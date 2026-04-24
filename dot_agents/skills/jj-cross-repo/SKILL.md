---
name: jj-cross-repo
description: >-
  Supplements the base `jujutsu` skill with patterns specific to project-task
  workspaces: bookmarks that don't auto-advance, splitting commits non-
  interactively, pushing the same branch name across sibling repos, and
  recovering broken `.jj/repo` pointers when the task directory moves. Use
  whenever running jj inside `~/dev/projects/…` or across sibling checkouts.
---

# jj in project-task workspaces

Read `~/.agents/skills/jujutsu/SKILL.md` first for fundamentals. This adds
only the cross-repo specifics.

## Bookmarks don't auto-advance

Unlike git branches, a jj bookmark is a named pointer that stays put when you
commit on top of it. Every push you must:

    jj bookmark set <type>/<project>/<task>  --to @  --allow-backwards
    jj git push -b <type>/<project>/<task>

`jj bookmark set` creates-or-updates in one call; `--allow-backwards` covers
the case where a rebase moves the tip "backwards" by jj's reckoning.

For multi-repo tasks, use **`just push <type> <task-id>`** from the project
directory (or `just proj::push <project> <type> <task-id>`). It derives the
bookmark name, runs `jj bookmark set` + `jj git push` (or `git push`) in
each repo listed in `task.json`, and supports `DRY_RUN=1`. Pass specific
`<repo-basename>` args to push a subset.

## Non-interactive splitting

Agents can't drive `jj split -i`. Use path-based splitting:

    jj split -r <change>  path/to/a  path/to/b   # a, b become new commit
    # ...or stage-wise by abandoning and re-creating
    jj new <change>-                             # branch off parent
    jj desc -m "First half"
    # copy in only the files you want, then:
    jj new                                       # second commit
    jj desc -m "Second half"

After a split, rebase children onto the new tip:

    jj rebase -s <old-child> -d <new-parent>

## Rebasing a task stack on main

From a task checkout (jj workspace or colocated clone):

    jj git fetch
    jj rebase -b <type>/<project>/<task>  -d main@origin

If there are conflicts, jj commits them into the stack. Resolve by editing
files to remove markers, then:

    jj st        # confirm no conflict markers remain
    jj squash    # if you created a fix commit you want merged into the parent

## Broken `.jj/repo` pointer

Symptom after moving the task directory:

    Error: Cannot access /Users/.../tasks/feat/<task>/<repo>/.jj/repo

`.jj/repo` in a jj workspace is a **text file** holding a relative path to
the canonical repo's `.jj/repo`. Rewrite it:

    cd <task-checkout>
    canonical="$HOME/dev/repos/github.com/<org>/<repo>/.jj/repo"
    python3 -c 'import os,sys; print(os.path.relpath(sys.argv[1], os.getcwd()))' "$canonical" > .jj/repo
    jj st

## Pushing sibling repos in lockstep

From the project directory (`~/dev/projects/<project>/`):

    just status <type> <task-id>         # check every repo first
    DRY_RUN=1 just push <type> <task-id> # confirm the commands
    just push <type> <task-id>           # execute

The recipe derives the bookmark name as `<type>/<project>/<task-id>` and
runs `jj bookmark set --allow-backwards` + `jj git push -b <branch>` in
each repo from `task.json`, stopping on the first failure. Pass one or
more `<repo-basename>` args to push a subset.

## Things to avoid as an agent

- `jj split -i`, `jj squash -i`, `jj resolve` (all interactive).
- `git commit`, `git rebase`, `git checkout` inside a jj workspace — they
  desync the working copy relative to `@`.
- `jj op undo` without reading `jj op log` first; some ops cascade.
- Force-pushing a canonical clone's main history without checking whether
  sibling task workspaces are checked out against it.
