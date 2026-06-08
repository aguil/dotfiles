# Directory listing aliases backed by eza (https://github.com/eza-community/eza).
if command -v eza >/dev/null 2>&1; then
  alias ls='eza --color=auto --group-directories-first --icons=auto'
  alias l='eza --color=auto --group-directories-first --icons=auto'
  alias ll='eza -l --color=auto --group-directories-first --icons=auto --git'
  alias la='eza -a --color=auto --group-directories-first --icons=auto'
  alias lla='eza -la --color=auto --group-directories-first --icons=auto --git'
  alias lt='eza --tree --color=auto --group-directories-first --icons=auto'
  alias lS='eza -l --sort=size --color=auto --group-directories-first --icons=auto'
fi
