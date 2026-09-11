# Tracker: none

The default mode, and the one the README documents first. It requires no
external service, no authentication, and no network access — a project can
adopt the pipeline before it has decided whether to use an issue tracker at
all, or may simply not want one. This file is not a placeholder pointing at
a real integration to configure later; it is the complete, working
implementation for projects that track work in specs alone.

Selected by `tracker.type: none` (see `pipeline-config.md`). Only
`tracker.prefix` is read; `tracker.team` and `tracker.states` do not apply
in this mode and are never read.

## resolve_or_create

Input: the argument passed to the task or plan flow — either a tracker
identifier or a free-text description.

1. If the argument matches `<prefix>-<number>` (the prefix from
   `tracker.prefix`), that string is the task ID. Nothing else to resolve.
2. Otherwise, treat the argument as a free-text description of new work:
   - List `paths.specs` for files matching `<prefix>-<number>.md`.
   - Take the highest existing `<number>`, add one. An empty directory
     yields `1`.
   - Present the derived ID to the user and ask for confirmation before
     using it — the scan only sees local spec files, not any work tracked
     elsewhere, so a stale or partially-cleaned directory could produce an
     ID that collides with something the user already knows about.

Two flows started close together can both scan `paths.specs` before
either has written a spec file, both compute the same highest-plus-one, and
both present the same derived ID for confirmation — a real race, not a
theoretical one, since this pipeline explicitly supports running multiple
worktrees in parallel. The user-confirmation step above is the guard: it is
a natural point for a person running two flows at once to notice the
duplicate before either proceeds. It is not sufficient by itself, because
confirmation depends on a human catching a coincidence they may not be
watching for. The deterministic backstop is the write itself: immediately
before creating the spec file at `paths.specs/<id>.md`, re-check that no
file already exists at that path. If one now exists — the other flow won
the race — stop rather than overwrite it, and re-derive the ID from a fresh
scan.

Output: the task ID, used as-is for the branch name and the spec filename.

## set_status

No operation. There is no external system to update.

Still report a line at the end phase, identical in shape to what the other
two modes report, so a reader of the phase's output never has to wonder
whether a status update was attempted and failed silently:

```
tracker: none, no status update
```
