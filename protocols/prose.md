# Prose (cross-cutting)

Sherpa's contract for what human-facing prose owes its reader — a referent, a frame, one
composed voice. Phase contracts and skill drivers cite this instead of restating the rule.

## The referent rule
Any label, ID, symbol, or file path in human-facing prose is either introduced at first use —
one clause naming what it is — or replaced with behavior the reader can recognize. Internal
enumeration IDs — a candidate `A1`, an index into a pool the reader never saw — carry no meaning
outside the channel that generated them: bind them to a named roster or don't use them.

> Bad: "C1 absorbs A3's per-token-into-named-set beat."
> Good: "Candidate C1 — merge the definition server-side — absorbs candidate A3's beat that
> applies each token into a named set."

## Verbatim is a quote, not a frame
Where a phase says to surface a reviewer's or subagent's text verbatim
(`protocols/workflow/phases/decompose.md`, `protocols/workflow/phases/implement.md`,
`skills/frame/SKILL.md`, `skills/implement/SKILL.md`), verbatim stays mandatory — a
driver that paraphrases a `BLOCK` launders the finding. The framing duty is added, never
substituted: one line before the quote naming, in the reader's terms, what it blocks. Fidelity
and readability aren't in tension — the quote stays exact; the line around it does the
introducing.

## Compose, don't relay
A driver emits its own artifact shape. A subagent's return value is input to that emission,
never the emission itself. Forwarding it verbatim as the whole message hands the reader a
machine channel's coordinates instead of a composed one. A real `/shape` run once relayed
`shape-reviewer`'s raw return straight to the human — that agent's own contract marks the text
as a machine channel: `agents/shape-reviewer.md:61` "Compact markdown, no preamble, no
narration"; `agents/shape-reviewer.md:93` "The final message is the return value.";
`agents/shape-reviewer.md:20-21` "Your final message IS the return value (the ranked shortlist),
not a human-facing note." The relay named pool bookkeeping IDs (`A1`, `C1`, `C3`) the human had
never seen a pool for, and domain symbols (`frontendTokensValues`, `cssVariableMapping`) never
introduced anywhere in the conversation. A correct critique read as noise and was discarded
unresolved.

## The reader test
This is a TEST, not a suggestion, generalized to any human-facing prose, not only questions:
could the reader act on this without opening the code? No → introduce or translate. Skip the
introduction when the reader already demonstrated familiarity with that surface earlier in the
conversation — re-explaining what they just told you reads as condescending; the failure this
guards against is briefing everything until the ceremony becomes noise the reader learns to skim.
No automated check proves prose readable: a grep for section names or word presence can pass
while the prose stays opaque. This test is applied by a reader, not a gate.
