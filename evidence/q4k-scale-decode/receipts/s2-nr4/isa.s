BB0:
	s_load_dword s0, s[14:15], 0x0                              ; c0020007 00000000
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_mul_i32 s0, s0, s18                                       ; 92001200
	s_add_u32 s16, s16, s0                                      ; 80100010
	s_lshl_b32 s16, s16, 2                                      ; 8e108210
	s_add_u32 s1, s16, 4                                        ; 80018410
	s_cmp_ge_u32 s4, s1                                         ; bf090104
	s_cbranch_scc0 BB42                                         ; bf8402f9
BB1:
	s_add_u32 s17, s17, s9                                      ; 80110911
	s_cmp_lg_i32 s17, 0                                         ; bf018011
	s_cbranch_scc0 BB3                                          ; bf840043
BB2:
	v_cvt_f32_u32_e32 v1, s11                                   ; 7e020c0b
	v_rcp_f32_e32 v1, v1                                        ; 7e024501
	v_mul_f32_e32 v1, 0x4f7ffffe, v1                            ; 0a0202ff 4f7ffffe
	v_cvt_u32_f32_e32 v1, v1                                    ; 7e020f01
	v_readfirstlane_b32 s0, v1                                  ; 7e000501
	s_mul_i32 s1, s11, s0                                       ; 9201000b
	s_sub_i32 s1, 0, s1                                         ; 81810180
	s_mul_hi_u32 s1, s0, s1                                     ; 96010100
	v_cvt_f32_u32_e32 v2, s13                                   ; 7e040c0d
	s_add_u32 s0, s0, s1                                        ; 80000100
	v_rcp_f32_e32 v2, v2                                        ; 7e044502
	s_mul_hi_u32 s0, s17, s0                                    ; 96000011
	s_mul_i32 s4, s0, s11                                       ; 92040b00
	v_mul_f32_e32 v2, 0x4f7ffffe, v2                            ; 0a0404ff 4f7ffffe
	s_sub_i32 s4, s17, s4                                       ; 81840411
	v_cvt_u32_f32_e32 v2, v2                                    ; 7e040f02
	s_cmp_ge_u32 s4, s11                                        ; bf090b04
	v_readfirstlane_b32 s18, v2                                 ; 7e240502
	s_add_u32 s0, s0, src_scc                                   ; 8000fd00
	s_sub_i32 s14, s4, s11                                      ; 818e0b04
	s_cmp_ge_u32 s4, s11                                        ; bf090b04
	s_mul_i32 s19, s13, s18                                     ; 9213120d
	s_cselect_b32 s14, s14, s4                                  ; 850e040e
	s_cmp_ge_u32 s14, s11                                       ; bf090b0e
	s_mov_b32 s15, src_scc                                      ; be8f00fd
	s_add_u32 s0, s0, src_scc                                   ; 8000fd00
	s_sub_i32 s11, s14, s11                                     ; 818b0b0e
	s_cmp_lg_i32 s15, 0                                         ; bf01800f
	v_cvt_f32_u32_e32 v3, s12                                   ; 7e060c0c
	s_cselect_b32 s11, s11, s14                                 ; 850b0e0b
	s_sub_i32 s19, 0, s19                                       ; 81931380
	v_rcp_f32_e32 v3, v3                                        ; 7e064503
	s_mul_hi_u32 s19, s18, s19                                  ; 96131312
	s_add_u32 s18, s18, s19                                     ; 80121312
	v_mul_f32_e32 v3, 0x4f7ffffe, v3                            ; 0a0606ff 4f7ffffe
	s_mul_hi_u32 s18, s0, s18                                   ; 96121200
	v_cvt_u32_f32_e32 v3, v3                                    ; 7e060f03
	s_mul_i32 s20, s18, s13                                     ; 92140d12
	v_readfirstlane_b32 s23, v3                                 ; 7e2e0503
	s_sub_i32 s0, s0, s20                                       ; 81801400
	s_mul_i32 s24, s12, s23                                     ; 9218170c
	s_cmp_ge_u32 s0, s13                                        ; bf090d00
	s_add_u32 s18, s18, src_scc                                 ; 8012fd12
	s_sub_i32 s22, s0, s13                                      ; 81960d00
	s_cmp_ge_u32 s0, s13                                        ; bf090d00
	s_cselect_b32 s22, s22, s0                                  ; 85160016
	s_cmp_ge_u32 s22, s13                                       ; bf090d16
	s_add_u32 s18, s18, src_scc                                 ; 8012fd12
	s_sub_i32 s24, 0, s24                                       ; 81981880
	s_mul_i32 s18, s18, s10                                     ; 92120a12
	s_mul_hi_u32 s24, s23, s24                                  ; 96181817
	s_add_u32 s23, s23, s24                                     ; 80171817
	s_mul_hi_u32 s23, s11, s23                                  ; 9617170b
	s_mul_i32 s25, s23, s12                                     ; 92190c17
	s_sub_i32 s11, s11, s25                                     ; 818b190b
	s_cmp_ge_u32 s11, s12                                       ; bf090c0b
	s_add_u32 s23, s23, src_scc                                 ; 8017fd17
	s_sub_i32 s27, s11, s12                                     ; 819b0c0b
	s_cmp_ge_u32 s11, s12                                       ; bf090c0b
	s_cselect_b32 s27, s27, s11                                 ; 851b0b1b
	s_cmp_ge_u32 s27, s12                                       ; bf090c1b
	s_add_u32 s23, s23, src_scc                                 ; 8017fd17
	s_add_u32 s18, s18, s23                                     ; 80121712
	s_branch BB4                                                ; bf820001
BB3:
	s_mov_b32 s18, 0                                            ; be920080
BB4:
	s_lshr_b32 s5, s5, 8                                        ; 8f058805
	v_and_b32_e32 v1, 12, v0                                    ; 2602008c
	v_and_b32_e32 v2, 15, v0                                    ; 2604008f
	s_lshr_b32 s3, s3, 8                                        ; 8f038803
	v_lshrrev_b32_e32 v0, 4, v0                                 ; 20000084
	v_mov_b32_e32 v5, 0                                         ; 7e0a0280
	v_mov_b32_e32 v6, 0                                         ; 7e0c0280
	v_mov_b32_e32 v7, 0                                         ; 7e0e0280
	s_mul_i32 s18, s18, s5                                      ; 92120512
	v_sub_u32_e32 v1, v2, v1                                    ; 6a020302
	v_bfe_u32 v3, v2, 2, 1                                      ; d1c80003 02050502
	v_lshrrev_b32_e32 v2, 3, v2                                 ; 20040483
	v_lshl_add_u32 v1, v1, 1, v3                                ; d1fd0001 040d0301
	v_mov_b32_e32 v3, 0                                         ; 7e060280
	v_lshlrev_b32_e32 v1, 2, v1                                 ; 24020282
	v_lshl_add_u32 v4, v2, 5, v1                                ; d1fd0004 04050b02
	v_lshl_add_u32 v1, v2, 6, v1                                ; d1fd0001 04050d02
	s_branch BB5                                                ; bf8201b0
BB10:
	s_mov_b64 exec, s[0:1]                                      ; befe0100
	s_mov_b32 s0, s2                                            ; be800002
	s_movk_i32 s1, 0x8000                                       ; b0018000
	s_load_dwordx8 s[24:31], s[0:1], 0x0                        ; c00e0600 00000000
	s_mul_i32 s0, s6, s17                                       ; 92001106
	v_lshl_add_u32 v8, v0, 8, v1                                ; d1fd0008 04051100
	v_add_u32_e32 v9, s0, v8                                    ; 68121000
	v_add_u32_e32 v8, 0x80, v8                                  ; 681010ff 00000080
	v_lshrrev_b32_e32 v9, 2, v9                                 ; 20121282
	v_add_u32_e32 v8, s0, v8                                    ; 68101000
	v_lshlrev_b32_e32 v9, 4, v9                                 ; 24121284
	v_lshrrev_b32_e32 v8, 2, v8                                 ; 20101082
	v_lshlrev_b32_e32 v8, 4, v8                                 ; 24101084
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_load_dwordx4 v[12:15], v9, s[28:31], 0 offen         ; e05c1000 80070c09
	buffer_load_dwordx4 v[16:19], v9, s[28:31], 0 offen offset:128 ; e05c1080 80071009
	buffer_load_dwordx4 v[20:23], v8, s[28:31], 0 offen         ; e05c1000 80071408
	buffer_load_dwordx4 v[8:11], v8, s[28:31], 0 offen offset:128 ; e05c1080 80070808
	s_mul_i32 s1, s16, s3                                       ; 92010310
	v_lshl_add_u32 v26, v2, 1, 8                                ; d1fd001a 02210302
	v_add_u32_e32 v30, 64, v4                                   ; 683c08c0
	s_add_u32 s1, s18, s1                                       ; 80010112
	s_add_u32 s4, s16, 1                                        ; 80048110
	v_add_u32_e32 v24, s1, v0                                   ; 68300001
	s_mul_i32 s4, s4, s3                                        ; 92040304
	v_lshlrev_b32_e32 v25, 4, v24                               ; 24323084
	s_add_u32 s4, s18, s4                                       ; 80040412
	s_add_u32 s5, s16, 2                                        ; 80058210
	v_lshl_add_u32 v24, v24, 7, v25                             ; d1fd0018 04650f18
	v_add_u32_e32 v31, s4, v0                                   ; 683e0004
	s_mul_i32 s5, s5, s3                                        ; 92050305
	v_add_u32_e32 v28, 16, v24                                  ; 68383090
	v_add3_u32 v27, v26, 4, v24                                 ; d1ff001b 0461091a
	v_lshlrev_b32_e32 v32, 4, v31                               ; 24403e84
	s_add_u32 s5, s18, s5                                       ; 80050512
	v_add_u32_e32 v29, v28, v4                                  ; 683a091c
	v_add_u32_e32 v28, v28, v30                                 ; 68383d1c
	s_add_u32 s9, s16, 3                                        ; 80098310
	v_lshl_add_u32 v31, v31, 7, v32                             ; d1fd001f 04810f1f
	v_add_u32_e32 v36, s5, v0                                   ; 68480005
	s_mul_i32 s9, s9, s3                                        ; 92090309
	v_add3_u32 v33, v26, 4, v31                                 ; d1ff0021 047d091a
	v_add_u32_e32 v34, 16, v31                                  ; 68443e90
	v_lshlrev_b32_e32 v37, 4, v36                               ; 244a4884
	s_add_u32 s9, s18, s9                                       ; 80090912
	v_add_u32_e32 v35, v34, v4                                  ; 68460922
	v_add_u32_e32 v34, v34, v30                                 ; 68443d22
	v_lshl_add_u32 v36, v36, 7, v37                             ; d1fd0024 04950f24
	v_add_u32_e32 v41, s9, v0                                   ; 68520009
	v_add_u32_e32 v39, 16, v36                                  ; 684e4890
	v_add3_u32 v38, v26, 4, v36                                 ; d1ff0026 0491091a
	v_lshlrev_b32_e32 v42, 4, v41                               ; 24545284
	v_add_u32_e32 v40, v39, v4                                  ; 68500927
	v_add_u32_e32 v39, v39, v30                                 ; 684e3d27
	v_lshl_add_u32 v41, v41, 7, v42                             ; d1fd0029 04a90f29
	v_add_u32_e32 v43, 16, v41                                  ; 68565290
	v_add3_u32 v26, v26, 4, v41                                 ; d1ff001a 04a5091a
	v_add_u32_e32 v44, v43, v4                                  ; 6858092b
	v_add_u32_e32 v43, v43, v30                                 ; 68563d2b
	buffer_load_dwordx3 v[45:47], v24, s[24:27], 0 offen        ; e0581000 80062d18
	buffer_load_ushort v27, v27, s[24:27], 0 offen              ; e0481000 80061b1b
	buffer_load_dword v29, v29, s[24:27], 0 offen               ; e0501000 80061d1d
	buffer_load_dword v28, v28, s[24:27], 0 offen               ; e0501000 80061c1c
	buffer_load_dwordx3 v[48:50], v31, s[24:27], 0 offen        ; e0581000 8006301f
	buffer_load_ushort v33, v33, s[24:27], 0 offen              ; e0481000 80062121
	buffer_load_dword v35, v35, s[24:27], 0 offen               ; e0501000 80062323
	buffer_load_dword v34, v34, s[24:27], 0 offen               ; e0501000 80062222
	buffer_load_dwordx3 v[51:53], v36, s[24:27], 0 offen        ; e0581000 80063324
	buffer_load_ushort v38, v38, s[24:27], 0 offen              ; e0481000 80062626
	buffer_load_dword v40, v40, s[24:27], 0 offen               ; e0501000 80062828
	buffer_load_dword v39, v39, s[24:27], 0 offen               ; e0501000 80062727
	buffer_load_dwordx3 v[54:56], v41, s[24:27], 0 offen        ; e0581000 80063629
	buffer_load_ushort v26, v26, s[24:27], 0 offen              ; e0481000 80061a1a
	buffer_load_dword v44, v44, s[24:27], 0 offen               ; e0501000 80062c2c
	buffer_load_dword v43, v43, s[24:27], 0 offen               ; e0501000 80062b2b
	s_bitreplicate_b64_b32 vcc, 0xf0f0f0f                       ; beea37ff 0f0f0f0f
	s_mov_b32 s10, 0xf0f0f0f                                    ; be8a00ff 0f0f0f0f
	s_mov_b32 s11, 0xc0c0c0c0                                   ; be8b00ff c0c0c0c0
	s_mov_b32 s12, 0x3f3f3f3f                                   ; be8c00ff 3f3f3f3f
	v_add_u32_e32 v0, 4, v0                                     ; 68000084
	s_waitcnt vmcnt(19)                                         ; bf8c7f73
	v_add_f32_e32 v57, v12, v13                                 ; 02721b0c
	s_waitcnt vmcnt(18)                                         ; bf8c7f72
	v_add_f32_e32 v58, v16, v17                                 ; 02742310
	s_waitcnt vmcnt(17)                                         ; bf8c7f71
	v_add_f32_e32 v59, v20, v21                                 ; 02762b14
	v_add_f32_e32 v57, v57, v14                                 ; 02721d39
	s_waitcnt vmcnt(16)                                         ; bf8c7f70
	v_add_f32_e32 v60, v8, v9                                   ; 02781308
	v_add_f32_e32 v58, v58, v18                                 ; 0274253a
	v_add_f32_e32 v59, v59, v22                                 ; 02762d3b
	v_add_f32_e32 v57, v57, v15                                 ; 02721f39
	v_add_f32_e32 v60, v60, v10                                 ; 0278153c
	v_add_f32_e32 v58, v58, v19                                 ; 0274273a
	v_add_f32_e32 v59, v59, v23                                 ; 02762f3b
	v_add_f32_e32 v60, v60, v11                                 ; 0278173c
	s_waitcnt vmcnt(15)                                         ; bf8c3f7f
	v_cvt_f32_f16_sdwa v31, v45 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e3e16f9 0005062d
	v_cvt_f32_f16_e32 v45, v45                                  ; 7e5a172d
	v_cndmask_b32_sdwa v61, v46, v46, vcc dst_sel:WORD_0 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 007a5cf9 0605142e
	v_cndmask_b32_sdwa v61, v47, v47, vcc dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 007a5ef9 0605152f
	s_waitcnt vmcnt(14)                                         ; bf8c3f7e
	v_lshl_or_b32 v27, v27, 12, v27                             ; d200001b 046d191b
	v_and_b32_e32 v62, s11, v61                                 ; 267c7a0b
	v_and_b32_e32 v61, s12, v61                                 ; 267a7a0c
	v_lshrrev_b32_e32 v62, 2, v62                               ; 207c7c82
	s_waitcnt vmcnt(13)                                         ; bf8c3f7d
	v_and_b32_e32 v41, s10, v29                                 ; 26523a0a
	v_cvt_f32_ubyte3_e32 v24, v61                               ; 7e30293d
	v_cvt_f32_ubyte2_e32 v25, v61                               ; 7e32273d
	v_cvt_f32_ubyte1_e32 v30, v61                               ; 7e3c253d
	v_cvt_f32_ubyte0_e32 v61, v61                               ; 7e7a233d
	v_and_or_b32 v27, s10, v27, v62                             ; d201001b 04fa360a
	v_cvt_f32_ubyte2_e32 v46, v41                               ; 7e5c2729
	v_cvt_f32_ubyte3_e32 v42, v41                               ; 7e542929
	v_cvt_f32_ubyte1_e32 v47, v41                               ; 7e5e2529
	v_cvt_f32_ubyte0_e32 v41, v41                               ; 7e522329
	v_cvt_f32_ubyte1_e32 v37, v27                               ; 7e4a251b
	v_cvt_f32_ubyte2_e32 v36, v27                               ; 7e48271b
	v_cvt_f32_ubyte3_e32 v32, v27                               ; 7e40291b
	v_cvt_f32_ubyte0_e32 v27, v27                               ; 7e36231b
	v_lshrrev_b32_e32 v29, 4, v29                               ; 203a3a84
	v_mul_f32_e32 v42, v15, v42                                 ; 0a54550f
	v_mul_f32_e32 v32, v60, v32                                 ; 0a40413c
	v_and_b32_e32 v29, s10, v29                                 ; 263a3a0a
	v_mac_f32_e32 v42, v14, v46                                 ; 2c545d0e
	v_mac_f32_e32 v32, v59, v36                                 ; 2c40493b
	v_cvt_f32_ubyte3_e32 v62, v29                               ; 7e7c291d
	v_mac_f32_e32 v42, v13, v47                                 ; 2c545f0d
	v_mac_f32_e32 v32, v58, v24                                 ; 2c40313a
	v_cvt_f32_ubyte2_e32 v24, v29                               ; 7e30271d
	v_mul_f32_e32 v62, v19, v62                                 ; 0a7c7d13
	v_mac_f32_e32 v42, v12, v41                                 ; 2c54530c
	v_mac_f32_e32 v32, v57, v25                                 ; 2c403339
	v_cvt_f32_ubyte1_e32 v25, v29                               ; 7e32251d
	v_cvt_f32_ubyte0_e32 v29, v29                               ; 7e3a231d
	v_mac_f32_e32 v62, v18, v24                                 ; 2c7c3112
	v_mad_f32 v3, -v31, v32, v3                                 ; d1c10003 240e411f
	v_mac_f32_e32 v62, v17, v25                                 ; 2c7c3311
	v_mac_f32_e32 v62, v16, v29                                 ; 2c7c3b10
	s_waitcnt vmcnt(12)                                         ; bf8c3f7c
	v_and_b32_e32 v29, s10, v28                                 ; 263a380a
	v_lshrrev_b32_e32 v28, 4, v28                               ; 20383884
	v_cvt_f32_ubyte3_e32 v31, v29                               ; 7e3e291d
	v_cvt_f32_ubyte1_e32 v36, v29                               ; 7e48251d
	v_cvt_f32_ubyte2_e32 v32, v29                               ; 7e40271d
	v_cvt_f32_ubyte0_e32 v29, v29                               ; 7e3a231d
	v_and_b32_e32 v28, s10, v28                                 ; 2638380a
	v_mul_f32_e32 v31, v23, v31                                 ; 0a3e3f17
	v_cvt_f32_ubyte3_e32 v41, v28                               ; 7e52291c
	v_cvt_f32_ubyte2_e32 v46, v28                               ; 7e5c271c
	v_cvt_f32_ubyte1_e32 v47, v28                               ; 7e5e251c
	v_cvt_f32_ubyte0_e32 v28, v28                               ; 7e38231c
	v_mac_f32_e32 v31, v22, v32                                 ; 2c3e4116
	s_waitcnt vmcnt(11)                                         ; bf8c3f7b
	v_cndmask_b32_sdwa v49, v49, v49, vcc dst_sel:WORD_0 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 006262f9 06051431
	v_mul_f32_e32 v41, v11, v41                                 ; 0a52530b
	v_cndmask_b32_sdwa v49, v50, v50, vcc dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 006264f9 06051532
	v_mac_f32_e32 v31, v21, v36                                 ; 2c3e4915
	v_mac_f32_e32 v41, v10, v46                                 ; 2c525d0a
	v_and_b32_e32 v50, s11, v49                                 ; 2664620b
	v_and_b32_e32 v49, s12, v49                                 ; 2662620c
	v_mac_f32_e32 v31, v20, v29                                 ; 2c3e3b14
	v_cvt_f32_f16_sdwa v25, v48 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e3216f9 00050630
	v_mac_f32_e32 v41, v9, v47                                  ; 2c525f09
	v_cvt_f32_f16_e32 v48, v48                                  ; 7e601730
	s_waitcnt vmcnt(10)                                         ; bf8c3f7a
	v_lshl_or_b32 v33, v33, 12, v33                             ; d2000021 04851921
	v_lshrrev_b32_e32 v50, 2, v50                               ; 20646482
	v_cvt_f32_ubyte1_e32 v24, v49                               ; 7e302531
	v_mac_f32_e32 v41, v8, v28                                  ; 2c523908
	v_and_or_b32 v33, s10, v33, v50                             ; d2010021 04ca420a
	v_mul_f32_e32 v41, v41, v37                                 ; 0a524b29
	v_cvt_f32_ubyte1_e32 v29, v33                               ; 7e3a2521
	v_cvt_f32_ubyte2_e32 v28, v33                               ; 7e382721
	v_mac_f32_e32 v41, v31, v27                                 ; 2c52371f
	v_cvt_f32_ubyte3_e32 v27, v33                               ; 7e362921
	v_cvt_f32_ubyte0_e32 v33, v33                               ; 7e422321
	v_mac_f32_e32 v41, v62, v30                                 ; 2c523d3e
	v_cvt_f32_ubyte2_e32 v62, v49                               ; 7e7c2731
	s_waitcnt vmcnt(9)                                          ; bf8c3f79
	v_and_b32_e32 v30, s10, v35                                 ; 263c460a
	v_mul_f32_e32 v27, v60, v27                                 ; 0a36373c
	v_mac_f32_e32 v41, v42, v61                                 ; 2c527b2a
	v_cvt_f32_ubyte3_e32 v61, v49                               ; 7e7a2931
	v_cvt_f32_ubyte0_e32 v49, v49                               ; 7e622331
	v_cvt_f32_ubyte1_e32 v36, v30                               ; 7e48251e
	v_cvt_f32_ubyte2_e32 v32, v30                               ; 7e40271e
	v_cvt_f32_ubyte3_e32 v31, v30                               ; 7e3e291e
	v_cvt_f32_ubyte0_e32 v30, v30                               ; 7e3c231e
	v_mac_f32_e32 v27, v59, v28                                 ; 2c36393b
	v_lshrrev_b32_e32 v35, 4, v35                               ; 20464684
	v_mac_f32_e32 v3, v45, v41                                  ; 2c06532d
	v_mul_f32_e32 v31, v15, v31                                 ; 0a3e3f0f
	v_mac_f32_e32 v27, v58, v61                                 ; 2c367b3a
	v_and_b32_e32 v35, s10, v35                                 ; 2646460a
	s_waitcnt vmcnt(8)                                          ; bf8c3f78
	v_and_b32_e32 v45, s10, v34                                 ; 265a440a
	v_mac_f32_e32 v31, v14, v32                                 ; 2c3e410e
	v_mac_f32_e32 v27, v57, v62                                 ; 2c367d39
	v_cvt_f32_ubyte1_e32 v42, v35                               ; 7e542523
	v_cvt_f32_ubyte3_e32 v37, v35                               ; 7e4a2923
	v_cvt_f32_ubyte2_e32 v41, v35                               ; 7e522723
	v_cvt_f32_ubyte0_e32 v35, v35                               ; 7e462323
	v_cvt_f32_ubyte2_e32 v47, v45                               ; 7e5e272d
	v_cvt_f32_ubyte3_e32 v46, v45                               ; 7e5c292d
	v_mac_f32_e32 v31, v13, v36                                 ; 2c3e490d
	v_cvt_f32_ubyte1_e32 v50, v45                               ; 7e64252d
	v_mad_f32 v5, -v25, v27, v5                                 ; d1c10005 24163719
	v_cvt_f32_ubyte0_e32 v45, v45                               ; 7e5a232d
	v_mul_f32_e32 v37, v19, v37                                 ; 0a4a4b13
	v_lshrrev_b32_e32 v34, 4, v34                               ; 20444484
	v_mul_f32_e32 v46, v23, v46                                 ; 0a5c5d17
	v_mac_f32_e32 v31, v12, v30                                 ; 2c3e3d0c
	v_mac_f32_e32 v37, v18, v41                                 ; 2c4a5312
	v_and_b32_e32 v34, s10, v34                                 ; 2644440a
	v_mac_f32_e32 v46, v22, v47                                 ; 2c5c5f16
	v_mac_f32_e32 v37, v17, v42                                 ; 2c4a5511
	v_cvt_f32_ubyte3_e32 v61, v34                               ; 7e7a2922
	v_cvt_f32_ubyte2_e32 v62, v34                               ; 7e7c2722
	v_mac_f32_e32 v46, v21, v50                                 ; 2c5c6515
	v_mac_f32_e32 v37, v16, v35                                 ; 2c4a4710
	v_mul_f32_e32 v61, v11, v61                                 ; 0a7a7b0b
	v_mac_f32_e32 v46, v20, v45                                 ; 2c5c5b14
	v_mac_f32_e32 v61, v10, v62                                 ; 2c7a7d0a
	v_cvt_f32_ubyte1_e32 v62, v34                               ; 7e7c2522
	v_cvt_f32_ubyte0_e32 v34, v34                               ; 7e442322
	v_mac_f32_e32 v61, v9, v62                                  ; 2c7a7d09
	s_waitcnt vmcnt(7)                                          ; bf8c3f77
	v_cndmask_b32_sdwa v62, v52, v52, vcc dst_sel:WORD_0 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 007c68f9 06051434
	v_cndmask_b32_sdwa v62, v53, v53, vcc dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 007c6af9 06051535
	v_mac_f32_e32 v61, v8, v34                                  ; 2c7a4508
	s_waitcnt vmcnt(6)                                          ; bf8c3f76
	v_lshl_or_b32 v38, v38, 12, v38                             ; d2000026 04991926
	v_mul_f32_e32 v61, v61, v29                                 ; 0a7a3b3d
	v_cvt_f32_f16_sdwa v29, v51 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e3a16f9 00050633
	v_cvt_f32_f16_e32 v51, v51                                  ; 7e661733
	v_mac_f32_e32 v61, v46, v33                                 ; 2c7a432e
	v_mac_f32_e32 v61, v37, v24                                 ; 2c7a3125
	v_and_b32_e32 v24, s11, v62                                 ; 26307c0b
	v_and_b32_e32 v62, s12, v62                                 ; 267c7c0c
	v_mac_f32_e32 v61, v31, v49                                 ; 2c7a631f
	s_waitcnt vmcnt(5)                                          ; bf8c3f75
	v_and_b32_e32 v32, s10, v40                                 ; 2640500a
	v_lshrrev_b32_e32 v24, 2, v24                               ; 20303082
	v_cvt_f32_ubyte1_e32 v28, v62                               ; 7e38253e
	v_cvt_f32_ubyte3_e32 v25, v62                               ; 7e32293e
	v_cvt_f32_ubyte2_e32 v27, v62                               ; 7e36273e
	v_cvt_f32_ubyte0_e32 v62, v62                               ; 7e7c233e
	v_mac_f32_e32 v5, v48, v61                                  ; 2c0a7b30
	v_cvt_f32_ubyte2_e32 v34, v32                               ; 7e442720
	v_cvt_f32_ubyte3_e32 v33, v32                               ; 7e422920
	v_cvt_f32_ubyte1_e32 v35, v32                               ; 7e462520
	v_and_or_b32 v38, s10, v38, v24                             ; d2010026 04624c0a
	v_cvt_f32_ubyte0_e32 v32, v32                               ; 7e402320
	v_lshrrev_b32_e32 v40, 4, v40                               ; 20505084
	v_mul_f32_e32 v33, v15, v33                                 ; 0a42430f
	v_cvt_f32_ubyte2_e32 v31, v38                               ; 7e3e2726
	v_cvt_f32_ubyte3_e32 v30, v38                               ; 7e3c2926
	v_and_b32_e32 v40, s10, v40                                 ; 2650500a
	v_mac_f32_e32 v33, v14, v34                                 ; 2c42450e
	s_waitcnt vmcnt(4)                                          ; bf8c3f74
	v_and_b32_e32 v42, s10, v39                                 ; 26544e0a
	v_mul_f32_e32 v30, v60, v30                                 ; 0a3c3d3c
	v_cvt_f32_ubyte1_e32 v41, v40                               ; 7e522528
	v_cvt_f32_ubyte3_e32 v36, v40                               ; 7e482928
	v_cvt_f32_ubyte2_e32 v37, v40                               ; 7e4a2728
	v_cvt_f32_ubyte0_e32 v40, v40                               ; 7e502328
	v_mac_f32_e32 v33, v13, v35                                 ; 2c42470d
	v_cvt_f32_ubyte3_e32 v45, v42                               ; 7e5a292a
	v_cvt_f32_ubyte2_e32 v46, v42                               ; 7e5c272a
	v_mac_f32_e32 v30, v59, v31                                 ; 2c3c3f3b
	v_cvt_f32_ubyte1_e32 v47, v42                               ; 7e5e252a
	v_mul_f32_e32 v36, v19, v36                                 ; 0a484913
	v_cvt_f32_ubyte0_e32 v42, v42                               ; 7e54232a
	v_lshrrev_b32_e32 v39, 4, v39                               ; 204e4e84
	v_mac_f32_e32 v33, v12, v32                                 ; 2c42410c
	v_mul_f32_e32 v45, v23, v45                                 ; 0a5a5b17
	v_mac_f32_e32 v30, v58, v25                                 ; 2c3c333a
	v_mac_f32_e32 v36, v18, v37                                 ; 2c484b12
	v_and_b32_e32 v39, s10, v39                                 ; 264e4e0a
	v_mac_f32_e32 v45, v22, v46                                 ; 2c5a5d16
	v_cvt_f32_ubyte1_e32 v52, v38                               ; 7e682526
	v_mac_f32_e32 v30, v57, v27                                 ; 2c3c3739
	v_mac_f32_e32 v36, v17, v41                                 ; 2c485311
	v_cvt_f32_ubyte2_e32 v49, v39                               ; 7e622727
	v_cvt_f32_ubyte0_e32 v38, v38                               ; 7e4c2326
	v_cvt_f32_ubyte1_e32 v50, v39                               ; 7e642527
	v_cvt_f32_ubyte3_e32 v48, v39                               ; 7e602927
	v_cvt_f32_ubyte0_e32 v39, v39                               ; 7e4e2327
	v_mac_f32_e32 v45, v21, v47                                 ; 2c5a5f15
	v_mad_f32 v6, -v29, v30, v6                                 ; d1c10006 241a3d1d
	v_mac_f32_e32 v36, v16, v40                                 ; 2c485110
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_cndmask_b32_sdwa v53, v55, v55, vcc dst_sel:WORD_0 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 006a6ef9 06051437
	v_cndmask_b32_sdwa v53, v56, v56, vcc dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 006a70f9 06051538
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_lshl_or_b32 v26, v26, 12, v26                             ; d200001a 0469191a
	v_mul_f32_e32 v48, v11, v48                                 ; 0a60610b
	v_mac_f32_e32 v45, v20, v42                                 ; 2c5a5514
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v56, s10, v44                                 ; 2670580a
	v_and_b32_e32 v55, s11, v53                                 ; 266e6a0b
	v_mac_f32_e32 v48, v10, v49                                 ; 2c60630a
	v_cvt_f32_ubyte3_e32 v61, v56                               ; 7e7a2938
	v_lshrrev_b32_e32 v55, 2, v55                               ; 206e6e82
	v_mac_f32_e32 v48, v9, v50                                  ; 2c606509
	v_mul_f32_e32 v15, v15, v61                                 ; 0a1e7b0f
	v_lshrrev_b32_e32 v44, 4, v44                               ; 20585884
	v_and_or_b32 v26, s10, v26, v55                             ; d201001a 04de340a
	v_mac_f32_e32 v48, v8, v39                                  ; 2c604f08
	v_and_b32_e32 v44, s10, v44                                 ; 2658580a
	v_mul_f32_e32 v48, v48, v52                                 ; 0a606930
	v_mac_f32_e32 v48, v45, v38                                 ; 2c604d2d
	v_mac_f32_e32 v48, v36, v28                                 ; 2c603924
	v_mac_f32_e32 v48, v33, v62                                 ; 2c607d21
	v_cvt_f32_ubyte2_e32 v62, v56                               ; 7e7c2738
	v_mac_f32_e32 v6, v51, v48                                  ; 2c0c6133
	v_mac_f32_e32 v15, v14, v62                                 ; 2c1e7d0e
	v_cvt_f32_ubyte1_e32 v62, v56                               ; 7e7c2538
	v_cvt_f32_ubyte0_e32 v56, v56                               ; 7e702338
	v_mac_f32_e32 v15, v13, v62                                 ; 2c1e7d0d
	v_cvt_f32_ubyte3_e32 v62, v44                               ; 7e7c292c
	v_mac_f32_e32 v15, v12, v56                                 ; 2c1e710c
	v_mul_f32_e32 v19, v19, v62                                 ; 0a267d13
	v_cvt_f32_ubyte2_e32 v62, v44                               ; 7e7c272c
	v_mac_f32_e32 v19, v18, v62                                 ; 2c267d12
	v_cvt_f32_ubyte1_e32 v62, v44                               ; 7e7c252c
	v_cvt_f32_ubyte0_e32 v44, v44                               ; 7e58232c
	v_mac_f32_e32 v19, v17, v62                                 ; 2c267d11
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v62, s10, v43                                 ; 267c560a
	v_lshrrev_b32_e32 v43, 4, v43                               ; 20565684
	v_mac_f32_e32 v19, v16, v44                                 ; 2c265910
	v_cvt_f32_ubyte1_e32 v14, v62                               ; 7e1c253e
	v_cvt_f32_ubyte2_e32 v13, v62                               ; 7e1a273e
	v_cvt_f32_ubyte3_e32 v12, v62                               ; 7e18293e
	v_cvt_f32_ubyte0_e32 v62, v62                               ; 7e7c233e
	v_and_b32_e32 v43, s10, v43                                 ; 2656560a
	v_mul_f32_e32 v23, v23, v12                                 ; 0a2e1917
	v_cvt_f32_ubyte1_e32 v18, v43                               ; 7e24252b
	v_cvt_f32_ubyte2_e32 v17, v43                               ; 7e22272b
	v_and_b32_e32 v53, s12, v53                                 ; 266a6a0c
	v_cvt_f32_ubyte3_e32 v16, v43                               ; 7e20292b
	v_cvt_f32_ubyte0_e32 v43, v43                               ; 7e56232b
	v_mac_f32_e32 v23, v22, v13                                 ; 2c2e1b16
	v_cvt_f32_ubyte3_e32 v22, v53                               ; 7e2c2935
	v_cvt_f32_ubyte2_e32 v24, v53                               ; 7e302735
	v_cvt_f32_ubyte1_e32 v25, v26                               ; 7e32251a
	v_mul_f32_e32 v11, v11, v16                                 ; 0a16210b
	v_mac_f32_e32 v23, v21, v14                                 ; 2c2e1d15
	v_cvt_f32_ubyte2_e32 v21, v26                               ; 7e2a271a
	v_mac_f32_e32 v11, v10, v17                                 ; 2c16230a
	v_mac_f32_e32 v23, v20, v62                                 ; 2c2e7d14
	v_cvt_f32_ubyte3_e32 v20, v26                               ; 7e28291a
	v_cvt_f32_ubyte0_e32 v26, v26                               ; 7e34231a
	v_cvt_f32_f16_sdwa v27, v54 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e3616f9 00050636
	v_mac_f32_e32 v11, v9, v18                                  ; 2c162509
	v_cvt_f32_f16_e32 v54, v54                                  ; 7e6c1736
	v_mul_f32_e32 v60, v60, v20                                 ; 0a78293c
	v_mac_f32_e32 v11, v8, v43                                  ; 2c165708
	v_mac_f32_e32 v60, v59, v21                                 ; 2c782b3b
	v_mul_f32_e32 v11, v11, v25                                 ; 0a16330b
	v_mac_f32_e32 v60, v58, v22                                 ; 2c782d3a
	v_mac_f32_e32 v11, v23, v26                                 ; 2c163517
	v_cvt_f32_ubyte1_e32 v26, v53                               ; 7e342535
	v_cvt_f32_ubyte0_e32 v53, v53                               ; 7e6a2335
	v_mac_f32_e32 v60, v57, v24                                 ; 2c783139
	v_mac_f32_e32 v11, v19, v26                                 ; 2c163513
	v_mad_f32 v7, -v27, v60, v7                                 ; d1c10007 241e791b
	v_mac_f32_e32 v11, v15, v53                                 ; 2c166b0f
	v_mac_f32_e32 v7, v54, v11                                  ; 2c0e1736
BB5:
	s_mov_b64 s[0:1], exec                                      ; be80017e
	v_cmpx_le_u32_e32 vcc, s3, v0                               ; 7db60003
BB6:
	s_andn2_b64 s[0:1], s[0:1], exec                            ; 89807e00
	s_cbranch_scc1 BB10                                         ; bf85fe4c
BB11:
	s_mov_b64 exec, -1                                          ; befe01c1
	s_or_saveexec_b64 s[4:5], -1                                ; be8421c1
	v_cndmask_b32_e64 v63, 0, v3, s[4:5]                        ; d100003f 00120680
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v63, v63, v63 quad_perm:[1,0,3,2] row_mask:0xf bank_mask:0xf ; 027e7efa ff00b13f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v63, v63, v63 quad_perm:[2,3,0,1] row_mask:0xf bank_mask:0xf ; 027e7efa ff004e3f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v63, v63, v63 row_half_mirror row_mask:0xf bank_mask:0xf ; 027e7efa ff01413f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v63, v63, v63 row_mirror row_mask:0xf bank_mask:0xf ; 027e7efa ff01403f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v63, v63, v63 row_bcast:15 row_mask:0xa bank_mask:0xf ; 027e7efa af01423f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v63, v63, v63 row_bcast:31 row_mask:0xc bank_mask:0xf ; 027e7efa cf01433f
	s_mov_b64 exec, s[4:5]                                      ; befe0104
	v_readlane_b32 s0, v63, 63                                  ; d2890000 00017f3f
	s_or_saveexec_b64 s[4:5], -1                                ; be8421c1
	v_cndmask_b32_e64 v63, 0, v5, s[4:5]                        ; d100003f 00120a80
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v63, v63, v63 quad_perm:[1,0,3,2] row_mask:0xf bank_mask:0xf ; 027e7efa ff00b13f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v63, v63, v63 quad_perm:[2,3,0,1] row_mask:0xf bank_mask:0xf ; 027e7efa ff004e3f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v63, v63, v63 row_half_mirror row_mask:0xf bank_mask:0xf ; 027e7efa ff01413f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v63, v63, v63 row_mirror row_mask:0xf bank_mask:0xf ; 027e7efa ff01403f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v63, v63, v63 row_bcast:15 row_mask:0xa bank_mask:0xf ; 027e7efa af01423f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v63, v63, v63 row_bcast:31 row_mask:0xc bank_mask:0xf ; 027e7efa cf01433f
	s_mov_b64 exec, s[4:5]                                      ; befe0104
	v_readlane_b32 s1, v63, 63                                  ; d2890001 00017f3f
	s_or_saveexec_b64 s[4:5], -1                                ; be8421c1
	v_cndmask_b32_e64 v63, 0, v6, s[4:5]                        ; d100003f 00120c80
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v63, v63, v63 quad_perm:[1,0,3,2] row_mask:0xf bank_mask:0xf ; 027e7efa ff00b13f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v63, v63, v63 quad_perm:[2,3,0,1] row_mask:0xf bank_mask:0xf ; 027e7efa ff004e3f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v63, v63, v63 row_half_mirror row_mask:0xf bank_mask:0xf ; 027e7efa ff01413f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v63, v63, v63 row_mirror row_mask:0xf bank_mask:0xf ; 027e7efa ff01403f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v63, v63, v63 row_bcast:15 row_mask:0xa bank_mask:0xf ; 027e7efa af01423f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v63, v63, v63 row_bcast:31 row_mask:0xc bank_mask:0xf ; 027e7efa cf01433f
	s_mov_b64 exec, s[4:5]                                      ; befe0104
	v_readlane_b32 s3, v63, 63                                  ; d2890003 00017f3f
	s_or_saveexec_b64 s[10:11], -1                              ; be8a21c1
	v_cndmask_b32_e64 v63, 0, v7, s[10:11]                      ; d100003f 002a0e80
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v63, v63, v63 quad_perm:[1,0,3,2] row_mask:0xf bank_mask:0xf ; 027e7efa ff00b13f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v63, v63, v63 quad_perm:[2,3,0,1] row_mask:0xf bank_mask:0xf ; 027e7efa ff004e3f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v63, v63, v63 row_half_mirror row_mask:0xf bank_mask:0xf ; 027e7efa ff01413f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v63, v63, v63 row_mirror row_mask:0xf bank_mask:0xf ; 027e7efa ff01403f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v63, v63, v63 row_bcast:15 row_mask:0xa bank_mask:0xf ; 027e7efa af01423f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v63, v63, v63 row_bcast:31 row_mask:0xc bank_mask:0xf ; 027e7efa cf01433f
	s_mov_b64 exec, 1                                           ; befe0181
	v_readlane_b32 s4, v63, 63                                  ; d2890004 00017f3f
BB12:
	s_bitcmp1_b32 s8, 0                                         ; bf0d8008
	s_cbranch_scc0 BB14                                         ; bf84000f
BB13:
	s_mov_b32 s10, s2                                           ; be8a0002
	s_movk_i32 s11, 0x8000                                      ; b00b8000
	s_load_dwordx4 s[12:15], s[10:11], 0x30                     ; c00a0305 00000030
	s_mul_i32 s5, s7, s17                                       ; 92051107
	s_mov_b32 s6, src_scc                                       ; be8600fd
	s_add_u32 s5, s5, s16                                       ; 80051005
	s_lshl_b32 s5, s5, 2                                        ; 8e058205
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s5, s[12:15], s5                        ; c0200146 00000005
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_mov_b32_e32 v0, s5                                        ; 7e000205
	v_add_f32_e32 v0, s0, v0                                    ; 02000000
	s_branch BB15                                               ; bf820002
BB14:
	s_mov_b32 s6, src_scc                                       ; be8600fd
	v_mov_b32_e32 v0, s0                                        ; 7e000200
BB15:
	s_bitcmp1_b32 s8, 1                                         ; bf0d8108
	s_cbranch_scc0 BB17                                         ; bf84000e
BB16:
	s_mov_b32 s8, s2                                            ; be880002
	s_movk_i32 s9, 0x8000                                       ; b0098000
	s_load_dwordx4 s[8:11], s[8:9], 0x40                        ; c00a0204 00000040
	s_mul_i32 s0, s7, s17                                       ; 92001107
	s_mov_b32 s5, src_scc                                       ; be8500fd
	s_add_u32 s0, s0, s16                                       ; 80001000
	s_lshl_b32 s0, s0, 2                                        ; 8e008200
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s0, s[8:11], s0                         ; c0200004 00000000
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v0, s0, v0                                    ; 02000000
	s_branch BB18                                               ; bf820001
BB17:
	s_mov_b32 s5, src_scc                                       ; be8500fd
BB18:
	s_mov_b32 s0, s3                                            ; be800003
	s_movk_i32 s3, 0x8000                                       ; b0038000
	s_load_dwordx4 s[8:11], s[2:3], 0x20                        ; c00a0201 00000020
	s_mul_i32 s7, s7, s17                                       ; 92071107
	s_add_u32 s7, s7, s16                                       ; 80071007
	s_lshl_b32 s7, s7, 2                                        ; 8e078207
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_store_dword v0, off, s[8:11], s7                     ; e0700000 07020080
	s_cmp_lg_i32 s6, 0                                          ; bf018006
	s_cbranch_scc0 BB20                                         ; bf84000b
BB19:
	s_load_dwordx4 s[12:15], s[2:3], 0x30                       ; c00a0301 00000030
	s_mov_b32 s6, src_scc                                       ; be8600fd
	s_add_u32 s16, s7, 4                                        ; 80108407
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s16, s[12:15], s16                      ; c0200406 00000010
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_mov_b32_e32 v0, s16                                       ; 7e000210
	v_add_f32_e32 v0, s1, v0                                    ; 02000001
	s_branch BB21                                               ; bf820002
BB20:
	s_mov_b32 s6, src_scc                                       ; be8600fd
	v_mov_b32_e32 v0, s1                                        ; 7e000201
BB21:
	s_cmp_lg_i32 s5, 0                                          ; bf018005
	s_cbranch_scc0 BB23                                         ; bf84000a
BB22:
	s_load_dwordx4 s[12:15], s[2:3], 0x40                       ; c00a0301 00000040
	s_mov_b32 s1, src_scc                                       ; be8100fd
	s_add_u32 s5, s7, 4                                         ; 80058407
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s5, s[12:15], s5                        ; c0200146 00000005
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v0, s5, v0                                    ; 02000005
	s_branch BB24                                               ; bf820001
BB23:
	s_mov_b32 s1, src_scc                                       ; be8100fd
BB24:
	s_add_u32 s5, s7, 4                                         ; 80058407
	buffer_store_dword v0, off, s[8:11], s5                     ; e0700000 05020080
	s_cmp_lg_i32 s6, 0                                          ; bf018006
	s_cbranch_scc0 BB26                                         ; bf84000b
BB25:
	s_load_dwordx4 s[12:15], s[2:3], 0x30                       ; c00a0301 00000030
	s_mov_b32 s5, src_scc                                       ; be8500fd
	s_add_u32 s6, s7, 8                                         ; 80068807
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s6, s[12:15], s6                        ; c0200186 00000006
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_mov_b32_e32 v0, s6                                        ; 7e000206
	v_add_f32_e32 v0, s0, v0                                    ; 02000000
	s_branch BB27                                               ; bf820002
BB26:
	s_mov_b32 s5, src_scc                                       ; be8500fd
	v_mov_b32_e32 v0, s0                                        ; 7e000200
BB27:
	s_cmp_lg_i32 s1, 0                                          ; bf018001
	s_cbranch_scc0 BB29                                         ; bf84000a
BB28:
	s_load_dwordx4 s[12:15], s[2:3], 0x40                       ; c00a0301 00000040
	s_mov_b32 s0, src_scc                                       ; be8000fd
	s_add_u32 s1, s7, 8                                         ; 80018807
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s1, s[12:15], s1                        ; c0200046 00000001
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v0, s1, v0                                    ; 02000001
	s_branch BB30                                               ; bf820001
BB29:
	s_mov_b32 s0, src_scc                                       ; be8000fd
BB30:
	s_add_u32 s1, s7, 8                                         ; 80018807
	buffer_store_dword v0, off, s[8:11], s1                     ; e0700000 01020080
	s_cmp_lg_i32 s5, 0                                          ; bf018005
	s_cbranch_scc0 BB32                                         ; bf84000a
BB31:
	s_load_dwordx4 s[12:15], s[2:3], 0x30                       ; c00a0301 00000030
	s_add_u32 s1, s7, 12                                        ; 80018c07
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s1, s[12:15], s1                        ; c0200046 00000001
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_mov_b32_e32 v0, s1                                        ; 7e000201
	v_add_f32_e32 v0, s4, v0                                    ; 02000004
	s_branch BB33                                               ; bf820001
BB32:
	v_mov_b32_e32 v0, s4                                        ; 7e000204
BB33:
	s_cmp_lg_i32 s0, 0                                          ; bf018000
	s_cbranch_scc0 BB36                                         ; bf840008
BB34:
	s_load_dwordx4 s[0:3], s[2:3], 0x40                         ; c00a0001 00000040
	s_add_u32 s4, s7, 12                                        ; 80048c07
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s4, s[0:3], s4                          ; c0200100 00000004
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v0, s4, v0                                    ; 02000004
BB36:
	s_add_u32 s7, s7, 12                                        ; 80078c07
	buffer_store_dword v0, off, s[8:11], s7                     ; e0700000 07020080
	s_branch BB119                                              ; bf82031d
BB42:
	s_cmp_lt_u32 s16, s4                                        ; bf0a0410
	s_cbranch_scc0 BB119                                        ; bf84031b
BB43:
	s_sub_i32 s4, s4, s16                                       ; 81841004
	s_add_u32 s17, s17, s9                                      ; 80110911
	s_cmp_lg_i32 s17, 0                                         ; bf018011
	s_cbranch_scc0 BB45                                         ; bf840043
BB44:
	v_cvt_f32_u32_e32 v1, s11                                   ; 7e020c0b
	v_rcp_f32_e32 v1, v1                                        ; 7e024501
	v_mul_f32_e32 v1, 0x4f7ffffe, v1                            ; 0a0202ff 4f7ffffe
	v_cvt_u32_f32_e32 v1, v1                                    ; 7e020f01
	v_readfirstlane_b32 s0, v1                                  ; 7e000501
	s_mul_i32 s1, s11, s0                                       ; 9201000b
	s_sub_i32 s1, 0, s1                                         ; 81810180
	s_mul_hi_u32 s1, s0, s1                                     ; 96010100
	v_cvt_f32_u32_e32 v2, s13                                   ; 7e040c0d
	s_add_u32 s0, s0, s1                                        ; 80000100
	v_rcp_f32_e32 v2, v2                                        ; 7e044502
	s_mul_hi_u32 s0, s17, s0                                    ; 96000011
	s_mul_i32 s9, s0, s11                                       ; 92090b00
	v_mul_f32_e32 v2, 0x4f7ffffe, v2                            ; 0a0404ff 4f7ffffe
	s_sub_i32 s9, s17, s9                                       ; 81890911
	v_cvt_u32_f32_e32 v2, v2                                    ; 7e040f02
	s_cmp_ge_u32 s9, s11                                        ; bf090b09
	v_readfirstlane_b32 s19, v2                                 ; 7e260502
	s_add_u32 s0, s0, src_scc                                   ; 8000fd00
	s_sub_i32 s15, s9, s11                                      ; 818f0b09
	s_cmp_ge_u32 s9, s11                                        ; bf090b09
	s_mul_i32 s20, s13, s19                                     ; 9214130d
	s_cselect_b32 s15, s15, s9                                  ; 850f090f
	s_cmp_ge_u32 s15, s11                                       ; bf090b0f
	s_mov_b32 s18, src_scc                                      ; be9200fd
	s_add_u32 s0, s0, src_scc                                   ; 8000fd00
	s_sub_i32 s11, s15, s11                                     ; 818b0b0f
	s_cmp_lg_i32 s18, 0                                         ; bf018012
	v_cvt_f32_u32_e32 v3, s12                                   ; 7e060c0c
	s_cselect_b32 s11, s11, s15                                 ; 850b0f0b
	s_sub_i32 s20, 0, s20                                       ; 81941480
	v_rcp_f32_e32 v3, v3                                        ; 7e064503
	s_mul_hi_u32 s20, s19, s20                                  ; 96141413
	s_add_u32 s19, s19, s20                                     ; 80131413
	v_mul_f32_e32 v3, 0x4f7ffffe, v3                            ; 0a0606ff 4f7ffffe
	s_mul_hi_u32 s19, s0, s19                                   ; 96131300
	v_cvt_u32_f32_e32 v3, v3                                    ; 7e060f03
	s_mul_i32 s21, s19, s13                                     ; 92150d13
	v_readfirstlane_b32 s24, v3                                 ; 7e300503
	s_sub_i32 s0, s0, s21                                       ; 81801500
	s_mul_i32 s25, s12, s24                                     ; 9219180c
	s_cmp_ge_u32 s0, s13                                        ; bf090d00
	s_add_u32 s19, s19, src_scc                                 ; 8013fd13
	s_sub_i32 s23, s0, s13                                      ; 81970d00
	s_cmp_ge_u32 s0, s13                                        ; bf090d00
	s_cselect_b32 s23, s23, s0                                  ; 85170017
	s_cmp_ge_u32 s23, s13                                       ; bf090d17
	s_add_u32 s19, s19, src_scc                                 ; 8013fd13
	s_sub_i32 s25, 0, s25                                       ; 81991980
	s_mul_i32 s19, s19, s10                                     ; 92130a13
	s_mul_hi_u32 s25, s24, s25                                  ; 96191918
	s_add_u32 s24, s24, s25                                     ; 80181918
	s_mul_hi_u32 s24, s11, s24                                  ; 9618180b
	s_mul_i32 s26, s24, s12                                     ; 921a0c18
	s_sub_i32 s11, s11, s26                                     ; 818b1a0b
	s_cmp_ge_u32 s11, s12                                       ; bf090c0b
	s_add_u32 s24, s24, src_scc                                 ; 8018fd18
	s_sub_i32 s28, s11, s12                                     ; 819c0c0b
	s_cmp_ge_u32 s11, s12                                       ; bf090c0b
	s_cselect_b32 s28, s28, s11                                 ; 851c0b1c
	s_cmp_ge_u32 s28, s12                                       ; bf090c1c
	s_add_u32 s24, s24, src_scc                                 ; 8018fd18
	s_add_u32 s19, s19, s24                                     ; 80131813
	s_branch BB46                                               ; bf820001
BB45:
	s_mov_b32 s19, 0                                            ; be930080
BB46:
	s_lshr_b32 s5, s5, 8                                        ; 8f058805
	v_and_b32_e32 v1, 12, v0                                    ; 2602008c
	v_and_b32_e32 v2, 15, v0                                    ; 2604008f
	s_lshr_b32 s3, s3, 8                                        ; 8f038803
	v_lshrrev_b32_e32 v0, 4, v0                                 ; 20000084
	v_mov_b32_e32 v5, 0                                         ; 7e0a0280
	v_mov_b32_e32 v6, 0                                         ; 7e0c0280
	v_mov_b32_e32 v7, 0                                         ; 7e0e0280
	s_mul_i32 s19, s19, s5                                      ; 92130513
	v_sub_u32_e32 v1, v2, v1                                    ; 6a020302
	v_bfe_u32 v3, v2, 2, 1                                      ; d1c80003 02050502
	v_lshrrev_b32_e32 v2, 3, v2                                 ; 20040483
	v_lshl_add_u32 v1, v1, 1, v3                                ; d1fd0001 040d0301
	v_mov_b32_e32 v3, 0                                         ; 7e060280
	v_lshlrev_b32_e32 v1, 2, v1                                 ; 24020282
	v_lshl_add_u32 v4, v2, 5, v1                                ; d1fd0004 04050b02
	v_lshl_add_u32 v1, v2, 6, v1                                ; d1fd0001 04050d02
BB47:
	s_mov_b64 s[0:1], exec                                      ; be80017e
	v_cmpx_le_u32_e32 vcc, s3, v0                               ; 7db60003
BB48:
	s_andn2_b64 s[0:1], s[0:1], exec                            ; 89807e00
	s_cbranch_scc0 BB65                                         ; bf8401c6
BB52:
	s_mov_b64 exec, s[0:1]                                      ; befe0100
	s_mov_b32 s0, s2                                            ; be800002
	s_movk_i32 s1, 0x8000                                       ; b0018000
	s_load_dwordx4 s[12:15], s[0:1], 0x10                       ; c00a0300 00000010
	s_mul_i32 s5, s6, s17                                       ; 92051106
	v_lshl_add_u32 v8, v0, 8, v1                                ; d1fd0008 04051100
	v_add_u32_e32 v9, s5, v8                                    ; 68121005
	v_add_u32_e32 v8, 0x80, v8                                  ; 681010ff 00000080
	v_lshrrev_b32_e32 v9, 2, v9                                 ; 20121282
	v_add_u32_e32 v8, s5, v8                                    ; 68101005
	v_lshlrev_b32_e32 v9, 4, v9                                 ; 24121284
	v_lshrrev_b32_e32 v8, 2, v8                                 ; 20101082
	v_lshlrev_b32_e32 v8, 4, v8                                 ; 24101084
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_load_dwordx4 v[12:15], v9, s[12:15], 0 offen         ; e05c1000 80030c09
	buffer_load_dwordx4 v[16:19], v9, s[12:15], 0 offen offset:128 ; e05c1080 80031009
	buffer_load_dwordx4 v[20:23], v8, s[12:15], 0 offen         ; e05c1000 80031408
	buffer_load_dwordx4 v[8:11], v8, s[12:15], 0 offen offset:128 ; e05c1080 80030808
	s_cmp_lg_i32 s4, 0                                          ; bf018004
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_add_f32_e32 v24, v12, v13                                 ; 02301b0c
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_add_f32_e32 v25, v16, v17                                 ; 02322310
	v_add_f32_e32 v24, v24, v14                                 ; 02301d18
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_add_f32_e32 v26, v20, v21                                 ; 02342b14
	v_add_f32_e32 v25, v25, v18                                 ; 02322519
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_add_f32_e32 v27, v8, v9                                   ; 02361308
	v_add_f32_e32 v24, v24, v15                                 ; 02301f18
	v_add_f32_e32 v26, v26, v22                                 ; 02342d1a
	v_add_f32_e32 v25, v25, v19                                 ; 02322719
	v_add_f32_e32 v27, v27, v10                                 ; 0236151b
	v_add_f32_e32 v26, v26, v23                                 ; 02342f1a
	v_add_f32_e32 v27, v27, v11                                 ; 0236171b
	s_cbranch_scc0 BB64                                         ; bf840199
BB53:
	s_load_dwordx4 s[12:15], s[0:1], 0x0                        ; c00a0300 00000000
	s_mul_i32 s0, s16, s3                                       ; 92000310
	v_lshl_add_u32 v30, v2, 1, 8                                ; d1fd001e 02210302
	v_add_u32_e32 v34, 64, v4                                   ; 684408c0
	s_add_u32 s0, s19, s0                                       ; 80000013
	v_add_u32_e32 v28, s0, v0                                   ; 68380000
	v_lshlrev_b32_e32 v29, 4, v28                               ; 243a3884
	v_lshl_add_u32 v28, v28, 7, v29                             ; d1fd001c 04750f1c
	v_add3_u32 v31, v30, 4, v28                                 ; d1ff001f 0471091e
	v_add_u32_e32 v32, 16, v28                                  ; 68403890
	v_add_u32_e32 v33, v32, v4                                  ; 68420920
	v_add_u32_e32 v32, v32, v34                                 ; 68404520
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_load_dwordx3 v[35:37], v28, s[12:15], 0 offen        ; e0581000 8003231c
	buffer_load_ushort v31, v31, s[12:15], 0 offen              ; e0481000 80031f1f
	buffer_load_dword v33, v33, s[12:15], 0 offen               ; e0501000 80032121
	buffer_load_dword v32, v32, s[12:15], 0 offen               ; e0501000 80032020
	s_bitreplicate_b64_b32 vcc, 0xf0f0f0f                       ; beea37ff 0f0f0f0f
	s_mov_b32 s1, 0xf0f0f0f                                     ; be8100ff 0f0f0f0f
	s_cmp_lt_u32 1, s4                                          ; bf0a0481
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_cndmask_b32_sdwa v38, v36, v36, vcc dst_sel:WORD_0 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 004c48f9 06051424
	v_cndmask_b32_sdwa v38, v37, v37, vcc dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 004c4af9 06051525
	v_cvt_f32_f16_sdwa v43, v35 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e5616f9 00050623
	v_cvt_f32_f16_e32 v35, v35                                  ; 7e461723
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_lshl_or_b32 v31, v31, 12, v31                             ; d200001f 047d191f
	v_and_b32_e32 v39, 0xc0c0c0c0, v38                          ; 264e4cff c0c0c0c0
	v_and_b32_e32 v38, 0x3f3f3f3f, v38                          ; 264c4cff 3f3f3f3f
	v_lshrrev_b32_e32 v39, 2, v39                               ; 204e4e82
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v47, s1, v33                                  ; 265e4201
	v_cvt_f32_ubyte3_e32 v40, v38                               ; 7e502926
	v_cvt_f32_ubyte2_e32 v41, v38                               ; 7e522726
	v_cvt_f32_ubyte1_e32 v42, v38                               ; 7e542526
	v_cvt_f32_ubyte0_e32 v38, v38                               ; 7e4c2326
	v_and_or_b32 v31, s1, v31, v39                              ; d201001f 049e3e01
	v_cvt_f32_ubyte3_e32 v48, v47                               ; 7e60292f
	v_cvt_f32_ubyte2_e32 v49, v47                               ; 7e62272f
	v_cvt_f32_ubyte1_e32 v50, v47                               ; 7e64252f
	v_cvt_f32_ubyte0_e32 v47, v47                               ; 7e5e232f
	v_cvt_f32_ubyte3_e32 v44, v31                               ; 7e58291f
	v_cvt_f32_ubyte2_e32 v45, v31                               ; 7e5a271f
	v_cvt_f32_ubyte1_e32 v46, v31                               ; 7e5c251f
	v_cvt_f32_ubyte0_e32 v31, v31                               ; 7e3e231f
	v_mul_f32_e32 v48, v15, v48                                 ; 0a60610f
	v_lshrrev_b32_e32 v33, 4, v33                               ; 20424284
	v_mul_f32_e32 v44, v27, v44                                 ; 0a58591b
	v_mac_f32_e32 v48, v14, v49                                 ; 2c60630e
	v_and_b32_e32 v33, s1, v33                                  ; 26424201
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v54, s1, v32                                  ; 266c4001
	v_mac_f32_e32 v44, v26, v45                                 ; 2c585b1a
	v_mac_f32_e32 v48, v13, v50                                 ; 2c60650d
	v_cvt_f32_ubyte2_e32 v52, v33                               ; 7e682721
	v_cvt_f32_ubyte1_e32 v53, v33                               ; 7e6a2521
	v_cvt_f32_ubyte3_e32 v51, v33                               ; 7e662921
	v_cvt_f32_ubyte0_e32 v33, v33                               ; 7e422321
	v_cvt_f32_ubyte3_e32 v55, v54                               ; 7e6e2936
	v_cvt_f32_ubyte2_e32 v56, v54                               ; 7e702736
	v_mac_f32_e32 v44, v25, v40                                 ; 2c585119
	v_mac_f32_e32 v48, v12, v47                                 ; 2c605f0c
	v_cvt_f32_ubyte1_e32 v57, v54                               ; 7e722536
	v_cvt_f32_ubyte0_e32 v54, v54                               ; 7e6c2336
	v_mul_f32_e32 v51, v19, v51                                 ; 0a666713
	v_lshrrev_b32_e32 v32, 4, v32                               ; 20404084
	v_mul_f32_e32 v55, v23, v55                                 ; 0a6e6f17
	v_mac_f32_e32 v44, v24, v41                                 ; 2c585318
	v_mac_f32_e32 v51, v18, v52                                 ; 2c666912
	v_and_b32_e32 v32, s1, v32                                  ; 26404001
	v_mac_f32_e32 v55, v22, v56                                 ; 2c6e7116
	v_mad_f32 v3, -v43, v44, v3                                 ; d1c10003 240e592b
	v_mac_f32_e32 v51, v17, v53                                 ; 2c666b11
	v_cvt_f32_ubyte1_e32 v60, v32                               ; 7e782520
	v_cvt_f32_ubyte3_e32 v58, v32                               ; 7e742920
	v_cvt_f32_ubyte2_e32 v59, v32                               ; 7e762720
	v_cvt_f32_ubyte0_e32 v32, v32                               ; 7e402320
	v_mac_f32_e32 v55, v21, v57                                 ; 2c6e7315
	v_mac_f32_e32 v51, v16, v33                                 ; 2c664310
	v_mul_f32_e32 v58, v11, v58                                 ; 0a74750b
	v_mac_f32_e32 v55, v20, v54                                 ; 2c6e6d14
	v_mac_f32_e32 v58, v10, v59                                 ; 2c74770a
	v_mac_f32_e32 v58, v9, v60                                  ; 2c747909
	v_mac_f32_e32 v58, v8, v32                                  ; 2c744108
	v_mul_f32_e32 v58, v58, v46                                 ; 0a745d3a
	v_mac_f32_e32 v58, v55, v31                                 ; 2c743f37
	v_mac_f32_e32 v58, v51, v42                                 ; 2c745533
	v_mac_f32_e32 v58, v48, v38                                 ; 2c744d30
	v_mac_f32_e32 v3, v35, v58                                  ; 2c067523
	s_cbranch_scc0 BB64                                         ; bf84012d
BB54:
	s_add_u32 s0, s16, 1                                        ; 80008110
	s_mul_i32 s0, s0, s3                                        ; 92000300
	s_add_u32 s0, s19, s0                                       ; 80000013
	v_add_u32_e32 v28, s0, v0                                   ; 68380000
	v_lshlrev_b32_e32 v29, 4, v28                               ; 243a3884
	v_lshl_add_u32 v28, v28, 7, v29                             ; d1fd001c 04750f1c
	v_add3_u32 v31, v30, 4, v28                                 ; d1ff001f 0471091e
	v_add_u32_e32 v32, 16, v28                                  ; 68403890
	v_add_u32_e32 v33, v32, v4                                  ; 68420920
	v_add_u32_e32 v32, v32, v34                                 ; 68404520
	buffer_load_dwordx3 v[35:37], v28, s[12:15], 0 offen        ; e0581000 8003231c
	buffer_load_ushort v31, v31, s[12:15], 0 offen              ; e0481000 80031f1f
	buffer_load_dword v33, v33, s[12:15], 0 offen               ; e0501000 80032121
	buffer_load_dword v32, v32, s[12:15], 0 offen               ; e0501000 80032020
	s_mov_b32 s1, 0xf0f0f0f                                     ; be8100ff 0f0f0f0f
	s_cmp_lt_u32 2, s4                                          ; bf0a0482
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_cndmask_b32_sdwa v38, v36, v36, vcc dst_sel:WORD_0 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 004c48f9 06051424
	v_cndmask_b32_sdwa v38, v37, v37, vcc dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 004c4af9 06051525
	v_cvt_f32_f16_sdwa v43, v35 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e5616f9 00050623
	v_cvt_f32_f16_e32 v35, v35                                  ; 7e461723
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_lshl_or_b32 v31, v31, 12, v31                             ; d200001f 047d191f
	v_and_b32_e32 v39, 0xc0c0c0c0, v38                          ; 264e4cff c0c0c0c0
	v_and_b32_e32 v38, 0x3f3f3f3f, v38                          ; 264c4cff 3f3f3f3f
	v_lshrrev_b32_e32 v39, 2, v39                               ; 204e4e82
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v47, s1, v33                                  ; 265e4201
	v_cvt_f32_ubyte3_e32 v40, v38                               ; 7e502926
	v_cvt_f32_ubyte2_e32 v41, v38                               ; 7e522726
	v_cvt_f32_ubyte1_e32 v42, v38                               ; 7e542526
	v_cvt_f32_ubyte0_e32 v38, v38                               ; 7e4c2326
	v_and_or_b32 v31, s1, v31, v39                              ; d201001f 049e3e01
	v_cvt_f32_ubyte3_e32 v48, v47                               ; 7e60292f
	v_cvt_f32_ubyte2_e32 v49, v47                               ; 7e62272f
	v_cvt_f32_ubyte1_e32 v50, v47                               ; 7e64252f
	v_cvt_f32_ubyte0_e32 v47, v47                               ; 7e5e232f
	v_cvt_f32_ubyte1_e32 v46, v31                               ; 7e5c251f
	v_cvt_f32_ubyte3_e32 v44, v31                               ; 7e58291f
	v_cvt_f32_ubyte2_e32 v45, v31                               ; 7e5a271f
	v_cvt_f32_ubyte0_e32 v31, v31                               ; 7e3e231f
	v_mul_f32_e32 v48, v15, v48                                 ; 0a60610f
	v_lshrrev_b32_e32 v33, 4, v33                               ; 20424284
	v_mul_f32_e32 v44, v27, v44                                 ; 0a58591b
	v_mac_f32_e32 v48, v14, v49                                 ; 2c60630e
	v_and_b32_e32 v33, s1, v33                                  ; 26424201
	v_mac_f32_e32 v44, v26, v45                                 ; 2c585b1a
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v54, s1, v32                                  ; 266c4001
	v_mac_f32_e32 v48, v13, v50                                 ; 2c60650d
	v_cvt_f32_ubyte1_e32 v53, v33                               ; 7e6a2521
	v_cvt_f32_ubyte3_e32 v51, v33                               ; 7e662921
	v_cvt_f32_ubyte2_e32 v52, v33                               ; 7e682721
	v_cvt_f32_ubyte0_e32 v33, v33                               ; 7e422321
	v_mac_f32_e32 v44, v25, v40                                 ; 2c585119
	v_cvt_f32_ubyte2_e32 v56, v54                               ; 7e702736
	v_cvt_f32_ubyte3_e32 v55, v54                               ; 7e6e2936
	v_mac_f32_e32 v48, v12, v47                                 ; 2c605f0c
	v_cvt_f32_ubyte1_e32 v57, v54                               ; 7e722536
	v_mul_f32_e32 v51, v19, v51                                 ; 0a666713
	v_cvt_f32_ubyte0_e32 v54, v54                               ; 7e6c2336
	v_lshrrev_b32_e32 v32, 4, v32                               ; 20404084
	v_mac_f32_e32 v44, v24, v41                                 ; 2c585318
	v_mul_f32_e32 v55, v23, v55                                 ; 0a6e6f17
	v_mac_f32_e32 v51, v18, v52                                 ; 2c666912
	v_and_b32_e32 v32, s1, v32                                  ; 26404001
	v_mad_f32 v5, -v43, v44, v5                                 ; d1c10005 2416592b
	v_mac_f32_e32 v55, v22, v56                                 ; 2c6e7116
	v_mac_f32_e32 v51, v17, v53                                 ; 2c666b11
	v_cvt_f32_ubyte3_e32 v58, v32                               ; 7e742920
	v_cvt_f32_ubyte2_e32 v59, v32                               ; 7e762720
	v_cvt_f32_ubyte1_e32 v60, v32                               ; 7e782520
	v_cvt_f32_ubyte0_e32 v32, v32                               ; 7e402320
	v_mac_f32_e32 v55, v21, v57                                 ; 2c6e7315
	v_mac_f32_e32 v51, v16, v33                                 ; 2c664310
	v_mul_f32_e32 v58, v11, v58                                 ; 0a74750b
	v_mac_f32_e32 v55, v20, v54                                 ; 2c6e6d14
	v_mac_f32_e32 v58, v10, v59                                 ; 2c74770a
	v_mac_f32_e32 v58, v9, v60                                  ; 2c747909
	v_mac_f32_e32 v58, v8, v32                                  ; 2c744108
	v_mul_f32_e32 v58, v58, v46                                 ; 0a745d3a
	v_mac_f32_e32 v58, v55, v31                                 ; 2c743f37
	v_mac_f32_e32 v58, v51, v42                                 ; 2c745533
	v_mac_f32_e32 v58, v48, v38                                 ; 2c744d30
	v_mac_f32_e32 v5, v35, v58                                  ; 2c0a7523
	s_cbranch_scc0 BB64                                         ; bf8400c8
BB55:
	s_add_u32 s0, s16, 2                                        ; 80008210
	s_mul_i32 s0, s0, s3                                        ; 92000300
	s_add_u32 s0, s19, s0                                       ; 80000013
	v_add_u32_e32 v28, s0, v0                                   ; 68380000
	v_lshlrev_b32_e32 v29, 4, v28                               ; 243a3884
	v_lshl_add_u32 v28, v28, 7, v29                             ; d1fd001c 04750f1c
	v_add3_u32 v31, v30, 4, v28                                 ; d1ff001f 0471091e
	v_add_u32_e32 v32, 16, v28                                  ; 68403890
	v_add_u32_e32 v33, v32, v4                                  ; 68420920
	v_add_u32_e32 v32, v32, v34                                 ; 68404520
	buffer_load_dwordx3 v[35:37], v28, s[12:15], 0 offen        ; e0581000 8003231c
	buffer_load_ushort v31, v31, s[12:15], 0 offen              ; e0481000 80031f1f
	buffer_load_dword v33, v33, s[12:15], 0 offen               ; e0501000 80032121
	buffer_load_dword v32, v32, s[12:15], 0 offen               ; e0501000 80032020
	s_mov_b32 s1, 0xf0f0f0f                                     ; be8100ff 0f0f0f0f
	s_cmp_lt_u32 3, s4                                          ; bf0a0483
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_cndmask_b32_sdwa v38, v36, v36, vcc dst_sel:WORD_0 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 004c48f9 06051424
	v_cndmask_b32_sdwa v38, v37, v37, vcc dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 004c4af9 06051525
	v_cvt_f32_f16_sdwa v43, v35 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e5616f9 00050623
	v_cvt_f32_f16_e32 v35, v35                                  ; 7e461723
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_lshl_or_b32 v31, v31, 12, v31                             ; d200001f 047d191f
	v_and_b32_e32 v39, 0xc0c0c0c0, v38                          ; 264e4cff c0c0c0c0
	v_and_b32_e32 v38, 0x3f3f3f3f, v38                          ; 264c4cff 3f3f3f3f
	v_lshrrev_b32_e32 v39, 2, v39                               ; 204e4e82
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v47, s1, v33                                  ; 265e4201
	v_cvt_f32_ubyte3_e32 v40, v38                               ; 7e502926
	v_cvt_f32_ubyte2_e32 v41, v38                               ; 7e522726
	v_cvt_f32_ubyte1_e32 v42, v38                               ; 7e542526
	v_cvt_f32_ubyte0_e32 v38, v38                               ; 7e4c2326
	v_and_or_b32 v31, s1, v31, v39                              ; d201001f 049e3e01
	v_cvt_f32_ubyte3_e32 v48, v47                               ; 7e60292f
	v_cvt_f32_ubyte2_e32 v49, v47                               ; 7e62272f
	v_cvt_f32_ubyte1_e32 v50, v47                               ; 7e64252f
	v_cvt_f32_ubyte0_e32 v47, v47                               ; 7e5e232f
	v_cvt_f32_ubyte1_e32 v46, v31                               ; 7e5c251f
	v_cvt_f32_ubyte3_e32 v44, v31                               ; 7e58291f
	v_cvt_f32_ubyte2_e32 v45, v31                               ; 7e5a271f
	v_cvt_f32_ubyte0_e32 v31, v31                               ; 7e3e231f
	v_mul_f32_e32 v48, v15, v48                                 ; 0a60610f
	v_lshrrev_b32_e32 v33, 4, v33                               ; 20424284
	v_mul_f32_e32 v44, v27, v44                                 ; 0a58591b
	v_mac_f32_e32 v48, v14, v49                                 ; 2c60630e
	v_and_b32_e32 v33, s1, v33                                  ; 26424201
	v_mac_f32_e32 v44, v26, v45                                 ; 2c585b1a
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v54, s1, v32                                  ; 266c4001
	v_mac_f32_e32 v48, v13, v50                                 ; 2c60650d
	v_cvt_f32_ubyte1_e32 v53, v33                               ; 7e6a2521
	v_cvt_f32_ubyte3_e32 v51, v33                               ; 7e662921
	v_cvt_f32_ubyte2_e32 v52, v33                               ; 7e682721
	v_cvt_f32_ubyte0_e32 v33, v33                               ; 7e422321
	v_mac_f32_e32 v44, v25, v40                                 ; 2c585119
	v_cvt_f32_ubyte2_e32 v56, v54                               ; 7e702736
	v_cvt_f32_ubyte3_e32 v55, v54                               ; 7e6e2936
	v_mac_f32_e32 v48, v12, v47                                 ; 2c605f0c
	v_cvt_f32_ubyte1_e32 v57, v54                               ; 7e722536
	v_mul_f32_e32 v51, v19, v51                                 ; 0a666713
	v_cvt_f32_ubyte0_e32 v54, v54                               ; 7e6c2336
	v_lshrrev_b32_e32 v32, 4, v32                               ; 20404084
	v_mac_f32_e32 v44, v24, v41                                 ; 2c585318
	v_mul_f32_e32 v55, v23, v55                                 ; 0a6e6f17
	v_mac_f32_e32 v51, v18, v52                                 ; 2c666912
	v_and_b32_e32 v32, s1, v32                                  ; 26404001
	v_mad_f32 v6, -v43, v44, v6                                 ; d1c10006 241a592b
	v_mac_f32_e32 v55, v22, v56                                 ; 2c6e7116
	v_mac_f32_e32 v51, v17, v53                                 ; 2c666b11
	v_cvt_f32_ubyte3_e32 v58, v32                               ; 7e742920
	v_cvt_f32_ubyte2_e32 v59, v32                               ; 7e762720
	v_cvt_f32_ubyte1_e32 v60, v32                               ; 7e782520
	v_cvt_f32_ubyte0_e32 v32, v32                               ; 7e402320
	v_mac_f32_e32 v55, v21, v57                                 ; 2c6e7315
	v_mac_f32_e32 v51, v16, v33                                 ; 2c664310
	v_mul_f32_e32 v58, v11, v58                                 ; 0a74750b
	v_mac_f32_e32 v55, v20, v54                                 ; 2c6e6d14
	v_mac_f32_e32 v58, v10, v59                                 ; 2c74770a
	v_mac_f32_e32 v58, v9, v60                                  ; 2c747909
	v_mac_f32_e32 v58, v8, v32                                  ; 2c744108
	v_mul_f32_e32 v58, v58, v46                                 ; 0a745d3a
	v_mac_f32_e32 v58, v55, v31                                 ; 2c743f37
	v_mac_f32_e32 v58, v51, v42                                 ; 2c745533
	v_mac_f32_e32 v58, v48, v38                                 ; 2c744d30
	v_mac_f32_e32 v6, v35, v58                                  ; 2c0c7523
	s_cbranch_scc0 BB64                                         ; bf840063
BB56:
	s_add_u32 s0, s16, 3                                        ; 80008310
	s_mul_i32 s0, s0, s3                                        ; 92000300
	s_add_u32 s0, s19, s0                                       ; 80000013
	v_add_u32_e32 v28, s0, v0                                   ; 68380000
	v_lshlrev_b32_e32 v29, 4, v28                               ; 243a3884
	v_lshl_add_u32 v28, v28, 7, v29                             ; d1fd001c 04750f1c
	v_add3_u32 v30, v30, 4, v28                                 ; d1ff001e 0471091e
	v_add_u32_e32 v31, 16, v28                                  ; 683e3890
	v_add_u32_e32 v32, v31, v4                                  ; 6840091f
	v_add_u32_e32 v31, v31, v34                                 ; 683e451f
	buffer_load_dwordx3 v[33:35], v28, s[12:15], 0 offen        ; e0581000 8003211c
	buffer_load_ushort v30, v30, s[12:15], 0 offen              ; e0481000 80031e1e
	buffer_load_dword v32, v32, s[12:15], 0 offen               ; e0501000 80032020
	buffer_load_dword v31, v31, s[12:15], 0 offen               ; e0501000 80031f1f
	s_mov_b32 s1, 0xf0f0f0f                                     ; be8100ff 0f0f0f0f
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_cvt_f32_f16_sdwa v41, v33 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e5216f9 00050621
	v_cvt_f32_f16_e32 v33, v33                                  ; 7e421721
	v_cndmask_b32_sdwa v36, v34, v34, vcc dst_sel:WORD_0 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 004844f9 06051422
	v_cndmask_b32_sdwa v36, v35, v35, vcc dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 004846f9 06051523
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_lshl_or_b32 v30, v30, 12, v30                             ; d200001e 0479191e
	v_and_b32_e32 v37, 0xc0c0c0c0, v36                          ; 264a48ff c0c0c0c0
	v_and_b32_e32 v36, 0x3f3f3f3f, v36                          ; 264848ff 3f3f3f3f
	v_lshrrev_b32_e32 v37, 2, v37                               ; 204a4a82
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v45, s1, v32                                  ; 265a4001
	v_cvt_f32_ubyte3_e32 v38, v36                               ; 7e4c2924
	v_cvt_f32_ubyte2_e32 v39, v36                               ; 7e4e2724
	v_cvt_f32_ubyte1_e32 v40, v36                               ; 7e502524
	v_cvt_f32_ubyte0_e32 v36, v36                               ; 7e482324
	v_and_or_b32 v30, s1, v30, v37                              ; d201001e 04963c01
	v_cvt_f32_ubyte3_e32 v46, v45                               ; 7e5c292d
	v_cvt_f32_ubyte2_e32 v47, v45                               ; 7e5e272d
	v_cvt_f32_ubyte1_e32 v48, v45                               ; 7e60252d
	v_cvt_f32_ubyte0_e32 v45, v45                               ; 7e5a232d
	v_cvt_f32_ubyte1_e32 v44, v30                               ; 7e58251e
	v_cvt_f32_ubyte3_e32 v42, v30                               ; 7e54291e
	v_cvt_f32_ubyte2_e32 v43, v30                               ; 7e56271e
	v_cvt_f32_ubyte0_e32 v30, v30                               ; 7e3c231e
	v_mul_f32_e32 v15, v15, v46                                 ; 0a1e5d0f
	v_lshrrev_b32_e32 v32, 4, v32                               ; 20404084
	v_mul_f32_e32 v27, v27, v42                                 ; 0a36551b
	v_mac_f32_e32 v15, v14, v47                                 ; 2c1e5f0e
	v_and_b32_e32 v32, s1, v32                                  ; 26404001
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v52, s1, v31                                  ; 26683e01
	v_mac_f32_e32 v27, v26, v43                                 ; 2c36571a
	v_mac_f32_e32 v15, v13, v48                                 ; 2c1e610d
	v_cvt_f32_ubyte1_e32 v51, v32                               ; 7e662520
	v_cvt_f32_ubyte3_e32 v49, v32                               ; 7e622920
	v_cvt_f32_ubyte2_e32 v50, v32                               ; 7e642720
	v_cvt_f32_ubyte0_e32 v32, v32                               ; 7e402320
	v_cvt_f32_ubyte3_e32 v53, v52                               ; 7e6a2934
	v_cvt_f32_ubyte2_e32 v54, v52                               ; 7e6c2734
	v_mac_f32_e32 v27, v25, v38                                 ; 2c364d19
	v_mac_f32_e32 v15, v12, v45                                 ; 2c1e5b0c
	v_cvt_f32_ubyte1_e32 v55, v52                               ; 7e6e2534
	v_mul_f32_e32 v19, v19, v49                                 ; 0a266313
	v_cvt_f32_ubyte0_e32 v52, v52                               ; 7e682334
	v_lshrrev_b32_e32 v31, 4, v31                               ; 203e3e84
	v_mul_f32_e32 v23, v23, v53                                 ; 0a2e6b17
	v_mac_f32_e32 v27, v24, v39                                 ; 2c364f18
	v_mac_f32_e32 v19, v18, v50                                 ; 2c266512
	v_and_b32_e32 v31, s1, v31                                  ; 263e3e01
	v_mac_f32_e32 v23, v22, v54                                 ; 2c2e6d16
	v_mad_f32 v7, -v41, v27, v7                                 ; d1c10007 241e3729
	v_mac_f32_e32 v19, v17, v51                                 ; 2c266711
	v_cvt_f32_ubyte3_e32 v56, v31                               ; 7e70291f
	v_cvt_f32_ubyte2_e32 v57, v31                               ; 7e72271f
	v_cvt_f32_ubyte1_e32 v58, v31                               ; 7e74251f
	v_cvt_f32_ubyte0_e32 v31, v31                               ; 7e3e231f
	v_mac_f32_e32 v23, v21, v55                                 ; 2c2e6f15
	v_mac_f32_e32 v19, v16, v32                                 ; 2c264110
	v_mul_f32_e32 v11, v11, v56                                 ; 0a16710b
	v_mac_f32_e32 v23, v20, v52                                 ; 2c2e6914
	v_mac_f32_e32 v11, v10, v57                                 ; 2c16730a
	v_mac_f32_e32 v11, v9, v58                                  ; 2c167509
	v_mac_f32_e32 v11, v8, v31                                  ; 2c163f08
	v_mul_f32_e32 v11, v11, v44                                 ; 0a16590b
	v_mac_f32_e32 v11, v23, v30                                 ; 2c163d17
	v_mac_f32_e32 v11, v19, v40                                 ; 2c165113
	v_mac_f32_e32 v11, v15, v36                                 ; 2c16490f
	v_mac_f32_e32 v7, v33, v11                                  ; 2c0e1721
BB64:
	v_add_u32_e32 v0, 4, v0                                     ; 68000084
	s_branch BB47                                               ; bf82fe36
BB65:
	s_mov_b64 exec, -1                                          ; befe01c1
	s_cmp_lg_i32 s4, 0                                          ; bf018004
	s_cselect_b64 s[0:1], -1, 0                                 ; 858080c1
	s_cbranch_scc0 BB77                                         ; bf84006a
BB66:
	s_or_saveexec_b64 s[10:11], -1                              ; be8a21c1
	s_cmp_lt_u32 1, s4                                          ; bf0a0481
	v_cndmask_b32_e64 v63, 0, v3, s[10:11]                      ; d100003f 002a0680
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v63, v63, v63 quad_perm:[1,0,3,2] row_mask:0xf bank_mask:0xf ; 027e7efa ff00b13f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v63, v63, v63 quad_perm:[2,3,0,1] row_mask:0xf bank_mask:0xf ; 027e7efa ff004e3f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v63, v63, v63 row_half_mirror row_mask:0xf bank_mask:0xf ; 027e7efa ff01413f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v63, v63, v63 row_mirror row_mask:0xf bank_mask:0xf ; 027e7efa ff01403f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v63, v63, v63 row_bcast:15 row_mask:0xa bank_mask:0xf ; 027e7efa af01423f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v63, v63, v63 row_bcast:31 row_mask:0xc bank_mask:0xf ; 027e7efa cf01433f
	s_mov_b64 exec, s[10:11]                                    ; befe010a
	v_readlane_b32 s3, v63, 63                                  ; d2890003 00017f3f
	s_cbranch_scc0 BB75                                         ; bf84004f
BB67:
	s_or_saveexec_b64 s[10:11], -1                              ; be8a21c1
	s_cmp_lt_u32 2, s4                                          ; bf0a0482
	v_cndmask_b32_e64 v63, 0, v5, s[10:11]                      ; d100003f 002a0a80
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v63, v63, v63 quad_perm:[1,0,3,2] row_mask:0xf bank_mask:0xf ; 027e7efa ff00b13f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v63, v63, v63 quad_perm:[2,3,0,1] row_mask:0xf bank_mask:0xf ; 027e7efa ff004e3f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v63, v63, v63 row_half_mirror row_mask:0xf bank_mask:0xf ; 027e7efa ff01413f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v63, v63, v63 row_mirror row_mask:0xf bank_mask:0xf ; 027e7efa ff01403f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v63, v63, v63 row_bcast:15 row_mask:0xa bank_mask:0xf ; 027e7efa af01423f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v63, v63, v63 row_bcast:31 row_mask:0xc bank_mask:0xf ; 027e7efa cf01433f
	s_mov_b64 exec, s[10:11]                                    ; befe010a
	v_readlane_b32 s5, v63, 63                                  ; d2890005 00017f3f
	s_cbranch_scc0 BB73                                         ; bf840034
BB68:
	s_or_saveexec_b64 s[10:11], -1                              ; be8a21c1
	s_cmp_lt_u32 3, s4                                          ; bf0a0483
	v_cndmask_b32_e64 v63, 0, v6, s[10:11]                      ; d100003f 002a0c80
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v63, v63, v63 quad_perm:[1,0,3,2] row_mask:0xf bank_mask:0xf ; 027e7efa ff00b13f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v63, v63, v63 quad_perm:[2,3,0,1] row_mask:0xf bank_mask:0xf ; 027e7efa ff004e3f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v63, v63, v63 row_half_mirror row_mask:0xf bank_mask:0xf ; 027e7efa ff01413f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v63, v63, v63 row_mirror row_mask:0xf bank_mask:0xf ; 027e7efa ff01403f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v63, v63, v63 row_bcast:15 row_mask:0xa bank_mask:0xf ; 027e7efa af01423f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v63, v63, v63 row_bcast:31 row_mask:0xc bank_mask:0xf ; 027e7efa cf01433f
	s_mov_b64 exec, s[10:11]                                    ; befe010a
	v_readlane_b32 s6, v63, 63                                  ; d2890006 00017f3f
	s_cbranch_scc0 BB71                                         ; bf840019
BB69:
	s_or_saveexec_b64 s[10:11], -1                              ; be8a21c1
	v_cndmask_b32_e64 v63, 0, v7, s[10:11]                      ; d100003f 002a0e80
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v63, v63, v63 quad_perm:[1,0,3,2] row_mask:0xf bank_mask:0xf ; 027e7efa ff00b13f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v63, v63, v63 quad_perm:[2,3,0,1] row_mask:0xf bank_mask:0xf ; 027e7efa ff004e3f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v63, v63, v63 row_half_mirror row_mask:0xf bank_mask:0xf ; 027e7efa ff01413f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v63, v63, v63 row_mirror row_mask:0xf bank_mask:0xf ; 027e7efa ff01403f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v63, v63, v63 row_bcast:15 row_mask:0xa bank_mask:0xf ; 027e7efa af01423f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v63, v63, v63 row_bcast:31 row_mask:0xc bank_mask:0xf ; 027e7efa cf01433f
	s_mov_b64 exec, s[10:11]                                    ; befe010a
	v_readlane_b32 s9, v63, 63                                  ; d2890009 00017f3f
	v_mov_b32_e32 v7, s9                                        ; 7e0e0209
BB71:
	v_mov_b32_e32 v6, s6                                        ; 7e0c0206
BB73:
	v_mov_b32_e32 v5, s5                                        ; 7e0a0205
BB75:
	v_mov_b32_e32 v3, s3                                        ; 7e060203
BB77:
	s_mov_b64 s[10:11], 1                                       ; be8a0181
	s_and_b64 exec, s[0:1], s[10:11]                            ; 86fe0a00
	s_cbranch_execz BB119                                       ; bf880083
BB78:
	s_bitcmp1_b32 s8, 0                                         ; bf0d8008
	s_cbranch_scc0 BB80                                         ; bf84000e
BB79:
	s_mov_b32 s0, s2                                            ; be800002
	s_movk_i32 s1, 0x8000                                       ; b0018000
	s_load_dwordx4 s[12:15], s[0:1], 0x30                       ; c00a0300 00000030
	s_mul_i32 s0, s7, s17                                       ; 92001107
	s_mov_b32 s1, src_scc                                       ; be8100fd
	s_add_u32 s0, s0, s16                                       ; 80001000
	s_lshl_b32 s0, s0, 2                                        ; 8e008200
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s0, s[12:15], s0                        ; c0200006 00000000
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v3, s0, v3                                    ; 02060600
	s_branch BB81                                               ; bf820001
BB80:
	s_mov_b32 s1, src_scc                                       ; be8100fd
BB81:
	s_bitcmp1_b32 s8, 1                                         ; bf0d8108
	s_cbranch_scc0 BB83                                         ; bf84000e
BB82:
	s_mov_b32 s8, s2                                            ; be880002
	s_movk_i32 s9, 0x8000                                       ; b0098000
	s_load_dwordx4 s[8:11], s[8:9], 0x40                        ; c00a0204 00000040
	s_mul_i32 s0, s7, s17                                       ; 92001107
	s_mov_b32 s3, src_scc                                       ; be8300fd
	s_add_u32 s0, s0, s16                                       ; 80001000
	s_lshl_b32 s0, s0, 2                                        ; 8e008200
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s0, s[8:11], s0                         ; c0200004 00000000
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v3, s0, v3                                    ; 02060600
	s_branch BB84                                               ; bf820001
BB83:
	s_mov_b32 s3, src_scc                                       ; be8300fd
BB84:
	s_mov_b32 s0, s3                                            ; be800003
	s_movk_i32 s3, 0x8000                                       ; b0038000
	s_load_dwordx4 s[8:11], s[2:3], 0x20                        ; c00a0201 00000020
	s_mul_i32 s7, s7, s17                                       ; 92071107
	s_add_u32 s7, s7, s16                                       ; 80071007
	s_lshl_b32 s7, s7, 2                                        ; 8e078207
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_store_dword v3, off, s[8:11], s7                     ; e0700000 07020380
	s_cmp_lt_u32 1, s4                                          ; bf0a0481
	s_cbranch_scc0 BB119                                        ; bf840055
BB85:
	s_cmp_lg_i32 s1, 0                                          ; bf018001
	s_cbranch_scc0 BB87                                         ; bf84000a
BB86:
	s_load_dwordx4 s[12:15], s[2:3], 0x30                       ; c00a0301 00000030
	s_mov_b32 s1, src_scc                                       ; be8100fd
	s_add_u32 s5, s7, 4                                         ; 80058407
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s5, s[12:15], s5                        ; c0200146 00000005
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v5, s5, v5                                    ; 020a0a05
	s_branch BB88                                               ; bf820001
BB87:
	s_mov_b32 s1, src_scc                                       ; be8100fd
BB88:
	s_cmp_lg_i32 s0, 0                                          ; bf018000
	s_cbranch_scc0 BB90                                         ; bf84000a
BB89:
	s_load_dwordx4 s[12:15], s[2:3], 0x40                       ; c00a0301 00000040
	s_mov_b32 s0, src_scc                                       ; be8000fd
	s_add_u32 s5, s7, 4                                         ; 80058407
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s5, s[12:15], s5                        ; c0200146 00000005
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v5, s5, v5                                    ; 020a0a05
	s_branch BB91                                               ; bf820001
BB90:
	s_mov_b32 s0, src_scc                                       ; be8000fd
BB91:
	s_add_u32 s5, s7, 4                                         ; 80058407
	buffer_store_dword v5, off, s[8:11], s5                     ; e0700000 05020580
	s_cmp_lt_u32 2, s4                                          ; bf0a0482
	s_cbranch_scc0 BB119                                        ; bf840036
BB92:
	s_cmp_lg_i32 s1, 0                                          ; bf018001
	s_cbranch_scc0 BB94                                         ; bf84000a
BB93:
	s_load_dwordx4 s[12:15], s[2:3], 0x30                       ; c00a0301 00000030
	s_mov_b32 s1, src_scc                                       ; be8100fd
	s_add_u32 s5, s7, 8                                         ; 80058807
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s5, s[12:15], s5                        ; c0200146 00000005
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v6, s5, v6                                    ; 020c0c05
	s_branch BB95                                               ; bf820001
BB94:
	s_mov_b32 s1, src_scc                                       ; be8100fd
BB95:
	s_cmp_lg_i32 s0, 0                                          ; bf018000
	s_cbranch_scc0 BB97                                         ; bf84000a
BB96:
	s_load_dwordx4 s[12:15], s[2:3], 0x40                       ; c00a0301 00000040
	s_mov_b32 s0, src_scc                                       ; be8000fd
	s_add_u32 s5, s7, 8                                         ; 80058807
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s5, s[12:15], s5                        ; c0200146 00000005
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v6, s5, v6                                    ; 020c0c05
	s_branch BB98                                               ; bf820001
BB97:
	s_mov_b32 s0, src_scc                                       ; be8000fd
BB98:
	s_add_u32 s5, s7, 8                                         ; 80058807
	buffer_store_dword v6, off, s[8:11], s5                     ; e0700000 05020680
	s_cmp_lt_u32 3, s4                                          ; bf0a0483
	s_cbranch_scc0 BB119                                        ; bf840017
BB99:
	s_cmp_lg_i32 s1, 0                                          ; bf018001
	s_cbranch_scc0 BB102                                        ; bf840008
BB100:
	s_load_dwordx4 s[12:15], s[2:3], 0x30                       ; c00a0301 00000030
	s_add_u32 s1, s7, 12                                        ; 80018c07
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s1, s[12:15], s1                        ; c0200046 00000001
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v7, s1, v7                                    ; 020e0e01
BB102:
	s_cmp_lg_i32 s0, 0                                          ; bf018000
	s_cbranch_scc0 BB105                                        ; bf840008
BB103:
	s_load_dwordx4 s[0:3], s[2:3], 0x40                         ; c00a0001 00000040
	s_add_u32 s4, s7, 12                                        ; 80048c07
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s4, s[0:3], s4                          ; c0200100 00000004
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v7, s4, v7                                    ; 020e0e04
BB105:
	s_add_u32 s7, s7, 12                                        ; 80078c07
	buffer_store_dword v7, off, s[8:11], s7                     ; e0700000 07020780
BB119:
	s_endpgm                                                    ; bf810000
