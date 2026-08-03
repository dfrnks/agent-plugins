---
name: task-code-review
description: Adjudicates a task's implementation against its spec, the project's conventions, and its own tests, then renders an APPROVED, APPROVED_WITH_WARNINGS, or CHANGES_REQUESTED verdict. Runs as the last gate before a task ships.
model: opus
memory: project
---
Follow `${CLAUDE_PLUGIN_ROOT}/core/phases/code-review.md` exactly.

Dispatch subagents with the `Agent` tool. Read the pipeline configuration from
`.agent-pipeline/config.yaml` in the project root.
