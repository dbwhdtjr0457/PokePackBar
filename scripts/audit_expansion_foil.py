#!/usr/bin/env python3
"""Check new-expansion materials, angle response and original-registered borders.

Run after audit_foil_alignment.py --render --sets cel30 cel30c me2pt5 me3 me4 me5.
This is executable evidence, not proof of a factory emboss match.
"""
import argparse
import concurrent.futures
import json
import os
import subprocess
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
RES = ROOT / 'Sources/PokePackBar/Resources'
SETS = {'cel30', 'cel30c', 'me2pt5', 'me3', 'me4', 'me5'}


def foil_map(binary):
    env = dict(os.environ, PPB_OFFLINE='1', PPB_CARD_ART_DIR=str(ROOT / 'local-assets/CardArt'))
    return json.loads(subprocess.check_output([str(binary), '--export-foil-map', '--all-cards'], env=env))


def sheet(items, folder, name):
    for page in range(0, len(items), 12):
        batch = items[page:page + 12]
        result = Image.new('RGB', (4 * 280, ((len(batch) + 3) // 4) * 232), '#15161a')
        draw = ImageDraw.Draw(result)
        for i, item in enumerate(batch):
            cid, finish = item['cardID'], item['finish']
            stem = f'{cid}-{finish}'
            x, y = i % 4 * 280, i // 4 * 232
            draw.text((x + 3, y + 3), stem, fill='white')
            for j, pose in enumerate(['geometry-rest', 'diagonal']):
                with Image.open(folder / f'{stem}-{pose}.png') as image:
                    crop = image.crop((120, 120, 600, 790))
                    crop.thumbnail((138, 200))
                    result.paste(crop, (x + j * 140, y + 23))
        result.save(folder / f'{name}-{page // 12:02d}.jpg', quality=94)


def main():
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument('--renders', required=True, type=Path)
    parser.add_argument('--binary', type=Path, default=ROOT / '.build/release/PokePackBar')
    parser.add_argument('--before', type=Path)
    parser.add_argument('--sheets-only', action='store_true')
    parser.add_argument('--refresh-classic', action='store_true', help='Re-render all 30 source-bound gold masks after refinement')
    args = parser.parse_args()
    values = [v for v in foil_map(args.binary).values() if v['cardID'].split('-')[0] in SETS]
    classic = [v for v in values if v['cardID'].startswith('cel30c-')]
    assert len(values) == 1051 and len(classic) == 30
    if args.refresh_classic:
        env = dict(os.environ, PPB_OFFLINE='1', PPB_CARD_ART_DIR=str(ROOT / 'local-assets/CardArt'))
        def render(item):
            command = [str(args.binary), '--render-holo-preview', item['cardID'], str(args.renders),
                       item['finish'], '--actual-size', '--flat-card', '--compact']
            for extra in [[], ['--geometry']]:
                subprocess.run(command + extra, env=env, check=True, capture_output=True, timeout=45)
        with concurrent.futures.ThreadPoolExecutor(max_workers=2) as executor:
            list(executor.map(render, classic))
    sheet(classic, args.renders, 'gold-frames')
    if args.sheets_only:
        return
    response = {}
    groups = {}
    metadata = {c[0]: c for c in json.loads((RES / 'card-index.json').read_text())['cards']}
    expansion = json.loads((RES / 'expansion-foil.json').read_text())
    matrix = []
    for value in values:
        cid, finish, spec = value['cardID'], value['finish'], value['spec']
        stem = f'{cid}-{finish}'
        images = [np.asarray(Image.open(args.renders / f'{stem}-{pose}.png').convert('RGB'), dtype=float)[120:790, 120:600]
                  for pose in ['rest', 'diagonal']]
        delta = float(np.abs(images[0] - images[1]).mean())
        assert delta > .03, (stem, 'foil does not respond', delta)
        response[stem] = round(delta, 4)
        motif = expansion['ascendedParallels'].get(cid, {}).get('pattern') if finish == 'patternedReverse' else None
        group = (json.dumps(spec, sort_keys=True), metadata[cid][4], motif)
        groups.setdefault(group, value)
        matrix.append({'cardID': cid, 'finish': finish, 'rarity': expansion['cards'][cid]['rarity'],
                       'spec': spec, 'motif': motif, 'meanAngleDelta255': round(delta, 4)})
    sheet(list(groups.values()), args.renders, 'materials')
    regression = {}
    if args.before:
        before = foil_map(args.before)
        current = {v['cardID'] + '#' + v['finish']: v for v in values}
        for key, value in current.items():
            old = before.get(key)
            if old is None or old['spec'] != value['spec']:
                regression[key] = {'before': old['spec'] if old else None, 'after': value['spec']}
        assert len(regression) == 373, len(regression)
    report = {'originals': 852, 'foilPrintings': len(values), 'specs': len({json.dumps(v['spec'], sort_keys=True) for v in values}),
              'visualGroupsIncludingElementAndMotif': len(groups), 'goldFrames': len(classic),
              'minimumMeanAngleDelta255': min(response.values()), 'changedPrintings': len(regression) if args.before else None,
              'physicalEmbossVerified': False}
    (args.renders / 'expansion-report.json').write_text(json.dumps(report, indent=2) + '\n')
    (args.renders / 'printing-matrix.json').write_text(json.dumps(matrix, indent=2) + '\n')
    if args.before:
        (args.renders / 'regressions.json').write_text(json.dumps(regression, indent=2) + '\n')
    print(json.dumps(report, indent=2))


if __name__ == '__main__':
    main()
