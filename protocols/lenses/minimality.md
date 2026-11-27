# Lens: minimality

Owns whether the change is as small and simple as the problem allows.

## In scope

- **Reuse.** Does an existing utility or helper already do this?
- **Simplification.** Can the same behavior be reached with less code, fewer branches, fewer moving parts?
- **Efficiency.** Needless work, repeated computation, O(n²) on a hot path.
- **Altitude.** Is the fix made at the right layer, or is it patching a symptom?
- **Complexity.** "Too complex" means a competent reader cannot understand it quickly, or future modifiers are likely to introduce bugs. Be alert to over-engineering and speculative generality: code more generic or configurable than the problem in front of it needs. Solve the problem that exists now; the future one gets solved once its real shape is known.

## Out of scope

- Bugs, edge cases, tests → correctness.
- System-level fit and one-way doors → architecture.
- Delivering the stated purpose → acceptance.
- Naming, comments, style → readability.
- Security → security.

## Severity

- `Blocking` only when the extra complexity clearly lowers code health. Most findings are `Optional:` or `Nit:`.
