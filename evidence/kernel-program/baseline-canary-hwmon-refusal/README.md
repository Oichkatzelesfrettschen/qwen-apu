# Baseline canary: missing telemetry hwmon binding

The single 2B canary `baseline-2b-single-20260908T0157Z` stopped at its first
instrument failure under source `bb7f5a2a4bacce2f515f9202dc9dc946d9fac8fa`.
The acquisition used `lease-q4k-6b262d93-r1`, executable SHA-256
`510c0420346ffa4f5104d3f2b28117262a0d30b2907dc21c833d38442c3e49af`, and
proved `production/4`, one inference thread, one batch thread, Vulkan0, all
GPU layers and inference nice 19 through the actual process identity.

Readiness took 9070.664 ms. The streamed warmup completed 64 generated tokens;
first content arrived after 541.718 ms. These are retained single observations,
not accepted baseline performance estimates. Zero repeated decode requests ran.
The broker produced 269 samples, each lacking required sensors. Its header
records `hwmon=-`: the runner passed the DRM path but omitted `--hwmon`, which
the broker requires for `freq1_input` and `temp1_input`. The five-second usable
sample deadline refused before the repeated block. The sampler exited 0; the
validator exited 1. Successful sampler termination alone supplies no admission.

The window returned 1, restored automatic DPM selection, retained KSM run=1,
and held stock power. Before/after bundle links and runtime-manifest identity
matched. Final checks returned health 200, unauthenticated models 401 and
authenticated models 200. The standing QEMU PID remained present in the final
observation. The operator stop rule held the 0.8B/4B anchors and kernel windows.
`diagnostic-summary.tsv` states the five outcomes separately from the raw
terminal records; the diagnostic summary carries no accepted rate.

The follow-up runner resolves one amdgpu hwmon directory under the selected DRM
device, requires readable delivered-clock and temperature surfaces before
acquisition, records that directory and passes it to the broker. The baseline
fixture now executes the compiled broker against synthetic DRM/hwmon files and
checks actual retained sensor values. Absent, ambiguous, incomplete and foreign
hwmon selections refuse before launch. A configured hwmon search root still
requires the resolved sensor directory to belong to the selected DRM device.
The follow-up repair has no device measurement in this record.

The complete raw window remains under `.runtime/results/` on the appliance and
in the workstation's runtime result mirror. The raw acquisition preserves the
executed runner, reader, lease, sampler, validator and runtime source archive.
This directory retains a reviewed diagnostic subset through
`remote/retain-acquisition.sh`; `transformation.tsv` binds original and sanitized
bytes. The sanitized subset is a failure report, not a replay-complete accepted
acquisition. Acquisition identity and later reader identity remain separate.
