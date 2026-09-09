Fix a defect test-first — reproduce it with a failing test, name the root cause, make the minimal change, and verify nothing else broke.

Resolve the pipeline root before reading anything. This file's pointers must
work from three places that do not share one root: the project root, the
worktree this flow creates (where no `.cursor/` directory of its own exists —
every step after that one runs with the worktree as its working directory, so a
project-relative path would dangle there), and, when the pipeline is installed
for the user rather than per project, a directory that is not a prepared
project and need not be a git repository at all:

```bash
PIPELINE_ROOT="${TDD_PIPELINE_ROOT:-}"
if [ -z "$PIPELINE_ROOT" ]; then
  GIT_COMMON="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)"
  if [ -n "$GIT_COMMON" ] && [ -d "$(dirname "$GIT_COMMON")/.cursor/tdd/core" ]; then
    PIPELINE_ROOT="$(dirname "$GIT_COMMON")/.cursor/tdd"
  else
    PIPELINE_ROOT="$HOME/.cursor/plugins/local/tdd"
  fi
fi
```

`$TDD_PIPELINE_ROOT` is honoured first, so an installation that lives somewhere
else needs no edit to this file. Otherwise `git rev-parse --git-common-dir`
names the main repository's own git directory from inside the main checkout and
from inside every worktree created from it alike, so its parent is the project
root in both cases and a project-local installation resolves identically from
either. That parent is accepted only when it actually holds `core/`: the test is
what separates a prepared project from a directory that merely happens to be a
git repository, and it is why the user-level path below it is a fallback rather
than a guess. Silencing `git rev-parse` is what lets a directory outside any
repository reach that fallback instead of failing here.

Stop and report that the pipeline is not installed if `$PIPELINE_ROOT/core`
does not exist, rather than reading on with pointers that cannot resolve.

Follow `$PIPELINE_ROOT/core/flows/fix-bug.md`.

Every bare `core/…` path inside that file — and inside every file it points
at — is relative to the pipeline root: read each one as
`$PIPELINE_ROOT/core/…`.

Dispatch exploration subagents with the `Task` tool.

Any text following the command invocation is input to the flow above; how
Cursor delivers that text to this file is not confirmed on this machine.
