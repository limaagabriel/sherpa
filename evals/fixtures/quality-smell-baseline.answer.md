# Answer key — quality-smell-baseline

Do NOT forward this file to the reviewer under test.

## Planted defect — Feature Envy (Smell baseline)
`src/cart.js:8-13`'s `loyaltyDiscount()` method belongs to `Cart`, but every line inside it reaches
into `this.customer.membership` — `tier`, `yearsActive`, `avgAnnualSpend` — and never touches `Cart`'s
own state (`this.items` isn't referenced at all). The method is more interested in `customer`'s data
than in `Cart`'s own; it should live on the membership/customer side (e.g.
`customer.membership.loyaltyDiscount()`), not on `Cart`.

This is a clean textbook Feature Envy: it does not overlap Minimality (nothing here is unused,
premature, or speculative — the method is exercised by the accompanying test) or Architecture (no
scattered edits, no unrelated responsibilities crammed into one file, no inheritance involved). It
is also not a Correctness, Security, Performance, or Tests+regression issue — the arithmetic is
right and the test passes against the diff as written.

Expected attack category: **Smell baseline** (Feature Envy).
Expected quote: the `loyaltyDiscount()` method body in `src/cart.js`, specifically the three lines
that read `this.customer.membership.tier`, `this.customer.membership.yearsActive`, and
`this.customer.membership.avgAnnualSpend` while never using `this.items`.

## Judging
A catch counts if the reviewer's FIX/BLOCK list names the method reaching into another object's data
more than its own (however worded — "Feature Envy", "reaches into customer more than its own state",
"should live on customer/membership instead of Cart" all count), per EVALS.md's Pass criterion: it
must quote the offending method (or the specific lines above) and tag it with "Smell baseline",
"Feature Envy", or a reasonably equivalent category (e.g. "misplaced responsibility" tied to the same
quoted lines). A "Message Chains" or "Law of Demeter" catch that quotes the same three lines
(`this.customer.membership.tier`, `yearsActive`, `avgAnnualSpend`) also counts as a pass, since
Message Chains is a live adjacent Smell-baseline category over the identical evidence. A PASS verdict,
or a FIX list that doesn't mention this specific method, fails the fixture. A catch that instead
miscategorizes the finding under Architecture or Minimality — without quoting the right lines — does
not count as a pass for this fixture, since the whole point is that this defect does not fit those
two bullets.
