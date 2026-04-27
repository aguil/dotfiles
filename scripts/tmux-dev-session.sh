#!/usr/bin/env bash
set -euo pipefail

# Usage: tmuxdev [layout] [session] [path]
#   layout: web (default), dev
#   session: session name, default = task-id (multi-repo task) or repo directory name
#   path: project dir, default PWD
#
# Implicit path resolution (unless TMUXDEV_NO_RESOLVE=1):
#   - Git worktrees: normalize to `git rev-parse --show-toplevel`.
#   - Jujutsu: normalize to `jj workspace root` when not inside a git worktree.
#   - Project-task workspaces (DEV_ROOT/projects/<project>/<type>/<task-id>/task.json):
#     multiple checkouts add a "repos" window (web) and task-scoped shells (dev).
#
# Env:
#   TMUXDEV_NO_RESOLVE=1     — skip git/jj normalization and task.json handling.
#   TMUXDEV_RESOLVE_TASK=0   — skip task.json only (still applies VCS resolution).
#   DEV_ROOT                 — project root (default: $HOME/dev).

ORIG_CWD="$(pwd -P)"
DEV_ROOT="${DEV_ROOT:-$HOME/dev}"

case "${1:-}" in
  dev) LAYOUT="dev"; shift ;;
  web) LAYOUT="web"; shift ;;
  *)   LAYOUT="web" ;;
esac

SESSION_NAME="${1:-}"
PROJECT_DIR="${2:-$ORIG_CWD}"

# Legacy: tmux-dev-session.sh <session_name> <project_dir>
if [ -n "$SESSION_NAME" ] && [ -d "$SESSION_NAME" ]; then
  PROJECT_DIR="$SESSION_NAME"
  SESSION_NAME=""
fi

resolve_vcs_root() {
  local d="$1"
  [ -d "$d" ] || { printf '%s\n' "$d"; return 0; }
  if command -v git >/dev/null 2>&1 && git -C "$d" rev-parse --show-toplevel >/dev/null 2>&1; then
    git -C "$d" rev-parse --show-toplevel
    return 0
  fi
  if command -v jj >/dev/null 2>&1; then
    local jr=""
    jr="$(cd "$d" && jj workspace root 2>/dev/null)" || jr=""
    if [ -n "$jr" ] && [ -d "$jr" ]; then
      printf '%s\n' "$jr"
      return 0
    fi
  fi
  printf '%s\n' "$d"
}

find_task_dir() {
  local p="$1"
  local dev_root="$DEV_ROOT"
  while [ -n "$p" ] && [ "$p" != "/" ]; do
    if [ -f "$p/task.json" ]; then
      case "$p" in
        "$dev_root/projects/"?*/?*/?*)
          printf '%s\n' "$p"
          return 0
          ;;
      esac
    fi
    p="$(dirname "$p")"
  done
  return 1
}

MULTI_REPO=0
TASK_DIR=""
PRIMARY_REPO=""
ORDERED_REPOS=()

analyze_task_json() {
  python3 - "$1" "$2" <<'PY'
import json
import os
import sys

task_json = sys.argv[1]
orig = os.path.realpath(sys.argv[2])

if not os.path.isfile(task_json):
    sys.exit(2)

with open(task_json, encoding="utf-8") as f:
    data = json.load(f)

repos = data.get("repos") or {}
base = os.path.dirname(task_json)
paths = []
for name in sorted(repos.keys()):
    p = os.path.join(base, name)
    if os.path.isdir(p):
        paths.append(os.path.realpath(p))

if not paths:
    print("NONE")
    sys.exit(0)

best_i = 0
best_len = -1
for i, p in enumerate(paths):
    if orig == p or orig.startswith(p + os.sep):
        if len(p) > best_len:
            best_len = len(p)
            best_i = i

primary = paths[best_i]
ordered = [primary] + [p for p in paths if p != primary]

if len(paths) >= 2:
    mode = "MULTI"
elif len(paths) == 1:
    mode = "SINGLE"
else:
    mode = "NONE"

print(mode)
print(os.path.dirname(task_json))
print(primary)
for p in ordered:
    print(p)
PY
}

if [ "${TMUXDEV_NO_RESOLVE:-}" != "1" ]; then
  PROJECT_DIR="$(resolve_vcs_root "$PROJECT_DIR")"
fi

if [ "${TMUXDEV_RESOLVE_TASK:-1}" = "1" ] && [ "${TMUXDEV_NO_RESOLVE:-}" != "1" ]; then
  td=""
  if td="$(find_task_dir "$PROJECT_DIR")"; then
    _task_lines=()
    while IFS= read -r _tl; do
      _task_lines+=("$_tl")
    done < <(analyze_task_json "$td/task.json" "$ORIG_CWD")
    _mode="${_task_lines[0]:-}"
    case "$_mode" in
      SINGLE)
        TASK_DIR="${_task_lines[1]}"
        PRIMARY_REPO="${_task_lines[2]}"
        PROJECT_DIR="$PRIMARY_REPO"
        ;;
      MULTI)
        MULTI_REPO=1
        TASK_DIR="${_task_lines[1]}"
        PRIMARY_REPO="${_task_lines[2]}"
        ORDERED_REPOS=()
        _idx=0
        for _tl in "${_task_lines[@]}"; do
          if [ "$_idx" -ge 3 ]; then
            ORDERED_REPOS+=("$_tl")
          fi
          _idx=$((_idx + 1))
        done
        ;;
      NONE | "") ;;
    esac
  fi
fi

if [ -z "$PRIMARY_REPO" ]; then
  PRIMARY_REPO="$PROJECT_DIR"
fi

if [ -z "$SESSION_NAME" ]; then
  if [ "$MULTI_REPO" = "1" ] && [ -n "$TASK_DIR" ]; then
    SESSION_NAME="$(basename "$TASK_DIR")"
  else
    SESSION_NAME=$(basename "$PROJECT_DIR")
  fi
fi

AI_CMD="${AI_TERM_CMD:-agent}"

if ! command -v tmux >/dev/null 2>&1; then
  echo "tmux is not installed or not in PATH" >&2
  exit 1
fi

if [ "$MULTI_REPO" = "1" ]; then
  if [ ! -d "${TASK_DIR:-}" ]; then
    echo "tmuxdev: task directory does not exist: ${TASK_DIR:-}" >&2
    exit 1
  fi
else
  if [ ! -d "$PROJECT_DIR" ]; then
    echo "project directory does not exist: $PROJECT_DIR" >&2
    exit 1
  fi
fi

if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
  if [ -n "${TMUX:-}" ]; then
    tmux switch-client -t "$SESSION_NAME"
  else
    tmux attach-session -t "$SESSION_NAME"
  fi
  exit 0
fi

# Web layout: plain tmux only. tmuxp/libtmux often raises LibTmuxException (e.g.
# "can't find pane: %1") while splitting multi-pane windows on tmux 3.6+.

tmux_layout_web() {
  local s="$SESSION_NAME"
  local root="$PRIMARY_REPO"
  local secondary=()
  local rp si idx bn lc

  tmux new-session -d -s "$s" -n editor -c "$root"
  tmux split-window -v -t "$s:editor.0" -c "$root"
  tmux split-window -h -t "$s:editor.1" -c "$root"
  tmux select-layout -t "$s:editor" tiled
  tmux send-keys -t "$s:editor.0" "nvim" C-m
  tmux send-keys -t "$s:editor.1" 'bash -ic "git st 2>/dev/null || jj st 2>/dev/null; exec bash"' C-m
  tmux send-keys -t "$s:editor.2" 'bash -lc "ls; exec bash"' C-m

  if [ "$MULTI_REPO" = "1" ]; then
    secondary=()
    for rp in "${ORDERED_REPOS[@]}"; do
      [ "$rp" = "$PRIMARY_REPO" ] && continue
      secondary+=("$rp")
    done
    si=0
    while [ "$si" -lt "${#secondary[@]}" ]; do
      rp="${secondary[$si]}"
      if [ "$si" -eq 0 ]; then
        tmux new-window -t "$s" -n repos -c "$rp"
      else
        tmux split-window -v -t "$s:repos.0" -c "$rp"
      fi
      si=$((si + 1))
    done
    if [ "${#secondary[@]}" -gt 0 ]; then
      tmux select-layout -t "$s:repos" tiled
      idx=0
      for rp in "${secondary[@]}"; do
        bn="$(basename "$rp")"
        lc="echo '=== ${bn} ==='; git st 2>/dev/null || jj st 2>/dev/null; exec bash"
        tmux send-keys -t "$s:repos.$idx" "bash -lc $(printf '%q' "$lc")" C-m
        idx=$((idx + 1))
      done
    fi
  fi

  tmux new-window -t "$s" -n runtime -c "$root"
  tmux split-window -v -t "$s:runtime.0" -c "$root"
  tmux split-window -h -t "$s:runtime.0" -c "$root"
  tmux split-window -h -t "$s:runtime.2" -c "$root"
  tmux select-layout -t "$s:runtime" tiled

  tmux new-window -t "$s" -n test -c "$root"
  tmux split-window -h -t "$s:test.0" -c "$root"
  tmux select-layout -t "$s:test" even-horizontal

  tmux new-window -t "$s" -n ops -c "$root"
  tmux split-window -v -t "$s:ops.0" -c "$root"
  tmux split-window -h -t "$s:ops.0" -c "$root"
  tmux split-window -h -t "$s:ops.2" -c "$root"
  tmux select-layout -t "$s:ops" tiled

  tmux select-window -t "$s:0"
}

if [ "$LAYOUT" = "web" ]; then
  tmux_layout_web
  if [ -n "${TMUX:-}" ]; then
    tmux switch-client -t "$SESSION_NAME"
  else
    tmux attach-session -t "$SESSION_NAME"
  fi
  exit 0
fi

# dev layout
if [ "$MULTI_REPO" = "1" ]; then
  _shell_root="$TASK_DIR"
else
  _shell_root="$PROJECT_DIR"
fi

tmux new-session -d -s "$SESSION_NAME" -n editor -c "$PRIMARY_REPO"
tmux send-keys -t "$SESSION_NAME":editor.0 "nvim" C-m
tmux split-window -h -t "$SESSION_NAME":editor -c "$PRIMARY_REPO"
tmux send-keys -t "$SESSION_NAME":editor.1 "$AI_CMD" C-m
tmux select-pane -t "$SESSION_NAME":editor.0

tmux new-window -t "$SESSION_NAME" -n tests -c "$_shell_root"
tmux new-window -t "$SESSION_NAME" -n shell -c "$_shell_root"
tmux select-window -t "$SESSION_NAME":editor

if [ -n "${TMUX:-}" ]; then
  tmux switch-client -t "$SESSION_NAME"
else
  tmux attach-session -t "$SESSION_NAME"
fi
