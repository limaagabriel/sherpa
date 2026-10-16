# Lens: architecture

Owns how the change fits into the system.

## In scope

- **Design.** Do the pieces of this change interact sensibly? Does it belong in this codebase, or in a library? Does it integrate cleanly with what is already there? Is now the right time to add it?
- **Fit.** Does it follow the codebase's existing patterns, and the project's pack rules when `configPath` resolves any?
- **Forward-looking risk.** A one-way door (hard to undo once shipped), a missing seam where callers will soon need one, a hardcoded assumption that will not survive the next obvious change.

## Out of scope

- Whether it works, edge cases, tests → correctness.
- Delivering the stated purpose → acceptance.
- Needless code or speculative generality → minimality.
- Names, comments, style → readability.
- Security → security.

## Severity

- If you find a major design objection in the main part of the change, raise it first; it can make later polish moot.
- `Blocking` only when code health would clearly drop (e.g. wrong layer, breaks an established boundary). Forward-looking risks are usually `Optional:` or `FYI:`.
