from __future__ import annotations

import hashlib
import json
import re
from datetime import timezone
from typing import Annotated, Iterator

from fastapi import APIRouter, Depends, HTTPException, Path, Request, Response
from sqlalchemy import select
from sqlalchemy.orm import Session

from . import packs
from .config import Settings
from .models import Book

router = APIRouter()

_RANGE_RE = re.compile(r"^bytes=(\d*)-(\d*)$")
BookId = Annotated[str, Path(pattern=packs.BOOK_ID_RE.pattern)]


def get_session(request: Request) -> Iterator[Session]:
    session = request.app.state.session_factory()
    try:
        yield session
    finally:
        session.close()


def get_settings(request: Request) -> Settings:
    return request.app.state.settings


def _book_or_404(session: Session, book_id: str) -> Book:
    book = session.get(Book, book_id)
    if book is None:
        raise HTTPException(status_code=404, detail=f'Unknown book "{book_id}".')
    return book


def _etag_matches(header: str, etag: str) -> bool:
    for candidate in header.split(","):
        candidate = candidate.strip()
        if candidate.startswith("W/"):
            candidate = candidate[2:]
        if candidate == etag:
            return True
    return False


@router.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


@router.get("/catalogue")
def catalogue(request: Request, session: Session = Depends(get_session)) -> Response:
    books = session.scalars(select(Book).order_by(Book.id)).all()
    updated_at = max((book.updated_at for book in books), default=None)
    if updated_at is not None and updated_at.tzinfo is None:
        updated_at = updated_at.replace(tzinfo=timezone.utc)
    payload = {
        "updatedAt": updated_at.isoformat().replace("+00:00", "Z")
        if updated_at
        else "1970-01-01T00:00:00Z",
        "books": [packs.catalogue_entry(book) for book in books],
    }
    body = json.dumps(payload, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
    etag = '"' + hashlib.sha256(body).hexdigest() + '"'
    headers = {"ETag": etag, "Cache-Control": "public, max-age=60"}
    incoming = request.headers.get("if-none-match")
    if incoming and _etag_matches(incoming, etag):
        return Response(status_code=304, headers=headers)
    return Response(content=body, media_type="application/json", headers=headers)


@router.get("/books/{book_id}")
def book_manifest(
    book_id: BookId,
    settings: Settings = Depends(get_settings),
    session: Session = Depends(get_session),
) -> dict:
    book = _book_or_404(session, book_id)
    try:
        return packs.manifest_payload(book, settings)
    except packs.PackError as error:
        raise HTTPException(status_code=404, detail=str(error)) from error


@router.get("/books/{book_id}/download")
def download_descriptor(
    book_id: BookId,
    request: Request,
    settings: Settings = Depends(get_settings),
    session: Session = Depends(get_session),
) -> Response:
    book = _book_or_404(session, book_id)
    try:
        descriptor = packs.download_descriptor(book, settings)
    except packs.PackError as error:
        raise HTTPException(status_code=404, detail=str(error)) from error
    body = packs.canonical_json(descriptor)
    etag = '"' + hashlib.sha256(body).hexdigest() + '"'
    headers = {"ETag": etag, "Cache-Control": "no-cache"}
    incoming = request.headers.get("if-none-match")
    if incoming and _etag_matches(incoming, etag):
        return Response(status_code=304, headers=headers)
    return Response(content=body, media_type="application/json", headers=headers)


@router.get("/books/{book_id}/files/{relative_path:path}")
def download_file(
    book_id: BookId,
    relative_path: str,
    request: Request,
    settings: Settings = Depends(get_settings),
    session: Session = Depends(get_session),
) -> Response:
    book = _book_or_404(session, book_id)
    try:
        data = packs.download_file_bytes(book, settings, relative_path)
    except packs.PackError as error:
        raise HTTPException(status_code=404, detail=str(error)) from error
    etag = '"' + hashlib.sha256(data).hexdigest() + '"'
    headers = {"ETag": etag, "Cache-Control": "public, max-age=3600"}
    incoming = request.headers.get("if-none-match")
    if incoming and _etag_matches(incoming, etag):
        return Response(status_code=304, headers=headers)
    return Response(content=data, media_type="application/json", headers=headers)


@router.get("/books/{book_id}/chapters/{chapter_id}")
def chapter(
    book_id: BookId,
    chapter_id: str,
    settings: Settings = Depends(get_settings),
    session: Session = Depends(get_session),
) -> dict:
    book = _book_or_404(session, book_id)
    try:
        return packs.chapter_payload(book, settings, chapter_id)
    except packs.PackError as error:
        raise HTTPException(status_code=404, detail=str(error)) from error


def _parse_range(header: str, size: int) -> tuple[int, int]:
    match = _RANGE_RE.fullmatch(header.strip())
    if match is None:
        raise ValueError("Malformed range.")
    start_raw, end_raw = match.groups()
    if not start_raw and not end_raw:
        raise ValueError("Empty range.")
    if not start_raw:
        suffix = int(end_raw)
        if suffix <= 0:
            raise ValueError("Invalid suffix range.")
        start = max(0, size - suffix)
        return start, size - 1
    start = int(start_raw)
    end = int(end_raw) if end_raw else size - 1
    if start >= size or start > end:
        raise ValueError("Range outside the file.")
    return start, min(end, size - 1)


@router.get("/books/{book_id}/audio/{filename}")
def audio(
    book_id: BookId,
    filename: str,
    request: Request,
    settings: Settings = Depends(get_settings),
    session: Session = Depends(get_session),
) -> Response:
    book = _book_or_404(session, book_id)
    try:
        path = packs.audio_file(book, settings, filename)
    except packs.PackError as error:
        raise HTTPException(status_code=404, detail=str(error)) from error

    data = path.read_bytes()
    size = len(data)
    headers = {
        "Accept-Ranges": "bytes",
        "Cache-Control": "public, max-age=86400",
        "ETag": '"' + hashlib.sha256(data).hexdigest() + '"',
    }
    range_header = request.headers.get("range")
    if not range_header:
        return Response(
            content=data, media_type="audio/mpeg", headers=headers
        )
    try:
        start, end = _parse_range(range_header, size)
    except ValueError:
        headers["Content-Range"] = f"bytes */{size}"
        return Response(
            status_code=416, media_type="application/json", headers=headers
        )
    headers["Content-Range"] = f"bytes {start}-{end}/{size}"
    return Response(
        status_code=206,
        content=data[start : end + 1],
        media_type="audio/mpeg",
        headers=headers,
    )
