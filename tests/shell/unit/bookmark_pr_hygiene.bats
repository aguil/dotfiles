#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../../.." && pwd -P)"
  SCRIPT="$REPO_ROOT/scripts/bookmark-pr-hygiene.sh"
  TMP_CASE_DIR="$(mktemp -d)"
  MOCK_BIN="$TMP_CASE_DIR/bin"
  mkdir -p "$MOCK_BIN"
  PATH_ORIG="$PATH"
  PATH="$MOCK_BIN:$PATH"
  # shellcheck source=tests/shell/helpers/assert.sh
  source "$REPO_ROOT/tests/shell/helpers/assert.sh"
  # shellcheck source=tests/shell/helpers/bookmark_pr_hygiene_mocks.sh
  source "$REPO_ROOT/tests/shell/helpers/bookmark_pr_hygiene_mocks.sh"
}

teardown() {
  PATH="$PATH_ORIG"
  rm -rf "$TMP_CASE_DIR"
}

@test "classifies landed_on_default in jj mode" {
  export MOCK_COMPARE_STATUS="behind"
  export MOCK_OPEN_COUNT="0"
  export MOCK_MERGED_TOTAL="0"
  export MOCK_MERGED_DEFAULT="0"
  export MOCK_MERGED_DEFAULT_EXACT="0"
  write_gh_mock
  write_jj_mock

  run bash "$SCRIPT" audit

  assert_status 0 "$status"
  assert_contains "$output" "landed_on_default"
  assert_contains "$output" "feat/test"
}

@test "classifies open_pr in git mode" {
  export MOCK_COMPARE_STATUS="ahead"
  export MOCK_OPEN_COUNT="1"
  export MOCK_MERGED_TOTAL="0"
  export MOCK_MERGED_DEFAULT="0"
  export MOCK_MERGED_DEFAULT_EXACT="0"
  write_gh_mock
  write_jj_root_fail_mock
  write_git_mock

  run bash "$SCRIPT" audit

  assert_status 0 "$status"
  assert_contains "$output" "open_pr"
  assert_contains "$output" "open PR exists"
}

@test "classifies landed_via_pr_exact_head when merged head matches" {
  export MOCK_COMPARE_STATUS="ahead"
  export MOCK_OPEN_COUNT="0"
  export MOCK_MERGED_TOTAL="1"
  export MOCK_MERGED_DEFAULT="1"
  export MOCK_MERGED_DEFAULT_EXACT="1"
  write_gh_mock
  write_jj_mock

  run bash "$SCRIPT" audit

  assert_status 0 "$status"
  assert_contains "$output" "landed_via_pr_exact_head"
  assert_contains "$output" "yes"
}

@test "classifies unknown_remote_sha when compare has no status" {
  export MOCK_COMPARE_STATUS=""
  export MOCK_OPEN_COUNT="0"
  export MOCK_MERGED_TOTAL="0"
  export MOCK_MERGED_DEFAULT="0"
  export MOCK_MERGED_DEFAULT_EXACT="0"
  write_gh_mock
  write_jj_root_fail_mock
  write_git_mock

  run bash "$SCRIPT" audit

  assert_status 0 "$status"
  assert_contains "$output" "unknown_remote_sha"
}
