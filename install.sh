#!/usr/bin/env bash
set -euo pipefail

if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
  printf '%s\n' 'Run this script as a command; do not source it.' >&2
  return 1
fi

destdir=""
case "${1:-}" in
  --help|-h)
    printf '%s\n' 'Usage: bash install.sh [--destdir ABSOLUTE_DIRECTORY]' \
      'Install Jedi for the current user. --destdir stages files for package checks.'
    exit 0
    ;;
  --destdir)
    if [[ "$#" != 2 || "${2:-}" != /* || "$2" == / ]]; then
      printf '%s\n' '--destdir requires an absolute staging directory other than /.' >&2
      exit 2
    fi
    destdir="${2%/}"
    ;;
  "") ;;
  *) printf 'Unknown option: %s\n' "$1" >&2; exit 2 ;;
esac
if [[ -z "$destdir" && "$#" != 0 ]]; then
  printf '%s\n' 'Usage: bash install.sh [--destdir ABSOLUTE_DIRECTORY]' >&2
  exit 2
fi
if [[ "$(uname -s)" != Linux || "$(uname -m)" != x86_64 ]]; then
  printf '%s\n' 'This distribution requires Linux x86_64.' >&2
  exit 1
fi

script_dir="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
binary="$script_dir/jedi"
if [[ ! -f "$binary" ]]; then
  binary="$script_dir/build/jedi"
fi
if [[ ! -f "$binary" || ! -x "$binary" ]]; then
  printf 'Jedi binary missing or not executable: %s\n' "$binary" >&2
  printf '%s\n' 'Use the binary release archive, or compile the source first.' >&2
  exit 127
fi
for name in jedi jedidemo jedidev; do
  if [[ ! -f "$script_dir/launchers/$name" ]]; then
    printf 'Required launcher missing: %s\n' "$name" >&2
    exit 1
  fi
done

# Staging preserves the final installation paths without changing HOME.
install_root="$destdir$HOME"
mkdir -p "$install_root/.local/libexec" "$install_root/.local/bin"
install -m 0755 "$binary" "$install_root/.local/libexec/jedi"
for name in jedi jedidemo jedidev; do
  install -m 0755 "$script_dir/launchers/$name" "$install_root/.local/bin/$name"
done
mkdir -p "$install_root/jedi-examples"
for example in "$script_dir"/examples/*.txt; do
  [[ -f "$example" ]] || continue
  target="$install_root/jedi-examples/$(basename -- "$example")"
  if [[ -e "$target" || -L "$target" ]]; then
    printf 'Existing example kept: %s\n' "$target"
  else
    install -m 0644 "$example" "$target"
  fi
done
if [[ -n "$destdir" ]]; then
  printf 'Installation staged in: %s\n' "$destdir"
else
  printf '%s\n' 'Jedi installed for the current user.' \
    'In this terminal, run:' \
    '  export PATH="$HOME/.local/bin:$PATH"' \
    '  hash -r' \
    '  jedidemo config --paths' \
    'Use jedi for production and jedidemo for the supplied fictional examples.'
fi
