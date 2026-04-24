#!/usr/bin/env bash
set -euo pipefail

projects_root="${1:?usage: proj-list-types.sh <projects-root> <project>}"
project="${2:?usage: proj-list-types.sh <projects-root> <project>}"

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

find "$project_dir" -mindepth 1 -maxdepth 1 -type d 2>/dev/null |
  while IFS= read -r d; do
    [ -n "${d:-}" ] || continue
    [ -d "$d" ] || continue
    printf '%s\t%s\n' "$(_proj_mtime_sec "$d")" "${d##*/}"
  done | LC_ALL=C sort -t $'\t' -nr -k1,1 | cut -f2-
