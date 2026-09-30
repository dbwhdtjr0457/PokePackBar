# Supplemental Energy language correction — 2026-09-29

The simulator models English packs. UI localization does not change printed card language.
The previous importer incorrectly used Japanese `ja-m6a-169` through `ja-m6a-176`
art for **all** Mega Evolution and 30th Celebration supplemental Energy cards.
Those eight PNGs have been removed from source and are stripped from incremental
build output when packaging. The loader no longer tries their PNG/WebP filenames.

## Corrected mapping

| Pack | Resource family | English collector numbers | Artwork |
| --- | --- | --- | --- |
| Mega Evolution (`me*`) | `mee-en-{type}.jpg` | MEE 001–008 | Standard Mega Evolution |
| 30th Celebration (`cel30`) | `mee30-en-{type}.jpg` | MEE 009–016 | YOSHIROTTEN, anniversary logo |

English originals: https://pkmncards.com/set/mee/

Files are downloaded without resizing from
`https://pkmncards.com/wp-content/uploads/mee_en_{NNN}_std.jpg` (001–016),
733×1024 pixels. Cross-reference: TCGplayer MEE group 24461, products
656263–656270 and 713248–713255 (`https://tcgcsv.com/tcgplayer/3/24461/products`).

SM, SWSH and SVE images are unchanged in this correction. Their printed language
is checked alongside the new MEE art; this does **not** claim that every later-era
Energy design revision or physical foil printing has been individually verified.

## Regression gates

- `scripts/audit_energy_art.swift`: all 41 packaged Energy images must decode at
  >=650×900, have English ENERGY title text and no Japanese title text. The 16
  MEE footers must contain their expected collector number. Old Japanese PNG/WebP
  names must be absent. Runs offline before signing/installing.
- `--audit-physical-pack-cards`: all catalog pack recipes, actual bundle loader,
  and distinct standard/anniversary supplemental and random Energy routing.

This correction changes artwork selection only, not pull rates or pack counts.
