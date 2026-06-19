# Tiering Catalog

**Inline mode:** see `protocols/invariants/inline-mode.md`.

Defines how `/build-and-review` tiers each subtask and catalogs the **codegen** shapes the agent may match. The human owns the final call; the agent matches the codegen shape and proposes — it never decides a tier beyond that match.

## The three tiers

| Tier | Unlocked by | Builder | Model |
|------|-------------|---------|-------|
| **codegen** | subtask matches a shape below | `/codegen-build` | haiku |
| **inline** | **human-only** at plan approval | main agent, inline | session |
| **default** | everything else | `/adversarial-build --skip-probe` | sonnet + Vet |

**Resolution order (per subtask):**

```
1. Matches a codegen shape?  → CODEGEN   (cheapest; preferred in inline mode too)
2. else, mode == inline?      → INLINE    (human-only)
3. else                       → DEFAULT   (full ceremony)
```

## Authority model

The agent never self-routes to inline — only matches the codegen shape.

## Match protocol

Runs in the Tier phase, before building. Must be decidable from the subtask statement plus a cheap read of the named file(s) — never a deep analysis.

1. Compare the subtask against each shape's **Qualifies when**.
2. If any **Disqualifier** hits, the subtask spans more than one shape, or you are unsure → **no match**.
3. Clean single-shape match → propose CODEGEN (normal mode: wait for confirmation).

Safety net: if `/codegen-build`'s haiku worker hits hand-authoring work, it returns `BUILD FAILED` and `/build-and-review` re-routes to `default`.

---

## Codegen shapes

### auto-gen-command

Running a deterministic generator whose output the generator/formatter owns.

- **Qualifies when:** the subtask is "run `<generator>`" — a deterministic code generator — and the diff is purely regenerated output.
- **Disqualifiers (any hit → not codegen):** the same subtask also edits the schema/model/`*.yaml` driving the generator; a new entity, service, or endpoint is introduced; the run leaves migration or DB artifacts needing judgment; generated output is hand-edited after the run.
- **Examples:**
  - "regenerate the `*Model` classes after pulling — no schema change."
  - "re-run REST Builder to refresh the generated client — the `.yaml` is unchanged."

---

## Extending the catalog

Only the human adds shapes, and only to the **codegen** tier. A new shape MUST carry: a **Qualifies when** decidable without deep analysis, an explicit **Disqualifiers** list, and at least one **Example**. A shape whose match needs Scout-level analysis does not belong here.
