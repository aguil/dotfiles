set shell := ["bash", "-eu", "-o", "pipefail", "-c"]

# Shared task implementation (also used by per-project Justfiles under ~/dev/projects/<name>/).
mod_pt := justfile_directory() / "project_tasks.just"

# Env: DEV_ROOT, DEV_GIT_HOST, DRY_RUN (passed through to project_tasks.just for new/add/drop).
DEV_ROOT := env_var_or_default("DEV_ROOT", env_var("HOME") + "/dev")
GIT_HOST := env_var_or_default("DEV_GIT_HOST", "github.com")
REPOS_ROOT := DEV_ROOT + "/repos/" + GIT_HOST
PROJECTS_ROOT := DEV_ROOT + "/projects"

# List recipes (default task).
default:
  @just --list

# Create project dirs, manifests/default.repos stub, AGENTS.md (if missing), and a local Justfile that forwards to project_tasks.just (no `project` arg when run from that dir). Env: DEV_ROOT, DEV_GIT_HOST.
project-init project:
  @set -euo pipefail; \
  project_dir="{{PROJECTS_ROOT}}/{{project}}"; \
  stub_src="{{ justfile_directory() }}/project_local_justfile.stub"; \
  mod_path="{{ justfile_directory() }}/project_tasks.just"; \
  writer="{{ justfile_directory() }}/scripts/write-project-local-justfile.py"; \
  agents_stub="{{ justfile_directory() }}/project_agents.md.stub"; \
  agents_writer="{{ justfile_directory() }}/scripts/write-project-agents-md.py"; \
  mkdir -p "$project_dir/manifests" "$project_dir/tasks" "$project_dir/state/locks" "$project_dir/state/events"; \
  manifest="$project_dir/manifests/default.repos"; \
  if [ ! -f "$manifest" ]; then printf '# repo base\n# acme/api main\n' > "$manifest"; fi; \
  python3 "$writer" "$stub_src" "$project_dir/Justfile" "$mod_path" "{{project}}"; \
  if [ ! -f "$project_dir/AGENTS.md" ]; then python3 "$agents_writer" "$agents_stub" "$project_dir/AGENTS.md" "{{project}}"; fi; \
  printf '%s\n' "$project_dir"

# --- Delegates (set DEV_PROJECT_NAME for shared project_tasks.just) ---

new project type task_id:
  @DEV_PROJECT_NAME="{{project}}" DRY_RUN="${DRY_RUN:-}" just -f "{{mod_pt}}" new "{{type}}" "{{task_id}}"

add project type task_id *repos:
  @DEV_PROJECT_NAME="{{project}}" DRY_RUN="${DRY_RUN:-}" just -f "{{mod_pt}}" add "{{type}}" "{{task_id}}" {{repos}}

list project type="":
  @DEV_PROJECT_NAME="{{project}}" DRY_RUN="${DRY_RUN:-}" just -f "{{mod_pt}}" list "{{type}}"

drop project type="" task_id="" *repos:
  @DEV_PROJECT_NAME="{{project}}" DRY_RUN="${DRY_RUN:-}" just -f "{{mod_pt}}" drop "{{type}}" "{{task_id}}" {{repos}}
