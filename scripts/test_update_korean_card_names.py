import json
import unittest

from update_korean_card_names import OVERRIDES, RES, SOURCES, lookup_table, normalized, resolve, validate_names


def card(card_id, name, visual="pR"):
    return [card_id, name, "C", 0, visual]


class KoreanNameTests(unittest.TestCase):
    def setUp(self):
        self.cards = [card("old-1", "Charizard"), card("old-2", "Mew ex"), card("old-3", "Mew EX")]
        self.names = {"old-1": "리자몽", "old-2": "뮤 ex", "old-3": "뮤 EX"}
        self.table = lookup_table(self.cards, self.names)

    def test_reuses_exact_name_and_source(self):
        name, source = resolve(card("new-1", "Mew ex"), self.table, {})
        self.assertEqual(name, "뮤 ex")
        self.assertEqual(source["source"], "old-2")

    def test_alias_does_not_merge_mechanics_or_gender(self):
        self.assertEqual(normalized("Ho-Oh"), normalized("Ho Oh"))
        self.assertNotEqual(normalized("Mew ex"), normalized("Mew EX"))
        self.assertNotEqual(normalized("Nidoran♀"), normalized("Nidoran♂"))
        self.assertNotEqual(normalized("Umbreon ★"), normalized("Umbreon"))

    def test_ambiguous_existing_names_require_review(self):
        rows = self.cards + [card("old-4", "Charizard")]
        table = lookup_table(rows, self.names | {"old-4": "다른이름"})
        self.assertIsNone(resolve(card("new-1", "Charizard"), table, {}))

    def test_owner_mega_suffix_composition(self):
        self.assertEqual(resolve(card("new-1", "Team Rocket's Mega Charizard ex"), self.table, {})[0],
                         "로켓단의 메가리자몽 ex")

    def test_never_composes_trainer_or_unknown_species(self):
        self.assertIsNone(resolve(card("new-1", "Mega Charizard ex", "t"), self.table, {}))
        self.assertIsNone(resolve(card("new-1", "Missing Species ex"), self.table, {}))

    def test_reviewed_override_takes_precedence(self):
        overrides = {"Charizard": {"name": "검토한 이름", "kind": "reviewed", "source": "reference"}}
        self.assertEqual(resolve(card("new-1", "Charizard"), self.table, overrides)[0], "검토한 이름")

    def test_detects_missing_empty_english_and_boilerplate(self):
        for invalid in (None, "", " ", "Team Rocket's 뮤츠 ex", "소프트웨어"):
            self.assertTrue(validate_names([card("new-1", "Mew")], {"new-1": invalid}))
        self.assertEqual(validate_names(self.cards, self.names), [])

    def test_real_catalogue_and_original_regression(self):
        cards = json.loads((RES / "card-index.json").read_text())["cards"]
        names = json.loads((RES / "card-names-ko.json").read_text())["names"]
        added = json.loads(SOURCES.read_text())
        self.assertEqual(validate_names(cards, names), [])
        self.assertEqual(len(added), 1283)
        original = {key: value for key, value in names.items() if key not in added}
        self.assertEqual(len(validate_names(cards, original)), 1283)
        self.assertEqual(names["cel30-R_RGB"], "뮤")
        self.assertEqual(names["me4-75"], "앙쥬 플라엣테")
        self.assertEqual(names["me3-75"], "유카리")
        self.assertEqual(names["me5-78"], "무쿠")

    def test_added_names_reproduce_from_preserved_baseline(self):
        cards = json.loads((RES / "card-index.json").read_text())["cards"]
        names = json.loads((RES / "card-names-ko.json").read_text())["names"]
        sources = json.loads(SOURCES.read_text())
        baseline = {key: value for key, value in names.items() if key not in sources}
        table = lookup_table(cards, baseline)
        overrides = json.loads(OVERRIDES.read_text())
        by_id = {row[0]: row for row in cards}
        for card_id, provenance in sources.items():
            result = resolve(by_id[card_id], table, overrides)
            self.assertIsNotNone(result, card_id)
            self.assertEqual(result, (names[card_id], provenance), card_id)


if __name__ == "__main__":
    unittest.main()
