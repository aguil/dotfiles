#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../../.." && pwd -P)"
  # shellcheck source=tests/shell/helpers/assert.sh
  source "$REPO_ROOT/tests/shell/helpers/assert.sh"
}

@test "repos hygiene runs through public recipe" {
  run just -f "$REPO_ROOT/repos.just" hygiene

  assert_status 0 "$status"
  assert_contains "$output" "Mode:"
  assert_contains "$output" "Default branch:"
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
