# Flow: plan

Design a change and stop. This flow explores the codebase, settles the open
questions with a person, and writes a spec — then ends, deliberately, without
creating a worktree, running a phase, or touching implementation code.

It exists because `task` is a commitment: by the time a person sees the
design, the machinery is already assembled around it. Some work needs the
design settled first — a change too large for one task, an approach with two
plausible shapes, a direction that has to be argued before it is scheduled.
Forcing that through `task` either wastes a pipeline run or turns the gate
into a design review it was never meant to be.

The output is a spec at `paths.specs/<task-id>.md`, in the same shape and
at the same path `task` produces, so nothing downstream has to know which
flow wrote it. `review <task-id>` critiques it, and `task <task-id>` takes it
through the pipeline without drafting it again, because `task` reuses a spec
it finds already at that path. This flow adds a way in, not a second kind of
artifact.

## Input

The argument is either a tracker identifier (for example `TASK-1`) naming an
item that already exists, or a description of what needs designing — a
feature, a module, a migration, an architectural change. Extra context
(constraints, preferences, an approach the user already has in mind) is
input to Step 1.

If no argument is given, ask what should be planned. Do not guess from the
branch name or recent commits: this flow's value is that a person chose the
subject.

Like `task`, this flow resolves the work item through the tracker, so the
spec carries the task ID that `task`, `review`, and `resume` look it up by.
Unlike `task`, it never calls the tracker's `set_status`: nothing has
started, and the tracker should not claim otherwise. Moving the item to its
start state stays the job of the flow that starts it.

## Step 0 — Load configuration

Read `.tdd-pipeline/config.yaml`. Follow the fail-fast protocol in
`core/contracts/pipeline-config.md`: stop and name the exact missing key if
the file or a key this flow needs is absent. This flow needs `tracker.type`,
`tracker.prefix`, `paths.specs`, `paths.conventions`, and
`git.commit_trailer`. `tracker.type` selects which file among
`core/trackers/none.md`, `core/trackers/linear.md`, and
`core/trackers/github.md` resolves the item; that file may require further
keys of its own, and an absent one follows the same fail-fast rule.

When the argument is a tracker identifier, resolve it now, through that
file's `resolve_or_create` operation, and use what the item already says —
its title and description — as the goal Step 1 starts from. If a spec
already exists at `paths.specs/<task-id>.md`, read it: this run revises that
spec in place rather than writing a second one beside it.

## Step 1 — Understand the goal

Ask before exploring. Even a description that reads as complete carries
assumptions the person has not written down, and discovering them after the
spec is drafted costs a rewrite.

Ask about scope (what is included, and what explicitly is not), approach
preferences (an architecture, a pattern, a library already intended),
constraints (compatibility, sequencing, work this depends on or blocks), and
who or what consumes the result.

Ask as a small number of concrete questions and wait. Two to four is the
useful range: fewer leaves the exploration unaimed, more turns a design
conversation into a form.

This flow asks twice — here and in Step 3. These first questions are the ones
askable without knowing the codebase, and asking them now keeps Step 2 from
exploring in the wrong direction. The second round is the opposite: questions
that only become askable once exploration has found something.

## Step 2 — Explore

Dispatch subagents in parallel, each covering a distinct concern, the same
way `review` does:

- **What already exists** — the models, routes, components, jobs, or modules
  covering this area today, and the patterns a new design should follow
  rather than reinvent.
- **The nearest precedent** — a feature already built here that solved a
  structurally similar problem. Its shape is the strongest available evidence
  about what will fit.
- **What this touches** — the modules, contracts, and data flows a change in
  this area reaches, including the ones the description did not mention.

Read the files these reports surface closely enough to judge them yourself. A
design assembled from subagent summaries inherits their compressions, and the
compressions are where the constraint that breaks the design hides.

Read `paths.conventions` as well. A plan that contradicts a rule the project
already holds itself to is a finding for Step 3, not a silent decision.

## Step 3 — Resolve the open questions

Exploration turns vague questions into specific ones. Ask the second round
now: where new state belongs given where existing state lives, which of two
established patterns applies when both are present, how far the change should
reach when exploration found more callers than expected.

State the assumptions the design rests on as a numbered list and ask which
are wrong. An assumption corrected in one word is cheaper than a finding a
phase surfaces three steps into implementation.

If exploration showed the work is too large for a single pass, say so here
and propose the split, per the subtask structure in
`core/contracts/spec-template.md`. Deciding that after a spec has been
drafted as one unit wastes the drafting.

## Step 4 — Draft the spec

Write the spec to `paths.specs/<task-id>.md`, with the ID resolved as below,
following the skeleton and completeness rules in
`core/contracts/spec-template.md` exactly — every section present, including
`## Out of Scope` and an empty `## Agent Handoff Log`.

Two completeness rules are why this flow writes a real spec rather than a
looser plan document: an unverified external API schema and an unverified
claim about existing internal infrastructure are both rejected. Resolve them
now, while a person is present and exploration is fresh — the phases that
read this spec later cannot, and `review` would only send it back.

Every step in `## Approach` must be actionable. "Handle the error case" is
not a design; it is a note that a design is still owed.

### Resolving the task ID

When Step 0 already resolved an identifier, use it. Otherwise resolve one
here, and not earlier: by now Steps 1 to 3 have turned the description into
a design a person has shaped, and an item created at the first message would
outlive every design abandoned during those questions.

Call `resolve_or_create` in the tracker file Step 0 selected, with the
design's title as the free-text description and its `## Context` as any
body that file asks for. The tracker creates the item exactly as it would
for `task`, and that file's own rules govern how — including the
confirmation it asks for and its guard against a spec already present at
the derived path. Use the returned ID as-is for the filename and the spec's
title line; do not reconstruct or reformat it.

Report the created item in Step 8. A design that is later abandoned leaves
an item behind, and whoever abandons it closes it in the tracker; this flow
never deletes one.

## Step 5 — Refute the draft

Dispatch a subagent to argue the draft is wrong, before any person sees it.
Not to improve it, not to review it kindly — to make the strongest case
against it that the codebase supports. Give it the drafted spec and let it
read whatever it needs.

Four failure classes are worth naming, because a design conversation
produces them and its own author cannot see them:

- **A mechanism with no precedent here.** A design that introduces an
  operation this codebase has never performed is not automatically wrong,
  but it owes an argument, and a draft that introduces one in a single
  clause has not made it.
- **A claim its own citation does not support.** Every statement about
  existing behaviour cites a `file:line`; the refuter reads each cited line
  and reports the ones that say something else, or nothing.
- **A promise elsewhere that the design falsifies.** Flows and phases make
  standing promises about what they write and what they leave behind. A
  design that breaks one and does not amend it has produced a document that
  contradicts the file next to it.
- **A step no input can reach.** Trace the entry point's accepted arguments
  through to the new behaviour. A mechanism that nothing can trigger reads
  as complete and changes nothing.

Apply what survives to the spec before Step 6, correcting the draft rather
than annotating it. A draft that survives unchanged is a valid outcome — say
so in Step 8 rather than editing something to have edited something.

This runs here, and not only in the review flow, because the order matters.
By the time `review` runs, a person has been shown the draft and may have
agreed with it, and a design is hardest to abandon once someone has approved
it. A refutation before the gate costs one subagent; the same finding after
it costs a rewrite of work already blessed.

## Step 6 — Confirm with the user

Show what was written and ask for corrections. Iterate until the person
agrees, editing the file rather than defending the draft.

This is the last gate, and unlike `task`'s it opens onto nothing — agreement
means the spec is finished, not that anything is about to run. Say that
plainly, so nobody approves expecting work to start.

## Step 7 — Commit

```bash
git add <spec file>
git commit -m "<task-id>: add spec"
```

The message is the one `task` uses for the same file, since the file is the
same artifact whichever flow wrote it. A run that revised an existing spec
commits it as `<task-id>: revise spec`.

If `git.commit_trailer` is non-empty, append it as a trailer; if empty, omit
it rather than adding an empty line.

Commit for the same reason `init` commits its configuration: every phase runs
inside a worktree created fresh from `git.base_branch`, which contains only
committed files. A spec that exists solely in this checkout's working tree is
invisible to every phase that would read it, and the failure appears as a
missing spec in a project where the spec is plainly on disk.

Stage only the spec file. This flow wrote nothing else.

## Step 8 — Report

Return, in order:

- The task ID, and whether it named an existing item or Step 4 created one.
- The spec path, and a one-line summary of what it designs.
- What Step 3 established as out of scope — the boundary is the part of a
  design most easily lost between the conversation and the file.
- Whether Step 3 proposed splitting the work, and into what.
- The next step, named as a command with the task ID filled in rather than
  described: `review <task-id>` to have the spec critiqued by a fresh
  reader, or `task <task-id>` to take it through the pipeline, which
  reuses this spec instead of drafting its own.

Do not run either. This flow ends here, and a flow that continues into
implementation because the design looked finished is the exact commitment
this flow exists to avoid making on a person's behalf.
