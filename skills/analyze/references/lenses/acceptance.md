# Lens: acceptance

Owns whether the change delivers what it was asked to deliver.

In /analyze, the PR body and linked tickets (when the coordinator passes them) play the role plan acceptance criteria play in /implement.

## In scope

- **Functionality.** Does the change do what its description and linked tickets say? Anything promised but missing, or done but never asked for?
- Is that behavior good for end-users and for the developers who will call this code later?
- **User-facing changes (templates, DOM, CSS, UI components):**
  - Think about the real user impact: clearer or more confusing, faster or slower, consistent with the rest of the product?
  - Accessibility is a real finding, not a nit: semantic HTML, ARIA where native semantics fall short, keyboard operability, focus management, heading structure, screen-reader announcement. A change with no visible pixel difference can still regress these.
  - When a diff can't show the behavior (animation, responsive layout, interaction timing), ask for a demo instead of approving on faith.

## Out of scope

- Bugs, edge cases, races, tests → correctness.
- Fit with the system's design and patterns → architecture.
- Unneeded code, reuse, over-engineering → minimality.
- Naming, comments, style, docs → readability.
- Security → security.

## Deep-pass triggers

/implement runs this lens on a step when the step's diff touches: templates, DOM, CSS, or UI
components. (Used by /implement to decide whether to run this lens; ignore when reviewing.)

## Severity

- `Blocking`: the change contradicts or misses its stated purpose, or breaks accessibility in a way users would notice.
