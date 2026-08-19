**Task-initiating request (verbatim):** "Our CI on-call rotation is drowning in flaky-test noise —
figure out what's actually going on and how to fix it."

## Problem contract
**Who:** CI on-call engineers rotating weekly on the platform team.
**Capability:** merge a passing PR without manually re-running pipelines to tell a real failure
from noise.
**Obstacle:** the integration suite retries each transiently-failing test up to 3 times before
marking the run red, so a real regression and a flaky test both show the same "red after retries"
signal to the on-call engineer.
**Costs:** on-call spends roughly 2 hours/week re-running green-after-retry pipelines by hand to
confirm a failure is real; one true regression shipped to production last quarter after being
buried in retry noise (incident #4021).
**Solved-signal:** flaky-test noise self-heals without on-call needing to re-run pipelines.

## Discovery
- **Landmarks:** `ci/retry-wrapper.sh:1` wraps every integration test run with up to 3 retries;
  `ci/results-dashboard.md` shows retry counts per run but doesn't surface them to the on-call view.
- **Precedent:** incident #4021 postmortem (linked internally) names retry-masked flakiness as the
  root cause of a missed regression.
- **Constraints:** the retry wrapper is shared by two other pipelines outside CI on-call's control;
  changing its default retry count needs sign-off from the build-tools team.
- **Tests:** none covering the retry-wrapper's own behavior today.
- **Gaps:** no existing signal distinguishes "passed on retry" from "passed clean" in the on-call
  dashboard.
- **Confidence:** high on the obstacle and costs (backed by the incident + the dashboard gap);
  medium on solution direction (not yet explored — that's `/shape`'s job).

## Open questions
- Does on-call want a dashboard change (surface retry counts) or a policy change (stop retrying
  certain test classes)? Not yet resolved — a real framing tradeoff, not a discoverable fact.
