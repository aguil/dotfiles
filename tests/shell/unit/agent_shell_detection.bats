#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../../.." && pwd)"
  PROFILE_D="$REPO_ROOT/dot_config/chezmoi/profile.d"
  RENDERED_ZOXIDE="$(mktemp)"
  command -v chezmoi >/dev/null 2>&1 || return 0
  chezmoi execute-template \
    <"$PROFILE_D/zoxide-init.sh.tmpl" >"$RENDERED_ZOXIDE"
}

teardown() {
  rm -f "${RENDERED_ZOXIDE:-}"
}

@test "agent env markers skip zoxide when helper function is missing" {
  command -v zoxide >/dev/null 2>&1 || skip "zoxide not installed"
  command -v chezmoi >/dev/null 2>&1 || skip "chezmoi not installed"

  run bash -c '
    set -euo pipefail
    source "$1/00-agent-shell.sh"
    # shellcheck source=/dev/null
    source "$2"
    unset -f _is_agent_shell _chez_agent_shell_active 2>/dev/null || true
    export CURSOR_AGENT=1
    chez_init_zoxide_cd
    declare -f cd 2>/dev/null | grep -q __zoxide && exit 1 || exit 0
  ' bash "$PROFILE_D" "$RENDERED_ZOXIDE"

  [ "$status" -eq 0 ]
}

@test "human shell without agent markers may init zoxide cd" {
  command -v zoxide >/dev/null 2>&1 || skip "zoxide not installed"
  command -v chezmoi >/dev/null 2>&1 || skip "chezmoi not installed"

  run bash -c '
    set -euo pipefail
    source "$1/00-agent-shell.sh"
    # shellcheck source=/dev/null
    source "$2"
    unset CURSOR_AGENT CLAUDECODE CUSTOM_AGENT_SHELL
    chez_init_zoxide_cd
    declare -f cd 2>/dev/null | grep -q __zoxide
  ' bash "$PROFILE_D" "$RENDERED_ZOXIDE"

  [ "$status" -eq 0 ]
}
