# Project requirements contract

This is the single normative list of what a consuming project must have in
place, who creates each artifact, and who checks it afterward. The init,
conventions, and doctor flows all cite this table instead of restating it.

Every requirement below applies to a project that already holds source code.
A project that holds none yet is a defined state, not a broken one — see
`## Greenfield projects` for which requirement it suspends, how that state is
detected, and when it ends.

See `core/contracts/pipeline-config.md` for the configuration schema itself —
this contract only names which keys and paths must exist, not their format.

## Requirements

| Requirement | Required | Created by | Validated by |
|---|---|---|---|
| `.agent-pipeline/config.yaml` with every key the configured mode uses, tracked in git | yes | init (writes and commits) | every phase, step 0 |
| Git repository with `git.base_branch` present | yes | — | doctor, task |
| `paths.specs` directory | yes | init | doctor |
| `paths.worktrees` directory, git-ignored | yes | init | doctor |
| `paths.conventions` file, non-empty, with derived stack rules, tracked in git | yes, except while greenfield | conventions (writes and commits) | doctor, execute phase |
| `.agent-pipeline/memory/` directory | no | init | doctor |
| `paths.review_checklist`, tracked in git when set | no | conventions (writes and commits) | doctor |
| `git.worktree_setup` script, executable, if dependencies are git-ignored | conditional | init proposes and sets the executable bit | doctor, task |
| Tracker auth (Linear or `gh auth`) | conditional on `tracker.type` | — | doctor, task |

## Why a populated conventions file is mandatory

The execute and code-review phases do not carry their own inline rules for
project-specific conventions. They delegate that entirely to the project's
conventions file — the one named by `paths.conventions` — reading it at the
start of each run and applying whatever it finds.

That delegation has a failure mode when the file is empty or missing real
content: the phases still run, still report success, and still enforce
nothing, because there was nothing in the file to enforce. This is a silent
pass, and it is worse than a hard failure — a hard failure stops the pipeline
and gets fixed; a silent pass ships unreviewed work while every report says
green.

Therefore the doctor flow treats a conventions file that exists but holds no
rules as a **fail**, never a pass. "Holds no rules" is defined concretely so
this is a mechanical check, not a judgment call: fewer than five **rule
lines** found **between the two managed-section markers** that the
conventions flow writes — see `conventions-template.md` for the exact marker
pair.

A rule line is a list item **carrying** a `file:line` citation anywhere in
it, which is the exact shape the conventions flow writes a rule in. Count
list items, not physical lines: a rule wraps across as many lines as it
needs, and its citation closes the item rather than its first line — the
worked example in `conventions-template.md` is itself two lines long, with
the citation on the second. Reading this as "the line ends in a citation"
would miss every wrapped rule, and so fail a conventions file holding five
perfectly good ones. Headings never count,
and this is the load-bearing part of the definition rather than a detail:
the conventions flow emits all seven area headings on every run, including
for areas where nothing was derived, so a threshold counting headings would
report `pass` on a file holding no rules whatsoever — reintroducing the
silent pass this rule exists to prevent. A "no rule derived" line never
counts either, for the same reason, nor does an uncited list item: without
a citation there is nothing a later run or a human can check the line
against.

The count never extends past the closing marker or before the opening one;
hand-written prose anywhere outside that span, however long, does not count
toward the threshold, and neither does anything in the discoveries span,
which holds unconfirmed candidates rather than derived rules. A file above
that threshold may still be thin, but a file below it is treated as
equivalent to absent, and doctor reports it exactly the way it reports a
missing file — naming the path and directing the user to the conventions
flow.

## Greenfield projects

The threshold above assumes there was something to derive rules from. A
repository that holds no source code yet breaks that assumption, and
enforcing the threshold against it produces a failure with no reachable fix:
the conventions flow's own rule bar needs two or more independent call sites
(`core/flows/conventions.md`, Step 2), a repository with no source has zero,
so the flow correctly derives nothing, doctor correctly counts zero rules,
and the remedy doctor names is the flow that just ran. Init would end at
`not ready` on every new project, permanently, and the report would blame
the conventions file rather than the absence of code.

So this contract defines that absence as a state with a name. **While a
project is greenfield, the `paths.conventions` row is `n/a`, not `fail`** —
the file still gets created and committed with its seven headings, and every
other requirement in the table applies unchanged.

### Detecting it

Greenfield is a mechanical test, run against what git tracks — not a
judgment about whether a project "feels" new, and not a count of files on
disk, since an untracked working tree is invisible from the worktrees every
phase runs inside:

```bash
git ls-files -- . \
  ':(exclude).agent-pipeline/**' \
  ':(exclude)*.md' \
  ':(exclude).gitignore' \
  ':(exclude)LICENSE*'
```

The exclusions are the pipeline's own artifacts, the project's prose, and
repository metadata — none of which a rule could carry a `file:line`
citation into. **Empty output means greenfield.** Any remaining path at all
means the project is not greenfield and the five-rule threshold applies in
full.

### Why the test is empty-or-nothing

That last sentence is the load-bearing part, and it is deliberately blunt
rather than proportionate. A greenfield verdict *waives* the one check that
exists to prevent silent non-enforcement, so a wrong verdict in that
direction is the exact failure `## Why a populated conventions file is
mandatory` describes: every phase runs, every phase reports success, and
nothing project-specific is enforced.

The two directions of error are therefore not symmetric, and the test is
tuned accordingly:

- Wrongly reporting a real codebase as greenfield **waives enforcement
  silently** — the failure this whole contract exists to prevent.
- Wrongly reporting an empty project as non-greenfield produces a `fail`
  naming the conventions file. Noisy, visible, and no worse than the
  behaviour this section replaces.

Never soften the test toward the first error to make a report look tidier —
no "mostly empty," no "only scaffolding," no threshold of a few files that
seem unimportant. One tracked source file is enough to end the state,
because one file is enough for a human to have made a choice worth
enforcing.

### When it ends

The state is self-clearing and nothing needs to remember it: the test above
is re-run fresh on every doctor invocation, so the first commit that tracks
a source file flips the `paths.conventions` row from `n/a` back to whatever
it honestly is — which, on a project whose conventions have never been
derived, is `fail`, naming the conventions flow, which can now succeed.

Nothing is persisted to record that a project was ever greenfield. A stored
flag would have to be cleared by whoever adds the first source file, and the
one thing that can be relied on not to happen is a person updating a marker
about a state they were never told they were in.

Because the state clears on a commit rather than on a run of any flow, the
first task the pipeline ships against a greenfield project is the moment it
stops being true. The end phase reports that transition when it sees it
(`core/phases/end.md`, Step 3), so the first person to add code learns that
conventions are now derivable — rather than discovering it at the next
unrelated doctor run.
