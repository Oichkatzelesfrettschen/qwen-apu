BB0:
	s_load_dword s0, s[14:15], 0x0                              ; c0020007 00000000
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_mul_i32 s0, s0, s18                                       ; 92001200
	s_add_u32 s16, s16, s0                                      ; 80100010
	s_lshl_b32 s16, s16, 2                                      ; 8e108210
	s_add_u32 s1, s16, 4                                        ; 80018410
	s_cmp_ge_u32 s4, s1                                         ; bf090104
	s_cbranch_scc0 BB48                                         ; bf84031c
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
	s_mul_i32 s18, s18, s5                                      ; 92120512
	v_sub_u32_e32 v1, v2, v1                                    ; 6a020302
	v_bfe_u32 v3, v2, 2, 1                                      ; d1c80003 02050502
	v_lshrrev_b32_e32 v2, 3, v2                                 ; 20040483
	v_lshl_add_u32 v1, v1, 1, v3                                ; d1fd0001 040d0301
	v_lshlrev_b32_e32 v1, 2, v1                                 ; 24020282
	v_lshl_add_u32 v4, v2, 5, v1                                ; d1fd0004 04050b02
	v_lshl_add_u32 v1, v2, 6, v1                                ; d1fd0001 04050d02
	v_cmpx_gt_u32_e32 vcc, s3, v0                               ; 7db80003
	s_cbranch_execz BB15                                        ; bf8801d5
BB5:
	s_mov_b32 s0, s2                                            ; be800002
	s_movk_i32 s1, 0x8000                                       ; b0018000
	s_load_dwordx8 s[24:31], s[0:1], 0x0                        ; c00e0600 00000000
	s_mul_i32 s0, s16, s3                                       ; 92000310
	s_mul_i32 s6, s6, s17                                       ; 92061106
	v_lshlrev_b32_e32 v2, 4, v2                                 ; 24040484
	v_add_u32_e32 v3, 64, v4                                    ; 680608c0
	s_bitreplicate_b64_b32 vcc, 0xf0f0f0f                       ; beea37ff 0f0f0f0f
	s_mov_b64 s[10:11], exec                                    ; be8a017e
	v_mov_b32_e32 v5, 0                                         ; 7e0a0280
	s_add_u32 s0, s18, s0                                       ; 80000012
	s_add_u32 s1, s16, 1                                        ; 80018110
	v_mov_b32_e32 v6, 0                                         ; 7e0c0280
	v_mov_b32_e32 v7, 0                                         ; 7e0e0280
	v_mov_b32_e32 v8, 0                                         ; 7e100280
	s_mul_i32 s1, s1, s3                                        ; 92010301
	s_add_u32 s1, s18, s1                                       ; 80010112
	s_add_u32 s4, s16, 2                                        ; 80048210
	s_mul_i32 s4, s4, s3                                        ; 92040304
	s_add_u32 s4, s18, s4                                       ; 80040412
	s_add_u32 s5, s16, 3                                        ; 80058310
	s_mul_i32 s5, s5, s3                                        ; 92050305
	s_add_u32 s18, s18, s5                                      ; 80120512
	s_nop 0                                                     ; bf800000
	(then repeated 3 times)
BB6:
	v_add_u32_e32 v9, s0, v0                                    ; 68120000
	v_lshlrev_b32_e32 v10, 4, v9                                ; 24141284
	v_lshl_add_u32 v9, v9, 7, v10                               ; d1fd0009 04290f09
	v_add_u32_e32 v11, 16, v9                                   ; 68161290
	v_add_u32_e32 v12, v11, v4                                  ; 6818090b
	v_add_u32_e32 v11, v11, v3                                  ; 6816070b
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_load_dwordx4 v[16:19], v9, s[24:27], 0 offen         ; e05c1000 80061009
	buffer_load_dword v12, v12, s[24:27], 0 offen               ; e0501000 80060c0c
	buffer_load_dword v11, v11, s[24:27], 0 offen               ; e0501000 80060b0b
	v_lshl_add_u32 v13, v0, 8, v1                               ; d1fd000d 04051100
	v_add_u32_e32 v14, s6, v13                                  ; 681c1a06
	v_add_u32_e32 v13, 0x80, v13                                ; 681a1aff 00000080
	v_lshrrev_b32_e32 v14, 2, v14                               ; 201c1c82
	v_add_u32_e32 v13, s6, v13                                  ; 681a1a06
	v_lshlrev_b32_e32 v14, 4, v14                               ; 241c1c84
	v_lshrrev_b32_e32 v13, 2, v13                               ; 201a1a82
	v_lshlrev_b32_e32 v13, 4, v13                               ; 241a1a84
	buffer_load_dwordx4 v[20:23], v14, s[28:31], 0 offen        ; e05c1000 8007140e
	buffer_load_dwordx4 v[24:27], v14, s[28:31], 0 offen offset:128 ; e05c1080 8007180e
	buffer_load_dwordx4 v[28:31], v13, s[28:31], 0 offen        ; e05c1000 80071c0d
	buffer_load_dwordx4 v[32:35], v13, s[28:31], 0 offen offset:128 ; e05c1080 8007200d
	v_add_u32_e32 v15, s1, v0                                   ; 681e0001
	v_lshlrev_b32_e32 v36, 4, v15                               ; 24481e84
	v_lshl_add_u32 v15, v15, 7, v36                             ; d1fd000f 04910f0f
	v_add_u32_e32 v37, 16, v15                                  ; 684a1e90
	v_add_u32_e32 v38, v37, v4                                  ; 684c0925
	v_add_u32_e32 v37, v37, v3                                  ; 684a0725
	buffer_load_dwordx4 v[40:43], v15, s[24:27], 0 offen        ; e05c1000 8006280f
	buffer_load_dword v38, v38, s[24:27], 0 offen               ; e0501000 80062626
	buffer_load_dword v37, v37, s[24:27], 0 offen               ; e0501000 80062525
	s_mov_b32 s5, 0xf0f0f0f                                     ; be8500ff 0f0f0f0f
	s_mov_b32 s9, 0xc0c0c0c0                                    ; be8900ff c0c0c0c0
	s_mov_b32 s12, 0x3f3f3f3f                                   ; be8c00ff 3f3f3f3f
	v_add_u32_e32 v39, s4, v0                                   ; 684e0004
	v_lshlrev_b32_e32 v44, 4, v39                               ; 24584e84
	v_lshl_add_u32 v39, v39, 7, v44                             ; d1fd0027 04b10f27
	s_waitcnt vmcnt(9)                                          ; bf8c3f79
	v_bfe_u32 v19, v19, v2, 16                                  ; d1c80013 02420513
	v_cndmask_b32_sdwa v45, v17, v17, vcc dst_sel:WORD_0 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 005a22f9 06051411
	v_cndmask_b32_sdwa v45, v18, v18, vcc dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 005a24f9 06051512
	s_waitcnt vmcnt(8)                                          ; bf8c3f78
	v_and_b32_e32 v14, s5, v12                                  ; 261c1805
	v_lshrrev_b32_e32 v12, 4, v12                               ; 20181884
	v_lshl_or_b32 v19, v19, 12, v19                             ; d2000013 044d1913
	v_and_b32_e32 v46, s9, v45                                  ; 265c5a09
	v_and_b32_e32 v45, s12, v45                                 ; 265a5a0c
	v_cvt_f32_ubyte3_e32 v15, v14                               ; 7e1e290e
	v_cvt_f32_ubyte2_e32 v17, v14                               ; 7e22270e
	v_cvt_f32_ubyte1_e32 v18, v14                               ; 7e24250e
	v_cvt_f32_ubyte0_e32 v14, v14                               ; 7e1c230e
	v_and_b32_e32 v12, s5, v12                                  ; 26181805
	v_lshrrev_b32_e32 v46, 2, v46                               ; 205c5c82
	v_cvt_f32_ubyte3_e32 v10, v45                               ; 7e14292d
	v_cvt_f32_ubyte2_e32 v13, v45                               ; 7e1a272d
	s_waitcnt vmcnt(6)                                          ; bf8c3f76
	v_mul_f32_e32 v15, v23, v15                                 ; 0a1e1f17
	v_cvt_f32_ubyte2_e32 v44, v12                               ; 7e58270c
	v_cvt_f32_ubyte3_e32 v36, v12                               ; 7e48290c
	v_and_or_b32 v19, s5, v19, v46                              ; d2010013 04ba2605
	v_mac_f32_e32 v15, v22, v17                                 ; 2c1e2316
	v_and_b32_e32 v17, s5, v11                                  ; 26221605
	s_waitcnt vmcnt(5)                                          ; bf8c3f75
	v_mul_f32_e32 v36, v27, v36                                 ; 0a48491b
	v_cvt_f32_ubyte2_e32 v9, v19                                ; 7e122713
	v_cvt_f32_ubyte3_e32 v46, v19                               ; 7e5c2913
	v_mac_f32_e32 v15, v21, v18                                 ; 2c1e2515
	v_cvt_f32_ubyte3_e32 v18, v17                               ; 7e242911
	v_mac_f32_e32 v36, v26, v44                                 ; 2c48591a
	v_cvt_f32_ubyte2_e32 v44, v17                               ; 7e582711
	v_lshrrev_b32_e32 v11, 4, v11                               ; 20161684
	v_mac_f32_e32 v15, v20, v14                                 ; 2c1e1d14
	v_cvt_f32_ubyte1_e32 v14, v12                               ; 7e1c250c
	v_cvt_f32_ubyte0_e32 v12, v12                               ; 7e18230c
	s_waitcnt vmcnt(4)                                          ; bf8c3f74
	v_mul_f32_e32 v18, v31, v18                                 ; 0a24251f
	v_and_b32_e32 v11, s5, v11                                  ; 26161605
	v_mac_f32_e32 v36, v25, v14                                 ; 2c481d19
	v_mac_f32_e32 v18, v30, v44                                 ; 2c24591e
	v_cvt_f32_ubyte3_e32 v14, v11                               ; 7e1c290b
	v_cvt_f32_ubyte1_e32 v44, v11                               ; 7e58250b
	v_mac_f32_e32 v36, v24, v12                                 ; 2c481918
	v_cvt_f32_ubyte1_e32 v12, v17                               ; 7e182511
	v_cvt_f32_ubyte0_e32 v17, v17                               ; 7e222311
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_mul_f32_e32 v14, v35, v14                                 ; 0a1c1d23
	v_mac_f32_e32 v18, v29, v12                                 ; 2c24191d
	v_mac_f32_e32 v18, v28, v17                                 ; 2c24231c
	v_cvt_f32_ubyte2_e32 v17, v11                               ; 7e22270b
	v_cvt_f32_ubyte0_e32 v11, v11                               ; 7e16230b
	v_mac_f32_e32 v14, v34, v17                                 ; 2c1c2322
	v_mac_f32_e32 v14, v33, v44                                 ; 2c1c5921
	v_mac_f32_e32 v14, v32, v11                                 ; 2c1c1720
	v_mul_f32_e32 v11, v35, v46                                 ; 0a165d23
	v_mac_f32_e32 v11, v31, v9                                  ; 2c16131f
	v_mac_f32_e32 v11, v27, v10                                 ; 2c16151b
	v_mac_f32_e32 v11, v23, v13                                 ; 2c161b17
	v_mac_f32_e32 v11, v34, v46                                 ; 2c165d22
	v_mac_f32_e32 v11, v30, v9                                  ; 2c16131e
	v_mac_f32_e32 v11, v26, v10                                 ; 2c16151a
	v_mac_f32_e32 v11, v22, v13                                 ; 2c161b16
	v_mac_f32_e32 v11, v33, v46                                 ; 2c165d21
	v_mac_f32_e32 v11, v29, v9                                  ; 2c16131d
	v_mac_f32_e32 v11, v25, v10                                 ; 2c161519
	v_mac_f32_e32 v11, v21, v13                                 ; 2c161b15
	v_mac_f32_e32 v11, v32, v46                                 ; 2c165d20
	v_mac_f32_e32 v11, v28, v9                                  ; 2c16131c
	v_mac_f32_e32 v11, v24, v10                                 ; 2c161518
	v_mov_b32_e32 v17, v11                                      ; 7e22030b
	buffer_load_dwordx4 v[9:12], v39, s[24:27], 0 offen         ; e05c1000 80060927
	v_add_u32_e32 v39, 16, v39                                  ; 684e4e90
	v_add_u32_e32 v46, v39, v4                                  ; 685c0927
	v_add_u32_e32 v39, v39, v3                                  ; 684e0727
	buffer_load_dword v46, v46, s[24:27], 0 offen               ; e0501000 80062e2e
	buffer_load_dword v39, v39, s[24:27], 0 offen               ; e0501000 80062727
	v_cvt_f32_ubyte1_e32 v44, v19                               ; 7e582513
	v_cvt_f32_ubyte0_e32 v19, v19                               ; 7e262313
	v_mac_f32_e32 v17, v20, v13                                 ; 2c221b14
	v_cvt_f32_ubyte1_e32 v13, v45                               ; 7e1a252d
	v_cvt_f32_ubyte0_e32 v45, v45                               ; 7e5a232d
	s_waitcnt vmcnt(5)                                          ; bf8c3f75
	v_bfe_u32 v43, v43, v2, 16                                  ; d1c8002b 0242052b
	v_mul_f32_e32 v14, v14, v44                                 ; 0a1c590e
	v_lshl_or_b32 v43, v43, 12, v43                             ; d200002b 04ad192b
	v_mac_f32_e32 v14, v18, v19                                 ; 2c1c2712
	v_cndmask_b32_sdwa v18, v41, v41, vcc dst_sel:WORD_0 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 002452f9 06051429
	v_cndmask_b32_sdwa v18, v42, v42, vcc dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 002454f9 0605152a
	v_mac_f32_e32 v14, v36, v13                                 ; 2c1c1b24
	v_and_b32_e32 v19, s9, v18                                  ; 26262409
	v_and_b32_e32 v18, s12, v18                                 ; 2624240c
	v_mac_f32_e32 v14, v15, v45                                 ; 2c1c5b0f
	v_cvt_f32_f16_sdwa v15, v16 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e1e16f9 00050610
	v_cvt_f32_f16_e32 v16, v16                                  ; 7e201710
	v_lshrrev_b32_e32 v19, 2, v19                               ; 20262682
	s_waitcnt vmcnt(4)                                          ; bf8c3f74
	v_and_b32_e32 v45, s5, v38                                  ; 265a4c05
	v_cvt_f32_ubyte3_e32 v44, v18                               ; 7e582912
	v_mad_f32 v5, -v15, v17, v5                                 ; d1c10005 2416230f
	v_and_or_b32 v43, s5, v43, v19                              ; d201002b 044e5605
	v_cvt_f32_ubyte1_e32 v15, v45                               ; 7e1e252d
	v_cvt_f32_ubyte3_e32 v13, v45                               ; 7e1a292d
	v_mac_f32_e32 v5, v16, v14                                  ; 2c0a1d10
	v_add_u32_e32 v16, s18, v0                                  ; 68200012
	v_cvt_f32_ubyte2_e32 v14, v45                               ; 7e1c272d
	v_cvt_f32_ubyte0_e32 v45, v45                               ; 7e5a232d
	v_cvt_f32_ubyte3_e32 v36, v43                               ; 7e48292b
	v_cvt_f32_ubyte2_e32 v42, v43                               ; 7e54272b
	v_lshrrev_b32_e32 v38, 4, v38                               ; 204c4c84
	v_mul_f32_e32 v13, v23, v13                                 ; 0a1a1b17
	v_lshlrev_b32_e32 v17, 4, v16                               ; 24222084
	v_mul_f32_e32 v41, v35, v36                                 ; 0a524923
	v_and_b32_e32 v38, s5, v38                                  ; 264c4c05
	v_mac_f32_e32 v13, v22, v14                                 ; 2c1a1d16
	v_lshl_add_u32 v16, v16, 7, v17                             ; d1fd0010 04450f10
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_and_b32_e32 v14, s5, v37                                  ; 261c4a05
	v_mac_f32_e32 v41, v31, v42                                 ; 2c52551f
	v_cvt_f32_ubyte2_e32 v19, v38                               ; 7e262726
	v_cvt_f32_ubyte3_e32 v17, v38                               ; 7e222926
	v_mac_f32_e32 v13, v21, v15                                 ; 2c1a1f15
	v_cvt_f32_ubyte3_e32 v15, v14                               ; 7e1e290e
	v_mac_f32_e32 v41, v27, v44                                 ; 2c52591b
	v_mul_f32_e32 v17, v27, v17                                 ; 0a22231b
	v_lshrrev_b32_e32 v37, 4, v37                               ; 204a4a84
	v_mac_f32_e32 v13, v20, v45                                 ; 2c1a5b14
	v_cvt_f32_ubyte1_e32 v45, v38                               ; 7e5a2526
	v_cvt_f32_ubyte0_e32 v38, v38                               ; 7e4c2326
	v_mul_f32_e32 v15, v31, v15                                 ; 0a1e1f1f
	v_mac_f32_e32 v17, v26, v19                                 ; 2c22271a
	v_cvt_f32_ubyte2_e32 v19, v14                               ; 7e26270e
	v_and_b32_e32 v37, s5, v37                                  ; 264a4a05
	v_mac_f32_e32 v17, v25, v45                                 ; 2c225b19
	v_mac_f32_e32 v15, v30, v19                                 ; 2c1e271e
	v_cvt_f32_ubyte1_e32 v19, v37                               ; 7e262525
	v_cvt_f32_ubyte3_e32 v45, v37                               ; 7e5a2925
	v_mac_f32_e32 v17, v24, v38                                 ; 2c224d18
	v_cvt_f32_ubyte1_e32 v38, v14                               ; 7e4c250e
	v_cvt_f32_ubyte0_e32 v14, v14                               ; 7e1c230e
	v_mul_f32_e32 v45, v35, v45                                 ; 0a5a5b23
	v_mac_f32_e32 v15, v29, v38                                 ; 2c1e4d1d
	v_mac_f32_e32 v15, v28, v14                                 ; 2c1e1d1c
	v_cvt_f32_ubyte2_e32 v14, v37                               ; 7e1c2725
	v_cvt_f32_ubyte0_e32 v37, v37                               ; 7e4a2325
	v_mac_f32_e32 v45, v34, v14                                 ; 2c5a1d22
	v_mac_f32_e32 v45, v33, v19                                 ; 2c5a2721
	v_mac_f32_e32 v45, v32, v37                                 ; 2c5a4b20
	v_cvt_f32_ubyte2_e32 v37, v18                               ; 7e4a2712
	v_mac_f32_e32 v41, v23, v37                                 ; 2c524b17
	v_mov_b32_e32 v14, v37                                      ; 7e1c0325
	v_mac_f32_e32 v41, v34, v36                                 ; 2c524922
	v_mac_f32_e32 v41, v30, v42                                 ; 2c52551e
	v_mac_f32_e32 v41, v26, v44                                 ; 2c52591a
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_mov_b32_e32 v19, v39                                      ; 7e260327
	v_mac_f32_e32 v41, v22, v37                                 ; 2c524b16
	v_mac_f32_e32 v41, v33, v36                                 ; 2c524921
	v_mac_f32_e32 v41, v29, v42                                 ; 2c52551d
	v_mac_f32_e32 v41, v25, v44                                 ; 2c525919
	v_mac_f32_e32 v41, v21, v37                                 ; 2c524b15
	v_mac_f32_e32 v41, v32, v36                                 ; 2c524920
	buffer_load_dwordx4 v[36:39], v16, s[24:27], 0 offen        ; e05c1000 80062410
	v_add_u32_e32 v16, 16, v16                                  ; 68202090
	v_mac_f32_e32 v41, v28, v42                                 ; 2c52551c
	v_mac_f32_e32 v41, v24, v44                                 ; 2c525918
	v_add_u32_e32 v44, v16, v4                                  ; 68580910
	v_add_u32_e32 v16, v16, v3                                  ; 68200710
	buffer_load_dword v44, v44, s[24:27], 0 offen               ; e0501000 80062c2c
	buffer_load_dword v16, v16, s[24:27], 0 offen               ; e0501000 80061010
	v_cvt_f32_ubyte1_e32 v42, v43                               ; 7e54252b
	v_cvt_f32_ubyte0_e32 v43, v43                               ; 7e56232b
	v_mac_f32_e32 v41, v20, v14                                 ; 2c521d14
	v_cvt_f32_ubyte1_e32 v14, v18                               ; 7e1c2512
	v_cvt_f32_ubyte0_e32 v18, v18                               ; 7e242312
	v_add_u32_e32 v0, 4, v0                                     ; 68000084
	v_bfe_u32 v12, v12, v2, 16                                  ; d1c8000c 0242050c
	v_mul_f32_e32 v45, v45, v42                                 ; 0a5a552d
	v_cmp_le_u32_e64 s[14:15], s3, v0                           ; d0cb000e 00020003
	v_lshl_or_b32 v12, v12, 12, v12                             ; d200000c 0431190c
	v_mac_f32_e32 v45, v15, v43                                 ; 2c5a570f
	v_cvt_f32_f16_sdwa v15, v40 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e1e16f9 00050628
	v_cvt_f32_f16_e32 v40, v40                                  ; 7e501728
	v_mac_f32_e32 v45, v17, v14                                 ; 2c5a1d11
	v_cndmask_b32_sdwa v17, v10, v10, vcc dst_sel:WORD_0 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 002214f9 0605140a
	v_cndmask_b32_sdwa v17, v11, v11, vcc dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 002216f9 0605150b
	v_mad_f32 v6, -v15, v41, v6                                 ; d1c10006 241a530f
	v_mac_f32_e32 v45, v13, v18                                 ; 2c5a250d
	v_and_b32_e32 v18, s9, v17                                  ; 26242209
	v_and_b32_e32 v17, s12, v17                                 ; 2622220c
	v_mac_f32_e32 v6, v40, v45                                  ; 2c0c5b28
	v_lshrrev_b32_e32 v18, 2, v18                               ; 20242482
	v_cvt_f32_ubyte2_e32 v45, v17                               ; 7e5a2711
	v_cvt_f32_ubyte3_e32 v43, v17                               ; 7e562911
	v_and_or_b32 v12, s5, v12, v18                              ; d201000c 044a1805
	v_cvt_f32_ubyte2_e32 v42, v12                               ; 7e54270c
	v_cvt_f32_ubyte3_e32 v40, v12                               ; 7e50290c
	v_mul_f32_e32 v41, v35, v40                                 ; 0a525123
	v_cvt_f32_ubyte1_e32 v10, v12                               ; 7e14250c
	v_mac_f32_e32 v41, v31, v42                                 ; 2c52551f
	v_cvt_f32_ubyte0_e32 v12, v12                               ; 7e18230c
	v_cvt_f32_ubyte1_e32 v11, v17                               ; 7e162511
	v_mac_f32_e32 v41, v27, v43                                 ; 2c52571b
	v_cvt_f32_ubyte0_e32 v17, v17                               ; 7e222311
	v_cvt_f32_f16_sdwa v13, v9 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e1a16f9 00050609
	v_mac_f32_e32 v41, v23, v45                                 ; 2c525b17
	v_cvt_f32_f16_e32 v9, v9                                    ; 7e121709
	v_and_b32_e32 v14, s5, v46                                  ; 261c5c05
	v_mac_f32_e32 v41, v34, v40                                 ; 2c525122
	v_cvt_f32_ubyte2_e32 v18, v14                               ; 7e24270e
	v_cvt_f32_ubyte3_e32 v15, v14                               ; 7e1e290e
	v_mac_f32_e32 v41, v30, v42                                 ; 2c52551e
	v_mul_f32_e32 v15, v23, v15                                 ; 0a1e1f17
	v_mac_f32_e32 v41, v26, v43                                 ; 2c52571a
	v_lshrrev_b32_e32 v46, 4, v46                               ; 205c5c84
	v_mac_f32_e32 v15, v22, v18                                 ; 2c1e2516
	v_mac_f32_e32 v41, v22, v45                                 ; 2c525b16
	v_and_b32_e32 v46, s5, v46                                  ; 265c5c05
	v_mac_f32_e32 v41, v33, v40                                 ; 2c525121
	v_mac_f32_e32 v41, v29, v42                                 ; 2c52551d
	v_mac_f32_e32 v41, v25, v43                                 ; 2c525719
	v_mac_f32_e32 v41, v21, v45                                 ; 2c525b15
	v_mac_f32_e32 v41, v32, v40                                 ; 2c525120
	v_cvt_f32_ubyte1_e32 v40, v14                               ; 7e50250e
	v_cvt_f32_ubyte0_e32 v14, v14                               ; 7e1c230e
	v_mac_f32_e32 v41, v28, v42                                 ; 2c52551c
	v_cvt_f32_ubyte2_e32 v42, v46                               ; 7e54272e
	v_mac_f32_e32 v15, v21, v40                                 ; 2c1e5115
	v_mac_f32_e32 v41, v24, v43                                 ; 2c525718
	v_cvt_f32_ubyte1_e32 v43, v46                               ; 7e56252e
	v_mac_f32_e32 v15, v20, v14                                 ; 2c1e1d14
	v_mac_f32_e32 v41, v20, v45                                 ; 2c525b14
	v_and_b32_e32 v45, s5, v19                                  ; 265a2605
	v_lshrrev_b32_e32 v19, 4, v19                               ; 20262684
	v_mad_f32 v7, -v13, v41, v7                                 ; d1c10007 241e530d
	v_cvt_f32_ubyte3_e32 v41, v46                               ; 7e52292e
	v_cvt_f32_ubyte0_e32 v46, v46                               ; 7e5c232e
	v_cvt_f32_ubyte2_e32 v13, v45                               ; 7e1a272d
	v_cvt_f32_ubyte1_e32 v14, v45                               ; 7e1c252d
	v_and_b32_e32 v19, s5, v19                                  ; 26262605
	v_mul_f32_e32 v41, v27, v41                                 ; 0a52531b
	v_cvt_f32_ubyte2_e32 v40, v19                               ; 7e502713
	v_cvt_f32_ubyte3_e32 v18, v19                               ; 7e242913
	v_mac_f32_e32 v41, v26, v42                                 ; 2c52551a
	v_cvt_f32_ubyte1_e32 v42, v19                               ; 7e542513
	v_cvt_f32_ubyte0_e32 v19, v19                               ; 7e262313
	v_mul_f32_e32 v18, v35, v18                                 ; 0a242523
	v_mac_f32_e32 v41, v25, v43                                 ; 2c525719
	v_mac_f32_e32 v18, v34, v40                                 ; 2c245122
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_bfe_u32 v39, v39, v2, 16                                  ; d1c80027 02420527
	v_cndmask_b32_sdwa v43, v37, v37, vcc dst_sel:WORD_0 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 00564af9 06051425
	v_mac_f32_e32 v41, v24, v46                                 ; 2c525d18
	v_cvt_f32_ubyte3_e32 v46, v45                               ; 7e5c292d
	v_cvt_f32_ubyte0_e32 v45, v45                               ; 7e5a232d
	v_mac_f32_e32 v18, v33, v42                                 ; 2c245521
	v_cndmask_b32_sdwa v43, v38, v38, vcc dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 00564cf9 06051526
	v_lshl_or_b32 v39, v39, 12, v39                             ; d2000027 049d1927
	v_mul_f32_e32 v46, v31, v46                                 ; 0a5c5d1f
	v_mac_f32_e32 v18, v32, v19                                 ; 2c242720
	v_mac_f32_e32 v46, v30, v13                                 ; 2c5c1b1e
	v_mul_f32_e32 v18, v18, v10                                 ; 0a241512
	v_mac_f32_e32 v46, v29, v14                                 ; 2c5c1d1d
	v_mac_f32_e32 v46, v28, v45                                 ; 2c5c5b1c
	v_and_b32_e32 v45, s9, v43                                  ; 265a5609
	v_and_b32_e32 v43, s12, v43                                 ; 2656560c
	v_mac_f32_e32 v18, v46, v12                                 ; 2c24192e
	v_cvt_f32_f16_sdwa v14, v36 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e1c16f9 00050624
	v_cvt_f32_f16_e32 v36, v36                                  ; 7e481724
	v_lshrrev_b32_e32 v45, 2, v45                               ; 205a5a82
	v_cvt_f32_ubyte1_e32 v13, v43                               ; 7e1a252b
	v_cvt_f32_ubyte3_e32 v10, v43                               ; 7e14292b
	v_mac_f32_e32 v18, v41, v11                                 ; 2c241729
	v_cvt_f32_ubyte2_e32 v11, v43                               ; 7e16272b
	v_cvt_f32_ubyte0_e32 v43, v43                               ; 7e56232b
	v_and_or_b32 v39, s5, v39, v45                              ; d2010027 04b64e05
	v_mac_f32_e32 v18, v15, v17                                 ; 2c24230f
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v15, s5, v44                                  ; 261e5805
	v_lshrrev_b32_e32 v44, 4, v44                               ; 20585884
	v_cvt_f32_ubyte3_e32 v46, v39                               ; 7e5c2927
	v_cvt_f32_ubyte1_e32 v12, v39                               ; 7e182527
	v_mac_f32_e32 v7, v9, v18                                   ; 2c0e2509
	v_cvt_f32_ubyte2_e32 v9, v39                                ; 7e122727
	v_cvt_f32_ubyte0_e32 v39, v39                               ; 7e4e2327
	v_cvt_f32_ubyte1_e32 v19, v15                               ; 7e26250f
	v_cvt_f32_ubyte3_e32 v17, v15                               ; 7e22290f
	v_cvt_f32_ubyte2_e32 v18, v15                               ; 7e24270f
	v_cvt_f32_ubyte0_e32 v15, v15                               ; 7e1e230f
	v_and_b32_e32 v44, s5, v44                                  ; 26585805
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v41, s5, v16                                  ; 26522005
	v_mul_f32_e32 v17, v23, v17                                 ; 0a222317
	v_cvt_f32_ubyte2_e32 v38, v44                               ; 7e4c272c
	v_cvt_f32_ubyte3_e32 v37, v44                               ; 7e4a292c
	v_cvt_f32_ubyte1_e32 v40, v44                               ; 7e50252c
	v_cvt_f32_ubyte0_e32 v44, v44                               ; 7e58232c
	v_cvt_f32_ubyte1_e32 v45, v41                               ; 7e5a2529
	v_cvt_f32_ubyte3_e32 v42, v41                               ; 7e542929
	v_mac_f32_e32 v17, v22, v18                                 ; 2c222516
	v_mul_f32_e32 v37, v27, v37                                 ; 0a4a4b1b
	v_lshrrev_b32_e32 v16, 4, v16                               ; 20202084
	v_mul_f32_e32 v42, v31, v42                                 ; 0a54551f
	v_mac_f32_e32 v17, v21, v19                                 ; 2c222715
	v_mac_f32_e32 v37, v26, v38                                 ; 2c4a4d1a
	v_and_b32_e32 v16, s5, v16                                  ; 26202005
	v_mac_f32_e32 v17, v20, v15                                 ; 2c221f14
	v_mac_f32_e32 v37, v25, v40                                 ; 2c4a5119
	v_cvt_f32_ubyte1_e32 v19, v16                               ; 7e262510
	v_cvt_f32_ubyte3_e32 v15, v16                               ; 7e1e2910
	v_cvt_f32_ubyte2_e32 v18, v16                               ; 7e242710
	v_cvt_f32_ubyte0_e32 v16, v16                               ; 7e202310
	v_mac_f32_e32 v37, v24, v44                                 ; 2c4a5918
	v_cvt_f32_ubyte2_e32 v44, v41                               ; 7e582729
	v_cvt_f32_ubyte0_e32 v41, v41                               ; 7e522329
	v_mul_f32_e32 v15, v35, v15                                 ; 0a1e1f23
	v_mul_f32_e32 v35, v35, v46                                 ; 0a465d23
	v_mac_f32_e32 v42, v30, v44                                 ; 2c54591e
	v_mac_f32_e32 v15, v34, v18                                 ; 2c1e2522
	v_mac_f32_e32 v35, v31, v9                                  ; 2c46131f
	v_mac_f32_e32 v42, v29, v45                                 ; 2c545b1d
	v_mac_f32_e32 v15, v33, v19                                 ; 2c1e2721
	v_mac_f32_e32 v35, v27, v10                                 ; 2c46151b
	v_mac_f32_e32 v42, v28, v41                                 ; 2c54531c
	v_mac_f32_e32 v15, v32, v16                                 ; 2c1e2120
	v_mac_f32_e32 v35, v23, v11                                 ; 2c461717
	v_mul_f32_e32 v15, v15, v12                                 ; 0a1e190f
	v_mac_f32_e32 v35, v34, v46                                 ; 2c465d22
	v_mac_f32_e32 v15, v42, v39                                 ; 2c1e4f2a
	v_mac_f32_e32 v35, v30, v9                                  ; 2c46131e
	v_mac_f32_e32 v15, v37, v13                                 ; 2c1e1b25
	v_mac_f32_e32 v35, v26, v10                                 ; 2c46151a
	v_mac_f32_e32 v15, v17, v43                                 ; 2c1e5711
	v_mac_f32_e32 v35, v22, v11                                 ; 2c461716
	v_mac_f32_e32 v35, v33, v46                                 ; 2c465d21
	v_mac_f32_e32 v35, v29, v9                                  ; 2c46131d
	v_mac_f32_e32 v35, v25, v10                                 ; 2c461519
	v_mac_f32_e32 v35, v21, v11                                 ; 2c461715
	v_mac_f32_e32 v35, v32, v46                                 ; 2c465d20
	v_mac_f32_e32 v35, v28, v9                                  ; 2c46131c
	v_mac_f32_e32 v35, v24, v10                                 ; 2c461518
	v_mac_f32_e32 v35, v20, v11                                 ; 2c461714
	v_mad_f32 v8, -v14, v35, v8                                 ; d1c10008 2422470e
	v_mac_f32_e32 v8, v36, v15                                  ; 2c101f24
	s_and_saveexec_b64 s[12:13], s[14:15]                       ; be8c200e
BB11:
	s_andn2_wrexec_b64 s[12:13], s[12:13]                       ; be8c360c
	s_cbranch_scc1 BB6                                          ; bf85fe49
BB12:
	s_mov_b64 exec, s[10:11]                                    ; befe010a
BB15:
	s_andn2_b64 exec, -1, exec                                  ; 89fe7ec1
	v_mov_b32_e32 v5, 0                                         ; 7e0a0280
	v_mov_b32_e32 v6, 0                                         ; 7e0c0280
	v_mov_b32_e32 v7, 0                                         ; 7e0e0280
	v_mov_b32_e32 v8, 0                                         ; 7e100280
BB17:
	s_mov_b64 exec, -1                                          ; befe01c1
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
	s_mov_b64 exec, s[4:5]                                      ; befe0104
	v_readlane_b32 s0, v47, 63                                  ; d2890000 00017f2f
	s_or_saveexec_b64 s[4:5], -1                                ; be8421c1
	v_cndmask_b32_e64 v47, 0, v6, s[4:5]                        ; d100002f 00120c80
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
	v_readlane_b32 s1, v47, 63                                  ; d2890001 00017f2f
	s_or_saveexec_b64 s[4:5], -1                                ; be8421c1
	v_cndmask_b32_e64 v47, 0, v7, s[4:5]                        ; d100002f 00120e80
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
	v_readlane_b32 s3, v47, 63                                  ; d2890003 00017f2f
	s_or_saveexec_b64 s[10:11], -1                              ; be8a21c1
	v_cndmask_b32_e64 v47, 0, v8, s[10:11]                      ; d100002f 002a1080
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
	v_readlane_b32 s4, v47, 63                                  ; d2890004 00017f2f
BB18:
	s_bitcmp1_b32 s8, 0                                         ; bf0d8008
	s_cbranch_scc0 BB20                                         ; bf84000f
BB19:
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
	s_branch BB21                                               ; bf820002
BB20:
	s_mov_b32 s6, src_scc                                       ; be8600fd
	v_mov_b32_e32 v0, s0                                        ; 7e000200
BB21:
	s_bitcmp1_b32 s8, 1                                         ; bf0d8108
	s_cbranch_scc0 BB23                                         ; bf84000e
BB22:
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
	s_branch BB24                                               ; bf820001
BB23:
	s_mov_b32 s5, src_scc                                       ; be8500fd
BB24:
	s_mov_b32 s0, s3                                            ; be800003
	s_movk_i32 s3, 0x8000                                       ; b0038000
	s_load_dwordx4 s[8:11], s[2:3], 0x20                        ; c00a0201 00000020
	s_mul_i32 s7, s7, s17                                       ; 92071107
	s_add_u32 s7, s7, s16                                       ; 80071007
	s_lshl_b32 s7, s7, 2                                        ; 8e078207
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_store_dword v0, off, s[8:11], s7                     ; e0700000 07020080
	s_cmp_lg_i32 s6, 0                                          ; bf018006
	s_cbranch_scc0 BB26                                         ; bf84000b
BB25:
	s_load_dwordx4 s[12:15], s[2:3], 0x30                       ; c00a0301 00000030
	s_mov_b32 s6, src_scc                                       ; be8600fd
	s_add_u32 s16, s7, 4                                        ; 80108407
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s16, s[12:15], s16                      ; c0200406 00000010
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_mov_b32_e32 v0, s16                                       ; 7e000210
	v_add_f32_e32 v0, s1, v0                                    ; 02000001
	s_branch BB27                                               ; bf820002
BB26:
	s_mov_b32 s6, src_scc                                       ; be8600fd
	v_mov_b32_e32 v0, s1                                        ; 7e000201
BB27:
	s_cmp_lg_i32 s5, 0                                          ; bf018005
	s_cbranch_scc0 BB29                                         ; bf84000a
BB28:
	s_load_dwordx4 s[12:15], s[2:3], 0x40                       ; c00a0301 00000040
	s_mov_b32 s1, src_scc                                       ; be8100fd
	s_add_u32 s5, s7, 4                                         ; 80058407
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s5, s[12:15], s5                        ; c0200146 00000005
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v0, s5, v0                                    ; 02000005
	s_branch BB30                                               ; bf820001
BB29:
	s_mov_b32 s1, src_scc                                       ; be8100fd
BB30:
	s_add_u32 s5, s7, 4                                         ; 80058407
	buffer_store_dword v0, off, s[8:11], s5                     ; e0700000 05020080
	s_cmp_lg_i32 s6, 0                                          ; bf018006
	s_cbranch_scc0 BB32                                         ; bf84000b
BB31:
	s_load_dwordx4 s[12:15], s[2:3], 0x30                       ; c00a0301 00000030
	s_mov_b32 s5, src_scc                                       ; be8500fd
	s_add_u32 s6, s7, 8                                         ; 80068807
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s6, s[12:15], s6                        ; c0200186 00000006
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_mov_b32_e32 v0, s6                                        ; 7e000206
	v_add_f32_e32 v0, s0, v0                                    ; 02000000
	s_branch BB33                                               ; bf820002
BB32:
	s_mov_b32 s5, src_scc                                       ; be8500fd
	v_mov_b32_e32 v0, s0                                        ; 7e000200
BB33:
	s_cmp_lg_i32 s1, 0                                          ; bf018001
	s_cbranch_scc0 BB35                                         ; bf84000a
BB34:
	s_load_dwordx4 s[12:15], s[2:3], 0x40                       ; c00a0301 00000040
	s_mov_b32 s0, src_scc                                       ; be8000fd
	s_add_u32 s1, s7, 8                                         ; 80018807
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s1, s[12:15], s1                        ; c0200046 00000001
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v0, s1, v0                                    ; 02000001
	s_branch BB36                                               ; bf820001
BB35:
	s_mov_b32 s0, src_scc                                       ; be8000fd
BB36:
	s_add_u32 s1, s7, 8                                         ; 80018807
	buffer_store_dword v0, off, s[8:11], s1                     ; e0700000 01020080
	s_cmp_lg_i32 s5, 0                                          ; bf018005
	s_cbranch_scc0 BB38                                         ; bf84000a
BB37:
	s_load_dwordx4 s[12:15], s[2:3], 0x30                       ; c00a0301 00000030
	s_add_u32 s1, s7, 12                                        ; 80018c07
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s1, s[12:15], s1                        ; c0200046 00000001
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_mov_b32_e32 v0, s1                                        ; 7e000201
	v_add_f32_e32 v0, s4, v0                                    ; 02000004
	s_branch BB39                                               ; bf820001
BB38:
	v_mov_b32_e32 v0, s4                                        ; 7e000204
BB39:
	s_cmp_lg_i32 s0, 0                                          ; bf018000
	s_cbranch_scc0 BB42                                         ; bf840008
BB40:
	s_load_dwordx4 s[0:3], s[2:3], 0x40                         ; c00a0001 00000040
	s_add_u32 s4, s7, 12                                        ; 80048c07
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s4, s[0:3], s4                          ; c0200100 00000004
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v0, s4, v0                                    ; 02000004
BB42:
	s_add_u32 s7, s7, 12                                        ; 80078c07
	buffer_store_dword v0, off, s[8:11], s7                     ; e0700000 07020080
	s_branch BB131                                              ; bf820344
BB48:
	s_cmp_lt_u32 s16, s4                                        ; bf0a0410
	s_cbranch_scc0 BB131                                        ; bf840342
BB49:
	s_sub_i32 s4, s4, s16                                       ; 81841004
	s_add_u32 s17, s17, s9                                      ; 80110911
	s_cmp_lg_i32 s17, 0                                         ; bf018011
	s_cbranch_scc0 BB51                                         ; bf840043
BB50:
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
	s_branch BB52                                               ; bf820001
BB51:
	s_mov_b32 s19, 0                                            ; be930080
BB52:
	s_lshr_b32 s5, s5, 8                                        ; 8f058805
	v_and_b32_e32 v1, 12, v0                                    ; 2602008c
	v_and_b32_e32 v2, 15, v0                                    ; 2604008f
	s_lshr_b32 s3, s3, 8                                        ; 8f038803
	v_lshrrev_b32_e32 v0, 4, v0                                 ; 20000084
	s_mul_i32 s19, s19, s5                                      ; 92130513
	v_sub_u32_e32 v1, v2, v1                                    ; 6a020302
	v_bfe_u32 v3, v2, 2, 1                                      ; d1c80003 02050502
	v_lshrrev_b32_e32 v2, 3, v2                                 ; 20040483
	v_lshl_add_u32 v1, v1, 1, v3                                ; d1fd0001 040d0301
	v_lshlrev_b32_e32 v1, 2, v1                                 ; 24020282
	v_lshl_add_u32 v4, v2, 5, v1                                ; d1fd0004 04050b02
	v_lshl_add_u32 v1, v2, 6, v1                                ; d1fd0001 04050d02
	v_cmpx_gt_u32_e32 vcc, s3, v0                               ; 7db80003
	s_cbranch_execz BB75                                        ; bf8801ee
BB53:
	v_lshlrev_b32_e32 v2, 4, v2                                 ; 24040484
	s_cmp_lg_i32 s4, 0                                          ; bf018004
	s_mov_b64 s[0:1], exec                                      ; be80017e
	v_mov_b32_e32 v3, 0                                         ; 7e060280
	v_mov_b32_e32 v5, 0                                         ; 7e0a0280
	v_mov_b32_e32 v6, 0                                         ; 7e0c0280
	v_mov_b32_e32 v7, 0                                         ; 7e0e0280
	s_branch BB54                                               ; bf820008
	s_nop 0                                                     ; bf800000
	(then repeated 5 times)
BB71:
	s_mov_b64 exec, s[10:11]                                    ; befe010a
	s_cmp_lg_i32 s9, 0                                          ; bf018009
BB54:
	v_lshl_add_u32 v8, v0, 8, v1                                ; d1fd0008 04051100
	s_cbranch_scc0 BB65                                         ; bf8401d4
BB55:
	s_mov_b32 s10, s2                                           ; be8a0002
	s_movk_i32 s11, 0x8000                                      ; b00b8000
	s_load_dwordx8 s[24:31], s[10:11], 0x0                      ; c00e0605 00000000
	s_mul_i32 s5, s16, s3                                       ; 92050310
	s_mov_b32 s9, src_scc                                       ; be8900fd
	v_add_u32_e32 v13, 64, v4                                   ; 681a08c0
	s_add_u32 s5, s19, s5                                       ; 80050513
	v_add_u32_e32 v9, s5, v0                                    ; 68120005
	v_lshlrev_b32_e32 v10, 4, v9                                ; 24141284
	v_lshl_add_u32 v9, v9, 7, v10                               ; d1fd0009 04290f09
	v_add_u32_e32 v11, 16, v9                                   ; 68161290
	v_add_u32_e32 v12, v11, v4                                  ; 6818090b
	v_add_u32_e32 v11, v11, v13                                 ; 68161b0b
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_load_dwordx4 v[16:19], v9, s[24:27], 0 offen         ; e05c1000 80061009
	buffer_load_dword v12, v12, s[24:27], 0 offen               ; e0501000 80060c0c
	buffer_load_dword v11, v11, s[24:27], 0 offen               ; e0501000 80060b0b
	s_mul_i32 s10, s6, s17                                      ; 920a1106
	v_add_u32_e32 v14, s10, v8                                  ; 681c100a
	v_add_u32_e32 v8, 0x80, v8                                  ; 681010ff 00000080
	v_lshrrev_b32_e32 v14, 2, v14                               ; 201c1c82
	v_add_u32_e32 v8, s10, v8                                   ; 6810100a
	v_lshlrev_b32_e32 v14, 4, v14                               ; 241c1c84
	v_lshrrev_b32_e32 v8, 2, v8                                 ; 20101082
	v_lshlrev_b32_e32 v8, 4, v8                                 ; 24101084
	buffer_load_dwordx4 v[20:23], v14, s[28:31], 0 offen        ; e05c1000 8007140e
	buffer_load_dwordx4 v[24:27], v14, s[28:31], 0 offen offset:128 ; e05c1080 8007180e
	buffer_load_dwordx4 v[28:31], v8, s[28:31], 0 offen         ; e05c1000 80071c08
	buffer_load_dwordx4 v[32:35], v8, s[28:31], 0 offen offset:128 ; e05c1080 80072008
	s_bitreplicate_b64_b32 vcc, 0xf0f0f0f                       ; beea37ff 0f0f0f0f
	s_mov_b32 s11, 0xf0f0f0f                                    ; be8b00ff 0f0f0f0f
	s_cmp_lt_u32 1, s4                                          ; bf0a0481
	s_waitcnt vmcnt(6)                                          ; bf8c3f76
	v_cndmask_b32_sdwa v15, v17, v17, vcc dst_sel:WORD_0 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 001e22f9 06051411
	v_cndmask_b32_sdwa v15, v18, v18, vcc dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 001e24f9 06051512
	v_bfe_u32 v19, v19, v2, 16                                  ; d1c80013 02420513
	v_cvt_f32_f16_sdwa v41, v16 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e5216f9 00050610
	v_cvt_f32_f16_e32 v16, v16                                  ; 7e201710
	v_and_b32_e32 v17, 0xc0c0c0c0, v15                          ; 26221eff c0c0c0c0
	v_and_b32_e32 v15, 0x3f3f3f3f, v15                          ; 261e1eff 3f3f3f3f
	s_waitcnt vmcnt(5)                                          ; bf8c3f75
	v_and_b32_e32 v42, s11, v12                                 ; 2654180b
	v_lshl_or_b32 v19, v19, 12, v19                             ; d2000013 044d1913
	v_lshrrev_b32_e32 v17, 2, v17                               ; 20222282
	v_cvt_f32_ubyte3_e32 v37, v15                               ; 7e4a290f
	v_cvt_f32_ubyte2_e32 v38, v15                               ; 7e4c270f
	v_cvt_f32_ubyte1_e32 v40, v15                               ; 7e50250f
	v_cvt_f32_ubyte0_e32 v15, v15                               ; 7e1e230f
	v_lshrrev_b32_e32 v12, 4, v12                               ; 20181884
	v_cvt_f32_ubyte3_e32 v43, v42                               ; 7e56292a
	v_cvt_f32_ubyte2_e32 v44, v42                               ; 7e58272a
	v_cvt_f32_ubyte1_e32 v45, v42                               ; 7e5a252a
	v_cvt_f32_ubyte0_e32 v42, v42                               ; 7e54232a
	v_and_or_b32 v19, s11, v19, v17                             ; d2010013 0446260b
	s_waitcnt vmcnt(4)                                          ; bf8c3f74
	v_and_b32_e32 v10, s11, v11                                 ; 2614160b
	v_and_b32_e32 v12, s11, v12                                 ; 2618180b
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_mul_f32_e32 v43, v23, v43                                 ; 0a565717
	v_cvt_f32_ubyte3_e32 v18, v19                               ; 7e242913
	v_cvt_f32_ubyte2_e32 v36, v19                               ; 7e482713
	v_cvt_f32_ubyte1_e32 v39, v19                               ; 7e4e2513
	v_cvt_f32_ubyte0_e32 v19, v19                               ; 7e262313
	v_cvt_f32_ubyte2_e32 v17, v10                               ; 7e22270a
	v_cvt_f32_ubyte3_e32 v14, v10                               ; 7e1c290a
	v_cvt_f32_ubyte2_e32 v8, v12                                ; 7e10270c
	v_cvt_f32_ubyte1_e32 v9, v12                                ; 7e12250c
	v_cvt_f32_ubyte3_e32 v46, v12                               ; 7e5c290c
	v_cvt_f32_ubyte0_e32 v12, v12                               ; 7e18230c
	v_lshrrev_b32_e32 v11, 4, v11                               ; 20161684
	v_mac_f32_e32 v43, v22, v44                                 ; 2c565916
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_mul_f32_e32 v46, v27, v46                                 ; 0a5c5d1b
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_mul_f32_e32 v14, v31, v14                                 ; 0a1c1d1f
	v_and_b32_e32 v11, s11, v11                                 ; 2616160b
	v_mac_f32_e32 v43, v21, v45                                 ; 2c565b15
	v_mac_f32_e32 v46, v26, v8                                  ; 2c5c111a
	v_mac_f32_e32 v14, v30, v17                                 ; 2c1c231e
	v_cvt_f32_ubyte3_e32 v44, v11                               ; 7e58290b
	v_cvt_f32_ubyte2_e32 v45, v11                               ; 7e5a270b
	v_cvt_f32_ubyte1_e32 v8, v11                                ; 7e10250b
	v_cvt_f32_ubyte0_e32 v11, v11                               ; 7e16230b
	v_mac_f32_e32 v43, v20, v42                                 ; 2c565514
	v_cvt_f32_ubyte1_e32 v42, v10                               ; 7e54250a
	v_cvt_f32_ubyte0_e32 v10, v10                               ; 7e14230a
	v_mac_f32_e32 v46, v25, v9                                  ; 2c5c1319
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_mul_f32_e32 v9, v35, v18                                  ; 0a122523
	v_mul_f32_e32 v44, v35, v44                                 ; 0a585923
	v_mac_f32_e32 v14, v29, v42                                 ; 2c1c551d
	v_mac_f32_e32 v46, v24, v12                                 ; 2c5c1918
	v_mac_f32_e32 v9, v31, v36                                  ; 2c12491f
	v_mac_f32_e32 v44, v34, v45                                 ; 2c585b22
	v_mac_f32_e32 v14, v28, v10                                 ; 2c1c151c
	v_mac_f32_e32 v9, v27, v37                                  ; 2c124b1b
	v_mac_f32_e32 v44, v33, v8                                  ; 2c581121
	v_mac_f32_e32 v9, v23, v38                                  ; 2c124d17
	v_mac_f32_e32 v44, v32, v11                                 ; 2c581720
	v_mac_f32_e32 v9, v34, v18                                  ; 2c122522
	v_mul_f32_e32 v44, v44, v39                                 ; 0a584f2c
	v_mac_f32_e32 v9, v30, v36                                  ; 2c12491e
	v_mac_f32_e32 v44, v14, v19                                 ; 2c58270e
	v_mac_f32_e32 v9, v26, v37                                  ; 2c124b1a
	v_mac_f32_e32 v44, v46, v40                                 ; 2c58512e
	v_mac_f32_e32 v9, v22, v38                                  ; 2c124d16
	v_mac_f32_e32 v44, v43, v15                                 ; 2c581f2b
	v_mac_f32_e32 v9, v33, v18                                  ; 2c122521
	v_mac_f32_e32 v9, v29, v36                                  ; 2c12491d
	v_mac_f32_e32 v9, v25, v37                                  ; 2c124b19
	v_mac_f32_e32 v9, v21, v38                                  ; 2c124d15
	v_mac_f32_e32 v9, v32, v18                                  ; 2c122520
	v_mac_f32_e32 v9, v28, v36                                  ; 2c12491c
	v_mac_f32_e32 v9, v24, v37                                  ; 2c124b18
	v_mac_f32_e32 v9, v20, v38                                  ; 2c124d14
	v_mad_f32 v3, -v41, v9, v3                                  ; d1c10003 240e1329
	v_mac_f32_e32 v3, v16, v44                                  ; 2c065910
	s_cbranch_scc0 BB66                                         ; bf84014a
BB56:
	s_add_u32 s5, s16, 1                                        ; 80058110
	s_mul_i32 s5, s5, s3                                        ; 92050305
	s_add_u32 s5, s19, s5                                       ; 80050513
	v_add_u32_e32 v8, s5, v0                                    ; 68100005
	v_lshlrev_b32_e32 v9, 4, v8                                 ; 24121084
	v_lshl_add_u32 v8, v8, 7, v9                                ; d1fd0008 04250f08
	v_add_u32_e32 v10, 16, v8                                   ; 68141090
	v_add_u32_e32 v11, v10, v4                                  ; 6816090a
	v_add_u32_e32 v10, v10, v13                                 ; 68141b0a
	buffer_load_dwordx4 v[16:19], v8, s[24:27], 0 offen         ; e05c1000 80061008
	buffer_load_dword v11, v11, s[24:27], 0 offen               ; e0501000 80060b0b
	buffer_load_dword v10, v10, s[24:27], 0 offen               ; e0501000 80060a0a
	s_mov_b32 s10, 0xf0f0f0f                                    ; be8a00ff 0f0f0f0f
	s_cmp_lt_u32 2, s4                                          ; bf0a0482
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_bfe_u32 v19, v19, v2, 16                                  ; d1c80013 02420513
	v_cndmask_b32_sdwa v12, v17, v17, vcc dst_sel:WORD_0 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 001822f9 06051411
	v_cndmask_b32_sdwa v12, v18, v18, vcc dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 001824f9 06051512
	v_lshl_or_b32 v19, v19, 12, v19                             ; d2000013 044d1913
	v_and_b32_e32 v14, 0xc0c0c0c0, v12                          ; 261c18ff c0c0c0c0
	v_and_b32_e32 v12, 0x3f3f3f3f, v12                          ; 261818ff 3f3f3f3f
	v_lshrrev_b32_e32 v14, 2, v14                               ; 201c1c82
	v_cvt_f32_ubyte3_e32 v36, v12                               ; 7e48290c
	v_cvt_f32_ubyte2_e32 v37, v12                               ; 7e4a270c
	v_and_or_b32 v19, s10, v19, v14                             ; d2010013 043a260a
	v_cvt_f32_ubyte3_e32 v15, v19                               ; 7e1e2913
	v_cvt_f32_ubyte2_e32 v18, v19                               ; 7e242713
	v_mul_f32_e32 v17, v35, v15                                 ; 0a221f23
	v_cvt_f32_ubyte1_e32 v38, v19                               ; 7e4c2513
	v_cvt_f32_ubyte0_e32 v19, v19                               ; 7e262313
	v_mac_f32_e32 v17, v31, v18                                 ; 2c22251f
	v_cvt_f32_ubyte1_e32 v39, v12                               ; 7e4e250c
	v_cvt_f32_ubyte0_e32 v12, v12                               ; 7e18230c
	v_cvt_f32_f16_sdwa v40, v16 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e5016f9 00050610
	v_mac_f32_e32 v17, v27, v36                                 ; 2c22491b
	v_cvt_f32_f16_e32 v16, v16                                  ; 7e201710
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v41, s10, v11                                 ; 2652160a
	v_mac_f32_e32 v17, v23, v37                                 ; 2c224b17
	v_cvt_f32_ubyte3_e32 v42, v41                               ; 7e542929
	v_cvt_f32_ubyte2_e32 v43, v41                               ; 7e562729
	v_mac_f32_e32 v17, v34, v15                                 ; 2c221f22
	v_mul_f32_e32 v42, v23, v42                                 ; 0a545517
	v_cvt_f32_ubyte1_e32 v44, v41                               ; 7e582529
	v_cvt_f32_ubyte0_e32 v41, v41                               ; 7e522329
	v_mac_f32_e32 v17, v30, v18                                 ; 2c22251e
	v_mac_f32_e32 v42, v22, v43                                 ; 2c545716
	v_lshrrev_b32_e32 v11, 4, v11                               ; 20161684
	v_mac_f32_e32 v17, v26, v36                                 ; 2c22491a
	v_mac_f32_e32 v42, v21, v44                                 ; 2c545915
	v_and_b32_e32 v11, s10, v11                                 ; 2616160a
	v_mac_f32_e32 v17, v22, v37                                 ; 2c224b16
	v_mac_f32_e32 v42, v20, v41                                 ; 2c545314
	v_cvt_f32_ubyte2_e32 v46, v11                               ; 7e5c270b
	v_cvt_f32_ubyte3_e32 v45, v11                               ; 7e5a290b
	v_mac_f32_e32 v17, v33, v15                                 ; 2c221f21
	v_mul_f32_e32 v45, v27, v45                                 ; 0a5a5b1b
	v_mac_f32_e32 v17, v29, v18                                 ; 2c22251d
	v_mac_f32_e32 v45, v26, v46                                 ; 2c5a5d1a
	v_cvt_f32_ubyte1_e32 v46, v11                               ; 7e5c250b
	v_cvt_f32_ubyte0_e32 v11, v11                               ; 7e16230b
	v_mac_f32_e32 v17, v25, v36                                 ; 2c224919
	v_mac_f32_e32 v45, v25, v46                                 ; 2c5a5d19
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v46, s10, v10                                 ; 265c140a
	v_mac_f32_e32 v17, v21, v37                                 ; 2c224b15
	v_mac_f32_e32 v45, v24, v11                                 ; 2c5a1718
	v_lshrrev_b32_e32 v10, 4, v10                               ; 20141484
	v_cvt_f32_ubyte3_e32 v8, v46                                ; 7e10292e
	v_cvt_f32_ubyte2_e32 v9, v46                                ; 7e12272e
	v_cvt_f32_ubyte1_e32 v11, v46                               ; 7e16252e
	v_cvt_f32_ubyte0_e32 v46, v46                               ; 7e5c232e
	v_mac_f32_e32 v17, v32, v15                                 ; 2c221f20
	v_and_b32_e32 v10, s10, v10                                 ; 2614140a
	v_mul_f32_e32 v8, v31, v8                                   ; 0a10111f
	v_mac_f32_e32 v17, v28, v18                                 ; 2c22251c
	v_cvt_f32_ubyte3_e32 v14, v10                               ; 7e1c290a
	v_cvt_f32_ubyte2_e32 v15, v10                               ; 7e1e270a
	v_mac_f32_e32 v8, v30, v9                                   ; 2c10131e
	v_mac_f32_e32 v17, v24, v36                                 ; 2c224918
	v_mul_f32_e32 v14, v35, v14                                 ; 0a1c1d23
	v_mac_f32_e32 v8, v29, v11                                  ; 2c10171d
	v_mac_f32_e32 v17, v20, v37                                 ; 2c224b14
	v_mac_f32_e32 v14, v34, v15                                 ; 2c1c1f22
	v_mac_f32_e32 v8, v28, v46                                  ; 2c105d1c
	v_mad_f32 v5, -v40, v17, v5                                 ; d1c10005 24162328
	v_cvt_f32_ubyte1_e32 v17, v10                               ; 7e22250a
	v_cvt_f32_ubyte0_e32 v10, v10                               ; 7e14230a
	v_mac_f32_e32 v14, v33, v17                                 ; 2c1c2321
	v_mac_f32_e32 v14, v32, v10                                 ; 2c1c1520
	v_mul_f32_e32 v14, v14, v38                                 ; 0a1c4d0e
	v_mac_f32_e32 v14, v8, v19                                  ; 2c1c2708
	v_mac_f32_e32 v14, v45, v39                                 ; 2c1c4f2d
	v_mac_f32_e32 v14, v42, v12                                 ; 2c1c192a
	v_mac_f32_e32 v5, v16, v14                                  ; 2c0a1d10
	s_cbranch_scc0 BB66                                         ; bf8400dc
BB57:
	s_add_u32 s5, s16, 2                                        ; 80058210
	s_mul_i32 s5, s5, s3                                        ; 92050305
	s_add_u32 s5, s19, s5                                       ; 80050513
	v_add_u32_e32 v8, s5, v0                                    ; 68100005
	v_lshlrev_b32_e32 v9, 4, v8                                 ; 24121084
	v_lshl_add_u32 v8, v8, 7, v9                                ; d1fd0008 04250f08
	v_add_u32_e32 v10, 16, v8                                   ; 68141090
	v_add_u32_e32 v11, v10, v4                                  ; 6816090a
	v_add_u32_e32 v10, v10, v13                                 ; 68141b0a
	buffer_load_dwordx4 v[16:19], v8, s[24:27], 0 offen         ; e05c1000 80061008
	buffer_load_dword v11, v11, s[24:27], 0 offen               ; e0501000 80060b0b
	buffer_load_dword v10, v10, s[24:27], 0 offen               ; e0501000 80060a0a
	s_mov_b32 s10, 0xf0f0f0f                                    ; be8a00ff 0f0f0f0f
	s_cmp_lt_u32 3, s4                                          ; bf0a0483
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_bfe_u32 v19, v19, v2, 16                                  ; d1c80013 02420513
	v_cndmask_b32_sdwa v12, v17, v17, vcc dst_sel:WORD_0 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 001822f9 06051411
	v_cndmask_b32_sdwa v12, v18, v18, vcc dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 001824f9 06051512
	v_lshl_or_b32 v19, v19, 12, v19                             ; d2000013 044d1913
	v_and_b32_e32 v14, 0xc0c0c0c0, v12                          ; 261c18ff c0c0c0c0
	v_and_b32_e32 v12, 0x3f3f3f3f, v12                          ; 261818ff 3f3f3f3f
	v_lshrrev_b32_e32 v14, 2, v14                               ; 201c1c82
	v_cvt_f32_ubyte3_e32 v36, v12                               ; 7e48290c
	v_cvt_f32_ubyte2_e32 v37, v12                               ; 7e4a270c
	v_and_or_b32 v19, s10, v19, v14                             ; d2010013 043a260a
	v_cvt_f32_ubyte3_e32 v15, v19                               ; 7e1e2913
	v_cvt_f32_ubyte2_e32 v18, v19                               ; 7e242713
	v_mul_f32_e32 v17, v35, v15                                 ; 0a221f23
	v_cvt_f32_ubyte1_e32 v38, v19                               ; 7e4c2513
	v_cvt_f32_ubyte0_e32 v19, v19                               ; 7e262313
	v_mac_f32_e32 v17, v31, v18                                 ; 2c22251f
	v_cvt_f32_ubyte1_e32 v39, v12                               ; 7e4e250c
	v_cvt_f32_ubyte0_e32 v12, v12                               ; 7e18230c
	v_cvt_f32_f16_sdwa v40, v16 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e5016f9 00050610
	v_mac_f32_e32 v17, v27, v36                                 ; 2c22491b
	v_cvt_f32_f16_e32 v16, v16                                  ; 7e201710
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v41, s10, v11                                 ; 2652160a
	v_mac_f32_e32 v17, v23, v37                                 ; 2c224b17
	v_cvt_f32_ubyte3_e32 v42, v41                               ; 7e542929
	v_cvt_f32_ubyte2_e32 v43, v41                               ; 7e562729
	v_mac_f32_e32 v17, v34, v15                                 ; 2c221f22
	v_mul_f32_e32 v42, v23, v42                                 ; 0a545517
	v_cvt_f32_ubyte1_e32 v44, v41                               ; 7e582529
	v_cvt_f32_ubyte0_e32 v41, v41                               ; 7e522329
	v_mac_f32_e32 v17, v30, v18                                 ; 2c22251e
	v_mac_f32_e32 v42, v22, v43                                 ; 2c545716
	v_lshrrev_b32_e32 v11, 4, v11                               ; 20161684
	v_mac_f32_e32 v17, v26, v36                                 ; 2c22491a
	v_mac_f32_e32 v42, v21, v44                                 ; 2c545915
	v_and_b32_e32 v11, s10, v11                                 ; 2616160a
	v_mac_f32_e32 v17, v22, v37                                 ; 2c224b16
	v_mac_f32_e32 v42, v20, v41                                 ; 2c545314
	v_cvt_f32_ubyte2_e32 v46, v11                               ; 7e5c270b
	v_cvt_f32_ubyte3_e32 v45, v11                               ; 7e5a290b
	v_mac_f32_e32 v17, v33, v15                                 ; 2c221f21
	v_mul_f32_e32 v45, v27, v45                                 ; 0a5a5b1b
	v_mac_f32_e32 v17, v29, v18                                 ; 2c22251d
	v_mac_f32_e32 v45, v26, v46                                 ; 2c5a5d1a
	v_cvt_f32_ubyte1_e32 v46, v11                               ; 7e5c250b
	v_cvt_f32_ubyte0_e32 v11, v11                               ; 7e16230b
	v_mac_f32_e32 v17, v25, v36                                 ; 2c224919
	v_mac_f32_e32 v45, v25, v46                                 ; 2c5a5d19
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v46, s10, v10                                 ; 265c140a
	v_mac_f32_e32 v17, v21, v37                                 ; 2c224b15
	v_mac_f32_e32 v45, v24, v11                                 ; 2c5a1718
	v_lshrrev_b32_e32 v10, 4, v10                               ; 20141484
	v_cvt_f32_ubyte3_e32 v8, v46                                ; 7e10292e
	v_cvt_f32_ubyte2_e32 v9, v46                                ; 7e12272e
	v_cvt_f32_ubyte1_e32 v11, v46                               ; 7e16252e
	v_cvt_f32_ubyte0_e32 v46, v46                               ; 7e5c232e
	v_mac_f32_e32 v17, v32, v15                                 ; 2c221f20
	v_and_b32_e32 v10, s10, v10                                 ; 2614140a
	v_mul_f32_e32 v8, v31, v8                                   ; 0a10111f
	v_mac_f32_e32 v17, v28, v18                                 ; 2c22251c
	v_cvt_f32_ubyte3_e32 v14, v10                               ; 7e1c290a
	v_cvt_f32_ubyte2_e32 v15, v10                               ; 7e1e270a
	v_mac_f32_e32 v8, v30, v9                                   ; 2c10131e
	v_mac_f32_e32 v17, v24, v36                                 ; 2c224918
	v_mul_f32_e32 v14, v35, v14                                 ; 0a1c1d23
	v_mac_f32_e32 v8, v29, v11                                  ; 2c10171d
	v_mac_f32_e32 v17, v20, v37                                 ; 2c224b14
	v_mac_f32_e32 v14, v34, v15                                 ; 2c1c1f22
	v_mac_f32_e32 v8, v28, v46                                  ; 2c105d1c
	v_mad_f32 v6, -v40, v17, v6                                 ; d1c10006 241a2328
	v_cvt_f32_ubyte1_e32 v17, v10                               ; 7e22250a
	v_cvt_f32_ubyte0_e32 v10, v10                               ; 7e14230a
	v_mac_f32_e32 v14, v33, v17                                 ; 2c1c2321
	v_mac_f32_e32 v14, v32, v10                                 ; 2c1c1520
	v_mul_f32_e32 v14, v14, v38                                 ; 0a1c4d0e
	v_mac_f32_e32 v14, v8, v19                                  ; 2c1c2708
	v_mac_f32_e32 v14, v45, v39                                 ; 2c1c4f2d
	v_mac_f32_e32 v14, v42, v12                                 ; 2c1c192a
	v_mac_f32_e32 v6, v16, v14                                  ; 2c0c1d10
	s_cbranch_scc0 BB66                                         ; bf84006e
BB58:
	s_add_u32 s5, s16, 3                                        ; 80058310
	s_mul_i32 s5, s5, s3                                        ; 92050305
	s_add_u32 s5, s19, s5                                       ; 80050513
	v_add_u32_e32 v8, s5, v0                                    ; 68100005
	v_lshlrev_b32_e32 v9, 4, v8                                 ; 24121084
	v_lshl_add_u32 v8, v8, 7, v9                                ; d1fd0008 04250f08
	v_add_u32_e32 v10, 16, v8                                   ; 68141090
	v_add_u32_e32 v11, v10, v4                                  ; 6816090a
	v_add_u32_e32 v10, v10, v13                                 ; 68141b0a
	buffer_load_dwordx4 v[12:15], v8, s[24:27], 0 offen         ; e05c1000 80060c08
	buffer_load_dword v11, v11, s[24:27], 0 offen               ; e0501000 80060b0b
	buffer_load_dword v10, v10, s[24:27], 0 offen               ; e0501000 80060a0a
	s_mov_b32 s10, 0xf0f0f0f                                    ; be8a00ff 0f0f0f0f
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_bfe_u32 v15, v15, v2, 16                                  ; d1c8000f 0242050f
	v_cndmask_b32_sdwa v13, v13, v13, vcc dst_sel:WORD_0 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 001a1af9 0605140d
	v_cndmask_b32_sdwa v13, v14, v14, vcc dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 001a1cf9 0605150e
	v_cvt_f32_f16_sdwa v38, v12 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e4c16f9 0005060c
	v_lshl_or_b32 v15, v15, 12, v15                             ; d200000f 043d190f
	v_cvt_f32_f16_e32 v12, v12                                  ; 7e18170c
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v39, s10, v11                                 ; 264e160a
	v_and_b32_e32 v14, 0xc0c0c0c0, v13                          ; 261c1aff c0c0c0c0
	v_and_b32_e32 v13, 0x3f3f3f3f, v13                          ; 261a1aff 3f3f3f3f
	v_cvt_f32_ubyte1_e32 v42, v39                               ; 7e542527
	v_cvt_f32_ubyte3_e32 v40, v39                               ; 7e502927
	v_cvt_f32_ubyte2_e32 v41, v39                               ; 7e522727
	v_lshrrev_b32_e32 v14, 2, v14                               ; 201c1c82
	v_cvt_f32_ubyte0_e32 v39, v39                               ; 7e4e2327
	v_cvt_f32_ubyte3_e32 v18, v13                               ; 7e24290d
	v_cvt_f32_ubyte2_e32 v19, v13                               ; 7e26270d
	v_cvt_f32_ubyte1_e32 v37, v13                               ; 7e4a250d
	v_cvt_f32_ubyte0_e32 v13, v13                               ; 7e1a230d
	v_mul_f32_e32 v40, v23, v40                                 ; 0a505117
	v_lshrrev_b32_e32 v11, 4, v11                               ; 20161684
	v_and_or_b32 v15, s10, v15, v14                             ; d201000f 043a1e0a
	v_mac_f32_e32 v40, v22, v41                                 ; 2c505316
	v_and_b32_e32 v11, s10, v11                                 ; 2616160a
	v_cvt_f32_ubyte3_e32 v16, v15                               ; 7e20290f
	v_cvt_f32_ubyte2_e32 v17, v15                               ; 7e22270f
	v_cvt_f32_ubyte1_e32 v36, v15                               ; 7e48250f
	v_cvt_f32_ubyte0_e32 v15, v15                               ; 7e1e230f
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v46, s10, v10                                 ; 265c140a
	v_mac_f32_e32 v40, v21, v42                                 ; 2c505515
	v_cvt_f32_ubyte3_e32 v43, v11                               ; 7e56290b
	v_cvt_f32_ubyte2_e32 v44, v11                               ; 7e58270b
	v_cvt_f32_ubyte1_e32 v45, v11                               ; 7e5a250b
	v_cvt_f32_ubyte0_e32 v11, v11                               ; 7e16230b
	v_cvt_f32_ubyte3_e32 v8, v46                                ; 7e10292e
	v_cvt_f32_ubyte2_e32 v9, v46                                ; 7e12272e
	v_mac_f32_e32 v40, v20, v39                                 ; 2c504f14
	v_mul_f32_e32 v43, v27, v43                                 ; 0a56571b
	v_lshrrev_b32_e32 v10, 4, v10                               ; 20141484
	v_mul_f32_e32 v8, v31, v8                                   ; 0a10111f
	v_mac_f32_e32 v43, v26, v44                                 ; 2c56591a
	v_and_b32_e32 v10, s10, v10                                 ; 2614140a
	v_mac_f32_e32 v8, v30, v9                                   ; 2c10131e
	v_mac_f32_e32 v43, v25, v45                                 ; 2c565b19
	v_cvt_f32_ubyte2_e32 v39, v10                               ; 7e4e270a
	v_cvt_f32_ubyte1_e32 v41, v10                               ; 7e52250a
	v_cvt_f32_ubyte3_e32 v14, v10                               ; 7e1c290a
	v_cvt_f32_ubyte0_e32 v10, v10                               ; 7e14230a
	v_mac_f32_e32 v43, v24, v11                                 ; 2c561718
	v_cvt_f32_ubyte1_e32 v11, v46                               ; 7e16252e
	v_cvt_f32_ubyte0_e32 v46, v46                               ; 7e5c232e
	v_mul_f32_e32 v14, v35, v14                                 ; 0a1c1d23
	v_mul_f32_e32 v35, v35, v16                                 ; 0a462123
	v_mac_f32_e32 v8, v29, v11                                  ; 2c10171d
	v_mac_f32_e32 v14, v34, v39                                 ; 2c1c4f22
	v_mac_f32_e32 v35, v31, v17                                 ; 2c46231f
	v_mac_f32_e32 v8, v28, v46                                  ; 2c105d1c
	v_mac_f32_e32 v14, v33, v41                                 ; 2c1c5321
	v_mac_f32_e32 v35, v27, v18                                 ; 2c46251b
	v_mac_f32_e32 v14, v32, v10                                 ; 2c1c1520
	v_mac_f32_e32 v35, v23, v19                                 ; 2c462717
	v_mul_f32_e32 v14, v14, v36                                 ; 0a1c490e
	v_mac_f32_e32 v35, v34, v16                                 ; 2c462122
	v_mac_f32_e32 v14, v8, v15                                  ; 2c1c1f08
	v_mac_f32_e32 v35, v30, v17                                 ; 2c46231e
	v_mac_f32_e32 v14, v43, v37                                 ; 2c1c4b2b
	v_mac_f32_e32 v35, v26, v18                                 ; 2c46251a
	v_mac_f32_e32 v14, v40, v13                                 ; 2c1c1b28
	v_mac_f32_e32 v35, v22, v19                                 ; 2c462716
	v_mac_f32_e32 v35, v33, v16                                 ; 2c462121
	v_mac_f32_e32 v35, v29, v17                                 ; 2c46231d
	v_mac_f32_e32 v35, v25, v18                                 ; 2c462519
	v_mac_f32_e32 v35, v21, v19                                 ; 2c462715
	v_mac_f32_e32 v35, v32, v16                                 ; 2c462120
	v_mac_f32_e32 v35, v28, v17                                 ; 2c46231c
	v_mac_f32_e32 v35, v24, v18                                 ; 2c462518
	v_mac_f32_e32 v35, v20, v19                                 ; 2c462714
	v_mad_f32 v7, -v38, v35, v7                                 ; d1c10007 241e4726
	v_mac_f32_e32 v7, v12, v14                                  ; 2c0e1d0c
	s_branch BB66                                               ; bf820001
BB65:
	s_mov_b32 s9, src_scc                                       ; be8900fd
BB66:
	v_add_u32_e32 v0, 4, v0                                     ; 68000084
	s_mov_b64 s[10:11], exec                                    ; be8a017e
	v_cmpx_le_u32_e32 vcc, s3, v0                               ; 7db60003
BB67:
	s_andn2_b64 s[10:11], s[10:11], exec                        ; 898a7e0a
	s_cbranch_scc1 BB71                                         ; bf85fe21
BB72:
	s_mov_b64 exec, s[0:1]                                      ; befe0100
BB75:
	s_andn2_b64 exec, -1, exec                                  ; 89fe7ec1
	v_mov_b32_e32 v3, 0                                         ; 7e060280
	v_mov_b32_e32 v5, 0                                         ; 7e0a0280
	v_mov_b32_e32 v6, 0                                         ; 7e0c0280
	v_mov_b32_e32 v7, 0                                         ; 7e0e0280
BB77:
	s_mov_b64 exec, -1                                          ; befe01c1
	s_cmp_lg_i32 s4, 0                                          ; bf018004
	s_cselect_b64 s[0:1], -1, 0                                 ; 858080c1
	s_cbranch_scc0 BB89                                         ; bf84006a
BB78:
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
	s_cbranch_scc0 BB87                                         ; bf84004f
BB79:
	s_or_saveexec_b64 s[10:11], -1                              ; be8a21c1
	s_cmp_lt_u32 2, s4                                          ; bf0a0482
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
	s_cbranch_scc0 BB85                                         ; bf840034
BB80:
	s_or_saveexec_b64 s[10:11], -1                              ; be8a21c1
	s_cmp_lt_u32 3, s4                                          ; bf0a0483
	v_cndmask_b32_e64 v47, 0, v6, s[10:11]                      ; d100002f 002a0c80
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
	v_readlane_b32 s6, v47, 63                                  ; d2890006 00017f2f
	s_cbranch_scc0 BB83                                         ; bf840019
BB81:
	s_or_saveexec_b64 s[10:11], -1                              ; be8a21c1
	v_cndmask_b32_e64 v47, 0, v7, s[10:11]                      ; d100002f 002a0e80
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
	v_readlane_b32 s9, v47, 63                                  ; d2890009 00017f2f
	v_mov_b32_e32 v7, s9                                        ; 7e0e0209
BB83:
	v_mov_b32_e32 v6, s6                                        ; 7e0c0206
BB85:
	v_mov_b32_e32 v5, s5                                        ; 7e0a0205
BB87:
	v_mov_b32_e32 v3, s3                                        ; 7e060203
BB89:
	s_mov_b64 s[10:11], 1                                       ; be8a0181
	s_and_b64 exec, s[0:1], s[10:11]                            ; 86fe0a00
	s_cbranch_execz BB131                                       ; bf880083
BB90:
	s_bitcmp1_b32 s8, 0                                         ; bf0d8008
	s_cbranch_scc0 BB92                                         ; bf84000e
BB91:
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
	s_branch BB93                                               ; bf820001
BB92:
	s_mov_b32 s1, src_scc                                       ; be8100fd
BB93:
	s_bitcmp1_b32 s8, 1                                         ; bf0d8108
	s_cbranch_scc0 BB95                                         ; bf84000e
BB94:
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
	s_branch BB96                                               ; bf820001
BB95:
	s_mov_b32 s3, src_scc                                       ; be8300fd
BB96:
	s_mov_b32 s0, s3                                            ; be800003
	s_movk_i32 s3, 0x8000                                       ; b0038000
	s_load_dwordx4 s[8:11], s[2:3], 0x20                        ; c00a0201 00000020
	s_mul_i32 s7, s7, s17                                       ; 92071107
	s_add_u32 s7, s7, s16                                       ; 80071007
	s_lshl_b32 s7, s7, 2                                        ; 8e078207
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_store_dword v3, off, s[8:11], s7                     ; e0700000 07020380
	s_cmp_lt_u32 1, s4                                          ; bf0a0481
	s_cbranch_scc0 BB131                                        ; bf840055
BB97:
	s_cmp_lg_i32 s1, 0                                          ; bf018001
	s_cbranch_scc0 BB99                                         ; bf84000a
BB98:
	s_load_dwordx4 s[12:15], s[2:3], 0x30                       ; c00a0301 00000030
	s_mov_b32 s1, src_scc                                       ; be8100fd
	s_add_u32 s5, s7, 4                                         ; 80058407
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s5, s[12:15], s5                        ; c0200146 00000005
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v5, s5, v5                                    ; 020a0a05
	s_branch BB100                                              ; bf820001
BB99:
	s_mov_b32 s1, src_scc                                       ; be8100fd
BB100:
	s_cmp_lg_i32 s0, 0                                          ; bf018000
	s_cbranch_scc0 BB102                                        ; bf84000a
BB101:
	s_load_dwordx4 s[12:15], s[2:3], 0x40                       ; c00a0301 00000040
	s_mov_b32 s0, src_scc                                       ; be8000fd
	s_add_u32 s5, s7, 4                                         ; 80058407
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s5, s[12:15], s5                        ; c0200146 00000005
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v5, s5, v5                                    ; 020a0a05
	s_branch BB103                                              ; bf820001
BB102:
	s_mov_b32 s0, src_scc                                       ; be8000fd
BB103:
	s_add_u32 s5, s7, 4                                         ; 80058407
	buffer_store_dword v5, off, s[8:11], s5                     ; e0700000 05020580
	s_cmp_lt_u32 2, s4                                          ; bf0a0482
	s_cbranch_scc0 BB131                                        ; bf840036
BB104:
	s_cmp_lg_i32 s1, 0                                          ; bf018001
	s_cbranch_scc0 BB106                                        ; bf84000a
BB105:
	s_load_dwordx4 s[12:15], s[2:3], 0x30                       ; c00a0301 00000030
	s_mov_b32 s1, src_scc                                       ; be8100fd
	s_add_u32 s5, s7, 8                                         ; 80058807
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s5, s[12:15], s5                        ; c0200146 00000005
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v6, s5, v6                                    ; 020c0c05
	s_branch BB107                                              ; bf820001
BB106:
	s_mov_b32 s1, src_scc                                       ; be8100fd
BB107:
	s_cmp_lg_i32 s0, 0                                          ; bf018000
	s_cbranch_scc0 BB109                                        ; bf84000a
BB108:
	s_load_dwordx4 s[12:15], s[2:3], 0x40                       ; c00a0301 00000040
	s_mov_b32 s0, src_scc                                       ; be8000fd
	s_add_u32 s5, s7, 8                                         ; 80058807
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s5, s[12:15], s5                        ; c0200146 00000005
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v6, s5, v6                                    ; 020c0c05
	s_branch BB110                                              ; bf820001
BB109:
	s_mov_b32 s0, src_scc                                       ; be8000fd
BB110:
	s_add_u32 s5, s7, 8                                         ; 80058807
	buffer_store_dword v6, off, s[8:11], s5                     ; e0700000 05020680
	s_cmp_lt_u32 3, s4                                          ; bf0a0483
	s_cbranch_scc0 BB131                                        ; bf840017
BB111:
	s_cmp_lg_i32 s1, 0                                          ; bf018001
	s_cbranch_scc0 BB114                                        ; bf840008
BB112:
	s_load_dwordx4 s[12:15], s[2:3], 0x30                       ; c00a0301 00000030
	s_add_u32 s1, s7, 12                                        ; 80018c07
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s1, s[12:15], s1                        ; c0200046 00000001
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v7, s1, v7                                    ; 020e0e01
BB114:
	s_cmp_lg_i32 s0, 0                                          ; bf018000
	s_cbranch_scc0 BB117                                        ; bf840008
BB115:
	s_load_dwordx4 s[0:3], s[2:3], 0x40                         ; c00a0001 00000040
	s_add_u32 s4, s7, 12                                        ; 80048c07
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s4, s[0:3], s4                          ; c0200100 00000004
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v7, s4, v7                                    ; 020e0e04
BB117:
	s_add_u32 s7, s7, 12                                        ; 80078c07
	buffer_store_dword v7, off, s[8:11], s7                     ; e0700000 07020780
BB131:
	s_endpgm                                                    ; bf810000
