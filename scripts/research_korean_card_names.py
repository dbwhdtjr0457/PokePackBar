#!/usr/bin/env python3
"""Read public Korean card-detail pages for reviewed naming evidence (no images)."""
import concurrent.futures
import html
import json
import re
import urllib.request
from pathlib import Path


def read_card(card_id):
    url = f"https://pokemoncard.co.kr/cards/detail/{card_id}"
    request = urllib.request.Request(url, headers={"User-Agent": "PokePackBar/local-name-review"})
    with urllib.request.urlopen(request, timeout=30) as response:
        source = response.read().decode("utf-8")
    if "접근불가" in source and 'class="card-hp title"' not in source:
        raise RuntimeError(f"Access unavailable: {url}")
    match = re.search(r'<span class="card-hp title">(.*?)</span>', source, re.S)
    if not match:
        raise RuntimeError(f"Missing card title: {url}")
    title = html.unescape(re.sub(r"<[^>]+>", "", match[1])).strip()
    body = source[source.index('<div class="pokemon-info">'):]
    body = body.split('<div class="pokemon-detail', 1)[0]
    # Short rules text supports manual English/Korean identity review, not fuzzy joins.
    body = re.sub(r"\s+", " ", html.unescape(re.sub(r"<[^>]+>", " ", body))).strip()
    return dict(id=card_id, name=title, url=url, rules=body[:1200])


if __name__ == "__main__":
    groups = {"BS2025015": range(153, 194), "BS2026002": range(66, 81),
              "BS2026003": range(68, 84), "BS2026004": range(63, 82)}
    ids = [f"{prefix}{number:03}" for prefix, numbers in groups.items() for number in numbers]
    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as executor:
        entries = list(executor.map(read_card, ids))
    output = Path("local-assets/korean-name-review/official-card-names.json")
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(entries, ensure_ascii=False, indent=2) + "\n")
    for entry in entries:
        print(entry["id"], entry["name"])
