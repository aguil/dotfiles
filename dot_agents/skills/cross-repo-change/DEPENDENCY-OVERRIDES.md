# Dependency override ladder

When a producer PR and a consumer PR are both in flight, the consumer has
to point at the producer's in-progress code. Use the **lowest rung that
works**, and always climb up before the consumer PR leaves draft.

## The ladder (low → high)

1. **Local path override** — fastest inner loop, never pushed.
   - `pubspec.yaml`: `dependency_overrides: { pkg: { path: ../producer } }`
   - `build.gradle`: `includeBuild '../producer'` in `settings.gradle`.
   - npm/yarn: `"resolutions"` with `file:` / `link:` protocol, or
     `npm link`.
   - Good for: iterating while both checkouts are editable in the same
     task.
   - Never: commit this to a PR that will leave draft.

2. **Git branch override** — shared across machines/CI.
   - `pubspec.yaml`:

         dependency_overrides:
           pkg:
             git:
               url: https://github.com/<org>/<producer>.git
               ref: feat/<project>/<task-id>

   - `package.json` `"resolutions"`: `github:<org>/<producer>#<branch>`.
   - Codegen spec files (e.g. OpenAPI manifests, proto registries): pin to
     the same branch on the producer spec source.
   - Good for: running CI end-to-end before the producer is released.
   - Must be **removed** before review.

3. **Pinned commit SHA** — only for debugging a moving target.
   - Use when a branch tip rebases often and you need reproducibility for
     one run. Convert back to branch ref as soon as the tip stabilises.

4. **Released version / tag** — the end state.
   - `pubspec.yaml`: `pkg: ^1.2.3`.
   - Codegen spec files: reference the producer's **release tag**.
   - This is the only acceptable state for the final review diff.

Organisation-specific rules on which ref counts as "release-quality"
(e.g. must be a release tag rather than a raw SHA) belong in the work
overlay (`~/.agents/AGENTS.work.md`).

## Order of operations

Producer merges first **or** producer and consumer go green together with
a branch override, then the override is bumped to the release in a final
commit on the consumer PR. Coordinate the switch:

    # on the consumer:
    1. confirm producer PR is approved / merged
    2. publish / tag the producer as needed
    3. bump the override to the release in one commit titled
       "Pin <pkg> to <version>"
    4. push; verify CI; request review

## Red flags during review

- `dependency_overrides` present in a PR marked "ready for review"
- `ref:` pointing at a feature branch name
- Codegen spec files with a raw 40-char commit hash
- `pubspec.lock` / `package-lock.json` / `yarn.lock` diffs that don't match
  the manifest delta

Each of these indicates the ladder wasn't climbed.
