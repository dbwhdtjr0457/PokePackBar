import unittest

import numpy as np

from build_reviewed_foil import build, raster, rect, union


class ReviewedFoilTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        manifest = build()
        cls.data = manifest['printings']
        cls.stamps = manifest['starSheetExclusions']

    def test_ordinary_ex_stamps_follow_the_printed_side(self):
        self.assertEqual(len(self.stamps), 12)
        for cid, entry in self.stamps.items():
            mask = raster(entry['contours'], (1000,700))
            y, x = np.nonzero(mask)
            expected_x = .14 if cid in {'cel30-54','cel30-92'} else .87
            self.assertAlmostEqual(x.mean()/700, expected_x, delta=.035, msg=cid)
            self.assertLess((x.max()-x.min())/700, .26, cid)
            self.assertLess((y.max()-y.min())/1000, .17, cid)

    def test_overlap_is_union_not_xor(self):
        shape = (100, 100)
        result = raster(union(shape, [rect(.1,.1,.7,.7)], [rect(.4,.4,.9,.9)]), shape)
        self.assertEqual(result[50,50], 255)
        self.assertEqual(result[5,5], 0)

    def test_holes_are_preserved(self):
        shape = (100,100)
        donut = [rect(.1,.1,.9,.9), rect(.3,.3,.7,.7)]
        result = raster(union(shape, donut), shape)
        self.assertEqual(result[50,50], 0)
        self.assertEqual(result[20,20], 255)

    def test_explicit_cohort_not_rarity_wide(self):
        self.assertEqual(len(self.data), 85)
        rocket = self.data['cel25c-15_A2#celebrationsClassic']
        self.assertIn('additional_front_and_oblique', rocket['evidenceStatus'])
        for key, entry in self.data.items():
            self.assertEqual(key, entry['cardID']+'#'+entry['finish'])
            self.assertFalse(entry['physicalPlateVerified'])
            self.assertTrue(entry['referenceURLs'])

    def test_fans_are_registered_individually(self):
        geometries = set()
        for number in range(23,53):
            e = self.data[f'cel30-{number}#fullArt']
            if e['fans']:
                geometries.add(tuple((f['x'],f['y'],f['radius']) for f in e['fans']))
            self.assertTrue(e['fans'])
            self.assertFalse(e['baseInclude'])
        self.assertGreaterEqual(len(geometries), 20)

    def test_no_empty_or_degenerate_masks(self):
        for entry in self.data.values():
            for layer in entry['layers']:
                mask = raster(layer['include'], (336,240))
                mask &= ~raster(layer['exclude'], (336,240))
                self.assertGreater(np.count_nonzero(mask), 20, (entry['cardID'],layer['name']))

    def test_classic30_gold_is_registered_to_each_original(self):
        import json
        from build_reviewed_foil import RES
        expansion = json.loads((RES/'expansion-foil.json').read_text())['cards']
        for n in range(1,31):
            cid = f'cel30c-{n}'
            entry = self.data[cid+'#celebrationsClassic']
            layers = {l['name']: l for l in entry['layers']}
            self.assertEqual(layers['gold-rim']['include'], expansion[cid]['goldFrame'])
            self.assertIn('illustration-stars', layers)
            if n in {21,26,30}:
                self.assertNotIn('subject-micro-etch', layers)


if __name__ == '__main__':
    unittest.main()
