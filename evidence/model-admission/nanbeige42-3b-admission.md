# Nanbeige4.2-3B: the loop costs what the parameter count saves

`Nanbeige/Nanbeige4.2-3B` is a looped transformer: `config.json` declares
`num_hidden_layers: 22` with `num_loops: 2` and `tie_word_embeddings: false`.
`src/models/nanbeige.cpp` in the pinned tree reads `{arch}.num_loops`, sets
`hparams.n_layer_all = n_layer_phys * n_loops`, and comments that it shares the
physical weights across loops while each slot keeps its own KV index. Decode
therefore runs 44 layers per token over 22 layers' worth of weights.

Parameter count falls and per-token weight traffic does not. A loop saves
weights, and this appliance has 29 GiB of DDR4 against a 2.6 GB checkpoint, so
capacity is the axis it has slack on. Bandwidth is the axis it is starved on,
and a 1.87 GB working set cannot stay in 4 MB of L3 between iterations, so the
second loop re-reads every layer from DRAM.

## The census, from a range request

`remote/gguf-tensor-census.py` parses the header and index, so the first 48 MiB
of the file answers the admission question without the weights.
`Abiray/Nanbeige4.2-3B-GGUF` at revision
`774a61f8217ad18e7e102107fb7abcfecfae6a99`, `Nanbeige4.2-3B-Q4_K_M.gguf`,
2,574,807,986 bytes,
`18a659d0c1744e5bd2f4b8da55e0dcabf42ec7f005b74ec8eb66593b3380f958`:

```text
architecture             nanbeige
block_count              22
num_loops                2
skip_loop_final_norm     False
embeddings_tied          false
token_embd               287,096,832   Q4_K, lookup only
output.weight            418,682,880   Q6_K, streamed once
looped_layer_bytes     1,865,048,064   streamed once per loop
```

The conversion is community-produced and this tree cannot reproduce it:
`convert_hf_to_gguf.py` at the pinned commit carries no Nanbeige class, while
`gguf-py` carries the `NUM_LOOPS` and `SKIP_LOOP_FINAL_NORM` writer keys and
`src/` carries the runtime. That gap is a hazard rather than a blocker, and it
is the first thing the census checked. `nanbeige.cpp` reads the loop count with
`ml.get_key(LLM_KV_NUM_LOOPS, n_loops_u, false)`, a non-required lookup that
defaults to 1, so a converter predating loop support would produce a file that
loads cleanly and runs 22 layers instead of 44 -- answering wrongly rather than
failing, which is the same failure this repository documents for a mismatched
projector. This file carries `num_loops = 2`, so that hazard is refuted here and
stays a standing check for any other looped conversion.

## Prediction, recorded before the run

Per-token traffic is the looped layers twice plus the logit projection once:

```text
2 x 1,865,048,064 + 418,682,880 = 4,148,803,584 bytes = 4.149 GB
```

Against the 8.28 to 8.88 GB/s band the two 32-layer Qwen3.5-architecture
checkpoints measured on this machine, that predicts **2.00 to 2.14 decode
tok/s**, and 44 effective layers argue for the lower end because per-layer cost
grows with depth.

| Checkpoint | streamed/token | decode tok/s |
| --- | ---: | ---: |
| Qwen3.8-2B distill | 1.263 GB | 9.46 measured |
| Qwen3.8-4B distill | 2.698 GB | 3.07 measured |
| **Nanbeige4.2-3B Q4_K_M** | **4.149 GB** | **2.00 to 2.14 predicted** |
| Qwen3.8-9B distill | 5.046 GB | 1.76 measured |

A 4.2B checkpoint therefore lands between the 4B and the 9B rather than near the
2B, and below the 4B it is nominally smaller than. Q6_K at 3.42 GB would
predict roughly 1.6 tok/s.

**Falsification criterion:** a measured decode above 2.5 tok/s refutes the model
that the second loop re-streams from DRAM, and would mean either that the
backend retains the layer weights across iterations or that the loop is elided.
A measurement inside 2.00 to 2.14 confirms it. Below 2.00 indicates depth cost
beyond the 32-layer band, which is a quantitative correction rather than a
refutation.

## Why the published evidence does not transfer

The Artificial Analysis mobile study that places Nanbeige4.2-3B at the top of
its 16K bracket ran on phone-class silicon with unified memory an order of
magnitude faster than 38.4 GB/s nominal and with a system-level cache large
enough to change the loop's cost. A loop is close to free where bandwidth is
abundant and arithmetic is the constraint. This machine is the opposite case,
so the ranking inverts rather than transfers.

The same study's second finding transfers directly and points the same way:
Nanbeige's score fell from 63 to 18 under a one-minute output budget because
its reasoning traces did not finish. This appliance already measured that
failure on the Qwen3.5-4B base, which produced an empty answer at the 2048-token
cap, and it decodes several times slower than the phones tested.

## What still has to be measured

Throughput is predicted rather than measured, and quality is untested. The
suite that separates the checkpoints here is
`remote/compare-model-candidate.sh` and `remote/reasoning-span-probe.sh`, and
the loop argument says nothing about whether the model answers correctly. A
model that answers better at 2 tok/s remains a legitimate choice for work that
is not interactive; the prediction sets the price, not the verdict.
