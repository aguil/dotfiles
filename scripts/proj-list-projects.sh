#!/usr/bin/env bash
set -euo pipefail

projects_root="${1:?usage: proj-list-projects.sh <projects-root>}"

if [ ! -d "$projects_root" ]; then
  exit 0
fi

find "$projects_root" -mindepth 1 -maxdepth 1 -type d -printf '%T@ %f\n' 2>/dev/null |
  sort -nr |
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    name="${line#* }"
    [ -n "$name" ] || continue
    printf '%s\n' "$name"
  done
