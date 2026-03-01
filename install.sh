#!/usr/bin/env bash

set -euo pipefail

REPO_URL="git@github.com:aguil/dotfiles.git"
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
