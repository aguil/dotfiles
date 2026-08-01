# Agent CLI context statusline

Shared context-usage meter for **Cursor CLI** (`cursor-agent` / `agent`) and
**Claude Code**. Warns at yellow/red thresholds so you can compact deliberately
instead of waiting for auto-summarize / auto-compact.

## Behavior

Both CLIs run `~/.local/bin/ai-statusline` as a `statusLine` command. On each
UI update it reads session JSON from stdin and prints a colored bar:

| `context_window_size` | Yellow | Red | Hint command |
| --------------------- | ------ | --- | ------------ |
| &lt; 500k (200K-class)  | 65%    | 85% | `/summarize` (Cursor) |
| ≥ 500k (1M-class)     | 20%    | 65% | `/compact` (Claude) |

Agent detection: Claude payloads include `cost`, `rate_limits`, and/or
`exceeds_200k_tokens`; otherwise Cursor is assumed.

On an **upward** level change (green→yellow, yellow→red) the statusline rings
BEL once per level per session. Usage dropping back below yellow clears the
latch.

Session breadcrumbs live under
`${XDG_CACHE_HOME:-~/.cache}/ai-context-alerts/<session_id>.json`.

### Claude Code Stop hook

`~/.claude/hooks/context-threshold-stop.sh` runs on `Stop`. When the breadcrumb
shows yellow/red and that level has not yet been stop-notified, it returns:

- `systemMessage` — user-visible nudge in the Claude UI
- `terminalSequence` — OSC 777 desktop notify + BEL

Cursor CLI cannot mirror this today: interactive `cursor-agent` only fires
shell hooks, and IDE `stop` only supports `followup_message` (auto-submits a
prompt), not a passive user alert. Cursor relies on the statusline + BEL.

## Source → applied

| Source | Target |
| ------ | ------ |
| `dot_local/bin/executable_ai-statusline` | `~/.local/bin/ai-statusline` |
| `dot_local/bin/lib/ai-context-thresholds.sh` | `~/.local/bin/lib/ai-context-thresholds.sh` |
| `dot_claude/settings.json.tmpl` | `~/.claude/settings.json` |
| `dot_claude/hooks/executable_context-threshold-stop.sh` | `~/.claude/hooks/context-threshold-stop.sh` |
| `.chezmoiscripts/run_after_25-cursor-statusline.sh` | merges `statusLine` into `~/.cursor/cli-config.json` |

`cli-config.json` is **not** fully managed (model/auth/state stay local). The
run-after only sets/updates the `statusLine` object. Claude `settings.json` **is**
fully managed from the template — edit the chezmoi source, not only the live
file.

## Overrides

```bash
export AI_CTX_YELLOW=50
export AI_CTX_RED=80
```

Both must be set to override the window-size defaults.

## Apply and reload

```bash
chezmoi apply ~/.local/bin/ai-statusline \
  ~/.local/bin/lib/ai-context-thresholds.sh \
  ~/.claude/settings.json \
  ~/.claude/hooks/context-threshold-stop.sh
# run_after_25 merges Cursor statusLine on full apply; or run it once:
bash ~/.local/share/chezmoi/.chezmoiscripts/run_after_25-cursor-statusline.sh
```

Restart the Cursor CLI / Claude Code session (or start a new one) so
`statusLine` / hooks reload. See `docs/agent-live-systems.md` for general
apply/reload hygiene.

## Smoke test

```bash
echo '{"session_id":"probe","model":{"display_name":"Test"},"context_window":{"used_percentage":70,"context_window_size":200000}}' \
  | ~/.local/bin/ai-statusline

echo '{"session_id":"probe","model":{"display_name":"Opus"},"context_window":{"used_percentage":25,"context_window_size":1000000},"cost":{}}' \
  | ~/.local/bin/ai-statusline
```

Expect yellow hints at those percentages, with `/summarize` vs `/compact`
respectively. Clean up with
`rm -f ~/.cache/ai-context-alerts/probe.json`.
