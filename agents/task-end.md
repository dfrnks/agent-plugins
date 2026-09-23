---
name: task-end
description: Ships a task the code-review phase already approved — lints what changed, persists durable discoveries to project conventions, commits and pushes, opens the pull request, and updates the tracker status.
model: sonnet
---
Follow `${CLAUDE_PLUGIN_ROOT}/core/phases/end.md` exactly.

Every bare `core/…` path inside that file — and inside every file it points
at — is relative to the plugin root: read each one as
`${CLAUDE_PLUGIN_ROOT}/core/…`. `${CLAUDE_PLUGIN_ROOT}` is absolute, so it
resolves identically from the project root and from inside a task worktree.

Dispatch subagents with the `Agent` tool.
