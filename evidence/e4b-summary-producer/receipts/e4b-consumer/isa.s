BB0:
	s_load_dword s0, s[14:15], 0x0                              ; c0020007 00000000
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_mul_i32 s0, s0, s18                                       ; 92001200
	s_add_u32 s16, s16, s0                                      ; 80100010
	s_lshl_b32 s16, s16, 2                                      ; 8e108210
	s_add_u32 s1, s16, 4                                        ; 80018410
	s_cmp_ge_u32 s4, s1                                         ; bf090104
	s_cbranch_scc0 BB42                                         ; bf840314
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
	s_branch BB5                                                ; bf8201cb
BB10:
	s_mov_b64 exec, s[0:1]                                      ; befe0100
	s_mov_b32 s0, s2                                            ; be800002
	s_movk_i32 s1, 0x8000                                       ; b0018000
	s_load_dwordx4 s[12:15], s[0:1], 0x50                       ; c00a0300 00000050
	s_load_dwordx8 s[24:31], s[0:1], 0x0                        ; c00e0600 00000000
	s_mul_i32 s0, s6, s17                                       ; 92001106
	v_bfe_u32 v9, v1, 2, 4                                      ; d1c80009 02110501
	v_lshrrev_b32_e32 v10, 6, v1                                ; 20140286
	s_lshr_b32 s1, s0, 4                                        ; 8f018400
	v_lshl_add_u32 v10, v10, 3, v9                              ; d1fd000a 0425070a
	v_lshl_add_u32 v8, v0, 4, s1                                ; d1fd0008 00050900
	v_add_lshl_u32 v8, v8, v10, 4                               ; d1fe0008 02121508
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_load_dwordx4 v[8:11], v8, s[12:15], 0 offen          ; e05c1000 80030808
	s_mul_i32 s4, s16, s3                                       ; 92040310
	v_lshlrev_b32_e32 v14, 1, v2                                ; 241c0481
	v_add_u32_e32 v22, 64, v4                                   ; 682c08c0
	s_add_u32 s4, s18, s4                                       ; 80040412
	v_and_b32_e32 v16, -4, v14                                  ; 26201cc4
	v_add_u32_e32 v19, 8, v14                                   ; 68261c88
	v_add_u32_e32 v12, s4, v0                                   ; 68180004
	v_lshlrev_b32_e32 v13, 4, v12                               ; 241a1884
	v_lshl_add_u32 v12, v12, 7, v13                             ; d1fd000c 04350f0c
	v_add_u32_e32 v15, 4, v12                                   ; 681e1884
	v_add_u32_e32 v20, 16, v12                                  ; 68281890
	v_add_u32_e32 v17, v16, v15                                 ; 68221f10
	v_add_u32_e32 v18, v15, v14                                 ; 68241d0f
	v_add_u32_e32 v15, v15, v19                                 ; 681e270f
	v_add_u32_e32 v21, v20, v4                                  ; 682a0914
	v_add_u32_e32 v20, v20, v22                                 ; 68282d14
	buffer_load_dword v12, v12, s[24:27], 0 offen               ; e0501000 80060c0c
	buffer_load_dwordx2 v[24:25], v17, s[24:27], 0 offen        ; e0541000 80061811
	buffer_load_ushort v15, v15, s[24:27], 0 offen              ; e0481000 80060f0f
	buffer_load_dword v21, v21, s[24:27], 0 offen               ; e0501000 80061515
	buffer_load_dword v20, v20, s[24:27], 0 offen               ; e0501000 80061414
	v_lshl_add_u32 v23, v0, 8, v1                               ; d1fd0017 04051100
	v_add_u32_e32 v26, s0, v23                                  ; 68342e00
	v_add_u32_e32 v23, 0x80, v23                                ; 682e2eff 00000080
	v_lshrrev_b32_e32 v26, 2, v26                               ; 20343482
	v_add_u32_e32 v23, s0, v23                                  ; 682e2e00
	v_lshlrev_b32_e32 v26, 4, v26                               ; 24343484
	v_lshrrev_b32_e32 v23, 2, v23                               ; 202e2e82
	v_lshlrev_b32_e32 v23, 4, v23                               ; 242e2e84
	buffer_load_dwordx4 v[28:31], v26, s[28:31], 0 offen        ; e05c1000 80071c1a
	buffer_load_dwordx4 v[32:35], v26, s[28:31], 0 offen offset:128 ; e05c1080 8007201a
	buffer_load_dwordx4 v[36:39], v23, s[28:31], 0 offen        ; e05c1000 80072417
	buffer_load_dwordx4 v[40:43], v23, s[28:31], 0 offen offset:128 ; e05c1080 80072817
	s_add_u32 s5, s16, 1                                        ; 80058110
	s_mul_i32 s5, s5, s3                                        ; 92050305
	s_add_u32 s5, s18, s5                                       ; 80050512
	s_add_u32 s9, s16, 2                                        ; 80098210
	v_add_u32_e32 v27, s5, v0                                   ; 68360005
	s_mul_i32 s9, s9, s3                                        ; 92090309
	v_lshlrev_b32_e32 v44, 4, v27                               ; 24583684
	s_add_u32 s9, s18, s9                                       ; 80090912
	v_lshl_add_u32 v27, v27, 7, v44                             ; d1fd001b 04b10f1b
	v_add_u32_e32 v50, s9, v0                                   ; 68640009
	v_add_u32_e32 v45, 4, v27                                   ; 685a3684
	v_add_u32_e32 v48, 16, v27                                  ; 68603690
	s_add_u32 s10, s16, 3                                       ; 800a8310
	v_lshlrev_b32_e32 v51, 4, v50                               ; 24666484
	v_add_u32_e32 v46, v16, v45                                 ; 685c5b10
	v_add_u32_e32 v47, v45, v14                                 ; 685e1d2d
	v_add_u32_e32 v45, v45, v19                                 ; 685a272d
	v_add_u32_e32 v49, v48, v4                                  ; 68620930
	v_add_u32_e32 v48, v48, v22                                 ; 68602d30
	s_mul_i32 s10, s10, s3                                      ; 920a030a
	v_lshl_add_u32 v50, v50, 7, v51                             ; d1fd0032 04cd0f32
	s_add_u32 s10, s18, s10                                     ; 800a0a12
	v_add_u32_e32 v52, 4, v50                                   ; 68686484
	v_add_u32_e32 v55, 16, v50                                  ; 686e6490
	v_add_u32_e32 v57, s10, v0                                  ; 6872000a
	v_add_u32_e32 v53, v16, v52                                 ; 686a6910
	v_add_u32_e32 v54, v52, v14                                 ; 686c1d34
	v_add_u32_e32 v52, v52, v19                                 ; 68682734
	v_add_u32_e32 v56, v55, v4                                  ; 68700937
	v_add_u32_e32 v55, v55, v22                                 ; 686e2d37
	v_lshlrev_b32_e32 v58, 4, v57                               ; 24747284
	v_lshl_add_u32 v57, v57, 7, v58                             ; d1fd0039 04e90f39
	v_add_u32_e32 v59, 4, v57                                   ; 68767284
	v_add_u32_e32 v60, 16, v57                                  ; 68787290
	v_add_u32_e32 v14, v59, v14                                 ; 681c1d3b
	v_add_u32_e32 v16, v16, v59                                 ; 68207710
	v_add_u32_e32 v59, v59, v19                                 ; 6876273b
	v_add_u32_e32 v61, v60, v4                                  ; 687a093c
	v_add_u32_e32 v60, v60, v22                                 ; 68782d3c
	s_waitcnt vmcnt(8)                                          ; bf8c3f78
	v_mov_b32_e32 v62, v12                                      ; 7e7c030c
	buffer_load_dword v27, v27, s[24:27], 0 offen               ; e0501000 80061b1b
	buffer_load_dwordx2 v[22:23], v46, s[24:27], 0 offen        ; e0541000 8006162e
	buffer_load_ushort v45, v45, s[24:27], 0 offen              ; e0481000 80062d2d
	buffer_load_dword v49, v49, s[24:27], 0 offen               ; e0501000 80063131
	buffer_load_dword v48, v48, s[24:27], 0 offen               ; e0501000 80063030
	buffer_load_dword v50, v50, s[24:27], 0 offen               ; e0501000 80063232
	buffer_load_dwordx2 v[12:13], v53, s[24:27], 0 offen        ; e0541000 80060c35
	buffer_load_ushort v52, v52, s[24:27], 0 offen              ; e0481000 80063434
	buffer_load_dword v56, v56, s[24:27], 0 offen               ; e0501000 80063838
	buffer_load_dword v55, v55, s[24:27], 0 offen               ; e0501000 80063737
	buffer_load_dword v57, v57, s[24:27], 0 offen               ; e0501000 80063939
	buffer_load_dwordx2 v[16:17], v16, s[24:27], 0 offen        ; e0541000 80061010
	buffer_load_ushort v59, v59, s[24:27], 0 offen              ; e0481000 80063b3b
	buffer_load_dword v61, v61, s[24:27], 0 offen               ; e0501000 80063d3d
	buffer_load_dword v60, v60, s[24:27], 0 offen               ; e0501000 80063c3c
	s_mov_b32 s11, 0xf0f0f0f                                    ; be8b00ff 0f0f0f0f
	s_mov_b32 s12, 0xc0c0c0c0                                   ; be8c00ff c0c0c0c0
	s_mov_b32 s13, 0x3f3f3f3f                                   ; be8d00ff 3f3f3f3f
	v_add_u32_e32 v0, 4, v0                                     ; 68000084
	v_cvt_f32_f16_sdwa v19, v62 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e2616f9 0005063e
	v_cvt_f32_f16_e32 v62, v62                                  ; 7e7c173e
	s_waitcnt vmcnt(22)                                         ; bf8c7f76
	v_alignbyte_b32 v24, v25, v24, v18                          ; d1cf0018 044a3119
	v_alignbyte_b32 v25, v25, v25, v18                          ; d1cf0019 044a3319
	s_waitcnt vmcnt(21)                                         ; bf8c7f75
	v_lshl_or_b32 v15, v15, 12, v15                             ; d200000f 043d190f
	s_waitcnt vmcnt(20)                                         ; bf8c7f74
	v_and_b32_e32 v46, s11, v21                                 ; 265c2a0b
	v_lshrrev_b32_e32 v21, 4, v21                               ; 202a2a84
	v_mov_b32_sdwa v24, v25 dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_0 ; 7e3002f9 00041519
	v_cvt_f32_ubyte1_e32 v58, v46                               ; 7e74252e
	v_cvt_f32_ubyte2_e32 v53, v46                               ; 7e6a272e
	v_cvt_f32_ubyte3_e32 v51, v46                               ; 7e66292e
	v_cvt_f32_ubyte0_e32 v46, v46                               ; 7e5c232e
	v_and_b32_e32 v21, s11, v21                                 ; 262a2a0b
	v_and_b32_e32 v25, s12, v24                                 ; 2632300c
	v_and_b32_e32 v24, s13, v24                                 ; 2630300d
	s_waitcnt vmcnt(18)                                         ; bf8c7f72
	v_mul_f32_e32 v51, v31, v51                                 ; 0a66671f
	v_cvt_f32_ubyte3_e32 v18, v21                               ; 7e242915
	v_lshrrev_b32_e32 v25, 2, v25                               ; 20323282
	v_cvt_f32_ubyte2_e32 v44, v24                               ; 7e582718
	v_cvt_f32_ubyte3_e32 v26, v24                               ; 7e342918
	v_mac_f32_e32 v51, v30, v53                                 ; 2c666b1e
	v_and_b32_e32 v53, s11, v20                                 ; 266a280b
	s_waitcnt vmcnt(17)                                         ; bf8c7f71
	v_mul_f32_e32 v18, v35, v18                                 ; 0a242523
	v_and_or_b32 v15, s11, v15, v25                             ; d201000f 04661e0b
	v_cvt_f32_ubyte2_e32 v25, v21                               ; 7e322715
	v_mac_f32_e32 v51, v29, v58                                 ; 2c66751d
	v_cvt_f32_ubyte3_e32 v58, v53                               ; 7e742935
	v_lshrrev_b32_e32 v20, 4, v20                               ; 20282884
	v_mac_f32_e32 v18, v34, v25                                 ; 2c243322
	v_cvt_f32_ubyte1_e32 v25, v53                               ; 7e322535
	v_mac_f32_e32 v51, v28, v46                                 ; 2c665d1c
	v_cvt_f32_ubyte1_e32 v46, v21                               ; 7e5c2515
	v_cvt_f32_ubyte0_e32 v21, v21                               ; 7e2a2315
	s_waitcnt vmcnt(16)                                         ; bf8c7f70
	v_mul_f32_e32 v58, v39, v58                                 ; 0a747527
	v_and_b32_e32 v20, s11, v20                                 ; 2628280b
	v_mac_f32_e32 v18, v33, v46                                 ; 2c245d21
	v_cvt_f32_ubyte3_e32 v46, v20                               ; 7e5c2914
	v_mac_f32_e32 v18, v32, v21                                 ; 2c242b20
	v_cvt_f32_ubyte2_e32 v21, v53                               ; 7e2a2735
	v_cvt_f32_ubyte0_e32 v53, v53                               ; 7e6a2335
	s_waitcnt vmcnt(15)                                         ; bf8c3f7f
	v_mul_f32_e32 v46, v43, v46                                 ; 0a5c5d2b
	v_mac_f32_e32 v58, v38, v21                                 ; 2c742b26
	v_cvt_f32_ubyte1_e32 v21, v20                               ; 7e2a2514
	v_mac_f32_e32 v58, v37, v25                                 ; 2c743325
	v_cvt_f32_ubyte3_e32 v25, v15                               ; 7e32290f
	v_mac_f32_e32 v58, v36, v53                                 ; 2c746b24
	v_cvt_f32_ubyte2_e32 v53, v20                               ; 7e6a2714
	v_cvt_f32_ubyte0_e32 v20, v20                               ; 7e282314
	v_mul_f32_e32 v25, v11, v25                                 ; 0a32330b
	v_mac_f32_e32 v46, v42, v53                                 ; 2c5c6b2a
	v_cvt_f32_ubyte2_e32 v53, v15                               ; 7e6a270f
	v_mac_f32_e32 v46, v41, v21                                 ; 2c5c2b29
	v_cvt_f32_ubyte1_e32 v21, v24                               ; 7e2a2518
	v_cvt_f32_ubyte0_e32 v24, v24                               ; 7e302318
	v_mac_f32_e32 v25, v10, v53                                 ; 2c326b0a
	v_mac_f32_e32 v46, v40, v20                                 ; 2c5c2928
	v_cvt_f32_ubyte1_e32 v20, v15                               ; 7e28250f
	v_cvt_f32_ubyte0_e32 v15, v15                               ; 7e1e230f
	v_mac_f32_e32 v25, v9, v26                                  ; 2c323509
	v_mul_f32_e32 v46, v46, v20                                 ; 0a5c292e
	v_mac_f32_e32 v25, v8, v44                                  ; 2c325908
	v_mac_f32_e32 v46, v58, v15                                 ; 2c5c1f3a
	v_mad_f32 v3, -v19, v25, v3                                 ; d1c10003 240e3313
	s_waitcnt vmcnt(13)                                         ; bf8c3f7d
	v_alignbyte_b32 v22, v23, v22, v47                          ; d1cf0016 04be2d17
	v_alignbyte_b32 v23, v23, v23, v47                          ; d1cf0017 04be2f17
	v_mac_f32_e32 v46, v18, v21                                 ; 2c5c2b12
	s_waitcnt vmcnt(12)                                         ; bf8c3f7c
	v_lshl_or_b32 v45, v45, 12, v45                             ; d200002d 04b5192d
	v_mov_b32_sdwa v22, v23 dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_0 ; 7e2c02f9 00041517
	v_mac_f32_e32 v46, v51, v24                                 ; 2c5c3133
	v_cvt_f32_f16_sdwa v24, v27 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e3016f9 0005061b
	v_cvt_f32_f16_e32 v27, v27                                  ; 7e36171b
	v_and_b32_e32 v25, s12, v22                                 ; 26322c0c
	v_and_b32_e32 v22, s13, v22                                 ; 262c2c0d
	v_mac_f32_e32 v3, v62, v46                                  ; 2c065d3e
	v_lshrrev_b32_e32 v25, 2, v25                               ; 20323282
	s_waitcnt vmcnt(11)                                         ; bf8c3f7b
	v_and_b32_e32 v58, s11, v49                                 ; 2674620b
	v_cvt_f32_ubyte2_e32 v44, v22                               ; 7e582716
	v_cvt_f32_ubyte1_e32 v46, v22                               ; 7e5c2516
	v_cvt_f32_ubyte3_e32 v26, v22                               ; 7e342916
	v_cvt_f32_ubyte0_e32 v22, v22                               ; 7e2c2316
	v_and_or_b32 v45, s11, v45, v25                             ; d201002d 04665a0b
	v_cvt_f32_ubyte2_e32 v15, v58                               ; 7e1e273a
	v_cvt_f32_ubyte3_e32 v62, v58                               ; 7e7c293a
	v_cvt_f32_ubyte1_e32 v18, v58                               ; 7e24253a
	v_cvt_f32_ubyte0_e32 v58, v58                               ; 7e74233a
	v_cvt_f32_ubyte2_e32 v51, v45                               ; 7e66272d
	v_cvt_f32_ubyte3_e32 v47, v45                               ; 7e5e292d
	v_cvt_f32_ubyte1_e32 v53, v45                               ; 7e6a252d
	v_cvt_f32_ubyte0_e32 v45, v45                               ; 7e5a232d
	v_lshrrev_b32_e32 v49, 4, v49                               ; 20626284
	v_mul_f32_e32 v62, v31, v62                                 ; 0a7c7d1f
	v_mul_f32_e32 v47, v11, v47                                 ; 0a5e5f0b
	v_and_b32_e32 v49, s11, v49                                 ; 2662620b
	v_mac_f32_e32 v62, v30, v15                                 ; 2c7c1f1e
	v_mac_f32_e32 v47, v10, v51                                 ; 2c5e670a
	s_waitcnt vmcnt(10)                                         ; bf8c3f7a
	v_and_b32_e32 v23, s11, v48                                 ; 262e600b
	v_cvt_f32_ubyte3_e32 v19, v49                               ; 7e262931
	v_cvt_f32_ubyte2_e32 v20, v49                               ; 7e282731
	v_cvt_f32_ubyte1_e32 v21, v49                               ; 7e2a2531
	v_cvt_f32_ubyte0_e32 v49, v49                               ; 7e622331
	v_mac_f32_e32 v62, v29, v18                                 ; 2c7c251d
	v_mac_f32_e32 v47, v9, v26                                  ; 2c5e3509
	v_cvt_f32_ubyte2_e32 v25, v23                               ; 7e322717
	v_mul_f32_e32 v19, v35, v19                                 ; 0a262723
	v_cvt_f32_ubyte1_e32 v26, v23                               ; 7e342517
	v_mac_f32_e32 v62, v28, v58                                 ; 2c7c751c
	v_lshrrev_b32_e32 v48, 4, v48                               ; 20606084
	v_mac_f32_e32 v47, v8, v44                                  ; 2c5e5908
	v_mac_f32_e32 v19, v34, v20                                 ; 2c262922
	v_and_b32_e32 v48, s11, v48                                 ; 2660600b
	v_mad_f32 v5, -v24, v47, v5                                 ; d1c10005 24165f18
	v_cvt_f32_ubyte3_e32 v24, v23                               ; 7e302917
	v_cvt_f32_ubyte0_e32 v23, v23                               ; 7e2e2317
	v_mac_f32_e32 v19, v33, v21                                 ; 2c262b21
	v_cvt_f32_ubyte3_e32 v44, v48                               ; 7e582930
	v_cvt_f32_ubyte2_e32 v47, v48                               ; 7e5e2730
	v_mul_f32_e32 v24, v39, v24                                 ; 0a303127
	v_mac_f32_e32 v19, v32, v49                                 ; 2c266320
	v_cvt_f32_ubyte1_e32 v49, v48                               ; 7e622530
	v_cvt_f32_ubyte0_e32 v48, v48                               ; 7e602330
	v_mul_f32_e32 v44, v43, v44                                 ; 0a58592b
	s_waitcnt vmcnt(9)                                          ; bf8c3f79
	v_cvt_f32_f16_sdwa v51, v50 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e6616f9 00050632
	v_mac_f32_e32 v24, v38, v25                                 ; 2c303326
	v_cvt_f32_f16_e32 v50, v50                                  ; 7e641732
	s_waitcnt vmcnt(8)                                          ; bf8c3f78
	v_alignbyte_b32 v12, v13, v12, v54                          ; d1cf000c 04da190d
	v_alignbyte_b32 v13, v13, v13, v54                          ; d1cf000d 04da1b0d
	v_mac_f32_e32 v44, v42, v47                                 ; 2c585f2a
	v_mac_f32_e32 v24, v37, v26                                 ; 2c303525
	v_mov_b32_sdwa v12, v13 dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_0 ; 7e1802f9 0004150d
	v_mac_f32_e32 v44, v41, v49                                 ; 2c586329
	v_mac_f32_e32 v24, v36, v23                                 ; 2c302f24
	s_waitcnt vmcnt(7)                                          ; bf8c3f77
	v_lshl_or_b32 v52, v52, 12, v52                             ; d2000034 04d11934
	v_mac_f32_e32 v44, v40, v48                                 ; 2c586128
	v_mul_f32_e32 v44, v44, v53                                 ; 0a586b2c
	v_and_b32_e32 v53, s12, v12                                 ; 266a180c
	v_and_b32_e32 v12, s13, v12                                 ; 2618180d
	v_mac_f32_e32 v44, v24, v45                                 ; 2c585b18
	v_lshrrev_b32_e32 v53, 2, v53                               ; 206a6a82
	v_cvt_f32_ubyte3_e32 v54, v12                               ; 7e6c290c
	v_cvt_f32_ubyte2_e32 v58, v12                               ; 7e74270c
	v_mac_f32_e32 v44, v19, v46                                 ; 2c585d13
	s_waitcnt vmcnt(6)                                          ; bf8c3f76
	v_and_b32_e32 v19, s11, v56                                 ; 2626700b
	v_and_or_b32 v52, s11, v52, v53                             ; d2010034 04d6680b
	v_mac_f32_e32 v44, v62, v22                                 ; 2c582d3e
	v_cvt_f32_ubyte1_e32 v62, v12                               ; 7e7c250c
	v_cvt_f32_ubyte0_e32 v12, v12                               ; 7e18230c
	v_cvt_f32_ubyte2_e32 v21, v19                               ; 7e2a2713
	v_cvt_f32_ubyte3_e32 v20, v19                               ; 7e282913
	v_cvt_f32_ubyte3_e32 v13, v52                               ; 7e1a2934
	v_cvt_f32_ubyte1_e32 v22, v19                               ; 7e2c2513
	v_cvt_f32_ubyte1_e32 v18, v52                               ; 7e242534
	v_cvt_f32_ubyte2_e32 v15, v52                               ; 7e1e2734
	v_cvt_f32_ubyte0_e32 v52, v52                               ; 7e682334
	v_mac_f32_e32 v5, v27, v44                                  ; 2c0a591b
	v_cvt_f32_ubyte0_e32 v19, v19                               ; 7e262313
	v_lshrrev_b32_e32 v56, 4, v56                               ; 20707084
	v_mul_f32_e32 v20, v31, v20                                 ; 0a28291f
	v_mul_f32_e32 v13, v11, v13                                 ; 0a1a1b0b
	v_and_b32_e32 v56, s11, v56                                 ; 2670700b
	s_waitcnt vmcnt(5)                                          ; bf8c3f75
	v_and_b32_e32 v26, s11, v55                                 ; 26346e0b
	v_mac_f32_e32 v20, v30, v21                                 ; 2c282b1e
	v_mac_f32_e32 v13, v10, v15                                 ; 2c1a1f0a
	v_cvt_f32_ubyte3_e32 v23, v56                               ; 7e2e2938
	v_cvt_f32_ubyte1_e32 v25, v56                               ; 7e322538
	v_cvt_f32_ubyte2_e32 v24, v56                               ; 7e302738
	v_cvt_f32_ubyte0_e32 v56, v56                               ; 7e702338
	v_cvt_f32_ubyte3_e32 v27, v26                               ; 7e36291a
	v_cvt_f32_ubyte2_e32 v44, v26                               ; 7e58271a
	v_mac_f32_e32 v20, v29, v22                                 ; 2c282d1d
	v_cvt_f32_ubyte1_e32 v45, v26                               ; 7e5a251a
	v_mac_f32_e32 v13, v9, v54                                  ; 2c1a6d09
	v_mul_f32_e32 v23, v35, v23                                 ; 0a2e2f23
	v_cvt_f32_ubyte0_e32 v26, v26                               ; 7e34231a
	v_lshrrev_b32_e32 v55, 4, v55                               ; 206e6e84
	v_mul_f32_e32 v27, v39, v27                                 ; 0a363727
	v_mac_f32_e32 v20, v28, v19                                 ; 2c28271c
	v_mac_f32_e32 v13, v8, v58                                  ; 2c1a7508
	v_mac_f32_e32 v23, v34, v24                                 ; 2c2e3122
	v_and_b32_e32 v55, s11, v55                                 ; 266e6e0b
	v_mac_f32_e32 v27, v38, v44                                 ; 2c365926
	v_mac_f32_e32 v23, v33, v25                                 ; 2c2e3321
	v_cvt_f32_ubyte2_e32 v47, v55                               ; 7e5e2737
	v_cvt_f32_ubyte1_e32 v48, v55                               ; 7e602537
	v_cvt_f32_ubyte3_e32 v46, v55                               ; 7e5c2937
	v_cvt_f32_ubyte0_e32 v55, v55                               ; 7e6e2337
	v_mad_f32 v6, -v51, v13, v6                                 ; d1c10006 241a1b33
	v_mac_f32_e32 v27, v37, v45                                 ; 2c365b25
	v_mac_f32_e32 v23, v32, v56                                 ; 2c2e7120
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_alignbyte_b32 v16, v17, v16, v14                          ; d1cf0010 043a2111
	v_alignbyte_b32 v17, v17, v17, v14                          ; d1cf0011 043a2311
	v_mul_f32_e32 v46, v43, v46                                 ; 0a5c5d2b
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_lshl_or_b32 v59, v59, 12, v59                             ; d200003b 04ed193b
	v_mac_f32_e32 v27, v36, v26                                 ; 2c363524
	v_mov_b32_sdwa v16, v17 dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_0 ; 7e2002f9 00041511
	v_mac_f32_e32 v46, v42, v47                                 ; 2c5c5f2a
	v_and_b32_e32 v49, s12, v16                                 ; 2662200c
	v_mac_f32_e32 v46, v41, v48                                 ; 2c5c6129
	v_lshrrev_b32_e32 v49, 2, v49                               ; 20626282
	v_mac_f32_e32 v46, v40, v55                                 ; 2c5c6f28
	v_and_or_b32 v59, s11, v59, v49                             ; d201003b 04c6760b
	v_mul_f32_e32 v46, v46, v18                                 ; 0a5c252e
	v_mac_f32_e32 v46, v27, v52                                 ; 2c5c691b
	v_mac_f32_e32 v46, v23, v62                                 ; 2c5c7d17
	v_mac_f32_e32 v46, v20, v12                                 ; 2c5c1914
	v_mac_f32_e32 v6, v50, v46                                  ; 2c0c5d32
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v50, s11, v61                                 ; 26647a0b
	v_lshrrev_b32_e32 v61, 4, v61                               ; 207a7a84
	v_cvt_f32_ubyte3_e32 v51, v50                               ; 7e662932
	v_cvt_f32_ubyte1_e32 v53, v50                               ; 7e6a2532
	v_cvt_f32_ubyte2_e32 v52, v50                               ; 7e682732
	v_cvt_f32_ubyte0_e32 v50, v50                               ; 7e642332
	v_and_b32_e32 v61, s11, v61                                 ; 267a7a0b
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v58, s11, v60                                 ; 2674780b
	v_mul_f32_e32 v31, v31, v51                                 ; 0a3e671f
	v_cvt_f32_ubyte1_e32 v56, v61                               ; 7e70253d
	v_cvt_f32_ubyte3_e32 v54, v61                               ; 7e6c293d
	v_cvt_f32_ubyte2_e32 v55, v61                               ; 7e6e273d
	v_cvt_f32_ubyte0_e32 v61, v61                               ; 7e7a233d
	v_cvt_f32_ubyte2_e32 v62, v58                               ; 7e7c273a
	v_mac_f32_e32 v31, v30, v52                                 ; 2c3e691e
	v_mul_f32_e32 v35, v35, v54                                 ; 0a466d23
	v_lshrrev_b32_e32 v60, 4, v60                               ; 20787884
	v_mac_f32_e32 v31, v29, v53                                 ; 2c3e6b1d
	v_mac_f32_e32 v35, v34, v55                                 ; 2c466f22
	v_and_b32_e32 v60, s11, v60                                 ; 2678780b
	v_mac_f32_e32 v31, v28, v50                                 ; 2c3e651c
	v_mac_f32_e32 v35, v33, v56                                 ; 2c467121
	v_mac_f32_e32 v35, v32, v61                                 ; 2c467b20
	v_cvt_f32_ubyte3_e32 v61, v58                               ; 7e7a293a
	v_mul_f32_e32 v39, v39, v61                                 ; 0a4e7b27
	v_mac_f32_e32 v39, v38, v62                                 ; 2c4e7d26
	v_cvt_f32_ubyte1_e32 v62, v58                               ; 7e7c253a
	v_cvt_f32_ubyte0_e32 v58, v58                               ; 7e74233a
	v_and_b32_e32 v16, s13, v16                                 ; 2620200d
	v_mac_f32_e32 v39, v37, v62                                 ; 2c4e7d25
	v_cvt_f32_ubyte3_e32 v62, v60                               ; 7e7c293c
	v_mac_f32_e32 v39, v36, v58                                 ; 2c4e7524
	v_mul_f32_e32 v43, v43, v62                                 ; 0a567d2b
	v_cvt_f32_ubyte2_e32 v62, v60                               ; 7e7c273c
	v_mac_f32_e32 v43, v42, v62                                 ; 2c567d2a
	v_cvt_f32_ubyte1_e32 v62, v60                               ; 7e7c253c
	v_cvt_f32_ubyte0_e32 v60, v60                               ; 7e78233c
	v_mac_f32_e32 v43, v41, v62                                 ; 2c567d29
	v_cvt_f32_ubyte3_e32 v62, v59                               ; 7e7c293b
	v_mac_f32_e32 v43, v40, v60                                 ; 2c567928
	v_mul_f32_e32 v11, v11, v62                                 ; 0a167d0b
	v_cvt_f32_ubyte2_e32 v62, v59                               ; 7e7c273b
	v_mac_f32_e32 v11, v10, v62                                 ; 2c167d0a
	v_cvt_f32_ubyte3_e32 v62, v16                               ; 7e7c2910
	v_mac_f32_e32 v11, v9, v62                                  ; 2c167d09
	v_cvt_f32_ubyte2_e32 v62, v16                               ; 7e7c2710
	v_mac_f32_e32 v11, v8, v62                                  ; 2c167d08
	v_cvt_f32_ubyte1_e32 v62, v59                               ; 7e7c253b
	v_cvt_f32_ubyte0_e32 v59, v59                               ; 7e76233b
	v_mul_f32_e32 v43, v43, v62                                 ; 0a567d2b
	v_cvt_f32_ubyte1_e32 v62, v16                               ; 7e7c2510
	v_cvt_f32_ubyte0_e32 v16, v16                               ; 7e202310
	v_mac_f32_e32 v43, v39, v59                                 ; 2c567727
	v_mac_f32_e32 v43, v35, v62                                 ; 2c567d23
	v_cvt_f32_f16_sdwa v62, v57 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e7c16f9 00050639
	v_cvt_f32_f16_e32 v57, v57                                  ; 7e721739
	v_mac_f32_e32 v43, v31, v16                                 ; 2c56211f
	v_mad_f32 v7, -v62, v11, v7                                 ; d1c10007 241e173e
	v_mac_f32_e32 v7, v57, v43                                  ; 2c0e5739
BB5:
	s_mov_b64 s[0:1], exec                                      ; be80017e
	v_cmpx_le_u32_e32 vcc, s3, v0                               ; 7db60003
BB6:
	s_andn2_b64 s[0:1], s[0:1], exec                            ; 89807e00
	s_cbranch_scc1 BB10                                         ; bf85fe31
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
	s_branch BB119                                              ; bf82033d
BB42:
	s_cmp_lt_u32 s16, s4                                        ; bf0a0410
	s_cbranch_scc0 BB119                                        ; bf84033b
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
	s_nop 0                                                     ; bf800000
	(then repeated 3 times)
BB47:
	s_mov_b64 s[0:1], exec                                      ; be80017e
	v_cmpx_le_u32_e32 vcc, s3, v0                               ; 7db60003
BB48:
	s_andn2_b64 s[0:1], s[0:1], exec                            ; 89807e00
	s_cbranch_scc0 BB65                                         ; bf8401e1
BB52:
	s_mov_b64 exec, s[0:1]                                      ; befe0100
	s_mov_b32 s0, s2                                            ; be800002
	s_movk_i32 s1, 0x8000                                       ; b0018000
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_load_dwordx4 s[12:15], s[0:1], 0x50                       ; c00a0300 00000050
	s_mul_i32 s5, s6, s17                                       ; 92051106
	v_lshl_add_u32 v8, v0, 8, v1                                ; d1fd0008 04051100
	v_bfe_u32 v10, v1, 2, 4                                     ; d1c8000a 02110501
	v_lshrrev_b32_e32 v11, 6, v1                                ; 20160286
	s_lshr_b32 s9, s5, 4                                        ; 8f098405
	s_cmp_lg_i32 s4, 0                                          ; bf018004
	v_lshl_add_u32 v11, v11, 3, v10                             ; d1fd000b 0429070b
	v_lshl_add_u32 v9, v0, 4, s9                                ; d1fd0009 00250900
	s_cbranch_scc0 BB64                                         ; bf8401cc
BB53:
	s_load_dwordx8 s[24:31], s[0:1], 0x0                        ; c00e0600 00000000
	v_add_lshl_u32 v9, v9, v11, 4                               ; d1fe0009 02121709
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_load_dwordx4 v[12:15], v9, s[12:15], 0 offen         ; e05c1000 80030c09
	s_mul_i32 s0, s16, s3                                       ; 92000310
	v_lshlrev_b32_e32 v11, 1, v2                                ; 24160481
	v_add_u32_e32 v23, 64, v4                                   ; 682e08c0
	s_add_u32 s0, s19, s0                                       ; 80000013
	v_and_b32_e32 v17, -4, v11                                  ; 262216c4
	v_add_u32_e32 v20, 8, v11                                   ; 68281688
	v_add_u32_e32 v9, s0, v0                                    ; 68120000
	v_lshlrev_b32_e32 v10, 4, v9                                ; 24141284
	v_lshl_add_u32 v9, v9, 7, v10                               ; d1fd0009 04290f09
	v_add_u32_e32 v16, 4, v9                                    ; 68201284
	v_add_u32_e32 v21, 16, v9                                   ; 682a1290
	v_add_u32_e32 v18, v17, v16                                 ; 68242111
	v_add_u32_e32 v19, v16, v11                                 ; 68261710
	v_add_u32_e32 v16, v16, v20                                 ; 68202910
	v_add_u32_e32 v22, v21, v4                                  ; 682c0915
	v_add_u32_e32 v21, v21, v23                                 ; 682a2f15
	buffer_load_dword v9, v9, s[24:27], 0 offen                 ; e0501000 80060909
	buffer_load_dwordx2 v[24:25], v18, s[24:27], 0 offen        ; e0541000 80061812
	buffer_load_ushort v16, v16, s[24:27], 0 offen              ; e0481000 80061010
	buffer_load_dword v22, v22, s[24:27], 0 offen               ; e0501000 80061616
	buffer_load_dword v21, v21, s[24:27], 0 offen               ; e0501000 80061515
	v_add_u32_e32 v26, s5, v8                                   ; 68341005
	v_add_u32_e32 v8, 0x80, v8                                  ; 681010ff 00000080
	v_lshrrev_b32_e32 v26, 2, v26                               ; 20343482
	v_add_u32_e32 v8, s5, v8                                    ; 68101005
	v_lshlrev_b32_e32 v26, 4, v26                               ; 24343484
	v_lshrrev_b32_e32 v8, 2, v8                                 ; 20101082
	v_lshlrev_b32_e32 v8, 4, v8                                 ; 24101084
	buffer_load_dwordx4 v[28:31], v26, s[28:31], 0 offen        ; e05c1000 80071c1a
	buffer_load_dwordx4 v[32:35], v26, s[28:31], 0 offen offset:128 ; e05c1080 8007201a
	buffer_load_dwordx4 v[36:39], v8, s[28:31], 0 offen         ; e05c1000 80072408
	buffer_load_dwordx4 v[40:43], v8, s[28:31], 0 offen offset:128 ; e05c1080 80072808
	s_mov_b32 s1, 0xf0f0f0f                                     ; be8100ff 0f0f0f0f
	s_cmp_lt_u32 1, s4                                          ; bf0a0481
	s_waitcnt vmcnt(8)                                          ; bf8c3f78
	v_cvt_f32_f16_sdwa v27, v9 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e3616f9 00050609
	v_cvt_f32_f16_e32 v9, v9                                    ; 7e121709
	s_waitcnt vmcnt(7)                                          ; bf8c3f77
	v_alignbyte_b32 v24, v25, v24, v19                          ; d1cf0018 044e3119
	v_alignbyte_b32 v25, v25, v25, v19                          ; d1cf0019 044e3319
	s_waitcnt vmcnt(6)                                          ; bf8c3f76
	v_lshl_or_b32 v16, v16, 12, v16                             ; d2000010 04411910
	v_mov_b32_sdwa v24, v25 dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_0 ; 7e3002f9 00041519
	v_and_b32_e32 v44, 0xc0c0c0c0, v24                          ; 265830ff c0c0c0c0
	v_and_b32_e32 v24, 0x3f3f3f3f, v24                          ; 263030ff 3f3f3f3f
	s_waitcnt vmcnt(5)                                          ; bf8c3f75
	v_and_b32_e32 v51, s1, v22                                  ; 26662c01
	v_lshrrev_b32_e32 v44, 2, v44                               ; 20585882
	v_cvt_f32_ubyte2_e32 v46, v24                               ; 7e5c2718
	v_cvt_f32_ubyte1_e32 v47, v24                               ; 7e5e2518
	v_cvt_f32_ubyte3_e32 v45, v24                               ; 7e5a2918
	v_cvt_f32_ubyte0_e32 v24, v24                               ; 7e302318
	v_cvt_f32_ubyte3_e32 v52, v51                               ; 7e682933
	v_cvt_f32_ubyte2_e32 v53, v51                               ; 7e6a2733
	v_and_or_b32 v16, s1, v16, v44                              ; d2010010 04b22001
	v_cvt_f32_ubyte1_e32 v54, v51                               ; 7e6c2533
	v_cvt_f32_ubyte0_e32 v51, v51                               ; 7e662333
	v_lshrrev_b32_e32 v22, 4, v22                               ; 202c2c84
	v_cvt_f32_ubyte1_e32 v50, v16                               ; 7e642510
	v_cvt_f32_ubyte2_e32 v49, v16                               ; 7e622710
	v_cvt_f32_ubyte3_e32 v48, v16                               ; 7e602910
	v_cvt_f32_ubyte0_e32 v16, v16                               ; 7e202310
	s_waitcnt vmcnt(4)                                          ; bf8c3f74
	v_and_b32_e32 v58, s1, v21                                  ; 26742a01
	v_and_b32_e32 v22, s1, v22                                  ; 262c2c01
	v_lshrrev_b32_e32 v21, 4, v21                               ; 202a2a84
	v_mul_f32_e32 v48, v15, v48                                 ; 0a60610f
	v_cvt_f32_ubyte2_e32 v60, v58                               ; 7e78273a
	v_cvt_f32_ubyte1_e32 v61, v58                               ; 7e7a253a
	v_cvt_f32_ubyte3_e32 v59, v58                               ; 7e76293a
	v_cvt_f32_ubyte0_e32 v58, v58                               ; 7e74233a
	v_cvt_f32_ubyte1_e32 v57, v22                               ; 7e722516
	v_cvt_f32_ubyte3_e32 v55, v22                               ; 7e6e2916
	v_cvt_f32_ubyte2_e32 v56, v22                               ; 7e702716
	v_cvt_f32_ubyte0_e32 v22, v22                               ; 7e2c2316
	v_and_b32_e32 v21, s1, v21                                  ; 262a2a01
	v_mac_f32_e32 v48, v14, v49                                 ; 2c60630e
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_mul_f32_e32 v52, v31, v52                                 ; 0a68691f
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_mul_f32_e32 v55, v35, v55                                 ; 0a6e6f23
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_mul_f32_e32 v59, v39, v59                                 ; 0a767727
	v_cvt_f32_ubyte2_e32 v8, v21                                ; 7e102715
	v_cvt_f32_ubyte1_e32 v10, v21                               ; 7e142515
	v_cvt_f32_ubyte3_e32 v62, v21                               ; 7e7c2915
	v_cvt_f32_ubyte0_e32 v21, v21                               ; 7e2a2315
	v_mac_f32_e32 v48, v13, v45                                 ; 2c605b0d
	v_mac_f32_e32 v52, v30, v53                                 ; 2c686b1e
	v_mac_f32_e32 v55, v34, v56                                 ; 2c6e7122
	v_mac_f32_e32 v59, v38, v60                                 ; 2c767926
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_mul_f32_e32 v62, v43, v62                                 ; 0a7c7d2b
	v_mac_f32_e32 v48, v12, v46                                 ; 2c605d0c
	v_mac_f32_e32 v52, v29, v54                                 ; 2c686d1d
	v_mac_f32_e32 v55, v33, v57                                 ; 2c6e7321
	v_mac_f32_e32 v59, v37, v61                                 ; 2c767b25
	v_mac_f32_e32 v62, v42, v8                                  ; 2c7c112a
	v_mad_f32 v3, -v27, v48, v3                                 ; d1c10003 240e611b
	v_mac_f32_e32 v52, v28, v51                                 ; 2c68671c
	v_mac_f32_e32 v55, v32, v22                                 ; 2c6e2d20
	v_mac_f32_e32 v59, v36, v58                                 ; 2c767524
	v_mac_f32_e32 v62, v41, v10                                 ; 2c7c1529
	v_mac_f32_e32 v62, v40, v21                                 ; 2c7c2b28
	v_mul_f32_e32 v62, v62, v50                                 ; 0a7c653e
	v_mac_f32_e32 v62, v59, v16                                 ; 2c7c213b
	v_mac_f32_e32 v62, v55, v47                                 ; 2c7c5f37
	v_mac_f32_e32 v62, v52, v24                                 ; 2c7c3134
	v_mac_f32_e32 v3, v9, v62                                   ; 2c067d09
	s_cbranch_scc0 BB64                                         ; bf840142
BB54:
	s_add_u32 s0, s16, 1                                        ; 80008110
	s_mul_i32 s0, s0, s3                                        ; 92000300
	s_add_u32 s0, s19, s0                                       ; 80000013
	v_add_u32_e32 v8, s0, v0                                    ; 68100000
	v_lshlrev_b32_e32 v9, 4, v8                                 ; 24121084
	v_lshl_add_u32 v8, v8, 7, v9                                ; d1fd0008 04250f08
	v_add_u32_e32 v10, 4, v8                                    ; 68141084
	v_add_u32_e32 v19, 16, v8                                   ; 68261090
	v_add_u32_e32 v16, v17, v10                                 ; 68201511
	v_add_u32_e32 v18, v10, v11                                 ; 6824170a
	v_add_u32_e32 v10, v10, v20                                 ; 6814290a
	v_add_u32_e32 v21, v19, v4                                  ; 682a0913
	v_add_u32_e32 v19, v19, v23                                 ; 68262f13
	buffer_load_dword v8, v8, s[24:27], 0 offen                 ; e0501000 80060808
	buffer_load_dwordx2 v[24:25], v16, s[24:27], 0 offen        ; e0541000 80061810
	buffer_load_ushort v10, v10, s[24:27], 0 offen              ; e0481000 80060a0a
	buffer_load_dword v21, v21, s[24:27], 0 offen               ; e0501000 80061515
	buffer_load_dword v19, v19, s[24:27], 0 offen               ; e0501000 80061313
	s_mov_b32 s1, 0xf0f0f0f                                     ; be8100ff 0f0f0f0f
	s_cmp_lt_u32 2, s4                                          ; bf0a0482
	s_waitcnt vmcnt(4)                                          ; bf8c3f74
	v_cvt_f32_f16_sdwa v22, v8 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e2c16f9 00050608
	v_cvt_f32_f16_e32 v8, v8                                    ; 7e101708
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_alignbyte_b32 v24, v25, v24, v18                          ; d1cf0018 044a3119
	v_alignbyte_b32 v25, v25, v25, v18                          ; d1cf0019 044a3319
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_lshl_or_b32 v10, v10, 12, v10                             ; d200000a 0429190a
	v_mov_b32_sdwa v24, v25 dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_0 ; 7e3002f9 00041519
	v_and_b32_e32 v25, 0xc0c0c0c0, v24                          ; 263230ff c0c0c0c0
	v_and_b32_e32 v24, 0x3f3f3f3f, v24                          ; 263030ff 3f3f3f3f
	v_lshrrev_b32_e32 v25, 2, v25                               ; 20323282
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v48, s1, v21                                  ; 26602a01
	v_cvt_f32_ubyte3_e32 v26, v24                               ; 7e342918
	v_cvt_f32_ubyte2_e32 v27, v24                               ; 7e362718
	v_cvt_f32_ubyte1_e32 v44, v24                               ; 7e582518
	v_cvt_f32_ubyte0_e32 v24, v24                               ; 7e302318
	v_and_or_b32 v10, s1, v10, v25                              ; d201000a 04661401
	v_cvt_f32_ubyte3_e32 v49, v48                               ; 7e622930
	v_cvt_f32_ubyte2_e32 v50, v48                               ; 7e642730
	v_cvt_f32_ubyte1_e32 v51, v48                               ; 7e662530
	v_cvt_f32_ubyte0_e32 v48, v48                               ; 7e602330
	v_cvt_f32_ubyte1_e32 v47, v10                               ; 7e5e250a
	v_cvt_f32_ubyte3_e32 v45, v10                               ; 7e5a290a
	v_cvt_f32_ubyte2_e32 v46, v10                               ; 7e5c270a
	v_cvt_f32_ubyte0_e32 v10, v10                               ; 7e14230a
	v_mul_f32_e32 v49, v31, v49                                 ; 0a62631f
	v_lshrrev_b32_e32 v21, 4, v21                               ; 202a2a84
	v_mul_f32_e32 v45, v15, v45                                 ; 0a5a5b0f
	v_mac_f32_e32 v49, v30, v50                                 ; 2c62651e
	v_and_b32_e32 v21, s1, v21                                  ; 262a2a01
	v_mac_f32_e32 v45, v14, v46                                 ; 2c5a5d0e
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v55, s1, v19                                  ; 266e2601
	v_mac_f32_e32 v49, v29, v51                                 ; 2c62671d
	v_cvt_f32_ubyte3_e32 v52, v21                               ; 7e682915
	v_cvt_f32_ubyte2_e32 v53, v21                               ; 7e6a2715
	v_cvt_f32_ubyte1_e32 v54, v21                               ; 7e6c2515
	v_cvt_f32_ubyte0_e32 v21, v21                               ; 7e2a2315
	v_mac_f32_e32 v45, v13, v26                                 ; 2c5a350d
	v_cvt_f32_ubyte2_e32 v57, v55                               ; 7e722737
	v_cvt_f32_ubyte3_e32 v56, v55                               ; 7e702937
	v_cvt_f32_ubyte1_e32 v58, v55                               ; 7e742537
	v_mac_f32_e32 v49, v28, v48                                 ; 2c62611c
	v_mul_f32_e32 v52, v35, v52                                 ; 0a686923
	v_cvt_f32_ubyte0_e32 v55, v55                               ; 7e6e2337
	v_lshrrev_b32_e32 v19, 4, v19                               ; 20262684
	v_mac_f32_e32 v45, v12, v27                                 ; 2c5a370c
	v_mul_f32_e32 v56, v39, v56                                 ; 0a707127
	v_mac_f32_e32 v52, v34, v53                                 ; 2c686b22
	v_and_b32_e32 v19, s1, v19                                  ; 26262601
	v_mad_f32 v5, -v22, v45, v5                                 ; d1c10005 24165b16
	v_mac_f32_e32 v56, v38, v57                                 ; 2c707326
	v_mac_f32_e32 v52, v33, v54                                 ; 2c686d21
	v_cvt_f32_ubyte1_e32 v61, v19                               ; 7e7a2513
	v_cvt_f32_ubyte2_e32 v60, v19                               ; 7e782713
	v_cvt_f32_ubyte3_e32 v59, v19                               ; 7e762913
	v_cvt_f32_ubyte0_e32 v19, v19                               ; 7e262313
	v_mac_f32_e32 v56, v37, v58                                 ; 2c707525
	v_mac_f32_e32 v52, v32, v21                                 ; 2c682b20
	v_mul_f32_e32 v59, v43, v59                                 ; 0a76772b
	v_mac_f32_e32 v56, v36, v55                                 ; 2c706f24
	v_mac_f32_e32 v59, v42, v60                                 ; 2c76792a
	v_mac_f32_e32 v59, v41, v61                                 ; 2c767b29
	v_mac_f32_e32 v59, v40, v19                                 ; 2c762728
	v_mul_f32_e32 v59, v59, v47                                 ; 0a765f3b
	v_mac_f32_e32 v59, v56, v10                                 ; 2c761538
	v_mac_f32_e32 v59, v52, v44                                 ; 2c765934
	v_mac_f32_e32 v59, v49, v24                                 ; 2c763131
	v_mac_f32_e32 v5, v8, v59                                   ; 2c0a7708
	s_cbranch_scc0 BB64                                         ; bf8400d6
BB55:
	s_add_u32 s0, s16, 2                                        ; 80008210
	s_mul_i32 s0, s0, s3                                        ; 92000300
	s_add_u32 s0, s19, s0                                       ; 80000013
	v_add_u32_e32 v8, s0, v0                                    ; 68100000
	v_lshlrev_b32_e32 v9, 4, v8                                 ; 24121084
	v_lshl_add_u32 v8, v8, 7, v9                                ; d1fd0008 04250f08
	v_add_u32_e32 v10, 4, v8                                    ; 68141084
	v_add_u32_e32 v19, 16, v8                                   ; 68261090
	v_add_u32_e32 v16, v17, v10                                 ; 68201511
	v_add_u32_e32 v18, v10, v11                                 ; 6824170a
	v_add_u32_e32 v10, v10, v20                                 ; 6814290a
	v_add_u32_e32 v21, v19, v4                                  ; 682a0913
	v_add_u32_e32 v19, v19, v23                                 ; 68262f13
	buffer_load_dword v8, v8, s[24:27], 0 offen                 ; e0501000 80060808
	buffer_load_dwordx2 v[24:25], v16, s[24:27], 0 offen        ; e0541000 80061810
	buffer_load_ushort v10, v10, s[24:27], 0 offen              ; e0481000 80060a0a
	buffer_load_dword v21, v21, s[24:27], 0 offen               ; e0501000 80061515
	buffer_load_dword v19, v19, s[24:27], 0 offen               ; e0501000 80061313
	s_mov_b32 s1, 0xf0f0f0f                                     ; be8100ff 0f0f0f0f
	s_cmp_lt_u32 3, s4                                          ; bf0a0483
	s_waitcnt vmcnt(4)                                          ; bf8c3f74
	v_cvt_f32_f16_sdwa v22, v8 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e2c16f9 00050608
	v_cvt_f32_f16_e32 v8, v8                                    ; 7e101708
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_alignbyte_b32 v24, v25, v24, v18                          ; d1cf0018 044a3119
	v_alignbyte_b32 v25, v25, v25, v18                          ; d1cf0019 044a3319
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_lshl_or_b32 v10, v10, 12, v10                             ; d200000a 0429190a
	v_mov_b32_sdwa v24, v25 dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_0 ; 7e3002f9 00041519
	v_and_b32_e32 v25, 0xc0c0c0c0, v24                          ; 263230ff c0c0c0c0
	v_and_b32_e32 v24, 0x3f3f3f3f, v24                          ; 263030ff 3f3f3f3f
	v_lshrrev_b32_e32 v25, 2, v25                               ; 20323282
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v48, s1, v21                                  ; 26602a01
	v_cvt_f32_ubyte3_e32 v26, v24                               ; 7e342918
	v_cvt_f32_ubyte2_e32 v27, v24                               ; 7e362718
	v_cvt_f32_ubyte1_e32 v44, v24                               ; 7e582518
	v_cvt_f32_ubyte0_e32 v24, v24                               ; 7e302318
	v_and_or_b32 v10, s1, v10, v25                              ; d201000a 04661401
	v_cvt_f32_ubyte3_e32 v49, v48                               ; 7e622930
	v_cvt_f32_ubyte2_e32 v50, v48                               ; 7e642730
	v_cvt_f32_ubyte1_e32 v51, v48                               ; 7e662530
	v_cvt_f32_ubyte0_e32 v48, v48                               ; 7e602330
	v_cvt_f32_ubyte1_e32 v47, v10                               ; 7e5e250a
	v_cvt_f32_ubyte3_e32 v45, v10                               ; 7e5a290a
	v_cvt_f32_ubyte2_e32 v46, v10                               ; 7e5c270a
	v_cvt_f32_ubyte0_e32 v10, v10                               ; 7e14230a
	v_mul_f32_e32 v49, v31, v49                                 ; 0a62631f
	v_lshrrev_b32_e32 v21, 4, v21                               ; 202a2a84
	v_mul_f32_e32 v45, v15, v45                                 ; 0a5a5b0f
	v_mac_f32_e32 v49, v30, v50                                 ; 2c62651e
	v_and_b32_e32 v21, s1, v21                                  ; 262a2a01
	v_mac_f32_e32 v45, v14, v46                                 ; 2c5a5d0e
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v55, s1, v19                                  ; 266e2601
	v_mac_f32_e32 v49, v29, v51                                 ; 2c62671d
	v_cvt_f32_ubyte3_e32 v52, v21                               ; 7e682915
	v_cvt_f32_ubyte2_e32 v53, v21                               ; 7e6a2715
	v_cvt_f32_ubyte1_e32 v54, v21                               ; 7e6c2515
	v_cvt_f32_ubyte0_e32 v21, v21                               ; 7e2a2315
	v_mac_f32_e32 v45, v13, v26                                 ; 2c5a350d
	v_cvt_f32_ubyte2_e32 v57, v55                               ; 7e722737
	v_cvt_f32_ubyte3_e32 v56, v55                               ; 7e702937
	v_cvt_f32_ubyte1_e32 v58, v55                               ; 7e742537
	v_mac_f32_e32 v49, v28, v48                                 ; 2c62611c
	v_mul_f32_e32 v52, v35, v52                                 ; 0a686923
	v_cvt_f32_ubyte0_e32 v55, v55                               ; 7e6e2337
	v_lshrrev_b32_e32 v19, 4, v19                               ; 20262684
	v_mac_f32_e32 v45, v12, v27                                 ; 2c5a370c
	v_mul_f32_e32 v56, v39, v56                                 ; 0a707127
	v_mac_f32_e32 v52, v34, v53                                 ; 2c686b22
	v_and_b32_e32 v19, s1, v19                                  ; 26262601
	v_mad_f32 v6, -v22, v45, v6                                 ; d1c10006 241a5b16
	v_mac_f32_e32 v56, v38, v57                                 ; 2c707326
	v_mac_f32_e32 v52, v33, v54                                 ; 2c686d21
	v_cvt_f32_ubyte1_e32 v61, v19                               ; 7e7a2513
	v_cvt_f32_ubyte2_e32 v60, v19                               ; 7e782713
	v_cvt_f32_ubyte3_e32 v59, v19                               ; 7e762913
	v_cvt_f32_ubyte0_e32 v19, v19                               ; 7e262313
	v_mac_f32_e32 v56, v37, v58                                 ; 2c707525
	v_mac_f32_e32 v52, v32, v21                                 ; 2c682b20
	v_mul_f32_e32 v59, v43, v59                                 ; 0a76772b
	v_mac_f32_e32 v56, v36, v55                                 ; 2c706f24
	v_mac_f32_e32 v59, v42, v60                                 ; 2c76792a
	v_mac_f32_e32 v59, v41, v61                                 ; 2c767b29
	v_mac_f32_e32 v59, v40, v19                                 ; 2c762728
	v_mul_f32_e32 v59, v59, v47                                 ; 0a765f3b
	v_mac_f32_e32 v59, v56, v10                                 ; 2c761538
	v_mac_f32_e32 v59, v52, v44                                 ; 2c765934
	v_mac_f32_e32 v59, v49, v24                                 ; 2c763131
	v_mac_f32_e32 v6, v8, v59                                   ; 2c0c7708
	s_cbranch_scc0 BB64                                         ; bf84006a
BB56:
	s_add_u32 s0, s16, 3                                        ; 80008310
	s_mul_i32 s0, s0, s3                                        ; 92000300
	s_add_u32 s0, s19, s0                                       ; 80000013
	v_add_u32_e32 v8, s0, v0                                    ; 68100000
	v_lshlrev_b32_e32 v9, 4, v8                                 ; 24121084
	v_lshl_add_u32 v8, v8, 7, v9                                ; d1fd0008 04250f08
	v_add_u32_e32 v10, 4, v8                                    ; 68141084
	v_add_u32_e32 v16, 16, v8                                   ; 68201090
	v_add_u32_e32 v17, v17, v10                                 ; 68221511
	v_add_u32_e32 v11, v10, v11                                 ; 6816170a
	v_add_u32_e32 v10, v10, v20                                 ; 6814290a
	v_add_u32_e32 v18, v16, v4                                  ; 68240910
	v_add_u32_e32 v16, v16, v23                                 ; 68202f10
	buffer_load_dword v8, v8, s[24:27], 0 offen                 ; e0501000 80060808
	buffer_load_dwordx2 v[20:21], v17, s[24:27], 0 offen        ; e0541000 80061411
	buffer_load_ushort v10, v10, s[24:27], 0 offen              ; e0481000 80060a0a
	buffer_load_dword v18, v18, s[24:27], 0 offen               ; e0501000 80061212
	buffer_load_dword v16, v16, s[24:27], 0 offen               ; e0501000 80061010
	s_mov_b32 s1, 0xf0f0f0f                                     ; be8100ff 0f0f0f0f
	s_waitcnt vmcnt(4)                                          ; bf8c3f74
	v_cvt_f32_f16_sdwa v19, v8 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e2616f9 00050608
	v_cvt_f32_f16_e32 v8, v8                                    ; 7e101708
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_alignbyte_b32 v20, v21, v20, v11                          ; d1cf0014 042e2915
	v_alignbyte_b32 v21, v21, v21, v11                          ; d1cf0015 042e2b15
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_lshl_or_b32 v10, v10, 12, v10                             ; d200000a 0429190a
	v_mov_b32_sdwa v20, v21 dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_0 ; 7e2802f9 00041515
	v_and_b32_e32 v21, 0xc0c0c0c0, v20                          ; 262a28ff c0c0c0c0
	v_and_b32_e32 v20, 0x3f3f3f3f, v20                          ; 262828ff 3f3f3f3f
	v_lshrrev_b32_e32 v21, 2, v21                               ; 202a2a82
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v44, s1, v18                                  ; 26582401
	v_cvt_f32_ubyte3_e32 v22, v20                               ; 7e2c2914
	v_cvt_f32_ubyte2_e32 v23, v20                               ; 7e2e2714
	v_cvt_f32_ubyte1_e32 v24, v20                               ; 7e302514
	v_cvt_f32_ubyte0_e32 v20, v20                               ; 7e282314
	v_and_or_b32 v10, s1, v10, v21                              ; d201000a 04561401
	v_cvt_f32_ubyte3_e32 v45, v44                               ; 7e5a292c
	v_cvt_f32_ubyte2_e32 v46, v44                               ; 7e5c272c
	v_cvt_f32_ubyte1_e32 v47, v44                               ; 7e5e252c
	v_cvt_f32_ubyte0_e32 v44, v44                               ; 7e58232c
	v_cvt_f32_ubyte3_e32 v25, v10                               ; 7e32290a
	v_cvt_f32_ubyte2_e32 v26, v10                               ; 7e34270a
	v_cvt_f32_ubyte1_e32 v27, v10                               ; 7e36250a
	v_cvt_f32_ubyte0_e32 v10, v10                               ; 7e14230a
	v_mul_f32_e32 v31, v31, v45                                 ; 0a3e5b1f
	v_lshrrev_b32_e32 v18, 4, v18                               ; 20242484
	v_mul_f32_e32 v15, v15, v25                                 ; 0a1e330f
	v_mac_f32_e32 v31, v30, v46                                 ; 2c3e5d1e
	v_and_b32_e32 v18, s1, v18                                  ; 26242401
	v_mac_f32_e32 v15, v14, v26                                 ; 2c1e350e
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v51, s1, v16                                  ; 26662001
	v_mac_f32_e32 v31, v29, v47                                 ; 2c3e5f1d
	v_cvt_f32_ubyte3_e32 v48, v18                               ; 7e602912
	v_cvt_f32_ubyte2_e32 v49, v18                               ; 7e622712
	v_cvt_f32_ubyte1_e32 v50, v18                               ; 7e642512
	v_cvt_f32_ubyte0_e32 v18, v18                               ; 7e242312
	v_mac_f32_e32 v15, v13, v22                                 ; 2c1e2d0d
	v_cvt_f32_ubyte2_e32 v53, v51                               ; 7e6a2733
	v_cvt_f32_ubyte3_e32 v52, v51                               ; 7e682933
	v_cvt_f32_ubyte1_e32 v54, v51                               ; 7e6c2533
	v_mac_f32_e32 v31, v28, v44                                 ; 2c3e591c
	v_mul_f32_e32 v35, v35, v48                                 ; 0a466123
	v_cvt_f32_ubyte0_e32 v51, v51                               ; 7e662333
	v_lshrrev_b32_e32 v16, 4, v16                               ; 20202084
	v_mac_f32_e32 v15, v12, v23                                 ; 2c1e2f0c
	v_mul_f32_e32 v39, v39, v52                                 ; 0a4e6927
	v_mac_f32_e32 v35, v34, v49                                 ; 2c466322
	v_and_b32_e32 v16, s1, v16                                  ; 26202001
	v_mad_f32 v7, -v19, v15, v7                                 ; d1c10007 241e1f13
	v_mac_f32_e32 v39, v38, v53                                 ; 2c4e6b26
	v_mac_f32_e32 v35, v33, v50                                 ; 2c466521
	v_cvt_f32_ubyte2_e32 v56, v16                               ; 7e702710
	v_cvt_f32_ubyte1_e32 v57, v16                               ; 7e722510
	v_cvt_f32_ubyte3_e32 v55, v16                               ; 7e6e2910
	v_cvt_f32_ubyte0_e32 v16, v16                               ; 7e202310
	v_mac_f32_e32 v39, v37, v54                                 ; 2c4e6d25
	v_mac_f32_e32 v35, v32, v18                                 ; 2c462520
	v_mul_f32_e32 v43, v43, v55                                 ; 0a566f2b
	v_mac_f32_e32 v39, v36, v51                                 ; 2c4e6724
	v_mac_f32_e32 v43, v42, v56                                 ; 2c56712a
	v_mac_f32_e32 v43, v41, v57                                 ; 2c567329
	v_mac_f32_e32 v43, v40, v16                                 ; 2c562128
	v_mul_f32_e32 v43, v43, v27                                 ; 0a56372b
	v_mac_f32_e32 v43, v39, v10                                 ; 2c561527
	v_mac_f32_e32 v43, v35, v24                                 ; 2c563123
	v_mac_f32_e32 v43, v31, v20                                 ; 2c56291f
	v_mac_f32_e32 v7, v8, v43                                   ; 2c0e5708
BB64:
	v_add_u32_e32 v0, 4, v0                                     ; 68000084
	s_branch BB47                                               ; bf82fe1b
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
	s_cbranch_execz BB119                                       ; bf880084
BB78:
	s_bitcmp1_b32 s8, 0                                         ; bf0d8008
	s_cbranch_scc0 BB80                                         ; bf84000f
BB79:
	s_mov_b32 s0, s2                                            ; be800002
	s_movk_i32 s1, 0x8000                                       ; b0018000
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
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
