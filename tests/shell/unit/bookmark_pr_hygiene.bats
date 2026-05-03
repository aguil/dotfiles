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
}

teardown() {
  PATH="$PATH_ORIG"
  rm -rf "$TMP_CASE_DIR"
}

write_gh_mock() {
  cat >"$MOCK_BIN/gh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [ "$1" = "repo" ] && [ "$2" = "view" ]; then
  has_default=0
  for arg in "$@"; do
    if [ "$arg" = "defaultBranchRef" ]; then has_default=1; fi
  done
  if [ "$has_default" -eq 1 ]; then
    printf '%s\n' "${MOCK_DEFAULT_BRANCH:-master}"
  else
    printf '%s\n' "${MOCK_REPO:-aguil/dotfiles}"
  fi
  exit 0
fi

if [ "$1" = "pr" ] && [ "$2" = "list" ]; then
  state=""
  has_base=0
  has_oid=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --state) state="$2"; shift ;;
      --json)
        case "$2" in
          *baseRefName*) has_base=1 ;;
          *headRefOid*) has_oid=1 ;;
        esac
        shift
        ;;
    esac
    shift
  done
  if [ "$state" = "open" ]; then
    printf '%s\n' "${MOCK_OPEN_COUNT:-0}"
    exit 0
  fi
  if [ "$state" = "merged" ]; then
    if [ "$has_oid" -eq 1 ]; then
      printf '%s\n' "${MOCK_MERGED_DEFAULT_EXACT:-0}"
      exit 0
    fi
    if [ "$has_base" -eq 1 ]; then
      printf '%s\n' "${MOCK_MERGED_DEFAULT:-0}"
      exit 0
    fi
    printf '%s\n' "${MOCK_MERGED_TOTAL:-0}"
    exit 0
  fi
fi

if [ "$1" = "api" ]; then
  if [ -n "${MOCK_COMPARE_STATUS:-}" ]; then
    printf '%s\n' "$MOCK_COMPARE_STATUS"
  fi
  exit 0
fi

printf 'unexpected gh invocation: %s\n' "$*" >&2
exit 1
EOF
  chmod +x "$MOCK_BIN/gh"
}

write_jj_mock() {
  cat >"$MOCK_BIN/jj" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

cmd="${1:-}"
case "$cmd" in
  root)
    printf '%s\n' "${MOCK_JJ_ROOT:-/tmp/jj-root}"
    ;;
  bookmark)
    sub="${2:-}"
    case "$sub" in
      list)
        printf 'master: abcdef123456 base\n'
        printf '%s: %s feature\n' "${MOCK_HEAD_NAME:-feat/test}" "${MOCK_HEAD_SHA:-111111111111}"
        ;;
      *) exit 1 ;;
    esac
    ;;
  log)
    printf '%s\n' "${MOCK_HEAD_SHA:-111111111111}"
    ;;
  git)
    sub="${2:-}"
    case "$sub" in
      remote)
        printf 'origin git@github.com:aguil/dotfiles.git\n'
        ;;
      *) exit 1 ;;
    esac
    ;;
  *)
    exit 1
    ;;
esac
EOF
  chmod +x "$MOCK_BIN/jj"
}

write_git_mock() {
  cat >"$MOCK_BIN/git" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

cmd="${1:-}"
case "$cmd" in
  rev-parse)
    case "${2:-}" in
      --is-inside-work-tree)
        printf 'true\n'
        ;;
      --show-toplevel)
        printf '%s\n' "${MOCK_GIT_ROOT:-/tmp/git-root}"
        ;;
      --git-dir)
        printf '.git\n'
        ;;
      --git-common-dir)
        printf '.git\n'
        ;;
      *) exit 1 ;;
    esac
    ;;
  for-each-ref)
    printf 'master\tabcdef123456\n'
    printf '%s\t%s\n' "${MOCK_HEAD_NAME:-feat/test}" "${MOCK_HEAD_SHA:-111111111111}"
    ;;
  remote)
    if [ "${2:-}" = "get-url" ]; then
      printf 'git@github.com:aguil/dotfiles.git\n'
    else
      exit 1
    fi
    ;;
  *)
    exit 1
    ;;
esac
EOF
  chmod +x "$MOCK_BIN/git"
}

write_jj_root_fail_mock() {
  cat >"$MOCK_BIN/jj" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [ "${1:-}" = "root" ]; then
  exit 1
fi

exit 1
EOF
  chmod +x "$MOCK_BIN/jj"
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
