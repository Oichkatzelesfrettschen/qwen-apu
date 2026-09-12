# Withheld model: Qwen3.8-4B Distill i1-Q6_K

```text
id             qwen38-4b-i1-q6k
scope          model
subject        qwen38-4b-i1-q6k
registry tier  rejected
model file     Qwen3.8-4B-Distill-Q6_K-GGUF/Qwen3.8-4B-i1-Q6_K.gguf
bytes          3,563,028,992
failure class  rejected-low-bit-ladder
tuple          unbounded; the withholding covers every geometry of this rung
first evidence evidence/model-admission/qwen38-4b-low-bit-ladder.md
latest evidence evidence/decode-bound-analysis.md
```

## The measured result the registry row cites

`evidence/decode-bound-analysis.md` measures 2.35 tok/s as the four-block mean
and 8.13 GB/s achieved streaming. The achieved rate matches Q4_K_M's trunk --
the two differ by +0.22, -0.15, -0.44, and +0.29 GB/s across the four blocks for
a mean of -0.02 -- so this rung streams at the served checkpoint's rate and
carries 28% more bytes per token to do it. Q4_K_M runs 28% above it on paired
means with no block reversing the order.

That is the rung's whole finding: the high-bit trunk costs decode in proportion
to its byte count and buys nothing this appliance reads back. The registry row
reads `rejected` for that reason.

## The withholding

The 3.32 GiB answer a question the four-block sweep has answered. The weights
are removed from the appliance disk and this row stands in their place:
`remote/download-qwen38-4b-distill-i1-q6k.sh` refuses at its top while this row
exists, and `qwen-apu models install` refuses any group naming the id.

## Re-entry gate

Re-entry is the quarantine re-entry gate. A graded quality result placing this
rung above the served Q4_K_M by a margin that survives one sweep, measured
against a same-sweep control, is the claim that would justify its bytes; the
rate arm alone cannot. The fetch script's pin, byte count, and digest stay in
the tree, so re-entry is a fetch rather than a re-admission.
