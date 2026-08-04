# Resume here — state as of 2026-08-04

## Where things stand

All 16 tasks of `docs/plans/2026-08-03-agent-pipeline-implementation.md` are
implemented, and the whole-branch review's fix wave has now been applied. The
package is complete in structure:

- `core/` — 6 contracts, 3 trackers, 5 phases, 6 flows, harness-neutral
- `adapters/claude-code/` and `adapters/cursor/` — thin pointers into `core/`
- `install.sh`, five checkers, a 27-case suite
- `README.md` and `docs/validation-2026-08-03.md`

Branch: `implement-pipeline`, 45 commits from `main`. Suite 27/27, all four
gates pass. **Nothing has been published; there is no git remote.**

## What was closed, and how it was verified

The seven blockers and the fix-soon list are done, across two commits.

`ea8ebe7` (previously flagged UNREVIEWED) has now been reviewed. It touched
only `core/` and `adapters/`, and it closed BP1, BP2, BP5, BP6 and most of the
fix-soon list. The work holds up: each fix landed in every file that had to
agree, not just one.

`edc253e` closed what `ea8ebe7` had not touched at all — `README.md`,
`install.sh`, the checkers, and the validation record: BP3, BP4, BP7, the
installer's false "no changes were made", the checkers' ordinary-English false
positives and fixed `/tmp` paths, and the two undocumented constraints (branch
name must equal the task ID; three of five agents pinned to the larger model).

Verified by execution:

- **BP1** — an uncommitted file is invisible in a worktree created from the
  base branch; a committed one is visible. `git ls-files --error-unmatch`
  distinguishes the two, so doctor's new row works.
- **BP2** — the old rule counted 7 on a conventions file holding no rules at
  all; the new one counts 0.
- **BP5** — `git rev-parse --path-format=absolute --git-common-dir` yields the
  same absolute root from the project and from inside a worktree.
- **install.sh** — a refused install now leaves no directories behind.

Verified by reading only, there being no executable to run: **BP6**. Walking
the problematic log (`review`, `test`, `code-review`, `execute`) through the
new single procedure yields `code-review`, which is correct, and the two old
rules did diverge on it.

### One defect found in `ea8ebe7`, and fixed

Its BP2 fix defined a rule line as "a list item **ending in** a `file:line`
citation" in two files while `doctor.md` said "**carrying**" one. Rules wrap,
and the template's own worked example puts its citation on a continuation
line, so "ending in" undercounts: measured against fixtures, two real rules
count as one. A project with five legitimate rules would have failed doctor.
All three files now say "carrying", and count list items rather than physical
lines.

## What is left

1. **Live-dispatch validation on Claude Code.** This is the real gap, and
   `docs/validation-2026-08-03.md` now states it plainly: the current agent
   layout's only evidence is `claude plugin details` reporting `Agents (5)`,
   which is an install-time snapshot. The layout it replaced had been tested by
   actually dispatching a phase. Close that asymmetry by running one — not by
   arguing about it.
2. **Validation on Cursor.** Never run end to end. `install.sh` is tested by a
   fixture case, but no phase has ever executed under that harness, so BP5's
   root resolution is verified as a shell command and not as a working install.
3. **Re-review the fix wave** (`edc253e`).
4. **Publish** to `dfrnks/agent-pipeline` — there is still no remote.

Acceptance criterion 3 of the design (a `task` reaching `SHIPPED` with an open
pull request) remains **not met**, honestly: validation ran locally with no
remote. That stays recorded as-is.

## What the review found genuinely good — preserve under later change

- **The test-protection contract and its tie-breaker** (`execute.md:144-161`,
  `code-review.md:124-133`). Validation planted four weakenings, produced a
  green suite and clean lint, and a fresh-context reviewer caught all four,
  named the files, and surfaced an unplanted finding. This is the thesis of the
  package and it is empirically demonstrated.
- **The discoveries-span design** (`conventions-template.md`) — placing an
  append-only writer's output outside a span another flow rewrites wholesale,
  making the guarantee structural rather than disciplinary.
- **`pipeline.md` Steps 1 and 2** — a portable worktree check that is a real
  conditional, and a review gate whose rationale explains why it looks
  redundant on the happy path.
- **Configuration discipline** — 17 keys, zero spelling variants across three
  directories and the README, every shared number reconciled.
- **The checker suite** — negative fixtures on both sides of every gate.

## Decisions already made, do not relitigate

- The pipeline directory in a consuming project is `.agent-pipeline/`, not a
  harness-named one, so neutrality is real rather than asserted.
- `core/` shows the shape; the README shows a realistic instance.
- The spec may name real harness files; `core/` may not — different audiences.
- Validation runs locally with no remote. The pull-request criterion is
  recorded as **not met**, honestly, and stays that way.
- Both harnesses stay first-class. The scope was reconsidered on 2026-08-04
  and deliberately kept: finish as built, no new complexity, weight on docs.
- Publication happens only after live-dispatch validation passes on both
  harnesses.

## Notes

`.import/` is gitignored and holds the porting source. If it is missing,
restage it — and keep the two source directories' files distinctly named,
because a filename collision there silently destroyed the source for four
tasks earlier in this project.

The session ledger this file used to point at
(`.superpowers/sdd/2026-08-03-agent-pipeline-implementation/progress.md`) is
**gone** — it lived outside version control and is not in this worktree. The
per-task rulings and deferred findings it held cannot be recovered. This file
and the git history are what remain.
