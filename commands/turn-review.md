---
description: Run the turn-reviewer subagent against the current turn's work. Read-only audit of code diff, process rules, codebase conventions (CLAUDE.md), claim verification, AND the turn's reasoning (root-cause claims, "what code does" conclusions, citations). Returns PASS / WARN / FIX / BLOCK verdict with evidence.
---

Invoke the `turn-reviewer` subagent via the Agent tool with `subagent_type: "turn-reviewer"`.

Audits the whole turn — code diff, process, AND reasoning — in one pass. Trigger for a code audit, reasoning audit, or both.

The subagent has no access to the conversation transcript. It only sees the briefing you write. Anything not passed explicitly is invisible to it.

## Briefing contents

- What the user asked for this conversation
- What you did and claimed
- Specific assertions to audit (test-pass claims, file:line citations, "implemented X" statements)
- Current `git status` and `git diff` summary
- **EVIDENCE PACK** — required when you claim tests ran, builds passed, or any external command succeeded. Without it, the turn-reviewer must BLOCK by rule.
- **CITATIONS** — required when the turn stated a root cause, diagnosis, or "what code does."

### EVIDENCE PACK format

```
EVIDENCE PACK
- Claim: <e.g. "unit tests pass for module X">
  Command: <verbatim shell command run>
  Exit code: <0 / non-zero>
  Output excerpt: <last 20–30 lines, or "BUILD SUCCESSFUL" line + summary>
  Log path: <absolute path if written to file, else "inline above">
```

For file:line citations to audit: list each as `<file>:<line> — <what should be there>`. The turn-reviewer will Read and confirm.

If no evidence is needed: `EVIDENCE PACK: none — no completion claims made this turn`.

### CITATIONS format

```
CONCLUSION: <claim>
EVIDENCE:
- <file:line> — "<exact text or close paraphrase>"
- grep "<pattern>" <scope> → N hits: "<key excerpt>"
- transcript: "<verbatim quote>"
ALTERNATIVES CONSIDERED:
- <alt 1> — ruled out because <reason>
NEXT ACTION: <inform user | Edit <file> | Write <file>>
```

If no conclusions were reached: `NO CONCLUSIONS — this turn was <exploration / listing / clarifying>`.

## Verdict handling

- `PASS` — relay the AUDITED CLAIMS list to the user in one line, then proceed.
- `WARN` — surface each finding as a bullet, then proceed.
- `FIX` — apply each finding's stated mechanical repair, re-invoke the turn-reviewer, repeat until verdict ≠ FIX (cap 3 iterations; treat remaining as BLOCK). Note `turn-reviewer: FIX×N applied` in summary.
- `BLOCK` — surface findings verbatim, state required action, ask user how to proceed. Do not auto-fix.

Mixed FIX + BLOCK → handle as BLOCK; do not auto-fix anything until the user weighs in.
