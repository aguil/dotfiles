#!/usr/bin/env bash
set -euo pipefail

# Publish ~/.agents/skills/<name>/ to ~/.claude/skills/<name> so Claude Code
# loads them.
#
# Usage:
#   sync-skills.sh [copy|symlink]
#
# Defaults to copy mode. Symlink mode falls back to copying any skill whose
# link can't be created (e.g. Windows without Developer Mode).
#
# Only entries this script manages are replaced or pruned: symlinks into
# ~/.agents/skills, and copies carrying the marker file below. Anything else
# in ~/.claude/skills is left alone.

MODE="${1:-copy}"
SOURCE_DIR="${HOME}/.agents/skills"
TARGET_DIR="${HOME}/.claude/skills"
MARKER=".synced-from-agents"

# Use ~/ in messages instead of a long absolute $HOME path.
_tilde_path() {
  local p="$1"
  case "$p" in
    "${HOME}/"*) printf '%s' "~/${p#"${HOME}/"}" ;;
    *) printf '%s' "$p" ;;
  esac
}

if [[ "${MODE}" != "copy" && "${MODE}" != "symlink" ]]; then
  printf 'invalid mode: %s\n' "${MODE}" >&2
  printf 'usage: %s [copy|symlink]\n' "$(basename "$0")" >&2
  exit 1
fi

if [[ ! -d "${SOURCE_DIR}" ]]; then
  printf 'skills: source directory not found: %s\n' \
    "$(_tilde_path "${SOURCE_DIR}")" >&2
  exit 1
fi

is_skill_source() {
  [[ -f "$1/SKILL.md" ]]
}

is_managed() {
  local dst="$1"
  if [[ -L "$dst" ]]; then
    case "$(readlink "$dst")" in
      */.agents/skills/* | .agents/skills/*) return 0 ;;
    esac
    return 1
  fi
  [[ -d "$dst" && -f "$dst/${MARKER}" ]]
}

# Git Bash's ln -s silently copies unless MSYS asks for native links;
# nativestrict makes it fail instead, so the copy fallback can take over.
link_skill() {
  local src="$1" dst="$2"
  MSYS=winsymlinks:nativestrict ln -s "$src" "$dst" 2>/dev/null || return 1
  if [[ ! -L "$dst" ]]; then
    rm -rf -- "$dst"
    return 1
  fi
}

copy_skill() {
  local src="$1" dst="$2"
  cp -R "$src" "$dst"
  : > "$dst/${MARKER}"
}

mkdir -p "${TARGET_DIR}"

linked=0
copied=0
fallback=0
skipped=0
pruned=0

shopt -s nullglob

for src in "${SOURCE_DIR}"/*/; do
  src="${src%/}"
  is_skill_source "$src" || continue
  name="$(basename "$src")"
  dst="${TARGET_DIR}/${name}"

  if [[ -e "$dst" || -L "$dst" ]]; then
    if ! is_managed "$dst"; then
      printf 'skipped %s: exists and is not managed by sync-skills\n' \
        "$(_tilde_path "$dst")" >&2
      skipped=$((skipped + 1))
      continue
    fi
    rm -rf -- "$dst"
  fi

  if [[ "${MODE}" == "symlink" ]]; then
    if link_skill "$src" "$dst"; then
      linked=$((linked + 1))
      continue
    fi
    fallback=$((fallback + 1))
  fi
  copy_skill "$src" "$dst"
  copied=$((copied + 1))
done

for dst in "${TARGET_DIR}"/*; do
  name="$(basename "$dst")"
  is_skill_source "${SOURCE_DIR}/${name}" && continue
  is_managed "$dst" || continue
  rm -rf -- "$dst"
  printf 'pruned %s: no longer in %s\n' \
    "$(_tilde_path "$dst")" "$(_tilde_path "${SOURCE_DIR}")"
  pruned=$((pruned + 1))
done

printf 'skills: %s -> %s\n' \
  "$(_tilde_path "${SOURCE_DIR}")" "$(_tilde_path "${TARGET_DIR}")"
printf '  linked %d, copied %d, pruned %d, skipped %d\n' \
  "$linked" "$copied" "$pruned" "$skipped"
if [[ "$fallback" -gt 0 ]]; then
  printf '  symlinks not permitted for %d skill(s); copied instead.\n' \
    "$fallback"
fi
