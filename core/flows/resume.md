# Flow: resume

Re-enter an interrupted pipeline at one phase, run that phase alone, and
stop. This is a recovery tool: an operator reaching for `resume` is already
dealing with something that went wrong — a phase crashed mid-run, a session
closed early, a `CHANGES_REQUESTED` verdict needs a deliberate second pass at
execute — and the one thing this flow must never do is compound that by
chaining forward into the phases that follow.

## Input

A task ID (for example `TASK-1`) and, optionally, a phase name: one of
`test`, `execute`, `code-review`, `end`. With no phase given, infer it in
`## Phase selection`, from the handoff log rather than from a guess.

## Phase selection

Read `.tdd-pipeline/config.yaml` first. Follow the fail-fast protocol in
`core/contracts/pipeline-config.md`: stop and name the exact missing key if
the file or a key this flow needs is absent. This flow needs `paths.specs`,
`paths.worktrees`, and `git.base_branch`.

When no phase argument was given, read `paths.specs/<task-id>.md`'s
`## Agent Handoff Log` in full, per `core/contracts/handoff-log.md`, and
apply **one** rule, in this order, stopping at the first branch that matches.

The rule is a single procedure rather than two descriptions of one intent
because phases repeat: a log can read `review`, `test`, `code-review`,
`execute` after one rejected review and a resumed fix, and "the phase after
the last entry" and "the first phase with no entry yet" name different phases
on exactly that log — one `code-review`, the other `end`. Dispatching `end`
there would push and open a pull request on a fix no review has seen.

1. Find the **last** entry whose heading names one of `test`, `execute`,
   `code-review`, `end` — last by position in the file, which is append
   order, not by the date in the heading. Ignore every other entry, including
   `review`.
2. If there is no such entry, resume at `test`. No leaf phase has run.
3. If that entry is `code-review` and it records a `CHANGES_REQUESTED`
   verdict, resume at `execute`. A rejected review sends the task back, not
   forward.
4. If that entry is `end`, there is nothing to resume: report the task as
   already shipped and stop without dispatching anything. Do not re-run
   `end` — it pushes, opens a pull request, and moves the tracker, none of
   which is safe to repeat blind.
5. Otherwise resume at the successor of that entry's phase in the fixed order
   `test` → `execute` → `code-review` → `end`.

Never take the count of entries, or which names are absent, into account:
only the identity of the last leaf-phase entry and, for `code-review`, its
verdict. On the log above, step 1 finds `execute` and step 5 resumes at
`code-review` — the fix gets reviewed, which is the point of having stopped.

## Preconditions

Confirm the spec at `paths.specs/<task-id>.md` exists and its handoff log
carries an entry whose heading begins with `review`, matched with the same
tolerance `pipeline.md`'s Step 2 uses. If not, stop: this flow runs no phase,
including `test`, against a spec that was never reviewed — direct the user to
run `review` first.

Confirm a worktree exists at `paths.worktrees/<task-id>` and its branch
equals the task ID. Three cases follow:

- **Worktree present, correct branch** — proceed to Execution.
- **Worktree present, wrong branch** — stop and report the mismatch; do not
  guess which state is correct or force a branch switch on the caller.
- **Worktree missing entirely** — recreate it from this task's own branch,
  never from `git.base_branch`. Look locally first, because a project with no
  remote is fully supported (see `core/phases/end.md` Step 4) and there the
  task's branch exists only locally:

  ```bash
  git rev-parse --verify --quiet "refs/heads/<task-id>"
  ```

  On success, recreate from the local branch with no fetch:

  ```bash
  git worktree add "<paths.worktrees>/<task-id>" "<task-id>"
  ```

  If the local branch does not exist and a remote is configured, fetch the
  branch first, then add the worktree the same way:

  ```bash
  git fetch <remote> "<task-id>"
  git worktree add "<paths.worktrees>/<task-id>" "<task-id>"
  ```

  Use the remote the repository actually names (`git remote`), not an assumed
  one, the same way the end phase does.

  Recreating from the base branch would silently discard whatever this task
  committed on its own branch — commits from phases that already ran, which
  are exactly what this flow exists to resume past. Only when the branch
  exists neither locally nor on any configured remote is there nothing to
  resume: stop and report that the task was never started through `task`, or
  its branch was deleted. "No remote configured" is never by itself a reason
  to report nothing to resume.

Whether the worktree was confirmed or recreated, mirror any untracked
scaffolding into it before dispatching, per
`core/contracts/untracked-scaffolding.md`. A recreated worktree is as bare as
a new one, and a project that keeps its specs out of git has none there — the
phase would stop at its first step, or worse, read a spec with no handoff log
and mistake a resumed task for a fresh one.

## Execution

Dispatch the single phase selected above — `core/phases/test.md`,
`core/phases/execute.md`, `core/phases/code-review.md`, or
`core/phases/end.md` — as a subagent whose working directory is the worktree
confirmed or recreated above, passing the task ID. Do not dispatch
`core/phases/pipeline.md` in its place: that phase runs the full sequence,
reintroducing exactly the chaining this flow exists to avoid.

Stop once the dispatched phase returns. When anything was mirrored in, copy
the spec back to the main checkout first — the phase's handoff-log entry is
the record the next resume reads, and it was written to the copy.

Report its result exactly as it came
back — the leaf phases' fixed-shape report or verdict line, unchanged — and
the worktree path this ran against. Do not dispatch the next phase, and do
not offer to. If the operator wants to continue, running this flow again is
how they do it, deliberately, one phase at a time.
