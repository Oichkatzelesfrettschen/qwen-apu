# Compact n-gram retrieval does not yet earn a served comparison

## Decision

The workstation screen retains a small positive proposal signal and withholds
device work. A leave-one-workload-out external corpus raised the aggregate from
`1.000000` to `1.181538` committed tokens per simulated target pass, but the
optimistic projection against the retained target-pass cost curve reaches only
`1.008530x`. That projection excludes lookup, bookkeeping, restoration, and
rejected-state costs. Three of six workloads remain below `1.0x` even before
those costs. The result does not justify a served comparison or SSD experiment.

The result also preserves the narrower positive finding. The external corpus
raised exact draft acceptance from `0.261905` for history alone to `0.506383`
and supplied 58 of 79 proposal rounds. A more relevant corpus can improve
proposal quality. The current evidence says the improvement is too small and
uneven to pay the registered verification cost, not that retrieval-assisted
speculation can never help.

## Existing implementation boundary

`implementation-identities.tsv` binds the inspected llama.cpp source at
`f280b26983ad0fdb705a0d9ebf0503e76f2899b0`.

The pinned `ngram-simple` implementation searches the current token history.
Its defaults use a 12-token lookup key and a 48-token continuation. The older
repository depth arms changed `--spec-draft-n-max`, which does not configure
that implementation; `--spec-ngram-simple-size-n`, `-size-m`, and `-min-hits`
own its actual parameters.

The separate `ngram-cache` implementation loads static and dynamic cache files
through `common_ngram_cache_load()` during speculative-context construction.
The loader materializes nested `std::unordered_map` objects, and drafting reads
those in-memory maps. Context and dynamic keys span one through four tokens;
the static cache uses two-token keys. The existing file-backed cache therefore
uses storage for persistence and startup capacity. It is not a disk-resident
index that performs an SSD read for each generated token.

A longer-prefix retrieval store inspired by REST or a selected compact store
inspired by CREST would be a separate implementation and evidence tuple. Their
published results motivate the mechanism but provide no Raven2 speed claim:

- REST: <https://arxiv.org/abs/2311.08252>
- CREST: <https://arxiv.org/abs/2408.04678>

## Offline screen

`input-sequences.tsv` selects one canonical 128-token continuation for each of
six structured or code-like 4B workloads: accumulator, constraints,
list transformation, stack, state machine, and variable trace. Each source is
bound by SHA-256. All records name `qwen38-4b-distill`.

The screen compares three configurations:

| Configuration | Proposal source |
| --- | --- |
| `none` | one target token per simulated pass |
| `history` | only tokens already revealed in the held-out continuation |
| `history_external` | history first, then an index built from the other five workloads |

Every external index excludes the held-out workload. The runner backs off over
exact keys of 12, 8, and 4 tokens and proposes at most three tokens. Three is
the deepest registered proposal before the retained Raven2 target cost jumps at
column five. The replay commits the accepted prefix plus the target token that
would follow or replace it, so the final token stream remains exact by
construction.

| Configuration | Target passes | Committed/pass | Acceptance | Optimistic projected speedup |
| --- | ---: | ---: | ---: | ---: |
| `none` | 768 | 1.000000 | - | 1.000000x |
| `history` | 747 | 1.028112 | 0.261905 | 0.976011x |
| `history_external` | 650 | 1.181538 | 0.506383 | 1.008530x |

The projection binds `evidence/mtp-speculation-matrix.md` and uses its reported
one- through four-column target-pass costs of 323, 459, 662, and 783 ms. The
projection is an optimistic screening bound from historical device evidence,
not a current performance result. The screen measured Python lookup latency and
allocation on the workstation only. The maximum traced external-index
allocation was 791,056 bytes; that number describes Python objects rather than
a proposed native compact layout.

`workstation-result/results.tsv` retains every workload/configuration summary.
`rounds.tsv` retains every proposal, acceptance, commit, key size, source, and
lookup duration without copying token values. `aggregate.tsv` carries the table
above, while `contract.tsv` binds the runner, manifest, cost evidence, model,
split, keys, and draft limit. `terminal-state.tsv` records completion and the
absence of appliance contact.

## Limits and next admission condition

The retained responses contain output token IDs but not prompt token IDs. The
screen therefore measures completion-history and cross-task retrieval only. It
does not measure copying from the user-provided source text, which is the
strongest code-editing hypothesis. The offline replay also performs no target
forward pass, speculative accept/reject sampling, page-fault measurement, SSD
read, or correctness comparison between served configurations.

No served comparison is preregistered. Another workstation proposal should
first retain prompt/source token IDs and show a material, workload-consistent
gain over the history-only index under the same leave-one-workload-out rule.
Only a proposal that clears the historical verification-cost bound with margin
should register target verification, lookup, page-fault, storage-read, memory,
first-token, total-task, and task-correctness measurements. The appliance,
serving bundle, authentication boundary, and Q8 hold remain unchanged.
