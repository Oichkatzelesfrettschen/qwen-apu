# PR #105 split into eight successor lanes

`stage-a-census-brackets` carries 58 commits and touches 1183 files. Every
commit reaches a lane. The lanes
branch from `main` at 6fcf390, which is PR #106 merged, so the split is taken
against the activation-lock repairs rather than against the commit the source
branch itself left. This document records where each commit lands, which lanes
stack on which, what the split leaves unassigned, and what each lane's checks
reported on the workstation.

`docs/split-plan/lanes.tsv` is the authority: it assigns every path the branch
touches to one lane, to the `shared` set whose files several lanes each own
part of, or to the `dropped` set no lane carries.
`docs/split-plan/split-pr-105.sh` reads that map and reproduces the seven
branches from a base ref, so a later move of `main` re-runs the split rather
than re-deriving it. The tables below are generated from the map and from the
script's own replay log.

## Lane order and stacking

`commits` counts the branch against its own base, so a stacked lane's number
excludes census-timing's. `replayed` counts the source commits the lane took;
each lane also carries one commit for its share of the shared files and one for
its own manifest. A split commit takes the original's author identity and date
and its own committer date, so a second run of the script reproduces the same
trees under new commit hashes: the tips below name one run, and
`git rev-parse lane/<name>^{tree}` is what a later run reproduces.

| lane | branch | base | commits | mode |
| --- | --- | --- | ---: | --- |
| 1 | `lane/census-timing` @ `e9accb5` | `origin/main` | 31 (29 replayed) | the pipeline census instrument, its readers, its bricks and quiescence, the census runner, and the replay corpus |
| 2 | `lane/build-cache-identity` @ `65f7c69` | `origin/main` | 3 (2 replayed) | gate cell keys, build cache keys, binary reuse |
| 3 | `lane/dpm-telemetry` @ `d649f09` | `lane/census-timing` | 9 (7 replayed) | the DPM authority probe, broker freshness, the clock-state records |
| 4 | `lane/shader-e4` @ `8306377` | `origin/main` | 9 (7 replayed) | the two Q4_K activation candidates, the shader laboratory, the E1 and E4 receipts |
| 5 | `lane/correctness-witnesses` @ `48ff457` | `lane/census-timing` | 15 (13 replayed) | the kernel-delta witness, the margin contract, the holdout and quality-gate evidence |
| 6 | `lane/served-ab-harness` @ `5136c3e` | `lane/census-timing` | 15 (13 replayed) | the served binary A/B runner and the bracket reader |
| 7 | `lane/retained-evidence` @ `2d71649` | `origin/main` | 20 (18 replayed) | every retained census run directory and the manifest over it |
| 8 | `lane/deployment-followups` @ `7393ff2` | `origin/main` | 6 (6 replayed) | the activation-lock and eligibility repairs PR #106 did not carry, the broker's port reuse, and the web-launch lease poll |

Three lanes stack on `lane/census-timing` rather than branching from `main`.
`remote/run-raven2-vulkan-kernel-census.sh` sources `remote/census-arm-lib.sh`
and invokes `remote/telemetry-broker.c`, `remote/sample-clock-sidecar.py`,
`remote/validate-clock-sidecar.py`, and `remote/summarize-census-controls.py`,
so lane 1 runs nothing without those five files and they are introduced there.
`remote/probe-dpm-authority.sh`, `remote/run-kernel-delta-witness.sh`, and
`remote/run-served-binary-ab.sh` each source `census-arm-lib.sh` in turn, which
is what puts lanes 3, 5, and 6 above lane 1. Rebasing after PR #106 therefore
rebases lane 1 first and the three onto its new tip; lanes 2, 4, and 7 rebase
independently.

## Deviations from the lane listing this split was asked for

Each of these moves a file away from the lane the task named, and each is named
here with the mechanism that forced it.

`remote/summarize-census-controls.py` is listed under served-ab-harness and is
carried by census-timing. `remote/test-census-controls.py` reads it and lane 1
must run that test green, and `run-raven2-vulkan-kernel-census.sh` calls the
summarizer as its own verdict, so the pair travels with the runner.
`remote/run-served-binary-ab.sh` reads the same summarizer from lane 1's tip.

`remote/telemetry-broker.c`, `remote/validate-clock-sidecar.py`, and
`remote/sample-clock-sidecar.py` are introduced by census-timing for the same
reason. dpm-telemetry carries e0d179a's freshness column on top of them through
a per-commit override in `lanes.tsv`, which is what "telemetry-broker.c
freshness" separates from "telemetry-broker.c".

`remote/census-arm-lib.sh` is introduced by census-timing and baf58d8's
environment sealing stays there rather than moving to served-ab-harness with
the rest of that commit. The same commit changes `probe-dpm-authority.sh` and
`run-kernel-delta-witness.sh`, which are lanes 3 and 5, and both call the
sealing helper; putting the helper in a sibling lane would leave two lanes
sourcing a function no ancestor defines. 161f4e7's cooldown lease reaches
served-ab-harness through `run-served-binary-ab.sh` alone for the same reason.

A design document travels with the instrument it registers and a run directory
travels with lane 7. `e4/kernel-delta-design.md` and
`e4/margin-contract-design.md` are correctness-witnesses,
`e4/served-ab-design.md` is served-ab-harness, and `dpm-authority-design.md`
and `fclk-command-research.md` are dpm-telemetry, while every
`20260902T*Z/`, `served-ab-*/`, and `kernel-delta-20260902T2312Z/` directory is
retained-evidence. Lanes 3, 4, and 5 keep the receipt directories the task
names for them.

`remote/check-text-policy.py` is duplicated rather than assigned. Its one hunk
admits `.c` for `telemetry-broker.c` and `shader-lab.c` and `.comp` for the ISA
probes, so census-timing and shader-e4 each carry the identical change and a
merge of the two is a no-op.

`ARTIFACTS.md` gains no row: the branch leaves the file unchanged, so lane 7's
share of it is empty.

## The eighth lane, built against main rather than replayed

Six commits change the four files PR #106 repaired and predate that merge, so a
path replay of the branch's copy would revert it. `lane/deployment-followups`
takes main's shape and adds the branch's own checks on top, which
`split_deployment_followups` in the script reproduces.

- 74ddab7 `deployment: refuse a multiply linked lock leaf and a doubled
  eligibility row` cherry-picks onto the repaired files. `git diff
  origin/deployment-lock-repairs origin/stage-a-census-brackets` shows this
  branch *adding* the `st_nlink != 1` check in `verify_identity` and the
  row-cardinality refusal in `build-deployment-bundle.sh` and
  `verify-deployment-bundle.sh`, so PR #106 carried neither and this lane is
  where they land. main's `FOREIGN_WRITE_BITS` mode rule, its
  `deployment_bundle_name_is_valid` helper, and its staging-parent check all
  survive the cherry-pick.
- b02fabd's three deployment paths arrive as a three-way patch application
  rather than as a checkout of the branch's whole file, which is what keeps
  main's repairs while adding the two-shape eligibility grammar and the
  `plant_manifest` cases that exercise it against an assembled bundle.
- The CLAUDE.md sentence naming the hard-link refusal is placed by name at the
  paragraph on descriptor 7 of `.activate.lock`.
- a3105b4 and 7e9e09b, the `evidence/deployment-bundle-presets/` gate-heads
  record of the lock-leaf regression, and 995ef68's web-launch lease poll and
  f5f92d8's broker port reuse, are pure cherry-picks.

`lanes.tsv` still drops `remote/activate-deployment-bundle.sh`,
`remote/deployment-bundle-name.sh`, `remote/resolve-active-deployment.sh`,
`remote/test-open-verified-lock-descriptor.py`, and
`remote/test-run-fixed64-served-campaign.sh`. The source branch holds the
pre-#106 copy of each and changes none of them, so replaying that copy over
6fcf390 would revert the merge and add nothing.

2c33709, be25554, and bddc3eb are dropped as commits and carried as content:
each only rewrites `evidence/SHA256SUMS` or registers a gate cell, and every
lane regenerates its own manifest and carries its own cells.

## Files two lanes both change

These conflict when the lanes merge sequentially, which is a property of the
split rather than a defect. The second lane to merge re-expresses its hunks
against the first.

- `remote/repository-quality-gates.sh`. build-cache-identity converts the flat
  command list into `gate_cell` rows reading `remote/gate-cell-key.sh`, and
  lanes 1, 4, 5, and 6 add their rows in the base file's flat form. The two
  shapes cannot merge textually; whichever merges second re-expresses its rows.
- `remote/build-llama-preset.sh`. census-timing raises the instrumentation
  label to `pipeline-census-v3` and keeps an instrumentation row off a serving
  manifest; build-cache-identity carries the shader pack, the object cache, and
  the binary key. The hunks are disjoint and adjacent.
- `remote/radv-low-priority-env.sh` and
  `remote/test-radv-low-priority-env.sh`. census-timing rebuilds the diagnostic
  profile; shader-e4 adds the two sideplane names to the scrub and the case
  that proves it.
- `remote/check-text-policy.py`, identically in two lanes, which merges clean.
- `CLAUDE.md` and `evidence/raven2-vulkan-kernel-census/README.md`, split at
  section boundaries. `docs/split-plan/shared/<lane>/` holds each lane's whole
  version, so a re-run of the split reproduces the same slices.

## References that dangle inside a lane

`evidence/raven2-vulkan-kernel-census/README.md` is one document over every run
of the campaign, so a lane's copy names directories another lane carries. The
prose is left as the branch wrote it rather than rewritten, and the references
are enumerated instead.

- census-timing names the retained `20260902T0819Z`, `20260902T1302Z`,
  `20260902T1417Z`, `20260902T2011Z`, and `0222Z` directories, chains six and
  seven, the first calibration on 34de93f, all of which are retained-evidence,
  and the 250 ms sidecar gap under a forced clock policy, which is
  dpm-telemetry.
- dpm-telemetry names the P-nosidecar, I0, I1, and S states, `arms.tsv`,
  `summary.tsv`, `acquisition-contract.tsv`, `sidecar_max_lost_fraction`,
  `census_regime=retired`, `QWEN_CENSUS_REUSE_BRICKS`, and the
  `20260902T2011Z` receipts. It also keeps main's `pipeline-census-v1` label
  where census-timing carries `pipeline-census-v3`, because the section stating
  the five execution states belongs to census-timing and copying it would put
  one section in two lanes.
- retained-evidence names `decode-decomposition.md`, the comparability band and
  regime precondition, the served A/B harness, `clock_invariant`'s mclk floor,
  the sibling E1 ISA dumps at `20260902T2039Z` and `20260902T1312Z`, and the E4
  candidate build with its registered activation-group-sums band.

## Checks per lane

Each lane's branch was checked out on the workstation and put through `sh -n`
and `shellcheck -S warning` over every tracked shell script, `ruff check` over
the tree, `python3 remote/check-text-policy.py`,
`remote/refresh-evidence-manifest.sh --check`,
`remote/check-ledger-evidence.sh`, and every unit test the lane carries that
`remote/repository-quality-gates.sh` registers as a cell.

`sh -n`, `shellcheck -S warning`, `ruff check`, `check-text-policy.py`, and
`check-ledger-evidence.sh` pass on all eight. The manifest check passes on all
eight and is the one pass in each row's count that carries less weight than the
others: the split script runs `refresh-evidence-manifest.sh` in write mode as
its last step per lane, so `--check` reports what that write produced. What it
does establish is that the manifest and the tree agree per lane, which is the
property a lane merged alone needs.

`remote/repository-quality-gates.sh` registers no cell naming
`remote/test-probe-dpm-authority.sh`, on main or on the source branch.
dpm-telemetry carries the test and runs it green directly, so a regression in
`probe-dpm-authority.sh` reaches no gate until a successor change registers the
cell.

`lane/census-timing` inherits `# neighbours overlap` in CLAUDE.md from the
source branch. American English governs checked-in text and
`check-text-policy.py` carries no spelling rule, so the gate passes and the
spelling stands; it is the census-timing reviewer's to correct.

| lane | tip | commits | replayed source commits | checks |
| --- | --- | ---: | ---: | --- |
| census-timing | `e9accb5` | 31 | 29 | 16 pass, `remote/test-radv-low-priority-env.sh` not run |
| build-cache-identity | `65f7c69` | 3 | 2 | 10 pass, `remote/test-radv-low-priority-env.sh` not run |
| dpm-telemetry | `d649f09` | 9 | 7 | 17 pass, `remote/test-radv-low-priority-env.sh` not run |
| shader-e4 | `8306377` | 9 | 7 | 12 pass, `remote/test-radv-low-priority-env.sh` not run |
| correctness-witnesses | `48ff457` | 15 | 13 | 18 pass, `remote/test-radv-low-priority-env.sh` not run |
| served-ab-harness | `5136c3e` | 15 | 13 | 17 pass, `remote/test-run-served-binary-ab.sh` not run, `remote/test-radv-low-priority-env.sh` not run |
| retained-evidence | `2d71649` | 20 | 18 | 8 pass, `remote/test-radv-low-priority-env.sh` not run |
| deployment-followups | `7393ff2` | 6 | 6 | 12 pass, `remote/test-radv-low-priority-env.sh` not run |

deployment-followups also runs `remote/test-deployment-bundle.sh` at 38 checks,
`python3 remote/test-open-verified-lock-descriptor.py` at 15 checks, and
`ruff format --check` and `mypy --strict` over the eight typed files
`repository-quality-gates.sh` names, all accepted. `authorize-broker.py` sits
outside that typed set and fails both on main already, so the lane inherits
that state rather than introducing it.

Two checks cannot run on this workstation and are reported as not run with
their reason rather than as failures.

- `remote/test-radv-low-priority-env.sh` on every lane. The wrapper refuses an
  unreadable ICD ahead of every assertion and this host has no
  `/usr/share/vulkan/icd.d/radeon_icd.x86_64.json`. It runs on the appliance.
- `remote/test-run-served-binary-ab.sh` on served-ab-harness. The harness
  refuses a host other than the appliance, so its preflight fixture ends at
  `runs on the measured host` here.

## Commits

Every commit of `origin/main..origin/stage-a-census-brackets` with the lane or
lanes that carry it. `cherry-pick` means the whole commit landed in one lane
with its authorship and message unchanged; `split` means the commit spans lanes
and each lane re-committed its own paths under the original subject and body
with a `Split-from` trailer. `dropped` means the split carries the commit's
content without the commit, for the reason the eighth-lane section gives.
deployment-followups is built by hand and appears in the table through its own
section rather than through the replay log.

| commit | subject | lane | mode |
| --- | --- | --- | --- |
| 74ddab7 | deployment: refuse a multiply linked lock leaf and a doubled eligibility row | deployment-followups | cherry-pick |
| 0259199 | census: bracket every dispatch, read on availability, bind the request | census-timing | split |
| a3105b4 | evidence: record the gated head beside the final head of the lock-leaf regression | deployment-followups | cherry-pick |
| 7e9e09b | evidence: carry gate-heads.tsv in the manifest | deployment-followups | cherry-pick |
| b02fabd | census: state ownership from exclusive brackets, bind every control to its evidence | census-timing, deployment-followups | split |
| 8f0f206 | census: carry the artifact ledger into every arm and retain the v2 diagnostic run | census-timing, retained-evidence | split |
| 2c33709 | evidence: carry the v2 diagnostic census run in the manifest | none | dropped |
| e18b840 | census: quote the empty CDPATH in the hash test | census-timing | cherry-pick |
| b4a2735 | census: hold a calibration to three accepted controls and bind the scoreboard denominator | census-timing | split |
| d30aef5 | census: decide the FCLK sidecar allowance by reading the attribute | census-timing | split |
| 34de93f | census: bind P and I to one base build, close the S environment, and bound sidecar gaps | census-timing | split |
| 587a69f | census: bind attribution to one calibration contract and classify S blocks by token column | census-timing | split |
| 86e1773 | census: sample at nice 19 every 10 ms and register the decode decomposition | census-timing | split |
| 1a182c5 | census: read every backend context section and admit the diagnostic profile in the monitor | census-timing | cherry-pick |
| 59c03c8 | census: read the token column over weight matmuls and retain the 34de93f acquisition | census-timing, retained-evidence | split |
| e4c148a | census: defer row emission into a binary buffer and let the sampler float across both cores | census-timing, retained-evidence | split |
| 49c8ed8 | census: bind the runtime tree into the contract, compare each arm's server to its role, and keep instrumentation rows off serving manifests | census-timing | split |
| 1878591 | census: state-preserving calibration, C telemetry broker, and the compiler laboratory | census-timing, build-cache-identity, shader-e4, retained-evidence | split |
| be25554 | gate: the cache-key cell reads build-llama-preset.sh | none | dropped |
| 67fc486 | census: the scoreboard inputs check counts each setting once | census-timing | cherry-pick |
| 995ef68 | test: poll the lease release after the web-launch session ends | deployment-followups | cherry-pick |
| d173156 | census: E4b-A activation sideplane candidate with the measured projection fan-out | shader-e4 | split |
| f5f92d8 | web-mcp: the broker binds over TIME_WAIT remainders of its own port | deployment-followups | cherry-pick |
| d490a39 | census: control verdicts over replicated pairs, a reachable quiescence, and the 0819Z run | census-timing, retained-evidence | split |
| b7a3612 | census: E1 ISA inventory, the E4 mechanism receipt, and the clock-state invariant | census-timing, shader-e4, retained-evidence | split |
| 9944c64 | census: served binary ABBA harness for a candidate build | census-timing, shader-e4, served-ab-harness | split |
| 05bd95f | census: clock regime precondition and comparability by band | census-timing, served-ab-harness, retained-evidence | split |
| 203805d | census: the served A/B admits a control manifest naming no candidate series, and the sampler runs at 20 ms | census-timing, served-ab-harness, retained-evidence | split |
| d1dea50 | census: the graphics clock is a commanded invariant over delivered clocks | census-timing, dpm-telemetry, served-ab-harness | split |
| 239af70 | census: the level selection readback polls before it is judged | census-timing | cherry-pick |
| 26cea7f | census: rebuild the broker on a source change, tolerate fabric transients, and document the parts | census-timing, dpm-telemetry, served-ab-harness | split |
| 803d468 | census: quiescence under a pinned clock, the first commanded-clock runs, and the fabric refusal | census-timing, dpm-telemetry, served-ab-harness, retained-evidence | split |
| 8e852f8 | census: name the commanded clock state, split the stall bound by policy, and measure the priority term | census-timing, dpm-telemetry, served-ab-harness, retained-evidence | split |
| 856e88f | census: kernel-delta mode judges a patch by one pipeline's GPU bracket with a null pipeline beside it | served-ab-harness, retained-evidence | split |
| 70fa4ef | evidence: register the kernel-delta design and its falsifiers ahead of the E4 bracket run | correctness-witnesses | split |
| 353219d | census: retain the first kernel-delta acquisition and add the token-id and log-probability witness | correctness-witnesses, retained-evidence | split |
| 9c08c94 | census: kernel-delta admission is whole or nothing, and the reader states union, span, ratio, and executed modules | shader-e4, correctness-witnesses, served-ab-harness, retained-evidence | split |
| 40a8a4f | census: merge probability entries onto the token array by id, and record the kernel-delta result | correctness-witnesses, retained-evidence | split |
| eea386c | census: retain the E4 witness and its zero-movement calibration, and let the witness candidate run on the CPU backend | correctness-witnesses | split |
| 65cfbb9 | evidence: the E4 witness against two references, zero compile movement and the CPU backend envelope | correctness-witnesses, retained-evidence | split |
| 37c3fcb | census: judge the E4 witness on decision margins over a fresh holdout, and retire the unreferenced bound | correctness-witnesses, retained-evidence | split |
| a3ed7cb | census: admit a withheld probability entry by the multi-byte sequence that follows it | correctness-witnesses | split |
| 2232e15 | census: bound the TERM fixture by the campaign's life rather than by a fixed poll budget | served-ab-harness | cherry-pick |
| 8d10749 | census: refuse malformed metadata, an emit total apart from its parts, and instants that disagree with their span | census-timing | cherry-pick |
| de878d3 | census: name the row iterator in the margin witness test so ruff E741 passes | correctness-witnesses | cherry-pick |
| de691ef | evidence: the E4 margin holdout, ten prompts held and two argmax flips at ties of 0.0001 and 0.0023 nat | correctness-witnesses, retained-evidence | split |
| 05ad0e8 | gates: key every cell on the tools the gate runs, the file mode, and bare-name imports; refuse binary reuse over unkeyed edits | build-cache-identity | split |
| e0d179a | telemetry: mark fresh DPM reads in the record and judge the clock invariant over reads rather than rows | dpm-telemetry | cherry-pick |
| 3db353c | census: scrub the sideplane variables, bind the probe to its hwmon and lease, and refuse witness bounds that fail open | dpm-telemetry, shader-e4, correctness-witnesses | split |
| bddc3eb | gates: register the receipt-diff, shader-lab replay, and kernel-delta witness tests as cells | none | dropped |
| 63df204 | census: bind every arm to the tree, model, and series it claims, and let no recorded input go unread in the admission | census-timing, served-ab-harness | split |
| baf58d8 | census: hand every measurement arm a closed environment and hold the lease across the clock | census-timing, dpm-telemetry, correctness-witnesses, served-ab-harness | split |
| fb50ef7 | evidence: the E4 quality gate, the same 40 of 65 on four arms and 64 of 65 replies byte-identical | correctness-witnesses, retained-evidence | split |
| 161f4e7 | census: bind the arm's state directory to the lease the campaign locked, and state the cooldown's lease | census-timing, served-ab-harness | split |
| 5039c3f | shader-lab: track the replay fixtures' radv-debug.log files that a global ignore rule kept out of the tree | shader-e4 | cherry-pick |

## Files

Every path the branch touches, by lane. Retained evidence trees are collapsed
to one row per run directory with the file count beside it.

### build-cache-identity (4 paths)

- `remote/build-cache-keys.sh`
- `remote/gate-cell-key.sh`
- `remote/test-build-cache-keys.sh`
- `remote/test-repository-gate-cells.sh`

### census-timing (37 paths)

- `evidence/raven2-vulkan-kernel-census/decode-decomposition.md`
- `evidence/raven2-vulkan-kernel-census/replay-corpus/` (1 files)
- `evidence/raven2-vulkan-kernel-census/replay-corpus/02-P/` (3 files)
- `evidence/raven2-vulkan-kernel-census/replay-corpus/10-I1/` (4 files)
- `evidence/raven2-vulkan-kernel-census/replay-corpus/13-S/` (2 files)
- `evidence/raven2-vulkan-kernel-census/state-preserving-campaign.md`
- `patches/llama-vulkan-pipeline-census.patch`
- `remote/await-quiescence.sh`
- `remote/build-telemetry-broker.sh`
- `remote/census-arm-lib.sh`
- `remote/measure-served-decode.sh`
- `remote/monitor-qwen-runtime.sh`
- `remote/prepare-llama-census-source.sh`
- `remote/qwen-webui-control.sh`
- `remote/run-raven2-vulkan-kernel-census.sh`
- `remote/sample-clock-sidecar.py`
- `remote/summarize-census-controls.py`
- `remote/summarize-kernel-census.py`
- `remote/summarize-perf-logger-slice.py`
- `remote/telemetry-broker.c`
- `remote/test-await-quiescence.sh`
- `remote/test-census-controls.py`
- `remote/test-census-replay-corpus.py`
- `remote/test-census-sha256.sh`
- `remote/test-qwen-runtime-guards.sh`
- `remote/test-run-raven2-vulkan-kernel-census.sh`
- `remote/test-sample-clock-sidecar.py`
- `remote/test-summarize-kernel-census.py`
- `remote/test-summarize-perf-logger-slice.py`
- `remote/test-telemetry-broker.sh`
- `remote/validate-clock-sidecar.py`

### correctness-witnesses (392 paths)

- `evidence/raven2-vulkan-kernel-census/e4/` (2 files)
- `evidence/raven2-vulkan-kernel-census/e4/kernel-delta-witness-20260903T0148Z/` (100 files)
- `evidence/raven2-vulkan-kernel-census/e4/margin-holdout-20260903T0456Z/` (197 files)
- `evidence/raven2-vulkan-kernel-census/e4/quality-gate-20260903T0547Z/` (10 files)
- `evidence/raven2-vulkan-kernel-census/e4/witness-calibration-20260903T0203Z/` (51 files)
- `evidence/raven2-vulkan-kernel-census/e4/witness-cpu-reference-20260903T0220Z/` (27 files)
- `remote/run-kernel-delta-witness.sh`
- `remote/summarize-margin-witness.py`
- `remote/test-run-kernel-delta-witness.sh`
- `remote/test-summarize-margin-witness.py`
- `remote/witness-prompts/holdout-12.tsv`

### dpm-telemetry (118 paths)

- `evidence/hardware/qwen-laptop-parts.md`
- `evidence/hardware/qwen-laptop-parts.tsv`
- `evidence/raven2-vulkan-kernel-census/dpm-authority-design.md`
- `evidence/raven2-vulkan-kernel-census/dpm-authority/` (1 files)
- `evidence/raven2-vulkan-kernel-census/dpm-authority/20260902T1813Z/` (20 files)
- `evidence/raven2-vulkan-kernel-census/dpm-authority/20260902T1820Z-postload/` (23 files)
- `evidence/raven2-vulkan-kernel-census/dpm-authority/20260902T1822Z-actual/` (10 files)
- `evidence/raven2-vulkan-kernel-census/dpm-authority/20260902T1826Z-manual/` (12 files)
- `evidence/raven2-vulkan-kernel-census/dpm-authority/20260902T2002Z-fclk-level3/` (4 files)
- `evidence/raven2-vulkan-kernel-census/dpm-authority/20260902T2048Z-fclk-rescind/` (6 files)
- `evidence/raven2-vulkan-kernel-census/dpm-authority/20260902T2154Z-nice-probe/` (36 files)
- `evidence/raven2-vulkan-kernel-census/fclk-command-research.md`
- `remote/probe-dpm-authority.sh`
- `remote/test-probe-dpm-authority.sh`

### dropped (8 paths)

- `evidence/deployment-bundle-presets/20260901T2352Z/` (1 files)
- `evidence/deployment-bundle-presets/README.md`
- `remote/build-deployment-bundle.sh`
- `remote/open-verified-lock-descriptor.py`
- `remote/test-deployment-bundle.sh`
- `remote/test-qwen-web-launch.sh`
- `remote/verify-deployment-bundle.sh`
- `remote/web-mcp/authorize-broker.py`

### retained-evidence (534 paths)

- `evidence/raven2-vulkan-kernel-census/20260902T0222Z/` (16 files)
- `evidence/raven2-vulkan-kernel-census/20260902T0426Z/` (23 files)
- `evidence/raven2-vulkan-kernel-census/20260902T0525Z/` (27 files)
- `evidence/raven2-vulkan-kernel-census/20260902T0617Z/` (27 files)
- `evidence/raven2-vulkan-kernel-census/20260902T0819Z/` (35 files)
- `evidence/raven2-vulkan-kernel-census/20260902T1302Z/` (48 files)
- `evidence/raven2-vulkan-kernel-census/20260902T1417Z/` (48 files)
- `evidence/raven2-vulkan-kernel-census/20260902T1556Z/` (50 files)
- `evidence/raven2-vulkan-kernel-census/20260902T2011Z/` (54 files)
- `evidence/raven2-vulkan-kernel-census/20260902T2124Z/` (73 files)
- `evidence/raven2-vulkan-kernel-census/e4/kernel-delta-20260902T2312Z/` (55 files)
- `evidence/raven2-vulkan-kernel-census/e4/served-ab-20260902T2032Z/` (26 files)
- `evidence/raven2-vulkan-kernel-census/e4/served-ab-20260902T2139Z/` (26 files)
- `evidence/raven2-vulkan-kernel-census/e4/served-ab-20260902T2222Z/` (26 files)

### served-ab-harness (5 paths)

- `evidence/raven2-vulkan-kernel-census/e4/` (1 files)
- `remote/run-served-binary-ab.sh`
- `remote/summarize-bracket-ab.py`
- `remote/test-run-served-binary-ab.sh`
- `remote/test-summarize-bracket-ab.py`

### shader-e4 (77 paths)

- `evidence/raven2-vulkan-kernel-census/e1/` (6 files)
- `evidence/raven2-vulkan-kernel-census/e1/isa/` (4 files)
- `evidence/raven2-vulkan-kernel-census/e1/nir/` (2 files)
- `evidence/raven2-vulkan-kernel-census/e1/receipts/` (16 files)
- `evidence/raven2-vulkan-kernel-census/e1/stats/` (7 files)
- `evidence/raven2-vulkan-kernel-census/e4/` (8 files)
- `evidence/raven2-vulkan-kernel-census/e4/e1-isa-e4-20260903T0140Z/` (4 files)
- `patches/llama-vulkan-q4k-activation-group-sums.patch`
- `patches/llama-vulkan-q4k-activation-sideplane.patch`
- `remote/dump-radv-shader-isa.sh`
- `remote/isa-probes/README.md`
- `remote/isa-probes/q4k-float-dot.comp`
- `remote/isa-probes/q4k-float-dot.spv`
- `remote/isa-probes/q4k-integer-dot.comp`
- `remote/isa-probes/q4k-integer-dot.spv`
- `remote/isa-probes/q4k-packed-u8-dot.comp`
- `remote/isa-probes/q4k-packed-u8-dot.spv`
- `remote/isa-probes/q4k-widen-early-dot.comp`
- `remote/isa-probes/q4k-widen-early-dot.spv`
- `remote/isa-probes/run-probe.c`
- `remote/llama-patch-series.tsv`
- `remote/raven2-shader-lab/README.md`
- `remote/raven2-shader-lab/depth.py`
- `remote/raven2-shader-lab/lab.sh`
- `remote/raven2-shader-lab/receipt-diff.sh`
- `remote/raven2-shader-lab/shader-lab.c`
- `remote/raven2-shader-lab/test-depth.py`
- `remote/raven2-shader-lab/test-fixtures/replay-candidate/harness.txt`
- `remote/raven2-shader-lab/test-fixtures/replay-candidate/radv-debug.log`
- `remote/raven2-shader-lab/test-fixtures/replay-control/harness.txt`
- `remote/raven2-shader-lab/test-fixtures/replay-control/radv-debug.log`
- `remote/raven2-shader-lab/test-fixtures/replay-two-pipelines/harness.txt`
- `remote/raven2-shader-lab/test-fixtures/replay-two-pipelines/radv-debug.log`
- `remote/raven2-shader-lab/test-lab-replay.sh`
- `remote/raven2-shader-lab/test-receipt-diff.sh`
- `remote/summarize-radv-isa.py`
- `remote/test-summarize-radv-isa.py`

### shared (8 paths)

- `CLAUDE.md`
- `evidence/SHA256SUMS`
- `evidence/raven2-vulkan-kernel-census/README.md`
- `remote/build-llama-preset.sh`
- `remote/check-text-policy.py`
- `remote/radv-low-priority-env.sh`
- `remote/repository-quality-gates.sh`
- `remote/test-radv-low-priority-env.sh`

### unassigned (5 paths)

- `remote/activate-deployment-bundle.sh`
- `remote/deployment-bundle-name.sh`
- `remote/resolve-active-deployment.sh`
- `remote/test-open-verified-lock-descriptor.py`
- `remote/test-run-fixed64-served-campaign.sh`

## Review threads

The 89 threads of `replies.tsv` mapped to lanes by the path each names. The
`shared` rows are threads against a file several lanes each own part of.

| thread | path | disposition | lane |
| --- | --- | --- | --- |
| PRRT_kwDOUEfplM6egz15 | `evidence/raven2-vulkan-kernel-census/README.md` | fixed | shared |
| PRRT_kwDOUEfplM6egz2A | `patches/llama-vulkan-q4k-activation-sideplane.patch` | fixed | shader-e4 |
| PRRT_kwDOUEfplM6ebHiY | `patches/llama-vulkan-q4k-activation-sideplane.patch` | OPEN-DEFER | shader-e4 |
| PRRT_kwDOUEfplM6eaVhq | `remote/build-cache-keys.sh` | fixed | build-cache-identity |
| PRRT_kwDOUEfplM6en4kF | `remote/build-cache-keys.sh` | fixed | build-cache-identity |
| PRRT_kwDOUEfplM6ewTrc | `remote/build-cache-keys.sh` | fixed | build-cache-identity |
| PRRT_kwDOUEfplM6ewTrW | `remote/build-deployment-bundle.sh` | OPEN-DEFER | dropped |
| PRRT_kwDOUEfplM6eaVhU | `remote/build-llama-preset.sh` | fixed | shared |
| PRRT_kwDOUEfplM6eaVhj | `remote/build-llama-preset.sh` | skipped | shared |
| PRRT_kwDOUEfplM6en4ju | `remote/build-llama-preset.sh` | fixed | shared |
| PRRT_kwDOUEfplM6en4j0 | `remote/build-llama-preset.sh` | skipped | shared |
| PRRT_kwDOUEfplM6es_3X | `remote/build-llama-preset.sh` | fixed | shared |
| PRRT_kwDOUEfplM6es_3a | `remote/build-llama-preset.sh` | skipped | shared |
| PRRT_kwDOUEfplM6eqdCj | `remote/census-arm-lib.sh` | OPEN-DEFER | census-timing |
| PRRT_kwDOUEfplM6eaVhc | `remote/dump-radv-shader-isa.sh` | fixed | shader-e4 |
| PRRT_kwDOUEfplM6evzqS | `remote/dump-radv-shader-isa.sh` | fixed | shader-e4 |
| PRRT_kwDOUEfplM6eaViP | `remote/gate-cell-key.sh` | fixed | build-cache-identity |
| PRRT_kwDOUEfplM6er9-e | `remote/gate-cell-key.sh` | fixed | build-cache-identity |
| PRRT_kwDOUEfplM6ejTWu | `remote/gate-cell-key.sh` | fixed | build-cache-identity |
| PRRT_kwDOUEfplM6eiipo | `remote/gate-cell-key.sh` | fixed | build-cache-identity |
| PRRT_kwDOUEfplM6ergpb | `remote/probe-dpm-authority.sh` | fixed | dpm-telemetry |
| PRRT_kwDOUEfplM6evzqL | `remote/probe-dpm-authority.sh` | fixed | dpm-telemetry |
| PRRT_kwDOUEfplM6epOyQ | `remote/probe-dpm-authority.sh` | fixed | dpm-telemetry |
| PRRT_kwDOUEfplM6ergpP | `remote/probe-dpm-authority.sh` | fixed | dpm-telemetry |
| PRRT_kwDOUEfplM6ejTXK | `remote/radv-low-priority-env.sh` | fixed | shared |
| PRRT_kwDOUEfplM6er9-k | `remote/raven2-shader-lab/depth.py` | OPEN-DEFER | shader-e4 |
| PRRT_kwDOUEfplM6eaViA | `remote/raven2-shader-lab/depth.py` | OPEN-DEFER | shader-e4 |
| PRRT_kwDOUEfplM6ekcok | `remote/raven2-shader-lab/lab.sh` | fixed | shader-e4 |
| PRRT_kwDOUEfplM6er9-n | `remote/raven2-shader-lab/lab.sh` | OPEN-DEFER | shader-e4 |
| PRRT_kwDOUEfplM6er9-K | `remote/raven2-shader-lab/lab.sh` | OPEN-DEFER | shader-e4 |
| PRRT_kwDOUEfplM6ergpW | `remote/raven2-shader-lab/receipt-diff.sh` | fixed | shader-e4 |
| PRRT_kwDOUEfplM6eaVh8 | `remote/raven2-shader-lab/receipt-diff.sh` | fixed | shader-e4 |
| PRRT_kwDOUEfplM6evzp_ | `remote/run-kernel-delta-witness.sh` | fixed | correctness-witnesses |
| PRRT_kwDOUEfplM6evzqF | `remote/run-kernel-delta-witness.sh` | fixed | correctness-witnesses |
| PRRT_kwDOUEfplM6ewLjK | `remote/run-kernel-delta-witness.sh` | fixed | correctness-witnesses |
| PRRT_kwDOUEfplM6ekcoy | `remote/run-raven2-vulkan-kernel-census.sh` | ADDRESSED | census-timing |
| PRRT_kwDOUEfplM6en4j9 | `remote/run-raven2-vulkan-kernel-census.sh` | fixed | census-timing |
| PRRT_kwDOUEfplM6eiip1 | `remote/run-raven2-vulkan-kernel-census.sh` | fixed | census-timing |
| PRRT_kwDOUEfplM6eaViJ | `remote/run-raven2-vulkan-kernel-census.sh` | fixed | census-timing |
| PRRT_kwDOUEfplM6en4kP | `remote/run-raven2-vulkan-kernel-census.sh` | fixed | census-timing |
| PRRT_kwDOUEfplM6epOyp | `remote/run-raven2-vulkan-kernel-census.sh` | fixed | census-timing |
| PRRT_kwDOUEfplM6eaVh6 | `remote/run-raven2-vulkan-kernel-census.sh` | fixed | census-timing |
| PRRT_kwDOUEfplM6eaVhy | `remote/run-raven2-vulkan-kernel-census.sh` | OPEN-DEFER | census-timing |
| PRRT_kwDOUEfplM6eqdB4 | `remote/run-raven2-vulkan-kernel-census.sh` | fixed | census-timing |
| PRRT_kwDOUEfplM6er9-F | `remote/run-raven2-vulkan-kernel-census.sh` | OPEN-DEFER | census-timing |
| PRRT_kwDOUEfplM6eqdBz | `remote/run-raven2-vulkan-kernel-census.sh` | fixed | census-timing |
| PRRT_kwDOUEfplM6eaVhQ | `remote/run-raven2-vulkan-kernel-census.sh` | fixed | census-timing |
| PRRT_kwDOUEfplM6epOyV | `remote/run-served-binary-ab.sh` | fixed | served-ab-harness |
| PRRT_kwDOUEfplM6epOyL | `remote/run-served-binary-ab.sh` | fixed | served-ab-harness |
| PRRT_kwDOUEfplM6ejTV1 | `remote/run-served-binary-ab.sh` | fixed | served-ab-harness |
| PRRT_kwDOUEfplM6er9-a | `remote/run-served-binary-ab.sh` | fixed | served-ab-harness |
| PRRT_kwDOUEfplM6en4kL | `remote/run-served-binary-ab.sh` | fixed | served-ab-harness |
| PRRT_kwDOUEfplM6ergpf | `remote/run-served-binary-ab.sh` | fixed | served-ab-harness |
| PRRT_kwDOUEfplM6ewTq_ | `remote/run-served-binary-ab.sh` | fixed | served-ab-harness |
| PRRT_kwDOUEfplM6ejTWl | `remote/run-served-binary-ab.sh` | fixed | served-ab-harness |
| PRRT_kwDOUEfplM6ergpR | `remote/run-served-binary-ab.sh` | fixed | served-ab-harness |
| PRRT_kwDOUEfplM6ewTrC | `remote/run-served-binary-ab.sh` | fixed | served-ab-harness |
| PRRT_kwDOUEfplM6etZ-e | `remote/summarize-bracket-ab.py` | fixed | served-ab-harness |
| PRRT_kwDOUEfplM6ebHiJ | `remote/summarize-census-controls.py` | DISAGREE | census-timing |
| PRRT_kwDOUEfplM6eqdCF | `remote/summarize-census-controls.py` | fixed | census-timing |
| PRRT_kwDOUEfplM6ewTrH | `remote/summarize-census-controls.py` | fixed | census-timing |
| PRRT_kwDOUEfplM6eqdCM | `remote/summarize-census-controls.py` | fixed | census-timing |
| PRRT_kwDOUEfplM6ewTrO | `remote/summarize-census-controls.py` | fixed | census-timing |
| PRRT_kwDOUEfplM6eiipu | `remote/summarize-kernel-census.py` | fixed | census-timing |
| PRRT_kwDOUEfplM6es_3k | `remote/summarize-kernel-census.py` | fixed | census-timing |
| PRRT_kwDOUEfplM6ejTW2 | `remote/summarize-kernel-census.py` | fixed | census-timing |
| PRRT_kwDOUEfplM6ergpI | `remote/summarize-kernel-census.py` | fixed | census-timing |
| PRRT_kwDOUEfplM6eqdCa | `remote/summarize-kernel-census.py` | fixed | census-timing |
| PRRT_kwDOUEfplM6ebHim | `remote/summarize-kernel-census.py` | fixed | census-timing |
| PRRT_kwDOUEfplM6ebHic | `remote/telemetry-broker.c` | OPEN-DEFER | census-timing |
| PRRT_kwDOUEfplM6epOyD | `remote/telemetry-broker.c` | fixed | census-timing |
| PRRT_kwDOUEfplM6egz1w | `remote/test-await-quiescence.sh` | ADDRESSED | census-timing |
| PRRT_kwDOUEfplM6eqdB- | `remote/test-await-quiescence.sh` | ADDRESSED | census-timing |
| PRRT_kwDOUEfplM6eqdCP | `remote/test-probe-dpm-authority.sh` | fixed | dpm-telemetry |
| PRRT_kwDOUEfplM6ekco4 | `remote/test-run-raven2-vulkan-kernel-census.sh` | ADDRESSED | census-timing |
| PRRT_kwDOUEfplM6eiip3 | `remote/validate-clock-sidecar.py` | fixed | census-timing |
| PRRT_kwDOUEfplM6eqdCW | `remote/validate-clock-sidecar.py` | fixed | census-timing |
| PRRT_kwDOUEfplM6ewLjR | `remote/validate-clock-sidecar.py` | fixed | census-timing |
| PRRT_kwDOUEfplM6ekcou | `remote/validate-clock-sidecar.py` | OPEN-DEFER | census-timing |
| PRRT_kwDOUEfplM6en4j5 | `remote/validate-clock-sidecar.py` | fixed | census-timing |
| PRRT_kwDOUEfplM6es_3f | `remote/validate-clock-sidecar.py` | fixed | census-timing |
| PRRT_kwDOUEfplM6ebHiC | `remote/validate-clock-sidecar.py` | fixed | census-timing |
| PRRT_kwDOUEfplM6epOyI | `remote/validate-clock-sidecar.py` | fixed | census-timing |
| PRRT_kwDOUEfplM6ewLjM | `remote/validate-clock-sidecar.py` | fixed | census-timing |
| PRRT_kwDOUEfplM6ebHiQ | `remote/validate-clock-sidecar.py` | fixed | census-timing |
| PRRT_kwDOUEfplM6ejTXD | `remote/validate-clock-sidecar.py` | fixed | census-timing |
| PRRT_kwDOUEfplM6ewLjP | `remote/validate-clock-sidecar.py` | fixed | census-timing |
| PRRT_kwDOUEfplM6egz2I | `remote/validate-clock-sidecar.py` | fixed | census-timing |
| PRRT_kwDOUEfplM6er9-S | `remote/validate-clock-sidecar.py` | fixed | census-timing |

- build-cache-identity: 7 threads
- census-timing: 43 threads
- correctness-witnesses: 3 threads
- dpm-telemetry: 5 threads
- dropped: 1 threads
- served-ab-harness: 11 threads
- shader-e4: 11 threads
- shared: 8 threads

Every `OPEN-DEFER` thread travels with the file it names, so the successor
work each one defers lands in that thread's lane.

## Landings

`lane/census-timing` merged into main as PR #116 at commit 717dbef. `lane/deployment-followups` merged into main as PR #123 at commit 36d54a9. The remaining six lanes remain unmerged: build-cache-identity, dpm-telemetry, shader-e4, correctness-witnesses, served-ab-harness, and retained-evidence.
