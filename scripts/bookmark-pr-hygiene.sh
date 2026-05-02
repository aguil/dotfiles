#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: bookmark-pr-hygiene.sh [audit|prune] [-R org/repo]

Modes:
  audit   Classify non-default heads as landed/outstanding (default)
  prune   Remove only safe landed heads (requires CONFIRM=1)

Env:
  CONFIRM=1      Required for prune mode
  PRUNE_REMOTE=1 In git mode, also delete remote branches on origin

Notes:
  - Uses remote default branch and PR state as authority.
  - Auto-detects jj or git mode from current working directory.
EOF
}

die() {
  printf '%s\n' "$*" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"
}

MODE="audit"
REPO=""

while [ $# -gt 0 ]; do
  case "$1" in
    audit|prune)
      MODE="$1"
      ;;
    -R|--repo)
      [ $# -ge 2 ] || die "missing value for $1"
      REPO="$2"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "unknown argument: $1"
      ;;
  esac
  shift
done

require_cmd gh

JJ_AVAILABLE=0
if command -v jj >/dev/null 2>&1; then
  JJ_AVAILABLE=1
fi

GIT_AVAILABLE=0
if command -v git >/dev/null 2>&1; then
  GIT_AVAILABLE=1
fi

VCS_MODE=""
REPO_ROOT=""

if [ "$JJ_AVAILABLE" -eq 1 ] && jj root >/dev/null 2>&1; then
  REPO_ROOT="$(jj root)"
  if [ -d "$REPO_ROOT/.jj" ] && [ -d "$REPO_ROOT/.git" ]; then
    VCS_MODE="jj-colocated"
  elif [ -f "$REPO_ROOT/.jj/repo" ] && [ ! -e "$REPO_ROOT/.git" ]; then
    VCS_MODE="jj-workspace"
  else
    VCS_MODE="jj"
  fi
elif [ "$GIT_AVAILABLE" -eq 1 ] && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  REPO_ROOT="$(git rev-parse --show-toplevel)"
  git_dir="$(git rev-parse --git-dir)"
  git_common_dir="$(git rev-parse --git-common-dir)"
  if [ "$git_dir" = "$git_common_dir" ]; then
    VCS_MODE="git-repo"
  else
    VCS_MODE="git-worktree"
  fi
else
  die "not inside a jj or git repository"
fi

github_repo_from_url() {
  local url="$1"
  local parsed=""

  case "$url" in
    git@github.com:*.git)
      parsed="${url#git@github.com:}"
      parsed="${parsed%.git}"
      ;;
    git@github.com:*)
      parsed="${url#git@github.com:}"
      ;;
    https://github.com/*.git)
      parsed="${url#https://github.com/}"
      parsed="${parsed%.git}"
      ;;
    https://github.com/*)
      parsed="${url#https://github.com/}"
      ;;
  esac

  case "$parsed" in
    */*) printf '%s' "$parsed" ;;
    *) printf '' ;;
  esac
}

resolve_repo_from_remotes() {
  local remote_url=""
  local parsed=""

  case "$VCS_MODE" in
    jj|jj-colocated|jj-workspace)
      if [ "$JJ_AVAILABLE" -eq 1 ]; then
        remote_url="$(jj git remote list 2>/dev/null | while read -r name url; do if [ "$name" = "origin" ]; then printf '%s' "$url"; break; fi; done)"
        if [ -z "$remote_url" ]; then
          remote_url="$(jj git remote list 2>/dev/null | while read -r _name _url; do printf '%s' "$_url"; break; done)"
        fi
      fi
      ;;
    git-repo|git-worktree)
      if [ "$GIT_AVAILABLE" -eq 1 ]; then
        remote_url="$(git remote get-url origin 2>/dev/null || true)"
        if [ -z "$remote_url" ]; then
          remote_url="$(git remote -v 2>/dev/null | while read -r _name _url _rest; do printf '%s' "$_url"; break; done)"
        fi
      fi
      ;;
  esac

  [ -n "$remote_url" ] || return 1

  parsed="$(github_repo_from_url "$remote_url")"
  [ -n "$parsed" ] || return 1

  printf '%s' "$parsed"
}

if [ -z "$REPO" ]; then
  REPO="$(gh repo view --json nameWithOwner --jq '.nameWithOwner' 2>/dev/null || true)"
  if [ -z "$REPO" ]; then
    REPO="$(resolve_repo_from_remotes 2>/dev/null || true)"
  fi
  [ -n "$REPO" ] || die "unable to resolve GitHub repo from cwd; pass -R <org/repo>"
fi

DEFAULT_BRANCH="$(gh repo view "$REPO" --json defaultBranchRef --jq '.defaultBranchRef.name' 2>/dev/null || true)"
[ -n "$DEFAULT_BRANCH" ] || die "unable to resolve default branch for $REPO"

declare -a HEAD_NAMES=()
declare -A HEAD_SHA=()

collect_jj_heads() {
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    case "$line" in
      ' '*) continue ;;
    esac
    name="${line%%:*}"
    [ -n "$name" ] || continue
    [ "$name" = "$DEFAULT_BRANCH" ] && continue
    case "$line" in
      *"(deleted)"*) continue ;;
    esac

    sha_lines="$(jj log -r "$name" --no-graph -T 'commit_id ++ "\n"' 2>/dev/null || true)"
    sha_count=0
    first_sha=""
    while IFS= read -r sha; do
      [ -n "$sha" ] || continue
      sha_count=$((sha_count + 1))
      if [ -z "$first_sha" ]; then
        first_sha="$sha"
      fi
    done <<< "$sha_lines"

    HEAD_NAMES+=("$name")
    if [ "$sha_count" -eq 1 ]; then
      HEAD_SHA["$name"]="$first_sha"
    else
      HEAD_SHA["$name"]="MULTI"
    fi
  done < <(jj bookmark list)
}

collect_git_heads() {
  while IFS=$'\t' read -r name sha; do
    [ -n "$name" ] || continue
    [ "$name" = "$DEFAULT_BRANCH" ] && continue
    HEAD_NAMES+=("$name")
    HEAD_SHA["$name"]="$sha"
  done < <(git for-each-ref refs/heads --format='%(refname:short)	%(objectname)')
}

case "$VCS_MODE" in
  jj|jj-colocated|jj-workspace)
    collect_jj_heads
    ;;
  git-repo|git-worktree)
    collect_git_heads
    ;;
esac

if [ "$VCS_MODE" = "jj-workspace" ] || [ "$VCS_MODE" = "git-worktree" ]; then
  printf 'Warning: running from %s; canonical repo checkout is preferred.\n\n' "$VCS_MODE"
fi

if [ ${#HEAD_NAMES[@]} -eq 0 ]; then
  printf 'Mode: %s\nRepo: %s\nDefault branch: %s\n\n' "$VCS_MODE" "$REPO" "$DEFAULT_BRANCH"
  printf 'No non-default local heads found.\n'
  exit 0
fi

get_open_pr_count() {
  local head="$1"
  gh pr list -R "$REPO" --state open --search "head:$head" \
    --json headRefName --jq "[.[] | select(.headRefName==\"$head\")] | length"
}

get_merged_pr_metrics() {
  local head="$1"
  local sha="$2"

  merged_total=$(gh pr list -R "$REPO" --state merged --search "head:$head" \
    --json headRefName --jq "[.[] | select(.headRefName==\"$head\")] | length")

  merged_default=$(gh pr list -R "$REPO" --state merged --search "head:$head" \
    --json headRefName,baseRefName --jq "[.[] | select(.headRefName==\"$head\" and .baseRefName==\"$DEFAULT_BRANCH\")] | length")

  merged_default_exact=0
  if [ "$sha" != "MULTI" ] && [ -n "$sha" ]; then
    merged_default_exact=$(gh pr list -R "$REPO" --state merged --search "head:$head" \
      --json headRefName,baseRefName,headRefOid --jq "[.[] | select(.headRefName==\"$head\" and .baseRefName==\"$DEFAULT_BRANCH\" and .headRefOid==\"$sha\")] | length")
  fi
}

get_compare_status() {
  local sha="$1"
  if [ "$sha" = "MULTI" ] || [ -z "$sha" ]; then
    printf 'unknown'
    return 0
  fi

  local status
  status="$(gh api "repos/$REPO/compare/$DEFAULT_BRANCH...$sha" --jq '.status' 2>/dev/null || true)"
  if [ -z "$status" ]; then
    printf 'unknown'
  else
    printf '%s' "$status"
  fi
}

declare -a REPORT_LINES=()
declare -a PRUNE_CANDIDATES=()

for head in "${HEAD_NAMES[@]}"; do
  sha="${HEAD_SHA[$head]}"

  open_count="$(get_open_pr_count "$head")"
  get_merged_pr_metrics "$head" "$sha"
  compare_status="$(get_compare_status "$sha")"

  state=""
  review_patch="no"
  prune_safe="no"
  reason=""

  if [ "$sha" = "MULTI" ]; then
    state="ambiguous_multi_merged"
    review_patch="yes"
    reason="conflicting local head revisions"
  elif [ "$open_count" -gt 0 ] && [ "$merged_total" -gt 0 ]; then
    state="merged_and_open_conflict"
    review_patch="yes"
    reason="both open and merged PRs exist"
  elif [ "$open_count" -gt 0 ]; then
    state="open_pr"
    reason="open PR exists"
  elif [ "$compare_status" = "behind" ] || [ "$compare_status" = "identical" ]; then
    state="landed_on_default"
    prune_safe="yes"
    reason="head commit is ancestor of default branch"
  elif [ "$merged_default" -gt 0 ] && [ "$merged_default_exact" -gt 0 ]; then
    state="landed_via_pr_exact_head"
    prune_safe="yes"
    reason="merged PR to default has exact head SHA"
  elif [ "$merged_default" -gt 1 ]; then
    state="ambiguous_multi_merged"
    review_patch="yes"
    reason="multiple merged PRs for head name"
  elif [ "$merged_default" -eq 1 ]; then
    state="landed_via_pr_head_mismatch"
    review_patch="yes"
    reason="merged PR exists but head SHA differs"
  elif [ "$merged_total" -gt 0 ]; then
    state="wrong_base_merged"
    review_patch="yes"
    reason="merged PR exists on non-default base"
  elif [ "$compare_status" = "unknown" ]; then
    state="unknown_remote_sha"
    review_patch="yes"
    reason="head SHA not known on remote"
  else
    state="no_pr"
    review_patch="yes"
    reason="no open or merged PR found"
  fi

  if [ "$prune_safe" = "yes" ]; then
    PRUNE_CANDIDATES+=("$head")
  fi

  REPORT_LINES+=("$state\t$head\t$sha\t$prune_safe\t$review_patch\t$reason")
done

printf 'Mode: %s\nRepo: %s\nDefault branch: %s\n\n' "$VCS_MODE" "$REPO" "$DEFAULT_BRANCH"
printf '%-33s %-40s %-12s %-8s %-8s %s\n' "STATE" "HEAD" "SHA" "PRUNE" "REVIEW" "REASON"
printf '%-33s %-40s %-12s %-8s %-8s %s\n' "-----" "----" "---" "-----" "------" "------"
for line in "${REPORT_LINES[@]}"; do
  IFS=$'\t' read -r state head sha prune_safe review_patch reason <<< "$line"
  short_sha="$sha"
  if [ "$sha" != "MULTI" ] && [ ${#sha} -gt 12 ]; then
    short_sha="${sha:0:12}"
  fi
  printf '%-33s %-40s %-12s %-8s %-8s %s\n' "$state" "$head" "$short_sha" "$prune_safe" "$review_patch" "$reason"
done

if [ "$MODE" != "prune" ]; then
  exit 0
fi

printf '\nPrune mode selected.\n'
if [ ${#PRUNE_CANDIDATES[@]} -eq 0 ]; then
  printf 'No prune-safe heads found.\n'
  exit 0
fi

printf 'Prune-safe heads:\n'
for head in "${PRUNE_CANDIDATES[@]}"; do
  printf '  - %s\n' "$head"
done

if [ "${CONFIRM:-}" != "1" ]; then
  printf '\nSkipping prune; set CONFIRM=1 to execute.\n'
  exit 0
fi

printf '\nExecuting prune...\n'

case "$VCS_MODE" in
  jj|jj-colocated|jj-workspace)
    jj bookmark delete "${PRUNE_CANDIDATES[@]}"
    jj git push --deleted
    ;;
  git-repo|git-worktree)
    deleted_local=()
    blocked_local=()
    current_branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
    for head in "${PRUNE_CANDIDATES[@]}"; do
      if [ "$current_branch" = "$head" ]; then
        blocked_local+=("$head(current)")
        continue
      fi
      if git branch -d "$head" >/dev/null 2>&1; then
        deleted_local+=("$head")
      else
        blocked_local+=("$head(checked-out-or-not-fully-merged)")
      fi
    done

    printf 'Local git branch prune results:\n'
    if [ ${#deleted_local[@]} -gt 0 ]; then
      for b in "${deleted_local[@]}"; do printf '  - deleted %s\n' "$b"; done
    else
      printf '  - no local branches deleted\n'
    fi
    if [ ${#blocked_local[@]} -gt 0 ]; then
      for b in "${blocked_local[@]}"; do printf '  - skipped %s\n' "$b"; done
    fi

    if [ "${PRUNE_REMOTE:-}" = "1" ]; then
      if git remote get-url origin >/dev/null 2>&1; then
        printf 'Remote prune enabled (origin).\n'
        for b in "${deleted_local[@]}"; do
          if git ls-remote --exit-code --heads origin "$b" >/dev/null 2>&1; then
            git push origin --delete "$b" >/dev/null
            printf '  - deleted remote origin/%s\n' "$b"
          fi
        done
      else
        printf 'Remote prune skipped: no origin remote configured.\n'
      fi
    else
      printf 'Remote prune disabled (set PRUNE_REMOTE=1 with CONFIRM=1 to enable).\n'
    fi
    ;;
esac

printf '\nPost-prune head snapshot:\n'
case "$VCS_MODE" in
  jj|jj-colocated|jj-workspace)
    jj bookmark list
    ;;
  git-repo|git-worktree)
    git for-each-ref refs/heads --format='%(refname:short)'
    ;;
esac
