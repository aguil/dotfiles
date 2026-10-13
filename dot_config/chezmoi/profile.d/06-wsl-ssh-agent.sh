# Bridge the 1Password SSH agent on Windows into WSL.
#
# 1Password serves its agent on the Windows named pipe
# //./pipe/openssh-ssh-agent. socat listens on ~/.ssh/agent.sock and hands each
# connection to npiperelay.exe, which talks to the pipe, so WSL's OpenSSH (ssh,
# ssh-add, ssh -A) can use keys held in 1Password.
#
# This lives in profile.d because ~/.bash_profile and ~/.zshrc both source
# profile.d, while bash login shells never read ~/.profile once ~/.bash_profile
# exists. ~/.profile sources this file too and checks WSL_SSH_RELAY_ACTIVE to
# decide whether to fall back to a local ssh-agent.

_chez_wsl_ssh_agent_relay() {
  [ -n "${WSL_DISTRO_NAME:-}" ] || return 0
  if [ -n "${ZSH_VERSION:-}" ]; then
    setopt local_options null_glob
  fi

  local sock="$HOME/.ssh/agent.sock"
  local relay="${NPIPERELAY_PATH:-}"
  local win_user candidate

  # Leave a socket someone else set (an SSH session into WSL, an IDE forward)
  # alone; the relay only manages its own path.
  case "${SSH_AUTH_SOCK:-}" in
    '' | "$sock") ;;
    *) return 0 ;;
  esac

  if [ -z "$relay" ]; then
    relay="$(command -v npiperelay.exe 2>/dev/null || true)"
  fi
  if [ -z "$relay" ]; then
    win_user="${WINDOWS_USER:-}"
    if [ -z "$win_user" ] && command -v cmd.exe >/dev/null 2>&1; then
      win_user="$(cmd.exe /c "echo %USERNAME%" 2>/dev/null | tr -d '\r')"
    fi
    win_user="${win_user:-$USER}"
    for candidate in \
      "/mnt/c/Users/$win_user/bin/npiperelay.exe" \
      "/mnt/c/Users/$win_user"/AppData/Local/Microsoft/WinGet/Packages/jstarks.npiperelay*/npiperelay.exe \
      "/mnt/c/Users/$win_user"/AppData/Local/Microsoft/WinGet/Packages/albertony.npiperelay*/npiperelay.exe; do
      if [ -x "$candidate" ]; then
        relay="$candidate"
        break
      fi
    done
  fi

  [ -x "$relay" ] || return 0
  command -v socat >/dev/null 2>&1 || return 0
  export NPIPERELAY_PATH="$relay"

  if ! ss -xl 2>/dev/null | grep -Fq "$sock"; then
    rm -f "$sock"
    (setsid socat UNIX-LISTEN:"$sock",fork EXEC:"$relay -ei -s //./pipe/openssh-ssh-agent" >/dev/null 2>&1 &)
  fi

  export SSH_AUTH_SOCK="$sock"
  # shellcheck disable=SC2034 # read by ~/.profile
  WSL_SSH_RELAY_ACTIVE=1
}

_chez_wsl_ssh_agent_relay
unset -f _chez_wsl_ssh_agent_relay
