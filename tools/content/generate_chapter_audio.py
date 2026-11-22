"""Generate chapter audio and word timings for a Storylingo pack.

Development-time tool: synthesizes the chapter text with edge-tts
(word boundaries), aligns the boundaries to the chapter tokens, writes
the MP3 into the pack and injects the `audio` block into the chapter
JSON (schemaVersion 2).

The app itself never calls this pipeline: it only reads the committed
asset and timings, fully offline.

Usage:
    python tools/content/generate_chapter_audio.py
    python tools/content/generate_chapter_audio.py --chapter chapter-02
    python tools/content/generate_chapter_audio.py --chapter chapter-03 \\
        --pack-version 1.3.0
    python tools/content/generate_chapter_audio.py --rate +5%
"""

from __future__ import annotations

import argparse
import asyncio
import json
import re
from pathlib import Path

try:
    from tools.content.audio_pipeline import (
        VOICE,
        align,
        chapter_tokens,
        paragraph_texts,
        probe_duration_ms,
        synthesize,
    )
except ImportError:  # Running the script directly from tools/content.
    import sys

    sys.path.insert(0, str(Path(__file__).resolve().parent))
    from audio_pipeline import (  # type: ignore[no-redef]
        VOICE,
        align,
        chapter_tokens,
        paragraph_texts,
        probe_duration_ms,
        synthesize,
    )

ROOT = Path(__file__).resolve().parents[2]
PACK_DIR = ROOT / "assets" / "content" / "sleepy-hollow-a2"
MANIFEST = PACK_DIR / "manifest.json"


def bump_pack_version(manifest: dict) -> str:
    major, minor, _patch = (
        int(part) for part in manifest["packVersion"].split(".")
    )
    version = f"{major}.{minor + 1}.0"
    manifest["packVersion"] = version
    return version


def resolve_pack_version(manifest: dict, requested: str | None) -> str:
    if requested is None:
        return bump_pack_version(manifest)
    if not re.fullmatch(r"\d+\.\d+\.\d+", requested):
        raise SystemExit(f"Invalid --pack-version: {requested!r}.")
    manifest["packVersion"] = requested
    return requested


def write_json(path: Path, payload: dict) -> None:
    path.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


async def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--chapter",
        default="chapter-01",
        help="Chapter id to synthesize (default: chapter-01)",
    )
    parser.add_argument("--rate", default="+0%", help="edge-tts rate, e.g. +5%%")
    parser.add_argument(
        "--pack-version",
        default=None,
        help="Set an explicit pack version instead of bumping the minor one",
    )
    parser.add_argument(
        "--skip-synthesis",
        action="store_true",
        help="Reuse the existing MP3 and only re-inject timings.",
    )
    args = parser.parse_args()

    chapter_path = PACK_DIR / "chapters" / f"{args.chapter}.json"
    if not chapter_path.exists():
        raise SystemExit(f"Unknown chapter: {chapter_path}")
    audio_relative = (
        f"assets/content/sleepy-hollow-a2/audio/{args.chapter}.mp3"
    )
    audio_path = ROOT / audio_relative
    boundaries_cache = ROOT / ".tmp" / f"audio-boundaries-{args.chapter}.json"

    chapter = json.loads(chapter_path.read_text(encoding="utf-8"))
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    tokens = chapter_tokens(chapter)
    text = "\n\n".join(paragraph_texts(chapter))
    print(f"Chapter tokens: {len(tokens)} | characters: {len(text)}")

    if args.skip_synthesis:
        if not audio_path.exists():
            raise SystemExit("--skip-synthesis requires an existing MP3.")
        boundaries = json.loads(
            boundaries_cache.read_text(encoding="utf-8")
        )["boundaries"]
    else:
        print("Synthesizing with edge-tts...")
        try:
            audio, boundaries = await synthesize(text, args.rate)
        except RuntimeError as error:
            raise SystemExit(str(error)) from error

    try:
        timings = align(tokens, boundaries)
    except RuntimeError as error:
        raise SystemExit(str(error)) from error
    fallback_ms = timings[-1]["endMs"] + 400
    if not args.skip_synthesis:
        audio_path.parent.mkdir(parents=True, exist_ok=True)
        audio_path.write_bytes(audio)
        boundaries_cache.parent.mkdir(parents=True, exist_ok=True)
        boundaries_cache.write_text(
            json.dumps({"boundaries": boundaries}, ensure_ascii=False),
            encoding="utf-8",
        )
    duration_ms = probe_duration_ms(audio_path, fallback_ms)

    chapter["schemaVersion"] = 2
    chapter["audio"] = {
        "asset": audio_relative,
        "durationMs": duration_ms,
        "voice": VOICE,
        "words": timings,
    }
    version = resolve_pack_version(manifest, args.pack_version)
    write_json(chapter_path, chapter)
    write_json(MANIFEST, manifest)

    print(
        f"Audio: {audio_relative} | duration: {duration_ms} ms | "
        f"timings: {len(timings)} | packVersion: {version}"
    )


if __name__ == "__main__":
    asyncio.run(main())
