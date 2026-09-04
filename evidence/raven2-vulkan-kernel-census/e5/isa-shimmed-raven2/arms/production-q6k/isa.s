BB0:
	s_load_dword s0, s[14:15], 0x0                              ; c0020007 00000000
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_mul_i32 s0, s0, s18                                       ; 92001200
	s_add_u32 s16, s16, s0                                      ; 80100010
	s_lshl_b32 s16, s16, 2                                      ; 8e108210
	s_add_u32 s1, s16, 4                                        ; 80018410
	s_cmp_ge_u32 s4, s1                                         ; bf090104
	s_cbranch_scc0 BB87                                         ; bf840628
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
	v_and_b32_e32 v1, 8, v0                                     ; 26020088
	v_and_b32_e32 v2, 15, v0                                    ; 2604008f
	s_lshr_b32 s3, s3, 8                                        ; 8f038803
	v_lshrrev_b32_e32 v0, 4, v0                                 ; 20000084
	s_mov_b32 s1, 0                                             ; be810080
	s_mul_i32 s18, s18, s5                                      ; 92120512
	v_sub_u32_e32 v3, v2, v1                                    ; 6a060302
	v_lshrrev_b32_e32 v4, 3, v2                                 ; 20080483
	v_mov_b32_e32 v8, 0                                         ; 7e100280
	s_and_b32 s0, s3, 3                                         ; 86008303
	v_mov_b32_e32 v9, 0                                         ; 7e120280
	v_lshlrev_b32_e32 v5, 2, v3                                 ; 240a0682
	v_lshrrev_b32_e32 v3, 2, v3                                 ; 20060682
	s_sub_i32 s0, s3, s0                                        ; 81800003
	v_lshl_add_u32 v6, v4, 6, v5                                ; d1fd0006 04150d04
	v_lshl_add_u32 v7, v4, 5, v5                                ; d1fd0007 04150b04
	v_lshl_add_u32 v4, v4, 7, v5                                ; d1fd0004 04150f04
	v_mov_b32_e32 v5, 0                                         ; 7e0a0280
	v_add_u32_e32 v1, v1, v3                                    ; 68020701
	v_mov_b32_e32 v3, 0                                         ; 7e060280
	s_branch BB5                                                ; bf820214
BB7:
	s_mov_b32 s4, s2                                            ; be840002
	s_movk_i32 s5, 0x8000                                       ; b0058000
	s_load_dwordx8 s[24:31], s[4:5], 0x0                        ; c00e0602 00000000
	v_add_u32_e32 v10, s1, v0                                   ; 68140001
	s_mul_i32 s4, s16, s3                                       ; 92040310
	v_add_u32_e32 v15, 32, v6                                   ; 681e0ca0
	s_movk_i32 s5, 0x80                                         ; b0050080
	s_movk_i32 s9, 0xc0                                         ; b00900c0
	s_add_u32 s4, s18, s4                                       ; 80040412
	v_add_u32_e32 v11, s4, v10                                  ; 68161404
	v_lshlrev_b32_e32 v12, 1, v11                               ; 24181681
	v_lshl_add_u32 v12, v11, 4, v12                             ; d1fd000c 0431090b
	v_lshl_add_u32 v12, v11, 6, v12                             ; d1fd000c 04310d0b
	v_lshl_add_u32 v11, v11, 7, v12                             ; d1fd000b 04310f0b
	v_add3_u32 v17, v2, s9, v11                                 ; d1ff0011 042c1302
	v_and_b32_e32 v13, -4, v11                                  ; 261a16c4
	v_add_u32_e32 v14, v13, v6                                  ; 681c0d0d
	v_add_u32_e32 v16, v13, v15                                 ; 68201f0d
	v_add3_u32 v13, v7, s5, v13                                 ; d1ff000d 04340b07
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_load_dwordx2 v[22:23], v14, s[24:27], 0 offen        ; e0541000 8006160e
	buffer_load_dwordx2 v[24:25], v16, s[24:27], 0 offen        ; e0541000 80061810
	buffer_load_dwordx2 v[12:13], v13, s[24:27], 0 offen        ; e0541000 80060c0d
	buffer_load_sbyte v17, v17, s[24:27], 0 offen               ; e0441000 80061111
	buffer_load_short_d16 v21, v11, s[24:27], 0 offen offset:208 ; e09010d0 8006150b
	v_lshl_add_u32 v26, v10, 8, v4                              ; d1fd001a 0411110a
	s_mul_i32 s10, s6, s17                                      ; 920a1106
	v_add_u32_e32 v26, s10, v26                                 ; 6834340a
	v_lshrrev_b32_e32 v26, 2, v26                               ; 20343482
	v_lshlrev_b32_e32 v26, 4, v26                               ; 24343484
	buffer_load_dwordx4 v[28:31], v26, s[28:31], 0 offen        ; e05c1000 80071c1a
	buffer_load_dwordx4 v[32:35], v26, s[28:31], 0 offen offset:128 ; e05c1080 8007201a
	buffer_load_dwordx4 v[36:39], v26, s[28:31], 0 offen offset:256 ; e05c1100 8007241a
	buffer_load_dwordx4 v[40:43], v26, s[28:31], 0 offen offset:384 ; e05c1180 8007281a
	v_add_u32_e32 v18, v11, v6                                  ; 68240d0b
	v_add_u32_e32 v19, v11, v15                                 ; 68261f0b
	v_add3_u32 v20, v7, s5, v11                                 ; d1ff0014 042c0b07
	s_add_u32 s11, s16, 1                                       ; 800b8110
	s_mul_i32 s11, s11, s3                                      ; 920b030b
	s_add_u32 s11, s18, s11                                     ; 800b0b12
	s_add_u32 s12, s16, 2                                       ; 800c8210
	v_add_u32_e32 v27, s11, v10                                 ; 6836140b
	s_mul_i32 s12, s12, s3                                      ; 920c030c
	v_lshlrev_b32_e32 v44, 1, v27                               ; 24583681
	s_add_u32 s12, s18, s12                                     ; 800c0c12
	v_lshl_add_u32 v44, v27, 4, v44                             ; d1fd002c 04b1091b
	v_add_u32_e32 v52, s12, v10                                 ; 6868140c
	v_lshl_add_u32 v44, v27, 6, v44                             ; d1fd002c 04b10d1b
	v_lshlrev_b32_e32 v53, 1, v52                               ; 246a6881
	v_lshl_add_u32 v27, v27, 7, v44                             ; d1fd001b 04b10f1b
	v_lshl_add_u32 v53, v52, 4, v53                             ; d1fd0035 04d50934
	v_add_u32_e32 v49, v27, v6                                  ; 68620d1b
	v_add_u32_e32 v50, v27, v15                                 ; 68641f1b
	v_and_b32_e32 v45, -4, v27                                  ; 265a36c4
	v_add3_u32 v51, v7, s5, v27                                 ; d1ff0033 046c0b07
	v_add3_u32 v48, v2, s9, v27                                 ; d1ff0030 046c1302
	v_lshl_add_u32 v53, v52, 6, v53                             ; d1fd0035 04d50d34
	v_add_u32_e32 v46, v45, v6                                  ; 685c0d2d
	v_add_u32_e32 v47, v45, v15                                 ; 685e1f2d
	v_add3_u32 v45, v7, s5, v45                                 ; d1ff002d 04b40b07
	v_lshl_add_u32 v52, v52, 7, v53                             ; d1fd0034 04d50f34
	v_and_b32_e32 v54, -4, v52                                  ; 266c68c4
	v_add_u32_e32 v55, v54, v6                                  ; 686e0d36
	v_add_u32_e32 v56, v54, v15                                 ; 68701f36
	buffer_load_dwordx2 v[58:59], v46, s[24:27], 0 offen        ; e0541000 80063a2e
	buffer_load_dwordx2 v[46:47], v47, s[24:27], 0 offen        ; e0541000 80062e2f
	buffer_load_dwordx2 v[44:45], v45, s[24:27], 0 offen        ; e0541000 80062c2d
	buffer_load_sbyte v48, v48, s[24:27], 0 offen               ; e0441000 80063030
	buffer_load_short_d16 v57, v27, s[24:27], 0 offen offset:208 ; e09010d0 8006391b
	buffer_load_dwordx2 v[26:27], v55, s[24:27], 0 offen        ; e0541000 80061a37
	buffer_load_dwordx2 v[60:61], v56, s[24:27], 0 offen        ; e0541000 80063c38
	v_add3_u32 v54, v7, s5, v54                                 ; d1ff0036 04d80b07
	buffer_load_dwordx2 v[54:55], v54, s[24:27], 0 offen        ; e0541000 80063636
	s_mov_b32 s13, 0x3030303                                    ; be8d00ff 03030303
	s_mov_b32 s14, 0xf0f0f0f                                    ; be8e00ff 0f0f0f0f
	s_mov_b32 s15, 0xc0c0c0c                                    ; be8f00ff 0c0c0c0c
	s_mov_b32 s19, 0x30303030                                   ; be9300ff 30303030
	s_mov_b32 s20, 0xc0c0c0c0                                   ; be9400ff c0c0c0c0
	v_lshlrev_b32_e32 v62, 6, v0                                ; 247c0086
	s_mov_b32 s21, 0xc2000000                                   ; be9500ff c2000000
	v_add_u32_e32 v14, v52, v6                                  ; 681c0d34
	v_add_u32_e32 v16, v52, v15                                 ; 68201f34
	v_add3_u32 v53, v7, s5, v52                                 ; d1ff0035 04d00b07
	v_lshl_add_u32 v11, v2, 2, v62                              ; d1fd000b 04f90502
	v_lshl_add_u32 v62, v1, 2, v62                              ; d1fd003e 04f90501
	s_waitcnt vmcnt(16)                                         ; bf8c7f70
	v_alignbyte_b32 v23, v23, v22, v18                          ; d1cf0017 044a2d17
	s_waitcnt vmcnt(15)                                         ; bf8c3f7f
	v_alignbyte_b32 v25, v25, v24, v19                          ; d1cf0019 044e3119
	s_waitcnt vmcnt(14)                                         ; bf8c3f7e
	v_alignbyte_b32 v13, v13, v12, v20                          ; d1cf000d 0452190d
	v_and_b32_e32 v56, s14, v25                                 ; 2670320e
	v_lshrrev_b32_e32 v25, 4, v25                               ; 20323284
	v_and_b32_e32 v18, s15, v13                                 ; 26241a0f
	v_and_b32_e32 v12, s13, v13                                 ; 26181a0d
	v_lshl_or_b32 v18, v18, 2, v56                              ; d2000012 04e10512
	v_lshlrev_b32_e32 v12, 4, v12                               ; 24181884
	s_waitcnt vmcnt(13)                                         ; bf8c3f7d
	v_cvt_f32_i32_e32 v17, v17                                  ; 7e220b11
	v_cvt_f32_ubyte0_e32 v20, v18                               ; 7e282312
	v_and_or_b32 v12, s14, v23, v12                             ; d201000c 04322e0e
	v_lshrrev_b32_e32 v23, 4, v23                               ; 202e2e84
	v_add_f32_e32 v20, s21, v20                                 ; 02282815
	v_cvt_f32_ubyte0_e32 v19, v12                               ; 7e26230c
	v_and_b32_e32 v23, s14, v23                                 ; 262e2e0e
	v_add_f32_e32 v19, s21, v19                                 ; 02262615
	v_and_or_b32 v23, s19, v13, v23                             ; d2010017 045e1a13
	v_and_b32_e32 v13, s20, v13                                 ; 261a1a14
	v_cvt_f32_ubyte0_e32 v22, v23                               ; 7e2c2317
	v_lshrrev_b32_e32 v13, 2, v13                               ; 201a1a82
	v_add_f32_e32 v22, s21, v22                                 ; 022c2c15
	v_and_or_b32 v25, s14, v25, v13                             ; d2010019 0436320e
	v_cvt_f32_ubyte0_e32 v24, v25                               ; 7e302319
	v_add_f32_e32 v24, s21, v24                                 ; 02303015
	ds_write_b32 v11, v17 offset:256                            ; d81a0100 0000110b
	v_cvt_f32_ubyte1_e32 v56, v12                               ; 7e70250c
	v_cvt_f32_ubyte1_e32 v13, v18                               ; 7e1a2512
	s_waitcnt vmcnt(10)                                         ; bf8c3f7a
	v_mul_f32_e32 v20, v32, v20                                 ; 0a282920
	v_mul_f32_e32 v19, v28, v19                                 ; 0a26271c
	v_cvt_f32_ubyte1_e32 v17, v23                               ; 7e222517
	s_waitcnt vmcnt(9)                                          ; bf8c3f79
	v_mul_f32_e32 v22, v36, v22                                 ; 0a2c2d24
	s_waitcnt vmcnt(8)                                          ; bf8c3f78
	v_mul_f32_e32 v24, v40, v24                                 ; 0a303128
	v_add_f32_e32 v56, s21, v56                                 ; 02707015
	v_add_f32_e32 v13, s21, v13                                 ; 021a1a15
	v_add_f32_e32 v17, s21, v17                                 ; 02222215
	v_mac_f32_e32 v19, v29, v56                                 ; 2c26711d
	v_cvt_f32_ubyte1_e32 v56, v25                               ; 7e702519
	v_mac_f32_e32 v20, v33, v13                                 ; 2c281b21
	v_cvt_f32_ubyte2_e32 v13, v12                               ; 7e1a270c
	v_mac_f32_e32 v22, v37, v17                                 ; 2c2c2325
	v_cvt_f32_ubyte2_e32 v17, v18                               ; 7e222712
	v_cvt_f32_ubyte3_e32 v12, v12                               ; 7e18290c
	v_add_f32_e32 v56, s21, v56                                 ; 02707015
	v_add_f32_e32 v13, s21, v13                                 ; 021a1a15
	v_add_f32_e32 v12, s21, v12                                 ; 02181815
	v_mac_f32_e32 v24, v41, v56                                 ; 2c307129
	v_mac_f32_e32 v19, v30, v13                                 ; 2c261b1e
	v_cvt_f32_ubyte2_e32 v13, v25                               ; 7e1a2719
	v_cvt_f32_ubyte2_e32 v56, v23                               ; 7e702717
	v_cvt_f32_ubyte3_e32 v18, v18                               ; 7e242912
	v_add_f32_e32 v17, s21, v17                                 ; 02222215
	v_mac_f32_e32 v19, v31, v12                                 ; 2c26191f
	v_add_f32_e32 v13, s21, v13                                 ; 021a1a15
	v_add_f32_e32 v18, s21, v18                                 ; 02242415
	v_mac_f32_e32 v20, v34, v17                                 ; 2c282322
	v_mac_f32_e32 v24, v42, v13                                 ; 2c301b2a
	v_mac_f32_e32 v20, v35, v18                                 ; 2c282523
	ds_read2_b32 v[12:13], v62 offset0:64 offset1:66            ; d86e4240 0c00003e
	ds_read2_b32 v[17:18], v62 offset0:68 offset1:70            ; d86e4644 1100003e
	v_cvt_f32_ubyte3_e32 v23, v23                               ; 7e2e2917
	v_cvt_f32_ubyte3_e32 v25, v25                               ; 7e322919
	v_add_f32_e32 v56, s21, v56                                 ; 02707015
	v_add_f32_e32 v23, s21, v23                                 ; 022e2e15
	v_add_f32_e32 v25, s21, v25                                 ; 02323215
	v_mac_f32_e32 v22, v38, v56                                 ; 2c2c7126
	v_mac_f32_e32 v24, v43, v25                                 ; 2c30332b
	v_mac_f32_e32 v22, v39, v23                                 ; 2c2c2f27
	v_add3_u32 v23, v2, s9, v52                                 ; d1ff0017 04d01302
	buffer_load_sbyte v23, v23, s[24:27], 0 offen               ; e0441000 80061717
	buffer_load_short_d16 v25, v52, s[24:27], 0 offen offset:208 ; e09010d0 80061934
	v_cvt_f32_f16_e32 v52, v21                                  ; 7e681715
	s_add_u32 s22, s16, 3                                       ; 80168310
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_mul_f32_e32 v24, v24, v18                                 ; 0a302518
	s_mul_i32 s22, s22, s3                                      ; 92160316
	v_mac_f32_e32 v24, v22, v17                                 ; 2c302316
	s_add_u32 s22, s18, s22                                     ; 80161612
	v_mac_f32_e32 v24, v20, v13                                 ; 2c301b14
	v_add_u32_e32 v10, s22, v10                                 ; 68141416
	v_mac_f32_e32 v24, v19, v12                                 ; 2c301913
	v_lshlrev_b32_e32 v56, 1, v10                               ; 24701481
	v_mac_f32_e32 v3, v24, v52                                  ; 2c066918
	v_mov_b32_e32 v52, v14                                      ; 7e68030e
	v_lshl_add_u32 v56, v10, 4, v56                             ; d1fd0038 04e1090a
	v_lshl_add_u32 v56, v10, 6, v56                             ; d1fd0038 04e10d0a
	v_lshl_add_u32 v10, v10, 7, v56                             ; d1fd000a 04e10f0a
	v_add_u32_e32 v20, v10, v15                                 ; 68281f0a
	v_add3_u32 v22, v2, s9, v10                                 ; d1ff0016 04281302
	v_and_b32_e32 v17, -4, v10                                  ; 262214c4
	v_add_u32_e32 v18, v17, v6                                  ; 68240d11
	v_add_u32_e32 v15, v17, v15                                 ; 681e1f11
	v_add3_u32 v17, v7, s5, v17                                 ; d1ff0011 04440b07
	buffer_load_dwordx2 v[12:13], v18, s[24:27], 0 offen        ; e0541000 80060c12
	buffer_load_dwordx2 v[18:19], v15, s[24:27], 0 offen        ; e0541000 8006120f
	buffer_load_dwordx2 v[14:15], v17, s[24:27], 0 offen        ; e0541000 80060e11
	buffer_load_sbyte v22, v22, s[24:27], 0 offen               ; e0441000 80061616
	buffer_load_short_d16 v56, v10, s[24:27], 0 offen offset:208 ; e09010d0 8006380a
	s_add_u32 s1, s1, 4                                         ; 80018401
	s_waitcnt vmcnt(14)                                         ; bf8c3f7e
	v_alignbyte_b32 v59, v59, v58, v49                          ; d1cf003b 04c6753b
	s_waitcnt vmcnt(13)                                         ; bf8c3f7d
	v_alignbyte_b32 v47, v47, v46, v50                          ; d1cf002f 04ca5d2f
	v_add3_u32 v21, v7, s5, v10                                 ; d1ff0015 04280b07
	v_add_u32_e32 v24, v10, v6                                  ; 68300d0a
	s_waitcnt vmcnt(12)                                         ; bf8c3f7c
	v_alignbyte_b32 v45, v45, v44, v51                          ; d1cf002d 04ce592d
	v_and_b32_e32 v58, s14, v47                                 ; 26745e0e
	v_lshrrev_b32_e32 v47, 4, v47                               ; 205e5e84
	v_and_b32_e32 v10, s13, v45                                 ; 26145a0d
	v_and_b32_e32 v17, s15, v45                                 ; 26225a0f
	v_lshlrev_b32_e32 v10, 4, v10                               ; 24141484
	v_lshl_or_b32 v17, v17, 2, v58                              ; d2000011 04e90511
	v_and_or_b32 v10, s14, v59, v10                             ; d201000a 042a760e
	v_lshrrev_b32_e32 v59, 4, v59                               ; 20767684
	v_cvt_f32_ubyte0_e32 v44, v10                               ; 7e58230a
	v_and_b32_e32 v59, s14, v59                                 ; 2676760e
	v_cvt_f32_ubyte1_e32 v50, v10                               ; 7e64250a
	v_add_f32_e32 v44, s21, v44                                 ; 02585815
	v_and_or_b32 v59, s19, v45, v59                             ; d201003b 04ee5a13
	v_and_b32_e32 v45, s20, v45                                 ; 265a5a14
	v_add_f32_e32 v50, s21, v50                                 ; 02646415
	v_cvt_f32_ubyte1_e32 v51, v17                               ; 7e662511
	v_mul_f32_e32 v44, v28, v44                                 ; 0a58591c
	v_cvt_f32_ubyte0_e32 v46, v59                               ; 7e5c233b
	v_lshrrev_b32_e32 v45, 2, v45                               ; 205a5a82
	v_cvt_f32_ubyte1_e32 v58, v59                               ; 7e74253b
	v_add_f32_e32 v51, s21, v51                                 ; 02666615
	v_mac_f32_e32 v44, v29, v50                                 ; 2c58651d
	v_add_f32_e32 v46, s21, v46                                 ; 025c5c15
	v_and_or_b32 v47, s14, v47, v45                             ; d201002f 04b65e0e
	v_cvt_f32_ubyte0_e32 v45, v17                               ; 7e5a2311
	v_add_f32_e32 v58, s21, v58                                 ; 02747415
	v_mul_f32_e32 v46, v36, v46                                 ; 0a5c5d24
	v_cvt_f32_ubyte1_e32 v50, v47                               ; 7e64252f
	v_cvt_f32_ubyte0_e32 v49, v47                               ; 7e62232f
	v_add_f32_e32 v45, s21, v45                                 ; 025a5a15
	v_mac_f32_e32 v46, v37, v58                                 ; 2c5c7525
	v_cvt_f32_ubyte2_e32 v58, v17                               ; 7e742711
	v_add_f32_e32 v50, s21, v50                                 ; 02646415
	v_add_f32_e32 v49, s21, v49                                 ; 02626215
	v_mul_f32_e32 v45, v32, v45                                 ; 0a5a5b20
	s_waitcnt vmcnt(11)                                         ; bf8c3f7b
	v_cvt_f32_i32_e32 v48, v48                                  ; 7e600b30
	v_add_f32_e32 v58, s21, v58                                 ; 02747415
	v_mul_f32_e32 v49, v40, v49                                 ; 0a626328
	v_mac_f32_e32 v45, v33, v51                                 ; 2c5a6721
	v_cvt_f32_ubyte2_e32 v51, v10                               ; 7e66270a
	v_mac_f32_e32 v49, v41, v50                                 ; 2c626529
	v_cvt_f32_ubyte2_e32 v50, v59                               ; 7e64273b
	v_mac_f32_e32 v45, v34, v58                                 ; 2c5a7522
	v_add_f32_e32 v51, s21, v51                                 ; 02666615
	v_add_f32_e32 v50, s21, v50                                 ; 02646415
	v_mac_f32_e32 v44, v30, v51                                 ; 2c58671e
	v_mac_f32_e32 v46, v38, v50                                 ; 2c5c6526
	ds_write_b32 v11, v48                                       ; d81a0000 0000300b
	v_cvt_f32_ubyte2_e32 v51, v47                               ; 7e66272f
	v_cvt_f32_ubyte3_e32 v10, v10                               ; 7e14290a
	v_mov_b32_e32 v58, v9                                       ; 7e740309
	v_add_f32_e32 v51, s21, v51                                 ; 02666615
	v_add_f32_e32 v10, s21, v10                                 ; 02141415
	v_mac_f32_e32 v49, v42, v51                                 ; 2c62672a
	v_mac_f32_e32 v44, v31, v10                                 ; 2c58151f
	ds_read2_b32 v[50:51], v62 offset1:2                        ; d86e0200 3200003e
	ds_read2_b32 v[9:10], v62 offset0:4 offset1:6               ; d86e0604 0900003e
	v_cvt_f32_ubyte3_e32 v17, v17                               ; 7e222911
	v_cvt_f32_ubyte3_e32 v59, v59                               ; 7e76293b
	v_cvt_f32_ubyte3_e32 v47, v47                               ; 7e5e292f
	s_waitcnt vmcnt(9)                                          ; bf8c3f79
	v_alignbyte_b32 v27, v27, v26, v52                          ; d1cf001b 04d2351b
	s_waitcnt vmcnt(8)                                          ; bf8c3f78
	v_alignbyte_b32 v61, v61, v60, v16                          ; d1cf003d 0442793d
	s_waitcnt vmcnt(7)                                          ; bf8c3f77
	v_alignbyte_b32 v55, v55, v54, v53                          ; d1cf0037 04d66d37
	v_add_f32_e32 v17, s21, v17                                 ; 02222215
	v_add_f32_e32 v59, s21, v59                                 ; 02767615
	v_add_f32_e32 v47, s21, v47                                 ; 025e5e15
	v_and_b32_e32 v60, s14, v61                                 ; 26787a0e
	v_lshrrev_b32_e32 v61, 4, v61                               ; 207a7a84
	v_and_b32_e32 v16, s13, v55                                 ; 26206e0d
	v_mac_f32_e32 v45, v35, v17                                 ; 2c5a2323
	v_and_b32_e32 v17, s15, v55                                 ; 26226e0f
	v_mac_f32_e32 v46, v39, v59                                 ; 2c5c7727
	v_cvt_f32_f16_e32 v59, v57                                  ; 7e761739
	v_mac_f32_e32 v49, v43, v47                                 ; 2c625f2b
	v_lshlrev_b32_e32 v16, 4, v16                               ; 24202084
	v_lshl_or_b32 v17, v17, 2, v60                              ; d2000011 04f10511
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_mul_f32_e32 v49, v49, v10                                 ; 0a621531
	v_and_or_b32 v16, s14, v27, v16                             ; d2010010 0442360e
	v_lshrrev_b32_e32 v27, 4, v27                               ; 20363684
	v_cvt_f32_ubyte0_e32 v47, v17                               ; 7e5e2311
	v_mac_f32_e32 v49, v46, v9                                  ; 2c62132e
	v_cvt_f32_ubyte0_e32 v26, v16                               ; 7e342310
	v_and_b32_e32 v27, s14, v27                                 ; 2636360e
	v_add_f32_e32 v47, s21, v47                                 ; 025e5e15
	v_mac_f32_e32 v49, v45, v51                                 ; 2c62672d
	v_add_f32_e32 v26, s21, v26                                 ; 02343415
	v_and_or_b32 v27, s19, v55, v27                             ; d201001b 046e6e13
	v_and_b32_e32 v55, s20, v55                                 ; 266e6e14
	v_mul_f32_e32 v47, v32, v47                                 ; 0a5e5f20
	v_mac_f32_e32 v49, v44, v50                                 ; 2c62652c
	v_cvt_f32_ubyte1_e32 v50, v16                               ; 7e642510
	v_mul_f32_e32 v26, v28, v26                                 ; 0a34351c
	v_cvt_f32_ubyte0_e32 v48, v27                               ; 7e60231b
	v_cvt_f32_ubyte1_e32 v51, v17                               ; 7e662511
	v_lshrrev_b32_e32 v55, 2, v55                               ; 206e6e82
	v_mac_f32_e32 v5, v49, v59                                  ; 2c0a7731
	v_cvt_f32_ubyte1_e32 v52, v27                               ; 7e68251b
	v_add_f32_e32 v50, s21, v50                                 ; 02646415
	v_add_f32_e32 v48, s21, v48                                 ; 02606015
	v_add_f32_e32 v51, s21, v51                                 ; 02666615
	v_and_or_b32 v61, s14, v61, v55                             ; d201003d 04de7a0e
	v_cvt_f32_ubyte2_e32 v54, v16                               ; 7e6c2710
	v_add_f32_e32 v52, s21, v52                                 ; 02686815
	v_mac_f32_e32 v26, v29, v50                                 ; 2c34651d
	v_mul_f32_e32 v48, v36, v48                                 ; 0a606124
	v_cvt_f32_ubyte2_e32 v55, v17                               ; 7e6e2711
	v_mac_f32_e32 v47, v33, v51                                 ; 2c5e6721
	v_cvt_f32_ubyte0_e32 v49, v61                               ; 7e62233d
	v_cvt_f32_ubyte1_e32 v53, v61                               ; 7e6a253d
	v_add_f32_e32 v54, s21, v54                                 ; 026c6c15
	v_cvt_f32_ubyte2_e32 v57, v27                               ; 7e72271b
	v_mac_f32_e32 v48, v37, v52                                 ; 2c606925
	v_cvt_f32_ubyte2_e32 v59, v61                               ; 7e76273d
	v_add_f32_e32 v55, s21, v55                                 ; 026e6e15
	v_cvt_f32_ubyte3_e32 v16, v16                               ; 7e202910
	v_add_f32_e32 v49, s21, v49                                 ; 02626215
	v_add_f32_e32 v53, s21, v53                                 ; 026a6a15
	v_mac_f32_e32 v26, v30, v54                                 ; 2c346d1e
	v_cvt_f32_ubyte3_e32 v17, v17                               ; 7e222911
	v_add_f32_e32 v57, s21, v57                                 ; 02727215
	v_add_f32_e32 v59, s21, v59                                 ; 02767615
	v_cvt_f32_ubyte3_e32 v27, v27                               ; 7e36291b
	v_mac_f32_e32 v47, v34, v55                                 ; 2c5e6f22
	v_add_f32_e32 v16, s21, v16                                 ; 02202015
	v_mul_f32_e32 v49, v40, v49                                 ; 0a626328
	v_cvt_f32_ubyte3_e32 v61, v61                               ; 7e7a293d
	v_add_f32_e32 v17, s21, v17                                 ; 02222215
	s_waitcnt vmcnt(6)                                          ; bf8c3f76
	v_cvt_f32_i32_e32 v23, v23                                  ; 7e2e0b17
	v_mac_f32_e32 v48, v38, v57                                 ; 2c607326
	v_add_f32_e32 v27, s21, v27                                 ; 02363615
	v_mac_f32_e32 v26, v31, v16                                 ; 2c34211f
	v_mac_f32_e32 v49, v41, v53                                 ; 2c626b29
	v_add_f32_e32 v61, s21, v61                                 ; 027a7a15
	v_mac_f32_e32 v47, v35, v17                                 ; 2c5e2323
	v_mac_f32_e32 v48, v39, v27                                 ; 2c603727
	v_mac_f32_e32 v49, v42, v59                                 ; 2c62772a
	v_mac_f32_e32 v49, v43, v61                                 ; 2c627b2b
	ds_write_b32 v11, v23 offset:256                            ; d81a0100 0000170b
	ds_read2_b32 v[16:17], v62 offset0:64 offset1:66            ; d86e4240 1000003e
	ds_read2_b32 v[44:45], v62 offset0:68 offset1:70            ; d86e4644 2c00003e
	s_waitcnt vmcnt(5)                                          ; bf8c3f75
	v_cvt_f32_f16_e32 v60, v25                                  ; 7e781719
	s_waitcnt vmcnt(4)                                          ; bf8c3f74
	v_alignbyte_b32 v13, v13, v12, v24                          ; d1cf000d 0462190d
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_alignbyte_b32 v19, v19, v18, v20                          ; d1cf0013 04522513
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_alignbyte_b32 v15, v15, v14, v21                          ; d1cf000f 04561d0f
	v_and_b32_e32 v61, s14, v19                                 ; 267a260e
	v_lshrrev_b32_e32 v19, 4, v19                               ; 20262684
	v_and_b32_e32 v10, s15, v15                                 ; 26141e0f
	v_and_b32_e32 v9, s13, v15                                  ; 26121e0d
	v_lshl_or_b32 v10, v10, 2, v61                              ; d200000a 04f5050a
	v_lshlrev_b32_e32 v9, 4, v9                                 ; 24121284
	v_cvt_f32_ubyte0_e32 v14, v10                               ; 7e1c230a
	v_and_or_b32 v9, s14, v13, v9                               ; d2010009 04261a0e
	v_lshrrev_b32_e32 v13, 4, v13                               ; 201a1a84
	v_add_f32_e32 v14, s21, v14                                 ; 021c1c15
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_cvt_f32_i32_e32 v22, v22                                  ; 7e2c0b16
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_mul_f32_e32 v49, v49, v45                                 ; 0a625b31
	v_cvt_f32_ubyte0_e32 v12, v9                                ; 7e182309
	v_and_b32_e32 v13, s14, v13                                 ; 261a1a0e
	v_mul_f32_e32 v32, v32, v14                                 ; 0a401d20
	v_mac_f32_e32 v49, v48, v44                                 ; 2c625930
	v_add_f32_e32 v12, s21, v12                                 ; 02181815
	v_and_or_b32 v13, s19, v15, v13                             ; d201000d 04361e13
	v_and_b32_e32 v15, s20, v15                                 ; 261e1e14
	v_mac_f32_e32 v49, v47, v17                                 ; 2c62232f
	v_mul_f32_e32 v28, v28, v12                                 ; 0a38191c
	v_lshrrev_b32_e32 v15, 2, v15                               ; 201e1e82
	v_mac_f32_e32 v49, v26, v16                                 ; 2c62211a
	v_and_or_b32 v19, s14, v19, v15                             ; d2010013 043e260e
	v_cvt_f32_ubyte0_e32 v15, v13                               ; 7e1e230d
	v_mac_f32_e32 v8, v49, v60                                  ; 2c107931
	v_cvt_f32_ubyte0_e32 v18, v19                               ; 7e242313
	v_add_f32_e32 v15, s21, v15                                 ; 021e1e15
	v_mul_f32_e32 v36, v36, v15                                 ; 0a481f24
	ds_write_b32 v11, v22                                       ; d81a0000 0000160b
	ds_read2_b32 v[14:15], v62 offset1:2                        ; d86e0200 0e00003e
	ds_read2_b32 v[16:17], v62 offset0:4 offset1:6              ; d86e0604 1000003e
	v_cvt_f32_ubyte1_e32 v20, v9                                ; 7e282509
	v_cvt_f32_ubyte1_e32 v21, v10                               ; 7e2a250a
	v_cvt_f32_ubyte1_e32 v22, v13                               ; 7e2c250d
	v_add_f32_e32 v18, s21, v18                                 ; 02242415
	v_cvt_f32_ubyte1_e32 v23, v19                               ; 7e2e2513
	v_cvt_f32_ubyte2_e32 v24, v9                                ; 7e302709
	v_add_f32_e32 v20, s21, v20                                 ; 02282815
	v_cvt_f32_ubyte2_e32 v25, v10                               ; 7e32270a
	v_add_f32_e32 v21, s21, v21                                 ; 022a2a15
	v_add_f32_e32 v22, s21, v22                                 ; 022c2c15
	v_mul_f32_e32 v40, v40, v18                                 ; 0a502528
	v_cvt_f32_ubyte2_e32 v26, v13                               ; 7e34270d
	v_add_f32_e32 v23, s21, v23                                 ; 022e2e15
	v_add_f32_e32 v24, s21, v24                                 ; 02303015
	v_mac_f32_e32 v28, v29, v20                                 ; 2c38291d
	v_cvt_f32_ubyte2_e32 v27, v19                               ; 7e362713
	v_add_f32_e32 v25, s21, v25                                 ; 02323215
	v_mac_f32_e32 v32, v33, v21                                 ; 2c402b21
	v_cvt_f32_ubyte3_e32 v9, v9                                 ; 7e122909
	v_mac_f32_e32 v36, v37, v22                                 ; 2c482d25
	v_add_f32_e32 v26, s21, v26                                 ; 02343415
	v_mac_f32_e32 v40, v41, v23                                 ; 2c502f29
	v_cvt_f32_ubyte3_e32 v10, v10                               ; 7e14290a
	v_mac_f32_e32 v28, v30, v24                                 ; 2c38311e
	v_add_f32_e32 v27, s21, v27                                 ; 02363615
	v_cvt_f32_ubyte3_e32 v13, v13                               ; 7e1a290d
	v_mac_f32_e32 v32, v34, v25                                 ; 2c403322
	v_add_f32_e32 v9, s21, v9                                   ; 02121215
	v_cvt_f32_ubyte3_e32 v19, v19                               ; 7e262913
	v_mac_f32_e32 v36, v38, v26                                 ; 2c483526
	v_add_f32_e32 v10, s21, v10                                 ; 02141415
	v_mac_f32_e32 v40, v42, v27                                 ; 2c50372a
	v_add_f32_e32 v13, s21, v13                                 ; 021a1a15
	v_mac_f32_e32 v28, v31, v9                                  ; 2c38131f
	v_add_f32_e32 v19, s21, v19                                 ; 02262615
	v_mac_f32_e32 v32, v35, v10                                 ; 2c401523
	v_mac_f32_e32 v36, v39, v13                                 ; 2c481b27
	v_mac_f32_e32 v40, v43, v19                                 ; 2c50272b
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_mul_f32_e32 v40, v40, v17                                 ; 0a502328
	v_mac_f32_e32 v40, v36, v16                                 ; 2c502124
	v_mac_f32_e32 v40, v32, v15                                 ; 2c501f20
	v_mac_f32_e32 v40, v28, v14                                 ; 2c501d1c
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_cvt_f32_f16_e32 v28, v56                                  ; 7e381738
	v_mad_f32 v9, v40, v28, v58                                 ; d1c10009 04ea3928
BB5:
	s_cmp_ge_u32 s1, s0                                         ; bf090001
	s_cbranch_scc0 BB7                                          ; bf84fdea
BB8:
	v_add_u32_e32 v10, s1, v0                                   ; 68140001
	s_mul_i32 s0, s16, s3                                       ; 92000310
	v_lshl_add_u32 v4, v10, 8, v4                               ; d1fd0004 0411110a
	v_cmpx_gt_u32_e32 vcc, s3, v10                              ; 7db81403
	s_add_u32 s0, s18, s0                                       ; 80000012
	s_cbranch_execz BB14                                        ; bf880019
BB9:
	s_mov_b32 s4, s2                                            ; be840002
	s_movk_i32 s5, 0x8000                                       ; b0058000
	s_load_dwordx4 s[12:15], s[4:5], 0x0                        ; c00a0302 00000000
	v_add_u32_e32 v11, s0, v10                                  ; 68161400
	s_movk_i32 s1, 0xc0                                         ; b00100c0
	v_lshlrev_b32_e32 v12, 1, v11                               ; 24181681
	v_lshl_add_u32 v12, v11, 4, v12                             ; d1fd000c 0431090b
	v_lshl_add_u32 v12, v11, 6, v12                             ; d1fd000c 04310d0b
	v_lshl_add_u32 v11, v11, 7, v12                             ; d1fd000b 04310f0b
	v_add3_u32 v11, v2, s1, v11                                 ; d1ff000b 042c0302
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_load_sbyte v11, v11, s[12:15], 0 offen               ; e0441000 80030b0b
	v_lshlrev_b32_e32 v13, 2, v2                                ; 241a0482
	v_lshl_add_u32 v13, v0, 6, v13                              ; d1fd000d 04350d00
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_cvt_f32_i32_e32 v11, v11                                  ; 7e160b0b
	ds_write_b32 v13, v11 offset:256                            ; d81a0100 00000b0d
BB14:
	s_mov_b64 exec, vcc                                         ; befe016a
	s_cbranch_execz BB20                                        ; bf880092
BB15:
	s_mov_b32 s4, s2                                            ; be840002
	s_movk_i32 s5, 0x8000                                       ; b0058000
	s_load_dwordx8 s[24:31], s[4:5], 0x0                        ; c00e0602 00000000
	v_add_u32_e32 v11, s0, v10                                  ; 68161400
	v_add_u32_e32 v15, 32, v6                                   ; 681e0ca0
	s_movk_i32 s0, 0x80                                         ; b0000080
	v_lshlrev_b32_e32 v12, 1, v11                               ; 24181681
	v_lshl_add_u32 v12, v11, 4, v12                             ; d1fd000c 0431090b
	v_lshl_add_u32 v12, v11, 6, v12                             ; d1fd000c 04310d0b
	v_lshl_add_u32 v11, v11, 7, v12                             ; d1fd000b 04310f0b
	v_and_b32_e32 v13, -4, v11                                  ; 261a16c4
	v_add_u32_e32 v16, v11, v15                                 ; 68201f0b
	v_add_u32_e32 v14, v13, v6                                  ; 681c0d0d
	v_add_u32_e32 v15, v13, v15                                 ; 681e1f0d
	v_add3_u32 v13, v7, s0, v13                                 ; d1ff000d 04340107
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_load_dwordx2 v[20:21], v14, s[24:27], 0 offen        ; e0541000 8006140e
	buffer_load_dwordx2 v[14:15], v15, s[24:27], 0 offen        ; e0541000 80060e0f
	buffer_load_dwordx2 v[12:13], v13, s[24:27], 0 offen        ; e0541000 80060c0d
	buffer_load_short_d16 v19, v11, s[24:27], 0 offen offset:208 ; e09010d0 8006130b
	s_mul_i32 s1, s6, s17                                       ; 92011106
	v_add_u32_e32 v22, s1, v4                                   ; 682c0801
	v_lshrrev_b32_e32 v22, 2, v22                               ; 202c2c82
	v_lshlrev_b32_e32 v22, 4, v22                               ; 242c2c84
	buffer_load_dwordx4 v[24:27], v22, s[28:31], 0 offen        ; e05c1000 80071816
	buffer_load_dwordx4 v[28:31], v22, s[28:31], 0 offen offset:128 ; e05c1080 80071c16
	buffer_load_dwordx4 v[32:35], v22, s[28:31], 0 offen offset:256 ; e05c1100 80072016
	buffer_load_dwordx4 v[36:39], v22, s[28:31], 0 offen offset:384 ; e05c1180 80072416
	v_lshlrev_b32_e32 v23, 2, v1                                ; 242e0282
	v_lshl_add_u32 v23, v0, 6, v23                              ; d1fd0017 045d0d00
	ds_read2_b32 v[40:41], v23 offset0:64 offset1:66            ; d86e4240 28000017
	ds_read2_b32 v[22:23], v23 offset0:68 offset1:70            ; d86e4644 16000017
	v_add_u32_e32 v18, v11, v6                                  ; 68240d0b
	v_add3_u32 v17, v7, s0, v11                                 ; d1ff0011 042c0107
	s_mov_b32 s4, 0xf0f0f0f                                     ; be8400ff 0f0f0f0f
	s_mov_b32 s5, 0x30303030                                    ; be8500ff 30303030
	s_mov_b32 s9, 0xc2000000                                    ; be8900ff c2000000
	s_waitcnt vmcnt(7)                                          ; bf8c3f77
	v_alignbyte_b32 v21, v21, v20, v18                          ; d1cf0015 044a2915
	s_waitcnt vmcnt(6)                                          ; bf8c3f76
	v_alignbyte_b32 v15, v15, v14, v16                          ; d1cf000f 04421d0f
	s_waitcnt vmcnt(5)                                          ; bf8c3f75
	v_alignbyte_b32 v13, v13, v12, v17                          ; d1cf000d 0446190d
	v_and_b32_e32 v42, s4, v15                                  ; 26541e04
	v_lshrrev_b32_e32 v15, 4, v15                               ; 201e1e84
	v_and_b32_e32 v44, 0xc0c0c0c, v13                           ; 26581aff 0c0c0c0c
	v_and_b32_e32 v43, 0x3030303, v13                           ; 26561aff 03030303
	v_lshl_or_b32 v44, v44, 2, v42                              ; d200002c 04a9052c
	v_lshlrev_b32_e32 v43, 4, v43                               ; 24565684
	v_cvt_f32_ubyte0_e32 v46, v44                               ; 7e5c232c
	v_and_or_b32 v43, s4, v21, v43                              ; d201002b 04ae2a04
	v_lshrrev_b32_e32 v21, 4, v21                               ; 202a2a84
	v_cvt_f32_ubyte1_e32 v50, v44                               ; 7e64252c
	v_add_f32_e32 v46, s9, v46                                  ; 025c5c09
	v_cvt_f32_ubyte0_e32 v45, v43                               ; 7e5a232b
	v_cvt_f32_ubyte1_e32 v49, v43                               ; 7e62252b
	v_and_b32_e32 v21, s4, v21                                  ; 262a2a04
	v_add_f32_e32 v50, s9, v50                                  ; 02646409
	v_add_f32_e32 v45, s9, v45                                  ; 025a5a09
	v_cvt_f32_ubyte2_e32 v53, v43                               ; 7e6a272b
	v_add_f32_e32 v49, s9, v49                                  ; 02626209
	v_and_or_b32 v21, s5, v13, v21                              ; d2010015 04561a05
	v_and_b32_e32 v13, 0xc0c0c0c0, v13                          ; 261a1aff c0c0c0c0
	v_cvt_f32_ubyte2_e32 v54, v44                               ; 7e6c272c
	v_add_f32_e32 v53, s9, v53                                  ; 026a6a09
	v_cvt_f32_ubyte1_e32 v51, v21                               ; 7e662515
	v_cvt_f32_ubyte0_e32 v47, v21                               ; 7e5e2315
	v_cvt_f32_ubyte2_e32 v55, v21                               ; 7e6e2715
	v_lshrrev_b32_e32 v13, 2, v13                               ; 201a1a82
	v_add_f32_e32 v54, s9, v54                                  ; 026c6c09
	v_cvt_f32_ubyte3_e32 v43, v43                               ; 7e56292b
	v_add_f32_e32 v51, s9, v51                                  ; 02666609
	v_cvt_f32_ubyte3_e32 v44, v44                               ; 7e58292c
	v_add_f32_e32 v47, s9, v47                                  ; 025e5e09
	v_add_f32_e32 v55, s9, v55                                  ; 026e6e09
	v_cvt_f32_ubyte3_e32 v21, v21                               ; 7e2a2915
	v_and_or_b32 v15, s4, v15, v13                              ; d201000f 04361e04
	v_add_f32_e32 v43, s9, v43                                  ; 02565609
	s_waitcnt vmcnt(4)                                          ; bf8c3f74
	v_cvt_f32_f16_e32 v57, v19                                  ; 7e721713
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_mul_f32_e32 v24, v24, v45                                 ; 0a305b18
	v_add_f32_e32 v44, s9, v44                                  ; 02585809
	v_add_f32_e32 v21, s9, v21                                  ; 022a2a09
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_mul_f32_e32 v28, v28, v46                                 ; 0a385d1c
	v_cvt_f32_ubyte1_e32 v52, v15                               ; 7e68250f
	v_cvt_f32_ubyte0_e32 v48, v15                               ; 7e60230f
	v_cvt_f32_ubyte2_e32 v56, v15                               ; 7e70270f
	v_cvt_f32_ubyte3_e32 v15, v15                               ; 7e1e290f
	v_mac_f32_e32 v24, v25, v49                                 ; 2c306319
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_mul_f32_e32 v32, v32, v47                                 ; 0a405f20
	v_mac_f32_e32 v28, v29, v50                                 ; 2c38651d
	v_add_f32_e32 v52, s9, v52                                  ; 02686809
	v_add_f32_e32 v48, s9, v48                                  ; 02606009
	v_add_f32_e32 v56, s9, v56                                  ; 02707009
	v_add_f32_e32 v15, s9, v15                                  ; 021e1e09
	v_mac_f32_e32 v24, v26, v53                                 ; 2c306b1a
	v_mac_f32_e32 v32, v33, v51                                 ; 2c406721
	v_mac_f32_e32 v28, v30, v54                                 ; 2c386d1e
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_mul_f32_e32 v36, v36, v48                                 ; 0a486124
	v_mac_f32_e32 v24, v27, v43                                 ; 2c30571b
	v_mac_f32_e32 v32, v34, v55                                 ; 2c406f22
	v_mac_f32_e32 v28, v31, v44                                 ; 2c38591f
	v_mac_f32_e32 v36, v37, v52                                 ; 2c486925
	v_mac_f32_e32 v32, v35, v21                                 ; 2c402b23
	v_mac_f32_e32 v36, v38, v56                                 ; 2c487126
	v_mac_f32_e32 v36, v39, v15                                 ; 2c481f27
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_mul_f32_e32 v36, v36, v23                                 ; 0a482f24
	v_mac_f32_e32 v36, v32, v22                                 ; 2c482d20
	v_mac_f32_e32 v36, v28, v41                                 ; 2c48531c
	v_mac_f32_e32 v36, v24, v40                                 ; 2c485118
	v_mac_f32_e32 v3, v36, v57                                  ; 2c067324
BB20:
	s_add_u32 s0, s16, 1                                        ; 80008110
	s_mov_b64 exec, vcc                                         ; befe016a
	s_mul_i32 s0, s0, s3                                        ; 92000300
	s_add_u32 s0, s18, s0                                       ; 80000012
	s_cbranch_execz BB26                                        ; bf880019
BB21:
	s_mov_b32 s4, s2                                            ; be840002
	s_movk_i32 s5, 0x8000                                       ; b0058000
	s_load_dwordx4 s[12:15], s[4:5], 0x0                        ; c00a0302 00000000
	v_add_u32_e32 v11, s0, v10                                  ; 68161400
	s_movk_i32 s1, 0xc0                                         ; b00100c0
	v_lshlrev_b32_e32 v12, 1, v11                               ; 24181681
	v_lshl_add_u32 v12, v11, 4, v12                             ; d1fd000c 0431090b
	v_lshl_add_u32 v12, v11, 6, v12                             ; d1fd000c 04310d0b
	v_lshl_add_u32 v11, v11, 7, v12                             ; d1fd000b 04310f0b
	v_add3_u32 v11, v2, s1, v11                                 ; d1ff000b 042c0302
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_load_sbyte v11, v11, s[12:15], 0 offen               ; e0441000 80030b0b
	v_lshlrev_b32_e32 v13, 2, v2                                ; 241a0482
	v_lshl_add_u32 v13, v0, 6, v13                              ; d1fd000d 04350d00
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_cvt_f32_i32_e32 v11, v11                                  ; 7e160b0b
	ds_write_b32 v13, v11                                       ; d81a0000 00000b0d
BB26:
	s_mov_b64 exec, vcc                                         ; befe016a
	s_cbranch_execz BB32                                        ; bf880092
BB27:
	s_mov_b32 s4, s2                                            ; be840002
	s_movk_i32 s5, 0x8000                                       ; b0058000
	s_load_dwordx8 s[24:31], s[4:5], 0x0                        ; c00e0602 00000000
	v_add_u32_e32 v11, s0, v10                                  ; 68161400
	v_add_u32_e32 v15, 32, v6                                   ; 681e0ca0
	s_movk_i32 s0, 0x80                                         ; b0000080
	v_lshlrev_b32_e32 v12, 1, v11                               ; 24181681
	v_lshl_add_u32 v12, v11, 4, v12                             ; d1fd000c 0431090b
	v_lshl_add_u32 v12, v11, 6, v12                             ; d1fd000c 04310d0b
	v_lshl_add_u32 v11, v11, 7, v12                             ; d1fd000b 04310f0b
	v_and_b32_e32 v13, -4, v11                                  ; 261a16c4
	v_add_u32_e32 v16, v11, v15                                 ; 68201f0b
	v_add_u32_e32 v14, v13, v6                                  ; 681c0d0d
	v_add_u32_e32 v15, v13, v15                                 ; 681e1f0d
	v_add3_u32 v13, v7, s0, v13                                 ; d1ff000d 04340107
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_load_dwordx2 v[20:21], v14, s[24:27], 0 offen        ; e0541000 8006140e
	buffer_load_dwordx2 v[14:15], v15, s[24:27], 0 offen        ; e0541000 80060e0f
	buffer_load_dwordx2 v[12:13], v13, s[24:27], 0 offen        ; e0541000 80060c0d
	buffer_load_short_d16 v19, v11, s[24:27], 0 offen offset:208 ; e09010d0 8006130b
	s_mul_i32 s1, s6, s17                                       ; 92011106
	v_add_u32_e32 v22, s1, v4                                   ; 682c0801
	v_lshrrev_b32_e32 v22, 2, v22                               ; 202c2c82
	v_lshlrev_b32_e32 v22, 4, v22                               ; 242c2c84
	buffer_load_dwordx4 v[24:27], v22, s[28:31], 0 offen        ; e05c1000 80071816
	buffer_load_dwordx4 v[28:31], v22, s[28:31], 0 offen offset:128 ; e05c1080 80071c16
	buffer_load_dwordx4 v[32:35], v22, s[28:31], 0 offen offset:256 ; e05c1100 80072016
	buffer_load_dwordx4 v[36:39], v22, s[28:31], 0 offen offset:384 ; e05c1180 80072416
	v_lshlrev_b32_e32 v23, 2, v1                                ; 242e0282
	v_lshl_add_u32 v23, v0, 6, v23                              ; d1fd0017 045d0d00
	ds_read2_b32 v[40:41], v23 offset1:2                        ; d86e0200 28000017
	ds_read2_b32 v[22:23], v23 offset0:4 offset1:6              ; d86e0604 16000017
	v_add_u32_e32 v18, v11, v6                                  ; 68240d0b
	v_add3_u32 v17, v7, s0, v11                                 ; d1ff0011 042c0107
	s_mov_b32 s4, 0xf0f0f0f                                     ; be8400ff 0f0f0f0f
	s_mov_b32 s5, 0x30303030                                    ; be8500ff 30303030
	s_mov_b32 s9, 0xc2000000                                    ; be8900ff c2000000
	s_waitcnt vmcnt(7)                                          ; bf8c3f77
	v_alignbyte_b32 v21, v21, v20, v18                          ; d1cf0015 044a2915
	s_waitcnt vmcnt(6)                                          ; bf8c3f76
	v_alignbyte_b32 v15, v15, v14, v16                          ; d1cf000f 04421d0f
	s_waitcnt vmcnt(5)                                          ; bf8c3f75
	v_alignbyte_b32 v13, v13, v12, v17                          ; d1cf000d 0446190d
	v_and_b32_e32 v42, s4, v15                                  ; 26541e04
	v_lshrrev_b32_e32 v15, 4, v15                               ; 201e1e84
	v_and_b32_e32 v44, 0xc0c0c0c, v13                           ; 26581aff 0c0c0c0c
	v_and_b32_e32 v43, 0x3030303, v13                           ; 26561aff 03030303
	v_lshl_or_b32 v44, v44, 2, v42                              ; d200002c 04a9052c
	v_lshlrev_b32_e32 v43, 4, v43                               ; 24565684
	v_cvt_f32_ubyte0_e32 v46, v44                               ; 7e5c232c
	v_and_or_b32 v43, s4, v21, v43                              ; d201002b 04ae2a04
	v_lshrrev_b32_e32 v21, 4, v21                               ; 202a2a84
	v_cvt_f32_ubyte1_e32 v50, v44                               ; 7e64252c
	v_add_f32_e32 v46, s9, v46                                  ; 025c5c09
	v_cvt_f32_ubyte0_e32 v45, v43                               ; 7e5a232b
	v_cvt_f32_ubyte1_e32 v49, v43                               ; 7e62252b
	v_and_b32_e32 v21, s4, v21                                  ; 262a2a04
	v_add_f32_e32 v50, s9, v50                                  ; 02646409
	v_add_f32_e32 v45, s9, v45                                  ; 025a5a09
	v_cvt_f32_ubyte2_e32 v53, v43                               ; 7e6a272b
	v_add_f32_e32 v49, s9, v49                                  ; 02626209
	v_and_or_b32 v21, s5, v13, v21                              ; d2010015 04561a05
	v_and_b32_e32 v13, 0xc0c0c0c0, v13                          ; 261a1aff c0c0c0c0
	v_cvt_f32_ubyte2_e32 v54, v44                               ; 7e6c272c
	v_add_f32_e32 v53, s9, v53                                  ; 026a6a09
	v_cvt_f32_ubyte1_e32 v51, v21                               ; 7e662515
	v_cvt_f32_ubyte0_e32 v47, v21                               ; 7e5e2315
	v_cvt_f32_ubyte2_e32 v55, v21                               ; 7e6e2715
	v_lshrrev_b32_e32 v13, 2, v13                               ; 201a1a82
	v_add_f32_e32 v54, s9, v54                                  ; 026c6c09
	v_cvt_f32_ubyte3_e32 v43, v43                               ; 7e56292b
	v_add_f32_e32 v51, s9, v51                                  ; 02666609
	v_cvt_f32_ubyte3_e32 v44, v44                               ; 7e58292c
	v_add_f32_e32 v47, s9, v47                                  ; 025e5e09
	v_add_f32_e32 v55, s9, v55                                  ; 026e6e09
	v_cvt_f32_ubyte3_e32 v21, v21                               ; 7e2a2915
	v_and_or_b32 v15, s4, v15, v13                              ; d201000f 04361e04
	v_add_f32_e32 v43, s9, v43                                  ; 02565609
	s_waitcnt vmcnt(4)                                          ; bf8c3f74
	v_cvt_f32_f16_e32 v57, v19                                  ; 7e721713
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_mul_f32_e32 v24, v24, v45                                 ; 0a305b18
	v_add_f32_e32 v44, s9, v44                                  ; 02585809
	v_add_f32_e32 v21, s9, v21                                  ; 022a2a09
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_mul_f32_e32 v28, v28, v46                                 ; 0a385d1c
	v_cvt_f32_ubyte1_e32 v52, v15                               ; 7e68250f
	v_cvt_f32_ubyte0_e32 v48, v15                               ; 7e60230f
	v_cvt_f32_ubyte2_e32 v56, v15                               ; 7e70270f
	v_cvt_f32_ubyte3_e32 v15, v15                               ; 7e1e290f
	v_mac_f32_e32 v24, v25, v49                                 ; 2c306319
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_mul_f32_e32 v32, v32, v47                                 ; 0a405f20
	v_mac_f32_e32 v28, v29, v50                                 ; 2c38651d
	v_add_f32_e32 v52, s9, v52                                  ; 02686809
	v_add_f32_e32 v48, s9, v48                                  ; 02606009
	v_add_f32_e32 v56, s9, v56                                  ; 02707009
	v_add_f32_e32 v15, s9, v15                                  ; 021e1e09
	v_mac_f32_e32 v24, v26, v53                                 ; 2c306b1a
	v_mac_f32_e32 v32, v33, v51                                 ; 2c406721
	v_mac_f32_e32 v28, v30, v54                                 ; 2c386d1e
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_mul_f32_e32 v36, v36, v48                                 ; 0a486124
	v_mac_f32_e32 v24, v27, v43                                 ; 2c30571b
	v_mac_f32_e32 v32, v34, v55                                 ; 2c406f22
	v_mac_f32_e32 v28, v31, v44                                 ; 2c38591f
	v_mac_f32_e32 v36, v37, v52                                 ; 2c486925
	v_mac_f32_e32 v32, v35, v21                                 ; 2c402b23
	v_mac_f32_e32 v36, v38, v56                                 ; 2c487126
	v_mac_f32_e32 v36, v39, v15                                 ; 2c481f27
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_mul_f32_e32 v36, v36, v23                                 ; 0a482f24
	v_mac_f32_e32 v36, v32, v22                                 ; 2c482d20
	v_mac_f32_e32 v36, v28, v41                                 ; 2c48531c
	v_mac_f32_e32 v36, v24, v40                                 ; 2c485118
	v_mac_f32_e32 v5, v36, v57                                  ; 2c0a7324
BB32:
	s_add_u32 s0, s16, 2                                        ; 80008210
	s_mov_b64 exec, vcc                                         ; befe016a
	s_mul_i32 s0, s0, s3                                        ; 92000300
	s_add_u32 s0, s18, s0                                       ; 80000012
	s_cbranch_execz BB38                                        ; bf880019
BB33:
	s_mov_b32 s4, s2                                            ; be840002
	s_movk_i32 s5, 0x8000                                       ; b0058000
	s_load_dwordx4 s[12:15], s[4:5], 0x0                        ; c00a0302 00000000
	v_add_u32_e32 v11, s0, v10                                  ; 68161400
	s_movk_i32 s1, 0xc0                                         ; b00100c0
	v_lshlrev_b32_e32 v12, 1, v11                               ; 24181681
	v_lshl_add_u32 v12, v11, 4, v12                             ; d1fd000c 0431090b
	v_lshl_add_u32 v12, v11, 6, v12                             ; d1fd000c 04310d0b
	v_lshl_add_u32 v11, v11, 7, v12                             ; d1fd000b 04310f0b
	v_add3_u32 v11, v2, s1, v11                                 ; d1ff000b 042c0302
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_load_sbyte v11, v11, s[12:15], 0 offen               ; e0441000 80030b0b
	v_lshlrev_b32_e32 v13, 2, v2                                ; 241a0482
	v_lshl_add_u32 v13, v0, 6, v13                              ; d1fd000d 04350d00
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_cvt_f32_i32_e32 v11, v11                                  ; 7e160b0b
	ds_write_b32 v13, v11 offset:256                            ; d81a0100 00000b0d
BB38:
	s_mov_b64 exec, vcc                                         ; befe016a
	s_cbranch_execz BB44                                        ; bf880092
BB39:
	s_mov_b32 s4, s2                                            ; be840002
	s_movk_i32 s5, 0x8000                                       ; b0058000
	s_load_dwordx8 s[24:31], s[4:5], 0x0                        ; c00e0602 00000000
	v_add_u32_e32 v11, s0, v10                                  ; 68161400
	v_add_u32_e32 v15, 32, v6                                   ; 681e0ca0
	s_movk_i32 s0, 0x80                                         ; b0000080
	v_lshlrev_b32_e32 v12, 1, v11                               ; 24181681
	v_lshl_add_u32 v12, v11, 4, v12                             ; d1fd000c 0431090b
	v_lshl_add_u32 v12, v11, 6, v12                             ; d1fd000c 04310d0b
	v_lshl_add_u32 v11, v11, 7, v12                             ; d1fd000b 04310f0b
	v_and_b32_e32 v13, -4, v11                                  ; 261a16c4
	v_add_u32_e32 v16, v11, v15                                 ; 68201f0b
	v_add_u32_e32 v14, v13, v6                                  ; 681c0d0d
	v_add_u32_e32 v15, v13, v15                                 ; 681e1f0d
	v_add3_u32 v13, v7, s0, v13                                 ; d1ff000d 04340107
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_load_dwordx2 v[20:21], v14, s[24:27], 0 offen        ; e0541000 8006140e
	buffer_load_dwordx2 v[14:15], v15, s[24:27], 0 offen        ; e0541000 80060e0f
	buffer_load_dwordx2 v[12:13], v13, s[24:27], 0 offen        ; e0541000 80060c0d
	buffer_load_short_d16 v19, v11, s[24:27], 0 offen offset:208 ; e09010d0 8006130b
	s_mul_i32 s1, s6, s17                                       ; 92011106
	v_add_u32_e32 v22, s1, v4                                   ; 682c0801
	v_lshrrev_b32_e32 v22, 2, v22                               ; 202c2c82
	v_lshlrev_b32_e32 v22, 4, v22                               ; 242c2c84
	buffer_load_dwordx4 v[24:27], v22, s[28:31], 0 offen        ; e05c1000 80071816
	buffer_load_dwordx4 v[28:31], v22, s[28:31], 0 offen offset:128 ; e05c1080 80071c16
	buffer_load_dwordx4 v[32:35], v22, s[28:31], 0 offen offset:256 ; e05c1100 80072016
	buffer_load_dwordx4 v[36:39], v22, s[28:31], 0 offen offset:384 ; e05c1180 80072416
	v_lshlrev_b32_e32 v23, 2, v1                                ; 242e0282
	v_lshl_add_u32 v23, v0, 6, v23                              ; d1fd0017 045d0d00
	ds_read2_b32 v[40:41], v23 offset0:64 offset1:66            ; d86e4240 28000017
	ds_read2_b32 v[22:23], v23 offset0:68 offset1:70            ; d86e4644 16000017
	v_add_u32_e32 v18, v11, v6                                  ; 68240d0b
	v_add3_u32 v17, v7, s0, v11                                 ; d1ff0011 042c0107
	s_mov_b32 s4, 0xf0f0f0f                                     ; be8400ff 0f0f0f0f
	s_mov_b32 s5, 0x30303030                                    ; be8500ff 30303030
	s_mov_b32 s9, 0xc2000000                                    ; be8900ff c2000000
	s_waitcnt vmcnt(7)                                          ; bf8c3f77
	v_alignbyte_b32 v21, v21, v20, v18                          ; d1cf0015 044a2915
	s_waitcnt vmcnt(6)                                          ; bf8c3f76
	v_alignbyte_b32 v15, v15, v14, v16                          ; d1cf000f 04421d0f
	s_waitcnt vmcnt(5)                                          ; bf8c3f75
	v_alignbyte_b32 v13, v13, v12, v17                          ; d1cf000d 0446190d
	v_and_b32_e32 v42, s4, v15                                  ; 26541e04
	v_lshrrev_b32_e32 v15, 4, v15                               ; 201e1e84
	v_and_b32_e32 v44, 0xc0c0c0c, v13                           ; 26581aff 0c0c0c0c
	v_and_b32_e32 v43, 0x3030303, v13                           ; 26561aff 03030303
	v_lshl_or_b32 v44, v44, 2, v42                              ; d200002c 04a9052c
	v_lshlrev_b32_e32 v43, 4, v43                               ; 24565684
	v_cvt_f32_ubyte0_e32 v46, v44                               ; 7e5c232c
	v_and_or_b32 v43, s4, v21, v43                              ; d201002b 04ae2a04
	v_lshrrev_b32_e32 v21, 4, v21                               ; 202a2a84
	v_cvt_f32_ubyte1_e32 v50, v44                               ; 7e64252c
	v_add_f32_e32 v46, s9, v46                                  ; 025c5c09
	v_cvt_f32_ubyte0_e32 v45, v43                               ; 7e5a232b
	v_cvt_f32_ubyte1_e32 v49, v43                               ; 7e62252b
	v_and_b32_e32 v21, s4, v21                                  ; 262a2a04
	v_add_f32_e32 v50, s9, v50                                  ; 02646409
	v_add_f32_e32 v45, s9, v45                                  ; 025a5a09
	v_cvt_f32_ubyte2_e32 v53, v43                               ; 7e6a272b
	v_add_f32_e32 v49, s9, v49                                  ; 02626209
	v_and_or_b32 v21, s5, v13, v21                              ; d2010015 04561a05
	v_and_b32_e32 v13, 0xc0c0c0c0, v13                          ; 261a1aff c0c0c0c0
	v_cvt_f32_ubyte2_e32 v54, v44                               ; 7e6c272c
	v_add_f32_e32 v53, s9, v53                                  ; 026a6a09
	v_cvt_f32_ubyte1_e32 v51, v21                               ; 7e662515
	v_cvt_f32_ubyte0_e32 v47, v21                               ; 7e5e2315
	v_cvt_f32_ubyte2_e32 v55, v21                               ; 7e6e2715
	v_lshrrev_b32_e32 v13, 2, v13                               ; 201a1a82
	v_add_f32_e32 v54, s9, v54                                  ; 026c6c09
	v_cvt_f32_ubyte3_e32 v43, v43                               ; 7e56292b
	v_add_f32_e32 v51, s9, v51                                  ; 02666609
	v_cvt_f32_ubyte3_e32 v44, v44                               ; 7e58292c
	v_add_f32_e32 v47, s9, v47                                  ; 025e5e09
	v_add_f32_e32 v55, s9, v55                                  ; 026e6e09
	v_cvt_f32_ubyte3_e32 v21, v21                               ; 7e2a2915
	v_and_or_b32 v15, s4, v15, v13                              ; d201000f 04361e04
	v_add_f32_e32 v43, s9, v43                                  ; 02565609
	s_waitcnt vmcnt(4)                                          ; bf8c3f74
	v_cvt_f32_f16_e32 v57, v19                                  ; 7e721713
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_mul_f32_e32 v24, v24, v45                                 ; 0a305b18
	v_add_f32_e32 v44, s9, v44                                  ; 02585809
	v_add_f32_e32 v21, s9, v21                                  ; 022a2a09
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_mul_f32_e32 v28, v28, v46                                 ; 0a385d1c
	v_cvt_f32_ubyte1_e32 v52, v15                               ; 7e68250f
	v_cvt_f32_ubyte0_e32 v48, v15                               ; 7e60230f
	v_cvt_f32_ubyte2_e32 v56, v15                               ; 7e70270f
	v_cvt_f32_ubyte3_e32 v15, v15                               ; 7e1e290f
	v_mac_f32_e32 v24, v25, v49                                 ; 2c306319
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_mul_f32_e32 v32, v32, v47                                 ; 0a405f20
	v_mac_f32_e32 v28, v29, v50                                 ; 2c38651d
	v_add_f32_e32 v52, s9, v52                                  ; 02686809
	v_add_f32_e32 v48, s9, v48                                  ; 02606009
	v_add_f32_e32 v56, s9, v56                                  ; 02707009
	v_add_f32_e32 v15, s9, v15                                  ; 021e1e09
	v_mac_f32_e32 v24, v26, v53                                 ; 2c306b1a
	v_mac_f32_e32 v32, v33, v51                                 ; 2c406721
	v_mac_f32_e32 v28, v30, v54                                 ; 2c386d1e
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_mul_f32_e32 v36, v36, v48                                 ; 0a486124
	v_mac_f32_e32 v24, v27, v43                                 ; 2c30571b
	v_mac_f32_e32 v32, v34, v55                                 ; 2c406f22
	v_mac_f32_e32 v28, v31, v44                                 ; 2c38591f
	v_mac_f32_e32 v36, v37, v52                                 ; 2c486925
	v_mac_f32_e32 v32, v35, v21                                 ; 2c402b23
	v_mac_f32_e32 v36, v38, v56                                 ; 2c487126
	v_mac_f32_e32 v36, v39, v15                                 ; 2c481f27
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_mul_f32_e32 v36, v36, v23                                 ; 0a482f24
	v_mac_f32_e32 v36, v32, v22                                 ; 2c482d20
	v_mac_f32_e32 v36, v28, v41                                 ; 2c48531c
	v_mac_f32_e32 v36, v24, v40                                 ; 2c485118
	v_mac_f32_e32 v8, v36, v57                                  ; 2c107324
BB44:
	s_add_u32 s0, s16, 3                                        ; 80008310
	s_mov_b64 exec, vcc                                         ; befe016a
	s_mul_i32 s0, s0, s3                                        ; 92000300
	s_add_u32 s18, s18, s0                                      ; 80120012
	s_cbranch_execz BB50                                        ; bf880019
BB45:
	s_mov_b32 s0, s2                                            ; be800002
	s_movk_i32 s1, 0x8000                                       ; b0018000
	s_load_dwordx4 s[12:15], s[0:1], 0x0                        ; c00a0300 00000000
	v_add_u32_e32 v11, s18, v10                                 ; 68161412
	s_movk_i32 s0, 0xc0                                         ; b00000c0
	v_lshlrev_b32_e32 v12, 1, v11                               ; 24181681
	v_lshl_add_u32 v12, v11, 4, v12                             ; d1fd000c 0431090b
	v_lshl_add_u32 v12, v11, 6, v12                             ; d1fd000c 04310d0b
	v_lshl_add_u32 v11, v11, 7, v12                             ; d1fd000b 04310f0b
	v_add3_u32 v11, v2, s0, v11                                 ; d1ff000b 042c0102
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_load_sbyte v11, v11, s[12:15], 0 offen               ; e0441000 80030b0b
	v_lshlrev_b32_e32 v2, 2, v2                                 ; 24040482
	v_lshl_add_u32 v2, v0, 6, v2                                ; d1fd0002 04090d00
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_cvt_f32_i32_e32 v11, v11                                  ; 7e160b0b
	ds_write_b32 v2, v11                                        ; d81a0000 00000b02
BB50:
	s_mov_b64 exec, vcc                                         ; befe016a
	s_cbranch_execz BB56                                        ; bf880092
BB51:
	s_mov_b32 s0, s2                                            ; be800002
	s_movk_i32 s1, 0x8000                                       ; b0018000
	s_load_dwordx8 s[24:31], s[0:1], 0x0                        ; c00e0600 00000000
	v_add_u32_e32 v10, s18, v10                                 ; 68141412
	s_movk_i32 s0, 0x80                                         ; b0000080
	v_lshlrev_b32_e32 v2, 1, v10                                ; 24041481
	v_lshl_add_u32 v2, v10, 4, v2                               ; d1fd0002 0409090a
	v_lshl_add_u32 v2, v10, 6, v2                               ; d1fd0002 04090d0a
	v_lshl_add_u32 v10, v10, 7, v2                              ; d1fd000a 04090f0a
	v_and_b32_e32 v11, -4, v10                                  ; 261614c4
	v_add_u32_e32 v13, v10, v6                                  ; 681a0d0a
	v_add3_u32 v15, v7, s0, v10                                 ; d1ff000f 04280107
	v_add3_u32 v7, v7, s0, v11                                  ; d1ff0007 042c0107
	v_add_u32_e32 v12, v11, v6                                  ; 68180d0b
	v_add_u32_e32 v6, 32, v6                                    ; 680c0ca0
	v_add_u32_e32 v14, v10, v6                                  ; 681c0d0a
	v_add_u32_e32 v6, v11, v6                                   ; 680c0d0b
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_load_dwordx2 v[16:17], v12, s[24:27], 0 offen        ; e0541000 8006100c
	buffer_load_dwordx2 v[18:19], v6, s[24:27], 0 offen         ; e0541000 80061206
	buffer_load_dwordx2 v[6:7], v7, s[24:27], 0 offen           ; e0541000 80060607
	buffer_load_short_d16 v20, v10, s[24:27], 0 offen offset:208 ; e09010d0 8006140a
	s_mul_i32 s6, s6, s17                                       ; 92061106
	v_add_u32_e32 v4, s6, v4                                    ; 68080806
	v_lshrrev_b32_e32 v4, 2, v4                                 ; 20080882
	v_lshlrev_b32_e32 v4, 4, v4                                 ; 24080884
	buffer_load_dwordx4 v[24:27], v4, s[28:31], 0 offen         ; e05c1000 80071804
	buffer_load_dwordx4 v[28:31], v4, s[28:31], 0 offen offset:128 ; e05c1080 80071c04
	buffer_load_dwordx4 v[32:35], v4, s[28:31], 0 offen offset:256 ; e05c1100 80072004
	buffer_load_dwordx4 v[36:39], v4, s[28:31], 0 offen offset:384 ; e05c1180 80072404
	v_lshlrev_b32_e32 v1, 2, v1                                 ; 24020282
	v_lshl_add_u32 v0, v0, 6, v1                                ; d1fd0000 04050d00
	ds_read2_b32 v[10:11], v0 offset1:2                         ; d86e0200 0a000000
	ds_read2_b32 v[0:1], v0 offset0:4 offset1:6                 ; d86e0604 00000000
	s_mov_b32 s1, 0xf0f0f0f                                     ; be8100ff 0f0f0f0f
	s_mov_b32 s3, 0x30303030                                    ; be8300ff 30303030
	s_mov_b32 s4, 0xc2000000                                    ; be8400ff c2000000
	s_waitcnt vmcnt(7)                                          ; bf8c3f77
	v_alignbyte_b32 v17, v17, v16, v13                          ; d1cf0011 04362111
	s_waitcnt vmcnt(6)                                          ; bf8c3f76
	v_alignbyte_b32 v19, v19, v18, v14                          ; d1cf0013 043a2513
	s_waitcnt vmcnt(5)                                          ; bf8c3f75
	v_alignbyte_b32 v7, v7, v6, v15                             ; d1cf0007 043e0d07
	v_and_b32_e32 v21, s1, v19                                  ; 262a2601
	v_lshrrev_b32_e32 v19, 4, v19                               ; 20262684
	v_and_b32_e32 v23, 0xc0c0c0c, v7                            ; 262e0eff 0c0c0c0c
	v_and_b32_e32 v22, 0x3030303, v7                            ; 262c0eff 03030303
	v_lshl_or_b32 v23, v23, 2, v21                              ; d2000017 04550517
	v_lshlrev_b32_e32 v22, 4, v22                               ; 242c2c84
	v_cvt_f32_ubyte0_e32 v41, v23                               ; 7e522317
	v_and_or_b32 v22, s1, v17, v22                              ; d2010016 045a2201
	v_lshrrev_b32_e32 v17, 4, v17                               ; 20222284
	v_add_f32_e32 v41, s4, v41                                  ; 02525204
	v_cvt_f32_ubyte1_e32 v45, v23                               ; 7e5a2517
	v_cvt_f32_ubyte1_e32 v44, v22                               ; 7e582516
	v_cvt_f32_ubyte0_e32 v40, v22                               ; 7e502316
	v_and_b32_e32 v17, s1, v17                                  ; 26222201
	v_add_f32_e32 v45, s4, v45                                  ; 025a5a04
	v_add_f32_e32 v44, s4, v44                                  ; 02585804
	v_cvt_f32_ubyte2_e32 v48, v22                               ; 7e602716
	v_add_f32_e32 v40, s4, v40                                  ; 02505004
	v_and_or_b32 v17, s3, v7, v17                               ; d2010011 04460e03
	v_and_b32_e32 v7, 0xc0c0c0c0, v7                            ; 260e0eff c0c0c0c0
	v_cvt_f32_ubyte2_e32 v49, v23                               ; 7e622717
	v_add_f32_e32 v48, s4, v48                                  ; 02606004
	v_cvt_f32_ubyte2_e32 v50, v17                               ; 7e642711
	v_cvt_f32_ubyte1_e32 v46, v17                               ; 7e5c2511
	v_cvt_f32_ubyte0_e32 v42, v17                               ; 7e542311
	v_lshrrev_b32_e32 v7, 2, v7                                 ; 200e0e82
	v_cvt_f32_ubyte3_e32 v22, v22                               ; 7e2c2916
	v_add_f32_e32 v49, s4, v49                                  ; 02626204
	v_add_f32_e32 v50, s4, v50                                  ; 02646404
	v_cvt_f32_ubyte3_e32 v23, v23                               ; 7e2e2917
	v_add_f32_e32 v46, s4, v46                                  ; 025c5c04
	v_add_f32_e32 v42, s4, v42                                  ; 02545404
	v_cvt_f32_ubyte3_e32 v17, v17                               ; 7e222911
	v_and_or_b32 v19, s1, v19, v7                               ; d2010013 041e2601
	v_add_f32_e32 v22, s4, v22                                  ; 022c2c04
	s_waitcnt vmcnt(4)                                          ; bf8c3f74
	v_cvt_f32_f16_e32 v52, v20                                  ; 7e681714
	v_add_f32_e32 v23, s4, v23                                  ; 022e2e04
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_mul_f32_e32 v24, v24, v40                                 ; 0a305118
	v_add_f32_e32 v17, s4, v17                                  ; 02222204
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_mul_f32_e32 v28, v28, v41                                 ; 0a38531c
	v_cvt_f32_ubyte0_e32 v43, v19                               ; 7e562313
	v_cvt_f32_ubyte2_e32 v51, v19                               ; 7e662713
	v_cvt_f32_ubyte1_e32 v47, v19                               ; 7e5e2513
	v_cvt_f32_ubyte3_e32 v19, v19                               ; 7e262913
	v_mac_f32_e32 v24, v25, v44                                 ; 2c305919
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_mul_f32_e32 v32, v32, v42                                 ; 0a405520
	v_mac_f32_e32 v28, v29, v45                                 ; 2c385b1d
	v_add_f32_e32 v43, s4, v43                                  ; 02565604
	v_add_f32_e32 v51, s4, v51                                  ; 02666604
	v_add_f32_e32 v47, s4, v47                                  ; 025e5e04
	v_add_f32_e32 v19, s4, v19                                  ; 02262604
	v_mac_f32_e32 v24, v26, v48                                 ; 2c30611a
	v_mac_f32_e32 v32, v33, v46                                 ; 2c405d21
	v_mac_f32_e32 v28, v30, v49                                 ; 2c38631e
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_mul_f32_e32 v36, v36, v43                                 ; 0a485724
	v_mac_f32_e32 v24, v27, v22                                 ; 2c302d1b
	v_mac_f32_e32 v32, v34, v50                                 ; 2c406522
	v_mac_f32_e32 v28, v31, v23                                 ; 2c382f1f
	v_mac_f32_e32 v36, v37, v47                                 ; 2c485f25
	v_mac_f32_e32 v32, v35, v17                                 ; 2c402323
	v_mac_f32_e32 v36, v38, v51                                 ; 2c486726
	v_mac_f32_e32 v36, v39, v19                                 ; 2c482727
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_mul_f32_e32 v36, v36, v1                                  ; 0a480324
	v_mac_f32_e32 v36, v32, v0                                  ; 2c480120
	v_mac_f32_e32 v36, v28, v11                                 ; 2c48171c
	v_mac_f32_e32 v36, v24, v10                                 ; 2c481518
	v_mac_f32_e32 v9, v36, v52                                  ; 2c126924
BB56:
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
	s_mov_b64 exec, 1                                           ; befe0181
	v_readlane_b32 s4, v63, 63                                  ; d2890004 00017f3f
BB57:
	s_bitcmp1_b32 s8, 0                                         ; bf0d8008
	s_cbranch_scc0 BB59                                         ; bf84000f
BB58:
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
	s_branch BB60                                               ; bf820002
BB59:
	s_mov_b32 s6, src_scc                                       ; be8600fd
	v_mov_b32_e32 v0, s0                                        ; 7e000200
BB60:
	s_bitcmp1_b32 s8, 1                                         ; bf0d8108
	s_cbranch_scc0 BB62                                         ; bf84000e
BB61:
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
	s_branch BB63                                               ; bf820001
BB62:
	s_mov_b32 s5, src_scc                                       ; be8500fd
BB63:
	s_mov_b32 s0, s3                                            ; be800003
	s_movk_i32 s3, 0x8000                                       ; b0038000
	s_load_dwordx4 s[8:11], s[2:3], 0x20                        ; c00a0201 00000020
	s_mul_i32 s7, s7, s17                                       ; 92071107
	s_add_u32 s7, s7, s16                                       ; 80071007
	s_lshl_b32 s7, s7, 2                                        ; 8e078207
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_store_dword v0, off, s[8:11], s7                     ; e0700000 07020080
	s_cmp_lg_i32 s6, 0                                          ; bf018006
	s_cbranch_scc0 BB65                                         ; bf84000b
BB64:
	s_load_dwordx4 s[12:15], s[2:3], 0x30                       ; c00a0301 00000030
	s_mov_b32 s6, src_scc                                       ; be8600fd
	s_add_u32 s16, s7, 4                                        ; 80108407
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s16, s[12:15], s16                      ; c0200406 00000010
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_mov_b32_e32 v0, s16                                       ; 7e000210
	v_add_f32_e32 v0, s1, v0                                    ; 02000001
	s_branch BB66                                               ; bf820002
BB65:
	s_mov_b32 s6, src_scc                                       ; be8600fd
	v_mov_b32_e32 v0, s1                                        ; 7e000201
BB66:
	s_cmp_lg_i32 s5, 0                                          ; bf018005
	s_cbranch_scc0 BB68                                         ; bf84000a
BB67:
	s_load_dwordx4 s[12:15], s[2:3], 0x40                       ; c00a0301 00000040
	s_mov_b32 s1, src_scc                                       ; be8100fd
	s_add_u32 s5, s7, 4                                         ; 80058407
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s5, s[12:15], s5                        ; c0200146 00000005
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v0, s5, v0                                    ; 02000005
	s_branch BB69                                               ; bf820001
BB68:
	s_mov_b32 s1, src_scc                                       ; be8100fd
BB69:
	s_add_u32 s5, s7, 4                                         ; 80058407
	buffer_store_dword v0, off, s[8:11], s5                     ; e0700000 05020080
	s_cmp_lg_i32 s6, 0                                          ; bf018006
	s_cbranch_scc0 BB71                                         ; bf84000b
BB70:
	s_load_dwordx4 s[12:15], s[2:3], 0x30                       ; c00a0301 00000030
	s_mov_b32 s5, src_scc                                       ; be8500fd
	s_add_u32 s6, s7, 8                                         ; 80068807
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s6, s[12:15], s6                        ; c0200186 00000006
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_mov_b32_e32 v0, s6                                        ; 7e000206
	v_add_f32_e32 v0, s0, v0                                    ; 02000000
	s_branch BB72                                               ; bf820002
BB71:
	s_mov_b32 s5, src_scc                                       ; be8500fd
	v_mov_b32_e32 v0, s0                                        ; 7e000200
BB72:
	s_cmp_lg_i32 s1, 0                                          ; bf018001
	s_cbranch_scc0 BB74                                         ; bf84000a
BB73:
	s_load_dwordx4 s[12:15], s[2:3], 0x40                       ; c00a0301 00000040
	s_mov_b32 s0, src_scc                                       ; be8000fd
	s_add_u32 s1, s7, 8                                         ; 80018807
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s1, s[12:15], s1                        ; c0200046 00000001
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v0, s1, v0                                    ; 02000001
	s_branch BB75                                               ; bf820001
BB74:
	s_mov_b32 s0, src_scc                                       ; be8000fd
BB75:
	s_add_u32 s1, s7, 8                                         ; 80018807
	buffer_store_dword v0, off, s[8:11], s1                     ; e0700000 01020080
	s_cmp_lg_i32 s5, 0                                          ; bf018005
	s_cbranch_scc0 BB77                                         ; bf84000a
BB76:
	s_load_dwordx4 s[12:15], s[2:3], 0x30                       ; c00a0301 00000030
	s_add_u32 s1, s7, 12                                        ; 80018c07
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s1, s[12:15], s1                        ; c0200046 00000001
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_mov_b32_e32 v0, s1                                        ; 7e000201
	v_add_f32_e32 v0, s4, v0                                    ; 02000004
	s_branch BB78                                               ; bf820001
BB77:
	v_mov_b32_e32 v0, s4                                        ; 7e000204
BB78:
	s_cmp_lg_i32 s0, 0                                          ; bf018000
	s_cbranch_scc0 BB81                                         ; bf840008
BB79:
	s_load_dwordx4 s[0:3], s[2:3], 0x40                         ; c00a0001 00000040
	s_add_u32 s4, s7, 12                                        ; 80048c07
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s4, s[0:3], s4                          ; c0200100 00000004
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v0, s4, v0                                    ; 02000004
BB81:
	s_add_u32 s7, s7, 12                                        ; 80078c07
	buffer_store_dword v0, off, s[8:11], s7                     ; e0700000 07020080
	s_branch BB232                                              ; bf8206e9
BB87:
	s_cmp_lt_u32 s16, s4                                        ; bf0a0410
	s_cbranch_scc0 BB232                                        ; bf8406e7
BB88:
	s_sub_i32 s4, s4, s16                                       ; 81841004
	s_add_u32 s17, s17, s9                                      ; 80110911
	s_cmp_lg_i32 s17, 0                                         ; bf018011
	s_cbranch_scc0 BB90                                         ; bf840043
BB89:
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
	s_branch BB91                                               ; bf820001
BB90:
	s_mov_b32 s19, 0                                            ; be930080
BB91:
	s_lshr_b32 s5, s5, 8                                        ; 8f058805
	v_and_b32_e32 v1, 8, v0                                     ; 26020088
	v_and_b32_e32 v2, 15, v0                                    ; 2604008f
	s_lshr_b32 s3, s3, 8                                        ; 8f038803
	v_lshrrev_b32_e32 v0, 4, v0                                 ; 20000084
	s_mov_b32 s1, 0                                             ; be810080
	s_mul_i32 s19, s19, s5                                      ; 92130513
	s_mov_b64 vcc, 0                                            ; beea0180
	v_sub_u32_e32 v3, v2, v1                                    ; 6a060302
	v_lshrrev_b32_e32 v4, 3, v2                                 ; 20080483
	s_and_b32 s0, s3, 3                                         ; 86008303
	v_mov_b32_e32 v8, 0                                         ; 7e100280
	v_mov_b32_e32 v9, 0                                         ; 7e120280
	v_lshlrev_b32_e32 v5, 2, v3                                 ; 240a0682
	v_lshrrev_b32_e32 v3, 2, v3                                 ; 20060682
	s_sub_i32 s0, s3, s0                                        ; 81800003
	v_lshl_add_u32 v6, v4, 6, v5                                ; d1fd0006 04150d04
	v_lshl_add_u32 v7, v4, 5, v5                                ; d1fd0007 04150b04
	v_lshl_add_u32 v4, v4, 7, v5                                ; d1fd0004 04150f04
	v_mov_b32_e32 v5, 0                                         ; 7e0a0280
	v_add_u32_e32 v1, v1, v3                                    ; 68020701
	v_mov_b32_e32 v3, 0                                         ; 7e060280
BB92:
	s_cmp_ge_u32 s1, s0                                         ; bf090001
	s_cbranch_scc1 BB111                                        ; bf85026e
BB94:
	v_add_u32_e32 v10, s1, v0                                   ; 68140001
	s_cmp_lg_i32 s4, 0                                          ; bf018004
	v_lshl_add_u32 v11, v10, 8, v4                              ; d1fd000b 0411110a
	s_cbranch_scc0 BB110                                        ; bf840267
BB95:
	s_mov_b32 s10, s2                                           ; be8a0002
	s_movk_i32 s11, 0x8000                                      ; b00b8000
	s_load_dwordx8 s[24:31], s[10:11], 0x0                      ; c00e0605 00000000
	s_mul_i32 s5, s16, s3                                       ; 92050310
	v_add_u32_e32 v16, 32, v6                                   ; 68200ca0
	s_movk_i32 s9, 0x80                                         ; b0090080
	s_movk_i32 s10, 0xc0                                        ; b00a00c0
	s_add_u32 s5, s19, s5                                       ; 80050513
	v_add_u32_e32 v12, s5, v10                                  ; 68181405
	v_lshlrev_b32_e32 v13, 1, v12                               ; 241a1881
	v_lshl_add_u32 v13, v12, 4, v13                             ; d1fd000d 0435090c
	v_lshl_add_u32 v13, v12, 6, v13                             ; d1fd000d 04350d0c
	v_lshl_add_u32 v12, v12, 7, v13                             ; d1fd000c 04350f0c
	v_add3_u32 v19, v2, s10, v12                                ; d1ff0013 04301502
	v_and_b32_e32 v14, -4, v12                                  ; 261c18c4
	v_add_u32_e32 v15, v14, v6                                  ; 681e0d0e
	v_add_u32_e32 v17, v14, v16                                 ; 6822210e
	v_add3_u32 v14, v7, s9, v14                                 ; d1ff000e 04381307
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_load_dwordx2 v[22:23], v15, s[24:27], 0 offen        ; e0541000 8006160f
	buffer_load_dwordx2 v[24:25], v17, s[24:27], 0 offen        ; e0541000 80061811
	buffer_load_dwordx2 v[14:15], v14, s[24:27], 0 offen        ; e0541000 80060e0e
	buffer_load_sbyte v19, v19, s[24:27], 0 offen               ; e0441000 80061313
	buffer_load_short_d16 v26, v12, s[24:27], 0 offen offset:208 ; e09010d0 80061a0c
	s_mul_i32 s11, s6, s17                                      ; 920b1106
	v_add_u32_e32 v11, s11, v11                                 ; 6816160b
	v_lshrrev_b32_e32 v11, 2, v11                               ; 20161682
	v_lshlrev_b32_e32 v11, 4, v11                               ; 24161684
	buffer_load_dwordx4 v[28:31], v11, s[28:31], 0 offen        ; e05c1000 80071c0b
	buffer_load_dwordx4 v[32:35], v11, s[28:31], 0 offen offset:128 ; e05c1080 8007200b
	buffer_load_dwordx4 v[36:39], v11, s[28:31], 0 offen offset:256 ; e05c1100 8007240b
	buffer_load_dwordx4 v[40:43], v11, s[28:31], 0 offen offset:384 ; e05c1180 8007280b
	v_add_u32_e32 v20, v12, v6                                  ; 68280d0c
	v_add_u32_e32 v21, v12, v16                                 ; 682a210c
	v_add3_u32 v18, v7, s9, v12                                 ; d1ff0012 04301307
	s_mov_b32 s12, 0xf0f0f0f                                    ; be8c00ff 0f0f0f0f
	s_mov_b32 s13, 0x30303030                                   ; be8d00ff 30303030
	v_lshlrev_b32_e32 v27, 6, v0                                ; 24360086
	s_and_b64 s[10:11], vcc, exec                               ; 868a7e6a
	v_lshlrev_b32_e32 v44, 2, v2                                ; 24580482
	s_mov_b32 s15, 0xc2000000                                   ; be8f00ff c2000000
	v_lshlrev_b32_e32 v46, 2, v1                                ; 245c0282
	s_cselect_b32 s14, 0, 0x100                                 ; 850eff80 00000100
	s_mov_b32 s18, src_scc                                      ; be9200fd
	s_not_b64 s[10:11], vcc                                     ; be8a056a
	s_cmp_lt_u32 1, s4                                          ; bf0a0481
	v_add3_u32 v45, v44, s14, v27                               ; d1ff002d 046c1d2c
	v_add3_u32 v47, v46, s14, v27                               ; d1ff002f 046c1d2e
	s_waitcnt vmcnt(8)                                          ; bf8c3f78
	v_alignbyte_b32 v23, v23, v22, v20                          ; d1cf0017 04522d17
	s_waitcnt vmcnt(7)                                          ; bf8c3f77
	v_alignbyte_b32 v25, v25, v24, v21                          ; d1cf0019 04563119
	s_waitcnt vmcnt(6)                                          ; bf8c3f76
	v_alignbyte_b32 v15, v15, v14, v18                          ; d1cf000f 044a1d0f
	v_and_b32_e32 v48, s12, v25                                 ; 2660320c
	v_lshrrev_b32_e32 v25, 4, v25                               ; 20323284
	v_and_b32_e32 v49, 0x3030303, v15                           ; 26621eff 03030303
	v_and_b32_e32 v50, 0xc0c0c0c, v15                           ; 26641eff 0c0c0c0c
	v_lshlrev_b32_e32 v49, 4, v49                               ; 24626284
	v_lshl_or_b32 v50, v50, 2, v48                              ; d2000032 04c10532
	v_and_or_b32 v49, s12, v23, v49                             ; d2010031 04c62e0c
	v_lshrrev_b32_e32 v23, 4, v23                               ; 202e2e84
	v_cvt_f32_ubyte0_e32 v52, v50                               ; 7e682332
	v_cvt_f32_ubyte1_e32 v55, v49                               ; 7e6e2531
	v_cvt_f32_ubyte0_e32 v51, v49                               ; 7e662331
	v_cvt_f32_ubyte1_e32 v56, v50                               ; 7e702532
	v_and_b32_e32 v23, s12, v23                                 ; 262e2e0c
	v_add_f32_e32 v52, s15, v52                                 ; 0268680f
	v_add_f32_e32 v55, s15, v55                                 ; 026e6e0f
	v_add_f32_e32 v51, s15, v51                                 ; 0266660f
	v_add_f32_e32 v56, s15, v56                                 ; 0270700f
	v_and_or_b32 v23, s13, v15, v23                             ; d2010017 045e1e0d
	v_and_b32_e32 v15, 0xc0c0c0c0, v15                          ; 261e1eff c0c0c0c0
	v_cvt_f32_ubyte2_e32 v59, v49                               ; 7e762731
	v_cvt_f32_ubyte2_e32 v60, v50                               ; 7e782732
	v_cvt_f32_ubyte1_e32 v57, v23                               ; 7e722517
	v_cvt_f32_ubyte2_e32 v61, v23                               ; 7e7a2717
	v_cvt_f32_ubyte0_e32 v53, v23                               ; 7e6a2317
	v_lshrrev_b32_e32 v15, 2, v15                               ; 201e1e82
	v_add_f32_e32 v59, s15, v59                                 ; 0276760f
	v_add_f32_e32 v60, s15, v60                                 ; 0278780f
	v_cvt_f32_ubyte3_e32 v49, v49                               ; 7e622931
	v_add_f32_e32 v57, s15, v57                                 ; 0272720f
	v_add_f32_e32 v61, s15, v61                                 ; 027a7a0f
	v_cvt_f32_ubyte3_e32 v50, v50                               ; 7e642932
	v_add_f32_e32 v53, s15, v53                                 ; 026a6a0f
	v_cvt_f32_ubyte3_e32 v23, v23                               ; 7e2e2917
	v_and_or_b32 v25, s12, v25, v15                             ; d2010019 043e320c
	v_add_f32_e32 v49, s15, v49                                 ; 0262620f
	s_waitcnt vmcnt(5)                                          ; bf8c3f75
	v_cvt_f32_i32_e32 v19, v19                                  ; 7e260b13
	v_add_f32_e32 v50, s15, v50                                 ; 0264640f
	v_add_f32_e32 v23, s15, v23                                 ; 022e2e0f
	v_cvt_f32_ubyte1_e32 v58, v25                               ; 7e742519
	v_cvt_f32_ubyte0_e32 v54, v25                               ; 7e6c2319
	v_cvt_f32_ubyte2_e32 v62, v25                               ; 7e7c2719
	v_cvt_f32_ubyte3_e32 v25, v25                               ; 7e322919
	v_add_f32_e32 v58, s15, v58                                 ; 0274740f
	v_add_f32_e32 v54, s15, v54                                 ; 026c6c0f
	v_add_f32_e32 v62, s15, v62                                 ; 027c7c0f
	v_add_f32_e32 v25, s15, v25                                 ; 0232320f
	ds_write_b32 v45, v19                                       ; d81a0000 0000132d
	ds_read2_b32 v[12:13], v47 offset1:2                        ; d86e0200 0c00002f
	ds_read2_b32 v[14:15], v47 offset0:4 offset1:6              ; d86e0604 0e00002f
	s_waitcnt vmcnt(4)                                          ; bf8c3f74
	v_cvt_f32_f16_e32 v11, v26                                  ; 7e16171a
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_mul_f32_e32 v51, v28, v51                                 ; 0a66671c
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_mul_f32_e32 v52, v32, v52                                 ; 0a686920
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_mul_f32_e32 v53, v36, v53                                 ; 0a6a6b24
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_mul_f32_e32 v54, v40, v54                                 ; 0a6c6d28
	v_mac_f32_e32 v51, v29, v55                                 ; 2c666f1d
	v_mac_f32_e32 v52, v33, v56                                 ; 2c687121
	v_mac_f32_e32 v53, v37, v57                                 ; 2c6a7325
	v_mac_f32_e32 v54, v41, v58                                 ; 2c6c7529
	v_mac_f32_e32 v51, v30, v59                                 ; 2c66771e
	v_mac_f32_e32 v52, v34, v60                                 ; 2c687922
	v_mac_f32_e32 v53, v38, v61                                 ; 2c6a7b26
	v_mac_f32_e32 v54, v42, v62                                 ; 2c6c7d2a
	v_mac_f32_e32 v51, v31, v49                                 ; 2c66631f
	v_mac_f32_e32 v52, v35, v50                                 ; 2c686523
	v_mac_f32_e32 v53, v39, v23                                 ; 2c6a2f27
	v_mac_f32_e32 v54, v43, v25                                 ; 2c6c332b
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_mul_f32_e32 v54, v54, v15                                 ; 0a6c1f36
	v_mac_f32_e32 v54, v53, v14                                 ; 2c6c1d35
	v_mac_f32_e32 v54, v52, v13                                 ; 2c6c1b34
	v_mac_f32_e32 v54, v51, v12                                 ; 2c6c1933
	v_mac_f32_e32 v3, v54, v11                                  ; 2c061736
	s_cbranch_scc0 BB107                                        ; bf8401be
BB96:
	s_add_u32 s5, s16, 1                                        ; 80058110
	s_movk_i32 s9, 0x80                                         ; b0090080
	s_movk_i32 s12, 0xc0                                        ; b00c00c0
	s_mul_i32 s5, s5, s3                                        ; 92050305
	s_add_u32 s5, s19, s5                                       ; 80050513
	v_add_u32_e32 v11, s5, v10                                  ; 68161405
	v_lshlrev_b32_e32 v12, 1, v11                               ; 24181681
	v_lshl_add_u32 v12, v11, 4, v12                             ; d1fd000c 0431090b
	v_lshl_add_u32 v12, v11, 6, v12                             ; d1fd000c 04310d0b
	v_lshl_add_u32 v11, v11, 7, v12                             ; d1fd000b 04310f0b
	v_and_b32_e32 v13, -4, v11                                  ; 261a16c4
	v_add3_u32 v18, v2, s12, v11                                ; d1ff0012 042c1902
	v_add_u32_e32 v14, v13, v6                                  ; 681c0d0d
	v_add_u32_e32 v15, v13, v16                                 ; 681e210d
	v_add3_u32 v13, v7, s9, v13                                 ; d1ff000d 04341307
	buffer_load_dwordx2 v[22:23], v14, s[24:27], 0 offen        ; e0541000 8006160e
	buffer_load_dwordx2 v[14:15], v15, s[24:27], 0 offen        ; e0541000 80060e0f
	buffer_load_dwordx2 v[12:13], v13, s[24:27], 0 offen        ; e0541000 80060c0d
	buffer_load_sbyte v18, v18, s[24:27], 0 offen               ; e0441000 80061212
	buffer_load_short_d16 v21, v11, s[24:27], 0 offen offset:208 ; e09010d0 8006150b
	s_mov_b32 s13, 0xf0f0f0f                                    ; be8d00ff 0f0f0f0f
	s_mov_b32 s14, 0x30303030                                   ; be8e00ff 30303030
	s_mulk_i32 s18, 0x100                                       ; b7920100
	v_add_u32_e32 v19, v11, v6                                  ; 68260d0b
	v_add_u32_e32 v20, v11, v16                                 ; 6828210b
	v_add3_u32 v17, v7, s9, v11                                 ; d1ff0011 042c1307
	s_mov_b32 s15, 0xc2000000                                   ; be8f00ff c2000000
	s_cmp_lt_u32 2, s4                                          ; bf0a0482
	v_add3_u32 v24, v44, s18, v27                               ; d1ff0018 046c252c
	v_add3_u32 v46, v46, s18, v27                               ; d1ff002e 046c252e
	s_waitcnt vmcnt(4)                                          ; bf8c3f74
	v_alignbyte_b32 v23, v23, v22, v19                          ; d1cf0017 044e2d17
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_alignbyte_b32 v15, v15, v14, v20                          ; d1cf000f 04521d0f
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_alignbyte_b32 v13, v13, v12, v17                          ; d1cf000d 0446190d
	v_and_b32_e32 v25, s13, v15                                 ; 26321e0d
	v_lshrrev_b32_e32 v15, 4, v15                               ; 201e1e84
	v_and_b32_e32 v26, 0x3030303, v13                           ; 26341aff 03030303
	v_and_b32_e32 v48, 0xc0c0c0c, v13                           ; 26601aff 0c0c0c0c
	v_lshlrev_b32_e32 v26, 4, v26                               ; 24343484
	v_lshl_or_b32 v48, v48, 2, v25                              ; d2000030 04650530
	v_and_or_b32 v26, s13, v23, v26                             ; d201001a 046a2e0d
	v_lshrrev_b32_e32 v23, 4, v23                               ; 202e2e84
	v_cvt_f32_ubyte0_e32 v50, v48                               ; 7e642330
	v_cvt_f32_ubyte0_e32 v49, v26                               ; 7e62231a
	v_and_b32_e32 v23, s13, v23                                 ; 262e2e0d
	v_add_f32_e32 v50, s15, v50                                 ; 0264640f
	v_cvt_f32_ubyte1_e32 v53, v26                               ; 7e6a251a
	v_add_f32_e32 v49, s15, v49                                 ; 0262620f
	v_and_or_b32 v23, s14, v13, v23                             ; d2010017 045e1a0e
	v_and_b32_e32 v13, 0xc0c0c0c0, v13                          ; 261a1aff c0c0c0c0
	v_mul_f32_e32 v50, v32, v50                                 ; 0a646520
	v_cvt_f32_ubyte1_e32 v54, v48                               ; 7e6c2530
	v_add_f32_e32 v53, s15, v53                                 ; 026a6a0f
	v_mul_f32_e32 v49, v28, v49                                 ; 0a62631c
	v_cvt_f32_ubyte0_e32 v51, v23                               ; 7e662317
	v_cvt_f32_ubyte1_e32 v55, v23                               ; 7e6e2517
	v_lshrrev_b32_e32 v13, 2, v13                               ; 201a1a82
	v_add_f32_e32 v54, s15, v54                                 ; 026c6c0f
	v_mac_f32_e32 v49, v29, v53                                 ; 2c626b1d
	v_add_f32_e32 v51, s15, v51                                 ; 0266660f
	v_cvt_f32_ubyte2_e32 v57, v26                               ; 7e72271a
	v_add_f32_e32 v55, s15, v55                                 ; 026e6e0f
	v_and_or_b32 v15, s13, v15, v13                             ; d201000f 04361e0d
	v_cvt_f32_ubyte2_e32 v58, v48                               ; 7e742730
	v_mac_f32_e32 v50, v33, v54                                 ; 2c646d21
	v_mul_f32_e32 v51, v36, v51                                 ; 0a666724
	v_cvt_f32_ubyte2_e32 v59, v23                               ; 7e762717
	v_add_f32_e32 v57, s15, v57                                 ; 0272720f
	v_cvt_f32_ubyte0_e32 v52, v15                               ; 7e68230f
	v_cvt_f32_ubyte1_e32 v56, v15                               ; 7e70250f
	v_add_f32_e32 v58, s15, v58                                 ; 0274740f
	v_cvt_f32_ubyte2_e32 v60, v15                               ; 7e78270f
	v_mac_f32_e32 v51, v37, v55                                 ; 2c666f25
	v_cvt_f32_ubyte3_e32 v26, v26                               ; 7e34291a
	v_add_f32_e32 v59, s15, v59                                 ; 0276760f
	v_mac_f32_e32 v49, v30, v57                                 ; 2c62731e
	v_add_f32_e32 v52, s15, v52                                 ; 0268680f
	v_add_f32_e32 v56, s15, v56                                 ; 0270700f
	v_cvt_f32_ubyte3_e32 v48, v48                               ; 7e602930
	v_mac_f32_e32 v50, v34, v58                                 ; 2c647522
	v_add_f32_e32 v60, s15, v60                                 ; 0278780f
	v_cvt_f32_ubyte3_e32 v23, v23                               ; 7e2e2917
	v_add_f32_e32 v26, s15, v26                                 ; 0234340f
	v_mac_f32_e32 v51, v38, v59                                 ; 2c667726
	v_cvt_f32_ubyte3_e32 v15, v15                               ; 7e1e290f
	v_mul_f32_e32 v52, v40, v52                                 ; 0a686928
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_cvt_f32_i32_e32 v18, v18                                  ; 7e240b12
	v_add_f32_e32 v48, s15, v48                                 ; 0260600f
	v_add_f32_e32 v23, s15, v23                                 ; 022e2e0f
	v_mac_f32_e32 v49, v31, v26                                 ; 2c62351f
	v_add_f32_e32 v15, s15, v15                                 ; 021e1e0f
	v_mac_f32_e32 v52, v41, v56                                 ; 2c687129
	v_mac_f32_e32 v50, v35, v48                                 ; 2c646123
	v_mac_f32_e32 v51, v39, v23                                 ; 2c662f27
	v_mac_f32_e32 v52, v42, v60                                 ; 2c68792a
	v_mac_f32_e32 v52, v43, v15                                 ; 2c681f2b
	ds_write_b32 v24, v18                                       ; d81a0000 00001218
	ds_read2_b32 v[12:13], v46 offset1:2                        ; d86e0200 0c00002e
	ds_read2_b32 v[14:15], v46 offset0:4 offset1:6              ; d86e0604 0e00002e
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_cvt_f32_f16_e32 v61, v21                                  ; 7e7a1715
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_mul_f32_e32 v52, v52, v15                                 ; 0a681f34
	v_mac_f32_e32 v52, v51, v14                                 ; 2c681d33
	v_mac_f32_e32 v52, v50, v13                                 ; 2c681b32
	v_mac_f32_e32 v52, v49, v12                                 ; 2c681931
	v_mac_f32_e32 v5, v52, v61                                  ; 2c0a7b34
	s_cbranch_scc0 BB110                                        ; bf840133
BB97:
	s_add_u32 s5, s16, 2                                        ; 80058210
	s_movk_i32 s9, 0x80                                         ; b0090080
	s_movk_i32 s12, 0xc0                                        ; b00c00c0
	s_mul_i32 s5, s5, s3                                        ; 92050305
	s_add_u32 s5, s19, s5                                       ; 80050513
	v_add_u32_e32 v11, s5, v10                                  ; 68161405
	v_lshlrev_b32_e32 v12, 1, v11                               ; 24181681
	v_lshl_add_u32 v12, v11, 4, v12                             ; d1fd000c 0431090b
	v_lshl_add_u32 v12, v11, 6, v12                             ; d1fd000c 04310d0b
	v_lshl_add_u32 v11, v11, 7, v12                             ; d1fd000b 04310f0b
	v_and_b32_e32 v13, -4, v11                                  ; 261a16c4
	v_add3_u32 v18, v2, s12, v11                                ; d1ff0012 042c1902
	v_add_u32_e32 v14, v13, v6                                  ; 681c0d0d
	v_add_u32_e32 v15, v13, v16                                 ; 681e210d
	v_add3_u32 v13, v7, s9, v13                                 ; d1ff000d 04341307
	buffer_load_dwordx2 v[22:23], v14, s[24:27], 0 offen        ; e0541000 8006160e
	buffer_load_dwordx2 v[14:15], v15, s[24:27], 0 offen        ; e0541000 80060e0f
	buffer_load_dwordx2 v[12:13], v13, s[24:27], 0 offen        ; e0541000 80060c0d
	buffer_load_sbyte v18, v18, s[24:27], 0 offen               ; e0441000 80061212
	buffer_load_short_d16 v21, v11, s[24:27], 0 offen offset:208 ; e09010d0 8006150b
	s_mov_b32 s13, 0xf0f0f0f                                    ; be8d00ff 0f0f0f0f
	s_mov_b32 s14, 0x30303030                                   ; be8e00ff 30303030
	s_mov_b32 s15, 0xc2000000                                   ; be8f00ff c2000000
	v_add_u32_e32 v19, v11, v6                                  ; 68260d0b
	v_add_u32_e32 v20, v11, v16                                 ; 6828210b
	v_add3_u32 v17, v7, s9, v11                                 ; d1ff0011 042c1307
	s_cmp_lt_u32 3, s4                                          ; bf0a0483
	s_waitcnt vmcnt(4)                                          ; bf8c3f74
	v_alignbyte_b32 v23, v23, v22, v19                          ; d1cf0017 044e2d17
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_alignbyte_b32 v15, v15, v14, v20                          ; d1cf000f 04521d0f
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_alignbyte_b32 v13, v13, v12, v17                          ; d1cf000d 0446190d
	v_and_b32_e32 v22, s13, v15                                 ; 262c1e0d
	v_lshrrev_b32_e32 v15, 4, v15                               ; 201e1e84
	v_and_b32_e32 v25, 0x3030303, v13                           ; 26321aff 03030303
	v_and_b32_e32 v26, 0xc0c0c0c, v13                           ; 26341aff 0c0c0c0c
	v_lshlrev_b32_e32 v25, 4, v25                               ; 24323284
	v_lshl_or_b32 v26, v26, 2, v22                              ; d200001a 0459051a
	v_and_or_b32 v25, s13, v23, v25                             ; d2010019 04662e0d
	v_lshrrev_b32_e32 v23, 4, v23                               ; 202e2e84
	v_cvt_f32_ubyte0_e32 v49, v26                               ; 7e62231a
	v_cvt_f32_ubyte0_e32 v48, v25                               ; 7e602319
	v_and_b32_e32 v23, s13, v23                                 ; 262e2e0d
	v_add_f32_e32 v49, s15, v49                                 ; 0262620f
	v_cvt_f32_ubyte1_e32 v52, v25                               ; 7e682519
	v_add_f32_e32 v48, s15, v48                                 ; 0260600f
	v_and_or_b32 v23, s14, v13, v23                             ; d2010017 045e1a0e
	v_and_b32_e32 v13, 0xc0c0c0c0, v13                          ; 261a1aff c0c0c0c0
	v_mul_f32_e32 v49, v32, v49                                 ; 0a626320
	v_cvt_f32_ubyte1_e32 v53, v26                               ; 7e6a251a
	v_add_f32_e32 v52, s15, v52                                 ; 0268680f
	v_mul_f32_e32 v48, v28, v48                                 ; 0a60611c
	v_cvt_f32_ubyte0_e32 v50, v23                               ; 7e642317
	v_cvt_f32_ubyte1_e32 v54, v23                               ; 7e6c2517
	v_lshrrev_b32_e32 v13, 2, v13                               ; 201a1a82
	v_add_f32_e32 v53, s15, v53                                 ; 026a6a0f
	v_mac_f32_e32 v48, v29, v52                                 ; 2c60691d
	v_add_f32_e32 v50, s15, v50                                 ; 0264640f
	v_cvt_f32_ubyte2_e32 v56, v25                               ; 7e702719
	v_add_f32_e32 v54, s15, v54                                 ; 026c6c0f
	v_and_or_b32 v15, s13, v15, v13                             ; d201000f 04361e0d
	v_mac_f32_e32 v49, v33, v53                                 ; 2c626b21
	v_cvt_f32_ubyte2_e32 v57, v26                               ; 7e72271a
	v_mul_f32_e32 v50, v36, v50                                 ; 0a646524
	v_cvt_f32_ubyte2_e32 v58, v23                               ; 7e742717
	v_add_f32_e32 v56, s15, v56                                 ; 0270700f
	v_cvt_f32_ubyte0_e32 v51, v15                               ; 7e66230f
	v_cvt_f32_ubyte1_e32 v55, v15                               ; 7e6e250f
	v_cvt_f32_ubyte2_e32 v59, v15                               ; 7e76270f
	v_add_f32_e32 v57, s15, v57                                 ; 0272720f
	v_mac_f32_e32 v50, v37, v54                                 ; 2c646d25
	v_add_f32_e32 v58, s15, v58                                 ; 0274740f
	v_cvt_f32_ubyte3_e32 v25, v25                               ; 7e322919
	v_mac_f32_e32 v48, v30, v56                                 ; 2c60711e
	v_add_f32_e32 v51, s15, v51                                 ; 0266660f
	v_cvt_f32_ubyte3_e32 v26, v26                               ; 7e34291a
	v_add_f32_e32 v55, s15, v55                                 ; 026e6e0f
	v_add_f32_e32 v59, s15, v59                                 ; 0276760f
	v_mac_f32_e32 v49, v34, v57                                 ; 2c627322
	v_cvt_f32_ubyte3_e32 v23, v23                               ; 7e2e2917
	v_mac_f32_e32 v50, v38, v58                                 ; 2c647526
	v_add_f32_e32 v25, s15, v25                                 ; 0232320f
	v_cvt_f32_ubyte3_e32 v15, v15                               ; 7e1e290f
	v_mul_f32_e32 v51, v40, v51                                 ; 0a666728
	v_add_f32_e32 v26, s15, v26                                 ; 0234340f
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_cvt_f32_i32_e32 v18, v18                                  ; 7e240b12
	v_add_f32_e32 v23, s15, v23                                 ; 022e2e0f
	v_mac_f32_e32 v48, v31, v25                                 ; 2c60331f
	v_add_f32_e32 v15, s15, v15                                 ; 021e1e0f
	v_mac_f32_e32 v51, v41, v55                                 ; 2c666f29
	v_mac_f32_e32 v49, v35, v26                                 ; 2c623523
	v_mac_f32_e32 v50, v39, v23                                 ; 2c642f27
	v_mac_f32_e32 v51, v42, v59                                 ; 2c66772a
	v_mac_f32_e32 v51, v43, v15                                 ; 2c661f2b
	ds_write_b32 v45, v18                                       ; d81a0000 0000122d
	ds_read2_b32 v[12:13], v47 offset1:2                        ; d86e0200 0c00002f
	ds_read2_b32 v[14:15], v47 offset0:4 offset1:6              ; d86e0604 0e00002f
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_cvt_f32_f16_e32 v60, v21                                  ; 7e781715
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_mul_f32_e32 v51, v51, v15                                 ; 0a661f33
	v_mac_f32_e32 v51, v50, v14                                 ; 2c661d32
	v_mac_f32_e32 v51, v49, v13                                 ; 2c661b31
	v_mac_f32_e32 v51, v48, v12                                 ; 2c661930
	v_mac_f32_e32 v8, v51, v60                                  ; 2c107933
	s_cbranch_scc0 BB103                                        ; bf8400a9
BB98:
	s_add_u32 s5, s16, 3                                        ; 80058310
	s_movk_i32 s9, 0x80                                         ; b0090080
	s_movk_i32 s10, 0xc0                                        ; b00a00c0
	s_mul_i32 s5, s5, s3                                        ; 92050305
	s_add_u32 s5, s19, s5                                       ; 80050513
	v_add_u32_e32 v11, s5, v10                                  ; 68161405
	v_lshlrev_b32_e32 v12, 1, v11                               ; 24181681
	v_lshl_add_u32 v12, v11, 4, v12                             ; d1fd000c 0431090b
	v_lshl_add_u32 v12, v11, 6, v12                             ; d1fd000c 04310d0b
	v_lshl_add_u32 v11, v11, 7, v12                             ; d1fd000b 04310f0b
	v_add3_u32 v18, v2, s10, v11                                ; d1ff0012 042c1502
	v_and_b32_e32 v13, -4, v11                                  ; 261a16c4
	v_add_u32_e32 v15, v11, v16                                 ; 681e210b
	v_add_u32_e32 v14, v13, v6                                  ; 681c0d0d
	v_add_u32_e32 v16, v13, v16                                 ; 6820210d
	v_add3_u32 v13, v7, s9, v13                                 ; d1ff000d 04341307
	buffer_load_dwordx2 v[20:21], v14, s[24:27], 0 offen        ; e0541000 8006140e
	buffer_load_dwordx2 v[22:23], v16, s[24:27], 0 offen        ; e0541000 80061610
	buffer_load_dwordx2 v[12:13], v13, s[24:27], 0 offen        ; e0541000 80060c0d
	buffer_load_sbyte v18, v18, s[24:27], 0 offen               ; e0441000 80061212
	buffer_load_short_d16 v25, v11, s[24:27], 0 offen offset:208 ; e09010d0 8006190b
	s_mov_b32 s11, 0xf0f0f0f                                    ; be8b00ff 0f0f0f0f
	s_mov_b32 s12, 0x30303030                                   ; be8c00ff 30303030
	s_mov_b32 s13, 0xc2000000                                   ; be8d00ff c2000000
	v_add_u32_e32 v19, v11, v6                                  ; 68260d0b
	v_add3_u32 v17, v7, s9, v11                                 ; d1ff0011 042c1307
	s_waitcnt vmcnt(4)                                          ; bf8c3f74
	v_alignbyte_b32 v21, v21, v20, v19                          ; d1cf0015 044e2915
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_alignbyte_b32 v23, v23, v22, v15                          ; d1cf0017 043e2d17
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_alignbyte_b32 v13, v13, v12, v17                          ; d1cf000d 0446190d
	v_and_b32_e32 v26, s11, v23                                 ; 26342e0b
	v_lshrrev_b32_e32 v23, 4, v23                               ; 202e2e84
	v_and_b32_e32 v47, 0xc0c0c0c, v13                           ; 265e1aff 0c0c0c0c
	v_and_b32_e32 v45, 0x3030303, v13                           ; 265a1aff 03030303
	v_lshl_or_b32 v47, v47, 2, v26                              ; d200002f 0469052f
	v_lshlrev_b32_e32 v45, 4, v45                               ; 245a5a84
	v_cvt_f32_ubyte0_e32 v49, v47                               ; 7e62232f
	v_and_or_b32 v45, s11, v21, v45                             ; d201002d 04b62a0b
	v_lshrrev_b32_e32 v21, 4, v21                               ; 202a2a84
	v_add_f32_e32 v49, s13, v49                                 ; 0262620d
	v_cvt_f32_ubyte0_e32 v48, v45                               ; 7e60232d
	v_and_b32_e32 v21, s11, v21                                 ; 262a2a0b
	v_cvt_f32_ubyte1_e32 v52, v45                               ; 7e68252d
	v_mul_f32_e32 v32, v32, v49                                 ; 0a406320
	v_add_f32_e32 v48, s13, v48                                 ; 0260600d
	v_and_or_b32 v21, s12, v13, v21                             ; d2010015 04561a0c
	v_and_b32_e32 v13, 0xc0c0c0c0, v13                          ; 261a1aff c0c0c0c0
	v_cvt_f32_ubyte1_e32 v53, v47                               ; 7e6a252f
	v_add_f32_e32 v52, s13, v52                                 ; 0268680d
	v_mul_f32_e32 v28, v28, v48                                 ; 0a38611c
	v_cvt_f32_ubyte1_e32 v54, v21                               ; 7e6c2515
	v_cvt_f32_ubyte0_e32 v50, v21                               ; 7e642315
	v_lshrrev_b32_e32 v13, 2, v13                               ; 201a1a82
	v_add_f32_e32 v53, s13, v53                                 ; 026a6a0d
	v_mac_f32_e32 v28, v29, v52                                 ; 2c38691d
	v_add_f32_e32 v54, s13, v54                                 ; 026c6c0d
	v_cvt_f32_ubyte2_e32 v56, v45                               ; 7e70272d
	v_add_f32_e32 v50, s13, v50                                 ; 0264640d
	v_and_or_b32 v23, s11, v23, v13                             ; d2010017 04362e0b
	v_cvt_f32_ubyte2_e32 v57, v47                               ; 7e72272f
	v_mac_f32_e32 v32, v33, v53                                 ; 2c406b21
	v_cvt_f32_ubyte2_e32 v58, v21                               ; 7e742715
	v_add_f32_e32 v56, s13, v56                                 ; 0270700d
	v_mul_f32_e32 v36, v36, v50                                 ; 0a486524
	v_cvt_f32_ubyte1_e32 v55, v23                               ; 7e6e2517
	v_cvt_f32_ubyte0_e32 v51, v23                               ; 7e662317
	v_add_f32_e32 v57, s13, v57                                 ; 0272720d
	v_cvt_f32_ubyte2_e32 v59, v23                               ; 7e762717
	v_add_f32_e32 v58, s13, v58                                 ; 0274740d
	v_mac_f32_e32 v28, v30, v56                                 ; 2c38711e
	v_cvt_f32_ubyte3_e32 v45, v45                               ; 7e5a292d
	v_mac_f32_e32 v36, v37, v54                                 ; 2c486d25
	v_add_f32_e32 v55, s13, v55                                 ; 026e6e0d
	v_add_f32_e32 v51, s13, v51                                 ; 0266660d
	v_cvt_f32_ubyte3_e32 v47, v47                               ; 7e5e292f
	v_mac_f32_e32 v32, v34, v57                                 ; 2c407322
	v_add_f32_e32 v59, s13, v59                                 ; 0276760d
	v_cvt_f32_ubyte3_e32 v21, v21                               ; 7e2a2915
	v_add_f32_e32 v45, s13, v45                                 ; 025a5a0d
	v_mac_f32_e32 v36, v38, v58                                 ; 2c487526
	v_cvt_f32_ubyte3_e32 v23, v23                               ; 7e2e2917
	v_mul_f32_e32 v40, v40, v51                                 ; 0a506728
	v_add_f32_e32 v47, s13, v47                                 ; 025e5e0d
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_cvt_f32_i32_e32 v18, v18                                  ; 7e240b12
	v_add_f32_e32 v21, s13, v21                                 ; 022a2a0d
	v_mac_f32_e32 v28, v31, v45                                 ; 2c385b1f
	v_add_f32_e32 v23, s13, v23                                 ; 022e2e0d
	v_mac_f32_e32 v40, v41, v55                                 ; 2c506f29
	v_mac_f32_e32 v32, v35, v47                                 ; 2c405f23
	v_mac_f32_e32 v36, v39, v21                                 ; 2c482b27
	v_mac_f32_e32 v40, v42, v59                                 ; 2c50772a
	v_mac_f32_e32 v40, v43, v23                                 ; 2c502f2b
	ds_write_b32 v24, v18                                       ; d81a0000 00001218
	ds_read2_b32 v[12:13], v46 offset1:2                        ; d86e0200 0c00002e
	ds_read2_b32 v[14:15], v46 offset0:4 offset1:6              ; d86e0604 0e00002e
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_cvt_f32_f16_e32 v60, v25                                  ; 7e781719
	s_mov_b32 s5, 4                                             ; be850084
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_mul_f32_e32 v40, v40, v15                                 ; 0a501f28
	v_mac_f32_e32 v40, v36, v14                                 ; 2c501d24
	v_mac_f32_e32 v40, v32, v13                                 ; 2c501b20
	v_mac_f32_e32 v40, v28, v12                                 ; 2c50191c
	v_mac_f32_e32 v9, v40, v60                                  ; 2c127928
	s_nop 0                                                     ; bf800000
	(then repeated 3 times)
BB99:
	s_cmp_ge_u32 s5, s4                                         ; bf090405
	s_cbranch_scc1 BB110                                        ; bf850020
BB101:
	s_add_u32 s9, s16, s5                                       ; 80090510
	s_movk_i32 s10, 0xc0                                        ; b00a00c0
	s_mul_i32 s9, s9, s3                                        ; 92090309
	s_add_u32 s9, s19, s9                                       ; 80090913
	v_add_u32_e32 v11, s9, v10                                  ; 68161409
	v_lshlrev_b32_e32 v12, 1, v11                               ; 24181681
	v_lshl_add_u32 v12, v11, 4, v12                             ; d1fd000c 0431090b
	v_lshl_add_u32 v12, v11, 6, v12                             ; d1fd000c 04310d0b
	v_lshl_add_u32 v11, v11, 7, v12                             ; d1fd000b 04310f0b
	v_add3_u32 v11, v2, s10, v11                                ; d1ff000b 042c1502
	buffer_load_sbyte v11, v11, s[24:27], 0 offen               ; e0441000 80060b0b
	s_and_b64 s[10:11], vcc, exec                               ; 868a7e6a
	s_xor_b32 s11, src_scc, 1                                   ; 880b81fd
	s_add_u32 s5, s5, 1                                         ; 80058105
	s_cmp_lg_i32 s11, 0                                         ; bf01800b
	v_lshl_add_u32 v13, s11, 8, v27                             ; d1fd000d 046d100b
	s_cselect_b64 vcc, -1, 0                                    ; 85ea80c1
	v_add_u32_e32 v13, v13, v44                                 ; 681a590d
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_cvt_f32_i32_e32 v11, v11                                  ; 7e160b0b
	ds_write_b32 v13, v11                                       ; d81a0000 00000b0d
	s_branch BB99                                               ; bf82ffe1
BB103:
	s_mov_b64 vcc, s[10:11]                                     ; beea010a
	s_branch BB110                                              ; bf820001
BB107:
	s_mov_b64 vcc, s[10:11]                                     ; beea010a
BB110:
	s_add_u32 s1, s1, 4                                         ; 80018401
	s_branch BB92                                               ; bf82fd90
BB111:
	v_add_u32_e32 v10, s1, v0                                   ; 68140001
	s_cmp_lg_i32 s4, 0                                          ; bf018004
	v_lshl_add_u32 v4, v10, 8, v4                               ; d1fd0004 0411110a
	s_cselect_b64 s[0:1], -1, 0                                 ; 858080c1
	s_cbranch_scc0 BB190                                        ; bf84038a
BB112:
	s_mul_i32 s5, s16, s3                                       ; 92050310
	v_cmpx_gt_u32_e64 s[10:11], s3, v10                         ; d0dc000a 00021403
	s_add_u32 s5, s19, s5                                       ; 80050513
	s_cbranch_execz BB118                                       ; bf88001d
BB113:
	s_mov_b32 s12, s2                                           ; be8c0002
	s_movk_i32 s13, 0x8000                                      ; b00d8000
	s_load_dwordx4 s[12:15], s[12:13], 0x0                      ; c00a0306 00000000
	v_add_u32_e32 v11, s5, v10                                  ; 68161405
	s_movk_i32 s9, 0xc0                                         ; b00900c0
	v_lshlrev_b32_e32 v12, 1, v11                               ; 24181681
	v_lshl_add_u32 v12, v11, 4, v12                             ; d1fd000c 0431090b
	v_lshl_add_u32 v12, v11, 6, v12                             ; d1fd000c 04310d0b
	v_lshl_add_u32 v11, v11, 7, v12                             ; d1fd000b 04310f0b
	v_add3_u32 v11, v2, s9, v11                                 ; d1ff000b 042c1302
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_load_sbyte v11, v11, s[12:15], 0 offen               ; e0441000 80030b0b
	s_and_b64 s[12:13], vcc, exec                               ; 868c7e6a
	s_cselect_b32 s12, 0, 0x100                                 ; 850cff80 00000100
	v_lshl_add_u32 v13, v0, 6, s12                              ; d1fd000d 00310d00
	v_lshl_add_u32 v13, v2, 2, v13                              ; d1fd000d 04350502
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_cvt_f32_i32_e32 v11, v11                                  ; 7e160b0b
	ds_write_b32 v13, v11                                       ; d81a0000 00000b0d
BB118:
	s_mov_b64 exec, s[10:11]                                    ; befe010a
	s_cbranch_execz BB124                                       ; bf880096
BB119:
	s_mov_b32 s12, s2                                           ; be8c0002
	s_movk_i32 s13, 0x8000                                      ; b00d8000
	s_load_dwordx8 s[24:31], s[12:13], 0x0                      ; c00e0606 00000000
	v_add_u32_e32 v11, s5, v10                                  ; 68161405
	v_add_u32_e32 v15, 32, v6                                   ; 681e0ca0
	s_movk_i32 s5, 0x80                                         ; b0050080
	v_lshlrev_b32_e32 v12, 1, v11                               ; 24181681
	v_lshl_add_u32 v12, v11, 4, v12                             ; d1fd000c 0431090b
	v_lshl_add_u32 v12, v11, 6, v12                             ; d1fd000c 04310d0b
	v_lshl_add_u32 v11, v11, 7, v12                             ; d1fd000b 04310f0b
	v_and_b32_e32 v13, -4, v11                                  ; 261a16c4
	v_add_u32_e32 v16, v11, v15                                 ; 68201f0b
	v_add_u32_e32 v14, v13, v6                                  ; 681c0d0d
	v_add_u32_e32 v15, v13, v15                                 ; 681e1f0d
	v_add3_u32 v13, v7, s5, v13                                 ; d1ff000d 04340b07
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_load_dwordx2 v[20:21], v14, s[24:27], 0 offen        ; e0541000 8006140e
	buffer_load_dwordx2 v[14:15], v15, s[24:27], 0 offen        ; e0541000 80060e0f
	buffer_load_dwordx2 v[12:13], v13, s[24:27], 0 offen        ; e0541000 80060c0d
	buffer_load_short_d16 v19, v11, s[24:27], 0 offen offset:208 ; e09010d0 8006130b
	s_mul_i32 s9, s6, s17                                       ; 92091106
	v_add_u32_e32 v22, s9, v4                                   ; 682c0809
	v_lshrrev_b32_e32 v22, 2, v22                               ; 202c2c82
	v_lshlrev_b32_e32 v22, 4, v22                               ; 242c2c84
	buffer_load_dwordx4 v[24:27], v22, s[28:31], 0 offen        ; e05c1000 80071816
	buffer_load_dwordx4 v[28:31], v22, s[28:31], 0 offen offset:128 ; e05c1080 80071c16
	buffer_load_dwordx4 v[32:35], v22, s[28:31], 0 offen offset:256 ; e05c1100 80072016
	buffer_load_dwordx4 v[36:39], v22, s[28:31], 0 offen offset:384 ; e05c1180 80072416
	s_and_b64 s[20:21], vcc, exec                               ; 86947e6a
	s_cselect_b32 s15, 0, 0x100                                 ; 850fff80 00000100
	v_lshl_add_u32 v23, v0, 6, s15                              ; d1fd0017 003d0d00
	v_lshl_add_u32 v23, v1, 2, v23                              ; d1fd0017 045d0501
	ds_read2_b32 v[40:41], v23 offset1:2                        ; d86e0200 28000017
	ds_read2_b32 v[22:23], v23 offset0:4 offset1:6              ; d86e0604 16000017
	v_add_u32_e32 v18, v11, v6                                  ; 68240d0b
	v_add3_u32 v17, v7, s5, v11                                 ; d1ff0011 042c0b07
	s_mov_b32 s12, 0xf0f0f0f                                    ; be8c00ff 0f0f0f0f
	s_mov_b32 s13, 0x30303030                                   ; be8d00ff 30303030
	s_mov_b32 s14, 0xc2000000                                   ; be8e00ff c2000000
	s_waitcnt vmcnt(7)                                          ; bf8c3f77
	v_alignbyte_b32 v21, v21, v20, v18                          ; d1cf0015 044a2915
	s_waitcnt vmcnt(6)                                          ; bf8c3f76
	v_alignbyte_b32 v15, v15, v14, v16                          ; d1cf000f 04421d0f
	s_waitcnt vmcnt(5)                                          ; bf8c3f75
	v_alignbyte_b32 v13, v13, v12, v17                          ; d1cf000d 0446190d
	v_and_b32_e32 v42, s12, v15                                 ; 26541e0c
	v_lshrrev_b32_e32 v15, 4, v15                               ; 201e1e84
	v_and_b32_e32 v43, 0x3030303, v13                           ; 26561aff 03030303
	v_and_b32_e32 v44, 0xc0c0c0c, v13                           ; 26581aff 0c0c0c0c
	v_lshlrev_b32_e32 v43, 4, v43                               ; 24565684
	v_lshl_or_b32 v44, v44, 2, v42                              ; d200002c 04a9052c
	v_and_or_b32 v43, s12, v21, v43                             ; d201002b 04ae2a0c
	v_lshrrev_b32_e32 v21, 4, v21                               ; 202a2a84
	v_cvt_f32_ubyte0_e32 v46, v44                               ; 7e5c232c
	v_cvt_f32_ubyte1_e32 v49, v43                               ; 7e62252b
	v_cvt_f32_ubyte1_e32 v50, v44                               ; 7e64252c
	v_cvt_f32_ubyte0_e32 v45, v43                               ; 7e5a232b
	v_and_b32_e32 v21, s12, v21                                 ; 262a2a0c
	v_add_f32_e32 v46, s14, v46                                 ; 025c5c0e
	v_add_f32_e32 v49, s14, v49                                 ; 0262620e
	v_add_f32_e32 v50, s14, v50                                 ; 0264640e
	v_add_f32_e32 v45, s14, v45                                 ; 025a5a0e
	v_cvt_f32_ubyte2_e32 v53, v43                               ; 7e6a272b
	v_and_or_b32 v21, s13, v13, v21                             ; d2010015 04561a0d
	v_and_b32_e32 v13, 0xc0c0c0c0, v13                          ; 261a1aff c0c0c0c0
	v_cvt_f32_ubyte2_e32 v54, v44                               ; 7e6c272c
	v_add_f32_e32 v53, s14, v53                                 ; 026a6a0e
	v_cvt_f32_ubyte1_e32 v51, v21                               ; 7e662515
	v_cvt_f32_ubyte2_e32 v55, v21                               ; 7e6e2715
	v_cvt_f32_ubyte0_e32 v47, v21                               ; 7e5e2315
	v_lshrrev_b32_e32 v13, 2, v13                               ; 201a1a82
	v_add_f32_e32 v54, s14, v54                                 ; 026c6c0e
	v_cvt_f32_ubyte3_e32 v43, v43                               ; 7e56292b
	v_add_f32_e32 v51, s14, v51                                 ; 0266660e
	v_cvt_f32_ubyte3_e32 v44, v44                               ; 7e58292c
	v_add_f32_e32 v55, s14, v55                                 ; 026e6e0e
	v_add_f32_e32 v47, s14, v47                                 ; 025e5e0e
	v_cvt_f32_ubyte3_e32 v21, v21                               ; 7e2a2915
	v_and_or_b32 v15, s12, v15, v13                             ; d201000f 04361e0c
	v_add_f32_e32 v43, s14, v43                                 ; 0256560e
	s_waitcnt vmcnt(4)                                          ; bf8c3f74
	v_cvt_f32_f16_e32 v57, v19                                  ; 7e721713
	v_add_f32_e32 v44, s14, v44                                 ; 0258580e
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_mul_f32_e32 v24, v24, v45                                 ; 0a305b18
	v_add_f32_e32 v21, s14, v21                                 ; 022a2a0e
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_mul_f32_e32 v28, v28, v46                                 ; 0a385d1c
	v_cvt_f32_ubyte1_e32 v52, v15                               ; 7e68250f
	v_cvt_f32_ubyte2_e32 v56, v15                               ; 7e70270f
	v_cvt_f32_ubyte0_e32 v48, v15                               ; 7e60230f
	v_cvt_f32_ubyte3_e32 v15, v15                               ; 7e1e290f
	v_mac_f32_e32 v24, v25, v49                                 ; 2c306319
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_mul_f32_e32 v32, v32, v47                                 ; 0a405f20
	v_mac_f32_e32 v28, v29, v50                                 ; 2c38651d
	v_add_f32_e32 v52, s14, v52                                 ; 0268680e
	v_add_f32_e32 v56, s14, v56                                 ; 0270700e
	v_add_f32_e32 v48, s14, v48                                 ; 0260600e
	v_add_f32_e32 v15, s14, v15                                 ; 021e1e0e
	v_mac_f32_e32 v24, v26, v53                                 ; 2c306b1a
	v_mac_f32_e32 v32, v33, v51                                 ; 2c406721
	v_mac_f32_e32 v28, v30, v54                                 ; 2c386d1e
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_mul_f32_e32 v36, v36, v48                                 ; 0a486124
	v_mac_f32_e32 v24, v27, v43                                 ; 2c30571b
	v_mac_f32_e32 v32, v34, v55                                 ; 2c406f22
	v_mac_f32_e32 v28, v31, v44                                 ; 2c38591f
	v_mac_f32_e32 v36, v37, v52                                 ; 2c486925
	v_mac_f32_e32 v32, v35, v21                                 ; 2c402b23
	v_mac_f32_e32 v36, v38, v56                                 ; 2c487126
	v_mac_f32_e32 v36, v39, v15                                 ; 2c481f27
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_mul_f32_e32 v36, v36, v23                                 ; 0a482f24
	v_mac_f32_e32 v36, v32, v22                                 ; 2c482d20
	v_mac_f32_e32 v36, v28, v41                                 ; 2c48531c
	v_mac_f32_e32 v36, v24, v40                                 ; 2c485118
	v_mac_f32_e32 v3, v36, v57                                  ; 2c067324
BB124:
	s_mov_b64 exec, -1                                          ; befe01c1
	s_cmp_lt_u32 1, s4                                          ; bf0a0481
	s_cbranch_scc0 BB178                                        ; bf840262
BB125:
	s_mov_b32 s5, src_scc                                       ; be8500fd
	s_add_u32 s9, s16, 1                                        ; 80098110
	s_mov_b64 exec, s[10:11]                                    ; befe010a
	s_mul_i32 s9, s9, s3                                        ; 92090309
	s_add_u32 s9, s19, s9                                       ; 80090913
	s_cbranch_execz BB131                                       ; bf88001d
BB126:
	s_mov_b32 s12, s2                                           ; be8c0002
	s_movk_i32 s13, 0x8000                                      ; b00d8000
	s_load_dwordx4 s[12:15], s[12:13], 0x0                      ; c00a0306 00000000
	v_add_u32_e32 v11, s9, v10                                  ; 68161409
	s_movk_i32 s18, 0xc0                                        ; b01200c0
	v_lshlrev_b32_e32 v12, 1, v11                               ; 24181681
	v_lshl_add_u32 v12, v11, 4, v12                             ; d1fd000c 0431090b
	v_lshl_add_u32 v12, v11, 6, v12                             ; d1fd000c 04310d0b
	v_lshl_add_u32 v11, v11, 7, v12                             ; d1fd000b 04310f0b
	v_add3_u32 v11, v2, s18, v11                                ; d1ff000b 042c2502
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_load_sbyte v11, v11, s[12:15], 0 offen               ; e0441000 80030b0b
	s_and_b64 s[12:13], vcc, exec                               ; 868c7e6a
	s_mul_i32 s20, 0x100, src_scc                               ; 9214fdff 00000100
	v_lshl_add_u32 v13, v0, 6, s20                              ; d1fd000d 00510d00
	v_lshl_add_u32 v13, v2, 2, v13                              ; d1fd000d 04350502
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_cvt_f32_i32_e32 v11, v11                                  ; 7e160b0b
	ds_write_b32 v13, v11                                       ; d81a0000 00000b0d
BB131:
	s_mov_b64 exec, s[10:11]                                    ; befe010a
	s_cbranch_execz BB137                                       ; bf880096
BB132:
	s_mov_b32 s12, s2                                           ; be8c0002
	s_movk_i32 s13, 0x8000                                      ; b00d8000
	s_load_dwordx8 s[24:31], s[12:13], 0x0                      ; c00e0606 00000000
	v_add_u32_e32 v11, s9, v10                                  ; 68161409
	v_add_u32_e32 v15, 32, v6                                   ; 681e0ca0
	s_movk_i32 s9, 0x80                                         ; b0090080
	v_lshlrev_b32_e32 v12, 1, v11                               ; 24181681
	v_lshl_add_u32 v12, v11, 4, v12                             ; d1fd000c 0431090b
	v_lshl_add_u32 v12, v11, 6, v12                             ; d1fd000c 04310d0b
	v_lshl_add_u32 v11, v11, 7, v12                             ; d1fd000b 04310f0b
	v_and_b32_e32 v13, -4, v11                                  ; 261a16c4
	v_add_u32_e32 v16, v11, v15                                 ; 68201f0b
	v_add_u32_e32 v14, v13, v6                                  ; 681c0d0d
	v_add_u32_e32 v15, v13, v15                                 ; 681e1f0d
	v_add3_u32 v13, v7, s9, v13                                 ; d1ff000d 04341307
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_load_dwordx2 v[20:21], v14, s[24:27], 0 offen        ; e0541000 8006140e
	buffer_load_dwordx2 v[14:15], v15, s[24:27], 0 offen        ; e0541000 80060e0f
	buffer_load_dwordx2 v[12:13], v13, s[24:27], 0 offen        ; e0541000 80060c0d
	buffer_load_short_d16 v19, v11, s[24:27], 0 offen offset:208 ; e09010d0 8006130b
	s_mul_i32 s12, s6, s17                                      ; 920c1106
	v_add_u32_e32 v22, s12, v4                                  ; 682c080c
	v_lshrrev_b32_e32 v22, 2, v22                               ; 202c2c82
	v_lshlrev_b32_e32 v22, 4, v22                               ; 242c2c84
	buffer_load_dwordx4 v[24:27], v22, s[28:31], 0 offen        ; e05c1000 80071816
	buffer_load_dwordx4 v[28:31], v22, s[28:31], 0 offen offset:128 ; e05c1080 80071c16
	buffer_load_dwordx4 v[32:35], v22, s[28:31], 0 offen offset:256 ; e05c1100 80072016
	buffer_load_dwordx4 v[36:39], v22, s[28:31], 0 offen offset:384 ; e05c1180 80072416
	s_and_b64 s[20:21], vcc, exec                               ; 86947e6a
	s_mul_i32 s18, 0x100, src_scc                               ; 9212fdff 00000100
	v_lshl_add_u32 v23, v0, 6, s18                              ; d1fd0017 00490d00
	v_lshl_add_u32 v23, v1, 2, v23                              ; d1fd0017 045d0501
	ds_read2_b32 v[40:41], v23 offset1:2                        ; d86e0200 28000017
	ds_read2_b32 v[22:23], v23 offset0:4 offset1:6              ; d86e0604 16000017
	v_add_u32_e32 v18, v11, v6                                  ; 68240d0b
	v_add3_u32 v17, v7, s9, v11                                 ; d1ff0011 042c1307
	s_mov_b32 s13, 0xf0f0f0f                                    ; be8d00ff 0f0f0f0f
	s_mov_b32 s14, 0x30303030                                   ; be8e00ff 30303030
	s_mov_b32 s15, 0xc2000000                                   ; be8f00ff c2000000
	s_waitcnt vmcnt(7)                                          ; bf8c3f77
	v_alignbyte_b32 v21, v21, v20, v18                          ; d1cf0015 044a2915
	s_waitcnt vmcnt(6)                                          ; bf8c3f76
	v_alignbyte_b32 v15, v15, v14, v16                          ; d1cf000f 04421d0f
	s_waitcnt vmcnt(5)                                          ; bf8c3f75
	v_alignbyte_b32 v13, v13, v12, v17                          ; d1cf000d 0446190d
	v_and_b32_e32 v42, s13, v15                                 ; 26541e0d
	v_lshrrev_b32_e32 v15, 4, v15                               ; 201e1e84
	v_and_b32_e32 v43, 0x3030303, v13                           ; 26561aff 03030303
	v_and_b32_e32 v44, 0xc0c0c0c, v13                           ; 26581aff 0c0c0c0c
	v_lshlrev_b32_e32 v43, 4, v43                               ; 24565684
	v_lshl_or_b32 v44, v44, 2, v42                              ; d200002c 04a9052c
	v_and_or_b32 v43, s13, v21, v43                             ; d201002b 04ae2a0d
	v_lshrrev_b32_e32 v21, 4, v21                               ; 202a2a84
	v_cvt_f32_ubyte0_e32 v46, v44                               ; 7e5c232c
	v_cvt_f32_ubyte1_e32 v49, v43                               ; 7e62252b
	v_cvt_f32_ubyte1_e32 v50, v44                               ; 7e64252c
	v_cvt_f32_ubyte0_e32 v45, v43                               ; 7e5a232b
	v_and_b32_e32 v21, s13, v21                                 ; 262a2a0d
	v_add_f32_e32 v46, s15, v46                                 ; 025c5c0f
	v_add_f32_e32 v49, s15, v49                                 ; 0262620f
	v_add_f32_e32 v50, s15, v50                                 ; 0264640f
	v_add_f32_e32 v45, s15, v45                                 ; 025a5a0f
	v_cvt_f32_ubyte2_e32 v53, v43                               ; 7e6a272b
	v_and_or_b32 v21, s14, v13, v21                             ; d2010015 04561a0e
	v_and_b32_e32 v13, 0xc0c0c0c0, v13                          ; 261a1aff c0c0c0c0
	v_cvt_f32_ubyte2_e32 v54, v44                               ; 7e6c272c
	v_add_f32_e32 v53, s15, v53                                 ; 026a6a0f
	v_cvt_f32_ubyte1_e32 v51, v21                               ; 7e662515
	v_cvt_f32_ubyte2_e32 v55, v21                               ; 7e6e2715
	v_cvt_f32_ubyte0_e32 v47, v21                               ; 7e5e2315
	v_lshrrev_b32_e32 v13, 2, v13                               ; 201a1a82
	v_add_f32_e32 v54, s15, v54                                 ; 026c6c0f
	v_cvt_f32_ubyte3_e32 v43, v43                               ; 7e56292b
	v_add_f32_e32 v51, s15, v51                                 ; 0266660f
	v_cvt_f32_ubyte3_e32 v44, v44                               ; 7e58292c
	v_add_f32_e32 v55, s15, v55                                 ; 026e6e0f
	v_add_f32_e32 v47, s15, v47                                 ; 025e5e0f
	v_cvt_f32_ubyte3_e32 v21, v21                               ; 7e2a2915
	v_and_or_b32 v15, s13, v15, v13                             ; d201000f 04361e0d
	v_add_f32_e32 v43, s15, v43                                 ; 0256560f
	s_waitcnt vmcnt(4)                                          ; bf8c3f74
	v_cvt_f32_f16_e32 v57, v19                                  ; 7e721713
	v_add_f32_e32 v44, s15, v44                                 ; 0258580f
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_mul_f32_e32 v24, v24, v45                                 ; 0a305b18
	v_add_f32_e32 v21, s15, v21                                 ; 022a2a0f
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_mul_f32_e32 v28, v28, v46                                 ; 0a385d1c
	v_cvt_f32_ubyte1_e32 v52, v15                               ; 7e68250f
	v_cvt_f32_ubyte2_e32 v56, v15                               ; 7e70270f
	v_cvt_f32_ubyte0_e32 v48, v15                               ; 7e60230f
	v_cvt_f32_ubyte3_e32 v15, v15                               ; 7e1e290f
	v_mac_f32_e32 v24, v25, v49                                 ; 2c306319
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_mul_f32_e32 v32, v32, v47                                 ; 0a405f20
	v_mac_f32_e32 v28, v29, v50                                 ; 2c38651d
	v_add_f32_e32 v52, s15, v52                                 ; 0268680f
	v_add_f32_e32 v56, s15, v56                                 ; 0270700f
	v_add_f32_e32 v48, s15, v48                                 ; 0260600f
	v_add_f32_e32 v15, s15, v15                                 ; 021e1e0f
	v_mac_f32_e32 v24, v26, v53                                 ; 2c306b1a
	v_mac_f32_e32 v32, v33, v51                                 ; 2c406721
	v_mac_f32_e32 v28, v30, v54                                 ; 2c386d1e
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_mul_f32_e32 v36, v36, v48                                 ; 0a486124
	v_mac_f32_e32 v24, v27, v43                                 ; 2c30571b
	v_mac_f32_e32 v32, v34, v55                                 ; 2c406f22
	v_mac_f32_e32 v28, v31, v44                                 ; 2c38591f
	v_mac_f32_e32 v36, v37, v52                                 ; 2c486925
	v_mac_f32_e32 v32, v35, v21                                 ; 2c402b23
	v_mac_f32_e32 v36, v38, v56                                 ; 2c487126
	v_mac_f32_e32 v36, v39, v15                                 ; 2c481f27
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_mul_f32_e32 v36, v36, v23                                 ; 0a482f24
	v_mac_f32_e32 v36, v32, v22                                 ; 2c482d20
	v_mac_f32_e32 v36, v28, v41                                 ; 2c48531c
	v_mac_f32_e32 v36, v24, v40                                 ; 2c485118
	v_mac_f32_e32 v5, v36, v57                                  ; 2c0a7324
BB137:
	s_mov_b64 exec, -1                                          ; befe01c1
	s_cmp_lt_u32 2, s4                                          ; bf0a0482
	s_cbranch_scc0 BB179                                        ; bf8401a5
BB138:
	s_add_u32 s9, s16, 2                                        ; 80098210
	s_mov_b64 exec, s[10:11]                                    ; befe010a
	s_mul_i32 s9, s9, s3                                        ; 92090309
	s_add_u32 s9, s19, s9                                       ; 80090913
	s_cbranch_execz BB144                                       ; bf88001d
BB139:
	s_mov_b32 s12, s2                                           ; be8c0002
	s_movk_i32 s13, 0x8000                                      ; b00d8000
	s_load_dwordx4 s[12:15], s[12:13], 0x0                      ; c00a0306 00000000
	v_add_u32_e32 v11, s9, v10                                  ; 68161409
	s_movk_i32 s18, 0xc0                                        ; b01200c0
	v_lshlrev_b32_e32 v12, 1, v11                               ; 24181681
	v_lshl_add_u32 v12, v11, 4, v12                             ; d1fd000c 0431090b
	v_lshl_add_u32 v12, v11, 6, v12                             ; d1fd000c 04310d0b
	v_lshl_add_u32 v11, v11, 7, v12                             ; d1fd000b 04310f0b
	v_add3_u32 v11, v2, s18, v11                                ; d1ff000b 042c2502
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_load_sbyte v11, v11, s[12:15], 0 offen               ; e0441000 80030b0b
	s_and_b64 s[12:13], vcc, exec                               ; 868c7e6a
	s_cselect_b32 s20, 0, 0x100                                 ; 8514ff80 00000100
	v_lshl_add_u32 v13, v0, 6, s20                              ; d1fd000d 00510d00
	v_lshl_add_u32 v13, v2, 2, v13                              ; d1fd000d 04350502
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_cvt_f32_i32_e32 v11, v11                                  ; 7e160b0b
	ds_write_b32 v13, v11                                       ; d81a0000 00000b0d
BB144:
	s_mov_b64 exec, s[10:11]                                    ; befe010a
	s_cbranch_execz BB150                                       ; bf880096
BB145:
	s_mov_b32 s12, s2                                           ; be8c0002
	s_movk_i32 s13, 0x8000                                      ; b00d8000
	s_load_dwordx8 s[24:31], s[12:13], 0x0                      ; c00e0606 00000000
	v_add_u32_e32 v11, s9, v10                                  ; 68161409
	v_add_u32_e32 v15, 32, v6                                   ; 681e0ca0
	s_movk_i32 s9, 0x80                                         ; b0090080
	v_lshlrev_b32_e32 v12, 1, v11                               ; 24181681
	v_lshl_add_u32 v12, v11, 4, v12                             ; d1fd000c 0431090b
	v_lshl_add_u32 v12, v11, 6, v12                             ; d1fd000c 04310d0b
	v_lshl_add_u32 v11, v11, 7, v12                             ; d1fd000b 04310f0b
	v_and_b32_e32 v13, -4, v11                                  ; 261a16c4
	v_add_u32_e32 v16, v11, v15                                 ; 68201f0b
	v_add_u32_e32 v14, v13, v6                                  ; 681c0d0d
	v_add_u32_e32 v15, v13, v15                                 ; 681e1f0d
	v_add3_u32 v13, v7, s9, v13                                 ; d1ff000d 04341307
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_load_dwordx2 v[20:21], v14, s[24:27], 0 offen        ; e0541000 8006140e
	buffer_load_dwordx2 v[14:15], v15, s[24:27], 0 offen        ; e0541000 80060e0f
	buffer_load_dwordx2 v[12:13], v13, s[24:27], 0 offen        ; e0541000 80060c0d
	buffer_load_short_d16 v19, v11, s[24:27], 0 offen offset:208 ; e09010d0 8006130b
	s_mul_i32 s12, s6, s17                                      ; 920c1106
	v_add_u32_e32 v22, s12, v4                                  ; 682c080c
	v_lshrrev_b32_e32 v22, 2, v22                               ; 202c2c82
	v_lshlrev_b32_e32 v22, 4, v22                               ; 242c2c84
	buffer_load_dwordx4 v[24:27], v22, s[28:31], 0 offen        ; e05c1000 80071816
	buffer_load_dwordx4 v[28:31], v22, s[28:31], 0 offen offset:128 ; e05c1080 80071c16
	buffer_load_dwordx4 v[32:35], v22, s[28:31], 0 offen offset:256 ; e05c1100 80072016
	buffer_load_dwordx4 v[36:39], v22, s[28:31], 0 offen offset:384 ; e05c1180 80072416
	s_and_b64 s[20:21], vcc, exec                               ; 86947e6a
	s_cselect_b32 s18, 0, 0x100                                 ; 8512ff80 00000100
	v_lshl_add_u32 v23, v0, 6, s18                              ; d1fd0017 00490d00
	v_lshl_add_u32 v23, v1, 2, v23                              ; d1fd0017 045d0501
	ds_read2_b32 v[40:41], v23 offset1:2                        ; d86e0200 28000017
	ds_read2_b32 v[22:23], v23 offset0:4 offset1:6              ; d86e0604 16000017
	v_add_u32_e32 v18, v11, v6                                  ; 68240d0b
	v_add3_u32 v17, v7, s9, v11                                 ; d1ff0011 042c1307
	s_mov_b32 s13, 0xf0f0f0f                                    ; be8d00ff 0f0f0f0f
	s_mov_b32 s14, 0x30303030                                   ; be8e00ff 30303030
	s_mov_b32 s15, 0xc2000000                                   ; be8f00ff c2000000
	s_waitcnt vmcnt(7)                                          ; bf8c3f77
	v_alignbyte_b32 v21, v21, v20, v18                          ; d1cf0015 044a2915
	s_waitcnt vmcnt(6)                                          ; bf8c3f76
	v_alignbyte_b32 v15, v15, v14, v16                          ; d1cf000f 04421d0f
	s_waitcnt vmcnt(5)                                          ; bf8c3f75
	v_alignbyte_b32 v13, v13, v12, v17                          ; d1cf000d 0446190d
	v_and_b32_e32 v42, s13, v15                                 ; 26541e0d
	v_lshrrev_b32_e32 v15, 4, v15                               ; 201e1e84
	v_and_b32_e32 v43, 0x3030303, v13                           ; 26561aff 03030303
	v_and_b32_e32 v44, 0xc0c0c0c, v13                           ; 26581aff 0c0c0c0c
	v_lshlrev_b32_e32 v43, 4, v43                               ; 24565684
	v_lshl_or_b32 v44, v44, 2, v42                              ; d200002c 04a9052c
	v_and_or_b32 v43, s13, v21, v43                             ; d201002b 04ae2a0d
	v_lshrrev_b32_e32 v21, 4, v21                               ; 202a2a84
	v_cvt_f32_ubyte0_e32 v46, v44                               ; 7e5c232c
	v_cvt_f32_ubyte1_e32 v49, v43                               ; 7e62252b
	v_cvt_f32_ubyte1_e32 v50, v44                               ; 7e64252c
	v_cvt_f32_ubyte0_e32 v45, v43                               ; 7e5a232b
	v_and_b32_e32 v21, s13, v21                                 ; 262a2a0d
	v_add_f32_e32 v46, s15, v46                                 ; 025c5c0f
	v_add_f32_e32 v49, s15, v49                                 ; 0262620f
	v_add_f32_e32 v50, s15, v50                                 ; 0264640f
	v_add_f32_e32 v45, s15, v45                                 ; 025a5a0f
	v_cvt_f32_ubyte2_e32 v53, v43                               ; 7e6a272b
	v_and_or_b32 v21, s14, v13, v21                             ; d2010015 04561a0e
	v_and_b32_e32 v13, 0xc0c0c0c0, v13                          ; 261a1aff c0c0c0c0
	v_cvt_f32_ubyte2_e32 v54, v44                               ; 7e6c272c
	v_add_f32_e32 v53, s15, v53                                 ; 026a6a0f
	v_cvt_f32_ubyte1_e32 v51, v21                               ; 7e662515
	v_cvt_f32_ubyte2_e32 v55, v21                               ; 7e6e2715
	v_cvt_f32_ubyte0_e32 v47, v21                               ; 7e5e2315
	v_lshrrev_b32_e32 v13, 2, v13                               ; 201a1a82
	v_add_f32_e32 v54, s15, v54                                 ; 026c6c0f
	v_cvt_f32_ubyte3_e32 v43, v43                               ; 7e56292b
	v_add_f32_e32 v51, s15, v51                                 ; 0266660f
	v_cvt_f32_ubyte3_e32 v44, v44                               ; 7e58292c
	v_add_f32_e32 v55, s15, v55                                 ; 026e6e0f
	v_add_f32_e32 v47, s15, v47                                 ; 025e5e0f
	v_cvt_f32_ubyte3_e32 v21, v21                               ; 7e2a2915
	v_and_or_b32 v15, s13, v15, v13                             ; d201000f 04361e0d
	v_add_f32_e32 v43, s15, v43                                 ; 0256560f
	s_waitcnt vmcnt(4)                                          ; bf8c3f74
	v_cvt_f32_f16_e32 v57, v19                                  ; 7e721713
	v_add_f32_e32 v44, s15, v44                                 ; 0258580f
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_mul_f32_e32 v24, v24, v45                                 ; 0a305b18
	v_add_f32_e32 v21, s15, v21                                 ; 022a2a0f
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_mul_f32_e32 v28, v28, v46                                 ; 0a385d1c
	v_cvt_f32_ubyte1_e32 v52, v15                               ; 7e68250f
	v_cvt_f32_ubyte2_e32 v56, v15                               ; 7e70270f
	v_cvt_f32_ubyte0_e32 v48, v15                               ; 7e60230f
	v_cvt_f32_ubyte3_e32 v15, v15                               ; 7e1e290f
	v_mac_f32_e32 v24, v25, v49                                 ; 2c306319
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_mul_f32_e32 v32, v32, v47                                 ; 0a405f20
	v_mac_f32_e32 v28, v29, v50                                 ; 2c38651d
	v_add_f32_e32 v52, s15, v52                                 ; 0268680f
	v_add_f32_e32 v56, s15, v56                                 ; 0270700f
	v_add_f32_e32 v48, s15, v48                                 ; 0260600f
	v_add_f32_e32 v15, s15, v15                                 ; 021e1e0f
	v_mac_f32_e32 v24, v26, v53                                 ; 2c306b1a
	v_mac_f32_e32 v32, v33, v51                                 ; 2c406721
	v_mac_f32_e32 v28, v30, v54                                 ; 2c386d1e
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_mul_f32_e32 v36, v36, v48                                 ; 0a486124
	v_mac_f32_e32 v24, v27, v43                                 ; 2c30571b
	v_mac_f32_e32 v32, v34, v55                                 ; 2c406f22
	v_mac_f32_e32 v28, v31, v44                                 ; 2c38591f
	v_mac_f32_e32 v36, v37, v52                                 ; 2c486925
	v_mac_f32_e32 v32, v35, v21                                 ; 2c402b23
	v_mac_f32_e32 v36, v38, v56                                 ; 2c487126
	v_mac_f32_e32 v36, v39, v15                                 ; 2c481f27
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_mul_f32_e32 v36, v36, v23                                 ; 0a482f24
	v_mac_f32_e32 v36, v32, v22                                 ; 2c482d20
	v_mac_f32_e32 v36, v28, v41                                 ; 2c48531c
	v_mac_f32_e32 v36, v24, v40                                 ; 2c485118
	v_mac_f32_e32 v8, v36, v57                                  ; 2c107324
BB150:
	s_mov_b64 exec, -1                                          ; befe01c1
	s_cmp_lt_u32 3, s4                                          ; bf0a0483
	s_cbranch_scc0 BB179                                        ; bf8400e8
BB151:
	s_add_u32 s9, s16, 3                                        ; 80098310
	s_mov_b64 exec, s[10:11]                                    ; befe010a
	s_mul_i32 s9, s9, s3                                        ; 92090309
	s_add_u32 s9, s19, s9                                       ; 80090913
	s_cbranch_execz BB157                                       ; bf88001d
BB152:
	s_mov_b32 s12, s2                                           ; be8c0002
	s_movk_i32 s13, 0x8000                                      ; b00d8000
	s_load_dwordx4 s[12:15], s[12:13], 0x0                      ; c00a0306 00000000
	v_add_u32_e32 v11, s9, v10                                  ; 68161409
	s_movk_i32 s18, 0xc0                                        ; b01200c0
	v_lshlrev_b32_e32 v12, 1, v11                               ; 24181681
	v_lshl_add_u32 v12, v11, 4, v12                             ; d1fd000c 0431090b
	v_lshl_add_u32 v12, v11, 6, v12                             ; d1fd000c 04310d0b
	v_lshl_add_u32 v11, v11, 7, v12                             ; d1fd000b 04310f0b
	v_add3_u32 v11, v2, s18, v11                                ; d1ff000b 042c2502
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_load_sbyte v11, v11, s[12:15], 0 offen               ; e0441000 80030b0b
	s_and_b64 s[12:13], vcc, exec                               ; 868c7e6a
	s_mul_i32 s20, 0x100, src_scc                               ; 9214fdff 00000100
	v_lshl_add_u32 v13, v0, 6, s20                              ; d1fd000d 00510d00
	v_lshl_add_u32 v13, v2, 2, v13                              ; d1fd000d 04350502
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_cvt_f32_i32_e32 v11, v11                                  ; 7e160b0b
	ds_write_b32 v13, v11                                       ; d81a0000 00000b0d
BB157:
	s_mov_b64 exec, s[10:11]                                    ; befe010a
	s_cbranch_execz BB163                                       ; bf880096
BB158:
	s_mov_b32 s12, s2                                           ; be8c0002
	s_movk_i32 s13, 0x8000                                      ; b00d8000
	s_load_dwordx8 s[24:31], s[12:13], 0x0                      ; c00e0606 00000000
	v_add_u32_e32 v11, s9, v10                                  ; 68161409
	s_movk_i32 s9, 0x80                                         ; b0090080
	v_lshlrev_b32_e32 v12, 1, v11                               ; 24181681
	v_lshl_add_u32 v12, v11, 4, v12                             ; d1fd000c 0431090b
	v_lshl_add_u32 v12, v11, 6, v12                             ; d1fd000c 04310d0b
	v_lshl_add_u32 v11, v11, 7, v12                             ; d1fd000b 04310f0b
	v_and_b32_e32 v13, -4, v11                                  ; 261a16c4
	v_add_u32_e32 v15, v11, v6                                  ; 681e0d0b
	v_add3_u32 v17, v7, s9, v11                                 ; d1ff0011 042c1307
	v_add3_u32 v7, v7, s9, v13                                  ; d1ff0007 04341307
	v_add_u32_e32 v14, v13, v6                                  ; 681c0d0d
	v_add_u32_e32 v6, 32, v6                                    ; 680c0ca0
	v_add_u32_e32 v16, v11, v6                                  ; 68200d0b
	v_add_u32_e32 v6, v13, v6                                   ; 680c0d0d
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_load_dwordx2 v[12:13], v14, s[24:27], 0 offen        ; e0541000 80060c0e
	buffer_load_dwordx2 v[18:19], v6, s[24:27], 0 offen         ; e0541000 80061206
	buffer_load_dwordx2 v[6:7], v7, s[24:27], 0 offen           ; e0541000 80060607
	buffer_load_short_d16 v20, v11, s[24:27], 0 offen offset:208 ; e09010d0 8006140b
	s_mul_i32 s6, s6, s17                                       ; 92061106
	v_add_u32_e32 v4, s6, v4                                    ; 68080806
	v_lshrrev_b32_e32 v4, 2, v4                                 ; 20080882
	v_lshlrev_b32_e32 v4, 4, v4                                 ; 24080884
	buffer_load_dwordx4 v[24:27], v4, s[28:31], 0 offen         ; e05c1000 80071804
	buffer_load_dwordx4 v[28:31], v4, s[28:31], 0 offen offset:128 ; e05c1080 80071c04
	buffer_load_dwordx4 v[32:35], v4, s[28:31], 0 offen offset:256 ; e05c1100 80072004
	buffer_load_dwordx4 v[36:39], v4, s[28:31], 0 offen offset:384 ; e05c1180 80072404
	s_and_b64 s[20:21], vcc, exec                               ; 86947e6a
	s_mul_i32 s15, 0x100, src_scc                               ; 920ffdff 00000100
	v_lshl_add_u32 v21, v0, 6, s15                              ; d1fd0015 003d0d00
	v_lshl_add_u32 v1, v1, 2, v21                               ; d1fd0001 04550501
	ds_read2_b32 v[22:23], v1 offset1:2                         ; d86e0200 16000001
	ds_read2_b32 v[40:41], v1 offset0:4 offset1:6               ; d86e0604 28000001
	s_mov_b32 s12, 0xf0f0f0f                                    ; be8c00ff 0f0f0f0f
	s_mov_b32 s13, 0x30303030                                   ; be8d00ff 30303030
	s_mov_b32 s14, 0xc2000000                                   ; be8e00ff c2000000
	s_waitcnt vmcnt(7)                                          ; bf8c3f77
	v_alignbyte_b32 v13, v13, v12, v15                          ; d1cf000d 043e190d
	s_waitcnt vmcnt(6)                                          ; bf8c3f76
	v_alignbyte_b32 v19, v19, v18, v16                          ; d1cf0013 04422513
	s_waitcnt vmcnt(5)                                          ; bf8c3f75
	v_alignbyte_b32 v7, v7, v6, v17                             ; d1cf0007 04460d07
	v_and_b32_e32 v42, s12, v19                                 ; 2654260c
	v_lshrrev_b32_e32 v19, 4, v19                               ; 20262684
	v_and_b32_e32 v44, 0xc0c0c0c, v7                            ; 26580eff 0c0c0c0c
	v_and_b32_e32 v43, 0x3030303, v7                            ; 26560eff 03030303
	v_lshl_or_b32 v44, v44, 2, v42                              ; d200002c 04a9052c
	v_lshlrev_b32_e32 v43, 4, v43                               ; 24565684
	v_cvt_f32_ubyte0_e32 v46, v44                               ; 7e5c232c
	v_and_or_b32 v43, s12, v13, v43                             ; d201002b 04ae1a0c
	v_lshrrev_b32_e32 v13, 4, v13                               ; 201a1a84
	v_add_f32_e32 v46, s14, v46                                 ; 025c5c0e
	v_cvt_f32_ubyte1_e32 v50, v44                               ; 7e64252c
	v_cvt_f32_ubyte1_e32 v49, v43                               ; 7e62252b
	v_cvt_f32_ubyte0_e32 v45, v43                               ; 7e5a232b
	v_and_b32_e32 v13, s12, v13                                 ; 261a1a0c
	v_add_f32_e32 v50, s14, v50                                 ; 0264640e
	v_add_f32_e32 v49, s14, v49                                 ; 0262620e
	v_add_f32_e32 v45, s14, v45                                 ; 025a5a0e
	v_cvt_f32_ubyte2_e32 v53, v43                               ; 7e6a272b
	v_and_or_b32 v13, s13, v7, v13                              ; d201000d 04360e0d
	v_and_b32_e32 v7, 0xc0c0c0c0, v7                            ; 260e0eff c0c0c0c0
	v_cvt_f32_ubyte2_e32 v54, v44                               ; 7e6c272c
	v_add_f32_e32 v53, s14, v53                                 ; 026a6a0e
	v_cvt_f32_ubyte1_e32 v51, v13                               ; 7e66250d
	v_cvt_f32_ubyte0_e32 v47, v13                               ; 7e5e230d
	v_cvt_f32_ubyte2_e32 v55, v13                               ; 7e6e270d
	v_lshrrev_b32_e32 v7, 2, v7                                 ; 200e0e82
	v_cvt_f32_ubyte3_e32 v43, v43                               ; 7e56292b
	v_add_f32_e32 v54, s14, v54                                 ; 026c6c0e
	v_cvt_f32_ubyte3_e32 v44, v44                               ; 7e58292c
	v_add_f32_e32 v51, s14, v51                                 ; 0266660e
	v_add_f32_e32 v47, s14, v47                                 ; 025e5e0e
	v_add_f32_e32 v55, s14, v55                                 ; 026e6e0e
	v_cvt_f32_ubyte3_e32 v13, v13                               ; 7e1a290d
	v_and_or_b32 v19, s12, v19, v7                              ; d2010013 041e260c
	v_add_f32_e32 v43, s14, v43                                 ; 0256560e
	s_waitcnt vmcnt(4)                                          ; bf8c3f74
	v_cvt_f32_f16_e32 v57, v20                                  ; 7e721714
	v_add_f32_e32 v44, s14, v44                                 ; 0258580e
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_mul_f32_e32 v24, v24, v45                                 ; 0a305b18
	v_add_f32_e32 v13, s14, v13                                 ; 021a1a0e
	v_cvt_f32_ubyte1_e32 v52, v19                               ; 7e682513
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_mul_f32_e32 v28, v28, v46                                 ; 0a385d1c
	v_cvt_f32_ubyte2_e32 v56, v19                               ; 7e702713
	v_cvt_f32_ubyte0_e32 v48, v19                               ; 7e602313
	v_cvt_f32_ubyte3_e32 v19, v19                               ; 7e262913
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_mul_f32_e32 v32, v32, v47                                 ; 0a405f20
	v_mac_f32_e32 v24, v25, v49                                 ; 2c306319
	v_add_f32_e32 v52, s14, v52                                 ; 0268680e
	v_mac_f32_e32 v28, v29, v50                                 ; 2c38651d
	v_add_f32_e32 v56, s14, v56                                 ; 0270700e
	v_add_f32_e32 v48, s14, v48                                 ; 0260600e
	v_add_f32_e32 v19, s14, v19                                 ; 0226260e
	v_mac_f32_e32 v32, v33, v51                                 ; 2c406721
	v_mac_f32_e32 v24, v26, v53                                 ; 2c306b1a
	v_mac_f32_e32 v28, v30, v54                                 ; 2c386d1e
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_mul_f32_e32 v36, v36, v48                                 ; 0a486124
	v_mac_f32_e32 v32, v34, v55                                 ; 2c406f22
	v_mac_f32_e32 v24, v27, v43                                 ; 2c30571b
	v_mac_f32_e32 v28, v31, v44                                 ; 2c38591f
	v_mac_f32_e32 v36, v37, v52                                 ; 2c486925
	v_mac_f32_e32 v32, v35, v13                                 ; 2c401b23
	v_mac_f32_e32 v36, v38, v56                                 ; 2c487126
	v_mac_f32_e32 v36, v39, v19                                 ; 2c482727
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_mul_f32_e32 v36, v36, v41                                 ; 0a485324
	v_mac_f32_e32 v36, v32, v40                                 ; 2c485120
	v_mac_f32_e32 v36, v28, v23                                 ; 2c482f1c
	v_mac_f32_e32 v36, v24, v22                                 ; 2c482d18
	v_mac_f32_e32 v9, v36, v57                                  ; 2c127324
BB163:
	s_mov_b64 exec, -1                                          ; befe01c1
	s_mov_b32 s6, 4                                             ; be860084
	s_nop 0                                                     ; bf800000
	(then repeated 1 times)
BB164:
	s_cmp_ge_u32 s6, s4                                         ; bf090406
	s_cbranch_scc1 BB179                                        ; bf850028
BB166:
	s_add_u32 s9, s16, s6                                       ; 80090610
	s_mul_i32 s9, s9, s3                                        ; 92090309
	s_add_u32 s9, s19, s9                                       ; 80090913
	s_and_b64 s[12:13], vcc, exec                               ; 868c7e6a
	s_mov_b64 exec, s[10:11]                                    ; befe010a
	s_xor_b32 s12, src_scc, 1                                   ; 880c81fd
	s_cbranch_execz BB172                                       ; bf88001b
BB167:
	s_mov_b32 s14, s2                                           ; be8e0002
	s_movk_i32 s15, 0x8000                                      ; b00f8000
	s_load_dwordx4 s[20:23], s[14:15], 0x0                      ; c00a0507 00000000
	v_add_u32_e32 v1, s9, v10                                   ; 68021409
	s_movk_i32 s9, 0xc0                                         ; b00900c0
	v_lshlrev_b32_e32 v4, 1, v1                                 ; 24080281
	v_lshl_add_u32 v4, v1, 4, v4                                ; d1fd0004 04110901
	v_lshl_add_u32 v4, v1, 6, v4                                ; d1fd0004 04110d01
	v_lshl_add_u32 v1, v1, 7, v4                                ; d1fd0001 04110f01
	v_add3_u32 v1, v2, s9, v1                                   ; d1ff0001 04041302
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_load_sbyte v1, v1, s[20:23], 0 offen                 ; e0441000 80050101
	s_lshl_b32 s13, s12, 8                                      ; 8e0d880c
	v_lshl_add_u32 v6, v0, 6, s13                               ; d1fd0006 00350d00
	v_lshl_add_u32 v6, v2, 2, v6                                ; d1fd0006 04190502
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_cvt_f32_i32_e32 v1, v1                                    ; 7e020b01
	ds_write_b32 v6, v1                                         ; d81a0000 00000106
BB172:
	s_mov_b64 exec, -1                                          ; befe01c1
	s_add_u32 s6, s6, 1                                         ; 80068106
	s_cmp_lg_i32 s12, 0                                         ; bf01800c
	s_cselect_b64 vcc, -1, 0                                    ; 85ea80c1
	s_branch BB164                                              ; bf82ffd7
BB178:
	s_mov_b32 s5, src_scc                                       ; be8500fd
BB179:
	s_or_saveexec_b64 s[10:11], -1                              ; be8a21c1
	s_cmp_lg_i32 s5, 0                                          ; bf018005
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
	s_cbranch_scc0 BB188                                        ; bf84004f
BB180:
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
	s_cbranch_scc0 BB186                                        ; bf840034
BB181:
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
	s_cbranch_scc0 BB184                                        ; bf840019
BB182:
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
	v_readlane_b32 s9, v63, 63                                  ; d2890009 00017f3f
	v_mov_b32_e32 v9, s9                                        ; 7e120209
BB184:
	v_mov_b32_e32 v8, s6                                        ; 7e100206
BB186:
	v_mov_b32_e32 v5, s5                                        ; 7e0a0205
BB188:
	v_mov_b32_e32 v3, s3                                        ; 7e060203
BB190:
	s_mov_b64 s[10:11], 1                                       ; be8a0181
	s_and_b64 exec, s[0:1], s[10:11]                            ; 86fe0a00
	s_cbranch_execz BB232                                       ; bf880083
BB191:
	s_bitcmp1_b32 s8, 0                                         ; bf0d8008
	s_cbranch_scc0 BB193                                        ; bf84000e
BB192:
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
	s_branch BB194                                              ; bf820001
BB193:
	s_mov_b32 s1, src_scc                                       ; be8100fd
BB194:
	s_bitcmp1_b32 s8, 1                                         ; bf0d8108
	s_cbranch_scc0 BB196                                        ; bf84000e
BB195:
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
	s_branch BB197                                              ; bf820001
BB196:
	s_mov_b32 s3, src_scc                                       ; be8300fd
BB197:
	s_mov_b32 s0, s3                                            ; be800003
	s_movk_i32 s3, 0x8000                                       ; b0038000
	s_load_dwordx4 s[8:11], s[2:3], 0x20                        ; c00a0201 00000020
	s_mul_i32 s7, s7, s17                                       ; 92071107
	s_add_u32 s7, s7, s16                                       ; 80071007
	s_lshl_b32 s7, s7, 2                                        ; 8e078207
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_store_dword v3, off, s[8:11], s7                     ; e0700000 07020380
	s_cmp_lt_u32 1, s4                                          ; bf0a0481
	s_cbranch_scc0 BB232                                        ; bf840055
BB198:
	s_cmp_lg_i32 s1, 0                                          ; bf018001
	s_cbranch_scc0 BB200                                        ; bf84000a
BB199:
	s_load_dwordx4 s[12:15], s[2:3], 0x30                       ; c00a0301 00000030
	s_mov_b32 s1, src_scc                                       ; be8100fd
	s_add_u32 s5, s7, 4                                         ; 80058407
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s5, s[12:15], s5                        ; c0200146 00000005
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v5, s5, v5                                    ; 020a0a05
	s_branch BB201                                              ; bf820001
BB200:
	s_mov_b32 s1, src_scc                                       ; be8100fd
BB201:
	s_cmp_lg_i32 s0, 0                                          ; bf018000
	s_cbranch_scc0 BB203                                        ; bf84000a
BB202:
	s_load_dwordx4 s[12:15], s[2:3], 0x40                       ; c00a0301 00000040
	s_mov_b32 s0, src_scc                                       ; be8000fd
	s_add_u32 s5, s7, 4                                         ; 80058407
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s5, s[12:15], s5                        ; c0200146 00000005
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v5, s5, v5                                    ; 020a0a05
	s_branch BB204                                              ; bf820001
BB203:
	s_mov_b32 s0, src_scc                                       ; be8000fd
BB204:
	s_add_u32 s5, s7, 4                                         ; 80058407
	buffer_store_dword v5, off, s[8:11], s5                     ; e0700000 05020580
	s_cmp_lt_u32 2, s4                                          ; bf0a0482
	s_cbranch_scc0 BB232                                        ; bf840036
BB205:
	s_cmp_lg_i32 s1, 0                                          ; bf018001
	s_cbranch_scc0 BB207                                        ; bf84000a
BB206:
	s_load_dwordx4 s[12:15], s[2:3], 0x30                       ; c00a0301 00000030
	s_mov_b32 s1, src_scc                                       ; be8100fd
	s_add_u32 s5, s7, 8                                         ; 80058807
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s5, s[12:15], s5                        ; c0200146 00000005
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v8, s5, v8                                    ; 02101005
	s_branch BB208                                              ; bf820001
BB207:
	s_mov_b32 s1, src_scc                                       ; be8100fd
BB208:
	s_cmp_lg_i32 s0, 0                                          ; bf018000
	s_cbranch_scc0 BB210                                        ; bf84000a
BB209:
	s_load_dwordx4 s[12:15], s[2:3], 0x40                       ; c00a0301 00000040
	s_mov_b32 s0, src_scc                                       ; be8000fd
	s_add_u32 s5, s7, 8                                         ; 80058807
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s5, s[12:15], s5                        ; c0200146 00000005
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v8, s5, v8                                    ; 02101005
	s_branch BB211                                              ; bf820001
BB210:
	s_mov_b32 s0, src_scc                                       ; be8000fd
BB211:
	s_add_u32 s5, s7, 8                                         ; 80058807
	buffer_store_dword v8, off, s[8:11], s5                     ; e0700000 05020880
	s_cmp_lt_u32 3, s4                                          ; bf0a0483
	s_cbranch_scc0 BB232                                        ; bf840017
BB212:
	s_cmp_lg_i32 s1, 0                                          ; bf018001
	s_cbranch_scc0 BB215                                        ; bf840008
BB213:
	s_load_dwordx4 s[12:15], s[2:3], 0x30                       ; c00a0301 00000030
	s_add_u32 s1, s7, 12                                        ; 80018c07
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s1, s[12:15], s1                        ; c0200046 00000001
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v9, s1, v9                                    ; 02121201
BB215:
	s_cmp_lg_i32 s0, 0                                          ; bf018000
	s_cbranch_scc0 BB218                                        ; bf840008
BB216:
	s_load_dwordx4 s[0:3], s[2:3], 0x40                         ; c00a0001 00000040
	s_add_u32 s4, s7, 12                                        ; 80048c07
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s4, s[0:3], s4                          ; c0200100 00000004
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v9, s4, v9                                    ; 02121204
BB218:
	s_add_u32 s7, s7, 12                                        ; 80078c07
	buffer_store_dword v9, off, s[8:11], s7                     ; e0700000 07020980
BB232:
	s_endpgm                                                    ; bf810000
