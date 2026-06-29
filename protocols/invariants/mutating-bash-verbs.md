# Mutating Bash Verbs

## The list

`git commit/push/reset/checkout/restore/clean/rm/mv/rebase` + `npm install` + `>` redirection.

## Read-only roles

`acceptance-reviewer`, `quality-reviewer`, `plan-reviewer`, `spec-reviewer`, code-review personas, and scout agents: Bash is inspection only — `git status`, `git diff`, `git log`, `git show`, `git blame`, `grep`, `cat`, `ls`, `rg`. Any listed verb is forbidden.

## Exceptions (intentional)

- **`builder`** runs its own commits and any commands the step requires.
