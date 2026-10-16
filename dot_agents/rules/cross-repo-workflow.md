# Cross-Repo Workflow

- For changes spanning multiple repositories, identify all impacted repos before
  editing.
- Keep branch or bookmark naming aligned across repos for the same task.
- Track dependency edges explicitly (which repo depends on which artifact).
- Land PRs in dependency order and note blocking relationships.
- Verify CI status per repo, not just in the origin repo.

## Rewriting your own PR branches

- Under jj, rebasing and force-pushing the user's own PR branches is the normal
  workflow. Do not ask for confirmation first.
- Before pushing, verify each remote head equals the commit the local stack was
  built from (or holds no remote-only work), so no desired change is lost. If
  that check passes, push.
- Stop and ask only when the check fails, or when the target is a shared or
  default branch (`master` / `main`).
