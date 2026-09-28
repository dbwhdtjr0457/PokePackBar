#!/usr/bin/env python3
"""Import Prismatic Evolutions Poke Ball and Master Ball market prices.

The source is TCGCSV's public cache of TCGplayer catalogue data:

* products: https://tcgcsv.com/tcgplayer/3/23821/products
* prices:   https://tcgcsv.com/tcgplayer/3/23821/prices

TCGplayer models each pattern as its own product.  This importer selects a
printing from the product-name suffix, maps the product's ``Number`` extended
field (for example, ``001/131``) to ``sv8pt5-1``, and joins the price collection
on ``productId``.  A parallel product must have one positive
``Holofoil.marketPrice``; missing market data is an error rather than a made-up
fallback.

Only ``sv8pt5`` Poke Ball and Master Ball entries in ``printingPrices`` are
replaced.  All legacy card prices, other printing prices, and unrelated
top-level snapshot metadata are preserved.
"""

from __future__ import annotations

import argparse
import datetime as dt
import email.utils
import json
import re
import sys
import time
import unicodedata
import urllib.error
import urllib.request
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Optional


CATEGORY_ID = 3  # TCGplayer: Pokemon
GROUP_ID = 23821  # SV: Prismatic Evolutions
SET_ID = "sv8pt5"
SET_CARD_DENOMINATOR = 131
BASE_URL = "https://tcgcsv.com/tcgplayer"
PRODUCTS_URL = f"{BASE_URL}/{CATEGORY_ID}/{GROUP_ID}/products"
PRICES_URL = f"{BASE_URL}/{CATEGORY_ID}/{GROUP_ID}/prices"
DOCS_URL = "https://tcgcsv.com/docs"
USER_AGENT = "PokePackBar/0.9 printing-price-snapshot"


@dataclass(frozen=True)
class Variant:
    product_suffix: str
    finish: str
    expected_products: int


VARIANTS = (
    Variant(" (Poke Ball Pattern)", "pokeBall", 100),
    Variant(" (Master Ball Pattern)", "masterBall", 67),
)
TARGET_FINISHES = {variant.finish for variant in VARIANTS}


@dataclass(frozen=True)
class SourceResponse:
    results: list[dict[str, Any]]
    last_modified: Optional[dt.datetime]


def fetch_collection(url: str, attempts: int) -> SourceResponse:
    last_error: Optional[Exception] = None
    for attempt in range(1, attempts + 1):
        try:
            request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
            with urllib.request.urlopen(request, timeout=45) as response:
                payload = json.load(response)
                last_modified_header = response.headers.get("Last-Modified")

            if payload.get("success") is not True:
                raise RuntimeError(f"source reported failure: {payload.get('errors', [])}")
            results = payload.get("results")
            if not isinstance(results, list):
                raise RuntimeError("source response has no results array")

            last_modified = None
            if last_modified_header:
                last_modified = email.utils.parsedate_to_datetime(last_modified_header)
                if last_modified.tzinfo is None:
                    last_modified = last_modified.replace(tzinfo=dt.timezone.utc)
                last_modified = last_modified.astimezone(dt.timezone.utc)
            return SourceResponse(results=results, last_modified=last_modified)
        except (json.JSONDecodeError, RuntimeError, TimeoutError, urllib.error.URLError) as error:
            last_error = error
            if attempt < attempts:
                time.sleep(min(8.0, 0.5 * attempt))
    raise RuntimeError(f"failed after {attempts} attempts: {url}: {last_error}")


def read_json(path: Path) -> dict[str, Any]:
    with path.open(encoding="utf-8") as file:
        payload = json.load(file)
    if not isinstance(payload, dict):
        raise RuntimeError(f"expected a JSON object: {path}")
    return payload


def write_json(path: Path, payload: dict[str, Any]) -> None:
    temporary = path.with_suffix(path.suffix + ".tmp")
    with temporary.open("w", encoding="utf-8") as file:
        # card-prices.json historically keeps one key per line.  Preserve that
        # shape so a snapshot refresh has a reviewable diff.
        json.dump(payload, file, ensure_ascii=False, indent=0)
        file.write("\n")
    temporary.replace(path)


def extended_value(product: dict[str, Any], field_name: str) -> Optional[str]:
    matches = [
        field.get("value")
        for field in product.get("extendedData", [])
        if field.get("name") == field_name
    ]
    if len(matches) != 1 or not isinstance(matches[0], str):
        return None
    return matches[0]


def card_number(product: dict[str, Any]) -> int:
    raw_number = extended_value(product, "Number")
    match = re.fullmatch(r"0*(\d+)/(\d+)", raw_number or "")
    if match is None or int(match.group(2)) != SET_CARD_DENOMINATOR:
        raise RuntimeError(
            f"product {product.get('productId')} has unexpected card number {raw_number!r}"
        )
    return int(match.group(1))


def normalized_name(name: str) -> str:
    """Normalize only catalogue disambiguators, not the card identity itself."""

    name = re.sub(r" - \d{3}/131$", "", name)
    name = re.sub(r" \[[^\]]+\]$", "", name)
    name = unicodedata.normalize("NFKD", name).encode("ascii", "ignore").decode()
    return re.sub(r"[^a-z0-9]+", "", name.lower())


def indexed_cards(index: dict[str, Any]) -> dict[str, str]:
    cards: dict[str, str] = {}
    for row in index.get("cards", []):
        if not isinstance(row, list) or len(row) < 2:
            continue
        card_id, name = row[0], row[1]
        if isinstance(card_id, str) and card_id.startswith(f"{SET_ID}-"):
            cards[card_id] = name
    if not cards:
        raise RuntimeError(f"card index contains no {SET_ID} cards")
    return cards


def market_prices_by_product(prices: list[dict[str, Any]]) -> dict[int, list[dict[str, Any]]]:
    grouped: dict[int, list[dict[str, Any]]] = {}
    for row in prices:
        product_id = row.get("productId")
        if isinstance(product_id, int):
            grouped.setdefault(product_id, []).append(row)
    return grouped


def import_prices(
    index: dict[str, Any],
    products: list[dict[str, Any]],
    prices: list[dict[str, Any]],
) -> tuple[dict[str, float], dict[str, int]]:
    cards = indexed_cards(index)
    prices_by_product = market_prices_by_product(prices)
    imported: dict[str, float] = {}
    coverage: dict[str, int] = {}
    matched_product_ids: set[int] = set()

    for variant in VARIANTS:
        matching_products = [
            product
            for product in products
            if isinstance(product.get("name"), str)
            and product["name"].endswith(variant.product_suffix)
        ]
        if len(matching_products) != variant.expected_products:
            raise RuntimeError(
                f"{variant.finish}: expected {variant.expected_products} products, "
                f"got {len(matching_products)}"
            )

        for product in matching_products:
            product_id = product.get("productId")
            if not isinstance(product_id, int) or product_id in matched_product_ids:
                raise RuntimeError(f"invalid or duplicate productId: {product_id!r}")
            matched_product_ids.add(product_id)

            number = card_number(product)
            card_id = f"{SET_ID}-{number}"
            indexed_name = cards.get(card_id)
            if indexed_name is None:
                raise RuntimeError(f"{product_id}: {card_id} is missing from card-index.json")

            product_name = product["name"][: -len(variant.product_suffix)]
            if normalized_name(product_name) != normalized_name(indexed_name):
                raise RuntimeError(
                    f"{product_id}: number matched {card_id}, but names differ: "
                    f"{product_name!r} != {indexed_name!r}"
                )

            holo_prices = [
                row
                for row in prices_by_product.get(product_id, [])
                if row.get("subTypeName") == "Holofoil"
            ]
            if len(holo_prices) != 1:
                raise RuntimeError(
                    f"{product_id}: expected one Holofoil price, got {len(holo_prices)}"
                )
            market_price = holo_prices[0].get("marketPrice")
            if not isinstance(market_price, (int, float)) or market_price <= 0:
                raise RuntimeError(f"{product_id}: invalid marketPrice {market_price!r}")

            storage_key = f"{card_id}#{variant.finish}"
            if storage_key in imported:
                raise RuntimeError(f"duplicate printing key: {storage_key}")
            imported[storage_key] = round(float(market_price), 2)

        coverage[variant.finish] = len(matching_products)

    return dict(sorted(imported.items())), coverage


def is_target_printing(storage_key: str) -> bool:
    card_id, separator, finish = storage_key.rpartition("#")
    return separator == "#" and card_id.startswith(f"{SET_ID}-") and finish in TARGET_FINISHES


def merge_snapshot(
    snapshot: dict[str, Any],
    imported: dict[str, float],
    coverage: dict[str, int],
    products_source: SourceResponse,
    prices_source: SourceResponse,
    as_of: str,
) -> dict[str, Any]:
    existing_printings = snapshot.get("printingPrices", {})
    if not isinstance(existing_printings, dict):
        raise RuntimeError("printingPrices must be a JSON object when present")

    preserved = {
        key: value
        for key, value in existing_printings.items()
        if isinstance(key, str) and not is_target_printing(key)
    }
    preserved.update(imported)

    version = snapshot.get("version", 2)
    snapshot["version"] = max(version if isinstance(version, int) else 2, 3)
    snapshot["printingPrices"] = dict(sorted(preserved.items()))
    snapshot["printingPriceSnapshot"] = {
        "asOf": as_of,
        "source": "TCGplayer market price via TCGCSV",
        "docsURL": DOCS_URL,
        "productsURL": PRODUCTS_URL,
        "pricesURL": PRICES_URL,
        "tcgplayerGroupID": GROUP_ID,
        "setID": SET_ID,
        "match": "product suffix + extendedData.Number; price join on productId",
        "priceField": "Holofoil.marketPrice",
        "coverage": coverage,
        "productsLastModified": iso_timestamp(products_source.last_modified),
        "pricesLastModified": iso_timestamp(prices_source.last_modified),
    }
    return snapshot


def iso_timestamp(value: Optional[dt.datetime]) -> Optional[str]:
    if value is None:
        return None
    return value.replace(microsecond=0).isoformat().replace("+00:00", "Z")


def snapshot_date(value: Optional[dt.datetime], override: Optional[str]) -> str:
    if override is not None:
        try:
            return dt.date.fromisoformat(override).isoformat()
        except ValueError as error:
            raise RuntimeError("--as-of must use YYYY-MM-DD") from error
    if value is None:
        raise RuntimeError("prices response has no Last-Modified header; pass --as-of explicitly")
    return value.date().isoformat()


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
    parser.add_argument("--attempts", type=int, default=5)
    parser.add_argument(
        "--as-of",
        help="override source Last-Modified date (YYYY-MM-DD), mainly for archived inputs",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="fetch and validate without changing card-prices.json",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if args.attempts < 1:
        raise RuntimeError("--attempts must be at least 1")

    index = read_json(args.index)
    snapshot = read_json(args.prices)
    products_source = fetch_collection(PRODUCTS_URL, args.attempts)
    prices_source = fetch_collection(PRICES_URL, args.attempts)
    imported, coverage = import_prices(
        index=index,
        products=products_source.results,
        prices=prices_source.results,
    )
    as_of = snapshot_date(prices_source.last_modified, args.as_of)
    merged = merge_snapshot(
        snapshot=snapshot,
        imported=imported,
        coverage=coverage,
        products_source=products_source,
        prices_source=prices_source,
        as_of=as_of,
    )

    action = "validated" if args.dry_run else "wrote"
    if not args.dry_run:
        write_json(args.prices, merged)
    print(
        f"{action} {len(imported)} {SET_ID} parallel prices "
        f"(Poke Ball {coverage['pokeBall']}, Master Ball {coverage['masterBall']}) "
        f"as of {as_of}"
    )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (KeyError, RuntimeError, TypeError, ValueError) as error:
        print(f"error: {error}", file=sys.stderr)
        raise SystemExit(1)
