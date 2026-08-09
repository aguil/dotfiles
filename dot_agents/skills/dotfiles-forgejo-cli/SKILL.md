---
name: dotfiles-forgejo-cli
description: >-
  Use fj (forgejo-cli) for Codeberg and other Forgejo hosts in this chezmoi
  setup. Use when creating or reviewing pull requests, issues, releases, or CI
  on Codeberg. Prefer fj over gh for those hosts.
---

# Forgejo CLI (fj) for Codeberg

When the task involves **Codeberg** (or another Forgejo host), use **`fj`**, not
**`gh`**. The chezmoi source is **not** one of those hosts — its `origin` is on
GitHub, so use **`gh`** there (see **dotfiles-github-cli**).

## Use `fj` for

- Pull requests: `fj pr list`, `fj pr view`, `fj pr create`, merge flows
- Issues, releases, tags, `fj whoami`, `fj actions` where supported

## Why prefer local `fj`

The shell **`fj()`** wrapper sets **`XDG_DATA_HOME`** and
**`-H $CHEZMOI_CODEBERG_HOST`** so commands do not follow a **GitHub** `origin`
(which causes **410 Gone** on `fj whoami`).

Subprocess tools call **`command fj`** and do not run the wrapper. Use
**`chez_fj`** (from `profile.d/03-fj-default-config.sh`) or:

```bash
XDG_DATA_HOME="${CHEZMOI_FJ_DATA_HOME:-$HOME/.local/share/fj-personal}" \
  fj -H "${CHEZMOI_CODEBERG_HOST:-codeberg.org}" pr list
```

## Auth

- **`fjpersonalauth`** — `fj auth add-token -H $CHEZMOI_CODEBERG_HOST` using
  **`codeberg.tokenOpRef`** / **`CHEZMOI_CODEBERG_TOKEN_OP_REF`** and 1Password
  (`op read`), or an interactive paste if the ref is unset.
- **`chezmoi apply`** runs
  `.chezmoiscripts/run_after_24-codeberg-fj-auth.sh.tmpl` with the same token
  ref when `fj whoami` is not yet configured.
- Keys file: `$CHEZMOI_FJ_DATA_HOME/forgejo-cli/forgejo-cli/keys.json`

## GitHub

For **`github.com`** remotes, `~/dev/repos/github.com/<user>/`, and the
**chezmoi source** (`~/.local/share/chezmoi`, origin `aguil/dotfiles`), use
**`gh`** and the **dotfiles-github-cli** skill instead.

## Overlay routes

Optional `~/.config/chezmoi/fj-routes.d/*.sh` files call
`fj_route <repo-root> <XDG_DATA_HOME>` (checked before built-in routes).

## Fallback

If `fj` is missing or not authenticated, say so explicitly. Install with
`cargo install forgejo-cli` (binary `fj`) or distro packages; see
[forgejo-cli](https://codeberg.org/forgejo-contrib/forgejo-cli).
