# Q8_0 mat-vec register pressure across the row count

`remote/raven2-shader-lab/q8-mat-vec-receipt.sh` compiles one SPIR-V module and
creates a live RADV RAVEN2 pipeline under two values of specialization constant
1, `NUM_ROWS`. The served Q8_0 decode geometry is `NUM_ROWS=2`; the candidate
arm the 0.8B attribution proposes is 4, which halves the dispatched workgroup
count over a Q8_0 weight tensor by doubling the rows one invocation reduces.
`--num-rows` reaches ACO through pipeline specialization rather than through the
glslc frontend, so both arms share one module digest and the receipt's own
`spirv_sha256` is what proves it.

## Falsifiers, stated before the numbers

- The registered P5 band in `../decode-decomposition.md` admits 40 to 64 VGPRs
  with four or more waves per SIMD, and names 84 VGPRs as the count above which
  occupancy rather than issue becomes the first target. A `NUM_ROWS=4` arm
  measuring above 64 VGPRs, or any spill, moves the row count out of the band
  and refutes it as a free amortization.
- A `NUM_ROWS=4` arm whose VALU count fails to rise near-proportionally reports
  that the row loop did not unroll, so the workgroup halving buys no arithmetic
  amortization.
- Two arms reporting different `spirv_sha256` report a compiler-frontend
  difference rather than a specialization difference, and the pair is void.

## Result

Both arms create a pipeline on `AMD Radeon Graphics (RADV RAVEN2)`, Mesa
26.2.1, from one module (`spirv_sha256 8b5ddf19...`, 22972 bytes), so the pair
is a specialization pair.

| field | NUM_ROWS=2 | NUM_ROWS=4 | ratio |
| --- | ---: | ---: | ---: |
| vgprs | 40 | 40 | 1.00 |
| sgprs | 48 | 48 | 1.00 |
| spilled vgprs / sgprs | 0 / 0 | 0 / 0 | -- |
| lds | 512 | 512 | 1.00 |
| scratch | 0 | 0 | -- |
| code_size | 8576 | 14776 | 1.72 |
| instruction_lines | 1637 | 2747 | 1.68 |
| valu | 1042 | 1962 | 1.88 |
| v_mac_f32 | 223 | 445 | 2.00 |
| vmem | 87 | 142 | 1.63 |
| longest_valu_chain | 14 | 14 | 1.00 |
| basic blocks | 100 | 115 | 1.15 |

Register pressure holds flat at 40 VGPRs across the row count, at the lower
edge of the registered band and 44 counts below the 84 the band names as the
occupancy threshold. `v_mac_f32` doubles exactly and VALU rises 1.88x, so the
row loop unrolls and the second row's arithmetic is real work rather than
overhead. `waves_per_simd` reads `-` because the RADV statistics path this
receipt reads reports no such field; at 40 VGPRs and the wave64 allocation
granularity of 4 the SIMD's 256-register file admits 6 waves, which is derived
arithmetic over the receipt's `vgprs` rather than an observation, and it clears
the band's four-wave requirement.

No falsifier is met. The Q8_0 mat-vec at `NUM_ROWS=4` costs no register
pressure, no spill, and no LDS on this part, so the workgroup halving is
admissible on the static receipt and its rate remains unmeasured.

## The kernel-delta bracket: not run

The registered bracket over `token_embd.weight`, 124160 workgroups against
62080, requires a served binary whose Q8_0 dispatch selects `NUM_ROWS=4`.
`patches/` holds no Q8_0 row-count member -- `llama-vulkan-q4k-row-select.patch`
is the Q4_K family's own row selector -- and the runtime root holds no candidate
`llama-server` beside the production tree, so `remote/run-served-binary-ab.sh`
has no candidate to place against the control. The figures 124160 and 62080
appear nowhere under `evidence/`, so the bracket is a prediction stated in the
campaign rather than a registered record. The arm is `not run` for the absence
of a candidate build, and the receipts above are the static half that would
justify writing one.

## Retained files

`spv/` holds the compiled module and its manifest. `rows-2/` and `rows-4/` each
hold the pipeline receipt, the RADV shader statistics, the disassembled ISA, the
final NIR, the SPIR-V disassembly, the basic-block depth table, and the
specialization record naming the layer the constant was applied at. Paths inside
the receipts name the run's own temporary directory on the appliance.
