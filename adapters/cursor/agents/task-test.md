---
name: task-test
description: Writes the failing test suite that defines a task's expected behavior, before any implementation exists. Runs as the red phase of the TDD pipeline.
---
Resolve the pipeline root before reading anything. This file's pointers must
work from the project root **and** from inside a task worktree, where no
`.cursor/` directory of its own exists — the phases run with the worktree as
their working directory, so a project-relative path would dangle there:

```bash
PIPELINE_ROOT="$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")/.cursor/tdd"
```

`git rev-parse --git-common-dir` names the main repository's own git
directory from inside the main checkout and from inside every worktree
created from it alike, so its parent is the project root in both cases and
`$PIPELINE_ROOT` resolves identically from either.

Follow `$PIPELINE_ROOT/core/phases/test.md` exactly.

Every bare `core/…` path inside that file — and inside every file it points
at — is relative to the pipeline root: read each one as
`$PIPELINE_ROOT/core/…`.

Dispatch subagents with the `Task` tool.
