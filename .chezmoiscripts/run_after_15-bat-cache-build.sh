#!/usr/bin/env bash
set -euo pipefail

bat_bin=
if command -v bat >/dev/null 2>&1; then
  bat_bin=bat
elif command -v batcat >/dev/null 2>&1; then
  bat_bin=batcat
fi
if [ -z "$bat_bin" ]; then
  exit 0
fi

themes_dir="${HOME}/.config/bat/themes"
if [ ! -d "$themes_dir" ] || [ -z "$(find "$themes_dir" -maxdepth 1 -name '*.tmTheme' -print -quit)" ]; then
  exit 0
fi

"$bat_bin" cache --build
