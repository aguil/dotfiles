# Vendor Global Rules Scaffold

Canonical source:

- `~/.agents/rules/global-instructions.md`

Reusable policy modules:

- `~/.agents/rules/`

Publisher:

- `~/.agents/scripts/sync-global-rules.sh`

## Recommended strategy

Use **copy mode** by default:

```bash
~/.agents/scripts/sync-global-rules.sh copy
```

Why:

- More resilient when tools overwrite files directly.
- Avoids symlink edge cases in tools that resolve paths in unusual ways.
- Easier to inspect each vendor's currently loaded file independently.

Use **symlink mode** only if you explicitly want a single live file view:

```bash
~/.agents/scripts/sync-global-rules.sh symlink
```

Symlink caveats:

- Vendor tools may replace symlinks with regular files during updates.
- Some backup/sync tools follow links and can create unexpected writes.
- If `~/.agents/rules/global-instructions.md` is unavailable, linked targets
  break.

## Vendor targets

- Claude: `~/.claude/CLAUDE.md`
- OpenCode: `~/.config/opencode/AGENTS.md`

## Claude overlays for vendor-global extensions

Place Claude-specific overlays in `~/.agents/rules/claude-*.md`.

`sync-global-rules.sh` (copy mode) writes `~/.claude/CLAUDE.md` by **inlining**
`global-instructions.md`, any `claude-*.md` files, and `work-overlay.md` when
that file exists, into one document (with `---` separators). A manifest of `@`
includes would pull the same text, but several Claude clients ask for
**separate read permissions** on each referenced path under `~/.agents`; a
single published file avoids that friction while keeping `~/.agents/rules/` the
place to edit.

Cursor note:

- Cursor global behavior is best handled with User Rules in Cursor settings.
