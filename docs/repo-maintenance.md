# Repo maintenance

This document covers lightweight repository maintenance helpers that are not
specific to project-task workspace flows.

## Branch/bookmark PR hygiene

Use these commands to identify local non-default heads that are already landed,
still in-flight, or ambiguous.

Audit current repository:

```bash
just repos::hygiene
```

Prune only heads classified as safe landed states:

```bash
CONFIRM=1 just repos::hygiene-prune
```

In git mode, also delete matching remote `origin/*` branches only when
explicitly enabled:

```bash
CONFIRM=1 PRUNE_REMOTE=1 just repos::hygiene-prune
```

Optional explicit repo override:

```bash
just repos::hygiene -- -R org/repo
```

### Authority and safety model

- Uses GitHub remote metadata and the remote default branch as authority.
- Resolves default branch dynamically (no hardcoded `master`/`main`).
- Accounts for squash/rebase merges using merged PR metadata.
- Requires `CONFIRM=1` for prune execution.
- In git mode, remote branch deletion is disabled by default.

### Where to run it

- Preferred: canonical repo checkouts (git repo or jj colocated repo).
- Supported: git worktrees and jj workspaces.
- In git worktrees, local branch deletion uses `git branch -d` and skips
  branches checked out elsewhere or not fully merged.

### Classification states

| State | Prune | Review patch |
|---|---|---|
| `landed_on_default` | yes | no |
| `landed_via_pr_exact_head` | yes | no |
| `open_pr` | no | no |
| `merged_and_open_conflict` | no | yes |
| `landed_via_pr_head_mismatch` | no | yes |
| `wrong_base_merged` | no | yes |
| `no_pr` | no | yes |
| `unknown_remote_sha` | no | yes |
| `ambiguous_multi_merged` | no | yes |
