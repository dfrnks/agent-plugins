---
description: Critique a task spec against the actual codebase, fix it in place, and record the review in its handoff log.
---
Follow `${CLAUDE_PLUGIN_ROOT}/core/flows/review.md`.

Every bare `core/…` path inside that file — and inside every file it points
at — is relative to the plugin root: read each one as
`${CLAUDE_PLUGIN_ROOT}/core/…`. `${CLAUDE_PLUGIN_ROOT}` is absolute, so it
resolves identically from the project root and from inside a task worktree.

Dispatch exploration subagents with the `Agent` tool.

ARGUMENTS: $ARGUMENTS
