from __future__ import annotations

import hashlib
import json
import os
import re
import shutil
import time
import uuid
from datetime import datetime, timezone
from pathlib import Path, PurePosixPath
from typing import Any

from sqlalchemy.orm import Session

from .config import Settings
from .models import Book

BOOK_ID_RE = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
PACK_VERSION_RE = re.compile(r"^\d+\.\d+\.\d+$")
LEVELS = ("a2", "b1", "b2")
DOWNLOAD_SCHEMA_VERSION = 1
_STAGING_MAX_AGE_SECONDS = 24 * 60 * 60


class PackError(ValueError):
    pass


def _read_json(path: Path) -> Any:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as error:
        raise PackError(f"Missing file: {path}") from error
    except (OSError, json.JSONDecodeError) as error:
        raise PackError(f"Invalid JSON in {path}: {error}") from error


def _require_dict(value: Any, label: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        raise PackError(f"{label} must be a JSON object.")
    return value


def _require_str(value: Any, label: str) -> str:
    if not isinstance(value, str) or not value.strip():
        raise PackError(f"{label} must be a non-empty string.")
    return value


def _require_int(value: Any, label: str) -> int:
    if not isinstance(value, int) or isinstance(value, bool):
        raise PackError(f"{label} must be an integer.")
    return value


def _safe_relative(value: str, label: str) -> Path:
    if not value or "\\" in value or "\x00" in value:
        raise PackError(f"Unsafe {label}.")
    pure = PurePosixPath(value)
    if pure.is_absolute() or ".." in pure.parts:
        raise PackError(f"Unsafe {label}.")
    return Path(*pure.parts)


def _chapter_file(source: Path, summary: dict[str, Any], index: int) -> Path:
    asset = summary.get("asset")
    if isinstance(asset, str) and asset.strip():
        candidate = source / "chapters" / Path(asset).name
    else:
        candidate = source / "chapters" / f"{_require_str(summary.get('id'), f'chapters[{index}].id')}.json"
    if not candidate.is_file():
        raise PackError(f"Chapter file not found: {candidate}")
    return candidate


def _validate_chapter(
    chapter: Any,
    *,
    book_id: str,
    summary: dict[str, Any],
    source: Path,
) -> None:
    chapter = _require_dict(chapter, f"chapter {summary.get('id')}")
    if chapter.get("id") != summary.get("id"):
        raise PackError("Chapter id does not match its manifest entry.")
    if chapter.get("bookId") != book_id:
        raise PackError("Chapter bookId does not match the manifest id.")
    if chapter.get("number") != summary.get("number"):
        raise PackError("Chapter number does not match its manifest entry.")
    paragraphs = chapter.get("paragraphs")
    if not isinstance(paragraphs, list) or not paragraphs:
        raise PackError("Chapter paragraphs must be a non-empty list.")
    if not isinstance(chapter.get("vocabulary"), list):
        raise PackError("Chapter vocabulary must be a list.")
    audio = chapter.get("audio")
    if isinstance(audio, dict):
        asset = audio.get("asset")
        if isinstance(asset, str) and asset.strip():
            audio_path = source / "audio" / Path(asset).name
            if not audio_path.is_file():
                raise PackError(f"Audio file not found: {audio_path}")


def canonical_json(payload: dict[str, Any]) -> bytes:
    return json.dumps(payload, ensure_ascii=False, separators=(",", ":")).encode(
        "utf-8"
    )


def _prefix_url(base_url: str | None, path: str) -> str:
    if base_url:
        return f"{base_url}{path}"
    return path


def manifest_payload_from(
    manifest: dict[str, Any], book_id: str, base_url: str | None = None
) -> dict[str, Any]:
    payload = dict(manifest)
    chapters: list[dict[str, Any]] = []
    for raw in manifest.get("chapters", []):
        summary = dict(raw)
        summary.pop("asset", None)
        summary["url"] = _prefix_url(
            base_url, f"/v1/books/{book_id}/chapters/{summary['id']}"
        )
        chapters.append(summary)
    payload["chapters"] = chapters
    return payload


def chapter_payload_from(
    chapter: dict[str, Any], book_id: str, base_url: str | None = None
) -> dict[str, Any]:
    payload = dict(chapter)
    audio = payload.get("audio")
    if isinstance(audio, dict):
        audio = dict(audio)
        asset = audio.get("asset")
        if isinstance(asset, str) and asset.strip():
            filename = Path(asset).name
            audio.pop("asset", None)
            audio["url"] = _prefix_url(
                base_url, f"/v1/books/{book_id}/audio/{filename}"
            )
        elif isinstance(audio.get("url"), str):
            audio["url"] = _prefix_url(base_url, audio["url"])
        payload["audio"] = audio
    return payload


def _audio_name(audio: dict[str, Any]) -> str | None:
    asset = audio.get("asset")
    if isinstance(asset, str) and asset.strip():
        return Path(asset).name
    url = audio.get("url")
    if isinstance(url, str) and url.strip():
        return PurePosixPath(url.split("?", 1)[0]).name
    return None


def build_download_descriptor(
    folder: Path, manifest: dict[str, Any], book_id: str
) -> dict[str, Any]:
    folder = Path(folder)
    manifest_bytes = canonical_json(manifest_payload_from(manifest, book_id))
    files: list[dict[str, Any]] = [
        {
            "kind": "manifest",
            "path": "manifest.json",
            "url": f"/v1/books/{book_id}",
            "downloadUrl": f"/v1/books/{book_id}/files/manifest.json",
            "sizeBytes": len(manifest_bytes),
            "sha256": hashlib.sha256(manifest_bytes).hexdigest(),
        }
    ]

    audio_files: dict[str, dict[str, Any]] = {}
    for raw in manifest.get("chapters", []):
        summary = _require_dict(raw, "manifest chapter")
        chapter_id = _require_str(summary.get("id"), "chapter id")
        asset = summary.get("asset")
        relative = (
            _safe_relative(asset, f"chapter asset for {chapter_id}")
            if isinstance(asset, str) and asset.strip()
            else Path("chapters") / f"{chapter_id}.json"
        )
        chapter_file = folder / relative
        chapter = _require_dict(_read_json(chapter_file), f"chapter {chapter_id}")
        chapter_bytes = canonical_json(chapter_payload_from(chapter, book_id))
        files.append(
            {
                "kind": "chapter",
                "chapterId": chapter_id,
                "path": relative.as_posix(),
                "url": f"/v1/books/{book_id}/chapters/{chapter_id}",
                "downloadUrl": f"/v1/books/{book_id}/files/{relative.as_posix()}",
                "sizeBytes": len(chapter_bytes),
                "sha256": hashlib.sha256(chapter_bytes).hexdigest(),
            }
        )

        audio = chapter.get("audio")
        if isinstance(audio, dict):
            name = _audio_name(audio)
            if name and name not in audio_files:
                audio_path = folder / "audio" / name
                data = audio_path.read_bytes()
                audio_files[name] = {
                    "kind": "audio",
                    "path": f"audio/{name}",
                    "url": f"/v1/books/{book_id}/audio/{name}",
                    "downloadUrl": f"/v1/books/{book_id}/audio/{name}",
                    "sizeBytes": len(data),
                    "sha256": hashlib.sha256(data).hexdigest(),
                }

    files.extend(sorted(audio_files.values(), key=lambda item: item["path"]))
    return {
        "schemaVersion": DOWNLOAD_SCHEMA_VERSION,
        "bookId": book_id,
        "packVersion": _require_str(manifest.get("packVersion"), "packVersion"),
        "totalBytes": sum(int(item["sizeBytes"]) for item in files),
        "files": files,
    }


def _write_sidecar(folder: Path, descriptor: dict[str, Any]) -> None:
    temporary = folder / ".download.json.tmp"
    temporary.write_bytes(canonical_json(descriptor))
    os.replace(temporary, folder / ".download.json")


def _read_sidecar(folder: Path) -> dict[str, Any] | None:
    try:
        sidecar = _read_json(folder / ".download.json")
    except PackError:
        return None
    if not isinstance(sidecar, dict):
        return None
    return sidecar


def _public_descriptor(
    descriptor: dict[str, Any], settings: Settings
) -> dict[str, Any]:
    if not settings.public_base_url:
        return descriptor
    result = {**descriptor}
    files: list[dict[str, Any]] = []
    for raw in descriptor.get("files", []):
        item = dict(raw)
        for key in ("url", "downloadUrl"):
            value = item.get(key)
            if isinstance(value, str):
                item[key] = _prefix_url(settings.public_base_url, value)
        files.append(item)
    result["files"] = files
    return result


def download_descriptor(book: Book, settings: Settings) -> dict[str, Any]:
    folder = pack_folder(book, settings)
    manifest = read_manifest(book, settings)
    sidecar = _read_sidecar(folder)
    if (
        sidecar is not None
        and sidecar.get("bookId") == book.id
        and sidecar.get("packVersion") == manifest.get("packVersion")
        and isinstance(sidecar.get("files"), list)
        and sidecar["files"]
    ):
        return _public_descriptor(sidecar, settings)
    descriptor = build_download_descriptor(folder, manifest, book.id)
    try:
        _write_sidecar(folder, descriptor)
    except OSError:
        pass
    return _public_descriptor(descriptor, settings)


def download_file_bytes(
    book: Book, settings: Settings, relative_path: str
) -> bytes:
    if not relative_path or relative_path in {".", ".."}:
        raise PackError("Unknown download file.")
    if "\\" in relative_path or "\x00" in relative_path:
        raise PackError("Unsafe download path.")
    pure = PurePosixPath(relative_path)
    if pure.is_absolute() or any(part in {"..", ""} for part in pure.parts):
        raise PackError("Unsafe download path.")

    folder = pack_folder(book, settings)
    manifest = read_manifest(book, settings)
    if pure.as_posix() == "manifest.json":
        return canonical_json(manifest_payload_from(manifest, book.id))

    parts = pure.parts
    if len(parts) != 2 or parts[0] != "chapters":
        raise PackError("Unknown download file.")
    filename = parts[1]
    for raw in manifest.get("chapters", []):
        summary = _require_dict(raw, "manifest chapter")
        asset = summary.get("asset")
        candidate = (
            Path(asset).name
            if isinstance(asset, str) and asset.strip()
            else f"{summary.get('id')}.json"
        )
        if candidate != filename:
            continue
        chapter_file = folder / (
            _safe_relative(asset, "chapter asset")
            if isinstance(asset, str) and asset.strip()
            else Path("chapters") / filename
        )
        chapter = _require_dict(
            _read_json(chapter_file), f"chapter {summary.get('id')}"
        )
        return canonical_json(chapter_payload_from(chapter, book.id))
    raise PackError("Unknown download file.")


def _replace_path(source: Path, target: Path) -> None:
    last_error: OSError | None = None
    for _ in range(5):
        try:
            os.replace(source, target)
            return
        except OSError as error:  # Windows can keep pack files open briefly.
            last_error = error
            time.sleep(0.1)
    raise PackError(f"Unable to replace {target.name}: {last_error}")


def _cleanup_temp_dirs(content_dir: Path) -> None:
    cutoff = time.time() - _STAGING_MAX_AGE_SECONDS
    for name in (".staging", ".backup"):
        parent = Path(content_dir) / name
        if not parent.is_dir():
            continue
        for child in parent.iterdir():
            try:
                if child.stat().st_mtime < cutoff:
                    shutil.rmtree(child, ignore_errors=True)
            except OSError:
                continue


def archive_pack(folder: Path, content_dir: Path) -> Path:
    folder = Path(folder)
    archive_root = Path(content_dir) / ".deleted"
    archive_root.mkdir(parents=True, exist_ok=True)
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    target = archive_root / f"{folder.name}-{stamp}-{uuid.uuid4().hex[:8]}"
    _replace_path(folder, target)
    return target


def publish_pack(
    source_dir: Path,
    content_dir: Path,
    session: Session,
    *,
    is_free: bool | None = None,
) -> Book:
    source_dir = Path(source_dir)
    manifest = _require_dict(_read_json(source_dir / "manifest.json"), "manifest")

    book_id = _require_str(manifest.get("id"), "manifest.id")
    if not BOOK_ID_RE.fullmatch(book_id):
        raise PackError(f"Invalid book id: {book_id!r}")
    pack_version = _require_str(manifest.get("packVersion"), "manifest.packVersion")
    if not PACK_VERSION_RE.fullmatch(pack_version):
        raise PackError(f"Invalid packVersion: {pack_version!r}")
    level = _require_str(manifest.get("level"), "manifest.level")
    if level not in LEVELS:
        raise PackError(
            f"Invalid level {level!r}; expected one of {', '.join(LEVELS)}."
        )

    existing_book = session.get(Book, book_id)
    # New books are paid unless publication explicitly marks them free. When
    # republishing without a flag, keep the stored status so a free book is
    # never locked by accident.
    effective_free = (
        bool(is_free)
        if is_free is not None
        else bool(existing_book.is_free if existing_book is not None else False)
    )
    manifest["isFree"] = effective_free

    raw_chapters = manifest.get("chapters")
    if not isinstance(raw_chapters, list) or not raw_chapters:
        raise PackError("manifest.chapters must be a non-empty list.")

    chapters: list[dict[str, Any]] = []
    chapter_files: list[Path] = []
    seen_ids: set[str] = set()
    numbers: list[int] = []
    for index, raw in enumerate(raw_chapters):
        summary = _require_dict(raw, f"manifest.chapters[{index}]")
        chapter_id = _require_str(summary.get("id"), f"chapters[{index}].id")
        if chapter_id in seen_ids:
            raise PackError(f"Duplicate chapter id: {chapter_id}")
        seen_ids.add(chapter_id)
        numbers.append(_require_int(summary.get("number"), f"chapters[{index}].number"))
        _require_str(summary.get("title"), f"chapters[{index}].title")
        _require_int(summary.get("estimatedMinutes"), f"chapters[{index}].estimatedMinutes")
        _require_int(summary.get("newWordCount"), f"chapters[{index}].newWordCount")

        chapter_file = _chapter_file(source_dir, summary, index)
        _validate_chapter(
            _read_json(chapter_file),
            book_id=book_id,
            summary=summary,
            source=source_dir,
        )
        chapter_files.append(chapter_file)
        normalized = dict(summary)
        normalized["asset"] = f"chapters/{chapter_file.name}"
        chapters.append(normalized)

    expected = list(range(1, len(numbers) + 1))
    if sorted(numbers) != expected:
        raise PackError("Chapter numbers must run from 1 without gaps.")

    content_dir = Path(content_dir)
    target = content_dir / book_id
    target.parent.mkdir(parents=True, exist_ok=True)
    manifest["chapters"] = chapters

    staging: Path | None = None
    backup: Path | None = None
    in_place = source_dir.resolve() == target.resolve()
    if in_place:
        manifest_bytes = (
            json.dumps(manifest, ensure_ascii=False, indent=2) + "\n"
        ).encode("utf-8")
        manifest_tmp = target / "manifest.json.tmp"
        manifest_tmp.write_bytes(manifest_bytes)
        descriptor = build_download_descriptor(target, manifest, book_id)
        _write_sidecar(target, descriptor)
        os.replace(manifest_tmp, target / "manifest.json")
    else:
        staging_root = content_dir / ".staging"
        staging_root.mkdir(parents=True, exist_ok=True)
        staging = staging_root / f"{book_id}-{uuid.uuid4().hex}"
        try:
            staging.mkdir()
            (staging / "chapters").mkdir()
            for chapter_file in chapter_files:
                shutil.copy2(chapter_file, staging / "chapters" / chapter_file.name)
            audio_source = source_dir / "audio"
            if audio_source.is_dir():
                shutil.copytree(audio_source, staging / "audio")
            (staging / "manifest.json").write_text(
                json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
                encoding="utf-8",
            )
            _write_sidecar(
                staging, build_download_descriptor(staging, manifest, book_id)
            )
        except Exception:
            shutil.rmtree(staging, ignore_errors=True)
            raise

        backup_root = content_dir / ".backup"
        backup_root.mkdir(parents=True, exist_ok=True)
        try:
            if target.exists():
                backup = backup_root / f"{book_id}-{uuid.uuid4().hex}"
                _replace_path(target, backup)
            _replace_path(staging, target)
            staging = None
        except Exception:
            if backup is not None and backup.exists() and not target.exists():
                _replace_path(backup, target)
                backup = None
            if staging is not None:
                shutil.rmtree(staging, ignore_errors=True)
            raise

    chapter_count = len(chapters)
    total_minutes = sum(int(chapter["estimatedMinutes"]) for chapter in chapters)
    new_word_count = sum(int(chapter["newWordCount"]) for chapter in chapters)
    now = datetime.now(timezone.utc)

    book = existing_book
    if book is None:
        book = Book(id=book_id)
        session.add(book)
    book.title = _require_str(manifest.get("title"), "manifest.title")
    book.title_fr = _require_str(manifest.get("titleFr"), "manifest.titleFr")
    book.author = _require_str(manifest.get("author"), "manifest.author")
    book.level = level
    book.description_fr = _require_str(
        manifest.get("descriptionFr"), "manifest.descriptionFr"
    )
    book.pack_version = pack_version
    book.chapter_count = chapter_count
    book.total_minutes = total_minutes
    book.new_word_count = new_word_count
    book.folder = book_id
    book.is_free = effective_free
    book.updated_at = now

    try:
        session.commit()
    except Exception:
        session.rollback()
        if not in_place and target.exists():
            failed = content_dir / ".staging" / f"{book_id}-{uuid.uuid4().hex}"
            try:
                _replace_path(target, failed)
            except PackError:
                pass
            if backup is not None and backup.exists():
                _replace_path(backup, target)
                backup = None
        raise
    session.refresh(book)

    if backup is not None:
        shutil.rmtree(backup, ignore_errors=True)
    _cleanup_temp_dirs(content_dir)
    return book


def pack_folder(book: Book, settings: Settings) -> Path:
    folder = Path(settings.content_dir) / book.folder
    if not folder.is_dir():
        raise PackError(f"Pack folder missing for {book.id}")
    return folder


def read_manifest(book: Book, settings: Settings) -> dict[str, Any]:
    return _require_dict(
        _read_json(pack_folder(book, settings) / "manifest.json"), "manifest"
    )


def _api_url(settings: Settings, path: str) -> str:
    return _prefix_url(settings.public_base_url, path)


def catalogue_entry(book: Book) -> dict[str, Any]:
    return {
        "id": book.id,
        "title": book.title,
        "titleFr": book.title_fr,
        "author": book.author,
        "level": book.level,
        "descriptionFr": book.description_fr,
        "packVersion": book.pack_version,
        "chapterCount": book.chapter_count,
        "totalMinutes": book.total_minutes,
        "newWordCount": book.new_word_count,
        "isFree": book.is_free,
        "manifestUrl": f"/v1/books/{book.id}",
    }


def manifest_payload(book: Book, settings: Settings) -> dict[str, Any]:
    payload = manifest_payload_from(
        read_manifest(book, settings), book.id, settings.public_base_url
    )
    # Packs published before the paywall lack isFree; the database is authoritative.
    payload["isFree"] = book.is_free
    return payload


def _chapter_path(book: Book, settings: Settings, chapter_id: str) -> Path:
    folder = pack_folder(book, settings)
    for raw in read_manifest(book, settings)["chapters"]:
        if raw.get("id") != chapter_id:
            continue
        asset = raw.get("asset")
        if not isinstance(asset, str) or not asset.strip():
            raise PackError(f"Chapter {chapter_id} has no asset path.")
        relative = _safe_relative(asset, f"chapter path for {chapter_id}")
        path = folder / relative
        if not path.is_file():
            raise PackError(f"Chapter file not found for {chapter_id}.")
        return path
    raise PackError(f"Unknown chapter {chapter_id}.")


def chapter_payload(book: Book, settings: Settings, chapter_id: str) -> dict[str, Any]:
    chapter = _require_dict(
        _read_json(_chapter_path(book, settings, chapter_id)), "chapter"
    )
    return chapter_payload_from(chapter, book.id, settings.public_base_url)


def audio_file(book: Book, settings: Settings, filename: str) -> Path:
    if (
        not filename
        or filename in {".", ".."}
        or "/" in filename
        or "\\" in filename
        or "\x00" in filename
    ):
        raise PackError("Invalid audio file name.")
    folder = pack_folder(book, settings)
    path = folder / "audio" / filename
    if not path.is_file():
        raise PackError("Audio file not found.")
    root = (folder / "audio").resolve()
    if root not in path.resolve().parents:
        raise PackError("Audio file outside the pack.")
    return path
