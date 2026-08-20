# Flow: fix-bug

Fix a defect test-first: reproduce it with a test that fails, find the cause,
make the smallest change that fixes it, and verify nothing else broke.

This flow exists because the pipeline starts from a spec and a bug starts
from a symptom. `task` resolves an item, writes a design, reviews it, and
runs four phases — sound for work whose shape has to be decided, and
disproportionate for "this endpoint returns 500 when the list is empty."
There the design is one line long and what the work needs is a reproduction.

The discipline is the pipeline's, compressed: the failing test comes first
and is what proves the fix works.

## Input

The argument is whatever the person has: a description of the symptom, an
error message or stack trace, or a tracker item's ID. Any additional context
— steps to reproduce, the file they suspect, what they expected — is input.

If no argument is given, ask for the symptom, including any error output and
the steps that produce it. Do not explore on a guess: a flow that searches
for the wrong defect finds something, and it is a different bug nobody asked
about.

When the argument is a tracker ID, read the item through
`core/trackers/<tracker.type>.md` and use its report as the symptom.
Otherwise this flow consults no tracker and creates no item.

## Mindset

You are debugging, not implementing. The order is not negotiable, because
each step is what makes the next meaningful:

1. **Understand the symptom** before reading code — a search aimed by a guess
   confirms the guess.
2. **Reproduce it in a test** before touching anything — a fix for a bug you
   cannot reproduce is a change whose effect nobody can demonstrate.
3. **Find the cause**, not the place where the symptom appears. Those are
   frequently different files, and the difference is the whole job.
4. **Verify** the fix without breaking anything adjacent.

The most common failure is fixing where the error surfaced rather than where
it originated: the symptom disappears, the cause remains, and it resurfaces
wearing a different stack trace.

## Step 0 — Load configuration

Read `.tdd-pipeline/config.yaml`. Follow the fail-fast protocol in
`core/contracts/pipeline-config.md`: stop and name the exact missing key if
the file or a key this flow needs is absent. This flow needs `commands.test`,
`commands.test_all`, `commands.lint`, `paths.tests`, `paths.worktrees`,
`paths.conventions`, `git.base_branch`, `git.commit_trailer`, and, when
present, `git.worktree_setup`.

## Step 1 — Gather the report

Establish, before reading any source: what was observed, what was expected
instead, and what sequence produces it. Read any error output, stack trace,
or log in full rather than skimming for a filename — the frame that names the
failing file is rarely the frame that explains it.

If the report is ambiguous in a way that would send the search in two
different directions, ask once, concretely. If it is ambiguous only in
details that do not change where to look, proceed and note the assumption in
Step 8.

## Step 2 — Create the worktree

This flow edits files, so it does not run in the main checkout. Create the
worktree before Step 3 reads anything, so no path reaches an edit while the
main repository is still the working directory.

Choose the branch name from the input:

- A tracker ID — use it verbatim, so the branch matches the item.
- Anything else — propose a short descriptive name marked as a fix
  (`fix-empty-list-500`) and use it unless the person objects.

Bring the base branch up to date first, exactly as `core/flows/task.md`
Step 5 does:

```bash
REMOTE=$(git remote | head -n 1)
```

With a remote, fetch and then decide which ref to branch from:

```bash
git fetch "$REMOTE" "<git.base_branch>"
git rev-list --left-right --count "$REMOTE/<git.base_branch>...<git.base_branch>"
```

Branch from the remote-tracking ref only when the second count is zero:

```bash
git worktree add "<paths.worktrees>/<branch>" -b "<branch>" "$REMOTE/<git.base_branch>"
```

With no remote, with a local base branch ahead or diverged, or after a failed
fetch, branch from the local base branch and say which case applied in
Step 8:

```bash
git worktree add "<paths.worktrees>/<branch>" -b "<branch>" "<git.base_branch>"
```

A local base branch ahead of the remote is not an edge case: a project whose
pipeline configuration is committed but not pushed has
`.tdd-pipeline/config.yaml` on the local branch only, so a worktree cut from
the remote lacks it and every step below fails on a project `doctor` calls
ready.

If a worktree already exists at that path, reuse it. If it holds uncommitted
work this flow did not just create, stop and ask before touching anything.

Then, if `git.worktree_setup` is configured, run it from the worktree root,
directly, by its own path:

```bash
./<git.worktree_setup>
```

The script carries its own shebang and executable bit, guaranteed by `init`
and checked by `doctor`; naming an interpreter would work by accident for one
language and pick the wrong one for another. Stop on a non-zero exit — every
step below runs the project's own commands and cannot diagnose an environment
that was never built.

**Every step from here operates inside the worktree.**

## Step 3 — Locate the fault

Dispatch subagents in parallel:

- **Where the defect lives** — the files on the path the symptom traverses,
  read in full rather than sampled, with the data flow through them traced.
  Include what recent history says: a defect in code that changed last week
  is usually in the change.
- **The test surface** — the tests already covering this area, the fixtures
  and helpers they use, and where a test reproducing this symptom belongs.
  Reproducing a bug in a style the suite does not otherwise use produces a
  test the next reader distrusts.

Read `paths.conventions` too. The fix has to satisfy the same rules as
everything else here, and it is where execute and code-review would look if
this bug went through the pipeline instead.

## Step 4 — Name the root cause

State the cause in one or two sentences, naming the file and line where it
originates, before proposing any change. If more than one cause fits what
Step 3 found, list them ranked and say what would distinguish them.

If the evidence does not support naming a cause, stop and report that, with
what was ruled out and what would be needed to continue. A guessed cause
produces a fix that changes behavior without explaining it, and the test
written next passes for a reason nobody established.

## Step 5 — Reproduce with a failing test

Write a test that fails **because of this defect**, in the location and style
Step 3 identified, asserting the behavior that is correct — not the behavior
observed today.

Run it with `commands.test` and confirm it fails for the reason it asserts,
not from a typo, an import error, or a broken fixture. A test that fails for
an unrelated reason still turns green when the bug is fixed, and proves
nothing.

**If the test cannot be made to fail, stop.** The bug is not reproduced and
everything after would be unverifiable. Report what was tried, what the test
does instead, and what reproduction would need — a specific environment, a
data state, a timing window. Do not proceed on the theory that the fix is
obvious: without a failing test, nothing distinguishes a fix from a change.

Commit the failing test on its own:

```bash
git add <test file>
git commit -m "<branch>: add failing test reproducing <symptom>"
```

Append `git.commit_trailer` when non-empty; omit it entirely when empty. The
red commit is separate on purpose: it lets any later reader run the suite at
that commit and watch the bug happen, which is the only durable proof the fix
addressed a real defect.

## Step 6 — Fix

Make the smallest change that addresses the cause named in Step 4.

Do not refactor surrounding code, rename anything, or improve what you pass
through. Those may all be worth doing, and each enlarges a diff whose entire
value is that a reviewer can see the fix without looking for it. Note them in
Step 8 instead.

Do not weaken or edit any existing test to accommodate the change. If an
existing test now fails, that is a finding: either the fix is wrong, or that
test encoded the defect. Say which in Step 8, and never resolve it by editing
the test quietly.

Follow `paths.conventions`.

## Step 7 — Verify

In order:

1. The test from Step 5 now passes.
2. `commands.test_all` passes — the fix broke nothing adjacent. A fix that
   turns one test green and another red has moved the defect.
3. `commands.lint` is clean.

If a verification fails, diagnose and fix before continuing. Do not report a
partial result as success: the verification is the only evidence this flow
produces.

Then commit the fix:

```bash
git add <changed files>
git commit -m "<branch>: fix <symptom>"
```

Append `git.commit_trailer` when non-empty, omit when empty. Stage only what
this flow changed — never `git add .`.

## Step 8 — Report

Return, in order:

- **Root cause** — the one or two sentences from Step 4, with `file:line`.
- **Fix** — what changed, and why that addresses the cause rather than the
  symptom.
- **Test** — the test that reproduces the defect, and what it asserts.
- **Verification** — the three results from Step 7, stated as results rather
  than claims.
- **Branch and worktree path**, so the person can inspect the diff.
- Anything deliberately left undone — a refactor noticed and skipped, an
  adjacent defect found, an assumption made in Step 1 — and, when Step 2's
  fetch did not happen, that the base branch was not refreshed.

**This flow does not push and does not open a pull request.** That is a
decision, not an omission: the work has had no independent review. The
pipeline earns its push through a code-review phase reading the diff in a
fresh context and returning a verdict, and nothing here does that job.

Name what to do next instead: inspect the diff in the worktree, and push it
from there when satisfied. If the fix turns out to be larger than one defect,
or wants the full gate, say so — the work belongs in a spec, and `task` runs
it end to end from there.
