# Flow: init

Bootstrap a project so the pipeline has something to run against. Every
other phase and flow reads `.agent-pipeline/config.yaml` at its own step 0
and stops the moment a key it needs is absent — none of them infers a
missing value, because a wrong guess there costs an entire branch of invalid
work. This flow is where that inference happens instead, once, in front of a
person who reviews it before it lands.

Takes no argument. Run it once against a project that has never used the
pipeline, or again later to review the configuration against a codebase that
has since changed shape.

## Step 1 — Detect the stack

Inspect the repository for the signals a project normally carries: a
dependency manifest at its root (or in each package, for a multi-package
layout), a configured test runner, a configured linter or formatter, and
whichever directories those tools populate with installed dependencies.
Read whatever configuration those tools already expose — a manifest's own
declared scripts, a checked-in config file naming the linter's entry point —
rather than guessing at a convention this specific project might not follow.

State plainly, in the proposal this step feeds into Step 2, that this
detection pass is the one exception to the pipeline's own rule against
inferring configuration: every phase's fail-fast protocol (see
`core/contracts/pipeline-config.md`) refuses to guess a command or a path,
because an unattended run has no one to catch a wrong guess before it
burns a branch of work. This flow is different only because nothing here
runs unattended — Step 2 puts every detected value in front of a human, and
nothing from this step reaches disk until that human confirms it. An agent
implementing a later flow that reuses this reasoning to justify guessing a
command on its own has misread why the exception exists here: the exception
is the confirmation gate, not the detection itself, and no other flow in
this pipeline carries that gate.

If no manifest, test runner, or linter can be found at all, do not fail —
carry that forward as an explicit gap in Step 2's proposal instead, so the
person confirming it fills in what detection could not find rather than
receiving a silently incomplete file.

## Step 2 — Propose the configuration

Draft a complete `.agent-pipeline/config.yaml` following the schema in
`core/contracts/pipeline-config.md`, using Step 1's findings for
`commands.test`, `commands.test_all`, `commands.lint`, and
`commands.typecheck` where one was found. Detect `git.base_branch` from the
repository's own current default branch rather than assuming a name.

Every other key needs a person's decision, not a detected value:
`tracker.type` (and, depending on it, `tracker.team` or `tracker.states`),
`paths.conventions` (no default exists — see that contract's note on why),
and whether `pr.enabled`. Ask for each explicitly; do not default any of
them silently.

The draft is incomplete until it carries **every** key the "Required keys by
mode" table in `core/contracts/pipeline-config.md` marks always-mandatory,
not only the ones Step 1 detected and the ones above that obviously need a
decision. The remaining always-mandatory keys are easy to omit precisely
because nothing in this flow's own narrative forces them, and a
configuration missing any one of them fails this flow's own Step 6 doctor
run against the file it just wrote:

- `version` — the schema version from that contract, written literally.
- `project` — the project's own name; propose the repository directory's
  name and let the person correct it.
- `tracker.prefix` — the task ID prefix, which also becomes the branch
  name. Ask; it is not derivable from the repository.
- `paths.tests` — a list, holding every directory this project keeps tests
  in. Propose what Step 1 found and confirm the list is complete; a project
  that separates unit and integration tests needs both entries.
- `paths.specs` and `paths.worktrees` — propose the contract's own layout
  values and confirm them, rather than leaving them unset because a default
  exists somewhere in a document; every phase reads them from this file.
- `git.commit_trailer` — mandatory as a key, commonly empty as a value.
  Write it explicitly, empty string included, so no phase has to decide
  whether an absent key means "none" or "not configured yet".

Present the whole draft file and ask for confirmation before writing
anything — edit any line the person changes, and only once every key is
settled, write `.agent-pipeline/config.yaml`. Nothing before this point has
touched disk.

## Step 3 — Create directories

Once the configuration is confirmed and written, create what it points at:
`paths.specs`, `paths.worktrees`, and `.agent-pipeline/memory/`, per the
layout in `core/contracts/pipeline-config.md`. `paths.conventions` is not
created here — Step 5 hands that off to a flow whose entire job is
populating it with real content, not an empty placeholder this step could
create and leave looking satisfied while holding nothing.

Add `paths.worktrees` to `.gitignore` if it is not already covered by an
existing entry there — a worktree checked into version control would
duplicate every file inside it under source control twice, once in the
worktree and once wherever the base branch already tracks it.

Then **commit the configuration**, on the branch the repository is already
on:

```bash
git add .agent-pipeline/config.yaml .gitignore
git commit -m "pipeline: add configuration"
```

This is not bookkeeping, and it is not optional. Every phase runs inside a
worktree created fresh from `git.base_branch`, and a fresh worktree contains
exactly the files that branch has committed — nothing else. A
`.agent-pipeline/config.yaml` that exists only in the main checkout's
working tree is invisible from every phase's own Step 0, so the entire
pipeline stops at its first step with a message telling the user to run this
flow, in a project where this flow has already run. Committing here is what
makes the file reachable from the place it is actually read.

If `git.commit_trailer` was set to a non-empty value in Step 2, append it as
a trailer on this commit. If the repository has uncommitted work of the
user's own, stage only the two paths named above — never `git add .` — so
this flow commits nothing it did not itself write.

## Step 4 — Worktree setup script

A worktree created fresh from `git.base_branch` starts with nothing that
the project excludes from version control — no installed dependencies, no
virtual environment, no local configuration file `.gitignore` keeps out of
the repository. Check whether any such directory is git-ignored in this
project. If none is, a fresh worktree already has everything it needs and
this step ends here with nothing to propose.

Otherwise, propose a small setup script that installs or restores whatever
those git-ignored directories hold, and propose setting `git.worktree_setup`
in the configuration to its path. As with every value in this flow, propose
and wait for confirmation rather than writing the script or the config key
unattended.

Once confirmed and written, commit the script and the configuration change
together, for the same reason Step 3 commits the configuration itself — the
orchestrator runs this script from inside a worktree, where only committed
files exist:

```bash
git add <setup script> .agent-pipeline/config.yaml
git commit -m "pipeline: add worktree setup script"
```

## Step 5 — Derive conventions

Hand off to the conventions flow (`core/flows/conventions.md`) against the
`paths.conventions` file just confirmed. That flow is what actually
populates the file with rules derived from this codebase — this step only
triggers that handoff, it does not duplicate any part of how that flow
explores the codebase or decides what counts as a rule.

## Step 6 — Verify

Run the doctor flow (`core/flows/doctor.md`) and print its report in full.
This flow never claims the project is ready on its own account — every
claim of readiness comes from doctor's own checks, run fresh against what
Steps 1 through 5 actually produced, not from this flow's assumption that
its own steps succeeded.
