# Project/task workspaces

This repo includes a `Justfile` workflow for outcome-oriented development directories. Recipes are intentionally small: scaffold a project, create a task from `manifests/default.repos`, optionally add a repo, list tasks, and drop work when done.

Layout (defaults under `~/dev`):

- `repos/github.com/<org>/<repo>`: canonical clone per repository (shared object database).
- `projects/<project>/tasks/<type>/<task-id>/<repo-basename>/`: each subfolder is a **jj workspace** (when the canonical repo is colocated for jj) or a **git worktree** (otherwise). There is no separate `workdirs` tree and no symlinks.
- `projects/<project>/tasks/<type>/<task-id>/task.json`: maps short directory names to `org/repo` for safe teardown (`drop`).

The `new` and `add` recipes prefer Jujutsu when the canonical repo is colocated (`.jj` exists and is readable), and fall back to `git worktree` otherwise. Checkouts under the task directory are worktrees/workspaces only—not full second clones; objects stay under the canonical repo.

Each checkout uses a **git branch** (and, under jj, a **bookmark** with the same name) of the form `<task-type>/<project>/<task-id>`, for example `feat/customer-portal/auth-session-hardening--2026-04-13`. The jj **workspace name** is a slug with the same parts joined by hyphens, plus the repo basename (e.g. `feat-customer-portal-auth-session-hardening--2026-04-13-api`).

## Quick start

Initialize a project scaffold:

```bash
just project-init customer-portal
```

Edit `~/dev/projects/customer-portal/manifests/default.repos`:

```text
# repo base
acme/api main
acme/web main
acme/infra main
```

Preview `new` (no writes):

```bash
DRY_RUN=1 just new customer-portal feat auth-session-hardening--2026-04-13
```

Create a task and materialize each line as `tasks/.../<basename>/` (the recipe prints the task directory when it finishes):

```bash
just new customer-portal feat auth-session-hardening--2026-04-13
```

`cd` to a task or one repo checkout (paths follow `~/dev/projects/<project>/tasks/<type>/<task-id>/` and `…/<repo-basename>/`):

```bash
cd ~/dev/projects/customer-portal/tasks/feat/auth-session-hardening--2026-04-13
cd ~/dev/projects/customer-portal/tasks/feat/auth-session-hardening--2026-04-13/api
```

Add one or more repos to an existing task. Each checkout is only a **jj workspace** or **git worktree**; the **canonical** clone must already exist under `repos/<host>/<org>/<repo>/` (from `new` or a prior clone). Each argument is `org/repo` unless there are at least two arguments and the **last** one contains **no** `/`, in which case that last token is a **shared** starting revision for every repo before it (default otherwise is `master`):

```bash
just add customer-portal feat auth-session-hardening--2026-04-13 acme/other
just add customer-portal feat auth-session-hardening--2026-04-13 acme/api acme/web
just add customer-portal feat auth-session-hardening--2026-04-13 acme/api acme/web develop
```

List task directories (optional second argument filters by type, e.g. `feat`):

```bash
just list customer-portal
just list customer-portal feat
```

Remove an entire project (drops every task under that project the same way as task-level `drop`, then deletes `projects/<project>/`):

```bash
just drop customer-portal
```

From a per-project directory (omit type and task id):

```bash
cd ~/dev/projects/customer-portal && just drop
```

Preview project removal (prints actions only):

```bash
DRY_RUN=1 just drop customer-portal
```

Remove the whole task (forget jj workspaces / remove git worktrees, delete `task.json` and the task directory). With `type` and `task_id` set, **no further arguments** means drop the entire task (same as an empty repo list):

```bash
just drop customer-portal feat auth-session-hardening--2026-04-13
```

Remove only some repos from a task (updates `task.json`; removes the task folder if no repos remain):

```bash
just drop customer-portal feat auth-session-hardening--2026-04-13 api web
```

Dry-run drop:

```bash
DRY_RUN=1 just drop customer-portal feat auth-session-hardening--2026-04-13
```

## Per-project `Justfile`

After `just project-init <name>`, use `cd ~/dev/projects/<name>` and run `just new`, `just add`, `just list`, or `just drop` without passing the project as the first argument (see the generated `Justfile` there). Use `just drop` with no further arguments to remove that whole project.

## Notes

- Manifest format is whitespace-separated: `<org/repo> <base-branch>`. Comments and blank lines are ignored; a missing branch defaults to `main`.
- `add` accepts multiple `org/repo` tokens. If the last token contains no `/` and there are at least two tokens, it is treated as a shared starting revision for all repos listed before it; otherwise every repo uses **`master`** (unrelated to the manifest’s `main` default). A revision that itself contains `/` (e.g. some tags) cannot be used as this trailing shared base—run `add` in separate invocations instead.
- Override roots with `DEV_ROOT` and `DEV_GIT_HOST`. Set `DRY_RUN=1` on `new` and `drop` for no-op previews.
- `task.json` is written by `new` and updated by `add` / partial `drop`. If it is missing, `drop` can infer the canonical `org/repo` for **git** worktrees via `git rev-parse --git-common-dir`.
- Project-wide `drop` does not accept extra repo arguments; use `drop <project> <type> <task_id> …` when removing selected repos from one task.

## Jujutsu (`jj`) details

- `jj workspace forget` takes the workspace **name** as a positional argument (tested on jj 0.40.x).
- `drop` checks `jj workspace list` on the **canonical** repo before calling `forget`. `forget` does not delete the directory; the recipe removes the checkout directory afterward when not in dry-run mode.

## Failure modes and troubleshooting

- **`new` clone fails**: URLs use `git@<DEV_GIT_HOST>:org/repo.git`. Adjust `DEV_GIT_HOST` or edit the recipe for HTTPS if needed.
- **`jj workspace add` and `--revision`**: The recipe retries with `--revision @` on the canonical repo if the named base revision fails.
- **`drop` / git**: `git worktree remove` runs from the canonical clone; on failure it may fall back to `rm -rf` on the checkout path **only** when it lies under the task directory.
- **`drop` / jj**: If `workspace forget` fails, the recipe exits without deleting that checkout so you can inspect `jj workspace list`.
