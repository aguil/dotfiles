#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../../.." && pwd -P)"
  TMP_CASE_DIR="$(mktemp -d)"
  MOCK_BIN="$TMP_CASE_DIR/bin"
  mkdir -p "$MOCK_BIN"
  PATH_ORIG="$PATH"
  # shellcheck source=tests/shell/helpers/assert.sh
  source "$REPO_ROOT/tests/shell/helpers/assert.sh"
  # shellcheck source=tests/shell/helpers/bookmark_pr_hygiene_mocks.sh
  source "$REPO_ROOT/tests/shell/helpers/bookmark_pr_hygiene_mocks.sh"
}

teardown() {
  PATH="$PATH_ORIG"
  rm -rf "$TMP_CASE_DIR"
}

@test "repos hygiene runs through public recipe" {
  activate_bookmark_hygiene_gh_mock
  run just -f "$REPO_ROOT/repos.just" hygiene

  assert_status 0 "$status"
  assert_contains "$output" "Mode:"
  assert_contains "$output" "Default branch:"
}

@test "repos hygiene uses invocation directory not justfile directory" {
  activate_bookmark_hygiene_gh_mock
  cd "$REPO_ROOT/tests/shell"
  run just -f "$REPO_ROOT/repos.just" hygiene

  assert_status 0 "$status"
  assert_contains "$output" "Mode:"
}

@test "repos hygiene-prune guard blocks without CONFIRM" {
  run just -f "$REPO_ROOT/repos.just" hygiene-prune

  assert_status 1 "$status"
  assert_contains "$output" "set CONFIRM=1 to execute prune"
}

@test "proj module remains discoverable via list" {
  run just -f "$REPO_ROOT/proj.just" --list

  assert_status 0 "$status"
  assert_contains "$output" "add project type task_id *repos"
  assert_contains "$output" "push project=\"\" type=\"\" task_id=\"\" *repos"
}
