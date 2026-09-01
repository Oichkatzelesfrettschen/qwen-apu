# A small draft model in front of a larger target

## The hypothesis

A 0.8B checkpoint decoding at 15.17 to 15.96 tok/s proposes tokens cheaply
enough that a 2B or 4B target verifying them decodes faster than it does alone.
`evidence/mtp-speculation-matrix.md` measured the embedded head doing this on
the 4B distill: acceptance 0.896 to 0.969 across three prompts and a decode
gain of 1.17 to 1.22 times over the unspeculated arm. Two pairings ask whether a
separate checkpoint reaches the same place, with the 2B target as the first arm
and the 4B as the second.

`remote/draft-pairs.tsv` carries them as `candidate` rows, so
`remote/build-router-presets.sh` offers each as its own picker section and
`remote/qwen-capacity-policy.sh` admits the section that names it. Neither row
carries evidence yet: `validated_evidence` reads `-` on both, and this
directory is where a measured arm lands.

## The mechanism at the pinned build

`--spec-type draft-simple` is the exact string. `common/speculative.cpp` maps it
onto `COMMON_SPECULATIVE_TYPE_DRAFT_SIMPLE`, and
`tools/server/server-context.cpp` builds a second `common_params` through
`common_base_params_to_speculative`, which copies the draft's `mparams`,
`devices`, `n_gpu_layers`, tensor overrides, and cache types over the target's.
`common_speculative_init_result` then loads that path as its own model with its
own context. Two checkpoints are resident, so the pairing costs the sum of both
artifacts on one Vulkan carve-out and `remote/qwen-launch.sh` sizes the router
preflight against that sum.

The draft context is derived rather than configured: the same constructor
assigns `cparams.n_ctx = llama_n_ctx(ctx_tgt)` before the draft model loads, and
no argument at this commit sets a draft depth. The ledger's `draft_context`
column records the derived value and the preset emits no key for it.

Placement is stated on both halves. `common_base_params_to_speculative`
overwrites `result.devices`, `result.n_gpu_layers`, and
`result.tensor_buft_overrides` with the draft's own values whenever a draft path
is set, so the `--device Vulkan0`, `--n-gpu-layers all`, and
`--override-tensor .*=Vulkan0` that reach the target leave the draft on
automatic placement unless the section names the draft options too.

## Tokenizer compatibility

`common_speculative_impl_draft_simple` calls
`common_speculative_are_compatible` in its constructor and throws
`draft model vocab type must match target model to use speculation` when it
fails. The check is four comparisons: matching `llama_vocab_type`, matching
`add_bos`/`add_eos` with matching token ids where they are set, a token-count
difference within `SPEC_VOCAB_MAX_SIZE_DIFFERENCE` of 128, and byte-identical
token text from `SPEC_VOCAB_CHECK_START_TOKEN_ID` of 5 upward.

That throw is caught rather than fatal, which decides how a mismatch presents.
`tools/server/server-context.cpp` wraps `common_speculative_init` in a `try`,
logs `failed to initialize speculative decoding context`, and continues with
`spec` null, so an incompatible pairing serves the target unspeculated at the
target's own rate. The same state arrives a second way: a context whose
`common_context_can_seq_rm` answers `COMMON_CONTEXT_SEQ_RM_TYPE_NO` skips the
initializer outright. Both leave a served request carrying no `draft_n`, since
`tools/server/server-common.cpp` adds the draft fields only where the request
drafted something, so `remote/measure-draft-pair.sh` reads a pair arm without
them as a terminal `state=failed reason=draft_absent` and withholds
`pair_over_control`. A silently unspeculated arm would otherwise report a
plausible rate against a control measuring the same thing.

`evidence/model-admission/static-admission.tsv` is the tree's own authority on
that identity, and it reports one vocabulary across the family:

| candidate | architecture | vocabulary | tokenizer pre | tokens_sha256 |
| --- | --- | ---: | --- | --- |
| qwen38-2b-distill-gguf | qwen35 | 248320 | qwen35 | 5cf6b9d701d926cb |
| qwen35-08b-bartowski | qwen35 | 248320 | qwen35 | 5cf6b9d701d926cb |
| qwen38-9b-distill | qwen35 | 248320 | qwen35 | 5cf6b9d701d926cb |

`remote/test-gguf-tokenizer-identity.py` proves that digest changes when any
decoder array changes, so a shared `tokens_sha256` is a shared token text array
and the byte-identity half of the runtime check is met by construction.

Two gaps stay open on the workstation. The served `qwen35-08b` row is the Q8_0
artifact from Qwen's own repository and the table's 0.8B rows are Q4_K_M
conversions of the same weights, and `qwen38-4b-distill` carries no static
admission row at all. Value format leaves the tokenizer arrays untouched, so the
expectation is that both read the same digest, and neither has been measured.
`remote/admit-candidate-static.py` reads a pinned revision's header over a range
request and answers both without the device.

## Draft length

`spec_draft_n_max` starts at 2 on both rows. `evidence/mtp-speculation-matrix.md`
prices the target's verification pass by column count on this device: columns
one through four cost about 150 ms each and column five costs 536 ms, an
occupancy step rather than a slope, and its S4 and S6 arms both decoded slower
than no speculation at all. Its arm labels map to draft length through the S1
log line `n_max=1` beside the S1 table row `cols 2`, so a draft of N verifies
N+1 columns; that mapping is inference from the two rather than a figure either
states. A draft of 2 verifies three columns, inside the measured flat region and
one column clear of the step. The MTP head's draft pass cost 66.4 ms and the
0.8B's whole token time is 63 to 66 ms, so the draft half of that arithmetic
transfers; the acceptance half does not, since a standalone draft is a different
model rather than a head trained on the target's own hidden state.

## Falsifiers, registered before any run

- A pair arm decoding below its own controls in the same session refutes the
  pairing at that draft length. The controls bracket the pair arms, so a decline
  that both controls share is machine drift rather than the pairing.
- Acceptance below the 0.896 the MTP head reached on its worst prompt places the
  standalone draft behind the head the target already ships, which makes the
  second resident checkpoint the more expensive way to buy less. The 0.896
  value is a conservative comparison policy, not a standalone-draft break-even
  derived from matched target and draft passes.
- Any emitted token-ID difference between a pair arm and either greedy control
  refutes correctness for that prompt even when rate and acceptance improve.
- A tokenizer mismatch the static check missed appears as a pair arm carrying no
  drafted tokens, which the harness ends on rather than scoring. That refutes
  the admission rather than the mechanism, and the row moves to `rejected` with
  the arm's server log retained for its
  `failed to initialize speculative decoding context` line.

A local `admission_gate=accepted` makes the measurement eligible for the
device-level promotion review; the harness never changes the ledger tier. A
`production` row additionally requires a retained clean kernel-hazard delta,
healthy bracketing controls, exact target and draft identities, and the
repository's quality-equivalence decision. One that decodes below its control
at `spec_draft_n_max` 2 earns one more arm at 1 before the row moves, since the
MTP matrix measured its own peak there.

## Running it on the laptop

The harness holds `$HOME/qwen-webui-state/vulkan-workload.lock` from before
listener preflight through summary publication, so another cooperating Vulkan
workload cannot overlap an arm. The harness refuses a resident server on either
the appliance or measurement port. Readiness binds the launched PID, Linux
process start time, and loopback listener inode. The same tuple must bracket
every completion request and the post-arm health exchange, so a foreign
listener or a same-PID close-and-rebind becomes terminal. The output path must
be absent. One invocation claims one immutable measurement directory, so a
failed rerun cannot leave an older accepted summary masquerading as the new
result. Teardown opens a Linux pidfd, verifies the recorded process start time,
and sends TERM or KILL through that stable process reference.

```sh
~/qwen-laptop-setup/remote/qwen-teardown.sh
QWEN_VULKAN_WORKLOAD_LOCK=$HOME/qwen-webui-state/vulkan-workload.lock \
    QWEN_PRODUCTION_BUILD_DIR=$HOME/llama.cpp-build \
    ~/qwen-laptop-setup/remote/measure-draft-pair.sh \
    qwen38-2b-distill+qwen35-08b-draft \
    ~/qwen-webui-state/draft-pairs/qwen38-2b-distill
QWEN_VULKAN_WORKLOAD_LOCK=$HOME/qwen-webui-state/vulkan-workload.lock \
    QWEN_PRODUCTION_BUILD_DIR=$HOME/llama.cpp-build \
    ~/qwen-laptop-setup/remote/measure-draft-pair.sh \
    qwen38-4b-distill+qwen35-08b-draft \
    ~/qwen-webui-state/draft-pairs/qwen38-4b-distill
```

Each run routes all four servers through `qwen-exec-idle-priority.sh` and
`radv-low-priority-env.sh` under `low-async`. An external prompt corpus is copied
once into `prompts.tsv`; every arm consumes that retained copy. Each request is
the exact nine-field object `prompt`, `n_predict`, `temperature=0`, `top_k=1`,
`seed`, `cache_prompt=false`, `stream=false`, `return_tokens=true`, and
`ignore_eos=true`. `curl --data-binary` sends the retained request bytes without
newline rewriting.

Before the first registry query, the harness copies `model-registry.sh`,
`models.tsv`, `draft-pairs.tsv`, and `quarantine.tsv` into the claimed output
directory. Every pair and model lookup reads those snapshots. `inputs.txt`
records the Git source revision plus source and retained identities for the
registry reader, all three ledger authorities, the measurement runner,
summarizer, prompt corpus, server, priority wrapper, Vulkan wrapper, target, and
draft. `source-revision-check.tsv` and `identity-check.tsv` reconcile the same
measured surfaces after all four arms. A source mutation remains terminal even
though the retained snapshot prevents a mixed tuple.

One directory per arm holds request bodies, token-bearing response bodies,
per-request listener tuples, and the server log. `arms.tsv` carries these exact
columns: `arm`, `mode`, `prompt`, `predicted_n`, `decode_tok_s`, `drafted`,
`accepted`, `acceptance`, `target_steps`, `tokens_per_target_step`,
`token_sha256`, `request_sha256`, `prompt_identity`, `request_identity`,
`response_sha256`, and `listener_identity`. The complete request identity uses
an exact key set and exact JSON value types. A control response carrying either
draft-counter key is terminal even when the value is null or malformed.

The retained summarizer writes `summarizer-execution-check.tsv` after one read
verifies its expected SHA-256 and byte count, then compiles and executes those
same in-memory bytes. `summary.txt` computes rates from total post-first token
time, reports both adjacent ABBA ratios, minimum and drafted-token-weighted
acceptance, effective tokens per post-first target step, and separate
performance, acceptance, exact-token, and local admission gates. The summary
rejects accepted counts above drafted counts and drafted counts above
`spec_draft_n_max` times the number of target steps. The step count omits the
first token that arrives from the prompt logits and follows
`predicted_n - draft_n_accepted - 1`. Rate aggregation weights each response by
`predicted_n - 1`. A rejected arm at draft length 2 reports `retry-n-max-1`
rather than promoting a mean that either adjacent control contradicts.

Serving a pairing through the ordinary chain takes the picker section the
generator writes:

```sh
~/qwen-laptop-setup/remote/build-router-presets.sh
QWEN_ROUTER=1 ~/qwen-laptop-setup/remote/qwen-launch.sh
```

The launch reports `router_preflight_subject=` with the draft beside the target
and `router_preflight_requirement mib=` with the draft's own mebibytes added,
because both checkpoints stay resident for the whole session.

## What stays unmeasured without the device

Every number above is either a figure retained from another run or a property
read from the pinned source. No arm of either pairing has run: the acceptance a
0.8B reaches against a 2B or 4B target, the decode rate either pairing serves,
the resident cost of two checkpoints in the 2048 MiB carve-out the 4B alone
fills to 2029, and whether the vocabulary check passes on the exact artifacts
this appliance holds are all open.
