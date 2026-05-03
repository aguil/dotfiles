# Agent instructions (dotfiles)

This repository is the **chezmoi source** for this dotfiles setup. It is listed in `.chezmoiignore` so this file is **not** copied into `$HOME` on `chezmoi apply`; it exists here for tools that read repo-root `AGENTS.md`.

## GitHub

For work targeting this dotfiles repository on GitHub, use the **`gh`** CLI for PRs, issues, releases, and similar tasks so authentication and host aliases match your local shell environment.

See also: **`.agents/skills/`** after apply (source: `dot_agents/skills/`), especially the **`dotfiles-github-cli`** skill.

## Version control

If a **`.jj/`** directory exists in this tree, it is a **Jujutsu (jj)** colocated repo: use **`jj`** for commits, bookmarks, and history; avoid raw **`git`** commands that rewrite state unless you know the repo is Git-only.
