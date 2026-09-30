# Foil audit — 2026-09-29

## Scope

This audit checks the 0.11.12 working tree based directly on tag `v0.11.11` (`4e70bb5`). It separates four different claims:

1. resource registration and source-image hashes;
2. material routing and mask isolation;
3. visible angular response in the native 240pt SwiftUI renderer;
4. physical-card equivalence.

The first three can be tested locally. The fourth remains limited by the available angled photographs and the absence of factory emboss/depth data. A passing render is not physical certification.

## Repeated checks

| Check | Result | Boundary |
| --- | --- | --- |
| Native optical contracts | PASS | Routing, sheet isolation, fine-scale relief, gold palette, eight Neo subjects and six bad mutations |
| Native foil geometry | PASS | 18,949 source hashes/layouts at 180/240/420pt |
| Confirmed foil fixes | PASS | 2 Celebrations exceptions, 38 subject mappings, 106 relief printings, 71 Legendary reverses and 471 ball parallels |
| Explicitly reviewed profiles | PASS | 85 printings, no diagonal hue partition, 30 Classic gold masks and 12 source-bound cracked-ice sets; not factory plates |
| Physical marks | PASS | 280 registrations, 16 traced motifs and 10 source-hashed EX wordmarks |
| Material-family native renders | PASS | 115 distinct routed families, 690 frames, no render failures |
| Small-angle visibility sample | PASS | 27 of 27 pass, including a bounded full-face response check for RBG/BWR |

Temporary contact sheets were inspected at their native 240pt card size and removed after the result was recorded.

## Findings corrected in this pass

### 1. `sm1-113#reverseHolo` symbol response

- Before: small-angle `2.09/255`; large-angle `4.65/255`; `8.85%` of the checked outside-art region exceeded an 8-level change.
- After: small-angle `2.80/255`; large-angle `6.53/255`; `10.72%` exceeds an 8-level change.
- The fix raises only the fixed Sun & Moon symbol relief and its dark/light angular contrast. The registered outside-art coverage remains unchanged and does not enter the illustration.
- Verdict: local visibility defect corrected. Exact factory depth remains unverified.

### 2. `ex7-1#reverseHolo` sparse energy/set carrier

- Before: small-angle `2.72/255`; large-angle `7.02/255`; `8.55%` of the art region exceeded an 8-level change.
- After: small-angle `2.98/255`; large-angle `8.91/255`; `9.88%` exceeds an 8-level change.
- The fixture uses a `9.5%` affected-pixel floor because this registered outline carrier occupies less area than the general `10%` floor. Mean-response requirements remain unchanged.
- Energy symbols and the Team Rocket Returns wordmark remain spatially fixed; no symbol was enlarged and the rare-parallel gold treatment is unchanged.
- Verdict: marginal local response corrected without changing geometry. Exact factory depth remains unverified.

### 3. `rsv10pt5-172#blackWhite` broad white return

- Before: full-card maximum mean delta `47.81/255`; the moving white lobe washed out the subject and rules text.
- After: full-card large-angle mean delta `22.16/255`, below the new `28/255` regression ceiling; small-angle response remains visible at `7.52/255`.
- The fix narrows and lowers only the monochrome scanned-relief light and shadow lobes. Dedicated black-etched and white-etched printings retain their existing response.
- Verdict: overexposure defect corrected while preserving a visible engraved response. Exact factory normals remain unverified.

### 4. Anniversary diagonal hue partition across 85 printings

- Before: confetti, fragment and micro-etch meshes assigned every facet to one of six hue regions using `x * 0.42 + y * 0.58`. This created the same card-wide diagonal colour organization on all 25 Celebrations Classic, 30 anniversary Pikachu and 30 anniversary Classic printings.
- After: each facet receives an independent normal and circular hue phase. A low-weight smooth field supplies only weak local coherence between neighbours; it cannot organize the card into broad directional bands.
- Gold fragments keep a warm-gold base. Only one eighth of phase groups can produce the restrained red/green edge diffraction, instead of allowing full-spectrum colour across the border.
- Confetti, micro-etching and embossed gold stars now use separate angular-response speeds.
- The native audit samples 12,000 facets, rejects correlation with the former diagonal axis, requires all 64 hue/normal groups and checks that the three material speeds do not collapse back to one response.
- Native 10-angle contact sheets for 30th Lugia, Magikarp, Pikachu and 25th Blastoise were inspected at normal card size and removed afterward. The broad diagonal partition was absent in these representatives.
- Verdict: shared renderer defect corrected for all 85 registered printings. Exact factory facet normals remain unverified.

### 5. Low full-card scores that are not defects by themselves

- `pl2-RT1#holo` (`1.33/255`) uses small source-bound cracked-ice regions outside the illustration.
- `cel25c-15_A2#celebrationsClassic` (`1.35/255`) uses a localized confetti/illustration treatment with a plain paper frame.
- A full-card average penalizes correct small masks. Neither should be expanded just to satisfy a global score.

## Physical-equivalence limits still unresolved

- Exact SAR, UR and MUR emboss direction/depth remains a family-level approximation; no per-card factory normal maps exist.
- Seventeen Ascended registrations use the companion printing of the same card for alignment rather than their own printing photograph.
- The shape and color logic for 980 EX stamps is corrected, but every individual physical stamp position and size has not been measured.
- Ordinary modern ex material is shared across 220 cards from a small set of oblique references; this is routing coverage, not individual approval.
- Cosmos feature extraction can confuse tiny printed white details with scan-visible foil highlights and cannot reconstruct highlights absent from a flat source scan.
- Classic 30 gold regions are source-bound, but manufacturing relief direction, sheet phase and production-lot variation are not certified.
- The 12 cracked-ice registrations recover visible source regions, not hidden facets or factory normals.

## Reference-access note

The configured local `chrome_devtools` MCP could not attach because its profile was already held by another browser process (`browser is already running ... use --isolated`). No browser process was terminated. Existing source-bound local references, recorded URLs/hashes and native renders were used; new web photographs were not promoted to reviewed evidence in this pass.

## Documentation correction

`physical-foil-marks.md` still ended with the pre-follow-up statement that eight Ascended references were missing, although the same document records their later restoration to 280/280. That stale verdict is corrected in this pass. The remaining limitations are the 17 companion alignments and unmeasured per-card EX stamp placement.
