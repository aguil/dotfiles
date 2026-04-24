## Vendor-Agnostic Global Rules

This directory contains reusable rule modules that do not depend on any
specific agent vendor.

Use this layout as the source of truth for policy. Publish the canonical
`global-instructions.md` entry point to vendor paths with
`~/.agents/scripts/sync-global-rules.sh`.

Suggested mapping:

- `global-instructions.md` -> canonical publishable global instruction file
- `core-principles.md` -> always-on policy
- `cross-repo-workflow.md` -> multi-repo workflow policy
- `skill-routing.md` -> trigger-to-skill routing policy

Notes:

- Keep vendor-specific overlays in separate files (for example
  `~/.agents/AGENTS.work.md`).
- Avoid hardcoding org names or private repo slugs in these base rule files.
