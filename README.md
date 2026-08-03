# agent-pipeline

A harness-neutral, test-driven development pipeline for coding agents: it turns
a one-line request into a reviewed spec, a failing test suite, an
implementation that satisfies it, an adjudicated code review, and a shipped
branch. The pipeline's behaviour lives entirely in `core/` as plain Markdown —
thin per-harness adapters point at it, so the same pipeline runs unchanged on
Claude Code and on Cursor, and a project keeps working when the developer
switches tools.

## Commands

| Command | What it does |
|---|---|
| `init` | Bootstraps a project: detects the stack, proposes `.agent-pipeline/config.yaml` for confirmation, creates the directories, and hands off to `conventions`. Run once per project. |
| `conventions` | Explores the codebase and derives its actual rules — one line per rule, each ending in a `file:line` citation — into the project's conventions file. This is what the execute and code-review phases enforce. |
| `doctor` | Checks the project against every requirement the pipeline needs, one row per requirement, and reports `pass` / `fail` / `n/a`. Takes an optional `repair` argument. |
| `task` | The single entry point for work. Resolves the item, writes a spec, reviews it, stops at a confirmation gate, then creates a worktree and runs the four phases against it. |
| `review` | Critiques an existing spec against the real codebase and fixes it in place. Runs standalone, or inline as `task`'s own step 3. |
| `resume` | Re-enters an interrupted pipeline at exactly one phase, runs that phase alone, and stops. A recovery tool, not a retry loop. |

Behind `task` sit four phases — **test** (write the failing suite), **execute**
(make it pass without weakening it), **code-review** (adjudicate), and **end**
(lint, persist what was learned, push, open the pull request).

## Installation

### Cursor

`install.sh` links this repository's `core/` and the Cursor adapter into a
project's `.cursor/` directory:

```bash
git clone https://github.com/dfrnks/agent-pipeline.git ~/src/agent-pipeline
cd ~/src/agent-pipeline
./install.sh --harness cursor --project /path/to/your/project
```

It is idempotent, and it refuses to replace anything under the destination it
did not itself create — a real file, or a symlink pointing somewhere else. A
conflict on any destination aborts before any destination is changed.

### Claude Code

The Claude Code adapter ships as a plugin, not as project-local symlinks, so
`install.sh` deliberately refuses `--harness claude-code`. Install it through
Claude Code's own plugin flow instead:

```bash
claude plugin marketplace add dfrnks/agent-pipeline
claude plugin install tdd-pipeline@agent-pipeline
```

The adapter reaches `core/` through `${CLAUDE_PLUGIN_ROOT}`, a variable Claude
Code sets only when it loads the adapter through its plugin system. Symlinking
the adapter into a project's `.claude/` directory would produce files that look
installed but whose every `core/` pointer dangles, which is why the installer
refuses rather than producing that layout.

> **Known limitation.** On the Claude Code version this was validated against,
> the plugin's six commands load correctly but its five agents do not — see
> [`docs/validation-2026-08-03.md`](docs/validation-2026-08-03.md), "Defects
> exposed", for the evidence and the remedy. The Cursor adapter is unaffected.

## Configuration

`init` writes `.agent-pipeline/config.yaml` for you, after showing you the draft
and waiting for your confirmation. The directory is named for the pipeline
rather than for any harness, so it is identical on every harness.

Here is a complete, runnable configuration for a plain Python project using
`pytest` and `ruff` inside a virtual environment, with no issue tracker and
pull requests enabled — the shape most projects start from:

```yaml
version: 1
project: ledger

tracker:
  type: none                  # none | linear | github
  prefix: TASK                # task IDs become TASK-1, TASK-2, … and the branch name

commands:
  test: ".venv/bin/python -m pytest -q {target}"   # {target} = the module or file under test
  test_all: ".venv/bin/python -m pytest -q"
  lint: ".venv/bin/python -m ruff check ."
  # typecheck: ".venv/bin/python -m mypy src"      # optional

paths:
  tests: [tests]
  specs: .agent-pipeline/tasks
  worktrees: .agent-pipeline/worktrees
  conventions: CONVENTIONS.md
  review_checklist: .agent-pipeline/review-checklist.md   # optional

git:
  base_branch: main
  commit_trailer: ""
  worktree_setup: scripts/setup-worktree.sh               # optional

pr:
  enabled: true
```

Two keys deserve a note:

- **`paths.conventions` has no default.** Point it at whatever document already
  holds your project's rules. The execute and code-review phases carry no
  project-specific rules of their own and read this file at the start of every
  run, so a file that exists but holds nothing means those phases enforce
  nothing while still reporting success. `doctor` treats fewer than five rules
  in the file's managed section as a hard `fail` for exactly that reason.
- **`git.worktree_setup`** covers whatever your project excludes from version
  control — a virtual environment, installed packages, a local `.env`. A fresh
  worktree starts without them. For the configuration above, the script is:

  ```bash
  #!/usr/bin/env bash
  set -euo pipefail
  cd "$(dirname "$0")/.."
  [ -d .venv ] || uv venv .venv
  uv pip install --quiet --python .venv/bin/python pytest ruff
  ```

## Your first task in five minutes

1. **Install** the adapter for your harness, as above.

2. **Bootstrap the project.** Run `init`. It inspects the repository, proposes a
   complete configuration, and asks you to confirm every value it could not
   detect — the tracker, the conventions path, whether to open pull requests.
   Nothing reaches disk before you confirm.

3. **Let it derive your conventions.** `init` hands off to `conventions`, which
   explores the codebase in parallel and proposes rules — but only patterns
   holding at two or more independent sites, each with the `file:line` it came
   from. You accept, edit, or drop each group. This is the step worth your
   attention: everything the pipeline later enforces comes from here.

4. **Check the project is ready.** Run `doctor`. Every row should read `pass` or
   `n/a`. If the conventions row fails, run `conventions` again — that row is
   the one guarding against a pipeline that runs green while enforcing nothing.

5. **Run a task.** Give it a description:

   ```
   task "validate input types on add"
   ```

   It resolves a task ID, explores the affected code, asks you a single grouped
   question about scope and constraints, drafts a spec, reviews that spec
   against the real codebase and fixes what it finds, then **stops and shows you
   the result**. That stop is a hard gate: answer anything other than "proceed"
   and you are left with a reviewed, committed spec and nothing else — which is
   also how you use this package for planning alone.

6. **Answer the gate.** On "proceed", it creates a worktree on a branch named
   for the task, runs your `git.worktree_setup` script inside it, and dispatches
   the four phases in order. Each phase writes what it learned into the spec's
   handoff log, which is the only thing the next phase reads.

If a phase is interrupted, `resume TASK-1` picks up at the right phase — it
reads the handoff log to work out which one, runs exactly that phase, and
stops. State lives in files, not in a session.

## Updating

Both harnesses read the package from your clone, so updating is a `git pull` in
that clone:

```bash
cd ~/src/agent-pipeline
git pull
```

For Cursor, that is the whole update: `install.sh` created symlinks into
`.cursor/`, so every project you installed into now points at the new content
with no reinstallation. Re-running `install.sh` is safe and idempotent if a
release adds a new command or agent file, which needs a new link.

For Claude Code, the plugin is copied into its own cache at install time rather
than symlinked, so a `git pull` alone does not reach it — reinstall the plugin
to pick up changes.

## Repository layout

```
core/          the pipeline itself — harness-neutral, the only normative content
  contracts/   config schema, spec template, handoff log, conventions template,
               project requirements, review checklist seed
  flows/       init, conventions, doctor, task, review, resume
  phases/      pipeline, test, execute, code-review, end
  trackers/    none, github, linear
adapters/      thin per-harness pointers into core/ — claude-code/, cursor/
checks/        the five gates that keep core/ neutral and the tree leak-free
tests/         the test suite covering the checkers
install.sh     links core/ and one harness's adapter into a project
```

`core/` never names a tool, a language, or a harness. That neutrality is
enforced mechanically by `checks/core-is-neutral.sh`, not by convention.

## Validation

[`docs/validation-2026-08-03.md`](docs/validation-2026-08-03.md) records the
first end-to-end run of this pipeline against a real project, criterion by
criterion, including what was verified by execution, what was not, and the
defects the run exposed. It is written to be honest rather than green.
