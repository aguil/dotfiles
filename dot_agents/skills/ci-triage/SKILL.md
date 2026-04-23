---
name: ci-triage
description: >-
  Structured approach to triaging a failing GitHub Actions check on a PR:
  find the run, extract the real error from logs, reproduce locally, fix in
  an isolated commit, push, and poll. Use whenever CI is red on any PR in
  the current task.
---

# CI triage loop

Goal: turn a red check green with the smallest, most reviewable commit
possible. Don't fan out fixes across multiple commits — one failure, one
focused commit.

## 1. Locate the run

GitHub Actions:

    gh pr checks <pr> -R <org>/<repo>
    gh run list -R <org>/<repo> --branch <type>/<project>/<task> --limit 5
    gh run view <run-id> -R <org>/<repo> --log-failed

If the project ships additional test-runner integrations (e.g. a dedicated
test-results system reached via an MCP server or CLI), use those for richer
log access. Any such work-specific integration is documented in
`~/.agents/AGENTS.work.md` and its companion skills.

## 2. Find the real error

Logs from CI wrap real errors in noise (setup, cache restore, etc.). Skip
past:

- Setup / checkout / cache steps — they almost never fail usefully; if they
  do, it's infra, not your code.
- "0 tests ran" lines — symptom, not cause; keep scrolling.

Grep for, in order:

    FAIL|FAILED|ERROR|Exception|panic:
    # then narrow to the *first* occurrence

First error is usually the real one; subsequent failures cascade from it.

## 3. Reproduce locally

Never fix a CI-only error blind. Get it to happen on your machine first.

- Dart: `dart test path/to/failing_test.dart --reporter expanded`
- Flutter: `flutter test path/to/failing_test.dart`
- Java: `mvn -pl <module> test -Dtest=<TestClass>#<method>`
- Go: `go test ./pkg/... -run '^TestThing$' -v`
- Node: `npm test -- --testPathPattern=…`

If it only repros in CI, the delta is the environment: network access,
generated code freshness, or OS differences.

## 4. Fix in an isolated commit

One logical change, clear message:

    Fix flaky ordering in FilterService tests

If the project's PR policy requires a tracker ID suffix on titles, see
`cross-repo-change/BRANCHING.md` for the format.

If the fix changes production code *and* regenerated clients, those are
two commits (see `dart-cross-repo` on generated code hygiene).

## 5. Push and poll

    # from the project directory, for every repo in task.json:
    just push <type> <task-id>
    # or for a single repo:
    just push <type> <task-id> <repo-basename>

Watch:

    gh pr checks <pr> -R <org>/<repo> --watch

Until the check flips green or produces a new, different failure.

## 6. When it's not your bug

- **Flaky test**: rerun once (`gh run rerun <run-id>`). If it flakes again,
  file a ticket and, if policy allows, mark the test as a known flake.
  Don't paper over with retries in production code.
- **Infra outage**: check the org status dashboard / #ci channel before
  burning time.
- **Dependency not yet released**: you climbed the override ladder too
  early. See `cross-repo-change/DEPENDENCY-OVERRIDES.md`.

## Anti-patterns

- Force-pushing "fix ci" commits that don't actually change anything.
- Amending the same commit after each failed attempt so history is a lie
  about the debugging process. Leave the trail; squash at merge time if
  the project's policy does that.
- Disabling a test as "the fix". Only acceptable with a linked bug ticket
  and a comment explaining the plan.
