# Windows backup workflow

This folder contains scripts and exported artifacts for backing up machine-specific Windows config.

## Export

Run from repo root:

```powershell
powershell -ExecutionPolicy Bypass -File .\windows\backup\export.ps1
```

The export script currently captures these targets when present:

- PowerShell 7 profile (`Documents\PowerShell\Microsoft.PowerShell_profile.ps1`)
- Windows PowerShell profile (`Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1`)
- Windows Terminal settings (`settings.json` for stable/preview packages)
- VS Code user settings and keybindings
- `winget` package export (`windows/backup/winget-packages.json`)

## Notes

- Missing files are skipped.
- Existing repo copies are overwritten with the latest local version.
- Review diffs before committing in case local app settings include machine-specific values you do not want to track.
