#!/usr/bin/env bash
# Claude Code Stop hook: user-visible nudge when context crosses yellow/red.
#
# Depends on ~/.local/bin/ai-statusline writing a per-session breadcrumb under
# $XDG_CACHE_HOME/ai-context-alerts/. Emits systemMessage + terminalSequence
# once per level per session (resets when usage drops back to green).

set -euo pipefail

helper="${HOME}/.local/bin/lib/ai-context-thresholds.sh"
if [ ! -f "$helper" ]; then
  exit 0
fi
# shellcheck source=/dev/null
. "$helper"

input="$(cat)"
session_id="$(printf '%s' "$input" | jq -r '.session_id // "unknown"')"
state_path="$(ai_context_session_state_path "$session_id")"

if [ ! -f "$state_path" ]; then
  exit 0
fi

pct="$(ai_context_state_get "$state_path" pct 0)"
level="$(ai_context_state_get "$state_path" level green)"
yellow="$(ai_context_state_get "$state_path" yellow 65)"
red="$(ai_context_state_get "$state_path" red 85)"
window="$(ai_context_state_get "$state_path" window 200000)"
compact_cmd="$(ai_context_state_get "$state_path" compact_cmd /compact)"
stop_alerted="$(ai_context_state_get "$state_path" stop_alerted green)"

case "$pct" in
  '' | *[!0-9]*) pct=0 ;;
esac

if [ "$level" = "green" ]; then
  exit 0
fi

prev_rank="$(ai_context_level_rank "$stop_alerted")"
cur_rank="$(ai_context_level_rank "$level")"
if [ "$cur_rank" -le "$prev_rank" ]; then
  exit 0
fi

case "$level" in
  red)
    msg="Context at ${pct}% (red ≥${red}% for ${window}-token window). Run ${compact_cmd} soon — auto-compact may be imminent."
    title="Claude Code · context red"
    ;;
  *)
    msg="Context at ${pct}% (yellow ≥${yellow}% for ${window}-token window). Good spot to run ${compact_cmd} before continuing."
    title="Claude Code · context yellow"
    ;;
esac

# OSC 777 desktop notify + BEL (allowlisted via Claude terminalSequence).
seq="$(printf '\033]777;notify;%s;%s\007\a' "$title" "$msg")"

jq -nc --arg msg "$msg" --arg seq "$seq" \
  '{systemMessage:$msg, terminalSequence:$seq}'

ai_context_state_merge "$state_path" "$(jq -nc --arg level "$level" '{stop_alerted:$level}')"
