#!/usr/bin/env python3
"""Build the public low/high WebP tree consumed by CardImageSource.

The checked-in card-art manifest and the separately restored original snapshot
are the source of truth. Card images get a 360 px thumbnail and a full-size
WebP; pack images keep a single full-size WebP at cards/packs/<set>.webp.
"""
from __future__ import annotations

import argparse
import concurrent.futures
import hashlib
import json
import os
import shutil
import tempfile
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "Sources/PokePackBar/Resources/card-art.json"
DEFAULT_ART = ROOT / "local-assets/CardArt"
DEFAULT_OUTPUT = ROOT / "local-assets/s3-artwork"


def sha256(path: Path) -> str:
    value = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            value.update(chunk)
    return value.hexdigest()


def webp_mode(image: Image.Image) -> Image.Image:
    return image.convert("RGBA" if "A" in image.getbands() else "RGB")


def save_webp(image: Image.Image, destination: Path, quality: int) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(dir=destination.parent, suffix=".webp", delete=False) as temporary:
        temp = Path(temporary.name)
    try:
        webp_mode(image).save(temp, format="WEBP", quality=quality, method=6, exact=True)
        temp.replace(destination)
    finally:
        temp.unlink(missing_ok=True)


def valid_webp(path: Path, expected_size: tuple[int, int] | None = None,
               maximum_edge: int | None = None) -> bool:
    try:
        with Image.open(path) as image:
            if image.format != "WEBP":
                return False
            if expected_size is not None and image.size != expected_size:
                return False
            if maximum_edge is not None and max(image.size) > maximum_edge:
                return False
            image.verify()
        return path.stat().st_size > 0
    except Exception:
        return False


def card_targets(output: Path, card_id: str) -> tuple[Path, Path]:
    set_id, separator, _ = card_id.partition("-")
    if not separator or not set_id:
        raise ValueError(f"Malformed card ID: {card_id}")
    directory = output / "cards" / set_id
    return directory / f"{card_id}.webp", directory / f"{card_id}_hires.webp"


def build_one(job: tuple[str, dict, str, str, int, int]) -> tuple[str, list[dict]]:
    key, entry, art_raw, output_raw, low_edge, high_quality = job
    art, output = Path(art_raw), Path(output_raw)
    source = art / entry["file"]
    if not source.is_file() or source.is_symlink():
        raise ValueError(f"Missing original: {key} ({source})")
    if source.stat().st_size != entry["bytes"] or sha256(source) != entry["sha256"]:
        raise ValueError(f"Original does not match manifest: {key}")

    made: list[Path] = []
    with Image.open(source) as opened:
        opened.load()
        original = webp_mode(opened)
        if original.size != (entry["width"], entry["height"]):
            raise ValueError(f"Original dimensions changed: {key}")

        if key.startswith("pack_"):
            target = output / "cards" / "packs" / f"{key.removeprefix('pack_')}.webp"
            if not valid_webp(target, expected_size=original.size):
                if source.suffix.lower() == ".webp":
                    target.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copyfile(source, target)
                else:
                    save_webp(original, target, high_quality)
            made.append(target)
        else:
            low, high = card_targets(output, key)
            if not valid_webp(high, expected_size=original.size):
                if source.suffix.lower() == ".webp":
                    high.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copyfile(source, high)
                else:
                    save_webp(original, high, high_quality)
            if not valid_webp(low, maximum_edge=low_edge):
                thumbnail = original.copy()
                thumbnail.thumbnail((low_edge, low_edge), Image.Resampling.LANCZOS)
                save_webp(thumbnail, low, 82)
            made.extend((low, high))

    records = []
    for path in made:
        if not valid_webp(path):
            raise ValueError(f"Generated invalid WebP: {path}")
        with Image.open(path) as image:
            width, height = image.size
        records.append({
            "key": path.relative_to(output).as_posix(),
            "bytes": path.stat().st_size,
            "sha256": sha256(path),
            "width": width,
            "height": height,
            "sourceSHA256": entry["sha256"],
        })
    return key, records


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--art-dir", type=Path, default=DEFAULT_ART)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--workers", type=int, default=min(8, os.cpu_count() or 4))
    parser.add_argument("--low-edge", type=int, default=360)
    parser.add_argument("--high-quality", type=int, default=92)
    parser.add_argument("--reverse", action="store_true", help=argparse.SUPPRESS)
    parser.add_argument("--no-manifest", action="store_true", help=argparse.SUPPRESS)
    args = parser.parse_args()
    if args.workers < 1 or args.low_edge < 100 or not 1 <= args.high_quality <= 100:
        parser.error("invalid worker, edge, or quality value")

    payload = json.loads(MANIFEST.read_text())
    images = payload.get("images", {})
    if not images:
        raise ValueError("Empty card-art manifest")
    args.output.mkdir(parents=True, exist_ok=True)
    jobs = [
        (key, entry, str(args.art_dir), str(args.output), args.low_edge, args.high_quality)
        for key, entry in sorted(images.items(), reverse=args.reverse)
    ]

    records: dict[str, dict] = {}
    with concurrent.futures.ThreadPoolExecutor(max_workers=args.workers) as executor:
        futures = [executor.submit(build_one, job) for job in jobs]
        for done, future in enumerate(concurrent.futures.as_completed(futures), 1):
            key, built = future.result()
            records.update((item["key"], item) for item in built)
            if done % 1000 == 0 or done == len(futures):
                print(f"{done}/{len(futures)} originals -> {len(records)} WebP objects", flush=True)

    expected = (len(images) - sum(key.startswith("pack_") for key in images)) * 2 \
        + sum(key.startswith("pack_") for key in images)
    if len(records) != expected:
        raise ValueError(f"Incomplete output: {len(records)} != {expected}")
    if args.no_manifest:
        print(f"PASS auxiliary S3 artwork worker: {len(records)} objects", flush=True)
        return 0
    result = {
        "version": 1,
        "sourceManifestSHA256": sha256(MANIFEST),
        "sourceImageCount": len(images),
        "objectCount": len(records),
        "lowMaximumEdge": args.low_edge,
        "highQuality": args.high_quality,
        "objects": dict(sorted(records.items())),
    }
    (args.output / "s3-artwork-manifest.json").write_text(
        json.dumps(result, ensure_ascii=False, indent=2, sort_keys=True) + "\n"
    )
    total = sum(record["bytes"] for record in records.values())
    print(f"PASS S3 artwork: {len(records)} objects, {total / 1024**3:.2f} GiB", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
