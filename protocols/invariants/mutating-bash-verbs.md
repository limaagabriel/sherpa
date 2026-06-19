# Mutating Bash Verbs

## The list

`git commit/push/reset/checkout/restore/clean/rm/mv/rebase` + `npm install` + `>` redirection.

## Read-only roles

Acceptance-reviewer, adversarial-breaker (default + `mode=briefing`), turn-reviewer, code-review personas, scout agents, and coordinators (`/build-and-review`, `/adversarial-build`): Bash is inspection only — `git status`, `git diff`, `git log`, `git show`, `git blame`, `grep`, `cat`, `ls`, `rg`. Any listed verb is forbidden.

Coordinators MAY additionally invoke `scripts/build-log.sh` (per-phase telemetry; encapsulates its own `>>`) and `scripts/build-notes.sh init` (repo-local notes config, once at Prep; encapsulates its own `git config`).

## Exceptions (intentional)

- **Builder agents** (`adversarial-builder`, `codegen-builder`) run their own commits and any commands the briefing names.
- **`adversarial-breaker` `mode=output`** may run non-mutating build/test commands (`./gradlew compileJava`, unit tests). Tree-mutating verbs stay forbidden.
- **Generator runs** (`/codegen-build` briefings) execute the catalogued command verbatim.
