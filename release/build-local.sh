#!/usr/bin/env bash
set -euo pipefail
script_dir="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CDPATH= cd -- "$script_dir/.."
bash release/check.sh
commit="unknown"
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  commit="$(git rev-parse HEAD)"
fi
JEDI_GIT_COMMIT="$commit" TZ=UTC crystal build src/jedi_cli.cr \
  --release --no-debug -o build/jedi 2>&1 | tee build/check/compile-release.txt
python3 release/smoke.py build/jedi --log-dir build/smoke-local
printf '%s\n' 'Local binary ready: build/jedi' 'Install it with: bash install.sh'
