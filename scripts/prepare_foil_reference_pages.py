"""Temporary linked-photo sheets. No remote image bytes are stored locally."""
import argparse
import json
from html import escape
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument('observations', type=Path)
parser.add_argument('output', type=Path)
args = parser.parse_args()
args.output.mkdir(parents=True, exist_ok=True)
rows = sorted((r for r in json.loads(args.observations.read_text())
               if r['cardID'].startswith('cel30-')), key=lambda r: int(r['cardID'].split('-')[1]))
for start in range(0, len(rows), 3):
    body = '<!doctype html><meta charset="utf-8"><title>Foil evidence</title><style>body{display:flex;gap:8px;background:#181818;color:white;margin:8px;font:16px sans-serif}article{width:590px}img{width:590px;height:745px;object-fit:contain}h2{margin:4px}</style>'
    for row in rows[start:start+3]:
        body += '<article><h2>' + escape(row['cardID']) + '</h2><img src="' + escape(row['photos'][0], quote=True) + '"></article>'
    (args.output / f'photo-{start//3:02d}.html').write_text(body)
print(f'{len(rows)} photo references; no review status assigned')
