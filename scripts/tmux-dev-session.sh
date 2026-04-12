#!/usr/bin/env bash
set -euo pipefail

# Usage: tmuxdev [layout] [session] [path]
#   layout: web (default), dev
#   session: session name, default = basename of path
#   path: project dir, default PWD

case "${1:-}" in
  dev) LAYOUT="dev"; shift ;;
  web) LAYOUT="web"; shift ;;
  *)   LAYOUT="web" ;;
esac

SESSION_NAME="${1:-}"
PROJECT_DIR="${2:-$PWD}"

# Backward compatibility for legacy tmuxdev wrappers that called:
#   tmux-dev-session.sh <session_name> <project_dir>
# When invoked as `tmuxdev dev`, that legacy wrapper passes the current path as
# SESSION_NAME. If SESSION_NAME looks like a directory path, treat it as
# PROJECT_DIR and derive SESSION_NAME from the basename below.
if [ -n "$SESSION_NAME" ] && [ -d "$SESSION_NAME" ]; then
  PROJECT_DIR="$SESSION_NAME"
  SESSION_NAME=""
fi

if [ -z "$SESSION_NAME" ]; then
  SESSION_NAME=$(basename "$(cd "$PROJECT_DIR" && pwd)")
fi

AI_CMD="${AI_TERM_CMD:-agent}"

if ! command -v tmux >/dev/null 2>&1; then
  echo "tmux is not installed or not in PATH" >&2
  exit 1
fi

if [ ! -d "$PROJECT_DIR" ]; then
  echo "project directory does not exist: $PROJECT_DIR" >&2
  exit 1
fi

if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
  if [ -n "${TMUX:-}" ]; then
    tmux switch-client -t "$SESSION_NAME"
  else
    tmux attach-session -t "$SESSION_NAME"
  fi
  exit 0
fi

if [ "$LAYOUT" = "web" ]; then
  if ! command -v tmuxp >/dev/null 2>&1; then
    echo "tmuxp is required for web layout (Brewfile / linux/pip-packages.txt)" >&2
    exit 1
  fi
  tmuxp_config="${TMUXP_CONFIG:-$HOME/.config/tmuxp/web-dev.yaml}"
  tmp_config=$(mktemp "${TMPDIR:-/tmp}/tmuxp.XXXXXX.yaml")
  sed "s|^session_name: .*|session_name: $SESSION_NAME|" "$tmuxp_config" > "$tmp_config"
  trap 'rm -f "$tmp_config"' EXIT
  (cd "$PROJECT_DIR" && tmuxp load "$tmp_config")
  exit 0
fi

tmux new-session -d -s "$SESSION_NAME" -n editor -c "$PROJECT_DIR"
tmux send-keys -t "$SESSION_NAME":editor.0 "nvim" C-m
tmux split-window -h -t "$SESSION_NAME":editor -c "$PROJECT_DIR"
tmux send-keys -t "$SESSION_NAME":editor.1 "$AI_CMD" C-m
tmux select-pane -t "$SESSION_NAME":editor.0

tmux new-window -t "$SESSION_NAME" -n tests -c "$PROJECT_DIR"
tmux new-window -t "$SESSION_NAME" -n shell -c "$PROJECT_DIR"
tmux select-window -t "$SESSION_NAME":editor

if [ -n "${TMUX:-}" ]; then
  tmux switch-client -t "$SESSION_NAME"
else
  tmux attach-session -t "$SESSION_NAME"
fi
