#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../../.." && pwd)"
  RENDERED="$(mktemp)"
}

teardown() {
  rm -f "$RENDERED"
}

render_profile_snippet() {
  local profile="$1"
  CHEZMOI_PROFILE="$profile" chezmoi execute-template \
    <"$REPO_ROOT/dot_config/chezmoi/profile.d/01-gh-default-config.sh.tmpl" \
    >"$RENDERED"
}

@test "personal profile exports gh-personal for subprocess gh" {
  command -v chezmoi >/dev/null 2>&1 || skip "chezmoi not installed"
  render_profile_snippet personal

  run bash -c "source \"$RENDERED\"; printf '%s' \"\$GH_CONFIG_DIR\""
  [ "$status" -eq 0 ]
  [[ "$output" == *"/.config/gh-personal" ]]
}

@test "work profile template branch targets default gh config dir" {
  grep -Fq 'eq .profile "work"' \
    "$REPO_ROOT/dot_config/chezmoi/profile.d/01-gh-default-config.sh.tmpl"
  grep -Fq '$HOME/.config/gh}' \
    "$REPO_ROOT/dot_config/chezmoi/profile.d/01-gh-default-config.sh.tmpl"
}

@test "subprocess command gh inherits exported GH_CONFIG_DIR" {
  command -v chezmoi >/dev/null 2>&1 || skip "chezmoi not installed"
  render_profile_snippet personal

  run bash -c "source \"$RENDERED\"; env | rg '^GH_CONFIG_DIR='"
  [ "$status" -eq 0 ]
  [[ "$output" == GH_CONFIG_DIR=*gh-personal ]]
}
