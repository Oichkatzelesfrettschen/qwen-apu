BB0:
	s_load_dword s0, s[14:15], 0x0                              ; c0020007 00000000
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_mul_i32 s0, s0, s18                                       ; 92001200
	s_add_u32 s16, s16, s0                                      ; 80100010
	s_lshl_b32 s16, s16, 2                                      ; 8e108210
	s_add_u32 s1, s16, 4                                        ; 80018410
	s_cmp_ge_u32 s4, s1                                         ; bf090104
	s_cbranch_scc0 BB42                                         ; bf8402ee
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
	s_mul_i32 s18, s18, s5                                      ; 92120512
	v_mov_b32_e32 v7, 0                                         ; 7e0e0280
	v_sub_u32_e32 v1, v2, v1                                    ; 6a020302
	v_bfe_u32 v3, v2, 2, 1                                      ; d1c80003 02050502
	v_lshrrev_b32_e32 v2, 3, v2                                 ; 20040483
	v_lshl_add_u32 v1, v1, 1, v3                                ; d1fd0001 040d0301
	v_mov_b32_e32 v3, 0                                         ; 7e060280
	v_lshlrev_b32_e32 v1, 2, v1                                 ; 24020282
	v_lshl_add_u32 v4, v2, 5, v1                                ; d1fd0004 04050b02
	v_lshl_add_u32 v1, v2, 6, v1                                ; d1fd0001 04050d02
	v_lshlrev_b32_e32 v2, 4, v2                                 ; 24040484
	s_branch BB5                                                ; bf8201a4
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
	s_mov_b32 s9, 0xc0c0c0c0                                    ; be8900ff c0c0c0c0
	s_mov_b32 s10, 0x3f3f3f3f                                   ; be8a00ff 3f3f3f3f
	s_add_u32 s11, s16, 2                                       ; 800b8210
	s_mul_i32 s11, s11, s3                                      ; 920b030b
	s_add_u32 s11, s18, s11                                     ; 800b0b12
	v_add_u32_e32 v33, s11, v0                                  ; 6842000b
	s_waitcnt vmcnt(9)                                          ; bf8c3f79
	v_add_f32_e32 v34, v12, v13                                 ; 02441b0c
	s_waitcnt vmcnt(8)                                          ; bf8c3f78
	v_add_f32_e32 v35, v16, v17                                 ; 02462310
	s_waitcnt vmcnt(7)                                          ; bf8c3f77
	v_add_f32_e32 v44, v20, v21                                 ; 02582b14
	v_add_f32_e32 v34, v34, v14                                 ; 02441d22
	v_add_f32_e32 v35, v35, v18                                 ; 02462523
	s_waitcnt vmcnt(6)                                          ; bf8c3f76
	v_add_f32_e32 v45, v8, v9                                   ; 025a1308
	v_add_f32_e32 v44, v44, v22                                 ; 02582d2c
	v_add_f32_e32 v34, v34, v15                                 ; 02441f22
	v_add_f32_e32 v35, v35, v19                                 ; 02462723
	v_add_f32_e32 v45, v45, v10                                 ; 025a152d
	v_add_f32_e32 v44, v44, v23                                 ; 02582f2c
	v_add_f32_e32 v45, v45, v11                                 ; 025a172d
	s_waitcnt vmcnt(5)                                          ; bf8c3f75
	v_bfe_u32 v39, v39, v2, 16                                  ; d1c80027 02420527
	v_cndmask_b32_sdwa v46, v37, v37, vcc dst_sel:WORD_0 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 005c4af9 06051425
	v_cndmask_b32_sdwa v46, v38, v38, vcc dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 005c4cf9 06051526
	s_waitcnt vmcnt(4)                                          ; bf8c3f74
	v_and_b32_e32 v25, s5, v27                                  ; 26323605
	v_lshrrev_b32_e32 v27, 4, v27                               ; 20363684
	v_lshl_or_b32 v39, v39, 12, v39                             ; d2000027 049d1927
	v_and_b32_e32 v24, s9, v46                                  ; 26305c09
	v_cvt_f32_ubyte3_e32 v29, v25                               ; 7e3a2919
	v_cvt_f32_ubyte1_e32 v37, v25                               ; 7e4a2519
	v_cvt_f32_ubyte2_e32 v30, v25                               ; 7e3c2719
	v_cvt_f32_ubyte0_e32 v25, v25                               ; 7e322319
	v_and_b32_e32 v27, s5, v27                                  ; 26363605
	v_lshrrev_b32_e32 v24, 2, v24                               ; 20303082
	v_mul_f32_e32 v29, v15, v29                                 ; 0a3a3b0f
	v_cvt_f32_ubyte3_e32 v38, v27                               ; 7e4c291b
	v_and_or_b32 v39, s5, v39, v24                              ; d2010027 04624e05
	v_cvt_f32_ubyte2_e32 v24, v27                               ; 7e30271b
	v_mac_f32_e32 v29, v14, v30                                 ; 2c3a3d0e
	v_mul_f32_e32 v38, v19, v38                                 ; 0a4c4d13
	v_mac_f32_e32 v29, v13, v37                                 ; 2c3a4b0d
	v_mac_f32_e32 v38, v18, v24                                 ; 2c4c3112
	v_mac_f32_e32 v29, v12, v25                                 ; 2c3a330c
	v_cvt_f32_ubyte1_e32 v25, v27                               ; 7e32251b
	v_cvt_f32_ubyte0_e32 v27, v27                               ; 7e36231b
	v_mac_f32_e32 v38, v17, v25                                 ; 2c4c3311
	v_mac_f32_e32 v38, v16, v27                                 ; 2c4c3710
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_and_b32_e32 v27, s5, v26                                  ; 26363405
	v_lshrrev_b32_e32 v26, 4, v26                               ; 20343484
	v_cvt_f32_ubyte1_e32 v24, v27                               ; 7e30251b
	v_cvt_f32_ubyte3_e32 v30, v27                               ; 7e3c291b
	v_cvt_f32_ubyte2_e32 v37, v27                               ; 7e4a271b
	v_cvt_f32_ubyte0_e32 v27, v27                               ; 7e36231b
	v_and_b32_e32 v26, s5, v26                                  ; 26343405
	v_mul_f32_e32 v30, v23, v30                                 ; 0a3c3d17
	v_and_b32_e32 v46, s10, v46                                 ; 265c5c0a
	v_cvt_f32_ubyte3_e32 v25, v26                               ; 7e32291a
	v_mac_f32_e32 v30, v22, v37                                 ; 2c3c4b16
	v_cvt_f32_ubyte1_e32 v37, v26                               ; 7e4a251a
	v_mul_f32_e32 v25, v11, v25                                 ; 0a32330b
	v_mac_f32_e32 v30, v21, v24                                 ; 2c3c3115
	v_cvt_f32_ubyte3_e32 v24, v39                               ; 7e302927
	v_mac_f32_e32 v30, v20, v27                                 ; 2c3c3714
	v_cvt_f32_ubyte2_e32 v27, v26                               ; 7e36271a
	v_cvt_f32_ubyte0_e32 v26, v26                               ; 7e34231a
	v_mul_f32_e32 v24, v45, v24                                 ; 0a30312d
	v_mac_f32_e32 v25, v10, v27                                 ; 2c32370a
	v_cvt_f32_ubyte3_e32 v27, v46                               ; 7e36292e
	v_mac_f32_e32 v25, v9, v37                                  ; 2c324b09
	v_cvt_f32_ubyte2_e32 v37, v46                               ; 7e4a272e
	v_mac_f32_e32 v25, v8, v26                                  ; 2c323508
	v_cvt_f32_ubyte2_e32 v26, v39                               ; 7e342727
	v_mac_f32_e32 v24, v44, v26                                 ; 2c30352c
	v_cvt_f32_ubyte1_e32 v26, v39                               ; 7e342527
	v_cvt_f32_ubyte0_e32 v39, v39                               ; 7e4e2327
	v_mac_f32_e32 v24, v35, v27                                 ; 2c303723
	v_cvt_f32_ubyte1_e32 v27, v46                               ; 7e36252e
	v_cvt_f32_ubyte0_e32 v46, v46                               ; 7e5c232e
	v_mul_f32_e32 v25, v25, v26                                 ; 0a323519
	v_mac_f32_e32 v24, v34, v37                                 ; 2c304b22
	v_mac_f32_e32 v25, v30, v39                                 ; 2c324f1e
	v_lshlrev_b32_e32 v30, 4, v33                               ; 243c4284
	v_mov_b32_e32 v39, v28                                      ; 7e4e031c
	v_mac_f32_e32 v25, v38, v27                                 ; 2c323726
	v_lshl_add_u32 v33, v33, 7, v30                             ; d1fd0021 04790f21
	v_mac_f32_e32 v25, v29, v46                                 ; 2c325d1d
	v_add_u32_e32 v37, 16, v33                                  ; 684a4290
	v_add_u32_e32 v38, v37, v4                                  ; 684c0925
	v_add_u32_e32 v37, v37, v28                                 ; 684a3925
	buffer_load_dwordx4 v[26:29], v33, s[24:27], 0 offen        ; e05c1000 80061a21
	buffer_load_dword v38, v38, s[24:27], 0 offen               ; e0501000 80062626
	buffer_load_dword v37, v37, s[24:27], 0 offen               ; e0501000 80062525
	v_cvt_f32_f16_sdwa v46, v36 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e5c16f9 00050624
	v_cvt_f32_f16_e32 v36, v36                                  ; 7e481724
	s_add_u32 s12, s16, 3                                       ; 800c8310
	s_waitcnt vmcnt(5)                                          ; bf8c3f75
	v_bfe_u32 v43, v43, v2, 16                                  ; d1c8002b 0242052b
	v_cndmask_b32_sdwa v41, v41, v41, vcc dst_sel:WORD_0 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 005252f9 06051429
	v_cndmask_b32_sdwa v41, v42, v42, vcc dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 005254f9 0605152a
	v_mad_f32 v3, -v46, v24, v3                                 ; d1c10003 240e312e
	s_waitcnt vmcnt(4)                                          ; bf8c3f74
	v_and_b32_e32 v24, s5, v32                                  ; 26304005
	s_mul_i32 s12, s12, s3                                      ; 920c030c
	v_lshl_or_b32 v43, v43, 12, v43                             ; d200002b 04ad192b
	v_and_b32_e32 v42, s9, v41                                  ; 26545209
	v_mac_f32_e32 v3, v36, v25                                  ; 2c063324
	v_cvt_f32_ubyte1_e32 v33, v24                               ; 7e422518
	v_cvt_f32_ubyte2_e32 v30, v24                               ; 7e3c2718
	v_cvt_f32_ubyte3_e32 v25, v24                               ; 7e322918
	v_cvt_f32_ubyte0_e32 v24, v24                               ; 7e302318
	v_lshrrev_b32_e32 v32, 4, v32                               ; 20404084
	s_add_u32 s12, s18, s12                                     ; 800c0c12
	v_lshrrev_b32_e32 v42, 2, v42                               ; 20545482
	v_mul_f32_e32 v25, v15, v25                                 ; 0a32330f
	v_and_b32_e32 v32, s5, v32                                  ; 26404005
	v_add_u32_e32 v46, s12, v0                                  ; 685c000c
	v_and_or_b32 v43, s5, v43, v42                              ; d201002b 04aa5605
	v_mac_f32_e32 v25, v14, v30                                 ; 2c323d0e
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_and_b32_e32 v30, s5, v31                                  ; 263c3e05
	v_cvt_f32_ubyte3_e32 v36, v32                               ; 7e482920
	v_cvt_f32_ubyte2_e32 v42, v32                               ; 7e542720
	v_mac_f32_e32 v25, v13, v33                                 ; 2c32430d
	v_cvt_f32_ubyte2_e32 v33, v30                               ; 7e42271e
	v_mul_f32_e32 v36, v19, v36                                 ; 0a484913
	v_lshrrev_b32_e32 v31, 4, v31                               ; 203e3e84
	v_mac_f32_e32 v25, v12, v24                                 ; 2c32310c
	v_cvt_f32_ubyte1_e32 v24, v32                               ; 7e302520
	v_cvt_f32_ubyte0_e32 v32, v32                               ; 7e402320
	v_mac_f32_e32 v36, v18, v42                                 ; 2c485512
	v_cvt_f32_ubyte1_e32 v42, v30                               ; 7e54251e
	v_and_b32_e32 v31, s5, v31                                  ; 263e3e05
	v_mac_f32_e32 v36, v17, v24                                 ; 2c483111
	v_cvt_f32_ubyte3_e32 v24, v31                               ; 7e30291f
	v_mac_f32_e32 v36, v16, v32                                 ; 2c484110
	v_cvt_f32_ubyte3_e32 v32, v30                               ; 7e40291e
	v_cvt_f32_ubyte0_e32 v30, v30                               ; 7e3c231e
	v_mul_f32_e32 v24, v11, v24                                 ; 0a30310b
	v_and_b32_e32 v41, s10, v41                                 ; 2652520a
	v_mul_f32_e32 v32, v23, v32                                 ; 0a404117
	v_mac_f32_e32 v32, v22, v33                                 ; 2c404316
	v_cvt_f32_ubyte1_e32 v33, v31                               ; 7e42251f
	v_mac_f32_e32 v32, v21, v42                                 ; 2c405515
	v_cvt_f32_ubyte3_e32 v42, v43                               ; 7e54292b
	v_mac_f32_e32 v32, v20, v30                                 ; 2c403d14
	v_cvt_f32_ubyte2_e32 v30, v31                               ; 7e3c271f
	v_cvt_f32_ubyte0_e32 v31, v31                               ; 7e3e231f
	v_mul_f32_e32 v42, v45, v42                                 ; 0a54552d
	v_mac_f32_e32 v24, v10, v30                                 ; 2c303d0a
	v_cvt_f32_ubyte2_e32 v30, v43                               ; 7e3c272b
	v_mac_f32_e32 v24, v9, v33                                  ; 2c304309
	v_cvt_f32_ubyte2_e32 v33, v41                               ; 7e422729
	v_mac_f32_e32 v42, v44, v30                                 ; 2c543d2c
	v_cvt_f32_ubyte1_e32 v30, v43                               ; 7e3c252b
	v_cvt_f32_ubyte0_e32 v43, v43                               ; 7e56232b
	v_mac_f32_e32 v24, v8, v31                                  ; 2c303f08
	v_cvt_f32_ubyte3_e32 v31, v41                               ; 7e3e2929
	v_mul_f32_e32 v24, v24, v30                                 ; 0a303d18
	v_mac_f32_e32 v42, v35, v31                                 ; 2c543f23
	v_cvt_f32_ubyte1_e32 v31, v41                               ; 7e3e2529
	v_cvt_f32_ubyte0_e32 v41, v41                               ; 7e522329
	v_mac_f32_e32 v24, v32, v43                                 ; 2c305720
	v_lshlrev_b32_e32 v32, 4, v46                               ; 24405c84
	v_mac_f32_e32 v42, v34, v33                                 ; 2c544322
	v_mac_f32_e32 v24, v36, v31                                 ; 2c303f24
	v_lshl_add_u32 v46, v46, 7, v32                             ; d1fd002e 04810f2e
	v_mac_f32_e32 v24, v25, v41                                 ; 2c305319
	v_add_u32_e32 v33, 16, v46                                  ; 68425c90
	v_add_u32_e32 v36, v33, v4                                  ; 68480921
	v_add_u32_e32 v33, v33, v39                                 ; 68424f21
	v_mov_b32_e32 v25, v33                                      ; 7e320321
	buffer_load_dwordx4 v[30:33], v46, s[24:27], 0 offen        ; e05c1000 80061e2e
	buffer_load_dword v36, v36, s[24:27], 0 offen               ; e0501000 80062424
	buffer_load_dword v25, v25, s[24:27], 0 offen               ; e0501000 80061919
	v_cvt_f32_f16_sdwa v39, v40 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e4e16f9 00050628
	v_cvt_f32_f16_e32 v40, v40                                  ; 7e501728
	v_add_u32_e32 v0, 4, v0                                     ; 68000084
	s_waitcnt vmcnt(5)                                          ; bf8c3f75
	v_bfe_u32 v29, v29, v2, 16                                  ; d1c8001d 0242051d
	v_mad_f32 v5, -v39, v42, v5                                 ; d1c10005 24165527
	v_lshl_or_b32 v29, v29, 12, v29                             ; d200001d 0475191d
	v_mac_f32_e32 v5, v40, v24                                  ; 2c0a3128
	v_cndmask_b32_sdwa v40, v27, v27, vcc dst_sel:WORD_0 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 005036f9 0605141b
	v_cndmask_b32_sdwa v40, v28, v28, vcc dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 005038f9 0605151c
	s_waitcnt vmcnt(4)                                          ; bf8c3f74
	v_and_b32_e32 v24, s5, v38                                  ; 26304c05
	v_and_b32_e32 v41, s9, v40                                  ; 26525009
	v_and_b32_e32 v40, s10, v40                                 ; 2650500a
	v_cvt_f32_ubyte2_e32 v28, v24                               ; 7e382718
	v_cvt_f32_ubyte3_e32 v27, v24                               ; 7e362918
	v_lshrrev_b32_e32 v41, 2, v41                               ; 20525282
	v_cvt_f32_ubyte3_e32 v46, v40                               ; 7e5c2928
	v_cvt_f32_ubyte1_e32 v39, v24                               ; 7e4e2518
	v_mul_f32_e32 v27, v15, v27                                 ; 0a36370f
	v_cvt_f32_ubyte0_e32 v24, v24                               ; 7e302318
	v_and_or_b32 v29, s5, v29, v41                              ; d201001d 04a63a05
	v_lshrrev_b32_e32 v38, 4, v38                               ; 204c4c84
	v_mac_f32_e32 v27, v14, v28                                 ; 2c36390e
	v_cvt_f32_ubyte3_e32 v42, v29                               ; 7e54291d
	v_cvt_f32_ubyte2_e32 v43, v29                               ; 7e56271d
	v_and_b32_e32 v38, s5, v38                                  ; 264c4c05
	v_mac_f32_e32 v27, v13, v39                                 ; 2c364f0d
	v_mul_f32_e32 v42, v45, v42                                 ; 0a54552d
	v_cvt_f32_ubyte3_e32 v41, v38                               ; 7e522926
	v_mac_f32_e32 v27, v12, v24                                 ; 2c36310c
	v_cvt_f32_ubyte1_e32 v24, v38                               ; 7e302526
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_and_b32_e32 v28, s5, v37                                  ; 26384a05
	v_mac_f32_e32 v42, v44, v43                                 ; 2c54572c
	v_cvt_f32_ubyte2_e32 v43, v38                               ; 7e562726
	v_cvt_f32_ubyte0_e32 v38, v38                               ; 7e4c2326
	v_mul_f32_e32 v41, v19, v41                                 ; 0a525313
	v_cvt_f32_ubyte2_e32 v39, v28                               ; 7e4e271c
	v_mac_f32_e32 v42, v35, v46                                 ; 2c545d23
	v_cvt_f32_ubyte2_e32 v46, v40                               ; 7e5c2728
	v_mac_f32_e32 v41, v18, v43                                 ; 2c525712
	v_cvt_f32_ubyte1_e32 v43, v28                               ; 7e56251c
	v_lshrrev_b32_e32 v37, 4, v37                               ; 204a4a84
	v_mac_f32_e32 v42, v34, v46                                 ; 2c545d22
	v_cvt_f32_ubyte1_e32 v46, v29                               ; 7e5c251d
	v_cvt_f32_ubyte0_e32 v29, v29                               ; 7e3a231d
	v_mac_f32_e32 v41, v17, v24                                 ; 2c523111
	v_and_b32_e32 v37, s5, v37                                  ; 264a4a05
	v_mac_f32_e32 v41, v16, v38                                 ; 2c524d10
	v_cvt_f32_ubyte3_e32 v38, v28                               ; 7e4c291c
	v_cvt_f32_ubyte0_e32 v28, v28                               ; 7e38231c
	v_cvt_f32_ubyte3_e32 v24, v37                               ; 7e302925
	v_mul_f32_e32 v38, v23, v38                                 ; 0a4c4d17
	v_mul_f32_e32 v24, v11, v24                                 ; 0a30310b
	v_mac_f32_e32 v38, v22, v39                                 ; 2c4c4f16
	v_cvt_f32_ubyte1_e32 v39, v37                               ; 7e4e2525
	v_mac_f32_e32 v38, v21, v43                                 ; 2c4c5715
	v_cvt_f32_ubyte1_e32 v43, v40                               ; 7e562528
	v_cvt_f32_ubyte0_e32 v40, v40                               ; 7e502328
	v_mac_f32_e32 v38, v20, v28                                 ; 2c4c3914
	v_cvt_f32_ubyte2_e32 v28, v37                               ; 7e382725
	v_cvt_f32_ubyte0_e32 v37, v37                               ; 7e4a2325
	v_mac_f32_e32 v24, v10, v28                                 ; 2c30390a
	v_mac_f32_e32 v24, v9, v39                                  ; 2c304f09
	v_mac_f32_e32 v24, v8, v37                                  ; 2c304b08
	v_mul_f32_e32 v24, v24, v46                                 ; 0a305d18
	v_cvt_f32_f16_sdwa v46, v26 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e5c16f9 0005061a
	v_cvt_f32_f16_e32 v26, v26                                  ; 7e34171a
	v_mac_f32_e32 v24, v38, v29                                 ; 2c303b26
	v_mad_f32 v6, -v46, v42, v6                                 ; d1c10006 241a552e
	v_mac_f32_e32 v24, v41, v43                                 ; 2c305729
	v_mac_f32_e32 v24, v27, v40                                 ; 2c30511b
	v_mac_f32_e32 v6, v26, v24                                  ; 2c0c311a
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_bfe_u32 v33, v33, v2, 16                                  ; d1c80021 02420521
	v_cndmask_b32_sdwa v46, v31, v31, vcc dst_sel:WORD_0 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 005c3ef9 0605141f
	v_cndmask_b32_sdwa v46, v32, v32, vcc dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 005c40f9 06051520
	v_lshl_or_b32 v33, v33, 12, v33                             ; d2000021 04851921
	v_and_b32_e32 v24, s9, v46                                  ; 26305c09
	v_and_b32_e32 v46, s10, v46                                 ; 265c5c0a
	v_lshrrev_b32_e32 v24, 2, v24                               ; 20303082
	v_cvt_f32_ubyte2_e32 v29, v46                               ; 7e3a272e
	v_cvt_f32_ubyte3_e32 v28, v46                               ; 7e38292e
	v_cvt_f32_ubyte1_e32 v32, v46                               ; 7e40252e
	v_cvt_f32_ubyte0_e32 v46, v46                               ; 7e5c232e
	v_and_or_b32 v33, s5, v33, v24                              ; d2010021 04624205
	v_cvt_f32_ubyte2_e32 v27, v33                               ; 7e362721
	v_cvt_f32_ubyte1_e32 v31, v33                               ; 7e3e2521
	v_cvt_f32_ubyte3_e32 v26, v33                               ; 7e342921
	v_cvt_f32_ubyte0_e32 v33, v33                               ; 7e422321
	v_mul_f32_e32 v45, v45, v26                                 ; 0a5a352d
	v_mac_f32_e32 v45, v44, v27                                 ; 2c5a372c
	v_mac_f32_e32 v45, v35, v28                                 ; 2c5a3923
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v35, s5, v36                                  ; 26464805
	v_lshrrev_b32_e32 v36, 4, v36                               ; 20484884
	v_mac_f32_e32 v45, v34, v29                                 ; 2c5a3b22
	v_cvt_f32_f16_sdwa v34, v30 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e4416f9 0005061e
	v_cvt_f32_f16_e32 v30, v30                                  ; 7e3c171e
	v_cvt_f32_ubyte2_e32 v38, v35                               ; 7e4c2723
	v_cvt_f32_ubyte1_e32 v39, v35                               ; 7e4e2523
	v_cvt_f32_ubyte3_e32 v37, v35                               ; 7e4a2923
	v_cvt_f32_ubyte0_e32 v35, v35                               ; 7e462323
	v_and_b32_e32 v36, s5, v36                                  ; 26484805
	v_mad_f32 v7, -v34, v45, v7                                 ; d1c10007 241e5b22
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v43, s5, v25                                  ; 26563205
	v_mul_f32_e32 v15, v15, v37                                 ; 0a1e4b0f
	v_cvt_f32_ubyte3_e32 v40, v36                               ; 7e502924
	v_cvt_f32_ubyte1_e32 v42, v36                               ; 7e542524
	v_cvt_f32_ubyte2_e32 v41, v36                               ; 7e522724
	v_cvt_f32_ubyte0_e32 v36, v36                               ; 7e482324
	v_cvt_f32_ubyte2_e32 v45, v43                               ; 7e5a272b
	v_cvt_f32_ubyte3_e32 v44, v43                               ; 7e58292b
	v_mac_f32_e32 v15, v14, v38                                 ; 2c1e4d0e
	v_mul_f32_e32 v19, v19, v40                                 ; 0a265113
	v_lshrrev_b32_e32 v25, 4, v25                               ; 20323284
	v_mul_f32_e32 v23, v23, v44                                 ; 0a2e5917
	v_mac_f32_e32 v15, v13, v39                                 ; 2c1e4f0d
	v_mac_f32_e32 v19, v18, v41                                 ; 2c265312
	v_and_b32_e32 v25, s5, v25                                  ; 26323205
	v_mac_f32_e32 v23, v22, v45                                 ; 2c2e5b16
	v_mac_f32_e32 v15, v12, v35                                 ; 2c1e470c
	v_cvt_f32_ubyte1_e32 v12, v43                               ; 7e18252b
	v_cvt_f32_ubyte0_e32 v43, v43                               ; 7e56232b
	v_mac_f32_e32 v19, v17, v42                                 ; 2c265511
	v_cvt_f32_ubyte2_e32 v14, v25                               ; 7e1c2719
	v_cvt_f32_ubyte3_e32 v13, v25                               ; 7e1a2919
	v_mac_f32_e32 v23, v21, v12                                 ; 2c2e1915
	v_mac_f32_e32 v19, v16, v36                                 ; 2c264910
	v_cvt_f32_ubyte1_e32 v16, v25                               ; 7e202519
	v_cvt_f32_ubyte0_e32 v25, v25                               ; 7e322319
	v_mul_f32_e32 v11, v11, v13                                 ; 0a161b0b
	v_mac_f32_e32 v23, v20, v43                                 ; 2c2e5714
	v_mac_f32_e32 v11, v10, v14                                 ; 2c161d0a
	v_mac_f32_e32 v11, v9, v16                                  ; 2c162109
	v_mac_f32_e32 v11, v8, v25                                  ; 2c163308
	v_mul_f32_e32 v11, v11, v31                                 ; 0a163f0b
	v_mac_f32_e32 v11, v23, v33                                 ; 2c164317
	v_mac_f32_e32 v11, v19, v32                                 ; 2c164113
	v_mac_f32_e32 v11, v15, v46                                 ; 2c165d0f
	v_mac_f32_e32 v7, v30, v11                                  ; 2c0e171e
BB5:
	s_mov_b64 s[0:1], exec                                      ; be80017e
	v_cmpx_le_u32_e32 vcc, s3, v0                               ; 7db60003
BB6:
	s_andn2_b64 s[0:1], s[0:1], exec                            ; 89807e00
	s_cbranch_scc1 BB10                                         ; bf85fe58
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
	s_mov_b64 exec, s[4:5]                                      ; befe0104
	v_readlane_b32 s1, v47, 63                                  ; d2890001 00017f2f
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
	v_readlane_b32 s3, v47, 63                                  ; d2890003 00017f2f
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
	s_mov_b64 exec, 1                                           ; befe0181
	v_readlane_b32 s4, v47, 63                                  ; d2890004 00017f2f
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
	s_branch BB119                                              ; bf820310
BB42:
	s_cmp_lt_u32 s16, s4                                        ; bf0a0410
	s_cbranch_scc0 BB119                                        ; bf84030e
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
	s_mul_i32 s19, s19, s5                                      ; 92130513
	v_mov_b32_e32 v7, 0                                         ; 7e0e0280
	v_sub_u32_e32 v1, v2, v1                                    ; 6a020302
	v_bfe_u32 v3, v2, 2, 1                                      ; d1c80003 02050502
	v_lshrrev_b32_e32 v2, 3, v2                                 ; 20040483
	v_lshl_add_u32 v1, v1, 1, v3                                ; d1fd0001 040d0301
	v_mov_b32_e32 v3, 0                                         ; 7e060280
	v_lshlrev_b32_e32 v1, 2, v1                                 ; 24020282
	v_lshl_add_u32 v4, v2, 5, v1                                ; d1fd0004 04050b02
	v_lshl_add_u32 v1, v2, 6, v1                                ; d1fd0001 04050d02
	v_lshlrev_b32_e32 v2, 4, v2                                 ; 24040484
BB47:
	s_mov_b64 s[0:1], exec                                      ; be80017e
	v_cmpx_le_u32_e32 vcc, s3, v0                               ; 7db60003
BB48:
	s_andn2_b64 s[0:1], s[0:1], exec                            ; 89807e00
	s_cbranch_scc0 BB65                                         ; bf8401b8
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
	s_cbranch_scc0 BB64                                         ; bf84018b
BB53:
	s_load_dwordx4 s[12:15], s[0:1], 0x0                        ; c00a0300 00000000
	s_mul_i32 s0, s16, s3                                       ; 92000310
	v_add_u32_e32 v32, 64, v4                                   ; 684008c0
	s_add_u32 s0, s19, s0                                       ; 80000013
	v_add_u32_e32 v28, s0, v0                                   ; 68380000
	v_lshlrev_b32_e32 v29, 4, v28                               ; 243a3884
	v_lshl_add_u32 v28, v28, 7, v29                             ; d1fd001c 04750f1c
	v_add_u32_e32 v30, 16, v28                                  ; 683c3890
	v_add_u32_e32 v31, v30, v4                                  ; 683e091e
	v_add_u32_e32 v30, v30, v32                                 ; 683c411e
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_load_dwordx4 v[36:39], v28, s[12:15], 0 offen        ; e05c1000 8003241c
	buffer_load_dword v31, v31, s[12:15], 0 offen               ; e0501000 80031f1f
	buffer_load_dword v30, v30, s[12:15], 0 offen               ; e0501000 80031e1e
	s_bitreplicate_b64_b32 vcc, 0xf0f0f0f                       ; beea37ff 0f0f0f0f
	s_mov_b32 s1, 0xf0f0f0f                                     ; be8100ff 0f0f0f0f
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
	v_and_b32_e32 v44, s1, v31                                  ; 26583e01
	v_and_or_b32 v39, s1, v39, v34                              ; d2010027 048a4e01
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
	v_and_b32_e32 v31, s1, v31                                  ; 263e3e01
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
	v_and_b32_e32 v31, s1, v30                                  ; 263e3c01
	v_lshrrev_b32_e32 v30, 4, v30                               ; 203c3c84
	v_cvt_f32_ubyte3_e32 v34, v31                               ; 7e44291f
	v_cvt_f32_ubyte2_e32 v35, v31                               ; 7e46271f
	v_cvt_f32_ubyte1_e32 v37, v31                               ; 7e4a251f
	v_cvt_f32_ubyte0_e32 v31, v31                               ; 7e3e231f
	v_and_b32_e32 v30, s1, v30                                  ; 263c3c01
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
	v_mac_f32_e32 v3, v36, v38                                  ; 2c064d24
	s_cbranch_scc0 BB64                                         ; bf840124
BB54:
	s_add_u32 s0, s16, 1                                        ; 80008110
	s_mul_i32 s0, s0, s3                                        ; 92000300
	s_add_u32 s0, s19, s0                                       ; 80000013
	v_add_u32_e32 v28, s0, v0                                   ; 68380000
	v_lshlrev_b32_e32 v29, 4, v28                               ; 243a3884
	v_lshl_add_u32 v28, v28, 7, v29                             ; d1fd001c 04750f1c
	v_add_u32_e32 v30, 16, v28                                  ; 683c3890
	v_add_u32_e32 v31, v30, v4                                  ; 683e091e
	v_add_u32_e32 v30, v30, v32                                 ; 683c411e
	buffer_load_dwordx4 v[36:39], v28, s[12:15], 0 offen        ; e05c1000 8003241c
	buffer_load_dword v31, v31, s[12:15], 0 offen               ; e0501000 80031f1f
	buffer_load_dword v30, v30, s[12:15], 0 offen               ; e0501000 80031e1e
	s_mov_b32 s1, 0xf0f0f0f                                     ; be8100ff 0f0f0f0f
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
	v_and_b32_e32 v44, s1, v31                                  ; 26583e01
	v_and_or_b32 v39, s1, v39, v34                              ; d2010027 048a4e01
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
	v_and_b32_e32 v31, s1, v31                                  ; 263e3e01
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
	v_and_b32_e32 v31, s1, v30                                  ; 263e3c01
	v_lshrrev_b32_e32 v30, 4, v30                               ; 203c3c84
	v_cvt_f32_ubyte2_e32 v35, v31                               ; 7e46271f
	v_cvt_f32_ubyte3_e32 v34, v31                               ; 7e44291f
	v_cvt_f32_ubyte1_e32 v37, v31                               ; 7e4a251f
	v_cvt_f32_ubyte0_e32 v31, v31                               ; 7e3e231f
	v_and_b32_e32 v30, s1, v30                                  ; 263c3c01
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
	s_cbranch_scc0 BB64                                         ; bf8400c2
BB55:
	s_add_u32 s0, s16, 2                                        ; 80008210
	s_mul_i32 s0, s0, s3                                        ; 92000300
	s_add_u32 s0, s19, s0                                       ; 80000013
	v_add_u32_e32 v28, s0, v0                                   ; 68380000
	v_lshlrev_b32_e32 v29, 4, v28                               ; 243a3884
	v_lshl_add_u32 v28, v28, 7, v29                             ; d1fd001c 04750f1c
	v_add_u32_e32 v30, 16, v28                                  ; 683c3890
	v_add_u32_e32 v31, v30, v4                                  ; 683e091e
	v_add_u32_e32 v30, v30, v32                                 ; 683c411e
	buffer_load_dwordx4 v[36:39], v28, s[12:15], 0 offen        ; e05c1000 8003241c
	buffer_load_dword v31, v31, s[12:15], 0 offen               ; e0501000 80031f1f
	buffer_load_dword v30, v30, s[12:15], 0 offen               ; e0501000 80031e1e
	s_mov_b32 s1, 0xf0f0f0f                                     ; be8100ff 0f0f0f0f
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
	v_and_b32_e32 v44, s1, v31                                  ; 26583e01
	v_and_or_b32 v39, s1, v39, v34                              ; d2010027 048a4e01
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
	v_and_b32_e32 v31, s1, v31                                  ; 263e3e01
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
	v_and_b32_e32 v31, s1, v30                                  ; 263e3c01
	v_lshrrev_b32_e32 v30, 4, v30                               ; 203c3c84
	v_cvt_f32_ubyte2_e32 v35, v31                               ; 7e46271f
	v_cvt_f32_ubyte3_e32 v34, v31                               ; 7e44291f
	v_cvt_f32_ubyte1_e32 v37, v31                               ; 7e4a251f
	v_cvt_f32_ubyte0_e32 v31, v31                               ; 7e3e231f
	v_and_b32_e32 v30, s1, v30                                  ; 263c3c01
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
	s_cbranch_scc0 BB64                                         ; bf840060
BB56:
	s_add_u32 s0, s16, 3                                        ; 80008310
	s_mul_i32 s0, s0, s3                                        ; 92000300
	s_add_u32 s0, s19, s0                                       ; 80000013
	v_add_u32_e32 v28, s0, v0                                   ; 68380000
	v_lshlrev_b32_e32 v29, 4, v28                               ; 243a3884
	v_lshl_add_u32 v28, v28, 7, v29                             ; d1fd001c 04750f1c
	v_add_u32_e32 v30, 16, v28                                  ; 683c3890
	v_add_u32_e32 v31, v30, v4                                  ; 683e091e
	v_add_u32_e32 v30, v30, v32                                 ; 683c411e
	buffer_load_dwordx4 v[32:35], v28, s[12:15], 0 offen        ; e05c1000 8003201c
	buffer_load_dword v31, v31, s[12:15], 0 offen               ; e0501000 80031f1f
	buffer_load_dword v30, v30, s[12:15], 0 offen               ; e0501000 80031e1e
	s_mov_b32 s1, 0xf0f0f0f                                     ; be8100ff 0f0f0f0f
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
	v_and_b32_e32 v43, s1, v31                                  ; 26563e01
	v_and_or_b32 v35, s1, v35, v34                              ; d2010023 048a4601
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
	v_and_b32_e32 v31, s1, v31                                  ; 263e3e01
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
	v_and_b32_e32 v46, s1, v30                                  ; 265c3c01
	v_lshrrev_b32_e32 v30, 4, v30                               ; 203c3c84
	v_mac_f32_e32 v19, v16, v31                                 ; 2c263f10
	v_cvt_f32_ubyte2_e32 v13, v46                               ; 7e1a272e
	v_cvt_f32_ubyte1_e32 v14, v46                               ; 7e1c252e
	v_cvt_f32_ubyte3_e32 v12, v46                               ; 7e18292e
	v_cvt_f32_ubyte0_e32 v46, v46                               ; 7e5c232e
	v_and_b32_e32 v30, s1, v30                                  ; 263c3c01
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
BB64:
	v_add_u32_e32 v0, 4, v0                                     ; 68000084
	s_branch BB47                                               ; bf82fe44
BB65:
	s_mov_b64 exec, -1                                          ; befe01c1
	s_cmp_lg_i32 s4, 0                                          ; bf018004
	s_cselect_b64 s[0:1], -1, 0                                 ; 858080c1
	s_cbranch_scc0 BB77                                         ; bf84006a
BB66:
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
	s_cbranch_scc0 BB75                                         ; bf84004f
BB67:
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
	s_cbranch_scc0 BB73                                         ; bf840034
BB68:
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
	s_cbranch_scc0 BB71                                         ; bf840019
BB69:
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
