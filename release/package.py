#!/usr/bin/env python3
"""Create deterministic source, documentation and validated binary archives."""

import argparse
import gzip
import importlib.util
import io
import json
import os
import tarfile
import time
import zipfile
from pathlib import Path

from common import ROOT, ROOT_FILES, public_files, sha256, source_hash, version

# Fixed archive metadata. The same input bytes produce the same archive bytes.
DEFAULT_EPOCH = 1791417600  # 2026-10-08 00:00:00 UTC


def tar_archive(target, prefix, files, epoch):
    with target.open("wb") as output:
        with gzip.GzipFile(filename="", mode="wb", fileobj=output, mtime=epoch) as compressed:
            with tarfile.open(fileobj=compressed, mode="w", format=tarfile.PAX_FORMAT) as archive:
                for relative, source in sorted(files.items()):
                    data = source.read_bytes()
                    entry = tarfile.TarInfo(f"{prefix}/{relative}")
                    entry.size = len(data)
                    entry.mtime = epoch
                    entry.uid = entry.gid = 0
                    entry.uname = entry.gname = "root"
                    entry.mode = 0o755 if source.stat().st_mode & 0o111 else 0o644
                    archive.addfile(entry, io.BytesIO(data))


def zip_archive(target, prefix, files, epoch):
    timestamp = time.gmtime(epoch)[:6]
    with zipfile.ZipFile(target, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for relative, source in sorted(files.items()):
            entry = zipfile.ZipInfo(f"{prefix}/{relative}", timestamp)
            entry.create_system = 3
            mode = 0o755 if source.stat().st_mode & 0o111 else 0o644
            entry.external_attr = (0o100000 | mode) << 16
            entry.compress_type = zipfile.ZIP_DEFLATED
            archive.writestr(entry, source.read_bytes())


def binary_files(binary, info_path, smoke_path):
    spec = importlib.util.spec_from_file_location("check_elf", ROOT / "release/check-elf.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    module.check(binary)
    info = json.loads(info_path.read_text())
    smoke = json.loads(smoke_path.read_text())
    if info["version"] != version() or info["source_sha256"] != source_hash():
        raise ValueError("Source files changed after build verification")
    if info["binary_sha256"] != sha256(binary) or smoke["binary_sha256"] != sha256(binary):
        raise ValueError("Binary does not match the build or target smoke-test evidence")
    if info.get("specs") != "493 examples, 0 failures, 0 errors, 0 pending":
        raise ValueError("A passing 493-spec result is required")
    if any(info.get(field) != "passed" for field in ("format", "cli_compile", "alpine_smoke")):
        raise ValueError("Incomplete build verification")
    if not smoke.get("success") or smoke.get("system") != "Linux" or smoke.get("architecture") != "x86_64":
        raise ValueError("A passing target Linux x86_64 smoke test is required")
    native = ROOT / "build/static/licenses/native"
    if not (native / "manifest.json").is_file():
        raise ValueError("Native-library license notices have not been collected")
    files = {"jedi": binary, "BUILD-INFO.json": info_path, "TARGET-TEST.json": smoke_path}
    for path in public_files():
        relative = path.relative_to(ROOT).as_posix()
        if relative.startswith(("documentation/", "examples/", "launchers/", "pdf/", "reference/", "output/pdf/", "licenses/")):
            files[relative] = path
        elif relative in ROOT_FILES and (relative.endswith(".md") or relative in ("LICENSE", "install.sh")):
            files[relative] = path
        elif relative == "release/dependencies.json":
            files[relative] = path
    for path in native.rglob("*"):
        if path.is_file():
            files["licenses/native/" + path.relative_to(native).as_posix()] = path
    # Build logs are retained by the publisher; binary users receive the results above.
    return files


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--without-binary", action="store_true",
                        help="Prepare source and documentation only; no executable archive")
    parser.add_argument("--binary", type=Path, default=ROOT / "build/static/jedi")
    parser.add_argument("--build-info", type=Path, default=ROOT / "build/static/BUILD-INFO.json")
    parser.add_argument("--target-smoke", type=Path, default=ROOT / "build/smoke-target/result.json")
    parser.add_argument("--output", type=Path, default=ROOT / "dist")
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    if any(output.iterdir()):
        raise ValueError("Output directory must be empty; use a new directory for each release attempt")
    epoch = int(os.environ.get("SOURCE_DATE_EPOCH", DEFAULT_EPOCH))
    if epoch < 315532800:
        raise ValueError("SOURCE_DATE_EPOCH must be 1980 or later for ZIP files")
    all_files = {path.relative_to(ROOT).as_posix(): path for path in public_files()}
    documentation = {relative: path for relative, path in all_files.items()
                     if relative.startswith(("documentation/", "examples/", "launchers/", "pdf/", "output/pdf/", "reference/", "licenses/"))
                     or (relative in ROOT_FILES and (relative.endswith(".md") or relative == "LICENSE"))
                     or relative == "release/dependencies.json"}
    executable = None
    if not args.without_binary:
        # Validate everything before creating any release archive.
        executable = binary_files(args.binary.resolve(), args.build_info.resolve(), args.target_smoke.resolve())
    release_version = version()
    source_name = f"jedi-{release_version}-source"
    tar_archive(output / f"{source_name}.tar.gz", source_name, all_files, epoch)
    docs_name = f"jedi-{release_version}-documentation"
    zip_archive(output / f"{docs_name}.zip", docs_name, documentation, epoch)
    if executable is not None:
        name = f"jedi-{release_version}-linux-x86_64"
        tar_archive(output / f"{name}.tar.gz", name, executable, epoch)
    artifacts = sorted(path for path in output.iterdir() if path.suffix in (".gz", ".zip"))
    sums = "".join(f"{sha256(path)}  {path.name}\n" for path in artifacts)
    (output / "SHA256SUMS").write_text(sums)
    for path in artifacts:
        (output / f"{path.name}.sha256").write_text(f"{sha256(path)}  {path.name}\n")
    print(sums, end="")
    if args.without_binary:
        print("Source and documentation prepared. No executable archive was created.")


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, KeyError, json.JSONDecodeError) as error:
        raise SystemExit(f"Packaging failed: {error}")
