# Adopt an existing spec instead of always writing one

## Context

The `task` flow already detects an existing spec: `core/flows/task.md:51`
reads "If a spec already exists at `paths.specs/<task-id>.md`, read it,
summarize it briefly, and skip to Step 3." That branch is the seam this
pipeline needs in order to accept a spec written anywhere else — by the
`plan` flow, by a person, or by a planning tool outside this pipeline — but
it is too narrow and too soft to carry that weight today. Four defects:

1. The test is prose ("already exists at"), not a mechanical command, so it
   invites judgment where the repository's strongest precedent forbids it.
   The greenfield test at `core/contracts/project-requirements.md:101` is the
   model: one command, quoted verbatim, with a binary decision rule.
2. The test reads the filesystem. Every phase runs inside a worktree created
   from `git.base_branch`, which contains only committed files, so a spec
   present on disk but untracked is adopted by `task` and then invisible to
   every phase that follows. `core/contracts/project-requirements.md:95`
   already establishes that a tracked-set test is the correct instrument.
3. It matches exactly one filename. A spec written by `plan` is named for its
   subject, never a task ID, by explicit instruction at
   `core/flows/plan.md:103`. So `core/flows/plan.md:16` — "`task` picks it
   up" — is false as implemented, and `core/flows/plan.md:151` sends the user
   down that path anyway.
4. Adopting performs no validation: no check of the adopted file against
   `core/contracts/spec-template.md`, and no report line distinguishing a
   spec written now from one adopted. `core/flows/task.md:188` promises
   "freshly written or already existed" but has no third case.

Separately, `core/trackers/none.md:38` and `core/flows/task.md:51` prescribe
opposite actions at the same moment. The tracker file requires that,
immediately before creating a spec, an existing file at that path means stop
and re-derive the ID. The task flow requires that the same condition means
adopt the file and skip ahead. Neither cites the other and which wins is
undefined. This change touches that exact path and must settle it.

## Approach

Define the detection once, in a contract, and have the flows cite it rather
than restate it — the structure `core/contracts/project-requirements.md`
uses for the greenfield test and that `core/flows/conventions.md:19`,
`core/flows/doctor.md:153` and `core/flows/init.md:38` all consume.

**1. Add `## Locating an existing spec` to `core/contracts/spec-template.md`.**
It defines two things. First, the tracked-set test, as a single command in a
fenced block, run from the repository root:

```bash
git ls-files -- <paths.specs>
```

Second, the resolution rule over that output, stated as a binary: a spec is
adoptable when exactly one tracked file under `paths.specs` is offered by the
caller or names the task ID; zero means write a fresh spec; more than one
means stop and ask which. The section states explicitly that an untracked
file on disk is not a spec for this purpose, and names the consequence — a
worktree cut from `git.base_branch` cannot see it. It forbids judgment in the
same terms `core/flows/doctor.md:156` uses: do not substitute a different
test, and do not decide by forming an impression of the file's contents. It
forecloses the near-misses by name: "it covers most of this", "it is a little
stale but close enough", "the subject looks related".

**2. Adopt by rename, never by widening the lookup.** When the adopted file
is not already `paths.specs/<task-id>.md`, `task` moves it there with
`git mv` before Step 3, so the file's history is preserved and every
downstream reader keeps working unchanged. `core/flows/resume.md:23`,
`core/flows/resume.md:56` and `core/phases/pipeline.md:52` all address the
spec as `paths.specs/<task-id>.md`; the rename is what keeps all three
correct without editing any of them.

**3. Validate on adopt.** Before Step 3, confirm the adopted file carries
every section the skeleton at `core/contracts/spec-template.md` requires. A
missing section is a stop, naming the section — not a silent proceed, and not
an automatic repair, because the review flow at `core/flows/review.md` is the
step that fixes a spec and it runs next.

**4. Settle the conflict with `core/trackers/none.md`.** The two rules govern
different moments and the fix is to say so in both files. The tracker's
backstop at `core/trackers/none.md:38` guards ID *derivation* — the free-text
branch that computes highest-plus-one — where a file appearing at the derived
path means another flow won a race, and stopping is correct. Adoption governs
an ID the caller *supplied*, where a file at that path is the spec for that
work. Add one sentence to each file naming the other case and pointing at the
file that owns it.

**5. Report which path was taken.** `core/flows/task.md:188` gains a third
case: written fresh, adopted at its own name, or adopted and renamed from
another name. The report states the source filename in the renamed case.
Both outcomes read identically in a bare report, and only one means the
design was settled with a person present — the argument
`core/flows/conventions.md:40` makes for the same requirement.

**6. Correct `core/flows/plan.md`.** Line 16's claim becomes true rather than
deleted. The naming instruction at `core/flows/plan.md:103` keeps the
subject-name rule and drops the "task writes its own spec under the tracker's
ID" sentence, which this change makes wrong. `core/flows/plan.md:151` gains
the fact that `task` will rename the file when it adopts it.

## Files to Modify

- `checks/manifest.txt` — add `## Locating an existing spec` to the
  `core/contracts/spec-template.md` row. Written before the section itself,
  so the structure check fails first.
- `core/contracts/spec-template.md` — new `## Locating an existing spec`
  section holding the command, the binary rule, the anti-judgment clause and
  the named near-misses.
- `core/flows/task.md` — Step 2's opening branch cites the new contract
  section, adopts by `git mv`, and validates against the skeleton. Step 7's
  report gains the third case. The opening paragraph at
  `core/flows/task.md:3` stops asserting the flow "writes a spec".
- `core/trackers/none.md` — one sentence distinguishing the derivation
  backstop from adoption.
- `core/flows/plan.md` — lines 103 and 151 corrected; line 16 left standing
  because it becomes true.
- `README.md` — the task row at line 23 and the plan row at line 24 in the
  commands table; the walkthrough at lines 253-269.

No adapter changes. `adapters/claude-code/commands/task.md:4` and
`adapters/cursor/commands/task.md:17` are pointers with no step-level
content, and this change adds no file under `core/phases/` or `core/flows/`,
so `checks/adapters-cover-core.sh` is unaffected.

## Definition of Done

- [ ] `core/contracts/spec-template.md` holds a `## Locating an existing
      spec` section whose test is a single command in a fenced block, and
      `checks/structure.sh` passes against the updated
      `checks/manifest.txt` row.
- [ ] The manifest row was committed before the section was written, per the
      rule at `checks/manifest.txt:2` and the convention at `CLAUDE.md:110`.
- [ ] `core/flows/task.md` Step 2 cites the contract section by its full
      `core/contracts/spec-template.md` path rather than restating the test,
      per `CLAUDE.md:22`.
- [ ] Adoption of a spec not named `<task-id>.md` uses `git mv`, and
      `core/flows/resume.md`, `core/phases/pipeline.md` and
      `core/flows/review.md` are unchanged by this task.
- [ ] `core/flows/task.md` Step 7 reports three distinct cases, and the
      renamed case names the source filename.
- [ ] `core/trackers/none.md` and `core/flows/task.md` each name the other's
      case; neither contradicts the other when read alone.
- [ ] `core/flows/plan.md:16` is true as implemented: a `plan`-written spec
      offered to `task` is adopted rather than redesigned.
- [ ] No file under `core/` names a harness or a third-party tool:
      `checks/core-is-neutral.sh` exits 0, per `CLAUDE.md:12`. The literal
      `CLAUDE.md` is a rejected token, so the conventions path is written as
      `paths.conventions`.
- [ ] `./tests/run.sh` exits 0 and the full `commands.lint` chain exits 0.
- [ ] Every `file:line` citation in `CLAUDE.md` that points into a file this
      task edited still resolves to the rule it cites, checked line by line
      per `core/phases/code-review.md:73`.
- [ ] Markdown prose under `core/` wraps at 77 columns and prose outside it
      at 80, per `CLAUDE.md:118` and `CLAUDE.md:120`.

## Out of Scope

- The mechanical test-protection gate. That is a sibling task, specified in
  `freeze-committed-tests.md`, and shares no file with this one.
- Naming any planning tool outside this pipeline in `core/`. The seam is
  generic there; the `README.md` may name a concrete example.
- Widening `core/flows/resume.md` or `core/phases/pipeline.md` to look a spec
  up by subject. The rename makes it unnecessary.
- The undefined commit message in `core/flows/review.md:133` for a spec-path
  input, the `set_status(start)` ordering at `core/flows/task.md:41`, the
  missing `### review` definition in `core/contracts/handoff-log.md`, the
  subtask-filename question against the ID scan at `core/trackers/none.md:22`,
  and the undefined title line for a spec with no task ID at
  `core/contracts/spec-template.md:14`. All found during planning, all real,
  none required by this change.

## Agent Handoff Log
<!-- Phases append findings here — see handoff-log.md -->
