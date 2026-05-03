#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_URL="${REPO_URL:-${CHEZMOI_REPO_URL:-}}"
if [ -z "$REPO_URL" ] && command -v git >/dev/null 2>&1; then
  REPO_URL="$(git -C "$SCRIPT_DIR" remote get-url origin 2>/dev/null || true)"
fi

if [ -z "$REPO_URL" ]; then
  printf '%s\n' "Unable to determine dotfiles repo URL." >&2
  printf '%s\n' "Set REPO_URL (or CHEZMOI_REPO_URL) and rerun." >&2
  printf '%s\n' "Example SSH:   REPO_URL='git@github.com:<user>/dotfiles.git' ./install.sh" >&2
  printf '%s\n' "Example HTTPS: REPO_URL='https://github.com/<user>/dotfiles.git' ./install.sh" >&2
  exit 1
fi

BRANCH="${BRANCH:-}"

if ! command -v chezmoi >/dev/null 2>&1; then
  if command -v brew >/dev/null 2>&1; then
    brew install chezmoi
  else
    if [ -n "$BRANCH" ]; then
      sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply "$REPO_URL" --branch "$BRANCH"
    else
      sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply "$REPO_URL"
    fi
    exit 0
  fi
fi

if [ -n "$BRANCH" ]; then
  chezmoi init --apply "$REPO_URL" --branch "$BRANCH"
else
  chezmoi init --apply "$REPO_URL"
fi
