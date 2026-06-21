# Komorebi Setup Notes

## Core startup

`C:\Users\jason\.config\start-komorebi.cmd`  
Starts komorebi, bars, whkd, and `workspace-cycle.ahk`. Includes retry logic for
komorebi startup timing.

## Scheduled tasks

| Task name               | Trigger              | Action                                                   |
| ----------------------- | -------------------- | -------------------------------------------------------- |
| `StartKomorebi`         | Logon (delayed)      | `cmd.exe /c "C:\Users\jason\.config\start-komorebi.cmd"` |
| `StartKomorebiOnUnlock` | Session unlock event | `cmd.exe /c "C:\Users\jason\.config\start-komorebi.cmd"` |

## Hotkeys

`C:\Users\jason\.config\whkdrc` — main window-management hotkeys (focus / move /
stack / resize / layout / etc). Workspace number bindings are intentionally
handled by AutoHotkey, not whkd.

### Why AutoHotkey handles workspace number bindings

In this setup, whkd reliably captures most window-management bindings, but
workspace-number style bindings (`Alt+1..9` and related cycle combos) were
intermittently dropped after the first successful trigger. The `komorebic`
commands and workspace scripts were verified to work when run directly, so the
issue was input-hook reliability for those specific hotkeys, not command
correctness. AutoHotkey v2 provided stable repeated capture for these workspace
bindings, so workspace focus/move/cycle keys were moved to `workspace-cycle.ahk`
while keeping the rest of the keymap in whkd.

## AutoHotkey workspace layer

`C:\Users\jason\.config\workspace-cycle.ahk` — reliable workspace hotkeys and
ring cycling.

| Key                     | Action                                      |
| ----------------------- | ------------------------------------------- |
| `Alt+1`–`Alt+9`         | Focus workspace (slot → named ws, adaptive) |
| `Alt+Shift+1`–`+9`      | Move window to workspace (adaptive)         |
| `Win+F7` / `Ctrl+Alt+7` | Cycle previous workspace in global ring     |
| `Win+F8` / `Ctrl+Alt+8` | Cycle next workspace in global ring         |

## Workspace scripts

### `workspace-target.ps1`

Maps a 1-based slot number to a named workspace.

| Monitors | Slot → workspace                            |
| -------- | ------------------------------------------- |
| 3+       | I1 I2 I3 · E4 E5 E6 · E7 E8 E9 (slots 1–9)  |
| 2        | I1 I2 I3 · E4 E5 E6 (slots 1–6)             |
| 1        | I1 I2 I3 · I1 I2 I3 (slots 1–6, duplicated) |

### `workspace-ring.ps1`

Cycles through all workspaces across all monitors in a global ring
(previous/next). Adapts to the number of currently detected monitors.

### `workspace-cycle.ps1`

Logging variant of the ring-cycle script. Writes to
`%LOCALAPPDATA%\komorebi\workspace-cycle.log`.

### `workspace-reconcile.ps1`

Ensures workspace names exist and are correct after startup or monitor
reconnect. Called once at AHK startup and then every 15 seconds via `SetTimer`.

## Komorebi config files

| File                                 | Purpose                     |
| ------------------------------------ | --------------------------- |
| `C:\Users\jason\komorebi.json`       | Main komorebi configuration |
| `C:\Users\jason\komorebi.bar.0.json` | Bar config for monitor 0    |
| `C:\Users\jason\komorebi.bar.1.json` | Bar config for monitor 1    |
| `C:\Users\jason\komorebi.bar.2.json` | Bar config for monitor 2    |

## Monitor / workspace layout

| Index | Workspaces   | Notes                                     |
| ----- | ------------ | ----------------------------------------- |
| 0     | I1 · I2 · I3 | Internal / primary                        |
| 1     | E4 · E5 · E6 | External monitor 1 (ViewSonic)            |
| 2     | E7 · E8 · E9 | External monitor 2 (ASUS VP28U, portrait) |

### Finding the display ID for `display_index_preferences`

The identifier strings are stable Windows PnP hardware paths (not the ephemeral
HMONITOR handles that `komorebic state` returns). Run this in PowerShell after
all monitors are connected:

```powershell
Get-PnpDevice -Class Monitor | ForEach-Object {
    $s = $_.InstanceId -split '\\'
    [PSCustomObject]@{ Name=$_.FriendlyName; KomorebiId="$($s[1])-$($s[2])" }
} | Format-List
```

Each `KomorebiId` value is in the `{DEVICE}-{path}&UID{number}` format that
komorebi expects. Copy the value for the AUS28B1 (DISPLAY3) entry into
`komorebi.json` under `display_index_preferences."2"`.

## Troubleshooting

### Workspaces look wrong after monitor changes

1. Run `C:\Users\jason\.config\start-komorebi.cmd`
2. If still wrong, run:

```powershell
powershell -ExecutionPolicy Bypass -File C:\Users\jason\.config\workspace-reconcile.ps1
```
