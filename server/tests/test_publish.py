from __future__ import annotations

from pathlib import Path

import pytest
from fastapi.testclient import TestClient

from server.app.config import Settings
from server.app.packs import PackError, publish_pack


def _publish(app, settings: Settings, source: Path):
    with app.state.session_factory() as session:
        return publish_pack(source, settings.content_dir, session)


def test_publish_is_idempotent(client: TestClient, app, settings, make_pack) -> None:
    source = make_pack("republish")
    _publish(app, settings, source)
    _publish(app, settings, source)
    books = client.get("/v1/catalogue").json()["books"]
    assert [book["id"] for book in books] == ["demo-book"]
    assert books[0]["chapterCount"] == 1


@pytest.mark.parametrize("book_id", ["Demo Book", "../demo", "demo_book", ""])
def test_invalid_book_id_is_rejected(app, settings, make_pack, book_id: str) -> None:
    source = make_pack("invalid-id", book_id=book_id)
    with pytest.raises(PackError):
        _publish(app, settings, source)


def test_chapter_number_must_match_manifest(app, settings, make_pack) -> None:
    source = make_pack("mismatch", chapter_overrides={"number": 2})
    with pytest.raises(PackError):
        _publish(app, settings, source)


def test_chapter_book_id_must_match_manifest(app, settings, make_pack) -> None:
    source = make_pack("book-mismatch", chapter_overrides={"bookId": "other-book"})
    with pytest.raises(PackError):
        _publish(app, settings, source)


def test_missing_audio_file_is_rejected(app, settings, make_pack) -> None:
    source = make_pack("missing-audio")
    chapter_path = source / "chapters" / "chapter-01.json"
    text = chapter_path.read_text(encoding="utf-8")
    chapter_path.write_text(
        text.replace("chapter-01.mp3", "missing.mp3"), encoding="utf-8"
    )
    (source / "audio" / "chapter-01.mp3").unlink()
    with pytest.raises(PackError):
        _publish(app, settings, source)


def test_chapter_numbers_must_be_contiguous(app, settings, make_pack) -> None:
    second = {
        "id": "chapter-02",
        "number": 3,
        "title": "Le soir",
        "asset": "chapters/chapter-02.json",
        "estimatedMinutes": 2,
        "newWordCount": 1,
    }
    manifest = {
        "chapters": [
            {
                "id": "chapter-01",
                "number": 1,
                "title": "Un matin",
                "asset": "chapters/chapter-01.json",
                "estimatedMinutes": 2,
                "newWordCount": 1,
            },
            second,
        ]
    }
    source = make_pack("gap", manifest_overrides=manifest)
    (source / "chapters" / "chapter-02.json").write_text(
        (source / "chapters" / "chapter-01.json").read_text(encoding="utf-8"),
        encoding="utf-8",
    )
    with pytest.raises(PackError):
        _publish(app, settings, source)
