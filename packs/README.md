# Project packs — extending the workflow engine

The engine is project-agnostic. A **project pack** layers project-specific
knowledge on top of it (code style, extra reviewers, profile/conventions)
without the engine knowing anything about your project.

A pack is a **YAML config file** plus an **init skill**. Sherpa ships one generic
`SessionStart` hook that scans your config dir, detects the active project, and
announces its pack to the engine. N projects coexist — one YAML each. No project
ever ships its own hook.

## Where configs live

The resolver checks these candidates, **highest precedence first**:

```
<repo>/.claude/sherpa.yaml          # project-local, shareable in-repo (single file)
<repo>/.codex/sherpa.yaml           # project-local, shareable in-repo (single file)
${WORKFLOW_PACKS_DIR:-~/.claude/sherpa/projects}/<project>.yaml   # workspace (user-global, many)
```

The **project-local** form is a single `sherpa.yaml` (or `.yml`) committed inside
the repo — one project, so no `projects/` dir or multi-tenancy needed; its
`detect` can just be `exit 0` ("this repo"). The **workspace** dir holds one YAML
per project (each with a real `detect`) and is where you keep packs for repos you
can't commit into. The first config whose `detect` matches wins, so a
project-local pack **overrides** the workspace. Set `WORKFLOW_PACKS_DIR` to
relocate the workspace dir.

At session start the hook announces, via a user-visible `systemMessage`, either
**`Project "<name>" loaded into Sherpa from <yaml path>`** or **`no project pack
matched … running generic`** — so you always know whether project-specific
knowledge is active. Generic means no pack: every pack-dependent step no-ops.

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
  architectureRules: cat /abs/path/to/architecture.md
  projectStatePath: /abs/path/to/my-project/.workflow-state
```

On the first config whose `detect` exits 0, the hook emits a `WORKFLOW_PACK:` line
(built from `name` + `pack`, values with spaces auto-quoted) followed by
`sessionInstructions`, as SessionStart `additionalContext`.

### Relative paths

Path-ish values may be **absolute or relative**. A relative value resolves against
the config's **proximate `.claude`/`.codex` directory** — the nearest ancestor of
the YAML named `.claude` or `.codex`. So `<repo>/.codex/sherpa.yaml` resolves
against `<repo>/.codex`, and `~/.claude/sherpa/projects/<p>.yaml` against
`~/.claude`. This lets a committed pack reference scripts/files next to it:

```yaml
detect: ./detect.sh                  # runs from the proximate dir
pack:
  codeStyleAudit: ./style-audit.sh   # pre-wrapped: cd <base> && ./style-audit.sh
  codeStyleRules: cat ./rules.md
  projectStatePath: ./.workflow-state # → <base>/.workflow-state
```

Values starting with `/` (an absolute path, or a `/slash-skill` like
`/my-style-audit`) and `projectStatePath` starting with `~` are left **as-is** —
never rewritten. `detect` runs with its working directory set to the proximate dir
(its `$CWD` export still points at the repo, so cwd-glob detects are unaffected).

## What each `pack` key does

| Key | Fills | Engine seam that consumes it | When absent |
|---|---|---|---|
| `initialize` | skill that loads project knowledge; main agent invokes at session start, orchestrator forwards its SKILL.md path to subagents which `Read` it | the agent + every builder/reviewer/breaker subagent | engine defaults only |
| `reviewers` | extra code-reviewer subagents | `/build-and-review` review fan-out | only generic reviewers run |
| `codeStyleAudit` | exhaustive per-rule style **command** | Validate phase style audit | style audit skipped |
| `codeStyleRules` | shell **command** that dumps the full rule set to stdout — sherpa runs it, makes no assumption about storage | task-reviewer / adversarial-* style pass | falls back to language conventions + in-file precedent — `style — language-convention fallback` |
| `architectureRules` | shell **command** that dumps the project's architectural guidelines to stdout — sherpa runs it at the **plan** layer (vs `codeStyleRules` at the step layer) | `plan-reviewer` mode=briefing — its Architecture-rule violation lens | falls back to advisory general principles (SRP / coupling / cyclic deps / leaky abstraction) — `architecture — general-principle fallback`, WARN not BLOCK |
| `projectStatePath` | dir for this project's run-state (SPEC/DECISIONS/PROGRESS/`discovery/`/`briefings/`/`handoffs/`) — absolute, `~`, or relative to the proximate dir | state-persistence BASE resolution | falls back to `WORKFLOW_STATE_DIR` env, then the XDG default |

`codeStyleAudit`, `codeStyleRules`, and `architectureRules` are **commands**, not paths —
the engine runs them and never assumes how the rules are stored. Codegen tiering shapes are
extended by the human per `protocols/invariants/tiering-catalog.md` § Extending the
catalog.

## Make a pack

```sh
# project-local (commit it in the repo — recommended for one project):
cp TEMPLATE.yaml /path/to/my-repo/.codex/sherpa.yaml   # or .claude/sherpa.yaml
# edit pack (detect can be `exit 0` — it's this repo); sessionInstructions

# OR workspace (user-global, for repos you can't commit into):
cp TEMPLATE.yaml "${WORKFLOW_PACKS_DIR:-~/.claude/sherpa/projects}/my-project.yaml"
# edit detect / sessionInstructions / pack

cp -r TEMPLATE my-project-init-skill     # the init skill; place where Claude Code finds skills
```

No hook to write or register — sherpa's `SessionStart` hook reads your YAML.

## State directory (where SPEC/DECISIONS/PROGRESS/handoffs land)

Three ways to set it, highest precedence first:

1. **Per-project** — set `projectStatePath` in the pack `pack:` map (absolute, `~`,
   or relative to the proximate dir — see § Relative paths). Auto-selected when the
   project is detected; no shell setup, and each project gets its own dir.
2. **Per-shell** — `export WORKFLOW_STATE_DIR=/path/to/my/workflow-state` (global,
   independent of packs).
3. **Default** — unset both → the zero-config XDG location.

Resolution: `BASE = <pack projectStatePath> || ${WORKFLOW_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/claude-workflow}`,
then `<BASE>/<branch-or-task-key>/`.
