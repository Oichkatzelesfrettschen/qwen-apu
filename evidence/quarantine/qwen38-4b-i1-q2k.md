# Withheld model: Qwen3.8-4B Distill i1-Q2_K

```text
id             qwen38-4b-i1-q2k
scope          model
subject        qwen38-4b-i1-q2k
registry tier  rejected
model file     Qwen3.8-4B-Distill-Q2_K-GGUF/Qwen3.8-4B-i1-Q2_K.gguf
bytes          1,959,168,512
failure class  rejected-low-bit-ladder
tuple          unbounded; the withholding covers every geometry of this rung
first evidence evidence/model-admission/qwen38-4b-low-bit-ladder.md
latest evidence evidence/decode-bound-analysis.md
```

## The measured result the registry row cites

The rung was fetched to test whether fewer streamed bytes convert to
proportional decode. `evidence/model-admission/qwen38-4b-low-bit-ladder.md`
registered the prediction at 4.35 tok/s from Q4_K_M's 3.07 and the exact byte
ratio, with a two-sided falsifier at 3.5 and above.

`evidence/decode-bound-analysis.md` measures 2.90 tok/s as the four-block mean
and 5.53 GB/s achieved streaming, against Q4_K_M's 8.1 GB/s trunk. Q2_K streams
29.4% fewer bytes per token and decodes no faster in any block, so the
registered falsifier fired and the linear size-to-decode model is refuted. The
registry row reads `rejected` for that reason.

## The withholding

The rung answers one question and that question is answered. Its 1.87 GiB sit on
an appliance whose whole model store competes with the DDR4 the served
checkpoints stream from, so the weights are removed from the appliance disk and
this row stands in their place. `remote/download-qwen38-4b-distill-i1-q2k.sh`
refuses at its top while this row exists, and
`qwen-apu models install` refuses any group naming the id.

## Re-entry gate

Re-entry is the quarantine re-entry gate: this row leaves
`remote/quarantine.tsv` when a new measurement contradicts the one above -- a
Q2_K trunk reaching the Q4_K trunk's achieved streaming rate on this backend, or
a pipeline change that removes the per-weight indirection
`evidence/decode-bound-analysis.md` names as the conjectured mechanism. The
fetch script's pin, byte count, and digest stay in the tree, so re-entry is a
fetch rather than a re-admission.
