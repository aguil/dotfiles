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

### `workspace-recover.ps1`

Repairs komorebi after a display change. While docking, komorebi can see a
display before Windows has given it an ID or serial, and briefly counts too many
displays. A monitor can then be left with one unnamed workspace, in the wrong
order, as a permanent `UNKNOWN` display, or without space reserved for its bar.
Windows can be left unmanaged (no frame, overlapping the bar). komorebi does not
correct this while the monitor count stays the same.

`workspace-cycle.ahk` runs the script 8 seconds after the last display change.
It waits up to 20 seconds for komorebi and Windows to agree, then:

- **Labels, order, bar spacing, a serial or a configured display is wrong:**
  runs `komorebic replace-configuration`. This rebuilds the monitor list in
  place, adopts the visible windows and restarts the bars.
- **The rebuild did not help:** runs `start-komorebi.cmd`, at most once every 10
  minutes.
- **Anything else, such as a virtual display:** logs it and changes nothing.

Reloading `komorebi.json` is not enough: it only reapplies names and layouts.
Unmanaged windows alone are not detected; run
`komorebic replace-configuration $HOME\komorebi.json` by hand for those.

#### Window placement

komorebi does not keep track of windows across a dock. Windows brings them back
before komorebi's monitor list is complete, so komorebi adopts each one wherever
it is at that moment. Windows on hidden workspaces can stay cloaked and
unmanaged, which makes them invisible; a rebuild and a restart both skip cloaked
windows.

So `workspace-cycle.ahk` also keeps `workspace-recover.ps1 -Watch` running.
About every 10 seconds it saves which workspace each tiled window is on, but
only while every configured display is present and labelled, and only if two
checks in a row agree. A display change stops the saving until recovery
finishes, or for 10 minutes. The file is
`%LOCALAPPDATA%\komorebi\workspace-placement.json`; it holds window handles,
process IDs and workspace names, not titles.

After recovery, if a display had gone away or a rebuild was needed, the script
uncloaks saved windows that komorebi forgot (with the undocumented shell call
that komorebi itself uses), sends each window back to its workspace, and
restores the visible workspaces and the focus. It must focus each window to move
it, so do not type until it is done.

- Moves made in the last 20 seconds, or while undocked, are not kept.
- Saved windows that the undock minimized are reopened. So is one you minimize
  while undocked.
- Floating, monocle and maximized windows, and those hidden to the tray, are
  left alone. The log counts them.
- Window order, splits and stacks are not restored.
- Placement is only saved and restored with all three displays. Windows on a
  display that is not in `komorebi.json` are not saved, and removing such a
  display does not start a restore.

If a restore fails, saving stays paused for up to 10 minutes. The placement it
started from is kept in `workspace-placement.previous.json` until the next
restore. To get a placement back by hand, move the windows with
`Alt+Shift+1`–`+9`.

Monitors are identified by serial or device ID, never by position. Actions and
failures are logged to `%LOCALAPPDATA%\komorebi\workspace-recover.log`.

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

1. Check `%LOCALAPPDATA%\komorebi\workspace-recover.log`.
2. Run `C:\Users\jason\.config\start-komorebi.cmd`
3. If still wrong, check that each external monitor's `serial_number_id` from
   `komorebic monitor-information` (and the internal panel's `device_id`)
   appears under `display_index_preferences` in `komorebi.json`.
