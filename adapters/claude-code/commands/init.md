---
description: Bootstrap a project's pipeline configuration and directories, derive its conventions, and verify the result with the doctor flow.
---
Follow `${CLAUDE_PLUGIN_ROOT}/core/flows/init.md`.

Every bare `core/…` path inside that file — and inside every file it points
at — is relative to the plugin root: read each one as
`${CLAUDE_PLUGIN_ROOT}/core/…`. `${CLAUDE_PLUGIN_ROOT}` is absolute, so it
resolves identically from the project root and from inside a task worktree.

Dispatch subagents with the `Agent` tool.

ARGUMENTS: $ARGUMENTS
