from __future__ import annotations

import hmac
import json
import logging
import shutil
import stat
import tempfile
import zipfile
from datetime import datetime, timezone
from pathlib import Path, PurePosixPath
from typing import Annotated, Iterator
from urllib.parse import quote

from fastapi import (
    APIRouter,
    Depends,
    File,
    Form,
    HTTPException,
    Request,
    UploadFile,
)
from fastapi.responses import RedirectResponse
from fastapi.templating import Jinja2Templates
from sqlalchemy import select
from sqlalchemy.orm import Session

from ..config import Settings
from ..models import Book
from ..packs import (
    LEVELS,
    PackError,
    archive_pack,
    pack_folder,
    publish_pack,
    read_manifest,
)
from .auth import (
    SESSION_COOKIE,
    SESSION_TTL_SECONDS,
    AdminAuth,
    AdminSession,
)

logger = logging.getLogger("storylingo.admin")

router = APIRouter(prefix="/admin", tags=["admin"], include_in_schema=False)
templates = Jinja2Templates(directory=str(Path(__file__).parent / "templates"))

MAX_ARCHIVE_ENTRIES = 2000


class UploadTooLarge(PackError):
    pass


def get_settings(request: Request) -> Settings:
    return request.app.state.settings


def get_session(request: Request) -> Iterator[Session]:
    session = request.app.state.session_factory()
    try:
        yield session
    finally:
        session.close()


def get_admin_auth(request: Request) -> AdminAuth:
    return request.app.state.admin_auth


def require_admin(request: Request) -> AdminSession:
    auth: AdminAuth = request.app.state.admin_auth
    session = auth.read(request.cookies.get(SESSION_COOKIE))
    if session is None:
        raise HTTPException(
            status_code=303, headers={"Location": "/admin/login"}
        )
    return session


AdminDep = Annotated[AdminSession, Depends(require_admin)]
SettingsDep = Annotated[Settings, Depends(get_settings)]
SessionDep = Annotated[Session, Depends(get_session)]


def _redirect(url: str) -> RedirectResponse:
    response = RedirectResponse(url=url, status_code=303)
    response.headers["Cache-Control"] = "no-store"
    return response


def _render(
    request: Request,
    template: str,
    context: dict,
    *,
    status_code: int = 200,
):
    response = templates.TemplateResponse(
        request, template, context, status_code=status_code
    )
    response.headers["Cache-Control"] = "no-store"
    response.headers["X-Frame-Options"] = "DENY"
    return response


def _check_csrf(session: AdminSession, csrf: str) -> None:
    if not csrf or not hmac.compare_digest(
        csrf.encode("utf-8"), session.csrf.encode("utf-8")
    ):
        raise HTTPException(status_code=403, detail="Jeton CSRF invalide.")


_MONTHS_FR = (
    "janv.",
    "févr.",
    "mars",
    "avr.",
    "mai",
    "juin",
    "juil.",
    "août",
    "sept.",
    "oct.",
    "nov.",
    "déc.",
)


def _format_updated(value: datetime | None) -> str:
    if value is None:
        return "—"
    if value.tzinfo is None:
        value = value.replace(tzinfo=timezone.utc)
    moment = value.astimezone(timezone.utc)
    month = _MONTHS_FR[moment.month - 1]
    return f"{moment.day} {month} {moment.year} · {moment:%H:%M} UTC"


def _notice_text(notice: str | None, book_id: str | None) -> str | None:
    book_id = (book_id or "").strip()[:120]
    if notice == "imported":
        return (
            f"Pack « {book_id} » importé." if book_id else "Pack importé."
        )
    if notice == "access":
        return (
            f"Statut d'accès de « {book_id} » mis à jour."
            if book_id
            else "Statut d'accès mis à jour."
        )
    if notice == "updated":
        return (
            f"Livre « {book_id} » mis à jour." if book_id else "Livre mis à jour."
        )
    if notice == "deleted":
        return (
            f"Livre « {book_id} » supprimé ; pack archivé."
            if book_id
            else "Livre supprimé ; pack archivé."
        )
    return None


@router.get("")
def admin_root(_session: AdminDep) -> RedirectResponse:
    return _redirect("/admin/books")


@router.get("/login")
def login_page(request: Request):
    auth = get_admin_auth(request)
    if auth.read(request.cookies.get(SESSION_COOKIE)) is not None:
        return _redirect("/admin/books")
    return _render(request, "login.html", {"error": None, "csrf": None})


@router.post("/login")
def login(request: Request, password: str = Form("")):
    auth = get_admin_auth(request)
    if not auth.check_password(password):
        client = request.client.host if request.client else "unknown"
        logger.warning("Admin login rejected from %s", client)
        return _render(
            request,
            "login.html",
            {"error": "Mot de passe invalide.", "csrf": None},
            status_code=401,
        )
    cookie, _ = auth.issue()
    response = _redirect("/admin/books")
    response.set_cookie(
        SESSION_COOKIE,
        cookie,
        max_age=SESSION_TTL_SECONDS,
        httponly=True,
        samesite="lax",
        secure=request.url.scheme == "https",
        path="/admin",
    )
    logger.info("Admin login succeeded")
    return response


@router.post("/logout")
def logout(session: AdminDep, csrf: str = Form("")):
    _check_csrf(session, csrf)
    response = _redirect("/admin/login")
    response.delete_cookie(
        SESSION_COOKIE, path="/admin", httponly=True, samesite="lax"
    )
    return response


@router.get("/books")
def books_page(
    request: Request,
    session: AdminDep,
    session_db: SessionDep,
    notice: str | None = None,
    book: str | None = None,
):
    records = session_db.scalars(select(Book).order_by(Book.id)).all()
    books = [
        {
            "id": record.id,
            "title": record.title,
            "title_fr": record.title_fr,
            "level": record.level,
            "pack_version": record.pack_version,
            "chapter_count": record.chapter_count,
            "is_free": record.is_free,
            "updated_at": _format_updated(record.updated_at),
        }
        for record in records
    ]
    stats = {
        "total": len(books),
        "chapters": sum(book["chapter_count"] for book in books),
        "minutes": sum(record.total_minutes for record in records),
        "free": sum(1 for book in books if book["is_free"]),
        "paid": sum(1 for book in books if not book["is_free"]),
    }
    return _render(
        request,
        "books.html",
        {
            "csrf": session.csrf,
            "books": books,
            "stats": stats,
            "notice": _notice_text(notice, book),
        },
    )


def _book_or_404(session_db: Session, book_id: str) -> Book:
    book = session_db.get(Book, book_id)
    if book is None:
        raise HTTPException(status_code=404, detail="Livre inconnu.")
    return book


def _clean_text(value: str, label: str, limit: int) -> str:
    value = value.strip()
    if not value:
        raise ValueError(f"{label} est obligatoire.")
    if len(value) > limit:
        raise ValueError(f"{label} ne doit pas dépasser {limit} caractères.")
    return value


def _book_view(book: Book) -> dict:
    return {
        "id": book.id,
        "title": book.title,
        "title_fr": book.title_fr,
        "author": book.author,
        "level": book.level,
        "description_fr": book.description_fr,
        "pack_version": book.pack_version,
        "chapter_count": book.chapter_count,
        "total_minutes": book.total_minutes,
        "new_word_count": book.new_word_count,
        "is_free": book.is_free,
        "updated_at": _format_updated(book.updated_at),
    }


def _book_form(book: Book) -> dict[str, str]:
    return {
        "title": book.title,
        "title_fr": book.title_fr,
        "author": book.author,
        "level": book.level,
        "description_fr": book.description_fr,
        "access": "free" if book.is_free else "paid",
    }


def _render_detail(
    request: Request,
    session: AdminSession,
    book: Book,
    *,
    error: str | None = None,
    status_code: int = 200,
):
    settings: Settings = request.app.state.settings
    chapters: list[dict] = []
    pack_available = True
    try:
        manifest = read_manifest(book, settings)
        chapters = [
            {
                "id": item.get("id", ""),
                "number": item.get("number", ""),
                "title": item.get("title", ""),
                "estimated_minutes": item.get("estimatedMinutes", ""),
                "new_word_count": item.get("newWordCount", ""),
            }
            for item in manifest.get("chapters", [])
            if isinstance(item, dict)
        ]
    except PackError:
        pack_available = False
    return _render(
        request,
        "book_detail.html",
        {
            "csrf": session.csrf,
            "book": _book_view(book),
            "chapters": chapters,
            "pack_available": pack_available,
            "error": error,
        },
        status_code=status_code,
    )


def _render_edit(
    request: Request,
    session: AdminSession,
    book: Book,
    form: dict[str, str],
    error: str | None,
    *,
    status_code: int = 400,
):
    return _render(
        request,
        "book_edit.html",
        {
            "csrf": session.csrf,
            "book": _book_view(book),
            "form": form,
            "error": error,
        },
        status_code=status_code,
    )


@router.get("/books/{book_id}")
def book_detail(
    request: Request,
    session: AdminDep,
    session_db: SessionDep,
    book_id: str,
):
    book = _book_or_404(session_db, book_id)
    return _render_detail(request, session, book)


@router.get("/books/{book_id}/edit")
def edit_book_page(
    request: Request,
    session: AdminDep,
    session_db: SessionDep,
    book_id: str,
):
    book = _book_or_404(session_db, book_id)
    return _render(
        request,
        "book_edit.html",
        {
            "csrf": session.csrf,
            "book": _book_view(book),
            "form": _book_form(book),
            "error": None,
        },
        status_code=200,
    )


@router.post("/books/{book_id}/edit")
def edit_book(
    request: Request,
    session: AdminDep,
    settings: SettingsDep,
    session_db: SessionDep,
    book_id: str,
    csrf: str = Form(""),
    title: str = Form(""),
    title_fr: str = Form(""),
    author: str = Form(""),
    level: str = Form(""),
    description_fr: str = Form(""),
    access: str = Form("free"),
):
    _check_csrf(session, csrf)
    book = _book_or_404(session_db, book_id)
    form = {
        "title": title,
        "title_fr": title_fr,
        "author": author,
        "level": level,
        "description_fr": description_fr,
        "access": access,
    }
    try:
        if access not in {"free", "paid"}:
            raise ValueError("Choix d'accès invalide.")
        fields = {
            "title": _clean_text(title, "Le titre", 300),
            "titleFr": _clean_text(title_fr, "Le titre français", 300),
            "author": _clean_text(author, "L'auteur", 200),
            "level": _clean_text(level, "Le niveau", 8).lower(),
            "descriptionFr": _clean_text(
                description_fr, "La description", 1000
            ),
        }
        if fields["level"] not in LEVELS:
            raise ValueError(
                "Niveau invalide : utilisez a2, b1 ou b2."
            )
    except ValueError as error:
        return _render_edit(request, session, book, form, str(error))

    try:
        folder = pack_folder(book, settings)
    except PackError as error:
        return _render_edit(
            request,
            session,
            book,
            form,
            f"Pack introuvable : {error}",
            status_code=409,
        )

    with tempfile.TemporaryDirectory(prefix="storylingo-edit-") as temporary:
        source = Path(temporary) / "pack"
        shutil.copytree(folder, source)
        manifest_path = source / "manifest.json"
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        manifest.update(fields)
        manifest_path.write_text(
            json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )
        try:
            book = publish_pack(
                source,
                settings.content_dir,
                session_db,
                is_free=access == "free",
            )
        except PackError as error:
            return _render_edit(request, session, book, form, str(error))

    logger.info("Admin update book=%s free=%s", book.id, book.is_free)
    return _redirect(f"/admin/books?notice=updated&book={quote(book.id)}")


@router.post("/books/{book_id}/delete")
def delete_book(
    request: Request,
    session: AdminDep,
    settings: SettingsDep,
    session_db: SessionDep,
    book_id: str,
    csrf: str = Form(""),
    confirm: str = Form(""),
):
    _check_csrf(session, csrf)
    book = _book_or_404(session_db, book_id)
    if confirm.strip() != book.id:
        return _render_detail(
            request,
            session,
            book,
            error="Saisissez l'identifiant exact du livre pour confirmer.",
            status_code=400,
        )

    folder = Path(settings.content_dir) / book.folder
    archived: Path | None = None
    if folder.is_dir():
        try:
            archived = archive_pack(folder, settings.content_dir)
        except PackError as error:
            return _render_detail(
                request,
                session,
                book,
                error=f"Archivage impossible : {error}",
                status_code=409,
            )

    session_db.delete(book)
    try:
        session_db.commit()
    except Exception:
        session_db.rollback()
        if archived is not None and archived.exists() and not folder.exists():
            shutil.move(str(archived), str(folder))
        raise

    logger.info(
        "Admin delete book=%s archived=%s",
        book_id,
        archived.name if archived is not None else None,
    )
    return _redirect(f"/admin/books?notice=deleted&book={quote(book_id)}")


@router.get("/import")
def import_page(request: Request, session: AdminDep):
    return _render(
        request,
        "import.html",
        {"csrf": session.csrf, "error": None, "selected": "keep"},
    )


def _read_upload(upload: UploadFile, destination: Path, limit: int) -> int:
    size = 0
    limit_mb = max(1, limit // (1024 * 1024))
    with destination.open("wb") as output:
        while True:
            chunk = upload.file.read(1024 * 1024)
            if not chunk:
                break
            size += len(chunk)
            if size > limit:
                raise UploadTooLarge(f"Archive trop volumineuse (max {limit_mb} Mo).")
            output.write(chunk)
    return size


def _extract_zip(archive_path: Path, target: Path, limit: int) -> None:
    try:
        archive = zipfile.ZipFile(archive_path)
    except zipfile.BadZipFile as error:
        raise PackError("Fichier ZIP invalide.") from error
    with archive:
        entries = archive.infolist()
        if len(entries) > MAX_ARCHIVE_ENTRIES:
            raise PackError("L'archive contient trop de fichiers.")
        extracted_size = 0
        for entry in entries:
            name = entry.filename
            if not name or "\\" in name or "\x00" in name:
                raise PackError("Chemin non autorisé dans l'archive.")
            pure = PurePosixPath(name)
            if pure.is_absolute() or any(
                part in {"..", ""} for part in pure.parts
            ):
                raise PackError("Chemin non autorisé dans l'archive.")
            mode = entry.external_attr >> 16
            if mode and stat.S_ISLNK(mode):
                raise PackError("Lien symbolique interdit dans l'archive.")
            destination = target.joinpath(*pure.parts)
            if entry.is_dir():
                destination.mkdir(parents=True, exist_ok=True)
                continue
            extracted_size += entry.file_size
            if extracted_size > limit:
                raise PackError(
                    "Archive trop volumineuse une fois décompressée."
                )
            destination.parent.mkdir(parents=True, exist_ok=True)
            remaining = limit - (extracted_size - entry.file_size)
            copied = 0
            with archive.open(entry) as source, destination.open("wb") as output:
                while True:
                    chunk = source.read(1024 * 1024)
                    if not chunk:
                        break
                    copied += len(chunk)
                    if copied > remaining:
                        raise PackError(
                            "Archive trop volumineuse une fois décompressée."
                        )
                    output.write(chunk)


def _locate_pack_root(extracted: Path) -> Path:
    if (extracted / "manifest.json").is_file():
        return extracted
    directories = [item for item in extracted.iterdir() if item.is_dir()]
    if (
        len(directories) == 1
        and (directories[0] / "manifest.json").is_file()
    ):
        return directories[0]
    raise PackError("manifest.json introuvable à la racine de l'archive.")


def _import_response(
    request: Request,
    session: AdminSession,
    message: str,
    access: str,
    *,
    status_code: int = 400,
):
    return _render(
        request,
        "import.html",
        {"csrf": session.csrf, "error": message, "selected": access},
        status_code=status_code,
    )


@router.post("/import")
def import_submit(
    request: Request,
    session: AdminDep,
    settings: SettingsDep,
    csrf: str = Form(""),
    access: str = Form("keep"),
    file: UploadFile = File(...),
):
    _check_csrf(session, csrf)
    if access not in {"keep", "free", "paid"}:
        return _import_response(
            request, session, "Choix d'accès invalide.", "keep"
        )
    filename = file.filename or ""
    if not filename.lower().endswith(".zip"):
        return _import_response(
            request, session, "Le fichier doit être une archive .zip.", access
        )
    is_free = None if access == "keep" else access == "free"

    with tempfile.TemporaryDirectory(prefix="storylingo-admin-") as temporary:
        temporary_path = Path(temporary)
        archive_path = temporary_path / "pack.zip"
        try:
            size = _read_upload(
                file, archive_path, settings.admin_max_upload_bytes
            )
        except UploadTooLarge as error:
            return _import_response(
                request, session, str(error), access, status_code=413
            )
        if size == 0:
            return _import_response(
                request, session, "L'archive est vide.", access
            )

        extracted = temporary_path / "pack"
        extracted.mkdir()
        try:
            _extract_zip(
                archive_path, extracted, settings.admin_max_upload_bytes
            )
            source = _locate_pack_root(extracted)
            with request.app.state.session_factory() as db:
                book = publish_pack(
                    source, settings.content_dir, db, is_free=is_free
                )
        except PackError as error:
            return _import_response(request, session, str(error), access)

    logger.info(
        "Admin import book=%s version=%s free=%s",
        book.id,
        book.pack_version,
        book.is_free,
    )
    return _redirect(
        f"/admin/books?notice=imported&book={quote(book.id)}"
    )


@router.post("/books/{book_id}/access")
def set_book_access(
    book_id: str,
    session: AdminDep,
    session_db: SessionDep,
    csrf: str = Form(""),
    access: str = Form(""),
):
    _check_csrf(session, csrf)
    if access not in {"free", "paid"}:
        raise HTTPException(status_code=400, detail="Valeur d'accès invalide.")
    book = session_db.get(Book, book_id)
    if book is None:
        raise HTTPException(status_code=404, detail="Livre inconnu.")
    book.is_free = access == "free"
    book.updated_at = datetime.now(timezone.utc)
    session_db.commit()
    logger.info(
        "Admin access update book=%s free=%s", book.id, book.is_free
    )
    return _redirect(
        f"/admin/books?notice=access&book={quote(book.id)}"
    )
