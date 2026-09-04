BB0:
	s_load_dword s0, s[14:15], 0x0                              ; c0020007 00000000
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_mul_i32 s0, s0, s18                                       ; 92001200
	s_add_u32 s16, s16, s0                                      ; 80100010
	s_lshl_b32 s16, s16, 1                                      ; 8e108110
	s_add_u32 s1, s16, 2                                        ; 80018210
	s_cmp_ge_u32 s4, s1                                         ; bf090104
	s_cbranch_scc0 BB36                                         ; bf8401ca
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
	s_cbranch_execz BB15                                        ; bf8800f3
BB5:
	s_mov_b32 s0, s2                                            ; be800002
	s_movk_i32 s1, 0x8000                                       ; b0018000
	s_load_dwordx8 s[24:31], s[0:1], 0x0                        ; c00e0600 00000000
	s_mul_i32 s6, s6, s17                                       ; 92061106
	s_mul_i32 s0, s16, s3                                       ; 92000310
	v_lshlrev_b32_e32 v2, 4, v2                                 ; 24040484
	v_add_u32_e32 v3, 64, v4                                    ; 680608c0
	s_bitreplicate_b64_b32 vcc, 0xf0f0f0f                       ; beea37ff 0f0f0f0f
	s_mov_b64 s[4:5], exec                                      ; be84017e
	v_mov_b32_e32 v5, 0                                         ; 7e0a0280
	v_mov_b32_e32 v6, 0                                         ; 7e0c0280
	s_add_u32 s0, s18, s0                                       ; 80000012
	s_add_u32 s1, s16, 1                                        ; 80018110
	s_mul_i32 s1, s1, s3                                        ; 92010301
	s_add_u32 s18, s18, s1                                      ; 80120112
BB6:
	v_lshl_add_u32 v7, v0, 8, v1                                ; d1fd0007 04051100
	v_add_u32_e32 v8, s6, v7                                    ; 68100e06
	v_add_u32_e32 v7, 0x80, v7                                  ; 680e0eff 00000080
	v_lshrrev_b32_e32 v8, 2, v8                                 ; 20101082
	v_add_u32_e32 v7, s6, v7                                    ; 680e0e06
	v_lshlrev_b32_e32 v8, 4, v8                                 ; 24101084
	v_lshrrev_b32_e32 v7, 2, v7                                 ; 200e0e82
	v_lshlrev_b32_e32 v7, 4, v7                                 ; 240e0e84
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_load_dwordx4 v[12:15], v8, s[28:31], 0 offen         ; e05c1000 80070c08
	buffer_load_dwordx4 v[8:11], v8, s[28:31], 0 offen offset:128 ; e05c1080 80070808
	buffer_load_dwordx4 v[16:19], v7, s[28:31], 0 offen         ; e05c1000 80071007
	buffer_load_dwordx4 v[20:23], v7, s[28:31], 0 offen offset:128 ; e05c1080 80071407
	v_add_u32_e32 v24, s0, v0                                   ; 68300000
	v_add_u32_e32 v28, s18, v0                                  ; 68380012
	v_lshlrev_b32_e32 v25, 4, v24                               ; 24323084
	v_lshlrev_b32_e32 v29, 4, v28                               ; 243a3884
	v_lshl_add_u32 v24, v24, 7, v25                             ; d1fd0018 04650f18
	v_lshl_add_u32 v28, v28, 7, v29                             ; d1fd001c 04750f1c
	v_add_u32_e32 v26, 16, v24                                  ; 68343090
	v_add_u32_e32 v30, 16, v28                                  ; 683c3890
	v_add_u32_e32 v27, v26, v4                                  ; 6836091a
	v_add_u32_e32 v26, v26, v3                                  ; 6834071a
	v_add_u32_e32 v31, v30, v4                                  ; 683e091e
	v_add_u32_e32 v30, v30, v3                                  ; 683c071e
	buffer_load_dwordx4 v[32:35], v24, s[24:27], 0 offen        ; e05c1000 80062018
	buffer_load_dword v27, v27, s[24:27], 0 offen               ; e0501000 80061b1b
	buffer_load_dword v26, v26, s[24:27], 0 offen               ; e0501000 80061a1a
	buffer_load_dwordx4 v[36:39], v28, s[24:27], 0 offen        ; e05c1000 8006241c
	buffer_load_dword v31, v31, s[24:27], 0 offen               ; e0501000 80061f1f
	buffer_load_dword v30, v30, s[24:27], 0 offen               ; e0501000 80061e1e
	s_mov_b32 s1, 0xf0f0f0f                                     ; be8100ff 0f0f0f0f
	v_add_u32_e32 v0, 4, v0                                     ; 68000084
	v_cmp_le_u32_e64 s[10:11], s3, v0                           ; d0cb000a 00020003
	s_waitcnt vmcnt(9)                                          ; bf8c3f79
	v_add_f32_e32 v40, v12, v13                                 ; 02501b0c
	s_waitcnt vmcnt(8)                                          ; bf8c3f78
	v_add_f32_e32 v41, v8, v9                                   ; 02521308
	s_waitcnt vmcnt(7)                                          ; bf8c3f77
	v_add_f32_e32 v42, v16, v17                                 ; 02542310
	v_add_f32_e32 v40, v40, v14                                 ; 02501d28
	v_add_f32_e32 v41, v41, v10                                 ; 02521529
	s_waitcnt vmcnt(6)                                          ; bf8c3f76
	v_add_f32_e32 v43, v20, v21                                 ; 02562b14
	v_add_f32_e32 v42, v42, v18                                 ; 0254252a
	v_add_f32_e32 v40, v40, v15                                 ; 02501f28
	v_add_f32_e32 v41, v41, v11                                 ; 02521729
	v_add_f32_e32 v43, v43, v22                                 ; 02562d2b
	v_add_f32_e32 v42, v42, v19                                 ; 0254272a
	v_add_f32_e32 v43, v43, v23                                 ; 02562f2b
	s_waitcnt vmcnt(5)                                          ; bf8c3f75
	v_bfe_u32 v35, v35, v2, 16                                  ; d1c80023 02420523
	v_cndmask_b32_sdwa v44, v33, v33, vcc dst_sel:WORD_0 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 005842f9 06051421
	v_cndmask_b32_sdwa v44, v34, v34, vcc dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 005844f9 06051522
	v_lshl_or_b32 v35, v35, 12, v35                             ; d2000023 048d1923
	v_and_b32_e32 v45, 0xc0c0c0c0, v44                          ; 265a58ff c0c0c0c0
	v_and_b32_e32 v44, 0x3f3f3f3f, v44                          ; 265858ff 3f3f3f3f
	s_waitcnt vmcnt(4)                                          ; bf8c3f74
	v_and_b32_e32 v33, s1, v27                                  ; 26423601
	v_lshrrev_b32_e32 v45, 2, v45                               ; 205a5a82
	v_cvt_f32_ubyte1_e32 v29, v44                               ; 7e3a252c
	v_cvt_f32_ubyte3_e32 v24, v44                               ; 7e30292c
	v_cvt_f32_ubyte2_e32 v25, v44                               ; 7e32272c
	v_cvt_f32_ubyte0_e32 v44, v44                               ; 7e58232c
	v_cvt_f32_ubyte3_e32 v34, v33                               ; 7e442921
	v_and_or_b32 v35, s1, v35, v45                              ; d2010023 04b64601
	v_cvt_f32_ubyte2_e32 v45, v33                               ; 7e5a2721
	v_mul_f32_e32 v34, v15, v34                                 ; 0a44450f
	v_lshrrev_b32_e32 v27, 4, v27                               ; 20363684
	v_cvt_f32_ubyte1_e32 v28, v35                               ; 7e382523
	v_cvt_f32_ubyte2_e32 v7, v35                                ; 7e0e2723
	v_cvt_f32_ubyte3_e32 v46, v35                               ; 7e5c2923
	v_cvt_f32_ubyte0_e32 v35, v35                               ; 7e462323
	v_mac_f32_e32 v34, v14, v45                                 ; 2c445b0e
	v_and_b32_e32 v27, s1, v27                                  ; 26363601
	v_mul_f32_e32 v46, v43, v46                                 ; 0a5c5d2b
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_and_b32_e32 v45, s1, v26                                  ; 265a3401
	v_mac_f32_e32 v46, v42, v7                                  ; 2c5c0f2a
	v_cvt_f32_ubyte1_e32 v7, v33                                ; 7e0e2521
	v_cvt_f32_ubyte0_e32 v33, v33                               ; 7e422321
	v_mac_f32_e32 v46, v41, v24                                 ; 2c5c3129
	v_cvt_f32_ubyte3_e32 v24, v27                               ; 7e30291b
	v_mac_f32_e32 v34, v13, v7                                  ; 2c440f0d
	v_cvt_f32_ubyte3_e32 v7, v45                                ; 7e0e292d
	v_mac_f32_e32 v46, v40, v25                                 ; 2c5c3328
	v_cvt_f32_ubyte2_e32 v25, v27                               ; 7e32271b
	v_mul_f32_e32 v24, v11, v24                                 ; 0a30310b
	v_mac_f32_e32 v34, v12, v33                                 ; 2c44430c
	v_cvt_f32_ubyte1_e32 v33, v27                               ; 7e42251b
	v_cvt_f32_ubyte0_e32 v27, v27                               ; 7e36231b
	v_mul_f32_e32 v7, v19, v7                                   ; 0a0e0f13
	v_lshrrev_b32_e32 v26, 4, v26                               ; 20343484
	v_mac_f32_e32 v24, v10, v25                                 ; 2c30330a
	v_cvt_f32_ubyte2_e32 v25, v45                               ; 7e32272d
	v_and_b32_e32 v26, s1, v26                                  ; 26343401
	v_mac_f32_e32 v24, v9, v33                                  ; 2c304309
	v_mac_f32_e32 v7, v18, v25                                  ; 2c0e3312
	v_cvt_f32_ubyte3_e32 v33, v26                               ; 7e42291a
	v_cvt_f32_ubyte1_e32 v25, v26                               ; 7e32251a
	v_mac_f32_e32 v24, v8, v27                                  ; 2c303708
	v_cvt_f32_ubyte1_e32 v27, v45                               ; 7e36252d
	v_cvt_f32_ubyte0_e32 v45, v45                               ; 7e5a232d
	v_mul_f32_e32 v33, v23, v33                                 ; 0a424317
	v_mac_f32_e32 v7, v17, v27                                  ; 2c0e3711
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_bfe_u32 v39, v39, v2, 16                                  ; d1c80027 02420527
	v_cndmask_b32_sdwa v27, v37, v37, vcc dst_sel:WORD_0 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 00364af9 06051425
	v_mac_f32_e32 v7, v16, v45                                  ; 2c0e5b10
	v_cvt_f32_ubyte2_e32 v45, v26                               ; 7e5a271a
	v_cvt_f32_ubyte0_e32 v26, v26                               ; 7e34231a
	v_cndmask_b32_sdwa v27, v38, v38, vcc dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 00364cf9 06051526
	v_lshl_or_b32 v39, v39, 12, v39                             ; d2000027 049d1927
	v_mac_f32_e32 v33, v22, v45                                 ; 2c425b16
	v_mac_f32_e32 v33, v21, v25                                 ; 2c423315
	v_mac_f32_e32 v33, v20, v26                                 ; 2c423514
	v_cvt_f32_f16_sdwa v26, v32 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e3416f9 00050620
	v_cvt_f32_f16_e32 v32, v32                                  ; 7e401720
	v_mul_f32_e32 v33, v33, v28                                 ; 0a423921
	v_and_b32_e32 v28, 0xc0c0c0c0, v27                          ; 263836ff c0c0c0c0
	v_and_b32_e32 v27, 0x3f3f3f3f, v27                          ; 263636ff 3f3f3f3f
	v_mad_f32 v5, -v26, v46, v5                                 ; d1c10005 24165d1a
	v_mac_f32_e32 v33, v7, v35                                  ; 2c424707
	v_lshrrev_b32_e32 v28, 2, v28                               ; 20383882
	v_cvt_f32_ubyte1_e32 v37, v27                               ; 7e4a251b
	v_mac_f32_e32 v33, v24, v29                                 ; 2c423b18
	v_and_or_b32 v39, s1, v39, v28                              ; d2010027 04724e01
	v_cvt_f32_f16_sdwa v38, v36 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e4c16f9 00050624
	v_mac_f32_e32 v33, v34, v44                                 ; 2c425922
	v_cvt_f32_ubyte2_e32 v34, v27                               ; 7e44271b
	v_cvt_f32_f16_e32 v36, v36                                  ; 7e481724
	v_cvt_f32_ubyte3_e32 v29, v39                               ; 7e3a2927
	v_cvt_f32_ubyte1_e32 v35, v39                               ; 7e462527
	v_mac_f32_e32 v5, v32, v33                                  ; 2c0a4320
	v_cvt_f32_ubyte3_e32 v33, v27                               ; 7e42291b
	v_cvt_f32_ubyte0_e32 v27, v27                               ; 7e36231b
	v_cvt_f32_ubyte2_e32 v32, v39                               ; 7e402727
	v_cvt_f32_ubyte0_e32 v39, v39                               ; 7e4e2327
	v_mul_f32_e32 v43, v43, v29                                 ; 0a563b2b
	v_mac_f32_e32 v43, v42, v32                                 ; 2c56412a
	v_mac_f32_e32 v43, v41, v33                                 ; 2c564329
	v_mac_f32_e32 v43, v40, v34                                 ; 2c564528
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v40, s1, v31                                  ; 26503e01
	v_lshrrev_b32_e32 v31, 4, v31                               ; 203e3e84
	v_mad_f32 v6, -v38, v43, v6                                 ; d1c10006 241a5726
	v_cvt_f32_ubyte1_e32 v43, v40                               ; 7e562528
	v_cvt_f32_ubyte3_e32 v41, v40                               ; 7e522928
	v_cvt_f32_ubyte2_e32 v42, v40                               ; 7e542728
	v_cvt_f32_ubyte0_e32 v40, v40                               ; 7e502328
	v_and_b32_e32 v31, s1, v31                                  ; 263e3e01
	v_mul_f32_e32 v15, v15, v41                                 ; 0a1e530f
	v_cvt_f32_ubyte3_e32 v44, v31                               ; 7e58291f
	v_cvt_f32_ubyte2_e32 v45, v31                               ; 7e5a271f
	v_cvt_f32_ubyte1_e32 v46, v31                               ; 7e5c251f
	v_cvt_f32_ubyte0_e32 v31, v31                               ; 7e3e231f
	v_mac_f32_e32 v15, v14, v42                                 ; 2c1e550e
	v_mul_f32_e32 v11, v11, v44                                 ; 0a16590b
	v_mac_f32_e32 v15, v13, v43                                 ; 2c1e570d
	v_mac_f32_e32 v11, v10, v45                                 ; 2c165b0a
	v_mac_f32_e32 v15, v12, v40                                 ; 2c1e510c
	v_mac_f32_e32 v11, v9, v46                                  ; 2c165d09
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v46, s1, v30                                  ; 265c3c01
	v_lshrrev_b32_e32 v30, 4, v30                               ; 203c3c84
	v_mac_f32_e32 v11, v8, v31                                  ; 2c163f08
	v_cvt_f32_ubyte2_e32 v8, v46                                ; 7e10272e
	v_cvt_f32_ubyte1_e32 v9, v46                                ; 7e12252e
	v_cvt_f32_ubyte3_e32 v7, v46                                ; 7e0e292e
	v_cvt_f32_ubyte0_e32 v46, v46                               ; 7e5c232e
	v_and_b32_e32 v30, s1, v30                                  ; 263c3c01
	v_mul_f32_e32 v19, v19, v7                                  ; 0a260f13
	v_cvt_f32_ubyte1_e32 v13, v30                               ; 7e1a251e
	v_cvt_f32_ubyte3_e32 v10, v30                               ; 7e14291e
	v_cvt_f32_ubyte2_e32 v12, v30                               ; 7e18271e
	v_cvt_f32_ubyte0_e32 v30, v30                               ; 7e3c231e
	v_mac_f32_e32 v19, v18, v8                                  ; 2c261112
	v_mul_f32_e32 v23, v23, v10                                 ; 0a2e1517
	v_mac_f32_e32 v19, v17, v9                                  ; 2c261311
	v_mac_f32_e32 v23, v22, v12                                 ; 2c2e1916
	v_mac_f32_e32 v19, v16, v46                                 ; 2c265d10
	v_mac_f32_e32 v23, v21, v13                                 ; 2c2e1b15
	v_mac_f32_e32 v23, v20, v30                                 ; 2c2e3d14
	v_mul_f32_e32 v23, v23, v35                                 ; 0a2e4717
	v_mac_f32_e32 v23, v19, v39                                 ; 2c2e4f13
	v_mac_f32_e32 v23, v11, v37                                 ; 2c2e4b0b
	v_mac_f32_e32 v23, v15, v27                                 ; 2c2e370f
	v_mac_f32_e32 v6, v36, v23                                  ; 2c0c2f24
	s_and_saveexec_b64 s[10:11], s[10:11]                       ; be8a200a
BB11:
	s_andn2_wrexec_b64 s[10:11], s[10:11]                       ; be8a360a
	s_cbranch_scc1 BB6                                          ; bf85ff1f
BB12:
	s_mov_b64 exec, s[4:5]                                      ; befe0104
BB15:
	s_andn2_b64 exec, -1, exec                                  ; 89fe7ec1
	v_mov_b32_e32 v5, 0                                         ; 7e0a0280
	v_mov_b32_e32 v6, 0                                         ; 7e0c0280
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
	s_mov_b64 exec, 1                                           ; befe0181
	v_readlane_b32 s1, v47, 63                                  ; d2890001 00017f2f
BB18:
	s_bitcmp1_b32 s8, 0                                         ; bf0d8008
	s_cbranch_scc0 BB20                                         ; bf84000f
BB19:
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
	s_branch BB21                                               ; bf820002
BB20:
	s_mov_b32 s4, src_scc                                       ; be8400fd
	v_mov_b32_e32 v0, s0                                        ; 7e000200
BB21:
	s_bitcmp1_b32 s8, 1                                         ; bf0d8108
	s_cbranch_scc0 BB23                                         ; bf84000e
BB22:
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
	s_branch BB24                                               ; bf820001
BB23:
	s_mov_b32 s3, src_scc                                       ; be8300fd
BB24:
	s_mov_b32 s0, s3                                            ; be800003
	s_movk_i32 s3, 0x8000                                       ; b0038000
	s_load_dwordx4 s[8:11], s[2:3], 0x20                        ; c00a0201 00000020
	s_mul_i32 s7, s7, s17                                       ; 92071107
	s_add_u32 s7, s7, s16                                       ; 80071007
	s_lshl_b32 s7, s7, 2                                        ; 8e078207
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_store_dword v0, off, s[8:11], s7                     ; e0700000 07020080
	s_cmp_lg_i32 s4, 0                                          ; bf018004
	s_cbranch_scc0 BB26                                         ; bf84000a
BB25:
	s_load_dwordx4 s[12:15], s[2:3], 0x30                       ; c00a0301 00000030
	s_add_u32 s4, s7, 4                                         ; 80048407
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s4, s[12:15], s4                        ; c0200106 00000004
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_mov_b32_e32 v0, s4                                        ; 7e000204
	v_add_f32_e32 v0, s1, v0                                    ; 02000001
	s_branch BB27                                               ; bf820001
BB26:
	v_mov_b32_e32 v0, s1                                        ; 7e000201
BB27:
	s_cmp_lg_i32 s0, 0                                          ; bf018000
	s_cbranch_scc0 BB30                                         ; bf840008
BB28:
	s_load_dwordx4 s[0:3], s[2:3], 0x40                         ; c00a0001 00000040
	s_add_u32 s4, s7, 4                                         ; 80048407
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s4, s[0:3], s4                          ; c0200100 00000004
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v0, s4, v0                                    ; 02000004
BB30:
	s_add_u32 s7, s7, 4                                         ; 80078407
	buffer_store_dword v0, off, s[8:11], s7                     ; e0700000 07020080
	s_branch BB89                                               ; bf8201e1
BB36:
	s_cmp_lt_u32 s16, s4                                        ; bf0a0410
	s_cbranch_scc0 BB89                                         ; bf8401df
BB37:
	s_sub_i32 s4, s4, s16                                       ; 81841004
	s_add_u32 s17, s17, s9                                      ; 80110911
	s_cmp_lg_i32 s17, 0                                         ; bf018011
	s_cbranch_scc0 BB39                                         ; bf840043
BB38:
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
	s_branch BB40                                               ; bf820001
BB39:
	s_mov_b32 s19, 0                                            ; be930080
BB40:
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
	s_cbranch_execz BB57                                        ; bf880101
BB41:
	s_mov_b32 s0, s2                                            ; be800002
	s_movk_i32 s1, 0x8000                                       ; b0018000
	s_load_dwordx4 s[12:15], s[0:1], 0x10                       ; c00a0300 00000010
	s_mul_i32 s6, s6, s17                                       ; 92061106
	v_lshlrev_b32_e32 v2, 4, v2                                 ; 24040484
	s_cmp_lg_i32 s4, 0                                          ; bf018004
	s_mov_b64 s[10:11], exec                                    ; be8a017e
	v_mov_b32_e32 v3, 0                                         ; 7e060280
	v_mov_b32_e32 v5, 0                                         ; 7e0a0280
	s_branch BB42                                               ; bf820002
BB53:
	s_mov_b64 exec, s[20:21]                                    ; befe0114
	s_cmp_lg_i32 s9, 0                                          ; bf018009
BB42:
	v_lshl_add_u32 v6, v0, 8, v1                                ; d1fd0006 04051100
	v_add_u32_e32 v7, s6, v6                                    ; 680e0c06
	v_add_u32_e32 v6, 0x80, v6                                  ; 680c0cff 00000080
	v_lshrrev_b32_e32 v7, 2, v7                                 ; 200e0e82
	v_add_u32_e32 v6, s6, v6                                    ; 680c0c06
	v_lshlrev_b32_e32 v7, 4, v7                                 ; 240e0e84
	v_lshrrev_b32_e32 v6, 2, v6                                 ; 200c0c82
	v_lshlrev_b32_e32 v6, 4, v6                                 ; 240c0c84
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_load_dwordx4 v[8:11], v7, s[12:15], 0 offen          ; e05c1000 80030807
	buffer_load_dwordx4 v[12:15], v7, s[12:15], 0 offen offset:128 ; e05c1080 80030c07
	buffer_load_dwordx4 v[16:19], v6, s[12:15], 0 offen         ; e05c1000 80031006
	buffer_load_dwordx4 v[20:23], v6, s[12:15], 0 offen offset:128 ; e05c1080 80031406
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_add_f32_e32 v24, v8, v9                                   ; 02301308
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_add_f32_e32 v25, v12, v13                                 ; 02321b0c
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_add_f32_e32 v26, v16, v17                                 ; 02342310
	v_add_f32_e32 v24, v24, v10                                 ; 02301518
	v_add_f32_e32 v25, v25, v14                                 ; 02321d19
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_add_f32_e32 v27, v20, v21                                 ; 02362b14
	v_add_f32_e32 v26, v26, v18                                 ; 0234251a
	v_add_f32_e32 v24, v24, v11                                 ; 02301718
	v_add_f32_e32 v25, v25, v15                                 ; 02321f19
	v_add_f32_e32 v27, v27, v22                                 ; 02362d1b
	v_add_f32_e32 v26, v26, v19                                 ; 0234271a
	v_add_f32_e32 v27, v27, v23                                 ; 02362f1b
	s_cbranch_scc0 BB47                                         ; bf8400c9
BB43:
	s_load_dwordx4 s[20:23], s[0:1], 0x0                        ; c00a0500 00000000
	s_mul_i32 s5, s16, s3                                       ; 92050310
	s_mov_b32 s9, src_scc                                       ; be8900fd
	v_add_u32_e32 v30, 64, v4                                   ; 683c08c0
	s_add_u32 s5, s19, s5                                       ; 80050513
	v_add_u32_e32 v6, s5, v0                                    ; 680c0005
	v_lshlrev_b32_e32 v7, 4, v6                                 ; 240e0c84
	v_lshl_add_u32 v6, v6, 7, v7                                ; d1fd0006 041d0f06
	v_add_u32_e32 v28, 16, v6                                   ; 68380c90
	v_add_u32_e32 v29, v28, v4                                  ; 683a091c
	v_add_u32_e32 v28, v28, v30                                 ; 68383d1c
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_load_dwordx4 v[32:35], v6, s[20:23], 0 offen         ; e05c1000 80052006
	buffer_load_dword v29, v29, s[20:23], 0 offen               ; e0501000 80051d1d
	buffer_load_dword v28, v28, s[20:23], 0 offen               ; e0501000 80051c1c
	s_bitreplicate_b64_b32 vcc, 0xf0f0f0f                       ; beea37ff 0f0f0f0f
	s_mov_b32 s18, 0xf0f0f0f                                    ; be9200ff 0f0f0f0f
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
	v_and_b32_e32 v42, s18, v29                                 ; 26543a12
	v_and_or_b32 v35, s18, v35, v33                             ; d2010023 04864612
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
	v_and_b32_e32 v29, s18, v29                                 ; 263a3a12
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
	v_and_b32_e32 v29, s18, v28                                 ; 263a3812
	v_lshrrev_b32_e32 v28, 4, v28                               ; 20383884
	v_cvt_f32_ubyte2_e32 v34, v29                               ; 7e44271d
	v_cvt_f32_ubyte1_e32 v36, v29                               ; 7e48251d
	v_cvt_f32_ubyte3_e32 v33, v29                               ; 7e42291d
	v_cvt_f32_ubyte0_e32 v29, v29                               ; 7e3a231d
	v_and_b32_e32 v28, s18, v28                                 ; 26383812
	v_mul_f32_e32 v33, v19, v33                                 ; 0a424313
	v_cvt_f32_ubyte3_e32 v37, v28                               ; 7e4a291c
	v_cvt_f32_ubyte1_e32 v41, v28                               ; 7e52251c
	v_cvt_f32_ubyte2_e32 v38, v28                               ; 7e4c271c
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
	s_cbranch_scc0 BB48                                         ; bf840062
BB44:
	s_add_u32 s5, s16, 1                                        ; 80058110
	s_mul_i32 s5, s5, s3                                        ; 92050305
	s_add_u32 s5, s19, s5                                       ; 80050513
	v_add_u32_e32 v6, s5, v0                                    ; 680c0005
	v_lshlrev_b32_e32 v7, 4, v6                                 ; 240e0c84
	v_lshl_add_u32 v6, v6, 7, v7                                ; d1fd0006 041d0f06
	v_add_u32_e32 v28, 16, v6                                   ; 68380c90
	v_add_u32_e32 v29, v28, v4                                  ; 683a091c
	v_add_u32_e32 v28, v28, v30                                 ; 68383d1c
	buffer_load_dwordx4 v[32:35], v6, s[20:23], 0 offen         ; e05c1000 80052006
	buffer_load_dword v29, v29, s[20:23], 0 offen               ; e0501000 80051d1d
	buffer_load_dword v28, v28, s[20:23], 0 offen               ; e0501000 80051c1c
	s_mov_b32 s18, 0xf0f0f0f                                    ; be9200ff 0f0f0f0f
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
	v_and_b32_e32 v41, s18, v29                                 ; 26523a12
	v_and_or_b32 v35, s18, v35, v31                             ; d2010023 047e4612
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
	v_and_b32_e32 v29, s18, v29                                 ; 263a3a12
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
	v_and_b32_e32 v46, s18, v28                                 ; 265c3812
	v_lshrrev_b32_e32 v28, 4, v28                               ; 20383884
	v_mac_f32_e32 v15, v12, v29                                 ; 2c1e3b0c
	v_cvt_f32_ubyte1_e32 v8, v46                                ; 7e10252e
	v_cvt_f32_ubyte2_e32 v7, v46                                ; 7e0e272e
	v_cvt_f32_ubyte3_e32 v6, v46                                ; 7e0c292e
	v_cvt_f32_ubyte0_e32 v46, v46                               ; 7e5c232e
	v_and_b32_e32 v28, s18, v28                                 ; 26383812
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
	s_branch BB48                                               ; bf820001
BB47:
	s_mov_b32 s9, src_scc                                       ; be8900fd
BB48:
	v_add_u32_e32 v0, 4, v0                                     ; 68000084
	s_mov_b64 s[20:21], exec                                    ; be94017e
	v_cmpx_le_u32_e32 vcc, s3, v0                               ; 7db60003
BB49:
	s_andn2_b64 s[20:21], s[20:21], exec                        ; 89947e14
	s_cbranch_scc1 BB53                                         ; bf85ff0b
BB54:
	s_mov_b64 exec, s[10:11]                                    ; befe010a
BB57:
	s_andn2_b64 exec, -1, exec                                  ; 89fe7ec1
	v_mov_b32_e32 v3, 0                                         ; 7e060280
	v_mov_b32_e32 v5, 0                                         ; 7e0a0280
BB59:
	s_mov_b64 exec, -1                                          ; befe01c1
	s_cmp_lg_i32 s4, 0                                          ; bf018004
	s_cselect_b64 s[0:1], -1, 0                                 ; 858080c1
	s_cbranch_scc0 BB65                                         ; bf840034
BB60:
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
	s_cbranch_scc0 BB63                                         ; bf840019
BB61:
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
BB63:
	v_mov_b32_e32 v3, s3                                        ; 7e060203
BB65:
	s_mov_b64 s[10:11], 1                                       ; be8a0181
	s_and_b64 exec, s[0:1], s[10:11]                            ; 86fe0a00
	s_cbranch_execz BB89                                        ; bf880045
BB66:
	s_bitcmp1_b32 s8, 0                                         ; bf0d8008
	s_cbranch_scc0 BB68                                         ; bf84000e
BB67:
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
	s_branch BB69                                               ; bf820001
BB68:
	s_mov_b32 s1, src_scc                                       ; be8100fd
BB69:
	s_bitcmp1_b32 s8, 1                                         ; bf0d8108
	s_cbranch_scc0 BB71                                         ; bf84000e
BB70:
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
	s_branch BB72                                               ; bf820001
BB71:
	s_mov_b32 s3, src_scc                                       ; be8300fd
BB72:
	s_mov_b32 s0, s3                                            ; be800003
	s_movk_i32 s3, 0x8000                                       ; b0038000
	s_load_dwordx4 s[8:11], s[2:3], 0x20                        ; c00a0201 00000020
	s_mul_i32 s7, s7, s17                                       ; 92071107
	s_add_u32 s7, s7, s16                                       ; 80071007
	s_lshl_b32 s7, s7, 2                                        ; 8e078207
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_store_dword v3, off, s[8:11], s7                     ; e0700000 07020380
	s_cmp_lt_u32 1, s4                                          ; bf0a0481
	s_cbranch_scc0 BB89                                         ; bf840017
BB73:
	s_cmp_lg_i32 s1, 0                                          ; bf018001
	s_cbranch_scc0 BB76                                         ; bf840008
BB74:
	s_load_dwordx4 s[12:15], s[2:3], 0x30                       ; c00a0301 00000030
	s_add_u32 s1, s7, 4                                         ; 80018407
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s1, s[12:15], s1                        ; c0200046 00000001
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v5, s1, v5                                    ; 020a0a01
BB76:
	s_cmp_lg_i32 s0, 0                                          ; bf018000
	s_cbranch_scc0 BB79                                         ; bf840008
BB77:
	s_load_dwordx4 s[0:3], s[2:3], 0x40                         ; c00a0001 00000040
	s_add_u32 s4, s7, 4                                         ; 80048407
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s4, s[0:3], s4                          ; c0200100 00000004
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v5, s4, v5                                    ; 020a0a04
BB79:
	s_add_u32 s7, s7, 4                                         ; 80078407
	buffer_store_dword v5, off, s[8:11], s7                     ; e0700000 07020580
BB89:
	s_endpgm                                                    ; bf810000
