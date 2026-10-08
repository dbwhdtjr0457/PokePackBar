#!/usr/bin/env python3
"""Measure illustration windows in the installed ORIGINAL scans (never alter art).

Dependencies: Pillow, numpy, opencv-python-headless. Rectangle edges are measured
on each image; era/layout priors only constrain the search. Full bleed and energy
cards have no illustration-window exclusion. Confidence and source hashes remain
in the manifest so a low-evidence measurement is not called a physical foil scan.
"""
import argparse
import concurrent.futures
import hashlib
import json
import re
from collections import Counter
from pathlib import Path

import cv2
import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
RES = ROOT / "Sources/PokePackBar/Resources"
ART = ROOT / "local-assets/CardArt"
OUT = RES / "foil-geometry.json"
cv2.setNumThreads(1)
# Source-of-truth lists already used by the renderer. Ancient Traits extend the
# illustration to the attack box; they are not standard XY rectangular art.
catalogue_source = (ROOT / "Sources/PokePackBar/Core/FoilMaterialCatalog.swift").read_text()
ancient_table = catalogue_source.split("static let ancientTraitReverseNumbers:")[-1].split("\n    ]", 1)[0]
ANCIENT_TRAITS = {sid: set(re.findall(r'\b([0-9]+)\b', nums))
                  for sid, nums in re.findall(r'"(xy\d+)":\s*\[([^\]]+)\]', ancient_table)}
LETTERING = json.loads((ROOT / "scripts/foil-lettering-regions.json").read_text())


def profile(card, rarities):
    cid, name, tier, ri, *kind = card
    sid = cid.split("-")[0]
    rarity = rarities[ri].lower()
    kind = kind[0] if kind else ""
    if cid in {"bw11-114", "bw11-115"}:
        return "full", None  # Reshiram/Zekrom: the entire original is gold art.
    if sid == "cel30" and rarity == "pikachu rare":
        return "modern", (.08, .10, .92, .475)
    if cid.split("-", 1)[1] in ANCIENT_TRAITS.get(sid, set()):
        return "ancient-trait", (.07, .17, .93, .71)
    if cid == "cel25-25" or (sid == "g1" and cid in {"g1-25", "g1-29"}):
        return "full", None
    if rarity == "rare prism star":
        # Framed illustration above the Prism Star rule box, energies included.
        # The diamond in the text box is measured separately (prism_diamond).
        if kind.startswith("e"):
            return "sm-prism-energy", (.083, .137, .91, .576)
        if kind == "t":
            return "sm-prism-trainer", (.075, .137, .92, .452)
        return "sm-prism", (.075, .106, .92, .435)
    if kind.startswith("e"):
        return "energy", None
    # Reprints retain their original frame, NOT their expansion's release year.
    if sid == "cel30c":
        n = int(cid.split("-")[1])
        if n in {1, 5, 7, 14, 15, 24}:
            return ("vintage-trainer", (.095, .23, .915, .555)) if n == 5 else ("vintage", (.12, .13, .88, .515))
        if n in {2, 3, 6, 25}:
            return "ex", (.085, .103, .92, .468)
        if n in {10, 11, 22}:
            return "dp", (.085, .102, .92, .50)
        if n == 12:
            return "modern", (.08, .10, .92, .475)
        if n == 18:
            return "extended", (.07, .10, .93, .53)
        if n == 29:
            return "ecard", (.11, .125, .95, .49)
        return "full", None
    if sid == "cel25c":
        # Source card numbers are non-unique; IDs include _A suffixes.
        source_id = cid.removesuffix("_A")
        if source_id in {"cel25c-4", "cel25c-2", "cel25c-15_A1", "cel25c-8", "cel25c-20",
                   "cel25c-24", "cel25c-66", "cel25c-73", "cel25c-15_A2", "cel25c-15_A3"}:
            if kind == "t":
                return "vintage-trainer", (.095, .23, .915, .555)
            return "vintage", (.12, .13, .88, .515)
        if source_id in {"cel25c-17", "cel25c-86", "cel25c-88", "cel25c-9", "cel25c-93"}:
            return ("ex-trainer", (.095, .155, .915, .51)) if kind == "t" else ("ex", (.08, .10, .92, .48))
        if source_id in {"cel25c-15_A4", "cel25c-109", "cel25c-145"}:
            return "dp", (.085, .102, .92, .50)
        if source_id == "cel25c-107":
            return "extended", (.065, .10, .935, .53)
        return "full", None
    if rarity in {"rare prime", "rare holo lv.x"}:
        return "extended", (.065, .10, .935, .53)
    if rarity == "rare holo ex" and sid.startswith("ex"):
        return "ex", (.075, .10, .925, .475)
    if tier in {"AR", "SAR", "SR", "SSR", "HR", "UR", "BWR", "MUR", "FUR", "MA", "CHR", "RRR", "PR"}:
        # Pre-XY secret cards (Crystal, SH shinies, BW gold-border shinies)
        # retain a framed illustration despite being mapped to the UR tier.
        framed_secret = rarity == "rare secret" and sid.startswith(("base", "neo", "ecard", "ex", "dp", "pl", "hgss", "bw"))
        if rarity != "rare holo star" and not framed_secret:
            return "full", None
    if any(s in rarity for s in ["holo ex", "holo gx", "holo v", "break", "legend"]):
        return "full", None
    if rarity in {"double rare", "pikachu rare", "rbg rare"}:
        return "full", None
    if sid.startswith(("base", "gym", "neo")) or sid == "xy12":
        return ("vintage-trainer", (.095, .23, .915, .555)) if kind == "t" else ("vintage", (.12, .13, .88, .515))
    if sid.startswith("ecard"):
        return ("ecard-trainer", (.10, .16, .90, .51)) if kind == "t" else ("ecard", (.095, .118, .968, .49))
    if sid.startswith("ex"):
        return ("ex-trainer", (.095, .155, .915, .51)) if kind == "t" else ("ex", (.08, .10, .92, .48))
    if sid.startswith(("dp", "pl", "hgss")) or sid == "col1":
        return ("dp-trainer", (.09, .145, .91, .51)) if kind == "t" else ("dp", (.085, .11, .915, .50))
    if sid.startswith(("bw", "xy")) or sid in {"g1", "dc1"}:
        return ("bw-trainer", (.10, .16, .90, .515)) if kind == "t" else ("bw", (.095, .12, .905, .505))
    if sid.startswith("sm"):
        return ("sm-trainer", (.08, .145, .92, .52)) if kind == "t" else ("sm", (.08, .097, .92, .475))
    return ("modern-trainer", (.08, .145, .92, .52)) if kind == "t" else ("modern", (.08, .10, .92, .475))


def measure(rgb, prior):
    """Find straight frame edges using support, continuity and a bounded prior.

    Search in original pixels (up to 1000 high). Gradients alone confuse a dark
    character/letter with a frame; long-run support and robust column/row means
    are needed together. Leave the metallic frame OUT of the illustration.
    """
    h, w = rgb.shape[:2]
    channels = rgb.astype(np.float32) / 255
    gx = np.linalg.norm(channels[:, 2:] - channels[:, :-2], axis=2)
    gy = np.linalg.norm(channels[2:] - channels[:-2], axis=2)
    gx = np.pad(gx, ((0, 0), (1, 1)))
    gy = np.pad(gy, ((1, 1), (0, 0)))
    l, t, r, b = prior
    result = [l, t, r, b]
    scores = []
    for iteration in range(2):
        l, t, r, b = result
        for axis, expected in enumerate(prior):
            vertical = axis in (0, 2)
            dimension = w if vertical else h
            radius = .032 if vertical else .026
            start, end = int((expected - radius) * dimension), int((expected + radius) * dimension)
            candidates = np.arange(max(2, start), min(dimension - 2, end))
            if vertical:
                strip = gx[int((t + .03) * h):int((b - .03) * h), candidates]
            else:
                # Evolution badges and anniversary logos cover the corners.
                strip = gy[candidates, int((l + .12) * w):int((r - .14) * w)].T
            strength = np.mean(np.minimum(strip, .5), axis=0)
            support = np.mean(strip > .085, axis=0)
            continuity = np.quantile(strip, .25, axis=0)
            distance = np.abs(candidates / dimension - expected) / radius
            score = strength * .9 + support * .25 + continuity * .5 - distance * .035
            best = int(np.argmax(score))
            result[axis] = float(candidates[best] / dimension)
            if iteration == 1:
                scores.append(float(support[best]))
    # Half a display pixel inside the measured edge, not a big rounded mask.
    result[0] += 1 / w
    result[1] += 1 / h
    result[2] -= 1 / w
    result[3] -= 1 / h
    return [round(v, 6) for v in result], round(min(scores), 3)


def analyze(args):
    card, rarities, entry, override = args
    cid = card[0]
    path = ART / entry["file"]
    with Image.open(path) as original:
        rgb = original.convert("RGB")
        if rgb.width > rgb.height:
            rgb = rgb.transpose(Image.Transpose.ROTATE_90)
        w, h = rgb.size
        family, prior = profile(card, rarities)
        rect, confidence = (None, 1.0) if prior is None else measure(np.asarray(rgb), prior)
        method = "full-face" if prior is None else "measured-frame-edges"
        if override:
            assert override["sha256"] == entry["sha256"], f"Re-review changed original: {cid}"
            rect = [round(v / (w if i % 2 == 0 else h), 6)
                    for i, v in enumerate(override["artPixels"])]
            family = override.get("profile", family)
            confidence, method = 1.0, "reviewed-image-landmarks"
        outline = ecard_outline(np.asarray(rgb), rect) if family.startswith("ecard") else []
        lettering = lettering_contours(np.asarray(rgb), LETTERING[cid]) if cid in LETTERING else []
        has_name_foil = (cid.split("-")[0].startswith("ex") and card[2] in {"R", "RR"}) or rarities[card[3]].lower() == "rare prime"
        accents = name_contours(np.asarray(rgb), rect) if has_name_foil else []
        if family.startswith("sm-prism"):
            diamond, support = prism_diamond(np.asarray(rgb), rect)
            assert diamond and support >= .6, f"Prism Star diamond not found: {cid} ({support})"
            accents = [diamond]
    return cid, dict(sha256=entry["sha256"], width=w, height=h, art=rect,
                    profile=family, confidence=confidence, method=method,
                    outline=outline, lettering=lettering, accents=accents)


def name_contours(rgb, rect):
    """Extract printed header ink; never redraw the name in a substitute font.

    Local thresholding retains character holes while rejecting the broad metal
    rail. This is an image-guided accent, not a claim about factory foil ink.
    """
    h, w = rgb.shape[:2]
    t = rect[1] if rect else .10
    y0, y1 = round(.034 * h), round(min(.108, t - .009) * h)
    x0, x1 = round(.06 * w), round(.92 * w)
    gray = cv2.cvtColor(rgb, cv2.COLOR_RGB2GRAY)
    roi = gray[y0:y1, x0:x1]
    polarity = cv2.THRESH_BINARY_INV if np.median(roi) > 120 else cv2.THRESH_BINARY
    threshold = cv2.adaptiveThreshold(gray, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C, polarity, 31,
                                     12 if polarity == cv2.THRESH_BINARY_INV else -12)
    mask = np.zeros((h, w), np.uint8)
    mask[y0:y1, x0:x1] = threshold[y0:y1, x0:x1]
    count, labels, stats, _ = cv2.connectedComponentsWithStats(mask)
    valid = np.zeros(count, dtype=np.uint8)
    for i in range(1, count):
        x, y, cw, ch, area = stats[i]
        if 6 <= area <= w * h * .007 and .008 * h <= ch <= .07 * h and cw < .18 * w:
            valid[i] = 255
    contours, _ = cv2.findContours(valid[labels], cv2.RETR_LIST, cv2.CHAIN_APPROX_SIMPLE)
    return [[[round(float(x) / w, 6), round(float(y) / h, 6)] for x, y in cv2.approxPolyDP(c, .65, True)[:, 0]]
            for c in contours if cv2.contourArea(c) >= 3]


PRISM_SLOPE = np.tan(np.radians(55))


def prism_diamond(rgb, rect):
    """Trace the printed Prism Star diamond below the rule box.

    Its sides are straight 55/125 degree print edges on every scan, so the
    shape is an axis-aligned rhombus. Text often hides one side; the visible
    opposite pair gives the half-height and one side of the other pair is
    enough. Supporter/Stadium boxes and the panel foot cover the lower tip,
    so the polygon stops where the lower sides stop being visible.
    """
    h, w = rgb.shape[:2]
    gray = cv2.cvtColor(rgb, cv2.COLOR_RGB2GRAY)
    edges = cv2.Canny(cv2.GaussianBlur(gray, (3, 3), 0), 40, 110)
    edges[:round((rect[3] + .02) * h)] = 0
    edges[:, :round(.05 * w)] = 0
    edges[:, round(.95 * w):] = 0
    found = cv2.HoughLinesP(edges, 1, np.pi / 360, 60, minLineLength=round(.07 * h), maxLineGap=10)
    segments = []
    for x1, y1, x2, y2 in (found.reshape(-1, 4) if found is not None else []):
        angle = (np.degrees(np.arctan2(y2 - y1, x2 - x1)) + 180) % 180
        mx, my = (x1 + x2) / 2, (y1 + y2) / 2
        if abs(angle - 55) < 3:
            segments.append(("rising", my - PRISM_SLOPE * mx))
        elif abs(angle - 125) < 3:
            segments.append(("falling", my + PRISM_SLOPE * mx))
    near = cv2.dilate(edges, np.ones((3, 3), np.uint8)) > 0

    def corners(cx, cy, b):
        a = b / PRISM_SLOPE
        return [(cx, cy - b), (cx + a, cy), (cx, cy + b), (cx - a, cy)]

    def support(cx, cy, b):
        t = np.linspace(.04, .96, 60)
        points = corners(cx, cy, b)
        hits = 0
        for (x0, y0), (x1, y1) in zip(points, points[1:] + points[:1]):
            xs = np.rint(x0 + (x1 - x0) * t).astype(int)
            ys = np.rint(y0 + (y1 - y0) * t).astype(int)
            inside = (xs >= 0) & (xs < w) & (ys >= 0) & (ys < h)
            hits += int(near[ys[inside], xs[inside]].sum())
        return hits / (4 * len(t))

    def clusters(kind):
        groups = []
        for value in sorted(c for k, c in segments if k == kind):
            if groups and value - groups[-1][-1] < 6:
                groups[-1].append(value)
            else:
                groups.append([value])
        return [float(np.mean(group)) for group in groups]

    rising, falling = clusters("rising"), clusters("falling")
    candidates = []
    for pair, other, pair_is_rising in ((rising, falling, True), (falling, rising, False)):
        for i, low in enumerate(pair):
            for high in pair[i + 1:]:
                b = (high - low) / 2
                if not .14 * h < b < .30 * h:
                    continue
                for side in other:
                    for other_mid in (side + b, side - b):
                        m1, m2 = ((low + high) / 2, other_mid) if pair_is_rising else (other_mid, (low + high) / 2)
                        candidates.append(((m2 - m1) / (2 * PRISM_SLOPE), (m1 + m2) / 2, b))
    if not candidates:
        return None, 0.0
    cx, cy, b = max(candidates, key=lambda c: support(*c))
    for step in (2, 1):
        improved = True
        while improved:
            improved = False
            for dx, dy, db in ((step, 0, 0), (-step, 0, 0), (0, step, 0), (0, -step, 0), (0, 0, step), (0, 0, -step)):
                if support(cx + dx, cy + dy, b + db) > support(cx, cy, b):
                    cx, cy, b = cx + dx, cy + dy, b + db
                    improved = True
    score = support(cx, cy, b)
    top, right, bottom, left = corners(cx, cy, b)
    # Walk down both lower sides comparing ink just inside and just outside
    # each side. A Supporter/Stadium box or the panel foot has the same ink
    # on both sides; the Pokemon weakness bar only interrupts a long run.
    lab = cv2.cvtColor(rgb, cv2.COLOR_RGB2LAB).astype(np.float32)
    a = b / PRISM_SLOPE
    rows = np.arange(round(cy), min(h, round(cy + b)))
    contrast = np.zeros(len(rows))
    for i, y in enumerate(rows):
        spread = a * (1 - (y - cy) / b)
        for side, inward in ((cx - spread, 1), (cx + spread, -1)):
            inner = [lab[y, round(side + inward * d)] for d in range(3, 9) if 0 <= side + inward * d < w - .5]
            outer = [lab[y, round(side - inward * d)] for d in range(3, 9) if 0 <= side - inward * d < w - .5]
            if inner and outer:
                contrast[i] = max(contrast[i], np.linalg.norm(np.median(inner, 0) - np.median(outer, 0)))
    visible = np.array([np.median(contrast[max(0, i - 6):i + 7]) > 18 for i in range(len(rows))])
    foot, start = cy, None
    for i, shown in enumerate(np.append(visible, False)):
        if shown and start is None:
            start = i
        elif not shown and start is not None:
            if i - start >= .2 * b:
                foot = rows[i - 1]
            start = None
    if foot < cy + .92 * b:
        spread = a * (1 - (foot - cy) / b)
        polygon = [top, right, (cx + spread, foot), (cx - spread, foot), left]
    else:
        polygon = [top, right, bottom, left]
    return [[round(min(max(x / w, 0), 1), 6), round(min(max(y / h, 0), 1), 6)] for x, y in polygon], round(score, 3)


def ecard_outline(rgb, rect):
    """Trace the curved yellow frame in e-Reader scans, in original pixels.

    Each row searches for the printed yellow-to-art transition, rather than
    cutting the asymmetric illustration with a generic rounded rectangle.
    The ellipse only bounds the search; it is not the emitted mask.
    """
    h, w = rgb.shape[:2]
    l, t, r, b = rect
    hsv = cv2.cvtColor(rgb, cv2.COLOR_RGB2HSV)
    yellow = ((hsv[:, :, 0] >= 16) & (hsv[:, :, 0] <= 42)
              & (hsv[:, :, 1] > 100) & (hsv[:, :, 2] > 105)).astype(np.float32)
    left_edge = []
    rows = np.linspace(round(t * h), round(b * h), 75).astype(int)
    # Curve radius scales with this measured illustration, not the card holder.
    ry = min(.10 * h, (b - t) * h * .32)
    rx = .16 * w
    for y in rows:
        dy = min(y - t * h, b * h - y)
        curved = max(0, 1 - max(0, dy) / ry)
        expected = l * w + rx * (1 - np.sqrt(max(0, 1 - curved * curved)))
        candidates = np.arange(max(round(l * w), round(expected - .037 * w)),
                               min(round(r * w), round(expected + .037 * w)) + 1)
        stripe = yellow[max(0, y - 2):min(h, y + 3)].mean(axis=0)
        # An actual border has yellow just outside and non-yellow just inside.
        before = np.array([stripe[max(0, x - 4):x].mean() for x in candidates])
        after = np.array([stripe[x:min(w, x + 4)].mean() for x in candidates])
        score = before - after - np.abs(candidates - expected) / w * 3
        x = int(candidates[np.argmax(score)])
        left_edge.append([round((x + 1) / w, 6), round(y / h, 6)])
    return left_edge + [[r, b], [r, t]]


def lettering_contours(rgb, recipe):
    """Trace the actual ink, including character holes, within reviewed ROIs.

    The ROI is NOT the foil mask; hue/ink boundaries in the original determine
    every emitted vertex. This avoids glowing background rectangles/bands.
    """
    h, w = rgb.shape[:2]
    roi = np.zeros((h, w), np.uint8)
    for polygon in recipe["regions"]:
        cv2.fillPoly(roi, [np.rint(np.array(polygon) * [w, h]).astype(np.int32)], 255)
    hsv = cv2.cvtColor(rgb, cv2.COLOR_RGB2HSV)
    hue, sat, value = cv2.split(hsv)
    color = recipe["color"]
    if color == "white":
        ink = (sat < 45) & (value > 215)
    else:
        lower, upper = dict(yellow=(20, 39), magenta=(140, 176), blue=(97, 116), cyan=(87, 105))[color]
        ink = (hue >= lower) & (hue <= upper) & (sat > 130) & (value > 90)
    mask = ((roi > 0) & ink).astype(np.uint8) * 255
    contours, _ = cv2.findContours(mask, cv2.RETR_LIST, cv2.CHAIN_APPROX_SIMPLE)
    return [[[round(float(x) / w, 6), round(float(y) / h, 6)] for x, y in cv2.approxPolyDP(c, .55, True)[:, 0]]
            for c in contours if cv2.contourArea(c) >= 10]


def contact_sheet(entries, cards, destination, ids):
    cols, cell_w, cell_h = 8, 186, 278
    for page in range(0, len(ids), 64):
        part = ids[page:page + 64]
        sheet = Image.new("RGB", (cols * cell_w, ((len(part) + cols - 1) // cols) * cell_h), "#20242a")
        draw = ImageDraw.Draw(sheet)
        for i, cid in enumerate(part):
            item = entries[cid]
            source = Image.open(ART / cards[cid]["file"]).convert("RGB")
            if source.width > source.height:
                source = source.transpose(Image.Transpose.ROTATE_90)
            source.thumbnail((176, 246))
            x, y = (i % cols) * cell_w + 5, (i // cols) * cell_h + 22
            sheet.paste(source, (x, y))
            if item["art"]:
                l, t, r, b = item["art"]
                draw.rectangle((x + l * source.width, y + t * source.height,
                                x + r * source.width, y + b * source.height), outline="#ff0066", width=1)
                if item["outline"]:
                    draw.line([(x + px * source.width, y + py * source.height) for px, py in item["outline"]]
                              + [(x + item["outline"][0][0] * source.width, y + item["outline"][0][1] * source.height)],
                              fill="#00ffff", width=1)
            draw.text((x, y - 18), f'{cid} {item["confidence"]:.2f}', fill="white")
        sheet.save(destination / f"frames-{page // 64:03d}.jpg", quality=94)


def main():
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument("--review-dir", type=Path)
    parser.add_argument("--verify", action="store_true")
    options = parser.parse_args()
    index = json.loads((RES / "card-index.json").read_text())
    images = json.loads((RES / "card-art.json").read_text())["images"]
    override_path = ROOT / "scripts/foil-geometry-overrides.json"
    overrides = json.loads(override_path.read_text()) if override_path.exists() else {}
    if options.verify:
        entries = json.loads(OUT.read_text())["cards"]
        assert set(entries) == {c[0] for c in index["cards"]}, "Geometry coverage mismatch"
        for cid, item in entries.items():
            assert item["sha256"] == images[cid]["sha256"], f"Changed original: {cid}"
            if item["art"]:
                l, t, r, b = item["art"]
                assert 0 <= l < r <= 1 and 0 <= t < b <= 1, cid
        print(f"PASS geometry coverage + original hashes + bounds: {len(entries)}")
        return
    tasks = [(c, index["rarities"], images[c[0]], overrides.get(c[0])) for c in index["cards"]]
    with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
        entries = dict(pool.map(analyze, tasks))
    OUT.write_text(json.dumps(dict(version=1, cards=entries), separators=(",", ":"), sort_keys=True) + "\n")
    counts = Counter(v["profile"] for v in entries.values())
    print(json.dumps(counts, indent=2))
    low = sorted((cid for cid, e in entries.items() if e["confidence"] < .20), key=lambda cid: entries[cid]["confidence"])
    print(f"Measured {len(entries)} originals; low-edge-evidence: {len(low)}")
    if options.review_dir:
        options.review_dir.mkdir(parents=True, exist_ok=True)
        for old in options.review_dir.glob("frames-*.jpg"):
            old.unlink()  # Only this tool's reproducible diagnostic sheets.
        selected = [c[0] for c in index["cards"] if c[0].startswith(("cel30", "cel25c"))]
        # Representatives of every actual source set AND layout; then the
        # lowest-confidence detections. Full manifest covers every card.
        seen = set()
        for cid, entry in entries.items():
            group = (cid.split("-")[0], entry["profile"])
            if group not in seen:
                seen.add(group)
                if cid not in selected:
                    selected.append(cid)
        selected += [cid for cid in low if cid not in selected]
        contact_sheet(entries, images, options.review_dir, selected)
        (options.review_dir / "low-confidence.json").write_text(json.dumps(low))


if __name__ == "__main__":
    main()
