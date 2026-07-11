# Skill Routing

- Before acting, load the matching skill when a trigger condition applies.
- Triggers should be intent-based (for example: "cross-repo change", "dependency
  edit", "CI failure") rather than vendor/tool names.
- Route "stale bookmarks/branches", "merged PR cleanup", or "bookmark hygiene"
  intents to a branch/bookmark PR hygiene skill.
- Route "tmux", "terminal config", "chezmoi apply", "shell profile", or "reload
  dotfiles" intents to `docs/agent-live-systems.md` in the chezmoi source tree
  (for example `~/.local/share/chezmoi/docs/agent-live-systems.md`).
- Route to vendor-specific skills only from overlay files, not from base rules.
- Keep routing entries short and deterministic so they are easy to audit.
