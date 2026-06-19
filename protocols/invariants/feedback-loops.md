# Feedback Loops

The build-quality invariant every builder tier follows. Governs how a builder gets signal on its own work; the EVIDENCE PACK in `protocols/invariants/output-contract.md` records the run.

## Principle

See how your code actually behaves before handoff. For every subtask, run the tightest feedback loop the change admits and let the result steer the next edit. Record the actual run (command + result) in the EVIDENCE PACK — never the run you *expect*.

## The loop ladder (strongest first)

- **Automated tests, red→green→refactor.** Prefer when the change is unit-testable and a harness exists. Write the *failing* test first, then the minimal code to pass it, then refactor on green. Work in vertical slices. Test observable behavior through the public interface, not internals.
- **Static types / compiler.** Always run for typed code — `compileJava`, `tsc --noEmit`, etc.
- **Runtime / observation.** For UI, rendering, or behavior you can't unit-test cheaply: exercise the real path and record what you observed.

## When to skip test-first

Skip when tests would be high-friction or low-value: no existing harness, throwaway or exploratory edits, pure config/theming with no logic. Never manufacture brittle tests to satisfy a preference. **"Hard to test" is not "skip all feedback"** — fall back to the next rung (compile, runtime). When you skip the strongest loop, one DECISIONS note naming the loop used instead is enough.

## Auto-generated code

For tasks whose output a generator owns end-to-end (a deterministic code generator), the generator run *is* the feedback loop. Record command + exit code in the EVIDENCE PACK. Do **not** author tests for generated output — that is hand-authoring and forbidden for generator-owned tasks.
