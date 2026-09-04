BB0:
	s_load_dword s0, s[14:15], 0x0                              ; c0020007 00000000
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_mul_i32 s0, s0, s18                                       ; 92001200
	s_add_u32 s16, s16, s0                                      ; 80100010
	s_lshl_b32 s16, s16, 3                                      ; 8e108310
	s_add_u32 s1, s16, 8                                        ; 80018810
	s_cmp_ge_u32 s4, s1                                         ; bf090104
	s_cbranch_scc0 BB72                                         ; bf840594
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
	s_cbranch_execz BB14                                        ; bf88036c
BB5:
	s_mov_b32 s0, s2                                            ; be800002
	s_movk_i32 s1, 0x8000                                       ; b0018000
	s_load_dwordx8 s[24:31], s[0:1], 0x0                        ; c00e0600 00000000
	s_mul_i32 s6, s6, s17                                       ; 92061106
	s_mul_i32 s0, s16, s3                                       ; 92000310
	s_add_u32 s0, s18, s0                                       ; 80000012
	s_add_u32 s1, s16, 1                                        ; 80018110
	s_mul_i32 s1, s1, s3                                        ; 92010301
	s_add_u32 s1, s18, s1                                       ; 80010112
	s_add_u32 s4, s16, 2                                        ; 80048210
	s_mul_i32 s4, s4, s3                                        ; 92040304
	s_add_u32 s4, s18, s4                                       ; 80040412
	s_add_u32 s5, s16, 3                                        ; 80058310
	v_lshlrev_b32_e32 v2, 1, v2                                 ; 24040481
	v_add_u32_e32 v5, 64, v4                                    ; 680a08c0
	s_mul_i32 s5, s5, s3                                        ; 92050305
	v_add_u32_e32 v3, 8, v2                                     ; 68060488
	v_mov_b32_e32 v6, 0                                         ; 7e0c0280
	v_mov_b32_e32 v7, 0                                         ; 7e0e0280
	s_add_u32 s5, s18, s5                                       ; 80050512
	s_add_u32 s9, s16, 4                                        ; 80098410
	v_mov_b32_e32 v8, 0                                         ; 7e100280
	v_mov_b32_e32 v9, 0                                         ; 7e120280
	v_mov_b32_e32 v10, 0                                        ; 7e140280
	v_mov_b32_e32 v11, 0                                        ; 7e160280
	s_mul_i32 s9, s9, s3                                        ; 92090309
	v_mov_b32_e32 v12, 0                                        ; 7e180280
	v_mov_b32_e32 v13, 0                                        ; 7e1a0280
	s_add_u32 s9, s18, s9                                       ; 80090912
	s_add_u32 s10, s16, 5                                       ; 800a8510
	s_mul_i32 s10, s10, s3                                      ; 920a030a
	s_add_u32 s10, s18, s10                                     ; 800a0a12
	s_add_u32 s11, s16, 6                                       ; 800b8610
	s_mul_i32 s11, s11, s3                                      ; 920b030b
	s_add_u32 s11, s18, s11                                     ; 800b0b12
	s_add_u32 s12, s16, 7                                       ; 800c8710
	s_mul_i32 s12, s12, s3                                      ; 920c030c
	s_add_u32 s18, s18, s12                                     ; 80120c12
	s_mov_b64 s[12:13], exec                                    ; be8c017e
BB6:
	v_lshl_add_u32 v14, v0, 8, v1                               ; d1fd000e 04051100
	v_add_u32_e32 v15, s6, v14                                  ; 681e1c06
	v_add_u32_e32 v14, 0x80, v14                                ; 681c1cff 00000080
	v_lshrrev_b32_e32 v15, 2, v15                               ; 201e1e82
	v_add_u32_e32 v14, s6, v14                                  ; 681c1c06
	v_lshlrev_b32_e32 v15, 4, v15                               ; 241e1e84
	v_lshrrev_b32_e32 v14, 2, v14                               ; 201c1c82
	v_lshlrev_b32_e32 v14, 4, v14                               ; 241c1c84
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_load_dwordx4 v[16:19], v15, s[28:31], 0 offen        ; e05c1000 8007100f
	buffer_load_dwordx4 v[20:23], v15, s[28:31], 0 offen offset:128 ; e05c1080 8007140f
	buffer_load_dwordx4 v[24:27], v14, s[28:31], 0 offen        ; e05c1000 8007180e
	buffer_load_dwordx4 v[28:31], v14, s[28:31], 0 offen offset:128 ; e05c1080 80071c0e
	v_add_u32_e32 v32, s0, v0                                   ; 68400000
	v_and_b32_e32 v35, -4, v2                                   ; 264604c4
	v_add_u32_e32 v40, s1, v0                                   ; 68500001
	v_lshlrev_b32_e32 v33, 4, v32                               ; 24424084
	v_lshlrev_b32_e32 v41, 4, v40                               ; 24525084
	v_lshl_add_u32 v32, v32, 7, v33                             ; d1fd0020 04850f20
	v_lshl_add_u32 v40, v40, 7, v41                             ; d1fd0028 04a50f28
	v_add_u32_e32 v47, s4, v0                                   ; 685e0004
	v_add_u32_e32 v38, 16, v32                                  ; 684c4090
	v_add_u32_e32 v34, 4, v32                                   ; 68444084
	v_add_u32_e32 v45, 16, v40                                  ; 685a5090
	v_add_u32_e32 v42, 4, v40                                   ; 68545084
	v_lshlrev_b32_e32 v48, 4, v47                               ; 24605e84
	v_add_u32_e32 v39, v38, v4                                  ; 684e0926
	v_add_u32_e32 v38, v38, v5                                  ; 684c0b26
	v_add_u32_e32 v36, v35, v34                                 ; 68484523
	v_add_u32_e32 v37, v34, v2                                  ; 684a0522
	v_add_u32_e32 v34, v34, v3                                  ; 68440722
	v_add_u32_e32 v46, v45, v4                                  ; 685c092d
	v_add_u32_e32 v45, v45, v5                                  ; 685a0b2d
	v_add_u32_e32 v43, v35, v42                                 ; 68565523
	v_add_u32_e32 v44, v42, v2                                  ; 6858052a
	v_add_u32_e32 v42, v42, v3                                  ; 6854072a
	v_lshl_add_u32 v47, v47, 7, v48                             ; d1fd002f 04c10f2f
	v_add_u32_e32 v54, s5, v0                                   ; 686c0005
	v_add_u32_e32 v49, 4, v47                                   ; 68625e84
	v_add_u32_e32 v52, 16, v47                                  ; 68685e90
	v_lshlrev_b32_e32 v55, 4, v54                               ; 246e6c84
	v_add_u32_e32 v51, v49, v2                                  ; 68660531
	v_add_u32_e32 v50, v35, v49                                 ; 68646323
	v_add_u32_e32 v49, v49, v3                                  ; 68620731
	v_add_u32_e32 v53, v52, v4                                  ; 686a0934
	v_add_u32_e32 v52, v52, v5                                  ; 68680b34
	v_lshl_add_u32 v54, v54, 7, v55                             ; d1fd0036 04dd0f36
	buffer_load_dword v32, v32, s[24:27], 0 offen               ; e0501000 80062020
	buffer_load_dwordx2 v[14:15], v36, s[24:27], 0 offen        ; e0541000 80060e24
	buffer_load_ushort v34, v34, s[24:27], 0 offen              ; e0481000 80062222
	buffer_load_dword v39, v39, s[24:27], 0 offen               ; e0501000 80062727
	buffer_load_dword v38, v38, s[24:27], 0 offen               ; e0501000 80062626
	buffer_load_dword v40, v40, s[24:27], 0 offen               ; e0501000 80062828
	buffer_load_dwordx2 v[56:57], v43, s[24:27], 0 offen        ; e0541000 8006382b
	buffer_load_ushort v42, v42, s[24:27], 0 offen              ; e0481000 80062a2a
	buffer_load_dword v46, v46, s[24:27], 0 offen               ; e0501000 80062e2e
	buffer_load_dword v45, v45, s[24:27], 0 offen               ; e0501000 80062d2d
	buffer_load_dword v47, v47, s[24:27], 0 offen               ; e0501000 80062f2f
	buffer_load_dwordx2 v[58:59], v50, s[24:27], 0 offen        ; e0541000 80063a32
	buffer_load_ushort v49, v49, s[24:27], 0 offen              ; e0481000 80063131
	buffer_load_dword v53, v53, s[24:27], 0 offen               ; e0501000 80063535
	buffer_load_dword v52, v52, s[24:27], 0 offen               ; e0501000 80063434
	buffer_load_dword v60, v54, s[24:27], 0 offen               ; e0501000 80063c36
	s_mov_b32 s14, 0xf0f0f0f                                    ; be8e00ff 0f0f0f0f
	s_mov_b32 s15, 0xc0c0c0c0                                   ; be8f00ff c0c0c0c0
	s_mov_b32 s19, 0x3f3f3f3f                                   ; be9300ff 3f3f3f3f
	v_add_u32_e32 v61, 4, v54                                   ; 687a6c84
	s_waitcnt vmcnt(19)                                         ; bf8c7f73
	v_add_f32_e32 v62, v16, v17                                 ; 027c2310
	s_waitcnt vmcnt(18)                                         ; bf8c7f72
	v_add_f32_e32 v33, v20, v21                                 ; 02422b14
	s_waitcnt vmcnt(17)                                         ; bf8c7f71
	v_add_f32_e32 v36, v24, v25                                 ; 02483318
	v_add_f32_e32 v62, v62, v18                                 ; 027c253e
	s_waitcnt vmcnt(16)                                         ; bf8c7f70
	v_add_f32_e32 v41, v28, v29                                 ; 02523b1c
	v_add_f32_e32 v33, v33, v22                                 ; 02422d21
	v_add_f32_e32 v36, v36, v26                                 ; 02483524
	v_add_f32_e32 v62, v62, v19                                 ; 027c273e
	v_add_f32_e32 v41, v41, v30                                 ; 02523d29
	v_add_f32_e32 v33, v33, v23                                 ; 02422f21
	v_add_f32_e32 v36, v36, v27                                 ; 02483724
	v_add_f32_e32 v41, v41, v31                                 ; 02523f29
	s_waitcnt vmcnt(14)                                         ; bf8c3f7e
	v_alignbyte_b32 v14, v15, v14, v37                          ; d1cf000e 04961d0f
	v_alignbyte_b32 v15, v15, v15, v37                          ; d1cf000f 04961f0f
	s_waitcnt vmcnt(13)                                         ; bf8c3f7d
	v_lshl_or_b32 v34, v34, 12, v34                             ; d2000022 04891922
	s_waitcnt vmcnt(12)                                         ; bf8c3f7c
	v_and_b32_e32 v48, s14, v39                                 ; 26604e0e
	v_lshrrev_b32_e32 v39, 4, v39                               ; 204e4e84
	v_mov_b32_sdwa v14, v15 dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_0 ; 7e1c02f9 0004150f
	v_cvt_f32_ubyte2_e32 v55, v48                               ; 7e6e2730
	v_cvt_f32_ubyte1_e32 v15, v48                               ; 7e1e2530
	v_cvt_f32_ubyte3_e32 v50, v48                               ; 7e642930
	v_cvt_f32_ubyte0_e32 v48, v48                               ; 7e602330
	v_and_b32_e32 v39, s14, v39                                 ; 264e4e0e
	v_and_b32_e32 v43, s15, v14                                 ; 26561c0f
	v_and_b32_e32 v14, s19, v14                                 ; 261c1c13
	v_mul_f32_e32 v50, v19, v50                                 ; 0a646513
	v_cvt_f32_ubyte3_e32 v37, v39                               ; 7e4a2927
	v_lshrrev_b32_e32 v43, 2, v43                               ; 20565682
	v_mac_f32_e32 v50, v18, v55                                 ; 2c646f12
	s_waitcnt vmcnt(11)                                         ; bf8c3f7b
	v_and_b32_e32 v55, s14, v38                                 ; 266e4c0e
	v_mul_f32_e32 v37, v23, v37                                 ; 0a4a4b17
	v_and_or_b32 v34, s14, v34, v43                             ; d2010022 04ae440e
	v_cvt_f32_ubyte2_e32 v43, v39                               ; 7e562727
	v_mac_f32_e32 v50, v17, v15                                 ; 2c641f11
	v_cvt_f32_ubyte3_e32 v15, v55                               ; 7e1e2937
	v_lshrrev_b32_e32 v38, 4, v38                               ; 204c4c84
	v_mac_f32_e32 v37, v22, v43                                 ; 2c4a5716
	v_cvt_f32_ubyte1_e32 v43, v55                               ; 7e562537
	v_mac_f32_e32 v50, v16, v48                                 ; 2c646110
	v_cvt_f32_ubyte1_e32 v48, v39                               ; 7e602527
	v_cvt_f32_ubyte0_e32 v39, v39                               ; 7e4e2327
	v_mul_f32_e32 v15, v27, v15                                 ; 0a1e1f1b
	v_and_b32_e32 v38, s14, v38                                 ; 264c4c0e
	v_mac_f32_e32 v37, v21, v48                                 ; 2c4a6115
	v_cvt_f32_ubyte3_e32 v48, v38                               ; 7e602926
	v_mac_f32_e32 v37, v20, v39                                 ; 2c4a4f14
	v_cvt_f32_ubyte2_e32 v39, v55                               ; 7e4e2737
	v_cvt_f32_ubyte0_e32 v55, v55                               ; 7e6e2337
	v_mul_f32_e32 v48, v31, v48                                 ; 0a60611f
	v_mac_f32_e32 v15, v26, v39                                 ; 2c1e4f1a
	v_cvt_f32_ubyte1_e32 v39, v38                               ; 7e4e2526
	v_mac_f32_e32 v15, v25, v43                                 ; 2c1e5719
	v_cvt_f32_ubyte3_e32 v43, v34                               ; 7e562922
	v_mac_f32_e32 v15, v24, v55                                 ; 2c1e6f18
	v_cvt_f32_ubyte2_e32 v55, v38                               ; 7e6e2726
	v_cvt_f32_ubyte0_e32 v38, v38                               ; 7e4c2326
	v_mul_f32_e32 v43, v41, v43                                 ; 0a565729
	v_mac_f32_e32 v48, v30, v55                                 ; 2c606f1e
	v_cvt_f32_ubyte2_e32 v55, v34                               ; 7e6e2722
	v_mac_f32_e32 v48, v29, v39                                 ; 2c604f1d
	v_cvt_f32_ubyte2_e32 v39, v14                               ; 7e4e270e
	v_add_u32_e32 v54, 16, v54                                  ; 686c6c90
	v_mac_f32_e32 v43, v36, v55                                 ; 2c566f24
	v_cvt_f32_ubyte1_e32 v55, v34                               ; 7e6e2522
	v_cvt_f32_ubyte0_e32 v34, v34                               ; 7e442322
	v_mac_f32_e32 v48, v28, v38                                 ; 2c604d1c
	v_cvt_f32_ubyte3_e32 v38, v14                               ; 7e4c290e
	v_mul_f32_e32 v48, v48, v55                                 ; 0a606f30
	v_mac_f32_e32 v43, v33, v38                                 ; 2c564d21
	v_add_u32_e32 v38, v54, v4                                  ; 684c0936
	v_add_u32_e32 v54, v54, v5                                  ; 686c0b36
	v_mac_f32_e32 v48, v15, v34                                 ; 2c60450f
	v_add_u32_e32 v15, v35, v61                                 ; 681e7b23
	v_cvt_f32_ubyte1_e32 v34, v14                               ; 7e44250e
	v_cvt_f32_ubyte0_e32 v14, v14                               ; 7e1c230e
	v_mac_f32_e32 v43, v62, v39                                 ; 2c564f3e
	v_cvt_f32_f16_sdwa v39, v32 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e4e16f9 00050620
	v_mac_f32_e32 v48, v37, v34                                 ; 2c604525
	v_add_u32_e32 v37, v61, v2                                  ; 684a053d
	v_add_u32_e32 v61, v61, v3                                  ; 687a073d
	v_mad_f32 v6, -v39, v43, v6                                 ; d1c10006 241a5727
	v_add_u32_e32 v43, s9, v0                                   ; 68560009
	v_mac_f32_e32 v48, v50, v14                                 ; 2c601d32
	v_lshlrev_b32_e32 v50, 4, v43                               ; 24645684
	v_lshl_add_u32 v43, v43, 7, v50                             ; d1fd002b 04c90f2b
	buffer_load_dwordx2 v[14:15], v15, s[24:27], 0 offen        ; e0541000 80060e0f
	buffer_load_ushort v61, v61, s[24:27], 0 offen              ; e0481000 80063d3d
	buffer_load_dword v38, v38, s[24:27], 0 offen               ; e0501000 80062626
	buffer_load_dword v54, v54, s[24:27], 0 offen               ; e0501000 80063636
	buffer_load_dword v55, v43, s[24:27], 0 offen               ; e0501000 8006372b
	v_cvt_f32_f16_e32 v32, v32                                  ; 7e401720
	s_waitcnt vmcnt(14)                                         ; bf8c3f7e
	v_alignbyte_b32 v56, v57, v56, v44                          ; d1cf0038 04b27139
	v_alignbyte_b32 v57, v57, v57, v44                          ; d1cf0039 04b27339
	s_waitcnt vmcnt(13)                                         ; bf8c3f7d
	v_lshl_or_b32 v42, v42, 12, v42                             ; d200002a 04a9192a
	s_waitcnt vmcnt(12)                                         ; bf8c3f7c
	v_and_b32_e32 v39, s14, v46                                 ; 264e5c0e
	v_mac_f32_e32 v6, v32, v48                                  ; 2c0c6120
	v_add_u32_e32 v32, 4, v43                                   ; 68405684
	v_mov_b32_sdwa v56, v57 dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_0 ; 7e7002f9 00041539
	v_lshrrev_b32_e32 v46, 4, v46                               ; 205c5c84
	v_cvt_f32_ubyte2_e32 v48, v39                               ; 7e602727
	v_cvt_f32_ubyte3_e32 v44, v39                               ; 7e582927
	v_cvt_f32_ubyte1_e32 v50, v39                               ; 7e642527
	v_cvt_f32_ubyte0_e32 v39, v39                               ; 7e4e2327
	v_and_b32_e32 v34, s15, v56                                 ; 2644700f
	v_and_b32_e32 v56, s19, v56                                 ; 26707013
	v_and_b32_e32 v46, s14, v46                                 ; 265c5c0e
	v_mul_f32_e32 v44, v19, v44                                 ; 0a585913
	v_lshrrev_b32_e32 v34, 2, v34                               ; 20444482
	v_cvt_f32_ubyte3_e32 v57, v46                               ; 7e72292e
	v_mac_f32_e32 v44, v18, v48                                 ; 2c586112
	v_and_or_b32 v42, s14, v42, v34                             ; d201002a 048a540e
	v_cvt_f32_ubyte2_e32 v34, v46                               ; 7e44272e
	v_mul_f32_e32 v57, v23, v57                                 ; 0a727317
	v_mac_f32_e32 v44, v17, v50                                 ; 2c586511
	v_mac_f32_e32 v57, v22, v34                                 ; 2c724516
	v_mac_f32_e32 v44, v16, v39                                 ; 2c584f10
	v_cvt_f32_ubyte1_e32 v39, v46                               ; 7e4e252e
	v_cvt_f32_ubyte0_e32 v46, v46                               ; 7e5c232e
	v_mac_f32_e32 v57, v21, v39                                 ; 2c724f15
	v_mac_f32_e32 v57, v20, v46                                 ; 2c725d14
	s_waitcnt vmcnt(11)                                         ; bf8c3f7b
	v_and_b32_e32 v46, s14, v45                                 ; 265c5a0e
	v_lshrrev_b32_e32 v45, 4, v45                               ; 205a5a84
	v_cvt_f32_ubyte3_e32 v48, v46                               ; 7e60292e
	v_cvt_f32_ubyte1_e32 v34, v46                               ; 7e44252e
	v_cvt_f32_ubyte2_e32 v50, v46                               ; 7e64272e
	v_cvt_f32_ubyte0_e32 v46, v46                               ; 7e5c232e
	v_and_b32_e32 v45, s14, v45                                 ; 265a5a0e
	v_mul_f32_e32 v48, v27, v48                                 ; 0a60611b
	v_cvt_f32_ubyte3_e32 v39, v45                               ; 7e4e292d
	v_mac_f32_e32 v48, v26, v50                                 ; 2c60651a
	v_cvt_f32_ubyte1_e32 v50, v45                               ; 7e64252d
	v_mul_f32_e32 v39, v31, v39                                 ; 0a4e4f1f
	v_mac_f32_e32 v48, v25, v34                                 ; 2c604519
	v_cvt_f32_ubyte3_e32 v34, v42                               ; 7e44292a
	v_mac_f32_e32 v48, v24, v46                                 ; 2c605d18
	v_cvt_f32_ubyte2_e32 v46, v45                               ; 7e5c272d
	v_cvt_f32_ubyte0_e32 v45, v45                               ; 7e5a232d
	v_mul_f32_e32 v34, v41, v34                                 ; 0a444529
	v_mac_f32_e32 v39, v30, v46                                 ; 2c4e5d1e
	v_cvt_f32_ubyte3_e32 v46, v56                               ; 7e5c2938
	v_mac_f32_e32 v39, v29, v50                                 ; 2c4e651d
	v_cvt_f32_ubyte2_e32 v50, v56                               ; 7e642738
	v_add_u32_e32 v43, 16, v43                                  ; 68565690
	v_mac_f32_e32 v39, v28, v45                                 ; 2c4e5b1c
	v_cvt_f32_ubyte2_e32 v45, v42                               ; 7e5a272a
	v_mac_f32_e32 v34, v36, v45                                 ; 2c445b24
	v_cvt_f32_ubyte1_e32 v45, v42                               ; 7e5a252a
	v_cvt_f32_ubyte0_e32 v42, v42                               ; 7e54232a
	v_mac_f32_e32 v34, v33, v46                                 ; 2c445d21
	v_add_u32_e32 v46, v35, v32                                 ; 685c4123
	v_mul_f32_e32 v39, v39, v45                                 ; 0a4e5b27
	v_mac_f32_e32 v34, v62, v50                                 ; 2c44653e
	v_add_u32_e32 v50, v32, v2                                  ; 68640520
	v_add_u32_e32 v32, v32, v3                                  ; 68400720
	v_mac_f32_e32 v39, v48, v42                                 ; 2c4e5530
	v_cvt_f32_ubyte1_e32 v48, v56                               ; 7e602538
	v_cvt_f32_ubyte0_e32 v56, v56                               ; 7e702338
	v_mac_f32_e32 v39, v57, v48                                 ; 2c4e6139
	v_add_u32_e32 v57, v43, v4                                  ; 6872092b
	v_add_u32_e32 v43, v43, v5                                  ; 68560b2b
	v_mac_f32_e32 v39, v44, v56                                 ; 2c4e712c
	v_add_u32_e32 v44, s10, v0                                  ; 6858000a
	v_lshlrev_b32_e32 v45, 4, v44                               ; 245a5884
	v_lshl_add_u32 v44, v44, 7, v45                             ; d1fd002c 04b50f2c
	buffer_load_dwordx2 v[45:46], v46, s[24:27], 0 offen        ; e0541000 80062d2e
	buffer_load_ushort v32, v32, s[24:27], 0 offen              ; e0481000 80062020
	buffer_load_dword v57, v57, s[24:27], 0 offen               ; e0501000 80063939
	buffer_load_dword v43, v43, s[24:27], 0 offen               ; e0501000 80062b2b
	buffer_load_dword v48, v44, s[24:27], 0 offen               ; e0501000 8006302c
	v_cvt_f32_f16_sdwa v42, v40 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e5416f9 00050628
	v_cvt_f32_f16_e32 v40, v40                                  ; 7e501728
	s_waitcnt vmcnt(15)                                         ; bf8c3f7f
	v_cvt_f32_f16_sdwa v56, v47 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e7016f9 0005062f
	v_cvt_f32_f16_e32 v47, v47                                  ; 7e5e172f
	s_waitcnt vmcnt(14)                                         ; bf8c3f7e
	v_alignbyte_b32 v58, v59, v58, v51                          ; d1cf003a 04ce753b
	v_alignbyte_b32 v59, v59, v59, v51                          ; d1cf003b 04ce773b
	s_waitcnt vmcnt(13)                                         ; bf8c3f7d
	v_lshl_or_b32 v49, v49, 12, v49                             ; d2000031 04c51931
	v_mad_f32 v7, -v42, v34, v7                                 ; d1c10007 241e452a
	s_waitcnt vmcnt(12)                                         ; bf8c3f7c
	v_and_b32_e32 v34, s14, v53                                 ; 26446a0e
	v_mov_b32_sdwa v58, v59 dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_0 ; 7e7402f9 0004153b
	v_lshrrev_b32_e32 v53, 4, v53                               ; 206a6a84
	v_mac_f32_e32 v7, v40, v39                                  ; 2c0e4f28
	v_cvt_f32_ubyte2_e32 v40, v34                               ; 7e502722
	v_cvt_f32_ubyte1_e32 v42, v34                               ; 7e542522
	v_cvt_f32_ubyte3_e32 v39, v34                               ; 7e4e2922
	v_cvt_f32_ubyte0_e32 v34, v34                               ; 7e442322
	v_and_b32_e32 v59, s15, v58                                 ; 2676740f
	v_and_b32_e32 v53, s14, v53                                 ; 266a6a0e
	v_mul_f32_e32 v39, v19, v39                                 ; 0a4e4f13
	v_lshrrev_b32_e32 v59, 2, v59                               ; 20767682
	v_cvt_f32_ubyte3_e32 v51, v53                               ; 7e662935
	v_mac_f32_e32 v39, v18, v40                                 ; 2c4e5112
	s_waitcnt vmcnt(11)                                         ; bf8c3f7b
	v_and_b32_e32 v40, s14, v52                                 ; 2650680e
	v_and_or_b32 v49, s14, v49, v59                             ; d2010031 04ee620e
	v_cvt_f32_ubyte2_e32 v59, v53                               ; 7e762735
	v_mul_f32_e32 v51, v23, v51                                 ; 0a666717
	v_mac_f32_e32 v39, v17, v42                                 ; 2c4e5511
	v_cvt_f32_ubyte3_e32 v42, v40                               ; 7e542928
	v_lshrrev_b32_e32 v52, 4, v52                               ; 20686884
	v_mac_f32_e32 v51, v22, v59                                 ; 2c667716
	v_cvt_f32_ubyte1_e32 v59, v40                               ; 7e762528
	v_mac_f32_e32 v39, v16, v34                                 ; 2c4e4510
	v_cvt_f32_ubyte1_e32 v34, v53                               ; 7e442535
	v_cvt_f32_ubyte0_e32 v53, v53                               ; 7e6a2335
	v_mul_f32_e32 v42, v27, v42                                 ; 0a54551b
	v_and_b32_e32 v52, s14, v52                                 ; 2668680e
	v_mac_f32_e32 v51, v21, v34                                 ; 2c664515
	v_cvt_f32_ubyte3_e32 v34, v52                               ; 7e442934
	v_mac_f32_e32 v51, v20, v53                                 ; 2c666b14
	v_cvt_f32_ubyte2_e32 v53, v40                               ; 7e6a2728
	v_cvt_f32_ubyte0_e32 v40, v40                               ; 7e502328
	v_mul_f32_e32 v34, v31, v34                                 ; 0a44451f
	v_and_b32_e32 v58, s19, v58                                 ; 26747413
	v_mac_f32_e32 v42, v26, v53                                 ; 2c546b1a
	v_cvt_f32_ubyte1_e32 v53, v52                               ; 7e6a2534
	v_mac_f32_e32 v42, v25, v59                                 ; 2c547719
	v_cvt_f32_ubyte3_e32 v59, v49                               ; 7e762931
	v_mac_f32_e32 v42, v24, v40                                 ; 2c545118
	v_cvt_f32_ubyte2_e32 v40, v52                               ; 7e502734
	v_cvt_f32_ubyte0_e32 v52, v52                               ; 7e682334
	v_mul_f32_e32 v59, v41, v59                                 ; 0a767729
	v_mac_f32_e32 v34, v30, v40                                 ; 2c44511e
	v_cvt_f32_ubyte2_e32 v40, v49                               ; 7e502731
	v_mac_f32_e32 v34, v29, v53                                 ; 2c446b1d
	v_cvt_f32_ubyte2_e32 v53, v58                               ; 7e6a273a
	v_mac_f32_e32 v59, v36, v40                                 ; 2c765124
	v_cvt_f32_ubyte1_e32 v40, v49                               ; 7e502531
	v_cvt_f32_ubyte0_e32 v49, v49                               ; 7e622331
	v_mac_f32_e32 v34, v28, v52                                 ; 2c44691c
	v_cvt_f32_ubyte3_e32 v52, v58                               ; 7e68293a
	v_mul_f32_e32 v34, v34, v40                                 ; 0a445122
	v_mac_f32_e32 v59, v33, v52                                 ; 2c766921
	v_mac_f32_e32 v34, v42, v49                                 ; 2c44632a
	v_cvt_f32_ubyte1_e32 v42, v58                               ; 7e54253a
	v_add_u32_e32 v49, 4, v44                                   ; 68625884
	v_cvt_f32_ubyte0_e32 v58, v58                               ; 7e74233a
	v_add_u32_e32 v44, 16, v44                                  ; 68585890
	v_mac_f32_e32 v59, v62, v53                                 ; 2c766b3e
	v_mac_f32_e32 v34, v51, v42                                 ; 2c445533
	v_add_u32_e32 v52, v49, v2                                  ; 68680531
	v_add_u32_e32 v51, v35, v49                                 ; 68666323
	v_add_u32_e32 v49, v49, v3                                  ; 68620731
	v_add_u32_e32 v53, v44, v4                                  ; 686a092c
	v_add_u32_e32 v44, v44, v5                                  ; 68580b2c
	v_mad_f32 v8, -v56, v59, v8                                 ; d1c10008 24227738
	v_add_u32_e32 v56, s11, v0                                  ; 6870000b
	v_mac_f32_e32 v34, v39, v58                                 ; 2c447527
	v_lshlrev_b32_e32 v58, 4, v56                               ; 24747084
	v_lshl_add_u32 v56, v56, 7, v58                             ; d1fd0038 04e90f38
	buffer_load_dwordx2 v[58:59], v51, s[24:27], 0 offen        ; e0541000 80063a33
	buffer_load_ushort v49, v49, s[24:27], 0 offen              ; e0481000 80063131
	buffer_load_dword v53, v53, s[24:27], 0 offen               ; e0501000 80063535
	buffer_load_dword v44, v44, s[24:27], 0 offen               ; e0501000 80062c2c
	buffer_load_dword v39, v56, s[24:27], 0 offen               ; e0501000 80062738
	s_waitcnt vmcnt(15)                                         ; bf8c3f7f
	v_cvt_f32_f16_sdwa v40, v60 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e5016f9 0005063c
	v_cvt_f32_f16_e32 v60, v60                                  ; 7e78173c
	s_waitcnt vmcnt(14)                                         ; bf8c3f7e
	v_alignbyte_b32 v14, v15, v14, v37                          ; d1cf000e 04961d0f
	v_alignbyte_b32 v15, v15, v15, v37                          ; d1cf000f 04961f0f
	s_waitcnt vmcnt(13)                                         ; bf8c3f7d
	v_lshl_or_b32 v61, v61, 12, v61                             ; d200003d 04f5193d
	v_mac_f32_e32 v8, v47, v34                                  ; 2c10452f
	s_waitcnt vmcnt(12)                                         ; bf8c3f7c
	v_and_b32_e32 v47, s14, v38                                 ; 265e4c0e
	v_lshrrev_b32_e32 v38, 4, v38                               ; 204c4c84
	v_mov_b32_sdwa v14, v15 dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_0 ; 7e1c02f9 0004150f
	v_cvt_f32_ubyte3_e32 v51, v47                               ; 7e66292f
	v_cvt_f32_ubyte1_e32 v34, v47                               ; 7e44252f
	v_cvt_f32_ubyte2_e32 v15, v47                               ; 7e1e272f
	v_cvt_f32_ubyte0_e32 v47, v47                               ; 7e5e232f
	v_and_b32_e32 v38, s14, v38                                 ; 264c4c0e
	v_and_b32_e32 v42, s15, v14                                 ; 26541c0f
	v_mul_f32_e32 v51, v19, v51                                 ; 0a666713
	v_cvt_f32_ubyte3_e32 v37, v38                               ; 7e4a2926
	v_lshrrev_b32_e32 v42, 2, v42                               ; 20545482
	v_mac_f32_e32 v51, v18, v15                                 ; 2c661f12
	s_waitcnt vmcnt(11)                                         ; bf8c3f7b
	v_and_b32_e32 v15, s14, v54                                 ; 261e6c0e
	v_mul_f32_e32 v37, v23, v37                                 ; 0a4a4b17
	v_and_or_b32 v61, s14, v61, v42                             ; d201003d 04aa7a0e
	v_cvt_f32_ubyte2_e32 v42, v38                               ; 7e542726
	v_mac_f32_e32 v51, v17, v34                                 ; 2c664511
	v_cvt_f32_ubyte3_e32 v34, v15                               ; 7e44290f
	v_lshrrev_b32_e32 v54, 4, v54                               ; 206c6c84
	v_mac_f32_e32 v37, v22, v42                                 ; 2c4a5516
	v_cvt_f32_ubyte1_e32 v42, v15                               ; 7e54250f
	v_mac_f32_e32 v51, v16, v47                                 ; 2c665f10
	v_cvt_f32_ubyte1_e32 v47, v38                               ; 7e5e2526
	v_cvt_f32_ubyte0_e32 v38, v38                               ; 7e4c2326
	v_mul_f32_e32 v34, v27, v34                                 ; 0a44451b
	v_and_b32_e32 v54, s14, v54                                 ; 266c6c0e
	v_mac_f32_e32 v37, v21, v47                                 ; 2c4a5f15
	v_cvt_f32_ubyte3_e32 v47, v54                               ; 7e5e2936
	v_mac_f32_e32 v37, v20, v38                                 ; 2c4a4d14
	v_cvt_f32_ubyte2_e32 v38, v15                               ; 7e4c270f
	v_cvt_f32_ubyte0_e32 v15, v15                               ; 7e1e230f
	v_mul_f32_e32 v47, v31, v47                                 ; 0a5e5f1f
	v_and_b32_e32 v14, s19, v14                                 ; 261c1c13
	v_mac_f32_e32 v34, v26, v38                                 ; 2c444d1a
	v_cvt_f32_ubyte1_e32 v38, v54                               ; 7e4c2536
	v_mac_f32_e32 v34, v25, v42                                 ; 2c445519
	v_cvt_f32_ubyte3_e32 v42, v61                               ; 7e54293d
	v_mac_f32_e32 v34, v24, v15                                 ; 2c441f18
	v_cvt_f32_ubyte2_e32 v15, v54                               ; 7e1e2736
	v_cvt_f32_ubyte0_e32 v54, v54                               ; 7e6c2336
	v_mul_f32_e32 v42, v41, v42                                 ; 0a545529
	v_mac_f32_e32 v47, v30, v15                                 ; 2c5e1f1e
	v_cvt_f32_ubyte3_e32 v15, v14                               ; 7e1e290e
	v_mac_f32_e32 v47, v29, v38                                 ; 2c5e4d1d
	v_cvt_f32_ubyte2_e32 v38, v14                               ; 7e4c270e
	v_mac_f32_e32 v47, v28, v54                                 ; 2c5e6d1c
	v_cvt_f32_ubyte2_e32 v54, v61                               ; 7e6c273d
	v_mac_f32_e32 v42, v36, v54                                 ; 2c546d24
	v_cvt_f32_ubyte1_e32 v54, v61                               ; 7e6c253d
	v_cvt_f32_ubyte0_e32 v61, v61                               ; 7e7a233d
	v_mac_f32_e32 v42, v33, v15                                 ; 2c541f21
	v_add_u32_e32 v15, 4, v56                                   ; 681e7084
	v_add_u32_e32 v56, 16, v56                                  ; 68707090
	v_mul_f32_e32 v47, v47, v54                                 ; 0a5e6d2f
	v_mac_f32_e32 v42, v62, v38                                 ; 2c544d3e
	v_add_u32_e32 v38, v56, v4                                  ; 684c0938
	v_add_u32_e32 v56, v56, v5                                  ; 68700b38
	v_mac_f32_e32 v47, v34, v61                                 ; 2c5e7b22
	v_cvt_f32_ubyte1_e32 v61, v14                               ; 7e7a250e
	v_cvt_f32_ubyte0_e32 v14, v14                               ; 7e1c230e
	v_add_u32_e32 v34, v35, v15                                 ; 68441f23
	v_mad_f32 v9, -v40, v42, v9                                 ; d1c10009 24265528
	v_add_u32_e32 v40, s18, v0                                  ; 68500012
	v_mac_f32_e32 v47, v37, v61                                 ; 2c5e7b25
	v_add_u32_e32 v37, v15, v2                                  ; 684a050f
	v_add_u32_e32 v15, v15, v3                                  ; 681e070f
	v_lshlrev_b32_e32 v42, 4, v40                               ; 24545084
	v_mac_f32_e32 v47, v51, v14                                 ; 2c5e1d33
	v_mov_b32_e32 v51, v13                                      ; 7e66030d
	v_lshl_add_u32 v40, v40, 7, v42                             ; d1fd0028 04a90f28
	buffer_load_dwordx2 v[13:14], v34, s[24:27], 0 offen        ; e0541000 80060d22
	buffer_load_ushort v15, v15, s[24:27], 0 offen              ; e0481000 80060f0f
	buffer_load_dword v38, v38, s[24:27], 0 offen               ; e0501000 80062626
	buffer_load_dword v56, v56, s[24:27], 0 offen               ; e0501000 80063838
	buffer_load_dword v54, v40, s[24:27], 0 offen               ; e0501000 80063628
	s_waitcnt vmcnt(14)                                         ; bf8c3f7e
	v_alignbyte_b32 v45, v46, v45, v50                          ; d1cf002d 04ca5b2e
	v_alignbyte_b32 v46, v46, v46, v50                          ; d1cf002e 04ca5d2e
	s_waitcnt vmcnt(13)                                         ; bf8c3f7d
	v_lshl_or_b32 v32, v32, 12, v32                             ; d2000020 04811920
	v_mac_f32_e32 v9, v60, v47                                  ; 2c125f3c
	v_cvt_f32_f16_sdwa v60, v55 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e7816f9 00050637
	v_cvt_f32_f16_e32 v55, v55                                  ; 7e6e1737
	s_waitcnt vmcnt(12)                                         ; bf8c3f7c
	v_and_b32_e32 v34, s14, v57                                 ; 2644720e
	v_mov_b32_sdwa v45, v46 dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_0 ; 7e5a02f9 0004152e
	v_lshrrev_b32_e32 v57, 4, v57                               ; 20727284
	v_cvt_f32_ubyte2_e32 v46, v34                               ; 7e5c2722
	v_cvt_f32_ubyte1_e32 v47, v34                               ; 7e5e2522
	v_cvt_f32_ubyte3_e32 v42, v34                               ; 7e542922
	v_cvt_f32_ubyte0_e32 v34, v34                               ; 7e442322
	v_and_b32_e32 v61, s15, v45                                 ; 267a5a0f
	v_and_b32_e32 v57, s14, v57                                 ; 2672720e
	v_mul_f32_e32 v42, v19, v42                                 ; 0a545513
	v_lshrrev_b32_e32 v61, 2, v61                               ; 207a7a82
	v_cvt_f32_ubyte3_e32 v50, v57                               ; 7e642939
	v_mac_f32_e32 v42, v18, v46                                 ; 2c545d12
	s_waitcnt vmcnt(11)                                         ; bf8c3f7b
	v_and_b32_e32 v46, s14, v43                                 ; 265c560e
	v_and_or_b32 v32, s14, v32, v61                             ; d2010020 04f6400e
	v_cvt_f32_ubyte2_e32 v61, v57                               ; 7e7a2739
	v_mul_f32_e32 v50, v23, v50                                 ; 0a646517
	v_mac_f32_e32 v42, v17, v47                                 ; 2c545f11
	v_cvt_f32_ubyte3_e32 v47, v46                               ; 7e5e292e
	v_lshrrev_b32_e32 v43, 4, v43                               ; 20565684
	v_mac_f32_e32 v50, v22, v61                                 ; 2c647b16
	v_cvt_f32_ubyte1_e32 v61, v46                               ; 7e7a252e
	v_mac_f32_e32 v42, v16, v34                                 ; 2c544510
	v_cvt_f32_ubyte1_e32 v34, v57                               ; 7e442539
	v_cvt_f32_ubyte0_e32 v57, v57                               ; 7e722339
	v_mul_f32_e32 v47, v27, v47                                 ; 0a5e5f1b
	v_and_b32_e32 v43, s14, v43                                 ; 2656560e
	v_mac_f32_e32 v50, v21, v34                                 ; 2c644515
	v_cvt_f32_ubyte3_e32 v34, v43                               ; 7e44292b
	v_mac_f32_e32 v50, v20, v57                                 ; 2c647314
	v_cvt_f32_ubyte2_e32 v57, v46                               ; 7e72272e
	v_cvt_f32_ubyte0_e32 v46, v46                               ; 7e5c232e
	v_mul_f32_e32 v34, v31, v34                                 ; 0a44451f
	v_and_b32_e32 v45, s19, v45                                 ; 265a5a13
	v_mac_f32_e32 v47, v26, v57                                 ; 2c5e731a
	v_cvt_f32_ubyte1_e32 v57, v43                               ; 7e72252b
	v_mac_f32_e32 v47, v25, v61                                 ; 2c5e7b19
	v_cvt_f32_ubyte3_e32 v61, v32                               ; 7e7a2920
	v_mac_f32_e32 v47, v24, v46                                 ; 2c5e5d18
	v_cvt_f32_ubyte2_e32 v46, v43                               ; 7e5c272b
	v_cvt_f32_ubyte0_e32 v43, v43                               ; 7e56232b
	v_mul_f32_e32 v61, v41, v61                                 ; 0a7a7b29
	v_mac_f32_e32 v34, v30, v46                                 ; 2c445d1e
	v_cvt_f32_ubyte3_e32 v46, v45                               ; 7e5c292d
	v_mac_f32_e32 v34, v29, v57                                 ; 2c44731d
	v_cvt_f32_ubyte2_e32 v57, v45                               ; 7e72272d
	v_mac_f32_e32 v34, v28, v43                                 ; 2c44571c
	v_cvt_f32_ubyte2_e32 v43, v32                               ; 7e562720
	v_mac_f32_e32 v61, v36, v43                                 ; 2c7a5724
	v_cvt_f32_ubyte1_e32 v43, v32                               ; 7e562520
	v_cvt_f32_ubyte0_e32 v32, v32                               ; 7e402320
	v_mac_f32_e32 v61, v33, v46                                 ; 2c7a5d21
	v_add_u32_e32 v46, 4, v40                                   ; 685c5084
	v_add_u32_e32 v40, 16, v40                                  ; 68505090
	v_mul_f32_e32 v34, v34, v43                                 ; 0a445722
	v_mov_b32_e32 v43, v31                                      ; 7e56031f
	v_mac_f32_e32 v61, v62, v57                                 ; 2c7a733e
	v_add_u32_e32 v35, v35, v46                                 ; 68465d23
	v_add_u32_e32 v57, v40, v4                                  ; 68720928
	v_add_u32_e32 v40, v40, v5                                  ; 68500b28
	v_mac_f32_e32 v34, v47, v32                                 ; 2c44412f
	v_cvt_f32_ubyte1_e32 v47, v45                               ; 7e5e252d
	v_mac_f32_e32 v34, v50, v47                                 ; 2c445f32
	v_add_u32_e32 v50, v46, v2                                  ; 6864052e
	v_add_u32_e32 v46, v46, v3                                  ; 685c072e
	buffer_load_dwordx2 v[31:32], v35, s[24:27], 0 offen        ; e0541000 80061f23
	buffer_load_ushort v46, v46, s[24:27], 0 offen              ; e0481000 80062e2e
	buffer_load_dword v57, v57, s[24:27], 0 offen               ; e0501000 80063939
	buffer_load_dword v40, v40, s[24:27], 0 offen               ; e0501000 80062828
	v_cvt_f32_ubyte0_e32 v45, v45                               ; 7e5a232d
	v_mad_f32 v10, -v60, v61, v10                               ; d1c1000a 242a7b3c
	v_add_u32_e32 v0, 4, v0                                     ; 68000084
	s_waitcnt vmcnt(13)                                         ; bf8c3f7d
	v_alignbyte_b32 v58, v59, v58, v52                          ; d1cf003a 04d2753b
	v_alignbyte_b32 v59, v59, v59, v52                          ; d1cf003b 04d2773b
	s_waitcnt vmcnt(12)                                         ; bf8c3f7c
	v_lshl_or_b32 v49, v49, 12, v49                             ; d2000031 04c51931
	v_mac_f32_e32 v34, v42, v45                                 ; 2c445b2a
	v_cvt_f32_f16_sdwa v45, v48 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e5a16f9 00050630
	v_cvt_f32_f16_e32 v48, v48                                  ; 7e601730
	v_cmp_le_u32_e32 vcc, s3, v0                                ; 7d960003
	s_waitcnt vmcnt(11)                                         ; bf8c3f7b
	v_and_b32_e32 v60, s14, v53                                 ; 26786a0e
	v_mov_b32_sdwa v58, v59 dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_0 ; 7e7402f9 0004153b
	v_mac_f32_e32 v10, v55, v34                                 ; 2c144537
	v_cvt_f32_ubyte3_e32 v61, v60                               ; 7e7a293c
	v_cvt_f32_ubyte1_e32 v35, v60                               ; 7e46253c
	v_cvt_f32_ubyte2_e32 v34, v60                               ; 7e44273c
	v_cvt_f32_ubyte0_e32 v60, v60                               ; 7e78233c
	v_and_b32_e32 v47, s15, v58                                 ; 265e740f
	v_and_b32_e32 v58, s19, v58                                 ; 26747413
	v_lshrrev_b32_e32 v53, 4, v53                               ; 206a6a84
	v_mul_f32_e32 v61, v19, v61                                 ; 0a7a7b13
	v_lshrrev_b32_e32 v47, 2, v47                               ; 205e5e82
	v_cvt_f32_ubyte2_e32 v55, v58                               ; 7e6e273a
	v_cvt_f32_ubyte3_e32 v52, v58                               ; 7e68293a
	v_and_b32_e32 v53, s14, v53                                 ; 266a6a0e
	v_mac_f32_e32 v61, v18, v34                                 ; 2c7a4512
	v_and_or_b32 v49, s14, v49, v47                             ; d2010031 04be620e
	s_waitcnt vmcnt(10)                                         ; bf8c3f7a
	v_and_b32_e32 v34, s14, v44                                 ; 2644580e
	v_cvt_f32_ubyte2_e32 v47, v53                               ; 7e5e2735
	v_cvt_f32_ubyte3_e32 v42, v53                               ; 7e542935
	v_mac_f32_e32 v61, v17, v35                                 ; 2c7a4711
	v_cvt_f32_ubyte3_e32 v59, v49                               ; 7e762931
	v_cvt_f32_ubyte3_e32 v35, v34                               ; 7e462922
	v_mul_f32_e32 v42, v23, v42                                 ; 0a545517
	v_mac_f32_e32 v61, v16, v60                                 ; 2c7a7910
	v_cvt_f32_ubyte1_e32 v60, v53                               ; 7e782535
	v_cvt_f32_ubyte0_e32 v53, v53                               ; 7e6a2335
	v_mul_f32_e32 v59, v41, v59                                 ; 0a767729
	v_lshrrev_b32_e32 v44, 4, v44                               ; 20585884
	v_mul_f32_e32 v35, v27, v35                                 ; 0a46471b
	v_mac_f32_e32 v42, v22, v47                                 ; 2c545f16
	v_cvt_f32_ubyte2_e32 v47, v34                               ; 7e5e2722
	v_and_b32_e32 v44, s14, v44                                 ; 2658580e
	v_mac_f32_e32 v42, v21, v60                                 ; 2c547915
	v_mac_f32_e32 v35, v26, v47                                 ; 2c465f1a
	v_cvt_f32_ubyte3_e32 v60, v44                               ; 7e78292c
	v_cvt_f32_ubyte1_e32 v47, v44                               ; 7e5e252c
	v_mac_f32_e32 v42, v20, v53                                 ; 2c546b14
	v_cvt_f32_ubyte1_e32 v53, v34                               ; 7e6a2522
	v_cvt_f32_ubyte0_e32 v34, v34                               ; 7e442322
	v_mul_f32_e32 v60, v43, v60                                 ; 0a78792b
	v_mac_f32_e32 v35, v25, v53                                 ; 2c466b19
	v_cvt_f32_ubyte2_e32 v53, v49                               ; 7e6a2731
	v_mac_f32_e32 v35, v24, v34                                 ; 2c464518
	v_cvt_f32_ubyte2_e32 v34, v44                               ; 7e44272c
	v_cvt_f32_ubyte0_e32 v44, v44                               ; 7e58232c
	v_mac_f32_e32 v59, v36, v53                                 ; 2c766b24
	v_mac_f32_e32 v60, v30, v34                                 ; 2c78451e
	v_cvt_f32_ubyte1_e32 v34, v58                               ; 7e44253a
	v_cvt_f32_ubyte0_e32 v58, v58                               ; 7e74233a
	v_mac_f32_e32 v59, v33, v52                                 ; 2c766921
	s_waitcnt vmcnt(8)                                          ; bf8c3f78
	v_alignbyte_b32 v13, v14, v13, v37                          ; d1cf000d 04961b0e
	v_mac_f32_e32 v60, v29, v47                                 ; 2c785f1d
	v_alignbyte_b32 v14, v14, v14, v37                          ; d1cf000e 04961d0e
	v_mac_f32_e32 v59, v62, v55                                 ; 2c766f3e
	v_cvt_f32_ubyte1_e32 v55, v49                               ; 7e6e2531
	v_cvt_f32_ubyte0_e32 v49, v49                               ; 7e622331
	v_mac_f32_e32 v60, v28, v44                                 ; 2c78591c
	v_mov_b32_sdwa v13, v14 dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_0 ; 7e1a02f9 0004150e
	v_mad_f32 v11, -v45, v59, v11                               ; d1c1000b 242e772d
	v_mul_f32_e32 v60, v60, v55                                 ; 0a786f3c
	s_waitcnt vmcnt(7)                                          ; bf8c3f77
	v_lshl_or_b32 v15, v15, 12, v15                             ; d200000f 043d190f
	v_and_b32_e32 v37, s15, v13                                 ; 264a1a0f
	v_and_b32_e32 v13, s19, v13                                 ; 261a1a13
	v_mac_f32_e32 v60, v35, v49                                 ; 2c786323
	v_cvt_f32_f16_sdwa v35, v39 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e4616f9 00050627
	v_cvt_f32_f16_e32 v39, v39                                  ; 7e4e1727
	v_lshrrev_b32_e32 v37, 2, v37                               ; 204a4a82
	v_cvt_f32_ubyte1_e32 v45, v13                               ; 7e5a250d
	v_cvt_f32_ubyte2_e32 v44, v13                               ; 7e58270d
	v_mac_f32_e32 v60, v42, v34                                 ; 2c78452a
	v_cvt_f32_ubyte3_e32 v42, v13                               ; 7e54290d
	v_cvt_f32_ubyte0_e32 v13, v13                               ; 7e1a230d
	v_and_or_b32 v15, s14, v15, v37                             ; d201000f 04961e0e
	s_waitcnt vmcnt(6)                                          ; bf8c3f76
	v_and_b32_e32 v52, s14, v38                                 ; 26684c0e
	v_mac_f32_e32 v60, v61, v58                                 ; 2c78753d
	v_cvt_f32_ubyte1_e32 v49, v15                               ; 7e62250f
	v_cvt_f32_ubyte3_e32 v47, v15                               ; 7e5e290f
	v_cvt_f32_ubyte2_e32 v55, v52                               ; 7e6e2734
	v_cvt_f32_ubyte1_e32 v58, v52                               ; 7e742534
	v_cvt_f32_ubyte3_e32 v53, v52                               ; 7e6a2934
	v_cvt_f32_ubyte0_e32 v52, v52                               ; 7e682334
	v_mac_f32_e32 v11, v48, v60                                 ; 2c167930
	v_cvt_f32_ubyte2_e32 v48, v15                               ; 7e60270f
	v_cvt_f32_ubyte0_e32 v15, v15                               ; 7e1e230f
	v_lshrrev_b32_e32 v38, 4, v38                               ; 204c4c84
	v_mul_f32_e32 v47, v41, v47                                 ; 0a5e5f29
	v_mul_f32_e32 v53, v19, v53                                 ; 0a6a6b13
	v_and_b32_e32 v38, s14, v38                                 ; 264c4c0e
	v_mac_f32_e32 v47, v36, v48                                 ; 2c5e6124
	v_mac_f32_e32 v53, v18, v55                                 ; 2c6a6f12
	s_waitcnt vmcnt(5)                                          ; bf8c3f75
	v_and_b32_e32 v14, s14, v56                                 ; 261c700e
	v_cvt_f32_ubyte1_e32 v61, v38                               ; 7e7a2526
	v_cvt_f32_ubyte2_e32 v60, v38                               ; 7e782726
	v_cvt_f32_ubyte3_e32 v59, v38                               ; 7e762926
	v_cvt_f32_ubyte0_e32 v38, v38                               ; 7e4c2326
	v_mac_f32_e32 v47, v33, v42                                 ; 2c5e5521
	v_mac_f32_e32 v53, v17, v58                                 ; 2c6a7511
	v_cvt_f32_ubyte3_e32 v34, v14                               ; 7e44290e
	v_cvt_f32_ubyte1_e32 v37, v14                               ; 7e4a250e
	v_mul_f32_e32 v59, v23, v59                                 ; 0a767717
	v_mac_f32_e32 v47, v62, v44                                 ; 2c5e593e
	v_lshrrev_b32_e32 v56, 4, v56                               ; 20707084
	v_mac_f32_e32 v53, v16, v52                                 ; 2c6a6910
	v_mul_f32_e32 v34, v27, v34                                 ; 0a44451b
	v_mac_f32_e32 v59, v22, v60                                 ; 2c767916
	v_mad_f32 v12, -v35, v47, v12                               ; d1c1000c 24325f23
	v_cvt_f32_ubyte2_e32 v35, v14                               ; 7e46270e
	v_cvt_f32_ubyte0_e32 v14, v14                               ; 7e1c230e
	v_and_b32_e32 v56, s14, v56                                 ; 2670700e
	v_mac_f32_e32 v59, v21, v61                                 ; 2c767b15
	v_mac_f32_e32 v34, v26, v35                                 ; 2c44471a
	v_cvt_f32_ubyte2_e32 v42, v56                               ; 7e542738
	v_cvt_f32_ubyte1_e32 v44, v56                               ; 7e582538
	v_mac_f32_e32 v59, v20, v38                                 ; 2c764d14
	v_cvt_f32_ubyte3_e32 v38, v56                               ; 7e4c2938
	v_cvt_f32_ubyte0_e32 v56, v56                               ; 7e702338
	v_mac_f32_e32 v34, v25, v37                                 ; 2c444b19
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_alignbyte_b32 v31, v32, v31, v50                          ; d1cf001f 04ca3f20
	v_alignbyte_b32 v32, v32, v32, v50                          ; d1cf0020 04ca4120
	v_mul_f32_e32 v38, v43, v38                                 ; 0a4c4d2b
	v_mac_f32_e32 v34, v24, v14                                 ; 2c441d18
	v_mov_b32_sdwa v31, v32 dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_0 ; 7e3e02f9 00041520
	v_mac_f32_e32 v38, v30, v42                                 ; 2c4c551e
	v_and_b32_e32 v47, s15, v31                                 ; 265e3e0f
	v_and_b32_e32 v31, s19, v31                                 ; 263e3e13
	v_mac_f32_e32 v38, v29, v44                                 ; 2c4c591d
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_lshl_or_b32 v46, v46, 12, v46                             ; d200002e 04b9192e
	v_lshrrev_b32_e32 v47, 2, v47                               ; 205e5e82
	v_cvt_f32_ubyte1_e32 v50, v31                               ; 7e64251f
	v_cvt_f32_ubyte3_e32 v48, v31                               ; 7e60291f
	v_mac_f32_e32 v38, v28, v56                                 ; 2c4c711c
	v_and_or_b32 v46, s14, v46, v47                             ; d201002e 04be5c0e
	v_mul_f32_e32 v38, v38, v49                                 ; 0a4c6326
	v_cvt_f32_ubyte2_e32 v49, v31                               ; 7e62271f
	v_cvt_f32_ubyte0_e32 v31, v31                               ; 7e3e231f
	v_cvt_f32_ubyte3_e32 v52, v46                               ; 7e68292e
	v_cvt_f32_ubyte1_e32 v55, v46                               ; 7e6e252e
	v_mac_f32_e32 v38, v34, v15                                 ; 2c4c1f22
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v56, s14, v57                                 ; 2670720e
	v_mul_f32_e32 v41, v41, v52                                 ; 0a526929
	v_mac_f32_e32 v38, v59, v45                                 ; 2c4c5b3b
	v_cvt_f32_f16_sdwa v45, v54 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e5a16f9 00050636
	v_cvt_f32_f16_e32 v54, v54                                  ; 7e6c1736
	v_cvt_f32_ubyte3_e32 v58, v56                               ; 7e742938
	v_cvt_f32_ubyte1_e32 v60, v56                               ; 7e782538
	v_cvt_f32_ubyte2_e32 v59, v56                               ; 7e762738
	v_cvt_f32_ubyte0_e32 v56, v56                               ; 7e702338
	v_mac_f32_e32 v38, v53, v13                                 ; 2c4c1b35
	v_cvt_f32_ubyte2_e32 v53, v46                               ; 7e6a272e
	v_cvt_f32_ubyte0_e32 v46, v46                               ; 7e5c232e
	v_lshrrev_b32_e32 v57, 4, v57                               ; 20727284
	v_mul_f32_e32 v19, v19, v58                                 ; 0a267513
	v_mac_f32_e32 v12, v39, v38                                 ; 2c184d27
	v_mac_f32_e32 v41, v36, v53                                 ; 2c526b24
	v_and_b32_e32 v57, s14, v57                                 ; 2672720e
	v_mac_f32_e32 v19, v18, v59                                 ; 2c267712
	v_mac_f32_e32 v41, v33, v48                                 ; 2c526121
	v_cvt_f32_ubyte3_e32 v61, v57                               ; 7e7a2939
	v_mac_f32_e32 v19, v17, v60                                 ; 2c267911
	v_mac_f32_e32 v41, v62, v49                                 ; 2c52633e
	v_cvt_f32_ubyte2_e32 v62, v57                               ; 7e7c2739
	v_mul_f32_e32 v23, v23, v61                                 ; 0a2e7b17
	v_mac_f32_e32 v19, v16, v56                                 ; 2c267110
	v_mad_f32 v13, -v45, v41, v51                               ; d1c1000d 24ce532d
	v_mac_f32_e32 v23, v22, v62                                 ; 2c2e7d16
	v_cvt_f32_ubyte1_e32 v62, v57                               ; 7e7c2539
	v_cvt_f32_ubyte0_e32 v57, v57                               ; 7e722339
	v_mac_f32_e32 v23, v21, v62                                 ; 2c2e7d15
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v62, s14, v40                                 ; 267c500e
	v_lshrrev_b32_e32 v40, 4, v40                               ; 20505084
	v_mac_f32_e32 v23, v20, v57                                 ; 2c2e7314
	v_cvt_f32_ubyte2_e32 v15, v62                               ; 7e1e273e
	v_cvt_f32_ubyte1_e32 v16, v62                               ; 7e20253e
	v_cvt_f32_ubyte3_e32 v14, v62                               ; 7e1c293e
	v_cvt_f32_ubyte0_e32 v62, v62                               ; 7e7c233e
	v_and_b32_e32 v40, s14, v40                                 ; 2650500e
	v_mul_f32_e32 v27, v27, v14                                 ; 0a361d1b
	v_cvt_f32_ubyte1_e32 v20, v40                               ; 7e282528
	v_cvt_f32_ubyte3_e32 v17, v40                               ; 7e222928
	v_cvt_f32_ubyte2_e32 v18, v40                               ; 7e242728
	v_cvt_f32_ubyte0_e32 v40, v40                               ; 7e502328
	v_mac_f32_e32 v27, v26, v15                                 ; 2c361f1a
	v_mul_f32_e32 v43, v43, v17                                 ; 0a56232b
	v_mac_f32_e32 v27, v25, v16                                 ; 2c362119
	v_mac_f32_e32 v43, v30, v18                                 ; 2c56251e
	v_mac_f32_e32 v27, v24, v62                                 ; 2c367d18
	v_mac_f32_e32 v43, v29, v20                                 ; 2c56291d
	v_mac_f32_e32 v43, v28, v40                                 ; 2c56511c
	v_mul_f32_e32 v43, v43, v55                                 ; 0a566f2b
	v_mac_f32_e32 v43, v27, v46                                 ; 2c565d1b
	v_mac_f32_e32 v43, v23, v50                                 ; 2c566517
	v_mac_f32_e32 v43, v19, v31                                 ; 2c563f13
	v_mac_f32_e32 v13, v54, v43                                 ; 2c1a5736
	s_and_saveexec_b64 s[14:15], vcc                            ; be8e206a
BB11:
	s_andn2_wrexec_b64 s[14:15], s[14:15]                       ; be8e360e
	s_cbranch_scc1 BB6                                          ; bf85fcbd
BB12:
	s_mov_b64 exec, s[12:13]                                    ; befe010c
BB14:
	s_andn2_b64 exec, -1, exec                                  ; 89fe7ec1
	s_cbranch_execz BB17                                        ; bf880008
BB15:
	v_mov_b32_e32 v6, 0                                         ; 7e0c0280
	v_mov_b32_e32 v7, 0                                         ; 7e0e0280
	v_mov_b32_e32 v8, 0                                         ; 7e100280
	v_mov_b32_e32 v9, 0                                         ; 7e120280
	v_mov_b32_e32 v10, 0                                        ; 7e140280
	v_mov_b32_e32 v11, 0                                        ; 7e160280
	v_mov_b32_e32 v12, 0                                        ; 7e180280
	v_mov_b32_e32 v13, 0                                        ; 7e1a0280
BB17:
	s_mov_b64 exec, -1                                          ; befe01c1
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
BB18:
	s_bitcmp1_b32 s8, 0                                         ; bf0d8008
	s_cbranch_scc0 BB20                                         ; bf84000f
BB19:
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
	s_branch BB21                                               ; bf820002
BB20:
	s_mov_b32 s18, src_scc                                      ; be9200fd
	v_mov_b32_e32 v0, s0                                        ; 7e000200
BB21:
	s_bitcmp1_b32 s8, 1                                         ; bf0d8108
	s_cbranch_scc0 BB23                                         ; bf84000e
BB22:
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
	s_branch BB24                                               ; bf820001
BB23:
	s_mov_b32 s8, src_scc                                       ; be8800fd
BB24:
	s_mov_b32 s0, s3                                            ; be800003
	s_movk_i32 s3, 0x8000                                       ; b0038000
	s_load_dwordx4 s[12:15], s[2:3], 0x20                       ; c00a0301 00000020
	s_mul_i32 s7, s7, s17                                       ; 92071107
	s_add_u32 s7, s7, s16                                       ; 80071007
	s_lshl_b32 s7, s7, 2                                        ; 8e078207
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_store_dword v0, off, s[12:15], s7                    ; e0700000 07030080
	s_cmp_lg_i32 s18, 0                                         ; bf018012
	s_cbranch_scc0 BB26                                         ; bf84000b
BB25:
	s_load_dwordx4 s[16:19], s[2:3], 0x30                       ; c00a0401 00000030
	s_mov_b32 s11, src_scc                                      ; be8b00fd
	s_add_u32 s20, s7, 4                                        ; 80148407
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s20, s[16:19], s20                      ; c0200508 00000014
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_mov_b32_e32 v0, s20                                       ; 7e000214
	v_add_f32_e32 v0, s1, v0                                    ; 02000001
	s_branch BB27                                               ; bf820002
BB26:
	s_mov_b32 s11, src_scc                                      ; be8b00fd
	v_mov_b32_e32 v0, s1                                        ; 7e000201
BB27:
	s_cmp_lg_i32 s8, 0                                          ; bf018008
	s_cbranch_scc0 BB29                                         ; bf84000a
BB28:
	s_load_dwordx4 s[16:19], s[2:3], 0x40                       ; c00a0401 00000040
	s_mov_b32 s1, src_scc                                       ; be8100fd
	s_add_u32 s8, s7, 4                                         ; 80088407
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s8, s[16:19], s8                        ; c0200208 00000008
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v0, s8, v0                                    ; 02000008
	s_branch BB30                                               ; bf820001
BB29:
	s_mov_b32 s1, src_scc                                       ; be8100fd
BB30:
	s_add_u32 s8, s7, 4                                         ; 80088407
	buffer_store_dword v0, off, s[12:15], s8                    ; e0700000 08030080
	s_cmp_lg_i32 s11, 0                                         ; bf01800b
	s_cbranch_scc0 BB32                                         ; bf84000b
BB31:
	s_load_dwordx4 s[16:19], s[2:3], 0x30                       ; c00a0401 00000030
	s_mov_b32 s8, src_scc                                       ; be8800fd
	s_add_u32 s11, s7, 8                                        ; 800b8807
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s11, s[16:19], s11                      ; c02002c8 0000000b
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_mov_b32_e32 v0, s11                                       ; 7e00020b
	v_add_f32_e32 v0, s0, v0                                    ; 02000000
	s_branch BB33                                               ; bf820002
BB32:
	s_mov_b32 s8, src_scc                                       ; be8800fd
	v_mov_b32_e32 v0, s0                                        ; 7e000200
BB33:
	s_cmp_lg_i32 s1, 0                                          ; bf018001
	s_cbranch_scc0 BB35                                         ; bf84000a
BB34:
	s_load_dwordx4 s[16:19], s[2:3], 0x40                       ; c00a0401 00000040
	s_mov_b32 s0, src_scc                                       ; be8000fd
	s_add_u32 s1, s7, 8                                         ; 80018807
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s1, s[16:19], s1                        ; c0200048 00000001
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v0, s1, v0                                    ; 02000001
	s_branch BB36                                               ; bf820001
BB35:
	s_mov_b32 s0, src_scc                                       ; be8000fd
BB36:
	s_add_u32 s1, s7, 8                                         ; 80018807
	buffer_store_dword v0, off, s[12:15], s1                    ; e0700000 01030080
	s_cmp_lg_i32 s8, 0                                          ; bf018008
	s_cbranch_scc0 BB38                                         ; bf84000b
BB37:
	s_load_dwordx4 s[16:19], s[2:3], 0x30                       ; c00a0401 00000030
	s_mov_b32 s1, src_scc                                       ; be8100fd
	s_add_u32 s8, s7, 12                                        ; 80088c07
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s8, s[16:19], s8                        ; c0200208 00000008
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_mov_b32_e32 v0, s8                                        ; 7e000208
	v_add_f32_e32 v0, s4, v0                                    ; 02000004
	s_branch BB39                                               ; bf820002
BB38:
	s_mov_b32 s1, src_scc                                       ; be8100fd
	v_mov_b32_e32 v0, s4                                        ; 7e000204
BB39:
	s_cmp_lg_i32 s0, 0                                          ; bf018000
	s_cbranch_scc0 BB41                                         ; bf84000a
BB40:
	s_load_dwordx4 s[16:19], s[2:3], 0x40                       ; c00a0401 00000040
	s_mov_b32 s0, src_scc                                       ; be8000fd
	s_add_u32 s4, s7, 12                                        ; 80048c07
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s4, s[16:19], s4                        ; c0200108 00000004
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v0, s4, v0                                    ; 02000004
	s_branch BB42                                               ; bf820001
BB41:
	s_mov_b32 s0, src_scc                                       ; be8000fd
BB42:
	s_add_u32 s4, s7, 12                                        ; 80048c07
	buffer_store_dword v0, off, s[12:15], s4                    ; e0700000 04030080
	s_cmp_lg_i32 s1, 0                                          ; bf018001
	s_cbranch_scc0 BB44                                         ; bf84000b
BB43:
	s_load_dwordx4 s[16:19], s[2:3], 0x30                       ; c00a0401 00000030
	s_mov_b32 s1, src_scc                                       ; be8100fd
	s_add_u32 s4, s7, 16                                        ; 80049007
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s4, s[16:19], s4                        ; c0200108 00000004
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_mov_b32_e32 v0, s4                                        ; 7e000204
	v_add_f32_e32 v0, s5, v0                                    ; 02000005
	s_branch BB45                                               ; bf820002
BB44:
	s_mov_b32 s1, src_scc                                       ; be8100fd
	v_mov_b32_e32 v0, s5                                        ; 7e000205
BB45:
	s_cmp_lg_i32 s0, 0                                          ; bf018000
	s_cbranch_scc0 BB47                                         ; bf84000a
BB46:
	s_load_dwordx4 s[16:19], s[2:3], 0x40                       ; c00a0401 00000040
	s_mov_b32 s0, src_scc                                       ; be8000fd
	s_add_u32 s4, s7, 16                                        ; 80049007
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s4, s[16:19], s4                        ; c0200108 00000004
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v0, s4, v0                                    ; 02000004
	s_branch BB48                                               ; bf820001
BB47:
	s_mov_b32 s0, src_scc                                       ; be8000fd
BB48:
	s_add_u32 s4, s7, 16                                        ; 80049007
	buffer_store_dword v0, off, s[12:15], s4                    ; e0700000 04030080
	s_cmp_lg_i32 s1, 0                                          ; bf018001
	s_cbranch_scc0 BB50                                         ; bf84000b
BB49:
	s_load_dwordx4 s[16:19], s[2:3], 0x30                       ; c00a0401 00000030
	s_mov_b32 s1, src_scc                                       ; be8100fd
	s_add_u32 s4, s7, 20                                        ; 80049407
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s4, s[16:19], s4                        ; c0200108 00000004
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_mov_b32_e32 v0, s4                                        ; 7e000204
	v_add_f32_e32 v0, s6, v0                                    ; 02000006
	s_branch BB51                                               ; bf820002
BB50:
	s_mov_b32 s1, src_scc                                       ; be8100fd
	v_mov_b32_e32 v0, s6                                        ; 7e000206
BB51:
	s_cmp_lg_i32 s0, 0                                          ; bf018000
	s_cbranch_scc0 BB53                                         ; bf84000a
BB52:
	s_load_dwordx4 s[16:19], s[2:3], 0x40                       ; c00a0401 00000040
	s_mov_b32 s0, src_scc                                       ; be8000fd
	s_add_u32 s4, s7, 20                                        ; 80049407
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s4, s[16:19], s4                        ; c0200108 00000004
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v0, s4, v0                                    ; 02000004
	s_branch BB54                                               ; bf820001
BB53:
	s_mov_b32 s0, src_scc                                       ; be8000fd
BB54:
	s_add_u32 s4, s7, 20                                        ; 80049407
	buffer_store_dword v0, off, s[12:15], s4                    ; e0700000 04030080
	s_cmp_lg_i32 s1, 0                                          ; bf018001
	s_cbranch_scc0 BB56                                         ; bf84000b
BB55:
	s_load_dwordx4 s[16:19], s[2:3], 0x30                       ; c00a0401 00000030
	s_mov_b32 s1, src_scc                                       ; be8100fd
	s_add_u32 s4, s7, 24                                        ; 80049807
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s4, s[16:19], s4                        ; c0200108 00000004
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_mov_b32_e32 v0, s4                                        ; 7e000204
	v_add_f32_e32 v0, s9, v0                                    ; 02000009
	s_branch BB57                                               ; bf820002
BB56:
	s_mov_b32 s1, src_scc                                       ; be8100fd
	v_mov_b32_e32 v0, s9                                        ; 7e000209
BB57:
	s_cmp_lg_i32 s0, 0                                          ; bf018000
	s_cbranch_scc0 BB59                                         ; bf84000a
BB58:
	s_load_dwordx4 s[16:19], s[2:3], 0x40                       ; c00a0401 00000040
	s_mov_b32 s0, src_scc                                       ; be8000fd
	s_add_u32 s4, s7, 24                                        ; 80049807
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s4, s[16:19], s4                        ; c0200108 00000004
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v0, s4, v0                                    ; 02000004
	s_branch BB60                                               ; bf820001
BB59:
	s_mov_b32 s0, src_scc                                       ; be8000fd
BB60:
	s_add_u32 s4, s7, 24                                        ; 80049807
	buffer_store_dword v0, off, s[12:15], s4                    ; e0700000 04030080
	s_cmp_lg_i32 s1, 0                                          ; bf018001
	s_cbranch_scc0 BB62                                         ; bf84000a
BB61:
	s_load_dwordx4 s[16:19], s[2:3], 0x30                       ; c00a0401 00000030
	s_add_u32 s1, s7, 28                                        ; 80019c07
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s1, s[16:19], s1                        ; c0200048 00000001
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_mov_b32_e32 v0, s1                                        ; 7e000201
	v_add_f32_e32 v0, s10, v0                                   ; 0200000a
	s_branch BB63                                               ; bf820001
BB62:
	v_mov_b32_e32 v0, s10                                       ; 7e00020a
BB63:
	s_cmp_lg_i32 s0, 0                                          ; bf018000
	s_cbranch_scc0 BB66                                         ; bf840008
BB64:
	s_load_dwordx4 s[0:3], s[2:3], 0x40                         ; c00a0001 00000040
	s_add_u32 s4, s7, 28                                        ; 80049c07
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s4, s[0:3], s4                          ; c0200100 00000004
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v0, s4, v0                                    ; 02000004
BB66:
	s_add_u32 s7, s7, 28                                        ; 80079c07
	buffer_store_dword v0, off, s[12:15], s7                    ; e0700000 07030080
	s_branch BB215                                              ; bf8205e6
BB72:
	s_cmp_lt_u32 s16, s4                                        ; bf0a0410
	s_cbranch_scc0 BB215                                        ; bf8405e4
BB73:
	s_sub_i32 s4, s4, s16                                       ; 81841004
	s_add_u32 s17, s17, s9                                      ; 80110911
	s_cmp_lg_i32 s17, 0                                         ; bf018011
	s_cbranch_scc0 BB75                                         ; bf840043
BB74:
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
	s_branch BB76                                               ; bf820001
BB75:
	s_mov_b32 s19, 0                                            ; be930080
BB76:
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
	s_cbranch_execz BB110                                       ; bf8803a3
BB77:
	s_mov_b32 s0, s2                                            ; be800002
	s_movk_i32 s1, 0x8000                                       ; b0018000
	s_load_dwordx4 s[12:15], s[0:1], 0x10                       ; c00a0300 00000010
	s_mul_i32 s6, s6, s17                                       ; 92061106
	s_cmp_lg_i32 s4, 0                                          ; bf018004
	s_mov_b64 s[10:11], exec                                    ; be8a017e
	v_mov_b32_e32 v3, 0                                         ; 7e060280
	v_mov_b32_e32 v5, 0                                         ; 7e0a0280
	v_mov_b32_e32 v6, 0                                         ; 7e0c0280
	v_mov_b32_e32 v7, 0                                         ; 7e0e0280
	v_mov_b32_e32 v8, 0                                         ; 7e100280
	v_mov_b32_e32 v9, 0                                         ; 7e120280
	v_mov_b32_e32 v10, 0                                        ; 7e140280
	v_mov_b32_e32 v11, 0                                        ; 7e160280
	s_branch BB78                                               ; bf820002
BB107:
	s_mov_b64 exec, s[20:21]                                    ; befe0114
	s_cmp_lg_i32 s9, 0                                          ; bf018009
BB78:
	v_lshl_add_u32 v12, v0, 8, v1                               ; d1fd000c 04051100
	v_add_u32_e32 v13, s6, v12                                  ; 681a1806
	v_add_u32_e32 v12, 0x80, v12                                ; 681818ff 00000080
	v_lshrrev_b32_e32 v13, 2, v13                               ; 201a1a82
	v_add_u32_e32 v12, s6, v12                                  ; 68181806
	v_lshlrev_b32_e32 v13, 4, v13                               ; 241a1a84
	v_lshrrev_b32_e32 v12, 2, v12                               ; 20181882
	v_lshlrev_b32_e32 v12, 4, v12                               ; 24181884
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_load_dwordx4 v[16:19], v13, s[12:15], 0 offen        ; e05c1000 8003100d
	buffer_load_dwordx4 v[20:23], v13, s[12:15], 0 offen offset:128 ; e05c1080 8003140d
	buffer_load_dwordx4 v[24:27], v12, s[12:15], 0 offen        ; e05c1000 8003180c
	buffer_load_dwordx4 v[12:15], v12, s[12:15], 0 offen offset:128 ; e05c1080 80030c0c
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_add_f32_e32 v28, v16, v17                                 ; 02382310
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_add_f32_e32 v29, v20, v21                                 ; 023a2b14
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_add_f32_e32 v30, v24, v25                                 ; 023c3318
	v_add_f32_e32 v28, v28, v18                                 ; 0238251c
	v_add_f32_e32 v29, v29, v22                                 ; 023a2d1d
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_add_f32_e32 v31, v12, v13                                 ; 023e1b0c
	v_add_f32_e32 v30, v30, v26                                 ; 023c351e
	v_add_f32_e32 v28, v28, v19                                 ; 0238271c
	v_add_f32_e32 v29, v29, v23                                 ; 023a2f1d
	v_add_f32_e32 v31, v31, v14                                 ; 023e1d1f
	v_add_f32_e32 v30, v30, v27                                 ; 023c371e
	v_add_f32_e32 v31, v31, v15                                 ; 023e1f1f
	s_cbranch_scc0 BB101                                        ; bf840366
BB79:
	s_load_dwordx4 s[20:23], s[0:1], 0x0                        ; c00a0500 00000000
	s_mul_i32 s5, s16, s3                                       ; 92050310
	s_mov_b32 s9, src_scc                                       ; be8900fd
	v_lshlrev_b32_e32 v34, 1, v2                                ; 24440481
	v_add_u32_e32 v42, 64, v4                                   ; 685408c0
	s_add_u32 s5, s19, s5                                       ; 80050513
	v_and_b32_e32 v36, -4, v34                                  ; 264844c4
	v_add_u32_e32 v39, 8, v34                                   ; 684e4488
	v_add_u32_e32 v32, s5, v0                                   ; 68400005
	v_lshlrev_b32_e32 v33, 4, v32                               ; 24424084
	v_lshl_add_u32 v32, v32, 7, v33                             ; d1fd0020 04850f20
	v_add_u32_e32 v35, 4, v32                                   ; 68464084
	v_add_u32_e32 v40, 16, v32                                  ; 68504090
	v_add_u32_e32 v37, v36, v35                                 ; 684a4724
	v_add_u32_e32 v38, v35, v34                                 ; 684c4523
	v_add_u32_e32 v35, v35, v39                                 ; 68464f23
	v_add_u32_e32 v41, v40, v4                                  ; 68520928
	v_add_u32_e32 v40, v40, v42                                 ; 68505528
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_load_dword v32, v32, s[20:23], 0 offen               ; e0501000 80052020
	buffer_load_dwordx2 v[44:45], v37, s[20:23], 0 offen        ; e0541000 80052c25
	buffer_load_ushort v35, v35, s[20:23], 0 offen              ; e0481000 80052323
	buffer_load_dword v41, v41, s[20:23], 0 offen               ; e0501000 80052929
	buffer_load_dword v40, v40, s[20:23], 0 offen               ; e0501000 80052828
	s_mov_b32 s18, 0xf0f0f0f                                    ; be9200ff 0f0f0f0f
	s_cmp_lt_u32 1, s4                                          ; bf0a0481
	s_waitcnt vmcnt(4)                                          ; bf8c3f74
	v_cvt_f32_f16_sdwa v43, v32 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e5616f9 00050620
	v_cvt_f32_f16_e32 v32, v32                                  ; 7e401720
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_alignbyte_b32 v44, v45, v44, v38                          ; d1cf002c 049a592d
	v_alignbyte_b32 v45, v45, v45, v38                          ; d1cf002d 049a5b2d
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_lshl_or_b32 v35, v35, 12, v35                             ; d2000023 048d1923
	v_mov_b32_sdwa v44, v45 dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_0 ; 7e5802f9 0004152d
	v_and_b32_e32 v45, 0xc0c0c0c0, v44                          ; 265a58ff c0c0c0c0
	v_and_b32_e32 v44, 0x3f3f3f3f, v44                          ; 265858ff 3f3f3f3f
	v_lshrrev_b32_e32 v45, 2, v45                               ; 205a5a82
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v52, s18, v41                                 ; 26685212
	v_cvt_f32_ubyte3_e32 v46, v44                               ; 7e5c292c
	v_cvt_f32_ubyte2_e32 v47, v44                               ; 7e5e272c
	v_cvt_f32_ubyte1_e32 v48, v44                               ; 7e60252c
	v_cvt_f32_ubyte0_e32 v44, v44                               ; 7e58232c
	v_and_or_b32 v35, s18, v35, v45                             ; d2010023 04b64612
	v_cvt_f32_ubyte2_e32 v54, v52                               ; 7e6c2734
	v_cvt_f32_ubyte3_e32 v53, v52                               ; 7e6a2934
	v_cvt_f32_ubyte1_e32 v55, v52                               ; 7e6e2534
	v_cvt_f32_ubyte0_e32 v52, v52                               ; 7e682334
	v_cvt_f32_ubyte1_e32 v51, v35                               ; 7e662523
	v_cvt_f32_ubyte2_e32 v50, v35                               ; 7e642723
	v_cvt_f32_ubyte3_e32 v49, v35                               ; 7e622923
	v_cvt_f32_ubyte0_e32 v35, v35                               ; 7e462323
	v_lshrrev_b32_e32 v41, 4, v41                               ; 20525284
	v_mul_f32_e32 v53, v19, v53                                 ; 0a6a6b13
	v_mul_f32_e32 v49, v31, v49                                 ; 0a62631f
	v_and_b32_e32 v41, s18, v41                                 ; 26525212
	v_mac_f32_e32 v53, v18, v54                                 ; 2c6a6d12
	v_mac_f32_e32 v49, v30, v50                                 ; 2c62651e
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v59, s18, v40                                 ; 26765012
	v_cvt_f32_ubyte2_e32 v57, v41                               ; 7e722729
	v_cvt_f32_ubyte3_e32 v56, v41                               ; 7e702929
	v_cvt_f32_ubyte1_e32 v58, v41                               ; 7e742529
	v_cvt_f32_ubyte0_e32 v41, v41                               ; 7e522329
	v_mac_f32_e32 v53, v17, v55                                 ; 2c6a6f11
	v_mac_f32_e32 v49, v29, v46                                 ; 2c625d1d
	v_cvt_f32_ubyte3_e32 v60, v59                               ; 7e78293b
	v_cvt_f32_ubyte2_e32 v61, v59                               ; 7e7a273b
	v_cvt_f32_ubyte1_e32 v62, v59                               ; 7e7c253b
	v_mul_f32_e32 v56, v23, v56                                 ; 0a707117
	v_cvt_f32_ubyte0_e32 v59, v59                               ; 7e76233b
	v_mac_f32_e32 v53, v16, v52                                 ; 2c6a6910
	v_lshrrev_b32_e32 v40, 4, v40                               ; 20505084
	v_mac_f32_e32 v49, v28, v47                                 ; 2c625f1c
	v_mul_f32_e32 v60, v27, v60                                 ; 0a78791b
	v_mac_f32_e32 v56, v22, v57                                 ; 2c707316
	v_and_b32_e32 v40, s18, v40                                 ; 26505012
	v_mad_f32 v3, -v43, v49, v3                                 ; d1c10003 240e632b
	v_mac_f32_e32 v60, v26, v61                                 ; 2c787b1a
	v_mac_f32_e32 v56, v21, v58                                 ; 2c707515
	v_cvt_f32_ubyte1_e32 v37, v40                               ; 7e4a2528
	v_cvt_f32_ubyte2_e32 v33, v40                               ; 7e422728
	v_mac_f32_e32 v60, v25, v62                                 ; 2c787d19
	v_cvt_f32_ubyte3_e32 v62, v40                               ; 7e7c2928
	v_cvt_f32_ubyte0_e32 v40, v40                               ; 7e502328
	v_mac_f32_e32 v56, v20, v41                                 ; 2c705314
	v_mac_f32_e32 v60, v24, v59                                 ; 2c787718
	v_mul_f32_e32 v62, v15, v62                                 ; 0a7c7d0f
	v_mac_f32_e32 v62, v14, v33                                 ; 2c7c430e
	v_mac_f32_e32 v62, v13, v37                                 ; 2c7c4b0d
	v_mac_f32_e32 v62, v12, v40                                 ; 2c7c510c
	v_mul_f32_e32 v62, v62, v51                                 ; 0a7c673e
	v_mac_f32_e32 v62, v60, v35                                 ; 2c7c473c
	v_mac_f32_e32 v62, v56, v48                                 ; 2c7c6138
	v_mac_f32_e32 v62, v53, v44                                 ; 2c7c5935
	v_mac_f32_e32 v3, v32, v62                                  ; 2c067d20
	s_cbranch_scc0 BB102                                        ; bf8402f4
BB80:
	s_add_u32 s5, s16, 1                                        ; 80058110
	s_mul_i32 s5, s5, s3                                        ; 92050305
	s_add_u32 s5, s19, s5                                       ; 80050513
	v_add_u32_e32 v32, s5, v0                                   ; 68400005
	v_lshlrev_b32_e32 v33, 4, v32                               ; 24424084
	v_lshl_add_u32 v32, v32, 7, v33                             ; d1fd0020 04850f20
	v_add_u32_e32 v35, 4, v32                                   ; 68464084
	v_add_u32_e32 v40, 16, v32                                  ; 68504090
	v_add_u32_e32 v37, v36, v35                                 ; 684a4724
	v_add_u32_e32 v38, v35, v34                                 ; 684c4523
	v_add_u32_e32 v35, v35, v39                                 ; 68464f23
	v_add_u32_e32 v41, v40, v4                                  ; 68520928
	v_add_u32_e32 v40, v40, v42                                 ; 68505528
	buffer_load_dword v32, v32, s[20:23], 0 offen               ; e0501000 80052020
	buffer_load_dwordx2 v[44:45], v37, s[20:23], 0 offen        ; e0541000 80052c25
	buffer_load_ushort v35, v35, s[20:23], 0 offen              ; e0481000 80052323
	buffer_load_dword v41, v41, s[20:23], 0 offen               ; e0501000 80052929
	buffer_load_dword v40, v40, s[20:23], 0 offen               ; e0501000 80052828
	s_mov_b32 s18, 0xf0f0f0f                                    ; be9200ff 0f0f0f0f
	s_cmp_lt_u32 2, s4                                          ; bf0a0482
	s_waitcnt vmcnt(4)                                          ; bf8c3f74
	v_cvt_f32_f16_sdwa v43, v32 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e5616f9 00050620
	v_cvt_f32_f16_e32 v32, v32                                  ; 7e401720
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_alignbyte_b32 v44, v45, v44, v38                          ; d1cf002c 049a592d
	v_alignbyte_b32 v45, v45, v45, v38                          ; d1cf002d 049a5b2d
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_lshl_or_b32 v35, v35, 12, v35                             ; d2000023 048d1923
	v_mov_b32_sdwa v44, v45 dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_0 ; 7e5802f9 0004152d
	v_and_b32_e32 v45, 0xc0c0c0c0, v44                          ; 265a58ff c0c0c0c0
	v_and_b32_e32 v44, 0x3f3f3f3f, v44                          ; 265858ff 3f3f3f3f
	v_lshrrev_b32_e32 v45, 2, v45                               ; 205a5a82
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v52, s18, v41                                 ; 26685212
	v_cvt_f32_ubyte3_e32 v46, v44                               ; 7e5c292c
	v_cvt_f32_ubyte2_e32 v47, v44                               ; 7e5e272c
	v_cvt_f32_ubyte1_e32 v48, v44                               ; 7e60252c
	v_cvt_f32_ubyte0_e32 v44, v44                               ; 7e58232c
	v_and_or_b32 v35, s18, v35, v45                             ; d2010023 04b64612
	v_cvt_f32_ubyte3_e32 v53, v52                               ; 7e6a2934
	v_cvt_f32_ubyte2_e32 v54, v52                               ; 7e6c2734
	v_cvt_f32_ubyte1_e32 v55, v52                               ; 7e6e2534
	v_cvt_f32_ubyte0_e32 v52, v52                               ; 7e682334
	v_cvt_f32_ubyte1_e32 v51, v35                               ; 7e662523
	v_cvt_f32_ubyte3_e32 v49, v35                               ; 7e622923
	v_cvt_f32_ubyte2_e32 v50, v35                               ; 7e642723
	v_cvt_f32_ubyte0_e32 v35, v35                               ; 7e462323
	v_mul_f32_e32 v53, v19, v53                                 ; 0a6a6b13
	v_lshrrev_b32_e32 v41, 4, v41                               ; 20525284
	v_mul_f32_e32 v49, v31, v49                                 ; 0a62631f
	v_mac_f32_e32 v53, v18, v54                                 ; 2c6a6d12
	v_and_b32_e32 v41, s18, v41                                 ; 26525212
	v_mac_f32_e32 v49, v30, v50                                 ; 2c62651e
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v59, s18, v40                                 ; 26765012
	v_mac_f32_e32 v53, v17, v55                                 ; 2c6a6f11
	v_cvt_f32_ubyte3_e32 v56, v41                               ; 7e702929
	v_cvt_f32_ubyte2_e32 v57, v41                               ; 7e722729
	v_cvt_f32_ubyte1_e32 v58, v41                               ; 7e742529
	v_cvt_f32_ubyte0_e32 v41, v41                               ; 7e522329
	v_mac_f32_e32 v49, v29, v46                                 ; 2c625d1d
	v_cvt_f32_ubyte2_e32 v61, v59                               ; 7e7a273b
	v_cvt_f32_ubyte3_e32 v60, v59                               ; 7e78293b
	v_cvt_f32_ubyte1_e32 v62, v59                               ; 7e7c253b
	v_mac_f32_e32 v53, v16, v52                                 ; 2c6a6910
	v_mul_f32_e32 v56, v23, v56                                 ; 0a707117
	v_cvt_f32_ubyte0_e32 v59, v59                               ; 7e76233b
	v_lshrrev_b32_e32 v40, 4, v40                               ; 20505084
	v_mac_f32_e32 v49, v28, v47                                 ; 2c625f1c
	v_mul_f32_e32 v60, v27, v60                                 ; 0a78791b
	v_mac_f32_e32 v56, v22, v57                                 ; 2c707316
	v_and_b32_e32 v40, s18, v40                                 ; 26505012
	v_mad_f32 v5, -v43, v49, v5                                 ; d1c10005 2416632b
	v_mac_f32_e32 v60, v26, v61                                 ; 2c787b1a
	v_mac_f32_e32 v56, v21, v58                                 ; 2c707515
	v_cvt_f32_ubyte1_e32 v37, v40                               ; 7e4a2528
	v_cvt_f32_ubyte2_e32 v33, v40                               ; 7e422728
	v_mac_f32_e32 v60, v25, v62                                 ; 2c787d19
	v_cvt_f32_ubyte3_e32 v62, v40                               ; 7e7c2928
	v_cvt_f32_ubyte0_e32 v40, v40                               ; 7e502328
	v_mac_f32_e32 v56, v20, v41                                 ; 2c705314
	v_mac_f32_e32 v60, v24, v59                                 ; 2c787718
	v_mul_f32_e32 v62, v15, v62                                 ; 0a7c7d0f
	v_mac_f32_e32 v62, v14, v33                                 ; 2c7c430e
	v_mac_f32_e32 v62, v13, v37                                 ; 2c7c4b0d
	v_mac_f32_e32 v62, v12, v40                                 ; 2c7c510c
	v_mul_f32_e32 v62, v62, v51                                 ; 0a7c673e
	v_mac_f32_e32 v62, v60, v35                                 ; 2c7c473c
	v_mac_f32_e32 v62, v56, v48                                 ; 2c7c6138
	v_mac_f32_e32 v62, v53, v44                                 ; 2c7c5935
	v_mac_f32_e32 v5, v32, v62                                  ; 2c0a7d20
	s_cbranch_scc0 BB102                                        ; bf840288
BB81:
	s_add_u32 s5, s16, 2                                        ; 80058210
	s_mul_i32 s5, s5, s3                                        ; 92050305
	s_add_u32 s5, s19, s5                                       ; 80050513
	v_add_u32_e32 v32, s5, v0                                   ; 68400005
	v_lshlrev_b32_e32 v33, 4, v32                               ; 24424084
	v_lshl_add_u32 v32, v32, 7, v33                             ; d1fd0020 04850f20
	v_add_u32_e32 v35, 4, v32                                   ; 68464084
	v_add_u32_e32 v40, 16, v32                                  ; 68504090
	v_add_u32_e32 v37, v36, v35                                 ; 684a4724
	v_add_u32_e32 v38, v35, v34                                 ; 684c4523
	v_add_u32_e32 v35, v35, v39                                 ; 68464f23
	v_add_u32_e32 v41, v40, v4                                  ; 68520928
	v_add_u32_e32 v40, v40, v42                                 ; 68505528
	buffer_load_dword v32, v32, s[20:23], 0 offen               ; e0501000 80052020
	buffer_load_dwordx2 v[44:45], v37, s[20:23], 0 offen        ; e0541000 80052c25
	buffer_load_ushort v35, v35, s[20:23], 0 offen              ; e0481000 80052323
	buffer_load_dword v41, v41, s[20:23], 0 offen               ; e0501000 80052929
	buffer_load_dword v40, v40, s[20:23], 0 offen               ; e0501000 80052828
	s_mov_b32 s18, 0xf0f0f0f                                    ; be9200ff 0f0f0f0f
	s_cmp_lt_u32 3, s4                                          ; bf0a0483
	s_waitcnt vmcnt(4)                                          ; bf8c3f74
	v_cvt_f32_f16_sdwa v43, v32 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e5616f9 00050620
	v_cvt_f32_f16_e32 v32, v32                                  ; 7e401720
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_alignbyte_b32 v44, v45, v44, v38                          ; d1cf002c 049a592d
	v_alignbyte_b32 v45, v45, v45, v38                          ; d1cf002d 049a5b2d
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_lshl_or_b32 v35, v35, 12, v35                             ; d2000023 048d1923
	v_mov_b32_sdwa v44, v45 dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_0 ; 7e5802f9 0004152d
	v_and_b32_e32 v45, 0xc0c0c0c0, v44                          ; 265a58ff c0c0c0c0
	v_and_b32_e32 v44, 0x3f3f3f3f, v44                          ; 265858ff 3f3f3f3f
	v_lshrrev_b32_e32 v45, 2, v45                               ; 205a5a82
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v52, s18, v41                                 ; 26685212
	v_cvt_f32_ubyte3_e32 v46, v44                               ; 7e5c292c
	v_cvt_f32_ubyte2_e32 v47, v44                               ; 7e5e272c
	v_cvt_f32_ubyte1_e32 v48, v44                               ; 7e60252c
	v_cvt_f32_ubyte0_e32 v44, v44                               ; 7e58232c
	v_and_or_b32 v35, s18, v35, v45                             ; d2010023 04b64612
	v_cvt_f32_ubyte3_e32 v53, v52                               ; 7e6a2934
	v_cvt_f32_ubyte2_e32 v54, v52                               ; 7e6c2734
	v_cvt_f32_ubyte1_e32 v55, v52                               ; 7e6e2534
	v_cvt_f32_ubyte0_e32 v52, v52                               ; 7e682334
	v_cvt_f32_ubyte1_e32 v51, v35                               ; 7e662523
	v_cvt_f32_ubyte3_e32 v49, v35                               ; 7e622923
	v_cvt_f32_ubyte2_e32 v50, v35                               ; 7e642723
	v_cvt_f32_ubyte0_e32 v35, v35                               ; 7e462323
	v_mul_f32_e32 v53, v19, v53                                 ; 0a6a6b13
	v_lshrrev_b32_e32 v41, 4, v41                               ; 20525284
	v_mul_f32_e32 v49, v31, v49                                 ; 0a62631f
	v_mac_f32_e32 v53, v18, v54                                 ; 2c6a6d12
	v_and_b32_e32 v41, s18, v41                                 ; 26525212
	v_mac_f32_e32 v49, v30, v50                                 ; 2c62651e
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v59, s18, v40                                 ; 26765012
	v_mac_f32_e32 v53, v17, v55                                 ; 2c6a6f11
	v_cvt_f32_ubyte3_e32 v56, v41                               ; 7e702929
	v_cvt_f32_ubyte2_e32 v57, v41                               ; 7e722729
	v_cvt_f32_ubyte1_e32 v58, v41                               ; 7e742529
	v_cvt_f32_ubyte0_e32 v41, v41                               ; 7e522329
	v_mac_f32_e32 v49, v29, v46                                 ; 2c625d1d
	v_cvt_f32_ubyte2_e32 v61, v59                               ; 7e7a273b
	v_cvt_f32_ubyte3_e32 v60, v59                               ; 7e78293b
	v_cvt_f32_ubyte1_e32 v62, v59                               ; 7e7c253b
	v_mac_f32_e32 v53, v16, v52                                 ; 2c6a6910
	v_mul_f32_e32 v56, v23, v56                                 ; 0a707117
	v_cvt_f32_ubyte0_e32 v59, v59                               ; 7e76233b
	v_lshrrev_b32_e32 v40, 4, v40                               ; 20505084
	v_mac_f32_e32 v49, v28, v47                                 ; 2c625f1c
	v_mul_f32_e32 v60, v27, v60                                 ; 0a78791b
	v_mac_f32_e32 v56, v22, v57                                 ; 2c707316
	v_and_b32_e32 v40, s18, v40                                 ; 26505012
	v_mad_f32 v6, -v43, v49, v6                                 ; d1c10006 241a632b
	v_mac_f32_e32 v60, v26, v61                                 ; 2c787b1a
	v_mac_f32_e32 v56, v21, v58                                 ; 2c707515
	v_cvt_f32_ubyte1_e32 v37, v40                               ; 7e4a2528
	v_cvt_f32_ubyte2_e32 v33, v40                               ; 7e422728
	v_mac_f32_e32 v60, v25, v62                                 ; 2c787d19
	v_cvt_f32_ubyte3_e32 v62, v40                               ; 7e7c2928
	v_cvt_f32_ubyte0_e32 v40, v40                               ; 7e502328
	v_mac_f32_e32 v56, v20, v41                                 ; 2c705314
	v_mac_f32_e32 v60, v24, v59                                 ; 2c787718
	v_mul_f32_e32 v62, v15, v62                                 ; 0a7c7d0f
	v_mac_f32_e32 v62, v14, v33                                 ; 2c7c430e
	v_mac_f32_e32 v62, v13, v37                                 ; 2c7c4b0d
	v_mac_f32_e32 v62, v12, v40                                 ; 2c7c510c
	v_mul_f32_e32 v62, v62, v51                                 ; 0a7c673e
	v_mac_f32_e32 v62, v60, v35                                 ; 2c7c473c
	v_mac_f32_e32 v62, v56, v48                                 ; 2c7c6138
	v_mac_f32_e32 v62, v53, v44                                 ; 2c7c5935
	v_mac_f32_e32 v6, v32, v62                                  ; 2c0c7d20
	s_cbranch_scc0 BB102                                        ; bf84021c
BB82:
	s_add_u32 s5, s16, 3                                        ; 80058310
	s_mul_i32 s5, s5, s3                                        ; 92050305
	s_add_u32 s5, s19, s5                                       ; 80050513
	v_add_u32_e32 v32, s5, v0                                   ; 68400005
	v_lshlrev_b32_e32 v33, 4, v32                               ; 24424084
	v_lshl_add_u32 v32, v32, 7, v33                             ; d1fd0020 04850f20
	v_add_u32_e32 v35, 4, v32                                   ; 68464084
	v_add_u32_e32 v40, 16, v32                                  ; 68504090
	v_add_u32_e32 v37, v36, v35                                 ; 684a4724
	v_add_u32_e32 v38, v35, v34                                 ; 684c4523
	v_add_u32_e32 v35, v35, v39                                 ; 68464f23
	v_add_u32_e32 v41, v40, v4                                  ; 68520928
	v_add_u32_e32 v40, v40, v42                                 ; 68505528
	buffer_load_dword v32, v32, s[20:23], 0 offen               ; e0501000 80052020
	buffer_load_dwordx2 v[44:45], v37, s[20:23], 0 offen        ; e0541000 80052c25
	buffer_load_ushort v35, v35, s[20:23], 0 offen              ; e0481000 80052323
	buffer_load_dword v41, v41, s[20:23], 0 offen               ; e0501000 80052929
	buffer_load_dword v40, v40, s[20:23], 0 offen               ; e0501000 80052828
	s_mov_b32 s18, 0xf0f0f0f                                    ; be9200ff 0f0f0f0f
	s_cmp_lt_u32 4, s4                                          ; bf0a0484
	s_waitcnt vmcnt(4)                                          ; bf8c3f74
	v_cvt_f32_f16_sdwa v43, v32 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e5616f9 00050620
	v_cvt_f32_f16_e32 v32, v32                                  ; 7e401720
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_alignbyte_b32 v44, v45, v44, v38                          ; d1cf002c 049a592d
	v_alignbyte_b32 v45, v45, v45, v38                          ; d1cf002d 049a5b2d
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_lshl_or_b32 v35, v35, 12, v35                             ; d2000023 048d1923
	v_mov_b32_sdwa v44, v45 dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_0 ; 7e5802f9 0004152d
	v_and_b32_e32 v45, 0xc0c0c0c0, v44                          ; 265a58ff c0c0c0c0
	v_and_b32_e32 v44, 0x3f3f3f3f, v44                          ; 265858ff 3f3f3f3f
	v_lshrrev_b32_e32 v45, 2, v45                               ; 205a5a82
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v52, s18, v41                                 ; 26685212
	v_cvt_f32_ubyte3_e32 v46, v44                               ; 7e5c292c
	v_cvt_f32_ubyte2_e32 v47, v44                               ; 7e5e272c
	v_cvt_f32_ubyte1_e32 v48, v44                               ; 7e60252c
	v_cvt_f32_ubyte0_e32 v44, v44                               ; 7e58232c
	v_and_or_b32 v35, s18, v35, v45                             ; d2010023 04b64612
	v_cvt_f32_ubyte3_e32 v53, v52                               ; 7e6a2934
	v_cvt_f32_ubyte2_e32 v54, v52                               ; 7e6c2734
	v_cvt_f32_ubyte1_e32 v55, v52                               ; 7e6e2534
	v_cvt_f32_ubyte0_e32 v52, v52                               ; 7e682334
	v_cvt_f32_ubyte1_e32 v51, v35                               ; 7e662523
	v_cvt_f32_ubyte3_e32 v49, v35                               ; 7e622923
	v_cvt_f32_ubyte2_e32 v50, v35                               ; 7e642723
	v_cvt_f32_ubyte0_e32 v35, v35                               ; 7e462323
	v_mul_f32_e32 v53, v19, v53                                 ; 0a6a6b13
	v_lshrrev_b32_e32 v41, 4, v41                               ; 20525284
	v_mul_f32_e32 v49, v31, v49                                 ; 0a62631f
	v_mac_f32_e32 v53, v18, v54                                 ; 2c6a6d12
	v_and_b32_e32 v41, s18, v41                                 ; 26525212
	v_mac_f32_e32 v49, v30, v50                                 ; 2c62651e
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v59, s18, v40                                 ; 26765012
	v_mac_f32_e32 v53, v17, v55                                 ; 2c6a6f11
	v_cvt_f32_ubyte3_e32 v56, v41                               ; 7e702929
	v_cvt_f32_ubyte2_e32 v57, v41                               ; 7e722729
	v_cvt_f32_ubyte1_e32 v58, v41                               ; 7e742529
	v_cvt_f32_ubyte0_e32 v41, v41                               ; 7e522329
	v_mac_f32_e32 v49, v29, v46                                 ; 2c625d1d
	v_cvt_f32_ubyte2_e32 v61, v59                               ; 7e7a273b
	v_cvt_f32_ubyte3_e32 v60, v59                               ; 7e78293b
	v_cvt_f32_ubyte1_e32 v62, v59                               ; 7e7c253b
	v_mac_f32_e32 v53, v16, v52                                 ; 2c6a6910
	v_mul_f32_e32 v56, v23, v56                                 ; 0a707117
	v_cvt_f32_ubyte0_e32 v59, v59                               ; 7e76233b
	v_lshrrev_b32_e32 v40, 4, v40                               ; 20505084
	v_mac_f32_e32 v49, v28, v47                                 ; 2c625f1c
	v_mul_f32_e32 v60, v27, v60                                 ; 0a78791b
	v_mac_f32_e32 v56, v22, v57                                 ; 2c707316
	v_and_b32_e32 v40, s18, v40                                 ; 26505012
	v_mad_f32 v7, -v43, v49, v7                                 ; d1c10007 241e632b
	v_mac_f32_e32 v60, v26, v61                                 ; 2c787b1a
	v_mac_f32_e32 v56, v21, v58                                 ; 2c707515
	v_cvt_f32_ubyte1_e32 v37, v40                               ; 7e4a2528
	v_cvt_f32_ubyte2_e32 v33, v40                               ; 7e422728
	v_mac_f32_e32 v60, v25, v62                                 ; 2c787d19
	v_cvt_f32_ubyte3_e32 v62, v40                               ; 7e7c2928
	v_cvt_f32_ubyte0_e32 v40, v40                               ; 7e502328
	v_mac_f32_e32 v56, v20, v41                                 ; 2c705314
	v_mac_f32_e32 v60, v24, v59                                 ; 2c787718
	v_mul_f32_e32 v62, v15, v62                                 ; 0a7c7d0f
	v_mac_f32_e32 v62, v14, v33                                 ; 2c7c430e
	v_mac_f32_e32 v62, v13, v37                                 ; 2c7c4b0d
	v_mac_f32_e32 v62, v12, v40                                 ; 2c7c510c
	v_mul_f32_e32 v62, v62, v51                                 ; 0a7c673e
	v_mac_f32_e32 v62, v60, v35                                 ; 2c7c473c
	v_mac_f32_e32 v62, v56, v48                                 ; 2c7c6138
	v_mac_f32_e32 v62, v53, v44                                 ; 2c7c5935
	v_mac_f32_e32 v7, v32, v62                                  ; 2c0e7d20
	s_cbranch_scc0 BB102                                        ; bf8401b0
BB83:
	s_add_u32 s5, s16, 4                                        ; 80058410
	s_mul_i32 s5, s5, s3                                        ; 92050305
	s_add_u32 s5, s19, s5                                       ; 80050513
	v_add_u32_e32 v32, s5, v0                                   ; 68400005
	v_lshlrev_b32_e32 v33, 4, v32                               ; 24424084
	v_lshl_add_u32 v32, v32, 7, v33                             ; d1fd0020 04850f20
	v_add_u32_e32 v35, 4, v32                                   ; 68464084
	v_add_u32_e32 v40, 16, v32                                  ; 68504090
	v_add_u32_e32 v37, v36, v35                                 ; 684a4724
	v_add_u32_e32 v38, v35, v34                                 ; 684c4523
	v_add_u32_e32 v35, v35, v39                                 ; 68464f23
	v_add_u32_e32 v41, v40, v4                                  ; 68520928
	v_add_u32_e32 v40, v40, v42                                 ; 68505528
	buffer_load_dword v32, v32, s[20:23], 0 offen               ; e0501000 80052020
	buffer_load_dwordx2 v[44:45], v37, s[20:23], 0 offen        ; e0541000 80052c25
	buffer_load_ushort v35, v35, s[20:23], 0 offen              ; e0481000 80052323
	buffer_load_dword v41, v41, s[20:23], 0 offen               ; e0501000 80052929
	buffer_load_dword v40, v40, s[20:23], 0 offen               ; e0501000 80052828
	s_mov_b32 s18, 0xf0f0f0f                                    ; be9200ff 0f0f0f0f
	s_cmp_lt_u32 5, s4                                          ; bf0a0485
	s_waitcnt vmcnt(4)                                          ; bf8c3f74
	v_cvt_f32_f16_sdwa v43, v32 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e5616f9 00050620
	v_cvt_f32_f16_e32 v32, v32                                  ; 7e401720
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_alignbyte_b32 v44, v45, v44, v38                          ; d1cf002c 049a592d
	v_alignbyte_b32 v45, v45, v45, v38                          ; d1cf002d 049a5b2d
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_lshl_or_b32 v35, v35, 12, v35                             ; d2000023 048d1923
	v_mov_b32_sdwa v44, v45 dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_0 ; 7e5802f9 0004152d
	v_and_b32_e32 v45, 0xc0c0c0c0, v44                          ; 265a58ff c0c0c0c0
	v_and_b32_e32 v44, 0x3f3f3f3f, v44                          ; 265858ff 3f3f3f3f
	v_lshrrev_b32_e32 v45, 2, v45                               ; 205a5a82
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v52, s18, v41                                 ; 26685212
	v_cvt_f32_ubyte3_e32 v46, v44                               ; 7e5c292c
	v_cvt_f32_ubyte2_e32 v47, v44                               ; 7e5e272c
	v_cvt_f32_ubyte1_e32 v48, v44                               ; 7e60252c
	v_cvt_f32_ubyte0_e32 v44, v44                               ; 7e58232c
	v_and_or_b32 v35, s18, v35, v45                             ; d2010023 04b64612
	v_cvt_f32_ubyte3_e32 v53, v52                               ; 7e6a2934
	v_cvt_f32_ubyte2_e32 v54, v52                               ; 7e6c2734
	v_cvt_f32_ubyte1_e32 v55, v52                               ; 7e6e2534
	v_cvt_f32_ubyte0_e32 v52, v52                               ; 7e682334
	v_cvt_f32_ubyte1_e32 v51, v35                               ; 7e662523
	v_cvt_f32_ubyte3_e32 v49, v35                               ; 7e622923
	v_cvt_f32_ubyte2_e32 v50, v35                               ; 7e642723
	v_cvt_f32_ubyte0_e32 v35, v35                               ; 7e462323
	v_mul_f32_e32 v53, v19, v53                                 ; 0a6a6b13
	v_lshrrev_b32_e32 v41, 4, v41                               ; 20525284
	v_mul_f32_e32 v49, v31, v49                                 ; 0a62631f
	v_mac_f32_e32 v53, v18, v54                                 ; 2c6a6d12
	v_and_b32_e32 v41, s18, v41                                 ; 26525212
	v_mac_f32_e32 v49, v30, v50                                 ; 2c62651e
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v59, s18, v40                                 ; 26765012
	v_mac_f32_e32 v53, v17, v55                                 ; 2c6a6f11
	v_cvt_f32_ubyte3_e32 v56, v41                               ; 7e702929
	v_cvt_f32_ubyte2_e32 v57, v41                               ; 7e722729
	v_cvt_f32_ubyte1_e32 v58, v41                               ; 7e742529
	v_cvt_f32_ubyte0_e32 v41, v41                               ; 7e522329
	v_mac_f32_e32 v49, v29, v46                                 ; 2c625d1d
	v_cvt_f32_ubyte2_e32 v61, v59                               ; 7e7a273b
	v_cvt_f32_ubyte3_e32 v60, v59                               ; 7e78293b
	v_cvt_f32_ubyte1_e32 v62, v59                               ; 7e7c253b
	v_mac_f32_e32 v53, v16, v52                                 ; 2c6a6910
	v_mul_f32_e32 v56, v23, v56                                 ; 0a707117
	v_cvt_f32_ubyte0_e32 v59, v59                               ; 7e76233b
	v_lshrrev_b32_e32 v40, 4, v40                               ; 20505084
	v_mac_f32_e32 v49, v28, v47                                 ; 2c625f1c
	v_mul_f32_e32 v60, v27, v60                                 ; 0a78791b
	v_mac_f32_e32 v56, v22, v57                                 ; 2c707316
	v_and_b32_e32 v40, s18, v40                                 ; 26505012
	v_mad_f32 v8, -v43, v49, v8                                 ; d1c10008 2422632b
	v_mac_f32_e32 v60, v26, v61                                 ; 2c787b1a
	v_mac_f32_e32 v56, v21, v58                                 ; 2c707515
	v_cvt_f32_ubyte1_e32 v37, v40                               ; 7e4a2528
	v_cvt_f32_ubyte2_e32 v33, v40                               ; 7e422728
	v_mac_f32_e32 v60, v25, v62                                 ; 2c787d19
	v_cvt_f32_ubyte3_e32 v62, v40                               ; 7e7c2928
	v_cvt_f32_ubyte0_e32 v40, v40                               ; 7e502328
	v_mac_f32_e32 v56, v20, v41                                 ; 2c705314
	v_mac_f32_e32 v60, v24, v59                                 ; 2c787718
	v_mul_f32_e32 v62, v15, v62                                 ; 0a7c7d0f
	v_mac_f32_e32 v62, v14, v33                                 ; 2c7c430e
	v_mac_f32_e32 v62, v13, v37                                 ; 2c7c4b0d
	v_mac_f32_e32 v62, v12, v40                                 ; 2c7c510c
	v_mul_f32_e32 v62, v62, v51                                 ; 0a7c673e
	v_mac_f32_e32 v62, v60, v35                                 ; 2c7c473c
	v_mac_f32_e32 v62, v56, v48                                 ; 2c7c6138
	v_mac_f32_e32 v62, v53, v44                                 ; 2c7c5935
	v_mac_f32_e32 v8, v32, v62                                  ; 2c107d20
	s_cbranch_scc0 BB102                                        ; bf840144
BB84:
	s_add_u32 s5, s16, 5                                        ; 80058510
	s_mul_i32 s5, s5, s3                                        ; 92050305
	s_add_u32 s5, s19, s5                                       ; 80050513
	v_add_u32_e32 v32, s5, v0                                   ; 68400005
	v_lshlrev_b32_e32 v33, 4, v32                               ; 24424084
	v_lshl_add_u32 v32, v32, 7, v33                             ; d1fd0020 04850f20
	v_add_u32_e32 v35, 4, v32                                   ; 68464084
	v_add_u32_e32 v40, 16, v32                                  ; 68504090
	v_add_u32_e32 v37, v36, v35                                 ; 684a4724
	v_add_u32_e32 v38, v35, v34                                 ; 684c4523
	v_add_u32_e32 v35, v35, v39                                 ; 68464f23
	v_add_u32_e32 v41, v40, v4                                  ; 68520928
	v_add_u32_e32 v40, v40, v42                                 ; 68505528
	buffer_load_dword v32, v32, s[20:23], 0 offen               ; e0501000 80052020
	buffer_load_dwordx2 v[44:45], v37, s[20:23], 0 offen        ; e0541000 80052c25
	buffer_load_ushort v35, v35, s[20:23], 0 offen              ; e0481000 80052323
	buffer_load_dword v41, v41, s[20:23], 0 offen               ; e0501000 80052929
	buffer_load_dword v40, v40, s[20:23], 0 offen               ; e0501000 80052828
	s_mov_b32 s18, 0xf0f0f0f                                    ; be9200ff 0f0f0f0f
	s_cmp_lt_u32 6, s4                                          ; bf0a0486
	s_waitcnt vmcnt(4)                                          ; bf8c3f74
	v_cvt_f32_f16_sdwa v43, v32 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e5616f9 00050620
	v_cvt_f32_f16_e32 v32, v32                                  ; 7e401720
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_alignbyte_b32 v44, v45, v44, v38                          ; d1cf002c 049a592d
	v_alignbyte_b32 v45, v45, v45, v38                          ; d1cf002d 049a5b2d
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_lshl_or_b32 v35, v35, 12, v35                             ; d2000023 048d1923
	v_mov_b32_sdwa v44, v45 dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_0 ; 7e5802f9 0004152d
	v_and_b32_e32 v45, 0xc0c0c0c0, v44                          ; 265a58ff c0c0c0c0
	v_and_b32_e32 v44, 0x3f3f3f3f, v44                          ; 265858ff 3f3f3f3f
	v_lshrrev_b32_e32 v45, 2, v45                               ; 205a5a82
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v52, s18, v41                                 ; 26685212
	v_cvt_f32_ubyte3_e32 v46, v44                               ; 7e5c292c
	v_cvt_f32_ubyte2_e32 v47, v44                               ; 7e5e272c
	v_cvt_f32_ubyte1_e32 v48, v44                               ; 7e60252c
	v_cvt_f32_ubyte0_e32 v44, v44                               ; 7e58232c
	v_and_or_b32 v35, s18, v35, v45                             ; d2010023 04b64612
	v_cvt_f32_ubyte3_e32 v53, v52                               ; 7e6a2934
	v_cvt_f32_ubyte2_e32 v54, v52                               ; 7e6c2734
	v_cvt_f32_ubyte1_e32 v55, v52                               ; 7e6e2534
	v_cvt_f32_ubyte0_e32 v52, v52                               ; 7e682334
	v_cvt_f32_ubyte1_e32 v51, v35                               ; 7e662523
	v_cvt_f32_ubyte3_e32 v49, v35                               ; 7e622923
	v_cvt_f32_ubyte2_e32 v50, v35                               ; 7e642723
	v_cvt_f32_ubyte0_e32 v35, v35                               ; 7e462323
	v_mul_f32_e32 v53, v19, v53                                 ; 0a6a6b13
	v_lshrrev_b32_e32 v41, 4, v41                               ; 20525284
	v_mul_f32_e32 v49, v31, v49                                 ; 0a62631f
	v_mac_f32_e32 v53, v18, v54                                 ; 2c6a6d12
	v_and_b32_e32 v41, s18, v41                                 ; 26525212
	v_mac_f32_e32 v49, v30, v50                                 ; 2c62651e
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v59, s18, v40                                 ; 26765012
	v_mac_f32_e32 v53, v17, v55                                 ; 2c6a6f11
	v_cvt_f32_ubyte3_e32 v56, v41                               ; 7e702929
	v_cvt_f32_ubyte2_e32 v57, v41                               ; 7e722729
	v_cvt_f32_ubyte1_e32 v58, v41                               ; 7e742529
	v_cvt_f32_ubyte0_e32 v41, v41                               ; 7e522329
	v_mac_f32_e32 v49, v29, v46                                 ; 2c625d1d
	v_cvt_f32_ubyte2_e32 v61, v59                               ; 7e7a273b
	v_cvt_f32_ubyte3_e32 v60, v59                               ; 7e78293b
	v_cvt_f32_ubyte1_e32 v62, v59                               ; 7e7c253b
	v_mac_f32_e32 v53, v16, v52                                 ; 2c6a6910
	v_mul_f32_e32 v56, v23, v56                                 ; 0a707117
	v_cvt_f32_ubyte0_e32 v59, v59                               ; 7e76233b
	v_lshrrev_b32_e32 v40, 4, v40                               ; 20505084
	v_mac_f32_e32 v49, v28, v47                                 ; 2c625f1c
	v_mul_f32_e32 v60, v27, v60                                 ; 0a78791b
	v_mac_f32_e32 v56, v22, v57                                 ; 2c707316
	v_and_b32_e32 v40, s18, v40                                 ; 26505012
	v_mad_f32 v9, -v43, v49, v9                                 ; d1c10009 2426632b
	v_mac_f32_e32 v60, v26, v61                                 ; 2c787b1a
	v_mac_f32_e32 v56, v21, v58                                 ; 2c707515
	v_cvt_f32_ubyte1_e32 v37, v40                               ; 7e4a2528
	v_cvt_f32_ubyte2_e32 v33, v40                               ; 7e422728
	v_mac_f32_e32 v60, v25, v62                                 ; 2c787d19
	v_cvt_f32_ubyte3_e32 v62, v40                               ; 7e7c2928
	v_cvt_f32_ubyte0_e32 v40, v40                               ; 7e502328
	v_mac_f32_e32 v56, v20, v41                                 ; 2c705314
	v_mac_f32_e32 v60, v24, v59                                 ; 2c787718
	v_mul_f32_e32 v62, v15, v62                                 ; 0a7c7d0f
	v_mac_f32_e32 v62, v14, v33                                 ; 2c7c430e
	v_mac_f32_e32 v62, v13, v37                                 ; 2c7c4b0d
	v_mac_f32_e32 v62, v12, v40                                 ; 2c7c510c
	v_mul_f32_e32 v62, v62, v51                                 ; 0a7c673e
	v_mac_f32_e32 v62, v60, v35                                 ; 2c7c473c
	v_mac_f32_e32 v62, v56, v48                                 ; 2c7c6138
	v_mac_f32_e32 v62, v53, v44                                 ; 2c7c5935
	v_mac_f32_e32 v9, v32, v62                                  ; 2c127d20
	s_cbranch_scc0 BB102                                        ; bf8400d8
BB85:
	s_add_u32 s5, s16, 6                                        ; 80058610
	s_mul_i32 s5, s5, s3                                        ; 92050305
	s_add_u32 s5, s19, s5                                       ; 80050513
	v_add_u32_e32 v32, s5, v0                                   ; 68400005
	v_lshlrev_b32_e32 v33, 4, v32                               ; 24424084
	v_lshl_add_u32 v32, v32, 7, v33                             ; d1fd0020 04850f20
	v_add_u32_e32 v35, 4, v32                                   ; 68464084
	v_add_u32_e32 v40, 16, v32                                  ; 68504090
	v_add_u32_e32 v37, v36, v35                                 ; 684a4724
	v_add_u32_e32 v38, v35, v34                                 ; 684c4523
	v_add_u32_e32 v35, v35, v39                                 ; 68464f23
	v_add_u32_e32 v41, v40, v4                                  ; 68520928
	v_add_u32_e32 v40, v40, v42                                 ; 68505528
	buffer_load_dword v32, v32, s[20:23], 0 offen               ; e0501000 80052020
	buffer_load_dwordx2 v[44:45], v37, s[20:23], 0 offen        ; e0541000 80052c25
	buffer_load_ushort v35, v35, s[20:23], 0 offen              ; e0481000 80052323
	buffer_load_dword v41, v41, s[20:23], 0 offen               ; e0501000 80052929
	buffer_load_dword v40, v40, s[20:23], 0 offen               ; e0501000 80052828
	s_mov_b32 s18, 0xf0f0f0f                                    ; be9200ff 0f0f0f0f
	s_cmp_lt_u32 7, s4                                          ; bf0a0487
	s_waitcnt vmcnt(4)                                          ; bf8c3f74
	v_cvt_f32_f16_sdwa v43, v32 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e5616f9 00050620
	v_cvt_f32_f16_e32 v32, v32                                  ; 7e401720
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_alignbyte_b32 v44, v45, v44, v38                          ; d1cf002c 049a592d
	v_alignbyte_b32 v45, v45, v45, v38                          ; d1cf002d 049a5b2d
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_lshl_or_b32 v35, v35, 12, v35                             ; d2000023 048d1923
	v_mov_b32_sdwa v44, v45 dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_0 ; 7e5802f9 0004152d
	v_and_b32_e32 v45, 0xc0c0c0c0, v44                          ; 265a58ff c0c0c0c0
	v_and_b32_e32 v44, 0x3f3f3f3f, v44                          ; 265858ff 3f3f3f3f
	v_lshrrev_b32_e32 v45, 2, v45                               ; 205a5a82
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v52, s18, v41                                 ; 26685212
	v_cvt_f32_ubyte3_e32 v46, v44                               ; 7e5c292c
	v_cvt_f32_ubyte2_e32 v47, v44                               ; 7e5e272c
	v_cvt_f32_ubyte1_e32 v48, v44                               ; 7e60252c
	v_cvt_f32_ubyte0_e32 v44, v44                               ; 7e58232c
	v_and_or_b32 v35, s18, v35, v45                             ; d2010023 04b64612
	v_cvt_f32_ubyte3_e32 v53, v52                               ; 7e6a2934
	v_cvt_f32_ubyte2_e32 v54, v52                               ; 7e6c2734
	v_cvt_f32_ubyte1_e32 v55, v52                               ; 7e6e2534
	v_cvt_f32_ubyte0_e32 v52, v52                               ; 7e682334
	v_cvt_f32_ubyte1_e32 v51, v35                               ; 7e662523
	v_cvt_f32_ubyte3_e32 v49, v35                               ; 7e622923
	v_cvt_f32_ubyte2_e32 v50, v35                               ; 7e642723
	v_cvt_f32_ubyte0_e32 v35, v35                               ; 7e462323
	v_mul_f32_e32 v53, v19, v53                                 ; 0a6a6b13
	v_lshrrev_b32_e32 v41, 4, v41                               ; 20525284
	v_mul_f32_e32 v49, v31, v49                                 ; 0a62631f
	v_mac_f32_e32 v53, v18, v54                                 ; 2c6a6d12
	v_and_b32_e32 v41, s18, v41                                 ; 26525212
	v_mac_f32_e32 v49, v30, v50                                 ; 2c62651e
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v59, s18, v40                                 ; 26765012
	v_mac_f32_e32 v53, v17, v55                                 ; 2c6a6f11
	v_cvt_f32_ubyte3_e32 v56, v41                               ; 7e702929
	v_cvt_f32_ubyte2_e32 v57, v41                               ; 7e722729
	v_cvt_f32_ubyte1_e32 v58, v41                               ; 7e742529
	v_cvt_f32_ubyte0_e32 v41, v41                               ; 7e522329
	v_mac_f32_e32 v49, v29, v46                                 ; 2c625d1d
	v_cvt_f32_ubyte2_e32 v61, v59                               ; 7e7a273b
	v_cvt_f32_ubyte3_e32 v60, v59                               ; 7e78293b
	v_cvt_f32_ubyte1_e32 v62, v59                               ; 7e7c253b
	v_mac_f32_e32 v53, v16, v52                                 ; 2c6a6910
	v_mul_f32_e32 v56, v23, v56                                 ; 0a707117
	v_cvt_f32_ubyte0_e32 v59, v59                               ; 7e76233b
	v_lshrrev_b32_e32 v40, 4, v40                               ; 20505084
	v_mac_f32_e32 v49, v28, v47                                 ; 2c625f1c
	v_mul_f32_e32 v60, v27, v60                                 ; 0a78791b
	v_mac_f32_e32 v56, v22, v57                                 ; 2c707316
	v_and_b32_e32 v40, s18, v40                                 ; 26505012
	v_mad_f32 v10, -v43, v49, v10                               ; d1c1000a 242a632b
	v_mac_f32_e32 v60, v26, v61                                 ; 2c787b1a
	v_mac_f32_e32 v56, v21, v58                                 ; 2c707515
	v_cvt_f32_ubyte1_e32 v37, v40                               ; 7e4a2528
	v_cvt_f32_ubyte2_e32 v33, v40                               ; 7e422728
	v_mac_f32_e32 v60, v25, v62                                 ; 2c787d19
	v_cvt_f32_ubyte3_e32 v62, v40                               ; 7e7c2928
	v_cvt_f32_ubyte0_e32 v40, v40                               ; 7e502328
	v_mac_f32_e32 v56, v20, v41                                 ; 2c705314
	v_mac_f32_e32 v60, v24, v59                                 ; 2c787718
	v_mul_f32_e32 v62, v15, v62                                 ; 0a7c7d0f
	v_mac_f32_e32 v62, v14, v33                                 ; 2c7c430e
	v_mac_f32_e32 v62, v13, v37                                 ; 2c7c4b0d
	v_mac_f32_e32 v62, v12, v40                                 ; 2c7c510c
	v_mul_f32_e32 v62, v62, v51                                 ; 0a7c673e
	v_mac_f32_e32 v62, v60, v35                                 ; 2c7c473c
	v_mac_f32_e32 v62, v56, v48                                 ; 2c7c6138
	v_mac_f32_e32 v62, v53, v44                                 ; 2c7c5935
	v_mac_f32_e32 v10, v32, v62                                 ; 2c147d20
	s_cbranch_scc0 BB102                                        ; bf84006c
BB86:
	s_add_u32 s5, s16, 7                                        ; 80058710
	s_mul_i32 s5, s5, s3                                        ; 92050305
	s_add_u32 s5, s19, s5                                       ; 80050513
	v_add_u32_e32 v32, s5, v0                                   ; 68400005
	v_lshlrev_b32_e32 v33, 4, v32                               ; 24424084
	v_lshl_add_u32 v32, v32, 7, v33                             ; d1fd0020 04850f20
	v_add_u32_e32 v35, 4, v32                                   ; 68464084
	v_add_u32_e32 v37, 16, v32                                  ; 684a4090
	v_add_u32_e32 v36, v36, v35                                 ; 68484724
	v_add_u32_e32 v34, v35, v34                                 ; 68444523
	v_add_u32_e32 v35, v35, v39                                 ; 68464f23
	v_add_u32_e32 v38, v37, v4                                  ; 684c0925
	v_add_u32_e32 v37, v37, v42                                 ; 684a5525
	buffer_load_dword v32, v32, s[20:23], 0 offen               ; e0501000 80052020
	buffer_load_dwordx2 v[40:41], v36, s[20:23], 0 offen        ; e0541000 80052824
	buffer_load_ushort v35, v35, s[20:23], 0 offen              ; e0481000 80052323
	buffer_load_dword v38, v38, s[20:23], 0 offen               ; e0501000 80052626
	buffer_load_dword v37, v37, s[20:23], 0 offen               ; e0501000 80052525
	s_mov_b32 s18, 0xf0f0f0f                                    ; be9200ff 0f0f0f0f
	s_waitcnt vmcnt(4)                                          ; bf8c3f74
	v_cvt_f32_f16_sdwa v39, v32 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e4e16f9 00050620
	v_cvt_f32_f16_e32 v32, v32                                  ; 7e401720
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_alignbyte_b32 v40, v41, v40, v34                          ; d1cf0028 048a5129
	v_alignbyte_b32 v41, v41, v41, v34                          ; d1cf0029 048a5329
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_lshl_or_b32 v35, v35, 12, v35                             ; d2000023 048d1923
	v_mov_b32_sdwa v40, v41 dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_0 ; 7e5002f9 00041529
	v_and_b32_e32 v41, 0xc0c0c0c0, v40                          ; 265250ff c0c0c0c0
	v_and_b32_e32 v40, 0x3f3f3f3f, v40                          ; 265050ff 3f3f3f3f
	v_lshrrev_b32_e32 v41, 2, v41                               ; 20525282
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v48, s18, v38                                 ; 26604c12
	v_cvt_f32_ubyte3_e32 v42, v40                               ; 7e542928
	v_cvt_f32_ubyte2_e32 v43, v40                               ; 7e562728
	v_cvt_f32_ubyte1_e32 v44, v40                               ; 7e582528
	v_cvt_f32_ubyte0_e32 v40, v40                               ; 7e502328
	v_and_or_b32 v35, s18, v35, v41                             ; d2010023 04a64612
	v_cvt_f32_ubyte3_e32 v49, v48                               ; 7e622930
	v_cvt_f32_ubyte2_e32 v50, v48                               ; 7e642730
	v_cvt_f32_ubyte1_e32 v51, v48                               ; 7e662530
	v_cvt_f32_ubyte0_e32 v48, v48                               ; 7e602330
	v_cvt_f32_ubyte3_e32 v45, v35                               ; 7e5a2923
	v_cvt_f32_ubyte2_e32 v46, v35                               ; 7e5c2723
	v_cvt_f32_ubyte1_e32 v47, v35                               ; 7e5e2523
	v_cvt_f32_ubyte0_e32 v35, v35                               ; 7e462323
	v_mul_f32_e32 v19, v19, v49                                 ; 0a266313
	v_lshrrev_b32_e32 v38, 4, v38                               ; 204c4c84
	v_mul_f32_e32 v31, v31, v45                                 ; 0a3e5b1f
	v_mac_f32_e32 v19, v18, v50                                 ; 2c266512
	v_and_b32_e32 v38, s18, v38                                 ; 264c4c12
	v_mac_f32_e32 v31, v30, v46                                 ; 2c3e5d1e
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v55, s18, v37                                 ; 266e4a12
	v_mac_f32_e32 v19, v17, v51                                 ; 2c266711
	v_cvt_f32_ubyte3_e32 v52, v38                               ; 7e682926
	v_cvt_f32_ubyte2_e32 v53, v38                               ; 7e6a2726
	v_cvt_f32_ubyte1_e32 v54, v38                               ; 7e6c2526
	v_cvt_f32_ubyte0_e32 v38, v38                               ; 7e4c2326
	v_mac_f32_e32 v31, v29, v42                                 ; 2c3e551d
	v_cvt_f32_ubyte2_e32 v57, v55                               ; 7e722737
	v_cvt_f32_ubyte3_e32 v56, v55                               ; 7e702937
	v_cvt_f32_ubyte1_e32 v58, v55                               ; 7e742537
	v_mac_f32_e32 v19, v16, v48                                 ; 2c266110
	v_mul_f32_e32 v23, v23, v52                                 ; 0a2e6917
	v_cvt_f32_ubyte0_e32 v55, v55                               ; 7e6e2337
	v_lshrrev_b32_e32 v37, 4, v37                               ; 204a4a84
	v_mac_f32_e32 v31, v28, v43                                 ; 2c3e571c
	v_mul_f32_e32 v27, v27, v56                                 ; 0a36711b
	v_mac_f32_e32 v23, v22, v53                                 ; 2c2e6b16
	v_and_b32_e32 v37, s18, v37                                 ; 264a4a12
	v_mad_f32 v11, -v39, v31, v11                               ; d1c1000b 242e3f27
	v_mac_f32_e32 v27, v26, v57                                 ; 2c36731a
	v_mac_f32_e32 v23, v21, v54                                 ; 2c2e6d15
	v_cvt_f32_ubyte2_e32 v60, v37                               ; 7e782725
	v_cvt_f32_ubyte1_e32 v61, v37                               ; 7e7a2525
	v_cvt_f32_ubyte3_e32 v59, v37                               ; 7e762925
	v_cvt_f32_ubyte0_e32 v37, v37                               ; 7e4a2325
	v_mac_f32_e32 v27, v25, v58                                 ; 2c367519
	v_mac_f32_e32 v23, v20, v38                                 ; 2c2e4d14
	v_mul_f32_e32 v15, v15, v59                                 ; 0a1e770f
	v_mac_f32_e32 v27, v24, v55                                 ; 2c366f18
	v_mac_f32_e32 v15, v14, v60                                 ; 2c1e790e
	v_mac_f32_e32 v15, v13, v61                                 ; 2c1e7b0d
	v_mac_f32_e32 v15, v12, v37                                 ; 2c1e4b0c
	v_mul_f32_e32 v15, v15, v47                                 ; 0a1e5f0f
	v_mac_f32_e32 v15, v27, v35                                 ; 2c1e471b
	v_mac_f32_e32 v15, v23, v44                                 ; 2c1e5917
	v_mac_f32_e32 v15, v19, v40                                 ; 2c1e5113
	v_mac_f32_e32 v11, v32, v15                                 ; 2c161f20
	s_branch BB102                                              ; bf820001
BB101:
	s_mov_b32 s9, src_scc                                       ; be8900fd
BB102:
	v_add_u32_e32 v0, 4, v0                                     ; 68000084
	s_mov_b64 s[20:21], exec                                    ; be94017e
	v_cmpx_le_u32_e32 vcc, s3, v0                               ; 7db60003
BB103:
	s_andn2_b64 s[20:21], s[20:21], exec                        ; 89947e14
	s_cbranch_scc1 BB107                                        ; bf85fc6e
BB108:
	s_mov_b64 exec, s[10:11]                                    ; befe010a
BB110:
	s_andn2_b64 exec, -1, exec                                  ; 89fe7ec1
	s_cbranch_execz BB113                                       ; bf880008
BB111:
	v_mov_b32_e32 v3, 0                                         ; 7e060280
	v_mov_b32_e32 v5, 0                                         ; 7e0a0280
	v_mov_b32_e32 v6, 0                                         ; 7e0c0280
	v_mov_b32_e32 v7, 0                                         ; 7e0e0280
	v_mov_b32_e32 v8, 0                                         ; 7e100280
	v_mov_b32_e32 v9, 0                                         ; 7e120280
	v_mov_b32_e32 v10, 0                                        ; 7e140280
	v_mov_b32_e32 v11, 0                                        ; 7e160280
BB113:
	s_mov_b64 exec, -1                                          ; befe01c1
	s_cmp_lg_i32 s4, 0                                          ; bf018004
	s_cselect_b64 s[0:1], -1, 0                                 ; 858080c1
	s_cbranch_scc0 BB137                                        ; bf8400d6
BB114:
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
	s_cbranch_scc0 BB135                                        ; bf8400bb
BB115:
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
	s_cbranch_scc0 BB133                                        ; bf8400a0
BB116:
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
	s_cbranch_scc0 BB131                                        ; bf840085
BB117:
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
	s_cbranch_scc0 BB129                                        ; bf84006a
BB118:
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
	s_cbranch_scc0 BB127                                        ; bf84004f
BB119:
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
	s_cbranch_scc0 BB125                                        ; bf840034
BB120:
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
	s_cbranch_scc0 BB123                                        ; bf840019
BB121:
	s_or_saveexec_b64 s[14:15], -1                              ; be8e21c1
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
	v_mov_b32_e32 v11, s13                                      ; 7e16020d
BB123:
	v_mov_b32_e32 v10, s12                                      ; 7e14020c
BB125:
	v_mov_b32_e32 v9, s11                                       ; 7e12020b
BB127:
	v_mov_b32_e32 v8, s10                                       ; 7e10020a
BB129:
	v_mov_b32_e32 v7, s9                                        ; 7e0e0209
BB131:
	v_mov_b32_e32 v6, s6                                        ; 7e0c0206
BB133:
	v_mov_b32_e32 v5, s5                                        ; 7e0a0205
BB135:
	v_mov_b32_e32 v3, s3                                        ; 7e060203
BB137:
	s_mov_b64 s[10:11], 1                                       ; be8a0181
	s_and_b64 exec, s[0:1], s[10:11]                            ; 86fe0a00
	s_cbranch_execz BB215                                       ; bf8800ff
BB138:
	s_bitcmp1_b32 s8, 0                                         ; bf0d8008
	s_cbranch_scc0 BB140                                        ; bf84000e
BB139:
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
	s_branch BB141                                              ; bf820001
BB140:
	s_mov_b32 s1, src_scc                                       ; be8100fd
BB141:
	s_bitcmp1_b32 s8, 1                                         ; bf0d8108
	s_cbranch_scc0 BB143                                        ; bf84000e
BB142:
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
	s_branch BB144                                              ; bf820001
BB143:
	s_mov_b32 s3, src_scc                                       ; be8300fd
BB144:
	s_mov_b32 s0, s3                                            ; be800003
	s_movk_i32 s3, 0x8000                                       ; b0038000
	s_load_dwordx4 s[8:11], s[2:3], 0x20                        ; c00a0201 00000020
	s_mul_i32 s7, s7, s17                                       ; 92071107
	s_add_u32 s7, s7, s16                                       ; 80071007
	s_lshl_b32 s7, s7, 2                                        ; 8e078207
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_store_dword v3, off, s[8:11], s7                     ; e0700000 07020380
	s_cmp_lt_u32 1, s4                                          ; bf0a0481
	s_cbranch_scc0 BB215                                        ; bf8400d1
BB145:
	s_cmp_lg_i32 s1, 0                                          ; bf018001
	s_cbranch_scc0 BB147                                        ; bf84000a
BB146:
	s_load_dwordx4 s[12:15], s[2:3], 0x30                       ; c00a0301 00000030
	s_mov_b32 s1, src_scc                                       ; be8100fd
	s_add_u32 s5, s7, 4                                         ; 80058407
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s5, s[12:15], s5                        ; c0200146 00000005
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v5, s5, v5                                    ; 020a0a05
	s_branch BB148                                              ; bf820001
BB147:
	s_mov_b32 s1, src_scc                                       ; be8100fd
BB148:
	s_cmp_lg_i32 s0, 0                                          ; bf018000
	s_cbranch_scc0 BB150                                        ; bf84000a
BB149:
	s_load_dwordx4 s[12:15], s[2:3], 0x40                       ; c00a0301 00000040
	s_mov_b32 s0, src_scc                                       ; be8000fd
	s_add_u32 s5, s7, 4                                         ; 80058407
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s5, s[12:15], s5                        ; c0200146 00000005
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v5, s5, v5                                    ; 020a0a05
	s_branch BB151                                              ; bf820001
BB150:
	s_mov_b32 s0, src_scc                                       ; be8000fd
BB151:
	s_add_u32 s5, s7, 4                                         ; 80058407
	buffer_store_dword v5, off, s[8:11], s5                     ; e0700000 05020580
	s_cmp_lt_u32 2, s4                                          ; bf0a0482
	s_cbranch_scc0 BB215                                        ; bf8400b2
BB152:
	s_cmp_lg_i32 s1, 0                                          ; bf018001
	s_cbranch_scc0 BB154                                        ; bf84000a
BB153:
	s_load_dwordx4 s[12:15], s[2:3], 0x30                       ; c00a0301 00000030
	s_mov_b32 s1, src_scc                                       ; be8100fd
	s_add_u32 s5, s7, 8                                         ; 80058807
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s5, s[12:15], s5                        ; c0200146 00000005
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v6, s5, v6                                    ; 020c0c05
	s_branch BB155                                              ; bf820001
BB154:
	s_mov_b32 s1, src_scc                                       ; be8100fd
BB155:
	s_cmp_lg_i32 s0, 0                                          ; bf018000
	s_cbranch_scc0 BB157                                        ; bf84000a
BB156:
	s_load_dwordx4 s[12:15], s[2:3], 0x40                       ; c00a0301 00000040
	s_mov_b32 s0, src_scc                                       ; be8000fd
	s_add_u32 s5, s7, 8                                         ; 80058807
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s5, s[12:15], s5                        ; c0200146 00000005
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v6, s5, v6                                    ; 020c0c05
	s_branch BB158                                              ; bf820001
BB157:
	s_mov_b32 s0, src_scc                                       ; be8000fd
BB158:
	s_add_u32 s5, s7, 8                                         ; 80058807
	buffer_store_dword v6, off, s[8:11], s5                     ; e0700000 05020680
	s_cmp_lt_u32 3, s4                                          ; bf0a0483
	s_cbranch_scc0 BB215                                        ; bf840093
BB159:
	s_cmp_lg_i32 s1, 0                                          ; bf018001
	s_cbranch_scc0 BB161                                        ; bf84000a
BB160:
	s_load_dwordx4 s[12:15], s[2:3], 0x30                       ; c00a0301 00000030
	s_mov_b32 s1, src_scc                                       ; be8100fd
	s_add_u32 s5, s7, 12                                        ; 80058c07
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s5, s[12:15], s5                        ; c0200146 00000005
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v7, s5, v7                                    ; 020e0e05
	s_branch BB162                                              ; bf820001
BB161:
	s_mov_b32 s1, src_scc                                       ; be8100fd
BB162:
	s_cmp_lg_i32 s0, 0                                          ; bf018000
	s_cbranch_scc0 BB164                                        ; bf84000a
BB163:
	s_load_dwordx4 s[12:15], s[2:3], 0x40                       ; c00a0301 00000040
	s_mov_b32 s0, src_scc                                       ; be8000fd
	s_add_u32 s5, s7, 12                                        ; 80058c07
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s5, s[12:15], s5                        ; c0200146 00000005
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v7, s5, v7                                    ; 020e0e05
	s_branch BB165                                              ; bf820001
BB164:
	s_mov_b32 s0, src_scc                                       ; be8000fd
BB165:
	s_add_u32 s5, s7, 12                                        ; 80058c07
	buffer_store_dword v7, off, s[8:11], s5                     ; e0700000 05020780
	s_cmp_lt_u32 4, s4                                          ; bf0a0484
	s_cbranch_scc0 BB215                                        ; bf840074
BB166:
	s_cmp_lg_i32 s1, 0                                          ; bf018001
	s_cbranch_scc0 BB168                                        ; bf84000a
BB167:
	s_load_dwordx4 s[12:15], s[2:3], 0x30                       ; c00a0301 00000030
	s_mov_b32 s1, src_scc                                       ; be8100fd
	s_add_u32 s5, s7, 16                                        ; 80059007
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s5, s[12:15], s5                        ; c0200146 00000005
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v8, s5, v8                                    ; 02101005
	s_branch BB169                                              ; bf820001
BB168:
	s_mov_b32 s1, src_scc                                       ; be8100fd
BB169:
	s_cmp_lg_i32 s0, 0                                          ; bf018000
	s_cbranch_scc0 BB171                                        ; bf84000a
BB170:
	s_load_dwordx4 s[12:15], s[2:3], 0x40                       ; c00a0301 00000040
	s_mov_b32 s0, src_scc                                       ; be8000fd
	s_add_u32 s5, s7, 16                                        ; 80059007
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s5, s[12:15], s5                        ; c0200146 00000005
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v8, s5, v8                                    ; 02101005
	s_branch BB172                                              ; bf820001
BB171:
	s_mov_b32 s0, src_scc                                       ; be8000fd
BB172:
	s_add_u32 s5, s7, 16                                        ; 80059007
	buffer_store_dword v8, off, s[8:11], s5                     ; e0700000 05020880
	s_cmp_lt_u32 5, s4                                          ; bf0a0485
	s_cbranch_scc0 BB215                                        ; bf840055
BB173:
	s_cmp_lg_i32 s1, 0                                          ; bf018001
	s_cbranch_scc0 BB175                                        ; bf84000a
BB174:
	s_load_dwordx4 s[12:15], s[2:3], 0x30                       ; c00a0301 00000030
	s_mov_b32 s1, src_scc                                       ; be8100fd
	s_add_u32 s5, s7, 20                                        ; 80059407
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s5, s[12:15], s5                        ; c0200146 00000005
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v9, s5, v9                                    ; 02121205
	s_branch BB176                                              ; bf820001
BB175:
	s_mov_b32 s1, src_scc                                       ; be8100fd
BB176:
	s_cmp_lg_i32 s0, 0                                          ; bf018000
	s_cbranch_scc0 BB178                                        ; bf84000a
BB177:
	s_load_dwordx4 s[12:15], s[2:3], 0x40                       ; c00a0301 00000040
	s_mov_b32 s0, src_scc                                       ; be8000fd
	s_add_u32 s5, s7, 20                                        ; 80059407
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s5, s[12:15], s5                        ; c0200146 00000005
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v9, s5, v9                                    ; 02121205
	s_branch BB179                                              ; bf820001
BB178:
	s_mov_b32 s0, src_scc                                       ; be8000fd
BB179:
	s_add_u32 s5, s7, 20                                        ; 80059407
	buffer_store_dword v9, off, s[8:11], s5                     ; e0700000 05020980
	s_cmp_lt_u32 6, s4                                          ; bf0a0486
	s_cbranch_scc0 BB215                                        ; bf840036
BB180:
	s_cmp_lg_i32 s1, 0                                          ; bf018001
	s_cbranch_scc0 BB182                                        ; bf84000a
BB181:
	s_load_dwordx4 s[12:15], s[2:3], 0x30                       ; c00a0301 00000030
	s_mov_b32 s1, src_scc                                       ; be8100fd
	s_add_u32 s5, s7, 24                                        ; 80059807
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s5, s[12:15], s5                        ; c0200146 00000005
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v10, s5, v10                                  ; 02141405
	s_branch BB183                                              ; bf820001
BB182:
	s_mov_b32 s1, src_scc                                       ; be8100fd
BB183:
	s_cmp_lg_i32 s0, 0                                          ; bf018000
	s_cbranch_scc0 BB185                                        ; bf84000a
BB184:
	s_load_dwordx4 s[12:15], s[2:3], 0x40                       ; c00a0301 00000040
	s_mov_b32 s0, src_scc                                       ; be8000fd
	s_add_u32 s5, s7, 24                                        ; 80059807
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s5, s[12:15], s5                        ; c0200146 00000005
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v10, s5, v10                                  ; 02141405
	s_branch BB186                                              ; bf820001
BB185:
	s_mov_b32 s0, src_scc                                       ; be8000fd
BB186:
	s_add_u32 s5, s7, 24                                        ; 80059807
	buffer_store_dword v10, off, s[8:11], s5                    ; e0700000 05020a80
	s_cmp_lt_u32 7, s4                                          ; bf0a0487
	s_cbranch_scc0 BB215                                        ; bf840017
BB187:
	s_cmp_lg_i32 s1, 0                                          ; bf018001
	s_cbranch_scc0 BB190                                        ; bf840008
BB188:
	s_load_dwordx4 s[12:15], s[2:3], 0x30                       ; c00a0301 00000030
	s_add_u32 s1, s7, 28                                        ; 80019c07
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s1, s[12:15], s1                        ; c0200046 00000001
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v11, s1, v11                                  ; 02161601
BB190:
	s_cmp_lg_i32 s0, 0                                          ; bf018000
	s_cbranch_scc0 BB193                                        ; bf840008
BB191:
	s_load_dwordx4 s[0:3], s[2:3], 0x40                         ; c00a0001 00000040
	s_add_u32 s4, s7, 28                                        ; 80049c07
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s4, s[0:3], s4                          ; c0200100 00000004
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v11, s4, v11                                  ; 02161604
BB193:
	s_add_u32 s7, s7, 28                                        ; 80079c07
	buffer_store_dword v11, off, s[8:11], s7                    ; e0700000 07020b80
BB215:
	s_endpgm                                                    ; bf810000
