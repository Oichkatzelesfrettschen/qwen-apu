# The compact-model shortlist, loaded once each

Eleven checkpoints below two billion parameters, fetched at a pinned revision and
loaded once under strict Vulkan placement: CPU tensor placement and CPU graph
placement rejected first, then model, KV, and compute buffers required to name
Vulkan0 with no CPU fallback reached. Ten produced their two tokens. The
`admission-summary.tsv` beside this file is what the runner wrote.

## What the arm answers

The architectures reach past the Qwen family this appliance grew up on, and the
question was which of them this backend executes at all rather than which is
best. `llama-no-cpu-fallback.patch` makes that question decidable: an operation
without a Vulkan kernel refuses the load rather than running on the two cores and
reporting a rate, so an acceptance here is a claim about kernels rather than
about patience.

Three architectures were new to the tree and all three ran: `lfm2` (three
checkpoints), `granite`, `olmo2`, and `minicpm`. The Vulkan backend implements
`GGML_OP_SSM_SCAN` and `GGML_OP_SSM_CONV`, which is what the hybrid
state-space blocks need, so the hybrid families are not excluded here.

## The one refusal, and what it is not

`falcon-h1-15b` loads, serves, and answers a completion with HTTP 200. It then
reports `tokens_predicted:1` with empty content and `stop:true` -- an immediate
end of sequence where the other ten emit two tokens against the identical
request. The refusal is therefore a generation failure rather than a missing
kernel, and `granite4-1b` passing the same arm is the evidence that the hybrid
Mamba path itself executes.

That distinction stayed invisible at first. The check's final requirement was a
bare `grep` for the token count, and a non-match under `set -e` ended the script
with status 1, an empty log, and an empty detail column; the cause took an
`sh -x` replay to find. Every requirement in that file now names what it required
and what it found, which is the change this arm's own opacity motivated.

## Sizes, measured rather than advertised

The parameter count summed over every tensor's shape disagrees with the
publishers' labels often enough to matter for a picker that orders by size:
`granite-4.0-1b` measures 1631 M, `xLAM-2-1B-fc-r` 1543 M, and
`OLMo-2-0425-1B-Instruct` 1484 M, so three checkpoints advertised at one billion
sit between one and a half and one and two thirds. `MiniCPM4-0.5B` measures
433 M, below its label. `remote/model-capabilities.tsv` carries the measured
number, and the picker orders by it.

## What an acceptance does not establish

A load and two tokens say nothing about tool selection, reasoning, or
termination. Every admitted row enters `remote/models.tsv` at tier `candidate`
with `raw_tool_selection` unmeasured and `guarded_tool_execution` refused, which
is where every row in this tree sits until its own graded arm runs.
