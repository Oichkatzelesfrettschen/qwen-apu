# Change-surface CI selection

## Failure mechanism

Pull request 247 changed only CI gate infrastructure, but marking the pull
request ready for review bypassed its bounded route and executed all 155
repository cells. GitHub Actions run `34488259430` reports
`pull_request_gate=full reason=pull_request_is_merge_ready`, followed by
`cells_run=155 cells_reused=0`; the job lasted 31 minutes 36 seconds. The
changed input did not cause that denominator. Pull request lifecycle state did.

Pull request 248 exposed a second form of the same routing error. Its draft
changed README prose, the evidence manifest, and a new sanitized evidence
directory. The old classifier assigned `evidence/SHA256SUMS` to gate
infrastructure, recognized no general evidence surface, and therefore returned
`changed_path_requires_exhaustive_gate`. A new evidence directory consequently
required a route-specific source edit or all 155 cells even though the UI,
runtime, telemetry, and gate-cell implementations were unchanged.

## Correction

`remote/run-pull-request-gate.py` now derives a set of consuming surfaces for
every changed path. The selected command list is the deduplicated union for
those surfaces. Evidence is a general surface, and its manifest is an evidence
integrity companion. Documentation, Web UI, browser preflight, Q8 sampler
attribution, CI routing, and gate infrastructure remain separately named.
Unknown executable and runtime paths still select the exhaustive gate.

The workflow sends opened, synchronized, and reopened pull requests through the
same classifier. Marking an already checked commit ready for review changes no
tree input and starts no duplicate job.
`remote/merged-pr-gate-reuse.py` accepts an exact-tree successful PR source as
either `targeted` or `exhaustive`. Main promotes a cache only for an exhaustive
source; targeted reuse retains the source receipt and claims no full-gate
artifact.

## Focused proof

`remote/test-run-pull-request-gate.py` binds the exact six paths in pull request
248 to `documentation+evidence`. Its selected-command assertions require the
manifest and text checks and exclude appliance-path, feature-roster, Web UI,
telemetry, and browser-driver checks. Additional fixtures cover arbitrary new
evidence directories, unions with gate infrastructure, browser preflight, Q8,
and Web UI, traversal refusal, and exhaustive fallback for an unclassified
runtime launcher.

`remote/test-merged-pr-gate-reuse.py` requires the gate step itself to complete,
classifies a successful cache-save step as `exhaustive`, classifies a skipped
cache-save step as `targeted`, and refuses every other shape. Both kinds retain
the exact pull-request head tree, merge tree, workflow run, run attempt, and
successful clone-local job identity already required by the reuse proof.

## Boundaries and falsifiers

The change alters CI selection only. The change contacts no appliance, starts
no browser or model, and changes no serving artifact. A changed path that maps
to no reviewed surface continues to request the full repository gate.

The correction is falsified if the pull request 248 path set selects a Web UI,
browser, Q8, runtime, or exhaustive check; if draft state changes the selected
commands; if a targeted PR source causes cache promotion; if an exhaustive
source without its cache artifact avoids the full fallback; or if an exact-tree
mismatch reuses any PR result.
