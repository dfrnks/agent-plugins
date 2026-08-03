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

Read `.agent-pipeline/config.yaml` first. Follow the fail-fast protocol in
`core/contracts/pipeline-config.md`: stop and name the exact missing key if
the file or a key this flow needs is absent. This flow needs `paths.specs`,
`paths.worktrees`, and `git.base_branch`.

When no phase argument was given, read `paths.specs/<task-id>.md`'s
`## Agent Handoff Log` in full, per `core/contracts/handoff-log.md`. The
phase to run is the one after the last dated entry recorded there, in the
fixed order `test`, `execute`, `code-review`, `end` — an entry named for one
of these means that phase already ran; the phase to resume is the next name
in the sequence that has no entry yet. A log holding only a `review` entry
and nothing past it means no leaf phase has run at all — resume at `test`.

If the log's last entry is a `code-review` verdict of `CHANGES_REQUESTED`,
the next phase in sequence is still `execute` — a rejected review sends the
task back to execute, not forward to end — infer that specifically rather
than defaulting to the fixed-order successor of `code-review`.

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
- **Worktree missing entirely** — recreate it from the existing remote
  branch, never from `git.base_branch`:

  ```bash
  git fetch origin "<task-id>"
  git worktree add "<paths.worktrees>/<task-id>" "<task-id>"
  ```

  Recreating from the base branch instead would silently discard whatever
  this task already pushed to its remote branch — commits from phases that
  already ran, and are exactly what this flow exists to resume past, not
  erase. If the remote branch does not exist either, stop and report that
  there is nothing to resume: the task was never started through `task`, or
  its branch was deleted, and either way this flow has no state to recover.

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
