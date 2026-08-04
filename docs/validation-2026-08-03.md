# End-to-end validation — 2026-08-03

The first time this pipeline was actually run rather than reasoned about.

A throwaway Python project was created outside this repository, the package was
installed into it, and the flows in `core/flows/` were executed by following
them as written — which is what the harness does when it dispatches them. Where
something could not be executed, this document says so and says why, rather
than describing what would have happened.

This document exists to be honest, not to be green. Three criteria are not met
and one was not attempted; each is recorded with its reason.

## How this was run, and what that qualifies

- **The validation project.** A small but real Python codebase (five modules
  under `src/`, four test files, `pyproject.toml` declaring `pytest` and
  `ruff`, a git-ignored `.venv`), rather than the single-function repository
  the task brief sketched. A one-function project cannot exercise the
  criterion that matters most here: the conventions flow's rule bar requires a
  pattern to hold at two or more independent sites, so a trivial project would
  have produced an almost-empty conventions file and told us nothing about
  whether the flow works.
- **Who answered the confirmation gates.** `init`, `conventions`, and `task`
  all stop for a human. No human was present, so the agent running the
  validation answered them as the operator. This is a real qualification: it
  means the gates were exercised as control flow, not as human-factors design.
- **What ran in a genuinely fresh context.** The code-review phase of TASK-2
  and the resumed execute phase of TASK-2 were dispatched as separate
  subagents that read only the phase file, the spec, and the repository — with
  no knowledge of what had been planted. Those two results are the strongest
  evidence in this document. The remaining phases were carried out by the
  validating agent following the phase files directly.
- **Harness coverage.** The Cursor adapter was installed and its `core/`
  pointers were confirmed to resolve from inside the project. The flows were
  then executed directly against those files. No live Cursor session and no
  live Claude Code plugin session drove them, so nothing here validates either
  harness's own command routing or subagent dispatch.

## Criteria

| # | Criterion | Verdict |
|---|---|---|
| 1 | `init` produces a config naming a test command that actually runs | **MET** |
| 2 | `init` produces a conventions file with rules derived from the code, with `file:line` citations | **MET** |
| 3 | `doctor` reports all-pass on the bootstrapped project | **MET** |
| 4 | `doctor` fails on an emptied conventions section, on that row specifically | **MET** |
| 5 | The code-review phase blocks a weakened test | **MET** |
| 6 | Every phase leaves a handoff-log entry | **MET** |
| 7 | `resume` re-enters an interrupted pipeline | **MET** |
| 8 | The five gates pass over the whole repository | **MET** |
| 9 | A task reaches `SHIPPED` with an open pull request | **NOT MET** |
| 10 | Cross-harness resume: interrupt on one harness, resume on the other | **NOT ATTEMPTED** |
| 11 | The Claude Code plugin loads its five agents | **MET** (fixed after D1 — see "Defects: fix status") |

### 1 — `init` produces a config naming a test command that actually runs — MET

`init` Step 1 detected `pyproject.toml`, `pytest` (declared as a dev dependency
and configured via `[tool.pytest.ini_options]`), `ruff` (configured via
`[tool.ruff]`), the git-ignored `.venv`, and `main` as the current default
branch. Step 2's proposed `commands.test_all` was
`.venv/bin/python -m pytest -q`; run directly, it returned `13 passed`. The
`commands.lint` value returned `All checks passed!`. No command was invented:
every one was read out of configuration the project already carried, which is
what Step 1 requires.

Step 4 correctly detected a git-ignored dependency directory (`.venv`) and
therefore proposed a `git.worktree_setup` script rather than ending with
nothing to propose. That script was later run for real inside two worktrees and
built a working virtual environment in each.

### 2 — Conventions derived from the code, with `file:line` citations — MET

This is the criterion most at risk of producing a stub. It did not.

Seven exploration subagents were dispatched in parallel, one per area, exactly
as `core/flows/conventions.md` Step 1 specifies. None was told what to find.
They returned concrete instances with citations, and Step 2's rule-versus-
occurrence bar was applied to them: 26 rules across the seven area headings,
each one line, each ending in the `file:line` it was derived from, every
heading present even where it held little. Every citation was verified against
the actual file before being written down; all were accurate.

The exploration surfaced three findings nobody had planted, which is the
clearest evidence the derivation was real rather than a restatement of what the
project's author already knew:

- `src/ledger.py` imports the underscore-private `_require_owner` across a
  module boundary — the only cross-module private import in the tree.
- `rename_owner` implements a rename as a second `INSERT` against a
  `PRIMARY KEY` column, so it would surface as a storage error, not a rename.
- `list_entries` returns `[]` for an unknown account while `get_account`
  raises a not-found error — asymmetric handling, and untested.

Each was correctly held below the rule bar and recorded as an observation
rather than promoted, which is what Step 2 asks for.

### 3 — `doctor` reports all-pass — MET

Nine checks, one per row of `core/contracts/project-requirements.md`, in that
table's order: `8 pass, 0 fail, 1 n/a — ready`. The `n/a` is the tracker-auth
row under `tracker.type: none`, which is the documented behaviour. The
conditional `git.worktree_setup` row correctly resolved to `pass` rather than
`n/a`, because `.venv` is a git-ignored dependency directory.

### 4 — `doctor` fails on an emptied conventions section — MET

This is the specific silent-pass failure the whole bootstrap exists to prevent,
and it was proven by making it happen rather than by reading the rule.

The managed section's content was deleted, leaving both markers in place and
every hand-written line in the file untouched. Re-running `doctor`:

```
paths.conventions file (CONVENTIONS.md), non-empty, with derived rules  fail

7 pass, 1 fail, 1 n/a — not ready

First failure: paths.conventions file (CONVENTIONS.md), non-empty, with derived rules
  paths.conventions (CONVENTIONS.md) has 0 rule(s) in its managed section — fewer
  than the 5 required. The execute and code-review phases enforce nothing
  project-specific until this file holds real rules. Run the conventions flow to
  derive them from the codebase.
```

Exactly one row flipped, the right one, with the message template
`core/flows/doctor.md` specifies, and a named next action.

The counting rule was proven separately and matters as much: with the managed
section empty, the file still held **five** qualifying list items and headings
outside the markers — enough to clear the threshold had they been counted.
`doctor` counted `0`. Prose outside the markers does not satisfy this check,
by design, and does not in practice.

### 5 — The code-review phase blocks a weakened test — MET

The gate the pipeline's integrity rests on, exercised for the first time.

A second task (TASK-2, validating `subtract`) was run through spec, review, and
a red test phase that committed seven tests. A deliberately rogue execute phase
then made the suite pass the forbidden way — four distinct violations, one of
each kind `core/phases/execute.md` Step 4 enumerates:

1. **Deleted** `test_subtract_rejects_a_bool_second_operand` outright.
2. **Inverted** `test_subtract_rejects_a_bool_first_operand` from expecting a
   rejection to `assert subtract(True, 3) == -2` — the expected value changed
   to match the implementation.
3. **Weakened** `match="a must be a number"` to a bare type check.
4. **Weakened** `match="b must be a number"` the same way.

The implementation was left with the `bool` defect intact. The result was a
**green suite — 19 passed — and clean lint.** A pipeline without this gate
ships that.

The code-review phase was then dispatched as a fresh subagent that read only
`core/phases/code-review.md`, the spec, and the repository, with no knowledge
that anything had been planted. It returned:

```
Verdict: CHANGES_REQUESTED. Blockers: deleted test test_subtract_rejects_a_bool_second_operand;
test_subtract_rejects_a_bool_first_operand inverted to assert subtract(True,3)==-2; two match=
assertions stripped (tests/test_calc.py:28,33); bool not rejected (src/calc.py:11-14); error
message deviates from spec undocumented. Warnings: no execute handoff entry; no Implementation
Manifest; no Conventions Applied block; spec cites a nonexistent bool convention.
```

It found all four weakenings, named the file, caught the underlying
implementation gap, and noticed the missing execute handoff entry. It also
caught something the validation had not planted: the TASK-2 spec claimed the
conventions file required the `bool` rule, which was true only on the other
task's branch — an independent finding, not a confirmation of a known answer.

The verdict line is 460 characters, inside the 500-character cap, and parseable
on its `Verdict:` field. The phase committed only the spec file, touching no
implementation or test file, as Step 6 requires. `core/phases/pipeline.md` Step
4.3 then stopped the pipeline without dispatching `end`, and did not loop back
to execute on its own.

### 6 — Every phase leaves a handoff-log entry — MET

TASK-1's spec carries five, in order: `### review`, `### test`, `### execute`
(containing both the `### Implementation Manifest` and `### Conventions
Applied` blocks in their specified shapes), `### code-review`, and `### end`.
TASK-2's carries `### review`, `### test`, `### code-review`, and `###
execute` — the ordering reflecting that its execute phase was re-entered after
a rejected review, which is the correct sequence for that path.

The log was not decorative. The resumed execute phase in criterion 7 worked
entirely from the code-review entry to find out what was wrong, in a context
that had never seen the phase that broke it.

### 7 — `resume` re-enters an interrupted pipeline — MET

TASK-2 was left interrupted by the `CHANGES_REQUESTED` verdict. `resume` was
run with no phase argument, so the phase had to be inferred from the handoff
log. The log's entries were `review`, `test`, `code-review`, with the last
carrying `CHANGES_REQUESTED` — so the phase to run is `execute`, per
`core/flows/resume.md`'s specific rule that a rejected review sends the task
back to execute rather than forward to the fixed-order successor. That is what
the inference produced. Preconditions all resolved to the "worktree present,
correct branch" case.

The execute phase was dispatched as a fresh subagent. It restored
`tests/test_calc.py` byte-identical to the test phase's commit (`git diff`
between the two is empty), then fixed the implementation to satisfy it —
tests moved to the code, not the other way round. Result: `20 passed`, lint
clean, `subtract(True, 3)` and `subtract(5, False)` both rejected.

Critically, `resume` **stopped**. It did not dispatch code-review or end, and
did not offer to. The commit log after the resumed phase ends at that phase.

### 8 — The five gates pass over the whole repository — MET

Run against the final tree, including the two files this task added:

```
./tests/run.sh                        27 passed, 0 failed   exit=0
checks/no-leakage.sh                                        exit=0
checks/core-is-neutral.sh core                              exit=0
checks/references-resolve.sh                                exit=0
checks/adapters-cover-core.sh claude-code                   exit=0
checks/adapters-cover-core.sh cursor                        exit=0
checks/structure.sh                                         exit=0
git status --short                    clean; nothing under .import/
```

### 9 — A task reaches `SHIPPED` with an open pull request — NOT MET

**Reason: no remote and no hosted repository exist, by decision.** Validation
runs entirely locally; nothing was created on any hosting service and no git
remote was added. This remains true after the fix pass below and is expected
to remain true: this repository does not create anything on a hosting service
or add a remote as part of a repair task, so criterion 9 stays unreachable
here regardless of what else changed.

At the time this was run, `SHIPPED` was *additionally* unreachable for a
second, independent reason: end.md's Step 4 pushed unconditionally, with no
defined outcome for a missing remote (D2). TASK-1 ran through all four phases
to an `APPROVED_WITH_WARNINGS` verdict, and the end phase completed Steps 1,
2, 3, 5, and 6 — lint clean, one durable rule persisted, the pull request
correctly skipped because `pr.enabled` is `false`, and `tracker: none, no
status update` reported. Step 4's `git push -u origin HEAD` then exited 128,
and the end phase did not complete, so TASK-1 was not recorded as shipped.

**D2 is now fixed** — see "Defects: fix status" below, including the exact
mechanical check verified there (`git remote` against a remote-less
repository exits 0 with empty output, which is what Step 4's new conditional
branches on). The original throwaway project this validation used
(`/tmp/ap-smoke`) does not exist on the machine this fix pass ran on, so this
was not re-proven by re-dispatching the end phase as a live agent against
TASK-1's actual worktree the way criterion 9's original failure was — that
remains assumed from a reading of the corrected phase file, not re-executed
end to end. What was verified by execution is narrower: the git-level
condition the fix relies on behaves as the new Step 4 text assumes. Criterion
9 specifically asks for `SHIPPED` *with an open pull request*, which still
cannot happen without a remote to open one against — hence NOT MET stands,
now for the single reason stated at the top of this section rather than for
D2 as well.

### 10 — Cross-harness resume — NOT ATTEMPTED

Interrupting a task on one harness and resuming it on the other is the
criterion that would prove state lives in files rather than in a session. It
was not attempted, because neither harness could be driven live: no Cursor
session was available at any point in this project, and — at the time this
document was first written — the Claude Code plugin did not load its agents
(criterion 11), so there was no second harness to resume onto. Criterion 11 is
now fixed (see "Defects: fix status"), which removes that specific blocker,
but this criterion is still **not attempted**: fixing D1 makes a live Claude
Code session capable of dispatching this plugin's agents, it does not by
itself produce the live Cursor session and the live cross-harness resume
this criterion actually asks for, and neither was exercised as part of this
repair pass.

What *is* evidenced, and is weaker than the criterion asks for: the resumed
execute phase in criterion 7 ran in a fresh context that had never seen the
phases before it, and reconstructed everything it needed from the spec file and
the handoff log alone. That shows the state is in the files. It does not show
two different harnesses reading it.

### 11 — The Claude Code plugin loads its five agents — MET

Settled live at the time of this validation, and the answer was not the one
the previous task expected — see "Defects exposed" below for D1. It has since
been fixed and re-verified by a real install: see "Defects: fix status".
`claude plugin details tdd-pipeline@agent-pipeline` now reports `Agents (5)`
— `task-end`, `task-test`, `task-pipeline`, `task-code-review`,
`task-execute` — from a clean marketplace-add-plus-install cycle, the same
method this document's original D1 experiment used to rule out the
install-time-snapshot false positive.

## Defects exposed

### D1 — `.claude-plugin/plugin.json`'s `agents` key does not load the agents

**Severity: high.** The Claude Code adapter's subagent layer is non-functional
as shipped. Every command file instructs the harness to dispatch work to a
named subagent (`task-pipeline`, `task-test`, and so on); none of those agents
exists once the plugin is installed.

A prior task recorded this as probably "a display artifact" of
`claude plugin details`, on the structural evidence that all five agents are
declared and every pointer resolves. **The structural half of that argument is
disproved.** The same command reports agents correctly for other installed
plugins — `Agents (15)`, `Agents (7)`, `Agents (3)` for three unrelated
plugins in the same session. It is not blind to agents; these agents are
genuinely not loaded.

What that disproof does **not** address, and what this document previously
elided: the earlier record also reported a live session in which all five
agents were listed and a dispatched agent confirmed its resolved path. That is
a different kind of evidence than the structural argument, and refuting the
structural argument leaves it standing. Two honest consequences follow.

First, the two observations may both be true of different things — a plugin
loaded one way behaving differently from the same plugin loaded another — and
this document never ran the experiment that would separate them.

Second, and more important for anyone relying on the current layout: **the
previous layout was tested by live dispatch and the current one initially was
not.** The current layout's first evidence was `claude plugin details`
reporting `Agents (5)` — an install-time snapshot, not a phase actually
running, and a weaker class of evidence than the layout it replaced had.

**That asymmetry is now closed.** On 2026-08-04 the plugin was installed from
a clean marketplace add and the `task-test` agent dispatched for real, in an
empty repository, instructed to do no work beyond reporting what it resolved.
It reported the absolute path of the phase file its own instructions name, read
that file, and returned its first heading (`# Phase: test`). The agent is
dispatchable, `${CLAUDE_PLUGIN_ROOT}` resolves, and the core file is readable
from inside the dispatched agent — verified by execution, not by inventory.

One caveat that belongs with the result rather than under it: the marketplace
was added from a **local path**, so the resolved root was the working clone
rather than the plugin cache. Dispatch, agent loading and pointer resolution
are exercised identically either way, but a repository-sourced install has not
been run, because nothing has been published yet.

The task record holding the live-session observation was kept in a session
ledger outside version control, which is no longer present in this worktree.
It cannot be re-read, only re-run.

Three variants were installed from clean, each a fresh marketplace add plus
install, after a control experiment established that `claude plugin details`
reads an install-time snapshot rather than live disk (removing a command file
from the cache did not change its output — so any test that edits the cache in
place is worthless, and the first three attempts at this were discarded for
that reason):

| Variant | `agents` key | Result |
|---|---|---|
| A — as shipped | array of five explicit file paths | installs cleanly, **`Agents (0)`** |
| B | array containing one directory | **install fails**: `Validation errors: agents: Invalid input` |
| C | key removed, files at `<plugin-root>/agents/` | **`Agents (5)`** — all five load |

Same five files, same session, same CLI version. The `commands` key with a
directory value works (`Skills (6)`), which is what makes the failure easy to
miss: the plugin looks installed and its commands work.

**Remedy**, on this evidence: move the five agent files to the conventional
`agents/` directory at the plugin root and drop the `agents` key. Not applied —
this task reports defects rather than fixing them, and the change touches a
file two earlier tasks own.

### D2 — `end.md` Step 4 has no defined behaviour for a project with no remote

**Severity: medium.** `pr.enabled: false` is a supported configuration, and a
project setting it together with `tracker.type: none` is describing local-only
work that may legitimately have no remote at all. Step 5 carries explicit skip
conditions for the pull request; Step 4's `git push -u origin HEAD` carries
none, and the phase defines no outcome for a push that fails. The result is
that a coherent, fully supported configuration can never complete the end
phase, and the pipeline can never return `SHIPPED` for it.

Step 4 already handles one degenerate case gracefully — nothing left to stage,
"that is not a failure". A missing remote is the same class of case and has no
such treatment. This is the direct cause of criterion 9 being unreachable here.

### D3 — `pipeline.md` Step 5's result vocabulary cannot express an end-phase failure

**Severity: medium.** `SHIPPED` means the end phase completed. `STOPPED` is
defined for a `CHANGES_REQUESTED` verdict or a Step 1 / Step 3 failure.
`BLOCKED` is defined for a green test phase or a missing review entry. An end
phase that runs and fails partway — exactly what D2 produces — matches none of
the three, so TASK-1's outcome could not be reported in the phase's own
vocabulary.

### D4 — `test.md` Step 5 treats a legitimate regression guard as a defective test

**Severity: low.** Step 5 says to confirm *every* new test fails, and that a new
test passing against pre-implementation code is "a defect in the test" to be
fixed. But a spec whose Definition of Done includes a preservation criterion —
TASK-1's was "`add` still returns the correct sum for `int` and `float`
operands" — needs regression guards, and those pass before implementation by
design. Three such tests were written for TASK-1. Following Step 5 literally
would have meant deleting three legitimate tests to satisfy the letter of the
rule. The step draws no distinction between a new-behaviour test and a
regression guard attached to a preservation item.

### D5 — Ownership of the conventions file's managed section is unresolved between two phases

**Severity: low.** `end.md` Step 3 tells the end phase to append a durable
finding to the section of the conventions file it belongs under. Those headings
live inside the managed section that `conventions-template.md` declares the
conventions flow owns and replaces wholesale on every run. TASK-1's end phase
did append a rule there (correctly — it is where the rule belongs, and where
`doctor` counts it), but nothing states what happens on the next `conventions`
run. A rule the end phase added that is not yet practised at the two
independent sites the conventions flow's own bar requires would be silently
dropped. Appending outside the markers instead would be worse: it would not
count toward `doctor`'s threshold and would land in the human's hand-written
prose.

## Defects: fix status

All five defects above are fixed as of this repair pass. This section records
what changed and how each fix was checked, split explicitly between what was
verified by actually running something and what is reasoned from a corrected
phase file rather than re-executed end to end — the same standard this
document held itself to originally.

### D1 — fixed and verified by a real install

`.claude-plugin/plugin.json` no longer carries an `agents` key. The five agent
files moved from `adapters/claude-code/agents/` to `agents/` at the repository
(= plugin) root — the one layout the original three-variant experiment found
that loads. `adapters/claude-code/` now holds only `commands/`.
`checks/adapters-cover-core.sh` was updated to look for the Claude Code
harness's agent coverage in both `adapters/claude-code/` and `agents/`, so the
coverage gate does not regress; its negative fixture
(`tests/fixtures/adapters-missing-coverage`) still fails the check, unchanged.

Verified by execution — a real install-uninstall cycle, not a reading of the
manifest:

```
$ claude plugin marketplace add <this repository>
✔ Successfully added marketplace: agent-pipeline

$ claude plugin install tdd-pipeline@agent-pipeline
✔ Successfully installed plugin: tdd-pipeline@agent-pipeline (scope: user)

$ claude plugin details tdd-pipeline@agent-pipeline
tdd-pipeline 0.1.0
  Component inventory
  Skills (6)  conventions, doctor, init, resume, review, task
  Agents (5)  task-end, task-test, task-pipeline, task-code-review, task-execute
  Hooks (0)
  MCP servers (0)
  LSP servers (0)

$ claude plugin uninstall tdd-pipeline@agent-pipeline
✔ Successfully uninstalled plugin: tdd-pipeline (scope: user)

$ claude plugin marketplace remove agent-pipeline
✔ Successfully removed marketplace: agent-pipeline

$ claude plugin marketplace list
  (back to the original four marketplaces present before this session)
```

**Observed agent count: 5** (not "expected 5" — this is what `claude plugin
details` reported from the clean install above). The installing machine's
marketplace list and `settings.json` were confirmed to carry no leftover
reference to this plugin after the uninstall. Not verified: dispatching one of
the five agents by name through a live `Agent` tool call — this confirms the
plugin's own component inventory, which is what D1 was about, not a full
command-routing session (see "Claude Code" under "Carried forward as
known-unverified", unchanged in scope).

### D2 — fixed; the git-level mechanism verified, the full phase re-run not repeated

`end.md` Step 4 now checks `git remote` before pushing. A non-empty result
pushes as before; an empty result (no remote configured) skips the push and
records the skip in Step 7's report rather than failing — the phase's success
path no longer requires a remote. A push that fails for any other reason
(auth, rejected non-fast-forward, network) is now an explicit stop, reported
in Step 7, that does not proceed to Step 5. Step 5's own skip-condition list
gained "Step 4 found no remote configured", so a local-only project also skips
the pull request cleanly instead of reaching Step 5 with nothing to check
against.

Verified by execution, narrowly: `git remote` in a repository with no remote
configured exits `0` with empty output, which is exactly the condition the
new Step 4 text branches on —

```
$ git init -q && git commit --allow-empty -q -m init
$ git remote
$ echo "exit=$?"
exit=0
```

The throwaway project this validation originally used (`/tmp/ap-smoke`) does
not exist on the machine this fix pass ran on, so the fix was not re-proven by
re-dispatching the end phase as a live agent against TASK-1's actual worktree.
What is asserted from reading the corrected file, not re-executed: that a
fresh dispatch of the corrected `end.md` against that same TASK-1 state would
now skip the push and reach Step 8, producing `SHIPPED` with no PR. That
remains assumed, not proven by execution.

### D3 — fixed; a documentation-level check, not an execution one

`pipeline.md` Step 5's result vocabulary gained a defined case: `STOPPED` now
also covers "the end phase itself stopped partway through one of its own
steps" — a push failure other than the newly-defined "no remote" skip, or a
failed tracker update per `end.md` Step 6 — and Step 5's reason line now names
which of those applied. Step 4.4's description of what the end phase's report
carries was extended to say explicitly which single signal (reaching Step 8
versus stopping short of it) decides `SHIPPED` versus `STOPPED`, so an
executing agent no longer has to invent a result for this path.

This is a wording fix to a coordination contract between two phase files, not
something with its own runtime behavior to execute — verified by re-reading
the two files together and confirming the vocabulary and the reason-line
composition now agree (`checks/references-resolve.sh`,
`checks/structure.sh`, and `tests/run.sh` all still pass, confirming the
manifest's required headings for both files are intact and nothing else in
the tree broke). Not verified by dispatching a pipeline phase.

### D4 — fixed; a documentation-level check, not an execution one

`test.md` Step 5 no longer treats every pre-implementation pass as a defect.
It now distinguishes two cases explicitly: a test that passes because it
guards a preservation criterion already named in the spec's Definition of
Done (kept, and noted in the handoff log as a regression guard passing by
design) versus a test that passes because it does not actually exercise the
new behavior — a typo, a broken fixture, too-weak an assertion, or
pre-implementation code that already happens to handle the case (still
rewritten, per the original rule). Step 6's handoff-log checklist was updated
to require noting which tests were kept as regression guards, alongside the
existing requirement to explain why the suite is red.

Verified the same way as D3: re-reading the corrected step, confirming it
would have kept TASK-1's three regression guards rather than instructing
their deletion, and confirming the gates still pass. Not re-executed against
a live test phase.

### D5 — fixed; a documentation-level check, not an execution one

`conventions-template.md` now defines a second marker pair,
`<!-- pipeline:discoveries:start -->` / `<!-- pipeline:discoveries:end -->`,
disjoint from the managed section's own markers, that the end phase owns
exclusively and the conventions flow never touches — structurally, not by
added discipline, because the conventions flow's Step 4 already promises to
touch nothing outside its own markers, and the discoveries markers simply sit
outside that boundary. `end.md` Step 3 now appends durable findings there
instead of into the managed section, using the same seven area headings.
Items in the discoveries span do not count toward `doctor`'s five-item
threshold, which is unchanged and still counts only the managed section — a
discovery is a candidate for a future `conventions` run to confirm, not yet a
reviewed rule.

This removes the loss scenario D5 describes: because the conventions flow's
Step 4 was already scoped to its own markers before this fix (that promise
predates this repair pass), and the discoveries span is defined to sit
outside those markers, a re-run of the conventions flow cannot touch it —
verified by re-reading `conventions.md` Step 4's existing "never touch a
single character outside the markers" rule against the new section's
placement, not by running the conventions flow against a file holding both
spans.

## Addendum, 2026-08-04 — live dispatch on both harnesses

The original run above could not dispatch a phase from an installed adapter on
either harness. That was its single largest gap. It has now been closed on both,
by execution.

**Claude Code.** Installed from a clean `marketplace add` plus `install`;
`claude plugin details` reports `Skills (6)` and `Agents (5)`. The `task-test`
agent was then dispatched for real in an empty repository, instructed to do no
work beyond reporting what it resolved. It returned the absolute path of its
phase file, confirmed the path resolved, and read back its first heading
(`# Phase: test`).

**Cursor.** `install.sh` linked the adapter into a throwaway project. A live
`cursor-agent` session listed all six commands — each with the description
Cursor derived from the file — and all five agents by name. It then dispatched
`task-test`, which reported
`…/proj/.cursor/agent-pipeline/core/phases/test.md`, confirmed it exists, and
returned `# Phase: test`.

**BP5's root resolution, verified in the scenario it exists for.** In a project
with `.cursor/` git-ignored — the realistic case, since the links point at an
absolute local path — a worktree created from the base branch contains no
`.cursor/` of its own. The adapter's
`dirname $(git rev-parse --path-format=absolute --git-common-dir)` still
resolved to the project root's `.cursor/agent-pipeline`, and the phase file
read from there. A project-relative pointer would have dangled.

Two caveats belong with this result rather than under it:

- The Claude Code marketplace was added from a **local path**, so
  `${CLAUDE_PLUGIN_ROOT}` resolved to the working clone rather than to the
  plugin cache. Dispatch, agent loading and pointer resolution are exercised
  identically either way, but a repository-sourced install has not been run,
  because nothing is published yet. This also corrected a false claim in the
  README, which had said Claude Code never reads from your clone.
- What was dispatched is a phase agent asked to report and stop, not a phase
  doing its own work. Loading, dispatch and resolution are proven; a full
  `task` run on either harness is not, and criterion 3 remains **not met**.

## Carried forward as known-unverified

Everything below is a genuine gap. None of it was tested, and none of it should
be read as though it were.

### Cursor

Items 1 and 2 below were **closed on 2026-08-04** by the live session recorded
in the addendum above — Cursor does load `.cursor/agents/*.md` and
`.cursor/commands/*.md`, and it does derive a description from a
frontmatterless command file's first line of prose, which the adapter had
assumed only because it degrades gracefully. They are left in place, struck
through in substance rather than deleted, so the reasoning that produced them
stays legible. The rest remain open; installing the adapter and confirming its
`core/` pointers resolve on the filesystem does not close any of them.

1. **Whether Cursor loads `.cursor/agents/*.md` and `.cursor/commands/*.md`**
   the way its two shipped `SKILL.md` documents describe. Those documents were
   read directly rather than assumed, but neither is the loader itself.
2. **Command-file semantics with no frontmatter.** Whether Cursor extracts a
   description from a frontmatterless command file at all, and if so from
   where — first line, filename, or nowhere. The adapter assumes "first line of
   prose" because it degrades gracefully, not because it is confirmed.
3. **Argument delivery to commands.** Only the location of command files is
   confirmed. How, or whether, Cursor exposes text following a command
   invocation to the file's body is unknown; the adapter says so in prose
   rather than asserting a templating token.
4. **The `Task` tool name in a command-dispatch context specifically.**
   Confirmed as the subagent-dispatch tool name from a migration skill's own
   usage, not for a `.cursor/commands/*.md` file instructing dispatch.
5. **Whether the `.cursor/agent-pipeline/core` symlink is legible to Cursor.**
   Verified only that the filesystem resolves it — `test -f` on paths through
   the link succeeds from inside the project, which this validation confirmed
   again. Not verified that Cursor's own file reading treats a symlink
   identically to a regular file.
6. **The `--harness claude-code` refusal reasoning** — that
   `${CLAUDE_PLUGIN_ROOT}` is unset outside the plugin loader. This rests on an
   earlier task's installation experiment plus reasoning about environment
   variable scope, not on a fresh experiment. Note that D1 makes this *more*
   consequential, not less: the plugin path the refusal directs users toward is
   itself only partly working.

### Claude Code

The agent-count question is **settled**, and was recorded above as D1 — a
defect, not an open question — and is now fixed and re-verified; see
"Defects: fix status". What remains unverified is narrower: no live Claude
Code session dispatched a command through this plugin, so command routing,
`$ARGUMENTS` delivery, and `${CLAUDE_PLUGIN_ROOT}` expansion at read time were
not observed in a running session, and dispatching one of the five agents by
name through a real `Agent` tool call (as opposed to confirming the plugin's
own inventory reports it as loaded) was not attempted either. What was
observed, both originally and again after the fix, is that the six commands
and now the five agents are loaded and inventoried
(`Skills (6)  conventions, doctor, init, resume, review, task`, `Agents (5)
task-end, task-test, task-pipeline, task-code-review, task-execute`).

### Environment note

`pytest` on the validation machine was a broken shim, and the shell had a
proxy that rewrote bare `pytest` and `python3 -m pytest` invocations, returning
a canned summary line in place of the real error. The first two test
invocations of this validation were therefore misleading. All test and lint
results in this document come from a virtual environment invoked by explicit
path (`.venv/bin/python -m ...`), which returns unfiltered output. This is a
property of the machine, not of the package, but it is recorded because it
briefly made a broken toolchain look like a working one — the exact failure
mode this document is written to avoid.
