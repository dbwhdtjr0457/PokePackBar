#!/usr/bin/env python3
"""Build source-bound new-expansion treatments; never infer a parallel by name color.

The regular image determines registration, NOT the factory emboss plate. Physical
treatment evidence and optical approximations are recorded separately in docs.
"""
import argparse
import datetime
import hashlib
import json
import re
from collections import Counter
from pathlib import Path

import cv2
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
RES = ROOT / "Sources/PokePackBar/Resources"
OUTPUT = RES / "expansion-foil.json"
SETS = {"me2pt5", "me3", "me4", "me5", "cel30", "cel30c"}
PATTERNS = {"Poke Ball": "pokeBall", "Friend Ball": "friendBall", "Love Ball": "loveBall",
            "Quick Ball": "quickBall", "Dusk Ball": "duskBall", "Team Rocket": "teamRocket"}


def gold_frame(entry):
    image = Image.open(ROOT / "local-assets/CardArt" / entry["file"]).convert("RGB")
    if image.width > image.height:
        image = image.transpose(Image.Transpose.ROTATE_90)
    rgb = np.array(image)
    h, w = rgb.shape[:2]
    r, g, b = [rgb[:, :, i].astype(float) for i in range(3)]
    y, x = np.mgrid[:h, :w]
    # Source ink segmentation only in the outer frame. Do not turn a golden
    # Pokémon, attack box, anniversary logo, or white tab into a gold border.
    edge = (x < w * .062) | (x > w * .938) | (y < h * .045) | (y > h * .955)
    if Path(entry['file']).stem == 'cel30c-29':
        # Aquapolis e-reader stock has a wide left/bottom gold margin. The
        # ordinary 6.2% band clipped half of this card's photographed border.
        edge = (x < w * .132) | (x > w * .952) | (y < h * .035) | (y > h * .926)
    # Pale yellow text panels are not the saturated gold perimeter (notably
    # Classic Pikachu). Chroma prevents the outer search band leaking inward.
    gold = ((r > 105) & (r > g * .96) & (g > b * 1.13) & (r - b > r * .35) & edge).astype('uint8') * 255
    gold = cv2.morphologyEx(gold, cv2.MORPH_CLOSE, np.ones((3, 3), np.uint8))
    if Path(entry['file']).stem == 'cel30c-29':
        from build_reviewed_foil import anniversary_stamp, raster
        gold[raster(anniversary_stamp(rgb, (.13,.48)), (h,w)) > 0] = 0
    contours, _ = cv2.findContours(gold, cv2.RETR_TREE, cv2.CHAIN_APPROX_SIMPLE)
    polygons = []
    for contour in contours:
        if abs(cv2.contourArea(contour)) < 12:
            continue
        simple = cv2.approxPolyDP(contour, .55, True).reshape(-1, 2)
        polygons.append([[round(float(px) / w, 6), round(float(py) / h, 6)] for px, py in simple])
    fraction = float(np.count_nonzero(gold)) / (w * h)
    maximum = .28 if Path(entry['file']).stem == 'cel30c-29' else .23
    assert .012 < fraction < maximum, (entry["file"], fraction)
    return polygons, round(fraction, 5)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--products", type=Path, help="TCGCSV 24541/products response")
    parser.add_argument("--prices", type=Path, help="TCGCSV 24541/prices response")
    parser.add_argument("--verify", action="store_true")
    parser.add_argument("--refresh-frames", action="store_true", help="Rebuild only registered gold geometry, preserving catalogue/prices")
    parser.add_argument("--import-prices", action="store_true", help="Also merge exact parallel prices, with dates and product URLs")
    parser.add_argument("--as-of", default=datetime.date.today().isoformat(), help="Date the supplied public responses were captured")
    args = parser.parse_args()
    index = json.loads((RES / "card-index.json").read_text())
    art = json.loads((RES / "card-art.json").read_text())["images"]
    cards = {row[0]: row for row in index["cards"] if row[0].split('-')[0] in SETS}
    assert len(cards) == 852
    if args.refresh_frames:
        data = json.loads(OUTPUT.read_text())
        for cid, entry in data['cards'].items():
            if cid.startswith('cel30c-'):
                entry['goldFrame'], entry['goldArea'] = gold_frame(art[cid])
        OUTPUT.write_text(json.dumps(data,ensure_ascii=False,separators=(',',':'))+'\n')
        print('Refreshed 30 gold frames; prices and catalogue preserved')
        return
    if args.verify:
        data = json.loads(OUTPUT.read_text())
        assert set(data["cards"]) == set(cards)
        for cid, entry in data["cards"].items():
            assert entry["sha256"] == art[cid]["sha256"], cid
            assert entry["width"] == min(art[cid]["width"], art[cid]["height"]), cid
            assert entry["height"] == max(art[cid]["width"], art[cid]["height"]), cid
            for contour in entry.get("goldFrame", []):
                assert len(contour) >= 3
                assert all(len(p) == 2 and all(0 <= v <= 1 for v in p) for p in contour), cid
            if cid.startswith('cel30c-'):
                assert entry['goldFrame'] == gold_frame(art[cid])[0], ('Stale gold frame',cid)
        assert sum(bool(e.get("goldFrame")) for e in data["cards"].values()) == 30
        parallels = data["ascendedParallels"]
        assert len(parallels) == 140
        assert set(e["pattern"] for e in parallels.values()) == set(PATTERNS.values())
        assert all(cards[cid][4].startswith('p') and cards[cid][2] in ('C', 'U', 'R') for cid in parallels)
        print("PASS expansion foil: 852 source hashes/dimensions; 30 gold frames; 140 exact parallel pairs / 6 motifs")
        return
    assert args.products and args.prices, "Supply captured product and price JSON, or --verify"
    products = json.loads(args.products.read_text())["results"]
    prices = {}
    for price in json.loads(args.prices.read_text())["results"]:
        if price["subTypeName"] != "Reverse Holofoil" or not price["marketPrice"]:
            continue
        assert price["productId"] not in prices, "Ambiguous printing price"
        assert np.isfinite(price["marketPrice"]) and price["marketPrice"] > 0
        prices[price["productId"]] = price
    parallels = {}
    energy = {}
    for product in products:
        match = re.search(r"\((Energy Symbol Pattern|" + '|'.join(PATTERNS) + r")\)$", product["name"])
        if not match:
            continue
        meta = {d["name"]: d["value"] for d in product["extendedData"]}
        cid = "me2pt5-" + str(int(meta["Number"].split('/')[0]))
        assert cid in cards and cards[cid][4].startswith('p'), cid
        record = {"productID": product["productId"], "url": product["url"]}
        price = prices.get(product["productId"], {}).get("marketPrice")
        if price:
            record["marketUSD"] = price
        if match[1] == "Energy Symbol Pattern":
            assert cid not in energy
            energy[cid] = record
        else:
            assert cid not in parallels
            parallels[cid] = {**record, "pattern": PATTERNS[match[1]]}
    assert len(parallels) == 140 and set(parallels) == set(energy)
    for cid in parallels:
        parallels[cid]["energy"] = energy[cid]
    entries = {}
    for cid, row in cards.items():
        original = art[cid]
        rarity = index["rarities"][row[3]]
        entry = {"sha256": original["sha256"], "width": min(original["width"], original["height"]),
                 "height": max(original["width"], original["height"]), "rarity": rarity}
        if cid.startswith("cel30c-"):
            entry["treatment"] = "classic30"
            entry["goldFrame"], entry["goldArea"] = gold_frame(original)
        elif rarity == "Pikachu Rare":
            entry["treatment"] = "pikachu30"
        elif rarity == "Futuristic Rare":
            entry["treatment"] = "futuristic30"
        elif rarity in {"RBG Rare", "RGB Rare"}:
            entry["treatment"] = "rgb30"
        elif rarity == "Double Rare" and row[1].startswith("Mega "):
            entry["treatment"] = "megaDoubleRare"
        else:
            entry["treatment"] = "existing-era-material"
        entries[cid] = entry
    datetime.date.fromisoformat(args.as_of)
    data = {"version": 1, "asOf": args.as_of, "cards": entries, "ascendedParallels": parallels,
            "sources": ["https://www.30th.pokemon-card.com/product/m6a?slide=modal",
                        "https://www.pokemon-card.com/ex/m2a/", "https://tcgcsv.com/tcgplayer/3/24541/products",
                        "https://tcgcsv.com/tcgplayer/3/24541/prices"],
            "productsSHA256": hashlib.sha256(args.products.read_bytes()).hexdigest(),
            "pricesSHA256": hashlib.sha256(args.prices.read_bytes()).hexdigest()}
    OUTPUT.write_text(json.dumps(data, ensure_ascii=False, separators=(',', ':'), sort_keys=True) + '\n')
    if args.import_prices:
        path = RES / "card-prices.json"
        payload = json.loads(path.read_text())
        imported = 0
        for cid, parallel in parallels.items():
            for finish, product in [("patternedReverse", parallel), ("reverseHolo", parallel["energy"])]:
                if not product.get("marketUSD"):
                    continue
                key = cid + '#' + finish
                payload.setdefault("printingPrices", {})[key] = product["marketUSD"]
                payload.setdefault("printingDates", {})[key] = data["asOf"]
                payload.setdefault("printingSources", {})[key] = product["url"]
                imported += 1
        payload["printingPriceSnapshot"]["asOf"] = max(payload["printingDates"].values())
        payload["printingPriceSnapshot"]["sets"]["me2pt5-parallels"] = {"imported": imported, "ambiguousSkipped": 0}
        path.write_text(json.dumps(payload, ensure_ascii=False, separators=(',', ':'), sort_keys=True) + '\n')
        print(f"Merged {imported} exact printing prices; unrelated prices retained")
    print(Counter(e['treatment'] for e in entries.values()))
    print(Counter(e['pattern'] for e in parallels.values()))


if __name__ == "__main__":
    main()
