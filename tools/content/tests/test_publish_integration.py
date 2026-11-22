from __future__ import annotations

import asyncio
import json
from pathlib import Path

from ebooklib import epub
from fastapi.testclient import TestClient

from server.app.config import Settings
from server.app.main import create_app
from server.app.packs import publish_pack
from tools.content.import_book import ImportOptions, import_epub


def test_imported_pack_can_be_published_and_served(tmp_path: Path) -> None:
    source = epub.EpubBook()
    source.set_identifier("story-epub")
    source.set_title("The Quiet Road")
    source.set_language("en")
    source.add_author("Test Author")
    chapter = epub.EpubHtml(title="The Quiet Road", file_name="ch1.xhtml")
    chapter.content = (
        "<h1>The Quiet Road</h1><p>Mist covered the road.</p>"
    )
    source.add_item(chapter)
    source.toc = (chapter,)
    source.add_item(epub.EpubNcx())
    source.add_item(epub.EpubNav())
    source.spine = ["nav", chapter]
    epub_path = tmp_path / "story.epub"
    epub.write_epub(str(epub_path), source)

    lexicon_path = tmp_path / "lexicon.json"
    lexicon_path.write_text(
        json.dumps(
            {
                "words": {
                    "mist": {
                        "partOfSpeech": "noun",
                        "phonetic": "/mɪst/",
                        "definitionEn": "Thin fog.",
                        "translationFr": "brume",
                        "example": "Mist covered the road.",
                        "cefr": "A2",
                    }
                }
            }
        ),
        encoding="utf-8",
    )

    pack_dir = tmp_path / "pack"
    manifest, _chapters = asyncio.run(
        import_epub(
            epub_path,
            pack_dir,
            ImportOptions(
                book_id="quiet-road",
                title="The Quiet Road",
                title_fr="La route tranquille",
                author="Test Author",
                max_new_words=1,
            ),
            lexicon_path,
        )
    )
    assert manifest["packVersion"] == "1.0.0"

    settings = Settings(
        database_url=f"sqlite:///{(tmp_path / 'api.db').as_posix()}",
        content_dir=tmp_path / "packs",
        public_base_url=None,
    )
    app = create_app(settings)
    with app.state.session_factory() as session:
        publish_pack(pack_dir, settings.content_dir, session, is_free=True)

    sidecar = json.loads(
        (settings.content_dir / "quiet-road" / ".download.json").read_text(
            encoding="utf-8"
        )
    )
    assert sidecar["bookId"] == "quiet-road"
    assert [item["kind"] for item in sidecar["files"]] == ["manifest", "chapter"]

    with TestClient(app) as client:
        catalogue = client.get("/v1/catalogue").json()["books"]
        assert [book["id"] for book in catalogue] == ["quiet-road"]
        assert catalogue[0]["chapterCount"] == 1

        served_manifest = client.get("/v1/books/quiet-road").json()
        assert served_manifest["chapters"][0]["url"] == (
            "/v1/books/quiet-road/chapters/chapter-01"
        )

        served_chapter = client.get(
            "/v1/books/quiet-road/chapters/chapter-01"
        ).json()
        assert served_chapter["bookId"] == "quiet-road"
        assert served_chapter["level"] == "a2"
        assert served_chapter["vocabulary"][0]["id"] == "mist"
        assert served_chapter["paragraphs"][0]["segments"]
        assert "audio" not in served_chapter
