# TASK-15 — Add a lean design check to self-review and code review

## Context

The pipeline delivers correct, tested code, but no step asks whether that code
is easy to change later. `core/phases/execute.md:167-183` (Step 6 —
Self-review) checks correctness, conventions, security, types, and edge cases;
`core/phases/code-review.md:75-213` (Step 3) reviews six dimensions — spec
compliance, conventions, security, test integrity, test quality, checklist —
and none of them judges design. `core/flows/fix-bug.md:199-213` (Step 6 —
Fix) has no self-review at all. `core/contracts/review-checklist-base.md` has
four sections (Security, Correctness, Tests, Data and migrations) and no
design section.

The two design defects that cost most when an agent later changes the code are
duplication and indirection: a rule copied into two places gets updated in one
and missed in the other, and every layer of abstraction is another file to
read before any change. This task adds a small, fast design check aimed at
exactly those, without a new phase and without a separate refactor step.

The guiding rule: code stays local and explicit, no rule is copied, and tests
cover it. Duplicated knowledge (a business rule, a validation, a conversion)
is a defect at the second copy; repeated structure is tolerated until the
third. Indirection around a dependency belongs at an input/output boundary,
where tests need to replace it. The project's own conventions win over all of
this: a pattern `paths.conventions` establishes is never a design finding.

The design signals are written once, as the `## Design` section of
`core/contracts/review-checklist-base.md`. Execute, fix-bug, and code-review
point at that section rather than restating it — restating it in four files
would be the very duplication the section forbids.

Two findings are blockers: reimplementing logic the codebase already has, and
copying a business rule. This is deliberate, with its cost accepted: a
blocker means `CHANGES_REQUESTED`, which stops the pipeline without looping
back (`core/phases/pipeline.md:209-216`) until an operator resumes execute
through `core/flows/resume.md`. To keep a judgement call from ending a run,
a blocker must cite the `file:line` of the existing code it duplicates; a
claim without that citation is a warning.

Every addition stays language- and stack-neutral, per
`core/contracts/review-checklist-base.md:10-13` and
`checks/core-is-neutral.sh`: no principle acronyms, no vocabulary that
assumes one paradigm, and none of the words the neutrality checker rejects as
tool names even in plain English — "poetry", "composer", "rollup" — nor any
word containing "cursor". Prose under `core/` is hard-wrapped at 77 columns
(`CLAUDE.md`, Formatting and lint).

## Approach

1. **Test infrastructure, red first.**
   - `checks/structure.sh:45` runs `grep -qxF "$h" "$path"`, which reads a
     required line that begins with `-` as a grep option: the call exits 2
     and the line is reported missing even when present. Change it to
     `grep -qxF -- "$h" "$path"`.
   - Add `tests/fixtures/structure-dash-heading.md` containing the single
     line `- A line that begins with a dash`, plus two manifest fixtures:
     `tests/fixtures/manifest-dash-heading.txt` with the row
     `tests/fixtures/structure-dash-heading.md|- A line that begins with a dash`,
     and `tests/fixtures/manifest-dash-heading-missing.txt` with the row
     `tests/fixtures/structure-dash-heading.md|- A line that is not there`.
   - Add `tests/fixtures/manifest-design.txt`, naming the exact lines this
     task introduces (`<path>|<line>;<line>`, one row per file):

     ```
     core/contracts/review-checklist-base.md|## Design
     core/phases/code-review.md|### 7. Design
     core/phases/execute.md|- **Reuse** — does something in the codebase already do this?;- **Simplicity** — does this add something the task does not need?
     core/flows/fix-bug.md|- **Reuse** — does something in the codebase already do what the fix adds?;- **Simplicity** — does the fix add something the defect does not need?
     core/flows/conventions.md|- **Seed content the checklist lacks.**
     ```

   - In `tests/run.sh`, after the structure-checker asserts (line 82), add:

     ```bash
     assert_exit 0 "structure checker matches a required line beginning with a dash" \
       checks/structure.sh tests/fixtures/manifest-dash-heading.txt
     assert_exit 1 "structure checker rejects a missing line beginning with a dash" \
       checks/structure.sh tests/fixtures/manifest-dash-heading-missing.txt
     assert_exit 0 "core files carry the design check" \
       checks/structure.sh tests/fixtures/manifest-design.txt
     ```

   Every fixture string must appear as a whole line, exactly as written, and
   none may contain `;`, which the checker splits on. Each line the fixture
   names is a deliberately short first line followed by a line break, and
   the break is intentional: a later rewrap that pulls the next word up
   breaks the match. The first and third asserts fail until the `--` fix
   and steps 2 to 5 land.

2. **`core/contracts/review-checklist-base.md` — the single source.**
   - Line 5: "four sections" becomes "five sections".
   - Add `## Design` between `## Tests` (lines 52-60) and
     `## Data and migrations` (line 62). It opens with this precondition, in
     the style of the Data section's (lines 64-65): every item yields to
     `paths.conventions` — a pattern the conventions establish is not a
     finding — and an item about layers applies only where the project has
     layers. Items, in the file's `- [ ] ` format with 6-space continuation:
     - The change calls logic the codebase already has instead of
       reimplementing it.
     - Each business rule lives in one place; changing it means editing one
       site.
     - The same non-trivial block does not appear three or more times in
       the change.
     - No abstraction, option, or extension point exists without a second
       implementation today — a test double counts — or a requirement that
       names it.
     - No implementation satisfies a contract with an operation that only
       signals "not supported" or silently does nothing.
     - Each function added or changed does one job and, where the project
       has layers, stays inside one.
     - Adding one case touched one site, not every place that branches on
       the set.
     - Indirection around a dependency sits at an input/output boundary —
       storage, network, clock, an external service — not around logic
       that does none.
   - `checks/manifest.txt` line 8: the row becomes
     `core/contracts/review-checklist-base.md|## Security;## Correctness;## Tests;## Design;## Data and migrations`.
   - `core/flows/conventions.md` Step 5, lines 139 and 144: "four sections"
     becomes "five sections". Lines 144-146 also claim the flow "only
     appends, the same way it only appends to the conventions file's managed
     section", which `core/contracts/conventions-template.md:91-92` and
     `core/phases/code-review.md:252` contradict (the managed section is
     regenerated wholesale). Replace that sentence with: "Never replace the
     seed's five sections — this flow only adds to the checklist, never
     removes from it."
   - `core/flows/conventions.md` `## Drift reporting` (lines 158-172): add a
     third bullet to the list, whose first line is exactly the fixture's
     string, followed by an intentional break:

     ```markdown
     - **Seed content the checklist lacks.**
       On a re-run, compare `paths.review_checklist` against
       `core/contracts/review-checklist-base.md`: insert each seed section
       the checklist lacks at its position in the seed, and add each seed
       item missing from a section the checklist has to the end of that
       section. Without this, content added to the seed later reaches only
       projects that derive their checklist for the first time.
     ```

     Unlike the other two bullets, this one needs no accept/edit/drop
     choice — the seed is never optional — and the paragraph after the list
     should say so in one sentence.

3. **`core/phases/code-review.md` — dimension 7.**
   - Line 77: "Work through all six in order." becomes "Work through all
     seven in order."
   - After dimension 6 ends (line 213, before `## Step 4`), append
     `### 7. Design`. Appending, not inserting, keeps the references to
     "dimension 6" / "sixth dimension" (lines 43, 56, 241) correct. Its body:
     - Check this task's diff against the `## Design` section of
       `core/contracts/review-checklist-base.md`, whether or not
       `paths.review_checklist` is set, and apply that section's precondition
       — `paths.conventions` first.
     - This dimension owns the Design items: dimension 6 does not grade them
       again when they reach `paths.review_checklist`, so one defect never
       carries two severities.
     - The first two items — reimplemented logic and a copied business
       rule — are blockers when the finding cites the `file:line` of the
       existing code duplicated, and warnings without that citation. Every
       other Design item is a warning.
   - Dimension 6, sub-step 3 (lines 197-200): add "except its `## Design`
     items, which dimension 7 owns".
   - Step 4 (lines 219-224): add "reimplemented existing logic or a copied
     business rule, cited per dimension 7" to **Blocker**, and "any other
     design finding from dimension 7" to **Warning**.
   - Step 5 (lines 236-243): after the dimension 6 bullet, add "The design
     result from dimension 7 — each blocker with the `file:line` of the
     code it duplicates, and each warning."

4. **`core/phases/execute.md` Step 6 — Self-review.** After the **Edge
   cases** bullet (lines 179-180), before "Rewrite anything that fails",
   add two bullets. The question is the whole first line; the break after
   it is intentional:

   ```markdown
   - **Reuse** — does something in the codebase already do this?
     Search for the concept, not the name just written. The full list of
     design signals is the `## Design` section of
     `core/contracts/review-checklist-base.md`, which code-review applies.
   - **Simplicity** — does this add something the task does not need?
     An abstraction earns its place with a second implementation today —
     a test double counts — or a Definition of Done item that names it.
   ```

5. **`core/flows/fix-bug.md`.**
   - Step 6 — Fix: after the paragraph ending "Note them in Step 8 instead."
     (line 206), add a lead-in and two bullets, scoped to the lines the fix
     adds so they never license editing the code around them:

     ```markdown
     Before verifying, hold the lines the fix adds to two questions:

     - **Reuse** — does something in the codebase already do what the fix adds?
       Then the fix calls it instead of adding a second copy.
     - **Simplicity** — does the fix add something the defect does not need?
       It needs no abstraction, option, or extension point the defect does
       not require.
     ```

     The first bullet's first line is 74 columns and must stay unbroken.
   - Step 8 — Report (line 238 onward): add one item — the answer to both
     questions, naming the existing code the fix calls when Reuse applied.
     fix-bug has no review gate, so the report is the only place the check
     is visible.

## Files to Modify

- `checks/structure.sh` — `--` before the grep pattern.
- `tests/fixtures/structure-dash-heading.md`,
  `tests/fixtures/manifest-dash-heading.txt`,
  `tests/fixtures/manifest-dash-heading-missing.txt`,
  `tests/fixtures/manifest-design.txt` — new fixtures.
- `tests/run.sh` — three `assert_exit` lines.
- `core/contracts/review-checklist-base.md` — "five sections", `## Design`.
- `checks/manifest.txt` — `## Design` in the checklist-base row.
- `core/flows/conventions.md` — "five sections", corrected Step 5 sentence,
  Drift reporting bullet.
- `core/phases/code-review.md` — "all seven", dimension 7, dimension 6
  exception, Step 4 and Step 5 additions.
- `core/phases/execute.md` — two Step 6 bullets.
- `core/flows/fix-bug.md` — Step 6 lead-in and bullets, Step 8 item.

## Definition of Done

- [ ] `checks/structure.sh` passes `--` to grep, and `tests/run.sh` asserts
      both that a present line beginning with `-` is accepted and that a
      missing one is rejected (Testing: "Assert both the accepting and the
      rejecting case for every checker").
- [ ] The `manifest-design.txt` assert fails on the pre-change repository and
      passes after; every string in that fixture appears as a whole line.
- [ ] `core/contracts/review-checklist-base.md` says "five sections" and has
      `## Design` with its conventions-first precondition and the eight
      items; `checks/manifest.txt` requires it.
- [ ] `core/phases/code-review.md` says "all seven" and has `### 7. Design`,
      pointing at the checklist base section, with the citation rule for its
      two blockers; dimension 6, Step 4, and Step 5 name it.
- [ ] `core/phases/execute.md` and `core/flows/fix-bug.md` carry the Reuse
      and Simplicity bullets without restating the Design list; fix-bug's
      Step 8 reports the answers.
- [ ] `core/flows/conventions.md` says "five sections", no longer claims the
      managed section is only appended to, and carries the Drift reporting
      bullet.
- [ ] No added line names a principle acronym, a language, or a tool, and
      `checks/core-is-neutral.sh` passes (Module boundaries: "Never name a
      harness ... or a third-party tool in `core/`").
- [ ] Added prose under `core/` wraps at 77 columns except the fixture lines'
      intentional breaks, with spaced em dashes and `- ` lists (Formatting
      and lint) — verified by review, since no checker enforces width.
- [ ] `commands.lint` and `commands.test_all` pass.

## Out of Scope

- Deriving how a project handles dependencies in the conventions flow — a
  separate task, which runs after this one because it relies on the `--` fix.
- A separate refactor step or a new phase.
- Looping `CHANGES_REQUESTED` back to execute automatically.
- `docs/presentation/tdd-pipeline-walkthrough.html` and `.pdf`, which still
  say "Six review dimensions".
- Renumbering or reordering the existing six dimensions.
- The stale `CLAUDE.md` discoveries about `grep -qF` and the missing `n/a`
  path.

## Agent Handoff Log
<!-- Phases append findings here — see handoff-log.md -->
