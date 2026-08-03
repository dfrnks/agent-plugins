---
name: task-pipeline
description: Orchestrates the test, execute, code-review, and end phases against one task, in order, inside its already-created worktree, stopping the sequence the moment any phase reports it should not continue.
model: sonnet
memory: project
---
Follow `${CLAUDE_PLUGIN_ROOT}/core/phases/pipeline.md` exactly.

Dispatch subagents with the `Agent` tool.
