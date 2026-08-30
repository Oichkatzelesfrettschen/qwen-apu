# The Vulkan graph optimizer and view aliases

`ggml_vk_graph_optimize` reorders nodes to widen parallelism, and its
`is_src_of` relation decides which node may move. At the pinned commit
f280b26983ad0fdb705a0d9ebf0503e76f2899b0 that relation compares `dst->src[s]`
against `src` by pointer and compares the two nodes' own `view_src` bases, so
two distinct views of one underlying tensor read as independent: a write
through one view can move past a read through another. Upstream issue
ggml-org/llama.cpp#27805 reports the consequence as a silently different token
under greedy decoding on a model that carries recurrent state through views,
which is the qwen35 architecture both served distills declare.

## Ancestry

The reordering entered at e68aa10d8, `vulkan: sort graph to allow more parallel
execution (#15850)`, and the pinned commit descends from it:

```sh
git -C "$HOME/src/llama.cpp" merge-base --is-ancestor \
    e68aa10d8 f280b26983ad0fdb705a0d9ebf0503e76f2899b0 && echo ancestor=yes
```

That exits zero, so every build of the pinned tree carries the optimizer. The
workstation clone lives at `$HOME/src/llama.cpp`, which is the default
`remote/verify-llama-patch-series.sh` reads; the appliance clone is
`$HOME/src/llama.cpp-qwen-apu`, which is the default
`remote/build-llama-preset.sh` reads.

The optimizer is `ggml_vk_graph_optimize` at
`ggml/src/ggml-vulkan/ggml-vulkan.cpp:17528` in the pinned tree, registered as
`.graph_optimize` at line 17862. `is_empty` is the lambda at 17536 and
`is_src_of` is the dependency relation at 17540 through 17554.
`GGML_VK_DISABLE_GRAPH_OPTIMIZE` is read at line 6194 into
`device->disable_graph_optimize`, which the optimizer tests at 17533 and
returns on, so the environment variable is a complete off switch for the
reordering.

## The production patch

`patches/llama-vulkan-view-alias-deps.patch` backports upstream commit
b387ddfd84b4b1f79a6e09910748195e3320e89e, PR ggml-org/llama.cpp#27812, which
closes issue #27805. The code change is upstream's verbatim: `is_src_of`
compares the underlying base of `dst->src[s]` against the base of `src`, and
the base of `dst` against the base of `src->src[s]`, and the `is_empty` guard
keeps NONE, RESHAPE, TRANSPOSE, VIEW and PERMUTE nodes out of the relation
since they execute nothing.

It is the seventh member of the production series.
`remote/verify-llama-patch-series.sh` applies it in the production loop and
compares the resulting `ggml/src/ggml-vulkan/ggml-vulkan.cpp` against
`dfac33fe7fd487fc136e2915de7d5c146a3921b231ffef55877c6dd9e4f2c164`:

```sh
remote/verify-llama-patch-series.sh
```

The verifier prints `patch_series=accepted` only after every production patch
applies and every registered source digest matches. Its optional candidate
stage now concerns `llama-server-vulkan-workload-lease.patch`; the view-alias
patch has no candidate-stage invocation.

## Hypothesis

The optimizer reorders across view aliases on this device, so the production
build with the optimizer on emits a token-id sequence that differs from the
same build with `GGML_VK_DISABLE_GRAPH_OPTIMIZE=1`, at temperature 0 with a
fixed seed and `cache_prompt` off, on prompts that keep recurrent state alive
across many decode steps. The patched build rejoins the optimizer-off
sequence.

Two arms fail together or the hypothesis is wrong in a stated way. The
production arm agreeing with the optimizer-off arm across every prompt and
every restart leaves the reordering unobserved on this device and this
checkpoint pair, which is a bound on the defect rather than a refutation of the
upstream report: RADV on gfx902 builds a different pipeline set than the
reporters' devices, and a graph the optimizer never had a reordering
opportunity in cannot expose the relation. The patched arm differing from the
optimizer-off arm refutes the backport rather than the optimizer, since the
patch only ever adds dependencies and a correct addition cannot change the
order the unoptimized graph already carries.

## Falsifier

The production-optimize arm disagreeing with itself across matched requests
reproduces the defect directly, which is why
`remote/run-graph-alias-ab.sh` reports `graph_alias_selfconsistent=` beside
`graph_alias_ab=`. The reported symptom is per-start rather than per-request,
so the sample budget splits across fresh server processes.

The preregistered patched-arm falsifier remains binding: any patched-arm token
sequence that differs from the optimizer-off reference leaves the backport's
output-equivalence claim unresolved. A stable patched arm can still remove the
production arm's within-process nondeterminism without proving complete output
equivalence.

## Running it on the appliance

The harness owns no launch chain: it starts its own `llama-server` per arm on a
private loopback port and refuses to run while another server holds the device.
Tear the appliance down first.

```sh
# on the laptop, from ~/qwen-laptop-setup
remote/qwen-teardown.sh

# Build an explicit historical control without the seventh production patch,
# and build the canonical seven-patch production source separately. Record
# both resulting llama-server SHA-256 identities before running the harness.

QWEN_PRODUCTION_BUILD_DIR=$HOME/src/llama.cpp-qwen-apu/build-raven2-vulkan-production \
QWEN_ALIAS_BUILD_DIR=$HOME/src/llama.cpp-alias/build-raven2-vulkan-production \
    remote/run-graph-alias-ab.sh ~/qwen-graph-alias-ab \
        qwen38-2b-distill qwen38-4b-distill
```

Each arm reads `context_default`, `batch`, `ubatch`, `cache_type_k`,
`cache_type_v`, and `flash_attention` from `remote/models.tsv` and names all of
them on the argv, because an absent `--batch-size` falls through to the
llama.cpp default of 2048 and that geometry wedged the compute ring at depth
16384 in `evidence/depth-versus-submission-geometry.md`.

Placement is pinned the same way `qwen-capacity-policy.sh` pins it for the
serving path: `--device Vulkan0 --split-mode none --override-tensor '.*=Vulkan0'
--fit off` with `LLAMA_NO_CPU_FALLBACK=1`. Left to `--fit`, llama.cpp decides
placement per load from the free VRAM it observes, and an arm that drifts layers
onto the CPU decodes deterministically in a different way, so a drifted
reference reads as divergent and blames the optimizer while a drifted production
arm reads as identical and hides it. The harness then reads the load log for
`Vulkan0 model buffer size`, `Vulkan0 KV buffer size`, and `Vulkan0 compute
buffer size` before it sends the first request, and stops the run when any of
the three is absent.

Self-consistency is compared at matched request position rather than against one
canonical sample. This appliance answers `arith-05` with 37 cold and 23 warm
from the same `prompt_n`, an effect the evidence discipline records as real and
unisolated, so the `across-start` scope compares run 1 of each start against run
1 of the first, where both samples sit at the same position behind the same
prompt sequence, and the `within-start` scope compares later runs against run 1
of their own start. A `within-start` divergence alone is re-checked at matched
position before it counts against the optimizer.

The defaults are three restarts of four runs over six prompts at 256 predicted
tokens, so one model and one arm is 72 requests. At the registry's 9.19 decode
tok/s the 2B spends about 28 s of decode per request and the 4B about 77 s at
3.34, which puts the full two-model three-arm matrix near ten hours before
load. `QWEN_ALIAS_AB_RESTARTS`, `QWEN_ALIAS_AB_RUNS`, and
`QWEN_ALIAS_AB_PREDICT` shorten it, and a first pass over `qwen38-2b-distill`
alone answers the self-consistency question in about an hour.

The offline gate runs anywhere:

```sh
remote/test-run-graph-alias-ab.sh
```

It drives the harness against `remote/test-fixtures/fake-llama-server.sh`,
which serves `/health` and `/completion` under `QWEN_FAKE_SERVER_PORT` and
returns a reordered token array from a build lacking the patch with the
optimizer on. The eleven checks cover the refusal, the per-arm argv including
the four placement flags, the placement rejection when the load log withholds
Vulkan0, the two self-consistency scopes, the `divergent` verdict with its
first divergent index, the `identical` verdict, and the absent patched build
recorded as `alias_build_absent`.

The sweep runs under `set -eu` with no resume: one failed request ends it and
the next invocation starts from the first arm. `remote/probe-depth-wedge.sh`
treats its output directory as a resumable ledger and this harness does not, so
a ten-hour matrix is worth splitting into per-model invocations.

## Result on the appliance

`ab-2b/` retains the run: `qwen38-2b-distill` at its registry tuple (24576,
128/32, q8_0/q4_0, Flash Attention on), 256 predicted tokens, seed 1, three
server starts per arm and four requests per start over the six prompts, 72
samples per arm, on the RADV RAVEN2 device with the router torn down.

| arm | within-start self-consistency | across-start self-consistency | against optimizer-off |
| --- | --- | --- | --- |
| production, optimizer on | divergent on 5 of 6 prompts | identical on 6 of 6 | divergent on 5 of 6 (first divergence at token 1, 2, 2, 2, 14) |
| production, optimizer off | identical on 6 of 6 | identical on 6 of 6 | reference |
| alias patch, optimizer on | identical on 6 of 6 | identical on 6 of 6 | identical on 5 of 6; `variable-trace` diverges at token 109 |

The historical unpatched build disagrees with itself: four requests into one server
process at temperature 0 with `cache_prompt` off return different token arrays
on five prompts, and the first difference sits inside the first fourteen
tokens. That is the defect reproduced without the patched build, and the
across-start agreement shows the disorder lives inside a process rather than
in its start. The optimizer-off arm is identical on every comparison, so the
reordering alone carries it. The patched build is identical on every
self-consistency comparison and rejoins the optimizer-off sequence on five
prompts; on `variable-trace` it departs at token 109 and then repeats that
departure in all twelve samples. A deterministic difference from a graph the
patch still reorders is floating-point non-associativity of a legitimately
reordered reduction, which the harness cannot separate from a missed
dependency. The registered patched-arm falsifier therefore fired on
`variable-trace`. The retained run supports two bounded findings: the patch
eliminated the observed within-process nondeterminism on all six prompts, and
five prompts matched the optimizer-off reference. The run does not establish
complete output equivalence or a generally safe reordering relation. A new
control must distinguish permitted floating-point reassociation from a missed
dependency before closing that claim. The production series nevertheless
contains `llama-vulkan-view-alias-deps.patch` as its seventh member, and
`verify_source` carries `ggml/src/ggml-vulkan/ggml-vulkan.cpp` at
`dfac33fe7fd487fc136e2915de7d5c146a3921b231ffef55877c6dd9e4f2c164`.

The retained `ab-2b/inputs.txt` names mutable build directories and omits the
two `llama-server` digests. The directory therefore identifies the observed
paths but does not cryptographically bind either A/B arm to immutable binary
content. The later promotion digests below identify promoted utilities; they
do not retroactively establish the binaries used by the earlier A/B run.

The promotion also found the appliance's production source tree one patch
behind the series: `llama-vulkan-submit-trace.patch` had been added to
`verify-llama-patch-series.sh` without being applied to the working tree the
promoted build compiles from, so the tree's `ggml-vulkan.cpp` read
`0527a209...` after the alias patch where the replay reads `dfac33fe...`.
Applying the trace patch brought all seven verified files to their replay
digests before the rebuild, and the digest line the promote chain prints
exists so the next drift is caught before a build rather than after.

## Status

The lane has run on the device and the patch is operationally promoted.
`remote/build-llama-preset.sh
raven2-vulkan-production` rebuilt the seven-patch tree on the appliance in
111 s, and `remote/promote-llama-build.sh raven2-vulkan-production` accepted
it with `strict_vulkan=passed multimodal=passed`. Those admission checks prove
the named placement and multimodal gates; the open `variable-trace` falsifier
prevents a broader correctness or safety claim. The served router runs the
patched optimizer; `llama-cli` promoted at
`0a7c6909bced2329f25a23c495bcf38544fef1e6f7b7da68eb0b2bb493ec9518`,
`llama-bench` at
`20e0ae33e203622b611a7be7f8fcea8b9ada1e625e222925dd96132396dd5869`, and
`llama-mtmd-cli` at
`4103d02b0fc1a5b64902d11ef43bebe1d98cdd7a2cba4cd1ad49bc4d133b2a89`.
