# Design — automatic flow routing

**Date:** 2026-08-07
**Status:** approved, ready for implementation planning

## Problem

Every entry point this plugin ships is a slash command. `adapters/claude-code/commands/`
and `adapters/cursor/commands/` hold eight files each, and a command runs only
when a person types its name. Nothing in the plugin tells an agent *when* to
enter a flow on its own.

The consequence is the ordinary case, not an edge one. A user says "vamos criar
um botão que ao ser clicado abre um modal para editar imagens" and the agent
does exactly what it would do without this plugin installed: explores a little,
edits the files, and reports. No spec, no review, no failing test first, no
worktree, no pull request. The pipeline is installed and idle, and the only
thing standing between the project and its own process is whether the user
remembered to type `task`.

The command descriptions make this worse rather than better, because they
describe the mechanism instead of the trigger:

> `Run a task end to end — spec, review gate, TDD pipeline, pull request.`

An agent matching intent against that text learns what the command does, not
which requests belong to it. Compare a description written as a trigger, which
is why `brainstorming` fires unprompted and `plan` does not:

> `You MUST use this before any creative work — creating features, building
> components, adding functionality, or modifying behavior.`

## Decisions taken

Settled with the user before this document was written:

1. **Both mechanisms, no hook.** Trigger-shaped descriptions so the agent finds
   the flow, plus a routing rule in the project's own instructions file so the
   flow is not simply bypassed. A `UserPromptSubmit` hook was rejected: it is
   Claude Code only, it would violate the neutrality `checks/core-is-neutral.sh`
   enforces over `core/`, and Cursor would have no equivalent.
2. **Routing depends on the request**, not a single destination. A reported
   defect goes to `fix-bug`; a well-scoped change goes to `task`; something
   large or with two plausible shapes goes to `plan` first.
3. **Four categories stay out** of routing entirely, handled directly: questions
   and read-only work, trivial changes with no new behaviour, git/CI/environment
   operations, and a change the user already specified line by line.

## Constraints discovered

- `checks/core-is-neutral.sh` bans the literal token `CLAUDE\.md` — along with
  `claude`, `cursor`, and `CLAUDE_PLUGIN_ROOT` — inside every `core/**/*.md`.
  No core file may name the project instructions file it writes to. The name
  comes from configuration, and its default comes from the adapter.
- `checks/manifest.txt` pins the exact `##` heading list of each core flow and
  phase. Adding a numbered step to a core flow requires updating that line;
  `adapters/` has no manifest entry at all, so `description:` frontmatter is
  free to change.
- `core/contracts/conventions-template.md` already establishes this project's
  marker convention for a generated span inside a hand-written file. The
  routing block reuses it rather than inventing a second one.

## Part A — descriptions as triggers

Rewrite the `description:` frontmatter of **`task`, `plan`, and `fix-bug`** in
both harnesses — six files, frontmatter only, no body change.

The other five commands keep their current descriptions. `init`, `doctor`,
`conventions`, `review`, and `resume` are operations a person asks for by name,
not intents to be recognised from a description of the work; giving them
trigger language buys nothing and produces false fires.

Each new description carries the trigger **and** the boundary, because the
description is the only text the agent reads before deciding.

`plan`:

> Use when the user describes a change that needs designing before it gets
> built — a feature, a module, a migration, an architectural change — or when
> the request has two plausible shapes and the choice has to be argued first.
> Explores the codebase, settles the open questions, writes a spec, and stops
> without running anything. Not for questions about the code, trivial edits,
> git or CI operations, or a change the user already specified line by line.

`task`:

> Use when the user asks for a well-scoped change to be built and shipped — a
> feature, an endpoint, a component, a behaviour change — and the design is not
> in question. Resolves the item, writes and reviews a spec, stops at a
> confirmation gate, then runs the TDD pipeline against a worktree and opens a
> pull request. Not for questions about the code, trivial edits with no new
> behaviour, git or CI operations, or a change the user already specified line
> by line.

`fix-bug`:

> Use when the user reports a defect — something that used to work, wrong
> output, an unexpected error, a crash. Reproduces it with a failing test
> first, names the root cause, makes the minimal change, and verifies nothing
> else broke. Not for a change that adds new behaviour, which is a task, and
> not for questions about the code or git and CI operations.

## Part B — routing rule in the project

A description helps the agent *find* the flow. It does not stop the agent from
deciding to just make the edit. For that, the rule has to live in the file the
harness loads unprompted at the start of every session, in the project itself.

### B1 — configuration key

Add one optional key to `core/contracts/pipeline-config.md`, in the schema and
in the "Required keys by mode" table as optional in every mode:

`paths.agent_instructions` — the project instructions file the agent harness
loads on its own. Core describes it that way and never names it. The adapter
supplies the default when `init` proposes the configuration: `CLAUDE.md` for
Claude Code, `AGENTS.md` for Cursor.

Optional, not required, so that every project already carrying a
`.tdd-pipeline/config.yaml` keeps passing `doctor` without an edit. Unset means
the routing block is not managed for that project, and `doctor` reports the
check as `n/a` rather than as a failure.

### B2 — the block

Delimited by markers, in the shape `core/contracts/conventions-template.md`
already defines for the conventions file, and governed by the same three rules
that contract states: only the span between the markers is rewritten, absent
markers mean append rather than reorder, and a half-present or out-of-order
pair means stop as malformed rather than guess.

```markdown
<!-- pipeline:routing:start -->
## Development pipeline

A change to this project's code goes through a pipeline flow, not straight to
an edit:

- A reported defect — something that used to work, wrong output, an error, a
  crash — goes to the fix-bug flow.
- A well-scoped change whose design is not in question goes to the task flow.
- A change too large for one pass, or one with two plausible shapes, goes to
  the plan flow first.

Handle these directly, with no flow:

- Questions about the code, and anything else read-only.
- A trivial change with no new behaviour — a typo, a rename, formatting, a
  version bump.
- Git, CI, and environment operations.
- A change the user already specified precisely enough that routing it would
  redo a decision they have already made.
<!-- pipeline:routing:end -->
```

Core owns this text with the flows named plainly, as above. How a flow is
actually invoked is harness-specific, so each adapter's `init` command states
the invocation form for its harness, and the flow renders the three routing
lines using it — the same division of labour the adapters already use for
subagent dispatch and `${CLAUDE_PLUGIN_ROOT}`.

### B3 — who writes it

`core/flows/init.md` gains a step between the current Step 5 (Derive
conventions) and Step 6 (Verify), which becomes Step 7. It writes the block to
`paths.agent_instructions` and commits it alongside nothing else, staging only
that path — the same rule Step 3 already states about never running `git add .`
in a repository holding the user's own uncommitted work.

Step 2 proposes `paths.agent_instructions` with the adapter's default, in the
same pass that already asks for `paths.conventions` and `tracker.prefix`.

`checks/manifest.txt` updates on the `core/flows/init.md` line for the new and
renumbered headings.

### B4 — projects already initialised

`init` runs once per project and never again, so a project set up before this
change would never receive the block. `core/flows/doctor.md` gains a check
inside its existing `## Checks` section — no new heading, so no manifest
change — that reports whether `paths.agent_instructions` is set and whether the
file carries a well-formed marker pair. Repair mode inserts the block when it is
missing, and reports the file as malformed without touching it when only one
marker is present.

## Files to modify

| File | Change |
|---|---|
| `adapters/claude-code/commands/{task,plan,fix-bug}.md` | `description:` frontmatter |
| `adapters/cursor/commands/{task,plan,fix-bug}.md` | `description:` frontmatter |
| `adapters/{claude-code,cursor}/commands/init.md` | state the harness's instructions-file default and flow invocation form |
| `core/contracts/pipeline-config.md` | `paths.agent_instructions` in schema and required-keys table |
| `core/flows/init.md` | propose the key in Step 2; new step writing the block; renumber Verify |
| `core/flows/doctor.md` | routing-block check and its repair |
| `checks/manifest.txt` | new heading list for `core/flows/init.md` |

## Out of scope

- Any hook, in either harness.
- Trigger descriptions for `init`, `doctor`, `conventions`, `review`, `resume`.
- Changing what any flow does once entered. This design changes only how a flow
  is reached.

## Definition of Done

- `./tests/run.sh` passes, including `core-is-neutral.sh` over the edited core
  files and `structure.sh` against the updated manifest.
- No `core/**/*.md` names a harness or an instructions filename.
- `doctor` reports the new check as `n/a` on a project whose config omits
  `paths.agent_instructions`, and as a pass on one that has the block.
- Running `init` twice against the same project leaves exactly one marker pair
  and does not disturb hand-written text around it.
