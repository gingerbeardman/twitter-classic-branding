#!/usr/bin/env bash
#
# rebrand.sh — turn a decrypted Twitter/X IPA into a classic-Twitter-branded,
# NeoFreeBird-tweaked IPA. Adapts to the app version (regenerates overrides at the
# version's own rendition sizes) and edits only the files that actually matter.
#
# Usage:
#   ./rebrand.sh <decrypted-twitter.ipa> [output.ipa]
#
# Requirements: Xcode (actool/assetutil/clang), rsvg-convert, imagemagick (magick),
# cyan (pyzule-rw, with pillow), and a compiled NeoFreeBird tweak. Point these at your
# tweak build via env vars if they aren't in the defaults:
#   TWEAK_DYLIBS  dir containing BHTwitter.dylib, libbhFLEX.dylib, zxPluginsInject.dylib
#   TWEAK_BUNDLE  path to BHTwitter.bundle
set -Eeuo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---- config (override via env) --------------------------------------------
BLUE="${BLUE:-#1DA1F2}"
TWEAK_DYLIBS="${TWEAK_DYLIBS:-$HERE/tweak/.theos/obj/debug}"
TWEAK_BUNDLE="${TWEAK_BUNDLE:-$HERE/tweak/layout/Library/Application Support/BHT/BHTwitter.bundle}"
# ---------------------------------------------------------------------------

IPA_IN="${1:?usage: rebrand.sh <decrypted-twitter.ipa> [output.ipa]}"
OUT="${2:-$HERE/NeoFreeBird-Twitter.ipa}"
say(){ printf "\033[1;36m==>\033[0m %s\n" "$*"; }

for bin in actool assetutil clang rsvg-convert magick cyan python3 zip curl; do
  command -v "$bin" >/dev/null || { echo "missing required tool: $bin" >&2; exit 1; }
done
[ -f "$TWEAK_DYLIBS/BHTwitter.dylib" ] || { echo "tweak not found at $TWEAK_DYLIBS — build it and/or set TWEAK_DYLIBS" >&2; exit 1; }

# 0) ensure fetched sources + generated home icon exist
[ -f "$HERE/sources/nfb/vectors/twitter.svg" ] || { say "fetching NeoFreeBird sources"; bash "$HERE/fetch-sources.sh"; }
HOME_ICON="$HERE/sources/home-icon.png"
if [ ! -f "$HOME_ICON" ]; then
  say "generating opaque home icon"
  sed 's/currentColor/#ffffff/' "$HERE/sources/Twitter_bird_logo_black.svg" > "$HERE/sources/.bw.svg"
  rsvg-convert -w 640 -h 640 "$HERE/sources/.bw.svg" -o "$HERE/sources/.bw.png"
  magick -size 1024x1024 "xc:$BLUE" "$HERE/sources/.bw.png" -gravity center -composite -alpha remove -alpha off "$HOME_ICON"
  rm -f "$HERE/sources/.bw.svg" "$HERE/sources/.bw.png"
fi

WORK="$(mktemp -d)"; APP=""
say "extracting IPA"; unzip -q "$IPA_IN" -d "$WORK/app"
APP="$(echo "$WORK/app/Payload/"*.app)"; [ -d "$APP" ] || { echo "no .app in IPA" >&2; exit 1; }
say "Twitter version: $(plutil -extract CFBundleShortVersionString raw "$APP/Info.plist")"

# 1) compile the CoreUI extractor, extract the catalog
clang -fobjc-arc -framework Foundation -framework CoreGraphics -framework ImageIO "$HERE/tools/carextract.m" -o "$WORK/carextract"
"$WORK/carextract" "$APP/Assets.car" "$WORK/extracted" >/dev/null

# 2) rebuild the catalog with classic-bird overrides (adaptive sizes; fixes launch xLogo + custom icons)
say "rebuilding Assets.car"
python3 "$HERE/tools/list_appicons.py" "$APP/Assets.car" > "$WORK/appicons.txt"
python3 "$HERE/tools/merge_assets.py" "$WORK/extracted" "$WORK/merged" "$HERE" "$BLUE"
python3 "$HERE/tools/build_xcassets.py" "$WORK/merged" "$WORK/Assets.xcassets" "$WORK/appicons.txt" xLogo
mkdir -p "$WORK/car"
actool "$WORK/Assets.xcassets" --compile "$WORK/car" --platform iphoneos --minimum-deployment-target 14.0 \
  --include-all-app-icons --app-icon ProductionAppIcon --output-partial-info-plist "$WORK/p.plist" >/dev/null 2>&1 || true
[ -f "$WORK/car/Assets.car" ] || { echo "actool failed" >&2; exit 1; }
cp "$WORK/car/Assets.car" "$APP/Assets.car"

# 3) feed logo + compose button — vector swap + feature switch (NOT in the catalog)
say "swapping feed logo + compose vectors, patching feature switch"
VDST="$APP/TwitterAppearance_TwitterAppearance.bundle/VectorImages/main"
cp "$HERE/sources/nfb/vectors/twitter.svg" "$VDST/twitter.svg"
cp "$HERE/sources/nfb/vectors/compose.svg" "$VDST/compose.svg"
python3 - "$APP" <<'PY'
import json,sys
p=f"{sys.argv[1]}/fs_embedded_defaults_production.json"
d=json.load(open(p)); d["default"]["config"]["composer_fab_icon_option"]["value"]=""
json.dump(d,open(p,"w"))
PY

# 4) English wording rebrand (in place, preserves newer strings)
say "rebranding English strings"; python3 "$HERE/tools/rebrand_strings.py" "$APP" | tail -1

# 5) strip stale seals from the two bundles we edited (resource bundles; safe for sideloading)
for b in TwitterAppearance_TwitterAppearance.bundle Localization_Localization.bundle; do rm -rf "$APP/$b/_CodeSignature"; done

# 6) repackage + inject tweak + name + opaque bird home icon
say "repackaging + injecting tweak"
( cd "$WORK/app" && zip -qr "$WORK/repacked.ipa" Payload )
rm -f "$OUT"
cyan -i "$WORK/repacked.ipa" -o "${OUT%.ipa}" --ignore-encrypted -k "$HOME_ICON" -n Twitter \
  -uwf "$TWEAK_DYLIBS/zxPluginsInject.dylib" "$TWEAK_DYLIBS/libbhFLEX.dylib" "$TWEAK_DYLIBS/BHTwitter.dylib" "$TWEAK_BUNDLE"

say "done -> $OUT"
rm -rf "$WORK"
