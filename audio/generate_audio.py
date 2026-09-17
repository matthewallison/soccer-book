#!/usr/bin/env python3
"""Generate audiobook tracks from audio/transcript/*.md with ElevenLabs.

This script is deliberately conservative. The audiobook source is already edited for
speech, so the generator should not rewrite prose, expand abbreviations, or otherwise
"improve" the text. Its job is mechanical:

1. Read one or more transcript Markdown files.
2. Convert the leading Markdown title into clean spoken audiobook text. We want the
   listener to hear the title; we do not want Markdown syntax such as a leading '#'.
3. Split long chapters at paragraph boundaries so each Eleven v3 request stays under
   its text limit.
4. Send each chunk to ElevenLabs using one consistent voice/model/output format.
5. Cache every generated chunk locally. If generation is interrupted, or if we rerun
   an unchanged chapter, we do not pay to synthesize the same chunk again.
6. Join the chunk MP3s losslessly with ffmpeg into one finished MP3 per track.

The cache key includes the exact text plus every setting that can change the audio.
That matters for both reproducibility and cost: changing the voice, model, output
format, or speed should create a new cached generation rather than silently reusing
old audio.

Requirements:
    python -m pip install elevenlabs
    ffmpeg                         # e.g. `brew install ffmpeg` on macOS

Authentication:
    export ELEVENLABS_API_KEY='...'

Do NOT put an API key in this file or commit one to Git.

Examples:
    # Dry-run the whole book: show chunks and character counts, spend nothing.
    python audio/generate_audio.py --dry-run

    # Generate one pilot chapter for listening QA.
    python audio/generate_audio.py 05-how-we-play

    # Generate a position card as a second pilot.
    python audio/generate_audio.py 11-center-back

    # Once the voice and pacing are approved, generate every track.
    python audio/generate_audio.py --all

    # Override the configured voice without editing this file.
    python audio/generate_audio.py 05-how-we-play --voice-id YOUR_VOICE_ID

Finished files go to docs/audio/<track>.mp3. Intermediate chunks go to
.audio-cache/ at the repository root and are intentionally local build artifacts.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Iterable


# ---------------------------------------------------------------------------
# Project paths
# ---------------------------------------------------------------------------

AUDIO_DIR = Path(__file__).resolve().parent
REPO_ROOT = AUDIO_DIR.parent
TRANSCRIPT_DIR = AUDIO_DIR / "transcript"
OUTPUT_DIR = REPO_ROOT / "docs" / "audio"
CACHE_DIR = REPO_ROOT / ".audio-cache"


# ---------------------------------------------------------------------------
# Narration defaults
# ---------------------------------------------------------------------------

# Eleven v3 is the expressive model chosen for this player audiobook. The official
# ElevenLabs documentation currently describes a 5,000-character input limit for v3.
# We stay comfortably below that instead of packing requests to the exact boundary.
MODEL_ID = "eleven_v3"
MAX_CHARS = 4_500

# 44.1 kHz / 128 kbps MP3 is a good final-delivery format for spoken audio and does
# not require us to transcode after generation. Keeping every chunk in exactly the
# same format also lets ffmpeg concatenate them without re-encoding.
OUTPUT_FORMAT = "mp3_44100_128"

# The project README currently identifies Amelia as the working narration voice and
# records this ID. Keep it as a default for convenience, but --voice-id exists so we
# can audition and switch voices without editing source code.
DEFAULT_VOICE_ID = "ZF6FPAbjXT4488VcRRnw"

# We intentionally do not override stability/similarity/style here. For v3, the
# transcript's audio tags and the selected voice do much of the expressive work, and
# leaving voice settings unset uses the voice's configured defaults. Speed can still
# be explicitly supplied if listening tests show the narration needs adjustment.
DEFAULT_SPEED = 1.0


# ---------------------------------------------------------------------------
# Transcript preparation
# ---------------------------------------------------------------------------

def load_transcript(path: Path) -> str:
    """Load a transcript and make its Markdown H1 safe to narrate.

    The title is real audiobook content, so it should be spoken. The Markdown marker
    is merely source formatting, so it should not be sent to TTS. For example:

        # How We Play, and How You Learn It

    becomes:

        How We Play, and How You Learn It

    We deliberately do *not* invent spoken chapter numbers here. The transcript is
    the source of truth for what the listener hears; the filename already supplies
    ordering and the player/website supplies track metadata. Position-card titles are
    therefore handled naturally too: their descriptive title is spoken without an
    artificial "Chapter Eleven" prefix.

    Everything after the H1 is preserved exactly, including Eleven v3 audio tags such
    as [pause], [long pause], and [slows down]. The blank line after the title gives
    the model a natural beat before the opening narration.
    """
    text = path.read_text(encoding="utf-8").replace("\r\n", "\n").strip()

    # Remove only the Markdown syntax from the first H1. Do not remove the title
    # itself. If a transcript somehow has no H1, leave it untouched rather than
    # guessing what its title ought to be.
    text = re.sub(r"^#\s+(.+?)\n+", r"\1\n\n", text, count=1)
    return text.strip()


def split_oversize_paragraph(paragraph: str, limit: int) -> list[str]:
    """Split an unusually long paragraph, preferring sentence boundaries.

    Our edited transcripts normally contain short paragraphs, so this is a safety
    valve rather than the normal path. We never silently truncate text. If even one
    sentence exceeds the limit, we fall back to whitespace boundaries.
    """
    if len(paragraph) <= limit:
        return [paragraph]

    # Keep punctuation attached to the sentence that precedes it. This is not meant
    # to be a full linguistic sentence parser; it is simply a narration-safe fallback.
    sentences = re.split(r"(?<=[.!?])\s+", paragraph)
    pieces: list[str] = []
    current = ""

    for sentence in sentences:
        if len(sentence) > limit:
            # Flush anything already accumulated, then split this giant sentence on
            # words. A transcript this unusual should still generate rather than fail.
            if current:
                pieces.append(current)
                current = ""
            words = sentence.split()
            word_chunk = ""
            for word in words:
                candidate = f"{word_chunk} {word}".strip()
                if len(candidate) > limit and word_chunk:
                    pieces.append(word_chunk)
                    word_chunk = word
                else:
                    word_chunk = candidate
            if word_chunk:
                pieces.append(word_chunk)
            continue

        candidate = f"{current} {sentence}".strip()
        if len(candidate) > limit and current:
            pieces.append(current)
            current = sentence
        else:
            current = candidate

    if current:
        pieces.append(current)
    return pieces


def chunk_transcript(text: str, limit: int = MAX_CHARS) -> list[str]:
    """Pack complete paragraphs into API-sized chunks.

    Paragraph boundaries are important to narration. They are natural places for the
    model to reset, and splitting there avoids cutting a thought or an audio direction
    in half. We preserve a blank line between packed paragraphs.
    """
    raw_paragraphs = [p.strip() for p in re.split(r"\n\s*\n", text) if p.strip()]
    paragraphs: list[str] = []
    for paragraph in raw_paragraphs:
        paragraphs.extend(split_oversize_paragraph(paragraph, limit))

    chunks: list[str] = []
    current = ""
    for paragraph in paragraphs:
        candidate = f"{current}\n\n{paragraph}".strip() if current else paragraph
        if len(candidate) > limit and current:
            chunks.append(current)
            current = paragraph
        else:
            current = candidate
    if current:
        chunks.append(current)

    if any(len(chunk) > limit for chunk in chunks):
        raise RuntimeError("Internal error: a narration chunk still exceeds the limit")
    return chunks


# ---------------------------------------------------------------------------
# Cache and API generation
# ---------------------------------------------------------------------------

def cache_key(text: str, voice_id: str, speed: float) -> str:
    """Return a stable hash for every input that can materially change the audio."""
    payload = {
        "text": text,
        "voice_id": voice_id,
        "model_id": MODEL_ID,
        "output_format": OUTPUT_FORMAT,
        "speed": speed,
    }
    encoded = json.dumps(payload, sort_keys=True, ensure_ascii=False).encode("utf-8")
    return hashlib.sha256(encoded).hexdigest()


def write_audio_stream(response: Iterable[bytes], destination: Path) -> None:
    """Write the byte iterator returned by the ElevenLabs Python SDK."""
    with destination.open("wb") as fh:
        for block in response:
            if block:
                fh.write(block)


def synthesize_chunk(client, text: str, voice_id: str, speed: float) -> Path:
    """Generate one chunk, or return its existing local cache entry.

    We write to a temporary file and atomically rename it only after the API response
    has completed. That way an interrupted request never masquerades as a valid cached
    MP3 on the next run.
    """
    key = cache_key(text, voice_id, speed)
    cached = CACHE_DIR / f"{key}.mp3"
    if cached.exists() and cached.stat().st_size > 0:
        print(f"      cache hit {key[:10]}")
        return cached

    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    temporary = CACHE_DIR / f".{key}.tmp"

    # Import lazily so --dry-run works even on a machine where the SDK has not yet
    # been installed. VoiceSettings is used only for speed; the other settings remain
    # at the selected voice's defaults.
    from elevenlabs import VoiceSettings

    print(f"      generating {len(text):,} chars ({key[:10]})")
    response = client.text_to_speech.convert(
        voice_id=voice_id,
        text=text,
        model_id=MODEL_ID,
        output_format=OUTPUT_FORMAT,
        voice_settings=VoiceSettings(speed=speed),
    )
    write_audio_stream(response, temporary)
    temporary.replace(cached)
    return cached


# ---------------------------------------------------------------------------
# MP3 assembly
# ---------------------------------------------------------------------------

def require_ffmpeg() -> str:
    """Find ffmpeg before we spend money generating chunks we cannot assemble."""
    ffmpeg = shutil.which("ffmpeg")
    if not ffmpeg:
        raise SystemExit(
            "ffmpeg was not found. Install it first (for example: brew install ffmpeg)."
        )
    return ffmpeg


def concatenate_mp3s(ffmpeg: str, chunk_files: list[Path], destination: Path) -> None:
    """Losslessly concatenate identically encoded MP3 chunks with ffmpeg.

    The concat demuxer copies the already-generated MP3 audio (`-c copy`) rather than
    decoding and re-encoding it, so joining chunks does not reduce narration quality.
    """
    destination.parent.mkdir(parents=True, exist_ok=True)

    if len(chunk_files) == 1:
        shutil.copy2(chunk_files[0], destination)
        return

    with tempfile.NamedTemporaryFile("w", suffix=".txt", encoding="utf-8", delete=False) as fh:
        list_path = Path(fh.name)
        for chunk in chunk_files:
            # ffmpeg concat files use single-quoted paths. Escape a literal quote using
            # the shell-compatible sequence documented for concat list files.
            escaped = str(chunk.resolve()).replace("'", "'\\''")
            fh.write(f"file '{escaped}'\n")

    try:
        subprocess.run(
            [ffmpeg, "-hide_banner", "-loglevel", "error", "-y", "-f", "concat",
             "-safe", "0", "-i", str(list_path), "-c", "copy", str(destination)],
            check=True,
        )
    finally:
        list_path.unlink(missing_ok=True)


# ---------------------------------------------------------------------------
# Command-line workflow
# ---------------------------------------------------------------------------

def transcript_files(requested: list[str], generate_all: bool) -> list[Path]:
    """Resolve track names like '05-how-we-play' to transcript Markdown files."""
    available = sorted(TRANSCRIPT_DIR.glob("[0-9][0-9]-*.md"))
    if generate_all or not requested:
        return available

    by_stem = {path.stem: path for path in available}
    resolved: list[Path] = []
    for name in requested:
        stem = name[:-3] if name.endswith(".md") else name
        if stem not in by_stem:
            choices = "\n  ".join(by_stem)
            raise SystemExit(f"Unknown track: {name}\nAvailable tracks:\n  {choices}")
        resolved.append(by_stem[stem])
    return resolved


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Generate Soccer Development Handbook audio with ElevenLabs."
    )
    parser.add_argument(
        "tracks", nargs="*", help="Track stems, e.g. 05-how-we-play 11-center-back"
    )
    parser.add_argument(
        "--all", action="store_true", help="Generate all transcript tracks."
    )
    parser.add_argument(
        "--dry-run", action="store_true",
        help="Show chunking and character totals without calling ElevenLabs."
    )
    parser.add_argument(
        "--voice-id", default=os.getenv("ELEVENLABS_VOICE_ID", DEFAULT_VOICE_ID),
        help="ElevenLabs voice ID (or set ELEVENLABS_VOICE_ID)."
    )
    parser.add_argument(
        "--speed", type=float, default=DEFAULT_SPEED,
        help="Narration speed; default 1.0. Change only after listening tests."
    )
    parser.add_argument(
        "--max-chars", type=int, default=MAX_CHARS,
        help=f"Maximum characters per API request; default {MAX_CHARS}."
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    tracks = transcript_files(args.tracks, args.all)
    if not tracks:
        raise SystemExit(f"No transcripts found in {TRANSCRIPT_DIR}")

    prepared: list[tuple[Path, list[str]]] = []
    total_chars = 0

    # Always do the entire preparation pass first. This gives us a useful cost/size
    # summary before the first paid request and catches chunking problems early.
    for path in tracks:
        text = load_transcript(path)
        chunks = chunk_transcript(text, args.max_chars)
        prepared.append((path, chunks))
        chars = sum(len(chunk) for chunk in chunks)
        total_chars += chars
        sizes = ", ".join(f"{len(chunk):,}" for chunk in chunks)
        print(f"{path.stem}: {chars:,} chars -> {len(chunks)} chunk(s) [{sizes}]")

    print(f"\nTotal text sent to TTS: {total_chars:,} characters")
    if args.dry_run:
        print("Dry run only: no API calls were made and no audio was generated.")
        return 0

    api_key = os.getenv("ELEVENLABS_API_KEY")
    if not api_key:
        raise SystemExit(
            "ELEVENLABS_API_KEY is not set. Export it in your shell; never commit it."
        )

    # Validate ffmpeg before making paid API calls.
    ffmpeg = require_ffmpeg()

    try:
        from elevenlabs.client import ElevenLabs
    except ImportError as exc:
        raise SystemExit(
            "The ElevenLabs Python SDK is not installed. Run: python -m pip install elevenlabs"
        ) from exc

    client = ElevenLabs(api_key=api_key)

    for path, chunks in prepared:
        print(f"\nGenerating {path.stem}")
        generated: list[Path] = []
        for index, chunk in enumerate(chunks, start=1):
            print(f"  chunk {index}/{len(chunks)}")
            generated.append(synthesize_chunk(client, chunk, args.voice_id, args.speed))

        destination = OUTPUT_DIR / f"{path.stem}.mp3"
        concatenate_mp3s(ffmpeg, generated, destination)
        print(f"  wrote {destination.relative_to(REPO_ROOT)}")

    print("\nDone. Listen before committing generated MP3s; narration QA is the final edit pass.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
