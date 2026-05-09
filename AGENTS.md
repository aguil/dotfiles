# agent instructions (dotfiles)

this repository is the **chezmoi source** for this dotfiles setup. it is listed
in `.chezmoiignore` so this file is **not** copied into `$home` on
`chezmoi apply`; it exists here for tools that read repo-root `agents.md`.

## github

for work targeting this dotfiles repository on github, use the **`gh`** CLI for
prs, issues, releases, and similar tasks so authentication and host aliases
match your local shell environment.

see also: **`.agents/skills/`** after apply (source: `dot_agents/skills/`),
especially the **`dotfiles-github-cli`** skill.

## version control

if a **`.jj/`** directory exists in this tree, it is a **Jujutsu (jj)**
co-located repo: use **`jj`** for commits, bookmarks, and history; avoid raw
**`git`** commands that rewrite state unless you know the repo is Git-only.
