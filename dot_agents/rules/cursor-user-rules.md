# Cursor User Rules Seed

Paste or adapt these into Cursor Settings -> Rules -> User Rules.

- Read the matching skill before acting when a trigger applies.
- For VCS actions, use the repository's native VCS safely.
- For cross-repo tasks, keep branch naming consistent across repositories.
- Keep commits isolated to one logical change.
- Remove temporary dependency overrides before promoting a PR out of draft.
- For file-content searches, use `rg` (ripgrep) instead of `grep -r` when `rg`
  is installed.
- After opening a PR, run the `visual-pr` skill on it; this rule counts as
  explicit invocation by name. In a `.jj` repo use jj for its commit and push
  steps. If `.humanlayer/` doesn't exist, save the description outside the repo.
  Keep existing PR body content under `## Details`, and keep any required
  attribution line at the end of the PR body.
- Open PRs as drafts. Mark one ready only after `self-review-checks` covers its
  current head; a rebase needs a new review.
