---
name: dotfiles-github-cli
description: >-
  Use the GitHub CLI (gh) for GitHub operations on this dotfiles repository and
  this chezmoi-managed repository. Use when creating PRs, listing issues,
  checking CI, or any gh-supported task for that repo. Prefer gh so auth and
  hosts match your local shell configuration.
---

# GitHub CLI for dotfiles

When the task involves this dotfiles repository on GitHub or this **chezmoi
source tree** that applies into it, use **`gh`** for GitHub.

## Use `gh` for

- Pull requests: `gh pr create`, `gh pr view`, `gh pr list`, `gh pr checks`,
  `gh pr diff`
- Issues, releases, labels, and other subcommands where `gh` is sufficient

## Why prefer local `gh`

It uses your login, git hosts (for example your personal GitHub SSH host alias),
profile-default `GH_CONFIG_DIR` from chezmoi `profile.d`, and optional
**`CHEZMOI_GH_HOST`** / 1Password flows from your dotfiles docs—same context as
your terminal.

Subprocess tools invoke `command gh` (not the shell `gh()` function). Chezmoi
exports `GH_CONFIG_DIR` per profile in
`~/.config/chezmoi/profile.d/01-gh-default-config.sh` so agents and scripts do
not fall back to an unauthenticated `~/.config/gh` when your interactive shell
is routed correctly.

## Multiple GitHub.com logins on one machine

`gh` can store **several** logins for `github.com`, but the **active** login
(see `gh auth status`) is chosen **per config directory**, not per repository
path.

- **Default:** everything uses `~/.config/gh` (or the platform equivalent). Only
  **one** active `github.com` user at a time for that config. **`gh auth switch`
  updates that global choice**, so every shell session sharing that config sees
  the same active user until you switch again. Concurrent terminals are not
  independent unless you isolate config.
- **Avoid switching:** run `gh` with a **dedicated config dir**, for example
  `GH_CONFIG_DIR=… gh pr list`, so two sessions can use two identities at once
  without flipping the default active user.

When the active user does not match the account that owns the remote for the
tree you are in, either switch (`gh auth switch --user <login>`) or use the
matching `GH_CONFIG_DIR` for that profile.

This dotfiles shell wrapper also supports overlay route files in
`~/.config/chezmoi/gh-routes.d/*.sh`. Route files call
`gh_route <repo-root> <GH_CONFIG_DIR>`; the wrapper checks them before its
built-in personal routes. Prefer this for overlay repos such as
`~/.local/share/chezmoi-work` so PR commands do not require global
`gh auth switch`.

Built-in routing sets `GH_HOST=github.com` under
`~/dev/repos/github.com/<user>/` and in the chezmoi source when `origin` is on
GitHub.

For **Codeberg / Forgejo**, use **`fj`** (see **dotfiles-forgejo-cli** skill):
repo-scoped `fj()` sets `XDG_DATA_HOME` to `CHEZMOI_FJ_DATA_HOME` under
`~/dev/repos/<codeberg-host>/<user>/` and in the chezmoi source when `origin` is
on Codeberg. **`gh` does not support Forgejo hosts.**

Typical split (adjust paths and hostnames to your layout):

| Role                         | Chezmoi source (example)           | Use the `gh` login that owns this remote        |
| ---------------------------- | ---------------------------------- | ----------------------------------------------- |
| Primary dotfiles             | `~/.local/share/chezmoi`           | `fj` if origin is Codeberg; else `gh` on GitHub |
| Secondary overlay (optional) | e.g. `~/.local/share/chezmoi-work` | Employer or second user on GitHub               |

## Fallback

If `gh` is missing, not authenticated for the host, or the operation is
unsupported, say so explicitly, then use another tool if needed.
