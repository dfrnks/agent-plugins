# Conventions

The rules below are derived from this codebase, not imposed on it. Each one
carries the `file:line` it was read from, so it can be checked against the
code rather than trusted on its own.

<!-- pipeline:conventions:start -->

## Module boundaries and layering

- Never name a harness, a harness variable, a harness tool, or a third-party
  tool in `core/`; anything harness-specific belongs in an adapter
  (checks/core-is-neutral.sh:11).
- Never reference another top-level directory from `core/` — adapters point
  at core, and core points at nothing outside itself
  (adapters/claude-code/commands/task.md:4).
- Keep every adapter file a frontmatter shell plus a single
  `Follow .../core/<dir>/<file>.md` pointer, with no behaviour of its own
  (adapters/cursor/commands/tdd-task.md:37).
- Name the subagent-dispatch tool only in an adapter; core says "dispatch
  subagents" (core/flows/conventions.md:53).
- Reference a core file by its full `core/<dir>/<file>.md` path, never by a
  bare filename — the reference checker matches only the prefixed form
  (checks/references-resolve.sh:15).
- Treat `checks/` as source and `tests/` as the only test-owning directory
  (README.md:356).

## Error handling

- Use `set -uo pipefail` without `-e` in a script that scans and reports, and
  `set -euo pipefail` in a script that mutates state (checks/no-leakage.sh:4,
  install.sh:3).
- Accumulate findings in `rc` and end with `exit $rc`; never abort a scan on
  its first finding (checks/structure.sh:7, checks/structure.sh:24).
- Exit 2 for a caller or precondition error, and 1 for a finding
  (install.sh:17, checks/structure.sh:24).
- Name the exact failing item in every failure message — path, line, token
  (checks/no-leakage.sh:97).
- Abort when a scratch directory cannot be created rather than running
  degraded; a checker that passes because it could not run is worse than one
  that fails (checks/core-is-neutral.sh:43).
- Guard `cd "$(dirname "$0")/.."` with `|| exit 1` in every script not under
  `set -e` (checks/no-leakage.sh:5).
- Stop and name the exact missing configuration key; never substitute a guess
  or a hardcoded fallback (core/contracts/pipeline-config.md:122).
- Stop loudly when an external integration is unavailable; never fall back to
  a degraded mode (core/trackers/github.md:13).
- Report a phase as unverified when it could not run its check; never claim an
  observation it did not make (core/phases/test.md:129).

## Naming

- Title a core file `# <Kind>: <name>` matching its filename stem; a contract
  is titled `# <Thing> contract` (core/phases/test.md:1,
  core/contracts/handoff-log.md:1).
- Name a step `## Step <N> — <imperative>`, starting at
  `## Step 0` wherever configuration is read (core/phases/test.md:10).
- Write a hand-written commit subject as a capitalised imperative sentence,
  with no scope prefix and no trailing period (git log b63023c).
- Use the scoped form `<task-id>: <lowercase imperative>` or `pipeline: ...`
  only for a commit a phase or flow generates (core/flows/init.md:113,
  core/phases/test.md:212).
- Name a shell function in `snake_case`, with a `# <arg> <arg>` signature
  comment on the declaration line (tests/run.sh:8).
- Use uppercase for script-level values taken from arguments or the
  environment, and lowercase for arrays, locals, and the `rc` accumulator
  (install.sh:52, checks/structure.sh:7).
- Use `TASK-1` and `my-app` as the only example identifiers
  (core/contracts/pipeline-config.md:27).
- Name a fixture `<subject>-<condition>`, reserving `-lookalike` for the
  near-miss case (tests/fixtures/leak-lookalike.md:1).

## Authentication and authorization

- Check an external CLI or MCP integration's authentication before the first
  call, and stop with the exact command that fixes it; never fall back to a
  tracker type that needs none (core/trackers/github.md:13,
  core/trackers/linear.md:8).
- Never authenticate on the user's behalf; report the command and stop
  (core/flows/doctor.md:237).
- Never introduce a real home path or email address into a tracked file
  (checks/no-leakage.sh:9).
- Extend the leakage allowlist only for a genuinely needed placeholder, never
  to silence a real finding (checks/no-leakage.sh:33).

## Data access

- Read the pipeline configuration at Step 0 and defer failure behaviour to
  the fail-fast protocol (core/phases/execute.md:12).
- Commit anything a phase must read; an uncommitted file is invisible from
  inside a worktree (core/flows/conventions.md:130).
- Stage named paths; never `git add .` or `git add -A`
  (core/flows/conventions.md:128, core/phases/end.md:165).
- Pass state between phases only through the handoff log in the spec, never
  through session context (core/phases/execute.md:302).

## Testing

- Assert both the accepting and the rejecting case for every checker
  (tests/run.sh:31, tests/run.sh:35).
- Give every checker an argument that swaps its real target for a fixture
  (checks/structure.sh:6, checks/adapters-cover-core.sh:15).
- Assert every checker against the real repository, not only against fixtures
  (tests/run.sh:43).
- Add a `-lookalike` near-miss fixture wherever a check matches by pattern
  (tests/run.sh:39, tests/run.sh:51).
- Self-exempt the checker, the runner, and the fixtures only on an
  argument-less whole-repo scan (checks/no-leakage.sh:90,
  checks/references-resolve.sh:12).
- Write the `checks/manifest.txt` row before the file it describes, so the
  check fails first (checks/manifest.txt:2).
- Declare a test as one call to an `assert_*` helper with a sentence
  description, count passes and failures, and exit on the aggregate
  (tests/run.sh:8, tests/run.sh:78).

## Formatting and lint

- Hard-wrap Markdown prose under `core/` at 77 columns; tables, code fences,
  and frontmatter are exempt (core/phases/test.md:7).
- Hard-wrap Markdown prose outside `core/` at 80 columns (README.md:1).
- Use `- ` for an unordered list and `N. ` for an ordered one; never `*`, `+`,
  or `N)` (core/flows/init.md:74).
- Use bold for emphasis and reserve italic for single-word stress; never use
  underscore emphasis (core/contracts/project-requirements.md:117).
- Space every em dash on both sides (core/contracts/handoff-log.md:5).
- Write headings in sentence case, with a single H1 on line 1 of every core
  file (core/contracts/pipeline-config.md:75).
- Start every script with `#!/usr/bin/env bash`, indent by two spaces, use no
  tabs, and prefer `printf` over `echo` for diagnostics (tests/run.sh:1).
- End every tracked file with exactly one trailing newline, and leave no
  trailing whitespace (checks/structure.sh:1).
- Write every file in this repository in English
  (docs/specs/2026-08-03-tdd-pipeline-plugin-design.md:43).

<!-- pipeline:conventions:end -->

<!-- pipeline:discoveries:start -->

## Testing

- `checks/structure.sh:18` matches a required heading with `grep -qF`, an
  unanchored fixed string, so a heading merely mentioned in prose — inside a
  fence, in a cross-reference — satisfies the check. A manifest row proves
  the string is present, never that the section exists
  (`checks/structure.sh:18`).
- A change that touches only Markdown prose has no red-green purchase, and
  the pipeline has no `n/a` path for it: the test phase must report
  `unverified` when it cannot observe a failing suite
  (`core/phases/test.md:129`), and the orchestrator converts that to
  `BLOCKED` (`core/phases/pipeline.md:130`). The way through is a fixture
  under `paths.tests` that a checker rejects until the prose change lands —
  the pattern `tests/fixtures/manifest-good.txt` already establishes
  (`tests/run.sh:59`).

<!-- pipeline:discoveries:end -->
