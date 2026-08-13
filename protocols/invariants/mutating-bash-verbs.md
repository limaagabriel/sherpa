# Mutating Bash Verbs

## The list

`git commit/push/reset/checkout/restore/clean/rm/mv/rebase` + `npm install` + `>` redirection.

## Read-only roles

`acceptance-reviewer`, `quality-reviewer`, `decompose-reviewer`, `frame-reviewer`, code-review personas, scout agents, `shape-generator`, and `shape-reviewer`: Bash is inspection only — `git status`, `git diff`, `git log`, `git show`, `git blame`, `grep`, `cat`, `ls`, `rg`. Any listed verb is forbidden.

## Exceptions (intentional)

- **`step-builder`** runs its own commits and any commands the step requires.
