# One device window, five arms: the result ledger

One line per arm, each naming what passed, what failed, and what did not run,
with the record that carries it. A failure and an unrun check are different
claims and both survive here.

| arm | result | record |
| --- | --- | --- |
| Q8_0 row count, static | Passed. One SPIR-V module at NUM_ROWS 2 and 4 holds 40 VGPRs with zero spilled VGPRs and SGPRs, LDS 512, and code size 8576 rising to 14776, so the four-row path costs no register pressure. | `raven2-vulkan-kernel-census/q8-num-rows-20260907T1405Z/` |
| Q8_0 kernel-delta timing | Not run. No served candidate binary selects the four-row path: `patches/` holds no Q8_0 row-count member and the runtime root holds no candidate `llama-server`, so `run-served-binary-ab.sh` has no candidate to place against the control. | the same record |
| Prefill ladder | Partial. The 2B distill at 512, 4096, and 16384 measures prefill 50.83 to 36.23 tok/s and time to first token 10.10 s to 452.27 s. One arm refused on a 114.99 ms sampler gap and its quadruple reads incomplete. | `prefill-ladder/20260907T1410Z/` |
| Prefill ladder, threads | Unresolved at every rung. The registry row's two threads against one place their mean ratio at 0.9954, 1.0010, and 0.9724 with every interval spanning unity. | the same record |
| Prefill ladder, unmeasured | Not run: the 32768 rung, which clamps to 32719 and costs about 22 minutes per arm, and the 0.8B and 4B classes. Device-window budget. | the same record |
| Live web, `web-lookup` | Passed, 25 of 25 required checks including the served page turn: `qwen35-08b` proposed `web_search_exa`, the dialog opened, one grant was signed, and the tool result reached the transcript. | `web-live/20260907T1545Z/` |
| Live web, `web-reader` | Failed on the served page turn. `qwen38-2b-distill` was handed both tool schemas, proposed no call, and answered as though it had searched, naming a parameter that does not exist. Its curl replay passed every mechanism check. | the same record |
| Web `execution_policy` | Unchanged for both rows. `remote/web-profiles.tsv` still reads `ui-mediated` on `web-lookup` and `web-reader`; the operator edit is one line and this window made none. | the same record |
| Image router admission | Mechanisms passed, verdict refused on one check. The generation, digest match, provenance, every refusal, the lease release, and the teardown accept; the served page turn failed on both attempts because the language profile proposed no tool call and answered in prose. `image-appliance/served-turn-admission/` retains the run where that turn passed, and its language profile named the 4B distill. | `image-appliance/router-admission-20260907T1725Z/` |
| Image, unmeasured | Not run: the paired-review admission, and three-run generation wall times for `sd15+lcm` and `sd-turbo`. Device-window budget. The one `sdxs-512` generation this admission performed took 14 s, which is a single observation rather than a three-run record. | the same record |
| Vulkan workload lease | Promoted to the production stage and serving. The served admission passes both halves on the device, and the router child arms, acquires, and releases the lease around a served turn. | `vulkan-workload-lease/production-promotion-20260907T1650Z/` |
| Lease epoch | `lease-q4k-6b262d93-r1` is operationally admitted and serving; repository integration is pending. `main-2c1fa9de-r1` stands as the verified recovery bundle. A production-only bundle verified, promoted, and then refused to launch over the Q4_K formulation a candidate member compiles, which the record retains. | the same record |

Two arms failed the same way on two lanes: a checkpoint holding a low
`raw_tool_selection` grade is offered a tool schema, proposes nothing, and
answers in the register of a model that had used the tool. The mechanism halves
of both lanes passed in the same runs, so what those two failures measure is the
checkpoint a profile names rather than the lane.
