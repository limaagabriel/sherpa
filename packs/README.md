# Project packs — extending the workflow engine

The engine is project-agnostic. A **project pack** layers project-specific
knowledge on top of it (code style, architecture rules, profile/conventions)
without the engine knowing anything about your project.

A pack is a **YAML config file** plus, optionally, an **init skill** its prose may
invoke. Sherpa ships one generic
`SessionStart` hook that scans your config dir, detects the active project, and
announces its pack to the engine. N projects coexist — one YAML each. No project
ever ships its own hook.

## Where configs live

The resolver checks these candidates, **highest precedence first**:

```
<repo>/.sherpa/sherpa.yaml          # project-local, engine-neutral (single file)
<repo>/.claude/sherpa.yaml          # project-local, engine-specific
<repo>/.codex/sherpa.yaml           # project-local, engine-specific
<repo>/.pi/sherpa.yaml              # project-local, engine-specific
${WORKFLOW_PACKS_DIR:-${XDG_CONFIG_HOME:-~/.config}/sherpa/projects}/<project>.yaml   # workspace (user-global, many)
```

The **project-local** form is a single `sherpa.yaml` (or `.yml`) committed inside
the repo — one project, so no `projects/` dir or multi-tenancy needed, and no
`detect` needed either: the file only exists at that fixed path inside this repo,
so finding it already *is* the detection. The **workspace** dir holds one YAML
per project (each with a real `detect`, since one shared dir serves many repos)
and is where you keep packs for repos you can't commit into. The first config
whose `detect` matches (or, for a project-local config, whose file is simply
found) wins, so a project-local pack **overrides** the workspace. Set
`WORKFLOW_PACKS_DIR` to relocate the workspace dir. When it is unset, the legacy
`~/.claude/sherpa/projects` is also scanned as a read-fallback after the XDG dir,
so packs created before the engine-neutral move keep working.

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

# The WORKFLOW_PACK — extension points the engine consumes, sectioned by skill.
# `knowledge` values are inline prose, forwarded verbatim to every layer and
# subagent in the WORKFLOW_PACK announcement — the prose may itself say
# "invoke Skill X" if you want a skill loaded.
pack:
  knowledge: Invoke Skill my-project-init — loads project rules.   # cross-cutting: every layer, every subagent

  spec:
    knowledge: Additive spec-layer notes for the reviewer.   # optional, additive

  plan:
    knowledge: Additive plan-layer notes for the reviewer.   # optional, additive
    architectureRules: cat /abs/path/to/architecture.md

  implement:
    knowledge: Additive implement-layer notes for the step-builder.   # optional, additive
    codeStyleRules: cat /abs/path/to/rules.md
    validate: |
      npm run lint
      npm test

  diverge:
    knowledge: Additive diverge-layer notes for the diverge-reviewer.   # optional, additive
```

On the first config whose `detect` exits 0, the hook emits a `WORKFLOW_PACK:` line
(built from `name` + `pack`, values with spaces auto-quoted) followed by
`sessionInstructions`, as SessionStart `additionalContext`.

### Relative paths

Path-ish values may be **absolute or relative**. A relative value resolves against
the config's **proximate `.sherpa`/`.claude`/`.codex`/`.pi` directory** — the nearest ancestor of
the YAML named `.sherpa`, `.claude`, `.codex`, or `.pi`. So `<repo>/.codex/sherpa.yaml` resolves
against `<repo>/.codex`, and `~/.config/sherpa/projects/<p>.yaml` against
`~/.config/sherpa/projects`. This lets a committed pack reference scripts/files next to it:

```yaml
detect: ./detect.sh                  # runs from the proximate dir
pack:
  implement:
    codeStyleRules: cat ./rules.md   # pre-wrapped: cd <base> && cat ./rules.md
```

Values starting with `/` (an absolute path, or a `/slash-skill` like
`/my-style-audit`) are left **as-is** — never rewritten. `detect` runs with its
working directory set to the proximate dir (its `$CWD` export still points at the
repo, so cwd-glob detects are unaffected).

## What each `pack` key does

| Key | Fills | Engine seam that consumes it | When absent |
|---|---|---|---|
| `knowledge` (top-level) | inline prose, forwarded verbatim in the WORKFLOW_PACK announcement to every layer and subagent — the prose may itself say "invoke Skill X" | every layer, every subagent | engine defaults only |
| `spec.knowledge` | additive inline prose for the spec layer, forwarded verbatim alongside the cross-cutting `knowledge` | `/spec` skill, `spec-reviewer` | cross-cutting `knowledge` only |
| `plan.knowledge` | additive inline prose for the plan layer, forwarded verbatim alongside the cross-cutting `knowledge` | `/plan` skill, `plan-reviewer` | cross-cutting `knowledge` only |
| `plan.architectureRules` | shell **command** that dumps architecture constraints to stdout | `/plan` drafts steps mindful of it; `plan-reviewer` checks the decomposition against it | no architecture check |
| `implement.knowledge` | additive inline prose for the implement layer, forwarded verbatim alongside the cross-cutting `knowledge` | `step-builder`, `quality-reviewer` | cross-cutting `knowledge` only |
| `implement.codeStyleRules` | shell **command** that dumps the full rule set to stdout — sherpa runs it, makes no assumption about storage | `step-builder` output conformance + `quality-reviewer` style pass | falls back to language conventions + in-file precedent — `style — language-convention fallback` |
| `implement.validate` | shell command(s) `step-builder` runs before committing | `step-builder`'s existing "build/test before committing" gate — a failure is `BUILD FAILED` | `step-builder` runs its own acceptance check only |
| `diverge.knowledge` | additive inline prose for the diverge layer, forwarded verbatim alongside the cross-cutting `knowledge` | `/diverge` skill, `diverge-reviewer` | cross-cutting `knowledge` only |

`architectureRules`, `codeStyleRules`, and `validate` are **commands**, not paths — the engine
runs them and never assumes how the rules are stored.

## Make a pack

```sh
# project-local (commit it in the repo — recommended for one project):
cp TEMPLATE.yaml /path/to/my-repo/.sherpa/sherpa.yaml   # or .claude/ .codex/ .pi/
# edit pack (drop `detect` entirely — it's this repo); sessionInstructions

# OR workspace (user-global, for repos you can't commit into):
cp TEMPLATE.yaml "${WORKFLOW_PACKS_DIR:-${XDG_CONFIG_HOME:-~/.config}/sherpa/projects}/my-project.yaml"
# edit detect / sessionInstructions / pack

cp -r TEMPLATE my-project-init-skill     # optional init skill; only needed if your knowledge prose invokes one
```

No hook to write or register — sherpa's `SessionStart` hook reads your YAML.

## State

Sherpa persists nothing automatically. The spec and plan live in conversation; the
opt-in `/persist` skill writes them to disk when you ask. Packs carry no state path.
