#!/usr/bin/env python3
"""Import released English expansions, retaining existing IDs and source evidence.

TCGdex supplies typed card metadata. TCGCSV independently supplies collector
numbers, printings, prices and image fallbacks (including the Classic subset).
No future sets, inferred rarity, placeholder art or image upscaling is allowed.
Run from the repository root. HTTP snapshots are resumable in local-assets/.
"""
from __future__ import annotations

import concurrent.futures as futures
import argparse
import datetime as dt
import hashlib
import json
import re
import subprocess
import time
import urllib.request
from collections import Counter
from pathlib import Path

from update_pack_prices import choose_booster

ROOT = Path(__file__).resolve().parents[1]
RES = ROOT / "Sources/PokePackBar/Resources"
CACHE = ROOT / "local-assets/source-json"
LATEST = {"me2pt5": ("me02.5", 24541), "me3": ("me03", 24587),
          "me4": ("me04", 24655), "me5": ("me05", 24688),
          "cel30": ("30th", 24722), "cel30c": ("30th-c", 24837)}
TIERS = {"Common": "C", "Uncommon": "U", "Rare": "R", "Double Rare": "RR",
         "Illustration Rare": "AR", "Ultra Rare": "SR", "Special Illustration Rare": "SAR",
         "Mega Hyper Rare": "MUR", "Mega Attack Rare": "MA", "Futuristic Rare": "FUR",
         "Pikachu Rare": "AR", "Classic Collection": "CHR", "RBG Rare": "FUR"}
TYPES = dict(zip(["Grass", "Fire", "Water", "Lightning", "Psychic", "Fighting",
                 "Darkness", "Metal", "Dragon", "Fairy", "Colorless"], "GRWLPFDMNYC"))
# Source checklist ordinals are not printed collector numbers. These named
# variants require an explicit product join, especially the two LEGEND halves.
CLASSIC_PRODUCTS = {"3": 716157, "4": 716158, "18": 716198,
                    "19": 716199, "20": 716200, "22": 716203}
# Exact collector-number joins for source spelling/energy-symbol differences.
PRODUCT_ALIASES = {"me4-84": 693458, "me4-86": 693527, "cel30-87": 716483}
# Actual printed "Tera" labels, verified with audit_card_labels.swift across
# all 75 RR/SR/SAR originals. Both API providers omit this rule-box property.
PRINTED_TERA_IDS = {"me2pt5-38", "me2pt5-57", "me2pt5-73", "me2pt5-121",
                    "me2pt5-160", "me2pt5-179", "me2pt5-277"}


def write_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(json.dumps(value, ensure_ascii=False, separators=(",", ":")) + "\n")
    temporary.replace(path)


def fetch(url):
    path = CACHE / (hashlib.sha256(url.encode()).hexdigest() + ".json")
    if path.exists():
        return json.loads(path.read_text())
    for attempt in range(4):
        try:
            request = urllib.request.Request(url, headers={"User-Agent": "PokePackBar-local-catalogue/0.11"})
            with urllib.request.urlopen(request, timeout=35) as response:
                value = json.load(response)
            write_json(path, value)
            return value
        except Exception:
            if attempt == 3:
                raise
            time.sleep(0.5 * (attempt + 1))


def number(value):
    return re.sub(r"(?<=\D)0+(?=\d)|^0+(?=\d)", "", value.split("/")[0]).upper()


def name(value):
    return re.sub(r"[^a-z0-9]", "", value.lower().replace("é", "e").replace("&", "and"))


def product_fields(product):
    return {field["name"]: field["value"] for field in product.get("extendedData", [])}


def product_card_name(product):
    label = re.sub(r"\s*-\s*[A-Za-z0-9]+/[A-Za-z0-9]+$", "", product["name"])
    return re.sub(r"\s*\[[^]]+\]", "", label)


def source_image(product):
    # TCGplayer's original-resolution endpoint, never an enlarged 200w thumbnail.
    return f"https://tcgplayer-cdn.tcgplayer.com/product/{product['productId']}_in_1000x1000.jpg"


def record_prices(prices, card_id, product, market, finishes, as_of):
    available = [v for v in market if v["productId"] == product["productId"] and v.get("marketPrice", 0)]
    ordinary = next((v for v in available if v["subTypeName"] in ("Normal", "Holofoil")), None)
    if ordinary:
        prices["prices"][card_id] = ordinary["marketPrice"]
        prices.setdefault("priceDates", {})[card_id] = as_of
    for row in available:
        finish = {"Normal": "normal", "Reverse Holofoil": "reverseHolo",
                  "Holofoil": finishes.get(card_id)}.get(row["subTypeName"])
        if not finish:
            continue
        key = card_id + "#" + finish
        prices.setdefault("printingPrices", {})[key] = row["marketPrice"]
        prices.setdefault("printingDates", {})[key] = as_of
        prices.setdefault("printingSources", {})[key] = product["url"]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--prices-from-binary", type=Path,
                        help="After rebuilding the catalogue, resolve new printing prices using this app binary")
    args = parser.parse_args()
    finishes = json.loads(subprocess.check_output([str(args.prices_from_binary), "--export-printing-map"], text=True)) if args.prices_from_binary else {}
    index = json.loads((RES / "card-index.json").read_text())
    prices = json.loads((RES / "card-prices.json").read_text())
    pack_prices = json.loads((RES / "pack-prices.json").read_text())
    evidence = {"asOf": dt.date.today().isoformat(), "sets": {}, "cards": {}, "packImages": {}}
    new_rows, new_sets = [], []
    for app_id, (source_id, group_id) in LATEST.items():
        card_set = fetch(f"https://api.tcgdex.net/v2/en/sets/{source_id}")
        if card_set["releaseDate"] > dt.date.today().isoformat():
            raise ValueError(f"Unreleased set: {source_id}")
        products = fetch(f"https://tcgcsv.com/tcgplayer/3/{group_id}/products")["results"]
        market = fetch(f"https://tcgcsv.com/tcgplayer/3/{group_id}/prices")["results"]
        # Snapshot collection date. The public endpoint does not support HEAD.
        as_of = evidence["asOf"]
        candidates = [p for p in products if product_fields(p).get("Number")]
        with futures.ThreadPoolExecutor(max_workers=8) as executor:
            details = list(executor.map(lambda c: fetch(f"https://api.tcgdex.net/v2/en/cards/{c['id']}"), card_set["cards"]))
        if len(details) != card_set["cardCount"]["total"]:
            raise ValueError(f"Incomplete source: {source_id}")
        rows = []
        matched_products = set()
        for card in details:
            raw_rarity = "Classic Collection" if app_id == "cel30c" else card["rarity"]
            rarity = next((key for key in TIERS if key.casefold() == raw_rarity.casefold()), raw_rarity)
            tier = TIERS[rarity]  # Unknown rarity deliberately stops the import.
            card_id = app_id + "-" + number(card["localId"])
            visual = {"Pokemon": "p", "Trainer": "t", "Energy": "e"}[card["category"]]
            if visual != "t":
                visual += "".join(TYPES[kind] for kind in card.get("types", []))
            # TCGdex has no dependable Tera flag; use explicit source rule text only.
            if "tera" in str(card.get("effect", "")).lower() and visual.startswith("p"):
                visual += "!"
            matches = [p for p in candidates
                       if (app_id == "cel30c" or number(product_fields(p)["Number"]) == number(card["localId"]))
                       and name(product_card_name(p)) == name(card["name"])]
            # Parallel products have a suffix. Prefer the unsuffixed main printing.
            matches = [p for p in matches if not any(mark in p["name"].lower() for mark in
                       ("reverse", "ball pattern", "cosmos", "stamped", "prize pack"))]
            product = matches[0] if len(matches) == 1 else None
            if app_id == "cel30c" and number(card["localId"]) in CLASSIC_PRODUCTS:
                product = next(p for p in candidates if p["productId"] == CLASSIC_PRODUCTS[number(card["localId"])] )
            if card_id in PRODUCT_ALIASES:
                product = next(p for p in candidates if p["productId"] == PRODUCT_ALIASES[card_id])
            if product and product_fields(product).get("Rarity") in TIERS:
                # TCGdex currently collapses the seven Mega Attack Rares to
                # Ultra Rare. TCGplayer preserves the printed rarity label.
                rarity = product_fields(product)["Rarity"]
                tier = TIERS[rarity]
            if product and visual.startswith("p"):
                fields = product_fields(product)
                rule_text = fields.get("CardText", "")
                if re.search(r"\btera\b", rule_text, re.IGNORECASE) and not visual.endswith("!"):
                    visual += "!"
            if card_id in PRINTED_TERA_IDS and not visual.endswith("!"):
                visual += "!"
            if rarity not in index["rarities"]:
                index["rarities"].append(rarity)
            rows.append([card_id, card["name"], tier, index["rarities"].index(rarity), visual])
            urls = [card["image"] + "/high.webp"] if card.get("image") else []
            if product:
                matched_products.add(product["productId"])
                urls.insert(0, source_image(product))
                record_prices(prices, card_id, product, market, finishes, as_of)
            evidence["cards"][card_id] = {"sourceID": card["id"], "urls": urls,
                "visualCode": visual,
                "productID": product["productId"] if product else None,
                "printedNumber": product_fields(product).get("Number") if product else card["localId"]}
        # RGB secret cards are independently documented by TCGplayer but absent
        # from TCGdex's numeric checklist. Keep their actual printed identifiers.
        if app_id == "cel30":
            for product in candidates:
                fields = product_fields(product)
                if fields.get("Number") not in ("R/RGB", "G/RGB", "B/RGB"):
                    continue
                rarity = fields["Rarity"]
                if rarity not in index["rarities"]:
                    index["rarities"].append(rarity)
                card_id = "cel30-" + fields["Number"].replace("/", "_")
                rows.append([card_id, "Mew", TIERS[rarity], index["rarities"].index(rarity), "pP"])
                evidence["cards"][card_id] = {"sourceID": None, "urls": [source_image(product)],
                    "visualCode": "pP",
                    "productID": product["productId"], "printedNumber": fields["Number"]}
                record_prices(prices, card_id, product, market, finishes, as_of)
        if any(not evidence["cards"][row[0]]["urls"] for row in rows):
            raise ValueError(f"Missing image source: {[r[0] for r in rows if not evidence['cards'][r[0]]['urls']]}")
        new_rows += rows
        if app_id != "cel30c":
            new_sets.append({"id": app_id, "name": card_set["name"], "series": "Mega Evolution",
                "released": card_set["releaseDate"].replace("-", "/"), "cardCount": len(rows),
                "tierCounts": dict(Counter(row[2] for row in rows))})
            selected = choose_booster(products, market)
            if selected:
                product, price = selected
                pack_prices["packs"][app_id] = {"usd": round(price["marketPrice"], 2),
                    "asOf": as_of,
                    "productID": product["productId"], "productName": product["name"],
                    "url": product["url"], "sampleCount": product["snapshotSampleCount"]}
                evidence["packImages"][app_id] = source_image(product)
        evidence["sets"][app_id] = {"sourceID": source_id, "groupID": group_id,
            "released": card_set["releaseDate"], "cardCount": len(rows)}
        print(app_id, card_set["name"], len(rows), dict(Counter(row[2] for row in rows)), flush=True)
    index["cards"] = [row for row in index["cards"] if row[0].split("-")[0] not in LATEST] + new_rows
    index["sets"] = [s for s in index["sets"] if s["id"] not in LATEST] + new_sets
    index["subsetParents"]["cel30c"] = "cel30"
    parent = next(s for s in index["sets"] if s["id"] == "cel30")
    combined = [row for row in new_rows if row[0].startswith(("cel30-", "cel30c-"))]
    parent["cardCount"] = len(combined)
    parent["tierCounts"] = dict(Counter(row[2] for row in combined))
    assert len({r[0] for r in index["cards"]}) == len(index["cards"])
    write_json(RES / "card-index.json", index)
    write_json(RES / "card-prices.json", prices)
    # Old prices retain their snapshot date. New source dates are separately recorded.
    write_json(RES / "pack-prices.json", pack_prices)
    write_json(RES / "catalogue-sources.json", evidence)
    print(f"Imported {len(new_rows)} cards; {len(index['sets'])} booster sets; {len(index['cards'])} cards")


if __name__ == "__main__":
    main()
