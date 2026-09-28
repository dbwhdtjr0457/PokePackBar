#!/usr/bin/env python3
"""Register manually reviewed materials to local originals, never download photos.

Material decisions live in reviewed-foil-recipes.json. Image analysis below only
registers printed landmarks; it cannot infer an actual emboss/foil manufacturing
plate. Run --verify in packaging to reject stale registrations.
"""
import argparse
import hashlib
import json
from pathlib import Path

import cv2
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
RES = ROOT / 'Sources/PokePackBar/Resources'
OUT = RES / 'reviewed-foil.json'


def polygons(mask):
    h, w = mask.shape
    contours, _ = cv2.findContours(mask, cv2.RETR_TREE, cv2.CHAIN_APPROX_SIMPLE)
    return [[[round(float(x) / w, 6), round(float(y) / h, 6)]
             for x, y in cv2.approxPolyDP(c, 0.6, True).reshape(-1, 2)]
            for c in contours if cv2.contourArea(c) >= 5]


def rect(x1, y1, x2, y2):
    return [[x1, y1], [x2, y1], [x2, y2], [x1, y2]]


def raster(contours, shape):
    h, w = shape
    mask = np.zeros(shape, np.uint8)
    points = [np.round(np.array(c) * [w, h]).astype('int32') for c in contours]
    if points:
        cv2.fillPoly(mask, points, 255)
    return mask


def union(shape, *groups):
    mask = np.zeros(shape, np.uint8)
    for group in groups:
        mask |= raster(group, shape)
    return polygons(mask)


def perimeter(shape, inset):
    h, w = shape
    mask = np.full(shape, 255, np.uint8)
    x1, y1, x2, y2 = inset
    mask[round(y1*h):round(y2*h), round(x1*w):round(x2*w)] = 0
    return polygons(mask)


def anniversary_stamp(rgb, centre, ear_extension=.05):
    """Retain printed anniversary ink, including its black ear tips."""
    h, w = rgb.shape[:2]
    y, x = np.mgrid[:h, :w]
    r, g, b = [rgb[:, :, i].astype(float) for i in range(3)]
    cx, cy = centre
    roi = (y > h*(cy-.10)) & (y < h*(cy+.05)) & (x > w*(cx-.14)) & (x < w*(cx+.14))
    mask = ((r > 180) & (g > 140) & (b < 95) & roi).astype('uint8') * 255
    cs, _ = cv2.findContours(mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    cs = [c for c in cs if cv2.contourArea(c) > w*h*.002]
    if not cs:
        return []
    def distance(c):
        moments = cv2.moments(c)
        return ((moments['m10']/moments['m00']/w-cx)**2
                +(moments['m01']/moments['m00']/h-cy)**2)
    c = min(cs, key=distance)
    # Printed stamp has a yellow face and black ear tips: convex hull of nearby
    # yellow + black pixels, constrained to the detected stamp's own footprint.
    sx, sy, sw, sh = cv2.boundingRect(c)
    x1, x2 = max(0,sx-round(w*.013)), min(w,sx+sw+round(w*.013))
    y1, y2 = max(0,sy-round(h*ear_extension)), min(h,sy+sh+round(h*.008))
    candidate = (((r < 75)&(g < 75)&(b < 75)) | (mask > 0))
    out = np.zeros((h,w), np.uint8)
    out[y1:y2,x1:x2] = candidate[y1:y2,x1:x2].astype('uint8') * 255
    out = cv2.morphologyEx(out, cv2.MORPH_CLOSE, np.ones((5,5),np.uint8))
    cs, _ = cv2.findContours(out, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    out[:] = 0
    # Keep separate black tips too. Do not fill the empty notch between ears.
    for part in cs:
        if cv2.contourArea(part) > w*h*.00015:
            cv2.drawContours(out, [part], -1, 255, -1)
    return polygons(out)


def pikachu_regions(rgb):
    h, w = rgb.shape[:2]
    y, x = np.mgrid[:h, :w]
    r, g, b = [rgb[:, :, i].astype(float) for i in range(3)]
    roi = (x > w * .19) & (x < w * .81) & (y > h * .525) & (y < h * .84)
    yellow = ((r > 190) & (g > 140) & (b < 78) & roi).astype('uint8') * 255
    yellow = cv2.morphologyEx(yellow, cv2.MORPH_CLOSE, np.ones((9, 9), np.uint8))
    contours, _ = cv2.findContours(yellow, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    assert contours, 'No yellow anniversary silhouette'
    logo = np.zeros((h, w), np.uint8)
    cv2.drawContours(logo, [max(contours, key=cv2.contourArea)], -1, 255, -1)
    dark = ((r < 85) & (g < 85) & (b < 85) & roi & (y < h * .635)).astype('uint8') * 255
    contours, _ = cv2.findContours(dark, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    for c in contours:
        _, _, cw, ch = cv2.boundingRect(c)
        if cw > w * .055 and ch > h * .04:
            cv2.drawContours(logo, [c], -1, 255, -1)
    logo = cv2.morphologyEx(logo, cv2.MORPH_CLOSE, np.ones((5, 5), np.uint8))
    fraction = np.count_nonzero(logo) / (w * h)
    assert .05 < fraction < .15, fraction
    # Trace the actual neutral silver perimeter, not a generic stroke on the
    # card holder. Text/illustration pixels cannot enter this edge search band.
    edge = (x < w * .055) | (x > w * .955) | (y < h * .035) | (y > h * .965)
    neutral = ((np.maximum.reduce([r, g, b]) - np.minimum.reduce([r, g, b]) < 27)
               & (r > 65) & (r < 240) & edge).astype('uint8') * 255
    neutral = cv2.morphologyEx(neutral, cv2.MORPH_CLOSE, np.ones((3, 3), np.uint8))
    return polygons(logo), polygons(neutral)


def ink_exclusions(rgb, art):
    h, w = rgb.shape[:2]
    y, x = np.mgrid[:h, :w]
    r, g, b = [rgb[:, :, i].astype(float) for i in range(3)]
    outside_art = (y > art[3] * h) | (y < art[1] * h)
    dark = (r < 85) & (g < 85) & (b < 85)
    red = (r > g * 1.7) & (r > b * 1.7) & (r > 110) & (y > h * .69) & (y < h * .81)
    mask = ((dark | red) & outside_art & (x > w * .045) & (x < w * .96)).astype('uint8') * 255
    count, labels, stats, _ = cv2.connectedComponentsWithStats(mask)
    out = np.zeros_like(mask)
    for i in range(1, count):
        _, _, cw, ch, area = stats[i]
        if 4 < area and cw < w * .075 and ch < h * .047:
            out[labels == i] = 255
    return polygons(out)


def build():
    recipes = json.loads((ROOT / 'scripts/reviewed-foil-recipes.json').read_text())
    recipes.update(json.loads((ROOT / 'scripts/reviewed-classic30-recipes.json').read_text()))
    followups = json.loads((ROOT/'scripts/reviewed-pikachu-followups.json').read_text())
    for cid, review in followups.items():
        recipe = recipes[cid]
        recipe.update(review)
        recipe.update(preserveUnresolvedInterior=False, preserveLowerInterior=False,
                      preserveArtwork=False, grainInArtwork=True)
        recipe['referenceURLs'].append(review['reference'])
        recipe['evidenceStatus'] = 'additional_JP_foil_reveal_compared_to_EN_source'
        recipe['reconstruction'] = ('Large radial fans observed in the additional JP reference, registered to EN card coordinates. '
            'Manufacturer reveal uses a repeated foil-sheet phase; real cut/lot phase is not certified. '+review['observation'])
        # These nine additional references show the same display-sheet phase.
        # Do not manufacture false per-card differences for uniqueness tests.
        recipe['fans'] = [dict(x=x,y=y,radius=r,phase=p) for x,y,r,p in [
            (.085,.09,.32,.12),(.41,.35,.27,.4),(.83,.44,.29,.7),
            (.81,.735,.34,1.0),(.62,.06,.29,1.3)]]
    originals = json.loads((RES / 'card-art.json').read_text())['images']
    geometry = json.loads((RES / 'foil-geometry.json').read_text())['cards']
    subjects = json.loads((ROOT / 'scripts/reviewed-subject-regions.json').read_text())
    expansion = json.loads((RES/'expansion-foil.json').read_text())['cards']
    result = {}
    for cid, recipe in recipes.items():
        original = originals[cid]
        path = ROOT / 'local-assets/CardArt' / original['file']
        assert hashlib.sha256(path.read_bytes()).hexdigest() == original['sha256'], cid
        source = Image.open(path).convert('RGB')
        if source.width > source.height:
            source = source.transpose(Image.Transpose.ROTATE_90)
        rgb = np.array(source)
        art = geometry[cid]['art']
        ink = ink_exclusions(rgb, art or [0, .11, 1, .51])
        shape = rgb.shape[:2]
        layers = []
        base_include, base_exclude = [], []

        def layer(name, material, include, exclude=None, strength=1):
            if include:
                layers.append(dict(name=name, material=material, include=include,
                                   exclude=exclude or [], strength=strength))

        if recipe['style'] == 'pikachu30':
            logo, border = pikachu_regions(rgb)
            layer('silver-rim', 'silverFragments', border, strength=.95)
            layer('anniversary-logo', 'goldFragments', logo, ink, .90)
            base_exclude = union(shape, logo, border)
            if recipe.get('preserveUnresolvedInterior'):
                base_include = [rect(.05,.03,.955,.967)]
            elif recipe.get('preserveLowerInterior'):
                base_include = [rect(.05,art[3],.955,.967)]
            elif recipe.get('preserveArtwork'):
                base_include = [rect(*art)]
            if recipe.get('grainInArtwork') and not recipe.get('preserveArtwork'):
                protection = []
                if cid in followups:
                    r,g,b = [rgb[:,:,i].astype(float) for i in range(3)]
                    if recipe.get('cyanBackgroundOnly'):
                        allowed = (g > r*1.15)&(b > r*1.15)
                    else:
                        allowed = ~((r > 160)&(g > 110)&(b < g*.65))
                    allowed &= (np.max(rgb,axis=2)-np.min(rgb,axis=2) > 24)
                    protection = polygons((~allowed).astype('uint8')*255)
                layer('artwork-grain', 'confetti', [rect(*art)], protection,
                      recipe.get('artGrainStrength',.20))
                layer('artwork-micro-etch', 'microEtching', [rect(*art)], strength=.65)
            if recipe.get('fans'):
                layer('radial-sheet', 'radialFans', [rect(.05, .03, .955, .967)], union(shape, logo, ink), 1)
        elif recipe['style'] in {'classic25','classic30'}:
            classic30 = recipe['style'] == 'classic30'
            stamp = anniversary_stamp(rgb, recipe['stampCentre'])
            subject = []
            if recipe.get('subject'):
                assert subjects[cid]['sha256'] == original['sha256'], cid
                subject = subjects[cid]['subject']
            matte = union(shape, *[[rect(*box)] for box in recipe.get('mattePanels', [])])
            printed = union(shape, stamp, ink)
            background = [rect(.043,.035,.956,.97)] if recipe.get('fullArt') else [rect(*art)]
            if recipe.get('artExtension'):
                background = union(shape, background, recipe['artExtension'])
            if recipe.get('extraFoilBoxes'):
                background = union(shape, background, [rect(*box) for box in recipe['extraFoilBoxes']])
            border = expansion[cid]['goldFrame'] if classic30 else perimeter(shape, [.052,.041,.948,.958])
            exclusions = union(shape, subject, stamp, matte, border if classic30 else [], ink if recipe.get('fullArt') else [])
            layer('illustration-confetti', 'confetti', background,
                  exclusions, .86)
            if recipe.get('backgroundStars'):
                layer('illustration-stars', 'spectralStars', background, exclusions, .76)
            if recipe.get('subjectEtching') and subject:
                layer('subject-micro-etch', 'microEtching', subject, union(shape,stamp,matte,border), .85)
            if recipe.get('fullArtEtching'):
                layer('full-art-micro-etch', 'microEtching', background, union(shape,stamp,matte,border), .45)
            if classic30 or recipe.get('silverRim'):
                layer('gold-rim' if classic30 else 'silver-rim',
                      'goldFragments' if classic30 else 'silverFragments', border, strength=.95)
                if recipe.get('goldStars'):
                    layer('gold-rim-stars', 'goldStars', border, strength=.75)
            if recipe.get('paperEtching'):
                layer('paper-rim-micro-etch', 'microEtching', perimeter(shape,[.052,.041,.948,.958]), strength=.48)
            for i, box in enumerate(recipe.get('ruleBoxes', [])):
                layer(f'rule-foil-{i}', 'silverFragments', [rect(*box)], printed, .70)
        else:
            raise ValueError(f"Unknown recipe: {cid}")
        result[cid + '#' + recipe['finish']] = dict(
            cardID=cid, finish=recipe['finish'], sha256=original['sha256'],
            width=original['width'], height=original['height'],
            referenceURLs=recipe['referenceURLs'], evidenceStatus=recipe['evidenceStatus'],
            reconstruction=recipe['reconstruction'], physicalPlateVerified=False,
            baseInclude=base_include, baseExclude=base_exclude,
            fans=recipe.get('fans', []), layers=layers)
    stamp_exclusions = {}
    index = json.loads((RES/'card-index.json').read_text())
    for row in index['cards']:
        cid = row[0]
        if not cid.startswith('cel30-') or row[2] != 'RR':
            continue
        original = originals[cid]
        rgb = np.array(Image.open(ROOT/'local-assets/CardArt'/original['file']).convert('RGB'))
        # These two originals put the logo left, not over Pikachu's yellow body.
        centre = (.14,.46) if cid in {'cel30-54','cel30-92'} else (.87,.47)
        stamp = anniversary_stamp(rgb,centre,ear_extension=.018)
        assert stamp, ('Missing ordinary ex anniversary stamp',cid)
        stamp_exclusions[cid] = dict(sha256=original['sha256'],contours=stamp)
    assert len(stamp_exclusions) == 12
    return dict(version=1, printings=result,starSheetExclusions=stamp_exclusions)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--verify', action='store_true')
    args = parser.parse_args()
    data = build()
    if args.verify:
        assert data == json.loads(OUT.read_text()), 'Stale reviewed-foil registrations; regenerate'
    else:
        OUT.write_text(json.dumps(data, ensure_ascii=False, separators=(',', ':'), sort_keys=True) + '\n')
    print(f"PASS: {len(data['printings'])} explicitly reviewed printings; image hashes and regions checked; not factory plate certification")


if __name__ == '__main__':
    main()
