# agent-plugins

A plugin marketplace holding one plugin today, **`tdd-pipeline`**.

It is a harness-neutral, test-driven development pipeline for coding agents: it
turns a one-line request into a reviewed spec, a failing test suite, an
implementation that satisfies it, an adjudicated code review, and a shipped
branch. The pipeline's behaviour lives entirely in `core/` as plain Markdown —
thin per-harness adapters point at it, so the same pipeline runs unchanged on
Claude Code and on Cursor, and a project keeps working when the developer
switches tools.

## Commands

The eight commands are the same on both harnesses, but **you type them
differently**, because the two install by different mechanisms:

| What it does | Claude Code | Cursor |
|---|---|---|
| Bootstraps a project: detects the stack, proposes `.tdd-pipeline/config.yaml` for confirmation, creates the directories, commits them, and hands off to conventions. Run once per project. | `/tdd-pipeline:init` | `/init` |
| Explores the codebase and derives its actual rules — one per list item, each carrying a `file:line` citation — into the project's conventions file, and commits it. This is what the execute and code-review phases enforce. | `/tdd-pipeline:conventions` | `/conventions` |
| Checks the project against every requirement the pipeline needs, one row per requirement, and reports `pass` / `fail` / `n/a`. Takes an optional `repair` argument. | `/tdd-pipeline:doctor` | `/doctor` |
| The single entry point for work. Resolves the item, writes a spec, reviews it, stops at a confirmation gate, then creates a worktree and runs the four phases against it. | `/tdd-pipeline:task` | `/task` |
| Designs a change and **stops** — explores, settles the open questions with you, writes a spec, runs nothing. For work whose shape has to be decided before it is scheduled. | `/tdd-pipeline:plan` | `/plan` |
| Fixes a defect test-first: reproduces it with a failing test, names the root cause, makes the minimal change, verifies. Stops before pushing, because nothing reviewed it. | `/tdd-pipeline:fix-bug` | `/fix-bug` |
| Critiques an existing spec against the real codebase and fixes it in place. Runs standalone, or inline as `task`'s own step 3. | `/tdd-pipeline:review` | `/review` |
| Re-enters an interrupted pipeline at exactly one phase, runs that phase alone, and stops. A recovery tool, not a retry loop. | `/tdd-pipeline:resume` | `/resume` |

On Claude Code the commands are namespaced under the plugin name, which is
what keeps `/tdd-pipeline:init` and `/tdd-pipeline:review` distinct from the
built-in `/init` and `/review`.

On Cursor, `install.sh` links the command files into `.cursor/commands/`,
where they take their bare filenames — so **`/init`, `/review`, `/doctor`
and `/plan` are the pipeline's, and they will shadow or be shadowed by
anything else claiming those names** in that project. If you already use
commands by those
names, rename the links after installing; nothing in the pipeline depends on
what its command files are called, only on what they point at.

Throughout the rest of this README the commands are written bare — `init`,
`task`, `doctor` — meaning "whichever of the two forms above your harness
uses."

Behind `task` sit four phases — **test** (write the failing suite), **execute**
(make it pass without weakening it), **code-review** (adjudicate), and **end**
(lint, persist what was learned, push, open the pull request).

## Installation

### Cursor

`install.sh` links this repository's `core/` and the Cursor adapter into a
project's `.cursor/` directory:

```bash
git clone https://github.com/dfrnks/agent-plugins.git ~/src/agent-plugins
cd ~/src/agent-plugins
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
claude plugin marketplace add dfrnks/agent-plugins
claude plugin install tdd-pipeline@dfrnks
```

The plugin is `tdd-pipeline`; the marketplace it comes from is `dfrnks`.
The two lines name different things on purpose, and the mismatch is not a
typo: `marketplace add` takes a **GitHub path**, because that is where the
marketplace is fetched from, while `install` takes the **marketplace's own
name**, declared in `.claude-plugin/marketplace.json`, which is what it is
called once added. A marketplace name is independent of the repository that
carries it.

The `@` form names both plugin and marketplace, so the install works the same
way whether or not another marketplace also offers a plugin by that name —
which is why the name is `dfrnks` rather than something descriptive. Its
job is to be unique among the marketplaces a user has added and to say whose
plugin this is; a generic name would collide with the very other marketplaces
the `@` form exists to disambiguate against.

If you added this marketplace under an earlier name — it was `agent-plugins`,
then `deepcloud` — it is still registered under that name. The name is the key
Claude Code stores it under, so a rename in this repository does not reach an
installation that already exists. Remove and re-add it, substituting whichever
old name you have for `deepcloud` below:

```bash
claude plugin uninstall tdd-pipeline
claude plugin marketplace remove deepcloud
claude plugin marketplace add dfrnks/agent-plugins
claude plugin install tdd-pipeline@dfrnks
```

Then restart Claude Code. Removing the marketplace before re-adding it is the
part that matters: adding the same repository again while the old entry is
still registered leaves you with two marketplaces serving one plugin.

The adapter reaches `core/` through `${CLAUDE_PLUGIN_ROOT}`, a variable Claude
Code sets only when it loads the adapter through its plugin system. Symlinking
the adapter into a project's `.claude/` directory would produce files that look
installed but whose every `core/` pointer dangles, which is why the installer
refuses rather than producing that layout.

Verified by a clean install: `claude plugin details tdd-pipeline@dfrnks`
reports `Skills (8)` and `Agents (5)` — every command and every subagent
loads. The five agent files live at this repository's own `agents/`
directory (the plugin root, not under `adapters/claude-code/`) — see
[`docs/specs/2026-08-03-tdd-pipeline-plugin-design.md`](docs/specs/2026-08-03-tdd-pipeline-plugin-design.md)
for why that placement, specifically, is the one that works.

## Permissions the pipeline needs

The pipeline reads files outside your project and writes git commits inside it.
Both need permission, and when either is missing the failure does not look like
a permission problem — so this section is worth reading before the first run
rather than after it.

**1. The plugin root must be readable.** Every command points at a file under
the package's own `core/`, which lives outside your project directory. In an
interactive session you approve that read once and it is remembered. In a
non-interactive one (`claude -p`, CI, a hook) there is no prompt to approve, so
the read is denied and the flow stops before writing anything. Pass the root
explicitly there:

```bash
claude -p "…" --add-dir /path/to/your/agent-plugins/clone
```

**2. `git add` and `git commit` must be permitted.** `init` and `conventions`
commit what they write, deliberately — a worktree created from the base branch
contains only committed files, so an uncommitted config is invisible to every
phase. If git is denied, both flows still write their files and everything
looks like it worked, and then `doctor` fails on the three "tracked in git"
rows. That reads like a pipeline defect and is a permission setting.

**3. The configured `commands` must be runnable.** The test phase has to
observe its suite actually fail before the implementation exists. If it cannot
run the suite it reports `Status: unverified` rather than claiming red, and the
orchestrator stops — correct behaviour, but the run gets no further.

**4. On Claude Code, trust the workspace first.** This one is the trap. An
untrusted workspace makes Claude Code **ignore the project's entire
`.claude/settings.json` `permissions.allow` list** — not the offending entry,
the whole list — while printing one line about it. The visible symptom is
identical to item 2: flows write, commits silently fail, `doctor` reports the
project not ready. Open the project interactively once and accept the trust
dialog, or set it directly:

```json
// ~/.claude.json
{ "projects": { "/path/to/your/project": { "hasTrustDialogAccepted": true } } }
```

`doctor` names this case rather than leaving you to infer it. A row reading
"exists but is not tracked in git" means the write succeeded and the commit
did not, and that row deliberately offers **no flow to re-run** — neither
`init` nor `conventions` can clear it, since both already wrote the file and
both already failed to commit it. Accept the trust dialog, confirm `git add`
and `git commit` are permitted, then commit the file directly.

## Configuration

`init` writes `.tdd-pipeline/config.yaml` for you, after showing you the draft
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
  specs: .tdd-pipeline/tasks
  worktrees: .tdd-pipeline/worktrees
  conventions: CONVENTIONS.md
  review_checklist: .tdd-pipeline/review-checklist.md   # optional

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

The two harnesses update differently, because only one of them reads the
package from your clone.

**Cursor** reads from your clone, through the symlinks `install.sh` created.
A `git pull` is the whole update, and every project you installed into picks
it up at once:

```bash
cd ~/src/agent-plugins
git pull
```

Re-run `install.sh` only when a release adds a new command or agent file,
which needs a new link. It is idempotent, so re-running it costs nothing.

**Claude Code** depends on how you added the marketplace, and the difference
is worth knowing because it decides whether editing your clone changes what
runs:

- **Added from a local path** (`claude plugin marketplace add /path/to/clone`)
  — `${CLAUDE_PLUGIN_ROOT}` resolves to that clone, so a `git pull`, or any
  edit you make, takes effect on the next dispatch with no reinstall. This is
  the useful mode for working *on* the pipeline. Verified by dispatching a
  phase and having it report the absolute path it resolved: the clone, not the
  cache.
- **Added from a repository** (`claude plugin marketplace add owner/name`) —
  the plugin is fetched into Claude Code's own cache under
  `~/.claude/plugins/cache/`, which is a real copy rather than a link. Update
  it through the plugin flow rather than by pulling your clone.

If you are unsure which mode you are in, dispatch anything and look at the
path it reports, or read the `path` under your marketplace entry in
`~/.claude/settings.json`.

## Constraints worth knowing before you rely on it

**The branch name is the task ID, exactly.** `task` creates the worktree with
`git worktree add <path> -b <task-id> <base>`, and `resume` finds an
interrupted task by looking up `refs/heads/<task-id>`. Rename the branch and
`resume` reports there is nothing to resume, because as far as it can tell the
task was never started. If your team has a branch naming convention —
`feature/`, a username prefix — this pipeline does not currently accommodate
it; the ID is the whole name.

**Three of the five agents are pinned to the larger model.** On Claude Code,
`task-test`, `task-execute` and `task-code-review` declare `model: opus`;
`task-pipeline` and `task-end` use `sonnet`. That is a deliberate split — the
three pinned ones are the phases where a weaker model produces work that looks
right and is not — but it is also a cost decision that was made for you, and a
full task runs all five. Edit the frontmatter in `agents/` if you want a
different trade-off. Cursor's adapter carries no model field, so on Cursor the
choice is whatever your own configuration selects.

**The pipeline commits on your behalf, on your current branch.** `init` and
`conventions` each commit what they write, because a worktree created from the
base branch contains only committed files — an uncommitted config is invisible
to every phase. Both stage only the specific paths they wrote, never `git add
.`, so uncommitted work of your own stays uncommitted.

## Repository layout

```
core/          the pipeline itself — harness-neutral, the only normative content
  contracts/   config schema, spec template, handoff log, conventions template,
               project requirements, review checklist seed
  flows/       init, conventions, doctor, task, review, resume
  phases/      pipeline, test, execute, code-review, end
  trackers/    none, github, linear
agents/        Claude Code subagents — at the plugin (repository) root because
               that is the one location its plugin manifest loads agents from
adapters/      thin per-harness pointers into core/
  claude-code/ commands/ only — its agents/ live at the repository root, above
  cursor/      agents/ and commands/
checks/        the five gates that keep core/ neutral and the tree leak-free
tests/         the test suite covering the checkers
install.sh     links core/ and the Cursor adapter into a project
```

`core/` never names a **harness** — not Claude Code, not Cursor, not a
harness-specific variable or tool. It says "dispatch a subagent"; which tool
does the dispatching is an adapter's business. That rule is enforced
mechanically by `checks/core-is-neutral.sh`, not by convention.

The same checker also flags a sample of third-party tool and framework names,
so a concrete `pytest` or `webpack` cannot drift into a phase file. That half
is a **sample, not a gate**: it knows the tools it lists and nothing else.

Two deliberate exceptions, both under `core/trackers/`: `github.md` names
`gh` and `linear.md` names Linear. A tracker file whose whole job is to drive
one specific tracker cannot describe that job without naming it — the
alternative would be prose so indirect it stops being executable. The
neutrality that matters is that no *phase* or *flow* depends on which tracker
you chose, and `tracker.type` is what selects between them.

## Validation

[`docs/validation-2026-08-03.md`](docs/validation-2026-08-03.md) records the
first end-to-end run of this pipeline against a real project, criterion by
criterion, including what was verified by execution, what was not, and the
defects the run exposed. It is written to be honest rather than green.
