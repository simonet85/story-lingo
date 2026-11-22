from __future__ import annotations

import json
from pathlib import Path

import pytest
from ebooklib import epub

from tools.content.audio_pipeline import TOKEN_RE, align, normalize
from tools.content.import_book import (
    BookImportError,
    ImportOptions,
    build_chapters,
    build_manifest,
    extract_chapters,
    import_epub,
    load_lexicon,
)

LEXICON = {
    "version": "test",
    "words": {
        "mist": {
            "partOfSpeech": "noun",
            "phonetic": "/mɪst/",
            "definitionEn": "Thin fog.",
            "translationFr": "brume",
            "example": "A cold mist covered the road.",
            "cefr": "A2",
        },
        "road": {
            "partOfSpeech": "noun",
            "phonetic": "/roʊd/",
            "definitionEn": "A way between places.",
            "translationFr": "route",
            "example": "The road was empty.",
            "cefr": "A2",
        },
        "empty": {
            "partOfSpeech": "adjective",
            "phonetic": "/ˈɛmpti/",
            "definitionEn": "Containing nothing.",
            "translationFr": "vide",
            "example": "The road was empty.",
            "cefr": "A2",
        },
        "night": {
            "partOfSpeech": "noun",
            "phonetic": "/naɪt/",
            "definitionEn": "The dark part of the day.",
            "translationFr": "nuit",
            "example": "Mist returned at night.",
            "cefr": "A2",
        },
    },
}


def _write_epub(path: Path) -> Path:
    book = epub.EpubBook()
    book.set_identifier("demo-epub")
    book.set_title("The Morning Road")
    book.set_language("en")
    book.add_author("Test Author")

    first = epub.EpubHtml(title="The Morning Road", file_name="ch1.xhtml")
    first.content = (
        "<h1>The Morning Road</h1>"
        "<p>Mist covered the road.</p>"
        "<p>The morning was quiet.</p>"
    )
    second = epub.EpubHtml(title="The Empty Road", file_name="ch2.xhtml")
    second.content = (
        "<h1>The Empty Road</h1>"
        "<p>The road was empty.</p>"
        "<p>Mist returned at night.</p>"
    )
    book.add_item(first)
    book.add_item(second)
    book.toc = (first, second)
    book.add_item(epub.EpubNcx())
    book.add_item(epub.EpubNav())
    book.spine = ["nav", first, second]
    epub.write_epub(str(path), book)
    return path


def _lexicon_file(tmp_path: Path) -> Path:
    path = tmp_path / "lexicon.json"
    path.write_text(json.dumps(LEXICON), encoding="utf-8")
    return path


def _options(**overrides) -> ImportOptions:
    values = {
        "book_id": "morning-road",
        "title": "The Morning Road",
        "title_fr": "La route du matin",
        "author": "Test Author",
        "level": "A2",
        "description_fr": "Un voyage au petit matin.",
        "pack_version": "1.0.0",
        "max_new_words": 2,
    }
    values.update(overrides)
    return ImportOptions(**values)


def test_extract_chapters_skips_nav_and_keeps_paragraphs(tmp_path: Path) -> None:
    epub_path = _write_epub(tmp_path / "book.epub")
    chapters = extract_chapters(epub_path)
    assert chapters == [
        ("The Morning Road", ["Mist covered the road.", "The morning was quiet."]),
        ("The Empty Road", ["The road was empty.", "Mist returned at night."]),
    ]


def test_build_chapters_annotates_new_words_once(tmp_path: Path) -> None:
    extracted = extract_chapters(_write_epub(tmp_path / "book.epub"))
    lexicon = load_lexicon(_lexicon_file(tmp_path))
    chapters = build_chapters(extracted, lexicon, _options().normalized())

    first, second = chapters
    assert [entry["id"] for entry in first["vocabulary"]] == ["mist", "road"]
    assert [entry["id"] for entry in second["vocabulary"]] == ["empty", "night"]
    assert first["newWordCount"] == 2
    assert first["schemaVersion"] == 1

    for chapter in chapters:
        referenced = {
            segment["vocabId"]
            for paragraph in chapter["paragraphs"]
            for segment in paragraph["segments"]
            if "vocabId" in segment
        }
        assert referenced == {entry["id"] for entry in chapter["vocabulary"]}


def test_generated_chapters_match_dart_token_rules(tmp_path: Path) -> None:
    extracted = extract_chapters(_write_epub(tmp_path / "book.epub"))
    lexicon = load_lexicon(_lexicon_file(tmp_path))
    chapters = build_chapters(extracted, lexicon, _options().normalized())

    for chapter in chapters:
        for paragraph in chapter["paragraphs"]:
            assert paragraph["segments"]
            text = "".join(segment["text"] for segment in paragraph["segments"])
            for segment in paragraph["segments"]:
                if "vocabId" in segment:
                    assert TOKEN_RE.fullmatch(segment["text"])
            assert len(TOKEN_RE.findall(text)) > 0


def test_import_is_deterministic(tmp_path: Path) -> None:
    import asyncio

    epub_path = _write_epub(tmp_path / "book.epub")
    lexicon_path = _lexicon_file(tmp_path)
    asyncio.run(import_epub(epub_path, tmp_path / "a", _options(), lexicon_path))
    asyncio.run(import_epub(epub_path, tmp_path / "b", _options(), lexicon_path))

    files = sorted(
        path.relative_to(tmp_path / "a")
        for path in (tmp_path / "a").rglob("*")
        if path.is_file()
    )
    assert files
    for relative in files:
        assert (tmp_path / "a" / relative).read_bytes() == (
            tmp_path / "b" / relative
        ).read_bytes()


def test_import_writes_expected_pack_layout(tmp_path: Path) -> None:
    import asyncio

    asyncio.run(
        import_epub(
            _write_epub(tmp_path / "book.epub"),
            tmp_path / "pack",
            _options(),
            _lexicon_file(tmp_path),
        )
    )
    manifest = json.loads(
        (tmp_path / "pack" / "manifest.json").read_text(encoding="utf-8")
    )
    assert manifest["id"] == "morning-road"
    assert manifest["titleFr"] == "La route du matin"
    assert manifest["level"] == "a2"
    assert [chapter["id"] for chapter in manifest["chapters"]] == [
        "chapter-01",
        "chapter-02",
    ]
    assert manifest["chapters"][0]["asset"] == "chapters/chapter-01.json"
    assert manifest["chapters"][0]["newWordCount"] == 2

    chapter = json.loads(
        (tmp_path / "pack" / "chapters" / "chapter-01.json").read_text(
            encoding="utf-8"
        )
    )
    assert chapter["schemaVersion"] == 1
    assert "audio" not in chapter
    assert "estimatedMinutes" not in chapter
    assert chapter["bookId"] == "morning-road"


def test_max_new_words_zero_disables_annotation(tmp_path: Path) -> None:
    manifest, chapters = _run_import(
        tmp_path, _options(max_new_words=0)
    )
    assert all(not chapter["vocabulary"] for chapter in chapters)
    assert sum(item["newWordCount"] for item in manifest["chapters"]) == 0


def _run_import(tmp_path: Path, options: ImportOptions):
    import asyncio

    return asyncio.run(
        import_epub(
            _write_epub(tmp_path / "book.epub"),
            tmp_path / "pack",
            options,
            _lexicon_file(tmp_path),
        )
    )


def test_invalid_book_id_is_rejected(tmp_path: Path) -> None:
    with pytest.raises(BookImportError):
        _run_import(tmp_path, _options(book_id="Not A Book"))


def test_default_manifest_matches_chapter_count(tmp_path: Path) -> None:
    extracted = extract_chapters(_write_epub(tmp_path / "book.epub"))
    lexicon = load_lexicon(_lexicon_file(tmp_path))
    options = _options().normalized()
    chapters = build_chapters(extracted, lexicon, options)
    manifest = build_manifest(chapters, options)
    assert len(manifest["chapters"]) == len(chapters) == 2
    assert manifest["chapters"][1]["number"] == 2


def test_align_splits_multi_word_boundaries() -> None:
    tokens = ["Mist", "covered", "the", "road"]
    boundaries = [
        {"text": "Mist", "startMs": 0, "endMs": 300},
        {"text": "covered the road", "startMs": 350, "endMs": 1250},
    ]
    timings = align(tokens, boundaries)
    assert [timing["text"] for timing in timings] == tokens
    assert [timing["startMs"] for timing in timings] == sorted(
        timing["startMs"] for timing in timings
    )
    assert all(timing["endMs"] > timing["startMs"] for timing in timings)


def test_align_rejects_mismatched_tokens() -> None:
    tokens = ["Mist", "covered", "the", "road"]
    boundaries = [
        {"text": "Mist", "startMs": 0, "endMs": 300},
        {"text": "covered", "startMs": 350, "endMs": 800},
    ]
    with pytest.raises(RuntimeError):
        align(tokens, boundaries)


def test_normalize_matches_dart_word_rules() -> None:
    assert normalize("Mist,") == "mist"
    assert normalize("don’t") == "don't"
    assert normalize("words'") == "words"
