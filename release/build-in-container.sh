#!/usr/bin/env bash
set -euo pipefail
script_dir="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CDPATH= cd -- "$script_dir/.."
bash release/check.sh
TZ=UTC crystal build src/jedi_cli.cr --release --static --no-debug --verbose \
  -o build/static/jedi 2>&1 | tee build/static/compile.txt
python3 release/check-elf.py build/static/jedi
python3 release/smoke.py build/static/jedi --graphics --log-dir build/static/smoke-alpine
python3 release/collect-native-licenses.py
python3 release/build-info.py
printf '%s\n' 'Static build and Alpine smoke test passed.'
