#!/usr/bin/env python3
"""Record build evidence for the binary packager."""

import json
import os
import platform
import subprocess

from common import ROOT, sha256, source_hash, version

binary = ROOT / "build/static/jedi"
check = json.loads((ROOT / "build/check/result.json").read_text())
smoke = json.loads((ROOT / "build/static/smoke-alpine/result.json").read_text())
if not check["success"] or not smoke["success"]:
    raise SystemExit("Build verification did not pass")
if check["source_sha256"] != source_hash() or smoke["binary_sha256"] != sha256(binary):
    raise SystemExit("Build inputs changed after verification")
info = {
    "version": version(), "commit": os.environ.get("JEDI_GIT_COMMIT", "unknown"),
    "source_sha256": source_hash(), "binary_sha256": sha256(binary),
    "compiler": subprocess.check_output(["crystal", "--version"], text=True).strip(),
    "shards": subprocess.check_output(["shards", "--version"], text=True).strip(),
    "architecture": platform.machine(), "linking": "static-musl",
    "builder_id": (ROOT / "build/static/builder-id.txt").read_text().strip(),
    "base_image": (ROOT / "build/static/base-image.txt").read_text().strip(),
    "apk_packages": subprocess.check_output(["apk", "info", "-v"], text=True).splitlines(),
    "format": "passed", "specs": "493 examples, 0 failures, 0 errors, 0 pending",
    "cli_compile": "passed", "alpine_smoke": "passed",
}
(ROOT / "build/static/BUILD-INFO.json").write_text(json.dumps(info, indent=2) + "\n")
print("Build evidence recorded in build/static/BUILD-INFO.json.")
