---
description: Fix a defect test-first — reproduce it with a failing test, name the root cause, make the minimal change, and verify nothing else broke.
---
Follow `${CLAUDE_PLUGIN_ROOT}/core/flows/fix-bug.md`.

Every bare `core/…` path inside that file — and inside every file it points
at — is relative to the plugin root: read each one as
`${CLAUDE_PLUGIN_ROOT}/core/…`. `${CLAUDE_PLUGIN_ROOT}` is absolute, so it
resolves identically from the project root and from inside the worktree that
flow creates.

Dispatch exploration subagents with the `Agent` tool.

ARGUMENTS: $ARGUMENTS
