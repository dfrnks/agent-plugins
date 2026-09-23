---
name: task-test
description: Writes the failing test suite that defines a task's expected behavior, before any implementation exists. Runs as the red phase of the TDD pipeline.
model: opus
---
Follow `${CLAUDE_PLUGIN_ROOT}/core/phases/test.md` exactly.

Every bare `core/…` path inside that file — and inside every file it points
at — is relative to the plugin root: read each one as
`${CLAUDE_PLUGIN_ROOT}/core/…`. `${CLAUDE_PLUGIN_ROOT}` is absolute, so it
resolves identically from the project root and from inside a task worktree.

Dispatch subagents with the `Agent` tool.
