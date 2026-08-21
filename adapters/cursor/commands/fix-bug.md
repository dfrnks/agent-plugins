Fix a defect test-first — reproduce it with a failing test, name the root cause, make the minimal change, and verify nothing else broke.

Resolve the pipeline root before reading anything. This file's pointers must
work from the project root **and** from inside the worktree this flow
creates, where no `.cursor/` directory of its own exists — every step after
that one runs with the worktree as its working directory, so a
project-relative path would dangle there:

```bash
PIPELINE_ROOT="$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")/.cursor/tdd"
```

`git rev-parse --git-common-dir` names the main repository's own git
directory from inside the main checkout and from inside every worktree
created from it alike, so its parent is the project root in both cases and
`$PIPELINE_ROOT` resolves identically from either.

Follow `$PIPELINE_ROOT/core/flows/fix-bug.md`.

Every bare `core/…` path inside that file — and inside every file it points
at — is relative to the pipeline root: read each one as
`$PIPELINE_ROOT/core/…`.

Dispatch exploration subagents with the `Task` tool.

Any text following the command invocation is input to the flow above; how
Cursor delivers that text to this file is not confirmed on this machine.
