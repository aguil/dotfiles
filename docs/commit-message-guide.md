# Commit Message Guide

Use this guide for all commits in this repository.

## Format

Use Conventional Commits:

`<type>(optional-scope): <imperative summary>`

Examples:

- `feat(windows): add config export workflow and initial backups`
- `fix(verify): handle missing checksum argument`
- `docs(readme): clarify Windows backup steps`

## Types

- `feat`: new user-visible capability
- `fix`: bug fix
- `docs`: documentation-only change
- `refactor`: code restructure without behavior change
- `chore`: maintenance work (non-feature/non-fix)
- `test`: add or update tests
- `build`: build/dependency/tooling changes
- `ci`: CI pipeline/workflow changes
- `revert`: revert a previous commit

## Subject line rules

- Keep it concise (target <= 50 chars when practical)
- Use imperative mood (`add`, `update`, `remove`, `fix`)
- Capitalize only where natural (acronyms/proper nouns)
- Do not end with a period
- Focus on intent, not file-by-file mechanics

## Body (when needed)

Add a body for non-trivial changes. Explain:

- Why the change was made
- Any important tradeoffs or constraints
- Follow-up notes for future readers

Wrap body lines around ~72 chars for readability.

## Scope guidance

Use a scope when it improves clarity:

- `windows`, `keyboard`, `backup`, `readme`, `home`, `verify`

Skip scope if it adds noise.

## Good vs bad

Good:

- `feat(backup): export winget package snapshot`
- `docs(windows): add backup workflow and usage`
- `fix(keyboard): make apply script idempotent`

Bad:

- `tweaked stuff`
- `updates`
- `fixed things`

## Pre-commit checklist

- Message matches the actual change
- No secrets included
- Diff is focused and reviewable
- Subject is clear without opening the diff
