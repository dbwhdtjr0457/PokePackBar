#!/usr/bin/env python3
"""Generate source-bound, conservative Cosmos tuning from a complete native audit.

This is a visual balance profile, not a physical coating/emboss certification.
Require ample motion headroom in every Cosmos printing sharing the image.
"""
import argparse
import json
from pathlib import Path

from audit_artwork_balance import ROOT, combine

# This scan produced different Vision background masks across cold runs.
# Keep its original response instead of selecting only the favourable render.
UNSTABLE_BACKGROUND_IDS = {'base5-12'}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--audit', type=Path, required=True)
    parser.add_argument('--recheck-keys', type=Path)
    args = parser.parse_args()
    expected = json.loads((args.audit / 'expected-keys.json').read_text())
    rows = combine(sorted(args.audit.glob('shard-*.jsonl')), expected)
    if args.recheck_keys:
        keys = sorted(k for k, r in rows.items() if r['material'] in {'sheet-cosmos', 'sheet-goldStar'})
        args.recheck_keys.write_text(json.dumps(keys))
    originals = json.loads((ROOT / 'Sources/PokePackBar/Resources/card-art.json').read_text())['images']
    grouped = {}
    for row in rows.values():
        if row['material'] in {'sheet-cosmos', 'sheet-goldStar'}:
            grouped.setdefault(row['key'].split('#')[0], []).append(row)
    cards = {}
    for card_id, group in sorted(grouped.items()):
        if card_id in UNSTABLE_BACKGROUND_IDS:
            continue
        if not all(r['small'] >= 8 and r['large'] >= 16 for r in group):
            continue
        if not any('source-contrast-loss' in r['artwork']['flags'] for r in group):
            continue
        cards[card_id] = dict(sha256=originals[card_id]['sha256'], coatingGain=0.32,
                              dormantFleckOpacity=0.22)
    result = dict(version=1, baseline='2026-09-30-unlit-artwork-audit', cards=cards)
    target = ROOT / 'Sources/PokePackBar/Resources/foil-artwork-balance.json'
    target.write_text(json.dumps(result, indent=2) + '\n')
    print(f'Generated source-bound balance for {len(cards)} images')


if __name__ == '__main__':
    main()
