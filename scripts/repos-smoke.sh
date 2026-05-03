#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"

if ! command -v just >/dev/null 2>&1; then
  printf 'repos-smoke: missing just in PATH\n' >&2
  exit 1
fi

audit_log="$(mktemp)"
guard_log="$(mktemp)"
trap 'rm -f "$audit_log" "$guard_log"' EXIT

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
