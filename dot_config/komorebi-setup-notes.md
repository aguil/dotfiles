# Komorebi Setup Notes

## Core startup

`C:\Users\jason\.config\start-komorebi.cmd`  
Starts komorebi, bars, whkd, and `workspace-cycle.ahk`. Includes retry logic for
komorebi startup timing.

### Why komorebi starts with `--clean-state`

On a clean stop, komorebi saves its workspaces to `%TEMP%\komorebi.state.json`.
The next start restores them **by monitor position**, not by monitor, and the
saved names and layouts replace the ones from `komorebi.json`. If the monitors
were in a different order when the file was saved, the labels land on the wrong
displays, and each later stop saves the mistake again.

`--clean-state` skips that restore. The tradeoff is that a restart does not
remember which workspace each window was on. Both restart paths pass it:
`start-komorebi.cmd` and `Alt+Shift+C` in `whkdrc`.

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

Maps a 1-based slot number to a fixed label: slots 1–9 are always I1 I2 I3 · E4
E5 E6 · E7 E8 E9. If the monitor that owns a label is disconnected, the slot
falls back to the matching internal workspace (4 and 7 → I1, 5 and 8 → I2, 6 and
9 → I3). If neither exists, it does nothing.

### `workspace-ring.ps1`

Cycles through all workspaces across all monitors in a global ring
(previous/next). Adapts to the number of currently detected monitors.

### `workspace-cycle.ps1`

Logging variant of the ring-cycle script. Writes to
`%LOCALAPPDATA%\komorebi\workspace-cycle.log`.

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

The workspace names come from `komorebi.json`; komorebi applies them to each
display it matches in `display_index_preferences`.

### Finding the display ID for `display_index_preferences`

Each entry can be a monitor serial number or a device ID. Use the **serial
number** for external monitors. Device IDs end in `UID{number}`, which Windows
assigns per connection: the ViewSonic and ASUS have traded UIDs several times,
which left neither matched. Keep the device ID for the internal panel, whose
serial is just `0`.

Run this in PowerShell after all monitors are connected:

```powershell
komorebic monitor-information | ConvertFrom-Json |
    Format-List device, device_id, serial_number_id
```

The dotfiles repo is public, so the serials stay in the local chezmoi config
(`~/.config/chezmoi/chezmoi.toml`):

```toml
[data.komorebi]
  viewsonicSerial = "..."
  asusSerial = "..."
```

`chezmoi init` fills each value from the first source that has one:

1. `CHEZMOI_KOMOREBI_VIEWSONIC_SERIAL` or `CHEZMOI_KOMOREBI_ASUS_SERIAL`
2. The value already in the config
3. The serial Windows recorded for that model (`scripts/monitor-serial.ps1`). It
   stays blank if the model was never connected or has two different serials.

While both are blank, chezmoi skips `komorebi.json`. The existing value wins
over detection, so when replacing a monitor, edit the value. Then run
`chezmoi apply ~/komorebi.json` and `start-komorebi.cmd`.

Saving `komorebi.json` makes komorebi reload it, which reapplies names and
layouts but does not reorder monitors. `komorebic reload-configuration` does not
read `komorebi.json` at all: it only runs `komorebi.ps1` or `komorebi.ahk` from
the home folder, and this setup has neither.

## Troubleshooting

### Workspaces look wrong after monitor changes

1. Run `C:\Users\jason\.config\start-komorebi.cmd`
2. If still wrong, check that each external monitor's `serial_number_id` from
   `komorebic monitor-information` (and the internal panel's `device_id`)
   appears under `display_index_preferences` in `komorebi.json`.
