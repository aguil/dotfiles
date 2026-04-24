#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
projects_root="${DEV_ROOT:-$HOME/dev}/projects"

if ! command -v just >/dev/null 2>&1; then
  printf 'proj-smoke: missing `just` in PATH\n' >&2
  exit 1
fi

if ! command -v fzf >/dev/null 2>&1; then
  printf 'proj-smoke: missing `fzf` in PATH\n' >&2
  exit 1
fi

project="${1:-}"
if [ -z "$project" ]; then
  while IFS= read -r line; do
    [ -n "${line:-}" ] || continue
    project="$line"
    break
  done < <(bash "$repo_root/scripts/proj-list-projects.sh" "$projects_root")
fi

if [ -z "$project" ]; then
  printf 'proj-smoke: no projects found under %s\n' "$projects_root" >&2
  exit 1
fi

list_out="$(FZF_DEFAULT_OPTS="--filter=$project" just -f "$repo_root/proj.just" list)"
if [ -z "$list_out" ]; then
  printf 'proj-smoke: `proj::list` returned no tasks for project %s\n' "$project" >&2
  exit 1
fi

first_task=''
while IFS= read -r line; do
  [ -n "${line:-}" ] || continue
  first_task="$line"
  break
done <<< "$list_out"

if [ -z "$first_task" ]; then
  printf 'proj-smoke: failed to parse first task path from list output\n' >&2
  exit 1
fi

rel="${first_task#*"/$project/"}"
type="${rel%%/*}"
task_id="${rel#"$type/"}"
task_id="${task_id%%/*}"

if [ -z "$type" ] || [ -z "$task_id" ]; then
  printf 'proj-smoke: failed to parse <type>/<task-id> from %s\n' "$first_task" >&2
  exit 1
fi

FZF_DEFAULT_OPTS="--filter=$project" just -f "$repo_root/proj.just" status >/dev/null
DRY_RUN=1 just -f "$repo_root/proj.just" drop "$project" "$type" "$task_id" >/dev/null

push_log="$(mktemp)"
if DRY_RUN=1 just -f "$repo_root/proj.just" push "$project" "$type" "$task_id" >"$push_log" 2>&1; then
  :
else
  if grep -q 'push: no task.json' "$push_log"; then
    :
  else
    cat "$push_log" >&2
    rm -f "$push_log"
    printf 'proj-smoke: `proj::push` failed unexpectedly\n' >&2
    exit 1
  fi
fi
rm -f "$push_log"

printf 'proj-smoke: ok (%s, %s/%s)\n' "$project" "$type" "$task_id"
