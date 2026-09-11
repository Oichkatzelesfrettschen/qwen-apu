---
name: qwen-stage-a-census-state
description: "Stage A pipeline census: PR #104 (v1) merged as substrate; branch stage-a-census-brackets (PR #105) carries the v3 instrument after two falsification reviews; the 7e9e09b chain run is a diagnostic calibration only; a 2B calibration on the exact v3 head must accept all three registered controls before any 0.8B/4B census"
metadata:
  node_type: memory
  type: project
  originSessionId: 22147316-dacf-465f-ac92-4dde5be63047
  modified: 2026-09-03T12:13:48.765Z
---

Branch `stage-a-census-brackets` (worktree
~/worktrees/qwen-apu/stage-a-census-brackets, PR #105) carries the census
instrument. The reviewer refuted v1 (eWait, FNV, predicted serial) and then
refuted eight v2 claims on 2026-09-02: defects validated only on the
selected phase, `share_of_union` as ownership, exit 0 on a refuted
control, unregistered quadruples receiving bounds, P unbound to the
scoreboard, S bypassing the guarded harness, a discarded sidecar status,
and an empty `serving_eligible` value accepted. The v3 state:
format `pipeline-census-v3` with `census_selftest`, `census_emit`, and
`census_close dispatches=`; `clock_gettime(CLOCK_MONOTONIC)`;
`GGML_VK_PIPELINE_CENSUS_DUMP`; summarizer validates every in-window
graph before the phase filter, refuses straddling graphs, recomputes every
aggregate, and reports exclusive/ambiguous/overlap with
`ownership=inconclusive` above 0.05; arms `P-nosidecar P P P-nosidecar P
I0 I0 P I0 I1 I1 I0 S`, three registered controls only, campaign states
accepted (0) / refuted (3) / failed (1); P bound to
`QWEN_CENSUS_PRODUCTION_RECEIPT` (the fixed-64 identity-check.tsv server
row, digest 5dd86b90...82c2); S runs through measure-served-decode.sh
under the `diagnostic` profile with `QWEN_PERF_LOGGER=1` and reads
`server-log-request.slice`; sidecar columns renamed
(`pp_dpm_mclk_surface_mhz`), pinned to CPU 1 at nice 10, validated by
`validate-clock-sidecar.py`; bundle grammar refuses any instrumentation
row and any eligibility value other than exactly `yes`.

The 7e9e09b chain's v2 calibration is retained as
`evidence/raven2-vulkan-kernel-census/20260902T0222Z/` (diagnostic; every
served arm refused at launch because the runner passed no
QWEN_MODEL_ARTIFACTS, fixed in 8f0f206). The third review (2026-09-02)
added QWEN_CENSUS_MODE calibration/attribution (exactly three accepted
controls, zero unclassified), the one-executable-row rule, the scoreboard
denominator binding through models-resolved.tsv and campaign-inputs.tsv,
and the same/cross-pipeline overlap split (commit b4a2735); the bind_server
here-doc substitution had discarded its exit status (fixed there), and the
FCLK allowance used `-s` on a sysfs file, which stat reports at 4096 bytes
(fixed in d30aef5 after the e18b840 calibration failed its P arms on
`sensors=refused`). The d30aef5 gate then failed on a stale
evidence/SHA256SUMS as designed. The fourth review's seven findings landed
in 34de93f: P/I base-build identity (manifest rows plus ELF .comment),
three-state FCLK detection, explicit binding status with nonempty fields,
awk-exact manifest values, sidecar --max-gap-ns 10 ms, a closed diagnostic
profile (four exports, five unsets) with server-effective-env.tsv
retained, and the perf-logger parser reading the leading op token
(get_node_fusion_name prepends fused names; the comma form is the
concurrent logger the profile unsets). `~/stage-a-chain5.sh` gates
34de93f (started 03:53Z), builds `~/src/llama.cpp-census-v5`, runs the
calibration into `~/raven2-kernel-census-*-2b-calibration-v5`; log
`~/stage-a-chain5.log`; its gate accepted 04:15Z; the calibration failed
on sidecar gaps at nice 10 (max 58 ms), the two-context census file, the
f32 GDN chunk-product token column, and the monitor refusing profile
`diagnostic`; retained as evidence/raven2-vulkan-kernel-census/20260902T0426Z
(I1 ledgers: mat-vecs 88.2 of 97.2 ms union, idle+residual 3.4 ms,
conclusive; I1 arms 2.4-2.6% under I0, so the collect bound will likely
refute). R build byte-identical to P (5dd86b90...). Sampler is now nice 19
(mandatory, constant), 10 ms, 20 ms gap bound. Chain6 (59c03c8) retained
as 20260902T0525Z: S ran (2.458 tok/s, 64 blocks), I1 slot 10 accepted
conclusive, but the sampler pinned to core 1 lost ~40 ms/s to the nice-0
guards on that core; I1 2.5%/1.9% under I0. Fixes: sampler confined to
both cores (--cpu 0,1), instrument emission deferred into a 14.3 MiB
binary buffer drained at close (patch sha 53fbe4d6...). Chain7 (e4c148a,
v7) ran 06:17-06:28Z: collect delta 1.1-1.9% (inside 2%), I1 slot 10
conclusive, but every sampled arm refused on gaps: at nice 19 on both
cores the sampler shares CFS slices with the server's nice-19 threads
(3-5 gaps/window, max 60-119 ms, lost 1.2-1.5%), the sidecar itself
costs 1.0-1.4% of decode (pp_dpm sysfs reads 0.82 ms mean through SMU
firmware messages), and the cold opener (6.78 tok/s) sits in pair 1.
Chain8 remedies: warmup arm W, acceptance on window_lost_fraction<=0.02
plus a 100 ms stall bound, the C telemetry broker (remote/telemetry-broker.c,
nice 19 constant) with pp_dpm on a 100 ms channel. Retained as 0617Z.
Integration commit 1878591 (+be25554) landed all of it on the branch:
bricks C0-C3 with receipts and calibration root, acquisition/analysis
contracts, canary mode, wall-clock ledger, await-quiescence.sh, the
broker as default sampler (QWEN_CENSUS_SAMPLER=broker|python, built at
preflight), sparse gate (gate-cell-key.sh, `gate=accepted cells_run
cells_reused root=`), shader pack + binary key caches
(build-cache-keys.sh; 554 s cold -> 15 s reused, ninja needs
.ninja_deps/.ninja_log with mtimes), six named replay cases, the shader
lab (remote/raven2-shader-lab), and E4 SPIR-V results (net -36 of 1173
instructions at constants 64,4,1; E4b ceiling 2.6-5.2% of the body;
E4b-C refuted, reuse factor 1.0). Chain8 (~/stage-a-chain8.sh, log
~/stage-a-chain8.log) gates be25554, reuses the v7 instrument binary,
runs the v8 calibration, then dump-radv-shader-isa.sh for E1 with
GGML_VK_PIPELINE_CENSUS_DUMP into ~/raven2-e1-isa-*. E4b-A agent
(sideplane keyed by activation identity, reuse log) was still running.
Executing Q4_K pipeline is `_f32_f32`, not `_f16_f32`.
Chains 8/9 (be25554, 995ef68) failed the appliance gate on two
pre-existing test races (web-launch lease probe read once; broker bound
with allow_reuse_address False over TIME_WAIT), both fixed. Chain 10
(f5f92d8) completed all 14 arms, sidecar accepted everywhere under the
broker, collect accepted, sidecar/compile "refuted" on two replicates of
opposite sign -> retained as 0819Z; remedy d490a39: verdict on the paired
mean and 95% t-interval over QWEN_CENSUS_REPLICATES (default 4, 25 arms
+ W), states accepted/refuted/unresolved (exit 4), and the quiescence
sclk predicate is "stable step below the highest" (device rests at 400
MHz, step 1 of 3). Chain 11 (~/stage-a-chain11.sh, d490a39) runs the
25-arm calibration then the E1 dump (modules in ~/raven2-e1-isa-*-modules).
E4b-A committed (d173156): sideplane keyed by activation tensor, reuse
1.93 over one 2B graph, 36 of 84 pre-passes single-consumer.
Chain 11 (d490a39): 26 arms all complete, quiescence reached everywhere,
all controls unresolved because in-window sclk dropped 1100 -> ~800 MHz
from slot 10 (rate 9.5 -> 7.2 tok/s, temp falling; cause unattributed,
qemu guest + ksmd active) -> retained 1302Z. Commit b7a3612: clock-state
invariant (arms.tsv sclk_mode_mhz/sclk_share; pair with differing modes
= state-changed; broker host line load1/ksm), and evidence/.../e1/: Q4_K
mat-vec 91.5 VALU per lane/superblock/row (dot 38, unpack 41.25,
address 12 = 13.1%), Q6_K 86.75, VGPR 64, 4 subgroups/SIMD; E4 receipt
isa_changed (VALU 882->810, v_mac 248->152, no VGPR/occupancy change);
NIR does not hoist; scale/dm loads are 16-lane-uniform (E3 SGPR half
closed). Executed module digest a9ac07dd is not reproducible by any
glslc at hand (ACO erases the difference). Chain 12 (b7a3612) reproduced
the regime step (1100 -> 750-857 MHz from slot 10; retained 1417Z);
exact-mode comparability read the sustained pairs as state-changed.
Commits 9944c64 (remote/run-served-binary-ab.sh CONTROL CANDIDATE
MODEL_ID OUT, W C K K C x replicates, promotion bound 5%, E4 patch as
candidate series member; census-arm-lib.sh shared) and 05bd95f (6% sclk
band; regime precondition: sampled warmups 0a..0p until two agree within
band with modal share in [0.05,0.30] -- boost pins 1100 at share
0.55-0.68, sustained hovers at 0.12-0.16; regime_delta per arm). Chain
13 (~/stage-a-chain13.sh, 05bd95f) builds E4 (raven2-vulkan-production,
~/src/llama.cpp-e4), runs the v9 calibration, then the P-vs-E4 served
AB (~/raven2-served-ab-e4-*); prediction: refuted/unresolved at 5%,
mean +3.5 to +4.2%. Chain 13 result: E4 built
(~/src/llama.cpp-e4/build-raven2-vulkan-production/bin/llama-server);
precondition settled at 658 MHz (third regime, 1 s after the 20-min CPU
build; rates 5.7-6.1); 11 arms lost 2.1-6.3% of window at 10 ms; AB
refused (control manifest has no candidate_series row). Retained 1556Z.
Commit 203805d: absent row = empty selection; sampler 20 ms. Chain 14
(~/stage-a-chain14.sh, 203805d, launched 10:51 PDT) = gate,
calibration v9, AB, relaunch. The user wants times in Pacific.
Chain 14 was aborted (reviewers): the clock becomes an explicit control
(power_dpm_force_performance_level high|profile_peak), not a regime to
accommodate. remote/probe-dpm-authority.sh OUT MODEL [BENCH] (needs a
valid `sudo -v` on the laptop; restores auto under trap) ran idle at
18:13Z: writes accepted, tok/s 9.67/9.72/9.75 under auto/high/peak, bapm
parameter -1; invariant not computed (bench_end mark lost to the TERM
race, fixed by a 0.3 s wait + broker drain-on-TERM agent). Post-load
rerun (5 min `yes` on both cores, then the probe) pending. An opus agent
is adding QWEN_CENSUS_ENGINE_CLOCK_POLICY (contract rows
engine_clock_policy / engine_clock_required_mhz /
clock_below_required_fraction 0, validator --required-sclk-mhz ->
clock_invariant=held|violated, one priming warmup under a forced policy).
Decode decomposition check: 97 ms GPU bracket x 1100/658 + 3.4 ms host =
6.04 tok/s predicted vs 5.7-6.1 measured at 658 MHz, so clock scaling
explains the third regime whole.
DPM AUTHORITY RESULT (11:13-11:29 PDT, retained under
evidence/.../dpm-authority/): `high` and `profile_peak` pin hwmon
freq1_input (delivered sclk) at 1100 but drop pp_dpm_mclk (SMU10 fabric
clock) to 400 -> decode 6.3-7.0 tok/s, BELOW auto (6.8-8.2 post-load).
`manual` + `echo 2 > pp_dpm_sclk` delivers 1100 with mclk 933 -> 8.9-9.6
tok/s vs auto 7.9-8.2 after the same CPU load (the cold-boost figure
recovered). pp_dpm_mclk writes are accepted but ineffective (933 either
way). Campaign policy = manual/sclk level 2; invariant over freq1_input
(=1100) and starred mclk (>= 933 floor). pp_dpm_sclk reports the
selected state, not the delivered clock. Restore to auto under trap
always held. bapm=-1 means auto-enabled.
Commit d1dea50: QWEN_CENSUS_ENGINE_CLOCK_POLICY (auto|high|profile_peak|
manual) + QWEN_CENSUS_SCLK_LEVEL (default highest listed) +
QWEN_CENSUS_MCLK_FLOOR_MHZ 933; contract rows engine_clock_*; broker
column 8 sclk_actual_mhz (hwmon freq1_input); validator
--required-sclk-mhz/--required-mclk-mhz -> clock_invariant; arms.tsv
cols 14-15; one priming warmup under forced policy; the broker change
retires every earlier acquisition contract (no brick reuse across it).
Chain 15 (~/stage-a-chain15.sh, d1dea50, 11:59 PDT): gate, calibration
v10 under manual/level 2, P-vs-E4 served AB, E1 dump, relaunch. Needs a
valid sudo timestamp throughout (chain checks at start only).
Chain 15 refused at the sclk level readback race (fixed 239af70: poll
10 s); chain 16 (239af70, 12:56 PDT) running. FCLK: pp_dpm_mclk on
SMU10 is the fabric clock (table 0/400/933/1067); manual + level 3
written is accepted but the firmware holds 933 (1067 in 2/107 samples)
at 9.61 tok/s -- 1067 cannot be commanded; operating point = manual,
GFX 1100 delivered, FCLK 933 floor. Reviewer hypothesis: smu10_hwmgr.c
high/profile_peak request the hard-coded 1200 FCLK peak, the firmware
falls to 400 (falsifier: a kernel patch requesting the table maximum);
DDR4-2400 DIMMs are a separate hardware question (installed Crucial
CT16G4SFD8213 are 2133). ROCm 10: no gfx902 target; RADV primary;
isolated 8-step gfx902 ladder after E4/E1.
Chain 16 (239af70, 12:56-13:40 PDT): first commanded-clock runs. Calib
2011Z: 22/26 arms, GFX 1100 share 1.0 everywhere, FCLK 933, P arms
9.3-9.8 tok/s after the gate; failed on fabric transients (strict
floor), window_lost 2.14%, and the stale broker (invariant read the
DPM column); every cooldown timed out (quiescence sclk predicate vs a
pinned highest step). E4 served A/B 2032Z: 8 arms all at 1100/933, C
9.71/9.74/9.43/9.30 vs K(E4) 9.64/9.41/9.94/9.74 -> served_ab=
unresolved mean +1.5% sd 4.3% ci [-5.3,+8.3] (prediction: refuted/
unresolved at 5%, mean +3.5-4.2). Paired sd 4.3% under pinned clocks =
residual machine scatter (qemu VM at ~41% CPU + ksmd are suspects).
Commit 26cea7f: broker rebuild on source change + clock_source refusal,
fabric floor 1% tolerance, lost bound 3%, fclk-command-research.md
(manual write sends both bounds; high/peak send hard-coded 1200 with no
clamp; 933 hold = firmware refusal vs stale f_actual_hard_min_freq
cache, undecided), CLAUDE.md parts section + evidence/hardware/. In
Commit 803d468 landed all three: --sclk-forced, retention (2011Z,
e4/served-ab-20260902T2032Z), dpm-authority/20260902T2048Z-fclk-rescind.
FCLK conclusion: firmware honors manual hard-min 400 and 933, caps 1067
at 933 (no transient), DPM itself selects 1067 under auto (~50% in one
arm) -> 1067 is not commandable; kernel-patch route inherits the
refusal; contract = GFX 1100 + FCLK level 2 written (933 both bounds).
Chain 17 (803d468, 14:09-14:44 PDT, manual-gfx1100-fclk933): every
sampled arm held 1100/933 on every sample, sclk_source=sclk_actual_mhz.
Census failed on ONE arm (slot 3 P: 7.71 tok/s, 10% samples lost, host
stall); compile control +3.4% sd 3.5% unresolved (0.65% bound needs ~120
replicates at that sd -- bound is unreachable, user must re-register or
change statistic); collect -1.1% CI [-2.15,-0.12] vs 2% nearly closed.
A/B: 3 clean pairs -2.8/+0.2/-5.1% (mean -2.6%), slot 8 refused on one
113 ms gap at 2.08% lost -> stall bound now 250 ms under forced policy,
100 under auto; summarizer prints surviving pairs in detail. E4 served =
~0 +/- 4% over two runs; retained as component; Q4_K bracket needs a
census+E4 build (does not exist). Root scatter mechanism: server nice 19
on core 0 vs qemu vCPUs nice 0 (48% CPU) + ksmd nice 5 on core 0; nice
probe (dpm-authority/20260902T2154Z-nice-probe): nice 0 +1.9% [+0.6,+3.2]
on llama-bench, but rate tracks load1 under both -> guest memory traffic
is the remaining candidate; falsifier = labelled diagnostic with the guest
paused (user's call, Nick's VM). Retained 2124Z, e4/served-ab-2139Z,
nice probe. qwen-laptop appears in 5 source files as the measured-host
pin (pre-existing, flagged). Chain 18 (8e852f8): gate ok, E4 A/B lost 3
arms to coverage under host load 5-7 (guest burst, ksmd merging) ->
retained e4/served-ab-2222Z. Commit 856e88f: QWEN_CENSUS_AB_MODE=
kernel-delta in run-served-binary-ab.sh (both manifests instrumented,
series census vs census,E4; receipt verified against
QWEN_CENSUS_PRODUCTION_SERVER; every arm collects; summarize-bracket-ab.py
judges exclusive_bracket_ms of Q4_K with Q6_K as null + token identity;
coverage-refused arm kept under pinned clock). Chain 19
(~/stage-a-chain19.sh, 15:35 PDT): gate, prepare ~/src/llama.cpp-census-e4
with both patches, build census preset, settle load1<2.5 (10 min max),
kernel-delta A/B v7 vs census-e4, relaunch. test-run-served-binary-ab.sh
engine_clock_restore_on_term case is timing-flaky (failed once, passed on
rerun). Chain 19 RESULT (kernel-delta-20260902T2312Z, retained): Q4_K
exclusive bracket -3.93% sd 0.0002 over 4/4 pairs, union -3.90%, Q6_K
held both, span -2.1%, served +2.37% [+1.71,+3.02], zero timeouts, all
sidecars accepted; executed modules C a9ac07dd / K 180da20e / Q6_K
d584d6b4; E1 dump of census-e4 (e1-isa-e4-20260903T0140Z): pipeline 31
VALU 810, v_mac_f32 152, VGPR 64 = receipt. E4 retained as component;
E4b next. Reviewer-2 corrections landed in 9c08c94/40a8a4f: refusal set
parsed (gaps,window_lost only), whole-or-nothing admission (pairs ==
replicates, cooldown_timeouts 0, module_identity, response_identity
rename), union/span/ratio rows. Witness run-kernel-delta-witness.sh
(token ids + logprobs, bound 1e-3): server returns 127 probs for 128
tokens with the gap mid-array -> reader merges by id; chain 21 rerun
18:48 PDT -> result: ids held 768/768, logprob max 2.4e-2 (median 1e-5)
= differs on the 1e-3 bound; calibration production-vs-v7 = 0.0 exactly;
CPU-backend reference moves argmax on 4/6 prompts and logprobs up to
0.375 -> E4 movement is its own reassociation, an order inside a backend
change; bound needs a Vulkan-only reorder reference (none exists). All
three witness runs retained under evidence/.../e4/. Reviewer program
(2026-09-02 evening): 1e-3 bound retired as refuted with NO replacement
figure; margin contract registered in e4/margin-contract-design.md
(top-k 10, near-tie 0.1 nat, retention 0.5, holdout
remote/witness-prompts/holdout-12.tsv sha 1b784918..., commit 37c3fcb)
via QWEN_WITNESS_CONTRACT=margin + summarize-margin-witness.py; reader
admits withheld probability entries only where the next entry carries a
byte >= 0x80 (server-context.cpp process_token adds an entry only on
complete UTF-8; "÷" replies lose one entry per glyph; commit a3ed7cb).
Chain 24 result (retained e4/margin-holdout-20260903T0456Z): 10/12
held, min retention 0.786; grid-walk pos 25 and temperature-log pos 15
flip the argmax at control margins 0.0001 and 0.0023 nat -> differs as
registered; identity line re-registered to margins >= 0.1 nat (fresh
holdout needed, the retained run is NOT re-read). Audit (2026-09-02
late): do NOT merge #105; split into 7 lanes; repair main's #103
deployment defects first (pre-lock absence check, symlinked .staging,
dot-prefixed names, 0644 lock); env -i allowlists; lease before DPM;
ruff E741 fixed de878d3. PR #106 deployment-lock-repairs (63de01f
3a21102 1395700 d2111b3, from main 9398a46) opened 2026-09-02 ~22:55 PDT;
laptop gate in ~/qwen-gate-dlr (log ~/gate-dlr.log); merges FIRST, census
lanes rebase on it. #104's five threads are census-lane repairs, not #106.
Branch fixes landed on stage-a-census-brackets: 8d10749 (summarizer),
05ad0e8 (gate keys/binary reuse), e0d179a (broker freshness/validator),
3db353c (env scrub/probe/shader lab/witness), bddc3eb (gate cells),
63df204 (served/census harness identity binding, served-mode
response_identity, cooldown_timeouts fatal, sclk band in bracket reader;
reader reproduces the retained E4 rows exactly). Reply table for the 89
threads is scratchpad/replies.tsv (70 fixed, 14 deferred, 4 addressed,
1 disagree): post after the branch head gates on the laptop, then
resolve. Chain 25 = E4 quality gate
(text categories, C K K C, standalone servers aliased to the registry id);
attempt 1 failed on attribution (no --alias); result retained
e4/quality-gate-20260903T0547Z (fb50ef7): same 40/65 on all four arms,
64/65 replies byte-identical, screen-04 wording differs, both binaries
self-identical. E4 correctness matrix complete: deterministic held,
argmax held 10/12 (tie flips), retention >= 0.786, numerical identity
refuted, quality held. The serving launch is `QWEN_ROUTER=1 QWEN_BIND_HOST=0.0.0.0
qwen-launch.sh low-async` (router, 15 ids, LAN at 10.0.0.170:8080); a
bare `qwen-launch.sh` brings up a single-model 2B on loopback, which is
what chains 23-25 left behind -- every chain script's relaunch line must
carry those two variables. PRs open 2026-09-03: #106 deployment repairs,
#107 synthesis, #108 roster, #109 code-agent lane (3/3 tasks pass on the
4B), #110 web-search-live (live admission ran 07:24Z: grant, 5-result
bing search, fetch, page turn; SearXNG 75 MB), #111 install audit.
Runtime tree now = web-search-live d7b72f4. Launch pitfalls found: the
runtime-tree check's `comm` needs LC_ALL=C (laptop locale en_US), and
sync-runtime-tree.sh must not ship __pycache__ (a workstation
cpython-314 pyc broke the manifest); until fixed, launch with
`LC_ALL=C QWEN_ROUTER=1 QWEN_BIND_HOST=0.0.0.0 qwen-launch.sh low-async`
and delete *.pyc under ~/qwen-laptop-setup/remote first (both fixed on
web-search-live 480a06e/a104bb2; runtime tree synced to 7ff37e8). The
repository gate includes device tests (test-probe-depth-projector) that
refuse while a server holds the device, so a gate runs ONLY in a
teardown window: ~/gate-chain-1.sh (log ~/gate-chain-1.log) runs the
#106 gate (~/qwen-gate-dlr) then the census-branch gate
(~/qwen-gate-sacb) then relaunches the LAN router; started 00:47 PDT
2026-09-03. pgrep -f from an ssh shell matches itself: test liveness by
log content. PR #112 web-lan-exposure (base web-search-live; QWEN_WEB_LAN=1 +
QWEN_WEB_LAN_ADDRESS literal, bearer on router/broker/artifacts; runtime
tree synced to bf1522d). PR #113 e5-int24-shader (patch
llama-vulkan-q4k-int24-mmvq.patch candidate row; GGML_VULKAN_INT24_DOT
CMake option; GGML_VK_FORCE_INTEGER_DOT=1 runtime; compile receipts
under evidence/.../e5/; device stages not run). Queued on the laptop:
~/web-open-chain.sh runs admit-web-router-live.sh web-open after the
gate chain, then relaunches the LAN router. PR #106 MERGED as 6fcf390 (01:12 PDT 2026-09-03) after the laptop gate
accepted; census lanes rebase on it. Census branch gate rejected once on
test-shader-lab-replay because the fixtures' radv-debug.log were ignored
by ~/.gitignore_global (*.log); force-added in 5039c3f; rerun queued as
~/gate-chain-2.sh after the web-open admission. The laptop repo refuses
pushes to checked-out branches: push to refs/heads/incoming/NAME then
`git merge --ff-only incoming/NAME` in the checkout (~/Github/qwen-apu
is main, ~/qwen-gate-sacb is stage-a-census-brackets, ~/qwen-gate-dlr
was deployment-lock-repairs). Laptop git cannot fetch GitHub (https
auth). web-search-live now 11 commits (web-open promoted to validator-gated in
b0cf491 on two retained admissions: evidence/web-live/20260903T0724Z and
20260903T0810Z); web-lan-exposure rebased on it (tip 4a06908, PR #112
base web-search-live); runtime tree synced to 4a06908. Queued on the
laptop: ~/lan-web-image-chain.sh waits for gate_chain_2=done, then
launches `QWEN_WEB_LAN=1 QWEN_WEB_LAN_ADDRESS=10.0.0.170
QWEN_BIND_HOST=0.0.0.0 QWEN_WEB_AUTHORIZER_READY=1
QWEN_WEB_TOKEN_KEY_FILE=~/qwen-web-token.key qwen-image-launch.sh
low-async` = chat (web-open/4B) + web search + image + review on the LAN;
the 15-id ordinary router comes back with QWEN_ROUTER=1
QWEN_BIND_HOST=0.0.0.0 qwen-launch.sh. PR #114 prefill-ladder (base stage-a-census-brackets; 32768 rung
unmeasurable on shipped rows). Split done: PR #115 split-plan-pr-105,
PR #116 lane/census-timing (root, base main 6fcf390); lanes pushed:
build-cache-identity 65f7c69, dpm-telemetry d649f09, shader-e4 8306377,
correctness-witnesses 48ff457, served-ab-harness 5136c3e,
retained-evidence 2d71649; dpm/witness/served stack on census-timing;
lane/deployment-followups being created for six dropped commits
(74ddab7, b02fabd deployment hunks, a3105b4, 7e9e09b, 995ef68, f5f92d8).
Merge conflicts expected on repository-quality-gates.sh (gate_cell form
vs flat), build-llama-preset.sh, radv-low-priority-env.sh, CLAUDE.md.
Each lane gates on the laptop in a teardown window before its PR merges.
Census branch gate ACCEPTED at 5039c3f (01:40 PDT); 89 threads replied,
75 resolved, 14 deferred open. lane/deployment-followups 7393ff2 pushed;
split-plan-pr-105 bb245e3 (8 lanes). APPLIANCE STATE (user relaunch, later 2026-09-03): ordinary router on the LAN,
15 ids, no tools (QWEN_ROUTER=1 QWEN_BIND_HOST=0.0.0.0). The web+image LAN
lane (web-open + search + image, no review) is brought back by
~/lan-web-image-chain4.sh
(review needs a router-child projector tuple, task 31): launched by
~/lan-web-image-chain4.sh = build-web-presets.sh with QWEN_WEB_MCP_SERVER,
QWEN_WEB_PROVIDER=searxng, QWEN_WEB_STATE_DIR, QWEN_WEB_TOKEN_KEY_FILE
=~/qwen-web-token.key, QWEN_IMAGE_PROFILES=~/qwen-webui-state/
image-profiles-no-review.tsv, the five QWEN_IMAGE_* inputs
(PROFILES_JSON=~/image-admission-20260829T135331Z-review3/
image-parameters.json), then qwen-image-launch.sh with QWEN_WEB_LAN=1
QWEN_WEB_LAN_ADDRESS=10.0.0.170 QWEN_BIND_HOST=0.0.0.0. Page URL with
broker/artifacts params is on the lan_exposure line of session.status.
Router 10.0.0.170:8080 (bearer = ~/qwen-webui-state/api.key), broker
:8571. Fact-check incident (chat c4tcvue1wa6): the ordinary router serves
llama.cpp's embedded UI ("llama.app"), which advertises a browser-side
get_info tool to every model (tools/ui browser-info.ts); the 0.8B called
it twice and later cited "browser-only" as why it could not fact-check
its own prior answer; the transcript itself was carried (1304 prompt
tokens). The 0.8B's and the 4B's pharmacology were both wrong (Vyvanse is
lisdexamfetamine, a stimulant prodrug; "Vilan"/MAOI/selegiline are
fabrications). Remedy in progress: branch unified-router on
web-lan-exposure (task 33): one router preset with 15 tool-free sections
plus web-open carrying its MCP config; qwen-launch.sh starts broker +
SearXNG when a section names an MCP config and serves the repository
page. PR #117 unified-router (base web-lan-exposure): LIVE on the appliance since 05:46 PDT 2026-09-03: 16 ids (15 roster + web-open with search), LAN 10.0.0.170:8080, bearer required, broker :8571, SearXNG child; verifier fixed in 7e3c65d (row required only under the qwen_web_sections marker); bundle natural-boundary-13d05a0-r3-web assembled with QWEN_BUNDLE_ROUTER_PRESETS=merged ini and ACTIVATED (previous r2); automatic launch now = QWEN_ROUTER=1 QWEN_WEB_LAN=1 QWEN_WEB_LAN_ADDRESS=10.0.0.170 QWEN_BIND_HOST=0.0.0.0 QWEN_WEB_AUTHORIZER_READY=1 QWEN_WEB_TOKEN_KEY_FILE=~/qwen-web-token.key QWEN_WEB_MCP_SERVER=... QWEN_WEB_PROVIDER=searxng qwen-launch.sh low-async, no recovery mode. Launch form: ~/unified-router-chain.sh builds ~/qwen-webui-state/router-presets.ini with QWEN_WEB_AUTHORIZER_READY=1 QWEN_WEB_MCP_SERVER QWEN_WEB_PROVIDER=searxng QWEN_WEB_TOKEN_KEY_FILE QWEN_WEB_STATE_DIR, then QWEN_LLAMA_SERVER=~/qwen-deployments/natural-boundary-13d05a0-r2/llama-server QWEN_ROUTER=1 QWEN_ROUTER_PRESETS=$state/router-presets.ini QWEN_WEB_LAN=1 QWEN_WEB_LAN_ADDRESS=10.0.0.170 QWEN_BIND_HOST=0.0.0.0 QWEN_WEB_AUTHORIZER_READY=1 QWEN_WEB_TOKEN_KEY_FILE QWEN_WEB_MCP_SERVER QWEN_WEB_PROVIDER=searxng qwen-launch.sh low-async. Runtime tree = unified-router 1e20f27. Image lane is NOT in the unified preset yet (task 36). PR #118 webui-history-and-switch (base unified-router, tip b485c12): IndexedDB conversations with #/c/<id> routes, inline images with follow-up in one block, per-message model badges, llama.cpp UI notice tab (embedded UI cannot share the origin: server-http.cpp:333-427 one if/else); runtime tree synced to b485c12 so the served page has it. PR #119 probe-projector-router-mode (from main; gate fails closed until the device row exists). STAGED, NOT STARTED: ~/lane-gate-chain.sh (log ~/lane-gate-chain.log) = teardown, router-child projector probe for lfm25-vl-16b, gates for the 8 lanes (~/qwen-gate-lanes/NAME from incoming/ refs), live web admissions for web-reader and web-lookup, relaunch the unified router on the LAN; needs a user-approved ~4 h window. PR #120 unified-router-image (base unified-router; image server folded into the merged preset; review section withheld until the router-child row). Deploy attempt: bundle r4-image activated, launch refused on the web-mcp record row (4th column 'image' read into the digest); ROLLED BACK to r3-web, appliance serves web-only unified router; runtime tree = 1d92eac (image lane merged with the page). FIXED 96f21ec (qwen-launch.sh reads the four-field web-mcp-manifest row; test-unified-router-launch gains launch_accepts_the_image_bundle_record), pushed to unified-router-image (PR #120); runtime tree synced to 96f21ec; r4-image RE-ACTIVATED via ~/unified-image-chain2.sh and the LAN launch adds QWEN_IMAGE_PROFILES_JSON=~/image-admission-20260829T135331Z-review3/image-parameters.json; state=running with image_service_pid, artifact listener 0.0.0.0:<port> from session.status image_service_identity; web-open lists web_search_exa, web_fetch_exa, image_generate_image; one workstation curl generation (session -> grant-image on :8571 -> POST /tools) completed in 33 s, digest matched, replay refused, artifact 401 without bearer. Appliance now serves chat + search + image on the LAN from one bundle. sync-runtime-tree.sh carries remote/ and patches/ ONLY: webui/index.html must be scp'd to ~/qwen-laptop-setup/webui/index.html separately (the laptop served the Aug 29 page until 2026-09-03 ~09:15 PDT; now cd5ef83 with conversations, badges, UI-switch tab, and the API key kept in localStorage). llama-server --path reads the file per request, so a copy updates the live page without a relaunch. The bearer is per appliance: ~/qwen-webui-state/api.key (65 bytes, unchanged since Aug 28); the page asks once per browser now. Page-lane gate defects fixed on unified-router-image (9d35f8e test reset check, cd5ef83 storage probe lint). Agents running (3-cap): webui-history-and-switch (task 34, page: IndexedDB conversations, inline images, badges, UI switch tab), probe-projector-router-mode (task 31, from main). Tasks 35 (lease promotion) and 36 (image half of the unified router) queued; device chain after the script lanes land: root lane gate, projector probe, 2B/0.8B web admissions, prefill ladder, E5 build+ISA, lease admission+promote.
Lanes opened 2026-09-02 night: PR #107 evidence-first-principles-synthesis
(01c72c0, 18 lacunae; corrects integer-dot gate line to 6548), PR #108
webui-model-roster (feature-claims.tsv, build-feature-roster.sh,
roster.json, badges+matrix; web-profiles field 3 = web_mode, field 12 =
execution_policy, refused everywhere). SearXNG live on the laptop:
/usr/local/searxng runs as eirikr with SEARXNG_SETTINGS_PATH +
TMPDIR under ~/qwen-webui-state/searxng (root-owned /etc and /tmp caches
refused); engines that answer: bing, google, wikipedia, mdn, github,
stackoverflow (ddg/startpage/qwant CAPTCHA, brave rate-limit, mojeek/yep
denied); 66-78 MB RSS, 180-510 ms/query; pidfile
~/qwen-webui-state/searxng/webapp.pid; launcher ~/searxng-launch.sh.
Never pkill -f on the laptop (kills the ssh shell). Laptop CAN reach
GitHub and PyPI over https now. Pinned server serves /v1/messages
(Anthropic API) -> Claude Code points at the appliance. Agents running:
env-i seal (branch stage-a-census-brackets), web-search-live lane,
code-agent-lane. E5-int24 design in scratchpad
e5-int24-design.md (ACO 26.2.1: imul with both ub <= 0xffffff ->
v_mul_u32_u24, folds to v_mad_u32_u24; extract folds to SDWA). E4b target from the reviewer: Q4_K path <= 46.5
ms/token (about 2.7 ms/token more whole-graph saving on top of E4's 2.0),
measured as producer+consumer envelope, patch generated from the post-E4
tree, diagnostics off in timed arms; E4b goes in a successor PR from
merged main. PR #105 freeze: 116 threads, 98 unresolved, 89 without an
owner reply; batches in scratchpad threads-batch-{1,2,3}.json triaged
into triage-batch-N.tsv (ADDRESSED / OPEN-INTEGRITY / OPEN-DEFER /
DISAGREE); only integrity fixes land before merge. Quality gate
(run-quality-suite.py candidate vs control in one sweep) still pending
for E4. Not yet done: compile-bound decision, served-path nice contract,
guest-paused diagnostic. The fifth review's four
items landed as analysis head 587a69f (calibration-contract.tsv digest
required equal by attribution, QWEN_CENSUS_PRINT_CONTRACT=1, TERM cleanup
of served child and sidecar with a mutation test, UID-independent FCLK
fixtures, S parser classifying blocks by the largest n over non-f32
matmul rows because f32 rows are GDN chunk products scaling with token
count; 0222Z log reads 63 decode/3 prefill). Plan: keep chain5's raw
records as the acquisition bound to 34de93f, reprocess its S slice with
587a69f, run ~/stage-a-repro.sh (fresh production build R, ccache off,
cmp against the bundle server) in the teardown window after chain5, gate
587a69f, resolve PR threads, merge only then. Do not sync the runtime tree
while a chain's arms launch through it. test-radv-low-priority-env.sh fails on the
workstation at vulkaninfo (no RADV device) in the baseline too; it is a
laptop-gate test. RADV reports timestampPeriod=40 on RAVEN2. The nine PR
#105 review threads were answered with the fixing commits.

**Why:** The reviewer's rule: ownership is stated only where the brackets
can distinguish it from residency; every calibration falsifier controls the
process result; every auxiliary evidence source is present and valid
rather than attempted.

**How to apply:** Gate the exact v3 head on the laptop, build a fresh
census tree from the v3 patch, rerun the 2B calibration with
`QWEN_CENSUS_PRODUCTION_RECEIPT=<gate worktree>/evidence/fixed64-served-campaign/20260901T2011Z/identity-check.tsv`,
and start the 0.8B/4B census only after all three controls accept. See
[[qwen-fixed64-scoreboard-baseline]] and [[dash-dot-command-aborts]].

LAN PORTS (unified-router-image tip after cd5ef83): the user is remote over ssh+web and asked for a unique port. Post-chain relaunch form: QWEN_SERVER_PORT=42069 + the LAN launch env (broker derives 42070, artifacts 42071 under QWEN_WEB_LAN=1; page derives both from its own address). Runtime tree NOT yet synced with this (chain running; never sync mid-chain) -- after lane_gate_chain=done: sync-runtime-tree.sh, scp webui/index.html, teardown, relaunch on 42069, verify curl from workstation on all three ports. Page URL for the user then: http://10.0.0.170:42069/ with the api.key pasted once.

POST-CHAIN (2026-09-03): lane-gate-chain.sh started ~10:08 PDT (log ~/lane-gate-chain.log; first run failed silently: no exec bit). Router-child projector probe PASSED (8192, loaded, 4.2 tok/s, 0 resets) but against build-qwen-vulkan 3d5b1581 (the old default), not the promoted 5dd86b90 -> discarded; fix e77ee97 on probe-projector-router-mode defaults the server to resolve-active-deployment.sh. Staged ~/post-chain-relaunch.sh: teardown, rerun probe with QWEN_LLAMA_SERVER=deployment-current/llama-server, relaunch on QWEN_SERVER_PORT=42069 (broker 42070, artifacts 42071). BEFORE running it: sync-runtime-tree.sh from the unified-router-image worktree (.claude/worktrees/agent-a08f7f2ba30464e2b, tip 37ab8d5) and scp webui/index.html. Then retain the promoted probe run under evidence/depth-validation-32k-projector/lfm25-vl-16b/router-child/ on #119 (sanitize hostname/$HOME/mac), append the -router row with that evidence path, run check-validated-tuples + check-ledger-evidence + refresh-evidence-manifest.

LIVE (2026-09-03 10:41 PDT): unified router on http://10.0.0.170:42069/ (broker 42070, artifacts 42071), bundle r4-image, runtime tree 37ab8d5 + page cd5ef83 line, bearer api.key; verified from the workstation: health 200, 16 ids, broker 200, artifacts 401/200, tools on web-open. Lane gate chain was KILLED (user needed the site); its 8 lane gates + prefill-ladder-lane queued on the WORKSTATION gate runner (scratchpad gate-runner.sh; logs gate-runner.log, gate-runner-lanes.log, gate-runner-stack.log). unified-router-image first gate FAILED on test-qwen-launch-router-preflight (fixture lacked image-launch-lib.sh) -> fixed 002e5c1, re-queued. Still needing the device: web admissions web-reader/web-lookup (~10 min each, teardown), lease patch admission, E5 device stages, image perf arms. Promoted router-child probe PASSED (5dd86b90) -> retention agent on #119. User voice: report outages plainly; never present the URL unless verified from the workstation in that same turn.

E5 (PR #113, f39b893): workstation has no AMD GPU, but RADV 26.2.1 + a self-built amdgpu noop drm-shim (Mesa 26.2.1; AMD_FORCE_FAMILY is gone) compiles for RAVEN2 and its ACO output hashes identical to the appliance's retained receipts (ad837848 on the pinned q4_k f32 mat-vec). Decisive: int24 rewrite = 224 v_mul_u32_u24_sdwa, 1646 VALU; dotPacked4x8EXT build = 224 v_mul_i32_i24_sdwa, 1328 VALU (318 fewer) but the appliance's glslc (Vulkan 1.3.275) rejects GL_EXT_integer_dot_product; v_mad_u32_u24 fold never happens (SDWA is VOP2, mad is VOP3). Lab defect: lab.sh does not count v_mul_i32_i24. Laptop stages remain (module identity 8896269f..., runtime equality, witness, kernel-delta, whole-token). Address: 10.0.0.170 is a DHCP lease; qwen-laptop.local resolves via mDNS from the workstation -> the permanent address; open-LAN opt-in agent (branch lan-open-bringup from unified-router-image) building QWEN_WEB_LAN_NAME + QWEN_WEB_LAN_OPEN.

MERGES 2026-09-03: #106, #111, #116 (lane/census-timing) merged; main=717dbef. Workstation gate pitfall: ananicy-cpp renices comm 'bash' to -4, so any fixture with #!/bin/bash breaks the nice-19 served-decode contract (test-measurement-harnesses.sh) -> PR #122 gate-repair-served-python-wrapper (sh shebang). Re-gate every branch after #122 merges (unified-router-image, probe-projector-router-mode, split-plan-pr-105 (corpus restored 54f07bc), evidence-first-principles-synthesis, webui-model-roster, code-agent-lane, e5-int24-shader, 7 lanes, prefill-ladder-lane #121 now based on main). Lanes build-cache-identity/shader-e4/retained-evidence conflict with main -> merge agent. Gate runner script: scratchpad/gate-runner.sh LOG BRANCH... (worktrees ~/worktrees/qwen-apu/gate-<name>, logs beside).

OPEN LAN LIVE (2026-09-03 ~11:50 PDT): ~/open-lan-launch.sh on the laptop = teardown + qwen-launch.sh with QWEN_SERVER_PORT=42069 QWEN_WEB_LAN=1 QWEN_WEB_LAN_ADDRESS=10.0.0.170 QWEN_WEB_LAN_OPEN=1 (no key anywhere; lan_name derives qwen-laptop.local). Permanent address http://qwen-laptop.local:42069/ (10.0.0.170 is a DHCP lease). Verified from the workstation by name without a key: health, 16 ids, page, broker 42070, artifacts 42071, tools, chat. Branch lan-open-bringup ff-pushed into unified-router-image (PR #120 tip a2ce9cf); runtime tree synced to a2ce9cf + page. Operator decision recorded: LAN open, approvals still gate search/image.

E5 reframed on the workstation shim (branch e5-sdot-aco, 756ce1c,
2026-09-03): same Q4_K x Q8_1 probe, F0 FP dequantize 882 VALU / 64 VGPR /
chain 29; F1 stock OpSDot lowering 1328 / 36 / 23; F2 target-aware ACO
lowering (fork PR #2115, merged f1078c57e5f) 1297 / 36 / 24; F3 manual int24
1646 / 36 / 35. The earlier retained ISA receipts were compiled by Arch's
stock Mesa 26.2.1, not the fork; the fork's RADV ICD builds standalone in
under a minute with ccache and reproduces the pre-#2115 hash exactly. The
integer path carries more VALU than the FP path and fewer VGPRs; bracket
time on the appliance decides, and the appliance glslc still rejects
GL_EXT_integer_dot_product. lab.sh now counts v_mul_i32_i24 and v_add3_u32.

E4b-A refuted at compile time (branch e4b-summary-producer, 2026-09-03):
the sideplane consumer saves 13 of 810 VALU (1.6%), v_add_f32 40 -> 16,
plus 2 extra VMEM, against 84 producer dispatches per 2B decode graph, so
the E4b family cannot carry the remaining ~2.7 ms/token. The shim's E4
consumer receipt reproduces the appliance receipt bit for bit (isa_sha256
29454587...), so shim ACO output is appliance ISA. Next: attribute the 810
VALU + 414 SALU by phase (branch q4k-isa-attribution) and the NUM_ROWS
2/4/8 receipts; packed-FP16 or scale-decode restructuring are the candidate
levers.

Q4_K attribution (branch q4k-isa-attribution, 2026-09-03, shim = appliance
ISA): E4 loop body 330 VALU per 4 rows = MAC 104, weight decode 88, scale
decode 76, address 48, activation 12; body 76N+26 over NUM_ROWS N; SALU is
22 per iteration with one s_waitcnt lgkmcnt(0) on the critical path, the
rest outside the loop. Packed FP16 refuted at compile time (v_pk_fma_f16
costs 14 conversions; the mixed arm compiles to the control's exact ISA,
v_mad_mix_f32 = 0). NUM_ROWS=8 is a spec-constant-only arm: -3.64% body
VALU per row, -21% bytes per lane, VGPR flat 64, no spill, occupancy 4
unchanged; host passes rm_kq=4 so the remainder path is the falsifier.
Next: v_perm_b32 halfword select (-3/76), address rebase (ceiling -9/76),
hoist the per-iteration s_load_dwordx8. No candidate reaches the 2.7
ms/token the 2B promotion needs. depth.py partial-wait fix 17e096e changed
in-flight counts only, no chain figure.

Q4_K scale-word-select + loop-licm (branch q4k-scale-decode, 2026-09-03,
shim = appliance ISA): the two v_alignbyte_b32 were the unaligned 16-bit
load lowering, not a merge; v_perm_b32 is unreachable on gfx902 (ACO forms
it only at GFX10+). The triple-read plus byte-gather formulation compiles to
VALU 810 -> 776, VMEM 56 -> 40, longest chain 17 -> 12, and VGPR 64 -> 48,
which lifts occupancy 4 -> 5 subgroups per SIMD at the served four-row
shape; loop-licm hoists the descriptor reload (max_lgkm 1 -> 0, body SALU
22 -> 6). Combined arm `both`: VALU 786, VGPR 48. GF(2)-linearity proof
replaces sampled equivalence. The next kernel-delta device arm is this
combined candidate at manual-gfx1100-fclk933 (needs sudo -v).
