BB0:
	s_load_dword s0, s[14:15], 0x0                              ; c0020007 00000000
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_mul_i32 s0, s0, s18                                       ; 92001200
	s_add_u32 s16, s16, s0                                      ; 80100010
	s_add_u32 s1, s16, 1                                        ; 80018110
	s_cmp_ge_u32 s4, s1                                         ; bf090104
	s_cbranch_scc0 BB36                                         ; bf840599
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
	s_branch BB5                                                ; bf8202d1
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
	v_lshrrev_b32_e32 v24, 5, v24                               ; 20303085
	v_add_u32_e32 v24, s18, v24                                 ; 68303012
	v_and_b32_e32 v29, 7, v24                                   ; 263a3087
	v_lshrrev_b32_e32 v24, 3, v24                               ; 20303083
	v_lshl_add_u32 v29, v29, 3, v8                              ; d1fd001d 0421071d
	v_lshlrev_b32_e32 v5, 4, v24                                ; 240a3084
	v_and_b32_e32 v34, 7, v29                                   ; 26443a87
	v_lshrrev_b32_e32 v4, 4, v29                                ; 20083a84
	v_lshl_add_u32 v24, v24, 7, v5                              ; d1fd0018 04150f18
	v_lshl_add_u32 v4, v4, 3, v34                               ; d1fd0004 04890704
	v_lshlrev_b32_e32 v4, 2, v4                                 ; 24080882
	v_add3_u32 v4, v4, 16, v24                                  ; d1ff0004 04612104
	s_waitcnt vmcnt(5)                                          ; bf8c3f75
	v_mov_b32_e32 v9, v7                                        ; 7e120307
	buffer_load_dwordx4 v[4:7], v4, s[24:27], 0 offen           ; e05c1000 80060404
	v_bfe_u32 v11, v10, 3, 1                                    ; d1c8000b 0205070a
	v_lshrrev_b32_e32 v10, 3, v10                               ; 20141483
	s_mov_b32 s1, 0x80808080                                    ; be8100ff 80808080
	s_mov_b32 s4, 0xf0f0f0f                                     ; be8400ff 0f0f0f0f
	v_lshlrev_b32_e32 v11, 2, v11                               ; 24161682
	v_and_b32_e32 v25, 3, v10                                   ; 26321483
	v_cmp_gt_u32_e32 vcc, 4, v10                                ; 7d981484
	s_waitcnt vmcnt(5)                                          ; bf8c3f75
	v_xor_b32_e32 v13, s1, v13                                  ; 2a1a1a01
	v_xor_b32_e32 v15, s1, v15                                  ; 2a1e1e01
	v_xor_b32_e32 v12, s1, v12                                  ; 2a181801
	v_xor_b32_e32 v14, s1, v14                                  ; 2a1c1c01
	v_lshlrev_b32_e32 v25, 3, v25                               ; 24323283
	v_add_u32_e32 v27, 4, v25                                   ; 68363284
	v_add_u32_e32 v26, 2, v25                                   ; 68343282
	v_cndmask_b32_e32 v27, v27, v25, vcc                        ; 0036331b
	v_cndmask_b32_e32 v26, v26, v25, vcc                        ; 0034331a
	s_waitcnt vmcnt(4)                                          ; bf8c3f74
	v_lshrrev_b32_e32 v18, v11, v18                             ; 2024250b
	v_lshrrev_b32_e32 v16, v11, v16                             ; 2020210b
	v_lshrrev_b32_e32 v17, v11, v17                             ; 2022230b
	v_lshrrev_b32_e32 v11, v11, v19                             ; 2016270b
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_cndmask_b32_e32 v34, v23, v22, vcc                        ; 00442d17
	v_cndmask_b32_e32 v23, v23, v21, vcc                        ; 002e2b17
	v_lshrrev_b32_e32 v21, v26, v21                             ; 202a2b1a
	v_lshrrev_b32_e32 v26, v26, v22                             ; 20342d1a
	v_and_b32_e32 v10, 15, v16                                  ; 2614208f
	v_and_b32_e32 v16, s4, v16                                  ; 26202004
	v_bfe_u32 v34, v34, v27, 4                                  ; d1c80022 02123722
	v_bfe_u32 v23, v23, v25, 4                                  ; d1c80017 02123317
	v_mul_u32_u24_sdwa v19, v10, v12 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_0 ; 102618f9 0006060a
	v_mul_u32_u24_sdwa v22, v16, v12 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 102c18f9 02020610
	v_and_or_b32 v26, 48, v26, v34                              ; d201001a 048a34b0
	v_cvt_f32_f16_e32 v34, v20                                  ; 7e441714
	v_cvt_f32_f16_sdwa v20, v20 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e2816f9 00050614
	v_and_or_b32 v21, 48, v21, v23                              ; d2010015 045e2ab0
	v_and_b32_e32 v23, 15, v17                                  ; 262e228f
	v_and_b32_e32 v17, s4, v17                                  ; 26222204
	v_cvt_f32_ubyte0_e32 v26, v26                               ; 7e34231a
	v_cvt_f32_ubyte0_e32 v21, v21                               ; 7e2a2315
	v_mul_u32_u24_sdwa v25, v23, v13 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_0 ; 10321af9 00060617
	v_mul_u32_u24_sdwa v27, v17, v13 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 10361af9 02020611
	v_mul_f32_e32 v20, v20, v26                                 ; 0a283514
	v_mul_u32_u24_sdwa v26, v17, v13 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 10341af9 01010611
	v_mul_u32_u24_sdwa v13, v17, v13 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 101a1af9 03030611
	v_mul_f32_e32 v34, v34, v21                                 ; 0a442b22
	v_mul_u32_u24_sdwa v21, v16, v12 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 102a18f9 01010610
	v_mul_u32_u24_sdwa v12, v16, v12 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 101818f9 03030610
	v_add3_u32 v22, v22, v19, v21                               ; d1ff0016 04562716
	v_add3_u32 v25, v25, v22, v12                               ; d1ff0019 04322d19
	v_and_b32_e32 v12, 15, v18                                  ; 2618248f
	v_and_b32_e32 v18, s4, v18                                  ; 26242404
	v_add3_u32 v27, v27, v25, v26                               ; d1ff001b 046a331b
	v_and_b32_e32 v25, 15, v11                                  ; 2632168f
	v_and_b32_e32 v11, s4, v11                                  ; 26161604
	v_mul_u32_u24_sdwa v19, v12, v14 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_0 ; 10261cf9 0006060c
	v_mul_u32_u24_sdwa v21, v18, v14 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 102a1cf9 01010612
	v_mul_u32_u24_sdwa v22, v18, v14 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 102c1cf9 02020612
	v_mul_u32_u24_sdwa v14, v18, v14 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 101c1cf9 03030612
	v_mul_u32_u24_sdwa v26, v25, v15 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_0 ; 10341ef9 00060619
	v_add3_u32 v19, v19, v27, v13                               ; d1ff0013 04363713
	v_mul_u32_u24_sdwa v13, v11, v15 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 101a1ef9 0202060b
	v_mul_u32_u24_sdwa v27, v11, v15 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 10361ef9 0101060b
	v_add3_u32 v22, v22, v19, v21                               ; d1ff0016 04562716
	v_add3_u32 v26, v26, v22, v14                               ; d1ff001a 043a2d1a
	v_mov_b32_e32 v14, v25                                      ; 7e1c0319
	v_add3_u32 v13, v13, v26, v27                               ; d1ff000d 046e350d
	buffer_load_dwordx4 v[24:27], v24, s[24:27], 0 offen        ; e05c1000 80061818
	v_add_u32_sdwa v10, v10, v16 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_1 ; 681420f9 0106060a
	v_mul_u32_u24_sdwa v15, v11, v15 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 101e1ef9 0303060b
	v_add_u32_sdwa v10, v10, v16 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_2 ; 681420f9 0206060a
	v_add_u32_e32 v13, v13, v15                                 ; 681a1f0d
	v_add_u32_e32 v15, 0x800, v1                                ; 681e02ff 00000800
	v_add_u32_sdwa v10, v10, v16 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_3 ; 681420f9 0306060a
	v_lshrrev_b32_e32 v16, 5, v15                               ; 20201e85
	v_add_u32_e32 v16, s6, v16                                  ; 68202006
	v_add_u32_e32 v10, v10, v23                                 ; 68142f0a
	v_and_b32_e32 v19, 3, v16                                   ; 26262083
	v_lshrrev_b32_e32 v16, 2, v16                               ; 20202082
	v_add_u32_sdwa v10, v10, v17 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_1 ; 681422f9 0106060a
	v_lshlrev_b32_e32 v21, 4, v16                               ; 242a2084
	v_add_u32_sdwa v10, v10, v17 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_2 ; 681422f9 0206060a
	v_lshl_add_u32 v16, v16, 7, v21                             ; d1fd0010 04550f10
	v_add_u32_sdwa v10, v10, v17 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_3 ; 681422f9 0306060a
	v_lshl_add_u32 v22, v19, 2, v16                             ; d1fd0016 04410513
	v_lshl_add_u32 v19, v19, 3, v8                              ; d1fd0013 04210713
	v_add_u32_e32 v10, v10, v12                                 ; 6814190a
	v_mov_b32_e32 v12, v18                                      ; 7e180312
	v_lshlrev_b32_e32 v19, 2, v19                               ; 24262682
	v_add3_u32 v19, v19, 16, v16                                ; d1ff0013 04412113
	buffer_load_dword v22, v22, s[28:31], 0 offen               ; e0501000 80071616
	buffer_load_dwordx4 v[16:19], v19, s[28:31], 0 offen        ; e05c1000 80071013
	v_add_u32_sdwa v10, v10, v12 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_1 ; 681418f9 0106060a
	v_bfe_u32 v21, v29, 3, 1                                    ; d1c80015 0205071d
	v_lshrrev_b32_e32 v29, 3, v29                               ; 203a3a83
	v_add_u32_sdwa v10, v10, v12 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_2 ; 681418f9 0206060a
	v_lshlrev_b32_e32 v21, 2, v21                               ; 242a2a82
	v_and_b32_e32 v23, 3, v29                                   ; 262e3a83
	v_add_u32_sdwa v10, v10, v12 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_3 ; 681418f9 0306060a
	v_cmp_gt_u32_e32 vcc, 4, v29                                ; 7d983a84
	v_lshlrev_b32_e32 v23, 3, v23                               ; 242e2e83
	v_add_u32_e32 v10, v10, v14                                 ; 68141d0a
	v_cvt_f32_f16_e32 v14, v9                                   ; 7e1c1709
	v_cvt_f32_f16_sdwa v9, v9 div:2 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e1216f9 0005c609
	v_add_u32_e32 v15, s0, v15                                  ; 681e1e00
	v_add_u32_e32 v29, 4, v23                                   ; 683a2e84
	v_add_u32_sdwa v10, v10, v11 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_1 ; 681416f9 0106060a
	v_mul_f32_e32 v14, v14, v34                                 ; 0a1c450e
	v_add_u32_e32 v34, 2, v23                                   ; 68442e82
	v_lshrrev_b32_e32 v15, 5, v15                               ; 201e1e85
	v_cndmask_b32_e32 v29, v29, v23, vcc                        ; 003a2f1d
	v_add_u32_sdwa v10, v10, v11 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_2 ; 681416f9 0206060a
	v_cndmask_b32_e32 v34, v34, v23, vcc                        ; 00442f22
	v_add_u32_e32 v15, s18, v15                                 ; 681e1e12
	v_add_u32_sdwa v10, v10, v11 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_3 ; 681416f9 0306060a
	s_waitcnt vmcnt(5)                                          ; bf8c3f75
	v_cvt_f32_f16_e32 v11, v28                                  ; 7e16171c
	v_cvt_f32_f16_sdwa v28, v28 div:2 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e3816f9 0005c61c
	v_lshlrev_b32_e32 v10, 7, v10                               ; 24141487
	s_waitcnt vmcnt(4)                                          ; bf8c3f74
	v_xor_b32_e32 v30, s1, v30                                  ; 2a3c3c01
	v_xor_b32_e32 v31, s1, v31                                  ; 2a3e3e01
	v_xor_b32_e32 v32, s1, v32                                  ; 2a404001
	v_xor_b32_e32 v33, s1, v33                                  ; 2a424201
	v_sub_u32_e32 v13, v13, v10                                 ; 6a1a150d
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_lshrrev_b32_e32 v4, v21, v4                               ; 20080915
	v_lshrrev_b32_e32 v5, v21, v5                               ; 200a0b15
	v_lshrrev_b32_e32 v6, v21, v6                               ; 200c0d15
	v_lshrrev_b32_e32 v21, v21, v7                              ; 202a0f15
	v_cvt_f32_i32_e32 v13, v13                                  ; 7e1a0b0d
	v_mac_f32_e32 v2, v14, v13                                  ; 2c041b0e
	v_and_b32_e32 v13, 15, v4                                   ; 261a088f
	v_and_b32_e32 v4, s4, v4                                    ; 26080804
	v_mad_f32 v20, -v20, v9, v2                                 ; d1c10014 240a1314
	v_and_b32_e32 v2, 7, v15                                    ; 26041e87
	v_lshrrev_b32_e32 v15, 3, v15                               ; 201e1e83
	v_mul_u32_u24_sdwa v14, v13, v30 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_0 ; 101c3cf9 0006060d
	v_lshl_add_u32 v2, v2, 3, v8                                ; d1fd0002 04210702
	v_lshlrev_b32_e32 v12, 4, v15                               ; 24181e84
	v_and_b32_e32 v9, 7, v2                                     ; 26120487
	v_lshrrev_b32_e32 v10, 4, v2                                ; 20140484
	v_lshl_add_u32 v15, v15, 7, v12                             ; d1fd000f 04310f0f
	v_lshl_add_u32 v10, v10, 3, v9                              ; d1fd000a 0425070a
	v_lshlrev_b32_e32 v10, 2, v10                               ; 24141482
	v_mul_u32_u24_sdwa v12, v4, v30 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 10183cf9 01010604
	v_add3_u32 v10, v10, 16, v15                                ; d1ff000a 043d210a
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_cvt_f32_f16_e32 v9, v24                                   ; 7e121718
	v_cvt_f32_f16_sdwa v24, v24 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e3016f9 00050618
	v_cndmask_b32_e32 v7, v27, v26, vcc                         ; 000e351b
	v_cndmask_b32_e32 v27, v27, v25, vcc                        ; 0036331b
	v_lshrrev_b32_e32 v25, v34, v25                             ; 20323322
	v_lshrrev_b32_e32 v34, v34, v26                             ; 20443522
	v_bfe_u32 v7, v7, v29, 4                                    ; d1c80007 02123b07
	v_bfe_u32 v27, v27, v23, 4                                  ; d1c8001b 02122f1b
	v_mul_u32_u24_sdwa v23, v4, v30 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 102e3cf9 02020604
	v_mul_u32_u24_sdwa v30, v4, v30 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 103c3cf9 03030604
	v_and_or_b32 v34, 48, v34, v7                               ; d2010022 041e44b0
	v_and_or_b32 v25, 48, v25, v27                              ; d2010019 046e32b0
	v_add3_u32 v23, v23, v14, v12                               ; d1ff0017 04321d17
	v_cvt_f32_ubyte0_e32 v34, v34                               ; 7e442322
	v_cvt_f32_ubyte0_e32 v25, v25                               ; 7e322319
	v_mul_f32_e32 v24, v24, v34                                 ; 0a304518
	v_mul_f32_e32 v9, v9, v25                                   ; 0a123309
	v_and_b32_e32 v25, 15, v5                                   ; 26320a8f
	v_and_b32_e32 v5, s4, v5                                    ; 260a0a04
	v_and_b32_e32 v12, 15, v21                                  ; 26182a8f
	v_mul_u32_u24_sdwa v26, v25, v31 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_0 ; 10343ef9 00060619
	v_mul_u32_u24_sdwa v29, v5, v31 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 103a3ef9 02020605
	v_mul_u32_u24_sdwa v27, v5, v31 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 10363ef9 01010605
	v_mul_u32_u24_sdwa v31, v5, v31 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 103e3ef9 03030605
	v_mul_u32_u24_sdwa v14, v12, v33 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_0 ; 101c42f9 0006060c
	v_and_b32_e32 v21, s4, v21                                  ; 262a2a04
	v_add3_u32 v26, v26, v23, v30                               ; d1ff001a 047a2f1a
	v_and_b32_e32 v30, 15, v6                                   ; 263c0c8f
	v_and_b32_e32 v6, s4, v6                                    ; 260c0c04
	v_add3_u32 v29, v29, v26, v27                               ; d1ff001d 046e351d
	v_mov_b32_e32 v27, v30                                      ; 7e36031e
	v_mul_u32_u24_sdwa v34, v30, v32 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_0 ; 104440f9 0006061e
	v_mul_u32_u24_sdwa v7, v6, v32 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 100e40f9 02020606
	v_add3_u32 v34, v34, v29, v31                               ; d1ff0022 047e3b22
	v_mul_u32_u24_sdwa v31, v6, v32 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 103e40f9 01010606
	v_mul_u32_u24_sdwa v32, v6, v32 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 104040f9 03030606
	v_add3_u32 v7, v7, v34, v31                                 ; d1ff0007 047e4507
	v_add3_u32 v14, v14, v7, v32                                ; d1ff000e 04820f0e
	buffer_load_dwordx4 v[29:32], v10, s[24:27], 0 offen        ; e05c1000 80061d0a
	v_mul_u32_u24_sdwa v23, v21, v33 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 102e42f9 01010615
	v_mov_b32_e32 v7, v12                                       ; 7e0e030c
	v_mul_u32_u24_sdwa v26, v21, v33 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 103442f9 02020615
	v_mov_b32_e32 v10, v13                                      ; 7e14030d
	v_add3_u32 v26, v26, v14, v23                               ; d1ff001a 045e1d1a
	buffer_load_dwordx4 v[12:15], v15, s[24:27], 0 offen        ; e05c1000 80060c0f
	v_mul_u32_u24_sdwa v33, v21, v33 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 104242f9 03030615
	v_add_u32_e32 v23, 0xc00, v1                                ; 682e02ff 00000c00
	v_add_u32_sdwa v10, v10, v4 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_1 ; 681408f9 0106060a
	v_add_u32_e32 v26, v26, v33                                 ; 6834431a
	v_add_u32_sdwa v10, v10, v4 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_2 ; 681408f9 0206060a
	v_add_u32_sdwa v10, v10, v4 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_3 ; 681408f9 0306060a
	v_add_u32_e32 v10, v10, v25                                 ; 6814330a
	v_lshrrev_b32_e32 v25, 5, v23                               ; 20322e85
	v_add_u32_sdwa v10, v10, v5 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_1 ; 68140af9 0106060a
	v_add_u32_e32 v25, s6, v25                                  ; 68323206
	v_and_b32_e32 v33, 3, v25                                   ; 26423283
	v_add_u32_sdwa v10, v10, v5 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_2 ; 68140af9 0206060a
	v_lshrrev_b32_e32 v25, 2, v25                               ; 20323282
	v_add_u32_sdwa v10, v10, v5 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_3 ; 68140af9 0306060a
	v_lshlrev_b32_e32 v34, 4, v25                               ; 24443284
	v_add_u32_e32 v10, v10, v27                                 ; 6814370a
	v_lshl_add_u32 v25, v25, 7, v34                             ; d1fd0019 04890f19
	v_add_u32_sdwa v10, v10, v6 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_1 ; 68140cf9 0106060a
	v_lshl_add_u32 v34, v33, 2, v25                             ; d1fd0022 04650521
	v_lshl_add_u32 v33, v33, 3, v8                              ; d1fd0021 04210721
	v_add_u32_sdwa v10, v10, v6 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_2 ; 68140cf9 0206060a
	v_lshlrev_b32_e32 v33, 2, v33                               ; 24424282
	v_add_u32_sdwa v10, v10, v6 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_3 ; 68140cf9 0306060a
	v_add3_u32 v33, v33, 16, v25                                ; d1ff0021 04652121
	v_mov_b32_e32 v25, v7                                       ; 7e320307
	buffer_load_dword v34, v34, s[28:31], 0 offen               ; e0501000 80072222
	buffer_load_dwordx4 v[4:7], v33, s[28:31], 0 offen          ; e05c1000 80070421
	v_mul_f32_e32 v11, v11, v9                                  ; 0a16130b
	v_add_u32_e32 v23, s0, v23                                  ; 682e2e00
	v_add_u32_e32 v10, v10, v25                                 ; 6814330a
	v_lshrrev_b32_e32 v23, 5, v23                               ; 202e2e85
	v_add_u32_sdwa v10, v10, v21 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_1 ; 68142af9 0106060a
	v_add_u32_e32 v23, s18, v23                                 ; 682e2e12
	v_add_u32_sdwa v10, v10, v21 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_2 ; 68142af9 0206060a
	v_and_b32_e32 v27, 7, v23                                   ; 26362e87
	v_lshrrev_b32_e32 v23, 3, v23                               ; 202e2e83
	v_add_u32_sdwa v10, v10, v21 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_3 ; 68142af9 0306060a
	v_mov_b32_e32 v21, v11                                      ; 7e2a030b
	v_lshl_add_u32 v27, v27, 3, v8                              ; d1fd001b 0421071b
	v_lshlrev_b32_e32 v9, 4, v23                                ; 24122e84
	v_lshlrev_b32_e32 v10, 7, v10                               ; 24141487
	v_and_b32_e32 v33, 7, v27                                   ; 26423687
	v_lshrrev_b32_e32 v8, 4, v27                                ; 20103684
	v_lshl_add_u32 v23, v23, 7, v9                              ; d1fd0017 04250f17
	v_sub_u32_e32 v26, v26, v10                                 ; 6a34151a
	v_lshl_add_u32 v8, v8, 3, v33                               ; d1fd0008 04850708
	v_lshlrev_b32_e32 v8, 2, v8                                 ; 24101082
	v_add3_u32 v8, v8, 16, v23                                  ; d1ff0008 045d2108
	buffer_load_dwordx4 v[8:11], v8, s[24:27], 0 offen          ; e05c1000 80060808
	v_bfe_u32 v25, v2, 3, 1                                     ; d1c80019 02050702
	v_lshrrev_b32_e32 v2, 3, v2                                 ; 20040483
	v_cvt_f32_i32_e32 v26, v26                                  ; 7e340b1a
	s_waitcnt vmcnt(5)                                          ; bf8c3f75
	v_xor_b32_e32 v16, s1, v16                                  ; 2a202001
	v_xor_b32_e32 v17, s1, v17                                  ; 2a222201
	v_lshlrev_b32_e32 v25, 2, v25                               ; 24323282
	v_xor_b32_e32 v18, s1, v18                                  ; 2a242401
	v_xor_b32_e32 v19, s1, v19                                  ; 2a262601
	v_cmp_gt_u32_e32 vcc, 4, v2                                 ; 7d980484
	v_mac_f32_e32 v20, v21, v26                                 ; 2c283515
	v_and_b32_e32 v26, 3, v2                                    ; 26340483
	v_cvt_f32_f16_e32 v2, v22                                   ; 7e041716
	v_cvt_f32_f16_sdwa v22, v22 div:2 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e2c16f9 0005c616
	v_mad_f32 v24, -v24, v28, v20                               ; d1c10018 24523918
	v_lshlrev_b32_e32 v26, 3, v26                               ; 24343483
	v_add_u32_e32 v28, 2, v26                                   ; 68383482
	v_add_u32_e32 v33, 4, v26                                   ; 68423484
	v_cndmask_b32_e32 v28, v28, v26, vcc                        ; 0038351c
	s_waitcnt vmcnt(4)                                          ; bf8c3f74
	v_lshrrev_b32_e32 v29, v25, v29                             ; 203a3b19
	v_cndmask_b32_e32 v33, v33, v26, vcc                        ; 00423521
	v_lshrrev_b32_e32 v31, v25, v31                             ; 203e3f19
	v_lshrrev_b32_e32 v30, v25, v30                             ; 203c3d19
	v_lshrrev_b32_e32 v25, v25, v32                             ; 20324119
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_cndmask_b32_e32 v20, v15, v14, vcc                        ; 00281d0f
	v_cndmask_b32_e32 v15, v15, v13, vcc                        ; 001e1b0f
	v_lshrrev_b32_e32 v13, v28, v13                             ; 201a1b1c
	v_lshrrev_b32_e32 v28, v28, v14                             ; 20381d1c
	v_cvt_f32_f16_e32 v21, v12                                  ; 7e2a170c
	v_cvt_f32_f16_sdwa v12, v12 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e1816f9 0005060c
	v_bfe_u32 v20, v20, v33, 4                                  ; d1c80014 02124314
	v_bfe_u32 v15, v15, v26, 4                                  ; d1c8000f 0212350f
	v_and_b32_e32 v26, 15, v29                                  ; 26343a8f
	v_and_b32_e32 v29, s4, v29                                  ; 263a3a04
	v_and_or_b32 v28, 48, v28, v20                              ; d201001c 045238b0
	v_and_or_b32 v13, 48, v13, v15                              ; d201000d 043e1ab0
	v_mul_u32_u24_sdwa v33, v29, v16 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 104220f9 0202061d
	v_mul_u32_u24_sdwa v32, v29, v16 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 104020f9 0101061d
	v_cvt_f32_ubyte0_e32 v28, v28                               ; 7e38231c
	v_cvt_f32_ubyte0_e32 v13, v13                               ; 7e1a230d
	v_and_b32_e32 v20, 15, v31                                  ; 26283e8f
	v_mul_f32_e32 v12, v12, v28                                 ; 0a18390c
	v_mul_u32_u24_sdwa v28, v26, v16 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_0 ; 103820f9 0006061a
	v_mul_u32_u24_sdwa v16, v29, v16 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 102020f9 0303061d
	v_and_b32_e32 v31, s4, v31                                  ; 263e3e04
	v_mul_f32_e32 v21, v21, v13                                 ; 0a2a1b15
	v_and_b32_e32 v13, 15, v30                                  ; 261a3c8f
	v_and_b32_e32 v30, s4, v30                                  ; 263c3c04
	v_add3_u32 v33, v33, v28, v32                               ; d1ff0021 04823921
	v_mul_u32_u24_sdwa v28, v20, v18 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_0 ; 103824f9 00060614
	v_mul_u32_u24_sdwa v32, v31, v18 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 104024f9 0101061f
	v_mul_u32_u24_sdwa v14, v13, v17 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_0 ; 101c22f9 0006060d
	v_mul_u32_u24_sdwa v15, v30, v17 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 101e22f9 0101061e
	v_add3_u32 v14, v14, v33, v16                               ; d1ff000e 0442430e
	v_mul_u32_u24_sdwa v33, v31, v18 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 104224f9 0202061f
	v_mul_u32_u24_sdwa v18, v31, v18 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 102424f9 0303061f
	v_mul_u32_u24_sdwa v16, v30, v17 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 102022f9 0202061e
	v_mul_u32_u24_sdwa v17, v30, v17 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 102222f9 0303061e
	v_add3_u32 v16, v16, v14, v15                               ; d1ff0010 043e1d10
	v_and_b32_e32 v14, 15, v25                                  ; 261c328f
	v_and_b32_e32 v25, s4, v25                                  ; 26323204
	v_add3_u32 v28, v28, v16, v17                               ; d1ff001c 0446211c
	v_mul_u32_u24_sdwa v15, v14, v19 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_0 ; 101e26f9 0006060e
	v_mul_u32_u24_sdwa v16, v25, v19 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 102026f9 01010619
	v_mul_u32_u24_sdwa v17, v25, v19 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 102226f9 02020619
	v_add3_u32 v33, v33, v28, v32                               ; d1ff0021 04823921
	v_add3_u32 v15, v15, v33, v18                               ; d1ff000f 044a430f
	v_add3_u32 v17, v17, v15, v16                               ; d1ff0011 04421f11
	v_mov_b32_e32 v28, v17                                      ; 7e380311
	buffer_load_dwordx4 v[15:18], v23, s[24:27], 0 offen        ; e05c1000 80060f17
	v_add_u32_sdwa v26, v26, v29 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_1 ; 68343af9 0106061a
	v_mul_u32_u24_sdwa v19, v25, v19 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 102626f9 03030619
	v_add_u32_sdwa v26, v26, v29 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_2 ; 68343af9 0206061a
	v_add_u32_e32 v28, v28, v19                                 ; 6838271c
	v_mul_f32_e32 v2, v2, v21                                   ; 0a042b02
	v_add_u32_sdwa v26, v26, v29 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_3 ; 68343af9 0306061a
	v_add_u32_e32 v26, v26, v13                                 ; 68341b1a
	v_add_u32_sdwa v26, v26, v30 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_1 ; 68343cf9 0106061a
	v_bfe_u32 v29, v27, 3, 1                                    ; d1c8001d 0205071b
	v_add_u32_sdwa v26, v26, v30 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_2 ; 68343cf9 0206061a
	v_lshrrev_b32_e32 v27, 3, v27                               ; 20363683
	v_lshlrev_b32_e32 v29, 2, v29                               ; 243a3a82
	v_add_u32_sdwa v26, v26, v30 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_3 ; 68343cf9 0306061a
	v_and_b32_e32 v30, 3, v27                                   ; 263c3683
	v_add_u32_e32 v26, v26, v20                                 ; 6834291a
	v_cmp_gt_u32_e32 vcc, 4, v27                                ; 7d983684
	v_lshlrev_b32_e32 v30, 3, v30                               ; 243c3c83
	v_add_u32_sdwa v26, v26, v31 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_1 ; 68343ef9 0106061a
	v_add_u32_e32 v32, 4, v30                                   ; 68403c84
	v_add_u32_e32 v3, -4, v3                                    ; 680606c4
	v_add_u32_e32 v1, 0x1000, v1                                ; 680202ff 00001000
	v_add_u32_sdwa v26, v26, v31 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_2 ; 68343ef9 0206061a
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_cvt_f32_f16_e32 v33, v34                                  ; 7e421722
	v_cndmask_b32_e32 v32, v32, v30, vcc                        ; 00403d20
	v_cvt_f32_f16_sdwa v34, v34 div:2 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e4416f9 0005c622
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_xor_b32_e32 v4, s1, v4                                    ; 2a080801
	v_xor_b32_e32 v5, s1, v5                                    ; 2a0a0a01
	v_add_u32_sdwa v26, v26, v31 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_3 ; 68343ef9 0306061a
	v_add_u32_e32 v31, 2, v30                                   ; 683e3c82
	v_xor_b32_e32 v6, s1, v6                                    ; 2a0c0c01
	v_xor_b32_e32 v7, s1, v7                                    ; 2a0e0e01
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_lshrrev_b32_e32 v8, v29, v8                               ; 2010111d
	v_lshrrev_b32_e32 v9, v29, v9                               ; 2012131d
	v_lshrrev_b32_e32 v10, v29, v10                             ; 2014151d
	v_lshrrev_b32_e32 v29, v29, v11                             ; 203a171d
	v_add_u32_e32 v26, v26, v14                                 ; 68341d1a
	v_cndmask_b32_e32 v31, v31, v30, vcc                        ; 003e3d1f
	v_and_b32_e32 v19, 15, v9                                   ; 2626128f
	v_add_u32_sdwa v26, v26, v25 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_1 ; 683432f9 0106061a
	v_mul_u32_u24_sdwa v20, v19, v5 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_0 ; 10280af9 00060613
	v_and_b32_e32 v9, s4, v9                                    ; 26121204
	v_add_u32_sdwa v26, v26, v25 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_2 ; 683432f9 0206061a
	v_mul_u32_u24_sdwa v21, v9, v5 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 102a0af9 01010609
	v_add_u32_sdwa v26, v26, v25 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_3 ; 683432f9 0306061a
	v_lshlrev_b32_e32 v26, 7, v26                               ; 24343487
	v_and_b32_e32 v23, 15, v10                                  ; 262e148f
	v_sub_u32_e32 v28, v28, v26                                 ; 6a38351c
	v_cvt_f32_i32_e32 v28, v28                                  ; 7e380b1c
	v_and_b32_e32 v10, s4, v10                                  ; 26141404
	v_mac_f32_e32 v24, v2, v28                                  ; 2c303902
	v_and_b32_e32 v2, 15, v8                                    ; 2604108f
	v_and_b32_e32 v8, s4, v8                                    ; 26101004
	v_mul_u32_u24_sdwa v25, v10, v6 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 10320cf9 0101060a
	v_mul_u32_u24_sdwa v26, v10, v6 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 10340cf9 0202060a
	v_mad_f32 v12, -v12, v22, v24                               ; d1c1000c 24622d0c
	v_mul_u32_u24_sdwa v22, v9, v5 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 102c0af9 02020609
	v_mul_u32_u24_sdwa v5, v9, v5 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 100a0af9 03030609
	v_mul_u32_u24_sdwa v24, v23, v6 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_0 ; 10300cf9 00060617
	v_mul_u32_u24_sdwa v11, v2, v4 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_0 ; 101608f9 00060602
	v_mul_u32_u24_sdwa v6, v10, v6 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 100c0cf9 0303060a
	v_mul_u32_u24_sdwa v13, v8, v4 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 101a08f9 01010608
	v_and_b32_e32 v27, 15, v29                                  ; 26363a8f
	v_mul_u32_u24_sdwa v14, v8, v4 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 101c08f9 02020608
	v_mul_u32_u24_sdwa v4, v8, v4 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 100808f9 03030608
	v_and_b32_e32 v29, s4, v29                                  ; 263a3a04
	v_add_u32_sdwa v2, v2, v8 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_1 ; 680410f9 01060602
	v_mul_u32_u24_sdwa v28, v27, v7 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_0 ; 10380ef9 0006061b
	v_add3_u32 v14, v14, v11, v13                               ; d1ff000e 0436170e
	v_add_u32_sdwa v2, v2, v8 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_2 ; 680410f9 02060602
	v_add3_u32 v20, v20, v14, v4                                ; d1ff0014 04121d14
	v_mul_u32_u24_sdwa v4, v29, v7 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 10080ef9 0101061d
	v_add_u32_sdwa v2, v2, v8 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_3 ; 680410f9 03060602
	v_add3_u32 v22, v22, v20, v21                               ; d1ff0016 04562916
	v_add_u32_e32 v2, v2, v19                                   ; 68042702
	v_add3_u32 v24, v24, v22, v5                                ; d1ff0018 04162d18
	v_mul_u32_u24_sdwa v5, v29, v7 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 100a0ef9 0202061d
	v_mul_u32_u24_sdwa v7, v29, v7 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 100e0ef9 0303061d
	v_add_u32_sdwa v2, v2, v9 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_1 ; 680412f9 01060602
	v_add3_u32 v26, v26, v24, v25                               ; d1ff001a 0466311a
	v_add_u32_sdwa v2, v2, v9 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_2 ; 680412f9 02060602
	v_add3_u32 v28, v28, v26, v6                                ; d1ff001c 041a351c
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_cndmask_b32_e32 v6, v18, v17, vcc                         ; 000c2312
	v_add_u32_sdwa v2, v2, v9 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_3 ; 680412f9 03060602
	v_cndmask_b32_e32 v18, v18, v16, vcc                        ; 00242112
	v_add3_u32 v5, v5, v28, v4                                  ; d1ff0005 04123905
	v_lshrrev_b32_e32 v16, v31, v16                             ; 2020211f
	v_add_u32_e32 v2, v2, v23                                   ; 68042f02
	v_bfe_u32 v6, v6, v32, 4                                    ; d1c80006 02124106
	v_bfe_u32 v18, v18, v30, 4                                  ; d1c80012 02123d12
	v_lshrrev_b32_e32 v31, v31, v17                             ; 203e231f
	v_add_u32_e32 v5, v5, v7                                    ; 680a0f05
	v_add_u32_sdwa v2, v2, v10 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_1 ; 680414f9 01060602
	v_cvt_f32_f16_e32 v7, v15                                   ; 7e0e170f
	v_and_or_b32 v16, 48, v16, v18                              ; d2010010 044a20b0
	v_cvt_f32_f16_sdwa v15, v15 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e1e16f9 0005060f
	v_and_or_b32 v31, 48, v31, v6                               ; d201001f 041a3eb0
	v_add_u32_sdwa v2, v2, v10 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_2 ; 680414f9 02060602
	v_cvt_f32_ubyte0_e32 v16, v16                               ; 7e202310
	v_cvt_f32_ubyte0_e32 v31, v31                               ; 7e3e231f
	v_add_u32_sdwa v2, v2, v10 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_3 ; 680414f9 03060602
	v_mul_f32_e32 v7, v7, v16                                   ; 0a0e2107
	v_mul_f32_e32 v15, v15, v31                                 ; 0a1e3f0f
	v_add_u32_e32 v2, v2, v27                                   ; 68043702
	v_mul_f32_e32 v33, v33, v7                                  ; 0a420f21
	v_add_u32_sdwa v2, v2, v29 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_1 ; 68043af9 01060602
	v_add_u32_sdwa v2, v2, v29 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_2 ; 68043af9 02060602
	v_add_u32_sdwa v2, v2, v29 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_3 ; 68043af9 03060602
	v_lshlrev_b32_e32 v2, 7, v2                                 ; 24040487
	v_sub_u32_e32 v5, v5, v2                                    ; 6a0a0505
	v_cvt_f32_i32_e32 v5, v5                                    ; 7e0a0b05
	v_mac_f32_e32 v12, v33, v5                                  ; 2c180b21
	v_mad_f32 v2, -v15, v34, v12                                ; d1c10002 2432450f
BB5:
	s_mov_b64 s[0:1], exec                                      ; be80017e
	v_cmpx_gt_u32_e32 vcc, 4, v3                                ; 7db80684
BB6:
	s_andn2_b64 s[0:1], s[0:1], exec                            ; 89807e00
	s_cbranch_scc1 BB10                                         ; bf85fd2b
BB11:
	s_mov_b64 exec, -1                                          ; befe01c1
	v_cmpx_le_u32_e32 vcc, 2, v3                                ; 7db60682
	s_cbranch_execz BB17                                        ; bf88016c
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
	v_lshrrev_b32_e32 v24, 5, v24                               ; 20303085
	v_add_u32_e32 v24, s18, v24                                 ; 68303012
	v_and_b32_e32 v29, 7, v24                                   ; 263a3087
	v_lshrrev_b32_e32 v24, 3, v24                               ; 20303083
	v_lshl_add_u32 v29, v29, 3, v8                              ; d1fd001d 0421071d
	v_lshlrev_b32_e32 v5, 4, v24                                ; 240a3084
	v_and_b32_e32 v34, 7, v29                                   ; 26443a87
	v_lshrrev_b32_e32 v4, 4, v29                                ; 20083a84
	v_lshl_add_u32 v24, v24, 7, v5                              ; d1fd0018 04150f18
	v_lshl_add_u32 v4, v4, 3, v34                               ; d1fd0004 04890704
	v_lshlrev_b32_e32 v4, 2, v4                                 ; 24080882
	v_add3_u32 v4, v4, 16, v24                                  ; d1ff0004 04612104
	s_waitcnt vmcnt(5)                                          ; bf8c3f75
	v_mov_b32_e32 v8, v7                                        ; 7e100307
	buffer_load_dwordx4 v[4:7], v4, s[24:27], 0 offen           ; e05c1000 80060404
	v_bfe_u32 v9, v10, 3, 1                                     ; d1c80009 0205070a
	v_lshrrev_b32_e32 v10, 3, v10                               ; 20141483
	s_mov_b32 s1, 0x80808080                                    ; be8100ff 80808080
	s_mov_b32 s4, 0xf0f0f0f                                     ; be8400ff 0f0f0f0f
	v_bfe_u32 v27, v29, 3, 1                                    ; d1c8001b 0205071d
	v_lshlrev_b32_e32 v9, 2, v9                                 ; 24121282
	v_cmp_gt_u32_e32 vcc, 4, v10                                ; 7d981484
	v_and_b32_e32 v11, 3, v10                                   ; 26161483
	s_waitcnt vmcnt(5)                                          ; bf8c3f75
	v_xor_b32_e32 v13, s1, v13                                  ; 2a1a1a01
	v_xor_b32_e32 v14, s1, v14                                  ; 2a1c1c01
	v_xor_b32_e32 v12, s1, v12                                  ; 2a181801
	v_xor_b32_e32 v15, s1, v15                                  ; 2a1e1e01
	v_lshlrev_b32_e32 v27, 2, v27                               ; 24363682
	v_lshlrev_b32_e32 v11, 3, v11                               ; 24161683
	v_add_u32_e32 v26, 4, v11                                   ; 68341684
	v_add_u32_e32 v25, 2, v11                                   ; 68321682
	v_cndmask_b32_e32 v26, v26, v11, vcc                        ; 0034171a
	v_cndmask_b32_e32 v25, v25, v11, vcc                        ; 00321719
	s_waitcnt vmcnt(4)                                          ; bf8c3f74
	v_lshrrev_b32_e32 v16, v9, v16                              ; 20202109
	v_lshrrev_b32_e32 v18, v9, v18                              ; 20242509
	v_lshrrev_b32_e32 v17, v9, v17                              ; 20222309
	v_lshrrev_b32_e32 v9, v9, v19                               ; 20122709
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_cndmask_b32_e32 v34, v23, v22, vcc                        ; 00442d17
	v_cndmask_b32_e32 v23, v23, v21, vcc                        ; 002e2b17
	v_lshrrev_b32_e32 v21, v25, v21                             ; 202a2b19
	v_lshrrev_b32_e32 v25, v25, v22                             ; 20322d19
	v_and_b32_e32 v10, 15, v16                                  ; 2614208f
	v_and_b32_e32 v16, s4, v16                                  ; 26202004
	v_bfe_u32 v34, v34, v26, 4                                  ; d1c80022 02123522
	v_bfe_u32 v23, v23, v11, 4                                  ; d1c80017 02121717
	v_and_b32_e32 v22, 15, v17                                  ; 262c228f
	v_mul_u32_u24_sdwa v11, v10, v12 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_0 ; 101618f9 0006060a
	v_mul_u32_u24_sdwa v19, v16, v12 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 102618f9 01010610
	v_and_or_b32 v25, 48, v25, v34                              ; d2010019 048a32b0
	v_cvt_f32_f16_e32 v34, v20                                  ; 7e441714
	v_cvt_f32_f16_sdwa v20, v20 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e2816f9 00050614
	v_and_b32_e32 v17, s4, v17                                  ; 26222204
	v_and_or_b32 v21, 48, v21, v23                              ; d2010015 045e2ab0
	v_mul_u32_u24_sdwa v23, v22, v13 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_0 ; 102e1af9 00060616
	v_cvt_f32_ubyte0_e32 v25, v25                               ; 7e322319
	v_mul_u32_u24_sdwa v26, v17, v13 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 10341af9 02020611
	v_cvt_f32_ubyte0_e32 v21, v21                               ; 7e2a2315
	v_mul_f32_e32 v20, v20, v25                                 ; 0a283314
	v_mul_u32_u24_sdwa v25, v17, v13 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 10321af9 01010611
	v_mul_u32_u24_sdwa v13, v17, v13 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 101a1af9 03030611
	v_mul_f32_e32 v34, v34, v21                                 ; 0a442b22
	v_mul_u32_u24_sdwa v21, v16, v12 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 102a18f9 02020610
	v_mul_u32_u24_sdwa v12, v16, v12 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 101818f9 03030610
	v_add3_u32 v21, v21, v11, v19                               ; d1ff0015 044e1715
	v_and_b32_e32 v11, 15, v18                                  ; 2616248f
	v_and_b32_e32 v18, s4, v18                                  ; 26242404
	v_add3_u32 v23, v23, v21, v12                               ; d1ff0017 04322b17
	v_and_b32_e32 v21, 15, v9                                   ; 262a128f
	v_and_b32_e32 v9, s4, v9                                    ; 26121204
	v_mul_u32_u24_sdwa v12, v11, v14 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_0 ; 10181cf9 0006060b
	v_mul_u32_u24_sdwa v19, v18, v14 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 10261cf9 02020612
	v_add3_u32 v26, v26, v23, v25                               ; d1ff001a 04662f1a
	v_mul_u32_u24_sdwa v23, v21, v15 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_0 ; 102e1ef9 00060615
	v_mul_u32_u24_sdwa v25, v9, v15 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 10321ef9 01010609
	v_add3_u32 v12, v12, v26, v13                               ; d1ff000c 0436350c
	v_mul_u32_u24_sdwa v13, v18, v14 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 101a1cf9 01010612
	v_mul_u32_u24_sdwa v14, v18, v14 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 101c1cf9 03030612
	v_mul_u32_u24_sdwa v26, v9, v15 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 10341ef9 02020609
	v_add3_u32 v19, v19, v12, v13                               ; d1ff0013 04361913
	v_add3_u32 v23, v23, v19, v14                               ; d1ff0017 043a2717
	v_mov_b32_e32 v19, v15                                      ; 7e26030f
	buffer_load_dwordx4 v[12:15], v24, s[24:27], 0 offen        ; e05c1000 80060c18
	v_add_u32_sdwa v10, v10, v16 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_1 ; 681420f9 0106060a
	v_add3_u32 v26, v26, v23, v25                               ; d1ff001a 04662f1a
	v_mul_u32_u24_sdwa v19, v9, v19 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 102626f9 03030609
	v_add_u32_sdwa v10, v10, v16 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_2 ; 681420f9 0206060a
	v_add_u32_e32 v26, v26, v19                                 ; 6834271a
	v_add_u32_sdwa v10, v10, v16 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_3 ; 681420f9 0306060a
	v_add_u32_e32 v10, v10, v22                                 ; 68142d0a
	v_add_u32_sdwa v10, v10, v17 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_1 ; 681422f9 0106060a
	v_add_u32_sdwa v10, v10, v17 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_2 ; 681422f9 0206060a
	v_add_u32_sdwa v10, v10, v17 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_3 ; 681422f9 0306060a
	v_add_u32_e32 v10, v10, v11                                 ; 6814170a
	v_lshrrev_b32_e32 v29, 3, v29                               ; 203a3a83
	v_add_u32_sdwa v10, v10, v18 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_1 ; 681424f9 0106060a
	v_and_b32_e32 v22, 3, v29                                   ; 262c3a83
	v_add_u32_sdwa v10, v10, v18 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_2 ; 681424f9 0206060a
	v_cmp_gt_u32_e32 vcc, 4, v29                                ; 7d983a84
	v_lshlrev_b32_e32 v22, 3, v22                               ; 242c2c83
	v_add_u32_sdwa v10, v10, v18 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_3 ; 681424f9 0306060a
	v_add_u32_e32 v24, 4, v22                                   ; 68302c84
	v_add_u32_e32 v23, 2, v22                                   ; 682e2c82
	v_add_u32_e32 v3, -2, v3                                    ; 680606c2
	v_add_u32_e32 v10, v10, v21                                 ; 68142b0a
	v_cvt_f32_f16_e32 v21, v8                                   ; 7e2a1708
	v_cvt_f32_f16_sdwa v8, v8 div:2 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e1016f9 0005c608
	v_cndmask_b32_e32 v24, v24, v22, vcc                        ; 00302d18
	v_add_u32_e32 v1, 0x800, v1                                 ; 680202ff 00000800
	v_cndmask_b32_e32 v23, v23, v22, vcc                        ; 002e2d17
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_cvt_f32_f16_e32 v25, v28                                  ; 7e32171c
	v_cvt_f32_f16_sdwa v28, v28 div:2 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e3816f9 0005c61c
	v_add_u32_sdwa v10, v10, v9 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_1 ; 681412f9 0106060a
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_xor_b32_e32 v30, s1, v30                                  ; 2a3c3c01
	v_mul_f32_e32 v21, v21, v34                                 ; 0a2a4515
	v_xor_b32_e32 v31, s1, v31                                  ; 2a3e3e01
	v_xor_b32_e32 v32, s1, v32                                  ; 2a404001
	v_xor_b32_e32 v33, s1, v33                                  ; 2a424201
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_lshrrev_b32_e32 v4, v27, v4                               ; 2008091b
	v_lshrrev_b32_e32 v5, v27, v5                               ; 200a0b1b
	v_lshrrev_b32_e32 v6, v27, v6                               ; 200c0d1b
	v_lshrrev_b32_e32 v27, v27, v7                              ; 20360f1b
	v_add_u32_sdwa v10, v10, v9 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_2 ; 681412f9 0206060a
	v_and_b32_e32 v7, 15, v5                                    ; 260e0a8f
	v_add_u32_sdwa v10, v10, v9 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_3 ; 681412f9 0306060a
	v_and_b32_e32 v5, s4, v5                                    ; 260a0a04
	v_lshlrev_b32_e32 v10, 7, v10                               ; 24141487
	v_mul_u32_u24_sdwa v9, v5, v31 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 10123ef9 01010605
	v_sub_u32_e32 v26, v26, v10                                 ; 6a34151a
	v_mul_u32_u24_sdwa v10, v5, v31 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 10143ef9 02020605
	v_and_b32_e32 v11, 15, v6                                   ; 26160c8f
	v_cvt_f32_i32_e32 v26, v26                                  ; 7e340b1a
	v_and_b32_e32 v6, s4, v6                                    ; 260c0c04
	v_mul_u32_u24_sdwa v16, v11, v32 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_0 ; 102040f9 0006060b
	v_mac_f32_e32 v2, v21, v26                                  ; 2c043515
	v_and_b32_e32 v26, 15, v4                                   ; 2634088f
	v_and_b32_e32 v4, s4, v4                                    ; 26080804
	v_mul_u32_u24_sdwa v17, v6, v32 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 102240f9 01010606
	v_mul_u32_u24_sdwa v18, v6, v32 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 102440f9 02020606
	v_mad_f32 v20, -v20, v8, v2                                 ; d1c10014 240a1114
	v_mul_u32_u24_sdwa v8, v7, v31 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_0 ; 10103ef9 00060607
	v_mul_u32_u24_sdwa v31, v5, v31 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 103e3ef9 03030605
	v_mul_u32_u24_sdwa v32, v6, v32 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 104040f9 03030606
	v_mul_u32_u24_sdwa v29, v26, v30 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_0 ; 103a3cf9 0006061a
	v_and_b32_e32 v19, 15, v27                                  ; 2626368f
	v_mul_u32_u24_sdwa v34, v4, v30 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 10443cf9 01010604
	v_mul_u32_u24_sdwa v2, v4, v30 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 10043cf9 02020604
	v_mul_u32_u24_sdwa v30, v4, v30 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 103c3cf9 03030604
	v_and_b32_e32 v27, s4, v27                                  ; 26363604
	v_add_u32_sdwa v26, v26, v4 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_1 ; 683408f9 0106061a
	v_mul_u32_u24_sdwa v21, v19, v33 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_0 ; 102a42f9 00060613
	v_add3_u32 v2, v2, v29, v34                                 ; d1ff0002 048a3b02
	v_mul_u32_u24_sdwa v29, v27, v33 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 103a42f9 0101061b
	v_add_u32_sdwa v26, v26, v4 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_2 ; 683408f9 0206061a
	v_add3_u32 v8, v8, v2, v30                                  ; d1ff0008 047a0508
	v_mul_u32_u24_sdwa v30, v27, v33 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 103c42f9 0202061b
	v_mul_u32_u24_sdwa v33, v27, v33 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 104242f9 0303061b
	v_add_u32_sdwa v26, v26, v4 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_3 ; 683408f9 0306061a
	v_add3_u32 v10, v10, v8, v9                                 ; d1ff000a 0426110a
	v_add_u32_e32 v26, v26, v7                                  ; 68340f1a
	v_add3_u32 v16, v16, v10, v31                               ; d1ff0010 047e1510
	v_add_u32_sdwa v26, v26, v5 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_1 ; 68340af9 0106061a
	v_add3_u32 v18, v18, v16, v17                               ; d1ff0012 04462112
	v_add_u32_sdwa v26, v26, v5 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_2 ; 68340af9 0206061a
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_cndmask_b32_e32 v31, v15, v14, vcc                        ; 003e1d0f
	v_add3_u32 v21, v21, v18, v32                               ; d1ff0015 04822515
	v_add_u32_sdwa v26, v26, v5 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_3 ; 68340af9 0306061a
	v_cndmask_b32_e32 v15, v15, v13, vcc                        ; 001e1b0f
	v_lshrrev_b32_e32 v13, v23, v13                             ; 201a1b17
	v_add3_u32 v30, v30, v21, v29                               ; d1ff001e 04762b1e
	v_add_u32_e32 v26, v26, v11                                 ; 6834171a
	v_bfe_u32 v31, v31, v24, 4                                  ; d1c8001f 0212311f
	v_bfe_u32 v15, v15, v22, 4                                  ; d1c8000f 02122d0f
	v_lshrrev_b32_e32 v23, v23, v14                             ; 202e1d17
	v_add_u32_e32 v30, v30, v33                                 ; 683c431e
	v_add_u32_sdwa v26, v26, v6 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_1 ; 68340cf9 0106061a
	v_cvt_f32_f16_e32 v32, v12                                  ; 7e40170c
	v_and_or_b32 v13, 48, v13, v15                              ; d201000d 043e1ab0
	v_and_or_b32 v23, 48, v23, v31                              ; d2010017 047e2eb0
	v_cvt_f32_f16_sdwa v12, v12 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e1816f9 0005060c
	v_add_u32_sdwa v26, v26, v6 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_2 ; 68340cf9 0206061a
	v_cvt_f32_ubyte0_e32 v13, v13                               ; 7e1a230d
	v_cvt_f32_ubyte0_e32 v23, v23                               ; 7e2e2317
	v_add_u32_sdwa v26, v26, v6 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_3 ; 68340cf9 0306061a
	v_mul_f32_e32 v32, v32, v13                                 ; 0a401b20
	v_mul_f32_e32 v12, v12, v23                                 ; 0a182f0c
	v_add_u32_e32 v26, v26, v19                                 ; 6834271a
	v_mul_f32_e32 v25, v25, v32                                 ; 0a324119
	v_add_u32_sdwa v26, v26, v27 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_1 ; 683436f9 0106061a
	v_add_u32_sdwa v26, v26, v27 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_2 ; 683436f9 0206061a
	v_add_u32_sdwa v26, v26, v27 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_3 ; 683436f9 0306061a
	v_lshlrev_b32_e32 v26, 7, v26                               ; 24343487
	v_sub_u32_e32 v30, v30, v26                                 ; 6a3c351e
	v_cvt_f32_i32_e32 v30, v30                                  ; 7e3c0b1e
	v_mac_f32_e32 v20, v25, v30                                 ; 2c283d19
	v_mad_f32 v2, -v12, v28, v20                                ; d1c10002 2452390c
BB17:
	s_mov_b64 exec, -1                                          ; befe01c1
	v_cmpx_ne_i32_e32 vcc, 0, v3                                ; 7daa0680
	s_cbranch_execz BB23                                        ; bf8800b8
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
	s_mov_b32 s0, 0x80808080                                    ; be8000ff 80808080
	s_mov_b32 s1, 0xf0f0f0f                                     ; be8100ff 0f0f0f0f
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
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_xor_b32_e32 v10, s0, v10                                  ; 2a141400
	v_xor_b32_e32 v11, s0, v11                                  ; 2a161600
	v_xor_b32_e32 v8, s0, v8                                    ; 2a101000
	v_xor_b32_e32 v9, s0, v9                                    ; 2a121200
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_lshrrev_b32_e32 v14, v20, v14                             ; 201c1d14
	v_lshrrev_b32_e32 v13, v20, v13                             ; 201a1b14
	v_lshrrev_b32_e32 v12, v20, v12                             ; 20181914
	v_lshrrev_b32_e32 v20, v20, v15                             ; 20281f14
	v_and_b32_e32 v29, 15, v13                                  ; 263a1a8f
	v_and_b32_e32 v13, s1, v13                                  ; 261a1a01
	v_and_b32_e32 v33, 15, v14                                  ; 26421c8f
	v_and_b32_e32 v25, 15, v12                                  ; 2632188f
	v_and_b32_e32 v12, s1, v12                                  ; 26181801
	v_mul_u32_u24_sdwa v30, v29, v9 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_0 ; 103c12f9 0006061d
	v_mul_u32_u24_sdwa v32, v13, v9 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 104012f9 0202060d
	v_and_b32_e32 v14, s1, v14                                  ; 261c1c01
	v_mul_u32_u24_sdwa v31, v13, v9 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 103e12f9 0101060d
	v_mul_u32_u24_sdwa v9, v13, v9 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 101212f9 0303060d
	v_mul_u32_u24_sdwa v34, v33, v10 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_0 ; 104414f9 00060621
	v_mul_u32_u24_sdwa v26, v25, v8 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_0 ; 103410f9 00060619
	v_mul_u32_u24_sdwa v28, v12, v8 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 103810f9 0202060c
	v_mul_u32_u24_sdwa v27, v12, v8 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 103610f9 0101060c
	v_mul_u32_u24_sdwa v8, v12, v8 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 101010f9 0303060c
	v_and_b32_e32 v3, 15, v20                                   ; 2606288f
	v_mul_u32_u24_sdwa v0, v14, v10 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 100014f9 0101060e
	v_mul_u32_u24_sdwa v1, v14, v10 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 100214f9 0202060e
	v_mul_u32_u24_sdwa v10, v14, v10 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 101414f9 0303060e
	v_and_b32_e32 v20, s1, v20                                  ; 26282801
	v_add3_u32 v28, v28, v26, v27                               ; d1ff001c 046e351c
	v_add_u32_sdwa v25, v25, v12 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_1 ; 683218f9 01060619
	v_mul_u32_u24_sdwa v4, v3, v11 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_0 ; 100816f9 00060603
	v_mul_u32_u24_sdwa v7, v20, v11 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 100e16f9 02020614
	v_mul_u32_u24_sdwa v5, v20, v11 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 100a16f9 01010614
	v_mul_u32_u24_sdwa v11, v20, v11 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 101616f9 03030614
	v_add3_u32 v30, v30, v28, v8                                ; d1ff001e 0422391e
	v_add_u32_sdwa v25, v25, v12 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_2 ; 683218f9 02060619
	v_add3_u32 v32, v32, v30, v31                               ; d1ff0020 047e3d20
	v_add_u32_sdwa v25, v25, v12 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_3 ; 683218f9 03060619
	v_add3_u32 v34, v34, v32, v9                                ; d1ff0022 04264122
	v_add_u32_e32 v25, v25, v29                                 ; 68323b19
	v_add3_u32 v1, v1, v34, v0                                  ; d1ff0001 04024501
	v_add_u32_sdwa v25, v25, v13 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_1 ; 68321af9 01060619
	v_add3_u32 v4, v4, v1, v10                                  ; d1ff0004 042a0304
	v_add_u32_sdwa v25, v25, v13 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_2 ; 68321af9 02060619
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_cndmask_b32_e32 v8, v19, v18, vcc                         ; 00102513
	v_cndmask_b32_e32 v19, v19, v17, vcc                        ; 00262313
	v_add3_u32 v7, v7, v4, v5                                   ; d1ff0007 04160907
	v_add_u32_sdwa v25, v25, v13 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_3 ; 68321af9 03060619
	v_lshrrev_b32_e32 v17, v22, v17                             ; 20222316
	v_bfe_u32 v19, v19, v21, 4                                  ; d1c80013 02122b13
	v_add_u32_e32 v7, v7, v11                                   ; 680e1707
	v_bfe_u32 v8, v8, v23, 4                                    ; d1c80008 02122f08
	v_lshrrev_b32_e32 v22, v22, v18                             ; 202c2516
	v_add_u32_e32 v25, v25, v33                                 ; 68324319
	v_and_or_b32 v17, 48, v17, v19                              ; d2010011 044e22b0
	v_cvt_f32_f16_e32 v9, v16                                   ; 7e121710
	v_cvt_f32_f16_sdwa v16, v16 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e2016f9 00050610
	v_and_or_b32 v22, 48, v22, v8                               ; d2010016 04222cb0
	v_add_u32_sdwa v25, v25, v14 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_1 ; 68321cf9 01060619
	v_cvt_f32_ubyte0_e32 v17, v17                               ; 7e222311
	v_cvt_f32_ubyte0_e32 v22, v22                               ; 7e2c2316
	v_add_u32_sdwa v25, v25, v14 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_2 ; 68321cf9 02060619
	v_mul_f32_e32 v9, v9, v17                                   ; 0a122309
	v_mul_f32_e32 v16, v16, v22                                 ; 0a202d10
	v_add_u32_sdwa v25, v25, v14 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_3 ; 68321cf9 03060619
	v_mul_f32_e32 v24, v24, v9                                  ; 0a301318
	v_add_u32_e32 v25, v25, v3                                  ; 68320719
	v_add_u32_sdwa v25, v25, v20 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_1 ; 683228f9 01060619
	v_add_u32_sdwa v25, v25, v20 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_2 ; 683228f9 02060619
	v_add_u32_sdwa v25, v25, v20 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_3 ; 683228f9 03060619
	v_lshlrev_b32_e32 v25, 7, v25                               ; 24323287
	v_sub_u32_e32 v7, v7, v25                                   ; 6a0e3307
	v_cvt_f32_i32_e32 v7, v7                                    ; 7e0e0b07
	v_mac_f32_e32 v2, v24, v7                                   ; 2c040f18
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
	s_branch BB98                                               ; bf8205cc
BB36:
	s_cmp_lt_u32 s16, s4                                        ; bf0a0410
	s_cbranch_scc0 BB98                                         ; bf8405ca
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
	s_nop 0                                                     ; bf800000
	(then repeated 2 times)
BB41:
	s_mov_b64 s[10:11], exec                                    ; be8a017e
	v_cmpx_gt_u32_e32 vcc, 4, v3                                ; 7db80684
	s_mov_b32 s5, src_scc                                       ; be8500fd
BB42:
	s_andn2_b64 s[10:11], s[10:11], exec                        ; 898a7e0a
	s_cbranch_scc0 BB59                                         ; bf8402e7
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
	s_cbranch_scc0 BB49                                         ; bf8400a6
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
	s_mov_b32 s5, 0x80808080                                    ; be8500ff 80808080
	s_mov_b32 s9, 0xf0f0f0f                                     ; be8900ff 0f0f0f0f
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
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_xor_b32_e32 v12, s5, v12                                  ; 2a181805
	v_xor_b32_e32 v13, s5, v13                                  ; 2a1a1a05
	v_xor_b32_e32 v14, s5, v14                                  ; 2a1c1c05
	v_xor_b32_e32 v15, s5, v15                                  ; 2a1e1e05
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_lshrrev_b32_e32 v18, v11, v18                             ; 2024250b
	v_lshrrev_b32_e32 v17, v11, v17                             ; 2022230b
	v_lshrrev_b32_e32 v16, v11, v16                             ; 2020210b
	v_lshrrev_b32_e32 v11, v11, v19                             ; 2016270b
	v_and_b32_e32 v32, 15, v17                                  ; 2640228f
	v_and_b32_e32 v17, s9, v17                                  ; 26222209
	v_and_b32_e32 v5, 15, v18                                   ; 260a248f
	v_and_b32_e32 v28, 15, v16                                  ; 2638208f
	v_and_b32_e32 v16, s9, v16                                  ; 26202009
	v_mul_u32_u24_sdwa v33, v32, v13 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_0 ; 10421af9 00060620
	v_mul_u32_u24_sdwa v4, v17, v13 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 10081af9 02020611
	v_mul_u32_u24_sdwa v34, v17, v13 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 10441af9 01010611
	v_and_b32_e32 v18, s9, v18                                  ; 26242409
	v_mul_u32_u24_sdwa v13, v17, v13 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 101a1af9 03030611
	v_mul_u32_u24_sdwa v6, v5, v14 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_0 ; 100c1cf9 00060605
	v_mul_u32_u24_sdwa v29, v28, v12 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_0 ; 103a18f9 0006061c
	v_mul_u32_u24_sdwa v31, v16, v12 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 103e18f9 02020610
	v_mul_u32_u24_sdwa v30, v16, v12 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 103c18f9 01010610
	v_mul_u32_u24_sdwa v12, v16, v12 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 101818f9 03030610
	v_mul_u32_u24_sdwa v9, v18, v14 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 10121cf9 01010612
	v_mul_u32_u24_sdwa v10, v18, v14 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 10141cf9 02020612
	v_mul_u32_u24_sdwa v14, v18, v14 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 101c1cf9 03030612
	v_add3_u32 v31, v31, v29, v30                               ; d1ff001f 047a3b1f
	v_add_u32_sdwa v28, v28, v16 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_1 ; 683820f9 0106061c
	v_add3_u32 v33, v33, v31, v12                               ; d1ff0021 04323f21
	v_and_b32_e32 v12, 15, v11                                  ; 2618168f
	v_and_b32_e32 v11, s9, v11                                  ; 26161609
	v_add_u32_sdwa v28, v28, v16 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_2 ; 683820f9 0206061c
	v_add3_u32 v4, v4, v33, v34                                 ; d1ff0004 048a4304
	v_mul_u32_u24_sdwa v19, v11, v15 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 10261ef9 0202060b
	v_add_u32_sdwa v28, v28, v16 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_3 ; 683820f9 0306061c
	v_add3_u32 v6, v6, v4, v13                                  ; d1ff0006 04360906
	v_mul_u32_u24_sdwa v13, v12, v15 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_0 ; 101a1ef9 0006060c
	v_add_u32_e32 v28, v28, v32                                 ; 6838411c
	v_add3_u32 v10, v10, v6, v9                                 ; d1ff000a 04260d0a
	v_add_u32_sdwa v28, v28, v17 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_1 ; 683822f9 0106061c
	v_add3_u32 v13, v13, v10, v14                               ; d1ff000d 043a150d
	v_mul_u32_u24_sdwa v14, v11, v15 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 101c1ef9 0101060b
	v_mul_u32_u24_sdwa v15, v11, v15 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 101e1ef9 0303060b
	v_add_u32_sdwa v28, v28, v17 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_2 ; 683822f9 0206061c
	v_add3_u32 v19, v19, v13, v14                               ; d1ff0013 043a1b13
	v_add_u32_sdwa v28, v28, v17 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_3 ; 683822f9 0306061c
	v_add_u32_e32 v19, v19, v15                                 ; 68261f13
	v_add_u32_e32 v28, v28, v5                                  ; 68380b1c
	v_add_u32_sdwa v28, v28, v18 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_1 ; 683824f9 0106061c
	v_add_u32_sdwa v28, v28, v18 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_2 ; 683824f9 0206061c
	v_add_u32_sdwa v28, v28, v18 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_3 ; 683824f9 0306061c
	v_add_u32_e32 v28, v28, v12                                 ; 6838191c
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_cvt_f32_f16_e32 v29, v20                                  ; 7e3a1714
	v_add_u32_sdwa v28, v28, v11 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_1 ; 683816f9 0106061c
	v_cvt_f32_f16_sdwa v20, v20 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e2816f9 00050614
	v_add_u32_sdwa v28, v28, v11 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_2 ; 683816f9 0206061c
	v_add_u32_sdwa v28, v28, v11 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_3 ; 683816f9 0306061c
	v_lshlrev_b32_e32 v28, 7, v28                               ; 24383887
	v_sub_u32_e32 v19, v19, v28                                 ; 6a263913
	v_cndmask_b32_e32 v28, v23, v22, vcc                        ; 00382d17
	v_cndmask_b32_e32 v23, v23, v21, vcc                        ; 002e2b17
	v_lshrrev_b32_e32 v21, v25, v21                             ; 202a2b19
	v_lshrrev_b32_e32 v25, v25, v22                             ; 20322d19
	v_cvt_f32_i32_e32 v19, v19                                  ; 7e260b13
	v_bfe_u32 v28, v28, v26, 4                                  ; d1c8001c 0212351c
	v_bfe_u32 v23, v23, v24, 4                                  ; d1c80017 02123117
	v_and_or_b32 v25, 48, v25, v28                              ; d2010019 047232b0
	v_and_or_b32 v21, 48, v21, v23                              ; d2010015 045e2ab0
	v_cvt_f32_ubyte0_e32 v25, v25                               ; 7e322319
	v_cvt_f32_ubyte0_e32 v21, v21                               ; 7e2a2315
	v_mul_f32_e32 v20, v20, v25                                 ; 0a283314
	v_mul_f32_e32 v29, v29, v21                                 ; 0a3a2b1d
	v_mul_f32_e32 v27, v27, v29                                 ; 0a363b1b
	v_mac_f32_e32 v2, v27, v19                                  ; 2c04271b
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
	s_cbranch_scc0 BB52                                         ; bf8400a6
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
	s_mov_b32 s5, 0x80808080                                    ; be8500ff 80808080
	s_mov_b32 s9, 0xf0f0f0f                                     ; be8900ff 0f0f0f0f
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
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_xor_b32_e32 v12, s5, v12                                  ; 2a181805
	v_xor_b32_e32 v13, s5, v13                                  ; 2a1a1a05
	v_xor_b32_e32 v14, s5, v14                                  ; 2a1c1c05
	v_xor_b32_e32 v15, s5, v15                                  ; 2a1e1e05
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_lshrrev_b32_e32 v18, v11, v18                             ; 2024250b
	v_lshrrev_b32_e32 v17, v11, v17                             ; 2022230b
	v_lshrrev_b32_e32 v16, v11, v16                             ; 2020210b
	v_lshrrev_b32_e32 v11, v11, v19                             ; 2016270b
	v_and_b32_e32 v32, 15, v17                                  ; 2640228f
	v_and_b32_e32 v17, s9, v17                                  ; 26222209
	v_and_b32_e32 v5, 15, v18                                   ; 260a248f
	v_and_b32_e32 v28, 15, v16                                  ; 2638208f
	v_and_b32_e32 v16, s9, v16                                  ; 26202009
	v_mul_u32_u24_sdwa v33, v32, v13 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_0 ; 10421af9 00060620
	v_mul_u32_u24_sdwa v4, v17, v13 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 10081af9 02020611
	v_mul_u32_u24_sdwa v34, v17, v13 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 10441af9 01010611
	v_and_b32_e32 v18, s9, v18                                  ; 26242409
	v_mul_u32_u24_sdwa v13, v17, v13 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 101a1af9 03030611
	v_mul_u32_u24_sdwa v6, v5, v14 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_0 ; 100c1cf9 00060605
	v_mul_u32_u24_sdwa v29, v28, v12 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_0 ; 103a18f9 0006061c
	v_mul_u32_u24_sdwa v31, v16, v12 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 103e18f9 02020610
	v_mul_u32_u24_sdwa v30, v16, v12 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 103c18f9 01010610
	v_mul_u32_u24_sdwa v12, v16, v12 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 101818f9 03030610
	v_mul_u32_u24_sdwa v7, v18, v14 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 100e1cf9 01010612
	v_mul_u32_u24_sdwa v10, v18, v14 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 10141cf9 02020612
	v_mul_u32_u24_sdwa v14, v18, v14 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 101c1cf9 03030612
	v_add3_u32 v31, v31, v29, v30                               ; d1ff001f 047a3b1f
	v_add_u32_sdwa v28, v28, v16 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_1 ; 683820f9 0106061c
	v_add3_u32 v33, v33, v31, v12                               ; d1ff0021 04323f21
	v_and_b32_e32 v12, 15, v11                                  ; 2618168f
	v_and_b32_e32 v11, s9, v11                                  ; 26161609
	v_add_u32_sdwa v28, v28, v16 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_2 ; 683820f9 0206061c
	v_add3_u32 v4, v4, v33, v34                                 ; d1ff0004 048a4304
	v_mul_u32_u24_sdwa v19, v11, v15 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 10261ef9 0202060b
	v_add_u32_sdwa v28, v28, v16 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_3 ; 683820f9 0306061c
	v_add3_u32 v6, v6, v4, v13                                  ; d1ff0006 04360906
	v_mul_u32_u24_sdwa v13, v12, v15 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_0 ; 101a1ef9 0006060c
	v_add_u32_e32 v28, v28, v32                                 ; 6838411c
	v_add3_u32 v10, v10, v6, v7                                 ; d1ff000a 041e0d0a
	v_add_u32_sdwa v28, v28, v17 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_1 ; 683822f9 0106061c
	v_add3_u32 v13, v13, v10, v14                               ; d1ff000d 043a150d
	v_mul_u32_u24_sdwa v14, v11, v15 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 101c1ef9 0101060b
	v_mul_u32_u24_sdwa v15, v11, v15 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 101e1ef9 0303060b
	v_add_u32_sdwa v28, v28, v17 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_2 ; 683822f9 0206061c
	v_add3_u32 v19, v19, v13, v14                               ; d1ff0013 043a1b13
	v_add_u32_sdwa v28, v28, v17 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_3 ; 683822f9 0306061c
	v_add_u32_e32 v19, v19, v15                                 ; 68261f13
	v_add_u32_e32 v28, v28, v5                                  ; 68380b1c
	v_add_u32_sdwa v28, v28, v18 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_1 ; 683824f9 0106061c
	v_add_u32_sdwa v28, v28, v18 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_2 ; 683824f9 0206061c
	v_add_u32_sdwa v28, v28, v18 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_3 ; 683824f9 0306061c
	v_add_u32_e32 v28, v28, v12                                 ; 6838191c
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_cvt_f32_f16_e32 v29, v20                                  ; 7e3a1714
	v_add_u32_sdwa v28, v28, v11 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_1 ; 683816f9 0106061c
	v_cvt_f32_f16_sdwa v20, v20 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e2816f9 00050614
	v_add_u32_sdwa v28, v28, v11 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_2 ; 683816f9 0206061c
	v_add_u32_sdwa v28, v28, v11 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_3 ; 683816f9 0306061c
	v_lshlrev_b32_e32 v28, 7, v28                               ; 24383887
	v_sub_u32_e32 v19, v19, v28                                 ; 6a263913
	v_cndmask_b32_e32 v28, v23, v22, vcc                        ; 00382d17
	v_cndmask_b32_e32 v23, v23, v21, vcc                        ; 002e2b17
	v_lshrrev_b32_e32 v21, v25, v21                             ; 202a2b19
	v_lshrrev_b32_e32 v25, v25, v22                             ; 20322d19
	v_cvt_f32_i32_e32 v19, v19                                  ; 7e260b13
	v_bfe_u32 v28, v28, v26, 4                                  ; d1c8001c 0212351c
	v_bfe_u32 v23, v23, v24, 4                                  ; d1c80017 02123117
	v_and_or_b32 v25, 48, v25, v28                              ; d2010019 047232b0
	v_and_or_b32 v21, 48, v21, v23                              ; d2010015 045e2ab0
	v_cvt_f32_ubyte0_e32 v25, v25                               ; 7e322319
	v_cvt_f32_ubyte0_e32 v21, v21                               ; 7e2a2315
	v_mul_f32_e32 v20, v20, v25                                 ; 0a283314
	v_mul_f32_e32 v29, v29, v21                                 ; 0a3a2b1d
	v_mul_f32_e32 v27, v27, v29                                 ; 0a363b1b
	v_mac_f32_e32 v2, v27, v19                                  ; 2c04271b
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
	s_cbranch_scc0 BB55                                         ; bf8400a6
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
	s_mov_b32 s5, 0x80808080                                    ; be8500ff 80808080
	s_mov_b32 s9, 0xf0f0f0f                                     ; be8900ff 0f0f0f0f
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
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_xor_b32_e32 v12, s5, v12                                  ; 2a181805
	v_xor_b32_e32 v13, s5, v13                                  ; 2a1a1a05
	v_xor_b32_e32 v14, s5, v14                                  ; 2a1c1c05
	v_xor_b32_e32 v15, s5, v15                                  ; 2a1e1e05
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_lshrrev_b32_e32 v18, v11, v18                             ; 2024250b
	v_lshrrev_b32_e32 v17, v11, v17                             ; 2022230b
	v_lshrrev_b32_e32 v16, v11, v16                             ; 2020210b
	v_lshrrev_b32_e32 v11, v11, v19                             ; 2016270b
	v_and_b32_e32 v32, 15, v17                                  ; 2640228f
	v_and_b32_e32 v17, s9, v17                                  ; 26222209
	v_and_b32_e32 v5, 15, v18                                   ; 260a248f
	v_and_b32_e32 v28, 15, v16                                  ; 2638208f
	v_and_b32_e32 v16, s9, v16                                  ; 26202009
	v_mul_u32_u24_sdwa v33, v32, v13 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_0 ; 10421af9 00060620
	v_mul_u32_u24_sdwa v4, v17, v13 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 10081af9 02020611
	v_mul_u32_u24_sdwa v34, v17, v13 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 10441af9 01010611
	v_and_b32_e32 v18, s9, v18                                  ; 26242409
	v_mul_u32_u24_sdwa v13, v17, v13 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 101a1af9 03030611
	v_mul_u32_u24_sdwa v6, v5, v14 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_0 ; 100c1cf9 00060605
	v_mul_u32_u24_sdwa v29, v28, v12 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_0 ; 103a18f9 0006061c
	v_mul_u32_u24_sdwa v31, v16, v12 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 103e18f9 02020610
	v_mul_u32_u24_sdwa v30, v16, v12 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 103c18f9 01010610
	v_mul_u32_u24_sdwa v12, v16, v12 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 101818f9 03030610
	v_mul_u32_u24_sdwa v7, v18, v14 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 100e1cf9 01010612
	v_mul_u32_u24_sdwa v10, v18, v14 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 10141cf9 02020612
	v_mul_u32_u24_sdwa v14, v18, v14 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 101c1cf9 03030612
	v_add3_u32 v31, v31, v29, v30                               ; d1ff001f 047a3b1f
	v_add_u32_sdwa v28, v28, v16 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_1 ; 683820f9 0106061c
	v_add3_u32 v33, v33, v31, v12                               ; d1ff0021 04323f21
	v_and_b32_e32 v12, 15, v11                                  ; 2618168f
	v_and_b32_e32 v11, s9, v11                                  ; 26161609
	v_add_u32_sdwa v28, v28, v16 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_2 ; 683820f9 0206061c
	v_add3_u32 v4, v4, v33, v34                                 ; d1ff0004 048a4304
	v_mul_u32_u24_sdwa v19, v11, v15 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 10261ef9 0202060b
	v_add_u32_sdwa v28, v28, v16 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_3 ; 683820f9 0306061c
	v_add3_u32 v6, v6, v4, v13                                  ; d1ff0006 04360906
	v_mul_u32_u24_sdwa v13, v12, v15 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_0 ; 101a1ef9 0006060c
	v_add_u32_e32 v28, v28, v32                                 ; 6838411c
	v_add3_u32 v10, v10, v6, v7                                 ; d1ff000a 041e0d0a
	v_add_u32_sdwa v28, v28, v17 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_1 ; 683822f9 0106061c
	v_add3_u32 v13, v13, v10, v14                               ; d1ff000d 043a150d
	v_mul_u32_u24_sdwa v14, v11, v15 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 101c1ef9 0101060b
	v_mul_u32_u24_sdwa v15, v11, v15 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 101e1ef9 0303060b
	v_add_u32_sdwa v28, v28, v17 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_2 ; 683822f9 0206061c
	v_add3_u32 v19, v19, v13, v14                               ; d1ff0013 043a1b13
	v_add_u32_sdwa v28, v28, v17 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_3 ; 683822f9 0306061c
	v_add_u32_e32 v19, v19, v15                                 ; 68261f13
	v_add_u32_e32 v28, v28, v5                                  ; 68380b1c
	v_add_u32_sdwa v28, v28, v18 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_1 ; 683824f9 0106061c
	v_add_u32_sdwa v28, v28, v18 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_2 ; 683824f9 0206061c
	v_add_u32_sdwa v28, v28, v18 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_3 ; 683824f9 0306061c
	v_add_u32_e32 v28, v28, v12                                 ; 6838191c
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_cvt_f32_f16_e32 v29, v20                                  ; 7e3a1714
	v_add_u32_sdwa v28, v28, v11 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_1 ; 683816f9 0106061c
	v_cvt_f32_f16_sdwa v20, v20 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e2816f9 00050614
	v_add_u32_sdwa v28, v28, v11 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_2 ; 683816f9 0206061c
	v_add_u32_sdwa v28, v28, v11 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_3 ; 683816f9 0306061c
	v_lshlrev_b32_e32 v28, 7, v28                               ; 24383887
	v_sub_u32_e32 v19, v19, v28                                 ; 6a263913
	v_cndmask_b32_e32 v28, v23, v22, vcc                        ; 00382d17
	v_cndmask_b32_e32 v23, v23, v21, vcc                        ; 002e2b17
	v_lshrrev_b32_e32 v21, v25, v21                             ; 202a2b19
	v_lshrrev_b32_e32 v25, v25, v22                             ; 20322d19
	v_cvt_f32_i32_e32 v19, v19                                  ; 7e260b13
	v_bfe_u32 v28, v28, v26, 4                                  ; d1c8001c 0212351c
	v_bfe_u32 v23, v23, v24, 4                                  ; d1c80017 02123117
	v_and_or_b32 v25, 48, v25, v28                              ; d2010019 047232b0
	v_and_or_b32 v21, 48, v21, v23                              ; d2010015 045e2ab0
	v_cvt_f32_ubyte0_e32 v25, v25                               ; 7e322319
	v_cvt_f32_ubyte0_e32 v21, v21                               ; 7e2a2315
	v_mul_f32_e32 v20, v20, v25                                 ; 0a283314
	v_mul_f32_e32 v29, v29, v21                                 ; 0a3a2b1d
	v_mul_f32_e32 v27, v27, v29                                 ; 0a363b1b
	v_mac_f32_e32 v2, v27, v19                                  ; 2c04271b
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
	s_cbranch_scc0 BB58                                         ; bf8400a6
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
	s_mov_b32 s4, 0x80808080                                    ; be8400ff 80808080
	s_mov_b32 s5, 0xf0f0f0f                                     ; be8500ff 0f0f0f0f
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
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_xor_b32_e32 v12, s4, v12                                  ; 2a181804
	v_xor_b32_e32 v13, s4, v13                                  ; 2a1a1a04
	v_xor_b32_e32 v14, s4, v14                                  ; 2a1c1c04
	v_xor_b32_e32 v15, s4, v15                                  ; 2a1e1e04
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_lshrrev_b32_e32 v18, v10, v18                             ; 2024250a
	v_lshrrev_b32_e32 v17, v10, v17                             ; 2022230a
	v_lshrrev_b32_e32 v16, v10, v16                             ; 2020210a
	v_lshrrev_b32_e32 v10, v10, v19                             ; 2014270a
	v_and_b32_e32 v31, 15, v17                                  ; 263e228f
	v_and_b32_e32 v17, s5, v17                                  ; 26222205
	v_and_b32_e32 v4, 15, v18                                   ; 2608248f
	v_and_b32_e32 v27, 15, v16                                  ; 2636208f
	v_and_b32_e32 v16, s5, v16                                  ; 26202005
	v_mul_u32_u24_sdwa v32, v31, v13 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_0 ; 10401af9 0006061f
	v_mul_u32_u24_sdwa v34, v17, v13 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 10441af9 02020611
	v_mul_u32_u24_sdwa v33, v17, v13 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 10421af9 01010611
	v_and_b32_e32 v18, s5, v18                                  ; 26242405
	v_mul_u32_u24_sdwa v13, v17, v13 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 101a1af9 03030611
	v_mul_u32_u24_sdwa v5, v4, v14 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_0 ; 100a1cf9 00060604
	v_mul_u32_u24_sdwa v28, v27, v12 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_0 ; 103818f9 0006061b
	v_mul_u32_u24_sdwa v30, v16, v12 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 103c18f9 02020610
	v_mul_u32_u24_sdwa v29, v16, v12 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 103a18f9 01010610
	v_mul_u32_u24_sdwa v12, v16, v12 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 101818f9 03030610
	v_and_b32_e32 v8, 15, v10                                   ; 2610148f
	v_mul_u32_u24_sdwa v6, v18, v14 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 100c1cf9 01010612
	v_mul_u32_u24_sdwa v7, v18, v14 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 100e1cf9 02020612
	v_mul_u32_u24_sdwa v14, v18, v14 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 101c1cf9 03030612
	v_and_b32_e32 v10, s5, v10                                  ; 26141405
	v_add3_u32 v30, v30, v28, v29                               ; d1ff001e 0476391e
	v_add_u32_sdwa v27, v27, v16 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_1 ; 683620f9 0106061b
	v_add3_u32 v32, v32, v30, v12                               ; d1ff0020 04323d20
	v_mul_u32_u24_sdwa v12, v8, v15 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_0 ; 10181ef9 00060608
	v_add_u32_sdwa v27, v27, v16 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_2 ; 683620f9 0206061b
	v_add3_u32 v34, v34, v32, v33                               ; d1ff0022 04864122
	v_add_u32_sdwa v27, v27, v16 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_3 ; 683620f9 0306061b
	v_add3_u32 v5, v5, v34, v13                                 ; d1ff0005 04364505
	v_mul_u32_u24_sdwa v13, v10, v15 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 101a1ef9 0101060a
	v_add_u32_e32 v27, v27, v31                                 ; 68363f1b
	v_add3_u32 v7, v7, v5, v6                                   ; d1ff0007 041a0b07
	v_add_u32_sdwa v27, v27, v17 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_1 ; 683622f9 0106061b
	v_add3_u32 v12, v12, v7, v14                                ; d1ff000c 043a0f0c
	v_mul_u32_u24_sdwa v14, v10, v15 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 101c1ef9 0202060a
	v_mul_u32_u24_sdwa v15, v10, v15 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 101e1ef9 0303060a
	v_add_u32_sdwa v27, v27, v17 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_2 ; 683622f9 0206061b
	v_add3_u32 v14, v14, v12, v13                               ; d1ff000e 0436190e
	v_add_u32_sdwa v27, v27, v17 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_3 ; 683622f9 0306061b
	v_add_u32_e32 v14, v14, v15                                 ; 681c1f0e
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_cndmask_b32_e32 v15, v23, v22, vcc                        ; 001e2d17
	v_cndmask_b32_e32 v23, v23, v21, vcc                        ; 002e2b17
	v_lshrrev_b32_e32 v21, v24, v21                             ; 202a2b18
	v_add_u32_e32 v27, v27, v4                                  ; 6836091b
	v_lshrrev_b32_e32 v24, v24, v22                             ; 20302d18
	v_bfe_u32 v15, v15, v25, 4                                  ; d1c8000f 0212330f
	v_bfe_u32 v23, v23, v11, 4                                  ; d1c80017 02121717
	v_cvt_f32_f16_e32 v16, v20                                  ; 7e201714
	v_add_u32_sdwa v27, v27, v18 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_1 ; 683624f9 0106061b
	v_and_or_b32 v24, 48, v24, v15                              ; d2010018 043e30b0
	v_cvt_f32_f16_sdwa v20, v20 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e2816f9 00050614
	v_and_or_b32 v21, 48, v21, v23                              ; d2010015 045e2ab0
	v_add_u32_sdwa v27, v27, v18 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_2 ; 683624f9 0206061b
	v_cvt_f32_ubyte0_e32 v24, v24                               ; 7e302318
	v_cvt_f32_ubyte0_e32 v21, v21                               ; 7e2a2315
	v_add_u32_sdwa v27, v27, v18 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_3 ; 683624f9 0306061b
	v_mul_f32_e32 v20, v20, v24                                 ; 0a283114
	v_mul_f32_e32 v16, v16, v21                                 ; 0a202b10
	v_add_u32_e32 v27, v27, v8                                  ; 6836111b
	v_mul_f32_e32 v26, v26, v16                                 ; 0a34211a
	v_add_u32_sdwa v27, v27, v10 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_1 ; 683614f9 0106061b
	v_add_u32_sdwa v27, v27, v10 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_2 ; 683614f9 0206061b
	v_add_u32_sdwa v27, v27, v10 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_3 ; 683614f9 0306061b
	v_lshlrev_b32_e32 v27, 7, v27                               ; 24363687
	v_sub_u32_e32 v14, v14, v27                                 ; 6a1c370e
	v_cvt_f32_i32_e32 v14, v14                                  ; 7e1c0b0e
	v_mac_f32_e32 v2, v26, v14                                  ; 2c041d1a
	v_mad_f32 v2, -v20, v9, v2                                  ; d1c10002 240a1314
BB58:
	v_add_u32_e32 v3, -4, v3                                    ; 680606c4
	v_add_u32_e32 v1, 0x1000, v1                                ; 680202ff 00001000
	s_branch BB41                                               ; bf82fd14
BB59:
	s_mov_b64 exec, -1                                          ; befe01c1
	v_cmpx_le_u32_e32 vcc, 2, v3                                ; 7db60682
	s_cbranch_execz BB71                                        ; bf880178
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
	s_cbranch_scc0 BB63                                         ; bf8400a6
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
	s_mov_b32 s5, 0x80808080                                    ; be8500ff 80808080
	s_mov_b32 s9, 0xf0f0f0f                                     ; be8900ff 0f0f0f0f
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
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_xor_b32_e32 v12, s5, v12                                  ; 2a181805
	v_xor_b32_e32 v13, s5, v13                                  ; 2a1a1a05
	v_xor_b32_e32 v14, s5, v14                                  ; 2a1c1c05
	v_xor_b32_e32 v15, s5, v15                                  ; 2a1e1e05
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_lshrrev_b32_e32 v18, v11, v18                             ; 2024250b
	v_lshrrev_b32_e32 v17, v11, v17                             ; 2022230b
	v_lshrrev_b32_e32 v16, v11, v16                             ; 2020210b
	v_lshrrev_b32_e32 v11, v11, v19                             ; 2016270b
	v_and_b32_e32 v32, 15, v17                                  ; 2640228f
	v_and_b32_e32 v17, s9, v17                                  ; 26222209
	v_and_b32_e32 v5, 15, v18                                   ; 260a248f
	v_and_b32_e32 v28, 15, v16                                  ; 2638208f
	v_and_b32_e32 v16, s9, v16                                  ; 26202009
	v_mul_u32_u24_sdwa v33, v32, v13 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_0 ; 10421af9 00060620
	v_mul_u32_u24_sdwa v4, v17, v13 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 10081af9 02020611
	v_mul_u32_u24_sdwa v34, v17, v13 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 10441af9 01010611
	v_and_b32_e32 v18, s9, v18                                  ; 26242409
	v_mul_u32_u24_sdwa v13, v17, v13 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 101a1af9 03030611
	v_mul_u32_u24_sdwa v6, v5, v14 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_0 ; 100c1cf9 00060605
	v_mul_u32_u24_sdwa v29, v28, v12 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_0 ; 103a18f9 0006061c
	v_mul_u32_u24_sdwa v31, v16, v12 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 103e18f9 02020610
	v_mul_u32_u24_sdwa v30, v16, v12 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 103c18f9 01010610
	v_mul_u32_u24_sdwa v12, v16, v12 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 101818f9 03030610
	v_mul_u32_u24_sdwa v9, v18, v14 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 10121cf9 01010612
	v_mul_u32_u24_sdwa v10, v18, v14 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 10141cf9 02020612
	v_mul_u32_u24_sdwa v14, v18, v14 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 101c1cf9 03030612
	v_add3_u32 v31, v31, v29, v30                               ; d1ff001f 047a3b1f
	v_add_u32_sdwa v28, v28, v16 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_1 ; 683820f9 0106061c
	v_add3_u32 v33, v33, v31, v12                               ; d1ff0021 04323f21
	v_and_b32_e32 v12, 15, v11                                  ; 2618168f
	v_and_b32_e32 v11, s9, v11                                  ; 26161609
	v_add_u32_sdwa v28, v28, v16 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_2 ; 683820f9 0206061c
	v_add3_u32 v4, v4, v33, v34                                 ; d1ff0004 048a4304
	v_mul_u32_u24_sdwa v19, v11, v15 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 10261ef9 0202060b
	v_add_u32_sdwa v28, v28, v16 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_3 ; 683820f9 0306061c
	v_add3_u32 v6, v6, v4, v13                                  ; d1ff0006 04360906
	v_mul_u32_u24_sdwa v13, v12, v15 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_0 ; 101a1ef9 0006060c
	v_add_u32_e32 v28, v28, v32                                 ; 6838411c
	v_add3_u32 v10, v10, v6, v9                                 ; d1ff000a 04260d0a
	v_add_u32_sdwa v28, v28, v17 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_1 ; 683822f9 0106061c
	v_add3_u32 v13, v13, v10, v14                               ; d1ff000d 043a150d
	v_mul_u32_u24_sdwa v14, v11, v15 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 101c1ef9 0101060b
	v_mul_u32_u24_sdwa v15, v11, v15 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 101e1ef9 0303060b
	v_add_u32_sdwa v28, v28, v17 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_2 ; 683822f9 0206061c
	v_add3_u32 v19, v19, v13, v14                               ; d1ff0013 043a1b13
	v_add_u32_sdwa v28, v28, v17 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_3 ; 683822f9 0306061c
	v_add_u32_e32 v19, v19, v15                                 ; 68261f13
	v_add_u32_e32 v28, v28, v5                                  ; 68380b1c
	v_add_u32_sdwa v28, v28, v18 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_1 ; 683824f9 0106061c
	v_add_u32_sdwa v28, v28, v18 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_2 ; 683824f9 0206061c
	v_add_u32_sdwa v28, v28, v18 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_3 ; 683824f9 0306061c
	v_add_u32_e32 v28, v28, v12                                 ; 6838191c
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_cvt_f32_f16_e32 v29, v20                                  ; 7e3a1714
	v_add_u32_sdwa v28, v28, v11 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_1 ; 683816f9 0106061c
	v_cvt_f32_f16_sdwa v20, v20 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e2816f9 00050614
	v_add_u32_sdwa v28, v28, v11 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_2 ; 683816f9 0206061c
	v_add_u32_sdwa v28, v28, v11 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_3 ; 683816f9 0306061c
	v_lshlrev_b32_e32 v28, 7, v28                               ; 24383887
	v_sub_u32_e32 v19, v19, v28                                 ; 6a263913
	v_cndmask_b32_e32 v28, v23, v22, vcc                        ; 00382d17
	v_cndmask_b32_e32 v23, v23, v21, vcc                        ; 002e2b17
	v_lshrrev_b32_e32 v21, v25, v21                             ; 202a2b19
	v_lshrrev_b32_e32 v25, v25, v22                             ; 20322d19
	v_cvt_f32_i32_e32 v19, v19                                  ; 7e260b13
	v_bfe_u32 v28, v28, v26, 4                                  ; d1c8001c 0212351c
	v_bfe_u32 v23, v23, v24, 4                                  ; d1c80017 02123117
	v_and_or_b32 v25, 48, v25, v28                              ; d2010019 047232b0
	v_and_or_b32 v21, 48, v21, v23                              ; d2010015 045e2ab0
	v_cvt_f32_ubyte0_e32 v25, v25                               ; 7e322319
	v_cvt_f32_ubyte0_e32 v21, v21                               ; 7e2a2315
	v_mul_f32_e32 v20, v20, v25                                 ; 0a283314
	v_mul_f32_e32 v29, v29, v21                                 ; 0a3a2b1d
	v_mul_f32_e32 v27, v27, v29                                 ; 0a363b1b
	v_mac_f32_e32 v2, v27, v19                                  ; 2c04271b
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
	s_cbranch_scc0 BB66                                         ; bf8400a6
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
	s_mov_b32 s4, 0x80808080                                    ; be8400ff 80808080
	s_mov_b32 s5, 0xf0f0f0f                                     ; be8500ff 0f0f0f0f
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
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_xor_b32_e32 v12, s4, v12                                  ; 2a181804
	v_xor_b32_e32 v13, s4, v13                                  ; 2a1a1a04
	v_xor_b32_e32 v14, s4, v14                                  ; 2a1c1c04
	v_xor_b32_e32 v15, s4, v15                                  ; 2a1e1e04
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_lshrrev_b32_e32 v18, v10, v18                             ; 2024250a
	v_lshrrev_b32_e32 v17, v10, v17                             ; 2022230a
	v_lshrrev_b32_e32 v16, v10, v16                             ; 2020210a
	v_lshrrev_b32_e32 v10, v10, v19                             ; 2014270a
	v_and_b32_e32 v31, 15, v17                                  ; 263e228f
	v_and_b32_e32 v17, s5, v17                                  ; 26222205
	v_and_b32_e32 v4, 15, v18                                   ; 2608248f
	v_and_b32_e32 v27, 15, v16                                  ; 2636208f
	v_and_b32_e32 v16, s5, v16                                  ; 26202005
	v_mul_u32_u24_sdwa v32, v31, v13 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_0 ; 10401af9 0006061f
	v_mul_u32_u24_sdwa v34, v17, v13 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 10441af9 02020611
	v_mul_u32_u24_sdwa v33, v17, v13 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 10421af9 01010611
	v_and_b32_e32 v18, s5, v18                                  ; 26242405
	v_mul_u32_u24_sdwa v13, v17, v13 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 101a1af9 03030611
	v_mul_u32_u24_sdwa v5, v4, v14 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_0 ; 100a1cf9 00060604
	v_mul_u32_u24_sdwa v28, v27, v12 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_0 ; 103818f9 0006061b
	v_mul_u32_u24_sdwa v30, v16, v12 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 103c18f9 02020610
	v_mul_u32_u24_sdwa v29, v16, v12 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 103a18f9 01010610
	v_mul_u32_u24_sdwa v12, v16, v12 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 101818f9 03030610
	v_and_b32_e32 v8, 15, v10                                   ; 2610148f
	v_mul_u32_u24_sdwa v6, v18, v14 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 100c1cf9 01010612
	v_mul_u32_u24_sdwa v7, v18, v14 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 100e1cf9 02020612
	v_mul_u32_u24_sdwa v14, v18, v14 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 101c1cf9 03030612
	v_and_b32_e32 v10, s5, v10                                  ; 26141405
	v_add3_u32 v30, v30, v28, v29                               ; d1ff001e 0476391e
	v_add_u32_sdwa v27, v27, v16 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_1 ; 683620f9 0106061b
	v_add3_u32 v32, v32, v30, v12                               ; d1ff0020 04323d20
	v_mul_u32_u24_sdwa v12, v8, v15 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_0 ; 10181ef9 00060608
	v_add_u32_sdwa v27, v27, v16 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_2 ; 683620f9 0206061b
	v_add3_u32 v34, v34, v32, v33                               ; d1ff0022 04864122
	v_add_u32_sdwa v27, v27, v16 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_3 ; 683620f9 0306061b
	v_add3_u32 v5, v5, v34, v13                                 ; d1ff0005 04364505
	v_mul_u32_u24_sdwa v13, v10, v15 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 101a1ef9 0101060a
	v_add_u32_e32 v27, v27, v31                                 ; 68363f1b
	v_add3_u32 v7, v7, v5, v6                                   ; d1ff0007 041a0b07
	v_add_u32_sdwa v27, v27, v17 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_1 ; 683622f9 0106061b
	v_add3_u32 v12, v12, v7, v14                                ; d1ff000c 043a0f0c
	v_mul_u32_u24_sdwa v14, v10, v15 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 101c1ef9 0202060a
	v_mul_u32_u24_sdwa v15, v10, v15 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 101e1ef9 0303060a
	v_add_u32_sdwa v27, v27, v17 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_2 ; 683622f9 0206061b
	v_add3_u32 v14, v14, v12, v13                               ; d1ff000e 0436190e
	v_add_u32_sdwa v27, v27, v17 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_3 ; 683622f9 0306061b
	v_add_u32_e32 v14, v14, v15                                 ; 681c1f0e
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_cndmask_b32_e32 v15, v23, v22, vcc                        ; 001e2d17
	v_cndmask_b32_e32 v23, v23, v21, vcc                        ; 002e2b17
	v_lshrrev_b32_e32 v21, v24, v21                             ; 202a2b18
	v_add_u32_e32 v27, v27, v4                                  ; 6836091b
	v_lshrrev_b32_e32 v24, v24, v22                             ; 20302d18
	v_bfe_u32 v15, v15, v25, 4                                  ; d1c8000f 0212330f
	v_bfe_u32 v23, v23, v11, 4                                  ; d1c80017 02121717
	v_cvt_f32_f16_e32 v16, v20                                  ; 7e201714
	v_add_u32_sdwa v27, v27, v18 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_1 ; 683624f9 0106061b
	v_and_or_b32 v24, 48, v24, v15                              ; d2010018 043e30b0
	v_cvt_f32_f16_sdwa v20, v20 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e2816f9 00050614
	v_and_or_b32 v21, 48, v21, v23                              ; d2010015 045e2ab0
	v_add_u32_sdwa v27, v27, v18 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_2 ; 683624f9 0206061b
	v_cvt_f32_ubyte0_e32 v24, v24                               ; 7e302318
	v_cvt_f32_ubyte0_e32 v21, v21                               ; 7e2a2315
	v_add_u32_sdwa v27, v27, v18 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_3 ; 683624f9 0306061b
	v_mul_f32_e32 v20, v20, v24                                 ; 0a283114
	v_mul_f32_e32 v16, v16, v21                                 ; 0a202b10
	v_add_u32_e32 v27, v27, v8                                  ; 6836111b
	v_mul_f32_e32 v26, v26, v16                                 ; 0a34211a
	v_add_u32_sdwa v27, v27, v10 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_1 ; 683614f9 0106061b
	v_add_u32_sdwa v27, v27, v10 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_2 ; 683614f9 0206061b
	v_add_u32_sdwa v27, v27, v10 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_3 ; 683614f9 0306061b
	v_lshlrev_b32_e32 v27, 7, v27                               ; 24363687
	v_sub_u32_e32 v14, v14, v27                                 ; 6a1c370e
	v_cvt_f32_i32_e32 v14, v14                                  ; 7e1c0b0e
	v_mac_f32_e32 v2, v26, v14                                  ; 2c041d1a
	v_mad_f32 v2, -v20, v9, v2                                  ; d1c10002 240a1314
BB66:
	v_add_u32_e32 v3, -2, v3                                    ; 680606c2
	v_add_u32_e32 v1, 0x800, v1                                 ; 680202ff 00000800
	s_mov_b32 s5, src_scc                                       ; be8500fd
BB71:
	s_mov_b64 exec, -1                                          ; befe01c1
	v_cmpx_ne_i32_e32 vcc, 0, v3                                ; 7daa0680
	s_cbranch_execz BB80                                        ; bf8800be
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
	s_cbranch_scc0 BB75                                         ; bf8400a6
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
	s_mov_b32 s3, 0x80808080                                    ; be8300ff 80808080
	s_mov_b32 s4, 0xf0f0f0f                                     ; be8400ff 0f0f0f0f
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
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_xor_b32_e32 v8, s3, v8                                    ; 2a101003
	v_xor_b32_e32 v9, s3, v9                                    ; 2a121203
	v_xor_b32_e32 v10, s3, v10                                  ; 2a141403
	v_xor_b32_e32 v11, s3, v11                                  ; 2a161603
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_lshrrev_b32_e32 v14, v20, v14                             ; 201c1d14
	v_lshrrev_b32_e32 v13, v20, v13                             ; 201a1b14
	v_lshrrev_b32_e32 v12, v20, v12                             ; 20181914
	v_lshrrev_b32_e32 v20, v20, v15                             ; 20281f14
	v_and_b32_e32 v29, 15, v13                                  ; 263a1a8f
	v_and_b32_e32 v13, s4, v13                                  ; 261a1a04
	v_and_b32_e32 v33, 15, v14                                  ; 26421c8f
	v_and_b32_e32 v25, 15, v12                                  ; 2632188f
	v_and_b32_e32 v12, s4, v12                                  ; 26181804
	v_mul_u32_u24_sdwa v30, v29, v9 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_0 ; 103c12f9 0006061d
	v_mul_u32_u24_sdwa v32, v13, v9 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 104012f9 0202060d
	v_mul_u32_u24_sdwa v31, v13, v9 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 103e12f9 0101060d
	v_and_b32_e32 v14, s4, v14                                  ; 261c1c04
	v_mul_u32_u24_sdwa v9, v13, v9 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 101212f9 0303060d
	v_mul_u32_u24_sdwa v34, v33, v10 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_0 ; 104414f9 00060621
	v_mul_u32_u24_sdwa v26, v25, v8 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_0 ; 103410f9 00060619
	v_mul_u32_u24_sdwa v28, v12, v8 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 103810f9 0202060c
	v_mul_u32_u24_sdwa v27, v12, v8 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 103610f9 0101060c
	v_mul_u32_u24_sdwa v8, v12, v8 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 101010f9 0303060c
	v_and_b32_e32 v3, 15, v20                                   ; 2606288f
	v_mul_u32_u24_sdwa v0, v14, v10 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 100014f9 0101060e
	v_mul_u32_u24_sdwa v1, v14, v10 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 100214f9 0202060e
	v_mul_u32_u24_sdwa v10, v14, v10 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 101414f9 0303060e
	v_and_b32_e32 v20, s4, v20                                  ; 26282804
	v_add3_u32 v28, v28, v26, v27                               ; d1ff001c 046e351c
	v_mul_u32_u24_sdwa v4, v3, v11 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_0 ; 100816f9 00060603
	v_add_u32_sdwa v25, v25, v12 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_1 ; 683218f9 01060619
	v_mul_u32_u24_sdwa v5, v20, v11 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_1 ; 100a16f9 01010614
	v_mul_u32_u24_sdwa v7, v20, v11 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 100e16f9 02020614
	v_mul_u32_u24_sdwa v11, v20, v11 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 src1_sel:BYTE_3 ; 101616f9 03030614
	v_add3_u32 v30, v30, v28, v8                                ; d1ff001e 0422391e
	v_add_u32_sdwa v25, v25, v12 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_2 ; 683218f9 02060619
	v_add3_u32 v32, v32, v30, v31                               ; d1ff0020 047e3d20
	v_add_u32_sdwa v25, v25, v12 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_3 ; 683218f9 03060619
	v_add3_u32 v34, v34, v32, v9                                ; d1ff0022 04264122
	v_add_u32_e32 v25, v25, v29                                 ; 68323b19
	v_add3_u32 v1, v1, v34, v0                                  ; d1ff0001 04024501
	v_add_u32_sdwa v25, v25, v13 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_1 ; 68321af9 01060619
	v_add3_u32 v4, v4, v1, v10                                  ; d1ff0004 042a0304
	v_add_u32_sdwa v25, v25, v13 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_2 ; 68321af9 02060619
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_cndmask_b32_e32 v8, v19, v18, vcc                         ; 00102513
	v_cndmask_b32_e32 v19, v19, v17, vcc                        ; 00262313
	v_add3_u32 v7, v7, v4, v5                                   ; d1ff0007 04160907
	v_add_u32_sdwa v25, v25, v13 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_3 ; 68321af9 03060619
	v_lshrrev_b32_e32 v17, v22, v17                             ; 20222316
	v_bfe_u32 v19, v19, v21, 4                                  ; d1c80013 02122b13
	v_add_u32_e32 v7, v7, v11                                   ; 680e1707
	v_bfe_u32 v8, v8, v23, 4                                    ; d1c80008 02122f08
	v_lshrrev_b32_e32 v22, v22, v18                             ; 202c2516
	v_add_u32_e32 v25, v25, v33                                 ; 68324319
	v_and_or_b32 v17, 48, v17, v19                              ; d2010011 044e22b0
	v_cvt_f32_f16_e32 v9, v16                                   ; 7e121710
	v_cvt_f32_f16_sdwa v16, v16 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e2016f9 00050610
	v_and_or_b32 v22, 48, v22, v8                               ; d2010016 04222cb0
	v_add_u32_sdwa v25, v25, v14 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_1 ; 68321cf9 01060619
	v_cvt_f32_ubyte0_e32 v17, v17                               ; 7e222311
	v_cvt_f32_ubyte0_e32 v22, v22                               ; 7e2c2316
	v_add_u32_sdwa v25, v25, v14 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_2 ; 68321cf9 02060619
	v_mul_f32_e32 v9, v9, v17                                   ; 0a122309
	v_mul_f32_e32 v16, v16, v22                                 ; 0a202d10
	v_add_u32_sdwa v25, v25, v14 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_3 ; 68321cf9 03060619
	v_mul_f32_e32 v24, v24, v9                                  ; 0a301318
	v_add_u32_e32 v25, v25, v3                                  ; 68320719
	v_add_u32_sdwa v25, v25, v20 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_1 ; 683228f9 01060619
	v_add_u32_sdwa v25, v25, v20 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_2 ; 683228f9 02060619
	v_add_u32_sdwa v25, v25, v20 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_3 ; 683228f9 03060619
	v_lshlrev_b32_e32 v25, 7, v25                               ; 24323287
	v_sub_u32_e32 v7, v7, v25                                   ; 6a0e3307
	v_cvt_f32_i32_e32 v7, v7                                    ; 7e0e0b07
	v_mac_f32_e32 v2, v24, v7                                   ; 2c040f18
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
