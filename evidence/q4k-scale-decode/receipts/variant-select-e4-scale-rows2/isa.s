BB0:
	s_load_dword s0, s[14:15], 0x0                              ; c0020007 00000000
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_mul_i32 s0, s0, s18                                       ; 92001200
	s_add_u32 s16, s16, s0                                      ; 80100010
	s_lshl_b32 s16, s16, 1                                      ; 8e108110
	s_add_u32 s1, s16, 2                                        ; 80018210
	s_cmp_ge_u32 s4, s1                                         ; bf090104
	s_cbranch_scc0 BB30                                         ; bf8401c4
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
	s_mul_i32 s18, s18, s5                                      ; 92120512
	v_sub_u32_e32 v1, v2, v1                                    ; 6a020302
	v_bfe_u32 v3, v2, 2, 1                                      ; d1c80003 02050502
	v_lshrrev_b32_e32 v2, 3, v2                                 ; 20040483
	v_lshl_add_u32 v1, v1, 1, v3                                ; d1fd0001 040d0301
	v_mov_b32_e32 v3, 0                                         ; 7e060280
	v_lshlrev_b32_e32 v1, 2, v1                                 ; 24020282
	v_lshl_add_u32 v4, v2, 5, v1                                ; d1fd0004 04050b02
	v_lshl_add_u32 v1, v2, 6, v1                                ; d1fd0001 04050d02
	v_lshlrev_b32_e32 v2, 4, v2                                 ; 24040484
	s_branch BB5                                                ; bf8200ea
BB10:
	s_mov_b64 exec, s[0:1]                                      ; befe0100
	s_mov_b32 s0, s2                                            ; be800002
	s_movk_i32 s1, 0x8000                                       ; b0018000
	s_load_dwordx8 s[24:31], s[0:1], 0x0                        ; c00e0600 00000000
	s_mul_i32 s0, s6, s17                                       ; 92001106
	v_lshl_add_u32 v6, v0, 8, v1                                ; d1fd0006 04051100
	v_add_u32_e32 v7, s0, v6                                    ; 680e0c00
	v_add_u32_e32 v6, 0x80, v6                                  ; 680c0cff 00000080
	v_lshrrev_b32_e32 v7, 2, v7                                 ; 200e0e82
	v_add_u32_e32 v6, s0, v6                                    ; 680c0c00
	v_lshlrev_b32_e32 v7, 4, v7                                 ; 240e0e84
	v_lshrrev_b32_e32 v6, 2, v6                                 ; 200c0c82
	v_lshlrev_b32_e32 v6, 4, v6                                 ; 240c0c84
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_load_dwordx4 v[8:11], v7, s[28:31], 0 offen          ; e05c1000 80070807
	buffer_load_dwordx4 v[12:15], v7, s[28:31], 0 offen offset:128 ; e05c1080 80070c07
	buffer_load_dwordx4 v[16:19], v6, s[28:31], 0 offen         ; e05c1000 80071006
	buffer_load_dwordx4 v[20:23], v6, s[28:31], 0 offen offset:128 ; e05c1080 80071406
	s_mul_i32 s1, s16, s3                                       ; 92010310
	v_add_u32_e32 v28, 64, v4                                   ; 683808c0
	s_add_u32 s1, s18, s1                                       ; 80010112
	s_add_u32 s4, s16, 1                                        ; 80048110
	v_add_u32_e32 v24, s1, v0                                   ; 68300001
	s_mul_i32 s4, s4, s3                                        ; 92040304
	v_lshlrev_b32_e32 v25, 4, v24                               ; 24323084
	s_add_u32 s4, s18, s4                                       ; 80040412
	v_lshl_add_u32 v24, v24, 7, v25                             ; d1fd0018 04650f18
	v_add_u32_e32 v29, s4, v0                                   ; 683a0004
	v_add_u32_e32 v26, 16, v24                                  ; 68343090
	v_lshlrev_b32_e32 v30, 4, v29                               ; 243c3a84
	v_add_u32_e32 v27, v26, v4                                  ; 6836091a
	v_add_u32_e32 v26, v26, v28                                 ; 6834391a
	v_lshl_add_u32 v29, v29, 7, v30                             ; d1fd001d 04790f1d
	v_add_u32_e32 v31, 16, v29                                  ; 683e3a90
	v_add_u32_e32 v32, v31, v4                                  ; 6840091f
	v_add_u32_e32 v31, v31, v28                                 ; 683e391f
	buffer_load_dwordx4 v[36:39], v24, s[24:27], 0 offen        ; e05c1000 80062418
	buffer_load_dword v27, v27, s[24:27], 0 offen               ; e0501000 80061b1b
	buffer_load_dword v26, v26, s[24:27], 0 offen               ; e0501000 80061a1a
	buffer_load_dwordx4 v[40:43], v29, s[24:27], 0 offen        ; e05c1000 8006281d
	buffer_load_dword v32, v32, s[24:27], 0 offen               ; e0501000 80062020
	buffer_load_dword v31, v31, s[24:27], 0 offen               ; e0501000 80061f1f
	s_bitreplicate_b64_b32 vcc, 0xf0f0f0f                       ; beea37ff 0f0f0f0f
	s_mov_b32 s5, 0xf0f0f0f                                     ; be8500ff 0f0f0f0f
	v_add_u32_e32 v0, 4, v0                                     ; 68000084
	s_waitcnt vmcnt(9)                                          ; bf8c3f79
	v_add_f32_e32 v33, v8, v9                                   ; 02421308
	s_waitcnt vmcnt(8)                                          ; bf8c3f78
	v_add_f32_e32 v34, v12, v13                                 ; 02441b0c
	s_waitcnt vmcnt(7)                                          ; bf8c3f77
	v_add_f32_e32 v35, v16, v17                                 ; 02462310
	v_add_f32_e32 v33, v33, v10                                 ; 02421521
	v_add_f32_e32 v34, v34, v14                                 ; 02441d22
	s_waitcnt vmcnt(6)                                          ; bf8c3f76
	v_add_f32_e32 v44, v20, v21                                 ; 02582b14
	v_add_f32_e32 v35, v35, v18                                 ; 02462523
	v_add_f32_e32 v33, v33, v11                                 ; 02421721
	v_add_f32_e32 v34, v34, v15                                 ; 02441f22
	v_add_f32_e32 v44, v44, v22                                 ; 02582d2c
	v_add_f32_e32 v35, v35, v19                                 ; 02462723
	v_add_f32_e32 v44, v44, v23                                 ; 02582f2c
	s_waitcnt vmcnt(5)                                          ; bf8c3f75
	v_cndmask_b32_sdwa v45, v37, v37, vcc dst_sel:WORD_0 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 005a4af9 06051425
	v_bfe_u32 v39, v39, v2, 16                                  ; d1c80027 02420527
	v_cndmask_b32_sdwa v45, v38, v38, vcc dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 005a4cf9 06051526
	v_lshl_or_b32 v39, v39, 12, v39                             ; d2000027 049d1927
	v_and_b32_e32 v46, 0xc0c0c0c0, v45                          ; 265c5aff c0c0c0c0
	v_and_b32_e32 v45, 0x3f3f3f3f, v45                          ; 265a5aff 3f3f3f3f
	v_cvt_f32_f16_sdwa v29, v36 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e3a16f9 00050624
	v_lshrrev_b32_e32 v46, 2, v46                               ; 205c5c82
	v_cvt_f32_ubyte3_e32 v7, v45                                ; 7e0e292d
	v_cvt_f32_ubyte2_e32 v24, v45                               ; 7e30272d
	v_cvt_f32_ubyte1_e32 v28, v45                               ; 7e38252d
	v_cvt_f32_ubyte0_e32 v45, v45                               ; 7e5a232d
	v_cvt_f32_f16_e32 v36, v36                                  ; 7e481724
	s_waitcnt vmcnt(4)                                          ; bf8c3f74
	v_and_b32_e32 v30, s5, v27                                  ; 263c3605
	v_and_or_b32 v39, s5, v39, v46                              ; d2010027 04ba4e05
	v_cvt_f32_ubyte3_e32 v37, v30                               ; 7e4a291e
	v_cvt_f32_ubyte2_e32 v38, v30                               ; 7e4c271e
	v_cvt_f32_ubyte2_e32 v6, v39                                ; 7e0c2727
	v_cvt_f32_ubyte1_e32 v25, v39                               ; 7e322527
	v_cvt_f32_ubyte3_e32 v46, v39                               ; 7e5c2927
	v_cvt_f32_ubyte0_e32 v39, v39                               ; 7e4e2327
	v_mul_f32_e32 v37, v11, v37                                 ; 0a4a4b0b
	v_lshrrev_b32_e32 v27, 4, v27                               ; 20363684
	v_mul_f32_e32 v46, v44, v46                                 ; 0a5c5d2c
	v_mac_f32_e32 v37, v10, v38                                 ; 2c4a4d0a
	v_and_b32_e32 v27, s5, v27                                  ; 26363605
	v_mac_f32_e32 v46, v35, v6                                  ; 2c5c0d23
	v_cvt_f32_ubyte2_e32 v6, v27                                ; 7e0c271b
	v_mac_f32_e32 v46, v34, v7                                  ; 2c5c0f22
	v_cvt_f32_ubyte1_e32 v7, v27                                ; 7e0e251b
	v_mac_f32_e32 v46, v33, v24                                 ; 2c5c3121
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_and_b32_e32 v24, s5, v26                                  ; 26303405
	v_mad_f32 v3, -v29, v46, v3                                 ; d1c10003 240e5d1d
	v_cvt_f32_ubyte1_e32 v46, v30                               ; 7e5c251e
	v_cvt_f32_ubyte0_e32 v30, v30                               ; 7e3c231e
	v_cvt_f32_ubyte2_e32 v29, v24                               ; 7e3a2718
	v_mac_f32_e32 v37, v9, v46                                  ; 2c4a5d09
	v_cvt_f32_ubyte3_e32 v46, v27                               ; 7e5c291b
	v_cvt_f32_ubyte0_e32 v27, v27                               ; 7e36231b
	v_lshrrev_b32_e32 v26, 4, v26                               ; 20343484
	v_mac_f32_e32 v37, v8, v30                                  ; 2c4a3d08
	v_cvt_f32_ubyte1_e32 v30, v24                               ; 7e3c2518
	v_mul_f32_e32 v46, v15, v46                                 ; 0a5c5d0f
	v_and_b32_e32 v26, s5, v26                                  ; 26343405
	v_mac_f32_e32 v46, v14, v6                                  ; 2c5c0d0e
	v_cvt_f32_ubyte3_e32 v38, v26                               ; 7e4c291a
	v_cvt_f32_ubyte2_e32 v6, v26                                ; 7e0c271a
	v_mac_f32_e32 v46, v13, v7                                  ; 2c5c0f0d
	v_cvt_f32_ubyte1_e32 v7, v26                                ; 7e0e251a
	v_cvt_f32_ubyte0_e32 v26, v26                               ; 7e34231a
	v_mul_f32_e32 v38, v23, v38                                 ; 0a4c4d17
	v_mac_f32_e32 v46, v12, v27                                 ; 2c5c370c
	v_cvt_f32_ubyte3_e32 v27, v24                               ; 7e362918
	v_cvt_f32_ubyte0_e32 v24, v24                               ; 7e302318
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_bfe_u32 v43, v43, v2, 16                                  ; d1c8002b 0242052b
	v_mac_f32_e32 v38, v22, v6                                  ; 2c4c0d16
	v_mul_f32_e32 v27, v19, v27                                 ; 0a363713
	v_lshl_or_b32 v43, v43, 12, v43                             ; d200002b 04ad192b
	v_mac_f32_e32 v38, v21, v7                                  ; 2c4c0f15
	v_mac_f32_e32 v27, v18, v29                                 ; 2c363b12
	v_mac_f32_e32 v38, v20, v26                                 ; 2c4c3514
	v_mac_f32_e32 v27, v17, v30                                 ; 2c363d11
	v_mul_f32_e32 v38, v38, v25                                 ; 0a4c3326
	v_mac_f32_e32 v27, v16, v24                                 ; 2c363110
	v_cndmask_b32_sdwa v24, v41, v41, vcc dst_sel:WORD_0 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 003052f9 06051429
	v_cndmask_b32_sdwa v24, v42, v42, vcc dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 003054f9 0605152a
	v_mac_f32_e32 v38, v27, v39                                 ; 2c4c4f1b
	v_and_b32_e32 v25, 0xc0c0c0c0, v24                          ; 263230ff c0c0c0c0
	v_and_b32_e32 v24, 0x3f3f3f3f, v24                          ; 263030ff 3f3f3f3f
	v_mac_f32_e32 v38, v46, v28                                 ; 2c4c392e
	v_lshrrev_b32_e32 v25, 2, v25                               ; 20323282
	v_cvt_f32_ubyte2_e32 v29, v24                               ; 7e3a2718
	v_cvt_f32_ubyte3_e32 v28, v24                               ; 7e382918
	v_mac_f32_e32 v38, v37, v45                                 ; 2c4c5b25
	v_and_or_b32 v43, s5, v43, v25                              ; d201002b 04665605
	v_mac_f32_e32 v3, v36, v38                                  ; 2c064d24
	v_cvt_f32_ubyte2_e32 v27, v43                               ; 7e36272b
	v_cvt_f32_ubyte1_e32 v30, v43                               ; 7e3c252b
	v_cvt_f32_ubyte3_e32 v26, v43                               ; 7e34292b
	v_cvt_f32_ubyte0_e32 v43, v43                               ; 7e56232b
	v_mul_f32_e32 v44, v44, v26                                 ; 0a58352c
	v_mac_f32_e32 v44, v35, v27                                 ; 2c583723
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v35, s5, v32                                  ; 26464005
	v_lshrrev_b32_e32 v32, 4, v32                               ; 20404084
	v_mac_f32_e32 v44, v34, v28                                 ; 2c583922
	v_cvt_f32_f16_sdwa v34, v40 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e4416f9 00050628
	v_cvt_f32_f16_e32 v40, v40                                  ; 7e501728
	v_cvt_f32_ubyte2_e32 v37, v35                               ; 7e4a2723
	v_cvt_f32_ubyte3_e32 v36, v35                               ; 7e482923
	v_cvt_f32_ubyte1_e32 v38, v35                               ; 7e4c2523
	v_cvt_f32_ubyte0_e32 v35, v35                               ; 7e462323
	v_and_b32_e32 v32, s5, v32                                  ; 26404005
	v_mac_f32_e32 v44, v33, v29                                 ; 2c583b21
	v_cvt_f32_ubyte1_e32 v33, v24                               ; 7e422518
	v_cvt_f32_ubyte0_e32 v24, v24                               ; 7e302318
	v_mul_f32_e32 v11, v11, v36                                 ; 0a16490b
	v_cvt_f32_ubyte2_e32 v41, v32                               ; 7e522720
	v_cvt_f32_ubyte3_e32 v39, v32                               ; 7e4e2920
	v_cvt_f32_ubyte1_e32 v42, v32                               ; 7e542520
	v_cvt_f32_ubyte0_e32 v32, v32                               ; 7e402320
	v_mad_f32 v5, -v34, v44, v5                                 ; d1c10005 24165922
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v44, s5, v31                                  ; 26583e05
	v_mac_f32_e32 v11, v10, v37                                 ; 2c164b0a
	v_mul_f32_e32 v15, v15, v39                                 ; 0a1e4f0f
	v_lshrrev_b32_e32 v31, 4, v31                               ; 203e3e84
	v_cvt_f32_ubyte3_e32 v45, v44                               ; 7e5a292c
	v_cvt_f32_ubyte2_e32 v46, v44                               ; 7e5c272c
	v_mac_f32_e32 v11, v9, v38                                  ; 2c164d09
	v_mac_f32_e32 v15, v14, v41                                 ; 2c1e530e
	v_and_b32_e32 v31, s5, v31                                  ; 263e3e05
	v_mul_f32_e32 v19, v19, v45                                 ; 0a265b13
	v_mac_f32_e32 v11, v8, v35                                  ; 2c164708
	v_mac_f32_e32 v15, v13, v42                                 ; 2c1e550d
	v_mac_f32_e32 v19, v18, v46                                 ; 2c265d12
	v_cvt_f32_ubyte1_e32 v46, v44                               ; 7e5c252c
	v_cvt_f32_ubyte0_e32 v44, v44                               ; 7e58232c
	v_mac_f32_e32 v15, v12, v32                                 ; 2c1e410c
	v_mac_f32_e32 v19, v17, v46                                 ; 2c265d11
	v_cvt_f32_ubyte3_e32 v46, v31                               ; 7e5c291f
	v_mac_f32_e32 v19, v16, v44                                 ; 2c265910
	v_mul_f32_e32 v23, v23, v46                                 ; 0a2e5d17
	v_cvt_f32_ubyte2_e32 v46, v31                               ; 7e5c271f
	v_mac_f32_e32 v23, v22, v46                                 ; 2c2e5d16
	v_cvt_f32_ubyte1_e32 v46, v31                               ; 7e5c251f
	v_cvt_f32_ubyte0_e32 v31, v31                               ; 7e3e231f
	v_mac_f32_e32 v23, v21, v46                                 ; 2c2e5d15
	v_mac_f32_e32 v23, v20, v31                                 ; 2c2e3f14
	v_mul_f32_e32 v23, v23, v30                                 ; 0a2e3d17
	v_mac_f32_e32 v23, v19, v43                                 ; 2c2e5713
	v_mac_f32_e32 v23, v15, v33                                 ; 2c2e430f
	v_mac_f32_e32 v23, v11, v24                                 ; 2c2e310b
	v_mac_f32_e32 v5, v40, v23                                  ; 2c0a2f28
BB5:
	s_mov_b64 s[0:1], exec                                      ; be80017e
	v_cmpx_le_u32_e32 vcc, s3, v0                               ; 7db60003
BB6:
	s_andn2_b64 s[0:1], s[0:1], exec                            ; 89807e00
	s_cbranch_scc1 BB10                                         ; bf85ff12
BB11:
	s_mov_b64 exec, -1                                          ; befe01c1
	s_or_saveexec_b64 s[4:5], -1                                ; be8421c1
	v_cndmask_b32_e64 v47, 0, v3, s[4:5]                        ; d100002f 00120680
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v47, v47, v47 quad_perm:[1,0,3,2] row_mask:0xf bank_mask:0xf ; 025e5efa ff00b12f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v47, v47, v47 quad_perm:[2,3,0,1] row_mask:0xf bank_mask:0xf ; 025e5efa ff004e2f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v47, v47, v47 row_half_mirror row_mask:0xf bank_mask:0xf ; 025e5efa ff01412f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v47, v47, v47 row_mirror row_mask:0xf bank_mask:0xf ; 025e5efa ff01402f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v47, v47, v47 row_bcast:15 row_mask:0xa bank_mask:0xf ; 025e5efa af01422f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v47, v47, v47 row_bcast:31 row_mask:0xc bank_mask:0xf ; 025e5efa cf01432f
	s_mov_b64 exec, s[4:5]                                      ; befe0104
	v_readlane_b32 s0, v47, 63                                  ; d2890000 00017f2f
	s_or_saveexec_b64 s[4:5], -1                                ; be8421c1
	v_cndmask_b32_e64 v47, 0, v5, s[4:5]                        ; d100002f 00120a80
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v47, v47, v47 quad_perm:[1,0,3,2] row_mask:0xf bank_mask:0xf ; 025e5efa ff00b12f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v47, v47, v47 quad_perm:[2,3,0,1] row_mask:0xf bank_mask:0xf ; 025e5efa ff004e2f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v47, v47, v47 row_half_mirror row_mask:0xf bank_mask:0xf ; 025e5efa ff01412f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v47, v47, v47 row_mirror row_mask:0xf bank_mask:0xf ; 025e5efa ff01402f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v47, v47, v47 row_bcast:15 row_mask:0xa bank_mask:0xf ; 025e5efa af01422f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v47, v47, v47 row_bcast:31 row_mask:0xc bank_mask:0xf ; 025e5efa cf01432f
	s_mov_b64 exec, 1                                           ; befe0181
	v_readlane_b32 s1, v47, 63                                  ; d2890001 00017f2f
BB12:
	s_bitcmp1_b32 s8, 0                                         ; bf0d8008
	s_cbranch_scc0 BB14                                         ; bf84000f
BB13:
	s_mov_b32 s4, s2                                            ; be840002
	s_movk_i32 s5, 0x8000                                       ; b0058000
	s_load_dwordx4 s[12:15], s[4:5], 0x30                       ; c00a0302 00000030
	s_mul_i32 s3, s7, s17                                       ; 92031107
	s_mov_b32 s4, src_scc                                       ; be8400fd
	s_add_u32 s3, s3, s16                                       ; 80031003
	s_lshl_b32 s3, s3, 2                                        ; 8e038203
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s3, s[12:15], s3                        ; c02000c6 00000003
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_mov_b32_e32 v0, s3                                        ; 7e000203
	v_add_f32_e32 v0, s0, v0                                    ; 02000000
	s_branch BB15                                               ; bf820002
BB14:
	s_mov_b32 s4, src_scc                                       ; be8400fd
	v_mov_b32_e32 v0, s0                                        ; 7e000200
BB15:
	s_bitcmp1_b32 s8, 1                                         ; bf0d8108
	s_cbranch_scc0 BB17                                         ; bf84000e
BB16:
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
	v_add_f32_e32 v0, s0, v0                                    ; 02000000
	s_branch BB18                                               ; bf820001
BB17:
	s_mov_b32 s3, src_scc                                       ; be8300fd
BB18:
	s_mov_b32 s0, s3                                            ; be800003
	s_movk_i32 s3, 0x8000                                       ; b0038000
	s_load_dwordx4 s[8:11], s[2:3], 0x20                        ; c00a0201 00000020
	s_mul_i32 s7, s7, s17                                       ; 92071107
	s_add_u32 s7, s7, s16                                       ; 80071007
	s_lshl_b32 s7, s7, 2                                        ; 8e078207
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_store_dword v0, off, s[8:11], s7                     ; e0700000 07020080
	s_cmp_lg_i32 s4, 0                                          ; bf018004
	s_cbranch_scc0 BB20                                         ; bf84000a
BB19:
	s_load_dwordx4 s[12:15], s[2:3], 0x30                       ; c00a0301 00000030
	s_add_u32 s4, s7, 4                                         ; 80048407
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s4, s[12:15], s4                        ; c0200106 00000004
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_mov_b32_e32 v0, s4                                        ; 7e000204
	v_add_f32_e32 v0, s1, v0                                    ; 02000001
	s_branch BB21                                               ; bf820001
BB20:
	v_mov_b32_e32 v0, s1                                        ; 7e000201
BB21:
	s_cmp_lg_i32 s0, 0                                          ; bf018000
	s_cbranch_scc0 BB24                                         ; bf840008
BB22:
	s_load_dwordx4 s[0:3], s[2:3], 0x40                         ; c00a0001 00000040
	s_add_u32 s4, s7, 4                                         ; 80048407
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s4, s[0:3], s4                          ; c0200100 00000004
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v0, s4, v0                                    ; 02000004
BB24:
	s_add_u32 s7, s7, 4                                         ; 80078407
	buffer_store_dword v0, off, s[8:11], s7                     ; e0700000 07020080
	s_branch BB77                                               ; bf8201db
BB30:
	s_cmp_lt_u32 s16, s4                                        ; bf0a0410
	s_cbranch_scc0 BB77                                         ; bf8401d9
BB31:
	s_sub_i32 s4, s4, s16                                       ; 81841004
	s_add_u32 s17, s17, s9                                      ; 80110911
	s_cmp_lg_i32 s17, 0                                         ; bf018011
	s_cbranch_scc0 BB33                                         ; bf840043
BB32:
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
	s_branch BB34                                               ; bf820001
BB33:
	s_mov_b32 s19, 0                                            ; be930080
BB34:
	s_lshr_b32 s5, s5, 8                                        ; 8f058805
	v_and_b32_e32 v1, 12, v0                                    ; 2602008c
	v_and_b32_e32 v2, 15, v0                                    ; 2604008f
	s_lshr_b32 s3, s3, 8                                        ; 8f038803
	v_lshrrev_b32_e32 v0, 4, v0                                 ; 20000084
	v_mov_b32_e32 v5, 0                                         ; 7e0a0280
	s_mul_i32 s19, s19, s5                                      ; 92130513
	v_sub_u32_e32 v1, v2, v1                                    ; 6a020302
	v_bfe_u32 v3, v2, 2, 1                                      ; d1c80003 02050502
	v_lshrrev_b32_e32 v2, 3, v2                                 ; 20040483
	v_lshl_add_u32 v1, v1, 1, v3                                ; d1fd0001 040d0301
	v_mov_b32_e32 v3, 0                                         ; 7e060280
	v_lshlrev_b32_e32 v1, 2, v1                                 ; 24020282
	v_lshl_add_u32 v4, v2, 5, v1                                ; d1fd0004 04050b02
	v_lshl_add_u32 v1, v2, 6, v1                                ; d1fd0001 04050d02
	v_lshlrev_b32_e32 v2, 4, v2                                 ; 24040484
	s_nop 0                                                     ; bf800000
	(then repeated 4 times)
BB35:
	s_mov_b64 s[0:1], exec                                      ; be80017e
	v_cmpx_le_u32_e32 vcc, s3, v0                               ; 7db60003
BB36:
	s_andn2_b64 s[0:1], s[0:1], exec                            ; 89807e00
	s_cbranch_scc0 BB47                                         ; bf8400f4
BB40:
	s_mov_b64 exec, s[0:1]                                      ; befe0100
	s_mov_b32 s0, s2                                            ; be800002
	s_movk_i32 s1, 0x8000                                       ; b0018000
	s_load_dwordx4 s[12:15], s[0:1], 0x10                       ; c00a0300 00000010
	s_mul_i32 s5, s6, s17                                       ; 92051106
	v_lshl_add_u32 v6, v0, 8, v1                                ; d1fd0006 04051100
	v_add_u32_e32 v7, s5, v6                                    ; 680e0c05
	v_add_u32_e32 v6, 0x80, v6                                  ; 680c0cff 00000080
	v_lshrrev_b32_e32 v7, 2, v7                                 ; 200e0e82
	v_add_u32_e32 v6, s5, v6                                    ; 680c0c05
	v_lshlrev_b32_e32 v7, 4, v7                                 ; 240e0e84
	v_lshrrev_b32_e32 v6, 2, v6                                 ; 200c0c82
	v_lshlrev_b32_e32 v6, 4, v6                                 ; 240c0c84
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_load_dwordx4 v[8:11], v7, s[12:15], 0 offen          ; e05c1000 80030807
	buffer_load_dwordx4 v[12:15], v7, s[12:15], 0 offen offset:128 ; e05c1080 80030c07
	buffer_load_dwordx4 v[16:19], v6, s[12:15], 0 offen         ; e05c1000 80031006
	buffer_load_dwordx4 v[20:23], v6, s[12:15], 0 offen offset:128 ; e05c1080 80031406
	s_cmp_lg_i32 s4, 0                                          ; bf018004
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_add_f32_e32 v24, v8, v9                                   ; 02301308
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_add_f32_e32 v25, v12, v13                                 ; 02321b0c
	v_add_f32_e32 v24, v24, v10                                 ; 02301518
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_add_f32_e32 v26, v16, v17                                 ; 02342310
	v_add_f32_e32 v25, v25, v14                                 ; 02321d19
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_add_f32_e32 v27, v20, v21                                 ; 02362b14
	v_add_f32_e32 v24, v24, v11                                 ; 02301718
	v_add_f32_e32 v26, v26, v18                                 ; 0234251a
	v_add_f32_e32 v25, v25, v15                                 ; 02321f19
	v_add_f32_e32 v27, v27, v22                                 ; 02362d1b
	v_add_f32_e32 v26, v26, v19                                 ; 0234271a
	v_add_f32_e32 v27, v27, v23                                 ; 02362f1b
	s_cbranch_scc0 BB46                                         ; bf8400c7
BB41:
	s_load_dwordx4 s[12:15], s[0:1], 0x0                        ; c00a0300 00000000
	s_mul_i32 s0, s16, s3                                       ; 92000310
	v_add_u32_e32 v30, 64, v4                                   ; 683c08c0
	s_add_u32 s0, s19, s0                                       ; 80000013
	v_add_u32_e32 v6, s0, v0                                    ; 680c0000
	v_lshlrev_b32_e32 v7, 4, v6                                 ; 240e0c84
	v_lshl_add_u32 v6, v6, 7, v7                                ; d1fd0006 041d0f06
	v_add_u32_e32 v28, 16, v6                                   ; 68380c90
	v_add_u32_e32 v29, v28, v4                                  ; 683a091c
	v_add_u32_e32 v28, v28, v30                                 ; 68383d1c
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_load_dwordx4 v[32:35], v6, s[12:15], 0 offen         ; e05c1000 80032006
	buffer_load_dword v29, v29, s[12:15], 0 offen               ; e0501000 80031d1d
	buffer_load_dword v28, v28, s[12:15], 0 offen               ; e0501000 80031c1c
	s_bitreplicate_b64_b32 vcc, 0xf0f0f0f                       ; beea37ff 0f0f0f0f
	s_mov_b32 s1, 0xf0f0f0f                                     ; be8100ff 0f0f0f0f
	s_cmp_lt_u32 1, s4                                          ; bf0a0481
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_bfe_u32 v35, v35, v2, 16                                  ; d1c80023 02420523
	v_cndmask_b32_sdwa v31, v33, v33, vcc dst_sel:WORD_0 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 003e42f9 06051421
	v_cndmask_b32_sdwa v31, v34, v34, vcc dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 003e44f9 06051522
	v_lshl_or_b32 v35, v35, 12, v35                             ; d2000023 048d1923
	v_and_b32_e32 v33, 0xc0c0c0c0, v31                          ; 26423eff c0c0c0c0
	v_and_b32_e32 v31, 0x3f3f3f3f, v31                          ; 263e3eff 3f3f3f3f
	v_cvt_f32_f16_sdwa v41, v32 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e5216f9 00050620
	v_lshrrev_b32_e32 v33, 2, v33                               ; 20424282
	v_cvt_f32_f16_e32 v32, v32                                  ; 7e401720
	v_cvt_f32_ubyte1_e32 v40, v31                               ; 7e50251f
	v_cvt_f32_ubyte3_e32 v37, v31                               ; 7e4a291f
	v_cvt_f32_ubyte2_e32 v38, v31                               ; 7e4c271f
	v_cvt_f32_ubyte0_e32 v31, v31                               ; 7e3e231f
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v42, s1, v29                                  ; 26543a01
	v_and_or_b32 v35, s1, v35, v33                              ; d2010023 04864601
	v_cvt_f32_ubyte1_e32 v45, v42                               ; 7e5a252a
	v_cvt_f32_ubyte3_e32 v43, v42                               ; 7e56292a
	v_cvt_f32_ubyte2_e32 v44, v42                               ; 7e58272a
	v_cvt_f32_ubyte0_e32 v42, v42                               ; 7e54232a
	v_cvt_f32_ubyte1_e32 v39, v35                               ; 7e4e2523
	v_cvt_f32_ubyte3_e32 v34, v35                               ; 7e442923
	v_cvt_f32_ubyte2_e32 v36, v35                               ; 7e482723
	v_cvt_f32_ubyte0_e32 v35, v35                               ; 7e462323
	v_lshrrev_b32_e32 v29, 4, v29                               ; 203a3a84
	v_mul_f32_e32 v43, v11, v43                                 ; 0a56570b
	v_mul_f32_e32 v34, v27, v34                                 ; 0a44451b
	v_and_b32_e32 v29, s1, v29                                  ; 263a3a01
	v_mac_f32_e32 v43, v10, v44                                 ; 2c56590a
	v_mac_f32_e32 v34, v26, v36                                 ; 2c44491a
	v_cvt_f32_ubyte1_e32 v7, v29                                ; 7e0e251d
	v_cvt_f32_ubyte3_e32 v46, v29                               ; 7e5c291d
	v_cvt_f32_ubyte2_e32 v6, v29                                ; 7e0c271d
	v_cvt_f32_ubyte0_e32 v29, v29                               ; 7e3a231d
	v_mac_f32_e32 v43, v9, v45                                  ; 2c565b09
	v_mac_f32_e32 v34, v25, v37                                 ; 2c444b19
	v_mul_f32_e32 v46, v15, v46                                 ; 0a5c5d0f
	v_mac_f32_e32 v43, v8, v42                                  ; 2c565508
	v_mac_f32_e32 v34, v24, v38                                 ; 2c444d18
	v_mac_f32_e32 v46, v14, v6                                  ; 2c5c0d0e
	v_mad_f32 v3, -v41, v34, v3                                 ; d1c10003 240e4529
	v_mac_f32_e32 v46, v13, v7                                  ; 2c5c0f0d
	v_mac_f32_e32 v46, v12, v29                                 ; 2c5c3b0c
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v29, s1, v28                                  ; 263a3801
	v_lshrrev_b32_e32 v28, 4, v28                               ; 20383884
	v_cvt_f32_ubyte2_e32 v34, v29                               ; 7e44271d
	v_cvt_f32_ubyte1_e32 v36, v29                               ; 7e48251d
	v_cvt_f32_ubyte3_e32 v33, v29                               ; 7e42291d
	v_cvt_f32_ubyte0_e32 v29, v29                               ; 7e3a231d
	v_and_b32_e32 v28, s1, v28                                  ; 26383801
	v_mul_f32_e32 v33, v19, v33                                 ; 0a424313
	v_cvt_f32_ubyte1_e32 v41, v28                               ; 7e52251c
	v_cvt_f32_ubyte2_e32 v38, v28                               ; 7e4c271c
	v_cvt_f32_ubyte3_e32 v37, v28                               ; 7e4a291c
	v_cvt_f32_ubyte0_e32 v28, v28                               ; 7e38231c
	v_mac_f32_e32 v33, v18, v34                                 ; 2c424512
	v_mul_f32_e32 v37, v23, v37                                 ; 0a4a4b17
	v_mac_f32_e32 v33, v17, v36                                 ; 2c424911
	v_mac_f32_e32 v37, v22, v38                                 ; 2c4a4d16
	v_mac_f32_e32 v33, v16, v29                                 ; 2c423b10
	v_mac_f32_e32 v37, v21, v41                                 ; 2c4a5315
	v_mac_f32_e32 v37, v20, v28                                 ; 2c4a3914
	v_mul_f32_e32 v37, v37, v39                                 ; 0a4a4f25
	v_mac_f32_e32 v37, v33, v35                                 ; 2c4a4721
	v_mac_f32_e32 v37, v46, v40                                 ; 2c4a512e
	v_mac_f32_e32 v37, v43, v31                                 ; 2c4a3f2b
	v_mac_f32_e32 v3, v32, v37                                  ; 2c064b20
	s_cbranch_scc0 BB46                                         ; bf840060
BB42:
	s_add_u32 s0, s16, 1                                        ; 80008110
	s_mul_i32 s0, s0, s3                                        ; 92000300
	s_add_u32 s0, s19, s0                                       ; 80000013
	v_add_u32_e32 v6, s0, v0                                    ; 680c0000
	v_lshlrev_b32_e32 v7, 4, v6                                 ; 240e0c84
	v_lshl_add_u32 v6, v6, 7, v7                                ; d1fd0006 041d0f06
	v_add_u32_e32 v28, 16, v6                                   ; 68380c90
	v_add_u32_e32 v29, v28, v4                                  ; 683a091c
	v_add_u32_e32 v28, v28, v30                                 ; 68383d1c
	buffer_load_dwordx4 v[32:35], v6, s[12:15], 0 offen         ; e05c1000 80032006
	buffer_load_dword v29, v29, s[12:15], 0 offen               ; e0501000 80031d1d
	buffer_load_dword v28, v28, s[12:15], 0 offen               ; e0501000 80031c1c
	s_mov_b32 s1, 0xf0f0f0f                                     ; be8100ff 0f0f0f0f
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_bfe_u32 v35, v35, v2, 16                                  ; d1c80023 02420523
	v_cndmask_b32_sdwa v30, v33, v33, vcc dst_sel:WORD_0 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 003c42f9 06051421
	v_cndmask_b32_sdwa v30, v34, v34, vcc dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 003c44f9 06051522
	v_lshl_or_b32 v35, v35, 12, v35                             ; d2000023 048d1923
	v_and_b32_e32 v31, 0xc0c0c0c0, v30                          ; 263e3cff c0c0c0c0
	v_and_b32_e32 v30, 0x3f3f3f3f, v30                          ; 263c3cff 3f3f3f3f
	v_cvt_f32_f16_sdwa v40, v32 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e5016f9 00050620
	v_lshrrev_b32_e32 v31, 2, v31                               ; 203e3e82
	v_cvt_f32_f16_e32 v32, v32                                  ; 7e401720
	v_cvt_f32_ubyte3_e32 v36, v30                               ; 7e48291e
	v_cvt_f32_ubyte2_e32 v37, v30                               ; 7e4a271e
	v_cvt_f32_ubyte1_e32 v39, v30                               ; 7e4e251e
	v_cvt_f32_ubyte0_e32 v30, v30                               ; 7e3c231e
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v41, s1, v29                                  ; 26523a01
	v_and_or_b32 v35, s1, v35, v31                              ; d2010023 047e4601
	v_cvt_f32_ubyte1_e32 v44, v41                               ; 7e582529
	v_cvt_f32_ubyte3_e32 v42, v41                               ; 7e542929
	v_cvt_f32_ubyte2_e32 v43, v41                               ; 7e562729
	v_cvt_f32_ubyte0_e32 v41, v41                               ; 7e522329
	v_cvt_f32_ubyte3_e32 v33, v35                               ; 7e422923
	v_cvt_f32_ubyte2_e32 v34, v35                               ; 7e442723
	v_cvt_f32_ubyte1_e32 v38, v35                               ; 7e4c2523
	v_cvt_f32_ubyte0_e32 v35, v35                               ; 7e462323
	v_lshrrev_b32_e32 v29, 4, v29                               ; 203a3a84
	v_mul_f32_e32 v11, v11, v42                                 ; 0a16550b
	v_mul_f32_e32 v27, v27, v33                                 ; 0a36431b
	v_and_b32_e32 v29, s1, v29                                  ; 263a3a01
	v_mac_f32_e32 v11, v10, v43                                 ; 2c16570a
	v_mac_f32_e32 v27, v26, v34                                 ; 2c36451a
	v_cvt_f32_ubyte3_e32 v45, v29                               ; 7e5a291d
	v_cvt_f32_ubyte2_e32 v46, v29                               ; 7e5c271d
	v_mac_f32_e32 v11, v9, v44                                  ; 2c165909
	v_mac_f32_e32 v27, v25, v36                                 ; 2c364919
	v_mul_f32_e32 v15, v15, v45                                 ; 0a1e5b0f
	v_mac_f32_e32 v11, v8, v41                                  ; 2c165308
	v_mac_f32_e32 v27, v24, v37                                 ; 2c364b18
	v_mac_f32_e32 v15, v14, v46                                 ; 2c1e5d0e
	v_cvt_f32_ubyte1_e32 v46, v29                               ; 7e5c251d
	v_cvt_f32_ubyte0_e32 v29, v29                               ; 7e3a231d
	v_mad_f32 v5, -v40, v27, v5                                 ; d1c10005 24163728
	v_mac_f32_e32 v15, v13, v46                                 ; 2c1e5d0d
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v46, s1, v28                                  ; 265c3801
	v_lshrrev_b32_e32 v28, 4, v28                               ; 20383884
	v_mac_f32_e32 v15, v12, v29                                 ; 2c1e3b0c
	v_cvt_f32_ubyte1_e32 v8, v46                                ; 7e10252e
	v_cvt_f32_ubyte2_e32 v7, v46                                ; 7e0e272e
	v_cvt_f32_ubyte3_e32 v6, v46                                ; 7e0c292e
	v_cvt_f32_ubyte0_e32 v46, v46                               ; 7e5c232e
	v_and_b32_e32 v28, s1, v28                                  ; 26383801
	v_mul_f32_e32 v19, v19, v6                                  ; 0a260d13
	v_cvt_f32_ubyte2_e32 v10, v28                               ; 7e14271c
	v_cvt_f32_ubyte1_e32 v12, v28                               ; 7e18251c
	v_cvt_f32_ubyte3_e32 v9, v28                                ; 7e12291c
	v_cvt_f32_ubyte0_e32 v28, v28                               ; 7e38231c
	v_mac_f32_e32 v19, v18, v7                                  ; 2c260f12
	v_mul_f32_e32 v23, v23, v9                                  ; 0a2e1317
	v_mac_f32_e32 v19, v17, v8                                  ; 2c261111
	v_mac_f32_e32 v23, v22, v10                                 ; 2c2e1516
	v_mac_f32_e32 v19, v16, v46                                 ; 2c265d10
	v_mac_f32_e32 v23, v21, v12                                 ; 2c2e1915
	v_mac_f32_e32 v23, v20, v28                                 ; 2c2e3914
	v_mul_f32_e32 v23, v23, v38                                 ; 0a2e4d17
	v_mac_f32_e32 v23, v19, v35                                 ; 2c2e4713
	v_mac_f32_e32 v23, v15, v39                                 ; 2c2e4f0f
	v_mac_f32_e32 v23, v11, v30                                 ; 2c2e3d0b
	v_mac_f32_e32 v5, v32, v23                                  ; 2c0a2f20
BB46:
	v_add_u32_e32 v0, 4, v0                                     ; 68000084
	s_branch BB35                                               ; bf82ff08
BB47:
	s_mov_b64 exec, -1                                          ; befe01c1
	s_cmp_lg_i32 s4, 0                                          ; bf018004
	s_cselect_b64 s[0:1], -1, 0                                 ; 858080c1
	s_cbranch_scc0 BB53                                         ; bf840034
BB48:
	s_or_saveexec_b64 s[10:11], -1                              ; be8a21c1
	s_cmp_lt_u32 1, s4                                          ; bf0a0481
	v_cndmask_b32_e64 v47, 0, v3, s[10:11]                      ; d100002f 002a0680
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v47, v47, v47 quad_perm:[1,0,3,2] row_mask:0xf bank_mask:0xf ; 025e5efa ff00b12f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v47, v47, v47 quad_perm:[2,3,0,1] row_mask:0xf bank_mask:0xf ; 025e5efa ff004e2f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v47, v47, v47 row_half_mirror row_mask:0xf bank_mask:0xf ; 025e5efa ff01412f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v47, v47, v47 row_mirror row_mask:0xf bank_mask:0xf ; 025e5efa ff01402f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v47, v47, v47 row_bcast:15 row_mask:0xa bank_mask:0xf ; 025e5efa af01422f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v47, v47, v47 row_bcast:31 row_mask:0xc bank_mask:0xf ; 025e5efa cf01432f
	s_mov_b64 exec, s[10:11]                                    ; befe010a
	v_readlane_b32 s3, v47, 63                                  ; d2890003 00017f2f
	s_cbranch_scc0 BB51                                         ; bf840019
BB49:
	s_or_saveexec_b64 s[10:11], -1                              ; be8a21c1
	v_cndmask_b32_e64 v47, 0, v5, s[10:11]                      ; d100002f 002a0a80
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v47, v47, v47 quad_perm:[1,0,3,2] row_mask:0xf bank_mask:0xf ; 025e5efa ff00b12f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v47, v47, v47 quad_perm:[2,3,0,1] row_mask:0xf bank_mask:0xf ; 025e5efa ff004e2f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v47, v47, v47 row_half_mirror row_mask:0xf bank_mask:0xf ; 025e5efa ff01412f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v47, v47, v47 row_mirror row_mask:0xf bank_mask:0xf ; 025e5efa ff01402f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v47, v47, v47 row_bcast:15 row_mask:0xa bank_mask:0xf ; 025e5efa af01422f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v47, v47, v47 row_bcast:31 row_mask:0xc bank_mask:0xf ; 025e5efa cf01432f
	s_mov_b64 exec, s[10:11]                                    ; befe010a
	v_readlane_b32 s5, v47, 63                                  ; d2890005 00017f2f
	v_mov_b32_e32 v5, s5                                        ; 7e0a0205
BB51:
	v_mov_b32_e32 v3, s3                                        ; 7e060203
BB53:
	s_mov_b64 s[10:11], 1                                       ; be8a0181
	s_and_b64 exec, s[0:1], s[10:11]                            ; 86fe0a00
	s_cbranch_execz BB77                                        ; bf880045
BB54:
	s_bitcmp1_b32 s8, 0                                         ; bf0d8008
	s_cbranch_scc0 BB56                                         ; bf84000e
BB55:
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
	s_branch BB57                                               ; bf820001
BB56:
	s_mov_b32 s1, src_scc                                       ; be8100fd
BB57:
	s_bitcmp1_b32 s8, 1                                         ; bf0d8108
	s_cbranch_scc0 BB59                                         ; bf84000e
BB58:
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
	s_branch BB60                                               ; bf820001
BB59:
	s_mov_b32 s3, src_scc                                       ; be8300fd
BB60:
	s_mov_b32 s0, s3                                            ; be800003
	s_movk_i32 s3, 0x8000                                       ; b0038000
	s_load_dwordx4 s[8:11], s[2:3], 0x20                        ; c00a0201 00000020
	s_mul_i32 s7, s7, s17                                       ; 92071107
	s_add_u32 s7, s7, s16                                       ; 80071007
	s_lshl_b32 s7, s7, 2                                        ; 8e078207
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_store_dword v3, off, s[8:11], s7                     ; e0700000 07020380
	s_cmp_lt_u32 1, s4                                          ; bf0a0481
	s_cbranch_scc0 BB77                                         ; bf840017
BB61:
	s_cmp_lg_i32 s1, 0                                          ; bf018001
	s_cbranch_scc0 BB64                                         ; bf840008
BB62:
	s_load_dwordx4 s[12:15], s[2:3], 0x30                       ; c00a0301 00000030
	s_add_u32 s1, s7, 4                                         ; 80018407
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s1, s[12:15], s1                        ; c0200046 00000001
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v5, s1, v5                                    ; 020a0a01
BB64:
	s_cmp_lg_i32 s0, 0                                          ; bf018000
	s_cbranch_scc0 BB67                                         ; bf840008
BB65:
	s_load_dwordx4 s[0:3], s[2:3], 0x40                         ; c00a0001 00000040
	s_add_u32 s4, s7, 4                                         ; 80048407
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s4, s[0:3], s4                          ; c0200100 00000004
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v5, s4, v5                                    ; 020a0a04
BB67:
	s_add_u32 s7, s7, 4                                         ; 80078407
	buffer_store_dword v5, off, s[8:11], s7                     ; e0700000 07020580
BB77:
	s_endpgm                                                    ; bf810000
