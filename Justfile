set shell := ["bash", "-eu", "-o", "pipefail", "-c"]

mod proj
mod repos

# List recipes (default task).
default:
  @just --list

# Publish vendor global instruction files from canonical rules scaffold.
agents-sync mode="copy":
  @_jd="{{justfile_directory()}}"; \
  _script="$_jd/dot_agents/scripts/executable_sync-global-rules.sh"; \
  if [ ! -f "$_script" ]; then \
    _script="$HOME/.agents/scripts/sync-global-rules.sh"; \
  fi; \
  if [ ! -f "$_script" ]; then \
    _cz="$(chezmoi source-path 2>/dev/null || true)"; \
    if [ -n "$_cz" ]; then _script="$_cz/dot_agents/scripts/executable_sync-global-rules.sh"; fi; \
  fi; \
  if [ ! -f "$_script" ]; then \
    printf 'agents-sync: missing script: %s\n' "$_script" >&2; exit 1; \
  fi; \
  bash "$_script" "{{mode}}"; \
  printf '\nClaude:\n'; \
  printf '  ~/.claude/CLAUDE.md is regenerated from:\n'; \
  printf '    ~/.agents/rules/global-instructions.md\n'; \
  printf '    ~/.agents/rules/claude-*.md (optional overlays)\n'; \
  printf '  Content is inlined (one file) so the app does not ask to read\n'; \
  printf '  each ~/.agents path separately.\n'; \
  printf '  Re-run after edits so new sessions match.\n'; \
  printf '\nCursor:\n'; \
  printf '  This recipe updates Claude/OpenCode files only. Cursor still\n'; \
  printf '  needs User Rules for always-on global behavior.\n'; \
  printf '  1) Open Settings -> Rules -> User Rules for baseline\n'; \
  printf '     instructions; project rules add on top.\n'; \
  printf '  2) Paste or adapt ~/.agents/rules/cursor-user-rules.md — a\n'; \
  printf '     Cursor-oriented seed matching ~/.agents/rules habits.\n'; \
  printf '  3) Keep ~/.agents/rules/global-instructions.md canonical;\n'; \
  printf '     mirror changes into User Rules so Cursor stays aligned.\n'

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
