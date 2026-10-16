---
name: analyze
description: Pre-review analysis of local branch changes or a GitHub PR. Read-only, report-only.
---

# Code Review

Coordinates an independent, isolated review of a diff and reports findings plus a verdict. This file is the orchestration layer; the reviewing doctrine lives in `references/reviewer.md` (shared brief) and `references/lenses/*.md` (one brief per lens).

## When to use / not

- Reviewing a working branch's changes before opening a PR.
- Reviewing an already-open PR before merge.
- NOT for posting comments back to GitHub/GitLab, applying fixes, or process/workflow advice (review-speed SLOs, reviewer-roulette, approval workflows). This skill only reports.

## Inputs

- No argument → review the local branch's changes.
- A PR URL or number → review that PR instead.

## Workflow

### 1. Resolve target + gates

**Not a git repo:** if `git rev-parse --is-inside-work-tree` fails, abort loudly — say plainly this isn't a git repository and there's nothing to review.

**Local (no arg):**

```bash
git rev-parse --is-inside-work-tree
git rev-parse --abbrev-ref origin/HEAD 2>/dev/null || echo main
git merge-base <default-branch> HEAD
git status --short                 # staged + unstaged + untracked
git add -N .                       # intent-to-add: pulls untracked files' content into the diff below, stages nothing for real
git diff <merge-base>               # committed branch commits + staged + unstaged, through the working tree
```

The diff to review is committed branch commits **through the working tree** — merge-base..HEAD, plus whatever's staged and unstaged on top. Treat all of it as one change: a reviewer cares about what would ship if you committed and opened the PR right now, not about what happens to already be committed. `git diff <merge-base>` alone never shows the content of untracked (`??`) files — a brand-new file that was never `git add`ed would otherwise ship unreviewed. `git add -N` (intent-to-add) fixes this: it registers each untracked path so its content appears in the diff, without actually staging or committing anything. If `origin/HEAD` isn't set, fall back to `main` or `master` (whichever exists).

Also collect the commit messages between merge-base and HEAD — this is the change description for local review (see step 2).

**PR arg (URL or number):**

```bash
gh pr view <pr> --json title,body,baseRefName,headRefName
gh pr diff <pr>
```

Parse owner/repo from the URL if given; otherwise resolve via `gh repo view`. The PR title + body is the change description.

**Empty diff:** if there's nothing to review (no commits ahead and no working-tree changes, or an empty PR diff) — abort loudly, say so, don't fabricate a review.

### 2. Navigate order (Google)

The reviewer itself owns the read order (description first, then the main part of the change, then the rest — see `references/reviewer.md`). The coordinator's job here is just to make sure the reviewer *can* follow that order: always pass the change description (commit messages or PR title/body) **alongside** the diff, never the diff alone.

### 3. Trivial fast path (GitLab)

If the change is unambiguously trivial — a typo/copy fix, a tiny no-behavior-change refactor, removing dead code, or a well-understood logic change under ~5 lines — dispatch one pass with `references/lenses/correctness.md` and no other lenses, through the same isolated mechanism as step 4. Otherwise proceed to step 4. Either way, the reviewer always runs in its own isolated dispatch — the trivial path is a lighter pass, never an excuse to review inline.

### 4. Dispatch the lenses

Doctrine lives in `references/reviewer.md` (shared) and one file per lens in `references/lenses/`, resolved relative to this skill's own directory. The **Lens dispatch prompt** = full contents of `references/reviewer.md` + one lens file's contents + the change description + the diff + `configPath` when announced.

**Portability rule: read those files' content yourself and inject it into the prompt — never tell the subagent to open a path.** This skill may be installed anywhere, and the dispatched process's cwd is the user's project, not this repo, so a relative path won't resolve for it. Forward `configPath` to every dispatched subagent; each resolves the pack itself via `bash scripts/resolve-pack-value.sh <configPath> analyze`.

Dispatch these lenses **in parallel**, each in its own isolated `code-reviewer` dispatch, with its own Lens dispatch prompt:

- `acceptance`, `architecture`, `correctness`, `minimality`, `readability` — always.
- `security` — only when the diff touches credentials/tokens/secrets, authn/authz, trust-boundary input handling, or new/changed dependencies (lockfiles). Decide by diff content only. Otherwise report it as `skipped`.

Per harness:

- **Claude Code (has subagents):** dispatch the Agent tool with `subagent_type: "code-reviewer"` once per lens, with that lens's Lens dispatch prompt.
- **Codex CLI (has subagents):** invoke the Codex agent role `code-reviewer` (from sherpa's own `.codex/agents/code-reviewer.toml`; install per `.codex/agents/README.md`) once per lens with the same prompt. The role is read-only via `sandbox_mode`; spawn a fresh role each pass, never resume one.
- **pi (has pi-subagents):** dispatch the registered `code-reviewer` role through pi-subagents (the `subagent` tool or `/run code-reviewer`, registered from `.pi/agents/code-reviewer.md`; see `.pi/agents/README.md` and `protocols/harness/pi.md`) once per lens with the same prompt — never fall back to a generic unregistered process for this agent.
- **Never review inline in the coordinator's own context.** A reviewer that shares the builder's context isn't independent — that independence is the entire point of this skill.

### 5. Merge + report

Collect every lens pass and emit one merged report. This file owns its shape:

1. **Findings** — `file:line`, verbatim quote, the why, exactly one severity label, and the lens tag(s).
   - Dedupe: the same `file:line`, or the same root cause, raised by several lenses becomes one finding tagged with every contributing lens.
   - Rank `Blocking` first.
   - Show at most 5 findings per lens — every `Blocking` is always shown — and state how many lower-severity ones were left out.
   - A finding tagged with several lenses counts once for each of them, in both the display cap and the tally.
   - A one-line pointer from a lens to the owning lens (for an out-of-scope `Blocking` issue) is not a finding and counts toward neither the tally nor the verdict. If the owning lens raised the same issue, fold the pointer into that finding (add the pointing lens as a tag); if it did not, list the pointer under Questions for the author.
2. **Tally line**, exactly: `Lenses: acceptance N · architecture N · correctness N · minimality N · readability N · security N|skipped`
   N = the number of findings attributed to that lens after dedupe and before the display cap.
3. **Praise** — what's done well and why.
4. **Questions for the author** — merged and deduped across lenses.
5. **Verdict**, computed by you across all lenses:
   - `REQUEST CHANGES` if **any** lens produced a `Blocking` finding.
   - else `APPROVE WITH NITS` if only `Nit:`/`Optional:`/`FYI:` findings remain.
   - else `APPROVE`.

## Out of scope

Posting comments to GitHub/GitLab, applying fixes, review-speed/SLO rules, reviewer-roulette or approval-workflow policy. This skill is report-only and read-only, end to end.
