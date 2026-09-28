#!/usr/bin/env python3
"""Capture printing-specific reference art and trace its visible foil marks.

The output describes visible reference marks, not measured factory emboss dies.
Source hashes and registration stay attached to each original/printing.
"""
import concurrent.futures
import argparse
import hashlib
import json
import shutil
from pathlib import Path
import urllib.request
import urllib.error
from collections import defaultdict
import cv2
import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
RES = ROOT / "Sources/PokePackBar/Resources"
CACHE = ROOT / "local-assets/physical-foil-references"
REFERENCE_OVERRIDES = json.loads((ROOT / 'scripts/physical-foil-reference-overrides.json').read_text())


def reference_url(card_id, finish, product):
    override = REFERENCE_OVERRIDES.get(f'{card_id}#{finish}')
    return override['url'] if override else f"https://tcgplayer-cdn.tcgplayer.com/product/{product['productID']}_in_1000x1000.jpg"


def fetch(url, name):
    path = CACHE / name
    if not path.exists():
        request = urllib.request.Request(url, headers={"User-Agent": "PokePackBar/foil-reference-audit"})
        try:
            with urllib.request.urlopen(request, timeout=45) as response:
                path.write_bytes(response.read())
        except (urllib.error.URLError, TimeoutError) as error:
            print(f"UNAVAILABLE {name}: {error}", flush=True)
            return path
    return path


def capture():
    CACHE.mkdir(parents=True, exist_ok=True)
    expansion = json.loads((RES / "expansion-foil.json").read_text())
    jobs = []
    for cid, entry in expansion["ascendedParallels"].items():
        for finish, product in [("patternedReverse", entry), ("reverseHolo", entry["energy"])]:
            url = reference_url(cid, finish, product)
            jobs.append((url, f"{cid}-{finish}.jpg"))
    jobs.extend((f"https://images.pokemontcg.io/ex{n}/logo.png", f"ex{n}-logo.png") for n in range(7, 17))
    with concurrent.futures.ThreadPoolExecutor(max_workers=10) as pool:
        for result in pool.map(lambda args: fetch(*args), jobs):
            print(result.name, flush=True)


def mark_signal(path):
    """Separate the lighter foil from the surrounding coloured panel/ink."""
    image = np.asarray(Image.open(path).convert("RGB").resize((600, 837)))
    gray = cv2.cvtColor(image, cv2.COLOR_RGB2GRAY).astype(float)
    yy, xx = np.mgrid[:837, :600]
    x, y = (xx - 300) / 600, (yy - 564) / 600
    circle = x*x + y*y
    panel = (abs(x) < .37) & (abs(y) < .255)
    reference = panel & (circle > .245**2)
    design = np.stack([np.ones_like(x), x, y, x*y, x*x, y*y], axis=-1)
    selected = reference
    for _ in range(4):
        fit = np.linalg.lstsq(design[selected], gray[selected], rcond=None)[0]
        residual = gray - design @ fit
        selected = reference & (abs(residual) < 13)
    interior = circle < .235**2
    threshold = max(10, np.percentile(residual[interior], 80) * .47)
    signal = (residual > threshold) & interior
    return signal.astype('uint8') * 255, image


def inspect_consensus(output):
    index = json.loads((RES / "card-index.json").read_text())
    cards = {c[0]: c for c in index["cards"]}
    parallels = json.loads((RES / "expansion-foil.json").read_text())["ascendedParallels"]
    groups = defaultdict(list)
    for cid, entry in parallels.items():
        for finish, motif in [("patternedReverse", entry['pattern']), ("reverseHolo", cards[cid][4])]:
            path = CACHE / f"{cid}-{finish}.jpg"
            if path.exists():
                mask, _ = mark_signal(path)
                groups[motif].append(mask)
    out = Image.new('RGB', (1200, 4*280), '#ddd')
    draw = ImageDraw.Draw(out)
    for n, (motif, masks) in enumerate(sorted(groups.items())):
        mask = (np.mean(np.stack(masks) > 0, axis=0) > .45).astype('uint8')*255
        mask = cv2.morphologyEx(mask, cv2.MORPH_CLOSE, np.ones((5,5), np.uint8))
        mask = cv2.morphologyEx(mask, cv2.MORPH_OPEN, np.ones((5,5), np.uint8))
        crop = Image.fromarray(mask).crop((150,415,450,715)).resize((260,260))
        x,y=n%4*300,n//4*280
        out.paste(crop,(x,y+20));draw.text((x,y),f'{motif}: {len(masks)}',fill='black')
    output.parent.mkdir(parents=True, exist_ok=True)
    out.save(output)


def contours(mask):
    found, _ = cv2.findContours(mask, cv2.RETR_TREE, cv2.CHAIN_APPROX_SIMPLE)
    return [cv2.approxPolyDP(c, .55, True).reshape(-1, 2) for c in found if abs(cv2.contourArea(c)) > 32]


def compile_marks():
    cv2.setRNGSeed(0)
    index = json.loads((RES / 'card-index.json').read_text())
    cards = {c[0]: c for c in index['cards']}
    art = json.loads((RES / 'card-art.json').read_text())['images']
    parallels = json.loads((RES / 'expansion-foil.json').read_text())['ascendedParallels']
    grouped = defaultdict(list)
    observations = {}
    for cid, entry in parallels.items():
        for finish, motif in [('patternedReverse', entry['pattern']), ('reverseHolo', cards[cid][4])]:
            key = f'{cid}#{finish}'
            path = CACHE / f'{cid}-{finish}.jpg'
            if path.exists():
                mask, image = mark_signal(path)
                observations[key] = (mask, image)
                grouped[motif].append(mask)
    templates = {}
    for motif, masks in grouped.items():
        mask = (np.mean(np.stack(masks) > 0, axis=0) > .45).astype('uint8')*255
        mask = cv2.morphologyEx(mask, cv2.MORPH_CLOSE, np.ones((5,5), np.uint8))
        mask = cv2.morphologyEx(mask, cv2.MORPH_OPEN, np.ones((5,5), np.uint8))
        polygon = contours(mask)
        templates[motif] = polygon
    result = {'version': 1, 'method': 'Visible international printing marks traced by multi-scan consensus; not factory emboss dies',
              'templates': {}, 'ascended': {}, 'inkMasks': {}, 'exLogos': {}, 'unavailable': []}
    for motif, polygons in templates.items():
        result['templates'][motif] = {'referenceCount': len(grouped[motif]),
            'contours': [[[round(float(x)/600, 6), round(float(y)/837, 6)] for x, y in contour] for contour in polygons]}
    sift = cv2.SIFT_create(nfeatures=2000)
    detector_mask = np.full((837, 600), 255, np.uint8)
    detector_mask[420:710, 135:465] = 0
    for cid, entry in parallels.items():
        original = np.asarray(Image.open(ROOT / 'local-assets/CardArt' / art[cid]['file']).convert('RGB').resize((600,837)))
        original_gray = cv2.cvtColor(original, cv2.COLOR_RGB2GRAY)
        # Printing ink is not foil. Exclude neutral dark lettering rather than
        # adding bright emblem paint over the attacks/ability text.
        yy, xx = np.mgrid[:837, :600]
        neutral = original.max(axis=2).astype(float) - original.min(axis=2).astype(float)
        ink = ((original_gray < 88) & (neutral < 46) & (xx > 120) & (xx < 480) & (yy > 410) & (yy < 725)).astype('uint8')*255
        ink = cv2.dilate(ink, np.ones((2,2),np.uint8))
        ink_contours, _ = cv2.findContours(ink, cv2.RETR_TREE, cv2.CHAIN_APPROX_SIMPLE)
        result['inkMasks'][cid] = [[[round(float(x)/600,6),round(float(y)/837,6)] for x,y in cv2.approxPolyDP(c,.40,True).reshape(-1,2)]
            for c in ink_contours if abs(cv2.contourArea(c)) > 3]
        target_keys, target_desc = sift.detectAndCompute(original_gray, detector_mask)
        for finish, motif in [('patternedReverse', entry['pattern']), ('reverseHolo', cards[cid][4])]:
            key = f'{cid}#{finish}'
            reference_key = key
            if reference_key not in observations:
                other = 'reverseHolo' if finish == 'patternedReverse' else 'patternedReverse'
                reference_key = f'{cid}#{other}'
            if reference_key not in observations:
                result['unavailable'].append(key)
                continue
            signal, reference = observations[reference_key]
            reference_gray = cv2.cvtColor(reference, cv2.COLOR_RGB2GRAY)
            source_keys, source_desc = sift.detectAndCompute(reference_gray, detector_mask)
            pairs = cv2.BFMatcher().knnMatch(source_desc, target_desc, k=2)
            good = [a for a,b in pairs if a.distance < .70*b.distance]
            if len(good) < 16:
                result['unavailable'].append(key)
                continue
            src = np.float32([source_keys[m.queryIdx].pt for m in good])
            dst = np.float32([target_keys[m.trainIdx].pt for m in good])
            matrix, inliers = cv2.estimateAffinePartial2D(src, dst, method=cv2.RANSAC, ransacReprojThreshold=2)
            if matrix is None or int(inliers.sum()) < 14:
                result['unavailable'].append(key)
                continue
            shift = (0, 0)
            if reference_key == key:
                template = np.zeros((837,600), np.uint8)
                cv2.drawContours(template, templates[motif], -1, 255, cv2.FILLED)
                # Record observed registration, not a card-width/panel-height formula.
                best = -1
                for dy in range(-6,7,2):
                    for dx in range(-6,7,2):
                        shifted = np.roll(template, (dy,dx), axis=(0,1)) > 0
                        score = np.count_nonzero(shifted & (signal > 0)) / max(1, np.count_nonzero(shifted | (signal > 0)))
                        if score > best:
                            best, shift = score, (dx,dy)
            matrix[:,2] += matrix[:,:2] @ np.array(shift)
            normalized = np.diag([1/600,1/837]) @ matrix @ np.diag([600,837,1])
            reference_id, reference_finish = reference_key.split('#')
            reference_product = entry if reference_finish == 'patternedReverse' else entry['energy']
            path = CACHE / f'{reference_id}-{reference_finish}.jpg'
            residual = np.linalg.norm(cv2.transform(src[None], matrix)[0] - dst, axis=1)
            result['ascended'][key] = {'sha256': art[cid]['sha256'], 'motif': motif,
                'transform': [round(float(v),8) for v in normalized.reshape(-1)],
                'referenceURL': reference_url(cid, reference_finish, reference_product),
                'referenceSHA256': hashlib.sha256(path.read_bytes()).hexdigest(),
                'registration': 'own-printing' if reference_key == key else 'paired-printing-same-card',
                'inliers': int(inliers.sum()), 'registrationMedianPixels': round(float(np.median(residual[inliers[:,0]>0])),3)}
            print('registered', key, result['ascended'][key]['registration'], flush=True)
    logo_dir = RES / 'foil-marks'
    logo_dir.mkdir(exist_ok=True)
    for n in range(7,17):
        name = f'ex{n}-logo.png'
        source = CACHE / name
        shutil.copyfile(source, logo_dir / name)
        image = Image.open(source)
        result['exLogos'][f'ex{n}'] = {'file': name, 'width': image.width, 'height': image.height,
            'sha256': hashlib.sha256(source.read_bytes()).hexdigest(),
            'sourceURL': f'https://images.pokemontcg.io/ex{n}/logo.png',
            'registration': 'frame-relative; individual physical stamp placement not certified'}
    (RES / 'physical-foil-marks.json').write_text(json.dumps(result, separators=(',',':'))+'\n')
    print('TOTAL', len(result['ascended']), 'MISSING', result['unavailable'], flush=True)


def verify():
    data = json.loads((RES / 'physical-foil-marks.json').read_text())
    art = json.loads((RES / 'card-art.json').read_text())['images']
    parallels = json.loads((RES / 'expansion-foil.json').read_text())['ascendedParallels']
    expected = {f'{cid}#{finish}' for cid in parallels for finish in ['reverseHolo','patternedReverse']}
    assert set(data['ascended']) | set(data['unavailable']) == expected
    assert not (set(data['ascended']) & set(data['unavailable']))
    assert len(data['templates']) == 16 and len(data['exLogos']) == 10
    for name, template in data['templates'].items():
        assert template['referenceCount'] >= 3, name
        assert template['contours']
        assert all(len(c) >= 3 and all(len(p) == 2 and all(0 <= v <= 1 for v in p) for p in c) for c in template['contours']), name
    for key, entry in data['ascended'].items():
        cid, finish = key.split('#')
        assert entry['sha256'] == art[cid]['sha256'], key
        assert entry['motif'] in data['templates'] and entry['inliers'] >= 14, key
        assert len(entry['transform']) == 6 and all(np.isfinite(entry['transform'])), key
        for contour in data['templates'][entry['motif']]['contours']:
            for x,y in contour:
                m = entry['transform']
                assert 0 < m[0]*x+m[1]*y+m[2] < 1 and 0 < m[3]*x+m[4]*y+m[5] < 1, key
    for key, entry in data['exLogos'].items():
        assert hashlib.sha256((RES/'foil-marks'/entry['file']).read_bytes()).hexdigest() == entry['sha256'], key
    print(f"PASS physical foil marks: {len(data['ascended'])} registered, {len(data['unavailable'])} explicitly unavailable, 16 traced motifs, 10 source-hashed logos")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument('--capture', action='store_true')
    mode.add_argument('--compile', action='store_true')
    mode.add_argument('--verify', action='store_true')
    mode.add_argument('--preview', type=Path)
    args = parser.parse_args()
    if args.preview:
        inspect_consensus(args.preview)
    elif args.compile:
        compile_marks()
    elif args.capture:
        capture()
    else:
        verify()
