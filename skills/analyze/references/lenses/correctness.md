# Lens: correctness

Owns whether the code is right and whether its tests prove it.

## In scope

- Bugs and logic errors.
- **Edge cases:** empty, missing, duplicate, malformed input; boundaries; error paths and what the caller sees.
- **Parallel code:** reason through races and deadlocks; running the code will not show them.
- **Tests.** Are appropriate unit/integration/e2e tests present? Will each test fail if the code it covers breaks? Watch for tests that only assert against their own mocks, or would pass with wrong logic. Needless test complexity counts too.
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

## Severity

- `Blocking`: a real defect, a test that cannot fail, or an irreversible migration.
- Pre-existing bugs: `FYI:` only.
