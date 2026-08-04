# Resume here — state as of 2026-08-04

## Where things stand

All 16 tasks of `docs/plans/2026-08-03-agent-pipeline-implementation.md` are
implemented, and the whole-branch review's fix wave has now been applied. The
package is complete in structure:

- `core/` — 6 contracts, 3 trackers, 5 phases, 6 flows, harness-neutral
- `adapters/claude-code/` and `adapters/cursor/` — thin pointers into `core/`
- `install.sh`, five checkers, a 27-case suite
- `README.md` and `docs/validation-2026-08-03.md`

Everything lives on `main`, in a single working directory — the earlier
two-folder split was a git worktree and has been consolidated. Suite 27/27, all
four gates pass. **Nothing has been published; there is no git remote.**

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

**BP6** was first checked by reading — walking the problematic log (`review`,
`test`, `code-review`, `execute`) through the new single procedure yields
`code-review`, which is correct, where the two old rules diverged. It has since
been confirmed under execution as well: `resume` inferred `test` from a log
holding only a `review` entry and ran that one phase without chaining, and the
end phase left its own handoff entry in the full run.

### One defect found in `ea8ebe7`, and fixed

Its BP2 fix defined a rule line as "a list item **ending in** a `file:line`
citation" in two files while `doctor.md` said "**carrying**" one. Rules wrap,
and the template's own worked example puts its citation on a continuation
line, so "ending in" undercounts: measured against fixtures, two real rules
count as one. A project with five legitimate rules would have failed doctor.
All three files now say "carrying", and count list items rather than physical
lines.

## Live dispatch — closed on both harnesses

Both harnesses now load the adapter and dispatch a phase for real. Recorded in
full in `docs/validation-2026-08-03.md`'s 2026-08-04 addendum.

- **Claude Code** — clean marketplace add plus install, `Skills (6)` and
  `Agents (5)`, and `task-test` dispatched in an empty repository returned its
  resolved phase path and that file's first heading.
- **Cursor** — `install.sh` into a throwaway project; a live `cursor-agent`
  session listed all six commands and five agents and dispatched `task-test`,
  which resolved and read its phase file. This also closed items 1 and 2 of the
  carried-forward Cursor list.
- **BP5 in its real scenario** — with `.cursor/` git-ignored, a worktree has no
  `.cursor/` of its own, and the `git-common-dir` resolution still reached the
  project root's copy.

That dispatch also **disproved a README claim**: with a local-path marketplace,
`${CLAUDE_PLUGIN_ROOT}` resolves to the working clone, not the plugin cache, so
a `git pull` takes effect with no reinstall. Both install modes are now
documented.

## The pipeline works end to end

A full run was completed and independently verified on 2026-08-04 — see the
second addendum in `docs/validation-2026-08-03.md`. A throwaway Python project
was bootstrapped (`doctor`: 8 pass, 0 fail, 1 n/a) and taken through a real
task: six commits, tests that genuinely failed before the implementation
(**5 failed, 7 passed** at the red commit, re-checked by hand), 12 passing
after, clean lint, all four handoff entries, and a code-review verdict of
`APPROVED_WITH_WARNINGS` with five substantive warnings.

BP1, BP2 and BP6 were each confirmed under execution rather than by reading,
and the spec gate caught three real blockers before any code existed.

**It also runs unattended.** The first run needed nudging between phases; that
was traced to `pipeline.md` Step 4 never requiring the sequence to be carried
through in one pass, fixed, and re-verified — a single call with no
intervention now reaches `SHIPPED` through all four phases.

**`git.worktree_setup` runs too.** Testing it exposed a defect spanning four
files — the executable bit was never set, never checked, and `pipeline.md`
never said how to invoke the script, so it worked or not depending on a choice
the text left open. Fixed and re-verified: doctor fails a non-executable
script by name, and a second full task created its worktree, ran the script in
it, and shipped unattended.

## What is left

1. **A repository-sourced install.** The Claude Code marketplace was added from
   a local path, because nothing is published. The cache path has never been
   the resolved root in a live dispatch.
2. **A full run on Cursor.** Cursor is verified as far as loading and
   dispatching; no task has been run through it.
3. **Re-review the fix wave** (`edc253e`, `3e59a66`, `8641ac0`, `101af6e`,
   `deb6be8`).
4. **Publish** to `dfrnks/agent-pipeline` — there is still no remote.

The design's pull-request criterion remains **not met**: validation ran locally
with no remote, so push and pull request were correctly skipped rather than
exercised.

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

The session ledger is **present**, at
`.superpowers/sdd/2026-08-03-agent-pipeline-implementation/` — `progress.md`
(117 lines), a per-task brief and report for each of the 16 tasks, and the
review diffs. It is gitignored, so it travels with the working directory and
not with the branch: keep it when moving or consolidating checkouts.

Read `task-14-report.md:274-298` before touching the Claude Code agent layout.
It records `claude plugin details` reporting `Agents (0)` while a live session
listed all five agents and a dispatched one resolved its pointer — which is
what `docs/validation-2026-08-03.md`'s D1 section originally read as proof the
agents were not loading.
