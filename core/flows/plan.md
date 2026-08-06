# Flow: plan

Design a change and stop. This flow explores the codebase, settles the open
questions with a person, and writes a spec — then ends, deliberately,
without creating a worktree, without running a phase, and without touching
implementation code.

It exists because `task` is a commitment. That flow resolves a tracker item,
writes a spec, reviews it, and runs the whole pipeline against a worktree;
by the time a person sees the design, the machinery is already assembled
around it. Some work needs the design settled first — a change too large for
one task, an approach with two plausible shapes, a direction that has to be
argued before it is scheduled. Forcing that conversation through `task`
either wastes a pipeline run or turns the gate into the design review it was
never meant to be.

The output is a spec in `paths.specs`, in the same shape `task` produces, so
nothing downstream has to know which flow wrote it. `review` critiques it,
`task` picks it up, `resume` re-enters it. This flow adds a way in, not a
second kind of artifact.

## Input

The argument is a description of what needs designing — a feature, a
module, a migration, an architectural change. Extra context (constraints,
preferences, an approach the user already has in mind) is input to Step 1,
not noise to be summarised away.

If no argument is given, ask what should be planned before doing anything
else. Do not guess from the branch name or from recent commits: this flow's
entire value is that a person chose the subject.

Unlike `task`, this flow takes **no task ID and consults no tracker**. The
work being designed may never become a tracked item, and inventing an ID
here would produce a spec whose name promises a tracker entry that does not
exist.

## Step 0 — Load configuration

Read `.tdd-pipeline/config.yaml`. Follow the fail-fast protocol in
`core/contracts/pipeline-config.md`: stop and name the exact missing key if
the file or a key this flow needs is absent. This flow needs `paths.specs`,
`paths.conventions`, and `git.commit_trailer`.

## Step 1 — Understand the goal

Ask before exploring. Even a description that reads as complete carries
assumptions the person holds and has not written down, and the cost of
discovering them after the spec is drafted is a rewrite.

Ask about scope (what is included, and what is explicitly not), about
approach preferences (an architecture, a pattern, a library the person
already intends), about constraints (compatibility, sequencing, work this
depends on or blocks), and about who or what consumes the result.

Ask these as a small number of concrete questions and wait for the answers.
Two to four is the useful range: fewer leaves the exploration unaimed, more
turns a design conversation into a form.

This flow asks twice — here, and again in Step 3 — for a reason worth
stating. These first questions are the ones that can be asked without
knowing the codebase, and asking them now keeps Step 2 from exploring in the
wrong direction. The second round is the opposite: questions that only
become askable once the exploration has found something.

## Step 2 — Explore

Dispatch subagents in parallel, each covering a distinct concern, the same
way `review` does:

- **What already exists** — the models, routes, components, jobs, or
  modules covering this area today, and the patterns they establish that a
  new design should follow rather than reinvent.
- **The nearest precedent** — a feature already built in this codebase that
  solved a structurally similar problem. Its shape is the strongest
  available evidence about what will fit here.
- **What this touches** — the modules, contracts, and data flows a change in
  this area reaches, including the ones the description did not mention.

Read the files these reports surface closely enough to judge them yourself.
A design assembled from subagent summaries inherits their compressions, and
the compressions are where the constraint that breaks the design hides.

Read `paths.conventions` as well. A plan that contradicts a rule the project
already holds itself to is a finding to raise in Step 3, not a decision to
make silently here.

## Step 3 — Resolve the open questions

Exploration turns vague questions into specific ones. Ask this second round
now: the design decisions the codebase itself has just made askable — where
new state belongs given where existing state lives, which of two established
patterns applies when both are present, how far the change should reach when
the exploration found more callers than expected.

State the assumptions the design rests on as a numbered list and ask which
are wrong. An assumption a person can correct in one word is cheaper than a
finding a phase surfaces three steps into implementation.

If exploration showed the work is too large for a single pass through the
pipeline, say so here and propose the split, per the subtask structure in
`core/contracts/spec-template.md`. Deciding that at the end, after a spec has
been drafted as one unit, wastes the drafting.

## Step 4 — Draft the spec

Write the spec into `paths.specs`, following the skeleton and completeness
rules in `core/contracts/spec-template.md` exactly — every section present,
including `## Out of Scope` and an empty `## Agent Handoff Log`.

Name it for its subject, not for a task ID this flow never resolved: a
short, specific, hyphenated name (`webhook-delivery-retries`). If the work
later becomes a tracked item, `task` writes its own spec under the tracker's
ID, and this one stands as the design that preceded it.

The completeness rules apply here in full, and two of them are the reason
this flow writes a real spec rather than a looser plan document: an
unverified external API schema and an unverified claim about existing
internal infrastructure are both rejected. Resolve them now, while a person
is present and exploration is fresh — the phases that read this spec later
cannot, and `review` would only send it back.

Every step in `## Approach` must be actionable. "Handle the error case" is
not a design; it is a note that a design is still owed.

## Step 5 — Confirm with the user

Show what was written and ask for corrections. Iterate until the person
agrees, editing the file rather than defending the draft.

This is the last gate in this flow, and unlike `task`'s gate it opens onto
nothing — agreement here means the spec is finished, not that anything is
about to run. Say that plainly, so nobody approves expecting work to start.

## Step 6 — Commit

Commit the spec file:

```bash
git add <spec file>
git commit -m "plan: <spec name>"
```

If `git.commit_trailer` is non-empty, append it as a trailer on the commit
message. If it is empty, omit it entirely — do not add an empty trailer
line.

Commit for the same reason `init` commits its configuration: every phase
runs inside a worktree created fresh from `git.base_branch`, which contains
only committed files. A spec that exists solely in this checkout's working
tree is invisible to every phase that would later read it, and the failure
appears as a missing spec in a project where the spec is plainly on disk.

Stage only the spec file. This flow wrote nothing else, and staging anything
else would commit work that is not its own.

## Step 7 — Report

Return, in order:

- The spec path, and a one-line summary of what it designs.
- What Step 3 established as out of scope — the boundary is the part of a
  design most easily lost between the conversation and the file.
- Whether Step 3 proposed splitting the work, and into what.
- The next step, named as a command rather than described: `review` to have
  the spec critiqued by a fresh reader before anyone builds against it, or
  `task` to take it through the pipeline.

Do not run either of them. This flow ends here, and a flow that continues
into implementation because the design looked finished is the exact
commitment this flow exists to avoid making on a person's behalf.
