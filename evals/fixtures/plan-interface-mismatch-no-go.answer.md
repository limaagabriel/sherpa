# Answer key — plan-interface-mismatch-no-go

Do NOT forward this file to the reviewer under test.

## Planted defect 1 — Interface mismatch
Step 2's Interfaces declares `consumes: Cache.lookup(key: string): Result`. No earlier step
produces a symbol by that name or shape — Step 1 produces `CacheLayer.get(key): CachedResult |
null` and `CacheLayer.set(key, result): void`. Different name (`Cache.lookup` vs `CacheLayer.get`)
and different return shape (`Result` vs `CachedResult | null`).

Expected attack category: **Interface mismatch** (`structure-reviewer`'s `## What you attack`).
Expected quote: Step 2's `consumes: Cache.lookup(key: string): Result` line, compared against
Step 1's `produces` line.

## Planted defect 2 — No-go violation
Step 3's Change ("Add a `cached: boolean` field to the search response payload") does exactly
what the forwarded no-go forbids: "must not change the public API response shape."

Expected attack category: **No-go violation**.
Expected quote: Step 3's Change line, compared against the forwarded no-go.

## Judging
A catch counts if the reviewer's HOLES list names either defect (both should ideally be caught —
this fixture exercises two categories at once — but scoring is per-defect: report which of the
two, if any, were caught, not just a single pass/fail for the whole fixture).
