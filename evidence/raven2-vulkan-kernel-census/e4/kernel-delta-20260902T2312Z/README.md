# E4 by its Q4_K bracket: 3.93% shorter, union with it, the null held, four of four pairs

```text
measurement_status=diagnostic
acquisition_head=856e88fefc73d9f22108696a4280f64613a06093
reader_head=9c08c941944a4795b9f1826f3e69fcc036778ad5
kernel_delta_verdict=bracket-shortened
control_server_sha256=addcae10bc3683a5700a981e4239061e719ecce92dc11ee436f96337b39f9a22   census v7, series llama-vulkan-pipeline-census.patch
candidate_server_sha256=741a0d7625625ebbc98a37078eadf5ee87a5368d3212a9475a7e7748dcbb5178 census+E4, series llama-vulkan-pipeline-census.patch,llama-vulkan-q4k-activation-group-sums.patch
candidate_series_sha256=42fc4ac11367b5b62024c2fdc17a12ece183625d158f0571012539e3c565387b
instrumentation=pipeline-census-v3 (both)
denominator_server=production bundle 5dd86b90..., receipt fixed64-served-campaign/20260901T2011Z
engine_clock=manual-gfx1100-fclk933, every arm held on every sample
cooldown_timeouts=0  arm_failures=0  sidecar=accepted on all 9 arms  load1 at start 2.30
```

The design is registered in `../kernel-delta-design.md` ahead of this run.
The acquisition tree is 856e88f; the reader that produced the rows below is
9c08c94, re-run over the retained ledgers, and it adds rows the acquisition's
own summary did not carry (union, span, ratio, module identity) without
changing the acquired numbers.

## The result

| role | column | pairs | mean | sd | 95% interval | verdict |
| --- | --- | ---: | ---: | ---: | --- | --- |
| subject Q4_K | exclusive_bracket_ms | 4 | -0.0393 | 0.0002 | [-0.0395, -0.0390] | shortened |
| subject Q4_K | pipeline_bracket_union_ms | 4 | -0.0390 | 0.0002 | [-0.0393, -0.0387] | shortened |
| null Q6_K | exclusive_bracket_ms | 4 | -0.0001 | 0.0004 | [-0.0008, +0.0005] | held |
| null Q6_K | pipeline_bracket_union_ms | 4 | -0.0001 | 0.0004 | [-0.0008, +0.0005] | held |
| graph span | queue_completion_span_ms_per_graph | 4 | -0.0209 | 0.0017 | [-0.0236, -0.0183] | secondary |
| ratio Q4_K/Q6_K | exclusive | 4 | -0.0392 | 0.0002 | [-0.0395, -0.0388] | secondary |

Per pair, Q4_K exclusive: -0.0395, -0.0393, -0.0392, -0.0391. Control arms
3226.7, 3226.0, 3225.9, 3225.7 ms over 63 decode graphs; candidate arms
3099.3, 3099.1, 3099.5, 3099.6 ms. Union moves with exclusive within 0.03
points, so the shortening is an execution envelope and not an overlap
accounting. Q6_K holds on both readings within 0.1%, so the machine did not
move between arms and the candidate did not move its neighbour. The graph
span falls 2.1%, which is the 127 ms the subject lost over 6.3 s of graph
time, and the whole-token rate under instrumentation reads +2.37%
[+1.71, +3.02] over the same four pairs (`summary.tsv`), the first served
E4 comparison to resolve, because these arms met a host at load 2.3 rather
than 5 to 7.

The prediction was a bracket 2 to 10% shorter with 8.1% as the first-order
opportunity; 3.9% is inside the registered window at 48% of the opportunity.
The per-dispatch median moved 207.4 to 199.8 us.

## The executed modules

| role | pipeline 31 executed SPIR-V | ACO ISA |
| --- | --- | --- |
| control (every C arm and W) | `a9ac07dd...` | VALU 882, `v_mac_f32` 248, VGPR 64 (`../../e1/README.md`) |
| candidate (every K arm) | `180da20e...` | VALU 810, `v_mac_f32` 152, VGPR 64, code 6480 (`../e1-isa-e4-20260903T0140Z/isa/031.s`) |
| Q6_K, every arm | `d584d6b4...` | one module |

`module_identity=held`: one subject module per role, the two differ, one
null module across all nine arms. The candidate's executed module was
dumped from the census+E4 binary on the appliance
(`../e1-isa-e4-20260903T0140Z/`) and its pipeline 31 disassembles to the
numbers E4's shader-lab receipt states, VALU 882 to 810 and `v_mac_f32` 248
to 152 with VGPR unchanged, so the E4 source reached execution on the device
the bracket was read from. The executed module is the appliance's own
compile: it carries `SPV_KHR_float_controls` and the subgroup capabilities
the workstation's `e4.spvasm` does not, the same relation E1 found between
the executed baseline and any workstation `glslc`, so the binding is by ISA
count and dump rather than by SPIR-V byte identity.

## Correctness

`response_identity=held` over four pairs: every candidate reply's content
and `predicted_n` equal its control's (`arms/*/response.json`). Two token
sequences can share a string, so the token-id and log-probability witness
(`../kernel-delta-witness-20260903T0148Z/`) reads the ids: held on every
one of 768 generated tokens over six state-carrying prompts, both binaries
exactly self-consistent, and the selected log-probability moved by at most
2.4e-2 nat with a median of 1e-6 to 1e-4. That exceeds the 1e-3 bound the
witness registered, and the two references beside it place the movement:
two builds of the same shader source move nothing
(`../witness-calibration-20260903T0203Z/`), and the CPU backend against
Vulkan moves the argmax on four of six prompts and the log-probabilities by
up to 0.375 (`../witness-cpu-reference-20260903T0220Z/`). E4's movement is
its own reassociation, an order of magnitude inside a backend change the
appliance already serves as equivalent, with no argmax moved.

The correctness state is a matrix rather than one flag:

| property | result |
| --- | --- |
| candidate and control self-repeatability | exact |
| same-semantics independent builds | bit-identical |
| token ids, candidate against control | identical over all 768 observed tokens |
| first token divergence | none |
| selected log-probability identity | refuted, maximum 2.421e-2 nat |
| registered 1e-3 nat bound | refuted and retired without a replacement figure |
| longitudinal amplification over 128 tokens | not observed |
| margin robustness | `../margin-contract-design.md`, judged on a fresh holdout |
| general task-quality non-regression | pending the graded suite |

The CPU reference is context rather than a threshold: it shows E4 is far
smaller than a backend transition and says nothing about whether every
smaller perturbation is acceptable, which is what the margin contract asks.

## Reading

E4 shortens the Q4_K mat-vec by 3.9% of its bracket under this execution
shape, with the null pipeline held, the union agreeing, the executed ISA
matching the receipt, and the reply identical. Under the registered
classification E4 is retained as a composable component and E4b proceeds
on the remaining opportunity; E4 on its own does not reach the 5%
whole-model promotion bound and was not expected to.

## Files

| file | content |
| --- | --- |
| `arms.tsv`, `summary.tsv`, `terminal-state.tsv`, `wall-clock.tsv`, `campaign-inputs.tsv`, `inputs.tsv` | the ledgers the runner wrote |
| `bracket-summary.tsv` | the acquisition-time bracket rows (subject, null, response identity) |
| `clock-state.tsv` | per-arm delivered clock mode, share, temperature, busy, sample count |
| `arms/*/pipeline-ledger-{decode,prefill}.tsv` | every arm's census ledgers, the bracket authority |
| `arms/*/clock-sidecar-verdict.txt`, `arms/*/request-window.tsv`, `arms/*/response.json` | verdict, window, and reply per arm |
| `raw-digests.txt` | SHA-256 of each arm's raw `pipeline-census.tsv`, computed on the appliance |
