# Global Instructions

Use this file as the canonical, vendor-agnostic global instruction source.

- Load matching skills before acting when a trigger condition applies.
- Keep commits atomic and branch naming consistent across related repos. For
  message shape: agents and automation **always** include a short commit body
  unless the user marks the change trivial-only (see `commit-messages.md`).
- For multi-repo changes, identify dependencies and land updates in order.
- Remove temporary dependency overrides before PRs leave draft.
- For file-content searches, prefer `rg` (ripgrep) over `grep -r` when `rg` is
  installed (see `core-principles.md`).
- A GitHub `#N` can be a PR, an issue, or a stacked-PR stack; all three use one
  number sequence per repo, and "stack #N" means a stack. Resolve an unfamiliar
  `#N` with `gh-ref N` (or `gh api repos/{owner}/{repo}/stacks/N`) before saying
  it doesn't exist. A 404 from `gh pr view` is not enough evidence.

See companion policy modules in this directory:

- `commit-messages.md`
- `core-principles.md`
- `cross-repo-workflow.md`
- `live-interaction-safety.md`
- `skill-routing.md`
