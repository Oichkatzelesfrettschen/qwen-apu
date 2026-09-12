# Withheld model: Qwen3.8-4B Distill i1-Q5_K_M

```text
id             qwen38-4b-i1-q5km
scope          model
subject        qwen38-4b-i1-q5km
registry tier  rejected
model file     Qwen3.8-4B-Distill-Q5_K_M-GGUF/Qwen3.8-4B-i1-Q5_K_M.gguf
bytes          3,161,426,432
failure class  rejected-low-bit-ladder
tuple          unbounded; the withholding covers every geometry of this rung
first evidence evidence/model-admission/qwen38-4b-low-bit-ladder.md
latest evidence evidence/decode-bound-analysis.md
```

## The measured result the registry row cites

The rung extends the ladder above Q4_K_M to test whether a higher-bit trunk
holds its achieved streaming rate. `evidence/decode-bound-analysis.md` measures
1.93 tok/s as the four-block mean and 5.92 GB/s achieved streaming, against
Q4_K_M's 3.07 tok/s and 8.1 GB/s trunk: Q4_K_M runs 55% above this rung on
paired means with no block reversing the order.

The mechanism the same file records is the bulk format rather than the byte
count. A Q5_K trunk carries 65.76% of the streamed bulk and reaches 5.9 GB/s
where the Q4_K and Q6_K trunks reach about 8.1, so the rung pays more bytes per
token and streams them slower. The registry row reads `rejected` for that
reason.

## The withholding

The ladder arm is complete and this rung's 2.94 GiB serve nothing the 4B distill
does not serve faster. The weights are removed from the appliance disk and this
row stands in their place:
`remote/download-qwen38-4b-distill-i1-q5km.sh` refuses at its top while this row
exists, and `qwen-apu models install` refuses any group naming the id.

## Re-entry gate

Re-entry is the quarantine re-entry gate. A Q5_K trunk measured at the Q4_K
trunk's achieved streaming rate on this backend, under one sweep against a
same-sweep Q4_K_M control, removes this row. The fetch script's pin, byte count,
and digest stay in the tree, so re-entry is a fetch rather than a re-admission.
