#!/usr/bin/env bash
# Attach a clipboard image to an agent CLI prompt (Cursor, Claude Code) via @path.
#
# Minimal tmux integration: prefix + p runs this with --inject (see dot_tmux.conf).
# Native Ctrl+V / Alt+V in agent still preferred when the terminal passes the key.
#
# WSL: optional ~/.local/bin/wl-paste shim so Cursor agent Ctrl+V can read the
# Windows clipboard when the terminal forwards the key.
#
# Usage:
#   paste-image-agent.sh --inject [pane_id]   # tmux: inject @path into agent prompt
#   paste-image-agent.sh --print-attachment   # print @path to stdout

set -euo pipefail

lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
. "$lib_dir/lib/clipboard-image.sh"

mode=print
target_pane=""

while [ $# -gt 0 ]; do
  case "$1" in
    --inject)
      mode=inject
      shift
      [ $# -gt 0 ] || break
      target_pane="$1"
      shift
      ;;
    --print-attachment | --print)
      mode=print
      shift
      ;;
    -h | --help)
      sed -n '2,14p' "$0"
      exit 0
      ;;
    *)
      printf 'unknown argument: %s\n' "$1" >&2
      exit 2
      ;;
  esac
done

notify() {
  if [ -n "${TMUX:-}" ]; then
    tmux display-message "$1"
  else
    printf '%s\n' "$1" >&2
  fi
}

tmpdir=""
cleanup() {
  if [ -n "$tmpdir" ]; then
    rm -rf "$tmpdir"
  fi
}
trap cleanup EXIT

tmpdir="$(mktemp -d)"
image_path="$tmpdir/clipboard.png"

if ! clipboard_image_fetch_to_file "$image_path"; then
  notify 'clipboard has no image'
  exit 1
fi

attach_path="$(mktemp "${TMPDIR:-/tmp}/cursor-agent-clipboard-XXXXXX.png")"
cp "$image_path" "$attach_path"
trap - EXIT
cleanup

attachment="@${attach_path}"

case "$mode" in
  print)
    printf '%s\n' "$attachment"
    ;;
  inject)
    if [ -z "$target_pane" ]; then
      target_pane="${TMUX_PANE:-}"
    fi
    if [ -z "$target_pane" ] || ! tmux display-message -p -t "$target_pane" '#{pane_id}' >/dev/null 2>&1; then
      printf '%s\n' "$attachment"
      printf 'No tmux pane to inject into; paste the @path above into agent.\n' >&2
      exit 1
    fi
    tmux send-keys -l -t "$target_pane" "$attachment "
    notify "attached image"
    ;;
esac
