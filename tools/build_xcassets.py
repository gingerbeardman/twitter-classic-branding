#!/usr/bin/env python3
"""
Build an .xcassets bundle from a flat folder of rendition PNGs, ready for actool.

Usage:
  build_xcassets.py <src_png_dir> <out_xcassets_dir> <appicon_names_file> [template_name ...]

  <appicon_names_file> : newline-separated list of asset names that are App Icons
                         (AssetType "Icon Image" in the source catalog). Everything
                         else becomes a plain imageset.
  <template_name>      : zero or more asset names to mark as template-rendering
                         (tinted by the app, e.g. xLogo).

App-icon renditions are mapped to (idiom,size,scale) by pixel width via ICON_MAP.
Plain images are universal imagesets keyed by @2x/@3x scale suffix.
"""
import os, re, json, shutil, struct, sys

if len(sys.argv) < 4:
    sys.exit(__doc__)

SRC, XC, APPICONS_FILE = sys.argv[1], sys.argv[2], sys.argv[3]
TEMPLATES = set(sys.argv[4:])
APP_ICONS = set(l.strip() for l in open(APPICONS_FILE) if l.strip())

# pixel-width -> (idiom, size, scale) for app-icon renditions
ICON_MAP = {
    1024: ("ios-marketing", "1024x1024", "1x"),
    180:  ("iphone", "60x60", "3x"),
    167:  ("ipad", "83.5x83.5", "2x"),
    152:  ("ipad", "76x76", "2x"),
    120:  ("iphone", "60x60", "2x"),
    87:   ("iphone", "29x29", "3x"),
    80:   ("iphone", "40x40", "2x"),
}

def parse(fn):
    m = re.match(r"^(.*?)(@([234])x)?\.png$", fn)
    return m.group(1), (int(m.group(3)) if m.group(3) else 1)

def pixw(path):
    with open(path, "rb") as f:
        f.seek(16)
        return struct.unpack(">I", f.read(4))[0]

if os.path.exists(XC):
    shutil.rmtree(XC)
os.makedirs(XC)
json.dump({"info": {"author": "xcode", "version": 1}}, open(f"{XC}/Contents.json", "w"))

groups = {}
for fn in sorted(os.listdir(SRC)):
    if not fn.endswith(".png"):
        continue
    base, scale = parse(fn)
    groups.setdefault(base, []).append((scale, fn))

n_icon = n_img = 0
skipped = []
for base, files in groups.items():
    if base in APP_ICONS:
        d = f"{XC}/{base}.appiconset"; os.makedirs(d)
        images = []
        for scale, fn in files:
            w = pixw(f"{SRC}/{fn}")
            if w not in ICON_MAP:
                skipped.append(f"{fn} (w={w})"); continue
            idiom, size, sc = ICON_MAP[w]
            shutil.copy(f"{SRC}/{fn}", f"{d}/{fn}")
            images.append({"idiom": idiom, "size": size, "scale": sc, "filename": fn})
        json.dump({"images": images, "info": {"author": "xcode", "version": 1}},
                  open(f"{d}/Contents.json", "w"), indent=2)
        n_icon += 1
    else:
        d = f"{XC}/{base}.imageset"; os.makedirs(d)
        images = []
        for scale, fn in files:
            shutil.copy(f"{SRC}/{fn}", f"{d}/{fn}")
            images.append({"idiom": "universal", "scale": f"{scale}x", "filename": fn})
        c = {"images": images, "info": {"author": "xcode", "version": 1}}
        if base in TEMPLATES:
            c["properties"] = {"template-rendering-intent": "template"}
        json.dump(c, open(f"{d}/Contents.json", "w"), indent=2)
        n_img += 1

print(f"built xcassets: {n_icon} appiconsets, {n_img} imagesets")
if skipped:
    print("  skipped (pixel size not in ICON_MAP): " + ", ".join(skipped))
