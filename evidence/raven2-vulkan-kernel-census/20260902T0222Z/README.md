# 20260902T0222Z: diagnostic calibration on the v2 instrument

```text
measurement_status=diagnostic
instrument_version=pipeline-census-v2-pre-review
gate_head=7e9e09b2cb643bb009d756f23666447c55a10401
merge_authority=no
ownership_authority=no
```

The chain gated head 7e9e09b (accepted, `chain.log`), built the v2 census
preset from a fresh candidate tree (`census-build-artifact-manifest.tsv`:
`instrumentation pipeline-census-v2`, `serving_eligible no`,
`checkpoint_semantics natural-boundary-v1`), and ran
`P I0 I0 P I0 I1 I1 I0 S` on the 2B. Every served arm refused at launch on
`descriptor-backed model path requires approved model identity`
(`arms/01-P/runner.stderr`): the served harness pins the model through a
descriptor and derives the approved identity from `QWEN_MODEL_ARTIFACTS`,
which the runner never passed. Both registered controls therefore read
`incomplete` (`summary.tsv`), and no census, bracket, overlap, or
ownership figure exists from this run.

The S arm completed through the standalone launch the v2 runner used:
64 predicted tokens in 25347.675 ms, 2.485 tok/s under the serialized
diagnostic profile, 66 `Vulkan Timings:` blocks in `arms/09-S/perf-logger.log`
(`arms/09-S/response.json`, `arms/09-S/request-window.tsv`). That arm ran
outside the guarded harness and is an inventory rather than a comparator.

The 5 ms clock sidecar ran beside every arm (`sidecar-footers.tsv`): the
S arm's footer reads 6134 samples at an achieved period of 5000144 ns and
a mean sample cost of 614128 ns, and `pp_dpm_fclk` read `unavailable` on
every sample because the SMU10 kernel path exposes that file empty. The
v2 column names in `arms/09-S/clock-sidecar.tsv` (`fclk_mhz`, `mclk_mhz`)
predate the surface-naming correction.

Files carry `$HOME` for the home prefix and `qwen-laptop` for the host.
