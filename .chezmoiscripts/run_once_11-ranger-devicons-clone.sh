#!/usr/bin/env bash
set -euo pipefail

PLUGIN_DIR="${HOME}/.config/ranger/plugins/ranger_devicons"

if [ -d "$PLUGIN_DIR" ]; then
  exit 0
fi

if ! command -v git >/dev/null 2>&1; then
  printf 'chezmoi: skipping ranger_devicons clone (git not found)\n' >&2
  exit 0
fi

mkdir -p "$(dirname "$PLUGIN_DIR")"
git clone --depth 1 https://github.com/alexanderjeurissen/ranger_devicons "$PLUGIN_DIR"
printf 'chezmoi: cloned ranger_devicons to %s\n' "$PLUGIN_DIR"
