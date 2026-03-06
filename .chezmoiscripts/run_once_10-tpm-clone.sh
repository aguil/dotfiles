#!/usr/bin/env bash
set -euo pipefail

TPM_DIR="${HOME}/.tmux/plugins/tpm"

if [ -d "$TPM_DIR" ]; then
  exit 0
fi

if ! command -v git >/dev/null 2>&1; then
  printf 'chezmoi: skipping TPM clone (git not found)\n' >&2
  exit 0
fi

mkdir -p "$(dirname "$TPM_DIR")"
git clone --depth 1 https://github.com/tmux-plugins/tpm "$TPM_DIR"
printf 'chezmoi: cloned TPM to %s\n' "$TPM_DIR"

