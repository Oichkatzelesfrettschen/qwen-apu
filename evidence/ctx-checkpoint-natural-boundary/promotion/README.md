# The promotion of the natural-boundary build

`remote/prepare-llama-vulkan-source.sh` upgraded the appliance's
`~/src/llama.cpp-qwen-apu` from the seven-patch prefix through
`patches/llama-server-natural-checkpoint-boundary.patch`, and
`remote/verify-llama-patch-series.sh` then replayed the series onto a clean
checkout of `f280b269` and matched `tools/server/server-context.cpp` at
`3744317beb622feff234e5b7a615c50665579f34ce49921e324bcd418fb3a58a`. That is
the same source the candidate binary
`68b28cc61e8903f35721a6ce796d9dff1f0f80fa344ad06d0d8e79d987bdae8c` compiled,
file for file across all eight paths the series touches, so the arms retained
beside this directory measure the source the promoted build carries.

`remote/build-llama-preset.sh raven2-vulkan-production` produced
`5dd86b90154f6143a5303efd2590b9268a0a5e3e908c4d6791f1fde03a4782c2`
(`promoted-binary.txt`) and recorded the semantics it compiled
(`artifact-manifest-head.tsv`). The promoted digest differs from the validated
candidate's because the two builds carry different compiler targets and build
prefixes. The identity arms already measure that difference as numerically
inert here: the frozen production binary
`40f7b775074e7d207dc2ad12f1aefc9635bd3904d5c35b68c8e43483622c4005` and the
candidate agree bit-for-bit on ids and log-probabilities at `c=0`, across
both turns and all three classes.

`remote/promote-llama-build.sh` accepted the preset on its own gates --
manifest digests current, the multimodal load closure whole, the strict Vulkan
one-token check placing every weight on `Vulkan0`, and the image smoke naming
the declared colours. The rebuild replaced the previous production directory
in place, so `--rollback` resolves to that same directory and
`~/qwen-frozen-binaries/` holds the only prior serving artifact.

## The capability binding, exercised

```text
frozen production binary, ledger count 2    refused, checkpoint_semantics=unknown
promoted binary, ledger count 2             --ctx-checkpoints 2 reaches the argv
```

`frozen.stderr` retains the refusal. `relaunch.txt` and `smoke.json` retain
the guarded relaunch on the promoted binary and one served completion at
9.64 decode tok/s, which is the 2B's ordinary rate.
