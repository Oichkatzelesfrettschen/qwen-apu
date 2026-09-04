BB0:
	s_load_dword s0, s[14:15], 0x0                              ; c0020007 00000000
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_mul_i32 s0, s0, s18                                       ; 92001200
	s_add_u32 s16, s16, s0                                      ; 80100010
	s_add_u32 s1, s16, 1                                        ; 80018110
	s_cmp_ge_u32 s4, s1                                         ; bf090104
	s_cbranch_scc0 BB36                                         ; bf840490
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
	s_mul_i32 s6, s17, s6                                       ; 92060611
	v_lshlrev_b32_e32 v1, 4, v0                                 ; 24020084
	s_and_b32 s0, s3, 0xfffffc00                                ; 8600ff03 fffffc00
	s_lshr_b32 s1, s3, 10                                       ; 8f018a03
	v_and_b32_e32 v0, 1, v0                                     ; 26000081
	s_mul_i32 s18, s18, s5                                      ; 92120512
	v_add_u32_e32 v2, s0, v1                                    ; 68040200
	s_lshl_b32 s18, s18, 3                                      ; 8e128312
	s_lshr_b32 s6, s6, 5                                        ; 8f068506
	v_cmp_gt_u32_e32 vcc, s3, v2                                ; 7d980403
	v_mov_b32_e32 v2, 0                                         ; 7e040280
	v_cndmask_b32_e64 v3, 0, 1, vcc                             ; d1000003 01a90280
	v_add_u32_e32 v3, s1, v3                                    ; 68060601
	s_branch BB5                                                ; bf82023b
BB10:
	s_mov_b64 exec, s[0:1]                                      ; befe0100
	s_mov_b32 s0, s2                                            ; be800002
	s_movk_i32 s1, 0x8000                                       ; b0018000
	s_load_dwordx8 s[24:31], s[0:1], 0x0                        ; c00e0600 00000000
	v_lshrrev_b32_e32 v4, 5, v1                                 ; 20080285
	v_lshlrev_b32_e32 v8, 2, v0                                 ; 24100082
	v_add_u32_e32 v4, s6, v4                                    ; 68080806
	v_and_b32_e32 v5, 3, v4                                     ; 260a0883
	v_lshrrev_b32_e32 v4, 2, v4                                 ; 20080882
	v_lshlrev_b32_e32 v6, 4, v4                                 ; 240c0884
	v_lshl_add_u32 v4, v4, 7, v6                                ; d1fd0004 04190f04
	v_lshl_add_u32 v7, v5, 2, v4                                ; d1fd0007 04110505
	v_lshl_add_u32 v5, v5, 3, v8                                ; d1fd0005 04210705
	v_lshlrev_b32_e32 v5, 2, v5                                 ; 240a0a82
	v_add3_u32 v5, v5, 16, v4                                   ; d1ff0005 04112105
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_load_dword v7, v7, s[28:31], 0 offen                 ; e0501000 80070707
	buffer_load_dwordx4 v[12:15], v5, s[28:31], 0 offen         ; e05c1000 80070c05
	s_mul_i32 s0, s16, s3                                       ; 92000310
	v_add_u32_e32 v9, s0, v1                                    ; 68120200
	v_lshrrev_b32_e32 v9, 5, v9                                 ; 20121285
	v_add_u32_e32 v9, s18, v9                                   ; 68121212
	v_and_b32_e32 v10, 7, v9                                    ; 26141287
	v_lshrrev_b32_e32 v9, 3, v9                                 ; 20121283
	v_lshl_add_u32 v10, v10, 3, v8                              ; d1fd000a 0421070a
	v_lshlrev_b32_e32 v17, 4, v9                                ; 24221284
	v_and_b32_e32 v11, 7, v10                                   ; 26161487
	v_lshrrev_b32_e32 v16, 4, v10                               ; 20201484
	v_lshl_add_u32 v9, v9, 7, v17                               ; d1fd0009 04450f09
	v_lshl_add_u32 v16, v16, 3, v11                             ; d1fd0010 042d0710
	v_lshlrev_b32_e32 v16, 2, v16                               ; 24202082
	v_add3_u32 v16, v16, 16, v9                                 ; d1ff0010 04252110
	buffer_load_dwordx4 v[16:19], v16, s[24:27], 0 offen        ; e05c1000 80061010
	buffer_load_dwordx4 v[20:23], v9, s[24:27], 0 offen         ; e05c1000 80061409
	v_add_u32_e32 v24, 0x400, v1                                ; 683002ff 00000400
	v_lshrrev_b32_e32 v25, 5, v24                               ; 20323085
	v_add_u32_e32 v25, s6, v25                                  ; 68323206
	v_and_b32_e32 v26, 3, v25                                   ; 26343283
	v_lshrrev_b32_e32 v25, 2, v25                               ; 20323282
	v_lshlrev_b32_e32 v27, 4, v25                               ; 24363284
	v_lshl_add_u32 v25, v25, 7, v27                             ; d1fd0019 046d0f19
	v_lshl_add_u32 v28, v26, 2, v25                             ; d1fd001c 0465051a
	v_lshl_add_u32 v26, v26, 3, v8                              ; d1fd001a 0421071a
	v_lshlrev_b32_e32 v26, 2, v26                               ; 24343482
	v_add3_u32 v26, v26, 16, v25                                ; d1ff001a 0465211a
	buffer_load_dword v28, v28, s[28:31], 0 offen               ; e0501000 80071c1c
	buffer_load_dwordx4 v[30:33], v26, s[28:31], 0 offen        ; e05c1000 80071e1a
	v_add_u32_e32 v24, s0, v24                                  ; 68303000
	v_bfe_u32 v6, v10, 3, 1                                     ; d1c80006 0205070a
	v_lshrrev_b32_e32 v10, 3, v10                               ; 20141483
	v_lshrrev_b32_e32 v24, 5, v24                               ; 20303085
	v_lshlrev_b32_e32 v6, 2, v6                                 ; 240c0c82
	v_and_b32_e32 v9, 3, v10                                    ; 26121483
	v_cmp_gt_u32_e32 vcc, 4, v10                                ; 7d981484
	v_add_u32_e32 v24, s18, v24                                 ; 68303012
	v_lshlrev_b32_e32 v9, 3, v9                                 ; 24121283
	s_mov_b32 s1, 0xf0f0f0f                                     ; be8100ff 0f0f0f0f
	v_and_b32_e32 v29, 7, v24                                   ; 263a3087
	v_lshrrev_b32_e32 v24, 3, v24                               ; 20303083
	v_add_u32_e32 v11, 2, v9                                    ; 68161282
	v_add_u32_e32 v25, 4, v9                                    ; 68321284
	v_lshl_add_u32 v29, v29, 3, v8                              ; d1fd001d 0421071d
	v_lshlrev_b32_e32 v5, 4, v24                                ; 240a3084
	v_cndmask_b32_e32 v11, v11, v9, vcc                         ; 0016130b
	v_cndmask_b32_e32 v25, v25, v9, vcc                         ; 00321319
	v_and_b32_e32 v34, 7, v29                                   ; 26443a87
	v_lshrrev_b32_e32 v4, 4, v29                                ; 20083a84
	v_lshl_add_u32 v24, v24, 7, v5                              ; d1fd0018 04150f18
	v_lshl_add_u32 v4, v4, 3, v34                               ; d1fd0004 04890704
	v_lshlrev_b32_e32 v4, 2, v4                                 ; 24080882
	v_add3_u32 v4, v4, 16, v24                                  ; d1ff0004 04612104
	s_waitcnt vmcnt(5)                                          ; bf8c3f75
	v_mov_b32_e32 v34, v7                                       ; 7e440307
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_lshrrev_b32_e32 v17, v6, v17                              ; 20222306
	v_lshrrev_b32_e32 v18, v6, v18                              ; 20242506
	v_lshrrev_b32_e32 v16, v6, v16                              ; 20202106
	v_lshrrev_b32_e32 v6, v6, v19                               ; 200c2706
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_cndmask_b32_e32 v26, v23, v22, vcc                        ; 00342d17
	v_cndmask_b32_e32 v23, v23, v21, vcc                        ; 002e2b17
	v_lshrrev_b32_e32 v21, v11, v21                             ; 202a2b0b
	v_mov_b32_e32 v27, v6                                       ; 7e360306
	v_bfe_u32 v26, v26, v25, 4                                  ; d1c8001a 0212331a
	v_bfe_u32 v23, v23, v9, 4                                   ; d1c80017 02121317
	v_mov_b32_e32 v9, v22                                       ; 7e120316
	v_and_or_b32 v21, 48, v21, v23                              ; d2010015 045e2ab0
	buffer_load_dwordx4 v[4:7], v4, s[24:27], 0 offen           ; e05c1000 80060404
	buffer_load_dwordx4 v[22:25], v24, s[24:27], 0 offen        ; e05c1000 80061618
	v_and_b32_e32 v17, s1, v17                                  ; 26222201
	v_cvt_f32_f16_e32 v10, v20                                  ; 7e141714
	v_cvt_f32_f16_sdwa v20, v20 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e2816f9 00050614
	v_lshrrev_b32_e32 v11, v11, v9                              ; 2016130b
	v_cvt_f32_ubyte0_e32 v21, v21                               ; 7e2a2315
	v_and_b32_e32 v16, s1, v16                                  ; 26202001
	v_mul_i32_i24_sdwa v19, sext(v17), sext(v13) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 0c261af9 09090611
	v_and_or_b32 v11, 48, v11, v26                              ; d201000b 046a16b0
	v_mul_f32_e32 v10, v10, v21                                 ; 0a142b0a
	v_mul_i32_i24_sdwa v21, sext(v17), sext(v13) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 0c2a1af9 0a0a0611
	v_and_b32_e32 v18, s1, v18                                  ; 26242401
	v_mul_i32_i24_sdwa v26, sext(v16), sext(v12) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 src1_sel:BYTE_0 ; 0c3418f9 08080610
	v_mul_i32_i24_sdwa v9, sext(v16), sext(v12) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 0c1218f9 09090610
	v_cvt_f32_ubyte0_e32 v11, v11                               ; 7e16230b
	v_mul_f32_e32 v20, v20, v11                                 ; 0a281714
	v_mul_i32_i24_sdwa v11, sext(v17), sext(v13) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 src1_sel:BYTE_0 ; 0c161af9 08080611
	v_mul_i32_i24_sdwa v17, sext(v17), sext(v13) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 0c221af9 0b0b0611
	v_mul_i32_i24_sdwa v13, sext(v16), sext(v12) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 0c1a18f9 0a0a0610
	v_mul_i32_i24_sdwa v16, sext(v16), sext(v12) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 0c2018f9 0b0b0610
	v_add3_u32 v11, v11, v19, v21                               ; d1ff000b 0456270b
	v_add_u32_e32 v21, 0x800, v1                                ; 682a02ff 00000800
	v_mul_i32_i24_sdwa v19, sext(v18), sext(v14) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 0c261cf9 0a0a0612
	v_add3_u32 v26, v26, v9, v13                                ; d1ff001a 0436131a
	v_add3_u32 v11, v11, v17, 0                                 ; d1ff000b 0202230b
	v_mul_i32_i24_sdwa v17, sext(v18), sext(v14) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 0c221cf9 09090612
	v_and_b32_e32 v27, s1, v27                                  ; 26363601
	v_lshrrev_b32_e32 v9, 5, v21                                ; 20122a85
	v_add3_u32 v26, v26, v16, v11                               ; d1ff001a 042e211a
	v_mul_i32_i24_sdwa v16, sext(v18), sext(v14) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 src1_sel:BYTE_0 ; 0c201cf9 08080612
	v_mul_i32_i24_sdwa v18, sext(v18), sext(v14) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 0c241cf9 0b0b0612
	v_mul_i32_i24_sdwa v14, sext(v27), sext(v15) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 src1_sel:BYTE_0 ; 0c1c1ef9 0808061b
	v_add_u32_e32 v9, s6, v9                                    ; 68121206
	v_add3_u32 v16, v16, v17, v19                               ; d1ff0010 044e2310
	v_mov_b32_e32 v19, v10                                      ; 7e26030a
	v_and_b32_e32 v11, 3, v9                                    ; 26161283
	v_lshrrev_b32_e32 v9, 2, v9                                 ; 20121282
	v_lshlrev_b32_e32 v12, 4, v9                                ; 24181284
	v_lshl_add_u32 v9, v9, 7, v12                               ; d1fd0009 04310f09
	v_lshl_add_u32 v13, v11, 2, v9                              ; d1fd000d 0425050b
	v_lshl_add_u32 v11, v11, 3, v8                              ; d1fd000b 0421070b
	v_lshlrev_b32_e32 v11, 2, v11                               ; 24161682
	v_add3_u32 v11, v11, 16, v9                                 ; d1ff000b 0425210b
	buffer_load_dword v13, v13, s[28:31], 0 offen               ; e0501000 80070d0d
	buffer_load_dwordx4 v[9:12], v11, s[28:31], 0 offen         ; e05c1000 8007090b
	v_mul_i32_i24_sdwa v17, sext(v27), sext(v15) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 0c221ef9 0909061b
	v_add3_u32 v16, v16, v18, v26                               ; d1ff0010 046a2510
	v_mul_i32_i24_sdwa v18, sext(v27), sext(v15) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 0c241ef9 0a0a061b
	v_mul_i32_i24_sdwa v27, sext(v27), sext(v15) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 0c361ef9 0b0b061b
	v_cvt_f32_f16_e32 v26, v34                                  ; 7e341722
	v_cvt_f32_f16_sdwa v34, v34 div:2 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e4416f9 0005c622
	v_add_u32_e32 v21, s0, v21                                  ; 682a2a00
	v_add3_u32 v14, v14, v17, v18                               ; d1ff000e 044a230e
	v_mul_f32_e32 v26, v26, v19                                 ; 0a34271a
	v_lshrrev_b32_e32 v21, 5, v21                               ; 202a2a85
	v_add3_u32 v14, v14, v27, v16                               ; d1ff000e 0442370e
	v_bfe_u32 v17, v29, 3, 1                                    ; d1c80011 0205071d
	v_add_u32_e32 v21, s18, v21                                 ; 682a2a12
	v_lshrrev_b32_e32 v29, 3, v29                               ; 203a3a83
	v_cvt_f32_i32_e32 v14, v14                                  ; 7e1c0b0e
	v_lshlrev_b32_e32 v17, 2, v17                               ; 24222282
	v_and_b32_e32 v27, 7, v21                                   ; 26362a87
	v_lshrrev_b32_e32 v21, 3, v21                               ; 202a2a83
	v_and_b32_e32 v18, 3, v29                                   ; 26243a83
	v_cmp_gt_u32_e32 vcc, 4, v29                                ; 7d983a84
	v_mac_f32_e32 v2, v26, v14                                  ; 2c041d1a
	v_lshl_add_u32 v27, v27, 3, v8                              ; d1fd001b 0421071b
	v_lshlrev_b32_e32 v16, 4, v21                               ; 24202a84
	v_lshlrev_b32_e32 v18, 3, v18                               ; 24242483
	v_mad_f32 v20, -v20, v34, v2                                ; d1c10014 240a4514
	v_lshrrev_b32_e32 v15, 4, v27                               ; 201e3684
	v_and_b32_e32 v14, 7, v27                                   ; 261c3687
	v_lshl_add_u32 v21, v21, 7, v16                             ; d1fd0015 04410f15
	v_add_u32_e32 v26, 4, v18                                   ; 68342484
	v_add_u32_e32 v19, 2, v18                                   ; 68262482
	v_lshl_add_u32 v15, v15, 3, v14                             ; d1fd000f 0439070f
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_lshrrev_b32_e32 v4, v17, v4                               ; 20080911
	v_lshrrev_b32_e32 v6, v17, v6                               ; 200c0d11
	v_lshlrev_b32_e32 v15, 2, v15                               ; 241e1e82
	v_add3_u32 v15, v15, 16, v21                                ; d1ff000f 0455210f
	v_lshrrev_b32_e32 v5, v17, v5                               ; 200a0b11
	v_lshrrev_b32_e32 v17, v17, v7                              ; 20220f11
	v_cndmask_b32_e32 v26, v26, v18, vcc                        ; 0034251a
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_cndmask_b32_e32 v29, v25, v24, vcc                        ; 003a3119
	v_cndmask_b32_e32 v25, v25, v23, vcc                        ; 00322f19
	v_cndmask_b32_e32 v19, v19, v18, vcc                        ; 00262513
	v_mov_b32_e32 v7, v24                                       ; 7e0e0318
	v_bfe_u32 v29, v29, v26, 4                                  ; d1c8001d 0212351d
	v_bfe_u32 v25, v25, v18, 4                                  ; d1c80019 02122519
	v_mov_b32_e32 v18, v27                                      ; 7e24031b
	v_lshrrev_b32_e32 v23, v19, v23                             ; 202e2f13
	v_and_or_b32 v23, 48, v23, v25                              ; d2010017 04662eb0
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_mov_b32_e32 v2, v13                                       ; 7e04030d
	buffer_load_dwordx4 v[13:16], v15, s[24:27], 0 offen        ; e05c1000 80060d0f
	buffer_load_dwordx4 v[24:27], v21, s[24:27], 0 offen        ; e05c1000 80061815
	v_and_b32_e32 v5, s1, v5                                    ; 260a0a01
	v_cvt_f32_f16_e32 v21, v22                                  ; 7e2a1716
	v_cvt_f32_f16_sdwa v22, v22 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e2c16f9 00050616
	v_lshrrev_b32_e32 v19, v19, v7                              ; 20260f13
	v_cvt_f32_ubyte0_e32 v23, v23                               ; 7e2e2317
	v_and_b32_e32 v4, s1, v4                                    ; 26080801
	v_mul_i32_i24_sdwa v34, sext(v5), sext(v31) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 0c443ef9 0a0a0605
	v_and_or_b32 v19, 48, v19, v29                              ; d2010013 047626b0
	v_mul_i32_i24_sdwa v29, sext(v5), sext(v31) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 0c3a3ef9 09090605
	v_mul_f32_e32 v21, v21, v23                                 ; 0a2a2f15
	v_mul_i32_i24_sdwa v23, sext(v5), sext(v31) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 src1_sel:BYTE_0 ; 0c2e3ef9 08080605
	v_mul_i32_i24_sdwa v5, sext(v5), sext(v31) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 0c0a3ef9 0b0b0605
	v_mul_i32_i24_sdwa v31, sext(v4), sext(v30) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 src1_sel:BYTE_0 ; 0c3e3cf9 08080604
	v_and_b32_e32 v6, s1, v6                                    ; 260c0c01
	v_cvt_f32_ubyte0_e32 v19, v19                               ; 7e262313
	v_add3_u32 v23, v23, v29, v34                               ; d1ff0017 048a3b17
	v_mul_i32_i24_sdwa v34, sext(v4), sext(v30) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 0c443cf9 09090604
	v_add_u32_e32 v29, 0xc00, v1                                ; 683a02ff 00000c00
	v_mul_i32_i24_sdwa v7, sext(v6), sext(v32) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 src1_sel:BYTE_0 ; 0c0e40f9 08080606
	v_mul_f32_e32 v22, v22, v19                                 ; 0a2c2716
	v_mul_i32_i24_sdwa v19, sext(v6), sext(v32) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 0c2640f9 09090606
	v_add3_u32 v23, v23, v5, 0                                  ; d1ff0017 02020b17
	v_mul_i32_i24_sdwa v5, sext(v4), sext(v30) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 0c0a3cf9 0a0a0604
	v_mul_i32_i24_sdwa v4, sext(v4), sext(v30) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 0c083cf9 0b0b0604
	v_lshrrev_b32_e32 v30, 5, v29                               ; 203c3a85
	v_and_b32_e32 v17, s1, v17                                  ; 26222201
	v_add3_u32 v31, v31, v34, v5                                ; d1ff001f 0416451f
	v_add_u32_e32 v30, s6, v30                                  ; 683c3c06
	v_mul_i32_i24_sdwa v5, sext(v17), sext(v33) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 0c0a42f9 09090611
	v_add3_u32 v31, v31, v4, v23                                ; d1ff001f 045e091f
	v_mul_i32_i24_sdwa v23, sext(v6), sext(v32) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 0c2e40f9 0a0a0606
	v_mul_i32_i24_sdwa v6, sext(v6), sext(v32) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 0c0c40f9 0b0b0606
	v_mul_i32_i24_sdwa v4, sext(v17), sext(v33) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 src1_sel:BYTE_0 ; 0c0842f9 08080611
	v_and_b32_e32 v32, 3, v30                                   ; 26403c83
	v_lshrrev_b32_e32 v30, 2, v30                               ; 203c3c82
	v_add3_u32 v7, v7, v19, v23                                 ; d1ff0007 045e2707
	v_lshlrev_b32_e32 v34, 4, v30                               ; 24443c84
	v_add3_u32 v7, v7, v6, v31                                  ; d1ff0007 047e0d07
	v_mul_i32_i24_sdwa v6, sext(v17), sext(v33) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 0c0c42f9 0a0a0611
	v_mul_i32_i24_sdwa v17, sext(v17), sext(v33) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 0c2242f9 0b0b0611
	v_lshl_add_u32 v30, v30, 7, v34                             ; d1fd001e 04890f1e
	v_lshl_add_u32 v34, v32, 2, v30                             ; d1fd0022 04790520
	v_lshl_add_u32 v32, v32, 3, v8                              ; d1fd0020 04210720
	v_lshlrev_b32_e32 v32, 2, v32                               ; 24404082
	v_add3_u32 v32, v32, 16, v30                                ; d1ff0020 04792120
	buffer_load_dword v34, v34, s[28:31], 0 offen               ; e0501000 80072222
	buffer_load_dwordx4 v[30:33], v32, s[28:31], 0 offen        ; e05c1000 80071e20
	v_add_u32_e32 v29, s0, v29                                  ; 683a3a00
	v_add3_u32 v4, v4, v5, v6                                   ; d1ff0004 041a0b04
	v_lshrrev_b32_e32 v29, 5, v29                               ; 203a3a85
	v_add3_u32 v4, v4, v17, v7                                  ; d1ff0004 041e2304
	v_cvt_f32_f16_e32 v7, v28                                   ; 7e0e171c
	v_cvt_f32_f16_sdwa v28, v28 div:2 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e3816f9 0005c61c
	v_add_u32_e32 v29, s18, v29                                 ; 683a3a12
	v_cvt_f32_i32_e32 v4, v4                                    ; 7e080b04
	v_mul_f32_e32 v7, v7, v21                                   ; 0a0e2b07
	v_and_b32_e32 v17, 7, v29                                   ; 26223a87
	v_lshrrev_b32_e32 v29, 3, v29                               ; 203a3a83
	v_mac_f32_e32 v20, v7, v4                                   ; 2c280907
	v_lshl_add_u32 v17, v17, 3, v8                              ; d1fd0011 04210711
	v_lshlrev_b32_e32 v23, 4, v29                               ; 242e3a84
	v_mad_f32 v22, -v22, v28, v20                               ; d1c10016 24523916
	v_bfe_u32 v28, v18, 3, 1                                    ; d1c8001c 02050712
	v_lshrrev_b32_e32 v18, 3, v18                               ; 20242483
	v_and_b32_e32 v19, 7, v17                                   ; 26262287
	v_lshrrev_b32_e32 v21, 4, v17                               ; 202a2284
	v_lshl_add_u32 v29, v29, 7, v23                             ; d1fd001d 045d0f1d
	v_bfe_u32 v7, v17, 3, 1                                     ; d1c80007 02050711
	v_lshlrev_b32_e32 v28, 2, v28                               ; 24383882
	v_cmp_gt_u32_e32 vcc, 4, v18                                ; 7d982484
	v_and_b32_e32 v4, 3, v18                                    ; 26082483
	v_lshl_add_u32 v21, v21, 3, v19                             ; d1fd0015 044d0715
	v_lshlrev_b32_e32 v7, 2, v7                                 ; 240e0e82
	v_lshlrev_b32_e32 v4, 3, v4                                 ; 24080883
	v_lshlrev_b32_e32 v21, 2, v21                               ; 242a2a82
	v_add_u32_e32 v5, 2, v4                                     ; 680a0882
	v_add_u32_e32 v6, 4, v4                                     ; 680c0884
	v_add3_u32 v21, v21, 16, v29                                ; d1ff0015 04752115
	buffer_load_dwordx4 v[18:21], v21, s[24:27], 0 offen        ; e05c1000 80061215
	s_waitcnt vmcnt(4)                                          ; bf8c3f74
	v_lshrrev_b32_e32 v13, v28, v13                             ; 201a1b1c
	v_lshrrev_b32_e32 v15, v28, v15                             ; 201e1f1c
	v_lshrrev_b32_e32 v14, v28, v14                             ; 201c1d1c
	v_lshrrev_b32_e32 v28, v28, v16                             ; 2038211c
	v_cndmask_b32_e32 v5, v5, v4, vcc                           ; 000a0905
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_cndmask_b32_e32 v8, v27, v26, vcc                         ; 0010351b
	v_cndmask_b32_e32 v27, v27, v25, vcc                        ; 0036331b
	v_cndmask_b32_e32 v6, v6, v4, vcc                           ; 000c0906
	v_mov_b32_e32 v23, v7                                       ; 7e2e0307
	v_lshrrev_b32_e32 v25, v5, v25                              ; 20323305
	v_mov_b32_e32 v16, v5                                       ; 7e200305
	v_bfe_u32 v27, v27, v4, 4                                   ; d1c8001b 0212091b
	v_bfe_u32 v8, v8, v6, 4                                     ; d1c80008 02120d08
	buffer_load_dwordx4 v[4:7], v29, s[24:27], 0 offen          ; e05c1000 8006041d
	v_and_b32_e32 v14, s1, v14                                  ; 261c1c01
	v_lshrrev_b32_e32 v16, v16, v26                             ; 20203510
	v_cvt_f32_f16_e32 v26, v24                                  ; 7e341718
	v_cvt_f32_f16_sdwa v24, v24 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e3016f9 00050618
	v_and_or_b32 v25, 48, v25, v27                              ; d2010019 046e32b0
	v_and_b32_e32 v13, s1, v13                                  ; 261a1a01
	v_mul_i32_i24_sdwa v27, sext(v14), sext(v10) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 src1_sel:BYTE_0 ; 0c3614f9 0808060e
	v_mul_i32_i24_sdwa v29, sext(v14), sext(v10) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 0c3a14f9 0909060e
	v_and_or_b32 v16, 48, v16, v8                               ; d2010010 042220b0
	v_mul_i32_i24_sdwa v8, sext(v14), sext(v10) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 0c1014f9 0a0a060e
	v_mul_i32_i24_sdwa v14, sext(v14), sext(v10) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 0c1c14f9 0b0b060e
	v_cvt_f32_ubyte0_e32 v25, v25                               ; 7e322319
	v_mul_i32_i24_sdwa v10, sext(v13), sext(v9) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 src1_sel:BYTE_0 ; 0c1412f9 0808060d
	v_and_b32_e32 v15, s1, v15                                  ; 261e1e01
	v_cvt_f32_ubyte0_e32 v16, v16                               ; 7e202310
	v_add3_u32 v27, v27, v29, v8                                ; d1ff001b 04223b1b
	v_mul_f32_e32 v26, v26, v25                                 ; 0a34331a
	v_mul_i32_i24_sdwa v29, sext(v15), sext(v11) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 0c3a16f9 0a0a060f
	v_and_b32_e32 v28, s1, v28                                  ; 26383801
	v_mul_i32_i24_sdwa v25, sext(v15), sext(v11) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 src1_sel:BYTE_0 ; 0c3216f9 0808060f
	v_mul_f32_e32 v24, v24, v16                                 ; 0a302118
	v_mul_i32_i24_sdwa v16, sext(v13), sext(v9) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 0c2012f9 0a0a060d
	v_add3_u32 v27, v27, v14, 0                                 ; d1ff001b 02021d1b
	v_mul_i32_i24_sdwa v14, sext(v13), sext(v9) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 0c1c12f9 0909060d
	v_mul_i32_i24_sdwa v13, sext(v13), sext(v9) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 0c1a12f9 0b0b060d
	v_mul_i32_i24_sdwa v9, sext(v28), sext(v12) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 0c1218f9 0909061c
	v_mul_i32_i24_sdwa v8, sext(v28), sext(v12) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 src1_sel:BYTE_0 ; 0c1018f9 0808061c
	v_add3_u32 v10, v10, v14, v16                               ; d1ff000a 04421d0a
	v_lshrrev_b32_e32 v17, 3, v17                               ; 20222283
	v_add3_u32 v10, v10, v13, v27                               ; d1ff000a 046e1b0a
	v_mul_i32_i24_sdwa v27, sext(v15), sext(v11) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 0c3616f9 0909060f
	v_mul_i32_i24_sdwa v15, sext(v15), sext(v11) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 0c1e16f9 0b0b060f
	v_cvt_f32_f16_e32 v11, v2                                   ; 7e161702
	v_cvt_f32_f16_sdwa v2, v2 div:2 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e0416f9 0005c602
	v_add3_u32 v25, v25, v27, v29                               ; d1ff0019 04763719
	v_cmp_gt_u32_e32 vcc, 4, v17                                ; 7d982284
	v_mul_f32_e32 v11, v11, v26                                 ; 0a16350b
	v_add3_u32 v25, v25, v15, v10                               ; d1ff0019 042a1f19
	v_mul_i32_i24_sdwa v10, sext(v28), sext(v12) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 0c1418f9 0a0a061c
	v_mul_i32_i24_sdwa v28, sext(v28), sext(v12) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 0c3818f9 0b0b061c
	v_and_b32_e32 v12, 3, v17                                   ; 26182283
	v_add_u32_e32 v3, -4, v3                                    ; 680606c4
	v_add_u32_e32 v1, 0x1000, v1                                ; 680202ff 00001000
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_cvt_f32_f16_e32 v15, v34                                  ; 7e1e1722
	v_cvt_f32_f16_sdwa v34, v34 div:2 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e4416f9 0005c622
	v_add3_u32 v8, v8, v9, v10                                  ; d1ff0008 042a1308
	v_lshlrev_b32_e32 v12, 3, v12                               ; 24181883
	v_add3_u32 v8, v8, v28, v25                                 ; d1ff0008 04663908
	v_add_u32_e32 v14, 4, v12                                   ; 681c1884
	v_add_u32_e32 v13, 2, v12                                   ; 681a1882
	v_cvt_f32_i32_e32 v8, v8                                    ; 7e100b08
	v_cndmask_b32_e32 v14, v14, v12, vcc                        ; 001c190e
	v_cndmask_b32_e32 v13, v13, v12, vcc                        ; 001a190d
	v_mac_f32_e32 v22, v11, v8                                  ; 2c2c110b
	v_mad_f32 v24, -v24, v2, v22                                ; d1c10018 245a0518
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_lshrrev_b32_e32 v18, v23, v18                             ; 20242517
	v_lshrrev_b32_e32 v19, v23, v19                             ; 20262717
	v_lshrrev_b32_e32 v20, v23, v20                             ; 20282917
	v_lshrrev_b32_e32 v23, v23, v21                             ; 202e2b17
	v_and_b32_e32 v18, s1, v18                                  ; 26242401
	v_and_b32_e32 v19, s1, v19                                  ; 26262601
	v_and_b32_e32 v20, s1, v20                                  ; 26282801
	v_mul_i32_i24_sdwa v26, sext(v18), sext(v30) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 0c343cf9 0a0a0612
	v_mul_i32_i24_sdwa v25, sext(v18), sext(v30) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 0c323cf9 09090612
	v_mul_i32_i24_sdwa v22, sext(v18), sext(v30) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 src1_sel:BYTE_0 ; 0c2c3cf9 08080612
	v_mul_i32_i24_sdwa v18, sext(v18), sext(v30) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 0c243cf9 0b0b0612
	v_mul_i32_i24_sdwa v16, sext(v19), sext(v31) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 src1_sel:BYTE_0 ; 0c203ef9 08080613
	v_mul_i32_i24_sdwa v17, sext(v19), sext(v31) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 0c223ef9 09090613
	v_mul_i32_i24_sdwa v21, sext(v19), sext(v31) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 0c2a3ef9 0a0a0613
	v_mul_i32_i24_sdwa v19, sext(v19), sext(v31) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 0c263ef9 0b0b0613
	v_mul_i32_i24_sdwa v28, sext(v20), sext(v32) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 0c3840f9 09090614
	v_mul_i32_i24_sdwa v27, sext(v20), sext(v32) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 src1_sel:BYTE_0 ; 0c3640f9 08080614
	v_mul_i32_i24_sdwa v29, sext(v20), sext(v32) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 0c3a40f9 0a0a0614
	v_mul_i32_i24_sdwa v20, sext(v20), sext(v32) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 0c2840f9 0b0b0614
	v_and_b32_e32 v23, s1, v23                                  ; 262e2e01
	v_add3_u32 v22, v22, v25, v26                               ; d1ff0016 046a3316
	v_add3_u32 v16, v16, v17, v21                               ; d1ff0010 04562310
	v_add3_u32 v27, v27, v28, v29                               ; d1ff001b 0476391b
	v_mul_i32_i24_sdwa v31, sext(v23), sext(v33) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 0c3e42f9 09090617
	v_mul_i32_i24_sdwa v32, sext(v23), sext(v33) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 0c4042f9 0a0a0617
	v_mul_i32_i24_sdwa v30, sext(v23), sext(v33) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 src1_sel:BYTE_0 ; 0c3c42f9 08080617
	v_mul_i32_i24_sdwa v23, sext(v23), sext(v33) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 0c2e42f9 0b0b0617
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_cndmask_b32_e32 v33, v7, v6, vcc                          ; 00420d07
	v_cndmask_b32_e32 v7, v7, v5, vcc                           ; 000e0b07
	v_lshrrev_b32_e32 v5, v13, v5                               ; 200a0b0d
	v_add3_u32 v16, v16, v19, 0                                 ; d1ff0010 02022710
	v_lshrrev_b32_e32 v13, v13, v6                              ; 201a0d0d
	v_add3_u32 v30, v30, v31, v32                               ; d1ff001e 04823f1e
	v_cvt_f32_f16_e32 v2, v4                                    ; 7e041704
	v_bfe_u32 v33, v33, v14, 4                                  ; d1c80021 02121d21
	v_cvt_f32_f16_sdwa v4, v4 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e0816f9 00050604
	v_bfe_u32 v7, v7, v12, 4                                    ; d1c80007 02121907
	v_add3_u32 v22, v22, v18, v16                               ; d1ff0016 04422516
	v_and_or_b32 v13, 48, v13, v33                              ; d201000d 04861ab0
	v_and_or_b32 v5, 48, v5, v7                                 ; d2010005 041e0ab0
	v_add3_u32 v27, v27, v20, v22                               ; d1ff001b 045a291b
	v_cvt_f32_ubyte0_e32 v13, v13                               ; 7e1a230d
	v_cvt_f32_ubyte0_e32 v5, v5                                 ; 7e0a2305
	v_add3_u32 v30, v30, v23, v27                               ; d1ff001e 046e2f1e
	v_mul_f32_e32 v4, v4, v13                                   ; 0a081b04
	v_mul_f32_e32 v2, v2, v5                                    ; 0a040b02
	v_cvt_f32_i32_e32 v30, v30                                  ; 7e3c0b1e
	v_mul_f32_e32 v15, v15, v2                                  ; 0a1e050f
	v_mac_f32_e32 v24, v15, v30                                 ; 2c303d0f
	v_mad_f32 v2, -v4, v34, v24                                 ; d1c10002 24624504
BB5:
	s_mov_b64 s[0:1], exec                                      ; be80017e
	v_cmpx_gt_u32_e32 vcc, 4, v3                                ; 7db80684
BB6:
	s_andn2_b64 s[0:1], s[0:1], exec                            ; 89807e00
	s_cbranch_scc1 BB10                                         ; bf85fdc1
BB11:
	s_mov_b64 exec, -1                                          ; befe01c1
	v_cmpx_le_u32_e32 vcc, 2, v3                                ; 7db60682
	s_cbranch_execz BB17                                        ; bf880120
BB12:
	s_mov_b32 s0, s2                                            ; be800002
	s_movk_i32 s1, 0x8000                                       ; b0018000
	s_load_dwordx8 s[24:31], s[0:1], 0x0                        ; c00e0600 00000000
	v_lshrrev_b32_e32 v4, 5, v1                                 ; 20080285
	v_lshlrev_b32_e32 v8, 2, v0                                 ; 24100082
	v_add_u32_e32 v4, s6, v4                                    ; 68080806
	v_and_b32_e32 v5, 3, v4                                     ; 260a0883
	v_lshrrev_b32_e32 v4, 2, v4                                 ; 20080882
	v_lshlrev_b32_e32 v6, 4, v4                                 ; 240c0884
	v_lshl_add_u32 v4, v4, 7, v6                                ; d1fd0004 04190f04
	v_lshl_add_u32 v7, v5, 2, v4                                ; d1fd0007 04110505
	v_lshl_add_u32 v5, v5, 3, v8                                ; d1fd0005 04210705
	v_lshlrev_b32_e32 v5, 2, v5                                 ; 240a0a82
	v_add3_u32 v5, v5, 16, v4                                   ; d1ff0005 04112105
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_load_dword v7, v7, s[28:31], 0 offen                 ; e0501000 80070707
	buffer_load_dwordx4 v[12:15], v5, s[28:31], 0 offen         ; e05c1000 80070c05
	s_mul_i32 s0, s16, s3                                       ; 92000310
	v_add_u32_e32 v9, s0, v1                                    ; 68120200
	v_lshrrev_b32_e32 v9, 5, v9                                 ; 20121285
	v_add_u32_e32 v9, s18, v9                                   ; 68121212
	v_and_b32_e32 v10, 7, v9                                    ; 26141287
	v_lshrrev_b32_e32 v9, 3, v9                                 ; 20121283
	v_lshl_add_u32 v10, v10, 3, v8                              ; d1fd000a 0421070a
	v_lshlrev_b32_e32 v17, 4, v9                                ; 24221284
	v_and_b32_e32 v11, 7, v10                                   ; 26161487
	v_lshrrev_b32_e32 v16, 4, v10                               ; 20201484
	v_lshl_add_u32 v9, v9, 7, v17                               ; d1fd0009 04450f09
	v_lshl_add_u32 v16, v16, 3, v11                             ; d1fd0010 042d0710
	v_lshlrev_b32_e32 v16, 2, v16                               ; 24202082
	v_add3_u32 v16, v16, 16, v9                                 ; d1ff0010 04252110
	buffer_load_dwordx4 v[16:19], v16, s[24:27], 0 offen        ; e05c1000 80061010
	buffer_load_dwordx4 v[20:23], v9, s[24:27], 0 offen         ; e05c1000 80061409
	v_add_u32_e32 v24, 0x400, v1                                ; 683002ff 00000400
	v_lshrrev_b32_e32 v25, 5, v24                               ; 20323085
	v_add_u32_e32 v25, s6, v25                                  ; 68323206
	v_and_b32_e32 v26, 3, v25                                   ; 26343283
	v_lshrrev_b32_e32 v25, 2, v25                               ; 20323282
	v_lshlrev_b32_e32 v27, 4, v25                               ; 24363284
	v_lshl_add_u32 v25, v25, 7, v27                             ; d1fd0019 046d0f19
	v_lshl_add_u32 v28, v26, 2, v25                             ; d1fd001c 0465051a
	v_lshl_add_u32 v26, v26, 3, v8                              ; d1fd001a 0421071a
	v_lshlrev_b32_e32 v26, 2, v26                               ; 24343482
	v_add3_u32 v26, v26, 16, v25                                ; d1ff001a 0465211a
	buffer_load_dword v28, v28, s[28:31], 0 offen               ; e0501000 80071c1c
	buffer_load_dwordx4 v[30:33], v26, s[28:31], 0 offen        ; e05c1000 80071e1a
	v_add_u32_e32 v24, s0, v24                                  ; 68303000
	v_bfe_u32 v6, v10, 3, 1                                     ; d1c80006 0205070a
	v_lshrrev_b32_e32 v10, 3, v10                               ; 20141483
	v_lshrrev_b32_e32 v24, 5, v24                               ; 20303085
	v_lshlrev_b32_e32 v6, 2, v6                                 ; 240c0c82
	v_cmp_gt_u32_e32 vcc, 4, v10                                ; 7d981484
	v_add_u32_e32 v24, s18, v24                                 ; 68303012
	v_and_b32_e32 v29, 7, v24                                   ; 263a3087
	v_lshrrev_b32_e32 v24, 3, v24                               ; 20303083
	s_mov_b32 s1, 0xf0f0f0f                                     ; be8100ff 0f0f0f0f
	v_lshl_add_u32 v29, v29, 3, v8                              ; d1fd001d 0421071d
	v_and_b32_e32 v8, 3, v10                                    ; 26101483
	v_lshlrev_b32_e32 v5, 4, v24                                ; 240a3084
	v_and_b32_e32 v34, 7, v29                                   ; 26443a87
	v_lshrrev_b32_e32 v4, 4, v29                                ; 20083a84
	v_bfe_u32 v11, v29, 3, 1                                    ; d1c8000b 0205071d
	v_lshlrev_b32_e32 v8, 3, v8                                 ; 24101083
	v_lshl_add_u32 v24, v24, 7, v5                              ; d1fd0018 04150f18
	v_lshl_add_u32 v4, v4, 3, v34                               ; d1fd0004 04890704
	v_lshlrev_b32_e32 v11, 2, v11                               ; 24161682
	v_add_u32_e32 v9, 2, v8                                     ; 68121082
	v_add_u32_e32 v10, 4, v8                                    ; 68141084
	v_lshlrev_b32_e32 v4, 2, v4                                 ; 24080882
	v_cndmask_b32_e32 v9, v9, v8, vcc                           ; 00121109
	v_add3_u32 v4, v4, 16, v24                                  ; d1ff0004 04612104
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_lshrrev_b32_e32 v16, v6, v16                              ; 20202106
	v_cndmask_b32_e32 v10, v10, v8, vcc                         ; 0014110a
	v_lshrrev_b32_e32 v18, v6, v18                              ; 20242506
	v_lshrrev_b32_e32 v17, v6, v17                              ; 20222306
	v_lshrrev_b32_e32 v6, v6, v19                               ; 200c2706
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_cndmask_b32_e32 v19, v23, v22, vcc                        ; 00262d17
	v_cndmask_b32_e32 v23, v23, v21, vcc                        ; 002e2b17
	v_lshrrev_b32_e32 v21, v9, v21                              ; 202a2b09
	v_mov_b32_e32 v34, v6                                       ; 7e440306
	v_bfe_u32 v23, v23, v8, 4                                   ; d1c80017 02121117
	v_mov_b32_e32 v8, v7                                        ; 7e100307
	v_and_or_b32 v21, 48, v21, v23                              ; d2010015 045e2ab0
	v_mov_b32_e32 v23, v24                                      ; 7e2e0318
	buffer_load_dwordx4 v[24:27], v4, s[24:27], 0 offen         ; e05c1000 80061804
	buffer_load_dwordx4 v[4:7], v23, s[24:27], 0 offen          ; e05c1000 80060417
	v_lshrrev_b32_e32 v9, v9, v22                               ; 20122d09
	v_and_b32_e32 v17, s1, v17                                  ; 26222201
	v_bfe_u32 v19, v19, v10, 4                                  ; d1c80013 02121513
	v_cvt_f32_f16_e32 v10, v20                                  ; 7e141714
	v_cvt_f32_f16_sdwa v20, v20 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e2816f9 00050614
	v_cvt_f32_ubyte0_e32 v21, v21                               ; 7e2a2315
	v_and_b32_e32 v16, s1, v16                                  ; 26202001
	v_mul_i32_i24_sdwa v22, sext(v17), sext(v13) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 0c2c1af9 0a0a0611
	v_and_or_b32 v9, 48, v9, v19                                ; d2010009 044e12b0
	v_mul_i32_i24_sdwa v19, sext(v17), sext(v13) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 src1_sel:BYTE_0 ; 0c261af9 08080611
	v_mul_f32_e32 v10, v10, v21                                 ; 0a142b0a
	v_mul_i32_i24_sdwa v21, sext(v17), sext(v13) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 0c2a1af9 09090611
	v_mul_i32_i24_sdwa v17, sext(v17), sext(v13) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 0c221af9 0b0b0611
	v_and_b32_e32 v18, s1, v18                                  ; 26242401
	v_mul_i32_i24_sdwa v13, sext(v16), sext(v12) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 0c1a18f9 0a0a0610
	v_mul_i32_i24_sdwa v23, sext(v16), sext(v12) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 src1_sel:BYTE_0 ; 0c2e18f9 08080610
	v_cvt_f32_ubyte0_e32 v9, v9                                 ; 7e122309
	v_add3_u32 v19, v19, v21, v22                               ; d1ff0013 045a2b13
	v_and_b32_e32 v34, s1, v34                                  ; 26444401
	v_mul_f32_e32 v20, v20, v9                                  ; 0a281314
	v_mul_i32_i24_sdwa v9, sext(v16), sext(v12) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 0c1218f9 09090610
	v_mul_i32_i24_sdwa v16, sext(v16), sext(v12) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 0c2018f9 0b0b0610
	v_add3_u32 v19, v19, v17, 0                                 ; d1ff0013 02022313
	v_mul_i32_i24_sdwa v17, sext(v18), sext(v14) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 0c221cf9 09090612
	v_mul_i32_i24_sdwa v21, sext(v34), sext(v15) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 src1_sel:BYTE_0 ; 0c2a1ef9 08080622
	v_mul_i32_i24_sdwa v22, sext(v34), sext(v15) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 0c2c1ef9 09090622
	v_add3_u32 v23, v23, v9, v13                                ; d1ff0017 04361317
	v_add3_u32 v23, v23, v16, v19                               ; d1ff0017 044e2117
	v_mul_i32_i24_sdwa v19, sext(v18), sext(v14) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 0c261cf9 0a0a0612
	v_mul_i32_i24_sdwa v16, sext(v18), sext(v14) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 src1_sel:BYTE_0 ; 0c201cf9 08080612
	v_mul_i32_i24_sdwa v18, sext(v18), sext(v14) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 0c241cf9 0b0b0612
	v_lshrrev_b32_e32 v29, 3, v29                               ; 203a3a83
	v_add3_u32 v16, v16, v17, v19                               ; d1ff0010 044e2310
	v_cmp_gt_u32_e32 vcc, 4, v29                                ; 7d983a84
	v_add3_u32 v16, v16, v18, v23                               ; d1ff0010 045e2510
	v_mul_i32_i24_sdwa v23, sext(v34), sext(v15) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 0c2e1ef9 0a0a0622
	v_mul_i32_i24_sdwa v34, sext(v34), sext(v15) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 0c441ef9 0b0b0622
	v_add_u32_e32 v3, -2, v3                                    ; 680606c2
	v_add_u32_e32 v1, 0x800, v1                                 ; 680202ff 00000800
	v_add3_u32 v21, v21, v22, v23                               ; d1ff0015 045e2d15
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_cvt_f32_f16_e32 v9, v28                                   ; 7e12171c
	v_cvt_f32_f16_sdwa v28, v28 div:2 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e3816f9 0005c61c
	v_add3_u32 v21, v21, v34, v16                               ; d1ff0015 04424515
	v_cvt_f32_f16_e32 v34, v8                                   ; 7e441708
	v_cvt_f32_f16_sdwa v8, v8 div:2 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e1016f9 0005c608
	v_cvt_f32_i32_e32 v21, v21                                  ; 7e2a0b15
	v_mul_f32_e32 v34, v34, v10                                 ; 0a441522
	v_mac_f32_e32 v2, v34, v21                                  ; 2c042b22
	v_and_b32_e32 v34, 3, v29                                   ; 26443a83
	v_mad_f32 v20, -v20, v8, v2                                 ; d1c10014 240a1114
	v_lshlrev_b32_e32 v34, 3, v34                               ; 24444483
	v_add_u32_e32 v2, 2, v34                                    ; 68044482
	v_add_u32_e32 v8, 4, v34                                    ; 68104484
	v_cndmask_b32_e32 v2, v2, v34, vcc                          ; 00044502
	v_cndmask_b32_e32 v8, v8, v34, vcc                          ; 00104508
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_lshrrev_b32_e32 v26, v11, v26                             ; 2034350b
	v_lshrrev_b32_e32 v24, v11, v24                             ; 2030310b
	v_lshrrev_b32_e32 v25, v11, v25                             ; 2032330b
	v_lshrrev_b32_e32 v11, v11, v27                             ; 2016370b
	v_and_b32_e32 v26, s1, v26                                  ; 26343401
	v_and_b32_e32 v24, s1, v24                                  ; 26303001
	v_and_b32_e32 v25, s1, v25                                  ; 26323201
	v_mul_i32_i24_sdwa v17, sext(v26), sext(v32) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 src1_sel:BYTE_0 ; 0c2240f9 0808061a
	v_mul_i32_i24_sdwa v18, sext(v26), sext(v32) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 0c2440f9 0909061a
	v_mul_i32_i24_sdwa v19, sext(v26), sext(v32) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 0c2640f9 0a0a061a
	v_mul_i32_i24_sdwa v14, sext(v24), sext(v30) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 src1_sel:BYTE_0 ; 0c1c3cf9 08080618
	v_mul_i32_i24_sdwa v26, sext(v26), sext(v32) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 0c3440f9 0b0b061a
	v_mul_i32_i24_sdwa v16, sext(v24), sext(v30) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 0c203cf9 0a0a0618
	v_mul_i32_i24_sdwa v15, sext(v24), sext(v30) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 0c1e3cf9 09090618
	v_mul_i32_i24_sdwa v24, sext(v24), sext(v30) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 0c303cf9 0b0b0618
	v_mul_i32_i24_sdwa v13, sext(v25), sext(v31) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 0c1a3ef9 0a0a0619
	v_mul_i32_i24_sdwa v10, sext(v25), sext(v31) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 src1_sel:BYTE_0 ; 0c143ef9 08080619
	v_mul_i32_i24_sdwa v12, sext(v25), sext(v31) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 0c183ef9 09090619
	v_mul_i32_i24_sdwa v25, sext(v25), sext(v31) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 0c323ef9 0b0b0619
	v_and_b32_e32 v11, s1, v11                                  ; 26161601
	v_add3_u32 v17, v17, v18, v19                               ; d1ff0011 044e2511
	v_add3_u32 v14, v14, v15, v16                               ; d1ff000e 04421f0e
	v_add3_u32 v10, v10, v12, v13                               ; d1ff000a 0436190a
	v_mul_i32_i24_sdwa v21, sext(v11), sext(v33) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 src1_sel:BYTE_0 ; 0c2a42f9 0808060b
	v_mul_i32_i24_sdwa v22, sext(v11), sext(v33) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 0c2c42f9 0909060b
	v_mul_i32_i24_sdwa v23, sext(v11), sext(v33) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 0c2e42f9 0a0a060b
	v_mul_i32_i24_sdwa v11, sext(v11), sext(v33) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 0c1642f9 0b0b060b
	v_add3_u32 v10, v10, v25, 0                                 ; d1ff000a 0202330a
	v_add3_u32 v21, v21, v22, v23                               ; d1ff0015 045e2d15
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_cvt_f32_f16_e32 v25, v4                                   ; 7e321704
	v_cvt_f32_f16_sdwa v4, v4 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e0816f9 00050604
	v_add3_u32 v14, v14, v24, v10                               ; d1ff000e 042a310e
	v_cndmask_b32_e32 v24, v7, v6, vcc                          ; 00300d07
	v_cndmask_b32_e32 v7, v7, v5, vcc                           ; 000e0b07
	v_lshrrev_b32_e32 v5, v2, v5                                ; 200a0b02
	v_lshrrev_b32_e32 v2, v2, v6                                ; 20040d02
	v_add3_u32 v17, v17, v26, v14                               ; d1ff0011 043a3511
	v_bfe_u32 v24, v24, v8, 4                                   ; d1c80018 02121118
	v_bfe_u32 v7, v7, v34, 4                                    ; d1c80007 02124507
	v_add3_u32 v21, v21, v11, v17                               ; d1ff0015 04461715
	v_and_or_b32 v2, 48, v2, v24                                ; d2010002 046204b0
	v_and_or_b32 v5, 48, v5, v7                                 ; d2010005 041e0ab0
	v_cvt_f32_i32_e32 v21, v21                                  ; 7e2a0b15
	v_cvt_f32_ubyte0_e32 v2, v2                                 ; 7e042302
	v_cvt_f32_ubyte0_e32 v5, v5                                 ; 7e0a2305
	v_mul_f32_e32 v4, v4, v2                                    ; 0a080504
	v_mul_f32_e32 v25, v25, v5                                  ; 0a320b19
	v_mul_f32_e32 v9, v9, v25                                   ; 0a123309
	v_mac_f32_e32 v20, v9, v21                                  ; 2c282b09
	v_mad_f32 v2, -v4, v28, v20                                 ; d1c10002 24523904
BB17:
	s_mov_b64 exec, -1                                          ; befe01c1
	v_cmpx_ne_i32_e32 vcc, 0, v3                                ; 7daa0680
	s_cbranch_execz BB23                                        ; bf880091
BB18:
	s_mov_b32 s0, s2                                            ; be800002
	s_movk_i32 s1, 0x8000                                       ; b0018000
	s_load_dwordx8 s[24:31], s[0:1], 0x0                        ; c00e0600 00000000
	v_lshrrev_b32_e32 v3, 5, v1                                 ; 20060285
	v_lshlrev_b32_e32 v0, 2, v0                                 ; 24000082
	v_add_u32_e32 v3, s6, v3                                    ; 68060606
	v_and_b32_e32 v4, 3, v3                                     ; 26080683
	v_lshrrev_b32_e32 v3, 2, v3                                 ; 20060682
	v_lshlrev_b32_e32 v5, 4, v3                                 ; 240a0684
	v_lshl_add_u32 v3, v3, 7, v5                                ; d1fd0003 04150f03
	v_lshl_add_u32 v6, v4, 2, v3                                ; d1fd0006 040d0504
	v_lshl_add_u32 v4, v4, 3, v0                                ; d1fd0004 04010704
	v_lshlrev_b32_e32 v4, 2, v4                                 ; 24080882
	v_add3_u32 v4, v4, 16, v3                                   ; d1ff0004 040d2104
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_load_dword v6, v6, s[28:31], 0 offen                 ; e0501000 80070606
	buffer_load_dwordx4 v[8:11], v4, s[28:31], 0 offen          ; e05c1000 80070804
	s_mul_i32 s3, s16, s3                                       ; 92030310
	v_add_u32_e32 v1, s3, v1                                    ; 68020203
	v_lshrrev_b32_e32 v1, 5, v1                                 ; 20020285
	v_add_u32_e32 v1, s18, v1                                   ; 68020212
	v_and_b32_e32 v7, 7, v1                                     ; 260e0287
	v_lshrrev_b32_e32 v1, 3, v1                                 ; 20020283
	v_lshl_add_u32 v7, v7, 3, v0                                ; d1fd0007 04010707
	v_lshlrev_b32_e32 v14, 4, v1                                ; 241c0284
	v_and_b32_e32 v12, 7, v7                                    ; 26180e87
	v_lshrrev_b32_e32 v13, 4, v7                                ; 201a0e84
	v_lshl_add_u32 v1, v1, 7, v14                               ; d1fd0001 04390f01
	v_lshl_add_u32 v13, v13, 3, v12                             ; d1fd000d 0431070d
	v_lshlrev_b32_e32 v13, 2, v13                               ; 241a1a82
	v_add3_u32 v13, v13, 16, v1                                 ; d1ff000d 0405210d
	buffer_load_dwordx4 v[12:15], v13, s[24:27], 0 offen        ; e05c1000 80060c0d
	buffer_load_dwordx4 v[16:19], v1, s[24:27], 0 offen         ; e05c1000 80061001
	v_bfe_u32 v20, v7, 3, 1                                     ; d1c80014 02050707
	v_lshrrev_b32_e32 v7, 3, v7                                 ; 200e0e83
	s_mov_b32 s0, 0xf0f0f0f                                     ; be8000ff 0f0f0f0f
	v_lshlrev_b32_e32 v20, 2, v20                               ; 24282882
	v_and_b32_e32 v21, 3, v7                                    ; 262a0e83
	v_cmp_gt_u32_e32 vcc, 4, v7                                 ; 7d980e84
	v_lshlrev_b32_e32 v21, 3, v21                               ; 242a2a83
	v_add_u32_e32 v23, 4, v21                                   ; 682e2a84
	v_add_u32_e32 v22, 2, v21                                   ; 682c2a82
	v_cndmask_b32_e32 v23, v23, v21, vcc                        ; 002e2b17
	v_cndmask_b32_e32 v22, v22, v21, vcc                        ; 002c2b16
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_cvt_f32_f16_e32 v24, v6                                   ; 7e301706
	v_cvt_f32_f16_sdwa v6, v6 div:2 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e0c16f9 0005c606
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_lshrrev_b32_e32 v12, v20, v12                             ; 20181914
	v_lshrrev_b32_e32 v13, v20, v13                             ; 201a1b14
	v_lshrrev_b32_e32 v14, v20, v14                             ; 201c1d14
	v_lshrrev_b32_e32 v20, v20, v15                             ; 20281f14
	v_and_b32_e32 v12, s0, v12                                  ; 26181800
	v_and_b32_e32 v13, s0, v13                                  ; 261a1a00
	v_and_b32_e32 v14, s0, v14                                  ; 261c1c00
	v_mul_i32_i24_sdwa v28, sext(v12), sext(v8) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 src1_sel:BYTE_0 ; 0c3810f9 0808060c
	v_mul_i32_i24_sdwa v30, sext(v12), sext(v8) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 0c3c10f9 0a0a060c
	v_mul_i32_i24_sdwa v29, sext(v12), sext(v8) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 0c3a10f9 0909060c
	v_mul_i32_i24_sdwa v12, sext(v12), sext(v8) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 0c1810f9 0b0b060c
	v_mul_i32_i24_sdwa v26, sext(v13), sext(v9) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 0c3412f9 0909060d
	v_mul_i32_i24_sdwa v27, sext(v13), sext(v9) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 0c3612f9 0a0a060d
	v_mul_i32_i24_sdwa v25, sext(v13), sext(v9) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 src1_sel:BYTE_0 ; 0c3212f9 0808060d
	v_mul_i32_i24_sdwa v13, sext(v13), sext(v9) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 0c1a12f9 0b0b060d
	v_mul_i32_i24_sdwa v31, sext(v14), sext(v10) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 src1_sel:BYTE_0 ; 0c3e14f9 0808060e
	v_mul_i32_i24_sdwa v33, sext(v14), sext(v10) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 0c4214f9 0a0a060e
	v_mul_i32_i24_sdwa v32, sext(v14), sext(v10) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 0c4014f9 0909060e
	v_mul_i32_i24_sdwa v14, sext(v14), sext(v10) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 0c1c14f9 0b0b060e
	v_and_b32_e32 v20, s0, v20                                  ; 26282800
	v_add3_u32 v28, v28, v29, v30                               ; d1ff001c 047a3b1c
	v_add3_u32 v25, v25, v26, v27                               ; d1ff0019 046e3519
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_cndmask_b32_e32 v3, v19, v18, vcc                         ; 00062513
	v_add3_u32 v31, v31, v32, v33                               ; d1ff001f 0486411f
	v_cndmask_b32_e32 v19, v19, v17, vcc                        ; 00262313
	v_mul_i32_i24_sdwa v0, sext(v20), sext(v11) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 0c0016f9 09090614
	v_mul_i32_i24_sdwa v1, sext(v20), sext(v11) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 0c0216f9 0a0a0614
	v_mul_i32_i24_sdwa v34, sext(v20), sext(v11) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 src1_sel:BYTE_0 ; 0c4416f9 08080614
	v_mul_i32_i24_sdwa v20, sext(v20), sext(v11) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 0c2816f9 0b0b0614
	v_lshrrev_b32_e32 v17, v22, v17                             ; 20222316
	v_add3_u32 v25, v25, v13, 0                                 ; d1ff0019 02021b19
	v_lshrrev_b32_e32 v22, v22, v18                             ; 202c2516
	v_bfe_u32 v3, v3, v23, 4                                    ; d1c80003 02122f03
	v_bfe_u32 v19, v19, v21, 4                                  ; d1c80013 02122b13
	v_cvt_f32_f16_e32 v4, v16                                   ; 7e081710
	v_add3_u32 v34, v34, v0, v1                                 ; d1ff0022 04060122
	v_cvt_f32_f16_sdwa v16, v16 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e2016f9 00050610
	v_add3_u32 v28, v28, v12, v25                               ; d1ff001c 0466191c
	v_and_or_b32 v22, 48, v22, v3                               ; d2010016 040e2cb0
	v_and_or_b32 v17, 48, v17, v19                              ; d2010011 044e22b0
	v_add3_u32 v31, v31, v14, v28                               ; d1ff001f 04721d1f
	v_cvt_f32_ubyte0_e32 v22, v22                               ; 7e2c2316
	v_cvt_f32_ubyte0_e32 v17, v17                               ; 7e222311
	v_add3_u32 v34, v34, v20, v31                               ; d1ff0022 047e2922
	v_mul_f32_e32 v16, v16, v22                                 ; 0a202d10
	v_mul_f32_e32 v4, v4, v17                                   ; 0a082304
	v_cvt_f32_i32_e32 v34, v34                                  ; 7e440b22
	v_mul_f32_e32 v24, v24, v4                                  ; 0a300918
	v_mac_f32_e32 v2, v24, v34                                  ; 2c044518
	v_mad_f32 v2, -v16, v6, v2                                  ; d1c10002 240a0d10
BB23:
	s_mov_b64 exec, -1                                          ; befe01c1
	s_or_saveexec_b64 s[4:5], -1                                ; be8421c1
	v_cndmask_b32_e64 v35, 0, v2, s[4:5]                        ; d1000023 00120480
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v35, v35, v35 quad_perm:[1,0,3,2] row_mask:0xf bank_mask:0xf ; 024646fa ff00b123
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v35, v35, v35 quad_perm:[2,3,0,1] row_mask:0xf bank_mask:0xf ; 024646fa ff004e23
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v35, v35, v35 row_half_mirror row_mask:0xf bank_mask:0xf ; 024646fa ff014123
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v35, v35, v35 row_mirror row_mask:0xf bank_mask:0xf ; 024646fa ff014023
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v35, v35, v35 row_bcast:15 row_mask:0xa bank_mask:0xf ; 024646fa af014223
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v35, v35, v35 row_bcast:31 row_mask:0xc bank_mask:0xf ; 024646fa cf014323
	s_mov_b64 exec, 1                                           ; befe0181
	v_readlane_b32 s0, v35, 63                                  ; d2890000 00017f23
BB24:
	s_bitcmp1_b32 s8, 0                                         ; bf0d8008
	s_cbranch_scc0 BB26                                         ; bf84000e
BB25:
	s_mov_b32 s4, s2                                            ; be840002
	s_movk_i32 s5, 0x8000                                       ; b0058000
	s_load_dwordx4 s[12:15], s[4:5], 0x30                       ; c00a0302 00000030
	s_mul_i32 s1, s7, s17                                       ; 92011107
	s_add_u32 s1, s1, s16                                       ; 80011001
	s_lshl_b32 s1, s1, 2                                        ; 8e018201
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s1, s[12:15], s1                        ; c0200046 00000001
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_mov_b32_e32 v0, s1                                        ; 7e000201
	v_add_f32_e32 v0, s0, v0                                    ; 02000000
	s_branch BB27                                               ; bf820001
BB26:
	v_mov_b32_e32 v0, s0                                        ; 7e000200
BB27:
	s_bitcmp1_b32 s8, 1                                         ; bf0d8108
	s_cbranch_scc0 BB30                                         ; bf84000c
BB28:
	s_mov_b32 s0, s2                                            ; be800002
	s_movk_i32 s1, 0x8000                                       ; b0018000
	s_load_dwordx4 s[8:11], s[0:1], 0x40                        ; c00a0200 00000040
	s_mul_i32 s0, s7, s17                                       ; 92001107
	s_add_u32 s0, s0, s16                                       ; 80001000
	s_lshl_b32 s0, s0, 2                                        ; 8e008200
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s0, s[8:11], s0                         ; c0200004 00000000
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v0, s0, v0                                    ; 02000000
BB30:
	s_movk_i32 s3, 0x8000                                       ; b0038000
	s_load_dwordx4 s[0:3], s[2:3], 0x20                         ; c00a0001 00000020
	s_mul_i32 s7, s7, s17                                       ; 92071107
	s_add_u32 s7, s7, s16                                       ; 80071007
	s_lshl_b32 s7, s7, 2                                        ; 8e078207
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_store_dword v0, off, s[0:3], s7                      ; e0700000 07000080
	s_branch BB98                                               ; bf8204b8
BB36:
	s_cmp_lt_u32 s16, s4                                        ; bf0a0410
	s_cbranch_scc0 BB98                                         ; bf8404b6
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
	s_mul_i32 s6, s17, s6                                       ; 92060611
	v_lshlrev_b32_e32 v1, 4, v0                                 ; 24020084
	s_and_b32 s0, s3, 0xfffffc00                                ; 8600ff03 fffffc00
	s_lshr_b32 s1, s3, 10                                       ; 8f018a03
	v_and_b32_e32 v0, 1, v0                                     ; 26000081
	s_mul_i32 s19, s19, s5                                      ; 92130513
	v_add_u32_e32 v2, s0, v1                                    ; 68040200
	s_lshl_b32 s19, s19, 3                                      ; 8e138313
	s_lshr_b32 s6, s6, 5                                        ; 8f068506
	s_cmp_lg_i32 s4, 0                                          ; bf018004
	v_cmp_gt_u32_e32 vcc, s3, v2                                ; 7d980403
	v_mov_b32_e32 v2, 0                                         ; 7e040280
	v_cndmask_b32_e64 v3, 0, 1, vcc                             ; d1000003 01a90280
	v_add_u32_e32 v3, s1, v3                                    ; 68060601
	s_cselect_b64 s[0:1], -1, 0                                 ; 858080c1
BB41:
	s_mov_b64 s[10:11], exec                                    ; be8a017e
	v_cmpx_gt_u32_e32 vcc, 4, v3                                ; 7db80684
	s_mov_b32 s5, src_scc                                       ; be8500fd
BB42:
	s_andn2_b64 s[10:11], s[10:11], exec                        ; 898a7e0a
	s_cbranch_scc0 BB59                                         ; bf84024b
BB46:
	s_mov_b64 exec, s[10:11]                                    ; befe010a
	s_mov_b32 s10, s2                                           ; be8a0002
	s_movk_i32 s11, 0x8000                                      ; b00b8000
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_load_dwordx4 s[12:15], s[10:11], 0x10                     ; c00a0305 00000010
	s_mul_i32 s4, s16, s3                                       ; 92040310
	s_cmp_lg_i32 s5, 0                                          ; bf018005
	v_lshrrev_b32_e32 v4, 5, v1                                 ; 20080285
	v_lshlrev_b32_e32 v8, 2, v0                                 ; 24100082
	v_add_u32_e32 v4, s6, v4                                    ; 68080806
	v_and_b32_e32 v5, 3, v4                                     ; 260a0883
	v_lshrrev_b32_e32 v4, 2, v4                                 ; 20080882
	v_lshlrev_b32_e32 v6, 4, v4                                 ; 240c0884
	v_lshl_add_u32 v4, v4, 7, v6                                ; d1fd0004 04190f04
	v_lshl_add_u32 v7, v5, 2, v4                                ; d1fd0007 04110505
	v_lshl_add_u32 v5, v5, 3, v8                                ; d1fd0005 04210705
	v_lshlrev_b32_e32 v5, 2, v5                                 ; 240a0a82
	v_add3_u32 v5, v5, 16, v4                                   ; d1ff0005 04112105
	s_cbranch_scc0 BB49                                         ; bf84007f
BB47:
	s_load_dwordx4 s[20:23], s[10:11], 0x0                      ; c00a0505 00000000
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_load_dword v7, v7, s[12:15], 0 offen                 ; e0501000 80030707
	buffer_load_dwordx4 v[12:15], v5, s[12:15], 0 offen         ; e05c1000 80030c05
	v_add_u32_e32 v4, s4, v1                                    ; 68080204
	v_lshrrev_b32_e32 v4, 5, v4                                 ; 20080885
	v_add_u32_e32 v4, s19, v4                                   ; 68080813
	v_and_b32_e32 v5, 7, v4                                     ; 260a0887
	v_lshrrev_b32_e32 v4, 3, v4                                 ; 20080883
	v_lshl_add_u32 v5, v5, 3, v8                                ; d1fd0005 04210705
	v_lshlrev_b32_e32 v10, 4, v4                                ; 24140884
	v_and_b32_e32 v6, 7, v5                                     ; 260c0a87
	v_lshrrev_b32_e32 v9, 4, v5                                 ; 20120a84
	v_lshl_add_u32 v4, v4, 7, v10                               ; d1fd0004 04290f04
	v_lshl_add_u32 v9, v9, 3, v6                                ; d1fd0009 04190709
	v_lshlrev_b32_e32 v9, 2, v9                                 ; 24121282
	v_add3_u32 v9, v9, 16, v4                                   ; d1ff0009 04112109
	buffer_load_dwordx4 v[16:19], v9, s[20:23], 0 offen         ; e05c1000 80051009
	buffer_load_dwordx4 v[20:23], v4, s[20:23], 0 offen         ; e05c1000 80051404
	v_bfe_u32 v11, v5, 3, 1                                     ; d1c8000b 02050705
	v_lshrrev_b32_e32 v5, 3, v5                                 ; 200a0a83
	s_mov_b32 s5, 0xf0f0f0f                                     ; be8500ff 0f0f0f0f
	v_lshlrev_b32_e32 v11, 2, v11                               ; 24161682
	v_and_b32_e32 v24, 3, v5                                    ; 26300a83
	v_cmp_gt_u32_e32 vcc, 4, v5                                 ; 7d980a84
	v_lshlrev_b32_e32 v24, 3, v24                               ; 24303083
	v_add_u32_e32 v26, 4, v24                                   ; 68343084
	v_add_u32_e32 v25, 2, v24                                   ; 68323082
	v_cndmask_b32_e32 v26, v26, v24, vcc                        ; 0034311a
	v_cndmask_b32_e32 v25, v25, v24, vcc                        ; 00323119
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_cvt_f32_f16_e32 v27, v7                                   ; 7e361707
	v_cvt_f32_f16_sdwa v7, v7 div:2 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e0e16f9 0005c607
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_lshrrev_b32_e32 v17, v11, v17                             ; 2022230b
	v_lshrrev_b32_e32 v18, v11, v18                             ; 2024250b
	v_lshrrev_b32_e32 v16, v11, v16                             ; 2020210b
	v_lshrrev_b32_e32 v11, v11, v19                             ; 2016270b
	v_and_b32_e32 v17, s5, v17                                  ; 26222205
	v_and_b32_e32 v18, s5, v18                                  ; 26242405
	v_and_b32_e32 v16, s5, v16                                  ; 26202005
	v_mul_i32_i24_sdwa v29, sext(v17), sext(v13) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 0c3a1af9 09090611
	v_mul_i32_i24_sdwa v30, sext(v17), sext(v13) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 0c3c1af9 0a0a0611
	v_mul_i32_i24_sdwa v28, sext(v17), sext(v13) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 src1_sel:BYTE_0 ; 0c381af9 08080611
	v_mul_i32_i24_sdwa v17, sext(v17), sext(v13) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 0c221af9 0b0b0611
	v_mul_i32_i24_sdwa v34, sext(v18), sext(v14) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 src1_sel:BYTE_0 ; 0c441cf9 08080612
	v_mul_i32_i24_sdwa v4, sext(v18), sext(v14) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 0c081cf9 09090612
	v_mul_i32_i24_sdwa v5, sext(v18), sext(v14) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 0c0a1cf9 0a0a0612
	v_mul_i32_i24_sdwa v18, sext(v18), sext(v14) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 0c241cf9 0b0b0612
	v_mul_i32_i24_sdwa v31, sext(v16), sext(v12) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 src1_sel:BYTE_0 ; 0c3e18f9 08080610
	v_mul_i32_i24_sdwa v33, sext(v16), sext(v12) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 0c4218f9 0a0a0610
	v_mul_i32_i24_sdwa v32, sext(v16), sext(v12) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 0c4018f9 09090610
	v_mul_i32_i24_sdwa v16, sext(v16), sext(v12) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 0c2018f9 0b0b0610
	v_and_b32_e32 v11, s5, v11                                  ; 26161605
	v_add3_u32 v28, v28, v29, v30                               ; d1ff001c 047a3b1c
	v_add3_u32 v34, v34, v4, v5                                 ; d1ff0022 04160922
	v_add3_u32 v31, v31, v32, v33                               ; d1ff001f 0486411f
	v_mul_i32_i24_sdwa v9, sext(v11), sext(v15) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 0c121ef9 0909060b
	v_mul_i32_i24_sdwa v10, sext(v11), sext(v15) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 0c141ef9 0a0a060b
	v_mul_i32_i24_sdwa v6, sext(v11), sext(v15) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 src1_sel:BYTE_0 ; 0c0c1ef9 0808060b
	v_mul_i32_i24_sdwa v11, sext(v11), sext(v15) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 0c161ef9 0b0b060b
	v_add3_u32 v28, v28, v17, 0                                 ; d1ff001c 0202231c
	v_add3_u32 v6, v6, v9, v10                                  ; d1ff0006 042a1306
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_cvt_f32_f16_e32 v12, v20                                  ; 7e181714
	v_add3_u32 v31, v31, v16, v28                               ; d1ff001f 0472211f
	v_cvt_f32_f16_sdwa v20, v20 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e2816f9 00050614
	v_add3_u32 v34, v34, v18, v31                               ; d1ff0022 047e2522
	v_add3_u32 v6, v6, v11, v34                                 ; d1ff0006 048a1706
	v_cndmask_b32_e32 v11, v23, v22, vcc                        ; 00162d17
	v_cndmask_b32_e32 v23, v23, v21, vcc                        ; 002e2b17
	v_lshrrev_b32_e32 v21, v25, v21                             ; 202a2b19
	v_lshrrev_b32_e32 v25, v25, v22                             ; 20322d19
	v_cvt_f32_i32_e32 v6, v6                                    ; 7e0c0b06
	v_bfe_u32 v11, v11, v26, 4                                  ; d1c8000b 0212350b
	v_bfe_u32 v23, v23, v24, 4                                  ; d1c80017 02123117
	v_and_or_b32 v25, 48, v25, v11                              ; d2010019 042e32b0
	v_and_or_b32 v21, 48, v21, v23                              ; d2010015 045e2ab0
	v_cvt_f32_ubyte0_e32 v25, v25                               ; 7e322319
	v_cvt_f32_ubyte0_e32 v21, v21                               ; 7e2a2315
	v_mul_f32_e32 v20, v20, v25                                 ; 0a283314
	v_mul_f32_e32 v12, v12, v21                                 ; 0a182b0c
	v_mul_f32_e32 v27, v27, v12                                 ; 0a36191b
	v_mac_f32_e32 v2, v27, v6                                   ; 2c040d1b
	v_mad_f32 v2, -v20, v7, v2                                  ; d1c10002 240a0f14
BB49:
	v_add_u32_e32 v4, 0x400, v1                                 ; 680802ff 00000400
	v_lshrrev_b32_e32 v5, 5, v4                                 ; 200a0885
	v_add_u32_e32 v5, s6, v5                                    ; 680a0a06
	v_and_b32_e32 v6, 3, v5                                     ; 260c0a83
	v_lshrrev_b32_e32 v5, 2, v5                                 ; 200a0a82
	v_lshlrev_b32_e32 v7, 4, v5                                 ; 240e0a84
	v_lshl_add_u32 v5, v5, 7, v7                                ; d1fd0005 041d0f05
	v_lshl_add_u32 v9, v6, 2, v5                                ; d1fd0009 04150506
	v_lshl_add_u32 v6, v6, 3, v8                                ; d1fd0006 04210706
	v_lshlrev_b32_e32 v6, 2, v6                                 ; 240c0c82
	v_add3_u32 v6, v6, 16, v5                                   ; d1ff0006 04152106
	s_cbranch_scc0 BB52                                         ; bf84007f
BB50:
	s_load_dwordx4 s[20:23], s[10:11], 0x0                      ; c00a0505 00000000
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_load_dword v9, v9, s[12:15], 0 offen                 ; e0501000 80030909
	buffer_load_dwordx4 v[12:15], v6, s[12:15], 0 offen         ; e05c1000 80030c06
	v_add_u32_e32 v4, s4, v4                                    ; 68080804
	v_lshrrev_b32_e32 v4, 5, v4                                 ; 20080885
	v_add_u32_e32 v4, s19, v4                                   ; 68080813
	v_and_b32_e32 v5, 7, v4                                     ; 260a0887
	v_lshrrev_b32_e32 v4, 3, v4                                 ; 20080883
	v_lshl_add_u32 v5, v5, 3, v8                                ; d1fd0005 04210705
	v_lshlrev_b32_e32 v10, 4, v4                                ; 24140884
	v_and_b32_e32 v6, 7, v5                                     ; 260c0a87
	v_lshrrev_b32_e32 v7, 4, v5                                 ; 200e0a84
	v_lshl_add_u32 v4, v4, 7, v10                               ; d1fd0004 04290f04
	v_lshl_add_u32 v7, v7, 3, v6                                ; d1fd0007 04190707
	v_lshlrev_b32_e32 v7, 2, v7                                 ; 240e0e82
	v_add3_u32 v7, v7, 16, v4                                   ; d1ff0007 04112107
	buffer_load_dwordx4 v[16:19], v7, s[20:23], 0 offen         ; e05c1000 80051007
	buffer_load_dwordx4 v[20:23], v4, s[20:23], 0 offen         ; e05c1000 80051404
	v_bfe_u32 v11, v5, 3, 1                                     ; d1c8000b 02050705
	v_lshrrev_b32_e32 v5, 3, v5                                 ; 200a0a83
	s_mov_b32 s5, 0xf0f0f0f                                     ; be8500ff 0f0f0f0f
	v_lshlrev_b32_e32 v11, 2, v11                               ; 24161682
	v_and_b32_e32 v24, 3, v5                                    ; 26300a83
	v_cmp_gt_u32_e32 vcc, 4, v5                                 ; 7d980a84
	v_lshlrev_b32_e32 v24, 3, v24                               ; 24303083
	v_add_u32_e32 v26, 4, v24                                   ; 68343084
	v_add_u32_e32 v25, 2, v24                                   ; 68323082
	v_cndmask_b32_e32 v26, v26, v24, vcc                        ; 0034311a
	v_cndmask_b32_e32 v25, v25, v24, vcc                        ; 00323119
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_cvt_f32_f16_e32 v27, v9                                   ; 7e361709
	v_cvt_f32_f16_sdwa v9, v9 div:2 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e1216f9 0005c609
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_lshrrev_b32_e32 v17, v11, v17                             ; 2022230b
	v_lshrrev_b32_e32 v18, v11, v18                             ; 2024250b
	v_lshrrev_b32_e32 v16, v11, v16                             ; 2020210b
	v_lshrrev_b32_e32 v11, v11, v19                             ; 2016270b
	v_and_b32_e32 v17, s5, v17                                  ; 26222205
	v_and_b32_e32 v18, s5, v18                                  ; 26242405
	v_and_b32_e32 v16, s5, v16                                  ; 26202005
	v_mul_i32_i24_sdwa v29, sext(v17), sext(v13) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 0c3a1af9 09090611
	v_mul_i32_i24_sdwa v30, sext(v17), sext(v13) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 0c3c1af9 0a0a0611
	v_mul_i32_i24_sdwa v28, sext(v17), sext(v13) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 src1_sel:BYTE_0 ; 0c381af9 08080611
	v_mul_i32_i24_sdwa v17, sext(v17), sext(v13) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 0c221af9 0b0b0611
	v_mul_i32_i24_sdwa v34, sext(v18), sext(v14) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 src1_sel:BYTE_0 ; 0c441cf9 08080612
	v_mul_i32_i24_sdwa v4, sext(v18), sext(v14) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 0c081cf9 09090612
	v_mul_i32_i24_sdwa v5, sext(v18), sext(v14) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 0c0a1cf9 0a0a0612
	v_mul_i32_i24_sdwa v18, sext(v18), sext(v14) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 0c241cf9 0b0b0612
	v_mul_i32_i24_sdwa v31, sext(v16), sext(v12) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 src1_sel:BYTE_0 ; 0c3e18f9 08080610
	v_mul_i32_i24_sdwa v33, sext(v16), sext(v12) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 0c4218f9 0a0a0610
	v_mul_i32_i24_sdwa v32, sext(v16), sext(v12) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 0c4018f9 09090610
	v_mul_i32_i24_sdwa v16, sext(v16), sext(v12) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 0c2018f9 0b0b0610
	v_and_b32_e32 v11, s5, v11                                  ; 26161605
	v_add3_u32 v28, v28, v29, v30                               ; d1ff001c 047a3b1c
	v_add3_u32 v34, v34, v4, v5                                 ; d1ff0022 04160922
	v_add3_u32 v31, v31, v32, v33                               ; d1ff001f 0486411f
	v_mul_i32_i24_sdwa v7, sext(v11), sext(v15) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 0c0e1ef9 0909060b
	v_mul_i32_i24_sdwa v10, sext(v11), sext(v15) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 0c141ef9 0a0a060b
	v_mul_i32_i24_sdwa v6, sext(v11), sext(v15) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 src1_sel:BYTE_0 ; 0c0c1ef9 0808060b
	v_mul_i32_i24_sdwa v11, sext(v11), sext(v15) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 0c161ef9 0b0b060b
	v_add3_u32 v28, v28, v17, 0                                 ; d1ff001c 0202231c
	v_add3_u32 v6, v6, v7, v10                                  ; d1ff0006 042a0f06
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_cvt_f32_f16_e32 v12, v20                                  ; 7e181714
	v_add3_u32 v31, v31, v16, v28                               ; d1ff001f 0472211f
	v_cvt_f32_f16_sdwa v20, v20 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e2816f9 00050614
	v_add3_u32 v34, v34, v18, v31                               ; d1ff0022 047e2522
	v_add3_u32 v6, v6, v11, v34                                 ; d1ff0006 048a1706
	v_cndmask_b32_e32 v11, v23, v22, vcc                        ; 00162d17
	v_cndmask_b32_e32 v23, v23, v21, vcc                        ; 002e2b17
	v_lshrrev_b32_e32 v21, v25, v21                             ; 202a2b19
	v_lshrrev_b32_e32 v25, v25, v22                             ; 20322d19
	v_cvt_f32_i32_e32 v6, v6                                    ; 7e0c0b06
	v_bfe_u32 v11, v11, v26, 4                                  ; d1c8000b 0212350b
	v_bfe_u32 v23, v23, v24, 4                                  ; d1c80017 02123117
	v_and_or_b32 v25, 48, v25, v11                              ; d2010019 042e32b0
	v_and_or_b32 v21, 48, v21, v23                              ; d2010015 045e2ab0
	v_cvt_f32_ubyte0_e32 v25, v25                               ; 7e322319
	v_cvt_f32_ubyte0_e32 v21, v21                               ; 7e2a2315
	v_mul_f32_e32 v20, v20, v25                                 ; 0a283314
	v_mul_f32_e32 v12, v12, v21                                 ; 0a182b0c
	v_mul_f32_e32 v27, v27, v12                                 ; 0a36191b
	v_mac_f32_e32 v2, v27, v6                                   ; 2c040d1b
	v_mad_f32 v2, -v20, v9, v2                                  ; d1c10002 240a1314
BB52:
	v_add_u32_e32 v4, 0x800, v1                                 ; 680802ff 00000800
	v_lshrrev_b32_e32 v5, 5, v4                                 ; 200a0885
	v_add_u32_e32 v5, s6, v5                                    ; 680a0a06
	v_and_b32_e32 v6, 3, v5                                     ; 260c0a83
	v_lshrrev_b32_e32 v5, 2, v5                                 ; 200a0a82
	v_lshlrev_b32_e32 v7, 4, v5                                 ; 240e0a84
	v_lshl_add_u32 v5, v5, 7, v7                                ; d1fd0005 041d0f05
	v_lshl_add_u32 v9, v6, 2, v5                                ; d1fd0009 04150506
	v_lshl_add_u32 v6, v6, 3, v8                                ; d1fd0006 04210706
	v_lshlrev_b32_e32 v6, 2, v6                                 ; 240c0c82
	v_add3_u32 v6, v6, 16, v5                                   ; d1ff0006 04152106
	s_cbranch_scc0 BB55                                         ; bf84007f
BB53:
	s_load_dwordx4 s[20:23], s[10:11], 0x0                      ; c00a0505 00000000
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_load_dword v9, v9, s[12:15], 0 offen                 ; e0501000 80030909
	buffer_load_dwordx4 v[12:15], v6, s[12:15], 0 offen         ; e05c1000 80030c06
	v_add_u32_e32 v4, s4, v4                                    ; 68080804
	v_lshrrev_b32_e32 v4, 5, v4                                 ; 20080885
	v_add_u32_e32 v4, s19, v4                                   ; 68080813
	v_and_b32_e32 v5, 7, v4                                     ; 260a0887
	v_lshrrev_b32_e32 v4, 3, v4                                 ; 20080883
	v_lshl_add_u32 v5, v5, 3, v8                                ; d1fd0005 04210705
	v_lshlrev_b32_e32 v10, 4, v4                                ; 24140884
	v_and_b32_e32 v6, 7, v5                                     ; 260c0a87
	v_lshrrev_b32_e32 v7, 4, v5                                 ; 200e0a84
	v_lshl_add_u32 v4, v4, 7, v10                               ; d1fd0004 04290f04
	v_lshl_add_u32 v7, v7, 3, v6                                ; d1fd0007 04190707
	v_lshlrev_b32_e32 v7, 2, v7                                 ; 240e0e82
	v_add3_u32 v7, v7, 16, v4                                   ; d1ff0007 04112107
	buffer_load_dwordx4 v[16:19], v7, s[20:23], 0 offen         ; e05c1000 80051007
	buffer_load_dwordx4 v[20:23], v4, s[20:23], 0 offen         ; e05c1000 80051404
	v_bfe_u32 v11, v5, 3, 1                                     ; d1c8000b 02050705
	v_lshrrev_b32_e32 v5, 3, v5                                 ; 200a0a83
	s_mov_b32 s5, 0xf0f0f0f                                     ; be8500ff 0f0f0f0f
	v_lshlrev_b32_e32 v11, 2, v11                               ; 24161682
	v_and_b32_e32 v24, 3, v5                                    ; 26300a83
	v_cmp_gt_u32_e32 vcc, 4, v5                                 ; 7d980a84
	v_lshlrev_b32_e32 v24, 3, v24                               ; 24303083
	v_add_u32_e32 v26, 4, v24                                   ; 68343084
	v_add_u32_e32 v25, 2, v24                                   ; 68323082
	v_cndmask_b32_e32 v26, v26, v24, vcc                        ; 0034311a
	v_cndmask_b32_e32 v25, v25, v24, vcc                        ; 00323119
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_cvt_f32_f16_e32 v27, v9                                   ; 7e361709
	v_cvt_f32_f16_sdwa v9, v9 div:2 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e1216f9 0005c609
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_lshrrev_b32_e32 v17, v11, v17                             ; 2022230b
	v_lshrrev_b32_e32 v18, v11, v18                             ; 2024250b
	v_lshrrev_b32_e32 v16, v11, v16                             ; 2020210b
	v_lshrrev_b32_e32 v11, v11, v19                             ; 2016270b
	v_and_b32_e32 v17, s5, v17                                  ; 26222205
	v_and_b32_e32 v18, s5, v18                                  ; 26242405
	v_and_b32_e32 v16, s5, v16                                  ; 26202005
	v_mul_i32_i24_sdwa v29, sext(v17), sext(v13) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 0c3a1af9 09090611
	v_mul_i32_i24_sdwa v30, sext(v17), sext(v13) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 0c3c1af9 0a0a0611
	v_mul_i32_i24_sdwa v28, sext(v17), sext(v13) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 src1_sel:BYTE_0 ; 0c381af9 08080611
	v_mul_i32_i24_sdwa v17, sext(v17), sext(v13) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 0c221af9 0b0b0611
	v_mul_i32_i24_sdwa v34, sext(v18), sext(v14) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 src1_sel:BYTE_0 ; 0c441cf9 08080612
	v_mul_i32_i24_sdwa v4, sext(v18), sext(v14) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 0c081cf9 09090612
	v_mul_i32_i24_sdwa v5, sext(v18), sext(v14) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 0c0a1cf9 0a0a0612
	v_mul_i32_i24_sdwa v18, sext(v18), sext(v14) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 0c241cf9 0b0b0612
	v_mul_i32_i24_sdwa v31, sext(v16), sext(v12) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 src1_sel:BYTE_0 ; 0c3e18f9 08080610
	v_mul_i32_i24_sdwa v33, sext(v16), sext(v12) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 0c4218f9 0a0a0610
	v_mul_i32_i24_sdwa v32, sext(v16), sext(v12) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 0c4018f9 09090610
	v_mul_i32_i24_sdwa v16, sext(v16), sext(v12) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 0c2018f9 0b0b0610
	v_and_b32_e32 v11, s5, v11                                  ; 26161605
	v_add3_u32 v28, v28, v29, v30                               ; d1ff001c 047a3b1c
	v_add3_u32 v34, v34, v4, v5                                 ; d1ff0022 04160922
	v_add3_u32 v31, v31, v32, v33                               ; d1ff001f 0486411f
	v_mul_i32_i24_sdwa v7, sext(v11), sext(v15) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 0c0e1ef9 0909060b
	v_mul_i32_i24_sdwa v10, sext(v11), sext(v15) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 0c141ef9 0a0a060b
	v_mul_i32_i24_sdwa v6, sext(v11), sext(v15) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 src1_sel:BYTE_0 ; 0c0c1ef9 0808060b
	v_mul_i32_i24_sdwa v11, sext(v11), sext(v15) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 0c161ef9 0b0b060b
	v_add3_u32 v28, v28, v17, 0                                 ; d1ff001c 0202231c
	v_add3_u32 v6, v6, v7, v10                                  ; d1ff0006 042a0f06
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_cvt_f32_f16_e32 v12, v20                                  ; 7e181714
	v_add3_u32 v31, v31, v16, v28                               ; d1ff001f 0472211f
	v_cvt_f32_f16_sdwa v20, v20 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e2816f9 00050614
	v_add3_u32 v34, v34, v18, v31                               ; d1ff0022 047e2522
	v_add3_u32 v6, v6, v11, v34                                 ; d1ff0006 048a1706
	v_cndmask_b32_e32 v11, v23, v22, vcc                        ; 00162d17
	v_cndmask_b32_e32 v23, v23, v21, vcc                        ; 002e2b17
	v_lshrrev_b32_e32 v21, v25, v21                             ; 202a2b19
	v_lshrrev_b32_e32 v25, v25, v22                             ; 20322d19
	v_cvt_f32_i32_e32 v6, v6                                    ; 7e0c0b06
	v_bfe_u32 v11, v11, v26, 4                                  ; d1c8000b 0212350b
	v_bfe_u32 v23, v23, v24, 4                                  ; d1c80017 02123117
	v_and_or_b32 v25, 48, v25, v11                              ; d2010019 042e32b0
	v_and_or_b32 v21, 48, v21, v23                              ; d2010015 045e2ab0
	v_cvt_f32_ubyte0_e32 v25, v25                               ; 7e322319
	v_cvt_f32_ubyte0_e32 v21, v21                               ; 7e2a2315
	v_mul_f32_e32 v20, v20, v25                                 ; 0a283314
	v_mul_f32_e32 v12, v12, v21                                 ; 0a182b0c
	v_mul_f32_e32 v27, v27, v12                                 ; 0a36191b
	v_mac_f32_e32 v2, v27, v6                                   ; 2c040d1b
	v_mad_f32 v2, -v20, v9, v2                                  ; d1c10002 240a1314
BB55:
	v_add_u32_e32 v4, 0xc00, v1                                 ; 680802ff 00000c00
	v_lshrrev_b32_e32 v5, 5, v4                                 ; 200a0885
	v_add_u32_e32 v5, s6, v5                                    ; 680a0a06
	v_and_b32_e32 v6, 3, v5                                     ; 260c0a83
	v_lshrrev_b32_e32 v5, 2, v5                                 ; 200a0a82
	v_lshlrev_b32_e32 v7, 4, v5                                 ; 240e0a84
	v_lshl_add_u32 v5, v5, 7, v7                                ; d1fd0005 041d0f05
	v_lshl_add_u32 v9, v6, 2, v5                                ; d1fd0009 04150506
	v_lshl_add_u32 v6, v6, 3, v8                                ; d1fd0006 04210706
	v_lshlrev_b32_e32 v6, 2, v6                                 ; 240c0c82
	v_add3_u32 v6, v6, 16, v5                                   ; d1ff0006 04152106
	s_cbranch_scc0 BB58                                         ; bf84007f
BB56:
	s_load_dwordx4 s[20:23], s[10:11], 0x0                      ; c00a0505 00000000
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_load_dword v9, v9, s[12:15], 0 offen                 ; e0501000 80030909
	buffer_load_dwordx4 v[12:15], v6, s[12:15], 0 offen         ; e05c1000 80030c06
	v_add_u32_e32 v4, s4, v4                                    ; 68080804
	v_lshrrev_b32_e32 v4, 5, v4                                 ; 20080885
	v_add_u32_e32 v4, s19, v4                                   ; 68080813
	v_and_b32_e32 v5, 7, v4                                     ; 260a0887
	v_lshrrev_b32_e32 v4, 3, v4                                 ; 20080883
	v_lshl_add_u32 v5, v5, 3, v8                                ; d1fd0005 04210705
	v_lshlrev_b32_e32 v8, 4, v4                                 ; 24100884
	v_and_b32_e32 v6, 7, v5                                     ; 260c0a87
	v_lshrrev_b32_e32 v7, 4, v5                                 ; 200e0a84
	v_lshl_add_u32 v4, v4, 7, v8                                ; d1fd0004 04210f04
	v_lshl_add_u32 v7, v7, 3, v6                                ; d1fd0007 04190707
	v_lshlrev_b32_e32 v7, 2, v7                                 ; 240e0e82
	v_add3_u32 v7, v7, 16, v4                                   ; d1ff0007 04112107
	buffer_load_dwordx4 v[16:19], v7, s[20:23], 0 offen         ; e05c1000 80051007
	buffer_load_dwordx4 v[20:23], v4, s[20:23], 0 offen         ; e05c1000 80051404
	v_bfe_u32 v10, v5, 3, 1                                     ; d1c8000a 02050705
	v_lshrrev_b32_e32 v5, 3, v5                                 ; 200a0a83
	s_mov_b32 s4, 0xf0f0f0f                                     ; be8400ff 0f0f0f0f
	v_lshlrev_b32_e32 v10, 2, v10                               ; 24141482
	v_and_b32_e32 v11, 3, v5                                    ; 26160a83
	v_cmp_gt_u32_e32 vcc, 4, v5                                 ; 7d980a84
	v_lshlrev_b32_e32 v11, 3, v11                               ; 24161683
	v_add_u32_e32 v25, 4, v11                                   ; 68321684
	v_add_u32_e32 v24, 2, v11                                   ; 68301682
	v_cndmask_b32_e32 v25, v25, v11, vcc                        ; 00321719
	v_cndmask_b32_e32 v24, v24, v11, vcc                        ; 00301718
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_cvt_f32_f16_e32 v26, v9                                   ; 7e341709
	v_cvt_f32_f16_sdwa v9, v9 div:2 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e1216f9 0005c609
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_lshrrev_b32_e32 v17, v10, v17                             ; 2022230a
	v_lshrrev_b32_e32 v18, v10, v18                             ; 2024250a
	v_lshrrev_b32_e32 v16, v10, v16                             ; 2020210a
	v_lshrrev_b32_e32 v10, v10, v19                             ; 2014270a
	v_and_b32_e32 v17, s4, v17                                  ; 26222204
	v_and_b32_e32 v18, s4, v18                                  ; 26242404
	v_and_b32_e32 v16, s4, v16                                  ; 26202004
	v_mul_i32_i24_sdwa v28, sext(v17), sext(v13) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 0c381af9 09090611
	v_mul_i32_i24_sdwa v29, sext(v17), sext(v13) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 0c3a1af9 0a0a0611
	v_mul_i32_i24_sdwa v27, sext(v17), sext(v13) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 src1_sel:BYTE_0 ; 0c361af9 08080611
	v_mul_i32_i24_sdwa v17, sext(v17), sext(v13) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 0c221af9 0b0b0611
	v_mul_i32_i24_sdwa v33, sext(v18), sext(v14) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 src1_sel:BYTE_0 ; 0c421cf9 08080612
	v_mul_i32_i24_sdwa v34, sext(v18), sext(v14) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 0c441cf9 09090612
	v_mul_i32_i24_sdwa v4, sext(v18), sext(v14) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 0c081cf9 0a0a0612
	v_mul_i32_i24_sdwa v18, sext(v18), sext(v14) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 0c241cf9 0b0b0612
	v_mul_i32_i24_sdwa v30, sext(v16), sext(v12) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 src1_sel:BYTE_0 ; 0c3c18f9 08080610
	v_mul_i32_i24_sdwa v32, sext(v16), sext(v12) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 0c4018f9 0a0a0610
	v_mul_i32_i24_sdwa v31, sext(v16), sext(v12) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 0c3e18f9 09090610
	v_mul_i32_i24_sdwa v16, sext(v16), sext(v12) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 0c2018f9 0b0b0610
	v_and_b32_e32 v10, s4, v10                                  ; 26141404
	v_add3_u32 v27, v27, v28, v29                               ; d1ff001b 0476391b
	v_add3_u32 v33, v33, v34, v4                                ; d1ff0021 04124521
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_cndmask_b32_e32 v8, v23, v22, vcc                         ; 00102d17
	v_add3_u32 v30, v30, v31, v32                               ; d1ff001e 04823f1e
	v_cndmask_b32_e32 v23, v23, v21, vcc                        ; 002e2b17
	v_mul_i32_i24_sdwa v6, sext(v10), sext(v15) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 0c0c1ef9 0909060a
	v_mul_i32_i24_sdwa v7, sext(v10), sext(v15) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 0c0e1ef9 0a0a060a
	v_lshrrev_b32_e32 v21, v24, v21                             ; 202a2b18
	v_mul_i32_i24_sdwa v5, sext(v10), sext(v15) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 src1_sel:BYTE_0 ; 0c0a1ef9 0808060a
	v_mul_i32_i24_sdwa v10, sext(v10), sext(v15) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 0c141ef9 0b0b060a
	v_add3_u32 v27, v27, v17, 0                                 ; d1ff001b 0202231b
	v_lshrrev_b32_e32 v24, v24, v22                             ; 20302d18
	v_bfe_u32 v8, v8, v25, 4                                    ; d1c80008 02123308
	v_bfe_u32 v23, v23, v11, 4                                  ; d1c80017 02121717
	v_add3_u32 v5, v5, v6, v7                                   ; d1ff0005 041e0d05
	v_add3_u32 v30, v30, v16, v27                               ; d1ff001e 046e211e
	v_and_or_b32 v24, 48, v24, v8                               ; d2010018 042230b0
	v_and_or_b32 v21, 48, v21, v23                              ; d2010015 045e2ab0
	v_add3_u32 v33, v33, v18, v30                               ; d1ff0021 047a2521
	v_cvt_f32_ubyte0_e32 v24, v24                               ; 7e302318
	v_cvt_f32_ubyte0_e32 v21, v21                               ; 7e2a2315
	v_add3_u32 v5, v5, v10, v33                                 ; d1ff0005 04861505
	v_cvt_f32_f16_e32 v10, v20                                  ; 7e141714
	v_cvt_f32_f16_sdwa v20, v20 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e2816f9 00050614
	v_cvt_f32_i32_e32 v5, v5                                    ; 7e0a0b05
	v_mul_f32_e32 v10, v10, v21                                 ; 0a142b0a
	v_mul_f32_e32 v20, v20, v24                                 ; 0a283114
	v_mul_f32_e32 v26, v26, v10                                 ; 0a34151a
	v_mac_f32_e32 v2, v26, v5                                   ; 2c040b1a
	v_mad_f32 v2, -v20, v9, v2                                  ; d1c10002 240a1314
BB58:
	v_add_u32_e32 v3, -4, v3                                    ; 680606c4
	v_add_u32_e32 v1, 0x1000, v1                                ; 680202ff 00001000
	s_branch BB41                                               ; bf82fdb0
BB59:
	s_mov_b64 exec, -1                                          ; befe01c1
	v_cmpx_le_u32_e32 vcc, 2, v3                                ; 7db60682
	s_cbranch_execz BB71                                        ; bf88012a
BB60:
	s_mov_b32 s10, s2                                           ; be8a0002
	s_movk_i32 s11, 0x8000                                      ; b00b8000
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_load_dwordx4 s[12:15], s[10:11], 0x10                     ; c00a0305 00000010
	v_lshrrev_b32_e32 v4, 5, v1                                 ; 20080285
	v_lshlrev_b32_e32 v8, 2, v0                                 ; 24100082
	s_mul_i32 s4, s16, s3                                       ; 92040310
	s_cmp_lg_i32 s5, 0                                          ; bf018005
	v_add_u32_e32 v4, s6, v4                                    ; 68080806
	v_and_b32_e32 v5, 3, v4                                     ; 260a0883
	v_lshrrev_b32_e32 v4, 2, v4                                 ; 20080882
	v_lshlrev_b32_e32 v6, 4, v4                                 ; 240c0884
	v_lshl_add_u32 v4, v4, 7, v6                                ; d1fd0004 04190f04
	v_lshl_add_u32 v7, v5, 2, v4                                ; d1fd0007 04110505
	v_lshl_add_u32 v5, v5, 3, v8                                ; d1fd0005 04210705
	v_lshlrev_b32_e32 v5, 2, v5                                 ; 240a0a82
	v_add3_u32 v5, v5, 16, v4                                   ; d1ff0005 04112105
	s_cbranch_scc0 BB63                                         ; bf84007f
BB61:
	s_load_dwordx4 s[20:23], s[10:11], 0x0                      ; c00a0505 00000000
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_load_dword v7, v7, s[12:15], 0 offen                 ; e0501000 80030707
	buffer_load_dwordx4 v[12:15], v5, s[12:15], 0 offen         ; e05c1000 80030c05
	v_add_u32_e32 v4, s4, v1                                    ; 68080204
	v_lshrrev_b32_e32 v4, 5, v4                                 ; 20080885
	v_add_u32_e32 v4, s19, v4                                   ; 68080813
	v_and_b32_e32 v5, 7, v4                                     ; 260a0887
	v_lshrrev_b32_e32 v4, 3, v4                                 ; 20080883
	v_lshl_add_u32 v5, v5, 3, v8                                ; d1fd0005 04210705
	v_lshlrev_b32_e32 v10, 4, v4                                ; 24140884
	v_and_b32_e32 v6, 7, v5                                     ; 260c0a87
	v_lshrrev_b32_e32 v9, 4, v5                                 ; 20120a84
	v_lshl_add_u32 v4, v4, 7, v10                               ; d1fd0004 04290f04
	v_lshl_add_u32 v9, v9, 3, v6                                ; d1fd0009 04190709
	v_lshlrev_b32_e32 v9, 2, v9                                 ; 24121282
	v_add3_u32 v9, v9, 16, v4                                   ; d1ff0009 04112109
	buffer_load_dwordx4 v[16:19], v9, s[20:23], 0 offen         ; e05c1000 80051009
	buffer_load_dwordx4 v[20:23], v4, s[20:23], 0 offen         ; e05c1000 80051404
	v_bfe_u32 v11, v5, 3, 1                                     ; d1c8000b 02050705
	v_lshrrev_b32_e32 v5, 3, v5                                 ; 200a0a83
	s_mov_b32 s5, 0xf0f0f0f                                     ; be8500ff 0f0f0f0f
	v_lshlrev_b32_e32 v11, 2, v11                               ; 24161682
	v_and_b32_e32 v24, 3, v5                                    ; 26300a83
	v_cmp_gt_u32_e32 vcc, 4, v5                                 ; 7d980a84
	v_lshlrev_b32_e32 v24, 3, v24                               ; 24303083
	v_add_u32_e32 v26, 4, v24                                   ; 68343084
	v_add_u32_e32 v25, 2, v24                                   ; 68323082
	v_cndmask_b32_e32 v26, v26, v24, vcc                        ; 0034311a
	v_cndmask_b32_e32 v25, v25, v24, vcc                        ; 00323119
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_cvt_f32_f16_e32 v27, v7                                   ; 7e361707
	v_cvt_f32_f16_sdwa v7, v7 div:2 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e0e16f9 0005c607
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_lshrrev_b32_e32 v17, v11, v17                             ; 2022230b
	v_lshrrev_b32_e32 v18, v11, v18                             ; 2024250b
	v_lshrrev_b32_e32 v16, v11, v16                             ; 2020210b
	v_lshrrev_b32_e32 v11, v11, v19                             ; 2016270b
	v_and_b32_e32 v17, s5, v17                                  ; 26222205
	v_and_b32_e32 v18, s5, v18                                  ; 26242405
	v_and_b32_e32 v16, s5, v16                                  ; 26202005
	v_mul_i32_i24_sdwa v29, sext(v17), sext(v13) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 0c3a1af9 09090611
	v_mul_i32_i24_sdwa v30, sext(v17), sext(v13) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 0c3c1af9 0a0a0611
	v_mul_i32_i24_sdwa v28, sext(v17), sext(v13) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 src1_sel:BYTE_0 ; 0c381af9 08080611
	v_mul_i32_i24_sdwa v17, sext(v17), sext(v13) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 0c221af9 0b0b0611
	v_mul_i32_i24_sdwa v34, sext(v18), sext(v14) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 src1_sel:BYTE_0 ; 0c441cf9 08080612
	v_mul_i32_i24_sdwa v4, sext(v18), sext(v14) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 0c081cf9 09090612
	v_mul_i32_i24_sdwa v5, sext(v18), sext(v14) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 0c0a1cf9 0a0a0612
	v_mul_i32_i24_sdwa v18, sext(v18), sext(v14) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 0c241cf9 0b0b0612
	v_mul_i32_i24_sdwa v31, sext(v16), sext(v12) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 src1_sel:BYTE_0 ; 0c3e18f9 08080610
	v_mul_i32_i24_sdwa v33, sext(v16), sext(v12) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 0c4218f9 0a0a0610
	v_mul_i32_i24_sdwa v32, sext(v16), sext(v12) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 0c4018f9 09090610
	v_mul_i32_i24_sdwa v16, sext(v16), sext(v12) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 0c2018f9 0b0b0610
	v_and_b32_e32 v11, s5, v11                                  ; 26161605
	v_add3_u32 v28, v28, v29, v30                               ; d1ff001c 047a3b1c
	v_add3_u32 v34, v34, v4, v5                                 ; d1ff0022 04160922
	v_add3_u32 v31, v31, v32, v33                               ; d1ff001f 0486411f
	v_mul_i32_i24_sdwa v9, sext(v11), sext(v15) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 0c121ef9 0909060b
	v_mul_i32_i24_sdwa v10, sext(v11), sext(v15) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 0c141ef9 0a0a060b
	v_mul_i32_i24_sdwa v6, sext(v11), sext(v15) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 src1_sel:BYTE_0 ; 0c0c1ef9 0808060b
	v_mul_i32_i24_sdwa v11, sext(v11), sext(v15) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 0c161ef9 0b0b060b
	v_add3_u32 v28, v28, v17, 0                                 ; d1ff001c 0202231c
	v_add3_u32 v6, v6, v9, v10                                  ; d1ff0006 042a1306
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_cvt_f32_f16_e32 v12, v20                                  ; 7e181714
	v_add3_u32 v31, v31, v16, v28                               ; d1ff001f 0472211f
	v_cvt_f32_f16_sdwa v20, v20 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e2816f9 00050614
	v_add3_u32 v34, v34, v18, v31                               ; d1ff0022 047e2522
	v_add3_u32 v6, v6, v11, v34                                 ; d1ff0006 048a1706
	v_cndmask_b32_e32 v11, v23, v22, vcc                        ; 00162d17
	v_cndmask_b32_e32 v23, v23, v21, vcc                        ; 002e2b17
	v_lshrrev_b32_e32 v21, v25, v21                             ; 202a2b19
	v_lshrrev_b32_e32 v25, v25, v22                             ; 20322d19
	v_cvt_f32_i32_e32 v6, v6                                    ; 7e0c0b06
	v_bfe_u32 v11, v11, v26, 4                                  ; d1c8000b 0212350b
	v_bfe_u32 v23, v23, v24, 4                                  ; d1c80017 02123117
	v_and_or_b32 v25, 48, v25, v11                              ; d2010019 042e32b0
	v_and_or_b32 v21, 48, v21, v23                              ; d2010015 045e2ab0
	v_cvt_f32_ubyte0_e32 v25, v25                               ; 7e322319
	v_cvt_f32_ubyte0_e32 v21, v21                               ; 7e2a2315
	v_mul_f32_e32 v20, v20, v25                                 ; 0a283314
	v_mul_f32_e32 v12, v12, v21                                 ; 0a182b0c
	v_mul_f32_e32 v27, v27, v12                                 ; 0a36191b
	v_mac_f32_e32 v2, v27, v6                                   ; 2c040d1b
	v_mad_f32 v2, -v20, v7, v2                                  ; d1c10002 240a0f14
BB63:
	v_add_u32_e32 v4, 0x400, v1                                 ; 680802ff 00000400
	v_lshrrev_b32_e32 v5, 5, v4                                 ; 200a0885
	v_add_u32_e32 v5, s6, v5                                    ; 680a0a06
	v_and_b32_e32 v6, 3, v5                                     ; 260c0a83
	v_lshrrev_b32_e32 v5, 2, v5                                 ; 200a0a82
	v_lshlrev_b32_e32 v7, 4, v5                                 ; 240e0a84
	v_lshl_add_u32 v5, v5, 7, v7                                ; d1fd0005 041d0f05
	v_lshl_add_u32 v9, v6, 2, v5                                ; d1fd0009 04150506
	v_lshl_add_u32 v6, v6, 3, v8                                ; d1fd0006 04210706
	v_lshlrev_b32_e32 v6, 2, v6                                 ; 240c0c82
	v_add3_u32 v6, v6, 16, v5                                   ; d1ff0006 04152106
	s_cbranch_scc0 BB66                                         ; bf84007f
BB64:
	s_load_dwordx4 s[20:23], s[10:11], 0x0                      ; c00a0505 00000000
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_load_dword v9, v9, s[12:15], 0 offen                 ; e0501000 80030909
	buffer_load_dwordx4 v[12:15], v6, s[12:15], 0 offen         ; e05c1000 80030c06
	v_add_u32_e32 v4, s4, v4                                    ; 68080804
	v_lshrrev_b32_e32 v4, 5, v4                                 ; 20080885
	v_add_u32_e32 v4, s19, v4                                   ; 68080813
	v_and_b32_e32 v5, 7, v4                                     ; 260a0887
	v_lshrrev_b32_e32 v4, 3, v4                                 ; 20080883
	v_lshl_add_u32 v5, v5, 3, v8                                ; d1fd0005 04210705
	v_lshlrev_b32_e32 v8, 4, v4                                 ; 24100884
	v_and_b32_e32 v6, 7, v5                                     ; 260c0a87
	v_lshrrev_b32_e32 v7, 4, v5                                 ; 200e0a84
	v_lshl_add_u32 v4, v4, 7, v8                                ; d1fd0004 04210f04
	v_lshl_add_u32 v7, v7, 3, v6                                ; d1fd0007 04190707
	v_lshlrev_b32_e32 v7, 2, v7                                 ; 240e0e82
	v_add3_u32 v7, v7, 16, v4                                   ; d1ff0007 04112107
	buffer_load_dwordx4 v[16:19], v7, s[20:23], 0 offen         ; e05c1000 80051007
	buffer_load_dwordx4 v[20:23], v4, s[20:23], 0 offen         ; e05c1000 80051404
	v_bfe_u32 v10, v5, 3, 1                                     ; d1c8000a 02050705
	v_lshrrev_b32_e32 v5, 3, v5                                 ; 200a0a83
	s_mov_b32 s4, 0xf0f0f0f                                     ; be8400ff 0f0f0f0f
	v_lshlrev_b32_e32 v10, 2, v10                               ; 24141482
	v_and_b32_e32 v11, 3, v5                                    ; 26160a83
	v_cmp_gt_u32_e32 vcc, 4, v5                                 ; 7d980a84
	v_lshlrev_b32_e32 v11, 3, v11                               ; 24161683
	v_add_u32_e32 v25, 4, v11                                   ; 68321684
	v_add_u32_e32 v24, 2, v11                                   ; 68301682
	v_cndmask_b32_e32 v25, v25, v11, vcc                        ; 00321719
	v_cndmask_b32_e32 v24, v24, v11, vcc                        ; 00301718
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_cvt_f32_f16_e32 v26, v9                                   ; 7e341709
	v_cvt_f32_f16_sdwa v9, v9 div:2 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e1216f9 0005c609
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_lshrrev_b32_e32 v17, v10, v17                             ; 2022230a
	v_lshrrev_b32_e32 v18, v10, v18                             ; 2024250a
	v_lshrrev_b32_e32 v16, v10, v16                             ; 2020210a
	v_lshrrev_b32_e32 v10, v10, v19                             ; 2014270a
	v_and_b32_e32 v17, s4, v17                                  ; 26222204
	v_and_b32_e32 v18, s4, v18                                  ; 26242404
	v_and_b32_e32 v16, s4, v16                                  ; 26202004
	v_mul_i32_i24_sdwa v28, sext(v17), sext(v13) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 0c381af9 09090611
	v_mul_i32_i24_sdwa v29, sext(v17), sext(v13) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 0c3a1af9 0a0a0611
	v_mul_i32_i24_sdwa v27, sext(v17), sext(v13) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 src1_sel:BYTE_0 ; 0c361af9 08080611
	v_mul_i32_i24_sdwa v17, sext(v17), sext(v13) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 0c221af9 0b0b0611
	v_mul_i32_i24_sdwa v33, sext(v18), sext(v14) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 src1_sel:BYTE_0 ; 0c421cf9 08080612
	v_mul_i32_i24_sdwa v34, sext(v18), sext(v14) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 0c441cf9 09090612
	v_mul_i32_i24_sdwa v4, sext(v18), sext(v14) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 0c081cf9 0a0a0612
	v_mul_i32_i24_sdwa v18, sext(v18), sext(v14) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 0c241cf9 0b0b0612
	v_mul_i32_i24_sdwa v30, sext(v16), sext(v12) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 src1_sel:BYTE_0 ; 0c3c18f9 08080610
	v_mul_i32_i24_sdwa v32, sext(v16), sext(v12) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 0c4018f9 0a0a0610
	v_mul_i32_i24_sdwa v31, sext(v16), sext(v12) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 0c3e18f9 09090610
	v_mul_i32_i24_sdwa v16, sext(v16), sext(v12) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 0c2018f9 0b0b0610
	v_and_b32_e32 v10, s4, v10                                  ; 26141404
	v_add3_u32 v27, v27, v28, v29                               ; d1ff001b 0476391b
	v_add3_u32 v33, v33, v34, v4                                ; d1ff0021 04124521
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_cndmask_b32_e32 v8, v23, v22, vcc                         ; 00102d17
	v_add3_u32 v30, v30, v31, v32                               ; d1ff001e 04823f1e
	v_cndmask_b32_e32 v23, v23, v21, vcc                        ; 002e2b17
	v_mul_i32_i24_sdwa v6, sext(v10), sext(v15) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 0c0c1ef9 0909060a
	v_mul_i32_i24_sdwa v7, sext(v10), sext(v15) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 0c0e1ef9 0a0a060a
	v_lshrrev_b32_e32 v21, v24, v21                             ; 202a2b18
	v_mul_i32_i24_sdwa v5, sext(v10), sext(v15) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 src1_sel:BYTE_0 ; 0c0a1ef9 0808060a
	v_mul_i32_i24_sdwa v10, sext(v10), sext(v15) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 0c141ef9 0b0b060a
	v_add3_u32 v27, v27, v17, 0                                 ; d1ff001b 0202231b
	v_lshrrev_b32_e32 v24, v24, v22                             ; 20302d18
	v_bfe_u32 v8, v8, v25, 4                                    ; d1c80008 02123308
	v_bfe_u32 v23, v23, v11, 4                                  ; d1c80017 02121717
	v_add3_u32 v5, v5, v6, v7                                   ; d1ff0005 041e0d05
	v_add3_u32 v30, v30, v16, v27                               ; d1ff001e 046e211e
	v_and_or_b32 v24, 48, v24, v8                               ; d2010018 042230b0
	v_and_or_b32 v21, 48, v21, v23                              ; d2010015 045e2ab0
	v_add3_u32 v33, v33, v18, v30                               ; d1ff0021 047a2521
	v_cvt_f32_ubyte0_e32 v24, v24                               ; 7e302318
	v_cvt_f32_ubyte0_e32 v21, v21                               ; 7e2a2315
	v_add3_u32 v5, v5, v10, v33                                 ; d1ff0005 04861505
	v_cvt_f32_f16_e32 v10, v20                                  ; 7e141714
	v_cvt_f32_f16_sdwa v20, v20 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e2816f9 00050614
	v_cvt_f32_i32_e32 v5, v5                                    ; 7e0a0b05
	v_mul_f32_e32 v10, v10, v21                                 ; 0a142b0a
	v_mul_f32_e32 v20, v20, v24                                 ; 0a283114
	v_mul_f32_e32 v26, v26, v10                                 ; 0a34151a
	v_mac_f32_e32 v2, v26, v5                                   ; 2c040b1a
	v_mad_f32 v2, -v20, v9, v2                                  ; d1c10002 240a1314
BB66:
	v_add_u32_e32 v3, -2, v3                                    ; 680606c2
	v_add_u32_e32 v1, 0x800, v1                                 ; 680202ff 00000800
	s_mov_b32 s5, src_scc                                       ; be8500fd
BB71:
	s_mov_b64 exec, -1                                          ; befe01c1
	v_cmpx_ne_i32_e32 vcc, 0, v3                                ; 7daa0680
	s_cbranch_execz BB80                                        ; bf880097
BB72:
	s_mov_b32 s10, s2                                           ; be8a0002
	s_movk_i32 s11, 0x8000                                      ; b00b8000
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_load_dwordx4 s[12:15], s[10:11], 0x10                     ; c00a0305 00000010
	v_lshrrev_b32_e32 v3, 5, v1                                 ; 20060285
	v_lshlrev_b32_e32 v0, 2, v0                                 ; 24000082
	s_mul_i32 s3, s16, s3                                       ; 92030310
	s_cmp_lg_i32 s5, 0                                          ; bf018005
	v_add_u32_e32 v3, s6, v3                                    ; 68060606
	v_and_b32_e32 v4, 3, v3                                     ; 26080683
	v_lshrrev_b32_e32 v3, 2, v3                                 ; 20060682
	v_lshlrev_b32_e32 v5, 4, v3                                 ; 240a0684
	v_lshl_add_u32 v3, v3, 7, v5                                ; d1fd0003 04150f03
	v_lshl_add_u32 v6, v4, 2, v3                                ; d1fd0006 040d0504
	v_lshl_add_u32 v4, v4, 3, v0                                ; d1fd0004 04010704
	v_lshlrev_b32_e32 v4, 2, v4                                 ; 24080882
	v_add3_u32 v4, v4, 16, v3                                   ; d1ff0004 040d2104
	s_cbranch_scc0 BB75                                         ; bf84007f
BB73:
	s_load_dwordx4 s[20:23], s[10:11], 0x0                      ; c00a0505 00000000
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_load_dword v6, v6, s[12:15], 0 offen                 ; e0501000 80030606
	buffer_load_dwordx4 v[8:11], v4, s[12:15], 0 offen          ; e05c1000 80030804
	v_add_u32_e32 v1, s3, v1                                    ; 68020203
	v_lshrrev_b32_e32 v1, 5, v1                                 ; 20020285
	v_add_u32_e32 v1, s19, v1                                   ; 68020213
	v_and_b32_e32 v3, 7, v1                                     ; 26060287
	v_lshrrev_b32_e32 v1, 3, v1                                 ; 20020283
	v_lshl_add_u32 v3, v3, 3, v0                                ; d1fd0003 04010703
	v_lshlrev_b32_e32 v7, 4, v1                                 ; 240e0284
	v_and_b32_e32 v4, 7, v3                                     ; 26080687
	v_lshrrev_b32_e32 v5, 4, v3                                 ; 200a0684
	v_lshl_add_u32 v1, v1, 7, v7                                ; d1fd0001 041d0f01
	v_lshl_add_u32 v5, v5, 3, v4                                ; d1fd0005 04110705
	v_lshlrev_b32_e32 v5, 2, v5                                 ; 240a0a82
	v_add3_u32 v5, v5, 16, v1                                   ; d1ff0005 04052105
	buffer_load_dwordx4 v[12:15], v5, s[20:23], 0 offen         ; e05c1000 80050c05
	buffer_load_dwordx4 v[16:19], v1, s[20:23], 0 offen         ; e05c1000 80051001
	v_bfe_u32 v20, v3, 3, 1                                     ; d1c80014 02050703
	v_lshrrev_b32_e32 v3, 3, v3                                 ; 20060683
	s_mov_b32 s3, 0xf0f0f0f                                     ; be8300ff 0f0f0f0f
	v_lshlrev_b32_e32 v20, 2, v20                               ; 24282882
	v_and_b32_e32 v21, 3, v3                                    ; 262a0683
	v_cmp_gt_u32_e32 vcc, 4, v3                                 ; 7d980684
	v_lshlrev_b32_e32 v21, 3, v21                               ; 242a2a83
	v_add_u32_e32 v23, 4, v21                                   ; 682e2a84
	v_add_u32_e32 v22, 2, v21                                   ; 682c2a82
	v_cndmask_b32_e32 v23, v23, v21, vcc                        ; 002e2b17
	v_cndmask_b32_e32 v22, v22, v21, vcc                        ; 002c2b16
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_cvt_f32_f16_e32 v24, v6                                   ; 7e301706
	v_cvt_f32_f16_sdwa v6, v6 div:2 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e0c16f9 0005c606
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_lshrrev_b32_e32 v13, v20, v13                             ; 201a1b14
	v_lshrrev_b32_e32 v14, v20, v14                             ; 201c1d14
	v_lshrrev_b32_e32 v12, v20, v12                             ; 20181914
	v_lshrrev_b32_e32 v20, v20, v15                             ; 20281f14
	v_and_b32_e32 v13, s3, v13                                  ; 261a1a03
	v_and_b32_e32 v14, s3, v14                                  ; 261c1c03
	v_and_b32_e32 v12, s3, v12                                  ; 26181803
	v_mul_i32_i24_sdwa v26, sext(v13), sext(v9) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 0c3412f9 0909060d
	v_mul_i32_i24_sdwa v27, sext(v13), sext(v9) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 0c3612f9 0a0a060d
	v_mul_i32_i24_sdwa v25, sext(v13), sext(v9) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 src1_sel:BYTE_0 ; 0c3212f9 0808060d
	v_mul_i32_i24_sdwa v13, sext(v13), sext(v9) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 0c1a12f9 0b0b060d
	v_mul_i32_i24_sdwa v31, sext(v14), sext(v10) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 src1_sel:BYTE_0 ; 0c3e14f9 0808060e
	v_mul_i32_i24_sdwa v32, sext(v14), sext(v10) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 0c4014f9 0909060e
	v_mul_i32_i24_sdwa v33, sext(v14), sext(v10) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 0c4214f9 0a0a060e
	v_mul_i32_i24_sdwa v14, sext(v14), sext(v10) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 0c1c14f9 0b0b060e
	v_mul_i32_i24_sdwa v28, sext(v12), sext(v8) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 src1_sel:BYTE_0 ; 0c3810f9 0808060c
	v_mul_i32_i24_sdwa v30, sext(v12), sext(v8) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 0c3c10f9 0a0a060c
	v_mul_i32_i24_sdwa v29, sext(v12), sext(v8) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 0c3a10f9 0909060c
	v_mul_i32_i24_sdwa v12, sext(v12), sext(v8) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 0c1810f9 0b0b060c
	v_and_b32_e32 v20, s3, v20                                  ; 26282803
	v_add3_u32 v25, v25, v26, v27                               ; d1ff0019 046e3519
	v_add3_u32 v31, v31, v32, v33                               ; d1ff001f 0486411f
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_cndmask_b32_e32 v3, v19, v18, vcc                         ; 00062513
	v_add3_u32 v28, v28, v29, v30                               ; d1ff001c 047a3b1c
	v_cndmask_b32_e32 v19, v19, v17, vcc                        ; 00262313
	v_mul_i32_i24_sdwa v0, sext(v20), sext(v11) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 0c0016f9 09090614
	v_mul_i32_i24_sdwa v1, sext(v20), sext(v11) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 0c0216f9 0a0a0614
	v_lshrrev_b32_e32 v17, v22, v17                             ; 20222316
	v_mul_i32_i24_sdwa v34, sext(v20), sext(v11) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 src1_sel:BYTE_0 ; 0c4416f9 08080614
	v_mul_i32_i24_sdwa v20, sext(v20), sext(v11) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 0c2816f9 0b0b0614
	v_add3_u32 v25, v25, v13, 0                                 ; d1ff0019 02021b19
	v_lshrrev_b32_e32 v22, v22, v18                             ; 202c2516
	v_bfe_u32 v3, v3, v23, 4                                    ; d1c80003 02122f03
	v_bfe_u32 v19, v19, v21, 4                                  ; d1c80013 02122b13
	v_cvt_f32_f16_e32 v4, v16                                   ; 7e081710
	v_cvt_f32_f16_sdwa v16, v16 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e2016f9 00050610
	v_add3_u32 v34, v34, v0, v1                                 ; d1ff0022 04060122
	v_add3_u32 v28, v28, v12, v25                               ; d1ff001c 0466191c
	v_and_or_b32 v22, 48, v22, v3                               ; d2010016 040e2cb0
	v_and_or_b32 v17, 48, v17, v19                              ; d2010011 044e22b0
	v_add3_u32 v31, v31, v14, v28                               ; d1ff001f 04721d1f
	v_cvt_f32_ubyte0_e32 v22, v22                               ; 7e2c2316
	v_cvt_f32_ubyte0_e32 v17, v17                               ; 7e222311
	v_add3_u32 v34, v34, v20, v31                               ; d1ff0022 047e2922
	v_mul_f32_e32 v16, v16, v22                                 ; 0a202d10
	v_mul_f32_e32 v4, v4, v17                                   ; 0a082304
	v_cvt_f32_i32_e32 v34, v34                                  ; 7e440b22
	v_mul_f32_e32 v24, v24, v4                                  ; 0a300918
	v_mac_f32_e32 v2, v24, v34                                  ; 2c044518
	v_mad_f32 v2, -v16, v6, v2                                  ; d1c10002 240a0d10
BB75:
	s_mov_b32 s5, src_scc                                       ; be8500fd
BB80:
	s_mov_b64 exec, -1                                          ; befe01c1
	s_cmp_lg_i32 s5, 0                                          ; bf018005
	s_cbranch_scc0 BB83                                         ; bf840019
BB81:
	s_or_saveexec_b64 s[4:5], -1                                ; be8421c1
	v_cndmask_b32_e64 v35, 0, v2, s[4:5]                        ; d1000023 00120480
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v35, v35, v35 quad_perm:[1,0,3,2] row_mask:0xf bank_mask:0xf ; 024646fa ff00b123
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v35, v35, v35 quad_perm:[2,3,0,1] row_mask:0xf bank_mask:0xf ; 024646fa ff004e23
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v35, v35, v35 row_half_mirror row_mask:0xf bank_mask:0xf ; 024646fa ff014123
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v35, v35, v35 row_mirror row_mask:0xf bank_mask:0xf ; 024646fa ff014023
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v35, v35, v35 row_bcast:15 row_mask:0xa bank_mask:0xf ; 024646fa af014223
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v35, v35, v35 row_bcast:31 row_mask:0xc bank_mask:0xf ; 024646fa cf014323
	s_mov_b64 exec, s[4:5]                                      ; befe0104
	v_readlane_b32 s3, v35, 63                                  ; d2890003 00017f23
	v_mov_b32_e32 v2, s3                                        ; 7e040203
BB83:
	s_mov_b64 s[4:5], 1                                         ; be840181
	s_and_b64 exec, s[0:1], s[4:5]                              ; 86fe0400
	s_cbranch_execz BB98                                        ; bf880026
BB84:
	s_bitcmp1_b32 s8, 0                                         ; bf0d8008
	s_cbranch_scc0 BB87                                         ; bf84000d
BB85:
	s_mov_b32 s0, s2                                            ; be800002
	s_movk_i32 s1, 0x8000                                       ; b0018000
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_load_dwordx4 s[12:15], s[0:1], 0x30                       ; c00a0300 00000030
	s_mul_i32 s0, s7, s17                                       ; 92001107
	s_add_u32 s0, s0, s16                                       ; 80001000
	s_lshl_b32 s0, s0, 2                                        ; 8e008200
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s0, s[12:15], s0                        ; c0200006 00000000
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v2, s0, v2                                    ; 02040400
BB87:
	s_bitcmp1_b32 s8, 1                                         ; bf0d8108
	s_cbranch_scc0 BB90                                         ; bf84000c
BB88:
	s_mov_b32 s0, s2                                            ; be800002
	s_movk_i32 s1, 0x8000                                       ; b0018000
	s_load_dwordx4 s[8:11], s[0:1], 0x40                        ; c00a0200 00000040
	s_mul_i32 s0, s7, s17                                       ; 92001107
	s_add_u32 s0, s0, s16                                       ; 80001000
	s_lshl_b32 s0, s0, 2                                        ; 8e008200
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s0, s[8:11], s0                         ; c0200004 00000000
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v2, s0, v2                                    ; 02040400
BB90:
	s_movk_i32 s3, 0x8000                                       ; b0038000
	s_load_dwordx4 s[0:3], s[2:3], 0x20                         ; c00a0001 00000020
	s_mul_i32 s7, s7, s17                                       ; 92071107
	s_add_u32 s7, s7, s16                                       ; 80071007
	s_lshl_b32 s7, s7, 2                                        ; 8e078207
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_store_dword v2, off, s[0:3], s7                      ; e0700000 07000280
BB98:
	s_endpgm                                                    ; bf810000
