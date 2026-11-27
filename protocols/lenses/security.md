# Lens: security (triggered)

Runs only when the diff touches one of these:

- Credentials, tokens, secrets, or API keys (processing or storage).
- Authentication or authorization (login, sessions, permission checks, access control).
- Input crossing a trust boundary: user input reaching a query, shell command, file path, template, or deserializer.
- Dependencies: any addition or version change in a lockfile.

## In scope

- **Credentials, authn, authz** need a closer read than an ordinary diff. A missing check, a token logged in plaintext, or an authz check that fails open is a security defect, not a style issue.
- **Trust-boundary input:** injection into queries, shell, paths, templates; unsafe deserialization.
- **New or changed dependencies** may carry malicious packages. Check that it is what it claims: reputable maintainer, plausible usage history, no typosquat-style name close to a well-known package. Treat an unfamiliar new dependency as guilty until shown otherwise.
- **Links and images, especially in docs changes.** A docs-only diff can carry a malicious link or a tracking/exfiltration image.
- **Community contributions.** If the diff comes from an external or community contributor (unfamiliar author, first-time contribution, or the task context says so), review all changes for malicious code before anything else, not just the trigger areas.
- **When in doubt, flag for human appsec review.** You are not a security team. If you cannot rule out a risk from the diff alone, say so and flag it instead of guessing.

## Out of scope

- General bugs, tests → correctness.
- Design and fit → architecture.
- Delivering the stated purpose → acceptance.
- Needless code → minimality.
- Names, comments, style → readability.

## Severity

- `Blocking`: a broken authz check, a credential logged or stored insecurely, a plausibly malicious dependency.
