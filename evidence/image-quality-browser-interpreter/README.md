# Image-quality browser interpreter preparation

## Result

`qwen-home.sh` declares the browser Python as
`$QWEN_HOME/opt/browser-venv/bin/python`, and the browser acquisition entry
point launches the lifecycle runner with that path. Shell activation, a script
shebang, and the first `python3` on `PATH` carry no selection authority. The
entry point refuses a runtime root bound to another checkout and passes its
runtime-root authority through an internal environment value that caller
arguments cannot replace. The Python runner verifies that its running
executable and virtual-environment prefix equal the declared browser
environment before it imports `marionette_driver` or starts the acquisition
driver. The runner launches both itself and the accepted acquisition driver in
isolated Python mode. Ambient user-site and `PYTHONPATH` packages therefore
carry no import authority, and the dependency source and distribution metadata
must resolve inside the declared environment.

The preflight fingerprints four roles: browser-environment Python, the complete
installed-file manifest of the `marionette_driver` distribution, the
acquisition driver, and the intended Firefox executable. Every manifest entry
must resolve inside the declared environment, and the imported module must be
one of those entries. Schema `qwen-browser-driver-preflight-v2` identifies the
dependency digest as
`distribution-manifest-path-content-sha256-v1`; the algorithm hashes each
environment-relative manifest path with the file's content digest.
`preflight-private.json` retains paths under the new result directory.
`preflight-public.json` carries role names, versions, algorithms, and SHA-256
identities while omitting paths. An unreadable or disappearing manifest file
becomes a retained `dependency_identity` refusal rather than an incomplete
directory. The runner owns and injects the driver's `--firefox-bin` argument,
so the fingerprinted executable and the executable handed to the driver are
one identity.

The entry point declares and reuses the existing private browser environment;
the preparation neither provisions another environment nor installs a browser
dependency. An absent or divergent dependency remains a preflight refusal.
The driver is a workstation-side acquisition controller that runs from the Git
checkout. `check-runtime-tree.sh` guards the copied appliance runtime and
intentionally refuses a Git source clone, so its synced-tree contract does not
apply to this controller. The successor record instead binds the checkout's
acquisition-driver digest; the retained qualification record binds the source
and deployed payload manifests separately.

The focused fixture puts an executable named `python3` first on `PATH`; that
executable would leave a marker and exit 99 if selected. The accepted arm uses
the declared virtual environment, imports the fixture dependency, writes the
role-only record, and leaves the hostile marker absent. The refusal arm removes
the dependency metadata and module, observes `failure_stage=dependency_import`,
and leaves driver, Firefox, profile, image-authorization, and image-generation
markers absent. Further arms prove a foreign runtime-root marker refuses before
record creation, a caller-supplied runtime-root option cannot redirect output,
and a hostile `PYTHONPATH` package cannot replace the dependency used by the
driver. The deadline arm starts a fixture driver and child in the runner's
owned process group, records status 124, and observes group termination. The
signal arm sends SIGTERM to the runner, observes the driver group terminate,
and retains status 143, the signal identity, and the cleanup result before the
runner exits. Additional arms show that a non-imported distribution file moves
the dependency digest, `nan` and `inf` timeouts refuse, SIGHUP retains status
129 after group cleanup, a driver that exits before its child still triggers
child cleanup, and a process-creation error retains a `driver_start` refusal.
Process-group liveness excludes zombies because they cannot continue an
acquisition. A signal captured while the driver wait or cleanup returns still
overrides a natural status 0 with status 128 plus the signal number.

`environment-preflight.json` is the role-only derivative from a workstation
preflight through the declared existing environment. It reports Python 3.14.7,
`marionette_driver` 3.7.1, the acquisition-driver identity, and the intended
Firefox-executable identity with `driver_execution=withheld_preflight_only`.
`transformation.tsv` binds the retained private source digest, public derivative
digest, and its original producer digest. That retained derivative uses schema
`qwen-browser-driver-preflight-v1`; it predates the complete-distribution and
terminal-cleanup additions and is not reclassified as their proof. The
successor acquisition runs the stronger v2 preflight before any driver or
Firefox startup. The retained preflight started neither the driver nor Firefox.

## Successor acquisition

The retained acquisition in
`evidence/ui-tool-qualification-20260909/README.md` remains closed with these
states:

| Seed | State |
| ---: | --- |
| `314159` | `failed_before_start` |
| `271828` | `not_run` |
| `161803` | `not_run` |

`successor-acquisition.tsv` defines a new acquisition rather than an append or
repair of that record. The successor uses one fresh direct child of
`$QWEN_HOME/results`; the runner refuses an existing directory. The contract
preserves the three prompts, their order and seeds, `image-sdxs-512-a`, its
registered `lfm25-vl-16b` reviewer, 512 by 512 dimensions, and four steps.
Named execution authorization remains a prerequisite. The preparation runs no
browser, creates no disposable profile, authorizes no image call, and generates
no image.

The successor stops on its first protocol or restoration failure. A completed
row retains generation completion, exact parameters, artifact digest, stage
latency, predefined constraint results, reviewer schema validity, reviewer
judgment, direct inspection, and their agreement. Image bytes and records
carrying paths, credentials, addresses, result handles, or authorization stay
under the runtime root. A sanitized derivative may publish role identities,
digests, criteria, scores, and bounded observations after acquisition review.

## Successor result

Authorization `image-quality-successor-20260910-01` was consumed once. The fox
row generated and retained one image, and its reviewer completed. Direct
inspection passed two of five constraints while the reviewer passed its single
subject constraint, so reviewer/direct agreement is false. The broker refused
the cube row after application approval because the client still held one
outstanding image grant. The stopping rule left the exact-text row `not_run`.
The separate retained result is
[`evidence/image-quality-successor-broker-grant-stop/`](../image-quality-successor-broker-grant-stop/).
