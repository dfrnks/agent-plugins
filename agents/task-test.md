---
name: task-test
description: Writes the failing test suite that defines a task's expected behavior, before any implementation exists. Runs as the red phase of the TDD pipeline.
model: opus
memory: project
---
Follow `${CLAUDE_PLUGIN_ROOT}/core/phases/test.md` exactly.

Dispatch subagents with the `Agent` tool.
