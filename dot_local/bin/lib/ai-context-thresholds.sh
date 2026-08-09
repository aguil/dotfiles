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

# True for plain non-negative integers only. Callers feed these values to
# `[ -ge ]` and `jq --argjson`, both of which abort the script on anything else.
ai_context_is_int() {
  case "${1:-}" in
    '' | *[!0-9]*) return 1 ;;
    *) return 0 ;;
  esac
}

ai_context_thresholds() {
  local window="${1:-200000}"
  local yellow red

  ai_context_is_int "$window" || window=200000

  if [ "$window" -ge 500000 ]; then
    yellow=20
    red=65
  else
    yellow=65
    red=85
  fi

  # Overrides win only when both are integers. A malformed value used to be
  # echoed straight through into `[ -ge ]` and `jq --argjson`, which killed the
  # statusline under `set -e` and left an empty breadcrumb behind.
  if ai_context_is_int "${AI_CTX_YELLOW:-}" && ai_context_is_int "${AI_CTX_RED:-}"; then
    yellow="$AI_CTX_YELLOW"
    red="$AI_CTX_RED"
  fi

  printf '%s %s\n' "$yellow" "$red"
}

# Prints: green | yellow | red
ai_context_level() {
  local pct="${1:-0}"
  local yellow="${2:-65}"
  local red="${3:-85}"

  ai_context_is_int "$pct" || pct=0
  ai_context_is_int "$yellow" || yellow=65
  ai_context_is_int "$red" || red=85

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
#
# Never fatal: this runs on every statusline refresh, so a bad cache file must
# not take the meter down with it. A corrupt breadcrumb is reset from the
# current patch rather than failing forever and re-ringing BEL each refresh.
ai_context_state_merge() {
  local path="$1"
  local patch_json="${2:-}"
  local dir

  # Callers build the patch as `"$(jq -nc ...)"` in the argument list, where a
  # jq failure does not trip `set -e`. Guard so an empty or truncated patch
  # cannot be written out as state. This is a shell-only test on purpose: the
  # statusline reaches here on refreshes, and spawning jq just to validate was
  # a measurable share of the cost.
  case "$patch_json" in
    '{'*'}') ;;
    *) return 0 ;;
  esac

  dir="${path%/*}"
  [ -d "$dir" ] || mkdir -p "$dir" || return 0

  if [ -f "$path" ] &&
    jq -c --argjson patch "$patch_json" '. * $patch' "$path" >"${path}.tmp" 2>/dev/null; then
    mv "${path}.tmp" "$path"
    return 0
  fi
  rm -f "${path}.tmp"

  # No usable state file. This path is rare, so pay for real validation here
  # rather than letting a malformed patch replace the breadcrumb wholesale.
  if printf '%s' "$patch_json" | jq -e 'type == "object"' >/dev/null 2>&1; then
    printf '%s\n' "$patch_json" >"$path"
  fi
}
