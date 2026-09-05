# Reuse acceptance: the three outcomes the calibration machinery must show

The state-preserving campaign (`../state-preserving-campaign.md`) is closed as
an implemented baseline on one check rather than on a further feature: an
unchanged acquisition input closure reuses its admitted artifacts, a
reader-only change reprocesses retained data with no device work, and a
changed executable invalidates the receipt it was closed over. The check runs
on the workstation against disposable state -- `remote/test-run-raven2-vulkan-kernel-census.sh`
builds every prior calibration under its own temporary directory, drives the
runner with fake servers and a stub broker, and reads no production
`.runtime/state`, deployment selector, or authorization state -- so it is a
property of the code rather than of a device run.

| outcome | case | what it proves |
| --- | --- | --- |
| unchanged closure reuses | `brick_reuse_zero_arms` | four bricks whose receipts are bound to the root and whose closures equal this run's are echoed as `reused` at their own slots, the warmup is skipped, no arm directory is created, and the calibration root over the copied receipts is the terminal state's own |
| reader-only change reprocesses retained bytes | `brick_revalidation_artifact_moved`, `brick_revalidation_reader_refused`, `brick_revalidation_census_refused`, `brick_revalidation_bare_receipts`, `brick_reuse_chained` | every reuse rehashes the retained records against the receipt and reruns the current readers over those bytes; a record that moved, a reader that refuses, or a brick that retained nothing is measured again while the other bricks are reused, and a second generation resolves its records through the first's `reused_from` chain |
| changed executable invalidates | `brick_closure_binary_changed` | a receipt closed over another instrumented server is genuine and bound to its root, and the runner refuses it by name (`census_brick_reuse=closure_changed brick=C2 recorded=... current=...`), reuses the three bricks whose closure held (`bricks=C0 C1 C3`), and measures the changed brick's slots again |
| contract change invalidates | `reuse_foreign_contract`, `reuse_root_foreign_contract` | a directory whose `inputs.tsv` or root names another acquisition contract is refused whole |
| tampered receipt invalidates | `brick_receipt_unbound` | a receipt whose bytes moved since the root was written is refused ahead of its closure |

The retained run: `remote/test-run-raven2-vulkan-kernel-census.sh` on the
workstation, 55 runner cases and every brick case above accepted, exit 0.
The closure-change line and its case landed with this file; the other cases
were retained ahead of it and are cited rather than re-proven.

What this closes and leaves. The machinery reuses what it can prove and
re-measures what it cannot, which is the whole baseline claim. Dual-resident
servers, wider cache sharing across campaigns, and scheduling experiments
inside one lease are deferred extensions and prerequisites of nothing.
