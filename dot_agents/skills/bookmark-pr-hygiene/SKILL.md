---
name: bookmark-pr-hygiene
description: >-
  Audit and prune stale local branch/bookmark heads using remote default-branch
  and PR state as authority. Use when asked to clean up merged heads, find
  outstanding work, or run bookmark/branch hygiene.
---

# Branch/bookmark PR hygiene

Use this skill to classify local non-default heads as landed vs outstanding,
then prune only safe landed heads.

## Authority model

- Remote repository metadata (via `gh`) is authoritative.
- Default branch is resolved dynamically from the remote.
- PR state is used to handle squash/rebase merges where commit ancestry alone
  is not sufficient.

## Commands

- Audit only:

      just repos::hygiene

- Prune safe landed heads:

      CONFIRM=1 just repos::hygiene-prune

- In git mode, also delete matching remote branches on `origin`:

      CONFIRM=1 PRUNE_REMOTE=1 just repos::hygiene-prune

Optional repo override:

    just repos::hygiene -- -R <org/repo>

## States

- `landed_on_default` -> prune-safe.
- `landed_via_pr_exact_head` -> prune-safe.
- `open_pr` -> keep.
- `merged_and_open_conflict` -> keep and review patch.
- `landed_via_pr_head_mismatch` -> keep and review patch.
- `wrong_base_merged` -> keep and review patch.
- `no_pr` -> keep and review patch.
- `unknown_remote_sha` -> keep and review patch.
- `ambiguous_multi_merged` -> keep and review patch.

## Safety notes

- Prefer running from a canonical checkout (`git` repo or jj colocated repo).
- Running from git worktrees or jj workspaces is supported, but canonical repo
  context is less ambiguous.
- Prune requires `CONFIRM=1`.
- Git remote deletion is opt-in via `PRUNE_REMOTE=1`.
