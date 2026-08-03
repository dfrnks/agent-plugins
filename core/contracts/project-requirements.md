# Project requirements contract

The pipeline does not run against an empty project. This is the single
normative list of what a consuming project must have in place, who creates
each artifact, and who checks it afterward. The init, conventions, and doctor
flows all cite this table instead of restating it.

See `core/contracts/pipeline-config.md` for the configuration schema itself —
this contract only names which keys and paths must exist, not their format.

## Requirements

| Requirement | Required | Created by | Validated by |
|---|---|---|---|
| `.agent-pipeline/config.yaml` with every key the configured mode uses | yes | init | every phase, step 0 |
| Git repository with `git.base_branch` present | yes | — | doctor, task |
| `paths.specs` directory | yes | init | doctor |
| `paths.worktrees` directory, git-ignored | yes | init | doctor |
| `paths.conventions` file, non-empty, with derived stack rules | yes | conventions | doctor, execute phase |
| `.agent-pipeline/memory/` directory | no | init | doctor |
| `paths.review_checklist` | no | conventions | doctor |
| `git.worktree_setup` script, if dependencies are git-ignored | conditional | init proposes | task |
| Tracker auth (Linear or `gh auth`) | conditional on `tracker.type` | — | doctor, task |

## Why a populated conventions file is mandatory

The execute and code-review phases do not carry their own inline rules for
project-specific conventions. They delegate that entirely to the project's
conventions file — the one named by `paths.conventions` — reading it at the
start of each run and applying whatever it finds.

That delegation has a failure mode when the file is empty or missing real
content: the phases still run, still report success, and still enforce
nothing, because there was nothing in the file to enforce. This is a silent
pass, and it is worse than a hard failure — a hard failure stops the pipeline
and gets fixed; a silent pass ships unreviewed work while every report says
green.

Therefore the doctor flow treats a conventions file that exists but holds no
rules as a **fail**, never a pass. "Holds no rules" is defined concretely so
this is a mechanical check, not a judgment call: fewer than five list items
or headings found **between the two managed-section markers** that the
conventions flow writes — see `conventions-template.md` for the exact marker
pair. The count never extends past the closing marker or before the opening
one; hand-written prose anywhere outside that span, however long, does not
count toward the threshold. A file above that threshold may still be thin,
but a file below it is treated as equivalent to absent, and doctor reports it
exactly the way it reports a missing file — naming the path and directing
the user to the conventions flow.
