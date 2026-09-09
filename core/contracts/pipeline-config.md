# Pipeline configuration contract

`.tdd-pipeline/config.yaml`, in the consuming project, is the only file the
pipeline requires to exist before it runs. The directory is named for the
pipeline, not for any harness, and holds everything the pipeline owns in a
consuming project:

```
.tdd-pipeline/
  config.yaml
  tasks/TASK-1.md
  memory/<phase>/
  worktrees/TASK-1/
  review-checklist.md      # optional
```

The location is identical on every harness, so a project keeps working when
the developer switches tools — and, unlike a harness-named directory, the
neutrality is real rather than asserted. Harness directories still exist
alongside it and hold only adapters. Every phase and flow cites this contract
instead of restating configuration keys.

## Schema

```yaml
version: 1
project: my-app

tracker:
  type: none                  # none | linear | github
  prefix: TASK                # ID prefix; becomes the branch name
  # team:   <string>          # linear only
  # states: { start: "In Progress", review: "In Review" }

commands:
  test: "<test runner invocation> {target}"   # {target} = a specific module or file, substituted in at run time
  test_all: "<test runner invocation, run with no {target}>"
  lint: "<lint/format invocation>"
  # typecheck: "<typecheck invocation>"       # optional

paths:
  tests: [tests]
  specs: .tdd-pipeline/tasks
  worktrees: .tdd-pipeline/worktrees
  conventions: CONVENTIONS.md  # example only — no default; see note below
  # review_checklist: .tdd-pipeline/review-checklist.md   # optional

git:
  base_branch: main
  commit_trailer: ""
  # worktree_setup: scripts/setup-worktree.sh       # optional

pr:
  enabled: true

# policy:
#   full_suite: every_phase   # every_phase | on_execute_and_end | on_execute | on_end | never
```

`git.commit_trailer` is the **only** trailer any flow may add to a commit.
When it is empty, commits carry no trailer at all. In particular, never append
agent attribution — `Co-authored-by:` naming a tool or model, `Generated-by:`,
or any equivalent — on your own initiative. Harnesses add such a line
reflexively, and many projects forbid it outright; a phase that adds one to an
unpushed commit costs a rewrite, and to a pushed one costs a force-push.
Whether a project *wants* attribution is exactly what setting this key to a
non-empty value says, so an empty value is an instruction, not an omission.

`paths.conventions` has no default. Every project must set it explicitly, to
whatever document already holds its rules — commonly the same file its agent
tooling already reads. `CONVENTIONS.md` above is only an illustrative example
value, not a fallback the pipeline assumes when the key is absent; an absent
`paths.conventions` key is handled like any other missing required key, under
Fail-fast protocol below, not silently defaulted.

This contract names no specific filename on purpose: naming one would embed
an assumption about which harness a project uses into a file that must stay
harness-neutral. A design document aimed at developers configuring a specific
harness may name concrete files for that harness as examples; this contract,
which the pipeline itself reads at runtime across every harness, does not.

`policy.full_suite` decides **which phases run `commands.test_all`**, the broad
run, as opposed to `commands.test`, the targeted one. It exists because the
broad run is usually the single largest cost in a pipeline, and how much it buys
varies by project in a way this contract cannot guess. In a monolith whose
modules import each other freely, a change anywhere can break anything, and
running everything at every phase is the point. In a repository of independent
packages, most of that run exercises code the change provably cannot reach.

| Value | Runs the broad suite |
|---|---|
| `every_phase` | test, execute, and end |
| `on_execute_and_end` | execute, and end |
| `on_execute` | execute only |
| `on_end` | end only, unconditionally, as the last gate before the pull request |
| `never` | nowhere — only `commands.test` runs, and CI is the regression gate |

When the key is absent the value is `every_phase`. That default preserves the
behavior of every project configured before this key existed: a pipeline that
silently starts verifying less after a plugin upgrade is a worse failure than a
slow one. `doctor` reports the effective value and says the key is unset, so a
project keeps the old behavior until it chooses otherwise rather than by never
having heard of the choice.

Two properties of the scale are worth stating, because the ordering is not by
strength alone. `on_execute` fails **earlier**, while the implementation is
still the thing being worked on and a fix is cheap and local. `on_end` fails
**later** but covers **more**: it is the only single-run value that sees the
state after lint autofix, which `end` applies after code-review has already
approved. `on_execute_and_end` is the pair, and is what a project that wants one
value without studying the trade-off should pick.

`never` is not reckless on its own terms — it is a statement that CI is the
regression gate and the project accepts a round trip when a break lands outside
the changed scope. It costs the most when the pipeline runs unattended, because
the broad run is then the last thing standing between a broken pull request and
a human noticing.

Whatever the policy, what `commands.test_all` *means* stays the project's to
define. A monorepo whose packages are independent may legitimately define it to
cover the packages a change touches rather than every test in the repository;
that is a narrower `all`, decided by the project that can prove the
independence, not by this contract.

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
| `tracker.states` | | yes | optional | |
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
| `policy.full_suite` | | | | yes |

`tracker.type: github` needs nothing beyond the always-mandatory keys to
function: it authenticates through `gh` and can label using nothing but the
prefix already required for every mode. `tracker.states` is accepted but
optional in this mode — a project that prefers named labels like
`In Progress` / `In Review` over the prefix-derived defaults may set
`tracker.states.start` and `tracker.states.review` and github mode uses
those as the label names instead. When the key is absent, the defaults are
`<prefix>:in-progress` and `<prefix>:in-review`, built from `tracker.prefix`
— naming the exact default here, rather than leaving it to each tracker
file to invent one, is what keeps the label names identical however many
times a project regenerates its configuration or reads this contract.
`tracker.states` with only `start` or only `review` set is a configuration
error under github mode, handled like any other malformed key: stop and
name the missing half, rather than silently defaulting it while honoring
the one that was provided.

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
naming the file and the specific missing key:

```
Cannot start: `.tdd-pipeline/config.yaml` is missing key `commands.test`.
Add it, or run the init flow to regenerate the configuration.
```

The configuration path stays `.tdd-pipeline/config.yaml` regardless of
harness, because it is the pipeline's own directory, not a harness directory.
