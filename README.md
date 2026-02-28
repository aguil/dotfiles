Jason's dotfiles
================

This repository stores personal shell/editor/tooling config and Windows setup assets.

## Windows backups

Use `windows/backup/export.ps1` to snapshot common Windows app and terminal config into this repo.

```powershell
powershell -ExecutionPolicy Bypass -File .\windows\backup\export.ps1
```

The script is safe to re-run. It only copies files that exist and skips missing targets.

## Commit messages

Use `docs/commit-message-guide.md` for commit message conventions in this repo.

## Prompt snippets

Reusable prompt snippets live in `docs/prompts/`.

Use `scripts/oprompt.ps1` to print or copy one:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\oprompt.ps1 commit
powershell -ExecutionPolicy Bypass -File .\scripts\oprompt.ps1 pr-update -Copy
```
