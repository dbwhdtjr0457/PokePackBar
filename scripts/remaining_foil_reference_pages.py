"""Reproducible linked reference sheets; creating a sheet never marks it reviewed."""
import argparse
import json
import re
import urllib.request
from html import escape
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LEX = {
    66: ('vikavolt', ['21865ef31a3040a8849e0720b12a3ab9','05d9178396f94a028879f08ab6a5f1b6','41d4d0a0e8334acfbf6f3fe03c0ab293']),
    69: ('iono-s-tadbulb', ['73729a6b137a426ab543e4925998c840','f340dc1f18ca4e3bb8c32ceb774b5b42','a910f112cba84179bbb2113a73710f6e']),
    71: ('iono-s-wattrel', ['09fe8fea33c040e1a870857c8edc14ef','241c151a5dc04f1496833e662d51f60b','c1f0c6f930094502a1db9081ffbb8afa']),
    72: ('iono-s-kilowattrel', ['9306c79ab8cd4a91827d1ce434884798','008b25bd2993476792e8b13ea1d3f871','77af5806d83b449cb32d42a3fef42bf0']),
}
CLASSIC_ORDER = [14,1,5,15,7,24,29,2,6,25,3,22,10,11,18,19,20,21,16,4,23,9,17,13,8,28,12,26,27,30]
OFFICIAL = 'https://www.30th.pokemon-card.com/product/m6a'


def page(output, name, images):
    body = '<!doctype html><meta charset="utf-8"><title>Physical foil reference comparison</title><style>body{display:flex;gap:8px;background:#181818;color:white;margin:8px;font:14px sans-serif}article{flex:1;min-width:0}img{width:100%;height:760px;object-fit:contain}h2{font-size:16px;margin:4px}</style>'
    for title, url in images:
        body += f'<article><h2>{escape(title)}</h2><img src="{escape(url,quote=True)}"></article>'
    (output / f'{name}.html').write_text(body)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    output = args.output
    output.mkdir(parents=True, exist_ok=True)
    artlink = output / 'originals'
    if not artlink.exists():
        artlink.symlink_to(ROOT / 'local-assets/CardArt', target_is_directory=True)
    records = {}
    for n, (slug, hashes) in LEX.items():
        urls = [f'https://static.wixstatic.com/media/c01fda_{h}~mv2.jpg' for h in hashes]
        records[f'me2pt5-{n}'] = dict(page=f'https://www.lexcollects.co.uk/product-page/ascended-heroes-{slug}-{n:03d}-217', photos=urls)
        page(output, f'ascended-{n}', [(f'{n} specimen {i}', url) for i,url in enumerate(urls)])
    raw = urllib.request.urlopen(OFFICIAL, timeout=30).read().decode()
    urls = dict(re.findall(r'(/images/m6a/cards/m6a_(\d+)_[a-z0-9]+\.png)', raw))
    by_number = {int(n): 'https://www.30th.pokemon-card.com'+url for url,n in urls.items()}
    for i, n in enumerate(CLASSIC_ORDER, 136):
        url = by_number[151152 if i in [151,152] else i]
        records[f'cel30c-{n}'] = dict(page=OFFICIAL, photos=[url], referenceLanguage='Japanese', staticReferenceOnly=True)
    for start in range(1,31,2):
        images = []
        for n in [start,start+1]:
            cid = f'cel30c-{n}'
            images += [(cid+' official JP',records[cid]['photos'][0]), (cid+' installed EN','originals/'+cid+'.jpg')]
        page(output, f'classic-{start:02d}', images)
    recipes = json.loads((ROOT/'scripts/reviewed-foil-recipes.json').read_text())
    for n in [26,29,35,36,40,43,49,50,51]:
        cid = f'cel30-{n}'
        refs = recipes[cid]['referenceURLs']
        records[cid] = dict(page=refs[0], photos=refs[1:], referenceLanguage='Japanese', staticReferenceOnly=True)
        page(output, f'pikachu-{n}', [(cid+' specimen', refs[1]), (cid+' installed EN','originals/'+cid+'.jpg')])
    page(output, 'star-sheet', [('Owner photograph: star sheet','https://efour.b-cdn.net/uploads/default/original/3X/1/e/1ef4b8e18445cb8f67f9a636aa07815320e0b9ff.jpeg')])
    page(output, 'miraidon-stars', [(str(i),url) for i,url in enumerate([
        'https://i.ebayimg.com/images/g/M7gAAOSw~hFkKvGf/s-l1200.jpg',
        'https://i.ebayimg.com/images/g/S~4AAOSwu7tmwYhG/s-l1200.jpg',
        'https://i.ebayimg.com/images/g/TGQAAOSwZAFm~Zh0/s-l1200.jpg'])])
    for n, name in {26:'020_mgb734dr',36:'030_mt8ktxb9',40:'034_yuxf6flm',49:'043_u68bbz2j',50:'044_x4um6kfj'}.items():
        page(output, f'pikachu-reveal-{n}', [
            (f'JP {n-6} manufacturer reveal',f'https://www.30th.pokemon-card.com/images/m6a/cards/m6a_{name}.png'),
            (f'EN {n} installed',f'originals/cel30-{n}.jpg')])
    for n in [29,35,43,51]:
        page(output, f'pikachu-reveal-{n}', [
            (f'JP {n-6} archived scan',f'https://billsarchive.com/assets/30th-pikachu/p{n-6:03d}.webp'),
            (f'EN {n} installed',f'originals/cel30-{n}.jpg')])
    (output/'references.json').write_text(json.dumps(records,ensure_ascii=False,indent=2))
    print(f'{len(records)} reference entries; no review approval inferred')


if __name__ == '__main__':
    main()
