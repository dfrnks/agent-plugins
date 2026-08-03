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
| Project convention: pattern, naming, command, path, contract | the file at `paths.conventions` |
| Phase-workflow learning | `.agent-pipeline/memory/<phase>/` |
| Detail specific to this task only | this handoff log |
| Personal communication preference | the operator's own memory, outside the repository |

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
