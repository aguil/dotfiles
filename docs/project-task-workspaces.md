# Project/task workspaces

This repo includes a `Justfile` workflow for outcome-oriented development directories. Recipes are intentionally small: scaffold a project, scaffold a task, **`just add`** each repo after canonical clones exist under `repos/`, list tasks, and drop work when done.

Layout (defaults under `~/dev`):

- `repos/github.com/<org>/<repo>`: canonical clone per repository (shared object database). Create and update these **outside** the `just` recipes (or with your own tooling); `add` expects them to already exist.
- `projects/<project>/<type>/<task-id>/<repo-basename>/`: each subfolder is a **jj workspace** (when the canonical repo is colocated for jj) or a **git worktree** (otherwise). There is no separate `workdirs` tree and no symlinks.
- `projects/<project>/<type>/<task-id>/task.json`: maps short directory names to `org/repo` for safe teardown (`drop`). **`just new`** creates an empty `repos` object; **`just add`** fills it.

The `new` and `add` recipes prefer Jujutsu when the canonical repo is colocated (`.jj` exists and is readable), and fall back to `git worktree` otherwise. Checkouts under the task directory are worktrees/workspaces only—not full second clones; objects stay under the canonical repo.

Each checkout uses a **git branch** (and, under jj, a **bookmark** with the same name) of the form `<task-type>/<project>/<task-id>`, for example `feat/customer-portal/auth-session-hardening--2026-04-13`. The jj **workspace name** is a slug with the same parts joined by hyphens, plus the repo basename (e.g. `feat-customer-portal-auth-session-hardening--2026-04-13-api`).

## Quick start

Initialize a project scaffold:

```bash
just proj::init customer-portal
```

This creates the directory tree, a per-project `Justfile`, and **`AGENTS.md`** at the project root when missing (re-running `proj::init` does not overwrite a customized **`AGENTS.md`**).

Discover known project/task args:

```bash
just proj::list                    # opens project picker with task preview (newest first)
```

Ensure canonical clones exist under `~/dev/repos/github.com/` (or your **`DEV_GIT_HOST`**), for example `acme/api`, `acme/web`.

Preview **`new`** (no writes):

```bash
DRY_RUN=1 just new customer-portal feat auth-session-hardening--2026-04-13
```

Scaffold the task directory and empty **`task.json`** (the recipe prints the task directory when it finishes):

```bash
just new customer-portal feat auth-session-hardening--2026-04-13
```

`cd` to a task or one repo checkout (paths follow `~/dev/projects/<project>/<type>/<task-id>/` and `…/<repo-basename>/`):

```bash
cd ~/dev/projects/customer-portal/feat/auth-session-hardening--2026-04-13
cd ~/dev/projects/customer-portal/feat/auth-session-hardening--2026-04-13/api
```

Add one or more repos to a task. Each checkout is only a **jj workspace** or **git worktree**; the **canonical** clone must already exist under `repos/<host>/<org>/<repo>/`. Each argument is `org/repo` unless there are at least two arguments and the **last** one contains **no** `/`, in which case that last token is a **shared** starting revision for every repo before it (default otherwise is `master`):

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

After `just proj::init <name>`, use `cd ~/dev/projects/<name>` and run `just new`, `just add`, `just list`, or `just drop` without passing the project as the first argument (see the generated `Justfile` there). Use `just drop` with no further arguments to remove that whole project.

From the dotfiles repo root, use the project-scoped equivalents:

```bash
just proj::list [project] [type]
```

## Notes

- **`just new`** refuses to run if **`task.json`** already exists in that task directory (avoid accidental overwrite).
- `proj::list`, `proj::status`, `proj::push`, and `proj::drop` accept an omitted project when your current directory is already under `~/dev/projects/<project>/...`.
- `proj::list` with no project opens an `fzf` picker sorted by project mtime and previews each project's tasks as compact `type/task-id` rows (newest first).
- `status`, `push`, and `drop` use `fzf` to select missing args (`project`, `type`, `task-id`) when inference from CWD is not enough.
- `add` accepts multiple `org/repo` tokens. If the last token contains no `/` and there are at least two tokens, it is treated as a shared starting revision for all repos listed before it; otherwise every repo uses **`master`**. A revision that itself contains `/` (e.g. some tags) cannot be used as this trailing shared base—run `add` in separate invocations instead.
- Override roots with `DEV_ROOT` and `DEV_GIT_HOST`. Set `DRY_RUN=1` on `new` and `drop` for no-op previews.
- `task.json` is written by `new` (empty `repos`) and updated by `add` / partial `drop`. If it is missing, `drop` can infer the canonical `org/repo` for **git** worktrees via `git rev-parse --git-common-dir`.
- Project-wide `drop` does not accept extra repo arguments; use `drop <project> <type> <task_id> …` when removing selected repos from one task.
- **Migrating from the old `tasks/` layout** (where paths were `projects/<project>/tasks/<type>/<task-id>/`): move each type directory up one level (for example `mv projects/foo/tasks/feat projects/foo/` for every type under `tasks/`, then remove the empty `tasks` directory). Update any local **`AGENTS.md`** that still documents the old paths.

## Shell completion setup

Generate completion scripts with `just --completions <shell>`, then place them where your shell loads completions.

### Bash

```bash
mkdir -p ~/.local/share/bash-completion/completions
just --completions bash > ~/.local/share/bash-completion/completions/just
```

### Zsh

```bash
mkdir -p ~/.zfunc
just --completions zsh > ~/.zfunc/_just
```

Ensure `~/.zshrc` includes `~/.zfunc` in `fpath` before `compinit`, for example:

```bash
fpath=(~/.zfunc $fpath)
autoload -Uz compinit && compinit
```

### Fish

```bash
mkdir -p ~/.config/fish/completions
just --completions fish > ~/.config/fish/completions/just.fish
```

## Smoke test

Run the lightweight picker/workflow smoke test from this repo:

```bash
just proj-smoke
just proj-smoke customer-portal
```

The smoke test checks `proj::list` picker selection, project-wide `proj::status`, and dry-run `proj::drop`/`proj::push` for one discovered task.

## Jujutsu (`jj`) details

- `jj workspace forget` takes the workspace **name** as a positional argument (tested on jj 0.40.x).
- `drop` checks `jj workspace list` on the **canonical** repo before calling `forget`. `forget` does not delete the directory; the recipe removes the checkout directory afterward when not in dry-run mode.

## Failure modes and troubleshooting

- **`add` / missing canonical**: `add` does not clone; ensure **`$DEV_ROOT/repos/<host>/<org>/<repo>`** exists before **`add`**.
- **`jj workspace add` and `--revision`**: The recipe retries with `--revision @` on the canonical repo if the named base revision fails.
- **`drop` / git**: `git worktree remove` runs from the canonical clone; on failure it may fall back to `rm -rf` on the checkout path **only** when it lies under the task directory.
- **`drop` / jj**: If `workspace forget` fails, the recipe exits without deleting that checkout so you can inspect `jj workspace list`.
