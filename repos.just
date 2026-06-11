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

# Install the git pre-commit hook for this repo (markdown Prettier + whitespace).
# Run once per clone. Requires the `pre-commit` CLI (e.g. brew install pre-commit)
# and `prettier` on PATH (e.g. brew install prettier).
pre-commit-install:
  @set -euo pipefail; \
  _root="{{ justfile_directory() }}"; \
  if [ ! -f "$_root/.pre-commit-config.yaml" ]; then printf 'repos::pre-commit-install: missing .pre-commit-config.yaml under %s\n' "$_root" >&2; exit 1; fi; \
  command -v pre-commit >/dev/null 2>&1 || { printf 'repos::pre-commit-install: install the pre-commit CLI first (brew install pre-commit, pipx install pre-commit, …)\n' >&2; exit 1; }; \
  cd "$_root" && pre-commit install

# Run the same hooks as CI on all tracked files (offline parity check).
# Requires `prettier` on PATH (brew install prettier).
pre-commit-verify:
  @set -euo pipefail; \
  _root="{{ justfile_directory() }}"; \
  command -v pre-commit >/dev/null 2>&1 || { printf 'repos::pre-commit-verify: install pre-commit first\n' >&2; exit 1; }; \
  cd "$_root" && pre-commit run --all-files
