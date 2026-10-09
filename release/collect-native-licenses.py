#!/usr/bin/env python3
"""Collect license notices for the exact native-library versions in Alpine."""

import json
import shutil
import subprocess
from pathlib import Path

from common import ROOT

# Package names, upstream release tags and upstream notice filenames.
SOURCES = {
    "musl": ("https://git.musl-libc.org/git/musl", "v{version}", ["COPYRIGHT"]),
    "gc": ("https://github.com/ivmai/bdwgc.git", "v{version}", ["doc/README.copyright", "LICENSE", "README.md"]),
    "pcre2": ("https://github.com/PCRE2Project/pcre2.git", "pcre2-{version}", ["LICENCE", "LICENCE.md"]),
    "yaml": ("https://github.com/yaml/libyaml.git", "{version}", ["License"]),
    "openssl": ("https://github.com/openssl/openssl.git", "openssl-{version}", ["LICENSE.txt", "NOTICE"]),
    "zlib": ("https://github.com/madler/zlib.git", "v{version}", ["LICENSE"]),
    "libevent": ("https://github.com/libevent/libevent.git", "release-{version}-stable", ["LICENSE"]),
}

# Prefer the packages containing the static libraries linked into the binary.
# Alpine may install those without the corresponding runtime or CLI package.
APK_PACKAGES = {
    "musl": ("musl-dev", "musl"),
    "gc": ("gc-static", "gc"),
    "pcre2": ("pcre2-static", "pcre2"),
    "yaml": ("yaml-static", "yaml"),
    "openssl": ("openssl-libs-static", "openssl", "openssl-dev", "libssl3"),
    "zlib": ("zlib-static", "zlib"),
    "libevent": ("libevent-static", "libevent"),
}


def packages():
    result = {}
    for block in Path("/lib/apk/db/installed").read_text().split("\n\n"):
        fields = dict(line.split(":", 1) for line in block.splitlines() if ":" in line)
        if "P" in fields and "V" in fields:
            result[fields["P"]] = fields["V"]
    return result


installed = packages()
destination = ROOT / "build/static/licenses/native"
cache = ROOT / "build/native-license-sources"
destination.mkdir(parents=True, exist_ok=True)
cache.mkdir(parents=True, exist_ok=True)
manifest = {}
for package, (url, pattern, candidates) in SOURCES.items():
    apk_package = next((name for name in APK_PACKAGES[package] if name in installed), None)
    package_version = installed.get(apk_package)
    if package_version is None:
        # Old and new Crystal runtimes do not link the same event-loop libraries.
        if package == "libevent":
            continue
        raise SystemExit(f"Native package version not found: {package}")
    upstream_version = package_version.rsplit("-r", 1)[0]
    tag = pattern.format(version=upstream_version)
    checkout = cache / f"{package}-{upstream_version}"
    if not checkout.exists():
        subprocess.run(["git", "clone", "--depth", "1", "--branch", tag,
                        url, str(checkout)], check=True)
    found = []
    target = destination / package
    target.mkdir(exist_ok=True)
    for name in candidates:
        source = checkout / name
        if source.is_file():
            shutil.copyfile(source, target / Path(name).name)
            found.append(Path(name).name)
    if not found:
        raise SystemExit(f"No upstream license notice found for {package} {tag}")
    commit = subprocess.check_output(["git", "-C", str(checkout), "rev-parse", "HEAD"], text=True).strip()
    manifest[package] = {"apk_package": apk_package, "apk_version": package_version, "upstream": url,
                         "tag": tag, "commit": commit, "notices": found}

# SQLite's upstream source is in the public domain; no upstream license file exists.
sqlite_package = next((name for name in ("sqlite-static", "sqlite-libs", "sqlite") if name in installed), None)
sqlite_version = installed.get(sqlite_package)
if not sqlite_version:
    raise SystemExit("SQLite package version not found")
sqlite = destination / "sqlite"
sqlite.mkdir(exist_ok=True)
(sqlite / "PUBLIC-DOMAIN.txt").write_text(
    "SQLite\n\nThe SQLite source code is in the public domain.\n"
    "Upstream statement: https://www.sqlite.org/copyright.html\n"
    f"Alpine package version: {sqlite_version}\n")
manifest["sqlite"] = {"apk_package": sqlite_package, "apk_version": sqlite_version,
                       "upstream": "https://www.sqlite.org/copyright.html",
                       "notices": ["PUBLIC-DOMAIN.txt"]}
shutil.copytree(ROOT / "licenses/crystal", destination / "crystal", dirs_exist_ok=True)
(destination / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
print("Native-library license notices collected from matching upstream releases.")
