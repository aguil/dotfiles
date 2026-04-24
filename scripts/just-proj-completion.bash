#!/usr/bin/env bash

_just_proj_complete_candidates() {
  local kind="$1"
  local projects_root="${DEV_ROOT:-$HOME/dev}/projects"
  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

  case "$kind" in
    projects)
      bash "$script_dir/proj-list-projects.sh" "$projects_root"
      ;;
    types)
      local project="${2:-}"
      [ -n "$project" ] || return 0
      bash "$script_dir/proj-list-types.sh" "$projects_root" "$project"
      ;;
    task_ids)
      local project="${2:-}"
      local type_name="${3:-}"
      [ -n "$project" ] || return 0
      [ -n "$type_name" ] || return 0
      bash "$script_dir/proj-list-tasks.sh" "$projects_root" "$project" "$type_name" |
        while IFS= read -r line; do
          [ -n "$line" ] || continue
          printf '%s\n' "${line#*/}"
        done
      ;;
  esac
}

_just_proj_dynamic_complete() {
  local line line_trimmed rest
  line="${COMP_LINE:0:COMP_POINT}"
  line_trimmed="${line#${line%%[![:space:]]*}}"
  [[ "$line_trimmed" == just* ]] || return 1

  rest="${line_trimmed#just}"
  rest="${rest#${rest%%[![:space:]]*}}"

  local parts=()
  read -r -a parts <<< "$rest"
  [ "${#parts[@]}" -gt 0 ] || return 1

  local recipe_token="${parts[0]}"
  [[ "$recipe_token" == proj::* ]] || return 1

  local recipe="${recipe_token#proj::}"
  local has_trailing_space=0
  [[ "$line" == *[[:space:]] ]] && has_trailing_space=1

  local cur=""
  local arg_index=0
  if [ "$has_trailing_space" -eq 1 ]; then
    arg_index=${#parts[@]}
  else
    if [ "${#parts[@]}" -eq 1 ]; then
      return 1
    fi
    cur="${parts[$(( ${#parts[@]} - 1 ))]}"
    arg_index=$(( ${#parts[@]} - 1 ))
  fi

  local project_arg="${parts[1]:-}"
  local type_arg="${parts[2]:-}"

  if type compopt >/dev/null 2>&1; then
    compopt +o default +o bashdefault 2>/dev/null || true
  fi

  case "$recipe" in
    init)
      if [ "$arg_index" -eq 1 ]; then
        COMPREPLY=( $(compgen -W "$(_just_proj_complete_candidates projects)" -- "$cur") )
        return 0
      fi
      ;;
    list)
      if [ "$arg_index" -eq 1 ]; then
        COMPREPLY=( $(compgen -W "$(_just_proj_complete_candidates projects)" -- "$cur") )
        return 0
      fi
      if [ "$arg_index" -eq 2 ] && [ -n "$project_arg" ]; then
        COMPREPLY=( $(compgen -W "$(_just_proj_complete_candidates types "$project_arg")" -- "$cur") )
        return 0
      fi
      ;;
    new|add|status|push|drop)
      if [ "$arg_index" -eq 1 ]; then
        COMPREPLY=( $(compgen -W "$(_just_proj_complete_candidates projects)" -- "$cur") )
        return 0
      fi
      if [ "$arg_index" -eq 2 ] && [ -n "$project_arg" ]; then
        COMPREPLY=( $(compgen -W "$(_just_proj_complete_candidates types "$project_arg")" -- "$cur") )
        return 0
      fi
      if [ "$arg_index" -eq 3 ] && [ -n "$project_arg" ] && [ -n "$type_arg" ]; then
        COMPREPLY=( $(compgen -W "$(_just_proj_complete_candidates task_ids "$project_arg" "$type_arg")" -- "$cur") )
        return 0
      fi
      ;;
  esac

  COMPREPLY=()
  return 1
}

_just_with_proj_dynamic() {
  if _just_proj_dynamic_complete; then
    return 0
  fi

  if declare -F _just >/dev/null 2>&1; then
    _just "$@"
    return 0
  fi

  return 0
}

complete -F _just_with_proj_dynamic just
