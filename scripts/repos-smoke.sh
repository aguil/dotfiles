#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"

if ! command -v just >/dev/null 2>&1; then
  printf 'repos-smoke: missing just in PATH\n' >&2
  exit 1
fi

audit_log="$(mktemp)"
guard_log="$(mktemp)"
mock_dir="$(mktemp -d)"
trap 'rm -f "$audit_log" "$guard_log"; rm -rf "$mock_dir"' EXIT

MOCK_BIN="$mock_dir/bin"
mkdir -p "$MOCK_BIN"
PATH_ORIG="$PATH"
# shellcheck source=tests/shell/helpers/bookmark_pr_hygiene_mocks.sh
source "$repo_root/tests/shell/helpers/bookmark_pr_hygiene_mocks.sh"
activate_bookmark_hygiene_gh_mock

cd "$repo_root"
if just -f "$repo_root/repos.just" hygiene >"$audit_log" 2>&1; then
  :
else
  cat "$audit_log" >&2
  printf 'repos-smoke: repos::hygiene failed unexpectedly\n' >&2
  exit 1
fi

if just -f "$repo_root/repos.just" hygiene-prune >"$guard_log" 2>&1; then
  cat "$guard_log" >&2
  printf 'repos-smoke: repos::hygiene-prune succeeded without CONFIRM=1\n' >&2
  exit 1
fi

if grep -q 'set CONFIRM=1 to execute prune' "$guard_log"; then
  :
else
  cat "$guard_log" >&2
  printf 'repos-smoke: prune guard message missing\n' >&2
  exit 1
fi

printf 'repos-smoke: ok\n'
