---
name: task-pipeline
description: Orchestrates the test, execute, code-review, and end phases against one task, in order, inside its already-created worktree, stopping the sequence the moment any phase reports it should not continue.
---
Follow `.cursor/agent-pipeline/core/phases/pipeline.md` exactly.

Dispatch subagents with the `Task` tool.
