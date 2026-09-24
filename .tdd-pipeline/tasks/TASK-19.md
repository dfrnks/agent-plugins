# TASK-19 — Make the GitHub tracker create both status labels before editing

## Context

`core/trackers/github.md:52-57` (`set_status`, steps 3 and 4) creates only the
target label when it is missing, then runs
`gh issue edit <n> --add-label "<label>" --remove-label "<other-label>"` and
states that "the remove is a no-op, without error, the first time a given
issue is labeled at all".

That holds only when `<other-label>` already exists in the repository. When it
has never been created, `gh` rejects the whole edit and applies neither label:

```
failed to update https://github.com/<owner>/<repo>/issues/15: 'TASK:in-review' not found
failed to update 1 issue
```

So the first `set_status start` in a repository that has never used the
pipeline always fails. It happened on TASK-15 in this repository and had to be
worked around by hand (issue #19).

The chosen fix: step 3 makes sure both status labels exist, so step 4's single
edit command always succeeds. The removal is harmless in exactly one case —
the label exists in the repository but is not on the issue — and step 3 makes
that the only case left.

## Approach

1. **Red-first fixture.** Add `tests/fixtures/manifest-github-labels.txt`:

   ```
   core/trackers/github.md|3. Make sure both status labels exist in the repository.
   ```

   and add to `tests/run.sh`, directly after the "conventions flow derives
   how dependencies are handled" assert (the last structure-checker assert,
   before the adapter-coverage asserts):

   ```bash
   assert_exit 0 "github tracker creates both status labels before editing" \
     checks/structure.sh tests/fixtures/manifest-github-labels.txt
   ```

   The string appears as a whole line, exactly as written, and contains no
   `;`. It is a deliberately short first line followed by an intentional
   break; a rewrap that pulls the next word up breaks the match. The assert
   fails until step 2 lands.

2. **`core/trackers/github.md` `## set_status`, steps 3 and 4 (lines
   52-57).** Replace both steps with:

   ```markdown
   3. Make sure both status labels exist in the repository.
      List the repository's labels once, with
      `gh label list --limit 1000 --json name --jq '.[].name'` — the default
      limit of 30 would hide labels in a larger repository — and create each
      of the two that the list does not name exactly, with
      `gh label create "<label>"`. Never pass `--force`: it overwrites the
      colour and description of a label the project already customised.
   4. Apply the target label and remove the other: `gh issue edit <n>
      --add-label "<label>" --remove-label "<other-label>"`. `gh` rejects
      the whole edit when either label is missing from the repository,
      which step 3 rules out; removing a label the issue does not carry,
      such as the first time an issue is labeled at all, is harmless.
   ```

   Keep the wrap at 77 columns everywhere except the step 3 first line's
   intentional break. Leave steps 1 and 2 and `## resolve_or_create`
   untouched.

## Files to Modify

- `tests/fixtures/manifest-github-labels.txt` — new red-first manifest
  fixture.
- `tests/run.sh` — one `assert_exit` naming the fixture.
- `core/trackers/github.md` — `set_status` steps 3 and 4.

## Definition of Done

- [ ] `tests/run.sh` includes the assert naming
      `tests/fixtures/manifest-github-labels.txt`; it fails on the pre-change
      repository and passes after (Testing: "Assert both the accepting and
      the rejecting case").
- [ ] `set_status` step 3 lists labels with `--limit`, creates each missing
      status label, and forbids `--force`; step 4 no longer claims the
      removal is harmless without qualification.
- [ ] `checks/core-is-neutral.sh` passes (Module boundaries: harness and
      tool names stay out of `core/` — `gh` is already the tracker file's
      own integration and is not on the checker's list).
- [ ] Added prose wraps at 77 columns except the intentional break, with
      spaced em dashes (Formatting and lint).
- [ ] `commands.lint` and `commands.test_all` pass.

## Out of Scope

- `core/trackers/linear.md` and `core/trackers/none.md`.
- `tracker.states` handling and the label names themselves
  (`core/contracts/pipeline-config.md`).
- Label colours or descriptions.

## Agent Handoff Log
<!-- Phases append findings here — see handoff-log.md -->
