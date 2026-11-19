# Unattended mode

Read this when your args start with `--unattended`. You run headless, in a fresh session, for a
loop that parks the ticket at the next human gate. This file overrides every "ask", "wait for
approval" and "ask right then" in the skill you were invoked as. Protocol version: `protocol=1`.

## Rules

1. **Never ask, never wait.** Never call `AskUserQuestion`. Stop at the first human gate instead
   of crossing it.
2. **Read the ticket.** The next arg is the absolute path of the ticket file (it may arrive wrapped
   in double quotes; drop them); the file name without `.md` is the ID.
   - The task is the first `# ` line (the title) plus the body above the first `<!-- sherpa:`
     marker.
   - Output of earlier layers lives in marker sections, `<!-- sherpa:<name> -->` to
     `<!-- /sherpa:<name> -->`, under a heading. Read them as if they were in your context. A plan
     section is approved.
   - Section map (layer → marker name / heading): frame → `frame` / `## Frame`; shape → `plan` /
     `## Plan`; implement → `implementation` / `## Implementation`; analyze → `analysis` /
     `## Analysis`; a failed earlier run → `last-run` / `## Last run`.
   - `## Answers` holds the user's replies, all rounds. It is theirs.
3. **Resume, never start over.** If the ticket already has a section for your own layer, continue
   it: keep its discovery, apply every answer, keep unanswered questions with their ids, number
   new questions after the highest id, and re-run the layer's reviewers.
4. **Per layer.**
   - Frame: the task is the ticket.
   - Shape: the problem is the frame section. If the ticket already has an implementation section,
     the answers are code-review direction: the new plan covers only what is still missing from
     the worktree's code. Earlier commits are the starting point, never rebuilt.
   - Implement: build the whole plan section in one run, as it does interactively.
   - Analyze: the target is the local branch in cwd.
5. **Leave no marks.** Never edit the ticket file (the loop writes it). Never push. Never add marks
   (trailers, tags) to commits.
6. **End with a handoff.** Your final message is parsed. Its first line is
   `STATUS: <DONE|GATE|FAILED> protocol=1`. For `GATE` it also carries
   `actionNeeded=<answers|approval|review|decision>` on that line:
   - `answers` whenever any `Q<n>:` question is open;
   - otherwise frame or shape → `approval`, implement → `review`, analyze → `decision`.

   Then the full output, written for a reader with no other context (implement: each step, its
   result and its commit SHA). For `GATE` and `FAILED`, end with `## Waiting on you`: numbered
   `Q<n>:` items, or the approval needed.
7. **Which status.** Frame, shape and implement print `GATE` or `FAILED` only (after implement,
   the user reviews the code). Analyze prints `DONE` on a verdict of `APPROVE` only;
   `APPROVE WITH NITS` and `REQUEST CHANGES` print `GATE`.
