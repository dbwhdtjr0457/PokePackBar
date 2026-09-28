"""Disposable registration diagnostics; these do not approve a proposed mask."""
import argparse
import json
from pathlib import Path

import cv2
import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
RES = ROOT / 'Sources/PokePackBar/Resources'


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--proposals', type=Path)
    parser.add_argument('--subjects', action='store_true')
    parser.add_argument('--star-stamps', action='store_true')
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    art = json.loads((RES / 'card-art.json').read_text())['images']
    records = {}
    if args.proposals:
        for file in sorted(args.proposals.glob('*.png')):
            cid = file.stem
            bounds = json.loads(file.with_suffix('.json').read_text())
            mask = np.array(Image.open(file).convert('L'))
            mask = (mask > 150).astype('uint8') * 255
            contours, _ = cv2.findContours(mask, cv2.RETR_TREE, cv2.CHAIN_APPROX_SIMPLE)
            h, w = mask.shape
            polygons = []
            for c in contours:
                if cv2.contourArea(c) < 15:
                    continue
                points = cv2.approxPolyDP(c, .7, True).reshape(-1, 2)
                polygons.append([[round(bounds[0] + float(x) / w * (bounds[2] - bounds[0]), 6),
                                  round(bounds[1] + float(y) / h * (bounds[3] - bounds[1]), 6)] for x, y in points])
            records[cid] = dict(subject=polygons, sha256=art[cid]['sha256'],
                                status='proposal_requires_manual_review')
        (args.output / 'proposed-subject-contours.json').write_text(json.dumps(records, separators=(',', ':')))
    elif args.subjects:
        records = json.loads((ROOT / 'scripts/reviewed-subject-regions.json').read_text())
    elif args.star_stamps:
        entries = json.loads((RES / 'reviewed-foil.json').read_text())['starSheetExclusions']
        records = {cid: {'stamp': entry['contours']} for cid, entry in entries.items()}
    else:
        entries = json.loads((RES / 'reviewed-foil.json').read_text())['printings']
        records = {e['cardID']: {layer['name']: layer for layer in e['layers']} for e in entries.values()}
    colors = ['#ff00ff', '#00d8ff', '#00ff70', '#ff9000', '#aaaaee']
    for offset in range(0, len(records), 8):
        canvas = Image.new('RGB', (960, 1440), '#eeeeee')
        draw = ImageDraw.Draw(canvas)
        for slot, (cid, fields) in enumerate(list(records.items())[offset:offset+8]):
            original = Image.open(ROOT / 'local-assets/CardArt' / art[cid]['file']).convert('RGB')
            if original.width > original.height:
                original = original.transpose(Image.Transpose.ROTATE_90)
            view = original.copy()
            for i, (field, value) in enumerate((p for p in fields.items() if isinstance(p[1], (list,dict)))):
                contours = value['include'] if isinstance(value, dict) else value
                mask = np.zeros((original.height, original.width), np.uint8)
                points = [np.round(np.array(c) * [original.width, original.height]).astype('int32') for c in contours]
                if points:
                    cv2.fillPoly(mask, points, 255)
                if isinstance(value, dict) and value['exclude']:
                    exclusion = np.zeros_like(mask)
                    points = [np.round(np.array(c)*[original.width,original.height]).astype('int32') for c in value['exclude']]
                    cv2.fillPoly(exclusion, points, 255)
                    mask &= ~exclusion
                tint = Image.blend(view, Image.new('RGB', original.size, colors[i % len(colors)]), .60)
                view = Image.composite(tint, view, Image.fromarray(mask))
            x, y = slot % 2 * 480, slot // 2 * 360
            draw.text((x + 2, y + 2), cid, fill='black')
            for col, im in enumerate([original, view]):
                im.thumbnail((240, 335))
                canvas.paste(im, (x + col * 240, y + 22))
        canvas.save(args.output / f'regions-{offset//8:02d}.jpg', quality=95)
    print(f"Diagnostic sheets for {len(records)} originals; NOT manual approval")


if __name__ == '__main__':
    main()
