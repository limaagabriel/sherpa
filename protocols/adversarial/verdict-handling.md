# Reviewer Verdict Handling

Single source of truth for how the main agent handles reviewer verdicts. Imported into the user's global CLAUDE.md and referenced by `commands/adversarial-build.md`. System map: `protocols/adversarial/README.md`.

## Verdict response (shared protocol)

Applies to every reviewer subagent. `<reviewer>` = the active reviewer name.

- **Coverage validation (on receipt):** confirm the report's `COVERAGE` log has a line for every catalog class the reviewer emits (see per-reviewer sections). A missing class → re-invoke once naming it. Still missing on round 2 → it's a prompt/agent bug, not flakiness: surface `<reviewer>: INCOMPLETE COVERAGE — <classes>` and proceed with the partial report flagged. Only run verdict handling once coverage is complete.
- **Response to verdict** (`PASS < WARN < FIX < BLOCK`; verdict = highest tier across findings):
  - `PASS` — proceed.
  - `WARN` — proceed, but surface each finding first, under a `**<reviewer>: WARN**` section. Advisory, so a faithful one-line summary suffices (no verbatim quote needed) — but keep the `file:line`/citation so the user can find it. Format: `- **[title]** — <summary, citation preserved>. *Suggested:* <action>`.
  - `FIX` — apply each finding's mechanical repair, re-invoke the same reviewer, repeat until verdict ≠ FIX. No user prompt during the loop. Cap 3; if still FIX after 3, treat the rest as BLOCK and surface them. After clearing, note `<reviewer>: FIX×N applied`. **A finding is FIX whenever one unambiguous mechanical repair clears it, regardless of severity** — even a release-blocker (unexecutable instruction, stale/contradicting doc line, missing tool declaration) is FIX, not BLOCK. Severity rides the FIX→BLOCK escalation above, not the initial tier.
  - `BLOCK` — for findings needing **human judgment**: a choice between alternatives ("user decides which"), a behavioral/scope/architecture call, or a reasoning finding with no mechanical repair. **Do not** emit a success summary or state the conclusion as fact. Open with a `**<reviewer>: BLOCK**` section; for each finding quote the evidence and suggested-action **verbatim** — no paraphrase, no truncation, keep citations. Format: `- **[title]** — <evidence verbatim>. *Suggested:* <action verbatim>`. Then state the required action and ask how to proceed (fix / override / abandon). Never auto-fix.
- **Mixed FIX + BLOCK → overall BLOCK.** Handle per BLOCK; don't auto-fix the FIX items first (the user may want to revert everything).

## Turn audit (turn-reviewer)

Audits the whole turn: **code diff**, **process** (skill use, Discover/Plan skips, narration, summary length, scope creep), and **reasoning** (root-cause claims, "what code does", citation soundness). A turn may carry any combination.

- **Catalog classes:** `BLOCK`, `FIX`, `WARN`. Reasoning checks live inside them (no separate class). Project style and precedent are NOT turn-reviewer's job — `task-reviewer` owns them on the committed range; for ad-hoc edits outside `/build-and-review`, run a manual style/precedent pass if your project provides one.
- **Primary trigger:** the `/execute` skill invokes `turn-reviewer` (via Agent) before claiming any step done, auditing `<base SHA>..HEAD` + working tree. Forward the audit scope SHA into the briefing so it audits that range, not an improvised baseline. (`/adversarial-build` forwards its own `PRE-BUILD BASE` separately.) A host environment MAY additionally wire a Stop-hook to fire this automatically, but the plugin ships no such hook.
- **Briefing requirement:** brief the subagent on what the turn produced — the diff plus an **EVIDENCE PACK** for any completion claim, and/or each conclusion with its **CITATIONS** (file:line, grep, transcript). Formats in `commands/turn-review.md`. A completion claim with no evidence, or a conclusion with no citation, is flagged by rule.
- **Manual triggers:** "audit", "adversary", "turn review", "diff review", "challenge this", "reasoning review", "challenge my reasoning", "/turn-review" — invoke regardless of diff size, ignoring the hook cache.
- **Disagree with the hook:** invoke even when it didn't fire if the turn warrants it (a one-line security fix, or before any Edit/Write that depends on an unverified diagnosis). The hook is a floor, not a ceiling.
- **BLOCK override for reasoning findings:** there's no diff to revert, so replace "fix / override / abandon" with "re-investigate, gather more evidence, or narrow the claim".

## Task audit (task-reviewer)

Judges a committed diff range against a goal + acceptance criteria, then audits style and patterns.

- **Catalog classes:** `ACCEPTANCE` (MET/UNMET/UNVERIFIABLE per criterion), `STYLE` (project style), `PRECEDENT`. `STYLE` is `N/A` when no project pack announced a `codeStyleRules` command. `PRECEDENT` reports 0 when no new pattern appears.
- **Coverage validation:** confirm an `ACCEPTANCE` section, a `STYLE (project pack)` line, and a `PRECEDENT` section. Missing → re-invoke once naming it.
- **Verdict mapping:** `ACCEPTANCE: UNMET` → BLOCK (builder must fix). `[STYLE]` → FIX (mechanical). `[PRECEDENT]` → BLOCK (human judgment, regardless of ACCEPTANCE). Mixed STYLE + PRECEDENT → BLOCK.
- **Trigger:** fired by `/build-and-review` once the committed range is stable. Not hook-driven.

## Plan audit (plan-breaker)

Attacks goals at the plan layer — `mode=briefing` (goal well-formedness, before any step is built) and `mode=output` (goal achievement, after the build). Owns the premise layer; does NOT re-run `task-reviewer` (acceptance) or `turn-reviewer` (code quality).

- **Output shape:** `MODE`, `VERDICT` (`SOLID | HOLES`), `ATTACKED`, `HOLES` — not a tiered COVERAGE log. Validation: `MODE` + `VERDICT` + non-empty `ATTACKED` present, and `HOLES` non-empty whenever `VERDICT: HOLES`. Malformed → re-invoke once.
- **Verdict mapping (`SOLID` → PASS):** classify each hole. Unbound Outcome, ceremony `For`, circular `Because`, orphan step, plan-goal↛brief gap → BLOCK (binding/cut is human judgment; bind via `AskUserQuestion`, then re-attack with a fresh Agent call). Unverifiable done-when → FIX (add the confirming command). Unsound why-lost, architecture-rule violation, unstated load-bearing assumption → BLOCK (each needs a human decision — re-decide the rejected alternative, accept-or-conform the architecture rule, confirm-or-bind the premise; an architecture-rule violation mirrors `PRECEDENT → BLOCK`). The split is the principle: a hole with one unambiguous mechanical repair is FIX (only unverifiable done-when qualifies today); every hole needing human judgment is BLOCK. `mode=output` holes (Outcome not true, motivation unsatisfied, goal drift) → BLOCK (the human decides more work vs. re-plan). BLOCK findings surfaced verbatim.
- **No `architectureRules` pack command** → the Architecture-rule violation lens is skipped (no finding emitted), exactly as `STYLE` goes `N/A` without `codeStyleRules`.
- **BLOCK override:** a `mode=output` BLOCK has no diff to revert — replace "fix / override / abandon" with "do the missing work, re-plan the goal, or accept the gap".
- **Trigger:** `mode=briefing` in Plan before approval; `mode=output` in Validate. Not hook-driven.

## Code-style audit (project-pack capability)

Exhaustive per-rule style enumeration is a **project-pack capability**, not an engine feature. When the active project pack announced a `codeStyleAudit` command, the Validate phase runs it over the committed range as the no-judgment-pick gate — distinct from `task-reviewer`'s lighter inner-loop candidate-pick style check. **If no pack announced `codeStyleAudit`, this gate simply does not run.**

- **What the pack's audit emits:** the pack owns its rule taxonomy and coverage shape. The engine treats the audit as a black box that returns tiered findings (`FIX` / `BLOCK`) over the in-scope diff. The pack's own docs define how it reports coverage and which file types it scopes to.
- **Verdict mapping (Validate dispatcher):** `[FIX]` → mechanical reformat to the rule's prescribed good-form (apply, fold into the owning commit via fixup/autosquash, re-run the pack's audit, cap 3). `[BLOCK]` → human judgment (ambiguous application, behavior-changing repair, or two valid repairs); surface verbatim. Mixed FIX + BLOCK → overall BLOCK; don't auto-fold the FIX items until the user weighs in.
- **Report-only invocations:** a pack may also expose its audit as a manual report-only command that surfaces FIX and BLOCK findings with their suggested repairs but never applies or folds them — the FIX-fold above is the Validate phase's job alone.
- **Dispatcher precision:** the engine-side dispatcher dedups overlapping `file:line` findings, drops noise and pre-existing-only hits, and reports what came back CLEAN so completeness is visible.
