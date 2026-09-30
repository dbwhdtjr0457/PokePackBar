#!/usr/bin/env python3
"""Catalogue-wide native scan/effect comparison. Never reads a wallet.

Numerical screening is not individual visual approval. Native contact sheets
are a separate explicit operation; no image editing is performed here.
"""
import argparse
from collections import Counter
from concurrent.futures import ThreadPoolExecutor
import csv
import hashlib
import json
import os
from pathlib import Path
import subprocess
import time

ROOT = Path(__file__).resolve().parents[1]


def risk(pose):
    return (max(0, 1 - pose['edgeRetention']) + pose['weakenedEdgeFraction']
            + pose['brightVeilFraction'] + pose['darkVeilFraction']
            + pose['addedClippingFraction'])


def combine(paths, expected):
    rows = {}
    for path in paths:
        for line in path.read_text().splitlines():
            row = json.loads(line)
            if row['key'] in rows:
                raise ValueError(f"Duplicate printing: {row['key']}")
            rows[row['key']] = row
    missing, extra = sorted(set(expected) - rows.keys()), sorted(rows.keys() - set(expected))
    if missing or extra:
        raise ValueError(f'Incomplete coverage: {len(missing)} missing; {len(extra)} extra')
    if any(row['status'] == 'error' or not row.get('artwork') for row in rows.values()):
        raise ValueError('Native render errors or missing artwork measurements')
    return rows


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--binary', type=Path, required=True)
    parser.add_argument('--art-dir', type=Path)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--workers', type=int, default=4, choices=range(1, 5))
    parser.add_argument('--tier')
    parser.add_argument('--keys-file', type=Path)
    parser.add_argument('--cached-only', action='store_true')
    parser.add_argument('--contacts', type=Path)
    parser.add_argument('--summarize-only', action='store_true')
    args = parser.parse_args()
    binary, output = args.binary.resolve(), args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    env = dict(os.environ, PPB_OFFLINE='1')
    env.pop('PPB_CARD_ART_DIR', None)
    if args.art_dir:
        env['PPB_CARD_ART_DIR'] = str(args.art_dir.resolve())
    index = json.loads((ROOT / 'Sources/PokePackBar/Resources/card-index.json').read_text())
    cards = {c[0]: c for c in index['cards']}
    foil = json.loads(subprocess.check_output([str(binary), '--export-foil-map', '--all-cards'], env=env))
    defaults = json.loads(subprocess.check_output([str(binary), '--export-printing-map'], env=env))
    expected = set(foil) | {f'{card}#{finish}' for card, finish in defaults.items()}
    if args.cached_only:
        if args.art_dir:
            raise ValueError('--cached-only must use the actual runtime cache, not an original override')
        cache = Path.home() / 'Library/Application Support/PokePackBar/cards-v2'
        expected = {key for key in expected if (cache / (key.split('#')[0] + '_hires.webp')).is_file()}
    if args.tier:
        expected = {key for key in expected if cards[key.split('#')[0]][2] == args.tier}
    if args.keys_file:
        requested = set(json.loads(args.keys_file.read_text()))
        if requested - expected:
            raise ValueError('Unknown printing requested')
        expected &= requested
    if not expected:
        raise ValueError('Empty audit selection')
    paths = [output / f'shard-{i}.jsonl' for i in range(args.workers)]
    if not args.summarize_only:
        if any(p.exists() for p in paths):
            raise ValueError('Refusing to overwrite audit output')
        selection = output / 'expected-keys.json'
        selection.write_text(json.dumps(sorted(expected)))
        provenance = dict(binary=str(binary), binarySHA256=hashlib.sha256(binary.read_bytes()).hexdigest(),
                          originalLibrary=env.get('PPB_CARD_ART_DIR'), catalogueCards=len(cards),
                          expectedPrintings=len(expected), poses=10, startedAt=time.time(),
                          workers=args.workers, visualApproval='not implied by numerical screening')
        (output / 'provenance.json').write_text(json.dumps(provenance, indent=2))

        def run(shard):
            command = ['/usr/bin/nice', '-n', '10', str(binary), '--audit-catalogue-foil', str(paths[shard]),
                       '--art-balance', '--keys-file', str(selection), '--shards', str(args.workers), '--shard', str(shard)]
            if args.contacts:
                command += ['--contact-dir', str(args.contacts.resolve())]
            with (output / f'shard-{shard}.log').open('x') as log:
                subprocess.run(command, env=env, stdout=log, stderr=subprocess.STDOUT, check=True)
            print(f'Completed shard {shard}', flush=True)
        with ThreadPoolExecutor(max_workers=args.workers) as executor:
            list(executor.map(run, range(args.workers)))
    rows = combine(paths, expected)
    candidates = sorted((r for r in rows.values() if r['artwork']['flags']),
                        key=lambda r: max(risk(p) for p in r['artwork']['poses']), reverse=True)
    summary = dict(cards=len({k.split('#')[0] for k in rows}), printings=len(rows), frames=len(rows)*10,
                   foilPrintings=sum(k in foil for k in rows),
                   statuses=dict(Counter(r['status'] for r in rows.values())),
                   artworkFlagged=len(candidates),
                   flags=dict(Counter(f for r in rows.values() for f in r['artwork']['flags'])),
                   candidatesByMaterial=dict(Counter(r['material'] for r in candidates)),
                   lowFoilSignal=sum(r['status'] == 'review' for r in rows.values()),
                   errors=0, missing=[], extra=[],
                   visualApproval='numerical full coverage; contact-sheet inspection recorded separately')
    (output / 'summary.json').write_text(json.dumps(summary, indent=2))
    (output / 'candidates.json').write_text(json.dumps(candidates, indent=2))
    with (output / 'per-printing.csv').open('w') as file:
        writer = csv.writer(file)
        writer.writerow(['key', 'name', 'tier', 'material', 'status', 'coverage', 'flags', 'worst_pose', 'edge_retention',
                         'faint_correlation_min', 'veiled_fraction_max', 'small_holo', 'large_holo', 'microdetail'])
        for key, row in sorted(rows.items()):
            poses = row['artwork']['poses']
            worst = max(poses, key=risk)
            card = cards[key.split('#')[0]]
            writer.writerow([key, card[1], card[2], row['material'], row['status'], row['coverage'], '|'.join(row['artwork']['flags']),
                             worst['name'], min(p['edgeRetention'] for p in poses),
                             min(p['faintEdgeCorrelation'] for p in poses),
                             max(p['brightVeilFraction'] + p['darkVeilFraction'] for p in poses),
                             row['small'], row['large'], row['detail']])
    with (output / 'per-material.csv').open('w') as file:
        writer = csv.writer(file)
        writer.writerow(['material', 'printings', 'flagged', 'contrast_loss', 'faint_interference', 'low_signal'])
        for material in sorted({r['material'] for r in rows.values()}):
            group = [r for r in rows.values() if r['material'] == material]
            writer.writerow([material, len(group), sum(bool(r['artwork']['flags']) for r in group),
                             sum('source-contrast-loss' in r['artwork']['flags'] for r in group),
                             sum('faint-detail-interference' in r['artwork']['flags'] for r in group),
                             sum(r['status'] == 'review' for r in group)])
    print(json.dumps(summary, indent=2), flush=True)


if __name__ == '__main__':
    main()
