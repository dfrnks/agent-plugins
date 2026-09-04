# Phase: pipeline

Orchestrate the four leaf phases — test, execute, code-review, end — against
one task, in order, inside the worktree the task flow already created. This
phase writes nothing and adjudicates nothing; it dispatches the phases that
do, reads what each reports, and decides whether the next one runs.

The argument is a task ID (for example `TASK-1`). If none is given, derive it
from the current branch name.

## Step 0 — Load configuration

Read `.tdd-pipeline/config.yaml`. Follow the fail-fast protocol in
`core/contracts/pipeline-config.md`: stop and name the exact missing key if
the file or a key this phase needs is absent. This phase needs
`paths.worktrees`, `paths.specs`, and, when present, `git.worktree_setup`.

If that file is not in the worktree at all, do not fail yet: the project may
keep it out of git, in which case a fresh worktree cannot contain it. Mirror
it per `core/contracts/untracked-scaffolding.md` and read it again. Its path
is fixed, which is what makes this possible — the configured paths cannot be
mirrored until the configuration naming them has been read, so the
configuration has to come first, by its own known path. Once it is loaded,
mirror whichever of the configured paths are untracked, before Step 2 reads
the spec. Report which paths were mirrored in Step 5, or that none were.

Reaching this step with the file already absent *and* tracked is the ordinary
fail-fast case, and stops the run as before.

## Step 1 — Verify the working directory

This phase must never run against the main repository. The portable check
compares the repository top level against the parent of the common git
directory: in a plain checkout the two are equal; in a worktree they diverge.

```bash
TOP=$(git rev-parse --show-toplevel)
COMMON=$(git rev-parse --path-format=absolute --git-common-dir)
if [ "$TOP" = "$(dirname "$COMMON")" ]; then
  echo "Refusing to run: this is the main repository, not a task worktree."
  exit 1
fi
```

On failure, stop without editing anything and report that the task flow must
create the worktree first. This phase creates none for itself and does not
fall back to running in place.

Then confirm the branch is the task ID — a real conditional that stops the
phase, not a comment an agent has to notice and act on:

```bash
BRANCH=$(git branch --show-current)
if [ "$BRANCH" != "<task-id>" ]; then
  echo "Refusing to run: current branch '$BRANCH' does not match task '<task-id>'."
  exit 1
fi
```

A mismatch stops this phase the same way, without editing anything.

## Step 2 — Verify the spec was reviewed

Read `paths.specs/<task-id>.md` before dispatching any phase. Confirm its
`## Agent Handoff Log` (per `core/contracts/handoff-log.md`) contains an
entry whose heading begins with `review` — matched tolerantly: case
insensitive, allowing a date suffix or a qualifier to follow, so
`### review (YYYY-MM-DD)` and `### Review-plan` both match, and only an entry
with no resemblance at all fails.

If none exists, stop and return `BLOCKED`, naming the fix: run the review
flow against this task's spec, then re-invoke this phase. Do not run the
sequence anyway, and do not offer a way to skip — a guard a caller can bypass
is a suggestion.

This check exists for the paths that reach this phase without passing the
`task` flow's own gate: a direct dispatch, a resume after an interruption, or
an invocation against an existing worktree and spec. On every one of them
nothing else checks that the spec was reviewed. The agent that wrote a spec
is the wrong one to find its own gaps, so running the phases below against an
unreviewed spec spends the whole budget implementing a flawed plan correctly.

## Step 3 — Prepare dependencies

A fresh worktree is missing whatever the project excludes from version
control — installed packages, a virtual environment, local configuration.

If `git.worktree_setup` is configured, run it now — **directly, by its own
path, from the worktree root**, not through an interpreter chosen here:

```bash
./<git.worktree_setup>
```

The script carries its own shebang and executable bit, both guaranteed by the
flow that created it and checked by doctor. A named interpreter would work by
accident for one language, silently pick the wrong one for another, and mask
the misconfiguration that doctor row exists to catch.

Stop on a non-zero exit. Every phase after this one assumes a working
environment and cannot diagnose a setup failure it never expected. If
`git.worktree_setup` is absent, proceed — the project has declared that
nothing needs preparing.

## Step 4 — Run the phases

Dispatch each phase in order — test, execute, code-review, end — as a **fresh
subagent**, never inlined. The fresh context keeps each phase's reasoning
uncontaminated by this orchestrator's state and makes any phase resumable
later, possibly under different tooling. Every phase inherits this phase's
working directory, the worktree verified in Step 1; none creates a worktree
of its own. Do not nest worktrees.

Pass the task ID to each dispatched phase.

When Step 0 mirrored anything, copy the spec back to the main checkout as
each phase returns — every phase, including one that stops the run, and
before deciding what to do about its result. Phases append their handoff-log
entries to the spec they can see, which in a mirrored worktree is the copy;
the copy dies with the worktree. `core/contracts/untracked-scaffolding.md`
governs this, including the conventions document and the memory directory,
which the end phase writes.

**Run the four phases in a single pass, and do not hand control back in the
middle of it.** Dispatch each phase and **wait for it to return** before
deciding anything; dispatching one and reporting that it was dispatched is
not running it. If the tooling offers a background or detached dispatch, do
not use it here.

There are exactly four ways out of Step 4, all of them results rather than
pauses: `BLOCKED` from 4.1, `STOPPED` from 4.2 or 4.4, `CHANGES_REQUESTED`
from 4.3, or reaching the end phase and returning `SHIPPED`. Stopping
anywhere else — to summarise progress, to report a phase's output, to ask
whether to continue — is not one of them. An orchestrator that narrates and
yields defeats its own purpose, because a person now has to restart it at
each boundary.

This matters most for the three phases after `test`: their inputs come from
the handoff log and from git, not from this phase's context, so there is
never anything to pause and gather.

### 4.1 — test

Dispatch the test phase. It returns at most 300 characters:

```
Tests: <path>. <N> tests written. Status: <fail (red)|pass (green)|unverified|n/a (nothing testable)>. Committed: <yes|no>.
```

Read `Status:`. `fail (red)` and `n/a (nothing testable)` continue; the other
two stop the pipeline and return `BLOCKED`, carrying which one into Step 5's
reason. Do not dispatch execute on a stop.

- `pass (green)` — the tests describe no new behavior, so execute would have
  nothing to make pass and code-review would find an implementation nobody
  asked for.
- `unverified` — the suite was never run, so nothing is known about it.
  Treat this as an environment or permission failure to report, not as a
  test-design problem: the fix is to make `commands.test` runnable, which is
  what the test phase's own line names.
- `n/a (nothing testable)` — the task changes nothing a command can observe,
  so there is no red to wait for. Continue, and carry the status into
  Step 5's report so the run is never described as having gone red. The
  claim is not taken on trust: code-review adjudicates it against the same
  spec, and a task that had a testable item ships as a finding rather than
  silently.

A pipeline with no path for an untestable change does not enforce testing —
it converts every documentation fix into a `BLOCKED` run, and the way around
a gate that cannot be satisfied is a fabricated test, which is worse than the
change it was guarding.

### 4.2 — execute

Otherwise dispatch execute. It returns at most 300 characters:

```
Implemented: <summary>. Tests: pass (<N>). Lint: clean. Committed: yes.
```

That is the completed shape. The phase can also stop before reaching it — one
of its stop-and-escalate conditions, or a verification loop it could not
drive to green. Treat any return that is not the completed shape as a stop of
the whole pipeline: return `STOPPED`, carry execute's own account into
Step 5's reason, and do not dispatch code-review, which adjudicates finished
implementations and would otherwise deliver a verdict on work nobody claimed
was done.

On the completed shape, proceed. There is no field to branch on — the report
confirms that the green phase committed, so code-review has a diff to read.

### 4.3 — code-review

Dispatch code-review. It returns at most 500 characters:

```
Verdict: <APPROVED|APPROVED_WITH_WARNINGS|CHANGES_REQUESTED>. Blockers: <list|none>. Warnings: <list|none>.
```

Branch on `Verdict:` alone; `Blockers:` and `Warnings:` are for Step 5:

- `APPROVED` or `APPROVED_WITH_WARNINGS` — proceed to end.
- `CHANGES_REQUESTED` — stop and return `STOPPED`, carrying the blocker list
  into Step 5. Do **not** loop back to execute. Each unsupervised pass makes
  changes the rejecting review never sees, so nothing converges toward
  approval. Resuming is an operator-initiated act through
  `core/flows/resume.md`, which dispatches the single execute phase and
  stops — not a retry this phase performs, and not a re-invocation of this
  phase either, since re-entering here would resume the chaining the stop
  exists to break.

### 4.4 — end

Dispatch end only on the `APPROVED` / `APPROVED_WITH_WARNINGS` branch. It
returns one line per item, uncapped, covering in order the lint result,
whether a `commands.test_all` re-run was needed after autofixing, what it
persisted, branch push confirmation, the pull request URL or skip condition,
the tracker result, and — as its final line — the signal this phase branches
on:

```
End phase: <completed|stopped at Step <N>: <reason>>.
```

Branch on that line alone, and carry the whole report into Step 5 for the
pull request URL and final result. `completed` means end reached its own
Step 8: `SHIPPED`. Anything else means it stopped partway through one of its
own steps — a push failure other than the defined "no remote configured"
skip, a failed tracker update, or malformed conventions markers — and yields
`STOPPED`, carrying end's account into Step 5's reason.

If the report is missing that line entirely, treat it as `STOPPED` with the
reason "end phase reported no completion signal". Do not infer completion
from the other lines: a report can carry a lint result and a persistence line
and still come from a phase that stopped three steps later.

## Step 5 — Report

Return, in this order:

- **Result** — one of:
  - `SHIPPED` — the end phase ran and completed.
  - `STOPPED` — code-review returned `CHANGES_REQUESTED`, execute stopped or
    escalated instead of returning its completed shape (4.2), Step 1's guard
    or Step 3's setup failed, or the end phase stopped partway through one of
    its own steps.
  - `BLOCKED` — the test phase reported `pass (green)` or `unverified`, or
    Step 2 found no review entry in the handoff log.
- **Branch** — the task ID confirmed in Step 1.
- **Pull request URL** — from the end phase's report when `SHIPPED`;
  otherwise absent.
- **Worktree path** — `paths.worktrees/<task-id>`.
- On any result other than `SHIPPED`, a one-line reason so the operator knows
  where to resume: the blocker list, the guard or setup failure message,
  execute's own stop, the step and error end reported, the missing-review
  instruction, the confirmation that the suite came back green, or what
  stopped it from being run at all.

Keep this report short, but note the leaf phases' character caps do not apply
here: a cap exists when the reader is another phase running in a fresh
context, which is why the handoff log carries the real content. This report
is read by a person deciding what to do next. Anything they need to dig into
already lives in the handoff log each dispatched phase wrote to; this report
points at where things stand rather than restating it.
