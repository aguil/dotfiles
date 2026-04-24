set shell := ["bash", "-eu", "-o", "pipefail", "-c"]

# Env: DEV_ROOT, DEV_GIT_HOST, DRY_RUN (=1 for no-op previews on new / drop).
DEV_ROOT := env_var_or_default("DEV_ROOT", env_var("HOME") + "/dev")
GIT_HOST := env_var_or_default("DEV_GIT_HOST", "github.com")
REPOS_ROOT := DEV_ROOT + "/repos/" + GIT_HOST
PROJECTS_ROOT := DEV_ROOT + "/projects"

project := env_var_or_default("DEV_PROJECT_NAME", "")

# Fails fast when this file is run without DEV_PROJECT_NAME (e.g. `just -f …/project_tasks.just`).
_ensure_project:
  @if [ -z "${DEV_PROJECT_NAME:-}" ]; then echo >&2 "set DEV_PROJECT_NAME (project scope)"; exit 1; fi

# Scaffold <type>/<task-id>/ under the project and an empty task.json (repos:{}). With no repo args, pick repos via fzf --multi (optional; skip with no selection for an empty task). CLI org/repo args match `add` (optional shared base last if it has no '/'). DRY_RUN=1 skips writes; with extra args or fzf picks prints the add command that would follow.
new type task_id *repos: _ensure_project
  @project_dir="{{PROJECTS_ROOT}}/{{project}}"; \
  _tilde(){ case "$1" in "$HOME") printf '~';; "$HOME"/*) printf '~/%s' "${1#"$HOME"/}";; *) printf '%s' "$1";; esac; }; \
  task_dir="$project_dir/{{type}}/{{task_id}}"; \
  dry="${DRY_RUN:-}"; \
  if [ -f "$task_dir/task.json" ]; then printf "task already exists: %s\n" "$(_tilde "$task_dir")" >&2; exit 1; fi; \
  _na=( {{repos}} ); \
  _clean=(); for _a in "${_na[@]}"; do [ -n "${_a:-}" ] && _clean+=("$_a"); done; \
  _fwd=(); \
  if [ ${#_clean[@]} -gt 0 ]; then \
    repos=("${_clean[@]}"); base=master; \
    if [ ${#_clean[@]} -ge 2 ]; then \
      _li=$((${#_clean[@]} - 1)); \
      _last="${_clean[$_li]}"; \
      case "$_last" in */*) ;; *) base="$_last"; repos=("${_clean[@]:0:${_li}}"); ;; esac; \
    fi; \
    if [ ${#repos[@]} -eq 0 ]; then printf "new: pass at least one org/repo (optional shared base last if it has no '/')\n" >&2; exit 1; fi; \
    _fwd=("${repos[@]}"); \
    if [ ${#_clean[@]} -ge 2 ]; then \
      _li=$((${#_clean[@]} - 1)); \
      _last="${_clean[$_li]}"; \
      case "$_last" in */*) ;; *) _fwd+=("$base"); ;; esac; \
    fi; \
  else \
    command -v fzf >/dev/null 2>&1 || { printf "new: fzf is required when no repos are passed\n" >&2; exit 1; }; \
    repos_root="{{REPOS_ROOT}}"; \
    if [ ! -d "$repos_root" ]; then printf "new: repos root missing: %s\n" "$(_tilde "$repos_root")" >&2; exit 1; fi; \
    printf '%s\n' "new: Canonical org/repo paths under $(_tilde "$repos_root"). Tab/Shift-Tab: toggle selection, Enter: confirm, Esc: cancel. Empty selection creates a task with no linked repos." >&2; \
    while IFS= read -r _line; do [ -n "${_line:-}" ] && _fwd+=("$_line"); done < <(find "$repos_root" -mindepth 2 -maxdepth 2 -type d 2>/dev/null | while IFS= read -r _d; do [ -d "$_d/.git" ] || [ -d "$_d/.jj" ] || continue; printf '%s\n' "${_d#"${repos_root}/"}"; done | sort -u | fzf --multi --height 50% --header-first --header "new | Tab/Shift-Tab: toggle | Enter: confirm | Esc: cancel | empty selection OK" --marker ">>" --prompt "new repos> " || true); \
  fi; \
  if [ "$dry" = "1" ]; then \
    printf "[dry-run] new: would create %s with empty repos in task.json\n" "$(_tilde "$task_dir")" >&2; \
    if [ ${#_fwd[@]} -gt 0 ]; then printf "[dry-run] new: would run: just add \"%s\" \"%s\"" "{{type}}" "{{task_id}}" >&2; printf ' %q' "${_fwd[@]}" >&2; printf '\n' >&2; fi; \
    exit 0; \
  fi; \
  mkdir -p "$task_dir"; \
  python3 -c "import json,pathlib,sys; td,proj,typ,tid=sys.argv[1:5]; json.dump({'project':proj,'type':typ,'task_id':tid,'repos':{}},open(pathlib.Path(td)/'task.json','w'),indent=2)" \
    "$task_dir" "{{project}}" "{{type}}" "{{task_id}}"; \
  printf "%s\n" "$(_tilde "$task_dir")"; \
  if [ ${#_fwd[@]} -gt 0 ]; then \
    DRY_RUN="${DRY_RUN:-}" just -f "{{justfile()}}" add "{{type}}" "{{task_id}}" "${_fwd[@]}"; \
  fi

# Add repo(s) to an existing task (workspace / git worktree only; canonical must already exist under repos/). Pass one or more org/repo; optional shared base is the last arg if it contains no '/'. Default base master. With no args, pick repos with fzf --multi under REPOS_ROOT.
add type task_id *repos: _ensure_project
  @project_dir="{{PROJECTS_ROOT}}/{{project}}"; \
  _tilde(){ case "$1" in "$HOME") printf '~';; "$HOME"/*) printf '~/%s' "${1#"$HOME"/}";; *) printf '%s' "$1";; esac; }; \
  task_dir="$project_dir/{{type}}/{{task_id}}"; \
  dry="${DRY_RUN:-}"; \
  if [ ! -d "$task_dir" ]; then \
    printf "add: task not found: %s\n" "$(_tilde "$task_dir")" >&2; \
    printf "add: layout is projects/<project>/<type>/<task-id>/ — create the task first (from dotfiles repo: \`just new %s %s %s\`; from project dir: \`just new %s %s\`).\n" "{{project}}" "{{type}}" "{{task_id}}" "{{type}}" "{{task_id}}" >&2; \
    _typdir="$project_dir/{{type}}"; \
    if [ -d "$_typdir" ]; then \
      _ids="$(find "$_typdir" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | while IFS= read -r _d; do printf '%s ' "${_d##*/}"; done)"; \
      _ids="${_ids%% }"; \
      [ -n "$_ids" ] && printf "add: existing task-id dirs for type %s: %s\n" "{{type}}" "$_ids" >&2; \
    fi; \
    exit 1; \
  fi; \
  _args=( {{repos}} ); \
  _clean=(); for _a in "${_args[@]}"; do [ -n "${_a:-}" ] && _clean+=("$_a"); done; \
  if [ ${#_clean[@]} -eq 0 ]; then \
    command -v fzf >/dev/null 2>&1 || { printf "add: fzf is required when no repos are passed\n" >&2; exit 1; }; \
    repos_root="{{REPOS_ROOT}}"; \
    if [ ! -d "$repos_root" ]; then printf "add: repos root missing: %s\n" "$(_tilde "$repos_root")" >&2; exit 1; fi; \
    _cand=(); \
    while IFS= read -r _line; do [ -n "${_line:-}" ] && _cand+=("$_line"); done < <(find "$repos_root" -mindepth 2 -maxdepth 2 -type d 2>/dev/null | while IFS= read -r _d; do [ -d "$_d/.git" ] || [ -d "$_d/.jj" ] || continue; printf '%s\n' "${_d#"${repos_root}/"}"; done | sort -u); \
    if [ ${#_cand[@]} -eq 0 ]; then \
      printf "add: no canonical repos under %s (directories with .git or .jj). Clone one to that tree first, or pass org/repo on the command line after the task id, e.g. \`just add %s %s %s acme/repo\`.\n" "$(_tilde "$repos_root")" "{{project}}" "{{type}}" "{{task_id}}" >&2; \
      exit 1; \
    fi; \
    printf '%s\n' "add: Canonical org/repo paths under $(_tilde "$repos_root"). Tab/Shift-Tab: toggle selection, Enter: confirm, Esc: cancel. At least one repo is required." >&2; \
    repos=(); \
    _tmp="$(mktemp)"; \
    _fzf_ec=0; \
    printf '%s\n' "${_cand[@]}" | fzf --multi --height 50% --header-first --header "add | Tab/Shift-Tab: toggle | Enter: confirm | Esc: cancel | need 1+ repos" --marker ">>" --prompt "repos> " > "$_tmp" || _fzf_ec=$?; \
    if [ -s "$_tmp" ]; then while IFS= read -r _line; do [ -n "${_line:-}" ] && repos+=("$_line"); done < "$_tmp"; fi; \
    rm -f "$_tmp"; \
    base=master; \
    if [ ${#repos[@]} -eq 0 ]; then \
      if [ "$_fzf_ec" -eq 1 ] || [ "$_fzf_ec" -eq 130 ]; then printf "add: cancelled — no repos were added.\n" >&2; exit 0; \
      else printf "add: no repos selected — Enter was pressed with no rows marked (use Tab to toggle, then Enter), or pass org/repo after the task id, e.g. \`just add %s %s %s acme/repo\`.\n" "{{project}}" "{{type}}" "{{task_id}}" >&2; \
      exit 1; \
      fi; \
    fi; \
  else \
    repos=("${_clean[@]}"); base=master; \
    if [ ${#_clean[@]} -ge 2 ]; then \
      _li=$((${#_clean[@]} - 1)); \
      _last="${_clean[$_li]}"; \
      case "$_last" in */*) ;; *) base="$_last"; repos=("${_clean[@]:0:${_li}}"); ;; esac; \
    fi; \
    if [ ${#repos[@]} -eq 0 ]; then printf "add: pass at least one org/repo\n" >&2; exit 1; fi; \
  fi; \
  branch="{{type}}/{{project}}/{{task_id}}"; \
  if [ "$dry" = "1" ]; then \
    for orgrepo in "${repos[@]}"; do \
      link_name="${orgrepo##*/}"; \
      ws_dir="$task_dir/$link_name"; \
      printf "[dry-run] add %s -> %s (base=%s)\n" "$orgrepo" "$(_tilde "$ws_dir")" "$base" >&2; \
    done; \
    exit 0; \
  fi; \
  for orgrepo in "${repos[@]}"; do \
    case "$orgrepo" in */*) ;; *) printf "add: invalid org/repo (expected org/name): %s\n" "$orgrepo" >&2; exit 1 ;; esac; \
    repo_dir="{{REPOS_ROOT}}/$orgrepo"; \
    link_name="${orgrepo##*/}"; \
    ws_dir="$task_dir/$link_name"; \
    ws_name="{{type}}-{{project}}-{{task_id}}-$link_name"; \
    mkdir -p "$(dirname "$repo_dir")"; \
    if git -C "$repo_dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then \
      :; \
    elif [ -d "$repo_dir/.jj" ] && command -v jj >/dev/null 2>&1 && jj --repository "$repo_dir" root >/dev/null 2>&1; then \
      :; \
    else \
      printf "add: canonical repo missing at %s (clone it there first, then re-run add)\n" "$(_tilde "$repo_dir")" >&2; \
      exit 1; \
    fi; \
    if [ ! -d "$ws_dir" ]; then \
      if command -v jj >/dev/null 2>&1 && [ -d "$repo_dir/.jj" ] && jj --repository "$repo_dir" root >/dev/null 2>&1; then \
        jj --repository "$repo_dir" workspace add "$ws_dir" --name "$ws_name" --revision "$base" >/dev/null 2>&1 || \
          jj --repository "$repo_dir" workspace add "$ws_dir" --name "$ws_name" --revision @; \
        jj --no-pager --repository "$ws_dir" bookmark create "$branch" >/dev/null 2>&1 || true; \
      else \
        git -C "$repo_dir" fetch --all --prune; \
        start_ref="$base"; \
        if git -C "$repo_dir" show-ref --verify --quiet "refs/remotes/origin/$base"; then start_ref="origin/$base"; fi; \
        if git -C "$repo_dir" show-ref --verify --quiet "refs/heads/$branch"; then \
          git -C "$repo_dir" worktree add "$ws_dir" "$branch"; \
        else \
          git -C "$repo_dir" worktree add "$ws_dir" -b "$branch" "$start_ref"; \
        fi; \
      fi; \
    fi; \
    python3 -c "import json,pathlib,sys; td,link,org,proj,typ,tid=sys.argv[1:7]; p=pathlib.Path(td)/'task.json'; d=json.load(open(p)) if p.exists() else {}; d.setdefault('repos',{}); d['repos'][link]=org; d.setdefault('project',proj); d.setdefault('type',typ); d.setdefault('task_id',tid); json.dump(d,open(p,'w'),indent=2)" \
      "$task_dir" "$link_name" "$orgrepo" "{{project}}" "{{type}}" "{{task_id}}"; \
    printf "%s\n" "$(_tilde "$ws_dir")"; \
  done

# Print VCS status (jj st / git status -sb) for repos in a task, or for every task when type+task_id are omitted. Reads task.json for the repo list.
status type="" task_id="": _ensure_project
  @project_dir="{{PROJECTS_ROOT}}/{{project}}"; \
  typ="{{type}}"; tid="{{task_id}}"; \
  _tilde(){ case "$1" in "$HOME") printf '~';; "$HOME"/*) printf '~/%s' "${1#"$HOME"/}";; *) printf '%s' "$1";; esac; }; \
  if [ ! -d "$project_dir" ]; then printf "status: project not found: %s\n" "$(_tilde "$project_dir")" >&2; exit 1; fi; \
  cwd="$(pwd -P)"; \
  if [ -z "$typ" ]; then case "$cwd/" in "$project_dir"/*/*) rel="${cwd#"$project_dir/"}"; typ="${rel%%/*}" ;; esac; fi; \
  if [ -z "$tid" ]; then case "$cwd/" in "$project_dir"/*/*) rel="${cwd#"$project_dir/"}"; _t="${rel%%/*}"; _rest="${rel#"$_t/"}"; _id="${_rest%%/*}"; [ -n "$typ" ] || typ="$_t"; tid="$_id" ;; esac; fi; \
  if [ -n "$typ" ] && [ -z "$tid" ]; then \
    if command -v fzf >/dev/null 2>&1; then \
      _cand=(); while IFS= read -r _line; do [ -n "${_line:-}" ] && _cand+=("$_line"); done < <(find "$project_dir/$typ" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | while IFS= read -r _p; do [ -z "$_p" ] && continue; printf '%s\n' "${_p##*/}"; done | sort); \
      [ ${#_cand[@]} -gt 0 ] || { printf 'status: no task ids under type %s\n' "$typ" >&2; exit 1; }; \
      tid="$(printf '%s\n' "${_cand[@]}" | fzf --height 60% --layout reverse --header-first --header 'status | select task-id (newest first)' --prompt 'task-id> ' || true)"; \
      [ -n "$tid" ] || { printf 'status: cancelled\n' >&2; exit 0; }; \
    else \
      printf 'status: missing task_id (pass it, cd under %s/<type>/<task-id>, or install fzf for interactive selection)\n' "$project_dir" >&2; exit 1; \
    fi; \
  fi; \
  if [ -z "$typ" ] && [ -n "$tid" ]; then \
    if command -v fzf >/dev/null 2>&1; then \
      _cand=(); while IFS= read -r _line; do [ -n "${_line:-}" ] && _cand+=("$_line"); done < <(find "$project_dir" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | while IFS= read -r _p; do [ -z "$_p" ] && continue; printf '%s\n' "${_p##*/}"; done | sort); \
      [ ${#_cand[@]} -gt 0 ] || { printf 'status: no task types found under %s\n' "$project_dir" >&2; exit 1; }; \
      typ="$(printf '%s\n' "${_cand[@]}" | fzf --height 60% --layout reverse --header-first --header 'status | select type' --prompt 'type> ' || true)"; \
      [ -n "$typ" ] || { printf 'status: cancelled\n' >&2; exit 0; }; \
    else \
      printf 'status: missing type (pass it, cd under %s/<type>/<task-id>, or install fzf for interactive selection)\n' "$project_dir" >&2; exit 1; \
    fi; \
  fi; \
  _show_task() { \
    local td="$1"; \
    printf '\n## %s\n' "$(_tilde "$td")"; \
    if [ ! -f "$td/task.json" ]; then printf '  (no task.json)\n'; return; fi; \
    local repos; repos="$(python3 -c 'import json,sys; print("\n".join(json.load(open(sys.argv[1])).get("repos",{}).keys()))' "$td/task.json")"; \
    if [ -z "$repos" ]; then printf '  (no repos in task.json)\n'; return; fi; \
    while IFS= read -r name; do \
      [ -n "$name" ] || continue; \
      local ws="$td/$name"; \
      printf '\n===== %s =====\n' "$name"; \
      if [ ! -d "$ws" ]; then printf '  (missing checkout: %s)\n' "$(_tilde "$ws")"; continue; fi; \
      if [ -d "$ws/.jj" ] && command -v jj >/dev/null 2>&1; then \
        jj --no-pager --repository "$ws" st 2>&1 || true; \
      elif [ -e "$ws/.git" ]; then \
        git -C "$ws" status -sb 2>&1 || true; \
      else \
        printf '  (no .jj or .git)\n'; \
      fi; \
    done <<< "$repos"; \
  }; \
  if [ -n "$typ" ] && [ -n "$tid" ]; then \
    task_dir="$project_dir/$typ/$tid"; \
    if [ ! -d "$task_dir" ]; then printf "status: task not found: %s\n" "$(_tilde "$task_dir")" >&2; exit 1; fi; \
    _show_task "$task_dir"; \
  else \
    find "$project_dir" -mindepth 2 -maxdepth 2 -type d 2>/dev/null | sort | while IFS= read -r td; do \
      [ -z "$td" ] && continue; \
      _show_task "$td"; \
    done; \
  fi

# Move the <type>/<project>/<task-id> bookmark (jj) or branch (git) to the working-copy tip and push to origin, for each repo in task.json (or only the named repos). DRY_RUN=1 prints what would run. Requires git remotes/jj remotes to be already configured.
push type="" task_id="" *repos: _ensure_project
  @project_dir="{{PROJECTS_ROOT}}/{{project}}"; \
  typ="{{type}}"; tid="{{task_id}}"; \
  _tilde(){ case "$1" in "$HOME") printf '~';; "$HOME"/*) printf '~/%s' "${1#"$HOME"/}";; *) printf '%s' "$1";; esac; }; \
  dry="${DRY_RUN:-}"; \
  cwd="$(pwd -P)"; \
  if [ -z "$typ" ]; then case "$cwd/" in "$project_dir"/*/*) rel="${cwd#"$project_dir/"}"; typ="${rel%%/*}" ;; esac; fi; \
  if [ -z "$tid" ]; then case "$cwd/" in "$project_dir"/*/*) rel="${cwd#"$project_dir/"}"; _t="${rel%%/*}"; _rest="${rel#"$_t/"}"; _id="${_rest%%/*}"; [ -n "$typ" ] || typ="$_t"; tid="$_id" ;; esac; fi; \
  if [ -z "$typ" ] || [ -z "$tid" ]; then \
    command -v fzf >/dev/null 2>&1 || { printf 'push: missing type/task_id (pass them, cd under %s/<type>/<task-id>, or install fzf)\n' "$project_dir" >&2; exit 1; }; \
    if [ -z "$typ" ]; then \
      _cand=(); while IFS= read -r _line; do [ -n "${_line:-}" ] && _cand+=("$_line"); done < <(find "$project_dir" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | while IFS= read -r _p; do [ -z "$_p" ] && continue; printf '%s\n' "${_p##*/}"; done | sort); \
      [ ${#_cand[@]} -gt 0 ] || { printf 'push: no task types found under %s\n' "$project_dir" >&2; exit 1; }; \
      typ="$(printf '%s\n' "${_cand[@]}" | fzf --height 60% --layout reverse --header-first --header 'push | select type' --prompt 'type> ' || true)"; \
      [ -n "$typ" ] || { printf 'push: cancelled\n' >&2; exit 0; }; \
    fi; \
    if [ -z "$tid" ]; then \
      _cand=(); while IFS= read -r _line; do [ -n "${_line:-}" ] && _cand+=("$_line"); done < <(find "$project_dir/$typ" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | while IFS= read -r _p; do [ -z "$_p" ] && continue; printf '%s\n' "${_p##*/}"; done | sort); \
      [ ${#_cand[@]} -gt 0 ] || { printf 'push: no task ids under type %s\n' "$typ" >&2; exit 1; }; \
      tid="$(printf '%s\n' "${_cand[@]}" | fzf --height 60% --layout reverse --header-first --header 'push | select task-id (newest first)' --prompt 'task-id> ' || true)"; \
      [ -n "$tid" ] || { printf 'push: cancelled\n' >&2; exit 0; }; \
    fi; \
  fi; \
  task_dir="$project_dir/$typ/$tid"; \
  if [ ! -d "$task_dir" ]; then printf "push: task not found: %s\n" "$(_tilde "$task_dir")" >&2; exit 1; fi; \
  if [ ! -f "$task_dir/task.json" ]; then printf "push: no task.json at %s\n" "$(_tilde "$task_dir")" >&2; exit 1; fi; \
  branch="$typ/{{project}}/$tid"; \
  _args=( {{repos}} ); \
  selected=(); for _a in "${_args[@]}"; do [ -n "${_a:-}" ] && selected+=("$_a"); done; \
  mapfile -t all_repos < <(python3 -c 'import json,sys; print("\n".join(json.load(open(sys.argv[1])).get("repos",{}).keys()))' "$task_dir/task.json"); \
  if [ ${#selected[@]} -eq 0 ]; then selected=("${all_repos[@]}"); fi; \
  if [ ${#selected[@]} -eq 0 ]; then printf "push: no repos in task.json — add one with \`just add %s %s <org/repo>\` first\n" "$typ" "$tid" >&2; exit 1; fi; \
  for name in "${selected[@]}"; do \
    [ -n "$name" ] || continue; \
    ws="$task_dir/$name"; \
    printf '\n===== %s (%s) =====\n' "$name" "$branch"; \
    if [ ! -d "$ws" ]; then printf 'push: missing checkout: %s\n' "$(_tilde "$ws")" >&2; exit 1; fi; \
    if [ -d "$ws/.jj" ] && command -v jj >/dev/null 2>&1; then \
      if [ "$dry" = "1" ]; then \
        printf '[dry-run] jj -R %s bookmark set %s --to @ --allow-backwards\n' "$(_tilde "$ws")" "$branch"; \
        printf '[dry-run] jj -R %s git push -b %s\n' "$(_tilde "$ws")" "$branch"; \
      else \
        jj --no-pager --repository "$ws" bookmark set "$branch" --to @ --allow-backwards >/dev/null || { printf 'push: jj bookmark set failed for %s\n' "$name" >&2; exit 1; }; \
        jj --no-pager --repository "$ws" git push -b "$branch" || { printf 'push: jj git push failed for %s\n' "$name" >&2; exit 1; }; \
      fi; \
    elif [ -e "$ws/.git" ]; then \
      if [ "$dry" = "1" ]; then \
        printf '[dry-run] git -C %s push -u origin HEAD:%s\n' "$(_tilde "$ws")" "$branch"; \
      else \
        git -C "$ws" push -u origin "HEAD:$branch" || { printf 'push: git push failed for %s\n' "$name" >&2; exit 1; }; \
      fi; \
    else \
      printf 'push: no .jj or .git in %s\n' "$(_tilde "$ws")" >&2; exit 1; \
    fi; \
  done

# List task directories; optional type filters to <project>/<type>/*.
list type="": _ensure_project
  @root="{{PROJECTS_ROOT}}/{{project}}"; \
  _tilde(){ case "$1" in "$HOME") printf '~';; "$HOME"/*) printf '~/%s' "${1#"$HOME"/}";; *) printf '%s' "$1";; esac; }; \
  if [ ! -d "$root" ]; then exit 0; fi; \
  if [ -n "{{type}}" ]; then \
    find "$root/{{type}}" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | while IFS= read -r _p; do [ -z "$_p" ] && continue; printf '%s\n' "$(_tilde "$_p")"; done || true; \
  else \
    find "$root" -mindepth 2 -maxdepth 2 -type d 2>/dev/null | while IFS= read -r _p; do [ -z "$_p" ] && continue; printf '%s\n' "$(_tilde "$_p")"; done || true; \
  fi

# Forget jj workspace / remove git worktree for repos (or entire task if no repo names). Removes task.json. DRY_RUN=1 prints only.
# Omit type and task_id to drop the whole project (all tasks under projects/<project>/, then remove that directory).
drop type="" task_id="" *repos: _ensure_project
  @project_dir="{{PROJECTS_ROOT}}/{{project}}"; \
  typ="{{type}}"; tid="{{task_id}}"; \
  _tilde(){ case "$1" in "$HOME") printf '~';; "$HOME"/*) printf '~/%s' "${1#"$HOME"/}";; *) printf '%s' "$1";; esac; }; \
  dry="${DRY_RUN:-}"; \
  extra=( {{repos}} ); \
  _ex=(); for _x in "${extra[@]}"; do [ -n "${_x:-}" ] && _ex+=("$_x"); done; extra=("${_ex[@]}"); \
  proj='{{project}}'; \
  cwd="$(pwd -P)"; \
  if [ -z "$typ" ]; then case "$cwd/" in "$project_dir"/*/*) rel="${cwd#"$project_dir/"}"; typ="${rel%%/*}" ;; esac; fi; \
  if [ -z "$tid" ]; then case "$cwd/" in "$project_dir"/*/*) rel="${cwd#"$project_dir/"}"; _t="${rel%%/*}"; _rest="${rel#"$_t/"}"; _id="${_rest%%/*}"; [ -n "$typ" ] || typ="$_t"; tid="$_id" ;; esac; fi; \
  if { [ -n "$typ" ] && [ -z "$tid" ]; } || { [ -z "$typ" ] && [ -n "$tid" ]; } || [ ${#extra[@]} -gt 0 ]; then \
    if [ -z "$typ" ] || [ -z "$tid" ]; then \
      command -v fzf >/dev/null 2>&1 || { printf 'drop: missing type/task_id (pass them, cd under %s/<type>/<task-id>, or install fzf)\n' "$project_dir" >&2; exit 1; }; \
      if [ -z "$typ" ]; then \
        _cand=(); while IFS= read -r _line; do [ -n "${_line:-}" ] && _cand+=("$_line"); done < <(find "$project_dir" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | while IFS= read -r _p; do [ -z "$_p" ] && continue; printf '%s\n' "${_p##*/}"; done | sort); \
        [ ${#_cand[@]} -gt 0 ] || { printf 'drop: no task types found under %s\n' "$project_dir" >&2; exit 1; }; \
        typ="$(printf '%s\n' "${_cand[@]}" | fzf --height 60% --layout reverse --header-first --header 'drop | select type' --prompt 'type> ' || true)"; \
        [ -n "$typ" ] || { printf 'drop: cancelled\n' >&2; exit 0; }; \
      fi; \
      if [ -z "$tid" ]; then \
        _cand=(); while IFS= read -r _line; do [ -n "${_line:-}" ] && _cand+=("$_line"); done < <(find "$project_dir/$typ" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | while IFS= read -r _p; do [ -z "$_p" ] && continue; printf '%s\n' "${_p##*/}"; done | sort); \
        [ ${#_cand[@]} -gt 0 ] || { printf 'drop: no task ids under type %s\n' "$typ" >&2; exit 1; }; \
        tid="$(printf '%s\n' "${_cand[@]}" | fzf --height 60% --layout reverse --header-first --header 'drop | select task-id (newest first)' --prompt 'task-id> ' || true)"; \
        [ -n "$tid" ] || { printf 'drop: cancelled\n' >&2; exit 0; }; \
      fi; \
    fi; \
  fi; \
  _org_for_link() { \
    local link="$1"; \
    local ws="$task_dir/$link"; \
    if [ -f "$task_dir/task.json" ]; then \
      python3 -c 'import json,sys; link=sys.argv[2]; r=json.load(open(sys.argv[1])).get("repos",{}); print(r.get(link,""))' "$task_dir/task.json" "$link"; \
    elif [ -e "$ws/.git" ]; then \
      local gd rd prefix; \
      gd="$(git -C "$ws" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)" || { printf ""; return; }; \
      rd="$(dirname "$gd")"; rd="$(cd "$rd" && pwd -P)"; \
      prefix="$(cd "{{REPOS_ROOT}}" && pwd -P)/"; \
      case "$rd" in "$prefix"*) printf "%s\n" "${rd#"$prefix"}" ;; *) printf "" ;; esac; \
    else \
      printf ""; \
    fi; \
  }; \
  _drop_one() { \
    local name="$1"; \
    local orgrepo="$2"; \
    [ -n "$orgrepo" ] || { printf "unknown repo key %s (missing task.json mapping)\n" "$name" >&2; return 1; }; \
    local ws="$task_dir/$name"; \
    case "$ws" in "$task_dir"/*) ;; *) printf "refusing: bad path %s\n" "$(_tilde "$ws")" >&2; return 1 ;; esac; \
    local repo_dir="{{REPOS_ROOT}}/$orgrepo"; \
    local ws_name="$proj-$typ-$tid-$name"; \
    if [ -d "$ws/.git" ] && [ -d "$repo_dir/.git" ]; then \
      if [ "$dry" = "1" ]; then printf "[dry-run] git -C %s worktree remove %s\n" "$(_tilde "$repo_dir")" "$(_tilde "$ws")"; \
      else git -C "$repo_dir" worktree remove "$ws" >/dev/null 2>&1 || rm -rf "$ws"; fi; \
    elif [ -d "$ws/.jj" ] && [ -d "$repo_dir/.jj" ] && command -v jj >/dev/null 2>&1; then \
      if jj --no-pager --repository "$repo_dir" workspace list 2>/dev/null | awk -F: -v n="$ws_name" '$1==n{found=1} END{exit found!=1}'; then \
        if [ "$dry" = "1" ]; then printf "[dry-run] jj -R %s workspace forget %s\n" "$(_tilde "$repo_dir")" "$ws_name"; \
        else jj --no-pager --repository "$repo_dir" --ignore-working-copy workspace forget "$ws_name" || { printf "jj workspace forget failed for %s\n" "$ws_name" >&2; return 1; }; fi; \
      else printf "jj workspace %s not registered; removing dir only\n" "$ws_name" >&2; \
      fi; \
      if [ "$dry" = "1" ]; then printf "[dry-run] rm -rf %s\n" "$(_tilde "$ws")"; \
      elif [ -d "$ws" ]; then rm -rf "$ws"; fi; \
    else \
      if [ "$dry" = "1" ]; then printf "[dry-run] rm -rf %s\n" "$(_tilde "$ws")"; else rm -rf "$ws"; fi; \
    fi; \
  }; \
  if [ -z "$typ" ] && [ -z "$tid" ]; then \
    if [ ${#extra[@]} -ne 0 ]; then printf "drop project: extra arguments not allowed (drop each task with type and task_id to remove selected repos)\n" >&2; exit 1; fi; \
    case "$project_dir" in "{{PROJECTS_ROOT}}"/*) ;; *) printf "refusing: bad project path %s\n" "$(_tilde "$project_dir")" >&2; exit 1 ;; esac; \
    if [ ! -d "$project_dir" ]; then printf "project not found: %s\n" "$(_tilde "$project_dir")" >&2; exit 1; fi; \
    if [ "$dry" = "1" ]; then printf "[dry-run] drop entire project %s\n" "$(_tilde "$project_dir")" >&2; fi; \
    while IFS= read -r task_dir; do \
      [ -z "$task_dir" ] && continue; \
      rel="${task_dir#"$project_dir"/}"; \
      typ="${rel%%/*}"; tid="${rel#"$typ"/}"; \
      if [ -z "$typ" ] || [ -z "$tid" ]; then continue; fi; \
      if [ "$dry" = "1" ]; then printf "[dry-run] drop entire task %s\n" "$(_tilde "$task_dir")" >&2; \
      else \
        while IFS= read -r name; do \
          [ -n "$name" ] || continue; \
          org="$(_org_for_link "$name")"; \
          _drop_one "$name" "$org" || exit 1; \
        done < <(if [ -f "$task_dir/task.json" ]; then python3 -c 'import json,sys; print("\n".join(json.load(open(sys.argv[1])).get("repos",{}).keys()))' "$task_dir/task.json"; else shopt -s nullglob; for _d in "$task_dir"/*; do b="$(basename "$_d")"; [ "$b" = task.json ] && continue; [ -d "$_d/.git" ] || [ -d "$_d/.jj" ] || continue; printf "%s\n" "$b"; done; fi); \
        rm -f "$task_dir/task.json"; \
        rmdir "$task_dir" 2>/dev/null || rm -rf "$task_dir"; \
      fi; \
    done < <(find "$project_dir" -mindepth 2 -maxdepth 2 -type d 2>/dev/null || true); \
    if [ "$dry" = "1" ]; then printf "[dry-run] rm -rf %s\n" "$(_tilde "$project_dir")" >&2; \
    else rm -rf "$project_dir"; fi; \
    printf "dropped project %s\n" "$(_tilde "$project_dir")"; \
    exit 0; \
  fi; \
  if { [ -n "$typ" ] && [ -z "$tid" ]; } || { [ -z "$typ" ] && [ -n "$tid" ]; }; then \
    printf "drop: pass both type and task_id, or neither to drop the whole project\n" >&2; exit 1; \
  fi; \
  task_dir="$project_dir/$typ/$tid"; \
  if [ ! -d "$task_dir" ]; then printf "task not found: %s\n" "$(_tilde "$task_dir")" >&2; exit 1; fi; \
  if [ "$dry" = "1" ]; then printf "[dry-run] drop\n" >&2; fi; \
  if [ ${#extra[@]} -eq 0 ]; then \
    if [ "$dry" = "1" ]; then printf "[dry-run] drop entire task %s\n" "$(_tilde "$task_dir")" >&2; \
    else \
      while IFS= read -r name; do \
        [ -n "$name" ] || continue; \
        org="$(_org_for_link "$name")"; \
        _drop_one "$name" "$org" || exit 1; \
      done < <(if [ -f "$task_dir/task.json" ]; then python3 -c 'import json,sys; print("\n".join(json.load(open(sys.argv[1])).get("repos",{}).keys()))' "$task_dir/task.json"; else shopt -s nullglob; for _d in "$task_dir"/*; do b="$(basename "$_d")"; [ "$b" = task.json ] && continue; [ -d "$_d/.git" ] || [ -d "$_d/.jj" ] || continue; printf "%s\n" "$b"; done; fi); \
      rm -f "$task_dir/task.json"; \
      rmdir "$task_dir" 2>/dev/null || rm -rf "$task_dir"; \
      printf "dropped %s\n" "$(_tilde "$task_dir")"; \
    fi; \
  else \
    for name in "${extra[@]}"; do \
      [ -z "$name" ] && continue; \
      org="$(_org_for_link "$name")"; \
      _drop_one "$name" "$org" || exit 1; \
    done; \
    if [ -f "$task_dir/task.json" ] && [ "$dry" != "1" ]; then \
      python3 -c "import json,pathlib,sys; p=pathlib.Path(sys.argv[1]); rm=set(sys.argv[2:]); d=json.load(open(p)); r={k:v for k,v in d.get('repos',{}).items() if k not in rm}; (json.dump({**d,'repos':r},open(p,'w'),indent=2) if r else p.unlink())" "$task_dir/task.json" "${extra[@]}"; \
      rmdir "$task_dir" 2>/dev/null || true; \
    fi; \
    printf "dropped selected repos under %s\n" "$(_tilde "$task_dir")"; \
  fi

# Default when invoked with `just -f .../project_tasks.just`.
default:
  @just --list
