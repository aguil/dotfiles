#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../../.." && pwd)"
  SCRIPT="$REPO_ROOT/dot_agents/scripts/executable_sync-global-rules.sh"
  TEST_HOME="$(mktemp -d)"
  export HOME="$TEST_HOME"
  RULES="$HOME/.agents/rules"
  CURSOR_RULE="$HOME/.cursor/rules/global-instructions.mdc"
  mkdir -p "$RULES"
  printf '# Global Instructions\n\n- base rule\n' >"$RULES/global-instructions.md"
}

teardown() {
  rm -rf "${TEST_HOME:-}"
}

@test "copy mode publishes Claude and OpenCode copies" {
  run bash "$SCRIPT" copy
  [ "$status" -eq 0 ]
  cmp "$RULES/global-instructions.md" "$HOME/.claude/CLAUDE.md"
  cmp "$RULES/global-instructions.md" "$HOME/.config/opencode/AGENTS.md"
}

@test "skips Cursor when ~/.cursor does not exist" {
  run bash "$SCRIPT" copy
  [ "$status" -eq 0 ]
  [ ! -e "$HOME/.cursor" ]
  [[ "$output" == *"skipped Cursor"* ]]
}

@test "writes an always-applied Cursor user rule" {
  mkdir -p "$HOME/.cursor"
  run bash "$SCRIPT" copy
  [ "$status" -eq 0 ]
  [ "$(sed -n 1p "$CURSOR_RULE")" = "---" ]
  grep -qx 'alwaysApply: true' "$CURSOR_RULE"
  grep -qx -- '- base rule' "$CURSOR_RULE"
}

@test "Cursor rule gets the work overlay but not Claude overlays" {
  mkdir -p "$HOME/.cursor"
  printf -- '- claude only\n' >"$RULES/claude-extra.md"
  printf -- '- work rule\n' >"$RULES/work-overlay.md"
  run bash "$SCRIPT" copy
  [ "$status" -eq 0 ]
  grep -qx -- '- work rule' "$CURSOR_RULE"
  grep -qx -- '- claude only' "$HOME/.claude/CLAUDE.md"
  run grep -q 'claude only' "$CURSOR_RULE"
  [ "$status" -eq 1 ]
}

@test "symlink mode still generates the Cursor rule as a file" {
  mkdir -p "$HOME/.cursor"
  run bash "$SCRIPT" symlink
  [ "$status" -eq 0 ]
  [ -f "$CURSOR_RULE" ]
  [ ! -L "$CURSOR_RULE" ]
}

@test "rejects an unknown mode" {
  run bash "$SCRIPT" bogus
  [ "$status" -eq 1 ]
  [[ "$output" == *"invalid mode"* ]]
}
