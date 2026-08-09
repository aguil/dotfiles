---
name: mise-security
description: >-
  Security mitigation checklist for mise: supply-chain backends, paranoid trust,
  ceiling paths, lockfiles, secrets handling, and CI hardening. Use when adding
  mise tools, trusting a new mise.toml, or reviewing mise configuration in this
  dotfiles repo or project checkouts.
---

# mise security mitigation checklist

These settings are applied globally via chezmoi (`~/.config/mise/config.toml`,
`~/.config/chezmoi/profile.d/mise-security.sh`) and in this repo's `.mise.toml`.

## Supply chain

| Action                                                                         | Status here                   |
| ------------------------------------------------------------------------------ | ----------------------------- |
| **Disable legacy backends** — `disable_backends = ["asdf"]` in global config   | Applied                       |
| **Prefer verified backends** — use `aqua:`, `vfox:`, or `cargo:` when possible | Documented; QA tools use aqua |

## Configuration

| Action                                                                                                                             | Status here          |
| ---------------------------------------------------------------------------------------------------------------------------------- | -------------------- |
| **Paranoid mode** — `MISE_PARANOID=1` before `mise activate`                                                                       | Applied in profile.d |
| **Directory ceilings** — `MISE_CEILING_PATHS="$HOME"`                                                                              | Applied in profile.d |
| **Trusted dotfiles source** — chezmoi source in `trusted_config_paths`; `chezmoi apply` runs `mise trust` on global + repo configs | Applied              |

Before running `mise trust` on a **new** repository, manually inspect `[tasks]`
and `[env]` in its `mise.toml` (and any `_.file` includes).

## Reproducibility

| Action                                                 | Status here                                                                       |
| ------------------------------------------------------ | --------------------------------------------------------------------------------- |
| **Enforce lockfiles** — `mise lock` pins binary hashes | Global `~/.config/mise/mise.lock`; repo `mise.lock`; QA uses `mise exec --locked` |

After bumping a tool version:

```bash
mise lock --global    # ~/.config/mise
mise lock             # chezmoi source (QA tools)
```

Commit updated lockfiles with the version bump.

## Secrets management

| Action                      | Guidance                                                                                                                            |
| --------------------------- | ----------------------------------------------------------------------------------------------------------------------------------- |
| **Programmatic first**      | Fetch infra secrets at runtime via centralized managers (AWS Secrets Manager, Vault, etc.) in shell hooks — not committed env files |
| **Encrypted local storage** | For local-only overrides, encrypt at rest with SOPS + age; reference via `_.file` in `mise.toml`                                    |

## CI/CD hardening

| Action                                                                                 | Status here                                                                                                                                                                                                                                                                                         |
| -------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Disable experimental features** — `MISE_EXPERIMENTAL=0`                              | Profile.d default; **GitHub Actions** `.github/workflows/pre-commit.yaml` job `env`                                                                                                                                                                                                                 |
| **Paranoid + trust (CI)** — same posture as interactive shells, scoped to the checkout | GitHub workflow: `MISE_PARANOID=1`, `MISE_TRUSTED_CONFIG_PATHS` = `${{ github.workspace }}`. No `MISE_CEILING_PATHS`: mise excludes the ceiling dir itself, so pointing it at the workspace hides the repo's own `.mise.toml`; paranoid mode already hard-fails on configs outside the trusted path |
| **Locked tool runs in CI** — `mise exec --locked`                                      | GitHub pre-commit + Neovim steps; `qa.just` / `.pre-commit-config.yaml` locally                                                                                                                                                                                                                     |

In CI scripts that invoke mise, export the same vars (or the workspace-scoped
equivalents above on shared runners) and use `mise exec --locked`.

## Quick verification

```bash
mise settings disable_backends   # expect: ["asdf"]
echo "$MISE_PARANOID $MISE_CEILING_PATHS $MISE_EXPERIMENTAL"
mise exec --locked -- shellcheck --version   # from chezmoi source
```
