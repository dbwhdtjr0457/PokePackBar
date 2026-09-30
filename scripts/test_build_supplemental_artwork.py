import tempfile
import unittest
from pathlib import Path

from PIL import Image

from build_s3_artwork import build_one, sha256
from build_supplemental_artwork import SOURCE, inspect_sources


class SupplementalArtworkTests(unittest.TestCase):
    def test_all_english_sources_are_high_resolution(self):
        sources = inspect_sources(SOURCE)
        self.assertEqual(len(sources), 41)
        self.assertEqual(sources["supplement-energy-mee30-grass"]["file"], "mee30-en-grass.jpg")
        self.assertIn("supplement-energy-sm-fairy", sources)
        self.assertNotIn("supplement-energy-sve-fairy", sources)

    def test_builds_real_low_and_high_webp_without_upscaling(self):
        card_id = "supplement-energy-mee30-grass"
        entry = inspect_sources(SOURCE)[card_id]
        with tempfile.TemporaryDirectory() as temporary:
            _, objects = build_one((card_id, entry, str(SOURCE), temporary, 360, 92))
            self.assertEqual(len(objects), 2)
            for record in objects:
                path = Path(temporary) / record["key"]
                self.assertEqual(record["sha256"], sha256(path))
                with Image.open(path) as image:
                    self.assertEqual(image.format, "WEBP")
                    if "_hires" in path.name:
                        self.assertEqual(image.size, (entry["width"], entry["height"]))
                    else:
                        self.assertEqual(max(image.size), 360)
                    self.assertLess(image.width, image.height)

    def test_rejects_missing_source_instead_of_partial_upload(self):
        with tempfile.TemporaryDirectory() as temporary:
            with self.assertRaisesRegex(ValueError, "missing="):
                inspect_sources(Path(temporary))


if __name__ == "__main__":
    unittest.main()
