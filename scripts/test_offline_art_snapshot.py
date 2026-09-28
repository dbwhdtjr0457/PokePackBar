import copy
import hashlib
import json
import tempfile
import unittest
import zipfile
from pathlib import Path
from unittest.mock import patch

from offline_art_snapshot import digest, extract, originals, package, restore, validate_distribution


class OfflineArtSnapshotTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.art = self.root / 'art'
        self.art.mkdir()
        images = {}
        for name, data in [('card.png', b'first original'), ('pack.webp', b'pack original')]:
            (self.art / name).write_bytes(data)
            images[name] = dict(file=name, bytes=len(data), sha256=hashlib.sha256(data).hexdigest())
        (self.art / 'private-save.json').write_text('not part of the manifest')
        self.manifest = self.root / 'manifest.json'
        self.manifest.write_text(json.dumps(dict(images=images)))
        self.cache = self.root / 'archives'
        self.index = package(self.manifest, self.art, self.cache, 'https://example.com/release', part_bytes=20)
        self.distribution = self.root / 'distribution.json'
        self.distribution.write_text(json.dumps(self.index))
        self.entries = originals(self.manifest)

    def test_exact_restore_uses_cached_archives_without_network(self):
        output = self.root / 'restored'
        before = self.manifest.read_bytes()
        with patch('urllib.request.urlopen', side_effect=AssertionError('Unexpected network')):
            restore(self.manifest, self.distribution, output, self.cache)
            restore(self.manifest, self.distribution, output, self.cache)
        self.assertEqual(set(p.name for p in output.iterdir()), set(self.entries))
        self.assertEqual(self.manifest.read_bytes(), before)
        for name in self.entries:
            self.assertEqual((output / name).read_bytes(), (self.art / name).read_bytes())

    def test_packaging_excludes_non_manifest_files_and_is_deterministic(self):
        again = package(self.manifest, self.art, self.root/'again', 'https://example.com/release', part_bytes=20)
        self.assertEqual(self.index, again)
        self.assertEqual(len(self.index['assets']), 2)
        for asset in self.index['assets']:
            with zipfile.ZipFile(self.cache / asset['file']) as archive:
                self.assertNotIn('private-save.json', archive.namelist())

    def test_changed_manifest_is_rejected(self):
        self.manifest.write_text(self.manifest.read_text()+' ')
        with self.assertRaisesRegex(ValueError, 'does not match'):
            validate_distribution(self.index, self.manifest, self.entries)

    def test_incomplete_duplicate_and_insecure_distribution_are_rejected(self):
        for mutate in [lambda d: d['assets'].pop(),
                       lambda d: d['assets'].append(d['assets'][0]),
                       lambda d: d['assets'][0].update(url='http://example.com/art.zip')]:
            changed = copy.deepcopy(self.index)
            mutate(changed)
            with self.assertRaises(ValueError):
                validate_distribution(changed, self.manifest, self.entries)

    def test_corrupt_archive_does_not_replace_original(self):
        asset = self.index['assets'][0]
        archive = self.cache / asset['file']
        archive.write_bytes(b'corrupt')
        with self.assertRaisesRegex(ValueError, 'checksum'):
            extract(archive, asset, self.entries, self.art)
        self.assertEqual((self.art / 'card.png').read_bytes(), b'first original')

    def test_unexpected_archive_path_is_rejected(self):
        asset = copy.deepcopy(self.index['assets'][0])
        archive = self.cache / asset['file']
        with zipfile.ZipFile(archive, 'w') as bad:
            bad.writestr('../escape.png', b'bad')
        asset.update(bytes=archive.stat().st_size, sha256=digest(archive))
        with self.assertRaisesRegex(ValueError, 'Unsafe'):
            extract(archive, asset, self.entries, self.art)
        self.assertFalse((self.root / 'escape.png').exists())

    def test_changed_original_is_rejected_during_packaging(self):
        (self.art / 'card.png').write_bytes(b'changed')
        with self.assertRaisesRegex(ValueError, 'Changed original'):
            package(self.manifest, self.art, self.root/'bad', 'https://example.com/release')


if __name__ == '__main__':
    unittest.main()
