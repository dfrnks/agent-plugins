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
| Stack rules | Never in the plugin; always in the project's conventions file |
| v1 scope | Full pipeline + `/init`. Out: `/adr`, `/fix-bug`, `/review-pr` |
| Originating project | Left untouched; no migration in v1 |
| Commit trailer | Empty by default |

### Cross-cutting constraints

**Language.** Every document, prompt, README, comment, and error message in this
repository is written in English.

**No leakage.** No file in the plugin — prompt, README, example, frontmatter, or
error message — may contain a real project name, absolute path, person's name,
or organization identifier. Examples use `my-app` and `TASK-1` style IDs. A
final `grep` gate validates this before any push.

## Architecture

### Repository layout

```
dfrnks/claude-plugins/
├── .claude-plugin/marketplace.json
├── docs/specs/
└── plugins/tdd-pipeline/
    ├── .claude-plugin/plugin.json
    ├── agents/
    │   ├── task-isolate-start.md    orchestrator (runs inside the worktree)
    │   ├── task-test.md             red phase
    │   ├── task-execute.md          green phase
    │   ├── task-code-review.md      adjudicates implementation against spec
    │   └── task-end.md              lint, commit, push, PR, tracker status
    ├── commands/
    │   ├── init.md                  bootstrap a consuming project
    │   ├── task-start.md            resolve/create item, create worktree, delegate planning
    │   ├── plan.md                  exploration + collaborative spec design
    │   ├── task-review.md           spec review before implementation
    │   ├── review-plan.md           plan critique, tracker-independent
    │   ├── task-isolate-start.md    dispatches the orchestrator with isolation: worktree
    │   └── task-{test,execute,code-review,end}.md   thin wrappers
    ├── references/
    │   ├── pipeline-config.md       pipeline.yaml schema and semantics
    │   ├── spec-template.md         task spec structure + Definition of Done
    │   ├── handoff-log.md           Agent Handoff Log protocol and escalation rules
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

Commands and agents are namespaced (`/tdd-pipeline:task-start`,
`subagent_type: "tdd-pipeline:task-test"`). This avoids collisions with any
`.claude/` directory the project already has, so the plugin can be installed
side by side with an existing setup.

Files under `references/` are loaded by path via `${CLAUDE_PLUGIN_ROOT}`. Each
contract — config schema, spec template, handoff protocol — exists in exactly
one place instead of being duplicated across the five prompts.

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
tracker is involved at exactly two points in the pipeline: resolving or creating
the item in `/task-start`, and updating status in `task-end`. Everything else —
branch, worktree, spec, handoff log, PR — is identical across all three modes.

- **`none`** (default): the ID comes from the command argument. Local spec, no
  external calls. This is the path documented in the README.
- **`linear`**: Linear MCP. Resolves or creates the issue, moves it to
  `states.start` and later `states.review`.
- **`github`**: `gh issue` / `gh pr`. Labels instead of named states.

## Making the agents generic

Each inherited prompt is split in two: mechanics, which stay and become
parameterized by config; and stack rules, which leave the plugin and become a
read of `paths.conventions`.

| Agent | Stays | Leaves |
|---|---|---|
| `task-isolate-start` | isolation guard, branch rename to the task ID, sync with base branch, review-plan gate, orchestration of the four phases | absolute repository path, hardcoded setup script |
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

## `/tdd-pipeline:init`

Bootstraps a consuming project:

1. Detects the stack (package manager, test runner, linter) and **proposes** a
   `pipeline.yaml` for confirmation — never writes without approval.
2. Creates `paths.specs` and `.claude/agent-memory/`.
3. Checks that `paths.conventions` exists; if not, offers a minimal skeleton.
4. Seeds a generic `review-checklist.md`, if the user wants one.

Auto-detection is acceptable here, and only here, because a human confirms the
result before anything is written.

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
/tdd-pipeline:task-start "add CPF validation"
/tdd-pipeline:task-review TASK-1
/tdd-pipeline:task-isolate-start TASK-1
```

Acceptance criteria:

1. The pipeline reaches `SHIPPED` with an open PR, without manual intervention.
2. Every phase left its entry in the Agent Handoff Log.
3. `task-code-review` actually blocks when a test is weakened — verified by
   deliberately injecting a weakened assertion.
4. `grep -riE` over the plugin repository returns no real project name, absolute
   path, person's name, or organization identifier.

No existing project is touched during validation.

## Out of scope

- `/adr`, `/fix-bug`, `/review-pr` — independent of the pipeline; they become a
  second plugin in the same marketplace later.
- Prebuilt per-stack convention packs.
- Migrating any existing project to consume the plugin.
