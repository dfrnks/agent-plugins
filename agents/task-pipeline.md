---
name: task-pipeline
description: Orchestrates the test, execute, code-review, and end phases against one task, in order, inside its already-created worktree, stopping the sequence the moment any phase reports it should not continue.
model: sonnet
---
Follow `${CLAUDE_PLUGIN_ROOT}/core/phases/pipeline.md` exactly.

Every bare `core/…` path inside that file — and inside every file it points
at — is relative to the plugin root: read each one as
`${CLAUDE_PLUGIN_ROOT}/core/…`. `${CLAUDE_PLUGIN_ROOT}` is absolute, so it
resolves identically from the project root and from inside a task worktree.

Dispatch subagents with the `Agent` tool.
