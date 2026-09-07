# Installation requirements

This tree runs on two machines and each module belongs to one of them. The
appliance is the Raven2 laptop that owns the device, the Vulkan runtime, and
every serving path; `qwen-laptop` stands for its name throughout the
repository. The workstation carries the Git tree and three helpers that exist
because two 2.3 GHz cores are slow: the container build, the UI build, and the
static candidate reader. A module marked `laptop` installs on the appliance, a
module marked `workstation` installs beside the Git tree, and a module marked
`both` installs on either machine that runs it.

`docs/install-requirements.tsv` is the machine-readable form of this document
and `remote/check-install-requirements.sh` reads it. The script takes the host
as an argument rather than reading a hostname, because a hostname branch would
put a private name in a committed script and because the same tree is read on
the appliance, on the workstation, and inside a container that carries neither
name:

```sh
remote/check-install-requirements.sh laptop        # on the appliance
remote/check-install-requirements.sh workstation   # beside the Git tree
remote/check-install-requirements.sh validate      # row shape and cited paths
```

`validate` runs the shape rules and the cited-path rule alone, and
`remote/repository-quality-gates.sh` calls it beside
`check-validated-tuples.sh` and `check-ledger-evidence.sh`. Row shape and the
existence of a file a row cites are properties of the tree, so both are
asserted where the tree is; presence of the software is a property of a host,
so a host run resolves no `source_ref` at all. That split is what makes the
appliance arm runnable: `remote/sync-runtime-tree.sh:85` copies `remote/` and
`patches/`, so a synced runtime tree holds neither `docs/` nor the
evidence a row cites, and a host run that resolved those paths would refuse
every requirement over a directory the sync never sent. Run the host arm from
the appliance's own Git checkout, or name the ledger as the second argument.

Each run prints one line per requirement over `present`, `absent`,
`optional-absent`, `skipped`, and `not-run`, and an `absent` required row is
what moves the exit status.

Every `source_ref` line number was read at commit
`9398a467a794ec7b6705b7a35ec0f35e4481f5fd`. A line number moves as the tree
moves; the path is what the gate proves, and the gate refuses a row whose cited
path leaves the tree.

## What the ledger carries

An environment variable earns a row where the module needs it set to work at
all -- a key file, a settings path, a runtime location. A variable that selects
behavior inside a working install stays out: the submission profile names, the
cache-triple overrides, the context ceilings, and the tier and quarantine
switches are configuration rather than installation, and putting them here
would turn a requirement list into an environment dump.

`kind` carries optionality. `command`, `package`, `python-module`,
`node-package`, `env`, `path`, and `sysfs` are required for their host. An
`optional-` prefix marks something the tree names a convenience and runs
without. `manual` marks a requirement whose observation needs privilege the
checker declines to take; those rows report `not-run` and this document states
what a human checks instead.

The ledger names a tool where a script invokes it and a minimal image might
drop it. The POSIX shell's own builtins and the coreutils every distribution
installs by default carry no rows unless a script depends on a specific
implementation, which `mv -T` is the one case of.

| Module | Rows | Host |
| --- | ---: | --- |
| launch-chain | 35 | laptop, plus three sync rows |
| llama-build | 13 | laptop |
| container-build | 6 | workstation |
| ui-build | 4 | workstation |
| measurement | 14 | laptop |
| quality-suite | 4 | both |
| web-lane | 13 | laptop, browser and YAML on both |
| image-lane | 9 | laptop |
| model-fetch | 6 | both |
| hip-rocm | 5 | laptop |
| repository-gate | 16 | both |
| Total | 125 | |

A count is module-requirement pairs rather than distinct software. `cc` earns a
row in three modules because three different mechanisms need it, and each row
carries the file that establishes it there.

## Three findings that change what a reader installs

The integer dot product reaches the build through no CMake option. RADV
advertises `shaderIntegerDotProduct` and leaves every `*Accelerated` flag
false, so llama.cpp declines the `_q8_1` pipelines on its own; the only name in
this tree is the runtime variable `GGML_VK_DISABLE_INTEGER_DOT_PRODUCT`, which
`remote/radv-low-priority-env.sh:67` unsets in the profile scrub. Installing a
newer shader compiler changes nothing about it. The build scripts pin no
`glslc` or `glslang` version and check presence alone
(`remote/build-llama-vulkan.sh:32`), and the two hosts observed here run
`shaderc 2023.8` against `2026.3` with the same result.

A C compiler and the Vulkan development headers belong to the launch chain
rather than to the build. `remote/model-memory-preflight.sh:35` compiles
`vulkan-memory-budget-probe.c` with `cc ... -lvulkan` on every launch and runs
it against the RADV ICD file, so an appliance carrying a prebuilt
`llama-server` and no compiler refuses at the preflight rather than at a
rebuild.

`c++` is a build requirement and not a gate requirement. The gate's own list at
`remote/repository-quality-gates.sh:18` names eleven commands and a browser and
holds no compiler; `remote/build-llama-vulkan.sh:90` runs
`test-vulkan-pacing-math.sh` and `test-vulkan-submit-limit.sh`, which compile
C++ at `remote/test-vulkan-pacing-math.sh:58` and
`remote/test-vulkan-submit-limit.sh:31`, and those tests sit outside the gate's
cell list.

## launch-chain

Host: laptop, with one row on both. `qwen-launch.sh` through
`qwen-router-exec-guard.sh`, the teardown, the watchdogs, and the deployment
bundle layer. tmux owns the session, so the whole chain lives or dies with it.
The kernel-hazard watcher requires unprivileged `dmesg`
(`remote/watch-qwen-kernel-hazards.sh:83` refuses the launch where
`kernel.dmesg_restrict` blocks it), and the deployment resolver requires an
activated bundle under the root rather than a loose binary.

| Requirement | Kind | Pin | Check | Established by |
| --- | --- | --- | --- | --- |
| `tmux` | command | - | `command -v tmux >/dev/null` | remote/qwen-webui-control.sh:174 |
| `curl` | command | - | `command -v curl >/dev/null` | remote/qwen-launch.sh:364, remote/qwen-webui-session.sh:255 |
| `cc` | command | - | `command -v cc >/dev/null` | remote/model-memory-preflight.sh:35 |
| `/usr/include/vulkan/vulkan.h` | path | - | `test -r /usr/include/vulkan/vulkan.h` | remote/model-memory-preflight.sh:36, remote/build-vulkan-graphics-service-probe.sh:18 |
| `radeon_icd.x86_64.json` | path | - | `test -r "${QWEN_RADV_ICD:-/usr/share/vulkan/icd.d/radeon_icd.x86_64.json}"` | remote/model-memory-preflight.sh:38 |
| `openssl` | optional-command | - | `command -v openssl >/dev/null` | remote/qwen-webui-session.sh:150, remote/qwen-webui-session.sh:152 |
| `pgrep` | command | - | `command -v pgrep >/dev/null` | remote/qwen-launch.sh:22, remote/qwen-teardown.sh:78 |
| `ps` | command | - | `command -v ps >/dev/null` | remote/monitor-qwen-runtime.sh:67, remote/watch-qwen-kernel-hazards.sh:25 |
| `ss` | optional-command | - | `command -v ss >/dev/null` | remote/qwen-teardown.sh:241 |
| `stat` | command | - | `command -v stat >/dev/null` | remote/qwen-launch.sh:231, remote/qwen-build-exec-guard.sh:117 |
| `readlink` | command | - | `command -v readlink >/dev/null` | remote/qwen-build-exec-guard.sh:44, remote/resolve-active-deployment.sh:39 |
| `mktemp` | command | - | `command -v mktemp >/dev/null` | remote/qwen-launch.sh:130, remote/model-memory-preflight.sh:31 |
| `hostname` | command | - | `command -v hostname >/dev/null` | remote/qwen-launch.sh:387 |
| `getconf` | command | - | `command -v getconf >/dev/null` | remote/monitor-qwen-runtime.sh:98 |
| `comm` | command | - | `command -v comm >/dev/null` | remote/check-runtime-tree.sh:155 |
| `mv` | command | GNU coreutils | `mv --version 2>/dev/null \| grep -qi 'GNU coreutils'` | remote/build-deployment-bundle.sh:206, remote/activate-deployment-bundle.sh:158 |
| pidfd process-group signal | manual | - | `python3 remote/signal-process-group.py --check` | remote/signal-process-group.py:156 |
| `HOME` | env | - | `[ -n "${HOME:-}" ]` | remote/qwen-launch.sh:17, remote/qwen-webui-control.sh:25 |
| `gpu_busy_percent` | sysfs | - | `test -r "${QWEN_GPU_DEVICE_DIRECTORY:-/sys/class/drm/card1/device}/gpu_busy_percent"` | remote/monitor-qwen-runtime.sh:97, remote/monitor-qwen-runtime.sh:164 |
| `mem_info_vram_used` | sysfs | - | `test -r "${QWEN_GPU_DEVICE_DIRECTORY:-/sys/class/drm/card1/device}/mem_info_vram_used"` | remote/monitor-qwen-runtime.sh:166, remote/monitor-qwen-runtime.sh:172 |
| `vulkan-graphics-service-probe` | path | - | `test -x "${QWEN_VULKAN_LATENCY_PROBE:-$(remote/qwen-home.sh print qwen_home)/../build/vulkan-graphics-service-probe}"` | remote/qwen-webui-session.sh:526, remote/qwen-webui-session.sh:545 |
| `dmesg` | command | - | `dmesg --color=never >/dev/null 2>&1` | remote/watch-qwen-kernel-hazards.sh:83 |
| `flock` | command | - | `command -v flock >/dev/null` | remote/activate-deployment-bundle.sh:69 |
| `python3` | command | - | `command -v python3 >/dev/null` | remote/qwen-webui-session.sh:318, remote/open-verified-lock-descriptor.py:78 |
| `sha256sum` | command | - | `command -v sha256sum >/dev/null` | remote/qwen-router-exec-guard.sh:65 |
| `awk` | command | - | `command -v awk >/dev/null` | remote/qwen-capacity-policy.sh:45 |
| `sed` | command | - | `command -v sed >/dev/null` | remote/qwen-webui-control.sh:76 |
| `taskset` | command | - | `command -v taskset >/dev/null` | remote/qwen-webui-session.sh:556 |
| `ionice` | command | - | `command -v ionice >/dev/null` | remote/qwen-webui-session.sh:556 |
| `mem_info_gtt_used` | sysfs | - | `test -r "${QWEN_GPU_DEVICE_DIRECTORY:-/sys/class/drm/card1/device}/mem_info_gtt_used"` | remote/monitor-qwen-runtime.sh:94, remote/monitor-qwen-runtime.sh:165 |
| `/dev/dri/renderD128` | path | - | `test -w /dev/dri/renderD128` | remote/permissions-doctor.sh:9 |
| `deployment-current` | path | - | `test -x "${QWEN_LLAMA_SERVER:-${QWEN_DEPLOYMENT_ROOT:-$HOME/qwen-deployments}/deployment-current/llama-server}"` | remote/resolve-active-deployment.sh:32, remote/resolve-active-deployment.sh:33 |
| `rsync` | command (both) | - | `command -v rsync >/dev/null` | remote/sync-runtime-tree.sh:85 |
| `ssh` | command (workstation) | - | `command -v ssh >/dev/null` | remote/sync-runtime-tree.sh:105 |
| `git` | command (workstation) | - | `command -v git >/dev/null` | remote/sync-runtime-tree.sh:43 |

The DRM device index is a per-machine fact rather than a constant. Every reader
takes `/sys/class/drm/card1/device` as its default and accepts
`QWEN_GPU_DEVICE_DIRECTORY` or `QWEN_DRM_DEVICE` in its place, so a machine
whose amdgpu enumerates elsewhere sets the variable and the checks follow it.

Three rows in this table name something a minimal image drops. `mv -T` at
`remote/build-deployment-bundle.sh:206` and
`remote/activate-deployment-bundle.sh:158` is a GNU coreutils extension and it
is what makes bundle assembly and activation one atomic rename, so a busybox
`mv` breaks the transition rather than degrading it. `hostname` at
`remote/qwen-launch.sh:387` produces the reachable addresses the launcher
prints. `getconf` at `remote/monitor-qwen-runtime.sh:98` reads the clock tick
the monitor divides `/proc` counters by.

The pidfd row reports `not-run`. `remote/signal-process-group.py` signals a
process group through `pidfd_open` and `PIDFD_SIGNAL_PROCESS_GROUP`, and the
kernel either carries that call or refuses it; the script's own `--check`
subcommand at `remote/signal-process-group.py:156` is the observation, and it
runs on the appliance rather than inside this checker because a failed probe
there is a kernel fact about that machine.

`openssl` is optional because `remote/qwen-webui-session.sh:150` mints an API
key only under `QWEN_REQUIRE_API_KEY=1`. The default serves without one, since
a key on a trusted local network stands between a reader and the page rather
than between an attacker and the model.

## llama-build

Host: laptop. `remote/build-llama-vulkan.sh` builds with the distribution
toolchain and refuses a source tree at any commit other than
`f280b26983ad0fdb705a0d9ebf0503e76f2899b0`. The build wants a required-command
loop of five entries and the SPIR-V C++ headers under one of three names, and
`verify-llama-patch-series.sh` requires the scheduling tools unguarded where
the build script guards them with `|| true`.

| Requirement | Kind | Pin | Check | Established by |
| --- | --- | --- | --- | --- |
| `cmake` | command | - | `command -v cmake >/dev/null` | remote/build-llama-vulkan.sh:32 |
| `ninja` | command | - | `command -v ninja >/dev/null` | remote/build-llama-vulkan.sh:32 |
| `glslc` | command | - | `command -v glslc >/dev/null` | remote/build-llama-vulkan.sh:32 |
| `cc` | command | - | `command -v cc >/dev/null` | remote/build-llama-vulkan.sh:32 |
| `c++` | command | - | `command -v c++ >/dev/null` | remote/build-llama-vulkan.sh:32, remote/test-vulkan-submit-limit.sh:31 |
| `spirv.hpp` | path | - | `test -r /usr/include/spirv/unified1/spirv.hpp \|\| test -r /usr/include/spirv-headers/spirv.hpp \|\| test -r /usr/include/spirv.hpp` | remote/build-llama-vulkan.sh:46 |
| `git` | command | - | `command -v git >/dev/null` | remote/build-llama-vulkan.sh:25, remote/verify-llama-patch-series.sh:17 |
| llama.cpp checkout | path | `f280b26983ad0fdb705a0d9ebf0503e76f2899b0` | `test -d "${QWEN_LLAMA_SOURCE:-$(remote/qwen-home.sh print qwen_home_llama_source)}/.git"` | remote/build-llama-vulkan.sh:17, remote/build-llama-vulkan.sh:20 |
| `renice` | command | - | `command -v renice >/dev/null` | remote/verify-llama-patch-series.sh:9 |
| `ionice` | command | - | `command -v ionice >/dev/null` | remote/verify-llama-patch-series.sh:11 |
| `taskset` | command | - | `command -v taskset >/dev/null` | remote/verify-llama-patch-series.sh:10 |
| `ldd` | command | - | `command -v ldd >/dev/null` | remote/hash-load-closure.sh:39 |
| `ccache` | optional-command | - | `command -v ccache >/dev/null` | remote/build-llama-preset.sh:67 |

The patch series travels with the scripts. `verify-llama-patch-series.sh` and
`build-llama-trace.sh` read `../patches` from their own directory, so a sync
that copies `remote/` alone leaves a stale series that fails the replay digest
before any compilation starts. The only Vulkan CMake options this tree passes
are `-DGGML_VULKAN=ON` and, for the census arm alone,
`-DGGML_VULKAN_PIPELINE_CENSUS=ON` at `remote/build-llama-preset.sh:120`.

## container-build

Host: workstation. `remote/build-llama-on-workstation.sh` runs a container that
supplies the glibc 2.39 the appliance links against and rsyncs plain ELF
executables over. The runtime defaults to podman and `QWEN_CONTAINER=docker`
selects the other; the image is pulled on demand, so its local presence is a
convenience rather than a requirement. Everything in the apt list installs
inside the container and reaches neither host.

| Requirement | Kind | Pin | Check | Established by |
| --- | --- | --- | --- | --- |
| `podman` | command | - | `command -v "${QWEN_CONTAINER:-podman}" >/dev/null` | remote/build-llama-on-workstation.sh:21, remote/build-llama-on-workstation.sh:37 |
| `QWEN_CONTAINER` | optional-env | - | `[ -n "${QWEN_CONTAINER:-}" ]` | remote/build-llama-on-workstation.sh:21 |
| `docker.io/library/ubuntu:24.04` | optional-path | 24.04 | `"${QWEN_CONTAINER:-podman}" image inspect "${QWEN_BUILD_IMAGE:-docker.io/library/ubuntu:24.04}" >/dev/null 2>&1` | remote/build-llama-on-workstation.sh:32, remote/build-llama-on-workstation.sh:90 |
| `git` | command | - | `command -v git >/dev/null` | remote/build-llama-on-workstation.sh:35 |
| `rsync` | command | - | `command -v rsync >/dev/null` | remote/build-llama-on-workstation.sh:125 |
| `ssh` | command | - | `command -v ssh >/dev/null` | remote/build-llama-on-workstation.sh:125 |

The image's own apt line at `remote/build-llama-on-workstation.sh:94` installs
`build-essential cmake ninja-build git libvulkan-dev glslc spirv-headers
libcurl4-openssl-dev`. That list is the reference for what a from-scratch
appliance install needs beside the distribution's Vulkan driver, which is why
it is recorded here rather than as host rows.

## ui-build

Host: workstation. `remote/build-llama-ui.sh` pulls the SvelteKit sources out
of the pinned checkout over ssh, runs `npm ci` and `npm run build`, and copies
`dist/` back. The appliance acquires no Node toolchain: llama-server serves the
static directory through `--path`.

| Requirement | Kind | Pin | Check | Established by |
| --- | --- | --- | --- | --- |
| `node` | command | - | `command -v node >/dev/null` | remote/build-llama-ui.sh:27 |
| `npm` | command | - | `command -v npm >/dev/null` | remote/build-llama-ui.sh:27, remote/build-llama-ui.sh:39 |
| `rsync` | command | - | `command -v rsync >/dev/null` | remote/build-llama-ui.sh:27 |
| `ssh` | command | - | `command -v ssh >/dev/null` | remote/build-llama-ui.sh:34 |

`npm ci` reads the checkout's own lockfile, so the roughly one thousand
packages are pinned by llama.cpp at the expected commit rather than by this
tree. The repository fallback page `webui/index.html` is one committed file and
builds nothing.

## measurement

Host: laptop. The harnesses drive `llama-bench` and `llama-cli` from the build
directory, sample the DPM steps out of sysfs, and compile a Vulkan latency
probe of their own.

| Requirement | Kind | Pin | Check | Established by |
| --- | --- | --- | --- | --- |
| `llama-bench` | path | - | `test -x "${QWEN_LLAMA_BENCH:-$(remote/qwen-home.sh print qwen_home_llama_bench)}"` | remote/run-placement-sweep.sh:12, remote/run-placement-sweep.sh:23 |
| `llama-cli` | path | - | `test -x "${QWEN_LLAMA_CLI:-$(remote/qwen-home.sh print qwen_home_llama_cli)}"` | remote/run-representation-arm.sh:33 |
| `cc` | command | - | `command -v cc >/dev/null` | remote/build-vulkan-graphics-service-probe.sh:14 |
| `/usr/include/vulkan/vulkan.h` | path | - | `test -r /usr/include/vulkan/vulkan.h` | remote/build-vulkan-graphics-service-probe.sh:18 |
| `pp_dpm_sclk` | sysfs | - | `test -r "${QWEN_DRM_DEVICE:-/sys/class/drm/card1/device}/pp_dpm_sclk"` | remote/sample-gpu-clocks.sh:41, remote/sample-gpu-clocks.sh:64 |
| `pp_dpm_mclk` | sysfs | - | `test -r "${QWEN_DRM_DEVICE:-/sys/class/drm/card1/device}/pp_dpm_mclk"` | remote/sample-gpu-clocks.sh:62, remote/measure-dpm-force.sh:126 |
| `power_dpm_force_performance_level` | sysfs | - | `test -r "${QWEN_DRM_DEVICE:-/sys/class/drm/card1/device}/power_dpm_force_performance_level"` | remote/measure-dpm-force.sh:33, remote/amdgpu-capacity-audit.sh:52 |
| amdgpu hwmon | sysfs | - | `for h in "${QWEN_HWMON_ROOT:-/sys/class/hwmon}"/hwmon*; do [ "$(cat "$h/name" 2>/dev/null)" = amdgpu ] && exit 0; done; exit 1` | remote/sample-gpu-clocks.sh:42, remote/sample-gpu-clocks.sh:52 |
| `/etc/sudoers.d/90-qwen-agent` | manual | - | `sudo -n true` | remote/measure-dpm-force.sh:56, remote/measure-dpm-force.sh:136 |
| `renice` | command | - | `command -v renice >/dev/null` | remote/measure-dpm-force.sh:89 |
| `ionice` | command | - | `command -v ionice >/dev/null` | remote/measure-dpm-force.sh:35 |
| `taskset` | command | - | `command -v taskset >/dev/null` | remote/run-guarded-webui-benchmark.sh:22 |
| `nice` | command | - | `command -v nice >/dev/null` | remote/measure-bench-repeatability.sh:248 |
| `timeout` | command | - | `command -v timeout >/dev/null` | remote/run-rocm-vulkan-matrix.sh:99 |

The sudo row reports `not-run` because a passing `sudo -n true` proves a live
60-minute timestamp rather than the rule that grants it, and
`/etc/sudoers.d/90-qwen-agent` is mode 0440 root-owned and unreadable by the
serving user. `remote/measure-dpm-force.sh:56` performs exactly that check
itself and refuses its arm when it fails, so a human runs `sudo -v` once on the
appliance and the 60-minute `timestamp_type=global` window covers the SSH
sessions that follow. That variable is what
`remote/measure-dpm-force.sh:136` writes to
`power_dpm_force_performance_level` and what
`remote/measure-dpm-force.sh:71` restores.

The hwmon selection reads the `name` file rather than the index:
`remote/sample-gpu-clocks.sh:52` walks `hwmon*` and takes the first whose name
reads `amdgpu`, so the check reproduces that rule rather than probing
`temp1_input` on whichever node sorts first.

## quality-suite

Host: both. `run-quality-suite.py` posts the 75 graded rows at an explicit
depth and `run-quality-roster.sh` runs it against every servable registry row.
Every import is standard library; the fixture generator draws each PNG from a
declaration in its own source and `--check` compares pixels rather than file
bytes, because deflate is not reproducible across hosts while inflate is fully
specified.

| Requirement | Kind | Pin | Check | Established by |
| --- | --- | --- | --- | --- |
| `python3` | command | - | `command -v python3 >/dev/null` | remote/run-quality-suite.py:1 |
| `zlib` | python-module | - | `python3 -c 'import zlib'` | remote/generate-quality-images.py:32 |
| `curl` | command (laptop) | - | `command -v curl >/dev/null` | remote/run-quality-roster.sh:84 |
| `remote/quality-images` | path | - | `test -d remote/quality-images` | remote/generate-quality-images.py:32, remote/quality-suite.tsv:1 |

A tool row of the suite executes nothing. The appliance serves without
`--tools`, so the request body's `tools` field asks the model to emit a
`tool_calls` object and the grader reads that object, which measures selection
with the read-only boundary intact.

## web-lane

Host: laptop, with the browser and the YAML reader on both. The approval broker
and the MCP child are standard-library Python; the only third-party import in
either lane is PyYAML, which `remote/test-searxng-config.sh:23` names as its
one optional dependency. SearXNG runs as its own service account out of a
virtual environment, started directly as `python -m searx.webapp` with
`SEARXNG_SETTINGS_PATH` in the launch command
(`remote/searxng-control.sh:35`); `remote/install-searxng.sh:8` refuses the
upstream installer's Valkey and uwsgi stages, so neither a cache server nor an
application server belongs to this lane.

| Requirement | Kind | Pin | Check | Established by |
| --- | --- | --- | --- | --- |
| `python3` | command | - | `command -v python3 >/dev/null` | remote/web-mcp/server.py:1, remote/web-mcp/authorize-broker.py:1 |
| `chromium` | command (both) | - | `command -v "${QWEN_CHROMIUM:-chromium}" >/dev/null` | remote/web-mcp/drive-fallback-page.py:313, remote/repository-quality-gates.sh:26 |
| `QWEN_WEB_TOKEN_KEY_FILE` | env | - | `test -f "${QWEN_WEB_TOKEN_KEY_FILE:-/nonexistent}"` | remote/qwen-web-launch.sh:253, remote/qwen-web-launch.sh:256 |
| `QWEN_WEB_AUTHORIZER_READY` | optional-env | - | `[ -n "${QWEN_WEB_AUTHORIZER_READY:-}" ]` | remote/qwen-web-launch.sh:166 |
| `QWEN_WEB_EXA_KEY_FILE` | optional-env | - | `test -f "${QWEN_WEB_EXA_KEY_FILE:-/nonexistent}"` | remote/web-mcp/server.py:3253 |
| searx-pyenv python | path | - | `test -x "${QWEN_SEARXNG_PYTHON:-/usr/local/searxng/searx-pyenv/bin/python}"` | remote/searxng-control.sh:23 |
| `SEARXNG_SETTINGS_PATH` target | path | - | `test -e "${QWEN_SEARXNG_SETTINGS_PATH:-/etc/searxng/settings.yml}"` | remote/searxng-control.sh:24, remote/searxng-control.sh:35 |
| searxng service user | manual | - | `sudo -n -u "${QWEN_SEARXNG_SERVICE_USER:-searxng}" true` | remote/searxng-control.sh:22, remote/install-searxng.sh:68 |
| `openssl` | command | - | `command -v openssl >/dev/null` | remote/install-searxng.sh:162 |
| `git` | command | - | `command -v git >/dev/null` | remote/install-searxng.sh:82 |
| `yaml` | python-module (both) | - | `python3 -c 'import yaml'` | remote/test-searxng-config.sh:23 |
| `ss` | command | - | `command -v ss >/dev/null` | remote/admit-web-router-fake.sh:451 |
| yacy install | optional-path | - | `test -d "${QWEN_YACY_INSTALL_DIRECTORY:-$HOME/yacy}"` | remote/yacy-control.sh:1, remote/test-search-control.sh:25 |

`TMPDIR` reaches no part of this lane. The variable appears in this tree only
as the `${TMPDIR:-/tmp}` fallback that seven scripts pass to `mktemp`, and
neither `searxng-control.sh` nor `install-searxng.sh` names it, so the SearXNG
service inherits whatever its own launch environment carries.

The install root is an argument rather than a constant.
`remote/install-searxng.sh` takes `INSTALL_ROOT` positionally, and
`/usr/local/searxng` is where the appliance's install landed rather than a
value the script would restore. The two fixed defaults are the settings path
and the virtual environment's interpreter, both at
`remote/searxng-control.sh:23-24`.

The service-account row reports `not-run`: proving that the `searxng` user can
start the application needs a privileged switch this checker declines to make.
A human confirms it with `getent passwd searxng` and one
`remote/searxng-control.sh status`.

YaCy is present and unreferenced by the runtime chain.
`remote/install-yacy.sh` and `remote/yacy-control.sh` are invoked by
`remote/test-search-control.sh` alone; `remote/searxng-settings.yml` defines a
`yacy` engine under the `qwen-yacy` category and `remote/web-profiles.tsv`
names that category on its `web-sovereign` row, which reaches the SearXNG
instance rather than a script in this tree. Starting the peer stays a human
action, and the row is optional for that reason.

## image-lane

Host: laptop. `remote/build-stable-diffusion-vulkan.sh` builds `sd-cli` from a
pinned stable-diffusion.cpp revision with a pinned vendored ggml revision, and
its required-command loop names seven entries including `vulkaninfo`, because
the build reads the device report rather than assuming it. The service, the
protocol module, the MCP child, and the reviewer are standard-library Python.

| Requirement | Kind | Pin | Check | Established by |
| --- | --- | --- | --- | --- |
| `cmake` | command | - | `command -v cmake >/dev/null` | remote/build-stable-diffusion-vulkan.sh:62 |
| `ninja` | command | - | `command -v ninja >/dev/null` | remote/build-stable-diffusion-vulkan.sh:62 |
| `glslc` | command | - | `command -v glslc >/dev/null` | remote/build-stable-diffusion-vulkan.sh:62 |
| `vulkaninfo` | command | - | `command -v vulkaninfo >/dev/null` | remote/build-stable-diffusion-vulkan.sh:62 |
| stable-diffusion.cpp checkout | path | `de298c225bed97c3f9026b73cd7b71e7879bd41b` | `test -d "${QWEN_IMAGE_SOURCE:-$(remote/qwen-home.sh print qwen_home_image_source)}/.git"` | remote/build-stable-diffusion-vulkan.sh:22, remote/build-stable-diffusion-vulkan.sh:23 |
| `sd-cli` | path | - | `test -x "${QWEN_IMAGE_RUNTIME:-$(remote/qwen-home.sh print qwen_home_image_runtime)}"` | remote/run-image-standalone.sh:57 |
| `python3` | command | - | `command -v python3 >/dev/null` | remote/image-service.py:1, remote/image-mcp/server.py:1 |
| `QWEN_IMAGE_PROFILES_JSON` | env | - | `test -r "${QWEN_IMAGE_PROFILES_JSON:-/nonexistent}"` | remote/qwen-image-launch.sh:270, remote/qwen-image-launch.sh:272 |
| lease state directory | path | - | `test -d "${QWEN_WEBUI_STATE_DIRECTORY:-$HOME/qwen-webui-state}"` | remote/image-service.py:101, remote/image-service.py:656 |

The vendored ggml revision is pinned separately at
`remote/build-stable-diffusion-vulkan.sh:23` as
`8e800cef2948046cc47f9db6090491c6128ca42c`, so a submodule that moved fails the
build ahead of the compiler. The runtime root's own `state/vulkan-workload.lock` is the
lease both the image service and a patched llama-server write, which is why the
state directory rather than the lock file itself is the installation
requirement: the service creates the lock and the directory is what must
already exist.

## model-fetch

Host: both. Each download script pins a Hugging Face revision, a byte count,
and a SHA-256 and verifies an existing file in place, so a fetch needs a
transfer tool and a digest tool and nothing else. The derive scripts turn the
publishers' BF16 artifacts into F16 with the appliance's own `llama-quantize`.

| Requirement | Kind | Pin | Check | Established by |
| --- | --- | --- | --- | --- |
| `curl` | command | - | `command -v curl >/dev/null` | remote/download-qwen35-4b-q4km.sh:55, remote/fetch-candidate-artifact.sh:60 |
| `sha256sum` | command | - | `command -v sha256sum >/dev/null` | remote/download-qwen35-4b-q4km.sh:27, remote/fetch-candidate-artifact.sh:51 |
| `llama-quantize` | path (laptop) | - | `test -x "${QWEN_LLAMA_QUANTIZE:-$(remote/qwen-home.sh print qwen_home_llama_quantize)}"` | remote/derive-f16-artifact.sh:37, remote/derive-f16-artifact.sh:46 |
| `GGUF_PY_PATH` | optional-env (workstation) | - | `test -d "${GGUF_PY_PATH:-/nonexistent}"` | remote/test-gguf-tensor-census.py:37, remote/derive-f16-artifact.sh:25 |
| `struct` | python-module | - | `python3 -c 'import struct'` | remote/gguf-tensor-census.py:21 |
| `hashlib` | python-module | - | `python3 -c 'import hashlib'` | remote/admit-candidate-static.py:23, remote/gguf-tensor-census.py:18 |

`remote/admit-candidate-static.py` runs on the workstation because it reads a
GGUF metadata block over an HTTP range request against a pinned revision, which
needs the network and would spend the appliance's two cores badly.
`GGUF_PY_PATH` is optional because the census parser reads the file itself and
only `remote/test-gguf-tensor-census.py` needs the upstream `gguf-py` package
to cross-check it.

## hip-rocm

Host: laptop. `remote/build-llama-dual.sh` puts Vulkan and HIP in one binary so
`llama-bench --device` selects the backend and two rows differ by the backend
rather than by the build. The build requires TheRock rather than the
distribution: Ubuntu Noble ships HIP 5.7.31921 where ggml's HIP CMakeLists
requires 6.1, TheRock's headers collide with `/usr/include/hip` when the
distribution packages are also installed, and its LLVM selects GCC 14's
libstdc++.

| Requirement | Kind | Pin | Check | Established by |
| --- | --- | --- | --- | --- |
| TheRock `clang++` | path | `10.1.0a20260825` | `test -x "${ROCM_PATH:-$HOME/.venvs/rocm-gfx900/lib/python3.12/site-packages/_rocm_sdk_devel}/lib/llvm/bin/clang++"` | remote/build-llama-dual.sh:37, evidence/therock-sdk-manifest.tsv:2 |
| `ROCM_PATH` | optional-env | - | `[ -n "${ROCM_PATH:-}" ]` | remote/build-llama-dual.sh:37, remote/run-rocm-vulkan-matrix.sh:37 |
| gcc 14 libstdc++ | path | - | `test -d /usr/lib/gcc/x86_64-linux-gnu/14` | remote/build-llama-dual.sh:114 |
| `cmake` | command | - | `command -v cmake >/dev/null` | remote/build-llama-dual.sh:137 |
| `ninja` | command | - | `command -v ninja >/dev/null` | remote/build-llama-dual.sh:137 |

`HSA_ENABLE_SDMA=0` belongs to every HIP invocation rather than to the install.
It selects behavior in a working stack, so it carries no ledger row; the reason
it is mandatory anyway is that `llama_model_loader::load_all_data` parks in
`hipEventSynchronize` without it, and `evidence/rocm-h0-operational-failure.md`
records a run that held that wait state for 51 minutes where the same binary
completes in 19 seconds. The distribution ROCm headers must be absent rather
than present, which the ledger's presence-shaped kinds cannot state;
`remote/build-llama-dual.sh:108` states it in the build.

## repository-gate

Host: both. `remote/repository-quality-gates.sh:18` names eleven commands, line
26 names a browser through `QWEN_CHROMIUM`, and the cells beyond them run
`find`, `awk`, and the tests' own tools. The gate is clone-local by design:
hardware, model files, and the pinned llama.cpp source stay separate
integration surfaces, so every fixture it needs lives in this repository.

| Requirement | Kind | Pin | Check | Established by |
| --- | --- | --- | --- | --- |
| `bash` | command | - | `command -v bash >/dev/null` | remote/repository-quality-gates.sh:18 |
| `node` | command | - | `command -v node >/dev/null` | remote/repository-quality-gates.sh:18, remote/repository-quality-gates.sh:105 |
| `shellcheck` | command | - | `command -v shellcheck >/dev/null` | remote/repository-quality-gates.sh:18, remote/repository-quality-gates.sh:43 |
| `ruff` | command | - | `command -v ruff >/dev/null` | remote/repository-quality-gates.sh:18, remote/repository-quality-gates.sh:44 |
| `mypy` | command | - | `command -v mypy >/dev/null` | remote/repository-quality-gates.sh:18, remote/repository-quality-gates.sh:63 |
| `python3` | command | - | `command -v python3 >/dev/null` | remote/repository-quality-gates.sh:18 |
| `curl` | command | - | `command -v curl >/dev/null` | remote/repository-quality-gates.sh:18 |
| `flock` | command | - | `command -v flock >/dev/null` | remote/repository-quality-gates.sh:18 |
| `git` | command | - | `command -v git >/dev/null` | remote/repository-quality-gates.sh:18 |
| `ps` | command | - | `command -v ps >/dev/null` | remote/repository-quality-gates.sh:18 |
| `sha256sum` | command | - | `command -v sha256sum >/dev/null` | remote/repository-quality-gates.sh:18 |
| `chromium` | command | - | `command -v "${QWEN_CHROMIUM:-chromium}" >/dev/null` | remote/repository-quality-gates.sh:26, remote/repository-quality-gates.sh:99 |
| `QWEN_CHROMIUM` | optional-env | - | `[ -n "${QWEN_CHROMIUM:-}" ]` | remote/repository-quality-gates.sh:26 |
| `$HOME/.qwen-gate-venv` | optional-path | - | `test -x "$HOME/.qwen-gate-venv/bin/mypy"` | remote/repository-quality-gates.sh:44, remote/repository-quality-gates.sh:63 |
| `find` | command | - | `command -v find >/dev/null` | remote/repository-quality-gates.sh:33 |
| `awk` | command | - | `command -v awk >/dev/null` | remote/check-ledger-evidence.sh:41 |

The gate venv is one way to satisfy the `ruff` and `mypy` rows rather than a
name the gate reads. `remote/repository-quality-gates.sh:18` resolves both
through `PATH`, so the appliance puts `~/.qwen-gate-venv/bin` on `PATH` while
the workstation installs them per user; either arrangement passes the same
check, which is why the row is `optional-path`.

## Observed state, 2026-09-03

Read-only probes on both machines. The appliance is written as `qwen-laptop`;
the probes ran over SSH against its own name. Every entry is `command -v`,
`--version`, `dpkg -l`, `ls`, or `vulkaninfo --summary` output, and no probe
launched a server or loaded a model.

| Item | qwen-laptop | Workstation |
| --- | --- | --- |
| Distribution | Linux Mint 22.2 | CachyOS |
| Kernel | 7.0.0-29-generic | 7.2.2-1-cachyos |
| `python3` | 3.12.3 | 3.14.7 |
| `bash` | 5.2.21 | 5.3.15 |
| `node` | v18.19.1 (nodejs 18.19.1+dfsg-6ubuntu5) | v22.23.2 |
| `npm` | 9.2.0 | 12.0.2 |
| `shellcheck` | 0.9.0-1 | present |
| `ruff` | absent on `PATH`; 0.14.11 in `~/.qwen-gate-venv` | 0.14.11 |
| `mypy` | absent on `PATH`; 2.3.1 in `~/.qwen-gate-venv` | 1.19.1 |
| `~/.qwen-gate-venv` | present, carries `mypy` and `ruff` | absent |
| `chromium` | 151.0.7922.137 | 151.0.7922.173 |
| `cmake` | 3.28.3 | 4.4.3 |
| `ninja` | 1.11.1 | 1.13.2 |
| `c++` | GCC 13.3.0 (Ubuntu 13.3.0-6ubuntu2~24.04.1) | GCC 16.2.1 |
| `glslc` | shaderc 2023.8-1build1 | 2026.3 |
| `glslangValidator` | 11:15.1.0 (glslang-tools 15.1.0) | 11:16.4.0 |
| `vulkaninfo` | vulkan-tools 1.3.275.0 | present |
| `libvulkan-dev` | 1.3.275.0-1build1 | present |
| `spirv-headers` | 1.6.1+1.4.309.0-1 | present |
| `mesa-vulkan-drivers` | 26.2.1+git2608201115 | present |
| Vulkan device | `AMD Radeon Graphics (RADV RAVEN2)`, driver `radv`, API 1.4.354 | not probed |
| `docker` | 29.7.2 | 29.7.2 |
| `podman` | absent | present |
| `hipcc` | 1.1.1.60404-129~24.04 (distribution, not TheRock) | absent |
| `tmux` | 3.4 | 3.7c |
| `jq` | 1.7.1 | 1.8.2 |
| `curl` | 8.5.0 | 8.21.0 |
| `flock` | util-linux 2.39.3 | util-linux 2.42.2 |
| `rsync` | 3.2.7 | 3.5.0 |
| `git` | 2.43.0 | 2.55.0 |
| `openssl`, `pgrep`, `ss`, `lsof`, `taskset`, `chrt`, `nice`, `xxd`, `ldd` | present | present |
| `numactl` | absent | present |
| `clang` | absent | present |
| PyYAML | 6.0.1 | present |
| `dmesg` unprivileged | permitted, `kernel.dmesg_restrict = 0` | not probed |
| `sudo -n true` | not cached at probe time | not probed |
| `/etc/sudoers.d/90-qwen-agent` | present, mode 0440 root:root, 496 bytes | absent |
| `/sys/class/drm` | one card, `card1`; `pp_dpm_sclk`, `pp_dpm_mclk`, `pp_dpm_fclk`, `power_dpm_force_performance_level`, `mem_info_*` present | not probed |
| amdgpu hwmon | `/sys/class/hwmon/hwmon6`, name `amdgpu` | not probed |
| `/dev/dri` | `card1`, `renderD128` | not probed |
| `/usr/local/searxng` | `run`, `searxng-src`, `searx-pyenv` | absent |
| SearXNG interpreter | `/usr/local/searxng/searx-pyenv/bin/python` (3.12) | absent |
| `/etc/searxng/settings.yml` | present, mode 0640 `searxng:searxng` | absent |
| `searxng` service user | uid 997, home `/usr/local/searxng` | absent |
| `llama-server`, `llama-bench`, `sd-cli` on `PATH` | absent; both live under their build and deployment directories | absent |

`remote/check-install-requirements.sh workstation` accepted this workstation
with 35 present, 4 optional-absent, 86 skipped. The laptop arm ran on the
workstation to exercise its code path and rejected with 82 present and 22
absent, which is the expected shape there: the absences are the appliance's
device nodes, its DRM and hwmon sysfs entries, the RADV ICD file, and the
built `llama-bench`, `llama-cli`, `llama-quantize`, `sd-cli`, and
`vulkan-graphics-service-probe`. The laptop arm against the appliance is `not
run`, because it needs this branch in the appliance's own Git checkout and
this audit leaves that transfer to the operator.

Two probe results contradict what a reader would assume. The gate venv lives on
the appliance rather than on the workstation, which is where `ruff` and `mypy`
are absent from the appliance's `PATH` and present inside it; the appliance is
therefore the machine that runs the gate as written. And the distribution
`hipcc` is installed on the appliance at 1.1.1.60404, which is the collision
`remote/build-llama-dual.sh:108` refuses -- the dual build needs TheRock's tree
and the distribution's `/usr/include/hip` absent, so that package is what a HIP
arm removes first.
