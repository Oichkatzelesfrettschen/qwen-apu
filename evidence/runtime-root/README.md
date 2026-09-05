# The runtime root

A checkout of this repository is the complete declaration of the appliance,
`make bootstrap` expands that declaration into one ignored runtime tree beside
it, and production consumes only the checkout and that tree. This file states
the layout, the manifest that enumerates it, the doctor that reports what sits
outside it, the migration that moves the appliance onto it, and what the epoch
receipt binds once it has.

## Why the root is repo-local

An audit of the appliance on 2026-09-04 found two incompatible installation
doctrines in one tree. `remote/install-searxng.sh` ran every upstream install
stage under sudo, created the `searxng` system account, wrote
`/etc/searxng/settings.yml`, and cloned the source under `/usr/local/searxng`;
`remote/searxng-launch.sh` meanwhile defaulted to a user-owned tree under
`/opt/searxng-qwen-apu` with `searxng-src` and `searx-pyenv` beneath it, a
layout no install on the appliance had produced. The first launch of a fresh
epoch therefore failed at the health gate, and the launch that served that
day did so through an environment override the restore chain never recorded.
Around those two, the appliance had grown a home-directory sprawl -- fifteen
llama.cpp trees under `~/src`, models under `~/models`, deployments and state
as two further siblings, a RyzenAdj binary under `~/.local/bin`, a YaCy tree
under `~/opt`, a signing key in `~` itself -- with no single declared root and
no uninstall.

`remote/qwen-home.sh` closes both. QWEN_HOME names one directory and defaults
to `.runtime` beside `remote/`, so the tree that runs is the tree whose root
is read and a second external directory never reopens the question of which
is authoritative. An operator moves the root to another disk by exporting
QWEN_HOME, and every derived path follows. Models stay outside Git and inside
the root, since a self-contained repository means every byte is checked in or
reproducibly generated or fetched by a checked-in rule, and 74 GB of weights
belong to the second class.

## Layout

```text
.runtime/
├── .qwen-runtime-root   identity marker: runtime_schema_version, tree_root
├── manifest.tsv         written by `make status`
├── bin/                 built binaries and wrappers (ryzenadj)
├── opt/                 reproducible third-party source and tool installs
│   ├── searxng/{src,venv}
│   ├── llama.cpp/            the patched serving tree, build-*/ beneath it
│   ├── llama.cpp-upstream/   the pristine pinned clone the patch series applies to
│   ├── llama.cpp-trace/, llama.cpp-census/
│   ├── stable-diffusion.cpp/
│   ├── ryzenadj/src, shaderc/, radv/, rocm/, yacy/, gate-venv/
├── models/              immutable fetched checkpoints, pinned by download-*.sh
├── deployments/         immutable deployment bundles and deployment-current
├── state/               mutable application state, the session directory
├── cache/               disposable caches (build, gate, pip, ryzenadj-build)
├── tmp/                 process-lifetime scratch
└── results/             measurement outputs a harness names by label
```

`remote/qwen-home.sh paths` prints every declared name with its value, and
`remote/qwen_home.py` resolves the same root for a python child.

## The marker binds the root to one checkout

`.qwen-runtime-root` carries `tree_root=` beside its schema version, and that
field is the root's claim on a checkout. `qwen_home_binding_state` in
`remote/qwen-home.sh` resolves both sides through `cd -P` and answers
`unmarked` for a root `make bootstrap` has yet to lay out, `bound` where the
marker names this tree, and `foreign:TREE` where it names another;
`qwen_home_require_binding` turns the third into a refusal. `make status`,
`make verify`, `make uninstall`, `make purge`, and
`remote/resolve-active-deployment.sh` on its derived root all take that
refusal, so a root moved beside a second checkout stops the read rather than
serving one checkout's declaration through another checkout's scripts. `make
doctor` reports the state on a `declared` row instead, since the doctor
touches and refuses nothing.

`make bootstrap` is the first remedy a refused reader reaches for, so `init`
rewrites a foreign marker only where `QWEN_RUNTIME_ROOT_REBIND` names this
exact tree; without that rule the remedy silently takes the root the refusal
just reported. An explicit `QWEN_DEPLOYMENT_ROOT` or a deployment root named
on the command line is the caller's own claim and is verified as a bundle
root rather than through the binding. `remote/qwen_home.py` mirrors the same
three states as `binding_state()` and `require_binding()` for a python child
that resolves the root itself.

## The manifest

`make status` runs `remote/runtime-root.sh status`, which writes
`$QWEN_HOME/manifest.tsv` with one row per component the repository claims
ownership of, present or absent:

```text
component  kind  path  source  revision  source_sha256  installed_sha256  mutable  rebuild_command
```

`installed_sha256` is the digest of the installed object -- a binary's bytes,
a source tree's git head, a venv's sorted `pip freeze`, a model tree's sorted
path-and-size listing -- and reads `absent` where nothing is installed, so the
manifest states what is missing rather than omitting it. `source_sha256` is
the digest of the checked-in declaration the component is built from: the
SearXNG pin file, the requirements lock, the patch series ledger, the model
artifact ledger, the sudoers source. The manifest's own SHA-256 is printed on
the last line and is the `runtime_manifest_sha256` the receipt carries.

## The helper binaries and the image parameters

`make status` carries a row per helper the appliance builds or fetches --
`ryzenadj` and `image-runtime` by the digest of the binary itself, `shaderc`
by the digest of the `glslc` under its root -- so a manifest states which
toolchain the running appliance holds rather than that one is installed.

`image-parameters` joins them. The file states the geometry and the ceilings
`image-service.py` runs a job under, which makes it a generated byte of the
appliance rather than a path a caller names, so `remote/qwen-home.sh` declares
it as `qwen_home_image_parameters` at `state/image-parameters.json` and the
manifest records its digest beside `remote/image-profiles.tsv`, the ledger it
is written from. `require_image_parameters` in `remote/image-launch-lib.sh`
refuses a launch whose `QWEN_IMAGE_PROFILES_JSON` resolves outside the root and
names the served path in the refusal. The comparison is on the resolved path,
so a symlink under the root pointing outside it meets the same refusal.
`QWEN_IMAGE_PARAMETERS_EXTERNAL=1` admits a harness that writes its own
parameter set into its own output directory, which is what
`remote/admit-image-router.sh` does; a served launch names nothing of the sort.

## The doctor

`make doctor` classifies paths without touching any of them:

- `declared`: the root and its layout directories, and the one persistent
  root-owned object, `/etc/sudoers.d/90-qwen-agent`.
- `legacy-known`: the enumerated predecessor paths a launch or build once wrote
  outside the root, on the appliance and on the workstation alike, plus the
  `searxng` account and its `/tmp/sxng_cache_*.db` engine caches.
- `foreign`: an entry directly under the root that the layout does not name.
- `transient-system-state`: the sysfs nodes a campaign writes and restores,
  with their live values.

The summary line `legacy_paths_present=yes|no legacy_paths=N
foreign_owned_paths=N` is what the receipt binds. `make purge-legacy` removes
exactly the enumerated `legacy-known` paths under
`QWEN_PURGE_LEGACY_CONFIRM=yes`, refuses while no SearXNG instance stands
under the root, removes the account only after proving nothing runs as it and
no file outside the enumerated paths belongs to it, and wildcards nothing.
`make uninstall` keeps `state/` and `models/`; `make purge` removes the root
whole under `QWEN_RUNTIME_ROOT_CONFIRM` naming that exact path; both refuse a
directory carrying no marker and a directory whose marker names another
checkout. A root the marker binds to a production checkout takes that same
confirm on `make uninstall`, since such a root holds the served deployments
and the session state and its reproducible products cost hours to rebuild.
The discriminator is git's own: a production checkout carries `.git` as a
directory, a linked worktree carries it as a `gitdir:` file, and a fixture
tree carries neither, so the rule names the tree the appliance serves from
while naming no path the ratchet would refuse.

## The three verifications

`make verify` is the union of three targets that answer three questions and
fail for three reasons:

- `make verify-layout` reads the structure alone -- the marker, its schema,
  its binding to this checkout, every layout directory, and any entry under
  the root outside the layout -- beside the lexical ratchet. It touches no
  installed component, so it answers on a root `make bootstrap` just laid
  out, and a foreign entry or an absent layout directory fails it.
- `make verify-components` refreshes the manifest and reads the identity of
  every component out of it, naming each `present` with its installed digest,
  `absent` with the command that rebuilds it, or `mutable` where the component
  declares no identity. `make verify-sudo-policy` runs ahead of it. Absence is
  reported and counted rather than failed, since a partially expanded root is
  a state the manifest exists to state.
- `make verify-live` reads the transient system state -- the DPM level, the
  boost state, the KSM run state -- with the session state and the legacy
  summary beside it. A node absent from this machine reads `absent` and
  passes, because the workstation carries no amdgpu sysfs and a verification
  that refused there would refuse every gate run.

Model bytes stay out of all three, since 74 GB of hashing in a union would
make it unusable.

## The model files against their pins

`make verify-models` runs `remote/verify-models.sh`, which joins
`remote/models.tsv` against the pins the fetch rules state and reports one row
per registry artifact -- the model file, and the projector where the row
requires one:

```text
model_id  kind  path  status  expected  observed  fetch_script
```

`status` reads `verified`, `absent`, `bytes-differ`, `digest-differs`, or
`unpinned`, and a pin the registry names nowhere reads `orphan-pin` on the
reverse join. The pin comes from `remote/model-artifacts.tsv` where the ledger
carries the row and from the fetch script's own `expected_bytes=` and
`expected_sha256=` assignments otherwise, read out of the source rather than
by running it. Only a `bytes-differ` or a `digest-differs` fails the run: an
absent file is a state to report with the download script that produces it,
and `unpinned` names a hole in the fetch rules rather than a fault in a file.
The byte count is read before the digest, so a wrong file ends its row at a
stat rather than at a full read. Nothing is fetched.

Against the shipped ledgers, three rows read `unpinned`: the two 27B ladder
rows, whose one fetch script pins no single artifact, and the derived
`qwen35-08b-f16`, whose bytes `remote/derive-qwen35-08b-f16.sh` produces from
the BF16 source rather than fetching.

## The ratchet

`remote/check-appliance-paths.py` fails the repository gate where a tracked
script under `remote/` or the Makefile names `/usr/local`, `/opt`, `/etc`,
`/var`, `/srv`, `/home`, `$HOME/`, or `~/` outside a comment. The allowlist in
`runtime/appliance-path-allowlist.tsv` admits system facts by prefix with a
reason -- the sudo policy path, `/etc/os-release`, the PATH components of the
closed campaign environment, the libpci header probe -- and a line marked
`appliance-path: named` admits a path named on purpose: the doctor's legacy
table, a sanitized ledger string, a fixture proving a foreign path is refused.
`remote/test-check-appliance-paths.sh` seeds each class into a scratch
repository and proves the verdicts.

## The one privileged persistent object

`runtime/sudoers/90-qwen-agent` is the checked-in source of
`/etc/sudoers.d/90-qwen-agent`: a global sudo timestamp with a 60 minute
timeout, so one `sudo -v` in the operator's session covers the SSH commands
that administer the appliance. `make install-sudo-policy` copies it at mode
0440 owned by root after `visudo -c` accepts it, `make verify-sudo-policy`
requires the installed file to hash to the source at that mode and owner, and
`make uninstall-sudo-policy` removes it. Every other privileged write -- a DPM
level, a boost state, a KSM run state, an SMU budget -- stays transactional:
snapshot, mutate, measure, restore, verify the restoration.

## SearXNG under the root

`toolchains/searxng/source.tsv` pins the upstream URL, the commit, the SHA-256
of that commit's `requirements.txt`, and the python minimum;
`toolchains/searxng/requirements.lock` is the full frozen environment that
commit resolves to, 43 distributions captured from the verified appliance
install of 2026-08-29. `make install-searxng` clones the pin into
`opt/searxng/src`, proves the requirements digest, builds `opt/searxng/venv`
with `pip install --no-deps` over the lock, and requires the sorted freeze to
equal the lock byte for byte, so the venv identity the manifest records is the
digest of a listing the install already required to match. `make
verify-searxng` starts the instance through `remote/searxng-launch.sh` in a
scratch state directory, requires `/healthz` and one JSON search on the
loopback, and stops it. The launcher's `check` action reports an absent
component as a block naming the root, the source, the interpreter, and
`make install-searxng`, and both launchers run it ahead of the health gate.

### The wheelhouse

The lock states which distributions at which versions and the wheelhouse
states their bytes. `make searxng-wheelhouse` downloads the lock's wheels into
`opt/searxng/wheelhouse` and writes `wheelhouse.tsv` with one row per file
carrying its byte count and SHA-256; `make verify-searxng-wheelhouse` reads
that manifest back and requires every named file present at its digest and no
file in the directory the manifest leaves unnamed. An install over a populated
wheelhouse verifies it and then resolves with `--no-index` against
`--find-links` alone, so the same bytes install on a machine with no network
and a reinstall a year on installs what the first one did rather than what the
index serves that day. `QWEN_SEARXNG_OFFLINE=1` refuses an install where no
manifest stands, so a machine that meant to install from its own wheels says
so rather than silently fetching. The wheelhouse lives under `opt/searxng/`
rather than under `cache/`, because an offline reinstall depends on it and
`cache/` is the tree `make uninstall` discards, and `make status` carries its
manifest digest as the `searxng-wheelhouse` row.

`remote/test-install-searxng.sh` writes a two-wheel fixture wheelhouse and its
manifest directly and exercises every reader: the verification counts the
files, the install resolves offline and places both wheels, a mutated wheel
and an unnamed file each refuse, and `QWEN_SEARXNG_OFFLINE=1` refuses without
a manifest. Populating the wheelhouse against the real 43-distribution lock
reaches the network and is not run: no wheelhouse for the pinned lock has been
built or measured, and its digests stay uninvented until one is.

## Migration of the appliance

The appliance moves onto the root in this order, each step proven before the
next:

1. `make bootstrap` in the appliance's own checkout, which lays out the root.
2. `make install-searxng` and `make verify-searxng`.
3. Models: `make install-models` verifies the pinned files in place under
   `models/`; the existing 74 GB tree is moved there once and each download
   script then proves the bytes by digest rather than fetching them again.
4. `make install-ryzenadj`, `make install-image-runtime`, `make build-llama`.
5. Mutable state (`state/`) migrated separately from reproducible products.
6. A launch through the ordinary chain, `/healthz`, and a real search through
   the broker and router.
7. `make status`, whose manifest the epoch receipt binds.
8. `make purge-legacy`, then `make doctor` reading `legacy_paths_present=no`.
9. A relaunch and a second search.

Predecessor paths are migration inputs, classified one by one: rebuild from
source for toolchains and source trees, reuse by verified digest for the
immutable model files, migrate for mutable state, retire for the rest.

## What the receipt binds

`remote/write-deployment-receipt.sh` adds, beside the fields it carried:

```text
runtime_schema_version  qwen_home  runtime_manifest_sha256
searxng_source_commit   searxng_venv_identity
ryzenadj_digest  image_runtime_digest  shaderc_digest
models_manifest_digest  sudo_policy_digest
legacy_paths_present  foreign_owned_paths
```

The reproducibility statement a receipt then makes: clone this exact git
tree, run its declared expansion, verify the runtime manifest, and the
resulting environment has the same logical components and identities with no
reliance on undocumented machine history. A receipt reading
`legacy_paths_present=yes` is a continuity check, and the next production
epoch is certified only over one reading `no`.
