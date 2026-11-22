set shell := ["bash", "-eu", "-o", "pipefail", "-c"]
set windows-shell := ["C:/Program Files/Git/bin/bash.exe", "-eu", "-o", "pipefail", "-c"]

mod proj
mod repos

# List recipes (default task).
default:
  @"{{ just_executable() }}" --list

# Publish vendor global instruction files and skills from ~/.agents.
# Runs from the chezmoi source (source script names) or the applied ~/Justfile
# (scripts under ~/.agents/scripts).
agents-sync mode="copy":
  @_jd="{{justfile_directory()}}"; \
  _find(){ \
    for _p in "$_jd/dot_agents/scripts/executable_$1" "$HOME/.agents/scripts/$1"; do \
      [ -f "$_p" ] && { printf '%s' "$_p"; return 0; }; \
    done; \
    printf 'agents-sync: missing script %s (tried %s and %s)\n' "$1" \
      "$_jd/dot_agents/scripts/executable_$1" "$HOME/.agents/scripts/$1" >&2; return 1; \
  }; \
  _rules="$(_find sync-global-rules.sh)"; \
  _skills="$(_find sync-skills.sh)"; \
  bash "$_rules" "{{mode}}"; \
  printf '\n'; \
  bash "$_skills" "{{mode}}"; \
  printf '\nClaude:\n'; \
  printf '  ~/.claude/CLAUDE.md is regenerated from:\n'; \
  printf '    ~/.agents/rules/global-instructions.md\n'; \
  printf '    ~/.agents/rules/claude-*.md (optional overlays)\n'; \
  printf '  Content is inlined (one file) so the app does not ask to read\n'; \
  printf '  each ~/.agents path separately.\n'; \
  printf '  Re-run after edits so new sessions match.\n'; \
  printf '  ~/.claude/skills/<name> is published from ~/.agents/skills/<name>.\n'; \
  printf '  Copy mode needs a re-run after skill edits; symlink mode does not\n'; \
  printf '  (falls back to copy where symlinks are not permitted).\n'; \
  printf '\nCursor:\n'; \
  printf '  ~/.cursor/rules/global-instructions.mdc is generated from:\n'; \
  printf '    ~/.agents/rules/global-instructions.md\n'; \
  printf '    ~/.agents/rules/work-overlay.md (when present)\n'; \
  printf '  It is a user rule that applies in every project. Skipped when\n'; \
  printf '  ~/.cursor does not exist.\n'; \
  printf '  Cursor reads ~/.agents/skills directly, so skills need no copy.\n'

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
