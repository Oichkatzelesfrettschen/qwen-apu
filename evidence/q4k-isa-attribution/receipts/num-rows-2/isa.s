BB0:
	s_load_dword s0, s[14:15], 0x0                              ; c0020007 00000000
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_mul_i32 s0, s0, s18                                       ; 92001200
	s_add_u32 s16, s16, s0                                      ; 80100010
	s_lshl_b32 s16, s16, 1                                      ; 8e108110
	s_add_u32 s1, s16, 2                                        ; 80018210
	s_cmp_ge_u32 s4, s1                                         ; bf090104
	s_cbranch_scc0 BB30                                         ; bf8401d7
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
	s_branch BB5                                                ; bf8200fe
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
	v_lshlrev_b32_e32 v26, 1, v2                                ; 24340481
	v_add_u32_e32 v34, 64, v4                                   ; 684408c0
	s_add_u32 s1, s18, s1                                       ; 80010112
	s_add_u32 s4, s16, 1                                        ; 80048110
	v_and_b32_e32 v28, -4, v26                                  ; 263834c4
	v_add_u32_e32 v31, 8, v26                                   ; 683e3488
	v_add_u32_e32 v24, s1, v0                                   ; 68300001
	s_mul_i32 s4, s4, s3                                        ; 92040304
	v_lshlrev_b32_e32 v25, 4, v24                               ; 24323084
	s_add_u32 s4, s18, s4                                       ; 80040412
	v_lshl_add_u32 v24, v24, 7, v25                             ; d1fd0018 04650f18
	v_add_u32_e32 v35, s4, v0                                   ; 68460004
	v_add_u32_e32 v27, 4, v24                                   ; 68363084
	v_add_u32_e32 v32, 16, v24                                  ; 68403090
	v_lshlrev_b32_e32 v36, 4, v35                               ; 24484684
	v_add_u32_e32 v30, v27, v26                                 ; 683c351b
	v_add_u32_e32 v29, v28, v27                                 ; 683a371c
	v_add_u32_e32 v27, v27, v31                                 ; 68363f1b
	v_add_u32_e32 v33, v32, v4                                  ; 68420920
	v_add_u32_e32 v32, v32, v34                                 ; 68404520
	v_lshl_add_u32 v35, v35, 7, v36                             ; d1fd0023 04910f23
	v_add_u32_e32 v37, 4, v35                                   ; 684a4684
	v_add_u32_e32 v38, 16, v35                                  ; 684c4690
	v_add_u32_e32 v28, v28, v37                                 ; 68384b1c
	v_add_u32_e32 v26, v37, v26                                 ; 68343525
	v_add_u32_e32 v37, v37, v31                                 ; 684a3f25
	v_add_u32_e32 v39, v38, v4                                  ; 684e0926
	v_add_u32_e32 v38, v38, v34                                 ; 684c4526
	buffer_load_dword v24, v24, s[24:27], 0 offen               ; e0501000 80061818
	buffer_load_dwordx2 v[6:7], v29, s[24:27], 0 offen          ; e0541000 8006061d
	buffer_load_ushort v27, v27, s[24:27], 0 offen              ; e0481000 80061b1b
	buffer_load_dword v33, v33, s[24:27], 0 offen               ; e0501000 80062121
	buffer_load_dword v32, v32, s[24:27], 0 offen               ; e0501000 80062020
	buffer_load_dword v35, v35, s[24:27], 0 offen               ; e0501000 80062323
	buffer_load_dwordx2 v[28:29], v28, s[24:27], 0 offen        ; e0541000 80061c1c
	buffer_load_ushort v37, v37, s[24:27], 0 offen              ; e0481000 80062525
	buffer_load_dword v39, v39, s[24:27], 0 offen               ; e0501000 80062727
	buffer_load_dword v38, v38, s[24:27], 0 offen               ; e0501000 80062626
	s_mov_b32 s5, 0xf0f0f0f                                     ; be8500ff 0f0f0f0f
	v_add_u32_e32 v0, 4, v0                                     ; 68000084
	s_waitcnt vmcnt(13)                                         ; bf8c3f7d
	v_add_f32_e32 v40, v8, v9                                   ; 02501308
	s_waitcnt vmcnt(12)                                         ; bf8c3f7c
	v_add_f32_e32 v41, v12, v13                                 ; 02521b0c
	s_waitcnt vmcnt(11)                                         ; bf8c3f7b
	v_add_f32_e32 v42, v16, v17                                 ; 02542310
	v_add_f32_e32 v40, v40, v10                                 ; 02501528
	v_add_f32_e32 v41, v41, v14                                 ; 02521d29
	s_waitcnt vmcnt(10)                                         ; bf8c3f7a
	v_add_f32_e32 v43, v20, v21                                 ; 02562b14
	v_add_f32_e32 v42, v42, v18                                 ; 0254252a
	v_add_f32_e32 v40, v40, v11                                 ; 02501728
	v_add_f32_e32 v41, v41, v15                                 ; 02521f29
	v_add_f32_e32 v43, v43, v22                                 ; 02562d2b
	v_add_f32_e32 v42, v42, v19                                 ; 0254272a
	v_add_f32_e32 v43, v43, v23                                 ; 02562f2b
	s_waitcnt vmcnt(9)                                          ; bf8c3f79
	v_cvt_f32_f16_sdwa v44, v24 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e5816f9 00050618
	v_cvt_f32_f16_e32 v24, v24                                  ; 7e301718
	s_waitcnt vmcnt(8)                                          ; bf8c3f78
	v_alignbyte_b32 v6, v7, v6, v30                             ; d1cf0006 047a0d07
	v_alignbyte_b32 v7, v7, v7, v30                             ; d1cf0007 047a0f07
	s_waitcnt vmcnt(7)                                          ; bf8c3f77
	v_lshl_or_b32 v27, v27, 12, v27                             ; d200001b 046d191b
	v_mov_b32_sdwa v6, v7 dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_0 ; 7e0c02f9 00041507
	v_and_b32_e32 v45, 0xc0c0c0c0, v6                           ; 265a0cff c0c0c0c0
	v_and_b32_e32 v6, 0x3f3f3f3f, v6                            ; 260c0cff 3f3f3f3f
	v_lshrrev_b32_e32 v45, 2, v45                               ; 205a5a82
	s_waitcnt vmcnt(6)                                          ; bf8c3f76
	v_and_b32_e32 v36, s5, v33                                  ; 26484205
	v_cvt_f32_ubyte1_e32 v25, v6                                ; 7e322506
	v_cvt_f32_ubyte3_e32 v46, v6                                ; 7e5c2906
	v_cvt_f32_ubyte2_e32 v7, v6                                 ; 7e0e2706
	v_cvt_f32_ubyte0_e32 v6, v6                                 ; 7e0c2306
	v_and_or_b32 v27, s5, v27, v45                              ; d201001b 04b63605
	v_cvt_f32_ubyte2_e32 v45, v36                               ; 7e5a2724
	v_cvt_f32_ubyte2_e32 v31, v27                               ; 7e3e271b
	v_cvt_f32_ubyte3_e32 v30, v27                               ; 7e3c291b
	v_cvt_f32_ubyte1_e32 v34, v27                               ; 7e44251b
	v_cvt_f32_ubyte0_e32 v27, v27                               ; 7e36231b
	v_lshrrev_b32_e32 v33, 4, v33                               ; 20424284
	v_mul_f32_e32 v30, v43, v30                                 ; 0a3c3d2b
	v_and_b32_e32 v33, s5, v33                                  ; 26424205
	v_mac_f32_e32 v30, v42, v31                                 ; 2c3c3f2a
	v_mac_f32_e32 v30, v41, v46                                 ; 2c3c5d29
	v_cvt_f32_ubyte1_e32 v46, v36                               ; 7e5c2524
	v_mac_f32_e32 v30, v40, v7                                  ; 2c3c0f28
	v_cvt_f32_ubyte2_e32 v7, v33                                ; 7e0e2721
	s_waitcnt vmcnt(5)                                          ; bf8c3f75
	v_and_b32_e32 v31, s5, v32                                  ; 263e4005
	v_mad_f32 v3, -v44, v30, v3                                 ; d1c10003 240e3d2c
	v_cvt_f32_ubyte3_e32 v44, v36                               ; 7e582924
	v_cvt_f32_ubyte0_e32 v36, v36                               ; 7e482324
	v_cvt_f32_ubyte1_e32 v30, v33                               ; 7e3c2521
	v_mul_f32_e32 v44, v11, v44                                 ; 0a58590b
	v_mac_f32_e32 v44, v10, v45                                 ; 2c585b0a
	v_cvt_f32_ubyte1_e32 v45, v31                               ; 7e5a251f
	v_mac_f32_e32 v44, v9, v46                                  ; 2c585d09
	v_cvt_f32_ubyte3_e32 v46, v33                               ; 7e5c2921
	v_cvt_f32_ubyte0_e32 v33, v33                               ; 7e422321
	v_lshrrev_b32_e32 v32, 4, v32                               ; 20404084
	v_mac_f32_e32 v44, v8, v36                                  ; 2c584908
	v_cvt_f32_ubyte2_e32 v36, v31                               ; 7e48271f
	v_mul_f32_e32 v46, v15, v46                                 ; 0a5c5d0f
	v_and_b32_e32 v32, s5, v32                                  ; 26404005
	v_mac_f32_e32 v46, v14, v7                                  ; 2c5c0f0e
	v_cvt_f32_ubyte3_e32 v7, v32                                ; 7e0e2920
	v_mac_f32_e32 v46, v13, v30                                 ; 2c5c3d0d
	v_cvt_f32_ubyte2_e32 v30, v32                               ; 7e3c2720
	v_mul_f32_e32 v7, v23, v7                                   ; 0a0e0f17
	v_mac_f32_e32 v46, v12, v33                                 ; 2c5c430c
	v_cvt_f32_ubyte3_e32 v33, v31                               ; 7e42291f
	v_cvt_f32_ubyte0_e32 v31, v31                               ; 7e3e231f
	v_mac_f32_e32 v7, v22, v30                                  ; 2c0e3d16
	v_mul_f32_e32 v33, v19, v33                                 ; 0a424313
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_alignbyte_b32 v28, v29, v28, v26                          ; d1cf001c 046a391d
	v_alignbyte_b32 v29, v29, v29, v26                          ; d1cf001d 046a3b1d
	v_mac_f32_e32 v33, v18, v36                                 ; 2c424912
	v_mov_b32_sdwa v28, v29 dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_0 ; 7e3802f9 0004151d
	v_mac_f32_e32 v33, v17, v45                                 ; 2c425b11
	v_mac_f32_e32 v33, v16, v31                                 ; 2c423f10
	v_cvt_f32_ubyte1_e32 v31, v32                               ; 7e3e2520
	v_cvt_f32_ubyte0_e32 v32, v32                               ; 7e402320
	v_mac_f32_e32 v7, v21, v31                                  ; 2c0e3f15
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_lshl_or_b32 v37, v37, 12, v37                             ; d2000025 04951925
	v_mac_f32_e32 v7, v20, v32                                  ; 2c0e4114
	v_cvt_f32_f16_sdwa v32, v35 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e4016f9 00050623
	v_cvt_f32_f16_e32 v35, v35                                  ; 7e461723
	v_mul_f32_e32 v7, v7, v34                                   ; 0a0e4507
	v_mac_f32_e32 v7, v33, v27                                  ; 2c0e3721
	v_and_b32_e32 v33, 0xc0c0c0c0, v28                          ; 264238ff c0c0c0c0
	v_and_b32_e32 v28, 0x3f3f3f3f, v28                          ; 263838ff 3f3f3f3f
	v_mac_f32_e32 v7, v46, v25                                  ; 2c0e332e
	v_lshrrev_b32_e32 v33, 2, v33                               ; 20424282
	v_cvt_f32_ubyte2_e32 v36, v28                               ; 7e48271c
	v_cvt_f32_ubyte3_e32 v34, v28                               ; 7e44291c
	v_mac_f32_e32 v7, v44, v6                                   ; 2c0e0d2c
	v_cvt_f32_ubyte1_e32 v44, v28                               ; 7e58251c
	v_cvt_f32_ubyte0_e32 v28, v28                               ; 7e38231c
	v_and_or_b32 v37, s5, v37, v33                              ; d2010025 04864a05
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v6, s5, v39                                   ; 260c4e05
	v_mac_f32_e32 v3, v24, v7                                   ; 2c060f18
	v_cvt_f32_ubyte3_e32 v45, v37                               ; 7e5a2925
	v_cvt_f32_ubyte2_e32 v46, v37                               ; 7e5c2725
	v_cvt_f32_ubyte2_e32 v24, v6                                ; 7e302706
	v_cvt_f32_ubyte1_e32 v25, v6                                ; 7e322506
	v_cvt_f32_ubyte3_e32 v7, v6                                 ; 7e0e2906
	v_cvt_f32_ubyte0_e32 v6, v6                                 ; 7e0c2306
	v_lshrrev_b32_e32 v39, 4, v39                               ; 204e4e84
	v_mul_f32_e32 v43, v43, v45                                 ; 0a565b2b
	v_mul_f32_e32 v11, v11, v7                                  ; 0a160f0b
	v_and_b32_e32 v39, s5, v39                                  ; 264e4e05
	v_mac_f32_e32 v43, v42, v46                                 ; 2c565d2a
	v_cvt_f32_ubyte1_e32 v46, v37                               ; 7e5c2525
	v_cvt_f32_ubyte0_e32 v37, v37                               ; 7e4a2325
	v_mac_f32_e32 v11, v10, v24                                 ; 2c16310a
	v_cvt_f32_ubyte3_e32 v26, v39                               ; 7e342927
	v_cvt_f32_ubyte1_e32 v29, v39                               ; 7e3a2527
	v_cvt_f32_ubyte2_e32 v27, v39                               ; 7e362727
	v_cvt_f32_ubyte0_e32 v39, v39                               ; 7e4e2327
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v30, s5, v38                                  ; 263c4c05
	v_mac_f32_e32 v43, v41, v34                                 ; 2c564529
	v_mac_f32_e32 v11, v9, v25                                  ; 2c163309
	v_mul_f32_e32 v15, v15, v26                                 ; 0a1e350f
	v_cvt_f32_ubyte1_e32 v33, v30                               ; 7e42251e
	v_cvt_f32_ubyte3_e32 v31, v30                               ; 7e3e291e
	v_mac_f32_e32 v43, v40, v36                                 ; 2c564928
	v_lshrrev_b32_e32 v38, 4, v38                               ; 204c4c84
	v_mac_f32_e32 v11, v8, v6                                   ; 2c160d08
	v_mac_f32_e32 v15, v14, v27                                 ; 2c1e370e
	v_mul_f32_e32 v19, v19, v31                                 ; 0a263f13
	v_mad_f32 v5, -v32, v43, v5                                 ; d1c10005 24165720
	v_cvt_f32_ubyte2_e32 v32, v30                               ; 7e40271e
	v_cvt_f32_ubyte0_e32 v30, v30                               ; 7e3c231e
	v_and_b32_e32 v38, s5, v38                                  ; 264c4c05
	v_mac_f32_e32 v15, v13, v29                                 ; 2c1e3b0d
	v_mac_f32_e32 v19, v18, v32                                 ; 2c264112
	v_cvt_f32_ubyte2_e32 v36, v38                               ; 7e482726
	v_cvt_f32_ubyte3_e32 v34, v38                               ; 7e442926
	v_mac_f32_e32 v15, v12, v39                                 ; 2c1e4f0c
	v_cvt_f32_ubyte1_e32 v39, v38                               ; 7e4e2526
	v_cvt_f32_ubyte0_e32 v38, v38                               ; 7e4c2326
	v_mac_f32_e32 v19, v17, v33                                 ; 2c264311
	v_mul_f32_e32 v23, v23, v34                                 ; 0a2e4517
	v_mac_f32_e32 v19, v16, v30                                 ; 2c263d10
	v_mac_f32_e32 v23, v22, v36                                 ; 2c2e4916
	v_mac_f32_e32 v23, v21, v39                                 ; 2c2e4f15
	v_mac_f32_e32 v23, v20, v38                                 ; 2c2e4d14
	v_mul_f32_e32 v23, v23, v46                                 ; 0a2e5d17
	v_mac_f32_e32 v23, v19, v37                                 ; 2c2e4b13
	v_mac_f32_e32 v23, v15, v44                                 ; 2c2e590f
	v_mac_f32_e32 v23, v11, v28                                 ; 2c2e390b
	v_mac_f32_e32 v5, v35, v23                                  ; 2c0a2f23
BB5:
	s_mov_b64 s[0:1], exec                                      ; be80017e
	v_cmpx_le_u32_e32 vcc, s3, v0                               ; 7db60003
BB6:
	s_andn2_b64 s[0:1], s[0:1], exec                            ; 89807e00
	s_cbranch_scc1 BB10                                         ; bf85fefe
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
	s_branch BB77                                               ; bf8201ed
BB30:
	s_cmp_lt_u32 s16, s4                                        ; bf0a0410
	s_cbranch_scc0 BB77                                         ; bf8401eb
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
	s_nop 0                                                     ; bf800000
	(then repeated 2 times)
BB35:
	s_mov_b64 s[0:1], exec                                      ; be80017e
	v_cmpx_le_u32_e32 vcc, s3, v0                               ; 7db60003
BB36:
	s_andn2_b64 s[0:1], s[0:1], exec                            ; 89807e00
	s_cbranch_scc0 BB47                                         ; bf840109
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
	s_cbranch_scc0 BB46                                         ; bf8400dc
BB41:
	s_load_dwordx4 s[12:15], s[0:1], 0x0                        ; c00a0300 00000000
	s_mul_i32 s0, s16, s3                                       ; 92000310
	v_lshlrev_b32_e32 v28, 1, v2                                ; 24380481
	v_add_u32_e32 v36, 64, v4                                   ; 684808c0
	s_add_u32 s0, s19, s0                                       ; 80000013
	v_and_b32_e32 v30, -4, v28                                  ; 263c38c4
	v_add_u32_e32 v33, 8, v28                                   ; 68423888
	v_add_u32_e32 v6, s0, v0                                    ; 680c0000
	v_lshlrev_b32_e32 v7, 4, v6                                 ; 240e0c84
	v_lshl_add_u32 v6, v6, 7, v7                                ; d1fd0006 041d0f06
	v_add_u32_e32 v29, 4, v6                                    ; 683a0c84
	v_add_u32_e32 v34, 16, v6                                   ; 68440c90
	v_add_u32_e32 v31, v30, v29                                 ; 683e3b1e
	v_add_u32_e32 v32, v29, v28                                 ; 6840391d
	v_add_u32_e32 v29, v29, v33                                 ; 683a431d
	v_add_u32_e32 v35, v34, v4                                  ; 68460922
	v_add_u32_e32 v34, v34, v36                                 ; 68444922
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_load_dword v6, v6, s[12:15], 0 offen                 ; e0501000 80030606
	buffer_load_dwordx2 v[38:39], v31, s[12:15], 0 offen        ; e0541000 8003261f
	buffer_load_ushort v29, v29, s[12:15], 0 offen              ; e0481000 80031d1d
	buffer_load_dword v35, v35, s[12:15], 0 offen               ; e0501000 80032323
	buffer_load_dword v34, v34, s[12:15], 0 offen               ; e0501000 80032222
	s_mov_b32 s1, 0xf0f0f0f                                     ; be8100ff 0f0f0f0f
	s_cmp_lt_u32 1, s4                                          ; bf0a0481
	s_waitcnt vmcnt(4)                                          ; bf8c3f74
	v_cvt_f32_f16_sdwa v37, v6 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e4a16f9 00050606
	v_cvt_f32_f16_e32 v6, v6                                    ; 7e0c1706
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_alignbyte_b32 v38, v39, v38, v32                          ; d1cf0026 04824d27
	v_alignbyte_b32 v39, v39, v39, v32                          ; d1cf0027 04824f27
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_lshl_or_b32 v29, v29, 12, v29                             ; d200001d 0475191d
	v_mov_b32_sdwa v38, v39 dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_0 ; 7e4c02f9 00041527
	v_and_b32_e32 v39, 0xc0c0c0c0, v38                          ; 264e4cff c0c0c0c0
	v_and_b32_e32 v38, 0x3f3f3f3f, v38                          ; 264c4cff 3f3f3f3f
	v_lshrrev_b32_e32 v39, 2, v39                               ; 204e4e82
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v46, s1, v35                                  ; 265c4601
	v_cvt_f32_ubyte3_e32 v40, v38                               ; 7e502926
	v_cvt_f32_ubyte2_e32 v41, v38                               ; 7e522726
	v_cvt_f32_ubyte1_e32 v42, v38                               ; 7e542526
	v_cvt_f32_ubyte0_e32 v38, v38                               ; 7e4c2326
	v_and_or_b32 v29, s1, v29, v39                              ; d201001d 049e3a01
	v_cvt_f32_ubyte2_e32 v31, v46                               ; 7e3e272e
	v_cvt_f32_ubyte3_e32 v7, v46                                ; 7e0e292e
	v_cvt_f32_ubyte1_e32 v32, v46                               ; 7e40252e
	v_cvt_f32_ubyte0_e32 v46, v46                               ; 7e5c232e
	v_cvt_f32_ubyte1_e32 v45, v29                               ; 7e5a251d
	v_cvt_f32_ubyte2_e32 v44, v29                               ; 7e58271d
	v_cvt_f32_ubyte3_e32 v43, v29                               ; 7e56291d
	v_cvt_f32_ubyte0_e32 v29, v29                               ; 7e3a231d
	v_lshrrev_b32_e32 v35, 4, v35                               ; 20464684
	v_mul_f32_e32 v7, v11, v7                                   ; 0a0e0f0b
	v_mul_f32_e32 v43, v27, v43                                 ; 0a56571b
	v_and_b32_e32 v35, s1, v35                                  ; 26464601
	v_mac_f32_e32 v7, v10, v31                                  ; 2c0e3f0a
	v_mac_f32_e32 v43, v26, v44                                 ; 2c56591a
	v_cvt_f32_ubyte2_e32 v39, v35                               ; 7e4e2723
	v_mac_f32_e32 v7, v9, v32                                   ; 2c0e4109
	v_mac_f32_e32 v43, v25, v40                                 ; 2c565119
	v_cvt_f32_ubyte1_e32 v40, v35                               ; 7e502523
	v_mac_f32_e32 v7, v8, v46                                   ; 2c0e5d08
	v_mac_f32_e32 v43, v24, v41                                 ; 2c565318
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v41, s1, v34                                  ; 26524401
	v_lshrrev_b32_e32 v34, 4, v34                               ; 20444484
	v_mad_f32 v3, -v37, v43, v3                                 ; d1c10003 240e5725
	v_cvt_f32_ubyte3_e32 v37, v35                               ; 7e4a2923
	v_cvt_f32_ubyte0_e32 v35, v35                               ; 7e462323
	v_cvt_f32_ubyte3_e32 v43, v41                               ; 7e562929
	v_cvt_f32_ubyte2_e32 v44, v41                               ; 7e582729
	v_cvt_f32_ubyte1_e32 v46, v41                               ; 7e5c2529
	v_cvt_f32_ubyte0_e32 v41, v41                               ; 7e522329
	v_and_b32_e32 v34, s1, v34                                  ; 26444401
	v_mul_f32_e32 v37, v15, v37                                 ; 0a4a4b0f
	v_mul_f32_e32 v43, v19, v43                                 ; 0a565713
	v_cvt_f32_ubyte1_e32 v32, v34                               ; 7e402522
	v_cvt_f32_ubyte2_e32 v31, v34                               ; 7e3e2722
	v_mac_f32_e32 v37, v14, v39                                 ; 2c4a4f0e
	v_mac_f32_e32 v43, v18, v44                                 ; 2c565912
	v_mac_f32_e32 v37, v13, v40                                 ; 2c4a510d
	v_mac_f32_e32 v43, v17, v46                                 ; 2c565d11
	v_cvt_f32_ubyte3_e32 v46, v34                               ; 7e5c2922
	v_cvt_f32_ubyte0_e32 v34, v34                               ; 7e442322
	v_mac_f32_e32 v37, v12, v35                                 ; 2c4a470c
	v_mac_f32_e32 v43, v16, v41                                 ; 2c565310
	v_mul_f32_e32 v46, v23, v46                                 ; 0a5c5d17
	v_mac_f32_e32 v46, v22, v31                                 ; 2c5c3f16
	v_mac_f32_e32 v46, v21, v32                                 ; 2c5c4115
	v_mac_f32_e32 v46, v20, v34                                 ; 2c5c4514
	v_mul_f32_e32 v46, v46, v45                                 ; 0a5c5b2e
	v_mac_f32_e32 v46, v43, v29                                 ; 2c5c3b2b
	v_mac_f32_e32 v46, v37, v42                                 ; 2c5c5525
	v_mac_f32_e32 v46, v7, v38                                  ; 2c5c4d07
	v_mac_f32_e32 v3, v6, v46                                   ; 2c065d06
	s_cbranch_scc0 BB46                                         ; bf84006a
BB42:
	s_add_u32 s0, s16, 1                                        ; 80008110
	s_mul_i32 s0, s0, s3                                        ; 92000300
	s_add_u32 s0, s19, s0                                       ; 80000013
	v_add_u32_e32 v6, s0, v0                                    ; 680c0000
	v_lshlrev_b32_e32 v7, 4, v6                                 ; 240e0c84
	v_lshl_add_u32 v6, v6, 7, v7                                ; d1fd0006 041d0f06
	v_add_u32_e32 v29, 4, v6                                    ; 683a0c84
	v_add_u32_e32 v31, 16, v6                                   ; 683e0c90
	v_add_u32_e32 v30, v30, v29                                 ; 683c3b1e
	v_add_u32_e32 v28, v29, v28                                 ; 6838391d
	v_add_u32_e32 v29, v29, v33                                 ; 683a431d
	v_add_u32_e32 v32, v31, v4                                  ; 6840091f
	v_add_u32_e32 v31, v31, v36                                 ; 683e491f
	buffer_load_dword v6, v6, s[12:15], 0 offen                 ; e0501000 80030606
	buffer_load_dwordx2 v[34:35], v30, s[12:15], 0 offen        ; e0541000 8003221e
	buffer_load_ushort v29, v29, s[12:15], 0 offen              ; e0481000 80031d1d
	buffer_load_dword v32, v32, s[12:15], 0 offen               ; e0501000 80032020
	buffer_load_dword v31, v31, s[12:15], 0 offen               ; e0501000 80031f1f
	s_mov_b32 s1, 0xf0f0f0f                                     ; be8100ff 0f0f0f0f
	s_waitcnt vmcnt(4)                                          ; bf8c3f74
	v_cvt_f32_f16_sdwa v33, v6 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e4216f9 00050606
	v_cvt_f32_f16_e32 v6, v6                                    ; 7e0c1706
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_alignbyte_b32 v34, v35, v34, v28                          ; d1cf0022 04724523
	v_alignbyte_b32 v35, v35, v35, v28                          ; d1cf0023 04724723
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_lshl_or_b32 v29, v29, 12, v29                             ; d200001d 0475191d
	v_mov_b32_sdwa v34, v35 dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_0 ; 7e4402f9 00041523
	v_and_b32_e32 v35, 0xc0c0c0c0, v34                          ; 264644ff c0c0c0c0
	v_and_b32_e32 v34, 0x3f3f3f3f, v34                          ; 264444ff 3f3f3f3f
	v_lshrrev_b32_e32 v35, 2, v35                               ; 20464682
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v42, s1, v32                                  ; 26544001
	v_cvt_f32_ubyte3_e32 v36, v34                               ; 7e482922
	v_cvt_f32_ubyte2_e32 v37, v34                               ; 7e4a2722
	v_cvt_f32_ubyte1_e32 v38, v34                               ; 7e4c2522
	v_cvt_f32_ubyte0_e32 v34, v34                               ; 7e442322
	v_and_or_b32 v29, s1, v29, v35                              ; d201001d 048e3a01
	v_cvt_f32_ubyte3_e32 v43, v42                               ; 7e56292a
	v_cvt_f32_ubyte2_e32 v44, v42                               ; 7e58272a
	v_cvt_f32_ubyte1_e32 v45, v42                               ; 7e5a252a
	v_cvt_f32_ubyte0_e32 v42, v42                               ; 7e54232a
	v_cvt_f32_ubyte3_e32 v39, v29                               ; 7e4e291d
	v_cvt_f32_ubyte2_e32 v40, v29                               ; 7e50271d
	v_cvt_f32_ubyte1_e32 v41, v29                               ; 7e52251d
	v_cvt_f32_ubyte0_e32 v29, v29                               ; 7e3a231d
	v_mul_f32_e32 v11, v11, v43                                 ; 0a16570b
	v_lshrrev_b32_e32 v32, 4, v32                               ; 20404084
	v_mul_f32_e32 v27, v27, v39                                 ; 0a364f1b
	v_mac_f32_e32 v11, v10, v44                                 ; 2c16590a
	v_and_b32_e32 v32, s1, v32                                  ; 26404001
	v_mac_f32_e32 v27, v26, v40                                 ; 2c36511a
	v_mac_f32_e32 v11, v9, v45                                  ; 2c165b09
	v_cvt_f32_ubyte3_e32 v46, v32                               ; 7e5c2920
	v_mac_f32_e32 v27, v25, v36                                 ; 2c364919
	v_mac_f32_e32 v11, v8, v42                                  ; 2c165508
	v_mul_f32_e32 v15, v15, v46                                 ; 0a1e5d0f
	v_cvt_f32_ubyte2_e32 v46, v32                               ; 7e5c2720
	v_mac_f32_e32 v27, v24, v37                                 ; 2c364b18
	v_mac_f32_e32 v15, v14, v46                                 ; 2c1e5d0e
	v_cvt_f32_ubyte1_e32 v46, v32                               ; 7e5c2520
	v_cvt_f32_ubyte0_e32 v32, v32                               ; 7e402320
	v_mad_f32 v5, -v33, v27, v5                                 ; d1c10005 24163721
	v_mac_f32_e32 v15, v13, v46                                 ; 2c1e5d0d
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v46, s1, v31                                  ; 265c3e01
	v_lshrrev_b32_e32 v31, 4, v31                               ; 203e3e84
	v_mac_f32_e32 v15, v12, v32                                 ; 2c1e410c
	v_cvt_f32_ubyte1_e32 v9, v46                                ; 7e12252e
	v_cvt_f32_ubyte3_e32 v7, v46                                ; 7e0e292e
	v_cvt_f32_ubyte2_e32 v8, v46                                ; 7e10272e
	v_cvt_f32_ubyte0_e32 v46, v46                               ; 7e5c232e
	v_and_b32_e32 v31, s1, v31                                  ; 263e3e01
	v_mul_f32_e32 v19, v19, v7                                  ; 0a260f13
	v_cvt_f32_ubyte2_e32 v12, v31                               ; 7e18271f
	v_cvt_f32_ubyte3_e32 v10, v31                               ; 7e14291f
	v_cvt_f32_ubyte1_e32 v13, v31                               ; 7e1a251f
	v_cvt_f32_ubyte0_e32 v31, v31                               ; 7e3e231f
	v_mac_f32_e32 v19, v18, v8                                  ; 2c261112
	v_mul_f32_e32 v23, v23, v10                                 ; 0a2e1517
	v_mac_f32_e32 v19, v17, v9                                  ; 2c261311
	v_mac_f32_e32 v23, v22, v12                                 ; 2c2e1916
	v_mac_f32_e32 v19, v16, v46                                 ; 2c265d10
	v_mac_f32_e32 v23, v21, v13                                 ; 2c2e1b15
	v_mac_f32_e32 v23, v20, v31                                 ; 2c2e3f14
	v_mul_f32_e32 v23, v23, v41                                 ; 0a2e5317
	v_mac_f32_e32 v23, v19, v29                                 ; 2c2e3b13
	v_mac_f32_e32 v23, v15, v38                                 ; 2c2e4d0f
	v_mac_f32_e32 v23, v11, v34                                 ; 2c2e450b
	v_mac_f32_e32 v5, v6, v23                                   ; 2c0a2f06
BB46:
	v_add_u32_e32 v0, 4, v0                                     ; 68000084
	s_branch BB35                                               ; bf82fef3
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
