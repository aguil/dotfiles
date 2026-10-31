#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../../.." && pwd)"
  TEST_HOME="$(mktemp -d)"
  STUB_BIN="$TEST_HOME/bin"
  SOURCE_DIR="$TEST_HOME/source"
  WRAPPER="$TEST_HOME/02-gh-wrapper.sh"

  mkdir -p "$STUB_BIN" "$SOURCE_DIR"
  sed 's/{{ .git.personal.githubUser }}/owner/' \
    "$REPO_ROOT/dot_config/chezmoi/profile.d/02-gh-wrapper.sh.tmpl" >"$WRAPPER"

  # gh reports the config dir it was called with.
  cat >"$STUB_BIN/gh" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$GH_CONFIG_DIR"
EOF
  cat >"$STUB_BIN/chezmoi" <<EOF
#!/usr/bin/env bash
printf '%s\n' "$SOURCE_DIR"
EOF
  # ssh -G resolves the github-alias host to ssh.github.com.
  cat >"$STUB_BIN/ssh" <<'EOF'
#!/usr/bin/env bash
[ "$1" = "-G" ] || exit 1
case "$2" in
  github-alias) printf 'hostname ssh.github.com\n' ;;
  *) printf 'hostname %s\n' "$2" ;;
esac
EOF
  chmod +x "$STUB_BIN/gh" "$STUB_BIN/chezmoi" "$STUB_BIN/ssh"

  git -C "$SOURCE_DIR" init -q
}

teardown() {
  rm -rf "$TEST_HOME"
}

# Runs the wrapper as a work-profile shell would: the default config dir is the
# work account.
run_gh_in() {
  local dir="$1"
  shift
  run env -i HOME="$TEST_HOME" PATH="$STUB_BIN:/usr/bin:/bin" \
    GH_CONFIG_DIR="$TEST_HOME/.config/gh" \
    CHEZMOI_GH_CONFIG_DIR="$TEST_HOME/.config/gh" \
    "$@" bash -c "cd \"$dir\" && source \"$WRAPPER\" && gh api user"
}

@test "chezmoi source with an SSH alias origin uses the personal config" {
  git -C "$SOURCE_DIR" remote add origin git@github-alias:owner/dotfiles.git

  run_gh_in "$SOURCE_DIR"
  [ "$status" -eq 0 ]
  [ "$output" = "$TEST_HOME/.config/gh-personal" ]
}

@test "chezmoi source with an HTTPS GitHub origin uses the personal config" {
  git -C "$SOURCE_DIR" remote add origin https://github.com/owner/dotfiles.git

  run_gh_in "$SOURCE_DIR"
  [ "$status" -eq 0 ]
  [ "$output" = "$TEST_HOME/.config/gh-personal" ]
}

@test "chezmoi source on another forge keeps the default config" {
  git -C "$SOURCE_DIR" remote add origin git@codeberg.org:owner/dotfiles.git

  run_gh_in "$SOURCE_DIR"
  [ "$status" -eq 0 ]
  [ "$output" = "$TEST_HOME/.config/gh" ]
}

@test "personal repo tree uses the personal config" {
  local repo="$TEST_HOME/dev/repos/github.com/owner/project"
  mkdir -p "$repo"

  run_gh_in "$repo"
  [ "$status" -eq 0 ]
  [ "$output" = "$TEST_HOME/.config/gh-personal" ]
}

@test "CHEZMOI_GH_PERSONAL_CONFIG_DIR overrides the personal config" {
  git -C "$SOURCE_DIR" remote add origin git@github-alias:owner/dotfiles.git

  run_gh_in "$SOURCE_DIR" CHEZMOI_GH_PERSONAL_CONFIG_DIR="$TEST_HOME/custom"
  [ "$status" -eq 0 ]
  [ "$output" = "$TEST_HOME/custom" ]
}

@test "gh-routes.d routes win over the personal routes" {
  git -C "$SOURCE_DIR" remote add origin git@github-alias:owner/dotfiles.git
  mkdir -p "$TEST_HOME/.config/chezmoi/gh-routes.d"
  printf 'gh_route "%s" "%s"\n' "$SOURCE_DIR" "$TEST_HOME/.config/gh-work" \
    >"$TEST_HOME/.config/chezmoi/gh-routes.d/work.sh"

  run_gh_in "$SOURCE_DIR"
  [ "$status" -eq 0 ]
  [ "$output" = "$TEST_HOME/.config/gh-work" ]
}
