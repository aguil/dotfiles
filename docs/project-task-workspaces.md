# Project/task workspaces

This repo includes a `Justfile` workflow (with **`mod proj`**) for outcome-oriented development directories. Recipes are intentionally small: scaffold a project, create a task and attach canonical repos with **`add`** (see below), list tasks, and drop work when done.

Layout (defaults under `~/dev`):

- `repos/github.com/<org>/<repo>`: canonical clone per repository (shared object database). Create and update these **outside** the `just` recipes (or with your own tooling); `add` expects them to already exist.
- `projects/<project>/<type>/<task-id>/<repo-basename>/`: each subfolder is a **jj workspace** (when the canonical repo is colocated for jj) or a **git worktree** (otherwise). There is no separate `workdirs` tree and no symlinks.
- `projects/<project>/<type>/<task-id>/task.json`: maps short directory names to `org/repo` for safe teardown (`drop`). **`just proj::add` / per-project `just add`** create **`<type>/<task-id>/`** and **`task.json`** if missing, then add repo worktrees. For a *new* task, org/repo is optional: pass none and use `fzf` to pick, or select nothing in `fzf` to leave an empty `repos` object. For an *existing* task, `add` only adds checkouts; org/repo is required (CLI or `fzf`).

`add` prefers Jujutsu when the canonical repo is colocated (`.jj` exists and is readable), and falls back to `git worktree` otherwise. Checkouts under the task directory are worktrees/workspaces only—not full second clones; objects stay under the canonical repo.

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

The **`just proj::…`** examples below assume you run **`just`** from the directory that contains this repo’s **`Justfile`** (the one with **`mod proj`**). Inside **`~/dev/projects/<project>/`**, use the shorter per-project recipes (for example **`just add`**, **`just list`**) documented in [Per-project `Justfile`](#per-project-justfile).

Preview **bootstrap** for a *new* task and empty **`task.json`**, and any repos you would add next (no writes):

```bash
DRY_RUN=1 just proj::add customer-portal feat auth-session-hardening--2026-04-13
```

Create the task directory and empty **`task.json`**, and optionally add repos in one step (omitting org/repo opens `fzf`; empty `fzf` selection = no checkouts yet):

```bash
just proj::add customer-portal feat auth-session-hardening--2026-04-13
# or, with repos: just proj::add customer-portal feat auth-session-hardening--2026-04-13 acme/api
```

`cd` to a task or one repo checkout (paths follow `~/dev/projects/<project>/<type>/<task-id>/` and `…/<repo-basename>/`):

```bash
cd ~/dev/projects/customer-portal/feat/auth-session-hardening--2026-04-13
cd ~/dev/projects/customer-portal/feat/auth-session-hardening--2026-04-13/api
```

Add one or more repos to a task. Each checkout is only a **jj workspace** or **git worktree**; the **canonical** clone must already exist under `repos/<host>/<org>/<repo>/`. Each argument is `org/repo` unless there are at least two arguments and the **last** one contains **no** `/`, in which case that last token is a **shared** starting revision for every repo before it (default otherwise is `master`):

```bash
just proj::add customer-portal feat auth-session-hardening--2026-04-13 acme/other
just proj::add customer-portal feat auth-session-hardening--2026-04-13 acme/api acme/web
just proj::add customer-portal feat auth-session-hardening--2026-04-13 acme/api acme/web develop
```

List task directories (optional second argument filters by type, e.g. `feat`):

```bash
just proj::list customer-portal
just proj::list customer-portal feat
```

Remove an entire project (drops every task under that project the same way as task-level `drop`, then deletes `projects/<project>/`):

```bash
just proj::drop customer-portal
```

From a per-project directory (omit type and task id):

```bash
cd ~/dev/projects/customer-portal && just drop
```

Preview project removal (prints actions only):

```bash
DRY_RUN=1 just proj::drop customer-portal
```

Remove the whole task (forget jj workspaces / remove git worktrees, delete `task.json` and the task directory). With `type` and `task_id` set, **no further arguments** means drop the entire task (same as an empty repo list):

```bash
just proj::drop customer-portal feat auth-session-hardening--2026-04-13
```

Remove only some repos from a task (updates `task.json`; removes the task folder if no repos remain):

```bash
just proj::drop customer-portal feat auth-session-hardening--2026-04-13 api web
```

Dry-run drop:

```bash
DRY_RUN=1 just proj::drop customer-portal feat auth-session-hardening--2026-04-13
```

## Per-project `Justfile`

After `just proj::init <name>`, use `cd ~/dev/projects/<name>` and run `just add`, `just list`, or `just drop` without passing the project as the first argument (see the generated `Justfile` there). Use `just drop` with no further arguments to remove that whole project.

From the dotfiles repo root, use the project-scoped equivalents:

```bash
just proj::list [project] [type]
```

## Notes

- **`just add`**: if `task.json` is missing, bootstraps the task (same as the old `new`); if it already exists, only adds new repo worktrees. It does not overwrite an existing `task.json`.
- `proj::status`, `proj::push`, and `proj::drop` can infer `<project>` when your current directory is already under `~/dev/projects/<project>/…` (before any `fzf` prompts for missing pieces).
- **`proj::list`** with **no** `<project>` argument **always** opens the **`fzf`** project picker (sorted by project mtime, preview of `type/task-id` rows). Pass `<project>` to skip the picker; from inside `~/dev/projects/<name>/` use per-project **`just list`** to list that project without going through **`proj::list`**.
- `status`, `push`, and `drop` use `fzf` to select missing args (`project`, `type`, `task-id`) when inference from CWD is not enough.
- `add` accepts multiple `org/repo` tokens. If the last token contains no `/` and there are at least two tokens, it is treated as a shared starting revision for all repos listed before it; otherwise every repo uses **`master`**. A revision that itself contains `/` (e.g. some tags) cannot be used as this trailing shared base—run `add` in separate invocations instead.
- Override roots with `DEV_ROOT` and `DEV_GIT_HOST`. Set `DRY_RUN=1` on `add` (and `drop`, `push`) for no-op previews; `add` prints bootstrap and `[dry-run]` for repo worktrees.
- `task.json` is written when `add` first creates a task (empty `repos` if you skip all repos) and updated by `add` / partial `drop`. If it is missing, `drop` can infer the canonical `org/repo` for **git** worktrees via `git rev-parse --git-common-dir`.
- Project-wide `drop` does not accept extra repo arguments; use **`just proj::drop <project> <type> <task_id> …`** from the dotfiles `Justfile` when removing selected repos from one task (or **`just drop <type> <task_id> …`** from the project directory).
- **Migrating from the old `tasks/` layout** (where paths were `projects/<project>/tasks/<type>/<task-id>/`): move each type directory up one level (for example `mv projects/foo/tasks/feat projects/foo/` for every type under `tasks/`, then remove the empty `tasks` directory). Update any local **`AGENTS.md`** that still documents the old paths.

## Shell completion setup

Generate completion scripts with `just --completions <shell>`, then place them where your shell loads completions.

### Bash

**Applied dotfiles:** `~/.bash_profile` (from this repo) loads static **`just`** completions first, then **`$(chezmoi source-path)/scripts/just-proj-completion.bash`** — **after** `~/.extra`, conda, and **`PATH`** finalization so later hooks do not win. Bash-completion’s on-demand loader can still replace **`complete -F`** for **`just`** the first time stock **`_just`** runs; the profile re-applies the wrapper after that call and on each interactive prompt if needed. You normally only need to install static completions once:

```bash
mkdir -p ~/.local/share/bash-completion/completions
just --completions bash > ~/.local/share/bash-completion/completions/just
```

For a manual load (e.g. custom shell layout), use the portable source path:

```bash
source "$(chezmoi source-path)/scripts/just-proj-completion.bash"
```

`just-proj-completion.bash` adds dynamic completion for `proj::` args (`project`, `type`, `task-id`) from your local `~/dev/projects` tree.

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

**Applied dotfiles:** `~/.zshrc` from this repo runs **`bashcompinit`** (when available), sources **`$(chezmoi source-path)/scripts/just-proj-completion.bash`**, and registers a **`precmd`** hook to re-apply the wrapper if another completion layer replaced it.

For a manual load (e.g. before `compinit` elsewhere), use:

```bash
autoload -Uz bashcompinit && bashcompinit
source "$(chezmoi source-path)/scripts/just-proj-completion.bash"
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
