# Flow: resume

Re-enter an interrupted pipeline at one phase, run that phase alone, and
stop. This is a recovery tool: an operator reaching for `resume` is already
dealing with something that went wrong — a phase crashed mid-run, a session
was closed early, a `CHANGES_REQUESTED` verdict needs a deliberate second
pass at execute — and the one thing this flow must never do is compound
that state by chaining forward into the phases that follow. Run one phase,
report what it returned, and hand control back to whoever invoked this flow.

## Input

A task ID (for example `TASK-1`) and, optionally, a phase name: one of
`test`, `execute`, `code-review`, `end`. With no phase given, infer it in
Step 2, from the handoff log rather than from a guess.

## Phase selection

Read `.tdd-pipeline/config.yaml` first. Follow the fail-fast protocol in
`core/contracts/pipeline-config.md`: stop and name the exact missing key if
the file or a key this flow needs is absent. This flow needs `paths.specs`,
`paths.worktrees`, and `git.base_branch`.

When no phase argument was given, read `paths.specs/<task-id>.md`'s
`## Agent Handoff Log` in full, per `core/contracts/handoff-log.md`, and
apply **one** rule, in this order, stopping at the first branch that
matches. The rule is deliberately stated as a single procedure rather than
as two descriptions of the same intent, because phases repeat: a log can
read `review`, `test`, `code-review`, `execute` after one rejected review
and a resumed fix, and "the phase after the last entry" and "the first
phase in the sequence with no entry yet" name different phases on exactly
that log — one of them `code-review`, the other `end`, and dispatching
`end` there would push and open a pull request on a fix no review has seen.

1. Find the **last** entry in the log whose heading names one of `test`,
   `execute`, `code-review`, `end` — last by position in the file, which is
   append order, not by the date written in the heading. Ignore every other
   entry, including `review`, when identifying it.
2. If there is no such entry, resume at `test`. No leaf phase has run.
3. If that entry is `code-review` and it records a `CHANGES_REQUESTED`
   verdict, resume at `execute`. A rejected review sends the task back, not
   forward.
4. If that entry is `end`, there is nothing to resume: report the task as
   already shipped through its end phase and stop without dispatching
   anything. Do not re-run `end` — it pushes, opens a pull request, and
   moves the tracker, none of which is safe to repeat blind.
5. Otherwise, resume at the successor of that entry's phase in the fixed
   order `test` → `execute` → `code-review` → `end`.

Never take the count of entries, or which names are absent, into account:
only the identity of the last leaf-phase entry and, for `code-review`, its
verdict. On the log above, step 1 finds `execute`, and step 5 resumes at
`code-review` — the fix gets reviewed, which is the whole point of having
stopped.

## Preconditions

Confirm the spec at `paths.specs/<task-id>.md` exists and its handoff log
carries an entry whose heading begins with `review`, matched with the same
tolerance `pipeline.md`'s Step 2 uses. If it does not, stop: this flow does
not run any phase, including `test`, against a spec that was never reviewed
— direct the user to run `review` first.

Confirm a worktree for this task exists at `paths.worktrees/<task-id>` and
its current branch equals the task ID. Three cases follow from what's
actually there:

- **Worktree present, correct branch** — proceed to Execution.
- **Worktree present, wrong branch** — stop and report the mismatch; do not
  guess which state is correct or force a branch switch on the caller's
  behalf.
- **Worktree missing entirely** — recreate it from this task's own branch,
  never from `git.base_branch`. Look for that branch locally first, because
  a local-only project — no remote configured at all — is a fully supported
  configuration this pipeline serves (see `core/phases/end.md` Step 4), and
  in it the task's branch exists only locally:

  ```bash
  git rev-parse --verify --quiet "refs/heads/<task-id>"
  ```

  If that succeeds, recreate the worktree from the local branch directly,
  with no fetch:

  ```bash
  git worktree add "<paths.worktrees>/<task-id>" "<task-id>"
  ```

  If the local branch does not exist and a remote is configured, fetch the
  branch from it first and then add the worktree the same way:

  ```bash
  git fetch <remote> "<task-id>"
  git worktree add "<paths.worktrees>/<task-id>" "<task-id>"
  ```

  Use the remote the repository actually names (`git remote`), not an
  assumed one, the same way the end phase does.

  Recreating from the base branch instead would silently discard whatever
  this task already committed on its own branch — commits from phases that
  already ran, and are exactly what this flow exists to resume past, not
  erase. Only when the branch exists neither locally nor on any configured
  remote is there nothing to resume: stop and report that the task was never
  started through `task`, or its branch was deleted. "No remote configured"
  is never by itself a reason to report nothing to resume.

## Execution

Dispatch the single phase selected above — `core/phases/test.md`,
`core/phases/execute.md`, `core/phases/code-review.md`, or
`core/phases/end.md` — as a subagent whose working directory is the
worktree confirmed or recreated above, passing the task ID. Do not dispatch
`core/phases/pipeline.md` in its place: that phase runs the full sequence,
and running it here would reintroduce exactly the chaining this flow exists
to avoid.

Stop once the dispatched phase returns. Report its result exactly as it
came back — the leaf phases' fixed-shape report or verdict line, unchanged
— and the worktree path this ran against. Do not dispatch the next phase in
sequence, and do not offer to. If the operator wants to continue, running
this flow again is how they do it, deliberately, one phase at a time.
