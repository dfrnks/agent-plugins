# Phase: execute

Make the failing suite committed by the test phase pass, without weakening
it. This is the green phase of test-driven development: the tests already
committed are the contract for this task, and this phase's job is to
satisfy that contract, not to renegotiate it.

The argument to this phase is a task ID (for example `TASK-1`). If none is
given, derive it from the current branch name.

## Step 0 — Load configuration

Read `.agent-pipeline/config.yaml`. Follow the fail-fast protocol in
`core/contracts/pipeline-config.md`: stop and name the exact missing key
if the file or a key this phase needs is absent. This phase needs
`commands.test`, `commands.test_all`, `commands.lint`, `paths.specs`,
`paths.conventions`, and `git.commit_trailer`. If `commands.typecheck` is
set in the project's configuration, this phase also needs it.

## Step 1 — Read the handoff log

Read `paths.specs/<task-id>.md` in full, per `core/contracts/spec-template.md`
— not only `## Definition of Done`, but `## Approach` and `## Files to
Modify`, which name the files, functions, and data this phase must
produce.

Then read the `## Agent Handoff Log` section in full, per
`core/contracts/handoff-log.md`. The test phase that ran immediately before
this one left findings there: the path to the test files it wrote, mock or
fixture patterns established for this task, whether it found a testing
section in the conventions file, and any deviation it made from the spec.
Reusing what it already documented is cheaper than rediscovering it — a
mock pattern invented twice, once by the test phase and once by this one,
is a sign this step was skipped. If the log is empty or missing, proceed,
but expect to spend more effort locating patterns this step would
otherwise have handed over.

Map every `## Definition of Done` item to a concrete, verifiable check:
a specific test passing, a lint run coming back clean, a type-check
passing, an endpoint returning a specific shape. An item with no
attached check is a sign the item is not actually verifiable yet — resolve
that before moving on, rather than discovering it at Step 7.

An item that is ambiguous, or that contradicts a rule in
`paths.conventions`, must be flagged now, before any code is written. The
cost of surfacing a bad requirement rises steeply once implementation has
started — cheap to raise here, expensive to unwind three files in.

### Stop-and-escalate conditions

Three further conditions call for the same treatment, wherever in this
phase they surface, not only at intake:

- A Definition of Done item that is technically impossible given existing
  constraints must never be silently dropped. Explain why it cannot be
  satisfied as written, and propose the closest valid alternative.
- If implementing one Definition of Done item breaks another, resolve the
  conflict explicitly and document the trade-off in the handoff log —
  never pick one silently and let the other regress unremarked.
- If the task turns out to require touching infrastructure or deployment
  configuration beyond what the task's own scope implied, stop and ask
  before proceeding, rather than expanding scope unilaterally.

## Step 2 — Plan before editing

Before touching any file:

- **Explore the codebase.** Identify every file the task needs created or
  modified, and read it, or its nearest analogue, before writing anything.
  Never guess a file's location or an existing function's name — read the
  actual directory tree and existing imports.
- **Trace the dependency chain.** Understand how the pieces named in
  `## Approach` call each other, so the order of implementation follows
  the order of dependency rather than the order the files happen to be
  listed.
- **Mirror existing patterns.** Find analogous files already in the
  codebase — a similar endpoint, a similar component, a similar module —
  and match their structure, naming, and style. A codebase where every
  file looks like it was written by a different author, because each task
  invented its own shape, is harder for a human to maintain than one where
  new code reads like it always belonged.
- **State the plan**: which files will be created or modified, in what
  order, and why, before writing the first line.

## Step 3 — Load project conventions

Read the file at `paths.conventions`. This is the project's own record of
how it wants code written — layering, error handling, naming, the specific
rules of its stack — and it is what keeps this phase's output consistent
with the rest of the codebase without a phase file hardcoding rules for one
particular language or framework. For each area this task's changes touch
(for example: how errors propagate, how a new endpoint or entry point is
wired, how a schema field is validated, how authorization is checked, how a
UI element is composed), extract the applicable rule and apply it during
Step 5.

Record what was applied, in the handoff log (Step 9), in exactly this
shape:

```markdown
### Conventions Applied
- <rule text> — conventions:<line>  → applied at <file>:<line>
- No rule found covering <area> — flagging for review
```

A "no rule found" line is a required output when it is true, not an
admission of failure. The conventions file cannot cover every area every
task will ever touch, and the only way the project ever finds out where
its conventions are thin is if this phase says so plainly when it hits
one. Omitting the line because an empty-handed search feels like a
shortcoming defeats the entire reason this step exists: the next flow that
maintains the conventions file relies on exactly this signal to know where
to write a new rule, and a phase that stays silent here erases that signal
for good. Write the line every time it applies, with the same directness
as any other finding.

If the task changes the database schema or another migration-bearing
structure, follow the migration procedure documented at `paths.conventions`.
If no such procedure is documented there, stop and ask rather than
guessing a migration command — an invented migration step is exactly the
kind of unattended wrong guess the fail-fast protocol in
`core/contracts/pipeline-config.md` exists to prevent.

## Step 4 — Test protection contract

The tests committed by the test phase are the contract for this task, not
a draft this phase is free to negotiate. They were written specifically so
that an implementation satisfying every one of them has satisfied the
spec — weakening a test to make it pass is indistinguishable, from the
suite's perspective, from the behavior it was meant to guard never having
been built at all. The whole value of a red-then-green pipeline collapses
the moment the phase making tests pass is also allowed to rewrite what
"pass" means.

- **Never modify an existing assertion to make the implementation pass.**
  If a test expects a specific status, value, or error, the implementation
  must produce that outcome — the test does not move to meet the code.
- **Never delete an existing test.** Every test that survived the test
  phase exists to guard a specific piece of behavior; deleting it deletes
  the guard, silently, for whoever reads the suite later and assumes it
  still covers what it once did.
- **Never weaken a test condition** — loosening an exact match to a
  substring check, dropping an edge-case assertion, relaxing a mock's
  expected call count or arguments. A weakened test still looks green; it
  no longer proves what it once proved.
- **You may add new tests** for scenarios this phase discovers during
  implementation that the test phase did not cover.
- **You may fix genuine infrastructure bugs in test code** — a broken
  import, a wrong fixture path, a typo in a test helper. These are defects
  in the scaffolding around the contract, not changes to the contract
  itself.
- **Tie-breaker, applied without judgment: if a scaffolding fix would
  change any assertion's effective expected value, it is not a scaffolding
  fix.** A fixture can be wrong in a way that also supplies the value an
  assertion checks against, so "correcting the fixture" and "changing what
  the test expects" can be the same edit under two different names. Do not
  weigh how reasonable the fix looks in the moment — check only whether an
  assertion's effective expected value changes. If it does, treat the whole
  edit as a test-appears-wrong case below, not as an infrastructure fix,
  regardless of how the rest of the change looks.
- **If a test appears wrong** — its expectation seems to contradict the
  spec, or an edge case looks mis-specified — do not change it silently.
  Implement toward the spec, document the conflict in the handoff log
  (Step 9) with the specific test, the specific disagreement, and the
  reasoning, and let the code-review phase adjudicate. A silent rewrite
  forecloses that adjudication before it can happen.

## Step 5 — Implement

Implement the change file by file, in the dependency order established in
Step 2. Write complete code — no placeholders or stubbed-out branches
unless the Definition of Done explicitly allows them. Mirror the exact
style, naming, and import pattern of the analogous files identified in
Step 2, and apply the conventions extracted in Step 3.

## Step 6 — Self-review

After implementing each file or logical chunk, review it critically before
moving to the next one:

- **Correctness** — does this satisfy the Definition of Done item it
  targets?
- **Convention compliance** — does it match the rules extracted in Step 3?
- **Security and isolation** — is authorization checked where the
  conventions require it; can one account's action reach another
  account's data?
- **Type and shape safety** — do the types, schemas, or interfaces this
  code introduces or touches actually match what the rest of the codebase
  expects?
- **Edge cases** — not-found, empty input, boundary values: handled, or
  silently assumed away?

Rewrite anything that fails this review before proceeding to the next
chunk. A chunk reviewed only after the whole task is "done" costs far more
to fix than one reviewed while it is still fresh and isolated.

## Step 7 — Verification loop

For each Definition of Done item and its attached check from Step 1:

1. Run the verification: `commands.test` (with `{target}` substituted for
   the module or file this task's tests live in), `commands.test_all`, or
   `commands.typecheck` where set, or a manual trace where no automated
   check applies.
2. If it fails, diagnose the root cause and fix the implementation — never
   the test, per the contract in Step 4 — then re-run.
3. Do not mark a Definition of Done item complete until its check passes.

Repeat until every item is verified. Then run `commands.test_all` once
more, in full, to confirm nothing this task touched broke a previously
passing test elsewhere in the suite.

## Step 8 — Lint gate

After every test passes, run `commands.lint` and, when set,
`commands.typecheck`. Fix every violation they report. A task is not
complete until both the test suite and the lint gate are clean —
do not proceed to Step 9 with either one still failing. If fixing a lint
violation changes behavior, re-run Step 7 before continuing, since a fix
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

  Write one line per Definition of Done item, mapping it to the file and
  line that satisfies it, and one further line for anything security- or
  checklist-relevant the change touched, even when it is not itself a DoD
  item — a new entry point and the authorization guard on it, input
  validation added, a schema change, a secret or credential path. A change
  that touches none of these has no such line to add; a change that
  touches one and reports nothing forces the code-review phase to hunt for
  it with no starting point.

  Every line is an assertion about the code that the code-review phase will
  check against the code, not a summary of what happened — treat it with
  the same weight as a test assertion. A manifest line that overstates or
  misdescribes what the cited code actually does is worse than no manifest
  at all, because it sends the reviewer's attention to a spot that confirms
  a false claim instead of toward wherever the real gap is. Write only
  what the cited line actually demonstrates; if a Definition of Done item
  is not yet satisfied, say so instead of writing a line that reads as if
  it is.

- The `### Conventions Applied` block from Step 3, in full.
- Deviations from the spec made during implementation, and the reasoning
  for each.
- Any test that appeared wrong under Step 4, with the specific conflict
  documented for the code-review phase to adjudicate.
- Non-obvious implementation decisions a reviewer should know about before
  judging the diff.
- Anything discovered during implementation that was not anticipated by
  the spec.

Apply the escalation routing table in `core/contracts/handoff-log.md`: a
finding that is a durable fact about this codebase belongs in
`paths.conventions`, not buried here as a task-only detail. Note any such
escalation here as well, so a later reader of this log knows the finding
was acted on rather than dropped.

## Step 10 — Commit

Stage the implementation files from Step 5 and the spec file's updated
handoff log, then commit:

```bash
git add <implementation files> <spec file>
git commit -m "<task-id>: implement <short description>"
```

Stage specific files — never `git add .` or `git add -A`. If
`git.commit_trailer` is non-empty, append it as a trailer on the commit
message. If it is empty, omit it entirely — do not add an empty trailer
line.

## Step 11 — Report

Return a report of at most 300 characters, in exactly this shape:

```
Implemented: <summary>. Tests: pass (<N>). Lint: clean. Committed: yes.
```

Everything else — the conventions block, deviations, test conflicts,
implementation decisions — belongs in the handoff log written in Step 9,
never in this report. The next phase runs in a fresh context with no
memory of this one; the handoff log is the only place it can read what
happened here.
