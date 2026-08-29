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
  second resident checkpoint the more expensive way to buy less.
- A tokenizer mismatch the static check missed appears as a pair arm carrying no
  drafted tokens, which the harness ends on rather than scoring. That refutes
  the admission rather than the mechanism, and the row moves to `rejected` with
  the arm's server log retained for its
  `failed to initialize speculative decoding context` line.

A pairing that clears all three moves to `production` with its measured
directory in `validated_evidence`. One that decodes below its control at
`spec_draft_n_max` 2 earns one more arm at 1 before the row moves, since the MTP
matrix measured its own peak there.

## Running it on the laptop

The harness owns the device for its whole run and refuses to start beside a
resident server.

```sh
~/qwen-laptop-setup/remote/qwen-teardown.sh
QWEN_PRODUCTION_BUILD_DIR=$HOME/llama.cpp-build \
    ~/qwen-laptop-setup/remote/measure-draft-pair.sh \
    qwen38-2b-distill+qwen35-08b-draft \
    ~/qwen-webui-state/draft-pairs/qwen38-2b-distill
QWEN_PRODUCTION_BUILD_DIR=$HOME/llama.cpp-build \
    ~/qwen-laptop-setup/remote/measure-draft-pair.sh \
    qwen38-4b-distill+qwen35-08b-draft \
    ~/qwen-webui-state/draft-pairs/qwen38-4b-distill
```

Each run writes `inputs.txt`, one directory per arm holding its request bodies,
replies, and server log, an `arms.tsv` of twelve rows, and a `summary.txt`
carrying the paired means and their ratio.

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
