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
includes would pull the same text, but several Claude clients ask for **separate
read permissions** on each referenced path under `~/.agents`; a single published
file avoids that friction while keeping `~/.agents/rules/` the place to edit.

Cursor note:

- Cursor global behavior is best handled with User Rules in Cursor settings.

## PR descriptions

Agents run the `visual-pr` skill after opening a PR. A rule in
`global-instructions.md` (mirrored in `cursor-user-rules.md`) asks for it, and
`~/.local/bin/visual-pr-hook` reminds the agent right after `gh pr create`,
`gh pr new`, or `fj pr create` succeeds.

- Claude: `PostToolUse` entry merged by `dot_claude/modify_settings.json.tmpl`.
- Cursor: `postToolUse` entry merged into `~/.cursor/hooks.json` by
  `.chezmoiscripts/run_after_27-cursor-agent-hooks.sh`.

The skill in `dot_agents/skills/visual-pr/` is an unmodified copy of
`humanlayer/skills`; keep local behavior in the rule and hook so it can be
refreshed from upstream.

## PR readiness

Agents open PRs as drafts and mark them ready only after self-review covers the
current head. A rule asks for it, and `~/.local/bin/self-review-gate` checks it
before the command runs:

| Command                                    | Result |
| ------------------------------------------ | ------ |
| `gh pr create` without `--draft`           | Denied |
| `gh pr ready`, no review of the head       | Denied |
| `gh pr ready`, findings left               | Asks   |
| `gh pr ready`, incomplete review           | Asks   |
| `gh pr ready`, `gh` or results unusable    | Asks   |
| PR command in a `bash -c` or `eval` string | Asks   |
| `gh pr ready`, clean review of the head    | Passes |

A review counts when a `.agents-code-review/runs/*/result.json` in the PR's
checkout has a matching `pr_number` and `pr_reviewed_head_sha`. The newest match
decides, and it reads `findings` because triage `items` can hide a real finding.

- Claude: `PreToolUse` entry merged by `dot_claude/modify_settings.json.tmpl`.
- Cursor: `beforeShellExecution` entry merged by
  `.chezmoiscripts/run_after_27-cursor-agent-hooks.sh`.

Hooks only see agent tool calls, so an operator can run either command directly.
The gate doesn't cover the GitHub UI or `gh api`.
