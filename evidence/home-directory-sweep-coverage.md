# What the sweep holds that nothing else does

`evidence/home-directory-sweep-retention.tsv` classified 125 swept directories
against committed evidence and reported 9 covered whole, 96 partly, 20 not at
all. A directory-level fraction orders where to look and decides nothing about
a file: the 96 partial rows carry 558 MiB whose disposition it leaves open,
because a directory is covered file by file rather than in proportion.

`remote/classify-sweep-coverage.py` answers the file-level question from the
inventory `evidence/home-sweep-recovery/sweep-inventory/` already retains, so
the whole classification runs on the workstation and reads nothing on the
appliance. It writes two documents through one rename each and `--check`
regenerates them into memory and refuses a stale pair, which the
`sweep-coverage-current` gate cell runs.

## The population, file by file

| Class | Files | What it means |
| --- | ---: | --- |
| independently held | 6,089 | the digest is committed at a path outside the recovery tree |
| recovered | 229 | the digest is committed only under `evidence/home-sweep-recovery/`, or its sanitized source is recorded there |
| empty | 921 | zero bytes; matches everywhere and reconstructs nothing |
| duplicate within the sweep | 3,516 | another copy of these bytes sits in the sweep; this copy alone is redundant |
| unretained | 6,853 | these bytes exist in one place |

The five classes partition the 17,608 files exactly. The unretained and
duplicate rows together name 7,427 distinct digests over 1,198,385,248 bytes
(1.116 GiB), which is the population that ends if the sweep ends.

`evidence/home-directory-sweep-coverage.tsv` carries one row per file in the 96
partial directories that the tree does not independently hold: 11,066 rows over
path, byte count, digest, and reason.
`evidence/home-directory-sweep-producers.tsv` carries the same split per
directory for all 126, beside the producer and storage columns.

## Two directories carry most of it

| Directory | Unretained | Share | Question |
| --- | ---: | ---: | --- |
| `campaigns/qwen-test-models` | 674.4 MiB over 109 digests | 59.0% | is the synthetic corpus regenerable |
| `campaigns/qwen-frozen-binaries` | 55.1 MiB over 1 digest | 4.8% | is the frozen server recoverable by rebuild |
| everything else | 413.4 MiB over 7,317 digests | 36.2% | -- |

Almost two thirds of the irreplaceable bytes reduce to two questions that were
already registered rather than to a long tail. Both remain open here: this
classification states what has no second copy and decides nothing about whether
a copy is needed.

The remainder is dominated by kernel-census campaign directories at 29 to 59
MiB each, whose raw dispatch records are the inputs behind
`evidence/raven2-vulkan-kernel-census/`. A summary standing in the tree while
its raw source exists in one place is the shape the recovery work already
found; it is recorded here as measured rather than acted on.

## The synthetic corpus is regenerable and its bytes are not

`campaigns/qwen-test-models` holds 109 GGUF files named `<arch>-dense.gguf` and
`<arch>-moe.gguf`, and the generator sits in the pinned llama.cpp tree at
`f280b26983ad0fdb705a0d9ebf0503e76f2899b0`. `tests/test-llama-archs.cpp`
constructs each model in memory through `get_gguf_ctx(arch, moe)`, and
`save_models()` writes exactly that pair of names per architecture into a
directory the caller gives it. Two facts decide what regenerating it would
produce.

Tensor data is deterministic given a seed: `set_tensor_data` builds
`std::mt19937` over `seed ^ hasher(tensor->name)`, so one seed and one revision
yield one byte sequence per tensor. The seed is not: `main` sets
`size_t seed = rd()` from `std::random_device`, and `-s`/`--seed` is the only
way to fix it.

Nothing recorded the seed this corpus was written with. The directory holds 109
`.gguf` files and no other node -- no invocation transcript, no log, no
parameter record -- and no path anywhere in the sweep names `test-llama-archs`.
A regeneration therefore produces a corpus of the same architectures at the
same shapes with different weights, and byte-exact reproduction is unavailable
rather than merely unattempted.

That is the finding, and it is not "the model loads." The bytes are
irreplaceable and they carry no measurement: they are pseudorandom weights over
an architecture list, whose whole information content is the architecture set,
the shapes, and a seed that is gone. No committed evidence cites any of the 109
digests, which the coverage join reports as zero independent matches, so no
retained result depends on these exact bytes. The claim regeneration would
support -- that llama.cpp loads each architecture -- a fresh corpus supports
equally.

This closes the question of whether the corpus is reconstructible without
spending a build and 674 MiB of writes on the appliance. It authorizes no
removal: what the artifact is worth keeping for is a decision, and 59.0% of the
unretained population resting on random weights with a lost seed is the fact
that decision needs.

## Coverage is split at its source

`refresh-evidence-manifest.sh` enumerates through `git ls-files`, so
`evidence/SHA256SUMS` names the 3.0 MiB retained under
`evidence/home-sweep-recovery/`, and a swept file whose bytes were copied there
matches its own copy. Counting that as coverage answers "this was saved" where
the question asked is "was this already saved": one is the result of an act
taken after the sweep and the other is what the sweep found. `independent` and
`recovered` therefore stay separate columns, and 229 files land in the second.

The split has to be written to hold. The reader's first form took the recovery
prefix relative to `evidence/` where a manifest path is repository-relative, so
it matched nothing and counted all 98 retained digests as independent. Nothing
in the output said so. `test-classify-sweep-coverage.py` asserts the
distinction by reason on a fixture whose recovery copy is known, and the
mutation that restores the relative prefix fails that check.

An empty file is read before coverage rather than after it. Its digest is
committed in any tree holding one empty file, so a coverage test passes it while
it reconstructs nothing; the reader's first form classified all 915 of them as
covered. Both defects moved the headline in the same direction, which is the
direction a coverage figure drifts when nobody checks it.

## What a directory-level column no longer says

The historical `files_digest_in_evidence` column is preserved as the join that
was run. Recomputing it now under the independent-only rule differs on two
directories -- `campaigns/qwen-fixed64-main-5ce0f3c` reads 2,004 against 2,009
and `campaigns/fixed64-scoreboard-20260901T2011Z` reads 130 against 131 -- so
six files that matched committed evidence in that join no longer do. Committed
evidence moved between the two readings.

Coverage is therefore a measurement with a date rather than a property of the
sweep. An evidence file edited after a join silently lowers the coverage of
every swept file that matched its previous bytes, and nothing announces it. The
`sweep-coverage-current` gate cell exists for that: the derived documents are
regenerated and diffed on every gate run, so the drift is caught at the commit
that causes it.

## Producer, storage, and what an inventory cannot say

Three identities stay separate. `storage_role` is `raven2-appliance` for every
row and is stated rather than derived: the sweep lives in one place, and a copy
taken to the workstation would move that column and leave the producer
untouched.

`producer_role` reads `raven2-appliance` for 25 directories and `unknown` for
101. The attribution is by artifact rather than by location: the
graphics-latency probe and the kernel-hazard watcher run inside the guarded
launch chain against the Vulkan device, and the clock sidecar and telemetry log
read the amdgpu DPM attributes under `/sys/class/drm`, none of which a
workstation carries. `producer_evidence` names the artifacts found.

That claim is narrow on purpose. It states the directory holds bytes produced on
the Raven2, not that every byte in it was: a campaign directory also holds
downloaded checkpoints and binaries a workstation container built. The 101
`unknown` rows are not a gap to be filled by inference from where the files sit.
Attributing them needs a receipt read inside each acquisition, which is a bulk
read of 1.26 GiB against two cores; the appliance was serving when this ran
(`state=running`, load 1.84), so that read belongs in a named window rather than
beside a live session.

## Falsifiers

- The five classes fail to partition the file population exactly.
- A file whose bytes are committed only under `evidence/home-sweep-recovery/`
  reads as independently held.
- An empty file reads as covered.
- Unretained bytes are summed per file rather than per distinct digest.
- A directory carrying no device-only artifact reads as appliance-produced.
- The committed documents differ from what the reader derives.

## What this does not decide

It authorizes no deletion. `remote/check-deletion-plan.sh` refuses any plan
holding an unreviewed acquisition, and every directory here is unreviewed, so
the sweep stands protected while these questions stay open. It proves no
reconstruction: `qwen-test-models` is 674 MiB with no second copy, and whether a
generator reproduces those exact bytes is unmeasured. It verifies no retained
destination, which is why `check-deletion-plan.sh` refuses a disposal resting on
one.
