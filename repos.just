set shell := ["bash", "-eu", "-o", "pipefail", "-c"]

default:
  @just -f "{{ justfile_directory() }}/repos.just" --list

# Audit branch/bookmark PR hygiene in the current repo.
hygiene *args:
  @set -euo pipefail; \
  _jd="{{ justfile_directory() }}"; \
  script="$_jd/scripts/bookmark-pr-hygiene.sh"; \
  if [ ! -f "$script" ]; then \
    _cz="$(chezmoi source-path 2>/dev/null || true)"; \
    if [ -n "$_cz" ] && [ -f "$_cz/scripts/bookmark-pr-hygiene.sh" ]; then script="$_cz/scripts/bookmark-pr-hygiene.sh"; fi; \
  fi; \
  if [ ! -f "$script" ]; then printf 'repos::hygiene: missing script (tried %s and chezmoi source scripts/)\n' "$_jd/scripts/bookmark-pr-hygiene.sh" >&2; exit 1; fi; \
  bash "$script" audit {{ args }}

# Prune landed branch/bookmark heads. Requires CONFIRM=1.
hygiene-prune *args:
  @set -euo pipefail; \
  if [ "${CONFIRM:-}" != "1" ]; then printf 'repos::hygiene-prune: set CONFIRM=1 to execute prune\n' >&2; exit 1; fi; \
  _jd="{{ justfile_directory() }}"; \
  script="$_jd/scripts/bookmark-pr-hygiene.sh"; \
  if [ ! -f "$script" ]; then \
    _cz="$(chezmoi source-path 2>/dev/null || true)"; \
    if [ -n "$_cz" ] && [ -f "$_cz/scripts/bookmark-pr-hygiene.sh" ]; then script="$_cz/scripts/bookmark-pr-hygiene.sh"; fi; \
  fi; \
  if [ ! -f "$script" ]; then printf 'repos::hygiene-prune: missing script (tried %s and chezmoi source scripts/)\n' "$_jd/scripts/bookmark-pr-hygiene.sh" >&2; exit 1; fi; \
  bash "$script" prune {{ args }}
