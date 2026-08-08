#!/usr/bin/env bash
# tmux-help.sh — help popups for tmux (bound to prefix + ? and prefix + /).
#
#   tmux-help.sh keys        fzf search over `list-keys -N` binding notes
#   tmux-help.sh cheatsheet  render ~/.config/tmux/cheatsheet.md
#
# Runs inside display-popup, where tmux's server PATH may lack mise shims.
set -euo pipefail

PATH="$HOME/.local/share/mise/shims:$PATH"

list_noted_keys() {
  # -N alone covers root + prefix; copy-mode-vi notes need an explicit table.
  tmux list-keys -N
  tmux list-keys -N -T copy-mode-vi | sed 's/^/[copy] /'
}

case "${1:-}" in
  keys)
    if command -v fzf >/dev/null 2>&1; then
      # fzf exits 130 on Esc; that is a normal way to close the popup.
      list_noted_keys | fzf --reverse --no-sort \
        --prompt="keys> " --header="tmux key bindings (Esc to close)" || true
    else
      list_noted_keys | less
    fi
    ;;
  cheatsheet)
    sheet="${XDG_CONFIG_HOME:-$HOME/.config}/tmux/cheatsheet.md"
    if [ ! -r "$sheet" ]; then
      echo "cheatsheet not found: $sheet (run chezmoi apply)" >&2
      exit 1
    fi
    if command -v nvim >/dev/null 2>&1; then
      # Reuse the main nvim config's render-markdown.nvim (loads on
      # ft=markdown) instead of a raw pager view. -M is view-only:
      # nomodifiable and writes refused; q quits like a pager.
      exec nvim -M \
        -c "set laststatus=0 | setlocal nonumber norelativenumber signcolumn=no" \
        -c "nnoremap q <cmd>quit!<CR>" \
        "$sheet"
    elif command -v glow >/dev/null 2>&1; then
      glow -p "$sheet"
    elif command -v batcat >/dev/null 2>&1; then
      batcat --style=plain --paging=always --language=md "$sheet"
    elif command -v bat >/dev/null 2>&1; then
      bat --style=plain --paging=always --language=md "$sheet"
    else
      less "$sheet"
    fi
    ;;
  *)
    echo "usage: tmux-help.sh {keys|cheatsheet}" >&2
    exit 2
    ;;
esac
