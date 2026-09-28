#!/usr/bin/env python3
"""Package or restore exact card originals without changing the art manifest.

Only manifest-listed image files enter the archives. No caches, sidecars or
personal state are published. Python's standard library is sufficient to restore.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import tempfile
import time
import urllib.request
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / 'Sources/PokePackBar/Resources/card-art.json'
DISTRIBUTION = ROOT / 'scripts/offline-art-distribution.json'
ART = ROOT / 'local-assets/CardArt'
CACHE = ROOT / 'local-assets/artwork-distribution'
CHUNK_BYTES = 1024 * 1024
PART_BYTES = 1024 ** 3


def safe_name(name):
    if (not isinstance(name, str) or not name or name in {'.', '..'}
            or '/' in name or '\\' in name or any(ord(c) < 32 for c in name)):
        raise ValueError(f'Unsafe image/archive filename: {name!r}')
    return name


def digest(path):
    value = hashlib.sha256()
    with path.open('rb') as stream:
        for chunk in iter(lambda: stream.read(CHUNK_BYTES), b''):
            value.update(chunk)
    return value.hexdigest()


def matches(path, entry):
    return (path.is_file() and not path.is_symlink()
            and path.stat().st_size == entry['bytes'] and digest(path) == entry['sha256'])


def originals(manifest):
    entries = {}
    for image in json.loads(manifest.read_text())['images'].values():
        name = safe_name(image['file'])
        if name in entries or image['bytes'] <= 0:
            raise ValueError(f'Duplicate or empty original: {name}')
        entries[name] = image
    if not entries:
        raise ValueError('Empty art manifest')
    return entries


def package(manifest, art, output, base_url, part_bytes=PART_BYTES):
    entries = originals(manifest)
    output.mkdir(parents=True, exist_ok=True)
    groups, current, total = [], [], 0
    for name, entry in sorted(entries.items()):
        if current and total + entry['bytes'] > part_bytes:
            groups.append(current)
            current, total = [], 0
        current.append(name)
        total += entry['bytes']
    if current:
        groups.append(current)
    assets = []
    for number, names in enumerate(groups, 1):
        filename = f'card-art-{number:02d}-of-{len(groups):02d}.zip'
        destination = output / filename
        with tempfile.NamedTemporaryFile(dir=output, suffix='.zip', delete=False) as temporary:
            temp_path = Path(temporary.name)
        try:
            with zipfile.ZipFile(temp_path, 'w', compression=zipfile.ZIP_STORED) as archive:
                for name in names:
                    entry = entries[name]
                    source = art / name
                    if source.is_symlink():
                        raise ValueError(f'Symlink is not an original: {name}')
                    data = source.read_bytes()
                    if len(data) != entry['bytes'] or hashlib.sha256(data).hexdigest() != entry['sha256']:
                        raise ValueError(f'Changed original: {name}')
                    info = zipfile.ZipInfo(name, date_time=(1980, 1, 1, 0, 0, 0))
                    info.external_attr = 0o100644 << 16
                    archive.writestr(info, data)
            if temp_path.stat().st_size >= 2 * 1024 ** 3:
                raise ValueError('Archive exceeds the release asset limit')
            temp_path.replace(destination)
        finally:
            temp_path.unlink(missing_ok=True)
        asset = dict(file=filename, bytes=destination.stat().st_size,
                     sha256=digest(destination), url=base_url.rstrip('/')+'/'+filename,
                     images=names)
        assets.append(asset)
        print(f'Packaged {filename}: {len(names)} images, {asset["bytes"]} bytes', flush=True)
    return dict(version=1, manifestSHA256=digest(manifest), imageCount=len(entries),
                originalBytes=sum(e['bytes'] for e in entries.values()), assets=assets)


def validate_distribution(distribution, manifest, entries):
    if distribution.get('version') != 1 or distribution.get('manifestSHA256') != digest(manifest):
        raise ValueError('Distribution does not match this checked-in art manifest')
    seen, archives = set(), set()
    for asset in distribution['assets']:
        filename = safe_name(asset['file'])
        if filename in archives or not 0 < asset['bytes'] < 2 * 1024 ** 3:
            raise ValueError('Duplicate or oversized archive')
        if not asset['url'].startswith('https://') or not asset['images']:
            raise ValueError('Expected an HTTPS archive with image entries')
        archives.add(filename)
        for name in asset['images']:
            safe_name(name)
            if name in seen or name not in entries:
                raise ValueError(f'Duplicate or unexpected image: {name}')
            seen.add(name)
    if (seen != set(entries) or distribution['imageCount'] != len(entries)
            or distribution['originalBytes'] != sum(e['bytes'] for e in entries.values())):
        raise ValueError('Incomplete distribution')


def download(asset, cache):
    cache.mkdir(parents=True, exist_ok=True)
    target = cache / safe_name(asset['file'])
    if matches(target, asset):
        return target
    if not asset['url'].startswith('https://'):
        raise ValueError('Only HTTPS downloads are supported')
    for attempt in range(3):
        with tempfile.NamedTemporaryFile(dir=cache, suffix='.part', delete=False) as temporary:
            temp_path = Path(temporary.name)
        try:
            request = urllib.request.Request(asset['url'], headers={'User-Agent': 'PokePackBar-art-snapshot/1'})
            with urllib.request.urlopen(request, timeout=60) as response, temp_path.open('wb') as stream:
                if response.status != 200 or not response.geturl().startswith('https://'):
                    raise ValueError('Unexpected download response')
                received = 0
                while chunk := response.read(CHUNK_BYTES):
                    received += len(chunk)
                    if received > asset['bytes']:
                        raise ValueError('Download exceeds expected archive size')
                    stream.write(chunk)
            if not matches(temp_path, asset):
                raise ValueError(f'Archive checksum mismatch: {asset["file"]}')
            temp_path.replace(target)
            return target
        except Exception:
            if attempt == 2:
                raise
            time.sleep(attempt + 1)
        finally:
            temp_path.unlink(missing_ok=True)
    raise RuntimeError('Download failed')


def extract(archive_path, asset, entries, art):
    if not matches(archive_path, asset):
        raise ValueError('Archive checksum mismatch before extraction')
    art.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(archive_path) as archive:
        infos = archive.infolist()
        names = [safe_name(info.filename) for info in infos]
        if len(names) != len(set(names)) or set(names) != set(asset['images']):
            raise ValueError('Archive contains unexpected or duplicate files')
        for info in infos:
            entry = entries[info.filename]
            if info.file_size != entry['bytes'] or info.is_dir() or (info.external_attr >> 16) & 0o170000 == 0o120000:
                raise ValueError(f'Unexpected archive entry: {info.filename}')
            target = art / info.filename
            if matches(target, entry):
                continue
            data = archive.read(info)
            if hashlib.sha256(data).hexdigest() != entry['sha256']:
                raise ValueError(f'Original checksum mismatch: {info.filename}')
            with tempfile.NamedTemporaryFile(dir=art, suffix='.part', delete=False) as temporary:
                temp_path = Path(temporary.name)
            try:
                temp_path.write_bytes(data)
                temp_path.replace(target)
            finally:
                temp_path.unlink(missing_ok=True)


def restore(manifest, distribution_path, art, cache):
    entries = originals(manifest)
    distribution = json.loads(distribution_path.read_text())
    validate_distribution(distribution, manifest, entries)
    missing = {name for name, entry in entries.items() if not matches(art / name, entry)}
    if missing:
        art.mkdir(parents=True, exist_ok=True)
        needed = [a for a in distribution['assets'] if missing.intersection(a['images'])]
        # Reserve room for the final originals plus the needed archive downloads.
        reserve = sum(entries[n]['bytes'] for n in missing) + sum(a['bytes'] for a in needed)
        if shutil.disk_usage(art).free < reserve + 256 * 1024 ** 2:
            raise ValueError(f'At least {reserve / 1024**3:.1f} GiB free space is required')
        for asset in needed:
            print(f'Restoring {asset["file"]} ({len(asset["images"])} images)', flush=True)
            extract(download(asset, cache), asset, entries, art)
    if any(not matches(art / name, entry) for name, entry in entries.items()):
        raise ValueError('Restored artwork failed final verification')
    print(f'PASS exact artwork snapshot: {len(entries)} images; manifest unchanged', flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command', choices=['package', 'restore'])
    parser.add_argument('--art-dir', type=Path, default=ART)
    parser.add_argument('--cache-dir', type=Path, default=CACHE)
    parser.add_argument('--base-url', help='HTTPS release download prefix, for packaging only')
    args = parser.parse_args()
    if args.command == 'restore':
        restore(MANIFEST, DISTRIBUTION, args.art_dir, args.cache_dir)
        return
    if not args.base_url or not args.base_url.startswith('https://'):
        parser.error('Packaging requires --base-url https://...')
    result = package(MANIFEST, args.art_dir, args.cache_dir, args.base_url)
    DISTRIBUTION.write_text(json.dumps(result, indent=2, sort_keys=True)+'\n')
    print(f'Distribution index: {DISTRIBUTION}')


if __name__ == '__main__':
    main()
