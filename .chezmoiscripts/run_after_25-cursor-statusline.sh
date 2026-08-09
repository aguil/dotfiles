#!/usr/bin/env bash
# Ensure Cursor CLI statusLine points at the shared ai-statusline script.
# Does not rewrite other cli-config.json fields (model/auth/state stay intact).

set -euo pipefail

cfg="${HOME}/.cursor/cli-config.json"
script="${HOME}/.local/bin/ai-statusline"

if [ ! -f "$cfg" ] || [ ! -x "$script" ]; then
  exit 0
fi

if ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

current="$(jq -r '.statusLine.command // empty' "$cfg" 2>/dev/null || true)"
# Compare literal "~/.local/bin/..." in case an older config stored a tilde path.
# shellcheck disable=SC2088
if [ "$current" = "$script" ] || [ "$current" = "~/.local/bin/ai-statusline" ]; then
  exit 0
fi

# Merging a statusLine is optional, so a config this script cannot parse must
# not take `chezmoi apply` down with it. Bail out and leave the file alone.
if ! jq -e 'type == "object"' "$cfg" >/dev/null 2>&1; then
  exit 0
fi

tmp="$(mktemp)"
if jq --arg cmd "$script" '
  .statusLine = {
    "type": "command",
    "command": $cmd,
    "padding": 2
  }
' "$cfg" >"$tmp" 2>/dev/null; then
  mv "$tmp" "$cfg"
else
  rm -f "$tmp"
fi
