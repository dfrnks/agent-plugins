# Phase: end

Ship the task the code-review phase approved. This phase writes no
implementation code and adjudicates nothing — everything it touches was
already judged correct by the phases before it. Its job is to close the
loop: lint what changed, make sure anything this task learned about the
project survives past this task's own lifetime, commit and push, open the
pull request, and move the tracker to reflect that the work is ready for
review.

This phase runs only after code-review has returned a verdict of
`APPROVED` or `APPROVED_WITH_WARNINGS`. A verdict of `CHANGES_REQUESTED`
means the task returns to the execute phase instead — this phase never
runs against a task the review rejected.

The argument to this phase is a task ID (for example `TASK-1`). If none is
given, derive it from the current branch name.

## Step 0 — Load configuration

Read `.agent-pipeline/config.yaml`. Follow the fail-fast protocol in
`core/contracts/pipeline-config.md`: stop and name the exact missing key
if the file or a key this phase needs is absent. This phase needs
`commands.lint`, `commands.test_all`, `paths.conventions`, `paths.specs`,
`paths.worktrees`, `git.base_branch`, `git.commit_trailer`, `pr.enabled`,
and `tracker.type`.
`tracker.type` selects which file among `core/trackers/none.md`,
`core/trackers/linear.md`, and `core/trackers/github.md` governs Step 6;
that file may require further keys of its own (`tracker.team`,
`tracker.states`, depending on mode), and an absent one of those follows
the same fail-fast rule.

## Step 1 — Detect changed areas

Identify every commit made for this task since it diverged from
`git.base_branch` — the same technique code-review's Step 2 uses — and
list every file the diff touches. This file list drives two decisions
later in this phase: whether Step 2 has anything to lint, and what Step 3
has to look through when it mines the task for durable discoveries.

Separate the files the diff touches into the spec file's own edits (the
handoff log entries every phase leaves behind, not something a linter
checks) and everything else (implementation and test files, the actual
scope `commands.lint` exists to check). If the spec file is the only file
this task changed, nothing in `commands.lint`'s scope changed at all —
carry that forward to Step 2.

## Step 2 — Lint

If Step 1 found nothing outside the spec file changed, skip this step
entirely and record the skip for Step 7's report. Running a linter over a
diff that touched nothing it would check produces nothing but noise for
whoever reads the report next.

Otherwise, run `commands.lint`. Fix every violation it reports that its
own autofix left behind, and re-run until it exits clean — the same
discipline the execute phase's own lint gate holds itself to.

A lint command may run over the whole repository rather than a specific
target, which means a single run can format-touch a file this task never
modified. Before staging anything in Step 4, diff the lint run's output
against the file list from Step 1 and revert any change to a file outside
that list. A linter is entitled to clean up what this task touched; it is
not entitled to fold an unrelated file's reformatting into this task's
pull request, where nobody asked for it and nobody will review it as part
of this change.

Do not assume an autofix is behavior-neutral just because it came from a
linter rather than a hand edit. A removed "unused" import can drop a
needed side effect; a reordered import or declaration can change
initialization order; a rewritten expression can change what it evaluates
to at the margins. If any fix Step 2 applied or accepted could plausibly
have changed behavior rather than only style, re-run `commands.test_all`
before Step 4's commit, and say so in Step 7's report either way — that a
re-run happened and passed, or that nothing Step 2 did could have changed
behavior and so none was needed. Code-review already approved the
pre-lint state; this is the last gate standing between an autofix and a
merge, and treating every autofix as automatically safe is exactly the
assumption that lets a behavior change ship silently.

## Step 3 — Persist durable discoveries

This is the highest-leverage step in this phase, and the easiest one to
skip, because nothing forces it: nothing else in the pipeline ever reads
a spec file or a handoff log again after this task closes.
`paths.specs/<task-id>.md` sits untouched once the branch merges, and no
later phase run opens it back up. The only document a future session
actually reads is `paths.conventions`. So any durable fact a phase
discovered while working this task — a rule about the codebase, a naming
pattern, a command, a contract — is lost the moment this task closes
unless it lands there first. Skipping this step doesn't make that
discovery cost disappear; it moves the cost onto whichever session hits
the same problem next, and that session pays it slowly, and often gets it
wrong.

Read every subsection the test, execute, and code-review phases appended
to `## Agent Handoff Log` in `paths.specs/<task-id>.md` (see
`core/contracts/handoff-log.md`), start to finish. For each finding
recorded there — a "no rule found" line, a convention actually applied, a
deviation from the spec, a review warning, a non-obvious implementation
decision — ask one question: is this a durable fact about the project
itself, true regardless of whether this pipeline ever ran against it, and
not already present in `paths.conventions`?

If yes, append it under the matching area heading inside
`paths.conventions`'s **discoveries span**
(`core/contracts/conventions-template.md`'s discoveries section markers,
`<!-- pipeline:discoveries:start -->` / `<!-- pipeline:discoveries:end -->`)
— never inside the managed section those same headings also appear under.
The conventions flow owns the managed section and rewrites it wholesale on
every run of its own; anything this phase wrote there would be silently
discarded the next time that flow runs. The discoveries span exists
precisely so this phase's appends survive that rewrite. Match the
surrounding entries' heading structure, tone, and level of detail — a rule
that reads like it was airlifted in from a different document is harder for
the next reader to trust than one that reads like it always belonged there.
If the fact fits no existing heading, add the smallest new heading that
describes it, following the same area-heading convention rather than
inventing a new structure.

Route every other finding through the same table the handoff-log contract
defines, since not everything durable belongs in the same place:

- A project fact — `paths.conventions`.
- A phase-workflow learning, meaningful only to how a phase runs and not
  to a human reading the codebase — `.agent-pipeline/memory/<phase>/`.
- A detail specific only to this task, with no reuse value beyond it —
  stays in the handoff log, untouched.

When a finding is escalated, note the escalation in a final dated
subsection this phase appends to `## Agent Handoff Log`, per the
contract's escalation-routing note, so a later reader of the log knows
the finding was acted on rather than silently dropped.

State the outcome of this step explicitly in Step 7's report even when it
found nothing worth persisting. An absent statement and a considered
"nothing durable this task" look identical to a later reader unless the
report says which one happened — silence here is indistinguishable from
the step never having run at all, and only one of those is acceptable.

This step runs before Step 4's commit, not after, so any edit to
`paths.conventions` ships in the same commit as the work that motivated
it — a rule discovered by this task and recorded in some later commit is
a rule that was true and undocumented for the length of an entire pull
request.

## Step 4 — Commit and push

A task whose entire diff already landed in commits made by earlier phases
can reach this step with nothing left to stage — Step 2 found nothing to
lint, Step 3 found nothing durable to persist, and the working tree is
empty. That is not a failure: report it plainly in Step 7 and continue on
to Step 5 as if the commit had happened, rather than failing this phase or
fabricating a commit to have something to point to.

Stage whatever Step 2's lint fixes left in this task's own diff, any edit
Step 3 made to `paths.conventions` or `.agent-pipeline/memory/<phase>/`,
and the spec file's updated handoff log, then commit:

```bash
git add <lint-fixed files> <paths.conventions, if edited> <spec file>
git commit -m "<task-id>: ship"
```

Stage specific files — never `git add .` or `git add -A`. Step 2 already
excluded whatever the lint command's autofix touched outside this task's
diff; a broad add would pull that noise back in. If `git.commit_trailer`
is non-empty, append it as a trailer on the commit message. If it is
empty, omit it entirely — do not add an empty trailer line.

A project with no configured remote is a fully supported configuration —
local-only use, with `pr.enabled: false` and no external tracker, is a
first-class case this pipeline exists to serve, not a degraded one. Check
for a remote before pushing:

```bash
git remote
```

If that lists at least one remote, push the current branch to it:

```bash
git push -u origin HEAD
```

A push failure for any other reason (authentication, a rejected
non-fast-forward push, a network error) is a stop: report it in Step 7 and
do not proceed to Step 5, since there is no pull request to open against a
branch that never reached the remote.

If no remote is configured, skip the push entirely and record the skip in
Step 7's report — this is not a failure, and this phase's success path
must be reachable without a remote. Proceed to Step 5, which skips opening
a pull request for the same reason.

## Step 5 — Open the pull request

Skip this step entirely, and say so in Step 7's report, when any of the
following holds:

- the current branch is `git.base_branch`,
- `pr.enabled` is `false`,
- Step 4 found no remote configured and so had nothing to push against,
- a pull request for this branch already exists (check before creating
  one — for example, a query against the current branch's open pull
  requests that returns a result means one already exists).

Otherwise, open one against `git.base_branch`, titled with the task ID
and a short description of the change. Build the body from three parts:

- a short summary of what the task changed,
- the spec's `## Definition of Done` checklist, copied over with every
  item this task satisfies checked off,
- a short test plan naming the commands a reviewer runs to verify the
  change — `commands.test_all`, `commands.lint`, and anything else the
  spec's Definition of Done named as a check.

## Step 6 — Update tracker status

Open the file `core/trackers/<tracker.type>.md` selected in Step 0 and
call its `set_status` operation with the task ID and the phase `review` —
this ship step is the point in the pipeline where the tracker should show
the work as ready for review, not merely in progress.

Report the result exactly as the called tracker file specifies: `none`
mode reports the fixed line it names (`tracker: none, no status
update`); `linear` and `github` mode report the state or label the issue
moved to. A failed tracker call — a missing connection, an unmatched
state name, a missing `gh` authentication — is a stop, per that tracker
file's own rules. Do not treat a failed status update as something to
note quietly and move past: a silently failed update leaves the tracker
board showing stale information while the code has already shipped, which
is exactly what those rules exist to prevent.

## Step 7 — Report

Report, in order:

- Whether Step 2's lint ran, and its result — clean, or skipped because
  nothing in its scope changed.
- Whether Step 2's autofixes required a `commands.test_all` re-run, and
  the result if so — or an explicit statement that no fix could have
  changed behavior and none was needed.
- What Step 3 persisted to `paths.conventions` or phase memory, naming
  each item, or an explicit statement that nothing durable was found this
  task. Never leave this silent.
- Confirmation that the branch was pushed and what it carries, or that no
  remote was configured and the push was skipped.
- The pull request's URL, or which of Step 5's skip conditions applied.
- The tracker status result from Step 6.

Keep it to one line per item. Unlike the phases before it, this report is
read by a human deciding whether to merge, not by another phase resuming
from a handoff log, so it carries no fixed character cap — but it still
excludes anything that belongs in the handoff log instead: reasoning,
the full diff Step 3 reviewed, alternatives considered.

## Step 8 — Worktree cleanup hint

Close the report with the cleanup command for this task's worktree, and
state plainly that it is not to be run yet:

```bash
git worktree remove <paths.worktrees>/<task-id>
```

Substitute the configured `paths.worktrees` value and the actual task ID
before handing this to the user — this is a command for a person to run,
not one this phase executes itself. State explicitly that the worktree is
deliberately left in place until the pull request opened in Step 5
merges: review feedback on this task gets addressed inside this same
worktree, and removing it before the merge would throw away the one place
left to make those changes.
