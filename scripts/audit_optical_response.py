#!/usr/bin/env python3
"""Native material-family regression renders; pixels are not physical approval.

Uses the production SwiftUI renderer, never a browser recreation or live wallet.
Contact sheets are disposable test artifacts; JSON records are the audit trail.
"""
import argparse
import concurrent.futures
import hashlib
import json
import os
import subprocess
from datetime import datetime, timezone
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]


def make_overviews(output, results):
    """Keep the first two poses at 240pt, never shrink them for a coverage claim."""
    passed = [row for row in results if row['renderStatus'] == 'pass']
    for start in range(0, len(passed), 8):
        sheet = Image.new('RGB', (960, 1440), '#101014')
        for panel, row in enumerate(passed[start:start + 8]):
            source = output / f"{row['key'].replace('#', '-')}.jpg"
            pair = Image.open(source).crop((0, 0, 480, 360))
            sheet.paste(pair, (panel % 2 * 480, panel // 2 * 360))
        sheet.save(output / f'overview-{start // 8:02d}.jpg', quality=95)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--binary', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--ids', nargs='*')
    parser.add_argument('--families', action='store_true')
    parser.add_argument('--changed-materials', action='store_true', help='All reviewed, cracked-ice, ordinary ex and registered Ascended printings')
    parser.add_argument('--sweep', action='store_true')
    parser.add_argument('--overview-only', action='store_true')
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    if args.overview_only:
        make_overviews(output, json.loads((output / 'results.json').read_text())['results'])
        return
    binary = str(args.binary.resolve())
    started_at = datetime.now(timezone.utc).isoformat()
    resource_names = ['reviewed-foil', 'cracked-ice-facets', 'physical-foil-marks', 'expansion-foil']
    resource_hashes = {name: hashlib.sha256((ROOT / 'Sources/PokePackBar/Resources' / (name+'.json')).read_bytes()).hexdigest()
                       for name in resource_names}
    env = dict(os.environ, PPB_OFFLINE='1', PPB_CARD_ART_DIR=str(ROOT / 'local-assets/CardArt'))
    catalogue = json.loads(subprocess.check_output([binary, '--export-foil-map', '--all-cards'], env=env))
    selected = {}
    if args.changed_materials:
        for key, value in catalogue.items():
            if ((value.get('opticalMaterial') or '').startswith('reviewed-')
                or value['spec']['pattern'] in {'doubleRareSheen','crackedIce'}
                or value['spec'].get('treatment') == 'megaDoubleRare'
                or (value['cardID'].startswith('me2pt5-') and value['finish'] in {'patternedReverse','reverseHolo'})):
                selected[key] = value
    if args.families:
        seen = set()
        for key, value in sorted(catalogue.items()):
            spec = value['spec']
            family = tuple(spec.get(field) for field in ['pattern', 'texture', 'coverage', 'border', 'treatment']) + (value.get('opticalMaterial'),)
            if family not in seen:
                selected[key] = value
                seen.add(family)
    for card_id in args.ids or []:
        matches = {key: value for key, value in catalogue.items() if value['cardID'] == card_id}
        if not matches:
            raise SystemExit(f'Unknown foil ID: {card_id}')
        selected.update(matches)
    if not selected:
        raise SystemExit('Choose --families or --ids')

    def render(item):
        key, value = item
        folder = output / 'images' / key.replace('#', '-')
        row = dict(key=key, **value)
        try:
            flags = ['--sweep'] if args.sweep else []
            subprocess.run([binary, '--render-holo-preview', value['cardID'], str(folder), value['finish'],
                            '--actual-size', '--flat-card', *flags], env=env,
                           capture_output=True, check=True, timeout=120)
            stem = f"{value['cardID']}-{value['finish']}"
            poses = [f'sweep-{i:02d}' for i in range(36)] if args.sweep else ['rest', 'left', 'right', 'up', 'down', 'diagonal']
            frames = [np.asarray(Image.open(folder / f'{stem}-{pose}.png').convert('RGB')
                                 .crop((120, 120, 600, 790)), dtype=float) for pose in poses]
            differences = [float(np.abs(frame - frames[0]).mean()) for frame in frames[1:]]
            # Full-card mean is a triage signal only; small, correct masks have
            # naturally low values and must not be enlarged to satisfy a score.
            row.update(renderStatus='pass', maxAngleMeanDelta255=max(differences),
                       minAngleMeanDelta255=min(differences), frameCount=len(frames),
                       physicalAccuracy='not_certified_by_render_test')
            if args.sweep:
                row['adjacentFrameDelta255'] = [float(np.abs(frames[(i+1) % 36] - frames[i]).mean()) for i in range(36)]
            sheet = Image.new('RGB', (240 * 3, 360 * 2), '#101014')
            draw = ImageDraw.Draw(sheet)
            for panel, i in enumerate([0, 6, 12, 18, 24, 30] if args.sweep else range(6)):
                x, y = panel % 3 * 240, panel // 3 * 360
                draw.text((x + 4, y + 3), f'{key} {poses[i]}', fill='white')
                sheet.paste(Image.fromarray(frames[i].astype('uint8')).resize((240, 335)), (x, y + 22))
            sheet.save(output / f'{key.replace("#", "-")}.jpg', quality=95)
        except (OSError, ValueError, subprocess.SubprocessError) as error:
            row.update(renderStatus='error', error=str(error))
        return row

    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        results = list(pool.map(render, selected.items()))
    payload = dict(binary=binary, sha256=hashlib.sha256(Path(binary).read_bytes()).hexdigest(),
                   startedAt=started_at, completedAt=datetime.now(timezone.utc).isoformat(), resourceHashes=resource_hashes,
                   cards=len(results), frames=sum(r.get('frameCount', 0) for r in results),
                   failures=[r['key'] for r in results if r['renderStatus'] != 'pass'], results=results)
    (output / 'results.json').write_text(json.dumps(payload, ensure_ascii=False, indent=2))
    make_overviews(output, results)
    print(json.dumps({k: v for k, v in payload.items() if k != 'results'}, indent=2))
    if payload['failures']:
        raise SystemExit(1)


if __name__ == '__main__':
    main()
