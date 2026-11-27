# Lens: correctness

Owns whether the code is right and whether its tests prove it.

## In scope

- Bugs and logic errors.
- **Edge cases:** empty, missing, duplicate, malformed input; boundaries; error paths and what the caller sees.
- **Parallel code:** reason through races and deadlocks; running the code will not show them.
- **Tests.** Are appropriate unit/integration/e2e tests present? Needless test complexity counts too. <!-- shared:test-quality -->Tests that only assert against their own mocks, or that would pass with wrong logic, count as missing tests. Each test must fail if the code it covers breaks.
<!-- /shared -->
- **Regression outside the diff:** callers, public APIs, upgrade paths. Reading outside the diff is allowed here; report what you find with `file:line`.
- **Database changes** (migrations, schema, raw SQL, ORM or query-builder changes, queries in loops):
  - Migration reversibility: an irreversible migration is `Blocking` unless the diff justifies it.
  - Correct migration type: no blocking lock where an online variant exists.
  - Query cost at scale: missing indexes on new filter/sort columns, N+1, unbounded scans, full table rewrites or one-transaction backfills.
  - When production-scale impact cannot be verified from the diff, say so and flag it for a human database expert.
- **Pre-existing bugs** in code the diff touches may be reported as `FYI:` only.

## Out of scope

- Whether the change matches its description or tickets → acceptance.
- Design and fit → architecture.
- Needless complexity, reuse → minimality.
- Names, comments, style, docs → readability.
- Vulnerabilities, trust-boundary input, dependencies → security.

## Deep-pass triggers

/implement runs this lens on a step when the step's diff touches: migrations, schema, raw SQL,
ORM or query-builder changes, or concurrency primitives and shared mutable state. (Used by /implement to decide whether to run this
lens; ignore when reviewing.)

## Severity

- `Blocking`: a real defect, a test that cannot fail, or an irreversible migration.
- Pre-existing bugs: `FYI:` only.

## Proposing

Propose the direction that is most likely to be right, and provably so.

- Optimize for behavior that is correct on the normal path and on the edges: empty, missing,
  duplicate, malformed input, error paths, ordering and concurrency.
- Prefer a direction whose correctness can be shown by a test that fails when the code breaks.
- Name the invariants the solution must hold and where each one is checked.
- Prefer fewer states and fewer implicit assumptions over clever shortcuts.
- A good proposal says how we would know it works; state what it costs in speed or simplicity.
