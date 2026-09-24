# Flow: conventions

Derive the project's own rules from the codebase and write them into
`paths.conventions` — the file the execute and code-review phases read at the
start of every run and trust completely for anything project-specific.
Neither phase carries an inline rule about naming, layering, or error
handling; both delegate that entirely to whatever this flow writes.

That delegation is why this flow cannot behave like `init`'s detection pass:
a wrong guess here does not stop for a human to catch it — it becomes an
enforced rule the moment the file is written.

Takes no required argument; run standalone, or dispatched from `init`'s
Step 5. Reads `paths.review_checklist` from the configuration, if this is a
re-run, and `paths.conventions` in every case — resolve both from
`.tdd-pipeline/config.yaml` before Step 1, following the fail-fast protocol
in `core/contracts/pipeline-config.md`.

## Greenfield projects

Before Step 1, run the greenfield test from
`core/contracts/project-requirements.md`'s `## Greenfield projects` section.
If it reports greenfield, this flow takes a shorter path and says so:

- **Skip Step 1 entirely.** Do not dispatch the exploration subagents. There
  is no file for them to cite, so each would return nothing or something it
  invented — better not to create the pressure than to rely on Step 2 to
  resist it.
- **Skip Steps 2 and 3.** With no occurrences there is nothing to weigh
  against the rule bar and nothing to confirm.
- **Run Step 4 as written**, with no accepted rules — all seven headings,
  each followed by its "no rule derived" line, written between the markers
  and committed exactly as that step specifies. The commit is the point: the
  phases read this file from inside a worktree, so an uncommitted file does
  not exist to them, and that holds just as true when what it holds is seven
  headings.
- **Run Step 5 as written**, seeding `paths.review_checklist` from its base
  contract with nothing appended, or skipping it when the key is unset.

Then report the outcome as greenfield explicitly — that this run derived no
rules **because the repository tracks no source code**, not because
exploration came back empty-handed. Those read identically in a report and
mean opposite things.

This is the one path on which producing no rules is correct. It does not
soften Step 2's bar anywhere else: a repository with source code gets the
full exploration pass, and "the codebase is small" or "it is early" is never
a reason to reach for this section. The test is mechanical and
empty-or-nothing, and this flow does not second-guess it in either direction.

## Step 1 — Explore

Dispatch exploration subagents in parallel, one per area, each covering a
distinct concern across the whole codebase rather than one file at a time:

- Module boundaries and layering
- Error handling
- Naming
- Authentication and authorization
- Data access
- Test structure and mocking
- Formatting and lint

Each reports concrete instances of a pattern it found, every one carrying the
`file:line` it came from — not a summary judgment about whether "the project
generally does X." Judging whether a pattern is a rule or a coincidence is
this flow's job in Step 2, not something to delegate to the subagents.

## Step 2 — Rule versus occurrence

A pattern becomes a proposed rule only when it holds across multiple
independent call sites. A single instance, however clean, is reported as an
observation.

The distinction erodes easily under pressure to produce a fuller-looking
list, and a rule derived from one example is how a coincidence gets enforced
across an entire codebase. One file wrapping an error in a typed wrapper is
one file's choice; the same wrapper at several independent call sites, none
copying from the others, is a convention worth holding future code to. How
many sites cross the bar is a judgment call per pattern — but two or more
independent, non-adjacent sites is the floor.

Carry every occurrence forward regardless of which side it lands on. A
pattern that stayed an observation is still worth surfacing in Step 3 — the
person confirming may know it is about to become consistent, or may want it
promoted deliberately — but present it as what it is.

## Step 3 — Confirm with the user

Present every proposed rule grouped by the area heading it belongs under
(`core/contracts/conventions-template.md`'s seven headings, in order), each
with its `file:line` evidence. Present the observations that did not cross
Step 2's bar in the same pass, clearly separated, so the person can promote
one deliberately rather than only accepting what this flow already decided.

For each group the user accepts, edits, or drops it — never a single
all-or-nothing confirmation across the whole set. Wait for an explicit answer
before Step 4 writes anything.

## Step 4 — Write

Write the accepted rules between the managed-section markers defined in
`core/contracts/conventions-template.md`
(`<!-- pipeline:conventions:start -->` / `<!-- pipeline:conventions:end -->`),
using that contract's seven area headings in order. An area with no accepted
rule keeps its heading, followed by a line stating that no rule was derived —
never omitted, since an absent heading leaves a later reader unable to tell
"checked, found nothing" from "never checked."

Never touch a single character outside the markers. If the file already holds
hand-written prose with no markers, append the markers and the generated
block to the end, rather than reordering existing content. If only one marker
is present, or the two appear out of order, stop and report the file as
malformed rather than guessing which span this flow owns.

Each rule is one line, an imperative instruction, ending with the `file:line`
citation it was derived from. Do not compress a group of rules into a
paragraph; a later reader needs to check one rule at a time against its own
citation.

Then commit:

```bash
git add <paths.conventions>
git commit -m "pipeline: derive project conventions"
```

Stage that path specifically — never `git add .` — and append
`git.commit_trailer` if non-empty. The commit is part of this step, not an
afterthought a caller might do later: the phases read `paths.conventions`
from inside a worktree holding only what `git.base_branch` has committed. An
uncommitted conventions file is, to every phase, a conventions file that does
not exist — the silent non-enforcement this flow exists to prevent, arriving
by a different route.

## Step 5 — Derive the checklist

Derive `paths.review_checklist`, seeded from
`core/contracts/review-checklist-base.md`'s five sections and extended with
the rules accepted in Step 3 that read as review-time checks rather than
implementation-time instructions. A naming convention belongs in the
conventions file alone; "every new entry point carries an authorization
check" reads equally as a rule to follow and a box to check during review,
and belongs in both. Never replace the seed's five sections — this flow only
adds to the checklist, never removes from it.

On a re-run, bring an existing checklist up to the seed.
Compare `paths.review_checklist` against
`core/contracts/review-checklist-base.md`: insert each seed section the
checklist lacks at its position in the seed, and add each seed item
missing from a section the checklist has to the end of that section.
This needs no confirmation in Step 3 — the seed is never optional.
Without it, content added to the seed later reaches only projects that
derive their checklist for the first time.

Commit the checklist too, for the same reason Step 4 commits:

```bash
git add <paths.review_checklist>
git commit -m "pipeline: derive review checklist"
```

If `paths.review_checklist` is not set, skip this step and say so in the
report. It is an optional key, and this flow does not invent a path for it.

## Drift reporting

On a re-run against a file that already holds a managed section, do not
overwrite it blindly. Compare Step 1's fresh exploration against what the
existing managed section states, and report both directions:

- **Rules present in the file but no longer practiced in code** — the
  citation no longer shows the pattern, and no other site in this run's
  exploration shows it either.
- **Practices in code with no rule** — Step 2 found a pattern that clears the
  bar, but no line in the managed section states it.

Present both lists in Step 3 alongside the newly proposed groups, and let the
same accept/edit/drop choice apply to a drifted rule as to a new one. A rule
no longer practiced is not deleted silently just because this run noticed it.
