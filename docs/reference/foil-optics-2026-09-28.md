# 2026-09-28 local foil-material revision

## 0.11.8 visibility follow-up

The original artifact-removal pass below was not sufficient for visibility.
The follow-up removes duplicate Mega Attack attenuation, includes SAR in
angular gain/dispersion, strengthens warm gold and fine directional sheets,
and adds source-guided Amazing Rare response. Cosmos substrate is restricted
to the art background and waits for a prepared mask. Registered Delta subjects
now use a smooth sheet instead of drawn stripes. Reverse motifs gain localized
light and dark contrast without expanding coverage.

`scripts/audit_foil_visibility.py` separates render success from small-angle
signal and human review. It compares 24 printings at 240pt over ten poses and
can render an older app with `--baseline-binary`. Real PNG mutations (frozen
frames and 1% response) must be rejected. Six Python tests run in packaging.
The final 0.11.8 sample has 22 signal passes and two review candidates
(`ex7-1#reverseHolo`, `sm1-113#reverseHolo`); do not advertise universal visibility
or physical accuracy. The workspace report `reports/ppb-visibility-fix-2026-09-28`
records comparisons, installation, unchanged save/data checks, and limitations.

## Scope and evidence standard

This revision separates untextured diffraction sheets from etched full arts and removes several conspicuous synthetic artifacts found in the production SwiftUI renderer. Native renders use the real 240pt detail size. A successful render, a nonzero pixel difference, or a source hash does **not** certify physical accuracy.

We inspected first-hand owner/seller photographs, then iterated the native output. An angled Japanese example informs the material family but does not establish that every English printing uses the same emboss plate. Seller titles alone were not treated as visual evidence.

## Changes

| Material | Observed problem | Implementation |
| --- | --- | --- |
| BW/XY/SM/SWSH/SV etched full arts | Long light/dark fragments resembled scratches; printed luminance became invented relief; correlated normals made broad wires | Subpixel ridges, axial direction blending, dispersed microscopic normals, weak ink-edge guidance, angle-dependent diffraction colors; distinct family orientations retained |
| VSTAR and six Shiny relief families | Coarse line segments and low-frequency loops | Finer independent family sampling, shorter facets, dispersed normal response; no shared assumed spiral center |
| Cosmos and EX Gold Star | Extra circles were drawn over already-visible foil spots | Re-light compact bright source features in three fixed spatial groups with different angular responses; reject long edges/flat fills; image-identity-bound cache |
| Celebrations ordinary holos, LEGEND, refractor Gold Stars | Invented stars/parallel curves or broad diagonal RGB lines | Smooth, finely modulated diffraction sheet; separate family spectral response and existing registered coverage |
| Ordinary directional holo | Etched particles looked like dust on smooth stock | Dedicated continuous fine-line sheets: horizontal Tinsel, vertical SWSH, diagonal XY, rippled SM; not the etched-facet renderer |
| BW Radiant Collection | Added diagonal lines and embossed cross-hatching | Keep star-sheet character, remove unrelated diagonal/emboss overlays |
| EX Unseen Forces reverse | White target outlines instead of shaded 3D balls; balls projected across opaque subject | Dedicated colored spherical diffraction, continuous angular reveal, art-background coverage; existing set wordmark remains a separate printed layer |
| Gold / MUR / Neo Shining | Risk of palette regression from shared hue rotation | Eight gold families retain warm palettes; eight Neo Shining subjects retain achromatic grain; ordinary sheet changes do not route these into RGB materials |

## Iteration record

1. Baseline: legacy etched dust, Cosmos circles, weak Celebrations, VSTAR wires and LEGEND/Gold-Star bars identified.
2. Shorter etched ridges exposed regular sampling rows; those were not accepted as finished.
3. Dispersed normals removed large periodic structures. Fine mask grain replaced uniform sheet glare; angle-dependent colors strengthened the local response.
4. Source-registered Cosmos glints needed more movement. Connected features were split into three independently lit groups without moving their coordinates.
5. Full material sweep found ordinary holo dust and unnecessary Radiant Collection embossing. Merely shortening facets was insufficient.
6. Ordinary holo was moved to a dedicated fine directional sheet. Unseen Forces was compared to a close physical photograph and moved from white wireframes to shaded balls.
7. Final class sweep and installation checks are recorded separately in the workspace audit report. This document does not substitute for those results.

## Physical references actually inspected

- Cosmos: [owner's Ampharos comparison](https://www.elitefourum.com/t/what-is-your-favorite-holofoil-pattern/51707), [photograph](https://efour.b-cdn.net/uploads/default/original/3X/3/b/3bbf86dbab723d3d02b40642fd9471d973461c60.jpeg). Dense small colored flecks with sparse larger round/polygonal spots, not white target circles.
- BW texture: [owner's collection](https://www.elitefourum.com/t/qwachanseys-modern-collection/31015?page=4), [photograph](https://efour.b-cdn.net/uploads/default/original/2X/4/498c09596d9ad5440e25c0d1a09ade28a2e997b6.jpeg). Fine local texture on Japanese promo full arts; not proof of every international relief plate.
- Celebrations Pikachu: [seller's actual card](https://www.ebay.com/itm/137058924822), [angle one](https://i.ebayimg.com/images/g/DGgAAeSwLbVpmiAt/s-l1600.webp), [angle two](https://i.ebayimg.com/images/g/2zIAAeSw8NBpmiA1/s-l1600.webp). Fine smooth foil inside a plain yellow paper frame.
- LEGEND: [seller's Ho-Oh photograph](https://www.ebay.com/itm/388958511082), [detail](https://i.ebayimg.com/images/g/APsAAeSwzKJow~UR/s-l1600.webp). Colored fine sheet response, not the old synthetic parallel curves. Japanese example.
- Refractor Gold Star: [Gyarados seller photograph](https://www.befr.ebay.be/itm/313788232005), [detail](https://i.ebayimg.com/images/g/1dwAAOSw8b9hs6eM/s-l1600.webp). Limited cropped view; supports removal of large invented bars, not full-card certification.
- Radiant Collection: [Snivy photograph](https://www.ebay.com/itm/306797827694), [front](https://i.ebayimg.com/images/g/imwAAeSwhYxppJlR/s-l1600.webp). Smooth printed surface in this angle; no coarse cross-hatched etching. Single angle does not map the complete star sheet.
- Unseen Forces: [Scyther seller close-ups](https://www.ebay.com/itm/178041995761), [angled detail](https://i.ebayimg.com/images/g/Fv8AAeSw0Qpp2zOS/s-l1600.webp). Colored hemispheres with spherical shading and angle-dependent appearance in the background. The reference is an inverted-sheet variant; normal orientation is retained in the simulator.
- [Houndoom front](https://www.ebay.com/itm/318330349287) was also inspected; its front-on photograph does not resolve the 3D pattern and was not used to infer the shape.
- [Samurott listing](https://www.ebay.com/itm/306482298978) was inspected but the photo depicts a reverse, so it was rejected as evidence for ordinary Tinsel foil.

## Remaining limits — do not describe these as solved

- No factory emboss/depth/BRDF data is available. Engraved grooves and their normals remain a material-family approximation, not an exact per-card manufacturing plate.
- Source-feature detection cannot perfectly distinguish tiny white printed details from photographic foil highlights, nor recover foil absent from a flat scan. Continuous edges and uniform fills are explicitly rejected.
- Unseen Forces foreground separation uses the existing source-image segmentation path. It is not a manually traced, individually certified physical mask for every reverse printing. Exact ball positions vary with the foil-sheet cut and are approximated.
- Existing EX5–EX9 energy/ball/pinwheel motifs, modern reverse patterns, and unavailable Ascended registrations retain the limits documented in `physical-foil-marks.md`. This revision must not be described as completing all physical printing registrations.
- RGB, chrome, classic reprints and SAR were included in regression renders, but this pass did not obtain new measured emboss maps for them.
- UI visibility at 240pt intentionally gives a clearer response than a poorly lit physical card. Lighting, foil batches, photography and display gamut vary.

## Repeatable checks

```sh
swift build -c release -j 4
.build/release/PokePackBar --audit-foil-optics
.build/release/PokePackBar --audit-confirmed-foil-fixes
.build/release/PokePackBar --audit-foil-geometry
local-assets/.venv/bin/python scripts/audit_optical_response.py --binary .build/release/PokePackBar --output /tmp/ppb-optics-review --families
```

The optical guard tests production material routing, warm/neutral palettes, microscopic ridge scale, directional sheet distinctions, source-feature rejection/group conservation, and angular response. Deliberately bad dispatch/scale/normal implementations must fail. XCTest wrappers are provided, but a native audit pass is not an XCTest suite pass.
