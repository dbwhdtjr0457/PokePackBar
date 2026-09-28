# Foil follow-up — local 0.11.10

## Scope and completion boundary

This pass continues the earlier 57-printing implementation. It fixes confirmed missing registrations and material-routing defects. It does **not** certify all 20,318 catalogue foil printings against individual physical cards. A rendered frame, a source-hash match and an identified product photograph prove different things.

## Changes

| Area | Change | Evidence limit |
| --- | --- | --- |
| Classic 30 | All 30 have original-specific gold rim, illustration, subject and rules regions; background confetti and larger stars respond independently | Official individual Japanese images compared with installed English originals; factory relief directions remain reconstructed |
| Classic Lugia | Wide left/bottom gold frame replaces the narrow shared inset | Registered source-image outline, not a generic border |
| Pikachu 30 | All 30 use fixed radial-fan positions; the remaining nine fallback areas were replaced | Manufacturer display-sheet pattern repeats in some examples; production cut/lot phase is not certified |
| Ordinary ex | 220 ordinary ex cards receive stationary mixed star/circle motifs with independent angular responses; blanket glare reduced | Three oblique Miraidon photos and a 30th Fuecoco photograph, not individual physical approval of all 220 |
| Mega ex | 16 early Mega ex cards move out of ordinary ex stars into the existing Mega-specific material; all 44 Mega double rares checked for routing | Mega Lucario oblique photograph confirms a distinct surface; per-card etching not measured |
| 30th ordinary ex logos | 12 source-bound matte-logo exclusions; Pikachu 054 and Umbreon 092 correctly use the left-hand logo | Image-derived contour approximation |
| Cracked ice | 12 card-specific sets of visible angular regions replace random overlaid shards; six EX cards include the rules area, six Rotom-series cards exclude the art | Strict source-colour segmentation; hidden facets and physical normals cannot be recovered from a single scan |
| Ascended reverse | Eight missing motif registrations supplied, reaching 280/280 | 17 older registrations still use the companion printing's alignment |

All new registrations bind to the installed original hash. A replacement scan must regenerate registrations rather than silently reuse old coordinates. Black printed ink is excluded from cracked reflections. Empty post-clipping regions are dropped before serialization; runtime checks enforce all 12 cards remain decoded.

## Research references

- [Official 30th set](https://www.30th.pokemon-card.com/product/m6a): individual Classic illustrations and gold-rim construction.
- [Official Pikachu 020 image](https://www.30th.pokemon-card.com/images/m6a/cards/m6a_020_mgb734dr.png), [030](https://www.30th.pokemon-card.com/images/m6a/cards/m6a_030_mt8ktxb9.png), [034](https://www.30th.pokemon-card.com/images/m6a/cards/m6a_034_yuxf6flm.png), [043](https://www.30th.pokemon-card.com/images/m6a/cards/m6a_043_u68bbz2j.png), [044](https://www.30th.pokemon-card.com/images/m6a/cards/m6a_044_x4um6kfj.png).
- [Pikachu archive](https://billsarchive.com/30th-celebration-pikachu.html): supplemental images p023, p029, p037 and p045, explicitly not a manufacturer source.
- [Official Scarlet & Violet aesthetic changes](https://www.pokemon.com/us/pokemon-news/pokemon-tcg-scarlet-and-violet-revamps-pokemon-tcg-card-aesthetic).
- Miraidon 081 photo angles: [photo 1](https://i.ebayimg.com/images/g/M7gAAOSw~hFkKvGf/s-l1200.jpg), [photo 2](https://i.ebayimg.com/images/g/S~4AAOSwu7tmwYhG/s-l1200.jpg), [photo 3](https://i.ebayimg.com/images/g/TGQAAOSwZAFm~Zh0/s-l1200.jpg).
- [30th Fuecoco listing](https://www.ebay.com/itm/800683496852), [observed photo](https://i.ebayimg.com/images/g/bLsAAeSwNyZqrf-M/s-l1600.webp): mixed stars and the non-reflective logo.
- [Mega Lucario listing](https://www.ebay.com/itm/365934483103), [observed photo](https://i.ebayimg.com/images/g/wVoAAeSwuklo9rYN/s-l1600.webp): distinct Mega surface, not ordinary ex star sheet.
- Ascended exact product-image references and hashes are in `physical-foil-reference-overrides.json` and `physical-foil-marks.json`.

## Verification and known limits

`build_reviewed_foil.py --verify`, seven Python registration tests, `build_cracked_facets.py --verify`, `build_physical_foil_marks.py --verify`, native resource/geometry/optics/reviewed audits, and actual SwiftUI multi-angle renders cover separate failure modes. XCTest cannot run in the current command-line toolchain (`no such module XCTest`) and is not reported as passing.

Native render counts, inspected contact-sheet IDs, package checks and installation hashes are recorded in the workspace follow-up report. Screenshots are disposable; JSON results and this source/evidence ledger are retained.

Outstanding research is explicit: individually measured EX stamp positions, SAR/UR card-specific emboss maps, all Cosmos sheets, all ordinary ex physical cards, and factory facet normals. These are not implicitly approved by a family-level material change.
