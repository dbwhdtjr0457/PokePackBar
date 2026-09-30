# Catalogue-wide foil visibility — 2026-09-29

## Verdict and limits

The entire local catalogue was enumerated, not just rarity representatives:
18,949 cards, including 17,964 cards with 20,293 eligible foil printings, 92
routed material names and 127 material/coverage/texture/intensity/treatment
combinations. The other 985 cards have no eligible foil printing and were not
required to produce a foil signal. All 19,076 original card/pack assets passed
decode, dimensions, SHA-256 and the actual grid/detail loader audit.

Final results: **20,269 signal passes, 24 review candidates, zero render errors,
zero missing or unexpected printing keys**. This is not 20,269 individually
approved physical reproductions. Every foil printing was numerically tested;
human-equivalent image inspection covered selected native contact sheets only.
No new factory plate, exact emboss depth or per-card physical certification is
claimed. This pass used the existing source-bound registrations and originals,
not a new collection of angled physical photographs.

## Method

- `--audit-catalogue-foil output.jsonl` renders the actual `HoloCardBody` at
  240 × 335 pt, 2× then downsampled to 1×, at ten deterministic angles.
- Four small tilts (±0.28) are measured separately from five large tilts
  (±0.88 plus a diagonal). The rest frame is the comparison baseline.
- Actual coverage masks, registered profile include/exclude contours and
  cracked-ice facets determine the measured pixels. Artwork masks are prepared
  before rendering. Collection/wallet state is never loaded by this command.
- Whole-region thresholds: small-angle mean peak RGB delta ≥2.5/255,
  large-angle delta ≥5/255 and ≥10% of pixels changing by >8/255. These are
  low-signal heuristics, not calibrated perceptual or fidelity measurements.
- 3,465 sparse-pattern cases pass a **separate actual motif-footprint** test
  using the same thresholds. Their low whole-region scores remain in JSONL;
  they are not relabelled whole-region passes. This avoids enlarging correct
  small stamps or applying foil to plain paper just to raise an average.
- The 16,804 remaining passes meet the whole-region test. Animated microdetail
  is recorded separately from broad brightness and printed source detail.
- First complete pass: 20,293 printings. Rechecks: 7,742 and 4,157, including
  all members of the changed material groups, not only failing examples.
- Independent normal-size visibility fixtures: 32/32 pass, 320 frames; frozen
  and 1%-response pixel mutations are rejected. Optical contracts also pass.
- Visual samples include white/black BWR, bright mirror reverse, type-symbol
  reverse, Ascended ball reverse, BREAK, SAR, MUR and weak Cosmos/3D-ball cases.
  Gold remains warm; BWR remains achromatic. The dark/light changes are confined
  to existing motif/engraving masks, except the intentionally smooth mirror
  return confined to its existing foil region. No central white spotlight was
  reintroduced.

## Changes

1. **BWR scanned engraving**: replace the old broad luminance-gradient return
   with twelve fixed source-derived ridge-normal groups. Flat fills and solid
   lettering have zero ridge weight. Tilt changes local light/dark contrast;
   masks are bounded-cache entries, not regenerated each hover frame. Reshiram,
   Zekrom and Victini small-angle fixture responses are respectively 9.25,
   12.38 and 13.69/255. The existing Victini broad-response ceiling still passes.
   These are inferred image gradients, not recovered manufacturing normals.
2. **Bright mirror/stamped reverses**: add a narrow grain-masked neutral dark
   return inside the original foil mask. Additive white alone disappeared into
   pale trainer backgrounds. The art exclusion and finish identity are intact.
3. **Sparse reverse motifs**: strengthen fixed type symbols, tile, energy and
   ball impressions with paired dark/light response rather than a face wash.
4. **Tera, Prism, BREAK and starlight**: strengthen local motif contrast, not
   card-wide illumination. No mask positions, rarity mappings or save keys change.
5. **Ascended reverses**: increase the existing directional sheet's angular
   travel; keep the registered outside-art mark and mask. All members of the
   `mirror` audit family were rechecked because it includes these treatments.
6. **EX dimensional balls**: strengthen volume/shadow contrast without resizing
   or moving balls. One printing remains below the large-angle threshold.
7. Add streaming, sharded catalogue diagnostics and a report combiner that
   rejects duplicate keys within a run, incomplete catalogue coverage, malformed
   output and render errors. Later rechecks replace only their own keys and keep
   per-row provenance. Three combiner tests and nine visibility tests pass.

## Remaining candidates — not fixed by spreading foil into unknown regions

Cosmos source-visible flecks may be sparse and Vision background segmentation
may fail. A separate direct Vision check returns zero observations for both
`ex12-17` and `ex12-32`, while a `base1-4` control returns a foreground instance.
The existing conservative substrate correctly stays off when no prepared
background exists, but those cards remain visually weak. Increasing a global
overlay would conceal this rather than establish the correct foil surface.
Other Cosmos candidates may reflect small true regions or conservative masks;
each needs card-level mask/reference review before changing coverage.

| Printing | Small delta | Large delta |
| --- | ---: | ---: |
| ex12-17#reverseHolo | 0.14 | 0.54 |
| ex12-32#reverseHolo | 0.42 | 1.51 |
| ex13-2#holo | 0.56 | 2.19 |
| base5-17#holo | 0.88 | 3.32 |
| hgss4-7#holo | 0.99 | 2.61 |
| ex12-76#reverseHolo | 1.09 | 3.83 |
| ex9-101#holo | 1.37 | 5.02 |
| ex9-103#holo | 1.46 | 5.40 |
| gym2-10#holo | 1.49 | 3.45 |
| ex12-33#reverseHolo | 1.76 | 3.88 |
| ex12-72#reverseHolo | 1.86 | 6.55 |
| ex13-13#holo | 1.87 | 5.00 |
| ex12-53#reverseHolo | 1.92 | 4.52 |
| ecard1-26#holo | 1.94 | 7.04 |
| ex12-21#reverseHolo | 1.96 | 5.07 |
| pl3-8#holo | 2.15 | 7.63 |
| ex14-4#holo | 2.16 | 5.70 |
| dp7-100#holo | 2.17 | 5.87 |
| ex13-10#holo | 2.23 | 4.90 |
| pl3-146#holo | 2.29 | 7.16 |
| pl2-111#holo | 2.36 | 6.30 |
| ex12-52#reverseHolo | 2.38 | 7.30 |
| sv8-225#etched (Tera) | 2.48 | 7.01 |
| ex10-86#reverseHolo (3D balls) | 3.12 | 4.62 |

## Reproduction and evidence

Use `PPB_OFFLINE=1` and an explicit `PPB_CARD_ART_DIR` containing the full
original-image snapshot. The runtime CDN cache is not a complete audit input.
Run the release executable with `--audit-catalogue-foil output.jsonl`; split
work with `--shard N --shards 4`, select material representatives with
`--families`, or recheck a JSON array of printing keys with `--keys-file`.
The command refuses to overwrite an existing output. Combine chronological
results with `scripts/summarize_catalogue_foil.py --binary EXECUTABLE --results
SHARDS... --output REPORT_DIRECTORY`. Reports retain all weak candidates.

Local numeric evidence is under
`../../reports/ppb-catalogue-visibility-2026-09-29/` relative to this repository:
`final/summary.json`, `final/printing-results.jsonl`,
`final/review-candidates.json`, all input shards and `fixture-results.json`.
Temporary image/binary diagnostic copies are removed after inspection.

Renderer SHA-256 provenance:

- round2: `6933418c9361432b13c1d09de35eb9d66a7d11ba373fc7e918b57f1f2acdccbc`
- round3: `f7cff648a1bdbfd0b17e6ec797d5aed5302cf27bb7a5a7087bcddfd48c91ed48`
- round4: `4aa452dde1e34f2efee7baa654881ded87708b034ae22413cdd5d2153734b8c8`

XCTest is unavailable in the installed CommandLineTools toolchain (`no such
module 'XCTest'`). Native CLI contracts, release builds and Python tests are
separate evidence and do not imply that the XCTest suite ran.

## Installation verification

`scripts/build-app.sh` completed its packaged resource, Korean-name, price,
physical-pack, foil-geometry/optical/registration and isolated bulk-opening
checks, then installed the custom 0.11.12 app at `/Applications/PokePackBar.app`.
The installed binary matches the assembled binary byte-for-byte; deep/strict
code-signature verification succeeds with the local ad-hoc signature. The app
was reopened and its `/Applications` process confirmed. No interactive pack
opening or frame-rate claim follows from this launch check.

Installed binary SHA-256:
`bc8895a4b00f97e8f0b83d3aee9e02f65c29f1262c0fee35c661518f0ed1fa7b`.
The installed renderer was additionally tested using the actual runtime image
cache, without the original-library override: all three BWR fixtures pass
(`installed-bwr-results.json`). Small-angle responses: Victini 13.86,
Reshiram 9.23, Zekrom 12.42/255. This confirms the improvement does not depend
on the separate research-original image directory.
