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
