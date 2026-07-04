# twitter-classic-branding

Rebrand a decrypted **Twitter / X** IPA back to **classic Twitter** — bird logo in the
feed, feather compose button, bird launch screen, bird app icon + name, classic bird
alternate icons, and "Post → Tweet" wording — then inject the [NeoFreeBird](https://github.com/NeoFreeBird)
tweak. One command, and it adapts to the app version.

> [!WARNING]
> You need a **decrypted Twitter/X IPA that you obtained legally** (dumped from a device
> you own). This repo ships **no** Twitter/X artwork — branding assets are fetched at
> build time from the public [NeoFreeBird/app](https://github.com/NeoFreeBird/app) repo.
> "Twitter", the bird, and "X" are trademarks of X Corp. For personal use.

## Why it's built this way

The interesting part is *where* each branded element actually lives — most of it is **not**
in the asset catalog, which is why naive catalog edits don't work:

| Element | Real source | Fix |
|---|---|---|
| Feed / nav logo | `TwitterAppearance.bundle/VectorImages/main/twitter.svg` | swap the vector |
| Compose button | feature switch `composer_fab_icon_option` (+ `compose.svg`) | set to `""`, swap vector |
| Launch screen | `xLogo` **inside `Assets.car`** | rebuild the catalog |
| App name / home icon | `Info.plist` / primary icon | `cyan -n` / `cyan -k` |
| Alternate icons | `Custom-Icon-*` in `Assets.car` | rebuild the catalog |
| Wording | `Localization_Localization.bundle` (English) | in-place string replace |

The catalog is rebuilt from the target version's **own** extracted renditions with only the
branded ones swapped, so nothing the newer app added gets lost.

## Requirements

- macOS with **Xcode** (`actool`, `assetutil`, `clang`)
- `brew install imagemagick librsvg`
- `pipx install cyan && pipx inject cyan pillow`  ([pyzule-rw](https://github.com/asdfzxcvbn/pyzule-rw))
- A compiled **NeoFreeBird tweak** (the `.dylib`s + `BHTwitter.bundle`). Build it from
  [the tweak repo](https://github.com/NeoFreeBird) with `./build.sh --sideloaded`, then point
  `TWEAK_DYLIBS` / `TWEAK_BUNDLE` at it (defaults look in `./tweak/`).

## Usage

```bash
./rebrand.sh /path/to/decrypted-twitter.ipa [output.ipa]
```

First run auto-fetches branding sources (`fetch-sources.sh`) and generates the home icon.
Output defaults to `./NeoFreeBird-Twitter.ipa`. Install with AltStore / SideStore / Sideloadly.

## What's committed vs fetched vs generated

- **Committed:** the scripts in `tools/`, `rebrand.sh`, `fetch-sources.sh`, and
  `sources/Twitter_bird_logo_black.svg` (the [Font Awesome](https://fontawesome.com) free
  Twitter mark, CC BY 4.0) used to render the app/launch/icon birds.
- **Fetched** into `sources/nfb/` (git-ignored): NeoFreeBird's `twitter.svg`, `compose.svg`,
  and classic custom-icon masters.
- **Generated / ignored:** `sources/home-icon.png`, the merged catalog, and all IPAs.

## Tools

| file | role |
|---|---|
| `rebrand.sh` | orchestrator |
| `fetch-sources.sh` | pull NeoFreeBird branding assets from upstream |
| `tools/carextract.m` | CoreUI `Assets.car` → PNG extractor |
| `tools/list_appicons.py` | list App Icon asset names in a `.car` |
| `tools/merge_assets.py` | apply bird overrides at the version's rendition sizes |
| `tools/build_xcassets.py` | flat PNGs → `.xcassets` for `actool` |
| `tools/rebrand_strings.py` | English wording rebrand |

## Notes

- **English only** for wording — blanket replacement across all 47 languages is unsafe
  (e.g. German "Post" = mail), so other languages keep their current strings.
- `Custom-Icon-X-*` (Cyber/Mars/Moon/…) and Grok keep their X art — no classic equivalent.
- Login/posting may fail due to X's server-side attestation; that's outside a tweak's control.
