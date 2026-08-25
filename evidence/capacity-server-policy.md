# Capacity Server Policy Evidence

## Claim and falsifiers

The capacity launcher supplies one immutable server policy before model load.
The claim fails if a caller can add or override a server argument, the process
escapes CPU 0, its CPU or I/O priority exceeds the desktop-safe values, the
server listens beyond localhost, more than one slot or thread is configured,
automatic fitting changes the requested context, a tensor can fall back to the
CPU, a context above 24,576 tokens starts, or speculative decoding becomes
active.

| Subclaim | Authority | Falsifier | Validation | Artifact |
|---|---|---|---|---|
| One slot and one thread are explicit | llama.cpp option parser and fixed argument sequence | A generated invocation omits or changes any of the three values | `remote/test-qwen-capacity-policy.sh` | Captured fake-server arguments |
| The desktop retains scheduling priority | `/proc/self/status`, `ps`, and `ionice` | Affinity differs from CPU 0, nice differs from 19, or I/O class differs from idle | `remote/test-qwen-capacity-policy.sh` | Captured fake-server environment |
| The API remains local | llama.cpp `--host` option and fixed argument sequence | Host differs from `127.0.0.1` | `remote/test-qwen-capacity-policy.sh` | Captured fake-server arguments |
| Operational context is bounded | `qwen-capacity-policy.sh` maximum context check | A value above 24,576 reaches llama.cpp | 24,576 positive and 24,577 negative boundary tests | Captured exit status and diagnostic |
| Capacity caches remain bounded | llama.cpp option parser and fixed argument sequence | Checkpoints or RAM cache differ from zero, or context shift is enabled | `remote/test-qwen-capacity-policy.sh` | Captured fake-server arguments |
| RADV is the sole model backend | strict llama.cpp patch plus RADV environment wrapper | CPU tensor placement, CPU graph execution, another ICD, or llvmpipe proceeds | Post-build strict fallback tests | `evidence/strict-vulkan-placement.md` |
| Speculative decoding stays inactive | Closed argument surface with no draft options | Any `--spec-*` option reaches the server | `remote/test-qwen-capacity-policy.sh` | Captured fake-server arguments |

## Mechanism

`run-qwen-capacity-server.sh` runs the live host and Vulkan memory preflight,
then transfers control to `qwen-capacity-policy.sh`. The policy script accepts
no free-form server arguments and rejects every `LLAMA_ARG_*` environment
override. It supplies RADV device `Vulkan0`, complete layer offload, disabled
automatic fitting, one slot, one CPU thread, Q8/Q4 KV cache, zero recurrent
checkpoints, zero prompt RAM cache, and disabled context shift. The existing
RADV wrapper then applies CPU 0 affinity, nice level 19, idle I/O scheduling,
LOW Vulkan queue priority, the RADV ICD, and strict CPU-fallback rejection.
The policy rejects context values above 24,576 before the RADV wrapper starts
llama.cpp. The benchmark client independently rejects prompt depths above
24,000 tokens so fixed decode output retains context headroom.

The first policy test falsified the original scheduler implementation because
`nice -n 19` adds 19 to an inherited nice value instead of selecting an
absolute value. An agent process at nice -4 therefore produced a child at nice
15. The RADV, memory-preflight, and build entry points now run
`renice -n 19 -p $$` before `exec`, and the policy test requires an observed
nice value of 19.

The binary gate verifies that the generated llama.cpp parser accepts every
option, `Vulkan0` names Raven2, forced CPU tensor and graph placement abort,
and the all-tensor Vulkan override completes a two-token request. The shell test
establishes construction and scheduling policy; the binary test establishes
runtime placement.

## Validation result

On 2026-08-24, local and remote warning-clean ShellCheck plus `sh -n` accepted
all launcher and test scripts. `test-qwen-capacity-policy.sh` returned
`qwen_capacity_policy=accepted`, and `test-radv-low-priority-env.sh` returned
`radv_environment=accepted`.

The 24K boundary regression accepts 24,576 and rejects 24,577. A direct 32K
launch attempt returns status 2 with `context size exceeds operational maximum`
before any llama.cpp process starts.

A remote end-to-end dry launch used an empty model fixture, a 4096-token
context, a 1 MiB synthetic Vulkan working set, and fake server port 18080. The
live preflight selected `AMD Radeon Graphics (RADV RAVEN2)`, reported
16,611,995,648 available Vulkan bytes, preserved a 4 GiB desktop reserve, and
accepted both memory gates. The fake server then observed CPU 0, nice 19, idle
I/O, LOW Vulkan priority, strict CPU-fallback rejection, and the exact 42 fixed
argument tokens, including `--no-ui`, allocation-summary verbosity 4, and
`--override-tensor '.*=Vulkan0'`. No model was opened and no network listener
was created.
