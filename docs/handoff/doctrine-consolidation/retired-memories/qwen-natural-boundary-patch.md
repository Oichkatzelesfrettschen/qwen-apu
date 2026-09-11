---
name: qwen-natural-boundary-patch
description: "The natural-boundary checkpoint patch is a local repair we own, promoted 2026-09-01 as the eighth production member, with checkpoint_semantics bound to the build at the exec boundary"
metadata: 
  node_type: memory
  type: project
  originSessionId: 22147316-dacf-465f-ac92-4dde5be63047
  modified: 2026-09-01T02:27:21.231Z
---

The natural-boundary llama.cpp patch is a local repair owned by this
repository; PR #20288 is provenance for the {4 + n_ubatch, 4} placement
mechanism the patch removes, nothing more. Upstream-contribution language
stays out of evidence, commits, and conversation.

Measured 2026-08-31 on the 0.8B: patched c=2 reproduces stock c=0 ids and
logprobs bit-for-bit while the turn-2 restore charges 28 tokens (1.58 s
against 693.8 s), so the forced near-end partition is the sole measured
perturbation source and checkpoint capture, restoration, and natural
placement are numerically neutral.

The 0.8B and 2B compact validations closed 2026-08-31 (2B: production c0 ==
patched c0 == patched c2 bit-for-bit, 28-token restore at 1.96 s), so the
repair acts on the execution mechanism rather than only the 0.8B near-tie
symptom.

The 4B compact validation closed 2026-09-01 and all three classes are admitted.
Five witnesses -- frozen production c0, candidate c0 opening, candidate c2
first, candidate c2 repeat, candidate c0 closing (`patched-arm4b`) -- are
bit-identical on token ids and retained logprobs across both turns, 32 of 32
positions each. The charge split holds: every c0 turn 2 charges 30,748 tokens
(3188 to 3871 s) and every c2 turn 2 charges 28 (6.1 and 8.0 s). The prefill
rates span 7.94 to 9.77 tok/s across the five arms, inside this machine's
spread, and order nothing.

The 4B arm buys admission authority rather than mechanism discovery. The
mechanism is localized on the 0.8B and cross-validated on the 2B; the 4B
establishes that its own row, geometry, recurrent state, and long-context
execution tolerate the repaired implementation, because the ledger is
empirical rather than deductive.

A compact 32-token witness establishes that a class begins decoding from the
same measured numerical state under c=0 and c=2, repeats that state
deterministically, and restores correctly. It compares no long generation, so
a claim over thousands of decode positions requires a long-generation equality
arm that no run has performed.

The 4B closing c=0 arm reran as `patched-arm4b` after the probe's fixed 3600 s
`QWEN_CTX_REQUEST_SECONDS` ceiling timed out a class whose full prefill measures
3251-3502 s; the re-run uses 10800 s. A failed attempt ahead of it loaded and
released the model, so that arm's model-load and first-pipeline latency read
against a warmed RADV shader and page cache and are not a cold-start
measurement. The predicate is unaffected: turn-2 charge and numerical identity
both come from a request that reprefills all 30,748 tokens after loading. The
probe's request ceiling should scale from the class rather than sit at a
constant, since the 9B prefills slower still.

Promotion executed 2026-09-01 in that order. The candidate build tree replayed
byte-identically to the repository's seven production patches plus the
natural-boundary patch on all eight touched files, so the validated arms measure
the promoted build's source. `prepare-llama-vulkan-source.sh` upgraded the
appliance tree from the seven-patch prefix, `verify-llama-patch-series.sh` pins
`tools/server/server-context.cpp` at 3744317b as the eighth production member,
the rebuild produced 5dd86b90 twice with identical digests, promotion passed its
strict Vulkan and image smokes, the ledger moved to 2/2/2, the router presets
regenerated with five of fifteen sections at count 2, and the relaunched
appliance answers with `--ctx-checkpoints 2` on its argv. The frozen 40f7b775
remains the only prior serving artifact, since the rebuild replaced the
production directory in place and `--rollback` now resolves to that same
directory.

The capability binding is implemented rather than planned. A build earns its
declaration: `build-llama-preset.sh` writes
`checkpoint_semantics=natural-boundary-v1` only where the repository holds the
patch at c9d40105, the compiled source hashes to 3744317b, and the
`checkpoint_offsets` array is absent, and records `checkpoint_patch`,
`checkpoint_patch_sha256`, `checkpoint_source_sha256`, and
`checkpoint_patch_series_sha256` beside it. `remote/llama-patch-series.tsv` is
the single ordered-series authority the verifier, the source preparer, and the
build all read. `qwen-build-exec-guard.sh` runs on both serving paths after
`radv-low-priority-env.sh` and ahead of the router guard: it resolves the
executable through symlinks, requires the manifest to hash to what the policy
measured, requires one executable row matching that server's bytes and digest,
and requires one `checkpoint_semantics` row equal to the requirement. The
requirement follows the count that reaches a server -- the ledger row on the
single-model path, a positive `LLAMA_ARG_CTX_CHECKPOINTS` in some preset section
under router mode -- so an all-zero preset launches an older build.
`promote-llama-build.sh` applies the rule at the symlink swap and refuses a
rollback to a target the current policy cannot launch.

Main is coherent again, and the defect class is closed rather than this
instance alone.

Submission policy wants to become phase-aware rather than whole-session: the
32K c0 stress arm measured p50 168 us, p90 1.52 ms, p99 21.016 ms, max
104.542 ms, with 2414 of 103901 samples over 20 ms (2.3%), so serializing a
large first-turn prefill while decoding under low-async is the endpoint.
Serializing the whole session halves decode (2.718 against 1.348 tok/s). The
profile is process-wide today, so this needs a backend change keyed on graph
phase rather than an environment switch between requests; the proposed knobs are
`GGML_VK_PREFILL_MAX_NODES_PER_SUBMIT`, `GGML_VK_DECODE_MAX_NODES_PER_SUBMIT`,
and `GGML_VK_PREFILL_SERIALIZE_THRESHOLD`, compared across low-async/low-async,
serialized/serialized, serialized/low-async, and paced/low-async. Stage A runs
first, because its trace decides whether prefill pressure is submission density,
one dominant pipeline, or both.

Related: [[qwen-gtt-and-queue-decisions]], [[qwen-benchmark-class-policy]].

Prefix reuse across conversations (branch tool-prefix-checkpoint,
2026-09-03, source-read at f280b269 + production series): the appliance runs
`--parallel 1 --cache-ram 0`, so server_prompt_cache is inert and one slot's
checkpoint list is the only carrier. On the hybrid memory seq_pos_min
reports the last position, so every rollback takes the checkpoint branch.
A new conversation with the same system+tools head on the same slot IS
already reused (the fill loop breaks at last_user_message_pos and the
checkpoint at |P| is accepted); one unrelated request in between clears the
slot and the head is reprefilled; a different system prompt recomputes from
token 0 (Gated DeltaNet state cannot be partially reused). The candidate
patch `llama-server-prefix-checkpoint.patch` pins one whole-sequence state at
the last-user-message boundary keyed by model, template, tuple, build,
system-span digest, prefix-token digest, and length; armed by
QWEN_PREFIX_CHECKPOINT, independent of --ctx-checkpoints, declares
checkpoint_semantics unknown. Only the OAI chat path carries
message_delimiters; /completion gets no pin. Device arms unrun.
