---
name: jj-commit-hygiene
description: >-
  Patterns for keeping commits atomic during iterative development: the
  always-empty-@ workflow that eliminates working-copy drift, bookmark
  management with `jj bookmark advance`, and how to split mixed changes after
  the fact using `squash --from/--into`. Use whenever @ already has a described
  commit and new work is about to begin, or when a single commit needs to be
  divided into logical units.
---

# jj commit hygiene

Read `~/.agents/skills/jujutsu/SKILL.md` first. This adds the iterative-
workflow patterns that aren't in the base skill.

## The working-copy drift problem

The most common source of wasted commit-hygiene work: an agent makes change A,
describes @ and pushes a PR, then receives operator feedback requiring change B.
Instead of creating a new commit, the agent keeps editing @ — now @ contains
both A and B, and splitting them out costs more time than doing it right the
first time.

## Recommended workflow: always-empty-@

Keep `@` permanently empty by running `jj new` after every unit of work. `@-` is
then always the last real commit; `@` is always a clean landing zone for the
next change.

```bash
# Start a unit of work
jj desc -m "feat: X"     # describe the empty @ before touching any file

# ... make changes ...

# Finish the unit
jj new                   # @ becomes empty; @- holds the real commit
```

### Why this eliminates drift

- New work always starts with an empty, undescribed `@` — there is nothing to
  accidentally accumulate.
- Feedback that belongs in a separate commit never gets mixed in by default,
  because each unit of work explicitly begins with a fresh `jj desc`.

### Preflight: `jj st` before every edit

Run `jj st` before touching any file. With the always-empty-@ workflow, the
purpose shifts: you're no longer checking _whether_ to run `jj new` (@ should
already be empty), but validating that the state matches expectations — nothing
surprising in `@`, and `@-` is the commit you think it is.

```
Working copy changes:       ← should be empty
Working copy  (@) : ...     ← should have no description (or the one you just set)
Parent commit (@-): ...     ← should be the last real commit
```

If `@` has unexpected content or `@-` is wrong, stop and investigate before
making changes. `jj undo` can recover from most surprises.

### Feedback classification

When operator feedback arrives, decide before touching any file:

| Feedback type                               | Action                                   |
| ------------------------------------------- | ---------------------------------------- |
| New work, separate logical unit             | `jj desc -m "..."` on the empty @        |
| Refinement of the **same** logical unit     | `jj edit @-`, fix, `jj edit @` to return |
| Belongs in an **ancestor** commit           | `jj edit <ancestor>`, fix, `jj edit @`   |
| Line-level fix clearly owned by an ancestor | Edit, then `jj absorb`                   |

### Bookmark management in the always-empty-@ workflow

Because `@` is empty, the task bookmark should track `@-` — the last real
commit. Use `jj bookmark advance`:

```bash
# After jj new, advance the task bookmark to the latest real commit:
jj bookmark advance --to @-

# Then push:
jj git push -b <bookmark-name>
```

`jj bookmark advance` finds the closest ancestor bookmark(s) automatically and
moves them forward. It is fast-forward only — it refuses to move a bookmark
backwards, making it safe to run without naming the bookmark explicitly.

**When `advance` cannot be used:**

| Situation                                                           | Command                                            |
| ------------------------------------------------------------------- | -------------------------------------------------- |
| First push — no ancestor bookmark exists                            | `jj bookmark create <name> -r @-`                  |
| After a rebase — new commit is not a descendant of the old bookmark | `jj bookmark set <name> --to @- --allow-backwards` |

After a rebase, the commit IDs change even though the content is the same
logical continuation. `advance` sees no forward path and refuses;
`set --allow-backwards` handles the rebase case explicitly.

---

## Retroactive: splitting a mixed commit

When @ already contains N logical changes, split it using
`squash --from/--into`:

### Step 1 — create an empty commit A before @

    jj new @- -m "feat: first logical unit"

⚠️ **`jj new @-` creates a sibling, not an insertion.** The old @ is NOT
automatically rebased onto the new commit. After this command the graph is:

    @-  ──► A  (new @ — empty)
     └───► old@  (sibling, still has all changes)

You must linearize manually:

    jj rebase -r old@ -d A

Now the graph is: `@- → A (empty) → old@ (all changes)`.

Alternatively, use a change ID instead of `@-` to be explicit:

    jj new <parent-change-id> -m "feat: first logical unit"
    jj rebase -r <old-change-id> -d <A-change-id>

### Step 2 — move files into A

    jj squash --from <old@> --into A -- path/to/file1 path/to/file2

`jj squash --from X --into Y -- <files>` moves exactly those file-level diffs
from X into Y. X must be a descendant of Y (which it is after the rebase).

### Step 3 — insert more commits if needed

Repeat for each additional logical unit:

    jj new A -m "feat: second logical unit"   # B, sibling of old@
    jj rebase -r <old@> -d B
    jj squash --from <old@> --into B -- path/to/file3 path/to/file4

### Step 4 — rename the final commit

old@ now contains only the remaining files. Update its description:

    jj desc -r <old@> -m "feat: third logical unit"
    jj edit <old@>

### Full example (3-way split)

    # @ = qmpxnwnv with 9 mixed files, parent = vqurzpmr

    # Insert A:
    jj new vqurzpmr -m "feat: rename action label"
    jj rebase -r qmpxnwnv -d twwpwyrq          # twwpwyrq = A's change ID

    # Move 2 files into A:
    jj squash --from qmpxnwnv --into twwpwyrq \
      lib/src/intl/w_sox_intl.dart \
      lib/src/export_list/modules/exports_list/ui/exports_list.dart

    # Insert B:
    jj new twwpwyrq -m "feat: wire API middleware"
    jj rebase -r qmpxnwnv -d wmpppmsv           # wmpppmsv = B's change ID

    # Move 4 files into B:
    jj squash --from qmpxnwnv --into wmpppmsv \
      lib/src/export_list/export_list_experience.dart \
      lib/src/export_list/modules/export_details/export_details_module.dart \
      lib/src/export_list/modules/export_details/redux/export_details_actions.dart \
      lib/src/export_list/modules/export_details/redux/export_details_middlewares.dart

    # Rename C (qmpxnwnv now has 3 remaining files):
    jj desc -r qmpxnwnv -m "feat: render download buttons in panel"
    jj edit qmpxnwnv

    # Repair the bookmark after splitting:
    jj bookmark set sox-export-download --to qmpxnwnv --allow-backwards
    jj git push -b sox-export-download

---

## Bookmarks: `advance` vs `set` vs `create`

In `jj log`, `bookmark@` (trailing `@`) is a **remote tracking pointer** — it is
read-only and only moves on push. `bookmark` (no `@`) is the local pointer you
control.

| Command                                            | When to use                                                                               |
| -------------------------------------------------- | ----------------------------------------------------------------------------------------- |
| `jj bookmark advance --to @-`                      | Normal push after always-empty-@ workflow; moves the closest ancestor bookmark(s) forward |
| `jj bookmark create <name> -r @-`                  | First push for a task; no ancestor bookmark exists yet                                    |
| `jj bookmark set <name> --to @- --allow-backwards` | After a rebase; commit IDs changed so `advance` would refuse                              |

`advance` without `--to` defaults to `@`, which points at the empty working copy
commit in this workflow. Always pass `--to @-` explicitly.

---

## Splitting without post-hoc work: `jj split -r`

If the commit has not been heavily interleaved, path-based splitting is cleaner:

    jj split -r <change-id> path/to/file1 path/to/file2

This creates two commits: the first containing only the listed files, the second
containing everything else. Children rebase automatically.

Note: `jj split -i` is interactive and will hang in agent environments.

---

## Quick decision guide

```
About to make a change:
├─ @ is empty (always-empty-@ workflow) → jj desc -m "..." and start
├─ @ has content for a different logical unit → jj new, then jj desc
└─ Change belongs in an ancestor → jj edit <ancestor> or jj absorb

Ready to push:
├─ Normal case (fast-forward) → jj bookmark advance --to @-
├─ First push (no bookmark yet) → jj bookmark create <name> -r @-
└─ After rebase → jj bookmark set <name> --to @- --allow-backwards

@ has mixed content that needs splitting:
├─ Files cleanly separated → jj split -r @ <files>
└─ Complex mix → jj new @- + jj rebase + jj squash --from/--into
```
