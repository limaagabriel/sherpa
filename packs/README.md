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
<repo>/.sherpa/project.yaml         # project-local, single canonical location (single file)
<packs dir>/<project>/project.yaml  # workspace (user-global, many, one dir per pack)
```

`<packs dir>` resolves in this order: `$SHERPA_CONFIG_DIR/projects` if `SHERPA_CONFIG_DIR` is
set (it names sherpa's whole config root, not the packs dir itself), else `$WORKFLOW_PACKS_DIR`
if set (it points directly at the packs dir, no `/projects` suffix), else
`${XDG_CONFIG_HOME:-~/.config}/sherpa/projects`.

The **project-local** form is a single `project.yaml` (or `.yml`) committed inside
the repo, at `<repo>/.sherpa/project.yaml` — one project, one canonical location, so no
per-project directory or multi-tenancy needed, and no `detect` needed either: the file
only exists at that fixed path inside this repo, so finding it already *is* the
detection (`detect` is FORBIDDEN — never set it — for a project-local pack). The
**workspace** dir holds one directory per project, each holding its own `project.yaml`
(with a real `detect`, required since one shared dir serves many repos), and is where
you keep packs for repos you can't commit into. The first config whose `detect` matches
(or, for a project-local config, whose file is simply found) wins, so a project-local
pack **overrides** the workspace. When neither env var is set, the legacy
`~/.claude/sherpa/projects` dir is also scanned, after the XDG dir, as a read-fallback —
same per-pack layout, so packs living there keep working.

At session start the hook announces, via a user-visible `systemMessage`, either
**`Project "<name>" loaded into Sherpa from <yaml path>`** or **`no project pack
matched … running generic`** — so you always know whether project-specific
knowledge is active. Generic means no pack: every pack-dependent step no-ops.

## The config schema (camelCase)

`project.yaml` carries **metadata only** — nothing content-bearing lives in the YAML
anymore. Every content-bearing value is a fixed convention path (a file, or a
same-named directory of files) that lives next to the config, not a YAML key:

```yaml
name: my-project

# A shell command, run with $CWD exported. Exit 0 = this project is active.
# Detect however you like — cwd glob, file presence, git remote, anything.
# Required for a workspace pack (one dir serves many projects). FORBIDDEN
# (never set) for a project-local pack — the file's own fixed location already
# proves the project active.
detect: case "$CWD" in */my-project*) exit 0 ;; *) exit 1 ;; esac
```

...plus, alongside that `project.yaml`, whichever of these convention paths you need:

```
session.md                    # SessionStart-hook prose, read once at session start
context.md                    # cross-cutting, forwarded into every subagent's brief
frame/context.md              # additive to context.md, for the frame layer only
shape/context.md              # additive to context.md, for the shape layer only
shape/architecture.md         # architecture constraints
implement/context.md          # additive to context.md, for the implement layer only
implement/codeStyle.md        # complete rule set step-builder conforms output to
implement/validate.md         # command(s) step-builder runs before committing
implement/review.md           # prose the /implement driver reads before dispatching reviewers
```

Any of these stems may instead be a same-named **directory** of `*.md` files — e.g.
`implement/codeStyle/` holding several files — concatenated `LC_ALL=C sort`-by-filename.
If both `<stem>.md` and `<stem>/` exist, the file wins (a stderr warning names the
ambiguity). A missing convention path is a non-fatal stderr warning — that slot just
resolves to nothing.

On the first config whose `detect` exits 0 (or, for a project-local config, whose file
is simply found), the hook emits a `WORKFLOW_PACK:` line (built from `name` and
`configPath` only) as SessionStart `additionalContext`. Every convention path,
including `session` and `implement.validate`, is resolved lazily on demand via
`scripts/resolve-pack-value.sh <configPath> <key>`.

### Relative paths and resolution

Every convention key is resolved by calling `scripts/resolve-pack-value.sh <configPath>
<key>` (see `scripts/resolve-pack-value.sh`'s header comment for the full 9-key table).
There is no YAML lookup involved: the script maps `<key>` straight to its fixed stem,
then applies this precedence against the config's base dir:

1. `<stem>.md` exists → print its content, done.
2. else `<stem>/` exists → concatenate every `*.md` directly inside it,
   `LC_ALL=C sort`-by-filename, done.
3. both exist → the file wins, and a stderr warning names the ambiguity.
4. neither exists → print nothing to stdout; warn to stderr.

The **base dir is always the config's own directory** — project-local and workspace
configs alike, no exceptions and no ancestor walk-up. So `<repo>/.sherpa/project.yaml`
resolves convention paths against `<repo>/.sherpa/`, and `<packs
dir>/my-project/project.yaml` resolves against `<packs dir>/my-project/`.

This lets a pack colocate assets next to it:

```
<repo>/.sherpa/project.yaml
<repo>/.sherpa/implement/codeStyle.md
<repo>/.sherpa/implement/validate.md
```

### Colocated assets

Because every config's convention paths resolve against its own directory (project-local
or workspace alike), two packs can each ship a same-named file — e.g. both an
`implement/codeStyle.md` — without colliding:

```
<packs dir>/pack-a/project.yaml
<packs dir>/pack-a/implement/codeStyle.md
<packs dir>/pack-b/project.yaml
<packs dir>/pack-b/implement/codeStyle.md
```

Each pack just drops its convention files next to its own `project.yaml` — no naming
coordination between packs needed.

## What each key does

> **Breaking change note:** Both `implement.codeStyle` and `decompose.architecture` dropped a trailing `Rules` suffix in this release. A pack still using the suffixed spelling will see it resolve to nothing (no error) — grep your `project.yaml`/`sherpa.yaml` for a `Rules` suffix immediately after `codeStyle` or `architecture` and drop it.

> **Breaking change note:** `implement.validate` changed from a raw shell-command string to a file path (like every other content-bearing key) in this release. A pack still authoring `validate: <command>` will have that string treated as a (nonexistent) file path — it resolves to nothing, silently, and the build/test gate `step-builder` runs before committing stops firing. Move the command into its own file (e.g. `validate.md`) and point `validate` at that file's path instead.

> **Breaking change note:** The `decompose:` section was folded into `shape:` in this release — `decompose.knowledge` is now `shape.knowledge`, and `decompose.architecture` is now `shape.architecture`. A pack still authoring a `decompose:` section will see it silently ignored (no error) — move its `knowledge`/`architecture` keys under `shape:` instead.

> **Breaking change note:** Pack configs dropped YAML content-bearing keys entirely in this release, in favor of fixed convention paths on disk. A pack still authoring a dotted `pack:` YAML block (e.g. `pack:\n  knowledge: ./knowledge.md`, or top-level `context: ./context.txt`) will see it silently no-op (not an error) — nothing reads those keys anymore. The `knowledge` key name is retired in favor of `context` (and the old top-level `context` key, which meant SessionStart-hook prose, is retired in favor of `session`). Project-local packs also move location: `.sherpa/sherpa.yaml` (or the engine-specific `.claude/sherpa.yaml`, `.codex/sherpa.yaml`, `.pi/sherpa.yaml`) is retired in favor of the single `.sherpa/project.yaml`. Move each old YAML value's content into the matching convention file (see the table below) at the config's base dir instead.

| Key | Type | Fills | Engine seam that consumes it | When absent |
|---|---|---|---|---|
| `session` | file, or same-named directory of files | SessionStart-hook prose, read once at session start | `using-sherpa`'s HARD GATE, fetched lazily off the `WORKFLOW_PACK:` line's `configPath` | no session-start prose |
| `context` | file, or same-named directory of files | cross-cutting prose, resolved lazily via `scripts/resolve-pack-value.sh` immediately before each layer's dispatch, then forwarded to that layer's subagent(s) unchanged | every layer, every subagent | engine defaults only |
| `frame.context` | file, or same-named directory of files | additive prose for the frame layer, resolved the same lazy way alongside the cross-cutting `context` | `/frame` skill, `frame-reviewer` | cross-cutting `context` only |
| `shape.context` | file, or same-named directory of files | additive prose for the shape layer, resolved the same lazy way alongside the cross-cutting `context` | `/shape` skill, `shape-reviewer`, `structure-reviewer`, `readiness-reviewer` | cross-cutting `context` only |
| `shape.architecture` | file, or same-named directory of files | architecture constraints, resolved lazily and concatenated | plan-tail drafting (the `/shape` driver, composing the plan proposal); `structure-reviewer` checks the plan against it | no architecture check |
| `implement.context` | file, or same-named directory of files | additive prose for the implement layer, resolved the same lazy way alongside the cross-cutting `context` | `step-builder`, `quality-reviewer` | cross-cutting `context` only |
| `implement.codeStyle` | file, or same-named directory of files | complete rule set, resolved lazily and concatenated | `step-builder` output conformance + `quality-reviewer` style pass | falls back to language conventions + in-file precedent — `style — language-convention fallback` |
| `implement.validate` | file, or same-named directory of files | command(s) `step-builder` runs before committing, resolved lazily and concatenated — its content IS the command(s) to run | `step-builder`'s existing "build/test before committing" gate — a failure is `BUILD FAILED` | `step-builder` runs its own acceptance check only |
| `implement.review` | file, or same-named directory of files | prose instructions, resolved lazily and concatenated, read by the `/implement` driver itself at its pre-dispatch resolution point, right before dispatching that step's reviewer(s) | `/implement`'s driver, and whichever of `acceptance-reviewer`/`quality-reviewer` it ends up dispatching | driver uses its default two-reviewer/mechanical-single-reviewer dispatch unchanged |

`implement.review`'s content is plain prose the `/implement` driver reads and acts on directly —
not a structured directive. For example, an `implement/review.md` containing just:

```
Also flag any new REST endpoint missing an OpenAPI annotation.
```

lets the driver fold that instruction into `quality-reviewer`'s brief for the steps where it
applies, without any new engine surface — no new subagent, no new verdict shape.

`configPath` — the resolved path to this pack's yaml/config file — is announced automatically
by the engine alongside `name` in the `WORKFLOW_PACK:` line. Every convention path,
including `session` and `implement.validate`, is resolved lazily on demand and never inlined
into the announcement.

## Make a pack

```sh
# project-local (commit it in the repo — recommended for one project):
mkdir -p /path/to/my-repo/.sherpa
cp packs/TEMPLATE.yaml /path/to/my-repo/.sherpa/project.yaml
# edit name; delete the commented-out `detect:` example line entirely —
# a project-local pack must not have a `detect` key, it's forbidden

# OR workspace (user-global, for repos you can't commit into):
packs_dir="${SHERPA_CONFIG_DIR:+$SHERPA_CONFIG_DIR/projects}"
packs_dir="${packs_dir:-${WORKFLOW_PACKS_DIR:-${XDG_CONFIG_HOME:-~/.config}/sherpa/projects}}"
mkdir -p "$packs_dir/my-project"
cp packs/TEMPLATE.yaml "$packs_dir/my-project/project.yaml"
# edit name; uncomment the `detect:` example line and edit it for real

# Then, either way: create only the convention files you actually need, per the
# table above, next to that project.yaml — there's no scaffolding step, an
# absent file just means that slot resolves to nothing.

cp -r TEMPLATE my-project-init-skill     # optional init skill; invoke it from context or elsewhere
```

No hook to write or register — sherpa's `SessionStart` hook reads your YAML.

## State

Sherpa persists nothing automatically. The frame, pitch, and plan live in conversation; the
opt-in `/persist` skill writes them to disk when you ask. Packs carry no state path.
