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
- `frame/context.md`, `shape/context.md`, `implement/context.md`, `analyze/context.md` — appended
  for that layer's subagents only.

- `guardrails.yaml` — checks sherpa runs for you, per phase:

  ```yaml
  guardrails:
    - {name: lint, run: "npx eslint .", when: step}     # shell command, one line
    - {name: review, skill: analyze, args: "--fast", when: end}
  ```

  Each entry has a `name` and exactly one of `run` (a shell command) or `skill`
  (a skill name, optional `args`). `when` is `step` (after each step), `end` (at the
  end of the run) or `both` (the default).
  `bash scripts/guardrails/list.sh <configPath> <step|end> [run|skill]` prints the
  entries as `name<TAB>kind<TAB>value`; `bash scripts/guardrails/run.sh <configPath> <step|end>`
  runs the `run` entries via `bash -c` in the current directory and prints
  `GUARDRAIL <name>: pass|fail` (plus the last 20 output lines on a failure). Exit
  codes: `0` all passed or nothing to do (no file, or `configPath` is `none`);
  `1` (runner only) a guardrail failed; `2` cannot run (usage error, unknown phase,
  `yq` missing while the file exists, malformed YAML, an entry without `name`, or
  with both or neither of `run`/`skill`). Multi-line values are rejected (exit 2).
  - A `run` command in an `end` or `both` guardrail must only check, never modify files
    (`eslint`, not `eslint --fix`). A `when: step` guardrail may rewrite the step's own
    uncommitted files (e.g. a formatter, `eslint --fix`); those edits are committed with the step.
    A `run` command runs with your permissions and is not sandboxed — same trust as `detect`.
  - A `skill` guardrail must be report-only and non-interactive. The driver judges it
    from the skill's report, so it is not deterministic.

- `skills/<name>/SKILL.md` — a pack skill, run with `/invoke <name> [args]`. Companion files
  (scripts, templates) live in the same `skills/<name>/` folder; relative paths in the skill
  resolve there.
  - The `SessionStart` hook prints a `PACK SKILLS` index: one line per skill, with the
    description cut to its first sentence (max 150 chars). Whole entries only, the block is
    ≤ 2 KB, and any leftovers become `(N more — /invoke with no args lists all)`.
  - Give each skill a one-line `description:` in its frontmatter. A folded or multi-line
    value (`>`, `|`) shows an empty description; the skill is still listed by name.
  - A project pack skill overrides a shared one with the same folder name.
  - `/invoke` resolves the first argument in this order, first match wins: if it contains `/`
    or ends in `.md` and the file exists, that file; else a pack skill; else a native skill;
    else it prints the list.
  - `allowed-tools` is advisory only; nothing enforces it.
  - A skill runs with your permissions and is not sandboxed — same trust as `detect`.
  - A guardrail `skill:` entry may name a pack skill.

Any `context.md` may just tell the reader to Read another file.

## How subagents get it

One resolver call: `bash scripts/pack/load-layer.sh <configPath> [frame|shape|implement|analyze]`
prints whatever of the above exists.

> **Breaking change note:** `shape/architecture.md`, `implement/codeStyle.md`, `implement/validate.md`, `implement/review.md`, and directory-of-files stems are retired — move their content, or a "Read `<path>`" pointer, into the matching `context.md`. The old lazy `session` fetch is gone; the `SessionStart` hook now injects `session.md` directly.
>
> **Breaking change note:** build, test and lint instructions written as prose in `implement/context.md` are no longer run by the step builder — move them to `guardrails.yaml`.
>
> **Breaking change note:** the `review/` layer is renamed to `analyze/` (the `/review` skill is now `/analyze`) — move `review/context.md` to `analyze/context.md`.

## Shared pack

Personal rules that apply to every project live in one shared dir:
`${SHERPA_CONFIG_DIR:-${XDG_CONFIG_HOME:-~/.config}/sherpa}/shared`. It uses the same
convention files as a project pack — `context.md` and `<layer>/context.md` (frame, shape,
implement, analyze) — but needs no `project.yaml` and no `detect`, so it also applies when
no project pack matches.

`bash scripts/pack/load-layer.sh <configPath|none> [layer]` prints the shared files first,
then the project's, with the line `PROJECT RULES (override shared rules above on conflict):`
between them. Project rules win on conflict; this is prose the model follows, not a
guarantee. Pass `none` as `configPath` to get the shared files only. With no shared files,
the output is the same as before.

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

Sherpa persists nothing automatically; `/persist` is opt-in. The one exception is the opt-in
inventory, which keeps ticket state under `~/.config/sherpa/inventory` only when you run
`sherpa init` or `sherpa loop`.
