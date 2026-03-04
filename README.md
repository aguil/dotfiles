Jason's dotfiles
================

This repository stores personal shell/editor/tooling config and Windows setup assets.

## Windows backups

Use `windows/backup/export.ps1` to snapshot common Windows app and terminal config into this repo.

```powershell
powershell -ExecutionPolicy Bypass -File .\windows\backup\export.ps1
```

The script is safe to re-run. It only copies files that exist and skips missing targets.

## Linux apt packages

Use `linux/backup/export-apt-packages.sh` to snapshot manual apt packages into this repo.

```bash
bash ./linux/backup/export-apt-packages.sh
```

Use `linux/backup/install-apt-packages.sh` to install from `linux/apt-packages.txt`.

## Commit messages

Use `docs/commit-message-guide.md` for commit message conventions in this repo.

## Consolidation planning

- `docs/config-matrix.md` captures what is shared vs platform-specific vs persona-specific.
- `docs/drift-exceptions.md` tracks intentional differences between systems and why they exist.
- `docs/chezmoi-profiles.md` explains `work` vs `personal` profile usage.

## Prompt snippets

Reusable prompt snippets live in `docs/prompts/`.

Use `scripts/oprompt.ps1` to print or copy one:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\oprompt.ps1 commit
powershell -ExecutionPolicy Bypass -File .\scripts\oprompt.ps1 pr-update -Copy
```

`scripts/aprompt.ps1` is kept as a backward-compatible wrapper to `scripts/oprompt.ps1`.

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\aprompt.ps1 commit
```

For WSL/macOS/Linux, use `scripts/oprompt.sh`:

```bash
./scripts/oprompt.sh commit
./scripts/oprompt.sh pr-update --copy
```

After reloading your shell, you can also call `oprompt` from anywhere:

```bash
oprompt commit
oprompt pr-update --copy
```

`aprompt` remains as a backward-compatible alias.
