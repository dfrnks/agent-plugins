# Phase: pipeline

Orchestrate the four leaf phases — test, execute, code-review, end — against
one task, in order, inside the worktree the task flow already created. This
phase writes no test, no implementation code, and adjudicates nothing itself;
it dispatches the phases that do, reads what each one reports, and decides
whether the next phase runs at all.

The argument to this phase is a task ID (for example `TASK-1`). If none is
given, derive it from the current branch name.

## Step 0 — Load configuration

Read `.agent-pipeline/config.yaml`. Follow the fail-fast protocol in
`core/contracts/pipeline-config.md`: stop and name the exact missing key if
the file or a key this phase needs is absent. This phase needs
`paths.worktrees`, `paths.specs`, and, when present, `git.worktree_setup`.

## Step 1 — Verify the working directory

This phase must never run against the main repository — only inside a
worktree the task flow created for this task. The portable check compares
the repository top level against the parent of the common git directory:
in a plain checkout of the main repository the two are equal; in a worktree
they diverge, because the worktree's own top level sits apart from the
common `.git` directory shared with the main checkout.

```bash
TOP=$(git rev-parse --show-toplevel)
COMMON=$(git rev-parse --path-format=absolute --git-common-dir)
if [ "$TOP" = "$(dirname "$COMMON")" ]; then
  echo "Refusing to run: this is the main repository, not a task worktree."
  exit 1
fi
```

If this check fails, stop immediately without editing anything and report
that the task flow must create the worktree first — this phase does not
create one for itself and does not fall back to running in place.

Then confirm the current branch is the task ID this phase is running
against, with the same discipline as the check above — a real conditional
that stops the phase, not a comment an executing agent has to notice and
act on by itself:

```bash
BRANCH=$(git branch --show-current)
if [ "$BRANCH" != "<task-id>" ]; then
  echo "Refusing to run: current branch '$BRANCH' does not match task '<task-id>'."
  exit 1
fi
```

A mismatch is the same failure by another name — the worktree exists but is
not on the branch this task expects — and stops this phase the same way,
without editing anything.

## Step 2 — Verify the spec was reviewed

Read `paths.specs/<task-id>.md` before dispatching any phase. Confirm its
`## Agent Handoff Log` (per `core/contracts/handoff-log.md`) contains an
entry whose heading begins with `review` — matched tolerantly: case
insensitive, and allowing a date suffix or a qualifier to follow the name,
so `### review (YYYY-MM-DD)`, `### Review-plan`, and `### review
(post-implementation)` all count as a match, and only an entry with no
resemblance to the name at all fails it.

If no such entry exists, stop here and return `BLOCKED`, naming what to run
to fix it: run the review flow against this task's spec, then re-invoke this
phase. Do not fall back to running the phase sequence anyway, and do not
offer a way to skip this check — a guard a caller can bypass is a
suggestion, not a guard.

This check exists for exactly the paths that reach this phase without
passing through the `task` flow's own review gate first: a direct dispatch
of this phase, a resume after an interruption, or an invocation against a
worktree and spec that already exist. The happy path through `task` already
enforces review before this phase is ever reached, which is why this looks
redundant there — but this phase can be reached other ways, and on every one
of them nothing else checks that the spec was ever reviewed before now. The
reasoning is worth stating plainly, since it is easy to mistake for
unnecessary caution: the agent that wrote a spec is the wrong one to find
its own gaps, so a pipeline that runs the phases below against an unreviewed
spec spends its entire budget implementing a flawed plan correctly instead
of catching the flaw before any work starts.

## Step 3 — Prepare dependencies

A freshly created worktree is missing whatever the project excludes from
version control — installed packages, a virtual environment, local
configuration files — none of which exist there yet.

If `git.worktree_setup` is configured, run it now and stop on a non-zero
exit; do not proceed into Step 4 with dependencies unresolved, since every
phase this step precedes assumes a working project environment and has no
way of diagnosing a setup failure it never expected to see. If
`git.worktree_setup` is absent, proceed directly — the project has declared
that nothing needs preparing.

## Step 4 — Run the phases

Dispatch each phase in order — test, execute, code-review, end — as a
**fresh subagent** from this phase's own context, never inlined into it.
The fresh context is what keeps each phase's reasoning uncontaminated by
this orchestrator's own state, and what makes any individual phase
resumable later, on this run or a different one, possibly under different
tooling. Every phase inherits this phase's own working directory — the
worktree already verified in Step 1 — and none of them creates a worktree
of its own; do not nest worktrees.

Pass the task ID to each dispatched phase.

### 4.1 — test

Dispatch the test phase. It returns a report of at most 300 characters in
the shape:

```
Tests: <path>. <N> tests written. Status: fail (red). Committed: yes.
```

Read the `Status:` field. If it does not report a failing suite — the
tests came back green against the pre-implementation code — stop the whole
pipeline here and return `BLOCKED`. A red phase that is already green means
the tests do not describe any new behavior: proceeding would hand the
execute phase nothing to make pass, and the code-review phase would find an
implementation nobody asked for, because it never had a failing contract to
satisfy in the first place. Do not dispatch execute in this case.

### 4.2 — execute

Otherwise, dispatch the execute phase. It returns a report of at most 300
characters in the shape:

```
Implemented: <summary>. Tests: pass (<N>). Lint: clean. Committed: yes.
```

This report has no field this phase branches on — its role here is
confirmation that the green phase completed and committed, so code-review
has a diff to read. Proceed to code-review.

### 4.3 — code-review

Dispatch the code-review phase. It returns a verdict of at most 500
characters in the shape:

```
Verdict: <APPROVED|APPROVED_WITH_WARNINGS|CHANGES_REQUESTED>. Blockers: <list|none>. Warnings: <list|none>.
```

Parse the `Verdict:` field — the one part of this line control flow depends
on; `Blockers:` and `Warnings:` are for the report in Step 5, not for this
branch:

- `APPROVED` or `APPROVED_WITH_WARNINGS` — proceed to end.
- `CHANGES_REQUESTED` — stop the pipeline here and return `STOPPED`, carrying
  the blocker list from the verdict line into Step 5's report. Do **not**
  loop back to execute automatically. An unattended fix loop against a
  rejected review is how a pipeline burns a branch: each unsupervised pass
  makes changes the review that rejected them has never seen, so nothing in
  the loop converges toward an approval — resuming after `CHANGES_REQUESTED`
  is a deliberate, separate re-entry into this phase, not a retry this phase
  performs on its own.

### 4.4 — end

Dispatch the end phase only on the `APPROVED` / `APPROVED_WITH_WARNINGS`
branch above. It returns a report, one line per item, with no fixed
character cap, covering (in order) the lint result, whether a
`commands.test_all` re-run was needed after autofixing, what it persisted to
project conventions or phase memory, branch push confirmation, the pull
request URL or which skip condition applied, and the tracker status result.
This phase does not branch on any single field in that report — it carries
the whole report into Step 5 to compose the pull request URL and the final
result.

## Step 5 — Report

Return, in this order:

- **Result** — one of:
  - `SHIPPED` — the end phase ran and completed.
  - `STOPPED` — code-review returned `CHANGES_REQUESTED`, or Step 1's guard
    or Step 3's dependency setup failed.
  - `BLOCKED` — the test phase reported no failing tests, or Step 2 found no
    review entry in the spec's handoff log.
- **Branch** — the task ID confirmed in Step 1.
- **Pull request URL** — taken from the end phase's report when `SHIPPED`;
  otherwise absent.
- **Worktree path** — `paths.worktrees/<task-id>`.
- On any result other than `SHIPPED`, a one-line reason so the operator
  knows where to resume: the blocker list on `STOPPED` from code-review, the
  guard or setup failure message on `STOPPED` from Step 1 or Step 3, the
  missing-review instruction from Step 2 on `BLOCKED`, or the confirmation
  that the test suite came back green on the other `BLOCKED` case.

Keep this report itself short, but note that "short" here is a choice, not
an oversight matching the leaf phases' own character caps: those caps exist
because a leaf phase's report is read by another phase running in a fresh
context, so the handoff log has to carry the real content. This report is
read by a human deciding what to do next, the same job `end.md`'s own
uncapped report serves — the rule is that a cap applies when the reader is
another phase, not when the reader is a person. Anything a human would need
to dig deeper already lives in the spec file's handoff log, which each
dispatched phase wrote to directly; this report only points to where things
stand, it does not restate what those phases already recorded.
