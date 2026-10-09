"""Shared release helpers; no third-party Python packages are required."""

import hashlib
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ROOT_FILES = (
    "README.md", "README.fr.md", "LICENSE", "THIRD-PARTY.md",
    "INSTALL.md", "INSTALL.fr.md", "BUILD.md", "BUILD.fr.md",
    "CHANGELOG.md", "CHANGELOG.fr.md", "PUBLISHING.md", "PUBLISHING.fr.md",
    "CONTRIBUTING.md", "shard.yml", "shard.lock", "install.sh",
    ".gitignore", ".gitattributes", ".dockerignore",
)
PUBLIC_DIRS = (
    "src", "spec", "launchers", "examples", "documentation", "pdf",
    "reference", "output/pdf", "licenses", "release", ".github",
)


def version():
    match = re.search(r"^version:\s*([0-9]+\.[0-9]+\.[0-9]+)\s*$",
                      (ROOT / "shard.yml").read_text(), re.M)
    if not match:
        raise ValueError("No release version found in shard.yml")
    return match.group(1)


def sha256(path):
    digest = hashlib.sha256()
    with Path(path).open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def public_files():
    files = set()
    for name in ROOT_FILES:
        path = ROOT / name
        if path.is_file():
            files.add(path)
    for name in PUBLIC_DIRS:
        for path in (ROOT / name).rglob("*"):
            if not path.is_file():
                continue
            relative = path.relative_to(ROOT)
            if any(part in ("__pycache__", ".git", "anciens", "editorial")
                   for part in relative.parts):
                continue
            if path.suffix in (".pyc", ".db", ".conf", ".log"):
                continue
            if path.is_symlink():
                raise ValueError(f"Public source file is a symlink: {relative}")
            files.add(path)
    return sorted(files, key=lambda path: path.relative_to(ROOT).as_posix())


def source_hash():
    digest = hashlib.sha256()
    for path in public_files():
        digest.update(path.relative_to(ROOT).as_posix().encode() + b"\0")
        digest.update(sha256(path).encode() + b"\n")
    return digest.hexdigest()
