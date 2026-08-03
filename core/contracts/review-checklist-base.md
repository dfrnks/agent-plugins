# Review checklist base contract

The code-review phase checks an implementation against a checklist rather
than re-reading every changed file against unwritten judgment. This file is
the seed of that checklist: four sections that hold for any stack, any
language, any framework. The conventions flow extends this seed with rules
derived from the specific codebase it runs against — this file is what it
extends, never something a specific project's conventions replace.

Every item below is written so it applies unchanged to a CLI tool, a web
service, or a data pipeline alike. An item that only makes sense with a
particular framework, language, or provider in mind does not belong here —
it belongs in the derived rules the conventions flow writes on top.

## Security

- [ ] Every new entry point carries an authorization check before it acts.
- [ ] Input arriving from outside the system is validated before use, not
      trusted because it came from a request or a message.
- [ ] No secret, token, or credential appears in source code or test
      fixtures, in any form — plain, encoded, or embedded in a sample
      payload.
- [ ] Data scoped to one tenant, user, or account cannot be reached by
      supplying another tenant's, user's, or account's identifier.

## Correctness

- [ ] Every error path returns the documented error, never a sentinel value
      (`None`, `false`, `-1`, an empty collection) standing in for failure.
- [ ] Every branch stated in the Definition of Done exists in the code —
      no branch is implied by "similar cases already handled."
- [ ] Values representing money use an exact decimal type; a binary
      floating-point type never holds a monetary value.
- [ ] A timestamp that mirrors an event from an external system is read
      from that system's own payload, never generated locally at the
      moment of observation.

## Tests

- [ ] Every Definition of Done item maps to at least one test that fails
      without the corresponding implementation.
- [ ] Error paths and permission paths are covered by tests, not only the
      happy path.
- [ ] Tests are independent of one another and clean up any state they
      create, so run order never changes the outcome.
- [ ] No production code exists solely to make a test pass.

## Data and migrations

- [ ] Every schema change ships together with its migration, in the same
      change set.
- [ ] A new non-nullable column carries either a default value or a
      backfill step — never a bare `NOT NULL` against existing rows.
- [ ] A migration is reversible, or its irreversibility is stated
      explicitly rather than left to be discovered when a rollback fails.
