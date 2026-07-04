#!/usr/bin/env python3
"""
Merge NeoFreeBird/Twitter branding overrides onto a Twitter/X catalog's extracted
renditions. Adapts to the target version: every override is regenerated at whatever
pixel size the extracted rendition uses, so it works across app versions.

Usage:
  merge_assets.py <extracted_dir> <merged_dir> <branding_root> [blue_hex]

Catalog overrides (regenerated as bird, sized to this version's renditions):
  xLogo                        -> black bird silhouette (template; THIS drives the launch screen)
  ProductionAppIcon            -> white bird on Twitter blue (default app icon)
  Icon-Earlybird-settings      -> white bird on Twitter blue (default-icon preview)
  Icon-Production-settings     -> white bird on Twitter blue (default-icon preview)
  Custom-Icon-001..007 (+ -settings) -> NeoFreeBird classic bird icons (Settings > App Icon)
  icn_applicationshortcut_{DM,search,tweet} -> NeoFreeBird classic glyphs (Home-Screen quick actions)

Kept as extracted: Custom-Icon-X-* (no classic equivalent), grok, backgrounds, textures.
Note: the FEED logo and COMPOSE button are NOT catalog assets — they live in
TwitterAppearance/VectorImages + a feature switch, handled by rebrand.sh directly.
"""
import os, re, sys, glob, struct, subprocess, shutil, tempfile

if len(sys.argv) < 4:
    sys.exit(__doc__)
EXTRACT, MERGED, ROOT = sys.argv[1], sys.argv[2], sys.argv[3]
BLUE = sys.argv[4] if len(sys.argv) > 4 else "#1DA1F2"

SVG   = f"{ROOT}/sources/Twitter_bird_logo_black.svg"
NFB_C = f"{ROOT}/sources/nfb/custom-icons"       # Custom-Icon-00N.png (square masters)
NFB_S = f"{ROOT}/sources/nfb/shortcuts"          # icn_applicationshortcut_*.png

def sh(*a): subprocess.run(a, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
def dims(p):
    with open(p, "rb") as f:
        f.seek(16); w, h = struct.unpack(">II", f.read(8)); return w, h

os.makedirs(MERGED, exist_ok=True)
for f in glob.glob(f"{EXTRACT}/*.png"):
    shutil.copy(f, MERGED)

# prepare recoloured SVGs once
tmp = tempfile.mkdtemp()
svg_black = f"{tmp}/bird-black.svg"; svg_white = f"{tmp}/bird-white.svg"
src = open(SVG).read()
open(svg_black, "w").write(src.replace("currentColor", "#000000"))
open(svg_white, "w").write(src.replace("currentColor", "#ffffff"))

def gen_xlogo(dst, w, h):
    inner = round(min(w, h) * 0.80)
    sh("rsvg-convert", "-w", str(inner), "-h", str(inner), svg_black, "-o", f"{tmp}/b.png")
    sh("magick", "-size", f"{w}x{h}", "xc:none", f"{tmp}/b.png", "-gravity", "center", "-composite", dst)

def gen_bluebird(dst, w, h):
    inner = round(min(w, h) * 0.62)
    sh("rsvg-convert", "-w", str(inner), "-h", str(inner), svg_white, "-o", f"{tmp}/w.png")
    sh("magick", "-size", f"{w}x{h}", f"xc:{BLUE}", f"{tmp}/w.png", "-gravity", "center", "-composite", dst)

def resize_from(master, dst, w, h):
    sh("magick", master, "-resize", f"{w}x{h}!", "-filter", "Lanczos", dst)

# iterate the renditions actually present for each override asset, regenerate in place
def renditions(base):
    # files named base.png / base@2x.png / base@3x.png  (exact base, not prefix)
    out = []
    for f in glob.glob(f"{EXTRACT}/{glob.escape(base)}*.png"):
        stem = os.path.basename(f)
        if re.match(rf"^{re.escape(base)}(@[234]x)?\.png$", stem):
            out.append(os.path.join(MERGED, stem))
    return out

count = 0
for dst in renditions("xLogo"):
    gen_xlogo(dst, *dims(dst)); count += 1
for name in ("ProductionAppIcon", "Icon-Earlybird-settings", "Icon-Production-settings"):
    for dst in renditions(name):
        gen_bluebird(dst, *dims(dst)); count += 1
for n in ("001","002","003","004","005","006","007"):
    master = f"{NFB_C}/Custom-Icon-{n}.png"
    if not os.path.exists(master): continue
    for name in (f"Custom-Icon-{n}", f"Custom-Icon-{n}-settings"):
        for dst in renditions(name):
            resize_from(master, dst, *dims(dst)); count += 1
for g in ("DM", "search", "tweet"):
    master = f"{NFB_S}/icn_applicationshortcut_{g}.png"
    if not os.path.exists(master): continue
    for dst in renditions(f"icn_applicationshortcut_{g}"):
        resize_from(master, dst, *dims(dst)); count += 1

shutil.rmtree(tmp)
print(f"merged: regenerated {count} override renditions into {MERGED}")
