# Phase: test

Write the failing test suite for one task before any implementation exists.
This is the red phase: the tests define the contract execute must satisfy,
and they must fail first, or nothing proves the contract was unmet.

The argument is a task ID (for example `TASK-1`). If none is given, derive it
from the current branch name.

## Step 0 — Load configuration

Read `.tdd-pipeline/config.yaml`. Follow the fail-fast protocol in
`core/contracts/pipeline-config.md`: stop and name the exact missing key if
the file or a key this phase needs is absent. This phase needs
`commands.test`, `commands.test_all`, `paths.tests`, `paths.specs`,
`paths.conventions`, and `git.commit_trailer`.

## Step 1 — Load the spec

Read `paths.specs/<task-id>.md` in full, per
`core/contracts/spec-template.md` — not only `## Definition of Done`.
`## Approach` and `## Files to Modify` name the files, functions, and data
this phase must exercise, and `## Out of Scope` rules out cases that would
otherwise look like missing coverage.

Read `## Agent Handoff Log` in full too, per
`core/contracts/handoff-log.md`. A planning conversation or an earlier phase
may already have left constraints, resolved ambiguities, or fixture patterns
there.

## Step 2 — Study existing test patterns

Before writing anything, read a representative sample of the tests already in
`paths.tests` — a list, so check every directory it names (a project that
separates unit and integration tests names both). Match the project's file
naming, test structure, setup and teardown, and how dependencies outside the
code under test are isolated.

Then read `paths.conventions` and follow its testing section. It takes
precedence over a pattern merely inferred from `paths.tests`, since a
convention was written down for a reason.

If `paths.conventions` has no testing section, record the gap: this phase
found no testing conventions on file. That absence goes in the handoff log
(Step 6) as concretely as any other finding. It is the required output in
this case, not a shortcoming to hide — it is what lets the conventions flow
know a gap remains, and a phase that silently moves on erases that signal.

## Step 3 — Design the test plan

Enumerate what the suite needs to cover before writing any test, so coverage
is a deliberate choice rather than whatever came to mind first. Work through
every dimension that applies:

- **Happy path** — the behavior the task exists to deliver, under normal
  input.
- **Validation errors** — malformed, missing, or out-of-range input rejected
  the way the spec or the project's error-handling convention says.
- **Not-found** — a reference to something that does not exist, handled
  distinctly from a validation error.
- **Authorization** — an actor lacking permission, denied rather than
  silently succeeding or silently scoping to less data than expected.
- **Edge cases** — boundary values, empty collections, the largest or
  smallest accepted input.
- **Side effects** — anything the change writes, sends, or triggers
  elsewhere, verified to happen (or, for a negative case, not to).
- **Isolation between accounts or tenants** — where the codebase has separate
  owners of data, a test proving one owner cannot read or affect another's.

The spec's `## Out of Scope` and the task's nature decide which apply.
Skipping one that clearly applies because it was inconvenient is a gap the
next phase inherits silently.

## Step 4 — Write the tests

Write the suite into whichever `paths.tests` directory pairs with the code
under test, following Step 2's patterns. Hold every test to these standards:

- **Descriptive names.** The name states the behavior and the condition, so a
  failure is legible from the runner's output without opening the file.
- **Independence.** Any test runs alone, or in any order, with the same
  result. One that passes only because an earlier test left state is not
  independent.
- **External dependencies mocked or faked.** A network call, another service,
  the clock, a source of randomness — replaced with a controlled substitute,
  so a failure indicates a defect in the code under test.
- **No superficial assertions.** "No exception was thrown" or "a response
  object exists" passes on a broken implementation as reliably as on a
  correct one. Assert the real value.
- **No testing of internals.** Assert on observable behavior — inputs and
  outcomes — not on private state the execute phase may change freely.

Write the tests as the actual contract: specific enough that an
implementation satisfying every one has satisfied the spec, and no test
merely restating the implementation the author already had in mind.

## Step 5 — Verify the tests fail

Run `commands.test`, with `{target}` substituted for the module or file this
task's tests live in. Confirm every new test describing unimplemented
behavior fails, and fails **for the reason it asserts** — not from a typo, an
import error, or a broken fixture, all of which look red and prove nothing.
Regression guards are the deliberate exception, below.

If a new test unexpectedly passes against pre-implementation code, find out
*why* before assuming a defect. Two situations produce the same green and
call for opposite responses:

- **The behavior it checks already exists**, unrelated to what this task
  adds — a regression guard proving a preservation criterion in
  `## Definition of Done` still holds. It is *supposed* to be green now;
  that is why it was written alongside the new tests rather than after. Keep
  it, and note in Step 6 that it is a regression guard passing by design, so
  execute and code-review do not expect it to flip red.
- **It does not actually exercise the new behavior** — a typo, an import
  error, a broken fixture, an assertion too weak to distinguish the old code
  path from the new, or a case the old code handled by coincidence. This is
  the defect this step exists to catch: rewrite the test so it genuinely
  fails for the reason it claims.

The distinction is whether the spec asked this test to guard something that
must keep working (keep it) or to describe something new (fix it). When
unclear, re-read `## Definition of Done` before deciding — guessing risks
deleting the one test standing between this task and a silent regression.

Then, **if `policy.full_suite` is `every_phase`**, run `commands.test_all` to
confirm the new tests broke nothing already passing. Under any other value skip
it: at this point no implementation exists, so the only regression a new test
file can cause in another is through shared state — a fixture, a global mock, a
database left dirty — and the execute phase's own broad run catches that later,
with the code in place. This is the least load-bearing of the broad runs and the
first one a project trades away.

If `commands.test` cannot be run at all — the command is missing, the
environment was never built, a permission denies it — this phase has not
observed red and must not claim it. Report `Status: unverified` in Step 8,
naming what failed and what was tried, and commit nothing. Red is a
observation, not an inference from having written tests that ought to fail:
a phase that reports red it never saw hands execute a contract nobody
confirmed was unmet.

### When nothing in the task is testable

Some changes have no observable behaviour to assert: prose a reader consumes,
a comment, a document, a rename with no runtime effect. For those there is no
red to observe, and the two wrong answers are fabricating a test that fails
for a manufactured reason, and reporting `unverified`, which says the suite
could not run when in truth there was nothing to run.

Report `Status: n/a (nothing testable)` instead, and earn it. Walk
`## Definition of Done` item by item and state, one line each in Step 6, what
`commands.test` would have to observe for that item and why nothing can. An
item that names a file's contents, an exit code, a rendered string, or any
value a command can read is testable — write the test. This path is for the
case where every item fails that question, not for the case where finding the
assertion is hard.

Two rules keep this from becoming the easy exit:

- **Never reach for it before Step 3 has produced a test plan.** The plan is
  what makes the claim checkable; without one this is an assertion that
  testing was impossible, made by the party who would otherwise have to do
  it.
- **A single testable item disqualifies the whole task.** Write the tests for
  that item and report red as usual, noting the untestable remainder in
  Step 6. Mixed tasks are red tasks.

The code-review phase adjudicates the claim against the same spec, so an
`n/a` reported to avoid the work is a finding there rather than a shortcut.

### Proving the contract is satisfiable

Red is not the same as correct. A suite failing because the module it imports
does not exist has proved only that the module does not exist — nothing about
whether the expectations inside those tests can be met at all.

That gap matters whenever the tests carry **expected values the author
computed rather than observed**: a financial calculation, a rounding rule, a
normalization, a parser — anything whose assertions are dense with literal
numbers or strings. If one literal is wrong, execute cannot tell whether the
test or its own implementation is at fault, and its test-protection contract
says the tests are the contract. So it bends the implementation to match a
wrong number, and every downstream gate agrees, because the suite is green
and nothing there has an independent source to check against.

When this task's tests are of that kind, prove the contract satisfiable
before committing:

1. Confirm the suite is red for the right reason, per the checks above.
2. Write a throwaway reference implementation **outside the repository** — a
   scratch location, never a path under version control.
3. Put it in place, run this task's tests, and confirm they go green **with
   no errors and no warnings**, not merely that the failure count hit zero.
4. Remove it, and verify the removal mechanically with `git status` — the
   only files that may remain untracked are the test files themselves.
5. Re-run the tests, confirming red again, before Step 7 commits anything.

The reference implementation must never be committed, and must not be where
the expected values came from. It proves the assertions are mutually
**consistent** — that one implementation can satisfy all of them at once. It
cannot prove they are **right**: an implementation written from the same
misunderstanding that produced the tests will satisfy them perfectly. Anchor
the expected values in something outside this codebase — the specification, a
provider's documentation, a worked example the spec cites — and verify them
against that source first. Without the anchor, step 3 is circular.

Skip this whole check when the tests are dominated by mocks and I/O — a
route, a handler, a service whose assertions check status codes and call
shapes rather than computed values. There an import error is the whole of
what red can mean, and a reference implementation would only restate the
mocks.

## Step 6 — Handoff log

Append a dated subsection to `## Agent Handoff Log` in the spec file,
following `core/contracts/handoff-log.md`. Include:

- The path to the test file(s) written and a count of tests added.
- Confirmation that the suite is red and why, each failure traced to missing
  behavior rather than a broken test — and, separately, which tests were kept
  green on purpose as regression guards.
- Whether the contract was verified satisfiable per Step 5, and what the
  expected values were anchored against — or that the check did not apply,
  and why. State this on its own line, separate from the red confirmation:
  they answer different questions, and a reader who sees only "red for the
  right reason" cannot tell which was established.
- Any mock or fixture pattern established here that execute should reuse.
- Whether `paths.conventions` held a testing section (Step 2). If it held
  none, say so explicitly — a required entry, not only a note to add when
  something was found.
- Any deviation from the spec's test expectations, and why.

Apply the escalation routing table in `core/contracts/handoff-log.md`: a
finding that is a durable fact about this codebase belongs in
`paths.conventions`, appended inside its discoveries span
(`core/contracts/conventions-template.md`) and never inside the managed
section, which the conventions flow regenerates wholesale.

## Step 7 — Commit

Stage only the test files from Step 4 and the spec file's updated handoff
log, then commit:

```bash
git add <test files> <spec file>
git commit -m "<task-id>: add failing tests"
```

If `git.commit_trailer` is non-empty, append it as a trailer; if empty, omit
it rather than adding an empty line.

## Step 8 — Report

Return a report of at most 300 characters, in exactly this shape:

```
Tests: <path>. <N> tests written. Status: <fail (red)|pass (green)|unverified|n/a (nothing testable)>. Committed: <yes|no>.
```

`Status:` is a real field with four values, not a fixed string:

- `fail (red)` — at least one new test describing behavior this task adds
  fails for the reason it asserts. The expected outcome.
- `pass (green)` — every new test passed against pre-implementation code, and
  Step 5 established that none was a regression guard.
- `unverified` — Step 5 could not run the suite, so neither of the above was
  observed. Name what failed on the same line.
- `n/a (nothing testable)` — every `## Definition of Done` item describes a
  change with no observable behaviour to assert, per Step 5's own section.
  Distinct from `unverified`: the suite could have run, and there was nothing
  for it to run.

The orchestrator branches on this field (`core/phases/pipeline.md` Step 4.1):
`fail (red)` and `n/a (nothing testable)` continue, the other two stop. Never
write a status because the report's shape shows it — a hardcoded value makes
the orchestrator's stops unreachable and hands a green, unrun, or untested
suite forward as though it were red.

Everything else — the test plan's reasoning, the conventions gap, mock
patterns, deviations — belongs in the Step 6 handoff log. The next phase runs
in a fresh context with no memory of this one; that log is the only place it
can read what happened, and the short report is what makes this pipeline
resumable from any harness.
