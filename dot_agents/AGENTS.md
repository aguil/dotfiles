# Global agent rules

Read the matching skill **before acting** when a trigger fires.
Project-level `AGENTS.md` files (e.g. under `~/dev/projects/<project>/` or
at a repo root) still apply and take precedence on project-specific rules.

## Work overlay

If `~/.agents/AGENTS.work.md` exists, read it **in addition to this file**.
It layers employer-specific triggers, conventions, and skills on top of
the generic rules below, and is managed from a separate private dotfiles
source.

## Triggers for skills in this directory

- **Any VCS action** → read `skills/jujutsu/SKILL.md` first. If the working
  directory is inside `~/dev/projects/<project>/`, also read
  `skills/project-task-workspaces/SKILL.md` and, for cross-repo VCS work,
  `skills/jj-cross-repo/SKILL.md`.
- **Changes spanning 2+ repos in a task** →
  `skills/cross-repo-change/SKILL.md`.
- **Touching `pubspec.yaml`, `dependency_overrides`, or `build.gradle`** →
  `skills/dart-cross-repo/SKILL.md`.
- **CI / PR check failing** → `skills/ci-triage/SKILL.md`.
- **Work on `aguil/dotfiles` or this chezmoi tree** →
  `skills/dotfiles-github-cli/SKILL.md`.

## Always-on principles

- **Read `task.json`** before acting inside
  `~/dev/projects/<project>/<type>/<task-id>/…`. It's the canonical source
  of which repos are in the task.
- **Branch / bookmark name is fixed**: `<type>/<project>/<task-id>`, used
  identically across every repo in a task.
- **PR titles carry a tracker ID suffix** when the project uses an issue
  tracker (e.g. ` (PROJ-NNNN)`). See `skills/cross-repo-change/BRANCHING.md`.
- **Commits are isolated**, one logical change per commit. Prefer splitting
  before pushing over cleanup later.
- **Strip `dependency_overrides` and `git:` refs** before a PR leaves draft;
  the final diff uses published versions or release tags.
- **Don't run `git` commands in a jj workspace** (`.jj/` present, no
  `.git/`). Use `jj` — see `skills/jujutsu/SKILL.md` and
  `skills/jj-cross-repo/SKILL.md`.
