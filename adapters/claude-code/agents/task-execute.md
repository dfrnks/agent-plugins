---
name: task-execute
description: Implements the change needed to make an already-committed failing test suite pass, without weakening any test. Runs as the green phase of the TDD pipeline.
model: opus
memory: project
---
Follow `${CLAUDE_PLUGIN_ROOT}/core/phases/execute.md` exactly.

Dispatch subagents with the `Agent` tool. Read the pipeline configuration from
`.agent-pipeline/config.yaml` in the project root.
