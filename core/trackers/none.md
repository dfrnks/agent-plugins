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

Input: the argument passed to the task flow — either a tracker identifier
or a free-text description.

1. If the argument matches `<prefix>-<number>` (the prefix from
   `tracker.type`), that string is the task ID. Nothing else to resolve.
2. Otherwise, treat the argument as a free-text description of new work:
   - List `paths.specs` for files matching `<prefix>-<number>.md`.
   - Take the highest existing `<number>`, add one. An empty directory
     yields `1`.
   - Present the derived ID to the user and ask for confirmation before
     using it — the scan only sees local spec files, not any work tracked
     elsewhere, so a stale or partially-cleaned directory could produce an
     ID that collides with something the user already knows about.

Output: the task ID, used as-is for the branch name and the spec filename.

## set_status

No operation. There is no external system to update.

Still report a line at the end phase, identical in shape to what the other
two modes report, so a reader of the phase's output never has to wonder
whether a status update was attempted and failed silently:

```
tracker: none, no status update
```
