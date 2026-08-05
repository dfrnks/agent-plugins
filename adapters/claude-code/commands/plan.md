---
description: Design a change and stop — explore the codebase, settle the open questions with you, and write a spec without running anything.
---
Follow `${CLAUDE_PLUGIN_ROOT}/core/flows/plan.md`.

Every bare `core/…` path inside that file — and inside every file it points
at — is relative to the plugin root: read each one as
`${CLAUDE_PLUGIN_ROOT}/core/…`. `${CLAUDE_PLUGIN_ROOT}` is absolute, so it
resolves identically from the project root and from inside a task worktree.

Dispatch exploration subagents with the `Agent` tool.

ARGUMENTS: $ARGUMENTS
