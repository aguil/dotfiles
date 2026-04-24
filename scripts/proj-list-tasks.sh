#!/usr/bin/env bash
set -euo pipefail

projects_root="${1:?usage: proj-list-tasks.sh <projects-root> <project> [type]}"
project="${2:?usage: proj-list-tasks.sh <projects-root> <project> [type]}"
type="${3:-}"

project_dir="$projects_root/$project"

if [ ! -d "$project_dir" ]; then
  exit 0
fi

_proj_mtime_sec() {
  if stat --version >/dev/null 2>&1; then
    stat -c '%Y' "$1" 2>/dev/null || printf '0'
  else
    stat -f '%m' "$1" 2>/dev/null || printf '0'
  fi
}

if [ -n "$type" ]; then
  find "$project_dir/$type" -mindepth 1 -maxdepth 1 -type d 2>/dev/null |
    while IFS= read -r d; do
      [ -n "${d:-}" ] || continue
      [ -d "$d" ] || continue
      task_id="${d##*/}"
      [ -n "$task_id" ] || continue
      printf '%s\t%s/%s\n' "$(_proj_mtime_sec "$d")" "$type" "$task_id"
    done | LC_ALL=C sort -t $'\t' -nr -k1,1 | cut -f2-
else
  find "$project_dir" -mindepth 2 -maxdepth 2 -type d 2>/dev/null |
    while IFS= read -r d; do
      [ -n "${d:-}" ] || continue
      [ -d "$d" ] || continue
      rel="${d#"$project_dir"/}"
      [ -n "$rel" ] || continue
      printf '%s\t%s\n' "$(_proj_mtime_sec "$d")" "$rel"
    done | LC_ALL=C sort -t $'\t' -nr -k1,1 | cut -f2-
fi
