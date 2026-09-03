# Decode priority under manual-gfx1100-fclk933: nice 19 against nice 0 on core 0

```text
measurement_status=diagnostic
engine_clock=manual sclk_level=2 mclk_level=2 delivered_gfx_mhz=1100 fclk_mhz=933
bench=llama-bench (census v7 build) -m qwen38-2b-distill -p 0 -n 64 -r 5 -ngl 99 -t 2
placement=taskset -c 0, the inference core the appliance pins its server to
tenants=qemu-system-x86_64 at nice 0 on cores 0,1 (48.7% CPU at probe start), ksmd at nice 5 on core 0
```

The calibration in `../../20260902T2124Z/` refused one arm on a 10%
coverage loss whose decode rate fell 19% while the clock held, and the
appliance runs its server at nice 19 on core 0 (`radv-low-priority-env.sh`)
where two KVM vCPU threads at nice 0 and the KSM scanner at nice 5 also run.
Under CFS a nice-19 thread holds weight 15 against 1024 for nice 0, so a
runnable vCPU on core 0 leaves the server about 1.4% of the core until the
vCPU sleeps. This probe asks whether the server's own priority is the
scatter mechanism: eleven llama-bench arms in the order N19 N0 N0 N19 N19 N0
N0 N19 N0 N0 N19, each five repetitions of 64 tokens, with a 100 ms sampler
on core 1 recording delivered graphics clock, `load1`, and GPU busy.

## Result

| arm | nice | tok/s | within-arm sd | load1 max | sampler max gap ms |
| --- | ---: | ---: | ---: | ---: | ---: |
| N19-1 | 19 | 9.64 | 0.11 | 3.02 | 121 |
| N0-1 | 0 | 9.74 | 0.05 | 2.31 | 119 |
| N0-2 | 0 | 9.52 | 0.17 | 2.43 | 188 |
| N19-2 | 19 | 9.19 | 0.17 | 3.50 | 136 |
| N19-3 | 19 | 9.08 | 0.30 | 3.69 | 153 |
| N0-3 | 0 | 9.32 | 0.20 | 3.90 | 255 |
| N0-4 | 0 | 9.32 | 0.18 | 4.33 | 208 |
| N19-3b | 19 | 9.11 | 0.36 | 4.08 | 159 |
| N0-5 | 0 | 9.26 | 0.37 | 3.53 | 307 |
| N0-6 | 0 | 9.61 | 0.19 | 3.15 | 163 |
| N19-4 | 19 | 9.61 | 0.21 | 2.75 | 150 |

Every arm delivered 1100 MHz on every busy sample. Adjacent pairs, nice 0
over nice 19: +0.0104, +0.0359, +0.0264, +0.0231, +0.0165, +0.0000; mean
+0.0187, sd 0.0125, nominal 95% interval [+0.0056, +0.0318] over six pairs.
Nice 0 is faster by about 2% on this bench and the interval excludes zero
narrowly.

The rate follows host load more than it follows priority. The three arms at
or above 9.6 tok/s all ran under `load1` at or below 3.02 and split two to
one across the priorities; the four arms at or below 9.2 ran under 3.5 to
4.1. Under nice 0 the rate still slid from 9.74 to 9.26 as `load1` rose from
2.3 to 3.5, so the mechanism that orders the arms is one a higher priority
does not remove. The two cores share one L3 and one DDR4 controller with the
guest's two vCPU threads, and decode at 9.5 tok/s streams about 12 GB/s of
weights, so shared memory bandwidth and cache is the remaining candidate,
and its falsifier is one labelled diagnostic with the guest paused: a paired
sd that stays near 4% under a paused guest refutes it, and a sd that falls
to the within-arm 1 to 2% confirms it. That diagnostic characterizes a
machine the appliance is not, so it decides nothing about promotion and is
run only to name the mechanism.

llama-bench holds a shorter host critical path than the served decode
(no sampling, no HTTP), so the 2% here bounds the priority effect on the
served path from below. The served-path measurement needs the server's
priority as a contract field rather than a constant, since
`census-arm-lib.sh` requires `server_nice=19` against the scoreboard
receipt and `qwen-webui-session.sh` admits readiness only at nice 19.

## Files

| file | content |
| --- | --- |
| `probe.log` | the run's own summary lines |
| `nice-probe.sh` | the script as run |
| `N*.md` | llama-bench markdown output per arm |
| `N*.samples` | 100 ms sampler: monotonic ns, delivered GFX MHz, load1, GPU busy percent |
