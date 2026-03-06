# Chezmoi profiles

This repo uses `CHEZMOI_PROFILE` to separate work and personal identity/tooling.

## Profiles

- `work`
- `personal` (default when unset)

## Usage

Preview:

```bash
CHEZMOI_PROFILE=work chezmoi diff
CHEZMOI_PROFILE=personal chezmoi diff
```

PowerShell preview:

```powershell
$env:CHEZMOI_PROFILE = "work"
chezmoi diff

$env:CHEZMOI_PROFILE = "personal"
chezmoi diff
```

Apply:

```bash
CHEZMOI_PROFILE=work chezmoi apply
CHEZMOI_PROFILE=personal chezmoi apply
```

PowerShell:

```powershell
$env:CHEZMOI_PROFILE = "personal"
chezmoi apply
```

Note: `CHEZMOI_PROFILE=personal chezmoi diff` is POSIX shell syntax and will not work in PowerShell.

## One-time profile bootstrap

Profile setup uses chezmoi's built-in prompt support in `.chezmoi.toml.tmpl`:

- `promptChoiceOnce . "profile" "Select profile" (list "work" "personal") "personal"`

On first initialization, chezmoi prompts once and persists the selected profile in generated config data.

After that, normal `chezmoi diff` / `chezmoi apply` commands work without prefixing env vars each time.

If you ever need a temporary override for a command, `CHEZMOI_PROFILE` still takes precedence.

## What this currently controls

- Git identity through `dot_gitconfig.tmpl` + `dot_gitconfig-work.tmpl` / `dot_gitconfig-personal.tmpl`.
- Dotfiles repo override: commits in `~/projects/dotfiles/` use personal identity via Git `includeIf`.
- Chezmoi source repo override: commits in `chezmoi source-path` also use personal identity via Git `includeIf`.
- Git signing keys are injected directly as public key values from `.chezmoi.toml.tmpl` data.
- Tooling intent metadata in `.chezmoi.toml.tmpl` (`work`: IntelliJ IDEA + Cursor, `personal`: OpenCode + VSCode).
- Windows-only `komorebi`/`whkd` assets via `.chezmoiignore.tmpl`.

## Optional gh auto-login via 1Password

Chezmoi includes these post-apply scripts to bootstrap `gh` authentication only when needed:

- `.chezmoiscripts/run_after_20-gh-auth.sh.tmpl` for the default/global `gh` config.
- `.chezmoiscripts/run_after_21-gh-personal-auth.sh.tmpl` for the personal profile config directory (`GH_CONFIG_DIR`, default `~/.config/gh-personal`).

Both scripts first check `gh auth status -h <host>` and exit if already authenticated. If auth is missing, they read a token from 1Password CLI (`op`) and run `gh auth login --with-token`.

Set these environment variables before `chezmoi apply`:

```bash
export CHEZMOI_GH_HOST=github.com
export CHEZMOI_GH_TOKEN_OP_REF='op://Private/GitHub CLI/token'
export CHEZMOI_GH_CONFIG_DIR="$HOME/.config/gh-personal"
```

`CHEZMOI_GH_HOST` defaults to `github.com` when unset.
Set `CHEZMOI_GH_TOKEN_OP_REF` only for the `personal` profile.
`CHEZMOI_GH_CONFIG_DIR` defaults to `~/.config/gh-personal` for the personal repo-scoped profile.

These values are captured in `.chezmoi.toml.tmpl` with `promptStringOnce`
during `chezmoi init` and persisted in chezmoi state.

## Notes

- Keep profile-specific secrets in your chezmoi secret backend, not plaintext templates.
- Public signing keys are safe to commit; private keys must stay in 1Password/agent and out of repo.
- Any new intentional divergence should be added to `docs/drift-exceptions.md`.
