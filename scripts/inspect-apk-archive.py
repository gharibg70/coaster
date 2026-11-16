import json
import os
import stat
import sys
import zipfile
from pathlib import PurePosixPath

MAX_ARCHIVE_BYTES = 100 * 1024 * 1024
MAX_ENTRIES = 20_000
MAX_TOTAL_UNCOMPRESSED = 512 * 1024 * 1024
MAX_ENTRY_UNCOMPRESSED = 64 * 1024 * 1024
MAX_COMPRESSION_RATIO = 200


def fail(message):
    print(message, file=sys.stderr)
    raise SystemExit(1)


if len(sys.argv) != 2:
    fail("Usage: python3 scripts/inspect-apk-archive.py <apk-path>")

archive = sys.argv[1]
try:
    if os.path.getsize(archive) > MAX_ARCHIVE_BYTES:
        fail("APK exceeds the compressed size limit.")

    with zipfile.ZipFile(archive) as apk:
        infos = apk.infolist()
        if not infos or len(infos) > MAX_ENTRIES:
            fail("APK has an invalid number of archive entries.")

        total_size = 0
        names = []
        seen_names = set()
        for entry in infos:
            if entry.filename in seen_names:
                fail("APK contains duplicate archive paths.")
            seen_names.add(entry.filename)
            path = PurePosixPath(entry.filename)
            if path.is_absolute() or ".." in path.parts or "\\" in entry.filename:
                fail("APK contains an unsafe archive path.")
            if stat.S_ISLNK(entry.external_attr >> 16):
                fail("APK contains a symbolic link entry.")
            if entry.flag_bits & 0x1:
                fail("Encrypted APK entries are not supported.")
            if entry.file_size > MAX_ENTRY_UNCOMPRESSED:
                fail("APK contains an entry above the uncompressed size limit.")
            total_size += entry.file_size
            if total_size > MAX_TOTAL_UNCOMPRESSED:
                fail("APK exceeds the total uncompressed size limit.")
            if entry.file_size and entry.file_size / max(entry.compress_size, 1) > MAX_COMPRESSION_RATIO:
                fail("APK contains an entry above the compression-ratio limit.")
            names.append(entry.filename)

    print(json.dumps({"entries": names, "totalUncompressedBytes": total_size}))
except (OSError, zipfile.BadZipFile, RuntimeError) as error:
    fail(f"APK archive metadata is invalid: {type(error).__name__}.")
