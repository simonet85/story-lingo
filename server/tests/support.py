from __future__ import annotations

import json
from pathlib import Path
from typing import Any

AUDIO_BYTES = b"ID3" + bytes(range(256)) * 8
DEV_SECRET = "storylingo-test-dev-secret-0123456789"
ADMIN_TOKEN = "storylingo-test-admin-token-0123456789"
ADMIN_SESSION_SECRET = "storylingo-test-admin-session-secret-0123456789"


def build_pack(
    source: Path,
    book_id: str = "demo-book",
    *,
    manifest_overrides: dict[str, Any] | None = None,
    chapter_overrides: dict[str, Any] | None = None,
    with_audio: bool = True,
) -> Path:
    source.mkdir(parents=True, exist_ok=True)
    (source / "chapters").mkdir(exist_ok=True)

    chapter: dict[str, Any] = {
        "schemaVersion": 2,
        "id": "chapter-01",
        "bookId": book_id,
        "number": 1,
        "title": "Un matin",
        "level": "a2",
        "paragraphs": [
            {
                "id": "p-01",
                "segments": [{"text": "Hello world.", "vocabId": "hello"}],
            }
        ],
        "vocabulary": [
            {
                "id": "hello",
                "word": "Hello",
                "partOfSpeech": "interjection",
                "phonetic": "/həˈloʊ/",
                "definitionEn": "A greeting.",
                "translationFr": "Bonjour",
                "example": "Hello, Anna!",
                "cefr": "A1",
            }
        ],
        "audio": {
            "asset": f"assets/content/{book_id}/audio/chapter-01.mp3",
            "durationMs": 1000,
            "voice": "en-US-AriaNeural",
            "words": [
                {"text": "Hello", "startMs": 0, "endMs": 400},
                {"text": "world", "startMs": 450, "endMs": 900},
            ],
        },
    }
    chapter.update(chapter_overrides or {})
    if not with_audio:
        chapter.pop("audio", None)

    manifest: dict[str, Any] = {
        "schemaVersion": 1,
        "packVersion": "1.0.0",
        "id": book_id,
        "title": "Demo Book",
        "titleFr": "Livre de démonstration",
        "author": "Storylingo",
        "level": "a2",
        "descriptionFr": "Un livre de test.",
        "chapters": [
            {
                "id": "chapter-01",
                "number": 1,
                "title": "Un matin",
                "asset": "chapters/chapter-01.json",
                "estimatedMinutes": 2,
                "newWordCount": 1,
            }
        ],
    }
    manifest.update(manifest_overrides or {})

    (source / "chapters" / "chapter-01.json").write_text(
        json.dumps(chapter, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    (source / "manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    if with_audio:
        (source / "audio").mkdir(exist_ok=True)
        (source / "audio" / "chapter-01.mp3").write_bytes(AUDIO_BYTES)
    return source
