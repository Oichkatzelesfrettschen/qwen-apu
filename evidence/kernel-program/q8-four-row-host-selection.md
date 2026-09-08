# Q8 four-row host selection

The candidate `llama-vulkan-q8-four-row-select.patch` selects four rows for the Q8_0 floating-input mat-vec path on AMD GCN. One `q8_rows` value reaches both the pipeline workgroup denominator and specialization constant 1. Other quantization families retain their existing selection. All affected Q8 shapes remain affected consumers; non-Q8 paths are controls.

The patch applies after the production series alone and after the released lease bundle's six Q4_K candidate members. The shader source remains unchanged. The static rows-2/rows-4 receipt in `../raven2-vulkan-kernel-census/q8-num-rows-20260907T1405Z/` remains a source to compare against the candidate build's actual module; unchanged shader text alone does not establish compiler or module identity.

`python3 remote/test-q8-four-row-select.py` compiles the host expressions extracted from the patch with fatal compiler warnings. The fixture checks vendor/architecture selection, column specialization, and agreement between row count and dispatch denominator. The output-head geometry predicts 124160 control workgroups and 62080 candidate workgroups for 248320 rows. The fixture is a host-expression replay, not an executed Vulkan pipeline or served-model measurement.

A candidate build, actual module and dispatch observation, applicable census calibration, local envelope and whole-graph timing, and numerical comparison remain pending. The served comparison must bind the released Q4_K candidate series plus exactly this Q8 delta; the two baseline anchors are separate prerequisites and supply neither instrument calibration nor a promotion interval. The release binary and deployment remain unchanged.
