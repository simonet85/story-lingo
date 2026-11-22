"""Shared edge-tts synthesis and token alignment helpers.

Used by the pilot audio generator and by the EPUB import CLI. The pipeline
is deterministic once the TTS boundaries are known; timings are aligned to
the chapter tokens using a difflib sequence matcher.
"""

from __future__ import annotations

import difflib
import re
import subprocess
from pathlib import Path

import edge_tts

VOICE = "en-US-AriaNeural"
TOKEN_RE = re.compile(r"[A-Za-z0-9]+(?:[’'][A-Za-z0-9]+)*[’']?")
WORD_BOUNDARY_RE = re.compile(r"[A-Za-z0-9]+(?:[’'][A-Za-z0-9]+)*")


def normalize(word: str) -> str:
    word = word.replace("’", "'").lower()
    word = "".join(char for char in word if char.isalnum() or char == "'")
    return word.rstrip("'")


def paragraph_texts(chapter: dict) -> list[str]:
    return [
        "".join(segment["text"] for segment in paragraph["segments"])
        for paragraph in chapter["paragraphs"]
    ]


def chapter_tokens(chapter: dict) -> list[str]:
    tokens: list[str] = []
    for text in paragraph_texts(chapter):
        tokens.extend(match.group(0) for match in TOKEN_RE.finditer(text))
    return tokens


async def synthesize(
    text: str, rate: str, voice: str = VOICE
) -> tuple[bytes, list[dict]]:
    communicate = edge_tts.Communicate(
        text,
        voice,
        rate=rate,
        boundary="WordBoundary",
    )
    audio = bytearray()
    boundaries: list[dict] = []
    async for chunk in communicate.stream():
        if chunk["type"] == "audio":
            audio.extend(chunk["data"])
        elif chunk["type"] == "WordBoundary":
            start_ms = round(chunk["offset"] / 10_000)
            end_ms = round((chunk["offset"] + chunk["duration"]) / 10_000)
            boundaries.append(
                {
                    "text": chunk["text"],
                    "startMs": start_ms,
                    "endMs": max(start_ms + 1, end_ms),
                }
            )
    if not audio:
        raise RuntimeError("edge-tts returned no audio.")
    return bytes(audio), boundaries


def split_boundaries(boundaries: list[dict]) -> list[dict]:
    """Split a TTS boundary covering several words (e.g. "The road")."""
    expanded: list[dict] = []
    for boundary in boundaries:
        parts = WORD_BOUNDARY_RE.findall(boundary["text"])
        if not parts:
            continue
        span = boundary["endMs"] - boundary["startMs"]
        total_chars = sum(len(part) for part in parts)
        cursor = boundary["startMs"]
        cumulative = 0
        for index, part in enumerate(parts):
            cumulative += len(part)
            end = boundary["startMs"] + round(span * cumulative / total_chars)
            if index == len(parts) - 1:
                end = boundary["endMs"]
            expanded.append(
                {
                    "text": part,
                    "startMs": cursor,
                    "endMs": max(cursor + 1, end),
                }
            )
            cursor = expanded[-1]["endMs"]
    return expanded


def align(tokens: list[str], boundaries: list[dict]) -> list[dict]:
    expanded = split_boundaries(boundaries)
    left = [normalize(token) for token in tokens]
    right = [normalize(word["text"]) for word in expanded]

    matched: list[dict | None] = [None] * len(tokens)
    matcher = difflib.SequenceMatcher(a=left, b=right, autojunk=False)
    problems: list[str] = []
    for tag, i1, i2, j1, j2 in matcher.get_opcodes():
        if tag == "equal" or (tag == "replace" and i2 - i1 == j2 - j1):
            for offset in range(i2 - i1):
                matched[i1 + offset] = expanded[j1 + offset]
        elif tag == "insert":
            continue
        else:
            problems.append(
                f"{tag}: tokens {tokens[i1:i2]} vs boundaries "
                f"{[w['text'] for w in expanded[j1:j2]]}"
            )

    if problems:
        raise RuntimeError(
            "Unable to align chapter tokens with audio boundaries:\n  "
            + "\n  ".join(problems)
        )
    if any(item is None for item in matched):
        missing = [index for index, item in enumerate(matched) if item is None]
        raise RuntimeError(f"No timing for tokens at indices {missing}.")

    timings: list[dict] = []
    previous_start = -1
    for token, window in zip(tokens, matched):
        assert window is not None
        start_ms = window["startMs"]
        end_ms = window["endMs"]
        if start_ms <= previous_start:
            raise RuntimeError(
                f"Non-monotonic timing at token {token!r}: "
                f"{start_ms} after {previous_start}."
            )
        if end_ms <= start_ms:
            raise RuntimeError(f"Empty timing at token {token!r}.")
        previous_start = start_ms
        timings.append({"text": token, "startMs": start_ms, "endMs": end_ms})
    return timings


def probe_duration_ms(path: Path, fallback_ms: int) -> int:
    try:
        result = subprocess.run(
            [
                "ffprobe",
                "-v",
                "error",
                "-show_entries",
                "format=duration",
                "-of",
                "default=noprint_wrappers=1:nokey=1",
                str(path),
            ],
            capture_output=True,
            text=True,
            check=True,
        )
        return round(float(result.stdout.strip()) * 1000)
    except (OSError, subprocess.SubprocessError, ValueError):
        return fallback_ms
