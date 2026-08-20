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
<packs dir>/<project>/project.yaml  # workspace (user-global, many, one dir per pack)
```

`<packs dir>` resolves in this order: `$SHERPA_CONFIG_DIR/projects` if `SHERPA_CONFIG_DIR` is
set (it names sherpa's whole config root, not the packs dir itself), else `$WORKFLOW_PACKS_DIR`
if set (it points directly at the packs dir, no `/projects` suffix), else
`${XDG_CONFIG_HOME:-~/.config}/sherpa/projects`.

The **project-local** form is a single `sherpa.yaml` (or `.yml`) committed inside
the repo — one project, so no per-project directory or multi-tenancy needed, and no
`detect` needed either: the file only exists at that fixed path inside this repo,
so finding it already *is* the detection. The **workspace** dir holds one directory
per project, each holding its own `project.yaml` (with a real `detect`, since one
shared dir serves many repos), and is where you keep packs for repos you can't commit
into. The first config whose `detect` matches (or, for a project-local config, whose
file is simply found) wins, so a project-local pack **overrides** the workspace. When
neither env var is set, the legacy `~/.claude/sherpa/projects` dir is also scanned,
after the XDG dir, as a read-fallback — same per-pack layout, so packs living there
keep working.

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
# `knowledge` values are always literal inline prose — write them at any length.
# They are never inlined eagerly into the WORKFLOW_PACK announcement; each layer
# skill resolves them lazily via `yq` against the announced `configPath`,
# immediately before dispatch, then forwards the result unchanged to its
# subagent(s). Subagents cannot Read files or invoke a Skill for this input
# (see agents/*.md) — a `knowledge` value is never itself an instruction to
# load something else; write the prose directly.
pack:
  knowledge: Prefer named exports over default exports; keep functions under 40 lines.   # cross-cutting: every layer, every subagent

  frame:
    knowledge: Additive frame-layer notes for the reviewer.   # optional, additive

  shape:
    knowledge: Additive shape-layer notes for the shape-reviewer.   # optional, additive

  decompose:
    knowledge: Additive decompose-layer notes for the reviewer.   # optional, additive
    architectureRules: cat /abs/path/to/architecture.md

  implement:
    knowledge: Additive implement-layer notes for the step-builder.   # optional, additive
    codeStyleRules: cat /abs/path/to/rules.md
    validate: |
      npm run lint
      npm test
```

On the first config whose `detect` exits 0, the hook emits `sessionInstructions`
first, followed by a `WORKFLOW_PACK:` line (built from `name`, `configPath`, and
any command-type `pack` keys — `knowledge` values are never inlined here, see
below), as SessionStart `additionalContext`.

### Relative paths

Path-ish values may be **absolute or relative**. What a relative value resolves against
depends on which form the config is:

- **Project-local** (`<repo>/.sherpa|.claude|.codex|.pi/sherpa.yaml`): resolves against the
  config's **proximate `.sherpa`/`.claude`/`.codex`/`.pi` directory** — the nearest ancestor
  of the YAML named `.sherpa`, `.claude`, `.codex`, or `.pi`. So `<repo>/.codex/sherpa.yaml`
  resolves against `<repo>/.codex`.
- **Workspace** (`<packs dir>/<project>/project.yaml`): resolves against **the pack's own
  directory**, `<packs dir>/<project>/` — not the shared `<packs dir>`. So
  `<packs dir>/my-project/project.yaml` resolves against `<packs dir>/my-project/`.

Either way, this lets a pack reference scripts/files next to it:

```yaml
detect: ./detect.sh                  # runs from the config's base dir (see split above)
pack:
  implement:
    codeStyleRules: cat ./rules.md   # pre-wrapped: cd <base> && cat ./rules.md
```

Values starting with `/` (an absolute path, or a `/slash-skill` like
`/my-style-audit`) are left **as-is** — never rewritten. `detect` runs with its
working directory set to that base dir (its `$CWD` export still points at the
repo, so cwd-glob detects are unaffected).

### Colocated assets

Because a workspace pack's relative paths resolve against its own directory, two packs
can each ship a same-named file — e.g. both a `detect.sh` — without colliding:

```
<packs dir>/pack-a/project.yaml   # detect: ./detect.sh
<packs dir>/pack-a/detect.sh
<packs dir>/pack-b/project.yaml   # detect: ./detect.sh
<packs dir>/pack-b/detect.sh
```

Each pack's `project.yaml` just says `detect: ./detect.sh` and gets its own script — no
naming coordination between packs needed.

## What each `pack` key does

| Key | Fills | Engine seam that consumes it | When absent |
|---|---|---|---|
| `knowledge` (top-level) | inline prose, resolved lazily via `configPath` immediately before each layer's dispatch, then forwarded to that layer's subagent(s) unchanged — never inlined into the WORKFLOW_PACK announcement, and never itself a pointer telling a subagent to load something else | every layer, every subagent | engine defaults only |
| `frame.knowledge` | additive inline prose for the frame layer, resolved the same lazy way alongside the cross-cutting `knowledge` | `/frame` skill, `frame-reviewer` | cross-cutting `knowledge` only |
| `shape.knowledge` | additive inline prose for the shape layer, resolved the same lazy way alongside the cross-cutting `knowledge` | `/shape` skill, `shape-reviewer` | cross-cutting `knowledge` only |
| `decompose.knowledge` | additive inline prose for the decompose layer, resolved the same lazy way alongside the cross-cutting `knowledge` | `/decompose` skill, `structure-reviewer`, `readiness-reviewer` | cross-cutting `knowledge` only |
| `decompose.architectureRules` | shell **command** that dumps architecture constraints to stdout — inlined directly in the WORKFLOW_PACK announcement, unlike `knowledge` | `/decompose` drafts steps mindful of it; `structure-reviewer` checks the decomposition against it | no architecture check |
| `implement.knowledge` | additive inline prose for the implement layer, resolved the same lazy way alongside the cross-cutting `knowledge` | `step-builder`, `quality-reviewer` | cross-cutting `knowledge` only |
| `implement.codeStyleRules` | shell **command** that dumps the full rule set to stdout — inlined directly in the WORKFLOW_PACK announcement, sherpa runs it, makes no assumption about storage | `step-builder` output conformance + `quality-reviewer` style pass | falls back to language conventions + in-file precedent — `style — language-convention fallback` |
| `implement.validate` | shell command(s) `step-builder` runs before committing | `step-builder`'s existing "build/test before committing" gate — a failure is `BUILD FAILED` | `step-builder` runs its own acceptance check only |

`configPath` — the resolved path to this pack's yaml/config file — is announced automatically by the engine alongside `name`; it isn't an authored `pack` key, it's what the lazy `knowledge` resolution above reads from.

`architectureRules`, `codeStyleRules`, and `validate` are **commands**, not paths — the engine
runs them and never assumes how the rules are stored.

## Make a pack

```sh
# project-local (commit it in the repo — recommended for one project):
cp TEMPLATE.yaml /path/to/my-repo/.sherpa/sherpa.yaml   # or .claude/ .codex/ .pi/
# edit pack (drop `detect` entirely — it's this repo); sessionInstructions

# OR workspace (user-global, for repos you can't commit into):
packs_dir="${SHERPA_CONFIG_DIR:+$SHERPA_CONFIG_DIR/projects}"
packs_dir="${packs_dir:-${WORKFLOW_PACKS_DIR:-${XDG_CONFIG_HOME:-~/.config}/sherpa/projects}}"
mkdir -p "$packs_dir/my-project"
cp TEMPLATE.yaml "$packs_dir/my-project/project.yaml"
# edit detect / sessionInstructions / pack

cp -r TEMPLATE my-project-init-skill     # optional init skill; only needed if your sessionInstructions invokes one
```

No hook to write or register — sherpa's `SessionStart` hook reads your YAML.

## State

Sherpa persists nothing automatically. The frame, pitch, and plan live in conversation; the
opt-in `/persist` skill writes them to disk when you ask. Packs carry no state path.
