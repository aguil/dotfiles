set shell := ["bash", "-eu", "-o", "pipefail", "-c"]

mod proj

# List recipes (default task).
default:
  @just --list

# Publish vendor global instruction files from canonical rules scaffold.
agents-sync mode="copy":
  @script="{{justfile_directory()}}/dot_agents/scripts/executable_sync-global-rules.sh"; \
  if [ ! -f "$script" ]; then printf 'agents-sync: missing script: %s\n' "$script" >&2; exit 1; fi; \
  bash "$script" "{{mode}}"; \
  printf '\nCursor next steps:\n'; \
  printf '  1) Open Cursor Settings -> Rules -> User Rules.\n'; \
  printf '  2) Paste/adapt from: %s\n' "$HOME/.agents/rules/cursor-user-rules.md"; \
  printf '  3) Keep vendor-global canonical rules in: %s\n' "$HOME/.agents/rules/global-instructions.md"

# Smoke test project/task picker and key flows. Optional arg picks a project.
# Same script resolution as proj::list (scripts/ is not chezmoi-applied; use source-path).
proj-smoke project="":
  @set -euo pipefail; \
  _jd="{{ justfile_directory() }}"; \
  script="$_jd/scripts/proj-smoke.sh"; \
  if [ ! -f "$script" ]; then \
    _cz="$(chezmoi source-path 2>/dev/null || true)"; \
    if [ -n "$_cz" ] && [ -f "$_cz/scripts/proj-smoke.sh" ]; then script="$_cz/scripts/proj-smoke.sh"; fi; \
  fi; \
  if [ ! -f "$script" ]; then printf 'proj-smoke: missing script (tried %s and chezmoi source scripts/)\n' "$_jd/scripts/proj-smoke.sh" >&2; exit 1; fi; \
  if [ -n "{{project}}" ]; then bash "$script" "{{project}}"; else bash "$script"; fi
