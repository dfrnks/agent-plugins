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
     core/flows/conventions.md|On a re-run, bring an existing checklist up to the seed.
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
   and steps 2 to 5 land. The second assert passes from the start — before
   the fix the checker already exits 1 there, for the wrong reason — and
   stays as the guard that the fix does not start accepting a missing line.

   - **`CLAUDE.md` discoveries span (lines 137-155), with the `--` fix.**
     The `## Testing` entry at lines 141-145 describes `checks/structure.sh` wrongly — it cites line
     18 (the match is at line 45), says `grep -qF` and "unanchored" (the code
     uses `grep -qxF`, a whole-line match) — and TASK-16 depends on how that
     match behaves. Rewrite that one entry, in place inside the span, to:
     `checks/structure.sh:45` matches each required line as a whole line with
     `grep -qxF --`: a heading merely mentioned in prose no longer satisfies
     it, a line beginning with `-` is matched rather than read as an option,
     and a required string cannot contain `;`, which the checker splits a
     row on. Leave every other entry, and the managed section, untouched.

2. **`core/contracts/review-checklist-base.md` — the single source.**
   - Line 5: "four sections" becomes "five sections".
   - Add `## Design` between `## Tests` (lines 52-60) and
     `## Data and migrations` (line 62). The section has no precondition —
     it applies to every project — but opens with a precedence rule, worded
     without naming a configuration key, since this seed is copied into
     project checklists: "The project's own conventions come first: a
     pattern they establish is never a finding here, even where an item
     below would flag it." Items, in the file's `- [ ] ` format with 6-space
     continuation:
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
     - Each function added or changed does one job. When the project has
       layers: it stays inside one. A project without layers marks that half
       not applicable. (This follows the in-item condition style of the
       Security section, lines 31-34.)
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
   - Directly after that sentence, still in Step 5 and before its commit
     block, add a paragraph whose first line is exactly the fixture's
     string, followed by an intentional break:

     ```markdown
     On a re-run, bring an existing checklist up to the seed.
     Compare `paths.review_checklist` against
     `core/contracts/review-checklist-base.md`: insert each seed section the
     checklist lacks at its position in the seed, and add each seed item
     missing from a section the checklist has to the end of that section.
     This needs no confirmation in Step 3 — the seed is never optional.
     Without it, content added to the seed later reaches only projects that
     derive their checklist for the first time.
     ```

     `## Drift reporting` stays unchanged: it covers the conventions file's
     managed section, not the checklist.

3. **`core/phases/code-review.md` — dimension 7.**
   - Line 77: "Work through all six in order." becomes "Work through all
     seven in order."
   - After dimension 6 ends (line 213, before `## Step 4`), append
     `### 7. Design`. Appending, not inserting, keeps the references to
     "dimension 6" / "sixth dimension" (lines 43, 56, 241) correct. Its body
     opens with one framing sentence, as dimension 5 does — this dimension
     asks whether the change will be cheap to change again: no second copy
     of anything, no indirection nothing needs — then:
     - Check this task's diff against the `## Design` section of
       `core/contracts/review-checklist-base.md`, whether or not
       `paths.review_checklist` is set, and apply that section's
       conventions-first rule against `paths.conventions`.
     - A diff that adds or changes no code — prose, configuration, or tests
       only — reports this dimension not applicable, as dimension 3 does
       for a project with no notion of separate owners of data.
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
   - Step 8 — Report (lines 238-251): directly after the **Fix** item, add

     ```markdown
     - **Design** — the answers to Step 6's Reuse and Simplicity questions,
       naming the existing code the fix calls when Reuse applied.
     ```

     fix-bug has no review gate, so the report is the only place the check
     is visible.

## Files to Modify

- `checks/structure.sh` — `--` before the grep pattern.
- `CLAUDE.md` — rewrite the stale `checks/structure.sh` discovery.
- `tests/fixtures/structure-dash-heading.md`,
  `tests/fixtures/manifest-dash-heading.txt`,
  `tests/fixtures/manifest-dash-heading-missing.txt`,
  `tests/fixtures/manifest-design.txt` — new fixtures.
- `tests/run.sh` — three `assert_exit` lines.
- `core/contracts/review-checklist-base.md` — "five sections", `## Design`.
- `checks/manifest.txt` — `## Design` in the checklist-base row.
- `core/flows/conventions.md` — "five sections", corrected Step 5 sentence,
  Step 5 re-run paragraph.
- `core/phases/code-review.md` — "all seven", dimension 7, dimension 6
  exception, Step 4 and Step 5 additions.
- `core/phases/execute.md` — two Step 6 bullets.
- `core/flows/fix-bug.md` — Step 6 lead-in and bullets, Step 8 **Design**
  item.

## Definition of Done

- [ ] `checks/structure.sh` passes `--` to grep, and `tests/run.sh` asserts
      both that a present line beginning with `-` is accepted and that a
      missing one is rejected (Testing: "Assert both the accepting and the
      rejecting case for every checker"), and the `CLAUDE.md` discovery
      about it is rewritten inside the discoveries span only.
- [ ] The `manifest-design.txt` assert fails on the pre-change repository and
      passes after; every string in that fixture appears as a whole line.
- [ ] `core/contracts/review-checklist-base.md` says "five sections" and has
      `## Design` with its conventions-first opening rule, no precondition,
      and the eight items; `checks/manifest.txt` requires it.
- [ ] `core/phases/code-review.md` says "all seven" and has `### 7. Design`,
      pointing at the checklist base section, with the citation rule for its
      two blockers and its not-applicable rule for a diff with no code;
      dimension 6, Step 4, and Step 5 name it.
- [ ] `core/phases/execute.md` and `core/flows/fix-bug.md` carry the Reuse
      and Simplicity bullets without restating the Design list; fix-bug's
      Step 8 carries the **Design** item after **Fix**.
- [ ] `core/flows/conventions.md` says "five sections", no longer claims the
      managed section is only appended to, and carries the re-run paragraph
      in Step 5; `## Drift reporting` is unchanged.
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
- The stale `CLAUDE.md` discovery about the missing `n/a` path, and any
  change to the managed section of `CLAUDE.md`.
- `## Drift reporting` in `core/flows/conventions.md`.

## Agent Handoff Log
<!-- Phases append findings here — see handoff-log.md -->

### review (2026-09-24)
- Hard blockers cleared. No external API is involved. Every internal claim
  was located: all cited `file:line` references in the body were checked
  against the files at commit 8cf26d8 and match (structure.sh:45,
  execute.md:167-184, code-review.md:43/56/77/197-200/213/217-225/235-243/252,
  fix-bug.md:199-213/238-251, review-checklist-base.md:5/10-13/52-65,
  conventions.md:139/144-146/158-172, conventions-template.md:91-92,
  pipeline.md:209-216, run.sh:82, manifest.txt:8).
- Fixed: the `## Design` opener was called a precondition but could never
  make the section not applicable (review-checklist-base.md:15-21 defines a
  precondition as exactly that). It is now a precedence rule with no
  precondition and no configuration key, since the seed is copied into
  project checklists; the layer condition moved inside its item, in the
  Security section's style (lines 31-34). Dimension 7 now says
  "conventions-first rule".
- Fixed: dimension 7 lacked the framing sentence dimensions 3 and 5 open
  with and any not-applicable rule; both added (a diff with no code).
- Fixed: the checklist re-run bullet was placed in `## Drift reporting`,
  which is about the conventions file's managed section and feeds Step 3's
  accept/edit/drop choice — a category error that forced an exception
  sentence. It is now a Step 5 paragraph; the fixture line changed with it.
- Fixed: fix-bug Step 8's new item had no text or position; it is now a
  **Design** item after **Fix**.
- Fixed: stated that the dash-rejection assert passes from the start
  (structure.sh exits 1 for the wrong reason pre-fix) and why it stays.
- Added to scope: `CLAUDE.md:141-145` misdescribes `checks/structure.sh`
  (line 18, `grep -qF`, "unanchored"); the `--` fix would make it wrong a
  fourth way and TASK-16 relies on the behaviour. Folded into step 1 so
  Approach stays at five changes. Only the discoveries span is edited.
- Validated: nothing else counts dimensions or checklist sections outside
  `docs/` (excluded) and the historical design spec; README.md, agents/,
  adapters, doctor.md, project-requirements.md need no change.
- Validated: new fixtures trip no checker — references-resolve scans only
  `*.md` and skips `tests/fixtures/` in whole-repo mode; no-leakage skips
  fixtures; core-is-neutral scans only `core/`.
- Test split: the test phase writes only `tests/` (fixtures, run.sh), giving
  two red asserts; `checks/structure.sh`, `checks/manifest.txt`, and the
  prose are execute's. The real-manifest assert (run.sh:81-82) goes red
  only if execute edits manifest.txt:8 before adding `## Design`.
- Not split: five Approach changes, nine DoD items.

### test (2026-09-24)
- Wrote 3 asserts in `tests/run.sh` (after the real-manifest assert) and
  four fixtures: `tests/fixtures/structure-dash-heading.md`,
  `tests/fixtures/manifest-dash-heading.txt`,
  `tests/fixtures/manifest-dash-heading-missing.txt`,
  `tests/fixtures/manifest-design.txt`. The manifest fixtures open with a
  `#` comment line, as every existing manifest fixture does.
- Red, 36 passed / 2 failed, matched name by name against the tally:
  "structure checker matches a required line beginning with a dash" fails
  because grep reads `- A line…` as an option (`grep: invalid option`),
  exit 1; "core files carry the design check" fails on all seven missing
  lines (the four dash lines also hit the grep option error). Both trace to
  missing behaviour, not a broken fixture.
- Regression guard, green by design: "structure checker rejects a missing
  line beginning with a dash" exits 1 now (for the wrong reason, grep's
  option error) and must stay 1 after the `--` fix. Every pre-existing
  assert still passes.
- Satisfiability: verified. With `--` applied in place to
  `checks/structure.sh:45` (copy taken aside, restore trapped, checksum
  confirmed identical afterwards), the dash-present fixture exits 0 and
  the dash-missing fixture exits 1 with "missing heading ... - A line that
  is not there". The design fixture's strings, run against scratch samples
  built from the spec's Approach text (steps 2-5), exit 0. Anchor: the
  spec's own Approach wording; no value was computed.
- For execute: `checks/structure.sh` must get the `--` fix or every dash
  line in `manifest-design.txt` stays red regardless of the prose. Each
  fixture string must land as a whole line, byte for byte, including the
  spaced em dashes and `**` markup.
- `paths.conventions` (`CLAUDE.md`) holds a testing section; followed it
  (accept and reject case for the dash line, fixture under `paths.tests`
  for a prose change).
- No deviation from the spec's test expectations. `tests/run.sh` also
  touches no checker; `checks/manifest.txt` is left to execute.

### execute (2026-09-24)

### Implementation Manifest
- DoD "`checks/structure.sh` passes `--` to grep ... and the `CLAUDE.md`
  discovery about it is rewritten inside the discoveries span only"
  satisfied by checks/structure.sh:45 — `grep -qxF -- "$h" "$path"`; the
  dash asserts are tests/run.sh (test phase); CLAUDE.md:141-144 — the
  entry is rewritten in place between the discoveries markers, the other
  entry and the managed section untouched.
- DoD "The `manifest-design.txt` assert fails on the pre-change repository
  and passes after" satisfied by the prose below — red at 538a54e per the
  test entry, green now (38 passed, 0 failed).
- DoD "review-checklist-base.md says five sections and has `## Design`"
  satisfied by core/contracts/review-checklist-base.md:5 and :62-85 —
  precedence opener, no precondition, eight `- [ ] ` items;
  checks/manifest.txt:8 requires `## Design`.
- DoD "code-review.md says all seven and has `### 7. Design`" satisfied by
  core/phases/code-review.md:77, :216-235 (framing sentence, pointer to the
  checklist base section, not-applicable rule, ownership, citation rule),
  :199 (dimension 6 exception), :241-247 (Step 4), :267-268 (Step 5).
- DoD "execute.md and fix-bug.md carry the Reuse and Simplicity bullets ...
  fix-bug's Step 8 carries **Design** after **Fix**" satisfied by
  core/phases/execute.md:181-187, core/flows/fix-bug.md:208-215 and
  :253-254. Neither restates the Design list; execute points at it.
- DoD "conventions.md says five sections, no longer claims append-only,
  carries the re-run paragraph; `## Drift reporting` unchanged" satisfied
  by core/flows/conventions.md:139, :144-145, :147-154. Drift reporting
  is not in the diff.
- DoD "No added line names a principle acronym, a language, or a tool"
  — `checks/core-is-neutral.sh` passes; a grep of added lines for common
  principle acronyms and the rejected tool words found none.
- DoD "Added prose under `core/` wraps at 77 columns" — every added line
  under `core/` and in `CLAUDE.md` measured at 77 columns or fewer;
  spaced em dashes and `- ` lists throughout.
- DoD "`commands.lint` and `commands.test_all` pass" — both clean.
- Checker behaviour change — checks/structure.sh:45 — `--` ends option
  parsing, so a required line beginning with `-` is matched literally; no
  other checker changed.

### Conventions Applied
- Hard-wrap Markdown prose under `core/` at 77 columns — conventions:118
  → applied at core/phases/code-review.md:77-78 (rewrapped after "seven"
  lengthened the line), and every added core line
- Hard-wrap Markdown prose outside `core/` at 80 columns — conventions:120
  → applied at CLAUDE.md:141-144
- Space every em dash on both sides — conventions:125 → applied at
  core/contracts/review-checklist-base.md:74,83
- Use `- ` for an unordered list — conventions:121 → applied at
  core/flows/fix-bug.md:210-215
- Never name a harness ... or a third-party tool in `core/` —
  conventions:11 → applied across all core additions (checker passes)
- Reference a core file by its full `core/<dir>/<file>.md` path —
  conventions:22 → applied at core/phases/code-review.md:221,
  core/phases/execute.md:184
- Stage named paths; never `git add .` — conventions:92 → applied at the
  commit of this phase

### Notes
- No deviation from the spec's wording. The dimension 7 body is a framing
  sentence plus the spec's four points as `- ` bullets; the dimension 6
  exception is appended to sub-step 3's first sentence as
  "— except its `## Design` items, which dimension 7 owns."
- The fix-bug lead-in and bullets sit directly after the "Note them in
  Step 8 instead." paragraph, before the "Do not weaken" paragraph, as the
  spec places them.
- No test file modified: `git diff --name-only --diff-filter=MD HEAD --
  tests` is empty. No test appeared wrong.
- No escalation: the one durable fact (structure.sh's whole-line match) is
  the CLAUDE.md discovery rewrite the spec already asked for.

### code-review (2026-09-24)
- Diff read in full: `git diff main...HEAD` (538a54e test, eb1a104
  execute). Changed files match `## Files to Modify` exactly — no extra
  file, none left untouched. `## Drift reporting` (conventions.md:168 on)
  is not in the diff.
- Spec compliance: all nine DoD items satisfied. Pre-change red confirmed
  independently in a detached worktree at 538a54e: the dash-accept and
  design-fixture asserts fail, `checks/structure.sh
  tests/fixtures/manifest-design.txt` exits 1; at HEAD 38 passed, 0
  failed, and `commands.lint` exits 0. Wording matches the spec's Approach
  text for every added block; dimension 7 carries the framing sentence,
  the checklist-base pointer, the not-applicable rule, the ownership rule,
  and the `file:line` citation rule for its two blockers; Step 4 and Step
  5 name it; dimension 6 sub-step 3 carries the exception
  (code-review.md:199). Nothing Out of Scope was touched or is missing.
- Neutrality and format: added lines under `core/` and `CLAUDE.md` grepped
  for principle acronyms, language and tool names, and "cursor",
  "poetry", "composer", "rollup" — none; `checks/core-is-neutral.sh`
  passes. Every added line is 77 columns or fewer; em dashes spaced
  (including the line-leading dash at code-review.md:227); `- ` lists
  only.
- Conventions: every `### Conventions Applied` citation resolves —
  CLAUDE.md:11, :22, :92, :118, :120, :121, :125 each hold the cited rule,
  and the applied locations follow it. No "no rule found" lines. The
  rewritten `CLAUDE.md` discovery cites `checks/structure.sh:45`, which is
  the `grep -qxF --` line. No `→ Escalated to` lines to check.
- Security and isolation: not applicable — no entry point, input
  boundary, owner-scoped data, or credential in this project's change.
- Test integrity: only 538a54e touched `tests/`; eb1a104 changed no file
  under `tests/` (`git diff 538a54e HEAD -- tests` is empty). Inspected,
  not merely listed. No test flagged as appearing wrong.
- Test quality: each checker change has an accept and a reject assert
  (dash present / dash missing); the prose DoD items are covered by
  `manifest-design.txt`. No production code exists only for a test — the
  `--` fix corrects option parsing for any caller.
- Manifest spot-check: checked structure.sh:45 (the only code change, and
  the one TASK-16 depends on) — holds; code-review.md:216-235 (least
  obvious mapping: the citation rule for blockers) — holds; fix-bug.md:253
  (**Design** after **Fix**) — holds. The Step 4 range is cited as
  :241-247 where the Blocker bullet starts at :240; cosmetic, not a
  finding. No `paths.review_checklist` configured, so no checklist scan.
- Design (dimension 7): the only code change is one token in
  checks/structure.sh:45 — no reimplementation, no copied rule, no new
  indirection. The design signals are written once
  (review-checklist-base.md:62-85) and execute.md:181-187, fix-bug.md:
  208-215, and code-review.md:216-235 point at it without restating it.
  No findings.
- Blockers: none. Warnings: none.
- Suggestion: the rewritten CLAUDE.md:141-144 discovery says a prose
  mention "no longer" satisfies the check — wording relative to history
  in an entry meant to state a durable fact; "does not" would read
  cleaner. Optional.
- No escalation.
- Verdict: APPROVED.
