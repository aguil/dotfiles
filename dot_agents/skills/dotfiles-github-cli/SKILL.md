---
name: dotfiles-github-cli
description: >-
  Use the GitHub CLI (gh) for GitHub operations on this dotfiles repository and this chezmoi-managed
  repository. Use when creating PRs, listing issues, checking CI, or any gh-supported task
  for that repo. Prefer gh so auth and hosts match your local shell configuration.
---

# GitHub CLI for dotfiles

When the task involves this dotfiles repository on GitHub or this **chezmoi source tree** that applies into it, use **`gh`** for GitHub.

## Use `gh` for

- Pull requests: `gh pr create`, `gh pr view`, `gh pr list`, `gh pr checks`, `gh pr diff`
- Issues, releases, labels, and other subcommands where `gh` is sufficient

## Why prefer local `gh`

It uses your login, git hosts (for example your personal GitHub SSH host alias), and optional **`CHEZMOI_GH_HOST`** / 1Password flows from your dotfiles docs—same context as your terminal.

## Fallback

If `gh` is missing, not authenticated for the host, or the operation is unsupported, say so explicitly, then use another tool if needed.
