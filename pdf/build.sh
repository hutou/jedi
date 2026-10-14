#!/usr/bin/env bash
set -euo pipefail

if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
    printf '%s\n' 'Run this script as a command; do not source it.' >&2
    return 1
fi

language="${1:-both}"
if [[ "$#" -gt 1 || ! "$language" =~ ^(fr|en|both)$ ]]; then
    printf 'Usage: %s [fr|en|both]\n' "$0" >&2
    exit 2
fi

for program in pandoc xelatex; do
    if ! command -v "$program" >/dev/null 2>&1; then
        printf 'Required program not found: %s\n' "$program" >&2
        exit 127
    fi
done

script_dir="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CDPATH= cd -- "$script_dir/.."
mkdir -p output/pdf

if [[ "$language" == fr || "$language" == both ]]; then
    printf '%s\n' 'Building the French manual...'
    pandoc --defaults=pdf/fr.yaml --resource-path=.:documentation/nouveaux
fi
if [[ "$language" == en || "$language" == both ]]; then
    printf '%s\n' 'Building the English manual...'
    pandoc --defaults=pdf/en.yaml --resource-path=.:documentation/nouveaux
fi
printf '%s\n' 'PDF generation completed. Files are in output/pdf/.'
