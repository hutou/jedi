#!/usr/bin/env python3
"""Verify the exact upstream files used by the Jedi 1.0 release."""

import json
from pathlib import Path

from common import ROOT, sha256

lock = json.loads((ROOT / "release/dependencies.json").read_text())
failures = []
for name, entry in lock["shards"].items():
    directory = ROOT / "lib" / name
    for relative, expected in entry["files"].items():
        path = directory / relative
        if not path.is_file() or sha256(path) != expected:
            failures.append(f"{name}/{relative}")
    print(f"{name} {entry['version']} / {entry['commit']}")
if failures:
    raise SystemExit("Dependency verification failed:\n" + "\n".join(failures))
print("All locked dependency files match their recorded upstream revisions.")
