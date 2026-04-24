---
name: cross-repo-change
description: >-
  Run a change that spans 2+ repos in a project-task workspace end-to-end:
  ADR → draft PRs → implementation → dependency propagation → CI passing →
  ADR accepted → tracker transitioned. Use whenever work touches more than
  one checkout under `~/dev/projects/<project>/<type>/<task-id>/`.
---

# Cross-repo change workflow

This is the meta-skill for multi-repo tasks. It composes:
- `project-task-workspaces` (layout, VCS detection, task.json)
- `jujutsu` / `jj-cross-repo` (VCS mechanics)
- `dart-cross-repo` (language-specific dependency plumbing, if applicable)
- `ci-triage` (making CI green)

Organisation-specific conventions (tracker ID format, release-ref policy,
network preflight, extra test-runner integrations) live in the **work
overlay** — see `~/.agents/AGENTS.work.md` if it exists.

## Standard arc

1. **Discover scope.** Read `task.json`. The set of PRs that will exist is
   one per repo listed there — nothing more, nothing less. If the scope is
   actually different, update `task.json` via `just add`/`just drop` first.
2. **Draft the ADR** in the repo that owns the decision (usually the one
   introducing or consuming a new API). Other repos reference it in their
   PR descriptions.
3. **Open draft PRs up front** for every repo you will touch, even if empty.
   This lets you link them to each other in the descriptions and gives CI
   somewhere to run. See `BRANCHING.md` for titles and descriptions.
4. **Decide the dependency ladder** before coding — see
   `DEPENDENCY-OVERRIDES.md`. Know which direction consumers depend on
   producers, and which override strategy each PR will use while in flight.
5. **Implement per repo.** Keep changes for each repo **isolated in their
   own commits**. Don't squash unrelated fixes together: the user will ask
   for clean, reviewable commits, and restructuring later is expensive.
   One logical change per commit.
6. **Propagate dependencies** (producer → consumer order): once the
   producer PR has a stable branch tip, point the consumer's override at
   that branch, push, and confirm consumer CI. Repeat as the producer's
   tip moves.
7. **Triage CI** until green in every repo — see `ci-triage` skill.
8. **Remove overrides** before requesting review / merge. The final diff
   in each consumer PR must use a published version or a production-
   acceptable reference (tag/release), **never** a feature branch.
9. **Mark ADR accepted** once PRs are all approved (or merged, depending
   on project convention).
10. **Transition tracker** (Ready for Review → In Review → Done) as PRs
    move; make sure every PR title carries the tracker-ID suffix the
    project requires (see `BRANCHING.md`).

## Non-negotiable conventions

- **Branch/bookmark name** (identical across repos in a task):
  `<type>/<project>/<task-id>`.
- **Commits are isolated, not squashed.** If a follow-up fix appears,
  split it into its own commit *before* pushing. With jj: `jj split`
  (non-interactive flags; see `jj-cross-repo`), then move the bookmark to
  the new tip and force-with-lease push.
- **Overrides live on the feature branch only.** Strip them before the PR
  leaves draft.
- **ADR numbering** is owned by the repo it lives in; don't renumber
  across repos.

## Useful tool patterns

- `gh pr list -R <org>/<repo> --head <branch>` to find your draft in each
  repo without remembering PR numbers.
- `gh pr view <n> -R <org>/<repo> --json statusCheckRollup,mergeable,reviews`
  for a machine-readable status check before diving into logs.
- Use `just status` from the project directory for a quick snapshot of
  every repo at once (or `just status <type> <task-id>` to narrow to one
  task). Pushing all repos in a task is `just push <type> <task-id>`.

## When something is off

| Symptom | Likely cause | Fix |
|---|---|---|
| Consumer CI resolves old producer code | override points at a moved branch tip | re-push or pin to a specific commit briefly |
| PR has N+1 commits instead of N | follow-up wasn't split | `jj split`, move bookmark, push |
| PR title missing tracker ID | forgot the suffix | `gh pr edit --title` |
| `jj st` error about `.jj/repo` | task dir moved | see `project-task-workspaces` SKILL (fix the relative pointer) |
| `pub get` / `mvn` hangs or 403s on internal hosts | network / VPN — see the work overlay if one applies |
