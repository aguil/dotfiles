---
name: project-task-workspaces
description: >-
  Navigate `~/dev/projects/<project>/<type>/<task-id>/<repo>/` layouts created
  by `just proj::init` from aguil/dotfiles. Use when the CWD is inside
  `~/dev/projects/…`, when the user mentions a project/task, or when working
  across multiple repo checkouts in one task.
---

# Project-task workspaces

Projects scaffolded by `just proj::init <name>` (from the dotfiles `Justfile`
that declares `mod proj`, with `proj.just` beside it in the same directory)
look like this:

    ~/dev/projects/<project>/
      AGENTS.md                 <-- project-scope rules (read it)
      Justfile                  <-- `just new|add|list|status|push|drop`
      <type>/<task-id>/         <-- e.g. feat/user-applied-filter-awareness/
        task.json               <-- { "repos": { "<basename>": "org/repo" } }
        <repo-basename>/        <-- per-task checkout (jj workspace OR git worktree)

Canonical clones live at `~/dev/repos/<git-host>/<org>/<repo>/` (NOT inside the
project). They are usually jj-colocated (`.jj/` + `.git/`).

Older projects may show `just project-init` instead of `just proj::init` in
their AGENTS.md — treat them as equivalent; the per-project task interface
is unchanged.

## Always do these first

1. **Read `task.json`** to know which repos this task spans — don't guess from
   directory names. The keys are the repo basenames under the task dir; the
   values are `org/repo`.
2. **Detect VCS mode in each checkout** (this determines every subsequent
   command):
   - `.jj/repo` present, **no** `.git` → jj workspace → use `jj` exclusively.
     Never run `git commit`, `git rebase`, `git checkout` here.
   - `.git` file (not directory) → git worktree → use plain git.
   - `.jj/` **and** `.git/` → colocated (usually a canonical clone, not a task
     checkout) → prefer jj.
3. **Branch/bookmark name is fixed**:
   `<type>/<project>/<task-id>`, e.g.
   `feat/my-project/user-applied-filter-awareness`.
   Use this for `jj git push -b …`, `gh pr create --head …`, every time.

## Recipes

From **inside** a project directory (`~/dev/projects/<project>/`):

    just                                          # list recipes
    just new    <type> <task-id> [org/repo ...]
    just add    <type> <task-id> <org/repo> [<org/repo>...]
    just list   [<type>]
    just status [<type> <task-id>]                # jj st / git status -sb per repo
    just push   [<type> <task-id>] [<repo>...]    # move bookmark + push for each repo
    just drop   [<type> <task-id>] [<org/repo>...]

From **anywhere**, same operations via the module:

    just proj::init   <project>
    just proj::new    <project> <type> <task-id> [org/repo ...]
    just proj::add    <project> <type> <task-id> <org/repo> [...]
    just proj::list   [<project> [<type>]]
    just proj::status [<project> [<type> <task-id>]]
    just proj::push   [<project> <type> <task-id>] [<repo>...]
    just proj::drop   [<project> [<type> <task-id>]] [<org/repo>...]

Notes:
- `list` without a project can open an `fzf` picker with a per-project task
  preview (compact `type/task-id`, newest first, when `fzf` is available).
- `status` with no args iterates every task in the project; with `<type>
  <task-id>` it narrows to one task.
- `push` without repo args iterates every repo in `task.json`; pass one or
  more `<repo-basename>` args to push a subset. The branch/bookmark name
  is always derived as `<type>/<project>/<task-id>`.
- `DRY_RUN=1` is honoured by `new`, `drop`, and `push` for no-op previews.
- `just proj-smoke [project]` runs a quick regression check for picker and
  task-flow behavior.
- `scripts/just-proj-completion.bash` augments `just` completion with dynamic
  `proj::` arg completion from the local projects tree.

## When the jj workspace pointer breaks

Symptom: `jj st` prints `Cannot access …/.jj/repo`. This happens if the task
directory moved (e.g. `./tasks/feat` → `./feat`).

Fix: `.jj/repo` is a text file containing a **relative** path to the canonical
repo's `.jj/repo`. Rewrite it relative to the new location:

    cd <task-checkout>
    canonical_jj_repo="$HOME/dev/repos/github.com/<org>/<repo>/.jj/repo"
    python3 -c "import os,sys; \
      print(os.path.relpath(sys.argv[1], os.getcwd()))" \
      "$canonical_jj_repo" > .jj/repo
    jj st   # verify

## Helpers

For status and push across repos in a task, prefer the `just` recipes above
— they're the canonical interface and live with the rest of the task
family (`new` / `add` / `list` / `drop`).

One helper script remains, because it has to modify the caller's shell CWD
and therefore can't be a `just` recipe:

- `scripts/task-cd.sh <repo-basename>` — prints a `cd` command to a sibling
  repo in the same task. Invoke with `eval`:

      eval "$(~/.agents/skills/project-task-workspaces/scripts/task-cd.sh <repo>)"
