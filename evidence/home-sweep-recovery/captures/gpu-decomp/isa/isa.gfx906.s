	.text
	.amdgcn_target "amdgcn-amd-amdhsa--gfx906"
	.amdhsa_code_object_version 5
	.protected	fp32_fma                ; -- Begin function fp32_fma
	.globl	fp32_fma
	.p2align	8
	.type	fp32_fma,@function
fp32_fma:                               ; @fp32_fma
; %bb.0:
	s_add_u32 flat_scratch_lo, s10, s15
	s_addc_u32 flat_scratch_hi, s11, 0
	s_load_dwordx4 s[36:39], s[6:7], 0x0
	s_load_dwordx2 s[34:35], s[6:7], 0x10
	s_add_u32 s0, s0, s15
	s_addc_u32 s1, s1, 0
	s_mov_b64 s[10:11], s[8:9]
	s_add_u32 s8, s6, 24
	v_lshlrev_b32_e32 v2, 20, v2
	v_lshlrev_b32_e32 v1, 10, v1
	s_addc_u32 s9, s7, 0
	v_or3_b32 v31, v0, v1, v2
	v_mov_b32_e32 v0, 0
	s_mov_b32 s32, 0
	s_getpc_b64 s[6:7]
	s_add_u32 s6, s6, _Z13get_global_idj@rel32@lo+4
	s_addc_u32 s7, s7, _Z13get_global_idj@rel32@hi+12
	v_mov_b32_e32 v40, 0
	s_swappc_b64 s[30:31], s[6:7]
	v_lshlrev_b32_e32 v1, 6, v0
	v_ashrrev_i32_e32 v2, 31, v1
	v_lshlrev_b64 v[3:4], 2, v[1:2]
	v_mov_b32_e32 v2, s35
	v_add_co_u32_e32 v1, vcc, s34, v3
	v_addc_co_u32_e32 v2, vcc, v2, v4, vcc
	v_mov_b32_e32 v5, s39
	v_add_co_u32_e32 v3, vcc, s38, v3
	v_addc_co_u32_e32 v4, vcc, v5, v4, vcc
	s_mov_b64 s[6:7], 0
.LBB0_1:                                ; =>This Inner Loop Header: Depth=1
	v_mov_b32_e32 v5, s7
	v_add_co_u32_e64 v19, s[4:5], s6, v3
	v_add_co_u32_e32 v17, vcc, s6, v1
	v_addc_co_u32_e64 v20, s[4:5], v4, v5, s[4:5]
	v_addc_co_u32_e32 v18, vcc, v2, v5, vcc
	global_load_dwordx4 v[5:8], v[19:20], off
	global_load_dwordx4 v[9:12], v[17:18], off
	global_load_dwordx4 v[13:16], v[19:20], off offset:16
	s_add_u32 s6, s6, 32
	s_addc_u32 s7, s7, 0
	s_cmpk_eq_i32 s6, 0x100
	s_waitcnt vmcnt(1)
	v_fmac_f32_e32 v40, v5, v9
	v_fmac_f32_e32 v40, v6, v10
	v_fmac_f32_e32 v40, v7, v11
	v_fmac_f32_e32 v40, v8, v12
	global_load_dwordx4 v[5:8], v[17:18], off offset:16
	s_waitcnt vmcnt(0)
	v_fmac_f32_e32 v40, v13, v5
	v_fmac_f32_e32 v40, v14, v6
	v_fmac_f32_e32 v40, v15, v7
	v_fmac_f32_e32 v40, v16, v8
	s_cbranch_scc0 .LBB0_1
; %bb.2:
	v_mov_b32_e32 v1, 0
	v_mov_b32_e32 v2, v0
	v_ashrrev_i64 v[0:1], 30, v[1:2]
	v_mov_b32_e32 v2, s37
	v_add_co_u32_e32 v0, vcc, s36, v0
	v_addc_co_u32_e32 v1, vcc, v2, v1, vcc
	global_store_dword v[0:1], v40, off
	s_endpgm
	.section	.rodata,"a",@progbits
	.p2align	6, 0x0
	.amdhsa_kernel fp32_fma
		.amdhsa_group_segment_fixed_size 0
		.amdhsa_private_segment_fixed_size 0
		.amdhsa_kernarg_size 280
		.amdhsa_user_sgpr_count 12
		.amdhsa_user_sgpr_private_segment_buffer 1
		.amdhsa_user_sgpr_dispatch_ptr 1
		.amdhsa_user_sgpr_queue_ptr 0
		.amdhsa_user_sgpr_kernarg_segment_ptr 1
		.amdhsa_user_sgpr_dispatch_id 1
		.amdhsa_user_sgpr_flat_scratch_init 1
		.amdhsa_user_sgpr_private_segment_size 0
		.amdhsa_uses_dynamic_stack 1
		.amdhsa_system_sgpr_private_segment_wavefront_offset 1
		.amdhsa_system_sgpr_workgroup_id_x 1
		.amdhsa_system_sgpr_workgroup_id_y 1
		.amdhsa_system_sgpr_workgroup_id_z 1
		.amdhsa_system_sgpr_workgroup_info 0
		.amdhsa_system_vgpr_workitem_id 2
		.amdhsa_next_free_vgpr 41
		.amdhsa_next_free_sgpr 40
		.amdhsa_reserve_vcc 1
		.amdhsa_reserve_flat_scratch 1
		.amdhsa_reserve_xnack_mask 1
		.amdhsa_float_round_mode_32 0
		.amdhsa_float_round_mode_16_64 0
		.amdhsa_float_denorm_mode_32 3
		.amdhsa_float_denorm_mode_16_64 3
		.amdhsa_dx10_clamp 1
		.amdhsa_ieee_mode 1
		.amdhsa_fp16_overflow 0
		.amdhsa_exception_fp_ieee_invalid_op 0
		.amdhsa_exception_fp_denorm_src 0
		.amdhsa_exception_fp_ieee_div_zero 0
		.amdhsa_exception_fp_ieee_overflow 0
		.amdhsa_exception_fp_ieee_underflow 0
		.amdhsa_exception_fp_ieee_inexact 0
		.amdhsa_exception_int_div_zero 0
	.end_amdhsa_kernel
	.text
.Lfunc_end0:
	.size	fp32_fma, .Lfunc_end0-fp32_fma
                                        ; -- End function
	.section	.AMDGPU.csdata,"",@progbits
; Kernel info:
; codeLenInByte = 296
; NumSgprs: 46
; NumVgprs: 41
; ScratchSize: 0
; MemoryBound: 0
; FloatMode: 240
; IeeeMode: 1
; LDSByteSize: 0 bytes/workgroup (compile time only)
; SGPRBlocks: 5
; VGPRBlocks: 10
; NumSGPRsForWavesPerEU: 46
; NumVGPRsForWavesPerEU: 41
; Occupancy: 5
; WaveLimiterHint : 0
; COMPUTE_PGM_RSRC2:SCRATCH_EN: 1
; COMPUTE_PGM_RSRC2:USER_SGPR: 12
; COMPUTE_PGM_RSRC2:TRAP_HANDLER: 0
; COMPUTE_PGM_RSRC2:TGID_X_EN: 1
; COMPUTE_PGM_RSRC2:TGID_Y_EN: 1
; COMPUTE_PGM_RSRC2:TGID_Z_EN: 1
; COMPUTE_PGM_RSRC2:TIDIG_COMP_CNT: 2
	.text
	.protected	fp16_fma                ; -- Begin function fp16_fma
	.globl	fp16_fma
	.p2align	8
	.type	fp16_fma,@function
fp16_fma:                               ; @fp16_fma
; %bb.0:
	s_add_u32 flat_scratch_lo, s10, s15
	s_addc_u32 flat_scratch_hi, s11, 0
	s_load_dwordx4 s[36:39], s[6:7], 0x0
	s_load_dwordx2 s[34:35], s[6:7], 0x10
	s_add_u32 s0, s0, s15
	s_addc_u32 s1, s1, 0
	s_mov_b64 s[10:11], s[8:9]
	s_add_u32 s8, s6, 24
	v_lshlrev_b32_e32 v2, 20, v2
	v_lshlrev_b32_e32 v1, 10, v1
	s_addc_u32 s9, s7, 0
	v_or3_b32 v31, v0, v1, v2
	v_mov_b32_e32 v0, 0
	s_mov_b32 s32, 0
	s_getpc_b64 s[6:7]
	s_add_u32 s6, s6, _Z13get_global_idj@rel32@lo+4
	s_addc_u32 s7, s7, _Z13get_global_idj@rel32@hi+12
	v_mov_b32_e32 v40, 0
	s_swappc_b64 s[30:31], s[6:7]
	v_lshlrev_b32_e32 v1, 6, v0
	v_ashrrev_i32_e32 v2, 31, v1
	v_lshlrev_b64 v[3:4], 1, v[1:2]
	v_mov_b32_e32 v2, s35
	v_add_co_u32_e32 v1, vcc, s34, v3
	v_addc_co_u32_e32 v2, vcc, v2, v4, vcc
	v_mov_b32_e32 v5, s39
	v_add_co_u32_e32 v3, vcc, s38, v3
	v_addc_co_u32_e32 v4, vcc, v5, v4, vcc
	s_mov_b64 s[6:7], 0
.LBB1_1:                                ; =>This Inner Loop Header: Depth=1
	v_mov_b32_e32 v5, s7
	v_add_co_u32_e64 v15, s[4:5], s6, v3
	v_add_co_u32_e32 v13, vcc, s6, v1
	v_addc_co_u32_e64 v16, s[4:5], v4, v5, s[4:5]
	v_addc_co_u32_e32 v14, vcc, v2, v5, vcc
	global_load_dwordx4 v[5:8], v[15:16], off
	global_load_dwordx4 v[9:12], v[13:14], off
	s_add_u32 s6, s6, 16
	s_addc_u32 s7, s7, 0
	s_cmpk_eq_i32 s6, 0x80
	s_waitcnt vmcnt(1)
	v_lshrrev_b32_e32 v13, 16, v5
	s_waitcnt vmcnt(0)
	v_lshrrev_b32_e32 v17, 16, v9
	v_fma_f16 v5, v5, v9, v40
	v_fma_f16 v5, v13, v17, v5
	v_lshrrev_b32_e32 v14, 16, v6
	v_lshrrev_b32_e32 v18, 16, v10
	v_fma_f16 v5, v6, v10, v5
	v_fma_f16 v5, v14, v18, v5
	v_lshrrev_b32_e32 v15, 16, v7
	v_lshrrev_b32_e32 v19, 16, v11
	v_fma_f16 v5, v7, v11, v5
	v_fma_f16 v5, v15, v19, v5
	v_lshrrev_b32_e32 v16, 16, v8
	v_lshrrev_b32_e32 v9, 16, v12
	v_fma_f16 v5, v8, v12, v5
	v_fma_f16 v40, v16, v9, v5
	s_cbranch_scc0 .LBB1_1
; %bb.2:
	v_mov_b32_e32 v1, 0
	v_mov_b32_e32 v2, v0
	v_ashrrev_i64 v[0:1], 31, v[1:2]
	v_mov_b32_e32 v2, s37
	v_add_co_u32_e32 v0, vcc, s36, v0
	v_addc_co_u32_e32 v1, vcc, v2, v1, vcc
	global_store_short v[0:1], v40, off
	s_endpgm
	.section	.rodata,"a",@progbits
	.p2align	6, 0x0
	.amdhsa_kernel fp16_fma
		.amdhsa_group_segment_fixed_size 0
		.amdhsa_private_segment_fixed_size 0
		.amdhsa_kernarg_size 280
		.amdhsa_user_sgpr_count 12
		.amdhsa_user_sgpr_private_segment_buffer 1
		.amdhsa_user_sgpr_dispatch_ptr 1
		.amdhsa_user_sgpr_queue_ptr 0
		.amdhsa_user_sgpr_kernarg_segment_ptr 1
		.amdhsa_user_sgpr_dispatch_id 1
		.amdhsa_user_sgpr_flat_scratch_init 1
		.amdhsa_user_sgpr_private_segment_size 0
		.amdhsa_uses_dynamic_stack 1
		.amdhsa_system_sgpr_private_segment_wavefront_offset 1
		.amdhsa_system_sgpr_workgroup_id_x 1
		.amdhsa_system_sgpr_workgroup_id_y 1
		.amdhsa_system_sgpr_workgroup_id_z 1
		.amdhsa_system_sgpr_workgroup_info 0
		.amdhsa_system_vgpr_workitem_id 2
		.amdhsa_next_free_vgpr 41
		.amdhsa_next_free_sgpr 40
		.amdhsa_reserve_vcc 1
		.amdhsa_reserve_flat_scratch 1
		.amdhsa_reserve_xnack_mask 1
		.amdhsa_float_round_mode_32 0
		.amdhsa_float_round_mode_16_64 0
		.amdhsa_float_denorm_mode_32 3
		.amdhsa_float_denorm_mode_16_64 3
		.amdhsa_dx10_clamp 1
		.amdhsa_ieee_mode 1
		.amdhsa_fp16_overflow 0
		.amdhsa_exception_fp_ieee_invalid_op 0
		.amdhsa_exception_fp_denorm_src 0
		.amdhsa_exception_fp_ieee_div_zero 0
		.amdhsa_exception_fp_ieee_overflow 0
		.amdhsa_exception_fp_ieee_underflow 0
		.amdhsa_exception_fp_ieee_inexact 0
		.amdhsa_exception_int_div_zero 0
	.end_amdhsa_kernel
	.text
.Lfunc_end1:
	.size	fp16_fma, .Lfunc_end1-fp16_fma
                                        ; -- End function
	.section	.AMDGPU.csdata,"",@progbits
; Kernel info:
; codeLenInByte = 344
; NumSgprs: 46
; NumVgprs: 41
; ScratchSize: 0
; MemoryBound: 0
; FloatMode: 240
; IeeeMode: 1
; LDSByteSize: 0 bytes/workgroup (compile time only)
; SGPRBlocks: 5
; VGPRBlocks: 10
; NumSGPRsForWavesPerEU: 46
; NumVGPRsForWavesPerEU: 41
; Occupancy: 5
; WaveLimiterHint : 0
; COMPUTE_PGM_RSRC2:SCRATCH_EN: 1
; COMPUTE_PGM_RSRC2:USER_SGPR: 12
; COMPUTE_PGM_RSRC2:TRAP_HANDLER: 0
; COMPUTE_PGM_RSRC2:TGID_X_EN: 1
; COMPUTE_PGM_RSRC2:TGID_Y_EN: 1
; COMPUTE_PGM_RSRC2:TGID_Z_EN: 1
; COMPUTE_PGM_RSRC2:TIDIG_COMP_CNT: 2
	.text
	.protected	fp16x2_fma              ; -- Begin function fp16x2_fma
	.globl	fp16x2_fma
	.p2align	8
	.type	fp16x2_fma,@function
fp16x2_fma:                             ; @fp16x2_fma
; %bb.0:
	s_add_u32 flat_scratch_lo, s10, s15
	s_addc_u32 flat_scratch_hi, s11, 0
	s_load_dwordx4 s[36:39], s[6:7], 0x0
	s_load_dwordx2 s[34:35], s[6:7], 0x10
	s_add_u32 s0, s0, s15
	s_addc_u32 s1, s1, 0
	s_mov_b64 s[10:11], s[8:9]
	s_add_u32 s8, s6, 24
	v_lshlrev_b32_e32 v2, 20, v2
	v_lshlrev_b32_e32 v1, 10, v1
	s_addc_u32 s9, s7, 0
	v_or3_b32 v31, v0, v1, v2
	v_mov_b32_e32 v0, 0
	s_mov_b32 s32, 0
	s_getpc_b64 s[6:7]
	s_add_u32 s6, s6, _Z13get_global_idj@rel32@lo+4
	s_addc_u32 s7, s7, _Z13get_global_idj@rel32@hi+12
	v_mov_b32_e32 v40, 0
	s_swappc_b64 s[30:31], s[6:7]
	v_lshlrev_b32_e32 v1, 6, v0
	v_ashrrev_i32_e32 v2, 31, v1
	v_lshlrev_b64 v[3:4], 2, v[1:2]
	v_mov_b32_e32 v2, s35
	v_add_co_u32_e32 v1, vcc, s34, v3
	v_addc_co_u32_e32 v2, vcc, v2, v4, vcc
	v_mov_b32_e32 v5, s39
	v_add_co_u32_e32 v3, vcc, s38, v3
	v_addc_co_u32_e32 v4, vcc, v5, v4, vcc
	s_mov_b64 s[6:7], 0
.LBB2_1:                                ; =>This Inner Loop Header: Depth=1
	v_mov_b32_e32 v5, s7
	v_add_co_u32_e32 v17, vcc, s6, v1
	v_add_co_u32_e64 v19, s[4:5], s6, v3
	v_addc_co_u32_e64 v20, s[4:5], v4, v5, s[4:5]
	v_addc_co_u32_e32 v18, vcc, v2, v5, vcc
	global_load_dwordx4 v[5:8], v[17:18], off
	global_load_dwordx4 v[9:12], v[19:20], off
	global_load_dwordx4 v[13:16], v[19:20], off offset:16
                                        ; kill: killed $vgpr19 killed $vgpr20
	s_nop 0
	global_load_dwordx4 v[17:20], v[17:18], off offset:16
	s_add_u32 s6, s6, 32
	s_addc_u32 s7, s7, 0
	s_cmpk_eq_i32 s6, 0x100
	s_waitcnt vmcnt(2)
	v_pk_fma_f16 v5, v9, v5, v40
	v_pk_fma_f16 v5, v10, v6, v5
	v_pk_fma_f16 v5, v11, v7, v5
	v_pk_fma_f16 v5, v12, v8, v5
	s_waitcnt vmcnt(0)
	v_pk_fma_f16 v5, v13, v17, v5
	v_pk_fma_f16 v5, v14, v18, v5
	v_pk_fma_f16 v5, v15, v19, v5
	v_pk_fma_f16 v40, v16, v20, v5
	s_cbranch_scc0 .LBB2_1
; %bb.2:
	v_mov_b32_e32 v1, 0
	v_mov_b32_e32 v2, v0
	v_ashrrev_i64 v[0:1], 30, v[1:2]
	v_mov_b32_e32 v2, s37
	v_add_co_u32_e32 v0, vcc, s36, v0
	v_addc_co_u32_e32 v1, vcc, v2, v1, vcc
	global_store_dword v[0:1], v40, off
	s_endpgm
	.section	.rodata,"a",@progbits
	.p2align	6, 0x0
	.amdhsa_kernel fp16x2_fma
		.amdhsa_group_segment_fixed_size 0
		.amdhsa_private_segment_fixed_size 0
		.amdhsa_kernarg_size 280
		.amdhsa_user_sgpr_count 12
		.amdhsa_user_sgpr_private_segment_buffer 1
		.amdhsa_user_sgpr_dispatch_ptr 1
		.amdhsa_user_sgpr_queue_ptr 0
		.amdhsa_user_sgpr_kernarg_segment_ptr 1
		.amdhsa_user_sgpr_dispatch_id 1
		.amdhsa_user_sgpr_flat_scratch_init 1
		.amdhsa_user_sgpr_private_segment_size 0
		.amdhsa_uses_dynamic_stack 1
		.amdhsa_system_sgpr_private_segment_wavefront_offset 1
		.amdhsa_system_sgpr_workgroup_id_x 1
		.amdhsa_system_sgpr_workgroup_id_y 1
		.amdhsa_system_sgpr_workgroup_id_z 1
		.amdhsa_system_sgpr_workgroup_info 0
		.amdhsa_system_vgpr_workitem_id 2
		.amdhsa_next_free_vgpr 41
		.amdhsa_next_free_sgpr 40
		.amdhsa_reserve_vcc 1
		.amdhsa_reserve_flat_scratch 1
		.amdhsa_reserve_xnack_mask 1
		.amdhsa_float_round_mode_32 0
		.amdhsa_float_round_mode_16_64 0
		.amdhsa_float_denorm_mode_32 3
		.amdhsa_float_denorm_mode_16_64 3
		.amdhsa_dx10_clamp 1
		.amdhsa_ieee_mode 1
		.amdhsa_fp16_overflow 0
		.amdhsa_exception_fp_ieee_invalid_op 0
		.amdhsa_exception_fp_denorm_src 0
		.amdhsa_exception_fp_ieee_div_zero 0
		.amdhsa_exception_fp_ieee_overflow 0
		.amdhsa_exception_fp_ieee_underflow 0
		.amdhsa_exception_fp_ieee_inexact 0
		.amdhsa_exception_int_div_zero 0
	.end_amdhsa_kernel
	.text
.Lfunc_end2:
	.size	fp16x2_fma, .Lfunc_end2-fp16x2_fma
                                        ; -- End function
	.section	.AMDGPU.csdata,"",@progbits
; Kernel info:
; codeLenInByte = 332
; NumSgprs: 46
; NumVgprs: 41
; ScratchSize: 0
; MemoryBound: 0
; FloatMode: 240
; IeeeMode: 1
; LDSByteSize: 0 bytes/workgroup (compile time only)
; SGPRBlocks: 5
; VGPRBlocks: 10
; NumSGPRsForWavesPerEU: 46
; NumVGPRsForWavesPerEU: 41
; Occupancy: 5
; WaveLimiterHint : 0
; COMPUTE_PGM_RSRC2:SCRATCH_EN: 1
; COMPUTE_PGM_RSRC2:USER_SGPR: 12
; COMPUTE_PGM_RSRC2:TRAP_HANDLER: 0
; COMPUTE_PGM_RSRC2:TGID_X_EN: 1
; COMPUTE_PGM_RSRC2:TGID_Y_EN: 1
; COMPUTE_PGM_RSRC2:TGID_Z_EN: 1
; COMPUTE_PGM_RSRC2:TIDIG_COMP_CNT: 2
	.text
	.protected	fp16_acc_fp32           ; -- Begin function fp16_acc_fp32
	.globl	fp16_acc_fp32
	.p2align	8
	.type	fp16_acc_fp32,@function
fp16_acc_fp32:                          ; @fp16_acc_fp32
; %bb.0:
	s_add_u32 flat_scratch_lo, s10, s15
	s_addc_u32 flat_scratch_hi, s11, 0
	s_load_dwordx4 s[36:39], s[6:7], 0x0
	s_load_dwordx2 s[34:35], s[6:7], 0x10
	s_add_u32 s0, s0, s15
	s_addc_u32 s1, s1, 0
	s_mov_b64 s[10:11], s[8:9]
	s_add_u32 s8, s6, 24
	v_lshlrev_b32_e32 v2, 20, v2
	v_lshlrev_b32_e32 v1, 10, v1
	s_addc_u32 s9, s7, 0
	v_or3_b32 v31, v0, v1, v2
	v_mov_b32_e32 v0, 0
	s_mov_b32 s32, 0
	s_getpc_b64 s[6:7]
	s_add_u32 s6, s6, _Z13get_global_idj@rel32@lo+4
	s_addc_u32 s7, s7, _Z13get_global_idj@rel32@hi+12
	v_mov_b32_e32 v40, 0
	s_swappc_b64 s[30:31], s[6:7]
	v_lshlrev_b32_e32 v1, 6, v0
	v_ashrrev_i32_e32 v2, 31, v1
	v_lshlrev_b64 v[3:4], 1, v[1:2]
	v_mov_b32_e32 v2, s35
	v_add_co_u32_e32 v1, vcc, s34, v3
	v_addc_co_u32_e32 v2, vcc, v2, v4, vcc
	v_mov_b32_e32 v5, s39
	v_add_co_u32_e32 v3, vcc, s38, v3
	v_addc_co_u32_e32 v4, vcc, v5, v4, vcc
	s_mov_b64 s[6:7], 0
.LBB3_1:                                ; =>This Inner Loop Header: Depth=1
	v_mov_b32_e32 v5, s7
	v_add_co_u32_e64 v15, s[4:5], s6, v3
	v_add_co_u32_e32 v13, vcc, s6, v1
	v_addc_co_u32_e64 v16, s[4:5], v4, v5, s[4:5]
	v_addc_co_u32_e32 v14, vcc, v2, v5, vcc
	global_load_dwordx4 v[5:8], v[15:16], off
	global_load_dwordx4 v[9:12], v[13:14], off
	s_add_u32 s6, s6, 16
	s_addc_u32 s7, s7, 0
	s_cmpk_eq_i32 s6, 0x80
	s_waitcnt vmcnt(0)
	v_fma_mix_f32 v13, v5, v9, v40 op_sel_hi:[1,1,0]
	v_fma_mix_f32 v5, v5, v9, v13 op_sel:[1,1,0] op_sel_hi:[1,1,0]
	v_fma_mix_f32 v5, v6, v10, v5 op_sel_hi:[1,1,0]
	v_fma_mix_f32 v5, v6, v10, v5 op_sel:[1,1,0] op_sel_hi:[1,1,0]
	v_fma_mix_f32 v5, v7, v11, v5 op_sel_hi:[1,1,0]
	v_fma_mix_f32 v5, v7, v11, v5 op_sel:[1,1,0] op_sel_hi:[1,1,0]
	v_fma_mix_f32 v5, v8, v12, v5 op_sel_hi:[1,1,0]
	v_fma_mix_f32 v40, v8, v12, v5 op_sel:[1,1,0] op_sel_hi:[1,1,0]
	s_cbranch_scc0 .LBB3_1
; %bb.2:
	v_mov_b32_e32 v1, 0
	v_mov_b32_e32 v2, v0
	v_ashrrev_i64 v[0:1], 30, v[1:2]
	v_mov_b32_e32 v2, s37
	v_add_co_u32_e32 v0, vcc, s36, v0
	v_addc_co_u32_e32 v1, vcc, v2, v1, vcc
	global_store_dword v[0:1], v40, off
	s_endpgm
	.section	.rodata,"a",@progbits
	.p2align	6, 0x0
	.amdhsa_kernel fp16_acc_fp32
		.amdhsa_group_segment_fixed_size 0
		.amdhsa_private_segment_fixed_size 0
		.amdhsa_kernarg_size 280
		.amdhsa_user_sgpr_count 12
		.amdhsa_user_sgpr_private_segment_buffer 1
		.amdhsa_user_sgpr_dispatch_ptr 1
		.amdhsa_user_sgpr_queue_ptr 0
		.amdhsa_user_sgpr_kernarg_segment_ptr 1
		.amdhsa_user_sgpr_dispatch_id 1
		.amdhsa_user_sgpr_flat_scratch_init 1
		.amdhsa_user_sgpr_private_segment_size 0
		.amdhsa_uses_dynamic_stack 1
		.amdhsa_system_sgpr_private_segment_wavefront_offset 1
		.amdhsa_system_sgpr_workgroup_id_x 1
		.amdhsa_system_sgpr_workgroup_id_y 1
		.amdhsa_system_sgpr_workgroup_id_z 1
		.amdhsa_system_sgpr_workgroup_info 0
		.amdhsa_system_vgpr_workitem_id 2
		.amdhsa_next_free_vgpr 41
		.amdhsa_next_free_sgpr 40
		.amdhsa_reserve_vcc 1
		.amdhsa_reserve_flat_scratch 1
		.amdhsa_reserve_xnack_mask 1
		.amdhsa_float_round_mode_32 0
		.amdhsa_float_round_mode_16_64 0
		.amdhsa_float_denorm_mode_32 3
		.amdhsa_float_denorm_mode_16_64 3
		.amdhsa_dx10_clamp 1
		.amdhsa_ieee_mode 1
		.amdhsa_fp16_overflow 0
		.amdhsa_exception_fp_ieee_invalid_op 0
		.amdhsa_exception_fp_denorm_src 0
		.amdhsa_exception_fp_ieee_div_zero 0
		.amdhsa_exception_fp_ieee_overflow 0
		.amdhsa_exception_fp_ieee_underflow 0
		.amdhsa_exception_fp_ieee_inexact 0
		.amdhsa_exception_int_div_zero 0
	.end_amdhsa_kernel
	.text
.Lfunc_end3:
	.size	fp16_acc_fp32, .Lfunc_end3-fp16_acc_fp32
                                        ; -- End function
	.section	.AMDGPU.csdata,"",@progbits
; Kernel info:
; codeLenInByte = 308
; NumSgprs: 46
; NumVgprs: 41
; ScratchSize: 0
; MemoryBound: 0
; FloatMode: 240
; IeeeMode: 1
; LDSByteSize: 0 bytes/workgroup (compile time only)
; SGPRBlocks: 5
; VGPRBlocks: 10
; NumSGPRsForWavesPerEU: 46
; NumVGPRsForWavesPerEU: 41
; Occupancy: 5
; WaveLimiterHint : 0
; COMPUTE_PGM_RSRC2:SCRATCH_EN: 1
; COMPUTE_PGM_RSRC2:USER_SGPR: 12
; COMPUTE_PGM_RSRC2:TRAP_HANDLER: 0
; COMPUTE_PGM_RSRC2:TGID_X_EN: 1
; COMPUTE_PGM_RSRC2:TGID_Y_EN: 1
; COMPUTE_PGM_RSRC2:TGID_Z_EN: 1
; COMPUTE_PGM_RSRC2:TIDIG_COMP_CNT: 2
	.text
	.protected	int8_dot4               ; -- Begin function int8_dot4
	.globl	int8_dot4
	.p2align	8
	.type	int8_dot4,@function
int8_dot4:                              ; @int8_dot4
; %bb.0:
	s_add_u32 flat_scratch_lo, s10, s15
	s_addc_u32 flat_scratch_hi, s11, 0
	s_load_dwordx4 s[36:39], s[6:7], 0x0
	s_load_dwordx2 s[34:35], s[6:7], 0x10
	s_add_u32 s0, s0, s15
	s_addc_u32 s1, s1, 0
	s_mov_b64 s[10:11], s[8:9]
	s_add_u32 s8, s6, 24
	v_lshlrev_b32_e32 v2, 20, v2
	v_lshlrev_b32_e32 v1, 10, v1
	s_addc_u32 s9, s7, 0
	v_or3_b32 v31, v0, v1, v2
	v_mov_b32_e32 v0, 0
	s_mov_b32 s32, 0
	s_getpc_b64 s[6:7]
	s_add_u32 s6, s6, _Z13get_global_idj@rel32@lo+4
	s_addc_u32 s7, s7, _Z13get_global_idj@rel32@hi+12
	s_swappc_b64 s[30:31], s[6:7]
	v_lshlrev_b32_e32 v1, 6, v0
	v_ashrrev_i32_e32 v2, 31, v1
	v_lshlrev_b64 v[3:4], 2, v[1:2]
	v_mov_b32_e32 v2, s35
	v_add_co_u32_e32 v1, vcc, s34, v3
	v_addc_co_u32_e32 v2, vcc, v2, v4, vcc
	v_mov_b32_e32 v5, s39
	v_add_co_u32_e32 v3, vcc, s38, v3
	v_addc_co_u32_e32 v4, vcc, v5, v4, vcc
	s_mov_b64 s[4:5], 0
	v_mov_b32_e32 v5, 0
.LBB4_1:                                ; =>This Inner Loop Header: Depth=1
	v_add_co_u32_e32 v6, vcc, s4, v3
	v_mov_b32_e32 v11, s5
	v_addc_co_u32_e32 v7, vcc, v4, v11, vcc
	v_add_co_u32_e32 v10, vcc, s4, v1
	v_addc_co_u32_e32 v11, vcc, v2, v11, vcc
	global_load_dwordx4 v[6:9], v[6:7], off
	s_add_u32 s4, s4, 16
	global_load_dwordx4 v[10:13], v[10:11], off
	s_addc_u32 s5, s5, 0
	s_cmpk_eq_i32 s4, 0x100
	s_waitcnt vmcnt(1)
	v_lshrrev_b16_e32 v14, 8, v6
	v_bfe_i32 v14, v14, 0, 8
	s_waitcnt vmcnt(0)
	v_lshrrev_b16_e32 v18, 8, v10
	v_bfe_i32 v22, v6, 0, 8
	v_bfe_i32 v18, v18, 0, 8
	v_bfe_i32 v23, v10, 0, 8
	v_mul_i32_i24_sdwa v24, sext(v10), sext(v6) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2
	v_mul_i32_i24_sdwa v6, sext(v10), sext(v6) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3
	v_lshrrev_b16_e32 v15, 8, v7
	v_lshrrev_b16_e32 v19, 8, v11
	v_mad_i32_i24 v10, v23, v22, v24
	v_mad_i32_i24 v6, v18, v14, v6
	v_add3_u32 v5, v10, v6, v5
	v_bfe_i32 v6, v15, 0, 8
	v_bfe_i32 v10, v7, 0, 8
	v_bfe_i32 v14, v19, 0, 8
	v_bfe_i32 v15, v11, 0, 8
	v_mul_i32_i24_sdwa v18, sext(v11), sext(v7) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2
	v_mul_i32_i24_sdwa v7, sext(v11), sext(v7) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3
	v_lshrrev_b16_e32 v16, 8, v8
	v_lshrrev_b16_e32 v20, 8, v12
	v_mad_i32_i24 v10, v15, v10, v18
	v_mad_i32_i24 v6, v14, v6, v7
	v_add3_u32 v5, v10, v6, v5
	v_bfe_i32 v6, v16, 0, 8
	v_bfe_i32 v7, v8, 0, 8
	v_bfe_i32 v10, v20, 0, 8
	v_bfe_i32 v11, v12, 0, 8
	v_mul_i32_i24_sdwa v14, sext(v12), sext(v8) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2
	v_mul_i32_i24_sdwa v8, sext(v12), sext(v8) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3
	v_lshrrev_b16_e32 v17, 8, v9
	v_lshrrev_b16_e32 v21, 8, v13
	v_mad_i32_i24 v7, v11, v7, v14
	v_mad_i32_i24 v6, v10, v6, v8
	v_add3_u32 v5, v7, v6, v5
	v_bfe_i32 v6, v17, 0, 8
	v_bfe_i32 v7, v9, 0, 8
	v_bfe_i32 v8, v21, 0, 8
	v_bfe_i32 v10, v13, 0, 8
	v_mul_i32_i24_sdwa v11, sext(v13), sext(v9) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2
	v_mul_i32_i24_sdwa v9, sext(v13), sext(v9) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3
	v_mad_i32_i24 v7, v10, v7, v11
	v_mad_i32_i24 v6, v8, v6, v9
	v_add3_u32 v5, v7, v6, v5
	s_cbranch_scc0 .LBB4_1
; %bb.2:
	v_mov_b32_e32 v1, 0
	v_mov_b32_e32 v2, v0
	v_ashrrev_i64 v[0:1], 30, v[1:2]
	v_mov_b32_e32 v2, s37
	v_add_co_u32_e32 v0, vcc, s36, v0
	v_addc_co_u32_e32 v1, vcc, v2, v1, vcc
	global_store_dword v[0:1], v5, off
	s_endpgm
	.section	.rodata,"a",@progbits
	.p2align	6, 0x0
	.amdhsa_kernel int8_dot4
		.amdhsa_group_segment_fixed_size 0
		.amdhsa_private_segment_fixed_size 0
		.amdhsa_kernarg_size 280
		.amdhsa_user_sgpr_count 12
		.amdhsa_user_sgpr_private_segment_buffer 1
		.amdhsa_user_sgpr_dispatch_ptr 1
		.amdhsa_user_sgpr_queue_ptr 0
		.amdhsa_user_sgpr_kernarg_segment_ptr 1
		.amdhsa_user_sgpr_dispatch_id 1
		.amdhsa_user_sgpr_flat_scratch_init 1
		.amdhsa_user_sgpr_private_segment_size 0
		.amdhsa_uses_dynamic_stack 1
		.amdhsa_system_sgpr_private_segment_wavefront_offset 1
		.amdhsa_system_sgpr_workgroup_id_x 1
		.amdhsa_system_sgpr_workgroup_id_y 1
		.amdhsa_system_sgpr_workgroup_id_z 1
		.amdhsa_system_sgpr_workgroup_info 0
		.amdhsa_system_vgpr_workitem_id 2
		.amdhsa_next_free_vgpr 32
		.amdhsa_next_free_sgpr 40
		.amdhsa_reserve_vcc 1
		.amdhsa_reserve_flat_scratch 1
		.amdhsa_reserve_xnack_mask 1
		.amdhsa_float_round_mode_32 0
		.amdhsa_float_round_mode_16_64 0
		.amdhsa_float_denorm_mode_32 3
		.amdhsa_float_denorm_mode_16_64 3
		.amdhsa_dx10_clamp 1
		.amdhsa_ieee_mode 1
		.amdhsa_fp16_overflow 0
		.amdhsa_exception_fp_ieee_invalid_op 0
		.amdhsa_exception_fp_denorm_src 0
		.amdhsa_exception_fp_ieee_div_zero 0
		.amdhsa_exception_fp_ieee_overflow 0
		.amdhsa_exception_fp_ieee_underflow 0
		.amdhsa_exception_fp_ieee_inexact 0
		.amdhsa_exception_int_div_zero 0
	.end_amdhsa_kernel
	.text
.Lfunc_end4:
	.size	int8_dot4, .Lfunc_end4-int8_dot4
                                        ; -- End function
	.section	.AMDGPU.csdata,"",@progbits
; Kernel info:
; codeLenInByte = 560
; NumSgprs: 46
; NumVgprs: 32
; ScratchSize: 0
; MemoryBound: 0
; FloatMode: 240
; IeeeMode: 1
; LDSByteSize: 0 bytes/workgroup (compile time only)
; SGPRBlocks: 5
; VGPRBlocks: 7
; NumSGPRsForWavesPerEU: 46
; NumVGPRsForWavesPerEU: 32
; Occupancy: 8
; WaveLimiterHint : 0
; COMPUTE_PGM_RSRC2:SCRATCH_EN: 1
; COMPUTE_PGM_RSRC2:USER_SGPR: 12
; COMPUTE_PGM_RSRC2:TRAP_HANDLER: 0
; COMPUTE_PGM_RSRC2:TGID_X_EN: 1
; COMPUTE_PGM_RSRC2:TGID_Y_EN: 1
; COMPUTE_PGM_RSRC2:TGID_Z_EN: 1
; COMPUTE_PGM_RSRC2:TIDIG_COMP_CNT: 2
	.text
	.protected	int16x2_mad             ; -- Begin function int16x2_mad
	.globl	int16x2_mad
	.p2align	8
	.type	int16x2_mad,@function
int16x2_mad:                            ; @int16x2_mad
; %bb.0:
	s_add_u32 flat_scratch_lo, s10, s15
	s_addc_u32 flat_scratch_hi, s11, 0
	s_load_dwordx4 s[44:47], s[6:7], 0x0
	s_load_dwordx2 s[40:41], s[6:7], 0x10
	s_add_u32 s0, s0, s15
	s_addc_u32 s1, s1, 0
	s_mov_b64 s[36:37], s[6:7]
	v_lshlrev_b32_e32 v2, 20, v2
	v_lshlrev_b32_e32 v1, 10, v1
	s_mov_b64 s[34:35], s[8:9]
	s_add_u32 s8, s36, 24
	v_or3_b32 v40, v0, v1, v2
	s_addc_u32 s9, s37, 0
	s_mov_b64 s[10:11], s[34:35]
	v_mov_b32_e32 v31, v40
	v_mov_b32_e32 v0, 0
	s_mov_b32 s32, 0
	s_mov_b32 s33, s14
	s_mov_b32 s42, s13
	s_mov_b32 s43, s12
	s_mov_b64 s[38:39], s[4:5]
	s_getpc_b64 s[6:7]
	s_add_u32 s6, s6, _Z13get_global_idj@rel32@lo+4
	s_addc_u32 s7, s7, _Z13get_global_idj@rel32@hi+12
	s_swappc_b64 s[30:31], s[6:7]
	v_mov_b32_e32 v41, v0
	v_lshlrev_b32_e32 v0, 6, v41
	v_ashrrev_i32_e32 v1, 31, v0
	v_lshlrev_b64 v[0:1], 2, v[0:1]
	v_mov_b32_e32 v2, s41
	v_add_co_u32_e32 v62, vcc, s40, v0
	v_addc_co_u32_e32 v63, vcc, v2, v1, vcc
	v_mov_b32_e32 v2, s47
	v_add_co_u32_e32 v72, vcc, s46, v0
	v_addc_co_u32_e32 v73, vcc, v2, v1, vcc
	s_mov_b64 s[46:47], 0
	v_mov_b32_e32 v60, 0
	v_mov_b32_e32 v61, 0
.LBB5_1:                                ; =>This Inner Loop Header: Depth=1
	v_mov_b32_e32 v0, s47
	v_add_co_u32_e32 v74, vcc, s46, v72
	v_addc_co_u32_e32 v75, vcc, v73, v0, vcc
	global_load_dwordx4 v[42:45], v[74:75], off
	v_add_co_u32_e32 v76, vcc, s46, v62
	v_addc_co_u32_e32 v77, vcc, v63, v0, vcc
	global_load_dwordx4 v[56:59], v[76:77], off
	s_add_u32 s40, s36, 24
	s_addc_u32 s41, s37, 0
	s_mov_b64 s[4:5], s[38:39]
	s_mov_b64 s[8:9], s[40:41]
	s_mov_b64 s[10:11], s[34:35]
	s_mov_b32 s12, s43
	s_mov_b32 s13, s42
	s_mov_b32 s14, s33
	v_mov_b32_e32 v31, v40
	s_getpc_b64 s[48:49]
	s_add_u32 s48, s48, _Z12convert_int2Dv2_s@rel32@lo+4
	s_addc_u32 s49, s49, _Z12convert_int2Dv2_s@rel32@hi+12
	s_waitcnt vmcnt(1)
	v_mov_b32_e32 v0, v42
	s_swappc_b64 s[30:31], s[48:49]
	v_mov_b32_e32 v42, v0
	s_mov_b64 s[4:5], s[38:39]
	s_mov_b64 s[8:9], s[40:41]
	s_mov_b64 s[10:11], s[34:35]
	s_mov_b32 s12, s43
	s_mov_b32 s13, s42
	s_mov_b32 s14, s33
	v_mov_b32_e32 v31, v40
	v_mov_b32_e32 v0, v56
	v_mov_b32_e32 v46, v1
	s_swappc_b64 s[30:31], s[48:49]
	v_mul_lo_u32 v47, v0, v42
	s_mov_b64 s[4:5], s[38:39]
	s_mov_b64 s[8:9], s[40:41]
	s_mov_b64 s[10:11], s[34:35]
	s_mov_b32 s12, s43
	s_mov_b32 s13, s42
	s_mov_b32 s14, s33
	v_mov_b32_e32 v31, v40
	v_mov_b32_e32 v0, v43
	v_mul_lo_u32 v46, v1, v46
	s_swappc_b64 s[30:31], s[48:49]
	v_mov_b32_e32 v42, v0
	s_mov_b64 s[4:5], s[38:39]
	s_mov_b64 s[8:9], s[40:41]
	s_mov_b64 s[10:11], s[34:35]
	s_mov_b32 s12, s43
	s_mov_b32 s13, s42
	s_mov_b32 s14, s33
	v_mov_b32_e32 v31, v40
	v_mov_b32_e32 v0, v57
	v_mov_b32_e32 v43, v1
	s_swappc_b64 s[30:31], s[48:49]
	v_mul_lo_u32 v0, v0, v42
	v_mul_lo_u32 v1, v1, v43
	s_mov_b64 s[4:5], s[38:39]
	s_mov_b64 s[8:9], s[40:41]
	v_add3_u32 v60, v47, v60, v0
	s_mov_b64 s[10:11], s[34:35]
	s_mov_b32 s12, s43
	s_mov_b32 s13, s42
	s_mov_b32 s14, s33
	v_mov_b32_e32 v31, v40
	v_mov_b32_e32 v0, v44
	v_add3_u32 v61, v46, v61, v1
	s_swappc_b64 s[30:31], s[48:49]
	v_mov_b32_e32 v42, v0
	s_mov_b64 s[4:5], s[38:39]
	s_mov_b64 s[8:9], s[40:41]
	s_mov_b64 s[10:11], s[34:35]
	s_mov_b32 s12, s43
	s_mov_b32 s13, s42
	s_mov_b32 s14, s33
	v_mov_b32_e32 v31, v40
	v_mov_b32_e32 v0, v58
	v_mov_b32_e32 v43, v1
	s_swappc_b64 s[30:31], s[48:49]
	v_mul_lo_u32 v78, v0, v42
	s_mov_b64 s[4:5], s[38:39]
	s_mov_b64 s[8:9], s[40:41]
	s_mov_b64 s[10:11], s[34:35]
	s_mov_b32 s12, s43
	s_mov_b32 s13, s42
	s_mov_b32 s14, s33
	v_mov_b32_e32 v31, v40
	v_mov_b32_e32 v0, v45
	v_mul_lo_u32 v79, v1, v43
	s_swappc_b64 s[30:31], s[48:49]
	v_mov_b32_e32 v46, v0
	s_mov_b64 s[4:5], s[38:39]
	s_mov_b64 s[8:9], s[40:41]
	s_mov_b64 s[10:11], s[34:35]
	s_mov_b32 s12, s43
	s_mov_b32 s13, s42
	s_mov_b32 s14, s33
	v_mov_b32_e32 v31, v40
	v_mov_b32_e32 v0, v59
	v_mov_b32_e32 v47, v1
	s_swappc_b64 s[30:31], s[48:49]
	global_load_dwordx4 v[42:45], v[74:75], off offset:16
	global_load_dwordx4 v[56:59], v[76:77], off offset:16
	v_mul_lo_u32 v0, v0, v46
	v_mul_lo_u32 v1, v1, v47
	s_mov_b64 s[4:5], s[38:39]
	s_mov_b64 s[8:9], s[40:41]
	v_add3_u32 v60, v78, v60, v0
	s_mov_b64 s[10:11], s[34:35]
	s_mov_b32 s12, s43
	s_mov_b32 s13, s42
	s_mov_b32 s14, s33
	v_mov_b32_e32 v31, v40
	v_add3_u32 v47, v79, v61, v1
	s_waitcnt vmcnt(1)
	v_mov_b32_e32 v0, v42
	s_swappc_b64 s[30:31], s[48:49]
	v_mov_b32_e32 v42, v0
	s_mov_b64 s[4:5], s[38:39]
	s_mov_b64 s[8:9], s[40:41]
	s_mov_b64 s[10:11], s[34:35]
	s_mov_b32 s12, s43
	s_mov_b32 s13, s42
	s_mov_b32 s14, s33
	v_mov_b32_e32 v31, v40
	v_mov_b32_e32 v0, v56
	v_mov_b32_e32 v46, v1
	s_swappc_b64 s[30:31], s[48:49]
	v_mul_lo_u32 v56, v0, v42
	s_mov_b64 s[4:5], s[38:39]
	s_mov_b64 s[8:9], s[40:41]
	s_mov_b64 s[10:11], s[34:35]
	s_mov_b32 s12, s43
	s_mov_b32 s13, s42
	s_mov_b32 s14, s33
	v_mov_b32_e32 v31, v40
	v_mov_b32_e32 v0, v43
	v_mul_lo_u32 v46, v1, v46
	s_swappc_b64 s[30:31], s[48:49]
	v_mov_b32_e32 v42, v0
	s_mov_b64 s[4:5], s[38:39]
	s_mov_b64 s[8:9], s[40:41]
	s_mov_b64 s[10:11], s[34:35]
	s_mov_b32 s12, s43
	s_mov_b32 s13, s42
	s_mov_b32 s14, s33
	v_mov_b32_e32 v31, v40
	v_mov_b32_e32 v0, v57
	v_mov_b32_e32 v43, v1
	s_swappc_b64 s[30:31], s[48:49]
	v_mul_lo_u32 v0, v0, v42
	v_mul_lo_u32 v1, v1, v43
	s_mov_b64 s[4:5], s[38:39]
	s_mov_b64 s[8:9], s[40:41]
	v_add3_u32 v56, v56, v60, v0
	s_mov_b64 s[10:11], s[34:35]
	s_mov_b32 s12, s43
	s_mov_b32 s13, s42
	s_mov_b32 s14, s33
	v_mov_b32_e32 v31, v40
	v_mov_b32_e32 v0, v44
	v_add3_u32 v46, v46, v47, v1
	s_swappc_b64 s[30:31], s[48:49]
	v_mov_b32_e32 v42, v0
	s_mov_b64 s[4:5], s[38:39]
	s_mov_b64 s[8:9], s[40:41]
	s_mov_b64 s[10:11], s[34:35]
	s_mov_b32 s12, s43
	s_mov_b32 s13, s42
	s_mov_b32 s14, s33
	v_mov_b32_e32 v31, v40
	v_mov_b32_e32 v0, v58
	v_mov_b32_e32 v43, v1
	s_swappc_b64 s[30:31], s[48:49]
	v_mul_lo_u32 v44, v0, v42
	s_mov_b64 s[4:5], s[38:39]
	s_mov_b64 s[8:9], s[40:41]
	s_mov_b64 s[10:11], s[34:35]
	s_mov_b32 s12, s43
	s_mov_b32 s13, s42
	s_mov_b32 s14, s33
	v_mov_b32_e32 v31, v40
	v_mov_b32_e32 v0, v45
	v_mul_lo_u32 v47, v1, v43
	s_swappc_b64 s[30:31], s[48:49]
	v_mov_b32_e32 v42, v0
	s_mov_b64 s[4:5], s[38:39]
	s_mov_b64 s[8:9], s[40:41]
	s_mov_b64 s[10:11], s[34:35]
	s_mov_b32 s12, s43
	s_mov_b32 s13, s42
	s_mov_b32 s14, s33
	v_mov_b32_e32 v31, v40
	v_mov_b32_e32 v0, v59
	v_mov_b32_e32 v43, v1
	s_swappc_b64 s[30:31], s[48:49]
	v_mul_lo_u32 v1, v1, v43
	v_mul_lo_u32 v0, v0, v42
	s_add_u32 s46, s46, 32
	s_addc_u32 s47, s47, 0
	v_add3_u32 v61, v47, v46, v1
	s_cmpk_eq_i32 s46, 0x100
	v_add3_u32 v60, v44, v56, v0
	s_cbranch_scc0 .LBB5_1
; %bb.2:
	v_mov_b32_e32 v0, 0
	v_mov_b32_e32 v1, v41
	v_ashrrev_i64 v[0:1], 29, v[0:1]
	v_mov_b32_e32 v2, s45
	v_add_co_u32_e32 v0, vcc, s44, v0
	v_addc_co_u32_e32 v1, vcc, v2, v1, vcc
	global_store_dwordx2 v[0:1], v[60:61], off
	s_endpgm
	.section	.rodata,"a",@progbits
	.p2align	6, 0x0
	.amdhsa_kernel int16x2_mad
		.amdhsa_group_segment_fixed_size 0
		.amdhsa_private_segment_fixed_size 0
		.amdhsa_kernarg_size 280
		.amdhsa_user_sgpr_count 12
		.amdhsa_user_sgpr_private_segment_buffer 1
		.amdhsa_user_sgpr_dispatch_ptr 1
		.amdhsa_user_sgpr_queue_ptr 0
		.amdhsa_user_sgpr_kernarg_segment_ptr 1
		.amdhsa_user_sgpr_dispatch_id 1
		.amdhsa_user_sgpr_flat_scratch_init 1
		.amdhsa_user_sgpr_private_segment_size 0
		.amdhsa_uses_dynamic_stack 1
		.amdhsa_system_sgpr_private_segment_wavefront_offset 1
		.amdhsa_system_sgpr_workgroup_id_x 1
		.amdhsa_system_sgpr_workgroup_id_y 1
		.amdhsa_system_sgpr_workgroup_id_z 1
		.amdhsa_system_sgpr_workgroup_info 0
		.amdhsa_system_vgpr_workitem_id 2
		.amdhsa_next_free_vgpr 80
		.amdhsa_next_free_sgpr 50
		.amdhsa_reserve_vcc 1
		.amdhsa_reserve_flat_scratch 1
		.amdhsa_reserve_xnack_mask 1
		.amdhsa_float_round_mode_32 0
		.amdhsa_float_round_mode_16_64 0
		.amdhsa_float_denorm_mode_32 3
		.amdhsa_float_denorm_mode_16_64 3
		.amdhsa_dx10_clamp 1
		.amdhsa_ieee_mode 1
		.amdhsa_fp16_overflow 0
		.amdhsa_exception_fp_ieee_invalid_op 0
		.amdhsa_exception_fp_denorm_src 0
		.amdhsa_exception_fp_ieee_div_zero 0
		.amdhsa_exception_fp_ieee_overflow 0
		.amdhsa_exception_fp_ieee_underflow 0
		.amdhsa_exception_fp_ieee_inexact 0
		.amdhsa_exception_int_div_zero 0
	.end_amdhsa_kernel
	.text
.Lfunc_end5:
	.size	int16x2_mad, .Lfunc_end5-int16x2_mad
                                        ; -- End function
	.section	.AMDGPU.csdata,"",@progbits
; Kernel info:
; codeLenInByte = 1152
; NumSgprs: 56
; NumVgprs: 80
; ScratchSize: 0
; MemoryBound: 0
; FloatMode: 240
; IeeeMode: 1
; LDSByteSize: 0 bytes/workgroup (compile time only)
; SGPRBlocks: 6
; VGPRBlocks: 19
; NumSGPRsForWavesPerEU: 56
; NumVGPRsForWavesPerEU: 80
; Occupancy: 3
; WaveLimiterHint : 0
; COMPUTE_PGM_RSRC2:SCRATCH_EN: 1
; COMPUTE_PGM_RSRC2:USER_SGPR: 12
; COMPUTE_PGM_RSRC2:TRAP_HANDLER: 0
; COMPUTE_PGM_RSRC2:TGID_X_EN: 1
; COMPUTE_PGM_RSRC2:TGID_Y_EN: 1
; COMPUTE_PGM_RSRC2:TGID_Z_EN: 1
; COMPUTE_PGM_RSRC2:TIDIG_COMP_CNT: 2
	.text
	.protected	fp64_fma                ; -- Begin function fp64_fma
	.globl	fp64_fma
	.p2align	8
	.type	fp64_fma,@function
fp64_fma:                               ; @fp64_fma
; %bb.0:
	s_add_u32 flat_scratch_lo, s10, s15
	s_addc_u32 flat_scratch_hi, s11, 0
	s_load_dwordx4 s[36:39], s[6:7], 0x0
	s_load_dwordx2 s[34:35], s[6:7], 0x10
	s_add_u32 s0, s0, s15
	s_addc_u32 s1, s1, 0
	s_mov_b64 s[10:11], s[8:9]
	s_add_u32 s8, s6, 24
	v_lshlrev_b32_e32 v2, 20, v2
	v_lshlrev_b32_e32 v1, 10, v1
	s_addc_u32 s9, s7, 0
	v_or3_b32 v31, v0, v1, v2
	v_mov_b32_e32 v0, 0
	s_mov_b32 s32, 0
	s_getpc_b64 s[6:7]
	s_add_u32 s6, s6, _Z13get_global_idj@rel32@lo+4
	s_addc_u32 s7, s7, _Z13get_global_idj@rel32@hi+12
	s_swappc_b64 s[30:31], s[6:7]
	v_lshlrev_b32_e32 v1, 6, v0
	v_ashrrev_i32_e32 v2, 31, v1
	v_lshlrev_b64 v[1:2], 3, v[1:2]
	v_mov_b32_e32 v4, s35
	v_add_co_u32_e32 v3, vcc, s34, v1
	v_addc_co_u32_e32 v4, vcc, v4, v2, vcc
	v_mov_b32_e32 v6, s39
	v_add_co_u32_e32 v5, vcc, s38, v1
	v_addc_co_u32_e32 v6, vcc, v6, v2, vcc
	v_mov_b32_e32 v1, 0
	v_mov_b32_e32 v2, 0
	s_mov_b64 s[6:7], 0
.LBB6_1:                                ; =>This Inner Loop Header: Depth=1
	v_mov_b32_e32 v7, s7
	v_add_co_u32_e64 v21, s[4:5], s6, v5
	v_add_co_u32_e32 v19, vcc, s6, v3
	v_addc_co_u32_e64 v22, s[4:5], v6, v7, s[4:5]
	v_addc_co_u32_e32 v20, vcc, v4, v7, vcc
	global_load_dwordx4 v[7:10], v[21:22], off
	global_load_dwordx4 v[11:14], v[19:20], off
	s_add_u32 s6, s6, 64
	s_addc_u32 s7, s7, 0
	s_cmpk_eq_i32 s6, 0x200
	s_waitcnt vmcnt(0)
	v_fma_f64 v[1:2], v[7:8], v[11:12], v[1:2]
	v_fma_f64 v[1:2], v[9:10], v[13:14], v[1:2]
	global_load_dwordx4 v[7:10], v[21:22], off offset:16
	global_load_dwordx4 v[11:14], v[19:20], off offset:16
	s_waitcnt vmcnt(0)
	v_fma_f64 v[1:2], v[7:8], v[11:12], v[1:2]
	v_fma_f64 v[1:2], v[9:10], v[13:14], v[1:2]
	global_load_dwordx4 v[7:10], v[21:22], off offset:32
	global_load_dwordx4 v[11:14], v[19:20], off offset:32
	global_load_dwordx4 v[15:18], v[21:22], off offset:48
	s_waitcnt vmcnt(1)
	v_fma_f64 v[1:2], v[7:8], v[11:12], v[1:2]
	v_fma_f64 v[1:2], v[9:10], v[13:14], v[1:2]
	global_load_dwordx4 v[7:10], v[19:20], off offset:48
	s_waitcnt vmcnt(0)
	v_fma_f64 v[1:2], v[15:16], v[7:8], v[1:2]
	v_fma_f64 v[1:2], v[17:18], v[9:10], v[1:2]
	s_cbranch_scc0 .LBB6_1
; %bb.2:
	v_mov_b32_e32 v3, 0
	v_mov_b32_e32 v4, v0
	v_ashrrev_i64 v[3:4], 29, v[3:4]
	v_mov_b32_e32 v0, s37
	v_add_co_u32_e32 v3, vcc, s36, v3
	v_addc_co_u32_e32 v4, vcc, v0, v4, vcc
	global_store_dwordx2 v[3:4], v[1:2], off
	s_endpgm
	.section	.rodata,"a",@progbits
	.p2align	6, 0x0
	.amdhsa_kernel fp64_fma
		.amdhsa_group_segment_fixed_size 0
		.amdhsa_private_segment_fixed_size 0
		.amdhsa_kernarg_size 280
		.amdhsa_user_sgpr_count 12
		.amdhsa_user_sgpr_private_segment_buffer 1
		.amdhsa_user_sgpr_dispatch_ptr 1
		.amdhsa_user_sgpr_queue_ptr 0
		.amdhsa_user_sgpr_kernarg_segment_ptr 1
		.amdhsa_user_sgpr_dispatch_id 1
		.amdhsa_user_sgpr_flat_scratch_init 1
		.amdhsa_user_sgpr_private_segment_size 0
		.amdhsa_uses_dynamic_stack 1
		.amdhsa_system_sgpr_private_segment_wavefront_offset 1
		.amdhsa_system_sgpr_workgroup_id_x 1
		.amdhsa_system_sgpr_workgroup_id_y 1
		.amdhsa_system_sgpr_workgroup_id_z 1
		.amdhsa_system_sgpr_workgroup_info 0
		.amdhsa_system_vgpr_workitem_id 2
		.amdhsa_next_free_vgpr 32
		.amdhsa_next_free_sgpr 40
		.amdhsa_reserve_vcc 1
		.amdhsa_reserve_flat_scratch 1
		.amdhsa_reserve_xnack_mask 1
		.amdhsa_float_round_mode_32 0
		.amdhsa_float_round_mode_16_64 0
		.amdhsa_float_denorm_mode_32 3
		.amdhsa_float_denorm_mode_16_64 3
		.amdhsa_dx10_clamp 1
		.amdhsa_ieee_mode 1
		.amdhsa_fp16_overflow 0
		.amdhsa_exception_fp_ieee_invalid_op 0
		.amdhsa_exception_fp_denorm_src 0
		.amdhsa_exception_fp_ieee_div_zero 0
		.amdhsa_exception_fp_ieee_overflow 0
		.amdhsa_exception_fp_ieee_underflow 0
		.amdhsa_exception_fp_ieee_inexact 0
		.amdhsa_exception_int_div_zero 0
	.end_amdhsa_kernel
	.text
.Lfunc_end6:
	.size	fp64_fma, .Lfunc_end6-fp64_fma
                                        ; -- End function
	.section	.AMDGPU.csdata,"",@progbits
; Kernel info:
; codeLenInByte = 372
; NumSgprs: 46
; NumVgprs: 32
; ScratchSize: 0
; MemoryBound: 1
; FloatMode: 240
; IeeeMode: 1
; LDSByteSize: 0 bytes/workgroup (compile time only)
; SGPRBlocks: 5
; VGPRBlocks: 7
; NumSGPRsForWavesPerEU: 46
; NumVGPRsForWavesPerEU: 32
; Occupancy: 8
; WaveLimiterHint : 0
; COMPUTE_PGM_RSRC2:SCRATCH_EN: 1
; COMPUTE_PGM_RSRC2:USER_SGPR: 12
; COMPUTE_PGM_RSRC2:TRAP_HANDLER: 0
; COMPUTE_PGM_RSRC2:TGID_X_EN: 1
; COMPUTE_PGM_RSRC2:TGID_Y_EN: 1
; COMPUTE_PGM_RSRC2:TGID_Z_EN: 1
; COMPUTE_PGM_RSRC2:TIDIG_COMP_CNT: 2
	.hidden	__oclc_ABI_version              ; @__oclc_ABI_version
	.type	__oclc_ABI_version,@object
	.section	.rodata,"a",@progbits
	.weak	__oclc_ABI_version
	.p2align	2, 0x0
__oclc_ABI_version:
	.long	500                             ; 0x1f4
	.size	__oclc_ABI_version, 4

	.hidden	_Z13get_global_idj
	.hidden	_Z12convert_int2Dv2_s
	.ident	"Ubuntu clang version 19.1.7 (1~n~ppa1)"
	.section	".note.GNU-stack","",@progbits
	.addrsig
	.amdgpu_metadata
---
amdhsa.kernels:
  - .args:
      - .address_space:  global
        .offset:         0
        .size:           8
        .type_name:      'float*'
        .value_kind:     global_buffer
      - .address_space:  global
        .is_const:       true
        .offset:         8
        .size:           8
        .type_name:      'float*'
        .value_kind:     global_buffer
      - .address_space:  global
        .is_const:       true
        .offset:         16
        .size:           8
        .type_name:      'float*'
        .value_kind:     global_buffer
      - .offset:         24
        .size:           4
        .value_kind:     hidden_block_count_x
      - .offset:         28
        .size:           4
        .value_kind:     hidden_block_count_y
      - .offset:         32
        .size:           4
        .value_kind:     hidden_block_count_z
      - .offset:         36
        .size:           2
        .value_kind:     hidden_group_size_x
      - .offset:         38
        .size:           2
        .value_kind:     hidden_group_size_y
      - .offset:         40
        .size:           2
        .value_kind:     hidden_group_size_z
      - .offset:         42
        .size:           2
        .value_kind:     hidden_remainder_x
      - .offset:         44
        .size:           2
        .value_kind:     hidden_remainder_y
      - .offset:         46
        .size:           2
        .value_kind:     hidden_remainder_z
      - .offset:         64
        .size:           8
        .value_kind:     hidden_global_offset_x
      - .offset:         72
        .size:           8
        .value_kind:     hidden_global_offset_y
      - .offset:         80
        .size:           8
        .value_kind:     hidden_global_offset_z
      - .offset:         88
        .size:           2
        .value_kind:     hidden_grid_dims
      - .offset:         104
        .size:           8
        .value_kind:     hidden_hostcall_buffer
      - .offset:         112
        .size:           8
        .value_kind:     hidden_multigrid_sync_arg
      - .offset:         120
        .size:           8
        .value_kind:     hidden_heap_v1
      - .offset:         128
        .size:           8
        .value_kind:     hidden_default_queue
      - .offset:         136
        .size:           8
        .value_kind:     hidden_completion_action
      - .offset:         224
        .size:           8
        .value_kind:     hidden_queue_ptr
    .group_segment_fixed_size: 0
    .kernarg_segment_align: 8
    .kernarg_segment_size: 280
    .language:       OpenCL C
    .language_version:
      - 2
      - 0
    .max_flat_workgroup_size: 256
    .name:           fp32_fma
    .private_segment_fixed_size: 0
    .sgpr_count:     46
    .sgpr_spill_count: 0
    .symbol:         fp32_fma.kd
    .uses_dynamic_stack: true
    .vgpr_count:     41
    .vgpr_spill_count: 0
    .wavefront_size: 64
  - .args:
      - .address_space:  global
        .offset:         0
        .size:           8
        .type_name:      'half*'
        .value_kind:     global_buffer
      - .address_space:  global
        .is_const:       true
        .offset:         8
        .size:           8
        .type_name:      'half*'
        .value_kind:     global_buffer
      - .address_space:  global
        .is_const:       true
        .offset:         16
        .size:           8
        .type_name:      'half*'
        .value_kind:     global_buffer
      - .offset:         24
        .size:           4
        .value_kind:     hidden_block_count_x
      - .offset:         28
        .size:           4
        .value_kind:     hidden_block_count_y
      - .offset:         32
        .size:           4
        .value_kind:     hidden_block_count_z
      - .offset:         36
        .size:           2
        .value_kind:     hidden_group_size_x
      - .offset:         38
        .size:           2
        .value_kind:     hidden_group_size_y
      - .offset:         40
        .size:           2
        .value_kind:     hidden_group_size_z
      - .offset:         42
        .size:           2
        .value_kind:     hidden_remainder_x
      - .offset:         44
        .size:           2
        .value_kind:     hidden_remainder_y
      - .offset:         46
        .size:           2
        .value_kind:     hidden_remainder_z
      - .offset:         64
        .size:           8
        .value_kind:     hidden_global_offset_x
      - .offset:         72
        .size:           8
        .value_kind:     hidden_global_offset_y
      - .offset:         80
        .size:           8
        .value_kind:     hidden_global_offset_z
      - .offset:         88
        .size:           2
        .value_kind:     hidden_grid_dims
      - .offset:         104
        .size:           8
        .value_kind:     hidden_hostcall_buffer
      - .offset:         112
        .size:           8
        .value_kind:     hidden_multigrid_sync_arg
      - .offset:         120
        .size:           8
        .value_kind:     hidden_heap_v1
      - .offset:         128
        .size:           8
        .value_kind:     hidden_default_queue
      - .offset:         136
        .size:           8
        .value_kind:     hidden_completion_action
      - .offset:         224
        .size:           8
        .value_kind:     hidden_queue_ptr
    .group_segment_fixed_size: 0
    .kernarg_segment_align: 8
    .kernarg_segment_size: 280
    .language:       OpenCL C
    .language_version:
      - 2
      - 0
    .max_flat_workgroup_size: 256
    .name:           fp16_fma
    .private_segment_fixed_size: 0
    .sgpr_count:     46
    .sgpr_spill_count: 0
    .symbol:         fp16_fma.kd
    .uses_dynamic_stack: true
    .vgpr_count:     41
    .vgpr_spill_count: 0
    .wavefront_size: 64
  - .args:
      - .address_space:  global
        .offset:         0
        .size:           8
        .type_name:      'half2*'
        .value_kind:     global_buffer
      - .address_space:  global
        .is_const:       true
        .offset:         8
        .size:           8
        .type_name:      'half2*'
        .value_kind:     global_buffer
      - .address_space:  global
        .is_const:       true
        .offset:         16
        .size:           8
        .type_name:      'half2*'
        .value_kind:     global_buffer
      - .offset:         24
        .size:           4
        .value_kind:     hidden_block_count_x
      - .offset:         28
        .size:           4
        .value_kind:     hidden_block_count_y
      - .offset:         32
        .size:           4
        .value_kind:     hidden_block_count_z
      - .offset:         36
        .size:           2
        .value_kind:     hidden_group_size_x
      - .offset:         38
        .size:           2
        .value_kind:     hidden_group_size_y
      - .offset:         40
        .size:           2
        .value_kind:     hidden_group_size_z
      - .offset:         42
        .size:           2
        .value_kind:     hidden_remainder_x
      - .offset:         44
        .size:           2
        .value_kind:     hidden_remainder_y
      - .offset:         46
        .size:           2
        .value_kind:     hidden_remainder_z
      - .offset:         64
        .size:           8
        .value_kind:     hidden_global_offset_x
      - .offset:         72
        .size:           8
        .value_kind:     hidden_global_offset_y
      - .offset:         80
        .size:           8
        .value_kind:     hidden_global_offset_z
      - .offset:         88
        .size:           2
        .value_kind:     hidden_grid_dims
      - .offset:         104
        .size:           8
        .value_kind:     hidden_hostcall_buffer
      - .offset:         112
        .size:           8
        .value_kind:     hidden_multigrid_sync_arg
      - .offset:         120
        .size:           8
        .value_kind:     hidden_heap_v1
      - .offset:         128
        .size:           8
        .value_kind:     hidden_default_queue
      - .offset:         136
        .size:           8
        .value_kind:     hidden_completion_action
      - .offset:         224
        .size:           8
        .value_kind:     hidden_queue_ptr
    .group_segment_fixed_size: 0
    .kernarg_segment_align: 8
    .kernarg_segment_size: 280
    .language:       OpenCL C
    .language_version:
      - 2
      - 0
    .max_flat_workgroup_size: 256
    .name:           fp16x2_fma
    .private_segment_fixed_size: 0
    .sgpr_count:     46
    .sgpr_spill_count: 0
    .symbol:         fp16x2_fma.kd
    .uses_dynamic_stack: true
    .vgpr_count:     41
    .vgpr_spill_count: 0
    .wavefront_size: 64
  - .args:
      - .address_space:  global
        .offset:         0
        .size:           8
        .type_name:      'float*'
        .value_kind:     global_buffer
      - .address_space:  global
        .is_const:       true
        .offset:         8
        .size:           8
        .type_name:      'half*'
        .value_kind:     global_buffer
      - .address_space:  global
        .is_const:       true
        .offset:         16
        .size:           8
        .type_name:      'half*'
        .value_kind:     global_buffer
      - .offset:         24
        .size:           4
        .value_kind:     hidden_block_count_x
      - .offset:         28
        .size:           4
        .value_kind:     hidden_block_count_y
      - .offset:         32
        .size:           4
        .value_kind:     hidden_block_count_z
      - .offset:         36
        .size:           2
        .value_kind:     hidden_group_size_x
      - .offset:         38
        .size:           2
        .value_kind:     hidden_group_size_y
      - .offset:         40
        .size:           2
        .value_kind:     hidden_group_size_z
      - .offset:         42
        .size:           2
        .value_kind:     hidden_remainder_x
      - .offset:         44
        .size:           2
        .value_kind:     hidden_remainder_y
      - .offset:         46
        .size:           2
        .value_kind:     hidden_remainder_z
      - .offset:         64
        .size:           8
        .value_kind:     hidden_global_offset_x
      - .offset:         72
        .size:           8
        .value_kind:     hidden_global_offset_y
      - .offset:         80
        .size:           8
        .value_kind:     hidden_global_offset_z
      - .offset:         88
        .size:           2
        .value_kind:     hidden_grid_dims
      - .offset:         104
        .size:           8
        .value_kind:     hidden_hostcall_buffer
      - .offset:         112
        .size:           8
        .value_kind:     hidden_multigrid_sync_arg
      - .offset:         120
        .size:           8
        .value_kind:     hidden_heap_v1
      - .offset:         128
        .size:           8
        .value_kind:     hidden_default_queue
      - .offset:         136
        .size:           8
        .value_kind:     hidden_completion_action
      - .offset:         224
        .size:           8
        .value_kind:     hidden_queue_ptr
    .group_segment_fixed_size: 0
    .kernarg_segment_align: 8
    .kernarg_segment_size: 280
    .language:       OpenCL C
    .language_version:
      - 2
      - 0
    .max_flat_workgroup_size: 256
    .name:           fp16_acc_fp32
    .private_segment_fixed_size: 0
    .sgpr_count:     46
    .sgpr_spill_count: 0
    .symbol:         fp16_acc_fp32.kd
    .uses_dynamic_stack: true
    .vgpr_count:     41
    .vgpr_spill_count: 0
    .wavefront_size: 64
  - .args:
      - .address_space:  global
        .offset:         0
        .size:           8
        .type_name:      'int*'
        .value_kind:     global_buffer
      - .address_space:  global
        .is_const:       true
        .offset:         8
        .size:           8
        .type_name:      'char4*'
        .value_kind:     global_buffer
      - .address_space:  global
        .is_const:       true
        .offset:         16
        .size:           8
        .type_name:      'char4*'
        .value_kind:     global_buffer
      - .offset:         24
        .size:           4
        .value_kind:     hidden_block_count_x
      - .offset:         28
        .size:           4
        .value_kind:     hidden_block_count_y
      - .offset:         32
        .size:           4
        .value_kind:     hidden_block_count_z
      - .offset:         36
        .size:           2
        .value_kind:     hidden_group_size_x
      - .offset:         38
        .size:           2
        .value_kind:     hidden_group_size_y
      - .offset:         40
        .size:           2
        .value_kind:     hidden_group_size_z
      - .offset:         42
        .size:           2
        .value_kind:     hidden_remainder_x
      - .offset:         44
        .size:           2
        .value_kind:     hidden_remainder_y
      - .offset:         46
        .size:           2
        .value_kind:     hidden_remainder_z
      - .offset:         64
        .size:           8
        .value_kind:     hidden_global_offset_x
      - .offset:         72
        .size:           8
        .value_kind:     hidden_global_offset_y
      - .offset:         80
        .size:           8
        .value_kind:     hidden_global_offset_z
      - .offset:         88
        .size:           2
        .value_kind:     hidden_grid_dims
      - .offset:         104
        .size:           8
        .value_kind:     hidden_hostcall_buffer
      - .offset:         112
        .size:           8
        .value_kind:     hidden_multigrid_sync_arg
      - .offset:         120
        .size:           8
        .value_kind:     hidden_heap_v1
      - .offset:         128
        .size:           8
        .value_kind:     hidden_default_queue
      - .offset:         136
        .size:           8
        .value_kind:     hidden_completion_action
      - .offset:         224
        .size:           8
        .value_kind:     hidden_queue_ptr
    .group_segment_fixed_size: 0
    .kernarg_segment_align: 8
    .kernarg_segment_size: 280
    .language:       OpenCL C
    .language_version:
      - 2
      - 0
    .max_flat_workgroup_size: 256
    .name:           int8_dot4
    .private_segment_fixed_size: 0
    .sgpr_count:     46
    .sgpr_spill_count: 0
    .symbol:         int8_dot4.kd
    .uses_dynamic_stack: true
    .vgpr_count:     32
    .vgpr_spill_count: 0
    .wavefront_size: 64
  - .args:
      - .address_space:  global
        .offset:         0
        .size:           8
        .type_name:      'int2*'
        .value_kind:     global_buffer
      - .address_space:  global
        .is_const:       true
        .offset:         8
        .size:           8
        .type_name:      'short2*'
        .value_kind:     global_buffer
      - .address_space:  global
        .is_const:       true
        .offset:         16
        .size:           8
        .type_name:      'short2*'
        .value_kind:     global_buffer
      - .offset:         24
        .size:           4
        .value_kind:     hidden_block_count_x
      - .offset:         28
        .size:           4
        .value_kind:     hidden_block_count_y
      - .offset:         32
        .size:           4
        .value_kind:     hidden_block_count_z
      - .offset:         36
        .size:           2
        .value_kind:     hidden_group_size_x
      - .offset:         38
        .size:           2
        .value_kind:     hidden_group_size_y
      - .offset:         40
        .size:           2
        .value_kind:     hidden_group_size_z
      - .offset:         42
        .size:           2
        .value_kind:     hidden_remainder_x
      - .offset:         44
        .size:           2
        .value_kind:     hidden_remainder_y
      - .offset:         46
        .size:           2
        .value_kind:     hidden_remainder_z
      - .offset:         64
        .size:           8
        .value_kind:     hidden_global_offset_x
      - .offset:         72
        .size:           8
        .value_kind:     hidden_global_offset_y
      - .offset:         80
        .size:           8
        .value_kind:     hidden_global_offset_z
      - .offset:         88
        .size:           2
        .value_kind:     hidden_grid_dims
      - .offset:         104
        .size:           8
        .value_kind:     hidden_hostcall_buffer
      - .offset:         112
        .size:           8
        .value_kind:     hidden_multigrid_sync_arg
      - .offset:         120
        .size:           8
        .value_kind:     hidden_heap_v1
      - .offset:         128
        .size:           8
        .value_kind:     hidden_default_queue
      - .offset:         136
        .size:           8
        .value_kind:     hidden_completion_action
      - .offset:         224
        .size:           8
        .value_kind:     hidden_queue_ptr
    .group_segment_fixed_size: 0
    .kernarg_segment_align: 8
    .kernarg_segment_size: 280
    .language:       OpenCL C
    .language_version:
      - 2
      - 0
    .max_flat_workgroup_size: 256
    .name:           int16x2_mad
    .private_segment_fixed_size: 0
    .sgpr_count:     56
    .sgpr_spill_count: 0
    .symbol:         int16x2_mad.kd
    .uses_dynamic_stack: true
    .vgpr_count:     80
    .vgpr_spill_count: 0
    .wavefront_size: 64
  - .args:
      - .address_space:  global
        .offset:         0
        .size:           8
        .type_name:      'double*'
        .value_kind:     global_buffer
      - .address_space:  global
        .is_const:       true
        .offset:         8
        .size:           8
        .type_name:      'double*'
        .value_kind:     global_buffer
      - .address_space:  global
        .is_const:       true
        .offset:         16
        .size:           8
        .type_name:      'double*'
        .value_kind:     global_buffer
      - .offset:         24
        .size:           4
        .value_kind:     hidden_block_count_x
      - .offset:         28
        .size:           4
        .value_kind:     hidden_block_count_y
      - .offset:         32
        .size:           4
        .value_kind:     hidden_block_count_z
      - .offset:         36
        .size:           2
        .value_kind:     hidden_group_size_x
      - .offset:         38
        .size:           2
        .value_kind:     hidden_group_size_y
      - .offset:         40
        .size:           2
        .value_kind:     hidden_group_size_z
      - .offset:         42
        .size:           2
        .value_kind:     hidden_remainder_x
      - .offset:         44
        .size:           2
        .value_kind:     hidden_remainder_y
      - .offset:         46
        .size:           2
        .value_kind:     hidden_remainder_z
      - .offset:         64
        .size:           8
        .value_kind:     hidden_global_offset_x
      - .offset:         72
        .size:           8
        .value_kind:     hidden_global_offset_y
      - .offset:         80
        .size:           8
        .value_kind:     hidden_global_offset_z
      - .offset:         88
        .size:           2
        .value_kind:     hidden_grid_dims
      - .offset:         104
        .size:           8
        .value_kind:     hidden_hostcall_buffer
      - .offset:         112
        .size:           8
        .value_kind:     hidden_multigrid_sync_arg
      - .offset:         120
        .size:           8
        .value_kind:     hidden_heap_v1
      - .offset:         128
        .size:           8
        .value_kind:     hidden_default_queue
      - .offset:         136
        .size:           8
        .value_kind:     hidden_completion_action
      - .offset:         224
        .size:           8
        .value_kind:     hidden_queue_ptr
    .group_segment_fixed_size: 0
    .kernarg_segment_align: 8
    .kernarg_segment_size: 280
    .language:       OpenCL C
    .language_version:
      - 2
      - 0
    .max_flat_workgroup_size: 256
    .name:           fp64_fma
    .private_segment_fixed_size: 0
    .sgpr_count:     46
    .sgpr_spill_count: 0
    .symbol:         fp64_fma.kd
    .uses_dynamic_stack: true
    .vgpr_count:     32
    .vgpr_spill_count: 0
    .wavefront_size: 64
amdhsa.target:   amdgcn-amd-amdhsa--gfx906
amdhsa.version:
  - 1
  - 2
...

	.end_amdgpu_metadata
