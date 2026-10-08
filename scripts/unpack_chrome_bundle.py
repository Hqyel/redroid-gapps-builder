#!/usr/bin/env python3
"""Extract a verified Chrome/Trichrome APK bundle without zip-slip or extra files."""
from pathlib import Path, PurePosixPath
import sys
import zipfile

MAX_UNCOMPRESSED_BYTES = 1024 * 1024 * 1024
ALLOWED_DIRS = {"chrome", "trichrome"}


def unpack(archive_path: Path, target_dir: Path) -> None:
    if not zipfile.is_zipfile(archive_path):
        raise ValueError("The supplied bundle is not a ZIP archive")

    files = {}
    total = 0
    with zipfile.ZipFile(archive_path) as archive:
        for info in archive.infolist():
            if info.is_dir():
                continue
            path = PurePosixPath(info.filename)
            if (
                len(path.parts) != 2
                or path.parts[0] not in ALLOWED_DIRS
                or path.suffix.lower() != ".apk"
                or ".." in path.parts
                or info.filename.startswith("/")
            ):
                raise ValueError(f"Invalid bundle entry: {info.filename}")
            if info.filename in files:
                raise ValueError(f"Duplicate bundle entry: {info.filename}")
            if (info.external_attr >> 16) & 0o170000 == 0o120000:
                raise ValueError(f"Symlinks are not allowed: {info.filename}")
            total += info.file_size
            if total > MAX_UNCOMPRESSED_BYTES:
                raise ValueError("The uncompressed APK bundle is too large")
            files[info.filename] = info

        for directory in ALLOWED_DIRS:
            if f"{directory}/base.apk" not in files:
                raise ValueError(f"Missing {directory}/base.apk")

        for name, info in files.items():
            output = target_dir.joinpath(*PurePosixPath(name).parts)
            output.parent.mkdir(parents=True, exist_ok=True)
            with archive.open(info) as source, output.open("wb") as dest:
                while True:
                    chunk = source.read(1024 * 1024)
                    if not chunk:
                        break
                    dest.write(chunk)
            if not zipfile.is_zipfile(output):
                raise ValueError(f"Invalid APK (not ZIP format): {name}")
            print(f"Validated {name} ({info.file_size} bytes)")

    print("Bundle validated. Chrome and Trichrome APK splits are ready.")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit("Usage: unpack_chrome_bundle.py bundle.zip destination-dir")
    try:
        unpack(Path(sys.argv[1]), Path(sys.argv[2]))
    except (ValueError, zipfile.BadZipFile) as exc:
        sys.exit(f"ERROR: {exc}")
