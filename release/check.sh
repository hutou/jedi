#!/usr/bin/env bash
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CDPATH= cd -- "$script_dir/.."
for program in crystal shards python3 git; do
  command -v "$program" >/dev/null 2>&1 || {
    printf 'Required program not found: %s\n' "$program" >&2
    exit 127
  }
done
mkdir -p build/check
rm -f build/check/result.json
crystal --version | tee build/check/crystal.txt
if ! head -n 1 build/check/crystal.txt | grep -Eq '^Crystal 1\.21\.1([[:space:]]|$)'; then
  printf '%s\n' 'The Jedi 1.0 release procedure requires Crystal 1.21.1.' >&2
  exit 1
fi
shards --version | tee build/check/shards.txt

# Generated palette and Unicode tables are already committed upstream.
shards install --frozen --skip-postinstall 2>&1 | tee build/check/dependencies.txt
python3 release/verify-dependencies.py
TZ=UTC crystal tool format --check src spec 2>&1 | tee build/check/format.txt
TZ=UTC crystal spec --no-color 2>&1 | tee build/check/specs.txt
grep -Eq '493 examples, 0 failures, 0 errors, 0 pending' build/check/specs.txt || {
  printf '%s\n' 'The expected 493-spec release result was not found.' >&2
  exit 1
}
TZ=UTC crystal build src/jedi_cli.cr -o build/check/jedi 2>&1 | tee build/check/compile.txt
python3 - <<'PY'
import json
import sys
from pathlib import Path
sys.path.insert(0, "release")
from common import source_hash
Path("build/check/result.json").write_text(json.dumps({
    "success": True, "source_sha256": source_hash(), "spec_count": 493
}, indent=2) + "\n")
PY
printf '%s\n' 'Source compilation, formatting and all 493 specs passed.'
