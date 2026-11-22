from __future__ import annotations

import hashlib
import json
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

from server.app import packs
from server.app.config import Settings
from server.app.main import create_app
from server.app.models import Book
from server.app.packs import PackError, publish_pack
from server.tests.support import AUDIO_BYTES


def _descriptor(client: TestClient) -> dict:
    response = client.get("/v1/books/demo-book/download")
    assert response.status_code == 200, response.text
    payload = response.json()
    assert payload["schemaVersion"] == 1
    assert payload["bookId"] == "demo-book"
    assert payload["packVersion"] == "1.0.0"
    return payload


def _staging_entries(settings: Settings, name: str) -> list[Path]:
    folder = Path(settings.content_dir) / name
    return list(folder.iterdir()) if folder.is_dir() else []


def test_descriptor_lists_files_and_sizes(client: TestClient) -> None:
    descriptor = _descriptor(client)
    files = descriptor["files"]
    assert [item["kind"] for item in files] == ["manifest", "chapter", "audio"]
    assert files[0]["path"] == "manifest.json"
    assert files[1]["chapterId"] == "chapter-01"
    assert files[1]["path"] == "chapters/chapter-01.json"
    assert files[2]["path"] == "audio/chapter-01.mp3"
    assert descriptor["totalBytes"] == sum(item["sizeBytes"] for item in files)
    for item in files:
        assert len(item["sha256"]) == 64
        assert item["sizeBytes"] > 0


def test_descriptor_bytes_match_hashes_and_sizes(client: TestClient) -> None:
    descriptor = _descriptor(client)
    for item in descriptor["files"]:
        response = client.get(item["downloadUrl"])
        assert response.status_code == 200, item
        assert len(response.content) == item["sizeBytes"], item
        assert hashlib.sha256(response.content).hexdigest() == item["sha256"], item
        assert response.headers["etag"] == f'"{item["sha256"]}"', item

    manifest = client.get("/v1/books/demo-book/files/manifest.json").json()
    chapter = client.get(
        "/v1/books/demo-book/files/chapters/chapter-01.json"
    ).json()
    assert manifest["chapters"][0]["url"] == (
        "/v1/books/demo-book/chapters/chapter-01"
    )
    assert "asset" not in manifest["chapters"][0]
    assert chapter["audio"]["url"] == "/v1/books/demo-book/audio/chapter-01.mp3"
    assert "asset" not in chapter["audio"]
    audio = client.get("/v1/books/demo-book/audio/chapter-01.mp3")
    assert audio.content == AUDIO_BYTES


def test_descriptor_etag_returns_304(client: TestClient) -> None:
    first = client.get("/v1/books/demo-book/download")
    assert first.headers["cache-control"] == "no-cache"
    etag = first.headers["etag"]
    second = client.get(
        "/v1/books/demo-book/download", headers={"If-None-Match": etag}
    )
    assert second.status_code == 304
    assert second.content == b""
    assert second.headers["etag"] == etag


def test_download_sidecar_is_written_on_publish(
    client: TestClient, settings: Settings
) -> None:
    sidecar_path = Path(settings.content_dir) / "demo-book" / ".download.json"
    assert sidecar_path.is_file()
    sidecar = json.loads(sidecar_path.read_text(encoding="utf-8"))
    assert sidecar["files"][0]["downloadUrl"].startswith(
        "/v1/books/demo-book/files/"
    )
    assert _staging_entries(settings, ".staging") == []


def test_descriptor_is_rebuilt_when_sidecar_is_missing(
    client: TestClient, settings: Settings
) -> None:
    sidecar_path = Path(settings.content_dir) / "demo-book" / ".download.json"
    sidecar_path.unlink()
    descriptor = _descriptor(client)
    assert sidecar_path.is_file()
    assert descriptor["files"][0]["kind"] == "manifest"


def test_public_base_url_prefixes_descriptor_and_keeps_sidecar_relative(
    client: TestClient, settings: Settings
) -> None:
    app = create_app(
        Settings(
            database_url=settings.database_url,
            content_dir=settings.content_dir,
            public_base_url="https://cdn.example.com",
        )
    )
    with TestClient(app) as prefixed:
        descriptor = prefixed.get("/v1/books/demo-book/download").json()
        for item in descriptor["files"]:
            assert item["url"].startswith("https://cdn.example.com/v1/")
            assert item["downloadUrl"].startswith("https://cdn.example.com/v1/")
        manifest_url = descriptor["files"][0]["downloadUrl"]
        relative = manifest_url.removeprefix("https://cdn.example.com")
        assert prefixed.get(relative).json()["id"] == "demo-book"

    sidecar = json.loads(
        (
            Path(settings.content_dir) / "demo-book" / ".download.json"
        ).read_text(encoding="utf-8")
    )
    assert sidecar["files"][0]["downloadUrl"].startswith(
        "/v1/books/demo-book/files/"
    )


def test_unsafe_or_unknown_download_paths_return_404(client: TestClient) -> None:
    paths = (
        "..%2Fmanifest.json",
        "%2E%2E%2Fmanifest.json",
        "..%5Cmanifest.json",
        "%2Fmanifest.json",
        "chapters%2F..%2Fmanifest.json",
        "chapters/unknown.json",
        "audio%2Fchapter-01.mp3",
        ".download.json",
    )
    for path in paths:
        response = client.get(f"/v1/books/demo-book/files/{path}")
        assert response.status_code == 404, path


def test_download_endpoints_are_404_for_unknown_book(client: TestClient) -> None:
    assert client.get("/v1/books/nope/download").status_code == 404
    assert client.get("/v1/books/nope/files/manifest.json").status_code == 404


def test_publish_failure_restores_previous_pack(
    client: TestClient, app, settings: Settings, make_pack, monkeypatch
) -> None:
    source = make_pack(
        "next-version",
        manifest_overrides={"packVersion": "1.1.0", "title": "Demo Book v2"},
    )
    calls: list[tuple[Path, Path]] = []
    original = packs._replace_path

    def flaky_replace(src: Path, dst: Path) -> None:
        calls.append((src, dst))
        if len(calls) == 2:
            raise PackError("swap failed")
        original(src, dst)

    monkeypatch.setattr(packs, "_replace_path", flaky_replace)
    with pytest.raises(PackError):
        with app.state.session_factory() as session:
            publish_pack(source, settings.content_dir, session)

    with app.state.session_factory() as session:
        book = session.get(Book, "demo-book")
        assert book.pack_version == "1.0.0"
        assert book.title == "Demo Book"

    manifest = json.loads(
        (Path(settings.content_dir) / "demo-book" / "manifest.json").read_text(
            encoding="utf-8"
        )
    )
    assert manifest["packVersion"] == "1.0.0"
    assert manifest["title"] == "Demo Book"
    assert _staging_entries(settings, ".staging") == []
    assert _staging_entries(settings, ".backup") == []
    assert client.get("/v1/books/demo-book/download").status_code == 200
