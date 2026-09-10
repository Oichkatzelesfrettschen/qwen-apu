# Q8 calibration sampler-cost refusal

Calibration acquisition `q8-census-calibration-20260908T175234Z` retained 748
rows for arm `09-P`. Their `sample_cost_ns` values sum to `776,487,760 ns`;
integer floor division yields `1,038,085 ns`, above the registered
`1,000,000 ns` admission limit. The unchanged full-denominator verdict is
`refused`.

`q8-calibration-cost-analysis.md` retains the row distribution, phase
diagnostics, admission interpretation, missing evidence, and bounded claim.
`q8-calibration-sidecar-cost-comparison.md` retains the 22-arm comparison and
the SHA-256 identities of every sidecar input. The `09-P` sidecar SHA-256 is
`7065204fce732625ef469ae9fa27bdc5ccb2f393af7a6258cba16b1fc63b2ad6`.

The request-window diagnostic mean of `427,521 ns` does not replace the full
748-row denominator. Accepted arms contain isolated larger stalls, so the
evidence does not identify a deterministic broker defect, a slow sensor, a
scheduler event, or a Vulkan kernel effect. Q8 calibration and candidate
timing remain withheld until a registered input changes. The unchanged
calibration is not repeated.

The two reports are sanitized derivatives of private analyses under the
declared runtime root. Their bytes required zero substitutions. The
transformation record binds source, derivative, and sanitizer digests.
