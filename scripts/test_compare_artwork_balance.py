import unittest

from compare_artwork_balance import compare


def row(edge, small=5, material='megaGold', status='signal-pass', flags=()):
    return dict(material=material, status=status, small=small,
                artwork=dict(poses=[dict(edgeRetention=edge)], flags=list(flags)))


class BalanceComparisonTests(unittest.TestCase):
    def test_mur_improves_without_losing_signal(self):
        result = compare({'a': row(.68)}, {'a': row(.86)})
        self.assertEqual(result['protectedFailures'], [])

    def test_weak_mur_is_not_approved_for_clear_art(self):
        result = compare({'a': row(.68)}, {'a': row(.99, status='review')})
        self.assertEqual(result['protectedFailures'], ['a'])
        self.assertEqual(result['newLowSignalKeys'], ['a'])

    def test_bwr_strength_must_stay_unchanged(self):
        result = compare({'a': row(.9, material='white')}, {'a': row(.9, small=2, material='white')})
        self.assertEqual(result['protectedFailures'], ['a'])

    def test_incomplete_catalogue_is_rejected(self):
        with self.assertRaises(ValueError):
            compare({'a': row(.9)}, {})


if __name__ == '__main__':
    unittest.main()
