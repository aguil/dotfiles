# Skill Routing

- Before acting, load the matching skill when a trigger condition applies.
- Triggers should be intent-based (for example: "cross-repo change",
  "dependency edit", "CI failure") rather than vendor/tool names.
- Route to vendor-specific skills only from overlay files, not from base rules.
- Keep routing entries short and deterministic so they are easy to audit.
