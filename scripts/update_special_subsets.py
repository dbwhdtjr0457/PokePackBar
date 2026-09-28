#!/usr/bin/env python3
"""Import English special subsets into their physical parent booster pools.

Card metadata comes from the versioned PokemonTCG data repository. Prices come
from the Pokemon TCG API's TCGplayer market fields. The broad card-price
snapshot deliberately keeps its original ``asOf`` date; a separate provenance
block records when only these subset rows were refreshed.

The command is idempotent: existing rows for the eight source set IDs are
replaced, not appended.
"""

from __future__ import annotations

import argparse
import json
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Optional


POKEMON_TCG_DATA_REVISION = "39a26a144c8b6ef6c2fb17b2c29d0bb7121e3a11"
METADATA_URL = (
    "https://raw.githubusercontent.com/PokemonTCG/pokemon-tcg-data/"
    + POKEMON_TCG_DATA_REVISION
    + "/cards/en/{set_id}.json"
)
API_URL = "https://api.pokemontcg.io/v2/cards"
USER_AGENT = "PokePackBar/0.9 special-subset snapshot"

# Keep this equal to MarketEconomy.unknownUSD. Missing market data must not make
# a card free, and guessing a tier-derived price would look like market data.
UNKNOWN_USD = 0.05


@dataclass(frozen=True)
class Subset:
    source_id: str
    parent_id: str
    expected_cards: int


SUBSETS = (
    Subset("sma", "sm115", 94),
    Subset("swsh45sv", "swsh45", 122),
    Subset("cel25c", "cel25", 25),
    Subset("swsh9tg", "swsh9", 30),
    Subset("swsh10tg", "swsh10", 30),
    Subset("swsh11tg", "swsh11", 30),
    Subset("swsh12tg", "swsh12", 30),
    Subset("swsh12pt5gg", "swsh12pt5", 70),
)


def tier_for(source_set_id: str, rarity: str) -> str:
    """Map API rarities to the app's collection ladder.

    Subset context matters. A Shining Fates V is a shiny-vault replacement,
    not an ordinary V from the rare slot; Galarian Gallery art uses the later
    AR/SAR ladder even though the legacy API calls it Trainer Gallery Rare Holo.
    """

    if source_set_id == "sma":
        return {
            "Rare Shiny": "S",
            "Rare Shiny GX": "SSR",
            # Full-art Trainers and gold cards are still Shiny Vault reverse-slot
            # replacements. Their API rarity keeps the distinct foil treatment.
            "Rare Ultra": "SSR",
            "Rare Secret": "SSR",
        }[rarity]
    if source_set_id == "swsh45sv":
        return {
            "Rare Shiny": "S",
            "Rare Holo V": "SSR",
            "Rare Holo VMAX": "SSR",
            "Rare Secret": "SSR",
        }[rarity]
    if source_set_id == "cel25c":
        # A distinct collection tier keeps these cards in Celebrations' third
        # replacement position instead of the ordinary ultra-rare pool.
        return {"Classic Collection": "CHR"}[rarity]
    if source_set_id.endswith("tg"):
        # Every Trainer Gallery printing occupies the reverse-holo position.
        # Its source rarity is retained for finish rendering and display.
        return "CHR"
    if source_set_id == "swsh12pt5gg":
        if rarity == "Trainer Gallery Rare Holo":
            return "AR"
        # The rest of the gallery shares its hit position. Rare Secret still
        # renders gold because the original rarity remains on CardEntry.
        return "SAR"
    raise ValueError(f"no tier mapping for {source_set_id} / {rarity}")


def fetch_json(url: str, attempts: int) -> Any:
    last_error: Optional[Exception] = None
    for attempt in range(1, attempts + 1):
        try:
            request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
            with urllib.request.urlopen(request, timeout=45) as response:
                return json.load(response)
        except (urllib.error.URLError, OSError, json.JSONDecodeError) as error:
            last_error = error
            if attempt == attempts:
                break
            time.sleep(min(8.0, 0.6 * attempt))
    raise RuntimeError(f"failed after {attempts} attempts: {url}: {last_error}")


def api_cards(source_set_id: str, attempts: int) -> list[dict[str, Any]]:
    query = urllib.parse.urlencode(
        {
            "q": f"set.id:{source_set_id}",
            "pageSize": "250",
            "select": "id,name,rarity,tcgplayer",
        }
    )
    payload = fetch_json(f"{API_URL}?{query}", attempts)
    return payload.get("data", [])


def market_price(card: dict[str, Any]) -> Optional[float]:
    variants = card.get("tcgplayer", {}).get("prices", {})
    markets = [
        value.get("market")
        for value in variants.values()
        if isinstance(value, dict) and isinstance(value.get("market"), (int, float))
        and value["market"] > 0
    ]
    return round(max(markets), 2) if markets else None


def require_count(subset: Subset, cards: list[dict[str, Any]], source: str) -> None:
    if len(cards) != subset.expected_cards:
        raise RuntimeError(
            f"{subset.source_id}: expected {subset.expected_cards} {source} cards, got {len(cards)}"
        )


def read_json(path: Path) -> dict[str, Any]:
    with path.open(encoding="utf-8") as file:
        return json.load(file)


def write_json(path: Path, payload: dict[str, Any], compact: bool) -> None:
    temporary = path.with_suffix(path.suffix + ".tmp")
    with temporary.open("w", encoding="utf-8") as file:
        if compact:
            json.dump(payload, file, ensure_ascii=False, separators=(",", ":"))
        else:
            # card-prices.json historically keeps one key per line. Retaining
            # that shape makes a price refresh reviewable instead of replacing
            # the entire 17k-entry file in the diff.
            json.dump(payload, file, ensure_ascii=False, indent=0)
        file.write("\n")
    temporary.replace(path)


def import_subsets(
    index: dict[str, Any],
    prices: dict[str, Any],
    attempts: int,
    refresh_prices: bool = True,
) -> dict[str, int]:
    source_ids = {subset.source_id for subset in SUBSETS}
    subset_parents = dict(index.get("subsetParents", {}))
    existing_rows = [row for row in index["cards"] if row[0].split("-", 1)[0] not in source_ids]
    price_map = {
        card_id: value
        for card_id, value in prices["prices"].items()
        if card_id.split("-", 1)[0] not in source_ids
    }
    rarity_names = list(index.get("rarities", []))

    imported_rows: list[list[Any]] = []
    imported_prices: dict[str, float] = {}
    fallback_count = 0
    updated_dates: list[str] = []

    for subset in SUBSETS:
        metadata = fetch_json(METADATA_URL.format(set_id=subset.source_id), attempts)
        require_count(subset, metadata, "metadata")
        live_cards = api_cards(subset.source_id, attempts) if refresh_prices else []
        if refresh_prices:
            require_count(subset, live_cards, "API")
        live_by_id = {card["id"]: card for card in live_cards}
        metadata_ids = {card["id"] for card in metadata}
        if refresh_prices and metadata_ids != set(live_by_id):
            missing = sorted(metadata_ids - set(live_by_id))
            extra = sorted(set(live_by_id) - metadata_ids)
            raise RuntimeError(
                f"{subset.source_id}: metadata/API ID mismatch; missing={missing[:3]} extra={extra[:3]}"
            )

        subset_parents[subset.source_id] = subset.parent_id
        for card in metadata:
            rarity = card.get("rarity") or ""
            tier = tier_for(subset.source_id, rarity)
            if rarity not in rarity_names:
                rarity_names.append(rarity)
            imported_rows.append([card["id"], card["name"], tier, rarity_names.index(rarity)])

            if refresh_prices:
                live = live_by_id[card["id"]]
                value = market_price(live)
                if value is None:
                    value = UNKNOWN_USD
                    fallback_count += 1
                imported_prices[card["id"]] = value
                updated_at = live.get("tcgplayer", {}).get("updatedAt")
                if isinstance(updated_at, str) and updated_at:
                    updated_dates.append(updated_at)

    index["rarities"] = rarity_names
    index["subsetParents"] = dict(sorted(subset_parents.items()))
    index["cards"] = sorted(existing_rows + imported_rows, key=lambda row: row[0])

    parent_by_source = {subset.source_id: subset.parent_id for subset in SUBSETS}
    affected_parents = set(parent_by_source.values())
    counts: dict[str, dict[str, int]] = {parent: {} for parent in affected_parents}
    totals: dict[str, int] = {parent: 0 for parent in affected_parents}
    for row in index["cards"]:
        source = row[0].split("-", 1)[0]
        parent = parent_by_source.get(source, source)
        if parent not in affected_parents:
            continue
        tier = row[2]
        counts[parent][tier] = counts[parent].get(tier, 0) + 1
        totals[parent] += 1

    tier_order = index.get("tierOrder", [])
    for card_set in index["sets"]:
        parent = card_set["id"]
        if parent not in affected_parents:
            continue
        card_set["cardCount"] = totals[parent]
        card_set["tierCounts"] = {
            tier: counts[parent][tier] for tier in tier_order if counts[parent].get(tier, 0) > 0
        }

    if refresh_prices:
        price_map.update(imported_prices)
        prices["prices"] = dict(sorted(price_map.items()))
        prices["subsetPriceSnapshot"] = {
            "asOf": (max(updated_dates) if updated_dates else prices.get("asOf", ""))
            .replace("/", "-"),
            "source": "Pokemon TCG API v2 / TCGplayer market",
            "metadataRevision": POKEMON_TCG_DATA_REVISION,
            "fallbackUSD": UNKNOWN_USD,
            "fallbackCards": fallback_count,
            "setIDs": [subset.source_id for subset in SUBSETS],
        }

    return {
        "cards": len(imported_rows),
        "marketPrices": len(imported_prices) - fallback_count,
        "fallbackPrices": fallback_count,
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--index",
        type=Path,
        default=Path("Sources/PokePackBar/Resources/card-index.json"),
    )
    parser.add_argument(
        "--prices",
        type=Path,
        default=Path("Sources/PokePackBar/Resources/card-prices.json"),
    )
    parser.add_argument("--attempts", type=int, default=15)
    parser.add_argument(
        "--index-only",
        action="store_true",
        help="refresh pinned metadata and parent mappings without requesting or rewriting prices",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if args.attempts < 1:
        raise SystemExit("--attempts must be at least 1")
    index = read_json(args.index)
    prices = read_json(args.prices)
    summary = import_subsets(index, prices, args.attempts, refresh_prices=not args.index_only)
    write_json(args.index, index, compact=True)
    if not args.index_only:
        write_json(args.prices, prices, compact=False)
    if args.index_only:
        print(f"Imported metadata for {summary['cards']} subset cards; prices unchanged.")
    else:
        print(
            f"Imported {summary['cards']} subset cards: "
            f"{summary['marketPrices']} market prices, "
            f"{summary['fallbackPrices']} at ${UNKNOWN_USD:.2f} fallback."
        )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (KeyError, RuntimeError, ValueError) as error:
        print(f"error: {error}", file=sys.stderr)
        raise SystemExit(1)
