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
| 11 | The Claude Code plugin loads its five agents | **NOT MET** |

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
remote was added. `SHIPPED` requires the end phase to complete, and the end
phase's Step 4 pushes unconditionally.

This was executed rather than assumed. TASK-1 ran through all four phases to a
`APPROVED_WITH_WARNINGS` verdict, and the end phase completed Steps 1, 2, 3, 5,
and 6 — lint clean, one durable rule persisted into the conventions file's
managed section, the pull request correctly skipped because `pr.enabled` is
`false`, and `tracker: none, no status update` reported. Step 4's
`git push -u origin HEAD` then exited 128. The end phase therefore did not
complete, and TASK-1 is **not** recorded as shipped.

Everything up to the push was exercised and is reported above under criteria 1
through 8. The push, the pull request creation against a real base branch, and
a `SHIPPED` result remain unexercised. See "Defects exposed" — the run turned
up a real gap in `end.md` here, not merely an environmental limitation.

### 10 — Cross-harness resume — NOT ATTEMPTED

Interrupting a task on one harness and resuming it on the other is the
criterion that would prove state lives in files rather than in a session. It
was not attempted, because neither harness could be driven live: no Cursor
session was available at any point in this project, and the Claude Code plugin
does not load its agents (criterion 11), so there is no second harness to
resume onto.

What *is* evidenced, and is weaker than the criterion asks for: the resumed
execute phase in criterion 7 ran in a fresh context that had never seen the
phases before it, and reconstructed everything it needed from the spec file and
the handoff log alone. That shows the state is in the files. It does not show
two different harnesses reading it.

### 11 — The Claude Code plugin loads its five agents — NOT MET

Settled live, and the answer is not the one the previous task expected. See
"Defects exposed" below.

## Defects exposed

### D1 — `.claude-plugin/plugin.json`'s `agents` key does not load the agents

**Severity: high.** The Claude Code adapter's subagent layer is non-functional
as shipped. Every command file instructs the harness to dispatch work to a
named subagent (`task-pipeline`, `task-test`, and so on); none of those agents
exists once the plugin is installed.

A prior task recorded this as probably "a display artifact" of
`claude plugin details`, on the structural evidence that all five agents are
declared and every pointer resolves. **That is disproved.** The same command
reports agents correctly for other installed plugins — `Agents (15)`,
`Agents (7)`, `Agents (3)` for three unrelated plugins in the same session. It
is not blind to agents; these agents are genuinely not loaded.

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

## Carried forward as known-unverified

Everything below is a genuine gap. None of it was tested, and none of it should
be read as though it were.

### Cursor

No live Cursor session was available at any point in this project. The six
items below were raised by the task that built the Cursor adapter and remain
open; installing the adapter and confirming its `core/` pointers resolve on the
filesystem, which this validation did do, does not close any of them.

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

The agent-count question is **settled**, and is recorded above as D1 rather
than here — it is a defect, not an open question. What remains unverified is
narrower: no live Claude Code session dispatched a command through this plugin,
so command routing, `$ARGUMENTS` delivery, and `${CLAUDE_PLUGIN_ROOT}`
expansion at read time were not observed in a running session. What was
observed is that the six commands are loaded and inventoried
(`Skills (6)  conventions, doctor, init, resume, review, task`).

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
