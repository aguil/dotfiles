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
CLAUDE_EXTRAS_GLOB="${HOME}/.agents/rules/claude-*.md"
WORK_OVERLAY="${HOME}/.agents/rules/work-overlay.md"

CLAUDE_TARGET="${HOME}/.claude/CLAUDE.md"
OPENCODE_TARGET="${HOME}/.config/opencode/AGENTS.md"

# Use ~/ in messages instead of a long absolute $HOME path.
_tilde_path() {
  local p="$1"
  case "$p" in
    "${HOME}/"*) printf '%s' "~/${p#"${HOME}/"}" ;;
    *) printf '%s' "$p" ;;
  esac
}

if [[ ! -f "${SOURCE_FILE}" ]]; then
  printf 'source file not found: %s\n' "$(_tilde_path "${SOURCE_FILE}")" >&2
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
  printf 'copied:\n'
  printf '  %s\n' "$(_tilde_path "${SOURCE_FILE}")"
  printf '  -> %s\n' "$(_tilde_path "$target")"
}

publish_symlink() {
  local target="$1"
  mkdir -p "$(dirname "$target")"
  ln -sfn "${SOURCE_FILE}" "$target"
  printf 'symlinked:\n'
  printf '  %s\n' "$(_tilde_path "$target")"
  printf '  -> %s\n' "$(_tilde_path "${SOURCE_FILE}")"
}

# Inline ~/.agents markdown into CLAUDE.md. @-includes would load the same text
# but many Claude clients prompt separately for each referenced path.
write_claude_combined() {
  local target="$1"
  local -n extras_ref="$2"
  local extra

  mkdir -p "$(dirname "$target")"
  {
    printf '%s\n\n' \
      '<!-- sync-global-rules: edit ~/.agents/rules; run just agents-sync -->'
    cat "${SOURCE_FILE}"
    for extra in "${extras_ref[@]}"; do
      printf '\n\n---\n\n## %s\n\n' "$(basename "$extra")"
      cat "$extra"
    done
    printf '\n'
  } > "${target}"
}

publish_claude() {
  local target="$1"
  local extras=()

  if compgen -G "${CLAUDE_EXTRAS_GLOB}" > /dev/null; then
    mapfile -t extras < <(printf "%s\n" ${CLAUDE_EXTRAS_GLOB} | sort)
  fi
  if [[ -f "$WORK_OVERLAY" ]]; then
    extras+=( "$WORK_OVERLAY" )
  fi

  if [[ "${#extras[@]}" -eq 0 ]]; then
    publish_copy "$target"
    return
  fi

  write_claude_combined "$target" extras
  printf 'merged for Claude (%d overlay file(s)):\n' "${#extras[@]}"
  printf '  %s\n' "$(_tilde_path "${SOURCE_FILE}")"
  printf '  -> %s\n' "$(_tilde_path "$target")"
}

if [[ "${MODE}" == "copy" ]]; then
  publish_claude "${CLAUDE_TARGET}"
  publish_copy "${OPENCODE_TARGET}"
else
  if compgen -G "${CLAUDE_EXTRAS_GLOB}" > /dev/null \
    || [[ -f "$WORK_OVERLAY" ]]; then
    printf 'symlink mode: CLAUDE overlays present; using copy for Claude.\n'
    publish_claude "${CLAUDE_TARGET}"
  else
    publish_symlink "${CLAUDE_TARGET}"
  fi
  publish_symlink "${OPENCODE_TARGET}"
fi

printf '\nDone. Mode: %s\n' "${MODE}"
printf 'Claude:   %s\n' "$(_tilde_path "${CLAUDE_TARGET}")"
printf 'OpenCode: %s\n' "$(_tilde_path "${OPENCODE_TARGET}")"
