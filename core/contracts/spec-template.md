# Task spec template contract

A task spec is the unit of work the pipeline executes. It is written once,
by a planning conversation or a designer agent, and then handed to phases
that never see that conversation. Every phase — test, execute, code-review —
reads only the spec file and the conventions file at `paths.conventions`.
Nothing outside those two documents reaches them. This contract defines the
section skeleton every spec follows and the rules that make a spec complete
enough for that handoff to work.

## Skeleton

```markdown
# TASK-1 — Short, specific title

## Context
Why this change is needed — the problem or opportunity.

## Approach
The design: what gets built, and how it fits what already exists. Name
files, functions, data sources, and resolution chains explicitly.

## Files to Modify
Every file that will be touched, with a brief note on what changes in each.

## Definition of Done
- [ ] Measurable acceptance criterion, referencing the applicable convention
- [ ] Test or verification step

## Out of Scope
What this task deliberately does not cover, so no phase drifts into it.

## Agent Handoff Log
<!-- Phases append findings here — see handoff-log.md -->
```

Every section is present in every spec, even when short. A missing section
is not "implied" by context elsewhere in the file — a phase that needs
`## Out of Scope` and finds it absent has no way to tell "empty" from
"omitted by accident."

## What a spec leaves out

A spec is written to a phase that has no history. It never saw the planning
conversation, the review that corrected the spec, or the draft being
corrected. So the body states what to build, in the present tense, and stops
there. What the spec used to say, why it was wrong, and what proved it wrong
are the record of a decision rather than instructions, and their place is
`## Agent Handoff Log`, which every phase reads alongside the body.

The cost of putting them in `## Approach` instead is that reasoning there
reads exactly like a requirement, because it sits where the requirements
are. A phase handed "the previous draft said `and`, which made three of its
own criteria unreachable" has to work out that no part of that sentence is
something to do. Multiply that by every finding a review makes and the
instructions become the minority of their own section. Evidence goes the
same way: "verified — this dies with `Error: Method name must be a string`"
belongs to the reviewer's handoff entry, while the body carries only what
that evidence settled, in a form a phase can implement.

None of this licenses a thin spec. The completeness rules below say what a
phase needs in order to do the work and they hold in full; this section says
where the reasoning behind it lives. A spec that drops a field name, a path,
or a resolution chain in the name of brevity has broken a completeness rule,
not followed this one.

## Completeness rules

A spec is reviewed against these rules before any phase starts work. Most
are judgment calls the review flow applies per task; two are hard blockers
that make a spec unapprovable regardless of how well everything else reads.

- **A spec is fully self-contained.** The phase that implements it has no
  memory of the planning conversation: every data source, field name,
  resolution chain, file path, and integration detail is written out
  explicitly. If it is not in the spec, the phase does not know it.
- **Document data resolution chains end to end**, naming each store,
  collection, or table and the field that links to the next hop. A chain
  that stops halfway ("look up the related record") forces the executing
  phase to guess the rest.
- **Definition of Done items reference the applicable convention
  explicitly.** The execute phase follows the DoD literally and does not
  re-derive conventions from the conventions file on its own initiative — if
  a convention applies, name it as a DoD item, or the phase has no signal
  that it applies here.
- **A field added to a response shape is wired end to end in the same
  task.** A field with a default value passes validation while always
  returning the default — a silent failure that looks like success in every
  test that doesn't specifically check the value.
- **External API schema verification is a hard blocker, not a
  deferral.** Every request and response field name, type, enum value, and
  required flag is confirmed against the provider's reference documentation
  before the spec is approved. Writing "verify before implementing" in a
  spec is a deferral, not a verification — it moves the cost from planning
  (cheap: read a doc) to production (expensive: a live call fails against
  real data, and the fix needs a hotfix and a redeploy). The review flow
  rejects specs containing this kind of deferral outright. If the
  documentation is unavailable, stop and surface that to whoever can decide
  how to proceed — never invent a plausible shape and let the spec pass on
  a guess.
- **Internal data model verification is equally blocking.** When a spec
  claims existing infrastructure ("extend the existing endpoint", "reuse
  collection X"), locate it before approval — the check is exactly as
  mandatory as the external one, and skipping it fails the same way: the
  phase implements against an assumption instead of a fact. The trap here is
  specific: it is easy to search for the name the spec itself invented, get
  zero matches, and conclude "nothing exists yet, this is safe to build
  fresh." That conclusion is worthless, because a zero-match search for an
  invented name proves nothing by construction — of course a name nobody
  used before doesn't show up. The question that actually needs answering is
  not "does this name exist" but "where does this *concept* live today,
  under whatever name it already has." Search the whole repository rather
  than the subtree the task seems to belong to, since the concept may live
  in a part of the codebase the spec's author never looked at. Once found,
  treat the existing production code that already reads or writes it as
  ground truth for field names and shape — the spec aligns to that reality
  or explicitly documents the migration away from it.
- **Adding a value to an enumerated set is a multi-site change.** A spec
  proposing a new value for an existing enumeration — a status, a kind, a
  role — enumerates, before approval, every site in *this* project that
  branches on that set, because a value missing from any one of them is
  usually a silent gap rather than a build error. Derive that list from the
  codebase: search for every reader of the field, not only its writers. The
  categories vary by project, and the way to find them is to follow the
  existing values; a spec that lists only the definition site has not done
  this. Common shapes worth checking for, none of them mandatory and none
  of them exhaustive: places that mirror the set in a second type
  declaration, places that aggregate or group by it, places that treat some
  values as terminal, places that translate an external system's value into
  this one, and places that render it for a user to see or filter by.

- **A spec longer than a person will actually read is a split, not a
  thorough spec.** Two signals, either one sufficient: `## Approach` names
  more than five distinct changes, or `## Definition of Done` carries more
  than ten items. Both mean the task is several tasks, and both defeat the
  mechanisms that depend on the document being read end to end — the `task`
  flow's gate asks a person to approve what they have read, and the execute
  phase follows the Definition of Done literally, item by item. An approval
  nobody finished reading is not a gate, and a checklist too long to verify
  is not a contract. Split it per `## Subtask structure` below rather than
  trimming detail to fit: the completeness rules above are not negotiable
  against length, so a spec that is too long is carrying too much work, not
  too many words.

## Subtask structure

When a task is split, each subtask gets its own spec file (for example
`TASK-1-1.md`) and its own tracker item, parented to the original task. The
parent spec file becomes an index pointing at its subtasks, not a place
where subtask detail also lives — detail duplicated in two places drifts
the moment one of them is edited. The execute phase always works from
exactly one spec file; a phase asked to reconcile a parent file and a
subtask file at once has no defined precedence between them.
