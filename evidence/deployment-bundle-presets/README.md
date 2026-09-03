# Deployment bundles carry their presets through activation and rollback

`20260901T2055Z/` retains the live three-transition router regression on the
appliance at runtime head `5a5758e`: activate the natural-boundary bundle and
the router serves the 2B child at checkpoint count 2; activate the emergency
forced-tail bundle and the same launch serves it at an explicit 0; roll back
and it serves at 2 again. No preset was generated between the transitions.
Each launch printed `router_presets_source=deployment-current`, each child's
argv carried the count under the pinned build's `--swa-checkpoints` spelling,
and the deployment root held exactly one generation directory at every step.

| Step | current | previous | child executable | count |
| --- | --- | --- | --- | ---: |
| activate natural | `natural-boundary-13d05a0-r2` | `natural-boundary-13d05a0` | `natural-boundary-13d05a0-r2/llama-server` | 2 |
| activate emergency | `emergency-forced-tail-40f7b775-r2` | `natural-boundary-13d05a0-r2` | `emergency-forced-tail-40f7b775-r2/llama-server` | 0 |
| rollback | `natural-boundary-13d05a0-r2` | `emergency-forced-tail-40f7b775-r2` | `natural-boundary-13d05a0-r2/llama-server` | 2 |

Each transition drove one chat completion to `qwen38-2b-distill` on the
router port, which is what makes the child exist, read the child's argv from
`/proc`, and tore the session down to a free port and a free lease before the
next activation. `*-child-argv.txt` holds each argv, `*-launch.txt` each
launch transcript, and `*-activate.txt` each activator line.

## One bundle per launch

`20260901T2255Z/` retains the same regression at runtime head `90b4fa0`, where
a launch resolves its bundle once through `resolve-active-deployment.sh` and
carries the directory as `QWEN_ACTIVE_DEPLOYMENT_DIRECTORY`, with two more
transitions. The fourth pauses the launch with SIGSTOP three lines in, right
after it printed the natural bundle's preset path, activates the emergency
bundle underneath it, and resumes: the launch reported the natural bundle,
the control script selected `natural-boundary-13d05a0-r2/llama-server`, and
the 2B child carried count 2 while `deployment-current` already named the
emergency bundle. The fifth rolls back and serves at 2 again. Every launch
printed `router_presets_source=active-deployment` with a path inside the
resolved bundle, and one generation directory existed at every step.

| Step | current at launch | served bundle | count |
| --- | --- | --- | ---: |
| activate natural | `natural-boundary-13d05a0-r2` | the same | 2 |
| activate emergency | `emergency-forced-tail-40f7b775-r2` | the same | 0 |
| rollback | `natural-boundary-13d05a0-r2` | the same | 2 |
| activate under a paused launch | `emergency-forced-tail-40f7b775-r2` | `natural-boundary-13d05a0-r2` | 2 |
| rollback | `natural-boundary-13d05a0-r2` | the same | 2 |

The activation lock behind this is a descriptor the activator holds
exclusively for its whole run and the resolver holds shared while it reads,
so a writer exporting the former environment marker waits behind a holder;
role links are held to exactly `../BUNDLE_NAME` and generation links to
exactly `deployment-state.N`; and a preset section is bound to the ledger
count of the model its `LLAMA_ARG_MODEL` resolves to.
`remote/test-deployment-bundle.sh` carries those at 27 checks, including a
state link through `..` against an outside sentinel that stays byte-identical.

## Recovery and the lock leaf

`20260901T2352Z/` retains the same regression at runtime head `d8a3e16`
with two more transitions. The sixth points `deployment-state` at a
generation that does not exist: the automatic launch refuses on
`deployment-current does not resolve to a directory`, and a launch naming
`QWEN_LLAMA_SERVER` and `QWEN_CTX_CHECKPOINT_LEDGER` explicitly starts,
answers `/health`, and tears down, after which the pointer is restored and
`deployment-current` reads the natural bundle again. The seventh replaces
`.activate.lock` with a symlink to a sentinel file: the activator refuses
with `verified_lock_descriptor=rejected`, the automatic launch refuses, and
the sentinel's digest is unchanged afterwards, since
`open-verified-lock-descriptor.py` opens the leaf with `O_NOFOLLOW` and
without truncation. The five earlier transitions passed again ahead of
them, so the head that carries the verified lock leaf, the recovery mode,
the executable-row cardinality, the bundle name rule, the random staging,
and the ambiguity refusal in the preset check serves the same way the
earlier one did.

The full repository gate ran on `d8a3e16`, and the commit that retained
this directory followed it, so the final head of that pull request is not
the commit the gate ran on. `gate-heads.tsv` records the two heads and the
distinction: the successor touched this directory, this file, and
`evidence/SHA256SUMS` alone, so the runtime payload the appliance executed
is the gated payload, and the repository head carries evidence the gate
did not see beyond the ledger-evidence and manifest checks named there.

## What the bundle carries

A preset section carries `LLAMA_ARG_CTX_CHECKPOINTS` because
`common_preset::merge` would push one router argv value onto every child, so
the preset states the ledger's count a second time and the two move together.
`build-router-presets.sh` generated each bundle's preset against that bundle's
ledger through `QWEN_CTX_CHECKPOINT_LEDGER`, `build-deployment-bundle.sh`
verified it through `verify-bundle-preset-ledger.sh` and digested it into the
bundle manifest, and `qwen-launch.sh` read it through `deployment-current`.
The two manifests are retained: the natural bundle declares
`natural-boundary-v1` with maximum count 2 and the emergency bundle declares
`unknown` with maximum count 0, since the frozen 40f7b775 build's artifact
manifest predates the source-hash classification and an all-zero ledger is
admissible under any declaration. `web-presets.ini` reads `-` in both, because
`build-web-presets.sh` against the shipped all-refused ledger emits nothing and
says so; the transcript of that refusal is retained beside the router preset
generation.

## The two reported gaps, reproduced and closed

An operational report claimed that concurrent activations retained multiple
generation directories and lost the intermediate activation from the rollback
pointer, and that a renamed bundle directory activated under a foreign
internal `bundle_name`. Both reproduced on the previous activator in a
fixture: over eight trials of three racing writers, five trials retained more
than one generation directory, up to five, and seven left `deployment-previous`
on the original bundle rather than the displaced one, because each writer read
the displaced current and allocated its generation number before any
published; a bundle renamed from `bundle-c` activated as `bundle-renamed`.
The activator now serializes on `.activate.lock` under the deployment root
and requires the manifest's `bundle_name` to equal the directory it activates
from, and `remote/test-deployment-bundle.sh` carries six race trials and the
renamed-bundle refusal at 22 checks.

The first live attempt at this regression stopped on the probe rather than
the chain: it looked for `--ctx-checkpoints` in the child argv where the
pinned build spells the option `--swa-checkpoints`; the rerun retained here
reads either name.
