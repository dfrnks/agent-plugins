# Flow: doctor

Verify that a project actually satisfies every requirement in
`core/contracts/project-requirements.md`, and optionally repair what it finds
missing. This is the only place that table is checked mechanically rather
than assumed — `init` calls it at the end of its own run so that flow never
claims a project is ready on its own say-so.

Takes an optional `repair` argument. Without it, this flow only reports. Even
with it, nothing is fixed without the confirmation `## Repair mode` describes.

## Checks

Run one check per row of the requirements table, each reporting `pass`,
`fail`, or `n/a`:

- **`.tdd-pipeline/config.yaml` with every key the configured mode uses,
  tracked in git** — the file exists, parses, and holds every
  always-mandatory key from `core/contracts/pipeline-config.md`'s "Required
  keys by mode" table, plus whichever conditional keys `tracker.type`
  requires. A missing file or key is `fail`, naming the exact key. The file
  must also be tracked in git:

  ```bash
  git ls-files --error-unmatch .tdd-pipeline/config.yaml
  ```

  A non-zero exit is a `fail`, with a message saying why an untracked
  configuration is fatal rather than untidy: every phase runs inside a
  worktree created fresh from `git.base_branch`, which contains only
  committed files, so an untracked configuration is invisible at every
  phase's Step 0 and the pipeline stops at its first step.
- **Git repository with `git.base_branch` present** — the current directory
  is a git repository and that branch exists. `fail` otherwise; never `n/a`.
- **`paths.specs` directory** — exists. `fail` if absent.
- **`paths.worktrees` directory, git-ignored** — exists, and is covered by an
  entry in `.gitignore`. `fail` if either half is missing; a worktree
  directory that exists but is not ignored is a `fail`, not a partial pass,
  since committing a worktree's contents duplicates them under version
  control.
- **`paths.conventions` file, non-empty, with derived stack rules, tracked in
  git** — detailed on its own below. It carries the same
  `git ls-files --error-unmatch` check, for the same reason: a conventions
  file the phases cannot see from inside a worktree enforces as much as an
  empty one.
- **`.tdd-pipeline/memory/` directory** — exists. The requirements table
  marks this row "no" under "Required," but that column tracks whether the
  pipeline can run without it, not whether this check applies. `init` always
  creates it, so `pass` if present, `fail` if absent — absence means
  something removed it.
- **`paths.review_checklist`** — `n/a` when the configuration does not set
  the key. When set, check that the file exists **and is tracked in git**;
  `fail` if set but missing or untracked. A configured-but-absent path is a
  broken reference, and an untracked one is absent from every worktree
  code-review reads it in.
- **`git.worktree_setup` script, if dependencies are git-ignored** — `n/a`
  when no dependency directory in this project is git-ignored, per the same
  detection `init`'s Step 4 performs. When one is, `fail` if
  `git.worktree_setup` is unset, points at a script that does not exist, or
  points at one that is **not executable**; `pass` otherwise. Check the last
  mechanically with `test -x <path>` and name it distinctly from a missing
  file — "exists but is not executable" is a one-command fix, and reporting
  it as absent sends the user to regenerate a correct script. The bit matters
  because the orchestrator runs the script directly: without it the run stops
  before any phase, with an error that looks like a pipeline failure rather
  than a file mode.
- **Tracker auth** — `n/a` for `tracker.type: none`. For the other two modes,
  perform the connection check that mode's tracker file requires before any
  of its operations run — the Linear MCP server connection in
  `core/trackers/linear.md`, or the `gh auth status` check in
  `core/trackers/github.md` — and report `pass` or `fail`, naming what
  failed.

### The conventions check, specifically

The execute and code-review phases carry no inline rules for anything
project-specific; they read `paths.conventions` at the start of every run and
trust whatever it holds. A file that exists but holds no real content is
therefore silent non-enforcement wearing the appearance of a working
pipeline: every phase runs, reports success, and enforces nothing.

Apply the threshold from `core/contracts/project-requirements.md` exactly and
mechanically. Count **rule lines** strictly between
`<!-- pipeline:conventions:start -->` and `<!-- pipeline:conventions:end -->`
(see `core/contracts/conventions-template.md`). A rule line is a list item
carrying a `file:line` citation anywhere in it. Nothing else counts:

- **Count list items, never physical lines.** A rule wraps onto as many lines
  as it needs, and its citation commonly closes the item on a continuation
  line. Count each `- ` item once, reading through to the next item or the
  closing marker, and ask whether a citation appears anywhere inside it.
  Counting lines that end in a citation would fail a file holding five real
  rules.
- **Never count a heading.** The conventions flow emits all seven area
  headings on every run, including for areas where nothing was derived, so
  counting them would clear a five-item bar on a file holding no rules.
- **Never count a "no rule derived" line**, however worded. It reports an
  absence.
- **Never count a list item with no `file:line` citation.** The citation is
  what distinguishes a derived rule from a sentence.
- Never count anything outside the markers, however long the surrounding
  prose. Items in the discoveries span
  (`<!-- pipeline:discoveries:start -->` / `<!-- pipeline:discoveries:end -->`)
  do not count either; that span holds candidates the conventions flow has
  not confirmed.

Fewer than five rule lines is a `fail`. A missing file, or a file with no
markers, is the same `fail` rather than a separate case — to a phase reading
this file expecting real rules, both mean nothing is there to enforce.

When this check fails, name the file and the specific problem:

```
paths.conventions (<path>) has <N> rule(s) in its managed section — fewer
than the 5 required. The execute and code-review phases enforce nothing
project-specific until this file holds real rules. Run the conventions
flow to derive them from the codebase.
```

#### The one exception: a greenfield project

Before counting anything, run the greenfield test from
`core/contracts/project-requirements.md`'s `## Greenfield projects` section —
the `git ls-files` command written there, verbatim, exclusions included. Do
not substitute a different test, and do not decide the question by forming an
impression of the repository.

If that command's output is empty, report this row **`n/a`** with the reason
attached, and count no rules:

```
paths.conventions (<path>) — n/a: no source files are tracked in this
repository, so no rule can carry a file:line citation yet. The file exists
with its seven headings and is committed. This row becomes a real check on
the first commit that tracks a source file; run the conventions flow then.
```

State the reason inline on every greenfield run. A bare `n/a` is
indistinguishable from the optional rows below it, and this one is not
optional — it is deferred, and the report is the only place that distinction
is visible.

If the command prints even one path, the exception does not apply: count and
report `pass` or `fail`. The exception is the empty set and nothing else —
never a repository that merely looks new, holds only scaffolding, or tracks a
handful of files that seem too small to have conventions. Reporting `n/a`
here waives the one check standing between the project and silent
non-enforcement, so an over-generous verdict reintroduces the failure this
threshold prevents, while an over-strict one merely prints a `fail` somebody
can read.

## Output

Report a table, one row per check, in the requirements table's order, each
showing the check name and its `pass` / `fail` / `n/a` result.

Follow it with a one-line summary: the count of each result, and an overall
verdict — `ready` if every non-`n/a` check passed, `not ready` otherwise.

A greenfield `paths.conventions` row is `n/a`, so it does not block `ready`.
That is correct and not a loophole: the configuration, directories, and
branch are in place, and the file the phases read exists and is committed.
What it holds is nothing, which is the honest state of a project that has
established no conventions yet.

Say so explicitly. A `ready` verdict on a greenfield project carries one
extra line, immediately after the summary:

```
Greenfield: no conventions are derived yet, and none can be until this
repository tracks source code. Run the conventions flow after the first
code lands.
```

Never report `ready` on a greenfield project without that line. `ready` alone
tells a reader the conventions file passed, and it did not — it was never
checked.

On `not ready`, follow with the exact command to fix the first failure in
table order, naming the flow to run (`init`, `conventions`, or a direct edit
to `.tdd-pipeline/config.yaml`) rather than a generic instruction to resolve
the issue.

Name a fix only where running it can change the row. Pairing a `fail` with a
flow that provably cannot clear it is worse than naming no fix, because the
reader spends a run finding out and still cannot tell whether the flow failed
or the project is unfixable. Check the fix against the row before writing it;
never emit standing remedy text on the assumption it applies.

## Repair mode

With the `repair` argument, after printing the same report, offer to fix each
failing row, one at a time, in table order:

- A missing or incomplete `.tdd-pipeline/config.yaml`, a missing
  `paths.specs` or `paths.worktrees` directory, an un-ignored worktree path,
  or a missing `git.worktree_setup` script — offer to delegate to
  `core/flows/init.md`.
- An empty, missing, or under-threshold `paths.conventions` file — offer to
  delegate to `core/flows/conventions.md`. A greenfield project never reaches
  this offer, since that row reports `n/a` rather than `fail`. Do not add a
  repair for it: delegating against a repository with no source would spend a
  full exploration pass rediscovering that it has nothing to explore.
- A missing tracker authentication — this flow does not authenticate on the
  user's behalf. Report the exact command the relevant tracker file names
  (`gh auth login` for `github` mode, the equivalent for `linear`) and stop.

State plainly, before doing anything, which delegated flow will run and what
it will touch. Never repair without an explicit confirmation for each item.
Finding a `fail` is not permission to change anything, any more than `init`'s
detection pass is permission to write without its confirmation gate — a
person who ran `doctor repair` expecting a report and got an unasked-for
rewrite of their configuration has had this flow do exactly what `init` was
built not to do.

After every confirmed repair, re-run `## Checks` in full and print the
refreshed report rather than assuming the delegated flow succeeded — the same
discipline `init`'s own Step 6 holds itself to.
