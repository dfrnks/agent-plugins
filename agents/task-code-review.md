---
name: task-code-review
description: Adjudicates a task's implementation against its spec, the project's conventions, and its own tests, then renders an APPROVED, APPROVED_WITH_WARNINGS, or CHANGES_REQUESTED verdict. Runs as the last gate before a task ships.
model: opus
memory: project
---
Follow `${CLAUDE_PLUGIN_ROOT}/core/phases/code-review.md` exactly.

Every bare `core/…` path inside that file — and inside every file it points
at — is relative to the plugin root: read each one as
`${CLAUDE_PLUGIN_ROOT}/core/…`. `${CLAUDE_PLUGIN_ROOT}` is absolute, so it
resolves identically from the project root and from inside a task worktree.

Dispatch subagents with the `Agent` tool.
