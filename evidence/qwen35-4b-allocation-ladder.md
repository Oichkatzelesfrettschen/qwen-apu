# Qwen3.5 4B Allocation Ladder

The Q4_K_M artifact is 2,740,937,888 bytes, or about 2,614 MiB. Q8 K plus Q4
V cache requires about 52 MiB at 4K, 416 MiB at 32K, 832 MiB at 64K, and 1,664
MiB at 128K for the eight full-attention layers.

The provisional live Vulkan gates are:

| Context | Weights plus KV | Required Vulkan gate | Unassigned headroom |
|---:|---:|---:|---:|
| 4K | 2,666 MiB | 4,096 MiB | 1,430 MiB |
| 32K | 3,030 MiB | 4,608 MiB | 1,578 MiB |
| 64K | 3,446 MiB | 5,120 MiB | 1,674 MiB |
| 128K | 4,278 MiB | 6,144 MiB | 1,866 MiB |

The headroom covers recurrent state, graph and scratch buffers, allocator
rounding, and staging. These values are conservative admission estimates, not
measured consumption. Each successful allocation run replaces its estimate
with the model, KV, compute, host, and peak process values from the exact
binary. Any measured allocation above the gate or any desktop-reserve failure
stops escalation to the next depth.

The 4K rung proves architecture, quant, KV type, Flash Attention, queue, and
strict-placement compatibility without generation. The 32K, 64K, and 128K
allocation rungs follow only after the preceding kernel hazard scan remains
clean. Prompt-prefill and decode benchmarks are separate later gates.

## Measured allocation results

All four rungs pass with Q8 K, Q4 V, Flash Attention, one slot, zero context
checkpoints, zero RAM cache, strict Vulkan placement, and zero matching kernel
hazards after each run.

| Context | Model | KV | Recurrent state | Vulkan compute | Vulkan self | Vulkan free |
|---:|---:|---:|---:|---:|---:|---:|
| 4K | 2,603.50 MiB | 52.00 MiB | 50.25 MiB | 18.52 MiB | 2,724 MiB | 13,102 MiB |
| 32K | 2,603.50 MiB | 416.00 MiB | 50.25 MiB | 25.52 MiB | 3,095 MiB | 12,723 MiB |
| 64K | 2,603.50 MiB | 832.00 MiB | 50.25 MiB | 33.52 MiB | 3,519 MiB | 12,291 MiB |
| 128K | 2,603.50 MiB | 1,664.00 MiB | 50.25 MiB | 49.52 MiB | 4,367 MiB | 11,426 MiB |

The Vulkan memory breakdown includes an unaccounted driver and desktop term of
about 1,216 to 1,249 MiB. The host-visible compute buffer grows from about 2.5
MiB at 4K to 33.5 MiB at 128K; model tensors remain entirely in the `Vulkan0`
model buffer. Each graph reports one executable split.
