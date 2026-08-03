# Design — `tdd-pipeline`: a portable agent-driven development pipeline

**Date:** 2026-08-03
**Status:** approved, ready for implementation planning

## Problem

A mature agent-driven development pipeline already exists and works end to end:
from task creation to an open pull request, with mandatory TDD, spec review
before implementation, and code review after it. It lives inside a single
project and is wired to that project: stack, test and lint commands, absolute
paths, issue tracker, ID prefix.

The goal is to extract the pipeline's mechanics into a reusable plugin,
installable in any project, leaving no trace of the originating project.

## Decisions

| Decision | Choice |
|---|---|
| Distribution | Claude Code plugin, in the `dfrnks/claude-plugins` marketplace repo |
| Project configuration | `.claude/pipeline.yaml` (deterministic) + the project's conventions file (prose) |
| Issue tracker | Pluggable: `none` (default) \| `linear` \| `github` |
| Stack rules | Never in the plugin; always in the project's conventions file, derived by `/conventions` |
| Command surface | Six commands, two families: setup and work |
| Entry point | A single `/task`, end to end, with a confirmation gate after the spec |
| Originating project | Left untouched; no migration in v1 |
| Commit trailer | Empty by default |

### Cross-cutting constraints

**Language.** Every document, prompt, README, comment, and error message in this
repository is written in English.

**No leakage.** No file in the plugin — prompt, README, example, frontmatter, or
error message — may contain a real project name, absolute path, person's name,
or organization identifier. Examples use `my-app` and `TASK-1` style IDs. A
final `grep` gate validates this before any push.

## Command surface

The inherited pipeline had eleven commands with substantial overlap: a
tracker-aware spec review wrapping a tracker-independent one, a planning command
duplicating the first half of the start command, a deprecated alias, and four
thin wrappers that each launched exactly one agent. The generic plugin exposes
six.

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
- `/resume` replaces four single-purpose wrappers (`task-test`, `task-execute`,
  `task-code-review`, `task-end`). Phases remain individually addressable —
  `/tdd-pipeline:resume TASK-1 execute` — but as an argument, not as four
  commands to remember.
- The deprecated `task-run` / `task-isolate-run` aliases are not carried over.

## Architecture

### Repository layout

```
dfrnks/claude-plugins/
├── .claude-plugin/marketplace.json
├── docs/specs/
└── plugins/tdd-pipeline/
    ├── .claude-plugin/plugin.json
    ├── agents/
    │   ├── task-pipeline.md         orchestrator (runs inside the worktree)
    │   ├── task-test.md             red phase
    │   ├── task-execute.md          green phase
    │   ├── task-code-review.md      adjudicates implementation against spec
    │   └── task-end.md              lint, commit, push, PR, tracker status
    ├── commands/
    │   ├── init.md
    │   ├── conventions.md
    │   ├── doctor.md
    │   ├── task.md
    │   ├── review.md
    │   └── resume.md
    ├── references/
    │   ├── project-requirements.md  normative list of what a project must provide
    │   ├── pipeline-config.md       pipeline.yaml schema and semantics
    │   ├── spec-template.md         task spec structure + Definition of Done
    │   ├── handoff-log.md           Agent Handoff Log protocol and escalation rules
    │   ├── conventions-template.md  section skeleton for the conventions file
    │   ├── review-checklist-base.md stack-agnostic review checklist seed
    │   ├── tracker-none.md
    │   ├── tracker-linear.md
    │   └── tracker-github.md
    └── README.md
```

Installation in a consuming project:

```
/plugin marketplace add dfrnks/claude-plugins
/plugin install tdd-pipeline
```

Commands and agents are namespaced (`/tdd-pipeline:task`,
`subagent_type: "tdd-pipeline:task-test"`). This avoids collisions with any
`.claude/` directory the project already has, so the plugin can be installed
side by side with an existing setup.

Files under `references/` are loaded by path via `${CLAUDE_PLUGIN_ROOT}`. Each
contract — config schema, spec template, handoff protocol — exists in exactly
one place instead of being duplicated across the five agent prompts.

### Configuration contract

`.claude/pipeline.yaml`, in the consuming project. It is the only required file.

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
  specs: .claude/tasks
  worktrees: .claude/worktrees
  conventions: CLAUDE.md
  # review_checklist: .claude/review-checklist.md   # optional

git:
  base_branch: main
  commit_trailer: ""
  # worktree_setup: scripts/setup-worktree.sh       # optional

pr:
  enabled: true
```

**Fail-fast is mandatory.** Every agent reads this file at step 0. If it is
missing, or if a key the agent needs is absent, the agent stops immediately and
names the missing key. No agent infers test or lint commands from
`package.json`, `pyproject.toml`, or `Makefile`: the pipeline runs unattended,
and guessing wrong here costs an entire branch of invalid work.

`worktree_setup` covers dependencies excluded from version control (`.venv`,
`node_modules`, `.env`) that do not exist in a freshly created worktree. When
declared, the orchestrator runs the script before any phase; when absent, it
proceeds directly.

### Tracker layer

`tracker.type` selects which `references/tracker-*.md` the agent loads. The
tracker is involved at exactly two points: resolving or creating the item at the
start of `/task`, and updating status in `task-end`. Everything else — branch,
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
  3. review the spec against the codebase        → /review, inline
  4. ── GATE ── present the spec, ask to proceed
  5. dispatch the orchestrator in a worktree     → branch TASK-1
       task-test → task-execute → task-code-review → task-end
  6. report: verdict, PR URL, worktree path
```

### One worktree, not two

The inherited design created a named worktree for planning, then asked the
harness for a second worktree when the pipeline started — which is why it needed
a pre-dispatch rule requiring the spec to be committed to the base branch first,
so the second worktree could see it.

Merging the commands removes the problem instead of documenting it. Steps 1–4
touch no source code: they explore read-only and write one spec file, which is
committed to the base branch, where specs belong. Step 5 requests exactly one
worktree from the harness, renames its branch to the task ID, and all code
changes happen there. The local repository never leaves `git.base_branch`.

### The gate is the plan-only path

Step 4 is a hard stop that requires user confirmation. Answering "stop" leaves a
reviewed spec committed and nothing else — which is precisely what a separate
planning command used to provide. The gate is also where the inherited design's
`review-plan` precondition lived; it stays load-bearing, because the agent that
wrote the spec is the wrong one to find its gaps.

## Making the agents generic

Each inherited prompt is split in two: mechanics, which stay and become
parameterized by config; and stack rules, which leave the plugin and become a
read of `paths.conventions`.

| Agent | Stays | Leaves |
|---|---|---|
| `task-pipeline` | isolation guard, branch rename to the task ID, sync with base branch, orchestration of the four phases | absolute repository path, hardcoded setup script |
| `task-test` | mandatory study of existing test patterns, test plan by dimension, red-phase verification, handoff log, commit | test framework, mocking patterns, paths, endpoint conventions |
| `task-execute` | handoff log read, test protection contract, critic-style self-review, per-DoD verification loop, mandatory lint gate, commit, ≤300-character report | architecture rule block, lint and test commands, migration procedure |
| `task-code-review` | spec compliance, test integrity, test quality, security and isolation, manifest verification against the checklist, three-level verdict | layer-specific rules, commands, paths |
| `task-end` | changed-area detection, lint, persistence of discoveries into the conventions file, commit and push, PR, tracker status, worktree cleanup hint | hardcoded lint tools, package structure, hardcoded worktree path |

### Portable isolation guard

The guard preventing the orchestrator from running in the main repository
currently compares against an absolute path. The portable version compares
`git rev-parse --show-toplevel` with the parent directory of
`git rev-parse --git-common-dir`: if they are equal, the process is in the main
repository rather than a worktree. This works in any repository, with no
configuration.

### Primary risk and mitigation

Replacing inline rules with a pointer to the conventions file reduces
determinism: an inline rule is always read, while a pointer depends on the agent
finding and applying the right section.

Mitigation on two ends: `task-execute` cites in the handoff log the exact
convention lines it applied, and `task-code-review` checks those citations
against the file. If an agent found no rule covering an area it touched, that
surfaces as an explicit warning in the verdict instead of passing silently.

## Inversion: pipeline mechanics leave the conventions file

In the originating project, the conventions file accumulated pipeline protocol
mixed with project facts: the mandatory task spec structure, subtask structure,
Agent Handoff Log format, and the rule against improvising workflow steps.

None of that is a project fact — it is pipeline protocol. All of it moves into
`references/spec-template.md` and `references/handoff-log.md` inside the plugin.

Practical consequence: a new project adopts the pipeline with a
`pipeline.yaml` and **no** mandatory sections in its conventions file. The
conventions file goes back to holding only what belongs to the project —
architecture, patterns, pitfalls.

## Project requirements and their bootstrap

The plugin does not work against an empty project. It requires a small set of
artifacts to exist, and — critically — it requires the conventions file to have
**real content**. An empty conventions file silently defeats the central design
choice of this plugin: `task-execute` and `task-code-review` stop enforcing
inline rules and instead read the project's rules, so with nothing to read they
enforce nothing while still reporting success.

`references/project-requirements.md` is the single normative list. Everything
else in the plugin points at it instead of restating it.

| Requirement | Required | Created by | Validated by |
|---|---|---|---|
| `.claude/pipeline.yaml` with every key the configured mode uses | yes | `/init` | every agent, step 0 |
| Git repository with `git.base_branch` present | yes | — | `/doctor`, `/task` |
| `paths.specs` directory | yes | `/init` | `/doctor` |
| `paths.worktrees` directory, git-ignored | yes | `/init` | `/doctor` |
| `paths.conventions` file, non-empty, with derived stack rules | yes | `/conventions` | `/doctor`, `task-execute` |
| `.claude/agent-memory/` directory | no | `/init` | `/doctor` |
| `paths.review_checklist` | no | `/conventions` | `/doctor` |
| `git.worktree_setup` script, if dependencies are git-ignored | conditional | `/init` proposes | `task-pipeline` |
| Tracker auth (Linear MCP or `gh auth`) | conditional on `tracker.type` | — | `/doctor`, `/task` |

### `/tdd-pipeline:init`

One-shot bootstrap. Detects the stack (package manager, test runner, linter) and
**proposes** each artifact for confirmation — it never writes without approval.
Auto-detection is acceptable here, and only here, because a human reviews the
result before anything lands.

1. Propose `.claude/pipeline.yaml`.
2. Create `paths.specs`, `paths.worktrees`, `.claude/agent-memory/`, and add the
   worktree path to `.gitignore` if missing.
3. If dependencies are git-ignored, propose a `worktree_setup` script that
   symlinks or reinstalls them.
4. Hand off to `/conventions` to populate the conventions file and checklist.
5. Finish by running `/doctor` and printing its report.

### `/tdd-pipeline:conventions`

Derives the project's stack rules from the codebase and writes them into
`paths.conventions`. Re-runnable — `/init` is one-shot, but projects drift, and
a stale conventions file degrades every downstream review.

1. Dispatch Explore agents in parallel over the codebase to derive what is
   actually practiced: layering and module boundaries, error-handling
   convention, naming, auth and authorization pattern, data access pattern,
   test structure and mocking approach, formatting and lint rules.
2. Distinguish **rule** from **occurrence**: a pattern is only proposed as a
   rule when it holds across multiple independent call sites. A single example
   is reported as an observation, not a rule.
3. Present the derived rules for confirmation, grouped by area, each with the
   `file:line` evidence it was derived from. The user accepts, edits, or drops
   each group.
4. Write accepted rules into `paths.conventions` under managed section markers,
   so a later re-run updates that section without touching hand-written prose
   around it.
5. Derive `paths.review_checklist` from the accepted rules, seeded by
   `references/review-checklist-base.md` (the stack-agnostic items: auth on new
   endpoints, input validation, error paths tested, no secrets in code,
   migration reversibility).

On re-run against a populated file, it reports drift — rules in the file no
longer practiced in code, and practices in code with no rule — rather than
overwriting blindly.

### `/tdd-pipeline:doctor`

Re-runnable validation of the requirements table above. Reports each item as
pass, fail, or not-applicable, and with `--fix` offers to create what is
missing, delegating to `/init` or `/conventions` as appropriate.

Two jobs beyond first-time setup: diagnosing a project where the pipeline
started failing, and serving as the upgrade path when a new plugin version adds
a requirement. It is cheap to run and safe to run repeatedly.

A conventions file that exists but is effectively empty is a **fail**, not a
pass — that is the specific failure mode this whole section exists to prevent.

## Agent memory

Agents keep `memory: project` and write to `.claude/agent-memory/<agent>/`. That
mechanism is already generic and stays. The long block of memory instructions
pasted inline into one of the inherited prompts is removed: the harness already
injects that content, and the manual copy only duplicates and rots.

## Validation

A throwaway repository, plain Python, `tracker: none`, one small real task end
to end:

```
/tdd-pipeline:init
/tdd-pipeline:task "add CPF validation"
```

Acceptance criteria:

1. `/init` produces a working config and a conventions file with rules actually
   derived from the code, not a placeholder.
2. `/doctor` passes on the bootstrapped project, and fails on a project where
   the conventions file has been emptied.
3. `/task` reaches `SHIPPED` with an open PR, without manual intervention beyond
   the spec gate.
4. Every phase left its entry in the Agent Handoff Log.
5. `task-code-review` actually blocks when a test is weakened — verified by
   deliberately injecting a weakened assertion.
6. `/resume TASK-1 execute` re-enters a pipeline interrupted after the red phase.
7. `grep -riE` over the plugin repository returns no real project name, absolute
   path, person's name, or organization identifier.

No existing project is touched during validation.

## Out of scope

- `/adr`, `/fix-bug`, `/review-pr` — independent of the pipeline; they become a
  second plugin in the same marketplace later.
- Prebuilt per-stack convention packs.
- Migrating any existing project to consume the plugin.
