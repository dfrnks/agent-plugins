# Resume here — state as of 2026-08-03

Work paused before the final fix wave. Everything below is what a future session
needs to continue without re-deriving it.

## Where things stand

All 16 tasks of `docs/plans/2026-08-03-agent-pipeline-implementation.md` are
implemented and individually reviewed. The package is complete in structure:

- `core/` — 6 contracts, 3 trackers, 5 phases, 6 flows, harness-neutral
- `adapters/claude-code/` and `adapters/cursor/` — thin pointers into `core/`
- `install.sh`, five checkers, a 27-case suite
- `README.md` and `docs/validation-2026-08-03.md`

Branch: `implement-pipeline`, 41 commits from `main`. All gates pass on the
current tree. **Nothing has been published; there is no git remote.**

The first real end-to-end run happened in task 16 and exposed five defects
(D1–D5), all since fixed. D1 was severe: the plugin loaded zero agents. Its fix
was verified by a real install reporting five agents loaded.

## What is left: the final review's fix wave

A whole-branch review returned **publishable after named fixes** — seven
blockers plus a "fix soon" list. None have been applied. This is the next
action.

### Blockers

**BP1 — the pipeline cannot start.** Neither `init` nor `conventions` commits
what it writes, so `.agent-pipeline/config.yaml` and the conventions file never
reach the worktree that `task` creates from the base branch. Every phase then
fails its configuration load, and the stop message tells the user to run `init`
in a project where `init` already ran. Verified empirically by the reviewer:
`git worktree add`, then list — empty.
*Fix:* `init` commits what it writes; `conventions` commits the conventions file
and checklist; `doctor` gains a tracked-in-git check on those rows.

**BP2 — `doctor` passes a conventions file with zero rules.** The threshold
counts "list items **or headings**" between the managed markers
(`core/contracts/project-requirements.md:41`, restated in `doctor.md:72` and
`conventions-template.md:32`), but `conventions` must emit all seven area
headings every run, including for areas where nothing was derived. Seven clears
a bar of five, so a project where nothing was derived reports `pass` and
`ready` — the exact silent pass the threshold exists to prevent.
`README.md:113` already states the intent correctly: "fewer than five **rules**".
*Fix:* count only rule lines — list items carrying a `file:line` citation.
Update all three files together.

**BP3 — `README.md:206` is false.** It claims `core/` never names a tool and
that this is mechanically enforced. `core/trackers/github.md` names `gh` six
times, `core/trackers/linear.md` names Linear throughout, and so do
`core/flows/doctor.md:52,55,124` and `core/contracts/project-requirements.md:23`.
A tracker file naming its own tracker is correct design — say that instead.

**BP4 — the README never gives invocation syntax, and the bare names collide
with built-ins.** The quickstart uses `init`, `conventions`, `doctor`, `task`,
`resume` unnamespaced; on one harness `/init`, `/doctor` and `/review` are
built-ins, so a user following the README literally invokes the wrong tools.
The design document has the namespaced answer at lines 209 and 224–226, but it
never reached the README — and it may be wrong for the second harness, since
`install.sh:81` places files unnamespaced. Check rather than assume.

**BP5 — every second-harness phase pointer is unreachable from where phases
run.** Those adapters use a project-relative path, but phases are dispatched
with the worktree as cwd, and the worktree has no such directory. Validation
confirmed the pointers resolve from the project root — the one place phases
never run. Compounding: 64 bare `core/…` cross-references inside `core/` and
nothing states how they resolve.

**BP6 — `resume`'s phase inference contradicts itself, and `end` leaves no
handoff entry.** `core/flows/resume.md:26-28` gives two rules that diverge once
phases repeat; validation produced exactly that case, where one rule yields
`code-review` and the other yields `end` — pushing and opening a pull request on
a fix the reviewer never saw. Worsened because `end.md`'s only handoff append is
conditional (`:130-133`), unlike its three siblings, contradicting
`handoff-log.md:39`, so a shipped task looks unshipped and `resume` re-runs it.

**BP7 — the documents misdescribe the repository's own evidence.**
`docs/validation-2026-08-03.md:301-304` says an earlier conclusion rested on
structural evidence and "that is disproved", but the task-14 report records a
live session listing all five agents and a dispatched agent confirming its
resolved path. That result was never addressed by the disproof, and task 16's
report misattributes the conclusion to the wrong task. The current layout is not
in question — but the old layout was live-dispatch tested and the new one was
not, and that asymmetry should be stated rather than papered over.

### Fix soon

- **Contract breaks on failure paths.** `test.md:200-204` hardcodes
  `Status: fail (red).` in a shape it calls exact, making `pipeline.md`'s only
  `BLOCKED` branch unreachable — the inherited source had `pass/fail`.
  `pipeline.md` has no result value for a failed `execute`, nor for the third
  end-phase stop. `SHIPPED` versus `STOPPED` keys on a field `end.md`'s report
  does not carry.
- **Re-entry disagreement:** `pipeline.md:162` permits re-entry into the phase
  `resume.md:74` forbids.
- **Remote assumptions:** `end.md:180` checks for any remote then pushes to
  `origin`; `resume.md:53-66` recovers a worktree only from a remote and
  declares "nothing to resume" for a local branch — in the local-only
  configuration `end.md:170-174` calls first-class.
- **Conventions-span leak:** `handoff-log.md:63`, `test.md:180`,
  `execute.md:266`, `code-review.md:236` and `review.md:111` route durable
  findings to the conventions file without naming the span, so an agent writes
  into the managed section and loses the rule on the next `conventions` run.
  Only `end.md:105-110` names it.
- `review.md` has no Step 0 despite the config contract's "without exception",
  while using three config keys.
- `init.md:44-54` never collects five always-mandatory keys, so its own closing
  `doctor` run fails on the config it just produced.
- **Checker false positives:** `checks/core-is-neutral.sh`'s tool list matches
  ordinary English words — `express`, `spring`, `rails`. Both checkers also
  write to fixed `/tmp` scratch paths; use `mktemp`.
- `install.sh:70` runs `mkdir -p` before the conflict check, so its "no changes
  were made" message and `README.md:41` are both false on a refusal.
- `README.md:170` claims both harnesses read from your clone — false for one of
  them, and contradicted eleven lines later. `install.sh:39` and the README
  disagree on the plugin install argument.
- **Undisclosed constraints the README must state:** the branch name must equal
  the task ID exactly, and three agents are pinned to a specific model, which is
  a cost implication.
- **Extraction leftovers:** `spec-template.md:93-101`'s status-enum checklist is
  a verbatim map of the originating project's layers, stated as a mandatory
  gate. `review-checklist-base.md:32-34` ships two unguarded house rules under a
  promise of universality. Multi-tenancy is assumed unhedged in
  `code-review.md:103`, `execute.md:186` and `review-checklist-base.md:23`,
  while `test.md:81` hedges it correctly — apply that hedge.
  `handoff-log.md:73`'s only worked example comes from the originating stack and
  its counter-example describes a behavior no phase has.
- `pipeline.md:65` offers a post-implementation heading as an example satisfying
  a pre-implementation gate — drop it.
- **Validation honesty gaps:** criterion 8 restates a different claim than the
  design asked; criterion 7 substituted a different interruption scenario
  without disclosing it; criterion 11's unqualified "met" rests on an inventory
  count the same document calls unreliable. Three report-level caveats were
  never propagated: the spurious first red suite, the single-build scope of the
  D1 claims, and the untested `--harness claude-code` refusal.

## What the review found genuinely good — preserve under later change

- **The test-protection contract and its tie-breaker** (`execute.md:144-161`,
  `code-review.md:124-133`). Validation planted four weakenings, produced a
  green suite and clean lint, and a fresh-context reviewer caught all four,
  named the files, and surfaced an unplanted finding. This is the thesis of the
  package and it is empirically demonstrated.
- **The discoveries-span design** (`conventions-template.md:75-120`) — placing
  an append-only writer's output outside a span another flow rewrites wholesale,
  making the guarantee structural rather than disciplinary.
- **`pipeline.md` Steps 1 and 2** — a portable worktree check that is a real
  conditional, and a review gate whose rationale explains why it looks redundant
  on the happy path.
- **The caps rationale** (`pipeline.md:206-215`) — a cap applies when the reader
  is another phase, not when the reader is a person.
- **Configuration discipline** — 17 keys, zero spelling variants across three
  directories and the README, every shared number reconciled.
- **The checker suite** — negative fixtures on both sides of every gate.

## Decisions already made, do not relitigate

- The pipeline directory in a consuming project is `.agent-pipeline/`, not a
  harness-named one, so neutrality is real rather than asserted.
- `core/` shows the shape; the README shows a realistic instance.
- The spec may name real harness files; `core/` may not — different audiences.
- Validation runs locally with no remote. The pull-request criterion is recorded
  as **not met**, honestly, and stays that way.
- Publication happens only after the fix wave lands and validation passes.

## How to resume

1. Read `.superpowers/sdd/2026-08-03-agent-pipeline-implementation/progress.md`
   — the full ledger, every task, ruling and deferred finding.
2. Apply the fix wave above as **one** dispatch, not one per finding.
3. Verify BP1, BP2, BP5 and BP6 **by execution**. Every serious defect on this
   project was found by running something and missed by reasoning about it.
4. Re-review the fix wave, then publish to `dfrnks/agent-pipeline`.

Note that `.import/` is gitignored and holds the porting source. If it is
missing, restage it — and keep the two source directories' files distinctly
named, because a filename collision there silently destroyed the source for four
tasks earlier in this project.
