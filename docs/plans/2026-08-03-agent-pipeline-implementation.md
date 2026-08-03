# Agent Pipeline Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a harness-agnostic, agent-driven TDD pipeline package — neutral `core/` content plus thin Claude Code and Cursor adapters — installable into any project.

**Architecture:** All real content lives once in `core/` as harness-neutral Markdown. Adapters are ~5-line files carrying harness-specific frontmatter and a pointer into `core/`. Repository invariants (no leakage, core neutrality, resolvable references, required structure) are enforced by shell checkers driven by a manifest, and those checkers are what this plan tests against.

**Tech Stack:** Markdown, POSIX shell, git. No language runtime, no build step, no third-party dependencies.

**Design source:** `docs/specs/2026-08-03-tdd-pipeline-plugin-design.md`. Read it before starting.

## Global Constraints

- **English only.** Every file in this repository — docs, prompts, comments, commit messages, error strings — is written in English.
- **No leakage.** No file may contain a real project name, organization identifier, person's name, absolute filesystem path, or real email address. Examples use `my-app`, `TASK-1`, `tests/`, `pytest`. The one permitted real-world identifier is this repository's own owner handle and name, which installation instructions cannot work without.
- **`core/` is harness-neutral.** Files under `core/` must never contain the words `claude`, `cursor`, `anthropic`, a harness variable such as `${CLAUDE_PLUGIN_ROOT}`, or a harness tool name (`Agent` tool, `Task` tool). Core says "dispatch a subagent", never which tool does it.
- **`.import/` is gitignored** and must never be committed. It holds the inherited prompts used as porting source.
- **Commit trailer is empty.** Commits in this repo carry no `Co-Authored-By` line.
- **Every task ends green:** `./tests/run.sh` passes before the commit that closes a task.
- Paths in this plan are relative to the repository root.

---

### Task 1: Repository skeleton, test harness, and invariant checkers

Establishes the safety net every later task depends on. Nothing else can be reviewed until the checkers exist, because "did this file leak something" is not a judgement a reviewer should make by eye.

**Files:**
- Create: `.gitignore`
- Create: `checks/manifest.txt`
- Create: `checks/structure.sh`
- Create: `checks/no-leakage.sh`
- Create: `checks/core-is-neutral.sh`
- Create: `checks/references-resolve.sh`
- Test: `tests/run.sh`
- Test: `tests/fixtures/` (sample files that must fail each checker)

**Interfaces:**
- Produces:
  - `checks/manifest.txt` — one record per required file: `<path>|<required heading>;<required heading>;…`. Later tasks add a line here *before* writing the file.
  - `checks/structure.sh [manifest]` — exit 0 if every manifest path exists and contains each of its required headings; exit 1 with the first failure named.
  - `checks/no-leakage.sh [path…]` — exit 1 if any scanned file matches a leak pattern. Literal names come from the file at `$AGENT_PIPELINE_DENYLIST` when set; structural patterns are built in.
  - `checks/core-is-neutral.sh` — exit 1 if any file under `core/` contains a harness token.
  - `checks/references-resolve.sh` — exit 1 if any file references a `core/…md` path that does not exist.
  - `tests/run.sh` — runs the whole suite, prints `PASS`/`FAIL` per case, exits non-zero on any failure.

- [ ] **Step 1: Create the test runner with its first failing case**

`tests/run.sh` is a dependency-free runner. Write it with one case that asserts `checks/structure.sh` exists and is executable.

```bash
#!/usr/bin/env bash
# Test runner. No dependencies beyond coreutils and git.
set -uo pipefail
cd "$(dirname "$0")/.."

PASS=0; FAIL=0

assert_exit() { # <expected> <description> <cmd…>
  local expected="$1" desc="$2"; shift 2
  "$@" >/tmp/ap-test-out 2>&1
  local actual=$?
  if [ "$actual" = "$expected" ]; then
    printf 'PASS  %s\n' "$desc"; PASS=$((PASS+1))
  else
    printf 'FAIL  %s (expected exit %s, got %s)\n' "$desc" "$expected" "$actual"
    sed 's/^/      /' /tmp/ap-test-out; FAIL=$((FAIL+1))
  fi
}

assert_executable() { # <path> <description>
  if [ -x "$1" ]; then printf 'PASS  %s\n' "$2"; PASS=$((PASS+1))
  else printf 'FAIL  %s (not executable: %s)\n' "$2" "$1"; FAIL=$((FAIL+1)); fi
}

assert_executable checks/structure.sh "structure checker is executable"

printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
```

- [ ] **Step 2: Run it to verify it fails**

Run: `chmod +x tests/run.sh && ./tests/run.sh`
Expected: `FAIL  structure checker is executable`, exit 1.

- [ ] **Step 3: Write the structure checker**

```bash
#!/usr/bin/env bash
# Verifies every file listed in the manifest exists and has its required headings.
# Manifest format, one record per line:  <path>|<heading>;<heading>;…
set -uo pipefail
cd "$(dirname "$0")/.."
MANIFEST="${1:-checks/manifest.txt}"
rc=0

while IFS='|' read -r path headings; do
  case "$path" in ''|'#'*) continue ;; esac
  if [ ! -f "$path" ]; then
    printf 'missing file: %s\n' "$path"; rc=1; continue
  fi
  [ -z "${headings:-}" ] && continue
  IFS=';' read -ra required <<< "$headings"
  for h in "${required[@]}"; do
    [ -z "$h" ] && continue
    if ! grep -qF "$h" "$path"; then
      printf 'missing heading in %s: %s\n' "$path" "$h"; rc=1
    fi
  done
done < "$MANIFEST"

exit $rc
```

Create an empty `checks/manifest.txt` containing only a comment header:

```
# <path>|<required heading>;<required heading>;…
# Add the line for a file BEFORE writing the file, so the check fails first.
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `chmod +x checks/structure.sh && ./tests/run.sh`
Expected: `1 passed, 0 failed`.

- [ ] **Step 5: Add failing cases for the three remaining checkers**

Append to `tests/run.sh`, before the summary block:

```bash
assert_executable checks/no-leakage.sh      "leakage checker is executable"
assert_executable checks/core-is-neutral.sh "neutrality checker is executable"
assert_executable checks/references-resolve.sh "reference checker is executable"

# Fixtures: each must be rejected by its checker.
assert_exit 1 "leakage checker rejects an absolute home path" \
  checks/no-leakage.sh tests/fixtures/leak-abs-path.md
assert_exit 1 "leakage checker rejects an email address" \
  checks/no-leakage.sh tests/fixtures/leak-email.md
assert_exit 0 "leakage checker accepts a clean file" \
  checks/no-leakage.sh tests/fixtures/clean.md
assert_exit 1 "neutrality checker rejects a harness token in core" \
  checks/core-is-neutral.sh tests/fixtures/core-dirty
assert_exit 0 "neutrality checker accepts neutral prose" \
  checks/core-is-neutral.sh tests/fixtures/core-clean
assert_exit 1 "reference checker rejects a dangling core reference" \
  checks/references-resolve.sh tests/fixtures/dangling.md
```

- [ ] **Step 6: Run tests to verify the new cases fail**

Run: `./tests/run.sh`
Expected: six FAIL lines, exit 1.

- [ ] **Step 7: Write the fixtures**

```bash
mkdir -p tests/fixtures/core-dirty tests/fixtures/core-clean
printf 'See /home/someuser/projects/thing for details.\n' > tests/fixtures/leak-abs-path.md
printf 'Contact person@example-company.com about this.\n'   > tests/fixtures/leak-email.md
printf 'Run the configured test command against `tests/`.\n' > tests/fixtures/clean.md
printf 'Dispatch a subagent with the Agent tool.\n'          > tests/fixtures/core-dirty/phase.md
printf 'Dispatch a subagent for this phase.\n'               > tests/fixtures/core-clean/phase.md
printf 'Follow core/phases/does-not-exist.md for details.\n' > tests/fixtures/dangling.md
```

- [ ] **Step 8: Write the leakage checker**

```bash
#!/usr/bin/env bash
# Rejects real-world identifiers. Structural patterns are built in; literal
# names come from $AGENT_PIPELINE_DENYLIST (one lowercase literal per line).
set -uo pipefail
cd "$(dirname "$0")/.."

targets=("$@")
if [ ${#targets[@]} -eq 0 ]; then
  mapfile -t targets < <(git ls-files)
fi

# Structural: absolute home paths and email addresses.
# Repository-owner handles are deliberately NOT matched: installation
# instructions cannot work without naming this repository.
patterns=(
  '/home/[A-Za-z0-9._-]+/'
  '/Users/[A-Za-z0-9._-]+/'
  '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}'
)

rc=0
for f in "${targets[@]}"; do
  [ -f "$f" ] || continue
  case "$f" in checks/no-leakage.sh|tests/run.sh|tests/fixtures/*) [ $# -gt 0 ] || continue ;; esac
  for p in "${patterns[@]}"; do
    if grep -nEI "$p" "$f" >/tmp/ap-leak 2>/dev/null; then
      printf 'leak in %s:\n' "$f"; sed 's/^/  /' /tmp/ap-leak; rc=1
    fi
  done
  if [ -n "${AGENT_PIPELINE_DENYLIST:-}" ] && [ -f "$AGENT_PIPELINE_DENYLIST" ]; then
    if grep -nIiFf "$AGENT_PIPELINE_DENYLIST" "$f" >/tmp/ap-leak 2>/dev/null; then
      printf 'denylisted term in %s:\n' "$f"; sed 's/^/  /' /tmp/ap-leak; rc=1
    fi
  fi
done
exit $rc
```

Note the self-exemption: when scanning the whole tree, this script, the runner, and the fixtures are skipped, because they legitimately contain the patterns they detect. When a path is passed explicitly, nothing is skipped.

- [ ] **Step 9: Write the neutrality checker**

```bash
#!/usr/bin/env bash
# Files under core/ must not name a harness, a harness variable, or a harness tool.
set -uo pipefail
cd "$(dirname "$0")/.."
ROOT="${1:-core}"
[ -d "$ROOT" ] || exit 0

tokens='claude|cursor|anthropic|CLAUDE_PLUGIN_ROOT|CLAUDE\.md|\bAgent tool\b|\bTask tool\b|\.cursor/'
rc=0
while IFS= read -r f; do
  if grep -nEiI "$tokens" "$f" >/tmp/ap-neutral 2>/dev/null; then
    printf 'harness token in %s:\n' "$f"; sed 's/^/  /' /tmp/ap-neutral; rc=1
  fi
done < <(find "$ROOT" -type f -name '*.md')
exit $rc
```

- [ ] **Step 10: Write the reference checker**

```bash
#!/usr/bin/env bash
# Every core/…md path mentioned anywhere must exist.
set -uo pipefail
cd "$(dirname "$0")/.."

targets=("$@")
if [ ${#targets[@]} -eq 0 ]; then mapfile -t targets < <(git ls-files '*.md'); fi

rc=0
for f in "${targets[@]}"; do
  [ -f "$f" ] || continue
  while IFS= read -r ref; do
    [ -f "$ref" ] || { printf 'dangling reference in %s: %s\n' "$f" "$ref"; rc=1; }
  done < <(grep -oE 'core/[A-Za-z0-9._/-]+\.md' "$f" | sort -u)
done
exit $rc
```

- [ ] **Step 11: Run tests to verify all cases pass**

Run: `chmod +x checks/*.sh && ./tests/run.sh`
Expected: `10 passed, 0 failed`.

- [ ] **Step 12: Write `.gitignore` and stage the porting source**

```
.import/
/tmp/
```

Then stage the inherited prompts locally. `$IMPORT_SRC` is the inherited pipeline's agent directory — the operator supplies it; it is never written into a tracked file:

```bash
mkdir -p .import
cp "$IMPORT_SRC"/agents/*.md   .import/
cp "$IMPORT_SRC"/commands/*.md .import/
cp "$IMPORT_SRC"/review-checklist.md .import/ 2>/dev/null || true
git status --short   # must show nothing under .import/
```

- [ ] **Step 13: Commit**

```bash
git add .gitignore checks tests
git commit -m "Add repository invariant checkers and test runner"
```

---

### Task 2: Contract — pipeline configuration

**Files:**
- Create: `core/contracts/pipeline-config.md`
- Modify: `checks/manifest.txt`

**Interfaces:**
- Produces: the normative `pipeline.yaml` schema. Every phase and flow cites this file rather than restating keys.

- [ ] **Step 1: Add the manifest line (the failing test)**

Append to `checks/manifest.txt`:

```
core/contracts/pipeline-config.md|## Schema;## Required keys by mode;## Fail-fast protocol
```

- [ ] **Step 2: Run tests to verify failure**

Run: `./tests/run.sh`
Expected: `FAIL` with `missing file: core/contracts/pipeline-config.md`.

- [ ] **Step 3: Write the contract**

Content requirements — the file must contain, under those three headings:

1. `## Schema` — the complete annotated YAML from the design doc's "Configuration contract" section, copied verbatim, including the `my-app` / `TASK-1` example values and the comment markers for optional keys.
2. `## Required keys by mode` — a table: which keys are mandatory always, which only when `tracker.type` is `linear` (`team`, `states`), which only when it is `github`, and which are optional in every mode (`commands.typecheck`, `paths.review_checklist`, `git.worktree_setup`).
3. `## Fail-fast protocol` — the exact behaviour: read `.claude/pipeline.yaml` at step 0; if the file is absent, stop and instruct the user to run the init flow; if a key this phase will use is absent, stop and name that key; never infer a command from a package manifest, build file, or directory listing. Include the exact stop message template:

```
Cannot start: `.claude/pipeline.yaml` is missing key `commands.test`.
Add it, or run the init flow to regenerate the configuration.
```

State that the config path stays `.claude/pipeline.yaml` regardless of harness, because it is the pipeline's own directory.

- [ ] **Step 4: Run tests to verify they pass**

Run: `./tests/run.sh && checks/no-leakage.sh && checks/core-is-neutral.sh`
Expected: all pass, exit 0.

- [ ] **Step 5: Commit**

```bash
git add core/contracts/pipeline-config.md checks/manifest.txt
git commit -m "Add pipeline configuration contract"
```

---

### Task 3: Contract — project requirements

**Files:**
- Create: `core/contracts/project-requirements.md`
- Modify: `checks/manifest.txt`

**Interfaces:**
- Consumes: `core/contracts/pipeline-config.md` (referenced, not restated).
- Produces: the normative requirements table that the init, conventions, and doctor flows all cite.

- [ ] **Step 1: Add the manifest line**

```
core/contracts/project-requirements.md|## Requirements;## Why a populated conventions file is mandatory
```

- [ ] **Step 2: Run tests to verify failure**

Run: `./tests/run.sh`
Expected: `missing file: core/contracts/project-requirements.md`.

- [ ] **Step 3: Write the contract**

Under `## Requirements`, reproduce the nine-row table from the design doc's "Project requirements and their bootstrap" section, with the columns Requirement / Required / Created by / Validated by. Refer to flows by name (`init`, `conventions`, `doctor`) without a leading slash or harness prefix, since core is harness-neutral.

Under `## Why a populated conventions file is mandatory`, state the failure mode in full: the execute and code-review phases delegate rule enforcement to the project's conventions file, so an empty file means they enforce nothing while still reporting success — a silent pass, which is worse than a hard failure. Therefore a conventions file that exists but holds no rules is a **fail** in the doctor flow, not a pass. Define "holds no rules" concretely: fewer than five list items or headings beneath the managed-section marker.

- [ ] **Step 4: Run tests to verify they pass**

Run: `./tests/run.sh && checks/references-resolve.sh`
Expected: exit 0.

- [ ] **Step 5: Commit**

```bash
git add core/contracts/project-requirements.md checks/manifest.txt
git commit -m "Add project requirements contract"
```

---

### Task 4: Contracts — task spec template and handoff log protocol

These two ship together: the handoff log is a section of the spec, and a reviewer judging one needs the other in the same diff.

**Files:**
- Create: `core/contracts/spec-template.md`
- Create: `core/contracts/handoff-log.md`
- Modify: `checks/manifest.txt`
- Source: `.import/task-start.md`, `.import/plan.md` (spec shape); the inherited conventions file sections named "Task Spec Completeness", "Task Subtask Structure", "Agent Handoff Log", "Memory & Notes"

**Interfaces:**
- Produces:
  - `spec-template.md` — the exact section skeleton every task spec follows: `# <ID> — <Title>`, `## Context`, `## Approach`, `## Files to Modify`, `## Definition of Done`, `## Out of Scope`, `## Agent Handoff Log`.
  - `handoff-log.md` — the entry format, the read-before-write rule, and the escalation routing table.

- [ ] **Step 1: Add the manifest lines**

```
core/contracts/spec-template.md|## Skeleton;## Completeness rules;## Subtask structure
core/contracts/handoff-log.md|## Format;## Reading;## Writing;## Escalation routing
```

- [ ] **Step 2: Run tests to verify failure**

Run: `./tests/run.sh`
Expected: two `missing file:` lines.

- [ ] **Step 3: Write `spec-template.md`**

`## Skeleton` — the literal Markdown skeleton, in a fenced block, with `TASK-1` as the example ID.

`## Completeness rules` — port the generic rules from the inherited "Task Spec Completeness" section, dropping every stack-specific example. Keep exactly these, reworded to be domain-neutral:

- A spec is fully self-contained. The phase that implements it has no memory of the planning conversation: every data source, field name, resolution chain, file path, and integration detail is written out explicitly.
- Document data resolution chains end to end, naming each store, collection, or table and the field that links to the next hop.
- Definition of Done items reference the applicable convention explicitly. The execute phase follows the DoD literally and does not re-derive conventions.
- A field added to a response shape is wired end to end in the same task. A field with a default value passes validation while always returning the default — a silent failure.
- **External API schema verification is a hard blocker, not a deferral.** Every request and response field name, type, enum value, and required flag is confirmed against the provider's reference documentation before the spec is approved. Writing "verify before implementing" in a spec is a deferral; the review flow rejects specs containing one. If the documentation is unavailable, stop and surface it — never invent a plausible shape.
- **Internal data model verification is equally blocking.** When a spec claims existing infrastructure ("extend the existing endpoint", "reuse collection X"), locate it before approval. Invert the question: do not ask whether the spec's invented name exists — zero matches for an invented name proves nothing by construction. Ask where the *concept* lives today, search the whole repository rather than the subtree you expect, and treat existing production readers as ground truth for field names.
- **Adding a value to a status enum is a multi-site change.** Cover every category before approving: read schemas exposing the column, client-side type unions, aggregation and dashboard builders, "block on terminal status" call sites, state-transition maps in synchronization code, and filter and badge maps in the interface.

`## Subtask structure` — each subtask gets its own spec file (`TASK-1-1.md`) and its own tracker item parented to the original; the parent file becomes an index, not full detail; the execute phase works from exactly one spec file.

- [ ] **Step 4: Write `handoff-log.md`**

`## Format` — a fenced example:

```markdown
## Agent Handoff Log

### <phase-name> (YYYY-MM-DD)
- Finding or note
- Another finding
```

`## Reading` — before starting, every phase reads the log for warnings, mock patterns, fixture constraints, and deviation explanations left by earlier phases.

`## Writing` — before finishing, every phase appends a dated subsection covering: warnings about tricky areas, mock and fixture patterns the next phase needs, deviations from the spec and why, and critical constraints stated concretely ("changing this identifier breaks six tests").

`## Escalation routing` — the routing table, harness-neutral:

| What was learned | Where it goes |
|---|---|
| Project convention: pattern, naming, command, path, contract | the file at `paths.conventions` |
| Phase-workflow learning | `.claude/agent-memory/<phase>/` |
| Detail specific to this task only | this handoff log |
| Personal communication preference | the operator's own memory, outside the repository |

State the hard rule: project conventions never go to personal memory, because they are invisible to teammates; when in doubt, the conventions file wins. Note the escalation in the log as `→ Escalated to conventions: <summary>`.

- [ ] **Step 5: Run tests to verify they pass**

Run: `./tests/run.sh && checks/core-is-neutral.sh && checks/no-leakage.sh`
Expected: exit 0. The neutrality checker is the guard that catches a stack-specific example surviving the port.

- [ ] **Step 6: Commit**

```bash
git add core/contracts/spec-template.md core/contracts/handoff-log.md checks/manifest.txt
git commit -m "Add spec template and handoff log contracts"
```

---

### Task 5: Contracts — conventions template and review checklist base

**Files:**
- Create: `core/contracts/conventions-template.md`
- Create: `core/contracts/review-checklist-base.md`
- Modify: `checks/manifest.txt`
- Source: `.import/review-checklist.md` (for the shape; every stack-specific item is dropped)

**Interfaces:**
- Produces:
  - `conventions-template.md` — the managed-section markers and the area headings the conventions flow fills in.
  - `review-checklist-base.md` — the stack-agnostic checklist seed the conventions flow extends with derived rules.

- [ ] **Step 1: Add the manifest lines**

```
core/contracts/conventions-template.md|## Managed section markers;## Area headings
core/contracts/review-checklist-base.md|## Security;## Correctness;## Tests;## Data and migrations
```

- [ ] **Step 2: Run tests to verify failure**

Run: `./tests/run.sh`
Expected: two `missing file:` lines.

- [ ] **Step 3: Write `conventions-template.md`**

`## Managed section markers` — define the exact markers, so a re-run rewrites only what it owns:

```markdown
<!-- pipeline:conventions:start -->
... generated rules ...
<!-- pipeline:conventions:end -->
```

State the rule: the conventions flow replaces only the text between the markers; prose outside them is hand-written and never touched. If the markers are absent, the flow appends them at the end of the file rather than rewriting it.

`## Area headings` — the headings the generated block uses, in order: Module boundaries and layering; Error handling; Naming; Authentication and authorization; Data access; Testing; Formatting and lint. Each rule is one line, imperative, with a `file:line` citation of the evidence it was derived from.

- [ ] **Step 4: Write `review-checklist-base.md`**

Four sections, each a checkbox list. Every item must hold for any stack:

`## Security` — new entry points carry an authorization check; input from outside the system is validated before use; no secrets, tokens, or credentials in source or fixtures; data scoped to one tenant, user, or account cannot be reached from another.

`## Correctness` — error paths return the documented error, not a sentinel value; every branch stated in the Definition of Done exists in the code; values representing money use an exact decimal type, never a binary float; a timestamp mirroring an external event is read from that system's payload, never generated locally at observation time.

`## Tests` — every Definition of Done item maps to at least one test; error and permission paths are covered, not only the happy path; tests are independent and clean up after themselves; no production code exists solely to make a test pass.

`## Data and migrations` — a schema change ships with its migration; a new non-nullable column has a default or a backfill; a migration is reversible or its irreversibility is stated explicitly.

- [ ] **Step 5: Run tests to verify they pass**

Run: `./tests/run.sh && checks/core-is-neutral.sh`
Expected: exit 0.

- [ ] **Step 6: Commit**

```bash
git add core/contracts/conventions-template.md core/contracts/review-checklist-base.md checks/manifest.txt
git commit -m "Add conventions template and review checklist base"
```

---

### Task 6: Tracker layer

**Files:**
- Create: `core/trackers/none.md`
- Create: `core/trackers/linear.md`
- Create: `core/trackers/github.md`
- Modify: `checks/manifest.txt`

**Interfaces:**
- Produces: three files with an identical two-operation interface, so the task and end flows call the same thing regardless of mode.
  - `resolve_or_create(argument) -> task_id` — given a tracker ID or a free-text description, return the canonical task ID used as branch name and spec filename.
  - `set_status(task_id, phase)` where `phase` is `start` or `review`.

- [ ] **Step 1: Add the manifest lines**

```
core/trackers/none.md|## resolve_or_create;## set_status
core/trackers/linear.md|## resolve_or_create;## set_status
core/trackers/github.md|## resolve_or_create;## set_status
```

- [ ] **Step 2: Run tests to verify failure**

Run: `./tests/run.sh`
Expected: three `missing file:` lines.

- [ ] **Step 3: Write `none.md`**

`resolve_or_create`: if the argument matches `<prefix>-<number>`, that is the ID. Otherwise derive the next free ID by scanning `paths.specs` for existing `<prefix>-<n>.md` files and taking the highest `n` plus one; confirm the derived ID with the user before using it. No external calls.

`set_status`: no operation. Report "tracker: none, no status update" so the end phase's report stays uniform across modes.

- [ ] **Step 4: Write `linear.md`**

`resolve_or_create`: when the argument matches the ID pattern, fetch that issue and use its identifier and description; when it is free text, ask the user for project and priority in a single question, then create the issue on the team named by `tracker.team`, assigned to the current user, and use the returned identifier.

`set_status`: move the issue to `tracker.states.start` or `tracker.states.review`. If the configured state name does not exist on the team, stop and list the available states rather than guessing a near match.

State that Linear operations go through the Linear MCP server, and that if it is unavailable the flow stops with an actionable message instead of degrading to `none` — silently losing tracker updates is worse than failing.

- [ ] **Step 5: Write `github.md`**

`resolve_or_create`: an argument like `#123` or `123` resolves via `gh issue view <n> --json number,title,body`. Free text creates one via `gh issue create --title <t> --body <b>`. The task ID is `<prefix>-<number>` so branch names stay uniform across modes.

`set_status`: apply a label rather than a state — `gh issue edit <n> --add-label "<states.start>"`, removing the other pipeline label. If the label does not exist, create it first.

- [ ] **Step 6: Run tests to verify they pass**

Run: `./tests/run.sh && checks/core-is-neutral.sh && checks/no-leakage.sh`
Expected: exit 0. Note `gh` is a general-purpose tool, not a harness token, so it is allowed in core.

- [ ] **Step 7: Commit**

```bash
git add core/trackers checks/manifest.txt
git commit -m "Add pluggable tracker layer"
```

---

### Task 7: Phase — test (red)

**Files:**
- Create: `core/phases/test.md`
- Modify: `checks/manifest.txt`
- Source: `.import/task-test.md`

**Interfaces:**
- Consumes: `core/contracts/pipeline-config.md`, `core/contracts/handoff-log.md`, `core/contracts/spec-template.md`.
- Produces: a committed failing test suite plus a handoff log entry; returns a report of at most 300 characters.

- [ ] **Step 1: Add the manifest line**

```
core/phases/test.md|## Step 0 — Load configuration;## Step 1 — Load the spec;## Step 2 — Study existing test patterns;## Step 3 — Design the test plan;## Step 4 — Write the tests;## Step 5 — Verify the tests fail;## Step 6 — Handoff log;## Step 7 — Commit;## Step 8 — Report
```

- [ ] **Step 2: Run tests to verify failure**

Run: `./tests/run.sh`
Expected: `missing file: core/phases/test.md`.

- [ ] **Step 3: Port the phase**

Start from `.import/task-test.md`. **Keep**, rewritten to be stack-neutral: the core principle that tests define the contract and not the implementation; the mandatory study of existing test patterns before writing anything; the test-plan dimensions (happy path, validation errors, not-found, authorization, edge cases, side effects, isolation between accounts or tenants); the quality standards (descriptive names, independence, external dependencies mocked, no superficial assertions, no testing of internals); the red-phase verification; the handoff log entry with escalation; the commit; and the report cap.

**Delete entirely:** the named test framework and assertion library, the mocking recipes with concrete patch targets, the test directory paths, the list-endpoint pagination convention, and every example drawn from a specific domain.

**Parameterize:**
- Test command → `commands.test` with `{target}` substituted; full suite → `commands.test_all`.
- Test locations → `paths.tests`.
- Spec path → `paths.specs/<task-id>.md`.
- Commit trailer → `git.commit_trailer`, omitted when empty.

Add to `## Step 2` an instruction absent from the source: read the file at `paths.conventions` and follow its testing section; if it has no testing rules, say so in the handoff log so the conventions flow can fill the gap. This is half of the mitigation for the pointer-versus-inline risk.

`## Step 8 — Report` states the exact shape:

```
Tests: <path>. <N> tests written. Status: fail (red). Committed: yes.
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `./tests/run.sh && checks/core-is-neutral.sh && checks/no-leakage.sh && checks/references-resolve.sh`
Expected: exit 0.

- [ ] **Step 5: Commit**

```bash
git add core/phases/test.md checks/manifest.txt
git commit -m "Add red phase"
```

---

### Task 8: Phase — execute (green)

**Files:**
- Create: `core/phases/execute.md`
- Modify: `checks/manifest.txt`
- Source: `.import/task-execute.md`

**Interfaces:**
- Consumes: the handoff log written by the test phase; `core/contracts/pipeline-config.md`.
- Produces: committed implementation, a handoff log entry containing an `### Implementation Manifest` and a `### Conventions Applied` block, and a report of at most 300 characters.

- [ ] **Step 1: Add the manifest line**

```
core/phases/execute.md|## Step 0 — Load configuration;## Step 1 — Read the handoff log;## Step 2 — Plan before editing;## Step 3 — Load project conventions;## Step 4 — Test protection contract;## Step 5 — Implement;## Step 6 — Self-review;## Step 7 — Verification loop;## Step 8 — Lint gate;## Step 9 — Handoff log;## Step 10 — Commit;## Step 11 — Report
```

- [ ] **Step 2: Run tests to verify failure**

Run: `./tests/run.sh`
Expected: `missing file: core/phases/execute.md`.

- [ ] **Step 3: Port the phase**

**Keep**, rewritten stack-neutral: intake and Definition of Done mapping; explore-before-editing (never guess file locations, mirror analogous files); the handoff log read; the **test protection contract** verbatim in substance — never modify an existing assertion to make the implementation pass, never delete a test, never weaken a condition, may add tests, may fix genuine infrastructure bugs in tests, and when a test appears wrong document the conflict in the handoff log instead of changing it silently; critic-style self-review after each chunk; the per-DoD verification loop; the mandatory lint gate; the commit with explicit file staging; and the report cap.

**Delete entirely:** the architecture compliance block, the language version and syntax rules, the named lint and type-check tools, the migration commands, and the frontend-specific rules.

**Parameterize:** test, lint, and type-check commands from `commands.*`; migrations become "if the task changes the schema, follow the migration procedure documented at `paths.conventions`; if none is documented, stop and ask".

`## Step 3 — Load project conventions` is new and load-bearing. Read `paths.conventions` and, for each area the task touches, extract the applicable rules. Record them in the handoff log as:

```markdown
### Conventions Applied
- <rule text> — conventions:<line>  → applied at <file>:<line>
- No rule found covering <area> — flagging for review
```

Explicitly state that a "no rule found" line is not a failure; concealing it is. This block is what the code-review phase verifies.

`## Step 11 — Report`:

```
Implemented: <summary>. Tests: pass (<N>). Lint: clean. Committed: yes.
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `./tests/run.sh && checks/core-is-neutral.sh && checks/no-leakage.sh`
Expected: exit 0.

- [ ] **Step 5: Commit**

```bash
git add core/phases/execute.md checks/manifest.txt
git commit -m "Add green phase"
```

---

### Task 9: Phase — code review

**Files:**
- Create: `core/phases/code-review.md`
- Modify: `checks/manifest.txt`
- Source: `.import/task-code-review.md`

**Interfaces:**
- Consumes: the `### Implementation Manifest` and `### Conventions Applied` blocks from the execute phase; `paths.review_checklist` when configured.
- Produces: a handoff log entry and a verdict line of at most 500 characters, one of `APPROVED`, `APPROVED_WITH_WARNINGS`, `CHANGES_REQUESTED`.

- [ ] **Step 1: Add the manifest line**

```
core/phases/code-review.md|## Step 0 — Load configuration;## Step 1 — Load context;## Step 2 — Read the full diff;## Step 3 — Review dimensions;## Step 4 — Classify findings;## Step 5 — Handoff log;## Step 6 — Commit;## Step 7 — Verdict
```

- [ ] **Step 2: Run tests to verify failure**

Run: `./tests/run.sh`
Expected: `missing file: core/phases/code-review.md`.

- [ ] **Step 3: Port the phase**

`## Step 3 — Review dimensions` keeps five subsections, all stack-neutral:

1. **Spec compliance** — every Definition of Done item satisfied; deviations present in the handoff log and justified; nothing from the spec missing.
2. **Conventions** — read `paths.conventions`, then verify the execute phase's `### Conventions Applied` block: spot-check that each cited rule exists at the cited line and that the code does what the rule says. Every "no rule found" line becomes a warning naming the uncovered area. A missing block is itself a warning.
3. **Security and isolation** — authorization on new entry points, input validation, data reachable across account boundaries, secrets in source.
4. **Test integrity** — the highest-value gate, kept in full. Determine which commits touched test files. If the execute phase modified tests written by the test phase, diff those files and verify no assertion was weakened, no test deleted, and no expected value changed to match the implementation. Adding tests and fixing genuine infrastructure bugs are acceptable. **Any unjustified test modification is a blocker.** If the execute phase flagged a test as wrong, evaluate the claim on its merits.
5. **Checklist verification** — read the `### Implementation Manifest`, spot-check two or three claims against the code, then scan `paths.review_checklist` for items relevant to this change that the manifest does not mention and verify those directly. This replaces reading every file.

`## Step 4` keeps the three severities: blocker (must fix — security holes, data leaks, spec violations, weakened tests), warning (should fix), suggestion.

`## Step 7 — Verdict`:

```
Verdict: <APPROVED|APPROVED_WITH_WARNINGS|CHANGES_REQUESTED>. Blockers: <list|none>. Warnings: <list|none>.
```

**Delete:** every layer-specific and framework-specific rule list, the named directories, and the migration specifics beyond the generic checklist items.

- [ ] **Step 4: Run tests to verify they pass**

Run: `./tests/run.sh && checks/core-is-neutral.sh && checks/no-leakage.sh`
Expected: exit 0.

- [ ] **Step 5: Commit**

```bash
git add core/phases/code-review.md checks/manifest.txt
git commit -m "Add code review phase"
```

---

### Task 10: Phase — end (ship)

**Files:**
- Create: `core/phases/end.md`
- Modify: `checks/manifest.txt`
- Source: `.import/task-end.md`

**Interfaces:**
- Consumes: `core/trackers/<type>.md` for `set_status`; `commands.lint`; `pr.enabled`.
- Produces: pushed branch, opened pull request, updated tracker status, and a report naming what was persisted to the conventions file.

- [ ] **Step 1: Add the manifest line**

```
core/phases/end.md|## Step 0 — Load configuration;## Step 1 — Detect changed areas;## Step 2 — Lint;## Step 3 — Persist durable discoveries;## Step 4 — Commit and push;## Step 5 — Open the pull request;## Step 6 — Update tracker status;## Step 7 — Report;## Step 8 — Worktree cleanup hint
```

- [ ] **Step 2: Run tests to verify failure**

Run: `./tests/run.sh`
Expected: `missing file: core/phases/end.md`.

- [ ] **Step 3: Port the phase**

`## Step 3 — Persist durable discoveries` is kept in full and reworded — it is the highest-leverage step in the phase. The reasoning to preserve: spec files and handoff logs are not read in future sessions, only the conventions file is, so any durable project fact discovered during the task is lost the moment the task closes and the next session re-derives it, slowly and often wrongly. For each finding, ask whether it is a durable project fact not already present in the conventions file; if so append it to the most relevant section, matching the file's existing style. Route per the handoff log contract: project facts to the conventions file, workflow learnings to phase memory, task-only detail stays in the log. When nothing durable was found, say so explicitly in the report rather than skipping silently. This step runs **before** the commit so the conventions edit ships in the same commit.

`## Step 5` — skip when the current branch is `git.base_branch`, when `pr.enabled` is false, or when a pull request already exists. The body carries a summary, the Definition of Done checklist from the spec, and a test plan.

`## Step 8` — emit the cleanup commands for `paths.worktrees/<task-id>`, to be run after the pull request merges, and state that the worktree is deliberately preserved until then so review feedback can be addressed.

**Parameterize:** lint invocation from `commands.lint`, skipped when nothing in its scope changed; commit trailer from `git.commit_trailer`, omitted when empty; base branch from `git.base_branch`.

- [ ] **Step 4: Run tests to verify they pass**

Run: `./tests/run.sh && checks/core-is-neutral.sh && checks/no-leakage.sh`
Expected: exit 0.

- [ ] **Step 5: Commit**

```bash
git add core/phases/end.md checks/manifest.txt
git commit -m "Add ship phase"
```

---

### Task 11: Phase — pipeline orchestration

**Files:**
- Create: `core/phases/pipeline.md`
- Modify: `checks/manifest.txt`
- Source: `.import/task-isolate-start.md`

**Interfaces:**
- Consumes: all four phase files.
- Produces: a result of `SHIPPED`, `STOPPED`, or `BLOCKED`, with branch name, pull request URL, and worktree path.

- [ ] **Step 1: Add the manifest line**

```
core/phases/pipeline.md|## Step 0 — Load configuration;## Step 1 — Verify the working directory;## Step 2 — Prepare dependencies;## Step 3 — Run the phases;## Step 4 — Report
```

- [ ] **Step 2: Run tests to verify failure**

Run: `./tests/run.sh`
Expected: `missing file: core/phases/pipeline.md`.

- [ ] **Step 3: Write the orchestrator**

`## Step 1 — Verify the working directory` — the portable guard. The orchestrator must be running inside the worktree the task flow created, never the main repository:

```bash
TOP=$(git rev-parse --show-toplevel)
COMMON=$(git rev-parse --path-format=absolute --git-common-dir)
if [ "$TOP" = "$(dirname "$COMMON")" ]; then
  echo "Refusing to run: this is the main repository, not a task worktree."
  exit 1
fi
git branch --show-current   # must equal <task-id>
```

State that on failure the phase stops without editing anything, and reports that the task flow must create the worktree first.

`## Step 2 — Prepare dependencies` — when `git.worktree_setup` is configured, run it and stop on a non-zero exit.

`## Step 3 — Run the phases` — dispatch each phase as a **fresh subagent** from this context, in order: test, execute, code-review, end. Never inline a phase into this context; the fresh context is what keeps each phase's reasoning uncontaminated and what makes the phases resumable. Do not create nested worktrees — the phases inherit this working directory. Rules between phases:

- If the test phase reports no failing tests, stop with `BLOCKED` — a red phase that is already green means the tests do not describe new behaviour.
- Run the end phase only when the code-review verdict is `APPROVED` or `APPROVED_WITH_WARNINGS`. On `CHANGES_REQUESTED`, return `STOPPED` with the blocker list; do not loop back automatically, because an unattended fix loop against a rejected review is how a pipeline burns a branch.

`## Step 4 — Report` — result, branch, pull request URL, worktree path, and on a non-shipped result a one-line reason so the operator knows where to resume.

- [ ] **Step 4: Run tests to verify they pass**

Run: `./tests/run.sh && checks/core-is-neutral.sh && checks/references-resolve.sh`
Expected: exit 0.

- [ ] **Step 5: Commit**

```bash
git add core/phases/pipeline.md checks/manifest.txt
git commit -m "Add pipeline orchestration"
```

---

### Task 12: Flows — task, review, resume

**Files:**
- Create: `core/flows/task.md`
- Create: `core/flows/review.md`
- Create: `core/flows/resume.md`
- Modify: `checks/manifest.txt`
- Source: `.import/task-start.md`, `.import/plan.md`, `.import/task-review.md`, `.import/review-plan.md`

**Interfaces:**
- Consumes: tracker layer, spec template, pipeline orchestration.
- Produces: `task.md` is the single entry point; `review.md` is callable standalone and inline; `resume.md` re-enters a phase.

- [ ] **Step 1: Add the manifest lines**

```
core/flows/task.md|## Step 0 — Load configuration;## Step 1 — Resolve the item;## Step 2 — Write the spec;## Step 3 — Review the spec;## Step 4 — Gate;## Step 5 — Create the worktree;## Step 6 — Run the pipeline;## Step 7 — Report
core/flows/review.md|## Input;## Mindset;## Step 1 — Load context;## Step 2 — Explore;## Step 3 — Critique;## Step 4 — Fix the spec;## Step 5 — Handoff log
core/flows/resume.md|## Input;## Phase selection;## Preconditions;## Execution
```

- [ ] **Step 2: Run tests to verify failure**

Run: `./tests/run.sh`
Expected: three `missing file:` lines.

- [ ] **Step 3: Write `task.md`**

Steps 1 through 4 touch no source code. Step 1 delegates to the configured tracker's `resolve_or_create`. Step 2 explores the codebase and drafts the spec per `core/contracts/spec-template.md`, asking the user about scope, approach preferences, constraints, and affected user roles in a single grouped question rather than a decision tree; it commits the spec to `git.base_branch`, where specs belong.

Step 3 runs the review flow inline against the fresh spec. Step 4 is the gate: present the reviewed spec and the review findings, then ask whether to proceed. **This is a hard stop.** Stopping here leaves a reviewed, committed spec and nothing else — the plan-only path.

Step 5 creates the worktree with plain git:

```bash
git worktree add "<paths.worktrees>/<task-id>" -b "<task-id>" "<git.base_branch>"
```

Reuse an existing worktree at that path rather than recreating it; if it holds uncommitted work the flow did not create, stop and ask. Step 6 dispatches `core/phases/pipeline.md` as a subagent whose working directory is that worktree.

- [ ] **Step 4: Write `review.md`**

`## Mindset` — you did not write this spec. You are a skeptical fresh reader whose job is to find what the author missed, because the implementing phase follows the spec literally. Ask what could go wrong that is not covered, what existing code breaks, which assumptions are wrong, and what is missing from the Definition of Done.

`## Step 2 — Explore` — dispatch subagents in parallel over impact, existing patterns, and test coverage.

`## Step 3 — Critique` — apply the completeness rules from `core/contracts/spec-template.md`, especially the two hard blockers: unverified external API schemas and unverified claims about existing internal infrastructure. A spec containing "verify before implementing" is rejected, not annotated.

`## Step 4 — Fix the spec` — apply the findings to the spec file directly rather than only reporting them, then `## Step 5` records a `### review` entry in the handoff log. That entry is the precondition the task flow's gate checks.

- [ ] **Step 5: Write `resume.md`**

`## Input` — a task ID and an optional phase name (`test`, `execute`, `code-review`, `end`). With no phase, infer the next one from the handoff log: the phase after the last entry.

`## Preconditions` — the worktree for the task exists and the current branch matches the task ID; the spec exists and carries a `### review` entry. If the worktree is gone, recreate it from the existing remote branch rather than from the base branch, or the work already pushed is lost from view.

`## Execution` — dispatch that single phase as a subagent, then stop and report. Resume never chains into the following phases automatically: it is a recovery tool, and an operator reaching for it is already dealing with something that went wrong.

- [ ] **Step 6: Run tests to verify they pass**

Run: `./tests/run.sh && checks/core-is-neutral.sh && checks/references-resolve.sh && checks/no-leakage.sh`
Expected: exit 0.

- [ ] **Step 7: Commit**

```bash
git add core/flows/task.md core/flows/review.md core/flows/resume.md checks/manifest.txt
git commit -m "Add task, review, and resume flows"
```

---

### Task 13: Flows — init, conventions, doctor

**Files:**
- Create: `core/flows/init.md`
- Create: `core/flows/conventions.md`
- Create: `core/flows/doctor.md`
- Modify: `checks/manifest.txt`

**Interfaces:**
- Consumes: `core/contracts/project-requirements.md`, `core/contracts/pipeline-config.md`, `core/contracts/conventions-template.md`, `core/contracts/review-checklist-base.md`.
- Produces: a project that satisfies every requirement in the requirements table.

- [ ] **Step 1: Add the manifest lines**

```
core/flows/init.md|## Step 1 — Detect the stack;## Step 2 — Propose the configuration;## Step 3 — Create directories;## Step 4 — Worktree setup script;## Step 5 — Derive conventions;## Step 6 — Verify
core/flows/conventions.md|## Step 1 — Explore;## Step 2 — Rule versus occurrence;## Step 3 — Confirm with the user;## Step 4 — Write;## Step 5 — Derive the checklist;## Drift reporting
core/flows/doctor.md|## Checks;## Output;## Repair mode
```

- [ ] **Step 2: Run tests to verify failure**

Run: `./tests/run.sh`
Expected: three `missing file:` lines.

- [ ] **Step 3: Write `init.md`**

Detection inspects the repository for a package manifest, test runner, and linter, and **proposes** values — it never writes without confirmation. This is the only place auto-detection is permitted, precisely because a human reviews the result. Step 3 creates `paths.specs`, `paths.worktrees`, and `.claude/agent-memory/`, and adds the worktree path to `.gitignore` when missing. Step 4 proposes a setup script only when dependency directories are git-ignored, since otherwise a fresh worktree already works. Step 5 hands off to the conventions flow. Step 6 runs the doctor flow and prints its report, so init never claims success without verification.

- [ ] **Step 4: Write `conventions.md`**

Step 1 dispatches exploration subagents in parallel across: module boundaries and layering, error handling, naming, authentication and authorization, data access, test structure and mocking, formatting and lint.

`## Step 2 — Rule versus occurrence` is the quality bar: a pattern becomes a proposed rule only when it holds across multiple independent call sites. A single instance is reported as an observation. State why — a rule derived from one example is how a coincidence gets enforced on the whole codebase.

Step 3 presents rules grouped by area, each with its `file:line` evidence, and the user accepts, edits, or drops each group. Step 4 writes accepted rules between the managed-section markers from `core/contracts/conventions-template.md`, never touching prose outside them. Step 5 derives `paths.review_checklist`, seeded from `core/contracts/review-checklist-base.md` and extended with the accepted rules.

`## Drift reporting` — on a re-run against a populated file, report both directions: rules present in the file but no longer practiced in code, and practices in code with no rule. Never overwrite blindly.

- [ ] **Step 5: Write `doctor.md`**

`## Checks` — one entry per row of the requirements table, each reporting `pass`, `fail`, or `n/a`. Include the specific check that the conventions file is populated, using the threshold from the requirements contract: fewer than five rules beneath the managed-section marker is a `fail`, and the message must say so plainly rather than reporting a generic problem.

`## Output` — a table, then a one-line summary, then the exact command to fix the first failure.

`## Repair mode` — with a repair argument, offer to create each missing artifact, delegating to init or conventions. Never repair without confirmation.

- [ ] **Step 6: Run tests to verify they pass**

Run: `./tests/run.sh && checks/core-is-neutral.sh && checks/references-resolve.sh`
Expected: exit 0.

- [ ] **Step 7: Commit**

```bash
git add core/flows/init.md core/flows/conventions.md core/flows/doctor.md checks/manifest.txt
git commit -m "Add init, conventions, and doctor flows"
```

---

### Task 14: Claude Code adapter

**Files:**
- Create: `adapters/claude-code/.claude-plugin/plugin.json`
- Create: `.claude-plugin/marketplace.json`
- Create: `adapters/claude-code/agents/{task-pipeline,task-test,task-execute,task-code-review,task-end}.md`
- Create: `adapters/claude-code/commands/{init,conventions,doctor,task,review,resume}.md`
- Modify: `checks/manifest.txt`
- Test: `tests/run.sh`

**Interfaces:**
- Consumes: every file under `core/`.
- Produces: an installable plugin named `tdd-pipeline`.

- [ ] **Step 1: Add a failing adapter-coverage test**

Append to `tests/run.sh` before the summary:

```bash
assert_exit 0 "every core phase and flow has a Claude Code adapter" \
  checks/adapters-cover-core.sh claude-code
```

And add `checks/adapters-cover-core.sh`, which asserts that for every `core/phases/*.md` and `core/flows/*.md` there is at least one adapter file under `adapters/<harness>/` referencing it:

```bash
#!/usr/bin/env bash
set -uo pipefail
cd "$(dirname "$0")/.."
HARNESS="${1:?usage: adapters-cover-core.sh <harness>}"
DIR="adapters/$HARNESS"
[ -d "$DIR" ] || { printf 'missing adapter directory: %s\n' "$DIR"; exit 1; }
rc=0
while IFS= read -r core_file; do
  if ! grep -rqF "$core_file" "$DIR"; then
    printf 'no %s adapter references %s\n' "$HARNESS" "$core_file"; rc=1
  fi
done < <(find core/phases core/flows -name '*.md')
exit $rc
```

- [ ] **Step 2: Run tests to verify failure**

Run: `chmod +x checks/adapters-cover-core.sh && ./tests/run.sh`
Expected: `FAIL  every core phase and flow has a Claude Code adapter`.

- [ ] **Step 3: Write the plugin manifests**

`.claude-plugin/marketplace.json`:

```json
{
  "name": "agent-pipeline",
  "owner": { "name": "dfrnks" },
  "plugins": [
    {
      "name": "tdd-pipeline",
      "source": "./adapters/claude-code",
      "description": "Agent-driven TDD pipeline: spec, red, green, review, ship."
    }
  ]
}
```

`adapters/claude-code/.claude-plugin/plugin.json`:

```json
{
  "name": "tdd-pipeline",
  "version": "0.1.0",
  "description": "Agent-driven TDD pipeline: spec, red, green, review, ship."
}
```

- [ ] **Step 4: Write the five agent adapters**

Each is frontmatter plus a pointer. `agents/task-test.md`:

```markdown
---
name: task-test
description: Writes the failing test suite that defines a task's expected behavior, before any implementation exists. Runs as the red phase of the TDD pipeline.
model: opus
memory: project
---
Follow `${CLAUDE_PLUGIN_ROOT}/core/phases/test.md` exactly.

Dispatch subagents with the `Agent` tool. Read the pipeline configuration from
`.claude/pipeline.yaml` in the project root.
```

Repeat for `task-execute` (`core/phases/execute.md`, model opus), `task-code-review` (`core/phases/code-review.md`, model opus), `task-end` (`core/phases/end.md`, model sonnet), and `task-pipeline` (`core/phases/pipeline.md`, model sonnet). Write a specific `description` for each — it is what the harness uses to route work, so "handles tasks" is a defect.

- [ ] **Step 5: Write the six command adapters**

`commands/task.md`:

```markdown
---
description: Run a task end to end — spec, review gate, TDD pipeline, pull request.
---
Follow `${CLAUDE_PLUGIN_ROOT}/core/flows/task.md`.

Dispatch the pipeline orchestrator as the `task-pipeline` subagent via the `Agent`
tool, with the created worktree as its working directory.

ARGUMENTS: $ARGUMENTS
```

Repeat for `review` → `core/flows/review.md`, `resume` → `core/flows/resume.md`, `init` → `core/flows/init.md`, `conventions` → `core/flows/conventions.md`, `doctor` → `core/flows/doctor.md`.

- [ ] **Step 6: Add manifest lines and run tests**

```
adapters/claude-code/.claude-plugin/plugin.json|
.claude-plugin/marketplace.json|
```

Run: `./tests/run.sh && checks/no-leakage.sh && checks/references-resolve.sh`
Expected: exit 0. Note that `checks/core-is-neutral.sh` scans only `core/`, so the harness tokens in the adapter are permitted by design.

- [ ] **Step 7: Commit**

```bash
git add .claude-plugin adapters/claude-code checks tests
git commit -m "Add Claude Code adapter"
```

---

### Task 15: Cursor adapter and installer

**Files:**
- Create: `adapters/cursor/agents/*.md` (same five names)
- Create: `adapters/cursor/commands/*.md` (same six names)
- Create: `install.sh`
- Test: `tests/run.sh`, `tests/fixtures/project/`

**Interfaces:**
- Produces: `install.sh --harness <claude-code|cursor> --project <path>` — symlinks the adapter and core into the target project, idempotent, and refuses to overwrite a non-symlink it did not create.

- [ ] **Step 1: Add failing tests for adapter coverage and the installer**

```bash
assert_exit 0 "every core phase and flow has a Cursor adapter" \
  checks/adapters-cover-core.sh cursor
assert_exit 0 "installer creates cursor links in a fixture project" \
  tests/cases/install-cursor.sh
```

`tests/cases/install-cursor.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
git -C "$TMP" init -q
./install.sh --harness cursor --project "$TMP" >/dev/null
[ -L "$TMP/.cursor/agents/task-test.md" ]
[ -L "$TMP/.cursor/commands/task.md" ]
[ -d "$TMP/.cursor/agent-pipeline/core" ]
./install.sh --harness cursor --project "$TMP" >/dev/null   # idempotent
[ -L "$TMP/.cursor/agents/task-test.md" ]
```

- [ ] **Step 2: Run tests to verify failure**

Run: `chmod +x tests/cases/install-cursor.sh && ./tests/run.sh`
Expected: both new cases FAIL.

- [ ] **Step 3: Write the Cursor agent adapters**

Same five files, minimal frontmatter, and the harness-specific lines differ:

```markdown
---
name: task-test
description: Writes the failing test suite that defines a task's expected behavior, before any implementation exists. Runs as the red phase of the TDD pipeline.
---
Follow `.cursor/agent-pipeline/core/phases/test.md` exactly.

Dispatch subagents with the `Task` tool. Read the pipeline configuration from
`.claude/pipeline.yaml` in the project root.
```

The path is project-relative because this harness exposes no plugin-root variable; the installer guarantees that path exists. Keep the `description` text identical to the Claude Code adapter's, so routing behaves the same on both.

- [ ] **Step 4: Write the Cursor command adapters**

Six files mirroring the Claude Code commands, pointing at `.cursor/agent-pipeline/core/flows/*.md` and naming the `Task` tool.

- [ ] **Step 5: Write `install.sh`**

```bash
#!/usr/bin/env bash
# Links this package's adapter into a target project.
set -euo pipefail
SRC="$(cd "$(dirname "$0")" && pwd)"
HARNESS=""; PROJECT=""

while [ $# -gt 0 ]; do
  case "$1" in
    --harness) HARNESS="$2"; shift 2 ;;
    --project) PROJECT="$2"; shift 2 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

[ -n "$HARNESS" ] && [ -n "$PROJECT" ] || {
  echo "usage: install.sh --harness <claude-code|cursor> --project <path>" >&2; exit 2; }
[ -d "$SRC/adapters/$HARNESS" ] || { echo "unknown harness: $HARNESS" >&2; exit 2; }
[ -d "$PROJECT" ] || { echo "no such project: $PROJECT" >&2; exit 2; }

case "$HARNESS" in
  cursor)      DEST="$PROJECT/.cursor" ;;
  claude-code) DEST="$PROJECT/.claude" ;;
esac

link() { # <target> <linkname>
  if [ -e "$2" ] && [ ! -L "$2" ]; then
    echo "refusing to replace existing file: $2" >&2; exit 1
  fi
  ln -sfn "$1" "$2"
}

mkdir -p "$DEST/agents" "$DEST/commands" "$DEST/agent-pipeline"
link "$SRC/core" "$DEST/agent-pipeline/core"
for f in "$SRC/adapters/$HARNESS/agents/"*.md;   do link "$f" "$DEST/agents/$(basename "$f")"; done
for f in "$SRC/adapters/$HARNESS/commands/"*.md; do link "$f" "$DEST/commands/$(basename "$f")"; done

echo "Installed $HARNESS adapter into $DEST"
echo "Next: run the doctor flow in that project to verify its requirements."
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `chmod +x install.sh && ./tests/run.sh`
Expected: all cases pass, exit 0.

- [ ] **Step 7: Commit**

```bash
git add adapters/cursor install.sh checks tests
git commit -m "Add Cursor adapter and installer"
```

---

### Task 16: README and end-to-end validation

The acceptance criteria from the design document. This task is not complete until a real pipeline has shipped a real pull request on both harnesses.

**Files:**
- Create: `README.md`
- Create: `docs/validation-2026-08-03.md`

- [ ] **Step 1: Write the README**

Cover, in this order: what the package does in two sentences; the six commands in a table; installation for both harnesses; the `pipeline.yaml` example with `tracker: none` and a plain test runner; a "first task in five minutes" walkthrough; and how to update (`git pull` in the clone, which propagates through the symlinks).

- [ ] **Step 2: Create the validation repository**

```bash
TMP=$(mktemp -d)/smoke && mkdir -p "$TMP" && cd "$TMP"
git init -q && mkdir -p src tests
printf 'def add(a, b):\n    raise NotImplementedError\n' > src/calc.py
git add -A && git commit -q -m "Initial commit"
```

Install the Claude Code adapter into it.

- [ ] **Step 3: Run init and verify criteria 1 and 2**

Run the init command. Then confirm:
- the generated `.claude/pipeline.yaml` names a test command that actually runs;
- the conventions file contains rules derived from the code with `file:line` citations, not a placeholder;
- the doctor flow reports all-pass;
- emptying the managed conventions section makes the doctor flow report `fail` on that row specifically.

Record each result in `docs/validation-2026-08-03.md`.

- [ ] **Step 4: Run a full task and verify criteria 3, 4, and 5**

Run the task command with `"validate input types on add"`. Confirm the gate appears, then proceed. Confirm:
- the result is `SHIPPED` with a pull request URL;
- the spec's handoff log holds one entry per phase;
- the code-review phase blocks a weakened test — verify by re-running the pipeline on a second task after manually editing the red-phase assertion to a weaker form, and confirm the verdict is `CHANGES_REQUESTED` naming that file.

- [ ] **Step 5: Verify criteria 6 and 7**

Interrupt a third task after the red phase. Run the resume command with the `execute` phase and confirm it completes. Then install the Cursor adapter into the same repository, interrupt a fourth task on one harness, and resume it on the other. Record whether it completed — this is the criterion that proves state lives in files.

- [ ] **Step 6: Verify criterion 8 and close out**

```bash
cd <package repo>
./tests/run.sh
checks/no-leakage.sh
checks/core-is-neutral.sh
checks/references-resolve.sh
git status --short   # nothing under .import/
```

Write the validation results file with one line per criterion: pass, fail, or not attempted, with the evidence. A criterion that failed is recorded as failed — this document exists to be honest, not to be green.

- [ ] **Step 7: Commit**

```bash
git add README.md docs/validation-2026-08-03.md
git commit -m "Add README and record end-to-end validation results"
```

---

## Deferred

Not in this plan, per the design document's out-of-scope section: the ADR, bug-fix, and pull-request-review commands; harnesses beyond the two; prebuilt per-stack convention packs; migrating any existing project onto the package.
