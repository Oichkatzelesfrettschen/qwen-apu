BB0:
	s_load_dword s0, s[14:15], 0x0                              ; c0020007 00000000
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_mul_i32 s0, s0, s18                                       ; 92001200
	s_add_u32 s16, s16, s0                                      ; 80100010
	s_lshl_b32 s16, s16, 2                                      ; 8e108210
	s_add_u32 s1, s16, 4                                        ; 80018410
	s_cmp_ge_u32 s4, s1                                         ; bf090104
	s_cbranch_scc0 BB42                                         ; bf8402f0
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
	v_mov_b32_e32 v6, 0                                         ; 7e0c0280
	s_mul_i32 s18, s18, s5                                      ; 92120512
	v_mov_b32_e32 v7, 0                                         ; 7e0e0280
	v_mov_b32_e32 v8, 0                                         ; 7e100280
	v_sub_u32_e32 v1, v2, v1                                    ; 6a020302
	v_bfe_u32 v3, v2, 2, 1                                      ; d1c80003 02050502
	v_lshrrev_b32_e32 v2, 3, v2                                 ; 20040483
	v_lshl_add_u32 v1, v1, 1, v3                                ; d1fd0001 040d0301
	v_mov_b32_e32 v3, 0                                         ; 7e060280
	v_lshlrev_b32_e32 v1, 2, v1                                 ; 24020282
	v_lshl_add_u32 v4, v2, 5, v1                                ; d1fd0004 04050b02
	v_lshl_add_u32 v1, v2, 6, v1                                ; d1fd0001 04050d02
	v_lshlrev_b32_e32 v2, 4, v2                                 ; 24040484
	v_sub_u32_e32 v5, 16, v2                                    ; 6a0a0490
	s_branch BB5                                                ; bf8201a5
BB10:
	s_mov_b64 exec, s[0:1]                                      ; befe0100
	s_mov_b32 s0, s2                                            ; be800002
	s_movk_i32 s1, 0x8000                                       ; b0018000
	s_load_dwordx8 s[24:31], s[0:1], 0x0                        ; c00e0600 00000000
	s_mul_i32 s0, s6, s17                                       ; 92001106
	v_lshl_add_u32 v9, v0, 8, v1                                ; d1fd0009 04051100
	v_add_u32_e32 v10, s0, v9                                   ; 68141200
	v_add_u32_e32 v9, 0x80, v9                                  ; 681212ff 00000080
	v_lshrrev_b32_e32 v10, 2, v10                               ; 20141482
	v_add_u32_e32 v9, s0, v9                                    ; 68121200
	v_lshlrev_b32_e32 v10, 4, v10                               ; 24141484
	v_lshrrev_b32_e32 v9, 2, v9                                 ; 20121282
	v_lshlrev_b32_e32 v9, 4, v9                                 ; 24121284
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_load_dwordx4 v[12:15], v10, s[28:31], 0 offen        ; e05c1000 80070c0a
	buffer_load_dwordx4 v[16:19], v10, s[28:31], 0 offen offset:128 ; e05c1080 8007100a
	buffer_load_dwordx4 v[20:23], v9, s[28:31], 0 offen         ; e05c1000 80071409
	buffer_load_dwordx4 v[24:27], v9, s[28:31], 0 offen offset:128 ; e05c1080 80071809
	s_mul_i32 s1, s16, s3                                       ; 92010310
	v_add_u32_e32 v31, 64, v4                                   ; 683e08c0
	s_add_u32 s1, s18, s1                                       ; 80010112
	s_add_u32 s4, s16, 1                                        ; 80048110
	v_add_u32_e32 v11, s1, v0                                   ; 68160001
	s_mul_i32 s4, s4, s3                                        ; 92040304
	v_lshlrev_b32_e32 v28, 4, v11                               ; 24381684
	s_add_u32 s4, s18, s4                                       ; 80040412
	s_add_u32 s5, s16, 2                                        ; 80058210
	v_lshl_add_u32 v11, v11, 7, v28                             ; d1fd000b 04710f0b
	v_add_u32_e32 v32, s4, v0                                   ; 68400004
	s_mul_i32 s5, s5, s3                                        ; 92050305
	v_add_u32_e32 v29, 16, v11                                  ; 683a1690
	v_lshlrev_b32_e32 v33, 4, v32                               ; 24424084
	s_add_u32 s5, s18, s5                                       ; 80050512
	s_add_u32 s9, s16, 3                                        ; 80098310
	v_add_u32_e32 v30, v29, v4                                  ; 683c091d
	v_add_u32_e32 v29, v29, v31                                 ; 683a3f1d
	v_lshl_add_u32 v32, v32, 7, v33                             ; d1fd0020 04850f20
	v_add_u32_e32 v36, s5, v0                                   ; 68480005
	s_mul_i32 s9, s9, s3                                        ; 92090309
	v_add_u32_e32 v34, 16, v32                                  ; 68444090
	v_lshlrev_b32_e32 v37, 4, v36                               ; 244a4884
	s_add_u32 s9, s18, s9                                       ; 80090912
	v_add_u32_e32 v35, v34, v4                                  ; 68460922
	v_add_u32_e32 v34, v34, v31                                 ; 68443f22
	v_lshl_add_u32 v36, v36, 7, v37                             ; d1fd0024 04950f24
	v_add_u32_e32 v40, s9, v0                                   ; 68500009
	v_add_u32_e32 v38, 16, v36                                  ; 684c4890
	v_lshlrev_b32_e32 v41, 4, v40                               ; 24525084
	v_add_u32_e32 v39, v38, v4                                  ; 684e0926
	v_add_u32_e32 v38, v38, v31                                 ; 684c3f26
	v_lshl_add_u32 v40, v40, 7, v41                             ; d1fd0028 04a50f28
	v_add_u32_e32 v42, 16, v40                                  ; 68545090
	v_add_u32_e32 v43, v42, v4                                  ; 6856092a
	v_add_u32_e32 v42, v42, v31                                 ; 68543f2a
	buffer_load_dwordx4 v[44:47], v11, s[24:27], 0 offen        ; e05c1000 80062c0b
	buffer_load_dword v30, v30, s[24:27], 0 offen               ; e0501000 80061e1e
	buffer_load_dword v29, v29, s[24:27], 0 offen               ; e0501000 80061d1d
	buffer_load_dwordx4 v[48:51], v32, s[24:27], 0 offen        ; e05c1000 80063020
	buffer_load_dword v35, v35, s[24:27], 0 offen               ; e0501000 80062323
	buffer_load_dword v34, v34, s[24:27], 0 offen               ; e0501000 80062222
	buffer_load_dwordx4 v[52:55], v36, s[24:27], 0 offen        ; e05c1000 80063424
	buffer_load_dword v39, v39, s[24:27], 0 offen               ; e0501000 80062727
	buffer_load_dword v38, v38, s[24:27], 0 offen               ; e0501000 80062626
	buffer_load_dwordx4 v[56:59], v40, s[24:27], 0 offen        ; e05c1000 80063828
	buffer_load_dword v43, v43, s[24:27], 0 offen               ; e0501000 80062b2b
	buffer_load_dword v42, v42, s[24:27], 0 offen               ; e0501000 80062a2a
	s_bfm_b32 s10, 16, 16                                       ; 910a9090
	s_mov_b32 s11, 0xf0f0f0f                                    ; be8b00ff 0f0f0f0f
	s_mov_b32 s12, 0xc0c0c0c0                                   ; be8c00ff c0c0c0c0
	s_mov_b32 s13, 0x3f3f3f3f                                   ; be8d00ff 3f3f3f3f
	v_add_u32_e32 v0, 4, v0                                     ; 68000084
	s_waitcnt vmcnt(15)                                         ; bf8c3f7f
	v_add_f32_e32 v60, v12, v13                                 ; 02781b0c
	s_waitcnt vmcnt(14)                                         ; bf8c3f7e
	v_add_f32_e32 v61, v16, v17                                 ; 027a2310
	s_waitcnt vmcnt(13)                                         ; bf8c3f7d
	v_add_f32_e32 v62, v20, v21                                 ; 027c2b14
	v_add_f32_e32 v60, v60, v14                                 ; 02781d3c
	s_waitcnt vmcnt(12)                                         ; bf8c3f7c
	v_add_f32_e32 v9, v24, v25                                  ; 02123318
	v_add_f32_e32 v61, v61, v18                                 ; 027a253d
	v_add_f32_e32 v62, v62, v22                                 ; 027c2d3e
	v_add_f32_e32 v60, v60, v15                                 ; 02781f3c
	v_add_f32_e32 v9, v9, v26                                   ; 02123509
	v_add_f32_e32 v61, v61, v19                                 ; 027a273d
	v_add_f32_e32 v62, v62, v23                                 ; 027c2f3e
	v_add_f32_e32 v9, v9, v27                                   ; 02123709
	s_waitcnt vmcnt(11)                                         ; bf8c3f7b
	v_bfe_u32 v47, v47, v2, 16                                  ; d1c8002f 0242052f
	v_lshlrev_b32_e32 v46, v5, v46                              ; 245c5d05
	v_bfe_u32 v45, v45, v2, 16                                  ; d1c8002d 0242052d
	v_lshl_or_b32 v47, v47, 12, v47                             ; d200002f 04bd192f
	v_and_or_b32 v46, s10, v46, v45                             ; d201002e 04b65c0a
	v_and_b32_e32 v10, s12, v46                                 ; 26145c0c
	v_and_b32_e32 v46, s13, v46                                 ; 265c5c0d
	v_cvt_f32_f16_sdwa v37, v44 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e4a16f9 0005062c
	v_lshrrev_b32_e32 v10, 2, v10                               ; 20141482
	v_cvt_f32_ubyte1_e32 v36, v46                               ; 7e48252e
	v_cvt_f32_f16_e32 v44, v44                                  ; 7e58172c
	v_cvt_f32_ubyte2_e32 v32, v46                               ; 7e40272e
	v_cvt_f32_ubyte3_e32 v31, v46                               ; 7e3e292e
	v_cvt_f32_ubyte0_e32 v46, v46                               ; 7e5c232e
	s_waitcnt vmcnt(10)                                         ; bf8c3f7a
	v_and_b32_e32 v40, s11, v30                                 ; 26503c0b
	v_and_or_b32 v47, s11, v47, v10                             ; d201002f 042a5e0b
	v_cvt_f32_ubyte3_e32 v41, v40                               ; 7e522928
	v_cvt_f32_ubyte1_e32 v10, v40                               ; 7e142528
	v_cvt_f32_ubyte2_e32 v45, v40                               ; 7e5a2728
	v_cvt_f32_ubyte0_e32 v40, v40                               ; 7e502328
	v_cvt_f32_ubyte2_e32 v28, v47                               ; 7e38272f
	v_cvt_f32_ubyte3_e32 v11, v47                               ; 7e16292f
	v_cvt_f32_ubyte1_e32 v33, v47                               ; 7e42252f
	v_cvt_f32_ubyte0_e32 v47, v47                               ; 7e5e232f
	v_mul_f32_e32 v41, v15, v41                                 ; 0a52530f
	v_lshrrev_b32_e32 v30, 4, v30                               ; 203c3c84
	v_mul_f32_e32 v11, v9, v11                                  ; 0a161709
	v_mac_f32_e32 v41, v14, v45                                 ; 2c525b0e
	v_and_b32_e32 v30, s11, v30                                 ; 263c3c0b
	v_mac_f32_e32 v11, v62, v28                                 ; 2c16393e
	v_mac_f32_e32 v41, v13, v10                                 ; 2c52150d
	v_cvt_f32_ubyte2_e32 v28, v30                               ; 7e38271e
	v_mac_f32_e32 v11, v61, v31                                 ; 2c163f3d
	v_cvt_f32_ubyte1_e32 v31, v30                               ; 7e3e251e
	v_mac_f32_e32 v41, v12, v40                                 ; 2c52510c
	v_mac_f32_e32 v11, v60, v32                                 ; 2c16413c
	s_waitcnt vmcnt(9)                                          ; bf8c3f79
	v_and_b32_e32 v32, s11, v29                                 ; 26403a0b
	v_lshrrev_b32_e32 v29, 4, v29                               ; 203a3a84
	v_mad_f32 v3, -v37, v11, v3                                 ; d1c10003 240e1725
	v_cvt_f32_ubyte3_e32 v11, v30                               ; 7e16291e
	v_cvt_f32_ubyte0_e32 v30, v30                               ; 7e3c231e
	v_cvt_f32_ubyte2_e32 v40, v32                               ; 7e502720
	v_cvt_f32_ubyte1_e32 v45, v32                               ; 7e5a2520
	v_cvt_f32_ubyte3_e32 v37, v32                               ; 7e4a2920
	v_cvt_f32_ubyte0_e32 v32, v32                               ; 7e402320
	v_and_b32_e32 v29, s11, v29                                 ; 263a3a0b
	v_mul_f32_e32 v11, v19, v11                                 ; 0a161713
	v_mul_f32_e32 v37, v23, v37                                 ; 0a4a4b17
	v_cvt_f32_ubyte3_e32 v10, v29                               ; 7e14291d
	v_mac_f32_e32 v11, v18, v28                                 ; 2c163912
	v_cvt_f32_ubyte2_e32 v28, v29                               ; 7e38271d
	v_mac_f32_e32 v37, v22, v40                                 ; 2c4a5116
	v_mul_f32_e32 v10, v27, v10                                 ; 0a14151b
	v_mac_f32_e32 v11, v17, v31                                 ; 2c163f11
	s_waitcnt vmcnt(8)                                          ; bf8c3f78
	v_bfe_u32 v51, v51, v2, 16                                  ; d1c80033 02420533
	v_bfe_u32 v49, v49, v2, 16                                  ; d1c80031 02420531
	v_mac_f32_e32 v37, v21, v45                                 ; 2c4a5b15
	v_lshlrev_b32_e32 v50, v5, v50                              ; 24646505
	v_mac_f32_e32 v10, v26, v28                                 ; 2c14391a
	v_mac_f32_e32 v11, v16, v30                                 ; 2c163d10
	v_cvt_f32_ubyte1_e32 v30, v29                               ; 7e3c251d
	v_cvt_f32_ubyte0_e32 v29, v29                               ; 7e3a231d
	v_lshl_or_b32 v51, v51, 12, v51                             ; d2000033 04cd1933
	v_mac_f32_e32 v37, v20, v32                                 ; 2c4a4114
	v_and_or_b32 v50, s10, v50, v49                             ; d2010032 04c6640a
	v_mac_f32_e32 v10, v25, v30                                 ; 2c143d19
	v_and_b32_e32 v31, s12, v50                                 ; 263e640c
	v_and_b32_e32 v50, s13, v50                                 ; 2664640d
	v_mac_f32_e32 v10, v24, v29                                 ; 2c143b18
	v_lshrrev_b32_e32 v31, 2, v31                               ; 203e3e82
	v_mul_f32_e32 v10, v10, v33                                 ; 0a14430a
	v_and_or_b32 v51, s11, v51, v31                             ; d2010033 047e660b
	v_mac_f32_e32 v10, v37, v47                                 ; 2c145f25
	v_cvt_f32_ubyte2_e32 v37, v50                               ; 7e4a2732
	v_cvt_f32_ubyte2_e32 v33, v51                               ; 7e422733
	v_cvt_f32_ubyte3_e32 v32, v51                               ; 7e402933
	v_cvt_f32_ubyte1_e32 v40, v51                               ; 7e502533
	v_cvt_f32_ubyte0_e32 v51, v51                               ; 7e662333
	v_mac_f32_e32 v10, v11, v36                                 ; 2c14490b
	v_cvt_f32_ubyte3_e32 v36, v50                               ; 7e482932
	s_waitcnt vmcnt(7)                                          ; bf8c3f77
	v_and_b32_e32 v45, s11, v35                                 ; 265a460b
	v_mul_f32_e32 v32, v9, v32                                  ; 0a404109
	v_mac_f32_e32 v10, v41, v46                                 ; 2c145d29
	v_cvt_f32_ubyte1_e32 v41, v50                               ; 7e522532
	v_cvt_f32_ubyte0_e32 v50, v50                               ; 7e642332
	v_cvt_f32_ubyte1_e32 v49, v45                               ; 7e62252d
	v_cvt_f32_ubyte3_e32 v46, v45                               ; 7e5c292d
	v_cvt_f32_ubyte2_e32 v47, v45                               ; 7e5e272d
	v_mac_f32_e32 v32, v62, v33                                 ; 2c40433e
	v_cvt_f32_ubyte0_e32 v45, v45                               ; 7e5a232d
	v_mac_f32_e32 v3, v44, v10                                  ; 2c06152c
	v_cvt_f32_f16_sdwa v44, v48 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e5816f9 00050630
	v_cvt_f32_f16_e32 v48, v48                                  ; 7e601730
	v_lshrrev_b32_e32 v35, 4, v35                               ; 20464684
	v_mul_f32_e32 v46, v15, v46                                 ; 0a5c5d0f
	v_mac_f32_e32 v32, v61, v36                                 ; 2c40493d
	s_waitcnt vmcnt(6)                                          ; bf8c3f76
	v_and_b32_e32 v29, s11, v34                                 ; 263a440b
	v_and_b32_e32 v35, s11, v35                                 ; 2646460b
	v_mac_f32_e32 v46, v14, v47                                 ; 2c5c5f0e
	v_mac_f32_e32 v32, v60, v37                                 ; 2c404b3c
	v_cvt_f32_ubyte2_e32 v31, v29                               ; 7e3e271d
	v_cvt_f32_ubyte3_e32 v30, v29                               ; 7e3c291d
	v_cvt_f32_ubyte2_e32 v11, v35                               ; 7e162723
	v_cvt_f32_ubyte1_e32 v28, v35                               ; 7e382523
	v_cvt_f32_ubyte3_e32 v10, v35                               ; 7e142923
	v_cvt_f32_ubyte0_e32 v35, v35                               ; 7e462323
	v_mac_f32_e32 v46, v13, v49                                 ; 2c5c630d
	v_mad_f32 v6, -v44, v32, v6                                 ; d1c10006 241a412c
	v_cvt_f32_ubyte1_e32 v32, v29                               ; 7e40251d
	v_cvt_f32_ubyte0_e32 v29, v29                               ; 7e3a231d
	v_mul_f32_e32 v30, v23, v30                                 ; 0a3c3d17
	v_lshrrev_b32_e32 v34, 4, v34                               ; 20444484
	v_mul_f32_e32 v10, v19, v10                                 ; 0a141513
	v_mac_f32_e32 v46, v12, v45                                 ; 2c5c5b0c
	v_mac_f32_e32 v30, v22, v31                                 ; 2c3c3f16
	v_and_b32_e32 v34, s11, v34                                 ; 2644440b
	v_mac_f32_e32 v10, v18, v11                                 ; 2c141712
	v_mac_f32_e32 v30, v21, v32                                 ; 2c3c4115
	v_cvt_f32_ubyte3_e32 v33, v34                               ; 7e422922
	v_cvt_f32_ubyte1_e32 v36, v34                               ; 7e482522
	v_mac_f32_e32 v10, v17, v28                                 ; 2c143911
	s_waitcnt vmcnt(5)                                          ; bf8c3f75
	v_bfe_u32 v55, v55, v2, 16                                  ; d1c80037 02420537
	v_mac_f32_e32 v30, v20, v29                                 ; 2c3c3b14
	v_mul_f32_e32 v33, v27, v33                                 ; 0a42431b
	v_bfe_u32 v53, v53, v2, 16                                  ; d1c80035 02420535
	v_lshlrev_b32_e32 v54, v5, v54                              ; 246c6d05
	v_mac_f32_e32 v10, v16, v35                                 ; 2c144710
	v_cvt_f32_ubyte2_e32 v35, v34                               ; 7e462722
	v_cvt_f32_ubyte0_e32 v34, v34                               ; 7e442322
	v_lshl_or_b32 v55, v55, 12, v55                             ; d2000037 04dd1937
	v_and_or_b32 v54, s10, v54, v53                             ; d2010036 04d66c0a
	v_mac_f32_e32 v33, v26, v35                                 ; 2c42471a
	v_and_b32_e32 v37, s12, v54                                 ; 264a6c0c
	v_and_b32_e32 v54, s13, v54                                 ; 266c6c0d
	v_mac_f32_e32 v33, v25, v36                                 ; 2c424919
	v_lshrrev_b32_e32 v37, 2, v37                               ; 204a4a82
	v_cvt_f32_ubyte2_e32 v45, v54                               ; 7e5a2736
	v_cvt_f32_ubyte3_e32 v44, v54                               ; 7e582936
	v_mac_f32_e32 v33, v24, v34                                 ; 2c424518
	v_and_or_b32 v55, s11, v55, v37                             ; d2010037 04966e0b
	v_cvt_f32_ubyte1_e32 v47, v54                               ; 7e5e2536
	v_mul_f32_e32 v33, v33, v40                                 ; 0a425121
	v_cvt_f32_ubyte3_e32 v40, v55                               ; 7e502937
	v_mac_f32_e32 v33, v30, v51                                 ; 2c42671e
	v_mul_f32_e32 v40, v9, v40                                  ; 0a505109
	v_mac_f32_e32 v33, v10, v41                                 ; 2c42530a
	v_cvt_f32_ubyte2_e32 v41, v55                               ; 7e522737
	v_mac_f32_e32 v33, v46, v50                                 ; 2c42652e
	v_cvt_f32_ubyte1_e32 v46, v55                               ; 7e5c2537
	v_cvt_f32_ubyte0_e32 v55, v55                               ; 7e6e2337
	v_mac_f32_e32 v40, v62, v41                                 ; 2c50533e
	v_mac_f32_e32 v6, v48, v33                                  ; 2c0c4330
	s_waitcnt vmcnt(4)                                          ; bf8c3f74
	v_and_b32_e32 v48, s11, v39                                 ; 26604e0b
	v_lshrrev_b32_e32 v39, 4, v39                               ; 204e4e84
	v_mac_f32_e32 v40, v61, v44                                 ; 2c50593d
	v_cvt_f32_ubyte2_e32 v50, v48                               ; 7e642730
	v_cvt_f32_ubyte1_e32 v51, v48                               ; 7e662530
	v_cvt_f32_ubyte3_e32 v49, v48                               ; 7e622930
	v_cvt_f32_ubyte0_e32 v48, v48                               ; 7e602330
	v_and_b32_e32 v39, s11, v39                                 ; 264e4e0b
	v_mac_f32_e32 v40, v60, v45                                 ; 2c505b3c
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_and_b32_e32 v28, s11, v38                                 ; 26384c0b
	v_mul_f32_e32 v49, v15, v49                                 ; 0a62630f
	v_cvt_f32_ubyte3_e32 v53, v39                               ; 7e6a2927
	v_cvt_f32_ubyte2_e32 v10, v39                               ; 7e142727
	v_cvt_f32_ubyte1_e32 v11, v39                               ; 7e162527
	v_cvt_f32_ubyte0_e32 v39, v39                               ; 7e4e2327
	v_cvt_f32_ubyte2_e32 v30, v28                               ; 7e3c271c
	v_cvt_f32_ubyte1_e32 v31, v28                               ; 7e3e251c
	v_cvt_f32_ubyte3_e32 v29, v28                               ; 7e3a291c
	v_mac_f32_e32 v49, v14, v50                                 ; 2c62650e
	v_mul_f32_e32 v53, v19, v53                                 ; 0a6a6b13
	v_cvt_f32_ubyte0_e32 v28, v28                               ; 7e38231c
	v_lshrrev_b32_e32 v38, 4, v38                               ; 204c4c84
	v_mul_f32_e32 v29, v23, v29                                 ; 0a3a3b17
	v_mac_f32_e32 v49, v13, v51                                 ; 2c62670d
	v_mac_f32_e32 v53, v18, v10                                 ; 2c6a1512
	v_and_b32_e32 v38, s11, v38                                 ; 264c4c0b
	v_mac_f32_e32 v29, v22, v30                                 ; 2c3a3d16
	v_mac_f32_e32 v49, v12, v48                                 ; 2c62610c
	v_mac_f32_e32 v53, v17, v11                                 ; 2c6a1711
	v_cvt_f32_ubyte2_e32 v33, v38                               ; 7e422726
	v_cvt_f32_ubyte1_e32 v34, v38                               ; 7e442526
	v_cvt_f32_ubyte3_e32 v32, v38                               ; 7e402926
	v_cvt_f32_ubyte0_e32 v38, v38                               ; 7e4c2326
	v_mac_f32_e32 v29, v21, v31                                 ; 2c3a3f15
	v_cvt_f32_ubyte0_e32 v54, v54                               ; 7e6c2336
	v_cvt_f32_f16_sdwa v35, v52 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e4616f9 00050634
	v_mac_f32_e32 v53, v16, v39                                 ; 2c6a4f10
	v_cvt_f32_f16_e32 v52, v52                                  ; 7e681734
	v_mul_f32_e32 v32, v27, v32                                 ; 0a40411b
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_bfe_u32 v59, v59, v2, 16                                  ; d1c8003b 0242053b
	v_bfe_u32 v57, v57, v2, 16                                  ; d1c80039 02420539
	v_mac_f32_e32 v29, v20, v28                                 ; 2c3a3914
	v_lshlrev_b32_e32 v58, v5, v58                              ; 24747505
	v_mad_f32 v7, -v35, v40, v7                                 ; d1c10007 241e5123
	v_mac_f32_e32 v32, v26, v33                                 ; 2c40431a
	v_lshl_or_b32 v59, v59, 12, v59                             ; d200003b 04ed193b
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v37, s11, v43                                 ; 264a560b
	v_and_or_b32 v58, s10, v58, v57                             ; d201003a 04e6740a
	v_mac_f32_e32 v32, v25, v34                                 ; 2c404519
	v_cvt_f32_ubyte2_e32 v39, v37                               ; 7e4e2725
	v_cvt_f32_ubyte1_e32 v40, v37                               ; 7e502525
	v_and_b32_e32 v36, s12, v58                                 ; 2648740c
	v_mac_f32_e32 v32, v24, v38                                 ; 2c404d18
	v_cvt_f32_ubyte3_e32 v38, v37                               ; 7e4c2925
	v_cvt_f32_ubyte0_e32 v37, v37                               ; 7e4a2325
	v_lshrrev_b32_e32 v43, 4, v43                               ; 20565684
	v_lshrrev_b32_e32 v36, 2, v36                               ; 20484882
	v_mul_f32_e32 v32, v32, v46                                 ; 0a405d20
	v_mul_f32_e32 v15, v15, v38                                 ; 0a1e4d0f
	v_and_b32_e32 v43, s11, v43                                 ; 2656560b
	v_and_or_b32 v59, s11, v59, v36                             ; d201003b 0492760b
	v_mac_f32_e32 v32, v29, v55                                 ; 2c406f1d
	v_mac_f32_e32 v15, v14, v39                                 ; 2c1e4f0e
	v_cvt_f32_ubyte1_e32 v45, v43                               ; 7e5a252b
	v_cvt_f32_ubyte2_e32 v44, v43                               ; 7e58272b
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v46, s11, v42                                 ; 265c540b
	v_cvt_f32_ubyte3_e32 v41, v43                               ; 7e52292b
	v_cvt_f32_ubyte0_e32 v43, v43                               ; 7e56232b
	v_mac_f32_e32 v32, v53, v47                                 ; 2c405f35
	v_mac_f32_e32 v15, v13, v40                                 ; 2c1e510d
	v_cvt_f32_ubyte2_e32 v48, v46                               ; 7e60272e
	v_cvt_f32_ubyte3_e32 v47, v46                               ; 7e5e292e
	v_mul_f32_e32 v19, v19, v41                                 ; 0a265313
	v_lshrrev_b32_e32 v42, 4, v42                               ; 20545484
	v_mac_f32_e32 v32, v49, v54                                 ; 2c406d31
	v_cvt_f32_ubyte1_e32 v49, v46                               ; 7e62252e
	v_cvt_f32_ubyte0_e32 v46, v46                               ; 7e5c232e
	v_mac_f32_e32 v15, v12, v37                                 ; 2c1e4b0c
	v_mul_f32_e32 v23, v23, v47                                 ; 0a2e5f17
	v_mac_f32_e32 v19, v18, v44                                 ; 2c265912
	v_and_b32_e32 v42, s11, v42                                 ; 2654540b
	v_mac_f32_e32 v7, v52, v32                                  ; 2c0e4134
	v_mac_f32_e32 v23, v22, v48                                 ; 2c2e6116
	v_cvt_f32_ubyte3_e32 v53, v59                               ; 7e6a293b
	v_mac_f32_e32 v19, v17, v45                                 ; 2c265b11
	v_cvt_f32_ubyte3_e32 v50, v42                               ; 7e64292a
	v_cvt_f32_ubyte2_e32 v51, v42                               ; 7e66272a
	v_cvt_f32_ubyte1_e32 v52, v42                               ; 7e68252a
	v_cvt_f32_ubyte0_e32 v42, v42                               ; 7e54232a
	v_cvt_f32_ubyte2_e32 v54, v59                               ; 7e6c273b
	v_and_b32_e32 v58, s13, v58                                 ; 2674740d
	v_mac_f32_e32 v23, v21, v49                                 ; 2c2e6315
	v_mul_f32_e32 v9, v9, v53                                   ; 0a126b09
	v_mac_f32_e32 v19, v16, v43                                 ; 2c265710
	v_mul_f32_e32 v27, v27, v50                                 ; 0a36651b
	v_cvt_f32_ubyte2_e32 v57, v58                               ; 7e72273a
	v_cvt_f32_ubyte3_e32 v55, v58                               ; 7e6e293a
	v_mac_f32_e32 v23, v20, v46                                 ; 2c2e5d14
	v_mac_f32_e32 v9, v62, v54                                  ; 2c126d3e
	v_mac_f32_e32 v27, v26, v51                                 ; 2c36671a
	v_cvt_f32_f16_sdwa v62, v56 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e7c16f9 00050638
	v_cvt_f32_f16_e32 v56, v56                                  ; 7e701738
	v_mac_f32_e32 v9, v61, v55                                  ; 2c126f3d
	v_cvt_f32_ubyte1_e32 v61, v58                               ; 7e7a253a
	v_cvt_f32_ubyte0_e32 v58, v58                               ; 7e74233a
	v_mac_f32_e32 v27, v25, v52                                 ; 2c366919
	v_mac_f32_e32 v9, v60, v57                                  ; 2c12733c
	v_cvt_f32_ubyte1_e32 v60, v59                               ; 7e78253b
	v_cvt_f32_ubyte0_e32 v59, v59                               ; 7e76233b
	v_mac_f32_e32 v27, v24, v42                                 ; 2c365518
	v_mad_f32 v8, -v62, v9, v8                                  ; d1c10008 2422133e
	v_mul_f32_e32 v27, v27, v60                                 ; 0a36791b
	v_mac_f32_e32 v27, v23, v59                                 ; 2c367717
	v_mac_f32_e32 v27, v19, v61                                 ; 2c367b13
	v_mac_f32_e32 v27, v15, v58                                 ; 2c36750f
	v_mac_f32_e32 v8, v56, v27                                  ; 2c103738
BB5:
	s_mov_b64 s[0:1], exec                                      ; be80017e
	v_cmpx_le_u32_e32 vcc, s3, v0                               ; 7db60003
BB6:
	s_andn2_b64 s[0:1], s[0:1], exec                            ; 89807e00
	s_cbranch_scc1 BB10                                         ; bf85fe57
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
	v_readlane_b32 s1, v63, 63                                  ; d2890001 00017f3f
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
	v_readlane_b32 s3, v63, 63                                  ; d2890003 00017f3f
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
	s_branch BB119                                              ; bf820317
BB42:
	s_cmp_lt_u32 s16, s4                                        ; bf0a0410
	s_cbranch_scc0 BB119                                        ; bf840315
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
	v_mov_b32_e32 v6, 0                                         ; 7e0c0280
	s_mul_i32 s19, s19, s5                                      ; 92130513
	v_mov_b32_e32 v7, 0                                         ; 7e0e0280
	v_mov_b32_e32 v8, 0                                         ; 7e100280
	v_sub_u32_e32 v1, v2, v1                                    ; 6a020302
	v_bfe_u32 v3, v2, 2, 1                                      ; d1c80003 02050502
	v_lshrrev_b32_e32 v2, 3, v2                                 ; 20040483
	v_lshl_add_u32 v1, v1, 1, v3                                ; d1fd0001 040d0301
	v_mov_b32_e32 v3, 0                                         ; 7e060280
	v_lshlrev_b32_e32 v1, 2, v1                                 ; 24020282
	v_lshl_add_u32 v4, v2, 5, v1                                ; d1fd0004 04050b02
	v_lshl_add_u32 v1, v2, 6, v1                                ; d1fd0001 04050d02
	v_lshlrev_b32_e32 v2, 4, v2                                 ; 24040484
	v_sub_u32_e32 v5, 16, v2                                    ; 6a0a0490
BB47:
	s_mov_b64 s[0:1], exec                                      ; be80017e
	v_cmpx_le_u32_e32 vcc, s3, v0                               ; 7db60003
BB48:
	s_andn2_b64 s[0:1], s[0:1], exec                            ; 89807e00
	s_cbranch_scc0 BB65                                         ; bf8401be
BB52:
	s_mov_b64 exec, s[0:1]                                      ; befe0100
	s_mov_b32 s0, s2                                            ; be800002
	s_movk_i32 s1, 0x8000                                       ; b0018000
	s_load_dwordx4 s[12:15], s[0:1], 0x10                       ; c00a0300 00000010
	s_mul_i32 s5, s6, s17                                       ; 92051106
	v_lshl_add_u32 v9, v0, 8, v1                                ; d1fd0009 04051100
	v_add_u32_e32 v10, s5, v9                                   ; 68141205
	v_add_u32_e32 v9, 0x80, v9                                  ; 681212ff 00000080
	v_lshrrev_b32_e32 v10, 2, v10                               ; 20141482
	v_add_u32_e32 v9, s5, v9                                    ; 68121205
	v_lshlrev_b32_e32 v10, 4, v10                               ; 24141484
	v_lshrrev_b32_e32 v9, 2, v9                                 ; 20121282
	v_lshlrev_b32_e32 v9, 4, v9                                 ; 24121284
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_load_dwordx4 v[12:15], v10, s[12:15], 0 offen        ; e05c1000 80030c0a
	buffer_load_dwordx4 v[16:19], v10, s[12:15], 0 offen offset:128 ; e05c1080 8003100a
	buffer_load_dwordx4 v[20:23], v9, s[12:15], 0 offen         ; e05c1000 80031409
	buffer_load_dwordx4 v[24:27], v9, s[12:15], 0 offen offset:128 ; e05c1080 80031809
	s_cmp_lg_i32 s4, 0                                          ; bf018004
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_add_f32_e32 v11, v12, v13                                 ; 02161b0c
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_add_f32_e32 v28, v16, v17                                 ; 02382310
	v_add_f32_e32 v11, v11, v14                                 ; 02161d0b
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_add_f32_e32 v29, v20, v21                                 ; 023a2b14
	v_add_f32_e32 v28, v28, v18                                 ; 0238251c
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_add_f32_e32 v30, v24, v25                                 ; 023c3318
	v_add_f32_e32 v11, v11, v15                                 ; 02161f0b
	v_add_f32_e32 v29, v29, v22                                 ; 023a2d1d
	v_add_f32_e32 v28, v28, v19                                 ; 0238271c
	v_add_f32_e32 v30, v30, v26                                 ; 023c351e
	v_add_f32_e32 v29, v29, v23                                 ; 023a2f1d
	v_add_f32_e32 v30, v30, v27                                 ; 023c371e
	s_cbranch_scc0 BB64                                         ; bf840191
BB53:
	s_load_dwordx4 s[12:15], s[0:1], 0x0                        ; c00a0300 00000000
	s_mul_i32 s0, s16, s3                                       ; 92000310
	v_add_u32_e32 v33, 64, v4                                   ; 684208c0
	s_add_u32 s0, s19, s0                                       ; 80000013
	v_add_u32_e32 v9, s0, v0                                    ; 68120000
	v_lshlrev_b32_e32 v10, 4, v9                                ; 24141284
	v_lshl_add_u32 v9, v9, 7, v10                               ; d1fd0009 04290f09
	v_add_u32_e32 v31, 16, v9                                   ; 683e1290
	v_add_u32_e32 v32, v31, v4                                  ; 6840091f
	v_add_u32_e32 v31, v31, v33                                 ; 683e431f
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_load_dwordx4 v[36:39], v9, s[12:15], 0 offen         ; e05c1000 80032409
	buffer_load_dword v32, v32, s[12:15], 0 offen               ; e0501000 80032020
	buffer_load_dword v31, v31, s[12:15], 0 offen               ; e0501000 80031f1f
	s_bfm_b32 s1, 16, 16                                        ; 91019090
	s_mov_b32 s5, 0xf0f0f0f                                     ; be8500ff 0f0f0f0f
	s_cmp_lt_u32 1, s4                                          ; bf0a0481
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_bfe_u32 v39, v39, v2, 16                                  ; d1c80027 02420527
	v_bfe_u32 v37, v37, v2, 16                                  ; d1c80025 02420525
	v_lshlrev_b32_e32 v38, v5, v38                              ; 244c4d05
	v_lshl_or_b32 v39, v39, 12, v39                             ; d2000027 049d1927
	v_and_or_b32 v38, s1, v38, v37                              ; d2010026 04964c01
	v_and_b32_e32 v34, 0xc0c0c0c0, v38                          ; 26444cff c0c0c0c0
	v_and_b32_e32 v38, 0x3f3f3f3f, v38                          ; 264c4cff 3f3f3f3f
	v_cvt_f32_f16_sdwa v44, v36 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e5816f9 00050624
	v_lshrrev_b32_e32 v34, 2, v34                               ; 20444482
	v_cvt_f32_ubyte1_e32 v43, v38                               ; 7e562526
	v_cvt_f32_f16_e32 v36, v36                                  ; 7e481724
	v_cvt_f32_ubyte3_e32 v40, v38                               ; 7e502926
	v_cvt_f32_ubyte2_e32 v41, v38                               ; 7e522726
	v_cvt_f32_ubyte0_e32 v38, v38                               ; 7e4c2326
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v45, s5, v32                                  ; 265a4005
	v_and_or_b32 v39, s5, v39, v34                              ; d2010027 048a4e05
	v_cvt_f32_ubyte1_e32 v48, v45                               ; 7e60252d
	v_cvt_f32_ubyte3_e32 v46, v45                               ; 7e5c292d
	v_cvt_f32_ubyte2_e32 v47, v45                               ; 7e5e272d
	v_cvt_f32_ubyte0_e32 v45, v45                               ; 7e5a232d
	v_cvt_f32_ubyte1_e32 v42, v39                               ; 7e542527
	v_cvt_f32_ubyte3_e32 v35, v39                               ; 7e462927
	v_cvt_f32_ubyte2_e32 v37, v39                               ; 7e4a2727
	v_cvt_f32_ubyte0_e32 v39, v39                               ; 7e4e2327
	v_lshrrev_b32_e32 v32, 4, v32                               ; 20404084
	v_mul_f32_e32 v46, v15, v46                                 ; 0a5c5d0f
	v_mul_f32_e32 v35, v30, v35                                 ; 0a46471e
	v_and_b32_e32 v32, s5, v32                                  ; 26404005
	v_mac_f32_e32 v46, v14, v47                                 ; 2c5c5f0e
	v_mac_f32_e32 v35, v29, v37                                 ; 2c464b1d
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v52, s5, v31                                  ; 26683e05
	v_cvt_f32_ubyte3_e32 v49, v32                               ; 7e622920
	v_cvt_f32_ubyte2_e32 v50, v32                               ; 7e642720
	v_cvt_f32_ubyte1_e32 v51, v32                               ; 7e662520
	v_cvt_f32_ubyte0_e32 v32, v32                               ; 7e402320
	v_mac_f32_e32 v46, v13, v48                                 ; 2c5c610d
	v_mac_f32_e32 v35, v28, v40                                 ; 2c46511c
	v_cvt_f32_ubyte2_e32 v54, v52                               ; 7e6c2734
	v_cvt_f32_ubyte3_e32 v53, v52                               ; 7e6a2934
	v_mul_f32_e32 v49, v19, v49                                 ; 0a626313
	v_cvt_f32_ubyte1_e32 v55, v52                               ; 7e6e2534
	v_cvt_f32_ubyte0_e32 v52, v52                               ; 7e682334
	v_mac_f32_e32 v46, v12, v45                                 ; 2c5c5b0c
	v_lshrrev_b32_e32 v31, 4, v31                               ; 203e3e84
	v_mac_f32_e32 v35, v11, v41                                 ; 2c46530b
	v_mul_f32_e32 v53, v23, v53                                 ; 0a6a6b17
	v_mac_f32_e32 v49, v18, v50                                 ; 2c626512
	v_and_b32_e32 v31, s5, v31                                  ; 263e3e05
	v_mad_f32 v3, -v44, v35, v3                                 ; d1c10003 240e472c
	v_mac_f32_e32 v53, v22, v54                                 ; 2c6a6d16
	v_mac_f32_e32 v49, v17, v51                                 ; 2c626711
	v_cvt_f32_ubyte1_e32 v58, v31                               ; 7e74251f
	v_cvt_f32_ubyte2_e32 v57, v31                               ; 7e72271f
	v_cvt_f32_ubyte3_e32 v56, v31                               ; 7e70291f
	v_cvt_f32_ubyte0_e32 v31, v31                               ; 7e3e231f
	v_mac_f32_e32 v53, v21, v55                                 ; 2c6a6f15
	v_mac_f32_e32 v49, v16, v32                                 ; 2c624110
	v_mul_f32_e32 v56, v27, v56                                 ; 0a70711b
	v_mac_f32_e32 v53, v20, v52                                 ; 2c6a6914
	v_mac_f32_e32 v56, v26, v57                                 ; 2c70731a
	v_mac_f32_e32 v56, v25, v58                                 ; 2c707519
	v_mac_f32_e32 v56, v24, v31                                 ; 2c703f18
	v_mul_f32_e32 v56, v56, v42                                 ; 0a705538
	v_mac_f32_e32 v56, v53, v39                                 ; 2c704f35
	v_mac_f32_e32 v56, v49, v43                                 ; 2c705731
	v_mac_f32_e32 v56, v46, v38                                 ; 2c704d2e
	v_mac_f32_e32 v3, v36, v56                                  ; 2c067124
	s_cbranch_scc0 BB64                                         ; bf84012a
BB54:
	s_add_u32 s0, s16, 1                                        ; 80008110
	s_mul_i32 s0, s0, s3                                        ; 92000300
	s_add_u32 s0, s19, s0                                       ; 80000013
	v_add_u32_e32 v9, s0, v0                                    ; 68120000
	v_lshlrev_b32_e32 v10, 4, v9                                ; 24141284
	v_lshl_add_u32 v9, v9, 7, v10                               ; d1fd0009 04290f09
	v_add_u32_e32 v31, 16, v9                                   ; 683e1290
	v_add_u32_e32 v32, v31, v4                                  ; 6840091f
	v_add_u32_e32 v31, v31, v33                                 ; 683e431f
	buffer_load_dwordx4 v[36:39], v9, s[12:15], 0 offen         ; e05c1000 80032409
	buffer_load_dword v32, v32, s[12:15], 0 offen               ; e0501000 80032020
	buffer_load_dword v31, v31, s[12:15], 0 offen               ; e0501000 80031f1f
	s_bfm_b32 s1, 16, 16                                        ; 91019090
	s_mov_b32 s5, 0xf0f0f0f                                     ; be8500ff 0f0f0f0f
	s_cmp_lt_u32 2, s4                                          ; bf0a0482
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_bfe_u32 v37, v37, v2, 16                                  ; d1c80025 02420525
	v_lshlrev_b32_e32 v38, v5, v38                              ; 244c4d05
	v_bfe_u32 v39, v39, v2, 16                                  ; d1c80027 02420527
	v_and_or_b32 v38, s1, v38, v37                              ; d2010026 04964c01
	v_lshl_or_b32 v39, v39, 12, v39                             ; d2000027 049d1927
	v_and_b32_e32 v34, 0xc0c0c0c0, v38                          ; 26444cff c0c0c0c0
	v_and_b32_e32 v38, 0x3f3f3f3f, v38                          ; 264c4cff 3f3f3f3f
	v_cvt_f32_f16_sdwa v44, v36 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e5816f9 00050624
	v_lshrrev_b32_e32 v34, 2, v34                               ; 20444482
	v_cvt_f32_ubyte1_e32 v43, v38                               ; 7e562526
	v_cvt_f32_f16_e32 v36, v36                                  ; 7e481724
	v_cvt_f32_ubyte3_e32 v40, v38                               ; 7e502926
	v_cvt_f32_ubyte2_e32 v41, v38                               ; 7e522726
	v_cvt_f32_ubyte0_e32 v38, v38                               ; 7e4c2326
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v45, s5, v32                                  ; 265a4005
	v_and_or_b32 v39, s5, v39, v34                              ; d2010027 048a4e05
	v_cvt_f32_ubyte3_e32 v46, v45                               ; 7e5c292d
	v_cvt_f32_ubyte1_e32 v48, v45                               ; 7e60252d
	v_cvt_f32_ubyte2_e32 v47, v45                               ; 7e5e272d
	v_cvt_f32_ubyte0_e32 v45, v45                               ; 7e5a232d
	v_cvt_f32_ubyte1_e32 v42, v39                               ; 7e542527
	v_cvt_f32_ubyte3_e32 v35, v39                               ; 7e462927
	v_cvt_f32_ubyte2_e32 v37, v39                               ; 7e4a2727
	v_cvt_f32_ubyte0_e32 v39, v39                               ; 7e4e2327
	v_lshrrev_b32_e32 v32, 4, v32                               ; 20404084
	v_mul_f32_e32 v46, v15, v46                                 ; 0a5c5d0f
	v_mul_f32_e32 v35, v30, v35                                 ; 0a46471e
	v_and_b32_e32 v32, s5, v32                                  ; 26404005
	v_mac_f32_e32 v46, v14, v47                                 ; 2c5c5f0e
	v_mac_f32_e32 v35, v29, v37                                 ; 2c464b1d
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v52, s5, v31                                  ; 26683e05
	v_cvt_f32_ubyte3_e32 v49, v32                               ; 7e622920
	v_cvt_f32_ubyte2_e32 v50, v32                               ; 7e642720
	v_cvt_f32_ubyte1_e32 v51, v32                               ; 7e662520
	v_cvt_f32_ubyte0_e32 v32, v32                               ; 7e402320
	v_mac_f32_e32 v46, v13, v48                                 ; 2c5c610d
	v_mac_f32_e32 v35, v28, v40                                 ; 2c46511c
	v_cvt_f32_ubyte2_e32 v54, v52                               ; 7e6c2734
	v_cvt_f32_ubyte3_e32 v53, v52                               ; 7e6a2934
	v_mul_f32_e32 v49, v19, v49                                 ; 0a626313
	v_cvt_f32_ubyte1_e32 v55, v52                               ; 7e6e2534
	v_cvt_f32_ubyte0_e32 v52, v52                               ; 7e682334
	v_mac_f32_e32 v46, v12, v45                                 ; 2c5c5b0c
	v_lshrrev_b32_e32 v31, 4, v31                               ; 203e3e84
	v_mac_f32_e32 v35, v11, v41                                 ; 2c46530b
	v_mul_f32_e32 v53, v23, v53                                 ; 0a6a6b17
	v_mac_f32_e32 v49, v18, v50                                 ; 2c626512
	v_and_b32_e32 v31, s5, v31                                  ; 263e3e05
	v_mad_f32 v6, -v44, v35, v6                                 ; d1c10006 241a472c
	v_mac_f32_e32 v53, v22, v54                                 ; 2c6a6d16
	v_mac_f32_e32 v49, v17, v51                                 ; 2c626711
	v_cvt_f32_ubyte1_e32 v58, v31                               ; 7e74251f
	v_cvt_f32_ubyte2_e32 v57, v31                               ; 7e72271f
	v_cvt_f32_ubyte3_e32 v56, v31                               ; 7e70291f
	v_cvt_f32_ubyte0_e32 v31, v31                               ; 7e3e231f
	v_mac_f32_e32 v53, v21, v55                                 ; 2c6a6f15
	v_mac_f32_e32 v49, v16, v32                                 ; 2c624110
	v_mul_f32_e32 v56, v27, v56                                 ; 0a70711b
	v_mac_f32_e32 v53, v20, v52                                 ; 2c6a6914
	v_mac_f32_e32 v56, v26, v57                                 ; 2c70731a
	v_mac_f32_e32 v56, v25, v58                                 ; 2c707519
	v_mac_f32_e32 v56, v24, v31                                 ; 2c703f18
	v_mul_f32_e32 v56, v56, v42                                 ; 0a705538
	v_mac_f32_e32 v56, v53, v39                                 ; 2c704f35
	v_mac_f32_e32 v56, v49, v43                                 ; 2c705731
	v_mac_f32_e32 v56, v46, v38                                 ; 2c704d2e
	v_mac_f32_e32 v6, v36, v56                                  ; 2c0c7124
	s_cbranch_scc0 BB64                                         ; bf8400c6
BB55:
	s_add_u32 s0, s16, 2                                        ; 80008210
	s_mul_i32 s0, s0, s3                                        ; 92000300
	s_add_u32 s0, s19, s0                                       ; 80000013
	v_add_u32_e32 v9, s0, v0                                    ; 68120000
	v_lshlrev_b32_e32 v10, 4, v9                                ; 24141284
	v_lshl_add_u32 v9, v9, 7, v10                               ; d1fd0009 04290f09
	v_add_u32_e32 v31, 16, v9                                   ; 683e1290
	v_add_u32_e32 v32, v31, v4                                  ; 6840091f
	v_add_u32_e32 v31, v31, v33                                 ; 683e431f
	buffer_load_dwordx4 v[36:39], v9, s[12:15], 0 offen         ; e05c1000 80032409
	buffer_load_dword v32, v32, s[12:15], 0 offen               ; e0501000 80032020
	buffer_load_dword v31, v31, s[12:15], 0 offen               ; e0501000 80031f1f
	s_bfm_b32 s1, 16, 16                                        ; 91019090
	s_mov_b32 s5, 0xf0f0f0f                                     ; be8500ff 0f0f0f0f
	s_cmp_lt_u32 3, s4                                          ; bf0a0483
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_bfe_u32 v37, v37, v2, 16                                  ; d1c80025 02420525
	v_lshlrev_b32_e32 v38, v5, v38                              ; 244c4d05
	v_bfe_u32 v39, v39, v2, 16                                  ; d1c80027 02420527
	v_and_or_b32 v38, s1, v38, v37                              ; d2010026 04964c01
	v_lshl_or_b32 v39, v39, 12, v39                             ; d2000027 049d1927
	v_and_b32_e32 v34, 0xc0c0c0c0, v38                          ; 26444cff c0c0c0c0
	v_and_b32_e32 v38, 0x3f3f3f3f, v38                          ; 264c4cff 3f3f3f3f
	v_cvt_f32_f16_sdwa v44, v36 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e5816f9 00050624
	v_lshrrev_b32_e32 v34, 2, v34                               ; 20444482
	v_cvt_f32_ubyte1_e32 v43, v38                               ; 7e562526
	v_cvt_f32_f16_e32 v36, v36                                  ; 7e481724
	v_cvt_f32_ubyte3_e32 v40, v38                               ; 7e502926
	v_cvt_f32_ubyte2_e32 v41, v38                               ; 7e522726
	v_cvt_f32_ubyte0_e32 v38, v38                               ; 7e4c2326
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v45, s5, v32                                  ; 265a4005
	v_and_or_b32 v39, s5, v39, v34                              ; d2010027 048a4e05
	v_cvt_f32_ubyte3_e32 v46, v45                               ; 7e5c292d
	v_cvt_f32_ubyte1_e32 v48, v45                               ; 7e60252d
	v_cvt_f32_ubyte2_e32 v47, v45                               ; 7e5e272d
	v_cvt_f32_ubyte0_e32 v45, v45                               ; 7e5a232d
	v_cvt_f32_ubyte1_e32 v42, v39                               ; 7e542527
	v_cvt_f32_ubyte3_e32 v35, v39                               ; 7e462927
	v_cvt_f32_ubyte2_e32 v37, v39                               ; 7e4a2727
	v_cvt_f32_ubyte0_e32 v39, v39                               ; 7e4e2327
	v_lshrrev_b32_e32 v32, 4, v32                               ; 20404084
	v_mul_f32_e32 v46, v15, v46                                 ; 0a5c5d0f
	v_mul_f32_e32 v35, v30, v35                                 ; 0a46471e
	v_and_b32_e32 v32, s5, v32                                  ; 26404005
	v_mac_f32_e32 v46, v14, v47                                 ; 2c5c5f0e
	v_mac_f32_e32 v35, v29, v37                                 ; 2c464b1d
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v52, s5, v31                                  ; 26683e05
	v_cvt_f32_ubyte3_e32 v49, v32                               ; 7e622920
	v_cvt_f32_ubyte2_e32 v50, v32                               ; 7e642720
	v_cvt_f32_ubyte1_e32 v51, v32                               ; 7e662520
	v_cvt_f32_ubyte0_e32 v32, v32                               ; 7e402320
	v_mac_f32_e32 v46, v13, v48                                 ; 2c5c610d
	v_mac_f32_e32 v35, v28, v40                                 ; 2c46511c
	v_cvt_f32_ubyte2_e32 v54, v52                               ; 7e6c2734
	v_cvt_f32_ubyte3_e32 v53, v52                               ; 7e6a2934
	v_mul_f32_e32 v49, v19, v49                                 ; 0a626313
	v_cvt_f32_ubyte1_e32 v55, v52                               ; 7e6e2534
	v_cvt_f32_ubyte0_e32 v52, v52                               ; 7e682334
	v_mac_f32_e32 v46, v12, v45                                 ; 2c5c5b0c
	v_lshrrev_b32_e32 v31, 4, v31                               ; 203e3e84
	v_mac_f32_e32 v35, v11, v41                                 ; 2c46530b
	v_mul_f32_e32 v53, v23, v53                                 ; 0a6a6b17
	v_mac_f32_e32 v49, v18, v50                                 ; 2c626512
	v_and_b32_e32 v31, s5, v31                                  ; 263e3e05
	v_mad_f32 v7, -v44, v35, v7                                 ; d1c10007 241e472c
	v_mac_f32_e32 v53, v22, v54                                 ; 2c6a6d16
	v_mac_f32_e32 v49, v17, v51                                 ; 2c626711
	v_cvt_f32_ubyte1_e32 v58, v31                               ; 7e74251f
	v_cvt_f32_ubyte2_e32 v57, v31                               ; 7e72271f
	v_cvt_f32_ubyte3_e32 v56, v31                               ; 7e70291f
	v_cvt_f32_ubyte0_e32 v31, v31                               ; 7e3e231f
	v_mac_f32_e32 v53, v21, v55                                 ; 2c6a6f15
	v_mac_f32_e32 v49, v16, v32                                 ; 2c624110
	v_mul_f32_e32 v56, v27, v56                                 ; 0a70711b
	v_mac_f32_e32 v53, v20, v52                                 ; 2c6a6914
	v_mac_f32_e32 v56, v26, v57                                 ; 2c70731a
	v_mac_f32_e32 v56, v25, v58                                 ; 2c707519
	v_mac_f32_e32 v56, v24, v31                                 ; 2c703f18
	v_mul_f32_e32 v56, v56, v42                                 ; 0a705538
	v_mac_f32_e32 v56, v53, v39                                 ; 2c704f35
	v_mac_f32_e32 v56, v49, v43                                 ; 2c705731
	v_mac_f32_e32 v56, v46, v38                                 ; 2c704d2e
	v_mac_f32_e32 v7, v36, v56                                  ; 2c0e7124
	s_cbranch_scc0 BB64                                         ; bf840062
BB56:
	s_add_u32 s0, s16, 3                                        ; 80008310
	s_mul_i32 s0, s0, s3                                        ; 92000300
	s_add_u32 s0, s19, s0                                       ; 80000013
	v_add_u32_e32 v9, s0, v0                                    ; 68120000
	v_lshlrev_b32_e32 v10, 4, v9                                ; 24141284
	v_lshl_add_u32 v9, v9, 7, v10                               ; d1fd0009 04290f09
	v_add_u32_e32 v31, 16, v9                                   ; 683e1290
	v_add_u32_e32 v32, v31, v4                                  ; 6840091f
	v_add_u32_e32 v31, v31, v33                                 ; 683e431f
	buffer_load_dwordx4 v[36:39], v9, s[12:15], 0 offen         ; e05c1000 80032409
	buffer_load_dword v32, v32, s[12:15], 0 offen               ; e0501000 80032020
	buffer_load_dword v31, v31, s[12:15], 0 offen               ; e0501000 80031f1f
	s_bfm_b32 s1, 16, 16                                        ; 91019090
	s_mov_b32 s5, 0xf0f0f0f                                     ; be8500ff 0f0f0f0f
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_lshlrev_b32_e32 v38, v5, v38                              ; 244c4d05
	v_bfe_u32 v39, v39, v2, 16                                  ; d1c80027 02420527
	v_bfe_u32 v37, v37, v2, 16                                  ; d1c80025 02420525
	v_lshl_or_b32 v39, v39, 12, v39                             ; d2000027 049d1927
	v_and_or_b32 v38, s1, v38, v37                              ; d2010026 04964c01
	v_and_b32_e32 v33, 0xc0c0c0c0, v38                          ; 26424cff c0c0c0c0
	v_and_b32_e32 v38, 0x3f3f3f3f, v38                          ; 264c4cff 3f3f3f3f
	v_cvt_f32_f16_sdwa v43, v36 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e5616f9 00050624
	v_lshrrev_b32_e32 v33, 2, v33                               ; 20424282
	v_cvt_f32_ubyte1_e32 v42, v38                               ; 7e542526
	v_cvt_f32_f16_e32 v36, v36                                  ; 7e481724
	v_cvt_f32_ubyte3_e32 v37, v38                               ; 7e4a2926
	v_cvt_f32_ubyte2_e32 v40, v38                               ; 7e502726
	v_cvt_f32_ubyte0_e32 v38, v38                               ; 7e4c2326
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v44, s5, v32                                  ; 26584005
	v_and_or_b32 v39, s5, v39, v33                              ; d2010027 04864e05
	v_cvt_f32_ubyte1_e32 v47, v44                               ; 7e5e252c
	v_cvt_f32_ubyte3_e32 v45, v44                               ; 7e5a292c
	v_cvt_f32_ubyte2_e32 v46, v44                               ; 7e5c272c
	v_cvt_f32_ubyte0_e32 v44, v44                               ; 7e58232c
	v_cvt_f32_ubyte3_e32 v34, v39                               ; 7e442927
	v_cvt_f32_ubyte2_e32 v35, v39                               ; 7e462727
	v_cvt_f32_ubyte1_e32 v41, v39                               ; 7e522527
	v_cvt_f32_ubyte0_e32 v39, v39                               ; 7e4e2327
	v_lshrrev_b32_e32 v32, 4, v32                               ; 20404084
	v_mul_f32_e32 v15, v15, v45                                 ; 0a1e5b0f
	v_mul_f32_e32 v30, v30, v34                                 ; 0a3c451e
	v_and_b32_e32 v32, s5, v32                                  ; 26404005
	v_mac_f32_e32 v15, v14, v46                                 ; 2c1e5d0e
	v_mac_f32_e32 v30, v29, v35                                 ; 2c3c471d
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v51, s5, v31                                  ; 26663e05
	v_cvt_f32_ubyte3_e32 v48, v32                               ; 7e602920
	v_cvt_f32_ubyte2_e32 v49, v32                               ; 7e622720
	v_cvt_f32_ubyte1_e32 v50, v32                               ; 7e642520
	v_cvt_f32_ubyte0_e32 v32, v32                               ; 7e402320
	v_mac_f32_e32 v15, v13, v47                                 ; 2c1e5f0d
	v_mac_f32_e32 v30, v28, v37                                 ; 2c3c4b1c
	v_cvt_f32_ubyte2_e32 v53, v51                               ; 7e6a2733
	v_cvt_f32_ubyte3_e32 v52, v51                               ; 7e682933
	v_mul_f32_e32 v19, v19, v48                                 ; 0a266113
	v_cvt_f32_ubyte1_e32 v54, v51                               ; 7e6c2533
	v_cvt_f32_ubyte0_e32 v51, v51                               ; 7e662333
	v_mac_f32_e32 v15, v12, v44                                 ; 2c1e590c
	v_lshrrev_b32_e32 v31, 4, v31                               ; 203e3e84
	v_mac_f32_e32 v30, v11, v40                                 ; 2c3c510b
	v_mul_f32_e32 v23, v23, v52                                 ; 0a2e6917
	v_mac_f32_e32 v19, v18, v49                                 ; 2c266312
	v_and_b32_e32 v31, s5, v31                                  ; 263e3e05
	v_mad_f32 v8, -v43, v30, v8                                 ; d1c10008 24223d2b
	v_mac_f32_e32 v23, v22, v53                                 ; 2c2e6b16
	v_mac_f32_e32 v19, v17, v50                                 ; 2c266511
	v_cvt_f32_ubyte1_e32 v57, v31                               ; 7e72251f
	v_cvt_f32_ubyte2_e32 v56, v31                               ; 7e70271f
	v_cvt_f32_ubyte3_e32 v55, v31                               ; 7e6e291f
	v_cvt_f32_ubyte0_e32 v31, v31                               ; 7e3e231f
	v_mac_f32_e32 v23, v21, v54                                 ; 2c2e6d15
	v_mac_f32_e32 v19, v16, v32                                 ; 2c264110
	v_mul_f32_e32 v27, v27, v55                                 ; 0a366f1b
	v_mac_f32_e32 v23, v20, v51                                 ; 2c2e6714
	v_mac_f32_e32 v27, v26, v56                                 ; 2c36711a
	v_mac_f32_e32 v27, v25, v57                                 ; 2c367319
	v_mac_f32_e32 v27, v24, v31                                 ; 2c363f18
	v_mul_f32_e32 v27, v27, v41                                 ; 0a36531b
	v_mac_f32_e32 v27, v23, v39                                 ; 2c364f17
	v_mac_f32_e32 v27, v19, v42                                 ; 2c365513
	v_mac_f32_e32 v27, v15, v38                                 ; 2c364d0f
	v_mac_f32_e32 v8, v36, v27                                  ; 2c103724
BB64:
	v_add_u32_e32 v0, 4, v0                                     ; 68000084
	s_branch BB47                                               ; bf82fe3e
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
	v_readlane_b32 s5, v63, 63                                  ; d2890005 00017f3f
	s_cbranch_scc0 BB73                                         ; bf840034
BB68:
	s_or_saveexec_b64 s[10:11], -1                              ; be8a21c1
	s_cmp_lt_u32 3, s4                                          ; bf0a0483
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
	v_readlane_b32 s6, v63, 63                                  ; d2890006 00017f3f
	s_cbranch_scc0 BB71                                         ; bf840019
BB69:
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
	v_readlane_b32 s9, v63, 63                                  ; d2890009 00017f3f
	v_mov_b32_e32 v8, s9                                        ; 7e100209
BB71:
	v_mov_b32_e32 v7, s6                                        ; 7e0e0206
BB73:
	v_mov_b32_e32 v6, s5                                        ; 7e0c0205
BB75:
	v_mov_b32_e32 v3, s3                                        ; 7e060203
BB77:
	s_mov_b64 s[10:11], 1                                       ; be8a0181
	s_and_b64 exec, s[0:1], s[10:11]                            ; 86fe0a00
	s_cbranch_execz BB119                                       ; bf880083
BB78:
	s_bitcmp1_b32 s8, 0                                         ; bf0d8008
	s_cbranch_scc0 BB80                                         ; bf84000e
BB79:
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
	v_add_f32_e32 v6, s5, v6                                    ; 020c0c05
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
	v_add_f32_e32 v6, s5, v6                                    ; 020c0c05
	s_branch BB91                                               ; bf820001
BB90:
	s_mov_b32 s0, src_scc                                       ; be8000fd
BB91:
	s_add_u32 s5, s7, 4                                         ; 80058407
	buffer_store_dword v6, off, s[8:11], s5                     ; e0700000 05020680
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
	v_add_f32_e32 v7, s5, v7                                    ; 020e0e05
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
	v_add_f32_e32 v7, s5, v7                                    ; 020e0e05
	s_branch BB98                                               ; bf820001
BB97:
	s_mov_b32 s0, src_scc                                       ; be8000fd
BB98:
	s_add_u32 s5, s7, 8                                         ; 80058807
	buffer_store_dword v7, off, s[8:11], s5                     ; e0700000 05020780
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
	v_add_f32_e32 v8, s1, v8                                    ; 02101001
BB102:
	s_cmp_lg_i32 s0, 0                                          ; bf018000
	s_cbranch_scc0 BB105                                        ; bf840008
BB103:
	s_load_dwordx4 s[0:3], s[2:3], 0x40                         ; c00a0001 00000040
	s_add_u32 s4, s7, 12                                        ; 80048c07
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s4, s[0:3], s4                          ; c0200100 00000004
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v8, s4, v8                                    ; 02101004
BB105:
	s_add_u32 s7, s7, 12                                        ; 80078c07
	buffer_store_dword v8, off, s[8:11], s7                     ; e0700000 07020880
BB119:
	s_endpgm                                                    ; bf810000
