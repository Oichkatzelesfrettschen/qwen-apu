# The withheld checkpoints: what the appliance removes, and how the plan admits it

Eight registry rows stand withheld. `remote/quarantine.tsv` carries a
model-scope row for each, `evidence/quarantine/<id>.md` carries its reason and
re-entry gate, the row's fetch script refuses at its top, and
`qwen-apu models install` refuses any group naming the id. The tree is complete;
what remains is the disk, and this document is the input the appliance run
reads.

## The exact payload

Nine files across seven directories under `$QWEN_HOME/models/`. Two directories
hold two withheld artifacts apiece -- the 27B ladder's two quants, and the
Ministral checkpoint beside the projector that encodes into it -- which is what
makes a directory-granular acquisition safe here: no retained row shares either
directory.

| model id | relative path under `models/` | bytes |
| --- | --- | ---: |
| `qwen38-4b-i1-q2k` | `Qwen3.8-4B-Distill-Q2_K-GGUF/Qwen3.8-4B-i1-Q2_K.gguf` | 1,959,168,512 |
| `qwen38-4b-i1-q5km` | `Qwen3.8-4B-Distill-Q5_K_M-GGUF/Qwen3.8-4B-i1-Q5_K_M.gguf` | 3,161,426,432 |
| `qwen38-4b-i1-q6k` | `Qwen3.8-4B-Distill-Q6_K-GGUF/Qwen3.8-4B-i1-Q6_K.gguf` | 3,563,028,992 |
| `qwen38-9b-distill` | `Qwen3.8-9B-Distill-GGUF/Qwen3.8-9B-Q4_K_M.gguf` | 5,780,090,176 |
| `qwen38-27b-q2kxl` | `Qwen3.8-27B-GGUF/Qwen3.8-27B-UD-Q2_K_XL.gguf` | 9,828,981,664 |
| `qwen38-27b-iq3xxs` | `Qwen3.8-27B-GGUF/Qwen3.8-27B-UD-IQ3_XXS.gguf` | 10,934,860,704 |
| `nanbeige42-3b` | `Nanbeige4.2-3B-GGUF/Nanbeige4.2-3B-Q4_K_M.gguf` | 2,574,807,986 |
| `ministral3-3b` | `Ministral-3-3B-Instruct-GGUF/Ministral-3-3B-Instruct-Q4_K_M.gguf` | 2,146,498,528 |
| `ministral3-3b-mmproj` | `Ministral-3-3B-Instruct-GGUF/mmproj-Ministral-3-3B-Instruct-f16.gguf` | 840,297,088 |

40,789,160,082 bytes, 37.99 GiB. Every count is `remote/model-artifacts.tsv`'s
own `expected_bytes` column beside the digest that verified the fetch.

The seven acquisition objects the plan classifies:

```text
$QWEN_HOME/models/Qwen3.8-4B-Distill-Q2_K-GGUF
$QWEN_HOME/models/Qwen3.8-4B-Distill-Q5_K_M-GGUF
$QWEN_HOME/models/Qwen3.8-4B-Distill-Q6_K-GGUF
$QWEN_HOME/models/Qwen3.8-9B-Distill-GGUF
$QWEN_HOME/models/Qwen3.8-27B-GGUF
$QWEN_HOME/models/Nanbeige4.2-3B-GGUF
$QWEN_HOME/models/Ministral-3-3B-Instruct-GGUF
```

A directory holding one file beyond its rows above is a stop rather than a
detail: a stray `.part`, a second quant, or a projector no row names is inside
the fingerprint and inside the payload manifest, and removing the directory
removes it too. The run confirms each directory's contents against this table
before it writes a decision.

## The invocation shape, and the seam in it

`remote/check-deletion-plan.sh` classifies a whole removal action rather than a
subset. `root_entries_of` selects `models` under `purge` alone, so `plan purge`
is the only plan that reaches these seven objects, and `plan uninstall` never
sees them. The removal this document prepares is not a purge: it takes seven
objects out of `models/` and leaves the root standing.

The run therefore reads the purge plan for its identity and takes a per-object
verdict against it, without executing purge:

```sh
# 1. The plan identity the authorizations bind to. The whole-root report is
#    read for plan_sha256; nothing in it is executed. This invocation exits
#    1 on this root by design -- every directory under results/ reads
#    unreviewed -- and the plan_sha256= line prints either way. Capture the
#    value once and pass it unchanged to every verdict: re-deriving it after
#    any change under the root yields a different identity, and every
#    authorization already written against the first refuses as stale.
remote/check-deletion-plan.sh plan purge

# 2. Per directory: the payload manifest an intentional discard requires.
remote/check-deletion-plan.sh payload-manifest \
    "$QWEN_HOME/models/Qwen3.8-27B-GGUF"
remote/check-deletion-plan.sh fingerprint \
    "$QWEN_HOME/models/Qwen3.8-27B-GGUF"

# 3. Write $QWEN_HOME/models/<DIR>/.acquisition/decision.tsv, tab separated,
#    all eight keys present:
#      acquisition_id         the directory's own basename
#      metadata_fingerprint   step 2's fingerprint
#      payload_manifest       step 2's payload manifest
#      decision               dispose
#      reason                 intentional-discard
#      retained_destination   -none-, the withholding retains no copy
#      retained_digest        -none-
#      authorization          authorization.tsv
#    and beside it authorization.tsv with all six keys:
#      acquisition_id  payload_manifest  action  plan_sha256
#      authorized_by   authorized_at
#    where action is `purge` and plan_sha256 is step 1's.

# 4. The verdict, per directory. `admit<TAB>intentional-discard` is the
#    only result that admits a removal.
remote/check-deletion-plan.sh verdict \
    "$QWEN_HOME/models/Qwen3.8-27B-GGUF" acquisition purge "$plan_sha256"

# 5. Remove exactly the seven directories, after all seven read `admit`.
```

Two properties of that shape are stated rather than assumed. The authorization
binds to a plan identity whose action the run does not execute, which is what
makes step 1's report a source of identity rather than an instruction; the
binding still does its work, because a record replayed against a different
selection fails the `plan_sha256` comparison in `object_verdict`. And
`reason` is `intentional-discard` rather than `verified-copy-retained`: the
withholding keeps no copy anywhere, and `verified-copy-retained` refuses with
`destination-unverified` by design, since permitting it would assert a
destination this removal does not have.

A decision sealed before a byte moves is stale the moment the directory
changes: writing the records moves bytes only inside the excluded
`.acquisition/` subtree, so the fingerprint and the plan identity both hold
still between step 2 and step 5. A fetch or a rename in that interval is what
`changed-since-review` catches.

## What the run does not need

No device window, no server teardown, and no sudo. The seven directories carry
no serving role -- `remote/build-router-presets.sh` writes no preset section for
an `archive`, `rejected`, or model-scope-quarantined row, so no live preset
names a path inside them -- and `remote/select-projector.sh` searches a model
file's own directory, which for the Ministral projector goes with the
checkpoint.

After the removal, `qwen-apu models verify --artifacts` reports each of the
nine artifact ids above as `withheld` and exits zero, which is the receipt that the tree and
the disk agree.
