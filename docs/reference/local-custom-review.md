# Local-custom contribution: review and build guide

This branch collects local changes based on upstream `main` at `19b89f2` (0.8.0).
The packaged development version is 0.11.11. It is not an upstream release or a
claim that every physical card has been individually verified. The upstream
installation and gameplay descriptions in the main README have not yet been
rewritten as release documentation for this branch.

## What changes

- Pack opening uses set-specific composition and printing finishes. Realistic
  mode separates physical product rules from game bonuses and restricts special
  packs to supported products. Recorded seeds and rules/catalogue identifiers
  allow an opening to be replayed without changing the live collection.
- Purchases and openings persist the wallet and inventory together. Failed saves
  roll back the operation, and eight rotating backups support recovery. Existing
  collection keys remain readable while printing-specific ownership is added.
- Card and pack prices retain source/date information. Exact printing quotes,
  representative fallback prices and game-economy adjustments are distinguishable.
  Imported price snapshots are validated before replacing the current snapshot.
- The catalogue includes 127 sets and 18,949 cards, with Korean display names and
  a high-resolution artwork manifest. Images are decoded at different sizes for
  the grid and detail view instead of enlarging cached thumbnails.
- Foil coverage follows source-image geometry. Separate materials handle gold,
  etched, directional, star, cracked-ice, reverse and anniversary treatments.
  Source-bound registrations cover selected subjects, frames and printed marks.
  The popover is narrower (400 pt), with a 480 pt tab area.

## Source build and non-destructive checks

Use macOS with Swift 6.2 or newer. The existing CI uses Xcode 26 on macOS 26;
the application deployment target remains macOS 14. A full Xcode installation
is needed for XCTest on machines whose Command Line Tools lack that module.

```sh
swift build -c release -j 4
swift test
PPB_OFFLINE=1 .build/release/PokePackBar --audit-local
PPB_OFFLINE=1 .build/release/PokePackBar --audit-foil-optics
PPB_OFFLINE=1 .build/release/PokePackBar --audit-confirmed-foil-fixes
PPB_OFFLINE=1 .build/release/PokePackBar --audit-price-snapshot
PPB_OFFLINE=1 .build/release/PokePackBar --audit-korean-names
PPB_OFFLINE=1 .build/release/PokePackBar --audit-foil-geometry
PPB_OFFLINE=1 .build/release/PokePackBar --audit-reviewed-foil
```

These audit entry points run before normal application startup. Persistence
checks use temporary state and injected failures, not the user's live save.
They are useful alongside XCTest, not a substitute for a passing XCTest suite.
Building the executable and running data/material audits do not require the
multi-gigabyte offline image library. Rendering cards and verifying the complete
image library do require the corresponding original artwork.

Python checks use Pillow, NumPy and OpenCV for image processing, plus urllib3 for
artwork retrieval. Set up the local environment before running those tools:

```sh
python3 -m venv local-assets/.venv
local-assets/.venv/bin/python -m pip install Pillow numpy opencv-python-headless urllib3
local-assets/.venv/bin/python -m unittest discover -s scripts -p 'test_*.py'
```

The reviewed-foil tests also read original card images. With the image library
absent, the pricing/name/visibility tests can be run individually; the complete
Python suite must not be reported as passing until its image inputs are present.

## Exact offline artwork and app packaging

Raw card scans, the Python environment, caches, personal saves, local research
captures and `.app` bundles are excluded from Git. **The original images are
distributed separately**, not omitted from the contribution:
[artwork snapshot release](https://github.com/dbwhdtjr0457/PokePackBar/releases/tag/artwork-2026-09-28).
Its five ZIP archives contain all 18,949 card images and 127 pack images from the
checked-in manifest, approximately 4.5 GiB in total. Only manifest-listed image
files enter those archives. Source URLs remain in `card-art.json`.

```sh
python3 scripts/offline_art_snapshot.py restore
local-assets/.venv/bin/python scripts/build_card_art_library.py --verify
PPB_CARD_ART_DIR="$PWD/local-assets/CardArt" PPB_OFFLINE=1 \
  .build/release/PokePackBar --audit-image-library
PPB_SKIP_INSTALL=1 ./scripts/build-app.sh
```

The snapshot restorer needs only Python's standard library. It verifies each
archive and individual image against SHA-256 and size, rejects unexpected archive
paths, reuses verified files on rerun, and never rewrites the manifest. Downloads
stay in `local-assets/artwork-distribution/`; restored originals go into
`local-assets/CardArt/`. Allow approximately 15 GiB for archives, originals and
the assembled application. `build-app.sh` runs the restorer before artwork checks
so a missing library is downloaded before packaging. A failed download or hash
mismatch stops the build instead of creating an image-less bundle.

The older `build_card_art_library.py` without `--verify` or `--copy-to` is an
**update/research tool**, not snapshot restoration. It resolves current provider
images and rewrites the art manifest. If a provider replaces a scan, inspect the
diff and regenerate/review affected geometry and foil registrations. Do not use
that update path merely to reproduce this version.

`build-app.sh` requires the verified local image library and Python environment.
`PPB_SKIP_INSTALL=1` builds and signs a local bundle without replacing the installed
app. Omitting that flag stops and replaces `/Applications/PokePackBar.app`.
Do not run the installation path merely to review this contribution.

Image and card-design rights remain with their respective owners. Source URLs,
hashes and generated registrations are included for review; the project's MIT
license does not grant rights to third-party artwork. Both the separately hosted
originals and the small registered foil-mark assets need a redistribution-policy
decision before an upstream release.

## Integration decisions before merging

- The custom build disables upstream updates to prevent local changes being
  overwritten. `AppLinks.isCustomBuild`, the version, bundle identity and build
  channel need an upstream release decision; merging them unchanged would retain
  local-custom behavior.
- The offline package is large. This draft pins a snapshot hosted on the
  contributor's fork; upstream hosting, third-party artwork policy and Python
  dependency pinning remain release decisions. The existing Homebrew/release
  workflow has not been validated with this package.
- Published prices are dated snapshots, not a live market feed. Some printing
  quotes still fall back to a representative price or an explicitly labeled
  reference sale. Pull-rate estimates are not manufacturer-certified odds.
- Family-wide material checks, source-hash alignment and rendered frames do not
  establish physical fidelity for every card. Factory emboss/depth maps remain
  approximations. Some Ascended registrations use a companion printing's
  alignment, and some Radiant Collection motifs are unresolved.

See [the follow-up review](foil-followup-2026-09-28.md),
[the material review](foil-optics-2026-09-28.md),
[Radiant Collection findings](generations-rc-2026-09-28.md),
[printed-mark limits](physical-foil-marks.md) and
[subject-mask limits](subject-foil-masks.md) for evidence and unresolved work.
