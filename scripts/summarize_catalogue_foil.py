#!/usr/bin/env python3
"""Combine complete native audit shards and later rechecks without hiding misses.

Input order is chronological: a later per-printing check replaces an earlier
one, with provenance retained. Signal pass is not individual visual approval.
"""
import argparse
import collections
import hashlib
import json
import os
from pathlib import Path
import subprocess


def combine(paths):
    rows = {}
    for path in paths:
        seen = set()
        for line in path.read_text().splitlines():
            row = json.loads(line)
            key = row['key']
            if key in seen:
                raise ValueError(f'duplicate key in {path}: {key}')
            seen.add(key)
            row['auditFile'] = path.name
            rows[key] = row
    return rows


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--binary', type=Path, required=True)
    parser.add_argument('--results', nargs='+', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--rerender-materials', nargs='*', default=[])
    args = parser.parse_args()
    rows = combine(args.results)
    expected = json.loads(subprocess.check_output(
        [str(args.binary.resolve()), '--export-foil-map', '--all-cards'],
        env=dict(os.environ, PPB_OFFLINE='1')))
    missing = sorted(set(expected) - set(rows))
    extra = sorted(set(rows) - set(expected))
    bad = [row for row in rows.values() if row['status'] not in ['signal-pass', 'sparse-signal-pass']]
    summary = dict(eligiblePrintings=len(expected), eligibleCards=len({r['cardID'] for r in expected.values()}),
        auditedPrintings=len(rows), missing=missing, extra=extra,
        statuses=dict(collections.Counter(r['status'] for r in rows.values())),
        candidatesByMaterial=dict(collections.Counter(r['material'] for r in bad)),
        catalogueBinary=str(args.binary.resolve()),
        catalogueBinarySHA256=hashlib.sha256(args.binary.read_bytes()).hexdigest(),
        inputs=[dict(path=str(p.resolve()), sha256=hashlib.sha256(p.read_bytes()).hexdigest()) for p in args.results],
        scope='native 240pt; ten angles; actual coverage; sparse motifs measured separately',
        visualApproval='selected samples only; not every frame', physicalAccuracy='not_certified')
    args.output.mkdir(parents=True, exist_ok=True)
    (args.output / 'summary.json').write_text(json.dumps(summary, indent=2))
    (args.output / 'printing-results.jsonl').write_text(''.join(json.dumps(rows[k]) + '\n' for k in sorted(rows)))
    (args.output / 'review-candidates.json').write_text(json.dumps(sorted(bad, key=lambda r:r['small']), indent=2))
    rerender = sorted(key for key, row in rows.items()
                      if row['status'] not in ['signal-pass', 'sparse-signal-pass']
                      or row['material'] in args.rerender_materials)
    (args.output / 'recheck-keys.json').write_text(json.dumps(rerender))
    print(json.dumps({k:v for k,v in summary.items() if k not in ['missing','extra','inputs']}, indent=2))
    if missing or extra:
        raise SystemExit(f'incomplete catalogue coverage: {len(missing)} missing, {len(extra)} unexpected')
    errors = summary['statuses'].get('error', 0)
    if errors:
        raise SystemExit(f'{errors} native render errors; see review-candidates.json')


if __name__ == '__main__':
    main()
