# Source-registered subject foil masks

## Scope and evidence

The confirmed subject-only corrections cover Neo Destiny Shining 106–113 (8),
EX Delta Species 1–18 (18), and EX Dragon Frontiers 1–12 (12). Reprints, additional
delta expansions and reverse printings do not inherit these masks automatically.
The source-art hash and dimensions are part of every entry in
`Resources/foil-subject-masks.json`.

The original silhouette proposals came from macOS Vision on each illustration
crop. All 38 proposals were inspected. Twelve needed local corrections, including
Crobat's wings, Latios's background tower, Mewtwo's tail, Salamence's wings,
Tyranitar, Meganium, Pinsir and Typhlosion. Corrected silhouette boundaries were
refined against source pixels; holes between limbs remain holes. The resulting
normalized vector contours are the editable source of truth, not a repeatable
promise that the next Vision model will make the same prediction.

Delta cards' golden outer rims are measured separately from the artwork and text
panel. Neo's yellow paper border has no foil path. An initially considered
assumption that all yellow rims were paper was rejected before implementation:
[collectors' treatment comparison](https://www.elitefourum.com/t/ex-sets-reverse-holos/16005)
and [the complete delta holo collection](https://www.reddit.com/r/PokemonTCG/comments/1by0nsn)
identify reflective delta borders. The inner printed silver frame is not treated
as interchangeable with either a Neo paper border or a delta golden rim.

## Failure behavior and regression protection

- Registered masks are synchronous: the first render does not flash a whole art
  window while waiting for foreground detection.
- A missing mask or changed source hash fails closed. It never substitutes a
  generic oval or 42%-opaque whole-illustration fallback.
- Other estimated subject masks also omit the whole-window fallback on failure.
- `FoilSubjectMasks.verify()` checks exact 38-card coverage, source identity,
  illustration containment, Neo paper borders, delta text-panel exclusion and
  positive/negative landmarks. The source-replacement failure is explicitly
  injected so the guard cannot pass merely because all bundled sources are valid.
- `scripts/audit_subject_masks.py` additionally hashes the actual art files and
  can emit diagnostic sheets using `--contact-sheets <temporary-directory>`.
- `FoilSubjectMasksTests` records six regression tests. The local Command Line
  Tools lack XCTest (`no such module 'XCTest'`), so these could not execute here;
  the executable audit and Python resource checks run without XCTest.

## Checked — 2026-09-23

All 38 final masks were inspected in five 240pt source/mask contact sheets after
the corrections. The final native debug executable rendered every affected
printing at 240pt @2x, rest and diagonal (76 images; zero failures). All five
native contact sheets were visually reviewed. The subject effect stays off the
surrounding illustration background; Neo paper borders remain matte, while
delta outer rims retain their independent response.

This was not a new 1:1 comparison with 38 physical cards. Source scans already
contain captured lighting, and foreground silhouettes do not reveal a printing
plate. Thin limb edges, aura/flame boundaries, occlusion and metal-rim ink remain
source-image approximations. No entry claims `physicalPlateVerified`.

## Verdict

The confirmed whole-artwork reflection error is corrected for these 38 original
printings. The unchanged refractor shader still reads as parallel light lines
at some angles; registration correctness must not be mistaken for exact physical
material reproduction. The masks do not certify factory embossing or every
physical foil boundary.
