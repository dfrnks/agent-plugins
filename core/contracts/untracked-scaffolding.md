# Untracked scaffolding contract

Some projects deliberately keep the pipeline's own files out of version
control: the configuration, the specs, sometimes the conventions document.
The reasons are legitimate — specs read as working notes rather than
repository content, and a team may not want them in its history.

Every phase, though, runs inside a worktree, and a worktree holds only
committed files. Untracked scaffolding is therefore invisible from exactly
where it is needed, and the run stops at a phase's first step.

This contract defines how a flow makes untracked scaffolding visible to a
worktree, and how it returns what the phases wrote there. A flow that
mirrors is doing bookkeeping the project would otherwise leave to the user,
by hand, once per task — which is where it gets forgotten.

## Detection

Resolve the main checkout first. This works from inside a worktree and from
the main checkout alike, because `--git-common-dir` names the main
repository's git directory in both:

```bash
MAIN="$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")"
```

Run from `$MAIN`, test each scaffolding path:

```bash
git ls-files --error-unmatch <path>
```

A non-zero exit means untracked, which means it needs mirroring. The paths to
test are `.tdd-pipeline/config.yaml`, `paths.specs`, `paths.conventions`,
`.tdd-pipeline/memory/`, and `paths.review_checklist` and
`git.worktree_setup` when the configuration sets them.

**`paths.worktrees` is never mirrored.** It is git-ignored by requirement and
holds the worktrees themselves, so copying it copies the destination into
itself.

Mirroring is per-path, not all-or-nothing. A project commonly tracks its
conventions document and not its specs; mirror only what the test says is
untracked, and leave a tracked path to git.

## Mirroring in

Copy each untracked path from `$MAIN` to the same relative path inside the
worktree, immediately after `git worktree add` and before any phase runs.

Order matters in one case: when `git.worktree_setup` is itself untracked,
mirror it before running it, or the pipeline's own setup step finds no script
where the configuration says one is.

Mirroring is not a substitute for `git.worktree_setup`. That script links or
installs dependency trees; this contract moves only the pipeline's own
files. A worktree usually needs both.

## Mirroring back

Phases append their handoff-log entries to the spec, and in a mirrored
worktree they append to the copy. The copy dies with the worktree. Nothing
errors — the canonical spec simply never gains a log, and whatever reads it
next starts blind.

So copy back, from the worktree to `$MAIN`:

- **The spec**, after *each* phase returns, not once when the run ends. A
  phase that stops the run still wrote its entry, and that entry is
  precisely what the next attempt needs to read.
- **`paths.conventions` and `.tdd-pipeline/memory/`**, after any phase that
  writes them.

For the spec the worktree copy wins outright: during a run, phases are its
only writers. For the conventions document that is not safe — a user may
have edited it in the main checkout while the run was in flight, and phases
write only inside the managed markers. Copy back the managed spans, not the
whole file, and leave everything outside them as `$MAIN` has it.

**Spans, plural: there are two, they are not adjacent, and copying back only
the first silently loses the second.** `core/contracts/conventions-template.md`
defines `pipeline:conventions:start` / `:end` *and*
`pipeline:discoveries:start` / `:end`, with hand-written prose permitted
between them. The end phase writes durable facts to the discoveries span, so
an agent that reads "the managed section" as one region copies conventions
back, drops discoveries, and the run's most valuable output — the findings
meant to outlive the task — dies with the worktree. Nothing errors. Enumerate
both spans by name and copy each one.

A repair counts as a write, and must come back too. An unterminated span — a
`start` with no matching `end` — is a stop condition, and a phase that repairs
it in a mirrored worktree has fixed only the copy. The next run finds the file
broken again and pays the same cost, which reads as the repair having failed
rather than never having been persisted.

## Never staged

A mirrored path is untracked because the project chose that. Mirroring is a
visibility mechanism and changes nothing about that choice.

Never stage a mirrored path. Never reach for `git add -A` or `git add .` in
a mirrored worktree — the mirrored files sit at their canonical relative
paths, so a blanket add sweeps every one of them into the commit. Stage named
paths, and verify before each commit that no mirrored path appears among
them.

A phase whose own contract tells it to commit the spec or the conventions
document skips that step in a mirrored worktree, and reports the skip rather
than failing: the file is present by mirror, not by git, and committing it
would defeat the project's decision.
