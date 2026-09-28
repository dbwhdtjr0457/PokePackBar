#!/usr/bin/env python3
"""Download original HD card art (Pillow and urllib3 required).

No resampling is performed. Decode, dimensions and SHA-256 are recorded for each
file. An incomplete catalogue fails the command and cannot pass the install gate.
Existing verified files are reused; source snapshots and download reports remain
under ignored local-assets/. Usage: local-assets/.venv/bin/python ... [--verify]
"""
from __future__ import annotations

import argparse
import concurrent.futures as futures
import hashlib
import io
import json
import re
import shutil
import time
import urllib.request
from urllib.parse import quote
from pathlib import Path

from PIL import Image
import urllib3
from update_latest_catalogue import ROOT, RES, fetch, write_json, number, name

ART = ROOT / "local-assets/CardArt"
MIRROR = "https://zaoosaaiyamnnuhhnnxt.supabase.co/storage/v1/object/public/cards"
HTTP = urllib3.PoolManager(num_pools=8, maxsize=48, block=True,
    timeout=urllib3.Timeout(connect=8, read=20), retries=1,
    headers={"User-Agent": "PokePackBar-local-art/0.11"})
REFRESH = False
ALIASES = {"swsh45": "swsh4.5", "swsh45sv": "swsh4.5sv", "cel25c": "cel25cc",
           "swsh12pt5": "swsh12.5", "swsh12pt5gg": "swsh12.5gg", "me1": "me01", "me2": "me02",
           "sv8pt5": "sv08.5", "sv4pt5": "sv04.5", "sv3pt5": "sv03.5",
           "zsv10pt5": "sv10.5b", "rsv10pt5": "sv10.5w"}
# All four Classic Collection cards are printed #15, but are different cards.
# These verified products prevent either 404s or accidental shared Venusaur art.
PRODUCT_OVERRIDES = {"cel25c-15_A1": 250321, "cel25c-15_A2": 250323,
                     "cel25c-15_A3": 250324, "cel25c-15_A4": 250333}


def validate(data, is_pack=False):
    with Image.open(io.BytesIO(data)) as picture:
        width, height = picture.size
        picture.verify()
    if is_pack:
        if width < 120 or height < 180:
            raise ValueError(f"Small pack art: {width}x{height}")
    elif min(width, height) < 580 or max(width, height) < 800 or not 0.60 < min(width, height) / max(width, height) < 0.85:
        raise ValueError(f"Not original HD card art: {width}x{height}")
    return width, height, {"JPEG": "jpg", "WEBP": "webp", "PNG": "png"}[picture.format]


def download(job):
    key, urls, is_pack = job
    failures = []
    sidecar = ART / (key + ".json")
    saved = None
    if sidecar.is_file():
        try:
            record = json.loads(sidecar.read_text())
            existing = ART / record["file"]
            data = existing.read_bytes()
            width, height, _ = validate(data, is_pack)
            if record["sha256"] != hashlib.sha256(data).hexdigest():
                raise ValueError("Changed cached file")
            if not REFRESH:
                return key, record, None
            saved = record
        except Exception as error:
            failures.append(str(error))
    for url in dict.fromkeys(urls):
        if saved and saved["sourceURL"] == url:
            return key, saved, None
        try:
            response = HTTP.request("GET", url)
            if response.status != 200:
                raise ValueError(f"HTTP {response.status}")
            data = response.data
            width, height, extension = validate(data, is_pack)
            filename = key + "." + extension
            temporary = ART / (filename + ".part")
            temporary.write_bytes(data)
            temporary.replace(ART / filename)
            record = {"file": filename, "width": width, "height": height, "bytes": len(data),
                      "sha256": hashlib.sha256(data).hexdigest(), "sourceURL": url}
            write_json(ART / (key + ".json"), record)
            return key, record, None
        except Exception as error:
            failures.append(f"{url}: {error}")
    return key, None, failures


def image_sources(index, latest):
    pricing = json.loads((RES / "card-prices.json").read_text())
    market_images = {}
    for key, source in pricing.get("printingSources", {}).items():
        card_id, finish = key.split("#", 1)
        if finish in ("reverseHolo", "pokeBall", "masterBall"):
            continue
        match = re.search(r"/product/(\d+)/", source)
        if match:
            market_images[card_id] = f"https://tcgplayer-cdn.tcgplayer.com/product/{match[1]}_in_1000x1000.jpg"
    source_sets = fetch("https://api.tcgdex.net/v2/en/sets")
    by_id = {s["id"]: s for s in source_sets}
    by_name = {name(s["name"]): s["id"] for s in source_sets}
    current_sets = {s["id"]: s for s in index["sets"]}
    prefixes = sorted({row[0].split("-")[0] for row in index["cards"]} - set(latest["sets"]))

    def load(prefix):
        source_id = ALIASES.get(prefix)
        if not source_id:
            source_id = prefix if prefix in by_id else by_name.get(name(current_sets.get(prefix, {}).get("name", "")))
        if not source_id or source_id not in by_id:
            return prefix, {}
        try:
            source = fetch(f"https://api.tcgdex.net/v2/en/sets/{source_id}")
            return prefix, {number(c["localId"]): c for c in source["cards"]}
        except Exception as error:
            print(f"Metadata fallback {prefix}: {error}", flush=True)
            return prefix, {}

    with futures.ThreadPoolExecutor(max_workers=8) as executor:
        source_cards = dict(executor.map(load, prefixes))
    jobs = []
    for card_id, card_name, *_ in index["cards"]:
        if card_id in latest["cards"]:
            urls = latest["cards"][card_id]["urls"]
        else:
            prefix, local_id = card_id.split("-", 1)
            image_id = "question" if card_id == "ex10-?" else local_id
            card = source_cards.get(prefix, {}).get(number(local_id))
            # The original PNG is often 733x1024 where TCGdex's "high"
            # derivative is only 600x825. Never replace a better original with
            # the smaller file simply because WebP transfers faster.
            urls = [f"https://images.pokemontcg.io/{prefix}/{quote(image_id, safe='')}_hires.png"]
            if card_id in market_images:
                # This product join was already validated by set, card number,
                # name and canonical printing by the price importer. TCGplayer
                # supplies 1000px scans for many older 400/600px source cards.
                urls.insert(0, market_images[card_id])
            if card_id in PRODUCT_OVERRIDES:
                urls.insert(0, f"https://tcgplayer-cdn.tcgplayer.com/product/{PRODUCT_OVERRIDES[card_id]}_in_1000x1000.jpg")
            if card and card.get("image") and name(card["name"]) == name(card_name):
                urls.append(card["image"] + "/high.webp")
            urls.append(f"{MIRROR}/{prefix}/{quote(card_id, safe='')}_hires.webp")
        jobs.append((card_id, urls, False))
    for card_set in index["sets"]:
        key = card_set["id"]
        urls = [latest["packImages"][key]] if key in latest["packImages"] else []
        urls.append(f"{MIRROR}/packs/{key}.webp")
        jobs.append(("pack_" + key, urls, True))
    return jobs


def verify(index):
    manifest = json.loads((RES / "card-art.json").read_text())
    expected = {row[0] for row in index["cards"]} | {"pack_" + s["id"] for s in index["sets"]}
    if expected != set(manifest["images"]):
        raise ValueError(f"Library coverage mismatch: {len(expected - set(manifest['images']))} missing")
    total = 0
    for key, entry in manifest["images"].items():
        data = (ART / entry["file"]).read_bytes()
        width, height, _ = validate(data, key.startswith("pack_"))
        if (width, height) != (entry["width"], entry["height"]) or hashlib.sha256(data).hexdigest() != entry["sha256"]:
            raise ValueError(f"Image changed: {key}")
        total += len(data)
    print(f"PASS offline originals: {len(expected)} images, {total / 1024**3:.2f} GiB; no resize/upscale")


def main():
    global REFRESH
    parser = argparse.ArgumentParser()
    parser.add_argument("--verify", action="store_true")
    parser.add_argument("--copy-to", type=Path, help="Copy only manifest-referenced, verified originals into an app bundle")
    parser.add_argument("--workers", type=int, default=12)
    parser.add_argument("--refresh", action="store_true", help="Retry preferred sources instead of reusing verified originals")
    args = parser.parse_args()
    REFRESH = args.refresh
    index = json.loads((RES / "card-index.json").read_text())
    if args.copy_to:
        verify(index)
        args.copy_to.mkdir(parents=True, exist_ok=True)
        manifest = json.loads((RES / "card-art.json").read_text())
        for entry in manifest["images"].values():
            shutil.copy2(ART / entry["file"], args.copy_to / entry["file"])
        return
    if args.verify:
        return verify(index)
    ART.mkdir(parents=True, exist_ok=True)
    if shutil.disk_usage(ART).free < 15 * 1024**3:
        raise ValueError("At least 15 GiB free space is required")
    latest = json.loads((RES / "catalogue-sources.json").read_text())
    jobs = image_sources(index, latest)
    records, failures = {}, {}
    start = time.monotonic()
    with futures.ThreadPoolExecutor(max_workers=args.workers) as executor:
        pending = [executor.submit(download, job) for job in jobs]
        for done, future in enumerate(futures.as_completed(pending), 1):
            key, record, error = future.result()
            if record:
                records[key] = record
            else:
                failures[key] = error
            if done % 1000 == 0 or done == len(jobs):
                print(f"{done}/{len(jobs)} verified={len(records)} unavailable={len(failures)} elapsed={time.monotonic()-start:.0f}s", flush=True)
            if done % 500 == 0:
                write_json(RES / "card-art.json", {"version": 1, "minimumCardWidth": 580,
                    "asOf": latest["asOf"], "images": dict(sorted(records.items()))})
    write_json(ROOT / "local-assets/art-download-failures.json", failures)
    write_json(RES / "card-art.json", {"version": 1, "minimumCardWidth": 580,
        "asOf": latest["asOf"], "images": dict(sorted(records.items()))})
    if failures:
        raise ValueError(f"{len(failures)} images unresolved; inspect local-assets/art-download-failures.json")
    verify(index)


if __name__ == "__main__":
    main()
