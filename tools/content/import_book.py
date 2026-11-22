"""Import an EPUB into a Storylingo content pack.

Development-time tool:
- reads the EPUB spine, extracts chapters and paragraphs;
- annotates a deterministic number of new words per chapter from the
  versioned A2/B1 lexicon (``tools/content/lexicon/a2.json``);
- writes manifest.json + chapters/*.json (schemaVersion 1);
- with ``--audio``, synthesizes each chapter with edge-tts, aligns word
  timings and writes schemaVersion 2 chapters with MP3s.

Usage:
    python tools/content/import_book.py book.epub --book-id my-book --audio

The pack is written to STORYLINGO_CONTENT_DIR/<book-id> and published to the
catalogue database. Use --output to generate it elsewhere, or --no-publish to
skip the database step.
"""

from __future__ import annotations

import argparse
import asyncio
import json
import re
import shutil
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from bs4 import BeautifulSoup
from ebooklib import ITEM_DOCUMENT, epub

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from tools.content.audio_pipeline import (  # noqa: E402
    TOKEN_RE,
    VOICE,
    align,
    normalize,
    probe_duration_ms,
    synthesize,
)

DEFAULT_LEXICON = ROOT / "tools" / "content" / "lexicon" / "a2.json"
BOOK_ID_RE = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
LEVELS = ("a2", "b1", "b2")
BLOCK_TAGS = ("h1", "h2", "h3", "h4", "p", "li", "blockquote")
SENTENCE_RE = re.compile(r"(?<=[.!?])\s+")

WORDS_PER_MINUTE = 140


class BookImportError(RuntimeError):
    pass


@dataclass(frozen=True)
class ImportOptions:
    book_id: str
    title: str
    title_fr: str
    author: str
    level: str = "a2"
    description_fr: str = ""
    pack_version: str = "1.0.0"
    max_new_words: int = 8
    voice: str = VOICE
    rate: str = "+0%"

    def normalized(self) -> ImportOptions:
        if not BOOK_ID_RE.fullmatch(self.book_id):
            raise BookImportError(
                f"Invalid book id {self.book_id!r} "
                "(lowercase letters, digits and single hyphens)."
            )
        level = self.level.lower()
        if level not in LEVELS:
            raise BookImportError(f"Invalid level {self.level!r}.")
        if not re.fullmatch(r"\d+\.\d+\.\d+", self.pack_version):
            raise BookImportError(f"Invalid pack version {self.pack_version!r}.")
        if self.max_new_words < 0:
            raise BookImportError("max_new_words must be >= 0.")
        return ImportOptions(
            book_id=self.book_id,
            title=self.title.strip(),
            title_fr=(self.title_fr or self.title).strip(),
            author=self.author.strip() or "Unknown",
            level=level,
            description_fr=self.description_fr.strip()
            or f"{self.title.strip()} — un livre importé depuis un EPUB.",
            pack_version=self.pack_version,
            max_new_words=self.max_new_words,
            voice=self.voice,
            rate=self.rate,
        )


def load_lexicon(path: Path) -> dict[str, dict[str, Any]]:
    payload = json.loads(Path(path).read_text(encoding="utf-8"))
    raw_words = payload.get("words", payload)
    if not isinstance(raw_words, dict):
        raise BookImportError("Lexicon must contain a 'words' object.")
    lexicon: dict[str, dict[str, Any]] = {}
    for word, entry in raw_words.items():
        if not isinstance(entry, dict):
            raise BookImportError(f"Lexicon entry {word!r} must be an object.")
        if any(char.isspace() for char in str(word)):
            continue
        key = normalize(str(word))
        if len(key) > 2 and key not in lexicon:
            lexicon[key] = entry
    return lexicon


def _clean_text(value: str) -> str:
    return " ".join(value.replace("\xa0", " ").split())


def extract_chapters(epub_path: Path) -> list[tuple[str | None, list[str]]]:
    book = epub.read_epub(str(epub_path), options={"ignore_ncx": True})
    chapters: list[tuple[str | None, list[str]]] = []
    seen: set[str] = set()
    for entry in book.spine:
        idref = entry[0] if isinstance(entry, (tuple, list)) else entry
        if idref in seen:
            continue
        seen.add(idref)
        item = book.get_item_with_id(idref)
        if item is None or item.get_type() != ITEM_DOCUMENT:
            continue
        if "nav" in (getattr(item, "properties", None) or []):
            continue
        soup = BeautifulSoup(item.get_content(), "html.parser")
        for junk in soup(["script", "style", "nav"]):
            junk.decompose()
        heading: str | None = None
        paragraphs: list[str] = []
        for element in soup.find_all(BLOCK_TAGS):
            if element.find_parent(BLOCK_TAGS) is not None:
                continue
            text = _clean_text(element.get_text(" ", strip=True))
            if not text:
                continue
            if heading is None and element.name in {"h1", "h2", "h3"}:
                if len(text) <= 90:
                    heading = text
                    continue
            paragraphs.append(text)
        if not paragraphs:
            continue
        chapters.append((heading, paragraphs))
    if not chapters:
        raise BookImportError("No readable chapter found in the EPUB.")
    return chapters


def _example_sentence(text: str, word: str) -> str:
    needle = normalize(word)
    for sentence in SENTENCE_RE.split(text):
        if needle in [normalize(token) for token in TOKEN_RE.findall(sentence)]:
            return sentence.strip()
    return text.strip()


def _vocabulary_entry(
    key: str,
    display: str,
    data: dict[str, Any],
    paragraph_text: str,
    level: str,
) -> dict[str, Any]:
    cefr = str(data.get("cefr") or level).lower()
    if cefr not in LEVELS:
        cefr = level
    example = _example_sentence(paragraph_text, display)
    return {
        "id": key,
        "word": str(data.get("word") or display),
        "partOfSpeech": str(data.get("partOfSpeech") or "word"),
        "phonetic": str(data.get("phonetic") or ""),
        "definitionEn": str(data.get("definitionEn") or ""),
        "translationFr": str(data.get("translationFr") or ""),
        "example": example,
        "cefr": cefr,
    }


def _select_words(
    texts: list[str],
    lexicon: dict[str, dict[str, Any]],
    known_words: set[str],
    limit: int,
) -> list[tuple[str, str, str]]:
    """Return (key, display, paragraph text) in first-occurrence order."""
    selected: list[tuple[str, str, str]] = []
    seen: set[str] = set()
    if limit == 0:
        return selected
    for text in texts:
        for match in TOKEN_RE.finditer(text):
            key = normalize(match.group(0))
            if len(key) <= 2 or key in known_words or key in seen:
                continue
            if key not in lexicon:
                continue
            seen.add(key)
            selected.append((key, match.group(0), text))
            if len(selected) >= limit:
                return selected
    return selected


def _segments(text: str, vocab_ids: dict[str, str]) -> list[dict[str, str]]:
    pieces: list[dict[str, str]] = []
    annotated: set[str] = set()
    cursor = 0
    for match in TOKEN_RE.finditer(text):
        key = normalize(match.group(0))
        vocab_id = vocab_ids.get(key)
        if vocab_id is None or vocab_id in annotated:
            continue
        if match.start() > cursor:
            pieces.append({"text": text[cursor : match.start()]})
        pieces.append({"text": match.group(0), "vocabId": vocab_id})
        annotated.add(vocab_id)
        cursor = match.end()
    if cursor < len(text):
        pieces.append({"text": text[cursor:]})

    merged: list[dict[str, str]] = []
    for piece in pieces:
        if (
            merged
            and "vocabId" not in piece
            and "vocabId" not in merged[-1]
        ):
            merged[-1]["text"] += piece["text"]
        else:
            merged.append(piece)
    if not merged:
        merged.append({"text": text})
    return merged


def build_chapters(
    extracted: list[tuple[str | None, list[str]]],
    lexicon: dict[str, dict[str, Any]],
    options: ImportOptions,
) -> list[dict[str, Any]]:
    chapters: list[dict[str, Any]] = []
    known_words: set[str] = set()
    for index, (heading, texts) in enumerate(extracted, start=1):
        chapter_id = f"chapter-{index:02d}"
        selected = _select_words(
            texts, lexicon, known_words, options.max_new_words
        )
        known_words.update(key for key, _display, _text in selected)
        vocab_ids = {key: key for key, _display, _text in selected}
        vocabulary = [
            _vocabulary_entry(key, display, lexicon[key], text, options.level)
            for key, display, text in selected
        ]
        paragraphs = [
            {"id": f"p-{position:02d}", "segments": _segments(text, vocab_ids)}
            for position, text in enumerate(texts, start=1)
        ]
        token_count = sum(
            len(TOKEN_RE.findall(text)) for text in texts
        )
        minutes = max(1, min(30, round(token_count / WORDS_PER_MINUTE)))
        chapters.append(
            {
                "schemaVersion": 1,
                "id": chapter_id,
                "bookId": options.book_id,
                "number": index,
                "title": heading or f"Chapitre {index}",
                "level": options.level,
                "paragraphs": paragraphs,
                "vocabulary": vocabulary,
                "estimatedMinutes": minutes,
                "newWordCount": len(vocabulary),
            }
        )
    return chapters


def build_manifest(
    chapters: list[dict[str, Any]], options: ImportOptions
) -> dict[str, Any]:
    return {
        "schemaVersion": 1,
        "packVersion": options.pack_version,
        "id": options.book_id,
        "title": options.title,
        "titleFr": options.title_fr,
        "author": options.author,
        "level": options.level,
        "descriptionFr": options.description_fr,
        "chapters": [
            {
                "id": chapter["id"],
                "number": chapter["number"],
                "title": chapter["title"],
                "asset": f"chapters/{chapter['id']}.json",
                "estimatedMinutes": chapter["estimatedMinutes"],
                "newWordCount": chapter["newWordCount"],
            }
            for chapter in chapters
        ],
    }


def _write_json(path: Path, payload: dict[str, Any]) -> None:
    path.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


def write_pack(
    output_dir: Path,
    manifest: dict[str, Any],
    chapters: list[dict[str, Any]],
) -> None:
    chapters_dir = output_dir / "chapters"
    if chapters_dir.exists():
        shutil.rmtree(chapters_dir)
    chapters_dir.mkdir(parents=True)
    for chapter in chapters:
        payload = dict(chapter)
        payload.pop("estimatedMinutes", None)
        payload.pop("newWordCount", None)
        _write_json(chapters_dir / f"{chapter['id']}.json", payload)
    _write_json(output_dir / "manifest.json", manifest)


async def add_audio(
    output_dir: Path,
    chapters: list[dict[str, Any]],
    options: ImportOptions,
) -> None:
    audio_dir = output_dir / "audio"
    if audio_dir.exists():
        shutil.rmtree(audio_dir)
    audio_dir.mkdir(parents=True)
    for chapter in chapters:
        texts = [
            "".join(segment["text"] for segment in paragraph["segments"])
            for paragraph in chapter["paragraphs"]
        ]
        tokens = [
            match.group(0) for text in texts for match in TOKEN_RE.finditer(text)
        ]
        full_text = "\n\n".join(texts)
        audio, boundaries = await synthesize(full_text, options.rate, options.voice)
        timings = align(tokens, boundaries)
        fallback_ms = timings[-1]["endMs"] + 400
        filename = f"{chapter['id']}.mp3"
        audio_path = audio_dir / filename
        audio_path.write_bytes(audio)
        duration_ms = probe_duration_ms(audio_path, fallback_ms)
        chapter["schemaVersion"] = 2
        chapter["audio"] = {
            "asset": f"assets/content/{options.book_id}/audio/{filename}",
            "durationMs": duration_ms,
            "voice": options.voice,
            "words": timings,
        }


async def import_epub(
    epub_path: Path,
    output_dir: Path,
    options: ImportOptions,
    lexicon_path: Path = DEFAULT_LEXICON,
    with_audio: bool = False,
) -> tuple[dict[str, Any], list[dict[str, Any]]]:
    options = options.normalized()
    lexicon = load_lexicon(lexicon_path)
    extracted = extract_chapters(epub_path)
    chapters = build_chapters(extracted, lexicon, options)
    if with_audio:
        await add_audio(output_dir, chapters, options)
    manifest = build_manifest(chapters, options)
    write_pack(output_dir, manifest, chapters)
    return manifest, chapters


def _default_title(epub_path: Path) -> tuple[str, str]:
    book = epub.read_epub(str(epub_path), options={"ignore_ncx": True})
    titles = book.get_metadata("DC", "title")
    creators = book.get_metadata("DC", "creator")
    title = _clean_text(titles[0][0]) if titles else epub_path.stem
    author = _clean_text(creators[0][0]) if creators else ""
    return title, author


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("epub", type=Path, help="EPUB file to import.")
    parser.add_argument("--book-id", required=True, help="Pack id.")
    parser.add_argument(
        "--output",
        type=Path,
        default=None,
        help="Output pack folder (default: CONTENT_DIR/<book-id>).",
    )
    parser.add_argument(
        "--content-dir",
        type=Path,
        default=None,
        help="Override STORYLINGO_CONTENT_DIR for publication.",
    )
    parser.add_argument(
        "--no-publish",
        action="store_true",
        help="Only generate the pack; do not write the catalogue row.",
    )
    access = parser.add_mutually_exclusive_group()
    access.add_argument(
        "--free",
        dest="is_free",
        action="store_true",
        default=None,
        help="Publish the book as free (default: paid for new books).",
    )
    access.add_argument(
        "--paid",
        dest="is_free",
        action="store_false",
        help="Publish the book behind the subscription.",
    )
    parser.add_argument("--title", default=None)
    parser.add_argument("--title-fr", default=None)
    parser.add_argument("--author", default=None)
    parser.add_argument("--level", default="A2")
    parser.add_argument("--description-fr", default="")
    parser.add_argument("--pack-version", default="1.0.0")
    parser.add_argument(
        "--max-new-words",
        type=int,
        default=8,
        help="New vocabulary words annotated per chapter (default: 8).",
    )
    parser.add_argument("--lexicon", type=Path, default=DEFAULT_LEXICON)
    parser.add_argument(
        "--audio",
        action="store_true",
        help="Generate MP3 audio and word timings with edge-tts.",
    )
    parser.add_argument("--voice", default=VOICE)
    parser.add_argument("--rate", default="+0%")
    args = parser.parse_args(argv)

    if not args.epub.is_file():
        parser.error(f"EPUB not found: {args.epub}")

    from server.app.config import Settings

    settings = Settings.from_env(ROOT)
    content_dir = args.content_dir or settings.content_dir
    output_dir = args.output or content_dir / args.book_id

    metadata_title, metadata_author = _default_title(args.epub)
    title = args.title or metadata_title or args.book_id
    options = ImportOptions(
        book_id=args.book_id,
        title=title,
        title_fr=args.title_fr or title,
        author=args.author or metadata_author,
        level=args.level,
        description_fr=args.description_fr,
        pack_version=args.pack_version,
        max_new_words=args.max_new_words,
        voice=args.voice,
        rate=args.rate,
    )
    try:
        manifest, chapters = asyncio.run(
            import_epub(
                args.epub,
                output_dir,
                options,
                lexicon_path=args.lexicon,
                with_audio=args.audio,
            )
        )
    except BookImportError as error:
        parser.error(str(error))
        return 2
    except RuntimeError as error:
        print(f"Import failed: {error}", file=sys.stderr)
        return 1

    access_label = "unpublished"
    if not args.no_publish:
        from server.app.db import Base, make_engine, make_session_factory
        from server.app.packs import PackError, publish_pack

        engine = make_engine(settings.database_url)
        Base.metadata.create_all(engine)
        factory = make_session_factory(engine)
        try:
            with factory() as session:
                book = publish_pack(
                    output_dir, content_dir, session, is_free=args.is_free
                )
                access_label = "free" if book.is_free else "paid"
        except PackError as error:
            print(f"Publication failed: {error}", file=sys.stderr)
            return 1

    words = sum(chapter["newWordCount"] for chapter in chapters)
    minutes = sum(chapter["estimatedMinutes"] for chapter in chapters)
    print(
        f"Imported {manifest['id']} v{manifest['packVersion']}: "
        f"{len(chapters)} chapters, {words} new words, ~{minutes} min "
        f"-> {output_dir}"
    )
    if args.audio:
        print("Audio: generated for every chapter.")
    if not args.no_publish:
        print(f"Published catalogue row into {content_dir} ({access_label}).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
