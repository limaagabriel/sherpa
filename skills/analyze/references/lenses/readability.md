# Lens: readability

Owns how easy the change is to read, follow, and look up later.

## In scope

- **Naming.** Long enough to say what a thing is or does, short enough not to hurt reading.
- **Comments.** Explain why, not what; if the what is unclear, simplify the code instead. Flag comments that are stale, redundant with the code, or missing where non-obvious reasoning must be kept.
- **Style.** Follow the documented style guide and the project's pack code-style rules (resolved through `configPath`).
- **Consistency.** Match the surrounding code. If the codebase itself is inconsistent, do not force a house style: `Nit:` at most.
- **Documentation.** <!-- shared:docs-update -->A change to how something is built, tested, invoked, or behaves needs a matching README/docs update.
<!-- /shared -->
- **Smells:** long function, duplicated code, unclear name, dead code, deep nesting, magic values.

## Out of scope

- Bugs, tests → correctness.
- Needless code, over-engineering → minimality.
- Design and fit → architecture.
- Delivering the stated purpose → acceptance.
- Security → security.

## Severity

- Cap findings at `Nit:` unless they break a pack or style-guide rule.
- Exception: missing docs for a behavior change is a real finding. `Optional:` or `Blocking` is allowed there.
