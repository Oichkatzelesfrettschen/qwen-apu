# Deployment epochs

An epoch is the interval a served bundle keeps one identity: one main commit,
one synced runtime tree, one activated bundle, and, where the LAN lane is
armed, one exposure boundary. `remote/write-deployment-receipt.sh` reads that
identity off the running appliance and `remote/verify-lan-site.sh` reads the
served behavior a LAN peer actually gets. Neither script infers the other's
result -- the receipt names what the appliance claims to be running, and the
site verification measures what a peer on the network receives from it --
so an epoch is confirmed only where both agree: the receipt names a commit,
and a tag on that commit is the durable pointer a later reader follows back
to the source tree the receipt's own digests were computed over.

## The receipt schema

`remote/write-deployment-receipt.sh ROOT OUTPUT_TSV` writes one field per row:
`field`, `value`, `source_path`, tab-separated, with a header comment row and
a closing `receipt_sha256` row whose value is the digest over every row above
it and whose `source_path` is the receipt file itself.

| field | what it names | source |
| --- | --- | --- |
| `main_commit` | the git commit the synced runtime tree was digested from | `runtime-tree-manifest.tsv`'s `git_head` row |
| `runtime_tree_digest` | the `remote/` payload's own tree digest | the same manifest's `remote_payload_tree_sha256` row |
| `patch_tree_digest` | the `patches/` payload's own tree digest | the same manifest's `patches_payload_tree_sha256` row |
| `server_digest` | the bundled `llama-server` binary's SHA-256 | the active bundle's `bundle-manifest.tsv` |
| `bundle_digest` | the bundle manifest's own SHA-256, the bundle's identity fingerprint | the same file |
| `router_preset_digest` | the bundled `router-presets.ini`'s SHA-256, or `-` where the bundle carries none | the same file |
| `web_preset_digest` | the bundled `web-presets.ini`'s SHA-256, or `-` | the same file |
| `model_ledger_digest` | the model registry's own SHA-256 | `remote/models.tsv` |
| `checkpoint_ledger_digest` | the bundled context-checkpoint ledger's SHA-256 | the bundle's `ctx-checkpoints.tsv` |
| `tool_prefix_identity` | `<candidate_series>:<candidate_series_sha256>` from the build that produced the bundled server; `-:-` where the build carried no candidate patches, which is every production build until `patches/llama-server-prefix-checkpoint.patch` is promoted | the bundle's `artifact-manifest.tsv` |
| `open_lan_policy_identity` | the `lan_exposure=... lan_address=... lan_name=... lan_open=...` substring `qwen-webui-session.sh` appends to its `state=running` line, or `no-running-session` where the session status names no running session | `$QWEN_RECEIPT_STATE_DIRECTORY/session.status`, default `~/qwen-webui-state/session.status` |

Every row but the last is read from a file this script verified before it
read a byte of it: `check-runtime-tree.sh` recomputes the runtime tree's own
digests ahead of the first four rows, and `resolve-active-deployment.sh`
verifies the bundle whole ahead of the rest. A row therefore never names a
file this run failed to confirm; an unsynced or divergent runtime tree, or a
deployment root with no active bundle, refuses the whole receipt rather than
writing a partial one. `open_lan_policy_identity` is the one field read
without a verification step, because a stopped session is a legitimate state
to write a receipt against -- binding the identity of a bundle a peer is no
longer being served -- and `no-running-session` states that plainly rather
than refusing.

`tool_prefix_identity` is worth reading literally rather than as a pass/fail:
`evidence/tool-prefix-checkpoint/README.md` registers that the candidate
patch reaches no production build, so every checked-in bundle reads `-:-`
here. The live checkpoint behavior `remote/verify-lan-site.sh`'s
`tool_prefix_checkpoint` row measures is the mechanism that same README
attributes to the *unpatched* server on this hybrid architecture -- the
natural checkpoint boundary the eighth production patch already ships --
so a passing site verification and a `-:-` receipt field are the expected
pairing, not a contradiction. A receipt naming a non-`-` candidate series
states that this appliance ran the further candidate arm the README's own
measurement design describes as unrun.

## The tag rule

An epoch a reader should be able to return to gets a git tag on the main
commit its receipt names: `deploy/<bundle-name>`, where `<bundle-name>` is
the bundle's own name field (`bundle_name` in `bundle-manifest.tsv`, and the
same string `receipt_sha256`'s row covers indirectly through every digest
above it). The tag is pushed to the same remote the source tree was synced
from, so `git log --oneline --all | grep deploy/` on the workstation finds
every epoch a bundle was ever cut for, whether or not that bundle still
exists on the appliance.

A tag names a commit, not a receipt: two receipts written minutes apart
against the same activated bundle both name the same `main_commit`, and one
tag serves both. A new tag is warranted where the bundle changes -- a new
`bundle_digest`, a new `server_digest`, or a new `checkpoint_ledger_digest` --
because a fresh bundle is a fresh epoch even where the source commit it
derives from has not moved (a re-assembled bundle from an unmodified build,
say, or a ledger edit rebuilt without a new commit). The receipt's own
`bundle_digest` row is what a tagger reads to decide whether the currently
tagged epoch still matches what the appliance is serving.

## Reading a receipt against a site verification

`remote/verify-lan-site.sh SITE_URL OUTPUT_DIR` and
`remote/write-deployment-receipt.sh ROOT OUTPUT_TSV` answer different
questions from different vantage points and are not required to run from the
same machine: the receipt reads local files on the appliance, and the site
verification reads the network the way a LAN peer does. A closed epoch's
record is the pair together -- the receipt naming what was running, the
verification naming what a peer received from it, and the git tag naming
where in history to find the source both were read against.
