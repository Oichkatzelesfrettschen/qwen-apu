---
name: qwen-serving-epoch-lease
description: "The appliance serves lease-q4k-6b262d93-r1 (server sha256 510c0420...) with main-2c1fa9de-r1 as recovery; the rule is preserve the working service until an authorized replacement passes admission, and activate-deployment-bundle.sh rollback swaps links without restarting the server"
metadata: 
  node_type: memory
  type: project
  originSessionId: 22147316-dacf-465f-ac92-4dde5be63047
  modified: 2026-09-07T19:43:25.795Z
---

On 2026-09-07 the workload-lease patch was promoted to the ten-member
production series and served as epoch `lease-q4k-6b262d93-r1` (server
SHA-256 `510c0420...`, replacing `92015c14...`). The operator's decision:
keep it serving, keep `main-2c1fa9de-r1` verified as the recovery target, and
read any earlier "leave main-2c1fa9de-r1 serving" note as the general rule
"preserve the working service until an authorized replacement passes its
admission checks", not as a permanent prohibition.

**Why:** two instructions named different epochs; the later, authorized task
(#35) governs. Rollback triggers are release defects only: executable/policy
mismatch, loss of the auth boundary, a reproducible lease deadlock, failure to
release ownership, a new GPU hazard, or a serving regression attributable to
the deployment. A failed doc, format, or unrelated fixture check is not one.

**How to apply:** no activation, rollback, rebuild, or new device arm while an
integration queue drains; merge never implies rebuild or activation. One
landing owner controls the queue and deploys. `activate-deployment-bundle.sh
rollback` only verifies and swaps links; a real rollback is inspect the
previous bundle, then teardown, activate, relaunch, and verify the running
executable. Related: [[qwen-4b-row-scoped-release]],
[[flock-does-not-survive-bash-calls]].
