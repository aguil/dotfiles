# Agent subprocess detection for profile.d consumers (e.g. zoxide-init).
# Load first (00- prefix) so later snippets can branch before smart-cd init.

_is_agent_shell() {
  # Cursor IDE / CLI agent (https://cursor.com/docs/agent/tools/terminal)
  [ -n "${CURSOR_AGENT:-}" ] && return 0
  # Claude Code bash tool / hooks (https://code.claude.com/docs/en/env-vars)
  [ "${CLAUDECODE:-}" = "1" ] && return 0
  # Explicit opt-in for other agent shells (e.g. OpenCode bash tool via
  # opencode.json "env": { "CUSTOM_AGENT_SHELL": "1" })
  [ -n "${CUSTOM_AGENT_SHELL:-}" ] && return 0
  return 1
}

# Agent shells rehydrated from export -p keep env markers but may drop helper
# functions. Use this at call sites (zoxide-init) instead of _is_agent_shell alone.
_chez_agent_shell_active() {
  if type _is_agent_shell >/dev/null 2>&1 && _is_agent_shell; then
    return 0
  fi
  [ -n "${CURSOR_AGENT:-}" ] && return 0
  [ "${CLAUDECODE:-}" = "1" ] && return 0
  [ -n "${CUSTOM_AGENT_SHELL:-}" ] && return 0
  return 1
}
