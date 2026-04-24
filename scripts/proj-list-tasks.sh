#!/usr/bin/env bash
set -euo pipefail

projects_root="${1:?usage: proj-list-tasks.sh <projects-root> <project> [type]}"
project="${2:?usage: proj-list-tasks.sh <projects-root> <project> [type]}"
type="${3:-}"

project_dir="$projects_root/$project"

if [ ! -d "$project_dir" ]; then
  exit 0
fi

if [ -n "$type" ]; then
  find "$project_dir/$type" -mindepth 1 -maxdepth 1 -type d -printf '%T@ %f\n' 2>/dev/null |
    sort -nr |
    while IFS= read -r line; do
      [ -n "$line" ] || continue
      task_id="${line#* }"
      [ -n "$task_id" ] || continue
      printf '%s/%s\n' "$type" "$task_id"
    done
else
  find "$project_dir" -mindepth 2 -maxdepth 2 -type d -printf '%T@ %P\n' 2>/dev/null |
    sort -nr |
    while IFS= read -r line; do
      [ -n "$line" ] || continue
      rel="${line#* }"
      [ -n "$rel" ] || continue
      printf '%s\n' "$rel"
    done
fi
