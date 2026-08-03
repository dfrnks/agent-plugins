# Conventions template contract

The conventions flow writes derived rules into the project's conventions
file — the one named by `paths.conventions`. That file usually already
exists, holding prose a human wrote by hand: team norms, links, context that
has nothing to do with any single flow run. The conventions flow must be
able to add to that file, and to re-run later and refresh what it added,
without ever touching the surrounding prose. This contract defines the
markers and headings that make that possible.

## Managed section markers

The conventions flow owns everything between these two marker lines, and
nothing outside them:

```markdown
<!-- pipeline:conventions:start -->
... generated rules ...
<!-- pipeline:conventions:end -->
```

- On every run, the flow replaces only the text between the markers.
  Anything written above `<!-- pipeline:conventions:start -->` or below
  `<!-- pipeline:conventions:end -->` is hand-written prose and is never
  read, moved, or rewritten.
- If the markers are absent from the file, the flow appends them — and the
  generated block between them — to the end of the file. It does not
  rewrite or reorder any existing content to make room.
- If only one marker is present, or the markers appear out of order, the
  flow treats the file as malformed and stops rather than guessing which
  span it owns.
- The doctor flow's five-item threshold (see `project-requirements.md`) is
  counted only across list items and headings found between these markers.
  Prose outside them, however long, never counts toward it — the threshold
  measures what the pipeline generated, not what a human wrote.

## Area headings

Inside the managed section, the generated block uses these headings, always
in this order:

1. Module boundaries and layering
2. Error handling
3. Naming
4. Authentication and authorization
5. Data access
6. Testing
7. Formatting and lint

An area with no derived rules for this project still keeps its heading,
followed by a line stating that no rule was derived — omitting the heading
would leave a later reader unable to tell "checked, nothing found" from
"never checked."

Under each heading, every rule is one line, written as an imperative
instruction, and ends with a `file:line` citation pointing at the evidence
it was derived from:

```markdown
## Error handling
- Wrap outbound calls in a typed error, never let a raw exception cross a
  layer boundary (src/api/client.py:42).
```

The citation is what lets a later run — or a human — verify a rule against
the codebase directly, rather than trusting the sentence on its own.

## Discoveries section markers

A durable finding the end phase persists mid-task (`core/phases/end.md`
Step 3) does not go inside the managed section above. It goes in a second,
disjoint span, with its own marker pair:

```markdown
<!-- pipeline:discoveries:start -->
... durable findings appended by the end phase, one per task ...
<!-- pipeline:discoveries:end -->
```

This split exists because the two spans have incompatible write patterns.
The conventions flow's Step 4 regenerates the managed section
wholesale on every run — it is a *rewrite*, not a merge, by design, so that
a rule no longer practiced in the code can disappear from the file the same
way it disappeared from the codebase. The end phase's Step 3, by contrast,
only ever *appends*, one task at a time, with no exploration pass of its
own to decide whether what it appended last time still holds. Placing an
append-only writer's output inside a span another flow overwrites wholesale
is not a mistake either flow's own logic would catch — the discoveries span
makes it structural instead: the conventions flow already promises, in the
paragraph above, to touch nothing outside `pipeline:conventions:start` /
`pipeline:conventions:end`, and the discoveries markers simply live outside
that promise's boundary. No flow needs to know about the other's span for
this to hold.

- The end phase owns this span exclusively. It only ever appends to it —
  never touches the managed section above — and uses the same seven area
  headings from the section above for consistency, adding a heading only
  when it has something to file under it (unlike the managed section, this
  span does not pre-populate all seven; it grows by appending, not by
  regeneration, so there is nothing to keep in sync).
- The conventions flow never touches this span, on any run — it is outside
  the bounds the paragraph above already restricts Step 4 to, which is what
  makes "never lost on a re-run" true by construction rather than by
  discipline.
- Items here do not count toward doctor's five-item threshold
  (`core/contracts/project-requirements.md`), which measures confirmed,
  derived rules in the managed section only. A discovery appended here has
  not been through the conventions flow's Step 2 rule-versus-occurrence bar
  or its Step 3 human confirmation — it is a candidate, not yet a rule.
- On a later run, the conventions flow's own exploration (Step 1) may
  independently rediscover the same pattern from the codebase and, once it
  clears the rule bar, propose it through the normal confirm-and-write path
  into the managed section — this span is a durable record for a human or a
  future run to notice, not an automatic input any flow promotes on its
  own.
- If the markers are absent, the end phase appends them — and the finding —
  to the end of the file, the same way the managed section's own markers
  get appended per the rule above. If only one marker is present, or the
  two appear out of order, the end phase treats the file as malformed and
  stops, exactly as the conventions flow does for its own markers.
