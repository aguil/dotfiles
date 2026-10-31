#!/usr/bin/env bash
# Register this repo's agent hooks in ~/.cursor/hooks.json.
# Merges one entry per hook; hooks from `work hooks install cursor` and any
# other local entries stay intact.

set -euo pipefail

cursor_dir="${HOME}/.cursor"
cfg="${cursor_dir}/hooks.json"
visual_pr_hook="${HOME}/.local/bin/visual-pr-hook"
self_review_gate="${HOME}/.local/bin/self-review-gate"

if [ ! -d "$cursor_dir" ] || [ ! -x "$visual_pr_hook" ] || [ ! -x "$self_review_gate" ]; then
  exit 0
fi

if ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

current='{"version": 1, "hooks": {}}'
if [ -f "$cfg" ]; then
  current="$(cat "$cfg")"
fi

# Registering the hooks is optional, so a config this script cannot parse must
# not take `chezmoi apply` down with it. Bail out and leave the file alone.
if ! printf '%s' "$current" | jq -e 'type == "object"' >/dev/null 2>&1; then
  exit 0
fi

tmp="$(mktemp)"
# Entries are matched by command so re-applying rewrites in place rather than
# stacking a duplicate hook every time.
if printf '%s' "$current" | jq \
  --arg visual_pr "$visual_pr_hook cursor" \
  --arg gate "$self_review_gate cursor" '
  .version //= 1
  | .hooks //= {}
  | .hooks.postToolUse = (
      ((.hooks.postToolUse // []) | map(select(.command != $visual_pr)))
      + [{matcher: "Shell", command: $visual_pr}]
    )
  | .hooks.beforeShellExecution = (
      ((.hooks.beforeShellExecution // []) | map(select(.command != $gate)))
      + [{command: $gate}]
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
