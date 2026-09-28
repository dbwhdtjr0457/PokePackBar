#!/usr/bin/env python3
"""Read the production renderer at normal UI size; rendering != visibility.

Small pointer movements are ±0.28, not just the edge-of-card ±0.88 poses.
Thresholds reject nearly inert renders, not certify human/physical fidelity.
Every release still needs native contact-sheet review for material character.
"""
import argparse
import concurrent.futures
import hashlib
import json
import os
import subprocess
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
POSES = ['rest', 'near-left', 'near-right', 'near-up', 'near-down',
         'left', 'right', 'up', 'down', 'diagonal']
FIXTURES = [
    ('g1-RC29', 'radiantCollection', 'art'), ('g1-RC30', 'radiantCollection', 'interior'),
    ('swsh4-102', 'amazingRare', 'art'), ('me2pt5-265', 'megaAttack', 'interior'),
    ('cel30-102', 'fullArt', 'interior'), ('col1-SL1', 'holo', 'art'),
    ('sma-SV1', 'shiny', 'art'), ('bw1-19', 'holo', 'art'),
    ('hgss1-ONE', 'holo', 'interior'), ('cel30-147', 'etched', 'interior'),
    ('me1-155', 'etched', 'interior'), ('me1-187', 'gold', 'interior'),
    ('hgss1-111', 'holo', 'interior'), ('ex10-46', 'reverseHolo', 'art'),
    ('bw11-RC1', 'radiantCollection', 'interior'), ('ex11-1', 'holo', 'subject'),
    ('hgss1-105', 'holo', 'art'), ('ex7-1', 'reverseHolo', 'art'),
    ('sm1-113', 'reverseHolo', 'outsideArt'), ('rsv10pt5-1', 'pokeBall', 'outsideArt'),
    ('xy10-14', 'breakFoil', 'interior'), ('me2pt5-1', 'reverseHolo', 'outsideArt'),
    ('me2pt5-1', 'patternedReverse', 'outsideArt'), ('ex1-100', 'holo', 'art'),
    ('sm35-27', 'shiny', 'art'), ('neo4-106', 'shiny', 'art'),
]


def response(frames, indices, region):
    changes = [np.abs(frames[i] - frames[0]).mean(axis=2) for i in indices]
    peak = np.max(changes, axis=0)[region]
    return dict(meanDelta255=float(peak.mean()), fractionAbove8=float(np.mean(peak > 8)))


def measure(frames, region):
    return dict(small=response(frames, range(1, 5), region),
                large=response(frames, range(5, 10), region))


def visible(metrics):
    # A deliberately lenient low-signal guard. Artistic acceptance is separate.
    return (metrics['small']['meanDelta255'] >= 2.5
            and metrics['large']['meanDelta255'] >= 5.0
            and metrics['large']['fractionAbove8'] >= 0.10)


def subject_region(entry, width=240, height=335):
    """Same even-odd registered source contours as the native subject mask."""
    image_height = width * entry['height'] / entry['width']
    top = (height - image_height) / 2
    region = np.zeros((height, width), dtype=bool)
    for contour in entry['subject']:
        layer = Image.new('1', (width, height))
        ImageDraw.Draw(layer).polygon([(x * width, top + y * image_height) for x, y in contour], fill=1)
        region ^= np.asarray(layer, dtype=bool)
    return region


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--binary', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--art-dir', type=Path)
    parser.add_argument('--baseline-binary', type=Path, help='Compare the same six large-angle poses to an older app')
    parser.add_argument('--keys', nargs='*')
    parser.add_argument('--enforce', action='store_true')
    parser.add_argument('--classify-only', action='store_true')
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    env = dict(os.environ, PPB_OFFLINE='1')
    env.pop('PPB_CARD_ART_DIR', None)
    if args.art_dir:
        env['PPB_CARD_ART_DIR'] = str(args.art_dir.resolve())
    geometry = json.loads((ROOT / 'Sources/PokePackBar/Resources/foil-geometry.json').read_text())['cards']
    subjects = json.loads((ROOT / 'Sources/PokePackBar/Resources/foil-subject-masks.json').read_text())['cards']
    fixtures = [f for f in FIXTURES if not args.keys or f'{f[0]}#{f[1]}' in args.keys]
    if args.keys and set(args.keys) != {f'{f[0]}#{f[1]}' for f in fixtures}:
        raise SystemExit('Unknown visibility fixture key')

    def render(fixture):
        card_id, finish, area = fixture
        key = f'{card_id}-{finish}'
        folder = output / 'images' / key
        if not args.classify_only:
            subprocess.run([str(args.binary.resolve()), '--render-holo-preview', card_id, str(folder),
                            finish, '--actual-size', '--flat-card', '--visibility'],
                           env=env, capture_output=True, check=True, timeout=120)
        frames = [np.asarray(Image.open(folder / f'{key}-{pose}.png').convert('RGB')
                             .crop((120, 120, 600, 790)).resize((240, 335)), dtype=float) for pose in POSES]
        region = np.zeros((335, 240), dtype=bool)
        region[12:-12, 12:-12] = True
        geom = geometry[card_id]
        if area != 'interior' and geom.get('art') and geom['width'] < geom['height']:
            x1, y1, x2, y2 = geom['art']
            height = 240 * geom['height'] / geom['width']
            top = (335 - height) / 2
            art = np.zeros_like(region)
            art[max(0, round(top+y1*height)):min(335, round(top+y2*height)),
                max(0, round(x1*240)):min(240, round(x2*240))] = True
            region &= art if area in ['art', 'subject'] else ~art
        if area == 'subject':
            region &= subject_region(subjects[card_id])
        metrics = measure(frames, region)
        baseline = None
        if args.baseline_binary:
            baseline_folder = output / 'baseline-images' / key
            if not args.classify_only:
                subprocess.run([str(args.baseline_binary.resolve()), '--render-holo-preview', card_id,
                                str(baseline_folder), finish, '--actual-size', '--flat-card'],
                               env=env, capture_output=True, check=True, timeout=120)
            baseline_frames = [np.asarray(Image.open(baseline_folder / f'{key}-{pose}.png').convert('RGB')
                                .crop((120, 120, 600, 790)).resize((240, 335)), dtype=float)
                               for pose in [POSES[0], *POSES[5:]]]
            baseline = response(baseline_frames, range(1, 6), region)
        # Mutate real pixels, then traverse the same measurement path. A
        # successful render with frozen/over-attenuated light must be rejected.
        frozen = measure([frames[0]] * len(frames), region)
        attenuated = measure([frames[0] + (frame - frames[0]) * 0.01 for frame in frames], region)
        assert not visible(frozen), 'Frozen native frames passed'
        assert not visible(attenuated), 'Over-attenuated native frames passed'
        sheet = Image.new('RGB', (1200, 720), '#121218')
        draw = ImageDraw.Draw(sheet)
        for i, frame in enumerate(frames):
            x, y = i % 5 * 240, i // 5 * 360
            draw.text((x+3, y+3), f'{card_id} {POSES[i]}', fill='white')
            sheet.paste(Image.fromarray(frame.astype('uint8')), (x, y+22))
        sheet.save(output / f'{key}.jpg', quality=95)
        return dict(key=f'{card_id}#{finish}', region=area, metrics=metrics,
                    baselineLarge=baseline,
                    renderStatus='pass', signalStatus='pass' if visible(metrics) else 'review',
                    rejectedMutations=['frozen_native_frames', 'one_percent_native_response'],
                    visualStatus='requires_human_review')

    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        results = list(pool.map(render, fixtures))
    result = dict(binary=str(args.binary.resolve()), sha256=hashlib.sha256(args.binary.read_bytes()).hexdigest(),
                  baselineBinary=str(args.baseline_binary.resolve()) if args.baseline_binary else None,
                  baselineSHA256=hashlib.sha256(args.baseline_binary.read_bytes()).hexdigest() if args.baseline_binary else None,
                  frames=len(results)*len(POSES), results=results,
                  weakCandidates=[r['key'] for r in results if r['signalStatus'] != 'pass'],
                  nativePixelMutationsRejected=True, physicalAccuracy='not_certified')
    (output / 'results.json').write_text(json.dumps(result, ensure_ascii=False, indent=2))
    for row in results:
        print(row['key'], row['signalStatus'], json.dumps(row['metrics']))
    if args.enforce and result['weakCandidates']:
        raise SystemExit(1)


if __name__ == '__main__':
    main()
