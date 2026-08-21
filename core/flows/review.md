# Flow: review

Critique a task spec against the actual codebase, then fix it. This flow runs
the same way whether invoked standalone by a person or inline by `task`'s
Step 3 against a spec that flow just drafted. Nothing here branches on which
is happening — the tracker layer already accounts for the difference between
a tracker-linked item and a spec with no tracker behind it.

## Input

The argument is a task ID (for example `TASK-1`) or a spec path. If neither
is given, infer the task ID from the current branch name; if that also fails
to resolve a spec, list `paths.specs` and ask which file to review.

## Mindset

You did not write this spec. You are a skeptical fresh reader, not its
author's second opinion of themselves — your job is to find what the author
missed, because the phase that implements this spec follows it literally and
has no memory of whatever reasoning produced it.

Read every section asking: what could go wrong that isn't covered here? What
existing code would this break? Which assumptions does this spec make that
aren't actually true? What's missing from the Definition of Done that would
let a phase call this task finished while real gaps remain?

## Step 0 — Load configuration

Read `.tdd-pipeline/config.yaml` before anything else. Follow the fail-fast
protocol in `core/contracts/pipeline-config.md`, which governs every flow and
phase without exception: stop and name the exact missing key if the file or a
key this flow needs is absent. This flow needs `paths.specs`,
`paths.conventions`, and `git.commit_trailer`.

Being invoked inline by `task`, which already loaded the configuration, is
not a reason to skip this step. This flow is equally reachable standalone,
and one that reads three configured values while trusting a caller to have
validated them has no defined behaviour on the path where it runs first.

## Step 1 — Load context

Read the spec file in full — every section in
`core/contracts/spec-template.md`'s skeleton, not only
`## Definition of Done`. Read `paths.conventions` to know what the project
already holds itself to. Read `## Agent Handoff Log` in full, per
`core/contracts/handoff-log.md`; the spec is unimplemented at this point, so
that section carries only what an earlier run of this flow, or a planning
conversation, left there.

## Step 2 — Explore

Dispatch subagents in parallel, each covering a distinct concern:

- **Impact** — read every file `## Files to Modify` names, trace the callers
  and consumers of anything being changed, and identify files that should be
  in that list but are not.
- **Existing patterns** — find an analogous feature already built here and
  compare the spec's approach against how that one actually works. A spec
  that contradicts an established pattern without saying why is a finding.
- **Test coverage** — read the tests already covering the affected area, and
  confirm the Definition of Done and any verification steps are actually
  executable against this project as written.

Read what these subagents surface closely enough to judge it yourself in
Step 3 — their reports inform the critique, they do not substitute for it.

## Step 3 — Critique

Apply the completeness rules in `core/contracts/spec-template.md` in full,
judging correctness, completeness, security and isolation implications, and
backward compatibility against what Step 2 actually found — not against the
spec's own account of itself.

Two rules from that contract are hard blockers, not judgment calls: a spec
containing an unverified external API schema, or an unverified claim about
existing internal infrastructure, is rejected outright. A spec reading
"verify before implementing" against either does not pass with a note — that
phrase moves a verification this flow is supposed to complete into a phase
that has no way to complete it. Resolve it yourself: read the documentation,
locate the actual code, and decide once you know rather than once you have
written down that someone should find out.

## Step 4 — Fix the spec

Do not stop at reporting what Step 3 found — apply every finding to the spec
file directly. Add files Step 2 found missing from `## Files to Modify`. Add
edge cases to `## Approach` or wherever they belong. Add missing acceptance
criteria to `## Definition of Done`. Correct a contradicted pattern, a wrong
assumption, or an unverified claim in place, backed by what Step 2 and Step 3
confirmed. If the spec is too broad for one pass, propose splitting it per
`core/contracts/spec-template.md`'s subtask structure.

Write the correction, not the case for it. The body gets the instruction as
it should now read; the finding, the draft it replaces, and the evidence
that settled it go in Step 5's entry — see `## What a spec leaves out` in
`core/contracts/spec-template.md`. Writing both in both places puts one of
them where it cannot be used: `## Approach` is read as the instructions, so
a paragraph on why the old rule failed is a paragraph the executing phase
has to rule out before it can start.

A spec this step leaves unchanged because nothing needed fixing is a valid
outcome — say so plainly in Step 5 rather than fixing something to have
something to report.

## Step 5 — Handoff log

Append a `### review` subsection to `## Agent Handoff Log`, per
`core/contracts/handoff-log.md`. This is the entry the `pipeline` phase's
precondition checks for before running any phase against this spec — record
it even when Step 4 found nothing to change, since the entry itself, not its
contents, is what that precondition looks for.

Include:

- Every finding from Step 3, and what Step 4 did about it — added, fixed, or
  explicitly left as-is with the reasoning.
- Confirmation that both hard blockers were checked and cleared, naming what
  was verified and against what source.
- Any pattern reference or assumption Step 2 validated or invalidated.
- Whether this spec should be split, and why, if Step 4 proposed it.

Apply the escalation routing table in `core/contracts/handoff-log.md`: a
finding that is a durable fact about the codebase belongs in
`paths.conventions`, appended inside its discoveries span
(`core/contracts/conventions-template.md`) and never inside the managed
section, which the conventions flow regenerates wholesale. Note any such
escalation in this same entry.

Commit the spec file's changes:

```bash
git add <spec file>
git commit -m "<task-id>: review spec"
```

If `git.commit_trailer` is non-empty, append it as a trailer; if empty, omit
it entirely.
