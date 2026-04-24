# Core Principles

- Read relevant task metadata before making changes.
- Keep one logical change per commit.
- Use consistent branch naming across related repositories.
- Prefer splitting work before push over cleanup after push.
- Remove temporary dependency overrides before a PR leaves draft state.
- Use repository-native VCS commands safely (for example, avoid `git` inside
  a pure jj workspace).
