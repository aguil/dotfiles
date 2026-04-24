set shell := ["bash", "-eu", "-o", "pipefail", "-c"]

# Shared task implementation (also used by per-project Justfiles under ~/dev/projects/<name>/).
mod_pt := justfile_directory() / "project_tasks.just"

# Env: DEV_ROOT, DEV_GIT_HOST, DRY_RUN (passed through to project_tasks.just for new/add/drop).
DEV_ROOT := env_var_or_default("DEV_ROOT", env_var("HOME") + "/dev")
GIT_HOST := env_var_or_default("DEV_GIT_HOST", "github.com")
REPOS_ROOT := DEV_ROOT + "/repos/" + GIT_HOST
PROJECTS_ROOT := DEV_ROOT + "/projects"

# List module recipes (invoked as `just proj`).
default:
  @just -f "{{justfile_directory()}}/proj.just" --list

# Create project dirs, AGENTS.md (if missing), and a local Justfile that forwards to project_tasks.just (no `project` arg when run from that dir). Env: DEV_ROOT, DEV_GIT_HOST.
init project:
  @set -euo pipefail; \
  _src="$(chezmoi source-path 2>/dev/null || true)"; \
  if [ -z "$_src" ]; then printf 'init: chezmoi source-path failed (install chezmoi or fix its config).\n' >&2; exit 1; fi; \
  project_dir="{{PROJECTS_ROOT}}/{{project}}"; \
  stub_src="{{ justfile_directory() }}/project_local_justfile.stub"; \
  mod_path="{{ justfile_directory() }}/project_tasks.just"; \
  writer="$_src/scripts/write-project-local-justfile.py"; \
  agents_stub="{{ justfile_directory() }}/project_agents.md.stub"; \
  agents_writer="$_src/scripts/write-project-agents-md.py"; \
  if [ ! -f "$writer" ]; then printf 'init: missing %s (chezmoi source tree incomplete?).\n' "$writer" >&2; exit 1; fi; \
  mkdir -p "$project_dir"; \
  python3 "$writer" "$stub_src" "$project_dir/Justfile" "$mod_path" "{{project}}"; \
  if [ ! -f "$project_dir/AGENTS.md" ]; then python3 "$agents_writer" "$agents_stub" "$project_dir/AGENTS.md" "{{project}}"; fi; \
  printf '%s\n' "$project_dir"

# --- Delegates (set DEV_PROJECT_NAME for shared project_tasks.just) ---

new project type task_id *repos:
  @DEV_PROJECT_NAME="{{project}}" DRY_RUN="${DRY_RUN:-}" just -f "{{mod_pt}}" new "{{type}}" "{{task_id}}" {{repos}}

add project type task_id *repos:
  @DEV_PROJECT_NAME="{{project}}" DRY_RUN="${DRY_RUN:-}" just -f "{{mod_pt}}" add "{{type}}" "{{task_id}}" {{repos}}

list project="" type="":
  @proj="{{project}}"; \
  if [ -z "$proj" ]; then \
    cwd="$(pwd -P)"; root="{{PROJECTS_ROOT}}"; \
    case "$cwd/" in "$root"/*) rel="${cwd#"$root/"}"; proj="${rel%%/*}" ;; esac; \
  fi; \
  if [ -z "$proj" ]; then \
    command -v fzf >/dev/null 2>&1 || { printf 'list: missing project (pass one, cd under %s/<project>, or install fzf)\n' "{{PROJECTS_ROOT}}" >&2; exit 1; }; \
    _cand=(); while IFS= read -r _line; do [ -n "${_line:-}" ] && _cand+=("$_line"); done < <(find "{{PROJECTS_ROOT}}" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | while IFS= read -r _p; do [ -z "$_p" ] && continue; printf '%s\n' "${_p##*/}"; done | sort); \
    [ ${#_cand[@]} -gt 0 ] || { printf 'list: no projects found under %s\n' "{{PROJECTS_ROOT}}" >&2; exit 0; }; \
    proj="$(printf '%s\n' "${_cand[@]}" | fzf --height 60% --preview 'DEV_PROJECT_NAME={} just -f "{{mod_pt}}" list "{{type}}" 2>/dev/null || true' --preview-window 'right:60%:wrap' --header 'list | select project (preview: task dirs)' --prompt 'project> ' || true)"; \
    [ -n "$proj" ] || { printf 'list: cancelled\n' >&2; exit 0; }; \
  fi; \
  DEV_PROJECT_NAME="$proj" DRY_RUN="${DRY_RUN:-}" just -f "{{mod_pt}}" list "{{type}}"

status project="" type="" task_id="":
  @proj="{{project}}"; \
  typ="{{type}}"; tid="{{task_id}}"; \
  cwd="$(pwd -P)"; root="{{PROJECTS_ROOT}}"; \
  if [ -z "$proj" ]; then \
    case "$cwd/" in "$root"/*) rel="${cwd#"$root/"}"; proj="${rel%%/*}" ;; esac; \
  fi; \
  if [ -z "$typ" ] || [ -z "$tid" ]; then \
    case "$cwd/" in "$root"/*/*/*) rel="${cwd#"$root/"}"; _p="${rel%%/*}"; _rest="${rel#"$_p/"}"; _t="${_rest%%/*}"; _id="${_rest#"$_t/"}"; _id="${_id%%/*}"; [ -z "$typ" ] && typ="$_t"; [ -z "$tid" ] && tid="$_id" ;; esac; \
  fi; \
  if [ -z "$proj" ]; then \
    command -v fzf >/dev/null 2>&1 || { printf 'status: missing project (pass one, cd under %s/<project>, or install fzf)\n' "{{PROJECTS_ROOT}}" >&2; exit 1; }; \
    _cand=(); while IFS= read -r _line; do [ -n "${_line:-}" ] && _cand+=("$_line"); done < <(find "{{PROJECTS_ROOT}}" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | while IFS= read -r _p; do [ -z "$_p" ] && continue; printf '%s\n' "${_p##*/}"; done | sort); \
    [ ${#_cand[@]} -gt 0 ] || { printf 'status: no projects found under %s\n' "{{PROJECTS_ROOT}}" >&2; exit 1; }; \
    proj="$(printf '%s\n' "${_cand[@]}" | fzf --height 50% --header 'status | select project' --prompt 'project> ' || true)"; \
    [ -n "$proj" ] || { printf 'status: cancelled\n' >&2; exit 0; }; \
  fi; \
  DEV_PROJECT_NAME="$proj" DRY_RUN="${DRY_RUN:-}" just -f "{{mod_pt}}" status "$typ" "$tid"

push project="" type="" task_id="" *repos:
  @proj="{{project}}"; \
  typ="{{type}}"; tid="{{task_id}}"; \
  cwd="$(pwd -P)"; root="{{PROJECTS_ROOT}}"; \
  if [ -z "$proj" ]; then \
    case "$cwd/" in "$root"/*) rel="${cwd#"$root/"}"; proj="${rel%%/*}" ;; esac; \
  fi; \
  if [ -z "$typ" ] || [ -z "$tid" ]; then \
    case "$cwd/" in "$root"/*/*/*) rel="${cwd#"$root/"}"; _p="${rel%%/*}"; _rest="${rel#"$_p/"}"; _t="${_rest%%/*}"; _id="${_rest#"$_t/"}"; _id="${_id%%/*}"; [ -z "$typ" ] && typ="$_t"; [ -z "$tid" ] && tid="$_id" ;; esac; \
  fi; \
  if [ -z "$proj" ]; then \
    command -v fzf >/dev/null 2>&1 || { printf 'push: missing project (pass one, cd under %s/<project>, or install fzf)\n' "{{PROJECTS_ROOT}}" >&2; exit 1; }; \
    _cand=(); while IFS= read -r _line; do [ -n "${_line:-}" ] && _cand+=("$_line"); done < <(find "{{PROJECTS_ROOT}}" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | while IFS= read -r _p; do [ -z "$_p" ] && continue; printf '%s\n' "${_p##*/}"; done | sort); \
    [ ${#_cand[@]} -gt 0 ] || { printf 'push: no projects found under %s\n' "{{PROJECTS_ROOT}}" >&2; exit 1; }; \
    proj="$(printf '%s\n' "${_cand[@]}" | fzf --height 50% --header 'push | select project' --prompt 'project> ' || true)"; \
    [ -n "$proj" ] || { printf 'push: cancelled\n' >&2; exit 0; }; \
  fi; \
  DEV_PROJECT_NAME="$proj" DRY_RUN="${DRY_RUN:-}" just -f "{{mod_pt}}" push "$typ" "$tid" {{repos}}

drop project="" type="" task_id="" *repos:
  @proj="{{project}}"; \
  typ="{{type}}"; tid="{{task_id}}"; \
  cwd="$(pwd -P)"; root="{{PROJECTS_ROOT}}"; \
  if [ -z "$proj" ]; then \
    case "$cwd/" in "$root"/*) rel="${cwd#"$root/"}"; proj="${rel%%/*}" ;; esac; \
  fi; \
  if [ -z "$typ" ] || [ -z "$tid" ]; then \
    case "$cwd/" in "$root"/*/*/*) rel="${cwd#"$root/"}"; _p="${rel%%/*}"; _rest="${rel#"$_p/"}"; _t="${_rest%%/*}"; _id="${_rest#"$_t/"}"; _id="${_id%%/*}"; [ -z "$typ" ] && typ="$_t"; [ -z "$tid" ] && tid="$_id" ;; esac; \
  fi; \
  if [ -z "$proj" ]; then \
    command -v fzf >/dev/null 2>&1 || { printf 'drop: missing project (pass one, cd under %s/<project>, or install fzf)\n' "{{PROJECTS_ROOT}}" >&2; exit 1; }; \
    _cand=(); while IFS= read -r _line; do [ -n "${_line:-}" ] && _cand+=("$_line"); done < <(find "{{PROJECTS_ROOT}}" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | while IFS= read -r _p; do [ -z "$_p" ] && continue; printf '%s\n' "${_p##*/}"; done | sort); \
    [ ${#_cand[@]} -gt 0 ] || { printf 'drop: no projects found under %s\n' "{{PROJECTS_ROOT}}" >&2; exit 1; }; \
    proj="$(printf '%s\n' "${_cand[@]}" | fzf --height 50% --header 'drop | select project' --prompt 'project> ' || true)"; \
    [ -n "$proj" ] || { printf 'drop: cancelled\n' >&2; exit 0; }; \
  fi; \
  DEV_PROJECT_NAME="$proj" DRY_RUN="${DRY_RUN:-}" just -f "{{mod_pt}}" drop "$typ" "$tid" {{repos}}
