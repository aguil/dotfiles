# Drift exceptions

Use this file to track intentional drift between `mac-work`, `win-personal`, and `wsl-personal`.

If it is not listed here, drift is treated as accidental and should be reduced.

## Rules

- Every exception must have a clear reason and scope.
- Prefer persona or platform overlays before host-specific overrides.
- Review all exceptions quarterly and remove stale ones.

## Exception register

| ID | Area | Scope | Exception | Reason | Owner | Added | Review cadence |
| --- | --- | --- | --- | --- | --- | --- | --- |
| EX-001 | Window manager | windows | `komorebi` install and config are Windows-only | Native Windows tiling workflow; not applicable to macOS/WSL | Jason | 2026-03-01 | Quarterly |
| EX-002 | IDE tooling | personal/work | `personal`: OpenCode + VSCode, `work`: IntelliJ IDEA + Cursor | Different workflows and licensing/account context | Jason | 2026-03-01 | Quarterly |
| EX-003 | Git identity | personal/work | Different `user.name`, `user.email`, and signing identity | Required separation of work vs personal commits | Jason | 2026-03-01 | Quarterly |
| EX-004 | Credential integration | platform | Git credential helper and keychain integration differs by OS | OS-native secure storage behavior differs | Jason | 2026-03-01 | Quarterly |
| EX-005 | Neovim profile | personal/work (planned) | Potential persona-specific Neovim overlays after base migration | Work/personal plugin and workflow needs may diverge | Jason | 2026-03-01 | Quarterly |
| EX-006 | Registry auth | work tooling | npm/artifactory auth is not managed in dotfiles | Credentials and registry injection are handled by a work-specific tool | Jason | 2026-03-01 | Quarterly |

## Review checklist

- Is this exception still required?
- Can it move to shared baseline now?
- Can host-specific logic be replaced with platform/persona logic?
- Does this exception introduce security or maintenance risk?
