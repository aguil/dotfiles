set shell := ["bash", "-eu", "-o", "pipefail", "-c"]

mod proj

# Publish vendor global instruction files from canonical rules scaffold.
agents-sync mode="copy":
  @script="{{justfile_directory()}}/dot_agents/scripts/executable_sync-global-rules.sh"; \
  if [ ! -f "$script" ]; then printf 'agents-sync: missing script: %s\n' "$script" >&2; exit 1; fi; \
  bash "$script" "{{mode}}"; \
  printf '\nCursor next steps:\n'; \
  printf '  1) Open Cursor Settings -> Rules -> User Rules.\n'; \
  printf '  2) Paste/adapt from: %s\n' "$HOME/.agents/rules/cursor-user-rules.md"; \
  printf '  3) Keep vendor-global canonical rules in: %s\n' "$HOME/.agents/rules/global-instructions.md"

# List recipes (default task).
default:
  @just --list
