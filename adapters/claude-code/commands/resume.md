---
description: Re-enter an interrupted pipeline at one phase, run that phase alone, and stop without chaining into the phases that follow.
---
Follow `${CLAUDE_PLUGIN_ROOT}/core/flows/resume.md`.

Dispatch the selected phase as the corresponding `task-test`, `task-execute`,
`task-code-review`, or `task-end` subagent via the `Agent` tool, with the
confirmed worktree as its working directory.

ARGUMENTS: $ARGUMENTS
