# Build-Id (commit note)

Per-run scope key. One commit per subtask; the key rides a git **note** on `refs/notes/build-id`, off the commit message. Coordination metadata — **not an audited invariant**. The only presence check is the Deliver-time scope check below.

## Storage

Lives in a git note, never the commit message. `scripts/build-notes.sh` is the only read/write surface — consumers never parse `git notes` inline.

A note holds a deduped, sorted **key-SET**: a squash merges folded commits' keys via `notes.rewriteMode=cat_sort_uniq`. Every reader treats a note as a set.

## Config (run once, at Prep)

```sh
scripts/build-notes.sh init
```

Sets repo-local `notes.rewriteRef=refs/notes/build-id`, `notes.rewriteMode=cat_sort_uniq`, `notes.rewrite.amend=true`, `notes.rewrite.rebase=true`. Native git then carries the note across amend/rebase with no hook — including between-turn rebases. Must be repo-local (`.git/config`), or cross-turn rewrites lose the note.

## Format

```
<BUILD ID>.<n>
```

- `<BUILD ID>` — per-run identifier generated at Prep (`scripts/build-id.sh`).
- `<n>` — subtask index (1-based; `1` when not decomposed).

## Create-vs-amend (builder's decision)

```sh
scripts/build-notes.sh head-key
```

- HEAD's key-set already contains `<BUILD ID>.<n>` → **amend**: `git commit --amend --no-edit`. The note is carried to the new SHA by native config.
- Otherwise → **create**: `git commit -m "<subject>"`, then `scripts/build-notes.sh stamp <BUILD ID>.<n>`.

Exactly one commit per subtask; fix-round churn folds in via amend. `stamp` unions the key into the existing set.

## Folding a Review-stage fix into an earlier subtask

When a Verify/Review fix targets a subtask whose commit is no longer HEAD, fold it — never add a stray commit:

```sh
scripts/fold-fix.sh <BUILD ID>.<n> <PRE-BUILD BASE> [files...]
```

If `$target` is empty, the script aborts and reports — never `git commit --fixup=""`. Non-interactive; rewrites only this run's commits above `<PRE-BUILD BASE>`. Requires git ≥2.38 (script checks and aborts on older; never falls back to `git rebase -i`). On conflict, `git rebase --abort` and report — never force a resolution.

## What reads the key

All via `scripts/build-notes.sh` — never inline `git notes` parse.

- Builder — create-vs-amend self-detection (`head-key`).
- `adversarial-breaker` `mode=output` — scopes attack to commits with this run's key (`range`).
- `task-reviewer` — attributes each UNMET criterion to the owning `<BUILD ID>.<n>` (`range`).
- `/build-and-review` Deliver and `/adversarial-build` Deliver — scope check every commit carries this run's key (`range`).
- `scripts/fold-fix.sh` — resolves the autosquash target (`owner`).

## Hard limits

- Never touch `<PRE-BUILD BASE>` or any commit below it.
- Never touch a commit lacking this run's `Build-Id` key.
