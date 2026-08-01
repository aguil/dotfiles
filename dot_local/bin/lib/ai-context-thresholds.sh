# shellcheck shell=bash
# Shared context-usage thresholds for Cursor CLI + Claude Code statusline/hooks.
#
# Defaults:
#   ~200K windows → yellow 65% / red 85%
#   ~1M windows   → yellow 20% / red 65%
# Override with AI_CTX_YELLOW / AI_CTX_RED (integers).

ai_context_cache_dir() {
  printf '%s\n' "${XDG_CACHE_HOME:-$HOME/.cache}/ai-context-alerts"
}

ai_context_thresholds() {
  local window="${1:-200000}"
  local yellow red

  if [ -n "${AI_CTX_YELLOW:-}" ] && [ -n "${AI_CTX_RED:-}" ]; then
    printf '%s %s\n' "$AI_CTX_YELLOW" "$AI_CTX_RED"
    return 0
  fi

  if [ "$window" -ge 500000 ]; then
    yellow=20
    red=65
  else
    yellow=65
    red=85
  fi

  printf '%s %s\n' "$yellow" "$red"
}

# Prints: green | yellow | red
ai_context_level() {
  local pct="${1:-0}"
  local yellow="${2:-65}"
  local red="${3:-85}"

  if [ "$pct" -ge "$red" ]; then
    printf 'red\n'
  elif [ "$pct" -ge "$yellow" ]; then
    printf 'yellow\n'
  else
    printf 'green\n'
  fi
}

ai_context_level_rank() {
  case "${1:-green}" in
    red) printf '2\n' ;;
    yellow) printf '1\n' ;;
    *) printf '0\n' ;;
  esac
}

# Detect agent from statusline payload shape.
# Prints: claude | cursor
ai_context_detect_agent() {
  local payload="$1"
  if printf '%s' "$payload" | jq -e 'has("cost") or has("rate_limits") or has("exceeds_200k_tokens")' >/dev/null 2>&1; then
    printf 'claude\n'
  else
    printf 'cursor\n'
  fi
}

ai_context_compact_cmd() {
  case "${1:-cursor}" in
    claude) printf '/compact\n' ;;
    *) printf '/summarize\n' ;;
  esac
}

ai_context_session_state_path() {
  local session_id="${1:-unknown}"
  # Keep filenames boring for shell/json tooling.
  session_id="${session_id//\//_}"
  printf '%s/%s.json\n' "$(ai_context_cache_dir)" "$session_id"
}

# Read a field from the session state file; default as $2.
ai_context_state_get() {
  local path="$1"
  local key="$2"
  local default="${3:-}"
  if [ ! -f "$path" ]; then
    printf '%s\n' "$default"
    return 0
  fi
  jq -r --arg key "$key" --arg default "$default" '.[$key] // $default' "$path" 2>/dev/null || printf '%s\n' "$default"
}

# Merge JSON object fields into the session state file.
ai_context_state_merge() {
  local path="$1"
  local patch_json="$2"
  local dir
  dir="$(dirname "$path")"
  mkdir -p "$dir"
  if [ -f "$path" ]; then
    jq -c --argjson patch "$patch_json" '. * $patch' "$path" >"${path}.tmp" && mv "${path}.tmp" "$path"
  else
    printf '%s\n' "$patch_json" >"$path"
  fi
}
