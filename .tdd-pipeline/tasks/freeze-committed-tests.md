# Freeze the committed tests against the execute phase, mechanically

## Context

The rule that the execute phase may not weaken the tests the test phase
committed exists today only as prose. `core/phases/execute.md:107` states it
and `core/phases/execute.md:117` forbids weakening a condition. The only
enforcement is the code-review phase reading a diff, which
`core/phases/code-review.md:101` itself calls "the only phase positioned to
catch it" — a single model reading a diff, running after the violation is
already in history.

A naive gate — "the execute phase must not change anything under
`paths.tests`" — is wrong, and the prose already explains why. Three
legitimate paths produce a diff there:

1. `core/phases/execute.md:120` grants "You may add new tests" for scenarios
   the test phase did not cover. Unconditional, and directed rather than
   tolerated.
2. `core/phases/execute.md:122` grants "You may fix genuine infrastructure
   bugs in test code" — a broken import, a wrong fixture path, a typo in a
   helper. This modifies an existing file.
3. The lint gate at `core/phases/execute.md:181` runs `commands.lint`, which
   is a whole-repository invocation in the general case. A formatter with
   autofix touches test files with no agent intent at all.

Path 2 is why the prose spends its longest bullet, at
`core/phases/execute.md:125`, on a content tie-breaker rather than a path
rule: it has already concluded that a path-level rule cannot separate a
scaffolding fix from a weakening edit. So the mechanical gate must claim only
what code-review structurally cannot — running before the commit, and being
deterministic — and must leave content adjudication where it is.

Two constraints on the implementation, both verified against the code. The
gate cannot live in a script under `checks/`: that directory is this
repository's own infrastructure and is never installed into a consuming
project. `install.sh:81` links only `core/` and the adapter, `core/` may not
name another top-level directory, and `CLAUDE_PLUGIN_ROOT` — the only
variable naming the plugin's location — is a token
`checks/core-is-neutral.sh:11` rejects inside `core/`. A checker there would
also `cd` to its own repository root by house convention and inspect the
wrong tree entirely. And the gate cannot read `paths.tests` by parsing YAML:
the established pattern is substitution of a value the phase agent already
holds from its Step 0 read, exactly as `core/phases/pipeline.md:79`
substitutes `git.worktree_setup` into a command.

## Approach

The gate is a fenced conditional inside `core/phases/execute.md`, on the
model of `core/phases/pipeline.md:37` — "a real conditional that stops the
phase, not a comment an agent has to notice and act on." It ships wherever
`core/` ships, on both harnesses, and names no tool outside itself.

**1. The invariant, compared against the worktree rather than the index.**
No file under `paths.tests` that exists at `HEAD` may differ from `HEAD` when
the phase reaches its commit:

```bash
git diff --name-only --diff-filter=MD HEAD -- <paths.tests>
```

Empty output means the committed tests are intact and the phase proceeds.
Any output names the files that must be dealt with before it may commit.
`--diff-filter=MD` excludes additions, so
`core/phases/execute.md:120` is preserved; a newly added file is untracked
and never appears in this diff at all.

Comparing the worktree and not the index is the load-bearing choice. A gate
on the staged set is bypassed by the mechanism it depends on: the test runner
reads the worktree, so an agent that weakens a test and simply never stages
it goes green at `core/phases/execute.md:173`, passes a staged-set gate, and
commits an implementation whose committed tests fail on a fresh checkout.
`core/phases/code-review.md:104` diffs commits and would see nothing.

**2. `paths.tests` is substituted, not parsed.** `core/phases/execute.md:15`
lists the keys this phase loads and does not include `paths.tests`; it gains
it. The fail-fast protocol at `core/contracts/pipeline-config.md:122` then
stops the phase on a project that does not set the key, with the template at
`core/contracts/pipeline-config.md:133`. The key is a list, so the command
takes every directory it names as a separate pathspec.

**3. Unintended edits are restored, not excused.** When the diff names a file
the phase did not deliberately change — the autofix case — the remedy is
stated rather than tolerated:

```bash
git checkout HEAD -- <the named file>
```

This is legitimate precisely because the phase is not allowed to change that
file: discarding the edit restores the contract. The gate then re-runs.

**4. A fourth stop-and-escalate condition, not a self-granted permission.**
`core/phases/execute.md:44` gains one: when the phase genuinely cannot
proceed without modifying a committed test file — the suite cannot execute at
all because of a defect in one, or `commands.lint` reports a violation inside
one that restoring will not clear — it writes the Step 9 handoff entry naming
the file, the specific defect, and the outcome of the tie-breaker at
`core/phases/execute.md:125`, and then stops without committing.

This is the deadlock case and it must be named, because the phase would
otherwise be unable to go green, unable to fix the cause, and unable to
report: `core/phases/execute.md:173` forbids marking an item complete until
its check passes, and `core/phases/execute.md:171` forbids fixing the test.

No new terminal state is needed. `core/phases/pipeline.md:150` already treats
any return that is not the completed shape as `STOPPED`, carrying the phase's
own account into its report, and `core/flows/resume.md:38` re-enters from the
handoff log. The Step 9 entry is written before the stop, which is why the
gate sits after Step 9 rather than inside Step 10.

**5. `core/phases/execute.md:122` narrows.** Fixing scaffolding in a
committed test file stops being a permission the phase grants itself and
becomes the exception path in item 4. Adding a new test file stays
unconditional. That is the behavioural change this task makes, and it is
written into Step 4 of that file, not only into the gate.

**6. Step numbering.** The gate becomes `## Step 10 — Test protection gate`,
placed after `## Step 9 — Handoff log`. `## Step 10 — Commit` becomes
`## Step 11 — Commit` and `## Step 11 — Report` becomes
`## Step 12 — Report`. `checks/structure.sh:18` matches each heading as a
fixed string, so `checks/manifest.txt:13` must carry all three new strings
before the file is edited.

**7. Commit staging gains the added tests.** `core/phases/execute.md:236`
stages "the implementation files from Step 5 and the spec file". A test added
under the `core/phases/execute.md:120` grant is neither, and has no staging
instruction anywhere in the phase today. The renumbered commit step names it.

## Files to Modify

- `checks/manifest.txt` — row 13 becomes, from `## Step 9 — Handoff log`
  onward: `## Step 9 — Handoff log;## Step 10 — Test protection gate;## Step
  11 — Commit;## Step 12 — Report`. Committed before the file is edited.
- `core/phases/execute.md` — `core/phases/execute.md:15` gains `paths.tests`;
  `core/phases/execute.md:44` gains the fourth stop-and-escalate condition;
  Step 4 narrows `core/phases/execute.md:122`; the new Step 10 holds the
  gate and the restore remedy; the commit step renumbers to 11 and names the
  added test files; the report step renumbers to 12.
- `CLAUDE.md` — `CLAUDE.md:95` cites `core/phases/execute.md:257`, which
  shifts when a step is inserted. Re-derive and correct it. No other
  `CLAUDE.md` citation points into a file this task edits.
- `README.md` — the constraints section at `README.md:317` gains the new hard
  constraint. `README.md:356` is not touched: this task adds no checker, so
  the count of gates is unchanged.

No new script, no fixture, no `tests/cases/` file, and no change to
`commands.lint`. Appending a checker to that chain would have been inert in
any case: `core/phases/execute.md:181` runs it at Step 8, before anything is
staged or committed.

No adapter changes. `agents/task-execute.md:7` and
`adapters/cursor/agents/task-execute.md:19` are pointers with no step-level
content, and `checks/adapters-cover-core.sh:34` enumerates only existing
files under `core/phases/` and `core/flows/`.

## Definition of Done

- [ ] `checks/manifest.txt` row 13 carries the three new heading strings, and
      `checks/structure.sh` exits 1 against the repository until
      `core/phases/execute.md` is renumbered, then 0. `tests/run.sh:65` is the
      assertion that goes red and green with it. This is the task's cycle.
- [ ] `git log --oneline --reverse -- checks/manifest.txt
      core/phases/execute.md` shows the manifest row in an earlier commit
      than the renumbering, per `checks/manifest.txt:2` and `CLAUDE.md:110`.
- [ ] `grep -n 'paths.tests' core/phases/execute.md` shows the key in the
      Step 0 list at `core/phases/execute.md:15`.
- [ ] `grep -c '^## Step ' core/phases/execute.md` returns 13, and the
      headings run Step 0 through Step 12 with no repeated number.
- [ ] The gate appears as a fenced `bash` block containing
      `git diff --name-only --diff-filter=MD HEAD` and a conditional that
      stops the phase, matching the form at `core/phases/pipeline.md:37`.
- [ ] The gate compares against `HEAD` and not the index. `grep -n 'cached'
      core/phases/execute.md` returns nothing.
- [ ] Step 10 states the restore remedy with `git checkout HEAD --` and says
      the gate re-runs after it.
- [ ] `core/phases/execute.md:44`'s list holds a fourth condition naming the
      suite-cannot-execute and lint-violation cases, and requiring the Step 9
      entry before the stop.
- [ ] Step 4 of `core/phases/execute.md` states that a scaffolding fix to a
      committed test file is now the exception path, and that adding a test
      remains unconditional.
- [ ] The renumbered commit step names the test files added under the
      `core/phases/execute.md:120` grant among what it stages.
- [ ] `git diff --name-only main...HEAD -- core/phases/pipeline.md
      core/flows/resume.md checks/` is empty: no new terminal state and no
      new checker.
- [ ] `sed -n '257p' core/phases/execute.md` is re-read and `CLAUDE.md:95`
      corrected to whatever line now holds that rule.
- [ ] `checks/core-is-neutral.sh` exits 0. No test runner, package manager or
      linter is named in any `core/` file — `pytest`, `jest`, `npm` and
      `prettier` are all rejected at `checks/core-is-neutral.sh:31`, per the
      rule at `CLAUDE.md:11`.
- [ ] `./tests/run.sh` exits 0 and the full `commands.lint` chain exits 0.
- [ ] Markdown prose under `core/` wraps at 77 columns, per `CLAUDE.md:118`.

## Out of Scope

- The spec-adoption seam, specified in `adopt-existing-spec.md`. The two
  tasks share `checks/manifest.txt`, editing different rows, and `README.md`,
  editing different sections. That task lands first; this one rebases onto it
  and re-derives its own line citations.
- Content-level adjudication of a test change. `core/phases/code-review.md:104`
  keeps it, including the tie-breaker; this gate is structural only.
- Any marker written into git to identify the test phase's commit. Comparing
  against `HEAD` at the gate makes it unnecessary, and the execute phase
  makes no commit before its own, so a baseline recorded earlier in the phase
  would be identical to `HEAD` and buy nothing.
- Unit-testing the gate's shell. It ships as prose inside a phase file, and
  this repository has no harness that executes a phase. The manifest cycle
  above is the only mechanical purchase this task has, and it proves the
  renumbering, not the conditional. Stated here rather than left for a phase
  to discover.
- The behaviour of `core/phases/end.md` toward a test file left dirty by an
  autofix. Item 3's restore removes the case this task creates; the
  pre-existing question of what the end phase does with such a file is not
  reopened here.
- The `core/flows/fix-bug.md` green step, which inlines its own no-weakening
  rule at `core/flows/fix-bug.md:198` and never dispatches this phase.

## Agent Handoff Log
<!-- Phases append findings here — see handoff-log.md -->

### review (2026-08-24)

- **The checker had nowhere to live.** The draft put the gate in a new
  `checks/` script. That directory is never installed into a consuming
  project — `install.sh:81` links only `core/` and the adapter — and on the
  other harness `core/` cannot even spell the plugin's location, because
  `CLAUDE_PLUGIN_ROOT` is a token `checks/core-is-neutral.sh:11` rejects
  there. The draft's own DoD required that checker to exit 0, so it forbade
  the one mechanism by which its script could have been found. A checker
  would also have inspected the wrong repository: the mandated
  `cd "$(dirname "$0")/.."` preamble discards the worktree cwd the phase runs
  in. Fixed: the gate is a fenced conditional inside
  `core/phases/execute.md`, on the `core/phases/pipeline.md:37` model. The
  script, its fixtures, its `tests/cases/` file and the `commands.lint`
  append are all cut.
- **The staged-set framing erased the true positive along with the false
  one.** The draft gated the index, on the grounds that
  `core/phases/execute.md:243` forbids `git add .`, so a formatter edit never
  reaches the commit. But the test runner reads the worktree: an agent that
  weakens a test and never stages it goes green at
  `core/phases/execute.md:173`, passes the gate, and commits an
  implementation whose committed tests fail on a fresh checkout —
  `core/phases/code-review.md:104` diffs commits and sees nothing. The gate
  now compares the worktree against `HEAD`, and the autofix case is handled
  by a stated restore rather than by being invisible.
- **The formatter case was displaced, not removed.** An unstaged edit to a
  frozen test file survives into the end phase, where
  `core/phases/end.md:50` reverts only files outside the task's list — and
  the test file is inside it. Either it is silently destroyed with the
  worktree or it is laundered into the ship commit. Item 3's explicit
  `git checkout HEAD --` restore removes the case at its source.
- **The stop was routed through a path whose purpose is not stopping.**
  `core/phases/execute.md:132` is continue-and-flag: it runs on to Steps 9,
  10 and 11 precisely so code-review can adjudicate. A hard stop routed
  through it would never reach the handoff log. Fixed: a fourth condition
  under `core/phases/execute.md:44`, with the Step 9 entry written before the
  stop, which is why the gate sits after Step 9.
- **The deadlock was real and unaddressed.** A broken import in a committed
  test file makes the suite unrunnable; `core/phases/execute.md:173` forbids
  completing an item, `core/phases/execute.md:171` forbids fixing the test,
  and the new rule turned `core/phases/execute.md:122` from permission into
  prohibition. The phase could neither go green, nor fix the cause, nor
  report. Now named explicitly as the exception path.
- **No new terminal state is needed after all.** `core/phases/pipeline.md:150`
  already converts any non-completed return from execute into `STOPPED`, and
  `core/flows/resume.md:38` re-enters from the handoff log. The draft implied
  changes to both files; the DoD now pins them as unchanged.
- **The YAML parser was unnecessary.** `core/phases/pipeline.md:79`
  substitutes `git.worktree_setup` into a command rather than parsing it, and
  every `commands.*` invocation works the same way. Since the phase already
  gains `paths.tests` at Step 0, it holds the value. The roughly twenty-five
  lines of awk, the indentation anchoring, the quote-aware comment stripping
  and the parser fixtures are all cut.
- **The Step 2 baseline was dead weight.** The execute phase makes no commit
  between Step 2 and its own, so a recorded `HEAD` is always identical to
  `HEAD` at the gate. There is also no precedent in `core/` for a shell
  variable assigned in one fenced block and read in a later step — each block
  is a separate invocation. Dropped, and recorded in Out of Scope so a later
  reader does not reintroduce it.
- **Appending the checker to `commands.lint` would have been inert.** That
  chain runs at `core/phases/execute.md:181`, Step 8, before anything is
  staged or committed. The draft's DoD required the wiring and the wiring
  could not fire.
- **The new step was never named.** The draft's first ordered action was
  committing a manifest row, without supplying the heading string to commit —
  and `checks/structure.sh:18` matches by fixed string. The heading is now
  given verbatim, along with the two renumbered ones.
- **Freezing `paths.tests` freezes this repository's own runner.**
  `.tdd-pipeline/config.yaml:20` sets `tests: [tests]`, which contains
  `tests/run.sh`. The concern is real but lands on the test phase, which is
  allowed to write test files, rather than on execute — a future task adding
  a checker has its assertions written in the red phase, not the green one.
  Left as-is deliberately, and noted here so the next reader does not treat
  it as an oversight.
- **The `-lookalike` requirement was misapplied and is now moot.**
  `CLAUDE.md:105` requires the near-miss to assert whichever direction a
  naive matcher gets wrong, and the draft neither fixed the exit code nor
  distinguished a parser lookalike from a path-matcher one. With no checker
  and no fixtures, the requirement no longer applies.
- **Hard blocker, external API schema: not applicable.** This task calls no
  external API.
- **Hard blocker, internal infrastructure: checked and cleared.** Every claim
  was verified by reading the cited file at the cited line. Verified against
  the working tree at commit 5337a57: `core/phases/execute.md` lines 15, 17,
  44, 107, 117, 120, 122, 125, 132, 171, 173, 181, 236, 243, 257;
  `core/phases/pipeline.md` lines 37, 79, 130, 150;
  `core/phases/code-review.md` lines 101, 104; `core/flows/resume.md:38`;
  `core/contracts/pipeline-config.md` lines 122, 133; `install.sh:81`;
  `checks/core-is-neutral.sh` lines 11, 31; `checks/structure.sh:18`;
  `checks/manifest.txt` lines 2, 13; `tests/run.sh:65`; `CLAUDE.md` lines 11,
  95, 110, 118.
- **Nine citations in the draft were wrong** and are corrected: the
  code-review quote is at `core/phases/code-review.md:101`, not 98; the
  prose-judgment sentence at `:104`, not the blank line 103; the fail-fast
  rule at `core/contracts/pipeline-config.md:122`, not the blank line 116;
  the stop template at `:133`, not the fence at 132; the Step 0 key list at
  `core/phases/execute.md:15`, not the lead-in at 14; the lint invocation at
  `core/phases/execute.md:181`, not the heading at 179; the neutrality rule
  at `CLAUDE.md:11`, not 12. The draft also claimed appending assertions
  after `tests/run.sh:76` would protect the citations at `CLAUDE.md:100`,
  `:104` and `:106`, which was false — inserting into the block at
  `tests/run.sh:25` shifts all of them. That whole edit is now cut.
- **Not split.** The task is smaller than the draft, not larger: one file
  carries the behaviour and one row carries the red.
- No escalation to the conventions file from this review. The two durable
  facts this pair of reviews surfaced were already recorded during the
  sibling's review, in the discoveries span.

