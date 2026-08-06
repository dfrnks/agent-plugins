---
description: Derive the project's own conventions from the codebase, write them into the project's conventions file, and extend the review checklist alongside them.
---
Follow `${CLAUDE_PLUGIN_ROOT}/core/flows/conventions.md`.

Every bare `core/…` path inside that file — and inside every file it points
at — is relative to the plugin root: read each one as
`${CLAUDE_PLUGIN_ROOT}/core/…`. `${CLAUDE_PLUGIN_ROOT}` is absolute, so it
resolves identically from the project root and from inside a task worktree.

Dispatch exploration subagents with the `Agent` tool.

ARGUMENTS: $ARGUMENTS
