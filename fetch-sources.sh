#!/usr/bin/env bash
#
# fetch-sources.sh — download the NeoFreeBird-derived branding assets this pipeline
# needs, from the upstream public repo, into ./sources/nfb/. These are NOT committed
# here (we don't redistribute Twitter/NeoFreeBird artwork); they are fetched on demand.
#
# Custom-icon + shortcut masters are extracted from NeoFreeBird's classic Assets.car
# (which renders them to STANDARD PNGs) rather than the loose bundle PNGs, which are
# Apple "CgBI" iOS-optimized PNGs that ImageMagick cannot read.
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

echo "==> custom-icon + shortcut masters (extracted from classic Assets.car)"
command -v clang >/dev/null && command -v assetutil >/dev/null || {
  echo "  ERROR: need Xcode (clang + assetutil) to extract masters from Assets.car" >&2; exit 1; }
tmp="$(mktemp -d)"
get "$RAW/assets/classic/Assets.car" "$tmp/Assets.car"
clang -fobjc-arc -framework Foundation -framework CoreGraphics -framework ImageIO \
  "$HERE/tools/carextract.m" -o "$tmp/carextract"
"$tmp/carextract" "$tmp/Assets.car" "$tmp/out" >/dev/null 2>&1 || true
# classic bird custom icons 001-007: use the -settings@2x rendition (clean 196px square master)
for n in 001 002 003 004 005 006 007; do
  f="$tmp/out/Custom-Icon-${n}-settings@2x.png"
  [ -f "$f" ] && cp "$f" "$DST/custom-icons/Custom-Icon-${n}.png" && echo "  extracted Custom-Icon-${n}"
done
# Home-Screen quick-action glyphs
for g in DM search tweet; do
  f="$tmp/out/icn_applicationshortcut_${g}@2x.png"
  [ -f "$f" ] && cp "$f" "$DST/shortcuts/icn_applicationshortcut_${g}.png" && echo "  extracted ${g} glyph"
done
rm -rf "$tmp"

echo "done. sources/nfb/ populated (standard PNGs)."
