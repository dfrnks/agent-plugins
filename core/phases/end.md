# Phase: end

Ship the task the code-review phase approved. This phase writes no
implementation code and adjudicates nothing — everything it touches was
already judged correct. It lints what changed, makes sure anything this task
learned survives past this task, commits and pushes, opens the pull request,
and moves the tracker.

It runs only after code-review returned `APPROVED` or
`APPROVED_WITH_WARNINGS`. `CHANGES_REQUESTED` sends the task back to execute
instead; this phase never runs against a review that rejected it.

The argument is a task ID (for example `TASK-1`). If none is given, derive it
from the current branch name.

## Step 0 — Load configuration

Read `.tdd-pipeline/config.yaml`. Follow the fail-fast protocol in
`core/contracts/pipeline-config.md`: stop and name the exact missing key if
the file or a key this phase needs is absent. This phase needs
`commands.lint`, `commands.test_all`, `paths.conventions`, `paths.specs`,
`paths.worktrees`, `git.base_branch`, `git.commit_trailer`, `pr.enabled`, and
`tracker.type`.

`tracker.type` selects which file among `core/trackers/none.md`,
`core/trackers/linear.md`, and `core/trackers/github.md` governs Step 6. That
file may require further keys of its own (`tracker.team`, `tracker.states`),
and an absent one follows the same fail-fast rule.

## Step 1 — Detect changed areas

Identify every commit made for this task since it diverged from
`git.base_branch` — the technique code-review's Step 2 uses — and list every
file the diff touches.

Separate the spec file's own edits (handoff log entries, which no linter
checks) from everything else. If the spec file is the only file this task
changed, nothing in `commands.lint`'s scope changed at all; carry that
forward to Step 2.

## Step 2 — Lint

If Step 1 found nothing outside the spec file changed, skip this step and
record the skip for Step 7's report.

Otherwise run `commands.lint`. Fix every violation its autofix left behind
and re-run until it exits clean, the same discipline execute's lint gate
holds itself to.

A lint command may run over the whole repository, so a single run can
format-touch a file this task never modified. Before staging anything in
Step 4, diff the lint run's output against Step 1's file list and revert any
change to a file outside it. A linter may clean up what this task touched; it
may not fold an unrelated file's reformatting into this pull request.

Do not assume an autofix is behavior-neutral because a linter made it. A
removed "unused" import can drop a needed side effect; a reordered
declaration can change initialization order; a rewritten expression can
change what it evaluates to at the margins. If any fix applied here could
plausibly have changed behavior, re-run `commands.test_all` before Step 4's
commit — and under `policy.full_suite: on_end`, run it whether or not a fix
could have, because that value puts the one broad run here deliberately, as the
last gate before the pull request. Under `never`, run `commands.test` instead
and say so. Either way say which in Step 7's report — that a re-run happened and
passed, or that nothing here could have changed behavior. Code-review
approved the pre-lint state, so this is the last gate between an autofix and
a merge.

## Step 3 — Persist durable discoveries

No *unrelated* session ever reads this spec file or handoff log again after
this task closes. The only document one of those reads is
`paths.conventions`. Any durable fact discovered while working this task is
lost unless it lands there now — and the cost does not disappear, it moves to
whichever session hits the same problem next.

The one exception is a task built directly on this one — a branch cut from
this branch, shipping as a stacked pull request. Its phases do read this log,
because it is the only record of what this task actually built: the shape of
the interface they are about to call, and the decisions a reviewer needed.
That is not a reason to route a durable fact here instead of to
`paths.conventions`; the two carry different things, and a fact that outlives
this pair of tasks belongs in conventions regardless.

Read every subsection the test, execute, and code-review phases appended to
`## Agent Handoff Log` in `paths.specs/<task-id>.md` (see
`core/contracts/handoff-log.md`), start to finish. For each finding — a "no
rule found" line, a convention applied, a deviation from the spec, a review
warning, a non-obvious decision — ask one question: is this a durable fact
about the project itself, true regardless of whether this pipeline ever ran,
and not already in `paths.conventions`?

If yes, append it under the matching area heading inside that file's
**discoveries span** (`core/contracts/conventions-template.md`,
`<!-- pipeline:discoveries:start -->` / `<!-- pipeline:discoveries:end -->`) —
never inside the managed section where those same headings also appear. The
conventions flow rewrites the managed section wholesale on every run, so
anything written there is silently discarded; the discoveries span exists so
these appends survive. Match the surrounding entries' heading structure,
tone, and detail. If the fact fits no existing heading, add the smallest new
one that describes it.

Route every other finding through the handoff-log contract's table:

- A project fact — `paths.conventions`.
- A phase-workflow learning, meaningful only to how a phase runs:
  `.tdd-pipeline/memory/<phase>/`.
- A detail specific to this task alone — stays in the handoff log, untouched.

Append a dated `### end` subsection to `## Agent Handoff Log` —
**unconditionally, on every run, whether or not anything was escalated** —
exactly as the other phases append their own. Record:

- Each finding escalated to `paths.conventions` or
  `.tdd-pipeline/memory/<phase>/`, in the contract's escalation form, or an
  explicit line stating nothing durable was found.
- Step 2's lint result, including a skip and its reason.
- That this phase ran, and how far it got.

The unconditional part matters: this is the only entry recording that the
task shipped, and the resume flow infers the next phase from the last
leaf-phase entry. With no `end` entry a shipped task reads as one whose end
phase never ran, and the next `resume` dispatches `end` again — pushing
again, opening a second pull request, moving the tracker on closed work.

Write the entry before Step 4 commits, so it ships in the same commit and
survives a later step stopping.

State this step's outcome in Step 7 even when it found nothing. Silence and a
considered "nothing durable this task" are indistinguishable to a later
reader, and only one of them is acceptable.

### When this task is the first code in the project

While reading `paths.conventions` above, check whether its **managed
section** holds any rule. If it does, there is nothing more to do here. If it
holds none, the project was greenfield when configured
(`core/contracts/project-requirements.md`, `## Greenfield projects`), and
this task just committed the source code that ends that state.

Report the transition in Step 7, in one line:

```
This task is the first source code in this project. Conventions are now
derivable; run the conventions flow to derive them.
```

Do not run the conventions flow from here, and do not write rules into the
managed section. That section belongs to the conventions flow, whose rule bar
needs several independent call sites — one task's worth of new code is
exactly the single-source evidence that bar exists to reject.

The report line is the whole mechanism. The greenfield state clears on a
commit, not on a run of any flow, so nothing else is watching for the moment
it ends; this phase is the one place guaranteed to be reading the conventions
file when the first code lands.

Everything in this step runs before Step 4's commit, so any edit to
`paths.conventions` ships alongside the work that motivated it.

## Step 4 — Commit and push

A task whose entire diff already landed in earlier phases' commits can reach
this step with nothing to stage. That is not a failure: report it plainly in
Step 7 and continue to Step 5, rather than failing the phase or fabricating a
commit.

Stage Step 2's lint fixes, any edit Step 3 made to `paths.conventions` or
`.tdd-pipeline/memory/<phase>/`, and the spec file's updated handoff log:

```bash
git add <lint-fixed files> <paths.conventions, if edited> <spec file>
git commit -m "<task-id>: ship"
```

Stage specific files — never `git add .` or `git add -A`, which would pull
back the out-of-scope lint noise Step 2 just excluded. If
`git.commit_trailer` is non-empty, append it as a trailer; if empty, omit it
rather than adding an empty line.

A project with no remote is fully supported — local-only use with
`pr.enabled: false` is a first-class case, not a degraded one. Check first:

```bash
git remote
```

With at least one remote, push to the one that command actually named, never
an assumed one:

```bash
REMOTE=$(git remote | head -n 1)
git push -u "$REMOTE" HEAD
```

A repository whose only remote is not called `origin` is ordinary, and a
hardcoded `origin` fails there on a project with a perfectly usable remote.
With several remotes prefer `origin` if present, otherwise the first listed,
and say which in Step 7's report.

A push failure for any other reason — authentication, a rejected
non-fast-forward, a network error — is a stop. Report it and do not proceed
to Step 5; there is no pull request to open against a branch that never
reached the remote.

With no remote, skip the push, record the skip in Step 7, and proceed to
Step 5, which skips for the same reason.

## Step 5 — Open the pull request

Skip this step, saying so in Step 7, when any of these holds:

- the current branch is `git.base_branch`,
- `pr.enabled` is `false`,
- Step 4 found no remote to push against,
- a pull request for this branch already exists — check before creating one.

Otherwise open one against `git.base_branch`, titled with the task ID and a
short description. Build the body from three parts:

- a short summary of what the task changed,
- the spec's `## Definition of Done` checklist, with every item this task
  satisfies checked off,
- a test plan naming the commands a reviewer runs to verify:
  `commands.test_all`, `commands.lint`, and anything else the Definition of
  Done named.

## Step 6 — Update tracker status

Open `core/trackers/<tracker.type>.md` and call its `set_status` operation
with the task ID and the phase `review` — shipping is the point where the
tracker should show the work as ready for review, not merely in progress.

Report the result exactly as that file specifies: `none` mode reports its
fixed line (`tracker: none, no status update`); `linear` and `github` report
the state or label the issue moved to. A failed call — missing connection,
unmatched state name, missing `gh` authentication — is a stop, per that
file's own rules. A quietly failed update leaves the board stale while the
code has already shipped.

## Step 7 — Report

Report, in order:

- Whether Step 2's lint ran and its result — clean, or skipped because
  nothing in its scope changed.
- Whether Step 2's autofixes required a `commands.test_all` re-run and the
  result, or an explicit statement that none was needed.
- What Step 3 persisted to `paths.conventions` or phase memory, naming each
  item, or an explicit statement that nothing durable was found. Never leave
  this silent.
- That the branch was pushed, to which remote, and what it carries — or that
  no remote was configured and the push was skipped.
- The pull request URL, or which of Step 5's skip conditions applied.
- Step 6's tracker status result.
- As the **final line**, the completion signal the orchestrator branches on
  (`core/phases/pipeline.md` Step 4.4), in exactly this shape:

  ```
  End phase: <completed|stopped at Step <N>: <reason>>.
  ```

  Write `completed` only when Step 8 is reached — every step above either ran
  or applied a defined skip. On a stop, write that instead, naming the step
  number and reason, and emit the report there rather than ending silently.
  Without this line the orchestrator has no field to read and must treat the
  run as stopped, turning a shipped task into a reported failure.

One line per item. This report is read by a human deciding whether to merge,
not by a phase resuming from a handoff log, so it carries no character cap —
but it still excludes what belongs in the handoff log: reasoning, the full
diff, alternatives considered.

## Step 8 — Worktree cleanup hint

Close the report with the cleanup command for this task's worktree, and state
plainly that it is not to be run yet:

```bash
git worktree remove <paths.worktrees>/<task-id>
```

Substitute the configured `paths.worktrees` value and the actual task ID —
this is a command for a person to run, not one this phase executes. State
that the worktree stays until the pull request merges: review feedback gets
addressed inside this same worktree, and removing it first throws away the
one place left to make those changes.
