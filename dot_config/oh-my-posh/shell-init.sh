# Oh My Posh — shared init for bash and zsh.
# Usage: . "${HOME}/.config/oh-my-posh/shell-init.sh" bash
#        . "${HOME}/.config/oh-my-posh/shell-init.sh" zsh
#
# Theme resolution order matches the PowerShell profile: custom JSON first,
# then Homebrew-shipped Spaceship, then a public Spaceship URL.

case "${1-}" in
bash | zsh) ;;
*)
    printf '%s\n' "oh-my-posh shell-init: first argument must be bash or zsh" >&2
    return 2 2>/dev/null || exit 2
    ;;
esac

omp_shell="$1"

[ -z "${INTELLIJ_ENVIRONMENT_READER:-}" ] || return 0
command -v oh-my-posh >/dev/null 2>&1 || return 0

omp_config=""
_omp_homebrew="${BREW_PREFIX:-${HOMEBREW_PREFIX:-}}"
if [ -f "${HOME}/.config/oh-my-posh/spaceship-custom.omp.json" ]; then
    omp_config="${HOME}/.config/oh-my-posh/spaceship-custom.omp.json"
elif [ -n "$_omp_homebrew" ] && [ -f "${_omp_homebrew}/opt/oh-my-posh/themes/spaceship.omp.json" ]; then
    omp_config="${_omp_homebrew}/opt/oh-my-posh/themes/spaceship.omp.json"
elif [ -f "/usr/share/oh-my-posh/themes/spaceship.omp.json" ]; then
    omp_config="/usr/share/oh-my-posh/themes/spaceship.omp.json"
fi

if [ -n "$omp_config" ]; then
    eval "$(oh-my-posh init "$omp_shell" --config "$omp_config")"
else
    eval "$(oh-my-posh init "$omp_shell" --config "https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/spaceship.omp.json")"
fi

unset _omp_homebrew
