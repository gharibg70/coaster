#!/usr/bin/env python3
import json, os, posixpath, sys, zipfile

MAX_COMPRESSED = 50 * 1024 * 1024
MAX_UNCOMPRESSED = 200 * 1024 * 1024
MAX_RATIO = 1000


def fail(message):
    print(message, file=sys.stderr)
    raise SystemExit(1)

if len(sys.argv) != 2:
    fail('Usage: inspect-ios-archive.py <ipa>')
archive = os.path.abspath(sys.argv[1])
if not os.path.isfile(archive):
    fail('IPA file does not exist.')
if os.path.getsize(archive) > MAX_COMPRESSED:
    fail('IPA compressed-size limit exceeded.')
try:
    with zipfile.ZipFile(archive) as zf:
        infos = zf.infolist()
        names = [info.filename for info in infos]
        if len(names) != len(set(names)):
            fail('duplicate archive paths are not allowed.')
        for info in infos:
            name = info.filename.replace('\\', '/')
            if name.startswith('/') or name == '..' or name.startswith('../') or '/..' in name.split('/'):
                fail('unsafe archive path detected.')
            normalized_name = posixpath.normpath(name.rstrip('/')) + ('/' if name.endswith('/') else '')
            if normalized_name != name or '\x00' in name or '..' in name.split('/'):
                fail('unsafe archive path detected.')
            if info.file_size > MAX_UNCOMPRESSED:
                fail('IPA entry-size limit exceeded.')
            if info.compress_size == 0 and info.file_size:
                fail('compression-ratio limit exceeded.')
            if info.compress_size and info.file_size / info.compress_size > MAX_RATIO:
                fail('compression-ratio limit exceeded.')
        total = sum(info.file_size for info in infos)
        if total > MAX_UNCOMPRESSED:
            fail('IPA uncompressed-size limit exceeded.')
        print(json.dumps({'entries': names}, ensure_ascii=False))
except zipfile.BadZipFile:
    fail('IPA ZIP archive preflight failed.')
