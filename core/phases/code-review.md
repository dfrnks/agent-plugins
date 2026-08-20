# Phase: code-review

Adjudicate the implementation execute produced against the spec, the
project's conventions, and the tests themselves. This is the last gate before
the change merges. It writes no code and does not negotiate with the test
suite on execute's behalf — it reads what happened and renders a verdict any
human on the project can audit later.

The argument is a task ID (for example `TASK-1`). If none is given, derive it
from the current branch name.

## Step 0 — Load configuration

Read `.tdd-pipeline/config.yaml`. Follow the fail-fast protocol in
`core/contracts/pipeline-config.md`: stop and name the exact missing key if
the file or a key this phase needs is absent. This phase needs
`commands.test_all`, `paths.specs`, `paths.conventions`, `paths.tests`,
`git.base_branch`, and `git.commit_trailer` — plus `paths.review_checklist`,
if the project sets it.

## Step 1 — Load context

Read `paths.specs/<task-id>.md` in full, per
`core/contracts/spec-template.md` — `## Definition of Done`, `## Approach`,
`## Files to Modify`, and `## Out of Scope` — so the diff is judged against
what the task asked for rather than a guess at it.

Then read `## Agent Handoff Log` in full, per
`core/contracts/handoff-log.md`. The test and execute phases each left a
dated entry. From execute's, two blocks matter most:

- The `### Implementation Manifest`: one line per Definition of Done item
  mapping it to the `<file>:<line>` that satisfies it and a claim about what
  that line does, plus one line per checklist-relevant area the change
  touched (a new entry point, an authorization check, input validation, a
  schema change, a secret or credential path). Step 3's sixth dimension
  spot-checks this and builds its coverage scan from it.
- The `### Conventions Applied` block: each rule execute says it applied,
  with a citation to `paths.conventions` and where it applied it, plus a line
  for every area where it found no rule.

Also note deviations from the spec and their reasoning, any test execute
flagged as appearing wrong, and non-obvious implementation decisions — needed
throughout Step 3.

If either phase's entry is missing or empty, that is itself a finding: this
phase has no shortcut left and must reconstruct the context from the diff and
the spec. A missing `### Implementation Manifest` is a finding under its own
name, not folded into this general case — see Step 3's sixth dimension.

## Step 2 — Read the full diff

Identify every commit made for this task since it diverged from
`git.base_branch`, and read the full diff, not a summary. Note for each file
whether it is a test file (under an entry in `paths.tests`) or an
implementation file — Step 3's test-integrity check runs on that split.
Reconcile the changed files against `## Files to Modify`: a file touched that
the spec never named, or a named file left untouched, is a finding — not
necessarily a blocker, but never silently accepted.

## Step 3 — Review dimensions

Work through all six in order. Do not skip one because the diff looks small;
a one-line change can violate any of them.

### 1. Spec compliance

Check every `## Definition of Done` item against the diff: satisfied,
partially satisfied, or missing. A deviation is acceptable only if the
handoff log documents it with reasoning — an undocumented one is a finding
however reasonable it looks, being indistinguishable from an oversight.

### 2. Conventions

Read `paths.conventions`. Then verify the `### Conventions Applied` block
line by line: does the cited rule exist at the cited line, and does the code
at the cited location do what the rule says? A citation pointing at the wrong
line, a rule that says something different from the claim, or applied code
that does not follow the cited rule are each findings. This is what keeps the
citation honest rather than decorative.

Every "no rule found" line becomes a warning naming the uncovered area, so
the gap is visible to whoever maintains `paths.conventions` next. A missing
`### Conventions Applied` block is itself a warning: the paper trail proving
conventions were consulted only works if its absence is a finding rather than
"nothing to check here."

### 3. Security and isolation

Check that every new entry point carries an authorization check before it
acts, that input from outside the system is validated before use, that —
where this codebase has separate owners of data — data scoped to one tenant,
user, or account cannot be reached by supplying another's identifier, and
that no secret, token, or credential was added to source or test fixtures. A
project with no such notion reports this dimension not applicable rather than
inventing a boundary; a project with one is never exempt.

### 4. Test integrity

The highest-value gate this phase runs: execute is forbidden from making a
test pass by weakening it, and this is the only phase positioned to catch it
if it happened anyway.

Using Step 2's split, isolate every commit that touched a file the test phase
wrote. For each, diff that file as the test phase committed it against its
current state, and verify:

- **No assertion was weakened** — an exact match loosened to a substring
  check, a specific expected value replaced by a looser one, a mock's
  expected call count or arguments relaxed.
- **No test was deleted.**
- **No expected value was changed to match the implementation** instead of
  the implementation being changed to match the expectation.

Apply the same tie-breaker execute was bound by: if a change to a test file
altered any assertion's effective expected value, it is not a scaffolding
fix, whatever the commit message or handoff log calls it. Judge the diff, not
the label — a weakening edit described as a fixture correction is still one.

Adding new tests and fixing genuine infrastructure bugs — a broken import, a
wrong fixture path, a typo in a helper, none of which touch an assertion's
effective expected value — are acceptable and not findings.

**Any unjustified test modification is a blocker.** If the handoff log shows
execute flagged a specific test as appearing wrong, evaluate that claim on
its merits against the spec: agreeing with a documented, reasoned claim is
not waving through a silent rewrite, and disagreeing with it is not an
automatic blocker either.

### 5. Test quality

Distinct from integrity: integrity asks whether the tests were weakened after
being written, quality whether they were any good to begin with. A suite that
was never weakened can still fail every one of these.

- Is there a test for every Definition of Done item?
- Do tests cover error and permission paths, not only the happy path?
- Are authorization tests realistic — does the mocked guard actually enforce
  the rule, rather than admitting everyone?
- Do tests clean up after themselves?
- **Does production code contain logic that exists only to accommodate a
  test?** Call this out specifically. It is the check most likely to be
  skipped and the one whose absence does the most damage: such code looks
  purposeful and survives review indefinitely once let through once.

### 6. Checklist verification

This is what makes reviewing a large diff affordable: the manifest is trusted
strategically — sampled and cross-checked, not re-derived from scratch.

1. **Read the `### Implementation Manifest`** from Step 1 in full.
2. **Spot-check two or three lines** by following each cited `<file>:<line>`
   and confirming the code does what the line claims. Choose deliberately,
   not the first two or three: prefer a line touching security or a data
   boundary, and the Definition of Done item whose mapping to code is least
   obvious — the lines most likely to hide a problem.
3. **Scan `paths.review_checklist`**, when configured, for items relevant to
   this change that the manifest does not mention, and verify those directly.
   The manifest says what execute thought worth recording, not what a
   checklist built from the project's own history says is worth checking.

Two rules govern the results, because either one skipped turns this into a
formality:

- **A missing `### Implementation Manifest` is a warning in its own right**,
  named as such — never a silent cue to fall back to reading every file.
  Compensating quietly means nobody downstream learns the artifact stopped
  being produced.
- **An inaccurate manifest line is worse than a missing one, and is treated
  that way.** A claim that overstates what the cited code does sends
  attention toward a spot that confirms a false claim, away from the actual
  gap. When a spot-check fails, escalate the severity beyond what the same
  defect would otherwise earn.

## Step 4 — Classify findings

Sort every finding from Step 3 into one of three severities:

- **Blocker** — must be fixed before merge: a security hole, a data leak
  across accounts, an unmet Definition of Done item, a weakened or deleted
  test.
- **Warning** — should be fixed, but does not block: an uncovered area named
  by a "no rule found" line, a missing `### Conventions Applied` block, a
  minor convention deviation, a partially satisfied checklist item.
- **Suggestion** — worth raising, changes nothing about the verdict.

A task with one or more blockers cannot be `APPROVED` or
`APPROVED_WITH_WARNINGS`, however cleanly the other dimensions passed.

## Step 5 — Handoff log

Append a dated subsection to `## Agent Handoff Log` in the spec file,
following `core/contracts/handoff-log.md`. Include:

- Every finding from Step 4, grouped by severity, each naming its file and
  location.
- The conventions spot-check result from dimension 2 — which citations
  checked out, which didn't, which "no rule found" areas were confirmed.
- The test-integrity result from dimension 4 — which commits touched test
  files, and confirmation that each was inspected, not merely listed.
- The manifest spot-check result from dimension 6 — which lines were checked
  and why those, which held up, and which checklist items needed direct
  verification because the manifest never mentioned them.
- Any adjudication on a test execute flagged as appearing wrong, with
  reasoning.
- The verdict from Step 7.

Apply the escalation routing table in `core/contracts/handoff-log.md`: a
finding that is a durable fact about the codebase belongs in
`paths.conventions`, appended inside its discoveries span
(`core/contracts/conventions-template.md`) and never inside the managed
section, which the conventions flow regenerates wholesale. Note any such
escalation here too, so a later reader knows it was acted on.

## Step 6 — Commit

Stage the spec file's updated handoff log, then commit:

```bash
git add <spec file>
git commit -m "<task-id>: code review — <verdict>"
```

Stage the spec file specifically — never `git add .` or `git add -A`. This
phase changes no implementation or test file, so nothing else belongs here.
If `git.commit_trailer` is non-empty, append it as a trailer; if empty, omit
it rather than adding an empty line.

## Step 7 — Verdict

Return a verdict of at most 500 characters, in exactly this shape:

```
Verdict: <APPROVED|APPROVED_WITH_WARNINGS|CHANGES_REQUESTED>. Blockers: <list|none>. Warnings: <list|none>.
```

The cap holds this line to a fixed shape an orchestrator can parse without
reading the handoff log. Every blocker, every warning, the reasoning behind
each, and the full record of what was checked belongs in the Step 5 handoff
log, never squeezed in here. The next phase or human runs in a fresh context
with no memory of this one; that log is the only place it can read what
happened.
