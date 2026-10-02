# Tracker: clickup

Selected by `tracker.type: clickup`. `tracker.workspace`,
`tracker.states`, and exactly one of `tracker.list` or `tracker.folder`
are mandatory in this mode (see `pipeline-config.md`, "Required keys by
mode"); missing any one of them, or setting both `list` and `folder`, is a
fail-fast stop at step 0, before any of the operations below run.

All operations in this file go through the ClickUp MCP server. If that
server is not connected — not configured, not authenticated, or the
connection fails at call time — the flow stops with a message naming the
missing connection and instructing the user to connect it, rather than
proceeding. Falling back to `tracker.type: none` in that situation is
explicitly forbidden, for the same reason `linear.md` gives: a silent
fallback keeps code shipping while the board quietly stops reflecting
reality. Pass `tracker.workspace` on every call; an account that belongs
to more than one workspace otherwise gets an error, or worse, the wrong
workspace.

## resolve_or_create

Input: the argument passed to the task or plan flow — either a tracker
identifier or a free-text description.

1. If the argument matches `<prefix>-<number>` (the prefix from
   `tracker.prefix`), fetch that task through the ClickUp MCP server by
   its custom ID. Use its custom ID as the task ID and its description to
   seed the spec. A task that does not exist is a stop naming the ID, not
   an invitation to create one under that number.
2. Otherwise, treat the argument as a free-text description of new work:
   - Resolve the target list. With `tracker.list`, use it. With
     `tracker.folder`, list the folder's lists and keep the ones whose
     date range contains today — a sprint folder holds one list per
     sprint, and the current one is the only right place for new work.
     Take the range from the list's start and due dates when the server
     returns them; otherwise from a range written in the list's name,
     such as `Sprint 53 (28/09/26 - 23/10/26)`, read day first. Exactly
     one match is the target. Zero or several matches is a
     stop that lists the folder's lists with their dates and asks the
     user to pick one; never choose the latest-looking name instead,
     because filing work into a closed or future sprint skews a board
     the whole team plans from.
   - Ask the user, in a single question, for the priority to file the
     task under.
   - Create the task in that list, assigned to the current user.
   - Read the custom ID back from the created task.

Output: the task's custom ID, used as-is for the branch name and the spec
filename. ClickUp is authoritative for its custom IDs, so this mode never
builds the ID from `tracker.prefix` and a number it chose itself.

Two guards apply to the custom ID, on the first one this mode resolves or
creates in a given run:

- If the task carries no custom ID — the space has custom task IDs
  turned off — stop and say so. The internal ClickUp ID is not a
  substitute: it does not match `<prefix>-<number>`, so the next
  `resolve_or_create` could never find the task again by the branch name.
- If the custom ID's prefix differs from `tracker.prefix`, stop with a
  message naming both values, rather than proceeding with a branch name
  and spec filename that quietly disagree with the tracker's own naming.

## set_status

Input: a task ID and a phase (`start` or `review`).

Move the task to the status named by `tracker.states.start` or
`tracker.states.review`, matching the phase.

Statuses in ClickUp belong to the task's list, folder, or space, so check
them against the task itself: fetch the task with its available statuses
and confirm the configured name is among them, comparing
case-insensitively, as ClickUp does. If it is not, stop and list the
statuses that do exist, with a message naming the configured value that
failed to match. Never substitute the closest-looking status — a status
chosen by resemblance can route the task into a stage with its own
automation attached, and nothing in the pipeline would notice.

Report one line in the same shape the other modes use:

```
tracker: clickup, <task-id> → <status>
```
