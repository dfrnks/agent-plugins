# Flow: conventions

Derive the project's own rules from the codebase itself, and write them into
`paths.conventions` — the file the execute and code-review phases read at
the start of every run and trust completely for anything specific to this
project. Neither phase carries an inline rule about naming, layering, or
error handling; both delegate that entirely to whatever this flow writes.
That delegation is exactly why this flow cannot behave like `init`'s
detection pass: a wrong guess here does not stop for a human to catch it
before the next phase acts on it — it becomes an enforced rule the moment
the file is written. Every step below exists to keep that from happening on
a coincidence.

Takes no required argument; run standalone, or dispatched from `init`'s
Step 5 against the `paths.conventions` file that flow just confirmed. Reads
`paths.review_checklist` from the configuration, if this is a re-run, and
`paths.conventions` in every case — resolve both from
`.agent-pipeline/config.yaml` before Step 1, following the same fail-fast
protocol every other flow uses (`core/contracts/pipeline-config.md`): stop
and name the exact missing key rather than guessing a path.

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

Each subagent reports back concrete instances of a pattern it found, every
one carrying the `file:line` it came from — not a summary judgment about
whether "the project generally does X." Judging whether a pattern is a rule
or a coincidence is this flow's own job in Step 2, not something to delegate
to the subagents doing the exploring.

## Step 2 — Rule versus occurrence

This is the quality bar the rest of this flow exists to enforce: a pattern
becomes a proposed rule only when it holds across multiple independent call
sites. A single instance, however clean, is reported as an observation, not
proposed as a rule.

State why, because the distinction is easy to erode under pressure to
produce a fuller-looking list: a rule derived from one example is exactly
how a coincidence gets enforced across an entire codebase. One file that
happens to wrap an error in a typed wrapper is one file's choice; the same
wrapper appearing at several independent call sites, none copying from the
others, is a convention worth writing down and holding future code to. The
number of sites needed to cross that bar is a judgment call this flow makes
per pattern, not a fixed count — but two or more independent, non-adjacent
sites is the floor below which nothing crosses into a rule.

Carry every occurrence forward regardless of which side of that bar it
lands on. A pattern that stayed an observation is still worth surfacing in
Step 3 — the person confirming rules may know it is about to become
consistent, or may want it promoted deliberately even short of the bar —
but it is presented as what it is, not dressed up as a rule this flow
manufactured evidence for.

## Step 3 — Confirm with the user

Present every proposed rule grouped by the area heading it belongs under
(`core/contracts/conventions-template.md`'s seven headings, in that order),
each rule with its `file:line` evidence attached. Present the observations
that did not cross Step 2's bar in the same pass, clearly separated from the
proposed rules, so the person confirming can promote one deliberately rather
than only ever accepting what this flow already decided.

For each group, the user accepts, edits, or drops it — never a single
all-or-nothing confirmation across the whole set. Wait for an explicit
answer before Step 4 writes anything.

## Step 4 — Write

Write the accepted rules between the managed-section markers defined in
`core/contracts/conventions-template.md`
(`<!-- pipeline:conventions:start -->` / `<!-- pipeline:conventions:end -->`),
using that contract's seven area headings in order. An area with no
accepted rule still keeps its heading, followed by a line stating that no
rule was derived for it — never omitted, since an absent heading leaves a
later reader unable to tell "checked, found nothing" from "never checked."

Never touch a single character outside the markers. If the file already
holds hand-written prose with no markers, append the markers and the
generated block to the end of the file, per that contract, rather than
reordering existing content to make room. If only one marker is present, or
the two appear out of order, stop and report the file as malformed rather
than guessing which span this flow owns.

Each rule is one line, an imperative instruction, ending with the
`file:line` citation it was derived from — exactly the shape
`conventions-template.md` specifies. Do not compress a group of rules from
one area into a single paragraph; a later reader, human or another flow
run, needs to be able to check one rule at a time against its own citation.

## Step 5 — Derive the checklist

Derive `paths.review_checklist`, seeded from
`core/contracts/review-checklist-base.md`'s four sections and extended with
the rules accepted in Step 3 that read as review-time checks rather than
implementation-time instructions — a naming convention belongs in the
conventions file alone, but "every new entry point carries an authorization
check" reads equally as a rule to follow and a box to check during review,
and belongs in both places. Never replace the seed's own four sections;
this flow only appends to them, the same way it only appends to the
conventions file's managed section.

If `paths.review_checklist` is not set in the configuration, skip this step
and say so in the report — it is an optional key, and this flow does not
invent a path for it.

## Drift reporting

On a re-run against a `paths.conventions` file that already holds a managed
section from an earlier run, do not overwrite it blindly. Compare what
Step 1's fresh exploration found against what the existing managed section
already states, and report both directions of drift:

- **Rules present in the file but no longer practiced in code** — the
  citation the rule once pointed to no longer shows the pattern, and no
  other site in this run's exploration shows it either.
- **Practices in code with no rule** — Step 2 found a pattern that clears
  the rule bar, but no line in the existing managed section states it.

Present both lists to the user in Step 3 alongside the newly proposed
groups, and let the same accept/edit/drop choice apply to a drifted rule as
to a new one — a rule no longer practiced is not deleted silently just
because this run noticed it first.
