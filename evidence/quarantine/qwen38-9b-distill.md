# Withheld model: Qwen3.8-9B Distill Q4_K_M

```text
id             qwen38-9b-distill
scope          model
subject        qwen38-9b-distill
registry tier  archive
role           deep-text
model file     Qwen3.8-9B-Distill-GGUF/Qwen3.8-9B-Q4_K_M.gguf
bytes          5,780,090,176
failure class  archive-decode-rate
tuple          unbounded; the withholding covers every geometry of this row
first evidence evidence/model-admission/qwen38-9b-4k-preflight.log
latest evidence evidence/qwen38-9b-distill-admission.md
```

## The measured result the registry row cites

The row carries 1.76 decode and 11.47 prefill tok/s from the seven-checkpoint
sweep in `evidence/model-admission/universal-candidate-ladder.md`, at 5.37 GiB
of weights. The size ladder this tree serves reads
`0.8B -> 2B -> 4B -> 9B -> 27B`, and the 9B sits below every class the appliance
targets: the 2B decodes at 9.46 and the 4B distill at 3.07 in the same sweep.
At 1.76 tok/s a 500-token reply takes over four and a half minutes, which is
outside the interactive band `remote/qwen-webui-session.sh` arms its desktop
latency policy for.

The row's quality column reads `5/5-screen`, the earlier five-prompt screen run
with thinking on, so no graded suite result stands against it either. The
registry row reads `archive` for that reason: a valid artifact displaced by a
faster one rather than a dangerous one.

## The withholding

5.38 GiB of appliance disk carry a checkpoint no launch path selects. The
weights are removed and this row stands in their place:
`remote/download-qwen38-9b-distill-q4km.sh` refuses at its top while this row
exists, and `qwen-apu models install` refuses any group naming the id.
`remote/build-router-presets.sh` already keeps an `archive` tier out of every
preset section, so the withholding removes bytes rather than a serving option.

## Re-entry gate

Re-entry is the quarantine re-entry gate. A change that moves the 9B into the
interactive band -- a draft pairing measured above the 4B's served rate, or a
backend change that lifts achieved streaming on this hardware -- removes this
row, and the registry tier moves from `archive` in the same step. The fetch
script's pin, byte count, and digest stay in the tree, so re-entry is a fetch
rather than a re-admission.
