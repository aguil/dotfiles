#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
OUTPUT_FILE="$REPO_ROOT/linux/apt-packages.txt"

if ! command -v apt-mark >/dev/null 2>&1; then
    echo "skip apt export (apt-mark not found)"
    exit 0
fi

apt-mark showmanual | sort > "$OUTPUT_FILE"
echo "export apt packages -> $OUTPUT_FILE"
