# Workstation llama source worktree reconciliation

## Result

The workstation inventory found eighteen `llama.cpp*` source roles under the
source root. Two Git common directories owned five linked worktrees; thirteen
other roles were standalone detached checkouts. Seventeen roles are historical
experiment sources whose mechanisms already have tracked patch or evidence
owners. The qwen-nvidia source and build tree remains the one retained external
source owner because its CUDA builds still bind published evidence.

The seventeen cleanup candidates occupy 15,987,245,056 bytes. The retained
qwen-nvidia owner occupies 53,339,684,864 bytes. Those byte counts describe the
enumerated source trees, including their ignored build directories; they do not
describe filesystem blocks recovered by a later Trash move.

`inventory.tsv` binds every role to its source HEAD, full tracked-diff digest,
tracked-diff length, untracked-file cardinality, process-reference observation,
durable owner surface, and disposition. The process scan inspected each
process's `cwd`, `exe`, `root`, and open file descriptors and observed zero
references into all eighteen trees. Cleanup repeats that observation before a
move because process ownership can change.

## Unique-source decision

The audit compared every substantive added source line in each tracked diff and
untracked source file against all tracked qwen-apu and qwen-nvidia llama patch
files. The comparison found complete line coverage for fourteen roles. The
remaining ninety-six distinct lines belong to one earlier pipeline-census
implementation and three earlier Q4_K sideplane layouts. The current tracked
pipeline-census patch retains source and executed-module SHA-256 identities,
bounded timestamp-query handling, module dumps, and the complete dispatch
record. The current sideplane patch retains the corrected tensor identity,
bounded column policy, producer-consumer layout, and registered candidate
controls. The earlier lines therefore add historical implementation bytes
rather than a missing mechanism.

Five exact relations close duplicate-source questions:

- `llama.cpp-e4` has the same full patch digest as
  `llama-vulkan-q4k-activation-group-sums.patch`.
- `llama.cpp-e4b-check` and `llama.cpp-e4b-ref2` have identical tracked diff
  and untracked-source identities. `llama.cpp-e4b-ref` differs in one earlier
  `ggml-vulkan.cpp` layout line.
- `llama.cpp-e4b-ref` and `llama.cpp-e4b-stack` resolve to the same total
  source state relative to the pinned source tree despite their different
  historical base commits and diff encodings.
- `llama.cpp-prefix-check` and `llama.cpp-prefix-gen` resolve to the same total
  source state relative to the pinned source tree despite their different
  historical base commits and diff encodings.
- `llama.cpp-prefix-ckpt` and `llama.cpp-qwen-apu-trace` have byte-identical
  source trees outside ignored build directories.

The qwen-nvidia tree receives a retained disposition rather than a cleanup
classification. Its many build directories name source and executable
identities in the CUDA evidence corpus. A later qwen-nvidia evidence-retention
task can classify derived build fanout without coupling that decision to the
qwen-apu cleanup.

## Private retention

Before cleanup, the workstation retained one reconstructable private bundle
under the repository-owned runtime result root. The bundle contains each full
binary Git diff, all thirty-one untracked source files with individual hashes,
source metadata, and build-directory byte counts. Public Git carries only the
sanitized derivative in this directory.

| Private record | SHA-256 |
| --- | --- |
| source summary | `daf5ca896b2af98e54aee43ae67fb4ba4994dc417f31b822c0384e62b06f036e` |
| untracked manifest | `8f1daa698901d60812990e9162651bb9d6d72d4b00dc043b0222dfbc0ffb90f8` |
| private bundle manifest | `740544fdef37daa31833f32fc4388458952810bed0900b26da508adc68a2fd69` |

The private bundle retains real paths and raw source deltas. The public record
uses role names and tracked repository-relative owners.

## Cleanup rule

Each cleanup candidate moves to recoverable user Trash only after the public
record reaches `main`, the final process scan again reports zero path
references, and every linked worktree is removed from its Git common
directory. The cleanup stops clone-local fsmonitor daemons first, removes
linked worktrees without force when Git accepts their state, and uses
recoverable movement for the remaining dirty standalone directories. Git
worktree pruning applies only after the exact moved path is absent.

The cleanup excludes the retained qwen-nvidia source tree, the workstation
qwen-apu runtime root, every Raven2 runtime source tree, deployment, result,
and service, and every unrelated repository or worktree.
