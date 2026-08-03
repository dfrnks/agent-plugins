# Flow: doctor

Verify that a project actually satisfies every requirement in
`core/contracts/project-requirements.md`, and optionally repair what it
finds missing. This flow is the only place that table is checked
mechanically rather than assumed — `init` calls it at the end of its own run
for exactly that reason, so that flow never claims a project is ready on its
own say-so.

Takes an optional `repair` argument. With no argument, this flow only
reports; nothing it finds ever gets fixed without the argument, and even
with it, nothing gets fixed without the confirmation `## Repair mode`
describes below.

## Checks

Run one check per row of `core/contracts/project-requirements.md`'s
requirements table, each reporting `pass`, `fail`, or `n/a`:

- **`.agent-pipeline/config.yaml` with every key the configured mode
  uses, tracked in git** — the file exists, parses, and holds every
  always-mandatory key from `core/contracts/pipeline-config.md`'s "Required
  keys by mode" table, plus whichever conditional keys `tracker.type`'s
  value requires. A missing file or a missing key is `fail`, naming the
  exact key. The file must also be **tracked in git**, checked
  mechanically:

  ```bash
  git ls-files --error-unmatch .agent-pipeline/config.yaml
  ```

  A non-zero exit is a `fail` on this row, with the message naming the file
  and saying why an untracked configuration is fatal rather than untidy:
  every phase runs inside a worktree created fresh from `git.base_branch`,
  which contains only committed files, so an untracked configuration is
  invisible at every phase's Step 0 and the pipeline stops at its first
  step. This row is what keeps that failure from recurring silently — it is
  the check that would have caught a configuration written but never
  committed.
- **Git repository with `git.base_branch` present** — the current directory
  is a git repository and the branch named by `git.base_branch` exists.
  `fail` otherwise; this row is never `n/a`, it is required unconditionally.
- **`paths.specs` directory** — exists. `fail` if absent.
- **`paths.worktrees` directory, git-ignored** — exists, and is covered by
  an entry in `.gitignore`. `fail` if either half is missing — a worktree
  directory that exists but is not git-ignored is still a `fail`, not a
  partial pass, since committing a worktree's contents duplicates them
  under version control.
- **`paths.conventions` file, non-empty, with derived stack rules, tracked
  in git** — the specific check this flow exists to get right, detailed on
  its own below. It carries the same `git ls-files --error-unmatch` tracking
  check as the configuration row above, and for the same reason: a
  conventions file the phases cannot see from inside a worktree enforces
  exactly as much as an empty one.
- **`.agent-pipeline/memory/` directory** — exists. The requirements table
  marks this row "no" under "Required," but that column tracks whether the
  pipeline can run at all without it, not whether this check applies —
  `init` always creates this directory, so check it plainly: `pass` if
  present, `fail` if absent, since its absence means something removed it
  after the fact, not that this is a project with no use for it.
- **`paths.review_checklist`** — optional in the table. Report `n/a` when
  the configuration does not set this key at all. When it is set, check
  that the file it names exists **and is tracked in git**, the same way the
  two rows above are checked; `fail` if the key is set but the file is
  missing or untracked, since a configured-but-absent path is a broken
  reference, not an intentional absence, and an untracked one is absent
  from every worktree the code-review phase reads it in.
- **`git.worktree_setup` script, if dependencies are git-ignored** —
  conditional. Report `n/a` when no dependency directory in this project is
  git-ignored, per the same detection `init`'s Step 4 performs. When one is,
  `fail` if `git.worktree_setup` is unset or points at a script that does
  not exist; `pass` otherwise.
- **Tracker auth (Linear or a connected tracker CLI)** — conditional on
  `tracker.type`. Report `n/a` for `tracker.type: none`. For the other two
  modes, perform the connection check that mode's own tracker file requires
  before any of its operations run — the Linear MCP server connection
  described in `core/trackers/linear.md`'s opening paragraphs, or the `gh
  auth status` check described in `core/trackers/github.md`'s — and report
  `pass` or `fail` accordingly, naming what failed.

### The conventions check, specifically

This is the check `core/contracts/project-requirements.md` calls out by
name: the execute and code-review phases carry no inline rules of their
own for anything project-specific, and read `paths.conventions` instead, at
the start of every run, trusting whatever it holds completely. A file that
exists but holds no real content is not a harmless placeholder under that
design — it is silent non-enforcement wearing the appearance of a working
pipeline: every phase still runs, still reports success, and enforces
nothing, because there was nothing in the file to enforce.

Apply the threshold defined in `core/contracts/project-requirements.md`
exactly, mechanically, not as a judgment call: count **rule lines** found
strictly between the `<!-- pipeline:conventions:start -->` and
`<!-- pipeline:conventions:end -->` markers (see
`core/contracts/conventions-template.md`). A rule line is a list item
carrying a `file:line` citation — the exact shape the conventions flow
writes a rule in. Nothing else counts:

- **Never count a heading.** The conventions flow emits all seven area
  headings on every run, including for areas where nothing was derived, so
  counting headings would clear a five-item bar on a file holding no rules
  at all — the precise silent pass this threshold exists to prevent.
- **Never count a "no rule derived" line**, however it is worded. It is the
  flow reporting an absence, not a rule.
- **Never count a list item with no `file:line` citation.** An
  uncited line has nothing a later reader or run can check it against, and
  the citation is what distinguishes a derived rule from a sentence.
- Never count anything before the opening marker or after the closing one,
  however long that surrounding prose runs — a human's own hand-written
  notes elsewhere in the file do not satisfy this check, by design. Items
  in the discoveries span (`<!-- pipeline:discoveries:start -->` /
  `<!-- pipeline:discoveries:end -->`) do not count either; that span holds
  candidates the conventions flow has not confirmed.

Fewer than five such rule lines is a `fail`. A missing file, or a file with
no markers at all, is also a `fail` — it is `fail` the same way a file below
the threshold is, not a separate case, because both mean the same thing to a
phase that reads this file expecting real rules: nothing is there to
enforce.

When this check fails, the message names the file and states the specific
problem plainly, not a generic "requirement not met":

```
paths.conventions (<path>) has <N> rule(s) in its managed section — fewer
than the 5 required. The execute and code-review phases enforce nothing
project-specific until this file holds real rules. Run the conventions
flow to derive them from the codebase.
```

## Output

Report a table, one row per check, in the requirements table's own order,
each row showing the check name and its `pass` / `fail` / `n/a` result.

Follow the table with a one-line summary: the count of passes, fails, and
n/a results, and an overall verdict — `ready` if every non-`n/a` check
passed, `not ready` otherwise.

Follow that, on `not ready`, with the exact command to fix the first
failure in table order — naming the flow to run (`init`, `conventions`, or
a direct edit to `.agent-pipeline/config.yaml`) rather than a generic
instruction to "resolve the issue." A person acting on this report should
never have to translate a `fail` row into a next action themselves.

## Repair mode

With the `repair` argument, after printing the same report `## Output`
describes, offer to fix each failing row, one at a time, in table order.
For each:

- A missing or incomplete `.agent-pipeline/config.yaml`, a missing
  `paths.specs` or `paths.worktrees` directory, an un-ignored worktree
  path, or a missing `git.worktree_setup` script — offer to delegate to the
  init flow (`core/flows/init.md`) to regenerate or complete it.
- An empty, missing, or under-threshold `paths.conventions` file — offer to
  delegate to the conventions flow (`core/flows/conventions.md`) to derive
  real rules.
- A missing tracker authentication — this flow does not authenticate on the
  user's behalf; report the exact command the relevant tracker file names
  (`gh auth login` for `github` mode, the equivalent for `linear` mode) and
  stop there.

State plainly, before doing anything, which delegated flow will run and
what it will touch. Never repair without an explicit confirmation for each
item — this flow finding a `fail` is not itself permission to change
anything, any more than `init`'s own detection pass in Step 1 is permission
to write without Step 2's confirmation gate. A person who ran `doctor
repair` expecting a report and got an unasked-for rewrite of their
configuration has had this flow do exactly what `init` was built not to do.

After every confirmed repair completes, re-run `## Checks` in full and
print the refreshed report, rather than assuming the delegated flow
succeeded — the same discipline `init`'s own Step 6 holds itself to.
