# tmux cheatsheet

Prefix is `C-b`. Keys are prefixed unless marked **root** (no prefix needed).

## Help

| Key | Action                                       |
| --- | -------------------------------------------- |
| `?` | Search all key bindings (fzf)                |
| `/` | This cheatsheet                              |
| `C` | customize-mode: browse/edit options and keys |

## Sessions and windows

| Key       | Action                                                                     |
| --------- | -------------------------------------------------------------------------- |
| `s`       | Choose session — `0-9`, then letters after the 9th                         |
| `w`       | Choose window from tree                                                    |
| `$` / `,` | Rename session / window                                                    |
| `c`       | New window                                                                 |
| `n`       | Next window (`p` is remapped to image paste — use `n`, numbers, or 󰁯 last) |
| `0-9`     | Jump to window by number                                                   |
| `d`       | Detach                                                                     |
| `r`       | Reload tmux config                                                         |

## Panes

| Key                  | Action                                                    |
| -------------------- | --------------------------------------------------------- |
| `"` / `%`            | Split below / right (keeps cwd)                           |
| **root** `C-h/j/k/l` | Focus pane left/down/up/right (vim-aware)                 |
| **root** `C-\`       | Focus last pane (vim-aware)                               |
| `h/j/k/l`            | Select pane (repeatable)                                  |
| `H/J/K/L`            | Resize by 5 (Shift)                                       |
| `C-h/j/k/l`          | Resize by 5 (no Shift — for when macOS eats Shift chords) |
| `M-h/j/k/l`          | Resize by 5 (Option/Meta)                                 |
| `z`                  | Zoom/unzoom pane (status shows 󰊓 when zoomed)             |
| `t`                  | Tile panes evenly                                         |
| `x`                  | Kill pane                                                 |

## Copy mode and clipboard

| Key               | Action                                               |
| ----------------- | ---------------------------------------------------- |
| `[`               | Enter copy mode (vi keys)                            |
| `v` / `V` / `C-v` | Character / line / rectangle selection               |
| `y`               | Yank to system clipboard (falls back to tmux buffer) |
| `]`               | Paste tmux buffer                                    |
| `P`               | Paste from system clipboard (macOS)                  |
| `Y`               | Copy top tmux buffer to system clipboard (macOS)     |
| `b`               | Clear screen and scrollback                          |

## Plugins

| Key           | Action                                                                     |
| ------------- | -------------------------------------------------------------------------- |
| `I` / `U`     | TPM: install / update plugins                                              |
| `C-s` / `C-r` | resurrect: save / restore session state (continuum autosaves every 10 min) |
| `F`           | tmux-fzf menu (sessions, windows, panes, keybindings — selecting runs it)  |
| `S`           | tmuxr: track session and scan agents                                       |
| `W`           | tmuxr: toggle agent sidebar                                                |
| `p`           | Paste clipboard image into agent prompt                                    |

## Gotchas

- Bare `C-h/j/k/l` can be eaten before tmux sees them: `C-h` as backspace, `C-l`
  by readline clear-screen when the shell gets the key first. Fall back to
  `prefix + h/j/k/l`, or enable CSI-u style modifier reporting in iTerm/Ghostty
  and disable Secure Keyboard Entry while testing.
- Inside Neovim, `C-h/j/k/l` belong to vim-tmux-navigator; tmux only handles
  them in non-vim panes.
- Option-based resize (`M-h/j/k/l`) needs the terminal to send Option as Meta
  (iTerm: Left Option → Esc+; Kitty: `macos_option_as_alt`).
