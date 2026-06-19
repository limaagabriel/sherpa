# Adversarial System — Maintenance Map

**Build-Id note:** see `protocols/invariants/build-id.md`.
**Inline mode:** see `protocols/invariants/inline-mode.md`.

## Overview

Three layers:

- **Turn audit:** the `/execute` skill runs `turn-reviewer` before claiming a step done — it audits code diff, process, and reasoning. (This plugin bundles no always-on hook; a host environment MAY wire a Stop-hook dispatcher to invoke `turn-reviewer` automatically, but that is host configuration, not shipped here.)
- **Orchestration:** `/build-and-review <task> + goal + acceptance criteria`. Discovers, decomposes into ≤6 subtasks, tiers and routes each, then runs two range-wide gates: **Verify** (`task-reviewer` — right thing built?) and **Review** (`turn-reviewer` — built right?). Edits source only in the `inline` tier.
- **Tier-engine:** three builders `/build-and-review` routes to:
  - **default** → `/adversarial-build --skip-probe` — drafter authors the briefing, Vet breaker attacks the spec, builder commits. Probe is skipped by default (re-attacked by range gates). Standalone callers may omit `--skip-probe` to restore Probe, or add `--skip-vet` to drop the spec gate.
  - **codegen** → `/codegen-build` — catalog-matched auto-gen to haiku; one commit, no breaker, no review.
  - **inline** → main agent edits inline.

## The Loop

### Outer — `/build-and-review`

```
1. Prep       record PRE-EXISTING DIRT + PRE-BUILD BASE + BUILD ID
2. Discover   /scout + clarify (≤10 rounds) + approach (1, conditional)
              → DISCOVER RECORD → discovery/<BUILD ID>.md   [skipped in inline mode]
3. Decompose  split step into ≤6 atomic subtasks, index each <n>
4. Tier       catalog match → CODEGEN; inline mode → INLINE; else → DEFAULT
              (normal mode: confirm codegen batch once; codegen wins ties)
5. Route      CODEGEN → /codegen-build (haiku) │ DEFAULT → /adversarial-build --skip-probe │ INLINE → main agent
              each subtask → one Build-Id-noted commit + handoffs/<BUILD ID>.<n>.md
6. Verify     task-reviewer over <PRE-BUILD BASE>..HEAD   [≤3 verify→fix loops]
                  UNMET → relay to owning subtask's builder, re-verify
                  STYLE → relay as mechanical fix; does not gate ACCEPTANCE
                  UNVERIFIABLE / cap hit → BLOCK → user
7. Review     turn-reviewer over the whole range
                  FIX   → relay to owning builder (amend/autosquash)  [≤3]
                  BLOCK → surface verbatim, ask user
8. Deliver    PASS → verify every commit carries this run's Build-Id note → done
```

### Inner — `/adversarial-build` (DEFAULT tier, per subtask)

```
1. Prep    inherit BUILD ID + <n> + DIRT + BASE from build-and-review (self-snapshot if standalone)
2. Brief   drafter authors briefing from discovery/<BUILD ID>.md
           breaker mode=briefing (Vet) → audits spec   [≤2 rewrites]
3. Build   builder → search + edits + one Build-Id-noted commit + handoff
           breaker mode=output (Probe) → attacks result   [≤3 fix loops; SKIPPED under --skip-probe]
4. Deliver verify commit carries this run's note; return handoff path + build verdict
```

`/codegen-build` is a single haiku dispatch (no breaker, no review); the `inline` tier is the main agent. Both flow through the outer Verify + Review gates.

## Caps Summary

| Cap | Value | Source |
|-----|-------|--------|
| Discover Scout dispatches | ≤2 | `commands/build-and-review.md` § Discover > Scout |
| Discover Clarify rounds | ≤10 (proceed-with-best-effort on cap) | `commands/build-and-review.md` § Discover > Clarify |
| Discover Approach selection | 1 (conditional) | `commands/build-and-review.md` § Discover > Approach |
| Decompose subtasks per step | ≤6 (one level deep) | `commands/build-and-review.md` § Decompose |
| Verify→fix loops (task-reviewer) | ≤3, then BLOCK→user | `commands/build-and-review.md` § Verify |
| Brief Vet rewrites (breaker mode=briefing) | ≤2 (skipped under `--skip-vet`) | `commands/adversarial-build.md` § Brief > Vet |
| Build-fix cap | ≤3 | `commands/adversarial-build.md` § Build |
| Probe output-fix loops | ≤3, drawn from build-fix cap; skipped under `--skip-probe` (default wiring) | `commands/adversarial-build.md` § Build > Probe |
| Reviewer FIX loops | ≤3, then BLOCK→user | `protocols/adversarial/verdict-handling.md` § Verdict response > FIX |

Cap **values** are authoritative here; Source shows where each is enforced. On hitting any cap without convergence, surface unresolved findings and hand to the user.

