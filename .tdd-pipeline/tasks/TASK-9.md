# TASK-9 — Adopt an existing spec instead of always writing one

## Context

The `task` flow already detects an existing spec: `core/flows/task.md:51`
reads "If a spec already exists at `paths.specs/<task-id>.md`, read it,
summarize it briefly, and skip to Step 3." That branch is the seam this
pipeline needs in order to accept a spec written anywhere else — by the
`plan` flow, by a person, or by a planning tool outside this pipeline — but
it cannot carry that weight today. Five defects:

1. There is no input channel. `core/flows/task.md:12` admits two argument
   forms, a tracker identifier or a free-text description, and Step 1 at
   `core/flows/task.md:32` forwards the argument verbatim to the tracker's
   `resolve_or_create` with no interception. A spec path handed to `task`
   falls to the free-text branch — `core/trackers/github.md:22` opens an
   issue titled with the path. So the resolved ID is always either one the
   caller typed or one freshly minted, and in the second case
   `paths.specs/<task-id>.md` cannot exist by construction. The
   subject-named spec is unreachable. `core/flows/review.md:11` already
   admits "a task ID (for example `TASK-1`) or a spec path"; `task` does not.
2. The test is prose ("already exists at"), not a mechanical command, so it
   invites judgment where the repository's strongest precedent forbids it.
   `core/contracts/project-requirements.md:110` is the model: a bolded
   binary verdict read straight off a command's raw output.
3. The test reads the filesystem. Every phase runs inside a worktree created
   from `git.base_branch`, which contains only committed files, so a spec
   present on disk but untracked is adopted and then invisible to every
   phase that follows.
4. It matches exactly one filename. A spec written by `plan` is named for its
   subject, by explicit instruction at `core/flows/plan.md:103`. So
   `core/flows/plan.md:16` — "`task` picks it up" — is false as implemented,
   and `core/flows/plan.md:152` recommends `task` as the next step anyway.
5. Adopting validates nothing and reports nothing distinguishable.
   `core/flows/task.md:188` promises "freshly written or already existed",
   which cannot express where an adopted spec came from.

Separately, `core/trackers/none.md:38` and `core/flows/task.md:51` prescribe
opposite actions when a file exists at a spec path — stop and re-derive, or
adopt and skip. Neither cites the other. This change touches that path and
must settle it.

## Approach

Define the detection once, in the contract that already owns `paths.specs`
as an artifact and already declares itself the file flows cite instead of
restating — `core/contracts/project-requirements.md:3`. That contract holds
the only executable test in `core/contracts/` today, at
`core/contracts/project-requirements.md:100`, and the greenfield section
this design copies is its neighbour.

**1. Add `## Locating an existing spec` to
`core/contracts/project-requirements.md`,** and amend that file's opening
paragraph at `core/contracts/project-requirements.md:7` to forward-declare
it, the way the greenfield exception is forward-declared there today.

The section defines two commands, each read as empty-or-nothing so that the
raw output is the verdict with no filtering step in between. For a resolved
task ID:

```bash
git ls-files -- <paths.specs>/<task-id>.md
```

Empty output means no spec exists for this task; write one. Any output means
a spec exists; adopt it. For a spec path the caller supplied:

```bash
git ls-files --error-unmatch <path>
```

A non-zero exit means the file is untracked, which is not a spec for this
purpose — a worktree cut from `git.base_branch` cannot see it. The section
states that consequence explicitly, and instructs the flow to stop and say
the file must be committed first rather than adopting it.

The section carries an error-asymmetry subsection, in the shape of
`core/contracts/project-requirements.md:114`: adopting a stale or near-miss
spec makes the pipeline implement the wrong design while every report reads
green, and writing a duplicate spec is noisy, visible and cheap. The test is
tuned toward the second. It forbids judgment in the terms
`core/flows/doctor.md:157` uses — do not substitute a different test, do not
decide by forming an impression of the file's contents — and forecloses the
near-misses by name: "it covers most of this", "it is a little stale but
close enough", "the subject looks related".

It closes with a "when it ends" subsection, in the shape of
`core/contracts/project-requirements.md:138`: once a spec is adopted and
sits at `paths.specs/<task-id>.md`, every later run of `task` against that
ID takes the ordinary already-exists branch. Nothing is persisted and no
marker records that adoption happened; the file's location is the whole
state.

**2. Give `task` the missing argument form.** `core/flows/task.md:12` gains a
third form, worded after `core/flows/review.md:11`: a path to a tracked spec
file under `paths.specs`. Step 1 gains a branch that runs **before**
`resolve_or_create`: when the argument is such a path, read the spec's title
line and pass that title as the free-text description to `resolve_or_create`,
so the tracker item is created with a meaningful title rather than a
filesystem path. The task ID comes back from the tracker as it always does.
No tracker file changes; the interception is entirely in `core/flows/task.md`.

**3. Adopt by rename, and commit the rename.** When the adopted file is not
already at `paths.specs/<task-id>.md`, move it there and commit in the same
step:

```bash
git mv <source path> <paths.specs>/<task-id>.md
git commit -m "<task-id>: adopt spec"
```

The commit is not optional and is the reason the rename is safe: `git mv`
only stages, and an uncommitted rename is invisible from the worktree Step 5
creates — the same defect this change exists to fix. `git.commit_trailer` is
appended when non-empty.

`git mv` fails when the destination already exists. That case cannot arise
on this path: a file at `paths.specs/<task-id>.md` means the already-exists
branch was taken and no rename is needed. If both a caller-supplied path and
`paths.specs/<task-id>.md` are tracked, they are two candidate specs — stop
and ask which, rather than choosing.

Two promises in `core/flows/task.md` become false and are amended in the
same change. `core/flows/task.md:7` says everything before the gate "writes
exactly one file — the spec"; a rename deletes one path and creates another.
`core/flows/task.md:113` promises that declining at the gate leaves "a
reviewed, committed spec and nothing else"; after an adoption it also leaves
the source file moved. Both sentences state the adoption case.

**4. Validate on adopt.** Before Step 3, confirm the adopted file carries
every section the skeleton at `core/contracts/spec-template.md:11` requires.
A missing section is a stop naming the section — not a silent proceed, and
not an automatic repair, because `core/flows/review.md` runs next and owns
fixing a spec.

**5. Settle the conflict with `core/trackers/none.md` by path, not by
provenance.** The backstop at `core/trackers/none.md:38` guards the path of a
**newly derived** ID: the free-text branch computes highest-plus-one, and a
file appearing there means another flow won the race, so stopping and
re-deriving is correct and stays unchanged. Adoption governs a path the
caller named, or an ID the caller supplied — neither of which can collide
with an ID just derived to be unused. Add one sentence to each file naming
the other case and pointing at the file that owns it.

This is why the plan-to-task handoff must travel the new argument form from
item 2 rather than free text. Free text reaches the derivation branch, where
stopping is correct; a spec path reaches the interception, where adopting is
correct.

**6. Report four states, not two.** `core/flows/task.md:188` reports: written
fresh; adopted at `paths.specs/<task-id>.md`; adopted and renamed, naming the
source path. Each adopted case also reports whether the spec already carried
a `### review` entry in its handoff log, since that is what distinguishes a
spec this pipeline already reviewed from one that has never been through the
gate — and the two are otherwise indistinguishable in a report.

**7. Correct `core/flows/plan.md`.** Line 16's claim becomes true rather than
deleted. `core/flows/plan.md:105` drops the "task writes its own spec under
the tracker's ID" sentence, which this change makes wrong, and keeps the
subject-name instruction at `core/flows/plan.md:103`. The next-step bullet at
`core/flows/plan.md:152` names the spec path as the argument to pass to
`task`, which is what makes the handoff work.

**8. Point `core/flows/review.md:13` at the contract.** Its zero-argument
fallback lists `paths.specs` from the filesystem — the instrument defect 3
rejects. One clause citing
`core/contracts/project-requirements.md`'s new section makes the contract the
single owner of locating a spec, which is what defining it once means.

**9. `## Step 2 — Write the spec` is pinned by `checks/manifest.txt:17` and
must not be renamed.** `checks/structure.sh:18` matches the heading as a
fixed string; softening it to reflect adoption fails
`tests/run.sh:65`. The step's prose changes; its title does not.

## Files to Modify

- `checks/manifest.txt` — add `## Locating an existing spec` to the
  `core/contracts/project-requirements.md` row at `checks/manifest.txt:4`.
  Committed before the section is written.
- `tests/fixtures/manifest-spec-location.txt` — a manifest fixture holding
  the `core/contracts/project-requirements.md` row with the new heading.
  This is what makes a failing test possible for a prose change: it exits 1
  until the section exists.
- `tests/run.sh` — one `assert_exit 0` invoking `checks/structure.sh` against
  that fixture, appended after `tests/run.sh:76` so the citations at
  `CLAUDE.md:100`, `CLAUDE.md:104` and `CLAUDE.md:106` keep resolving.
- `core/contracts/project-requirements.md` — the new section, its
  error-asymmetry and when-it-ends subsections, and the amended opening
  paragraph.
- `core/flows/task.md` — the argument paragraph at `core/flows/task.md:12`;
  the read-only promise at `core/flows/task.md:7`; the gate-decline promise
  at `core/flows/task.md:113`; Step 1's pre-tracker interception; Step 2's
  prose, title unchanged; Step 3's parenthetical at `core/flows/task.md:89`,
  which names two cases and must name three; Step 7's report at
  `core/flows/task.md:188`. Also `core/flows/task.md:4`, which asserts the
  flow "writes a spec for it", and `core/flows/task.md:52`, whose rationale
  "the item was already designed in an earlier run of this flow" stops being
  the only reason a spec can be there.
- `core/trackers/none.md` — one sentence distinguishing the derivation
  backstop from adoption.
- `core/flows/review.md` — one clause at `core/flows/review.md:13` citing the
  contract section.
- `core/flows/plan.md` — lines 105 and 152; line 16 left standing because it
  becomes true.
- `README.md` — the task row at `README.md:23`, the plan row at
  `README.md:24`, and the walkthrough at `README.md:253`.
- `CLAUDE.md` — only if the README edits change the number of lines above
  `README.md:356`, which `CLAUDE.md:26` cites. Correcting the citation by
  hand is safe: the conventions flow regenerates its managed section
  wholesale on its next run and will re-derive the right line.

No adapter changes. `adapters/claude-code/commands/task.md:4` and
`adapters/cursor/commands/task.md:17` are pointers with no step-level
content, and `checks/adapters-cover-core.sh:34` enumerates only existing
files under `core/phases/` and `core/flows/`, none of which are added.

## Definition of Done

- [ ] `checks/structure.sh tests/fixtures/manifest-spec-location.txt` exits 1
      before the section is written and 0 after, and that assertion is in
      `tests/run.sh`. This is the task's red-to-green cycle.
- [ ] `git log --oneline --reverse -- checks/manifest.txt
      core/contracts/project-requirements.md` shows the manifest row
      committed in an earlier commit than the section, per
      `checks/manifest.txt:2` and `CLAUDE.md:110`.
- [ ] `git ls-files -- <paths.specs>/<task-id>.md` and
      `git ls-files --error-unmatch <path>` both appear in
      `core/contracts/project-requirements.md` inside fenced blocks, and the
      section states a bolded binary verdict for each.
- [ ] The section carries an error-asymmetry subsection and a when-it-ends
      subsection, matching `core/contracts/project-requirements.md:114` and
      `core/contracts/project-requirements.md:138` in role.
- [ ] `core/flows/task.md:12` admits a spec path as a third argument form,
      and Step 1 intercepts it before `resolve_or_create`. Verify by reading
      Step 1: a spec path must never reach a tracker as free text.
- [ ] `grep -n 'git mv' core/flows/task.md` shows the rename, and the same
      block shows a `git commit`. An adopted spec is committed before Step 5
      creates the worktree, per `CLAUDE.md:91`.
- [ ] `core/flows/task.md` Step 2 states the validation from Approach item 4,
      naming the stop condition.
- [ ] `core/flows/task.md:7` and `core/flows/task.md:113` both state the
      adoption case; neither still promises exactly one file written or
      nothing left behind.
- [ ] `git diff --name-only main...HEAD -- core/flows/resume.md
      core/phases/pipeline.md core/phases/test.md core/phases/execute.md
      core/phases/code-review.md core/phases/end.md` is empty: the rename is
      what keeps all six readers of `paths.specs/<task-id>.md` correct.
- [ ] `grep -c '## Step 2 — Write the spec' core/flows/task.md` returns 1.
      The heading is pinned by `checks/manifest.txt:17`.
- [ ] `core/flows/task.md` Step 7 reports three cases and, for each adopted
      case, whether a `### review` entry was already present.
- [ ] `core/trackers/none.md` and `core/flows/task.md` each name the other's
      case, and `core/trackers/none.md:38` still says stop for a newly
      derived ID.
- [ ] `core/flows/plan.md:16` is true as implemented, and
      `core/flows/plan.md:152` names the spec path as the argument to `task`.
- [ ] `README.md` rows 23 and 24 and the walkthrough at `README.md:253` state
      that `task` can adopt a spec.
- [ ] Every `CLAUDE.md` citation into a file this task edited still resolves,
      re-derived with `sed -n '<n>p' <file>` for each, per the rule at
      `core/phases/code-review.md:75`.
- [ ] `checks/core-is-neutral.sh` exits 0. The literal `CLAUDE.md` is a
      rejected token at `checks/core-is-neutral.sh:11`, so the conventions
      path is written as `paths.conventions` everywhere in `core/`.
- [ ] `./tests/run.sh` exits 0 and the full `commands.lint` chain exits 0.
- [ ] Markdown prose under `core/` wraps at 77 columns and prose outside it
      at 80, per `CLAUDE.md:118` and `CLAUDE.md:120`.

## Out of Scope

- The mechanical test-protection gate, specified in
  `freeze-committed-tests.md`. The two tasks **do** share
  `checks/manifest.txt` and `README.md`, and the sibling edits
  `README.md:356` while this task edits lines above it. This task lands
  first; the sibling rebases onto it and re-derives its own line citations.
- Naming any planning tool outside this pipeline in `core/`. The seam is
  generic there; `README.md` may name a concrete example, and
  `checks/core-is-neutral.sh:8` scans `core/` only.
- Widening `core/flows/resume.md` or `core/phases/pipeline.md` to look a spec
  up by subject. The rename makes it unnecessary.
- The undefined commit message in `core/flows/review.md:133` for a spec-path
  input, the `set_status(start)` ordering at `core/flows/task.md:41`, the
  missing `### review` definition in `core/contracts/handoff-log.md`, the
  subtask-filename question against the ID scan at `core/trackers/none.md:22`,
  and the undefined title line for a spec with no task ID at
  `core/contracts/spec-template.md:14`.

## Agent Handoff Log
<!-- Phases append findings here — see handoff-log.md -->

### review (2026-08-24)

- **Blocking defect, confirmed by two independent readers: the change had no
  input channel.** `core/flows/task.md:12` admits only a tracker identifier
  or free text, and Step 1 forwards the argument verbatim to
  `resolve_or_create`, so a spec path handed to `task` in `github` mode opens
  an issue titled with the path (`core/trackers/github.md:22`). The resolved
  ID was therefore always either typed by the caller or freshly minted, and a
  subject-named spec was unreachable in both cases — the draft added no
  reachable behaviour. Fixed: Approach item 2 adds a third argument form
  worded after `core/flows/review.md:11`, plus a Step 1 branch that
  intercepts before the tracker. Files to Modify gained the argument
  paragraph and Step 1, neither of which the draft listed.
- **The draft's own fix reintroduced the defect it fixes.** `git mv` stages
  but does not commit, and the commit block at `core/flows/task.md:75` sits
  in the fresh-write branch, so an adopted-and-renamed spec was never
  committed and would be invisible from the worktree Step 5 creates —
  defect 3 of this spec's own Context. Reproduced in a scratch repository by
  the reviewing subagent. Fixed: the rename and its commit are one block,
  with a defined message, and the DoD requires both.
- **The `core/trackers/none.md` conflict was resolved in the wrong
  direction.** The draft split the two cases by who supplied the ID. But
  `core/flows/plan.md:29` states `plan` resolves no tracker, so a
  plan-to-task handoff arrives as free text — the derivation branch, where
  `core/trackers/none.md:38` correctly says stop. The headline use case was
  unreachable for a second, independent reason. Fixed: the split is now by
  path, and Approach item 5 states why the handoff must travel the new
  argument form rather than free text.
- **The contract was the wrong one.** The draft put the new section in
  `core/contracts/spec-template.md`, whose stated scope at
  `core/contracts/spec-template.md:7` is the section skeleton and
  completeness rules — locating a file is neither, and that file never
  mentions `paths.specs`, git, or worktrees. The requirements contract
  already owns `paths.specs` as an artifact, already declares itself the file
  flows cite instead of restating, and holds the only executable test in
  `core/contracts/`. Moved, and the manifest row changed from
  `checks/manifest.txt:5` to `checks/manifest.txt:4`.
- **The detection rule was a trinary with an undefined predicate, not a
  binary.** `git ls-files -- <paths.specs>` returns every spec ever written,
  so the verdict needed a filtering step the greenfield precedent
  deliberately pushes inside the command. "Offered by the caller" was
  load-bearing and never defined. Fixed: two commands, each empty-or-nothing,
  read straight off raw output.
- **Three properties of the invoked precedent were missing.** No
  error-asymmetry subsection (`core/contracts/project-requirements.md:114`),
  no when-it-ends subsection
  (`core/contracts/project-requirements.md:138`), and no amendment to the
  host contract's opening paragraph, which the greenfield section has at
  `core/contracts/project-requirements.md:7`. All three added.
- **The report cases collapsed the distinction they cited.** "Adopted at its
  own name" covered both a spec this flow wrote yesterday and one a person
  wrote by hand. Fixed: each adopted case also reports whether a `### review`
  entry was already present, which is the actual discriminator.
- **`## Step 2 — Write the spec` is pinned by `checks/manifest.txt:17`** and
  `checks/structure.sh:18` matches it as a fixed string. The draft implied
  softening it. Approach item 9 now forbids renaming it explicitly.
- **The Definition of Done was seven-elevenths unfalsifiable**, its only
  strong item was satisfiable by a substring, and it had no item at all for
  the validation step in Approach item 4, for `README.md`, or for
  `core/flows/task.md:4`. Item 10 cited `core/phases/code-review.md:73`,
  which is the reverse rule — verifying the handoff log's Conventions
  Applied block against the conventions file, not verifying that file's own
  citations. Rebuilt with executable commands where they exist, and the
  citation corrected to `core/phases/code-review.md:75`.
- **The Out of Scope claim that the siblings share no file was false.** Both
  list `checks/manifest.txt` and `README.md`, and the sibling edits
  `README.md:356` while this task edits lines above it. Corrected, with an
  explicit landing order.
- **Four citations were wrong.** `core/flows/plan.md:151` is the split bullet,
  not the next-step bullet (152); "writes a spec for it" is at
  `core/flows/task.md:4`, not line 3; the sentence Approach item 7 removes is
  at `core/flows/plan.md:105`, not 103; the anti-judgment terms are at
  `core/flows/doctor.md:157`, not 156. All corrected and re-verified line by
  line before rewriting.
- **`core/flows/task.md:7` and `core/flows/task.md:113` were unexamined.**
  Both promise things adoption falsifies — exactly one file written, and
  nothing left behind when the gate is declined. Both now in scope.
- **Consumers were undercounted.** The draft named three readers of
  `paths.specs/<task-id>.md`; there are eight. The DoD now pins six of them
  as unchanged with a single `git diff --name-only` command.
- **`core/flows/review.md:13` was left contradicting the new contract** — it
  locates a spec by listing the filesystem, the instrument this change
  rejects — and the draft's DoD required that file stay unchanged, converting
  an oversight into a commitment. Now it gains one clause citing the
  contract, and the DoD no longer forbids it.
- **Hard blocker, external API schema: not applicable.** This task calls no
  external API. Nothing in the spec describes a request or response shape.
- **Hard blocker, internal infrastructure: checked and cleared.** Every claim
  about existing behaviour was verified by reading the cited file at the
  cited line, not by searching for a name this spec invented. Verified
  against the working tree at commit 33ff66a: `core/flows/task.md` lines 4,
  7, 12, 32, 41, 51, 52, 89, 113, 188; `core/flows/plan.md` lines 16, 29,
  103, 105, 152; `core/trackers/none.md` lines 22, 38;
  `core/trackers/github.md:22`; `core/flows/review.md` lines 11, 13, 133;
  `core/contracts/project-requirements.md` lines 3, 7, 100, 110, 114, 138;
  `core/contracts/spec-template.md` lines 7, 11, 14; `core/flows/doctor.md:157`;
  `core/phases/code-review.md:75`; `checks/manifest.txt` lines 2, 4, 17;
  `checks/structure.sh:18`; `checks/core-is-neutral.sh` lines 8, 11;
  `checks/adapters-cover-core.sh:34`; `tests/run.sh` lines 65, 76.
- **Assumption invalidated: `git mv` has no precedent in `core/`.** An
  exhaustive grep found `git add`, `git commit`, `git worktree`, `git remote`,
  `git ls-files`, `git rev-parse`, `git fetch`, `git rev-list`, `git status`,
  `git push` and `git branch` — and no move or rename of a tracked file
  anywhere. The mechanic is kept, because widening eight readers is worse
  than moving one file, but it is now stated as a committed, single-block
  operation with its collision case defined rather than a one-clause aside.
- **Not split.** The task grew during this review — the argument form and the
  Step 1 interception are new scope — but every part is one mechanism, and
  splitting the input channel from the detection would produce a first half
  that changes nothing observable.
- → Escalated to conventions: two durable facts about this repository's
  gates, recorded in the discoveries span of the conventions file.

