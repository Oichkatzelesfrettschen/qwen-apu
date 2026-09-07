# Recovered from the home-directory sweep

`evidence/home-directory-sweep-retention.tsv` joins every swept directory
against committed `evidence/` by SHA-256 and reports 9 directories whose every
file digest is committed, 96 partly, 20 with none. This directory retains the
sources that join found irreplaceable, at 3.0 MiB, and states what each closes.
The originals stay in the sweep under `$QWEN_HOME/results/`; nothing here
authorizes removing them.

Read the coverage column for what it measures. A digest match proves the exact
bytes are committed. A miss proves only that those exact bytes are not, and a
sanitized file correctly misses while its substance is retained, a committed
summary correctly stands while its raw source is irreplaceable, and a match on
an empty file or a repeated status line contributes nothing toward
reconstructing an experiment. Coverage orders where to look; it decides
nothing on its own.

`remote/retain-acquisition.sh` performed each copy. It reads the source and
never writes it, applies the repository's three substitutions -- the private
hostname to `qwen-laptop`, the serving user's home prefix to `$HOME`, and a MAC
address to `<mac>` -- and writes `transformation.tsv` beside the copy carrying
the source digest, the retained digest, and the substitution count per file. A
file whose content is not text passes through byte-for-byte and records
`binary`, since substituting inside a compiled module would corrupt the
artifact its digest identifies. A reader holding only the retained copy can
therefore separate a sanitized substitution from an edit.

## The two gaps the tree names about itself

`representation-arm/` holds the 30 files of both ABBA runs behind
`evidence/representation-gate-16-bit.md`, which states at line 114 that "the
retained repository lacks the raw arms and a weight-level identity witness."
Twenty files carried the home prefix and were substituted; ten are identical to
their source. The weight-level identity witness that record also names remains
absent: these are the measurement arms, not a tensor-value comparison, and the
17.41 against 11.78 GiB tok/s difference the document reports is now backed by
the logs and clock samples that produced it.

`universal-sweep/` holds the fourteen `llama-bench` arms behind the
seven-checkpoint comparison in
`evidence/model-admission/universal-candidate-ladder.md`, mirrored forward and
reverse over seven checkpoints, with no substitution: all 29 files are
identical to their source. `parsed-arms.tsv` carries the extracted rows.

That document's figures reproduce from these arms. Its 9.19 decode tok/s,
63.85 prefill tok/s, and 11.61 GB/s for the 2B distill are the paired means of
slots 4 and 11 exactly; the 4B distill's 3.34, 22.40, and 9.01 are slots 7 and
8 to the rounding of one mean. The 11.5% and 11.1% offsets AGENTS.md quotes
follow from those against the 10.41 and 8.11 GB/s four-block means of
`evidence/decode-bound-analysis.md`. The paired span within this sweep runs
from 0.3% on both 4B rows to 7.2% on the 0.8B Q8_0, which is the scatter the
document reads its ratios inside.

## The executed modules

`e1-modules/` closes an identity-without-retention case rather than a
measurement gap. The E1 shader-lab receipts cite each module by
`spirv_sha256`, and a digest identifies bytes without retaining them: every one
of the 29 distinct modules is cited somewhere under `evidence/`, and none was
held there. They are held here now.

The store is content-addressed, so each module's filename is its own SHA-256
and every blob is stored once. `acquisitions.tsv` keeps the provenance that
deduplication would otherwise drop: one row per acquisition and module over the
six `raven2-e1-isa-*-modules` directories, 168 rows across 6 acquisitions and
29 modules.

The six acquisitions hold two module sets. Twenty-seven modules appear in all
six. `a9ac07dd4063e0903662cd5f1be68a5c2fbf06b0de924acd223525c7e4519d0d` appears
in the five production-series acquisitions and
`180da20e51c7163aa3af133dfece267092bbc2b706e7cfe91c10da9b91986908` in the E4
candidate alone, so the candidate arm swaps exactly one module against the
series and the other twenty-seven are the same bytes compiled again.

## The memory and firmware captures

`captures/` holds 25 files at 442 KiB that the file-level coverage join read as
existing in one place: the 18 top-level nodes of the HP memory and firmware
root-cause acquisition, including both SPD EEPROM images, and seven of the GPU
decomposition, including `raven2-vbios.rom` and the five per-target ISA
disassemblies. Every source digest was verified against `sweep-inventory/`
before the copy. `remote/sanitize-capture.py` performed each one under the same
three substitutions `retain-acquisition.sh` applies and records
`sanitizer_sha256` beside the two content digests, so a retained record binds
its substitutions to the reader that made them. The three binary artifacts pass
through byte-for-byte, since substituting inside a register dump or a ROM image
corrupts the artifact its digest identifies.

## What wrote each acquisition

`producer-receipts.tsv` carries one row per receipt read inside a directory the
artifact-marker rule left unattributed, its matched token, and the role that
token derives. It records the silent receipts too, because a receipt opened and
found to name no machine is a result. `classify-sweep-coverage.py` folds it into
`producer_role` without inferring from location, and a directory whose marker
and whose receipt disagree reads `mixed` rather than either.

## The sweep's own inventory

`sweep-inventory/` holds the per-file population the retention join was
computed from: `sha256.txt.gz` over 17,608 files, `nodes.tsv.gz` carrying the
type and byte count of every node, and the sweep's own `MANIFEST.tsv`.
`identity.tsv` records each one's SHA-256 and byte count.

They are retained here rather than only under `$QWEN_HOME/results/` because a
digest recorded beside an inventory that lives inside the same deletion
boundary repeats at one level up the problem the modules above closed:
`runtime-root.sh` removes `results/` on both `uninstall` and `purge`, so an
inventory retained only there is identified rather than kept.

## The derivation

`derivations/arm-stats.py` is the analysis script that sat loose among the 251
swept log files. It walks `arms/*/`, joins each arm's `telemetry.log` with its
`graphics-latency.log`, and emits one row per arm carrying peak VRAM, GTT and
RSS, minimum available memory, swap-in bytes, maximum temperature, the selected
graphics and fabric clock sets, sample count, and latency count, p90, maximum,
and breach count.

`remote/summarize-telemetry-session.sh` summarizes one session and reads no
latency log, so the cross-arm join and the latency columns have no counterpart
under `remote/`. Which committed figures this script produced is unestablished,
and promoting it into `remote/` waits on that reading rather than on its
absence being noticed.

## Corrections to the sweep record

The duplicate-file arithmetic in `evidence/home-directory-sweep.md` mixed two
populations. `MANIFEST.tsv` carries a digest no other file in the sweep
matches, so removing it from the population drops the file count and the
distinct-digest count together: 17,608 files over 10,702 distinct digests, and
17,607 over 10,701. The duplicate count is 6,906 under either reading, and the
duplicated bytes are 96.52 MiB. The record stated 17,607 against 10,702, which
pairs a count from one population with a count from the other.

## What is not decided here

`qwen-test-models` at 674.4 MiB is reconstruction unproven rather than
redundant. Its generator, command, input configuration, and dependency
versions in the pinned llama.cpp source are unrecorded, and no regeneration
has run, so its 109 stubs stay as they are. Size is a reason to investigate
rather than a finding about disposability.

`qwen-frozen-binaries` holds one `llama-server` byte-identical to
`deployments/emergency-forced-tail-40f7b775/llama-server` and its `-r2`. That
establishes duplication and not recoverability: all three copies live under the
same runtime root, which `uninstall` and `purge` both clear.
`frozen-binary-control.md` answers the recoverability question and answers it
no. No artifact manifest in the tree or on the appliance names that binary's
digest beside a commit, a patch series digest, and compiler and CMake flags; the
two that name it at all are the deployment bundle's own two-row records, and
`frozen-binary/artifact-manifest.tsv` retains one of them verbatim at the
`81c73bbb...` three committed bundle manifests bind. The directory stays because
the artifact cannot be rebuilt rather than pending a check of whether it can.

The 96 partly covered directories are classified per directory and not per
file. Each needs its unmatched files given a disposition, and a verified
durable archive is an admissible retention location for a raw table rather than
a commit into this tree.
