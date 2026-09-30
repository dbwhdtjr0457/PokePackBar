#!/usr/bin/env python3
"""Generate CDN-only low/high supplemental Energy WebP variants.

Checked-in English scans are regeneration inputs, not application resources.
The output has the same cards/<set>/<id> layout as CardImageSource; upload the
cards/ tree, retaining the manifest locally to verify every uploaded object.
"""
from __future__ import annotations

import argparse
import concurrent.futures
import json
import tempfile
from pathlib import Path

from PIL import Image

from build_s3_artwork import build_one, sha256


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "Sources/PokePackBar/Resources/supplement-energy"
OUTPUT = ROOT / "local-assets/supplemental-artwork"
TYPES = ("grass", "fire", "water", "lightning", "psychic", "fighting", "darkness", "metal")
STYLES = ("sm", "swsh", "sve", "mee", "mee30")


def source_files() -> dict[str, str]:
    return {
        f"supplement-energy-{style}-{energy}":
        f"{style}{'-en' if style in ('mee', 'mee30') else ''}-{energy}"
        f".{'png' if style == 'sve' else 'jpg'}"
        for style in STYLES
        for energy in (TYPES + ("fairy",) if style == "sm" else TYPES)
    }


def inspect_sources(directory: Path) -> dict[str, dict]:
    expected = source_files()
    actual = {path.name for path in directory.iterdir() if path.is_file() and not path.name.startswith(".")}
    if actual != set(expected.values()):
        raise ValueError(f"Supplemental source mismatch: missing={sorted(set(expected.values()) - actual)}, "
                         f"unexpected={sorted(actual - set(expected.values()))}")
    images = {}
    for card_id, name in expected.items():
        path = directory / name
        if path.is_symlink():
            raise ValueError(f"Unexpected symlink: {name}")
        with Image.open(path) as image:
            width, height = image.size
            image.verify()
        if not (width >= 650 and height >= 900 and width < height):
            raise ValueError(f"Low-resolution or non-portrait source: {name} ({width}x{height})")
        images[card_id] = {"file": name, "bytes": path.stat().st_size, "sha256": sha256(path),
                           "width": width, "height": height}
    return images


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=SOURCE)
    parser.add_argument("--output", type=Path, default=OUTPUT)
    parser.add_argument("--workers", type=int, default=4)
    args = parser.parse_args()
    if args.workers < 1:
        parser.error("workers must be positive")
    sources = inspect_sources(args.source)
    objects = {}
    args.output.mkdir(parents=True, exist_ok=True)
    # Regenerate in isolation so a changed original cannot reuse a stale WebP
    # merely because it has the same dimensions as the previous source scan.
    with tempfile.TemporaryDirectory(prefix=".supplemental-", dir=args.output) as temporary:
        jobs = [(card_id, entry, str(args.source), temporary, 360, 92)
                for card_id, entry in sorted(sources.items())]
        with concurrent.futures.ThreadPoolExecutor(max_workers=args.workers) as executor:
            for _, records in executor.map(build_one, jobs):
                objects.update((record["key"], record) for record in records)
        for key in objects:
            destination = args.output / key
            destination.parent.mkdir(parents=True, exist_ok=True)
            (Path(temporary) / key).replace(destination)
    if len(sources) != 41 or len(objects) != 82:
        raise ValueError("Incomplete supplemental Energy output")
    manifest = {"version": 1, "sourceImageCount": len(sources), "objectCount": len(objects),
                "lowMaximumEdge": 360, "highQuality": 92,
                "sources": dict(sorted(sources.items())), "objects": dict(sorted(objects.items()))}
    (args.output / "supplemental-artwork-manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2, sort_keys=True) + "\n")
    print(f"PASS supplemental CDN artwork: {len(sources)} originals -> {len(objects)} WebP objects, "
          f"{sum(record['bytes'] for record in objects.values()):,} bytes")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
