#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../../.." && pwd)"
  HOOK="$REPO_ROOT/dot_local/bin/executable_visual-pr-hook"
  MERGE="$REPO_ROOT/.chezmoiscripts/run_after_27-cursor-visual-pr-hook.sh"
  TEST_HOME="$(mktemp -d)"
  export HOME="$TEST_HOME"
  mkdir -p "$HOME/.agents/skills/visual-pr"
  touch "$HOME/.agents/skills/visual-pr/SKILL.md"
}

teardown() {
  rm -rf "${TEST_HOME:-}"
}

event() {
  jq -n --arg command "$1" '{tool_name: "Bash", tool_input: {command: $command}}'
}

run_hook() {
  run bash -c 'event_json="$1"; printf "%s" "$event_json" | bash "$2" "$3"' \
    bash "$(event "$1")" "$HOOK" "${2:-claude}"
}

install_hook_binary() {
  mkdir -p "$HOME/.local/bin" "$HOME/.cursor"
  touch "$HOME/.local/bin/visual-pr-hook"
  chmod +x "$HOME/.local/bin/visual-pr-hook"
}

@test "claude format returns PostToolUse additional context" {
  run_hook 'gh pr create --draft --title x'
  [ "$status" -eq 0 ]
  [ "$(jq -r '.hookSpecificOutput.hookEventName' <<<"$output")" = "PostToolUse" ]
  [[ "$(jq -r '.hookSpecificOutput.additionalContext' <<<"$output")" == *"visual-pr skill"* ]]
}

@test "cursor format returns additional_context" {
  run_hook 'gh pr create --title x' cursor
  [ "$status" -eq 0 ]
  [[ "$(jq -r '.additional_context' <<<"$output")" == *"visual-pr skill"* ]]
}

@test "message tells the agent to keep existing PR content" {
  run_hook 'gh pr create --title x'
  [ "$status" -eq 0 ]
  [[ "$(jq -r '.hookSpecificOutput.additionalContext' <<<"$output")" == *"existing PR body content"* ]]
}

@test "cursor tool_input may be a JSON-encoded string" {
  input='{"tool_name":"Shell","tool_input":"{\"command\":\"gh pr create\"}"}'
  run bash -c 'printf "%s" "$1" | bash "$2" cursor' bash "$input" "$HOOK"
  [ "$status" -eq 0 ]
  [[ "$output" == *additional_context* ]]
}

@test "matches PR commands in compound and prefixed forms" {
  local command
  for command in \
    'gh pr new' \
    'fj pr create title' \
    'command gh pr create' \
    'GH_HOST=github.com gh pr create' \
    'gh -R owner/repo pr create' \
    'jj git push -b x && gh pr create --fill' \
    'cd /tmp; gh pr create'; do
    run_hook "$command"
    [ "$status" -eq 0 ]
    [ -n "$output" ]
  done
}

@test "matches a PR command on a later line" {
  run_hook "$(printf 'jj git push\ngh pr create --fill')"
  [ "$status" -eq 0 ]
  [ -n "$output" ]
}

@test "ignores commands that do not open a PR" {
  local command
  for command in \
    'gh pr view 12' \
    'gh pr edit 12 --body-file x' \
    'gh pr create --help' \
    'gh pr create --web' \
    'gh pr create --dry-run' \
    'echo "gh pr create"' \
    "rg 'gh pr create' docs" \
    'git commit -m "docs: gh pr create notes"' \
    'high pr create'; do
    run_hook "$command"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
  done
}

@test "stays silent when the skill is not installed" {
  rm "$HOME/.agents/skills/visual-pr/SKILL.md"
  run_hook 'gh pr create'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "stays silent on malformed input and unknown formats" {
  run bash -c 'printf "not json" | bash "$1" claude' bash "$HOOK"
  [ "$status" -eq 0 ]
  [ -z "$output" ]

  run bash -c 'printf "{}" | bash "$1" other' bash "$HOOK"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "cursor merge keeps existing hooks and does not duplicate" {
  install_hook_binary
  cat >"$HOME/.cursor/hooks.json" <<'JSON'
{"version": 1, "hooks": {
  "postToolUse": [{"command": "./hooks/work-event.sh"}],
  "stop": [{"command": "./hooks/work-event.sh"}]
}}
JSON

  run bash "$MERGE"
  [ "$status" -eq 0 ]
  run bash "$MERGE"
  [ "$status" -eq 0 ]

  cfg="$HOME/.cursor/hooks.json"
  [ "$(jq '.hooks.postToolUse | length' "$cfg")" -eq 2 ]
  [ "$(jq -r '.hooks.postToolUse[0].command' "$cfg")" = "./hooks/work-event.sh" ]
  [ "$(jq -r '.hooks.postToolUse[1].matcher' "$cfg")" = "Shell" ]
  [ "$(jq -r '.hooks.postToolUse[1].command' "$cfg")" = "$HOME/.local/bin/visual-pr-hook cursor" ]
  [ "$(jq '.hooks.stop | length' "$cfg")" -eq 1 ]
}

@test "cursor merge creates a missing hooks.json" {
  install_hook_binary
  run bash "$MERGE"
  [ "$status" -eq 0 ]
  [ "$(jq -r '.version' "$HOME/.cursor/hooks.json")" = "1" ]
  [ "$(jq '.hooks.postToolUse | length' "$HOME/.cursor/hooks.json")" -eq 1 ]
}

@test "cursor merge leaves an unparseable hooks.json alone" {
  install_hook_binary
  printf 'not json' >"$HOME/.cursor/hooks.json"
  run bash "$MERGE"
  [ "$status" -eq 0 ]
  [ "$(cat "$HOME/.cursor/hooks.json")" = "not json" ]
}

@test "cursor merge does nothing without a Cursor directory" {
  mkdir -p "$HOME/.local/bin"
  touch "$HOME/.local/bin/visual-pr-hook"
  chmod +x "$HOME/.local/bin/visual-pr-hook"
  run bash "$MERGE"
  [ "$status" -eq 0 ]
  [ ! -e "$HOME/.cursor" ]
}
