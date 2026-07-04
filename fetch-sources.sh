#!/usr/bin/env bash
#
# fetch-sources.sh — download the NeoFreeBird-derived branding assets this pipeline
# needs, from the upstream public repo, into ./sources/nfb/. These are NOT committed
# here (we don't redistribute Twitter/NeoFreeBird artwork); they are fetched on demand.
#
# Source: https://github.com/NeoFreeBird/app  (classic branding set)
set -Eeuo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RAW="https://raw.githubusercontent.com/NeoFreeBird/app/main"
DST="$HERE/sources/nfb"
mkdir -p "$DST/vectors" "$DST/custom-icons" "$DST/shortcuts"

get() { curl -fsSL "$1" -o "$2" && echo "  fetched $(basename "$2")"; }

echo "==> vectors (feed logo + compose glyph)"
get "$RAW/assets/classic/TwitterAppearance_TwitterAppearance.bundle/VectorImages/main/twitter.svg" "$DST/vectors/twitter.svg"
get "$RAW/assets/classic/TwitterAppearance_TwitterAppearance.bundle/VectorImages/main/compose.svg" "$DST/vectors/compose.svg"

echo "==> custom-icon masters (Settings > App Icon, classic bird 001-007)"
for n in 001 002 003 004 005 006 007; do
  get "$RAW/assets/main/Custom-Icon-${n}60x60@3x.png" "$DST/custom-icons/Custom-Icon-${n}.png"
done

echo "==> shortcut glyph masters (Home-Screen quick actions) — best effort via classic Assets.car"
if command -v clang >/dev/null && command -v assetutil >/dev/null; then
  tmp="$(mktemp -d)"
  if curl -fsSL "$RAW/assets/classic/Assets.car" -o "$tmp/Assets.car"; then
    clang -fobjc-arc -framework Foundation -framework CoreGraphics -framework ImageIO \
      "$HERE/tools/carextract.m" -o "$tmp/carextract" 2>/dev/null || true
    if [ -x "$tmp/carextract" ]; then
      "$tmp/carextract" "$tmp/Assets.car" "$tmp/out" >/dev/null 2>&1 || true
      for g in DM search tweet; do
        f="$tmp/out/icn_applicationshortcut_${g}@2x.png"
        [ -f "$f" ] && cp "$f" "$DST/shortcuts/icn_applicationshortcut_${g}.png" && echo "  extracted ${g} glyph"
      done
    fi
  fi
  rm -rf "$tmp"
else
  echo "  (skipped — clang/assetutil not available; shortcut glyphs will stay stock)"
fi

echo "done. sources/nfb/ populated."
