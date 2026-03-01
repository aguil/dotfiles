# Config matrix

This document defines how configs should be consolidated across these targets:

- `mac-work`: macOS work laptop (currently has homeshick history)
- `win-personal`: Windows 11 Pro personal laptop
- `wsl-personal`: Ubuntu 22.04.5 LTS on WSL2

The goal is one shared developer baseline with explicit, intentional exceptions.

## Layering model

- `shared`: common defaults for all systems
- `platform`: OS/runtime-specific behavior (`darwin`, `windows`, `linux`, `wsl`)
- `persona`: account/profile-specific behavior (`work`, `personal`)

Recommended precedence:

1. shared
2. platform
3. persona
4. host-specific override (rare; document in drift exceptions)

## Decision matrix

| Area | Shared baseline | Platform overrides | Persona overrides | Notes |
| --- | --- | --- | --- | --- |
| Shell core (`bash`/`zsh`) | aliases, prompt structure, functions, env defaults | path tweaks, shell startup file paths, package manager paths | none by default | keep shell behavior aligned for muscle memory |
| Git behavior | diff/merge defaults (`kdiff3`/`p4merge`), core options, global ignores | credential helper and keychain integration | `user.name`, `user.email`, signing key | work/personal identity split is required |
| SSH config | common hardening and host defaults | key storage path differences | work-only hosts and key mappings | do not store private keys in repo |
| CLI tooling | `git`, `ripgrep`, `fd`, `fzf`, language runtimes | package manager commands (`brew`, `winget`, `apt`) | optional org-specific CLIs | keep versions close where practical |
| Terminal emulator settings | baseline terminal behavior where portable | Windows Terminal profile, iTerm/mac terminal choices | none | drift acceptable when UI model differs |
| Editor/IDE baseline | formatter/linter/toolchain configs in repo | launcher/path wiring per OS | editor choice split by persona | see tooling row below |
| Tooling choice | common language/tool config | install mechanics per OS | `personal`: OpenCode + VSCode, `work`: IntelliJ IDEA + Cursor | keep non-editor tool configs shared |
| Window management | none | `komorebi` on Windows only | none | must never install/configure outside Windows |
| Neovim | one shared base config initially | path/provider differences | optional split later | defer persona split until post-basics |
| Secrets | none in plaintext | secret backend integration details | profile-specific secrets | use chezmoi secret management |

## Immediate implementation order

1. Normalize shared baseline from latest backups.
2. Implement persona identity split (`work` vs `personal`) for Git and SSH.
3. Gate all `komorebi` installation and config to Windows only.
4. Add persona-based tooling install logic (OpenCode/VSCode vs IDEA/Cursor).
5. Validate `mac-work`, `win-personal`, and `wsl-personal` apply flows.
6. Remove homeshick hooks from macOS only after clean chezmoi validation.

## Validation checklist per target

- `chezmoi apply` succeeds without manual fixes.
- `chezmoi diff` is clean after apply.
- Git identity matches persona.
- SSH hosts and keys resolve correctly for that persona.
- Expected tooling is present for that persona.
- `komorebi` assets exist only on Windows.
