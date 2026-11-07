#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../../.." && pwd)"
  SCRIPT="$REPO_ROOT/dot_agents/scripts/executable_sync-skills.sh"
  TEST_HOME="$(mktemp -d)"
  export HOME="$TEST_HOME"
  SRC="$HOME/.agents/skills"
  DST="$HOME/.claude/skills"
  add_skill alpha
  add_skill beta
}

teardown() {
  rm -rf "${TEST_HOME:-}"
}

add_skill() {
  mkdir -p "$SRC/$1"
  printf '# %s\n' "$1" > "$SRC/$1/SKILL.md"
}

# True when this platform lets us create a real directory symlink.
can_symlink() {
  local probe="$TEST_HOME/.probe"
  mkdir -p "$probe/target"
  MSYS=winsymlinks:nativestrict ln -s "$probe/target" "$probe/link" 2>/dev/null \
    && [[ -L "$probe/link" ]]
}

@test "copy mode copies each skill with a marker" {
  run bash "$SCRIPT" copy
  [ "$status" -eq 0 ]
  [ -f "$DST/alpha/SKILL.md" ]
  [ -f "$DST/beta/SKILL.md" ]
  [ ! -L "$DST/alpha" ]
  [ -f "$DST/alpha/.synced-from-agents" ]
  [[ "$output" == *"copied 2"* ]]
}

@test "defaults to copy mode" {
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [ ! -L "$DST/alpha" ]
  [ -f "$DST/alpha/.synced-from-agents" ]
}

@test "ignores source directories without SKILL.md" {
  mkdir -p "$SRC/not-a-skill"
  run bash "$SCRIPT" copy
  [ "$status" -eq 0 ]
  [ ! -e "$DST/not-a-skill" ]
}

@test "re-running refreshes copies and drops stale files" {
  bash "$SCRIPT" copy
  printf 'updated\n' > "$SRC/alpha/SKILL.md"
  touch "$DST/alpha/stale.md"
  run bash "$SCRIPT" copy
  [ "$status" -eq 0 ]
  [ "$(cat "$DST/alpha/SKILL.md")" = "updated" ]
  [ ! -e "$DST/alpha/stale.md" ]
}

@test "leaves an unmanaged skill with the same name alone" {
  mkdir -p "$DST/alpha"
  printf 'mine\n' > "$DST/alpha/SKILL.md"
  run bash "$SCRIPT" copy
  [ "$status" -eq 0 ]
  [ "$(cat "$DST/alpha/SKILL.md")" = "mine" ]
  [ ! -f "$DST/alpha/.synced-from-agents" ]
  [[ "$output" == *"skipped 1"* ]]
}

@test "prunes managed skills whose source is gone, keeps unmanaged ones" {
  bash "$SCRIPT" copy
  mkdir -p "$DST/claude-only"
  touch "$DST/claude-only/SKILL.md"
  rm -rf "$SRC/beta"
  run bash "$SCRIPT" copy
  [ "$status" -eq 0 ]
  [ ! -e "$DST/beta" ]
  [ -f "$DST/claude-only/SKILL.md" ]
  [[ "$output" == *"pruned 1"* ]]
}

@test "symlink mode links, or copies with a marker where links are refused" {
  run bash "$SCRIPT" symlink
  [ "$status" -eq 0 ]
  [ -f "$DST/alpha/SKILL.md" ]
  if can_symlink; then
    [ -L "$DST/alpha" ]
    [[ "$output" == *"linked 2"* ]]
  else
    [ -f "$DST/alpha/.synced-from-agents" ]
    [[ "$output" == *"copied instead"* ]]
  fi
}

@test "replaces a legacy chezmoi relative symlink" {
  can_symlink || skip "directory symlinks not permitted here"
  mkdir -p "$DST"
  (cd "$DST" && MSYS=winsymlinks:nativestrict ln -s ../../.agents/skills/alpha alpha)
  run bash "$SCRIPT" copy
  [ "$status" -eq 0 ]
  [ ! -L "$DST/alpha" ]
  [ -f "$DST/alpha/.synced-from-agents" ]
  [ -f "$SRC/alpha/SKILL.md" ]
}

@test "switching from symlink to copy mode keeps the source intact" {
  can_symlink || skip "directory symlinks not permitted here"
  bash "$SCRIPT" symlink
  run bash "$SCRIPT" copy
  [ "$status" -eq 0 ]
  [ ! -L "$DST/alpha" ]
  [ -f "$SRC/alpha/SKILL.md" ]
  [ ! -f "$SRC/alpha/.synced-from-agents" ]
}

@test "rejects an unknown mode" {
  run bash "$SCRIPT" hardlink
  [ "$status" -eq 1 ]
  [[ "$output" == *"invalid mode"* ]]
}

@test "fails when the source directory is missing" {
  rm -rf "$HOME/.agents"
  run bash "$SCRIPT" copy
  [ "$status" -eq 1 ]
  [[ "$output" == *"source directory not found"* ]]
}
