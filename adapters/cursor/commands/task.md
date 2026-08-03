Run a task end to end — spec, review gate, TDD pipeline, pull request.

Follow `.cursor/agent-pipeline/core/flows/task.md`.

Dispatch the pipeline orchestrator as the `task-pipeline` subagent via the `Task`
tool, with the created worktree as its working directory.

Any text following the command invocation is input to the flow above; how
Cursor delivers that text to this file is not confirmed on this machine.
