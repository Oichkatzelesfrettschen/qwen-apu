BB0:
	s_load_dword s0, s[14:15], 0x0                              ; c0020007 00000000
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_mul_i32 s0, s0, s18                                       ; 92001200
	s_add_u32 s16, s16, s0                                      ; 80100010
	s_lshl_b32 s16, s16, 2                                      ; 8e108210
	s_add_u32 s1, s16, 4                                        ; 80018410
	s_cmp_ge_u32 s4, s1                                         ; bf090104
	s_cbranch_scc0 BB48                                         ; bf8402fb
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
	s_cbranch_execz BB15                                        ; bf8801b4
BB5:
	s_mov_b32 s0, s2                                            ; be800002
	s_movk_i32 s1, 0x8000                                       ; b0018000
	s_load_dwordx8 s[24:31], s[0:1], 0x0                        ; c00e0600 00000000
	s_mul_i32 s6, s6, s17                                       ; 92061106
	s_mul_i32 s0, s16, s3                                       ; 92000310
	v_lshlrev_b32_e32 v2, 4, v2                                 ; 24040484
	v_add_u32_e32 v3, 64, v4                                    ; 680608c0
	s_bitreplicate_b64_b32 vcc, 0xf0f0f0f                       ; beea37ff 0f0f0f0f
	s_mov_b64 s[10:11], exec                                    ; be8a017e
	v_mov_b32_e32 v5, 0                                         ; 7e0a0280
	v_mov_b32_e32 v6, 0                                         ; 7e0c0280
	s_add_u32 s0, s18, s0                                       ; 80000012
	s_add_u32 s1, s16, 1                                        ; 80018110
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
	v_lshl_add_u32 v9, v0, 8, v1                                ; d1fd0009 04051100
	v_add_u32_e32 v10, s6, v9                                   ; 68141206
	v_add_u32_e32 v9, 0x80, v9                                  ; 681212ff 00000080
	v_lshrrev_b32_e32 v10, 2, v10                               ; 20141482
	v_add_u32_e32 v9, s6, v9                                    ; 68121206
	v_lshlrev_b32_e32 v10, 4, v10                               ; 24141484
	v_lshrrev_b32_e32 v9, 2, v9                                 ; 20121282
	v_lshlrev_b32_e32 v9, 4, v9                                 ; 24121284
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_load_dwordx4 v[12:15], v10, s[28:31], 0 offen        ; e05c1000 80070c0a
	buffer_load_dwordx4 v[16:19], v10, s[28:31], 0 offen offset:128 ; e05c1080 8007100a
	buffer_load_dwordx4 v[20:23], v9, s[28:31], 0 offen         ; e05c1000 80071409
	buffer_load_dwordx4 v[24:27], v9, s[28:31], 0 offen offset:128 ; e05c1080 80071809
	v_add_u32_e32 v11, s0, v0                                   ; 68160000
	v_add_u32_e32 v31, s1, v0                                   ; 683e0001
	v_lshlrev_b32_e32 v28, 4, v11                               ; 24381684
	v_lshlrev_b32_e32 v32, 4, v31                               ; 24403e84
	v_lshl_add_u32 v11, v11, 7, v28                             ; d1fd000b 04710f0b
	v_lshl_add_u32 v31, v31, 7, v32                             ; d1fd001f 04810f1f
	v_add_u32_e32 v29, 16, v11                                  ; 683a1690
	v_add_u32_e32 v33, 16, v31                                  ; 68423e90
	v_add_u32_e32 v30, v29, v4                                  ; 683c091d
	v_add_u32_e32 v29, v29, v3                                  ; 683a071d
	v_add_u32_e32 v34, v33, v4                                  ; 68440921
	v_add_u32_e32 v33, v33, v3                                  ; 68420721
	buffer_load_dwordx4 v[36:39], v11, s[24:27], 0 offen        ; e05c1000 8006240b
	buffer_load_dword v30, v30, s[24:27], 0 offen               ; e0501000 80061e1e
	buffer_load_dword v29, v29, s[24:27], 0 offen               ; e0501000 80061d1d
	buffer_load_dwordx4 v[40:43], v31, s[24:27], 0 offen        ; e05c1000 8006281f
	buffer_load_dword v34, v34, s[24:27], 0 offen               ; e0501000 80062222
	buffer_load_dword v33, v33, s[24:27], 0 offen               ; e0501000 80062121
	s_mov_b32 s5, 0xf0f0f0f                                     ; be8500ff 0f0f0f0f
	s_mov_b32 s9, 0xc0c0c0c0                                    ; be8900ff c0c0c0c0
	s_mov_b32 s12, 0x3f3f3f3f                                   ; be8c00ff 3f3f3f3f
	v_add_u32_e32 v35, s4, v0                                   ; 68460004
	s_waitcnt vmcnt(9)                                          ; bf8c3f79
	v_add_f32_e32 v44, v12, v13                                 ; 02581b0c
	s_waitcnt vmcnt(8)                                          ; bf8c3f78
	v_add_f32_e32 v45, v16, v17                                 ; 025a2310
	v_add_f32_e32 v44, v44, v14                                 ; 02581d2c
	s_waitcnt vmcnt(7)                                          ; bf8c3f77
	v_add_f32_e32 v46, v20, v21                                 ; 025c2b14
	v_add_f32_e32 v45, v45, v18                                 ; 025a252d
	s_waitcnt vmcnt(6)                                          ; bf8c3f76
	v_add_f32_e32 v9, v24, v25                                  ; 02123318
	v_add_f32_e32 v44, v44, v15                                 ; 02581f2c
	v_add_f32_e32 v46, v46, v22                                 ; 025c2d2e
	v_add_f32_e32 v45, v45, v19                                 ; 025a272d
	v_add_f32_e32 v9, v9, v26                                   ; 02123509
	v_add_f32_e32 v46, v46, v23                                 ; 025c2f2e
	v_add_f32_e32 v9, v9, v27                                   ; 02123709
	s_waitcnt vmcnt(5)                                          ; bf8c3f75
	v_cndmask_b32_sdwa v10, v37, v37, vcc dst_sel:WORD_0 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 00144af9 06051425
	v_bfe_u32 v39, v39, v2, 16                                  ; d1c80027 02420527
	v_cndmask_b32_sdwa v10, v38, v38, vcc dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 00144cf9 06051526
	s_waitcnt vmcnt(4)                                          ; bf8c3f74
	v_and_b32_e32 v28, s5, v30                                  ; 26383c05
	v_lshrrev_b32_e32 v30, 4, v30                               ; 203c3c84
	v_lshl_or_b32 v39, v39, 12, v39                             ; d2000027 049d1927
	v_and_b32_e32 v11, s9, v10                                  ; 26161409
	v_cvt_f32_ubyte2_e32 v32, v28                               ; 7e40271c
	v_cvt_f32_ubyte3_e32 v31, v28                               ; 7e3e291c
	v_cvt_f32_ubyte1_e32 v37, v28                               ; 7e4a251c
	v_cvt_f32_ubyte0_e32 v28, v28                               ; 7e38231c
	v_and_b32_e32 v30, s5, v30                                  ; 263c3c05
	v_lshrrev_b32_e32 v11, 2, v11                               ; 20161682
	v_mul_f32_e32 v31, v15, v31                                 ; 0a3e3f0f
	v_cvt_f32_ubyte3_e32 v38, v30                               ; 7e4c291e
	v_and_or_b32 v39, s5, v39, v11                              ; d2010027 042e4e05
	v_cvt_f32_ubyte2_e32 v11, v30                               ; 7e16271e
	v_mac_f32_e32 v31, v14, v32                                 ; 2c3e410e
	v_mul_f32_e32 v38, v19, v38                                 ; 0a4c4d13
	v_mac_f32_e32 v31, v13, v37                                 ; 2c3e4b0d
	v_mac_f32_e32 v38, v18, v11                                 ; 2c4c1712
	v_mac_f32_e32 v31, v12, v28                                 ; 2c3e390c
	v_cvt_f32_ubyte1_e32 v28, v30                               ; 7e38251e
	v_cvt_f32_ubyte0_e32 v30, v30                               ; 7e3c231e
	v_mac_f32_e32 v38, v17, v28                                 ; 2c4c3911
	v_mac_f32_e32 v38, v16, v30                                 ; 2c4c3d10
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_and_b32_e32 v30, s5, v29                                  ; 263c3a05
	v_lshrrev_b32_e32 v29, 4, v29                               ; 203a3a84
	v_cvt_f32_ubyte1_e32 v11, v30                               ; 7e16251e
	v_cvt_f32_ubyte2_e32 v37, v30                               ; 7e4a271e
	v_cvt_f32_ubyte3_e32 v32, v30                               ; 7e40291e
	v_cvt_f32_ubyte0_e32 v30, v30                               ; 7e3c231e
	v_and_b32_e32 v29, s5, v29                                  ; 263a3a05
	v_mul_f32_e32 v32, v23, v32                                 ; 0a404117
	v_and_b32_e32 v10, s12, v10                                 ; 2614140c
	v_cvt_f32_ubyte3_e32 v28, v29                               ; 7e38291d
	v_mac_f32_e32 v32, v22, v37                                 ; 2c404b16
	v_cvt_f32_ubyte1_e32 v37, v29                               ; 7e4a251d
	v_mul_f32_e32 v28, v27, v28                                 ; 0a38391b
	v_mac_f32_e32 v32, v21, v11                                 ; 2c401715
	v_cvt_f32_ubyte3_e32 v11, v39                               ; 7e162927
	v_mac_f32_e32 v32, v20, v30                                 ; 2c403d14
	v_cvt_f32_ubyte2_e32 v30, v29                               ; 7e3c271d
	v_cvt_f32_ubyte0_e32 v29, v29                               ; 7e3a231d
	v_mul_f32_e32 v11, v9, v11                                  ; 0a161709
	v_mac_f32_e32 v28, v26, v30                                 ; 2c383d1a
	v_cvt_f32_ubyte3_e32 v30, v10                               ; 7e3c290a
	v_mac_f32_e32 v28, v25, v37                                 ; 2c384b19
	v_cvt_f32_ubyte2_e32 v37, v10                               ; 7e4a270a
	v_mac_f32_e32 v28, v24, v29                                 ; 2c383b18
	v_cvt_f32_ubyte2_e32 v29, v39                               ; 7e3a2727
	v_mac_f32_e32 v11, v46, v29                                 ; 2c163b2e
	v_cvt_f32_ubyte1_e32 v29, v39                               ; 7e3a2527
	v_cvt_f32_ubyte0_e32 v39, v39                               ; 7e4e2327
	v_mac_f32_e32 v11, v45, v30                                 ; 2c163d2d
	v_cvt_f32_ubyte1_e32 v30, v10                               ; 7e3c250a
	v_cvt_f32_ubyte0_e32 v10, v10                               ; 7e14230a
	v_mul_f32_e32 v28, v28, v29                                 ; 0a383b1c
	v_mac_f32_e32 v11, v44, v37                                 ; 2c164b2c
	v_mac_f32_e32 v28, v32, v39                                 ; 2c384f20
	v_lshlrev_b32_e32 v32, 4, v35                               ; 24404684
	v_mac_f32_e32 v28, v38, v30                                 ; 2c383d26
	v_lshl_add_u32 v35, v35, 7, v32                             ; d1fd0023 04810f23
	v_mac_f32_e32 v28, v31, v10                                 ; 2c38151f
	v_add_u32_e32 v37, 16, v35                                  ; 684a4690
	v_add_u32_e32 v38, v37, v4                                  ; 684c0925
	v_add_u32_e32 v37, v37, v3                                  ; 684a0725
	buffer_load_dwordx4 v[29:32], v35, s[24:27], 0 offen        ; e05c1000 80061d23
	buffer_load_dword v38, v38, s[24:27], 0 offen               ; e0501000 80062626
	buffer_load_dword v37, v37, s[24:27], 0 offen               ; e0501000 80062525
	v_cvt_f32_f16_sdwa v35, v36 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e4616f9 00050624
	v_cvt_f32_f16_e32 v36, v36                                  ; 7e481724
	s_waitcnt vmcnt(5)                                          ; bf8c3f75
	v_bfe_u32 v43, v43, v2, 16                                  ; d1c8002b 0242052b
	v_cndmask_b32_sdwa v39, v41, v41, vcc dst_sel:WORD_0 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 004e52f9 06051429
	v_cndmask_b32_sdwa v39, v42, v42, vcc dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 004e54f9 0605152a
	s_waitcnt vmcnt(4)                                          ; bf8c3f74
	v_and_b32_e32 v42, s5, v34                                  ; 26544405
	v_mad_f32 v5, -v35, v11, v5                                 ; d1c10005 24161723
	v_lshl_or_b32 v43, v43, 12, v43                             ; d200002b 04ad192b
	v_lshrrev_b32_e32 v34, 4, v34                               ; 20444484
	v_and_b32_e32 v41, s9, v39                                  ; 26524e09
	v_cvt_f32_ubyte3_e32 v10, v42                               ; 7e14292a
	v_cvt_f32_ubyte2_e32 v11, v42                               ; 7e16272a
	v_mac_f32_e32 v5, v36, v28                                  ; 2c0a3924
	v_add_u32_e32 v36, s18, v0                                  ; 68480012
	v_cvt_f32_ubyte1_e32 v28, v42                               ; 7e38252a
	v_cvt_f32_ubyte0_e32 v42, v42                               ; 7e54232a
	v_and_b32_e32 v34, s5, v34                                  ; 26444405
	v_lshrrev_b32_e32 v41, 2, v41                               ; 20525282
	v_mul_f32_e32 v10, v15, v10                                 ; 0a14150f
	v_cvt_f32_ubyte3_e32 v35, v34                               ; 7e462922
	v_and_or_b32 v43, s5, v43, v41                              ; d201002b 04a65605
	v_cvt_f32_ubyte2_e32 v41, v34                               ; 7e522722
	v_mac_f32_e32 v10, v14, v11                                 ; 2c14170e
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_and_b32_e32 v11, s5, v33                                  ; 26164205
	v_mul_f32_e32 v35, v19, v35                                 ; 0a464713
	v_mac_f32_e32 v10, v13, v28                                 ; 2c14390d
	v_cvt_f32_ubyte3_e32 v28, v11                               ; 7e38290b
	v_lshrrev_b32_e32 v33, 4, v33                               ; 20424284
	v_mac_f32_e32 v35, v18, v41                                 ; 2c465312
	v_cvt_f32_ubyte1_e32 v41, v11                               ; 7e52250b
	v_mac_f32_e32 v10, v12, v42                                 ; 2c14550c
	v_cvt_f32_ubyte1_e32 v42, v34                               ; 7e542522
	v_cvt_f32_ubyte0_e32 v34, v34                               ; 7e442322
	v_mul_f32_e32 v28, v23, v28                                 ; 0a383917
	v_and_b32_e32 v33, s5, v33                                  ; 26424205
	v_mac_f32_e32 v35, v17, v42                                 ; 2c465511
	v_cvt_f32_ubyte3_e32 v42, v33                               ; 7e542921
	v_mac_f32_e32 v35, v16, v34                                 ; 2c464510
	v_cvt_f32_ubyte2_e32 v34, v11                               ; 7e44270b
	v_cvt_f32_ubyte0_e32 v11, v11                               ; 7e16230b
	v_mul_f32_e32 v42, v27, v42                                 ; 0a54551b
	v_and_b32_e32 v39, s12, v39                                 ; 264e4e0c
	v_mac_f32_e32 v28, v22, v34                                 ; 2c384516
	v_cvt_f32_ubyte1_e32 v34, v33                               ; 7e442521
	v_mac_f32_e32 v28, v21, v41                                 ; 2c385315
	v_cvt_f32_ubyte3_e32 v41, v43                               ; 7e52292b
	v_mac_f32_e32 v28, v20, v11                                 ; 2c381714
	v_cvt_f32_ubyte2_e32 v11, v33                               ; 7e162721
	v_cvt_f32_ubyte0_e32 v33, v33                               ; 7e422321
	v_mul_f32_e32 v41, v9, v41                                  ; 0a525309
	v_mac_f32_e32 v42, v26, v11                                 ; 2c54171a
	v_cvt_f32_ubyte2_e32 v11, v43                               ; 7e16272b
	v_mac_f32_e32 v42, v25, v34                                 ; 2c544519
	v_cvt_f32_ubyte2_e32 v34, v39                               ; 7e442727
	v_mac_f32_e32 v41, v46, v11                                 ; 2c52172e
	v_cvt_f32_ubyte1_e32 v11, v43                               ; 7e16252b
	v_cvt_f32_ubyte0_e32 v43, v43                               ; 7e56232b
	v_mac_f32_e32 v42, v24, v33                                 ; 2c544318
	v_cvt_f32_ubyte3_e32 v33, v39                               ; 7e422927
	v_mul_f32_e32 v42, v42, v11                                 ; 0a54172a
	v_mac_f32_e32 v41, v45, v33                                 ; 2c52432d
	v_lshlrev_b32_e32 v33, 4, v36                               ; 24424884
	v_mac_f32_e32 v42, v28, v43                                 ; 2c54571c
	v_cvt_f32_ubyte1_e32 v28, v39                               ; 7e382527
	v_cvt_f32_ubyte0_e32 v39, v39                               ; 7e4e2327
	v_mov_b32_e32 v43, v9                                       ; 7e560309
	v_mac_f32_e32 v41, v44, v34                                 ; 2c52452c
	v_lshl_add_u32 v36, v36, 7, v33                             ; d1fd0024 04850f24
	v_mac_f32_e32 v42, v35, v28                                 ; 2c543923
	v_add_u32_e32 v34, 16, v36                                  ; 68444890
	v_mac_f32_e32 v42, v10, v39                                 ; 2c544f0a
	v_mov_b32_e32 v39, v8                                       ; 7e4e0308
	v_add_u32_e32 v35, v34, v4                                  ; 68460922
	v_add_u32_e32 v34, v34, v3                                  ; 68440722
	buffer_load_dwordx4 v[8:11], v36, s[24:27], 0 offen         ; e05c1000 80060824
	buffer_load_dword v35, v35, s[24:27], 0 offen               ; e0501000 80062323
	buffer_load_dword v34, v34, s[24:27], 0 offen               ; e0501000 80062222
	v_cvt_f32_f16_sdwa v28, v40 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e3816f9 00050628
	v_cvt_f32_f16_e32 v40, v40                                  ; 7e501728
	v_add_u32_e32 v0, 4, v0                                     ; 68000084
	s_waitcnt vmcnt(5)                                          ; bf8c3f75
	v_bfe_u32 v32, v32, v2, 16                                  ; d1c80020 02420520
	v_cndmask_b32_sdwa v30, v30, v30, vcc dst_sel:WORD_0 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 003c3cf9 0605141e
	v_cndmask_b32_sdwa v30, v31, v31, vcc dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 003c3ef9 0605151f
	s_waitcnt vmcnt(4)                                          ; bf8c3f74
	v_and_b32_e32 v36, s5, v38                                  ; 26484c05
	v_mad_f32 v6, -v28, v41, v6                                 ; d1c10006 241a531c
	v_cmp_le_u32_e64 s[14:15], s3, v0                           ; d0cb000e 00020003
	v_lshl_or_b32 v32, v32, 12, v32                             ; d2000020 04811920
	v_and_b32_e32 v31, s9, v30                                  ; 263e3c09
	v_cvt_f32_ubyte2_e32 v41, v36                               ; 7e522724
	v_lshrrev_b32_e32 v38, 4, v38                               ; 204c4c84
	v_mac_f32_e32 v6, v40, v42                                  ; 2c0c5528
	v_cvt_f32_ubyte3_e32 v40, v36                               ; 7e502924
	v_cvt_f32_ubyte1_e32 v42, v36                               ; 7e542524
	v_cvt_f32_ubyte0_e32 v36, v36                               ; 7e482324
	v_lshrrev_b32_e32 v31, 2, v31                               ; 203e3e82
	v_and_b32_e32 v38, s5, v38                                  ; 264c4c05
	v_mul_f32_e32 v40, v15, v40                                 ; 0a50510f
	v_and_or_b32 v32, s5, v32, v31                              ; d2010020 047e4005
	v_cvt_f32_ubyte2_e32 v31, v38                               ; 7e3e2726
	v_cvt_f32_ubyte3_e32 v28, v38                               ; 7e382926
	v_mac_f32_e32 v40, v14, v41                                 ; 2c50530e
	v_cvt_f32_ubyte3_e32 v33, v32                               ; 7e422920
	v_mul_f32_e32 v28, v19, v28                                 ; 0a383913
	v_mac_f32_e32 v40, v13, v42                                 ; 2c50550d
	v_mul_f32_e32 v33, v43, v33                                 ; 0a42432b
	v_mac_f32_e32 v28, v18, v31                                 ; 2c383f12
	v_mac_f32_e32 v40, v12, v36                                 ; 2c50490c
	v_cvt_f32_ubyte1_e32 v36, v38                               ; 7e482526
	v_cvt_f32_ubyte0_e32 v38, v38                               ; 7e4c2326
	v_mac_f32_e32 v28, v17, v36                                 ; 2c384911
	v_mac_f32_e32 v28, v16, v38                                 ; 2c384d10
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_and_b32_e32 v38, s5, v37                                  ; 264c4a05
	v_lshrrev_b32_e32 v37, 4, v37                               ; 204a4a84
	v_cvt_f32_ubyte2_e32 v42, v38                               ; 7e542726
	v_cvt_f32_ubyte1_e32 v31, v38                               ; 7e3e2526
	v_cvt_f32_ubyte3_e32 v41, v38                               ; 7e522926
	v_cvt_f32_ubyte0_e32 v38, v38                               ; 7e4c2326
	v_and_b32_e32 v37, s5, v37                                  ; 264a4a05
	v_mul_f32_e32 v41, v23, v41                                 ; 0a525317
	v_and_b32_e32 v30, s12, v30                                 ; 263c3c0c
	v_cvt_f32_ubyte3_e32 v36, v37                               ; 7e482925
	v_mac_f32_e32 v41, v22, v42                                 ; 2c525516
	v_cvt_f32_ubyte1_e32 v42, v37                               ; 7e542525
	v_mul_f32_e32 v36, v27, v36                                 ; 0a48491b
	v_mac_f32_e32 v41, v21, v31                                 ; 2c523f15
	v_cvt_f32_ubyte2_e32 v31, v32                               ; 7e3e2720
	v_mac_f32_e32 v41, v20, v38                                 ; 2c524d14
	v_cvt_f32_ubyte2_e32 v38, v37                               ; 7e4c2725
	v_cvt_f32_ubyte0_e32 v37, v37                               ; 7e4a2325
	v_mac_f32_e32 v33, v46, v31                                 ; 2c423f2e
	v_cvt_f32_ubyte1_e32 v31, v30                               ; 7e3e251e
	v_mac_f32_e32 v36, v26, v38                                 ; 2c484d1a
	v_cvt_f32_ubyte2_e32 v38, v30                               ; 7e4c271e
	v_mac_f32_e32 v36, v25, v42                                 ; 2c485519
	v_cvt_f32_ubyte1_e32 v42, v32                               ; 7e542520
	v_cvt_f32_ubyte0_e32 v32, v32                               ; 7e402320
	v_mac_f32_e32 v36, v24, v37                                 ; 2c484b18
	v_cvt_f32_ubyte3_e32 v37, v30                               ; 7e4a291e
	v_cvt_f32_ubyte0_e32 v30, v30                               ; 7e3c231e
	v_mul_f32_e32 v36, v36, v42                                 ; 0a485524
	v_mac_f32_e32 v33, v45, v37                                 ; 2c424b2d
	v_mac_f32_e32 v36, v41, v32                                 ; 2c484129
	v_cvt_f32_f16_sdwa v32, v29 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e4016f9 0005061d
	v_cvt_f32_f16_e32 v29, v29                                  ; 7e3a171d
	v_mac_f32_e32 v33, v44, v38                                 ; 2c424d2c
	v_mac_f32_e32 v36, v28, v31                                 ; 2c483f1c
	v_mad_f32 v7, -v32, v33, v7                                 ; d1c10007 241e4320
	v_mac_f32_e32 v36, v40, v30                                 ; 2c483d28
	v_mac_f32_e32 v7, v29, v36                                  ; 2c0e491d
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_cndmask_b32_sdwa v33, v9, v9, vcc dst_sel:WORD_0 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 004212f9 06051409
	v_cndmask_b32_sdwa v33, v10, v10, vcc dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 004214f9 0605150a
	v_bfe_u32 v11, v11, v2, 16                                  ; d1c8000b 0242050b
	v_and_b32_e32 v36, s9, v33                                  ; 26484209
	v_and_b32_e32 v33, s12, v33                                 ; 2642420c
	v_lshl_or_b32 v11, v11, 12, v11                             ; d200000b 042d190b
	v_lshrrev_b32_e32 v36, 2, v36                               ; 20484882
	v_cvt_f32_ubyte2_e32 v41, v33                               ; 7e522721
	v_cvt_f32_ubyte3_e32 v40, v33                               ; 7e502921
	v_and_or_b32 v11, s5, v11, v36                              ; d201000b 04921605
	v_cvt_f32_ubyte2_e32 v38, v11                               ; 7e4c270b
	v_cvt_f32_ubyte1_e32 v42, v11                               ; 7e54250b
	v_cvt_f32_ubyte3_e32 v37, v11                               ; 7e4a290b
	v_cvt_f32_ubyte0_e32 v11, v11                               ; 7e16230b
	v_mul_f32_e32 v43, v43, v37                                 ; 0a564b2b
	v_mac_f32_e32 v43, v46, v38                                 ; 2c564d2e
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v46, s5, v35                                  ; 265c4605
	v_mac_f32_e32 v43, v45, v40                                 ; 2c56512d
	v_cvt_f32_f16_sdwa v45, v8 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e5a16f9 00050608
	v_cvt_f32_f16_e32 v8, v8                                    ; 7e101708
	v_lshrrev_b32_e32 v35, 4, v35                               ; 20464684
	v_cvt_f32_ubyte2_e32 v10, v46                               ; 7e14272e
	v_cvt_f32_ubyte3_e32 v9, v46                                ; 7e12292e
	v_mac_f32_e32 v43, v44, v41                                 ; 2c56532c
	v_cvt_f32_ubyte1_e32 v44, v33                               ; 7e582521
	v_cvt_f32_ubyte0_e32 v33, v33                               ; 7e422321
	v_and_b32_e32 v35, s5, v35                                  ; 26464605
	v_mul_f32_e32 v15, v15, v9                                  ; 0a1e130f
	v_mad_f32 v45, -v45, v43, v39                               ; d1c1002d 249e572d
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v31, s5, v34                                  ; 263e4405
	v_cvt_f32_ubyte2_e32 v29, v35                               ; 7e3a2723
	v_cvt_f32_ubyte3_e32 v28, v35                               ; 7e382923
	v_cvt_f32_ubyte1_e32 v30, v35                               ; 7e3c2523
	v_cvt_f32_ubyte0_e32 v35, v35                               ; 7e462323
	v_mac_f32_e32 v15, v14, v10                                 ; 2c1e150e
	v_cvt_f32_ubyte1_e32 v14, v46                               ; 7e1c252e
	v_cvt_f32_ubyte0_e32 v46, v46                               ; 7e5c232e
	v_cvt_f32_ubyte3_e32 v32, v31                               ; 7e40291f
	v_cvt_f32_ubyte1_e32 v36, v31                               ; 7e48251f
	v_mul_f32_e32 v19, v19, v28                                 ; 0a263913
	v_lshrrev_b32_e32 v34, 4, v34                               ; 20444484
	v_mac_f32_e32 v15, v13, v14                                 ; 2c1e1d0d
	v_mul_f32_e32 v23, v23, v32                                 ; 0a2e4117
	v_mac_f32_e32 v19, v18, v29                                 ; 2c263b12
	v_and_b32_e32 v34, s5, v34                                  ; 26444405
	v_mac_f32_e32 v15, v12, v46                                 ; 2c1e5d0c
	v_mac_f32_e32 v19, v17, v30                                 ; 2c263d11
	v_cvt_f32_ubyte3_e32 v37, v34                               ; 7e4a2922
	v_cvt_f32_ubyte1_e32 v39, v34                               ; 7e4e2522
	v_cvt_f32_ubyte2_e32 v38, v34                               ; 7e4c2722
	v_cvt_f32_ubyte0_e32 v34, v34                               ; 7e442322
	v_mac_f32_e32 v19, v16, v35                                 ; 2c264710
	v_cvt_f32_ubyte2_e32 v35, v31                               ; 7e46271f
	v_cvt_f32_ubyte0_e32 v31, v31                               ; 7e3e231f
	v_mul_f32_e32 v27, v27, v37                                 ; 0a364b1b
	v_mac_f32_e32 v23, v22, v35                                 ; 2c2e4716
	v_mac_f32_e32 v27, v26, v38                                 ; 2c364d1a
	v_mac_f32_e32 v23, v21, v36                                 ; 2c2e4915
	v_mac_f32_e32 v27, v25, v39                                 ; 2c364f19
	v_mac_f32_e32 v23, v20, v31                                 ; 2c2e3f14
	v_mac_f32_e32 v27, v24, v34                                 ; 2c364518
	v_mul_f32_e32 v27, v27, v42                                 ; 0a36551b
	v_mac_f32_e32 v27, v23, v11                                 ; 2c361717
	v_mac_f32_e32 v27, v19, v44                                 ; 2c365913
	v_mac_f32_e32 v27, v15, v33                                 ; 2c36430f
	v_mad_f32 v8, v8, v27, v45                                  ; d1c10008 04b63708
	s_and_saveexec_b64 s[12:13], s[14:15]                       ; be8c200e
BB11:
	s_andn2_wrexec_b64 s[12:13], s[12:13]                       ; be8c360c
	s_cbranch_scc1 BB6                                          ; bf85fe6a
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
	s_branch BB131                                              ; bf82031f
BB48:
	s_cmp_lt_u32 s16, s4                                        ; bf0a0410
	s_cbranch_scc0 BB131                                        ; bf84031d
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
	s_cbranch_execz BB75                                        ; bf8801c9
BB53:
	s_mov_b32 s0, s2                                            ; be800002
	s_movk_i32 s1, 0x8000                                       ; b0018000
	s_load_dwordx4 s[12:15], s[0:1], 0x10                       ; c00a0300 00000010
	s_mul_i32 s6, s6, s17                                       ; 92061106
	v_lshlrev_b32_e32 v2, 4, v2                                 ; 24040484
	s_cmp_lg_i32 s4, 0                                          ; bf018004
	s_mov_b64 s[10:11], exec                                    ; be8a017e
	v_mov_b32_e32 v3, 0                                         ; 7e060280
	v_mov_b32_e32 v5, 0                                         ; 7e0a0280
	v_mov_b32_e32 v6, 0                                         ; 7e0c0280
	v_mov_b32_e32 v7, 0                                         ; 7e0e0280
	s_branch BB54                                               ; bf820004
	s_nop 0                                                     ; bf800000
	(then repeated 1 times)
BB71:
	s_mov_b64 exec, s[20:21]                                    ; befe0114
	s_cmp_lg_i32 s9, 0                                          ; bf018009
BB54:
	v_lshl_add_u32 v8, v0, 8, v1                                ; d1fd0008 04051100
	v_add_u32_e32 v9, s6, v8                                    ; 68121006
	v_add_u32_e32 v8, 0x80, v8                                  ; 681010ff 00000080
	v_lshrrev_b32_e32 v9, 2, v9                                 ; 20121282
	v_add_u32_e32 v8, s6, v8                                    ; 68101006
	v_lshlrev_b32_e32 v9, 4, v9                                 ; 24121284
	v_lshrrev_b32_e32 v8, 2, v8                                 ; 20101082
	v_lshlrev_b32_e32 v8, 4, v8                                 ; 24101084
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_load_dwordx4 v[12:15], v9, s[12:15], 0 offen         ; e05c1000 80030c09
	buffer_load_dwordx4 v[16:19], v9, s[12:15], 0 offen offset:128 ; e05c1080 80031009
	buffer_load_dwordx4 v[20:23], v8, s[12:15], 0 offen         ; e05c1000 80031408
	buffer_load_dwordx4 v[8:11], v8, s[12:15], 0 offen offset:128 ; e05c1080 80030808
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_add_f32_e32 v24, v12, v13                                 ; 02301b0c
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_add_f32_e32 v25, v16, v17                                 ; 02322310
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_add_f32_e32 v26, v20, v21                                 ; 02342b14
	v_add_f32_e32 v24, v24, v14                                 ; 02301d18
	v_add_f32_e32 v25, v25, v18                                 ; 02322519
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_add_f32_e32 v27, v8, v9                                   ; 02361308
	v_add_f32_e32 v26, v26, v22                                 ; 02342d1a
	v_add_f32_e32 v24, v24, v15                                 ; 02301f18
	v_add_f32_e32 v25, v25, v19                                 ; 02322719
	v_add_f32_e32 v27, v27, v10                                 ; 0236151b
	v_add_f32_e32 v26, v26, v23                                 ; 02342f1a
	v_add_f32_e32 v27, v27, v11                                 ; 0236171b
	s_cbranch_scc0 BB65                                         ; bf84018d
BB55:
	s_load_dwordx4 s[20:23], s[0:1], 0x0                        ; c00a0500 00000000
	s_mul_i32 s5, s16, s3                                       ; 92050310
	s_mov_b32 s9, src_scc                                       ; be8900fd
	v_add_u32_e32 v32, 64, v4                                   ; 684008c0
	s_add_u32 s5, s19, s5                                       ; 80050513
	v_add_u32_e32 v28, s5, v0                                   ; 68380005
	v_lshlrev_b32_e32 v29, 4, v28                               ; 243a3884
	v_lshl_add_u32 v28, v28, 7, v29                             ; d1fd001c 04750f1c
	v_add_u32_e32 v30, 16, v28                                  ; 683c3890
	v_add_u32_e32 v31, v30, v4                                  ; 683e091e
	v_add_u32_e32 v30, v30, v32                                 ; 683c411e
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_load_dwordx4 v[36:39], v28, s[20:23], 0 offen        ; e05c1000 8005241c
	buffer_load_dword v31, v31, s[20:23], 0 offen               ; e0501000 80051f1f
	buffer_load_dword v30, v30, s[20:23], 0 offen               ; e0501000 80051e1e
	s_bitreplicate_b64_b32 vcc, 0xf0f0f0f                       ; beea37ff 0f0f0f0f
	s_mov_b32 s18, 0xf0f0f0f                                    ; be9200ff 0f0f0f0f
	s_cmp_lt_u32 1, s4                                          ; bf0a0481
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_bfe_u32 v39, v39, v2, 16                                  ; d1c80027 02420527
	v_cndmask_b32_sdwa v33, v37, v37, vcc dst_sel:WORD_0 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 00424af9 06051425
	v_cndmask_b32_sdwa v33, v38, v38, vcc dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 00424cf9 06051526
	v_lshl_or_b32 v39, v39, 12, v39                             ; d2000027 049d1927
	v_and_b32_e32 v34, 0xc0c0c0c0, v33                          ; 264442ff c0c0c0c0
	v_and_b32_e32 v33, 0x3f3f3f3f, v33                          ; 264242ff 3f3f3f3f
	v_cvt_f32_f16_sdwa v43, v36 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e5616f9 00050624
	v_lshrrev_b32_e32 v34, 2, v34                               ; 20444482
	v_cvt_f32_f16_e32 v36, v36                                  ; 7e481724
	v_cvt_f32_ubyte1_e32 v42, v33                               ; 7e542521
	v_cvt_f32_ubyte3_e32 v38, v33                               ; 7e4c2921
	v_cvt_f32_ubyte2_e32 v40, v33                               ; 7e502721
	v_cvt_f32_ubyte0_e32 v33, v33                               ; 7e422321
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v44, s18, v31                                 ; 26583e12
	v_and_or_b32 v39, s18, v39, v34                             ; d2010027 048a4e12
	v_cvt_f32_ubyte3_e32 v45, v44                               ; 7e5a292c
	v_cvt_f32_ubyte2_e32 v46, v44                               ; 7e5c272c
	v_cvt_f32_ubyte1_e32 v41, v39                               ; 7e522527
	v_cvt_f32_ubyte3_e32 v35, v39                               ; 7e462927
	v_cvt_f32_ubyte2_e32 v37, v39                               ; 7e4a2727
	v_cvt_f32_ubyte0_e32 v39, v39                               ; 7e4e2327
	v_mul_f32_e32 v45, v15, v45                                 ; 0a5a5b0f
	v_lshrrev_b32_e32 v31, 4, v31                               ; 203e3e84
	v_mul_f32_e32 v35, v27, v35                                 ; 0a46471b
	v_mac_f32_e32 v45, v14, v46                                 ; 2c5a5d0e
	v_cvt_f32_ubyte1_e32 v46, v44                               ; 7e5c252c
	v_cvt_f32_ubyte0_e32 v44, v44                               ; 7e58232c
	v_and_b32_e32 v31, s18, v31                                 ; 263e3e12
	v_mac_f32_e32 v35, v26, v37                                 ; 2c464b1a
	v_mac_f32_e32 v45, v13, v46                                 ; 2c5a5d0d
	v_cvt_f32_ubyte2_e32 v28, v31                               ; 7e38271f
	v_cvt_f32_ubyte3_e32 v46, v31                               ; 7e5c291f
	v_cvt_f32_ubyte1_e32 v29, v31                               ; 7e3a251f
	v_cvt_f32_ubyte0_e32 v31, v31                               ; 7e3e231f
	v_mac_f32_e32 v35, v25, v38                                 ; 2c464d19
	v_mac_f32_e32 v45, v12, v44                                 ; 2c5a590c
	v_mul_f32_e32 v46, v19, v46                                 ; 0a5c5d13
	v_mac_f32_e32 v35, v24, v40                                 ; 2c465118
	v_mac_f32_e32 v46, v18, v28                                 ; 2c5c3912
	v_mad_f32 v3, -v43, v35, v3                                 ; d1c10003 240e472b
	v_mac_f32_e32 v46, v17, v29                                 ; 2c5c3b11
	v_mac_f32_e32 v46, v16, v31                                 ; 2c5c3f10
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v31, s18, v30                                 ; 263e3c12
	v_lshrrev_b32_e32 v30, 4, v30                               ; 203c3c84
	v_cvt_f32_ubyte3_e32 v34, v31                               ; 7e44291f
	v_cvt_f32_ubyte2_e32 v35, v31                               ; 7e46271f
	v_cvt_f32_ubyte1_e32 v37, v31                               ; 7e4a251f
	v_cvt_f32_ubyte0_e32 v31, v31                               ; 7e3e231f
	v_and_b32_e32 v30, s18, v30                                 ; 263c3c12
	v_mul_f32_e32 v34, v23, v34                                 ; 0a444517
	v_cvt_f32_ubyte3_e32 v38, v30                               ; 7e4c291e
	v_cvt_f32_ubyte1_e32 v43, v30                               ; 7e56251e
	v_cvt_f32_ubyte2_e32 v40, v30                               ; 7e50271e
	v_cvt_f32_ubyte0_e32 v30, v30                               ; 7e3c231e
	v_mac_f32_e32 v34, v22, v35                                 ; 2c444716
	v_mul_f32_e32 v38, v11, v38                                 ; 0a4c4d0b
	v_mac_f32_e32 v34, v21, v37                                 ; 2c444b15
	v_mac_f32_e32 v38, v10, v40                                 ; 2c4c510a
	v_mac_f32_e32 v34, v20, v31                                 ; 2c443f14
	v_mac_f32_e32 v38, v9, v43                                  ; 2c4c5709
	v_mac_f32_e32 v38, v8, v30                                  ; 2c4c3d08
	v_mul_f32_e32 v38, v38, v41                                 ; 0a4c5326
	v_mac_f32_e32 v38, v34, v39                                 ; 2c4c4f22
	v_mac_f32_e32 v38, v46, v42                                 ; 2c4c552e
	v_mac_f32_e32 v38, v45, v33                                 ; 2c4c432d
	v_mac_f32_e32 v3, v36, v38                                  ; 2c064d24
	s_cbranch_scc0 BB66                                         ; bf840126
BB56:
	s_add_u32 s5, s16, 1                                        ; 80058110
	s_mul_i32 s5, s5, s3                                        ; 92050305
	s_add_u32 s5, s19, s5                                       ; 80050513
	v_add_u32_e32 v28, s5, v0                                   ; 68380005
	v_lshlrev_b32_e32 v29, 4, v28                               ; 243a3884
	v_lshl_add_u32 v28, v28, 7, v29                             ; d1fd001c 04750f1c
	v_add_u32_e32 v30, 16, v28                                  ; 683c3890
	v_add_u32_e32 v31, v30, v4                                  ; 683e091e
	v_add_u32_e32 v30, v30, v32                                 ; 683c411e
	buffer_load_dwordx4 v[36:39], v28, s[20:23], 0 offen        ; e05c1000 8005241c
	buffer_load_dword v31, v31, s[20:23], 0 offen               ; e0501000 80051f1f
	buffer_load_dword v30, v30, s[20:23], 0 offen               ; e0501000 80051e1e
	s_mov_b32 s18, 0xf0f0f0f                                    ; be9200ff 0f0f0f0f
	s_cmp_lt_u32 2, s4                                          ; bf0a0482
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_bfe_u32 v39, v39, v2, 16                                  ; d1c80027 02420527
	v_cndmask_b32_sdwa v33, v37, v37, vcc dst_sel:WORD_0 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 00424af9 06051425
	v_cndmask_b32_sdwa v33, v38, v38, vcc dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 00424cf9 06051526
	v_lshl_or_b32 v39, v39, 12, v39                             ; d2000027 049d1927
	v_and_b32_e32 v34, 0xc0c0c0c0, v33                          ; 264442ff c0c0c0c0
	v_and_b32_e32 v33, 0x3f3f3f3f, v33                          ; 264242ff 3f3f3f3f
	v_cvt_f32_f16_sdwa v43, v36 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e5616f9 00050624
	v_lshrrev_b32_e32 v34, 2, v34                               ; 20444482
	v_cvt_f32_ubyte1_e32 v42, v33                               ; 7e542521
	v_cvt_f32_f16_e32 v36, v36                                  ; 7e481724
	v_cvt_f32_ubyte3_e32 v38, v33                               ; 7e4c2921
	v_cvt_f32_ubyte2_e32 v40, v33                               ; 7e502721
	v_cvt_f32_ubyte0_e32 v33, v33                               ; 7e422321
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v44, s18, v31                                 ; 26583e12
	v_and_or_b32 v39, s18, v39, v34                             ; d2010027 048a4e12
	v_cvt_f32_ubyte3_e32 v45, v44                               ; 7e5a292c
	v_cvt_f32_ubyte2_e32 v46, v44                               ; 7e5c272c
	v_cvt_f32_ubyte3_e32 v35, v39                               ; 7e462927
	v_cvt_f32_ubyte2_e32 v37, v39                               ; 7e4a2727
	v_cvt_f32_ubyte1_e32 v41, v39                               ; 7e522527
	v_cvt_f32_ubyte0_e32 v39, v39                               ; 7e4e2327
	v_mul_f32_e32 v45, v15, v45                                 ; 0a5a5b0f
	v_lshrrev_b32_e32 v31, 4, v31                               ; 203e3e84
	v_mul_f32_e32 v35, v27, v35                                 ; 0a46471b
	v_mac_f32_e32 v45, v14, v46                                 ; 2c5a5d0e
	v_cvt_f32_ubyte1_e32 v46, v44                               ; 7e5c252c
	v_cvt_f32_ubyte0_e32 v44, v44                               ; 7e58232c
	v_and_b32_e32 v31, s18, v31                                 ; 263e3e12
	v_mac_f32_e32 v35, v26, v37                                 ; 2c464b1a
	v_mac_f32_e32 v45, v13, v46                                 ; 2c5a5d0d
	v_cvt_f32_ubyte3_e32 v46, v31                               ; 7e5c291f
	v_cvt_f32_ubyte1_e32 v29, v31                               ; 7e3a251f
	v_cvt_f32_ubyte2_e32 v28, v31                               ; 7e38271f
	v_cvt_f32_ubyte0_e32 v31, v31                               ; 7e3e231f
	v_mac_f32_e32 v35, v25, v38                                 ; 2c464d19
	v_mac_f32_e32 v45, v12, v44                                 ; 2c5a590c
	v_mul_f32_e32 v46, v19, v46                                 ; 0a5c5d13
	v_mac_f32_e32 v35, v24, v40                                 ; 2c465118
	v_mac_f32_e32 v46, v18, v28                                 ; 2c5c3912
	v_mad_f32 v5, -v43, v35, v5                                 ; d1c10005 2416472b
	v_mac_f32_e32 v46, v17, v29                                 ; 2c5c3b11
	v_mac_f32_e32 v46, v16, v31                                 ; 2c5c3f10
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v31, s18, v30                                 ; 263e3c12
	v_lshrrev_b32_e32 v30, 4, v30                               ; 203c3c84
	v_cvt_f32_ubyte2_e32 v35, v31                               ; 7e46271f
	v_cvt_f32_ubyte3_e32 v34, v31                               ; 7e44291f
	v_cvt_f32_ubyte1_e32 v37, v31                               ; 7e4a251f
	v_cvt_f32_ubyte0_e32 v31, v31                               ; 7e3e231f
	v_and_b32_e32 v30, s18, v30                                 ; 263c3c12
	v_mul_f32_e32 v34, v23, v34                                 ; 0a444517
	v_cvt_f32_ubyte1_e32 v43, v30                               ; 7e56251e
	v_cvt_f32_ubyte2_e32 v40, v30                               ; 7e50271e
	v_cvt_f32_ubyte3_e32 v38, v30                               ; 7e4c291e
	v_cvt_f32_ubyte0_e32 v30, v30                               ; 7e3c231e
	v_mac_f32_e32 v34, v22, v35                                 ; 2c444716
	v_mul_f32_e32 v38, v11, v38                                 ; 0a4c4d0b
	v_mac_f32_e32 v34, v21, v37                                 ; 2c444b15
	v_mac_f32_e32 v38, v10, v40                                 ; 2c4c510a
	v_mac_f32_e32 v34, v20, v31                                 ; 2c443f14
	v_mac_f32_e32 v38, v9, v43                                  ; 2c4c5709
	v_mac_f32_e32 v38, v8, v30                                  ; 2c4c3d08
	v_mul_f32_e32 v38, v38, v41                                 ; 0a4c5326
	v_mac_f32_e32 v38, v34, v39                                 ; 2c4c4f22
	v_mac_f32_e32 v38, v46, v42                                 ; 2c4c552e
	v_mac_f32_e32 v38, v45, v33                                 ; 2c4c432d
	v_mac_f32_e32 v5, v36, v38                                  ; 2c0a4d24
	s_cbranch_scc0 BB66                                         ; bf8400c4
BB57:
	s_add_u32 s5, s16, 2                                        ; 80058210
	s_mul_i32 s5, s5, s3                                        ; 92050305
	s_add_u32 s5, s19, s5                                       ; 80050513
	v_add_u32_e32 v28, s5, v0                                   ; 68380005
	v_lshlrev_b32_e32 v29, 4, v28                               ; 243a3884
	v_lshl_add_u32 v28, v28, 7, v29                             ; d1fd001c 04750f1c
	v_add_u32_e32 v30, 16, v28                                  ; 683c3890
	v_add_u32_e32 v31, v30, v4                                  ; 683e091e
	v_add_u32_e32 v30, v30, v32                                 ; 683c411e
	buffer_load_dwordx4 v[36:39], v28, s[20:23], 0 offen        ; e05c1000 8005241c
	buffer_load_dword v31, v31, s[20:23], 0 offen               ; e0501000 80051f1f
	buffer_load_dword v30, v30, s[20:23], 0 offen               ; e0501000 80051e1e
	s_mov_b32 s18, 0xf0f0f0f                                    ; be9200ff 0f0f0f0f
	s_cmp_lt_u32 3, s4                                          ; bf0a0483
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_bfe_u32 v39, v39, v2, 16                                  ; d1c80027 02420527
	v_cndmask_b32_sdwa v33, v37, v37, vcc dst_sel:WORD_0 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 00424af9 06051425
	v_cndmask_b32_sdwa v33, v38, v38, vcc dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 00424cf9 06051526
	v_lshl_or_b32 v39, v39, 12, v39                             ; d2000027 049d1927
	v_and_b32_e32 v34, 0xc0c0c0c0, v33                          ; 264442ff c0c0c0c0
	v_and_b32_e32 v33, 0x3f3f3f3f, v33                          ; 264242ff 3f3f3f3f
	v_cvt_f32_f16_sdwa v43, v36 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e5616f9 00050624
	v_lshrrev_b32_e32 v34, 2, v34                               ; 20444482
	v_cvt_f32_ubyte1_e32 v42, v33                               ; 7e542521
	v_cvt_f32_f16_e32 v36, v36                                  ; 7e481724
	v_cvt_f32_ubyte3_e32 v38, v33                               ; 7e4c2921
	v_cvt_f32_ubyte2_e32 v40, v33                               ; 7e502721
	v_cvt_f32_ubyte0_e32 v33, v33                               ; 7e422321
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v44, s18, v31                                 ; 26583e12
	v_and_or_b32 v39, s18, v39, v34                             ; d2010027 048a4e12
	v_cvt_f32_ubyte3_e32 v45, v44                               ; 7e5a292c
	v_cvt_f32_ubyte2_e32 v46, v44                               ; 7e5c272c
	v_cvt_f32_ubyte3_e32 v35, v39                               ; 7e462927
	v_cvt_f32_ubyte2_e32 v37, v39                               ; 7e4a2727
	v_cvt_f32_ubyte1_e32 v41, v39                               ; 7e522527
	v_cvt_f32_ubyte0_e32 v39, v39                               ; 7e4e2327
	v_mul_f32_e32 v45, v15, v45                                 ; 0a5a5b0f
	v_lshrrev_b32_e32 v31, 4, v31                               ; 203e3e84
	v_mul_f32_e32 v35, v27, v35                                 ; 0a46471b
	v_mac_f32_e32 v45, v14, v46                                 ; 2c5a5d0e
	v_cvt_f32_ubyte1_e32 v46, v44                               ; 7e5c252c
	v_cvt_f32_ubyte0_e32 v44, v44                               ; 7e58232c
	v_and_b32_e32 v31, s18, v31                                 ; 263e3e12
	v_mac_f32_e32 v35, v26, v37                                 ; 2c464b1a
	v_mac_f32_e32 v45, v13, v46                                 ; 2c5a5d0d
	v_cvt_f32_ubyte3_e32 v46, v31                               ; 7e5c291f
	v_cvt_f32_ubyte1_e32 v29, v31                               ; 7e3a251f
	v_cvt_f32_ubyte2_e32 v28, v31                               ; 7e38271f
	v_cvt_f32_ubyte0_e32 v31, v31                               ; 7e3e231f
	v_mac_f32_e32 v35, v25, v38                                 ; 2c464d19
	v_mac_f32_e32 v45, v12, v44                                 ; 2c5a590c
	v_mul_f32_e32 v46, v19, v46                                 ; 0a5c5d13
	v_mac_f32_e32 v35, v24, v40                                 ; 2c465118
	v_mac_f32_e32 v46, v18, v28                                 ; 2c5c3912
	v_mad_f32 v6, -v43, v35, v6                                 ; d1c10006 241a472b
	v_mac_f32_e32 v46, v17, v29                                 ; 2c5c3b11
	v_mac_f32_e32 v46, v16, v31                                 ; 2c5c3f10
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v31, s18, v30                                 ; 263e3c12
	v_lshrrev_b32_e32 v30, 4, v30                               ; 203c3c84
	v_cvt_f32_ubyte2_e32 v35, v31                               ; 7e46271f
	v_cvt_f32_ubyte3_e32 v34, v31                               ; 7e44291f
	v_cvt_f32_ubyte1_e32 v37, v31                               ; 7e4a251f
	v_cvt_f32_ubyte0_e32 v31, v31                               ; 7e3e231f
	v_and_b32_e32 v30, s18, v30                                 ; 263c3c12
	v_mul_f32_e32 v34, v23, v34                                 ; 0a444517
	v_cvt_f32_ubyte1_e32 v43, v30                               ; 7e56251e
	v_cvt_f32_ubyte2_e32 v40, v30                               ; 7e50271e
	v_cvt_f32_ubyte3_e32 v38, v30                               ; 7e4c291e
	v_cvt_f32_ubyte0_e32 v30, v30                               ; 7e3c231e
	v_mac_f32_e32 v34, v22, v35                                 ; 2c444716
	v_mul_f32_e32 v38, v11, v38                                 ; 0a4c4d0b
	v_mac_f32_e32 v34, v21, v37                                 ; 2c444b15
	v_mac_f32_e32 v38, v10, v40                                 ; 2c4c510a
	v_mac_f32_e32 v34, v20, v31                                 ; 2c443f14
	v_mac_f32_e32 v38, v9, v43                                  ; 2c4c5709
	v_mac_f32_e32 v38, v8, v30                                  ; 2c4c3d08
	v_mul_f32_e32 v38, v38, v41                                 ; 0a4c5326
	v_mac_f32_e32 v38, v34, v39                                 ; 2c4c4f22
	v_mac_f32_e32 v38, v46, v42                                 ; 2c4c552e
	v_mac_f32_e32 v38, v45, v33                                 ; 2c4c432d
	v_mac_f32_e32 v6, v36, v38                                  ; 2c0c4d24
	s_cbranch_scc0 BB66                                         ; bf840062
BB58:
	s_add_u32 s5, s16, 3                                        ; 80058310
	s_mul_i32 s5, s5, s3                                        ; 92050305
	s_add_u32 s5, s19, s5                                       ; 80050513
	v_add_u32_e32 v28, s5, v0                                   ; 68380005
	v_lshlrev_b32_e32 v29, 4, v28                               ; 243a3884
	v_lshl_add_u32 v28, v28, 7, v29                             ; d1fd001c 04750f1c
	v_add_u32_e32 v30, 16, v28                                  ; 683c3890
	v_add_u32_e32 v31, v30, v4                                  ; 683e091e
	v_add_u32_e32 v30, v30, v32                                 ; 683c411e
	buffer_load_dwordx4 v[32:35], v28, s[20:23], 0 offen        ; e05c1000 8005201c
	buffer_load_dword v31, v31, s[20:23], 0 offen               ; e0501000 80051f1f
	buffer_load_dword v30, v30, s[20:23], 0 offen               ; e0501000 80051e1e
	s_mov_b32 s18, 0xf0f0f0f                                    ; be9200ff 0f0f0f0f
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_bfe_u32 v35, v35, v2, 16                                  ; d1c80023 02420523
	v_cndmask_b32_sdwa v33, v33, v33, vcc dst_sel:WORD_0 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 004242f9 06051421
	v_cndmask_b32_sdwa v33, v34, v34, vcc dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 004244f9 06051522
	v_lshl_or_b32 v35, v35, 12, v35                             ; d2000023 048d1923
	v_and_b32_e32 v34, 0xc0c0c0c0, v33                          ; 264442ff c0c0c0c0
	v_and_b32_e32 v33, 0x3f3f3f3f, v33                          ; 264242ff 3f3f3f3f
	v_cvt_f32_f16_sdwa v42, v32 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e5416f9 00050620
	v_lshrrev_b32_e32 v34, 2, v34                               ; 20444482
	v_cvt_f32_f16_e32 v32, v32                                  ; 7e401720
	v_cvt_f32_ubyte3_e32 v38, v33                               ; 7e4c2921
	v_cvt_f32_ubyte2_e32 v39, v33                               ; 7e4e2721
	v_cvt_f32_ubyte1_e32 v41, v33                               ; 7e522521
	v_cvt_f32_ubyte0_e32 v33, v33                               ; 7e422321
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v43, s18, v31                                 ; 26563e12
	v_and_or_b32 v35, s18, v35, v34                             ; d2010023 048a4612
	v_cvt_f32_ubyte1_e32 v46, v43                               ; 7e5c252b
	v_cvt_f32_ubyte3_e32 v44, v43                               ; 7e58292b
	v_cvt_f32_ubyte2_e32 v45, v43                               ; 7e5a272b
	v_cvt_f32_ubyte0_e32 v43, v43                               ; 7e56232b
	v_cvt_f32_ubyte3_e32 v36, v35                               ; 7e482923
	v_cvt_f32_ubyte2_e32 v37, v35                               ; 7e4a2723
	v_cvt_f32_ubyte1_e32 v40, v35                               ; 7e502523
	v_cvt_f32_ubyte0_e32 v35, v35                               ; 7e462323
	v_lshrrev_b32_e32 v31, 4, v31                               ; 203e3e84
	v_mul_f32_e32 v15, v15, v44                                 ; 0a1e590f
	v_mul_f32_e32 v27, v27, v36                                 ; 0a36491b
	v_and_b32_e32 v31, s18, v31                                 ; 263e3e12
	v_mac_f32_e32 v15, v14, v45                                 ; 2c1e5b0e
	v_mac_f32_e32 v27, v26, v37                                 ; 2c364b1a
	v_mac_f32_e32 v15, v13, v46                                 ; 2c1e5d0d
	v_cvt_f32_ubyte3_e32 v46, v31                               ; 7e5c291f
	v_mac_f32_e32 v27, v25, v38                                 ; 2c364d19
	v_mac_f32_e32 v15, v12, v43                                 ; 2c1e570c
	v_mul_f32_e32 v19, v19, v46                                 ; 0a265d13
	v_cvt_f32_ubyte2_e32 v46, v31                               ; 7e5c271f
	v_mac_f32_e32 v27, v24, v39                                 ; 2c364f18
	v_mac_f32_e32 v19, v18, v46                                 ; 2c265d12
	v_cvt_f32_ubyte1_e32 v46, v31                               ; 7e5c251f
	v_cvt_f32_ubyte0_e32 v31, v31                               ; 7e3e231f
	v_mad_f32 v7, -v42, v27, v7                                 ; d1c10007 241e372a
	v_mac_f32_e32 v19, v17, v46                                 ; 2c265d11
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v46, s18, v30                                 ; 265c3c12
	v_lshrrev_b32_e32 v30, 4, v30                               ; 203c3c84
	v_mac_f32_e32 v19, v16, v31                                 ; 2c263f10
	v_cvt_f32_ubyte2_e32 v13, v46                               ; 7e1a272e
	v_cvt_f32_ubyte1_e32 v14, v46                               ; 7e1c252e
	v_cvt_f32_ubyte3_e32 v12, v46                               ; 7e18292e
	v_cvt_f32_ubyte0_e32 v46, v46                               ; 7e5c232e
	v_and_b32_e32 v30, s18, v30                                 ; 263c3c12
	v_mul_f32_e32 v23, v23, v12                                 ; 0a2e1917
	v_cvt_f32_ubyte2_e32 v17, v30                               ; 7e22271e
	v_cvt_f32_ubyte1_e32 v18, v30                               ; 7e24251e
	v_cvt_f32_ubyte3_e32 v16, v30                               ; 7e20291e
	v_cvt_f32_ubyte0_e32 v30, v30                               ; 7e3c231e
	v_mac_f32_e32 v23, v22, v13                                 ; 2c2e1b16
	v_mul_f32_e32 v11, v11, v16                                 ; 0a16210b
	v_mac_f32_e32 v23, v21, v14                                 ; 2c2e1d15
	v_mac_f32_e32 v11, v10, v17                                 ; 2c16230a
	v_mac_f32_e32 v23, v20, v46                                 ; 2c2e5d14
	v_mac_f32_e32 v11, v9, v18                                  ; 2c162509
	v_mac_f32_e32 v11, v8, v30                                  ; 2c163d08
	v_mul_f32_e32 v11, v11, v40                                 ; 0a16510b
	v_mac_f32_e32 v11, v23, v35                                 ; 2c164717
	v_mac_f32_e32 v11, v19, v41                                 ; 2c165313
	v_mac_f32_e32 v11, v15, v33                                 ; 2c16430f
	v_mac_f32_e32 v7, v32, v11                                  ; 2c0e1720
	s_branch BB66                                               ; bf820001
BB65:
	s_mov_b32 s9, src_scc                                       ; be8900fd
BB66:
	v_add_u32_e32 v0, 4, v0                                     ; 68000084
	s_mov_b64 s[20:21], exec                                    ; be94017e
	v_cmpx_le_u32_e32 vcc, s3, v0                               ; 7db60003
BB67:
	s_andn2_b64 s[20:21], s[20:21], exec                        ; 89947e14
	s_cbranch_scc1 BB71                                         ; bf85fe47
BB72:
	s_mov_b64 exec, s[10:11]                                    ; befe010a
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
