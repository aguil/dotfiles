# Core Principles

- Read relevant task metadata before making changes.
- Keep one logical change per commit.
- Use consistent branch naming across related repositories.
- Prefer splitting work before push over cleanup after push.
- Remove temporary dependency overrides before a PR leaves draft state.
- Use repository-native VCS commands safely (for example, avoid `git` inside a
  pure jj workspace).
- Prefer `rg` (ripgrep) over `grep -r` for file-content searches when `rg` is
  installed; it honors `.gitignore`, parallelizes, and skips binaries, which
  turns multi-second scans of a large tree into a fraction of a second.
