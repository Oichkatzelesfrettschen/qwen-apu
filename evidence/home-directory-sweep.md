# The appliance home directory, swept into the runtime root

The appliance wrote 381 non-dotfile entries into `$HOME` over the campaigns this
tree records: 130 directories and 251 loose files, one of which is the analysis
script `arm-stats.py` rather than a log. `AGENTS.md` states that every generated
byte of the appliance lives in one declared runtime root, and `make doctor`
reports predecessor paths outside it, but a campaign output directory placed
directly under `$HOME` was outside the doctor's enumeration and so accumulated
unreported. On 2026-09-06 all of it moved to
`$QWEN_HOME/results/home-sweep-20260906/`, and `MANIFEST.tsv` beside it carries
one row per directory with its byte count and file count.

The sweep moves rather than deletes, because a measurement this tree cites is
worth more than the disk it occupies.

Five of those 130 directories are structural rather than campaign output --
`opt`, `src`, `vmware`, `worktrees`, and `qwen-gate-lanes` -- and all five were
empty. The sweep took them because it treated every non-dotfile home entry as
campaign output. `~/worktrees` is returned, since the agent guide declares
`~/worktrees/<repo>/<branch>` as the home a worktree lives in; the other four
stay gone, because `.runtime/opt` is where installed prefixes belong and
`~/src` and `~/vmware` name nothing this tree owns. The sweep therefore holds
125 campaign directories and the `logs` bundle, and `Github` and `worktrees`
are the two non-dotfile entries in the home directory.

## The population, measured

The move is complete and lossless by count: `find -type f` under the sweep
returns 17,608, which is the manifest's own 17,607 plus `MANIFEST.tsv`. The
tree holds no symbolic link. Six nodes are named pipes -- the `broker-control`
FIFOs of the two `raven2-dpm-authority-20260902T18*Z` runs -- which `-type f`
excludes, so the manifest counts a file population and the FIFO count is
recorded here rather than there.

`MANIFEST.tsv` states apparent size. The whole sweep reads 1,356,625,579 bytes
apparent against 1,410,531,328 allocated, so allocation exceeds content by
51.4 MiB, or 4.0%, across 17,607 mostly small files. Nothing is sparse:
`qwen-test-models` reads 707,196,032 apparent against 707,457,024 allocated
over 109 files. A reclamation figure taken from this sweep is therefore
1.31 GiB of disk against 1.26 GiB of content, and the difference is block
overhead rather than a compression or hard-link saving.

Content repeats inside the sweep, and the count states its population.
`MANIFEST.tsv` carries a digest no other file matches, so it moves the file
count and the distinct-digest count together: 17,608 files over 10,702
distinct digests, and the 17,607 the manifest itself describes over 10,701.
Either reading leaves 6,906 files duplicating an earlier one and 96.52 MiB of
the 1293.77 MiB a second copy of something already present.

## What committed evidence already holds

`evidence/home-directory-sweep-retention.tsv` carries one row per swept
directory: its manifest bytes and file count, the number of its files whose
SHA-256 appears anywhere in the committed `evidence/` tree, and the resulting
retention class. Every file on both sides was hashed for that join. The
per-file digest list lives at
`$QWEN_HOME/results/home-sweep-20260906-inventory/sha256.txt`, SHA-256
`f3d5cdac2a36436c31f43ed9c464da75032831cccf6d39438dace81d6c04e554`, beside
`nodes.tsv`, SHA-256
`d249352f5262fce07ddd60d1c5730cd39f9a5f114dd945a22265463d189ccc84`.

| retention class | directories | bytes |
| --- | ---: | ---: |
| every file's digest is in `evidence/` | 9 | 0.88 MiB |
| some file's digest is in `evidence/` | 96 | 558.53 MiB |
| no file's digest is in `evidence/` | 20 | 734.36 MiB |
| empty | 1 | 0 |

Read that table for what it measures. A digest match proves the exact bytes
are committed; a digest miss proves only that those exact bytes are not, and
this tree gives two routine reasons a retained measurement misses. The
repository sanitizes the private hostname to `qwen-laptop`, the home prefix to
`$HOME`, and MAC addresses to `<mac>` before committing, so a path-bearing file
diverges in digest while its substance is retained whole. A large campaign
deliberately retains decisive-arm summaries and receipts rather than every raw
per-dispatch table, so a partly retained directory is the ordinary shape of a
correctly retained campaign rather than a gap. The two calibration-v10 census
runs read 104 of 590 and 150 of 592, which is that shape.

The consequence is that `retained-partial` is a coverage measurement and not a
verdict, and 96 directories carry one. Deciding whether the uncommitted
remainder of any of them is disposable requires reading the files, which this
join does not do.

`qwen-test-models` is the largest single entry at 674.4 MiB, 52.1% of the
sweep, and holds none of this tree's checkpoints: 109 synthetic
per-architecture GGUF stubs, from `arcee-dense.gguf` to `xverse-dense.gguf`,
whose digests match no `expected_sha256` in any fetch script and no file under
the root's own `models/`. It is llama.cpp's architecture-coverage corpus, and
the recipe that produced it is unrecorded here, so it is a reconstruction
candidate rather than a proven-redundant one.

`qwen-frozen-binaries` holds one `llama-server` whose digest is
`40f7b775074e7d207dc2ad12f1aefc9635bd3904d5c35b68c8e43483622c4005`, and the
runtime root carries those exact bytes twice, at
`deployments/emergency-forced-tail-40f7b775/llama-server` and at
`-r2/llama-server`. Its 55.06 MiB is redundant by digest against a location
that survives `uninstall` no better than the sweep does.

## What committed evidence cites

Forty-one of these directories are named inside committed evidence files, some
heavily: 72 files each cite the four `q4k-served-ab-*` runs, 41 cite
`fixed64-scoreboard-20260901T2011Z`. A `$HOME` path in a committed record is a
sanitized historical path rather than a live pointer, which the tree already
demonstrates: `$HOME/qwen-webui-state` appears in 1307 committed files and
`make purge-legacy` removed that directory with no record broken.

The one case where a citation names bytes rather than a location is the E1
shader lab, whose receipts cite `$HOME/e1-lab-20260902/spv/e4-nsh.spv`. That
receipt carries `spirv_sha256` and `spirv_bytes` on the lines beside the path,
so the module is identified in the committed record. A digest identifies bytes
without retaining them: the six `raven2-e1-isa-*-modules` directories hold
those modules, no file in any of them matches a committed digest, and the
committed receipt is a check on a module rather than a copy of it. Regenerating
them from the pinned source and patch series is a reconstruction, and no run
has performed it.

Documentation names three home paths that no longer resolve, and the sweep is
what exposed them rather than what broke them. `AGENTS.md` runs its command
block from `~/qwen-laptop-setup/remote/`, which the appliance has never held
under that name, and reads `GGUF_PY_PATH=~/src/llama.cpp-qwen-apu/gguf-py`,
where the source trees live at `.runtime/opt/llama.cpp*`. Three scripts still
default an installation prefix to `~/opt`:
`remote/fetch-shaderc-toolchain.sh`, `remote/build-spirv-shader-pack.sh`, and
`remote/install-yacy.sh`, so the mechanism that put products in the home
directory remains armed at its default.

## The unmatched residue

Twenty directories hold no file whose digest is committed. Two of those are the
upstream corpus and the duplicated binary above. The remaining eighteen total
4.86 MiB, and two are gaps the tree names itself:

- `qwen-representation-arm`, 30 files, holds the two ABBA runs behind
  `evidence/representation-gate-16-bit.md`, which states at line 114 that "the
  retained repository lacks the raw arms and a weight-level identity witness."
- `qwen-universal-sweep`, 29 files, holds the raw fourteen-arm sweep behind the
  seven-checkpoint comparison in
  `evidence/model-admission/universal-candidate-ladder.md`. That document's
  9.01 and 11.61 GB/s figures, and the 11.1% and 11.5% offsets AGENTS.md quotes
  from them, have no raw backing anywhere under `evidence/`.

The rest -- the six E1 module directories, `raven2-e4-quality-20260903T0527Z`,
`qwen-build-logs`, `qwen-quality-gate`, `qwen-priority-probe`,
`qwen-kv-cache-factorial`, `qwen-dpm-force`, `qwen-bench-repeatability`, and
three `image-admission-20260829*` runs -- are cases where a committed document
quotes the derived numbers and the raw logs were never copied. Each is a weaker
claim than the two above, since the finding is retained and only its transcript
is not.

The `logs` bundle is unmatched on the same measure: 251 files, 5.30 MiB, two
digests committed. It holds `arm-stats.py`, which is a derivation rather than a
transcript and has no counterpart under `remote/`.

Promoting any of these into `evidence/` is a separate decision per directory,
and this record exists so that decision reads from a measurement rather than
from a directory listing. `evidence/home-sweep-recovery/` carries the first
of those decisions: both named gaps, the 29 executed SPIR-V modules the E1
receipts identify by digest and no committed file held, the sweep's own
per-file inventory, and the loose analysis script, each with the
transformation record `remote/retain-acquisition.sh` wrote beside it.

## The sweep now sits inside a deletion boundary

`runtime-root.sh` removes every root entry except `state` and `models` on
`uninstall`, and every entry on `purge`. `results/` is therefore removed by
both, so the move carried 1.26 GiB from a location outside every cleanup
enumeration into one inside two of them. Both refuse without
`QWEN_RUNTIME_ROOT_CONFIRM` naming the exact root while the marker binds it to
a production checkout, so no bare command reaches it, and the refusal text
describes what it removes as "74 GB of reproducible products", which the
unmatched residue above contradicts.

`make doctor` reports predecessor paths outside the root, foreign entries under
it, and transient system state. It reads the declared layout and the enumerated
legacy locations; it establishes nothing about whether an object under
`results/` carries provenance, a retention decision, or a second recoverable
copy. Making the cleanup commands refuse an acquisition under `results/` that
carries no retention decision is the repair this record argues for and does not
make.
