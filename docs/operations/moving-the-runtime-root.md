# Moving the appliance to another account

The appliance is one checkout and the runtime root beside it, so moving it is one
rename and one ownership change. The account that runs it owns its processes:
teardown signals the pids the record names and a pid is signalled by the user
that started it, so an operator who brings the appliance up and down at the
machine owns the tree it runs from. This is the procedure that gets it there, and
the order matters because five objects record the old location.

## What records the old path

| object | what it holds | repair |
| --- | --- | --- |
| `.qwen-runtime-root` | `tree_root=` the checkout that laid the root out | `QWEN_RUNTIME_ROOT_REBIND` naming the new tree, through `bootstrap.py` |
| `site-packages/qwen_apu.pth` | the absolute `src/` path | `bootstrap.py` rewrites it |
| `venv/bin/qwen-apu`, `venv/bin/qwen` | an absolute shebang and the root each names | `bootstrap.py` writes both |
| `models/{production,candidates}/*` | tier symlinks with absolute targets | `remote/build-router-presets.sh` empties and rebuilds them |
| the active bundle's `router-presets.ini` and `web-mcp-manifest.tsv` | one absolute model path per served section, and the web profile's config path | a rebuilt bundle, activated |

The bundle is the one object an edit cannot repair. `bundle-manifest.tsv`
digests every member, so a `sed` over the presets inside an activated bundle
leaves a unit whose manifest names bytes it no longer holds;
`build-deployment-bundle.sh` copies a preset in and digests it, which makes a
rebuild and an activation the only transition that keeps the unit's own identity
true. Its other members travel unchanged: `artifact-manifest.tsv`,
`ctx-checkpoints.tsv`, and `q4k-policy.tsv` name no absolute path, and
`llama-server` is a copied executable.

Three objects survive the move untouched, each for a reason worth knowing.
`venv/bin/python` is an absolute symlink to the system interpreter, so the
environment still runs when invoked through its own path, which is why
`bootstrap.py` repairs the venv rather than rebuilding it. The search instance
launches as `venv/bin/python -m searx.webapp`, so the shebangs its own console
scripts carry never run. And `deployments/deployment-current` is a relative
symlink, so the activated bundle survives the rename and only its contents need
the rebuild above.

## The order

```sh
qwen down                                    # the record's pids, proven absent
git -C <checkout> worktree list --porcelain  # every worktree registers absolute
git -C <checkout> worktree remove <path>     #   paths, so each one goes first
sudo mv <checkout> ~operator/Github/qwen-apu
sudo chown -R operator:operator ~operator/Github/qwen-apu
cd ~operator/Github/qwen-apu                 # as the new owner from here on
QWEN_RUNTIME_ROOT_REBIND=$PWD python3 bootstrap.py
remote/build-router-presets.sh <fresh ini>   # the tier symlinks as well
qwen-apu deployment build <name> ... --router-presets <fresh ini>
qwen-apu deployment activate <name>
make status && make doctor                   # claimed, foreign, predecessor paths
qwen up
```

`chown -R` over a 53 GB root rewrites inode metadata alone and the rename copies
no byte, so the move costs seconds where both paths sit on one filesystem. A move
across filesystems copies every model and is a different operation: read
`stat -c %d` on both parents before starting.

`make doctor` is the step that reports what the move left behind. It names
predecessor paths outside the root and foreign entries under it without touching
either, so a symlink still pointing into the old location surfaces there rather
than at the next launch.
