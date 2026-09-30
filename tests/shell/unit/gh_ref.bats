#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../../.." && pwd -P)"
  SCRIPT="$REPO_ROOT/dot_local/bin/executable_gh-ref"
  TMP_CASE_DIR="$(mktemp -d)"
  MOCK_BIN="$TMP_CASE_DIR/bin"
  mkdir -p "$MOCK_BIN"
  PATH_ORIG="$PATH"
  PATH="$MOCK_BIN:$PATH"
  export GH_REF_RETRY_DELAY=0
  export MOCK_CALLS="$TMP_CASE_DIR/calls"
  # shellcheck source=tests/shell/helpers/assert.sh
  source "$REPO_ROOT/tests/shell/helpers/assert.sh"
  write_gh_mock
  write_jj_mock
}

teardown() {
  PATH="$PATH_ORIG"
  rm -rf "$TMP_CASE_DIR"
}

# MOCK_FOUND: the endpoint kind (pulls, issues, stacks) that exists; others 404.
# MOCK_FLAKY: connection errors to return before answering (shared counter).
# MOCK_NO_REPO: when set, `gh repo view` fails as outside a git checkout.
write_gh_mock() {
  cat >"$MOCK_BIN/gh" <<'EOF'
#!/usr/bin/env bash
if [ "$1 $2" = "repo view" ]; then
  [ -n "${MOCK_NO_REPO:-}" ] && exit 1
  echo "owner/cwd-repo"
  exit 0
fi
path="$2"
echo "$path" >>"$MOCK_CALLS"
if [ "$(wc -l <"$MOCK_CALLS")" -le "${MOCK_FLAKY:-0}" ]; then
  echo "error connecting to api.github.com" >&2
  exit 1
fi
kind="$(basename "$(dirname "$path")")"
if [ "$kind" = "${MOCK_FOUND:-}" ]; then
  echo "found $path"
  exit 0
fi
echo '{"message":"Not Found"}'
echo "gh: Not Found (HTTP 404)" >&2
exit 1
EOF
  chmod +x "$MOCK_BIN/gh"
}

write_jj_mock() {
  cat >"$MOCK_BIN/jj" <<'EOF'
#!/usr/bin/env bash
[ -n "${MOCK_JJ_ORIGIN:-}" ] && echo "origin $MOCK_JJ_ORIGIN"
exit 0
EOF
  chmod +x "$MOCK_BIN/jj"
}

@test "a PR number resolves on the first lookup" {
  export MOCK_FOUND=pulls

  run bash "$SCRIPT" 178

  assert_status 0 "$status"
  assert_contains "$output" "found repos/owner/cwd-repo/pulls/178"
  assert_status 1 "$(wc -l <"$MOCK_CALLS")"
}

@test "a stack number falls through pulls and issues to stacks" {
  export MOCK_FOUND=stacks

  run bash "$SCRIPT" '#205'

  assert_status 0 "$status"
  assert_contains "$output" "found repos/owner/cwd-repo/stacks/205"
  assert_contains "$(cat "$MOCK_CALLS")" "issues/205"
}

@test "an unused number exits 1 and names the repo" {
  run bash "$SCRIPT" -R owner/other 999

  assert_status 1 "$status"
  assert_contains "$output" "owner/other has no PR, issue or stack #999"
}

@test "connection errors are retried, not read as missing" {
  export MOCK_FOUND=pulls MOCK_FLAKY=2

  run bash "$SCRIPT" 7

  assert_status 0 "$status"
  assert_contains "$output" "found repos/owner/cwd-repo/pulls/7"
}

@test "persistent connection errors exit 2" {
  export MOCK_FOUND=pulls MOCK_FLAKY=99

  run bash "$SCRIPT" 7

  assert_status 2 "$status"
  assert_contains "$output" "error connecting"
}

@test "a jj workspace without .git falls back to jj's origin" {
  export MOCK_FOUND=pulls MOCK_NO_REPO=1
  export MOCK_JJ_ORIGIN="git@github.com:owner/jj-repo.git"

  run bash "$SCRIPT" 3

  assert_status 0 "$status"
  assert_contains "$output" "found repos/owner/jj-repo/pulls/3"
}

@test "outside any repo without -R is a usage error" {
  export MOCK_NO_REPO=1

  run bash "$SCRIPT" 3

  assert_status 2 "$status"
  assert_contains "$output" "pass -R owner/repo"
}

@test "a non-numeric reference is a usage error" {
  run bash "$SCRIPT" abc

  assert_status 2 "$status"
  assert_contains "$output" "usage: gh-ref"
}
