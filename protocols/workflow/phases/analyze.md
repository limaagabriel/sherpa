# Analyze

Diagnose, then diverge on approach — before any draft. Runs on Discover's brief; hands Plan a chosen framing.

## Diagnose
Find root cause and all affected dependencies before settling on an approach. For bugs, rank hypotheses with the minimum evidence to confirm the top one. If diagnosis fails, stop and reassess — don't chain workarounds (no symlinking `node_modules`, copying files, bypassing safeguards). If evidence contradicts an `Assumption`/`Decision` in the brief, or raises a question only the user can answer, return to Discover.

## Alternative-approach panel
Once the brief holds, diverge on approach before any draft exists, unconditionally — opting into `/plan` is consent to its cost. Spawn three `Plan` agents in parallel, **isolated** — each sees only the goal + brief, never each other's output (shared context anchors them and collapses the panel to one wider thought). One per framing:
- **simplest-that-works** — the least machinery that satisfies the goal.
- **most-reversible** — the decomposition cheapest to walk back if a pick is wrong.
- **least-coupling** — the split that minimizes cross-step and cross-module coupling.

Each returns a rival decomposition for the same goal. Judge: rank the three on goal-fit + reversibility + cost; graft the strongest into one **chosen framing**, or adopt a rival wholesale. The chosen framing — and why the rivals lost — is what Plan drafts from and records in Block-3, where `plan-reviewer`'s Unsound why-lost lens attacks it. This is *decomposition* divergence, distinct from the goal-framing choice (`phases/discover.md` § Steps — the `AskUserQuestion` decision when the goal itself has multiple framings).
