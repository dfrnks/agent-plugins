# Flow: review

Critique a task spec against the actual codebase, then fix it. This flow
runs the same way whether it is invoked standalone, directly by a person
against an existing spec, or inline, dispatched by `task`'s own Step 3
against a spec that flow just finished drafting. Nothing in this flow
branches on which one is happening — the tracker layer already accounts for
whatever difference exists between a tracker-linked item and a spec with no
tracker behind it, so this flow reads and fixes the spec file itself either
way.

## Input

The argument is a task ID (for example `TASK-1`) or a spec path directly. If
neither is given, infer the task ID from the current branch name; if that
also fails to resolve a spec, list `paths.specs` and ask which file to
review.

## Mindset

You did not write this spec. You are a skeptical fresh reader, not its
author's second opinion of themselves — your job is to find what the
author missed, because the phase that implements this spec later follows it
literally and has no memory of whatever reasoning produced it.

Read every section asking: what could go wrong that isn't covered here?
What existing code would this break? Which assumptions does this spec make
that aren't actually true? What's missing from the Definition of Done that
would let a phase call this task finished while real gaps remain?

## Step 0 — Load configuration

Read `.agent-pipeline/config.yaml` before anything else. Follow the
fail-fast protocol in `core/contracts/pipeline-config.md` — which governs
every flow and phase "without exception", this one included: stop and name
the exact missing key if the file or a key this flow needs is absent. This
flow needs `paths.specs`, `paths.conventions`, and `git.commit_trailer`.

Being invoked inline by `task`, which already loaded the configuration, is
not a reason to skip this step. This flow is equally reachable standalone,
and a flow that reads three configured values while trusting a caller to
have validated them has no defined behaviour on the path where it is the
first thing to run — the same reasoning the pipeline phase gives for
re-checking preconditions the task flow already established.

## Step 1 — Load context

Read the spec file in full — every section in
`core/contracts/spec-template.md`'s skeleton, not only `## Definition of
Done`. Read the file at `paths.conventions` to know what the project already
holds itself to. Read the `## Agent Handoff Log` section in full, per
`core/contracts/handoff-log.md` — every phase's spec is unimplemented at
this point, so this section carries only what an earlier run of this flow,
or a planning conversation, already left there.

## Step 2 — Explore

Dispatch subagents in parallel, each covering a distinct concern:

- **Impact** — read every file the spec's `## Files to Modify` names, trace
  the callers and consumers of anything being changed, and identify files
  that should be in that list but are not.
- **Existing patterns** — find an analogous feature already built in this
  codebase, and compare the spec's approach against how that one actually
  works. A spec that contradicts an established pattern without saying why
  is a finding, not an improvement.
- **Test coverage** — read the tests already covering the affected area,
  and confirm the spec's Definition of Done and any verification steps it
  names are actually executable against this project as written.

Read whatever these subagents surface closely enough to judge it yourself in
Step 3 — their reports inform the critique, they do not substitute for it.

## Step 3 — Critique

Apply the completeness rules in `core/contracts/spec-template.md` in full,
judging correctness, completeness, security and isolation implications, and
backward compatibility against what Step 2 actually found — not against the
spec's own account of itself.

Two rules from that contract are hard blockers, not judgment calls: a spec
containing an unverified external API schema, or an unverified claim about
existing internal infrastructure, is rejected outright. A spec that reads
"verify before implementing" against either one does not pass with a note —
that phrase moves a verification this review flow is supposed to complete
into the phase that has no way to complete it, and rejecting it is this
flow's whole job in that case. Resolve the verification yourself before
deciding whether the spec passes: read the documentation, locate the actual
code, and only decide once you know rather than once you've written down
that someone should find out.

## Step 4 — Fix the spec

Do not stop at reporting what Step 3 found — apply every finding to the
spec file directly. Add files Step 2 found missing from `## Files to
Modify`. Add edge cases the critique surfaced to `## Approach` or wherever
they belong. Add missing acceptance criteria to `## Definition of Done`.
Correct a contradicted pattern, a wrong assumption, or an unverified claim
in place, now backed by what Step 2 and Step 3 actually confirmed. If the
spec turns out to be too broad for one pass through the pipeline, propose
splitting it into subtasks per `core/contracts/spec-template.md`'s subtask
structure, rather than leaving an oversized spec as a single unit.

A spec this step leaves unchanged because nothing needed fixing is a valid
outcome — say so plainly in Step 5's entry rather than fixing something
just to have something to report.

## Step 5 — Handoff log

Append a `### review` subsection to `## Agent Handoff Log`, per
`core/contracts/handoff-log.md`. This is the entry the `pipeline` phase's
own precondition checks for before it will run any phase against this
spec — record it even when Step 4 found nothing to change, since the entry
itself, not its contents, is what that precondition looks for.

Include:

- Every finding from Step 3, and what Step 4 did about it — added, fixed, or
  explicitly left as-is with the reasoning.
- Confirmation that both hard blockers were checked and cleared, naming
  what was verified and against what source.
- Any pattern reference or assumption Step 2's exploration validated or
  invalidated.
- Whether this spec should be split, and why, if Step 4 proposed it.

Apply the escalation routing table in `core/contracts/handoff-log.md`: a
finding that is a durable fact about the codebase belongs in
`paths.conventions` — appended inside its discoveries span
(`core/contracts/conventions-template.md`), never inside the managed section,
which the conventions flow regenerates wholesale on its next run — not
buried here as a task-only detail. Note any such
escalation in this same entry.

Commit the spec file's changes:

```bash
git add <spec file>
git commit -m "<task-id>: review spec"
```

If `git.commit_trailer` is non-empty, append it as a trailer on the commit
message. If it is empty, omit it entirely.
