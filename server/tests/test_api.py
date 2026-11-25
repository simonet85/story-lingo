from __future__ import annotations

from fastapi.testclient import TestClient

from server.app.config import Settings
from server.app.main import create_app
from server.tests.support import AUDIO_BYTES


def test_health(client: TestClient) -> None:
    response = client.get("/v1/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


def test_catalogue(client: TestClient) -> None:
    response = client.get("/v1/catalogue")
    assert response.status_code == 200
    payload = response.json()
    assert payload["updatedAt"].endswith("Z")
    books = payload["books"]
    assert [book["id"] for book in books] == ["demo-book"]
    book = books[0]
    assert book["title"] == "Demo Book"
    assert book["titleFr"] == "Livre de démonstration"
    assert book["author"] == "Storylingo"
    assert book["level"] == "a2"
    assert book["packVersion"] == "1.0.0"
    assert book["chapterCount"] == 1
    assert book["totalMinutes"] == 2
    assert book["newWordCount"] == 1
    assert book["isFree"] is True
    assert book["manifestUrl"] == "/v1/books/demo-book"
    assert response.headers["etag"].startswith('"')


def test_catalogue_etag_returns_304(client: TestClient) -> None:
    first = client.get("/v1/catalogue")
    etag = first.headers["etag"]
    second = client.get("/v1/catalogue", headers={"If-None-Match": etag})
    assert second.status_code == 304
    assert second.content == b""
    assert second.headers["etag"] == etag


def test_manifest_rewrites_chapter_urls(client: TestClient) -> None:
    response = client.get("/v1/books/demo-book")
    assert response.status_code == 200
    manifest = response.json()
    assert manifest["id"] == "demo-book"
    chapter = manifest["chapters"][0]
    assert chapter["id"] == "chapter-01"
    assert chapter["url"] == "/v1/books/demo-book/chapters/chapter-01"
    assert "asset" not in chapter


def test_chapter_rewrites_audio_url(client: TestClient) -> None:
    response = client.get("/v1/books/demo-book/chapters/chapter-01")
    assert response.status_code == 200
    chapter = response.json()
    assert chapter["id"] == "chapter-01"
    assert chapter["bookId"] == "demo-book"
    assert chapter["vocabulary"][0]["id"] == "hello"
    audio = chapter["audio"]
    assert audio["url"] == "/v1/books/demo-book/audio/chapter-01.mp3"
    assert "asset" not in audio
    assert len(audio["words"]) == 2


def test_public_base_url_is_prefixed(client: TestClient, settings: Settings) -> None:
    app = create_app(
        Settings(
            database_url=settings.database_url,
            content_dir=settings.content_dir,
            public_base_url="https://cdn.example.com",
        )
    )
    with TestClient(app) as client:
        manifest = client.get("/v1/books/demo-book").json()
        chapter = client.get("/v1/books/demo-book/chapters/chapter-01").json()
    assert manifest["chapters"][0]["url"] == (
        "https://cdn.example.com/v1/books/demo-book/chapters/chapter-01"
    )
    assert chapter["audio"]["url"] == (
        "https://cdn.example.com/v1/books/demo-book/audio/chapter-01.mp3"
    )


def test_audio_full_response(client: TestClient) -> None:
    response = client.get("/v1/books/demo-book/audio/chapter-01.mp3")
    assert response.status_code == 200
    assert response.content == AUDIO_BYTES
    assert response.headers["accept-ranges"] == "bytes"
    assert response.headers["content-type"] == "audio/mpeg"


def test_audio_range_returns_206(client: TestClient) -> None:
    size = len(AUDIO_BYTES)
    response = client.get(
        "/v1/books/demo-book/audio/chapter-01.mp3",
        headers={"Range": "bytes=0-9"},
    )
    assert response.status_code == 206
    assert response.content == AUDIO_BYTES[:10]
    assert response.headers["content-range"] == f"bytes 0-9/{size}"
    assert response.headers["accept-ranges"] == "bytes"


def test_audio_open_ended_and_suffix_ranges(client: TestClient) -> None:
    size = len(AUDIO_BYTES)
    open_ended = client.get(
        "/v1/books/demo-book/audio/chapter-01.mp3",
        headers={"Range": "bytes=10-"},
    )
    assert open_ended.status_code == 206
    assert open_ended.content == AUDIO_BYTES[10:]
    assert open_ended.headers["content-range"] == f"bytes 10-{size - 1}/{size}"

    suffix = client.get(
        "/v1/books/demo-book/audio/chapter-01.mp3",
        headers={"Range": "bytes=-4"},
    )
    assert suffix.status_code == 206
    assert suffix.content == AUDIO_BYTES[-4:]
    assert suffix.headers["content-range"] == f"bytes {size - 4}-{size - 1}/{size}"


def test_audio_invalid_range_returns_416(client: TestClient) -> None:
    size = len(AUDIO_BYTES)
    for header in ("bytes=999999-", "bytes=0-1,3-4", "bytes=abc", "bytes=-0"):
        response = client.get(
            "/v1/books/demo-book/audio/chapter-01.mp3",
            headers={"Range": header},
        )
        assert response.status_code == 416, header
        assert response.headers["content-range"] == f"bytes */{size}"


def test_unknown_book_chapter_and_audio_return_404(client: TestClient) -> None:
    assert client.get("/v1/books/nope").status_code == 404
    assert client.get("/v1/books/nope/chapters/chapter-01").status_code == 404
    assert (
        client.get("/v1/books/demo-book/chapters/chapter-99").status_code == 404
    )
    assert client.get("/v1/books/demo-book/audio/missing.mp3").status_code == 404


def test_invalid_book_id_returns_422(client: TestClient) -> None:
    assert client.get("/v1/books/Demo_Book").status_code == 422
    assert client.get("/v1/books/..").status_code in (404, 422)


def test_audio_path_traversal_is_rejected(client: TestClient) -> None:
    for name in ("..%2Fmanifest.json", "%2E%2E%2Fmanifest.json", "..%5Cmanifest.json"):
        response = client.get(f"/v1/books/demo-book/audio/{name}")
        assert response.status_code == 404, name


def test_cors_allows_local_dev_origins(client: TestClient) -> None:
    response = client.options(
        "/v1/catalogue",
        headers={
            "Origin": "http://localhost:5173",
            "Access-Control-Request-Method": "GET",
        },
    )
    assert response.status_code == 200
    assert response.headers["access-control-allow-origin"] == "http://localhost:5173"
