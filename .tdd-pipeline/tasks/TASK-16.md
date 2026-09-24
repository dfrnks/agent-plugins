# TASK-16 — Derive how a project handles dependencies in the conventions flow

## Context

The code the pipeline delivers should put indirection around a dependency only
at an input/output boundary — storage, network, clock, an external service —
where tests need to replace it, and should do it the way the project already
does. The design check added by TASK-15 defers to `paths.conventions` for
exactly that, so the conventions flow has to record it.

`core/flows/conventions.md:51-67` (Step 1 — Explore) dispatches one subagent
per area. Its "Module boundaries and layering" bullet says nothing about how
code reaches its input/output dependencies. Its sixth bullet, "Test structure
and mocking" (`core/flows/conventions.md:61`), covers replacing dependencies
in tests, but under a different name from the canonical list in
`core/contracts/conventions-template.md:52-58`, which calls the area
"Testing" — so the subagent explores under one name and the rules are
written under another. The test phase already studies "how dependencies
outside the code under test are isolated" (`core/phases/test.md:41-42`)
while writing a suite, but the conventions file never records it for execute
or code-review.

This task widens two existing areas instead of adding an eighth. The area
count "seven" appears twelve times across five files
(`core/contracts/conventions-template.md`, `core/flows/conventions.md`,
`core/flows/doctor.md`, `core/contracts/project-requirements.md`,
`core/flows/init.md`; the thirteenth match of `seven` under `core/`,
`core/phases/code-review.md:77`, counts review dimensions and is unrelated),
and a new heading would leave every existing
conventions file without it until the flow is re-run.

This task runs after TASK-15: its fixture names a line beginning with `-`,
which `checks/structure.sh` only matches once TASK-15's `--` fix has landed.

Prose under `core/` is hard-wrapped at 77 columns and stays language- and
stack-neutral (`checks/core-is-neutral.sh`): no named framework, container,
or library, and no word containing "cursor".

## Approach

1. **Red-first fixture.** Add `tests/fixtures/manifest-dependencies.txt`:

   ```
   core/flows/conventions.md|- Testing, including test structure and how tests replace dependencies
   core/contracts/conventions-template.md|Two areas reach further than their names suggest.
   ```

   and add to `tests/run.sh`, directly after the "core files carry the design
   check" assert (lines 87-88), before the adapter-coverage asserts:

   ```bash
   assert_exit 0 "conventions flow derives how dependencies are handled" \
     checks/structure.sh tests/fixtures/manifest-dependencies.txt
   ```

   Each string appears as a whole line, exactly as written, and contains no
   `;`. The template's line is a deliberately short first line followed by
   an intentional break; a rewrap that pulls the next word up breaks the
   match. The assert fails until steps 2 and 3 land.

2. **`core/flows/conventions.md` Step 1 — Explore (lines 56-62).** Replace
   the first and sixth bullets so the list reads:

   ```markdown
   - Module boundaries and layering, including how code reaches its
     input/output dependencies — storage, network, clock, an external
     service — and where the project places indirection around them
   - Error handling
   - Naming
   - Authentication and authorization
   - Data access
   - Testing, including test structure and how tests replace dependencies
   - Formatting and lint
   ```

   The sixth bullet is one line of 70 columns, exactly the fixture's string,
   and now carries the template's area name.

3. **`core/contracts/conventions-template.md` `## Area headings`.** After the
   numbered list (line 58), before "An area with no derived rules...", add:

   ```markdown
   Two areas reach further than their names suggest.
   "Module boundaries and layering" also records how code reaches its
   input/output dependencies — storage, network, clock, an external
   service — and where the project places indirection around them.
   "Testing" also records how tests replace those dependencies. Both
   describe what the project does, not what it should do: a project that
   calls its storage directly has that as its rule once the practice clears
   the bar in `core/flows/conventions.md` Step 2.
   ```

## Files to Modify

- `tests/fixtures/manifest-dependencies.txt` — new red-first manifest fixture.
- `tests/run.sh` — one `assert_exit` naming the fixture.
- `core/flows/conventions.md` — first and sixth Step 1 bullets.
- `core/contracts/conventions-template.md` — scope paragraph under
  `## Area headings`.

## Definition of Done

- [ ] `tests/run.sh` includes the assert naming
      `tests/fixtures/manifest-dependencies.txt`; it fails on the pre-change
      repository and passes after (Testing: "Assert both the accepting and
      the rejecting case").
- [ ] `core/flows/conventions.md` Step 1 names the sixth area "Testing",
      matching `core/contracts/conventions-template.md`, still covering test
      structure, and both widened bullets name input/output dependencies.
- [ ] `core/contracts/conventions-template.md` carries the scope paragraph,
      which defers to Step 2's bar, and the seven area headings and their
      order are unchanged.
- [ ] No added line names a framework, library, or language, and
      `checks/core-is-neutral.sh` passes (Module boundaries: "Never name a
      harness ... or a third-party tool in `core/`").
- [ ] Added prose under `core/` wraps at 77 columns except the fixture line's
      intentional break, with spaced em dashes (Formatting and lint).
- [ ] `commands.lint` and `commands.test_all` pass.

## Out of Scope

- An eighth area heading, and every "seven" count elsewhere.
- The design check in self-review and code review — TASK-15.
- Re-deriving this repository's own `CLAUDE.md`.
- `docs/`, including the presentation's list of areas.

## Agent Handoff Log
<!-- Phases append findings here — see handoff-log.md -->

### review (2026-09-24)
- Reviewed against main at 5be3dd1, after TASK-15 merged. Hard blockers
  cleared: no external API; every internal claim located —
  conventions.md:51-67/56-62/61, conventions-template.md:52-58 (with "An
  area with no derived rules" at :60), test.md:41-42 all match.
- Fixed drift: `grep -rn '\bseven\b' core/` now returns 13 matches in 6
  files; TASK-15 added code-review.md:77 ("all seven" dimensions). The
  Context now says twelve area-count occurrences and names that line as
  unrelated.
- Fixed drift: TASK-15 added three structure-checker asserts, so "after the
  structure-checker asserts" was ambiguous; the anchor is now the design
  check assert at tests/run.sh:87-88.
- Fixed: "external services" became "an external service" in both the
  Step 1 bullet and the template paragraph, matching
  review-checklist-base.md:83-85 word for word; this also removes a line
  that began with an em dash. The fixture lines are unchanged.
- Validated by simulation: the fixture exits 1 with "missing heading" for
  both lines today (no parse error); a control line beginning with `-`
  matches, confirming TASK-15's `--` fix; the proposed text passes
  core-is-neutral.sh; widths are within 77 apart from the intentional
  49-column break.
- Validated: execute.md:88-94, the conventions greenfield section, and
  CLAUDE.md's `## Testing` headings need no change; "mocking" survives only
  in `docs/`, which is out of scope.
- Not split: three Approach changes, six DoD items.

### test (2026-09-24)
- Wrote `tests/fixtures/manifest-dependencies.txt` (the two spec lines,
  verbatim, under a comment header in the `manifest-design.txt` style) and
  one `assert_exit 0` in `tests/run.sh` directly after the design check
  assert. 1 test added.
- Red for the right reason: `./tests/run.sh` gives 38 passed, 1 failed;
  the one failure is the new assert, and `checks/structure.sh` names both
  lines as "missing heading" in `core/flows/conventions.md` and
  `core/contracts/conventions-template.md`. The checker evaluates each line
  independently, so neither assertion hides behind the other. Every
  existing assert stayed green; no regression guard was added.
- Contract satisfiable: verified. Applied the Approach's text for steps 2
  and 3 in place from backed-up copies (restore on exit, checksums matched
  after), and got 39 passed, 0 failed, with `core-is-neutral.sh`,
  `structure.sh` and `references-resolve.sh` also passing. Expected values
  are the spec's own strings; nothing was computed.
- For execute: the fixture lines must appear as whole lines, exactly. The
  sixth bullet sits on one 70-column line, and the template paragraph's
  first line ends after "suggest." — a rewrap that pulls the next word up
  breaks the match. The old bullet "- Test structure and mocking" is
  replaced, not kept; the structure checker cannot assert its absence, so
  code review should confirm it is gone.
- `paths.conventions` (`CLAUDE.md`) holds a testing section; followed it
  (fixture as the red-first path for a prose-only change, per its
  `## Testing` note on `tests/run.sh:59`).
- No deviation from the spec's test expectations. Nothing escalated.

### execute (2026-09-24)

### Implementation Manifest
- DoD "tests/run.sh includes the assert naming
  tests/fixtures/manifest-dependencies.txt; it fails before and passes
  after" satisfied by tests/run.sh (test phase's assert, unchanged) —
  `./tests/run.sh` now gives 39 passed, 0 failed; red was 38/1 per the
  test entry.
- DoD "Step 1 names the sixth area Testing ... both widened bullets name
  input/output dependencies" satisfied by core/flows/conventions.md:56-58
  and core/flows/conventions.md:63 — first bullet names input/output
  dependencies and indirection; sixth bullet reads "Testing, including test
  structure and how tests replace dependencies"; "Test structure and
  mocking" no longer appears anywhere under core/.
- DoD "conventions-template.md carries the scope paragraph, defers to
  Step 2's bar, seven headings unchanged" satisfied by
  core/contracts/conventions-template.md:60-67 — paragraph inserted after
  the numbered list at :52-58, which is untouched; it cites
  `core/flows/conventions.md` Step 2 (heading at conventions.md:71).
- DoD "No added line names a framework, library, or language" satisfied by
  the lint run — `checks/core-is-neutral.sh` passes.
- DoD "Added prose wraps at 77 columns with spaced em dashes" satisfied by
  both core diffs — no added line exceeds 77 columns; the template's :60
  line is the intentional short break; every em dash is spaced.
- DoD "commands.lint and commands.test_all pass" — both exit 0.
- No entry point, authorization, validation, schema, or credential path
  touched: prose-only change.

### Conventions Applied
- Hard-wrap Markdown prose under `core/` at 77 columns — conventions:118
  → applied at core/contracts/conventions-template.md:60-67,
  core/flows/conventions.md:56-58
- Space every em dash on both sides — conventions:125 → applied at
  core/flows/conventions.md:57-58, core/contracts/conventions-template.md:62-63
- Reference a core file by its full `core/<dir>/<file>.md` path —
  conventions:22 → applied at core/contracts/conventions-template.md:67
- Never name a harness ... or a third-party tool in `core/` —
  conventions:11 → applied at both core diffs (core-is-neutral.sh passes)

### Notes
- Text applied verbatim from the Approach; no deviation. No test appeared
  wrong. Test protection gate: `git diff --name-only --diff-filter=MD HEAD
  -- tests` is empty. Nothing escalated.
