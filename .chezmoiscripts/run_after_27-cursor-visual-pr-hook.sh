#!/usr/bin/env bash
# Register visual-pr-hook in ~/.cursor/hooks.json.
# Merges one postToolUse entry; hooks from `work hooks install cursor` and any
# other local entries stay intact.

set -euo pipefail

cursor_dir="${HOME}/.cursor"
cfg="${cursor_dir}/hooks.json"
script="${HOME}/.local/bin/visual-pr-hook"

if [ ! -d "$cursor_dir" ] || [ ! -x "$script" ]; then
  exit 0
fi

if ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

current='{"version": 1, "hooks": {}}'
if [ -f "$cfg" ]; then
  current="$(cat "$cfg")"
fi

# Registering the hook is optional, so a config this script cannot parse must
# not take `chezmoi apply` down with it. Bail out and leave the file alone.
if ! printf '%s' "$current" | jq -e 'type == "object"' >/dev/null 2>&1; then
  exit 0
fi

tmp="$(mktemp)"
# Entries are matched by command so re-applying rewrites in place rather than
# stacking a duplicate hook every time.
if printf '%s' "$current" | jq --arg cmd "$script cursor" '
  .version //= 1
  | .hooks //= {}
  | .hooks.postToolUse = (
      ((.hooks.postToolUse // []) | map(select(.command != $cmd)))
      + [{matcher: "Shell", command: $cmd}]
    )
' >"$tmp" 2>/dev/null; then
  if [ -f "$cfg" ] && cmp -s "$tmp" "$cfg"; then
    rm -f "$tmp"
  else
    mv "$tmp" "$cfg"
  fi
else
  rm -f "$tmp"
fi
