# Commit messages

Applied with your dotfiles (`~/.agents/rules/`). Full detail lives in the **chezmoi
source** at `docs/commit-message-guide.md` when you have that repo checked out.

## Subject (always)

- Use **Conventional Commits**: `type(optional-scope): imperative summary` (no
  trailing period; keep the line short when practical).
- Types: `feat`, `fix`, `docs`, `refactor`, `chore`, `test`, `build`, `ci`,
  `revert` — see the full guide for definitions.

## Body — agents and scripted commits

**Always** add a short body (about 2–6 lines, wrap near ~72 columns) when the
commit is produced by an **agent**, **script**, or other **automated** workflow.

The body should make the next reader’s job easy: what changed, and **why** it
was done if that is not obvious from the subject. Mention tradeoffs, follow-ups,
or how to verify when that helps.

**Exception — subject only:** only skip the body when the **user** explicitly
says the change is **trivial-only** _and_ it matches the trivial checklist in
`docs/commit-message-guide.md` (e.g. obvious typo, one-word doc fix). When in
doubt, include a body.

## Humans driving `git` / `jj` directly

Same subject rules. Add a body for anything **non-trivial** (behavior change,
refactor, multi-file intent, review context). Subject-only is fine for small,
self-explanatory edits — see the full guide.
