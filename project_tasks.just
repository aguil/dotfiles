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

# Scaffold tasks/<type>/<task-id>/ and an empty task.json (repos:{}). Clone canonical repos and add worktrees yourself, then just add. DRY_RUN=1 skips writes.
new type task_id: _ensure_project
  @project_dir="{{PROJECTS_ROOT}}/{{project}}"; \
  task_dir="$project_dir/tasks/{{type}}/{{task_id}}"; \
  dry="${DRY_RUN:-}"; \
  if [ -f "$task_dir/task.json" ]; then printf "task already exists: %s\n" "$task_dir" >&2; exit 1; fi; \
  if [ "$dry" = "1" ]; then \
    printf "[dry-run] new: would create %s with empty repos in task.json\n" "$task_dir" >&2; \
  else \
    mkdir -p "$task_dir"; \
    python3 -c "import json,pathlib,sys; td,proj,typ,tid=sys.argv[1:5]; json.dump({'project':proj,'type':typ,'task_id':tid,'repos':{}},open(pathlib.Path(td)/'task.json','w'),indent=2)" \
      "$task_dir" "{{project}}" "{{type}}" "{{task_id}}"; \
  fi; \
  printf "%s\n" "$task_dir"

# Add repo(s) to an existing task (workspace / git worktree only; canonical must already exist under repos/). Pass one or more org/repo; optional shared base is the last arg if it contains no '/'. Default base master.
add type task_id *repos: _ensure_project
  @project_dir="{{PROJECTS_ROOT}}/{{project}}"; \
  task_dir="$project_dir/tasks/{{type}}/{{task_id}}"; \
  dry="${DRY_RUN:-}"; \
  if [ ! -d "$task_dir" ]; then printf "task not found: %s\n" "$task_dir" >&2; exit 1; fi; \
  _args=( {{repos}} ); \
  _clean=(); for _a in "${_args[@]}"; do [ -n "${_a:-}" ] && _clean+=("$_a"); done; \
  if [ ${#_clean[@]} -eq 0 ]; then printf "add: pass at least one org/repo\n" >&2; exit 1; fi; \
  repos=("${_clean[@]}"); base=master; \
  if [ ${#_clean[@]} -ge 2 ]; then \
    _li=$((${#_clean[@]} - 1)); \
    _last="${_clean[$_li]}"; \
    case "$_last" in */*) ;; *) base="$_last"; repos=("${_clean[@]:0:${_li}}"); ;; esac; \
  fi; \
  if [ ${#repos[@]} -eq 0 ]; then printf "add: pass at least one org/repo\n" >&2; exit 1; fi; \
  branch="{{type}}/{{project}}/{{task_id}}"; \
  if [ "$dry" = "1" ]; then \
    for orgrepo in "${repos[@]}"; do \
      link_name="${orgrepo##*/}"; \
      ws_dir="$task_dir/$link_name"; \
      printf "[dry-run] add %s -> %s (base=%s)\n" "$orgrepo" "$ws_dir" "$base" >&2; \
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
      printf "add: canonical repo missing at %s (clone it there first, then re-run add)\n" "$repo_dir" >&2; \
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
    printf "%s\n" "$ws_dir"; \
  done

# List task directories; optional type filters to tasks/<type>/*.
list type="": _ensure_project
  @root="{{PROJECTS_ROOT}}/{{project}}/tasks"; \
  if [ ! -d "$root" ]; then exit 0; fi; \
  if [ -n "{{type}}" ]; then \
    find "$root/{{type}}" -mindepth 1 -maxdepth 1 -type d 2>/dev/null || true; \
  else \
    find "$root" -mindepth 2 -maxdepth 2 -type d 2>/dev/null || true; \
  fi

# Forget jj workspace / remove git worktree for repos (or entire task if no repo names). Removes task.json. DRY_RUN=1 prints only.
# Omit type and task_id to drop the whole project (all tasks under projects/<project>/, then remove that directory).
drop type="" task_id="" *repos: _ensure_project
  @project_dir="{{PROJECTS_ROOT}}/{{project}}"; \
  dry="${DRY_RUN:-}"; \
  extra=( {{repos}} ); \
  _ex=(); for _x in "${extra[@]}"; do [ -n "${_x:-}" ] && _ex+=("$_x"); done; extra=("${_ex[@]}"); \
  proj='{{project}}'; \
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
    case "$ws" in "$task_dir"/*) ;; *) printf "refusing: bad path %s\n" "$ws" >&2; return 1 ;; esac; \
    local repo_dir="{{REPOS_ROOT}}/$orgrepo"; \
    local ws_name="$proj-$typ-$tid-$name"; \
    if [ -d "$ws/.git" ] && [ -d "$repo_dir/.git" ]; then \
      if [ "$dry" = "1" ]; then printf "[dry-run] git -C %s worktree remove %s\n" "$repo_dir" "$ws"; \
      else git -C "$repo_dir" worktree remove "$ws" >/dev/null 2>&1 || rm -rf "$ws"; fi; \
    elif [ -d "$ws/.jj" ] && [ -d "$repo_dir/.jj" ] && command -v jj >/dev/null 2>&1; then \
      if jj --no-pager --repository "$repo_dir" workspace list 2>/dev/null | awk -F: -v n="$ws_name" '$1==n{found=1} END{exit found!=1}'; then \
        if [ "$dry" = "1" ]; then printf "[dry-run] jj -R %s workspace forget %s\n" "$repo_dir" "$ws_name"; \
        else jj --no-pager --repository "$repo_dir" --ignore-working-copy workspace forget "$ws_name" || { printf "jj workspace forget failed for %s\n" "$ws_name" >&2; return 1; }; fi; \
      else printf "jj workspace %s not registered; removing dir only\n" "$ws_name" >&2; \
      fi; \
      if [ "$dry" = "1" ]; then printf "[dry-run] rm -rf %s\n" "$ws"; \
      elif [ -d "$ws" ]; then rm -rf "$ws"; fi; \
    else \
      if [ "$dry" = "1" ]; then printf "[dry-run] rm -rf %s\n" "$ws"; else rm -rf "$ws"; fi; \
    fi; \
  }; \
  if [ -z "{{type}}" ] && [ -z "{{task_id}}" ]; then \
    if [ ${#extra[@]} -ne 0 ]; then printf "drop project: extra arguments not allowed (drop each task with type and task_id to remove selected repos)\n" >&2; exit 1; fi; \
    case "$project_dir" in "{{PROJECTS_ROOT}}"/*) ;; *) printf "refusing: bad project path %s\n" "$project_dir" >&2; exit 1 ;; esac; \
    if [ ! -d "$project_dir" ]; then printf "project not found: %s\n" "$project_dir" >&2; exit 1; fi; \
    if [ "$dry" = "1" ]; then printf "[dry-run] drop entire project %s\n" "$project_dir" >&2; fi; \
    tasks_root="$project_dir/tasks"; \
    if [ -d "$tasks_root" ]; then \
      while IFS= read -r task_dir; do \
        [ -z "$task_dir" ] && continue; \
        rel="${task_dir#"$tasks_root"/}"; \
        typ="${rel%%/*}"; tid="${rel#"$typ"/}"; \
        if [ -z "$typ" ] || [ -z "$tid" ]; then continue; fi; \
        if [ "$dry" = "1" ]; then printf "[dry-run] drop entire task %s\n" "$task_dir" >&2; \
        else \
          while IFS= read -r name; do \
            [ -n "$name" ] || continue; \
            org="$(_org_for_link "$name")"; \
            _drop_one "$name" "$org" || exit 1; \
          done < <(if [ -f "$task_dir/task.json" ]; then python3 -c 'import json,sys; print("\n".join(json.load(open(sys.argv[1])).get("repos",{}).keys()))' "$task_dir/task.json"; else shopt -s nullglob; for _d in "$task_dir"/*; do b="$(basename "$_d")"; [ "$b" = task.json ] && continue; [ -d "$_d/.git" ] || [ -d "$_d/.jj" ] || continue; printf "%s\n" "$b"; done; fi); \
          rm -f "$task_dir/task.json"; \
          rmdir "$task_dir" 2>/dev/null || rm -rf "$task_dir"; \
        fi; \
      done < <(find "$tasks_root" -mindepth 2 -maxdepth 2 -type d 2>/dev/null || true); \
    fi; \
    if [ "$dry" = "1" ]; then printf "[dry-run] rm -rf %s\n" "$project_dir" >&2; \
    else rm -rf "$project_dir"; fi; \
    printf "dropped project %s\n" "$project_dir"; \
    exit 0; \
  fi; \
  if { [ -n "{{type}}" ] && [ -z "{{task_id}}" ]; } || { [ -z "{{type}}" ] && [ -n "{{task_id}}" ]; }; then \
    printf "drop: pass both type and task_id, or neither to drop the whole project\n" >&2; exit 1; \
  fi; \
  task_dir="$project_dir/tasks/{{type}}/{{task_id}}"; \
  typ='{{type}}'; tid='{{task_id}}'; \
  if [ ! -d "$task_dir" ]; then printf "task not found: %s\n" "$task_dir" >&2; exit 1; fi; \
  if [ "$dry" = "1" ]; then printf "[dry-run] drop\n" >&2; fi; \
  if [ ${#extra[@]} -eq 0 ]; then \
    if [ "$dry" = "1" ]; then printf "[dry-run] drop entire task %s\n" "$task_dir" >&2; \
    else \
      while IFS= read -r name; do \
        [ -n "$name" ] || continue; \
        org="$(_org_for_link "$name")"; \
        _drop_one "$name" "$org" || exit 1; \
      done < <(if [ -f "$task_dir/task.json" ]; then python3 -c 'import json,sys; print("\n".join(json.load(open(sys.argv[1])).get("repos",{}).keys()))' "$task_dir/task.json"; else shopt -s nullglob; for _d in "$task_dir"/*; do b="$(basename "$_d")"; [ "$b" = task.json ] && continue; [ -d "$_d/.git" ] || [ -d "$_d/.jj" ] || continue; printf "%s\n" "$b"; done; fi); \
      rm -f "$task_dir/task.json"; \
      rmdir "$task_dir" 2>/dev/null || rm -rf "$task_dir"; \
      printf "dropped %s\n" "$task_dir"; \
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
    printf "dropped selected repos under %s\n" "$task_dir"; \
  fi

# Default when invoked with `just -f .../project_tasks.just`.
default:
  @just --list
