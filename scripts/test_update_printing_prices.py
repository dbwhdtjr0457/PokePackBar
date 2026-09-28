import unittest

from update_printing_prices import add_fallbacks, apply_quotes, match_printings, number_key, valid_price


def product(pid, number, name):
    return dict(productId=pid, name=name, url=f"https://www.tcgplayer.com/product/{pid}",
                extendedData=[dict(name="Number", value=number)])


def price(pid, value, subtype="Holofoil"):
    return dict(productId=pid, marketPrice=value, lowPrice=9999, midPrice=20000, subTypeName=subtype)


def payload():
    return {key: {} for key in ("prices", "printingPrices", "printingDates", "printingSources", "printingKinds",
                               "priceDates", "priceSources", "priceKinds")}


class PrintingPriceTests(unittest.TestCase):
    def match(self, products, prices, cards, finishes, evidence=None, parallels=None):
        return match_printings(products, prices, "2026-09-22", cards, finishes, evidence or {}, parallels or {})

    def test_rgb_letters_are_distinct_and_normalize_both_forms(self):
        for letter in "RGB":
            self.assertEqual(number_key(f"{letter}_RGB"), f"{letter}/RGB")
        self.assertEqual(number_key("001/100"), "1")
        self.assertIsNone(number_key("not numbered"))
        cards = [[f"cel30-{c}_RGB", "Mew"] for c in "RGB"]
        finishes = {c[0]: "etched" for c in cards}
        products = [product(i, f"{c}/RGB", f"Mew - {c}/RGB") for i, c in enumerate("RGB")]
        result, ambiguous = self.match(products, [price(i, 100+i) for i in range(3)], cards, finishes)
        self.assertEqual(ambiguous, 0)
        self.assertEqual({k: v[0] for k, v in result.items()}, {f"cel30-{c}_RGB#etched": 100+i for i, c in enumerate("RGB")})

    def test_unsupported_numbers_never_join_through_none(self):
        result, _ = self.match([product(1, "", "Mew")], [price(1, 10)], [["x-???", "Mew"]], {"x-???": "etched"})
        self.assertEqual(result, {})

    def test_null_nan_boolean_and_asking_prices_are_not_market_quotes(self):
        for value in (None, float("nan"), float("inf"), True, 0, -1, 10_000_000):
            self.assertFalse(valid_price(value))
            result, _ = self.match([product(1, "R/RGB", "Mew - R/RGB")], [price(1, value)],
                                   [["cel30-R_RGB", "Mew"]], {"cel30-R_RGB": "etched"})
            self.assertEqual(result, {})

    def test_classic_reprint_ordinal_uses_curated_product_identity(self):
        result, _ = self.match([product(7, "4/102", "Charizard - Base Set")], [price(7, 77)],
                               [["cel30c-1", "Charizard"]], {"cel30c-1": "celebrationsClassic"},
                               {"cel30c-1": dict(productID=7, printedNumber="4/102")})
        self.assertEqual(result["cel30c-1#celebrationsClassic"][0], 77)

    def test_ascended_energy_and_ball_keep_separate_runtime_finishes(self):
        parallel = {"me2pt5-1": dict(productID=2, pattern="pokeBall", energy=dict(productID=3))}
        result, _ = self.match([product(2, "001/217", "Oddish (Poke Ball)"), product(3, "001/217", "Oddish (Energy Symbol Pattern)")],
                               [price(2, .32, "Reverse Holofoil"), price(3, .27, "Reverse Holofoil")],
                               [["me2pt5-1", "Oddish"]], {"me2pt5-1": "normal"}, parallels=parallel)
        self.assertEqual(set(result), {"me2pt5-1#patternedReverse", "me2pt5-1#reverseHolo"})

    def test_duplicate_number_and_name_is_ambiguous(self):
        result, _ = self.match([product(1, "1", "Mew")], [price(1, 10)],
                               [["x-1", "Mew"], ["x-01", "Mew"]], {"x-1": "holo", "x-01": "holo"})
        self.assertEqual(result, {})

    def test_multiple_source_products_for_same_printing_are_rejected(self):
        result, ambiguous = self.match([product(1, "1", "Mew"), product(2, "1", "Mew")],
                                      [price(1, 10), price(2, 20)], [["x-1", "Mew"]], {"x-1": "holo"})
        self.assertEqual(result, {})
        self.assertEqual(ambiguous, 1)

    def test_only_canonical_price_updates_representative_and_old_rows_survive(self):
        data = payload()
        data["prices"] = {"x-1": 1, "x-2": 3}
        data["priceDates"] = {"x-1": "old", "x-2": "old"}
        apply_quotes(data, {"x-1#masterBall": (100, "url", "new", "market")}, {"x-1": "normal"})
        self.assertEqual(data["prices"]["x-1"], 1)
        apply_quotes(data, {"x-1#normal": (2, "url", "new", "market")}, {"x-1": "normal"})
        self.assertEqual(data["prices"], {"x-1": 2, "x-2": 3})
        self.assertEqual(data["priceDates"], {"x-1": "new", "x-2": "old"})

    def test_reference_is_labelled_and_never_overwrites_market_price(self):
        data = payload()
        refs = {"x-1": dict(productID=7, usd=4000, url="source", asOf="2026-09-23")}
        evidence = {"x-1": dict(productID=7)}
        finishes = {"x-1": "etched"}
        self.assertEqual(add_fallbacks(data, refs, set(), finishes, evidence), ["x-1"])
        self.assertEqual(data["priceKinds"]["x-1"], "completed-sales-estimate")
        apply_quotes(data, {"x-1#etched": (4500, "tcg", "2026-09-24", "market")}, finishes)
        self.assertEqual(add_fallbacks(data, refs, set(), finishes, evidence), [])
        self.assertEqual(data["prices"]["x-1"], 4500)
        self.assertEqual(data["printingKinds"]["x-1#etched"], "market")

    def test_reference_wrong_identity_is_rejected(self):
        with self.assertRaises(ValueError):
            add_fallbacks(payload(), {"x-1": dict(productID=7, usd=1)}, set(),
                          {"x-1": "etched"}, {"x-1": dict(productID=8)})


if __name__ == "__main__":
    unittest.main()
