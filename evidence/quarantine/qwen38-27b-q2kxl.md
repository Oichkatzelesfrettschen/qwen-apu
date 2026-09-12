# Withheld model: Qwen3.8-27B UD-Q2_K_XL

```text
id             qwen38-27b-q2kxl
scope          model
subject        qwen38-27b-q2kxl
registry tier  archive
role           capacity-experiment
model file     Qwen3.8-27B-GGUF/Qwen3.8-27B-UD-Q2_K_XL.gguf
bytes          9,828,981,664
failure class  archive-capacity-experiment
tuple          unbounded; the withholding covers every geometry of this row
first evidence evidence/model-admission/qwen38-27b-q2-4k-preflight.log
latest evidence evidence/qwen38-27b-4k-admission.md
```

## The measured result the registry row cites

`evidence/qwen38-27b-4k-admission.md` sets the admission gate for this quant at
a 10,240 MiB provisional Vulkan allowance and 23.154 GiB of required
MemAvailable, against a 9,373.647 MiB file, on a 29 GiB shared host whose
desktop reserve is 4 GiB. The row's ceiling is 4096 tokens for that reason and
its `decode_tok_s` and `prefill_tok_s` columns read `-`: the experiment measured
what the machine admits rather than what it serves.

The finding is the capacity boundary, not a serving rate. Every class this
appliance targets -- 0.8B, 2B, 4B -- decodes above the 9B's 1.76 tok/s at a
fraction of the weights, and the 27B's own rate at 4096 was never measured
because the load peak, not the decode, is what the arm tested. The registry row
reads `archive` for that reason.

## The withholding

9.15 GiB of appliance disk carry a checkpoint whose admission arm is complete
and whose serving rate no campaign will read at this depth. The weights are
removed and this row stands in their place:
`remote/download-qwen38-27b-ladder.sh` refuses at its top while this row exists,
and `qwen-apu models install` refuses any group naming the id.

## Re-entry gate

Re-entry is the quarantine re-entry gate. A host with memory this one does not
have, or a backend that removes the second resident copy the admission gate
reserves against, is what would make the bytes worth their disk; a re-fetch on
this appliance is not. The ladder script's pins, byte counts, and digests stay
in the tree, so re-entry is a fetch rather than a re-admission.
