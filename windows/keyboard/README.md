# Caps Lock to Ctrl (Scancode Map)

This folder stores a machine-level keyboard remap for Windows:

- Source key: Caps Lock
- Destination key: Left Ctrl

Because this uses `Scancode Map` under `HKLM`, it applies system-wide, including elevated apps.

## Files

- `caps-to-ctrl.reg`: apply the remap
- `caps-to-ctrl-undo.reg`: remove the remap value
- `apply.ps1`: idempotent admin script to apply the remap

## Apply

Option 1 (script, recommended):

```powershell
powershell -ExecutionPolicy Bypass -File .\windows\keyboard\apply.ps1
```

Option 2 (manual):

1. Right-click `caps-to-ctrl.reg`
2. Choose **Merge**
3. Approve UAC prompt

## Undo

1. Right-click `caps-to-ctrl-undo.reg`
2. Choose **Merge**
3. Approve UAC prompt

## Notes

- Requires Administrator privileges.
- Sign out or reboot after apply/undo.
- Registry path: `HKLM\SYSTEM\CurrentControlSet\Control\Keyboard Layout`
- Value name: `Scancode Map` (REG_BINARY)
