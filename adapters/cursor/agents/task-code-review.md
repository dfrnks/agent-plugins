---
name: task-code-review
description: Adjudicates a task's implementation against its spec, the project's conventions, and its own tests, then renders an APPROVED, APPROVED_WITH_WARNINGS, or CHANGES_REQUESTED verdict. Runs as the last gate before a task ships.
---
Follow `.cursor/agent-pipeline/core/phases/code-review.md` exactly.

Dispatch subagents with the `Task` tool.
