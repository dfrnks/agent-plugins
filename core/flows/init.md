# Flow: init

Bootstrap a project so the pipeline has something to run against. Every other
phase and flow reads `.tdd-pipeline/config.yaml` at its own Step 0 and stops
the moment a key it needs is absent — none of them infers a missing value,
because a wrong guess there costs an entire branch of invalid work. This flow
is where that inference happens instead: once, in front of a person who
reviews it before it lands.

Takes no argument. Run it once against a project that has never used the
pipeline, or again later to review the configuration against a codebase that
has since changed shape.

## Step 1 — Detect the stack

Inspect the repository for the signals a project normally carries: a
dependency manifest at its root (or in each package, for a multi-package
layout), a configured test runner, a configured linter or formatter, and
whichever directories those tools populate with installed dependencies. Read
the configuration those tools already expose — a manifest's declared scripts,
a checked-in config file naming the linter's entry point — rather than
guessing at a convention this project might not follow.

State plainly in Step 2's proposal that this detection pass is the one
exception to the pipeline's rule against inferring configuration. Every
phase's fail-fast protocol refuses to guess a command or a path because an
unattended run has nobody to catch a wrong guess. Nothing here runs
unattended: Step 2 puts every detected value in front of a human, and nothing
reaches disk until they confirm it. **The exception is the confirmation gate,
not the detection** — no other flow carries that gate, so none of them may
reuse this reasoning to justify guessing a command on its own.

If no manifest, test runner, or linter can be found, do not fail — carry it
forward as an explicit gap in Step 2's proposal, so the person confirming
fills in what detection could not find.

Detection finding nothing has two causes, and Steps 5 and 6 behave
differently for each. Run the greenfield test from
`core/contracts/project-requirements.md`'s `## Greenfield projects` section
here, once, and carry the result forward:

- **A project with source code but no tooling detected** — the tooling exists
  and detection missed it, or the project has none configured yet. Either way
  a person fills the gap in Step 2 and everything proceeds normally.
- **A greenfield project** — nothing is tracked but the pipeline's own
  artifacts and prose. There is no tooling to detect because there is no
  project yet.

Say which in Step 2's proposal, in those terms. The difference is invisible
in a report that only says "no test runner found," and it decides whether the
commands a person is about to supply describe tooling that exists today or
tooling they intend to add.

This flow configures a project; it does not create one. A greenfield project
is a supported input and this flow runs to completion against it. It will not
scaffold a manifest, a test runner, or a first package to make detection
succeed, and it will not ask whether it should — that is the project's own
first task, and inventing one here would mean guessing a layout in the one
flow whose discipline is refusing to guess.

## Step 2 — Propose the configuration

Draft a complete `.tdd-pipeline/config.yaml` following the schema in
`core/contracts/pipeline-config.md`, using Step 1's findings for
`commands.test`, `commands.test_all`, `commands.lint`, and
`commands.typecheck` where found. Detect `git.base_branch` from the
repository's current default branch rather than assuming a name.

Every other key needs a person's decision: `tracker.type` (and, depending on
it, `tracker.team` or `tracker.states`), `paths.conventions` (no default
exists — see that contract's note on why), and whether `pr.enabled`. Ask for
each explicitly; default none of them silently.

The draft is incomplete until it carries **every** key the "Required keys by
mode" table marks always-mandatory, not only the ones Step 1 detected. The
remaining ones are easy to omit precisely because nothing in this flow's
narrative forces them, and a configuration missing any fails this flow's own
Step 6:

- `version` — the schema version from that contract, written literally.
- `project` — propose the repository directory's name and let the person
  correct it.
- `tracker.prefix` — the task ID prefix, which also becomes the branch name.
  Ask; it is not derivable from the repository.
- `paths.tests` — a list holding every directory this project keeps tests in.
  Propose what Step 1 found and confirm the list is complete; a project that
  separates unit and integration tests needs both entries.
- `paths.specs` and `paths.worktrees` — propose the contract's layout values
  and confirm them; every phase reads them from this file.
- `git.commit_trailer` — mandatory as a key, commonly empty as a value. Write
  it explicitly, empty string included, so no phase has to decide whether an
  absent key means "none" or "not configured yet".
- `policy.full_suite` — **ask, and ask with the cost on the table.** This one
  key decides how much wall-clock every pipeline in this project spends, and the
  right answer depends on how coupled the codebase is, which the person being
  asked knows and this flow does not. Do not propose a value silently.

  Before asking, measure rather than guess: run `commands.test` against one
  small module and `commands.test_all`, and put both numbers in the question.
  A project whose broad run costs six seconds does not need this decision; one
  whose broad run costs fifteen minutes is choosing between roughly one hour and
  roughly fifteen minutes per task, and deserves to know that before answering.

  Offer the five values from the contract, each with what it buys:

  - `every_phase` — test, execute and end. Most verification, most time. The
    right answer for a monolith whose modules import each other freely, where a
    change anywhere can break anything.
  - `on_execute_and_end` — the pair. Recommend this one absent a reason: it
    keeps the run that fails early and the run that sees the post-autofix state,
    and drops only the test-phase run, which happens before any implementation
    exists and is the weakest of the three.
  - `on_execute` — one run, failing earliest, while a fix is still cheap.
  - `on_end` — one run, later but broader: the only single-run value that sees
    what lint autofix did after code-review approved.
  - `never` — only the targeted run; CI is the regression gate. Say plainly what
    this trades: a break outside the changed scope is found by CI after the pull
    request exists, which costs a human noticing and the pipeline being
    dispatched again. Reasonable when someone watches CI; expensive when the
    pipeline runs unattended.

  If the person has no opinion, write `on_execute_and_end` and say that is what
  was written. Never leave the key out to mean "decide later": an absent key is
  `every_phase`, the slowest value, and a project should arrive there by choosing
  it rather than by omission.

Present the whole draft and ask for confirmation before writing anything.
Edit any line the person changes, and only once every key is settled, write
`.tdd-pipeline/config.yaml`. Nothing before this point has touched disk.

## Step 3 — Create directories

Create what the confirmed configuration points at: `paths.specs`,
`paths.worktrees`, and `.tdd-pipeline/memory/`. `paths.conventions` is not
created here — Step 5 hands that to a flow whose job is populating it with
real content, not an empty placeholder that looks satisfied while holding
nothing.

Add `paths.worktrees` to `.gitignore` if no existing entry covers it.

Then **commit the configuration**, on the branch the repository is already
on:

```bash
git add .tdd-pipeline/config.yaml .gitignore
git commit -m "pipeline: add configuration"
```

This is not optional. Every phase runs inside a worktree created fresh from
`git.base_branch`, which contains exactly the files that branch has
committed. A `.tdd-pipeline/config.yaml` that exists only in the main
checkout's working tree is invisible from every phase's Step 0, so the
pipeline stops at its first step telling the user to run this flow — in a
project where this flow has already run.

If `git.commit_trailer` was set to a non-empty value, append it as a trailer.
If the repository has uncommitted work of the user's own, stage only the two
paths above — never `git add .`.

## Step 4 — Worktree setup script

A worktree created fresh from `git.base_branch` starts with nothing the
project excludes from version control. Check whether any such directory is
git-ignored here. If none is, a fresh worktree already has what it needs and
this step ends with nothing to propose.

Otherwise propose a small setup script that installs or restores whatever
those directories hold, and propose setting `git.worktree_setup` to its path.
As with every value in this flow, propose and wait for confirmation rather
than writing unattended.

Once confirmed and written, **make the script executable and verify that it
is**, before committing:

```bash
chmod +x <setup script>
test -x <setup script>
```

The orchestrator runs this script directly, so the executable bit is part of
the artifact rather than a detail of how it was created. A script written
without it fails inside a worktree, on the first task, long after this flow
reported success. Git records the bit, so setting it here carries it to every
worktree and clone.

If `chmod` cannot be run, say so and stop this step rather than committing a
script that will not run. An unexecutable setup script is the same as a
missing one to every phase downstream, and worse than a missing one to a
reader, who sees a configured path and a file that exists.

Then commit the script and the configuration change together, for the same
reason Step 3 commits the configuration:

```bash
git add <setup script> .tdd-pipeline/config.yaml
git commit -m "pipeline: add worktree setup script"
```

## Step 5 — Derive conventions

Hand off to `core/flows/conventions.md` against the `paths.conventions` file
just confirmed. That flow populates it with rules derived from this codebase;
this step only triggers the handoff.

Hand off on a greenfield project too, rather than skipping. That flow has
defined behaviour for a codebase with nothing to explore (its
`## Greenfield projects` section): it skips exploration, writes the seven
headings with no rules under them, and commits. The file the execute and
code-review phases read must exist and be committed either way, so the
handoff is what creates it — skipping to save an exploration that would find
nothing would also skip the write.

Report which of the two happened. "Derived 6 rules" and "derived none,
because there is no code yet" are both correct outcomes, and only one means
the next flow has nothing left to do.

## Step 6 — Verify

Run `core/flows/doctor.md` and print its report in full. This flow never
claims the project is ready on its own account — every claim of readiness
comes from doctor's checks, run fresh against what Steps 1 through 5 actually
produced.

Print doctor's verdict as doctor reports it, including its greenfield line
when there is one. Do not restate a greenfield `n/a` on the conventions row
as a failure of Step 5, and do not follow it with an instruction to run the
conventions flow — that flow ran, in Step 5, and behaved correctly. A
greenfield project reaching `ready` here is this flow succeeding, not
settling.
