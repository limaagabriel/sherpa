---
name: adversarial-build
description: Adversarial build engine for ONE subtask. Briefs, vets (breaker), builds, probes output (breaker). --skip-vet/--skip-probe gate each breaker phase. Lands one commit. Args: <subtask> + discovery input.
---

**Build-Id note:** Follow `protocols/invariants/build-id.md`.
**Inline mode:** Follow `protocols/invariants/inline-mode.md`.
**Mutating-bash verbs:** Read `protocols/invariants/mutating-bash-verbs.md` — coordinator Bash is read-only.

## Prime directive

You are coordinator only. Never search the codebase or edit source files — that is the builder's job. Bash is read-only git: Prep snapshot (`git status`, `git rev-parse`) and Deliver purity check (`git log`). Never squash, reword, reset, or rewrite history. Dispatch the drafter; relay findings. Nothing else.

Builds **one subtask**. Does not split work, scout, or run the final review — `/build-and-review` owns those. adversarial-build is the default-tier worker `/build-and-review` dispatches per subtask; when invoked standalone, the caller must supply the discovery context.

## Relationship to /build-and-review

adversarial-build receives per dispatch:
- subtask statement + its **goal** and **acceptance criteria**
- discovery file path `discovery/<BUILD ID>.md` (coordinator and breaker `Read` it by path, never pasted inline)
- task-type + required template fields (`protocols/invariants/task-types.md`)
- run context: `BUILD ID`, subtask index `<n>`, `PRE-EXISTING DIRT`, `PRE-BUILD BASE`, handoff path
- project pack `codeStyleRules` command + `initialize` SKILL.md path when announced upstream — forward to the builder (run `codeStyleRules` for the rules, then write conforming code; `Read` the `initialize` SKILL.md for conventions) and the Probe breaker (run `codeStyleRules` to check project style; `Read` the `initialize` SKILL.md); absent → style steps fall back to the file's language conventions + in-file/module precedent. The drafter is style/knowledge-agnostic (it only writes the briefing; the builder owns conformance) — it receives neither key.

**Standalone:** caller supplies discovery context directly (inline or file path); no `discovery/<BUILD ID>.md` to read.

Does **not** write outer workflow run-state (`SPEC.md`, `DECISIONS.md`, `PROGRESS.md`). Writes `briefings/<BUILD ID>.<n>.md`. Its commit feeds the range `/build-and-review` Verifies and Reviews.

## Arguments

- `<subtask>` (required): work to implement, with goal + acceptance criteria.
- `--skip-vet`: skip Vet sub-phase (breaker `mode=briefing`). Drafter still runs its self-review; only the breaker dispatch + rewrite loop are dropped.
- `--skip-probe`: skip Probe sub-phase (breaker `mode=output`). Build still implements, commits, and writes handoff; build-failure relays still run.
- Run context (from `/build-and-review`; self-generate when standalone): `BUILD ID`, `<n>`, `PRE-EXISTING DIRT`, `PRE-BUILD BASE`, handoff path, project pack `codeStyleRules` command + `initialize` SKILL.md path (when announced).

Tiering is decided upstream. The only knobs here are `--skip-vet` / `--skip-probe`. Default-tier wiring passes `--skip-probe` (output re-attacked downstream by `task-reviewer` + `turn-reviewer`). Both flags together reduce the loop to Brief → Build → Deliver.

---

## The loop

### Logging

Emit one event per phase boundary via `scripts/build-log.sh` (queryable via `--stats`). Always pass `--build-id <BUILD ID> --coord adversarial-build --subtask <n>`; per-phase fields below. Never block the loop on log failure.

`--hole-classes` maps the breaker verdict to catalog class(es), comma-joined:
- **Vet** (`mode=briefing`): `ambiguous_instruction`, `missing_acceptance_criteria`, `unstated_assumption`, `infeasibility`, `precedent_gap`, `success_undefined`.
- **Probe** (`mode=output`): `edge_case`, `breaking_input`, `unsupported_claim`, `briefing_gap`, `missing_negative_path`, `style_violation` (only when a project pack `codeStyleRules` command was forwarded).

### Prep

When dispatched by `/build-and-review`, use supplied `BUILD ID`, `<n>`, `PRE-EXISTING DIRT`, `PRE-BUILD BASE` verbatim — never regenerate. When standalone: `git status --short` → `PRE-EXISTING DIRT`; `git rev-parse HEAD` → `PRE-BUILD BASE`; `scripts/build-id.sh` → `BUILD ID` with `<n> = 1`; `scripts/build-notes.sh init` → repo-local notes config.

**Log:** `--phase prep --event start`.

### Brief — Write briefing + Vet *(Vet skipped when `--skip-vet`)*

#### Dispatch the drafter

Dispatch `adversarial-drafter` (`model: sonnet`). Pass:
- Discovery file **path** `discovery/<BUILD ID>.md` — drafter `Read`s it; does not re-scout.
- Subtask statement, `goal`, acceptance-criteria slice.
- Task-type template (required fields become mandatory briefing sections).
- `BUILD ID`, subtask index `<n>`.
- Briefing file **path** to write: `briefings/<BUILD ID>.<n>.md`.

The drafter writes six spec sections (Goal, Acceptance criteria, Assumptions, Edge cases, Change map, Constraints), runs its self-review gate, persists to `briefings/<BUILD ID>.<n>.md`, and returns only `DRAFTED briefings/<BUILD ID>.<n>.md`. The briefing must exist and be non-empty before Vet or Build fire (Vet and builder `Read` it by path). Under `--skip-vet`, this single Draft dispatch is the only spec check.

#### Vet *(skipped when `--skip-vet`)*

Dispatch `adversarial-breaker` (`mode=briefing`, `model: sonnet`). Pass:
- Briefing file **path** `briefings/<BUILD ID>.<n>.md` — breaker verifies it exists and is non-empty.
- Discovery file **path** `discovery/<BUILD ID>.md`.
- `PRE-EXISTING DIRT` snapshot.

On `VERDICT: HOLES` → **log** `--phase vet --event verdict --verdict HOLES --rewrite <count> --hole-classes <classes>` (add `--cap-hit` at rewrite 2), then re-dispatch `adversarial-drafter` in Rewrite mode with the hole-list (drafter overwrites `briefings/<BUILD ID>.<n>.md`, returning `REWRITTEN <path>`), then re-dispatch the breaker. **Cap: 2 rewrites.** After cap, proceed with best available briefing and note unresolved holes in summary.

Re-dispatch is always a **fresh `Agent` call**, never `SendMessage`. Both drafter and breaker are stateless.

On `VERDICT: SOLID` → **log** `--phase vet --event verdict --verdict SOLID --rewrite <total>`, proceed to Build.

### Build — Implement + Probe *(Probe skipped when `--skip-probe`)*

#### Implement

Dispatch `adversarial-builder` (`model: sonnet`). Pass:
- Vetted briefing file **path** `briefings/<BUILD ID>.<n>.md`.
- `PRE-EXISTING DIRT` snapshot.
- `BUILD ID` and `<n>`.
- Project pack `codeStyleRules` command + `initialize` SKILL.md path (when announced) — run `codeStyleRules` for the rules and write conforming code from the start; `Read` the `initialize` SKILL.md for conventions.
- Absolute handoff path `handoffs/<BUILD ID>.<n>.md`.

Builder commits once with a real subject + Build-Id note, writes OUTPUT CONTRACT (EVIDENCE PACK / CLAIMS / DECISIONS / DIFF SUMMARY ending with commit SHA), and returns handoff path + `BUILD OK <short SHA>` / `BUILD FAILED <reason>`.

**Log** builder verdict: `--phase build --event verdict --verdict <OK|FAILED>` (add `--fix-loop <count>` once a relay has occurred).

Build/test failure → relay back as output-fix request (builder amends its commit). **Cap: ≤3 fix loops total, shared with Probe.** Build-failure relays run even under `--skip-probe`.

#### Probe *(skipped when `--skip-probe`)*

Output is re-attacked downstream by `task-reviewer` + `turn-reviewer` over the whole range when skipped.

Dispatch `adversarial-breaker` (`mode=output`, `model: sonnet`). Pass:
- Handoff file **path** `handoffs/<BUILD ID>.<n>.md` — breaker verifies path exists and commit carries expected Build-Id note.
- `PRE-EXISTING DIRT` snapshot.
- `BUILD ID`.
- `PRE-BUILD BASE` SHA, with instruction to inspect via `git diff <PRE-BUILD BASE>..HEAD`.
- Project pack `codeStyleRules` command + `initialize` SKILL.md path (when announced) — running `codeStyleRules` enables the `style_violation` hole-class against project rules (`Read` the `initialize` SKILL.md for conventions); absent → the breaker checks `style_violation` against the file's language conventions + in-file/module precedent.

On `VERDICT: HOLES` → **log** `--phase probe --event verdict --verdict HOLES --fix-loop <count> --hole-classes <classes>` (add `--cap-hit` at fix loop 3), relay each hole to `adversarial-builder` as a fix request (amends commit), re-dispatch breaker (fresh `Agent` call). **Cap: 3 fix loops total (shared with Build-failure relays).** After cap, surface remaining holes in summary and proceed.

On `VERDICT: SOLID` → **log** `--phase probe --event verdict --verdict SOLID --fix-loop <total>`, Deliver.

### Deliver

1. **Verify the commit is yours.** `scripts/build-notes.sh head-key` — confirm HEAD note key-set contains `<BUILD ID>.<n>`. If not, surface it; do not rewrite history.
2. **Leave history as-is.** No squash, no reword, no reset, no push.
3. **Return** handoff path + one-line build verdict to caller.
4. **Log** `--phase deliver --event end`.

A later Verify/Review FIX targeting this subtask is relayed by `/build-and-review` directly to `adversarial-builder` (amend or `--fixup` + autosquash) — adversarial-build does not re-enter its loop for that.
