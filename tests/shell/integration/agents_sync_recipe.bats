#!/usr/bin/env bats

# agents-sync must find its scripts both from the chezmoi source (source names next
# to the Justfile) and from the applied ~/Justfile (scripts under ~/.agents/scripts).
# Stub scripts stand in for the real ones so nothing outside TMP_CASE_DIR is written.

setup() {
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../../.." && pwd -P)"
  TMP_CASE_DIR="$(mktemp -d)"
  # shellcheck source=tests/shell/helpers/assert.sh
  source "$REPO_ROOT/tests/shell/helpers/assert.sh"
}

teardown() {
  rm -rf "$TMP_CASE_DIR"
}

# Copy the Justfile and the modules it loads into $1.
justfile_copy() {
  mkdir -p "$1"
  cp "$REPO_ROOT/Justfile" "$REPO_ROOT/proj.just" "$REPO_ROOT/repos.just" "$1/"
}

# Write a stub script at $1 that reports its label ($2) and mode.
stub() {
  mkdir -p "$(dirname "$1")"
  printf 'echo "ran %s mode=$1"\n' "$2" >"$1"
}

@test "agents-sync runs source-named scripts from the chezmoi source" {
  src="$TMP_CASE_DIR/src"
  justfile_copy "$src"
  stub "$src/dot_agents/scripts/executable_sync-global-rules.sh" src-rules
  stub "$src/dot_agents/scripts/executable_sync-skills.sh" src-skills

  HOME="$TMP_CASE_DIR/empty-home" run just -f "$src/Justfile" agents-sync

  assert_status 0 "$status"
  assert_contains "$output" "ran src-rules mode=copy"
  assert_contains "$output" "ran src-skills mode=copy"
}

@test "agents-sync runs applied scripts from ~/Justfile" {
  home="$TMP_CASE_DIR/home"
  justfile_copy "$home"
  stub "$home/.agents/scripts/sync-global-rules.sh" home-rules
  stub "$home/.agents/scripts/sync-skills.sh" home-skills

  HOME="$home" run just -f "$home/Justfile" agents-sync symlink

  assert_status 0 "$status"
  assert_contains "$output" "ran home-rules mode=symlink"
  assert_contains "$output" "ran home-skills mode=symlink"
}

@test "agents-sync stops before running anything when a script is missing" {
  home="$TMP_CASE_DIR/home"
  justfile_copy "$home"
  stub "$home/.agents/scripts/sync-global-rules.sh" home-rules

  HOME="$home" run just -f "$home/Justfile" agents-sync

  assert_status 1 "$status"
  assert_contains "$output" "agents-sync: missing script sync-skills.sh"
  [[ "$output" != *"ran home-rules"* ]]
}
