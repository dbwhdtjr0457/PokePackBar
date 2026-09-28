#!/usr/bin/env python3
"""Add compact card supertype/type metadata to ``card-index.json``.

The source is the versioned PokemonTCG data repository, pinned to a commit so
that the same input always produces the same index.  Each card row receives a
fifth value with this grammar::

    p<types>[!]   Pokemon (``!`` means the source explicitly says ``Tera``)
    t             Trainer
    e<types>      Energy

Types are one ASCII character each.  For example, ``pW`` is a Water Pokemon,
``pGD`` is a dual Grass/Darkness Pokemon, and ``pD!`` is a Darkness-type Tera
Pokemon.  An Energy card may omit a type because most historical source rows
do not carry one.

The command validates a one-to-one match between every bundled card and its
source row before replacing the index atomically.  Use ``--check`` in CI, or
``--source-root`` with a checkout of PokemonTCG/pokemon-tcg-data for an offline
and independently inspectable run.
"""

from __future__ import annotations

import argparse
import concurrent.futures
import json
import time
import urllib.error
import urllib.request
from collections import Counter
from pathlib import Path
from typing import Any


POKEMON_TCG_DATA_REVISION = "39a26a144c8b6ef6c2fb17b2c29d0bb7121e3a11"
RAW_CARD_URL = (
    "https://raw.githubusercontent.com/PokemonTCG/pokemon-tcg-data/"
    + POKEMON_TCG_DATA_REVISION
    + "/cards/en/{set_id}.json"
)
USER_AGENT = "PokePackBar card-visual-metadata importer"

TYPE_CODES = {
    "Grass": "G",
    "Fire": "R",
    "Water": "W",
    "Lightning": "L",
    "Psychic": "P",
    "Fighting": "F",
    "Darkness": "D",
    "Metal": "M",
    "Dragon": "N",
    "Fairy": "Y",
    "Colorless": "C",
}


def fetch_json(url: str, attempts: int) -> Any:
    last_error: Exception | None = None
    for attempt in range(1, attempts + 1):
        try:
            request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
            with urllib.request.urlopen(request, timeout=45) as response:
                return json.load(response)
        except (urllib.error.URLError, OSError, json.JSONDecodeError) as error:
            last_error = error
            if attempt < attempts:
                time.sleep(min(5.0, 0.5 * attempt))
    raise RuntimeError(f"failed after {attempts} attempts: {url}: {last_error}")


def source_cards(set_id: str, source_root: Path | None, attempts: int) -> list[dict[str, Any]]:
    if source_root is None:
        payload = fetch_json(RAW_CARD_URL.format(set_id=set_id), attempts)
    else:
        path = source_root / "cards" / "en" / f"{set_id}.json"
        if not path.is_file():
            raise RuntimeError(f"source file is missing: {path}")
        with path.open(encoding="utf-8") as file:
            payload = json.load(file)
    if not isinstance(payload, list):
        raise RuntimeError(f"{set_id}: expected a card array")
    return payload


def compact_visual_code(card: dict[str, Any]) -> str:
    card_id = card.get("id", "<unknown>")
    supertype = card.get("supertype")
    raw_types = card.get("types") or []
    if not isinstance(raw_types, list) or not all(isinstance(value, str) for value in raw_types):
        raise RuntimeError(f"{card_id}: malformed types: {raw_types!r}")
    try:
        types = "".join(TYPE_CODES[value] for value in raw_types)
    except KeyError as error:
        raise RuntimeError(f"{card_id}: unknown card type {error.args[0]!r}") from error

    subtypes = card.get("subtypes") or []
    if not isinstance(subtypes, list) or not all(isinstance(value, str) for value in subtypes):
        raise RuntimeError(f"{card_id}: malformed subtypes: {subtypes!r}")
    is_tera = "Tera" in subtypes

    if supertype == "Pokémon":
        if not 1 <= len(raw_types) <= 2:
            raise RuntimeError(f"{card_id}: Pokemon must have one or two types, got {raw_types!r}")
        return "p" + types + ("!" if is_tera else "")
    if supertype == "Trainer":
        if raw_types or is_tera:
            raise RuntimeError(f"{card_id}: Trainer unexpectedly has type/Tera metadata")
        return "t"
    if supertype == "Energy":
        if len(raw_types) > 2 or is_tera:
            raise RuntimeError(f"{card_id}: Energy has invalid type/Tera metadata")
        return "e" + types
    raise RuntimeError(f"{card_id}: unknown supertype {supertype!r}")


def read_index(path: Path) -> dict[str, Any]:
    with path.open(encoding="utf-8") as file:
        payload = json.load(file)
    if not isinstance(payload.get("cards"), list):
        raise RuntimeError(f"{path}: cards array is missing")
    return payload


def updated_index(
    index: dict[str, Any], source_root: Path | None, attempts: int, workers: int
) -> tuple[dict[str, Any], Counter[str]]:
    rows = index["cards"]
    row_ids: list[str] = []
    for position, row in enumerate(rows):
        if not isinstance(row, list) or len(row) < 4 or not isinstance(row[0], str):
            raise RuntimeError(f"card row {position} is malformed: {row!r}")
        row_ids.append(row[0])
    duplicates = [card_id for card_id, count in Counter(row_ids).items() if count > 1]
    if duplicates:
        raise RuntimeError(f"duplicate card IDs in index: {duplicates[:5]}")

    # New releases are sourced by the independently validated TCGdex/TCGCSV
    # importer. The pinned historical repository deliberately cannot supply them.
    evidence_path = Path(__file__).resolve().parents[1] / "Sources/PokePackBar/Resources/catalogue-sources.json"
    modern = json.loads(evidence_path.read_text()).get("cards", {}) if evidence_path.exists() else {}
    modern = {key: value for key, value in modern.items() if key in row_ids}
    set_ids = sorted({card_id.split("-", 1)[0] for card_id in row_ids if card_id not in modern})
    by_id: dict[str, dict[str, Any]] = {}

    def load(set_id: str) -> tuple[str, list[dict[str, Any]]]:
        return set_id, source_cards(set_id, source_root, attempts)

    with concurrent.futures.ThreadPoolExecutor(max_workers=workers) as executor:
        for set_id, cards in executor.map(load, set_ids):
            for card in cards:
                card_id = card.get("id")
                if not isinstance(card_id, str):
                    raise RuntimeError(f"{set_id}: source card has no string ID")
                if card_id in by_id:
                    raise RuntimeError(f"duplicate source card ID: {card_id}")
                by_id[card_id] = card

    missing = sorted(set(row_ids) - set(by_id) - set(modern))
    if missing:
        raise RuntimeError(f"source is missing {len(missing)} indexed cards: {missing[:8]}")
    extra = sorted(set(by_id) - set(row_ids))
    if extra:
        raise RuntimeError(f"index is missing {len(extra)} source cards: {extra[:8]}")

    stats: Counter[str] = Counter()
    updated_rows: list[list[Any]] = []
    for row in rows:
        if row[0] in modern:
            code = modern[row[0]].get("visualCode")
            if not isinstance(code, str) or not code or code != row[4]:
                raise RuntimeError(f"{row[0]}: rerun update_latest_catalogue.py to validate modern visual metadata")
        else:
            source = by_id[row[0]]
            code = compact_visual_code(source)
        # Column 4 is the rarity index and column 5 is this compact code. Keep
        # any future columns after it so this updater composes with later schema
        # extensions instead of truncating them.
        updated = row[:4] + [code] + row[5:]
        updated_rows.append(updated)

        stats["cards"] += 1
        stats[{"p": "pokemon", "t": "trainer", "e": "energy"}[code[0]]] += 1
        if code.endswith("!"):
            stats["tera"] += 1
        type_count = len(code.removeprefix("p").removeprefix("e").removesuffix("!"))
        if code[0] == "p" and type_count == 2:
            stats["dual_type"] += 1

    result = dict(index)
    result["version"] = max(2, int(index.get("version", 1)))
    result["cards"] = updated_rows
    stats["sets"] = len(set_ids)
    return result, stats


def encoded(payload: dict[str, Any]) -> str:
    return json.dumps(payload, ensure_ascii=False, separators=(",", ":")) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--index",
        type=Path,
        default=Path("Sources/PokePackBar/Resources/card-index.json"),
    )
    parser.add_argument(
        "--source-root",
        type=Path,
        help="local checkout of PokemonTCG/pokemon-tcg-data at the pinned revision",
    )
    parser.add_argument("--attempts", type=int, default=3)
    parser.add_argument("--workers", type=int, default=8)
    parser.add_argument("--check", action="store_true", help="fail if the index would change")
    args = parser.parse_args()

    if args.attempts < 1 or args.workers < 1:
        parser.error("--attempts and --workers must be positive")
    if args.source_root is not None:
        git_marker = args.source_root / ".git"
        if not (args.source_root / "cards" / "en").is_dir():
            parser.error(f"not a pokemon-tcg-data checkout: {args.source_root}")
        # A source archive has no .git directory, so content validation below
        # remains authoritative.  For a checkout, require the pinned revision.
        if git_marker.exists():
            import subprocess

            revision = subprocess.run(
                ["git", "-C", str(args.source_root), "rev-parse", "HEAD"],
                check=True,
                capture_output=True,
                text=True,
            ).stdout.strip()
            if revision != POKEMON_TCG_DATA_REVISION:
                parser.error(
                    f"source revision is {revision}; expected {POKEMON_TCG_DATA_REVISION}"
                )

    current = read_index(args.index)
    updated, stats = updated_index(current, args.source_root, args.attempts, args.workers)
    output = encoded(updated)
    current_output = encoded(current)

    print(f"source revision: {POKEMON_TCG_DATA_REVISION}")
    print(f"source template: {RAW_CARD_URL}")
    print(
        "validated: "
        f"{stats['cards']} cards / {stats['sets']} source sets; "
        f"Pokemon {stats['pokemon']}, Trainer {stats['trainer']}, Energy {stats['energy']}; "
        f"dual-type {stats['dual_type']}, Tera {stats['tera']}"
    )

    if args.check:
        if current_output != output:
            print(f"out of date: {args.index}")
            return 1
        print(f"up to date: {args.index}")
        return 0

    temporary = args.index.with_suffix(args.index.suffix + ".tmp")
    temporary.write_text(output, encoding="utf-8")
    temporary.replace(args.index)
    print(f"updated: {args.index}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
