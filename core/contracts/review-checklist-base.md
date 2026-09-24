# Review checklist base contract

The code-review phase checks an implementation against a checklist rather
than re-reading every changed file against unwritten judgment. This file is
the seed of that checklist: five sections that hold for any stack, any
language, any framework. The conventions flow extends this seed with rules
derived from the specific codebase it runs against — this file is what it
extends, never something a specific project's conventions replace.

Every item below is written so it applies unchanged to a CLI tool, a web
service, or a data pipeline alike. An item that only makes sense with a
particular framework, language, or provider in mind does not belong here —
it belongs in the derived rules the conventions flow writes on top.

Universal in scope is not the same as universal in applicability: a few
items below name a hazard that only some projects have (money, mirrored
external events, multiple owners of data). Each of those states its own
precondition, and a project the precondition does not hold for marks the
item not applicable and moves on, exactly as the "Data and migrations"
section already works. An item with no stated precondition applies to every
project without exception.

## Security

- [ ] Every new entry point carries an authorization check before it acts.
- [ ] Input arriving from outside the system is validated before use, not
      trusted because it came from a request or a message.
- [ ] No secret, token, or credential appears in source code or test
      fixtures, in any form — plain, encoded, or embedded in a sample
      payload.
- [ ] When the project has any notion of separate owners of data: data
      scoped to one tenant, user, or account cannot be reached by supplying
      another tenant's, user's, or account's identifier. A project with a
      single owner of all data marks this item not applicable.

## Correctness

- [ ] Every error path returns the documented error, never a sentinel value
      (`None`, `false`, `-1`, an empty collection) standing in for failure.
- [ ] Every branch stated in the Definition of Done exists in the code —
      no branch is implied by "similar cases already handled."
- [ ] When the change touches monetary values: they use an exact decimal
      type, and a binary floating-point type never holds one. A project
      that handles no money marks this item not applicable — it is listed
      because the failure is silent and expensive where it does apply, not
      because every project has money in it.
- [ ] When the change records a timestamp mirroring an event in another
      system: it is read from that system's own payload, never generated
      locally at the moment of observation. Not applicable to a project
      that mirrors no external events.

## Tests

- [ ] Every Definition of Done item maps to at least one test that fails
      without the corresponding implementation.
- [ ] Error paths and permission paths are covered by tests, not only the
      happy path.
- [ ] Tests are independent of one another and clean up any state they
      create, so run order never changes the outcome.
- [ ] No production code exists solely to make a test pass.

## Design

The project's own conventions come first: a pattern they establish is never
a finding here, even where an item below would flag it.

- [ ] The change calls logic the codebase already has instead of
      reimplementing it.
- [ ] Each business rule lives in one place; changing it means editing one
      site.
- [ ] The same non-trivial block does not appear three or more times in the
      change.
- [ ] No abstraction, option, or extension point exists without a second
      implementation today — a test double counts — or a requirement that
      names it.
- [ ] No implementation satisfies a contract with an operation that only
      signals "not supported" or silently does nothing.
- [ ] Each function added or changed does one job. When the project has
      layers: it stays inside one. A project without layers marks that half
      not applicable.
- [ ] Adding one case touched one site, not every place that branches on
      the set.
- [ ] Indirection around a dependency sits at an input/output boundary —
      storage, network, clock, an external service — not around logic that
      does none.

## Data and migrations

Applies only when the project versions a schema. If it does not, mark this
section not applicable and move on.

- [ ] A schema change ships together with its migration, in the same
      change set.
- [ ] A new non-nullable column carries either a default value or a
      backfill step — never a bare `NOT NULL` against existing rows.
- [ ] A migration is reversible, or its irreversibility is stated
      explicitly rather than left to be discovered when a rollback fails.
