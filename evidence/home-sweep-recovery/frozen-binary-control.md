# The frozen binary has a binding record and no rebuild record

`campaigns/qwen-frozen-binaries` holds one file,
`llama-server.production.40f7b775074e7d207dc2ad12f1aefc9635bd3904d5c35b68c8e43483622c4005`,
at 57,736,112 bytes. `evidence/home-directory-sweep.md` records that the runtime
root carries those exact bytes twice more, at
`deployments/emergency-forced-tail-40f7b775/llama-server` and its `-r2`, and
that all three copies sit inside one `uninstall` boundary. Duplication inside
one boundary is not a second copy, so the question the retention decision turns
on is whether the binary is recoverable by rebuild. That question is answered
here and the answer is no.

## What a rebuild record is

`remote/build-llama-preset.sh` writes `artifact-manifest.tsv` beside every build
it produces, carrying the preset, the llama.cpp commit, the worktree state, the
checkpoint semantics with the patch, source, and series digests that earned the
declaration, `compiler_flags`, `cmake_flags`, and one `executable` row per
binary with its byte count and SHA-256. Those fields together state the source,
the ordered patch series, and the toolchain configuration a rebuild reproduces
from. `evidence/ctx-checkpoint-natural-boundary/promotion/artifact-manifest-head.tsv`
retains that head for the successor build
`5dd86b90154f6143a5303efd2590b9268a0a5e3e908c4d6791f1fde03a4782c2`, which is
what such a record looks like when it exists.

## No manifest anywhere names 40f7b775 with those fields

Two searches were run and both came back empty of build identity.

Committed evidence: `evidence/ARTIFACT_MANIFEST.tsv` names four binaries and
none of them is this one. Twelve committed files cite the digest -- provenance
records, binary lists, and three `emergency-bundle-manifest.tsv` copies -- and
each cites it as an identity rather than as a build.

The appliance: every `artifact-manifest*.tsv` under the runtime root within four
directory levels was enumerated and grepped for the digest. Exactly two match,
`deployments/emergency-forced-tail-40f7b775/artifact-manifest.tsv` and its
`-r2`, and both hash to
`81c73bbb409636fe8d7b5d83b658da1093ca9bd3121d8bf4cfe481b074059b5d`, the value
all three committed `emergency-bundle-manifest.tsv` records already bind to that
bundle. The fetched copy reproduces that digest, so the retained manifest is the
one the bundle bound to this exact server, and it is retained verbatim at
`frozen-binary/artifact-manifest.tsv` with zero substitutions.

It carries two rows:

```text
checkpoint_semantics    unknown
executable      llama-server    57736112        40f7b775...c4005
```

`build-deployment-bundle.sh` copies the manifest its caller names rather than
deriving one, so this file is the minimal record the bundle layer requires --
one `checkpoint_semantics` row and one `executable` row matching the bundled
server -- written for a binary that arrived without a build manifest. It states
the identity and the checkpoint capability. It states no commit, no patch series
digest, no compiler flags, and no CMake flags.

`campaigns/qwen-frozen-binaries` itself holds the binary and nothing else: the
sweep inventory records one node under that directory.

## What is recorded about the build, and what it leaves open

`evidence/ctx-checkpoint-sweep/provenance.txt` is the closest thing to a source
statement. It names `llama_cpp_commit=f280b26` and the build path
`$HOME/src/llama.cpp-qwen-apu/build-appliance-current/bin/llama-server` beside
the digest. A commit alone underdetermines the artifact: this tree's builds
apply an ordered patch series over that same commit, and
`remote/verify-llama-patch-series.sh` exists because the series rather than the
commit decides the source. The manifest's `checkpoint_semantics` of `unknown` is
the direct evidence that the series is unidentified --
`remote/classify-checkpoint-semantics.sh` writes `natural-boundary-v1` only
against source hashing to `3744317b...` and `forced-tail-v1` only against the
pinned commit's own `a79cf9e1...`, and every other source reads `unknown`. This
binary's source matched neither.

A rebuild from `f280b26` therefore reproduces neither the source nor the
executable. Which patches it carried, in what order, under which compiler and
CMake flags, is unrecorded, so bit identity is not merely unmeasured: the inputs
a measurement would compare against are absent.

## The decision this supports

Recoverability by rebuild is refuted rather than unproven, so the sweep copy and
its two deployment siblings are the only existing form of this artifact, and all
three go together on `uninstall`. That is the fact a retention decision needs.

This authorizes no removal and requests none.
`remote/check-deletion-plan.sh` refuses a plan holding a bundle no role link
names and refuses an unreviewed acquisition, and both refusals stand here. What
changes is the reason: the directory is retained because the artifact cannot be
rebuilt, rather than pending a check of whether it can.

A second reason narrows what recovery would restore even if a rebuild were
possible. `evidence/ctx-checkpoint-natural-boundary/promotion/frozen.stderr`
retains the capacity policy refusing this binary against the ledger's own
positive count, because a positive `--ctx-checkpoints` requires
`natural-boundary-v1` and this manifest declares `unknown`. Its serving role is
therefore the all-zero-ledger rollback alone, which is exactly the role
`emergency-forced-tail-40f7b775-r2` fills.

## Falsifiers

- An `artifact-manifest.tsv` naming `40f7b775...c4005` beside a commit, a patch
  series digest, and compiler and CMake flags is found in the tree or on the
  appliance. The claim here is that the two matching manifests carry two rows;
  a third manifest carrying more refutes it.
- The retained `frozen-binary/artifact-manifest.tsv` fails to hash to
  `81c73bbb409636fe8d7b5d83b658da1093ca9bd3121d8bf4cfe481b074059b5d`, which
  would mean the retained copy is not the one the three bundle manifests bind.
- A rebuild record is produced later and a rebuilt binary hashes to
  `40f7b775...c4005`, which would establish bit-identical recovery and retire
  this file.

## What did not run

No rebuild was attempted. It requires the appliance's two cores for a full
llama.cpp build, and with the source series unidentified there is no candidate
configuration to build, so the run has no defined arm.

No byte comparison was made against the sweep copy or either deployment copy.
`evidence/home-directory-sweep.md` records their digest equality from the
retention join, and this file adds no second reading of it.
