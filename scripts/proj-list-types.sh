#!/usr/bin/env bash
set -euo pipefail

projects_root="${1:?usage: proj-list-types.sh <projects-root> <project>}"
project="${2:?usage: proj-list-types.sh <projects-root> <project>}"

project_dir="$projects_root/$project"

if [ ! -d "$project_dir" ]; then
  exit 0
fi

find "$project_dir" -mindepth 1 -maxdepth 1 -type d -printf '%T@ %f\n' 2>/dev/null |
  sort -nr |
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    type_name="${line#* }"
    [ -n "$type_name" ] || continue
    printf '%s\n' "$type_name"
  done
