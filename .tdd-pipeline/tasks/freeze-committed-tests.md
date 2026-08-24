# Freeze the committed tests against the execute phase, mechanically

## Context

The rule that the execute phase may not weaken the tests the test phase
committed exists today only as prose. `core/phases/execute.md:107` states it
and `core/phases/execute.md:117` forbids weakening a condition; the only
enforcement is the code-review phase reading a diff at
`core/phases/code-review.md:98`, which that file itself calls "the only phase
positioned to catch it." A single LLM reading a diff is a single point of
failure, and it runs after the violation is already in history.

A naive gate — "the execute phase must not change anything under
`paths.tests`" — is wrong, and the prose already explains why. Three
legitimate paths produce a diff there:

1. `core/phases/execute.md:120` grants "You may add new tests" for scenarios
   the test phase did not cover. Unconditional, and directed rather than
   tolerated.
2. `core/phases/execute.md:122` grants "You may fix genuine infrastructure
   bugs in test code" — a broken import, a wrong fixture path, a typo in a
   helper. This modifies an existing file.
3. The lint gate at `core/phases/execute.md:179` runs `commands.lint`, which
   is a whole-repository invocation in the general case. A formatter with
   autofix touches test files with no agent intent at all.

Path 2 is why the prose spends its longest bullet, at
`core/phases/execute.md:125`, on a content tie-breaker rather than a path
rule: the prose has already concluded that a path-level rule cannot separate
a scaffolding fix from a weakening edit. So the mechanical gate must claim
only what code-review structurally cannot — running before the commit, and
being deterministic — and must leave content adjudication where it is.

Two facts constrain the implementation and were verified against the code:
`core/phases/execute.md:14` does not list `paths.tests` among the keys the
phase loads, so the phase cannot read the key it would enforce; and no script
under `checks/` reads `.tdd-pipeline/config.yaml` at all, so nothing in this
repository parses YAML today.

## Approach

The gate is a precondition on what the execute phase **stages**, not on what
exists in the working tree. `core/phases/execute.md:243` already requires
staging specific files and forbids `git add .` and `git add -A`, so a
formatter that touched a test file never reaches the index and therefore
never reaches the commit. That single framing removes path 3 above without
any special case, and it removes the false-positive class that would
otherwise fail the phase after its own lint gate had passed.

**1. The invariant.** No file under `paths.tests` that already existed at the
execute phase's entry may appear in the index as modified or deleted.
Additions are legal, preserving `core/phases/execute.md:120`. This is a
strictly narrower claim than the prose rule and does not restate it.

**2. The baseline.** The execute phase records `git rev-parse HEAD` at Step 2,
before any edit, and the gate compares the index against that commit. This
identifies the phase's own diff, which is the invariant that matters, and it
needs no new git state, no commit-message parsing, and no marker the `doctor`
flow would have to learn about. When `core/flows/resume.md` dispatches
execute a second time, the recorded HEAD contains the first pass and the gate
correctly governs only the second.

**3. Where it runs.** A new step immediately before `## Step 10 — Commit`,
after the files are staged and before `git commit`. This renumbers the
existing Steps 10 and 11.

**4. Behaviour on a violation.** A hard stop, routed through the escalation
path `core/phases/execute.md:132` already defines for a test that appears
wrong: record the specific file and the disagreement in the handoff log and
stop, letting the code-review phase adjudicate. This converts
`core/phases/execute.md:122` from a permission the phase grants itself into
an exception a reviewer sees. That behavioural change is written into Step 4
of that file, not only into the check.

**5. Reading `paths.tests`.** `core/phases/execute.md:14` gains `paths.tests`
in its Step 0 key list, which makes the fail-fast protocol at
`core/contracts/pipeline-config.md:116` stop the phase on a project that does
not set it — correct, since the phase can no longer do its job without it.

**6. The repository-level checker.** A new `checks/` script implements the
comparison so the logic is tested rather than only described. It reads the
`paths.tests` list from `.tdd-pipeline/config.yaml`, which is a new capability
for this directory and the reason the script needs real tests. The parser
handles both list forms the documentation blesses — the flow sequence
`tests: [tests]` at `core/contracts/pipeline-config.md:42` and a block
sequence — and must survive a comment between the `paths:` key and its child,
which this repository's own configuration has. It anchors on the `paths:`
block by indentation rather than matching a bare `tests:` anywhere in the
file, strips trailing comments without cutting inside a quoted value, and
stops with the exact template at `core/contracts/pipeline-config.md:132` when
the key is absent rather than failing open.

## Files to Modify

- `checks/manifest.txt` — the `core/phases/execute.md` row gains the new step
  and renumbers `## Step 10 — Commit` and `## Step 11 — Report`. Committed
  before the file is edited.
- `core/phases/execute.md` — Step 0 gains `paths.tests`; Step 4 states that a
  scaffolding fix touching an existing test file is now a stop rather than a
  self-granted permission; a new step before Commit runs the gate; the two
  trailing steps renumber. Step 10's staging instruction also gains the test
  files added under the Step 4 grant, which today have no staging instruction
  anywhere in the phase.
- `checks/<new>.sh` — the checker. Executable, `#!/usr/bin/env bash`,
  `set -uo pipefail` without `-e`, `cd "$(dirname "$0")/.." || exit 1`,
  accumulating into `rc`, `exit $rc`, exit 2 for a caller error and 1 for a
  finding, naming the exact failing file.
- `tests/run.sh` — one `assert_executable` in the block at lines 25-28, and
  the assertions appended after line 76 so the citations at `CLAUDE.md:100`,
  `CLAUDE.md:104` and `CLAUDE.md:106` keep resolving.
- `tests/cases/<new>.sh` — a scratch-repository case, since the gate compares
  git state. Follows `tests/cases/install-cursor.sh:2` — `set -euo pipefail`,
  `mktemp -d`, `trap` on EXIT, `git init -q`.
- `tests/fixtures/` — accept, reject and `-lookalike` fixtures for the
  configuration parser.
- `.tdd-pipeline/config.yaml` — the new checker appended to the
  `commands.lint` chain.
- `README.md` — line 356 says "the five gates" and becomes wrong at six; the
  phases sentence at lines 45-47; the constraints section at line 317.

## Definition of Done

- [ ] The gate rejects a staged modification and a staged deletion of a file
      under `paths.tests` that existed at the recorded baseline, and accepts a
      staged addition.
- [ ] A formatter change to a test file that is never staged does not trip the
      gate.
- [ ] `core/phases/execute.md` Step 0 lists `paths.tests`, and the phase stops
      with the template at `core/contracts/pipeline-config.md:132` when the key
      is absent.
- [ ] Step 4 of `core/phases/execute.md` states the changed status of a
      scaffolding fix, and routes a violation to the handoff log per the
      existing escalation path at `core/phases/execute.md:132`.
- [ ] The `checks/manifest.txt` row was committed before the renumbering of
      `core/phases/execute.md`, per `checks/manifest.txt:2` and `CLAUDE.md:110`.
- [ ] The checker accepts an argument that swaps its target for a fixture, per
      `CLAUDE.md:101`.
- [ ] `tests/run.sh` asserts the checker is executable, asserts one accepting
      and one rejecting case, asserts a `-lookalike` near-miss proving a
      directory such as `tests-helpers` is not `tests`, and asserts the checker
      against the real repository — per `CLAUDE.md:99`, `CLAUDE.md:103`,
      `CLAUDE.md:105` and `CLAUDE.md:107`.
- [ ] The checker is clean under `shellcheck` and appended to `commands.lint`.
- [ ] `README.md` no longer claims five gates.
- [ ] Every `file:line` citation in `CLAUDE.md` pointing into a file this task
      edited still resolves, checked line by line per
      `core/phases/code-review.md:73`. `CLAUDE.md:95` cites
      `core/phases/execute.md:257` and `CLAUDE.md:114` cites `tests/run.sh:78`;
      both shift under this change.
- [ ] `checks/core-is-neutral.sh` exits 0. No test runner, package manager or
      linter is named in any `core/` file — `pytest`, `jest`, `npm` and
      `prettier` are all rejected tokens, per `CLAUDE.md:12`.
- [ ] `./tests/run.sh` exits 0 and the full `commands.lint` chain exits 0.

## Out of Scope

- The spec-adoption seam, specified in `adopt-existing-spec.md`.
- Content-level adjudication of a test change. `core/phases/code-review.md:98`
  keeps it, including the tie-breaker; this gate is structural only and does
  not restate it.
- Any marker written into git — a tag or a note — to identify the test
  phase's commit. The recorded baseline makes it unnecessary here, though it
  would also serve `core/phases/code-review.md:103`, which identifies that
  commit by prose judgment today.
- A general YAML parser. The script reads one key and stops.
- The `core/flows/fix-bug.md` green step, which inlines its own no-weakening
  rule at `core/flows/fix-bug.md:198` and never dispatches this phase.

## Agent Handoff Log
<!-- Phases append findings here — see handoff-log.md -->
