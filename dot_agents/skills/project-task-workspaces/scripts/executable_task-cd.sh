#!/usr/bin/env bash
# Usage: eval "$(task-cd.sh <repo-basename>)"
# From anywhere under ~/dev/projects/<project>/<type>/<task>/..., cd to a sibling repo.
set -euo pipefail
target="${1:?usage: task-cd.sh <repo-basename>}"
pwd_abs="$(pwd -P)"
case "$pwd_abs" in
  */dev/projects/*)
    task_dir="$(echo "$pwd_abs" | sed -E 's|(.*/dev/projects/[^/]+/[^/]+/[^/]+)(/.*)?$|\1|')"
    ;;
  *) echo "not inside a project-task workspace" >&2; exit 1 ;;
esac
[[ -d "$task_dir/$target" ]] || { echo "no such repo in task: $target (task_dir=$task_dir)" >&2; exit 1; }
printf 'cd %q\n' "$task_dir/$target"
