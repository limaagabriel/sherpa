# State persistence (clock-out)

Run-state files let resume pick up after compaction or reset. Main agent owns SPEC / DECISIONS / PROGRESS; `/build-and-review` and tier workers own `discovery/`, `briefings/`, `handoffs/`.

## Run-state directory
`<BASE>/<key>/`, where the base resolves in precedence order:
1. **`projectStatePath`** from the active pack's `WORKFLOW_PACK:` announcement, when present — per-project, auto-selected on detection, no shell setup.
2. else the shell default:
```sh
BASE="${WORKFLOW_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/claude-workflow}"
```
A pack `projectStatePath` (see `packs/README.md` § State directory) wins so each project keeps its own state dir; absent it, `WORKFLOW_STATE_DIR` redirects all run-state anywhere you like, and unset = the XDG default (transient resumable run-state, not persistent user data — hence `XDG_STATE_HOME`, not `XDG_DATA_HOME`). Create `<BASE>/<key>/` with `mkdir -p` BEFORE the first Scout subagent in Discover.

`<key>` = `git branch --show-current` when non-empty; else a slug of the **raw user-supplied task string** (the original request text, before scouting — NOT the brief's `Goal`, which doesn't exist yet).

## Slug algorithm
```sh
scripts/run-state-key.sh "<raw task string>"
```
Lowercases, collapses non-alnum runs to single hyphens, trims edge hyphens, truncates to 40 chars.

## Write rules
- **Discover end** → write `SPEC.md` with the brief's fields verbatim (`Supersedes` when a follow-up — see Archiving; plus Scout / Goal / Constraints / Non-goals / Assumptions / Decisions), not an expanded rewrite. If a prior `SPEC.md` exists in the same `<key>` dir, do **not** delete it — archive the completed plan (see below); the prior triplet moves into `archive/`, never deleted.
- **Plan approval → SPEC.md:** append the proposal's *Plan at a glance* + before/after table + steps below the brief fields. Once, on approval — not per step (that's `PROGRESS.md`).
- **Plan approval → DECISIONS.md** (append-only; create if absent, never overwrite): one `## <YYYY-MM-DD> — <short approach title>` section per entry, blank-line separated. Body: chosen approach + next-best + why it lost; for bugs, the Analyze root-cause too.
- **Every step transition in Execute → full rewrite of `PROGRESS.md`** (single current-state snapshot): full step list with per-step status; in-flight index = 1-based ordinal of the `in_progress` step (`none` when none); next steps; any block reason. **Always a full rewrite, never appended.** The `/execute` skill drives this rewrite on each transition (the engine bundles no enforcement hook).
- **Validate** → one more full rewrite of `PROGRESS.md` adding a test-results section (same rule; not a separate append).
- **`/build-and-review` run-state** (`discovery/`, `briefings/`, `handoffs/`) → keyed by `BUILD ID` + subtask index; transport + documentation only, not read back on resume.

## Archiving a completed plan
A branch holds one **active** plan (the triplet at the `<key>` dir root). A new Discover baseline on a branch that already ran one is a **follow-up**: archive the prior plan rather than clobber it, so its decisions survive one read away.

- **Completed gate (your judgment, not the script).** The prior plan is complete only when `PROGRESS.md` is present AND every step is `completed` AND in-flight index is `none` AND no block reason. Anything less — including a missing `PROGRESS.md` (it stopped before/during Execute) — is **not complete**. For a not-complete prior plan → **STOP**: don't overwrite `SPEC.md`, don't archive. Read its `SPEC.md`/`DECISIONS.md`, say where it stopped (Discover, Plan, or mid-Execute), and let the user finish it (`/workflow-resume`) or explicitly discard it before a new baseline.
- **Archive (the script).** When complete, slug the prior plan's `Goal`, then:
  ```sh
  scripts/run-state-archive.sh "<key-dir>" "<prior-goal-slug>"
  ```
  Moves the triplet into `archive/<NNN>-<slug>/` (`NNN` = existing count + 1) and echoes the path. It only moves files — the gate above is yours.
- **Supersedes pointer (no carry-forward).** Write the fresh `SPEC.md` with `Supersedes: archive/<NNN>-<slug>` as line 1 (the echoed path). Prior decisions stay in `archive/<NNN>-<slug>/DECISIONS.md`, read on demand — **not** copied into the new `DECISIONS.md`. New `DECISIONS.md`/`PROGRESS.md` start absent, written at their own phases.
- **`archive/` is reference-only** (like `briefings/`): `workflow-resume` counts its subdirs but never reads or routes on their contents.

## Resume
Manual after compaction or reset. The persisted files are the handoff surface.

## Don't
- Use `XDG_DATA_HOME`/`~/.local/share` for run-state (wrong semantics).
- Append to `PROGRESS.md` — always full rewrite.
- Treat `<key>` as the brief's `Goal` — it's the raw task string.
- Delete or overwrite a prior plan's triplet on a new baseline — archive it (only when complete; an incomplete prior plan stops the baseline).
- Copy archived `DECISIONS.md` into the new active file — the `Supersedes:` pointer is the link.
