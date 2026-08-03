# Tracker: linear

Selected by `tracker.type: linear`. `tracker.team` and `tracker.states` are
mandatory in this mode (see `pipeline-config.md`, "Required keys by mode");
missing either one is a fail-fast stop at step 0, before any of the
operations below run.

All operations in this file go through the Linear MCP server. If that
server is not connected — not configured, not authenticated, or the
connection fails at call time — the flow stops with a message naming the
missing connection and instructing the user to connect it, rather than
proceeding. Falling back to `tracker.type: none` in that situation is
explicitly forbidden: a silent fallback keeps the pipeline shipping code
while the tracker board quietly stops reflecting reality, and nobody is
told that happened. A loud stop costs one interruption; a silent one costs
a board nobody trusts.

## resolve_or_create

Input: the argument passed to the task flow — either a tracker identifier
or a free-text description.

1. If the argument matches the tracker's ID pattern (for example `ENG-123`),
   fetch that issue through the Linear MCP server. Use its identifier as
   the task ID and its description to seed the spec.
2. Otherwise, treat the argument as a free-text description of new work:
   - Ask the user, in a single question, for the project and the priority
     to file the issue under.
   - Create the issue on the team named by `tracker.team`, assigned to the
     current user.
   - Use the identifier Linear returns as the task ID.

Output: the task ID, used as-is for the branch name and the spec filename.

## set_status

Input: a task ID and a phase (`start` or `review`).

Move the issue to the state named by `tracker.states.start` or
`tracker.states.review`, matching the phase.

Before moving it, confirm the configured state name exists among the
team's workflow states. If it does not, stop and list the states that do
exist on the team, with a message naming the configured value that failed
to match. Never substitute the closest-looking state name — a state chosen
by resemblance rather than by the project's own configuration can silently
route the issue into the wrong stage of a workflow that has its own
downstream automation attached to it, and nothing in the pipeline would
notice.
