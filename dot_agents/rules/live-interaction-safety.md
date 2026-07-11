# Live Interaction Safety

Agents run in the operator's real environment. Commands that are fine in CI can
end sessions, break reload, or corrupt long-lived state when the operator is
actively working.

## Default stance

- **Assume the operator has live sessions** (tmux, SSH, IDE terminals, GUI
  terminals) unless they say otherwise.
- **Prefer non-destructive verification** over "restart to pick up changes."
- **Do not run lifecycle commands** that tear down user processes unless the
  operator explicitly asks.

## Forbidden without explicit user request

| Class                              | Examples                                                                                                              |
| ---------------------------------- | --------------------------------------------------------------------------------------------------------------------- |
| Multiplexer / session teardown     | `tmux kill-server`, `tmux kill-session`, closing all panes                                                            |
| Broad signal storms                | `pkill tmux`, `killall`, `systemctl restart` on user daemons                                                          |
| Forced config reload on live stack | `chezmoi apply` on files the operator is using _and_ immediate `source` / `tmux source-file` without a parsed dry run |
| Interactive VCS                    | `git` / `jj` commands that require a TTY or rewrite history the operator did not request                              |

## Allowed verification patterns

| Goal                     | Prefer                                                                                                                                                                                     | Avoid                                                                             |
| ------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | --------------------------------------------------------------------------------- |
| Syntax-check tmux config | Render to a temp file; `tmux -f /tmp/tmux.conf start-server \; display-message ok` **without** `kill-server` on the default socket                                                         | `kill-server` on the default socket as part of "validation"                       |
| tmux runtime experiments | `tmux -L agent-debug-…` scratch server; `tmux -L … kill-server` when done. On the default socket: unique debug session name + `trap`/`kill-session` for **only** that name before task end | Detached `tmux new-session -d -s sixel-diag` (etc.) left on the operator's server |
| Syntax-check shell       | `bash -n`, `zsh -n`, `shellcheck`                                                                                                                                                          | `source ~/.bashrc` in the agent's shell to "test"                                 |
| Chezmoi template         | `chezmoi execute-template < file.tmpl`; `chezmoi apply --dry-run --verbose`                                                                                                                | `chezmoi apply --force` on live interactive files while operator is in tmux       |
| Reload after fix         | Tell operator to run `prefix + r` or open a **new** terminal tab                                                                                                                           | Reloading from an agent mid-task without warning                                  |

## When changing interactive config

1. **Read** the applied file (`~/.tmux.conf`, terminal settings, shell rc) _and_
   the chezmoi source.
2. **Render** templates before claiming they are valid.
3. **Show** the operator what will change in files that affect live sessions.
4. **Apply** only when asked, or when the task clearly includes apply.
5. **Reload** is the operator's step unless they delegate it.

## Chezmoi templates

- Avoid aggressive trim (`{{-` / `-}}`) next to content lines; it can glue
  comments or directives onto the previous line and produce parse errors in
  tmux, sshd, etc.
- After editing `.tmpl` files that affect interactive tools, run
  `chezmoi execute-template` and inspect the **rendered** output, not only the
  template source.

## Communication

If a fix requires reload, restart, or new terminal tab, say so plainly and **do
not** run the disruptive step yourself unless asked.
