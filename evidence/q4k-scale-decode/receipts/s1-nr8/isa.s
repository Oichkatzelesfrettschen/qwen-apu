BB0:
	s_load_dword s0, s[14:15], 0x0                              ; c0020007 00000000
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_mul_i32 s0, s0, s18                                       ; 92001200
	s_add_u32 s16, s16, s0                                      ; 80100010
	s_lshl_b32 s16, s16, 3                                      ; 8e108310
	s_add_u32 s1, s16, 8                                        ; 80018810
	s_cmp_ge_u32 s4, s1                                         ; bf090104
	s_cbranch_scc0 BB66                                         ; bf840562
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
	v_mov_b32_e32 v7, 0                                         ; 7e0e0280
	s_mul_i32 s18, s18, s5                                      ; 92120512
	v_mov_b32_e32 v8, 0                                         ; 7e100280
	v_mov_b32_e32 v9, 0                                         ; 7e120280
	v_sub_u32_e32 v1, v2, v1                                    ; 6a020302
	v_bfe_u32 v3, v2, 2, 1                                      ; d1c80003 02050502
	v_lshrrev_b32_e32 v2, 3, v2                                 ; 20040483
	v_mov_b32_e32 v10, 0                                        ; 7e140280
	v_mov_b32_e32 v11, 0                                        ; 7e160280
	v_mov_b32_e32 v12, 0                                        ; 7e180280
	v_mov_b32_e32 v13, 0                                        ; 7e1a0280
	v_lshl_add_u32 v1, v1, 1, v3                                ; d1fd0001 040d0301
	v_mov_b32_e32 v3, 0                                         ; 7e060280
	v_lshlrev_b32_e32 v5, 4, v2                                 ; 240a0484
	v_lshlrev_b32_e32 v1, 2, v1                                 ; 24020282
	v_sub_u32_e32 v6, 16, v5                                    ; 6a0c0a90
	v_lshl_add_u32 v4, v2, 5, v1                                ; d1fd0004 04050b02
	v_lshl_add_u32 v1, v2, 6, v1                                ; d1fd0001 04050d02
	s_branch BB5                                                ; bf820337
	s_nop 0                                                     ; bf800000
	(then repeated 3 times)
BB10:
	s_mov_b64 exec, s[0:1]                                      ; befe0100
	s_mov_b32 s0, s2                                            ; be800002
	s_movk_i32 s1, 0x8000                                       ; b0018000
	s_load_dwordx8 s[24:31], s[0:1], 0x0                        ; c00e0600 00000000
	s_mul_i32 s0, s6, s17                                       ; 92001106
	v_lshl_add_u32 v14, v0, 8, v1                               ; d1fd000e 04051100
	v_add_u32_e32 v15, s0, v14                                  ; 681e1c00
	v_add_u32_e32 v14, 0x80, v14                                ; 681c1cff 00000080
	v_lshrrev_b32_e32 v15, 2, v15                               ; 201e1e82
	v_add_u32_e32 v14, s0, v14                                  ; 681c1c00
	v_lshlrev_b32_e32 v15, 4, v15                               ; 241e1e84
	v_lshrrev_b32_e32 v14, 2, v14                               ; 201c1c82
	v_lshlrev_b32_e32 v14, 4, v14                               ; 241c1c84
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_load_dwordx4 v[16:19], v15, s[28:31], 0 offen        ; e05c1000 8007100f
	buffer_load_dwordx4 v[20:23], v15, s[28:31], 0 offen offset:128 ; e05c1080 8007140f
	buffer_load_dwordx4 v[24:27], v14, s[28:31], 0 offen        ; e05c1000 8007180e
	buffer_load_dwordx4 v[28:31], v14, s[28:31], 0 offen offset:128 ; e05c1080 80071c0e
	s_mul_i32 s1, s16, s3                                       ; 92010310
	v_lshl_add_u32 v34, v2, 1, 8                                ; d1fd0022 02210302
	v_add_u32_e32 v38, 64, v4                                   ; 684c08c0
	s_add_u32 s1, s18, s1                                       ; 80010112
	s_add_u32 s4, s16, 1                                        ; 80048110
	v_add_u32_e32 v32, s1, v0                                   ; 68400001
	s_mul_i32 s4, s4, s3                                        ; 92040304
	v_lshlrev_b32_e32 v33, 4, v32                               ; 24424084
	s_add_u32 s4, s18, s4                                       ; 80040412
	s_add_u32 s5, s16, 2                                        ; 80058210
	v_lshl_add_u32 v32, v32, 7, v33                             ; d1fd0020 04850f20
	v_add_u32_e32 v39, s4, v0                                   ; 684e0004
	s_mul_i32 s5, s5, s3                                        ; 92050305
	v_add_u32_e32 v36, 16, v32                                  ; 68484090
	v_add3_u32 v35, v34, 4, v32                                 ; d1ff0023 04810922
	v_lshlrev_b32_e32 v40, 4, v39                               ; 24504e84
	s_add_u32 s5, s18, s5                                       ; 80050512
	v_add_u32_e32 v37, v36, v4                                  ; 684a0924
	v_add_u32_e32 v36, v36, v38                                 ; 68484d24
	s_add_u32 s9, s16, 3                                        ; 80098310
	v_lshl_add_u32 v39, v39, 7, v40                             ; d1fd0027 04a10f27
	v_add_u32_e32 v44, s5, v0                                   ; 68580005
	s_mul_i32 s9, s9, s3                                        ; 92090309
	v_add3_u32 v41, v34, 4, v39                                 ; d1ff0029 049d0922
	v_add_u32_e32 v42, 16, v39                                  ; 68544e90
	v_lshlrev_b32_e32 v45, 4, v44                               ; 245a5884
	s_add_u32 s9, s18, s9                                       ; 80090912
	v_add_u32_e32 v43, v42, v4                                  ; 6856092a
	v_add_u32_e32 v42, v42, v38                                 ; 68544d2a
	v_lshl_add_u32 v44, v44, 7, v45                             ; d1fd002c 04b50f2c
	v_add_u32_e32 v49, s9, v0                                   ; 68620009
	v_add_u32_e32 v47, 16, v44                                  ; 685e5890
	v_add3_u32 v46, v34, 4, v44                                 ; d1ff002e 04b10922
	v_lshlrev_b32_e32 v50, 4, v49                               ; 24646284
	v_add_u32_e32 v48, v47, v4                                  ; 6860092f
	v_add_u32_e32 v47, v47, v38                                 ; 685e4d2f
	v_lshl_add_u32 v49, v49, 7, v50                             ; d1fd0031 04c90f31
	buffer_load_dwordx3 v[51:53], v32, s[24:27], 0 offen        ; e0581000 80063320
	buffer_load_ushort v35, v35, s[24:27], 0 offen              ; e0481000 80062323
	buffer_load_dword v37, v37, s[24:27], 0 offen               ; e0501000 80062525
	buffer_load_dword v36, v36, s[24:27], 0 offen               ; e0501000 80062424
	buffer_load_dwordx3 v[54:56], v39, s[24:27], 0 offen        ; e0581000 80063627
	buffer_load_ushort v41, v41, s[24:27], 0 offen              ; e0481000 80062929
	buffer_load_dword v43, v43, s[24:27], 0 offen               ; e0501000 80062b2b
	buffer_load_dword v42, v42, s[24:27], 0 offen               ; e0501000 80062a2a
	buffer_load_dwordx3 v[57:59], v44, s[24:27], 0 offen        ; e0581000 8006392c
	buffer_load_ushort v46, v46, s[24:27], 0 offen              ; e0481000 80062e2e
	buffer_load_dword v48, v48, s[24:27], 0 offen               ; e0501000 80063030
	buffer_load_dword v47, v47, s[24:27], 0 offen               ; e0501000 80062f2f
	buffer_load_dwordx3 v[60:62], v49, s[24:27], 0 offen        ; e0581000 80063c31
	s_bfm_b32 s10, 16, 16                                       ; 910a9090
	s_mov_b32 s11, 0xf0f0f0f                                    ; be8b00ff 0f0f0f0f
	s_mov_b32 s12, 0xc0c0c0c0                                   ; be8c00ff c0c0c0c0
	s_mov_b32 s13, 0x3f3f3f3f                                   ; be8d00ff 3f3f3f3f
	s_waitcnt vmcnt(16)                                         ; bf8c7f70
	v_add_f32_e32 v14, v16, v17                                 ; 021c2310
	s_waitcnt vmcnt(15)                                         ; bf8c3f7f
	v_add_f32_e32 v15, v20, v21                                 ; 021e2b14
	v_add_f32_e32 v14, v14, v18                                 ; 021c250e
	s_waitcnt vmcnt(14)                                         ; bf8c3f7e
	v_add_f32_e32 v32, v24, v25                                 ; 02403318
	v_add_f32_e32 v15, v15, v22                                 ; 021e2d0f
	s_waitcnt vmcnt(13)                                         ; bf8c3f7d
	v_add_f32_e32 v33, v28, v29                                 ; 02423b1c
	v_add_f32_e32 v14, v14, v19                                 ; 021c270e
	v_add_f32_e32 v32, v32, v26                                 ; 02403520
	v_add_f32_e32 v15, v15, v23                                 ; 021e2f0f
	v_add_f32_e32 v33, v33, v30                                 ; 02423d21
	v_add_f32_e32 v32, v32, v27                                 ; 02403720
	v_add_f32_e32 v33, v33, v31                                 ; 02423f21
	s_waitcnt vmcnt(12)                                         ; bf8c3f7c
	v_bfe_u32 v52, v52, v5, 16                                  ; d1c80034 02420b34
	v_lshlrev_b32_e32 v53, v6, v53                              ; 246a6b06
	s_waitcnt vmcnt(11)                                         ; bf8c3f7b
	v_lshl_or_b32 v35, v35, 12, v35                             ; d2000023 048d1923
	s_waitcnt vmcnt(10)                                         ; bf8c3f7a
	v_and_b32_e32 v40, s11, v37                                 ; 26504a0b
	v_lshrrev_b32_e32 v37, 4, v37                               ; 204a4a84
	v_and_or_b32 v53, s10, v53, v52                             ; d2010035 04d26a0a
	v_cvt_f32_ubyte2_e32 v45, v40                               ; 7e5a2728
	v_cvt_f32_ubyte3_e32 v44, v40                               ; 7e582928
	v_cvt_f32_ubyte1_e32 v50, v40                               ; 7e642528
	v_cvt_f32_ubyte0_e32 v40, v40                               ; 7e502328
	v_and_b32_e32 v37, s11, v37                                 ; 264a4a0b
	v_and_b32_e32 v39, s12, v53                                 ; 264e6a0c
	v_and_b32_e32 v53, s13, v53                                 ; 266a6a0d
	v_mul_f32_e32 v44, v19, v44                                 ; 0a585913
	v_cvt_f32_ubyte3_e32 v52, v37                               ; 7e682925
	v_lshrrev_b32_e32 v39, 2, v39                               ; 204e4e82
	v_mac_f32_e32 v44, v18, v45                                 ; 2c585b12
	s_waitcnt vmcnt(9)                                          ; bf8c3f79
	v_and_b32_e32 v45, s11, v36                                 ; 265a480b
	v_mul_f32_e32 v52, v23, v52                                 ; 0a686917
	v_and_or_b32 v35, s11, v35, v39                             ; d2010023 049e460b
	v_cvt_f32_ubyte2_e32 v39, v37                               ; 7e4e2725
	v_mac_f32_e32 v44, v17, v50                                 ; 2c586511
	v_cvt_f32_ubyte3_e32 v50, v45                               ; 7e64292d
	v_lshrrev_b32_e32 v36, 4, v36                               ; 20484884
	v_mac_f32_e32 v52, v22, v39                                 ; 2c684f16
	v_cvt_f32_ubyte1_e32 v39, v45                               ; 7e4e252d
	v_mac_f32_e32 v44, v16, v40                                 ; 2c585110
	v_cvt_f32_ubyte1_e32 v40, v37                               ; 7e502525
	v_cvt_f32_ubyte0_e32 v37, v37                               ; 7e4a2325
	v_mul_f32_e32 v50, v27, v50                                 ; 0a64651b
	v_and_b32_e32 v36, s11, v36                                 ; 2648480b
	v_mac_f32_e32 v52, v21, v40                                 ; 2c685115
	v_cvt_f32_ubyte3_e32 v40, v36                               ; 7e502924
	v_mac_f32_e32 v52, v20, v37                                 ; 2c684b14
	v_cvt_f32_ubyte2_e32 v37, v45                               ; 7e4a272d
	v_cvt_f32_ubyte0_e32 v45, v45                               ; 7e5a232d
	v_mul_f32_e32 v40, v31, v40                                 ; 0a50511f
	v_mac_f32_e32 v50, v26, v37                                 ; 2c644b1a
	v_cvt_f32_ubyte1_e32 v37, v36                               ; 7e4a2524
	v_mac_f32_e32 v50, v25, v39                                 ; 2c644f19
	v_cvt_f32_ubyte3_e32 v39, v35                               ; 7e4e2923
	v_mac_f32_e32 v50, v24, v45                                 ; 2c645b18
	v_cvt_f32_ubyte2_e32 v45, v36                               ; 7e5a2724
	v_cvt_f32_ubyte0_e32 v36, v36                               ; 7e482324
	v_mul_f32_e32 v39, v33, v39                                 ; 0a4e4f21
	v_mac_f32_e32 v40, v30, v45                                 ; 2c505b1e
	v_cvt_f32_ubyte2_e32 v45, v35                               ; 7e5a2723
	v_mac_f32_e32 v40, v29, v37                                 ; 2c504b1d
	v_cvt_f32_ubyte2_e32 v37, v53                               ; 7e4a2735
	v_mac_f32_e32 v39, v32, v45                                 ; 2c4e5b20
	v_mac_f32_e32 v40, v28, v36                                 ; 2c50491c
	v_cvt_f32_ubyte3_e32 v36, v53                               ; 7e482935
	v_mac_f32_e32 v39, v15, v36                                 ; 2c4e490f
	v_add3_u32 v36, v34, 4, v49                                 ; d1ff0024 04c50922
	v_add_u32_e32 v49, 16, v49                                  ; 68626290
	v_mac_f32_e32 v39, v14, v37                                 ; 2c4e4b0e
	v_add_u32_e32 v37, v49, v4                                  ; 684a0931
	v_add_u32_e32 v49, v49, v38                                 ; 68624d31
	buffer_load_ushort v36, v36, s[24:27], 0 offen              ; e0481000 80062424
	buffer_load_dword v37, v37, s[24:27], 0 offen               ; e0501000 80062525
	buffer_load_dword v49, v49, s[24:27], 0 offen               ; e0501000 80063131
	v_cvt_f32_ubyte1_e32 v45, v35                               ; 7e5a2523
	v_cvt_f32_ubyte0_e32 v35, v35                               ; 7e462323
	s_add_u32 s14, s16, 4                                       ; 800e8410
	v_mul_f32_e32 v40, v40, v45                                 ; 0a505b28
	v_cvt_f32_ubyte1_e32 v45, v53                               ; 7e5a2535
	v_cvt_f32_ubyte0_e32 v53, v53                               ; 7e6a2335
	s_mul_i32 s14, s14, s3                                      ; 920e030e
	v_mac_f32_e32 v40, v50, v35                                 ; 2c504732
	s_waitcnt vmcnt(9)                                          ; bf8c3f79
	v_mov_b32_e32 v35, v43                                      ; 7e46032b
	s_add_u32 s14, s18, s14                                     ; 800e0e12
	v_mac_f32_e32 v40, v52, v45                                 ; 2c505b34
	v_add_u32_e32 v52, s14, v0                                  ; 6868000e
	v_mac_f32_e32 v40, v44, v53                                 ; 2c506b2c
	v_lshlrev_b32_e32 v53, 4, v52                               ; 246a6884
	v_lshl_add_u32 v52, v52, 7, v53                             ; d1fd0034 04d50f34
	buffer_load_dwordx3 v[43:45], v52, s[24:27], 0 offen        ; e0581000 80062b34
	v_cvt_f32_f16_sdwa v50, v51 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e6416f9 00050633
	v_cvt_f32_f16_e32 v51, v51                                  ; 7e661733
	v_bfe_u32 v55, v55, v5, 16                                  ; d1c80037 02420b37
	v_lshlrev_b32_e32 v56, v6, v56                              ; 24707106
	v_lshl_or_b32 v41, v41, 12, v41                             ; d2000029 04a51929
	v_mad_f32 v3, -v50, v39, v3                                 ; d1c10003 240e4f32
	v_and_or_b32 v56, s10, v56, v55                             ; d2010038 04de700a
	v_mac_f32_e32 v3, v51, v40                                  ; 2c065133
	v_and_b32_e32 v40, s11, v35                                 ; 2650460b
	v_lshrrev_b32_e32 v35, 4, v35                               ; 20464684
	v_and_b32_e32 v39, s12, v56                                 ; 264e700c
	v_and_b32_e32 v56, s13, v56                                 ; 2670700d
	v_cvt_f32_ubyte1_e32 v53, v40                               ; 7e6a2528
	v_cvt_f32_ubyte2_e32 v51, v40                               ; 7e662728
	v_cvt_f32_ubyte3_e32 v50, v40                               ; 7e642928
	v_cvt_f32_ubyte0_e32 v40, v40                               ; 7e502328
	v_and_b32_e32 v35, s11, v35                                 ; 2646460b
	v_lshrrev_b32_e32 v39, 2, v39                               ; 204e4e82
	v_mul_f32_e32 v50, v19, v50                                 ; 0a646513
	v_cvt_f32_ubyte3_e32 v55, v35                               ; 7e6e2923
	v_and_or_b32 v41, s11, v41, v39                             ; d2010029 049e520b
	v_cvt_f32_ubyte2_e32 v39, v35                               ; 7e4e2723
	v_mac_f32_e32 v50, v18, v51                                 ; 2c646712
	s_waitcnt vmcnt(9)                                          ; bf8c3f79
	v_and_b32_e32 v51, s11, v42                                 ; 2666540b
	v_mul_f32_e32 v55, v23, v55                                 ; 0a6e6f17
	v_mac_f32_e32 v50, v17, v53                                 ; 2c646b11
	v_lshrrev_b32_e32 v42, 4, v42                               ; 20545484
	v_cvt_f32_ubyte3_e32 v53, v51                               ; 7e6a2933
	v_mac_f32_e32 v55, v22, v39                                 ; 2c6e4f16
	v_cvt_f32_ubyte1_e32 v39, v51                               ; 7e4e2533
	v_mac_f32_e32 v50, v16, v40                                 ; 2c645110
	v_cvt_f32_ubyte1_e32 v40, v35                               ; 7e502523
	v_cvt_f32_ubyte0_e32 v35, v35                               ; 7e462323
	v_and_b32_e32 v42, s11, v42                                 ; 2654540b
	v_mul_f32_e32 v53, v27, v53                                 ; 0a6a6b1b
	v_mac_f32_e32 v55, v21, v40                                 ; 2c6e5115
	v_cvt_f32_ubyte3_e32 v40, v42                               ; 7e50292a
	v_mac_f32_e32 v55, v20, v35                                 ; 2c6e4714
	v_cvt_f32_ubyte2_e32 v35, v51                               ; 7e462733
	v_cvt_f32_ubyte0_e32 v51, v51                               ; 7e662333
	v_mul_f32_e32 v40, v31, v40                                 ; 0a50511f
	v_mac_f32_e32 v53, v26, v35                                 ; 2c6a471a
	v_cvt_f32_ubyte1_e32 v35, v42                               ; 7e46252a
	v_mac_f32_e32 v53, v25, v39                                 ; 2c6a4f19
	v_cvt_f32_ubyte3_e32 v39, v41                               ; 7e4e2929
	v_mac_f32_e32 v53, v24, v51                                 ; 2c6a6718
	v_cvt_f32_ubyte2_e32 v51, v42                               ; 7e66272a
	v_cvt_f32_ubyte0_e32 v42, v42                               ; 7e54232a
	v_mul_f32_e32 v39, v33, v39                                 ; 0a4e4f21
	v_mac_f32_e32 v40, v30, v51                                 ; 2c50671e
	v_cvt_f32_ubyte3_e32 v51, v56                               ; 7e662938
	v_mac_f32_e32 v40, v29, v35                                 ; 2c50471d
	v_cvt_f32_ubyte2_e32 v35, v56                               ; 7e462738
	v_mac_f32_e32 v40, v28, v42                                 ; 2c50551c
	v_cvt_f32_ubyte2_e32 v42, v41                               ; 7e542729
	v_mac_f32_e32 v39, v32, v42                                 ; 2c4e5520
	v_cvt_f32_ubyte1_e32 v42, v41                               ; 7e542529
	v_cvt_f32_ubyte0_e32 v41, v41                               ; 7e522329
	s_add_u32 s15, s16, 5                                       ; 800f8510
	v_mac_f32_e32 v39, v15, v51                                 ; 2c4e670f
	v_add3_u32 v51, v34, 4, v52                                 ; d1ff0033 04d10922
	v_add_u32_e32 v52, 16, v52                                  ; 68686890
	v_mul_f32_e32 v40, v40, v42                                 ; 0a505528
	s_mul_i32 s15, s15, s3                                      ; 920f030f
	v_mac_f32_e32 v39, v14, v35                                 ; 2c4e470e
	v_cvt_f32_ubyte1_e32 v35, v56                               ; 7e462538
	v_mac_f32_e32 v40, v53, v41                                 ; 2c505335
	v_cvt_f32_ubyte0_e32 v56, v56                               ; 7e702338
	v_cvt_f32_f16_sdwa v41, v54 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e5216f9 00050636
	v_add_u32_e32 v53, v52, v4                                  ; 686a0934
	v_add_u32_e32 v52, v52, v38                                 ; 68684d34
	s_add_u32 s15, s18, s15                                     ; 800f0f12
	v_mac_f32_e32 v40, v55, v35                                 ; 2c504737
	v_mad_f32 v7, -v41, v39, v7                                 ; d1c10007 241e4f29
	v_add_u32_e32 v42, s15, v0                                  ; 6854000f
	v_mac_f32_e32 v40, v50, v56                                 ; 2c507132
	v_lshlrev_b32_e32 v50, 4, v42                               ; 24645484
	v_mov_b32_e32 v35, v40                                      ; 7e460328
	v_lshl_add_u32 v42, v42, 7, v50                             ; d1fd002a 04c90f2a
	buffer_load_ushort v51, v51, s[24:27], 0 offen              ; e0481000 80063333
	buffer_load_dword v53, v53, s[24:27], 0 offen               ; e0501000 80063535
	buffer_load_dword v52, v52, s[24:27], 0 offen               ; e0501000 80063434
	buffer_load_dwordx3 v[39:41], v42, s[24:27], 0 offen        ; e0581000 8006272a
	v_cvt_f32_f16_e32 v54, v54                                  ; 7e6c1736
	s_waitcnt vmcnt(12)                                         ; bf8c3f7c
	v_bfe_u32 v58, v58, v5, 16                                  ; d1c8003a 02420b3a
	v_lshlrev_b32_e32 v59, v6, v59                              ; 24767706
	s_waitcnt vmcnt(11)                                         ; bf8c3f7b
	v_lshl_or_b32 v46, v46, 12, v46                             ; d200002e 04b9192e
	v_mac_f32_e32 v7, v54, v35                                  ; 2c0e4736
	s_waitcnt vmcnt(10)                                         ; bf8c3f7a
	v_and_b32_e32 v54, s11, v48                                 ; 266c600b
	v_lshrrev_b32_e32 v48, 4, v48                               ; 20606084
	v_and_or_b32 v59, s10, v59, v58                             ; d201003b 04ea760a
	v_cvt_f32_ubyte2_e32 v56, v54                               ; 7e702736
	v_cvt_f32_ubyte3_e32 v55, v54                               ; 7e6e2936
	v_cvt_f32_ubyte1_e32 v58, v54                               ; 7e742536
	v_cvt_f32_ubyte0_e32 v54, v54                               ; 7e6c2336
	v_and_b32_e32 v48, s11, v48                                 ; 2660600b
	v_and_b32_e32 v50, s12, v59                                 ; 2664760c
	v_mul_f32_e32 v55, v19, v55                                 ; 0a6e6f13
	v_cvt_f32_ubyte3_e32 v35, v48                               ; 7e462930
	v_lshrrev_b32_e32 v50, 2, v50                               ; 20646482
	v_mac_f32_e32 v55, v18, v56                                 ; 2c6e7112
	s_waitcnt vmcnt(9)                                          ; bf8c3f79
	v_and_b32_e32 v56, s11, v47                                 ; 26705e0b
	v_mul_f32_e32 v35, v23, v35                                 ; 0a464717
	v_and_or_b32 v46, s11, v46, v50                             ; d201002e 04ca5c0b
	v_cvt_f32_ubyte2_e32 v50, v48                               ; 7e642730
	v_mac_f32_e32 v55, v17, v58                                 ; 2c6e7511
	v_cvt_f32_ubyte3_e32 v58, v56                               ; 7e742938
	v_lshrrev_b32_e32 v47, 4, v47                               ; 205e5e84
	v_mac_f32_e32 v35, v22, v50                                 ; 2c466516
	v_cvt_f32_ubyte1_e32 v50, v56                               ; 7e642538
	v_mac_f32_e32 v55, v16, v54                                 ; 2c6e6d10
	v_cvt_f32_ubyte1_e32 v54, v48                               ; 7e6c2530
	v_cvt_f32_ubyte0_e32 v48, v48                               ; 7e602330
	v_mul_f32_e32 v58, v27, v58                                 ; 0a74751b
	v_and_b32_e32 v47, s11, v47                                 ; 265e5e0b
	v_mac_f32_e32 v35, v21, v54                                 ; 2c466d15
	v_cvt_f32_ubyte3_e32 v54, v47                               ; 7e6c292f
	v_mac_f32_e32 v35, v20, v48                                 ; 2c466114
	v_cvt_f32_ubyte2_e32 v48, v56                               ; 7e602738
	v_cvt_f32_ubyte0_e32 v56, v56                               ; 7e702338
	v_mul_f32_e32 v54, v31, v54                                 ; 0a6c6d1f
	v_and_b32_e32 v59, s13, v59                                 ; 2676760d
	v_mac_f32_e32 v58, v26, v48                                 ; 2c74611a
	v_cvt_f32_ubyte1_e32 v48, v47                               ; 7e60252f
	v_mac_f32_e32 v58, v25, v50                                 ; 2c746519
	v_cvt_f32_ubyte3_e32 v50, v46                               ; 7e64292e
	v_mac_f32_e32 v58, v24, v56                                 ; 2c747118
	v_cvt_f32_ubyte2_e32 v56, v47                               ; 7e70272f
	v_cvt_f32_ubyte0_e32 v47, v47                               ; 7e5e232f
	v_mul_f32_e32 v50, v33, v50                                 ; 0a646521
	v_mac_f32_e32 v54, v30, v56                                 ; 2c6c711e
	v_cvt_f32_ubyte2_e32 v56, v46                               ; 7e70272e
	v_mac_f32_e32 v54, v29, v48                                 ; 2c6c611d
	v_cvt_f32_ubyte2_e32 v48, v59                               ; 7e60273b
	v_mac_f32_e32 v50, v32, v56                                 ; 2c647120
	v_mac_f32_e32 v54, v28, v47                                 ; 2c6c5f1c
	v_cvt_f32_ubyte3_e32 v47, v59                               ; 7e5e293b
	v_mac_f32_e32 v50, v15, v47                                 ; 2c645f0f
	v_add3_u32 v47, v34, 4, v42                                 ; d1ff002f 04a90922
	v_add_u32_e32 v42, 16, v42                                  ; 68545490
	v_mac_f32_e32 v50, v14, v48                                 ; 2c64610e
	v_add_u32_e32 v48, v42, v4                                  ; 6860092a
	v_add_u32_e32 v42, v42, v38                                 ; 68544d2a
	buffer_load_ushort v47, v47, s[24:27], 0 offen              ; e0481000 80062f2f
	buffer_load_dword v48, v48, s[24:27], 0 offen               ; e0501000 80063030
	buffer_load_dword v42, v42, s[24:27], 0 offen               ; e0501000 80062a2a
	v_cvt_f32_ubyte1_e32 v56, v46                               ; 7e70252e
	v_cvt_f32_ubyte0_e32 v46, v46                               ; 7e5c232e
	s_waitcnt vmcnt(11)                                         ; bf8c3f7b
	v_bfe_u32 v61, v61, v5, 16                                  ; d1c8003d 02420b3d
	v_lshlrev_b32_e32 v62, v6, v62                              ; 247c7d06
	v_mul_f32_e32 v54, v54, v56                                 ; 0a6c7136
	v_cvt_f32_ubyte1_e32 v56, v59                               ; 7e70253b
	v_cvt_f32_ubyte0_e32 v59, v59                               ; 7e76233b
	v_and_or_b32 v62, s10, v62, v61                             ; d201003e 04f67c0a
	v_mac_f32_e32 v54, v58, v46                                 ; 2c6c5d3a
	v_cvt_f32_f16_sdwa v58, v57 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e7416f9 00050639
	v_cvt_f32_f16_e32 v57, v57                                  ; 7e721739
	s_add_u32 s19, s16, 6                                       ; 80138610
	v_mac_f32_e32 v54, v35, v56                                 ; 2c6c7123
	s_waitcnt vmcnt(10)                                         ; bf8c3f7a
	v_lshl_or_b32 v36, v36, 12, v36                             ; d2000024 04911924
	v_mad_f32 v8, -v58, v50, v8                                 ; d1c10008 2422653a
	v_cvt_f32_f16_sdwa v50, v60 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e6416f9 0005063c
	v_cvt_f32_f16_e32 v60, v60                                  ; 7e78173c
	s_mul_i32 s19, s19, s3                                      ; 92130313
	v_mac_f32_e32 v54, v55, v59                                 ; 2c6c7737
	v_and_b32_e32 v59, s12, v62                                 ; 26767c0c
	v_and_b32_e32 v62, s13, v62                                 ; 267c7c0d
	v_mac_f32_e32 v8, v57, v54                                  ; 2c106d39
	s_waitcnt vmcnt(9)                                          ; bf8c3f79
	v_and_b32_e32 v54, s11, v37                                 ; 266c4a0b
	v_lshrrev_b32_e32 v59, 2, v59                               ; 20767682
	v_lshrrev_b32_e32 v37, 4, v37                               ; 204a4a84
	v_cvt_f32_ubyte1_e32 v46, v62                               ; 7e5c253e
	v_cvt_f32_ubyte3_e32 v61, v62                               ; 7e7a293e
	v_cvt_f32_ubyte2_e32 v35, v62                               ; 7e46273e
	v_cvt_f32_ubyte0_e32 v62, v62                               ; 7e7c233e
	v_cvt_f32_ubyte1_e32 v57, v54                               ; 7e722536
	v_cvt_f32_ubyte2_e32 v56, v54                               ; 7e702736
	v_cvt_f32_ubyte3_e32 v55, v54                               ; 7e6e2936
	v_cvt_f32_ubyte0_e32 v54, v54                               ; 7e6c2336
	v_and_or_b32 v36, s11, v36, v59                             ; d2010024 04ee480b
	v_and_b32_e32 v37, s11, v37                                 ; 264a4a0b
	v_mul_f32_e32 v55, v19, v55                                 ; 0a6e6f13
	v_cvt_f32_ubyte2_e32 v59, v37                               ; 7e762725
	v_cvt_f32_ubyte3_e32 v58, v37                               ; 7e742925
	v_mac_f32_e32 v55, v18, v56                                 ; 2c6e7112
	s_waitcnt vmcnt(8)                                          ; bf8c3f78
	v_and_b32_e32 v56, s11, v49                                 ; 2670620b
	v_mul_f32_e32 v58, v23, v58                                 ; 0a747517
	v_mac_f32_e32 v55, v17, v57                                 ; 2c6e7311
	v_lshrrev_b32_e32 v49, 4, v49                               ; 20626284
	v_cvt_f32_ubyte3_e32 v57, v56                               ; 7e722938
	v_mac_f32_e32 v58, v22, v59                                 ; 2c747716
	v_cvt_f32_ubyte2_e32 v59, v56                               ; 7e762738
	v_mac_f32_e32 v55, v16, v54                                 ; 2c6e6d10
	v_cvt_f32_ubyte1_e32 v54, v37                               ; 7e6c2525
	v_cvt_f32_ubyte0_e32 v37, v37                               ; 7e4a2325
	v_and_b32_e32 v49, s11, v49                                 ; 2662620b
	v_mul_f32_e32 v57, v27, v57                                 ; 0a72731b
	v_mac_f32_e32 v58, v21, v54                                 ; 2c746d15
	v_cvt_f32_ubyte3_e32 v54, v49                               ; 7e6c2931
	v_mac_f32_e32 v57, v26, v59                                 ; 2c72771a
	v_cvt_f32_ubyte1_e32 v59, v49                               ; 7e762531
	v_mac_f32_e32 v58, v20, v37                                 ; 2c744b14
	v_cvt_f32_ubyte1_e32 v37, v56                               ; 7e4a2538
	v_cvt_f32_ubyte0_e32 v56, v56                               ; 7e702338
	v_mul_f32_e32 v54, v31, v54                                 ; 0a6c6d1f
	v_mac_f32_e32 v57, v25, v37                                 ; 2c724b19
	v_cvt_f32_ubyte3_e32 v37, v36                               ; 7e4a2924
	s_add_u32 s19, s18, s19                                     ; 80131312
	v_mac_f32_e32 v57, v24, v56                                 ; 2c727118
	v_cvt_f32_ubyte2_e32 v56, v49                               ; 7e702731
	v_cvt_f32_ubyte0_e32 v49, v49                               ; 7e622331
	v_mul_f32_e32 v37, v33, v37                                 ; 0a4a4b21
	v_mac_f32_e32 v54, v30, v56                                 ; 2c6c711e
	v_cvt_f32_ubyte1_e32 v56, v36                               ; 7e702524
	v_mac_f32_e32 v54, v29, v59                                 ; 2c6c771d
	v_mac_f32_e32 v54, v28, v49                                 ; 2c6c631c
	v_cvt_f32_ubyte2_e32 v49, v36                               ; 7e622724
	v_cvt_f32_ubyte0_e32 v36, v36                               ; 7e482324
	v_mul_f32_e32 v54, v54, v56                                 ; 0a6c7136
	v_mac_f32_e32 v37, v32, v49                                 ; 2c4a6320
	v_mac_f32_e32 v54, v57, v36                                 ; 2c6c4939
	v_add_u32_e32 v57, s19, v0                                  ; 68720013
	v_mac_f32_e32 v37, v15, v61                                 ; 2c4a7b0f
	v_mac_f32_e32 v54, v58, v46                                 ; 2c6c5d3a
	v_lshlrev_b32_e32 v59, 4, v57                               ; 24767284
	v_mac_f32_e32 v37, v14, v35                                 ; 2c4a470e
	v_lshl_add_u32 v57, v57, 7, v59                             ; d1fd0039 04ed0f39
	v_add3_u32 v61, v34, 4, v57                                 ; d1ff003d 04e50922
	v_add_u32_e32 v35, 16, v57                                  ; 68467290
	v_add_u32_e32 v36, v35, v4                                  ; 68480923
	v_add_u32_e32 v35, v35, v38                                 ; 68464d23
	buffer_load_dwordx3 v[56:58], v57, s[24:27], 0 offen        ; e0581000 80063839
	buffer_load_ushort v61, v61, s[24:27], 0 offen              ; e0481000 80063d3d
	buffer_load_dword v36, v36, s[24:27], 0 offen               ; e0501000 80062424
	buffer_load_dword v35, v35, s[24:27], 0 offen               ; e0501000 80062323
	s_waitcnt vmcnt(11)                                         ; bf8c3f7b
	v_bfe_u32 v44, v44, v5, 16                                  ; d1c8002c 02420b2c
	v_lshlrev_b32_e32 v45, v6, v45                              ; 245a5b06
	v_mac_f32_e32 v54, v55, v62                                 ; 2c6c7d37
	v_mad_f32 v9, -v50, v37, v9                                 ; d1c10009 24264b32
	s_add_u32 s20, s16, 7                                       ; 80148710
	s_waitcnt vmcnt(10)                                         ; bf8c3f7a
	v_lshl_or_b32 v51, v51, 12, v51                             ; d2000033 04cd1933
	v_and_or_b32 v45, s10, v45, v44                             ; d201002d 04b25a0a
	v_cvt_f32_f16_sdwa v44, v43 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e5816f9 0005062b
	v_cvt_f32_f16_e32 v43, v43                                  ; 7e56172b
	s_waitcnt vmcnt(9)                                          ; bf8c3f79
	v_and_b32_e32 v46, s11, v53                                 ; 265c6a0b
	v_mac_f32_e32 v9, v60, v54                                  ; 2c126d3c
	s_mul_i32 s20, s20, s3                                      ; 92140314
	v_and_b32_e32 v59, s12, v45                                 ; 26765a0c
	v_and_b32_e32 v45, s13, v45                                 ; 265a5a0d
	v_cvt_f32_ubyte3_e32 v49, v46                               ; 7e62292e
	v_cvt_f32_ubyte1_e32 v54, v46                               ; 7e6c252e
	v_cvt_f32_ubyte2_e32 v50, v46                               ; 7e64272e
	v_cvt_f32_ubyte0_e32 v46, v46                               ; 7e5c232e
	v_lshrrev_b32_e32 v53, 4, v53                               ; 206a6a84
	v_lshrrev_b32_e32 v59, 2, v59                               ; 20767682
	v_cvt_f32_ubyte2_e32 v62, v45                               ; 7e7c272d
	v_cvt_f32_ubyte3_e32 v60, v45                               ; 7e78292d
	v_cvt_f32_ubyte1_e32 v37, v45                               ; 7e4a252d
	v_cvt_f32_ubyte0_e32 v45, v45                               ; 7e5a232d
	v_mul_f32_e32 v49, v19, v49                                 ; 0a626313
	v_and_b32_e32 v53, s11, v53                                 ; 266a6a0b
	v_and_or_b32 v51, s11, v51, v59                             ; d2010033 04ee660b
	v_mac_f32_e32 v49, v18, v50                                 ; 2c626512
	s_waitcnt vmcnt(8)                                          ; bf8c3f78
	v_and_b32_e32 v50, s11, v52                                 ; 2664680b
	v_cvt_f32_ubyte3_e32 v55, v53                               ; 7e6e2935
	v_cvt_f32_ubyte2_e32 v59, v53                               ; 7e762735
	v_mac_f32_e32 v49, v17, v54                                 ; 2c626d11
	v_cvt_f32_ubyte2_e32 v54, v50                               ; 7e6c2732
	v_mul_f32_e32 v55, v23, v55                                 ; 0a6e6f17
	v_lshrrev_b32_e32 v52, 4, v52                               ; 20686884
	v_mac_f32_e32 v49, v16, v46                                 ; 2c625d10
	v_cvt_f32_ubyte1_e32 v46, v53                               ; 7e5c2535
	v_cvt_f32_ubyte0_e32 v53, v53                               ; 7e6a2335
	v_mac_f32_e32 v55, v22, v59                                 ; 2c6e7716
	v_cvt_f32_ubyte1_e32 v59, v50                               ; 7e762532
	v_and_b32_e32 v52, s11, v52                                 ; 2668680b
	v_mac_f32_e32 v55, v21, v46                                 ; 2c6e5d15
	v_cvt_f32_ubyte3_e32 v46, v52                               ; 7e5c2934
	v_mac_f32_e32 v55, v20, v53                                 ; 2c6e6b14
	v_cvt_f32_ubyte3_e32 v53, v50                               ; 7e6a2932
	v_cvt_f32_ubyte0_e32 v50, v50                               ; 7e642332
	v_mul_f32_e32 v46, v31, v46                                 ; 0a5c5d1f
	v_mul_f32_e32 v53, v27, v53                                 ; 0a6a6b1b
	v_mac_f32_e32 v53, v26, v54                                 ; 2c6a6d1a
	v_cvt_f32_ubyte1_e32 v54, v52                               ; 7e6c2534
	v_mac_f32_e32 v53, v25, v59                                 ; 2c6a7719
	v_cvt_f32_ubyte3_e32 v59, v51                               ; 7e762933
	s_add_u32 s20, s18, s20                                     ; 80141412
	v_mac_f32_e32 v53, v24, v50                                 ; 2c6a6518
	v_cvt_f32_ubyte2_e32 v50, v52                               ; 7e642734
	v_cvt_f32_ubyte0_e32 v52, v52                               ; 7e682334
	v_mul_f32_e32 v59, v33, v59                                 ; 0a767721
	v_mac_f32_e32 v46, v30, v50                                 ; 2c5c651e
	v_cvt_f32_ubyte2_e32 v50, v51                               ; 7e642733
	v_mac_f32_e32 v46, v29, v54                                 ; 2c5c6d1d
	v_mac_f32_e32 v59, v32, v50                                 ; 2c766520
	v_mac_f32_e32 v46, v28, v52                                 ; 2c5c691c
	v_cvt_f32_ubyte1_e32 v52, v51                               ; 7e682533
	v_cvt_f32_ubyte0_e32 v51, v51                               ; 7e662333
	v_mul_f32_e32 v46, v46, v52                                 ; 0a5c692e
	v_mac_f32_e32 v46, v53, v51                                 ; 2c5c6735
	v_add_u32_e32 v53, s20, v0                                  ; 686a0014
	v_lshlrev_b32_e32 v54, 4, v53                               ; 246c6a84
	v_lshl_add_u32 v53, v53, 7, v54                             ; d1fd0035 04d90f35
	v_add3_u32 v34, v34, 4, v53                                 ; d1ff0022 04d50922
	buffer_load_dwordx3 v[50:52], v53, s[24:27], 0 offen        ; e0581000 80063235
	buffer_load_ushort v34, v34, s[24:27], 0 offen              ; e0481000 80062222
	v_add_u32_e32 v53, 16, v53                                  ; 686a6a90
	v_add_u32_e32 v54, v53, v4                                  ; 686c0935
	v_add_u32_e32 v53, v53, v38                                 ; 686a4d35
	buffer_load_dword v54, v54, s[24:27], 0 offen               ; e0501000 80063636
	buffer_load_dword v53, v53, s[24:27], 0 offen               ; e0501000 80063535
	v_mac_f32_e32 v59, v15, v60                                 ; 2c76790f
	v_mac_f32_e32 v46, v55, v37                                 ; 2c5c4b37
	s_waitcnt vmcnt(11)                                         ; bf8c3f7b
	v_bfe_u32 v40, v40, v5, 16                                  ; d1c80028 02420b28
	v_lshlrev_b32_e32 v41, v6, v41                              ; 24525306
	v_cvt_f32_f16_sdwa v37, v39 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e4a16f9 00050627
	v_cvt_f32_f16_e32 v39, v39                                  ; 7e4e1727
	v_mac_f32_e32 v59, v14, v62                                 ; 2c767d0e
	v_add_u32_e32 v0, 4, v0                                     ; 68000084
	v_mac_f32_e32 v46, v49, v45                                 ; 2c5c5b31
	s_waitcnt vmcnt(10)                                         ; bf8c3f7a
	v_lshl_or_b32 v47, v47, 12, v47                             ; d200002f 04bd192f
	v_and_or_b32 v41, s10, v41, v40                             ; d2010029 04a2520a
	v_mad_f32 v10, -v44, v59, v10                               ; d1c1000a 242a772c
	v_and_b32_e32 v55, s12, v41                                 ; 266e520c
	v_and_b32_e32 v41, s13, v41                                 ; 2652520d
	v_mac_f32_e32 v10, v43, v46                                 ; 2c145d2b
	s_waitcnt vmcnt(9)                                          ; bf8c3f79
	v_and_b32_e32 v43, s11, v48                                 ; 2656600b
	v_lshrrev_b32_e32 v55, 2, v55                               ; 206e6e82
	v_cvt_f32_ubyte2_e32 v60, v41                               ; 7e782729
	v_cvt_f32_ubyte1_e32 v62, v41                               ; 7e7c2529
	v_cvt_f32_ubyte3_e32 v59, v41                               ; 7e762929
	v_cvt_f32_ubyte0_e32 v41, v41                               ; 7e522329
	v_cvt_f32_ubyte3_e32 v44, v43                               ; 7e58292b
	v_cvt_f32_ubyte2_e32 v45, v43                               ; 7e5a272b
	v_cvt_f32_ubyte1_e32 v46, v43                               ; 7e5c252b
	v_cvt_f32_ubyte0_e32 v43, v43                               ; 7e56232b
	v_and_or_b32 v47, s11, v47, v55                             ; d201002f 04de5e0b
	v_lshrrev_b32_e32 v48, 4, v48                               ; 20606084
	v_mul_f32_e32 v44, v19, v44                                 ; 0a585913
	v_cvt_f32_ubyte3_e32 v38, v47                               ; 7e4c292f
	v_cvt_f32_ubyte2_e32 v40, v47                               ; 7e50272f
	v_and_b32_e32 v48, s11, v48                                 ; 2660600b
	v_mac_f32_e32 v44, v18, v45                                 ; 2c585b12
	v_mul_f32_e32 v38, v33, v38                                 ; 0a4c4d21
	v_cvt_f32_ubyte2_e32 v55, v48                               ; 7e6e2730
	v_cvt_f32_ubyte3_e32 v49, v48                               ; 7e622930
	v_mac_f32_e32 v44, v17, v46                                 ; 2c585d11
	v_mac_f32_e32 v38, v32, v40                                 ; 2c4c5120
	v_cvt_f32_ubyte1_e32 v40, v48                               ; 7e502530
	v_cvt_f32_ubyte0_e32 v48, v48                               ; 7e602330
	v_mul_f32_e32 v49, v23, v49                                 ; 0a626317
	v_mac_f32_e32 v44, v16, v43                                 ; 2c585710
	s_waitcnt vmcnt(8)                                          ; bf8c3f78
	v_and_b32_e32 v43, s11, v42                                 ; 2656540b
	v_lshrrev_b32_e32 v42, 4, v42                               ; 20545484
	v_mac_f32_e32 v49, v22, v55                                 ; 2c626f16
	v_cvt_f32_ubyte3_e32 v45, v43                               ; 7e5a292b
	v_cvt_f32_ubyte2_e32 v46, v43                               ; 7e5c272b
	v_and_b32_e32 v42, s11, v42                                 ; 2654540b
	v_mac_f32_e32 v49, v21, v40                                 ; 2c625115
	v_mul_f32_e32 v45, v27, v45                                 ; 0a5a5b1b
	v_mac_f32_e32 v38, v15, v59                                 ; 2c4c770f
	v_cvt_f32_ubyte3_e32 v55, v42                               ; 7e6e292a
	v_cvt_f32_ubyte2_e32 v40, v42                               ; 7e50272a
	v_mac_f32_e32 v49, v20, v48                                 ; 2c626114
	v_cvt_f32_ubyte1_e32 v48, v43                               ; 7e60252b
	v_cvt_f32_ubyte0_e32 v43, v43                               ; 7e56232b
	v_mac_f32_e32 v45, v26, v46                                 ; 2c5a5d1a
	v_cvt_f32_ubyte1_e32 v46, v47                               ; 7e5c252f
	v_mac_f32_e32 v38, v14, v60                                 ; 2c4c790e
	v_cvt_f32_ubyte0_e32 v47, v47                               ; 7e5e232f
	v_mul_f32_e32 v55, v31, v55                                 ; 0a6e6f1f
	v_mac_f32_e32 v45, v25, v48                                 ; 2c5a6119
	s_waitcnt vmcnt(7)                                          ; bf8c3f77
	v_bfe_u32 v57, v57, v5, 16                                  ; d1c80039 02420b39
	v_lshlrev_b32_e32 v58, v6, v58                              ; 24747506
	v_mad_f32 v11, -v37, v38, v11                               ; d1c1000b 242e4d25
	v_mac_f32_e32 v55, v30, v40                                 ; 2c6e511e
	v_mac_f32_e32 v45, v24, v43                                 ; 2c5a5718
	v_cvt_f32_ubyte1_e32 v43, v42                               ; 7e56252a
	v_cvt_f32_ubyte0_e32 v42, v42                               ; 7e54232a
	v_and_or_b32 v58, s10, v58, v57                             ; d201003a 04e6740a
	v_mac_f32_e32 v55, v29, v43                                 ; 2c6e571d
	v_cvt_f32_f16_sdwa v57, v56 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e7216f9 00050638
	v_cvt_f32_f16_e32 v56, v56                                  ; 7e701738
	s_waitcnt vmcnt(6)                                          ; bf8c3f76
	v_lshl_or_b32 v61, v61, 12, v61                             ; d200003d 04f5193d
	v_mac_f32_e32 v55, v28, v42                                 ; 2c6e551c
	v_mul_f32_e32 v55, v55, v46                                 ; 0a6e5d37
	v_mac_f32_e32 v55, v45, v47                                 ; 2c6e5f2d
	v_and_b32_e32 v47, s12, v58                                 ; 265e740c
	v_and_b32_e32 v58, s13, v58                                 ; 2674740d
	v_mac_f32_e32 v55, v49, v62                                 ; 2c6e7d31
	v_lshrrev_b32_e32 v47, 2, v47                               ; 205e5e82
	v_cvt_f32_ubyte3_e32 v48, v58                               ; 7e60293a
	v_cvt_f32_ubyte2_e32 v49, v58                               ; 7e62273a
	v_mac_f32_e32 v55, v44, v41                                 ; 2c6e532c
	s_waitcnt vmcnt(5)                                          ; bf8c3f75
	v_and_b32_e32 v37, s11, v36                                 ; 264a480b
	v_and_or_b32 v61, s11, v61, v47                             ; d201003d 04be7a0b
	v_mac_f32_e32 v11, v39, v55                                 ; 2c166f27
	v_cvt_f32_ubyte1_e32 v55, v58                               ; 7e6e253a
	v_cvt_f32_ubyte0_e32 v58, v58                               ; 7e74233a
	v_cvt_f32_ubyte2_e32 v39, v37                               ; 7e4e2725
	v_cvt_f32_ubyte3_e32 v38, v37                               ; 7e4c2925
	v_cvt_f32_ubyte1_e32 v40, v37                               ; 7e502525
	v_cvt_f32_ubyte1_e32 v62, v61                               ; 7e7c253d
	v_cvt_f32_ubyte3_e32 v59, v61                               ; 7e76293d
	v_cvt_f32_ubyte2_e32 v60, v61                               ; 7e78273d
	v_cvt_f32_ubyte0_e32 v61, v61                               ; 7e7a233d
	v_cvt_f32_ubyte0_e32 v37, v37                               ; 7e4a2325
	v_lshrrev_b32_e32 v36, 4, v36                               ; 20484884
	v_mul_f32_e32 v38, v19, v38                                 ; 0a4c4d13
	v_mul_f32_e32 v59, v33, v59                                 ; 0a767721
	v_and_b32_e32 v36, s11, v36                                 ; 2648480b
	v_mac_f32_e32 v38, v18, v39                                 ; 2c4c4f12
	s_waitcnt vmcnt(4)                                          ; bf8c3f74
	v_and_b32_e32 v44, s11, v35                                 ; 2658460b
	v_mac_f32_e32 v59, v32, v60                                 ; 2c767920
	v_cvt_f32_ubyte3_e32 v41, v36                               ; 7e522924
	v_cvt_f32_ubyte2_e32 v42, v36                               ; 7e542724
	v_cvt_f32_ubyte1_e32 v43, v36                               ; 7e562524
	v_cvt_f32_ubyte0_e32 v36, v36                               ; 7e482324
	v_mac_f32_e32 v38, v17, v40                                 ; 2c4c5111
	v_cvt_f32_ubyte2_e32 v46, v44                               ; 7e5c272c
	v_cvt_f32_ubyte3_e32 v45, v44                               ; 7e5a292c
	v_mac_f32_e32 v59, v15, v48                                 ; 2c76610f
	v_mul_f32_e32 v41, v23, v41                                 ; 0a525317
	v_cvt_f32_ubyte1_e32 v47, v44                               ; 7e5e252c
	v_cvt_f32_ubyte0_e32 v44, v44                               ; 7e58232c
	v_lshrrev_b32_e32 v35, 4, v35                               ; 20464684
	v_mac_f32_e32 v38, v16, v37                                 ; 2c4c4b10
	v_mul_f32_e32 v45, v27, v45                                 ; 0a5a5b1b
	v_mac_f32_e32 v59, v14, v49                                 ; 2c76630e
	v_mac_f32_e32 v41, v22, v42                                 ; 2c525516
	v_and_b32_e32 v35, s11, v35                                 ; 2646460b
	v_mac_f32_e32 v45, v26, v46                                 ; 2c5a5d1a
	v_mad_f32 v12, -v57, v59, v12                               ; d1c1000c 24327739
	v_mac_f32_e32 v41, v21, v43                                 ; 2c525715
	v_cvt_f32_ubyte1_e32 v57, v35                               ; 7e722523
	v_cvt_f32_ubyte2_e32 v49, v35                               ; 7e622723
	v_cvt_f32_ubyte3_e32 v48, v35                               ; 7e602923
	v_cvt_f32_ubyte0_e32 v35, v35                               ; 7e462323
	v_mac_f32_e32 v45, v25, v47                                 ; 2c5a5f19
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_bfe_u32 v51, v51, v5, 16                                  ; d1c80033 02420b33
	v_mac_f32_e32 v41, v20, v36                                 ; 2c524914
	v_lshlrev_b32_e32 v52, v6, v52                              ; 24686906
	v_mul_f32_e32 v48, v31, v48                                 ; 0a60611f
	v_mac_f32_e32 v45, v24, v44                                 ; 2c5a5918
	v_and_or_b32 v52, s10, v52, v51                             ; d2010034 04ce680a
	v_mac_f32_e32 v48, v30, v49                                 ; 2c60631e
	v_mac_f32_e32 v48, v29, v57                                 ; 2c60731d
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_lshl_or_b32 v34, v34, 12, v34                             ; d2000022 04891922
	v_mac_f32_e32 v48, v28, v35                                 ; 2c60471c
	v_mul_f32_e32 v48, v48, v62                                 ; 0a607d30
	v_cvt_f32_f16_sdwa v62, v50 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e7c16f9 00050632
	v_cvt_f32_f16_e32 v50, v50                                  ; 7e641732
	v_mac_f32_e32 v48, v45, v61                                 ; 2c607b2d
	v_mac_f32_e32 v48, v41, v55                                 ; 2c606f29
	v_mac_f32_e32 v48, v38, v58                                 ; 2c607526
	v_and_b32_e32 v58, s12, v52                                 ; 2674680c
	v_and_b32_e32 v52, s13, v52                                 ; 2668680d
	v_mac_f32_e32 v12, v56, v48                                 ; 2c186138
	v_lshrrev_b32_e32 v58, 2, v58                               ; 20747482
	v_cvt_f32_ubyte1_e32 v61, v52                               ; 7e7a2534
	v_cvt_f32_ubyte2_e32 v60, v52                               ; 7e782734
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v38, s11, v54                                 ; 264c6c0b
	v_cvt_f32_ubyte3_e32 v59, v52                               ; 7e762934
	v_cvt_f32_ubyte0_e32 v52, v52                               ; 7e682334
	v_and_or_b32 v34, s11, v34, v58                             ; d2010022 04ea440b
	v_cvt_f32_ubyte2_e32 v40, v38                               ; 7e502726
	v_cvt_f32_ubyte3_e32 v39, v38                               ; 7e4e2926
	v_cvt_f32_ubyte1_e32 v41, v38                               ; 7e522526
	v_cvt_f32_ubyte0_e32 v38, v38                               ; 7e4c2326
	v_cvt_f32_ubyte1_e32 v37, v34                               ; 7e4a2522
	v_cvt_f32_ubyte2_e32 v36, v34                               ; 7e482722
	v_cvt_f32_ubyte3_e32 v35, v34                               ; 7e462922
	v_cvt_f32_ubyte0_e32 v34, v34                               ; 7e442322
	v_lshrrev_b32_e32 v54, 4, v54                               ; 206c6c84
	v_mul_f32_e32 v19, v19, v39                                 ; 0a264f13
	v_mul_f32_e32 v33, v33, v35                                 ; 0a424721
	v_and_b32_e32 v54, s11, v54                                 ; 266c6c0b
	v_mac_f32_e32 v19, v18, v40                                 ; 2c265112
	v_mac_f32_e32 v33, v32, v36                                 ; 2c424920
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v45, s11, v53                                 ; 265a6a0b
	v_cvt_f32_ubyte1_e32 v44, v54                               ; 7e582536
	v_cvt_f32_ubyte3_e32 v42, v54                               ; 7e542936
	v_cvt_f32_ubyte2_e32 v43, v54                               ; 7e562736
	v_cvt_f32_ubyte0_e32 v54, v54                               ; 7e6c2336
	v_mac_f32_e32 v19, v17, v41                                 ; 2c265311
	v_mac_f32_e32 v33, v15, v59                                 ; 2c42770f
	v_cvt_f32_ubyte3_e32 v46, v45                               ; 7e5c292d
	v_cvt_f32_ubyte2_e32 v47, v45                               ; 7e5e272d
	v_cvt_f32_ubyte1_e32 v48, v45                               ; 7e60252d
	v_mul_f32_e32 v23, v23, v42                                 ; 0a2e5517
	v_cvt_f32_ubyte0_e32 v45, v45                               ; 7e5a232d
	v_mac_f32_e32 v19, v16, v38                                 ; 2c264d10
	v_lshrrev_b32_e32 v53, 4, v53                               ; 206a6a84
	v_mac_f32_e32 v33, v14, v60                                 ; 2c42790e
	v_mul_f32_e32 v27, v27, v46                                 ; 0a365d1b
	v_mac_f32_e32 v23, v22, v43                                 ; 2c2e5716
	v_and_b32_e32 v53, s11, v53                                 ; 266a6a0b
	v_mad_f32 v13, -v62, v33, v13                               ; d1c1000d 2436433e
	v_mac_f32_e32 v27, v26, v47                                 ; 2c365f1a
	v_mac_f32_e32 v23, v21, v44                                 ; 2c2e5915
	v_cvt_f32_ubyte2_e32 v51, v53                               ; 7e662735
	v_cvt_f32_ubyte3_e32 v49, v53                               ; 7e622935
	v_mac_f32_e32 v27, v25, v48                                 ; 2c366119
	v_mac_f32_e32 v23, v20, v54                                 ; 2c2e6d14
	v_cvt_f32_ubyte1_e32 v54, v53                               ; 7e6c2535
	v_cvt_f32_ubyte0_e32 v53, v53                               ; 7e6a2335
	v_mul_f32_e32 v31, v31, v49                                 ; 0a3e631f
	v_mac_f32_e32 v27, v24, v45                                 ; 2c365b18
	v_mac_f32_e32 v31, v30, v51                                 ; 2c3e671e
	v_mac_f32_e32 v31, v29, v54                                 ; 2c3e6d1d
	v_mac_f32_e32 v31, v28, v53                                 ; 2c3e6b1c
	v_mul_f32_e32 v31, v31, v37                                 ; 0a3e4b1f
	v_mac_f32_e32 v31, v27, v34                                 ; 2c3e451b
	v_mac_f32_e32 v31, v23, v61                                 ; 2c3e7b17
	v_mac_f32_e32 v31, v19, v52                                 ; 2c3e6913
	v_mac_f32_e32 v13, v50, v31                                 ; 2c1a3f32
BB5:
	s_mov_b64 s[0:1], exec                                      ; be80017e
	v_cmpx_le_u32_e32 vcc, s3, v0                               ; 7db60003
BB6:
	s_andn2_b64 s[0:1], s[0:1], exec                            ; 89807e00
	s_cbranch_scc1 BB10                                         ; bf85fcc9
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
	v_cndmask_b32_e64 v63, 0, v7, s[4:5]                        ; d100003f 00120e80
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
	v_cndmask_b32_e64 v63, 0, v8, s[4:5]                        ; d100003f 00121080
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
	v_cndmask_b32_e64 v63, 0, v9, s[10:11]                      ; d100003f 002a1280
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
	v_readlane_b32 s4, v63, 63                                  ; d2890004 00017f3f
	s_or_saveexec_b64 s[10:11], -1                              ; be8a21c1
	v_cndmask_b32_e64 v63, 0, v10, s[10:11]                     ; d100003f 002a1480
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
	s_or_saveexec_b64 s[10:11], -1                              ; be8a21c1
	v_cndmask_b32_e64 v63, 0, v11, s[10:11]                     ; d100003f 002a1680
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
	s_or_saveexec_b64 s[10:11], -1                              ; be8a21c1
	v_cndmask_b32_e64 v63, 0, v12, s[10:11]                     ; d100003f 002a1880
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
	s_or_saveexec_b64 s[12:13], -1                              ; be8c21c1
	v_cndmask_b32_e64 v63, 0, v13, s[12:13]                     ; d100003f 00321a80
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
	v_readlane_b32 s10, v63, 63                                 ; d289000a 00017f3f
BB12:
	s_bitcmp1_b32 s8, 0                                         ; bf0d8008
	s_cbranch_scc0 BB14                                         ; bf84000f
BB13:
	s_mov_b32 s12, s2                                           ; be8c0002
	s_movk_i32 s13, 0x8000                                      ; b00d8000
	s_load_dwordx4 s[12:15], s[12:13], 0x30                     ; c00a0306 00000030
	s_mul_i32 s11, s7, s17                                      ; 920b1107
	s_mov_b32 s18, src_scc                                      ; be9200fd
	s_add_u32 s11, s11, s16                                     ; 800b100b
	s_lshl_b32 s11, s11, 2                                      ; 8e0b820b
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s11, s[12:15], s11                      ; c02002c6 0000000b
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_mov_b32_e32 v0, s11                                       ; 7e00020b
	v_add_f32_e32 v0, s0, v0                                    ; 02000000
	s_branch BB15                                               ; bf820002
BB14:
	s_mov_b32 s18, src_scc                                      ; be9200fd
	v_mov_b32_e32 v0, s0                                        ; 7e000200
BB15:
	s_bitcmp1_b32 s8, 1                                         ; bf0d8108
	s_cbranch_scc0 BB17                                         ; bf84000e
BB16:
	s_mov_b32 s12, s2                                           ; be8c0002
	s_movk_i32 s13, 0x8000                                      ; b00d8000
	s_load_dwordx4 s[12:15], s[12:13], 0x40                     ; c00a0306 00000040
	s_mul_i32 s0, s7, s17                                       ; 92001107
	s_mov_b32 s8, src_scc                                       ; be8800fd
	s_add_u32 s0, s0, s16                                       ; 80001000
	s_lshl_b32 s0, s0, 2                                        ; 8e008200
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s0, s[12:15], s0                        ; c0200006 00000000
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v0, s0, v0                                    ; 02000000
	s_branch BB18                                               ; bf820001
BB17:
	s_mov_b32 s8, src_scc                                       ; be8800fd
BB18:
	s_mov_b32 s0, s3                                            ; be800003
	s_movk_i32 s3, 0x8000                                       ; b0038000
	s_load_dwordx4 s[12:15], s[2:3], 0x20                       ; c00a0301 00000020
	s_mul_i32 s7, s7, s17                                       ; 92071107
	s_add_u32 s7, s7, s16                                       ; 80071007
	s_lshl_b32 s7, s7, 2                                        ; 8e078207
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_store_dword v0, off, s[12:15], s7                    ; e0700000 07030080
	s_cmp_lg_i32 s18, 0                                         ; bf018012
	s_cbranch_scc0 BB20                                         ; bf84000b
BB19:
	s_load_dwordx4 s[16:19], s[2:3], 0x30                       ; c00a0401 00000030
	s_mov_b32 s11, src_scc                                      ; be8b00fd
	s_add_u32 s20, s7, 4                                        ; 80148407
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s20, s[16:19], s20                      ; c0200508 00000014
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_mov_b32_e32 v0, s20                                       ; 7e000214
	v_add_f32_e32 v0, s1, v0                                    ; 02000001
	s_branch BB21                                               ; bf820002
BB20:
	s_mov_b32 s11, src_scc                                      ; be8b00fd
	v_mov_b32_e32 v0, s1                                        ; 7e000201
BB21:
	s_cmp_lg_i32 s8, 0                                          ; bf018008
	s_cbranch_scc0 BB23                                         ; bf84000a
BB22:
	s_load_dwordx4 s[16:19], s[2:3], 0x40                       ; c00a0401 00000040
	s_mov_b32 s1, src_scc                                       ; be8100fd
	s_add_u32 s8, s7, 4                                         ; 80088407
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s8, s[16:19], s8                        ; c0200208 00000008
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v0, s8, v0                                    ; 02000008
	s_branch BB24                                               ; bf820001
BB23:
	s_mov_b32 s1, src_scc                                       ; be8100fd
BB24:
	s_add_u32 s8, s7, 4                                         ; 80088407
	buffer_store_dword v0, off, s[12:15], s8                    ; e0700000 08030080
	s_cmp_lg_i32 s11, 0                                         ; bf01800b
	s_cbranch_scc0 BB26                                         ; bf84000b
BB25:
	s_load_dwordx4 s[16:19], s[2:3], 0x30                       ; c00a0401 00000030
	s_mov_b32 s8, src_scc                                       ; be8800fd
	s_add_u32 s11, s7, 8                                        ; 800b8807
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s11, s[16:19], s11                      ; c02002c8 0000000b
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_mov_b32_e32 v0, s11                                       ; 7e00020b
	v_add_f32_e32 v0, s0, v0                                    ; 02000000
	s_branch BB27                                               ; bf820002
BB26:
	s_mov_b32 s8, src_scc                                       ; be8800fd
	v_mov_b32_e32 v0, s0                                        ; 7e000200
BB27:
	s_cmp_lg_i32 s1, 0                                          ; bf018001
	s_cbranch_scc0 BB29                                         ; bf84000a
BB28:
	s_load_dwordx4 s[16:19], s[2:3], 0x40                       ; c00a0401 00000040
	s_mov_b32 s0, src_scc                                       ; be8000fd
	s_add_u32 s1, s7, 8                                         ; 80018807
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s1, s[16:19], s1                        ; c0200048 00000001
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v0, s1, v0                                    ; 02000001
	s_branch BB30                                               ; bf820001
BB29:
	s_mov_b32 s0, src_scc                                       ; be8000fd
BB30:
	s_add_u32 s1, s7, 8                                         ; 80018807
	buffer_store_dword v0, off, s[12:15], s1                    ; e0700000 01030080
	s_cmp_lg_i32 s8, 0                                          ; bf018008
	s_cbranch_scc0 BB32                                         ; bf84000b
BB31:
	s_load_dwordx4 s[16:19], s[2:3], 0x30                       ; c00a0401 00000030
	s_mov_b32 s1, src_scc                                       ; be8100fd
	s_add_u32 s8, s7, 12                                        ; 80088c07
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s8, s[16:19], s8                        ; c0200208 00000008
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_mov_b32_e32 v0, s8                                        ; 7e000208
	v_add_f32_e32 v0, s4, v0                                    ; 02000004
	s_branch BB33                                               ; bf820002
BB32:
	s_mov_b32 s1, src_scc                                       ; be8100fd
	v_mov_b32_e32 v0, s4                                        ; 7e000204
BB33:
	s_cmp_lg_i32 s0, 0                                          ; bf018000
	s_cbranch_scc0 BB35                                         ; bf84000a
BB34:
	s_load_dwordx4 s[16:19], s[2:3], 0x40                       ; c00a0401 00000040
	s_mov_b32 s0, src_scc                                       ; be8000fd
	s_add_u32 s4, s7, 12                                        ; 80048c07
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s4, s[16:19], s4                        ; c0200108 00000004
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v0, s4, v0                                    ; 02000004
	s_branch BB36                                               ; bf820001
BB35:
	s_mov_b32 s0, src_scc                                       ; be8000fd
BB36:
	s_add_u32 s4, s7, 12                                        ; 80048c07
	buffer_store_dword v0, off, s[12:15], s4                    ; e0700000 04030080
	s_cmp_lg_i32 s1, 0                                          ; bf018001
	s_cbranch_scc0 BB38                                         ; bf84000b
BB37:
	s_load_dwordx4 s[16:19], s[2:3], 0x30                       ; c00a0401 00000030
	s_mov_b32 s1, src_scc                                       ; be8100fd
	s_add_u32 s4, s7, 16                                        ; 80049007
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s4, s[16:19], s4                        ; c0200108 00000004
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_mov_b32_e32 v0, s4                                        ; 7e000204
	v_add_f32_e32 v0, s5, v0                                    ; 02000005
	s_branch BB39                                               ; bf820002
BB38:
	s_mov_b32 s1, src_scc                                       ; be8100fd
	v_mov_b32_e32 v0, s5                                        ; 7e000205
BB39:
	s_cmp_lg_i32 s0, 0                                          ; bf018000
	s_cbranch_scc0 BB41                                         ; bf84000a
BB40:
	s_load_dwordx4 s[16:19], s[2:3], 0x40                       ; c00a0401 00000040
	s_mov_b32 s0, src_scc                                       ; be8000fd
	s_add_u32 s4, s7, 16                                        ; 80049007
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s4, s[16:19], s4                        ; c0200108 00000004
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v0, s4, v0                                    ; 02000004
	s_branch BB42                                               ; bf820001
BB41:
	s_mov_b32 s0, src_scc                                       ; be8000fd
BB42:
	s_add_u32 s4, s7, 16                                        ; 80049007
	buffer_store_dword v0, off, s[12:15], s4                    ; e0700000 04030080
	s_cmp_lg_i32 s1, 0                                          ; bf018001
	s_cbranch_scc0 BB44                                         ; bf84000b
BB43:
	s_load_dwordx4 s[16:19], s[2:3], 0x30                       ; c00a0401 00000030
	s_mov_b32 s1, src_scc                                       ; be8100fd
	s_add_u32 s4, s7, 20                                        ; 80049407
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s4, s[16:19], s4                        ; c0200108 00000004
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_mov_b32_e32 v0, s4                                        ; 7e000204
	v_add_f32_e32 v0, s6, v0                                    ; 02000006
	s_branch BB45                                               ; bf820002
BB44:
	s_mov_b32 s1, src_scc                                       ; be8100fd
	v_mov_b32_e32 v0, s6                                        ; 7e000206
BB45:
	s_cmp_lg_i32 s0, 0                                          ; bf018000
	s_cbranch_scc0 BB47                                         ; bf84000a
BB46:
	s_load_dwordx4 s[16:19], s[2:3], 0x40                       ; c00a0401 00000040
	s_mov_b32 s0, src_scc                                       ; be8000fd
	s_add_u32 s4, s7, 20                                        ; 80049407
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s4, s[16:19], s4                        ; c0200108 00000004
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v0, s4, v0                                    ; 02000004
	s_branch BB48                                               ; bf820001
BB47:
	s_mov_b32 s0, src_scc                                       ; be8000fd
BB48:
	s_add_u32 s4, s7, 20                                        ; 80049407
	buffer_store_dword v0, off, s[12:15], s4                    ; e0700000 04030080
	s_cmp_lg_i32 s1, 0                                          ; bf018001
	s_cbranch_scc0 BB50                                         ; bf84000b
BB49:
	s_load_dwordx4 s[16:19], s[2:3], 0x30                       ; c00a0401 00000030
	s_mov_b32 s1, src_scc                                       ; be8100fd
	s_add_u32 s4, s7, 24                                        ; 80049807
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s4, s[16:19], s4                        ; c0200108 00000004
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_mov_b32_e32 v0, s4                                        ; 7e000204
	v_add_f32_e32 v0, s9, v0                                    ; 02000009
	s_branch BB51                                               ; bf820002
BB50:
	s_mov_b32 s1, src_scc                                       ; be8100fd
	v_mov_b32_e32 v0, s9                                        ; 7e000209
BB51:
	s_cmp_lg_i32 s0, 0                                          ; bf018000
	s_cbranch_scc0 BB53                                         ; bf84000a
BB52:
	s_load_dwordx4 s[16:19], s[2:3], 0x40                       ; c00a0401 00000040
	s_mov_b32 s0, src_scc                                       ; be8000fd
	s_add_u32 s4, s7, 24                                        ; 80049807
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s4, s[16:19], s4                        ; c0200108 00000004
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v0, s4, v0                                    ; 02000004
	s_branch BB54                                               ; bf820001
BB53:
	s_mov_b32 s0, src_scc                                       ; be8000fd
BB54:
	s_add_u32 s4, s7, 24                                        ; 80049807
	buffer_store_dword v0, off, s[12:15], s4                    ; e0700000 04030080
	s_cmp_lg_i32 s1, 0                                          ; bf018001
	s_cbranch_scc0 BB56                                         ; bf84000a
BB55:
	s_load_dwordx4 s[16:19], s[2:3], 0x30                       ; c00a0401 00000030
	s_add_u32 s1, s7, 28                                        ; 80019c07
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s1, s[16:19], s1                        ; c0200048 00000001
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_mov_b32_e32 v0, s1                                        ; 7e000201
	v_add_f32_e32 v0, s10, v0                                   ; 0200000a
	s_branch BB57                                               ; bf820001
BB56:
	v_mov_b32_e32 v0, s10                                       ; 7e00020a
BB57:
	s_cmp_lg_i32 s0, 0                                          ; bf018000
	s_cbranch_scc0 BB60                                         ; bf840008
BB58:
	s_load_dwordx4 s[0:3], s[2:3], 0x40                         ; c00a0001 00000040
	s_add_u32 s4, s7, 28                                        ; 80049c07
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s4, s[0:3], s4                          ; c0200100 00000004
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v0, s4, v0                                    ; 02000004
BB60:
	s_add_u32 s7, s7, 28                                        ; 80079c07
	buffer_store_dword v0, off, s[12:15], s7                    ; e0700000 07030080
	s_branch BB203                                              ; bf8205ad
BB66:
	s_cmp_lt_u32 s16, s4                                        ; bf0a0410
	s_cbranch_scc0 BB203                                        ; bf8405ab
BB67:
	s_sub_i32 s4, s4, s16                                       ; 81841004
	s_add_u32 s17, s17, s9                                      ; 80110911
	s_cmp_lg_i32 s17, 0                                         ; bf018011
	s_cbranch_scc0 BB69                                         ; bf840043
BB68:
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
	s_branch BB70                                               ; bf820001
BB69:
	s_mov_b32 s19, 0                                            ; be930080
BB70:
	s_lshr_b32 s5, s5, 8                                        ; 8f058805
	v_and_b32_e32 v1, 12, v0                                    ; 2602008c
	v_and_b32_e32 v2, 15, v0                                    ; 2604008f
	s_lshr_b32 s3, s3, 8                                        ; 8f038803
	v_lshrrev_b32_e32 v0, 4, v0                                 ; 20000084
	v_mov_b32_e32 v7, 0                                         ; 7e0e0280
	s_mul_i32 s19, s19, s5                                      ; 92130513
	v_mov_b32_e32 v8, 0                                         ; 7e100280
	v_mov_b32_e32 v9, 0                                         ; 7e120280
	v_sub_u32_e32 v1, v2, v1                                    ; 6a020302
	v_bfe_u32 v3, v2, 2, 1                                      ; d1c80003 02050502
	v_lshrrev_b32_e32 v2, 3, v2                                 ; 20040483
	v_mov_b32_e32 v10, 0                                        ; 7e140280
	v_mov_b32_e32 v11, 0                                        ; 7e160280
	v_mov_b32_e32 v12, 0                                        ; 7e180280
	v_mov_b32_e32 v13, 0                                        ; 7e1a0280
	v_lshl_add_u32 v1, v1, 1, v3                                ; d1fd0001 040d0301
	v_mov_b32_e32 v3, 0                                         ; 7e060280
	v_lshlrev_b32_e32 v5, 4, v2                                 ; 240a0484
	v_lshlrev_b32_e32 v1, 2, v1                                 ; 24020282
	v_sub_u32_e32 v6, 16, v5                                    ; 6a0c0a90
	v_lshl_add_u32 v4, v2, 5, v1                                ; d1fd0004 04050b02
	v_lshl_add_u32 v1, v2, 6, v1                                ; d1fd0001 04050d02
BB71:
	s_mov_b64 s[0:1], exec                                      ; be80017e
	v_cmpx_le_u32_e32 vcc, s3, v0                               ; 7db60003
BB72:
	s_andn2_b64 s[0:1], s[0:1], exec                            ; 89807e00
	s_cbranch_scc0 BB101                                        ; bf840368
BB76:
	s_mov_b64 exec, s[0:1]                                      ; befe0100
	s_mov_b32 s0, s2                                            ; be800002
	s_movk_i32 s1, 0x8000                                       ; b0018000
	s_load_dwordx4 s[12:15], s[0:1], 0x10                       ; c00a0300 00000010
	s_mul_i32 s5, s6, s17                                       ; 92051106
	v_lshl_add_u32 v14, v0, 8, v1                               ; d1fd000e 04051100
	v_add_u32_e32 v15, s5, v14                                  ; 681e1c05
	v_add_u32_e32 v14, 0x80, v14                                ; 681c1cff 00000080
	v_lshrrev_b32_e32 v15, 2, v15                               ; 201e1e82
	v_add_u32_e32 v14, s5, v14                                  ; 681c1c05
	v_lshlrev_b32_e32 v15, 4, v15                               ; 241e1e84
	v_lshrrev_b32_e32 v14, 2, v14                               ; 201c1c82
	v_lshlrev_b32_e32 v14, 4, v14                               ; 241c1c84
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_load_dwordx4 v[16:19], v15, s[12:15], 0 offen        ; e05c1000 8003100f
	buffer_load_dwordx4 v[20:23], v15, s[12:15], 0 offen offset:128 ; e05c1080 8003140f
	buffer_load_dwordx4 v[24:27], v14, s[12:15], 0 offen        ; e05c1000 8003180e
	buffer_load_dwordx4 v[28:31], v14, s[12:15], 0 offen offset:128 ; e05c1080 80031c0e
	s_cmp_lg_i32 s4, 0                                          ; bf018004
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_add_f32_e32 v32, v16, v17                                 ; 02402310
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_add_f32_e32 v33, v20, v21                                 ; 02422b14
	v_add_f32_e32 v32, v32, v18                                 ; 02402520
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_add_f32_e32 v34, v24, v25                                 ; 02443318
	v_add_f32_e32 v33, v33, v22                                 ; 02422d21
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_add_f32_e32 v35, v28, v29                                 ; 02463b1c
	v_add_f32_e32 v32, v32, v19                                 ; 02402720
	v_add_f32_e32 v34, v34, v26                                 ; 02443522
	v_add_f32_e32 v33, v33, v23                                 ; 02422f21
	v_add_f32_e32 v35, v35, v30                                 ; 02463d23
	v_add_f32_e32 v34, v34, v27                                 ; 02443722
	v_add_f32_e32 v35, v35, v31                                 ; 02463f23
	s_cbranch_scc0 BB100                                        ; bf84033b
BB77:
	s_load_dwordx4 s[12:15], s[0:1], 0x0                        ; c00a0300 00000000
	s_mul_i32 s0, s16, s3                                       ; 92000310
	v_lshl_add_u32 v36, v2, 1, 8                                ; d1fd0024 02210302
	v_add_u32_e32 v40, 64, v4                                   ; 685008c0
	s_add_u32 s0, s19, s0                                       ; 80000013
	v_add_u32_e32 v14, s0, v0                                   ; 681c0000
	v_lshlrev_b32_e32 v15, 4, v14                               ; 241e1c84
	v_lshl_add_u32 v14, v14, 7, v15                             ; d1fd000e 043d0f0e
	v_add3_u32 v37, v36, 4, v14                                 ; d1ff0025 04390924
	v_add_u32_e32 v38, 16, v14                                  ; 684c1c90
	v_add_u32_e32 v39, v38, v4                                  ; 684e0926
	v_add_u32_e32 v38, v38, v40                                 ; 684c5126
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_load_dwordx3 v[41:43], v14, s[12:15], 0 offen        ; e0581000 8003290e
	buffer_load_ushort v37, v37, s[12:15], 0 offen              ; e0481000 80032525
	buffer_load_dword v39, v39, s[12:15], 0 offen               ; e0501000 80032727
	buffer_load_dword v38, v38, s[12:15], 0 offen               ; e0501000 80032626
	s_bfm_b32 s1, 16, 16                                        ; 91019090
	s_mov_b32 s5, 0xf0f0f0f                                     ; be8500ff 0f0f0f0f
	s_cmp_lt_u32 1, s4                                          ; bf0a0481
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_lshlrev_b32_e32 v43, v6, v43                              ; 24565706
	v_bfe_u32 v42, v42, v5, 16                                  ; d1c8002a 02420b2a
	v_cvt_f32_f16_sdwa v48, v41 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e6016f9 00050629
	v_cvt_f32_f16_e32 v41, v41                                  ; 7e521729
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_lshl_or_b32 v37, v37, 12, v37                             ; d2000025 04951925
	v_and_or_b32 v43, s1, v43, v42                              ; d201002b 04aa5601
	v_and_b32_e32 v44, 0xc0c0c0c0, v43                          ; 265856ff c0c0c0c0
	v_and_b32_e32 v43, 0x3f3f3f3f, v43                          ; 265656ff 3f3f3f3f
	v_lshrrev_b32_e32 v44, 2, v44                               ; 20585882
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v52, s5, v39                                  ; 26684e05
	v_cvt_f32_ubyte3_e32 v45, v43                               ; 7e5a292b
	v_cvt_f32_ubyte2_e32 v46, v43                               ; 7e5c272b
	v_cvt_f32_ubyte1_e32 v47, v43                               ; 7e5e252b
	v_cvt_f32_ubyte0_e32 v43, v43                               ; 7e56232b
	v_and_or_b32 v37, s5, v37, v44                              ; d2010025 04b24a05
	v_cvt_f32_ubyte3_e32 v53, v52                               ; 7e6a2934
	v_cvt_f32_ubyte2_e32 v54, v52                               ; 7e6c2734
	v_cvt_f32_ubyte1_e32 v55, v52                               ; 7e6e2534
	v_cvt_f32_ubyte0_e32 v52, v52                               ; 7e682334
	v_cvt_f32_ubyte3_e32 v49, v37                               ; 7e622925
	v_cvt_f32_ubyte2_e32 v50, v37                               ; 7e642725
	v_cvt_f32_ubyte1_e32 v51, v37                               ; 7e662525
	v_cvt_f32_ubyte0_e32 v37, v37                               ; 7e4a2325
	v_mul_f32_e32 v53, v19, v53                                 ; 0a6a6b13
	v_lshrrev_b32_e32 v39, 4, v39                               ; 204e4e84
	v_mul_f32_e32 v49, v35, v49                                 ; 0a626323
	v_mac_f32_e32 v53, v18, v54                                 ; 2c6a6d12
	v_and_b32_e32 v39, s5, v39                                  ; 264e4e05
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v59, s5, v38                                  ; 26764c05
	v_mac_f32_e32 v49, v34, v50                                 ; 2c626522
	v_mac_f32_e32 v53, v17, v55                                 ; 2c6a6f11
	v_cvt_f32_ubyte3_e32 v56, v39                               ; 7e702927
	v_cvt_f32_ubyte2_e32 v57, v39                               ; 7e722727
	v_cvt_f32_ubyte1_e32 v58, v39                               ; 7e742527
	v_cvt_f32_ubyte0_e32 v39, v39                               ; 7e4e2327
	v_cvt_f32_ubyte2_e32 v61, v59                               ; 7e7a273b
	v_cvt_f32_ubyte3_e32 v60, v59                               ; 7e78293b
	v_mac_f32_e32 v49, v33, v45                                 ; 2c625b21
	v_cvt_f32_ubyte1_e32 v62, v59                               ; 7e7c253b
	v_mac_f32_e32 v53, v16, v52                                 ; 2c6a6910
	v_mul_f32_e32 v56, v23, v56                                 ; 0a707117
	v_cvt_f32_ubyte0_e32 v59, v59                               ; 7e76233b
	v_lshrrev_b32_e32 v38, 4, v38                               ; 204c4c84
	v_mul_f32_e32 v60, v27, v60                                 ; 0a78791b
	v_mac_f32_e32 v49, v32, v46                                 ; 2c625d20
	v_mac_f32_e32 v56, v22, v57                                 ; 2c707316
	v_and_b32_e32 v38, s5, v38                                  ; 264c4c05
	v_mac_f32_e32 v60, v26, v61                                 ; 2c787b1a
	v_mad_f32 v3, -v48, v49, v3                                 ; d1c10003 240e6330
	v_mac_f32_e32 v56, v21, v58                                 ; 2c707515
	v_cvt_f32_ubyte1_e32 v15, v38                               ; 7e1e2526
	v_cvt_f32_ubyte2_e32 v14, v38                               ; 7e1c2726
	v_mac_f32_e32 v60, v25, v62                                 ; 2c787d19
	v_cvt_f32_ubyte3_e32 v62, v38                               ; 7e7c2926
	v_cvt_f32_ubyte0_e32 v38, v38                               ; 7e4c2326
	v_mac_f32_e32 v56, v20, v39                                 ; 2c704f14
	v_mac_f32_e32 v60, v24, v59                                 ; 2c787718
	v_mul_f32_e32 v62, v31, v62                                 ; 0a7c7d1f
	v_mac_f32_e32 v62, v30, v14                                 ; 2c7c1d1e
	v_mac_f32_e32 v62, v29, v15                                 ; 2c7c1f1d
	v_mac_f32_e32 v62, v28, v38                                 ; 2c7c4d1c
	v_mul_f32_e32 v62, v62, v51                                 ; 0a7c673e
	v_mac_f32_e32 v62, v60, v37                                 ; 2c7c4b3c
	v_mac_f32_e32 v62, v56, v47                                 ; 2c7c5f38
	v_mac_f32_e32 v62, v53, v43                                 ; 2c7c5735
	v_mac_f32_e32 v3, v41, v62                                  ; 2c067d29
	s_cbranch_scc0 BB100                                        ; bf8402cf
BB78:
	s_add_u32 s0, s16, 1                                        ; 80008110
	s_mul_i32 s0, s0, s3                                        ; 92000300
	s_add_u32 s0, s19, s0                                       ; 80000013
	v_add_u32_e32 v14, s0, v0                                   ; 681c0000
	v_lshlrev_b32_e32 v15, 4, v14                               ; 241e1c84
	v_lshl_add_u32 v14, v14, 7, v15                             ; d1fd000e 043d0f0e
	v_add3_u32 v37, v36, 4, v14                                 ; d1ff0025 04390924
	v_add_u32_e32 v38, 16, v14                                  ; 684c1c90
	v_add_u32_e32 v39, v38, v4                                  ; 684e0926
	v_add_u32_e32 v38, v38, v40                                 ; 684c5126
	buffer_load_dwordx3 v[41:43], v14, s[12:15], 0 offen        ; e0581000 8003290e
	buffer_load_ushort v37, v37, s[12:15], 0 offen              ; e0481000 80032525
	buffer_load_dword v39, v39, s[12:15], 0 offen               ; e0501000 80032727
	buffer_load_dword v38, v38, s[12:15], 0 offen               ; e0501000 80032626
	s_bfm_b32 s1, 16, 16                                        ; 91019090
	s_mov_b32 s5, 0xf0f0f0f                                     ; be8500ff 0f0f0f0f
	s_cmp_lt_u32 2, s4                                          ; bf0a0482
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_bfe_u32 v42, v42, v5, 16                                  ; d1c8002a 02420b2a
	v_lshlrev_b32_e32 v43, v6, v43                              ; 24565706
	v_cvt_f32_f16_sdwa v48, v41 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e6016f9 00050629
	v_cvt_f32_f16_e32 v41, v41                                  ; 7e521729
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_lshl_or_b32 v37, v37, 12, v37                             ; d2000025 04951925
	v_and_or_b32 v43, s1, v43, v42                              ; d201002b 04aa5601
	v_and_b32_e32 v44, 0xc0c0c0c0, v43                          ; 265856ff c0c0c0c0
	v_and_b32_e32 v43, 0x3f3f3f3f, v43                          ; 265656ff 3f3f3f3f
	v_lshrrev_b32_e32 v44, 2, v44                               ; 20585882
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v52, s5, v39                                  ; 26684e05
	v_cvt_f32_ubyte3_e32 v45, v43                               ; 7e5a292b
	v_cvt_f32_ubyte2_e32 v46, v43                               ; 7e5c272b
	v_cvt_f32_ubyte1_e32 v47, v43                               ; 7e5e252b
	v_cvt_f32_ubyte0_e32 v43, v43                               ; 7e56232b
	v_and_or_b32 v37, s5, v37, v44                              ; d2010025 04b24a05
	v_cvt_f32_ubyte3_e32 v53, v52                               ; 7e6a2934
	v_cvt_f32_ubyte2_e32 v54, v52                               ; 7e6c2734
	v_cvt_f32_ubyte1_e32 v55, v52                               ; 7e6e2534
	v_cvt_f32_ubyte0_e32 v52, v52                               ; 7e682334
	v_cvt_f32_ubyte2_e32 v50, v37                               ; 7e642725
	v_cvt_f32_ubyte1_e32 v51, v37                               ; 7e662525
	v_cvt_f32_ubyte3_e32 v49, v37                               ; 7e622925
	v_cvt_f32_ubyte0_e32 v37, v37                               ; 7e4a2325
	v_mul_f32_e32 v53, v19, v53                                 ; 0a6a6b13
	v_lshrrev_b32_e32 v39, 4, v39                               ; 204e4e84
	v_mul_f32_e32 v49, v35, v49                                 ; 0a626323
	v_mac_f32_e32 v53, v18, v54                                 ; 2c6a6d12
	v_and_b32_e32 v39, s5, v39                                  ; 264e4e05
	v_mac_f32_e32 v49, v34, v50                                 ; 2c626522
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v59, s5, v38                                  ; 26764c05
	v_mac_f32_e32 v53, v17, v55                                 ; 2c6a6f11
	v_cvt_f32_ubyte1_e32 v58, v39                               ; 7e742527
	v_cvt_f32_ubyte2_e32 v57, v39                               ; 7e722727
	v_cvt_f32_ubyte3_e32 v56, v39                               ; 7e702927
	v_cvt_f32_ubyte0_e32 v39, v39                               ; 7e4e2327
	v_mac_f32_e32 v49, v33, v45                                 ; 2c625b21
	v_cvt_f32_ubyte2_e32 v61, v59                               ; 7e7a273b
	v_cvt_f32_ubyte3_e32 v60, v59                               ; 7e78293b
	v_cvt_f32_ubyte1_e32 v62, v59                               ; 7e7c253b
	v_mac_f32_e32 v53, v16, v52                                 ; 2c6a6910
	v_cvt_f32_ubyte0_e32 v59, v59                               ; 7e76233b
	v_mul_f32_e32 v56, v23, v56                                 ; 0a707117
	v_lshrrev_b32_e32 v38, 4, v38                               ; 204c4c84
	v_mac_f32_e32 v49, v32, v46                                 ; 2c625d20
	v_mul_f32_e32 v60, v27, v60                                 ; 0a78791b
	v_mac_f32_e32 v56, v22, v57                                 ; 2c707316
	v_and_b32_e32 v38, s5, v38                                  ; 264c4c05
	v_mad_f32 v7, -v48, v49, v7                                 ; d1c10007 241e6330
	v_mac_f32_e32 v60, v26, v61                                 ; 2c787b1a
	v_mac_f32_e32 v56, v21, v58                                 ; 2c707515
	v_cvt_f32_ubyte1_e32 v15, v38                               ; 7e1e2526
	v_cvt_f32_ubyte2_e32 v14, v38                               ; 7e1c2726
	v_mac_f32_e32 v60, v25, v62                                 ; 2c787d19
	v_cvt_f32_ubyte3_e32 v62, v38                               ; 7e7c2926
	v_cvt_f32_ubyte0_e32 v38, v38                               ; 7e4c2326
	v_mac_f32_e32 v56, v20, v39                                 ; 2c704f14
	v_mac_f32_e32 v60, v24, v59                                 ; 2c787718
	v_mul_f32_e32 v62, v31, v62                                 ; 0a7c7d1f
	v_mac_f32_e32 v62, v30, v14                                 ; 2c7c1d1e
	v_mac_f32_e32 v62, v29, v15                                 ; 2c7c1f1d
	v_mac_f32_e32 v62, v28, v38                                 ; 2c7c4d1c
	v_mul_f32_e32 v62, v62, v51                                 ; 0a7c673e
	v_mac_f32_e32 v62, v60, v37                                 ; 2c7c4b3c
	v_mac_f32_e32 v62, v56, v47                                 ; 2c7c5f38
	v_mac_f32_e32 v62, v53, v43                                 ; 2c7c5735
	v_mac_f32_e32 v7, v41, v62                                  ; 2c0e7d29
	s_cbranch_scc0 BB100                                        ; bf840268
BB79:
	s_add_u32 s0, s16, 2                                        ; 80008210
	s_mul_i32 s0, s0, s3                                        ; 92000300
	s_add_u32 s0, s19, s0                                       ; 80000013
	v_add_u32_e32 v14, s0, v0                                   ; 681c0000
	v_lshlrev_b32_e32 v15, 4, v14                               ; 241e1c84
	v_lshl_add_u32 v14, v14, 7, v15                             ; d1fd000e 043d0f0e
	v_add3_u32 v37, v36, 4, v14                                 ; d1ff0025 04390924
	v_add_u32_e32 v38, 16, v14                                  ; 684c1c90
	v_add_u32_e32 v39, v38, v4                                  ; 684e0926
	v_add_u32_e32 v38, v38, v40                                 ; 684c5126
	buffer_load_dwordx3 v[41:43], v14, s[12:15], 0 offen        ; e0581000 8003290e
	buffer_load_ushort v37, v37, s[12:15], 0 offen              ; e0481000 80032525
	buffer_load_dword v39, v39, s[12:15], 0 offen               ; e0501000 80032727
	buffer_load_dword v38, v38, s[12:15], 0 offen               ; e0501000 80032626
	s_bfm_b32 s1, 16, 16                                        ; 91019090
	s_mov_b32 s5, 0xf0f0f0f                                     ; be8500ff 0f0f0f0f
	s_cmp_lt_u32 3, s4                                          ; bf0a0483
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_bfe_u32 v42, v42, v5, 16                                  ; d1c8002a 02420b2a
	v_lshlrev_b32_e32 v43, v6, v43                              ; 24565706
	v_cvt_f32_f16_sdwa v48, v41 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e6016f9 00050629
	v_cvt_f32_f16_e32 v41, v41                                  ; 7e521729
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_lshl_or_b32 v37, v37, 12, v37                             ; d2000025 04951925
	v_and_or_b32 v43, s1, v43, v42                              ; d201002b 04aa5601
	v_and_b32_e32 v44, 0xc0c0c0c0, v43                          ; 265856ff c0c0c0c0
	v_and_b32_e32 v43, 0x3f3f3f3f, v43                          ; 265656ff 3f3f3f3f
	v_lshrrev_b32_e32 v44, 2, v44                               ; 20585882
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v52, s5, v39                                  ; 26684e05
	v_cvt_f32_ubyte3_e32 v45, v43                               ; 7e5a292b
	v_cvt_f32_ubyte2_e32 v46, v43                               ; 7e5c272b
	v_cvt_f32_ubyte1_e32 v47, v43                               ; 7e5e252b
	v_cvt_f32_ubyte0_e32 v43, v43                               ; 7e56232b
	v_and_or_b32 v37, s5, v37, v44                              ; d2010025 04b24a05
	v_cvt_f32_ubyte3_e32 v53, v52                               ; 7e6a2934
	v_cvt_f32_ubyte2_e32 v54, v52                               ; 7e6c2734
	v_cvt_f32_ubyte1_e32 v55, v52                               ; 7e6e2534
	v_cvt_f32_ubyte0_e32 v52, v52                               ; 7e682334
	v_cvt_f32_ubyte2_e32 v50, v37                               ; 7e642725
	v_cvt_f32_ubyte1_e32 v51, v37                               ; 7e662525
	v_cvt_f32_ubyte3_e32 v49, v37                               ; 7e622925
	v_cvt_f32_ubyte0_e32 v37, v37                               ; 7e4a2325
	v_mul_f32_e32 v53, v19, v53                                 ; 0a6a6b13
	v_lshrrev_b32_e32 v39, 4, v39                               ; 204e4e84
	v_mul_f32_e32 v49, v35, v49                                 ; 0a626323
	v_mac_f32_e32 v53, v18, v54                                 ; 2c6a6d12
	v_and_b32_e32 v39, s5, v39                                  ; 264e4e05
	v_mac_f32_e32 v49, v34, v50                                 ; 2c626522
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v59, s5, v38                                  ; 26764c05
	v_mac_f32_e32 v53, v17, v55                                 ; 2c6a6f11
	v_cvt_f32_ubyte1_e32 v58, v39                               ; 7e742527
	v_cvt_f32_ubyte2_e32 v57, v39                               ; 7e722727
	v_cvt_f32_ubyte3_e32 v56, v39                               ; 7e702927
	v_cvt_f32_ubyte0_e32 v39, v39                               ; 7e4e2327
	v_mac_f32_e32 v49, v33, v45                                 ; 2c625b21
	v_cvt_f32_ubyte2_e32 v61, v59                               ; 7e7a273b
	v_cvt_f32_ubyte3_e32 v60, v59                               ; 7e78293b
	v_cvt_f32_ubyte1_e32 v62, v59                               ; 7e7c253b
	v_mac_f32_e32 v53, v16, v52                                 ; 2c6a6910
	v_cvt_f32_ubyte0_e32 v59, v59                               ; 7e76233b
	v_mul_f32_e32 v56, v23, v56                                 ; 0a707117
	v_lshrrev_b32_e32 v38, 4, v38                               ; 204c4c84
	v_mac_f32_e32 v49, v32, v46                                 ; 2c625d20
	v_mul_f32_e32 v60, v27, v60                                 ; 0a78791b
	v_mac_f32_e32 v56, v22, v57                                 ; 2c707316
	v_and_b32_e32 v38, s5, v38                                  ; 264c4c05
	v_mad_f32 v8, -v48, v49, v8                                 ; d1c10008 24226330
	v_mac_f32_e32 v60, v26, v61                                 ; 2c787b1a
	v_mac_f32_e32 v56, v21, v58                                 ; 2c707515
	v_cvt_f32_ubyte1_e32 v15, v38                               ; 7e1e2526
	v_cvt_f32_ubyte2_e32 v14, v38                               ; 7e1c2726
	v_mac_f32_e32 v60, v25, v62                                 ; 2c787d19
	v_cvt_f32_ubyte3_e32 v62, v38                               ; 7e7c2926
	v_cvt_f32_ubyte0_e32 v38, v38                               ; 7e4c2326
	v_mac_f32_e32 v56, v20, v39                                 ; 2c704f14
	v_mac_f32_e32 v60, v24, v59                                 ; 2c787718
	v_mul_f32_e32 v62, v31, v62                                 ; 0a7c7d1f
	v_mac_f32_e32 v62, v30, v14                                 ; 2c7c1d1e
	v_mac_f32_e32 v62, v29, v15                                 ; 2c7c1f1d
	v_mac_f32_e32 v62, v28, v38                                 ; 2c7c4d1c
	v_mul_f32_e32 v62, v62, v51                                 ; 0a7c673e
	v_mac_f32_e32 v62, v60, v37                                 ; 2c7c4b3c
	v_mac_f32_e32 v62, v56, v47                                 ; 2c7c5f38
	v_mac_f32_e32 v62, v53, v43                                 ; 2c7c5735
	v_mac_f32_e32 v8, v41, v62                                  ; 2c107d29
	s_cbranch_scc0 BB100                                        ; bf840201
BB80:
	s_add_u32 s0, s16, 3                                        ; 80008310
	s_mul_i32 s0, s0, s3                                        ; 92000300
	s_add_u32 s0, s19, s0                                       ; 80000013
	v_add_u32_e32 v14, s0, v0                                   ; 681c0000
	v_lshlrev_b32_e32 v15, 4, v14                               ; 241e1c84
	v_lshl_add_u32 v14, v14, 7, v15                             ; d1fd000e 043d0f0e
	v_add3_u32 v37, v36, 4, v14                                 ; d1ff0025 04390924
	v_add_u32_e32 v38, 16, v14                                  ; 684c1c90
	v_add_u32_e32 v39, v38, v4                                  ; 684e0926
	v_add_u32_e32 v38, v38, v40                                 ; 684c5126
	buffer_load_dwordx3 v[41:43], v14, s[12:15], 0 offen        ; e0581000 8003290e
	buffer_load_ushort v37, v37, s[12:15], 0 offen              ; e0481000 80032525
	buffer_load_dword v39, v39, s[12:15], 0 offen               ; e0501000 80032727
	buffer_load_dword v38, v38, s[12:15], 0 offen               ; e0501000 80032626
	s_bfm_b32 s1, 16, 16                                        ; 91019090
	s_mov_b32 s5, 0xf0f0f0f                                     ; be8500ff 0f0f0f0f
	s_cmp_lt_u32 4, s4                                          ; bf0a0484
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_bfe_u32 v42, v42, v5, 16                                  ; d1c8002a 02420b2a
	v_lshlrev_b32_e32 v43, v6, v43                              ; 24565706
	v_cvt_f32_f16_sdwa v48, v41 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e6016f9 00050629
	v_cvt_f32_f16_e32 v41, v41                                  ; 7e521729
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_lshl_or_b32 v37, v37, 12, v37                             ; d2000025 04951925
	v_and_or_b32 v43, s1, v43, v42                              ; d201002b 04aa5601
	v_and_b32_e32 v44, 0xc0c0c0c0, v43                          ; 265856ff c0c0c0c0
	v_and_b32_e32 v43, 0x3f3f3f3f, v43                          ; 265656ff 3f3f3f3f
	v_lshrrev_b32_e32 v44, 2, v44                               ; 20585882
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v52, s5, v39                                  ; 26684e05
	v_cvt_f32_ubyte3_e32 v45, v43                               ; 7e5a292b
	v_cvt_f32_ubyte2_e32 v46, v43                               ; 7e5c272b
	v_cvt_f32_ubyte1_e32 v47, v43                               ; 7e5e252b
	v_cvt_f32_ubyte0_e32 v43, v43                               ; 7e56232b
	v_and_or_b32 v37, s5, v37, v44                              ; d2010025 04b24a05
	v_cvt_f32_ubyte3_e32 v53, v52                               ; 7e6a2934
	v_cvt_f32_ubyte2_e32 v54, v52                               ; 7e6c2734
	v_cvt_f32_ubyte1_e32 v55, v52                               ; 7e6e2534
	v_cvt_f32_ubyte0_e32 v52, v52                               ; 7e682334
	v_cvt_f32_ubyte2_e32 v50, v37                               ; 7e642725
	v_cvt_f32_ubyte1_e32 v51, v37                               ; 7e662525
	v_cvt_f32_ubyte3_e32 v49, v37                               ; 7e622925
	v_cvt_f32_ubyte0_e32 v37, v37                               ; 7e4a2325
	v_mul_f32_e32 v53, v19, v53                                 ; 0a6a6b13
	v_lshrrev_b32_e32 v39, 4, v39                               ; 204e4e84
	v_mul_f32_e32 v49, v35, v49                                 ; 0a626323
	v_mac_f32_e32 v53, v18, v54                                 ; 2c6a6d12
	v_and_b32_e32 v39, s5, v39                                  ; 264e4e05
	v_mac_f32_e32 v49, v34, v50                                 ; 2c626522
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v59, s5, v38                                  ; 26764c05
	v_mac_f32_e32 v53, v17, v55                                 ; 2c6a6f11
	v_cvt_f32_ubyte1_e32 v58, v39                               ; 7e742527
	v_cvt_f32_ubyte2_e32 v57, v39                               ; 7e722727
	v_cvt_f32_ubyte3_e32 v56, v39                               ; 7e702927
	v_cvt_f32_ubyte0_e32 v39, v39                               ; 7e4e2327
	v_mac_f32_e32 v49, v33, v45                                 ; 2c625b21
	v_cvt_f32_ubyte2_e32 v61, v59                               ; 7e7a273b
	v_cvt_f32_ubyte3_e32 v60, v59                               ; 7e78293b
	v_cvt_f32_ubyte1_e32 v62, v59                               ; 7e7c253b
	v_mac_f32_e32 v53, v16, v52                                 ; 2c6a6910
	v_cvt_f32_ubyte0_e32 v59, v59                               ; 7e76233b
	v_mul_f32_e32 v56, v23, v56                                 ; 0a707117
	v_lshrrev_b32_e32 v38, 4, v38                               ; 204c4c84
	v_mac_f32_e32 v49, v32, v46                                 ; 2c625d20
	v_mul_f32_e32 v60, v27, v60                                 ; 0a78791b
	v_mac_f32_e32 v56, v22, v57                                 ; 2c707316
	v_and_b32_e32 v38, s5, v38                                  ; 264c4c05
	v_mad_f32 v9, -v48, v49, v9                                 ; d1c10009 24266330
	v_mac_f32_e32 v60, v26, v61                                 ; 2c787b1a
	v_mac_f32_e32 v56, v21, v58                                 ; 2c707515
	v_cvt_f32_ubyte1_e32 v15, v38                               ; 7e1e2526
	v_cvt_f32_ubyte2_e32 v14, v38                               ; 7e1c2726
	v_mac_f32_e32 v60, v25, v62                                 ; 2c787d19
	v_cvt_f32_ubyte3_e32 v62, v38                               ; 7e7c2926
	v_cvt_f32_ubyte0_e32 v38, v38                               ; 7e4c2326
	v_mac_f32_e32 v56, v20, v39                                 ; 2c704f14
	v_mac_f32_e32 v60, v24, v59                                 ; 2c787718
	v_mul_f32_e32 v62, v31, v62                                 ; 0a7c7d1f
	v_mac_f32_e32 v62, v30, v14                                 ; 2c7c1d1e
	v_mac_f32_e32 v62, v29, v15                                 ; 2c7c1f1d
	v_mac_f32_e32 v62, v28, v38                                 ; 2c7c4d1c
	v_mul_f32_e32 v62, v62, v51                                 ; 0a7c673e
	v_mac_f32_e32 v62, v60, v37                                 ; 2c7c4b3c
	v_mac_f32_e32 v62, v56, v47                                 ; 2c7c5f38
	v_mac_f32_e32 v62, v53, v43                                 ; 2c7c5735
	v_mac_f32_e32 v9, v41, v62                                  ; 2c127d29
	s_cbranch_scc0 BB100                                        ; bf84019a
BB81:
	s_add_u32 s0, s16, 4                                        ; 80008410
	s_mul_i32 s0, s0, s3                                        ; 92000300
	s_add_u32 s0, s19, s0                                       ; 80000013
	v_add_u32_e32 v14, s0, v0                                   ; 681c0000
	v_lshlrev_b32_e32 v15, 4, v14                               ; 241e1c84
	v_lshl_add_u32 v14, v14, 7, v15                             ; d1fd000e 043d0f0e
	v_add3_u32 v37, v36, 4, v14                                 ; d1ff0025 04390924
	v_add_u32_e32 v38, 16, v14                                  ; 684c1c90
	v_add_u32_e32 v39, v38, v4                                  ; 684e0926
	v_add_u32_e32 v38, v38, v40                                 ; 684c5126
	buffer_load_dwordx3 v[41:43], v14, s[12:15], 0 offen        ; e0581000 8003290e
	buffer_load_ushort v37, v37, s[12:15], 0 offen              ; e0481000 80032525
	buffer_load_dword v39, v39, s[12:15], 0 offen               ; e0501000 80032727
	buffer_load_dword v38, v38, s[12:15], 0 offen               ; e0501000 80032626
	s_bfm_b32 s1, 16, 16                                        ; 91019090
	s_mov_b32 s5, 0xf0f0f0f                                     ; be8500ff 0f0f0f0f
	s_cmp_lt_u32 5, s4                                          ; bf0a0485
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_bfe_u32 v42, v42, v5, 16                                  ; d1c8002a 02420b2a
	v_lshlrev_b32_e32 v43, v6, v43                              ; 24565706
	v_cvt_f32_f16_sdwa v48, v41 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e6016f9 00050629
	v_cvt_f32_f16_e32 v41, v41                                  ; 7e521729
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_lshl_or_b32 v37, v37, 12, v37                             ; d2000025 04951925
	v_and_or_b32 v43, s1, v43, v42                              ; d201002b 04aa5601
	v_and_b32_e32 v44, 0xc0c0c0c0, v43                          ; 265856ff c0c0c0c0
	v_and_b32_e32 v43, 0x3f3f3f3f, v43                          ; 265656ff 3f3f3f3f
	v_lshrrev_b32_e32 v44, 2, v44                               ; 20585882
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v52, s5, v39                                  ; 26684e05
	v_cvt_f32_ubyte3_e32 v45, v43                               ; 7e5a292b
	v_cvt_f32_ubyte2_e32 v46, v43                               ; 7e5c272b
	v_cvt_f32_ubyte1_e32 v47, v43                               ; 7e5e252b
	v_cvt_f32_ubyte0_e32 v43, v43                               ; 7e56232b
	v_and_or_b32 v37, s5, v37, v44                              ; d2010025 04b24a05
	v_cvt_f32_ubyte3_e32 v53, v52                               ; 7e6a2934
	v_cvt_f32_ubyte2_e32 v54, v52                               ; 7e6c2734
	v_cvt_f32_ubyte1_e32 v55, v52                               ; 7e6e2534
	v_cvt_f32_ubyte0_e32 v52, v52                               ; 7e682334
	v_cvt_f32_ubyte2_e32 v50, v37                               ; 7e642725
	v_cvt_f32_ubyte1_e32 v51, v37                               ; 7e662525
	v_cvt_f32_ubyte3_e32 v49, v37                               ; 7e622925
	v_cvt_f32_ubyte0_e32 v37, v37                               ; 7e4a2325
	v_mul_f32_e32 v53, v19, v53                                 ; 0a6a6b13
	v_lshrrev_b32_e32 v39, 4, v39                               ; 204e4e84
	v_mul_f32_e32 v49, v35, v49                                 ; 0a626323
	v_mac_f32_e32 v53, v18, v54                                 ; 2c6a6d12
	v_and_b32_e32 v39, s5, v39                                  ; 264e4e05
	v_mac_f32_e32 v49, v34, v50                                 ; 2c626522
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v59, s5, v38                                  ; 26764c05
	v_mac_f32_e32 v53, v17, v55                                 ; 2c6a6f11
	v_cvt_f32_ubyte1_e32 v58, v39                               ; 7e742527
	v_cvt_f32_ubyte2_e32 v57, v39                               ; 7e722727
	v_cvt_f32_ubyte3_e32 v56, v39                               ; 7e702927
	v_cvt_f32_ubyte0_e32 v39, v39                               ; 7e4e2327
	v_mac_f32_e32 v49, v33, v45                                 ; 2c625b21
	v_cvt_f32_ubyte2_e32 v61, v59                               ; 7e7a273b
	v_cvt_f32_ubyte3_e32 v60, v59                               ; 7e78293b
	v_cvt_f32_ubyte1_e32 v62, v59                               ; 7e7c253b
	v_mac_f32_e32 v53, v16, v52                                 ; 2c6a6910
	v_cvt_f32_ubyte0_e32 v59, v59                               ; 7e76233b
	v_mul_f32_e32 v56, v23, v56                                 ; 0a707117
	v_lshrrev_b32_e32 v38, 4, v38                               ; 204c4c84
	v_mac_f32_e32 v49, v32, v46                                 ; 2c625d20
	v_mul_f32_e32 v60, v27, v60                                 ; 0a78791b
	v_mac_f32_e32 v56, v22, v57                                 ; 2c707316
	v_and_b32_e32 v38, s5, v38                                  ; 264c4c05
	v_mad_f32 v10, -v48, v49, v10                               ; d1c1000a 242a6330
	v_mac_f32_e32 v60, v26, v61                                 ; 2c787b1a
	v_mac_f32_e32 v56, v21, v58                                 ; 2c707515
	v_cvt_f32_ubyte1_e32 v15, v38                               ; 7e1e2526
	v_cvt_f32_ubyte2_e32 v14, v38                               ; 7e1c2726
	v_mac_f32_e32 v60, v25, v62                                 ; 2c787d19
	v_cvt_f32_ubyte3_e32 v62, v38                               ; 7e7c2926
	v_cvt_f32_ubyte0_e32 v38, v38                               ; 7e4c2326
	v_mac_f32_e32 v56, v20, v39                                 ; 2c704f14
	v_mac_f32_e32 v60, v24, v59                                 ; 2c787718
	v_mul_f32_e32 v62, v31, v62                                 ; 0a7c7d1f
	v_mac_f32_e32 v62, v30, v14                                 ; 2c7c1d1e
	v_mac_f32_e32 v62, v29, v15                                 ; 2c7c1f1d
	v_mac_f32_e32 v62, v28, v38                                 ; 2c7c4d1c
	v_mul_f32_e32 v62, v62, v51                                 ; 0a7c673e
	v_mac_f32_e32 v62, v60, v37                                 ; 2c7c4b3c
	v_mac_f32_e32 v62, v56, v47                                 ; 2c7c5f38
	v_mac_f32_e32 v62, v53, v43                                 ; 2c7c5735
	v_mac_f32_e32 v10, v41, v62                                 ; 2c147d29
	s_cbranch_scc0 BB100                                        ; bf840133
BB82:
	s_add_u32 s0, s16, 5                                        ; 80008510
	s_mul_i32 s0, s0, s3                                        ; 92000300
	s_add_u32 s0, s19, s0                                       ; 80000013
	v_add_u32_e32 v14, s0, v0                                   ; 681c0000
	v_lshlrev_b32_e32 v15, 4, v14                               ; 241e1c84
	v_lshl_add_u32 v14, v14, 7, v15                             ; d1fd000e 043d0f0e
	v_add3_u32 v37, v36, 4, v14                                 ; d1ff0025 04390924
	v_add_u32_e32 v38, 16, v14                                  ; 684c1c90
	v_add_u32_e32 v39, v38, v4                                  ; 684e0926
	v_add_u32_e32 v38, v38, v40                                 ; 684c5126
	buffer_load_dwordx3 v[41:43], v14, s[12:15], 0 offen        ; e0581000 8003290e
	buffer_load_ushort v37, v37, s[12:15], 0 offen              ; e0481000 80032525
	buffer_load_dword v39, v39, s[12:15], 0 offen               ; e0501000 80032727
	buffer_load_dword v38, v38, s[12:15], 0 offen               ; e0501000 80032626
	s_bfm_b32 s1, 16, 16                                        ; 91019090
	s_mov_b32 s5, 0xf0f0f0f                                     ; be8500ff 0f0f0f0f
	s_cmp_lt_u32 6, s4                                          ; bf0a0486
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_bfe_u32 v42, v42, v5, 16                                  ; d1c8002a 02420b2a
	v_lshlrev_b32_e32 v43, v6, v43                              ; 24565706
	v_cvt_f32_f16_sdwa v48, v41 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e6016f9 00050629
	v_cvt_f32_f16_e32 v41, v41                                  ; 7e521729
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_lshl_or_b32 v37, v37, 12, v37                             ; d2000025 04951925
	v_and_or_b32 v43, s1, v43, v42                              ; d201002b 04aa5601
	v_and_b32_e32 v44, 0xc0c0c0c0, v43                          ; 265856ff c0c0c0c0
	v_and_b32_e32 v43, 0x3f3f3f3f, v43                          ; 265656ff 3f3f3f3f
	v_lshrrev_b32_e32 v44, 2, v44                               ; 20585882
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v52, s5, v39                                  ; 26684e05
	v_cvt_f32_ubyte3_e32 v45, v43                               ; 7e5a292b
	v_cvt_f32_ubyte2_e32 v46, v43                               ; 7e5c272b
	v_cvt_f32_ubyte1_e32 v47, v43                               ; 7e5e252b
	v_cvt_f32_ubyte0_e32 v43, v43                               ; 7e56232b
	v_and_or_b32 v37, s5, v37, v44                              ; d2010025 04b24a05
	v_cvt_f32_ubyte3_e32 v53, v52                               ; 7e6a2934
	v_cvt_f32_ubyte2_e32 v54, v52                               ; 7e6c2734
	v_cvt_f32_ubyte1_e32 v55, v52                               ; 7e6e2534
	v_cvt_f32_ubyte0_e32 v52, v52                               ; 7e682334
	v_cvt_f32_ubyte2_e32 v50, v37                               ; 7e642725
	v_cvt_f32_ubyte1_e32 v51, v37                               ; 7e662525
	v_cvt_f32_ubyte3_e32 v49, v37                               ; 7e622925
	v_cvt_f32_ubyte0_e32 v37, v37                               ; 7e4a2325
	v_mul_f32_e32 v53, v19, v53                                 ; 0a6a6b13
	v_lshrrev_b32_e32 v39, 4, v39                               ; 204e4e84
	v_mul_f32_e32 v49, v35, v49                                 ; 0a626323
	v_mac_f32_e32 v53, v18, v54                                 ; 2c6a6d12
	v_and_b32_e32 v39, s5, v39                                  ; 264e4e05
	v_mac_f32_e32 v49, v34, v50                                 ; 2c626522
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v59, s5, v38                                  ; 26764c05
	v_mac_f32_e32 v53, v17, v55                                 ; 2c6a6f11
	v_cvt_f32_ubyte1_e32 v58, v39                               ; 7e742527
	v_cvt_f32_ubyte2_e32 v57, v39                               ; 7e722727
	v_cvt_f32_ubyte3_e32 v56, v39                               ; 7e702927
	v_cvt_f32_ubyte0_e32 v39, v39                               ; 7e4e2327
	v_mac_f32_e32 v49, v33, v45                                 ; 2c625b21
	v_cvt_f32_ubyte2_e32 v61, v59                               ; 7e7a273b
	v_cvt_f32_ubyte3_e32 v60, v59                               ; 7e78293b
	v_cvt_f32_ubyte1_e32 v62, v59                               ; 7e7c253b
	v_mac_f32_e32 v53, v16, v52                                 ; 2c6a6910
	v_cvt_f32_ubyte0_e32 v59, v59                               ; 7e76233b
	v_mul_f32_e32 v56, v23, v56                                 ; 0a707117
	v_lshrrev_b32_e32 v38, 4, v38                               ; 204c4c84
	v_mac_f32_e32 v49, v32, v46                                 ; 2c625d20
	v_mul_f32_e32 v60, v27, v60                                 ; 0a78791b
	v_mac_f32_e32 v56, v22, v57                                 ; 2c707316
	v_and_b32_e32 v38, s5, v38                                  ; 264c4c05
	v_mad_f32 v11, -v48, v49, v11                               ; d1c1000b 242e6330
	v_mac_f32_e32 v60, v26, v61                                 ; 2c787b1a
	v_mac_f32_e32 v56, v21, v58                                 ; 2c707515
	v_cvt_f32_ubyte1_e32 v15, v38                               ; 7e1e2526
	v_cvt_f32_ubyte2_e32 v14, v38                               ; 7e1c2726
	v_mac_f32_e32 v60, v25, v62                                 ; 2c787d19
	v_cvt_f32_ubyte3_e32 v62, v38                               ; 7e7c2926
	v_cvt_f32_ubyte0_e32 v38, v38                               ; 7e4c2326
	v_mac_f32_e32 v56, v20, v39                                 ; 2c704f14
	v_mac_f32_e32 v60, v24, v59                                 ; 2c787718
	v_mul_f32_e32 v62, v31, v62                                 ; 0a7c7d1f
	v_mac_f32_e32 v62, v30, v14                                 ; 2c7c1d1e
	v_mac_f32_e32 v62, v29, v15                                 ; 2c7c1f1d
	v_mac_f32_e32 v62, v28, v38                                 ; 2c7c4d1c
	v_mul_f32_e32 v62, v62, v51                                 ; 0a7c673e
	v_mac_f32_e32 v62, v60, v37                                 ; 2c7c4b3c
	v_mac_f32_e32 v62, v56, v47                                 ; 2c7c5f38
	v_mac_f32_e32 v62, v53, v43                                 ; 2c7c5735
	v_mac_f32_e32 v11, v41, v62                                 ; 2c167d29
	s_cbranch_scc0 BB100                                        ; bf8400cc
BB83:
	s_add_u32 s0, s16, 6                                        ; 80008610
	s_mul_i32 s0, s0, s3                                        ; 92000300
	s_add_u32 s0, s19, s0                                       ; 80000013
	v_add_u32_e32 v14, s0, v0                                   ; 681c0000
	v_lshlrev_b32_e32 v15, 4, v14                               ; 241e1c84
	v_lshl_add_u32 v14, v14, 7, v15                             ; d1fd000e 043d0f0e
	v_add3_u32 v37, v36, 4, v14                                 ; d1ff0025 04390924
	v_add_u32_e32 v38, 16, v14                                  ; 684c1c90
	v_add_u32_e32 v39, v38, v4                                  ; 684e0926
	v_add_u32_e32 v38, v38, v40                                 ; 684c5126
	buffer_load_dwordx3 v[41:43], v14, s[12:15], 0 offen        ; e0581000 8003290e
	buffer_load_ushort v37, v37, s[12:15], 0 offen              ; e0481000 80032525
	buffer_load_dword v39, v39, s[12:15], 0 offen               ; e0501000 80032727
	buffer_load_dword v38, v38, s[12:15], 0 offen               ; e0501000 80032626
	s_bfm_b32 s1, 16, 16                                        ; 91019090
	s_mov_b32 s5, 0xf0f0f0f                                     ; be8500ff 0f0f0f0f
	s_cmp_lt_u32 7, s4                                          ; bf0a0487
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_bfe_u32 v42, v42, v5, 16                                  ; d1c8002a 02420b2a
	v_lshlrev_b32_e32 v43, v6, v43                              ; 24565706
	v_cvt_f32_f16_sdwa v48, v41 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e6016f9 00050629
	v_cvt_f32_f16_e32 v41, v41                                  ; 7e521729
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_lshl_or_b32 v37, v37, 12, v37                             ; d2000025 04951925
	v_and_or_b32 v43, s1, v43, v42                              ; d201002b 04aa5601
	v_and_b32_e32 v44, 0xc0c0c0c0, v43                          ; 265856ff c0c0c0c0
	v_and_b32_e32 v43, 0x3f3f3f3f, v43                          ; 265656ff 3f3f3f3f
	v_lshrrev_b32_e32 v44, 2, v44                               ; 20585882
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v52, s5, v39                                  ; 26684e05
	v_cvt_f32_ubyte3_e32 v45, v43                               ; 7e5a292b
	v_cvt_f32_ubyte2_e32 v46, v43                               ; 7e5c272b
	v_cvt_f32_ubyte1_e32 v47, v43                               ; 7e5e252b
	v_cvt_f32_ubyte0_e32 v43, v43                               ; 7e56232b
	v_and_or_b32 v37, s5, v37, v44                              ; d2010025 04b24a05
	v_cvt_f32_ubyte3_e32 v53, v52                               ; 7e6a2934
	v_cvt_f32_ubyte2_e32 v54, v52                               ; 7e6c2734
	v_cvt_f32_ubyte1_e32 v55, v52                               ; 7e6e2534
	v_cvt_f32_ubyte0_e32 v52, v52                               ; 7e682334
	v_cvt_f32_ubyte2_e32 v50, v37                               ; 7e642725
	v_cvt_f32_ubyte1_e32 v51, v37                               ; 7e662525
	v_cvt_f32_ubyte3_e32 v49, v37                               ; 7e622925
	v_cvt_f32_ubyte0_e32 v37, v37                               ; 7e4a2325
	v_mul_f32_e32 v53, v19, v53                                 ; 0a6a6b13
	v_lshrrev_b32_e32 v39, 4, v39                               ; 204e4e84
	v_mul_f32_e32 v49, v35, v49                                 ; 0a626323
	v_mac_f32_e32 v53, v18, v54                                 ; 2c6a6d12
	v_and_b32_e32 v39, s5, v39                                  ; 264e4e05
	v_mac_f32_e32 v49, v34, v50                                 ; 2c626522
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v59, s5, v38                                  ; 26764c05
	v_mac_f32_e32 v53, v17, v55                                 ; 2c6a6f11
	v_cvt_f32_ubyte1_e32 v58, v39                               ; 7e742527
	v_cvt_f32_ubyte2_e32 v57, v39                               ; 7e722727
	v_cvt_f32_ubyte3_e32 v56, v39                               ; 7e702927
	v_cvt_f32_ubyte0_e32 v39, v39                               ; 7e4e2327
	v_mac_f32_e32 v49, v33, v45                                 ; 2c625b21
	v_cvt_f32_ubyte2_e32 v61, v59                               ; 7e7a273b
	v_cvt_f32_ubyte3_e32 v60, v59                               ; 7e78293b
	v_cvt_f32_ubyte1_e32 v62, v59                               ; 7e7c253b
	v_mac_f32_e32 v53, v16, v52                                 ; 2c6a6910
	v_cvt_f32_ubyte0_e32 v59, v59                               ; 7e76233b
	v_mul_f32_e32 v56, v23, v56                                 ; 0a707117
	v_lshrrev_b32_e32 v38, 4, v38                               ; 204c4c84
	v_mac_f32_e32 v49, v32, v46                                 ; 2c625d20
	v_mul_f32_e32 v60, v27, v60                                 ; 0a78791b
	v_mac_f32_e32 v56, v22, v57                                 ; 2c707316
	v_and_b32_e32 v38, s5, v38                                  ; 264c4c05
	v_mad_f32 v12, -v48, v49, v12                               ; d1c1000c 24326330
	v_mac_f32_e32 v60, v26, v61                                 ; 2c787b1a
	v_mac_f32_e32 v56, v21, v58                                 ; 2c707515
	v_cvt_f32_ubyte1_e32 v15, v38                               ; 7e1e2526
	v_cvt_f32_ubyte2_e32 v14, v38                               ; 7e1c2726
	v_mac_f32_e32 v60, v25, v62                                 ; 2c787d19
	v_cvt_f32_ubyte3_e32 v62, v38                               ; 7e7c2926
	v_cvt_f32_ubyte0_e32 v38, v38                               ; 7e4c2326
	v_mac_f32_e32 v56, v20, v39                                 ; 2c704f14
	v_mac_f32_e32 v60, v24, v59                                 ; 2c787718
	v_mul_f32_e32 v62, v31, v62                                 ; 0a7c7d1f
	v_mac_f32_e32 v62, v30, v14                                 ; 2c7c1d1e
	v_mac_f32_e32 v62, v29, v15                                 ; 2c7c1f1d
	v_mac_f32_e32 v62, v28, v38                                 ; 2c7c4d1c
	v_mul_f32_e32 v62, v62, v51                                 ; 0a7c673e
	v_mac_f32_e32 v62, v60, v37                                 ; 2c7c4b3c
	v_mac_f32_e32 v62, v56, v47                                 ; 2c7c5f38
	v_mac_f32_e32 v62, v53, v43                                 ; 2c7c5735
	v_mac_f32_e32 v12, v41, v62                                 ; 2c187d29
	s_cbranch_scc0 BB100                                        ; bf840065
BB84:
	s_add_u32 s0, s16, 7                                        ; 80008710
	s_mul_i32 s0, s0, s3                                        ; 92000300
	s_add_u32 s0, s19, s0                                       ; 80000013
	v_add_u32_e32 v14, s0, v0                                   ; 681c0000
	v_lshlrev_b32_e32 v15, 4, v14                               ; 241e1c84
	v_lshl_add_u32 v14, v14, 7, v15                             ; d1fd000e 043d0f0e
	v_add3_u32 v36, v36, 4, v14                                 ; d1ff0024 04390924
	v_add_u32_e32 v37, 16, v14                                  ; 684a1c90
	v_add_u32_e32 v38, v37, v4                                  ; 684c0925
	v_add_u32_e32 v37, v37, v40                                 ; 684a5125
	buffer_load_dwordx3 v[39:41], v14, s[12:15], 0 offen        ; e0581000 8003270e
	buffer_load_ushort v36, v36, s[12:15], 0 offen              ; e0481000 80032424
	buffer_load_dword v38, v38, s[12:15], 0 offen               ; e0501000 80032626
	buffer_load_dword v37, v37, s[12:15], 0 offen               ; e0501000 80032525
	s_bfm_b32 s1, 16, 16                                        ; 91019090
	s_mov_b32 s5, 0xf0f0f0f                                     ; be8500ff 0f0f0f0f
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_bfe_u32 v40, v40, v5, 16                                  ; d1c80028 02420b28
	v_lshlrev_b32_e32 v41, v6, v41                              ; 24525306
	v_cvt_f32_f16_sdwa v46, v39 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e5c16f9 00050627
	v_cvt_f32_f16_e32 v39, v39                                  ; 7e4e1727
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_lshl_or_b32 v36, v36, 12, v36                             ; d2000024 04911924
	v_and_or_b32 v41, s1, v41, v40                              ; d2010029 04a25201
	v_and_b32_e32 v42, 0xc0c0c0c0, v41                          ; 265452ff c0c0c0c0
	v_and_b32_e32 v41, 0x3f3f3f3f, v41                          ; 265252ff 3f3f3f3f
	v_lshrrev_b32_e32 v42, 2, v42                               ; 20545482
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v50, s5, v38                                  ; 26644c05
	v_cvt_f32_ubyte3_e32 v43, v41                               ; 7e562929
	v_cvt_f32_ubyte2_e32 v44, v41                               ; 7e582729
	v_cvt_f32_ubyte1_e32 v45, v41                               ; 7e5a2529
	v_cvt_f32_ubyte0_e32 v41, v41                               ; 7e522329
	v_and_or_b32 v36, s5, v36, v42                              ; d2010024 04aa4805
	v_cvt_f32_ubyte3_e32 v51, v50                               ; 7e662932
	v_cvt_f32_ubyte2_e32 v52, v50                               ; 7e682732
	v_cvt_f32_ubyte1_e32 v53, v50                               ; 7e6a2532
	v_cvt_f32_ubyte0_e32 v50, v50                               ; 7e642332
	v_cvt_f32_ubyte2_e32 v48, v36                               ; 7e602724
	v_cvt_f32_ubyte1_e32 v49, v36                               ; 7e622524
	v_cvt_f32_ubyte3_e32 v47, v36                               ; 7e5e2924
	v_cvt_f32_ubyte0_e32 v36, v36                               ; 7e482324
	v_mul_f32_e32 v19, v19, v51                                 ; 0a266713
	v_lshrrev_b32_e32 v38, 4, v38                               ; 204c4c84
	v_mul_f32_e32 v35, v35, v47                                 ; 0a465f23
	v_mac_f32_e32 v19, v18, v52                                 ; 2c266912
	v_and_b32_e32 v38, s5, v38                                  ; 264c4c05
	v_mac_f32_e32 v35, v34, v48                                 ; 2c466122
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v57, s5, v37                                  ; 26724a05
	v_mac_f32_e32 v19, v17, v53                                 ; 2c266b11
	v_cvt_f32_ubyte1_e32 v56, v38                               ; 7e702526
	v_cvt_f32_ubyte2_e32 v55, v38                               ; 7e6e2726
	v_cvt_f32_ubyte3_e32 v54, v38                               ; 7e6c2926
	v_cvt_f32_ubyte0_e32 v38, v38                               ; 7e4c2326
	v_mac_f32_e32 v35, v33, v43                                 ; 2c465721
	v_cvt_f32_ubyte2_e32 v59, v57                               ; 7e762739
	v_cvt_f32_ubyte3_e32 v58, v57                               ; 7e742939
	v_cvt_f32_ubyte1_e32 v60, v57                               ; 7e782539
	v_mac_f32_e32 v19, v16, v50                                 ; 2c266510
	v_cvt_f32_ubyte0_e32 v57, v57                               ; 7e722339
	v_mul_f32_e32 v23, v23, v54                                 ; 0a2e6d17
	v_lshrrev_b32_e32 v37, 4, v37                               ; 204a4a84
	v_mac_f32_e32 v35, v32, v44                                 ; 2c465920
	v_mul_f32_e32 v27, v27, v58                                 ; 0a36751b
	v_mac_f32_e32 v23, v22, v55                                 ; 2c2e6f16
	v_and_b32_e32 v37, s5, v37                                  ; 264a4a05
	v_mad_f32 v13, -v46, v35, v13                               ; d1c1000d 2436472e
	v_mac_f32_e32 v27, v26, v59                                 ; 2c36771a
	v_mac_f32_e32 v23, v21, v56                                 ; 2c2e7115
	v_cvt_f32_ubyte2_e32 v62, v37                               ; 7e7c2725
	v_cvt_f32_ubyte3_e32 v61, v37                               ; 7e7a2925
	v_mac_f32_e32 v27, v25, v60                                 ; 2c367919
	v_mac_f32_e32 v23, v20, v38                                 ; 2c2e4d14
	v_mul_f32_e32 v31, v31, v61                                 ; 0a3e7b1f
	v_mac_f32_e32 v27, v24, v57                                 ; 2c367318
	v_mac_f32_e32 v31, v30, v62                                 ; 2c3e7d1e
	v_cvt_f32_ubyte1_e32 v62, v37                               ; 7e7c2525
	v_cvt_f32_ubyte0_e32 v37, v37                               ; 7e4a2325
	v_mac_f32_e32 v31, v29, v62                                 ; 2c3e7d1d
	v_mac_f32_e32 v31, v28, v37                                 ; 2c3e4b1c
	v_mul_f32_e32 v31, v31, v49                                 ; 0a3e631f
	v_mac_f32_e32 v31, v27, v36                                 ; 2c3e491b
	v_mac_f32_e32 v31, v23, v45                                 ; 2c3e5b17
	v_mac_f32_e32 v31, v19, v41                                 ; 2c3e5313
	v_mac_f32_e32 v13, v39, v31                                 ; 2c1a3f27
BB100:
	v_add_u32_e32 v0, 4, v0                                     ; 68000084
	s_branch BB71                                               ; bf82fc94
BB101:
	s_mov_b64 exec, -1                                          ; befe01c1
	s_cmp_lg_i32 s4, 0                                          ; bf018004
	s_cselect_b64 s[0:1], -1, 0                                 ; 858080c1
	s_cbranch_scc0 BB125                                        ; bf8400d6
BB102:
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
	s_cbranch_scc0 BB123                                        ; bf8400bb
BB103:
	s_or_saveexec_b64 s[10:11], -1                              ; be8a21c1
	s_cmp_lt_u32 2, s4                                          ; bf0a0482
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
	v_readlane_b32 s5, v63, 63                                  ; d2890005 00017f3f
	s_cbranch_scc0 BB121                                        ; bf8400a0
BB104:
	s_or_saveexec_b64 s[10:11], -1                              ; be8a21c1
	s_cmp_lt_u32 3, s4                                          ; bf0a0483
	v_cndmask_b32_e64 v63, 0, v8, s[10:11]                      ; d100003f 002a1080
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
	s_cbranch_scc0 BB119                                        ; bf840085
BB105:
	s_or_saveexec_b64 s[10:11], -1                              ; be8a21c1
	s_cmp_lt_u32 4, s4                                          ; bf0a0484
	v_cndmask_b32_e64 v63, 0, v9, s[10:11]                      ; d100003f 002a1280
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
	s_cbranch_scc0 BB117                                        ; bf84006a
BB106:
	s_or_saveexec_b64 s[12:13], -1                              ; be8c21c1
	s_cmp_lt_u32 5, s4                                          ; bf0a0485
	v_cndmask_b32_e64 v63, 0, v10, s[12:13]                     ; d100003f 00321480
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
	s_mov_b64 exec, s[12:13]                                    ; befe010c
	v_readlane_b32 s10, v63, 63                                 ; d289000a 00017f3f
	s_cbranch_scc0 BB115                                        ; bf84004f
BB107:
	s_or_saveexec_b64 s[12:13], -1                              ; be8c21c1
	s_cmp_lt_u32 6, s4                                          ; bf0a0486
	v_cndmask_b32_e64 v63, 0, v11, s[12:13]                     ; d100003f 00321680
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
	s_mov_b64 exec, s[12:13]                                    ; befe010c
	v_readlane_b32 s11, v63, 63                                 ; d289000b 00017f3f
	s_cbranch_scc0 BB113                                        ; bf840034
BB108:
	s_or_saveexec_b64 s[14:15], -1                              ; be8e21c1
	s_cmp_lt_u32 7, s4                                          ; bf0a0487
	v_cndmask_b32_e64 v63, 0, v12, s[14:15]                     ; d100003f 003a1880
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
	s_mov_b64 exec, s[14:15]                                    ; befe010e
	v_readlane_b32 s12, v63, 63                                 ; d289000c 00017f3f
	s_cbranch_scc0 BB111                                        ; bf840019
BB109:
	s_or_saveexec_b64 s[14:15], -1                              ; be8e21c1
	v_cndmask_b32_e64 v63, 0, v13, s[14:15]                     ; d100003f 003a1a80
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
	s_mov_b64 exec, s[14:15]                                    ; befe010e
	v_readlane_b32 s13, v63, 63                                 ; d289000d 00017f3f
	v_mov_b32_e32 v13, s13                                      ; 7e1a020d
BB111:
	v_mov_b32_e32 v12, s12                                      ; 7e18020c
BB113:
	v_mov_b32_e32 v11, s11                                      ; 7e16020b
BB115:
	v_mov_b32_e32 v10, s10                                      ; 7e14020a
BB117:
	v_mov_b32_e32 v9, s9                                        ; 7e120209
BB119:
	v_mov_b32_e32 v8, s6                                        ; 7e100206
BB121:
	v_mov_b32_e32 v7, s5                                        ; 7e0e0205
BB123:
	v_mov_b32_e32 v3, s3                                        ; 7e060203
BB125:
	s_mov_b64 s[10:11], 1                                       ; be8a0181
	s_and_b64 exec, s[0:1], s[10:11]                            ; 86fe0a00
	s_cbranch_execz BB203                                       ; bf8800ff
BB126:
	s_bitcmp1_b32 s8, 0                                         ; bf0d8008
	s_cbranch_scc0 BB128                                        ; bf84000e
BB127:
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
	s_branch BB129                                              ; bf820001
BB128:
	s_mov_b32 s1, src_scc                                       ; be8100fd
BB129:
	s_bitcmp1_b32 s8, 1                                         ; bf0d8108
	s_cbranch_scc0 BB131                                        ; bf84000e
BB130:
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
	s_branch BB132                                              ; bf820001
BB131:
	s_mov_b32 s3, src_scc                                       ; be8300fd
BB132:
	s_mov_b32 s0, s3                                            ; be800003
	s_movk_i32 s3, 0x8000                                       ; b0038000
	s_load_dwordx4 s[8:11], s[2:3], 0x20                        ; c00a0201 00000020
	s_mul_i32 s7, s7, s17                                       ; 92071107
	s_add_u32 s7, s7, s16                                       ; 80071007
	s_lshl_b32 s7, s7, 2                                        ; 8e078207
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_store_dword v3, off, s[8:11], s7                     ; e0700000 07020380
	s_cmp_lt_u32 1, s4                                          ; bf0a0481
	s_cbranch_scc0 BB203                                        ; bf8400d1
BB133:
	s_cmp_lg_i32 s1, 0                                          ; bf018001
	s_cbranch_scc0 BB135                                        ; bf84000a
BB134:
	s_load_dwordx4 s[12:15], s[2:3], 0x30                       ; c00a0301 00000030
	s_mov_b32 s1, src_scc                                       ; be8100fd
	s_add_u32 s5, s7, 4                                         ; 80058407
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s5, s[12:15], s5                        ; c0200146 00000005
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v7, s5, v7                                    ; 020e0e05
	s_branch BB136                                              ; bf820001
BB135:
	s_mov_b32 s1, src_scc                                       ; be8100fd
BB136:
	s_cmp_lg_i32 s0, 0                                          ; bf018000
	s_cbranch_scc0 BB138                                        ; bf84000a
BB137:
	s_load_dwordx4 s[12:15], s[2:3], 0x40                       ; c00a0301 00000040
	s_mov_b32 s0, src_scc                                       ; be8000fd
	s_add_u32 s5, s7, 4                                         ; 80058407
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s5, s[12:15], s5                        ; c0200146 00000005
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v7, s5, v7                                    ; 020e0e05
	s_branch BB139                                              ; bf820001
BB138:
	s_mov_b32 s0, src_scc                                       ; be8000fd
BB139:
	s_add_u32 s5, s7, 4                                         ; 80058407
	buffer_store_dword v7, off, s[8:11], s5                     ; e0700000 05020780
	s_cmp_lt_u32 2, s4                                          ; bf0a0482
	s_cbranch_scc0 BB203                                        ; bf8400b2
BB140:
	s_cmp_lg_i32 s1, 0                                          ; bf018001
	s_cbranch_scc0 BB142                                        ; bf84000a
BB141:
	s_load_dwordx4 s[12:15], s[2:3], 0x30                       ; c00a0301 00000030
	s_mov_b32 s1, src_scc                                       ; be8100fd
	s_add_u32 s5, s7, 8                                         ; 80058807
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s5, s[12:15], s5                        ; c0200146 00000005
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v8, s5, v8                                    ; 02101005
	s_branch BB143                                              ; bf820001
BB142:
	s_mov_b32 s1, src_scc                                       ; be8100fd
BB143:
	s_cmp_lg_i32 s0, 0                                          ; bf018000
	s_cbranch_scc0 BB145                                        ; bf84000a
BB144:
	s_load_dwordx4 s[12:15], s[2:3], 0x40                       ; c00a0301 00000040
	s_mov_b32 s0, src_scc                                       ; be8000fd
	s_add_u32 s5, s7, 8                                         ; 80058807
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s5, s[12:15], s5                        ; c0200146 00000005
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v8, s5, v8                                    ; 02101005
	s_branch BB146                                              ; bf820001
BB145:
	s_mov_b32 s0, src_scc                                       ; be8000fd
BB146:
	s_add_u32 s5, s7, 8                                         ; 80058807
	buffer_store_dword v8, off, s[8:11], s5                     ; e0700000 05020880
	s_cmp_lt_u32 3, s4                                          ; bf0a0483
	s_cbranch_scc0 BB203                                        ; bf840093
BB147:
	s_cmp_lg_i32 s1, 0                                          ; bf018001
	s_cbranch_scc0 BB149                                        ; bf84000a
BB148:
	s_load_dwordx4 s[12:15], s[2:3], 0x30                       ; c00a0301 00000030
	s_mov_b32 s1, src_scc                                       ; be8100fd
	s_add_u32 s5, s7, 12                                        ; 80058c07
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s5, s[12:15], s5                        ; c0200146 00000005
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v9, s5, v9                                    ; 02121205
	s_branch BB150                                              ; bf820001
BB149:
	s_mov_b32 s1, src_scc                                       ; be8100fd
BB150:
	s_cmp_lg_i32 s0, 0                                          ; bf018000
	s_cbranch_scc0 BB152                                        ; bf84000a
BB151:
	s_load_dwordx4 s[12:15], s[2:3], 0x40                       ; c00a0301 00000040
	s_mov_b32 s0, src_scc                                       ; be8000fd
	s_add_u32 s5, s7, 12                                        ; 80058c07
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s5, s[12:15], s5                        ; c0200146 00000005
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v9, s5, v9                                    ; 02121205
	s_branch BB153                                              ; bf820001
BB152:
	s_mov_b32 s0, src_scc                                       ; be8000fd
BB153:
	s_add_u32 s5, s7, 12                                        ; 80058c07
	buffer_store_dword v9, off, s[8:11], s5                     ; e0700000 05020980
	s_cmp_lt_u32 4, s4                                          ; bf0a0484
	s_cbranch_scc0 BB203                                        ; bf840074
BB154:
	s_cmp_lg_i32 s1, 0                                          ; bf018001
	s_cbranch_scc0 BB156                                        ; bf84000a
BB155:
	s_load_dwordx4 s[12:15], s[2:3], 0x30                       ; c00a0301 00000030
	s_mov_b32 s1, src_scc                                       ; be8100fd
	s_add_u32 s5, s7, 16                                        ; 80059007
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s5, s[12:15], s5                        ; c0200146 00000005
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v10, s5, v10                                  ; 02141405
	s_branch BB157                                              ; bf820001
BB156:
	s_mov_b32 s1, src_scc                                       ; be8100fd
BB157:
	s_cmp_lg_i32 s0, 0                                          ; bf018000
	s_cbranch_scc0 BB159                                        ; bf84000a
BB158:
	s_load_dwordx4 s[12:15], s[2:3], 0x40                       ; c00a0301 00000040
	s_mov_b32 s0, src_scc                                       ; be8000fd
	s_add_u32 s5, s7, 16                                        ; 80059007
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s5, s[12:15], s5                        ; c0200146 00000005
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v10, s5, v10                                  ; 02141405
	s_branch BB160                                              ; bf820001
BB159:
	s_mov_b32 s0, src_scc                                       ; be8000fd
BB160:
	s_add_u32 s5, s7, 16                                        ; 80059007
	buffer_store_dword v10, off, s[8:11], s5                    ; e0700000 05020a80
	s_cmp_lt_u32 5, s4                                          ; bf0a0485
	s_cbranch_scc0 BB203                                        ; bf840055
BB161:
	s_cmp_lg_i32 s1, 0                                          ; bf018001
	s_cbranch_scc0 BB163                                        ; bf84000a
BB162:
	s_load_dwordx4 s[12:15], s[2:3], 0x30                       ; c00a0301 00000030
	s_mov_b32 s1, src_scc                                       ; be8100fd
	s_add_u32 s5, s7, 20                                        ; 80059407
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s5, s[12:15], s5                        ; c0200146 00000005
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v11, s5, v11                                  ; 02161605
	s_branch BB164                                              ; bf820001
BB163:
	s_mov_b32 s1, src_scc                                       ; be8100fd
BB164:
	s_cmp_lg_i32 s0, 0                                          ; bf018000
	s_cbranch_scc0 BB166                                        ; bf84000a
BB165:
	s_load_dwordx4 s[12:15], s[2:3], 0x40                       ; c00a0301 00000040
	s_mov_b32 s0, src_scc                                       ; be8000fd
	s_add_u32 s5, s7, 20                                        ; 80059407
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s5, s[12:15], s5                        ; c0200146 00000005
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v11, s5, v11                                  ; 02161605
	s_branch BB167                                              ; bf820001
BB166:
	s_mov_b32 s0, src_scc                                       ; be8000fd
BB167:
	s_add_u32 s5, s7, 20                                        ; 80059407
	buffer_store_dword v11, off, s[8:11], s5                    ; e0700000 05020b80
	s_cmp_lt_u32 6, s4                                          ; bf0a0486
	s_cbranch_scc0 BB203                                        ; bf840036
BB168:
	s_cmp_lg_i32 s1, 0                                          ; bf018001
	s_cbranch_scc0 BB170                                        ; bf84000a
BB169:
	s_load_dwordx4 s[12:15], s[2:3], 0x30                       ; c00a0301 00000030
	s_mov_b32 s1, src_scc                                       ; be8100fd
	s_add_u32 s5, s7, 24                                        ; 80059807
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s5, s[12:15], s5                        ; c0200146 00000005
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v12, s5, v12                                  ; 02181805
	s_branch BB171                                              ; bf820001
BB170:
	s_mov_b32 s1, src_scc                                       ; be8100fd
BB171:
	s_cmp_lg_i32 s0, 0                                          ; bf018000
	s_cbranch_scc0 BB173                                        ; bf84000a
BB172:
	s_load_dwordx4 s[12:15], s[2:3], 0x40                       ; c00a0301 00000040
	s_mov_b32 s0, src_scc                                       ; be8000fd
	s_add_u32 s5, s7, 24                                        ; 80059807
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s5, s[12:15], s5                        ; c0200146 00000005
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v12, s5, v12                                  ; 02181805
	s_branch BB174                                              ; bf820001
BB173:
	s_mov_b32 s0, src_scc                                       ; be8000fd
BB174:
	s_add_u32 s5, s7, 24                                        ; 80059807
	buffer_store_dword v12, off, s[8:11], s5                    ; e0700000 05020c80
	s_cmp_lt_u32 7, s4                                          ; bf0a0487
	s_cbranch_scc0 BB203                                        ; bf840017
BB175:
	s_cmp_lg_i32 s1, 0                                          ; bf018001
	s_cbranch_scc0 BB178                                        ; bf840008
BB176:
	s_load_dwordx4 s[12:15], s[2:3], 0x30                       ; c00a0301 00000030
	s_add_u32 s1, s7, 28                                        ; 80019c07
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s1, s[12:15], s1                        ; c0200046 00000001
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v13, s1, v13                                  ; 021a1a01
BB178:
	s_cmp_lg_i32 s0, 0                                          ; bf018000
	s_cbranch_scc0 BB181                                        ; bf840008
BB179:
	s_load_dwordx4 s[0:3], s[2:3], 0x40                         ; c00a0001 00000040
	s_add_u32 s4, s7, 28                                        ; 80049c07
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s4, s[0:3], s4                          ; c0200100 00000004
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v13, s4, v13                                  ; 021a1a04
BB181:
	s_add_u32 s7, s7, 28                                        ; 80079c07
	buffer_store_dword v13, off, s[8:11], s7                    ; e0700000 07020d80
BB203:
	s_endpgm                                                    ; bf810000
