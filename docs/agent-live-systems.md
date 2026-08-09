# Agent playbook: live systems (dotfiles)

Operator-facing tools managed from this repo can break active work if an agent
reloads or tears them down carelessly. This doc complements
`dot_agents/rules/live-interaction-safety.md` with repo-specific paths and
commands.

## In scope

| Artifact         | Source                                    | Applied target                    |
| ---------------- | ----------------------------------------- | --------------------------------- |
| tmux             | `dot_tmux.conf.tmpl`                      | `~/.tmux.conf`                    |
| bash/zsh         | `dot_bash_profile.tmpl`, `dot_zshrc.tmpl` | `~/.bash_profile`, `~/.zshrc`     |
| Windows Terminal | `windows/terminal/settings.json`          | WT `settings.json` (manual merge) |
| Neovim           | `dot_config/nvim/`                        | `~/.config/nvim/`                 |

## tmux

### Safe validation (agent may run)

```bash
# From chezmoi source root
chezmoi execute-template < dot_tmux.conf.tmpl > /tmp/tmux.conf.check
tmux -f /tmp/tmux.conf.check start-server \; display-message "config ok" 2>&1
```

Do **not** append `kill-server` on the **default** socket. A second
`start-server` against an existing socket is harmless; killing the default
server ends every operator session.

### tmux experiments and debug hygiene

When testing graphics, passthrough, keybindings, or other runtime behavior, do
**not** leave detached sessions on the operator's default tmux server.

**Prefer an isolated socket** so teardown cannot touch live work:

```bash
SOCK="agent-debug-$$"
CONF=/tmp/tmux.conf.check   # or a minimal scratch config

tmux -L "$SOCK" -f "$CONF" new-session -d -s probe 'sleep 300'
# … run diagnostics against -L "$SOCK" …
tmux -L "$SOCK" kill-server
```

`kill-server` on `-L agent-debug-…` is safe: it only stops that temporary
server.

If you must use the **default** socket (e.g. to mirror the operator's live
`allow-passthrough` / terminal overrides), create a clearly named debug session
and **always** remove it before ending the task—even on failure:

```bash
DBG=sixel-probe-$$
cleanup() { tmux kill-session -t "$DBG" 2>/dev/null || true; }
trap cleanup EXIT
tmux kill-session -t "$DBG" 2>/dev/null || true
tmux new-session -d -s "$DBG"
# … work …
cleanup
```

Use a unique `$DBG` name (PID suffix, timestamp). Never reuse generic names like
`sixel-diag`, `wraptest`, or `wraprun` on the default socket; they are easy to
orphan across agent turns.

Before closing a task that touched tmux at runtime, run `tmux list-sessions` and
confirm no agent-owned debug names remain.

### Unsafe (require explicit operator request)

```bash
tmux kill-server
tmux kill-session -t …
tmux source-file ~/.tmux.conf   # when config may still be broken
chezmoi apply --force ~/.tmux.conf   # overwrites live file mid-session
```

### Operator reload (after a good apply)

```text
prefix + r    # bound to source-file ~/.tmux.conf in dot_tmux.conf.tmpl
```

### Template gotcha (real incident)

Chezmoi trim glued a comment onto a `set-option` line:

```tmux
set-option -g @plugin "…tokyo-night-tmux"# Match Neovim …
```

tmux error: `command set-option: too many arguments`.

**Fix:** use `{{ … }}` without `{{- … -}}` beside config lines; always inspect
rendered output around template directives.

### tmux-tmuxr / work

- Plugin loads from `~/dev/projects/tmuxr/tmux-tmuxr` when present (conditional
  in template).
- Build `work` before expecting plugin hooks to work:
  `cd ~/dev/projects/tmuxr/work && npm run build`.
- See `~/dev/projects/tmuxr/tmux-tmuxr/README.md` for keybindings.

## Chezmoi apply

```bash
chezmoi apply --dry-run --verbose path/to/target
chezmoi execute-template < path/to/file.tmpl
chezmoi apply path/to/target    # only when operator wants live update
```

Interactive files (`~/.tmux.conf`, shell rc): prefer dry-run + rendered diff,
then let the operator apply or explicitly delegate apply + reload.

## Windows Terminal

`windows/terminal/settings.json` is a tracked backup/export, not always the live
file. Enabling Sixel (`experimental.sixelSupport` in profile defaults) requires
merge into live WT settings and a **full WT restart** (all windows). Agents
should describe that step, not assume `chezmoi apply` updates the running
terminal.

Tracked defaults **do not** rebind Ctrl+V; text paste stays on Ctrl+V. Agent
clipboard images use tmux `prefix + p` (`paste-image-agent.sh` in
`dot_tmux.conf.tmpl`), not WT keybindings.

## Agent CLI statusline / hooks

Context meter and Claude `Stop` latch:
[`docs/ai-cli-context-statusline.md`](ai-cli-context-statusline.md). After
apply, **restart** Cursor CLI / Claude Code so `statusLine` and hooks reload; do
not treat a live session as validation of the new config.

## Checklist before closing a dotfiles task

- [ ] Rendered config parses (`tmux -f …`, `bash -n`, JSON valid for WT)
- [ ] No `kill-server` / `pkill` on the **default** tmux socket during
      validation
- [ ] Agent-owned tmux debug sessions removed (`tmux list-sessions`; prefer `-L`
      scratch sockets killed with `tmux -L … kill-server`)
- [ ] Operator told if reload, new tab, or WT restart is needed
- [ ] Template whitespace checked around `{{ if }}` / variable assignments
