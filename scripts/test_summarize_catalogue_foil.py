import json
from pathlib import Path
import tempfile
import unittest

from summarize_catalogue_foil import combine


class CatalogueSummaryTests(unittest.TestCase):
    def test_recheck_overrides_only_the_rechecked_printing(self):
        with tempfile.TemporaryDirectory() as directory:
            first = Path(directory) / 'first.jsonl'
            second = Path(directory) / 'second.jsonl'
            first.write_text('\n'.join(json.dumps(row) for row in [
                dict(key='one#holo', status='review'),
                dict(key='two#reverseHolo', status='signal-pass'),
            ]))
            second.write_text(json.dumps(dict(key='one#holo', status='sparse-signal-pass')))
            rows = combine([first, second])
            self.assertEqual(set(rows), {'one#holo', 'two#reverseHolo'})
            self.assertEqual(rows['one#holo']['status'], 'sparse-signal-pass')
            self.assertEqual(rows['one#holo']['auditFile'], 'second.jsonl')
            self.assertEqual(rows['two#reverseHolo']['auditFile'], 'first.jsonl')

    def test_duplicate_in_one_run_is_not_silently_accepted(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'duplicate.jsonl'
            row = json.dumps(dict(key='one#holo', status='signal-pass'))
            path.write_text(row + '\n' + row)
            with self.assertRaisesRegex(ValueError, 'duplicate key'):
                combine([path])

    def test_partial_output_is_not_reported_as_complete(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'partial.jsonl'
            path.write_text('{"key":')
            with self.assertRaises(json.JSONDecodeError):
                combine([path])


if __name__ == '__main__':
    unittest.main()
