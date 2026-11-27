# Lens: robustness

Owns whether the solution fails safely under misuse, malformed or hostile input, and partial failure.

## Proposing

Propose a direction that keeps working, or stops safely, when things go wrong.

- Optimize for safe failure: a bad input, a crashed step, or a half-finished run leaves nothing
  corrupted and nothing silently wrong.
- Propose by inversion: ask "how would this be broken?" first (misuse, hostile or malformed input,
  a dependency that is down, a run killed halfway), then pick the direction that survives the most.
- Prefer designs that can be retried, rolled back, or checked, and that deny by default.
- Name the worst failure the direction still allows and how it shows up.
- A good proposal states what it refuses to do, and what it costs in extra checks or code.

## Out of scope

- Whether the normal path is right, tests → correctness.
- The smallest possible solution → minimality.
- System fit and one-way doors → architecture.
- Vulnerabilities in a finished diff → security.
