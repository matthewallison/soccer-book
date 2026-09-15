#!/usr/bin/env bash
# Builds one EPUB from the transcripts for ElevenLabs Studio import (one Heading 1 = one chapter).
set -euo pipefail
cd "$(dirname "$0")"

# --wrap=none keeps audio tags like [long pause] on one line; -smart keeps quotes as written.
pandoc transcript/*.md \
  --from markdown-smart \
  --wrap=none \
  --split-level=1 \
  --epub-title-page=false \
  --metadata title="Soccer Development Handbook: Player Audio Edition" \
  --metadata lang=en-US \
  --output soccer-handbook-player-audio.epub

echo "Built audio/soccer-handbook-player-audio.epub"
