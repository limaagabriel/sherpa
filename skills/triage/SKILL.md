---
name: triage
description: Triage all GitHub PR review feedback — categorize each item (makes sense / questionable / push back / needs clarification), flag lessons for AGENTS.md. Needs PR URL/number; GitHub-only.
---

# PR Reason

Reasons over all review feedback on a GitHub PR (unresolved inline threads, conversation comments, review-summary bodies) and tells you which to act on, which to push back on, and which lessons are worth writing into AGENTS.md. Strictly analytical — never edits code or replies on the PR.

## When to use

- A reviewer left feedback and you want a second opinion before implementing it blindly.
- You want to separate "real improvement" from "reviewer is wrong / contradicts our patterns."
- You want to capture recurring review feedback as durable instructions in AGENTS.md.

Not for: writing the PR description or applying the changes (this skill only reasons).

## Inputs

- **Required:** PR URL or number.
- **Owner/repo:** parsed from the URL, else from `gh repo view` / the `origin` remote.

## Workflow

### 1. Resolve target + drift check

```bash
gh pr view <pr> --json number,headRefName,headRefOid,headRepository,author,commits
git rev-parse HEAD && git branch --show-current
```

Compare the PR's `headRefName`/`headRefOid` to the local branch and HEAD. Keep `author` (to skip the author's own root comments) and `commits` (for the "possibly addressed" hint).

- **Match** → local checkout reflects the PR; file-context reasoning is trustworthy.
- **Drift** (different branch, or HEAD behind/ahead) → **say so loudly** and ask whether to continue. Reasoning over line numbers against a drifted tree produces wrong conclusions. Don't silently proceed.

### 2. Fetch all review feedback

**(a) Unresolved inline threads** — GraphQL, paged; keep only threads where `isResolved == false`:

```bash
gh api graphql --paginate -f query='
query($owner:String!,$repo:String!,$pr:Int!,$endCursor:String){
  repository(owner:$owner,name:$repo){
    pullRequest(number:$pr){
      reviewThreads(first:100, after:$endCursor){
        pageInfo{ hasNextPage endCursor }
        nodes{
          isResolved isOutdated path line
          comments(first:100){ nodes{ author{login} body createdAt } }
        }
      }
    }
  }
}' -f owner=<owner> -f repo=<repo> -F pr=<pr>
```

`gh --paginate` needs the variable named `$endCursor` and a `pageInfo{hasNextPage endCursor}` on the paged connection. It pages only one connection per query, so a thread keeps at most 100 comments.

For each unresolved thread keep: latest reviewer comment, `path`, `line`, `isOutdated`.

**(b) Conversation comments:**

```bash
gh api --paginate repos/<owner>/<repo>/issues/<pr>/comments \
  --jq '.[] | {author: .user.login, type: .user.type, body, created_at, url: .html_url}'
```

**(c) Review-summary bodies:**

```bash
gh api --paginate repos/<owner>/<repo>/pulls/<pr>/reviews \
  --jq '.[] | {author: .user.login, type: .user.type, state, body, submitted_at, url: .html_url}'
```

Per-element `--jq` keeps multi-page output as JSON lines.

**Filter root items** (b, c) — skip:

- the PR author's own comments;
- bot status reports (CI, coverage, deploy, changelog) — keep bot posts that critique the code (AI review bots);
- empty review bodies, and bodies that only approve or only restate/point to their own inline comments.

### 3. Reason over each item

Label each item with a **kind**: `request` (a question counts as a request), `complaint`, or `suggestion`. "Needs clarification" stays a verdict, not a kind.

For threads, read the file around `line` (skip file-context reasoning if drift was detected — note it instead). Root items have no `path:line` — reason against the PR diff and any files they name. A complaint with no proposed change is judged on whether it is fair, using the same four verdicts.

Add a **possibly addressed** hint when fetched data shows a later reply by the PR author or a later commit message that answers the item. Hint only — never drop the item.

Judge on three axes:

1. **Makes sense in *this* codebase?** — Does the suggested API/util/symbol actually exist here? Does it fit the module's established patterns? (verify, don't assume)
2. **Good engineering practice generally?** — Sound regardless of this repo: correctness, safety, readability, performance.
3. **Worth an AGENTS.md instruction?** — Only if the lesson is *general and recurring*, not a one-off. A repeated "use guard clauses" → yes. A typo fix → no.

Reason inline. Each item is a small, independent file peek — subagent isolation buys nothing and scatters redundant reads. If a single comment needs codebase-wide verification (does this symbol/API exist anywhere), dispatch one focused agent for *that* check only.

### 4. Report

**Executive summary:** one line on overall feedback quality + drift status.

**Per item** — locator · kind · verdict · one-line rationale (cite the code/standard for any "push back"). Locator is `path:line` for threads, `@author · comment|review(<state>) · <date> · <url>` for root items. Threads first, then root items.

Verdicts:

| Category | Meaning |
|---|---|
| ✅ Makes sense | Valid and good practice — implement it. |
| 🤔 Questionable | Real tradeoff or partially right — decide case by case. |
| ⛔ Push back | Wrong, or contradicts codebase patterns / best practice — reply, don't apply. Must cite evidence. |
| ❓ Needs clarification | Ambiguous — ask the reviewer before acting. |

**AGENTS.md candidates:** bullet list of generalizable rules worth adding, each with the comment(s) that motivated it and the proposed one-line instruction. If the rule is already in AGENTS.md, say so and skip. Recommend, don't write — the human decides.

## Principles

- Even senior reviewers are wrong sometimes — evaluate objectively.
- Back every "push back" with a code reference or a stated standard. No naked disagreement.
- Verify suggested symbols/APIs exist before calling a comment valid.
- Read-only: no code edits, no PR replies, no AGENTS.md writes.
