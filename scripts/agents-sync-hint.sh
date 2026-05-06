#!/usr/bin/env bash
# Hint when ~/.agents rules are newer than published vendor copies.
# Used by chezmoi run_after (chezmoi-apply) and shell rc (shell-once).
set -euo pipefail

SOURCE_FILE="${HOME}/.agents/rules/global-instructions.md"
CLAUDE_TARGET="${HOME}/.claude/CLAUDE.md"
OPENCODE_TARGET="${HOME}/.config/opencode/AGENTS.md"

mtime_of() {
  local f="$1"
  if [[ ! -e "$f" ]]; then
    printf '0\n'
    return
  fi
  if stat -f %m "$f" >/dev/null 2>&1; then
    stat -f %m "$f"
  else
    stat -c %Y "$f" 2>/dev/null || printf '0\n'
  fi
}

source_max_mtime() {
  local max=0
  local m f

  if [[ -f "$SOURCE_FILE" ]]; then
    m="$(mtime_of "$SOURCE_FILE")"
    [[ "$m" -gt "$max" ]] && max="$m"
  fi

  shopt -s nullglob
  local extras=( "${HOME}/.agents/rules/claude-"*.md )
  shopt -u nullglob
  for f in "${extras[@]}"; do
    [[ -f "$f" ]] || continue
    m="$(mtime_of "$f")"
    [[ "$m" -gt "$max" ]] && max="$m"
  done

  printf '%s\n' "$max"
}

needs_agents_sync() {
  [[ -f "$SOURCE_FILE" ]] || return 1

  local src_max
  src_max="$(source_max_mtime)"
  [[ "$src_max" -gt 0 ]] || return 1

  local any=0
  local t mt
  for t in "$CLAUDE_TARGET" "$OPENCODE_TARGET"; do
    if [[ ! -f "$t" ]]; then
      continue
    fi
    any=1
    mt="$(mtime_of "$t")"
    if [[ "$mt" -lt "$src_max" ]]; then
      return 0
    fi
  done

  # No published copies yet — skip (never synced, or Claude/OpenCode unused).
  [[ "$any" -eq 0 ]] && return 1

  return 1
}

print_hint() {
  printf '\nagent rules: ~/.agents/rules are newer than published vendor\n' >&2
  printf 'copies. Run `just agents-sync` from your chezmoi source\n' >&2
  printf '(refreshes Claude and OpenCode).\n\n' >&2
}

mode="${1:-}"
case "$mode" in
  chezmoi-apply | shell-once)
    if needs_agents_sync; then
      print_hint
    fi
    ;;
  *)
    printf 'usage: %s chezmoi-apply|shell-once\n' "$(basename "$0")" >&2
    exit 2
    ;;
esac
