Jason's dotfiles
================

This repository stores personal shell/editor/tooling config and Windows setup assets.

## Windows backups

Use `windows/backup/export.ps1` to snapshot common Windows app and terminal config into this repo.

```powershell
powershell -ExecutionPolicy Bypass -File .\windows\backup\export.ps1
```

The script is safe to re-run. It only copies files that exist and skips missing targets.
