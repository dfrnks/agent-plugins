# Pipeline configuration contract

`pipeline.yaml`, kept in the pipeline's own directory inside the consuming
project, is the only file the pipeline requires to exist before it runs. That
directory is not owned by any single harness — the same relative location is
used no matter which harness drives the pipeline, precisely so a project keeps
working when the developer switches tools. Every phase and flow cites this
contract instead of restating configuration keys.

## Schema

Two placeholders appear below in place of literal path segments, because the
segments they stand for are themselves harness-independent conventions rather
than fixed strings this contract can spell out once and for all:

- `<pipeline-dir>` — the pipeline's own directory described above: the single
  location, stable across every harness, that holds the configuration file
  itself, the task specs, and the worktrees.
- `<conventions-file>` — the project's own conventions document. Its name is a
  project choice, not something this contract mandates; a project picks
  whichever file it already uses to record architecture, patterns, and
  pitfalls.

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
  specs: <pipeline-dir>/tasks
  worktrees: <pipeline-dir>/worktrees
  conventions: <conventions-file>
  # review_checklist: <pipeline-dir>/review-checklist.md   # optional

git:
  base_branch: main
  commit_trailer: ""
  # worktree_setup: scripts/setup-worktree.sh       # optional

pr:
  enabled: true
```

`worktree_setup` covers dependencies excluded from version control (virtual
environments, installed packages, local `.env` files) that do not exist in a
freshly created worktree. When declared, the orchestrator runs the script
before any phase; when absent, it proceeds directly.

## Required keys by mode

| Key | Always mandatory | Mandatory when `tracker.type: linear` | Mandatory when `tracker.type: github` | Optional in every mode |
|---|---|---|---|---|
| `version` | yes | | | |
| `project` | yes | | | |
| `tracker.type` | yes | | | |
| `tracker.prefix` | yes | | | |
| `tracker.team` | | yes | | |
| `tracker.states` | | yes | | |
| `commands.test` | yes | | | |
| `commands.test_all` | yes | | | |
| `commands.lint` | yes | | | |
| `commands.typecheck` | | | | yes |
| `paths.tests` | yes | | | |
| `paths.specs` | yes | | | |
| `paths.worktrees` | yes | | | |
| `paths.conventions` | yes | | | |
| `paths.review_checklist` | | | | yes |
| `git.base_branch` | yes | | | |
| `git.commit_trailer` | yes | | | |
| `git.worktree_setup` | | | | yes |
| `pr.enabled` | yes | | | |

`tracker.type: github` needs nothing beyond the always-mandatory keys: it
authenticates and labels through the prefix already required for every mode,
using labels in place of the named states a `linear` tracker needs.

## Fail-fast protocol

Every phase reads the configuration file at step 0, before doing anything
else. Three rules govern that read, without exception:

1. If the configuration file is absent, stop immediately and instruct the
   user to run the init flow instead of proceeding with defaults.
2. If a key the current phase needs is absent, stop immediately and name that
   exact key — never substitute a guess or a hardcoded fallback.
3. Never infer a command, a path, or any other key from a package manifest,
   a build file, or a directory listing. The pipeline runs unattended, and a
   wrong guess here costs an entire branch of invalid work rather than one
   failed command.

When a required key is missing, the stop message follows this exact template,
naming the file by its role and the specific missing key:

```
Cannot start: `pipeline.yaml` is missing key `commands.test`.
Add it, or run the init flow to regenerate the configuration.
```

The configuration file's location stays the same regardless of which harness
is driving the pipeline, because it lives in the pipeline's own directory —
never a directory owned by a particular harness.
