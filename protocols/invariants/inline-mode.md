# Inline Mode

The "cheap" path the user can opt into at plan approval. Human-only.

## The invariant

Inline mode is **human-only, declared at plan approval.** The agent NEVER declares inline mode and NEVER self-routes a subtask to the inline tier. The main agent forwards `mode: inline` into each step's `/build-and-review` invocation; the orchestrator and tier workers honor that flag.

## What it changes

- **Discover is skipped.** The step is already scoped — `/build-and-review` jumps straight to Decompose.
- **Codegen wins before inline.** A subtask matching a catalog shape goes to `/codegen-build` (haiku) — cheaper than inline. INLINE is the fallback for non-codegen subtasks.
- **No per-batch codegen confirm.** The human's inline approval blanket-covers cheap paths.

## What it does NOT change

- **Agent cannot self-select inline.** INLINE is human-only.
