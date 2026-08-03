---
name: task-end
description: Ships a task the code-review phase already approved — lints what changed, persists durable discoveries to project conventions, commits and pushes, opens the pull request, and updates the tracker status.
model: sonnet
memory: project
---
Follow `${CLAUDE_PLUGIN_ROOT}/core/phases/end.md` exactly.

Dispatch subagents with the `Agent` tool. Read the pipeline configuration from
`.agent-pipeline/config.yaml` in the project root.
