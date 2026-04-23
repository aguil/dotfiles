# Branch, commit, and PR conventions

## Branch / bookmark name

    <type>/<project>/<task-id>

Examples:

    feat/my-project/user-applied-filter-awareness
    feat/my-project/data-list-additions

Use this **identically in every repo in the task**. It's what makes tooling
like `gh pr list --head <branch>` and `just push <type> <task-id>` just
work.

## PR title

    <Sentence-case summary, present tense>

If the project uses an issue tracker, append the ticket ID in parentheses:

    <Sentence-case summary, present tense>  (<TRACKER>-NNNN)

- The space before the paren matters for some automation; keep it.
- One tracker ID per PR. If the work spans multiple tickets, pick the
  primary one and link the others in the body.
- The **exact tracker format** is project- or organisation-specific; the
  work overlay (`~/.agents/AGENTS.work.md`) encodes the format and when it
  is mandatory.

Fix after the fact:

    gh pr edit <n> -R <org>/<repo> --title "New title  (<TRACKER>-NNNN)"

## PR description

Minimum contents:

1. One-paragraph summary of what changes in **this** repo.
2. Link to the ADR (path + permalink) if one exists.
3. Cross-links to sibling PRs in the task (one bullet per repo).
4. Testing notes (what was run locally, what CI covers).

## Commits

- **Isolated, one logical change per commit.** If the diff contains a
  refactor and a behaviour change, they are two commits.
- Fixups from code review go in as **new commits**, not as amendments to
  shipped commits — unless the project explicitly squashes on merge and
  the reviewer prefers amendments.
- Commit messages: imperative mood; tracker ID in the trailer or subject
  if helpful, but the PR title is the canonical place.

## Splitting a commit after the fact (jj)

    jj split -r <change> --tool builtin:diffedit  # avoid for agents
    # non-interactive: re-describe parts individually
    jj split -r <change> path/to/file-a path/to/file-b
    # or stage-by-hand:
    jj new <change>-  # branch off its parent
    # cherry-pick pieces, then rebase the original children onto the new tip
    jj rebase -s <change> -d @
