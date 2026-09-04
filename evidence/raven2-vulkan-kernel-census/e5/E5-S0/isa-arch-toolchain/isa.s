BB0:
	s_load_dword s0, s[14:15], 0x0                              ; c0020007 00000000
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_mul_i32 s0, s0, s18                                       ; 92001200
	s_add_u32 s16, s16, s0                                      ; 80100010
	s_add_u32 s1, s16, 1                                        ; 80018110
	s_cmp_ge_u32 s4, s1                                         ; bf090104
	s_cbranch_scc0 BB36                                         ; bf84048c
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
	s_branch BB5                                                ; bf82023a
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
	v_add_u32_e32 v26, v26, v9                                  ; 6834131a
	v_mul_f32_e32 v20, v20, v11                                 ; 0a281714
	v_mul_i32_i24_sdwa v11, sext(v17), sext(v13) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 src1_sel:BYTE_0 ; 0c161af9 08080611
	v_mul_i32_i24_sdwa v17, sext(v17), sext(v13) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 0c221af9 0b0b0611
	v_mul_i32_i24_sdwa v13, sext(v16), sext(v12) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 0c1a18f9 0a0a0610
	v_mul_i32_i24_sdwa v16, sext(v16), sext(v12) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 0c2018f9 0b0b0610
	v_add_u32_e32 v11, v11, v19                                 ; 6816270b
	v_mul_i32_i24_sdwa v19, sext(v18), sext(v14) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 0c261cf9 0a0a0612
	v_add3_u32 v26, v26, v13, v16                               ; d1ff001a 04421b1a
	v_mul_i32_i24_sdwa v16, sext(v18), sext(v14) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 src1_sel:BYTE_0 ; 0c201cf9 08080612
	v_add3_u32 v11, v11, v21, v17                               ; d1ff000b 04462b0b
	v_mul_i32_i24_sdwa v17, sext(v18), sext(v14) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 0c221cf9 09090612
	v_mul_i32_i24_sdwa v18, sext(v18), sext(v14) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 0c241cf9 0b0b0612
	v_add_u32_e32 v21, 0x800, v1                                ; 682a02ff 00000800
	v_add_u32_e32 v16, v16, v17                                 ; 68202310
	v_lshrrev_b32_e32 v9, 5, v21                                ; 20122a85
	v_add3_u32 v16, v16, v19, v18                               ; d1ff0010 044a2710
	v_add_u32_e32 v9, s6, v9                                    ; 68121206
	v_and_b32_e32 v12, 3, v9                                    ; 26181283
	v_lshrrev_b32_e32 v9, 2, v9                                 ; 20121282
	v_lshlrev_b32_e32 v13, 4, v9                                ; 241a1284
	v_lshl_add_u32 v9, v9, 7, v13                               ; d1fd0009 04350f09
	v_lshl_add_u32 v14, v12, 2, v9                              ; d1fd000e 0425050c
	v_lshl_add_u32 v12, v12, 3, v8                              ; d1fd000c 0421070c
	v_lshlrev_b32_e32 v12, 2, v12                               ; 24181882
	v_add3_u32 v12, v12, 16, v9                                 ; d1ff000c 0425210c
	v_mov_b32_e32 v9, v16                                       ; 7e120310
	buffer_load_dword v14, v14, s[28:31], 0 offen               ; e0501000 80070e0e
	buffer_load_dwordx4 v[16:19], v12, s[28:31], 0 offen        ; e05c1000 8007100c
	v_and_b32_e32 v27, s1, v27                                  ; 26363601
	v_add_u32_e32 v21, s0, v21                                  ; 682a2a00
	v_add3_u32 v9, v9, v26, v11                                 ; d1ff0009 042e3509
	v_mul_i32_i24_sdwa v11, sext(v27), sext(v15) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 src1_sel:BYTE_0 ; 0c161ef9 0808061b
	v_mul_i32_i24_sdwa v13, sext(v27), sext(v15) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 0c1a1ef9 0a0a061b
	v_mul_i32_i24_sdwa v12, sext(v27), sext(v15) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 0c181ef9 0909061b
	v_mul_i32_i24_sdwa v27, sext(v27), sext(v15) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 0c361ef9 0b0b061b
	v_cvt_f32_f16_e32 v15, v34                                  ; 7e1e1722
	v_cvt_f32_f16_sdwa v34, v34 div:2 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e4416f9 0005c622
	v_lshrrev_b32_e32 v21, 5, v21                               ; 202a2a85
	v_add_u32_e32 v11, v11, v12                                 ; 6816190b
	v_mul_f32_e32 v15, v15, v10                                 ; 0a1e150f
	v_add_u32_e32 v21, s18, v21                                 ; 682a2a12
	v_add3_u32 v11, v11, v13, v27                               ; d1ff000b 046e1b0b
	v_and_b32_e32 v26, 7, v21                                   ; 26342a87
	v_lshrrev_b32_e32 v21, 3, v21                               ; 202a2a83
	v_add_u32_e32 v11, v11, v9                                  ; 6816130b
	v_lshl_add_u32 v26, v26, 3, v8                              ; d1fd001a 0421071a
	v_lshlrev_b32_e32 v10, 4, v21                               ; 24142a84
	v_cvt_f32_i32_e32 v11, v11                                  ; 7e160b0b
	v_and_b32_e32 v27, 7, v26                                   ; 26363487
	v_lshrrev_b32_e32 v9, 4, v26                                ; 20123484
	v_lshl_add_u32 v21, v21, 7, v10                             ; d1fd0015 04290f15
	v_mac_f32_e32 v2, v15, v11                                  ; 2c04170f
	v_bfe_u32 v11, v29, 3, 1                                    ; d1c8000b 0205071d
	v_lshrrev_b32_e32 v29, 3, v29                               ; 203a3a83
	v_lshl_add_u32 v9, v9, 3, v27                               ; d1fd0009 046d0709
	v_mad_f32 v20, -v20, v34, v2                                ; d1c10014 240a4514
	v_lshlrev_b32_e32 v11, 2, v11                               ; 24161682
	v_cmp_gt_u32_e32 vcc, 4, v29                                ; 7d983a84
	v_and_b32_e32 v12, 3, v29                                   ; 26183a83
	v_lshlrev_b32_e32 v9, 2, v9                                 ; 24121282
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_lshrrev_b32_e32 v5, v11, v5                               ; 200a0b0b
	v_lshrrev_b32_e32 v4, v11, v4                               ; 2008090b
	v_lshrrev_b32_e32 v6, v11, v6                               ; 200c0d0b
	v_lshrrev_b32_e32 v11, v11, v7                              ; 20160f0b
	v_add3_u32 v9, v9, 16, v21                                  ; d1ff0009 04552109
	v_mov_b32_e32 v2, v8                                        ; 7e040308
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_cndmask_b32_e32 v27, v25, v24, vcc                        ; 00363119
	v_cndmask_b32_e32 v25, v25, v23, vcc                        ; 00322f19
	v_lshlrev_b32_e32 v12, 3, v12                               ; 24181883
	v_bfe_u32 v25, v25, v12, 4                                  ; d1c80019 02121919
	v_add_u32_e32 v15, 4, v12                                   ; 681e1884
	v_add_u32_e32 v13, 2, v12                                   ; 681a1882
	v_cndmask_b32_e32 v15, v15, v12, vcc                        ; 001e190f
	v_cndmask_b32_e32 v13, v13, v12, vcc                        ; 001a190d
	v_bfe_u32 v27, v27, v15, 4                                  ; d1c8001b 02121f1b
	v_lshrrev_b32_e32 v23, v13, v23                             ; 202e2f0d
	v_and_or_b32 v23, 48, v23, v25                              ; d2010017 04662eb0
	v_mov_b32_e32 v25, v13                                      ; 7e32030d
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_mov_b32_e32 v29, v14                                      ; 7e3a030e
	buffer_load_dwordx4 v[7:10], v9, s[24:27], 0 offen          ; e05c1000 80060709
	buffer_load_dwordx4 v[12:15], v21, s[24:27], 0 offen        ; e05c1000 80060c15
	v_and_b32_e32 v5, s1, v5                                    ; 260a0a01
	v_cvt_f32_f16_e32 v34, v22                                  ; 7e441716
	v_cvt_f32_f16_sdwa v22, v22 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e2c16f9 00050616
	v_cvt_f32_ubyte0_e32 v23, v23                               ; 7e2e2317
	v_lshrrev_b32_e32 v25, v25, v24                             ; 20323119
	v_and_b32_e32 v4, s1, v4                                    ; 26080801
	v_mul_i32_i24_sdwa v21, sext(v5), sext(v31) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 src1_sel:BYTE_0 ; 0c2a3ef9 08080605
	v_mul_i32_i24_sdwa v24, sext(v5), sext(v31) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 0c303ef9 0a0a0605
	v_mul_f32_e32 v34, v34, v23                                 ; 0a442f22
	v_mul_i32_i24_sdwa v23, sext(v5), sext(v31) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 0c2e3ef9 09090605
	v_mul_i32_i24_sdwa v5, sext(v5), sext(v31) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 0c0a3ef9 0b0b0605
	v_and_or_b32 v25, 48, v25, v27                              ; d2010019 046e32b0
	v_mul_i32_i24_sdwa v27, sext(v4), sext(v30) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 0c363cf9 09090604
	v_and_b32_e32 v6, s1, v6                                    ; 260c0c01
	v_mul_i32_i24_sdwa v31, sext(v4), sext(v30) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 0c3e3cf9 0a0a0604
	v_add_u32_e32 v21, v21, v23                                 ; 682a2f15
	v_cvt_f32_ubyte0_e32 v25, v25                               ; 7e322319
	v_mul_i32_i24_sdwa v23, sext(v6), sext(v32) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 0c2e40f9 0a0a0606
	v_add3_u32 v21, v21, v24, v5                                ; d1ff0015 04163115
	v_add_u32_e32 v24, 0xc00, v1                                ; 683002ff 00000c00
	v_mul_i32_i24_sdwa v5, sext(v6), sext(v32) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 0c0a40f9 09090606
	v_mul_f32_e32 v22, v22, v25                                 ; 0a2c3316
	v_mul_i32_i24_sdwa v25, sext(v4), sext(v30) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 src1_sel:BYTE_0 ; 0c323cf9 08080604
	v_mul_i32_i24_sdwa v4, sext(v4), sext(v30) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 0c083cf9 0b0b0604
	v_add_u32_e32 v25, v25, v27                                 ; 68323719
	v_lshrrev_b32_e32 v27, 5, v24                               ; 20363085
	v_add3_u32 v25, v25, v31, v4                                ; d1ff0019 04123f19
	v_mul_i32_i24_sdwa v4, sext(v6), sext(v32) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 src1_sel:BYTE_0 ; 0c0840f9 08080606
	v_mul_i32_i24_sdwa v6, sext(v6), sext(v32) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 0c0c40f9 0b0b0606
	v_add_u32_e32 v27, s6, v27                                  ; 68363606
	v_add_u32_e32 v4, v4, v5                                    ; 68080b04
	v_mov_b32_e32 v5, v28                                       ; 7e0a031c
	v_and_b32_e32 v30, 3, v27                                   ; 263c3683
	v_lshrrev_b32_e32 v27, 2, v27                               ; 20363682
	v_add3_u32 v4, v4, v23, v6                                  ; d1ff0004 041a2f04
	v_mov_b32_e32 v6, v29                                       ; 7e0c031d
	v_lshlrev_b32_e32 v31, 4, v27                               ; 243e3684
	v_lshl_add_u32 v27, v27, 7, v31                             ; d1fd001b 047d0f1b
	v_lshl_add_u32 v32, v30, 2, v27                             ; d1fd0020 046d051e
	v_lshl_add_u32 v30, v30, 3, v2                              ; d1fd001e 0409071e
	v_lshlrev_b32_e32 v30, 2, v30                               ; 243c3c82
	v_add3_u32 v30, v30, 16, v27                                ; d1ff001e 046d211e
	buffer_load_dword v32, v32, s[28:31], 0 offen               ; e0501000 80072020
	buffer_load_dwordx4 v[28:31], v30, s[28:31], 0 offen        ; e05c1000 80071c1e
	v_and_b32_e32 v11, s1, v11                                  ; 26161601
	v_add3_u32 v4, v4, v25, v21                                 ; d1ff0004 04563304
	v_cvt_f32_f16_e32 v27, v5                                   ; 7e361705
	v_add_u32_e32 v24, s0, v24                                  ; 68303000
	v_mul_i32_i24_sdwa v21, sext(v11), sext(v33) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 src1_sel:BYTE_0 ; 0c2a42f9 0808060b
	v_mul_i32_i24_sdwa v23, sext(v11), sext(v33) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 0c2e42f9 0909060b
	v_mul_i32_i24_sdwa v25, sext(v11), sext(v33) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 0c3242f9 0a0a060b
	v_mul_i32_i24_sdwa v11, sext(v11), sext(v33) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 0c1642f9 0b0b060b
	v_mul_f32_e32 v27, v27, v34                                 ; 0a36451b
	v_lshrrev_b32_e32 v24, 5, v24                               ; 20303085
	v_add_u32_e32 v21, v21, v23                                 ; 682a2f15
	v_cvt_f32_f16_sdwa v5, v5 div:2 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e0a16f9 0005c605
	v_add_u32_e32 v24, s18, v24                                 ; 68303012
	v_add3_u32 v21, v21, v25, v11                               ; d1ff0015 042e3315
	v_and_b32_e32 v33, 7, v24                                   ; 26423087
	v_lshrrev_b32_e32 v24, 3, v24                               ; 20303083
	v_add_u32_e32 v21, v21, v4                                  ; 682a0915
	v_lshl_add_u32 v33, v33, 3, v2                              ; d1fd0021 04090721
	v_lshlrev_b32_e32 v4, 4, v24                                ; 24083084
	v_cvt_f32_i32_e32 v21, v21                                  ; 7e2a0b15
	v_and_b32_e32 v34, 7, v33                                   ; 26444287
	v_lshrrev_b32_e32 v2, 4, v33                                ; 20044284
	v_lshl_add_u32 v24, v24, 7, v4                              ; d1fd0018 04110f18
	v_mac_f32_e32 v20, v27, v21                                 ; 2c282b1b
	v_bfe_u32 v23, v33, 3, 1                                    ; d1c80017 02050721
	v_lshl_add_u32 v2, v2, 3, v34                               ; d1fd0002 04890702
	v_mad_f32 v22, -v22, v5, v20                                ; d1c10016 24520b16
	v_bfe_u32 v5, v26, 3, 1                                     ; d1c80005 0205071a
	v_lshrrev_b32_e32 v26, 3, v26                               ; 20343483
	v_lshlrev_b32_e32 v23, 2, v23                               ; 242e2e82
	v_lshlrev_b32_e32 v2, 2, v2                                 ; 24040482
	v_lshlrev_b32_e32 v5, 2, v5                                 ; 240a0a82
	v_and_b32_e32 v11, 3, v26                                   ; 26163483
	v_cmp_gt_u32_e32 vcc, 4, v26                                ; 7d983484
	v_add3_u32 v2, v2, 16, v24                                  ; d1ff0002 04612102
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_lshrrev_b32_e32 v7, v5, v7                                ; 200e0f05
	v_lshrrev_b32_e32 v8, v5, v8                                ; 20101105
	v_lshrrev_b32_e32 v9, v5, v9                                ; 20121305
	v_lshrrev_b32_e32 v5, v5, v10                               ; 200a1505
	v_lshlrev_b32_e32 v11, 3, v11                               ; 24161683
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_cndmask_b32_e32 v25, v15, v14, vcc                        ; 00321d0f
	v_cndmask_b32_e32 v15, v15, v13, vcc                        ; 001e1b0f
	v_and_b32_e32 v8, s1, v8                                    ; 26101001
	v_add_u32_e32 v21, 4, v11                                   ; 682a1684
	v_add_u32_e32 v20, 2, v11                                   ; 68281682
	v_bfe_u32 v15, v15, v11, 4                                  ; d1c8000f 0212170f
	v_mov_b32_e32 v4, v8                                        ; 7e080308
	v_cndmask_b32_e32 v21, v21, v11, vcc                        ; 002a1715
	v_cndmask_b32_e32 v20, v20, v11, vcc                        ; 00281714
	v_bfe_u32 v25, v25, v21, 4                                  ; d1c80019 02122b19
	v_lshrrev_b32_e32 v13, v20, v13                             ; 201a1b14
	v_mov_b32_e32 v21, v25                                      ; 7e2a0319
	v_and_or_b32 v13, 48, v13, v15                              ; d201000d 043e1ab0
	v_mov_b32_e32 v15, v9                                       ; 7e1e0309
	buffer_load_dwordx4 v[8:11], v2, s[24:27], 0 offen          ; e05c1000 80060802
	buffer_load_dwordx4 v[24:27], v24, s[24:27], 0 offen        ; e05c1000 80061818
	v_cvt_f32_f16_e32 v34, v12                                  ; 7e44170c
	v_cvt_f32_f16_sdwa v12, v12 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e1816f9 0005060c
	v_mul_i32_i24_sdwa v2, sext(v4), sext(v17) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 src1_sel:BYTE_0 ; 0c0422f9 08080604
	v_lshrrev_b32_e32 v20, v20, v14                             ; 20281d14
	v_mul_i32_i24_sdwa v14, sext(v4), sext(v17) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 0c1c22f9 0a0a0604
	v_cvt_f32_ubyte0_e32 v13, v13                               ; 7e1a230d
	v_and_b32_e32 v7, s1, v7                                    ; 260e0e01
	v_and_or_b32 v20, 48, v20, v21                              ; d2010014 045628b0
	v_and_b32_e32 v15, s1, v15                                  ; 261e1e01
	v_mul_f32_e32 v34, v34, v13                                 ; 0a441b22
	v_mul_i32_i24_sdwa v13, sext(v4), sext(v17) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 0c1a22f9 09090604
	v_mul_i32_i24_sdwa v4, sext(v4), sext(v17) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 0c0822f9 0b0b0604
	v_mul_i32_i24_sdwa v21, sext(v7), sext(v16) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 0c2a20f9 0a0a0607
	v_mul_i32_i24_sdwa v17, sext(v7), sext(v16) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 src1_sel:BYTE_0 ; 0c2220f9 08080607
	v_cvt_f32_ubyte0_e32 v20, v20                               ; 7e282314
	v_add_u32_e32 v2, v2, v13                                   ; 68041b02
	v_mul_i32_i24_sdwa v13, sext(v15), sext(v18) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 0c1a24f9 0a0a060f
	v_and_b32_e32 v5, s1, v5                                    ; 260a0a01
	v_mul_f32_e32 v12, v12, v20                                 ; 0a18290c
	v_mul_i32_i24_sdwa v20, sext(v7), sext(v16) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 0c2820f9 09090607
	v_mul_i32_i24_sdwa v7, sext(v7), sext(v16) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 0c0e20f9 0b0b0607
	v_add3_u32 v2, v2, v14, v4                                  ; d1ff0002 04121d02
	v_mul_i32_i24_sdwa v4, sext(v15), sext(v18) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 src1_sel:BYTE_0 ; 0c0824f9 0808060f
	v_mul_i32_i24_sdwa v14, sext(v5), sext(v19) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 src1_sel:BYTE_0 ; 0c1c26f9 08080605
	v_mul_i32_i24_sdwa v16, sext(v5), sext(v19) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 0c2026f9 0a0a0605
	v_add_u32_e32 v17, v17, v20                                 ; 68222911
	v_add3_u32 v17, v17, v21, v7                                ; d1ff0011 041e2b11
	v_mul_i32_i24_sdwa v7, sext(v15), sext(v18) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 0c0e24f9 0909060f
	v_mul_i32_i24_sdwa v15, sext(v15), sext(v18) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 0c1e24f9 0b0b060f
	v_lshrrev_b32_e32 v33, 3, v33                               ; 20424283
	v_add_u32_e32 v4, v4, v7                                    ; 68080f04
	v_and_b32_e32 v18, 3, v33                                   ; 26244283
	v_cmp_gt_u32_e32 vcc, 4, v33                                ; 7d984284
	v_add3_u32 v4, v4, v13, v15                                 ; d1ff0004 043e1b04
	v_mul_i32_i24_sdwa v15, sext(v5), sext(v19) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 0c1e26f9 09090605
	v_mul_i32_i24_sdwa v5, sext(v5), sext(v19) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 0c0a26f9 0b0b0605
	v_lshlrev_b32_e32 v18, 3, v18                               ; 24242483
	v_add3_u32 v4, v4, v17, v2                                  ; d1ff0004 040a2304
	v_cvt_f32_f16_e32 v17, v6                                   ; 7e221706
	v_cvt_f32_f16_sdwa v6, v6 div:2 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e0c16f9 0005c606
	v_add_u32_e32 v14, v14, v15                                 ; 681c1f0e
	v_add_u32_e32 v3, -4, v3                                    ; 680606c4
	v_add_u32_e32 v1, 0x1000, v1                                ; 680202ff 00001000
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_cvt_f32_f16_e32 v21, v32                                  ; 7e2a1720
	v_add_u32_e32 v20, 4, v18                                   ; 68282484
	v_add_u32_e32 v19, 2, v18                                   ; 68262482
	v_cvt_f32_f16_sdwa v32, v32 div:2 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e4016f9 0005c620
	v_mul_f32_e32 v17, v17, v34                                 ; 0a224511
	v_add3_u32 v14, v14, v16, v5                                ; d1ff000e 0416210e
	v_cndmask_b32_e32 v20, v20, v18, vcc                        ; 00282514
	v_cndmask_b32_e32 v19, v19, v18, vcc                        ; 00262513
	v_add_u32_e32 v14, v14, v4                                  ; 681c090e
	v_cvt_f32_i32_e32 v14, v14                                  ; 7e1c0b0e
	v_mac_f32_e32 v22, v17, v14                                 ; 2c2c1d11
	v_mad_f32 v12, -v12, v6, v22                                ; d1c1000c 245a0d0c
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_lshrrev_b32_e32 v9, v23, v9                               ; 20121317
	v_lshrrev_b32_e32 v8, v23, v8                               ; 20101117
	v_lshrrev_b32_e32 v10, v23, v10                             ; 20141517
	v_lshrrev_b32_e32 v23, v23, v11                             ; 202e1717
	v_and_b32_e32 v9, s1, v9                                    ; 26121201
	v_and_b32_e32 v8, s1, v8                                    ; 26101001
	v_and_b32_e32 v10, s1, v10                                  ; 26141401
	v_mul_i32_i24_sdwa v22, sext(v9), sext(v29) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 src1_sel:BYTE_0 ; 0c2c3af9 08080609
	v_mul_i32_i24_sdwa v34, sext(v9), sext(v29) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 0c443af9 0a0a0609
	v_mul_i32_i24_sdwa v33, sext(v9), sext(v29) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 0c423af9 09090609
	v_mul_i32_i24_sdwa v9, sext(v9), sext(v29) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 0c123af9 0b0b0609
	v_mul_i32_i24_sdwa v4, sext(v8), sext(v28) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 0c0838f9 0a0a0608
	v_mul_i32_i24_sdwa v2, sext(v8), sext(v28) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 0c0438f9 09090608
	v_mul_i32_i24_sdwa v6, sext(v10), sext(v30) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 0c0c3cf9 0909060a
	v_mul_i32_i24_sdwa v5, sext(v10), sext(v30) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 src1_sel:BYTE_0 ; 0c0a3cf9 0808060a
	v_mul_i32_i24_sdwa v7, sext(v10), sext(v30) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 0c0e3cf9 0a0a060a
	v_mul_i32_i24_sdwa v10, sext(v10), sext(v30) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 0c143cf9 0b0b060a
	v_and_b32_e32 v23, s1, v23                                  ; 262e2e01
	v_add_u32_e32 v22, v22, v33                                 ; 682c4316
	v_add_u32_e32 v5, v5, v6                                    ; 680a0d05
	v_add3_u32 v22, v22, v34, v9                                ; d1ff0016 04264516
	v_mul_i32_i24_sdwa v34, sext(v8), sext(v28) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 src1_sel:BYTE_0 ; 0c4438f9 08080608
	v_mul_i32_i24_sdwa v8, sext(v8), sext(v28) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 0c1038f9 0b0b0608
	v_mul_i32_i24_sdwa v9, sext(v23), sext(v31) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 0c123ef9 09090617
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_cndmask_b32_e32 v11, v27, v26, vcc                        ; 0016351b
	v_cndmask_b32_e32 v27, v27, v25, vcc                        ; 0036331b
	v_add3_u32 v5, v5, v7, v10                                  ; d1ff0005 042a0f05
	v_mul_i32_i24_sdwa v10, sext(v23), sext(v31) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 0c143ef9 0a0a0617
	v_add_u32_e32 v34, v34, v2                                  ; 68440522
	v_lshrrev_b32_e32 v25, v19, v25                             ; 20323313
	v_lshrrev_b32_e32 v19, v19, v26                             ; 20263513
	v_bfe_u32 v11, v11, v20, 4                                  ; d1c8000b 0212290b
	v_bfe_u32 v27, v27, v18, 4                                  ; d1c8001b 0212251b
	v_cvt_f32_f16_e32 v13, v24                                  ; 7e1a1718
	v_add3_u32 v34, v34, v4, v8                                 ; d1ff0022 04220922
	v_mul_i32_i24_sdwa v8, sext(v23), sext(v31) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 src1_sel:BYTE_0 ; 0c103ef9 08080617
	v_mul_i32_i24_sdwa v23, sext(v23), sext(v31) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 0c2e3ef9 0b0b0617
	v_cvt_f32_f16_sdwa v24, v24 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e3016f9 00050618
	v_and_or_b32 v19, 48, v19, v11                              ; d2010013 042e26b0
	v_and_or_b32 v25, 48, v25, v27                              ; d2010019 046e32b0
	v_add3_u32 v5, v5, v34, v22                                 ; d1ff0005 045a4505
	v_add_u32_e32 v8, v8, v9                                    ; 68101308
	v_cvt_f32_ubyte0_e32 v19, v19                               ; 7e262313
	v_cvt_f32_ubyte0_e32 v25, v25                               ; 7e322319
	v_add3_u32 v8, v8, v10, v23                                 ; d1ff0008 045e1508
	v_mul_f32_e32 v24, v24, v19                                 ; 0a302718
	v_mul_f32_e32 v13, v13, v25                                 ; 0a1a330d
	v_add_u32_e32 v8, v8, v5                                    ; 68100b08
	v_mul_f32_e32 v21, v21, v13                                 ; 0a2a1b15
	v_cvt_f32_i32_e32 v8, v8                                    ; 7e100b08
	v_mac_f32_e32 v12, v21, v8                                  ; 2c181115
	v_mad_f32 v2, -v24, v32, v12                                ; d1c10002 24324118
BB5:
	s_mov_b64 s[0:1], exec                                      ; be80017e
	v_cmpx_gt_u32_e32 vcc, 4, v3                                ; 7db80684
BB6:
	s_andn2_b64 s[0:1], s[0:1], exec                            ; 89807e00
	s_cbranch_scc1 BB10                                         ; bf85fdc2
BB11:
	s_mov_b64 exec, -1                                          ; befe01c1
	v_cmpx_le_u32_e32 vcc, 2, v3                                ; 7db60682
	s_cbranch_execz BB17                                        ; bf88011e
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
	v_mul_i32_i24_sdwa v23, sext(v16), sext(v12) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 src1_sel:BYTE_0 ; 0c2e18f9 08080610
	v_mul_i32_i24_sdwa v13, sext(v16), sext(v12) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 0c1a18f9 0a0a0610
	v_and_b32_e32 v18, s1, v18                                  ; 26242401
	v_cvt_f32_ubyte0_e32 v9, v9                                 ; 7e122309
	v_add_u32_e32 v19, v19, v21                                 ; 68262b13
	v_and_b32_e32 v34, s1, v34                                  ; 26444401
	v_mul_i32_i24_sdwa v21, sext(v18), sext(v14) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 0c2a1cf9 0a0a0612
	v_mul_f32_e32 v20, v20, v9                                  ; 0a281314
	v_mul_i32_i24_sdwa v9, sext(v16), sext(v12) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 0c1218f9 09090610
	v_mul_i32_i24_sdwa v16, sext(v16), sext(v12) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 0c2018f9 0b0b0610
	v_add3_u32 v19, v19, v22, v17                               ; d1ff0013 04462d13
	v_mul_i32_i24_sdwa v17, sext(v18), sext(v14) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 0c221cf9 09090612
	v_mul_i32_i24_sdwa v22, sext(v34), sext(v15) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 src1_sel:BYTE_0 ; 0c2c1ef9 08080622
	v_add_u32_e32 v23, v23, v9                                  ; 682e1317
	v_mul_i32_i24_sdwa v9, sext(v34), sext(v15) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 0c121ef9 0a0a0622
	v_cvt_f32_f16_e32 v12, v8                                   ; 7e181708
	v_cvt_f32_f16_sdwa v8, v8 div:2 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e1016f9 0005c608
	v_add3_u32 v23, v23, v13, v16                               ; d1ff0017 04421b17
	v_mul_i32_i24_sdwa v16, sext(v18), sext(v14) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 src1_sel:BYTE_0 ; 0c201cf9 08080612
	v_mul_i32_i24_sdwa v18, sext(v18), sext(v14) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 0c241cf9 0b0b0612
	v_lshrrev_b32_e32 v29, 3, v29                               ; 203a3a83
	v_mul_f32_e32 v12, v12, v10                                 ; 0a18150c
	v_add_u32_e32 v16, v16, v17                                 ; 68202310
	v_cmp_gt_u32_e32 vcc, 4, v29                                ; 7d983a84
	v_and_b32_e32 v13, 3, v29                                   ; 261a3a83
	v_add3_u32 v16, v16, v21, v18                               ; d1ff0010 044a2b10
	v_add_u32_e32 v3, -2, v3                                    ; 680606c2
	v_add_u32_e32 v1, 0x800, v1                                 ; 680202ff 00000800
	v_lshlrev_b32_e32 v13, 3, v13                               ; 241a1a83
	v_add3_u32 v16, v16, v23, v19                               ; d1ff0010 044e2f10
	v_mul_i32_i24_sdwa v23, sext(v34), sext(v15) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 0c2e1ef9 09090622
	v_mul_i32_i24_sdwa v34, sext(v34), sext(v15) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 0c441ef9 0b0b0622
	v_add_u32_e32 v15, 4, v13                                   ; 681e1a84
	v_add_u32_e32 v14, 2, v13                                   ; 681c1a82
	v_add_u32_e32 v22, v22, v23                                 ; 682c2f16
	v_cndmask_b32_e32 v15, v15, v13, vcc                        ; 001e1b0f
	v_cndmask_b32_e32 v14, v14, v13, vcc                        ; 001c1b0e
	v_add3_u32 v22, v22, v9, v34                                ; d1ff0016 048a1316
	v_add_u32_e32 v22, v22, v16                                 ; 682c2116
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_cvt_f32_f16_e32 v16, v28                                  ; 7e20171c
	v_cvt_f32_f16_sdwa v28, v28 div:2 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e3816f9 0005c61c
	v_cvt_f32_i32_e32 v22, v22                                  ; 7e2c0b16
	v_mac_f32_e32 v2, v12, v22                                  ; 2c042d0c
	v_mad_f32 v20, -v20, v8, v2                                 ; d1c10014 240a1114
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_lshrrev_b32_e32 v26, v11, v26                             ; 2034350b
	v_lshrrev_b32_e32 v24, v11, v24                             ; 2030310b
	v_lshrrev_b32_e32 v25, v11, v25                             ; 2032330b
	v_lshrrev_b32_e32 v11, v11, v27                             ; 2016370b
	v_and_b32_e32 v26, s1, v26                                  ; 26343401
	v_and_b32_e32 v24, s1, v24                                  ; 26303001
	v_and_b32_e32 v25, s1, v25                                  ; 26323201
	v_mul_i32_i24_sdwa v23, sext(v24), sext(v30) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 0c2e3cf9 0a0a0618
	v_mul_i32_i24_sdwa v21, sext(v24), sext(v30) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 src1_sel:BYTE_0 ; 0c2a3cf9 08080618
	v_mul_i32_i24_sdwa v27, sext(v26), sext(v32) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 0c3640f9 0a0a061a
	v_mul_i32_i24_sdwa v22, sext(v24), sext(v30) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 0c2c3cf9 09090618
	v_mul_i32_i24_sdwa v24, sext(v24), sext(v30) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 0c303cf9 0b0b0618
	v_mul_i32_i24_sdwa v19, sext(v25), sext(v31) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 0c263ef9 0a0a0619
	v_mul_i32_i24_sdwa v17, sext(v25), sext(v31) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 src1_sel:BYTE_0 ; 0c223ef9 08080619
	v_mul_i32_i24_sdwa v18, sext(v25), sext(v31) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 0c243ef9 09090619
	v_mul_i32_i24_sdwa v25, sext(v25), sext(v31) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 0c323ef9 0b0b0619
	v_and_b32_e32 v11, s1, v11                                  ; 26161601
	v_add_u32_e32 v21, v21, v22                                 ; 682a2d15
	v_add_u32_e32 v17, v17, v18                                 ; 68222511
	v_mul_i32_i24_sdwa v29, sext(v11), sext(v33) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 src1_sel:BYTE_0 ; 0c3a42f9 0808060b
	v_mul_i32_i24_sdwa v30, sext(v11), sext(v33) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 0c3c42f9 0909060b
	v_mul_i32_i24_sdwa v31, sext(v11), sext(v33) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 0c3e42f9 0a0a060b
	v_mul_i32_i24_sdwa v11, sext(v11), sext(v33) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 0c1642f9 0b0b060b
	v_add3_u32 v21, v21, v23, v24                               ; d1ff0015 04622f15
	v_mul_i32_i24_sdwa v24, sext(v26), sext(v32) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 src1_sel:BYTE_0 ; 0c3040f9 0808061a
	v_add3_u32 v17, v17, v19, v25                               ; d1ff0011 04662711
	v_mul_i32_i24_sdwa v25, sext(v26), sext(v32) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 0c3240f9 0909061a
	v_mul_i32_i24_sdwa v26, sext(v26), sext(v32) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 0c3440f9 0b0b061a
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_cndmask_b32_e32 v32, v7, v6, vcc                          ; 00400d07
	v_cndmask_b32_e32 v7, v7, v5, vcc                           ; 000e0b07
	v_add_u32_e32 v29, v29, v30                                 ; 683a3d1d
	v_lshrrev_b32_e32 v5, v14, v5                               ; 200a0b0e
	v_lshrrev_b32_e32 v14, v14, v6                              ; 201c0d0e
	v_add_u32_e32 v24, v24, v25                                 ; 68303318
	v_cvt_f32_f16_e32 v33, v4                                   ; 7e421704
	v_bfe_u32 v32, v32, v15, 4                                  ; d1c80020 02121f20
	v_cvt_f32_f16_sdwa v4, v4 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e0816f9 00050604
	v_bfe_u32 v7, v7, v13, 4                                    ; d1c80007 02121b07
	v_add3_u32 v29, v29, v31, v11                               ; d1ff001d 042e3f1d
	v_add3_u32 v24, v24, v27, v26                               ; d1ff0018 046a3718
	v_and_or_b32 v14, 48, v14, v32                              ; d201000e 04821cb0
	v_and_or_b32 v5, 48, v5, v7                                 ; d2010005 041e0ab0
	v_add3_u32 v24, v24, v21, v17                               ; d1ff0018 04462b18
	v_cvt_f32_ubyte0_e32 v14, v14                               ; 7e1c230e
	v_cvt_f32_ubyte0_e32 v5, v5                                 ; 7e0a2305
	v_add_u32_e32 v29, v29, v24                                 ; 683a311d
	v_mul_f32_e32 v4, v4, v14                                   ; 0a081d04
	v_mul_f32_e32 v33, v33, v5                                  ; 0a420b21
	v_cvt_f32_i32_e32 v29, v29                                  ; 7e3a0b1d
	v_mul_f32_e32 v16, v16, v33                                 ; 0a204310
	v_mac_f32_e32 v20, v16, v29                                 ; 2c283b10
	v_mad_f32 v2, -v4, v28, v20                                 ; d1c10002 24523904
BB17:
	s_mov_b64 exec, -1                                          ; befe01c1
	v_cmpx_ne_i32_e32 vcc, 0, v3                                ; 7daa0680
	s_cbranch_execz BB23                                        ; bf880090
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
	v_mul_i32_i24_sdwa v32, sext(v14), sext(v10) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 0c4014f9 0909060e
	v_mul_i32_i24_sdwa v33, sext(v14), sext(v10) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 0c4214f9 0a0a060e
	v_mul_i32_i24_sdwa v14, sext(v14), sext(v10) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 0c1c14f9 0b0b060e
	v_add_u32_e32 v28, v28, v29                                 ; 68383b1c
	v_and_b32_e32 v20, s0, v20                                  ; 26282800
	v_add_u32_e32 v25, v25, v26                                 ; 68323519
	v_add_u32_e32 v31, v31, v32                                 ; 683e411f
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_cndmask_b32_e32 v3, v19, v18, vcc                         ; 00062513
	v_cndmask_b32_e32 v19, v19, v17, vcc                        ; 00262313
	v_add3_u32 v28, v28, v30, v12                               ; d1ff001c 04323d1c
	v_mul_i32_i24_sdwa v34, sext(v20), sext(v11) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 src1_sel:BYTE_0 ; 0c4416f9 08080614
	v_mul_i32_i24_sdwa v0, sext(v20), sext(v11) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 0c0016f9 09090614
	v_mul_i32_i24_sdwa v1, sext(v20), sext(v11) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 0c0216f9 0a0a0614
	v_mul_i32_i24_sdwa v20, sext(v20), sext(v11) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 0c2816f9 0b0b0614
	v_lshrrev_b32_e32 v17, v22, v17                             ; 20222316
	v_add3_u32 v25, v25, v27, v13                               ; d1ff0019 04363719
	v_add3_u32 v31, v31, v33, v14                               ; d1ff001f 043a431f
	v_bfe_u32 v3, v3, v23, 4                                    ; d1c80003 02122f03
	v_bfe_u32 v19, v19, v21, 4                                  ; d1c80013 02122b13
	v_lshrrev_b32_e32 v22, v22, v18                             ; 202c2516
	v_cvt_f32_f16_e32 v4, v16                                   ; 7e081710
	v_add_u32_e32 v34, v34, v0                                  ; 68440122
	v_cvt_f32_f16_sdwa v16, v16 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e2016f9 00050610
	v_add3_u32 v31, v31, v28, v25                               ; d1ff001f 0466391f
	v_and_or_b32 v17, 48, v17, v19                              ; d2010011 044e22b0
	v_and_or_b32 v22, 48, v22, v3                               ; d2010016 040e2cb0
	v_add3_u32 v34, v34, v1, v20                                ; d1ff0022 04520322
	v_cvt_f32_ubyte0_e32 v17, v17                               ; 7e222311
	v_cvt_f32_ubyte0_e32 v22, v22                               ; 7e2c2316
	v_add_u32_e32 v34, v34, v31                                 ; 68443f22
	v_mul_f32_e32 v4, v4, v17                                   ; 0a082304
	v_mul_f32_e32 v16, v16, v22                                 ; 0a202d10
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
	s_branch BB98                                               ; bf8204b1
BB36:
	s_cmp_lt_u32 s16, s4                                        ; bf0a0410
	s_cbranch_scc0 BB98                                         ; bf8404af
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
	s_cbranch_scc0 BB59                                         ; bf840247
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
	s_cbranch_scc0 BB49                                         ; bf84007e
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
	v_add_u32_e32 v28, v28, v29                                 ; 68383b1c
	v_and_b32_e32 v11, s5, v11                                  ; 26161605
	v_add_u32_e32 v34, v34, v4                                  ; 68440922
	v_add_u32_e32 v31, v31, v32                                 ; 683e411f
	v_add3_u32 v28, v28, v30, v17                               ; d1ff001c 04463d1c
	v_mul_i32_i24_sdwa v6, sext(v11), sext(v15) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 src1_sel:BYTE_0 ; 0c0c1ef9 0808060b
	v_mul_i32_i24_sdwa v10, sext(v11), sext(v15) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 0c141ef9 0a0a060b
	v_mul_i32_i24_sdwa v9, sext(v11), sext(v15) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 0c121ef9 0909060b
	v_mul_i32_i24_sdwa v11, sext(v11), sext(v15) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 0c161ef9 0b0b060b
	v_add3_u32 v34, v34, v5, v18                                ; d1ff0022 044a0b22
	v_add3_u32 v31, v31, v33, v16                               ; d1ff001f 0442431f
	v_add_u32_e32 v6, v6, v9                                    ; 680c1306
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_cvt_f32_f16_e32 v12, v20                                  ; 7e181714
	v_cvt_f32_f16_sdwa v20, v20 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e2816f9 00050614
	v_add3_u32 v34, v34, v31, v28                               ; d1ff0022 04723f22
	v_add3_u32 v6, v6, v10, v11                                 ; d1ff0006 042e1506
	v_cndmask_b32_e32 v11, v23, v22, vcc                        ; 00162d17
	v_cndmask_b32_e32 v23, v23, v21, vcc                        ; 002e2b17
	v_lshrrev_b32_e32 v21, v25, v21                             ; 202a2b19
	v_lshrrev_b32_e32 v25, v25, v22                             ; 20322d19
	v_add_u32_e32 v6, v6, v34                                   ; 680c4506
	v_bfe_u32 v11, v11, v26, 4                                  ; d1c8000b 0212350b
	v_bfe_u32 v23, v23, v24, 4                                  ; d1c80017 02123117
	v_cvt_f32_i32_e32 v6, v6                                    ; 7e0c0b06
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
	s_cbranch_scc0 BB52                                         ; bf84007e
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
	v_add_u32_e32 v28, v28, v29                                 ; 68383b1c
	v_and_b32_e32 v11, s5, v11                                  ; 26161605
	v_add_u32_e32 v34, v34, v4                                  ; 68440922
	v_add_u32_e32 v31, v31, v32                                 ; 683e411f
	v_add3_u32 v28, v28, v30, v17                               ; d1ff001c 04463d1c
	v_mul_i32_i24_sdwa v6, sext(v11), sext(v15) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 src1_sel:BYTE_0 ; 0c0c1ef9 0808060b
	v_mul_i32_i24_sdwa v10, sext(v11), sext(v15) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 0c141ef9 0a0a060b
	v_mul_i32_i24_sdwa v7, sext(v11), sext(v15) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 0c0e1ef9 0909060b
	v_mul_i32_i24_sdwa v11, sext(v11), sext(v15) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 0c161ef9 0b0b060b
	v_add3_u32 v34, v34, v5, v18                                ; d1ff0022 044a0b22
	v_add3_u32 v31, v31, v33, v16                               ; d1ff001f 0442431f
	v_add_u32_e32 v6, v6, v7                                    ; 680c0f06
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_cvt_f32_f16_e32 v12, v20                                  ; 7e181714
	v_cvt_f32_f16_sdwa v20, v20 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e2816f9 00050614
	v_add3_u32 v34, v34, v31, v28                               ; d1ff0022 04723f22
	v_add3_u32 v6, v6, v10, v11                                 ; d1ff0006 042e1506
	v_cndmask_b32_e32 v11, v23, v22, vcc                        ; 00162d17
	v_cndmask_b32_e32 v23, v23, v21, vcc                        ; 002e2b17
	v_lshrrev_b32_e32 v21, v25, v21                             ; 202a2b19
	v_lshrrev_b32_e32 v25, v25, v22                             ; 20322d19
	v_add_u32_e32 v6, v6, v34                                   ; 680c4506
	v_bfe_u32 v11, v11, v26, 4                                  ; d1c8000b 0212350b
	v_bfe_u32 v23, v23, v24, 4                                  ; d1c80017 02123117
	v_cvt_f32_i32_e32 v6, v6                                    ; 7e0c0b06
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
	s_cbranch_scc0 BB55                                         ; bf84007e
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
	v_add_u32_e32 v28, v28, v29                                 ; 68383b1c
	v_and_b32_e32 v11, s5, v11                                  ; 26161605
	v_add_u32_e32 v34, v34, v4                                  ; 68440922
	v_add_u32_e32 v31, v31, v32                                 ; 683e411f
	v_add3_u32 v28, v28, v30, v17                               ; d1ff001c 04463d1c
	v_mul_i32_i24_sdwa v6, sext(v11), sext(v15) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 src1_sel:BYTE_0 ; 0c0c1ef9 0808060b
	v_mul_i32_i24_sdwa v10, sext(v11), sext(v15) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 0c141ef9 0a0a060b
	v_mul_i32_i24_sdwa v7, sext(v11), sext(v15) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 0c0e1ef9 0909060b
	v_mul_i32_i24_sdwa v11, sext(v11), sext(v15) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 0c161ef9 0b0b060b
	v_add3_u32 v34, v34, v5, v18                                ; d1ff0022 044a0b22
	v_add3_u32 v31, v31, v33, v16                               ; d1ff001f 0442431f
	v_add_u32_e32 v6, v6, v7                                    ; 680c0f06
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_cvt_f32_f16_e32 v12, v20                                  ; 7e181714
	v_cvt_f32_f16_sdwa v20, v20 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e2816f9 00050614
	v_add3_u32 v34, v34, v31, v28                               ; d1ff0022 04723f22
	v_add3_u32 v6, v6, v10, v11                                 ; d1ff0006 042e1506
	v_cndmask_b32_e32 v11, v23, v22, vcc                        ; 00162d17
	v_cndmask_b32_e32 v23, v23, v21, vcc                        ; 002e2b17
	v_lshrrev_b32_e32 v21, v25, v21                             ; 202a2b19
	v_lshrrev_b32_e32 v25, v25, v22                             ; 20322d19
	v_add_u32_e32 v6, v6, v34                                   ; 680c4506
	v_bfe_u32 v11, v11, v26, 4                                  ; d1c8000b 0212350b
	v_bfe_u32 v23, v23, v24, 4                                  ; d1c80017 02123117
	v_cvt_f32_i32_e32 v6, v6                                    ; 7e0c0b06
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
	s_cbranch_scc0 BB58                                         ; bf84007e
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
	v_mul_i32_i24_sdwa v30, sext(v16), sext(v12) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 src1_sel:BYTE_0 ; 0c3c18f9 08080610
	v_mul_i32_i24_sdwa v32, sext(v16), sext(v12) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 0c4018f9 0a0a0610
	v_mul_i32_i24_sdwa v31, sext(v16), sext(v12) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 0c3e18f9 09090610
	v_mul_i32_i24_sdwa v16, sext(v16), sext(v12) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 0c2018f9 0b0b0610
	v_add_u32_e32 v27, v27, v28                                 ; 6836391b
	v_and_b32_e32 v10, s4, v10                                  ; 26141404
	v_add_u32_e32 v33, v33, v34                                 ; 68424521
	v_mul_i32_i24_sdwa v34, sext(v18), sext(v14) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 0c441cf9 0a0a0612
	v_mul_i32_i24_sdwa v18, sext(v18), sext(v14) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 0c241cf9 0b0b0612
	v_add_u32_e32 v30, v30, v31                                 ; 683c3f1e
	v_add3_u32 v27, v27, v29, v17                               ; d1ff001b 04463b1b
	v_mul_i32_i24_sdwa v4, sext(v10), sext(v15) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 0c081ef9 0909060a
	v_mul_i32_i24_sdwa v5, sext(v10), sext(v15) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 0c0a1ef9 0a0a060a
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_cndmask_b32_e32 v6, v23, v22, vcc                         ; 000c2d17
	v_cndmask_b32_e32 v23, v23, v21, vcc                        ; 002e2b17
	v_add3_u32 v33, v33, v34, v18                               ; d1ff0021 044a4521
	v_mul_i32_i24_sdwa v34, sext(v10), sext(v15) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 src1_sel:BYTE_0 ; 0c441ef9 0808060a
	v_mul_i32_i24_sdwa v10, sext(v10), sext(v15) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 0c141ef9 0b0b060a
	v_lshrrev_b32_e32 v21, v24, v21                             ; 202a2b18
	v_add3_u32 v30, v30, v32, v16                               ; d1ff001e 0442411e
	v_lshrrev_b32_e32 v24, v24, v22                             ; 20302d18
	v_bfe_u32 v6, v6, v25, 4                                    ; d1c80006 02123306
	v_bfe_u32 v23, v23, v11, 4                                  ; d1c80017 02121717
	v_cvt_f32_f16_e32 v7, v20                                   ; 7e0e1714
	v_add_u32_e32 v34, v34, v4                                  ; 68440922
	v_cvt_f32_f16_sdwa v20, v20 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e2816f9 00050614
	v_add3_u32 v33, v33, v30, v27                               ; d1ff0021 046e3d21
	v_and_or_b32 v24, 48, v24, v6                               ; d2010018 041a30b0
	v_and_or_b32 v21, 48, v21, v23                              ; d2010015 045e2ab0
	v_add3_u32 v34, v34, v5, v10                                ; d1ff0022 042a0b22
	v_cvt_f32_ubyte0_e32 v24, v24                               ; 7e302318
	v_cvt_f32_ubyte0_e32 v21, v21                               ; 7e2a2315
	v_add_u32_e32 v34, v34, v33                                 ; 68444322
	v_mul_f32_e32 v20, v20, v24                                 ; 0a283114
	v_mul_f32_e32 v7, v7, v21                                   ; 0a0e2b07
	v_cvt_f32_i32_e32 v34, v34                                  ; 7e440b22
	v_mul_f32_e32 v26, v26, v7                                  ; 0a340f1a
	v_mac_f32_e32 v2, v26, v34                                  ; 2c04451a
	v_mad_f32 v2, -v20, v9, v2                                  ; d1c10002 240a1314
BB58:
	v_add_u32_e32 v3, -4, v3                                    ; 680606c4
	v_add_u32_e32 v1, 0x1000, v1                                ; 680202ff 00001000
	s_branch BB41                                               ; bf82fdb4
BB59:
	s_mov_b64 exec, -1                                          ; befe01c1
	v_cmpx_le_u32_e32 vcc, 2, v3                                ; 7db60682
	s_cbranch_execz BB71                                        ; bf880128
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
	s_cbranch_scc0 BB63                                         ; bf84007e
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
	v_add_u32_e32 v28, v28, v29                                 ; 68383b1c
	v_and_b32_e32 v11, s5, v11                                  ; 26161605
	v_add_u32_e32 v34, v34, v4                                  ; 68440922
	v_add_u32_e32 v31, v31, v32                                 ; 683e411f
	v_add3_u32 v28, v28, v30, v17                               ; d1ff001c 04463d1c
	v_mul_i32_i24_sdwa v6, sext(v11), sext(v15) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 src1_sel:BYTE_0 ; 0c0c1ef9 0808060b
	v_mul_i32_i24_sdwa v10, sext(v11), sext(v15) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 0c141ef9 0a0a060b
	v_mul_i32_i24_sdwa v9, sext(v11), sext(v15) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 0c121ef9 0909060b
	v_mul_i32_i24_sdwa v11, sext(v11), sext(v15) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 0c161ef9 0b0b060b
	v_add3_u32 v34, v34, v5, v18                                ; d1ff0022 044a0b22
	v_add3_u32 v31, v31, v33, v16                               ; d1ff001f 0442431f
	v_add_u32_e32 v6, v6, v9                                    ; 680c1306
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_cvt_f32_f16_e32 v12, v20                                  ; 7e181714
	v_cvt_f32_f16_sdwa v20, v20 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e2816f9 00050614
	v_add3_u32 v34, v34, v31, v28                               ; d1ff0022 04723f22
	v_add3_u32 v6, v6, v10, v11                                 ; d1ff0006 042e1506
	v_cndmask_b32_e32 v11, v23, v22, vcc                        ; 00162d17
	v_cndmask_b32_e32 v23, v23, v21, vcc                        ; 002e2b17
	v_lshrrev_b32_e32 v21, v25, v21                             ; 202a2b19
	v_lshrrev_b32_e32 v25, v25, v22                             ; 20322d19
	v_add_u32_e32 v6, v6, v34                                   ; 680c4506
	v_bfe_u32 v11, v11, v26, 4                                  ; d1c8000b 0212350b
	v_bfe_u32 v23, v23, v24, 4                                  ; d1c80017 02123117
	v_cvt_f32_i32_e32 v6, v6                                    ; 7e0c0b06
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
	s_cbranch_scc0 BB66                                         ; bf84007e
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
	v_mul_i32_i24_sdwa v30, sext(v16), sext(v12) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 src1_sel:BYTE_0 ; 0c3c18f9 08080610
	v_mul_i32_i24_sdwa v32, sext(v16), sext(v12) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 0c4018f9 0a0a0610
	v_mul_i32_i24_sdwa v31, sext(v16), sext(v12) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 0c3e18f9 09090610
	v_mul_i32_i24_sdwa v16, sext(v16), sext(v12) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 0c2018f9 0b0b0610
	v_add_u32_e32 v27, v27, v28                                 ; 6836391b
	v_and_b32_e32 v10, s4, v10                                  ; 26141404
	v_add_u32_e32 v33, v33, v34                                 ; 68424521
	v_mul_i32_i24_sdwa v34, sext(v18), sext(v14) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 0c441cf9 0a0a0612
	v_mul_i32_i24_sdwa v18, sext(v18), sext(v14) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 0c241cf9 0b0b0612
	v_add_u32_e32 v30, v30, v31                                 ; 683c3f1e
	v_add3_u32 v27, v27, v29, v17                               ; d1ff001b 04463b1b
	v_mul_i32_i24_sdwa v4, sext(v10), sext(v15) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 0c081ef9 0909060a
	v_mul_i32_i24_sdwa v5, sext(v10), sext(v15) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 0c0a1ef9 0a0a060a
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_cndmask_b32_e32 v6, v23, v22, vcc                         ; 000c2d17
	v_cndmask_b32_e32 v23, v23, v21, vcc                        ; 002e2b17
	v_add3_u32 v33, v33, v34, v18                               ; d1ff0021 044a4521
	v_mul_i32_i24_sdwa v34, sext(v10), sext(v15) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 src1_sel:BYTE_0 ; 0c441ef9 0808060a
	v_mul_i32_i24_sdwa v10, sext(v10), sext(v15) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 0c141ef9 0b0b060a
	v_lshrrev_b32_e32 v21, v24, v21                             ; 202a2b18
	v_add3_u32 v30, v30, v32, v16                               ; d1ff001e 0442411e
	v_lshrrev_b32_e32 v24, v24, v22                             ; 20302d18
	v_bfe_u32 v6, v6, v25, 4                                    ; d1c80006 02123306
	v_bfe_u32 v23, v23, v11, 4                                  ; d1c80017 02121717
	v_cvt_f32_f16_e32 v7, v20                                   ; 7e0e1714
	v_add_u32_e32 v34, v34, v4                                  ; 68440922
	v_cvt_f32_f16_sdwa v20, v20 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e2816f9 00050614
	v_add3_u32 v33, v33, v30, v27                               ; d1ff0021 046e3d21
	v_and_or_b32 v24, 48, v24, v6                               ; d2010018 041a30b0
	v_and_or_b32 v21, 48, v21, v23                              ; d2010015 045e2ab0
	v_add3_u32 v34, v34, v5, v10                                ; d1ff0022 042a0b22
	v_cvt_f32_ubyte0_e32 v24, v24                               ; 7e302318
	v_cvt_f32_ubyte0_e32 v21, v21                               ; 7e2a2315
	v_add_u32_e32 v34, v34, v33                                 ; 68444322
	v_mul_f32_e32 v20, v20, v24                                 ; 0a283114
	v_mul_f32_e32 v7, v7, v21                                   ; 0a0e2b07
	v_cvt_f32_i32_e32 v34, v34                                  ; 7e440b22
	v_mul_f32_e32 v26, v26, v7                                  ; 0a340f1a
	v_mac_f32_e32 v2, v26, v34                                  ; 2c04451a
	v_mad_f32 v2, -v20, v9, v2                                  ; d1c10002 240a1314
BB66:
	v_add_u32_e32 v3, -2, v3                                    ; 680606c2
	v_add_u32_e32 v1, 0x800, v1                                 ; 680202ff 00000800
	s_mov_b32 s5, src_scc                                       ; be8500fd
BB71:
	s_mov_b64 exec, -1                                          ; befe01c1
	v_cmpx_ne_i32_e32 vcc, 0, v3                                ; 7daa0680
	s_cbranch_execz BB80                                        ; bf880096
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
	s_cbranch_scc0 BB75                                         ; bf84007e
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
	v_add_u32_e32 v25, v25, v26                                 ; 68323519
	v_and_b32_e32 v20, s3, v20                                  ; 26282803
	v_add_u32_e32 v31, v31, v32                                 ; 683e411f
	v_add_u32_e32 v28, v28, v29                                 ; 68383b1c
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_cndmask_b32_e32 v3, v19, v18, vcc                         ; 00062513
	v_cndmask_b32_e32 v19, v19, v17, vcc                        ; 00262313
	v_add3_u32 v25, v25, v27, v13                               ; d1ff0019 04363719
	v_mul_i32_i24_sdwa v34, sext(v20), sext(v11) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 src1_sel:BYTE_0 ; 0c4416f9 08080614
	v_mul_i32_i24_sdwa v1, sext(v20), sext(v11) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 0c0216f9 0a0a0614
	v_mul_i32_i24_sdwa v0, sext(v20), sext(v11) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 0c0016f9 09090614
	v_mul_i32_i24_sdwa v20, sext(v20), sext(v11) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 0c2816f9 0b0b0614
	v_add3_u32 v31, v31, v33, v14                               ; d1ff001f 043a431f
	v_lshrrev_b32_e32 v17, v22, v17                             ; 20222316
	v_add3_u32 v28, v28, v30, v12                               ; d1ff001c 04323d1c
	v_bfe_u32 v3, v3, v23, 4                                    ; d1c80003 02122f03
	v_lshrrev_b32_e32 v22, v22, v18                             ; 202c2516
	v_bfe_u32 v19, v19, v21, 4                                  ; d1c80013 02122b13
	v_cvt_f32_f16_e32 v4, v16                                   ; 7e081710
	v_add_u32_e32 v34, v34, v0                                  ; 68440122
	v_cvt_f32_f16_sdwa v16, v16 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e2016f9 00050610
	v_add3_u32 v31, v31, v28, v25                               ; d1ff001f 0466391f
	v_and_or_b32 v22, 48, v22, v3                               ; d2010016 040e2cb0
	v_and_or_b32 v17, 48, v17, v19                              ; d2010011 044e22b0
	v_add3_u32 v34, v34, v1, v20                                ; d1ff0022 04520322
	v_cvt_f32_ubyte0_e32 v22, v22                               ; 7e2c2316
	v_cvt_f32_ubyte0_e32 v17, v17                               ; 7e222311
	v_add_u32_e32 v34, v34, v31                                 ; 68443f22
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
