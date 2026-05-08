# Global Instructions

Use this file as the canonical, vendor-agnostic global instruction source.

- Load matching skills before acting when a trigger condition applies.
- Keep commits atomic and branch naming consistent across related repos. For
  message shape: agents and automation **always** include a short commit body
  unless the user marks the change trivial-only (see `commit-messages.md`).
- For multi-repo changes, identify dependencies and land updates in order.
- Remove temporary dependency overrides before PRs leave draft.

See companion policy modules in this directory:

- `commit-messages.md`
- `core-principles.md`
- `cross-repo-workflow.md`
- `skill-routing.md`
