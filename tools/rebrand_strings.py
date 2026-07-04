#!/usr/bin/env python3
"""
Rebrand X wording -> classic Twitter wording in the app's ENGLISH localization,
in place. English-only on purpose: blanket word replacement across all 47 languages
is linguistically unsafe (e.g. German "Post" = mail), so we only touch en / en-gb /
en-ss. Newer strings are preserved (we edit the current bundle, we do not overlay).

Handles both the uncompressed en.lproj/Localizable.strings and the raw-deflate
(<lang>.lproj.deflate, wbits -15) English variants.

Usage:
  rebrand_strings.py <Twitter.app dir>
"""
import os, re, sys, zlib

if len(sys.argv) < 2:
    sys.exit(__doc__)
APP = sys.argv[1]
BUN = f"{APP}/Localization_Localization.bundle"

# case-sensitive whole-word rules, longest first. \b won't touch snake_case keys.
RULES = [
    (r'\bReposts\b', 'Retweets'), (r'\bReposted\b', 'Retweeted'),
    (r'\bReposting\b', 'Retweeting'), (r'\bRepost\b', 'Retweet'),
    (r'\breposts\b', 'retweets'), (r'\breposted\b', 'retweeted'),
    (r'\breposting\b', 'retweeting'), (r'\brepost\b', 'retweet'),
    (r'\bPosts\b', 'Tweets'), (r'\bPosted\b', 'Tweeted'),
    (r'\bPosting\b', 'Tweeting'), (r'\bPost\b', 'Tweet'),
    (r'\bposts\b', 'tweets'), (r'\bposted\b', 'tweeted'),
    (r'\bposting\b', 'tweeting'), (r'\bpost\b', 'tweet'),
    (r'\bon X\b', 'on Twitter'), (r'\bto X\b', 'to Twitter'), (r'\bfrom X\b', 'from Twitter'),
    (r'\bX app\b', 'Twitter app'), (r'\bX Premium\b', 'Twitter Blue'),
]

def rebrand(text):
    n = 0
    for pat, rep in RULES:
        text, c = re.subn(pat, rep, text); n += c
    return text, n

total = 0

# 1) uncompressed en.lproj/Localizable.strings
p = f"{BUN}/en.lproj/Localizable.strings"
if os.path.exists(p):
    raw = open(p, "rb").read()
    try: txt = raw.decode("utf-8")
    except UnicodeDecodeError: txt = raw.decode("utf-16")
    new, c = rebrand(txt)
    if c: open(p, "w", encoding="utf-8").write(new)
    total += c; print(f"  en.lproj: {c}")

# 2) raw-deflate English variants
for name in ("en-gb.lproj.deflate", "en-ss.lproj.deflate"):
    p = f"{BUN}/{name}"
    if not os.path.exists(p):
        continue
    txt = zlib.decompress(open(p, "rb").read(), -15).decode("utf-8")
    new, c = rebrand(txt)
    if c:
        co = zlib.compressobj(9, zlib.DEFLATED, -15)
        open(p, "wb").write(co.compress(new.encode("utf-8")) + co.flush())
    total += c; print(f"  {name}: {c}")

print(f"rebrand_strings: {total} replacements")
