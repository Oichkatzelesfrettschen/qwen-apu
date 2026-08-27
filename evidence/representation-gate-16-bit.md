# What a 16-bit representation costs on Raven2 Vulkan

RADV on this device reports `shaderFloat16 = true` and `shaderInt8 = true`, and
`vulkaninfo` names no bfloat16 extension at all: a case-insensitive search for
`bfloat` over the full report returns zero lines. F16 is therefore the 16-bit
format the device advertises, and BF16 is a separate question about whether
llama.cpp's scalar BF16 pipelines execute without the extension their coopmat
variants require.

Both publishers ship BF16 as their only 16-bit artifact.
`empero-ai/Qwen3.8-2B-Distill-GGUF` holds BF16, Q4_K_M, Q5_K_M, Q6_K, and Q8_0;
`bartowski/Qwen_Qwen3.5-0.8B-GGUF` holds bf16 and no f16 model file. Measuring
what the device advertises therefore means producing F16 on the appliance, which
is why `remote/build-llama-vulkan.sh` now builds `llama-quantize`. The tool
accepts F16 as type 1 and BF16 as type 32, and the conversion changes the value
type while preserving the layout: the 0.8B census reports 99.17% of bytes as
BF16 before and 99.17% as F16 after, at the same 1,505,783,040 streamed bytes
per token.

## What the file streams, which is what the ratio rests on

The census figure excludes the multi-token-prediction block an ordinary load
skips, so it is the quantity the device moves rather than the file size.

| artifact | streamed bytes per token | GiB per token |
| --- | ---: | ---: |
| Qwen3.8-2B Distill Q4_K_M | 1,263,435,008 | 1.177 |
| Qwen3.8-2B Distill F16 | 3,764,747,520 | 3.506 |
| Qwen3.5-0.8B Q8_0 | 800,881,920 | 0.746 |
| Qwen3.5-0.8B F16 | 1,505,783,040 | 1.402 |

Each checkpoint's own measured rate fixes its achieved streaming. The 2B Q4_K_M
decodes 9.19 tok/s in the seven-checkpoint sweep, which is 10.81 GiB tok/s; the
0.8B Q8_0 decodes 18.53 tok/s, which is 13.82. Those two differ by 27.8%, so a
prediction uses the checkpoint's own point rather than one device constant.

## Registered predictions

The arm is `remote/run-representation-arm.sh`, which runs control, subject,
subject, control through `llama-bench` at `-ngl 99 -t 2 -r 3 -p 512 -n 64 -b 128
-ub 32 -fa on -ctk q8_0 -ctv q4_0 -ot '.*=Vulkan0'`, samples clocks, temperature,
and VRAM and GTT occupancy across every arm, and refuses any arm whose own
diagnostics name a CPU buffer. The ratio is read from the paired means, because the same checkpoint
under identical flags spans up to 30.6% between sweeps in this tree and an
absolute band built across sweeps measures the sweep.

1. The 2B F16 decode ratio against its Q4_K_M control lands within 0.30 to 0.38.
   The streamed-byte ratio is 0.336, so a purely bandwidth-bound representation
   returns the inverse byte ratio. Falsified by a ratio outside that band, which
   would mean the value format costs something other than the bytes it moves.
2. The 2B F16 decodes below 9 tok/s, the admission floor stated for this size
   class. Falsified by 9 tok/s or more.
3. The 0.8B F16 decodes between 8.5 and 11.2 tok/s. Its centre is 9.85 from the
   Q8_0 point, and the band carries the 4% uncontrolled depth-0 spread this tree
   measures plus room for a format-trunk change. This is the arm whose outcome
   the fit leaves open: it straddles the floor rather than clearing or missing
   it. Falsified by a rate outside the band.
4. F16 achieves at least the GiB tok/s its own control achieves, because an F16
   weight is read and used where a quantized weight is read and unpacked. The 2B
   control is Q4_K_M and the 0.8B control is Q8_0, so the comparison is against
   each arm's own control rather than against one quantization family. Falsified
   by F16 achieving less, which would place the cost in the wider memory
   footprint rather than in the arithmetic.
5. Strict Vulkan placement passes for F16 on both checkpoints. Falsified by a
   `CPU buffer size` line in either the one-token pre-check or an arm's own
   diagnostics, which would make that rate a hybrid measurement rather than a
   device one. The per-arm check is what the ratio rests on: a pre-check proves
   placement is reachable rather than taken, and the 0.8B carries 34% of its
   streamed bytes in one tied embedding tensor.

## What this gate decides

A poor F16 result rejects F16 as an interactive serving representation on this
device. It rejects no model identity: a checkpoint whose weights are only
published as safetensors or BF16 can still be converted to a K-quant that
serves, and the conversion strategy is what this outcome selects.

## Results

Pending. The arm has not run.
