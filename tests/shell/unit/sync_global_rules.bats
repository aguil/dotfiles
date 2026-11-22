#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../../.." && pwd)"
  SCRIPT="$REPO_ROOT/dot_agents/scripts/executable_sync-global-rules.sh"
  TEST_HOME="$(mktemp -d)"
  export HOME="$TEST_HOME"
  RULES="$HOME/.agents/rules"
  CURSOR_RULE="$HOME/.cursor/rules/global-instructions.mdc"
  CLAUDE_RULE="$HOME/.claude/rules/global-instructions.md"
  CLAUDE_LEGACY="$HOME/.claude/CLAUDE.md"
  mkdir -p "$RULES"
  printf '# Global Instructions\n\n- base rule\n' >"$RULES/global-instructions.md"
}

teardown() {
  rm -rf "${TEST_HOME:-}"
}

@test "copy mode publishes Claude and OpenCode copies" {
  run bash "$SCRIPT" copy
  [ "$status" -eq 0 ]
  cmp "$RULES/global-instructions.md" "$CLAUDE_RULE"
  cmp "$RULES/global-instructions.md" "$HOME/.config/opencode/AGENTS.md"
  [ ! -e "$CLAUDE_LEGACY" ]
}

@test "removes an old generated ~/.claude/CLAUDE.md" {
  mkdir -p "$HOME/.claude"
  cp "$RULES/global-instructions.md" "$CLAUDE_LEGACY"
  run bash "$SCRIPT" copy
  [ "$status" -eq 0 ]
  [ ! -e "$CLAUDE_LEGACY" ]
  [ -f "$CLAUDE_RULE" ]
  [[ "$output" == *"removed old copy"* ]]
}

@test "removes an old copy made before the source was edited" {
  mkdir -p "$HOME/.claude"
  cp "$RULES/global-instructions.md" "$CLAUDE_LEGACY"
  printf -- '- newer rule\n' >>"$RULES/global-instructions.md"
  run bash "$SCRIPT" copy
  [ "$status" -eq 0 ]
  [ ! -e "$CLAUDE_LEGACY" ]
}

@test "removes an old merged ~/.claude/CLAUDE.md" {
  mkdir -p "$HOME/.claude"
  printf '%s\n\nold merged text\n' \
    '<!-- sync-global-rules: edit ~/.agents/rules; run just agents-sync -->' \
    >"$CLAUDE_LEGACY"
  run bash "$SCRIPT" copy
  [ "$status" -eq 0 ]
  [ ! -e "$CLAUDE_LEGACY" ]
}

@test "removes an old symlinked ~/.claude/CLAUDE.md and keeps the source" {
  mkdir -p "$HOME/.claude"
  ln -s "$RULES/global-instructions.md" "$CLAUDE_LEGACY"
  run bash "$SCRIPT" copy
  [ "$status" -eq 0 ]
  [ ! -L "$CLAUDE_LEGACY" ]
  [ -f "$RULES/global-instructions.md" ]
}

@test "leaves a hand-written ~/.claude/CLAUDE.md alone" {
  mkdir -p "$HOME/.claude"
  printf '# My notes\n\n- mine\n' >"$CLAUDE_LEGACY"
  run bash "$SCRIPT" copy
  [ "$status" -eq 0 ]
  [ "$(sed -n 1p "$CLAUDE_LEGACY")" = "# My notes" ]
  [[ "$output" == *"not a copy this script wrote"* ]]
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
  grep -qx -- '- claude only' "$CLAUDE_RULE"
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
