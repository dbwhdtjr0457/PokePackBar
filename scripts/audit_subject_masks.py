#!/usr/bin/env python3
"""Validate reviewed source-art silhouettes; optionally emit diagnostic sheets.

The editable source is foil-subject-masks.json: normalized image contours with
their original hash and dimensions. These are NOT measured physical foil plates.
Never regenerate them by blindly accepting all Vision foreground instances.
Dependencies for --contact-sheets: Pillow, numpy, opencv-python-headless.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RES = ROOT / 'Sources/PokePackBar/Resources'
REQUIRED = {f'neo4-{n}' for n in range(106, 114)} | {f'ex11-{n}' for n in range(1, 19)} | {f'ex15-{n}' for n in range(1, 13)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--art-dir', type=Path, default=ROOT / 'local-assets/CardArt')
    parser.add_argument('--contact-sheets', type=Path)
    args = parser.parse_args()
    manifest = json.loads((RES / 'foil-subject-masks.json').read_text())
    art = json.loads((RES / 'card-art.json').read_text())['images']
    geometry = json.loads((RES / 'foil-geometry.json').read_text())['cards']
    assert manifest['version'] == 1 and set(manifest['cards']) == REQUIRED
    for cid, entry in manifest['cards'].items():
        original = art[cid]
        raw = (args.art_dir / original['file']).read_bytes()
        assert hashlib.sha256(raw).hexdigest() == original['sha256'] == entry['sha256'], cid
        assert (entry['width'], entry['height']) == (original['width'], original['height']), cid
        assert entry['physicalPlateVerified'] is False, cid
        assert 0.05 < entry['subjectArtFraction'] < 0.90, cid
        assert bool(entry['border']) == cid.startswith('ex'), cid
        assert entry['subject'], cid
        for contour in entry['subject'] + entry['border']:
            assert len(contour) >= 3, cid
            assert all(len(p) == 2 and all(math.isfinite(v) and 0 <= v <= 1 for v in p) for p in contour), cid
        bounds = geometry[cid]['art']
        for contour in entry['subject']:
            assert all(bounds[0] - .003 <= x <= bounds[2] + .003 and bounds[1] - .003 <= y <= bounds[3] + .003 for x, y in contour), cid
    print('PASS: 38 source-hash-bound silhouettes; 8 paper borders and 30 separately measured metal rims')
    if args.contact_sheets:
        contact_sheets(manifest['cards'], art, args.art_dir, args.contact_sheets)


def contact_sheets(cards, art, art_dir, out):
    import cv2
    import numpy as np
    from PIL import Image, ImageDraw
    out.mkdir(parents=True, exist_ok=True)
    ids = sorted(cards, key=lambda cid: (cid.split('-')[0], int(cid.split('-')[1])))
    for offset in range(0, len(ids), 8):
        sheet = Image.new('RGB', (1040, 1440), '#eeeeee')
        draw = ImageDraw.Draw(sheet)
        for pos, cid in enumerate(ids[offset:offset + 8]):
            original = Image.open(art_dir / art[cid]['file']).convert('RGB')
            width, height = original.size
            view = original.copy()
            for field, color in [('subject', '#00ff00'), ('border', '#ff00ff')]:
                mask = np.zeros((height, width), np.uint8)
                contours = [np.round(np.array(c) * [width, height]).astype('int32') for c in cards[cid][field]]
                if contours:
                    cv2.fillPoly(mask, contours, 255)  # even-odd, preserves silhouette holes
                tint = Image.blend(view, Image.new('RGB', original.size, color), .55)
                view = Image.composite(tint, view, Image.fromarray(mask))
            for col, image in enumerate([original, view]):
                image.thumbnail((240, 335))
                sheet.paste(image, ((pos % 2) * 520 + col * 250, (pos // 2) * 360 + 22))
            draw.text(((pos % 2) * 520, (pos // 2) * 360 + 3), cid, fill='black')
        sheet.save(out / f'subject-mask-{offset // 8:02d}.jpg')


if __name__ == '__main__':
    main()
