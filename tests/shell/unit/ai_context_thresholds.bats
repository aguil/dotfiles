#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../../.." && pwd)"
  LIB="$REPO_ROOT/dot_local/bin/lib/ai-context-thresholds.sh"
  STATUSLINE="$REPO_ROOT/dot_local/bin/executable_ai-statusline"
  CACHE_DIR="$(mktemp -d)"
  export XDG_CACHE_HOME="$CACHE_DIR"
}

teardown() {
  rm -rf "${CACHE_DIR:-}"
}

payload() {
  printf '{"session_id":"%s","model":{"display_name":"Opus"},' "${1:-t}"
  printf '"context_window":{"used_percentage":%s,"context_window_size":%s}}' \
    "${2:-70}" "${3:-200000}"
}

@test "thresholds use window defaults for 200K and 1M classes" {
  run bash -c 'set -euo pipefail; . "$1"; ai_context_thresholds 200000' bash "$LIB"
  [ "$status" -eq 0 ]
  [ "$output" = "65 85" ]

  run bash -c 'set -euo pipefail; . "$1"; ai_context_thresholds 1000000' bash "$LIB"
  [ "$status" -eq 0 ]
  [ "$output" = "20 65" ]
}

@test "integer overrides replace both thresholds" {
  run bash -c \
    'set -euo pipefail; . "$1"; AI_CTX_YELLOW=10 AI_CTX_RED=20 ai_context_thresholds 200000' \
    bash "$LIB"
  [ "$status" -eq 0 ]
  [ "$output" = "10 20" ]
}

@test "non-integer overrides fall back to window defaults" {
  run bash -c \
    'set -euo pipefail; . "$1"; AI_CTX_YELLOW=abc AI_CTX_RED=def ai_context_thresholds 200000' \
    bash "$LIB"
  [ "$status" -eq 0 ]
  [ "$output" = "65 85" ]
}

@test "a non-integer override does not take the statusline down" {
  command -v jq >/dev/null 2>&1 || skip "jq not installed"

  run bash -c 'payload="$1"; shift; printf "%s" "$payload" | AI_CTX_YELLOW=abc AI_CTX_RED=def bash "$1"' \
    bash "$(payload crash 70 200000)" "$STATUSLINE"
  [ "$status" -eq 0 ]
  [[ "$output" != *"jq:"* ]]
  [[ "$output" != *"integer expression expected"* ]]
}

@test "level ranking tolerates non-numeric inputs" {
  run bash -c 'set -euo pipefail; . "$1"; ai_context_level abc 65 85' bash "$LIB"
  [ "$status" -eq 0 ]
  [ "$output" = "green" ]
}

@test "an empty patch never becomes session state" {
  command -v jq >/dev/null 2>&1 || skip "jq not installed"

  run bash -c '
    set -euo pipefail
    . "$1"
    state="$2"
    ai_context_state_merge "$state" ""
    [ -f "$state" ] && exit 1
    exit 0
  ' bash "$LIB" "$CACHE_DIR/empty.json"
  [ "$status" -eq 0 ]
}

@test "a corrupt breadcrumb heals instead of failing forever" {
  command -v jq >/dev/null 2>&1 || skip "jq not installed"

  run bash -c '
    set -euo pipefail
    . "$1"
    state="$2"
    printf "not json at all" >"$state"
    ai_context_state_merge "$state" "{\"ui_alerted\":\"yellow\"}"
    jq -r ".ui_alerted" "$state"
  ' bash "$LIB" "$CACHE_DIR/corrupt.json"
  [ "$status" -eq 0 ]
  [ "$output" = "yellow" ]
  [ ! -f "$CACHE_DIR/corrupt.json.tmp" ]
}

@test "the BEL latch persists across refreshes once state is healthy" {
  command -v jq >/dev/null 2>&1 || skip "jq not installed"

  state="$CACHE_DIR/ai-context-alerts/latch.json"

  printf '%s' "$(payload latch 70 200000)" | bash "$STATUSLINE" >/dev/null
  [ "$(jq -r '.ui_alerted' "$state")" = "yellow" ]

  printf '%s' "$(payload latch 72 200000)" | bash "$STATUSLINE" >/dev/null
  [ "$(jq -r '.ui_alerted' "$state")" = "yellow" ]
}

@test "a session sitting at green writes no breadcrumb" {
  command -v jq >/dev/null 2>&1 || skip "jq not installed"

  printf '%s' "$(payload idle 30 200000)" | bash "$STATUSLINE" >/dev/null
  printf '%s' "$(payload idle 31 200000)" | bash "$STATUSLINE" >/dev/null

  [ ! -f "$CACHE_DIR/ai-context-alerts/idle.json" ]
}

@test "dropping back to green clears the breadcrumb and re-arms alerting" {
  command -v jq >/dev/null 2>&1 || skip "jq not installed"

  state="$CACHE_DIR/ai-context-alerts/drop.json"

  printf '%s' "$(payload drop 70 200000)" | bash "$STATUSLINE" >/dev/null
  [ "$(jq -r '.ui_alerted' "$state")" = "yellow" ]

  # Absence is the green state: no latch, and the Stop hook short-circuits.
  printf '%s' "$(payload drop 10 200000)" | bash "$STATUSLINE" >/dev/null
  [ ! -f "$state" ]

  # A later climb must be able to alert again.
  printf '%s' "$(payload drop 70 200000)" | bash "$STATUSLINE" >/dev/null
  [ "$(jq -r '.ui_alerted' "$state")" = "yellow" ]
}

@test "an unparseable payload degrades instead of erroring out" {
  command -v jq >/dev/null 2>&1 || skip "jq not installed"

  run bash -c 'printf "not json at all" | bash "$1"' bash "$STATUSLINE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ctx"* ]]
  [[ "$output" != *"jq:"* ]]
}

@test "a model display name containing spaces is not split" {
  command -v jq >/dev/null 2>&1 || skip "jq not installed"

  run bash -c '
    printf "%s" "{\"session_id\":\"spaced\",\"model\":{\"display_name\":\"Claude Opus 4\"},\"context_window\":{\"used_percentage\":30,\"context_window_size\":200000}}" \
      | bash "$1"
  ' bash "$STATUSLINE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"[Claude Opus 4]"* ]]
  [[ "$output" == *"30%"* ]]
}
