BB0:
	s_load_dword s0, s[14:15], 0x0                              ; c0020007 00000000
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_mul_i32 s0, s0, s18                                       ; 92001200
	s_add_u32 s16, s16, s0                                      ; 80100010
	s_lshl_b32 s16, s16, 3                                      ; 8e108310
	s_add_u32 s1, s16, 8                                        ; 80018810
	s_cmp_ge_u32 s4, s1                                         ; bf090104
	s_cbranch_scc0 BB66                                         ; bf840539
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
	v_mov_b32_e32 v8, 0                                         ; 7e100280
	v_sub_u32_e32 v1, v2, v1                                    ; 6a020302
	v_bfe_u32 v3, v2, 2, 1                                      ; d1c80003 02050502
	v_lshrrev_b32_e32 v2, 3, v2                                 ; 20040483
	v_mov_b32_e32 v9, 0                                         ; 7e120280
	v_mov_b32_e32 v10, 0                                        ; 7e140280
	v_mov_b32_e32 v11, 0                                        ; 7e160280
	v_lshl_add_u32 v1, v1, 1, v3                                ; d1fd0001 040d0301
	v_mov_b32_e32 v3, 0                                         ; 7e060280
	v_lshlrev_b32_e32 v1, 2, v1                                 ; 24020282
	v_lshl_add_u32 v4, v2, 5, v1                                ; d1fd0004 04050b02
	v_lshl_add_u32 v1, v2, 6, v1                                ; d1fd0001 04050d02
	v_lshlrev_b32_e32 v2, 4, v2                                 ; 24040484
	s_branch BB5                                                ; bf82030f
BB10:
	s_mov_b64 exec, s[0:1]                                      ; befe0100
	s_mov_b32 s0, s2                                            ; be800002
	s_movk_i32 s1, 0x8000                                       ; b0018000
	s_load_dwordx8 s[24:31], s[0:1], 0x0                        ; c00e0600 00000000
	s_mul_i32 s0, s6, s17                                       ; 92001106
	v_lshl_add_u32 v12, v0, 8, v1                               ; d1fd000c 04051100
	v_add_u32_e32 v13, s0, v12                                  ; 681a1800
	v_add_u32_e32 v12, 0x80, v12                                ; 681818ff 00000080
	v_lshrrev_b32_e32 v13, 2, v13                               ; 201a1a82
	v_add_u32_e32 v12, s0, v12                                  ; 68181800
	v_lshlrev_b32_e32 v13, 4, v13                               ; 241a1a84
	v_lshrrev_b32_e32 v12, 2, v12                               ; 20181882
	v_lshlrev_b32_e32 v12, 4, v12                               ; 24181884
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_load_dwordx4 v[16:19], v13, s[28:31], 0 offen        ; e05c1000 8007100d
	buffer_load_dwordx4 v[20:23], v13, s[28:31], 0 offen offset:128 ; e05c1080 8007140d
	buffer_load_dwordx4 v[24:27], v12, s[28:31], 0 offen        ; e05c1000 8007180c
	buffer_load_dwordx4 v[12:15], v12, s[28:31], 0 offen offset:128 ; e05c1080 80070c0c
	s_mul_i32 s1, s16, s3                                       ; 92010310
	v_add_u32_e32 v32, 64, v4                                   ; 684008c0
	s_add_u32 s1, s18, s1                                       ; 80010112
	s_add_u32 s4, s16, 1                                        ; 80048110
	v_add_u32_e32 v28, s1, v0                                   ; 68380001
	s_mul_i32 s4, s4, s3                                        ; 92040304
	v_lshlrev_b32_e32 v29, 4, v28                               ; 243a3884
	s_add_u32 s4, s18, s4                                       ; 80040412
	s_add_u32 s5, s16, 2                                        ; 80058210
	v_lshl_add_u32 v28, v28, 7, v29                             ; d1fd001c 04750f1c
	v_add_u32_e32 v33, s4, v0                                   ; 68420004
	s_mul_i32 s5, s5, s3                                        ; 92050305
	v_add_u32_e32 v30, 16, v28                                  ; 683c3890
	v_lshlrev_b32_e32 v34, 4, v33                               ; 24444284
	s_add_u32 s5, s18, s5                                       ; 80050512
	s_add_u32 s9, s16, 3                                        ; 80098310
	v_add_u32_e32 v31, v30, v4                                  ; 683e091e
	v_add_u32_e32 v30, v30, v32                                 ; 683c411e
	v_lshl_add_u32 v33, v33, 7, v34                             ; d1fd0021 04890f21
	v_add_u32_e32 v37, s5, v0                                   ; 684a0005
	s_mul_i32 s9, s9, s3                                        ; 92090309
	v_add_u32_e32 v35, 16, v33                                  ; 68464290
	v_lshlrev_b32_e32 v38, 4, v37                               ; 244c4a84
	s_add_u32 s9, s18, s9                                       ; 80090912
	v_add_u32_e32 v36, v35, v4                                  ; 68480923
	v_add_u32_e32 v35, v35, v32                                 ; 68464123
	v_lshl_add_u32 v37, v37, 7, v38                             ; d1fd0025 04990f25
	v_add_u32_e32 v41, s9, v0                                   ; 68520009
	v_add_u32_e32 v39, 16, v37                                  ; 684e4a90
	v_lshlrev_b32_e32 v42, 4, v41                               ; 24545284
	v_add_u32_e32 v40, v39, v4                                  ; 68500927
	v_add_u32_e32 v39, v39, v32                                 ; 684e4127
	buffer_load_dwordx4 v[48:51], v28, s[24:27], 0 offen        ; e05c1000 8006301c
	buffer_load_dword v31, v31, s[24:27], 0 offen               ; e0501000 80061f1f
	buffer_load_dword v30, v30, s[24:27], 0 offen               ; e0501000 80061e1e
	buffer_load_dwordx4 v[52:55], v33, s[24:27], 0 offen        ; e05c1000 80063421
	buffer_load_dword v36, v36, s[24:27], 0 offen               ; e0501000 80062424
	buffer_load_dword v35, v35, s[24:27], 0 offen               ; e0501000 80062323
	buffer_load_dwordx4 v[56:59], v37, s[24:27], 0 offen        ; e05c1000 80063825
	buffer_load_dword v40, v40, s[24:27], 0 offen               ; e0501000 80062828
	buffer_load_dword v39, v39, s[24:27], 0 offen               ; e0501000 80062727
	v_lshl_add_u32 v41, v41, 7, v42                             ; d1fd0029 04a90f29
	v_add_u32_e32 v43, 16, v41                                  ; 68565290
	v_add_u32_e32 v44, v43, v4                                  ; 6858092b
	v_add_u32_e32 v43, v43, v32                                 ; 6856412b
	v_mov_b32_e32 v28, v44                                      ; 7e38032c
	buffer_load_dwordx4 v[44:47], v41, s[24:27], 0 offen        ; e05c1000 80062c29
	buffer_load_dword v28, v28, s[24:27], 0 offen               ; e0501000 80061c1c
	buffer_load_dword v43, v43, s[24:27], 0 offen               ; e0501000 80062b2b
	s_bitreplicate_b64_b32 vcc, 0xf0f0f0f                       ; beea37ff 0f0f0f0f
	s_mov_b32 s10, 0xf0f0f0f                                    ; be8a00ff 0f0f0f0f
	s_mov_b32 s11, 0xc0c0c0c0                                   ; be8b00ff c0c0c0c0
	s_mov_b32 s12, 0x3f3f3f3f                                   ; be8c00ff 3f3f3f3f
	s_add_u32 s13, s16, 4                                       ; 800d8410
	s_mul_i32 s13, s13, s3                                      ; 920d030d
	s_add_u32 s13, s18, s13                                     ; 800d0d12
	v_add_u32_e32 v29, s13, v0                                  ; 683a000d
	s_waitcnt vmcnt(15)                                         ; bf8c3f7f
	v_add_f32_e32 v33, v16, v17                                 ; 02422310
	s_waitcnt vmcnt(14)                                         ; bf8c3f7e
	v_add_f32_e32 v34, v20, v21                                 ; 02442b14
	v_add_f32_e32 v33, v33, v18                                 ; 02422521
	s_waitcnt vmcnt(13)                                         ; bf8c3f7d
	v_add_f32_e32 v37, v24, v25                                 ; 024a3318
	s_waitcnt vmcnt(12)                                         ; bf8c3f7c
	v_add_f32_e32 v38, v12, v13                                 ; 024c1b0c
	v_add_f32_e32 v34, v34, v22                                 ; 02442d22
	v_add_f32_e32 v33, v33, v19                                 ; 02422721
	v_add_f32_e32 v37, v37, v26                                 ; 024a3525
	v_add_f32_e32 v38, v38, v14                                 ; 024c1d26
	v_add_f32_e32 v34, v34, v23                                 ; 02442f22
	v_add_f32_e32 v37, v37, v27                                 ; 024a3725
	v_add_f32_e32 v38, v38, v15                                 ; 024c1f26
	s_waitcnt vmcnt(11)                                         ; bf8c3f7b
	v_bfe_u32 v51, v51, v2, 16                                  ; d1c80033 02420533
	v_cndmask_b32_sdwa v41, v49, v49, vcc dst_sel:WORD_0 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 005262f9 06051431
	v_cndmask_b32_sdwa v41, v50, v50, vcc dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 005264f9 06051532
	s_waitcnt vmcnt(10)                                         ; bf8c3f7a
	v_and_b32_e32 v49, s10, v31                                 ; 26623e0a
	v_lshrrev_b32_e32 v31, 4, v31                               ; 203e3e84
	v_lshl_or_b32 v51, v51, 12, v51                             ; d2000033 04cd1933
	v_and_b32_e32 v42, s11, v41                                 ; 2654520b
	v_cvt_f32_ubyte3_e32 v50, v49                               ; 7e642931
	v_cvt_f32_ubyte1_e32 v61, v49                               ; 7e7a2531
	v_cvt_f32_ubyte2_e32 v60, v49                               ; 7e782731
	v_cvt_f32_ubyte0_e32 v49, v49                               ; 7e622331
	v_and_b32_e32 v31, s10, v31                                 ; 263e3e0a
	v_lshrrev_b32_e32 v42, 2, v42                               ; 20545482
	v_mul_f32_e32 v50, v19, v50                                 ; 0a646513
	v_cvt_f32_ubyte3_e32 v62, v31                               ; 7e7c291f
	v_and_or_b32 v51, s10, v51, v42                             ; d2010033 04aa660a
	v_cvt_f32_ubyte2_e32 v42, v31                               ; 7e54271f
	v_mac_f32_e32 v50, v18, v60                                 ; 2c647912
	s_waitcnt vmcnt(9)                                          ; bf8c3f79
	v_and_b32_e32 v60, s10, v30                                 ; 26783c0a
	v_mul_f32_e32 v62, v23, v62                                 ; 0a7c7d17
	v_mac_f32_e32 v50, v17, v61                                 ; 2c647b11
	v_cvt_f32_ubyte3_e32 v61, v60                               ; 7e7a293c
	v_lshrrev_b32_e32 v30, 4, v30                               ; 203c3c84
	v_mac_f32_e32 v62, v22, v42                                 ; 2c7c5516
	v_cvt_f32_ubyte1_e32 v42, v60                               ; 7e54253c
	v_mac_f32_e32 v50, v16, v49                                 ; 2c646310
	v_cvt_f32_ubyte1_e32 v49, v31                               ; 7e62251f
	v_cvt_f32_ubyte0_e32 v31, v31                               ; 7e3e231f
	v_mul_f32_e32 v61, v27, v61                                 ; 0a7a7b1b
	v_and_b32_e32 v30, s10, v30                                 ; 263c3c0a
	v_mac_f32_e32 v62, v21, v49                                 ; 2c7c6315
	v_cvt_f32_ubyte3_e32 v49, v30                               ; 7e62291e
	v_mac_f32_e32 v62, v20, v31                                 ; 2c7c3f14
	v_cvt_f32_ubyte2_e32 v31, v60                               ; 7e3e273c
	v_cvt_f32_ubyte0_e32 v60, v60                               ; 7e78233c
	v_mul_f32_e32 v49, v15, v49                                 ; 0a62630f
	v_and_b32_e32 v41, s12, v41                                 ; 2652520c
	v_mac_f32_e32 v61, v26, v31                                 ; 2c7a3f1a
	v_cvt_f32_ubyte1_e32 v31, v30                               ; 7e3e251e
	v_mac_f32_e32 v61, v25, v42                                 ; 2c7a5519
	v_cvt_f32_ubyte3_e32 v42, v51                               ; 7e542933
	v_mac_f32_e32 v61, v24, v60                                 ; 2c7a7918
	v_cvt_f32_ubyte2_e32 v60, v30                               ; 7e78271e
	v_cvt_f32_ubyte0_e32 v30, v30                               ; 7e3c231e
	v_mul_f32_e32 v42, v38, v42                                 ; 0a545526
	v_mac_f32_e32 v49, v14, v60                                 ; 2c62790e
	v_cvt_f32_ubyte2_e32 v60, v51                               ; 7e782733
	v_mac_f32_e32 v49, v13, v31                                 ; 2c623f0d
	v_cvt_f32_ubyte2_e32 v31, v41                               ; 7e3e2729
	v_mac_f32_e32 v42, v37, v60                                 ; 2c547925
	v_cvt_f32_ubyte1_e32 v60, v51                               ; 7e782533
	v_cvt_f32_ubyte0_e32 v51, v51                               ; 7e662333
	v_mac_f32_e32 v49, v12, v30                                 ; 2c623d0c
	v_cvt_f32_ubyte3_e32 v30, v41                               ; 7e3c2929
	v_mul_f32_e32 v49, v49, v60                                 ; 0a627931
	v_mac_f32_e32 v42, v34, v30                                 ; 2c543d22
	v_mac_f32_e32 v49, v61, v51                                 ; 2c62673d
	v_cvt_f32_ubyte1_e32 v61, v41                               ; 7e7a2529
	v_cvt_f32_ubyte0_e32 v41, v41                               ; 7e522329
	v_mac_f32_e32 v42, v33, v31                                 ; 2c543f21
	v_mac_f32_e32 v49, v62, v61                                 ; 2c627b3e
	v_lshlrev_b32_e32 v62, 4, v29                               ; 247c3a84
	v_mac_f32_e32 v49, v50, v41                                 ; 2c625332
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_mov_b32_e32 v41, v28                                      ; 7e52031c
	v_lshl_add_u32 v29, v29, 7, v62                             ; d1fd001d 04f90f1d
	v_add_u32_e32 v62, 16, v29                                  ; 687c3a90
	v_add_u32_e32 v30, v62, v4                                  ; 683c093e
	v_add_u32_e32 v62, v62, v32                                 ; 687c413e
	v_mov_b32_e32 v50, v30                                      ; 7e64031e
	buffer_load_dwordx4 v[28:31], v29, s[24:27], 0 offen        ; e05c1000 80061c1d
	buffer_load_dword v50, v50, s[24:27], 0 offen               ; e0501000 80063232
	buffer_load_dword v62, v62, s[24:27], 0 offen               ; e0501000 80063e3e
	v_cvt_f32_f16_sdwa v51, v48 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e6616f9 00050630
	v_cvt_f32_f16_e32 v48, v48                                  ; 7e601730
	s_add_u32 s14, s16, 5                                       ; 800e8510
	v_bfe_u32 v55, v55, v2, 16                                  ; d1c80037 02420537
	v_cndmask_b32_sdwa v61, v53, v53, vcc dst_sel:WORD_0 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 007a6af9 06051435
	v_cndmask_b32_sdwa v61, v54, v54, vcc dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 007a6cf9 06051536
	v_mad_f32 v3, -v51, v42, v3                                 ; d1c10003 240e5533
	s_mul_i32 s14, s14, s3                                      ; 920e030e
	v_lshl_or_b32 v55, v55, 12, v55                             ; d2000037 04dd1937
	v_and_b32_e32 v42, s11, v61                                 ; 26547a0b
	v_mac_f32_e32 v3, v48, v49                                  ; 2c066330
	v_and_b32_e32 v48, s10, v36                                 ; 2660480a
	v_lshrrev_b32_e32 v36, 4, v36                               ; 20484884
	s_add_u32 s14, s18, s14                                     ; 800e0e12
	v_lshrrev_b32_e32 v42, 2, v42                               ; 20545482
	v_cvt_f32_ubyte3_e32 v49, v48                               ; 7e622930
	v_cvt_f32_ubyte1_e32 v53, v48                               ; 7e6a2530
	v_cvt_f32_ubyte2_e32 v51, v48                               ; 7e662730
	v_cvt_f32_ubyte0_e32 v48, v48                               ; 7e602330
	v_and_b32_e32 v36, s10, v36                                 ; 2648480a
	v_add_u32_e32 v60, s14, v0                                  ; 6878000e
	v_and_or_b32 v55, s10, v55, v42                             ; d2010037 04aa6e0a
	v_mul_f32_e32 v49, v19, v49                                 ; 0a626313
	v_cvt_f32_ubyte2_e32 v42, v36                               ; 7e542724
	v_cvt_f32_ubyte3_e32 v54, v36                               ; 7e6c2924
	v_mac_f32_e32 v49, v18, v51                                 ; 2c626712
	v_and_b32_e32 v51, s10, v35                                 ; 2666460a
	v_mul_f32_e32 v54, v23, v54                                 ; 0a6c6d17
	v_mac_f32_e32 v49, v17, v53                                 ; 2c626b11
	v_cvt_f32_ubyte3_e32 v53, v51                               ; 7e6a2933
	v_lshrrev_b32_e32 v35, 4, v35                               ; 20464684
	v_mac_f32_e32 v54, v22, v42                                 ; 2c6c5516
	v_cvt_f32_ubyte1_e32 v42, v51                               ; 7e542533
	v_mac_f32_e32 v49, v16, v48                                 ; 2c626110
	v_cvt_f32_ubyte1_e32 v48, v36                               ; 7e602524
	v_cvt_f32_ubyte0_e32 v36, v36                               ; 7e482324
	v_mul_f32_e32 v53, v27, v53                                 ; 0a6a6b1b
	v_and_b32_e32 v35, s10, v35                                 ; 2646460a
	v_mac_f32_e32 v54, v21, v48                                 ; 2c6c6115
	v_cvt_f32_ubyte3_e32 v48, v35                               ; 7e602923
	v_mac_f32_e32 v54, v20, v36                                 ; 2c6c4914
	v_cvt_f32_ubyte2_e32 v36, v51                               ; 7e482733
	v_cvt_f32_ubyte0_e32 v51, v51                               ; 7e662333
	v_mul_f32_e32 v48, v15, v48                                 ; 0a60610f
	v_and_b32_e32 v61, s12, v61                                 ; 267a7a0c
	v_mac_f32_e32 v53, v26, v36                                 ; 2c6a491a
	v_cvt_f32_ubyte1_e32 v36, v35                               ; 7e482523
	v_mac_f32_e32 v53, v25, v42                                 ; 2c6a5519
	v_cvt_f32_ubyte3_e32 v42, v55                               ; 7e542937
	v_mac_f32_e32 v53, v24, v51                                 ; 2c6a6718
	v_cvt_f32_ubyte2_e32 v51, v35                               ; 7e662723
	v_cvt_f32_ubyte0_e32 v35, v35                               ; 7e462323
	v_mul_f32_e32 v42, v38, v42                                 ; 0a545526
	v_mac_f32_e32 v48, v14, v51                                 ; 2c60670e
	v_cvt_f32_ubyte2_e32 v51, v55                               ; 7e662737
	v_mac_f32_e32 v48, v13, v36                                 ; 2c60490d
	v_cvt_f32_ubyte2_e32 v36, v61                               ; 7e48273d
	v_mac_f32_e32 v42, v37, v51                                 ; 2c546725
	v_cvt_f32_ubyte1_e32 v51, v55                               ; 7e662537
	v_cvt_f32_ubyte0_e32 v55, v55                               ; 7e6e2337
	v_mac_f32_e32 v48, v12, v35                                 ; 2c60470c
	v_cvt_f32_ubyte3_e32 v35, v61                               ; 7e46293d
	v_mul_f32_e32 v48, v48, v51                                 ; 0a606730
	v_mac_f32_e32 v42, v34, v35                                 ; 2c544722
	v_mov_b32_e32 v35, v52                                      ; 7e460334
	v_mac_f32_e32 v48, v53, v55                                 ; 2c606f35
	v_cvt_f32_ubyte1_e32 v53, v61                               ; 7e6a253d
	v_mac_f32_e32 v48, v54, v53                                 ; 2c606b36
	v_lshlrev_b32_e32 v54, 4, v60                               ; 246c7884
	v_lshl_add_u32 v60, v60, 7, v54                             ; d1fd003c 04d90f3c
	buffer_load_dwordx4 v[52:55], v60, s[24:27], 0 offen        ; e05c1000 8006343c
	v_cvt_f32_ubyte0_e32 v61, v61                               ; 7e7a233d
	v_bfe_u32 v59, v59, v2, 16                                  ; d1c8003b 0242053b
	v_mac_f32_e32 v42, v33, v36                                 ; 2c544921
	v_cvt_f32_f16_sdwa v36, v35 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e4816f9 00050623
	v_cvt_f32_f16_e32 v35, v35                                  ; 7e461723
	v_mac_f32_e32 v48, v49, v61                                 ; 2c607b31
	v_and_b32_e32 v49, s10, v40                                 ; 2662500a
	v_lshl_or_b32 v59, v59, 12, v59                             ; d200003b 04ed193b
	v_mad_f32 v5, -v36, v42, v5                                 ; d1c10005 24165524
	v_cndmask_b32_sdwa v42, v57, v57, vcc dst_sel:WORD_0 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 005472f9 06051439
	v_cndmask_b32_sdwa v42, v58, v58, vcc dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 005474f9 0605153a
	v_lshrrev_b32_e32 v40, 4, v40                               ; 20505084
	v_cvt_f32_ubyte2_e32 v57, v49                               ; 7e722731
	v_cvt_f32_ubyte1_e32 v58, v49                               ; 7e742531
	v_mac_f32_e32 v5, v35, v48                                  ; 2c0a6123
	v_cvt_f32_ubyte3_e32 v51, v49                               ; 7e662931
	v_add_u32_e32 v60, 16, v60                                  ; 68787890
	v_add_u32_e32 v35, v60, v4                                  ; 6846093c
	v_add_u32_e32 v60, v60, v32                                 ; 6878413c
	buffer_load_dword v35, v35, s[24:27], 0 offen               ; e0501000 80062323
	buffer_load_dword v60, v60, s[24:27], 0 offen               ; e0501000 80063c3c
	v_cvt_f32_ubyte0_e32 v49, v49                               ; 7e622331
	v_and_b32_e32 v48, s11, v42                                 ; 2660540b
	v_and_b32_e32 v40, s10, v40                                 ; 2650500a
	v_mul_f32_e32 v51, v19, v51                                 ; 0a666713
	v_lshrrev_b32_e32 v48, 2, v48                               ; 20606082
	v_cvt_f32_ubyte2_e32 v36, v40                               ; 7e482728
	v_cvt_f32_ubyte3_e32 v61, v40                               ; 7e7a2928
	v_mac_f32_e32 v51, v18, v57                                 ; 2c667312
	v_and_or_b32 v59, s10, v59, v48                             ; d201003b 04c2760a
	v_cvt_f32_ubyte1_e32 v48, v40                               ; 7e602528
	v_cvt_f32_ubyte0_e32 v40, v40                               ; 7e502328
	v_mul_f32_e32 v61, v23, v61                                 ; 0a7a7b17
	v_mac_f32_e32 v51, v17, v58                                 ; 2c667511
	v_mac_f32_e32 v61, v22, v36                                 ; 2c7a4916
	v_mac_f32_e32 v51, v16, v49                                 ; 2c666310
	v_and_b32_e32 v49, s10, v39                                 ; 26624e0a
	v_lshrrev_b32_e32 v39, 4, v39                               ; 204e4e84
	v_mac_f32_e32 v61, v21, v48                                 ; 2c7a6115
	v_cvt_f32_ubyte2_e32 v58, v49                               ; 7e742731
	v_cvt_f32_ubyte1_e32 v36, v49                               ; 7e482531
	v_cvt_f32_ubyte3_e32 v57, v49                               ; 7e722931
	v_cvt_f32_ubyte0_e32 v49, v49                               ; 7e622331
	v_and_b32_e32 v39, s10, v39                                 ; 264e4e0a
	v_mac_f32_e32 v61, v20, v40                                 ; 2c7a5114
	v_mul_f32_e32 v57, v27, v57                                 ; 0a72731b
	v_cvt_f32_ubyte2_e32 v48, v39                               ; 7e602727
	v_cvt_f32_ubyte3_e32 v40, v39                               ; 7e502927
	v_and_b32_e32 v42, s12, v42                                 ; 2654540c
	v_mac_f32_e32 v57, v26, v58                                 ; 2c72751a
	v_cvt_f32_ubyte3_e32 v58, v59                               ; 7e74293b
	v_mul_f32_e32 v40, v15, v40                                 ; 0a50510f
	v_mac_f32_e32 v57, v25, v36                                 ; 2c724919
	v_cvt_f32_ubyte2_e32 v36, v59                               ; 7e48273b
	v_mul_f32_e32 v58, v38, v58                                 ; 0a747526
	v_mac_f32_e32 v40, v14, v48                                 ; 2c50610e
	v_cvt_f32_ubyte2_e32 v48, v42                               ; 7e60272a
	v_mac_f32_e32 v57, v24, v49                                 ; 2c726318
	v_cvt_f32_ubyte1_e32 v49, v39                               ; 7e622527
	v_cvt_f32_ubyte0_e32 v39, v39                               ; 7e4e2327
	v_mac_f32_e32 v58, v37, v36                                 ; 2c744925
	v_mac_f32_e32 v40, v13, v49                                 ; 2c50630d
	v_cvt_f32_ubyte1_e32 v49, v59                               ; 7e62253b
	v_cvt_f32_ubyte0_e32 v59, v59                               ; 7e76233b
	v_mac_f32_e32 v40, v12, v39                                 ; 2c504f0c
	v_cvt_f32_ubyte3_e32 v39, v42                               ; 7e4e292a
	v_bfe_u32 v47, v47, v2, 16                                  ; d1c8002f 0242052f
	v_mul_f32_e32 v40, v40, v49                                 ; 0a506328
	v_mac_f32_e32 v58, v34, v39                                 ; 2c744f22
	v_lshl_or_b32 v47, v47, 12, v47                             ; d200002f 04bd192f
	v_mac_f32_e32 v40, v57, v59                                 ; 2c507739
	v_cvt_f32_ubyte1_e32 v57, v42                               ; 7e72252a
	v_cvt_f32_ubyte0_e32 v42, v42                               ; 7e54232a
	v_cvt_f32_f16_sdwa v59, v56 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e7616f9 00050638
	v_cvt_f32_f16_e32 v56, v56                                  ; 7e701738
	v_and_b32_e32 v39, s10, v41                                 ; 264e520a
	v_mac_f32_e32 v58, v33, v48                                 ; 2c746121
	s_add_u32 s15, s16, 6                                       ; 800f8610
	v_mac_f32_e32 v40, v61, v57                                 ; 2c50733d
	v_cndmask_b32_sdwa v61, v45, v45, vcc dst_sel:WORD_0 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 007a5af9 0605142d
	v_mad_f32 v6, -v59, v58, v6                                 ; d1c10006 241a753b
	s_mul_i32 s15, s15, s3                                      ; 920f030f
	v_mac_f32_e32 v40, v51, v42                                 ; 2c505533
	s_add_u32 s15, s18, s15                                     ; 800f0f12
	v_mac_f32_e32 v6, v56, v40                                  ; 2c0c5138
	v_add_u32_e32 v42, s15, v0                                  ; 6854000f
	v_lshlrev_b32_e32 v45, 4, v42                               ; 245a5484
	v_lshl_add_u32 v42, v42, 7, v45                             ; d1fd002a 04b50f2a
	buffer_load_dwordx4 v[56:59], v42, s[24:27], 0 offen        ; e05c1000 8006382a
	v_cndmask_b32_sdwa v61, v46, v46, vcc dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 007a5cf9 0605152e
	v_cvt_f32_ubyte3_e32 v40, v39                               ; 7e502927
	v_cvt_f32_ubyte2_e32 v46, v39                               ; 7e5c2727
	v_add_u32_e32 v42, 16, v42                                  ; 68545490
	v_cvt_f32_ubyte1_e32 v48, v39                               ; 7e602527
	v_add_u32_e32 v51, v42, v4                                  ; 6866092a
	v_add_u32_e32 v42, v42, v32                                 ; 6854412a
	buffer_load_dword v51, v51, s[24:27], 0 offen               ; e0501000 80063333
	buffer_load_dword v42, v42, s[24:27], 0 offen               ; e0501000 80062a2a
	v_cvt_f32_ubyte0_e32 v39, v39                               ; 7e4e2327
	v_lshrrev_b32_e32 v41, 4, v41                               ; 20525284
	v_and_b32_e32 v36, s11, v61                                 ; 26487a0b
	v_mul_f32_e32 v40, v19, v40                                 ; 0a505113
	v_and_b32_e32 v41, s10, v41                                 ; 2652520a
	v_lshrrev_b32_e32 v36, 2, v36                               ; 20484882
	v_mac_f32_e32 v40, v18, v46                                 ; 2c505d12
	v_cvt_f32_ubyte3_e32 v49, v41                               ; 7e622929
	v_and_or_b32 v47, s10, v47, v36                             ; d201002f 04925e0a
	v_cvt_f32_ubyte2_e32 v36, v41                               ; 7e482729
	v_mac_f32_e32 v40, v17, v48                                 ; 2c506111
	v_mul_f32_e32 v49, v23, v49                                 ; 0a626317
	v_mac_f32_e32 v40, v16, v39                                 ; 2c504f10
	v_cvt_f32_ubyte1_e32 v39, v41                               ; 7e4e2529
	v_cvt_f32_ubyte0_e32 v41, v41                               ; 7e522329
	v_mac_f32_e32 v49, v22, v36                                 ; 2c624916
	v_mac_f32_e32 v49, v21, v39                                 ; 2c624f15
	v_mac_f32_e32 v49, v20, v41                                 ; 2c625314
	s_waitcnt vmcnt(9)                                          ; bf8c3f79
	v_and_b32_e32 v41, s10, v43                                 ; 2652560a
	v_lshrrev_b32_e32 v43, 4, v43                               ; 20565684
	v_cvt_f32_ubyte3_e32 v45, v41                               ; 7e5a2929
	v_cvt_f32_ubyte2_e32 v46, v41                               ; 7e5c2729
	v_cvt_f32_ubyte1_e32 v48, v41                               ; 7e602529
	v_cvt_f32_ubyte0_e32 v41, v41                               ; 7e522329
	v_and_b32_e32 v43, s10, v43                                 ; 2656560a
	v_mul_f32_e32 v45, v27, v45                                 ; 0a5a5b1b
	v_cvt_f32_ubyte3_e32 v36, v43                               ; 7e48292b
	v_and_b32_e32 v61, s12, v61                                 ; 267a7a0c
	v_cvt_f32_ubyte2_e32 v39, v43                               ; 7e4e272b
	v_mac_f32_e32 v45, v26, v46                                 ; 2c5a5d1a
	v_cvt_f32_ubyte2_e32 v46, v47                               ; 7e5c272f
	v_mul_f32_e32 v36, v15, v36                                 ; 0a48490f
	v_mac_f32_e32 v45, v25, v48                                 ; 2c5a6119
	v_cvt_f32_ubyte3_e32 v48, v61                               ; 7e60293d
	v_mac_f32_e32 v36, v14, v39                                 ; 2c484f0e
	v_cvt_f32_ubyte2_e32 v39, v61                               ; 7e4e273d
	v_mac_f32_e32 v45, v24, v41                                 ; 2c5a5318
	v_cvt_f32_ubyte1_e32 v41, v43                               ; 7e52252b
	v_cvt_f32_ubyte0_e32 v43, v43                               ; 7e56232b
	v_mac_f32_e32 v36, v13, v41                                 ; 2c48530d
	v_cvt_f32_ubyte1_e32 v41, v47                               ; 7e52252f
	v_mac_f32_e32 v36, v12, v43                                 ; 2c48570c
	v_cvt_f32_ubyte3_e32 v43, v47                               ; 7e56292f
	v_cvt_f32_ubyte0_e32 v47, v47                               ; 7e5e232f
	s_waitcnt vmcnt(8)                                          ; bf8c3f78
	v_bfe_u32 v31, v31, v2, 16                                  ; d1c8001f 0242051f
	v_mul_f32_e32 v36, v36, v41                                 ; 0a485324
	v_mul_f32_e32 v43, v38, v43                                 ; 0a565726
	v_lshl_or_b32 v31, v31, 12, v31                             ; d200001f 047d191f
	v_mac_f32_e32 v36, v45, v47                                 ; 2c485f2d
	v_cvt_f32_ubyte1_e32 v45, v61                               ; 7e5a253d
	v_cvt_f32_ubyte0_e32 v61, v61                               ; 7e7a233d
	v_cndmask_b32_sdwa v47, v29, v29, vcc dst_sel:WORD_0 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 005e3af9 0605141d
	v_cndmask_b32_sdwa v47, v30, v30, vcc dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 005e3cf9 0605151e
	v_mac_f32_e32 v43, v37, v46                                 ; 2c565d25
	v_cvt_f32_f16_sdwa v46, v44 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e5c16f9 0005062c
	v_cvt_f32_f16_e32 v44, v44                                  ; 7e58172c
	v_mac_f32_e32 v36, v49, v45                                 ; 2c485b31
	s_waitcnt vmcnt(7)                                          ; bf8c3f77
	v_and_b32_e32 v49, s10, v50                                 ; 2662640a
	s_add_u32 s19, s16, 7                                       ; 80138710
	v_mac_f32_e32 v43, v34, v48                                 ; 2c566122
	v_mac_f32_e32 v36, v40, v61                                 ; 2c487b28
	s_mul_i32 s19, s19, s3                                      ; 92130313
	v_mac_f32_e32 v43, v33, v39                                 ; 2c564f21
	s_add_u32 s19, s18, s19                                     ; 80131312
	v_mad_f32 v7, -v46, v43, v7                                 ; d1c10007 241e572e
	v_add_u32_e32 v29, s19, v0                                  ; 683a0013
	v_mac_f32_e32 v7, v44, v36                                  ; 2c0e492c
	v_lshlrev_b32_e32 v30, 4, v29                               ; 243c3a84
	v_lshl_add_u32 v29, v29, 7, v30                             ; d1fd001d 04790f1d
	buffer_load_dwordx4 v[43:46], v29, s[24:27], 0 offen        ; e05c1000 80062b1d
	v_and_b32_e32 v48, s11, v47                                 ; 26605e0b
	v_cvt_f32_ubyte3_e32 v61, v49                               ; 7e7a2931
	v_add_u32_e32 v29, 16, v29                                  ; 683a3a90
	v_cvt_f32_ubyte2_e32 v36, v49                               ; 7e482731
	v_add_u32_e32 v41, v29, v4                                  ; 6852091d
	v_add_u32_e32 v29, v29, v32                                 ; 683a411d
	buffer_load_dword v41, v41, s[24:27], 0 offen               ; e0501000 80062929
	buffer_load_dword v29, v29, s[24:27], 0 offen               ; e0501000 80061d1d
	v_cvt_f32_ubyte1_e32 v39, v49                               ; 7e4e2531
	v_cvt_f32_ubyte0_e32 v49, v49                               ; 7e622331
	v_lshrrev_b32_e32 v50, 4, v50                               ; 20646484
	v_lshrrev_b32_e32 v48, 2, v48                               ; 20606082
	v_mul_f32_e32 v61, v19, v61                                 ; 0a7a7b13
	v_and_b32_e32 v50, s10, v50                                 ; 2664640a
	v_and_or_b32 v31, s10, v31, v48                             ; d201001f 04c23e0a
	v_mac_f32_e32 v61, v18, v36                                 ; 2c7a4912
	v_cvt_f32_ubyte2_e32 v48, v50                               ; 7e602732
	v_cvt_f32_ubyte3_e32 v40, v50                               ; 7e502932
	v_mac_f32_e32 v61, v17, v39                                 ; 2c7a4f11
	v_mul_f32_e32 v40, v23, v40                                 ; 0a505117
	v_mac_f32_e32 v61, v16, v49                                 ; 2c7a6310
	v_cvt_f32_ubyte1_e32 v49, v50                               ; 7e622532
	v_cvt_f32_ubyte0_e32 v50, v50                               ; 7e642332
	v_mac_f32_e32 v40, v22, v48                                 ; 2c506116
	v_mac_f32_e32 v40, v21, v49                                 ; 2c506315
	v_mac_f32_e32 v40, v20, v50                                 ; 2c506514
	s_waitcnt vmcnt(9)                                          ; bf8c3f79
	v_and_b32_e32 v50, s10, v62                                 ; 26647c0a
	v_lshrrev_b32_e32 v62, 4, v62                               ; 207c7c84
	v_cvt_f32_ubyte2_e32 v32, v50                               ; 7e402732
	v_cvt_f32_ubyte1_e32 v36, v50                               ; 7e482532
	v_cvt_f32_ubyte3_e32 v30, v50                               ; 7e3c2932
	v_cvt_f32_ubyte0_e32 v50, v50                               ; 7e642332
	v_and_b32_e32 v62, s10, v62                                 ; 267c7c0a
	v_mul_f32_e32 v30, v27, v30                                 ; 0a3c3d1b
	v_and_b32_e32 v47, s12, v47                                 ; 265e5e0c
	v_cvt_f32_ubyte2_e32 v48, v62                               ; 7e60273e
	v_cvt_f32_ubyte3_e32 v39, v62                               ; 7e4e293e
	v_cvt_f32_ubyte1_e32 v49, v62                               ; 7e62253e
	v_cvt_f32_ubyte0_e32 v62, v62                               ; 7e7c233e
	v_mac_f32_e32 v30, v26, v32                                 ; 2c3c411a
	v_mul_f32_e32 v39, v15, v39                                 ; 0a4e4f0f
	v_mac_f32_e32 v30, v25, v36                                 ; 2c3c4919
	v_mac_f32_e32 v39, v14, v48                                 ; 2c4e610e
	v_mac_f32_e32 v30, v24, v50                                 ; 2c3c6518
	v_cvt_f32_ubyte3_e32 v50, v31                               ; 7e64291f
	v_mac_f32_e32 v39, v13, v49                                 ; 2c4e630d
	v_mul_f32_e32 v50, v38, v50                                 ; 0a646526
	v_mac_f32_e32 v39, v12, v62                                 ; 2c4e7d0c
	v_cvt_f32_ubyte2_e32 v62, v31                               ; 7e7c271f
	v_mac_f32_e32 v50, v37, v62                                 ; 2c647d25
	v_cvt_f32_ubyte3_e32 v62, v47                               ; 7e7c292f
	s_waitcnt vmcnt(8)                                          ; bf8c3f78
	v_bfe_u32 v55, v55, v2, 16                                  ; d1c80037 02420537
	v_mac_f32_e32 v50, v34, v62                                 ; 2c647d22
	v_cvt_f32_ubyte2_e32 v62, v47                               ; 7e7c272f
	v_lshl_or_b32 v55, v55, 12, v55                             ; d2000037 04dd1937
	v_mac_f32_e32 v50, v33, v62                                 ; 2c647d21
	v_cvt_f32_ubyte1_e32 v62, v31                               ; 7e7c251f
	v_cvt_f32_ubyte0_e32 v31, v31                               ; 7e3e231f
	v_mul_f32_e32 v39, v39, v62                                 ; 0a4e7d27
	v_cvt_f32_ubyte1_e32 v62, v47                               ; 7e7c252f
	v_cvt_f32_ubyte0_e32 v47, v47                               ; 7e5e232f
	v_mac_f32_e32 v39, v30, v31                                 ; 2c4e3f1e
	s_waitcnt vmcnt(7)                                          ; bf8c3f77
	v_and_b32_e32 v30, s10, v35                                 ; 263c460a
	v_mac_f32_e32 v39, v40, v62                                 ; 2c4e7d28
	v_cndmask_b32_sdwa v62, v53, v53, vcc dst_sel:WORD_0 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 007c6af9 06051435
	v_cndmask_b32_sdwa v62, v54, v54, vcc dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 007c6cf9 06051536
	v_cvt_f32_ubyte2_e32 v32, v30                               ; 7e40271e
	v_cvt_f32_ubyte1_e32 v36, v30                               ; 7e48251e
	v_cvt_f32_ubyte3_e32 v31, v30                               ; 7e3e291e
	v_cvt_f32_ubyte0_e32 v30, v30                               ; 7e3c231e
	v_mac_f32_e32 v39, v61, v47                                 ; 2c4e5f3d
	v_cvt_f32_f16_sdwa v61, v28 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e7a16f9 0005061c
	v_cvt_f32_f16_e32 v28, v28                                  ; 7e38171c
	v_lshrrev_b32_e32 v35, 4, v35                               ; 20464684
	v_mul_f32_e32 v31, v19, v31                                 ; 0a3e3f13
	v_mad_f32 v8, -v61, v50, v8                                 ; d1c10008 2422653d
	v_and_b32_e32 v35, s10, v35                                 ; 2646460a
	v_mac_f32_e32 v31, v18, v32                                 ; 2c3e4112
	s_waitcnt vmcnt(6)                                          ; bf8c3f76
	v_and_b32_e32 v48, s10, v60                                 ; 2660780a
	v_mac_f32_e32 v8, v28, v39                                  ; 2c104f1c
	v_and_b32_e32 v28, s11, v62                                 ; 26387c0b
	v_cvt_f32_ubyte3_e32 v39, v35                               ; 7e4e2923
	v_cvt_f32_ubyte1_e32 v47, v35                               ; 7e5e2523
	v_cvt_f32_ubyte2_e32 v40, v35                               ; 7e502723
	v_cvt_f32_ubyte0_e32 v35, v35                               ; 7e462323
	v_mac_f32_e32 v31, v17, v36                                 ; 2c3e4911
	v_cvt_f32_ubyte3_e32 v49, v48                               ; 7e622930
	v_cvt_f32_ubyte2_e32 v50, v48                               ; 7e642730
	v_cvt_f32_ubyte1_e32 v53, v48                               ; 7e6a2530
	v_lshrrev_b32_e32 v28, 2, v28                               ; 20383882
	v_mul_f32_e32 v39, v23, v39                                 ; 0a4e4f17
	v_cvt_f32_ubyte0_e32 v48, v48                               ; 7e602330
	v_lshrrev_b32_e32 v60, 4, v60                               ; 20787884
	v_mac_f32_e32 v31, v16, v30                                 ; 2c3e3d10
	v_mul_f32_e32 v49, v27, v49                                 ; 0a62631b
	v_and_or_b32 v55, s10, v55, v28                             ; d2010037 04726e0a
	v_mac_f32_e32 v39, v22, v40                                 ; 2c4e5116
	v_and_b32_e32 v60, s10, v60                                 ; 2678780a
	v_mac_f32_e32 v49, v26, v50                                 ; 2c62651a
	v_cvt_f32_ubyte3_e32 v30, v55                               ; 7e3c2937
	v_mac_f32_e32 v39, v21, v47                                 ; 2c4e5f15
	v_cvt_f32_ubyte2_e32 v32, v55                               ; 7e402737
	v_cvt_f32_ubyte2_e32 v61, v60                               ; 7e7a273c
	v_cvt_f32_ubyte1_e32 v28, v60                               ; 7e38253c
	v_cvt_f32_ubyte3_e32 v54, v60                               ; 7e6c293c
	v_cvt_f32_ubyte0_e32 v60, v60                               ; 7e78233c
	v_and_b32_e32 v62, s12, v62                                 ; 267c7c0c
	v_mac_f32_e32 v49, v25, v53                                 ; 2c626b19
	v_mul_f32_e32 v30, v38, v30                                 ; 0a3c3d26
	v_mac_f32_e32 v39, v20, v35                                 ; 2c4e4714
	v_cvt_f32_ubyte1_e32 v40, v55                               ; 7e502537
	v_mul_f32_e32 v54, v15, v54                                 ; 0a6c6d0f
	v_cvt_f32_ubyte0_e32 v55, v55                               ; 7e6e2337
	v_cvt_f32_ubyte3_e32 v35, v62                               ; 7e46293e
	v_cvt_f32_ubyte2_e32 v36, v62                               ; 7e48273e
	v_mac_f32_e32 v49, v24, v48                                 ; 2c626118
	v_cvt_f32_ubyte1_e32 v47, v62                               ; 7e5e253e
	v_mac_f32_e32 v30, v37, v32                                 ; 2c3c4125
	v_cvt_f32_ubyte0_e32 v62, v62                               ; 7e7c233e
	v_mac_f32_e32 v54, v14, v61                                 ; 2c6c7b0e
	v_cvt_f32_f16_sdwa v48, v52 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e6016f9 00050634
	v_cvt_f32_f16_e32 v52, v52                                  ; 7e681734
	s_waitcnt vmcnt(5)                                          ; bf8c3f75
	v_bfe_u32 v59, v59, v2, 16                                  ; d1c8003b 0242053b
	v_mac_f32_e32 v30, v34, v35                                 ; 2c3c4722
	v_mac_f32_e32 v54, v13, v28                                 ; 2c6c390d
	v_lshl_or_b32 v59, v59, 12, v59                             ; d200003b 04ed193b
	v_mac_f32_e32 v30, v33, v36                                 ; 2c3c4921
	v_mac_f32_e32 v54, v12, v60                                 ; 2c6c790c
	v_mad_f32 v9, -v48, v30, v9                                 ; d1c10009 24263d30
	v_mul_f32_e32 v54, v54, v40                                 ; 0a6c5136
	v_mac_f32_e32 v54, v49, v55                                 ; 2c6c6f31
	v_cndmask_b32_sdwa v49, v57, v57, vcc dst_sel:WORD_0 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 006272f9 06051439
	v_cndmask_b32_sdwa v49, v58, v58, vcc dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 006274f9 0605153a
	v_mac_f32_e32 v54, v39, v47                                 ; 2c6c5f27
	v_and_b32_e32 v50, s11, v49                                 ; 2664620b
	v_mac_f32_e32 v54, v31, v62                                 ; 2c6c7d1f
	v_lshrrev_b32_e32 v50, 2, v50                               ; 20646482
	v_mac_f32_e32 v9, v52, v54                                  ; 2c126d34
	s_waitcnt vmcnt(4)                                          ; bf8c3f74
	v_and_b32_e32 v52, s10, v51                                 ; 2668660a
	v_lshrrev_b32_e32 v51, 4, v51                               ; 20666684
	v_and_or_b32 v59, s10, v59, v50                             ; d201003b 04ca760a
	v_cvt_f32_ubyte1_e32 v55, v52                               ; 7e6e2534
	v_cvt_f32_ubyte3_e32 v53, v52                               ; 7e6a2934
	v_cvt_f32_ubyte2_e32 v54, v52                               ; 7e6c2734
	v_cvt_f32_ubyte0_e32 v52, v52                               ; 7e682334
	v_and_b32_e32 v51, s10, v51                                 ; 2666660a
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_and_b32_e32 v61, s10, v42                                 ; 267a540a
	v_mul_f32_e32 v53, v19, v53                                 ; 0a6a6b13
	v_cvt_f32_ubyte1_e32 v60, v51                               ; 7e782533
	v_cvt_f32_ubyte2_e32 v58, v51                               ; 7e742733
	v_cvt_f32_ubyte3_e32 v57, v51                               ; 7e722933
	v_cvt_f32_ubyte0_e32 v51, v51                               ; 7e662333
	v_cvt_f32_ubyte2_e32 v28, v61                               ; 7e38273d
	v_cvt_f32_ubyte1_e32 v30, v61                               ; 7e3c253d
	v_cvt_f32_ubyte3_e32 v62, v61                               ; 7e7c293d
	v_mac_f32_e32 v53, v18, v54                                 ; 2c6a6d12
	v_cvt_f32_ubyte0_e32 v61, v61                               ; 7e7a233d
	v_mul_f32_e32 v57, v23, v57                                 ; 0a727317
	v_lshrrev_b32_e32 v42, 4, v42                               ; 20545484
	v_mul_f32_e32 v62, v27, v62                                 ; 0a7c7d1b
	v_mac_f32_e32 v53, v17, v55                                 ; 2c6a6f11
	v_mac_f32_e32 v57, v22, v58                                 ; 2c727516
	v_and_b32_e32 v42, s10, v42                                 ; 2654540a
	v_mac_f32_e32 v62, v26, v28                                 ; 2c7c391a
	v_mac_f32_e32 v53, v16, v52                                 ; 2c6a6910
	v_cvt_f32_ubyte3_e32 v36, v59                               ; 7e48293b
	v_mac_f32_e32 v57, v21, v60                                 ; 2c727915
	v_cvt_f32_ubyte2_e32 v32, v42                               ; 7e40272a
	v_cvt_f32_ubyte3_e32 v31, v42                               ; 7e3e292a
	v_cvt_f32_ubyte1_e32 v35, v42                               ; 7e46252a
	v_cvt_f32_ubyte2_e32 v39, v59                               ; 7e4e273b
	v_cvt_f32_ubyte0_e32 v42, v42                               ; 7e54232a
	v_mac_f32_e32 v62, v25, v30                                 ; 2c7c3d19
	v_and_b32_e32 v49, s12, v49                                 ; 2662620c
	v_mul_f32_e32 v36, v38, v36                                 ; 0a484926
	v_mac_f32_e32 v57, v20, v51                                 ; 2c726714
	v_mul_f32_e32 v31, v15, v31                                 ; 0a3e3f0f
	v_cvt_f32_ubyte1_e32 v47, v59                               ; 7e5e253b
	v_cvt_f32_ubyte0_e32 v59, v59                               ; 7e76233b
	v_mac_f32_e32 v62, v24, v61                                 ; 2c7c7b18
	v_cvt_f32_ubyte1_e32 v48, v49                               ; 7e602531
	v_cvt_f32_ubyte3_e32 v40, v49                               ; 7e502931
	v_mac_f32_e32 v36, v37, v39                                 ; 2c484f25
	v_mac_f32_e32 v31, v14, v32                                 ; 2c3e410e
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_bfe_u32 v46, v46, v2, 16                                  ; d1c8002e 0242052e
	v_mac_f32_e32 v36, v34, v40                                 ; 2c485122
	v_cndmask_b32_sdwa v50, v44, v44, vcc dst_sel:WORD_0 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 006458f9 0605142c
	v_cndmask_b32_sdwa v50, v45, v45, vcc dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 00645af9 0605152d
	v_mac_f32_e32 v31, v13, v35                                 ; 2c3e470d
	v_lshl_or_b32 v46, v46, 12, v46                             ; d200002e 04b9192e
	v_and_b32_e32 v51, s11, v50                                 ; 2666640b
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v52, s10, v41                                 ; 2668520a
	v_mac_f32_e32 v31, v12, v42                                 ; 2c3e550c
	v_cvt_f32_ubyte2_e32 v42, v49                               ; 7e542731
	v_cvt_f32_ubyte0_e32 v49, v49                               ; 7e622331
	v_lshrrev_b32_e32 v51, 2, v51                               ; 20666682
	v_cvt_f32_ubyte2_e32 v54, v52                               ; 7e6c2734
	v_mul_f32_e32 v31, v31, v47                                 ; 0a3e5f1f
	v_mac_f32_e32 v36, v33, v42                                 ; 2c485521
	v_cvt_f32_ubyte1_e32 v55, v52                               ; 7e6e2534
	v_and_or_b32 v46, s10, v46, v51                             ; d201002e 04ce5c0a
	v_lshrrev_b32_e32 v41, 4, v41                               ; 20525284
	v_mac_f32_e32 v31, v62, v59                                 ; 2c3e773e
	v_and_b32_e32 v41, s10, v41                                 ; 2652520a
	v_mac_f32_e32 v31, v57, v48                                 ; 2c3e6139
	v_cvt_f32_ubyte1_e32 v58, v41                               ; 7e742529
	v_cvt_f32_ubyte2_e32 v57, v41                               ; 7e722729
	v_mac_f32_e32 v31, v53, v49                                 ; 2c3e6335
	v_cvt_f32_f16_sdwa v49, v56 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e6216f9 00050638
	v_cvt_f32_f16_e32 v56, v56                                  ; 7e701738
	v_cvt_f32_ubyte3_e32 v53, v52                               ; 7e6a2934
	v_cvt_f32_ubyte0_e32 v52, v52                               ; 7e682334
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v59, s10, v29                                 ; 26763a0a
	v_mad_f32 v10, -v49, v36, v10                               ; d1c1000a 242a4931
	v_mul_f32_e32 v19, v19, v53                                 ; 0a266b13
	v_cvt_f32_ubyte3_e32 v60, v59                               ; 7e78293b
	v_cvt_f32_ubyte2_e32 v61, v59                               ; 7e7a273b
	v_cvt_f32_ubyte1_e32 v62, v59                               ; 7e7c253b
	v_mac_f32_e32 v10, v56, v31                                 ; 2c143f38
	v_cvt_f32_ubyte3_e32 v56, v41                               ; 7e702929
	v_cvt_f32_ubyte0_e32 v41, v41                               ; 7e522329
	v_cvt_f32_ubyte0_e32 v59, v59                               ; 7e76233b
	v_mac_f32_e32 v19, v18, v54                                 ; 2c266d12
	v_mul_f32_e32 v27, v27, v60                                 ; 0a36791b
	v_lshrrev_b32_e32 v29, 4, v29                               ; 203a3a84
	v_mul_f32_e32 v23, v23, v56                                 ; 0a2e7117
	v_mac_f32_e32 v19, v17, v55                                 ; 2c266f11
	v_mac_f32_e32 v27, v26, v61                                 ; 2c367b1a
	v_and_b32_e32 v29, s10, v29                                 ; 263a3a0a
	v_mac_f32_e32 v23, v22, v57                                 ; 2c2e7316
	v_mac_f32_e32 v19, v16, v52                                 ; 2c266910
	v_mac_f32_e32 v27, v25, v62                                 ; 2c367d19
	v_cvt_f32_ubyte3_e32 v62, v29                               ; 7e7c291d
	v_mac_f32_e32 v23, v21, v58                                 ; 2c2e7515
	v_and_b32_e32 v50, s12, v50                                 ; 2664640c
	v_mac_f32_e32 v27, v24, v59                                 ; 2c367718
	v_mul_f32_e32 v15, v15, v62                                 ; 0a1e7d0f
	v_cvt_f32_ubyte2_e32 v62, v29                               ; 7e7c271d
	v_mac_f32_e32 v23, v20, v41                                 ; 2c2e5314
	v_mac_f32_e32 v15, v14, v62                                 ; 2c1e7d0e
	v_cvt_f32_ubyte1_e32 v62, v29                               ; 7e7c251d
	v_cvt_f32_ubyte0_e32 v29, v29                               ; 7e3a231d
	v_mac_f32_e32 v15, v13, v62                                 ; 2c1e7d0d
	v_cvt_f32_ubyte3_e32 v62, v46                               ; 7e7c292e
	v_mac_f32_e32 v15, v12, v29                                 ; 2c1e3b0c
	v_mul_f32_e32 v38, v38, v62                                 ; 0a4c7d26
	v_cvt_f32_ubyte2_e32 v62, v46                               ; 7e7c272e
	v_mac_f32_e32 v38, v37, v62                                 ; 2c4c7d25
	v_cvt_f32_ubyte3_e32 v62, v50                               ; 7e7c2932
	v_add_u32_e32 v0, 4, v0                                     ; 68000084
	v_mac_f32_e32 v38, v34, v62                                 ; 2c4c7d22
	v_cvt_f32_ubyte2_e32 v62, v50                               ; 7e7c2732
	v_mac_f32_e32 v38, v33, v62                                 ; 2c4c7d21
	v_cvt_f32_ubyte1_e32 v62, v46                               ; 7e7c252e
	v_cvt_f32_ubyte0_e32 v46, v46                               ; 7e5c232e
	v_mul_f32_e32 v15, v15, v62                                 ; 0a1e7d0f
	v_cvt_f32_ubyte1_e32 v62, v50                               ; 7e7c2532
	v_cvt_f32_ubyte0_e32 v50, v50                               ; 7e642332
	v_mac_f32_e32 v15, v27, v46                                 ; 2c1e5d1b
	v_mac_f32_e32 v15, v23, v62                                 ; 2c1e7d17
	v_cvt_f32_f16_sdwa v62, v43 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e7c16f9 0005062b
	v_cvt_f32_f16_e32 v43, v43                                  ; 7e56172b
	v_mac_f32_e32 v15, v19, v50                                 ; 2c1e6513
	v_mad_f32 v11, -v62, v38, v11                               ; d1c1000b 242e4d3e
	v_mac_f32_e32 v11, v43, v15                                 ; 2c161f2b
BB5:
	s_mov_b64 s[0:1], exec                                      ; be80017e
	v_cmpx_le_u32_e32 vcc, s3, v0                               ; 7db60003
BB6:
	s_andn2_b64 s[0:1], s[0:1], exec                            ; 89807e00
	s_cbranch_scc1 BB10                                         ; bf85fced
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
	s_branch BB203                                              ; bf820584
BB66:
	s_cmp_lt_u32 s16, s4                                        ; bf0a0410
	s_cbranch_scc0 BB203                                        ; bf840582
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
	v_mov_b32_e32 v5, 0                                         ; 7e0a0280
	v_mov_b32_e32 v6, 0                                         ; 7e0c0280
	s_mul_i32 s19, s19, s5                                      ; 92130513
	v_mov_b32_e32 v7, 0                                         ; 7e0e0280
	v_mov_b32_e32 v8, 0                                         ; 7e100280
	v_sub_u32_e32 v1, v2, v1                                    ; 6a020302
	v_bfe_u32 v3, v2, 2, 1                                      ; d1c80003 02050502
	v_lshrrev_b32_e32 v2, 3, v2                                 ; 20040483
	v_mov_b32_e32 v9, 0                                         ; 7e120280
	v_mov_b32_e32 v10, 0                                        ; 7e140280
	v_mov_b32_e32 v11, 0                                        ; 7e160280
	v_lshl_add_u32 v1, v1, 1, v3                                ; d1fd0001 040d0301
	v_mov_b32_e32 v3, 0                                         ; 7e060280
	v_lshlrev_b32_e32 v1, 2, v1                                 ; 24020282
	v_lshl_add_u32 v4, v2, 5, v1                                ; d1fd0004 04050b02
	v_lshl_add_u32 v1, v2, 6, v1                                ; d1fd0001 04050d02
	v_lshlrev_b32_e32 v2, 4, v2                                 ; 24040484
BB71:
	s_mov_b64 s[0:1], exec                                      ; be80017e
	v_cmpx_le_u32_e32 vcc, s3, v0                               ; 7db60003
BB72:
	s_andn2_b64 s[0:1], s[0:1], exec                            ; 89807e00
	s_cbranch_scc0 BB101                                        ; bf840340
BB76:
	s_mov_b64 exec, s[0:1]                                      ; befe0100
	s_mov_b32 s0, s2                                            ; be800002
	s_movk_i32 s1, 0x8000                                       ; b0018000
	s_load_dwordx4 s[12:15], s[0:1], 0x10                       ; c00a0300 00000010
	s_mul_i32 s5, s6, s17                                       ; 92051106
	v_lshl_add_u32 v12, v0, 8, v1                               ; d1fd000c 04051100
	v_add_u32_e32 v13, s5, v12                                  ; 681a1805
	v_add_u32_e32 v12, 0x80, v12                                ; 681818ff 00000080
	v_lshrrev_b32_e32 v13, 2, v13                               ; 201a1a82
	v_add_u32_e32 v12, s5, v12                                  ; 68181805
	v_lshlrev_b32_e32 v13, 4, v13                               ; 241a1a84
	v_lshrrev_b32_e32 v12, 2, v12                               ; 20181882
	v_lshlrev_b32_e32 v12, 4, v12                               ; 24181884
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_load_dwordx4 v[16:19], v13, s[12:15], 0 offen        ; e05c1000 8003100d
	buffer_load_dwordx4 v[20:23], v13, s[12:15], 0 offen offset:128 ; e05c1080 8003140d
	buffer_load_dwordx4 v[24:27], v12, s[12:15], 0 offen        ; e05c1000 8003180c
	buffer_load_dwordx4 v[12:15], v12, s[12:15], 0 offen offset:128 ; e05c1080 80030c0c
	s_cmp_lg_i32 s4, 0                                          ; bf018004
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_add_f32_e32 v28, v16, v17                                 ; 02382310
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_add_f32_e32 v29, v20, v21                                 ; 023a2b14
	v_add_f32_e32 v28, v28, v18                                 ; 0238251c
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_add_f32_e32 v30, v24, v25                                 ; 023c3318
	v_add_f32_e32 v29, v29, v22                                 ; 023a2d1d
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_add_f32_e32 v31, v12, v13                                 ; 023e1b0c
	v_add_f32_e32 v28, v28, v19                                 ; 0238271c
	v_add_f32_e32 v30, v30, v26                                 ; 023c351e
	v_add_f32_e32 v29, v29, v23                                 ; 023a2f1d
	v_add_f32_e32 v31, v31, v14                                 ; 023e1d1f
	v_add_f32_e32 v30, v30, v27                                 ; 023c371e
	v_add_f32_e32 v31, v31, v15                                 ; 023e1f1f
	s_cbranch_scc0 BB100                                        ; bf840313
BB77:
	s_load_dwordx4 s[12:15], s[0:1], 0x0                        ; c00a0300 00000000
	s_mul_i32 s0, s16, s3                                       ; 92000310
	v_add_u32_e32 v36, 64, v4                                   ; 684808c0
	s_add_u32 s0, s19, s0                                       ; 80000013
	v_add_u32_e32 v32, s0, v0                                   ; 68400000
	v_lshlrev_b32_e32 v33, 4, v32                               ; 24424084
	v_lshl_add_u32 v32, v32, 7, v33                             ; d1fd0020 04850f20
	v_add_u32_e32 v34, 16, v32                                  ; 68444090
	v_add_u32_e32 v35, v34, v4                                  ; 68460922
	v_add_u32_e32 v34, v34, v36                                 ; 68444922
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_load_dwordx4 v[40:43], v32, s[12:15], 0 offen        ; e05c1000 80032820
	buffer_load_dword v35, v35, s[12:15], 0 offen               ; e0501000 80032323
	buffer_load_dword v34, v34, s[12:15], 0 offen               ; e0501000 80032222
	s_bitreplicate_b64_b32 vcc, 0xf0f0f0f                       ; beea37ff 0f0f0f0f
	s_mov_b32 s1, 0xf0f0f0f                                     ; be8100ff 0f0f0f0f
	s_cmp_lt_u32 1, s4                                          ; bf0a0481
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_bfe_u32 v43, v43, v2, 16                                  ; d1c8002b 0242052b
	v_cndmask_b32_sdwa v37, v41, v41, vcc dst_sel:WORD_0 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 004a52f9 06051429
	v_cndmask_b32_sdwa v37, v42, v42, vcc dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 004a54f9 0605152a
	v_lshl_or_b32 v43, v43, 12, v43                             ; d200002b 04ad192b
	v_and_b32_e32 v38, 0xc0c0c0c0, v37                          ; 264c4aff c0c0c0c0
	v_and_b32_e32 v37, 0x3f3f3f3f, v37                          ; 264a4aff 3f3f3f3f
	v_cvt_f32_f16_sdwa v47, v40 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e5e16f9 00050628
	v_lshrrev_b32_e32 v38, 2, v38                               ; 204c4c82
	v_cvt_f32_f16_e32 v40, v40                                  ; 7e501728
	v_cvt_f32_ubyte1_e32 v46, v37                               ; 7e5c2525
	v_cvt_f32_ubyte3_e32 v42, v37                               ; 7e542925
	v_cvt_f32_ubyte2_e32 v44, v37                               ; 7e582725
	v_cvt_f32_ubyte0_e32 v37, v37                               ; 7e4a2325
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v48, s1, v35                                  ; 26604601
	v_and_or_b32 v43, s1, v43, v38                              ; d201002b 049a5601
	v_cvt_f32_ubyte1_e32 v51, v48                               ; 7e662530
	v_cvt_f32_ubyte3_e32 v49, v48                               ; 7e622930
	v_cvt_f32_ubyte2_e32 v50, v48                               ; 7e642730
	v_cvt_f32_ubyte0_e32 v48, v48                               ; 7e602330
	v_cvt_f32_ubyte1_e32 v45, v43                               ; 7e5a252b
	v_cvt_f32_ubyte3_e32 v39, v43                               ; 7e4e292b
	v_cvt_f32_ubyte2_e32 v41, v43                               ; 7e52272b
	v_cvt_f32_ubyte0_e32 v43, v43                               ; 7e56232b
	v_lshrrev_b32_e32 v35, 4, v35                               ; 20464684
	v_mul_f32_e32 v49, v19, v49                                 ; 0a626313
	v_mul_f32_e32 v39, v31, v39                                 ; 0a4e4f1f
	v_and_b32_e32 v35, s1, v35                                  ; 26464601
	v_mac_f32_e32 v49, v18, v50                                 ; 2c626512
	v_mac_f32_e32 v39, v30, v41                                 ; 2c4e531e
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v55, s1, v34                                  ; 266e4401
	v_cvt_f32_ubyte1_e32 v54, v35                               ; 7e6c2523
	v_cvt_f32_ubyte3_e32 v52, v35                               ; 7e682923
	v_cvt_f32_ubyte2_e32 v53, v35                               ; 7e6a2723
	v_cvt_f32_ubyte0_e32 v35, v35                               ; 7e462323
	v_mac_f32_e32 v49, v17, v51                                 ; 2c626711
	v_mac_f32_e32 v39, v29, v42                                 ; 2c4e551d
	v_cvt_f32_ubyte2_e32 v57, v55                               ; 7e722737
	v_cvt_f32_ubyte3_e32 v56, v55                               ; 7e702937
	v_cvt_f32_ubyte1_e32 v58, v55                               ; 7e742537
	v_mul_f32_e32 v52, v23, v52                                 ; 0a686917
	v_cvt_f32_ubyte0_e32 v55, v55                               ; 7e6e2337
	v_mac_f32_e32 v49, v16, v48                                 ; 2c626110
	v_lshrrev_b32_e32 v34, 4, v34                               ; 20444484
	v_mac_f32_e32 v39, v28, v44                                 ; 2c4e591c
	v_mul_f32_e32 v56, v27, v56                                 ; 0a70711b
	v_mac_f32_e32 v52, v22, v53                                 ; 2c686b16
	v_and_b32_e32 v34, s1, v34                                  ; 26444401
	v_mad_f32 v3, -v47, v39, v3                                 ; d1c10003 240e4f2f
	v_mac_f32_e32 v56, v26, v57                                 ; 2c70731a
	v_mac_f32_e32 v52, v21, v54                                 ; 2c686d15
	v_cvt_f32_ubyte2_e32 v60, v34                               ; 7e782722
	v_cvt_f32_ubyte1_e32 v61, v34                               ; 7e7a2522
	v_cvt_f32_ubyte3_e32 v59, v34                               ; 7e762922
	v_cvt_f32_ubyte0_e32 v34, v34                               ; 7e442322
	v_mac_f32_e32 v56, v25, v58                                 ; 2c707519
	v_mac_f32_e32 v52, v20, v35                                 ; 2c684714
	v_mul_f32_e32 v59, v15, v59                                 ; 0a76770f
	v_mac_f32_e32 v56, v24, v55                                 ; 2c706f18
	v_mac_f32_e32 v59, v14, v60                                 ; 2c76790e
	v_mac_f32_e32 v59, v13, v61                                 ; 2c767b0d
	v_mac_f32_e32 v59, v12, v34                                 ; 2c76450c
	v_mul_f32_e32 v59, v59, v45                                 ; 0a765b3b
	v_mac_f32_e32 v59, v56, v43                                 ; 2c765738
	v_mac_f32_e32 v59, v52, v46                                 ; 2c765d34
	v_mac_f32_e32 v59, v49, v37                                 ; 2c764b31
	v_mac_f32_e32 v3, v40, v59                                  ; 2c067728
	s_cbranch_scc0 BB100                                        ; bf8402ac
BB78:
	s_add_u32 s0, s16, 1                                        ; 80008110
	s_mul_i32 s0, s0, s3                                        ; 92000300
	s_add_u32 s0, s19, s0                                       ; 80000013
	v_add_u32_e32 v32, s0, v0                                   ; 68400000
	v_lshlrev_b32_e32 v33, 4, v32                               ; 24424084
	v_lshl_add_u32 v32, v32, 7, v33                             ; d1fd0020 04850f20
	v_add_u32_e32 v34, 16, v32                                  ; 68444090
	v_add_u32_e32 v35, v34, v4                                  ; 68460922
	v_add_u32_e32 v34, v34, v36                                 ; 68444922
	buffer_load_dwordx4 v[40:43], v32, s[12:15], 0 offen        ; e05c1000 80032820
	buffer_load_dword v35, v35, s[12:15], 0 offen               ; e0501000 80032323
	buffer_load_dword v34, v34, s[12:15], 0 offen               ; e0501000 80032222
	s_mov_b32 s1, 0xf0f0f0f                                     ; be8100ff 0f0f0f0f
	s_cmp_lt_u32 2, s4                                          ; bf0a0482
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_bfe_u32 v43, v43, v2, 16                                  ; d1c8002b 0242052b
	v_cndmask_b32_sdwa v37, v41, v41, vcc dst_sel:WORD_0 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 004a52f9 06051429
	v_cndmask_b32_sdwa v37, v42, v42, vcc dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 004a54f9 0605152a
	v_lshl_or_b32 v43, v43, 12, v43                             ; d200002b 04ad192b
	v_and_b32_e32 v38, 0xc0c0c0c0, v37                          ; 264c4aff c0c0c0c0
	v_and_b32_e32 v37, 0x3f3f3f3f, v37                          ; 264a4aff 3f3f3f3f
	v_cvt_f32_f16_sdwa v47, v40 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e5e16f9 00050628
	v_lshrrev_b32_e32 v38, 2, v38                               ; 204c4c82
	v_cvt_f32_ubyte1_e32 v46, v37                               ; 7e5c2525
	v_cvt_f32_f16_e32 v40, v40                                  ; 7e501728
	v_cvt_f32_ubyte3_e32 v42, v37                               ; 7e542925
	v_cvt_f32_ubyte2_e32 v44, v37                               ; 7e582725
	v_cvt_f32_ubyte0_e32 v37, v37                               ; 7e4a2325
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v48, s1, v35                                  ; 26604601
	v_and_or_b32 v43, s1, v43, v38                              ; d201002b 049a5601
	v_cvt_f32_ubyte3_e32 v49, v48                               ; 7e622930
	v_cvt_f32_ubyte1_e32 v51, v48                               ; 7e662530
	v_cvt_f32_ubyte2_e32 v50, v48                               ; 7e642730
	v_cvt_f32_ubyte0_e32 v48, v48                               ; 7e602330
	v_cvt_f32_ubyte3_e32 v39, v43                               ; 7e4e292b
	v_cvt_f32_ubyte2_e32 v41, v43                               ; 7e52272b
	v_cvt_f32_ubyte1_e32 v45, v43                               ; 7e5a252b
	v_cvt_f32_ubyte0_e32 v43, v43                               ; 7e56232b
	v_lshrrev_b32_e32 v35, 4, v35                               ; 20464684
	v_mul_f32_e32 v49, v19, v49                                 ; 0a626313
	v_mul_f32_e32 v39, v31, v39                                 ; 0a4e4f1f
	v_and_b32_e32 v35, s1, v35                                  ; 26464601
	v_mac_f32_e32 v49, v18, v50                                 ; 2c626512
	v_mac_f32_e32 v39, v30, v41                                 ; 2c4e531e
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v55, s1, v34                                  ; 266e4401
	v_cvt_f32_ubyte3_e32 v52, v35                               ; 7e682923
	v_cvt_f32_ubyte2_e32 v53, v35                               ; 7e6a2723
	v_cvt_f32_ubyte1_e32 v54, v35                               ; 7e6c2523
	v_cvt_f32_ubyte0_e32 v35, v35                               ; 7e462323
	v_mac_f32_e32 v49, v17, v51                                 ; 2c626711
	v_mac_f32_e32 v39, v29, v42                                 ; 2c4e551d
	v_cvt_f32_ubyte2_e32 v57, v55                               ; 7e722737
	v_cvt_f32_ubyte3_e32 v56, v55                               ; 7e702937
	v_mul_f32_e32 v52, v23, v52                                 ; 0a686917
	v_cvt_f32_ubyte1_e32 v58, v55                               ; 7e742537
	v_cvt_f32_ubyte0_e32 v55, v55                               ; 7e6e2337
	v_mac_f32_e32 v49, v16, v48                                 ; 2c626110
	v_lshrrev_b32_e32 v34, 4, v34                               ; 20444484
	v_mac_f32_e32 v39, v28, v44                                 ; 2c4e591c
	v_mul_f32_e32 v56, v27, v56                                 ; 0a70711b
	v_mac_f32_e32 v52, v22, v53                                 ; 2c686b16
	v_and_b32_e32 v34, s1, v34                                  ; 26444401
	v_mad_f32 v5, -v47, v39, v5                                 ; d1c10005 24164f2f
	v_mac_f32_e32 v56, v26, v57                                 ; 2c70731a
	v_mac_f32_e32 v52, v21, v54                                 ; 2c686d15
	v_cvt_f32_ubyte1_e32 v61, v34                               ; 7e7a2522
	v_cvt_f32_ubyte2_e32 v60, v34                               ; 7e782722
	v_cvt_f32_ubyte3_e32 v59, v34                               ; 7e762922
	v_cvt_f32_ubyte0_e32 v34, v34                               ; 7e442322
	v_mac_f32_e32 v56, v25, v58                                 ; 2c707519
	v_mac_f32_e32 v52, v20, v35                                 ; 2c684714
	v_mul_f32_e32 v59, v15, v59                                 ; 0a76770f
	v_mac_f32_e32 v56, v24, v55                                 ; 2c706f18
	v_mac_f32_e32 v59, v14, v60                                 ; 2c76790e
	v_mac_f32_e32 v59, v13, v61                                 ; 2c767b0d
	v_mac_f32_e32 v59, v12, v34                                 ; 2c76450c
	v_mul_f32_e32 v59, v59, v45                                 ; 0a765b3b
	v_mac_f32_e32 v59, v56, v43                                 ; 2c765738
	v_mac_f32_e32 v59, v52, v46                                 ; 2c765d34
	v_mac_f32_e32 v59, v49, v37                                 ; 2c764b31
	v_mac_f32_e32 v5, v40, v59                                  ; 2c0a7728
	s_cbranch_scc0 BB100                                        ; bf84024a
BB79:
	s_add_u32 s0, s16, 2                                        ; 80008210
	s_mul_i32 s0, s0, s3                                        ; 92000300
	s_add_u32 s0, s19, s0                                       ; 80000013
	v_add_u32_e32 v32, s0, v0                                   ; 68400000
	v_lshlrev_b32_e32 v33, 4, v32                               ; 24424084
	v_lshl_add_u32 v32, v32, 7, v33                             ; d1fd0020 04850f20
	v_add_u32_e32 v34, 16, v32                                  ; 68444090
	v_add_u32_e32 v35, v34, v4                                  ; 68460922
	v_add_u32_e32 v34, v34, v36                                 ; 68444922
	buffer_load_dwordx4 v[40:43], v32, s[12:15], 0 offen        ; e05c1000 80032820
	buffer_load_dword v35, v35, s[12:15], 0 offen               ; e0501000 80032323
	buffer_load_dword v34, v34, s[12:15], 0 offen               ; e0501000 80032222
	s_mov_b32 s1, 0xf0f0f0f                                     ; be8100ff 0f0f0f0f
	s_cmp_lt_u32 3, s4                                          ; bf0a0483
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_bfe_u32 v43, v43, v2, 16                                  ; d1c8002b 0242052b
	v_cndmask_b32_sdwa v37, v41, v41, vcc dst_sel:WORD_0 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 004a52f9 06051429
	v_cndmask_b32_sdwa v37, v42, v42, vcc dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 004a54f9 0605152a
	v_lshl_or_b32 v43, v43, 12, v43                             ; d200002b 04ad192b
	v_and_b32_e32 v38, 0xc0c0c0c0, v37                          ; 264c4aff c0c0c0c0
	v_and_b32_e32 v37, 0x3f3f3f3f, v37                          ; 264a4aff 3f3f3f3f
	v_cvt_f32_f16_sdwa v47, v40 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e5e16f9 00050628
	v_lshrrev_b32_e32 v38, 2, v38                               ; 204c4c82
	v_cvt_f32_ubyte1_e32 v46, v37                               ; 7e5c2525
	v_cvt_f32_f16_e32 v40, v40                                  ; 7e501728
	v_cvt_f32_ubyte3_e32 v42, v37                               ; 7e542925
	v_cvt_f32_ubyte2_e32 v44, v37                               ; 7e582725
	v_cvt_f32_ubyte0_e32 v37, v37                               ; 7e4a2325
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v48, s1, v35                                  ; 26604601
	v_and_or_b32 v43, s1, v43, v38                              ; d201002b 049a5601
	v_cvt_f32_ubyte3_e32 v49, v48                               ; 7e622930
	v_cvt_f32_ubyte1_e32 v51, v48                               ; 7e662530
	v_cvt_f32_ubyte2_e32 v50, v48                               ; 7e642730
	v_cvt_f32_ubyte0_e32 v48, v48                               ; 7e602330
	v_cvt_f32_ubyte3_e32 v39, v43                               ; 7e4e292b
	v_cvt_f32_ubyte2_e32 v41, v43                               ; 7e52272b
	v_cvt_f32_ubyte1_e32 v45, v43                               ; 7e5a252b
	v_cvt_f32_ubyte0_e32 v43, v43                               ; 7e56232b
	v_lshrrev_b32_e32 v35, 4, v35                               ; 20464684
	v_mul_f32_e32 v49, v19, v49                                 ; 0a626313
	v_mul_f32_e32 v39, v31, v39                                 ; 0a4e4f1f
	v_and_b32_e32 v35, s1, v35                                  ; 26464601
	v_mac_f32_e32 v49, v18, v50                                 ; 2c626512
	v_mac_f32_e32 v39, v30, v41                                 ; 2c4e531e
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v55, s1, v34                                  ; 266e4401
	v_cvt_f32_ubyte3_e32 v52, v35                               ; 7e682923
	v_cvt_f32_ubyte2_e32 v53, v35                               ; 7e6a2723
	v_cvt_f32_ubyte1_e32 v54, v35                               ; 7e6c2523
	v_cvt_f32_ubyte0_e32 v35, v35                               ; 7e462323
	v_mac_f32_e32 v49, v17, v51                                 ; 2c626711
	v_mac_f32_e32 v39, v29, v42                                 ; 2c4e551d
	v_cvt_f32_ubyte2_e32 v57, v55                               ; 7e722737
	v_cvt_f32_ubyte3_e32 v56, v55                               ; 7e702937
	v_mul_f32_e32 v52, v23, v52                                 ; 0a686917
	v_cvt_f32_ubyte1_e32 v58, v55                               ; 7e742537
	v_cvt_f32_ubyte0_e32 v55, v55                               ; 7e6e2337
	v_mac_f32_e32 v49, v16, v48                                 ; 2c626110
	v_lshrrev_b32_e32 v34, 4, v34                               ; 20444484
	v_mac_f32_e32 v39, v28, v44                                 ; 2c4e591c
	v_mul_f32_e32 v56, v27, v56                                 ; 0a70711b
	v_mac_f32_e32 v52, v22, v53                                 ; 2c686b16
	v_and_b32_e32 v34, s1, v34                                  ; 26444401
	v_mad_f32 v6, -v47, v39, v6                                 ; d1c10006 241a4f2f
	v_mac_f32_e32 v56, v26, v57                                 ; 2c70731a
	v_mac_f32_e32 v52, v21, v54                                 ; 2c686d15
	v_cvt_f32_ubyte1_e32 v61, v34                               ; 7e7a2522
	v_cvt_f32_ubyte2_e32 v60, v34                               ; 7e782722
	v_cvt_f32_ubyte3_e32 v59, v34                               ; 7e762922
	v_cvt_f32_ubyte0_e32 v34, v34                               ; 7e442322
	v_mac_f32_e32 v56, v25, v58                                 ; 2c707519
	v_mac_f32_e32 v52, v20, v35                                 ; 2c684714
	v_mul_f32_e32 v59, v15, v59                                 ; 0a76770f
	v_mac_f32_e32 v56, v24, v55                                 ; 2c706f18
	v_mac_f32_e32 v59, v14, v60                                 ; 2c76790e
	v_mac_f32_e32 v59, v13, v61                                 ; 2c767b0d
	v_mac_f32_e32 v59, v12, v34                                 ; 2c76450c
	v_mul_f32_e32 v59, v59, v45                                 ; 0a765b3b
	v_mac_f32_e32 v59, v56, v43                                 ; 2c765738
	v_mac_f32_e32 v59, v52, v46                                 ; 2c765d34
	v_mac_f32_e32 v59, v49, v37                                 ; 2c764b31
	v_mac_f32_e32 v6, v40, v59                                  ; 2c0c7728
	s_cbranch_scc0 BB100                                        ; bf8401e8
BB80:
	s_add_u32 s0, s16, 3                                        ; 80008310
	s_mul_i32 s0, s0, s3                                        ; 92000300
	s_add_u32 s0, s19, s0                                       ; 80000013
	v_add_u32_e32 v32, s0, v0                                   ; 68400000
	v_lshlrev_b32_e32 v33, 4, v32                               ; 24424084
	v_lshl_add_u32 v32, v32, 7, v33                             ; d1fd0020 04850f20
	v_add_u32_e32 v34, 16, v32                                  ; 68444090
	v_add_u32_e32 v35, v34, v4                                  ; 68460922
	v_add_u32_e32 v34, v34, v36                                 ; 68444922
	buffer_load_dwordx4 v[40:43], v32, s[12:15], 0 offen        ; e05c1000 80032820
	buffer_load_dword v35, v35, s[12:15], 0 offen               ; e0501000 80032323
	buffer_load_dword v34, v34, s[12:15], 0 offen               ; e0501000 80032222
	s_mov_b32 s1, 0xf0f0f0f                                     ; be8100ff 0f0f0f0f
	s_cmp_lt_u32 4, s4                                          ; bf0a0484
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_bfe_u32 v43, v43, v2, 16                                  ; d1c8002b 0242052b
	v_cndmask_b32_sdwa v37, v41, v41, vcc dst_sel:WORD_0 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 004a52f9 06051429
	v_cndmask_b32_sdwa v37, v42, v42, vcc dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 004a54f9 0605152a
	v_lshl_or_b32 v43, v43, 12, v43                             ; d200002b 04ad192b
	v_and_b32_e32 v38, 0xc0c0c0c0, v37                          ; 264c4aff c0c0c0c0
	v_and_b32_e32 v37, 0x3f3f3f3f, v37                          ; 264a4aff 3f3f3f3f
	v_cvt_f32_f16_sdwa v47, v40 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e5e16f9 00050628
	v_lshrrev_b32_e32 v38, 2, v38                               ; 204c4c82
	v_cvt_f32_ubyte1_e32 v46, v37                               ; 7e5c2525
	v_cvt_f32_f16_e32 v40, v40                                  ; 7e501728
	v_cvt_f32_ubyte3_e32 v42, v37                               ; 7e542925
	v_cvt_f32_ubyte2_e32 v44, v37                               ; 7e582725
	v_cvt_f32_ubyte0_e32 v37, v37                               ; 7e4a2325
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v48, s1, v35                                  ; 26604601
	v_and_or_b32 v43, s1, v43, v38                              ; d201002b 049a5601
	v_cvt_f32_ubyte3_e32 v49, v48                               ; 7e622930
	v_cvt_f32_ubyte1_e32 v51, v48                               ; 7e662530
	v_cvt_f32_ubyte2_e32 v50, v48                               ; 7e642730
	v_cvt_f32_ubyte0_e32 v48, v48                               ; 7e602330
	v_cvt_f32_ubyte3_e32 v39, v43                               ; 7e4e292b
	v_cvt_f32_ubyte2_e32 v41, v43                               ; 7e52272b
	v_cvt_f32_ubyte1_e32 v45, v43                               ; 7e5a252b
	v_cvt_f32_ubyte0_e32 v43, v43                               ; 7e56232b
	v_lshrrev_b32_e32 v35, 4, v35                               ; 20464684
	v_mul_f32_e32 v49, v19, v49                                 ; 0a626313
	v_mul_f32_e32 v39, v31, v39                                 ; 0a4e4f1f
	v_and_b32_e32 v35, s1, v35                                  ; 26464601
	v_mac_f32_e32 v49, v18, v50                                 ; 2c626512
	v_mac_f32_e32 v39, v30, v41                                 ; 2c4e531e
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v55, s1, v34                                  ; 266e4401
	v_cvt_f32_ubyte3_e32 v52, v35                               ; 7e682923
	v_cvt_f32_ubyte2_e32 v53, v35                               ; 7e6a2723
	v_cvt_f32_ubyte1_e32 v54, v35                               ; 7e6c2523
	v_cvt_f32_ubyte0_e32 v35, v35                               ; 7e462323
	v_mac_f32_e32 v49, v17, v51                                 ; 2c626711
	v_mac_f32_e32 v39, v29, v42                                 ; 2c4e551d
	v_cvt_f32_ubyte2_e32 v57, v55                               ; 7e722737
	v_cvt_f32_ubyte3_e32 v56, v55                               ; 7e702937
	v_mul_f32_e32 v52, v23, v52                                 ; 0a686917
	v_cvt_f32_ubyte1_e32 v58, v55                               ; 7e742537
	v_cvt_f32_ubyte0_e32 v55, v55                               ; 7e6e2337
	v_mac_f32_e32 v49, v16, v48                                 ; 2c626110
	v_lshrrev_b32_e32 v34, 4, v34                               ; 20444484
	v_mac_f32_e32 v39, v28, v44                                 ; 2c4e591c
	v_mul_f32_e32 v56, v27, v56                                 ; 0a70711b
	v_mac_f32_e32 v52, v22, v53                                 ; 2c686b16
	v_and_b32_e32 v34, s1, v34                                  ; 26444401
	v_mad_f32 v7, -v47, v39, v7                                 ; d1c10007 241e4f2f
	v_mac_f32_e32 v56, v26, v57                                 ; 2c70731a
	v_mac_f32_e32 v52, v21, v54                                 ; 2c686d15
	v_cvt_f32_ubyte1_e32 v61, v34                               ; 7e7a2522
	v_cvt_f32_ubyte2_e32 v60, v34                               ; 7e782722
	v_cvt_f32_ubyte3_e32 v59, v34                               ; 7e762922
	v_cvt_f32_ubyte0_e32 v34, v34                               ; 7e442322
	v_mac_f32_e32 v56, v25, v58                                 ; 2c707519
	v_mac_f32_e32 v52, v20, v35                                 ; 2c684714
	v_mul_f32_e32 v59, v15, v59                                 ; 0a76770f
	v_mac_f32_e32 v56, v24, v55                                 ; 2c706f18
	v_mac_f32_e32 v59, v14, v60                                 ; 2c76790e
	v_mac_f32_e32 v59, v13, v61                                 ; 2c767b0d
	v_mac_f32_e32 v59, v12, v34                                 ; 2c76450c
	v_mul_f32_e32 v59, v59, v45                                 ; 0a765b3b
	v_mac_f32_e32 v59, v56, v43                                 ; 2c765738
	v_mac_f32_e32 v59, v52, v46                                 ; 2c765d34
	v_mac_f32_e32 v59, v49, v37                                 ; 2c764b31
	v_mac_f32_e32 v7, v40, v59                                  ; 2c0e7728
	s_cbranch_scc0 BB100                                        ; bf840186
BB81:
	s_add_u32 s0, s16, 4                                        ; 80008410
	s_mul_i32 s0, s0, s3                                        ; 92000300
	s_add_u32 s0, s19, s0                                       ; 80000013
	v_add_u32_e32 v32, s0, v0                                   ; 68400000
	v_lshlrev_b32_e32 v33, 4, v32                               ; 24424084
	v_lshl_add_u32 v32, v32, 7, v33                             ; d1fd0020 04850f20
	v_add_u32_e32 v34, 16, v32                                  ; 68444090
	v_add_u32_e32 v35, v34, v4                                  ; 68460922
	v_add_u32_e32 v34, v34, v36                                 ; 68444922
	buffer_load_dwordx4 v[40:43], v32, s[12:15], 0 offen        ; e05c1000 80032820
	buffer_load_dword v35, v35, s[12:15], 0 offen               ; e0501000 80032323
	buffer_load_dword v34, v34, s[12:15], 0 offen               ; e0501000 80032222
	s_mov_b32 s1, 0xf0f0f0f                                     ; be8100ff 0f0f0f0f
	s_cmp_lt_u32 5, s4                                          ; bf0a0485
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_bfe_u32 v43, v43, v2, 16                                  ; d1c8002b 0242052b
	v_cndmask_b32_sdwa v37, v41, v41, vcc dst_sel:WORD_0 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 004a52f9 06051429
	v_cndmask_b32_sdwa v37, v42, v42, vcc dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 004a54f9 0605152a
	v_lshl_or_b32 v43, v43, 12, v43                             ; d200002b 04ad192b
	v_and_b32_e32 v38, 0xc0c0c0c0, v37                          ; 264c4aff c0c0c0c0
	v_and_b32_e32 v37, 0x3f3f3f3f, v37                          ; 264a4aff 3f3f3f3f
	v_cvt_f32_f16_sdwa v47, v40 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e5e16f9 00050628
	v_lshrrev_b32_e32 v38, 2, v38                               ; 204c4c82
	v_cvt_f32_ubyte1_e32 v46, v37                               ; 7e5c2525
	v_cvt_f32_f16_e32 v40, v40                                  ; 7e501728
	v_cvt_f32_ubyte3_e32 v42, v37                               ; 7e542925
	v_cvt_f32_ubyte2_e32 v44, v37                               ; 7e582725
	v_cvt_f32_ubyte0_e32 v37, v37                               ; 7e4a2325
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v48, s1, v35                                  ; 26604601
	v_and_or_b32 v43, s1, v43, v38                              ; d201002b 049a5601
	v_cvt_f32_ubyte3_e32 v49, v48                               ; 7e622930
	v_cvt_f32_ubyte1_e32 v51, v48                               ; 7e662530
	v_cvt_f32_ubyte2_e32 v50, v48                               ; 7e642730
	v_cvt_f32_ubyte0_e32 v48, v48                               ; 7e602330
	v_cvt_f32_ubyte3_e32 v39, v43                               ; 7e4e292b
	v_cvt_f32_ubyte2_e32 v41, v43                               ; 7e52272b
	v_cvt_f32_ubyte1_e32 v45, v43                               ; 7e5a252b
	v_cvt_f32_ubyte0_e32 v43, v43                               ; 7e56232b
	v_lshrrev_b32_e32 v35, 4, v35                               ; 20464684
	v_mul_f32_e32 v49, v19, v49                                 ; 0a626313
	v_mul_f32_e32 v39, v31, v39                                 ; 0a4e4f1f
	v_and_b32_e32 v35, s1, v35                                  ; 26464601
	v_mac_f32_e32 v49, v18, v50                                 ; 2c626512
	v_mac_f32_e32 v39, v30, v41                                 ; 2c4e531e
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v55, s1, v34                                  ; 266e4401
	v_cvt_f32_ubyte3_e32 v52, v35                               ; 7e682923
	v_cvt_f32_ubyte2_e32 v53, v35                               ; 7e6a2723
	v_cvt_f32_ubyte1_e32 v54, v35                               ; 7e6c2523
	v_cvt_f32_ubyte0_e32 v35, v35                               ; 7e462323
	v_mac_f32_e32 v49, v17, v51                                 ; 2c626711
	v_mac_f32_e32 v39, v29, v42                                 ; 2c4e551d
	v_cvt_f32_ubyte2_e32 v57, v55                               ; 7e722737
	v_cvt_f32_ubyte3_e32 v56, v55                               ; 7e702937
	v_mul_f32_e32 v52, v23, v52                                 ; 0a686917
	v_cvt_f32_ubyte1_e32 v58, v55                               ; 7e742537
	v_cvt_f32_ubyte0_e32 v55, v55                               ; 7e6e2337
	v_mac_f32_e32 v49, v16, v48                                 ; 2c626110
	v_lshrrev_b32_e32 v34, 4, v34                               ; 20444484
	v_mac_f32_e32 v39, v28, v44                                 ; 2c4e591c
	v_mul_f32_e32 v56, v27, v56                                 ; 0a70711b
	v_mac_f32_e32 v52, v22, v53                                 ; 2c686b16
	v_and_b32_e32 v34, s1, v34                                  ; 26444401
	v_mad_f32 v8, -v47, v39, v8                                 ; d1c10008 24224f2f
	v_mac_f32_e32 v56, v26, v57                                 ; 2c70731a
	v_mac_f32_e32 v52, v21, v54                                 ; 2c686d15
	v_cvt_f32_ubyte1_e32 v61, v34                               ; 7e7a2522
	v_cvt_f32_ubyte2_e32 v60, v34                               ; 7e782722
	v_cvt_f32_ubyte3_e32 v59, v34                               ; 7e762922
	v_cvt_f32_ubyte0_e32 v34, v34                               ; 7e442322
	v_mac_f32_e32 v56, v25, v58                                 ; 2c707519
	v_mac_f32_e32 v52, v20, v35                                 ; 2c684714
	v_mul_f32_e32 v59, v15, v59                                 ; 0a76770f
	v_mac_f32_e32 v56, v24, v55                                 ; 2c706f18
	v_mac_f32_e32 v59, v14, v60                                 ; 2c76790e
	v_mac_f32_e32 v59, v13, v61                                 ; 2c767b0d
	v_mac_f32_e32 v59, v12, v34                                 ; 2c76450c
	v_mul_f32_e32 v59, v59, v45                                 ; 0a765b3b
	v_mac_f32_e32 v59, v56, v43                                 ; 2c765738
	v_mac_f32_e32 v59, v52, v46                                 ; 2c765d34
	v_mac_f32_e32 v59, v49, v37                                 ; 2c764b31
	v_mac_f32_e32 v8, v40, v59                                  ; 2c107728
	s_cbranch_scc0 BB100                                        ; bf840124
BB82:
	s_add_u32 s0, s16, 5                                        ; 80008510
	s_mul_i32 s0, s0, s3                                        ; 92000300
	s_add_u32 s0, s19, s0                                       ; 80000013
	v_add_u32_e32 v32, s0, v0                                   ; 68400000
	v_lshlrev_b32_e32 v33, 4, v32                               ; 24424084
	v_lshl_add_u32 v32, v32, 7, v33                             ; d1fd0020 04850f20
	v_add_u32_e32 v34, 16, v32                                  ; 68444090
	v_add_u32_e32 v35, v34, v4                                  ; 68460922
	v_add_u32_e32 v34, v34, v36                                 ; 68444922
	buffer_load_dwordx4 v[40:43], v32, s[12:15], 0 offen        ; e05c1000 80032820
	buffer_load_dword v35, v35, s[12:15], 0 offen               ; e0501000 80032323
	buffer_load_dword v34, v34, s[12:15], 0 offen               ; e0501000 80032222
	s_mov_b32 s1, 0xf0f0f0f                                     ; be8100ff 0f0f0f0f
	s_cmp_lt_u32 6, s4                                          ; bf0a0486
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_bfe_u32 v43, v43, v2, 16                                  ; d1c8002b 0242052b
	v_cndmask_b32_sdwa v37, v41, v41, vcc dst_sel:WORD_0 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 004a52f9 06051429
	v_cndmask_b32_sdwa v37, v42, v42, vcc dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 004a54f9 0605152a
	v_lshl_or_b32 v43, v43, 12, v43                             ; d200002b 04ad192b
	v_and_b32_e32 v38, 0xc0c0c0c0, v37                          ; 264c4aff c0c0c0c0
	v_and_b32_e32 v37, 0x3f3f3f3f, v37                          ; 264a4aff 3f3f3f3f
	v_cvt_f32_f16_sdwa v47, v40 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e5e16f9 00050628
	v_lshrrev_b32_e32 v38, 2, v38                               ; 204c4c82
	v_cvt_f32_ubyte1_e32 v46, v37                               ; 7e5c2525
	v_cvt_f32_f16_e32 v40, v40                                  ; 7e501728
	v_cvt_f32_ubyte3_e32 v42, v37                               ; 7e542925
	v_cvt_f32_ubyte2_e32 v44, v37                               ; 7e582725
	v_cvt_f32_ubyte0_e32 v37, v37                               ; 7e4a2325
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v48, s1, v35                                  ; 26604601
	v_and_or_b32 v43, s1, v43, v38                              ; d201002b 049a5601
	v_cvt_f32_ubyte3_e32 v49, v48                               ; 7e622930
	v_cvt_f32_ubyte1_e32 v51, v48                               ; 7e662530
	v_cvt_f32_ubyte2_e32 v50, v48                               ; 7e642730
	v_cvt_f32_ubyte0_e32 v48, v48                               ; 7e602330
	v_cvt_f32_ubyte3_e32 v39, v43                               ; 7e4e292b
	v_cvt_f32_ubyte2_e32 v41, v43                               ; 7e52272b
	v_cvt_f32_ubyte1_e32 v45, v43                               ; 7e5a252b
	v_cvt_f32_ubyte0_e32 v43, v43                               ; 7e56232b
	v_lshrrev_b32_e32 v35, 4, v35                               ; 20464684
	v_mul_f32_e32 v49, v19, v49                                 ; 0a626313
	v_mul_f32_e32 v39, v31, v39                                 ; 0a4e4f1f
	v_and_b32_e32 v35, s1, v35                                  ; 26464601
	v_mac_f32_e32 v49, v18, v50                                 ; 2c626512
	v_mac_f32_e32 v39, v30, v41                                 ; 2c4e531e
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v55, s1, v34                                  ; 266e4401
	v_cvt_f32_ubyte3_e32 v52, v35                               ; 7e682923
	v_cvt_f32_ubyte2_e32 v53, v35                               ; 7e6a2723
	v_cvt_f32_ubyte1_e32 v54, v35                               ; 7e6c2523
	v_cvt_f32_ubyte0_e32 v35, v35                               ; 7e462323
	v_mac_f32_e32 v49, v17, v51                                 ; 2c626711
	v_mac_f32_e32 v39, v29, v42                                 ; 2c4e551d
	v_cvt_f32_ubyte2_e32 v57, v55                               ; 7e722737
	v_cvt_f32_ubyte3_e32 v56, v55                               ; 7e702937
	v_mul_f32_e32 v52, v23, v52                                 ; 0a686917
	v_cvt_f32_ubyte1_e32 v58, v55                               ; 7e742537
	v_cvt_f32_ubyte0_e32 v55, v55                               ; 7e6e2337
	v_mac_f32_e32 v49, v16, v48                                 ; 2c626110
	v_lshrrev_b32_e32 v34, 4, v34                               ; 20444484
	v_mac_f32_e32 v39, v28, v44                                 ; 2c4e591c
	v_mul_f32_e32 v56, v27, v56                                 ; 0a70711b
	v_mac_f32_e32 v52, v22, v53                                 ; 2c686b16
	v_and_b32_e32 v34, s1, v34                                  ; 26444401
	v_mad_f32 v9, -v47, v39, v9                                 ; d1c10009 24264f2f
	v_mac_f32_e32 v56, v26, v57                                 ; 2c70731a
	v_mac_f32_e32 v52, v21, v54                                 ; 2c686d15
	v_cvt_f32_ubyte1_e32 v61, v34                               ; 7e7a2522
	v_cvt_f32_ubyte2_e32 v60, v34                               ; 7e782722
	v_cvt_f32_ubyte3_e32 v59, v34                               ; 7e762922
	v_cvt_f32_ubyte0_e32 v34, v34                               ; 7e442322
	v_mac_f32_e32 v56, v25, v58                                 ; 2c707519
	v_mac_f32_e32 v52, v20, v35                                 ; 2c684714
	v_mul_f32_e32 v59, v15, v59                                 ; 0a76770f
	v_mac_f32_e32 v56, v24, v55                                 ; 2c706f18
	v_mac_f32_e32 v59, v14, v60                                 ; 2c76790e
	v_mac_f32_e32 v59, v13, v61                                 ; 2c767b0d
	v_mac_f32_e32 v59, v12, v34                                 ; 2c76450c
	v_mul_f32_e32 v59, v59, v45                                 ; 0a765b3b
	v_mac_f32_e32 v59, v56, v43                                 ; 2c765738
	v_mac_f32_e32 v59, v52, v46                                 ; 2c765d34
	v_mac_f32_e32 v59, v49, v37                                 ; 2c764b31
	v_mac_f32_e32 v9, v40, v59                                  ; 2c127728
	s_cbranch_scc0 BB100                                        ; bf8400c2
BB83:
	s_add_u32 s0, s16, 6                                        ; 80008610
	s_mul_i32 s0, s0, s3                                        ; 92000300
	s_add_u32 s0, s19, s0                                       ; 80000013
	v_add_u32_e32 v32, s0, v0                                   ; 68400000
	v_lshlrev_b32_e32 v33, 4, v32                               ; 24424084
	v_lshl_add_u32 v32, v32, 7, v33                             ; d1fd0020 04850f20
	v_add_u32_e32 v34, 16, v32                                  ; 68444090
	v_add_u32_e32 v35, v34, v4                                  ; 68460922
	v_add_u32_e32 v34, v34, v36                                 ; 68444922
	buffer_load_dwordx4 v[40:43], v32, s[12:15], 0 offen        ; e05c1000 80032820
	buffer_load_dword v35, v35, s[12:15], 0 offen               ; e0501000 80032323
	buffer_load_dword v34, v34, s[12:15], 0 offen               ; e0501000 80032222
	s_mov_b32 s1, 0xf0f0f0f                                     ; be8100ff 0f0f0f0f
	s_cmp_lt_u32 7, s4                                          ; bf0a0487
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_bfe_u32 v43, v43, v2, 16                                  ; d1c8002b 0242052b
	v_cndmask_b32_sdwa v37, v41, v41, vcc dst_sel:WORD_0 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 004a52f9 06051429
	v_cndmask_b32_sdwa v37, v42, v42, vcc dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 004a54f9 0605152a
	v_lshl_or_b32 v43, v43, 12, v43                             ; d200002b 04ad192b
	v_and_b32_e32 v38, 0xc0c0c0c0, v37                          ; 264c4aff c0c0c0c0
	v_and_b32_e32 v37, 0x3f3f3f3f, v37                          ; 264a4aff 3f3f3f3f
	v_cvt_f32_f16_sdwa v47, v40 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e5e16f9 00050628
	v_lshrrev_b32_e32 v38, 2, v38                               ; 204c4c82
	v_cvt_f32_ubyte1_e32 v46, v37                               ; 7e5c2525
	v_cvt_f32_f16_e32 v40, v40                                  ; 7e501728
	v_cvt_f32_ubyte3_e32 v42, v37                               ; 7e542925
	v_cvt_f32_ubyte2_e32 v44, v37                               ; 7e582725
	v_cvt_f32_ubyte0_e32 v37, v37                               ; 7e4a2325
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v48, s1, v35                                  ; 26604601
	v_and_or_b32 v43, s1, v43, v38                              ; d201002b 049a5601
	v_cvt_f32_ubyte3_e32 v49, v48                               ; 7e622930
	v_cvt_f32_ubyte1_e32 v51, v48                               ; 7e662530
	v_cvt_f32_ubyte2_e32 v50, v48                               ; 7e642730
	v_cvt_f32_ubyte0_e32 v48, v48                               ; 7e602330
	v_cvt_f32_ubyte3_e32 v39, v43                               ; 7e4e292b
	v_cvt_f32_ubyte2_e32 v41, v43                               ; 7e52272b
	v_cvt_f32_ubyte1_e32 v45, v43                               ; 7e5a252b
	v_cvt_f32_ubyte0_e32 v43, v43                               ; 7e56232b
	v_lshrrev_b32_e32 v35, 4, v35                               ; 20464684
	v_mul_f32_e32 v49, v19, v49                                 ; 0a626313
	v_mul_f32_e32 v39, v31, v39                                 ; 0a4e4f1f
	v_and_b32_e32 v35, s1, v35                                  ; 26464601
	v_mac_f32_e32 v49, v18, v50                                 ; 2c626512
	v_mac_f32_e32 v39, v30, v41                                 ; 2c4e531e
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v55, s1, v34                                  ; 266e4401
	v_cvt_f32_ubyte3_e32 v52, v35                               ; 7e682923
	v_cvt_f32_ubyte2_e32 v53, v35                               ; 7e6a2723
	v_cvt_f32_ubyte1_e32 v54, v35                               ; 7e6c2523
	v_cvt_f32_ubyte0_e32 v35, v35                               ; 7e462323
	v_mac_f32_e32 v49, v17, v51                                 ; 2c626711
	v_mac_f32_e32 v39, v29, v42                                 ; 2c4e551d
	v_cvt_f32_ubyte2_e32 v57, v55                               ; 7e722737
	v_cvt_f32_ubyte3_e32 v56, v55                               ; 7e702937
	v_mul_f32_e32 v52, v23, v52                                 ; 0a686917
	v_cvt_f32_ubyte1_e32 v58, v55                               ; 7e742537
	v_cvt_f32_ubyte0_e32 v55, v55                               ; 7e6e2337
	v_mac_f32_e32 v49, v16, v48                                 ; 2c626110
	v_lshrrev_b32_e32 v34, 4, v34                               ; 20444484
	v_mac_f32_e32 v39, v28, v44                                 ; 2c4e591c
	v_mul_f32_e32 v56, v27, v56                                 ; 0a70711b
	v_mac_f32_e32 v52, v22, v53                                 ; 2c686b16
	v_and_b32_e32 v34, s1, v34                                  ; 26444401
	v_mad_f32 v10, -v47, v39, v10                               ; d1c1000a 242a4f2f
	v_mac_f32_e32 v56, v26, v57                                 ; 2c70731a
	v_mac_f32_e32 v52, v21, v54                                 ; 2c686d15
	v_cvt_f32_ubyte1_e32 v61, v34                               ; 7e7a2522
	v_cvt_f32_ubyte2_e32 v60, v34                               ; 7e782722
	v_cvt_f32_ubyte3_e32 v59, v34                               ; 7e762922
	v_cvt_f32_ubyte0_e32 v34, v34                               ; 7e442322
	v_mac_f32_e32 v56, v25, v58                                 ; 2c707519
	v_mac_f32_e32 v52, v20, v35                                 ; 2c684714
	v_mul_f32_e32 v59, v15, v59                                 ; 0a76770f
	v_mac_f32_e32 v56, v24, v55                                 ; 2c706f18
	v_mac_f32_e32 v59, v14, v60                                 ; 2c76790e
	v_mac_f32_e32 v59, v13, v61                                 ; 2c767b0d
	v_mac_f32_e32 v59, v12, v34                                 ; 2c76450c
	v_mul_f32_e32 v59, v59, v45                                 ; 0a765b3b
	v_mac_f32_e32 v59, v56, v43                                 ; 2c765738
	v_mac_f32_e32 v59, v52, v46                                 ; 2c765d34
	v_mac_f32_e32 v59, v49, v37                                 ; 2c764b31
	v_mac_f32_e32 v10, v40, v59                                 ; 2c147728
	s_cbranch_scc0 BB100                                        ; bf840060
BB84:
	s_add_u32 s0, s16, 7                                        ; 80008710
	s_mul_i32 s0, s0, s3                                        ; 92000300
	s_add_u32 s0, s19, s0                                       ; 80000013
	v_add_u32_e32 v32, s0, v0                                   ; 68400000
	v_lshlrev_b32_e32 v33, 4, v32                               ; 24424084
	v_lshl_add_u32 v32, v32, 7, v33                             ; d1fd0020 04850f20
	v_add_u32_e32 v34, 16, v32                                  ; 68444090
	v_add_u32_e32 v35, v34, v4                                  ; 68460922
	v_add_u32_e32 v34, v34, v36                                 ; 68444922
	buffer_load_dwordx4 v[36:39], v32, s[12:15], 0 offen        ; e05c1000 80032420
	buffer_load_dword v35, v35, s[12:15], 0 offen               ; e0501000 80032323
	buffer_load_dword v34, v34, s[12:15], 0 offen               ; e0501000 80032222
	s_mov_b32 s1, 0xf0f0f0f                                     ; be8100ff 0f0f0f0f
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_bfe_u32 v39, v39, v2, 16                                  ; d1c80027 02420527
	v_cndmask_b32_sdwa v37, v37, v37, vcc dst_sel:WORD_0 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 004a4af9 06051425
	v_cndmask_b32_sdwa v37, v38, v38, vcc dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 004a4cf9 06051526
	v_lshl_or_b32 v39, v39, 12, v39                             ; d2000027 049d1927
	v_and_b32_e32 v38, 0xc0c0c0c0, v37                          ; 264c4aff c0c0c0c0
	v_and_b32_e32 v37, 0x3f3f3f3f, v37                          ; 264a4aff 3f3f3f3f
	v_cvt_f32_f16_sdwa v46, v36 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e5c16f9 00050624
	v_lshrrev_b32_e32 v38, 2, v38                               ; 204c4c82
	v_cvt_f32_f16_e32 v36, v36                                  ; 7e481724
	v_cvt_f32_ubyte3_e32 v42, v37                               ; 7e542925
	v_cvt_f32_ubyte2_e32 v43, v37                               ; 7e562725
	v_cvt_f32_ubyte1_e32 v45, v37                               ; 7e5a2525
	v_cvt_f32_ubyte0_e32 v37, v37                               ; 7e4a2325
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v47, s1, v35                                  ; 265e4601
	v_and_or_b32 v39, s1, v39, v38                              ; d2010027 049a4e01
	v_cvt_f32_ubyte1_e32 v50, v47                               ; 7e64252f
	v_cvt_f32_ubyte3_e32 v48, v47                               ; 7e60292f
	v_cvt_f32_ubyte2_e32 v49, v47                               ; 7e62272f
	v_cvt_f32_ubyte0_e32 v47, v47                               ; 7e5e232f
	v_cvt_f32_ubyte3_e32 v40, v39                               ; 7e502927
	v_cvt_f32_ubyte2_e32 v41, v39                               ; 7e522727
	v_cvt_f32_ubyte1_e32 v44, v39                               ; 7e582527
	v_cvt_f32_ubyte0_e32 v39, v39                               ; 7e4e2327
	v_lshrrev_b32_e32 v35, 4, v35                               ; 20464684
	v_mul_f32_e32 v19, v19, v48                                 ; 0a266113
	v_mul_f32_e32 v31, v31, v40                                 ; 0a3e511f
	v_and_b32_e32 v35, s1, v35                                  ; 26464601
	v_mac_f32_e32 v19, v18, v49                                 ; 2c266312
	v_mac_f32_e32 v31, v30, v41                                 ; 2c3e531e
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v54, s1, v34                                  ; 266c4401
	v_cvt_f32_ubyte3_e32 v51, v35                               ; 7e662923
	v_cvt_f32_ubyte2_e32 v52, v35                               ; 7e682723
	v_cvt_f32_ubyte1_e32 v53, v35                               ; 7e6a2523
	v_cvt_f32_ubyte0_e32 v35, v35                               ; 7e462323
	v_mac_f32_e32 v19, v17, v50                                 ; 2c266511
	v_mac_f32_e32 v31, v29, v42                                 ; 2c3e551d
	v_cvt_f32_ubyte2_e32 v56, v54                               ; 7e702736
	v_cvt_f32_ubyte3_e32 v55, v54                               ; 7e6e2936
	v_mul_f32_e32 v23, v23, v51                                 ; 0a2e6717
	v_cvt_f32_ubyte1_e32 v57, v54                               ; 7e722536
	v_cvt_f32_ubyte0_e32 v54, v54                               ; 7e6c2336
	v_mac_f32_e32 v19, v16, v47                                 ; 2c265f10
	v_lshrrev_b32_e32 v34, 4, v34                               ; 20444484
	v_mac_f32_e32 v31, v28, v43                                 ; 2c3e571c
	v_mul_f32_e32 v27, v27, v55                                 ; 0a366f1b
	v_mac_f32_e32 v23, v22, v52                                 ; 2c2e6916
	v_and_b32_e32 v34, s1, v34                                  ; 26444401
	v_mad_f32 v11, -v46, v31, v11                               ; d1c1000b 242e3f2e
	v_mac_f32_e32 v27, v26, v56                                 ; 2c36711a
	v_mac_f32_e32 v23, v21, v53                                 ; 2c2e6b15
	v_cvt_f32_ubyte1_e32 v60, v34                               ; 7e782522
	v_cvt_f32_ubyte2_e32 v59, v34                               ; 7e762722
	v_cvt_f32_ubyte3_e32 v58, v34                               ; 7e742922
	v_cvt_f32_ubyte0_e32 v34, v34                               ; 7e442322
	v_mac_f32_e32 v27, v25, v57                                 ; 2c367319
	v_mac_f32_e32 v23, v20, v35                                 ; 2c2e4714
	v_mul_f32_e32 v15, v15, v58                                 ; 0a1e750f
	v_mac_f32_e32 v27, v24, v54                                 ; 2c366d18
	v_mac_f32_e32 v15, v14, v59                                 ; 2c1e770e
	v_mac_f32_e32 v15, v13, v60                                 ; 2c1e790d
	v_mac_f32_e32 v15, v12, v34                                 ; 2c1e450c
	v_mul_f32_e32 v15, v15, v44                                 ; 0a1e590f
	v_mac_f32_e32 v15, v27, v39                                 ; 2c1e4f1b
	v_mac_f32_e32 v15, v23, v45                                 ; 2c1e5b17
	v_mac_f32_e32 v15, v19, v37                                 ; 2c1e4b13
	v_mac_f32_e32 v11, v36, v15                                 ; 2c161f24
BB100:
	v_add_u32_e32 v0, 4, v0                                     ; 68000084
	s_branch BB71                                               ; bf82fcbc
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
	s_cbranch_scc0 BB121                                        ; bf8400a0
BB104:
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
	s_cbranch_scc0 BB119                                        ; bf840085
BB105:
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
	s_cbranch_scc0 BB117                                        ; bf84006a
BB106:
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
	s_cbranch_scc0 BB115                                        ; bf84004f
BB107:
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
	s_cbranch_scc0 BB113                                        ; bf840034
BB108:
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
	s_cbranch_scc0 BB111                                        ; bf840019
BB109:
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
BB111:
	v_mov_b32_e32 v10, s12                                      ; 7e14020c
BB113:
	v_mov_b32_e32 v9, s11                                       ; 7e12020b
BB115:
	v_mov_b32_e32 v8, s10                                       ; 7e10020a
BB117:
	v_mov_b32_e32 v7, s9                                        ; 7e0e0209
BB119:
	v_mov_b32_e32 v6, s6                                        ; 7e0c0206
BB121:
	v_mov_b32_e32 v5, s5                                        ; 7e0a0205
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
	v_add_f32_e32 v5, s5, v5                                    ; 020a0a05
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
	v_add_f32_e32 v5, s5, v5                                    ; 020a0a05
	s_branch BB139                                              ; bf820001
BB138:
	s_mov_b32 s0, src_scc                                       ; be8000fd
BB139:
	s_add_u32 s5, s7, 4                                         ; 80058407
	buffer_store_dword v5, off, s[8:11], s5                     ; e0700000 05020580
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
	v_add_f32_e32 v6, s5, v6                                    ; 020c0c05
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
	v_add_f32_e32 v6, s5, v6                                    ; 020c0c05
	s_branch BB146                                              ; bf820001
BB145:
	s_mov_b32 s0, src_scc                                       ; be8000fd
BB146:
	s_add_u32 s5, s7, 8                                         ; 80058807
	buffer_store_dword v6, off, s[8:11], s5                     ; e0700000 05020680
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
	v_add_f32_e32 v7, s5, v7                                    ; 020e0e05
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
	v_add_f32_e32 v7, s5, v7                                    ; 020e0e05
	s_branch BB153                                              ; bf820001
BB152:
	s_mov_b32 s0, src_scc                                       ; be8000fd
BB153:
	s_add_u32 s5, s7, 12                                        ; 80058c07
	buffer_store_dword v7, off, s[8:11], s5                     ; e0700000 05020780
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
	v_add_f32_e32 v8, s5, v8                                    ; 02101005
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
	v_add_f32_e32 v8, s5, v8                                    ; 02101005
	s_branch BB160                                              ; bf820001
BB159:
	s_mov_b32 s0, src_scc                                       ; be8000fd
BB160:
	s_add_u32 s5, s7, 16                                        ; 80059007
	buffer_store_dword v8, off, s[8:11], s5                     ; e0700000 05020880
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
	v_add_f32_e32 v9, s5, v9                                    ; 02121205
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
	v_add_f32_e32 v9, s5, v9                                    ; 02121205
	s_branch BB167                                              ; bf820001
BB166:
	s_mov_b32 s0, src_scc                                       ; be8000fd
BB167:
	s_add_u32 s5, s7, 20                                        ; 80059407
	buffer_store_dword v9, off, s[8:11], s5                     ; e0700000 05020980
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
	v_add_f32_e32 v10, s5, v10                                  ; 02141405
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
	v_add_f32_e32 v10, s5, v10                                  ; 02141405
	s_branch BB174                                              ; bf820001
BB173:
	s_mov_b32 s0, src_scc                                       ; be8000fd
BB174:
	s_add_u32 s5, s7, 24                                        ; 80059807
	buffer_store_dword v10, off, s[8:11], s5                    ; e0700000 05020a80
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
	v_add_f32_e32 v11, s1, v11                                  ; 02161601
BB178:
	s_cmp_lg_i32 s0, 0                                          ; bf018000
	s_cbranch_scc0 BB181                                        ; bf840008
BB179:
	s_load_dwordx4 s[0:3], s[2:3], 0x40                         ; c00a0001 00000040
	s_add_u32 s4, s7, 28                                        ; 80049c07
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s4, s[0:3], s4                          ; c0200100 00000004
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v11, s4, v11                                  ; 02161604
BB181:
	s_add_u32 s7, s7, 28                                        ; 80079c07
	buffer_store_dword v11, off, s[8:11], s7                    ; e0700000 07020b80
BB203:
	s_endpgm                                                    ; bf810000
