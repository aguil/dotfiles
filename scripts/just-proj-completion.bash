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
  local line line_trimmed rest first_word
  line="${COMP_LINE:0:COMP_POINT}"
  line_trimmed="${line#${line%%[![:space:]]*}}"
  first_word="${line_trimmed%%[[:space:]]*}"
  # Allow absolute path to just (mise/shims) as well as bare `just`.
  [[ "$first_word" == just || "$first_word" == */just ]] || return 1

  rest="${line_trimmed#"${first_word}"}"
  rest="${rest#${rest%%[![:space:]]*}}"

  local parts=()
  read -r -a parts <<< "$rest"
  [ "${#parts[@]}" -gt 0 ] || return 1

  local recipe_token="${parts[0]}"
  [[ "$recipe_token" == proj::* ]] || return 1

  local recipe="${recipe_token#proj::}"
  # True only when the cursor sits after whitespace (new token), not merely
  # "there is a space somewhere" (e.g. between `just` and the recipe).
  local has_trailing_space=0
  [[ "$line" =~ [[:space:]]$ ]] && has_trailing_space=1

  local cur=""
  local arg_index=0
  if [ "$has_trailing_space" -eq 1 ]; then
    arg_index=${#parts[@]}
    cur=""
  else
    if [ "${#parts[@]}" -eq 1 ]; then
      # `just proj::list` with cursor at end (no trailing space): still
      # completing the first recipe argument (project), not the recipe name.
      case "$recipe" in
        init|list|add|status|push|drop)
          arg_index=1
          cur=""
          ;;
        *)
          return 1
          ;;
      esac
    else
      cur="${parts[$(( ${#parts[@]} - 1 ))]}"
      arg_index=$(( ${#parts[@]} - 1 ))
    fi
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
    add|status|push|drop)
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

_just_proj_register() {
  complete -F _just_with_proj_dynamic just
}

_just_with_proj_dynamic() {
  # Colon is in COMP_WORDBREAKS by default; strip it so delegated `_just` sees
  # `proj::…` as one word when we fall through.
  local _saved_wb="$COMP_WORDBREAKS"
  COMP_WORDBREAKS="${COMP_WORDBREAKS//:/}"

  if _just_proj_dynamic_complete; then
    COMP_WORDBREAKS="$_saved_wb"
    return 0
  fi

  # Newer just (clap) ships `_clap_complete_just`; older brew/bash files used `_just`.
  if declare -F _clap_complete_just >/dev/null 2>&1; then
    _clap_complete_just "$@"
    local _jr=$?
    COMP_WORDBREAKS="$_saved_wb"
    _just_proj_register
    return "$_jr"
  fi
  if declare -F _just >/dev/null 2>&1; then
    _just "$@"
    local _jr=$?
    COMP_WORDBREAKS="$_saved_wb"
    # Stock `_just` often invokes bash-completion's loader, which re-runs
    # `complete -F _just just` and drops our wrapper — put it back.
    _just_proj_register
    return "$_jr"
  fi

  COMP_WORDBREAKS="$_saved_wb"
  return 0
}

_just_proj_register
