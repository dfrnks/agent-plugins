---
name: task-execute
description: Implements the change needed to make an already-committed failing test suite pass, without weakening any test. Runs as the green phase of the TDD pipeline.
model: opus
memory: project
---
Follow `${CLAUDE_PLUGIN_ROOT}/core/phases/execute.md` exactly.

Every bare `core/…` path inside that file — and inside every file it points
at — is relative to the plugin root: read each one as
`${CLAUDE_PLUGIN_ROOT}/core/…`. `${CLAUDE_PLUGIN_ROOT}` is absolute, so it
resolves identically from the project root and from inside a task worktree.

Dispatch subagents with the `Agent` tool.
