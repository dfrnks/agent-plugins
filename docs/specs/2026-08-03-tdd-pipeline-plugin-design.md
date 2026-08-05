# Design — `tdd-pipeline`: a portable, harness-agnostic development pipeline

**Date:** 2026-08-03
**Status:** approved, ready for implementation planning

## Problem

A mature agent-driven development pipeline already exists and works end to end:
from task creation to an open pull request, with mandatory TDD, spec review
before implementation, and code review after it. It lives inside a single
project and is wired to that project — stack, test and lint commands, absolute
paths, issue tracker, ID prefix — and to a single agent harness.

The goal is to extract the pipeline's mechanics into a reusable package,
installable in any project on any supported harness, leaving no trace of the
originating project.

## Decisions

| Decision | Choice |
|---|---|
| Harnesses | Claude Code and Cursor, first-class both |
| Packaging | Harness-neutral `core/`, thin per-harness adapters |
| Distribution | Git repo `dfrnks/agent-plugins`; native plugin install for Claude Code, install script for Cursor |
| Project configuration | `.agent-pipeline/config.yaml` (deterministic) + the project's conventions file (prose) |
| Issue tracker | Pluggable: `none` (default) \| `linear` \| `github` |
| Stack rules | Never in the package; always in the project's conventions file, derived by `/conventions` |
| Worktree creation | Plain `git worktree add`, never a harness-specific isolation primitive |
| Command surface | Six commands, two families: setup and work |
| Entry point | A single `/task`, end to end, with a confirmation gate after the spec |
| Originating project | Left untouched; no migration in v1 |
| Commit trailer | Empty by default |

### Cross-cutting constraints

**Language.** Every document, prompt, README, comment, and error message in this
repository is written in English.

**No leakage.** No file in the package — prompt, README, example, frontmatter,
or error message — may contain a real project name, absolute path, person's
name, or organization identifier. Examples use `my-app` and `TASK-1` style IDs.
A final `grep` gate validates this before any push.

**No harness names in `core/`.** Core files never mention a specific harness,
tool name, or frontmatter key. They say "dispatch a subagent", not "call the
`Agent` tool". Anything harness-specific belongs in an adapter.

## Harness portability

The two supported harnesses have near-parity on everything the pipeline needs.
Verified against Claude Code and Cursor Agent v2026.07:

| Capability | Claude Code | Cursor | Where the difference is handled |
|---|---|---|---|
| Custom subagents | `agents/*.md` at the plugin root | `.cursor/agents/*.md` | adapter file shape; Claude Code's must live at the plugin root, not under `adapters/` — see below |
| Subagent frontmatter | `name`, `description`, `model`, `permissionMode`, `memory` | `name`, `description` | adapter |
| Subagent dispatch | `Agent` tool | `Task` tool | adapter names the tool; core says "dispatch a subagent" |
| Slash commands | `commands/*.md` | `.cursor/commands/*.md` | adapter |
| Persistent project rules | `CLAUDE.md` | `AGENTS.md`, `.cursor/rules/*.mdc` | `paths.conventions` in config |
| Skills | `SKILL.md` | `SKILL.md` | identical |
| MCP | yes | yes | identical |
| Worktree isolation | `isolation: "worktree"` | `best-of-n-runner` subagent | **neither** — see below |

Everything else — the phase prompts, the config contract, the spec template, the
handoff-log protocol, git, and the tracker layer — is identical prose and lives
in `core/` exactly once.

### Worktrees use plain git

The inherited design asked the harness to create the worktree. That primitive
differs between harnesses, and it forced two workarounds: the harness names the
branch `worktree-<random>`, so the orchestrator had to rename it to the task ID;
and the harness bases the worktree on the base branch's HEAD, so the spec had to
be committed and pushed before dispatch or it would be invisible.

The package uses `git worktree add <path> -b <task-id> <base>` directly. The
branch is correct from birth, the working tree is whatever git says it is, and
the mechanism is identical on every harness — including any future one. The only
thing lost is automatic worktree cleanup, which the inherited design already
never benefited from: the pipeline always writes files, so the worktree was
always preserved anyway.

## Repository layout

```
dfrnks/agent-plugins/
├── README.md
├── install.sh                       symlinks an adapter into a project
├── docs/specs/
├── .claude-plugin/
│   ├── marketplace.json             lists the tdd-pipeline plugin entry
│   └── plugin.json                  Claude Code plugin manifest (see below)
├── core/                            harness-neutral; the actual content
│   ├── phases/
│   │   ├── test.md                  red phase
│   │   ├── execute.md               green phase
│   │   ├── code-review.md           adjudicates implementation against spec
│   │   ├── end.md                   lint, commit, push, PR, tracker status
│   │   └── pipeline.md              orchestration of the four phases
│   ├── flows/
│   │   ├── task.md                  end-to-end entry flow
│   │   ├── review.md                spec critique
│   │   ├── resume.md                re-enter an interrupted pipeline
│   │   ├── init.md                  project bootstrap
│   │   ├── conventions.md           derive stack rules from the codebase
│   │   └── doctor.md                verify project requirements
│   ├── contracts/
│   │   ├── project-requirements.md  normative list of what a project provides
│   │   ├── pipeline-config.md       config.yaml schema and semantics
│   │   ├── spec-template.md         task spec structure + Definition of Done
│   │   ├── handoff-log.md           handoff protocol and escalation rules
│   │   ├── conventions-template.md  section skeleton for the conventions file
│   │   └── review-checklist-base.md stack-agnostic review checklist seed
│   └── trackers/{none,linear,github}.md
├── agents/*.md                      Claude Code subagents (see below for why
│                                     these sit at the repository root, not
│                                     under adapters/claude-code/)
└── adapters/
    ├── claude-code/
    │   └── commands/*.md            frontmatter + pointer into core/flows/
    └── cursor/
        ├── agents/*.md
        └── commands/*.md
```

An adapter file carries only what its harness requires, plus a pointer:

```markdown
---
name: task-test
description: Writes the failing test suite for a task, before implementation.
model: opus
---
Follow ${CLAUDE_PLUGIN_ROOT}/core/phases/test.md.
Dispatch subagents with the `Agent` tool.
```

Fixing a rule means editing one file in `core/`, and both harnesses get it.

### Why the Claude Code manifests live at the repository root, not under `adapters/claude-code/`

`${CLAUDE_PLUGIN_ROOT}` resolves to whatever directory the marketplace entry's
`source` names — nothing more. A `source` of `./adapters/claude-code` installs
only that subtree; `core/` is never copied alongside it, so every
`${CLAUDE_PLUGIN_ROOT}/core/...` pointer in an adapter dangles at install time.
This is verified, not assumed: installing the plugin from a `source` scoped to
`adapters/claude-code` produces an installed directory containing only
`agents/`, `commands/`, and `.claude-plugin/` — no `core/`.

The fix keeps `source: "."` — the whole repository installs, so `core/` is
always present at `${CLAUDE_PLUGIN_ROOT}/core/...`. `plugin.json` sits at the
repository root next to `marketplace.json`, in the same `.claude-plugin/`
directory, rather than the plugin nesting its own `.claude-plugin/` a level
down.

Where the five agent files live took a second, independently verified round.
`plugin.json`'s `agents` key, given an array of individual file paths (the
original layout, each path under `adapters/claude-code/agents/`), installs
without error and reports success — but loads **zero** agents. This is a
distinct failure from the one above: it is silent, and it was not caught by
`claude plugin details` either, because that command reports an install-time
snapshot rather than live disk — editing a plugin's cached files in place
does not change what it reports next, which makes it look like a display
quirk until an install is repeated from a clean marketplace-add each time. A
controlled experiment across three variants, each a full clean install (not
an in-place cache edit), settled it:

| Variant | `agents` key | Result |
|---|---|---|
| array of five explicit file paths (the original layout) | installs cleanly, **0 agents loaded** |
| array containing one directory path | **install fails**: `Validation errors: agents: Invalid input` |
| key removed entirely; agent files placed at `<plugin-root>/agents/` | **5 agents loaded** |

Only the third variant works. The `commands` key, by contrast, already
accepts a directory value (`["./adapters/claude-code/commands/"]`) and loads
correctly — that asymmetry between the two keys is exactly what made the
`agents` failure easy to miss. The fix: the five agent files sit at
`agents/` under the repository (= plugin) root, and `plugin.json` carries no
`agents` key at all — Claude Code's default agent-discovery path covers it.
`adapters/claude-code/` keeps only `commands/*.md`, which the `commands` key
still points at explicitly, since that form is confirmed to work.

Verified by a real install-uninstall cycle: `claude plugin marketplace add
<this repository>`, `claude plugin install tdd-pipeline`, then `claude plugin
details tdd-pipeline` reporting `Agents (5)` — `task-end`, `task-test`,
`task-pipeline`, `task-code-review`, `task-execute` — followed by `claude
plugin uninstall` and `claude plugin marketplace remove` to leave the
installing machine as found.

### Installation

**Claude Code** — native plugin, `${CLAUDE_PLUGIN_ROOT}` resolves `core/` paths:

```
/plugin marketplace add dfrnks/agent-plugins
/plugin install tdd-pipeline
```

**Cursor** — clone once, then per project:

```
./install.sh --harness cursor --project /path/to/project
```

The script symlinks `adapters/cursor/{agents,commands}/*` into the project's
`.cursor/`, and symlinks `core/` to a stable path the adapters reference. Because
they are symlinks, `git pull` in the clone updates every project at once.

Commands are namespaced on both harnesses (`/tdd-pipeline:task`), which avoids
collisions with any existing setup and lets the package be installed alongside
one.

## Command surface

The inherited pipeline had eleven commands with substantial overlap: a
tracker-aware spec review wrapping a tracker-independent one, a planning command
duplicating the first half of the start command, a deprecated alias, and four
thin wrappers that each launched exactly one agent. The package exposes six.

### Setup — run once per project, safe to re-run

| Command | Purpose |
|---|---|
| `/tdd-pipeline:init` | Bootstrap a project: config, directories, conventions, verification |
| `/tdd-pipeline:conventions` | Derive or refresh the project's stack rules from the codebase |
| `/tdd-pipeline:doctor` | Verify — and optionally repair — every project requirement |

### Work — the daily loop

| Command | Purpose |
|---|---|
| `/tdd-pipeline:task [id \| description]` | The entry point. Item → spec → gate → TDD pipeline → PR |
| `/tdd-pipeline:review [spec-path \| id]` | Critique a spec against the codebase and fix it |
| `/tdd-pipeline:resume <id> [phase]` | Re-enter an interrupted pipeline at a given phase |

### What each replaces

- `/task` absorbs the old `task-start` and `task-isolate-start`. There is no
  separate "plan" command: `/task` **stops at a confirmation gate** once the
  spec is written and reviewed, so planning without implementing is just `/task`
  followed by "stop here". This removes the duplication rather than renaming it.
- `/review` merges the old `task-review` and `review-plan`. The only difference
  between them was whether a tracker item was fetched first, which the tracker
  layer now handles as a detail.
- `/resume` replaces four single-purpose wrappers. Phases remain individually
  addressable — `/tdd-pipeline:resume TASK-1 execute` — but as an argument, not
  as four commands to remember.
- The deprecated `task-run` / `task-isolate-run` aliases are not carried over.

## Configuration contract

`.agent-pipeline/config.yaml`, in the consuming project. It is the only required file.
The directory is named for the pipeline, not for any harness, and holds
everything the pipeline owns in a consuming project:

```
.agent-pipeline/
  config.yaml
  tasks/TASK-1.md
  memory/<phase>/
  worktrees/TASK-1/
  review-checklist.md      # optional
```

The location is identical on every harness, so a project keeps working when the
developer switches tools — and, unlike a harness-named directory, the neutrality
is real rather than asserted. Harness directories still exist alongside it and
hold only adapters: the installer writes agents and commands there, and nothing
else.

```yaml
version: 1
project: my-app

tracker:
  type: none                  # none | linear | github
  prefix: TASK                # ID prefix; becomes the branch name
  # team:   <string>          # linear only
  # states: { start: "In Progress", review: "In Review" }

commands:
  test: "pytest {target}"     # {target} = a specific module or file
  test_all: "pytest"
  lint: "ruff check . --fix && ruff format ."
  # typecheck: "mypy ."       # optional

paths:
  tests: [tests]
  specs: .agent-pipeline/tasks
  worktrees: .agent-pipeline/worktrees
  conventions: CLAUDE.md      # or AGENTS.md — no default; see note below
  # review_checklist: .agent-pipeline/review-checklist.md   # optional

git:
  base_branch: main
  commit_trailer: ""
  # worktree_setup: scripts/setup-worktree.sh       # optional

pr:
  enabled: true
```

**Fail-fast is mandatory.** Every phase reads this file at step 0. If it is
missing, or if a key that phase needs is absent, it stops immediately and names
the missing key. Nothing infers test or lint commands from `package.json`,
`pyproject.toml`, or `Makefile`: the pipeline runs unattended, and guessing
wrong here costs an entire branch of invalid work.

`worktree_setup` covers dependencies excluded from version control (`.venv`,
`node_modules`, `.env`) that do not exist in a freshly created worktree. When
declared, the orchestrator runs the script before any phase; when absent, it
proceeds directly.

`paths.conventions` has no default. A project must set it explicitly, to
whatever document already holds its rules — the file its agent tooling
already reads. This document names `CLAUDE.md` and `AGENTS.md` above only as
concrete examples, because it speaks to a developer configuring a specific
harness. `core/contracts/pipeline-config.md`, the neutral file the pipeline
itself reads at runtime, names neither: it deliberately names no default
conventions file, because doing so would embed a harness assumption into a
layer that must stay harness-neutral. The two documents are for different
audiences, and disagreeing here is by design, not an oversight.

## Tracker layer

`tracker.type` selects which `core/trackers/*.md` file is loaded. The tracker is
involved at exactly two points: resolving or creating the item at the start of
`/task`, and updating status in the end phase. Everything else — branch,
worktree, spec, handoff log, PR — is identical across all three modes.

- **`none`** (default): the ID comes from the command argument. Local spec, no
  external calls. This is the path documented in the README.
- **`linear`**: Linear MCP. Resolves or creates the issue, moves it to
  `states.start` and later `states.review`.
- **`github`**: `gh issue` / `gh pr`. Labels instead of named states.

## The `/task` flow

```
/tdd-pipeline:task "add CPF validation"

  1. resolve or create the tracker item          → TASK-1
  2. write the spec                              → paths.specs/TASK-1.md
  3. review the spec against the codebase        → core/flows/review.md, inline
  4. ── GATE ── present the spec, ask to proceed
  5. git worktree add paths.worktrees/TASK-1 -b TASK-1 <base>
     run git.worktree_setup, if configured
     dispatch the orchestrator with that worktree as its working directory
       test → execute → code-review → end
  6. report: verdict, PR URL, worktree path
```

Steps 1–4 touch no source code: they explore read-only and write one spec file,
committed to the base branch, where specs belong. The local repository never
leaves `git.base_branch`; all code changes happen in the worktree.

### The gate is the plan-only path

Step 4 is a hard stop requiring user confirmation. Answering "stop" leaves a
reviewed spec committed and nothing else — precisely what a separate planning
command used to provide. The gate is also where the inherited design's
review-plan precondition lived; it stays load-bearing, because the agent that
wrote the spec is the wrong one to find its gaps.

## Making the phases generic

Each inherited prompt is split in two: mechanics, which stay and become
parameterized by config; and stack rules, which leave the package and become a
read of `paths.conventions`.

| Phase | Stays | Leaves |
|---|---|---|
| `pipeline` | working-directory guard, sequencing of the four phases, verdict aggregation | absolute repository path, hardcoded setup script, harness isolation primitive |
| `test` | mandatory study of existing test patterns, test plan by dimension, red-phase verification, handoff log, commit | test framework, mocking patterns, paths, endpoint conventions |
| `execute` | handoff log read, test protection contract, critic-style self-review, per-DoD verification loop, mandatory lint gate, commit, ≤300-character report | architecture rule block, lint and test commands, migration procedure |
| `code-review` | spec compliance, test integrity, test quality, security and isolation, manifest verification against the checklist, three-level verdict | layer-specific rules, commands, paths |
| `end` | changed-area detection, lint, persistence of discoveries into the conventions file, commit and push, PR, tracker status, worktree cleanup hint | hardcoded lint tools, package structure, hardcoded worktree path |

The ≤300-character phase reports are what make the pipeline portable across
harnesses and resumable: all real state lives in files — the config, the spec
with its handoff log, and git — never in a conversation. Any phase can run in a
fresh context, on either harness, at any time.

### Portable working-directory guard

The guard preventing the orchestrator from operating on the main repository
compares `git rev-parse --show-toplevel` with the parent directory of
`git rev-parse --git-common-dir`: if they are equal, it is the main repository
rather than a worktree. Pure git, no configuration, no harness dependency.

### Primary risk and mitigation

Replacing inline rules with a pointer to the conventions file reduces
determinism: an inline rule is always read, while a pointer depends on the agent
finding and applying the right section.

Mitigation on two ends: the execute phase cites in the handoff log the exact
convention lines it applied, and the code-review phase checks those citations
against the file. If a phase found no rule covering an area it touched, that
surfaces as an explicit warning in the verdict instead of passing silently.

## Inversion: pipeline mechanics leave the conventions file

In the originating project, the conventions file accumulated pipeline protocol
mixed with project facts: the mandatory task spec structure, subtask structure,
handoff log format, and the rule against improvising workflow steps.

None of that is a project fact — it is pipeline protocol. All of it moves into
`core/contracts/`.

Practical consequence: a new project adopts the pipeline with a
`.agent-pipeline/config.yaml` and **no** mandatory sections in its conventions
file. The conventions file goes
back to holding only what belongs to the project — architecture, patterns,
pitfalls.

## Project requirements and their bootstrap

The pipeline does not work against an empty project. It requires a small set of
artifacts to exist, and — critically — it requires the conventions file to have
**real content**. An empty conventions file silently defeats the central design
choice: the execute and code-review phases stop enforcing inline rules and
instead read the project's rules, so with nothing to read they enforce nothing
while still reporting success.

`core/contracts/project-requirements.md` is the single normative list.
Everything else points at it instead of restating it.

| Requirement | Required | Created by | Validated by |
|---|---|---|---|
| `.agent-pipeline/config.yaml` with every key the configured mode uses | yes | `/init` | every phase, step 0 |
| Git repository with `git.base_branch` present | yes | — | `/doctor`, `/task` |
| `paths.specs` directory | yes | `/init` | `/doctor` |
| `paths.worktrees` directory, git-ignored | yes | `/init` | `/doctor` |
| `paths.conventions` file, non-empty, with derived stack rules | yes | `/conventions` | `/doctor`, execute phase |
| `.agent-pipeline/memory/` directory | no | `/init` | `/doctor` |
| `paths.review_checklist` | no | `/conventions` | `/doctor` |
| `git.worktree_setup` script, if dependencies are git-ignored | conditional | `/init` proposes | `/task` |
| Tracker auth (Linear MCP or `gh auth`) | conditional on `tracker.type` | — | `/doctor`, `/task` |

### `/tdd-pipeline:init`

One-shot bootstrap. Detects the stack (package manager, test runner, linter) and
**proposes** each artifact for confirmation — it never writes without approval.
Auto-detection is acceptable here, and only here, because a human reviews the
result before anything lands.

1. Propose `.agent-pipeline/config.yaml`.
2. Create `paths.specs`, `paths.worktrees`, `.agent-pipeline/memory/`, and add the
   worktree path to `.gitignore` if missing.
3. If dependencies are git-ignored, propose a `worktree_setup` script that
   symlinks or reinstalls them.
4. Hand off to `/conventions` to populate the conventions file and checklist.
5. Finish by running `/doctor` and printing its report.

### `/tdd-pipeline:conventions`

Derives the project's stack rules from the codebase and writes them into
`paths.conventions`. Re-runnable — `/init` is one-shot, but projects drift, and
a stale conventions file degrades every downstream review.

1. Dispatch exploration subagents in parallel to derive what is actually
   practiced: layering and module boundaries, error-handling convention, naming,
   auth and authorization pattern, data access pattern, test structure and
   mocking approach, formatting and lint rules.
2. Distinguish **rule** from **occurrence**: a pattern is proposed as a rule
   only when it holds across multiple independent call sites. A single example
   is reported as an observation, not a rule.
3. Present the derived rules for confirmation, grouped by area, each with the
   `file:line` evidence it came from. The user accepts, edits, or drops each
   group.
4. Write accepted rules into `paths.conventions` under managed section markers,
   so a later re-run updates that section without touching hand-written prose
   around it.
5. Derive `paths.review_checklist` from the accepted rules, seeded by
   `core/contracts/review-checklist-base.md` — the stack-agnostic items: auth on
   new endpoints, input validation, error paths tested, no secrets in code,
   migration reversibility.

On re-run against a populated file, it reports drift — rules in the file no
longer practiced in code, and practices in code with no rule — rather than
overwriting blindly.

### `/tdd-pipeline:doctor`

Re-runnable validation of the requirements table. Reports each item as pass,
fail, or not-applicable, and with `--fix` offers to create what is missing,
delegating to `/init` or `/conventions` as appropriate.

Two jobs beyond first-time setup: diagnosing a project where the pipeline
started failing, and serving as the upgrade path when a new version adds a
requirement. It is cheap and safe to run repeatedly.

A conventions file that exists but is effectively empty is a **fail**, not a
pass — that is the specific failure mode this section exists to prevent.

## Agent memory

Phases record durable workflow learnings in `.agent-pipeline/memory/<phase>/`,
plain Markdown files read at phase start. This is deliberately file-based rather
than using a harness memory feature, for the same reason as everything else: it
survives a harness switch. Claude Code adapters may additionally set
`memory: project` in frontmatter, which is a convenience, not a dependency.

## Validation

A throwaway repository, plain Python, `tracker: none`, one small real task end
to end — **run twice, once per harness**:

```
/tdd-pipeline:init
/tdd-pipeline:task "add CPF validation"
```

Acceptance criteria:

1. `/init` produces a working config and a conventions file with rules actually
   derived from the code, not a placeholder.
2. `/doctor` passes on the bootstrapped project, and fails on a project whose
   conventions file has been emptied.
3. `/task` reaches `SHIPPED` with an open PR, without manual intervention beyond
   the spec gate.
4. Every phase left its entry in the handoff log.
5. The code-review phase actually blocks when a test is weakened — verified by
   deliberately injecting a weakened assertion.
6. `/resume TASK-1 execute` re-enters a pipeline interrupted after the red phase.
7. **Cross-harness resume**: a pipeline started on one harness is resumed on the
   other and completes. This is the real test that state lives in files.
8. `grep -riE` over the repository returns no real project name, absolute path,
   person's name, or organization identifier; and `grep` over `core/` returns no
   harness name or harness-specific tool name.

No existing project is touched during validation.

## Out of scope

- `/adr`, `/fix-bug`, `/review-pr` — independent of the pipeline; they become a
  second package in the same repo later.
- Harnesses beyond Claude Code and Cursor. The core/adapter split is what makes
  adding one later cheap; doing it now is speculative.
- Prebuilt per-stack convention packs.
- Migrating any existing project to consume the package.
