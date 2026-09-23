# Phase: execute

Make the failing suite committed by the test phase pass, without weakening
it. This is the green phase: the committed tests are the contract for this
task, and this phase satisfies that contract rather than renegotiating it.

The argument is a task ID (for example `TASK-1`). If none is given, derive it
from the current branch name.

## Step 0 — Load configuration

Read `.tdd-pipeline/config.yaml`. Follow the fail-fast protocol in
`core/contracts/pipeline-config.md`: stop and name the exact missing key if
the file or a key this phase needs is absent. This phase needs
`commands.test`, `commands.test_all`, `commands.lint`, `paths.specs`,
`paths.tests`, `paths.conventions`, and `git.commit_trailer` — plus
`commands.typecheck`, if the project sets it.

Then read every file under `.tdd-pipeline/memory/execute/`, per
`core/contracts/handoff-log.md`, `## Phase memory`. Those are lessons
earlier runs of this phase paid for; apply the ones that bear on this
task. An absent or empty directory is not an error.

## Step 1 — Read the handoff log

Read `paths.specs/<task-id>.md` in full, per
`core/contracts/spec-template.md` — not only `## Definition of Done`, but
`## Approach` and `## Files to Modify`, which name the files, functions, and
data this phase must produce.

Then read `## Agent Handoff Log` in full, per
`core/contracts/handoff-log.md`. The test phase left findings there: the path
to the test files it wrote, mock or fixture patterns established for this
task, whether it found a testing section in the conventions file, and any
deviation it made from the spec. A mock pattern invented twice, once by the
test phase and once here, is the sign this step was skipped. If the log is
empty, proceed, but expect to spend more effort locating patterns it would
have handed over.

Map every `## Definition of Done` item to a concrete, verifiable check: a
specific test passing, a clean lint run, a type-check passing, an endpoint
returning a specific shape. An item with no attached check is not yet
verifiable — resolve that now rather than discovering it at Step 7.

Flag an item that is ambiguous, or that contradicts a rule in
`paths.conventions`, before any code is written. A bad requirement is cheap
to raise here and expensive to unwind three files in.

### Stop-and-escalate conditions

Three further conditions get the same treatment, wherever in this phase they
surface:

- A Definition of Done item that is technically impossible given existing
  constraints must never be silently dropped. Explain why it cannot be
  satisfied as written, and propose the closest valid alternative.
- If implementing one Definition of Done item breaks another, resolve the
  conflict explicitly and document the trade-off in the handoff log — never
  pick one silently and let the other regress unremarked.
- If the task turns out to require touching infrastructure or deployment
  configuration beyond its own scope, stop and ask rather than expanding
  scope unilaterally.
- If this phase cannot proceed without modifying a test file the test phase
  committed — the suite cannot execute at all because of a defect in one, or
  the lint gate reports a violation inside one that restoring does not clear
  — write the Step 9 entry naming the file, the defect, and the outcome of
  Step 4's tie-breaker, then stop without committing. The next phase decides
  whether the edit was a scaffolding fix; this one does not.

## Step 2 — Plan before editing

Before touching any file:

- **Explore the codebase.** Identify every file the task needs created or
  modified, and read it, or its nearest analogue, before writing anything.
  Never guess a file's location or an existing function's name — read the
  actual directory tree and existing imports.
- **Trace the dependency chain.** Understand how the pieces named in
  `## Approach` call each other, so implementation follows dependency order
  rather than the order the files happen to be listed in.
- **Mirror existing patterns.** Find analogous files already in the codebase
  and match their structure, naming, and style. New code should read like it
  always belonged.
- **State the plan**: which files will be created or modified, in what order,
  and why, before writing the first line.

## Step 3 — Load project conventions

Read the file at `paths.conventions`. It is the project's own record of how
it wants code written — layering, error handling, naming, the rules of its
stack — and it is what keeps this phase consistent with the codebase without
hardcoding rules for one language or framework here. For each area this
task's changes touch (how errors propagate, how an endpoint is wired, how a
schema field is validated, how authorization is checked, how a UI element is
composed), extract the applicable rule and apply it in Step 5.

Record what was applied, in the handoff log (Step 9), in exactly this shape:

```markdown
### Conventions Applied
- <rule text> — conventions:<line>  → applied at <file>:<line>
- No rule found covering <area> — flagging for review
```

Take each `conventions:<line>` from the file on disk, by searching it for
the rule's text, never from a copy of the file already held in context. A
long conventions file held in context carries no reliable line numbers, and
a citation built from one points at the wrong line while the rule it names
exists — the reviewer then sees a dangling pointer instead of an applied
rule.

A "no rule found" line is a required output when true, not an admission of
failure. The conventions file cannot cover every area, and this phase saying
so plainly is the only way the project finds out where its conventions are
thin. The flow that maintains that file relies on exactly this signal to know
where to write a new rule; staying silent erases it for good.

If the task changes the database schema or another migration-bearing
structure, follow the migration procedure documented at `paths.conventions`.
If none is documented, stop and ask rather than guessing a migration
command.

## Step 4 — Test protection contract

The committed tests are the contract, not a draft. Weakening a test to make
it pass is indistinguishable, from the suite's perspective, from the guarded
behavior never having been built. A red-then-green pipeline collapses the
moment the phase making tests pass may also rewrite what "pass" means.

- **Never modify an existing assertion to make the implementation pass.** If
  a test expects a specific status, value, or error, the implementation must
  produce it — the test does not move to meet the code.
- **Never delete an existing test.** Deleting it deletes the guard, silently,
  for whoever later assumes the suite still covers what it once did.
- **Never weaken a test condition** — loosening an exact match to a substring
  check, dropping an edge-case assertion, relaxing a mock's expected call
  count or arguments. A weakened test still looks green.
- **You may add new tests** for scenarios discovered during implementation
  that the test phase did not cover.
- **A genuine infrastructure bug in test code** — a broken import, a wrong
  fixture path, a typo in a helper — is a defect in the scaffolding rather
  than a change to the contract. Fixing it still modifies a file the test
  phase committed, which Step 10 stops, so route it through the
  stop-and-escalate condition for that case instead of editing and carrying
  on. The exception is one a reviewer grants, not one this phase grants
  itself.
- **Tie-breaker, applied without judgment: if a scaffolding fix would change
  any assertion's effective expected value, it is not a scaffolding fix.** A
  fixture can be wrong in a way that also supplies the value an assertion
  checks against, so "correcting the fixture" and "changing what the test
  expects" can be one edit under two names. Do not weigh how reasonable the
  fix looks — check only whether an expected value changes. If it does, treat
  the whole edit as a test-appears-wrong case below.
- **If a test appears wrong** — its expectation contradicts the spec, or an
  edge case looks mis-specified — do not change it silently. Implement toward
  the spec, document the conflict in the handoff log (Step 9) with the
  specific test, the disagreement, and the reasoning, and let code-review
  adjudicate. A silent rewrite forecloses that adjudication.

## Step 5 — Implement

Implement the change file by file, in the dependency order from Step 2. Write
complete code — no placeholders or stubbed-out branches unless the Definition
of Done explicitly allows them. Mirror the style, naming, and import pattern
of the analogous files from Step 2, and apply the conventions from Step 3.

## Step 6 — Self-review

After each file or logical chunk, review it critically before moving on:

- **Correctness** — does this satisfy the Definition of Done item it targets?
- **Convention compliance** — does it match the rules from Step 3?
- **Security and isolation** — is authorization checked where the conventions
  require it; and, where this codebase has separate owners of data, can one
  account's action reach another's? Where it has no such notion, this half of
  the check does not apply and is not something to manufacture.
- **Type and shape safety** — do the types, schemas, or interfaces this code
  touches match what the rest of the codebase expects?
- **Edge cases** — not-found, empty input, boundary values: handled, or
  silently assumed away?

Rewrite anything that fails before proceeding. A chunk reviewed only once the
whole task is "done" costs far more to fix than one reviewed while fresh.

## Step 7 — Verification loop

For each Definition of Done item and its check from Step 1:

1. Run the verification: `commands.test` (with `{target}` substituted for the
   module or file this task's tests live in), `commands.test_all`, or
   `commands.typecheck` where set, or a manual trace where no automated check
   applies.
2. If it fails, diagnose the root cause and fix the implementation — never
   the test, per Step 4 — then re-run.
3. Do not mark an item complete until its check passes.

Repeat until every item is verified. Then, **unless `policy.full_suite` is
`on_end` or `never`**, run `commands.test_all` once more, in full, to confirm
nothing this task touched broke a previously passing test elsewhere. This is the
broad run most policies keep, because it is the earliest point where the
implementation exists and a failure is still cheap to fix in place.

Under `on_end` the broad run moves to that phase, which sees the later state;
under `never` it does not happen here at all and CI is the regression gate. In
both cases the targeted `commands.test` still gates every Definition of Done
item above — what changes is the breadth of the final sweep, never whether the
task's own tests passed.

## Step 8 — Lint gate

After every test passes, run `commands.lint` and, when set,
`commands.typecheck`. Fix every violation. A task is not complete until both
the suite and the lint gate are clean — do not proceed to Step 9 with either
failing. If fixing a lint violation changes behavior, re-run Step 7: a fix
made after the verification loop is unverified until it runs again.

## Step 9 — Handoff log

Append a dated subsection to `## Agent Handoff Log` in the spec file,
following `core/contracts/handoff-log.md`. Include:

- The `### Implementation Manifest` block, in exactly this shape:

  ```markdown
  ### Implementation Manifest
  - DoD "<Definition of Done item text>" satisfied by <file>:<line> — <claim>
  - <checklist-relevant area, for example: new entry point, authorization
    check, input validation, schema change, secret or credential path> —
    <file>:<line> — <claim>
  ```

  One line per Definition of Done item, mapping it to the file and line that
  satisfies it, and one further line for anything security- or
  checklist-relevant the change touched even when it is not a DoD item — a
  new entry point and its authorization guard, input validation added, a
  schema change, a secret or credential path. A change touching one of these
  and reporting nothing forces code-review to hunt for it with no starting
  point.

  Every line is an assertion about the code that code-review will check
  against the code — treat it with the weight of a test assertion. A line
  that overstates what the cited code does is worse than no manifest, because
  it sends the reviewer to a spot that confirms a false claim instead of
  toward the real gap. Write only what the cited line demonstrates; if a
  Definition of Done item is not yet satisfied, say so.

- The `### Conventions Applied` block from Step 3, in full.
- Deviations from the spec made during implementation, and why.
- Any test that appeared wrong under Step 4, with the conflict documented for
  code-review to adjudicate.
- Non-obvious implementation decisions a reviewer should know before judging
  the diff.
- Anything discovered during implementation that the spec did not anticipate.

Apply the escalation routing table in `core/contracts/handoff-log.md`: a
finding that is a durable fact about this codebase belongs in
`paths.conventions`, appended inside its discoveries span
(`core/contracts/conventions-template.md`) and never inside the managed
section, which the conventions flow regenerates wholesale. Note any such
escalation here too, so a later reader knows it was acted on rather than
dropped.

## Step 10 — Test protection gate

Before committing, confirm this phase honoured Step 4. From the worktree
root, with every directory `paths.tests` names as a pathspec:

```bash
git diff --name-only --diff-filter=MD HEAD -- <paths.tests>
```

Empty output means every test file the test phase committed is intact, and
this phase may commit. `--diff-filter=MD` reports modifications and deletions
only, so a test added under Step 4's grant never appears — a new file is
untracked and absent from this diff entirely.

When `paths.tests` names a directory that also holds implementation — a
project whose tests sit beside the code they test — the output lists this
phase's own implementation edits too, and those are not violations. Narrow
the output to test files by the project's own test-file naming, as the
test phase found it in its Step 2 or the conventions file states it, and
gate on what remains. Say in Step 9 that the output was narrowed and by
which pattern, so code-review can repeat the check. Never narrow by
judgment, file by file: a pattern is checkable, a choice is not.

Any remaining output names a file this phase was not allowed to change. Two
cases, and the difference is whether the change was deliberate:

- **Not deliberate** — most often the Step 8 lint gate's formatter reaching a
  file outside the implementation. Restore it and run the gate again:

  ```bash
  git checkout HEAD -- <the named file>
  ```

  Discarding the edit is legitimate precisely because this phase was never
  allowed to make it.
- **Deliberate** — a Step 4 violation. Stop, per the condition in
  `### Stop-and-escalate conditions`, without committing.

Compare against the working tree, not the index. The suite runs against the
working tree, so a weakened test that is simply never staged still turns the
verification loop green, while a check on the index sees nothing — and the
commit then carries an implementation whose committed tests fail on a fresh
checkout. A gate the phase can pass by withholding a file is not a gate.

## Step 11 — Commit

Stage the implementation files from Step 5, any test file added under
Step 4's grant, any file Step 9 escalated to under `paths.conventions` or
`.tdd-pipeline/memory/`, and the spec file's updated handoff log, then
commit:

```bash
git add <implementation files> <escalated files, if any> <spec file>
git commit -m "<task-id>: implement <short description>"
```

Stage specific files — never `git add .` or `git add -A`. If
`git.commit_trailer` is non-empty, append it as a trailer; if empty, omit it
rather than adding an empty line.

## Step 12 — Report

Return a report of at most 300 characters, in exactly this shape:

```
Implemented: <summary>. Tests: pass (<N>). Lint: clean. Committed: yes.
```

Everything else — the conventions block, deviations, test conflicts,
implementation decisions — belongs in the Step 9 handoff log, never here. The
next phase runs in a fresh context with no memory of this one; that log is
the only place it can read what happened.
