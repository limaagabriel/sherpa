---
name: build-and-review
description: Build-and-review orchestrator. Given a task + goal + acceptance criteria, it Discovers, Decomposes into subtasks, tiers each (codegen / inline / default), routes each to the right builder, then runs ONE task-reviewer pass (right thing?) and ONE turn-reviewer pass (thing right?) over the whole range, iterating until the goal is met. Owns the subtask split and both review gates. Args - <task>, goal, acceptance criteria, [mode: normal|inline]. See protocols/adversarial/README.md.
---

**Build-Id note:** Follow `protocols/invariants/build-id.md` — you own the BUILD ID; every commit across all tiers must carry it.
**Inline mode:** Follow `protocols/invariants/inline-mode.md` — you own tier routing; agents never self-classify.
**Mutating-bash verbs:** Read `protocols/invariants/mutating-bash-verbs.md` — coordinator Bash is read-only.

## What this is

Single entry point the CLAUDE.md Execute step calls. Turns one plan step into committed, verified, reviewed work. Orchestrates — splits the step, decides who builds each piece, gates the result. Delegates building:

| Tier | Unlocked by | Builder | Model |
|------|-------------|---------|-------|
| **codegen** | subtask matches `protocols/invariants/tiering-catalog.md` | `/codegen-build` | haiku |
| **inline** | **human-only**; applies to non-codegen subtasks | main agent, inline | current session |
| **default** | everything else | `/adversarial-build --skip-probe` | sonnet + Vet |

Two gates, run once over the whole range after building:
- **Verify** (`task-reviewer`) — right thing? (goal + every acceptance criterion met)
- **Review** (`turn-reviewer`) — thing right? (clean, honest, in-convention, no drift)

## Inputs

- `<task>` (required): the step to implement.
- **Goal** (required): one-sentence outcome from the Plan step.
- **Acceptance criteria** (required): observable end states (`done = <X>, confirmed by <re-runnable automated check>` — test/command; manual observation only with a stated reason it can't be automated). These are exactly what `task-reviewer` judges.
- **Mode** (optional, default `normal`): `inline` skips Discover and routes non-codegen subtasks to INLINE.

## Coordinator discipline

You orchestrate. You do **not** edit source files **except in the `inline` tier**. In every other tier, building is the dispatched worker's job. Your Bash is read-only git. Never squash, reword, or reset another worker's commit.

---

## The loop

### Logging

Emit one event per step via `scripts/build-log.sh` (queryable via `--stats`). Always pass `--build-id <BUILD ID> --coord build-and-review`; add `--subtask <n>` for per-subtask events. Never block the loop on log failure.

### Prep

Run once, before anything else:
- `git status --short` → `PRE-EXISTING DIRT`. Forward into every builder and reviewer dispatch.
- `git rev-parse HEAD` → `PRE-BUILD BASE`. Range `<PRE-BUILD BASE>..HEAD` scopes Verify, Review, and Deliver.
- `scripts/build-id.sh` → `BUILD ID`. Forward with each subtask's index `<n>` into every builder dispatch.
- `scripts/build-notes.sh init` → set repo-local notes config (idempotent).
- **Project pack.** If a `WORKFLOW_PACK:` line was announced at session start (see `packs/README.md`), capture its `initialize`, `codeStyleRules`, `reviewers`, and `codeStyleAudit`. Resolve the `initialize` skill's `SKILL.md` path. Forward `codeStyleRules` and the `initialize` SKILL.md path into every builder + reviewer dispatch (subagents don't see session context — they only get what you pass; they have no Skill tool, so they `Read` the SKILL.md rather than invoke it), and dispatch the announced `reviewers` in Review. **No announcement → no pack. The extra `reviewers` fan-out no-ops; style checks fall back to the file's language conventions + in-file/module precedent (no project rules to cite).**

Create `briefings/` and `handoffs/` lazily (workers `mkdir -p` their own).

**Log:** `--phase prep --event start`.

### Discover — Scout, Clarify, Approach *(skipped in inline mode)*

In `inline` mode skip Discover entirely — plan already approved; go straight to Decompose.

- **Scout (cap: 2 Explore dispatches inside `/scout`).** When a turn-level Discover brief exists upstream, forward its `Scout` landmarks as starting context and narrow breadth — the step scout extends, not re-derives. Invoke `/scout <task> <TARGET_DIR> <breadth>`. Pass as `FOCUS`: upstream landmarks to confirm/extend; file:line entry points and existing patterns; for transform tasks an input-fragment inventory; for schema tasks existing constraints/validators/consumers; structured **precedent list** (`{file:line, what_it_exemplifies}`, `None found` + justification allowed). When no upstream brief exists, scout from scratch. Read the turn-level brief from `SPEC.md` by path rather than inline.
- **Task-type (human-declared).** Determine from invocation or surface in a Clarify round; default to Feature. Load the matching template from `protocols/invariants/task-types.md`; required fields become mandatory briefing sections.
- **Clarify (cap: 10 rounds; proceed-with-best-effort on cap).** Per round, one `AskUserQuestion` batching every related hole (≤4 questions, 2-4 options each, one recommended). Hole classes: unmatched-fragment disposition (transform); validation order / idempotence / no-op; edge cases (empty, missing, duplicate, malformed); implicit acceptance criteria; trade-offs between interpretations. Omit questions resolved by upstream brief. On cap, document each open ambiguity as `open: <hole> — assumed <choice>` and forward so downstream Vet attacks it.
- **Approach (cap: 1 selection; conditional).** Only when Scout surfaced multiple viable framings — one `AskUserQuestion` with 2-3 framings + recommendation. Omit when one framing is obvious.

**Output:** persist a **discovery record** to `discovery/<BUILD ID>.md` (`mkdir -p discovery/` first). Begin with `# <task>`. Feed into Decompose locally; referenced by path (not pasted inline) in every default-tier dispatch. Written on Discover end; not read back on resume (resume re-scouts — a persisted scout can go stale).

### Decompose — atomic-work split

**Atomic = a single idea.** Defined by conceptual cohesion, not file count.

**A good subtask** (all three hold):
- **Independently buildable** — briefable and built without waiting on a sibling's output.
- **Independently verifiable** — its acceptance slice checkable on its own commit, not "looks done."
- **Lands the tree in a working state** — no half-applied codegen/schema/migration artifacts; module still builds.

**Calibration:**
- Too granular: "Create the file", "Add the import" — mechanical fragments of one idea.
- Too coarse: "Implement the feature" — bundles entity + service + UI + tests.
- Right: "Add the `priority` column + its `buildService` regen", "Wire the validator into the action class".

More than one distinct idea → split, **capped at 6** subtasks. Each gets a 1-based index `<n>` and lands its own commit. Single-idea step = subtask `1`. **Hard recursion cap: one level deep.**

Erring toward more subtasks only adds gates and can never skip one.

**Log:** `--phase decompose --event verdict --count <subtask-count>`.

### Tier — classify each subtask *(agent matches codegen; human owns the rest)*

Resolve tier in order:
```
1. Matches tiering-catalog shape (auto-gen / codegen command)?  → CODEGEN
2. else, mode == inline?                                        → INLINE
3. else                                                          → DEFAULT
```

- **Codegen wins even in inline mode** — cheaper than the main agent doing it inline. INLINE is only the fallback for non-codegen subtasks of an inline step.
- **The agent only ever matches CODEGEN** (mechanical pattern-match against `protocols/invariants/tiering-catalog.md`). Ambiguity resolves toward DEFAULT.
- **Confirmation:**
  - `normal` mode: if any subtask matched CODEGEN, surface proposed tiering once via `AskUserQuestion` — *"Subtasks N, M match codegen shape `<name>` → /codegen-build (haiku); rest → /adversarial-build --skip-probe. Confirm?"* — and wait. No codegen routing without the human's word.
  - `inline` mode: inline approval already covers cheap paths. Surface tiering in one line for transparency, then proceed.

**Log:** one route event per subtask — `--phase tier --event route --subtask <n> --tier <codegen|inline|default>`. Re-emit with new tier when mis-tier guard re-routes.

### Route — dispatch each subtask

Process in index order:
- **codegen** → invoke `/codegen-build` with subtask brief + `BUILD ID` + `<n>` + `PRE-EXISTING DIRT` + `PRE-BUILD BASE` + handoff path. On `BUILD FAILED` or re-tier signal, re-route to default tier (`/adversarial-build --skip-probe`).
- **default** → invoke `/adversarial-build --skip-probe` with subtask statement + goal + acceptance-criteria slice + discovery file path `discovery/<BUILD ID>.md` (pass by path, not inline) + task-type template + `BUILD ID` + `<n>` + `PRE-EXISTING DIRT` + `PRE-BUILD BASE` + handoff path + project pack `codeStyleRules` + `initialize` SKILL.md path (when announced). Returns handoff path + build verdict.
- **inline** (inline mode only) → you implement inline: edit files (conforming to the announced `codeStyleRules` output, when present), stage only your own (explicit paths, never `git add -A`), commit once with real subject, stamp Build-Id note (`scripts/build-notes.sh stamp <BUILD ID>.<n>`). Write handoff to `handoffs/<BUILD ID>.<n>.md` (EVIDENCE PACK / CLAIMS / DECISIONS / DIFF SUMMARY). If the subtask turns out to need real adversarial scrutiny, stop and re-route to default.

All tiers: **one commit per subtask, Build-Id noted, handoff at `handoffs/<BUILD ID>.<n>.md`.**

### Verify — task-reviewer (right thing?) *[cap: 3]*

Dispatch `task-reviewer` **once** over the whole range. Pass: goal, acceptance criteria (verbatim), `PRE-BUILD BASE`, range `<PRE-BUILD BASE>..HEAD`, `BUILD ID`, `PRE-EXISTING DIRT`, handoff paths, and the project pack `codeStyleRules` + `initialize` SKILL.md path when announced (enables its inner-loop style pass; omitted → it emits `style — N/A`). Returns per-criterion `MET / UNMET / UNVERIFIABLE` with evidence, owning `Build-Id.<n>` for each UNMET, plus `STYLE` (project style) findings.

- `STYLE` findings → relay each to its owning builder as a mechanical fix folded into that commit. Do not gate `ACCEPTANCE`.
- `ACCEPTANCE: MET` → **log** `--phase verify --event verdict --verdict MET --fix-loop <loops>`, proceed to Review.
- `ACCEPTANCE: UNMET` → **log** `--phase verify --event verdict --verdict UNMET --fix-loop <count>` (add `--cap-hit` at loop 3), relay each gap to the **owning subtask's builder** (which folds fix into that commit via amend or `--fixup` + `git rebase --autosquash <PRE-BUILD BASE>`), re-dispatch `task-reviewer` (fresh `Agent` call). **Cap: 3 loops.** After cap, or on `UNVERIFIABLE`, surface to user — human call required (BLOCK).

You own this loop. The reviewer judges each round; you drive the iteration.

### Review — turn-reviewer (thing right?)

Dispatch `turn-reviewer` **once** via `Agent` tool over the whole range. Brief: what the user asked (`<task>` + goal), what you did (orchestrated; note inline-tier edits as your own), handoff paths, `PRE-EXISTING DIRT` (labeled pre-existing), `BUILD ID`, range `<PRE-BUILD BASE>..HEAD` with `Audit scope: changes since <PRE-BUILD BASE>`.

**Project reviewers.** If the pack announced `reviewers`, dispatch each (via `Agent`) over the same range alongside `turn-reviewer`, passing the range `<PRE-BUILD BASE>..HEAD`, `PRE-EXISTING DIRT` (labeled pre-existing), the `codeStyleRules` command, and the `initialize` SKILL.md path. Triage their findings into the same verdict tiers; a pack reviewer's BLOCK is surfaced like any other. No `reviewers` announced → skip (generic `turn-reviewer` is the only Review gate).

**Log** verdict: `--phase review --event verdict --verdict <PASS|WARN|FIX|BLOCK>` (add `--fix-loop <n>` when FIX loop ran).

Handle per `protocols/adversarial/verdict-handling.md`. For a `FIX` needing builder involvement, relay to the owning builder with target Build-Id note key + `PRE-BUILD BASE`. Review FIXes are mechanical — no re-Verify needed.

### Deliver — PASS; verify purity and stop

On `turn-reviewer` PASS (or WARN with no blocking items):
1. **Verify range is exactly this run's commits.** `scripts/build-notes.sh range <BUILD ID> <PRE-BUILD BASE>` lists `<sha> <key>` for every noted commit. Distinct SHAs must equal `git rev-list <PRE-BUILD BASE>..HEAD` — any commit `range` omits is un-noted or keyed to a different run. Confirm exactly one note per subtask, indices `1..N`. Gap → surface and let user resolve; do NOT rewrite history.
2. **Leave history as-is.** No squash, no reword, no reset, no push.
3. **Summary** (1-2 sentences): what was implemented, per-subtask commit subjects + tiers, any unresolved holes/warnings.
4. **Log** `--phase deliver --event end`.
5. **Hand back.** This command completes one build-and-review unit; the caller may have its own process still to run. Return to the caller; do not treat Deliver as turn-end.

If the loop ends without a clean PASS (BLOCK or cap hit without convergence), surface the run's commits + unresolved findings; user decides.
