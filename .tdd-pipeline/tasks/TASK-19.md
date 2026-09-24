# TASK-19 — Make the GitHub tracker create both status labels before editing

## Context

`core/trackers/github.md:53-57` (`set_status`, steps 3 and 4) creates only the
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
   # TASK-19: github set_status creates both status labels before editing.
   core/trackers/github.md|3. Make sure both status labels exist in the repository.
   ```

   The comment line follows `tests/fixtures/manifest-dependencies.txt`.

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
   53-57).** Replace both steps with the text below. The block is indented
   here only because it sits inside this list: in `github.md` each step
   starts at column 0, like the existing steps, and the fixture line must
   match `3. Make sure both status labels exist in the repository.` at
   column 0.

   ```markdown
   3. Make sure both status labels exist in the repository.
      List the repository's labels once, with
      `gh label list --limit 1000 --json name --jq '.[].name'` — the default
      limit of 30 would hide labels in a larger repository — and create each
      of the two that the list does not name, with
      `gh label create "<label>"`. Compare names case-insensitively, as
      GitHub does, and treat an "already exists" failure from the create as
      success — the label is there, whether a differently cased name or a
      parallel run put it there. Never pass `--force`: it overwrites the
      color and description of a label the project already customized.
   4. Apply the target label and remove the other: `gh issue edit <n>
      --add-label "<label>" --remove-label "<other-label>"`. `gh` rejects
      the whole edit when either label is missing from the repository,
      which step 3 rules out; removing a label the issue does not carry,
      such as the first time an issue is labeled at all, is harmless.
   ```

   Keep the wrap at 77 columns. Lines end short only at the step 3 first
   line's intentional break and before a code span that cannot break. Use
   American spelling ("color", "customized"), matching `github.md`'s own
   "honoring" and "labeled" and `gh`'s `--color` flag. Leave steps 1 and 2 and `## resolve_or_create`
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
- [ ] `set_status` step 3 lists labels with `--limit`, compares names
      case-insensitively, creates each missing status label, treats "already
      exists" as success, and forbids `--force`; step 4 no longer claims the
      removal is harmless without qualification.
- [ ] `checks/core-is-neutral.sh` passes (Module boundaries: harness and
      tool names stay out of `core/` — `gh` is already the tracker file's
      own integration and is not on the checker's list).
- [ ] Added prose wraps at 77 columns, short only at the intentional break
      and before unbreakable code spans, with spaced em dashes (Formatting
      and lint).
- [ ] `commands.lint` and `commands.test_all` pass.

## Out of Scope

- `core/trackers/linear.md` and `core/trackers/none.md`.
- `tracker.states` handling and the label names themselves
  (`core/contracts/pipeline-config.md`).
- Label colours or descriptions.

## Agent Handoff Log
<!-- Phases append findings here — see handoff-log.md -->

### review (2026-09-24)
- Hard blockers cleared. No external API schema beyond `gh` flags, all
  checked against `gh label list --help` and `gh label create --help` on
  gh 2.97.0: `--limit` (default 30), `--json name`, `--jq` exist;
  `gh label create` without `--force` fails with "already exists" on an
  existing label. The listing command ran read-only and printed both
  `TASK:` labels. Internal claim located: github.md steps 3-4 are at
  lines 53-57 (the draft said 52-57; fixed).
- Fixed: GitHub label names are case-insensitive, so an exact comparison
  could miss `task:in-progress` and then fail to create `TASK:in-progress`.
  Step 3 now compares case-insensitively and treats "already exists" as
  success, which also covers two runs creating the same label at once.
- Fixed: the replacement block is indented in the spec only because it
  sits in a list; stated that each step starts at column 0 in github.md,
  since `grep -qxF` would not match an indented fixture line.
- Fixed: spelling set to American ("color", "customized"), matching
  github.md ("honoring", "labeled"); core/ has no prior "color"/"colour".
- Fixed: the wrap rule now allows short lines before unbreakable code
  spans; the fixture gains a `#` comment like manifest-dependencies.txt.
- Validated: nothing else in core/, README.md, CLAUDE.md, or docs/
  describes label creation or removal; pipeline-config.md:155-169 covers
  names only. Assert placement after tests/run.sh:89-90 is correct.
- Left as-is: step 4's claim that removing a label the issue does not
  carry is harmless could not be confirmed read-only; it matches GitHub's
  API behaviour and was observed during TASK-16, whose `set_status start`
  removed the then-existing, not-carried `TASK:in-review` without error.
- Not split: two Approach changes, five DoD items.

### test (2026-09-24)
- Tests: `tests/fixtures/manifest-github-labels.txt` (new, one record) and
  one `assert_exit 0` in `tests/run.sh` after the "conventions flow derives
  how dependencies are handled" assert. 1 test added.
- Red: `./tests/run.sh` reports 39 passed, 1 failed. The one failure is the
  new test, "github tracker creates both status labels before editing",
  with `missing heading in core/trackers/github.md: 3. Make sure both status
  labels exist in the repository.` That line is missing because step 3 is
  not written yet, not because the test is broken. All 39 existing tests
  still pass, and none of them was written as a regression guard for this
  task.
- Satisfiable: yes. I pasted the spec's step 3 and 4 block, exactly as the
  spec gives it at column 0, into a copy-backed `core/trackers/github.md`.
  With that in place `./tests/run.sh` gave 40 passed, 0 failed, and
  `checks/core-is-neutral.sh`, `checks/no-leakage.sh`,
  `checks/references-resolve.sh` and `checks/structure.sh` all exited 0.
  I restored the file from the copy (checksum matched) and saw red again.
  The expected value comes from the spec's Approach step 2 text, not from
  anything computed.
- Coverage limit: this fixture pins only step 3's first line. Nothing in
  the suite checks the rest of DoD item 2 (`--limit`, case-insensitive
  compare, "already exists" as success, no `--force`, step 4's
  qualified claim), and nothing checks the 77-column wrap. Code review
  has to check those by reading the file. This follows the spec, which
  asks for exactly one fixture line; the structure checker matches only
  whole lines, and the rest of the text is wrapped prose it cannot pin
  reliably.
- Line-match caveat for execute: `checks/structure.sh` uses `grep -qxF`,
  so the step 3 line must be exactly `3. Make sure both status labels
  exist in the repository.` at column 0, with no trailing whitespace and
  nothing after it on that line.
- Conventions: `CLAUDE.md` has a testing section (two, in fact). I followed
  its red-first fixture pattern for prose-only changes and its
  `<subject>-<condition>` fixture naming.
- Deviations from the spec: none.

### execute (2026-09-24)

### Implementation Manifest
- DoD "`tests/run.sh` includes the assert naming
  `tests/fixtures/manifest-github-labels.txt`; it fails on the pre-change
  repository and passes after" satisfied by tests/run.sh (test phase,
  commit afb49ba) — red before this change (39/1), green after (40/0).
- DoD "`set_status` step 3 lists labels with `--limit`, compares names
  case-insensitively, creates each missing status label, treats 'already
  exists' as success, and forbids `--force`; step 4 no longer claims the
  removal is harmless without qualification" satisfied by
  core/trackers/github.md:53-62 (step 3) and core/trackers/github.md:63-67
  (step 4) — text is the spec's Approach step 2 block verbatim, at column 0.
- DoD "`checks/core-is-neutral.sh` passes" satisfied by
  core/trackers/github.md:53-67 — the checker exits 0 as part of
  `commands.lint`.
- DoD "Added prose wraps at 77 columns ... with spaced em dashes" satisfied
  by core/trackers/github.md:53-67 — no line exceeds 77 columns (awk
  length check); lines end short only at :53 (intentional break) and :54,
  :57 (before unbreakable code spans); all three em dashes are spaced.
- DoD "`commands.lint` and `commands.test_all` pass" — `./tests/run.sh`
  40 passed, 0 failed; the full lint command exits 0.
- Checklist-relevant areas: none — no entry point, authorization,
  validation, schema, or credential path touched; prose only.

### Conventions Applied
- Hard-wrap Markdown prose under `core/` at 77 columns — conventions:118
  → applied at core/trackers/github.md:53-67
- Space every em dash on both sides — conventions:125 → applied at
  core/trackers/github.md:55,60
- Use `N. ` for an ordered list — conventions:121 → applied at
  core/trackers/github.md:53,63
- Stage named paths; never `git add .` — conventions:92 → applied at the
  commit of this phase
- Never name a third-party tool in `core/` — conventions:11 → not
  violated in effect: `gh` was already named in this tracker file and is
  not on `checks/core-is-neutral.sh`'s list, as the spec's DoD states;
  flagging for review that the rule's prose and the checker's list differ.

### Notes
- Deviations from the spec: none. Steps 1, 2, and `## resolve_or_create`
  untouched.
- Test protection gate: `git diff --name-only --diff-filter=MD HEAD --
  tests` was empty.
- No escalation to CLAUDE.md or phase memory.

### code-review (2026-09-24)
- Diff read in full from merge base 9cd2ca5: afb49ba (test) touched
  `tests/fixtures/manifest-github-labels.txt` (new) and `tests/run.sh`
  (+2 lines); 3976f73 (execute) touched `core/trackers/github.md` and this
  spec. Files match `## Files to Modify` exactly; nothing extra, nothing
  missing.

#### Blockers
- None.

#### Warnings
- CLAUDE.md:11 ("Never name ... a third-party tool in `core/`") is
  contradicted by `core/trackers/github.md`, which has always named `gh`
  and now names it more (lines 55, 58, 64-65). `checks/core-is-neutral.sh:11`
  does not list `gh`, so lint passes. Execute flagged this; the spec's DoD
  item 3 sanctions it. The rule's prose should carve out a tracker file's
  own integration CLI, or the checker and prose will keep disagreeing.
- Test quality: the only new test pins step 3's first line. DoD item 2's
  substance (`--limit`, case-insensitive compare, "already exists" as
  success, no `--force`, step 4's qualified claim) and DoD item 4 (wrap)
  are verified only by this review reading the file, not by any test. The
  spec asked for exactly this, so it is not a deviation, but a later edit
  can drop any of those clauses without the suite noticing.

#### Suggestions
- Conventions Applied cites the em dashes at github.md:55,60; there are
  three, at :55, :56, and :60. All are spaced, so only the pointer is short.

#### Dimension results
- Spec compliance: all five DoD items satisfied. github.md:53-67 is the
  spec's Approach step 2 block byte-for-byte (diffed after stripping the
  3-space list indent); steps 1, 2 and `## resolve_or_create` untouched.
  `./tests/run.sh` 40 passed, 0 failed; the full `commands.lint` exits 0.
  Red confirmed independently: at afb49ba `checks/structure.sh
  tests/fixtures/manifest-github-labels.txt` exits 1 naming the missing
  line; at HEAD it exits 0. Deviations: none documented, none found.
- Conventions: each citation resolved by text search in CLAUDE.md, and all
  line numbers hold: wrap at 77 (:118), em dashes (:125), `N. ` lists
  (:121), named-path staging (:92), third-party tools (:11). Longest
  changed line is 73 columns; short lines only at :53, :54, :57, as the
  spec permits. No "no rule found" lines; no `→ Escalated to` lines; no
  earlier phase of this task added to CLAUDE.md.
- Security and isolation: not applicable. Prose only; no entry point,
  input path, tenant boundary, or secret. No `gh` command was run against
  the repository during review.
- Test integrity: `tests/` was touched only by afb49ba (the test phase).
  `git diff afb49ba HEAD -- tests` is empty, so execute changed no test.
  Inspected, not just listed. No test was flagged as appearing wrong.
- Test quality: fixture named `<subject>-<condition>`, with a `#` comment
  like manifest-dependencies.txt; assert placed after the dependencies
  assert per the spec. Coverage gap recorded under Warnings. No production
  logic exists to accommodate a test.
- Checklist verification: `paths.review_checklist` is not configured. The
  manifest was spot-checked on the two least obvious lines: DoD item 2 →
  github.md:53-67 (held: every required clause present) and DoD item 4 →
  wrap and em dashes (held, except the em-dash pointer noted above).
  Manifest present and otherwise accurate.
- Design: not applicable. The diff adds no code (prose and tests only).

#### Verdict
APPROVED_WITH_WARNINGS
