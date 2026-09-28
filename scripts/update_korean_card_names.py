#!/usr/bin/env python3
"""Extend the bundled Korean name table without changing existing translations.

Only unambiguous existing names, explicit reviewed overrides, and Pokemon-only
name composition are allowed. No machine translation or fuzzy card-art matching.
"""
import argparse
import json
import re
from collections import Counter, defaultdict
from pathlib import Path

RES = Path("Sources/PokePackBar/Resources")
OVERRIDES = Path("scripts/korean-name-overrides.json")
SOURCES = Path("scripts/korean-name-additions.json")
OWNERS = {"Team Rocket's ": "로켓단의 ", "Erika's ": "민화의 ",
          "Hop's ": "호브의 ", "Larry's ": "청목의 ", "N's ": "N의 "}


def normalized(name):
    # Preserve case (ex and EX are different mechanics), gender and rarity marks.
    return re.sub(r"[\s-]", "", name)


def lookup_table(cards, names):
    table = defaultdict(dict)
    for card in cards:
        if value := names.get(card[0]):
            table[normalized(card[1])][value] = card[0]
    return table


def resolve(card, table, overrides):
    card_id, english = card[:2]
    if english in overrides:
        entry = overrides[english]
        return entry["name"], dict(kind=entry["kind"], source=entry["source"], english=english)

    def known(name):
        choices = table.get(normalized(name), {})
        if len(choices) == 1:
            korean, source = next(iter(choices.items()))
            return korean, source
        return None

    if match := known(english):
        return match[0], dict(kind="existing-name", source=match[1], english=english)
    if len(card) < 5 or not str(card[4]).startswith("p"):
        return None
    # Composition is restricted to a Pokemon species that already has an approved
    # Korean name; Trainer/Item/Energy strings must be reviewed individually.
    name = english
    prefix = ""
    for owner, korean in OWNERS.items():
        if name.startswith(owner):
            prefix, name = korean, name[len(owner):]
            break
    if name.startswith("Mega "):
        prefix += "메가"
        name = name[5:]
    suffix = ""
    if match := re.search(r"(?: |\-)(ex|EX|GX|VMAX|VSTAR|V|BREAK|LEGEND)$", name):
        suffix, name = " " + match[1], name[:match.start()]
    if match := known(name):
        return prefix + match[0] + suffix, dict(kind="composed-existing-pokemon", source=match[1], english=english)
    return None


def atomic_json(path, payload):
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(json.dumps(payload, ensure_ascii=False, indent=1) + "\n")
    temporary.replace(path)


def validate_names(cards, names):
    errors = []
    allowed = set("ex EX GX V VMAX VSTAR BREAK LEGEND M N AZ G C GL FB E4 FF WP VIP TAG TEAM TV MAX LV UB A Z".split())
    junk = ("카테고리", "사이트맵", "회사소개", "채용정보", "소프트웨어", "개인정보", "http", "<", ">")
    for card in cards:
        name = names.get(card[0], "")
        if not isinstance(name, str) or not name.strip():
            errors.append(f"{card[0]}: missing Korean name")
            continue
        if any(word not in allowed for word in name.split() if re.fullmatch(r"[A-Za-z]+", word)):
            errors.append(f"{card[0]}: untranslated English in {name}")
        if any(word in name for word in junk):
            errors.append(f"{card[0]}: boilerplate in {name}")
    return errors


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--write", action="store_true")
    parser.add_argument("--verify", action="store_true")
    args = parser.parse_args()
    cards = json.loads((RES / "card-index.json").read_text())["cards"]
    payload = json.loads((RES / "card-names-ko.json").read_text())
    overrides = json.loads(OVERRIDES.read_text()) if OVERRIDES.exists() else {}
    names = payload["names"]
    table = lookup_table(cards, names)
    additions, sources, unresolved = {}, {}, []
    for card in cards:
        if names.get(card[0]):
            continue
        result = resolve(card, table, overrides)
        if result:
            additions[card[0]], sources[card[0]] = result
        else:
            unresolved.append(card)
    print(json.dumps(dict(existing=len(names), resolved=len(additions),
        kinds=Counter(x["kind"] for x in sources.values()),
        unresolved=[dict(id=c[0], name=c[1], visual=c[4] if len(c)>4 else None) for c in unresolved]),
        ensure_ascii=False, indent=2))
    if args.verify:
        if errors := validate_names(cards, names):
            raise SystemExit("Korean catalogue validation failed:\n" + "\n".join(errors[:20]))
        print(f"PASS Korean names: {len(cards)} catalogue cards have bundled names")
    if args.write:
        if unresolved:
            raise SystemExit("Unresolved names: no files changed")
        if errors := validate_names(cards, names | additions):
            raise SystemExit("Invalid names: no files changed\n" + "\n".join(errors[:20]))
        payload["names"].update(additions)
        old_sources = json.loads(SOURCES.read_text()) if SOURCES.exists() else {}
        old_sources.update(sources)
        atomic_json(RES / "card-names-ko.json", payload)
        atomic_json(SOURCES, old_sources)


if __name__ == "__main__":
    main()
