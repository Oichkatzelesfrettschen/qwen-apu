# Image-quality browser interpreter preparation

## Result

The browser acquisition entry point resolves the Python executable at
`$QWEN_HOME/opt/browser-venv/bin/python` and launches the lifecycle runner with
that path. Shell activation, a script shebang, and the first `python3` on
`PATH` carry no selection authority. The Python runner verifies that its
running executable and virtual-environment prefix equal the declared browser
environment before it imports `marionette_driver` or starts the acquisition
driver. Isolated Python mode excludes ambient user-site and `PYTHONPATH`
packages, and the dependency source and distribution metadata must resolve
inside the declared environment.

The preflight fingerprints four roles: browser-environment Python, the
`marionette_driver.marionette` dependency source, the acquisition driver, and
the intended Firefox executable. `preflight-private.json` retains their paths
under the new result directory. `preflight-public.json` carries role names,
versions, and SHA-256 identities while omitting paths. A dependency or identity
failure writes both records with `driver_execution=not_started` and exits 2.
The runner owns and injects the driver's `--firefox-bin` argument, so the
fingerprinted executable and the executable handed to the driver are one
identity.

The focused fixture puts an executable named `python3` first on `PATH`; that
executable would leave a marker and exit 99 if selected. The accepted arm uses
the declared virtual environment, imports the fixture dependency, writes the
role-only record, and leaves the hostile marker absent. The refusal arm removes
the dependency metadata and module, observes `failure_stage=dependency_import`,
and leaves driver, Firefox, profile, image-authorization, and image-generation
markers absent. A third arm starts a fixture driver and child in the runner's
owned process group, reaches the registered deadline, records status 124, and
observes the child handle a group-delivered termination before the runner
returns.

`environment-preflight.json` is the role-only derivative from a workstation
preflight through the declared existing environment. It reports Python 3.14.7,
`marionette_driver` 3.7.1, the acquisition-driver identity, and the intended
Firefox-executable identity with `driver_execution=withheld_preflight_only`.
`transformation.tsv` binds the retained private source digest, public derivative
digest, and producer digest. The preflight started neither the driver nor
Firefox.

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
