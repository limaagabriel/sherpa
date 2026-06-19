# Project packs — extending the workflow engine

The engine is project-agnostic. A **project pack** layers project-specific
knowledge on top of it (code style, extra reviewers, profile/conventions)
without the engine knowing anything about your project.

A pack is a **YAML config file** plus an **init skill**. Sherpa ships one generic
`SessionStart` hook that scans your config dir, detects the active project, and
announces its pack to the engine. N projects coexist — one YAML each. No project
ever ships its own hook.

## Where configs live

```
${WORKFLOW_PACKS_DIR:-~/.claude/sherpa/projects}/<project>.yaml
```

One YAML per project. Set `WORKFLOW_PACKS_DIR` to relocate the dir. If the dir is
missing/empty, or no config's `detect` matches, the engine runs **generic** (no
pack) — every pack-dependent step no-ops.

## The config schema (camelCase)

```yaml
name: my-project

# A shell command, run with $CWD exported. Exit 0 = this project is active.
# Detect however you like — cwd glob, file presence, git remote, anything.
detect: case "$CWD" in */my-project*) exit 0 ;; *) exit 1 ;; esac

# What the main agent must do at session start when this project is detected
# (e.g. invoke the init skill + any project bootstrap). Free-form prose.
sessionInstructions: |
  Invoke Skill my-project-init before other work; skip if already invoked.

# The WORKFLOW_PACK — extension points the engine consumes.
pack:
  initialize: my-project-init
  reviewers: my-project-code-reviewer
  codeStyleAudit: /my-project-style-audit
  codeStyleRules: cat /abs/path/to/rules.md
  projectStatePath: /abs/path/to/my-project/.workflow-state
```

On the first config whose `detect` exits 0, the hook emits a `WORKFLOW_PACK:` line
(built from `name` + `pack`, values with spaces auto-quoted) followed by
`sessionInstructions`, as SessionStart `additionalContext`.

## What each `pack` key does

| Key | Fills | Engine seam that consumes it | When absent |
|---|---|---|---|
| `initialize` | skill that loads project knowledge; main agent invokes at session start, orchestrator forwards its SKILL.md path to subagents which `Read` it | the agent + every builder/reviewer/breaker subagent | engine defaults only |
| `reviewers` | extra code-reviewer subagents | `/build-and-review` review fan-out | only generic reviewers run |
| `codeStyleAudit` | exhaustive per-rule style **command** | Validate phase style audit | style audit skipped |
| `codeStyleRules` | shell **command** that dumps the full rule set to stdout — sherpa runs it, makes no assumption about storage | task-reviewer / adversarial-* style pass | `style — N/A: no project style pack` |
| `projectStatePath` | absolute dir for this project's run-state (SPEC/DECISIONS/PROGRESS/`discovery/`/`briefings/`/`handoffs/`) | state-persistence BASE resolution | falls back to `WORKFLOW_STATE_DIR` env, then the XDG default |

`codeStyleAudit` and `codeStyleRules` are **commands**, not paths — the engine runs
them and never assumes how the rules are stored. Codegen tiering shapes are
extended by the human per `protocols/invariants/tiering-catalog.md` § Extending the
catalog.

## Make a pack

```sh
cp TEMPLATE.yaml "${WORKFLOW_PACKS_DIR:-~/.claude/sherpa/projects}/my-project.yaml"
# edit detect / sessionInstructions / pack
cp -r TEMPLATE my-project-init-skill     # the init skill; place where Claude Code finds skills
```

No hook to write or register — sherpa's `SessionStart` hook reads your YAML.

## State directory (where SPEC/DECISIONS/PROGRESS/handoffs land)

Three ways to set it, highest precedence first:

1. **Per-project** — set `projectStatePath` in the pack `pack:` map. Auto-selected
   when the project is detected; no shell setup, and each project gets its own dir.
2. **Per-shell** — `export WORKFLOW_STATE_DIR=/path/to/my/workflow-state` (global,
   independent of packs).
3. **Default** — unset both → the zero-config XDG location.

Resolution: `BASE = <pack projectStatePath> || ${WORKFLOW_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/claude-workflow}`,
then `<BASE>/<branch-or-task-key>/`.
