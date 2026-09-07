# The Vulkan workload lease reaches the production series

`patches/llama-server-vulkan-workload-lease.patch` moves from the candidate
stage of `remote/llama-patch-series.tsv` to the production stage, so every
promoted build compiles it and `server_context_impl::update_slots` takes
`$QWEN_HOME/state/vulkan-workload.lock` around every decoding pass. The
appliance serves the result as epoch `lease-q4k-6b262d93-r1`.

## Falsifiers, stated before the numbers

- A promoted build whose `checkpoint_semantics` reads anything but
  `natural-boundary-v1` refuses every positive `--ctx-checkpoints` count, and
  the served ledger names 2 on every row, so such a build cannot serve and the
  promotion fails whatever the lease does.
- A served turn that leaves the lease unarmed, or an idle loaded server that
  holds it, refutes the two-sided invariant the patch exists to establish.
- An assembled bundle that verifies but refuses to launch is an outage rather
  than a promotion; the epoch stands only where the launch reaches
  `state=running` with `/health` answering 200.
- The active epoch `main-2c1fa9de-r1` must keep verifying across the ledger
  edit, since a rollback target that stops verifying removes the recovery the
  activation rests on.

## What the promotion required beyond the stage move

The lease member rewrites `tools/server/server-context.cpp`, the one file whose
digest two authorities pin. `verify-llama-patch-series.sh` refused at that file
against the nine-member pin `3744317b...`, and the ten-member replay produces
`7ef5095a...`. The pin moved in the five places that state it -- 
`remote/llama-patched-sources.tsv`, the `natural_boundary_source_sha256` default
in `remote/classify-checkpoint-semantics.sh`, `remote/build-llama-trace.sh`,
`remote/run-trace-campaign.sh`, and the `AGENTS.md` sentence naming it.

The digest names which source and the classifier's own `checkpoint_offsets` grep
states what that source does: the replayed file carries no forced tail
partition, so `natural-boundary-v1` stays earned rather than asserted. Both
branches discriminate after the re-pin -- the classifier reads
`natural-boundary-v1` over the ten-member source and `unknown` over the
nine-member one -- and the series then verifies whole at
`patch_series_sha256=84c05fbfaa8255d46a48448fb4a8dd2708ce78959098c39582b3ad15ca9a8493`
over ten members.

`remote/test-vulkan-workload-lease.sh` asserted the member through the candidate
replay, which prints one `applies=yes` row per candidate. A production member
reaches the plain replay instead, so the test now reads the stage from the
ledger and requires the production replay to accept.

## The refusal that a production-only build produced

The first assembled bundle, `lease-6b262d93-r1`, was built from the ten-member
production series alone. It verified and promoted, and its launch refused:

```
the selected llama-server does not admit Q4_K formulation e4-scale-licm/4
the build declares q4k_variants=-
```

`remote/models.tsv` releases `e4-scale-licm/4` for `qwen38-4b-distill`, and that
formulation is compiled by `llama-vulkan-q4k-variant-select.patch` and its five
companions, which sit at the candidate stage. A serving build is therefore the
production series plus that six-member candidate selection rather than the
production series alone -- the row-scoped Q4_K release binds the serving build
to candidate members no stage move promoted. The appliance rolled back to
`main-2c1fa9de-r1` and served again within the same minute; the falsifier that
an assembled bundle can verify and still refuse to launch was met, and the
refusal is retained here as the reason the second bundle exists.

## The bundle that serves

`lease-q4k-6b262d93-r1` is built from the ten-member production series with the
same six candidate Q4_K members the previous epoch carried
(`candidate_series_sha256 b38cf563...`, identical to `main-2c1fa9de-r1`), so the
one difference between the two epochs is the lease member.

| declaration | value |
| --- | --- |
| `serving_eligible` | `yes` |
| `checkpoint_semantics` | `natural-boundary-v1` |
| `checkpoint_patch_series_sha256` | `84c05fbf...` (ten members) |
| `checkpoint_series_tree` | `verified-candidate` |
| `q4k_variants` | `production/4` through `e4-scale-licm/8`, `route=arg:LLAMA_ARG_VK_Q4K_VARIANT` |
| `llama-server` sha256 | `510c0420346ffa4f5104d3f2b28117262a0d30b2907dc21c833d38442c3e49af` |

`verify-deployment-bundle.sh` accepts it, `promote-llama-build.sh` accepts with
`strict_vulkan=passed multimodal=passed`, and the appliance serves it at
`/health` 200 under `lan_boundary=lan-authenticated`.

The epoch is operationally admitted and serving; repository integration is
pending. The serving `llama-server` is
`sha256 510c0420346ffa4f5104d3f2b28117262a0d30b2907dc21c833d38442c3e49af` over
58,224,648 bytes. The recovery bundle `main-2c1fa9de-r1` stands as
`deployment_previous` and was verified after the ledger edit and again after the
activation, both times as
`deployment_bundle_verified=main-2c1fa9de-r1`, so the rollback the activation
rests on is proven rather than assumed. No throughput or quality arm compares
the two epochs, so the lease member's serving cost is unmeasured.

## The lease on the device

`test-vulkan-workload-lease.sh` against the bundled server, at the 2B distill:

```
ok the server arms the lease at startup
ok an idle loaded server leaves the lease free
ok the reply waits for the holder: elapsed=6s hold=6s
ok the acquire names the wait: waited_ms=5891
ok the completion answers after the lease is taken
ok the lease returns once every slot is idle
served_lease=admitted waited_ms=5891 elapsed_s=6
```

Router mode is the shape the appliance serves, and `server.cpp` reaches
`init()` only in its non-router branch, so the child rather than the router
holds the lease. One authenticated turn on the live epoch shows exactly that in
`router-lease-probe.txt`: the child arms the lease at load, acquires it with
`waited_ms=0` for the decode, and releases it when the slot goes idle.

## Retained files

`artifact-manifest.tsv` is the build's own declaration, `bundle-manifest.tsv`
the assembled bundle's, `patch-series-verify.txt` the ten-member replay,
`lease-test.txt` the served admission, `router-lease-probe.txt` the live
router turn, and `active-bundle-q4k.txt` the previous epoch's Q4_K release state
that the first refusal turned on. Paths name `$HOME` and the host reads
`qwen-laptop`.
