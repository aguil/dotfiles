# Cross-Repo Workflow

- For changes spanning multiple repositories, identify all impacted repos
  before editing.
- Keep branch or bookmark naming aligned across repos for the same task.
- Track dependency edges explicitly (which repo depends on which artifact).
- Land PRs in dependency order and note blocking relationships.
- Verify CI status per repo, not just in the origin repo.
