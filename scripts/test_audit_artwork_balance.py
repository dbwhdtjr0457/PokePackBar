import json
from pathlib import Path
import tempfile
import unittest

from audit_artwork_balance import combine


class ArtworkCoverageTests(unittest.TestCase):
    def run_case(self, rows, expected):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'rows.jsonl'
            path.write_text('\n'.join(json.dumps(row) for row in rows))
            return combine([path], expected)

    def test_complete_render_is_accepted_without_claiming_visual_approval(self):
        row = dict(key='one#gold', status='signal-pass', artwork={'flags': ['local-edge-loss']})
        self.assertEqual(self.run_case([row], {'one#gold'})['one#gold'], row)

    def test_missing_printing_is_rejected(self):
        with self.assertRaisesRegex(ValueError, 'Incomplete coverage'):
            self.run_case([], {'missing#gold'})

    def test_duplicate_printing_is_rejected(self):
        row = dict(key='one#gold', status='signal-pass', artwork={'flags': []})
        with self.assertRaisesRegex(ValueError, 'Duplicate printing'):
            self.run_case([row, row], {'one#gold'})

    def test_render_failure_is_rejected(self):
        with self.assertRaisesRegex(ValueError, 'Native render errors'):
            self.run_case([dict(key='one#gold', status='error')], {'one#gold'})

    def test_signal_only_result_does_not_count_as_artwork_review(self):
        with self.assertRaisesRegex(ValueError, 'missing artwork'):
            self.run_case([dict(key='one#gold', status='signal-pass')], {'one#gold'})


if __name__ == '__main__':
    unittest.main()
