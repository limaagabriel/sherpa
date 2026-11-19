# Sherpa

Sherpa is a [Claude Code](https://docs.claude.com/en/docs/claude-code/overview) plugin made of skills.
You call them one at a time.

The three main skills work in order:

- `/frame` understands the problem and states it clearly.
- `/shape` writes a step-by-step plan and gets it reviewed.
- `/implement` builds the plan, one reviewed step at a time.

Other skills: `/persist`, `/analyze`, `/triage`, `/restory`, and `/invoke`.

Sherpa also bundles helper agents: codebase-explorer, step-builder, code-reviewer, analysis-reviewer, engineering-reviewer, and the reviewers.

Sherpa offers the tools. You decide the workflow. It is opt-in: nothing runs until you call a skill.
It keeps nothing on disk unless you call `/persist`. The one exception is the optional inventory,
a ticket board that only the `sherpa` inventory commands write to (see
[Inventory](#inventory-optional)). Your project's rules go in an optional YAML file called a
"pack", so the core stays general and knows nothing about your repo.

## Install

Requires `jq` and `yq` (v4+) on `PATH`. `jq` serves the SessionStart pack resolver (without it the
hook stays silent) and the read-only Bash guard (without it, sherpa's read-only agents cannot run
Bash); without `yq` the resolver still loads but skips project packs.

Sherpa is a Claude Code plugin. From inside Claude Code:

```
/plugin marketplace add limaagabriel/sherpa
/plugin install sherpa@sherpa
```

Or point at a local clone:

```
git clone https://github.com/limaagabriel/sherpa.git
/plugin marketplace add /path/to/sherpa
/plugin install sherpa@sherpa
```

Then open `/hooks`, review and **trust** sherpa's two hooks: `SessionStart` (it detects your
project pack) and `PreToolUse` (it blocks state-changing Bash in the read-only agents), and start a
new thread. Verify with `/frame` — if the skill shows up, you're set.

## Usage

| Skill | Does | Start here when |
|---|---|---|
| `/frame <task>` | Scout, bind a problem statement, ask questions as they arise, compose + present a frame, get a cold-eyes critique. | the task is fuzzy or has design calls |
| `/shape <task>` | Drafts the plan directly — step budget stated up front — then gets it critiqued three ways (structure, readiness, engineering) in parallel, and waits for your one approval. | the problem's framed (or clear enough) |
| `/implement <task>` | Build each step (step-builder + quality reviewer), with pressure per step. | it's one obvious change |
| `/persist` | Write the in-context frame or plan to disk so a later session can resume. | you want to save or resume |
| `/analyze` | Pre-review analysis of a branch's changes or a GitHub PR; opens with a short context briefing, then lens findings checked by `analysis-reviewer`, plus a verdict. | you want a pre-PR or pre-merge second opinion |
| `/triage` | Categorize all PR review feedback (makes sense / questionable / push back / needs clarification), flag lessons for AGENTS.md. | you got PR feedback and want to sort it before acting |
| `/restory` | Rewrite the current branch's messy commits into a clean, logical sequence; same end tree, fewer/better commits. | your branch history needs tidying before a PR |
| `/invoke <name\|path> [args]` | Run a pack skill (`skills/<name>/SKILL.md`) or any markdown file as a skill; no args lists the pack skills. | a project pack ships a skill you want to run |

Each skill is a standalone entry point: it uses the upstream artifact if it's in context, else
does the minimum to proceed — never re-running the layer above.

```
/frame add rate limiting to the public API   # fuzzy → frame it first
   → scouts, asks a few questions, presents a frame
/shape                                       # draft the plan directly
   → critiques it three ways, then presents the plan, waits for your approval
/implement                                   # build them, reviewed per step
```

…or just `/implement bump the copyright year` for a one-liner.

## How it works

`/frame` scouts, binds a problem statement, and asks questions as they arise; `frame-reviewer`
attacks the framing. `/shape` drafts the plan directly, then gets it attacked in parallel by
`structure-reviewer` (how the steps relate), `readiness-reviewer` (each step's own contract), and
`engineering-reviewer` (plan-level engineering quality) — a gap only you can close waits on you
(human gate 1) — before presenting the plan and waiting for **your explicit approval (human
gate 2)**, the one gate every run hits. `/implement` then builds one step at a time:
`step-builder` commits, then `quality-reviewer` checks it against both quality and its acceptance
criteria. A `BLOCK` or a terminal `UNMET`/`FIX` surfaces to you verbatim; everything else continues
automatically.

## Reading a frame and a plan

A printed frame or plan still uses a few sherpa terms. Here is what each one means.

**Summary and Details.** A frame and a plan both open with a plain **Summary** of about 12 lines.
The full record follows under **Details**. The Summary only restates the Details in simple words.

**The problem statement** (in a frame). One sentence with five parts:

| Part | Plain meaning |
|---|---|
| who | A named party, never just "the user". |
| can't do what | The goal they cannot reach. |
| why (the obstacle) | The cause that exists now. |
| what it costs | What breaks if nobody fixes it. |
| how we'll know (the done signal) | What an observer sees change when it is solved. |

**Open questions and design questions.** Open questions are about the problem or its scope. You
answer them in `/frame`. Design questions are choices about the solution. `/frame` leaves them for
`/shape`, which picks an answer and records why in Block 3.

**The goal statement** (in a plan). `<Outcome> for <consumers> because <motivation>; done when
<verification>`. The outcome is the end state you can observe. The motivation says why it matters.
The verification is a check you can run again.

**The three plan blocks.**
- **Block 1:** the goal statement, a before/after table, the step budget, and the limits (the
  no-gos and the rabbit holes).
- **Block 2:** the steps, one block each.
- **Block 3:** why this approach (precedent, design-question answers) and how the result is verified.

**The fields of a step.**
- **Goal:** what this step achieves. It traces back to the plan goal.
- **Change:** the concrete edit this step makes, and nothing more.
- **Interfaces:** what the step relies on and what it leaves for later steps.
  - `consumes` is what the step needs that already exists, or that an earlier step produces.
  - `produces` is what later steps rely on.
  - Each entry is an anchor like `path::literal`. The `literal` is text that must appear exactly
    in that file, so it can be checked with `git grep -F`. A path with no `::literal`
    points at the whole file. `none — <reason>` means no file backs the entry.
- **Acceptance criteria:** `done = <X>, confirmed by <check>`. The check can be run again.
- **Risk:** the one real risk that could sink this step, or `none` with a reason.

**Reviewer verdicts.** After the draft, reviewers check it. `OK` means the draft goes on.
`GAPS` means a reviewer found a gap. The driver fixes what it can and waits for you on the rest.

**The two approval points** (called "human gates" in `/shape`). In `/shape`, only these wait for you:
1. A gap only you can close. The driver shows the finding and waits.
2. Plan approval. Say "approved", "go" or "lgtm". A question or a critique is not approval.

## Inventory (optional)

The inventory is a ticket board for one project, any git repository. Each ticket is a markdown
file, and its folder shows its stage. `sherpa loop <project>` runs each queued ticket's next stage
headless (no one is there to answer prompts) in a fresh session. It runs inside the ticket's own
git worktree, a second checkout of your repo. Each run stops at the next human gate and hands the
ticket back to you. You drive it by moving files and deleting one line.

### Install the CLI

The `sherpa` command is separate from the plugin. It needs `bash`, `git`, and `yq` (v4+).

```sh
npm i -g github:limaagabriel/sherpa    # or, inside a clone: npm link
```

Keep the CLI on the same version as the plugin. Both must agree on the unattended protocol number
(`protocol=1` in `protocols/unattended.md`). If they differ, the ticket fails with
`plugin and CLI versions differ`, and the reason goes to `## Last run`.

### Set up a project

A project is one board for one git repository. It needs no pack. Inside the repo:

```sh
sherpa init                                 # board named after the repo folder
sherpa init <project> --repository <path>   # or pick the name and the repo yourself
```

The board's ID (`<project>`) is just a name you pick: letters, digits, `.`, `_` and `-`. It defaults
to the folder name of the repository's main worktree; if that is not a valid name, `init` asks you to
pass one. If the worktree has a sherpa pack (see [Project packs](#project-packs-optional)), the
headless skills pick it up like any session (the SessionStart hook); otherwise they run with no pack.

`init` creates `~/.config/sherpa/inventory/<project>/` and prints its path. `SHERPA_CONFIG_DIR` or
`XDG_CONFIG_HOME` change the base. The folder holds:

```
~/.config/sherpa/inventory/<project>/
  settings.yaml        # your settings; written once, never overwritten
  board.md             # the generated board; never edit by hand
  .lock/               # pid and ticket ID while a pass runs
  backlog/  frame/  shape/  implement/  analyze/  done/
    <ID>.md            # one ticket per file
```

The ID is the file name without `.md`. It starts with a letter or digit, then may use letters,
digits, `.`, `_` and `-`, for example `LPD-12345.md`. An ID lives in one folder only.

### settings.yaml

Here is a Liferay-style example of the `worktree` keys:

```yaml
repository: /home/you/liferay-portal
worktree:
  path: ~/lp-worktrees/$TICKET_ID
  create: lp worktree add "$TICKET_ID"
```

- `repository:` is the main checkout of your repo. `init` fills it in. Like `path:`, it expands a
  leading `~` and any `$NAME` or `${NAME}` from the environment (see `path:`).
- `worktree:` holds two keys:
  - `path:` (required) is where each ticket's worktree goes. A leading `~` and any `$NAME` or
    `${NAME}` from the loop's environment are expanded (`$TICKET_ID` is the ticket ID). Nothing is
    run, and an unset variable stops the ticket with an error. The result must be an absolute path.
    `init` writes `<project>-worktrees/$TICKET_ID` next to the repo. A folder that already
    exists at the path must be a separate worktree root of `repository` (not the main checkout, not
    a subfolder); otherwise the ticket fails with
    `<path> is not a git worktree of <repository>`. The same check runs after `create:`.
  - `create:` (optional) is the command that makes the worktree. It runs in `repository`, with
    `TICKET_ID` and `TICKET_WORKTREE` (the expanded `path`) set. It must create the folder that
    `path` names. The default is `git worktree add -b "$TICKET_ID" "$TICKET_WORKTREE"`.
- `runner:` (required) is the command that runs one stage. It runs in the ticket's worktree with
  `TICKET_STAGE` (`frame`, `shape`, `implement` or `analyze`) and `TICKET_FILE` (the ticket
  file's absolute path) set.

`runner` and `worktree.create` run arbitrary shell from this file. Keep it yours.

`init` writes this runner:

```yaml
runner: |-
  claude -p "/sherpa:$TICKET_STAGE --unattended \"$TICKET_FILE\"" --permission-mode acceptEdits --add-dir "$(dirname "$TICKET_FILE")" --allowedTools "Read,Grep,Glob,Edit,Write,Bash(git status:*),Bash(git diff:*),Bash(git log:*),Bash(git show:*),Bash(git add:*),Bash(git commit:*)"
```

- `--unattended` makes the skill follow `protocols/unattended.md`: no questions, and it stops at
  each gate.
- `--permission-mode acceptEdits` lets the agent edit files without asking.
- `--add-dir` gives the agent the ticket's stage folder.
- `--allowedTools` lists the tools that run without asking. A headless run cannot answer a prompt,
  so a command you do not list may fail.

Rules for `--allowedTools`:

- Add your build and test commands, for example `Bash(npm test:*)`.
- Never allow `git push`.
- Never use a full permission bypass.

Keep the prompt first in the runner. `--add-dir` and `--allowedTools` take every argument after
them.

Only the `claude -p` runner is tested. For Codex CLI or pi, a runner works if it reads
`TICKET_STAGE` and `TICKET_FILE`, follows `protocols/unattended.md`, and prints the `STATUS:` line.
That path is untested.

### Write a ticket

Create the ticket in `frame/`, or in `backlog/` to park it. It is plain markdown, with the title as
the first `# ` line:

```markdown
# Fix the widget cache

What I want, in my words.

## Answers
```

The loop adds two lines of front matter (the block between the `---` lines) above the title:

```markdown
---
parked: frame
actionNeeded: answers
---
# Fix the widget cache
```

- `parked:` is the folder where the run stopped. The loop writes it.
- `actionNeeded:` is what the loop needs from you. Remove the line to say "ready again".

The loop writes each stage's output into its own section, between markers:

```markdown
## Frame
<!-- sherpa:frame -->
...the agent's output, ending with "## Waiting on you"...
<!-- /sherpa:frame -->
```

| Stage | Marker | Heading |
|---|---|---|
| frame | `frame` | `## Frame` |
| shape | `plan` | `## Plan` |
| implement | `implementation` | `## Implementation` |
| analyze | `analysis` | `## Analysis` |
| failed run | `last-run` | `## Last run` |

The loop edits only its front matter and these marker sections. Do not edit the `<!-- sherpa:… -->`
markers, and do not write inside them: the next run of that stage replaces the text there. Your
replies go under `## Answers`, which the loop never edits.

### Your actions

The loop sets `actionNeeded:` to one of five values:

| Value | Written when | What you do |
|---|---|---|
| `answers` | the output has open `Q<n>:` questions | answer under `## Answers`, remove the line |
| `approval` | frame or shape finished, nothing open | move the file to the next folder |
| `review` | implement finished | review the code; move to `analyze/`, or answer and move back to `shape/` |
| `decision` | analyze said APPROVE WITH NITS or REQUEST CHANGES | move to `done/`, or answer and move back to `shape/` |
| `fix` | the run failed (see `## Last run`) | fix the cause, remove the line to retry; after a failed implement, move back to `shape/` instead, so the plan covers only what is missing |

Then drive the ticket with these actions:

| You want to… | You do |
|---|---|
| start a ticket | create it in `frame/`, or move it from `backlog/` |
| send answers ("ready again") | write under `## Answers`, remove the `actionNeeded:` line |
| approve and advance | move the file to the next folder |
| send code-review feedback after implement | write under `## Answers`, move the file back to `shape/` |
| finish | move the file to `done/` |

The loop moves a file only when analyze says APPROVE, and then only to `done/`. Every other move is
yours.

The board and the loop read a ticket's state the same way. A ticket **waits on you** when it has
`actionNeeded:` and its `parked:` names its own folder. It is **running** while its pass runs.
Anything else is **queued**, and the next pass runs it. So moving a file out of a parked folder
queues it, and the old `actionNeeded:` line stops counting.

A re-run continues a ticket; it never starts over. If the ticket already has its stage's section,
the agent keeps that output, applies every answer, and asks only about questions still open. Question
IDs stay the same.

### Run it

```sh
sherpa loop <project>            # one pass, wait 300 s, repeat
sherpa loop <project> --every 60 # wait 60 s between passes instead
sherpa loop <project> --once     # one pass, then exit
sherpa board <project>           # refresh board.md and print it
```

- Ctrl-C stops the loop and the agent it started. A TERM signal does the same.
- Run one loop per project. If a pass finds the lock held by another pass, the loop stops with
  `another loop holds <project>` (exit 3).
- A pass with a failed ticket does not stop the loop; it keeps going. Exit 2 (no runner, unknown
  project, bad usage) does stop it.
- The board groups tickets into **Waiting on you**, **Agent running**, **Queued for agent**,
  **Backlog**, **Done**, and **Needs fixing**. The last holds broken tickets: a bad ID, one ID in
  two folders, broken front matter, or an unknown `actionNeeded:` value.
- A failed run writes `## Last run` (the reason, the exit code, the last 20 lines of stderr, and
  stdout) and sets `actionNeeded: fix`.
- If the output cannot be written (broken markers, bad YAML), it is saved as
  `<ID>.lost-output.txt` in the ticket's folder, and the ticket gets `actionNeeded: fix`.

### Trust

- `runner` and `worktree.create` run shell from `settings.yaml`, and the unattended agent reads
  your repo. Use only repos you trust.
- The unattended agent can edit any file in its worktree, including hook scripts that `git commit`
  runs. Review the code at the `review` gate.
- `## Last run` and `.lost-output.txt` files can hold secrets from stderr or stdout. Do not share a
  ticket as it is.
- Agent output is model text. Read it before you approve.

## Project packs (optional)

The engine ships generic. To layer in your project's conventions, commit
`<repo>/.sherpa/project.yaml` (project-local) or drop one directory per project under a shared
workspace dir. `project.yaml` carries metadata only (`name`, `detect`); every content-bearing
value — `session.md` (injected at session start), `context.md` (forwarded to every subagent, at
the root and per layer) — is a fixed convention path next to it, resolved by one call:
`bash scripts/pack/load-layer.sh <configPath> [frame|shape|implement|analyze]`. Sherpa's single
`SessionStart` hook scans for a matching config and announces the active pack automatically. Full
schema and resolution rules: `packs/README.md`.

## Components

- **`/frame`** (frame) — scout + bind a problem statement; `frame-reviewer` gives it cold eyes.
- **`/shape`** (shape) — drafts the plan directly; `structure-reviewer`, `readiness-reviewer`,
  and `engineering-reviewer` critique it in parallel.
- **`/implement`** (build) — runs approved steps; `step-builder` builds and commits each one,
  `quality-reviewer` checks it.
- **`codebase-explorer`** / **`/persist`** — cross-cutting: codebase discovery (dispatched directly by
  `/frame` and `/shape`, not a standalone skill), and opt-in disk persistence.
- **`/analyze`** — Pre-review analysis of a branch's changes or a GitHub PR;
  `code-reviewer` does the independent, isolated look, `analysis-reviewer` checks each finding; the report opens with a short context briefing and ends with a verdict.
- **`/triage`** — categorizes all PR review feedback and flags lessons for AGENTS.md;
  strictly analytical, never edits code or replies on the PR.
- **`/restory`** — rewrites the current branch's commits into a clean, reviewable sequence; pure
  git, never pushes.
- **`/invoke`** — runs a pack skill or any markdown file as a skill; runs with your permissions,
  unsandboxed.
- **`sherpa`** (`bin/sherpa`) — the CLI for the inventory: `init`, `loop`, and `board`. Each loop
  run follows `protocols/unattended.md`.

## Layout

```
skills/        /frame, /shape, /implement, /persist, /analyze, /triage, /restory, /invoke, using-sherpa
agents/        codebase-explorer, frame-reviewer, structure-reviewer, readiness-reviewer, engineering-reviewer, step-builder, quality-reviewer, code-reviewer, analysis-reviewer
protocols/harness/  Codex CLI and pi harness equivalence tables
protocols/unattended.md  rules for the headless runs the inventory loop starts (protocol=1)
packs/         project-pack template + docs
hooks/         the SessionStart pack resolver and the read-only Bash guard (scripts/hooks/guard-bash.sh)
bin/           the sherpa CLI: init, loop, board
scripts/       helper scripts by group: pack, agents, ci (see scripts/README.md)
scripts/inventory/  the inventory: ensure-board, ensure-worktree, run, build-board, ticket helpers
```

## License

MIT
