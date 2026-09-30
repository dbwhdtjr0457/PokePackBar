import unittest

import numpy as np

from audit_foil_visibility import measure, subject_region, texture_response, visible


class VisibilityGuardTests(unittest.TestCase):
    def setUp(self):
        self.region = np.ones((20, 20), dtype=bool)
        self.rest = np.full((20, 20, 3), 100.0)

    def test_visible_small_and_large_response(self):
        frames = [self.rest] + [self.rest + 4] * 4 + [self.rest + 12] * 5
        self.assertTrue(visible(measure(frames, self.region)))

    def test_successfully_rendered_but_inert_frames_fail(self):
        self.assertFalse(visible(measure([self.rest] * 10, self.region)))

    def test_extreme_tilt_only_does_not_pass(self):
        frames = [self.rest] * 5 + [self.rest + 25] * 5
        self.assertFalse(visible(measure(frames, self.region)))

    def test_correct_region_excludes_unrelated_effect(self):
        region = self.region.copy()
        region[:, :10] = False
        changed = self.rest.copy()
        changed[:, :10] += 40
        self.assertFalse(visible(measure([self.rest] + [changed] * 9, region)))

    def test_tiny_bright_spot_requires_review_not_automatic_acceptance(self):
        changed = self.rest.copy()
        changed[0, 0] = 255
        self.assertFalse(visible(measure([self.rest] + [changed] * 9, self.region)))

    def test_subject_contours_keep_holes_and_aspect_fit_offset(self):
        entry = dict(width=100, height=100, subject=[
            [[0.1, 0.1], [0.9, 0.1], [0.9, 0.9], [0.1, 0.9]],
            [[0.4, 0.4], [0.6, 0.4], [0.6, 0.6], [0.4, 0.6]],
        ])
        region = subject_region(entry, width=100, height=140)
        self.assertFalse(region[15, 50])
        self.assertTrue(region[40, 50])
        self.assertFalse(region[70, 50])

    def test_whole_face_brightness_is_not_texture(self):
        result = texture_response([self.rest, self.rest + 30], [1], self.region)
        self.assertEqual(result['meanDetailDelta255'], 0)

    def test_static_printed_detail_is_not_animated_texture(self):
        detailed = self.rest.copy()
        detailed[::2, ::2] += 40
        result = texture_response([detailed, detailed], [1], self.region)
        self.assertEqual(result['meanDetailDelta255'], 0)

    def test_local_ridges_produce_texture_contrast(self):
        changed = self.rest.copy()
        changed[::2, :] += 20
        changed[1::2, :] -= 10
        result = texture_response([self.rest, changed], [1], self.region)
        self.assertGreater(result['meanDetailDelta255'], 10)
        self.assertGreater(result['fractionAbove4'], 0.9)


if __name__ == '__main__':
    unittest.main()
