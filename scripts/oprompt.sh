#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ./scripts/oprompt.sh <name> [--copy]

Examples:
  ./scripts/oprompt.sh commit
  ./scripts/oprompt.sh pr-update --copy
EOF
}

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
  usage >&2
  exit 1
fi

name="$1"
copy="false"

if [ "$#" -eq 2 ]; then
  case "$2" in
    --copy|-c)
      copy="true"
      ;;
    *)
      usage >&2
      exit 1
      ;;
  esac
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
prompt_path="$repo_root/docs/prompts/$name.md"

if [ ! -f "$prompt_path" ]; then
  printf 'Prompt not found: %s\n' "$prompt_path" >&2
  exit 1
fi

copy_file_to_clipboard() {
  local file="$1"

  if command -v pbcopy >/dev/null 2>&1; then
    pbcopy < "$file"
    return 0
  fi

  if command -v clip.exe >/dev/null 2>&1; then
    clip.exe < "$file"
    return 0
  fi

  if command -v wl-copy >/dev/null 2>&1; then
    wl-copy < "$file"
    return 0
  fi

  if command -v xclip >/dev/null 2>&1; then
    xclip -selection clipboard < "$file"
    return 0
  fi

  if command -v xsel >/dev/null 2>&1; then
    xsel --clipboard --input < "$file"
    return 0
  fi

  return 1
}

if [ "$copy" = "true" ]; then
  if ! copy_file_to_clipboard "$prompt_path"; then
    printf 'No clipboard tool found (pbcopy, clip.exe, wl-copy, xclip, xsel).\n' >&2
    exit 1
  fi

  printf "Copied prompt '%s' to clipboard.\n" "$name"
else
  cat "$prompt_path"
fi
