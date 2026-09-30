#!/usr/bin/env python3
"""Compare full native audits without treating numeric flags as visual approval."""
import argparse
from collections import Counter
import json
from pathlib import Path

from audit_artwork_balance import combine


def compare(before, after):
    if set(before) != set(after):
        raise ValueError('Baseline and candidate must cover exactly the same printings')
    introduced_weak = []
    changed = []
    protected_failures = []
    for key, current in after.items():
        previous = before[key]
        if current['status'] == 'review' and previous['status'] != 'review':
            introduced_weak.append(key)
        old_edge = min(p['edgeRetention'] for p in previous['artwork']['poses'])
        new_edge = min(p['edgeRetention'] for p in current['artwork']['poses'])
        changed.append(dict(key=key, edgeBefore=old_edge, edgeAfter=new_edge,
                            smallBefore=previous['small'], smallAfter=current['small'],
                            flagsBefore=previous['artwork']['flags'], flagsAfter=current['artwork']['flags']))
        if current['material'] == 'megaGold':
            if new_edge < 0.83 or new_edge - old_edge < 0.12 or current['status'] != 'signal-pass':
                protected_failures.append(key)
        if current['material'] in {'black', 'white'}:
            if abs(current['small'] - previous['small']) > 0.1 or new_edge < old_edge - 0.01:
                protected_failures.append(key)
        if current['status'] == 'nonfoil-control' and current['artwork']['flags']:
            protected_failures.append(key)
    return dict(printings=len(after),
                flaggedBefore=sum(bool(r['artwork']['flags']) for r in before.values()),
                flaggedAfter=sum(bool(r['artwork']['flags']) for r in after.values()),
                flagsBefore=dict(Counter(f for r in before.values() for f in r['artwork']['flags'])),
                flagsAfter=dict(Counter(f for r in after.values() for f in r['artwork']['flags'])),
                newLowSignalKeys=sorted(introduced_weak),
                protectedFailures=sorted(set(protected_failures)), rows=changed)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--before', type=Path, required=True)
    parser.add_argument('--after', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--recheck', type=Path, action='append', default=[])
    parser.add_argument('--merged-output', type=Path)
    args = parser.parse_args()
    def read(directory):
        expected = json.loads((directory / 'expected-keys.json').read_text())
        return combine(sorted(directory.glob('shard-*.jsonl')), expected)
    before, after = read(args.before), read(args.after)
    rechecked = set()
    for directory in args.recheck:
        replacement = read(directory)
        if set(replacement) - set(after):
            raise ValueError('Recheck introduced an unknown printing')
        for row in replacement.values():
            row['recheckProvenance'] = str(directory)
        after.update(replacement)
        rechecked.update(replacement)
    if args.recheck:
        cosmos = {k for k, r in before.items() if r['material'] in {'sheet-cosmos', 'sheet-goldStar'}}
        if not cosmos <= rechecked:
            raise ValueError('Source-bound Cosmos change requires every affected printing rechecked')
    result = compare(before, after)
    result['recheckedPrintings'] = len(rechecked)
    if args.merged_output:
        args.merged_output.write_text(''.join(json.dumps(after[k]) + '\n' for k in sorted(after)))
    args.output.write_text(json.dumps(result, indent=2))
    print(json.dumps({k: v for k, v in result.items() if k != 'rows'}, indent=2))
    if result['protectedFailures']:
        raise SystemExit('Protected MUR/BWR/nonfoil regression')


if __name__ == '__main__':
    main()
