BB0:
	s_load_dword s0, s[14:15], 0x0                              ; c0020007 00000000
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_mul_i32 s0, s0, s18                                       ; 92001200
	s_add_u32 s16, s16, s0                                      ; 80100010
	s_lshl_b32 s16, s16, 4                                      ; 8e108410
	s_add_u32 s1, s16, 16                                       ; 80019010
	s_cmp_ge_u32 s4, s1                                         ; bf090104
	s_cbranch_scc0 BB114                                        ; bf840a70
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
	v_mov_b32_e32 v8, 0                                         ; 7e100280
	v_mov_b32_e32 v9, 0                                         ; 7e120280
	v_sub_u32_e32 v1, v2, v1                                    ; 6a020302
	v_bfe_u32 v3, v2, 2, 1                                      ; d1c80003 02050502
	v_lshrrev_b32_e32 v2, 3, v2                                 ; 20040483
	v_mov_b32_e32 v10, 0                                        ; 7e140280
	v_mov_b32_e32 v11, 0                                        ; 7e160280
	v_mov_b32_e32 v12, 0                                        ; 7e180280
	v_mov_b32_e32 v13, 0                                        ; 7e1a0280
	v_mov_b32_e32 v14, 0                                        ; 7e1c0280
	v_mov_b32_e32 v15, 0                                        ; 7e1e0280
	v_mov_b32_e32 v16, 0                                        ; 7e200280
	v_mov_b32_e32 v17, 0                                        ; 7e220280
	v_mov_b32_e32 v18, 0                                        ; 7e240280
	v_mov_b32_e32 v19, 0                                        ; 7e260280
	v_lshl_add_u32 v1, v1, 1, v3                                ; d1fd0001 040d0301
	v_mov_b32_e32 v3, 0                                         ; 7e060280
	v_lshlrev_b32_e32 v1, 2, v1                                 ; 24020282
	v_lshl_add_u32 v4, v2, 5, v1                                ; d1fd0004 04050b02
	v_lshl_add_u32 v1, v2, 6, v1                                ; d1fd0001 04050d02
	s_branch BB5                                                ; bf820687
BB10:
	s_mov_b64 exec, s[0:1]                                      ; befe0100
	s_mov_b32 s0, s2                                            ; be800002
	s_movk_i32 s1, 0x8000                                       ; b0018000
	s_load_dwordx8 s[24:31], s[0:1], 0x0                        ; c00e0600 00000000
	s_mul_i32 s0, s6, s17                                       ; 92001106
	v_lshl_add_u32 v20, v0, 8, v1                               ; d1fd0014 04051100
	v_add_u32_e32 v21, s0, v20                                  ; 682a2800
	v_add_u32_e32 v20, 0x80, v20                                ; 682828ff 00000080
	v_lshrrev_b32_e32 v21, 2, v21                               ; 202a2a82
	v_add_u32_e32 v20, s0, v20                                  ; 68282800
	v_lshlrev_b32_e32 v21, 4, v21                               ; 242a2a84
	v_lshrrev_b32_e32 v20, 2, v20                               ; 20282882
	v_lshlrev_b32_e32 v20, 4, v20                               ; 24282884
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_load_dwordx4 v[24:27], v21, s[28:31], 0 offen        ; e05c1000 80071815
	buffer_load_dwordx4 v[28:31], v21, s[28:31], 0 offen offset:128 ; e05c1080 80071c15
	buffer_load_dwordx4 v[32:35], v20, s[28:31], 0 offen        ; e05c1000 80072014
	buffer_load_dwordx4 v[20:23], v20, s[28:31], 0 offen offset:128 ; e05c1080 80071414
	s_mul_i32 s1, s16, s3                                       ; 92010310
	v_lshlrev_b32_e32 v38, 1, v2                                ; 244c0481
	v_add_u32_e32 v46, 64, v4                                   ; 685c08c0
	s_add_u32 s1, s18, s1                                       ; 80010112
	s_add_u32 s4, s16, 1                                        ; 80048110
	v_and_b32_e32 v40, -4, v38                                  ; 26504cc4
	v_add_u32_e32 v43, 8, v38                                   ; 68564c88
	v_add_u32_e32 v36, s1, v0                                   ; 68480001
	s_mul_i32 s4, s4, s3                                        ; 92040304
	v_lshlrev_b32_e32 v37, 4, v36                               ; 244a4884
	s_add_u32 s4, s18, s4                                       ; 80040412
	v_lshl_add_u32 v36, v36, 7, v37                             ; d1fd0024 04950f24
	v_add_u32_e32 v47, s4, v0                                   ; 685e0004
	v_add_u32_e32 v39, 4, v36                                   ; 684e4884
	v_add_u32_e32 v44, 16, v36                                  ; 68584890
	v_lshlrev_b32_e32 v48, 4, v47                               ; 24605e84
	v_add_u32_e32 v42, v39, v38                                 ; 68544d27
	v_add_u32_e32 v41, v40, v39                                 ; 68524f28
	v_add_u32_e32 v39, v39, v43                                 ; 684e5727
	v_add_u32_e32 v45, v44, v4                                  ; 685a092c
	v_add_u32_e32 v44, v44, v46                                 ; 68585d2c
	v_lshl_add_u32 v47, v47, 7, v48                             ; d1fd002f 04c10f2f
	v_add_u32_e32 v49, 4, v47                                   ; 68625e84
	v_add_u32_e32 v52, 16, v47                                  ; 68685e90
	v_add_u32_e32 v50, v40, v49                                 ; 68646328
	v_add_u32_e32 v51, v49, v38                                 ; 68664d31
	v_add_u32_e32 v49, v49, v43                                 ; 68625731
	v_add_u32_e32 v53, v52, v4                                  ; 686a0934
	v_add_u32_e32 v52, v52, v46                                 ; 68685d34
	buffer_load_dword v36, v36, s[24:27], 0 offen               ; e0501000 80062424
	buffer_load_dwordx2 v[54:55], v41, s[24:27], 0 offen        ; e0541000 80063629
	buffer_load_ushort v39, v39, s[24:27], 0 offen              ; e0481000 80062727
	buffer_load_dword v45, v45, s[24:27], 0 offen               ; e0501000 80062d2d
	buffer_load_dword v44, v44, s[24:27], 0 offen               ; e0501000 80062c2c
	buffer_load_dword v47, v47, s[24:27], 0 offen               ; e0501000 80062f2f
	buffer_load_dwordx2 v[56:57], v50, s[24:27], 0 offen        ; e0541000 80063832
	buffer_load_ushort v49, v49, s[24:27], 0 offen              ; e0481000 80063131
	buffer_load_dword v53, v53, s[24:27], 0 offen               ; e0501000 80063535
	buffer_load_dword v52, v52, s[24:27], 0 offen               ; e0501000 80063434
	s_mov_b32 s5, 0xf0f0f0f                                     ; be8500ff 0f0f0f0f
	s_mov_b32 s9, 0xc0c0c0c0                                    ; be8900ff c0c0c0c0
	s_mov_b32 s10, 0x3f3f3f3f                                   ; be8a00ff 3f3f3f3f
	s_add_u32 s11, s16, 2                                       ; 800b8210
	s_mul_i32 s11, s11, s3                                      ; 920b030b
	s_add_u32 s11, s18, s11                                     ; 800b0b12
	v_add_u32_e32 v58, s11, v0                                  ; 6874000b
	s_waitcnt vmcnt(13)                                         ; bf8c3f7d
	v_add_f32_e32 v59, v24, v25                                 ; 02763318
	s_waitcnt vmcnt(12)                                         ; bf8c3f7c
	v_add_f32_e32 v60, v28, v29                                 ; 02783b1c
	s_waitcnt vmcnt(11)                                         ; bf8c3f7b
	v_add_f32_e32 v61, v32, v33                                 ; 027a4320
	v_add_f32_e32 v59, v59, v26                                 ; 0276353b
	v_add_f32_e32 v60, v60, v30                                 ; 02783d3c
	s_waitcnt vmcnt(10)                                         ; bf8c3f7a
	v_add_f32_e32 v62, v20, v21                                 ; 027c2b14
	v_add_f32_e32 v61, v61, v34                                 ; 027a453d
	v_add_f32_e32 v59, v59, v27                                 ; 0276373b
	v_add_f32_e32 v60, v60, v31                                 ; 02783f3c
	v_add_f32_e32 v62, v62, v22                                 ; 027c2d3e
	v_add_f32_e32 v61, v61, v35                                 ; 027a473d
	v_add_f32_e32 v62, v62, v23                                 ; 027c2f3e
	s_waitcnt vmcnt(8)                                          ; bf8c3f78
	v_alignbyte_b32 v54, v55, v54, v42                          ; d1cf0036 04aa6d37
	v_alignbyte_b32 v55, v55, v55, v42                          ; d1cf0037 04aa6f37
	s_waitcnt vmcnt(7)                                          ; bf8c3f77
	v_lshl_or_b32 v39, v39, 12, v39                             ; d2000027 049d1927
	s_waitcnt vmcnt(6)                                          ; bf8c3f76
	v_and_b32_e32 v41, s5, v45                                  ; 26525a05
	v_lshrrev_b32_e32 v45, 4, v45                               ; 205a5a84
	v_mov_b32_sdwa v54, v55 dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_0 ; 7e6c02f9 00041537
	v_cvt_f32_ubyte1_e32 v50, v41                               ; 7e642529
	v_cvt_f32_ubyte2_e32 v48, v41                               ; 7e602729
	v_cvt_f32_ubyte3_e32 v42, v41                               ; 7e542929
	v_cvt_f32_ubyte0_e32 v41, v41                               ; 7e522329
	v_and_b32_e32 v45, s5, v45                                  ; 265a5a05
	v_and_b32_e32 v37, s9, v54                                  ; 264a6c09
	v_and_b32_e32 v54, s10, v54                                 ; 266c6c0a
	v_mul_f32_e32 v42, v27, v42                                 ; 0a54551b
	v_cvt_f32_ubyte3_e32 v55, v45                               ; 7e6e292d
	v_lshrrev_b32_e32 v37, 2, v37                               ; 204a4a82
	v_mac_f32_e32 v42, v26, v48                                 ; 2c54611a
	v_mul_f32_e32 v55, v31, v55                                 ; 0a6e6f1f
	v_and_or_b32 v39, s5, v39, v37                              ; d2010027 04964e05
	v_cvt_f32_ubyte2_e32 v37, v45                               ; 7e4a272d
	v_mac_f32_e32 v42, v25, v50                                 ; 2c546519
	v_mac_f32_e32 v55, v30, v37                                 ; 2c6e4b1e
	v_mac_f32_e32 v42, v24, v41                                 ; 2c545318
	v_cvt_f32_ubyte1_e32 v41, v45                               ; 7e52252d
	v_cvt_f32_ubyte0_e32 v45, v45                               ; 7e5a232d
	v_mac_f32_e32 v55, v29, v41                                 ; 2c6e531d
	v_mac_f32_e32 v55, v28, v45                                 ; 2c6e5b1c
	s_waitcnt vmcnt(5)                                          ; bf8c3f75
	v_and_b32_e32 v45, s5, v44                                  ; 265a5805
	v_lshrrev_b32_e32 v44, 4, v44                               ; 20585884
	v_cvt_f32_ubyte3_e32 v48, v45                               ; 7e60292d
	v_cvt_f32_ubyte2_e32 v50, v45                               ; 7e64272d
	v_cvt_f32_ubyte1_e32 v37, v45                               ; 7e4a252d
	v_cvt_f32_ubyte0_e32 v45, v45                               ; 7e5a232d
	v_and_b32_e32 v44, s5, v44                                  ; 26585805
	v_mul_f32_e32 v48, v35, v48                                 ; 0a606123
	v_cvt_f32_ubyte3_e32 v41, v44                               ; 7e52292c
	v_mac_f32_e32 v48, v34, v50                                 ; 2c606522
	v_cvt_f32_ubyte1_e32 v50, v44                               ; 7e64252c
	v_mul_f32_e32 v41, v23, v41                                 ; 0a525317
	v_mac_f32_e32 v48, v33, v37                                 ; 2c604b21
	v_cvt_f32_ubyte3_e32 v37, v39                               ; 7e4a2927
	v_mac_f32_e32 v48, v32, v45                                 ; 2c605b20
	v_cvt_f32_ubyte2_e32 v45, v44                               ; 7e5a272c
	v_cvt_f32_ubyte0_e32 v44, v44                               ; 7e58232c
	v_mul_f32_e32 v37, v62, v37                                 ; 0a4a4b3e
	v_mac_f32_e32 v41, v22, v45                                 ; 2c525b16
	v_cvt_f32_ubyte3_e32 v45, v54                               ; 7e5a2936
	v_mac_f32_e32 v41, v21, v50                                 ; 2c526515
	v_cvt_f32_ubyte2_e32 v50, v54                               ; 7e642736
	v_mac_f32_e32 v41, v20, v44                                 ; 2c525914
	v_cvt_f32_ubyte2_e32 v44, v39                               ; 7e582727
	v_mac_f32_e32 v37, v61, v44                                 ; 2c4a593d
	v_cvt_f32_ubyte1_e32 v44, v39                               ; 7e582527
	v_cvt_f32_ubyte0_e32 v39, v39                               ; 7e4e2327
	v_mac_f32_e32 v37, v60, v45                                 ; 2c4a5b3c
	v_lshlrev_b32_e32 v45, 4, v58                               ; 245a7484
	v_mul_f32_e32 v41, v41, v44                                 ; 0a525929
	v_mac_f32_e32 v37, v59, v50                                 ; 2c4a653b
	v_lshl_add_u32 v58, v58, 7, v45                             ; d1fd003a 04b50f3a
	v_mac_f32_e32 v41, v48, v39                                 ; 2c524f30
	v_cvt_f32_ubyte1_e32 v48, v54                               ; 7e602536
	v_cvt_f32_ubyte0_e32 v54, v54                               ; 7e6c2336
	v_add_u32_e32 v44, 16, v58                                  ; 68587490
	v_add_u32_e32 v50, 4, v58                                   ; 68647484
	v_mac_f32_e32 v41, v55, v48                                 ; 2c526137
	v_add_u32_e32 v45, v44, v4                                  ; 685a092c
	v_add_u32_e32 v44, v44, v46                                 ; 68585d2c
	v_add_u32_e32 v39, v50, v38                                 ; 684e4d32
	v_add_u32_e32 v55, v40, v50                                 ; 686e6528
	v_add_u32_e32 v50, v50, v43                                 ; 68645732
	v_mac_f32_e32 v41, v42, v54                                 ; 2c526d2a
	buffer_load_dword v58, v58, s[24:27], 0 offen               ; e0501000 80063a3a
	buffer_load_dwordx2 v[54:55], v55, s[24:27], 0 offen        ; e0541000 80063637
	buffer_load_ushort v50, v50, s[24:27], 0 offen              ; e0481000 80063232
	buffer_load_dword v45, v45, s[24:27], 0 offen               ; e0501000 80062d2d
	buffer_load_dword v44, v44, s[24:27], 0 offen               ; e0501000 80062c2c
	v_cvt_f32_f16_sdwa v42, v36 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e5416f9 00050624
	v_cvt_f32_f16_e32 v36, v36                                  ; 7e481724
	s_add_u32 s12, s16, 3                                       ; 800c8310
	s_waitcnt vmcnt(8)                                          ; bf8c3f78
	v_alignbyte_b32 v56, v57, v56, v51                          ; d1cf0038 04ce7139
	v_alignbyte_b32 v57, v57, v57, v51                          ; d1cf0039 04ce7339
	s_waitcnt vmcnt(7)                                          ; bf8c3f77
	v_lshl_or_b32 v49, v49, 12, v49                             ; d2000031 04c51931
	v_mad_f32 v3, -v42, v37, v3                                 ; d1c10003 240e4b2a
	s_mul_i32 s12, s12, s3                                      ; 920c030c
	v_mov_b32_sdwa v56, v57 dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_0 ; 7e7002f9 00041539
	s_waitcnt vmcnt(6)                                          ; bf8c3f76
	v_and_b32_e32 v57, s5, v53                                  ; 26726a05
	v_mac_f32_e32 v3, v36, v41                                  ; 2c065324
	s_add_u32 s12, s18, s12                                     ; 800c0c12
	v_and_b32_e32 v51, s9, v56                                  ; 26667009
	v_lshrrev_b32_e32 v53, 4, v53                               ; 206a6a84
	v_and_b32_e32 v56, s10, v56                                 ; 2670700a
	v_cvt_f32_ubyte3_e32 v36, v57                               ; 7e482939
	v_cvt_f32_ubyte2_e32 v37, v57                               ; 7e4a2739
	v_cvt_f32_ubyte1_e32 v41, v57                               ; 7e522539
	v_cvt_f32_ubyte0_e32 v57, v57                               ; 7e722339
	v_add_u32_e32 v48, s12, v0                                  ; 6860000c
	v_lshrrev_b32_e32 v51, 2, v51                               ; 20666682
	v_and_b32_e32 v53, s5, v53                                  ; 266a6a05
	v_mul_f32_e32 v36, v27, v36                                 ; 0a48491b
	v_and_or_b32 v49, s5, v49, v51                              ; d2010031 04ce6205
	v_cvt_f32_ubyte3_e32 v42, v53                               ; 7e542935
	v_cvt_f32_ubyte2_e32 v51, v53                               ; 7e662735
	v_mac_f32_e32 v36, v26, v37                                 ; 2c484b1a
	s_waitcnt vmcnt(5)                                          ; bf8c3f75
	v_and_b32_e32 v37, s5, v52                                  ; 264a6805
	v_mul_f32_e32 v42, v31, v42                                 ; 0a54551f
	v_mac_f32_e32 v36, v25, v41                                 ; 2c485319
	v_lshrrev_b32_e32 v52, 4, v52                               ; 20686884
	v_cvt_f32_ubyte3_e32 v41, v37                               ; 7e522925
	v_mac_f32_e32 v42, v30, v51                                 ; 2c54671e
	v_cvt_f32_ubyte2_e32 v51, v37                               ; 7e662725
	v_mac_f32_e32 v36, v24, v57                                 ; 2c487318
	v_cvt_f32_ubyte1_e32 v57, v53                               ; 7e722535
	v_cvt_f32_ubyte0_e32 v53, v53                               ; 7e6a2335
	v_and_b32_e32 v52, s5, v52                                  ; 26686805
	v_mul_f32_e32 v41, v35, v41                                 ; 0a525323
	v_mac_f32_e32 v42, v29, v57                                 ; 2c54731d
	v_cvt_f32_ubyte3_e32 v57, v52                               ; 7e722934
	v_mac_f32_e32 v41, v34, v51                                 ; 2c526722
	v_cvt_f32_ubyte1_e32 v51, v52                               ; 7e662534
	v_mac_f32_e32 v42, v28, v53                                 ; 2c546b1c
	v_cvt_f32_ubyte1_e32 v53, v37                               ; 7e6a2525
	v_cvt_f32_ubyte0_e32 v37, v37                               ; 7e4a2325
	v_mul_f32_e32 v57, v23, v57                                 ; 0a727317
	v_mac_f32_e32 v41, v33, v53                                 ; 2c526b21
	v_cvt_f32_ubyte2_e32 v53, v49                               ; 7e6a2731
	v_mac_f32_e32 v41, v32, v37                                 ; 2c524b20
	v_cvt_f32_ubyte2_e32 v37, v52                               ; 7e4a2734
	v_cvt_f32_ubyte0_e32 v52, v52                               ; 7e682334
	v_mac_f32_e32 v57, v22, v37                                 ; 2c724b16
	v_cvt_f32_ubyte3_e32 v37, v56                               ; 7e4a2938
	v_mac_f32_e32 v57, v21, v51                                 ; 2c726715
	v_cvt_f32_ubyte2_e32 v51, v56                               ; 7e662738
	v_mac_f32_e32 v57, v20, v52                                 ; 2c726914
	v_cvt_f32_ubyte3_e32 v52, v49                               ; 7e682931
	v_mul_f32_e32 v52, v62, v52                                 ; 0a68693e
	v_mac_f32_e32 v52, v61, v53                                 ; 2c686b3d
	v_cvt_f32_ubyte1_e32 v53, v49                               ; 7e6a2531
	v_cvt_f32_ubyte0_e32 v49, v49                               ; 7e622331
	v_mac_f32_e32 v52, v60, v37                                 ; 2c684b3c
	v_lshlrev_b32_e32 v37, 4, v48                               ; 244a6084
	v_mul_f32_e32 v57, v57, v53                                 ; 0a726b39
	v_cvt_f32_f16_sdwa v53, v47 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e6a16f9 0005062f
	v_mac_f32_e32 v52, v59, v51                                 ; 2c68673b
	v_lshl_add_u32 v48, v48, 7, v37                             ; d1fd0030 04950f30
	v_mac_f32_e32 v57, v41, v49                                 ; 2c726329
	v_cvt_f32_ubyte1_e32 v41, v56                               ; 7e522538
	v_cvt_f32_ubyte0_e32 v56, v56                               ; 7e702338
	v_mad_f32 v5, -v53, v52, v5                                 ; d1c10005 24166935
	v_mac_f32_e32 v57, v42, v41                                 ; 2c72532a
	v_add_u32_e32 v42, 4, v48                                   ; 68546084
	v_mac_f32_e32 v57, v36, v56                                 ; 2c727124
	v_add_u32_e32 v56, 16, v48                                  ; 68706090
	v_add_u32_e32 v49, v40, v42                                 ; 68625528
	v_add_u32_e32 v51, v42, v38                                 ; 68664d2a
	v_add_u32_e32 v42, v42, v43                                 ; 6854572a
	v_add_u32_e32 v36, v56, v4                                  ; 68480938
	v_add_u32_e32 v56, v56, v46                                 ; 68705d38
	buffer_load_dword v48, v48, s[24:27], 0 offen               ; e0501000 80063030
	buffer_load_dwordx2 v[52:53], v49, s[24:27], 0 offen        ; e0541000 80063431
	buffer_load_ushort v42, v42, s[24:27], 0 offen              ; e0481000 80062a2a
	buffer_load_dword v36, v36, s[24:27], 0 offen               ; e0501000 80062424
	buffer_load_dword v56, v56, s[24:27], 0 offen               ; e0501000 80063838
	v_cvt_f32_f16_e32 v47, v47                                  ; 7e5e172f
	s_add_u32 s13, s16, 4                                       ; 800d8410
	s_waitcnt vmcnt(8)                                          ; bf8c3f78
	v_alignbyte_b32 v54, v55, v54, v39                          ; d1cf0036 049e6d37
	v_alignbyte_b32 v55, v55, v55, v39                          ; d1cf0037 049e6f37
	s_waitcnt vmcnt(7)                                          ; bf8c3f77
	v_lshl_or_b32 v50, v50, 12, v50                             ; d2000032 04c91932
	s_waitcnt vmcnt(6)                                          ; bf8c3f76
	v_and_b32_e32 v41, s5, v45                                  ; 26525a05
	v_mac_f32_e32 v5, v47, v57                                  ; 2c0a732f
	s_mul_i32 s13, s13, s3                                      ; 920d030d
	v_mov_b32_sdwa v54, v55 dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_0 ; 7e6c02f9 00041537
	v_cvt_f32_ubyte1_e32 v55, v41                               ; 7e6e2529
	v_cvt_f32_ubyte2_e32 v49, v41                               ; 7e622729
	v_cvt_f32_ubyte3_e32 v47, v41                               ; 7e5e2929
	v_cvt_f32_ubyte0_e32 v41, v41                               ; 7e522329
	v_lshrrev_b32_e32 v45, 4, v45                               ; 205a5a84
	s_add_u32 s13, s18, s13                                     ; 800d0d12
	v_and_b32_e32 v39, s9, v54                                  ; 264e6c09
	v_and_b32_e32 v54, s10, v54                                 ; 266c6c0a
	v_mul_f32_e32 v47, v27, v47                                 ; 0a5e5f1b
	v_and_b32_e32 v45, s5, v45                                  ; 265a5a05
	v_add_u32_e32 v37, s13, v0                                  ; 684a000d
	v_lshrrev_b32_e32 v39, 2, v39                               ; 204e4e82
	v_mac_f32_e32 v47, v26, v49                                 ; 2c5e631a
	v_cvt_f32_ubyte3_e32 v57, v45                               ; 7e72292d
	v_and_or_b32 v50, s5, v50, v39                              ; d2010032 049e6405
	v_cvt_f32_ubyte2_e32 v39, v45                               ; 7e4e272d
	v_mac_f32_e32 v47, v25, v55                                 ; 2c5e6f19
	v_mul_f32_e32 v57, v31, v57                                 ; 0a72731f
	v_mac_f32_e32 v47, v24, v41                                 ; 2c5e5318
	v_cvt_f32_ubyte1_e32 v41, v45                               ; 7e52252d
	v_cvt_f32_ubyte0_e32 v45, v45                               ; 7e5a232d
	v_mac_f32_e32 v57, v30, v39                                 ; 2c724f1e
	v_mac_f32_e32 v57, v29, v41                                 ; 2c72531d
	v_mac_f32_e32 v57, v28, v45                                 ; 2c725b1c
	s_waitcnt vmcnt(5)                                          ; bf8c3f75
	v_and_b32_e32 v45, s5, v44                                  ; 265a5805
	v_lshrrev_b32_e32 v44, 4, v44                               ; 20585884
	v_cvt_f32_ubyte2_e32 v55, v45                               ; 7e6e272d
	v_cvt_f32_ubyte1_e32 v39, v45                               ; 7e4e252d
	v_cvt_f32_ubyte3_e32 v49, v45                               ; 7e62292d
	v_cvt_f32_ubyte0_e32 v45, v45                               ; 7e5a232d
	v_and_b32_e32 v44, s5, v44                                  ; 26585805
	v_mul_f32_e32 v49, v35, v49                                 ; 0a626323
	v_cvt_f32_ubyte3_e32 v41, v44                               ; 7e52292c
	v_mac_f32_e32 v49, v34, v55                                 ; 2c626f22
	v_cvt_f32_ubyte1_e32 v55, v44                               ; 7e6e252c
	v_mul_f32_e32 v41, v23, v41                                 ; 0a525317
	v_mac_f32_e32 v49, v33, v39                                 ; 2c624f21
	v_cvt_f32_ubyte3_e32 v39, v50                               ; 7e4e2932
	v_mac_f32_e32 v49, v32, v45                                 ; 2c625b20
	v_cvt_f32_ubyte2_e32 v45, v44                               ; 7e5a272c
	v_cvt_f32_ubyte0_e32 v44, v44                               ; 7e58232c
	v_mul_f32_e32 v39, v62, v39                                 ; 0a4e4f3e
	v_mac_f32_e32 v41, v22, v45                                 ; 2c525b16
	v_cvt_f32_ubyte3_e32 v45, v54                               ; 7e5a2936
	v_mac_f32_e32 v41, v21, v55                                 ; 2c526f15
	v_cvt_f32_ubyte2_e32 v55, v54                               ; 7e6e2736
	v_mac_f32_e32 v41, v20, v44                                 ; 2c525914
	v_cvt_f32_ubyte2_e32 v44, v50                               ; 7e582732
	v_mac_f32_e32 v39, v61, v44                                 ; 2c4e593d
	v_cvt_f32_ubyte1_e32 v44, v50                               ; 7e582532
	v_cvt_f32_ubyte0_e32 v50, v50                               ; 7e642332
	v_mac_f32_e32 v39, v60, v45                                 ; 2c4e5b3c
	v_lshlrev_b32_e32 v45, 4, v37                               ; 245a4a84
	v_mul_f32_e32 v41, v41, v44                                 ; 0a525929
	v_cvt_f32_f16_sdwa v44, v58 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e5816f9 0005063a
	v_mac_f32_e32 v39, v59, v55                                 ; 2c4e6f3b
	v_lshl_add_u32 v37, v37, 7, v45                             ; d1fd0025 04b50f25
	v_mac_f32_e32 v41, v49, v50                                 ; 2c526531
	v_cvt_f32_ubyte1_e32 v49, v54                               ; 7e622536
	v_cvt_f32_ubyte0_e32 v54, v54                               ; 7e6c2336
	v_add_u32_e32 v45, 16, v37                                  ; 685a4a90
	v_add_u32_e32 v50, 4, v37                                   ; 68644a84
	v_mac_f32_e32 v41, v57, v49                                 ; 2c526339
	v_add_u32_e32 v55, v40, v50                                 ; 686e6528
	v_add_u32_e32 v57, v50, v38                                 ; 68724d32
	v_add_u32_e32 v50, v50, v43                                 ; 68645732
	v_mac_f32_e32 v41, v47, v54                                 ; 2c526d2f
	v_add_u32_e32 v47, v45, v4                                  ; 685e092d
	v_add_u32_e32 v45, v45, v46                                 ; 685a5d2d
	buffer_load_dword v37, v37, s[24:27], 0 offen               ; e0501000 80062525
	buffer_load_dwordx2 v[54:55], v55, s[24:27], 0 offen        ; e0541000 80063637
	buffer_load_ushort v50, v50, s[24:27], 0 offen              ; e0481000 80063232
	buffer_load_dword v47, v47, s[24:27], 0 offen               ; e0501000 80062f2f
	buffer_load_dword v45, v45, s[24:27], 0 offen               ; e0501000 80062d2d
	v_mad_f32 v6, -v44, v39, v6                                 ; d1c10006 241a4f2c
	v_cvt_f32_f16_e32 v58, v58                                  ; 7e74173a
	s_add_u32 s14, s16, 5                                       ; 800e8510
	s_waitcnt vmcnt(8)                                          ; bf8c3f78
	v_alignbyte_b32 v52, v53, v52, v51                          ; d1cf0034 04ce6935
	v_alignbyte_b32 v53, v53, v53, v51                          ; d1cf0035 04ce6b35
	s_waitcnt vmcnt(7)                                          ; bf8c3f77
	v_lshl_or_b32 v42, v42, 12, v42                             ; d200002a 04a9192a
	v_mac_f32_e32 v6, v58, v41                                  ; 2c0c533a
	s_mul_i32 s14, s14, s3                                      ; 920e030e
	v_mov_b32_sdwa v52, v53 dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_0 ; 7e6802f9 00041535
	s_waitcnt vmcnt(6)                                          ; bf8c3f76
	v_and_b32_e32 v53, s5, v36                                  ; 266a4805
	s_add_u32 s14, s18, s14                                     ; 800e0e12
	v_lshrrev_b32_e32 v36, 4, v36                               ; 20484884
	v_and_b32_e32 v51, s9, v52                                  ; 26666809
	v_and_b32_e32 v52, s10, v52                                 ; 2668680a
	v_cvt_f32_ubyte1_e32 v41, v53                               ; 7e522535
	v_cvt_f32_ubyte2_e32 v39, v53                               ; 7e4e2735
	v_cvt_f32_ubyte3_e32 v58, v53                               ; 7e742935
	v_cvt_f32_ubyte0_e32 v53, v53                               ; 7e6a2335
	v_add_u32_e32 v49, s14, v0                                  ; 6862000e
	v_and_b32_e32 v36, s5, v36                                  ; 26484805
	v_lshrrev_b32_e32 v51, 2, v51                               ; 20666682
	v_mul_f32_e32 v58, v27, v58                                 ; 0a74751b
	v_cvt_f32_ubyte3_e32 v44, v36                               ; 7e582924
	v_and_or_b32 v42, s5, v42, v51                              ; d201002a 04ce5405
	v_cvt_f32_ubyte2_e32 v51, v36                               ; 7e662724
	v_mac_f32_e32 v58, v26, v39                                 ; 2c744f1a
	v_mul_f32_e32 v44, v31, v44                                 ; 0a58591f
	v_mac_f32_e32 v58, v25, v41                                 ; 2c745319
	v_mac_f32_e32 v44, v30, v51                                 ; 2c58671e
	v_mac_f32_e32 v58, v24, v53                                 ; 2c746b18
	v_cvt_f32_ubyte1_e32 v53, v36                               ; 7e6a2524
	v_cvt_f32_ubyte0_e32 v36, v36                               ; 7e482324
	v_mac_f32_e32 v44, v29, v53                                 ; 2c586b1d
	v_mac_f32_e32 v44, v28, v36                                 ; 2c58491c
	s_waitcnt vmcnt(5)                                          ; bf8c3f75
	v_and_b32_e32 v36, s5, v56                                  ; 26487005
	v_lshrrev_b32_e32 v56, 4, v56                               ; 20707084
	v_cvt_f32_ubyte2_e32 v41, v36                               ; 7e522724
	v_cvt_f32_ubyte1_e32 v51, v36                               ; 7e662524
	v_cvt_f32_ubyte3_e32 v39, v36                               ; 7e4e2924
	v_cvt_f32_ubyte0_e32 v36, v36                               ; 7e482324
	v_and_b32_e32 v56, s5, v56                                  ; 26707005
	v_mul_f32_e32 v39, v35, v39                                 ; 0a4e4f23
	v_cvt_f32_ubyte3_e32 v53, v56                               ; 7e6a2938
	v_mac_f32_e32 v39, v34, v41                                 ; 2c4e5322
	v_cvt_f32_ubyte1_e32 v41, v56                               ; 7e522538
	v_mul_f32_e32 v53, v23, v53                                 ; 0a6a6b17
	v_mac_f32_e32 v39, v33, v51                                 ; 2c4e6721
	v_cvt_f32_ubyte3_e32 v51, v42                               ; 7e66292a
	v_mac_f32_e32 v39, v32, v36                                 ; 2c4e4920
	v_cvt_f32_ubyte2_e32 v36, v56                               ; 7e482738
	v_cvt_f32_ubyte0_e32 v56, v56                               ; 7e702338
	v_mul_f32_e32 v51, v62, v51                                 ; 0a66673e
	v_mac_f32_e32 v53, v22, v36                                 ; 2c6a4916
	v_cvt_f32_ubyte3_e32 v36, v52                               ; 7e482934
	v_mac_f32_e32 v53, v21, v41                                 ; 2c6a5315
	v_cvt_f32_ubyte2_e32 v41, v52                               ; 7e522734
	v_mac_f32_e32 v53, v20, v56                                 ; 2c6a7114
	v_cvt_f32_ubyte2_e32 v56, v42                               ; 7e70272a
	v_mac_f32_e32 v51, v61, v56                                 ; 2c66713d
	v_cvt_f32_ubyte1_e32 v56, v42                               ; 7e70252a
	v_cvt_f32_ubyte0_e32 v42, v42                               ; 7e54232a
	v_mac_f32_e32 v51, v60, v36                                 ; 2c66493c
	v_lshlrev_b32_e32 v36, 4, v49                               ; 24486284
	v_mul_f32_e32 v53, v53, v56                                 ; 0a6a7135
	v_mac_f32_e32 v51, v59, v41                                 ; 2c66533b
	v_lshl_add_u32 v49, v49, 7, v36                             ; d1fd0031 04910f31
	v_mac_f32_e32 v53, v39, v42                                 ; 2c6a5527
	v_cvt_f32_ubyte1_e32 v39, v52                               ; 7e4e2534
	v_cvt_f32_ubyte0_e32 v52, v52                               ; 7e682334
	v_add_u32_e32 v41, 4, v49                                   ; 68526284
	v_add_u32_e32 v56, 16, v49                                  ; 68706290
	v_mac_f32_e32 v53, v44, v39                                 ; 2c6a4f2c
	v_add_u32_e32 v44, v41, v38                                 ; 68584d29
	v_add_u32_e32 v42, v40, v41                                 ; 68545328
	v_add_u32_e32 v41, v41, v43                                 ; 68525729
	v_mac_f32_e32 v53, v58, v52                                 ; 2c6a693a
	v_cvt_f32_f16_sdwa v52, v48 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e6816f9 00050630
	v_add_u32_e32 v58, v56, v4                                  ; 68740938
	v_add_u32_e32 v56, v56, v46                                 ; 68705d38
	v_mad_f32 v7, -v52, v51, v7                                 ; d1c10007 241e6734
	buffer_load_dword v49, v49, s[24:27], 0 offen               ; e0501000 80063131
	buffer_load_dwordx2 v[51:52], v42, s[24:27], 0 offen        ; e0541000 8006332a
	buffer_load_ushort v41, v41, s[24:27], 0 offen              ; e0481000 80062929
	buffer_load_dword v58, v58, s[24:27], 0 offen               ; e0501000 80063a3a
	buffer_load_dword v56, v56, s[24:27], 0 offen               ; e0501000 80063838
	v_cvt_f32_f16_e32 v48, v48                                  ; 7e601730
	s_add_u32 s15, s16, 6                                       ; 800f8610
	s_waitcnt vmcnt(8)                                          ; bf8c3f78
	v_alignbyte_b32 v54, v55, v54, v57                          ; d1cf0036 04e66d37
	v_alignbyte_b32 v55, v55, v55, v57                          ; d1cf0037 04e66f37
	s_waitcnt vmcnt(7)                                          ; bf8c3f77
	v_lshl_or_b32 v50, v50, 12, v50                             ; d2000032 04c91932
	s_waitcnt vmcnt(6)                                          ; bf8c3f76
	v_and_b32_e32 v57, s5, v47                                  ; 26725e05
	v_mac_f32_e32 v7, v48, v53                                  ; 2c0e6b30
	s_mul_i32 s15, s15, s3                                      ; 920f030f
	v_mov_b32_sdwa v54, v55 dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_0 ; 7e6c02f9 00041537
	v_cvt_f32_ubyte3_e32 v36, v57                               ; 7e482939
	v_cvt_f32_ubyte1_e32 v42, v57                               ; 7e542539
	v_cvt_f32_ubyte2_e32 v39, v57                               ; 7e4e2739
	v_cvt_f32_ubyte0_e32 v57, v57                               ; 7e722339
	v_lshrrev_b32_e32 v47, 4, v47                               ; 205e5e84
	s_add_u32 s15, s18, s15                                     ; 800f0f12
	v_and_b32_e32 v55, s9, v54                                  ; 266e6c09
	v_and_b32_e32 v54, s10, v54                                 ; 266c6c0a
	v_mul_f32_e32 v36, v27, v36                                 ; 0a48491b
	v_and_b32_e32 v47, s5, v47                                  ; 265e5e05
	v_add_u32_e32 v53, s15, v0                                  ; 686a000f
	v_lshrrev_b32_e32 v55, 2, v55                               ; 206e6e82
	v_mac_f32_e32 v36, v26, v39                                 ; 2c484f1a
	s_waitcnt vmcnt(5)                                          ; bf8c3f75
	v_and_b32_e32 v39, s5, v45                                  ; 264e5a05
	v_cvt_f32_ubyte3_e32 v48, v47                               ; 7e60292f
	v_and_or_b32 v50, s5, v50, v55                              ; d2010032 04de6405
	v_cvt_f32_ubyte2_e32 v55, v47                               ; 7e6e272f
	v_mac_f32_e32 v36, v25, v42                                 ; 2c485519
	v_cvt_f32_ubyte3_e32 v42, v39                               ; 7e542927
	v_mul_f32_e32 v48, v31, v48                                 ; 0a60611f
	v_lshrrev_b32_e32 v45, 4, v45                               ; 205a5a84
	v_mac_f32_e32 v36, v24, v57                                 ; 2c487318
	v_cvt_f32_ubyte1_e32 v57, v47                               ; 7e72252f
	v_cvt_f32_ubyte0_e32 v47, v47                               ; 7e5e232f
	v_mul_f32_e32 v42, v35, v42                                 ; 0a545523
	v_mac_f32_e32 v48, v30, v55                                 ; 2c606f1e
	v_cvt_f32_ubyte1_e32 v55, v39                               ; 7e6e2527
	v_and_b32_e32 v45, s5, v45                                  ; 265a5a05
	v_mac_f32_e32 v48, v29, v57                                 ; 2c60731d
	v_cvt_f32_ubyte3_e32 v57, v45                               ; 7e72292d
	v_mac_f32_e32 v48, v28, v47                                 ; 2c605f1c
	v_cvt_f32_ubyte2_e32 v47, v39                               ; 7e5e2727
	v_cvt_f32_ubyte0_e32 v39, v39                               ; 7e4e2327
	v_mul_f32_e32 v57, v23, v57                                 ; 0a727317
	v_mac_f32_e32 v42, v34, v47                                 ; 2c545f22
	v_cvt_f32_ubyte1_e32 v47, v45                               ; 7e5e252d
	v_mac_f32_e32 v42, v33, v55                                 ; 2c546f21
	v_cvt_f32_ubyte3_e32 v55, v50                               ; 7e6e2932
	v_mac_f32_e32 v42, v32, v39                                 ; 2c544f20
	v_cvt_f32_ubyte2_e32 v39, v45                               ; 7e4e272d
	v_cvt_f32_ubyte0_e32 v45, v45                               ; 7e5a232d
	v_mul_f32_e32 v55, v62, v55                                 ; 0a6e6f3e
	v_mac_f32_e32 v57, v22, v39                                 ; 2c724f16
	v_cvt_f32_ubyte2_e32 v39, v50                               ; 7e4e2732
	v_mac_f32_e32 v57, v21, v47                                 ; 2c725f15
	v_cvt_f32_ubyte2_e32 v47, v54                               ; 7e5e2736
	v_mac_f32_e32 v55, v61, v39                                 ; 2c6e4f3d
	v_cvt_f32_ubyte1_e32 v39, v50                               ; 7e4e2532
	v_cvt_f32_ubyte0_e32 v50, v50                               ; 7e642332
	v_mac_f32_e32 v57, v20, v45                                 ; 2c725b14
	v_cvt_f32_ubyte3_e32 v45, v54                               ; 7e5a2936
	v_mul_f32_e32 v57, v57, v39                                 ; 0a724f39
	v_mac_f32_e32 v55, v60, v45                                 ; 2c6e5b3c
	v_lshlrev_b32_e32 v45, 4, v53                               ; 245a6a84
	v_mac_f32_e32 v57, v42, v50                                 ; 2c72652a
	v_mac_f32_e32 v55, v59, v47                                 ; 2c6e5f3b
	v_cvt_f32_ubyte1_e32 v47, v54                               ; 7e5e2536
	v_cvt_f32_ubyte0_e32 v54, v54                               ; 7e6c2336
	v_lshl_add_u32 v53, v53, 7, v45                             ; d1fd0035 04b50f35
	v_mov_b32_e32 v45, v35                                      ; 7e5a0323
	v_mac_f32_e32 v57, v48, v47                                 ; 2c725f30
	v_add_u32_e32 v39, 16, v53                                  ; 684e6a90
	v_add_u32_e32 v48, 4, v53                                   ; 68606a84
	v_mac_f32_e32 v57, v36, v54                                 ; 2c726d24
	v_cvt_f32_f16_sdwa v36, v37 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e4816f9 00050625
	v_add_u32_e32 v42, v39, v4                                  ; 68540927
	v_add_u32_e32 v39, v39, v46                                 ; 684e5d27
	v_add_u32_e32 v54, v48, v38                                 ; 686c4d30
	v_add_u32_e32 v50, v40, v48                                 ; 68646128
	v_add_u32_e32 v48, v48, v43                                 ; 68605730
	v_mad_f32 v8, -v36, v55, v8                                 ; d1c10008 24226f24
	buffer_load_dword v53, v53, s[24:27], 0 offen               ; e0501000 80063535
	buffer_load_dwordx2 v[35:36], v50, s[24:27], 0 offen        ; e0541000 80062332
	buffer_load_ushort v48, v48, s[24:27], 0 offen              ; e0481000 80063030
	buffer_load_dword v42, v42, s[24:27], 0 offen               ; e0501000 80062a2a
	buffer_load_dword v39, v39, s[24:27], 0 offen               ; e0501000 80062727
	v_cvt_f32_f16_e32 v37, v37                                  ; 7e4a1725
	s_add_u32 s19, s16, 7                                       ; 80138710
	s_waitcnt vmcnt(8)                                          ; bf8c3f78
	v_alignbyte_b32 v51, v52, v51, v44                          ; d1cf0033 04b26734
	v_alignbyte_b32 v52, v52, v52, v44                          ; d1cf0034 04b26934
	s_waitcnt vmcnt(7)                                          ; bf8c3f77
	v_lshl_or_b32 v41, v41, 12, v41                             ; d2000029 04a51929
	v_mac_f32_e32 v8, v37, v57                                  ; 2c107325
	s_mul_i32 s19, s19, s3                                      ; 92130313
	v_mov_b32_sdwa v51, v52 dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_0 ; 7e6602f9 00041534
	s_waitcnt vmcnt(6)                                          ; bf8c3f76
	v_and_b32_e32 v52, s5, v58                                  ; 26687405
	s_add_u32 s19, s18, s19                                     ; 80131312
	v_lshrrev_b32_e32 v58, 4, v58                               ; 20747484
	v_and_b32_e32 v50, s9, v51                                  ; 26646609
	v_and_b32_e32 v51, s10, v51                                 ; 2666660a
	v_cvt_f32_ubyte1_e32 v37, v52                               ; 7e4a2534
	v_cvt_f32_ubyte3_e32 v55, v52                               ; 7e6e2934
	v_cvt_f32_ubyte2_e32 v57, v52                               ; 7e722734
	v_cvt_f32_ubyte0_e32 v52, v52                               ; 7e682334
	v_add_u32_e32 v47, s19, v0                                  ; 685e0013
	v_and_b32_e32 v58, s5, v58                                  ; 26747405
	v_lshrrev_b32_e32 v50, 2, v50                               ; 20646482
	v_mul_f32_e32 v55, v27, v55                                 ; 0a6e6f1b
	v_cvt_f32_ubyte3_e32 v44, v58                               ; 7e58293a
	v_and_or_b32 v41, s5, v41, v50                              ; d2010029 04ca5205
	v_cvt_f32_ubyte2_e32 v50, v58                               ; 7e64273a
	v_mac_f32_e32 v55, v26, v57                                 ; 2c6e731a
	s_waitcnt vmcnt(5)                                          ; bf8c3f75
	v_and_b32_e32 v57, s5, v56                                  ; 26727005
	v_mul_f32_e32 v44, v31, v44                                 ; 0a58591f
	v_mac_f32_e32 v55, v25, v37                                 ; 2c6e4b19
	v_lshrrev_b32_e32 v56, 4, v56                               ; 20707084
	v_cvt_f32_ubyte2_e32 v37, v57                               ; 7e4a2739
	v_mac_f32_e32 v44, v30, v50                                 ; 2c58651e
	v_cvt_f32_ubyte1_e32 v50, v57                               ; 7e642539
	v_mac_f32_e32 v55, v24, v52                                 ; 2c6e6918
	v_cvt_f32_ubyte1_e32 v52, v58                               ; 7e68253a
	v_cvt_f32_ubyte0_e32 v58, v58                               ; 7e74233a
	v_and_b32_e32 v56, s5, v56                                  ; 26707005
	v_mac_f32_e32 v44, v29, v52                                 ; 2c58691d
	v_cvt_f32_ubyte3_e32 v52, v56                               ; 7e682938
	v_mac_f32_e32 v44, v28, v58                                 ; 2c58751c
	v_cvt_f32_ubyte3_e32 v58, v57                               ; 7e742939
	v_cvt_f32_ubyte0_e32 v57, v57                               ; 7e722339
	v_mul_f32_e32 v52, v23, v52                                 ; 0a686917
	v_mul_f32_e32 v58, v45, v58                                 ; 0a74752d
	v_mac_f32_e32 v58, v34, v37                                 ; 2c744b22
	v_cvt_f32_ubyte1_e32 v37, v56                               ; 7e4a2538
	v_mac_f32_e32 v58, v33, v50                                 ; 2c746521
	v_cvt_f32_ubyte3_e32 v50, v41                               ; 7e642929
	v_mac_f32_e32 v58, v32, v57                                 ; 2c747320
	v_cvt_f32_ubyte2_e32 v57, v56                               ; 7e722738
	v_cvt_f32_ubyte0_e32 v56, v56                               ; 7e702338
	v_mul_f32_e32 v50, v62, v50                                 ; 0a64653e
	v_mac_f32_e32 v52, v22, v57                                 ; 2c687316
	v_cvt_f32_ubyte3_e32 v57, v51                               ; 7e722933
	v_mac_f32_e32 v52, v21, v37                                 ; 2c684b15
	v_cvt_f32_ubyte2_e32 v37, v51                               ; 7e4a2733
	v_mac_f32_e32 v52, v20, v56                                 ; 2c687114
	v_cvt_f32_ubyte2_e32 v56, v41                               ; 7e702729
	v_mac_f32_e32 v50, v61, v56                                 ; 2c64713d
	v_cvt_f32_ubyte1_e32 v56, v41                               ; 7e702529
	v_cvt_f32_ubyte0_e32 v41, v41                               ; 7e522329
	v_mac_f32_e32 v50, v60, v57                                 ; 2c64733c
	v_lshlrev_b32_e32 v57, 4, v47                               ; 24725e84
	v_mul_f32_e32 v52, v52, v56                                 ; 0a687134
	v_mac_f32_e32 v50, v59, v37                                 ; 2c644b3b
	v_lshl_add_u32 v47, v47, 7, v57                             ; d1fd002f 04e50f2f
	v_mac_f32_e32 v52, v58, v41                                 ; 2c68533a
	v_cvt_f32_ubyte1_e32 v58, v51                               ; 7e742533
	v_cvt_f32_ubyte0_e32 v51, v51                               ; 7e662333
	v_add_u32_e32 v37, 4, v47                                   ; 684a5e84
	v_mac_f32_e32 v52, v44, v58                                 ; 2c68752c
	v_add_u32_e32 v41, v40, v37                                 ; 68524b28
	v_add_u32_e32 v44, v37, v38                                 ; 68584d25
	v_add_u32_e32 v37, v37, v43                                 ; 684a5725
	v_mac_f32_e32 v52, v55, v51                                 ; 2c686737
	v_cvt_f32_f16_sdwa v51, v49 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e6616f9 00050631
	v_add_u32_e32 v55, 16, v47                                  ; 686e5e90
	v_mad_f32 v9, -v51, v50, v9                                 ; d1c10009 24266533
	v_add_u32_e32 v56, v55, v4                                  ; 68700937
	v_add_u32_e32 v55, v55, v46                                 ; 686e5d37
	buffer_load_dword v47, v47, s[24:27], 0 offen               ; e0501000 80062f2f
	buffer_load_dwordx2 v[50:51], v41, s[24:27], 0 offen        ; e0541000 80063229
	buffer_load_ushort v37, v37, s[24:27], 0 offen              ; e0481000 80062525
	buffer_load_dword v56, v56, s[24:27], 0 offen               ; e0501000 80063838
	buffer_load_dword v55, v55, s[24:27], 0 offen               ; e0501000 80063737
	v_cvt_f32_f16_e32 v49, v49                                  ; 7e621731
	s_add_u32 s20, s16, 8                                       ; 80148810
	s_waitcnt vmcnt(8)                                          ; bf8c3f78
	v_alignbyte_b32 v35, v36, v35, v54                          ; d1cf0023 04da4724
	v_alignbyte_b32 v36, v36, v36, v54                          ; d1cf0024 04da4924
	s_waitcnt vmcnt(7)                                          ; bf8c3f77
	v_lshl_or_b32 v48, v48, 12, v48                             ; d2000030 04c11930
	v_mac_f32_e32 v9, v49, v52                                  ; 2c126931
	s_mul_i32 s20, s20, s3                                      ; 92140314
	v_mov_b32_sdwa v35, v36 dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_0 ; 7e4602f9 00041524
	s_waitcnt vmcnt(6)                                          ; bf8c3f76
	v_and_b32_e32 v36, s5, v42                                  ; 26485405
	s_add_u32 s20, s18, s20                                     ; 80141412
	v_lshrrev_b32_e32 v42, 4, v42                               ; 20545484
	v_and_b32_e32 v58, s9, v35                                  ; 26744609
	v_and_b32_e32 v35, s10, v35                                 ; 2646460a
	v_cvt_f32_ubyte2_e32 v49, v36                               ; 7e622724
	v_cvt_f32_ubyte1_e32 v52, v36                               ; 7e682524
	v_cvt_f32_ubyte3_e32 v41, v36                               ; 7e522924
	v_cvt_f32_ubyte0_e32 v36, v36                               ; 7e482324
	v_add_u32_e32 v57, s20, v0                                  ; 68720014
	v_and_b32_e32 v42, s5, v42                                  ; 26545405
	v_lshrrev_b32_e32 v58, 2, v58                               ; 20747482
	v_mul_f32_e32 v41, v27, v41                                 ; 0a52531b
	v_cvt_f32_ubyte3_e32 v54, v42                               ; 7e6c292a
	v_and_or_b32 v48, s5, v48, v58                              ; d2010030 04ea6005
	v_cvt_f32_ubyte2_e32 v58, v42                               ; 7e74272a
	v_mac_f32_e32 v41, v26, v49                                 ; 2c52631a
	v_mul_f32_e32 v54, v31, v54                                 ; 0a6c6d1f
	v_mac_f32_e32 v41, v25, v52                                 ; 2c526919
	v_mac_f32_e32 v54, v30, v58                                 ; 2c6c751e
	v_mac_f32_e32 v41, v24, v36                                 ; 2c524918
	v_cvt_f32_ubyte1_e32 v36, v42                               ; 7e48252a
	v_cvt_f32_ubyte0_e32 v42, v42                               ; 7e54232a
	v_mac_f32_e32 v54, v29, v36                                 ; 2c6c491d
	v_mac_f32_e32 v54, v28, v42                                 ; 2c6c551c
	s_waitcnt vmcnt(5)                                          ; bf8c3f75
	v_and_b32_e32 v42, s5, v39                                  ; 26544e05
	v_lshrrev_b32_e32 v39, 4, v39                               ; 204e4e84
	v_cvt_f32_ubyte3_e32 v49, v42                               ; 7e62292a
	v_cvt_f32_ubyte1_e32 v58, v42                               ; 7e74252a
	v_cvt_f32_ubyte2_e32 v52, v42                               ; 7e68272a
	v_cvt_f32_ubyte0_e32 v42, v42                               ; 7e54232a
	v_and_b32_e32 v39, s5, v39                                  ; 264e4e05
	v_mul_f32_e32 v49, v45, v49                                 ; 0a62632d
	v_cvt_f32_ubyte3_e32 v36, v39                               ; 7e482927
	v_mac_f32_e32 v49, v34, v52                                 ; 2c626922
	v_cvt_f32_ubyte1_e32 v52, v39                               ; 7e682527
	v_mul_f32_e32 v36, v23, v36                                 ; 0a484917
	v_mac_f32_e32 v49, v33, v58                                 ; 2c627521
	v_cvt_f32_ubyte3_e32 v58, v48                               ; 7e742930
	v_mac_f32_e32 v49, v32, v42                                 ; 2c625520
	v_cvt_f32_ubyte2_e32 v42, v39                               ; 7e542727
	v_cvt_f32_ubyte0_e32 v39, v39                               ; 7e4e2327
	v_mul_f32_e32 v58, v62, v58                                 ; 0a74753e
	v_mac_f32_e32 v36, v22, v42                                 ; 2c485516
	v_cvt_f32_ubyte3_e32 v42, v35                               ; 7e542923
	v_mac_f32_e32 v36, v21, v52                                 ; 2c486915
	v_cvt_f32_ubyte2_e32 v52, v35                               ; 7e682723
	v_mac_f32_e32 v36, v20, v39                                 ; 2c484f14
	v_cvt_f32_ubyte2_e32 v39, v48                               ; 7e4e2730
	v_mac_f32_e32 v58, v61, v39                                 ; 2c744f3d
	v_cvt_f32_ubyte1_e32 v39, v48                               ; 7e4e2530
	v_cvt_f32_ubyte0_e32 v48, v48                               ; 7e602330
	v_mac_f32_e32 v58, v60, v42                                 ; 2c74553c
	v_lshlrev_b32_e32 v42, 4, v57                               ; 24547284
	v_mul_f32_e32 v36, v36, v39                                 ; 0a484f24
	v_mac_f32_e32 v58, v59, v52                                 ; 2c74693b
	v_lshl_add_u32 v57, v57, 7, v42                             ; d1fd0039 04a90f39
	v_mac_f32_e32 v36, v49, v48                                 ; 2c486131
	v_cvt_f32_ubyte1_e32 v48, v35                               ; 7e602523
	v_cvt_f32_ubyte0_e32 v35, v35                               ; 7e462323
	v_mov_b32_e32 v42, v34                                      ; 7e540322
	v_add_u32_e32 v39, 16, v57                                  ; 684e7290
	v_add_u32_e32 v49, 4, v57                                   ; 68627284
	v_mac_f32_e32 v36, v54, v48                                 ; 2c486136
	v_add_u32_e32 v54, v49, v38                                 ; 686c4d31
	v_add_u32_e32 v52, v40, v49                                 ; 68686328
	v_add_u32_e32 v49, v49, v43                                 ; 68625731
	v_mac_f32_e32 v36, v41, v35                                 ; 2c484729
	v_cvt_f32_f16_sdwa v35, v53 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e4616f9 00050635
	v_add_u32_e32 v41, v39, v4                                  ; 68520927
	v_add_u32_e32 v39, v39, v46                                 ; 684e5d27
	v_mad_f32 v10, -v35, v58, v10                               ; d1c1000a 242a7523
	buffer_load_dword v57, v57, s[24:27], 0 offen               ; e0501000 80063939
	buffer_load_dwordx2 v[34:35], v52, s[24:27], 0 offen        ; e0541000 80062234
	buffer_load_ushort v49, v49, s[24:27], 0 offen              ; e0481000 80063131
	buffer_load_dword v41, v41, s[24:27], 0 offen               ; e0501000 80062929
	buffer_load_dword v39, v39, s[24:27], 0 offen               ; e0501000 80062727
	v_cvt_f32_f16_e32 v53, v53                                  ; 7e6a1735
	s_add_u32 s21, s16, 9                                       ; 80158910
	s_waitcnt vmcnt(8)                                          ; bf8c3f78
	v_alignbyte_b32 v50, v51, v50, v44                          ; d1cf0032 04b26533
	v_alignbyte_b32 v51, v51, v51, v44                          ; d1cf0033 04b26733
	s_waitcnt vmcnt(7)                                          ; bf8c3f77
	v_lshl_or_b32 v37, v37, 12, v37                             ; d2000025 04951925
	s_waitcnt vmcnt(6)                                          ; bf8c3f76
	v_and_b32_e32 v52, s5, v56                                  ; 26687005
	v_mac_f32_e32 v10, v53, v36                                 ; 2c144935
	s_mul_i32 s21, s21, s3                                      ; 92150315
	v_mov_b32_sdwa v50, v51 dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_0 ; 7e6402f9 00041533
	v_cvt_f32_ubyte1_e32 v36, v52                               ; 7e482534
	v_cvt_f32_ubyte2_e32 v58, v52                               ; 7e742734
	v_cvt_f32_ubyte3_e32 v53, v52                               ; 7e6a2934
	v_cvt_f32_ubyte0_e32 v52, v52                               ; 7e682334
	v_lshrrev_b32_e32 v56, 4, v56                               ; 20707084
	s_add_u32 s21, s18, s21                                     ; 80151512
	v_and_b32_e32 v51, s9, v50                                  ; 26666409
	v_and_b32_e32 v50, s10, v50                                 ; 2664640a
	v_mul_f32_e32 v53, v27, v53                                 ; 0a6a6b1b
	v_and_b32_e32 v56, s5, v56                                  ; 26707005
	v_add_u32_e32 v48, s21, v0                                  ; 68600015
	v_lshrrev_b32_e32 v51, 2, v51                               ; 20666682
	v_mac_f32_e32 v53, v26, v58                                 ; 2c6a751a
	v_cvt_f32_ubyte3_e32 v44, v56                               ; 7e582938
	v_and_or_b32 v37, s5, v37, v51                              ; d2010025 04ce4a05
	v_cvt_f32_ubyte2_e32 v51, v56                               ; 7e662738
	v_mac_f32_e32 v53, v25, v36                                 ; 2c6a4919
	v_mul_f32_e32 v44, v31, v44                                 ; 0a58591f
	v_mac_f32_e32 v53, v24, v52                                 ; 2c6a6918
	v_cvt_f32_ubyte1_e32 v52, v56                               ; 7e682538
	v_cvt_f32_ubyte0_e32 v56, v56                               ; 7e702338
	v_mac_f32_e32 v44, v30, v51                                 ; 2c58671e
	v_mac_f32_e32 v44, v29, v52                                 ; 2c58691d
	v_mac_f32_e32 v44, v28, v56                                 ; 2c58711c
	s_waitcnt vmcnt(5)                                          ; bf8c3f75
	v_and_b32_e32 v56, s5, v55                                  ; 26706e05
	v_lshrrev_b32_e32 v55, 4, v55                               ; 206e6e84
	v_cvt_f32_ubyte1_e32 v51, v56                               ; 7e662538
	v_cvt_f32_ubyte3_e32 v58, v56                               ; 7e742938
	v_cvt_f32_ubyte2_e32 v36, v56                               ; 7e482738
	v_cvt_f32_ubyte0_e32 v56, v56                               ; 7e702338
	v_and_b32_e32 v55, s5, v55                                  ; 266e6e05
	v_mul_f32_e32 v58, v45, v58                                 ; 0a74752d
	v_cvt_f32_ubyte3_e32 v52, v55                               ; 7e682937
	v_mac_f32_e32 v58, v42, v36                                 ; 2c74492a
	v_cvt_f32_ubyte1_e32 v36, v55                               ; 7e482537
	v_mul_f32_e32 v52, v23, v52                                 ; 0a686917
	v_mac_f32_e32 v58, v33, v51                                 ; 2c746721
	v_cvt_f32_ubyte3_e32 v51, v37                               ; 7e662925
	v_mac_f32_e32 v58, v32, v56                                 ; 2c747120
	v_cvt_f32_ubyte2_e32 v56, v55                               ; 7e702737
	v_cvt_f32_ubyte0_e32 v55, v55                               ; 7e6e2337
	v_mul_f32_e32 v51, v62, v51                                 ; 0a66673e
	v_mac_f32_e32 v52, v22, v56                                 ; 2c687116
	v_cvt_f32_ubyte3_e32 v56, v50                               ; 7e702932
	v_mac_f32_e32 v52, v21, v36                                 ; 2c684915
	v_cvt_f32_ubyte2_e32 v36, v50                               ; 7e482732
	v_mac_f32_e32 v52, v20, v55                                 ; 2c686f14
	v_cvt_f32_ubyte2_e32 v55, v37                               ; 7e6e2725
	v_mac_f32_e32 v51, v61, v55                                 ; 2c666f3d
	v_cvt_f32_ubyte1_e32 v55, v37                               ; 7e6e2525
	v_cvt_f32_ubyte0_e32 v37, v37                               ; 7e4a2325
	v_mac_f32_e32 v51, v60, v56                                 ; 2c66713c
	v_lshlrev_b32_e32 v56, 4, v48                               ; 24706084
	v_mul_f32_e32 v52, v52, v55                                 ; 0a686f34
	v_mac_f32_e32 v51, v59, v36                                 ; 2c66493b
	v_lshl_add_u32 v48, v48, 7, v56                             ; d1fd0030 04e10f30
	v_mac_f32_e32 v52, v58, v37                                 ; 2c684b3a
	v_cvt_f32_ubyte1_e32 v58, v50                               ; 7e742532
	v_cvt_f32_ubyte0_e32 v50, v50                               ; 7e642332
	v_add_u32_e32 v36, 4, v48                                   ; 68486084
	v_mac_f32_e32 v52, v44, v58                                 ; 2c68752c
	v_add_u32_e32 v37, v40, v36                                 ; 684a4928
	v_add_u32_e32 v44, v36, v38                                 ; 68584d24
	v_add_u32_e32 v36, v36, v43                                 ; 68485724
	v_mac_f32_e32 v52, v53, v50                                 ; 2c686535
	v_cvt_f32_f16_sdwa v50, v47 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e6416f9 0005062f
	v_mad_f32 v11, -v50, v51, v11                               ; d1c1000b 242e6732
	v_add_u32_e32 v51, 16, v48                                  ; 68666090
	v_add_u32_e32 v53, v51, v4                                  ; 686a0933
	v_add_u32_e32 v51, v51, v46                                 ; 68665d33
	buffer_load_dword v48, v48, s[24:27], 0 offen               ; e0501000 80063030
	buffer_load_dwordx2 v[55:56], v37, s[24:27], 0 offen        ; e0541000 80063725
	buffer_load_ushort v36, v36, s[24:27], 0 offen              ; e0481000 80062424
	buffer_load_dword v53, v53, s[24:27], 0 offen               ; e0501000 80063535
	buffer_load_dword v51, v51, s[24:27], 0 offen               ; e0501000 80063333
	v_cvt_f32_f16_e32 v47, v47                                  ; 7e5e172f
	s_add_u32 s22, s16, 10                                      ; 80168a10
	s_waitcnt vmcnt(8)                                          ; bf8c3f78
	v_alignbyte_b32 v34, v35, v34, v54                          ; d1cf0022 04da4523
	v_alignbyte_b32 v35, v35, v35, v54                          ; d1cf0023 04da4723
	s_waitcnt vmcnt(7)                                          ; bf8c3f77
	v_lshl_or_b32 v49, v49, 12, v49                             ; d2000031 04c51931
	s_waitcnt vmcnt(6)                                          ; bf8c3f76
	v_and_b32_e32 v37, s5, v41                                  ; 264a5205
	v_mac_f32_e32 v11, v47, v52                                 ; 2c16692f
	s_mul_i32 s22, s22, s3                                      ; 92160316
	v_mov_b32_sdwa v34, v35 dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_0 ; 7e4402f9 00041523
	v_cvt_f32_ubyte3_e32 v47, v37                               ; 7e5e2925
	v_cvt_f32_ubyte2_e32 v50, v37                               ; 7e642725
	v_cvt_f32_ubyte1_e32 v52, v37                               ; 7e682525
	v_cvt_f32_ubyte0_e32 v37, v37                               ; 7e4a2325
	v_lshrrev_b32_e32 v41, 4, v41                               ; 20525284
	s_add_u32 s22, s18, s22                                     ; 80161612
	v_and_b32_e32 v35, s9, v34                                  ; 26464409
	v_and_b32_e32 v34, s10, v34                                 ; 2644440a
	v_mul_f32_e32 v47, v27, v47                                 ; 0a5e5f1b
	v_and_b32_e32 v41, s5, v41                                  ; 26525205
	v_add_u32_e32 v58, s22, v0                                  ; 68740016
	v_lshrrev_b32_e32 v35, 2, v35                               ; 20464682
	v_mac_f32_e32 v47, v26, v50                                 ; 2c5e651a
	v_cvt_f32_ubyte3_e32 v54, v41                               ; 7e6c2929
	v_and_or_b32 v49, s5, v49, v35                              ; d2010031 048e6205
	v_cvt_f32_ubyte2_e32 v35, v41                               ; 7e462729
	v_mac_f32_e32 v47, v25, v52                                 ; 2c5e6919
	v_mul_f32_e32 v54, v31, v54                                 ; 0a6c6d1f
	v_mac_f32_e32 v47, v24, v37                                 ; 2c5e4b18
	v_cvt_f32_ubyte1_e32 v37, v41                               ; 7e4a2529
	v_cvt_f32_ubyte0_e32 v41, v41                               ; 7e522329
	v_mac_f32_e32 v54, v30, v35                                 ; 2c6c471e
	v_mac_f32_e32 v54, v29, v37                                 ; 2c6c4b1d
	v_mac_f32_e32 v54, v28, v41                                 ; 2c6c531c
	s_waitcnt vmcnt(5)                                          ; bf8c3f75
	v_and_b32_e32 v41, s5, v39                                  ; 26524e05
	v_lshrrev_b32_e32 v39, 4, v39                               ; 204e4e84
	v_cvt_f32_ubyte1_e32 v35, v41                               ; 7e462529
	v_cvt_f32_ubyte3_e32 v50, v41                               ; 7e642929
	v_cvt_f32_ubyte2_e32 v52, v41                               ; 7e682729
	v_cvt_f32_ubyte0_e32 v41, v41                               ; 7e522329
	v_and_b32_e32 v39, s5, v39                                  ; 264e4e05
	v_mul_f32_e32 v50, v45, v50                                 ; 0a64652d
	v_cvt_f32_ubyte3_e32 v37, v39                               ; 7e4a2927
	v_mac_f32_e32 v50, v42, v52                                 ; 2c64692a
	v_cvt_f32_ubyte1_e32 v52, v39                               ; 7e682527
	v_mul_f32_e32 v37, v23, v37                                 ; 0a4a4b17
	v_mac_f32_e32 v50, v33, v35                                 ; 2c644721
	v_cvt_f32_ubyte3_e32 v35, v49                               ; 7e462931
	v_mac_f32_e32 v50, v32, v41                                 ; 2c645320
	v_cvt_f32_ubyte2_e32 v41, v39                               ; 7e522727
	v_cvt_f32_ubyte0_e32 v39, v39                               ; 7e4e2327
	v_mul_f32_e32 v35, v62, v35                                 ; 0a46473e
	v_mac_f32_e32 v37, v22, v41                                 ; 2c4a5316
	v_cvt_f32_ubyte3_e32 v41, v34                               ; 7e522922
	v_mac_f32_e32 v37, v21, v52                                 ; 2c4a6915
	v_cvt_f32_ubyte2_e32 v52, v34                               ; 7e682722
	v_mac_f32_e32 v37, v20, v39                                 ; 2c4a4f14
	v_cvt_f32_ubyte2_e32 v39, v49                               ; 7e4e2731
	v_mac_f32_e32 v35, v61, v39                                 ; 2c464f3d
	v_cvt_f32_ubyte1_e32 v39, v49                               ; 7e4e2531
	v_cvt_f32_ubyte0_e32 v49, v49                               ; 7e622331
	v_mac_f32_e32 v35, v60, v41                                 ; 2c46533c
	v_lshlrev_b32_e32 v41, 4, v58                               ; 24527484
	v_mul_f32_e32 v37, v37, v39                                 ; 0a4a4f25
	v_mac_f32_e32 v35, v59, v52                                 ; 2c46693b
	v_lshl_add_u32 v58, v58, 7, v41                             ; d1fd003a 04a50f3a
	v_mac_f32_e32 v37, v50, v49                                 ; 2c4a6332
	v_cvt_f32_ubyte1_e32 v49, v34                               ; 7e622522
	v_cvt_f32_ubyte0_e32 v34, v34                               ; 7e442322
	v_mov_b32_e32 v41, v33                                      ; 7e520321
	v_add_u32_e32 v50, 4, v58                                   ; 68647484
	v_mac_f32_e32 v37, v54, v49                                 ; 2c4a6336
	v_add_u32_e32 v52, v40, v50                                 ; 68686528
	v_add_u32_e32 v54, v50, v38                                 ; 686c4d32
	v_add_u32_e32 v50, v50, v43                                 ; 68645732
	v_mac_f32_e32 v37, v47, v34                                 ; 2c4a452f
	v_cvt_f32_f16_sdwa v34, v57 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e4416f9 00050639
	v_mad_f32 v12, -v34, v35, v12                               ; d1c1000c 24324722
	v_add_u32_e32 v35, 16, v58                                  ; 68467490
	v_add_u32_e32 v39, v35, v4                                  ; 684e0923
	v_add_u32_e32 v35, v35, v46                                 ; 68465d23
	buffer_load_dword v58, v58, s[24:27], 0 offen               ; e0501000 80063a3a
	buffer_load_dwordx2 v[33:34], v52, s[24:27], 0 offen        ; e0541000 80062134
	buffer_load_ushort v50, v50, s[24:27], 0 offen              ; e0481000 80063232
	buffer_load_dword v39, v39, s[24:27], 0 offen               ; e0501000 80062727
	buffer_load_dword v35, v35, s[24:27], 0 offen               ; e0501000 80062323
	v_cvt_f32_f16_e32 v57, v57                                  ; 7e721739
	s_add_u32 s23, s16, 11                                      ; 80178b10
	s_waitcnt vmcnt(8)                                          ; bf8c3f78
	v_alignbyte_b32 v55, v56, v55, v44                          ; d1cf0037 04b26f38
	v_alignbyte_b32 v56, v56, v56, v44                          ; d1cf0038 04b27138
	s_waitcnt vmcnt(7)                                          ; bf8c3f77
	v_lshl_or_b32 v36, v36, 12, v36                             ; d2000024 04911924
	s_waitcnt vmcnt(6)                                          ; bf8c3f76
	v_and_b32_e32 v52, s5, v53                                  ; 26686a05
	v_mac_f32_e32 v12, v57, v37                                 ; 2c184b39
	s_mul_i32 s23, s23, s3                                      ; 92170317
	v_mov_b32_sdwa v55, v56 dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_0 ; 7e6e02f9 00041538
	v_cvt_f32_ubyte2_e32 v57, v52                               ; 7e722734
	v_cvt_f32_ubyte3_e32 v56, v52                               ; 7e702934
	v_cvt_f32_ubyte1_e32 v37, v52                               ; 7e4a2534
	v_cvt_f32_ubyte0_e32 v52, v52                               ; 7e682334
	v_lshrrev_b32_e32 v53, 4, v53                               ; 206a6a84
	s_add_u32 s23, s18, s23                                     ; 80171712
	v_and_b32_e32 v49, s9, v55                                  ; 26626e09
	v_and_b32_e32 v55, s10, v55                                 ; 266e6e0a
	v_mul_f32_e32 v56, v27, v56                                 ; 0a70711b
	v_and_b32_e32 v53, s5, v53                                  ; 266a6a05
	v_add_u32_e32 v47, s23, v0                                  ; 685e0017
	v_lshrrev_b32_e32 v49, 2, v49                               ; 20626282
	v_mac_f32_e32 v56, v26, v57                                 ; 2c70731a
	v_cvt_f32_ubyte3_e32 v44, v53                               ; 7e582935
	v_and_or_b32 v36, s5, v36, v49                              ; d2010024 04c64805
	v_cvt_f32_ubyte2_e32 v49, v53                               ; 7e622735
	v_mac_f32_e32 v56, v25, v37                                 ; 2c704b19
	v_mul_f32_e32 v44, v31, v44                                 ; 0a58591f
	v_mac_f32_e32 v56, v24, v52                                 ; 2c706918
	v_cvt_f32_ubyte1_e32 v52, v53                               ; 7e682535
	v_cvt_f32_ubyte0_e32 v53, v53                               ; 7e6a2335
	v_mac_f32_e32 v44, v30, v49                                 ; 2c58631e
	v_mac_f32_e32 v44, v29, v52                                 ; 2c58691d
	v_mac_f32_e32 v44, v28, v53                                 ; 2c586b1c
	s_waitcnt vmcnt(5)                                          ; bf8c3f75
	v_and_b32_e32 v53, s5, v51                                  ; 266a6605
	v_lshrrev_b32_e32 v51, 4, v51                               ; 20666684
	v_cvt_f32_ubyte1_e32 v49, v53                               ; 7e622535
	v_cvt_f32_ubyte2_e32 v37, v53                               ; 7e4a2735
	v_cvt_f32_ubyte3_e32 v57, v53                               ; 7e722935
	v_cvt_f32_ubyte0_e32 v53, v53                               ; 7e6a2335
	v_and_b32_e32 v51, s5, v51                                  ; 26666605
	v_mul_f32_e32 v57, v45, v57                                 ; 0a72732d
	v_cvt_f32_ubyte3_e32 v52, v51                               ; 7e682933
	v_mac_f32_e32 v57, v42, v37                                 ; 2c724b2a
	v_cvt_f32_ubyte1_e32 v37, v51                               ; 7e4a2533
	v_mul_f32_e32 v52, v23, v52                                 ; 0a686917
	v_mac_f32_e32 v57, v41, v49                                 ; 2c726329
	v_cvt_f32_ubyte3_e32 v49, v36                               ; 7e622924
	v_mac_f32_e32 v57, v32, v53                                 ; 2c726b20
	v_cvt_f32_ubyte2_e32 v53, v51                               ; 7e6a2733
	v_cvt_f32_ubyte0_e32 v51, v51                               ; 7e662333
	v_mul_f32_e32 v49, v62, v49                                 ; 0a62633e
	v_mac_f32_e32 v52, v22, v53                                 ; 2c686b16
	v_cvt_f32_ubyte3_e32 v53, v55                               ; 7e6a2937
	v_mac_f32_e32 v52, v21, v37                                 ; 2c684b15
	v_cvt_f32_ubyte2_e32 v37, v55                               ; 7e4a2737
	v_mac_f32_e32 v52, v20, v51                                 ; 2c686714
	v_cvt_f32_ubyte2_e32 v51, v36                               ; 7e662724
	v_mac_f32_e32 v49, v61, v51                                 ; 2c62673d
	v_cvt_f32_ubyte1_e32 v51, v36                               ; 7e662524
	v_cvt_f32_ubyte0_e32 v36, v36                               ; 7e482324
	v_mac_f32_e32 v49, v60, v53                                 ; 2c626b3c
	v_lshlrev_b32_e32 v53, 4, v47                               ; 246a5e84
	v_mul_f32_e32 v52, v52, v51                                 ; 0a686734
	v_cvt_f32_f16_sdwa v51, v48 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e6616f9 00050630
	v_mac_f32_e32 v49, v59, v37                                 ; 2c624b3b
	v_lshl_add_u32 v47, v47, 7, v53                             ; d1fd002f 04d50f2f
	v_mac_f32_e32 v52, v57, v36                                 ; 2c684939
	v_cvt_f32_ubyte1_e32 v57, v55                               ; 7e722537
	v_cvt_f32_ubyte0_e32 v55, v55                               ; 7e6e2337
	v_add_u32_e32 v36, 4, v47                                   ; 68485e84
	v_add_u32_e32 v53, 16, v47                                  ; 686a5e90
	v_mac_f32_e32 v52, v44, v57                                 ; 2c68732c
	v_add_u32_e32 v37, v40, v36                                 ; 684a4928
	v_add_u32_e32 v44, v36, v38                                 ; 68584d24
	v_add_u32_e32 v36, v36, v43                                 ; 68485724
	v_mac_f32_e32 v52, v56, v55                                 ; 2c686f38
	v_add_u32_e32 v55, v53, v4                                  ; 686e0935
	v_add_u32_e32 v53, v53, v46                                 ; 686a5d35
	buffer_load_dword v47, v47, s[24:27], 0 offen               ; e0501000 80062f2f
	buffer_load_dwordx2 v[56:57], v37, s[24:27], 0 offen        ; e0541000 80063825
	buffer_load_ushort v36, v36, s[24:27], 0 offen              ; e0481000 80062424
	buffer_load_dword v55, v55, s[24:27], 0 offen               ; e0501000 80063737
	buffer_load_dword v53, v53, s[24:27], 0 offen               ; e0501000 80063535
	v_mad_f32 v13, -v51, v49, v13                               ; d1c1000d 24366333
	v_cvt_f32_f16_e32 v48, v48                                  ; 7e601730
	s_add_u32 s28, s16, 12                                      ; 801c8c10
	s_waitcnt vmcnt(8)                                          ; bf8c3f78
	v_alignbyte_b32 v33, v34, v33, v54                          ; d1cf0021 04da4322
	v_alignbyte_b32 v34, v34, v34, v54                          ; d1cf0022 04da4522
	s_waitcnt vmcnt(7)                                          ; bf8c3f77
	v_lshl_or_b32 v50, v50, 12, v50                             ; d2000032 04c91932
	s_waitcnt vmcnt(6)                                          ; bf8c3f76
	v_and_b32_e32 v49, s5, v39                                  ; 26624e05
	v_mac_f32_e32 v13, v48, v52                                 ; 2c1a6930
	s_mul_i32 s28, s28, s3                                      ; 921c031c
	v_mov_b32_sdwa v33, v34 dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_0 ; 7e4202f9 00041522
	v_cvt_f32_ubyte1_e32 v54, v49                               ; 7e6c2531
	v_cvt_f32_ubyte3_e32 v51, v49                               ; 7e662931
	v_cvt_f32_ubyte2_e32 v52, v49                               ; 7e682731
	v_cvt_f32_ubyte0_e32 v49, v49                               ; 7e622331
	v_lshrrev_b32_e32 v39, 4, v39                               ; 204e4e84
	s_add_u32 s28, s18, s28                                     ; 801c1c12
	v_and_b32_e32 v48, s9, v33                                  ; 26604209
	v_and_b32_e32 v33, s10, v33                                 ; 2642420a
	v_mul_f32_e32 v51, v27, v51                                 ; 0a66671b
	v_and_b32_e32 v39, s5, v39                                  ; 264e4e05
	v_add_u32_e32 v37, s28, v0                                  ; 684a001c
	v_lshrrev_b32_e32 v48, 2, v48                               ; 20606082
	v_mac_f32_e32 v51, v26, v52                                 ; 2c66691a
	s_waitcnt vmcnt(5)                                          ; bf8c3f75
	v_and_b32_e32 v52, s5, v35                                  ; 26684605
	v_cvt_f32_ubyte3_e32 v34, v39                               ; 7e442927
	v_and_or_b32 v50, s5, v50, v48                              ; d2010032 04c26405
	v_cvt_f32_ubyte2_e32 v48, v39                               ; 7e602727
	v_mac_f32_e32 v51, v25, v54                                 ; 2c666d19
	v_cvt_f32_ubyte3_e32 v54, v52                               ; 7e6c2934
	v_mul_f32_e32 v34, v31, v34                                 ; 0a44451f
	v_lshrrev_b32_e32 v35, 4, v35                               ; 20464684
	v_mac_f32_e32 v51, v24, v49                                 ; 2c666318
	v_cvt_f32_ubyte1_e32 v49, v39                               ; 7e622527
	v_cvt_f32_ubyte0_e32 v39, v39                               ; 7e4e2327
	v_mul_f32_e32 v54, v45, v54                                 ; 0a6c6d2d
	v_mac_f32_e32 v34, v30, v48                                 ; 2c44611e
	v_cvt_f32_ubyte1_e32 v48, v52                               ; 7e602534
	v_and_b32_e32 v35, s5, v35                                  ; 26464605
	v_mac_f32_e32 v34, v29, v49                                 ; 2c44631d
	v_cvt_f32_ubyte3_e32 v49, v35                               ; 7e622923
	v_mac_f32_e32 v34, v28, v39                                 ; 2c444f1c
	v_cvt_f32_ubyte2_e32 v39, v52                               ; 7e4e2734
	v_cvt_f32_ubyte0_e32 v52, v52                               ; 7e682334
	v_mul_f32_e32 v49, v23, v49                                 ; 0a626317
	v_mac_f32_e32 v54, v42, v39                                 ; 2c6c4f2a
	v_cvt_f32_ubyte1_e32 v39, v35                               ; 7e4e2523
	v_mac_f32_e32 v54, v41, v48                                 ; 2c6c6129
	v_cvt_f32_ubyte3_e32 v48, v50                               ; 7e602932
	v_mac_f32_e32 v54, v32, v52                                 ; 2c6c6920
	v_cvt_f32_ubyte2_e32 v52, v35                               ; 7e682723
	v_cvt_f32_ubyte0_e32 v35, v35                               ; 7e462323
	v_mul_f32_e32 v48, v62, v48                                 ; 0a60613e
	v_mac_f32_e32 v49, v22, v52                                 ; 2c626916
	v_cvt_f32_ubyte2_e32 v52, v50                               ; 7e682732
	v_mac_f32_e32 v49, v21, v39                                 ; 2c624f15
	v_cvt_f32_ubyte2_e32 v39, v33                               ; 7e4e2721
	v_mac_f32_e32 v48, v61, v52                                 ; 2c60693d
	v_cvt_f32_ubyte1_e32 v52, v50                               ; 7e682532
	v_cvt_f32_ubyte0_e32 v50, v50                               ; 7e642332
	v_mac_f32_e32 v49, v20, v35                                 ; 2c624714
	v_cvt_f32_ubyte3_e32 v35, v33                               ; 7e462921
	v_mul_f32_e32 v49, v49, v52                                 ; 0a626931
	v_mac_f32_e32 v48, v60, v35                                 ; 2c60473c
	v_lshlrev_b32_e32 v35, 4, v37                               ; 24464a84
	v_mac_f32_e32 v49, v54, v50                                 ; 2c626536
	v_mac_f32_e32 v48, v59, v39                                 ; 2c604f3b
	v_cvt_f32_ubyte1_e32 v39, v33                               ; 7e4e2521
	v_cvt_f32_ubyte0_e32 v33, v33                               ; 7e422321
	v_lshl_add_u32 v37, v37, 7, v35                             ; d1fd0025 048d0f25
	v_mac_f32_e32 v49, v34, v39                                 ; 2c624f22
	v_add_u32_e32 v34, 16, v37                                  ; 68444a90
	v_add_u32_e32 v50, 4, v37                                   ; 68644a84
	v_mac_f32_e32 v49, v51, v33                                 ; 2c624333
	v_add_u32_e32 v35, v34, v4                                  ; 68460922
	v_add_u32_e32 v34, v34, v46                                 ; 68445d22
	v_add_u32_e32 v54, v50, v38                                 ; 686c4d32
	v_add_u32_e32 v52, v40, v50                                 ; 68686528
	v_add_u32_e32 v50, v50, v43                                 ; 68645732
	buffer_load_dword v37, v37, s[24:27], 0 offen               ; e0501000 80062525
	buffer_load_dwordx2 v[51:52], v52, s[24:27], 0 offen        ; e0541000 80063334
	buffer_load_ushort v50, v50, s[24:27], 0 offen              ; e0481000 80063232
	buffer_load_dword v35, v35, s[24:27], 0 offen               ; e0501000 80062323
	buffer_load_dword v34, v34, s[24:27], 0 offen               ; e0501000 80062222
	v_cvt_f32_f16_sdwa v33, v58 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e4216f9 0005063a
	v_cvt_f32_f16_e32 v58, v58                                  ; 7e74173a
	s_add_u32 s29, s16, 13                                      ; 801d8d10
	s_waitcnt vmcnt(8)                                          ; bf8c3f78
	v_alignbyte_b32 v56, v57, v56, v44                          ; d1cf0038 04b27139
	v_alignbyte_b32 v57, v57, v57, v44                          ; d1cf0039 04b27339
	s_waitcnt vmcnt(7)                                          ; bf8c3f77
	v_lshl_or_b32 v36, v36, 12, v36                             ; d2000024 04911924
	s_waitcnt vmcnt(6)                                          ; bf8c3f76
	v_and_b32_e32 v39, s5, v55                                  ; 264e6e05
	v_mad_f32 v14, -v33, v48, v14                               ; d1c1000e 243a6121
	s_mul_i32 s29, s29, s3                                      ; 921d031d
	v_mov_b32_sdwa v56, v57 dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_0 ; 7e7002f9 00041539
	v_cvt_f32_ubyte2_e32 v48, v39                               ; 7e602727
	v_cvt_f32_ubyte3_e32 v44, v39                               ; 7e582927
	v_mac_f32_e32 v14, v58, v49                                 ; 2c1c633a
	v_cvt_f32_ubyte1_e32 v49, v39                               ; 7e622527
	v_cvt_f32_ubyte0_e32 v39, v39                               ; 7e4e2327
	v_lshrrev_b32_e32 v55, 4, v55                               ; 206e6e84
	s_add_u32 s29, s18, s29                                     ; 801d1d12
	v_and_b32_e32 v33, s9, v56                                  ; 26427009
	v_and_b32_e32 v56, s10, v56                                 ; 2670700a
	v_mul_f32_e32 v44, v27, v44                                 ; 0a58591b
	v_and_b32_e32 v55, s5, v55                                  ; 266e6e05
	v_add_u32_e32 v58, s29, v0                                  ; 6874001d
	v_lshrrev_b32_e32 v33, 2, v33                               ; 20424282
	v_mac_f32_e32 v44, v26, v48                                 ; 2c58611a
	s_waitcnt vmcnt(5)                                          ; bf8c3f75
	v_and_b32_e32 v48, s5, v53                                  ; 26606a05
	v_cvt_f32_ubyte3_e32 v57, v55                               ; 7e722937
	v_and_or_b32 v36, s5, v36, v33                              ; d2010024 04864805
	v_cvt_f32_ubyte2_e32 v33, v55                               ; 7e422737
	v_mac_f32_e32 v44, v25, v49                                 ; 2c586319
	v_cvt_f32_ubyte3_e32 v49, v48                               ; 7e622930
	v_mul_f32_e32 v57, v31, v57                                 ; 0a72731f
	v_lshrrev_b32_e32 v53, 4, v53                               ; 206a6a84
	v_mac_f32_e32 v44, v24, v39                                 ; 2c584f18
	v_cvt_f32_ubyte1_e32 v39, v55                               ; 7e4e2537
	v_cvt_f32_ubyte0_e32 v55, v55                               ; 7e6e2337
	v_mul_f32_e32 v49, v45, v49                                 ; 0a62632d
	v_mac_f32_e32 v57, v30, v33                                 ; 2c72431e
	v_cvt_f32_ubyte1_e32 v33, v48                               ; 7e422530
	v_and_b32_e32 v53, s5, v53                                  ; 266a6a05
	v_mac_f32_e32 v57, v29, v39                                 ; 2c724f1d
	v_cvt_f32_ubyte3_e32 v39, v53                               ; 7e4e2935
	v_mac_f32_e32 v57, v28, v55                                 ; 2c726f1c
	v_cvt_f32_ubyte2_e32 v55, v48                               ; 7e6e2730
	v_cvt_f32_ubyte0_e32 v48, v48                               ; 7e602330
	v_mul_f32_e32 v39, v23, v39                                 ; 0a4e4f17
	v_mac_f32_e32 v49, v42, v55                                 ; 2c626f2a
	v_cvt_f32_ubyte1_e32 v55, v53                               ; 7e6e2535
	v_mac_f32_e32 v49, v41, v33                                 ; 2c624329
	v_cvt_f32_ubyte3_e32 v33, v36                               ; 7e422924
	v_mac_f32_e32 v49, v32, v48                                 ; 2c626120
	v_cvt_f32_ubyte2_e32 v48, v53                               ; 7e602735
	v_cvt_f32_ubyte0_e32 v53, v53                               ; 7e6a2335
	v_mul_f32_e32 v33, v62, v33                                 ; 0a42433e
	v_mac_f32_e32 v39, v22, v48                                 ; 2c4e6116
	v_cvt_f32_ubyte2_e32 v48, v36                               ; 7e602724
	v_mac_f32_e32 v39, v21, v55                                 ; 2c4e6f15
	v_cvt_f32_ubyte2_e32 v55, v56                               ; 7e6e2738
	v_mac_f32_e32 v33, v61, v48                                 ; 2c42613d
	v_cvt_f32_ubyte1_e32 v48, v36                               ; 7e602524
	v_cvt_f32_ubyte0_e32 v36, v36                               ; 7e482324
	v_mac_f32_e32 v39, v20, v53                                 ; 2c4e6b14
	v_cvt_f32_ubyte3_e32 v53, v56                               ; 7e6a2938
	v_mul_f32_e32 v39, v39, v48                                 ; 0a4e6127
	v_cvt_f32_f16_sdwa v48, v47 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e6016f9 0005062f
	v_mac_f32_e32 v33, v60, v53                                 ; 2c426b3c
	v_lshlrev_b32_e32 v53, 4, v58                               ; 246a7484
	v_mac_f32_e32 v39, v49, v36                                 ; 2c4e4931
	v_mac_f32_e32 v33, v59, v55                                 ; 2c426f3b
	v_cvt_f32_ubyte1_e32 v55, v56                               ; 7e6e2538
	v_cvt_f32_ubyte0_e32 v56, v56                               ; 7e702338
	v_lshl_add_u32 v58, v58, 7, v53                             ; d1fd003a 04d50f3a
	v_mac_f32_e32 v39, v57, v55                                 ; 2c4e6f39
	v_add_u32_e32 v57, 4, v58                                   ; 68727484
	v_add_u32_e32 v49, 16, v58                                  ; 68627490
	v_mac_f32_e32 v39, v44, v56                                 ; 2c4e712c
	v_add_u32_e32 v36, v40, v57                                 ; 68487328
	v_add_u32_e32 v44, v57, v38                                 ; 68584d39
	v_add_u32_e32 v57, v57, v43                                 ; 68725739
	v_add_u32_e32 v53, v49, v4                                  ; 686a0931
	v_add_u32_e32 v49, v49, v46                                 ; 68625d31
	buffer_load_dword v58, v58, s[24:27], 0 offen               ; e0501000 80063a3a
	buffer_load_dwordx2 v[55:56], v36, s[24:27], 0 offen        ; e0541000 80063724
	buffer_load_ushort v57, v57, s[24:27], 0 offen              ; e0481000 80063939
	buffer_load_dword v53, v53, s[24:27], 0 offen               ; e0501000 80063535
	buffer_load_dword v49, v49, s[24:27], 0 offen               ; e0501000 80063131
	v_mad_f32 v15, -v48, v33, v15                               ; d1c1000f 243e4330
	v_cvt_f32_f16_e32 v47, v47                                  ; 7e5e172f
	s_add_u32 s30, s16, 14                                      ; 801e8e10
	s_waitcnt vmcnt(8)                                          ; bf8c3f78
	v_alignbyte_b32 v51, v52, v51, v54                          ; d1cf0033 04da6734
	v_alignbyte_b32 v52, v52, v52, v54                          ; d1cf0034 04da6934
	s_waitcnt vmcnt(7)                                          ; bf8c3f77
	v_lshl_or_b32 v50, v50, 12, v50                             ; d2000032 04c91932
	v_mac_f32_e32 v15, v47, v39                                 ; 2c1e4f2f
	s_waitcnt vmcnt(6)                                          ; bf8c3f76
	v_and_b32_e32 v39, s5, v35                                  ; 264e4605
	s_mul_i32 s30, s30, s3                                      ; 921e031e
	v_mov_b32_sdwa v51, v52 dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_0 ; 7e6602f9 00041534
	v_cvt_f32_ubyte2_e32 v48, v39                               ; 7e602727
	v_cvt_f32_ubyte3_e32 v47, v39                               ; 7e5e2927
	v_cvt_f32_ubyte1_e32 v52, v39                               ; 7e682527
	v_cvt_f32_ubyte0_e32 v39, v39                               ; 7e4e2327
	v_lshrrev_b32_e32 v35, 4, v35                               ; 20464684
	s_add_u32 s30, s18, s30                                     ; 801e1e12
	v_and_b32_e32 v36, s9, v51                                  ; 26486609
	v_and_b32_e32 v51, s10, v51                                 ; 2666660a
	v_mul_f32_e32 v47, v27, v47                                 ; 0a5e5f1b
	v_and_b32_e32 v35, s5, v35                                  ; 26464605
	v_add_u32_e32 v33, s30, v0                                  ; 6842001e
	v_lshrrev_b32_e32 v36, 2, v36                               ; 20484882
	v_mac_f32_e32 v47, v26, v48                                 ; 2c5e611a
	s_waitcnt vmcnt(5)                                          ; bf8c3f75
	v_and_b32_e32 v48, s5, v34                                  ; 26604405
	v_cvt_f32_ubyte3_e32 v54, v35                               ; 7e6c2923
	v_and_or_b32 v50, s5, v50, v36                              ; d2010032 04926405
	v_cvt_f32_ubyte2_e32 v36, v35                               ; 7e482723
	v_mac_f32_e32 v47, v25, v52                                 ; 2c5e6919
	v_cvt_f32_ubyte3_e32 v52, v48                               ; 7e682930
	v_mul_f32_e32 v54, v31, v54                                 ; 0a6c6d1f
	v_lshrrev_b32_e32 v34, 4, v34                               ; 20444484
	v_mac_f32_e32 v47, v24, v39                                 ; 2c5e4f18
	v_cvt_f32_ubyte1_e32 v39, v35                               ; 7e4e2523
	v_cvt_f32_ubyte0_e32 v35, v35                               ; 7e462323
	v_mul_f32_e32 v52, v45, v52                                 ; 0a68692d
	v_mac_f32_e32 v54, v30, v36                                 ; 2c6c491e
	v_cvt_f32_ubyte1_e32 v36, v48                               ; 7e482530
	v_and_b32_e32 v34, s5, v34                                  ; 26444405
	v_mac_f32_e32 v54, v29, v39                                 ; 2c6c4f1d
	v_cvt_f32_ubyte3_e32 v39, v34                               ; 7e4e2922
	v_mac_f32_e32 v54, v28, v35                                 ; 2c6c471c
	v_cvt_f32_ubyte2_e32 v35, v48                               ; 7e462730
	v_cvt_f32_ubyte0_e32 v48, v48                               ; 7e602330
	v_mul_f32_e32 v39, v23, v39                                 ; 0a4e4f17
	v_mac_f32_e32 v52, v42, v35                                 ; 2c68472a
	v_cvt_f32_ubyte1_e32 v35, v34                               ; 7e462522
	v_mac_f32_e32 v52, v41, v36                                 ; 2c684929
	v_cvt_f32_ubyte3_e32 v36, v50                               ; 7e482932
	v_mac_f32_e32 v52, v32, v48                                 ; 2c686120
	v_cvt_f32_ubyte2_e32 v48, v34                               ; 7e602722
	v_cvt_f32_ubyte0_e32 v34, v34                               ; 7e442322
	v_mul_f32_e32 v36, v62, v36                                 ; 0a48493e
	v_mac_f32_e32 v39, v22, v48                                 ; 2c4e6116
	v_cvt_f32_ubyte2_e32 v48, v50                               ; 7e602732
	v_mac_f32_e32 v39, v21, v35                                 ; 2c4e4715
	v_cvt_f32_ubyte2_e32 v35, v51                               ; 7e462733
	v_mac_f32_e32 v36, v61, v48                                 ; 2c48613d
	v_cvt_f32_ubyte1_e32 v48, v50                               ; 7e602532
	v_cvt_f32_ubyte0_e32 v50, v50                               ; 7e642332
	v_mac_f32_e32 v39, v20, v34                                 ; 2c4e4514
	v_cvt_f32_ubyte3_e32 v34, v51                               ; 7e442933
	v_mul_f32_e32 v39, v39, v48                                 ; 0a4e6127
	v_mac_f32_e32 v36, v60, v34                                 ; 2c48453c
	v_lshlrev_b32_e32 v34, 4, v33                               ; 24444284
	v_mac_f32_e32 v39, v52, v50                                 ; 2c4e6534
	v_cvt_f32_f16_sdwa v52, v37 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e6816f9 00050625
	v_mac_f32_e32 v36, v59, v35                                 ; 2c48473b
	v_cvt_f32_ubyte1_e32 v35, v51                               ; 7e462533
	v_cvt_f32_ubyte0_e32 v51, v51                               ; 7e662333
	v_lshl_add_u32 v33, v33, 7, v34                             ; d1fd0021 04890f21
	v_mad_f32 v16, -v52, v36, v16                               ; d1c10010 24424934
	v_mac_f32_e32 v39, v54, v35                                 ; 2c4e4736
	v_add_u32_e32 v54, 16, v33                                  ; 686c4290
	v_add_u32_e32 v48, 4, v33                                   ; 68604284
	v_mac_f32_e32 v39, v47, v51                                 ; 2c4e672f
	v_add_u32_e32 v34, v54, v4                                  ; 68440936
	v_add_u32_e32 v54, v54, v46                                 ; 686c5d36
	v_add_u32_e32 v50, v40, v48                                 ; 68646128
	v_add_u32_e32 v51, v48, v38                                 ; 68664d30
	v_add_u32_e32 v48, v48, v43                                 ; 68605730
	buffer_load_dword v33, v33, s[24:27], 0 offen               ; e0501000 80062121
	buffer_load_dwordx2 v[35:36], v50, s[24:27], 0 offen        ; e0541000 80062332
	buffer_load_ushort v48, v48, s[24:27], 0 offen              ; e0481000 80063030
	buffer_load_dword v34, v34, s[24:27], 0 offen               ; e0501000 80062222
	buffer_load_dword v54, v54, s[24:27], 0 offen               ; e0501000 80063636
	v_cvt_f32_f16_e32 v37, v37                                  ; 7e4a1725
	s_add_u32 s31, s16, 15                                      ; 801f8f10
	s_waitcnt vmcnt(8)                                          ; bf8c3f78
	v_alignbyte_b32 v55, v56, v55, v44                          ; d1cf0037 04b26f38
	v_alignbyte_b32 v56, v56, v56, v44                          ; d1cf0038 04b27138
	s_waitcnt vmcnt(7)                                          ; bf8c3f77
	v_lshl_or_b32 v57, v57, 12, v57                             ; d2000039 04e51939
	s_waitcnt vmcnt(6)                                          ; bf8c3f76
	v_and_b32_e32 v44, s5, v53                                  ; 26586a05
	v_mac_f32_e32 v16, v37, v39                                 ; 2c204f25
	s_mul_i32 s31, s31, s3                                      ; 921f031f
	v_mov_b32_sdwa v55, v56 dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_0 ; 7e6e02f9 00041538
	v_cvt_f32_ubyte1_e32 v52, v44                               ; 7e68252c
	v_cvt_f32_ubyte3_e32 v47, v44                               ; 7e5e292c
	v_cvt_f32_ubyte2_e32 v50, v44                               ; 7e64272c
	v_cvt_f32_ubyte0_e32 v44, v44                               ; 7e58232c
	v_lshrrev_b32_e32 v53, 4, v53                               ; 206a6a84
	s_add_u32 s31, s18, s31                                     ; 801f1f12
	v_and_b32_e32 v39, s9, v55                                  ; 264e6e09
	v_and_b32_e32 v55, s10, v55                                 ; 266e6e0a
	v_mul_f32_e32 v47, v27, v47                                 ; 0a5e5f1b
	v_and_b32_e32 v53, s5, v53                                  ; 266a6a05
	v_add_u32_e32 v37, s31, v0                                  ; 684a001f
	v_lshrrev_b32_e32 v39, 2, v39                               ; 204e4e82
	v_mac_f32_e32 v47, v26, v50                                 ; 2c5e651a
	s_waitcnt vmcnt(5)                                          ; bf8c3f75
	v_and_b32_e32 v50, s5, v49                                  ; 26646205
	v_cvt_f32_ubyte3_e32 v56, v53                               ; 7e702935
	v_and_or_b32 v57, s5, v57, v39                              ; d2010039 049e7205
	v_cvt_f32_ubyte2_e32 v39, v53                               ; 7e4e2735
	v_mac_f32_e32 v47, v25, v52                                 ; 2c5e6919
	v_cvt_f32_ubyte3_e32 v52, v50                               ; 7e682932
	v_mul_f32_e32 v56, v31, v56                                 ; 0a70711f
	v_lshrrev_b32_e32 v49, 4, v49                               ; 20626284
	v_mac_f32_e32 v47, v24, v44                                 ; 2c5e5918
	v_cvt_f32_ubyte1_e32 v44, v53                               ; 7e582535
	v_cvt_f32_ubyte0_e32 v53, v53                               ; 7e6a2335
	v_mul_f32_e32 v52, v45, v52                                 ; 0a68692d
	v_mac_f32_e32 v56, v30, v39                                 ; 2c704f1e
	v_cvt_f32_ubyte1_e32 v39, v50                               ; 7e4e2532
	v_and_b32_e32 v49, s5, v49                                  ; 26626205
	v_mac_f32_e32 v56, v29, v44                                 ; 2c70591d
	v_cvt_f32_ubyte3_e32 v44, v49                               ; 7e582931
	v_mac_f32_e32 v56, v28, v53                                 ; 2c706b1c
	v_cvt_f32_ubyte2_e32 v53, v50                               ; 7e6a2732
	v_cvt_f32_ubyte0_e32 v50, v50                               ; 7e642332
	v_mul_f32_e32 v44, v23, v44                                 ; 0a585917
	v_mac_f32_e32 v52, v42, v53                                 ; 2c686b2a
	v_cvt_f32_ubyte1_e32 v53, v49                               ; 7e6a2531
	v_mac_f32_e32 v52, v41, v39                                 ; 2c684f29
	v_cvt_f32_ubyte3_e32 v39, v57                               ; 7e4e2939
	v_mac_f32_e32 v52, v32, v50                                 ; 2c686520
	v_cvt_f32_ubyte2_e32 v50, v49                               ; 7e642731
	v_cvt_f32_ubyte0_e32 v49, v49                               ; 7e622331
	v_mul_f32_e32 v39, v62, v39                                 ; 0a4e4f3e
	v_mac_f32_e32 v44, v22, v50                                 ; 2c586516
	v_cvt_f32_ubyte3_e32 v50, v55                               ; 7e642937
	v_mac_f32_e32 v44, v21, v53                                 ; 2c586b15
	v_cvt_f32_ubyte2_e32 v53, v55                               ; 7e6a2737
	v_mac_f32_e32 v44, v20, v49                                 ; 2c586314
	v_cvt_f32_ubyte2_e32 v49, v57                               ; 7e622739
	v_mac_f32_e32 v39, v61, v49                                 ; 2c4e633d
	v_cvt_f32_ubyte1_e32 v49, v57                               ; 7e622539
	v_cvt_f32_ubyte0_e32 v57, v57                               ; 7e722339
	v_mac_f32_e32 v39, v60, v50                                 ; 2c4e653c
	v_lshlrev_b32_e32 v50, 4, v37                               ; 24644a84
	v_mul_f32_e32 v44, v44, v49                                 ; 0a58632c
	v_mac_f32_e32 v39, v59, v53                                 ; 2c4e6b3b
	v_lshl_add_u32 v37, v37, 7, v50                             ; d1fd0025 04c90f25
	v_mac_f32_e32 v44, v52, v57                                 ; 2c587334
	v_cvt_f32_ubyte1_e32 v52, v55                               ; 7e682537
	v_add_u32_e32 v53, 4, v37                                   ; 686a4a84
	v_mac_f32_e32 v44, v56, v52                                 ; 2c586938
	v_add_u32_e32 v56, 16, v37                                  ; 68704a90
	v_add_u32_e32 v40, v40, v53                                 ; 68506b28
	v_add_u32_e32 v38, v53, v38                                 ; 684c4d35
	v_add_u32_e32 v53, v53, v43                                 ; 686a5735
	v_add_u32_e32 v57, v56, v4                                  ; 68720938
	v_add_u32_e32 v56, v56, v46                                 ; 68705d38
	buffer_load_dword v37, v37, s[24:27], 0 offen               ; e0501000 80062525
	buffer_load_dwordx2 v[49:50], v40, s[24:27], 0 offen        ; e0541000 80063128
	buffer_load_ushort v53, v53, s[24:27], 0 offen              ; e0481000 80063535
	buffer_load_dword v57, v57, s[24:27], 0 offen               ; e0501000 80063939
	buffer_load_dword v56, v56, s[24:27], 0 offen               ; e0501000 80063838
	v_cvt_f32_ubyte0_e32 v55, v55                               ; 7e6e2337
	v_cvt_f32_f16_sdwa v52, v58 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e6816f9 0005063a
	v_cvt_f32_f16_e32 v58, v58                                  ; 7e74173a
	v_add_u32_e32 v0, 4, v0                                     ; 68000084
	s_waitcnt vmcnt(8)                                          ; bf8c3f78
	v_alignbyte_b32 v35, v36, v35, v51                          ; d1cf0023 04ce4724
	v_alignbyte_b32 v36, v36, v36, v51                          ; d1cf0024 04ce4924
	v_mac_f32_e32 v44, v47, v55                                 ; 2c586f2f
	v_cvt_f32_f16_sdwa v55, v33 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e6e16f9 00050621
	v_cvt_f32_f16_e32 v33, v33                                  ; 7e421721
	v_mad_f32 v17, -v52, v39, v17                               ; d1c10011 24464f34
	s_waitcnt vmcnt(7)                                          ; bf8c3f77
	v_lshl_or_b32 v48, v48, 12, v48                             ; d2000030 04c11930
	v_mov_b32_sdwa v35, v36 dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_0 ; 7e4602f9 00041524
	v_mac_f32_e32 v17, v58, v44                                 ; 2c22593a
	s_waitcnt vmcnt(6)                                          ; bf8c3f76
	v_and_b32_e32 v44, s5, v34                                  ; 26584405
	v_and_b32_e32 v58, s9, v35                                  ; 26744609
	v_and_b32_e32 v35, s10, v35                                 ; 2646460a
	v_cvt_f32_ubyte2_e32 v47, v44                               ; 7e5e272c
	v_cvt_f32_ubyte3_e32 v46, v44                               ; 7e5c292c
	v_cvt_f32_ubyte1_e32 v51, v44                               ; 7e66252c
	v_cvt_f32_ubyte0_e32 v44, v44                               ; 7e58232c
	v_lshrrev_b32_e32 v58, 2, v58                               ; 20747482
	v_cvt_f32_ubyte3_e32 v36, v35                               ; 7e482923
	v_lshrrev_b32_e32 v34, 4, v34                               ; 20444484
	v_cvt_f32_ubyte1_e32 v40, v35                               ; 7e502523
	v_cvt_f32_ubyte2_e32 v39, v35                               ; 7e4e2723
	v_cvt_f32_ubyte0_e32 v35, v35                               ; 7e462323
	v_mul_f32_e32 v46, v27, v46                                 ; 0a5c5d1b
	v_and_or_b32 v48, s5, v48, v58                              ; d2010030 04ea6005
	v_and_b32_e32 v34, s5, v34                                  ; 26444405
	v_mac_f32_e32 v46, v26, v47                                 ; 2c5c5f1a
	s_waitcnt vmcnt(5)                                          ; bf8c3f75
	v_and_b32_e32 v47, s5, v54                                  ; 265e6c05
	v_cvt_f32_ubyte3_e32 v43, v48                               ; 7e562930
	v_cvt_f32_ubyte2_e32 v58, v34                               ; 7e742722
	v_cvt_f32_ubyte3_e32 v52, v34                               ; 7e682922
	v_mac_f32_e32 v46, v25, v51                                 ; 2c5c6719
	v_cvt_f32_ubyte3_e32 v51, v47                               ; 7e66292f
	v_mul_f32_e32 v43, v62, v43                                 ; 0a56573e
	v_mul_f32_e32 v52, v31, v52                                 ; 0a68691f
	v_lshrrev_b32_e32 v54, 4, v54                               ; 206c6c84
	v_mac_f32_e32 v46, v24, v44                                 ; 2c5c5918
	v_cvt_f32_ubyte1_e32 v44, v34                               ; 7e582522
	v_cvt_f32_ubyte0_e32 v34, v34                               ; 7e442322
	v_mul_f32_e32 v51, v45, v51                                 ; 0a66672d
	v_mac_f32_e32 v52, v30, v58                                 ; 2c68751e
	v_cvt_f32_ubyte2_e32 v58, v47                               ; 7e74272f
	v_and_b32_e32 v54, s5, v54                                  ; 266c6c05
	v_mac_f32_e32 v52, v29, v44                                 ; 2c68591d
	v_mac_f32_e32 v51, v42, v58                                 ; 2c66752a
	v_cvt_f32_ubyte3_e32 v44, v54                               ; 7e582936
	v_cvt_f32_ubyte1_e32 v58, v54                               ; 7e742536
	v_mac_f32_e32 v52, v28, v34                                 ; 2c68451c
	v_cvt_f32_ubyte1_e32 v34, v47                               ; 7e44252f
	v_cvt_f32_ubyte0_e32 v47, v47                               ; 7e5e232f
	v_mul_f32_e32 v44, v23, v44                                 ; 0a585917
	v_mac_f32_e32 v51, v41, v34                                 ; 2c664529
	v_cvt_f32_ubyte2_e32 v34, v48                               ; 7e442730
	v_mac_f32_e32 v51, v32, v47                                 ; 2c665f20
	v_cvt_f32_ubyte2_e32 v47, v54                               ; 7e5e2736
	v_cvt_f32_ubyte0_e32 v54, v54                               ; 7e6c2336
	v_mac_f32_e32 v43, v61, v34                                 ; 2c56453d
	v_mac_f32_e32 v44, v22, v47                                 ; 2c585f16
	v_mac_f32_e32 v43, v60, v36                                 ; 2c56493c
	v_cvt_f32_ubyte1_e32 v36, v48                               ; 7e482530
	v_cvt_f32_ubyte0_e32 v48, v48                               ; 7e602330
	v_mac_f32_e32 v44, v21, v58                                 ; 2c587515
	v_mac_f32_e32 v43, v59, v39                                 ; 2c564f3b
	v_mac_f32_e32 v44, v20, v54                                 ; 2c586d14
	v_mad_f32 v18, -v55, v43, v18                               ; d1c10012 244a5737
	v_mul_f32_e32 v44, v44, v36                                 ; 0a58492c
	v_mac_f32_e32 v44, v51, v48                                 ; 2c586133
	v_mac_f32_e32 v44, v52, v40                                 ; 2c585134
	v_mac_f32_e32 v44, v46, v35                                 ; 2c58472e
	s_waitcnt vmcnt(4)                                          ; bf8c3f74
	v_cvt_f32_f16_sdwa v39, v37 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e4e16f9 00050625
	v_cvt_f32_f16_e32 v37, v37                                  ; 7e4a1725
	v_mac_f32_e32 v18, v33, v44                                 ; 2c245921
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_alignbyte_b32 v49, v50, v49, v38                          ; d1cf0031 049a6332
	v_alignbyte_b32 v50, v50, v50, v38                          ; d1cf0032 049a6532
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_lshl_or_b32 v53, v53, 12, v53                             ; d2000035 04d51935
	v_mov_b32_sdwa v49, v50 dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_0 ; 7e6202f9 00041532
	v_and_b32_e32 v40, s9, v49                                  ; 26506209
	v_and_b32_e32 v49, s10, v49                                 ; 2662620a
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v51, s5, v57                                  ; 26667205
	v_lshrrev_b32_e32 v40, 2, v40                               ; 20505082
	v_cvt_f32_ubyte1_e32 v46, v49                               ; 7e5c2531
	v_cvt_f32_ubyte2_e32 v44, v49                               ; 7e582731
	v_cvt_f32_ubyte3_e32 v43, v49                               ; 7e562931
	v_cvt_f32_ubyte0_e32 v49, v49                               ; 7e622331
	v_cvt_f32_ubyte3_e32 v52, v51                               ; 7e682933
	v_cvt_f32_ubyte2_e32 v54, v51                               ; 7e6c2733
	v_and_or_b32 v53, s5, v53, v40                              ; d2010035 04a26a05
	v_cvt_f32_ubyte1_e32 v55, v51                               ; 7e6e2533
	v_cvt_f32_ubyte0_e32 v51, v51                               ; 7e662333
	v_mul_f32_e32 v27, v27, v52                                 ; 0a36691b
	v_lshrrev_b32_e32 v57, 4, v57                               ; 20727284
	v_cvt_f32_ubyte2_e32 v48, v53                               ; 7e602735
	v_cvt_f32_ubyte3_e32 v47, v53                               ; 7e5e2935
	v_cvt_f32_ubyte1_e32 v50, v53                               ; 7e642535
	v_cvt_f32_ubyte0_e32 v53, v53                               ; 7e6a2335
	v_mac_f32_e32 v27, v26, v54                                 ; 2c366d1a
	v_and_b32_e32 v57, s5, v57                                  ; 26727205
	v_mul_f32_e32 v62, v62, v47                                 ; 0a7c5f3e
	v_mac_f32_e32 v27, v25, v55                                 ; 2c366f19
	v_cvt_f32_ubyte3_e32 v58, v57                               ; 7e742939
	v_mac_f32_e32 v62, v61, v48                                 ; 2c7c613d
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v61, s5, v56                                  ; 267a7005
	v_mac_f32_e32 v27, v24, v51                                 ; 2c366718
	v_mul_f32_e32 v31, v31, v58                                 ; 0a3e751f
	v_mac_f32_e32 v62, v60, v43                                 ; 2c7c573c
	v_cvt_f32_ubyte1_e32 v60, v57                               ; 7e782539
	v_mac_f32_e32 v62, v59, v44                                 ; 2c7c593b
	v_cvt_f32_ubyte2_e32 v59, v57                               ; 7e762739
	v_cvt_f32_ubyte0_e32 v57, v57                               ; 7e722339
	v_lshrrev_b32_e32 v56, 4, v56                               ; 20707084
	v_mad_f32 v19, -v39, v62, v19                               ; d1c10013 244e7d27
	v_cvt_f32_ubyte3_e32 v62, v61                               ; 7e7c293d
	v_mac_f32_e32 v31, v30, v59                                 ; 2c3e771e
	v_and_b32_e32 v56, s5, v56                                  ; 26707005
	v_mul_f32_e32 v45, v45, v62                                 ; 0a5a7d2d
	v_cvt_f32_ubyte2_e32 v62, v61                               ; 7e7c273d
	v_mac_f32_e32 v31, v29, v60                                 ; 2c3e791d
	v_mac_f32_e32 v45, v42, v62                                 ; 2c5a7d2a
	v_cvt_f32_ubyte1_e32 v62, v61                               ; 7e7c253d
	v_cvt_f32_ubyte0_e32 v61, v61                               ; 7e7a233d
	v_mac_f32_e32 v31, v28, v57                                 ; 2c3e731c
	v_mac_f32_e32 v45, v41, v62                                 ; 2c5a7d29
	v_cvt_f32_ubyte3_e32 v62, v56                               ; 7e7c2938
	v_mac_f32_e32 v45, v32, v61                                 ; 2c5a7b20
	v_mul_f32_e32 v23, v23, v62                                 ; 0a2e7d17
	v_cvt_f32_ubyte2_e32 v62, v56                               ; 7e7c2738
	v_mac_f32_e32 v23, v22, v62                                 ; 2c2e7d16
	v_cvt_f32_ubyte1_e32 v62, v56                               ; 7e7c2538
	v_cvt_f32_ubyte0_e32 v56, v56                               ; 7e702338
	v_mac_f32_e32 v23, v21, v62                                 ; 2c2e7d15
	v_mac_f32_e32 v23, v20, v56                                 ; 2c2e7114
	v_mul_f32_e32 v23, v23, v50                                 ; 0a2e6517
	v_mac_f32_e32 v23, v45, v53                                 ; 2c2e6b2d
	v_mac_f32_e32 v23, v31, v46                                 ; 2c2e5d1f
	v_mac_f32_e32 v23, v27, v49                                 ; 2c2e631b
	v_mac_f32_e32 v19, v37, v23                                 ; 2c262f25
BB5:
	s_mov_b64 s[0:1], exec                                      ; be80017e
	v_cmpx_le_u32_e32 vcc, s3, v0                               ; 7db60003
BB6:
	s_andn2_b64 s[0:1], s[0:1], exec                            ; 89807e00
	s_cbranch_scc1 BB10                                         ; bf85f975
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
	s_mov_b64 exec, s[10:11]                                    ; befe010a
	v_readlane_b32 s4, v63, 63                                  ; d2890004 00017f3f
	s_or_saveexec_b64 s[10:11], -1                              ; be8a21c1
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
	v_readlane_b32 s5, v63, 63                                  ; d2890005 00017f3f
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
	v_readlane_b32 s6, v63, 63                                  ; d2890006 00017f3f
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
	v_readlane_b32 s9, v63, 63                                  ; d2890009 00017f3f
	s_or_saveexec_b64 s[12:13], -1                              ; be8c21c1
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
	v_readlane_b32 s10, v63, 63                                 ; d289000a 00017f3f
	s_or_saveexec_b64 s[12:13], -1                              ; be8c21c1
	v_cndmask_b32_e64 v63, 0, v12, s[12:13]                     ; d100003f 00321880
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
	v_readlane_b32 s12, v63, 63                                 ; d289000c 00017f3f
	s_or_saveexec_b64 s[14:15], -1                              ; be8e21c1
	v_cndmask_b32_e64 v63, 0, v14, s[14:15]                     ; d100003f 003a1c80
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
	s_or_saveexec_b64 s[18:19], -1                              ; be9221c1
	v_cndmask_b32_e64 v63, 0, v15, s[18:19]                     ; d100003f 004a1e80
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
	s_mov_b64 exec, s[18:19]                                    ; befe0112
	v_readlane_b32 s14, v63, 63                                 ; d289000e 00017f3f
	s_or_saveexec_b64 s[18:19], -1                              ; be9221c1
	v_cndmask_b32_e64 v63, 0, v16, s[18:19]                     ; d100003f 004a2080
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
	s_mov_b64 exec, s[18:19]                                    ; befe0112
	v_readlane_b32 s15, v63, 63                                 ; d289000f 00017f3f
	s_or_saveexec_b64 s[20:21], -1                              ; be9421c1
	v_cndmask_b32_e64 v63, 0, v17, s[20:21]                     ; d100003f 00522280
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
	s_mov_b64 exec, s[20:21]                                    ; befe0114
	v_readlane_b32 s18, v63, 63                                 ; d2890012 00017f3f
	s_or_saveexec_b64 s[20:21], -1                              ; be9421c1
	v_cndmask_b32_e64 v63, 0, v18, s[20:21]                     ; d100003f 00522480
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
	s_mov_b64 exec, s[20:21]                                    ; befe0114
	v_readlane_b32 s19, v63, 63                                 ; d2890013 00017f3f
	s_or_saveexec_b64 s[22:23], -1                              ; be9621c1
	v_cndmask_b32_e64 v63, 0, v19, s[22:23]                     ; d100003f 005a2680
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
	v_readlane_b32 s20, v63, 63                                 ; d2890014 00017f3f
BB12:
	s_bitcmp1_b32 s8, 0                                         ; bf0d8008
	s_cbranch_scc0 BB14                                         ; bf84000f
BB13:
	s_mov_b32 s22, s2                                           ; be960002
	s_movk_i32 s23, 0x8000                                      ; b0178000
	s_load_dwordx4 s[24:27], s[22:23], 0x30                     ; c00a060b 00000030
	s_mul_i32 s21, s7, s17                                      ; 92151107
	s_mov_b32 s22, src_scc                                      ; be9600fd
	s_add_u32 s21, s21, s16                                     ; 80151015
	s_lshl_b32 s21, s21, 2                                      ; 8e158215
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s21, s[24:27], s21                      ; c020054c 00000015
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_mov_b32_e32 v0, s21                                       ; 7e000215
	v_add_f32_e32 v0, s0, v0                                    ; 02000000
	s_branch BB15                                               ; bf820002
BB14:
	s_mov_b32 s22, src_scc                                      ; be9600fd
	v_mov_b32_e32 v0, s0                                        ; 7e000200
BB15:
	s_bitcmp1_b32 s8, 1                                         ; bf0d8108
	s_cbranch_scc0 BB17                                         ; bf84000e
BB16:
	s_mov_b32 s24, s2                                           ; be980002
	s_movk_i32 s25, 0x8000                                      ; b0198000
	s_load_dwordx4 s[24:27], s[24:25], 0x40                     ; c00a060c 00000040
	s_mul_i32 s0, s7, s17                                       ; 92001107
	s_mov_b32 s8, src_scc                                       ; be8800fd
	s_add_u32 s0, s0, s16                                       ; 80001000
	s_lshl_b32 s0, s0, 2                                        ; 8e008200
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s0, s[24:27], s0                        ; c020000c 00000000
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v0, s0, v0                                    ; 02000000
	s_branch BB18                                               ; bf820001
BB17:
	s_mov_b32 s8, src_scc                                       ; be8800fd
BB18:
	s_mov_b32 s0, s3                                            ; be800003
	s_movk_i32 s3, 0x8000                                       ; b0038000
	s_load_dwordx4 s[24:27], s[2:3], 0x20                       ; c00a0601 00000020
	s_mul_i32 s7, s7, s17                                       ; 92071107
	s_add_u32 s7, s7, s16                                       ; 80071007
	s_lshl_b32 s7, s7, 2                                        ; 8e078207
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_store_dword v0, off, s[24:27], s7                    ; e0700000 07060080
	s_cmp_lg_i32 s22, 0                                         ; bf018016
	s_cbranch_scc0 BB20                                         ; bf84000b
BB19:
	s_load_dwordx4 s[28:31], s[2:3], 0x30                       ; c00a0701 00000030
	s_mov_b32 s16, src_scc                                      ; be9000fd
	s_add_u32 s17, s7, 4                                        ; 80118407
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s17, s[28:31], s17                      ; c020044e 00000011
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_mov_b32_e32 v0, s17                                       ; 7e000211
	v_add_f32_e32 v0, s1, v0                                    ; 02000001
	s_branch BB21                                               ; bf820002
BB20:
	s_mov_b32 s16, src_scc                                      ; be9000fd
	v_mov_b32_e32 v0, s1                                        ; 7e000201
BB21:
	s_cmp_lg_i32 s8, 0                                          ; bf018008
	s_cbranch_scc0 BB23                                         ; bf84000a
BB22:
	s_load_dwordx4 s[28:31], s[2:3], 0x40                       ; c00a0701 00000040
	s_mov_b32 s1, src_scc                                       ; be8100fd
	s_add_u32 s8, s7, 4                                         ; 80088407
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s8, s[28:31], s8                        ; c020020e 00000008
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v0, s8, v0                                    ; 02000008
	s_branch BB24                                               ; bf820001
BB23:
	s_mov_b32 s1, src_scc                                       ; be8100fd
BB24:
	s_add_u32 s8, s7, 4                                         ; 80088407
	buffer_store_dword v0, off, s[24:27], s8                    ; e0700000 08060080
	s_cmp_lg_i32 s16, 0                                         ; bf018010
	s_cbranch_scc0 BB26                                         ; bf84000b
BB25:
	s_load_dwordx4 s[28:31], s[2:3], 0x30                       ; c00a0701 00000030
	s_mov_b32 s8, src_scc                                       ; be8800fd
	s_add_u32 s16, s7, 8                                        ; 80108807
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s16, s[28:31], s16                      ; c020040e 00000010
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_mov_b32_e32 v0, s16                                       ; 7e000210
	v_add_f32_e32 v0, s0, v0                                    ; 02000000
	s_branch BB27                                               ; bf820002
BB26:
	s_mov_b32 s8, src_scc                                       ; be8800fd
	v_mov_b32_e32 v0, s0                                        ; 7e000200
BB27:
	s_cmp_lg_i32 s1, 0                                          ; bf018001
	s_cbranch_scc0 BB29                                         ; bf84000a
BB28:
	s_load_dwordx4 s[28:31], s[2:3], 0x40                       ; c00a0701 00000040
	s_mov_b32 s0, src_scc                                       ; be8000fd
	s_add_u32 s1, s7, 8                                         ; 80018807
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s1, s[28:31], s1                        ; c020004e 00000001
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v0, s1, v0                                    ; 02000001
	s_branch BB30                                               ; bf820001
BB29:
	s_mov_b32 s0, src_scc                                       ; be8000fd
BB30:
	s_add_u32 s1, s7, 8                                         ; 80018807
	buffer_store_dword v0, off, s[24:27], s1                    ; e0700000 01060080
	s_cmp_lg_i32 s8, 0                                          ; bf018008
	s_cbranch_scc0 BB32                                         ; bf84000b
BB31:
	s_load_dwordx4 s[28:31], s[2:3], 0x30                       ; c00a0701 00000030
	s_mov_b32 s1, src_scc                                       ; be8100fd
	s_add_u32 s8, s7, 12                                        ; 80088c07
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s8, s[28:31], s8                        ; c020020e 00000008
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
	s_load_dwordx4 s[28:31], s[2:3], 0x40                       ; c00a0701 00000040
	s_mov_b32 s0, src_scc                                       ; be8000fd
	s_add_u32 s4, s7, 12                                        ; 80048c07
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s4, s[28:31], s4                        ; c020010e 00000004
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v0, s4, v0                                    ; 02000004
	s_branch BB36                                               ; bf820001
BB35:
	s_mov_b32 s0, src_scc                                       ; be8000fd
BB36:
	s_add_u32 s4, s7, 12                                        ; 80048c07
	buffer_store_dword v0, off, s[24:27], s4                    ; e0700000 04060080
	s_cmp_lg_i32 s1, 0                                          ; bf018001
	s_cbranch_scc0 BB38                                         ; bf84000b
BB37:
	s_load_dwordx4 s[28:31], s[2:3], 0x30                       ; c00a0701 00000030
	s_mov_b32 s1, src_scc                                       ; be8100fd
	s_add_u32 s4, s7, 16                                        ; 80049007
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s4, s[28:31], s4                        ; c020010e 00000004
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
	s_load_dwordx4 s[28:31], s[2:3], 0x40                       ; c00a0701 00000040
	s_mov_b32 s0, src_scc                                       ; be8000fd
	s_add_u32 s4, s7, 16                                        ; 80049007
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s4, s[28:31], s4                        ; c020010e 00000004
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v0, s4, v0                                    ; 02000004
	s_branch BB42                                               ; bf820001
BB41:
	s_mov_b32 s0, src_scc                                       ; be8000fd
BB42:
	s_add_u32 s4, s7, 16                                        ; 80049007
	buffer_store_dword v0, off, s[24:27], s4                    ; e0700000 04060080
	s_cmp_lg_i32 s1, 0                                          ; bf018001
	s_cbranch_scc0 BB44                                         ; bf84000b
BB43:
	s_load_dwordx4 s[28:31], s[2:3], 0x30                       ; c00a0701 00000030
	s_mov_b32 s1, src_scc                                       ; be8100fd
	s_add_u32 s4, s7, 20                                        ; 80049407
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s4, s[28:31], s4                        ; c020010e 00000004
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
	s_load_dwordx4 s[28:31], s[2:3], 0x40                       ; c00a0701 00000040
	s_mov_b32 s0, src_scc                                       ; be8000fd
	s_add_u32 s4, s7, 20                                        ; 80049407
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s4, s[28:31], s4                        ; c020010e 00000004
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v0, s4, v0                                    ; 02000004
	s_branch BB48                                               ; bf820001
BB47:
	s_mov_b32 s0, src_scc                                       ; be8000fd
BB48:
	s_add_u32 s4, s7, 20                                        ; 80049407
	buffer_store_dword v0, off, s[24:27], s4                    ; e0700000 04060080
	s_cmp_lg_i32 s1, 0                                          ; bf018001
	s_cbranch_scc0 BB50                                         ; bf84000b
BB49:
	s_load_dwordx4 s[28:31], s[2:3], 0x30                       ; c00a0701 00000030
	s_mov_b32 s1, src_scc                                       ; be8100fd
	s_add_u32 s4, s7, 24                                        ; 80049807
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s4, s[28:31], s4                        ; c020010e 00000004
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
	s_load_dwordx4 s[28:31], s[2:3], 0x40                       ; c00a0701 00000040
	s_mov_b32 s0, src_scc                                       ; be8000fd
	s_add_u32 s4, s7, 24                                        ; 80049807
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s4, s[28:31], s4                        ; c020010e 00000004
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v0, s4, v0                                    ; 02000004
	s_branch BB54                                               ; bf820001
BB53:
	s_mov_b32 s0, src_scc                                       ; be8000fd
BB54:
	s_add_u32 s4, s7, 24                                        ; 80049807
	buffer_store_dword v0, off, s[24:27], s4                    ; e0700000 04060080
	s_cmp_lg_i32 s1, 0                                          ; bf018001
	s_cbranch_scc0 BB56                                         ; bf84000b
BB55:
	s_load_dwordx4 s[28:31], s[2:3], 0x30                       ; c00a0701 00000030
	s_mov_b32 s1, src_scc                                       ; be8100fd
	s_add_u32 s4, s7, 28                                        ; 80049c07
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s4, s[28:31], s4                        ; c020010e 00000004
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_mov_b32_e32 v0, s4                                        ; 7e000204
	v_add_f32_e32 v0, s10, v0                                   ; 0200000a
	s_branch BB57                                               ; bf820002
BB56:
	s_mov_b32 s1, src_scc                                       ; be8100fd
	v_mov_b32_e32 v0, s10                                       ; 7e00020a
BB57:
	s_cmp_lg_i32 s0, 0                                          ; bf018000
	s_cbranch_scc0 BB59                                         ; bf84000a
BB58:
	s_load_dwordx4 s[28:31], s[2:3], 0x40                       ; c00a0701 00000040
	s_mov_b32 s0, src_scc                                       ; be8000fd
	s_add_u32 s4, s7, 28                                        ; 80049c07
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s4, s[28:31], s4                        ; c020010e 00000004
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v0, s4, v0                                    ; 02000004
	s_branch BB60                                               ; bf820001
BB59:
	s_mov_b32 s0, src_scc                                       ; be8000fd
BB60:
	s_add_u32 s4, s7, 28                                        ; 80049c07
	buffer_store_dword v0, off, s[24:27], s4                    ; e0700000 04060080
	s_cmp_lg_i32 s1, 0                                          ; bf018001
	s_cbranch_scc0 BB62                                         ; bf84000b
BB61:
	s_load_dwordx4 s[28:31], s[2:3], 0x30                       ; c00a0701 00000030
	s_mov_b32 s1, src_scc                                       ; be8100fd
	s_add_u32 s4, s7, 32                                        ; 8004a007
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s4, s[28:31], s4                        ; c020010e 00000004
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_mov_b32_e32 v0, s4                                        ; 7e000204
	v_add_f32_e32 v0, s11, v0                                   ; 0200000b
	s_branch BB63                                               ; bf820002
BB62:
	s_mov_b32 s1, src_scc                                       ; be8100fd
	v_mov_b32_e32 v0, s11                                       ; 7e00020b
BB63:
	s_cmp_lg_i32 s0, 0                                          ; bf018000
	s_cbranch_scc0 BB65                                         ; bf84000a
BB64:
	s_load_dwordx4 s[8:11], s[2:3], 0x40                        ; c00a0201 00000040
	s_mov_b32 s0, src_scc                                       ; be8000fd
	s_add_u32 s4, s7, 32                                        ; 8004a007
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s4, s[8:11], s4                         ; c0200104 00000004
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v0, s4, v0                                    ; 02000004
	s_branch BB66                                               ; bf820001
BB65:
	s_mov_b32 s0, src_scc                                       ; be8000fd
BB66:
	s_add_u32 s4, s7, 32                                        ; 8004a007
	buffer_store_dword v0, off, s[24:27], s4                    ; e0700000 04060080
	s_cmp_lg_i32 s1, 0                                          ; bf018001
	s_cbranch_scc0 BB68                                         ; bf84000b
BB67:
	s_load_dwordx4 s[8:11], s[2:3], 0x30                        ; c00a0201 00000030
	s_mov_b32 s1, src_scc                                       ; be8100fd
	s_add_u32 s4, s7, 36                                        ; 8004a407
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s4, s[8:11], s4                         ; c0200104 00000004
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_mov_b32_e32 v0, s4                                        ; 7e000204
	v_add_f32_e32 v0, s12, v0                                   ; 0200000c
	s_branch BB69                                               ; bf820002
BB68:
	s_mov_b32 s1, src_scc                                       ; be8100fd
	v_mov_b32_e32 v0, s12                                       ; 7e00020c
BB69:
	s_cmp_lg_i32 s0, 0                                          ; bf018000
	s_cbranch_scc0 BB71                                         ; bf84000a
BB70:
	s_load_dwordx4 s[8:11], s[2:3], 0x40                        ; c00a0201 00000040
	s_mov_b32 s0, src_scc                                       ; be8000fd
	s_add_u32 s4, s7, 36                                        ; 8004a407
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s4, s[8:11], s4                         ; c0200104 00000004
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v0, s4, v0                                    ; 02000004
	s_branch BB72                                               ; bf820001
BB71:
	s_mov_b32 s0, src_scc                                       ; be8000fd
BB72:
	s_add_u32 s4, s7, 36                                        ; 8004a407
	buffer_store_dword v0, off, s[24:27], s4                    ; e0700000 04060080
	s_cmp_lg_i32 s1, 0                                          ; bf018001
	s_cbranch_scc0 BB74                                         ; bf84000b
BB73:
	s_load_dwordx4 s[8:11], s[2:3], 0x30                        ; c00a0201 00000030
	s_mov_b32 s1, src_scc                                       ; be8100fd
	s_add_u32 s4, s7, 40                                        ; 8004a807
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s4, s[8:11], s4                         ; c0200104 00000004
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_mov_b32_e32 v0, s4                                        ; 7e000204
	v_add_f32_e32 v0, s13, v0                                   ; 0200000d
	s_branch BB75                                               ; bf820002
BB74:
	s_mov_b32 s1, src_scc                                       ; be8100fd
	v_mov_b32_e32 v0, s13                                       ; 7e00020d
BB75:
	s_cmp_lg_i32 s0, 0                                          ; bf018000
	s_cbranch_scc0 BB77                                         ; bf84000a
BB76:
	s_load_dwordx4 s[8:11], s[2:3], 0x40                        ; c00a0201 00000040
	s_mov_b32 s0, src_scc                                       ; be8000fd
	s_add_u32 s4, s7, 40                                        ; 8004a807
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s4, s[8:11], s4                         ; c0200104 00000004
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v0, s4, v0                                    ; 02000004
	s_branch BB78                                               ; bf820001
BB77:
	s_mov_b32 s0, src_scc                                       ; be8000fd
BB78:
	s_add_u32 s4, s7, 40                                        ; 8004a807
	buffer_store_dword v0, off, s[24:27], s4                    ; e0700000 04060080
	s_cmp_lg_i32 s1, 0                                          ; bf018001
	s_cbranch_scc0 BB80                                         ; bf84000b
BB79:
	s_load_dwordx4 s[8:11], s[2:3], 0x30                        ; c00a0201 00000030
	s_mov_b32 s1, src_scc                                       ; be8100fd
	s_add_u32 s4, s7, 44                                        ; 8004ac07
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s4, s[8:11], s4                         ; c0200104 00000004
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_mov_b32_e32 v0, s4                                        ; 7e000204
	v_add_f32_e32 v0, s14, v0                                   ; 0200000e
	s_branch BB81                                               ; bf820002
BB80:
	s_mov_b32 s1, src_scc                                       ; be8100fd
	v_mov_b32_e32 v0, s14                                       ; 7e00020e
BB81:
	s_cmp_lg_i32 s0, 0                                          ; bf018000
	s_cbranch_scc0 BB83                                         ; bf84000a
BB82:
	s_load_dwordx4 s[8:11], s[2:3], 0x40                        ; c00a0201 00000040
	s_mov_b32 s0, src_scc                                       ; be8000fd
	s_add_u32 s4, s7, 44                                        ; 8004ac07
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s4, s[8:11], s4                         ; c0200104 00000004
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v0, s4, v0                                    ; 02000004
	s_branch BB84                                               ; bf820001
BB83:
	s_mov_b32 s0, src_scc                                       ; be8000fd
BB84:
	s_add_u32 s4, s7, 44                                        ; 8004ac07
	buffer_store_dword v0, off, s[24:27], s4                    ; e0700000 04060080
	s_cmp_lg_i32 s1, 0                                          ; bf018001
	s_cbranch_scc0 BB86                                         ; bf84000b
BB85:
	s_load_dwordx4 s[8:11], s[2:3], 0x30                        ; c00a0201 00000030
	s_mov_b32 s1, src_scc                                       ; be8100fd
	s_add_u32 s4, s7, 48                                        ; 8004b007
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s4, s[8:11], s4                         ; c0200104 00000004
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_mov_b32_e32 v0, s4                                        ; 7e000204
	v_add_f32_e32 v0, s15, v0                                   ; 0200000f
	s_branch BB87                                               ; bf820002
BB86:
	s_mov_b32 s1, src_scc                                       ; be8100fd
	v_mov_b32_e32 v0, s15                                       ; 7e00020f
BB87:
	s_cmp_lg_i32 s0, 0                                          ; bf018000
	s_cbranch_scc0 BB89                                         ; bf84000a
BB88:
	s_load_dwordx4 s[8:11], s[2:3], 0x40                        ; c00a0201 00000040
	s_mov_b32 s0, src_scc                                       ; be8000fd
	s_add_u32 s4, s7, 48                                        ; 8004b007
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s4, s[8:11], s4                         ; c0200104 00000004
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v0, s4, v0                                    ; 02000004
	s_branch BB90                                               ; bf820001
BB89:
	s_mov_b32 s0, src_scc                                       ; be8000fd
BB90:
	s_add_u32 s4, s7, 48                                        ; 8004b007
	buffer_store_dword v0, off, s[24:27], s4                    ; e0700000 04060080
	s_cmp_lg_i32 s1, 0                                          ; bf018001
	s_cbranch_scc0 BB92                                         ; bf84000b
BB91:
	s_load_dwordx4 s[8:11], s[2:3], 0x30                        ; c00a0201 00000030
	s_mov_b32 s1, src_scc                                       ; be8100fd
	s_add_u32 s4, s7, 52                                        ; 8004b407
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s4, s[8:11], s4                         ; c0200104 00000004
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_mov_b32_e32 v0, s4                                        ; 7e000204
	v_add_f32_e32 v0, s18, v0                                   ; 02000012
	s_branch BB93                                               ; bf820002
BB92:
	s_mov_b32 s1, src_scc                                       ; be8100fd
	v_mov_b32_e32 v0, s18                                       ; 7e000212
BB93:
	s_cmp_lg_i32 s0, 0                                          ; bf018000
	s_cbranch_scc0 BB95                                         ; bf84000a
BB94:
	s_load_dwordx4 s[8:11], s[2:3], 0x40                        ; c00a0201 00000040
	s_mov_b32 s0, src_scc                                       ; be8000fd
	s_add_u32 s4, s7, 52                                        ; 8004b407
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s4, s[8:11], s4                         ; c0200104 00000004
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v0, s4, v0                                    ; 02000004
	s_branch BB96                                               ; bf820001
BB95:
	s_mov_b32 s0, src_scc                                       ; be8000fd
BB96:
	s_add_u32 s4, s7, 52                                        ; 8004b407
	buffer_store_dword v0, off, s[24:27], s4                    ; e0700000 04060080
	s_cmp_lg_i32 s1, 0                                          ; bf018001
	s_cbranch_scc0 BB98                                         ; bf84000b
BB97:
	s_load_dwordx4 s[8:11], s[2:3], 0x30                        ; c00a0201 00000030
	s_mov_b32 s1, src_scc                                       ; be8100fd
	s_add_u32 s4, s7, 56                                        ; 8004b807
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s4, s[8:11], s4                         ; c0200104 00000004
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_mov_b32_e32 v0, s4                                        ; 7e000204
	v_add_f32_e32 v0, s19, v0                                   ; 02000013
	s_branch BB99                                               ; bf820002
BB98:
	s_mov_b32 s1, src_scc                                       ; be8100fd
	v_mov_b32_e32 v0, s19                                       ; 7e000213
BB99:
	s_cmp_lg_i32 s0, 0                                          ; bf018000
	s_cbranch_scc0 BB101                                        ; bf84000a
BB100:
	s_load_dwordx4 s[8:11], s[2:3], 0x40                        ; c00a0201 00000040
	s_mov_b32 s0, src_scc                                       ; be8000fd
	s_add_u32 s4, s7, 56                                        ; 8004b807
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s4, s[8:11], s4                         ; c0200104 00000004
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v0, s4, v0                                    ; 02000004
	s_branch BB102                                              ; bf820001
BB101:
	s_mov_b32 s0, src_scc                                       ; be8000fd
BB102:
	s_add_u32 s4, s7, 56                                        ; 8004b807
	buffer_store_dword v0, off, s[24:27], s4                    ; e0700000 04060080
	s_cmp_lg_i32 s1, 0                                          ; bf018001
	s_cbranch_scc0 BB104                                        ; bf84000a
BB103:
	s_load_dwordx4 s[8:11], s[2:3], 0x30                        ; c00a0201 00000030
	s_add_u32 s1, s7, 60                                        ; 8001bc07
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s1, s[8:11], s1                         ; c0200044 00000001
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_mov_b32_e32 v0, s1                                        ; 7e000201
	v_add_f32_e32 v0, s20, v0                                   ; 02000014
	s_branch BB105                                              ; bf820001
BB104:
	v_mov_b32_e32 v0, s20                                       ; 7e000214
BB105:
	s_cmp_lg_i32 s0, 0                                          ; bf018000
	s_cbranch_scc0 BB108                                        ; bf840008
BB106:
	s_load_dwordx4 s[0:3], s[2:3], 0x40                         ; c00a0001 00000040
	s_add_u32 s4, s7, 60                                        ; 8004bc07
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s4, s[0:3], s4                          ; c0200100 00000004
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v0, s4, v0                                    ; 02000004
BB108:
	s_add_u32 s7, s7, 60                                        ; 8007bc07
	buffer_store_dword v0, off, s[24:27], s7                    ; e0700000 07060080
	s_branch BB371                                              ; bf820b0c
BB114:
	s_cmp_lt_u32 s16, s4                                        ; bf0a0410
	s_cbranch_scc0 BB371                                        ; bf840b0a
BB115:
	s_sub_i32 s4, s4, s16                                       ; 81841004
	s_add_u32 s17, s17, s9                                      ; 80110911
	s_cmp_lg_i32 s17, 0                                         ; bf018011
	s_cbranch_scc0 BB117                                        ; bf840043
BB116:
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
	s_branch BB118                                              ; bf820001
BB117:
	s_mov_b32 s19, 0                                            ; be930080
BB118:
	s_lshr_b32 s5, s5, 8                                        ; 8f058805
	v_and_b32_e32 v1, 12, v0                                    ; 2602008c
	v_and_b32_e32 v2, 15, v0                                    ; 2604008f
	s_lshr_b32 s3, s3, 8                                        ; 8f038803
	v_lshrrev_b32_e32 v0, 4, v0                                 ; 20000084
	v_mov_b32_e32 v5, 0                                         ; 7e0a0280
	v_mov_b32_e32 v6, 0                                         ; 7e0c0280
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
	v_mov_b32_e32 v14, 0                                        ; 7e1c0280
	v_mov_b32_e32 v15, 0                                        ; 7e1e0280
	v_mov_b32_e32 v16, 0                                        ; 7e200280
	v_mov_b32_e32 v17, 0                                        ; 7e220280
	v_mov_b32_e32 v18, 0                                        ; 7e240280
	v_mov_b32_e32 v19, 0                                        ; 7e260280
	v_lshl_add_u32 v1, v1, 1, v3                                ; d1fd0001 040d0301
	v_mov_b32_e32 v3, 0                                         ; 7e060280
	v_lshlrev_b32_e32 v1, 2, v1                                 ; 24020282
	v_lshl_add_u32 v4, v2, 5, v1                                ; d1fd0004 04050b02
	v_lshl_add_u32 v1, v2, 6, v1                                ; d1fd0001 04050d02
BB119:
	s_mov_b64 s[0:1], exec                                      ; be80017e
	v_cmpx_le_u32_e32 vcc, s3, v0                               ; 7db60003
BB120:
	s_andn2_b64 s[0:1], s[0:1], exec                            ; 89807e00
	s_cbranch_scc0 BB173                                        ; bf8406f1
BB124:
	s_mov_b64 exec, s[0:1]                                      ; befe0100
	s_mov_b32 s0, s2                                            ; be800002
	s_movk_i32 s1, 0x8000                                       ; b0018000
	s_load_dwordx4 s[12:15], s[0:1], 0x10                       ; c00a0300 00000010
	s_mul_i32 s5, s6, s17                                       ; 92051106
	v_lshl_add_u32 v20, v0, 8, v1                               ; d1fd0014 04051100
	v_add_u32_e32 v21, s5, v20                                  ; 682a2805
	v_add_u32_e32 v20, 0x80, v20                                ; 682828ff 00000080
	v_lshrrev_b32_e32 v21, 2, v21                               ; 202a2a82
	v_add_u32_e32 v20, s5, v20                                  ; 68282805
	v_lshlrev_b32_e32 v21, 4, v21                               ; 242a2a84
	v_lshrrev_b32_e32 v20, 2, v20                               ; 20282882
	v_lshlrev_b32_e32 v20, 4, v20                               ; 24282884
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_load_dwordx4 v[24:27], v21, s[12:15], 0 offen        ; e05c1000 80031815
	buffer_load_dwordx4 v[28:31], v21, s[12:15], 0 offen offset:128 ; e05c1080 80031c15
	buffer_load_dwordx4 v[32:35], v20, s[12:15], 0 offen        ; e05c1000 80032014
	buffer_load_dwordx4 v[20:23], v20, s[12:15], 0 offen offset:128 ; e05c1080 80031414
	s_cmp_lg_i32 s4, 0                                          ; bf018004
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_add_f32_e32 v36, v24, v25                                 ; 02483318
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_add_f32_e32 v37, v28, v29                                 ; 024a3b1c
	v_add_f32_e32 v36, v36, v26                                 ; 02483524
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_add_f32_e32 v38, v32, v33                                 ; 024c4320
	v_add_f32_e32 v37, v37, v30                                 ; 024a3d25
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_add_f32_e32 v39, v20, v21                                 ; 024e2b14
	v_add_f32_e32 v36, v36, v27                                 ; 02483724
	v_add_f32_e32 v38, v38, v34                                 ; 024c4526
	v_add_f32_e32 v37, v37, v31                                 ; 024a3f25
	v_add_f32_e32 v39, v39, v22                                 ; 024e2d27
	v_add_f32_e32 v38, v38, v35                                 ; 024c4726
	v_add_f32_e32 v39, v39, v23                                 ; 024e2f27
	s_cbranch_scc0 BB172                                        ; bf8406c4
BB125:
	s_load_dwordx4 s[12:15], s[0:1], 0x0                        ; c00a0300 00000000
	s_mul_i32 s0, s16, s3                                       ; 92000310
	v_lshlrev_b32_e32 v42, 1, v2                                ; 24540481
	v_add_u32_e32 v50, 64, v4                                   ; 686408c0
	s_add_u32 s0, s19, s0                                       ; 80000013
	v_and_b32_e32 v44, -4, v42                                  ; 265854c4
	v_add_u32_e32 v47, 8, v42                                   ; 685e5488
	v_add_u32_e32 v40, s0, v0                                   ; 68500000
	v_lshlrev_b32_e32 v41, 4, v40                               ; 24525084
	v_lshl_add_u32 v40, v40, 7, v41                             ; d1fd0028 04a50f28
	v_add_u32_e32 v43, 4, v40                                   ; 68565084
	v_add_u32_e32 v48, 16, v40                                  ; 68605090
	v_add_u32_e32 v45, v44, v43                                 ; 685a572c
	v_add_u32_e32 v46, v43, v42                                 ; 685c552b
	v_add_u32_e32 v43, v43, v47                                 ; 68565f2b
	v_add_u32_e32 v49, v48, v4                                  ; 68620930
	v_add_u32_e32 v48, v48, v50                                 ; 68606530
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_load_dword v40, v40, s[12:15], 0 offen               ; e0501000 80032828
	buffer_load_dwordx2 v[52:53], v45, s[12:15], 0 offen        ; e0541000 8003342d
	buffer_load_ushort v43, v43, s[12:15], 0 offen              ; e0481000 80032b2b
	buffer_load_dword v49, v49, s[12:15], 0 offen               ; e0501000 80033131
	buffer_load_dword v48, v48, s[12:15], 0 offen               ; e0501000 80033030
	s_mov_b32 s1, 0xf0f0f0f                                     ; be8100ff 0f0f0f0f
	s_cmp_lt_u32 1, s4                                          ; bf0a0481
	s_waitcnt vmcnt(4)                                          ; bf8c3f74
	v_cvt_f32_f16_sdwa v51, v40 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e6616f9 00050628
	v_cvt_f32_f16_e32 v40, v40                                  ; 7e501728
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_alignbyte_b32 v52, v53, v52, v46                          ; d1cf0034 04ba6935
	v_alignbyte_b32 v53, v53, v53, v46                          ; d1cf0035 04ba6b35
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_lshl_or_b32 v43, v43, 12, v43                             ; d200002b 04ad192b
	v_mov_b32_sdwa v52, v53 dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_0 ; 7e6802f9 00041535
	v_and_b32_e32 v53, 0xc0c0c0c0, v52                          ; 266a68ff c0c0c0c0
	v_and_b32_e32 v52, 0x3f3f3f3f, v52                          ; 266868ff 3f3f3f3f
	v_lshrrev_b32_e32 v53, 2, v53                               ; 206a6a82
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v60, s1, v49                                  ; 26786201
	v_cvt_f32_ubyte3_e32 v54, v52                               ; 7e6c2934
	v_cvt_f32_ubyte2_e32 v55, v52                               ; 7e6e2734
	v_cvt_f32_ubyte1_e32 v56, v52                               ; 7e702534
	v_cvt_f32_ubyte0_e32 v52, v52                               ; 7e682334
	v_and_or_b32 v43, s1, v43, v53                              ; d201002b 04d65601
	v_cvt_f32_ubyte2_e32 v62, v60                               ; 7e7c273c
	v_cvt_f32_ubyte3_e32 v61, v60                               ; 7e7a293c
	v_cvt_f32_ubyte1_e32 v59, v43                               ; 7e76252b
	v_cvt_f32_ubyte2_e32 v58, v43                               ; 7e74272b
	v_cvt_f32_ubyte3_e32 v57, v43                               ; 7e72292b
	v_cvt_f32_ubyte0_e32 v43, v43                               ; 7e56232b
	v_lshrrev_b32_e32 v49, 4, v49                               ; 20626284
	v_mul_f32_e32 v61, v27, v61                                 ; 0a7a7b1b
	v_mul_f32_e32 v57, v39, v57                                 ; 0a727327
	v_and_b32_e32 v49, s1, v49                                  ; 26626201
	v_mac_f32_e32 v61, v26, v62                                 ; 2c7a7d1a
	v_cvt_f32_ubyte1_e32 v62, v60                               ; 7e7c253c
	v_cvt_f32_ubyte0_e32 v60, v60                               ; 7e78233c
	v_mac_f32_e32 v57, v38, v58                                 ; 2c727526
	v_cvt_f32_ubyte2_e32 v41, v49                               ; 7e522731
	v_cvt_f32_ubyte1_e32 v45, v49                               ; 7e5a2531
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v46, s1, v48                                  ; 265c6001
	v_mac_f32_e32 v61, v25, v62                                 ; 2c7a7d19
	v_cvt_f32_ubyte3_e32 v62, v49                               ; 7e7c2931
	v_cvt_f32_ubyte0_e32 v49, v49                               ; 7e622331
	v_mac_f32_e32 v57, v37, v54                                 ; 2c726d25
	v_cvt_f32_ubyte1_e32 v53, v46                               ; 7e6a252e
	v_mac_f32_e32 v61, v24, v60                                 ; 2c7a7918
	v_mul_f32_e32 v62, v31, v62                                 ; 0a7c7d1f
	v_lshrrev_b32_e32 v48, 4, v48                               ; 20606084
	v_mac_f32_e32 v57, v36, v55                                 ; 2c726f24
	v_mac_f32_e32 v62, v30, v41                                 ; 2c7c531e
	v_and_b32_e32 v48, s1, v48                                  ; 26606001
	v_mad_f32 v3, -v51, v57, v3                                 ; d1c10003 240e7333
	v_cvt_f32_ubyte2_e32 v51, v46                               ; 7e66272e
	v_mac_f32_e32 v62, v29, v45                                 ; 2c7c5b1d
	v_cvt_f32_ubyte3_e32 v54, v48                               ; 7e6c2930
	v_cvt_f32_ubyte2_e32 v55, v48                               ; 7e6e2730
	v_cvt_f32_ubyte1_e32 v57, v48                               ; 7e722530
	v_cvt_f32_ubyte0_e32 v48, v48                               ; 7e602330
	v_mac_f32_e32 v62, v28, v49                                 ; 2c7c631c
	v_cvt_f32_ubyte3_e32 v49, v46                               ; 7e62292e
	v_cvt_f32_ubyte0_e32 v46, v46                               ; 7e5c232e
	v_mul_f32_e32 v54, v23, v54                                 ; 0a6c6d17
	v_mul_f32_e32 v49, v35, v49                                 ; 0a626323
	v_mac_f32_e32 v54, v22, v55                                 ; 2c6c6f16
	v_mac_f32_e32 v49, v34, v51                                 ; 2c626722
	v_mac_f32_e32 v54, v21, v57                                 ; 2c6c7315
	v_mac_f32_e32 v49, v33, v53                                 ; 2c626b21
	v_mac_f32_e32 v54, v20, v48                                 ; 2c6c6114
	v_mac_f32_e32 v49, v32, v46                                 ; 2c625d20
	v_mul_f32_e32 v54, v54, v59                                 ; 0a6c7736
	v_mac_f32_e32 v54, v49, v43                                 ; 2c6c5731
	v_mac_f32_e32 v54, v62, v56                                 ; 2c6c713e
	v_mac_f32_e32 v54, v61, v52                                 ; 2c6c693d
	v_mac_f32_e32 v3, v40, v54                                  ; 2c066d28
	s_cbranch_scc0 BB172                                        ; bf840652
BB126:
	s_add_u32 s0, s16, 1                                        ; 80008110
	s_mul_i32 s0, s0, s3                                        ; 92000300
	s_add_u32 s0, s19, s0                                       ; 80000013
	v_add_u32_e32 v40, s0, v0                                   ; 68500000
	v_lshlrev_b32_e32 v41, 4, v40                               ; 24525084
	v_lshl_add_u32 v40, v40, 7, v41                             ; d1fd0028 04a50f28
	v_add_u32_e32 v43, 4, v40                                   ; 68565084
	v_add_u32_e32 v48, 16, v40                                  ; 68605090
	v_add_u32_e32 v45, v44, v43                                 ; 685a572c
	v_add_u32_e32 v46, v43, v42                                 ; 685c552b
	v_add_u32_e32 v43, v43, v47                                 ; 68565f2b
	v_add_u32_e32 v49, v48, v4                                  ; 68620930
	v_add_u32_e32 v48, v48, v50                                 ; 68606530
	buffer_load_dword v40, v40, s[12:15], 0 offen               ; e0501000 80032828
	buffer_load_dwordx2 v[52:53], v45, s[12:15], 0 offen        ; e0541000 8003342d
	buffer_load_ushort v43, v43, s[12:15], 0 offen              ; e0481000 80032b2b
	buffer_load_dword v49, v49, s[12:15], 0 offen               ; e0501000 80033131
	buffer_load_dword v48, v48, s[12:15], 0 offen               ; e0501000 80033030
	s_mov_b32 s1, 0xf0f0f0f                                     ; be8100ff 0f0f0f0f
	s_cmp_lt_u32 2, s4                                          ; bf0a0482
	s_waitcnt vmcnt(4)                                          ; bf8c3f74
	v_cvt_f32_f16_sdwa v51, v40 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e6616f9 00050628
	v_cvt_f32_f16_e32 v40, v40                                  ; 7e501728
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_alignbyte_b32 v52, v53, v52, v46                          ; d1cf0034 04ba6935
	v_alignbyte_b32 v53, v53, v53, v46                          ; d1cf0035 04ba6b35
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_lshl_or_b32 v43, v43, 12, v43                             ; d200002b 04ad192b
	v_mov_b32_sdwa v52, v53 dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_0 ; 7e6802f9 00041535
	v_and_b32_e32 v53, 0xc0c0c0c0, v52                          ; 266a68ff c0c0c0c0
	v_and_b32_e32 v52, 0x3f3f3f3f, v52                          ; 266868ff 3f3f3f3f
	v_lshrrev_b32_e32 v53, 2, v53                               ; 206a6a82
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v60, s1, v49                                  ; 26786201
	v_cvt_f32_ubyte3_e32 v54, v52                               ; 7e6c2934
	v_cvt_f32_ubyte2_e32 v55, v52                               ; 7e6e2734
	v_cvt_f32_ubyte1_e32 v56, v52                               ; 7e702534
	v_cvt_f32_ubyte0_e32 v52, v52                               ; 7e682334
	v_and_or_b32 v43, s1, v43, v53                              ; d201002b 04d65601
	v_cvt_f32_ubyte3_e32 v61, v60                               ; 7e7a293c
	v_cvt_f32_ubyte2_e32 v62, v60                               ; 7e7c273c
	v_cvt_f32_ubyte1_e32 v59, v43                               ; 7e76252b
	v_cvt_f32_ubyte3_e32 v57, v43                               ; 7e72292b
	v_cvt_f32_ubyte2_e32 v58, v43                               ; 7e74272b
	v_cvt_f32_ubyte0_e32 v43, v43                               ; 7e56232b
	v_mul_f32_e32 v61, v27, v61                                 ; 0a7a7b1b
	v_lshrrev_b32_e32 v49, 4, v49                               ; 20626284
	v_mul_f32_e32 v57, v39, v57                                 ; 0a727327
	v_mac_f32_e32 v61, v26, v62                                 ; 2c7a7d1a
	v_cvt_f32_ubyte1_e32 v62, v60                               ; 7e7c253c
	v_cvt_f32_ubyte0_e32 v60, v60                               ; 7e78233c
	v_and_b32_e32 v49, s1, v49                                  ; 26626201
	v_mac_f32_e32 v57, v38, v58                                 ; 2c727526
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v46, s1, v48                                  ; 265c6001
	v_mac_f32_e32 v61, v25, v62                                 ; 2c7a7d19
	v_cvt_f32_ubyte3_e32 v62, v49                               ; 7e7c2931
	v_cvt_f32_ubyte2_e32 v41, v49                               ; 7e522731
	v_cvt_f32_ubyte1_e32 v45, v49                               ; 7e5a2531
	v_cvt_f32_ubyte0_e32 v49, v49                               ; 7e622331
	v_mac_f32_e32 v57, v37, v54                                 ; 2c726d25
	v_cvt_f32_ubyte1_e32 v53, v46                               ; 7e6a252e
	v_mac_f32_e32 v61, v24, v60                                 ; 2c7a7918
	v_mul_f32_e32 v62, v31, v62                                 ; 0a7c7d1f
	v_lshrrev_b32_e32 v48, 4, v48                               ; 20606084
	v_mac_f32_e32 v57, v36, v55                                 ; 2c726f24
	v_mac_f32_e32 v62, v30, v41                                 ; 2c7c531e
	v_and_b32_e32 v48, s1, v48                                  ; 26606001
	v_mad_f32 v5, -v51, v57, v5                                 ; d1c10005 24167333
	v_cvt_f32_ubyte2_e32 v51, v46                               ; 7e66272e
	v_mac_f32_e32 v62, v29, v45                                 ; 2c7c5b1d
	v_cvt_f32_ubyte2_e32 v55, v48                               ; 7e6e2730
	v_cvt_f32_ubyte3_e32 v54, v48                               ; 7e6c2930
	v_cvt_f32_ubyte1_e32 v57, v48                               ; 7e722530
	v_cvt_f32_ubyte0_e32 v48, v48                               ; 7e602330
	v_mac_f32_e32 v62, v28, v49                                 ; 2c7c631c
	v_cvt_f32_ubyte3_e32 v49, v46                               ; 7e62292e
	v_cvt_f32_ubyte0_e32 v46, v46                               ; 7e5c232e
	v_mul_f32_e32 v54, v23, v54                                 ; 0a6c6d17
	v_mul_f32_e32 v49, v35, v49                                 ; 0a626323
	v_mac_f32_e32 v54, v22, v55                                 ; 2c6c6f16
	v_mac_f32_e32 v49, v34, v51                                 ; 2c626722
	v_mac_f32_e32 v54, v21, v57                                 ; 2c6c7315
	v_mac_f32_e32 v49, v33, v53                                 ; 2c626b21
	v_mac_f32_e32 v54, v20, v48                                 ; 2c6c6114
	v_mac_f32_e32 v49, v32, v46                                 ; 2c625d20
	v_mul_f32_e32 v54, v54, v59                                 ; 0a6c7736
	v_mac_f32_e32 v54, v49, v43                                 ; 2c6c5731
	v_mac_f32_e32 v54, v62, v56                                 ; 2c6c713e
	v_mac_f32_e32 v54, v61, v52                                 ; 2c6c693d
	v_mac_f32_e32 v5, v40, v54                                  ; 2c0a6d28
	s_cbranch_scc0 BB172                                        ; bf8405e6
BB127:
	s_add_u32 s0, s16, 2                                        ; 80008210
	s_mul_i32 s0, s0, s3                                        ; 92000300
	s_add_u32 s0, s19, s0                                       ; 80000013
	v_add_u32_e32 v40, s0, v0                                   ; 68500000
	v_lshlrev_b32_e32 v41, 4, v40                               ; 24525084
	v_lshl_add_u32 v40, v40, 7, v41                             ; d1fd0028 04a50f28
	v_add_u32_e32 v43, 4, v40                                   ; 68565084
	v_add_u32_e32 v48, 16, v40                                  ; 68605090
	v_add_u32_e32 v45, v44, v43                                 ; 685a572c
	v_add_u32_e32 v46, v43, v42                                 ; 685c552b
	v_add_u32_e32 v43, v43, v47                                 ; 68565f2b
	v_add_u32_e32 v49, v48, v4                                  ; 68620930
	v_add_u32_e32 v48, v48, v50                                 ; 68606530
	buffer_load_dword v40, v40, s[12:15], 0 offen               ; e0501000 80032828
	buffer_load_dwordx2 v[52:53], v45, s[12:15], 0 offen        ; e0541000 8003342d
	buffer_load_ushort v43, v43, s[12:15], 0 offen              ; e0481000 80032b2b
	buffer_load_dword v49, v49, s[12:15], 0 offen               ; e0501000 80033131
	buffer_load_dword v48, v48, s[12:15], 0 offen               ; e0501000 80033030
	s_mov_b32 s1, 0xf0f0f0f                                     ; be8100ff 0f0f0f0f
	s_cmp_lt_u32 3, s4                                          ; bf0a0483
	s_waitcnt vmcnt(4)                                          ; bf8c3f74
	v_cvt_f32_f16_sdwa v51, v40 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e6616f9 00050628
	v_cvt_f32_f16_e32 v40, v40                                  ; 7e501728
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_alignbyte_b32 v52, v53, v52, v46                          ; d1cf0034 04ba6935
	v_alignbyte_b32 v53, v53, v53, v46                          ; d1cf0035 04ba6b35
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_lshl_or_b32 v43, v43, 12, v43                             ; d200002b 04ad192b
	v_mov_b32_sdwa v52, v53 dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_0 ; 7e6802f9 00041535
	v_and_b32_e32 v53, 0xc0c0c0c0, v52                          ; 266a68ff c0c0c0c0
	v_and_b32_e32 v52, 0x3f3f3f3f, v52                          ; 266868ff 3f3f3f3f
	v_lshrrev_b32_e32 v53, 2, v53                               ; 206a6a82
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v60, s1, v49                                  ; 26786201
	v_cvt_f32_ubyte3_e32 v54, v52                               ; 7e6c2934
	v_cvt_f32_ubyte2_e32 v55, v52                               ; 7e6e2734
	v_cvt_f32_ubyte1_e32 v56, v52                               ; 7e702534
	v_cvt_f32_ubyte0_e32 v52, v52                               ; 7e682334
	v_and_or_b32 v43, s1, v43, v53                              ; d201002b 04d65601
	v_cvt_f32_ubyte3_e32 v61, v60                               ; 7e7a293c
	v_cvt_f32_ubyte2_e32 v62, v60                               ; 7e7c273c
	v_cvt_f32_ubyte1_e32 v59, v43                               ; 7e76252b
	v_cvt_f32_ubyte3_e32 v57, v43                               ; 7e72292b
	v_cvt_f32_ubyte2_e32 v58, v43                               ; 7e74272b
	v_cvt_f32_ubyte0_e32 v43, v43                               ; 7e56232b
	v_mul_f32_e32 v61, v27, v61                                 ; 0a7a7b1b
	v_lshrrev_b32_e32 v49, 4, v49                               ; 20626284
	v_mul_f32_e32 v57, v39, v57                                 ; 0a727327
	v_mac_f32_e32 v61, v26, v62                                 ; 2c7a7d1a
	v_cvt_f32_ubyte1_e32 v62, v60                               ; 7e7c253c
	v_cvt_f32_ubyte0_e32 v60, v60                               ; 7e78233c
	v_and_b32_e32 v49, s1, v49                                  ; 26626201
	v_mac_f32_e32 v57, v38, v58                                 ; 2c727526
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v46, s1, v48                                  ; 265c6001
	v_mac_f32_e32 v61, v25, v62                                 ; 2c7a7d19
	v_cvt_f32_ubyte3_e32 v62, v49                               ; 7e7c2931
	v_cvt_f32_ubyte2_e32 v41, v49                               ; 7e522731
	v_cvt_f32_ubyte1_e32 v45, v49                               ; 7e5a2531
	v_cvt_f32_ubyte0_e32 v49, v49                               ; 7e622331
	v_mac_f32_e32 v57, v37, v54                                 ; 2c726d25
	v_cvt_f32_ubyte1_e32 v53, v46                               ; 7e6a252e
	v_mac_f32_e32 v61, v24, v60                                 ; 2c7a7918
	v_mul_f32_e32 v62, v31, v62                                 ; 0a7c7d1f
	v_lshrrev_b32_e32 v48, 4, v48                               ; 20606084
	v_mac_f32_e32 v57, v36, v55                                 ; 2c726f24
	v_mac_f32_e32 v62, v30, v41                                 ; 2c7c531e
	v_and_b32_e32 v48, s1, v48                                  ; 26606001
	v_mad_f32 v6, -v51, v57, v6                                 ; d1c10006 241a7333
	v_cvt_f32_ubyte2_e32 v51, v46                               ; 7e66272e
	v_mac_f32_e32 v62, v29, v45                                 ; 2c7c5b1d
	v_cvt_f32_ubyte2_e32 v55, v48                               ; 7e6e2730
	v_cvt_f32_ubyte3_e32 v54, v48                               ; 7e6c2930
	v_cvt_f32_ubyte1_e32 v57, v48                               ; 7e722530
	v_cvt_f32_ubyte0_e32 v48, v48                               ; 7e602330
	v_mac_f32_e32 v62, v28, v49                                 ; 2c7c631c
	v_cvt_f32_ubyte3_e32 v49, v46                               ; 7e62292e
	v_cvt_f32_ubyte0_e32 v46, v46                               ; 7e5c232e
	v_mul_f32_e32 v54, v23, v54                                 ; 0a6c6d17
	v_mul_f32_e32 v49, v35, v49                                 ; 0a626323
	v_mac_f32_e32 v54, v22, v55                                 ; 2c6c6f16
	v_mac_f32_e32 v49, v34, v51                                 ; 2c626722
	v_mac_f32_e32 v54, v21, v57                                 ; 2c6c7315
	v_mac_f32_e32 v49, v33, v53                                 ; 2c626b21
	v_mac_f32_e32 v54, v20, v48                                 ; 2c6c6114
	v_mac_f32_e32 v49, v32, v46                                 ; 2c625d20
	v_mul_f32_e32 v54, v54, v59                                 ; 0a6c7736
	v_mac_f32_e32 v54, v49, v43                                 ; 2c6c5731
	v_mac_f32_e32 v54, v62, v56                                 ; 2c6c713e
	v_mac_f32_e32 v54, v61, v52                                 ; 2c6c693d
	v_mac_f32_e32 v6, v40, v54                                  ; 2c0c6d28
	s_cbranch_scc0 BB172                                        ; bf84057a
BB128:
	s_add_u32 s0, s16, 3                                        ; 80008310
	s_mul_i32 s0, s0, s3                                        ; 92000300
	s_add_u32 s0, s19, s0                                       ; 80000013
	v_add_u32_e32 v40, s0, v0                                   ; 68500000
	v_lshlrev_b32_e32 v41, 4, v40                               ; 24525084
	v_lshl_add_u32 v40, v40, 7, v41                             ; d1fd0028 04a50f28
	v_add_u32_e32 v43, 4, v40                                   ; 68565084
	v_add_u32_e32 v48, 16, v40                                  ; 68605090
	v_add_u32_e32 v45, v44, v43                                 ; 685a572c
	v_add_u32_e32 v46, v43, v42                                 ; 685c552b
	v_add_u32_e32 v43, v43, v47                                 ; 68565f2b
	v_add_u32_e32 v49, v48, v4                                  ; 68620930
	v_add_u32_e32 v48, v48, v50                                 ; 68606530
	buffer_load_dword v40, v40, s[12:15], 0 offen               ; e0501000 80032828
	buffer_load_dwordx2 v[52:53], v45, s[12:15], 0 offen        ; e0541000 8003342d
	buffer_load_ushort v43, v43, s[12:15], 0 offen              ; e0481000 80032b2b
	buffer_load_dword v49, v49, s[12:15], 0 offen               ; e0501000 80033131
	buffer_load_dword v48, v48, s[12:15], 0 offen               ; e0501000 80033030
	s_mov_b32 s1, 0xf0f0f0f                                     ; be8100ff 0f0f0f0f
	s_cmp_lt_u32 4, s4                                          ; bf0a0484
	s_waitcnt vmcnt(4)                                          ; bf8c3f74
	v_cvt_f32_f16_sdwa v51, v40 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e6616f9 00050628
	v_cvt_f32_f16_e32 v40, v40                                  ; 7e501728
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_alignbyte_b32 v52, v53, v52, v46                          ; d1cf0034 04ba6935
	v_alignbyte_b32 v53, v53, v53, v46                          ; d1cf0035 04ba6b35
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_lshl_or_b32 v43, v43, 12, v43                             ; d200002b 04ad192b
	v_mov_b32_sdwa v52, v53 dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_0 ; 7e6802f9 00041535
	v_and_b32_e32 v53, 0xc0c0c0c0, v52                          ; 266a68ff c0c0c0c0
	v_and_b32_e32 v52, 0x3f3f3f3f, v52                          ; 266868ff 3f3f3f3f
	v_lshrrev_b32_e32 v53, 2, v53                               ; 206a6a82
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v60, s1, v49                                  ; 26786201
	v_cvt_f32_ubyte3_e32 v54, v52                               ; 7e6c2934
	v_cvt_f32_ubyte2_e32 v55, v52                               ; 7e6e2734
	v_cvt_f32_ubyte1_e32 v56, v52                               ; 7e702534
	v_cvt_f32_ubyte0_e32 v52, v52                               ; 7e682334
	v_and_or_b32 v43, s1, v43, v53                              ; d201002b 04d65601
	v_cvt_f32_ubyte3_e32 v61, v60                               ; 7e7a293c
	v_cvt_f32_ubyte2_e32 v62, v60                               ; 7e7c273c
	v_cvt_f32_ubyte1_e32 v59, v43                               ; 7e76252b
	v_cvt_f32_ubyte3_e32 v57, v43                               ; 7e72292b
	v_cvt_f32_ubyte2_e32 v58, v43                               ; 7e74272b
	v_cvt_f32_ubyte0_e32 v43, v43                               ; 7e56232b
	v_mul_f32_e32 v61, v27, v61                                 ; 0a7a7b1b
	v_lshrrev_b32_e32 v49, 4, v49                               ; 20626284
	v_mul_f32_e32 v57, v39, v57                                 ; 0a727327
	v_mac_f32_e32 v61, v26, v62                                 ; 2c7a7d1a
	v_cvt_f32_ubyte1_e32 v62, v60                               ; 7e7c253c
	v_cvt_f32_ubyte0_e32 v60, v60                               ; 7e78233c
	v_and_b32_e32 v49, s1, v49                                  ; 26626201
	v_mac_f32_e32 v57, v38, v58                                 ; 2c727526
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v46, s1, v48                                  ; 265c6001
	v_mac_f32_e32 v61, v25, v62                                 ; 2c7a7d19
	v_cvt_f32_ubyte3_e32 v62, v49                               ; 7e7c2931
	v_cvt_f32_ubyte2_e32 v41, v49                               ; 7e522731
	v_cvt_f32_ubyte1_e32 v45, v49                               ; 7e5a2531
	v_cvt_f32_ubyte0_e32 v49, v49                               ; 7e622331
	v_mac_f32_e32 v57, v37, v54                                 ; 2c726d25
	v_cvt_f32_ubyte1_e32 v53, v46                               ; 7e6a252e
	v_mac_f32_e32 v61, v24, v60                                 ; 2c7a7918
	v_mul_f32_e32 v62, v31, v62                                 ; 0a7c7d1f
	v_lshrrev_b32_e32 v48, 4, v48                               ; 20606084
	v_mac_f32_e32 v57, v36, v55                                 ; 2c726f24
	v_mac_f32_e32 v62, v30, v41                                 ; 2c7c531e
	v_and_b32_e32 v48, s1, v48                                  ; 26606001
	v_mad_f32 v7, -v51, v57, v7                                 ; d1c10007 241e7333
	v_cvt_f32_ubyte2_e32 v51, v46                               ; 7e66272e
	v_mac_f32_e32 v62, v29, v45                                 ; 2c7c5b1d
	v_cvt_f32_ubyte2_e32 v55, v48                               ; 7e6e2730
	v_cvt_f32_ubyte3_e32 v54, v48                               ; 7e6c2930
	v_cvt_f32_ubyte1_e32 v57, v48                               ; 7e722530
	v_cvt_f32_ubyte0_e32 v48, v48                               ; 7e602330
	v_mac_f32_e32 v62, v28, v49                                 ; 2c7c631c
	v_cvt_f32_ubyte3_e32 v49, v46                               ; 7e62292e
	v_cvt_f32_ubyte0_e32 v46, v46                               ; 7e5c232e
	v_mul_f32_e32 v54, v23, v54                                 ; 0a6c6d17
	v_mul_f32_e32 v49, v35, v49                                 ; 0a626323
	v_mac_f32_e32 v54, v22, v55                                 ; 2c6c6f16
	v_mac_f32_e32 v49, v34, v51                                 ; 2c626722
	v_mac_f32_e32 v54, v21, v57                                 ; 2c6c7315
	v_mac_f32_e32 v49, v33, v53                                 ; 2c626b21
	v_mac_f32_e32 v54, v20, v48                                 ; 2c6c6114
	v_mac_f32_e32 v49, v32, v46                                 ; 2c625d20
	v_mul_f32_e32 v54, v54, v59                                 ; 0a6c7736
	v_mac_f32_e32 v54, v49, v43                                 ; 2c6c5731
	v_mac_f32_e32 v54, v62, v56                                 ; 2c6c713e
	v_mac_f32_e32 v54, v61, v52                                 ; 2c6c693d
	v_mac_f32_e32 v7, v40, v54                                  ; 2c0e6d28
	s_cbranch_scc0 BB172                                        ; bf84050e
BB129:
	s_add_u32 s0, s16, 4                                        ; 80008410
	s_mul_i32 s0, s0, s3                                        ; 92000300
	s_add_u32 s0, s19, s0                                       ; 80000013
	v_add_u32_e32 v40, s0, v0                                   ; 68500000
	v_lshlrev_b32_e32 v41, 4, v40                               ; 24525084
	v_lshl_add_u32 v40, v40, 7, v41                             ; d1fd0028 04a50f28
	v_add_u32_e32 v43, 4, v40                                   ; 68565084
	v_add_u32_e32 v48, 16, v40                                  ; 68605090
	v_add_u32_e32 v45, v44, v43                                 ; 685a572c
	v_add_u32_e32 v46, v43, v42                                 ; 685c552b
	v_add_u32_e32 v43, v43, v47                                 ; 68565f2b
	v_add_u32_e32 v49, v48, v4                                  ; 68620930
	v_add_u32_e32 v48, v48, v50                                 ; 68606530
	buffer_load_dword v40, v40, s[12:15], 0 offen               ; e0501000 80032828
	buffer_load_dwordx2 v[52:53], v45, s[12:15], 0 offen        ; e0541000 8003342d
	buffer_load_ushort v43, v43, s[12:15], 0 offen              ; e0481000 80032b2b
	buffer_load_dword v49, v49, s[12:15], 0 offen               ; e0501000 80033131
	buffer_load_dword v48, v48, s[12:15], 0 offen               ; e0501000 80033030
	s_mov_b32 s1, 0xf0f0f0f                                     ; be8100ff 0f0f0f0f
	s_cmp_lt_u32 5, s4                                          ; bf0a0485
	s_waitcnt vmcnt(4)                                          ; bf8c3f74
	v_cvt_f32_f16_sdwa v51, v40 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e6616f9 00050628
	v_cvt_f32_f16_e32 v40, v40                                  ; 7e501728
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_alignbyte_b32 v52, v53, v52, v46                          ; d1cf0034 04ba6935
	v_alignbyte_b32 v53, v53, v53, v46                          ; d1cf0035 04ba6b35
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_lshl_or_b32 v43, v43, 12, v43                             ; d200002b 04ad192b
	v_mov_b32_sdwa v52, v53 dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_0 ; 7e6802f9 00041535
	v_and_b32_e32 v53, 0xc0c0c0c0, v52                          ; 266a68ff c0c0c0c0
	v_and_b32_e32 v52, 0x3f3f3f3f, v52                          ; 266868ff 3f3f3f3f
	v_lshrrev_b32_e32 v53, 2, v53                               ; 206a6a82
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v60, s1, v49                                  ; 26786201
	v_cvt_f32_ubyte3_e32 v54, v52                               ; 7e6c2934
	v_cvt_f32_ubyte2_e32 v55, v52                               ; 7e6e2734
	v_cvt_f32_ubyte1_e32 v56, v52                               ; 7e702534
	v_cvt_f32_ubyte0_e32 v52, v52                               ; 7e682334
	v_and_or_b32 v43, s1, v43, v53                              ; d201002b 04d65601
	v_cvt_f32_ubyte3_e32 v61, v60                               ; 7e7a293c
	v_cvt_f32_ubyte2_e32 v62, v60                               ; 7e7c273c
	v_cvt_f32_ubyte1_e32 v59, v43                               ; 7e76252b
	v_cvt_f32_ubyte3_e32 v57, v43                               ; 7e72292b
	v_cvt_f32_ubyte2_e32 v58, v43                               ; 7e74272b
	v_cvt_f32_ubyte0_e32 v43, v43                               ; 7e56232b
	v_mul_f32_e32 v61, v27, v61                                 ; 0a7a7b1b
	v_lshrrev_b32_e32 v49, 4, v49                               ; 20626284
	v_mul_f32_e32 v57, v39, v57                                 ; 0a727327
	v_mac_f32_e32 v61, v26, v62                                 ; 2c7a7d1a
	v_cvt_f32_ubyte1_e32 v62, v60                               ; 7e7c253c
	v_cvt_f32_ubyte0_e32 v60, v60                               ; 7e78233c
	v_and_b32_e32 v49, s1, v49                                  ; 26626201
	v_mac_f32_e32 v57, v38, v58                                 ; 2c727526
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v46, s1, v48                                  ; 265c6001
	v_mac_f32_e32 v61, v25, v62                                 ; 2c7a7d19
	v_cvt_f32_ubyte3_e32 v62, v49                               ; 7e7c2931
	v_cvt_f32_ubyte2_e32 v41, v49                               ; 7e522731
	v_cvt_f32_ubyte1_e32 v45, v49                               ; 7e5a2531
	v_cvt_f32_ubyte0_e32 v49, v49                               ; 7e622331
	v_mac_f32_e32 v57, v37, v54                                 ; 2c726d25
	v_cvt_f32_ubyte1_e32 v53, v46                               ; 7e6a252e
	v_mac_f32_e32 v61, v24, v60                                 ; 2c7a7918
	v_mul_f32_e32 v62, v31, v62                                 ; 0a7c7d1f
	v_lshrrev_b32_e32 v48, 4, v48                               ; 20606084
	v_mac_f32_e32 v57, v36, v55                                 ; 2c726f24
	v_mac_f32_e32 v62, v30, v41                                 ; 2c7c531e
	v_and_b32_e32 v48, s1, v48                                  ; 26606001
	v_mad_f32 v8, -v51, v57, v8                                 ; d1c10008 24227333
	v_cvt_f32_ubyte2_e32 v51, v46                               ; 7e66272e
	v_mac_f32_e32 v62, v29, v45                                 ; 2c7c5b1d
	v_cvt_f32_ubyte2_e32 v55, v48                               ; 7e6e2730
	v_cvt_f32_ubyte3_e32 v54, v48                               ; 7e6c2930
	v_cvt_f32_ubyte1_e32 v57, v48                               ; 7e722530
	v_cvt_f32_ubyte0_e32 v48, v48                               ; 7e602330
	v_mac_f32_e32 v62, v28, v49                                 ; 2c7c631c
	v_cvt_f32_ubyte3_e32 v49, v46                               ; 7e62292e
	v_cvt_f32_ubyte0_e32 v46, v46                               ; 7e5c232e
	v_mul_f32_e32 v54, v23, v54                                 ; 0a6c6d17
	v_mul_f32_e32 v49, v35, v49                                 ; 0a626323
	v_mac_f32_e32 v54, v22, v55                                 ; 2c6c6f16
	v_mac_f32_e32 v49, v34, v51                                 ; 2c626722
	v_mac_f32_e32 v54, v21, v57                                 ; 2c6c7315
	v_mac_f32_e32 v49, v33, v53                                 ; 2c626b21
	v_mac_f32_e32 v54, v20, v48                                 ; 2c6c6114
	v_mac_f32_e32 v49, v32, v46                                 ; 2c625d20
	v_mul_f32_e32 v54, v54, v59                                 ; 0a6c7736
	v_mac_f32_e32 v54, v49, v43                                 ; 2c6c5731
	v_mac_f32_e32 v54, v62, v56                                 ; 2c6c713e
	v_mac_f32_e32 v54, v61, v52                                 ; 2c6c693d
	v_mac_f32_e32 v8, v40, v54                                  ; 2c106d28
	s_cbranch_scc0 BB172                                        ; bf8404a2
BB130:
	s_add_u32 s0, s16, 5                                        ; 80008510
	s_mul_i32 s0, s0, s3                                        ; 92000300
	s_add_u32 s0, s19, s0                                       ; 80000013
	v_add_u32_e32 v40, s0, v0                                   ; 68500000
	v_lshlrev_b32_e32 v41, 4, v40                               ; 24525084
	v_lshl_add_u32 v40, v40, 7, v41                             ; d1fd0028 04a50f28
	v_add_u32_e32 v43, 4, v40                                   ; 68565084
	v_add_u32_e32 v48, 16, v40                                  ; 68605090
	v_add_u32_e32 v45, v44, v43                                 ; 685a572c
	v_add_u32_e32 v46, v43, v42                                 ; 685c552b
	v_add_u32_e32 v43, v43, v47                                 ; 68565f2b
	v_add_u32_e32 v49, v48, v4                                  ; 68620930
	v_add_u32_e32 v48, v48, v50                                 ; 68606530
	buffer_load_dword v40, v40, s[12:15], 0 offen               ; e0501000 80032828
	buffer_load_dwordx2 v[52:53], v45, s[12:15], 0 offen        ; e0541000 8003342d
	buffer_load_ushort v43, v43, s[12:15], 0 offen              ; e0481000 80032b2b
	buffer_load_dword v49, v49, s[12:15], 0 offen               ; e0501000 80033131
	buffer_load_dword v48, v48, s[12:15], 0 offen               ; e0501000 80033030
	s_mov_b32 s1, 0xf0f0f0f                                     ; be8100ff 0f0f0f0f
	s_cmp_lt_u32 6, s4                                          ; bf0a0486
	s_waitcnt vmcnt(4)                                          ; bf8c3f74
	v_cvt_f32_f16_sdwa v51, v40 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e6616f9 00050628
	v_cvt_f32_f16_e32 v40, v40                                  ; 7e501728
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_alignbyte_b32 v52, v53, v52, v46                          ; d1cf0034 04ba6935
	v_alignbyte_b32 v53, v53, v53, v46                          ; d1cf0035 04ba6b35
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_lshl_or_b32 v43, v43, 12, v43                             ; d200002b 04ad192b
	v_mov_b32_sdwa v52, v53 dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_0 ; 7e6802f9 00041535
	v_and_b32_e32 v53, 0xc0c0c0c0, v52                          ; 266a68ff c0c0c0c0
	v_and_b32_e32 v52, 0x3f3f3f3f, v52                          ; 266868ff 3f3f3f3f
	v_lshrrev_b32_e32 v53, 2, v53                               ; 206a6a82
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v60, s1, v49                                  ; 26786201
	v_cvt_f32_ubyte3_e32 v54, v52                               ; 7e6c2934
	v_cvt_f32_ubyte2_e32 v55, v52                               ; 7e6e2734
	v_cvt_f32_ubyte1_e32 v56, v52                               ; 7e702534
	v_cvt_f32_ubyte0_e32 v52, v52                               ; 7e682334
	v_and_or_b32 v43, s1, v43, v53                              ; d201002b 04d65601
	v_cvt_f32_ubyte3_e32 v61, v60                               ; 7e7a293c
	v_cvt_f32_ubyte2_e32 v62, v60                               ; 7e7c273c
	v_cvt_f32_ubyte1_e32 v59, v43                               ; 7e76252b
	v_cvt_f32_ubyte3_e32 v57, v43                               ; 7e72292b
	v_cvt_f32_ubyte2_e32 v58, v43                               ; 7e74272b
	v_cvt_f32_ubyte0_e32 v43, v43                               ; 7e56232b
	v_mul_f32_e32 v61, v27, v61                                 ; 0a7a7b1b
	v_lshrrev_b32_e32 v49, 4, v49                               ; 20626284
	v_mul_f32_e32 v57, v39, v57                                 ; 0a727327
	v_mac_f32_e32 v61, v26, v62                                 ; 2c7a7d1a
	v_cvt_f32_ubyte1_e32 v62, v60                               ; 7e7c253c
	v_cvt_f32_ubyte0_e32 v60, v60                               ; 7e78233c
	v_and_b32_e32 v49, s1, v49                                  ; 26626201
	v_mac_f32_e32 v57, v38, v58                                 ; 2c727526
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v46, s1, v48                                  ; 265c6001
	v_mac_f32_e32 v61, v25, v62                                 ; 2c7a7d19
	v_cvt_f32_ubyte3_e32 v62, v49                               ; 7e7c2931
	v_cvt_f32_ubyte2_e32 v41, v49                               ; 7e522731
	v_cvt_f32_ubyte1_e32 v45, v49                               ; 7e5a2531
	v_cvt_f32_ubyte0_e32 v49, v49                               ; 7e622331
	v_mac_f32_e32 v57, v37, v54                                 ; 2c726d25
	v_cvt_f32_ubyte1_e32 v53, v46                               ; 7e6a252e
	v_mac_f32_e32 v61, v24, v60                                 ; 2c7a7918
	v_mul_f32_e32 v62, v31, v62                                 ; 0a7c7d1f
	v_lshrrev_b32_e32 v48, 4, v48                               ; 20606084
	v_mac_f32_e32 v57, v36, v55                                 ; 2c726f24
	v_mac_f32_e32 v62, v30, v41                                 ; 2c7c531e
	v_and_b32_e32 v48, s1, v48                                  ; 26606001
	v_mad_f32 v9, -v51, v57, v9                                 ; d1c10009 24267333
	v_cvt_f32_ubyte2_e32 v51, v46                               ; 7e66272e
	v_mac_f32_e32 v62, v29, v45                                 ; 2c7c5b1d
	v_cvt_f32_ubyte2_e32 v55, v48                               ; 7e6e2730
	v_cvt_f32_ubyte3_e32 v54, v48                               ; 7e6c2930
	v_cvt_f32_ubyte1_e32 v57, v48                               ; 7e722530
	v_cvt_f32_ubyte0_e32 v48, v48                               ; 7e602330
	v_mac_f32_e32 v62, v28, v49                                 ; 2c7c631c
	v_cvt_f32_ubyte3_e32 v49, v46                               ; 7e62292e
	v_cvt_f32_ubyte0_e32 v46, v46                               ; 7e5c232e
	v_mul_f32_e32 v54, v23, v54                                 ; 0a6c6d17
	v_mul_f32_e32 v49, v35, v49                                 ; 0a626323
	v_mac_f32_e32 v54, v22, v55                                 ; 2c6c6f16
	v_mac_f32_e32 v49, v34, v51                                 ; 2c626722
	v_mac_f32_e32 v54, v21, v57                                 ; 2c6c7315
	v_mac_f32_e32 v49, v33, v53                                 ; 2c626b21
	v_mac_f32_e32 v54, v20, v48                                 ; 2c6c6114
	v_mac_f32_e32 v49, v32, v46                                 ; 2c625d20
	v_mul_f32_e32 v54, v54, v59                                 ; 0a6c7736
	v_mac_f32_e32 v54, v49, v43                                 ; 2c6c5731
	v_mac_f32_e32 v54, v62, v56                                 ; 2c6c713e
	v_mac_f32_e32 v54, v61, v52                                 ; 2c6c693d
	v_mac_f32_e32 v9, v40, v54                                  ; 2c126d28
	s_cbranch_scc0 BB172                                        ; bf840436
BB131:
	s_add_u32 s0, s16, 6                                        ; 80008610
	s_mul_i32 s0, s0, s3                                        ; 92000300
	s_add_u32 s0, s19, s0                                       ; 80000013
	v_add_u32_e32 v40, s0, v0                                   ; 68500000
	v_lshlrev_b32_e32 v41, 4, v40                               ; 24525084
	v_lshl_add_u32 v40, v40, 7, v41                             ; d1fd0028 04a50f28
	v_add_u32_e32 v43, 4, v40                                   ; 68565084
	v_add_u32_e32 v48, 16, v40                                  ; 68605090
	v_add_u32_e32 v45, v44, v43                                 ; 685a572c
	v_add_u32_e32 v46, v43, v42                                 ; 685c552b
	v_add_u32_e32 v43, v43, v47                                 ; 68565f2b
	v_add_u32_e32 v49, v48, v4                                  ; 68620930
	v_add_u32_e32 v48, v48, v50                                 ; 68606530
	buffer_load_dword v40, v40, s[12:15], 0 offen               ; e0501000 80032828
	buffer_load_dwordx2 v[52:53], v45, s[12:15], 0 offen        ; e0541000 8003342d
	buffer_load_ushort v43, v43, s[12:15], 0 offen              ; e0481000 80032b2b
	buffer_load_dword v49, v49, s[12:15], 0 offen               ; e0501000 80033131
	buffer_load_dword v48, v48, s[12:15], 0 offen               ; e0501000 80033030
	s_mov_b32 s1, 0xf0f0f0f                                     ; be8100ff 0f0f0f0f
	s_cmp_lt_u32 7, s4                                          ; bf0a0487
	s_waitcnt vmcnt(4)                                          ; bf8c3f74
	v_cvt_f32_f16_sdwa v51, v40 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e6616f9 00050628
	v_cvt_f32_f16_e32 v40, v40                                  ; 7e501728
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_alignbyte_b32 v52, v53, v52, v46                          ; d1cf0034 04ba6935
	v_alignbyte_b32 v53, v53, v53, v46                          ; d1cf0035 04ba6b35
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_lshl_or_b32 v43, v43, 12, v43                             ; d200002b 04ad192b
	v_mov_b32_sdwa v52, v53 dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_0 ; 7e6802f9 00041535
	v_and_b32_e32 v53, 0xc0c0c0c0, v52                          ; 266a68ff c0c0c0c0
	v_and_b32_e32 v52, 0x3f3f3f3f, v52                          ; 266868ff 3f3f3f3f
	v_lshrrev_b32_e32 v53, 2, v53                               ; 206a6a82
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v60, s1, v49                                  ; 26786201
	v_cvt_f32_ubyte3_e32 v54, v52                               ; 7e6c2934
	v_cvt_f32_ubyte2_e32 v55, v52                               ; 7e6e2734
	v_cvt_f32_ubyte1_e32 v56, v52                               ; 7e702534
	v_cvt_f32_ubyte0_e32 v52, v52                               ; 7e682334
	v_and_or_b32 v43, s1, v43, v53                              ; d201002b 04d65601
	v_cvt_f32_ubyte3_e32 v61, v60                               ; 7e7a293c
	v_cvt_f32_ubyte2_e32 v62, v60                               ; 7e7c273c
	v_cvt_f32_ubyte1_e32 v59, v43                               ; 7e76252b
	v_cvt_f32_ubyte3_e32 v57, v43                               ; 7e72292b
	v_cvt_f32_ubyte2_e32 v58, v43                               ; 7e74272b
	v_cvt_f32_ubyte0_e32 v43, v43                               ; 7e56232b
	v_mul_f32_e32 v61, v27, v61                                 ; 0a7a7b1b
	v_lshrrev_b32_e32 v49, 4, v49                               ; 20626284
	v_mul_f32_e32 v57, v39, v57                                 ; 0a727327
	v_mac_f32_e32 v61, v26, v62                                 ; 2c7a7d1a
	v_cvt_f32_ubyte1_e32 v62, v60                               ; 7e7c253c
	v_cvt_f32_ubyte0_e32 v60, v60                               ; 7e78233c
	v_and_b32_e32 v49, s1, v49                                  ; 26626201
	v_mac_f32_e32 v57, v38, v58                                 ; 2c727526
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v46, s1, v48                                  ; 265c6001
	v_mac_f32_e32 v61, v25, v62                                 ; 2c7a7d19
	v_cvt_f32_ubyte3_e32 v62, v49                               ; 7e7c2931
	v_cvt_f32_ubyte2_e32 v41, v49                               ; 7e522731
	v_cvt_f32_ubyte1_e32 v45, v49                               ; 7e5a2531
	v_cvt_f32_ubyte0_e32 v49, v49                               ; 7e622331
	v_mac_f32_e32 v57, v37, v54                                 ; 2c726d25
	v_cvt_f32_ubyte1_e32 v53, v46                               ; 7e6a252e
	v_mac_f32_e32 v61, v24, v60                                 ; 2c7a7918
	v_mul_f32_e32 v62, v31, v62                                 ; 0a7c7d1f
	v_lshrrev_b32_e32 v48, 4, v48                               ; 20606084
	v_mac_f32_e32 v57, v36, v55                                 ; 2c726f24
	v_mac_f32_e32 v62, v30, v41                                 ; 2c7c531e
	v_and_b32_e32 v48, s1, v48                                  ; 26606001
	v_mad_f32 v10, -v51, v57, v10                               ; d1c1000a 242a7333
	v_cvt_f32_ubyte2_e32 v51, v46                               ; 7e66272e
	v_mac_f32_e32 v62, v29, v45                                 ; 2c7c5b1d
	v_cvt_f32_ubyte2_e32 v55, v48                               ; 7e6e2730
	v_cvt_f32_ubyte3_e32 v54, v48                               ; 7e6c2930
	v_cvt_f32_ubyte1_e32 v57, v48                               ; 7e722530
	v_cvt_f32_ubyte0_e32 v48, v48                               ; 7e602330
	v_mac_f32_e32 v62, v28, v49                                 ; 2c7c631c
	v_cvt_f32_ubyte3_e32 v49, v46                               ; 7e62292e
	v_cvt_f32_ubyte0_e32 v46, v46                               ; 7e5c232e
	v_mul_f32_e32 v54, v23, v54                                 ; 0a6c6d17
	v_mul_f32_e32 v49, v35, v49                                 ; 0a626323
	v_mac_f32_e32 v54, v22, v55                                 ; 2c6c6f16
	v_mac_f32_e32 v49, v34, v51                                 ; 2c626722
	v_mac_f32_e32 v54, v21, v57                                 ; 2c6c7315
	v_mac_f32_e32 v49, v33, v53                                 ; 2c626b21
	v_mac_f32_e32 v54, v20, v48                                 ; 2c6c6114
	v_mac_f32_e32 v49, v32, v46                                 ; 2c625d20
	v_mul_f32_e32 v54, v54, v59                                 ; 0a6c7736
	v_mac_f32_e32 v54, v49, v43                                 ; 2c6c5731
	v_mac_f32_e32 v54, v62, v56                                 ; 2c6c713e
	v_mac_f32_e32 v54, v61, v52                                 ; 2c6c693d
	v_mac_f32_e32 v10, v40, v54                                 ; 2c146d28
	s_cbranch_scc0 BB172                                        ; bf8403ca
BB132:
	s_add_u32 s0, s16, 7                                        ; 80008710
	s_mul_i32 s0, s0, s3                                        ; 92000300
	s_add_u32 s0, s19, s0                                       ; 80000013
	v_add_u32_e32 v40, s0, v0                                   ; 68500000
	v_lshlrev_b32_e32 v41, 4, v40                               ; 24525084
	v_lshl_add_u32 v40, v40, 7, v41                             ; d1fd0028 04a50f28
	v_add_u32_e32 v43, 4, v40                                   ; 68565084
	v_add_u32_e32 v48, 16, v40                                  ; 68605090
	v_add_u32_e32 v45, v44, v43                                 ; 685a572c
	v_add_u32_e32 v46, v43, v42                                 ; 685c552b
	v_add_u32_e32 v43, v43, v47                                 ; 68565f2b
	v_add_u32_e32 v49, v48, v4                                  ; 68620930
	v_add_u32_e32 v48, v48, v50                                 ; 68606530
	buffer_load_dword v40, v40, s[12:15], 0 offen               ; e0501000 80032828
	buffer_load_dwordx2 v[52:53], v45, s[12:15], 0 offen        ; e0541000 8003342d
	buffer_load_ushort v43, v43, s[12:15], 0 offen              ; e0481000 80032b2b
	buffer_load_dword v49, v49, s[12:15], 0 offen               ; e0501000 80033131
	buffer_load_dword v48, v48, s[12:15], 0 offen               ; e0501000 80033030
	s_mov_b32 s1, 0xf0f0f0f                                     ; be8100ff 0f0f0f0f
	s_cmp_lt_u32 8, s4                                          ; bf0a0488
	s_waitcnt vmcnt(4)                                          ; bf8c3f74
	v_cvt_f32_f16_sdwa v51, v40 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e6616f9 00050628
	v_cvt_f32_f16_e32 v40, v40                                  ; 7e501728
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_alignbyte_b32 v52, v53, v52, v46                          ; d1cf0034 04ba6935
	v_alignbyte_b32 v53, v53, v53, v46                          ; d1cf0035 04ba6b35
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_lshl_or_b32 v43, v43, 12, v43                             ; d200002b 04ad192b
	v_mov_b32_sdwa v52, v53 dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_0 ; 7e6802f9 00041535
	v_and_b32_e32 v53, 0xc0c0c0c0, v52                          ; 266a68ff c0c0c0c0
	v_and_b32_e32 v52, 0x3f3f3f3f, v52                          ; 266868ff 3f3f3f3f
	v_lshrrev_b32_e32 v53, 2, v53                               ; 206a6a82
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v60, s1, v49                                  ; 26786201
	v_cvt_f32_ubyte3_e32 v54, v52                               ; 7e6c2934
	v_cvt_f32_ubyte2_e32 v55, v52                               ; 7e6e2734
	v_cvt_f32_ubyte1_e32 v56, v52                               ; 7e702534
	v_cvt_f32_ubyte0_e32 v52, v52                               ; 7e682334
	v_and_or_b32 v43, s1, v43, v53                              ; d201002b 04d65601
	v_cvt_f32_ubyte3_e32 v61, v60                               ; 7e7a293c
	v_cvt_f32_ubyte2_e32 v62, v60                               ; 7e7c273c
	v_cvt_f32_ubyte1_e32 v59, v43                               ; 7e76252b
	v_cvt_f32_ubyte3_e32 v57, v43                               ; 7e72292b
	v_cvt_f32_ubyte2_e32 v58, v43                               ; 7e74272b
	v_cvt_f32_ubyte0_e32 v43, v43                               ; 7e56232b
	v_mul_f32_e32 v61, v27, v61                                 ; 0a7a7b1b
	v_lshrrev_b32_e32 v49, 4, v49                               ; 20626284
	v_mul_f32_e32 v57, v39, v57                                 ; 0a727327
	v_mac_f32_e32 v61, v26, v62                                 ; 2c7a7d1a
	v_cvt_f32_ubyte1_e32 v62, v60                               ; 7e7c253c
	v_cvt_f32_ubyte0_e32 v60, v60                               ; 7e78233c
	v_and_b32_e32 v49, s1, v49                                  ; 26626201
	v_mac_f32_e32 v57, v38, v58                                 ; 2c727526
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v46, s1, v48                                  ; 265c6001
	v_mac_f32_e32 v61, v25, v62                                 ; 2c7a7d19
	v_cvt_f32_ubyte3_e32 v62, v49                               ; 7e7c2931
	v_cvt_f32_ubyte2_e32 v41, v49                               ; 7e522731
	v_cvt_f32_ubyte1_e32 v45, v49                               ; 7e5a2531
	v_cvt_f32_ubyte0_e32 v49, v49                               ; 7e622331
	v_mac_f32_e32 v57, v37, v54                                 ; 2c726d25
	v_cvt_f32_ubyte1_e32 v53, v46                               ; 7e6a252e
	v_mac_f32_e32 v61, v24, v60                                 ; 2c7a7918
	v_mul_f32_e32 v62, v31, v62                                 ; 0a7c7d1f
	v_lshrrev_b32_e32 v48, 4, v48                               ; 20606084
	v_mac_f32_e32 v57, v36, v55                                 ; 2c726f24
	v_mac_f32_e32 v62, v30, v41                                 ; 2c7c531e
	v_and_b32_e32 v48, s1, v48                                  ; 26606001
	v_mad_f32 v11, -v51, v57, v11                               ; d1c1000b 242e7333
	v_cvt_f32_ubyte2_e32 v51, v46                               ; 7e66272e
	v_mac_f32_e32 v62, v29, v45                                 ; 2c7c5b1d
	v_cvt_f32_ubyte2_e32 v55, v48                               ; 7e6e2730
	v_cvt_f32_ubyte3_e32 v54, v48                               ; 7e6c2930
	v_cvt_f32_ubyte1_e32 v57, v48                               ; 7e722530
	v_cvt_f32_ubyte0_e32 v48, v48                               ; 7e602330
	v_mac_f32_e32 v62, v28, v49                                 ; 2c7c631c
	v_cvt_f32_ubyte3_e32 v49, v46                               ; 7e62292e
	v_cvt_f32_ubyte0_e32 v46, v46                               ; 7e5c232e
	v_mul_f32_e32 v54, v23, v54                                 ; 0a6c6d17
	v_mul_f32_e32 v49, v35, v49                                 ; 0a626323
	v_mac_f32_e32 v54, v22, v55                                 ; 2c6c6f16
	v_mac_f32_e32 v49, v34, v51                                 ; 2c626722
	v_mac_f32_e32 v54, v21, v57                                 ; 2c6c7315
	v_mac_f32_e32 v49, v33, v53                                 ; 2c626b21
	v_mac_f32_e32 v54, v20, v48                                 ; 2c6c6114
	v_mac_f32_e32 v49, v32, v46                                 ; 2c625d20
	v_mul_f32_e32 v54, v54, v59                                 ; 0a6c7736
	v_mac_f32_e32 v54, v49, v43                                 ; 2c6c5731
	v_mac_f32_e32 v54, v62, v56                                 ; 2c6c713e
	v_mac_f32_e32 v54, v61, v52                                 ; 2c6c693d
	v_mac_f32_e32 v11, v40, v54                                 ; 2c166d28
	s_cbranch_scc0 BB172                                        ; bf84035e
BB133:
	s_add_u32 s0, s16, 8                                        ; 80008810
	s_mul_i32 s0, s0, s3                                        ; 92000300
	s_add_u32 s0, s19, s0                                       ; 80000013
	v_add_u32_e32 v40, s0, v0                                   ; 68500000
	v_lshlrev_b32_e32 v41, 4, v40                               ; 24525084
	v_lshl_add_u32 v40, v40, 7, v41                             ; d1fd0028 04a50f28
	v_add_u32_e32 v43, 4, v40                                   ; 68565084
	v_add_u32_e32 v48, 16, v40                                  ; 68605090
	v_add_u32_e32 v45, v44, v43                                 ; 685a572c
	v_add_u32_e32 v46, v43, v42                                 ; 685c552b
	v_add_u32_e32 v43, v43, v47                                 ; 68565f2b
	v_add_u32_e32 v49, v48, v4                                  ; 68620930
	v_add_u32_e32 v48, v48, v50                                 ; 68606530
	buffer_load_dword v40, v40, s[12:15], 0 offen               ; e0501000 80032828
	buffer_load_dwordx2 v[52:53], v45, s[12:15], 0 offen        ; e0541000 8003342d
	buffer_load_ushort v43, v43, s[12:15], 0 offen              ; e0481000 80032b2b
	buffer_load_dword v49, v49, s[12:15], 0 offen               ; e0501000 80033131
	buffer_load_dword v48, v48, s[12:15], 0 offen               ; e0501000 80033030
	s_mov_b32 s1, 0xf0f0f0f                                     ; be8100ff 0f0f0f0f
	s_cmp_lt_u32 9, s4                                          ; bf0a0489
	s_waitcnt vmcnt(4)                                          ; bf8c3f74
	v_cvt_f32_f16_sdwa v51, v40 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e6616f9 00050628
	v_cvt_f32_f16_e32 v40, v40                                  ; 7e501728
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_alignbyte_b32 v52, v53, v52, v46                          ; d1cf0034 04ba6935
	v_alignbyte_b32 v53, v53, v53, v46                          ; d1cf0035 04ba6b35
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_lshl_or_b32 v43, v43, 12, v43                             ; d200002b 04ad192b
	v_mov_b32_sdwa v52, v53 dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_0 ; 7e6802f9 00041535
	v_and_b32_e32 v53, 0xc0c0c0c0, v52                          ; 266a68ff c0c0c0c0
	v_and_b32_e32 v52, 0x3f3f3f3f, v52                          ; 266868ff 3f3f3f3f
	v_lshrrev_b32_e32 v53, 2, v53                               ; 206a6a82
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v60, s1, v49                                  ; 26786201
	v_cvt_f32_ubyte3_e32 v54, v52                               ; 7e6c2934
	v_cvt_f32_ubyte2_e32 v55, v52                               ; 7e6e2734
	v_cvt_f32_ubyte1_e32 v56, v52                               ; 7e702534
	v_cvt_f32_ubyte0_e32 v52, v52                               ; 7e682334
	v_and_or_b32 v43, s1, v43, v53                              ; d201002b 04d65601
	v_cvt_f32_ubyte3_e32 v61, v60                               ; 7e7a293c
	v_cvt_f32_ubyte2_e32 v62, v60                               ; 7e7c273c
	v_cvt_f32_ubyte1_e32 v59, v43                               ; 7e76252b
	v_cvt_f32_ubyte3_e32 v57, v43                               ; 7e72292b
	v_cvt_f32_ubyte2_e32 v58, v43                               ; 7e74272b
	v_cvt_f32_ubyte0_e32 v43, v43                               ; 7e56232b
	v_mul_f32_e32 v61, v27, v61                                 ; 0a7a7b1b
	v_lshrrev_b32_e32 v49, 4, v49                               ; 20626284
	v_mul_f32_e32 v57, v39, v57                                 ; 0a727327
	v_mac_f32_e32 v61, v26, v62                                 ; 2c7a7d1a
	v_cvt_f32_ubyte1_e32 v62, v60                               ; 7e7c253c
	v_cvt_f32_ubyte0_e32 v60, v60                               ; 7e78233c
	v_and_b32_e32 v49, s1, v49                                  ; 26626201
	v_mac_f32_e32 v57, v38, v58                                 ; 2c727526
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v46, s1, v48                                  ; 265c6001
	v_mac_f32_e32 v61, v25, v62                                 ; 2c7a7d19
	v_cvt_f32_ubyte3_e32 v62, v49                               ; 7e7c2931
	v_cvt_f32_ubyte2_e32 v41, v49                               ; 7e522731
	v_cvt_f32_ubyte1_e32 v45, v49                               ; 7e5a2531
	v_cvt_f32_ubyte0_e32 v49, v49                               ; 7e622331
	v_mac_f32_e32 v57, v37, v54                                 ; 2c726d25
	v_cvt_f32_ubyte1_e32 v53, v46                               ; 7e6a252e
	v_mac_f32_e32 v61, v24, v60                                 ; 2c7a7918
	v_mul_f32_e32 v62, v31, v62                                 ; 0a7c7d1f
	v_lshrrev_b32_e32 v48, 4, v48                               ; 20606084
	v_mac_f32_e32 v57, v36, v55                                 ; 2c726f24
	v_mac_f32_e32 v62, v30, v41                                 ; 2c7c531e
	v_and_b32_e32 v48, s1, v48                                  ; 26606001
	v_mad_f32 v12, -v51, v57, v12                               ; d1c1000c 24327333
	v_cvt_f32_ubyte2_e32 v51, v46                               ; 7e66272e
	v_mac_f32_e32 v62, v29, v45                                 ; 2c7c5b1d
	v_cvt_f32_ubyte2_e32 v55, v48                               ; 7e6e2730
	v_cvt_f32_ubyte3_e32 v54, v48                               ; 7e6c2930
	v_cvt_f32_ubyte1_e32 v57, v48                               ; 7e722530
	v_cvt_f32_ubyte0_e32 v48, v48                               ; 7e602330
	v_mac_f32_e32 v62, v28, v49                                 ; 2c7c631c
	v_cvt_f32_ubyte3_e32 v49, v46                               ; 7e62292e
	v_cvt_f32_ubyte0_e32 v46, v46                               ; 7e5c232e
	v_mul_f32_e32 v54, v23, v54                                 ; 0a6c6d17
	v_mul_f32_e32 v49, v35, v49                                 ; 0a626323
	v_mac_f32_e32 v54, v22, v55                                 ; 2c6c6f16
	v_mac_f32_e32 v49, v34, v51                                 ; 2c626722
	v_mac_f32_e32 v54, v21, v57                                 ; 2c6c7315
	v_mac_f32_e32 v49, v33, v53                                 ; 2c626b21
	v_mac_f32_e32 v54, v20, v48                                 ; 2c6c6114
	v_mac_f32_e32 v49, v32, v46                                 ; 2c625d20
	v_mul_f32_e32 v54, v54, v59                                 ; 0a6c7736
	v_mac_f32_e32 v54, v49, v43                                 ; 2c6c5731
	v_mac_f32_e32 v54, v62, v56                                 ; 2c6c713e
	v_mac_f32_e32 v54, v61, v52                                 ; 2c6c693d
	v_mac_f32_e32 v12, v40, v54                                 ; 2c186d28
	s_cbranch_scc0 BB172                                        ; bf8402f2
BB134:
	s_add_u32 s0, s16, 9                                        ; 80008910
	s_mul_i32 s0, s0, s3                                        ; 92000300
	s_add_u32 s0, s19, s0                                       ; 80000013
	v_add_u32_e32 v40, s0, v0                                   ; 68500000
	v_lshlrev_b32_e32 v41, 4, v40                               ; 24525084
	v_lshl_add_u32 v40, v40, 7, v41                             ; d1fd0028 04a50f28
	v_add_u32_e32 v43, 4, v40                                   ; 68565084
	v_add_u32_e32 v48, 16, v40                                  ; 68605090
	v_add_u32_e32 v45, v44, v43                                 ; 685a572c
	v_add_u32_e32 v46, v43, v42                                 ; 685c552b
	v_add_u32_e32 v43, v43, v47                                 ; 68565f2b
	v_add_u32_e32 v49, v48, v4                                  ; 68620930
	v_add_u32_e32 v48, v48, v50                                 ; 68606530
	buffer_load_dword v40, v40, s[12:15], 0 offen               ; e0501000 80032828
	buffer_load_dwordx2 v[52:53], v45, s[12:15], 0 offen        ; e0541000 8003342d
	buffer_load_ushort v43, v43, s[12:15], 0 offen              ; e0481000 80032b2b
	buffer_load_dword v49, v49, s[12:15], 0 offen               ; e0501000 80033131
	buffer_load_dword v48, v48, s[12:15], 0 offen               ; e0501000 80033030
	s_mov_b32 s1, 0xf0f0f0f                                     ; be8100ff 0f0f0f0f
	s_cmp_lt_u32 10, s4                                         ; bf0a048a
	s_waitcnt vmcnt(4)                                          ; bf8c3f74
	v_cvt_f32_f16_sdwa v51, v40 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e6616f9 00050628
	v_cvt_f32_f16_e32 v40, v40                                  ; 7e501728
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_alignbyte_b32 v52, v53, v52, v46                          ; d1cf0034 04ba6935
	v_alignbyte_b32 v53, v53, v53, v46                          ; d1cf0035 04ba6b35
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_lshl_or_b32 v43, v43, 12, v43                             ; d200002b 04ad192b
	v_mov_b32_sdwa v52, v53 dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_0 ; 7e6802f9 00041535
	v_and_b32_e32 v53, 0xc0c0c0c0, v52                          ; 266a68ff c0c0c0c0
	v_and_b32_e32 v52, 0x3f3f3f3f, v52                          ; 266868ff 3f3f3f3f
	v_lshrrev_b32_e32 v53, 2, v53                               ; 206a6a82
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v60, s1, v49                                  ; 26786201
	v_cvt_f32_ubyte3_e32 v54, v52                               ; 7e6c2934
	v_cvt_f32_ubyte2_e32 v55, v52                               ; 7e6e2734
	v_cvt_f32_ubyte1_e32 v56, v52                               ; 7e702534
	v_cvt_f32_ubyte0_e32 v52, v52                               ; 7e682334
	v_and_or_b32 v43, s1, v43, v53                              ; d201002b 04d65601
	v_cvt_f32_ubyte3_e32 v61, v60                               ; 7e7a293c
	v_cvt_f32_ubyte2_e32 v62, v60                               ; 7e7c273c
	v_cvt_f32_ubyte1_e32 v59, v43                               ; 7e76252b
	v_cvt_f32_ubyte3_e32 v57, v43                               ; 7e72292b
	v_cvt_f32_ubyte2_e32 v58, v43                               ; 7e74272b
	v_cvt_f32_ubyte0_e32 v43, v43                               ; 7e56232b
	v_mul_f32_e32 v61, v27, v61                                 ; 0a7a7b1b
	v_lshrrev_b32_e32 v49, 4, v49                               ; 20626284
	v_mul_f32_e32 v57, v39, v57                                 ; 0a727327
	v_mac_f32_e32 v61, v26, v62                                 ; 2c7a7d1a
	v_cvt_f32_ubyte1_e32 v62, v60                               ; 7e7c253c
	v_cvt_f32_ubyte0_e32 v60, v60                               ; 7e78233c
	v_and_b32_e32 v49, s1, v49                                  ; 26626201
	v_mac_f32_e32 v57, v38, v58                                 ; 2c727526
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v46, s1, v48                                  ; 265c6001
	v_mac_f32_e32 v61, v25, v62                                 ; 2c7a7d19
	v_cvt_f32_ubyte3_e32 v62, v49                               ; 7e7c2931
	v_cvt_f32_ubyte2_e32 v41, v49                               ; 7e522731
	v_cvt_f32_ubyte1_e32 v45, v49                               ; 7e5a2531
	v_cvt_f32_ubyte0_e32 v49, v49                               ; 7e622331
	v_mac_f32_e32 v57, v37, v54                                 ; 2c726d25
	v_cvt_f32_ubyte1_e32 v53, v46                               ; 7e6a252e
	v_mac_f32_e32 v61, v24, v60                                 ; 2c7a7918
	v_mul_f32_e32 v62, v31, v62                                 ; 0a7c7d1f
	v_lshrrev_b32_e32 v48, 4, v48                               ; 20606084
	v_mac_f32_e32 v57, v36, v55                                 ; 2c726f24
	v_mac_f32_e32 v62, v30, v41                                 ; 2c7c531e
	v_and_b32_e32 v48, s1, v48                                  ; 26606001
	v_mad_f32 v13, -v51, v57, v13                               ; d1c1000d 24367333
	v_cvt_f32_ubyte2_e32 v51, v46                               ; 7e66272e
	v_mac_f32_e32 v62, v29, v45                                 ; 2c7c5b1d
	v_cvt_f32_ubyte2_e32 v55, v48                               ; 7e6e2730
	v_cvt_f32_ubyte3_e32 v54, v48                               ; 7e6c2930
	v_cvt_f32_ubyte1_e32 v57, v48                               ; 7e722530
	v_cvt_f32_ubyte0_e32 v48, v48                               ; 7e602330
	v_mac_f32_e32 v62, v28, v49                                 ; 2c7c631c
	v_cvt_f32_ubyte3_e32 v49, v46                               ; 7e62292e
	v_cvt_f32_ubyte0_e32 v46, v46                               ; 7e5c232e
	v_mul_f32_e32 v54, v23, v54                                 ; 0a6c6d17
	v_mul_f32_e32 v49, v35, v49                                 ; 0a626323
	v_mac_f32_e32 v54, v22, v55                                 ; 2c6c6f16
	v_mac_f32_e32 v49, v34, v51                                 ; 2c626722
	v_mac_f32_e32 v54, v21, v57                                 ; 2c6c7315
	v_mac_f32_e32 v49, v33, v53                                 ; 2c626b21
	v_mac_f32_e32 v54, v20, v48                                 ; 2c6c6114
	v_mac_f32_e32 v49, v32, v46                                 ; 2c625d20
	v_mul_f32_e32 v54, v54, v59                                 ; 0a6c7736
	v_mac_f32_e32 v54, v49, v43                                 ; 2c6c5731
	v_mac_f32_e32 v54, v62, v56                                 ; 2c6c713e
	v_mac_f32_e32 v54, v61, v52                                 ; 2c6c693d
	v_mac_f32_e32 v13, v40, v54                                 ; 2c1a6d28
	s_cbranch_scc0 BB172                                        ; bf840286
BB135:
	s_add_u32 s0, s16, 10                                       ; 80008a10
	s_mul_i32 s0, s0, s3                                        ; 92000300
	s_add_u32 s0, s19, s0                                       ; 80000013
	v_add_u32_e32 v40, s0, v0                                   ; 68500000
	v_lshlrev_b32_e32 v41, 4, v40                               ; 24525084
	v_lshl_add_u32 v40, v40, 7, v41                             ; d1fd0028 04a50f28
	v_add_u32_e32 v43, 4, v40                                   ; 68565084
	v_add_u32_e32 v48, 16, v40                                  ; 68605090
	v_add_u32_e32 v45, v44, v43                                 ; 685a572c
	v_add_u32_e32 v46, v43, v42                                 ; 685c552b
	v_add_u32_e32 v43, v43, v47                                 ; 68565f2b
	v_add_u32_e32 v49, v48, v4                                  ; 68620930
	v_add_u32_e32 v48, v48, v50                                 ; 68606530
	buffer_load_dword v40, v40, s[12:15], 0 offen               ; e0501000 80032828
	buffer_load_dwordx2 v[52:53], v45, s[12:15], 0 offen        ; e0541000 8003342d
	buffer_load_ushort v43, v43, s[12:15], 0 offen              ; e0481000 80032b2b
	buffer_load_dword v49, v49, s[12:15], 0 offen               ; e0501000 80033131
	buffer_load_dword v48, v48, s[12:15], 0 offen               ; e0501000 80033030
	s_mov_b32 s1, 0xf0f0f0f                                     ; be8100ff 0f0f0f0f
	s_cmp_lt_u32 11, s4                                         ; bf0a048b
	s_waitcnt vmcnt(4)                                          ; bf8c3f74
	v_cvt_f32_f16_sdwa v51, v40 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e6616f9 00050628
	v_cvt_f32_f16_e32 v40, v40                                  ; 7e501728
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_alignbyte_b32 v52, v53, v52, v46                          ; d1cf0034 04ba6935
	v_alignbyte_b32 v53, v53, v53, v46                          ; d1cf0035 04ba6b35
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_lshl_or_b32 v43, v43, 12, v43                             ; d200002b 04ad192b
	v_mov_b32_sdwa v52, v53 dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_0 ; 7e6802f9 00041535
	v_and_b32_e32 v53, 0xc0c0c0c0, v52                          ; 266a68ff c0c0c0c0
	v_and_b32_e32 v52, 0x3f3f3f3f, v52                          ; 266868ff 3f3f3f3f
	v_lshrrev_b32_e32 v53, 2, v53                               ; 206a6a82
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v60, s1, v49                                  ; 26786201
	v_cvt_f32_ubyte3_e32 v54, v52                               ; 7e6c2934
	v_cvt_f32_ubyte2_e32 v55, v52                               ; 7e6e2734
	v_cvt_f32_ubyte1_e32 v56, v52                               ; 7e702534
	v_cvt_f32_ubyte0_e32 v52, v52                               ; 7e682334
	v_and_or_b32 v43, s1, v43, v53                              ; d201002b 04d65601
	v_cvt_f32_ubyte3_e32 v61, v60                               ; 7e7a293c
	v_cvt_f32_ubyte2_e32 v62, v60                               ; 7e7c273c
	v_cvt_f32_ubyte1_e32 v59, v43                               ; 7e76252b
	v_cvt_f32_ubyte3_e32 v57, v43                               ; 7e72292b
	v_cvt_f32_ubyte2_e32 v58, v43                               ; 7e74272b
	v_cvt_f32_ubyte0_e32 v43, v43                               ; 7e56232b
	v_mul_f32_e32 v61, v27, v61                                 ; 0a7a7b1b
	v_lshrrev_b32_e32 v49, 4, v49                               ; 20626284
	v_mul_f32_e32 v57, v39, v57                                 ; 0a727327
	v_mac_f32_e32 v61, v26, v62                                 ; 2c7a7d1a
	v_cvt_f32_ubyte1_e32 v62, v60                               ; 7e7c253c
	v_cvt_f32_ubyte0_e32 v60, v60                               ; 7e78233c
	v_and_b32_e32 v49, s1, v49                                  ; 26626201
	v_mac_f32_e32 v57, v38, v58                                 ; 2c727526
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v46, s1, v48                                  ; 265c6001
	v_mac_f32_e32 v61, v25, v62                                 ; 2c7a7d19
	v_cvt_f32_ubyte3_e32 v62, v49                               ; 7e7c2931
	v_cvt_f32_ubyte2_e32 v41, v49                               ; 7e522731
	v_cvt_f32_ubyte1_e32 v45, v49                               ; 7e5a2531
	v_cvt_f32_ubyte0_e32 v49, v49                               ; 7e622331
	v_mac_f32_e32 v57, v37, v54                                 ; 2c726d25
	v_cvt_f32_ubyte1_e32 v53, v46                               ; 7e6a252e
	v_mac_f32_e32 v61, v24, v60                                 ; 2c7a7918
	v_mul_f32_e32 v62, v31, v62                                 ; 0a7c7d1f
	v_lshrrev_b32_e32 v48, 4, v48                               ; 20606084
	v_mac_f32_e32 v57, v36, v55                                 ; 2c726f24
	v_mac_f32_e32 v62, v30, v41                                 ; 2c7c531e
	v_and_b32_e32 v48, s1, v48                                  ; 26606001
	v_mad_f32 v14, -v51, v57, v14                               ; d1c1000e 243a7333
	v_cvt_f32_ubyte2_e32 v51, v46                               ; 7e66272e
	v_mac_f32_e32 v62, v29, v45                                 ; 2c7c5b1d
	v_cvt_f32_ubyte2_e32 v55, v48                               ; 7e6e2730
	v_cvt_f32_ubyte3_e32 v54, v48                               ; 7e6c2930
	v_cvt_f32_ubyte1_e32 v57, v48                               ; 7e722530
	v_cvt_f32_ubyte0_e32 v48, v48                               ; 7e602330
	v_mac_f32_e32 v62, v28, v49                                 ; 2c7c631c
	v_cvt_f32_ubyte3_e32 v49, v46                               ; 7e62292e
	v_cvt_f32_ubyte0_e32 v46, v46                               ; 7e5c232e
	v_mul_f32_e32 v54, v23, v54                                 ; 0a6c6d17
	v_mul_f32_e32 v49, v35, v49                                 ; 0a626323
	v_mac_f32_e32 v54, v22, v55                                 ; 2c6c6f16
	v_mac_f32_e32 v49, v34, v51                                 ; 2c626722
	v_mac_f32_e32 v54, v21, v57                                 ; 2c6c7315
	v_mac_f32_e32 v49, v33, v53                                 ; 2c626b21
	v_mac_f32_e32 v54, v20, v48                                 ; 2c6c6114
	v_mac_f32_e32 v49, v32, v46                                 ; 2c625d20
	v_mul_f32_e32 v54, v54, v59                                 ; 0a6c7736
	v_mac_f32_e32 v54, v49, v43                                 ; 2c6c5731
	v_mac_f32_e32 v54, v62, v56                                 ; 2c6c713e
	v_mac_f32_e32 v54, v61, v52                                 ; 2c6c693d
	v_mac_f32_e32 v14, v40, v54                                 ; 2c1c6d28
	s_cbranch_scc0 BB172                                        ; bf84021a
BB136:
	s_add_u32 s0, s16, 11                                       ; 80008b10
	s_mul_i32 s0, s0, s3                                        ; 92000300
	s_add_u32 s0, s19, s0                                       ; 80000013
	v_add_u32_e32 v40, s0, v0                                   ; 68500000
	v_lshlrev_b32_e32 v41, 4, v40                               ; 24525084
	v_lshl_add_u32 v40, v40, 7, v41                             ; d1fd0028 04a50f28
	v_add_u32_e32 v43, 4, v40                                   ; 68565084
	v_add_u32_e32 v48, 16, v40                                  ; 68605090
	v_add_u32_e32 v45, v44, v43                                 ; 685a572c
	v_add_u32_e32 v46, v43, v42                                 ; 685c552b
	v_add_u32_e32 v43, v43, v47                                 ; 68565f2b
	v_add_u32_e32 v49, v48, v4                                  ; 68620930
	v_add_u32_e32 v48, v48, v50                                 ; 68606530
	buffer_load_dword v40, v40, s[12:15], 0 offen               ; e0501000 80032828
	buffer_load_dwordx2 v[52:53], v45, s[12:15], 0 offen        ; e0541000 8003342d
	buffer_load_ushort v43, v43, s[12:15], 0 offen              ; e0481000 80032b2b
	buffer_load_dword v49, v49, s[12:15], 0 offen               ; e0501000 80033131
	buffer_load_dword v48, v48, s[12:15], 0 offen               ; e0501000 80033030
	s_mov_b32 s1, 0xf0f0f0f                                     ; be8100ff 0f0f0f0f
	s_cmp_lt_u32 12, s4                                         ; bf0a048c
	s_waitcnt vmcnt(4)                                          ; bf8c3f74
	v_cvt_f32_f16_sdwa v51, v40 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e6616f9 00050628
	v_cvt_f32_f16_e32 v40, v40                                  ; 7e501728
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_alignbyte_b32 v52, v53, v52, v46                          ; d1cf0034 04ba6935
	v_alignbyte_b32 v53, v53, v53, v46                          ; d1cf0035 04ba6b35
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_lshl_or_b32 v43, v43, 12, v43                             ; d200002b 04ad192b
	v_mov_b32_sdwa v52, v53 dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_0 ; 7e6802f9 00041535
	v_and_b32_e32 v53, 0xc0c0c0c0, v52                          ; 266a68ff c0c0c0c0
	v_and_b32_e32 v52, 0x3f3f3f3f, v52                          ; 266868ff 3f3f3f3f
	v_lshrrev_b32_e32 v53, 2, v53                               ; 206a6a82
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v60, s1, v49                                  ; 26786201
	v_cvt_f32_ubyte3_e32 v54, v52                               ; 7e6c2934
	v_cvt_f32_ubyte2_e32 v55, v52                               ; 7e6e2734
	v_cvt_f32_ubyte1_e32 v56, v52                               ; 7e702534
	v_cvt_f32_ubyte0_e32 v52, v52                               ; 7e682334
	v_and_or_b32 v43, s1, v43, v53                              ; d201002b 04d65601
	v_cvt_f32_ubyte3_e32 v61, v60                               ; 7e7a293c
	v_cvt_f32_ubyte2_e32 v62, v60                               ; 7e7c273c
	v_cvt_f32_ubyte1_e32 v59, v43                               ; 7e76252b
	v_cvt_f32_ubyte3_e32 v57, v43                               ; 7e72292b
	v_cvt_f32_ubyte2_e32 v58, v43                               ; 7e74272b
	v_cvt_f32_ubyte0_e32 v43, v43                               ; 7e56232b
	v_mul_f32_e32 v61, v27, v61                                 ; 0a7a7b1b
	v_lshrrev_b32_e32 v49, 4, v49                               ; 20626284
	v_mul_f32_e32 v57, v39, v57                                 ; 0a727327
	v_mac_f32_e32 v61, v26, v62                                 ; 2c7a7d1a
	v_cvt_f32_ubyte1_e32 v62, v60                               ; 7e7c253c
	v_cvt_f32_ubyte0_e32 v60, v60                               ; 7e78233c
	v_and_b32_e32 v49, s1, v49                                  ; 26626201
	v_mac_f32_e32 v57, v38, v58                                 ; 2c727526
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v46, s1, v48                                  ; 265c6001
	v_mac_f32_e32 v61, v25, v62                                 ; 2c7a7d19
	v_cvt_f32_ubyte3_e32 v62, v49                               ; 7e7c2931
	v_cvt_f32_ubyte2_e32 v41, v49                               ; 7e522731
	v_cvt_f32_ubyte1_e32 v45, v49                               ; 7e5a2531
	v_cvt_f32_ubyte0_e32 v49, v49                               ; 7e622331
	v_mac_f32_e32 v57, v37, v54                                 ; 2c726d25
	v_cvt_f32_ubyte1_e32 v53, v46                               ; 7e6a252e
	v_mac_f32_e32 v61, v24, v60                                 ; 2c7a7918
	v_mul_f32_e32 v62, v31, v62                                 ; 0a7c7d1f
	v_lshrrev_b32_e32 v48, 4, v48                               ; 20606084
	v_mac_f32_e32 v57, v36, v55                                 ; 2c726f24
	v_mac_f32_e32 v62, v30, v41                                 ; 2c7c531e
	v_and_b32_e32 v48, s1, v48                                  ; 26606001
	v_mad_f32 v15, -v51, v57, v15                               ; d1c1000f 243e7333
	v_cvt_f32_ubyte2_e32 v51, v46                               ; 7e66272e
	v_mac_f32_e32 v62, v29, v45                                 ; 2c7c5b1d
	v_cvt_f32_ubyte2_e32 v55, v48                               ; 7e6e2730
	v_cvt_f32_ubyte3_e32 v54, v48                               ; 7e6c2930
	v_cvt_f32_ubyte1_e32 v57, v48                               ; 7e722530
	v_cvt_f32_ubyte0_e32 v48, v48                               ; 7e602330
	v_mac_f32_e32 v62, v28, v49                                 ; 2c7c631c
	v_cvt_f32_ubyte3_e32 v49, v46                               ; 7e62292e
	v_cvt_f32_ubyte0_e32 v46, v46                               ; 7e5c232e
	v_mul_f32_e32 v54, v23, v54                                 ; 0a6c6d17
	v_mul_f32_e32 v49, v35, v49                                 ; 0a626323
	v_mac_f32_e32 v54, v22, v55                                 ; 2c6c6f16
	v_mac_f32_e32 v49, v34, v51                                 ; 2c626722
	v_mac_f32_e32 v54, v21, v57                                 ; 2c6c7315
	v_mac_f32_e32 v49, v33, v53                                 ; 2c626b21
	v_mac_f32_e32 v54, v20, v48                                 ; 2c6c6114
	v_mac_f32_e32 v49, v32, v46                                 ; 2c625d20
	v_mul_f32_e32 v54, v54, v59                                 ; 0a6c7736
	v_mac_f32_e32 v54, v49, v43                                 ; 2c6c5731
	v_mac_f32_e32 v54, v62, v56                                 ; 2c6c713e
	v_mac_f32_e32 v54, v61, v52                                 ; 2c6c693d
	v_mac_f32_e32 v15, v40, v54                                 ; 2c1e6d28
	s_cbranch_scc0 BB172                                        ; bf8401ae
BB137:
	s_add_u32 s0, s16, 12                                       ; 80008c10
	s_mul_i32 s0, s0, s3                                        ; 92000300
	s_add_u32 s0, s19, s0                                       ; 80000013
	v_add_u32_e32 v40, s0, v0                                   ; 68500000
	v_lshlrev_b32_e32 v41, 4, v40                               ; 24525084
	v_lshl_add_u32 v40, v40, 7, v41                             ; d1fd0028 04a50f28
	v_add_u32_e32 v43, 4, v40                                   ; 68565084
	v_add_u32_e32 v48, 16, v40                                  ; 68605090
	v_add_u32_e32 v45, v44, v43                                 ; 685a572c
	v_add_u32_e32 v46, v43, v42                                 ; 685c552b
	v_add_u32_e32 v43, v43, v47                                 ; 68565f2b
	v_add_u32_e32 v49, v48, v4                                  ; 68620930
	v_add_u32_e32 v48, v48, v50                                 ; 68606530
	buffer_load_dword v40, v40, s[12:15], 0 offen               ; e0501000 80032828
	buffer_load_dwordx2 v[52:53], v45, s[12:15], 0 offen        ; e0541000 8003342d
	buffer_load_ushort v43, v43, s[12:15], 0 offen              ; e0481000 80032b2b
	buffer_load_dword v49, v49, s[12:15], 0 offen               ; e0501000 80033131
	buffer_load_dword v48, v48, s[12:15], 0 offen               ; e0501000 80033030
	s_mov_b32 s1, 0xf0f0f0f                                     ; be8100ff 0f0f0f0f
	s_cmp_lt_u32 13, s4                                         ; bf0a048d
	s_waitcnt vmcnt(4)                                          ; bf8c3f74
	v_cvt_f32_f16_sdwa v51, v40 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e6616f9 00050628
	v_cvt_f32_f16_e32 v40, v40                                  ; 7e501728
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_alignbyte_b32 v52, v53, v52, v46                          ; d1cf0034 04ba6935
	v_alignbyte_b32 v53, v53, v53, v46                          ; d1cf0035 04ba6b35
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_lshl_or_b32 v43, v43, 12, v43                             ; d200002b 04ad192b
	v_mov_b32_sdwa v52, v53 dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_0 ; 7e6802f9 00041535
	v_and_b32_e32 v53, 0xc0c0c0c0, v52                          ; 266a68ff c0c0c0c0
	v_and_b32_e32 v52, 0x3f3f3f3f, v52                          ; 266868ff 3f3f3f3f
	v_lshrrev_b32_e32 v53, 2, v53                               ; 206a6a82
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v60, s1, v49                                  ; 26786201
	v_cvt_f32_ubyte3_e32 v54, v52                               ; 7e6c2934
	v_cvt_f32_ubyte2_e32 v55, v52                               ; 7e6e2734
	v_cvt_f32_ubyte1_e32 v56, v52                               ; 7e702534
	v_cvt_f32_ubyte0_e32 v52, v52                               ; 7e682334
	v_and_or_b32 v43, s1, v43, v53                              ; d201002b 04d65601
	v_cvt_f32_ubyte3_e32 v61, v60                               ; 7e7a293c
	v_cvt_f32_ubyte2_e32 v62, v60                               ; 7e7c273c
	v_cvt_f32_ubyte1_e32 v59, v43                               ; 7e76252b
	v_cvt_f32_ubyte3_e32 v57, v43                               ; 7e72292b
	v_cvt_f32_ubyte2_e32 v58, v43                               ; 7e74272b
	v_cvt_f32_ubyte0_e32 v43, v43                               ; 7e56232b
	v_mul_f32_e32 v61, v27, v61                                 ; 0a7a7b1b
	v_lshrrev_b32_e32 v49, 4, v49                               ; 20626284
	v_mul_f32_e32 v57, v39, v57                                 ; 0a727327
	v_mac_f32_e32 v61, v26, v62                                 ; 2c7a7d1a
	v_cvt_f32_ubyte1_e32 v62, v60                               ; 7e7c253c
	v_cvt_f32_ubyte0_e32 v60, v60                               ; 7e78233c
	v_and_b32_e32 v49, s1, v49                                  ; 26626201
	v_mac_f32_e32 v57, v38, v58                                 ; 2c727526
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v46, s1, v48                                  ; 265c6001
	v_mac_f32_e32 v61, v25, v62                                 ; 2c7a7d19
	v_cvt_f32_ubyte3_e32 v62, v49                               ; 7e7c2931
	v_cvt_f32_ubyte2_e32 v41, v49                               ; 7e522731
	v_cvt_f32_ubyte1_e32 v45, v49                               ; 7e5a2531
	v_cvt_f32_ubyte0_e32 v49, v49                               ; 7e622331
	v_mac_f32_e32 v57, v37, v54                                 ; 2c726d25
	v_cvt_f32_ubyte1_e32 v53, v46                               ; 7e6a252e
	v_mac_f32_e32 v61, v24, v60                                 ; 2c7a7918
	v_mul_f32_e32 v62, v31, v62                                 ; 0a7c7d1f
	v_lshrrev_b32_e32 v48, 4, v48                               ; 20606084
	v_mac_f32_e32 v57, v36, v55                                 ; 2c726f24
	v_mac_f32_e32 v62, v30, v41                                 ; 2c7c531e
	v_and_b32_e32 v48, s1, v48                                  ; 26606001
	v_mad_f32 v16, -v51, v57, v16                               ; d1c10010 24427333
	v_cvt_f32_ubyte2_e32 v51, v46                               ; 7e66272e
	v_mac_f32_e32 v62, v29, v45                                 ; 2c7c5b1d
	v_cvt_f32_ubyte2_e32 v55, v48                               ; 7e6e2730
	v_cvt_f32_ubyte3_e32 v54, v48                               ; 7e6c2930
	v_cvt_f32_ubyte1_e32 v57, v48                               ; 7e722530
	v_cvt_f32_ubyte0_e32 v48, v48                               ; 7e602330
	v_mac_f32_e32 v62, v28, v49                                 ; 2c7c631c
	v_cvt_f32_ubyte3_e32 v49, v46                               ; 7e62292e
	v_cvt_f32_ubyte0_e32 v46, v46                               ; 7e5c232e
	v_mul_f32_e32 v54, v23, v54                                 ; 0a6c6d17
	v_mul_f32_e32 v49, v35, v49                                 ; 0a626323
	v_mac_f32_e32 v54, v22, v55                                 ; 2c6c6f16
	v_mac_f32_e32 v49, v34, v51                                 ; 2c626722
	v_mac_f32_e32 v54, v21, v57                                 ; 2c6c7315
	v_mac_f32_e32 v49, v33, v53                                 ; 2c626b21
	v_mac_f32_e32 v54, v20, v48                                 ; 2c6c6114
	v_mac_f32_e32 v49, v32, v46                                 ; 2c625d20
	v_mul_f32_e32 v54, v54, v59                                 ; 0a6c7736
	v_mac_f32_e32 v54, v49, v43                                 ; 2c6c5731
	v_mac_f32_e32 v54, v62, v56                                 ; 2c6c713e
	v_mac_f32_e32 v54, v61, v52                                 ; 2c6c693d
	v_mac_f32_e32 v16, v40, v54                                 ; 2c206d28
	s_cbranch_scc0 BB172                                        ; bf840142
BB138:
	s_add_u32 s0, s16, 13                                       ; 80008d10
	s_mul_i32 s0, s0, s3                                        ; 92000300
	s_add_u32 s0, s19, s0                                       ; 80000013
	v_add_u32_e32 v40, s0, v0                                   ; 68500000
	v_lshlrev_b32_e32 v41, 4, v40                               ; 24525084
	v_lshl_add_u32 v40, v40, 7, v41                             ; d1fd0028 04a50f28
	v_add_u32_e32 v43, 4, v40                                   ; 68565084
	v_add_u32_e32 v48, 16, v40                                  ; 68605090
	v_add_u32_e32 v45, v44, v43                                 ; 685a572c
	v_add_u32_e32 v46, v43, v42                                 ; 685c552b
	v_add_u32_e32 v43, v43, v47                                 ; 68565f2b
	v_add_u32_e32 v49, v48, v4                                  ; 68620930
	v_add_u32_e32 v48, v48, v50                                 ; 68606530
	buffer_load_dword v40, v40, s[12:15], 0 offen               ; e0501000 80032828
	buffer_load_dwordx2 v[52:53], v45, s[12:15], 0 offen        ; e0541000 8003342d
	buffer_load_ushort v43, v43, s[12:15], 0 offen              ; e0481000 80032b2b
	buffer_load_dword v49, v49, s[12:15], 0 offen               ; e0501000 80033131
	buffer_load_dword v48, v48, s[12:15], 0 offen               ; e0501000 80033030
	s_mov_b32 s1, 0xf0f0f0f                                     ; be8100ff 0f0f0f0f
	s_cmp_lt_u32 14, s4                                         ; bf0a048e
	s_waitcnt vmcnt(4)                                          ; bf8c3f74
	v_cvt_f32_f16_sdwa v51, v40 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e6616f9 00050628
	v_cvt_f32_f16_e32 v40, v40                                  ; 7e501728
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_alignbyte_b32 v52, v53, v52, v46                          ; d1cf0034 04ba6935
	v_alignbyte_b32 v53, v53, v53, v46                          ; d1cf0035 04ba6b35
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_lshl_or_b32 v43, v43, 12, v43                             ; d200002b 04ad192b
	v_mov_b32_sdwa v52, v53 dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_0 ; 7e6802f9 00041535
	v_and_b32_e32 v53, 0xc0c0c0c0, v52                          ; 266a68ff c0c0c0c0
	v_and_b32_e32 v52, 0x3f3f3f3f, v52                          ; 266868ff 3f3f3f3f
	v_lshrrev_b32_e32 v53, 2, v53                               ; 206a6a82
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v60, s1, v49                                  ; 26786201
	v_cvt_f32_ubyte3_e32 v54, v52                               ; 7e6c2934
	v_cvt_f32_ubyte2_e32 v55, v52                               ; 7e6e2734
	v_cvt_f32_ubyte1_e32 v56, v52                               ; 7e702534
	v_cvt_f32_ubyte0_e32 v52, v52                               ; 7e682334
	v_and_or_b32 v43, s1, v43, v53                              ; d201002b 04d65601
	v_cvt_f32_ubyte3_e32 v61, v60                               ; 7e7a293c
	v_cvt_f32_ubyte2_e32 v62, v60                               ; 7e7c273c
	v_cvt_f32_ubyte1_e32 v59, v43                               ; 7e76252b
	v_cvt_f32_ubyte3_e32 v57, v43                               ; 7e72292b
	v_cvt_f32_ubyte2_e32 v58, v43                               ; 7e74272b
	v_cvt_f32_ubyte0_e32 v43, v43                               ; 7e56232b
	v_mul_f32_e32 v61, v27, v61                                 ; 0a7a7b1b
	v_lshrrev_b32_e32 v49, 4, v49                               ; 20626284
	v_mul_f32_e32 v57, v39, v57                                 ; 0a727327
	v_mac_f32_e32 v61, v26, v62                                 ; 2c7a7d1a
	v_cvt_f32_ubyte1_e32 v62, v60                               ; 7e7c253c
	v_cvt_f32_ubyte0_e32 v60, v60                               ; 7e78233c
	v_and_b32_e32 v49, s1, v49                                  ; 26626201
	v_mac_f32_e32 v57, v38, v58                                 ; 2c727526
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v46, s1, v48                                  ; 265c6001
	v_mac_f32_e32 v61, v25, v62                                 ; 2c7a7d19
	v_cvt_f32_ubyte3_e32 v62, v49                               ; 7e7c2931
	v_cvt_f32_ubyte2_e32 v41, v49                               ; 7e522731
	v_cvt_f32_ubyte1_e32 v45, v49                               ; 7e5a2531
	v_cvt_f32_ubyte0_e32 v49, v49                               ; 7e622331
	v_mac_f32_e32 v57, v37, v54                                 ; 2c726d25
	v_cvt_f32_ubyte1_e32 v53, v46                               ; 7e6a252e
	v_mac_f32_e32 v61, v24, v60                                 ; 2c7a7918
	v_mul_f32_e32 v62, v31, v62                                 ; 0a7c7d1f
	v_lshrrev_b32_e32 v48, 4, v48                               ; 20606084
	v_mac_f32_e32 v57, v36, v55                                 ; 2c726f24
	v_mac_f32_e32 v62, v30, v41                                 ; 2c7c531e
	v_and_b32_e32 v48, s1, v48                                  ; 26606001
	v_mad_f32 v17, -v51, v57, v17                               ; d1c10011 24467333
	v_cvt_f32_ubyte2_e32 v51, v46                               ; 7e66272e
	v_mac_f32_e32 v62, v29, v45                                 ; 2c7c5b1d
	v_cvt_f32_ubyte2_e32 v55, v48                               ; 7e6e2730
	v_cvt_f32_ubyte3_e32 v54, v48                               ; 7e6c2930
	v_cvt_f32_ubyte1_e32 v57, v48                               ; 7e722530
	v_cvt_f32_ubyte0_e32 v48, v48                               ; 7e602330
	v_mac_f32_e32 v62, v28, v49                                 ; 2c7c631c
	v_cvt_f32_ubyte3_e32 v49, v46                               ; 7e62292e
	v_cvt_f32_ubyte0_e32 v46, v46                               ; 7e5c232e
	v_mul_f32_e32 v54, v23, v54                                 ; 0a6c6d17
	v_mul_f32_e32 v49, v35, v49                                 ; 0a626323
	v_mac_f32_e32 v54, v22, v55                                 ; 2c6c6f16
	v_mac_f32_e32 v49, v34, v51                                 ; 2c626722
	v_mac_f32_e32 v54, v21, v57                                 ; 2c6c7315
	v_mac_f32_e32 v49, v33, v53                                 ; 2c626b21
	v_mac_f32_e32 v54, v20, v48                                 ; 2c6c6114
	v_mac_f32_e32 v49, v32, v46                                 ; 2c625d20
	v_mul_f32_e32 v54, v54, v59                                 ; 0a6c7736
	v_mac_f32_e32 v54, v49, v43                                 ; 2c6c5731
	v_mac_f32_e32 v54, v62, v56                                 ; 2c6c713e
	v_mac_f32_e32 v54, v61, v52                                 ; 2c6c693d
	v_mac_f32_e32 v17, v40, v54                                 ; 2c226d28
	s_cbranch_scc0 BB172                                        ; bf8400d6
BB139:
	s_add_u32 s0, s16, 14                                       ; 80008e10
	s_mul_i32 s0, s0, s3                                        ; 92000300
	s_add_u32 s0, s19, s0                                       ; 80000013
	v_add_u32_e32 v40, s0, v0                                   ; 68500000
	v_lshlrev_b32_e32 v41, 4, v40                               ; 24525084
	v_lshl_add_u32 v40, v40, 7, v41                             ; d1fd0028 04a50f28
	v_add_u32_e32 v43, 4, v40                                   ; 68565084
	v_add_u32_e32 v48, 16, v40                                  ; 68605090
	v_add_u32_e32 v45, v44, v43                                 ; 685a572c
	v_add_u32_e32 v46, v43, v42                                 ; 685c552b
	v_add_u32_e32 v43, v43, v47                                 ; 68565f2b
	v_add_u32_e32 v49, v48, v4                                  ; 68620930
	v_add_u32_e32 v48, v48, v50                                 ; 68606530
	buffer_load_dword v40, v40, s[12:15], 0 offen               ; e0501000 80032828
	buffer_load_dwordx2 v[52:53], v45, s[12:15], 0 offen        ; e0541000 8003342d
	buffer_load_ushort v43, v43, s[12:15], 0 offen              ; e0481000 80032b2b
	buffer_load_dword v49, v49, s[12:15], 0 offen               ; e0501000 80033131
	buffer_load_dword v48, v48, s[12:15], 0 offen               ; e0501000 80033030
	s_mov_b32 s1, 0xf0f0f0f                                     ; be8100ff 0f0f0f0f
	s_cmp_lt_u32 15, s4                                         ; bf0a048f
	s_waitcnt vmcnt(4)                                          ; bf8c3f74
	v_cvt_f32_f16_sdwa v51, v40 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e6616f9 00050628
	v_cvt_f32_f16_e32 v40, v40                                  ; 7e501728
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_alignbyte_b32 v52, v53, v52, v46                          ; d1cf0034 04ba6935
	v_alignbyte_b32 v53, v53, v53, v46                          ; d1cf0035 04ba6b35
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_lshl_or_b32 v43, v43, 12, v43                             ; d200002b 04ad192b
	v_mov_b32_sdwa v52, v53 dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_0 ; 7e6802f9 00041535
	v_and_b32_e32 v53, 0xc0c0c0c0, v52                          ; 266a68ff c0c0c0c0
	v_and_b32_e32 v52, 0x3f3f3f3f, v52                          ; 266868ff 3f3f3f3f
	v_lshrrev_b32_e32 v53, 2, v53                               ; 206a6a82
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v60, s1, v49                                  ; 26786201
	v_cvt_f32_ubyte3_e32 v54, v52                               ; 7e6c2934
	v_cvt_f32_ubyte2_e32 v55, v52                               ; 7e6e2734
	v_cvt_f32_ubyte1_e32 v56, v52                               ; 7e702534
	v_cvt_f32_ubyte0_e32 v52, v52                               ; 7e682334
	v_and_or_b32 v43, s1, v43, v53                              ; d201002b 04d65601
	v_cvt_f32_ubyte3_e32 v61, v60                               ; 7e7a293c
	v_cvt_f32_ubyte2_e32 v62, v60                               ; 7e7c273c
	v_cvt_f32_ubyte1_e32 v59, v43                               ; 7e76252b
	v_cvt_f32_ubyte3_e32 v57, v43                               ; 7e72292b
	v_cvt_f32_ubyte2_e32 v58, v43                               ; 7e74272b
	v_cvt_f32_ubyte0_e32 v43, v43                               ; 7e56232b
	v_mul_f32_e32 v61, v27, v61                                 ; 0a7a7b1b
	v_lshrrev_b32_e32 v49, 4, v49                               ; 20626284
	v_mul_f32_e32 v57, v39, v57                                 ; 0a727327
	v_mac_f32_e32 v61, v26, v62                                 ; 2c7a7d1a
	v_cvt_f32_ubyte1_e32 v62, v60                               ; 7e7c253c
	v_cvt_f32_ubyte0_e32 v60, v60                               ; 7e78233c
	v_and_b32_e32 v49, s1, v49                                  ; 26626201
	v_mac_f32_e32 v57, v38, v58                                 ; 2c727526
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v46, s1, v48                                  ; 265c6001
	v_mac_f32_e32 v61, v25, v62                                 ; 2c7a7d19
	v_cvt_f32_ubyte3_e32 v62, v49                               ; 7e7c2931
	v_cvt_f32_ubyte2_e32 v41, v49                               ; 7e522731
	v_cvt_f32_ubyte1_e32 v45, v49                               ; 7e5a2531
	v_cvt_f32_ubyte0_e32 v49, v49                               ; 7e622331
	v_mac_f32_e32 v57, v37, v54                                 ; 2c726d25
	v_cvt_f32_ubyte1_e32 v53, v46                               ; 7e6a252e
	v_mac_f32_e32 v61, v24, v60                                 ; 2c7a7918
	v_mul_f32_e32 v62, v31, v62                                 ; 0a7c7d1f
	v_lshrrev_b32_e32 v48, 4, v48                               ; 20606084
	v_mac_f32_e32 v57, v36, v55                                 ; 2c726f24
	v_mac_f32_e32 v62, v30, v41                                 ; 2c7c531e
	v_and_b32_e32 v48, s1, v48                                  ; 26606001
	v_mad_f32 v18, -v51, v57, v18                               ; d1c10012 244a7333
	v_cvt_f32_ubyte2_e32 v51, v46                               ; 7e66272e
	v_mac_f32_e32 v62, v29, v45                                 ; 2c7c5b1d
	v_cvt_f32_ubyte2_e32 v55, v48                               ; 7e6e2730
	v_cvt_f32_ubyte3_e32 v54, v48                               ; 7e6c2930
	v_cvt_f32_ubyte1_e32 v57, v48                               ; 7e722530
	v_cvt_f32_ubyte0_e32 v48, v48                               ; 7e602330
	v_mac_f32_e32 v62, v28, v49                                 ; 2c7c631c
	v_cvt_f32_ubyte3_e32 v49, v46                               ; 7e62292e
	v_cvt_f32_ubyte0_e32 v46, v46                               ; 7e5c232e
	v_mul_f32_e32 v54, v23, v54                                 ; 0a6c6d17
	v_mul_f32_e32 v49, v35, v49                                 ; 0a626323
	v_mac_f32_e32 v54, v22, v55                                 ; 2c6c6f16
	v_mac_f32_e32 v49, v34, v51                                 ; 2c626722
	v_mac_f32_e32 v54, v21, v57                                 ; 2c6c7315
	v_mac_f32_e32 v49, v33, v53                                 ; 2c626b21
	v_mac_f32_e32 v54, v20, v48                                 ; 2c6c6114
	v_mac_f32_e32 v49, v32, v46                                 ; 2c625d20
	v_mul_f32_e32 v54, v54, v59                                 ; 0a6c7736
	v_mac_f32_e32 v54, v49, v43                                 ; 2c6c5731
	v_mac_f32_e32 v54, v62, v56                                 ; 2c6c713e
	v_mac_f32_e32 v54, v61, v52                                 ; 2c6c693d
	v_mac_f32_e32 v18, v40, v54                                 ; 2c246d28
	s_cbranch_scc0 BB172                                        ; bf84006a
BB140:
	s_add_u32 s0, s16, 15                                       ; 80008f10
	s_mul_i32 s0, s0, s3                                        ; 92000300
	s_add_u32 s0, s19, s0                                       ; 80000013
	v_add_u32_e32 v40, s0, v0                                   ; 68500000
	v_lshlrev_b32_e32 v41, 4, v40                               ; 24525084
	v_lshl_add_u32 v40, v40, 7, v41                             ; d1fd0028 04a50f28
	v_add_u32_e32 v43, 4, v40                                   ; 68565084
	v_add_u32_e32 v45, 16, v40                                  ; 685a5090
	v_add_u32_e32 v44, v44, v43                                 ; 6858572c
	v_add_u32_e32 v42, v43, v42                                 ; 6854552b
	v_add_u32_e32 v43, v43, v47                                 ; 68565f2b
	v_add_u32_e32 v46, v45, v4                                  ; 685c092d
	v_add_u32_e32 v45, v45, v50                                 ; 685a652d
	buffer_load_dword v40, v40, s[12:15], 0 offen               ; e0501000 80032828
	buffer_load_dwordx2 v[48:49], v44, s[12:15], 0 offen        ; e0541000 8003302c
	buffer_load_ushort v43, v43, s[12:15], 0 offen              ; e0481000 80032b2b
	buffer_load_dword v46, v46, s[12:15], 0 offen               ; e0501000 80032e2e
	buffer_load_dword v45, v45, s[12:15], 0 offen               ; e0501000 80032d2d
	s_mov_b32 s1, 0xf0f0f0f                                     ; be8100ff 0f0f0f0f
	s_waitcnt vmcnt(4)                                          ; bf8c3f74
	v_cvt_f32_f16_sdwa v47, v40 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e5e16f9 00050628
	v_cvt_f32_f16_e32 v40, v40                                  ; 7e501728
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_alignbyte_b32 v48, v49, v48, v42                          ; d1cf0030 04aa6131
	v_alignbyte_b32 v49, v49, v49, v42                          ; d1cf0031 04aa6331
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_lshl_or_b32 v43, v43, 12, v43                             ; d200002b 04ad192b
	v_mov_b32_sdwa v48, v49 dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_0 ; 7e6002f9 00041531
	v_and_b32_e32 v49, 0xc0c0c0c0, v48                          ; 266260ff c0c0c0c0
	v_and_b32_e32 v48, 0x3f3f3f3f, v48                          ; 266060ff 3f3f3f3f
	v_lshrrev_b32_e32 v49, 2, v49                               ; 20626282
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v56, s1, v46                                  ; 26705c01
	v_cvt_f32_ubyte3_e32 v50, v48                               ; 7e642930
	v_cvt_f32_ubyte2_e32 v51, v48                               ; 7e662730
	v_cvt_f32_ubyte1_e32 v52, v48                               ; 7e682530
	v_cvt_f32_ubyte0_e32 v48, v48                               ; 7e602330
	v_and_or_b32 v43, s1, v43, v49                              ; d201002b 04c65601
	v_cvt_f32_ubyte3_e32 v57, v56                               ; 7e722938
	v_cvt_f32_ubyte2_e32 v58, v56                               ; 7e742738
	v_cvt_f32_ubyte1_e32 v59, v56                               ; 7e762538
	v_cvt_f32_ubyte0_e32 v56, v56                               ; 7e702338
	v_cvt_f32_ubyte3_e32 v53, v43                               ; 7e6a292b
	v_cvt_f32_ubyte2_e32 v54, v43                               ; 7e6c272b
	v_cvt_f32_ubyte1_e32 v55, v43                               ; 7e6e252b
	v_cvt_f32_ubyte0_e32 v43, v43                               ; 7e56232b
	v_mul_f32_e32 v27, v27, v57                                 ; 0a36731b
	v_lshrrev_b32_e32 v46, 4, v46                               ; 205c5c84
	v_mul_f32_e32 v39, v39, v53                                 ; 0a4e6b27
	v_mac_f32_e32 v27, v26, v58                                 ; 2c36751a
	v_and_b32_e32 v46, s1, v46                                  ; 265c5c01
	v_mac_f32_e32 v39, v38, v54                                 ; 2c4e6d26
	v_mac_f32_e32 v27, v25, v59                                 ; 2c367719
	v_cvt_f32_ubyte3_e32 v60, v46                               ; 7e78292e
	v_cvt_f32_ubyte2_e32 v61, v46                               ; 7e7a272e
	v_cvt_f32_ubyte1_e32 v62, v46                               ; 7e7c252e
	v_cvt_f32_ubyte0_e32 v46, v46                               ; 7e5c232e
	v_mac_f32_e32 v39, v37, v50                                 ; 2c4e6525
	v_mac_f32_e32 v27, v24, v56                                 ; 2c367118
	v_mul_f32_e32 v31, v31, v60                                 ; 0a3e791f
	v_mac_f32_e32 v39, v36, v51                                 ; 2c4e6724
	v_mac_f32_e32 v31, v30, v61                                 ; 2c3e7b1e
	v_mad_f32 v19, -v47, v39, v19                               ; d1c10013 244e4f2f
	v_mac_f32_e32 v31, v29, v62                                 ; 2c3e7d1d
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v62, s1, v45                                  ; 267c5a01
	v_lshrrev_b32_e32 v45, 4, v45                               ; 205a5a84
	v_mac_f32_e32 v31, v28, v46                                 ; 2c3e5d1c
	v_cvt_f32_ubyte1_e32 v26, v62                               ; 7e34253e
	v_cvt_f32_ubyte3_e32 v24, v62                               ; 7e30293e
	v_cvt_f32_ubyte2_e32 v25, v62                               ; 7e32273e
	v_cvt_f32_ubyte0_e32 v62, v62                               ; 7e7c233e
	v_and_b32_e32 v45, s1, v45                                  ; 265a5a01
	v_mul_f32_e32 v35, v35, v24                                 ; 0a463123
	v_cvt_f32_ubyte3_e32 v28, v45                               ; 7e38292d
	v_cvt_f32_ubyte2_e32 v29, v45                               ; 7e3a272d
	v_cvt_f32_ubyte1_e32 v30, v45                               ; 7e3c252d
	v_cvt_f32_ubyte0_e32 v45, v45                               ; 7e5a232d
	v_mac_f32_e32 v35, v34, v25                                 ; 2c463322
	v_mul_f32_e32 v23, v23, v28                                 ; 0a2e3917
	v_mac_f32_e32 v35, v33, v26                                 ; 2c463521
	v_mac_f32_e32 v23, v22, v29                                 ; 2c2e3b16
	v_mac_f32_e32 v35, v32, v62                                 ; 2c467d20
	v_mac_f32_e32 v23, v21, v30                                 ; 2c2e3d15
	v_mac_f32_e32 v23, v20, v45                                 ; 2c2e5b14
	v_mul_f32_e32 v23, v23, v55                                 ; 0a2e6f17
	v_mac_f32_e32 v23, v35, v43                                 ; 2c2e5723
	v_mac_f32_e32 v23, v31, v52                                 ; 2c2e691f
	v_mac_f32_e32 v23, v27, v48                                 ; 2c2e611b
	v_mac_f32_e32 v19, v40, v23                                 ; 2c262f28
BB172:
	v_add_u32_e32 v0, 4, v0                                     ; 68000084
	s_branch BB119                                              ; bf82f90b
BB173:
	s_mov_b64 exec, -1                                          ; befe01c1
	s_cmp_lg_i32 s4, 0                                          ; bf018004
	s_cselect_b64 s[0:1], -1, 0                                 ; 858080c1
	s_cbranch_scc0 BB221                                        ; bf8401ae
BB174:
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
	s_cbranch_scc0 BB219                                        ; bf840193
BB175:
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
	s_cbranch_scc0 BB217                                        ; bf840178
BB176:
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
	s_cbranch_scc0 BB215                                        ; bf84015d
BB177:
	s_or_saveexec_b64 s[10:11], -1                              ; be8a21c1
	s_cmp_lt_u32 4, s4                                          ; bf0a0484
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
	s_cbranch_scc0 BB213                                        ; bf840142
BB178:
	s_or_saveexec_b64 s[12:13], -1                              ; be8c21c1
	s_cmp_lt_u32 5, s4                                          ; bf0a0485
	v_cndmask_b32_e64 v63, 0, v8, s[12:13]                      ; d100003f 00321080
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
	s_cbranch_scc0 BB211                                        ; bf840127
BB179:
	s_or_saveexec_b64 s[12:13], -1                              ; be8c21c1
	s_cmp_lt_u32 6, s4                                          ; bf0a0486
	v_cndmask_b32_e64 v63, 0, v9, s[12:13]                      ; d100003f 00321280
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
	s_cbranch_scc0 BB209                                        ; bf84010c
BB180:
	s_or_saveexec_b64 s[14:15], -1                              ; be8e21c1
	s_cmp_lt_u32 7, s4                                          ; bf0a0487
	v_cndmask_b32_e64 v63, 0, v10, s[14:15]                     ; d100003f 003a1480
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
	s_cbranch_scc0 BB207                                        ; bf8400f1
BB181:
	s_or_saveexec_b64 s[14:15], -1                              ; be8e21c1
	s_cmp_lt_u32 8, s4                                          ; bf0a0488
	v_cndmask_b32_e64 v63, 0, v11, s[14:15]                     ; d100003f 003a1680
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
	s_cbranch_scc0 BB205                                        ; bf8400d6
BB182:
	s_or_saveexec_b64 s[18:19], -1                              ; be9221c1
	s_cmp_lt_u32 9, s4                                          ; bf0a0489
	v_cndmask_b32_e64 v63, 0, v12, s[18:19]                     ; d100003f 004a1880
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
	s_mov_b64 exec, s[18:19]                                    ; befe0112
	v_readlane_b32 s14, v63, 63                                 ; d289000e 00017f3f
	s_cbranch_scc0 BB203                                        ; bf8400bb
BB183:
	s_or_saveexec_b64 s[18:19], -1                              ; be9221c1
	s_cmp_lt_u32 10, s4                                         ; bf0a048a
	v_cndmask_b32_e64 v63, 0, v13, s[18:19]                     ; d100003f 004a1a80
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
	s_mov_b64 exec, s[18:19]                                    ; befe0112
	v_readlane_b32 s15, v63, 63                                 ; d289000f 00017f3f
	s_cbranch_scc0 BB201                                        ; bf8400a0
BB184:
	s_or_saveexec_b64 s[20:21], -1                              ; be9421c1
	s_cmp_lt_u32 11, s4                                         ; bf0a048b
	v_cndmask_b32_e64 v63, 0, v14, s[20:21]                     ; d100003f 00521c80
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
	s_mov_b64 exec, s[20:21]                                    ; befe0114
	v_readlane_b32 s18, v63, 63                                 ; d2890012 00017f3f
	s_cbranch_scc0 BB199                                        ; bf840085
BB185:
	s_or_saveexec_b64 s[20:21], -1                              ; be9421c1
	s_cmp_lt_u32 12, s4                                         ; bf0a048c
	v_cndmask_b32_e64 v63, 0, v15, s[20:21]                     ; d100003f 00521e80
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
	s_mov_b64 exec, s[20:21]                                    ; befe0114
	v_readlane_b32 s19, v63, 63                                 ; d2890013 00017f3f
	s_cbranch_scc0 BB197                                        ; bf84006a
BB186:
	s_or_saveexec_b64 s[22:23], -1                              ; be9621c1
	s_cmp_lt_u32 13, s4                                         ; bf0a048d
	v_cndmask_b32_e64 v63, 0, v16, s[22:23]                     ; d100003f 005a2080
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
	s_mov_b64 exec, s[22:23]                                    ; befe0116
	v_readlane_b32 s20, v63, 63                                 ; d2890014 00017f3f
	s_cbranch_scc0 BB195                                        ; bf84004f
BB187:
	s_or_saveexec_b64 s[22:23], -1                              ; be9621c1
	s_cmp_lt_u32 14, s4                                         ; bf0a048e
	v_cndmask_b32_e64 v63, 0, v17, s[22:23]                     ; d100003f 005a2280
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
	s_mov_b64 exec, s[22:23]                                    ; befe0116
	v_readlane_b32 s21, v63, 63                                 ; d2890015 00017f3f
	s_cbranch_scc0 BB193                                        ; bf840034
BB188:
	s_or_saveexec_b64 s[24:25], -1                              ; be9821c1
	s_cmp_lt_u32 15, s4                                         ; bf0a048f
	v_cndmask_b32_e64 v63, 0, v18, s[24:25]                     ; d100003f 00622480
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
	s_mov_b64 exec, s[24:25]                                    ; befe0118
	v_readlane_b32 s22, v63, 63                                 ; d2890016 00017f3f
	s_cbranch_scc0 BB191                                        ; bf840019
BB189:
	s_or_saveexec_b64 s[24:25], -1                              ; be9821c1
	v_cndmask_b32_e64 v63, 0, v19, s[24:25]                     ; d100003f 00622680
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
	s_mov_b64 exec, s[24:25]                                    ; befe0118
	v_readlane_b32 s23, v63, 63                                 ; d2890017 00017f3f
	v_mov_b32_e32 v19, s23                                      ; 7e260217
BB191:
	v_mov_b32_e32 v18, s22                                      ; 7e240216
BB193:
	v_mov_b32_e32 v17, s21                                      ; 7e220215
BB195:
	v_mov_b32_e32 v16, s20                                      ; 7e200214
BB197:
	v_mov_b32_e32 v15, s19                                      ; 7e1e0213
BB199:
	v_mov_b32_e32 v14, s18                                      ; 7e1c0212
BB201:
	v_mov_b32_e32 v13, s15                                      ; 7e1a020f
BB203:
	v_mov_b32_e32 v12, s14                                      ; 7e18020e
BB205:
	v_mov_b32_e32 v11, s13                                      ; 7e16020d
BB207:
	v_mov_b32_e32 v10, s12                                      ; 7e14020c
BB209:
	v_mov_b32_e32 v9, s11                                       ; 7e12020b
BB211:
	v_mov_b32_e32 v8, s10                                       ; 7e10020a
BB213:
	v_mov_b32_e32 v7, s9                                        ; 7e0e0209
BB215:
	v_mov_b32_e32 v6, s6                                        ; 7e0c0206
BB217:
	v_mov_b32_e32 v5, s5                                        ; 7e0a0205
BB219:
	v_mov_b32_e32 v3, s3                                        ; 7e060203
BB221:
	s_mov_b64 s[10:11], 1                                       ; be8a0181
	s_and_b64 exec, s[0:1], s[10:11]                            ; 86fe0a00
	s_cbranch_execz BB371                                       ; bf8801f7
BB222:
	s_bitcmp1_b32 s8, 0                                         ; bf0d8008
	s_cbranch_scc0 BB224                                        ; bf84000e
BB223:
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
	s_branch BB225                                              ; bf820001
BB224:
	s_mov_b32 s1, src_scc                                       ; be8100fd
BB225:
	s_bitcmp1_b32 s8, 1                                         ; bf0d8108
	s_cbranch_scc0 BB227                                        ; bf84000e
BB226:
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
	s_branch BB228                                              ; bf820001
BB227:
	s_mov_b32 s3, src_scc                                       ; be8300fd
BB228:
	s_mov_b32 s0, s3                                            ; be800003
	s_movk_i32 s3, 0x8000                                       ; b0038000
	s_load_dwordx4 s[8:11], s[2:3], 0x20                        ; c00a0201 00000020
	s_mul_i32 s7, s7, s17                                       ; 92071107
	s_add_u32 s7, s7, s16                                       ; 80071007
	s_lshl_b32 s7, s7, 2                                        ; 8e078207
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_store_dword v3, off, s[8:11], s7                     ; e0700000 07020380
	s_cmp_lt_u32 1, s4                                          ; bf0a0481
	s_cbranch_scc0 BB371                                        ; bf8401c9
BB229:
	s_cmp_lg_i32 s1, 0                                          ; bf018001
	s_cbranch_scc0 BB231                                        ; bf84000a
BB230:
	s_load_dwordx4 s[12:15], s[2:3], 0x30                       ; c00a0301 00000030
	s_mov_b32 s1, src_scc                                       ; be8100fd
	s_add_u32 s5, s7, 4                                         ; 80058407
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s5, s[12:15], s5                        ; c0200146 00000005
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v5, s5, v5                                    ; 020a0a05
	s_branch BB232                                              ; bf820001
BB231:
	s_mov_b32 s1, src_scc                                       ; be8100fd
BB232:
	s_cmp_lg_i32 s0, 0                                          ; bf018000
	s_cbranch_scc0 BB234                                        ; bf84000a
BB233:
	s_load_dwordx4 s[12:15], s[2:3], 0x40                       ; c00a0301 00000040
	s_mov_b32 s0, src_scc                                       ; be8000fd
	s_add_u32 s5, s7, 4                                         ; 80058407
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s5, s[12:15], s5                        ; c0200146 00000005
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v5, s5, v5                                    ; 020a0a05
	s_branch BB235                                              ; bf820001
BB234:
	s_mov_b32 s0, src_scc                                       ; be8000fd
BB235:
	s_add_u32 s5, s7, 4                                         ; 80058407
	buffer_store_dword v5, off, s[8:11], s5                     ; e0700000 05020580
	s_cmp_lt_u32 2, s4                                          ; bf0a0482
	s_cbranch_scc0 BB371                                        ; bf8401aa
BB236:
	s_cmp_lg_i32 s1, 0                                          ; bf018001
	s_cbranch_scc0 BB238                                        ; bf84000a
BB237:
	s_load_dwordx4 s[12:15], s[2:3], 0x30                       ; c00a0301 00000030
	s_mov_b32 s1, src_scc                                       ; be8100fd
	s_add_u32 s5, s7, 8                                         ; 80058807
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s5, s[12:15], s5                        ; c0200146 00000005
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v6, s5, v6                                    ; 020c0c05
	s_branch BB239                                              ; bf820001
BB238:
	s_mov_b32 s1, src_scc                                       ; be8100fd
BB239:
	s_cmp_lg_i32 s0, 0                                          ; bf018000
	s_cbranch_scc0 BB241                                        ; bf84000a
BB240:
	s_load_dwordx4 s[12:15], s[2:3], 0x40                       ; c00a0301 00000040
	s_mov_b32 s0, src_scc                                       ; be8000fd
	s_add_u32 s5, s7, 8                                         ; 80058807
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s5, s[12:15], s5                        ; c0200146 00000005
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v6, s5, v6                                    ; 020c0c05
	s_branch BB242                                              ; bf820001
BB241:
	s_mov_b32 s0, src_scc                                       ; be8000fd
BB242:
	s_add_u32 s5, s7, 8                                         ; 80058807
	buffer_store_dword v6, off, s[8:11], s5                     ; e0700000 05020680
	s_cmp_lt_u32 3, s4                                          ; bf0a0483
	s_cbranch_scc0 BB371                                        ; bf84018b
BB243:
	s_cmp_lg_i32 s1, 0                                          ; bf018001
	s_cbranch_scc0 BB245                                        ; bf84000a
BB244:
	s_load_dwordx4 s[12:15], s[2:3], 0x30                       ; c00a0301 00000030
	s_mov_b32 s1, src_scc                                       ; be8100fd
	s_add_u32 s5, s7, 12                                        ; 80058c07
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s5, s[12:15], s5                        ; c0200146 00000005
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v7, s5, v7                                    ; 020e0e05
	s_branch BB246                                              ; bf820001
BB245:
	s_mov_b32 s1, src_scc                                       ; be8100fd
BB246:
	s_cmp_lg_i32 s0, 0                                          ; bf018000
	s_cbranch_scc0 BB248                                        ; bf84000a
BB247:
	s_load_dwordx4 s[12:15], s[2:3], 0x40                       ; c00a0301 00000040
	s_mov_b32 s0, src_scc                                       ; be8000fd
	s_add_u32 s5, s7, 12                                        ; 80058c07
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s5, s[12:15], s5                        ; c0200146 00000005
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v7, s5, v7                                    ; 020e0e05
	s_branch BB249                                              ; bf820001
BB248:
	s_mov_b32 s0, src_scc                                       ; be8000fd
BB249:
	s_add_u32 s5, s7, 12                                        ; 80058c07
	buffer_store_dword v7, off, s[8:11], s5                     ; e0700000 05020780
	s_cmp_lt_u32 4, s4                                          ; bf0a0484
	s_cbranch_scc0 BB371                                        ; bf84016c
BB250:
	s_cmp_lg_i32 s1, 0                                          ; bf018001
	s_cbranch_scc0 BB252                                        ; bf84000a
BB251:
	s_load_dwordx4 s[12:15], s[2:3], 0x30                       ; c00a0301 00000030
	s_mov_b32 s1, src_scc                                       ; be8100fd
	s_add_u32 s5, s7, 16                                        ; 80059007
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s5, s[12:15], s5                        ; c0200146 00000005
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v8, s5, v8                                    ; 02101005
	s_branch BB253                                              ; bf820001
BB252:
	s_mov_b32 s1, src_scc                                       ; be8100fd
BB253:
	s_cmp_lg_i32 s0, 0                                          ; bf018000
	s_cbranch_scc0 BB255                                        ; bf84000a
BB254:
	s_load_dwordx4 s[12:15], s[2:3], 0x40                       ; c00a0301 00000040
	s_mov_b32 s0, src_scc                                       ; be8000fd
	s_add_u32 s5, s7, 16                                        ; 80059007
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s5, s[12:15], s5                        ; c0200146 00000005
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v8, s5, v8                                    ; 02101005
	s_branch BB256                                              ; bf820001
BB255:
	s_mov_b32 s0, src_scc                                       ; be8000fd
BB256:
	s_add_u32 s5, s7, 16                                        ; 80059007
	buffer_store_dword v8, off, s[8:11], s5                     ; e0700000 05020880
	s_cmp_lt_u32 5, s4                                          ; bf0a0485
	s_cbranch_scc0 BB371                                        ; bf84014d
BB257:
	s_cmp_lg_i32 s1, 0                                          ; bf018001
	s_cbranch_scc0 BB259                                        ; bf84000a
BB258:
	s_load_dwordx4 s[12:15], s[2:3], 0x30                       ; c00a0301 00000030
	s_mov_b32 s1, src_scc                                       ; be8100fd
	s_add_u32 s5, s7, 20                                        ; 80059407
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s5, s[12:15], s5                        ; c0200146 00000005
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v9, s5, v9                                    ; 02121205
	s_branch BB260                                              ; bf820001
BB259:
	s_mov_b32 s1, src_scc                                       ; be8100fd
BB260:
	s_cmp_lg_i32 s0, 0                                          ; bf018000
	s_cbranch_scc0 BB262                                        ; bf84000a
BB261:
	s_load_dwordx4 s[12:15], s[2:3], 0x40                       ; c00a0301 00000040
	s_mov_b32 s0, src_scc                                       ; be8000fd
	s_add_u32 s5, s7, 20                                        ; 80059407
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s5, s[12:15], s5                        ; c0200146 00000005
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v9, s5, v9                                    ; 02121205
	s_branch BB263                                              ; bf820001
BB262:
	s_mov_b32 s0, src_scc                                       ; be8000fd
BB263:
	s_add_u32 s5, s7, 20                                        ; 80059407
	buffer_store_dword v9, off, s[8:11], s5                     ; e0700000 05020980
	s_cmp_lt_u32 6, s4                                          ; bf0a0486
	s_cbranch_scc0 BB371                                        ; bf84012e
BB264:
	s_cmp_lg_i32 s1, 0                                          ; bf018001
	s_cbranch_scc0 BB266                                        ; bf84000a
BB265:
	s_load_dwordx4 s[12:15], s[2:3], 0x30                       ; c00a0301 00000030
	s_mov_b32 s1, src_scc                                       ; be8100fd
	s_add_u32 s5, s7, 24                                        ; 80059807
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s5, s[12:15], s5                        ; c0200146 00000005
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v10, s5, v10                                  ; 02141405
	s_branch BB267                                              ; bf820001
BB266:
	s_mov_b32 s1, src_scc                                       ; be8100fd
BB267:
	s_cmp_lg_i32 s0, 0                                          ; bf018000
	s_cbranch_scc0 BB269                                        ; bf84000a
BB268:
	s_load_dwordx4 s[12:15], s[2:3], 0x40                       ; c00a0301 00000040
	s_mov_b32 s0, src_scc                                       ; be8000fd
	s_add_u32 s5, s7, 24                                        ; 80059807
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s5, s[12:15], s5                        ; c0200146 00000005
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v10, s5, v10                                  ; 02141405
	s_branch BB270                                              ; bf820001
BB269:
	s_mov_b32 s0, src_scc                                       ; be8000fd
BB270:
	s_add_u32 s5, s7, 24                                        ; 80059807
	buffer_store_dword v10, off, s[8:11], s5                    ; e0700000 05020a80
	s_cmp_lt_u32 7, s4                                          ; bf0a0487
	s_cbranch_scc0 BB371                                        ; bf84010f
BB271:
	s_cmp_lg_i32 s1, 0                                          ; bf018001
	s_cbranch_scc0 BB273                                        ; bf84000a
BB272:
	s_load_dwordx4 s[12:15], s[2:3], 0x30                       ; c00a0301 00000030
	s_mov_b32 s1, src_scc                                       ; be8100fd
	s_add_u32 s5, s7, 28                                        ; 80059c07
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s5, s[12:15], s5                        ; c0200146 00000005
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v11, s5, v11                                  ; 02161605
	s_branch BB274                                              ; bf820001
BB273:
	s_mov_b32 s1, src_scc                                       ; be8100fd
BB274:
	s_cmp_lg_i32 s0, 0                                          ; bf018000
	s_cbranch_scc0 BB276                                        ; bf84000a
BB275:
	s_load_dwordx4 s[12:15], s[2:3], 0x40                       ; c00a0301 00000040
	s_mov_b32 s0, src_scc                                       ; be8000fd
	s_add_u32 s5, s7, 28                                        ; 80059c07
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s5, s[12:15], s5                        ; c0200146 00000005
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v11, s5, v11                                  ; 02161605
	s_branch BB277                                              ; bf820001
BB276:
	s_mov_b32 s0, src_scc                                       ; be8000fd
BB277:
	s_add_u32 s5, s7, 28                                        ; 80059c07
	buffer_store_dword v11, off, s[8:11], s5                    ; e0700000 05020b80
	s_cmp_lt_u32 8, s4                                          ; bf0a0488
	s_cbranch_scc0 BB371                                        ; bf8400f0
BB278:
	s_cmp_lg_i32 s1, 0                                          ; bf018001
	s_cbranch_scc0 BB280                                        ; bf84000a
BB279:
	s_load_dwordx4 s[12:15], s[2:3], 0x30                       ; c00a0301 00000030
	s_mov_b32 s1, src_scc                                       ; be8100fd
	s_add_u32 s5, s7, 32                                        ; 8005a007
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s5, s[12:15], s5                        ; c0200146 00000005
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v12, s5, v12                                  ; 02181805
	s_branch BB281                                              ; bf820001
BB280:
	s_mov_b32 s1, src_scc                                       ; be8100fd
BB281:
	s_cmp_lg_i32 s0, 0                                          ; bf018000
	s_cbranch_scc0 BB283                                        ; bf84000a
BB282:
	s_load_dwordx4 s[12:15], s[2:3], 0x40                       ; c00a0301 00000040
	s_mov_b32 s0, src_scc                                       ; be8000fd
	s_add_u32 s5, s7, 32                                        ; 8005a007
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s5, s[12:15], s5                        ; c0200146 00000005
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v12, s5, v12                                  ; 02181805
	s_branch BB284                                              ; bf820001
BB283:
	s_mov_b32 s0, src_scc                                       ; be8000fd
BB284:
	s_add_u32 s5, s7, 32                                        ; 8005a007
	buffer_store_dword v12, off, s[8:11], s5                    ; e0700000 05020c80
	s_cmp_lt_u32 9, s4                                          ; bf0a0489
	s_cbranch_scc0 BB371                                        ; bf8400d1
BB285:
	s_cmp_lg_i32 s1, 0                                          ; bf018001
	s_cbranch_scc0 BB287                                        ; bf84000a
BB286:
	s_load_dwordx4 s[12:15], s[2:3], 0x30                       ; c00a0301 00000030
	s_mov_b32 s1, src_scc                                       ; be8100fd
	s_add_u32 s5, s7, 36                                        ; 8005a407
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s5, s[12:15], s5                        ; c0200146 00000005
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v13, s5, v13                                  ; 021a1a05
	s_branch BB288                                              ; bf820001
BB287:
	s_mov_b32 s1, src_scc                                       ; be8100fd
BB288:
	s_cmp_lg_i32 s0, 0                                          ; bf018000
	s_cbranch_scc0 BB290                                        ; bf84000a
BB289:
	s_load_dwordx4 s[12:15], s[2:3], 0x40                       ; c00a0301 00000040
	s_mov_b32 s0, src_scc                                       ; be8000fd
	s_add_u32 s5, s7, 36                                        ; 8005a407
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s5, s[12:15], s5                        ; c0200146 00000005
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v13, s5, v13                                  ; 021a1a05
	s_branch BB291                                              ; bf820001
BB290:
	s_mov_b32 s0, src_scc                                       ; be8000fd
BB291:
	s_add_u32 s5, s7, 36                                        ; 8005a407
	buffer_store_dword v13, off, s[8:11], s5                    ; e0700000 05020d80
	s_cmp_lt_u32 10, s4                                         ; bf0a048a
	s_cbranch_scc0 BB371                                        ; bf8400b2
BB292:
	s_cmp_lg_i32 s1, 0                                          ; bf018001
	s_cbranch_scc0 BB294                                        ; bf84000a
BB293:
	s_load_dwordx4 s[12:15], s[2:3], 0x30                       ; c00a0301 00000030
	s_mov_b32 s1, src_scc                                       ; be8100fd
	s_add_u32 s5, s7, 40                                        ; 8005a807
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s5, s[12:15], s5                        ; c0200146 00000005
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v14, s5, v14                                  ; 021c1c05
	s_branch BB295                                              ; bf820001
BB294:
	s_mov_b32 s1, src_scc                                       ; be8100fd
BB295:
	s_cmp_lg_i32 s0, 0                                          ; bf018000
	s_cbranch_scc0 BB297                                        ; bf84000a
BB296:
	s_load_dwordx4 s[12:15], s[2:3], 0x40                       ; c00a0301 00000040
	s_mov_b32 s0, src_scc                                       ; be8000fd
	s_add_u32 s5, s7, 40                                        ; 8005a807
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s5, s[12:15], s5                        ; c0200146 00000005
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v14, s5, v14                                  ; 021c1c05
	s_branch BB298                                              ; bf820001
BB297:
	s_mov_b32 s0, src_scc                                       ; be8000fd
BB298:
	s_add_u32 s5, s7, 40                                        ; 8005a807
	buffer_store_dword v14, off, s[8:11], s5                    ; e0700000 05020e80
	s_cmp_lt_u32 11, s4                                         ; bf0a048b
	s_cbranch_scc0 BB371                                        ; bf840093
BB299:
	s_cmp_lg_i32 s1, 0                                          ; bf018001
	s_cbranch_scc0 BB301                                        ; bf84000a
BB300:
	s_load_dwordx4 s[12:15], s[2:3], 0x30                       ; c00a0301 00000030
	s_mov_b32 s1, src_scc                                       ; be8100fd
	s_add_u32 s5, s7, 44                                        ; 8005ac07
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s5, s[12:15], s5                        ; c0200146 00000005
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v15, s5, v15                                  ; 021e1e05
	s_branch BB302                                              ; bf820001
BB301:
	s_mov_b32 s1, src_scc                                       ; be8100fd
BB302:
	s_cmp_lg_i32 s0, 0                                          ; bf018000
	s_cbranch_scc0 BB304                                        ; bf84000a
BB303:
	s_load_dwordx4 s[12:15], s[2:3], 0x40                       ; c00a0301 00000040
	s_mov_b32 s0, src_scc                                       ; be8000fd
	s_add_u32 s5, s7, 44                                        ; 8005ac07
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s5, s[12:15], s5                        ; c0200146 00000005
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v15, s5, v15                                  ; 021e1e05
	s_branch BB305                                              ; bf820001
BB304:
	s_mov_b32 s0, src_scc                                       ; be8000fd
BB305:
	s_add_u32 s5, s7, 44                                        ; 8005ac07
	buffer_store_dword v15, off, s[8:11], s5                    ; e0700000 05020f80
	s_cmp_lt_u32 12, s4                                         ; bf0a048c
	s_cbranch_scc0 BB371                                        ; bf840074
BB306:
	s_cmp_lg_i32 s1, 0                                          ; bf018001
	s_cbranch_scc0 BB308                                        ; bf84000a
BB307:
	s_load_dwordx4 s[12:15], s[2:3], 0x30                       ; c00a0301 00000030
	s_mov_b32 s1, src_scc                                       ; be8100fd
	s_add_u32 s5, s7, 48                                        ; 8005b007
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s5, s[12:15], s5                        ; c0200146 00000005
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v16, s5, v16                                  ; 02202005
	s_branch BB309                                              ; bf820001
BB308:
	s_mov_b32 s1, src_scc                                       ; be8100fd
BB309:
	s_cmp_lg_i32 s0, 0                                          ; bf018000
	s_cbranch_scc0 BB311                                        ; bf84000a
BB310:
	s_load_dwordx4 s[12:15], s[2:3], 0x40                       ; c00a0301 00000040
	s_mov_b32 s0, src_scc                                       ; be8000fd
	s_add_u32 s5, s7, 48                                        ; 8005b007
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s5, s[12:15], s5                        ; c0200146 00000005
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v16, s5, v16                                  ; 02202005
	s_branch BB312                                              ; bf820001
BB311:
	s_mov_b32 s0, src_scc                                       ; be8000fd
BB312:
	s_add_u32 s5, s7, 48                                        ; 8005b007
	buffer_store_dword v16, off, s[8:11], s5                    ; e0700000 05021080
	s_cmp_lt_u32 13, s4                                         ; bf0a048d
	s_cbranch_scc0 BB371                                        ; bf840055
BB313:
	s_cmp_lg_i32 s1, 0                                          ; bf018001
	s_cbranch_scc0 BB315                                        ; bf84000a
BB314:
	s_load_dwordx4 s[12:15], s[2:3], 0x30                       ; c00a0301 00000030
	s_mov_b32 s1, src_scc                                       ; be8100fd
	s_add_u32 s5, s7, 52                                        ; 8005b407
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s5, s[12:15], s5                        ; c0200146 00000005
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v17, s5, v17                                  ; 02222205
	s_branch BB316                                              ; bf820001
BB315:
	s_mov_b32 s1, src_scc                                       ; be8100fd
BB316:
	s_cmp_lg_i32 s0, 0                                          ; bf018000
	s_cbranch_scc0 BB318                                        ; bf84000a
BB317:
	s_load_dwordx4 s[12:15], s[2:3], 0x40                       ; c00a0301 00000040
	s_mov_b32 s0, src_scc                                       ; be8000fd
	s_add_u32 s5, s7, 52                                        ; 8005b407
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s5, s[12:15], s5                        ; c0200146 00000005
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v17, s5, v17                                  ; 02222205
	s_branch BB319                                              ; bf820001
BB318:
	s_mov_b32 s0, src_scc                                       ; be8000fd
BB319:
	s_add_u32 s5, s7, 52                                        ; 8005b407
	buffer_store_dword v17, off, s[8:11], s5                    ; e0700000 05021180
	s_cmp_lt_u32 14, s4                                         ; bf0a048e
	s_cbranch_scc0 BB371                                        ; bf840036
BB320:
	s_cmp_lg_i32 s1, 0                                          ; bf018001
	s_cbranch_scc0 BB322                                        ; bf84000a
BB321:
	s_load_dwordx4 s[12:15], s[2:3], 0x30                       ; c00a0301 00000030
	s_mov_b32 s1, src_scc                                       ; be8100fd
	s_add_u32 s5, s7, 56                                        ; 8005b807
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s5, s[12:15], s5                        ; c0200146 00000005
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v18, s5, v18                                  ; 02242405
	s_branch BB323                                              ; bf820001
BB322:
	s_mov_b32 s1, src_scc                                       ; be8100fd
BB323:
	s_cmp_lg_i32 s0, 0                                          ; bf018000
	s_cbranch_scc0 BB325                                        ; bf84000a
BB324:
	s_load_dwordx4 s[12:15], s[2:3], 0x40                       ; c00a0301 00000040
	s_mov_b32 s0, src_scc                                       ; be8000fd
	s_add_u32 s5, s7, 56                                        ; 8005b807
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s5, s[12:15], s5                        ; c0200146 00000005
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v18, s5, v18                                  ; 02242405
	s_branch BB326                                              ; bf820001
BB325:
	s_mov_b32 s0, src_scc                                       ; be8000fd
BB326:
	s_add_u32 s5, s7, 56                                        ; 8005b807
	buffer_store_dword v18, off, s[8:11], s5                    ; e0700000 05021280
	s_cmp_lt_u32 15, s4                                         ; bf0a048f
	s_cbranch_scc0 BB371                                        ; bf840017
BB327:
	s_cmp_lg_i32 s1, 0                                          ; bf018001
	s_cbranch_scc0 BB330                                        ; bf840008
BB328:
	s_load_dwordx4 s[12:15], s[2:3], 0x30                       ; c00a0301 00000030
	s_add_u32 s1, s7, 60                                        ; 8001bc07
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s1, s[12:15], s1                        ; c0200046 00000001
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v19, s1, v19                                  ; 02262601
BB330:
	s_cmp_lg_i32 s0, 0                                          ; bf018000
	s_cbranch_scc0 BB333                                        ; bf840008
BB331:
	s_load_dwordx4 s[0:3], s[2:3], 0x40                         ; c00a0001 00000040
	s_add_u32 s4, s7, 60                                        ; 8004bc07
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s4, s[0:3], s4                          ; c0200100 00000004
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v19, s4, v19                                  ; 02262604
BB333:
	s_add_u32 s7, s7, 60                                        ; 8007bc07
	buffer_store_dword v19, off, s[8:11], s7                    ; e0700000 07021380
BB371:
	s_endpgm                                                    ; bf810000
