# Tracker: github

Selected by `tracker.type: github`. Per `pipeline-config.md`, this mode adds
no mandatory keys beyond the always-mandatory ones — no team, no required
states — because it can authenticate through `gh` and label through the
prefix every mode already requires. `tracker.states` is accepted but
optional here: set it to use named labels instead of the prefix-derived
defaults (see `set_status` below). A `tracker.states` block with only
`start` or only `review` set is a configuration error, not a
partial default — stop and name the missing half.

Every operation in this file runs through the `gh` CLI. Before the first
call, check `gh auth status`; if it fails, stop with a message telling the
user to authenticate (`gh auth login`) rather than proceeding or falling
back to `tracker.type: none`. A missing `gh` authentication is exactly the
kind of unavailable integration that must fail loudly: continuing without
it means code keeps shipping while the issue silently never gets touched,
and no one is told.

## resolve_or_create

Input: the argument passed to the task or plan flow — either a tracker
identifier or a free-text description.

1. If the argument is `#123`, `123`, or `<prefix>-123`, extract the number
   and resolve it with `gh issue view <n> --json number,title,body`.
2. Otherwise, treat the argument as a free-text description of new work and
   create the issue: `gh issue create --title "<t>" --body "<b>"`. Read the
   issue number back from the command's output.

Output: `<prefix>-<number>`, built from `tracker.prefix` and the resolved or
created issue number. Constructing the ID this way — rather than using the
bare number, or a GitHub-specific format — is what keeps the branch name
and spec filename identical in shape to the other two modes; no caller
downstream of this operation ever needs to know which tracker produced it.

## set_status

Input: a task ID and a phase (`start` or `review`).

This mode has no named workflow states, so a label stands in for one.

1. Determine the label name, per `pipeline-config.md`'s "Required keys by
   mode": if `tracker.states` is configured, both `start` and `review` must
   be present — a block with only one of the two is a configuration error;
   stop and name the missing half rather than defaulting it while honoring
   the one that was set. If `tracker.states` is absent entirely, use the
   defaults `<prefix>:in-progress` and `<prefix>:in-review`, built from
   `tracker.prefix`. Exactly one of the two labels is present on the issue
   at a time — the pair represents mutually exclusive states, not
   independent tags.
2. Recover the issue number from the task ID (`<prefix>-<number>`).
3. If the target label does not exist in the repository yet, create it
   first: `gh label create "<label>"`.
4. Apply it and remove the other: `gh issue edit <n> --add-label "<label>"
   --remove-label "<other-label>"`. The remove is a no-op, without error,
   the first time a given issue is labeled at all.
