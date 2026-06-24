# Sherpa

A [Claude Code](https://docs.claude.com/en/docs/claude-code/overview) plugin that
turns "do this task" into a guided **Discover → Analyze → Plan → Execute → Validate**
loop — with bundled scout, builder, and reviewer subagents that rope up, check the
rope at every pitch, and leave cairns so you can resume.

It's **opt-in** (nothing runs until you call `/plan`, `/execute`, or `/workflow`)
and **project-agnostic** — your project's code style, extra reviewers, and state
location plug in through a small YAML *pack*, so the engine never hard-codes
anything about your repo.

## Why

Asking an agent to "just build it" skips the parts that make work trustworthy:
scouting precedent, pinning down acceptance criteria, and adversarially checking
the result. Sherpa makes those steps first-class:

- **Plan before code.** Scout the codebase, bind a concrete goal, clarify open
  decisions, then wait for your explicit approval. No execution without an approved plan.
- **Adversarial by default.** A *breaker* attacks the spec before code exists and
  attacks the output after. A *reviewer* checks both "right thing?" and "built right?".
- **Resumable.** Each phase persists run-state (SPEC / DECISIONS / PROGRESS), so you
  can stop after `/plan` and pick up with `/execute` days later.

## Install

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

Then open `/hooks`, review and **trust** sherpa's `SessionStart` hook (it detects
your project pack), and start a new thread. Verify with `/plan` — if the skill
shows up, you're set.

## Usage

| Command | Does |
|---|---|
| `/plan <task>` | Discover → Analyze → Plan. Scouts, clarifies, proposes a plan, **waits for approval**. |
| `/execute [key]` | Execute → Validate against the approved plan. Builds each step, reviews, validates the goal. |
| `/workflow <task>` | The full loop — runs `/plan`, then `/execute` after you approve. |

Smaller building blocks you can call directly: `/scout`, `/build-and-review`,
`/adversarial-build`, `/codegen-build`, `/turn-review`, `/workflow-resume`.

Typical flow:

```
/workflow add rate limiting to the public API
   → sherpa scouts, asks a few clarifying questions, presents a plan
   → you approve
   → it builds each step, runs reviewers, validates against the goal
```

## How it works

```
Discover ─ scout codebase, gather precedent + constraints
Analyze  ─ bind a concrete goal contract, clarify open decisions
Plan     ─ propose steps  ──►  YOU APPROVE  ◄── (hard gate)
Execute  ─ per step: brief → vet spec → build → probe output → commit
Validate ─ task-reviewer (right thing?) + turn-reviewer (built right?)
```

Each step is tiered and routed to the cheapest builder that fits — a `codegen`
tier for deterministic generators (runs on Haiku), an `inline` tier for trivial
edits, and the full adversarial path for everything else. Reviews iterate up to a
cap, then hand unresolved findings back to you. Full map: `protocols/adversarial/README.md`.

## Project packs (optional)

The engine ships generic. To layer in your project's conventions, drop one YAML
file per project:

```
${WORKFLOW_PACKS_DIR:-~/.claude/sherpa/projects}/<project>.yaml
```

```yaml
name: my-project
detect: case "$CWD" in */my-project*) exit 0 ;; *) exit 1 ;; esac
sessionInstructions: |
  Invoke Skill my-project-init before other work; skip if already invoked.
pack:
  initialize: my-project-init          # skill that loads project knowledge
  reviewers: my-project-code-reviewer  # extra review subagents
  codeStyleRules: cat /abs/path/to/rules.md         # step-layer style rules
  architectureRules: cat /abs/path/to/architecture.md  # plan-layer architecture rules
  projectStatePath: /abs/path/to/.workflow-state
```

Sherpa's single `SessionStart` hook scans the dir, detects the active project, and
announces its pack — no per-project hook to write. If nothing matches, the engine
runs generic and every pack-dependent step no-ops. Details and the full schema:
`packs/README.md`.

### Where run-state lives

Resolved highest precedence first:

1. Pack `projectStatePath` (per-project).
2. `WORKFLOW_STATE_DIR` env var (per-shell).
3. Default: `${XDG_STATE_HOME:-~/.local/state}/claude-workflow`.

## Layout

```
skills/        /plan, /execute, /workflow + build-and-review, adversarial-build, scout, …
agents/        scout / builder / reviewer / breaker subagents
protocols/     the workflow + adversarial contracts (the engine's brain)
packs/         project-pack template + docs
hooks/         the single SessionStart pack resolver
```

## License

MIT
