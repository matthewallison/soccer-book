#!/usr/bin/env bash
# Build the printable handbook PDF from the Markdown sources.
# Usage: print/build.sh [output.pdf]
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PRINT="$ROOT/print"
OUT="${1:-$ROOT/soccer-development-handbook.pdf}"
BUILD="$(mktemp -d)"
trap 'rm -rf "$BUILD"' EXIT

INCLUDED=()

# Emit a Markdown file, tagging its first H1 with an anchor (#ch-<basename>)
# so cross-document links resolve inside the PDF.
chapter() {
  local file="$1" id
  INCLUDED+=("$file")
  id="ch-$(basename "$file" .md)"
  awk -v id="$id" '!done && /^# / { print $0 " {#" id "}"; done = 1; next } { print }' "$ROOT/$file"
  printf '\n\n'
}

latex() { printf '\n```{=latex}\n%s\n```\n\n' "$1"; }

{
  latex '\frontmatter'
  latex '\tableofcontents'
  latex '\mainmatter'
  chapter README.md

  latex '\hbpart{part-players}{Part one}{For Players}{The principles, language, and habits every player should own.}'
  latex '\hbsetlabel{For players}'
  chapter docs/player-philosophy.md
  chapter docs/team-culture-and-leadership.md
  chapter docs/injuries-and-return-to-play.md
  chapter docs/communication-and-movement.md
  chapter docs/film-review-guide.md
  chapter docs/home-development.md

  latex '\hbpart{part-positions}{Part two}{Position Cards}{One-page references to review before every match. Numbers follow the common 1–11 system; the right side takes the lower number.}'
  latex '\hbsetlabel{Position card}\newgeometry{top=0.6in, bottom=0.62in, left=0.62in, right=0.62in, headsep=0.18in, footskip=0.3in}'
  for card in goalkeeper outside-back center-back defensive-midfield winger striker attacking-midfield; do
    chapter "docs/positions/$card.md"
  done
  latex '\restoregeometry'

  latex '\hbpart{part-coaches}{Part three}{For Coaches and Parents}{The game model, the development system, and how families and coaches work together.}'
  latex '\hbsetlabel{For coaches}'
  chapter docs/coaching-game-model.md
  latex '\hbsetlabel{For coaches and parents}'
  chapter docs/good-coaching-signs.md
  latex '\hbsetlabel{For parents}'
  chapter docs/parent-partnership.md

  latex '\hbpart{part-resources}{Part four}{Templates and Resources}{Printable forms and the sources behind this handbook.}'
  latex '\hbsetlabel{Template}'
  chapter docs/templates/weekend-role-sheet.md
  chapter docs/templates/game-reflection.md
  chapter docs/templates/development-plan.md
  latex '\hbsetlabel{Resources}'
  chapter docs/further-reading.md
} > "$BUILD/handbook.md"

# Every handbook document must have a place in the print order. The chat
# transcript is source material, not part of the handbook.
missing=0
while IFS= read -r doc; do
  doc="${doc#"$ROOT/"}"
  [[ "$doc" == docs/chat-transcript.md ]] && continue
  if [[ ! " ${INCLUDED[*]} " == *" $doc "* ]]; then
    echo "error: $doc is not in the print order in print/build.sh" >&2
    missing=1
  fi
done < <(find "$ROOT/docs" -name '*.md' | sort)
(( missing == 0 )) || exit 1

pandoc "$BUILD/handbook.md" \
  --from markdown \
  --to pdf \
  --pdf-engine xelatex \
  --top-level-division chapter \
  --lua-filter "$PRINT/handbook.lua" \
  --metadata-file "$PRINT/metadata.yaml" \
  --include-in-header "$PRINT/preamble.tex" \
  --include-before-body "$PRINT/cover.tex" \
  --output "$OUT"

echo "Wrote $OUT"
