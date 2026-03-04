#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
INPUT_FILE="$REPO_ROOT/linux/apt-packages.txt"

if [ ! -f "$INPUT_FILE" ]; then
    echo "missing package list: $INPUT_FILE"
    exit 1
fi

if ! command -v apt-get >/dev/null 2>&1; then
    echo "apt-get not found"
    exit 1
fi

mapfile -t packages < <(grep -Ev '^\s*(#|$)' "$INPUT_FILE")

if [ ${#packages[@]} -eq 0 ]; then
    echo "no packages to install"
    exit 0
fi

sudo apt-get update
sudo apt-get install -y "${packages[@]}"
