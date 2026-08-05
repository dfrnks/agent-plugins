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

Read `.agent-pipeline/config.yaml`. Follow the fail-fast protocol in
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

Present the reviewed spec in full and the review findings from Step 3, then
ask whether to proceed to implementation.

**This is a hard stop, not a suggestion.** An answer other than proceeding —
however it is phrased — means stop here. Nothing past this point runs: no
worktree, no dispatch, no further tracker update. What remains is a
reviewed, committed spec and nothing else. This is the plan-only path, and
it is why no separate command exists for planning alone; asking here and
honoring the answer literally is what makes this flow serve both purposes
without a second entry point.

Only an explicit answer to proceed continues to Step 5.

## Step 5 — Create the worktree

First bring `git.base_branch` up to date, if this project has a remote at
all. A worktree branches from whatever the base branch points at locally,
and a local base branch is only as current as the last time someone
fetched — so on a machine that has not fetched in a week, every phase below
runs against week-old code. That failure is expensive precisely because it
is invisible: the tests pass, the review approves, and the conflict surfaces
in the pull request, long after the point where it could have been avoided.

Resolve the remote the way the end phase does — the name the repository
actually reports, preferring `origin` when several exist, never an assumed
one:

```bash
REMOTE=$(git remote | head -n 1)
```

If that names no remote, go straight to creating the worktree below: a
project with no remote is a fully supported configuration here, and there is
nothing for it to be out of date with.

With a remote, fetch the base branch and branch the worktree from the
fetched ref rather than from the local branch:

```bash
git fetch "$REMOTE" "<git.base_branch>"
git worktree add "<paths.worktrees>/<task-id>" -b "<task-id>" "$REMOTE/<git.base_branch>"
```

Branching from the remote-tracking ref, rather than resetting the local base
branch to match it, is deliberate: it leaves the user's own checkout exactly
as they left it. A flow that hard-resets a branch the user may have local
commits on destroys work that was never this flow's to touch.

If the fetch fails — no network, or an authentication prompt with nobody
there to answer it — do not stop. Create the worktree from the local base
branch instead, and **say in Step 7's report that the base branch could not
be refreshed, naming the local commit it was based on**. Working offline is
legitimate; working from silently stale code is not, and the only difference
between the two is whether the report says so.

Without a remote, or after a failed fetch, branch from the local base
branch:

```bash
git worktree add "<paths.worktrees>/<task-id>" -b "<task-id>" "<git.base_branch>"
```

If a worktree already exists at that path, reuse it rather than recreating
it. If it holds uncommitted work this flow did not just create, stop and
ask the user before touching anything further — it may belong to another
task started in parallel.

If `git.worktree_setup` is configured, this step does not run it — that is
the pipeline's own Step 3, run inside the worktree in Step 6 below, since it
depends on the worktree existing first.

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
- The review outcome from Step 3, in brief.
- Whether the gate in Step 4 was passed or stopped here — and if stopped,
  that the spec is reviewed, committed, and ready for a future run of this
  flow (or of `resume`) to pick up where this one left off.
- On a stop, nothing further to report.
- Past the gate: the worktree path from Step 5, and the pipeline's own
  report from Step 6 in full — result, branch, pull request URL if any, and
  the reason given for any result other than shipped.
- Whether the base branch was refreshed in Step 5. Say so only when it was
  **not** — no remote configured, or a fetch that failed — naming which of
  the two applied and the local commit the worktree was based on instead. A
  run that fetched successfully needs no line here; a run that did not is
  the one case where every result below it was produced against code that
  may already be behind, and the reader cannot tell from any other field.
