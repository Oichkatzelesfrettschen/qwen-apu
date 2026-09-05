# The frontier

The remaining program as a finite set of questions, each with the evidence it
already has, the one action left, the device access that action needs, the
condition that ends it in either direction, and where the answer lands. The
records this file cites carry the content; this file carries the boundaries.
A milestone leaves this file when its result location holds the answer.

The order is availability first, then the registered measurements, then the
attributions those measurements need, then the candidate they select.
Workstation work that needs no device runs beside that order. ROCm, new model
admissions, further power-policy experiments, and resident-server designs are
outside it.

## Router recovery after a cancelled load

- Question: does a request that arrives while a cancelled child load is in
  flight terminate correctly once that child is up?
- Evidence: `evidence/deployment-epochs/main-e909cfc-r1/README.md` records
  the 700 s wait on the appliance; `evidence/router-cancelled-load/` retains
  the deterministic workstation reproduction, the trace locating the slot
  hand-off that had no sender, and the repaired run under
  `patches/llama-router-cancelled-load-idle.patch`.
- Remaining: one bounded appliance confirmation on the exact patched
  executable, then promotion of the row to `production`.
- Device: one window, shaders unchanged.
- Ends when: the two-request sequence recovers with no third request, router
  restart, device reset, or model-stack change; or the patched build fails the
  sequence, which returns the diagnosis to the trace.
- Result: `evidence/router-cancelled-load/`.

## Verification with every row

- Question: does `remote/verify-lan-site.sh` write a terminal row for every
  check, name its checkpoint subject, and measure a cold prefix?
- Evidence: `remote/test-verify-lan-site.sh` proves the subject rule, the
  per-run nonce against a warm fixture, the terminal row against a router that
  never answers, and the rows an interrupted run leaves.
- Remaining: none on the workstation; the appliance run is the qualification
  below.
- Result: the verifier's own test in the repository gate.

## Qualified baseline

- Question: is the deployed baseline available, verified in every row, and
  recoverable?
- Evidence: `evidence/deployment-epochs/main-e909cfc-r1/` is the deployment
  epoch; its rollback target `main-f50d631-r1` names predecessor paths the
  migration removed and is historical evidence rather than a recovery target.
- Remaining: the LAN matrix with every row on the confirmed router build, a
  root-compatible rollback bundle proven by one activation and one rollback,
  and the qualified-epoch record.
- Device: the same window as the router confirmation.
- Ends when: every verifier row passes and rollback resolves and launches; or
  a row fails, which names the next repair.
- Result: `evidence/deployment-epochs/<bundle>/` with a `qualified_epoch`
  receipt.

## The registered 2B composition

- Question: does `e4-scale-licm/4` close the fixed-64 2B target, and does it
  beat the production series by the paired rule?
- Evidence: `evidence/q4k-scale-decode/target-closure-preregistration.md`
  registers the control (production series, no E4), the candidate (E4 with
  scale-word-select and loop LICM), the sequence (a priming arm and two
  mirrored quadruples), the operating point (nice 19 server, stock package
  limits, standing guest, KSM as found, manual 1100/933), and both verdicts.
- Remaining: run it as written, with every arm and its identity record.
- Device: one window.
- Ends when: the lower endpoint of the nominal two-sided 95% t interval over
  candidate absolute rate is above 10 tok/s (closed), the interval spans 10
  (unresolved), or lies below it (negative); promotion is the separate +5%
  paired verdict. An incomplete run stays incomplete. A pass establishes the
  fixed-64 request under the named operating point and no other depth and no
  new serving default.
- Result: `evidence/q4k-scale-decode/`.

## The 4B null

- Question: why did the composed Q4_K candidate move nothing on the 4B?
- Evidence: the E4 series under `evidence/raven2-vulkan-kernel-census/e4/`
  and the served comparisons there.
- Remaining: one attribution census arm on the 4B carrying executed modules
  and specializations, Q4_K and Q6_K ownership, and whole-graph timing.
- Device: one window, after the 2B composition.
- Ends when: exactly one conclusion is supported: the modified path was not
  selected; selected with no local improvement on this shape; improved locally
  with no graph effect; or its graph ownership is too small to matter. The
  larger 4B program then returns to temporal amortization as experiments.
- Result: `evidence/raven2-vulkan-kernel-census/` beside the 2B records.

## The 0.8B attribution

- Question: which Q8_0 shapes own the 0.8B decode and how much time sits
  outside them?
- Evidence: `evidence/q8-attribution/` carries the pipeline selection, the
  shapes, and the fixed-cost decomposition from the workstation; the served
  0.8B census text there is the one device read.
- Remaining: one attribution arm on the device, with a bridge control only
  where instrument, executable, or contract differs materially from the
  retained 2B subject.
- Device: one window, after the 4B.
- Ends when: the executed-path and time-ownership record is retained with its
  coverage limits. The Q4_K program's priorities do not transfer; the first
  Q8-specific experiment is chosen from this record.
- Result: `evidence/q8-attribution/`.

## The census instrument's unresolved controls

- Question: which calibration controls remain statistically unresolved?
- Evidence: `evidence/raven2-vulkan-kernel-census/README.md` and the retained
  calibration directories; the E4 comparison used the instrument on both sides
  and establishes a local effect, and no universal overhead bound.
- Remaining: enumerate each unaccepted control with its claim and interval and
  close it as accepted or recorded-unresolved.
- Device: none.
- Ends when: the enumeration is retained. An unresolved bound erases no valid
  local comparison.
- Result: `evidence/raven2-vulkan-kernel-census/README.md`.

## Mission 1 reuse

- Question: does the calibration machinery reuse unchanged artifacts and
  invalidate changed ones?
- Evidence: `evidence/raven2-vulkan-kernel-census/state-preserving-campaign.md`
  and `evidence/raven2-vulkan-kernel-census/replay-corpus/`.
- Remaining: one acceptance check on a disposable state root: an unchanged
  input closure reuses admitted artifacts, a reader-only change reprocesses
  retained data with no device work, and a changed executable, shader pack, or
  execution setting invalidates the corresponding receipt. Production state,
  the deployment selector, and authorization state stay untouched.
- Device: none.
- Ends when: the three outcomes are retained. Dual-resident servers, wider
  cache sharing, and scheduling experiments are deferred extensions.
- Result: `evidence/raven2-vulkan-kernel-census/replay-corpus/`.

## E5: the standard packed dot through OpSDotKHR and ACO

- Question: does an integer Q4_K x Q8_1 mat-vec through the standard packed
  dot beat the admitted floating path once activation quantization is counted?
- Evidence: `evidence/raven2-vulkan-kernel-census/e5/README.md` orders E5-M
  (manual int24, the negative control), E5-S0 (stock ACO), and E5-S1
  (target-aware ACO) and withholds a performance conclusion against the
  floating baseline.
- Remaining: workstation input closure first, then on the device in registered
  order: pipeline selection and executed ISA, integer-lowering arithmetic,
  activation-quantization numerics, timing of quantizer plus consumer together.
- Device: one window, after the attributions, only where the workstation
  closure holds.
- Ends when: a rung is admitted or rejected; the first decisive falsifier
  stops the ladder and a negative result closes the candidate.
- Result: `evidence/raven2-vulkan-kernel-census/e5/`.

## Runtime-root residuals

- Question: is the runtime root self-describing and protected?
- Evidence: `evidence/runtime-root/README.md` and the migration record in
  `evidence/deployment-epochs/main-e909cfc-r1/README.md`.
- Remaining: marker bound to the checkout, helper binaries and image
  parameters under the root, the inventory naming the served executable, the
  verify split, the hashed wheelhouse, and refusal of `git clean -x` and
  worktree removal on a checkout carrying the marker. Marker protection lands
  before any further destructive root operation.
- Device: none for the code; one launch for the served-executable inventory.
- Ends when: each item is a gated test.
- Result: `evidence/runtime-root/`.
