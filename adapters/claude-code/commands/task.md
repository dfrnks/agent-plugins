---
description: Run a task end to end — spec, review gate, TDD pipeline, pull request.
---
Follow `${CLAUDE_PLUGIN_ROOT}/core/flows/task.md`.

Every bare `core/…` path inside that file — and inside every file it points
at — is relative to the plugin root: read each one as
`${CLAUDE_PLUGIN_ROOT}/core/…`. `${CLAUDE_PLUGIN_ROOT}` is absolute, so it
resolves identically from the project root and from inside a task worktree.

Dispatch the pipeline orchestrator as the `task-pipeline` subagent via the `Agent`
tool, with the created worktree as its working directory.

ARGUMENTS: $ARGUMENTS
