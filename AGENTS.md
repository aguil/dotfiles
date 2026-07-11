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

## live systems (tmux, shell, terminal)

do not disrupt operator sessions while editing dotfiles. full policy:
**`dot_agents/rules/live-interaction-safety.md`** (after apply:
`~/.agents/rules/`). repo-specific commands and examples:
**`docs/agent-live-systems.md`**.

minimum bar when touching `dot_tmux.conf*`, shell rc, or
`windows/terminal/settings.json`:

- never run `tmux kill-server` or `kill-session` on the **default** socket to
  "validate" config.
- for tmux runtime experiments, use `-L agent-debug-…` and `kill-server` on that
  socket when done; if you must use the default socket, kill **only** your own
  debug session before ending the task (see `docs/agent-live-systems.md`).
- render templates with `chezmoi execute-template` before apply.
- do not `chezmoi apply --force` interactive files unless the operator asked to
  apply; prefer dry-run first.
- reload (`prefix + r`, new WT tab) is operator-driven unless delegated.
