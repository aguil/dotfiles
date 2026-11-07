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

# drop runs `rm -rf`, so these use real (non-dry) runs against a scratch DEV_ROOT and
# check that sibling projects survive each refused path.
drop_fixture() {
  DEV="$TMP_CASE_DIR/dev"
  mkdir -p "$DEV/projects/acme/feat/t1" "$DEV/projects/other/feat/t2"
}

run_drop() {
  local project="$1"
  shift
  run env DEV_ROOT="$DEV" DEV_PROJECT_NAME="$project" just -f "$REPO_ROOT/project_tasks.just" drop "$@"
}

@test "drop refuses project names that leave projects/<project>" {
  drop_fixture
  for name in .. . 'acme/..' 'acme\..'; do
    run_drop "$name"
    assert_status 1 "$status"
    assert_contains "$output" "refusing: bad project name"
  done
  [ -d "$DEV/projects/other/feat/t2" ]
  [ -d "$DEV/projects/acme/feat/t1" ]
}

@test "drop refuses type or task_id that leave the project" {
  drop_fixture
  run_drop acme .. .
  assert_status 1 "$status"
  assert_contains "$output" "refusing: bad type/task_id"
  run_drop acme feat ..
  assert_status 1 "$status"
  assert_contains "$output" "refusing: bad type/task_id"
  [ -d "$DEV/projects/other/feat/t2" ]
  [ -d "$DEV/projects/acme/feat/t1" ]
}

@test "drop refuses repo names that leave the task" {
  drop_fixture
  printf '{"repos":{"../..":"x/y"}}' >"$DEV/projects/acme/feat/t1/task.json"
  run_drop acme feat t1 ../..
  assert_status 1 "$status"
  assert_contains "$output" "refusing: bad repo name"
  [ -d "$DEV/projects/other/feat/t2" ]
  [ -f "$DEV/projects/acme/feat/t1/task.json" ]
}

@test "drop still removes a whole project" {
  drop_fixture
  run_drop acme
  assert_status 0 "$status"
  [ ! -e "$DEV/projects/acme" ]
  [ -d "$DEV/projects/other/feat/t2" ]
}
