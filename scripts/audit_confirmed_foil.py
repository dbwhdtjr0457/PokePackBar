#!/usr/bin/env python3
"""Render every printing in a confirmed-finding manifest, without opening a save.

Render success and pixel changes do not certify visual/physical accuracy. Keep
per-card results separate from the human review and unresolved reference gaps.
"""
import argparse
import concurrent.futures
import json
import os
import subprocess
import time
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--binary', type=Path, required=True)
    parser.add_argument('--findings', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--workers', type=int, default=6)
    args = parser.parse_args()
    binary = str(args.binary.resolve())
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    env = dict(os.environ, PPB_OFFLINE='1', PPB_CARD_ART_DIR=str(ROOT / 'local-assets/CardArt'))
    findings = json.loads(args.findings.read_text())
    keys = sorted({key for finding, cards in findings.items() if finding.startswith('F') for key in cards})
    foil_map = json.loads(subprocess.check_output([binary, '--export-foil-map', '--all-cards'], env=env))
    missing = set(keys) - foil_map.keys()
    if missing:
        raise RuntimeError(f'Confirmed printings missing from renderer: {sorted(missing)}')

    def render(key):
        value = foil_map[key]
        row = dict(value, key=key, physicalAccuracy='not_certified_by_render_test')
        folder = output / 'images' / key.replace('#', '-')
        try:
            subprocess.run([binary, '--render-holo-preview', value['cardID'], str(folder),
                value['finish'], '--compact', '--actual-size', '--flat-card'],
                env=env, capture_output=True, check=True, timeout=90)
            stem = f"{value['cardID']}-{value['finish']}"
            panels = []
            for pose in ['rest', 'diagonal']:
                with Image.open(folder / f'{stem}-{pose}.png') as image:
                    panels.append(np.asarray(image.convert('RGB').crop((120, 120, 600, 790)), dtype=float))
            delta = np.abs(panels[0] - panels[1])
            row.update(renderStatus='pass', meanAngleDelta255=round(float(delta.mean()), 5),
                       changedPixelFraction=round(float((delta.max(axis=2) > 8).mean()), 5))
        except (subprocess.SubprocessError, OSError, ValueError) as error:
            row.update(renderStatus='error', error=str(error))
        return row

    started = time.monotonic()
    results = []
    with (output / 'results.jsonl').open('w') as log:
        with concurrent.futures.ThreadPoolExecutor(max_workers=args.workers) as pool:
            futures = [pool.submit(render, key) for key in keys]
            for future in concurrent.futures.as_completed(futures):
                row = future.result()
                results.append(row)
                log.write(json.dumps(row, ensure_ascii=False) + '\n')
                log.flush()
                if len(results) % 100 == 0 or len(results) == len(keys):
                    print(f'Rendered {len(results)}/{len(keys)}', flush=True)
    summary = dict(printings=len(keys), anglesPerPrinting=2,
        failures=[row['key'] for row in results if row['renderStatus'] != 'pass'],
        elapsedSeconds=round(time.monotonic() - started),
        physicalAccuracy='not_certified_by_render_test')
    (output / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
    print(json.dumps(summary, indent=2))
    if summary['failures']:
        raise SystemExit(1)


if __name__ == '__main__':
    main()
