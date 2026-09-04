BB0:
	s_load_dword s0, s[14:15], 0x0                              ; c0020007 00000000
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_mul_i32 s0, s0, s18                                       ; 92001200
	s_add_u32 s16, s16, s0                                      ; 80100010
	s_lshl_b32 s16, s16, 2                                      ; 8e108210
	s_add_u32 s1, s16, 4                                        ; 80018410
	s_cmp_ge_u32 s4, s1                                         ; bf090104
	s_cbranch_scc0 BB42                                         ; bf8402fd
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
	v_mov_b32_e32 v7, 0                                         ; 7e0e0280
	s_mul_i32 s18, s18, s5                                      ; 92120512
	v_mov_b32_e32 v8, 0                                         ; 7e100280
	v_sub_u32_e32 v1, v2, v1                                    ; 6a020302
	v_bfe_u32 v3, v2, 2, 1                                      ; d1c80003 02050502
	v_lshrrev_b32_e32 v2, 3, v2                                 ; 20040483
	v_lshl_add_u32 v1, v1, 1, v3                                ; d1fd0001 040d0301
	v_mov_b32_e32 v3, 0                                         ; 7e060280
	v_lshlrev_b32_e32 v5, 4, v2                                 ; 240a0484
	v_lshlrev_b32_e32 v1, 2, v1                                 ; 24020282
	v_lshl_add_u32 v4, v2, 5, v1                                ; d1fd0004 04050b02
	v_lshl_add_u32 v1, v2, 6, v1                                ; d1fd0001 04050d02
	s_branch BB5                                                ; bf8201b3
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
	v_lshl_add_u32 v29, v2, 1, 8                                ; d1fd001d 02210302
	v_add_u32_e32 v33, 64, v4                                   ; 684208c0
	s_add_u32 s1, s18, s1                                       ; 80010112
	s_add_u32 s4, s16, 1                                        ; 80048110
	v_add_u32_e32 v11, s1, v0                                   ; 68160001
	s_mul_i32 s4, s4, s3                                        ; 92040304
	v_lshlrev_b32_e32 v28, 4, v11                               ; 24381684
	s_add_u32 s4, s18, s4                                       ; 80040412
	s_add_u32 s5, s16, 2                                        ; 80058210
	v_lshl_add_u32 v11, v11, 7, v28                             ; d1fd000b 04710f0b
	v_add_u32_e32 v34, s4, v0                                   ; 68440004
	s_mul_i32 s5, s5, s3                                        ; 92050305
	v_add_u32_e32 v31, 16, v11                                  ; 683e1690
	v_add3_u32 v30, v29, 4, v11                                 ; d1ff001e 042d091d
	v_lshlrev_b32_e32 v35, 4, v34                               ; 24464484
	s_add_u32 s5, s18, s5                                       ; 80050512
	v_add_u32_e32 v32, v31, v4                                  ; 6840091f
	v_add_u32_e32 v31, v31, v33                                 ; 683e431f
	s_add_u32 s9, s16, 3                                        ; 80098310
	v_lshl_add_u32 v34, v34, 7, v35                             ; d1fd0022 048d0f22
	v_add_u32_e32 v39, s5, v0                                   ; 684e0005
	s_mul_i32 s9, s9, s3                                        ; 92090309
	v_add3_u32 v36, v29, 4, v34                                 ; d1ff0024 0489091d
	v_add_u32_e32 v37, 16, v34                                  ; 684a4490
	v_lshlrev_b32_e32 v40, 4, v39                               ; 24504e84
	s_add_u32 s9, s18, s9                                       ; 80090912
	v_add_u32_e32 v38, v37, v4                                  ; 684c0925
	v_add_u32_e32 v37, v37, v33                                 ; 684a4325
	v_lshl_add_u32 v39, v39, 7, v40                             ; d1fd0027 04a10f27
	v_add_u32_e32 v44, s9, v0                                   ; 68580009
	v_add_u32_e32 v42, 16, v39                                  ; 68544e90
	v_add3_u32 v41, v29, 4, v39                                 ; d1ff0029 049d091d
	v_lshlrev_b32_e32 v45, 4, v44                               ; 245a5884
	v_add_u32_e32 v43, v42, v4                                  ; 6856092a
	v_add_u32_e32 v42, v42, v33                                 ; 6854432a
	v_lshl_add_u32 v44, v44, 7, v45                             ; d1fd002c 04b50f2c
	v_add_u32_e32 v46, 16, v44                                  ; 685c5890
	v_add3_u32 v29, v29, 4, v44                                 ; d1ff001d 04b1091d
	v_add_u32_e32 v47, v46, v4                                  ; 685e092e
	v_add_u32_e32 v46, v46, v33                                 ; 685c432e
	buffer_load_dwordx3 v[48:50], v11, s[24:27], 0 offen        ; e0581000 8006300b
	buffer_load_ushort v30, v30, s[24:27], 0 offen              ; e0481000 80061e1e
	buffer_load_dword v32, v32, s[24:27], 0 offen               ; e0501000 80062020
	buffer_load_dword v31, v31, s[24:27], 0 offen               ; e0501000 80061f1f
	buffer_load_dwordx3 v[51:53], v34, s[24:27], 0 offen        ; e0581000 80063322
	buffer_load_ushort v36, v36, s[24:27], 0 offen              ; e0481000 80062424
	buffer_load_dword v38, v38, s[24:27], 0 offen               ; e0501000 80062626
	buffer_load_dword v37, v37, s[24:27], 0 offen               ; e0501000 80062525
	buffer_load_dwordx3 v[54:56], v39, s[24:27], 0 offen        ; e0581000 80063627
	buffer_load_ushort v41, v41, s[24:27], 0 offen              ; e0481000 80062929
	buffer_load_dword v43, v43, s[24:27], 0 offen               ; e0501000 80062b2b
	buffer_load_dword v42, v42, s[24:27], 0 offen               ; e0501000 80062a2a
	buffer_load_dwordx3 v[57:59], v44, s[24:27], 0 offen        ; e0581000 8006392c
	buffer_load_ushort v29, v29, s[24:27], 0 offen              ; e0481000 80061d1d
	buffer_load_dword v47, v47, s[24:27], 0 offen               ; e0501000 80062f2f
	buffer_load_dword v46, v46, s[24:27], 0 offen               ; e0501000 80062e2e
	s_bfm_b32 s10, 16, 16                                       ; 910a9090
	s_mov_b32 s11, 0xf0f0f0f                                    ; be8b00ff 0f0f0f0f
	s_mov_b32 s12, 0xc0c0c0c0                                   ; be8c00ff c0c0c0c0
	s_mov_b32 s13, 0x3f3f3f3f                                   ; be8d00ff 3f3f3f3f
	v_add_u32_e32 v0, 4, v0                                     ; 68000084
	s_waitcnt vmcnt(19)                                         ; bf8c7f73
	v_add_f32_e32 v60, v12, v13                                 ; 02781b0c
	s_waitcnt vmcnt(18)                                         ; bf8c7f72
	v_add_f32_e32 v61, v16, v17                                 ; 027a2310
	s_waitcnt vmcnt(17)                                         ; bf8c7f71
	v_add_f32_e32 v62, v20, v21                                 ; 027c2b14
	v_add_f32_e32 v60, v60, v14                                 ; 02781d3c
	s_waitcnt vmcnt(16)                                         ; bf8c7f70
	v_add_f32_e32 v9, v24, v25                                  ; 02123318
	v_add_f32_e32 v61, v61, v18                                 ; 027a253d
	v_add_f32_e32 v62, v62, v22                                 ; 027c2d3e
	v_add_f32_e32 v60, v60, v15                                 ; 02781f3c
	v_add_f32_e32 v9, v9, v26                                   ; 02123509
	v_add_f32_e32 v61, v61, v19                                 ; 027a273d
	v_add_f32_e32 v62, v62, v23                                 ; 027c2f3e
	v_add_f32_e32 v9, v9, v27                                   ; 02123709
	s_waitcnt vmcnt(15)                                         ; bf8c3f7f
	v_lshrrev_b32_sdwa v50, v5, v50 dst_sel:WORD_1 dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:DWORD ; 206464f9 06060505
	v_cvt_f32_f16_sdwa v34, v48 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e4416f9 00050630
	v_lshrrev_b32_e32 v49, v5, v49                              ; 20626305
	v_cvt_f32_f16_e32 v48, v48                                  ; 7e601730
	s_waitcnt vmcnt(14)                                         ; bf8c3f7e
	v_lshl_or_b32 v30, v30, 12, v30                             ; d200001e 0479191e
	s_waitcnt vmcnt(13)                                         ; bf8c3f7d
	v_and_b32_e32 v39, s11, v32                                 ; 264e400b
	v_bfi_b32 v50, s10, v50, v49                                ; d1ca0032 04c6640a
	v_cvt_f32_ubyte1_e32 v45, v39                               ; 7e5a2527
	v_cvt_f32_ubyte3_e32 v40, v39                               ; 7e502927
	v_cvt_f32_ubyte2_e32 v44, v39                               ; 7e582727
	v_cvt_f32_ubyte0_e32 v39, v39                               ; 7e4e2327
	v_and_b32_e32 v10, s12, v50                                 ; 2614640c
	v_and_b32_e32 v50, s13, v50                                 ; 2664640d
	v_mul_f32_e32 v40, v15, v40                                 ; 0a50510f
	v_lshrrev_b32_e32 v32, 4, v32                               ; 20404084
	v_lshrrev_b32_e32 v10, 2, v10                               ; 20141482
	v_cvt_f32_ubyte3_e32 v11, v50                               ; 7e162932
	v_cvt_f32_ubyte1_e32 v33, v50                               ; 7e422532
	v_cvt_f32_ubyte2_e32 v28, v50                               ; 7e382732
	v_cvt_f32_ubyte0_e32 v50, v50                               ; 7e642332
	v_mac_f32_e32 v40, v14, v44                                 ; 2c50590e
	v_and_b32_e32 v32, s11, v32                                 ; 2640400b
	v_and_or_b32 v30, s11, v30, v10                             ; d201001e 042a3c0b
	s_waitcnt vmcnt(12)                                         ; bf8c3f7c
	v_and_b32_e32 v44, s11, v31                                 ; 26583e0b
	v_mac_f32_e32 v40, v13, v45                                 ; 2c505b0d
	v_cvt_f32_ubyte3_e32 v49, v32                               ; 7e622920
	v_cvt_f32_ubyte2_e32 v10, v32                               ; 7e142720
	v_cvt_f32_ubyte3_e32 v35, v30                               ; 7e46291e
	v_cvt_f32_ubyte3_e32 v45, v44                               ; 7e5a292c
	v_mac_f32_e32 v40, v12, v39                                 ; 2c504f0c
	v_cvt_f32_ubyte1_e32 v39, v32                               ; 7e4e2520
	v_cvt_f32_ubyte0_e32 v32, v32                               ; 7e402320
	v_mul_f32_e32 v49, v19, v49                                 ; 0a626313
	v_mul_f32_e32 v35, v9, v35                                  ; 0a464709
	v_lshrrev_b32_e32 v31, 4, v31                               ; 203e3e84
	v_mul_f32_e32 v45, v23, v45                                 ; 0a5a5b17
	v_mac_f32_e32 v49, v18, v10                                 ; 2c621512
	v_cvt_f32_ubyte2_e32 v10, v44                               ; 7e14272c
	v_and_b32_e32 v31, s11, v31                                 ; 263e3e0b
	v_mac_f32_e32 v49, v17, v39                                 ; 2c624f11
	v_mac_f32_e32 v45, v22, v10                                 ; 2c5a1516
	v_cvt_f32_ubyte1_e32 v10, v31                               ; 7e14251f
	v_cvt_f32_ubyte3_e32 v39, v31                               ; 7e4e291f
	v_mac_f32_e32 v49, v16, v32                                 ; 2c624110
	v_cvt_f32_ubyte1_e32 v32, v44                               ; 7e40252c
	v_cvt_f32_ubyte0_e32 v44, v44                               ; 7e58232c
	v_mul_f32_e32 v39, v27, v39                                 ; 0a4e4f1b
	v_mac_f32_e32 v45, v21, v32                                 ; 2c5a4115
	v_cvt_f32_ubyte1_e32 v32, v30                               ; 7e40251e
	v_mac_f32_e32 v45, v20, v44                                 ; 2c5a5914
	v_cvt_f32_ubyte2_e32 v44, v31                               ; 7e58271f
	v_cvt_f32_ubyte0_e32 v31, v31                               ; 7e3e231f
	s_waitcnt vmcnt(11)                                         ; bf8c3f7b
	v_lshrrev_b32_e32 v52, v5, v52                              ; 20686905
	v_mac_f32_e32 v39, v26, v44                                 ; 2c4e591a
	v_lshrrev_b32_sdwa v53, v5, v53 dst_sel:WORD_1 dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:DWORD ; 206a6af9 06060505
	v_mac_f32_e32 v39, v25, v10                                 ; 2c4e1519
	v_bfi_b32 v53, s10, v53, v52                                ; d1ca0035 04d26a0a
	v_mac_f32_e32 v39, v24, v31                                 ; 2c4e3f18
	v_cvt_f32_ubyte2_e32 v31, v30                               ; 7e3e271e
	v_cvt_f32_ubyte0_e32 v30, v30                               ; 7e3c231e
	v_mul_f32_e32 v39, v39, v32                                 ; 0a4e4127
	v_mac_f32_e32 v35, v62, v31                                 ; 2c463f3e
	v_mac_f32_e32 v39, v45, v30                                 ; 2c4e3d2d
	v_mac_f32_e32 v35, v61, v11                                 ; 2c46173d
	s_waitcnt vmcnt(10)                                         ; bf8c3f7a
	v_lshl_or_b32 v36, v36, 12, v36                             ; d2000024 04911924
	v_mac_f32_e32 v39, v49, v33                                 ; 2c4e4331
	v_and_b32_e32 v33, s12, v53                                 ; 26426a0c
	v_and_b32_e32 v53, s13, v53                                 ; 266a6a0d
	v_mac_f32_e32 v35, v60, v28                                 ; 2c46393c
	v_mac_f32_e32 v39, v40, v50                                 ; 2c4e6528
	v_cvt_f32_f16_sdwa v40, v51 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e5016f9 00050633
	v_cvt_f32_f16_e32 v51, v51                                  ; 7e661733
	v_lshrrev_b32_e32 v33, 2, v33                               ; 20424282
	v_mad_f32 v3, -v34, v35, v3                                 ; d1c10003 240e4722
	v_cvt_f32_ubyte3_e32 v34, v53                               ; 7e442935
	v_cvt_f32_ubyte2_e32 v35, v53                               ; 7e462735
	v_and_or_b32 v36, s11, v36, v33                             ; d2010024 0486480b
	s_waitcnt vmcnt(9)                                          ; bf8c3f79
	v_and_b32_e32 v49, s11, v38                                 ; 26624c0b
	v_mac_f32_e32 v3, v48, v39                                  ; 2c064f30
	v_cvt_f32_ubyte1_e32 v39, v53                               ; 7e4e2535
	v_cvt_f32_ubyte0_e32 v53, v53                               ; 7e6a2335
	v_cvt_f32_ubyte2_e32 v45, v36                               ; 7e5a2724
	v_cvt_f32_ubyte3_e32 v44, v36                               ; 7e582924
	v_cvt_f32_ubyte1_e32 v48, v36                               ; 7e602524
	v_cvt_f32_ubyte0_e32 v36, v36                               ; 7e482324
	v_cvt_f32_ubyte3_e32 v50, v49                               ; 7e642931
	v_cvt_f32_ubyte2_e32 v52, v49                               ; 7e682731
	v_cvt_f32_ubyte1_e32 v10, v49                               ; 7e142531
	v_cvt_f32_ubyte0_e32 v49, v49                               ; 7e622331
	v_lshrrev_b32_e32 v38, 4, v38                               ; 204c4c84
	v_mul_f32_e32 v44, v9, v44                                  ; 0a585909
	v_mul_f32_e32 v50, v15, v50                                 ; 0a64650f
	v_and_b32_e32 v38, s11, v38                                 ; 264c4c0b
	v_mac_f32_e32 v44, v62, v45                                 ; 2c585b3e
	v_mac_f32_e32 v50, v14, v52                                 ; 2c64690e
	s_waitcnt vmcnt(8)                                          ; bf8c3f78
	v_and_b32_e32 v31, s11, v37                                 ; 263e4a0b
	v_cvt_f32_ubyte3_e32 v11, v38                               ; 7e162926
	v_cvt_f32_ubyte2_e32 v28, v38                               ; 7e382726
	v_cvt_f32_ubyte1_e32 v30, v38                               ; 7e3c2526
	v_cvt_f32_ubyte0_e32 v38, v38                               ; 7e4c2326
	v_mac_f32_e32 v44, v61, v34                                 ; 2c58453d
	v_mac_f32_e32 v50, v13, v10                                 ; 2c64150d
	v_cvt_f32_ubyte3_e32 v32, v31                               ; 7e40291f
	v_cvt_f32_ubyte2_e32 v33, v31                               ; 7e42271f
	v_mul_f32_e32 v11, v19, v11                                 ; 0a161713
	v_cvt_f32_ubyte1_e32 v34, v31                               ; 7e44251f
	v_cvt_f32_ubyte0_e32 v31, v31                               ; 7e3e231f
	v_mac_f32_e32 v44, v60, v35                                 ; 2c58473c
	v_lshrrev_b32_e32 v37, 4, v37                               ; 204a4a84
	v_mac_f32_e32 v50, v12, v49                                 ; 2c64630c
	v_mul_f32_e32 v32, v23, v32                                 ; 0a404117
	v_mac_f32_e32 v11, v18, v28                                 ; 2c163912
	v_mad_f32 v6, -v40, v44, v6                                 ; d1c10006 241a5928
	v_and_b32_e32 v37, s11, v37                                 ; 264a4a0b
	v_mac_f32_e32 v32, v22, v33                                 ; 2c404316
	v_mac_f32_e32 v11, v17, v30                                 ; 2c163d11
	v_cvt_f32_ubyte1_e32 v40, v37                               ; 7e502525
	v_cvt_f32_ubyte3_e32 v35, v37                               ; 7e462925
	v_mac_f32_e32 v32, v21, v34                                 ; 2c404515
	s_waitcnt vmcnt(7)                                          ; bf8c3f77
	v_lshrrev_b32_e32 v55, v5, v55                              ; 206e6f05
	v_mac_f32_e32 v11, v16, v38                                 ; 2c164d10
	v_cvt_f32_ubyte2_e32 v38, v37                               ; 7e4c2725
	v_cvt_f32_ubyte0_e32 v37, v37                               ; 7e4a2325
	v_lshrrev_b32_sdwa v56, v5, v56 dst_sel:WORD_1 dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:DWORD ; 207070f9 06060505
	v_mul_f32_e32 v35, v27, v35                                 ; 0a46471b
	v_mac_f32_e32 v32, v20, v31                                 ; 2c403f14
	v_bfi_b32 v56, s10, v56, v55                                ; d1ca0038 04de700a
	v_mac_f32_e32 v35, v26, v38                                 ; 2c464d1a
	v_and_b32_e32 v44, s12, v56                                 ; 2658700c
	v_and_b32_e32 v56, s13, v56                                 ; 2670700d
	s_waitcnt vmcnt(6)                                          ; bf8c3f76
	v_lshl_or_b32 v41, v41, 12, v41                             ; d2000029 04a51929
	v_mac_f32_e32 v35, v25, v40                                 ; 2c465119
	v_lshrrev_b32_e32 v44, 2, v44                               ; 20585882
	v_cvt_f32_ubyte1_e32 v49, v56                               ; 7e622538
	v_cvt_f32_ubyte3_e32 v45, v56                               ; 7e5a2938
	v_mac_f32_e32 v35, v24, v37                                 ; 2c464b18
	v_and_or_b32 v41, s11, v41, v44                             ; d2010029 04b2520b
	v_mul_f32_e32 v35, v35, v48                                 ; 0a466123
	v_cvt_f32_ubyte2_e32 v48, v56                               ; 7e602738
	v_cvt_f32_ubyte0_e32 v56, v56                               ; 7e702338
	v_cvt_f32_ubyte2_e32 v52, v41                               ; 7e682729
	v_mac_f32_e32 v35, v32, v36                                 ; 2c464920
	v_mac_f32_e32 v35, v11, v39                                 ; 2c464f0b
	v_mac_f32_e32 v35, v50, v53                                 ; 2c466b32
	v_cvt_f32_f16_sdwa v50, v54 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e6416f9 00050636
	v_cvt_f32_f16_e32 v54, v54                                  ; 7e6c1736
	s_waitcnt vmcnt(5)                                          ; bf8c3f75
	v_and_b32_e32 v53, s11, v43                                 ; 266a560b
	v_mac_f32_e32 v6, v51, v35                                  ; 2c0c4733
	v_cvt_f32_ubyte3_e32 v51, v41                               ; 7e662929
	v_lshrrev_b32_e32 v43, 4, v43                               ; 20565684
	v_cvt_f32_ubyte2_e32 v10, v53                               ; 7e142735
	v_cvt_f32_ubyte3_e32 v55, v53                               ; 7e6e2935
	v_cvt_f32_ubyte1_e32 v11, v53                               ; 7e162535
	v_cvt_f32_ubyte0_e32 v53, v53                               ; 7e6a2335
	v_mul_f32_e32 v51, v9, v51                                  ; 0a666709
	v_and_b32_e32 v43, s11, v43                                 ; 2656560b
	v_mul_f32_e32 v55, v15, v55                                 ; 0a6e6f0f
	v_mac_f32_e32 v51, v62, v52                                 ; 2c66693e
	s_waitcnt vmcnt(4)                                          ; bf8c3f74
	v_and_b32_e32 v32, s11, v42                                 ; 2640540b
	v_cvt_f32_ubyte2_e32 v30, v43                               ; 7e3c272b
	v_cvt_f32_ubyte3_e32 v28, v43                               ; 7e38292b
	v_cvt_f32_ubyte1_e32 v31, v43                               ; 7e3e252b
	v_cvt_f32_ubyte0_e32 v43, v43                               ; 7e56232b
	v_mac_f32_e32 v55, v14, v10                                 ; 2c6e150e
	v_mac_f32_e32 v51, v61, v45                                 ; 2c665b3d
	v_cvt_f32_ubyte2_e32 v34, v32                               ; 7e442720
	v_cvt_f32_ubyte3_e32 v33, v32                               ; 7e422920
	v_cvt_f32_ubyte1_e32 v35, v32                               ; 7e462520
	v_mul_f32_e32 v28, v19, v28                                 ; 0a383913
	v_cvt_f32_ubyte0_e32 v32, v32                               ; 7e402320
	v_mac_f32_e32 v55, v13, v11                                 ; 2c6e170d
	v_lshrrev_b32_e32 v42, 4, v42                               ; 20545484
	v_mac_f32_e32 v51, v60, v48                                 ; 2c66613c
	v_mul_f32_e32 v33, v23, v33                                 ; 0a424317
	v_mac_f32_e32 v28, v18, v30                                 ; 2c383d12
	v_mac_f32_e32 v55, v12, v53                                 ; 2c6e6b0c
	v_and_b32_e32 v42, s11, v42                                 ; 2654540b
	v_mac_f32_e32 v33, v22, v34                                 ; 2c424516
	v_cvt_f32_ubyte1_e32 v39, v41                               ; 7e4e2529
	v_mac_f32_e32 v28, v17, v31                                 ; 2c383f11
	v_cvt_f32_ubyte0_e32 v41, v41                               ; 7e522329
	v_cvt_f32_ubyte1_e32 v38, v42                               ; 7e4c252a
	v_cvt_f32_ubyte2_e32 v37, v42                               ; 7e4a272a
	v_cvt_f32_ubyte3_e32 v36, v42                               ; 7e48292a
	v_cvt_f32_ubyte0_e32 v42, v42                               ; 7e54232a
	v_mac_f32_e32 v33, v21, v35                                 ; 2c424715
	v_mac_f32_e32 v28, v16, v43                                 ; 2c385710
	v_mad_f32 v7, -v50, v51, v7                                 ; d1c10007 241e6732
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_lshrrev_b32_e32 v58, v5, v58                              ; 20747505
	v_lshrrev_b32_sdwa v59, v5, v59 dst_sel:WORD_1 dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:DWORD ; 207676f9 06060505
	v_mul_f32_e32 v36, v27, v36                                 ; 0a48491b
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_lshl_or_b32 v29, v29, 12, v29                             ; d200001d 0475191d
	v_mac_f32_e32 v33, v20, v32                                 ; 2c424114
	v_bfi_b32 v59, s10, v59, v58                                ; d1ca003b 04ea760a
	v_mac_f32_e32 v36, v26, v37                                 ; 2c484b1a
	v_and_b32_e32 v40, s12, v59                                 ; 2650760c
	v_mac_f32_e32 v36, v25, v38                                 ; 2c484d19
	v_lshrrev_b32_e32 v40, 2, v40                               ; 20505082
	v_mac_f32_e32 v36, v24, v42                                 ; 2c485518
	v_and_or_b32 v29, s11, v29, v40                             ; d201001d 04a23a0b
	v_mul_f32_e32 v36, v36, v39                                 ; 0a484f24
	v_mac_f32_e32 v36, v33, v41                                 ; 2c485321
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v41, s11, v47                                 ; 26525e0b
	v_lshrrev_b32_e32 v47, 4, v47                               ; 205e5e84
	v_mac_f32_e32 v36, v28, v49                                 ; 2c48631c
	v_cvt_f32_ubyte1_e32 v44, v41                               ; 7e582529
	v_cvt_f32_ubyte2_e32 v43, v41                               ; 7e562729
	v_cvt_f32_ubyte3_e32 v42, v41                               ; 7e542929
	v_cvt_f32_ubyte0_e32 v41, v41                               ; 7e522329
	v_and_b32_e32 v47, s11, v47                                 ; 265e5e0b
	v_mac_f32_e32 v36, v55, v56                                 ; 2c487137
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v50, s11, v46                                 ; 26645c0b
	v_mul_f32_e32 v15, v15, v42                                 ; 0a1e550f
	v_cvt_f32_ubyte1_e32 v49, v47                               ; 7e62252f
	v_cvt_f32_ubyte3_e32 v45, v47                               ; 7e5a292f
	v_cvt_f32_ubyte2_e32 v48, v47                               ; 7e60272f
	v_cvt_f32_ubyte0_e32 v47, v47                               ; 7e5e232f
	v_mac_f32_e32 v7, v54, v36                                  ; 2c0e4936
	v_cvt_f32_ubyte2_e32 v52, v50                               ; 7e682732
	v_cvt_f32_ubyte3_e32 v51, v50                               ; 7e662932
	v_cvt_f32_ubyte1_e32 v53, v50                               ; 7e6a2532
	v_mac_f32_e32 v15, v14, v43                                 ; 2c1e570e
	v_mul_f32_e32 v19, v19, v45                                 ; 0a265b13
	v_cvt_f32_ubyte0_e32 v50, v50                               ; 7e642332
	v_lshrrev_b32_e32 v46, 4, v46                               ; 205c5c84
	v_mul_f32_e32 v23, v23, v51                                 ; 0a2e6717
	v_mac_f32_e32 v15, v13, v44                                 ; 2c1e590d
	v_mac_f32_e32 v19, v18, v48                                 ; 2c266112
	v_and_b32_e32 v46, s11, v46                                 ; 265c5c0b
	v_mac_f32_e32 v23, v22, v52                                 ; 2c2e6916
	v_cvt_f32_ubyte3_e32 v58, v29                               ; 7e74291d
	v_mac_f32_e32 v15, v12, v41                                 ; 2c1e530c
	v_mac_f32_e32 v19, v17, v49                                 ; 2c266311
	v_cvt_f32_ubyte3_e32 v54, v46                               ; 7e6c292e
	v_cvt_f32_ubyte2_e32 v55, v46                               ; 7e6e272e
	v_cvt_f32_ubyte1_e32 v56, v46                               ; 7e70252e
	v_cvt_f32_ubyte2_e32 v10, v29                               ; 7e14271d
	v_cvt_f32_ubyte0_e32 v46, v46                               ; 7e5c232e
	v_mac_f32_e32 v23, v21, v53                                 ; 2c2e6b15
	v_mul_f32_e32 v9, v9, v58                                   ; 0a127509
	v_and_b32_e32 v59, s13, v59                                 ; 2676760d
	v_mac_f32_e32 v19, v16, v47                                 ; 2c265f10
	v_mul_f32_e32 v27, v27, v54                                 ; 0a366d1b
	v_cvt_f32_ubyte1_e32 v13, v29                               ; 7e1a251d
	v_cvt_f32_ubyte0_e32 v29, v29                               ; 7e3a231d
	v_mac_f32_e32 v23, v20, v50                                 ; 2c2e6514
	v_mac_f32_e32 v9, v62, v10                                  ; 2c12153e
	v_cvt_f32_ubyte3_e32 v11, v59                               ; 7e16293b
	v_cvt_f32_ubyte1_e32 v14, v59                               ; 7e1c253b
	v_cvt_f32_ubyte2_e32 v12, v59                               ; 7e18273b
	v_cvt_f32_ubyte0_e32 v59, v59                               ; 7e76233b
	v_mac_f32_e32 v27, v26, v55                                 ; 2c366f1a
	v_mac_f32_e32 v9, v61, v11                                  ; 2c12173d
	v_mac_f32_e32 v27, v25, v56                                 ; 2c367119
	v_mac_f32_e32 v9, v60, v12                                  ; 2c12193c
	v_mac_f32_e32 v27, v24, v46                                 ; 2c365d18
	v_mul_f32_e32 v27, v27, v13                                 ; 0a361b1b
	v_mac_f32_e32 v27, v23, v29                                 ; 2c363b17
	v_mac_f32_e32 v27, v19, v14                                 ; 2c361d13
	v_mac_f32_e32 v27, v15, v59                                 ; 2c36770f
	v_cvt_f32_f16_sdwa v15, v57 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e1e16f9 00050639
	v_cvt_f32_f16_e32 v57, v57                                  ; 7e721739
	v_mad_f32 v8, -v15, v9, v8                                  ; d1c10008 2422130f
	v_mac_f32_e32 v8, v57, v27                                  ; 2c103739
BB5:
	s_mov_b64 s[0:1], exec                                      ; be80017e
	v_cmpx_le_u32_e32 vcc, s3, v0                               ; 7db60003
BB6:
	s_andn2_b64 s[0:1], s[0:1], exec                            ; 89807e00
	s_cbranch_scc1 BB10                                         ; bf85fe49
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
	s_branch BB119                                              ; bf820324
BB42:
	s_cmp_lt_u32 s16, s4                                        ; bf0a0410
	s_cbranch_scc0 BB119                                        ; bf840322
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
	v_mov_b32_e32 v7, 0                                         ; 7e0e0280
	s_mul_i32 s19, s19, s5                                      ; 92130513
	v_mov_b32_e32 v8, 0                                         ; 7e100280
	v_sub_u32_e32 v1, v2, v1                                    ; 6a020302
	v_bfe_u32 v3, v2, 2, 1                                      ; d1c80003 02050502
	v_lshrrev_b32_e32 v2, 3, v2                                 ; 20040483
	v_lshl_add_u32 v1, v1, 1, v3                                ; d1fd0001 040d0301
	v_mov_b32_e32 v3, 0                                         ; 7e060280
	v_lshlrev_b32_e32 v5, 4, v2                                 ; 240a0484
	v_lshlrev_b32_e32 v1, 2, v1                                 ; 24020282
	v_lshl_add_u32 v4, v2, 5, v1                                ; d1fd0004 04050b02
	v_lshl_add_u32 v1, v2, 6, v1                                ; d1fd0001 04050d02
BB47:
	s_mov_b64 s[0:1], exec                                      ; be80017e
	v_cmpx_le_u32_e32 vcc, s3, v0                               ; 7db60003
BB48:
	s_andn2_b64 s[0:1], s[0:1], exec                            ; 89807e00
	s_cbranch_scc0 BB65                                         ; bf8401cc
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
	s_cbranch_scc0 BB64                                         ; bf84019f
BB53:
	s_load_dwordx4 s[12:15], s[0:1], 0x0                        ; c00a0300 00000000
	s_mul_i32 s0, s16, s3                                       ; 92000310
	v_lshl_add_u32 v31, v2, 1, 8                                ; d1fd001f 02210302
	v_add_u32_e32 v35, 64, v4                                   ; 684608c0
	s_add_u32 s0, s19, s0                                       ; 80000013
	v_add_u32_e32 v9, s0, v0                                    ; 68120000
	v_lshlrev_b32_e32 v10, 4, v9                                ; 24141284
	v_lshl_add_u32 v9, v9, 7, v10                               ; d1fd0009 04290f09
	v_add3_u32 v32, v31, 4, v9                                  ; d1ff0020 0425091f
	v_add_u32_e32 v33, 16, v9                                   ; 68421290
	v_add_u32_e32 v34, v33, v4                                  ; 68440921
	v_add_u32_e32 v33, v33, v35                                 ; 68424721
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_load_dwordx3 v[36:38], v9, s[12:15], 0 offen         ; e0581000 80032409
	buffer_load_ushort v32, v32, s[12:15], 0 offen              ; e0481000 80032020
	buffer_load_dword v34, v34, s[12:15], 0 offen               ; e0501000 80032222
	buffer_load_dword v33, v33, s[12:15], 0 offen               ; e0501000 80032121
	s_bfm_b32 s1, 16, 16                                        ; 91019090
	s_mov_b32 s5, 0xf0f0f0f                                     ; be8500ff 0f0f0f0f
	s_cmp_lt_u32 1, s4                                          ; bf0a0481
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_lshrrev_b32_sdwa v38, v5, v38 dst_sel:WORD_1 dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:DWORD ; 204c4cf9 06060505
	v_lshrrev_b32_e32 v37, v5, v37                              ; 204a4b05
	v_cvt_f32_f16_sdwa v43, v36 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e5616f9 00050624
	v_cvt_f32_f16_e32 v36, v36                                  ; 7e481724
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_lshl_or_b32 v32, v32, 12, v32                             ; d2000020 04811920
	v_bfi_b32 v38, s1, v38, v37                                 ; d1ca0026 04964c01
	v_and_b32_e32 v39, 0xc0c0c0c0, v38                          ; 264e4cff c0c0c0c0
	v_and_b32_e32 v38, 0x3f3f3f3f, v38                          ; 264c4cff 3f3f3f3f
	v_lshrrev_b32_e32 v39, 2, v39                               ; 204e4e82
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v47, s5, v34                                  ; 265e4405
	v_cvt_f32_ubyte3_e32 v40, v38                               ; 7e502926
	v_cvt_f32_ubyte2_e32 v41, v38                               ; 7e522726
	v_cvt_f32_ubyte1_e32 v42, v38                               ; 7e542526
	v_cvt_f32_ubyte0_e32 v38, v38                               ; 7e4c2326
	v_and_or_b32 v32, s5, v32, v39                              ; d2010020 049e4005
	v_cvt_f32_ubyte3_e32 v48, v47                               ; 7e60292f
	v_cvt_f32_ubyte2_e32 v49, v47                               ; 7e62272f
	v_cvt_f32_ubyte1_e32 v50, v47                               ; 7e64252f
	v_cvt_f32_ubyte0_e32 v47, v47                               ; 7e5e232f
	v_cvt_f32_ubyte3_e32 v44, v32                               ; 7e582920
	v_cvt_f32_ubyte2_e32 v45, v32                               ; 7e5a2720
	v_cvt_f32_ubyte1_e32 v46, v32                               ; 7e5c2520
	v_cvt_f32_ubyte0_e32 v32, v32                               ; 7e402320
	v_mul_f32_e32 v48, v15, v48                                 ; 0a60610f
	v_lshrrev_b32_e32 v34, 4, v34                               ; 20444484
	v_mul_f32_e32 v44, v30, v44                                 ; 0a58591e
	v_mac_f32_e32 v48, v14, v49                                 ; 2c60630e
	v_and_b32_e32 v34, s5, v34                                  ; 26444405
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v54, s5, v33                                  ; 266c4205
	v_mac_f32_e32 v44, v29, v45                                 ; 2c585b1d
	v_mac_f32_e32 v48, v13, v50                                 ; 2c60650d
	v_cvt_f32_ubyte3_e32 v51, v34                               ; 7e662922
	v_cvt_f32_ubyte2_e32 v52, v34                               ; 7e682722
	v_cvt_f32_ubyte1_e32 v53, v34                               ; 7e6a2522
	v_cvt_f32_ubyte0_e32 v34, v34                               ; 7e442322
	v_cvt_f32_ubyte2_e32 v56, v54                               ; 7e702736
	v_cvt_f32_ubyte3_e32 v55, v54                               ; 7e6e2936
	v_mac_f32_e32 v44, v28, v40                                 ; 2c58511c
	v_cvt_f32_ubyte1_e32 v57, v54                               ; 7e722536
	v_mac_f32_e32 v48, v12, v47                                 ; 2c605f0c
	v_mul_f32_e32 v51, v19, v51                                 ; 0a666713
	v_cvt_f32_ubyte0_e32 v54, v54                               ; 7e6c2336
	v_lshrrev_b32_e32 v33, 4, v33                               ; 20424284
	v_mul_f32_e32 v55, v23, v55                                 ; 0a6e6f17
	v_mac_f32_e32 v44, v11, v41                                 ; 2c58530b
	v_mac_f32_e32 v51, v18, v52                                 ; 2c666912
	v_and_b32_e32 v33, s5, v33                                  ; 26424205
	v_mac_f32_e32 v55, v22, v56                                 ; 2c6e7116
	v_mad_f32 v3, -v43, v44, v3                                 ; d1c10003 240e592b
	v_mac_f32_e32 v51, v17, v53                                 ; 2c666b11
	v_cvt_f32_ubyte1_e32 v60, v33                               ; 7e782521
	v_cvt_f32_ubyte2_e32 v59, v33                               ; 7e762721
	v_cvt_f32_ubyte3_e32 v58, v33                               ; 7e742921
	v_cvt_f32_ubyte0_e32 v33, v33                               ; 7e422321
	v_mac_f32_e32 v55, v21, v57                                 ; 2c6e7315
	v_mac_f32_e32 v51, v16, v34                                 ; 2c664510
	v_mul_f32_e32 v58, v27, v58                                 ; 0a74751b
	v_mac_f32_e32 v55, v20, v54                                 ; 2c6e6d14
	v_mac_f32_e32 v58, v26, v59                                 ; 2c74771a
	v_mac_f32_e32 v58, v25, v60                                 ; 2c747919
	v_mac_f32_e32 v58, v24, v33                                 ; 2c744318
	v_mul_f32_e32 v58, v58, v46                                 ; 0a745d3a
	v_mac_f32_e32 v58, v55, v32                                 ; 2c744137
	v_mac_f32_e32 v58, v51, v42                                 ; 2c745533
	v_mac_f32_e32 v58, v48, v38                                 ; 2c744d30
	v_mac_f32_e32 v3, v36, v58                                  ; 2c067524
	s_cbranch_scc0 BB64                                         ; bf840133
BB54:
	s_add_u32 s0, s16, 1                                        ; 80008110
	s_mul_i32 s0, s0, s3                                        ; 92000300
	s_add_u32 s0, s19, s0                                       ; 80000013
	v_add_u32_e32 v9, s0, v0                                    ; 68120000
	v_lshlrev_b32_e32 v10, 4, v9                                ; 24141284
	v_lshl_add_u32 v9, v9, 7, v10                               ; d1fd0009 04290f09
	v_add3_u32 v32, v31, 4, v9                                  ; d1ff0020 0425091f
	v_add_u32_e32 v33, 16, v9                                   ; 68421290
	v_add_u32_e32 v34, v33, v4                                  ; 68440921
	v_add_u32_e32 v33, v33, v35                                 ; 68424721
	buffer_load_dwordx3 v[36:38], v9, s[12:15], 0 offen         ; e0581000 80032409
	buffer_load_ushort v32, v32, s[12:15], 0 offen              ; e0481000 80032020
	buffer_load_dword v34, v34, s[12:15], 0 offen               ; e0501000 80032222
	buffer_load_dword v33, v33, s[12:15], 0 offen               ; e0501000 80032121
	s_bfm_b32 s1, 16, 16                                        ; 91019090
	s_mov_b32 s5, 0xf0f0f0f                                     ; be8500ff 0f0f0f0f
	s_cmp_lt_u32 2, s4                                          ; bf0a0482
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_lshrrev_b32_e32 v37, v5, v37                              ; 204a4b05
	v_lshrrev_b32_sdwa v38, v5, v38 dst_sel:WORD_1 dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:DWORD ; 204c4cf9 06060505
	v_cvt_f32_f16_sdwa v43, v36 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e5616f9 00050624
	v_cvt_f32_f16_e32 v36, v36                                  ; 7e481724
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_lshl_or_b32 v32, v32, 12, v32                             ; d2000020 04811920
	v_bfi_b32 v38, s1, v38, v37                                 ; d1ca0026 04964c01
	v_and_b32_e32 v39, 0xc0c0c0c0, v38                          ; 264e4cff c0c0c0c0
	v_and_b32_e32 v38, 0x3f3f3f3f, v38                          ; 264c4cff 3f3f3f3f
	v_lshrrev_b32_e32 v39, 2, v39                               ; 204e4e82
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v47, s5, v34                                  ; 265e4405
	v_cvt_f32_ubyte3_e32 v40, v38                               ; 7e502926
	v_cvt_f32_ubyte2_e32 v41, v38                               ; 7e522726
	v_cvt_f32_ubyte1_e32 v42, v38                               ; 7e542526
	v_cvt_f32_ubyte0_e32 v38, v38                               ; 7e4c2326
	v_and_or_b32 v32, s5, v32, v39                              ; d2010020 049e4005
	v_cvt_f32_ubyte3_e32 v48, v47                               ; 7e60292f
	v_cvt_f32_ubyte2_e32 v49, v47                               ; 7e62272f
	v_cvt_f32_ubyte1_e32 v50, v47                               ; 7e64252f
	v_cvt_f32_ubyte0_e32 v47, v47                               ; 7e5e232f
	v_cvt_f32_ubyte2_e32 v45, v32                               ; 7e5a2720
	v_cvt_f32_ubyte1_e32 v46, v32                               ; 7e5c2520
	v_cvt_f32_ubyte3_e32 v44, v32                               ; 7e582920
	v_cvt_f32_ubyte0_e32 v32, v32                               ; 7e402320
	v_mul_f32_e32 v48, v15, v48                                 ; 0a60610f
	v_lshrrev_b32_e32 v34, 4, v34                               ; 20444484
	v_mul_f32_e32 v44, v30, v44                                 ; 0a58591e
	v_mac_f32_e32 v48, v14, v49                                 ; 2c60630e
	v_and_b32_e32 v34, s5, v34                                  ; 26444405
	v_mac_f32_e32 v44, v29, v45                                 ; 2c585b1d
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v54, s5, v33                                  ; 266c4205
	v_mac_f32_e32 v48, v13, v50                                 ; 2c60650d
	v_cvt_f32_ubyte1_e32 v53, v34                               ; 7e6a2522
	v_cvt_f32_ubyte2_e32 v52, v34                               ; 7e682722
	v_cvt_f32_ubyte3_e32 v51, v34                               ; 7e662922
	v_cvt_f32_ubyte0_e32 v34, v34                               ; 7e442322
	v_mac_f32_e32 v44, v28, v40                                 ; 2c58511c
	v_cvt_f32_ubyte2_e32 v56, v54                               ; 7e702736
	v_cvt_f32_ubyte3_e32 v55, v54                               ; 7e6e2936
	v_cvt_f32_ubyte1_e32 v57, v54                               ; 7e722536
	v_mac_f32_e32 v48, v12, v47                                 ; 2c605f0c
	v_cvt_f32_ubyte0_e32 v54, v54                               ; 7e6c2336
	v_mul_f32_e32 v51, v19, v51                                 ; 0a666713
	v_lshrrev_b32_e32 v33, 4, v33                               ; 20424284
	v_mac_f32_e32 v44, v11, v41                                 ; 2c58530b
	v_mul_f32_e32 v55, v23, v55                                 ; 0a6e6f17
	v_mac_f32_e32 v51, v18, v52                                 ; 2c666912
	v_and_b32_e32 v33, s5, v33                                  ; 26424205
	v_mad_f32 v6, -v43, v44, v6                                 ; d1c10006 241a592b
	v_mac_f32_e32 v55, v22, v56                                 ; 2c6e7116
	v_mac_f32_e32 v51, v17, v53                                 ; 2c666b11
	v_cvt_f32_ubyte1_e32 v60, v33                               ; 7e782521
	v_cvt_f32_ubyte2_e32 v59, v33                               ; 7e762721
	v_cvt_f32_ubyte3_e32 v58, v33                               ; 7e742921
	v_cvt_f32_ubyte0_e32 v33, v33                               ; 7e422321
	v_mac_f32_e32 v55, v21, v57                                 ; 2c6e7315
	v_mac_f32_e32 v51, v16, v34                                 ; 2c664510
	v_mul_f32_e32 v58, v27, v58                                 ; 0a74751b
	v_mac_f32_e32 v55, v20, v54                                 ; 2c6e6d14
	v_mac_f32_e32 v58, v26, v59                                 ; 2c74771a
	v_mac_f32_e32 v58, v25, v60                                 ; 2c747919
	v_mac_f32_e32 v58, v24, v33                                 ; 2c744318
	v_mul_f32_e32 v58, v58, v46                                 ; 0a745d3a
	v_mac_f32_e32 v58, v55, v32                                 ; 2c744137
	v_mac_f32_e32 v58, v51, v42                                 ; 2c745533
	v_mac_f32_e32 v58, v48, v38                                 ; 2c744d30
	v_mac_f32_e32 v6, v36, v58                                  ; 2c0c7524
	s_cbranch_scc0 BB64                                         ; bf8400cc
BB55:
	s_add_u32 s0, s16, 2                                        ; 80008210
	s_mul_i32 s0, s0, s3                                        ; 92000300
	s_add_u32 s0, s19, s0                                       ; 80000013
	v_add_u32_e32 v9, s0, v0                                    ; 68120000
	v_lshlrev_b32_e32 v10, 4, v9                                ; 24141284
	v_lshl_add_u32 v9, v9, 7, v10                               ; d1fd0009 04290f09
	v_add3_u32 v32, v31, 4, v9                                  ; d1ff0020 0425091f
	v_add_u32_e32 v33, 16, v9                                   ; 68421290
	v_add_u32_e32 v34, v33, v4                                  ; 68440921
	v_add_u32_e32 v33, v33, v35                                 ; 68424721
	buffer_load_dwordx3 v[36:38], v9, s[12:15], 0 offen         ; e0581000 80032409
	buffer_load_ushort v32, v32, s[12:15], 0 offen              ; e0481000 80032020
	buffer_load_dword v34, v34, s[12:15], 0 offen               ; e0501000 80032222
	buffer_load_dword v33, v33, s[12:15], 0 offen               ; e0501000 80032121
	s_bfm_b32 s1, 16, 16                                        ; 91019090
	s_mov_b32 s5, 0xf0f0f0f                                     ; be8500ff 0f0f0f0f
	s_cmp_lt_u32 3, s4                                          ; bf0a0483
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_lshrrev_b32_e32 v37, v5, v37                              ; 204a4b05
	v_lshrrev_b32_sdwa v38, v5, v38 dst_sel:WORD_1 dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:DWORD ; 204c4cf9 06060505
	v_cvt_f32_f16_sdwa v43, v36 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e5616f9 00050624
	v_cvt_f32_f16_e32 v36, v36                                  ; 7e481724
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_lshl_or_b32 v32, v32, 12, v32                             ; d2000020 04811920
	v_bfi_b32 v38, s1, v38, v37                                 ; d1ca0026 04964c01
	v_and_b32_e32 v39, 0xc0c0c0c0, v38                          ; 264e4cff c0c0c0c0
	v_and_b32_e32 v38, 0x3f3f3f3f, v38                          ; 264c4cff 3f3f3f3f
	v_lshrrev_b32_e32 v39, 2, v39                               ; 204e4e82
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v47, s5, v34                                  ; 265e4405
	v_cvt_f32_ubyte3_e32 v40, v38                               ; 7e502926
	v_cvt_f32_ubyte2_e32 v41, v38                               ; 7e522726
	v_cvt_f32_ubyte1_e32 v42, v38                               ; 7e542526
	v_cvt_f32_ubyte0_e32 v38, v38                               ; 7e4c2326
	v_and_or_b32 v32, s5, v32, v39                              ; d2010020 049e4005
	v_cvt_f32_ubyte3_e32 v48, v47                               ; 7e60292f
	v_cvt_f32_ubyte2_e32 v49, v47                               ; 7e62272f
	v_cvt_f32_ubyte1_e32 v50, v47                               ; 7e64252f
	v_cvt_f32_ubyte0_e32 v47, v47                               ; 7e5e232f
	v_cvt_f32_ubyte2_e32 v45, v32                               ; 7e5a2720
	v_cvt_f32_ubyte1_e32 v46, v32                               ; 7e5c2520
	v_cvt_f32_ubyte3_e32 v44, v32                               ; 7e582920
	v_cvt_f32_ubyte0_e32 v32, v32                               ; 7e402320
	v_mul_f32_e32 v48, v15, v48                                 ; 0a60610f
	v_lshrrev_b32_e32 v34, 4, v34                               ; 20444484
	v_mul_f32_e32 v44, v30, v44                                 ; 0a58591e
	v_mac_f32_e32 v48, v14, v49                                 ; 2c60630e
	v_and_b32_e32 v34, s5, v34                                  ; 26444405
	v_mac_f32_e32 v44, v29, v45                                 ; 2c585b1d
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v54, s5, v33                                  ; 266c4205
	v_mac_f32_e32 v48, v13, v50                                 ; 2c60650d
	v_cvt_f32_ubyte1_e32 v53, v34                               ; 7e6a2522
	v_cvt_f32_ubyte2_e32 v52, v34                               ; 7e682722
	v_cvt_f32_ubyte3_e32 v51, v34                               ; 7e662922
	v_cvt_f32_ubyte0_e32 v34, v34                               ; 7e442322
	v_mac_f32_e32 v44, v28, v40                                 ; 2c58511c
	v_cvt_f32_ubyte2_e32 v56, v54                               ; 7e702736
	v_cvt_f32_ubyte3_e32 v55, v54                               ; 7e6e2936
	v_cvt_f32_ubyte1_e32 v57, v54                               ; 7e722536
	v_mac_f32_e32 v48, v12, v47                                 ; 2c605f0c
	v_cvt_f32_ubyte0_e32 v54, v54                               ; 7e6c2336
	v_mul_f32_e32 v51, v19, v51                                 ; 0a666713
	v_lshrrev_b32_e32 v33, 4, v33                               ; 20424284
	v_mac_f32_e32 v44, v11, v41                                 ; 2c58530b
	v_mul_f32_e32 v55, v23, v55                                 ; 0a6e6f17
	v_mac_f32_e32 v51, v18, v52                                 ; 2c666912
	v_and_b32_e32 v33, s5, v33                                  ; 26424205
	v_mad_f32 v7, -v43, v44, v7                                 ; d1c10007 241e592b
	v_mac_f32_e32 v55, v22, v56                                 ; 2c6e7116
	v_mac_f32_e32 v51, v17, v53                                 ; 2c666b11
	v_cvt_f32_ubyte1_e32 v60, v33                               ; 7e782521
	v_cvt_f32_ubyte2_e32 v59, v33                               ; 7e762721
	v_cvt_f32_ubyte3_e32 v58, v33                               ; 7e742921
	v_cvt_f32_ubyte0_e32 v33, v33                               ; 7e422321
	v_mac_f32_e32 v55, v21, v57                                 ; 2c6e7315
	v_mac_f32_e32 v51, v16, v34                                 ; 2c664510
	v_mul_f32_e32 v58, v27, v58                                 ; 0a74751b
	v_mac_f32_e32 v55, v20, v54                                 ; 2c6e6d14
	v_mac_f32_e32 v58, v26, v59                                 ; 2c74771a
	v_mac_f32_e32 v58, v25, v60                                 ; 2c747919
	v_mac_f32_e32 v58, v24, v33                                 ; 2c744318
	v_mul_f32_e32 v58, v58, v46                                 ; 0a745d3a
	v_mac_f32_e32 v58, v55, v32                                 ; 2c744137
	v_mac_f32_e32 v58, v51, v42                                 ; 2c745533
	v_mac_f32_e32 v58, v48, v38                                 ; 2c744d30
	v_mac_f32_e32 v7, v36, v58                                  ; 2c0e7524
	s_cbranch_scc0 BB64                                         ; bf840065
BB56:
	s_add_u32 s0, s16, 3                                        ; 80008310
	s_mul_i32 s0, s0, s3                                        ; 92000300
	s_add_u32 s0, s19, s0                                       ; 80000013
	v_add_u32_e32 v9, s0, v0                                    ; 68120000
	v_lshlrev_b32_e32 v10, 4, v9                                ; 24141284
	v_lshl_add_u32 v9, v9, 7, v10                               ; d1fd0009 04290f09
	v_add3_u32 v31, v31, 4, v9                                  ; d1ff001f 0425091f
	v_add_u32_e32 v32, 16, v9                                   ; 68401290
	v_add_u32_e32 v33, v32, v4                                  ; 68420920
	v_add_u32_e32 v32, v32, v35                                 ; 68404720
	buffer_load_dwordx3 v[34:36], v9, s[12:15], 0 offen         ; e0581000 80032209
	buffer_load_ushort v31, v31, s[12:15], 0 offen              ; e0481000 80031f1f
	buffer_load_dword v33, v33, s[12:15], 0 offen               ; e0501000 80032121
	buffer_load_dword v32, v32, s[12:15], 0 offen               ; e0501000 80032020
	s_bfm_b32 s1, 16, 16                                        ; 91019090
	s_mov_b32 s5, 0xf0f0f0f                                     ; be8500ff 0f0f0f0f
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_lshrrev_b32_e32 v35, v5, v35                              ; 20464705
	v_lshrrev_b32_sdwa v36, v5, v36 dst_sel:WORD_1 dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:DWORD ; 204848f9 06060505
	v_cvt_f32_f16_sdwa v41, v34 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e5216f9 00050622
	v_cvt_f32_f16_e32 v34, v34                                  ; 7e441722
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_lshl_or_b32 v31, v31, 12, v31                             ; d200001f 047d191f
	v_bfi_b32 v36, s1, v36, v35                                 ; d1ca0024 048e4801
	v_and_b32_e32 v37, 0xc0c0c0c0, v36                          ; 264a48ff c0c0c0c0
	v_and_b32_e32 v36, 0x3f3f3f3f, v36                          ; 264848ff 3f3f3f3f
	v_lshrrev_b32_e32 v37, 2, v37                               ; 204a4a82
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v45, s5, v33                                  ; 265a4205
	v_cvt_f32_ubyte3_e32 v38, v36                               ; 7e4c2924
	v_cvt_f32_ubyte2_e32 v39, v36                               ; 7e4e2724
	v_cvt_f32_ubyte1_e32 v40, v36                               ; 7e502524
	v_cvt_f32_ubyte0_e32 v36, v36                               ; 7e482324
	v_and_or_b32 v31, s5, v31, v37                              ; d201001f 04963e05
	v_cvt_f32_ubyte3_e32 v46, v45                               ; 7e5c292d
	v_cvt_f32_ubyte2_e32 v47, v45                               ; 7e5e272d
	v_cvt_f32_ubyte1_e32 v48, v45                               ; 7e60252d
	v_cvt_f32_ubyte0_e32 v45, v45                               ; 7e5a232d
	v_cvt_f32_ubyte2_e32 v43, v31                               ; 7e56271f
	v_cvt_f32_ubyte1_e32 v44, v31                               ; 7e58251f
	v_cvt_f32_ubyte3_e32 v42, v31                               ; 7e54291f
	v_cvt_f32_ubyte0_e32 v31, v31                               ; 7e3e231f
	v_mul_f32_e32 v15, v15, v46                                 ; 0a1e5d0f
	v_lshrrev_b32_e32 v33, 4, v33                               ; 20424284
	v_mul_f32_e32 v30, v30, v42                                 ; 0a3c551e
	v_mac_f32_e32 v15, v14, v47                                 ; 2c1e5f0e
	v_and_b32_e32 v33, s5, v33                                  ; 26424205
	v_mac_f32_e32 v30, v29, v43                                 ; 2c3c571d
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v52, s5, v32                                  ; 26684005
	v_mac_f32_e32 v15, v13, v48                                 ; 2c1e610d
	v_cvt_f32_ubyte1_e32 v51, v33                               ; 7e662521
	v_cvt_f32_ubyte2_e32 v50, v33                               ; 7e642721
	v_cvt_f32_ubyte3_e32 v49, v33                               ; 7e622921
	v_cvt_f32_ubyte0_e32 v33, v33                               ; 7e422321
	v_mac_f32_e32 v30, v28, v38                                 ; 2c3c4d1c
	v_cvt_f32_ubyte2_e32 v54, v52                               ; 7e6c2734
	v_cvt_f32_ubyte3_e32 v53, v52                               ; 7e6a2934
	v_cvt_f32_ubyte1_e32 v55, v52                               ; 7e6e2534
	v_mac_f32_e32 v15, v12, v45                                 ; 2c1e5b0c
	v_cvt_f32_ubyte0_e32 v52, v52                               ; 7e682334
	v_mul_f32_e32 v19, v19, v49                                 ; 0a266313
	v_lshrrev_b32_e32 v32, 4, v32                               ; 20404084
	v_mac_f32_e32 v30, v11, v39                                 ; 2c3c4f0b
	v_mul_f32_e32 v23, v23, v53                                 ; 0a2e6b17
	v_mac_f32_e32 v19, v18, v50                                 ; 2c266512
	v_and_b32_e32 v32, s5, v32                                  ; 26404005
	v_mad_f32 v8, -v41, v30, v8                                 ; d1c10008 24223d29
	v_mac_f32_e32 v23, v22, v54                                 ; 2c2e6d16
	v_mac_f32_e32 v19, v17, v51                                 ; 2c266711
	v_cvt_f32_ubyte1_e32 v58, v32                               ; 7e742520
	v_cvt_f32_ubyte2_e32 v57, v32                               ; 7e722720
	v_cvt_f32_ubyte3_e32 v56, v32                               ; 7e702920
	v_cvt_f32_ubyte0_e32 v32, v32                               ; 7e402320
	v_mac_f32_e32 v23, v21, v55                                 ; 2c2e6f15
	v_mac_f32_e32 v19, v16, v33                                 ; 2c264310
	v_mul_f32_e32 v27, v27, v56                                 ; 0a36711b
	v_mac_f32_e32 v23, v20, v52                                 ; 2c2e6914
	v_mac_f32_e32 v27, v26, v57                                 ; 2c36731a
	v_mac_f32_e32 v27, v25, v58                                 ; 2c367519
	v_mac_f32_e32 v27, v24, v32                                 ; 2c364118
	v_mul_f32_e32 v27, v27, v44                                 ; 0a36591b
	v_mac_f32_e32 v27, v23, v31                                 ; 2c363f17
	v_mac_f32_e32 v27, v19, v40                                 ; 2c365113
	v_mac_f32_e32 v27, v15, v36                                 ; 2c36490f
	v_mac_f32_e32 v8, v34, v27                                  ; 2c103722
BB64:
	v_add_u32_e32 v0, 4, v0                                     ; 68000084
	s_branch BB47                                               ; bf82fe30
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
