# Answer key — step-diff-planted-bug

Do NOT forward this file to the reviewer under test.

## Planted defect — off-by-one boundary bug (Correctness)
`src/paginate.js`'s filter condition is `i >= start && i <= end`, but `end` is already
exclusive (`start + pageSize`) — using `<=` includes one extra element past the intended page
boundary. For `paginate(items, 4, 0)`, `start=0, end=4`, and `i <= 4` includes index 4, returning
5 items (`[0,1,2,3,4]`) instead of the intended 4 (`[0,1,2,3]`).

The accompanying test (`src/paginate.test.js`) asserts the CORRECT expected output
(`[0,1,2,3]`) and would FAIL if actually run against the buggy implementation — a reviewer that
runs the test (permitted — quality-reviewer's Bash is for inspection) will see a failing test; a
reviewer that reads the boundary condition carefully will spot the fencepost error without
running anything.

Expected attack category: **Correctness** (edge case / off-by-one), and/or **Tests + regression**
(a reviewer who runs the test and reports the failure also counts as a catch).
Expected quote: the line `return items.filter((_, i) => i >= start && i <= end);`, specifically
the `i <= end` clause.

## Judging
A catch counts if the reviewer's FIX/BLOCK list names the off-by-one (however worded — "off-by-one",
"boundary", "fencepost", "returns one extra item" all count) OR reports that the given test fails
against the diff. A PASS verdict, or a FIX list that doesn't mention this specific defect, fails
the fixture.
