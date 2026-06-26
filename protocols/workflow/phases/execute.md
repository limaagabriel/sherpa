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
