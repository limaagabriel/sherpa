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
  codeStyleRules: cat /abs/path/to/rules.md
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
  codeStyleRules: cat ./rules.md     # pre-wrapped: cd <base> && cat ./rules.md
```

Values starting with `/` (an absolute path, or a `/slash-skill` like
`/my-style-audit`) are left **as-is** — never rewritten. `detect` runs with its
working directory set to the proximate dir (its `$CWD` export still points at the
repo, so cwd-glob detects are unaffected).

## What each `pack` key does

| Key | Fills | Engine seam that consumes it | When absent |
|---|---|---|---|
| `initialize` | skill that loads project knowledge; main agent invokes at session start, orchestrator forwards its SKILL.md path to subagents which `Read` it | the agent + every step-builder/reviewer subagent | engine defaults only |
| `reviewers` | extra code-reviewer subagents | `quality-reviewer` style pass | only generic reviewers run |
| `codeStyleRules` | shell **command** that dumps the full rule set to stdout — sherpa runs it, makes no assumption about storage | step-builder output conformance + `quality-reviewer` style pass | falls back to language conventions + in-file precedent — `style — language-convention fallback` |

`codeStyleRules` is a **command**, not a path — the engine runs it and never assumes
how the rules are stored.

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

## State

Sherpa persists nothing automatically. The spec and plan live in conversation; the
opt-in `/persist` skill writes them to disk when you ask. Packs carry no state path.
