# Phase: code-review

Adjudicate the implementation the execute phase produced against the spec,
the project's own conventions, and the tests themselves. This is the last
gate before the change merges: it does not write code, and it does not
negotiate with the test suite on the execute phase's behalf — it reads what
happened and renders a verdict, with reasoning any human on the project can
audit later.

The argument to this phase is a task ID (for example `TASK-1`). If none is
given, derive it from the current branch name.

## Step 0 — Load configuration

Read `.tdd-pipeline/config.yaml`. Follow the fail-fast protocol in
`core/contracts/pipeline-config.md`: stop and name the exact missing key
if the file or a key this phase needs is absent. This phase needs
`commands.test_all`, `paths.specs`, `paths.conventions`, `paths.tests`,
`git.base_branch`, and `git.commit_trailer`. If `paths.review_checklist`
is set in the project's configuration, this phase also needs it.

## Step 1 — Load context

Read `paths.specs/<task-id>.md` in full, per
`core/contracts/spec-template.md` — `## Definition of Done`, `## Approach`,
`## Files to Modify`, and `## Out of Scope`, so the diff can be judged
against what the task actually asked for rather than against a guess at it.

Then read the `## Agent Handoff Log` section in full, per
`core/contracts/handoff-log.md`. The test phase and the execute phase each
left a dated entry there. From the execute phase's entry, this phase relies
on two blocks in particular:

- The `### Implementation Manifest`: one line per Definition of Done item,
  mapping it to the `<file>:<line>` that satisfies it and a claim about
  what that line does, plus one further line for each checklist-relevant
  area the change touched (a new entry point, an authorization check,
  input validation, a schema change, a secret or credential path). This is
  what Step 3's sixth dimension spot-checks and builds its coverage scan
  from.
- The `### Conventions Applied` block: each rule the execute phase says it
  applied, with a citation to `paths.conventions` and where it applied it,
  plus a line for every area where it found no rule.

Also note deviations from the spec and the reasoning for each, any test the
execute phase flagged as appearing wrong, and non-obvious implementation
decisions — the rest of what the entry records, needed throughout Step 3.

If either phase's entry is missing or empty, treat that itself as a
finding: this phase has no shortcut left and must reconstruct the missing
context from the diff and the spec directly. A missing
`### Implementation Manifest` block is a finding under its own name, not
folded into this general case — see Step 3's sixth dimension for how it is
handled specifically.

## Step 2 — Read the full diff

Identify every commit made for this task since it diverged from
`git.base_branch`, and read the full diff, not a summary of it. Note, for
each file, whether it is a test file (under an entry in `paths.tests`) or
an implementation file — this split is what Step 3's test-integrity check
runs on. Reconcile the changed files against `## Files to Modify`: a file
touched that the spec never named, or a named file left untouched, is a
finding, not necessarily a blocker, but never silently accepted.

## Step 3 — Review dimensions

Work through all six in order. Do not skip a dimension because the diff
looks small — a one-line change can violate any of them.

### 1. Spec compliance

Check every `## Definition of Done` item against the diff: satisfied,
partially satisfied, or missing. A deviation is acceptable only if the
handoff log documents it with reasoning; an undocumented deviation is a
finding regardless of how reasonable it looks in isolation, since an
undocumented one is indistinguishable from an oversight. Nothing in the
spec should be quietly absent from the diff.

### 2. Conventions

Read `paths.conventions`. Then verify the `### Conventions Applied` block
from Step 1 line by line: does the cited rule actually exist at the cited
line, and does the code at the cited location actually do what the rule
says? A citation that points at the wrong line, a rule that says something
different from what the block claims, or applied code that doesn't
actually follow the cited rule are each findings in their own right — this
check is what keeps the citation honest rather than decorative.

Every "no rule found" line in the block becomes a warning naming the
uncovered area, so the gap is visible to whoever maintains
`paths.conventions` next. A missing `### Conventions Applied` block
entirely is itself a warning: the mitigation this block exists to provide
— a paper trail proving the conventions were actually consulted rather
than skipped — only works if this phase treats its absence as a finding
and not as "nothing to check here."

### 3. Security and isolation

Check that every new entry point carries an authorization check before it
acts, that input arriving from outside the system is validated before use,
that — when this codebase has any notion of separate owners of data —
data scoped to one tenant, user, or account cannot be reached by supplying
another one's identifier, and that no secret, token, or credential was
added to source or test fixtures in any form. A project with no such notion
reports that dimension not applicable rather than inventing a boundary to
check against; a project with one is never exempt from it.

### 4. Test integrity

The highest-value gate this phase runs, kept in full because it is what
makes the rest of the pipeline trustworthy: the execute phase is forbidden
from making a test pass by weakening it, and this is the only phase
positioned to catch it if it happened anyway.

Using the split from Step 2, isolate every commit that touched a file the
test phase wrote. For each one, diff that file's state as the test phase
committed it against its current state, and verify:

- **No assertion was weakened** — an exact match loosened to a substring
  check, a specific expected value replaced by a looser one, a mock's
  expected call count or arguments relaxed.
- **No test was deleted.**
- **No expected value was changed to match the implementation** instead of
  the implementation being changed to match the expectation.

Apply the same tie-breaker the execute phase was bound by: if a change to a
test file altered any assertion's effective expected value, it is not a
scaffolding fix, whatever the commit message or the handoff log calls it.
Judge the diff itself, not the label attached to it — a weakening edit
described as a fixture correction is still a weakening edit.

Adding new tests and fixing genuine infrastructure bugs — a broken import,
a wrong fixture path, a typo in a test helper, none of which touch an
assertion's effective expected value — are acceptable and not findings.

**Any unjustified test modification is a blocker**, full stop. If the
handoff log shows the execute phase flagged a specific test as appearing
wrong, evaluate that claim on its own merits against the spec: agreeing
with a documented, reasoned claim is not the same as waving through a
silent rewrite, and disagreeing with it is not an automatic blocker either
— decide it on the evidence, both directions.

### 5. Test quality

Distinct from test integrity: integrity asks whether the tests were
weakened after being written; quality asks whether they were any good to
begin with. A suite that was never weakened can still fail every one of
these checks.

- Is there a test for every Definition of Done item?
- Do tests cover error and permission paths, not only the happy path?
- Are authorization tests realistic — does the mocked guard actually
  enforce the rule, rather than admitting everyone?
- Do tests clean up after themselves?
- **Does production code contain logic that exists only to accommodate a
  test?** Call this out specifically when found. It is the check most
  likely to be skipped, and the one whose absence does the most damage:
  such code looks purposeful, reads as if it belongs, and survives review
  indefinitely once it is let through the first time.

### 6. Checklist verification

This dimension is what makes reviewing a large diff affordable: instead of
re-reading every changed file, the manifest is trusted strategically —
sampled and cross-checked, not re-derived from scratch.

1. **Read the `### Implementation Manifest`** identified in Step 1 in full.
2. **Spot-check two or three of its lines** by following each cited
   `<file>:<line>` and confirming the code at that location actually does
   what the line claims. Choose which lines to check deliberately, not the
   first two or three in the list: prefer a line touching security or a
   data-boundary check, and a Definition of Done item whose mapping to code
   is least obvious — the lines most likely to hide a problem if the claim
   is wrong, not the ones most likely to be right.
3. **Scan `paths.review_checklist`**, when configured, for items relevant
   to this change that the manifest does not mention, and verify those
   directly — the manifest tells this phase what the execute phase thought
   was worth recording, not what a checklist built from the project's own
   history says is worth checking. An item the checklist flags that the
   manifest never touches is exactly the gap this step exists to close.

Two rules govern how the results of this dimension are treated, because
either one skipped turns the dimension from a real check into a formality:

- **A missing `### Implementation Manifest` block is a warning in its own
  right**, named as such, never a silent cue to fall back to reading every
  file instead. Compensating quietly for a missing manifest means nobody
  downstream ever learns the artifact stopped being produced — which is
  exactly the kind of gap that survives a review precisely because the
  reviewer worked around it instead of naming it.
- **An inaccurate manifest line is worse than a missing one, and is treated
  that way.** A claim that overstates or misdescribes what the cited code
  does sends attention toward a spot that merely confirms a false claim,
  away from wherever the actual gap is. When a spot-check fails, escalate
  the severity of the finding beyond what the same defect would otherwise
  earn — do not just note the correction and move on as if the manifest had
  never made the claim.

## Step 4 — Classify findings

Sort every finding from Step 3 into one of three severities:

- **Blocker** — must be fixed before this task can merge: a security hole,
  a data leak across accounts, an unmet Definition of Done item, a weakened
  or deleted test.
- **Warning** — should be fixed, but does not by itself block the merge: an
  uncovered area named by a "no rule found" line, a missing
  `### Conventions Applied` block, a minor convention deviation, a checklist
  item the diff only partially satisfies.
- **Suggestion** — worth raising, changes nothing about the verdict: a
  clearer name, a simplification, a note for a future task.

A task with one or more blockers cannot be `APPROVED` or
`APPROVED_WITH_WARNINGS`, regardless of how many other dimensions passed
cleanly.

## Step 5 — Handoff log

Append a dated subsection to `## Agent Handoff Log` in the spec file,
following `core/contracts/handoff-log.md`. Include:

- Every finding from Step 4, grouped by severity, each naming the file and
  location it concerns.
- The result of the conventions spot-check from Step 3's second
  dimension — which citations checked out, which didn't, and which "no
  rule found" areas were confirmed.
- The result of the test-integrity check from Step 3's fourth dimension —
  which commits touched test files, and confirmation that each was
  inspected, not merely listed.
- The result of the manifest spot-check from Step 3's sixth dimension —
  which lines were checked and why those were chosen, which held up and
  which didn't, and which checklist items required direct verification
  because the manifest never mentioned them.
- Any adjudication made on a test the execute phase flagged as appearing
  wrong, with the reasoning.
- The verdict from Step 7.

Apply the escalation routing table in `core/contracts/handoff-log.md`: a
finding that is a durable fact about the codebase belongs in
`paths.conventions` — appended inside its discoveries span
(`core/contracts/conventions-template.md`), never inside the managed section,
which the conventions flow regenerates wholesale on its next run — not
buried here as a task-only detail. Note any such
escalation here as well, so a later reader of this log knows the finding
was acted on rather than dropped.

## Step 6 — Commit

Stage the spec file's updated handoff log, then commit:

```bash
git add <spec file>
git commit -m "<task-id>: code review — <verdict>"
```

Stage the spec file specifically — never `git add .` or `git add -A`. This
phase changes no implementation or test file, so nothing else belongs in
this commit. If `git.commit_trailer` is non-empty, append it as a trailer
on the commit message. If it is empty, omit it entirely — do not add an
empty trailer line.

## Step 7 — Verdict

Return a verdict of at most 500 characters, in exactly this shape:

```
Verdict: <APPROVED|APPROVED_WITH_WARNINGS|CHANGES_REQUESTED>. Blockers: <list|none>. Warnings: <list|none>.
```

The cap holds this line to a fixed shape an orchestrator can parse without
reading the rest of the handoff log — a verdict long enough to explain
itself would defeat the reason it exists as a separate line at all. Every
blocker, every warning, the reasoning behind each, and the full record of
what was checked belongs in the handoff log written in Step 5, never
squeezed into this line. The next phase or human runs in a fresh context
with no memory of this one; the handoff log is the only place it can read
what happened here.
