# Agent handoff log contract

The `## Agent Handoff Log` section of a task spec (see `spec-template.md`) is
the only communication channel between phases. Phases run in sequence, each
with no memory of the others' work beyond what is written down — the log is
where a phase leaves what the next phase needs to know, and where it finds
what an earlier phase already learned.

## Format

Each phase appends one dated subsection, named for itself, never editing or
removing an earlier phase's entry:

```markdown
## Agent Handoff Log

### <phase-name> (YYYY-MM-DD)
- Finding or note
- Another finding
```

Entries accumulate. A later phase reads the whole log, not just the most
recent subsection — a warning left by the test phase is still relevant when
the code-review phase runs.

## Reading

Before starting any work, a phase reads the handoff log in full, for:

- warnings about tricky areas earlier phases ran into
- mock and fixture patterns already established for this task
- deviations from the spec that earlier phases made, and why
- constraints stated concretely enough to act on without re-deriving them

A phase that skips this step re-learns, the hard way, whatever the previous
phase already figured out — or worse, undoes a deliberate deviation because
it never saw the note explaining it.

## Writing

Before finishing, a phase appends its own dated subsection covering:

- warnings about tricky areas, for whichever phase runs next
- mock and fixture patterns the next phase needs to reuse rather than
  reinvent
- deviations from the spec, and the reasoning behind each one
- critical constraints stated concretely — not "be careful with the
  identifier" but "changing this identifier breaks six tests"

Vague notes cost the next phase the same investigation the current phase
already did. A concrete note costs one sentence.

## Escalation routing

Not everything a phase learns belongs in the handoff log. Some findings are
durable and reusable beyond this one task; leaving those only in a spec file
that gets archived once the task closes means the next task pays the same
discovery cost again. Route every finding using this table — a reader must
never be left guessing which row applies:

| What was learned | Where it goes |
|---|---|
| Project convention: pattern, naming, command, path, contract | the file at `paths.conventions`, inside its **discoveries span** |
| Phase-workflow learning | `.tdd-pipeline/memory/<phase>/` |
| Detail specific to this task only | this handoff log |
| Personal communication preference | the operator's own memory, outside the repository |

Row 1 names a span, not just a file, and the span is not optional. "Append"
means **insert immediately above** `<!-- pipeline:discoveries:end -->`, under
the matching area heading inside the span — never at the end of the file. A
block written after the end marker sits outside both spans: the conventions
flow does not own it, the discoveries span does not contain it, and a diff
that shows only added lines looks exactly like a correct append. After
writing, list the marker lines with their line numbers and confirm the new
entry falls between them and that nothing but whitespace follows the end
marker. A
convention written anywhere else inside `paths.conventions` — most
temptingly, straight under the matching area heading in the managed
section — is written into a span the conventions flow regenerates wholesale
on its next run, so the finding survives exactly until someone re-derives
the project's conventions and then disappears with no trace that it was
ever there. Append to the discoveries span instead
(`<!-- pipeline:discoveries:start -->` / `<!-- pipeline:discoveries:end -->`,
defined in `core/contracts/conventions-template.md`), which no flow
overwrites; a discovery there is a candidate a later conventions run can
confirm and promote into the managed section through its own rule bar.

Rows 1 and 2 are the pair a reader is most likely to blur together, since
both sound like "something the pipeline figured out while doing this work."
The test that separates them: a **convention** is a fact about the target
codebase itself — true whether or not this pipeline ever ran against it —
while a **phase-workflow learning** is an operational quirk of running a
phase, meaningful only to the phase that hit it.

"Every module in this project reads its settings through the shared
configuration loader; reading an environment variable directly bypasses the
defaults the loader applies" is a convention: it is true of the codebase,
and it matters to a human working in it with no pipeline involved.

"The code-review phase must reconstruct a test file's state as the test
phase committed it from version control rather than reading the working
tree, since the execute phase may have changed it since" is a
phase-workflow learning: it is about how *this pipeline's phase* does its
own job, and means nothing outside that context — a human reading the diff
by hand never hits it.

The hard rule: project conventions never go to personal memory. Personal
memory is invisible to teammates and to every other phase running against
this project, so a convention parked there might as well not exist for
anyone but the operator who wrote it. When a finding could plausibly belong
in either the conventions file or this log, the conventions file wins —
"detail specific to this task only" is the narrow row, not the default one.

When a phase escalates a finding out of the handoff log and into the
conventions file or phase memory, it still records the escalation here, so a
later reader of this log knows the finding was acted on rather than dropped:

```
→ Escalated to conventions: <one-line summary of what was added>
```

Every escalation is written inside the task's worktree, at the same relative
path it has in the main checkout, and nowhere else. A file written into the
main checkout never reaches the branch, ships with nothing, and leaves the
operator's own working tree dirty — while the log line above claims it was
acted on.

## Phase memory

`.tdd-pipeline/memory/<phase>/` is this pipeline's own memory, one directory
per phase, named exactly as the phase is: `test`, `execute`, `code-review`,
`end`, `pipeline`. It is the only memory the pipeline reads. A harness may
offer an agent-memory feature of its own; the pipeline does not use it,
because a learning kept there is invisible to every other harness and splits
one project's lessons across two places that never see each other.

**Reading.** At its first step, before any other work, every phase reads
every file under its own directory. The files are few and short by design,
so read all of them rather than choosing by filename. A lesson the phase
never reads is a lesson it pays for again.

**Writing.** One learning per file, in Markdown, named in kebab-case after
the lesson itself (`restore-from-a-copy-not-from-version-control.md`, not
`note-3.md`). The file opens with a single H1 stating the rule, then says
what was observed and on which task, why it matters, and how to apply it.
Before writing, read the directory: a new occurrence of a lesson already on
file extends that file with the new case rather than adding a second one.
Write it inside the worktree, per the paragraph above this section, so it
ships in the phase's commit.

A lesson that stops being specific to one phase — it changes what a phase
must do, not how one run went — belongs in that phase's own file in the
pipeline, not in any project's memory. Phase memory is where such a lesson
waits until someone moves it there.
