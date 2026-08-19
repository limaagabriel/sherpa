**Plan goal:** Response caching exists for the search endpoint, for repeat-query callers because
identical queries currently re-hit the DB every time; done when confirmed by a load test showing
cache-hit latency < 5ms and an 80% drop in DB query count for repeated queries.

**No-gos (forwarded from the pitch):** must not change the public API response shape.
**Rabbit holes (forwarded from the pitch):** none named.

## Step 1
**Goal:** An in-memory cache layer exists for search results, for the search handler because
repeated queries shouldn't re-hit the DB; done when confirmed by a unit test that a second call
with the same key returns the first call's stored value without a DB call.
**Change:** Add `CacheLayer` with `get`/`set` methods, keyed by query hash.
**Interfaces:** consumes: none; produces: `CacheLayer.get(key: string): CachedResult | null`,
`CacheLayer.set(key: string, result: CachedResult): void`.
**Example:** `cache.set("q:abc", {hits: [...], total: 12}); cache.get("q:abc") // => {hits: [...], total: 12}`
**Acceptance criteria:** done = a cached key returns without a DB call, confirmed by a unit test
mocking the DB and asserting zero calls on the second `get`.
**Blast contract:** reversibility: revertible; touches: new `CacheLayer` module only; revert:
delete the module, no other file depends on it yet.
**Risk:** unbounded memory growth if never evicted — acceptable for this step, a follow-up step
would add eviction; real risk, stated.

## Step 2
**Goal:** Search requests are served from cache when available, for end users because repeated
identical queries shouldn't re-hit the DB; done when confirmed by an integration test showing a
repeated request skips the DB.
**Change:** Wire the search handler to consult the cache before querying the DB.
**Interfaces:** consumes: `Cache.lookup(key: string): Result`; produces: none.
**Example:** handler pseudocode — `const cached = Cache.lookup(key); if (cached) return cached;`
**Acceptance criteria:** done = a repeated request doesn't hit the DB, confirmed by an integration
test with a DB call counter.
**Blast contract:** reversibility: revertible; touches: search handler only; revert: remove the
cache-check branch.
**Risk:** none — pure read-path addition, no write path touched.

## Step 3
**Goal:** Callers can tell whether a search response came from cache, for API consumers debugging
latency because cache hits and misses should be distinguishable; done when confirmed by an
integration test asserting the field's presence and value.
**Change:** Add a `cached: boolean` field to the search response payload.
**Interfaces:** consumes: none; produces: none.
**Example:** `{ hits: [...], total: 12, cached: true }`
**Acceptance criteria:** done = the response includes `cached`, confirmed by an integration test.
**Blast contract:** reversibility: revertible; touches: search response shape; revert: remove the field.
**Risk:** none stated.

## Block 3 — Why & how
**Why this approach:** an in-memory cache was chosen over a shared cache (e.g. Redis) because the
appetite is small and a single-instance deployment doesn't need cross-process sharing yet.
**How it's verified:** load test shows cache hit latency < 5ms and an 80% drop in DB query count
for repeated queries.
