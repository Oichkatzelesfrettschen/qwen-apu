---
name: qwen-2b-target-closure-result
description: "The registered 2B C K K C run executed 2026-09-05: closed once, unresolved on the repeat; paired verdict re-read under the median marker rule is unresolved twice (+5.28% and +5.47%, lower endpoints below +5%); series identity and denominator receipt must match the promoted ledger"
metadata: 
  node_type: memory
  type: project
  originSessionId: 22147316-dacf-465f-ac92-4dde5be63047
  modified: 2026-09-05T15:45:54.201Z
---

`evidence/q4k-scale-decode/target-closure-20260905/` retains two whole runs
of the registration: run 1 candidate arms 10.062/10.170/10.093/10.207 tok/s
(closed, interval [10.026, 10.240]); run 2 9.811/10.110/10.211/10.308
(unresolved, [9.768, 10.452]). Each run lost one control arm to the
sidecar's widest-gap `dpm_marker_cadence` rule. That rule was a coverage
double count (telemetry-broker.c refreshes DPM every tenth tick and re-bases
a missed deadline, so one wide marker gap is hold-off `gaps`/`window_lost`
already bound) and was re-registered over the median gap on 2026-09-05
(branch sidecar-marker-stride). `remote/reread-served-ab-sidecar.sh` re-read
both runs: four pairs each, +5.28% [+3.61, +6.94] and +5.47% [+1.92, +9.01],
unresolved twice against the +5% one-sided bound (`run1/reread/`,
`run2/reread/`). No serving default moves; the gain is near the bound and a
third run at four replicates resolves it only if scatter halves.

Two prerequisites the promotion of the router patch created: (1) the harness
binds both binaries to one `checkpoint_patch_series_sha256`, so the control
is the nine-member production build `70aa78bc` (same bytes as bundle
main-7f8f2ed-r1); (2) the fixed-64 denominator receipt binds the control's
digest, so it was re-measured (`denominator/`, 2B at 9.46 to 9.61).

**How to apply:** the candidate serving build lives at
`.runtime/opt/llama.cpp-q4k-sealed/build-raven2-vulkan-production/` on the
laptop (`83684f3c`, all nine q4k_variants keys); its census twin is built
into `.runtime/opt/llama.cpp-q4k-census/` (stack plus census patch; the
census runner now admits I's candidate_series = P's series + census patch).
Both roles must be unkeyed or both keyed. `sudo -n -v` every 4 minutes keeps
a granted credential alive across a long window.
