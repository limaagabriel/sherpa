# Project packs — extending the workflow engine

The engine is project-agnostic. A **project pack** layers project-specific
knowledge on top of it (code style, architecture rules, profile/conventions)
without the engine knowing anything about your project.

A pack is a **YAML config file** plus, optionally, an **init skill** its prose may
invoke. Sherpa ships one generic `SessionStart` hook that scans your config dir,
detects the active project, and announces its pack to the engine. N projects
coexist — one YAML each. No project ever ships its own hook.

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

# What the main agent must do at session start when this project is detected.
# A file path or array of file paths — resolved via scripts/resolve-pack-value.sh
# against the config's base directory, missing files warned and skipped per-entry.
context: ./context.txt

# The WORKFLOW_PACK — extension points the engine consumes, sectioned by skill.
# Content-bearing keys (knowledge, architecture, codeStyle, validate, context)
# are file paths or arrays of file paths, resolved via scripts/resolve-pack-value.sh:
# each relative path resolves against this config's base directory; absolute paths
# are used as-is. Missing files are warned and skipped per-entry (not all-or-nothing).
# Paths never expand shell/env vars or ~ — use literal paths only.
pack:
  knowledge: ./knowledge.md   # or: [./knowledge.md, ./more-knowledge.md]   # cross-cutting: every layer, every subagent

  frame:
    knowledge: ./frame-knowledge.md   # optional, additive

  shape:
    knowledge: ./shape-knowledge.md   # optional, additive

  decompose:
    knowledge: ./decompose-knowledge.md   # optional, additive
    architecture: ./architecture.md

  implement:
    knowledge: ./implement-knowledge.md   # optional, additive
    codeStyle: ./rules.md
    validate: ./validate.md   # file path whose content is the command(s) to run
```

On the first config whose `detect` exits 0, the hook emits `context` first,
followed by a `WORKFLOW_PACK:` line (built from `name` and `configPath` only),
as SessionStart `additionalContext`. All other keys, including `validate`, are
resolved lazily on demand via `scripts/resolve-pack-value.sh`.

### Relative paths and resolution

Content-bearing keys (`knowledge`, `architecture`, `codeStyle`, `validate`, `context`)
are resolved by calling `scripts/resolve-pack-value.sh <configPath> <dotted.key>`.
This script reads the YAML value (string or array of strings), resolves each relative
entry against the config's base directory, reads each resolved file, and concatenates
found ones in listed order. Missing files are **warned and skipped per-entry** (not
all-or-nothing). Paths never expand shell/env vars or `~` — they are literal.

Base directory depends on the config form:

- **Project-local** (`<repo>/.sherpa|.claude|.codex|.pi/sherpa.yaml`): resolves against the
  config's **proximate `.sherpa`/`.claude`/`.codex`/`.pi` directory** — the nearest ancestor
  of the YAML named `.sherpa`, `.claude`, `.codex`, or `.pi`. So `<repo>/.codex/sherpa.yaml`
  resolves against `<repo>/.codex`.
- **Workspace** (`<packs dir>/<project>/project.yaml`): resolves against **the pack's own
  directory**, `<packs dir>/<project>/` — not the shared `<packs dir>`. So
  `<packs dir>/my-project/project.yaml` resolves against `<packs dir>/my-project/`.

This lets a pack colocate assets next to it:

```yaml
detect: ./detect.sh                  # shell command; runs from the config's base dir
pack:
  implement:
    codeStyle: ./rules.md            # file path; resolved against config's base dir
    validate: ./validate.md          # file path; its content is the command(s) to run
```

Values starting with `/` (absolute paths) are used as-is. `detect` is the one key whose
value is always a shell command, never a path; it runs with its working directory set to
the base dir (its `$CWD` export still points at the repo, so cwd-glob detects work
normally).

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

> **Breaking change note:** Both `implement.codeStyle` and `decompose.architecture` dropped a trailing `Rules` suffix in this release. A pack still using the suffixed spelling will see it resolve to nothing (no error) — grep your `project.yaml`/`sherpa.yaml` for a `Rules` suffix immediately after `codeStyle` or `architecture` and drop it.

> **Breaking change note:** `implement.validate` changed from a raw shell-command string to a file path (like every other content-bearing key) in this release. A pack still authoring `validate: <command>` will have that string treated as a (nonexistent) file path — it resolves to nothing, silently, and the build/test gate `step-builder` runs before committing stops firing. Move the command into its own file (e.g. `validate.md`) and point `validate` at that file's path instead.

| Key | Type | Fills | Engine seam that consumes it | When absent |
|---|---|---|---|---|
| `knowledge` (top-level) | file path or array of paths | prose, resolved lazily via `scripts/resolve-pack-value.sh` immediately before each layer's dispatch, then forwarded to that layer's subagent(s) unchanged | every layer, every subagent | engine defaults only |
| `frame.knowledge` | file path or array of paths | additive prose for the frame layer, resolved the same lazy way alongside the cross-cutting `knowledge` | `/frame` skill, `frame-reviewer` | cross-cutting `knowledge` only |
| `shape.knowledge` | file path or array of paths | additive prose for the shape layer, resolved the same lazy way alongside the cross-cutting `knowledge` | `/shape` skill, `shape-reviewer` | cross-cutting `knowledge` only |
| `decompose.knowledge` | file path or array of paths | additive prose for the decompose layer, resolved the same lazy way alongside the cross-cutting `knowledge` | `/decompose` skill, `structure-reviewer`, `readiness-reviewer` | cross-cutting `knowledge` only |
| `decompose.architecture` | file path or array of paths | architecture constraints, resolved lazily and concatenated | `/decompose` drafts steps mindful of it; `structure-reviewer` checks the decomposition against it | no architecture check |
| `implement.knowledge` | file path or array of paths | additive prose for the implement layer, resolved the same lazy way alongside the cross-cutting `knowledge` | `step-builder`, `quality-reviewer` | cross-cutting `knowledge` only |
| `implement.codeStyle` | file path or array of paths | complete rule set, resolved lazily and concatenated | `step-builder` output conformance + `quality-reviewer` style pass | falls back to language conventions + in-file precedent — `style — language-convention fallback` |
| `implement.validate` | file path or array of paths | command(s) `step-builder` runs before committing, resolved lazily and concatenated — its content IS the command(s) to run | `step-builder`'s existing "build/test before committing" gate — a failure is `BUILD FAILED` | `step-builder` runs its own acceptance check only |
| `context` | file path or array of paths | free-form prose for session-start context | `SessionStart` hook as first `additionalContext`, before the `WORKFLOW_PACK:` line | no additional context |

`configPath` — the resolved path to this pack's yaml/config file — is announced automatically
by the engine alongside `name` in the `WORKFLOW_PACK:` line. All other keys,
including `validate`, are resolved lazily on demand and never inlined into the announcement.

## Make a pack

```sh
# project-local (commit it in the repo — recommended for one project):
cp TEMPLATE.yaml /path/to/my-repo/.sherpa/sherpa.yaml   # or .claude/ .codex/ .pi/
# edit pack (drop `detect` entirely — it's this repo); set context path or omit it

# OR workspace (user-global, for repos you can't commit into):
packs_dir="${SHERPA_CONFIG_DIR:+$SHERPA_CONFIG_DIR/projects}"
packs_dir="${packs_dir:-${WORKFLOW_PACKS_DIR:-${XDG_CONFIG_HOME:-~/.config}/sherpa/projects}}"
mkdir -p "$packs_dir/my-project"
cp TEMPLATE.yaml "$packs_dir/my-project/project.yaml"
# edit detect / context / pack

cp -r TEMPLATE my-project-init-skill     # optional init skill; invoke it from context or elsewhere
```

No hook to write or register — sherpa's `SessionStart` hook reads your YAML.

## State

Sherpa persists nothing automatically. The frame, pitch, and plan live in conversation; the
opt-in `/persist` skill writes them to disk when you ask. Packs carry no state path.
