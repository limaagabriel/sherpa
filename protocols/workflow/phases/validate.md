# Validate

Execute the test plan from Plan bullet (3).

## Steps
- Verify the worktree environment works before running tests.
- Run the test plan; record results.
- **Code-style audit (project-pack capability).** Only when the active project pack announced a `codeStyleAudit` command (see `packs/README.md`). Run it over the committed range and triage the returned reports per the pack's documented contract: validate coverage, dedup overlapping findings, fold each mechanical FIX into its owning commit via fixup/autosquash (cap 3 rounds), surface BLOCKs verbatim, and record the outcome in `PROGRESS.md`. Handle verdicts per `protocols/adversarial/verdict-handling.md` § Code-style audit. **No pack / no `codeStyleAudit` announced → skip this step** (the engine ships no style rules of its own). This is the exhaustive enumeration the inner-loop reviewers (which judgment-pick) do not do.
- Dispatch `plan-reviewer` with `mode=output` via the `Agent` tool. Forward the **plan goal** (contract), the committed range (base SHA), and the handoff paths. It attacks whether the finished plan *achieved its goal*: Outcome after-state actually holds, motivation (`Because`) satisfied — not just the letter of it — and no goal drift. This is the north-star check no other gate owns; every step can be accepted and the diff clean while the plan goal stays unmet (e.g. "kill the duplication" with the duplication still in the tree). It does NOT re-run `task-reviewer` (acceptance) or `turn-reviewer` (code quality). Handle the verdict per `protocols/adversarial/verdict-handling.md`.
