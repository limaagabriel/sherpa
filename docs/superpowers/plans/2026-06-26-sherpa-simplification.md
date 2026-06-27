# Sherpa Simplification Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Collapse sherpa's 5-deep adversarial dispatch chain into a 3-layer model (macro plan / step gate / build) with one builder and one pressure point per layer, deleting the redundant inner engine — without breaking Claude/Codex/Pi harness discovery.

**Architecture:** Three layers, each with one driver, one artifact, one pressure point; pressure lives at layer boundaries, never nested. L1 Macro = `plan` skill + `plan-reviewer`. L2 Step = `step-reviewer` (up-front, over all steps). L3 Build = `execute` skill driving one `builder` + two parallel reviewers (`acceptance-reviewer`, `quality-reviewer`). Layers made explicit by labeling (`Layer:` lines + layer-first README), never by moving files — each harness discovers components by its own convention.

**Tech Stack:** Markdown skills/agents/protocols, shell scripts, Codex `.toml` agent twins, JSON plugin manifests. No build system; verification is grep-sweeps + a real `/plan` smoke run.

## Global Constraints

- **No file moves across harness-convention dirs.** Claude reads `skills/` + `agents/` (convention, no `plugin.json` override). Codex reads `skills/` (via `.codex-plugin/plugin.json`) + `.codex/agents/*.toml`. Never relocate these.
- **Every agent has a Codex twin.** `agents/<x>.md` ⇔ `.codex/agents/<x>.toml`. Every create/delete/rename touches BOTH.
- **Never push. Commit only per task** (this plan's commits are fine; no `git push`).
- **No placeholders left in shipped files** — no TBD/TODO; no reference to a deleted agent/protocol/script.
- **Done-signal for every task: a clean grep sweep** (the named dead tokens appear only under `docs/`) plus the task's own check.

## Per-step acceptance (resolved)

L3 runs **two parallel reviewers we create**, distinct perspectives, after each step:
- `acceptance-reviewer` (plan perspective) — does the built step meet its acceptance criteria? Emits per-criterion `ACCEPTANCE: MET/UNMET`, relays gaps to the builder **once** (no 3-loop ceremony).
- `quality-reviewer` (quality perspective) — minimality, architecture, correctness, security, performance, edge cases, tests, regression. Emits `QUALITY: PASS/WARN/FIX/BLOCK`.

sherpa ships no dimension-reviewer fan-out (the old `staff/qa/accessibility` set and `protocols/code-review/base.md` aren't in this repo); a project pack may still announce extra `reviewers`.

`step-reviewer` (L2) still checks the **decomposition** up-front; `plan-reviewer mode=output` still checks the whole-plan **goal** at the end. The new reviewer fills the middle so a clean-but-wrong step is caught per-step, not late.

## File Structure (end state)

**Created**
- `agents/builder.md` + `.codex/agents/builder.toml` — the single L3 builder.
- `agents/acceptance-reviewer.md` + `.codex/agents/acceptance-reviewer.toml` — L3 plan-perspective reviewer.
- `agents/quality-reviewer.md` + `.codex/agents/quality-reviewer.toml` — L3 quality-perspective reviewer.

**Renamed + rewritten (content, not just path)**
- `agents/plan-breaker.md` → `agents/plan-reviewer.md` (+ `.toml`) — L1; absorbs turn-reviewer's reasoning lens.
- `agents/task-reviewer.md` → `agents/step-reviewer.md` (+ `.toml`) — L2; repurposed to up-front decomposition gate.

**Rewritten (same path)**
- `skills/execute/SKILL.md` — drives one builder + two reviewers; no tiering/build-id/handoffs/inline.
- `protocols/workflow/phases/execute.md`, `validate.md`, `plan.md` — rewired to new names, verdict logic inlined.

**Deleted**
- Skills: `skills/adversarial-build/`, `skills/codegen-build/`, `skills/build-and-review/`, `skills/turn-review/`.
- Agents (+ `.codex/agents/*.toml` twins): `adversarial-breaker`, `adversarial-drafter`, `adversarial-builder`, `codegen-builder`, `turn-reviewer`.
- Protocols: `protocols/adversarial/` (README + verdict-handling), `protocols/invariants/{tiering-catalog,build-id,inline-mode}.md`.
- Scripts: `scripts/{build-notes.sh,build-log.sh,fold-fix.sh}`.

**Edited for references only**
- `protocols/invariants/mutating-bash-verbs.md`, `packs/README.md`, `packs/TEMPLATE/SKILL.md`, `AGENTS.md`, `.codex/agents/README.md`, `README.md`.

---

### Task 1: Create the new L3 agents (builder + acceptance-reviewer + quality-reviewer)

**Files:**
- Create: `agents/builder.md`
- Create: `.codex/agents/builder.toml`
- Create: `agents/acceptance-reviewer.md`
- Create: `.codex/agents/acceptance-reviewer.toml`
- Create: `agents/quality-reviewer.md`
- Create: `.codex/agents/quality-reviewer.toml`

**Interfaces:**
- Consumes (from `execute`): `task`, `Goal`, `Acceptance criteria`, `PRE-EXISTING DIRT`, project-pack `codeStyleRules` + `initialize` SKILL.md path (when announced), target model (set by caller).
- Produces: exactly one commit (real subject, no Build-Id note); a short handoff (EVIDENCE / CLAIMS / DIFF SUMMARY) returned as final text; a build verdict `BUILT` | `BUILD FAILED`.

- [ ] **Step 1: Write `agents/builder.md`** with this content:

```markdown
---
name: builder
description: The single sherpa builder (L3). Implements ONE plan step — search, edit, build/test — and lands exactly one commit with a real subject. No build-id notes, no briefing, no tiering. Returns a short handoff + a BUILT/BUILD FAILED verdict. Never pushes.
Layer: build
---

# builder — L3

Implement one approved step and commit it. You are dispatched once per step by `/execute`.

## Inputs (from caller)
- `task` — the step to implement.
- `Goal` — one-sentence outcome (goal contract).
- `Acceptance criteria` — observable end states (`done = <X>, confirmed by <check>`).
- `PRE-EXISTING DIRT` — `git status --short` from before your run; never stage or claim it.
- Project pack `codeStyleRules` command + `initialize` SKILL.md path — when announced; `Read` the SKILL.md (no Skill tool), conform output to the rules.

## Rules
- **One commit, real subject.** Stage only files you changed (explicit paths, never `git add -A`). No Build-Id note. Never amend/reset/reword another commit. Never push.
- **Guard clauses, SRP, short functions, no inline comments, never `any`.**
- **Build/test before committing.** Run the acceptance check; if it can't pass, return `BUILD FAILED` with the evidence rather than committing broken work.
- **Mutating Bash only for your own build/test/commit** — never history rewrites.

## Output (final text = the return value)
- `VERDICT: BUILT` (committed `<sha> <subject>`) or `VERDICT: BUILD FAILED` (why).
- `EVIDENCE` — the check you ran + its result.
- `DIFF SUMMARY` — files touched, one line each.
```

- [ ] **Step 2: Write `.codex/agents/builder.toml`** mirroring an existing twin's shape. Read `.codex/agents/codegen-builder.toml` for the exact field set, then write the equivalent for `builder` (same keys, description matching the `.md`, model left to caller).

```bash
cat .codex/agents/codegen-builder.toml   # copy its key structure
```

- [ ] **Step 3: Write `agents/acceptance-reviewer.md`** with this content:

```markdown
---
name: acceptance-reviewer
description: Per-step acceptance reviewer (L3, plan perspective). Read-only. Given a built step's commit range + its acceptance criteria, judges each criterion MET/UNMET with evidence — does the code do what the step promised, regardless of code quality. Relays gaps to the builder once; no multi-loop. Distinct from the quality-reviewer.
Layer: build
---

# acceptance-reviewer — L3 (plan perspective)

Check one built step against **what it promised**. You judge intent-met, not code taste — the `quality-reviewer` owns quality.

## Input
- The step's `Goal` + `Acceptance criteria` (verbatim).
- The commit range for this step (`<base>..HEAD`).
- `PRE-EXISTING DIRT` — never attribute it to this step.

## What you do
- For each acceptance criterion, run/inspect its stated check and judge `MET` | `UNMET` | `UNVERIFIABLE`, each with evidence (the check + its result, or the file:line that satisfies it).
- You do NOT judge style, naming, or architecture — that's the `quality-reviewer`'s lens.

## Output
- Per criterion: `ACCEPTANCE: <criterion> — MET | UNMET: <gap> | UNVERIFIABLE: <why>`.
- Overall: `ACCEPTANCE: MET` (all met) or `ACCEPTANCE: UNMET` (≥1 gap) or `BLOCK` (≥1 unverifiable).
```

- [ ] **Step 4: Write `.codex/agents/acceptance-reviewer.toml`** mirroring `.codex/agents/builder.toml`'s field set, description matching the `.md`.

- [ ] **Step 5: Write `agents/quality-reviewer.md`** with this content:

```markdown
---
name: quality-reviewer
description: Per-step quality reviewer (L3, quality perspective). Read-only. Given a built step's commit range, audits the diff for minimality, architecture, correctness, security, performance, edge cases, test coverage, and regression risk. One general reviewer — sherpa ships no dimension-reviewer fan-out. Judges code quality, not whether the step met its acceptance criteria (that's the acceptance-reviewer). Self-contained.
Layer: build
---

# quality-reviewer — L3 (quality perspective)

Audit one built step's diff for quality. You judge code taste and correctness, not intent-met — the `acceptance-reviewer` owns "meets the spec."

## Input
- The step's commit range (`<base>..HEAD`).
- `PRE-EXISTING DIRT` — never attribute it to this step.

## What you audit
- **Minimality** — no speculative abstraction, no dead flexibility, simplest thing that works.
- **Architecture** — SRP, guard clauses, short functions, no inline comments; fits surrounding patterns.
- **Correctness** — logic holds; edge cases (empty, missing, duplicate, malformed) handled.
- **Security** — input validation at trust boundaries; no injection/secret-leak.
- **Performance** — no obvious O(n²) on hot paths, no needless work.
- **Tests + regression** — non-trivial logic carries a runnable check; change doesn't break neighbors.

## Output
- Findings tiered `BLOCK | FIX | WARN`, each with `file:line` evidence and a one-line fix.
- Overall: `QUALITY: PASS | WARN | FIX | BLOCK`.
```

- [ ] **Step 6: Write `.codex/agents/quality-reviewer.toml`** mirroring `.codex/agents/builder.toml`'s field set, description matching the `.md`.

- [ ] **Step 7: Verify all six exist and the agents carry the layer tag**

Run: `for f in agents/builder.md agents/acceptance-reviewer.md agents/quality-reviewer.md; do grep -q '^Layer: build' "$f" || echo "BAD $f"; done; for f in .codex/agents/builder.toml .codex/agents/acceptance-reviewer.toml .codex/agents/quality-reviewer.toml; do test -f "$f" || echo "MISSING $f"; done; echo done`
Expected: `done` with no `BAD`/`MISSING` lines.

- [ ] **Step 8: Commit**

```bash
git add agents/builder.md agents/acceptance-reviewer.md agents/quality-reviewer.md .codex/agents/builder.toml .codex/agents/acceptance-reviewer.toml .codex/agents/quality-reviewer.toml
git commit -m "sherpa-simplify: add L3 builder + acceptance-reviewer + quality-reviewer agents"
```

---

### Task 2: Rename plan-breaker → plan-reviewer (absorb reasoning audit)

**Files:**
- Rename: `agents/plan-breaker.md` → `agents/plan-reviewer.md`
- Rename: `.codex/agents/plan-breaker.toml` → `.codex/agents/plan-reviewer.toml`
- Modify: every caller of `plan-breaker` (see Step 3 grep).

**Interfaces:**
- Produces: `plan-reviewer` agent, two modes — `mode=briefing` (attacks plan goal well-formedness + architecture + **reasoning soundness**, used in `plan.md`) and `mode=output` (attacks whether the delivered plan achieved its goal, used in `validate.md`).

- [ ] **Step 1: Move both files**

```bash
git mv agents/plan-breaker.md agents/plan-reviewer.md
git mv .codex/agents/plan-breaker.toml .codex/agents/plan-reviewer.toml
```

- [ ] **Step 2: Edit `agents/plan-reviewer.md`** — set `name: plan-reviewer`; in the description and body, replace "plan-breaker" with "plan-reviewer"; add `Layer: macro` to frontmatter. Add a reasoning-audit lens (absorbed from the deleted turn-reviewer): under its lens list, add a bullet — `Reasoning soundness — root-cause claims, "what the code does" conclusions, and citations are checked; a plausible-but-unfounded rationale is a finding.` Apply the same name change inside `.codex/agents/plan-reviewer.toml`.

- [ ] **Step 3: Update every caller.** Find them, replace the token:

```bash
grep -rIl --exclude-dir=.git --exclude-dir=docs -- plan-breaker .
```
Expected list: `packs/README.md`, `packs/TEMPLATE/SKILL.md`, `protocols/workflow/phases/{analyze,plan,validate}.md`, `skills/{execute,plan}/SKILL.md`, `.codex/agents/README.md`. In each, replace `plan-breaker` → `plan-reviewer`.

- [ ] **Step 4: Verify no stray references**

Run: `grep -rIl --exclude-dir=.git --exclude-dir=docs -- plan-breaker . ; echo "exit=$?"`
Expected: no files printed (`grep` exit non-zero).

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "sherpa-simplify: plan-breaker -> plan-reviewer (L1, absorbs reasoning audit)"
```

---

### Task 3: Repurpose task-reviewer → step-reviewer (up-front decomposition gate)

**Files:**
- Rename: `agents/task-reviewer.md` → `agents/step-reviewer.md`
- Rename: `.codex/agents/task-reviewer.toml` → `.codex/agents/step-reviewer.toml`
- Modify: callers of `task-reviewer` (Step 4 grep).

**Interfaces:**
- Produces: `step-reviewer` agent. Input: the **full step list** (each step's goal contract + acceptance criteria) + the plan goal + `SPEC.md` path. Output: per-step `SOUND | GAP | MISSING-FOUNDATION` with evidence, and an overall `DECOMPOSITION: COMPLETE | INCOMPLETE`. Runs ONCE, before step 1 is built. Does NOT read a built diff.

- [ ] **Step 1: Move both files**

```bash
git mv agents/task-reviewer.md agents/step-reviewer.md
git mv .codex/agents/task-reviewer.toml .codex/agents/step-reviewer.toml
```

- [ ] **Step 2: Rewrite `agents/step-reviewer.md`** to the new role (it currently judges built acceptance; it now judges the decomposition up-front). Content:

```markdown
---
name: step-reviewer
description: Up-front step-decomposition gate (L2). Read-only. Given the plan goal + the full step list, judges whether the decomposition is complete BEFORE any step is built — does each step trace to the goal, is anything later steps depend on missing from the start, do steps overlap or leave a gap. Returns per-step verdicts + an overall COMPLETE/INCOMPLETE. Does not read built code. Self-contained.
Layer: step
---

# step-reviewer — L2

Pressure the plan's **decomposition** once, before building begins. You never see a diff — you see the plan.

## Input
- The **plan goal** (goal contract).
- The **full step list** — each step's goal contract + acceptance criteria.
- `SPEC.md` path (read for context; don't paste it back).

## What you attack
- **Traceability** — each step's Outcome advances the plan goal; an orphan step is a finding.
- **Missing foundation** — something steps 2..N depend on that no earlier step establishes.
- **Gap** — the steps don't sum to the after-state; the goal can't be reached as listed.
- **Overlap** — two steps build the same thing; one is dead weight.
- **Ordering** — a step depends on a later step's output.

## Output
- Per step: `SOUND` | `GAP: <what>` | `MISSING-FOUNDATION: <what>`.
- Overall: `DECOMPOSITION: COMPLETE` or `DECOMPOSITION: INCOMPLETE — <one-line summary>`.
```

- [ ] **Step 3: Update `.codex/agents/step-reviewer.toml`** — set `name`/description to match the rewritten `.md`.

- [ ] **Step 4: Update callers.** Find and rewire:

```bash
grep -rIl --exclude-dir=.git --exclude-dir=docs -- task-reviewer .
```
Survivors that keep a reference (`packs/README.md`, `packs/TEMPLATE/SKILL.md` if present, `.codex/agents/README.md`, `protocols/workflow/phases/{plan,validate}.md`): replace `task-reviewer` → `step-reviewer` and adjust any surrounding wording that described per-acceptance judging to the decomposition-gate role. Callers that are themselves being deleted (Task 6) need no edit.

- [ ] **Step 5: Verify**

Run: `grep -rIl --exclude-dir=.git --exclude-dir=docs -- task-reviewer . ; echo "exit=$?"`
Expected: no files printed.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "sherpa-simplify: task-reviewer -> step-reviewer (L2 up-front decomposition gate)"
```

---

### Task 4: Rewrite the execute skill (drive one builder + reviewers)

**Files:**
- Modify: `skills/execute/SKILL.md` (full rewrite of Gates 2 & 5).

**Interfaces:**
- Consumes: `builder`, `acceptance-reviewer`, `quality-reviewer` (Task 1), `step-reviewer` (Task 3), `plan-reviewer` (Task 2), optional pack `reviewers`.
- Produces: the L3 execution loop with the haiku model rule at dispatch time.

- [ ] **Step 1: Replace the skill body** with this content (keep the frontmatter `name: execute`, update the description to drop "build-and-review" / "inline"):

```markdown
---
name: execute
description: Drive the Execute -> Validate half of the workflow against an approved plan — read SPEC/DECISIONS/PROGRESS, gate the decomposition once (step-reviewer), build each step (one builder + acceptance/quality reviewers), then validate the plan goal (plan-reviewer). Triggers - "/execute", "/execute <key>", "execute the plan". Requires a plan from /plan; /workflow chains both.
---

# /execute — Execute, Validate

Run an **approved plan** to completion and verify it met its goal. Requires `SPEC.md` (with an appended plan) under the run-state dir — produced by `/plan`.

## Operating rules
- Same Authority / Stance / no-narration / Conventions rules as `/plan`.
- **Never push.** Commit only when the human asks. The builder owns one commit per step — never add a manual commit on top.
- **Harness:** under Codex CLI, read Claude-specific tool mentions per `${CLAUDE_PLUGIN_ROOT}/protocols/harness/codex.md`.

## Gates (run in order)

1. **Load run-state.** Resolve `BASE` per `state-persistence.md` § Run-state directory; `<key>` = given arg, else current branch. Read `$BASE/<key>/{SPEC,DECISIONS,PROGRESS}.md`. No approved plan → stop, tell the human to run `/plan`. Resuming a partial run → re-enter at the earliest unfinished step (see `${CLAUDE_PLUGIN_ROOT}/skills/workflow-resume/SKILL.md`).
2. **Step gate (L2, once).** Dispatch `step-reviewer` over the full step list + plan goal + `SPEC.md` path. `DECOMPOSITION: INCOMPLETE` → surface to the human (BLOCK); do not start building until resolved.
3. **Execute (L3).** Follow `${CLAUDE_PLUGIN_ROOT}/protocols/workflow/phases/execute.md`: one task per step, exactly one in-progress. Per step:
   - **Model rule:** is this step pure automated codegen — run a generator, commit its output, no hand-written logic? → dispatch `builder` at model **haiku**. Otherwise → default model.
   - Dispatch `builder` with `task` + `Goal` + `Acceptance criteria` + `PRE-EXISTING DIRT` + pack `codeStyleRules`/`initialize` path (when announced).
   - On `BUILT`, run the two L3 reviewers in parallel over the step's commit range: `acceptance-reviewer` (plan perspective — pass the acceptance criteria; emits `ACCEPTANCE: MET/UNMET`) and `quality-reviewer` (quality perspective — emits `QUALITY: PASS/WARN/FIX/BLOCK`). A project pack may add extra `reviewers` alongside these two.
   - **Verdict rule:** `ACCEPTANCE: UNMET` or a mechanical quality FIX → relay to the builder to fold into its commit, then re-check once; PASS / WARN → next step. BLOCK, `UNVERIFIABLE`, or an unresolved finding → stop, wait for the human.
4. **Rewrite PROGRESS on every step transition.** Full rewrite, never appended (`state-persistence.md` § Write rules).
5. **Validate.** Follow `${CLAUDE_PLUGIN_ROOT}/protocols/workflow/phases/validate.md`: run the test plan; run the pack's `codeStyleAudit` if announced (else skip); dispatch `plan-reviewer mode=output` to confirm the plan goal holds. One final PROGRESS rewrite.

## Done when
Every step completed, PROGRESS in-flight = `none`, Validate confirms the plan goal, no unresolved BLOCK.
```

- [ ] **Step 2: Verify no dead references remain in the skill**

Run: `grep -nE 'build-and-review|turn-review|inline-mode|verdict-handling|tiering|build-id' skills/execute/SKILL.md ; echo "exit=$?"`
Expected: no matches.

- [ ] **Step 3: Commit**

```bash
git add skills/execute/SKILL.md
git commit -m "sherpa-simplify: execute drives one builder + reviewers, no inner engine"
```

---

### Task 5: Rewire the workflow phase docs

**Files:**
- Modify: `protocols/workflow/phases/execute.md`
- Modify: `protocols/workflow/phases/validate.md`
- Modify: `protocols/workflow/phases/plan.md`

**Interfaces:** inlines the verdict rule (so `verdict-handling.md` can be deleted in Task 6) and the new agent names.

- [ ] **Step 1: Rewrite `protocols/workflow/phases/execute.md`** to:

```markdown
# Execute

Build the plan one step at a time with a single builder + two reviewers (acceptance, quality).

## TaskCreate / TaskUpdate
- One task per step. Exactly one `in_progress` at a time.
- Flip to `completed` only on the step's commit landing.

## Per-step build
Dispatch `builder` with the step's `task` + `Goal` + `Acceptance criteria` (+ pack `codeStyleRules`/`initialize` path when announced). Pure-codegen step → dispatch at model haiku; else default. Each step:
- Builds in isolation — module still builds, no half-applied artifacts.
- Lands exactly one commit (real subject, no Build-Id note). The builder owns it; never add a manual commit on top.
- On `BUILT`, two L3 reviewers run in parallel over the step's range: `acceptance-reviewer` (plan perspective — meets its criteria?) and `quality-reviewer` (quality perspective — clean, correct, secure, no regression).

## Verdicts
`ACCEPTANCE: UNMET` or a mechanical quality FIX → relay to the builder (folded into its commit), re-check once. PASS / WARN → next step. BLOCK or unresolved finding → wait for the human.
```

- [ ] **Step 2: Edit `protocols/workflow/phases/validate.md`** — replace `plan-breaker` with `plan-reviewer` (already done in Task 2 if it ran; confirm). Replace the two `Handle ... per protocols/adversarial/verdict-handling.md` references with an inline rule: `Handle the verdict: PASS/WARN/auto-cleared FIX → record and continue; BLOCK or unresolved finding → surface verbatim and wait for the human.` Leave the `codeStyleAudit` paragraph intact but drop its `verdict-handling.md § Code-style audit` pointer, replacing with the same inline rule.

- [ ] **Step 3: Edit `protocols/workflow/phases/plan.md`** — confirm `plan-breaker` → `plan-reviewer` (Task 2). Replace each `Handle per protocols/adversarial/verdict-handling.md` with the inline verdict rule from Step 2. In the "Adversarial goal review" section, keep `mode=briefing`. Remove the `task-reviewer`-as-step-driver clause in § Goal contract "Two layers" and reword: `each step goal is the local driver (its acceptance verified by the L3 acceptance-reviewer) and must trace up to it.`

- [ ] **Step 4: Verify phases are clean**

Run: `grep -rnE 'plan-breaker|task-reviewer|turn-review|verdict-handling|build-and-review|inline-mode' protocols/workflow/phases/ ; echo "exit=$?"`
Expected: no matches.

- [ ] **Step 5: Commit**

```bash
git add protocols/workflow/phases/
git commit -m "sherpa-simplify: rewire phase docs to 3-layer model, inline verdict rule"
```

---

### Task 6: Delete the inner engine

**Files:** delete (with Codex twins) — see commands.

- [ ] **Step 1: Delete skills**

```bash
git rm -r skills/adversarial-build skills/codegen-build skills/build-and-review skills/turn-review
```

- [ ] **Step 2: Delete agents + their Codex twins**

```bash
git rm agents/adversarial-breaker.md agents/adversarial-drafter.md agents/adversarial-builder.md agents/codegen-builder.md agents/turn-reviewer.md
git rm .codex/agents/adversarial-breaker.toml .codex/agents/adversarial-builder.toml .codex/agents/adversarial-drafter.toml .codex/agents/codegen-builder.toml .codex/agents/turn-reviewer.toml
```

- [ ] **Step 3: Delete protocols + scripts**

```bash
git rm -r protocols/adversarial
git rm protocols/invariants/tiering-catalog.md protocols/invariants/build-id.md protocols/invariants/inline-mode.md
git rm scripts/build-notes.sh scripts/build-log.sh scripts/fold-fix.sh
```

- [ ] **Step 4: Verify nothing outside `docs/` still references a deleted token**

Run:
```bash
grep -rIlE --exclude-dir=.git --exclude-dir=docs -- 'adversarial-build|codegen-build|build-and-review|turn-review|adversarial-breaker|adversarial-drafter|adversarial-builder|codegen-builder|turn-reviewer|verdict-handling|tiering-catalog|build-id|inline-mode|build-notes|build-log|fold-fix' .
echo "exit=$?"
```
Expected: no files printed (only Task 7 peripheral files may remain — fix them there if any appear).

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "sherpa-simplify: delete the inner adversarial/codegen build engine"
```

---

### Task 7: Clean peripheral references + make layers explicit

**Files:**
- Modify: `protocols/invariants/mutating-bash-verbs.md`, `packs/README.md`, `packs/TEMPLATE/SKILL.md`, `AGENTS.md`, `.codex/agents/README.md`, `README.md`.

- [ ] **Step 1: Purge dead tokens from peripheral files.** For each file the Task-6 Step-4 grep surfaced (plus the list above), remove or reword every mention of a deleted skill/agent/protocol/script. `mutating-bash-verbs.md`: drop the build-notes/build-log/build-id/coordinator examples, keep the general read-only-Bash rule. `packs/*`: point pack examples at `plan-reviewer`/`step-reviewer`/`builder`; drop `tiering-catalog`/`codegen-build` capability rows. `AGENTS.md` + `.codex/agents/README.md`: update the agent roster to the surviving set.

- [ ] **Step 2: Add a `Layer:` line to every component.** Skills: `workflow`/`plan` → `Layer: cross-cutting`/`macro`; `execute` → `build`; `scout` → `macro`; `workflow-resume` → `cross-cutting`. Agents: `plan-reviewer` macro, `step-reviewer` step, `builder` + `acceptance-reviewer` + `quality-reviewer` build. Put it in SKILL.md frontmatter / agent frontmatter (already added for the three new/renamed agents in Tasks 1–3).

- [ ] **Step 3: Rewrite `README.md`'s component index grouped by layer** — sections `## L1 Macro`, `## L2 Step`, `## L3 Build`, `## Cross-cutting`, each listing its skills/agents one line each. Remove every reference to deleted components.

- [ ] **Step 4: Full repo grep sweep**

Run:
```bash
grep -rIlE --exclude-dir=.git --exclude-dir=docs -- 'adversarial-build|codegen-build|build-and-review|turn-review|adversarial-breaker|adversarial-drafter|adversarial-builder|codegen-builder|turn-reviewer|verdict-handling|tiering-catalog|build-id|inline-mode|build-notes|build-log|fold-fix|plan-breaker|task-reviewer' .
echo "exit=$?"
```
Expected: no files printed.

- [ ] **Step 5: Verify every component carries a layer tag**

Run:
```bash
for f in skills/*/SKILL.md agents/*.md; do grep -q '^Layer:' "$f" || echo "MISSING: $f"; done
```
Expected: no `MISSING:` lines.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "sherpa-simplify: purge peripheral refs, make layers explicit (labels + README)"
```

---

### Task 8: Smoke test the workflow

**Files:** none modified; this is the integration check.

- [ ] **Step 1: Validate plugin manifests still parse**

Run: `python3 -c "import json,sys; [json.load(open(p)) for p in ['.claude-plugin/plugin.json','.claude-plugin/marketplace.json','.codex-plugin/plugin.json','hooks/hooks.json']]; print('OK')"`
Expected: `OK`

- [ ] **Step 2: Confirm every skill/agent referenced by a surviving skill resolves to a real file.** For each `${CLAUDE_PLUGIN_ROOT}/...` and bare agent name in `skills/*/SKILL.md` and `protocols/workflow/phases/*.md`, confirm the target exists:

```bash
grep -rhoE 'skills/[a-z-]+/SKILL\.md|agents/[a-z-]+\.md|protocols/[a-z/]+\.md|scripts/[a-z-]+\.sh' skills protocols | sort -u | while read p; do test -e "$p" || echo "DANGLING: $p"; done
```
Expected: no `DANGLING:` lines (paths printed without the `${CLAUDE_PLUGIN_ROOT}/` prefix resolve from repo root).

- [ ] **Step 3: Dry-run `/plan` reasoning (manual).** In a throwaway branch, invoke `/plan add a no-op helper` far enough to confirm: the skill loads, Discover/Analyze/Plan phases read without referencing a deleted file, and the `plan-reviewer mode=briefing` dispatch names a real agent. Stop at the approval gate (don't execute). Record the result in the commit message. This is manual because the workflow needs a live agent session — no automated check is possible.

- [ ] **Step 4: Run the surviving script test**

Run: `sh scripts/test-resolve-project-pack.sh`
Expected: its existing pass output (unchanged by this refactor).

- [ ] **Step 5: Commit the smoke-test note**

```bash
git commit --allow-empty -m "sherpa-simplify: smoke test — manifests parse, no dangling refs, /plan loads clean"
```

---

## Self-Review

- **Spec coverage:** 3-layer model (Tasks 2–5), one builder + haiku rule (Tasks 1, 4–5), two L3 reviewers `acceptance-reviewer` + `quality-reviewer` (Tasks 1, 4–5), delete list incl. fold-fix (Task 6), layers-by-labeling + Codex twins (Tasks 1–3, 7), harness-safe no-moves (Global Constraints) — all mapped.
- **Placeholder scan:** new file contents are shown in full; reference patches give exact grep + token. No TBD/TODO. No reference to the non-existent `protocols/code-review/base.md` or dimension reviewers.
- **Type/name consistency:** `plan-reviewer` (modes briefing/output), `step-reviewer` (DECOMPOSITION verdict), `builder` (BUILT/BUILD FAILED), `acceptance-reviewer` (ACCEPTANCE: MET/UNMET), `quality-reviewer` (QUALITY: PASS/WARN/FIX/BLOCK) used consistently across tasks.
- **Resolved decision:** L3 = two purpose-built parallel reviewers (acceptance + quality); no dimension-reviewer fan-out.
