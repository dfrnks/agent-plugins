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

This task widens two existing areas instead of adding an eighth. The count
"seven" appears twelve times across five files
(`core/contracts/conventions-template.md`, `core/flows/conventions.md`,
`core/flows/doctor.md`, `core/contracts/project-requirements.md`,
`core/flows/init.md`), and a new heading would leave every existing
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

   and add to `tests/run.sh`, after the structure-checker asserts:

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
     input/output dependencies — storage, network, clock, external
     services — and where the project places indirection around them
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
   input/output dependencies — storage, network, clock, external services
   — and where the project places indirection around them. "Testing" also
   records how tests replace those dependencies. Both describe what the
   project does, not what it should do: a project that calls its storage
   directly has that as its rule once the practice clears the bar in
   `core/flows/conventions.md` Step 2.
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
