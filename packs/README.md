# Project packs — extending the workflow engine

The engine is project-agnostic. A **project pack** layers project-specific
knowledge on top of it — without the engine knowing anything about your project.

## Where configs live

Three sources, highest precedence first:

- **Project-local** (recommended, one project): `<repo>/.sherpa/project.yaml` (`.yaml` or `.yml`), committed in the repo. No `detect` — the fixed path is the detection. Wins over the workspace.
- **Workspace** (user-global, many projects): `<packs dir>/<project>/project.yaml` (`.yaml` or `.yml`), with a real `detect` (required — one shared dir serves many repos). `<packs dir>` is `$SHERPA_CONFIG_DIR/projects` if set, else `$WORKFLOW_PACKS_DIR` if set, else `${XDG_CONFIG_HOME:-~/.config}/sherpa/projects`.
- **Legacy read-fallback**: when neither env var is set, `~/.claude/sherpa/projects` is also scanned, after the XDG dir, so packs living there keep working.

## The `project.yaml` schema

Metadata only — `name` and `detect`:

```yaml
name: my-project

# A shell command, run with $CWD exported. Exit 0 = this project is active.
# Required for a workspace pack. FORBIDDEN for a project-local pack.
detect: case "$CWD" in */my-project*) exit 0 ;; *) exit 1 ;; esac
```

## Convention files (next to `project.yaml`)

- `session.md` — bootstrap rules, injected at session start under a
  `PROJECT SESSION RULES` line. Soft-capped at 4 KB — keep it short.
- `context.md` — forwarded to every subagent.
- `frame/context.md`, `shape/context.md`, `implement/context.md` — appended
  for that layer's subagents only.

Any `context.md` may just tell the reader to Read another file.

## How subagents get it

One resolver call: `bash scripts/resolve-pack-value.sh <configPath> [frame|shape|implement]`
prints whatever of the above exists.

> **Breaking change note:** `shape/architecture.md`, `implement/codeStyle.md`, `implement/validate.md`, `implement/review.md`, and directory-of-files stems are retired — move their content, or a "Read `<path>`" pointer, into the matching `context.md`. The old lazy `session` fetch is gone; the `SessionStart` hook now injects `session.md` directly.

## Make a pack

```sh
# project-local:
mkdir -p /path/to/my-repo/.sherpa
cp packs/TEMPLATE.yaml /path/to/my-repo/.sherpa/project.yaml
# edit name; leave `detect` out entirely — it's only a commented-out
# example, and `detect` is forbidden for project-local packs

# OR workspace:
packs_dir="${SHERPA_CONFIG_DIR:+$SHERPA_CONFIG_DIR/projects}"
packs_dir="${packs_dir:-${WORKFLOW_PACKS_DIR:-${XDG_CONFIG_HOME:-~/.config}/sherpa/projects}}"
mkdir -p "$packs_dir/my-project"
cp packs/TEMPLATE.yaml "$packs_dir/my-project/project.yaml"
# edit name; write a real `detect:` line, using the commented example as a model
```

Then create only the convention files you actually need, next to that
`project.yaml` — an absent file just resolves to nothing.

## State

Sherpa persists nothing automatically; `/persist` is opt-in.
