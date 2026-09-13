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
| `venv/bin/qwen-apu` | an absolute shebang and the root it names | `bootstrap.py` writes it |
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
QWEN_WEB_AUTHORIZER_READY=1 \
  QWEN_WEB_MCP_SERVER=$PWD/remote/web-mcp/server.py \
  QWEN_WEB_TOKEN_KEY_FILE=$QWEN_HOME/state/web-token.key \
  QWEN_WEB_STATE_DIR=$QWEN_HOME/state/web-mcp \
  QWEN_WEB_PROVIDER=searxng \
  QWEN_IMAGE_MCP_SERVER=$PWD/remote/image-mcp/server.py \
  QWEN_IMAGE_TOKEN_KEY_FILE=$QWEN_HOME/state/web-token.key \
  QWEN_IMAGE_STATE_DIR=$QWEN_HOME/state/images \
  QWEN_IMAGE_SERVICE_SOCKET=$QWEN_HOME/state/images/image-service.sock \
  QWEN_IMAGE_PROFILES_JSON=$QWEN_HOME/state/image-parameters.json \
  remote/build-router-presets.sh $QWEN_HOME/state/router-presets.ini
qwen-apu deployment build <name> <bundle>/llama-server <bundle>/artifact-manifest.tsv \
    remote/ctx-checkpoints.tsv --router-presets $QWEN_HOME/state/router-presets.ini
qwen-apu deployment activate <name>
make status && make doctor                   # claimed, foreign, predecessor paths
qwen up
```

The lane inputs above are what make the regenerated preset match the bundle it
replaces. Without them the generator writes a preset one section short: it
withholds `web-open` as `authorizer_absent` and skips the image row, and the
launch then serves every model with no search, no generation, and no approval
rail. Comparing `grep -c '^\['` between the retired bundle's preset and the
fresh one catches that before a bundle is built around it. The server, artifact
manifest, and checkpoint ledger come from the bundle being replaced, which is why
the rebuild carries the same `server_sha256`: the binary is the one object the
move leaves byte-identical.

The operator's PATH needs no repair: `remote/qwen` travels with the checkout and
resolves the runtime root from its own location, so the entry that names
`remote/` keeps working at the new path. That entry belongs in `~/.bashrc`, which
every interactive shell reads; `~/.profile` reaches a login shell alone, and the
terminal an operator opens from a desktop session is not one.

`chown -R` over a 53 GB root rewrites inode metadata alone and the rename copies
no byte, so the move costs seconds where both paths sit on one filesystem. A move
across filesystems copies every model and is a different operation: read
`stat -c %d` on both parents before starting.

## Two accounts, one tree

After the move the tree belongs to the operator, so a second account reaches it
through `sudo` -- including for `git pull`, which writes `.git/` and nothing
privileged at all. That is ownership rather than a mode: elevating to run an
ordinary fetch hides which account the appliance belongs to and leaves root-owned
objects behind in the tree the moment one command runs without `-u`. A shared
group removes it in one transaction:

```sh
sudo groupadd -f qwen
sudo usermod -aG qwen operator && sudo usermod -aG qwen agent
sudo chown -R operator:qwen <checkout>
sudo find <checkout> -type d -exec chmod 2775 {} +   # setgid: new files inherit qwen
sudo find <checkout> -type f -exec chmod g+rw {} +
git -C <checkout> config core.sharedRepository group
```

The setgid bit makes the group survive every later write, and
`core.sharedRepository=group` is what makes git set group-write on the objects it
creates itself, which a permissive umask alone does not guarantee. A new member
takes effect at their next login.

Two further grants finish it. The operator's home is mode 750, so the group needs
traverse through it to reach the checkout at all, which one ACL gives without
making the home listable:

```sh
sudo setfacl -m g:qwen:x ~operator
git config --global --add safe.directory <checkout>   # per account, no privilege
```

The second is git's own ownership guard: since 2.35.2 a repository whose
directory belongs to another user is refused outright, `fatal: detected dubious
ownership`, whatever the modes say. The exception is per-account configuration
rather than a repository setting, so each account that shares the tree records it
once. Both accounts then pull, branch, and edit with no elevation.

The runtime root stays outside that grant. `RuntimePaths.lay_out` closes
`state/` to its owner at mode 0700 because the tool ledger refuses a directory
another user can read, and the signing key and the pairing secret live there, so
the group covers the checkout while `.runtime` keeps the serving account's own
ownership. An agent that needs to repair the root asks for that separately, which
is the boundary this split states.

`make doctor` is the step that reports what the move left behind. It names
predecessor paths outside the root and foreign entries under it without touching
either, so a symlink still pointing into the old location surfaces there rather
than at the next launch.
