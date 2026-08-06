---
name: task-execute
description: Implements the change needed to make an already-committed failing test suite pass, without weakening any test. Runs as the green phase of the TDD pipeline.
---
Resolve the pipeline root before reading anything. This file's pointers must
work from the project root **and** from inside a task worktree, where no
`.cursor/` directory of its own exists — the phases run with the worktree as
their working directory, so a project-relative path would dangle there:

```bash
PIPELINE_ROOT="$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")/.cursor/agent-pipeline"
```

`git rev-parse --git-common-dir` names the main repository's own git
directory from inside the main checkout and from inside every worktree
created from it alike, so its parent is the project root in both cases and
`$PIPELINE_ROOT` resolves identically from either.

Follow `$PIPELINE_ROOT/core/phases/execute.md` exactly.

Every bare `core/…` path inside that file — and inside every file it points
at — is relative to the pipeline root: read each one as
`$PIPELINE_ROOT/core/…`.

Dispatch subagents with the `Task` tool.
