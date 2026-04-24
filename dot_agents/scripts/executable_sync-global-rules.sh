#!/usr/bin/env bash
set -euo pipefail

# Publish canonical global rules to vendor-specific global instruction paths.
#
# Usage:
#   sync-global-rules.sh [copy|symlink]
#   sync-global-rules.sh copy
#   sync-global-rules.sh symlink
#
# Defaults to copy mode.

MODE="${1:-copy}"
SOURCE_FILE="${HOME}/.agents/rules/global-instructions.md"

CLAUDE_TARGET="${HOME}/.claude/CLAUDE.md"
OPENCODE_TARGET="${HOME}/.config/opencode/AGENTS.md"

if [[ ! -f "${SOURCE_FILE}" ]]; then
  printf 'source file not found: %s\n' "${SOURCE_FILE}" >&2
  exit 1
fi

if [[ "${MODE}" != "copy" && "${MODE}" != "symlink" ]]; then
  printf 'invalid mode: %s\n' "${MODE}" >&2
  printf 'usage: %s [copy|symlink]\n' "$(basename "$0")" >&2
  exit 1
fi

publish_copy() {
  local target="$1"
  mkdir -p "$(dirname "$target")"
  cp "${SOURCE_FILE}" "$target"
  printf 'copied: %s -> %s\n' "${SOURCE_FILE}" "$target"
}

publish_symlink() {
  local target="$1"
  mkdir -p "$(dirname "$target")"
  ln -sfn "${SOURCE_FILE}" "$target"
  printf 'symlinked: %s -> %s\n' "$target" "${SOURCE_FILE}"
}

if [[ "${MODE}" == "copy" ]]; then
  publish_copy "${CLAUDE_TARGET}"
  publish_copy "${OPENCODE_TARGET}"
else
  publish_symlink "${CLAUDE_TARGET}"
  publish_symlink "${OPENCODE_TARGET}"
fi

printf '\nDone. Mode: %s\n' "${MODE}"
printf 'Claude:   %s\n' "${CLAUDE_TARGET}"
printf 'OpenCode: %s\n' "${OPENCODE_TARGET}"
