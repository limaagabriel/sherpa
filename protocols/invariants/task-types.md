# Task-Type Templates

## Templates

Task type is **human-declared**; agent never infers; default to Feature.

### rename

Required fields:

- `OLD_TOKEN` — the exact pre-rename identifier
- All affected identifiers listed (every location the old name appears)

**Stale-token scan.** After implementing and before handoff:

```
grep -rn "<OLD_TOKEN>" <search-set>
```

`<search-set>` covers: the module's test files; all `*Test*.java` files in the same package tree; and all occurrences in docs (`*.md`) and config (`*.xml`, `*.properties`) under the module root (nearest ancestor directory containing a `build.gradle`). Any hit is a stale-token finding that BLOCKS the handoff.

---

### refactor

Required fields:

- `behavior-preservation` invariant — the observable contract that must not change
- Before/after behavioral-equivalence assertion confirming the contract holds after the change
- No-new-public-API confirmation

---

### feature

Required fields:

- `precedent` list — ≥1 `{file:line, what_it_exemplifies}` from Scout (when none exists: `Precedent: none found — new pattern justified by <reason>`)
- Acceptance-test description — observable end state and the command/observation confirming it

---

### debug

Required fields:

- `repro` — exact steps or failing test reproducing the defect
- Root-cause statement (`file:line` — precise location of the fault)
- Fix scoped to root cause only (no opportunistic cleanup)
- Regression-test description — the test or check that would have caught this, added by the fix
