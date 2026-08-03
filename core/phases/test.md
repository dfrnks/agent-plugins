# Phase: test

Write the failing test suite for one task before any implementation exists.
This is the red phase of test-driven development: the tests define the
contract the execute phase must satisfy, and they must fail before that
phase starts, or there is nothing proving the contract was unmet.

The argument to this phase is a task ID (for example `TASK-1`). If none is
given, derive it from the current branch name.

## Step 0 — Load configuration

Read `.agent-pipeline/config.yaml`. Follow the fail-fast protocol in
`core/contracts/pipeline-config.md`: stop and name the exact missing key
if the file or a key this phase needs is absent. This phase needs
`commands.test`, `commands.test_all`, `paths.tests`, `paths.specs`,
`paths.conventions`, and `git.commit_trailer`.

## Step 1 — Load the spec

Read `paths.specs/<task-id>.md`, the task spec described in
`core/contracts/spec-template.md`. Read the whole file, not only
`## Definition of Done` — `## Approach` and `## Files to Modify` name the
files, functions, and data this phase must exercise, and `## Out of Scope`
rules out cases that would otherwise look like missing coverage.

Also read the `## Agent Handoff Log` section in full, per
`core/contracts/handoff-log.md`. A planning conversation or an earlier
phase may have already left constraints, resolved ambiguities, or fixture
patterns there; skipping this step means re-deriving something already
settled.

## Step 2 — Study existing test patterns

Before writing anything, read a representative sample of the tests already
in `paths.tests`. Match the project's existing style: file naming, how a
test is structured, how setup and teardown are handled, how dependencies
outside the code under test are isolated. A test suite where every file
looks hand-written by a different author, because each phase run invented
its own conventions, is harder for a human to maintain than one where every
file looks like the others.

Then read the file at `paths.conventions` and follow its testing section.
That file is the project's own record of how it wants tests written —
naming, fixture layout, isolation strategy, anything specific to this
codebase — and it takes precedence over a pattern merely inferred from
`paths.tests`, since a convention was written down for a reason.

If `paths.conventions` has no testing section, do not proceed as though
nothing was expected. Record the gap: this phase found no testing
conventions on file. That absence goes in the handoff log (Step 6) exactly
as concretely as any other finding — reporting "no rule existed here" is
the required output in this case, not a shortcoming to hide, because it is
what lets the conventions flow later know a gap remains. A phase that
silently finds nothing and moves on erases the one signal that flow needs.

## Step 3 — Design the test plan

Before writing any test, enumerate what the suite needs to cover. Do not
write tests as they occur to you — decide the plan first, then implement
it, so coverage is a deliberate choice rather than whatever came to mind
first. Work through every dimension that applies to this task:

- **Happy path** — the behavior the task exists to deliver, under normal
  input.
- **Validation errors** — malformed, missing, or out-of-range input
  rejected the way the spec (or the project's existing error-handling
  convention) says it should be.
- **Not-found** — a reference to something that does not exist, handled
  distinctly from a validation error.
- **Authorization** — an actor who lacks permission for this action,
  denied rather than silently succeeding or silently scoping to less data
  than expected.
- **Edge cases** — boundary values, empty collections, the largest or
  smallest input the code accepts.
- **Side effects** — anything the change under test writes, sends, or
  triggers elsewhere, verified to happen (or, for a negative case, verified
  not to happen).
- **Isolation between accounts or tenants** — when the codebase has any
  notion of separate owners of data, a test proving one owner's action
  cannot read or affect another owner's data.

Not every dimension applies to every task; the spec's `## Out of Scope`
section and the task's own nature decide which do. Skipping a dimension
that clearly applies because it was inconvenient to test is a gap the next
phase inherits silently.

## Step 4 — Write the tests

Write the suite into `paths.tests`, following the patterns identified in
Step 2. Hold every test to these standards:

- **Descriptive names.** A test's name states the behavior and the
  condition, so a failure is legible from the test runner's output alone,
  without opening the file.
- **Independence.** Any test can run alone, or in any order relative to
  the others, and produce the same result. A test that only passes because
  an earlier test left behind state is not independent.
- **External dependencies mocked or faked.** Anything outside the code
  under test — a network call, another service, the system clock, a
  source of randomness — is replaced with a controlled substitute, so a
  failure indicates a defect in the code under test, not in something the
  test doesn't own.
- **No superficial assertions.** A test that only checks "no exception was
  thrown" or "a response object exists" without checking its actual
  content or effect passes on a broken implementation exactly as
  reliably as a correct one. Assert the real value.
- **No testing of internals.** Assert on observable behavior — inputs and
  outcomes — not on private state or implementation detail that the
  execute phase is free to change without breaking the contract.

Write the tests as the actual contract for this task: specific enough that
an implementation satisfying every test has satisfied the spec, and no test
merely restates the implementation the author already had in mind.

## Step 5 — Verify the tests fail

Run `commands.test`, with `{target}` substituted for the module or file
this task's tests live in. Confirm every new test fails, and that each one
fails for the reason the test asserts — not from a typo, an import error,
or a broken fixture, all of which produce a failure that looks red but
proves nothing about the contract.

If a new test unexpectedly passes against the current, pre-implementation
code, treat that as a defect in the test, not a shortcut: figure out why it
passed before implementation exists, and fix the test so it genuinely
exercises the missing behavior.

Then run `commands.test_all` to confirm the new tests did not break any
existing, previously-passing test in the suite.

## Step 6 — Handoff log

Append a dated subsection to `## Agent Handoff Log` in the spec file,
following `core/contracts/handoff-log.md`. Include:

- The path to the test file(s) written and a count of tests added.
- Confirmation that the suite is red, and why (each failure traced to
  missing behavior, not a broken test).
- Any mock or fixture pattern established here that the execute phase
  should reuse rather than reinvent.
- Whether `paths.conventions` held a testing section (Step 2). If it held
  none, say so explicitly here, so the conventions flow can close the gap
  — this is a required entry, not only a note to add when something was
  found.
- Any deviation from the spec's test expectations, and the reasoning.

Apply the escalation routing table in `core/contracts/handoff-log.md`: a
finding that is a durable fact about this codebase (a project convention)
belongs in `paths.conventions`, not buried here as a task-only detail.

## Step 7 — Commit

Stage only the test files written in Step 4 and the spec file's updated
handoff log, then commit:

```bash
git add <test files> <spec file>
git commit -m "TASK-1: add failing tests"
```

If `git.commit_trailer` is non-empty, append it as a trailer on the commit
message. If it is empty, omit it entirely — do not add an empty trailer
line.

## Step 8 — Report

Return a report of at most 300 characters, in exactly this shape:

```
Tests: <path>. <N> tests written. Status: fail (red). Committed: yes.
```

Everything else — the test plan's reasoning, the conventions gap, mock
patterns, deviations — belongs in the handoff log written in Step 6, never
in this report. The next phase runs in a fresh context with no memory of
this one; the handoff log is the only place it can read what happened
here, and the short report is what makes it possible to resume this
pipeline from any harness, not only the one that ran this phase.
