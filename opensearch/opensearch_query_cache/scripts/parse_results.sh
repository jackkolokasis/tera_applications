#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
    echo "Usage: $0 <results-root> [csv-output-dir]" >&2
    exit 1
fi

if [ "$#" -eq 2 ]; then
    python3 "${SCRIPT_DIR}/tools/parse_results.py" "$1" -o "$2"
else
    python3 "${SCRIPT_DIR}/tools/parse_results.py" "$1"
fi
