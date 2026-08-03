---
description: Re-enter an interrupted pipeline at one phase, run that phase alone, and stop without chaining into the phases that follow.
---
Follow `${CLAUDE_PLUGIN_ROOT}/core/flows/resume.md`.

Every bare `core/…` path inside that file — and inside every file it points
at — is relative to the plugin root: read each one as
`${CLAUDE_PLUGIN_ROOT}/core/…`. `${CLAUDE_PLUGIN_ROOT}` is absolute, so it
resolves identically from the project root and from inside a task worktree.

Dispatch the selected phase as the corresponding `task-test`, `task-execute`,
`task-code-review`, or `task-end` subagent via the `Agent` tool, with the
confirmed worktree as its working directory.

ARGUMENTS: $ARGUMENTS
