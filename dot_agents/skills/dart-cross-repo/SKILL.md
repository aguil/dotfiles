---
name: dart-cross-repo
description: >-
  Dart/Flutter gotchas when a change spans multiple repos: nested pub roots,
  lockfile hygiene, dependency_overrides, dart_dev format, and common CI
  error translations. Use whenever touching `pubspec.yaml`, `pubspec.lock`,
  `dependency_overrides`, or debugging `pub get` / `dart analyze` failures
  in a task.
---

# Dart in cross-repo tasks

## Find every pub root

A "repo" in `task.json` may have more than one `pubspec.yaml`. Before
running `pub get`, list them:

    fd -HI pubspec.yaml --max-depth 3
    # or: find . -maxdepth 3 -name pubspec.yaml

Common nested roots:
- `app/pubspec.yaml` (Flutter app) alongside top-level `pubspec.yaml`.
- `example/`, `tool/`, integration test packages.

Each root has its own `pubspec.lock`. Changing a version at the top level
without running `pub get` in the nested roots leaves stale lockfiles and
consumer CI will fail in confusing ways.

## Lockfile hygiene

- Commit the `pubspec.lock` changes that correspond to your `pubspec.yaml`
  changes — **never** mass-upgrade unrelated deps in a feature PR.
- If `pub get` pulls in unrelated transitive bumps, checkout the old lock,
  change only what you intended, then `dart pub get --offline` once to
  validate resolution.
- When switching from a `git:` override to a version, delete the old lock
  entries for that package before `pub get` to avoid sticky resolutions:

      dart pub cache clean -f <pkg>  # if needed
      rm -f pubspec.lock
      dart pub get

## dependency_overrides in this ecosystem

- Place overrides **only at the top-level `pubspec.yaml`** of each root.
  They don't propagate from a parent directory.
- Keep overrides in a single block at the end of the file so they're easy
  to strip before review.
- When both a path override and a git override are needed for different
  packages, group them with a comment:

        dependency_overrides:
          # Local path while iterating; remove before review.
          producer_pkg:
            path: ../producer

          # Branch override until producer release cuts.
          shared_pkg:
            git:
              url: https://github.com/<org>/shared.git
              ref: feat/<project>/<task-id>

See `~/.agents/skills/cross-repo-change/DEPENDENCY-OVERRIDES.md` for the
full ladder.

## Code generation

If the project uses codegen (build_runner, openapi-generator,
protoc-plugins, etc.):

- Regenerate after changing the spec or generator config. Project-specific
  wrappers usually live under `tool/` or in a `Makefile` / `Justfile`.
- Commit generated code **in its own commit**, e.g.
  "Regenerate clients for <tag>". It should be mechanical and reviewable
  independently from behavioural changes.
- If generation needs network access to an internal host, see the work
  overlay (`~/.agents/AGENTS.work.md`) for preflight checks.

## Formatting and analysis

Run in each pub root before pushing:

    dart format .
    dart analyze
    # or project-specific:
    dart run dart_dev format .
    dart run dart_dev analyze

Fix warnings in the **same repo PR** that introduced them. Don't punt them
to a sibling PR.

## Common CI errors → real cause

| CI error | Real cause |
|---|---|
| `Could not find a file named "pubspec.yaml" in …` | Pub root path wrong in CI config after a restructure |
| `Because <app> depends on <pkg> any which depends on …, version solving failed` | Consumer not yet pointed at producer's branch/tag |
| `The lockfile is not up to date` | Forgot `pub get` in a nested root |
| `Unhandled exception: Bad state: No host specified in URI …` | Private registry / auth — see the work overlay if one applies |
| `FormatException: Unexpected character` in generated code | Regenerated against a stale spec; re-pull producer and re-gen |

## Before requesting review

1. All `dependency_overrides` removed or replaced with tags.
2. Every `pubspec.lock` under the repo is consistent with its sibling
   `pubspec.yaml`.
3. Generated code is in a separate commit.
4. `dart analyze` is clean in every root.
