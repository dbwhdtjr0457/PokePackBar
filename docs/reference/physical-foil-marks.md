# Physical foil mark sources and limits

## Corrected implementation

- Removed the hand-drawn `ParallelGlyph` construction (thin rings, arbitrary polygons).
- Replaced Ascended Heroes symbols with contours traced from multiple identified international printing images. The 16 motifs comprise 10 Energy types and six Ball/R marks. Filled upper hemispheres, cut-outs, Energy silhouettes and the Rocket R now come from those images.
- Registered each available printing to the installed original with matching image features. The manifest binds each registration to the original SHA-256 and the reference-image SHA-256. It records which reference printing was used, the fitted transform and matching feature count.
- Protect neutral dark printed lettering from the emblem overlay using source-derived ink contours.
- Replaced system-font EX set names and invented underlines with the ten actual expansion wordmark images. Original graphic aspect ratios are retained. Early EX rare stamps retain the set colour, while common/uncommon and later stamps are desaturated.

## Evidence

- Official Japanese comparison: https://www.pokemon-card.com/ex/m2a/ (mirror-card-01 through 04). Confirms filled/cut-out construction, not the old wireframe shapes.
- International Budew Friend Ball example: https://www.tcgplayer.com/product/676865/pokemon-me-ascended-heroes-budew-016-217-friend-ball . Actual reference: https://tcgplayer-cdn.tcgplayer.com/product/676865_in_1000x1000.jpg . Energy companion: product 677005.
- Each of the 140 known card/printing pairs is joined through the existing `expansion-foil.json` product IDs, not a name guess. The generated manifest records the exact image URL and hash for each registration.
- EX wordmark graphic sources: https://images.pokemontcg.io/ex7/logo.png through ex16/logo.png. These are the original expansion graphics mirrored by the same public card-image service used by the catalogue, not newly typeset text.
- First-hand EX printing distinctions: https://www.elitefourum.com/t/ex-sets-reverse-holos/16005 . Describes rare/ordinary stamp colour differences and lower-right artwork placement. It does not establish a measured position for every individual card.

## Coverage and unresolved parts (original pass; superseded counts below)

- 272 of 280 Ascended printing registrations are present: 255 use that printing's own reference image; 17 use the other printing of the same card for image registration. Their motif shape still comes from multiple references of the correct motif.
- Both high-resolution references were unavailable (HTTP 403) for `me2pt5-66`, `me2pt5-69`, `me2pt5-71` and `me2pt5-72`. Their eight printings deliberately draw no emblem instead of falling back to invented geometry. Ordinary reverse-foil material remains visible. No access restriction was bypassed.
- Multi-scan consensus removes much of the overprinted attack text and photographic noise, but does not recover a factory die. Contour smoothing and source registration are measured visual approximations. A source-hash match does not certify a physical emboss plate.
- EX logo **shape** and common/rare colour distinction are corrected across the existing 980-stamp path. All 980 individual physical stamp dimensions/positions have **not** been measured. Placement remains artwork-frame-relative and must not be reported as pixel-perfect registration.
- All 16 extracted motif silhouettes were visually inspected as a contact sheet. Full-card/native angle review is a separate verification step. Automated checks are not a substitute for it.
- Alternate missing-reference checks: the CollectorsEdge Vikavolt Quick Ball product photo shows the ordinary unmarked version, so it was rejected. The HFX Games Kilowattrel Poke Ball product has no product images. Neither product name was accepted as proof that its displayed pixels depict the requested printing.

## Native regression caught during this fix

The initial actual-PNG substitution exposed a pre-existing material pipeline assumption: `LocalizedPatternFlash` treated all opaque PNG pixels as a solid shadow, while the artwork illumination nearly erased the base wordmark. The new `EXPrintedStampLayer` therefore draws the actual printed graphic separately from procedural foil-mask/illumination layers. It only activates for reverse-holo printings in EX7–EX16. This preserves the graphic at rest and prevents a black silhouette overlay. Native material/geometry checks and screenshot review must exercise this rendered path, not merely test that a logo file loads.

## Reproduction

Use the project's `local-assets/.venv/bin/python` environment:

1. `scripts/build_physical_foil_marks.py --capture` fetches identified printing references and source wordmarks into ignored local assets. Failed URLs are reported, not substituted.
2. `scripts/build_physical_foil_marks.py --compile` generates source-bound contour/registration data and copies unmodified wordmark PNGs into resources.
3. `scripts/build_physical_foil_marks.py --verify` verifies coverage accounting, source hashes, coordinates and logo hashes.
4. `--preview /tmp/foil-motif-review.png` generates a diagnostic contact sheet of extracted silhouettes.

Native checks: `PhysicalFoilMarks.verify()` and `PhysicalFoilMarksTests`. The latter requires an XCTest-capable Xcode toolchain; the current command-line toolchain reports `no such module 'XCTest'`.

## 2026-09-28 follow-up: missing eight registrations restored

The four unavailable TCGplayer pairs now have individually identified Lex Collects product photographs. `scripts/physical-foil-reference-overrides.json` pins the exact eight Wix image URLs. Normal, Energy and Ball photographs were compared for each card; Vikavolt uses Quick Ball, while the other three use Poke Ball. All four use Lightning Energy. No photograph was inferred from its product title alone.

Coverage is now **280/280 registrations**, with **263 own-printing photographs** and **17 companion-printing registrations**. The previous eight deliberately blank motifs are no longer blank. `build_physical_foil_marks.py --verify` and the native expected-printing audit reject a recurrence. This closes the missing-eight issue, not the unmeasured EX stamp positions or factory-plate limitations above.

Product sources: [Vikavolt](https://www.lexcollects.co.uk/product-page/ascended-heroes-vikavolt-066-217), [Iono's Tadbulb](https://www.lexcollects.co.uk/product-page/ascended-heroes-iono-s-tadbulb-069-217), [Iono's Wattrel](https://www.lexcollects.co.uk/product-page/ascended-heroes-iono-s-wattrel-071-217), [Iono's Kilowattrel](https://www.lexcollects.co.uk/product-page/ascended-heroes-iono-s-kilowattrel-072-217).

## Checked / verdict for this implementation pass

- Python resource verification passed: 272 registered entries plus eight explicitly unavailable entries account for all 280 expected printings; all 16 motifs have at least three reference images; ten wordmark hashes match.
- Native debug and release compilation succeeded. XCTest execution was unavailable for the toolchain reason above; this is not reported as a test pass.
- Native 240pt, 2×, rest/diagonal renders were visually reviewed for all 16 motif types, ten EX expansion logos, and common cards from the first four EX expansions (30 representative printings, 60 frames). After separating the printed layer and explicitly generating grayscale assets, logos remain legible without the opaque silhouette, and normal/rare colours are distinct.
- Source-ink exclusion was checked across all 272 registered emblems; the minimum retained visible emblem area is 82.6%. This guards against the dark blue card panel being mistaken for neutral printed text and hiding the whole mark.
- Verdict: confirmed fake-shape/font substitutions are corrected for the documented range. Eight missing Ascended references and the individual registration of 980 physical EX stamps remain unresolved; do not claim complete physical-card reproduction.
