#!/usr/bin/env python3
"""Audit every resolved foil printing and optionally render representative masks.

Uses the real native renderer offline. It never creates WalletStore or opens a
save. Output is reproducible diagnostic data, not a physical-foil ground truth.
"""
import argparse
import concurrent.futures
import json
import os
import subprocess
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
RES = ROOT / "Sources/PokePackBar/Resources"
WINDOWS = {"artWindow", "artWindowAndMark", "artAndBorder", "artNameAndBorder",
           "artSubject", "artBackground", "artSubjectAndBorder", "traitBands"}
# These scans intentionally have full-face foil (not a missing illustration).
FULL_FACE_HOLOS = {"cel25-25", "g1-25", "g1-29"}


def main():
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument("--binary", type=Path, default=ROOT / ".build/release/PokePackBar")
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--render", action="store_true")
    parser.add_argument("--sets", nargs="*", help="Limit only native renders to these sets; data audit still checks every printing")
    args = parser.parse_args()
    binary = str(args.binary.resolve())
    args.output.mkdir(parents=True, exist_ok=True)
    env = dict(os.environ, PPB_OFFLINE="1", PPB_CARD_ART_DIR=str(ROOT / "local-assets/CardArt"))
    geometry = json.loads((RES / "foil-geometry.json").read_text())["cards"]
    index = json.loads((RES / "card-index.json").read_text())
    cards = {c[0]: c for c in index["cards"]}
    printings = json.loads(subprocess.check_output([binary, "--export-foil-map", "--all-cards"], env=env))
    weak, missing = set(), set()
    samples, groups = {}, set()
    for value in printings.values():
        cid, finish, spec = value["cardID"], value["finish"], value["spec"]
        entry = geometry[cid]
        if entry["confidence"] < .2:
            weak.add(cid)
        if spec["coverage"] in WINDOWS and entry["art"] is None:
            if not cards[cid][4].startswith("e") and cid not in FULL_FACE_HOLOS:
                missing.add(cid)
        group = (entry["profile"], json.dumps(spec, sort_keys=True), finish)
        if group not in groups:
            groups.add(group)
            samples[cid + "#" + finish] = value
        # Every 30th card + every MA ink contour and reviewed exception.
        if cid.startswith(("cel30-", "cel30c-")) or finish == "megaAttack" or entry["method"] == "reviewed-image-landmarks":
            samples[cid + "#" + finish] = value
    report = dict(originals=len(geometry), foilPrintings=len(printings),
                  materialLayoutGroups=len(groups), weakFoilCards=sorted(weak),
                  missingWindowCards=sorted(missing), renderedSamples=0)
    assert not missing, f"Framed foil classified as full art: {sorted(missing)}"
    assert not weak, f"Review weak frame evidence: {sorted(weak)}"
    if args.render:
        ordered = [v for v in samples.values() if not args.sets or v["cardID"].split("-")[0] in args.sets]
        if args.sets:
            # Explicit sets request all their printings, not just one per group.
            ordered = [v for v in printings.values() if v["cardID"].split("-")[0] in args.sets]

        def render(value):
            common = [binary, "--render-holo-preview", value["cardID"], str(args.output.resolve()),
                      value["finish"], "--compact", "--actual-size", "--flat-card"]
            for extra in [[], ["--geometry"]]:
                subprocess.run(common + extra, env=env, check=True, capture_output=True, timeout=45)
            return value

        with concurrent.futures.ThreadPoolExecutor(max_workers=2) as executor:
            for i, _ in enumerate(executor.map(render, ordered), 1):
                if i % 25 == 0:
                    print(f"Native render {i}/{len(ordered)}", flush=True)
        report["renderedSamples"] = len(ordered)
        # Each sample: coverage overlay + actual illuminated material.
        for page in range(0, len(ordered), 24):
            batch = ordered[page:page + 24]
            sheet = Image.new("RGB", (6 * 264, ((len(batch) + 5) // 6) * 215), "#101114")
            draw = ImageDraw.Draw(sheet)
            for i, value in enumerate(batch):
                stem = f'{value["cardID"]}-{value["finish"]}'
                x, y = i % 6 * 264, i // 6 * 215
                draw.text((x + 4, y + 3), stem, fill="white")
                for j, suffix in enumerate(["geometry-rest", "diagonal"]):
                    with Image.open(args.output / f"{stem}-{suffix}.png") as image:
                        # Fixed native preview margin; retain the complete card.
                        image = image.crop((112, 112, 608, 798))
                        image.thumbnail((130, 193))
                        sheet.paste(image, (x + j * 132, y + 19))
            sheet.save(args.output / f"audit-{page // 24:03d}.jpg", quality=94)
    (args.output / "report.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
