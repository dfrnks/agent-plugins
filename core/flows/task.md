# Flow: task

The single entry point for starting work. `task` resolves what the work item
actually is, writes a spec for it, reviews that spec, stops at a hard
confirmation gate, and only past that gate creates an isolated worktree and
dispatches the pipeline against it. Everything before the gate is read-only
with respect to source code: it explores the codebase and writes exactly one
file — the spec — committed to the base branch, where specs belong. The
local repository never leaves the base branch; every change to source or
test code happens afterward, inside the worktree this flow creates in Step 5.

The argument is either a tracker identifier (for example `TASK-1`) or a
free-text description of new work. Extra context supplied alongside either
form — technical constraints, an approach already in mind — carries forward
into Step 2. If no argument is given, ask a single open-ended question: what
work should this start, an identifier or a description.

## Step 0 — Load configuration

Read `.tdd-pipeline/config.yaml`. Follow the fail-fast protocol in
`core/contracts/pipeline-config.md`: stop and name the exact missing key if
the file or a key this flow needs is absent. This flow needs `tracker.type`,
`tracker.prefix`, `paths.specs`, `paths.worktrees`, `paths.conventions`, and
`git.base_branch`. `tracker.type` selects which file among
`core/trackers/none.md`, `core/trackers/linear.md`, and `core/trackers/github.md`
governs Step 1; that file may require further keys of its own
(`tracker.team`, `tracker.states`), and an absent one of those follows the
same fail-fast rule.

## Step 1 — Resolve the item

Open the file `core/trackers/<tracker.type>.md` selected in Step 0 and call
its `resolve_or_create` operation with the argument (or the question's
answer, if none was given). Follow that file's own rules for telling an
existing identifier from a free-text description, and for what to do with
each case — this flow does not re-implement that logic, only calls it.

The operation returns a task ID. Use it as-is for the branch name in Step 5
and the spec filename in Step 2; do not reconstruct or reformat it.

Then call that same tracker file's `set_status` operation with the task ID
and the phase `start`, so the tracker reflects that work has begun before
any spec exists yet. Report the result exactly as that file specifies. In
`linear` mode an unmatched state name stops the flow; in `github` mode a
missing `gh` authentication or a malformed `tracker.states` block stops it;
in `none` mode the operation cannot fail. Whichever applies, never proceed
past a stop with tracker state left stale.

## Step 2 — Write the spec

If a spec already exists at `paths.specs/<task-id>.md`, read it, summarize it
briefly, and skip to Step 3 — the item was already designed in an earlier
run of this flow, and Step 2 does not run twice against the same task.

Otherwise, explore before asking anything: dispatch subagents in parallel to
investigate the areas this item touches — what already exists in this area
of the codebase and what patterns are established, an analogous feature
solved before and what it reused, and which other parts of the project the
change would affect. Read whatever the exploration surfaces closely enough
to ask informed questions next, rather than treating the subagents' reports
as a substitute for understanding them.

Then ask the user about scope, approach preferences, constraints, and
affected user roles — in a single grouped question, not a decision tree that
funnels through them one at a time. Wait for the answer before drafting
anything.

Draft the spec following the skeleton in `core/contracts/spec-template.md`
exactly: every section present, every file, function, and data source named
explicitly, every Definition of Done item referencing the convention it
enforces. Apply the completeness rules in that same contract, including its
two hard blockers, while drafting — do not defer that work entirely to
Step 3's review pass.

Write the file to `paths.specs/<task-id>.md`. Commit it to `git.base_branch`
— the branch the local repository is already on, and stays on through this
entire step:

```bash
git add <spec file>
git commit -m "<task-id>: add spec"
```

If `git.commit_trailer` is non-empty, append it as a trailer on the commit
message. If it is empty, omit it entirely.

## Step 3 — Review the spec

Run `core/flows/review.md` inline against the spec just written (or just
loaded, if Step 2 skipped), passing the task ID. That flow explores the
codebase independently, critiques the spec against its own completeness
rules, fixes what it finds directly in the spec file, and records a
`### review` entry in the handoff log. Carry its findings forward into
Step 4 — do not summarize them away.

## Step 4 — Gate

First re-read `paths.specs/<task-id>.md` and confirm its `## Agent Handoff
Log` carries a `review` entry, matched the way `core/phases/pipeline.md`
Step 2 matches it. Step 3 having reported success is not evidence — a review
that stops before its own Step 5 fixes the spec without recording that it
did, and this flow cannot tell that apart from one that finished.

If the entry is absent, run `core/flows/review.md` against this spec once
more and read the file again. Still absent: stop here, name the spec path,
and direct the user to run the review flow against this task ID. No gate, no
worktree, no offer to proceed anyway. Twice is the bound.

Then present the reviewed spec in full and the review findings from Step 3,
and ask whether to proceed to implementation.

**This is a hard stop, not a suggestion.** An answer other than proceeding —
however it is phrased — means stop here. Nothing past this point runs: no
worktree, no dispatch, no further tracker update. What remains is a
reviewed, committed spec and nothing else. This is the plan-only path, and
it is why no separate command exists for planning alone; asking here and
honoring the answer literally is what makes this flow serve both purposes
without a second entry point.

Only an explicit answer to proceed continues to Step 5.

## Step 5 — Create the worktree

Bring `git.base_branch` up to date first, if this project has a remote. A
worktree is only as current as the last fetch, and stale code fails in the
pull request — long after the point where it was cheap to prevent.

Resolve the remote the way the end phase does, preferring `origin` when
several exist, never an assumed name:

```bash
REMOTE=$(git remote | head -n 1)
```

With no remote, skip to the second worktree command below. A project without
one is fully supported, and has nothing to be out of date with.

Otherwise fetch, then ask which of the two refs to branch from:

```bash
git fetch "$REMOTE" "<git.base_branch>"
git rev-list --left-right --count "$REMOTE/<git.base_branch>...<git.base_branch>"
```

The second number counts commits the local base branch has that the remote
lacks. Branch from the remote-tracking ref **only when it is zero**:

```bash
git worktree add --no-track "<paths.worktrees>/<task-id>" -b "<task-id>" "$REMOTE/<git.base_branch>"
```

`--no-track` is load-bearing. Branching from a remote-tracking ref without it
sets the task branch's upstream to the *base* branch, and git then answers a
bare `git push` by suggesting `git push origin HEAD:<git.base_branch>` —
pushing the task's commits straight onto the base branch, no pull request and
no review. With it, the branch has no upstream and git suggests
`git push --set-upstream origin <task-id>`, which is what `end` wants.

In every other case — no remote, a non-zero second number, or a fetch that
failed, which is not a reason to stop — branch from the local base branch,
and name which case applied in Step 7's report:

```bash
git worktree add "<paths.worktrees>/<task-id>" -b "<task-id>" "<git.base_branch>"
```

Those unpushed commits are the user's own work, and routinely include
`.tdd-pipeline/config.yaml` itself: branching from the remote there yields a
worktree where every phase fails at its Step 0, in a project `doctor` calls
ready. Never reset the base branch to match the remote — leave the user's
checkout as they left it.

If a worktree already exists at that path, reuse it. If it holds uncommitted
work this flow did not just create, stop and ask the user before touching
anything further — it may belong to a task started in parallel.

Then mirror any untracked scaffolding into the worktree, following
`core/contracts/untracked-scaffolding.md`. A project that keeps its
configuration or its specs out of git has none of them in a fresh worktree,
and every phase would stop at its first step; the contract also governs
copying the spec back as each phase writes to it. Name in Step 7's report
which paths were mirrored, or that none were.

`git.worktree_setup` does not run here. It is the pipeline's own Step 3, run
inside the worktree in Step 6 below.

## Step 6 — Run the pipeline

Dispatch `core/phases/pipeline.md` as a subagent whose working directory is
the worktree created in Step 5, passing the task ID. That phase re-verifies
on its own that the working directory is a worktree, that the branch equals
the task ID, and that the spec's handoff log carries a `review` entry —
every one of those is already true by construction after Steps 1 through 5,
but the phase checks anyway because it can be reached other ways than this
flow, and does not trust a caller's word for its own preconditions.

## Step 7 — Report

Return, in order:

- The task ID resolved in Step 1, and the tracker's `start` status result.
- The spec path, and whether it was freshly written or already existed.
- The review outcome from Step 3, in brief, and whether Step 4 had to re-run
  the review to obtain a handoff log entry.
- How Step 4 ended: gate passed, user declined, or gate never presented for
  want of a `review` entry. Name which — "stopped at the gate" alone reads as
  the user's decision, and the third case is not that. On either stop, the
  spec is reviewed and committed, ready for a future run of this flow (or of
  `resume`) to pick up where this one left off.
- On a stop, nothing further to report.
- Past the gate: the worktree path from Step 5, and the pipeline's own
  report from Step 6 in full — result, branch, pull request URL if any, and
  the reason given for any result other than shipped.
- Which ref Step 5 branched from, whenever it was not the remote-tracking
  one — no remote configured, a fetch that failed, or a local base branch
  holding commits the remote does not have — naming which of the three
  applied and the local commit the worktree was based on. A run that
  branched from the fetched ref needs no line here. Any other run produced
  every result below it against code that may already be behind, or against
  local work that was never pushed, and no other field in this report
  reveals which.
