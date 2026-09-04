BB0:
	s_load_dword s0, s[14:15], 0x0                              ; c0020007 00000000
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_mul_i32 s0, s0, s18                                       ; 92001200
	s_add_u32 s16, s16, s0                                      ; 80100010
	s_lshl_b32 s16, s16, 3                                      ; 8e108310
	s_add_u32 s1, s16, 8                                        ; 80018810
	s_cmp_ge_u32 s4, s1                                         ; bf090104
	s_cbranch_scc0 BB66                                         ; bf84055b
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
	v_mov_b32_e32 v9, 0                                         ; 7e120280
	v_sub_u32_e32 v1, v2, v1                                    ; 6a020302
	v_bfe_u32 v3, v2, 2, 1                                      ; d1c80003 02050502
	v_lshrrev_b32_e32 v2, 3, v2                                 ; 20040483
	v_mov_b32_e32 v10, 0                                        ; 7e140280
	v_mov_b32_e32 v11, 0                                        ; 7e160280
	v_mov_b32_e32 v12, 0                                        ; 7e180280
	v_lshl_add_u32 v1, v1, 1, v3                                ; d1fd0001 040d0301
	v_mov_b32_e32 v3, 0                                         ; 7e060280
	v_lshlrev_b32_e32 v5, 4, v2                                 ; 240a0484
	v_lshlrev_b32_e32 v1, 2, v1                                 ; 24020282
	v_lshl_add_u32 v4, v2, 5, v1                                ; d1fd0004 04050b02
	v_lshl_add_u32 v1, v2, 6, v1                                ; d1fd0001 04050d02
	s_branch BB5                                                ; bf820331
	s_nop 0                                                     ; bf800000
	(then repeated 4 times)
BB10:
	s_mov_b64 exec, s[0:1]                                      ; befe0100
	s_mov_b32 s0, s2                                            ; be800002
	s_movk_i32 s1, 0x8000                                       ; b0018000
	s_load_dwordx8 s[24:31], s[0:1], 0x0                        ; c00e0600 00000000
	s_mul_i32 s0, s6, s17                                       ; 92001106
	v_lshl_add_u32 v13, v0, 8, v1                               ; d1fd000d 04051100
	v_add_u32_e32 v14, s0, v13                                  ; 681c1a00
	v_add_u32_e32 v13, 0x80, v13                                ; 681a1aff 00000080
	v_lshrrev_b32_e32 v14, 2, v14                               ; 201c1c82
	v_add_u32_e32 v13, s0, v13                                  ; 681a1a00
	v_lshlrev_b32_e32 v14, 4, v14                               ; 241c1c84
	v_lshrrev_b32_e32 v13, 2, v13                               ; 201a1a82
	v_lshlrev_b32_e32 v13, 4, v13                               ; 241a1a84
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_load_dwordx4 v[16:19], v14, s[28:31], 0 offen        ; e05c1000 8007100e
	buffer_load_dwordx4 v[20:23], v14, s[28:31], 0 offen offset:128 ; e05c1080 8007140e
	buffer_load_dwordx4 v[24:27], v13, s[28:31], 0 offen        ; e05c1000 8007180d
	buffer_load_dwordx4 v[28:31], v13, s[28:31], 0 offen offset:128 ; e05c1080 80071c0d
	s_mul_i32 s1, s16, s3                                       ; 92010310
	v_lshl_add_u32 v33, v2, 1, 8                                ; d1fd0021 02210302
	v_add_u32_e32 v37, 64, v4                                   ; 684a08c0
	s_add_u32 s1, s18, s1                                       ; 80010112
	s_add_u32 s4, s16, 1                                        ; 80048110
	v_add_u32_e32 v15, s1, v0                                   ; 681e0001
	s_mul_i32 s4, s4, s3                                        ; 92040304
	v_lshlrev_b32_e32 v32, 4, v15                               ; 24401e84
	s_add_u32 s4, s18, s4                                       ; 80040412
	s_add_u32 s5, s16, 2                                        ; 80058210
	v_lshl_add_u32 v15, v15, 7, v32                             ; d1fd000f 04810f0f
	v_add_u32_e32 v38, s4, v0                                   ; 684c0004
	s_mul_i32 s5, s5, s3                                        ; 92050305
	v_add_u32_e32 v35, 16, v15                                  ; 68461e90
	v_add3_u32 v34, v33, 4, v15                                 ; d1ff0022 043d0921
	v_lshlrev_b32_e32 v39, 4, v38                               ; 244e4c84
	s_add_u32 s5, s18, s5                                       ; 80050512
	v_add_u32_e32 v36, v35, v4                                  ; 68480923
	v_add_u32_e32 v35, v35, v37                                 ; 68464b23
	s_add_u32 s9, s16, 3                                        ; 80098310
	v_lshl_add_u32 v38, v38, 7, v39                             ; d1fd0026 049d0f26
	v_add_u32_e32 v43, s5, v0                                   ; 68560005
	s_mul_i32 s9, s9, s3                                        ; 92090309
	v_add3_u32 v40, v33, 4, v38                                 ; d1ff0028 04990921
	v_add_u32_e32 v41, 16, v38                                  ; 68524c90
	v_lshlrev_b32_e32 v44, 4, v43                               ; 24585684
	s_add_u32 s9, s18, s9                                       ; 80090912
	v_add_u32_e32 v42, v41, v4                                  ; 68540929
	v_add_u32_e32 v41, v41, v37                                 ; 68524b29
	v_lshl_add_u32 v43, v43, 7, v44                             ; d1fd002b 04b10f2b
	v_add_u32_e32 v48, s9, v0                                   ; 68600009
	v_add_u32_e32 v46, 16, v43                                  ; 685c5690
	v_add3_u32 v45, v33, 4, v43                                 ; d1ff002d 04ad0921
	v_lshlrev_b32_e32 v49, 4, v48                               ; 24626084
	v_add_u32_e32 v47, v46, v4                                  ; 685e092e
	v_add_u32_e32 v46, v46, v37                                 ; 685c4b2e
	v_lshl_add_u32 v48, v48, 7, v49                             ; d1fd0030 04c50f30
	v_add3_u32 v50, v33, 4, v48                                 ; d1ff0032 04c10921
	buffer_load_dwordx3 v[51:53], v15, s[24:27], 0 offen        ; e0581000 8006330f
	buffer_load_ushort v34, v34, s[24:27], 0 offen              ; e0481000 80062222
	buffer_load_dword v36, v36, s[24:27], 0 offen               ; e0501000 80062424
	buffer_load_dword v35, v35, s[24:27], 0 offen               ; e0501000 80062323
	buffer_load_dwordx3 v[54:56], v38, s[24:27], 0 offen        ; e0581000 80063626
	buffer_load_ushort v40, v40, s[24:27], 0 offen              ; e0481000 80062828
	buffer_load_dword v42, v42, s[24:27], 0 offen               ; e0501000 80062a2a
	buffer_load_dword v41, v41, s[24:27], 0 offen               ; e0501000 80062929
	buffer_load_dwordx3 v[57:59], v43, s[24:27], 0 offen        ; e0581000 8006392b
	buffer_load_ushort v45, v45, s[24:27], 0 offen              ; e0481000 80062d2d
	buffer_load_dword v47, v47, s[24:27], 0 offen               ; e0501000 80062f2f
	buffer_load_dword v46, v46, s[24:27], 0 offen               ; e0501000 80062e2e
	buffer_load_dwordx3 v[60:62], v48, s[24:27], 0 offen        ; e0581000 80063c30
	buffer_load_ushort v50, v50, s[24:27], 0 offen              ; e0481000 80063232
	s_bfm_b32 s10, 16, 16                                       ; 910a9090
	s_mov_b32 s11, 0xf0f0f0f                                    ; be8b00ff 0f0f0f0f
	s_mov_b32 s12, 0xc0c0c0c0                                   ; be8c00ff c0c0c0c0
	s_mov_b32 s13, 0x3f3f3f3f                                   ; be8d00ff 3f3f3f3f
	v_add_u32_e32 v48, 16, v48                                  ; 68606090
	s_waitcnt vmcnt(17)                                         ; bf8c7f71
	v_add_f32_e32 v13, v16, v17                                 ; 021a2310
	s_waitcnt vmcnt(16)                                         ; bf8c7f70
	v_add_f32_e32 v14, v20, v21                                 ; 021c2b14
	v_add_f32_e32 v13, v13, v18                                 ; 021a250d
	s_waitcnt vmcnt(15)                                         ; bf8c3f7f
	v_add_f32_e32 v15, v24, v25                                 ; 021e3318
	v_add_f32_e32 v14, v14, v22                                 ; 021c2d0e
	s_waitcnt vmcnt(14)                                         ; bf8c3f7e
	v_add_f32_e32 v32, v28, v29                                 ; 02403b1c
	v_add_f32_e32 v13, v13, v19                                 ; 021a270d
	v_add_f32_e32 v15, v15, v26                                 ; 021e350f
	v_add_f32_e32 v14, v14, v23                                 ; 021c2f0e
	v_add_f32_e32 v32, v32, v30                                 ; 02403d20
	v_add_f32_e32 v15, v15, v27                                 ; 021e370f
	v_add_f32_e32 v32, v32, v31                                 ; 02403f20
	s_waitcnt vmcnt(13)                                         ; bf8c3f7d
	v_lshrrev_b32_sdwa v53, v5, v53 dst_sel:WORD_1 dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:DWORD ; 206a6af9 06060505
	v_lshrrev_b32_e32 v52, v5, v52                              ; 20686905
	s_waitcnt vmcnt(12)                                         ; bf8c3f7c
	v_lshl_or_b32 v34, v34, 12, v34                             ; d2000022 04891922
	s_waitcnt vmcnt(11)                                         ; bf8c3f7b
	v_and_b32_e32 v39, s11, v36                                 ; 264e480b
	v_lshrrev_b32_e32 v36, 4, v36                               ; 20484884
	v_bfi_b32 v53, s10, v53, v52                                ; d1ca0035 04d26a0a
	v_cvt_f32_ubyte3_e32 v43, v39                               ; 7e562927
	v_cvt_f32_ubyte1_e32 v49, v39                               ; 7e622527
	v_cvt_f32_ubyte2_e32 v44, v39                               ; 7e582727
	v_cvt_f32_ubyte0_e32 v39, v39                               ; 7e4e2327
	v_and_b32_e32 v36, s11, v36                                 ; 2648480b
	v_and_b32_e32 v38, s12, v53                                 ; 264c6a0c
	v_and_b32_e32 v53, s13, v53                                 ; 266a6a0d
	v_mul_f32_e32 v43, v19, v43                                 ; 0a565713
	v_cvt_f32_ubyte3_e32 v52, v36                               ; 7e682924
	v_lshrrev_b32_e32 v38, 2, v38                               ; 204c4c82
	v_mac_f32_e32 v43, v18, v44                                 ; 2c565912
	s_waitcnt vmcnt(10)                                         ; bf8c3f7a
	v_and_b32_e32 v44, s11, v35                                 ; 2658460b
	v_mul_f32_e32 v52, v23, v52                                 ; 0a686917
	v_and_or_b32 v34, s11, v34, v38                             ; d2010022 049a440b
	v_cvt_f32_ubyte2_e32 v38, v36                               ; 7e4c2724
	v_mac_f32_e32 v43, v17, v49                                 ; 2c566311
	v_cvt_f32_ubyte3_e32 v49, v44                               ; 7e62292c
	v_lshrrev_b32_e32 v35, 4, v35                               ; 20464684
	v_mac_f32_e32 v52, v22, v38                                 ; 2c684d16
	v_cvt_f32_ubyte1_e32 v38, v44                               ; 7e4c252c
	v_mac_f32_e32 v43, v16, v39                                 ; 2c564f10
	v_cvt_f32_ubyte1_e32 v39, v36                               ; 7e4e2524
	v_cvt_f32_ubyte0_e32 v36, v36                               ; 7e482324
	v_mul_f32_e32 v49, v27, v49                                 ; 0a62631b
	v_and_b32_e32 v35, s11, v35                                 ; 2646460b
	v_mac_f32_e32 v52, v21, v39                                 ; 2c684f15
	v_cvt_f32_ubyte3_e32 v39, v35                               ; 7e4e2923
	v_mac_f32_e32 v52, v20, v36                                 ; 2c684914
	v_cvt_f32_ubyte2_e32 v36, v44                               ; 7e48272c
	v_cvt_f32_ubyte0_e32 v44, v44                               ; 7e58232c
	v_mul_f32_e32 v39, v31, v39                                 ; 0a4e4f1f
	v_mac_f32_e32 v49, v26, v36                                 ; 2c62491a
	v_cvt_f32_ubyte1_e32 v36, v35                               ; 7e482523
	v_mac_f32_e32 v49, v25, v38                                 ; 2c624d19
	v_cvt_f32_ubyte3_e32 v38, v34                               ; 7e4c2922
	v_mac_f32_e32 v49, v24, v44                                 ; 2c625918
	v_cvt_f32_ubyte2_e32 v44, v35                               ; 7e582723
	v_cvt_f32_ubyte0_e32 v35, v35                               ; 7e462323
	v_mul_f32_e32 v38, v32, v38                                 ; 0a4c4d20
	v_mac_f32_e32 v39, v30, v44                                 ; 2c4e591e
	v_cvt_f32_ubyte2_e32 v44, v34                               ; 7e582722
	v_mac_f32_e32 v39, v29, v36                                 ; 2c4e491d
	v_mac_f32_e32 v38, v15, v44                                 ; 2c4c590f
	v_mac_f32_e32 v39, v28, v35                                 ; 2c4e471c
	v_cvt_f32_ubyte3_e32 v35, v53                               ; 7e462935
	v_mac_f32_e32 v38, v14, v35                                 ; 2c4c470e
	v_add_u32_e32 v35, v48, v4                                  ; 68460930
	v_add_u32_e32 v48, v48, v37                                 ; 68604b30
	buffer_load_dword v35, v35, s[24:27], 0 offen               ; e0501000 80062323
	buffer_load_dword v48, v48, s[24:27], 0 offen               ; e0501000 80063030
	v_cvt_f32_ubyte2_e32 v36, v53                               ; 7e482735
	v_cvt_f32_ubyte1_e32 v44, v34                               ; 7e582522
	v_cvt_f32_ubyte0_e32 v34, v34                               ; 7e442322
	s_add_u32 s14, s16, 4                                       ; 800e8410
	v_mac_f32_e32 v38, v13, v36                                 ; 2c4c490d
	v_cvt_f32_ubyte1_e32 v36, v53                               ; 7e482535
	v_cvt_f32_ubyte0_e32 v53, v53                               ; 7e6a2335
	v_mul_f32_e32 v39, v39, v44                                 ; 0a4e5927
	s_mul_i32 s14, s14, s3                                      ; 920e030e
	v_mac_f32_e32 v39, v49, v34                                 ; 2c4e4531
	s_add_u32 s14, s18, s14                                     ; 800e0e12
	v_mac_f32_e32 v39, v52, v36                                 ; 2c4e4934
	v_mac_f32_e32 v39, v43, v53                                 ; 2c4e6b2b
	v_add_u32_e32 v43, s14, v0                                  ; 6856000e
	v_lshlrev_b32_e32 v44, 4, v43                               ; 24585684
	v_lshl_add_u32 v43, v43, 7, v44                             ; d1fd002b 04b10f2b
	v_add3_u32 v52, v33, 4, v43                                 ; d1ff0034 04ad0921
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_mov_b32_e32 v53, v35                                      ; 7e6a0323
	buffer_load_dwordx3 v[34:36], v43, s[24:27], 0 offen        ; e0581000 8006222b
	buffer_load_ushort v52, v52, s[24:27], 0 offen              ; e0481000 80063434
	v_cvt_f32_f16_sdwa v49, v51 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e6216f9 00050633
	v_cvt_f32_f16_e32 v51, v51                                  ; 7e661733
	v_lshrrev_b32_e32 v55, v5, v55                              ; 206e6f05
	v_lshrrev_b32_sdwa v56, v5, v56 dst_sel:WORD_1 dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:DWORD ; 207070f9 06060505
	v_lshl_or_b32 v40, v40, 12, v40                             ; d2000028 04a11928
	v_add_u32_e32 v43, 16, v43                                  ; 68565690
	v_mad_f32 v3, -v49, v38, v3                                 ; d1c10003 240e4d31
	v_and_b32_e32 v38, s11, v42                                 ; 264c540b
	v_bfi_b32 v56, s10, v56, v55                                ; d1ca0038 04de700a
	v_lshrrev_b32_e32 v42, 4, v42                               ; 20545484
	v_mac_f32_e32 v3, v51, v39                                  ; 2c064f33
	v_cvt_f32_ubyte3_e32 v39, v38                               ; 7e4e2926
	v_cvt_f32_ubyte2_e32 v44, v38                               ; 7e582726
	v_cvt_f32_ubyte1_e32 v49, v38                               ; 7e622526
	v_cvt_f32_ubyte0_e32 v38, v38                               ; 7e4c2326
	v_and_b32_e32 v55, s12, v56                                 ; 266e700c
	v_and_b32_e32 v56, s13, v56                                 ; 2670700d
	v_and_b32_e32 v42, s11, v42                                 ; 2654540b
	v_mul_f32_e32 v39, v19, v39                                 ; 0a4e4f13
	v_lshrrev_b32_e32 v55, 2, v55                               ; 206e6e82
	v_cvt_f32_ubyte3_e32 v51, v42                               ; 7e66292a
	v_mac_f32_e32 v39, v18, v44                                 ; 2c4e5912
	v_and_or_b32 v40, s11, v40, v55                             ; d2010028 04de500b
	v_cvt_f32_ubyte2_e32 v55, v42                               ; 7e6e272a
	v_mul_f32_e32 v51, v23, v51                                 ; 0a666717
	v_mac_f32_e32 v39, v17, v49                                 ; 2c4e6311
	v_mac_f32_e32 v51, v22, v55                                 ; 2c666f16
	v_mac_f32_e32 v39, v16, v38                                 ; 2c4e4d10
	v_cvt_f32_ubyte1_e32 v38, v42                               ; 7e4c252a
	v_cvt_f32_ubyte0_e32 v42, v42                               ; 7e54232a
	v_mac_f32_e32 v51, v21, v38                                 ; 2c664d15
	v_mac_f32_e32 v51, v20, v42                                 ; 2c665514
	v_and_b32_e32 v42, s11, v41                                 ; 2654520b
	v_lshrrev_b32_e32 v41, 4, v41                               ; 20525284
	v_cvt_f32_ubyte3_e32 v44, v42                               ; 7e58292a
	v_cvt_f32_ubyte1_e32 v55, v42                               ; 7e6e252a
	v_cvt_f32_ubyte2_e32 v49, v42                               ; 7e62272a
	v_cvt_f32_ubyte0_e32 v42, v42                               ; 7e54232a
	v_and_b32_e32 v41, s11, v41                                 ; 2652520b
	v_mul_f32_e32 v44, v27, v44                                 ; 0a58591b
	v_cvt_f32_ubyte3_e32 v38, v41                               ; 7e4c2929
	v_mac_f32_e32 v44, v26, v49                                 ; 2c58631a
	v_cvt_f32_ubyte1_e32 v49, v41                               ; 7e622529
	v_mul_f32_e32 v38, v31, v38                                 ; 0a4c4d1f
	v_mac_f32_e32 v44, v25, v55                                 ; 2c586f19
	v_cvt_f32_ubyte3_e32 v55, v40                               ; 7e6e2928
	v_mac_f32_e32 v44, v24, v42                                 ; 2c585518
	v_cvt_f32_ubyte2_e32 v42, v41                               ; 7e542729
	v_cvt_f32_ubyte0_e32 v41, v41                               ; 7e522329
	v_mul_f32_e32 v55, v32, v55                                 ; 0a6e6f20
	v_mac_f32_e32 v38, v30, v42                                 ; 2c4c551e
	v_cvt_f32_ubyte3_e32 v42, v56                               ; 7e542938
	v_mac_f32_e32 v38, v29, v49                                 ; 2c4c631d
	v_cvt_f32_ubyte2_e32 v49, v56                               ; 7e622738
	v_mac_f32_e32 v38, v28, v41                                 ; 2c4c531c
	v_cvt_f32_ubyte2_e32 v41, v40                               ; 7e522728
	s_add_u32 s15, s16, 5                                       ; 800f8510
	v_mac_f32_e32 v55, v15, v41                                 ; 2c6e530f
	v_cvt_f32_ubyte1_e32 v41, v40                               ; 7e522528
	v_cvt_f32_ubyte0_e32 v40, v40                               ; 7e502328
	s_mul_i32 s15, s15, s3                                      ; 920f030f
	v_mac_f32_e32 v55, v14, v42                                 ; 2c6e550e
	v_add_u32_e32 v42, v43, v4                                  ; 6854092b
	v_add_u32_e32 v43, v43, v37                                 ; 68564b2b
	v_mul_f32_e32 v38, v38, v41                                 ; 0a4c5326
	buffer_load_dword v42, v42, s[24:27], 0 offen               ; e0501000 80062a2a
	buffer_load_dword v43, v43, s[24:27], 0 offen               ; e0501000 80062b2b
	s_add_u32 s15, s18, s15                                     ; 800f0f12
	v_mac_f32_e32 v55, v13, v49                                 ; 2c6e630d
	v_mac_f32_e32 v38, v44, v40                                 ; 2c4c512c
	v_cvt_f32_ubyte1_e32 v44, v56                               ; 7e582538
	v_cvt_f32_ubyte0_e32 v56, v56                               ; 7e702338
	v_add_u32_e32 v49, s15, v0                                  ; 6862000f
	v_mac_f32_e32 v38, v51, v44                                 ; 2c4c5933
	v_lshlrev_b32_e32 v51, 4, v49                               ; 24666284
	v_mac_f32_e32 v38, v39, v56                                 ; 2c4c7127
	v_lshl_add_u32 v49, v49, 7, v51                             ; d1fd0031 04cd0f31
	v_add3_u32 v39, v33, 4, v49                                 ; d1ff0027 04c50921
	v_mov_b32_e32 v44, v39                                      ; 7e580327
	buffer_load_dwordx3 v[39:41], v49, s[24:27], 0 offen        ; e0581000 80062731
	buffer_load_ushort v44, v44, s[24:27], 0 offen              ; e0481000 80062c2c
	v_cvt_f32_f16_sdwa v56, v54 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e7016f9 00050636
	v_cvt_f32_f16_e32 v54, v54                                  ; 7e6c1736
	v_lshrrev_b32_e32 v58, v5, v58                              ; 20747505
	v_lshrrev_b32_sdwa v59, v5, v59 dst_sel:WORD_1 dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:DWORD ; 207676f9 06060505
	v_lshl_or_b32 v45, v45, 12, v45                             ; d200002d 04b5192d
	v_mad_f32 v6, -v56, v55, v6                                 ; d1c10006 241a6f38
	v_bfi_b32 v59, s10, v59, v58                                ; d1ca003b 04ea760a
	v_mac_f32_e32 v6, v54, v38                                  ; 2c0c4d36
	v_and_b32_e32 v54, s11, v47                                 ; 266c5e0b
	v_lshrrev_b32_e32 v47, 4, v47                               ; 205e5e84
	v_and_b32_e32 v51, s12, v59                                 ; 2666760c
	v_cvt_f32_ubyte1_e32 v58, v54                               ; 7e742536
	v_cvt_f32_ubyte2_e32 v56, v54                               ; 7e702736
	v_cvt_f32_ubyte3_e32 v55, v54                               ; 7e6e2936
	v_cvt_f32_ubyte0_e32 v54, v54                               ; 7e6c2336
	v_and_b32_e32 v47, s11, v47                                 ; 265e5e0b
	v_lshrrev_b32_e32 v51, 2, v51                               ; 20666682
	v_mul_f32_e32 v55, v19, v55                                 ; 0a6e6f13
	v_cvt_f32_ubyte3_e32 v38, v47                               ; 7e4c292f
	v_and_or_b32 v45, s11, v45, v51                             ; d201002d 04ce5a0b
	v_cvt_f32_ubyte2_e32 v51, v47                               ; 7e66272f
	v_mac_f32_e32 v55, v18, v56                                 ; 2c6e7112
	v_and_b32_e32 v56, s11, v46                                 ; 26705c0b
	v_mul_f32_e32 v38, v23, v38                                 ; 0a4c4d17
	v_mac_f32_e32 v55, v17, v58                                 ; 2c6e7511
	v_lshrrev_b32_e32 v46, 4, v46                               ; 205c5c84
	v_cvt_f32_ubyte3_e32 v58, v56                               ; 7e742938
	v_mac_f32_e32 v38, v22, v51                                 ; 2c4c6716
	v_cvt_f32_ubyte1_e32 v51, v56                               ; 7e662538
	v_mac_f32_e32 v55, v16, v54                                 ; 2c6e6d10
	v_cvt_f32_ubyte1_e32 v54, v47                               ; 7e6c252f
	v_cvt_f32_ubyte0_e32 v47, v47                               ; 7e5e232f
	v_and_b32_e32 v46, s11, v46                                 ; 265c5c0b
	v_mul_f32_e32 v58, v27, v58                                 ; 0a74751b
	v_mac_f32_e32 v38, v21, v54                                 ; 2c4c6d15
	v_cvt_f32_ubyte3_e32 v54, v46                               ; 7e6c292e
	v_mac_f32_e32 v38, v20, v47                                 ; 2c4c5f14
	v_cvt_f32_ubyte2_e32 v47, v56                               ; 7e5e2738
	v_cvt_f32_ubyte0_e32 v56, v56                               ; 7e702338
	v_mul_f32_e32 v54, v31, v54                                 ; 0a6c6d1f
	v_and_b32_e32 v59, s13, v59                                 ; 2676760d
	v_mac_f32_e32 v58, v26, v47                                 ; 2c745f1a
	v_cvt_f32_ubyte1_e32 v47, v46                               ; 7e5e252e
	v_mac_f32_e32 v58, v25, v51                                 ; 2c746719
	v_cvt_f32_ubyte3_e32 v51, v45                               ; 7e66292d
	v_mac_f32_e32 v58, v24, v56                                 ; 2c747118
	v_cvt_f32_ubyte2_e32 v56, v46                               ; 7e70272e
	v_cvt_f32_ubyte0_e32 v46, v46                               ; 7e5c232e
	v_add_u32_e32 v49, 16, v49                                  ; 68626290
	v_mul_f32_e32 v51, v32, v51                                 ; 0a666720
	v_mac_f32_e32 v54, v30, v56                                 ; 2c6c711e
	v_cvt_f32_ubyte2_e32 v56, v45                               ; 7e70272d
	v_mac_f32_e32 v54, v29, v47                                 ; 2c6c5f1d
	v_mac_f32_e32 v51, v15, v56                                 ; 2c66710f
	v_mac_f32_e32 v54, v28, v46                                 ; 2c6c5d1c
	v_cvt_f32_ubyte3_e32 v46, v59                               ; 7e5c293b
	v_mac_f32_e32 v51, v14, v46                                 ; 2c665d0e
	v_add_u32_e32 v46, v49, v4                                  ; 685c0931
	v_add_u32_e32 v49, v49, v37                                 ; 68624b31
	buffer_load_dword v46, v46, s[24:27], 0 offen               ; e0501000 80062e2e
	buffer_load_dword v49, v49, s[24:27], 0 offen               ; e0501000 80063131
	v_cvt_f32_ubyte2_e32 v47, v59                               ; 7e5e273b
	v_cvt_f32_ubyte1_e32 v56, v45                               ; 7e70252d
	v_cvt_f32_ubyte0_e32 v45, v45                               ; 7e5a232d
	v_lshrrev_b32_e32 v61, v5, v61                              ; 207a7b05
	v_lshrrev_b32_sdwa v62, v5, v62 dst_sel:WORD_1 dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:DWORD ; 207c7cf9 06060505
	v_mac_f32_e32 v51, v13, v47                                 ; 2c665f0d
	v_cvt_f32_ubyte1_e32 v47, v59                               ; 7e5e253b
	v_cvt_f32_ubyte0_e32 v59, v59                               ; 7e76233b
	v_lshl_or_b32 v50, v50, 12, v50                             ; d2000032 04c91932
	v_mul_f32_e32 v54, v54, v56                                 ; 0a6c7136
	v_bfi_b32 v62, s10, v62, v61                                ; d1ca003e 04f67c0a
	v_mac_f32_e32 v54, v58, v45                                 ; 2c6c5b3a
	v_and_b32_e32 v56, s12, v62                                 ; 26707c0c
	v_and_b32_e32 v62, s13, v62                                 ; 267c7c0d
	v_mac_f32_e32 v54, v38, v47                                 ; 2c6c5f26
	v_lshrrev_b32_e32 v56, 2, v56                               ; 20707082
	v_cvt_f32_ubyte2_e32 v61, v62                               ; 7e7a273e
	v_mac_f32_e32 v54, v55, v59                                 ; 2c6c7737
	v_cvt_f32_f16_sdwa v55, v57 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e6e16f9 00050639
	v_cvt_f32_f16_e32 v57, v57                                  ; 7e721739
	v_cvt_f32_ubyte3_e32 v59, v62                               ; 7e76293e
	v_cvt_f32_ubyte1_e32 v45, v62                               ; 7e5a253e
	v_and_or_b32 v50, s11, v50, v56                             ; d2010032 04e2640b
	v_cvt_f32_ubyte0_e32 v62, v62                               ; 7e7c233e
	v_cvt_f32_f16_sdwa v47, v60 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e5e16f9 0005063c
	v_mad_f32 v7, -v55, v51, v7                                 ; d1c10007 241e6737
	v_cvt_f32_f16_e32 v60, v60                                  ; 7e78173c
	v_and_b32_e32 v51, s11, v53                                 ; 26666a0b
	v_cvt_f32_ubyte1_e32 v38, v50                               ; 7e4c2532
	v_cvt_f32_ubyte2_e32 v58, v50                               ; 7e742732
	v_mac_f32_e32 v7, v57, v54                                  ; 2c0e6d39
	v_cvt_f32_ubyte3_e32 v57, v50                               ; 7e722932
	v_cvt_f32_ubyte0_e32 v50, v50                               ; 7e642332
	v_cvt_f32_ubyte3_e32 v54, v51                               ; 7e6c2933
	v_cvt_f32_ubyte2_e32 v55, v51                               ; 7e6e2733
	v_cvt_f32_ubyte1_e32 v56, v51                               ; 7e702533
	v_cvt_f32_ubyte0_e32 v51, v51                               ; 7e662333
	v_lshrrev_b32_e32 v53, 4, v53                               ; 206a6a84
	v_mul_f32_e32 v57, v32, v57                                 ; 0a727320
	v_mul_f32_e32 v54, v19, v54                                 ; 0a6c6d13
	v_and_b32_e32 v53, s11, v53                                 ; 266a6a0b
	v_mac_f32_e32 v57, v15, v58                                 ; 2c72750f
	v_mac_f32_e32 v54, v18, v55                                 ; 2c6c6f12
	v_cvt_f32_ubyte2_e32 v58, v53                               ; 7e742735
	v_mac_f32_e32 v57, v14, v59                                 ; 2c72770e
	v_cvt_f32_ubyte1_e32 v59, v53                               ; 7e762535
	v_mac_f32_e32 v54, v17, v56                                 ; 2c6c7111
	v_mac_f32_e32 v57, v13, v61                                 ; 2c727b0d
	s_waitcnt vmcnt(8)                                          ; bf8c3f78
	v_and_b32_e32 v61, s11, v48                                 ; 267a600b
	v_mac_f32_e32 v54, v16, v51                                 ; 2c6c6710
	v_mad_f32 v8, -v47, v57, v8                                 ; d1c10008 2422732f
	v_cvt_f32_ubyte3_e32 v57, v53                               ; 7e722935
	v_cvt_f32_ubyte0_e32 v53, v53                               ; 7e6a2335
	v_cvt_f32_ubyte2_e32 v51, v61                               ; 7e66273d
	v_cvt_f32_ubyte3_e32 v47, v61                               ; 7e5e293d
	v_lshrrev_b32_e32 v48, 4, v48                               ; 20606084
	v_mul_f32_e32 v57, v23, v57                                 ; 0a727317
	v_mul_f32_e32 v47, v27, v47                                 ; 0a5e5f1b
	v_and_b32_e32 v48, s11, v48                                 ; 2660600b
	s_add_u32 s19, s16, 6                                       ; 80138610
	v_mac_f32_e32 v57, v22, v58                                 ; 2c727516
	v_mac_f32_e32 v47, v26, v51                                 ; 2c5e671a
	v_cvt_f32_ubyte2_e32 v56, v48                               ; 7e702730
	v_cvt_f32_ubyte3_e32 v55, v48                               ; 7e6e2930
	v_cvt_f32_ubyte1_e32 v58, v48                               ; 7e742530
	s_mul_i32 s19, s19, s3                                      ; 92130313
	v_mac_f32_e32 v57, v21, v59                                 ; 2c727715
	v_cvt_f32_ubyte0_e32 v48, v48                               ; 7e602330
	v_mul_f32_e32 v55, v31, v55                                 ; 0a6e6f1f
	s_add_u32 s19, s18, s19                                     ; 80131312
	v_mac_f32_e32 v57, v20, v53                                 ; 2c726b14
	v_cvt_f32_ubyte1_e32 v53, v61                               ; 7e6a253d
	v_cvt_f32_ubyte0_e32 v61, v61                               ; 7e7a233d
	v_mac_f32_e32 v55, v30, v56                                 ; 2c6e711e
	s_waitcnt vmcnt(6)                                          ; bf8c3f76
	v_mov_b32_e32 v56, v52                                      ; 7e700334
	v_add_u32_e32 v59, s19, v0                                  ; 68760013
	v_mac_f32_e32 v47, v25, v53                                 ; 2c5e6b19
	v_mac_f32_e32 v55, v29, v58                                 ; 2c6e751d
	v_mac_f32_e32 v47, v24, v61                                 ; 2c5e7b18
	v_lshlrev_b32_e32 v61, 4, v59                               ; 247a7684
	v_mac_f32_e32 v55, v28, v48                                 ; 2c6e611c
	v_lshl_add_u32 v59, v59, 7, v61                             ; d1fd003b 04f50f3b
	v_add3_u32 v48, v33, 4, v59                                 ; d1ff0030 04ed0921
	buffer_load_dwordx3 v[51:53], v59, s[24:27], 0 offen        ; e0581000 8006333b
	buffer_load_ushort v48, v48, s[24:27], 0 offen              ; e0481000 80063030
	v_add_u32_e32 v59, 16, v59                                  ; 68767690
	v_add_u32_e32 v58, v59, v4                                  ; 6874093b
	v_add_u32_e32 v59, v59, v37                                 ; 68764b3b
	buffer_load_dword v58, v58, s[24:27], 0 offen               ; e0501000 80063a3a
	buffer_load_dword v59, v59, s[24:27], 0 offen               ; e0501000 80063b3b
	v_lshrrev_b32_e32 v35, v5, v35                              ; 20464705
	v_lshrrev_b32_sdwa v36, v5, v36 dst_sel:WORD_1 dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:DWORD ; 204848f9 06060505
	v_mul_f32_e32 v55, v55, v38                                 ; 0a6e4d37
	v_lshl_or_b32 v56, v56, 12, v56                             ; d2000038 04e11938
	v_bfi_b32 v36, s10, v36, v35                                ; d1ca0024 048e480a
	v_mac_f32_e32 v55, v47, v50                                 ; 2c6e652f
	v_mac_f32_e32 v55, v57, v45                                 ; 2c6e5b39
	v_mac_f32_e32 v55, v54, v62                                 ; 2c6e7d36
	v_mac_f32_e32 v8, v60, v55                                  ; 2c106f3c
	v_and_b32_e32 v60, s12, v36                                 ; 2678480c
	v_and_b32_e32 v36, s13, v36                                 ; 2648480d
	v_cvt_f32_f16_sdwa v38, v34 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e4c16f9 00050622
	v_lshrrev_b32_e32 v60, 2, v60                               ; 20787882
	v_cvt_f32_ubyte1_e32 v35, v36                               ; 7e462524
	v_cvt_f32_f16_e32 v34, v34                                  ; 7e441722
	s_waitcnt vmcnt(9)                                          ; bf8c3f79
	v_and_b32_e32 v45, s11, v42                                 ; 265a540b
	v_and_or_b32 v56, s11, v56, v60                             ; d2010038 04f2700b
	v_cvt_f32_ubyte2_e32 v50, v45                               ; 7e64272d
	v_cvt_f32_ubyte3_e32 v47, v45                               ; 7e5e292d
	v_cvt_f32_ubyte1_e32 v54, v45                               ; 7e6c252d
	v_cvt_f32_ubyte3_e32 v61, v56                               ; 7e7a2938
	v_cvt_f32_ubyte2_e32 v62, v56                               ; 7e7c2738
	v_cvt_f32_ubyte0_e32 v45, v45                               ; 7e5a232d
	v_mul_f32_e32 v47, v19, v47                                 ; 0a5e5f13
	v_mul_f32_e32 v61, v32, v61                                 ; 0a7a7b20
	v_lshrrev_b32_e32 v42, 4, v42                               ; 20545484
	v_mac_f32_e32 v47, v18, v50                                 ; 2c5e6512
	v_mac_f32_e32 v61, v15, v62                                 ; 2c7a7d0f
	v_cvt_f32_ubyte3_e32 v62, v36                               ; 7e7c2924
	v_and_b32_e32 v42, s11, v42                                 ; 2654540b
	v_mac_f32_e32 v47, v17, v54                                 ; 2c5e6d11
	v_mac_f32_e32 v61, v14, v62                                 ; 2c7a7d0e
	v_cvt_f32_ubyte2_e32 v62, v36                               ; 7e7c2724
	v_cvt_f32_ubyte0_e32 v36, v36                               ; 7e482324
	v_cvt_f32_ubyte1_e32 v60, v42                               ; 7e78252a
	v_cvt_f32_ubyte3_e32 v55, v42                               ; 7e6e292a
	v_cvt_f32_ubyte2_e32 v57, v42                               ; 7e72272a
	v_cvt_f32_ubyte0_e32 v42, v42                               ; 7e54232a
	v_mac_f32_e32 v47, v16, v45                                 ; 2c5e5b10
	v_mac_f32_e32 v61, v13, v62                                 ; 2c7a7d0d
	v_cvt_f32_ubyte1_e32 v62, v56                               ; 7e7c2538
	v_cvt_f32_ubyte0_e32 v56, v56                               ; 7e702338
	v_mul_f32_e32 v55, v23, v55                                 ; 0a6e6f17
	v_mad_f32 v9, -v38, v61, v9                                 ; d1c10009 24267b26
	s_waitcnt vmcnt(8)                                          ; bf8c3f78
	v_and_b32_e32 v61, s11, v43                                 ; 267a560b
	v_lshrrev_b32_e32 v43, 4, v43                               ; 20565684
	v_mac_f32_e32 v55, v22, v57                                 ; 2c6e7316
	v_cvt_f32_ubyte3_e32 v38, v61                               ; 7e4c293d
	v_cvt_f32_ubyte1_e32 v45, v61                               ; 7e5a253d
	v_and_b32_e32 v43, s11, v43                                 ; 2656560b
	v_mac_f32_e32 v55, v21, v60                                 ; 2c6e7915
	v_mul_f32_e32 v38, v27, v38                                 ; 0a4c4d1b
	s_add_u32 s20, s16, 7                                       ; 80148710
	v_cvt_f32_ubyte2_e32 v54, v43                               ; 7e6c272b
	v_cvt_f32_ubyte3_e32 v50, v43                               ; 7e64292b
	v_cvt_f32_ubyte1_e32 v57, v43                               ; 7e72252b
	v_mac_f32_e32 v55, v20, v42                                 ; 2c6e5514
	v_cvt_f32_ubyte2_e32 v42, v61                               ; 7e54273d
	v_cvt_f32_ubyte0_e32 v61, v61                               ; 7e7a233d
	s_mul_i32 s20, s20, s3                                      ; 92140314
	v_mul_f32_e32 v50, v31, v50                                 ; 0a64651f
	v_mac_f32_e32 v38, v26, v42                                 ; 2c4c551a
	s_add_u32 s20, s18, s20                                     ; 80141412
	v_mac_f32_e32 v50, v30, v54                                 ; 2c646d1e
	s_waitcnt vmcnt(6)                                          ; bf8c3f76
	v_mov_b32_e32 v54, v44                                      ; 7e6c032c
	v_mac_f32_e32 v38, v25, v45                                 ; 2c4c5b19
	v_mov_b32_e32 v45, v43                                      ; 7e5a032b
	v_add_u32_e32 v60, s20, v0                                  ; 68780014
	v_mac_f32_e32 v38, v24, v61                                 ; 2c4c7b18
	v_lshlrev_b32_e32 v61, 4, v60                               ; 247a7884
	v_lshl_add_u32 v60, v60, 7, v61                             ; d1fd003c 04f50f3c
	v_add3_u32 v33, v33, 4, v60                                 ; d1ff0021 04f10921
	buffer_load_dwordx3 v[42:44], v60, s[24:27], 0 offen        ; e0581000 80062a3c
	buffer_load_ushort v33, v33, s[24:27], 0 offen              ; e0481000 80062121
	v_mac_f32_e32 v50, v29, v57                                 ; 2c64731d
	v_add_u32_e32 v60, 16, v60                                  ; 68787890
	v_add_u32_e32 v57, v60, v4                                  ; 6872093c
	v_add_u32_e32 v60, v60, v37                                 ; 68784b3c
	buffer_load_dword v57, v57, s[24:27], 0 offen               ; e0501000 80063939
	buffer_load_dword v60, v60, s[24:27], 0 offen               ; e0501000 80063c3c
	v_cvt_f32_ubyte0_e32 v45, v45                               ; 7e5a232d
	v_lshrrev_b32_e32 v40, v5, v40                              ; 20505105
	v_lshrrev_b32_sdwa v41, v5, v41 dst_sel:WORD_1 dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:DWORD ; 205252f9 06060505
	v_lshl_or_b32 v54, v54, 12, v54                             ; d2000036 04d91936
	v_mac_f32_e32 v50, v28, v45                                 ; 2c645b1c
	v_bfi_b32 v41, s10, v41, v40                                ; d1ca0029 04a2520a
	v_mul_f32_e32 v50, v50, v62                                 ; 0a647d32
	v_and_b32_e32 v61, s12, v41                                 ; 267a520c
	v_and_b32_e32 v41, s13, v41                                 ; 2652520d
	v_mac_f32_e32 v50, v38, v56                                 ; 2c647126
	v_lshrrev_b32_e32 v61, 2, v61                               ; 207a7a82
	v_cvt_f32_ubyte1_e32 v38, v41                               ; 7e4c2529
	v_mac_f32_e32 v50, v55, v35                                 ; 2c644737
	v_cvt_f32_ubyte3_e32 v35, v41                               ; 7e462929
	v_cvt_f32_f16_sdwa v40, v39 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e5016f9 00050627
	v_and_or_b32 v54, s11, v54, v61                             ; d2010036 04f66c0b
	v_cvt_f32_f16_e32 v39, v39                                  ; 7e4e1727
	v_mac_f32_e32 v50, v47, v36                                 ; 2c64492f
	v_cvt_f32_ubyte2_e32 v36, v41                               ; 7e482729
	v_cvt_f32_ubyte0_e32 v41, v41                               ; 7e522329
	s_waitcnt vmcnt(9)                                          ; bf8c3f79
	v_and_b32_e32 v45, s11, v46                                 ; 265a5c0b
	v_cvt_f32_ubyte3_e32 v62, v54                               ; 7e7c2936
	v_cvt_f32_ubyte1_e32 v37, v54                               ; 7e4a2536
	v_mac_f32_e32 v9, v34, v50                                  ; 2c126522
	v_cvt_f32_ubyte2_e32 v34, v54                               ; 7e442736
	v_cvt_f32_ubyte0_e32 v54, v54                               ; 7e6c2336
	v_cvt_f32_ubyte2_e32 v50, v45                               ; 7e64272d
	v_cvt_f32_ubyte1_e32 v55, v45                               ; 7e6e252d
	v_cvt_f32_ubyte3_e32 v47, v45                               ; 7e5e292d
	v_cvt_f32_ubyte0_e32 v45, v45                               ; 7e5a232d
	v_mul_f32_e32 v62, v32, v62                                 ; 0a7c7d20
	v_lshrrev_b32_e32 v46, 4, v46                               ; 205c5c84
	v_mul_f32_e32 v47, v19, v47                                 ; 0a5e5f13
	v_mac_f32_e32 v62, v15, v34                                 ; 2c7c450f
	v_and_b32_e32 v46, s11, v46                                 ; 265c5c0b
	v_mac_f32_e32 v47, v18, v50                                 ; 2c5e6512
	v_mac_f32_e32 v62, v14, v35                                 ; 2c7c470e
	v_cvt_f32_ubyte3_e32 v56, v46                               ; 7e70292e
	v_cvt_f32_ubyte2_e32 v61, v46                               ; 7e7a272e
	v_mac_f32_e32 v47, v17, v55                                 ; 2c5e6f11
	v_mac_f32_e32 v62, v13, v36                                 ; 2c7c490d
	v_mul_f32_e32 v56, v23, v56                                 ; 0a707117
	v_mac_f32_e32 v47, v16, v45                                 ; 2c5e5b10
	v_mad_f32 v10, -v40, v62, v10                               ; d1c1000a 242a7d28
	v_cvt_f32_ubyte1_e32 v62, v46                               ; 7e7c252e
	v_cvt_f32_ubyte0_e32 v46, v46                               ; 7e5c232e
	v_mac_f32_e32 v56, v22, v61                                 ; 2c707b16
	v_mac_f32_e32 v56, v21, v62                                 ; 2c707d15
	s_waitcnt vmcnt(8)                                          ; bf8c3f78
	v_and_b32_e32 v62, s11, v49                                 ; 267c620b
	v_lshrrev_b32_e32 v49, 4, v49                               ; 20626284
	v_mac_f32_e32 v56, v20, v46                                 ; 2c705d14
	v_cvt_f32_ubyte3_e32 v34, v62                               ; 7e44293e
	v_cvt_f32_ubyte2_e32 v35, v62                               ; 7e46273e
	v_cvt_f32_ubyte1_e32 v36, v62                               ; 7e48253e
	v_cvt_f32_ubyte0_e32 v62, v62                               ; 7e7c233e
	v_and_b32_e32 v49, s11, v49                                 ; 2662620b
	v_mul_f32_e32 v34, v27, v34                                 ; 0a44451b
	v_cvt_f32_ubyte3_e32 v40, v49                               ; 7e502931
	v_cvt_f32_ubyte1_e32 v46, v49                               ; 7e5c2531
	v_cvt_f32_ubyte2_e32 v45, v49                               ; 7e5a2731
	v_cvt_f32_ubyte0_e32 v49, v49                               ; 7e622331
	v_add_u32_e32 v0, 4, v0                                     ; 68000084
	v_mac_f32_e32 v34, v26, v35                                 ; 2c44471a
	v_mul_f32_e32 v40, v31, v40                                 ; 0a50511f
	s_waitcnt vmcnt(7)                                          ; bf8c3f77
	v_lshrrev_b32_e32 v52, v5, v52                              ; 20686905
	v_lshrrev_b32_sdwa v53, v5, v53 dst_sel:WORD_1 dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:DWORD ; 206a6af9 06060505
	v_mac_f32_e32 v34, v25, v36                                 ; 2c444919
	v_mac_f32_e32 v40, v30, v45                                 ; 2c505b1e
	v_bfi_b32 v53, s10, v53, v52                                ; d1ca0035 04d26a0a
	v_mac_f32_e32 v34, v24, v62                                 ; 2c447d18
	v_mac_f32_e32 v40, v29, v46                                 ; 2c505d1d
	s_waitcnt vmcnt(6)                                          ; bf8c3f76
	v_lshl_or_b32 v48, v48, 12, v48                             ; d2000030 04c11930
	v_mac_f32_e32 v40, v28, v49                                 ; 2c50631c
	v_mul_f32_e32 v40, v40, v37                                 ; 0a504b28
	v_mac_f32_e32 v40, v34, v54                                 ; 2c506d22
	v_cvt_f32_f16_sdwa v54, v51 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e6c16f9 00050633
	v_cvt_f32_f16_e32 v51, v51                                  ; 7e661733
	v_mac_f32_e32 v40, v56, v38                                 ; 2c504d38
	v_mac_f32_e32 v40, v47, v41                                 ; 2c50532f
	v_and_b32_e32 v47, s12, v53                                 ; 265e6a0c
	v_and_b32_e32 v53, s13, v53                                 ; 266a6a0d
	v_mac_f32_e32 v10, v39, v40                                 ; 2c145127
	v_lshrrev_b32_e32 v47, 2, v47                               ; 205e5e82
	v_cvt_f32_ubyte3_e32 v49, v53                               ; 7e622935
	s_waitcnt vmcnt(5)                                          ; bf8c3f75
	v_and_b32_e32 v62, s11, v58                                 ; 267c740b
	v_cvt_f32_ubyte1_e32 v52, v53                               ; 7e682535
	v_cvt_f32_ubyte2_e32 v50, v53                               ; 7e642735
	v_cvt_f32_ubyte0_e32 v53, v53                               ; 7e6a2335
	v_and_or_b32 v48, s11, v48, v47                             ; d2010030 04be600b
	v_cvt_f32_ubyte3_e32 v34, v62                               ; 7e44293e
	v_cvt_f32_ubyte2_e32 v35, v62                               ; 7e46273e
	v_cvt_f32_ubyte1_e32 v36, v62                               ; 7e48253e
	v_cvt_f32_ubyte0_e32 v62, v62                               ; 7e7c233e
	v_cvt_f32_ubyte3_e32 v55, v48                               ; 7e6e2930
	v_cvt_f32_ubyte1_e32 v61, v48                               ; 7e7a2530
	v_cvt_f32_ubyte2_e32 v56, v48                               ; 7e702730
	v_cvt_f32_ubyte0_e32 v48, v48                               ; 7e602330
	v_mul_f32_e32 v34, v19, v34                                 ; 0a444513
	v_lshrrev_b32_e32 v58, 4, v58                               ; 20747484
	v_mul_f32_e32 v55, v32, v55                                 ; 0a6e6f20
	v_mac_f32_e32 v34, v18, v35                                 ; 2c444712
	v_and_b32_e32 v58, s11, v58                                 ; 2674740b
	v_mac_f32_e32 v55, v15, v56                                 ; 2c6e710f
	s_waitcnt vmcnt(4)                                          ; bf8c3f74
	v_and_b32_e32 v40, s11, v59                                 ; 2650760b
	v_mac_f32_e32 v34, v17, v36                                 ; 2c444911
	v_cvt_f32_ubyte1_e32 v39, v58                               ; 7e4e253a
	v_cvt_f32_ubyte2_e32 v38, v58                               ; 7e4c273a
	v_cvt_f32_ubyte3_e32 v37, v58                               ; 7e4a293a
	v_cvt_f32_ubyte0_e32 v58, v58                               ; 7e74233a
	v_mac_f32_e32 v55, v14, v49                                 ; 2c6e630e
	v_cvt_f32_ubyte2_e32 v45, v40                               ; 7e5a2728
	v_cvt_f32_ubyte3_e32 v41, v40                               ; 7e522928
	v_cvt_f32_ubyte1_e32 v46, v40                               ; 7e5c2528
	v_mac_f32_e32 v34, v16, v62                                 ; 2c447d10
	v_cvt_f32_ubyte0_e32 v40, v40                               ; 7e502328
	v_mul_f32_e32 v37, v23, v37                                 ; 0a4a4b17
	v_lshrrev_b32_e32 v59, 4, v59                               ; 20767684
	v_mac_f32_e32 v55, v13, v50                                 ; 2c6e650d
	v_mul_f32_e32 v41, v27, v41                                 ; 0a52531b
	v_mac_f32_e32 v37, v22, v38                                 ; 2c4a4d16
	v_and_b32_e32 v59, s11, v59                                 ; 2676760b
	v_mad_f32 v11, -v54, v55, v11                               ; d1c1000b 242e6f36
	v_mac_f32_e32 v41, v26, v45                                 ; 2c525b1a
	v_mac_f32_e32 v37, v21, v39                                 ; 2c4a4f15
	v_cvt_f32_ubyte1_e32 v50, v59                               ; 7e64253b
	v_cvt_f32_ubyte2_e32 v49, v59                               ; 7e62273b
	v_cvt_f32_ubyte3_e32 v47, v59                               ; 7e5e293b
	v_cvt_f32_ubyte0_e32 v59, v59                               ; 7e76233b
	v_mac_f32_e32 v41, v25, v46                                 ; 2c525d19
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_lshrrev_b32_e32 v43, v5, v43                              ; 20565705
	v_mac_f32_e32 v37, v20, v58                                 ; 2c4a7514
	v_lshrrev_b32_sdwa v44, v5, v44 dst_sel:WORD_1 dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:DWORD ; 205858f9 06060505
	v_mul_f32_e32 v47, v31, v47                                 ; 0a5e5f1f
	v_mac_f32_e32 v41, v24, v40                                 ; 2c525118
	v_bfi_b32 v44, s10, v44, v43                                ; d1ca002c 04ae580a
	v_mac_f32_e32 v47, v30, v49                                 ; 2c5e631e
	v_cvt_f32_f16_sdwa v55, v42 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e6e16f9 0005062a
	v_cvt_f32_f16_e32 v42, v42                                  ; 7e54172a
	v_mac_f32_e32 v47, v29, v50                                 ; 2c5e651d
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_lshl_or_b32 v33, v33, 12, v33                             ; d2000021 04851921
	v_mac_f32_e32 v47, v28, v59                                 ; 2c5e771c
	v_mul_f32_e32 v47, v47, v61                                 ; 0a5e7b2f
	v_mac_f32_e32 v47, v41, v48                                 ; 2c5e6129
	v_mac_f32_e32 v47, v37, v52                                 ; 2c5e6925
	v_mac_f32_e32 v47, v34, v53                                 ; 2c5e6b22
	v_mac_f32_e32 v11, v51, v47                                 ; 2c165f33
	v_and_b32_e32 v51, s12, v44                                 ; 2666580c
	v_and_b32_e32 v44, s13, v44                                 ; 2658580d
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v61, s11, v57                                 ; 267a720b
	v_lshrrev_b32_e32 v51, 2, v51                               ; 20666682
	v_cvt_f32_ubyte1_e32 v54, v44                               ; 7e6c252c
	v_cvt_f32_ubyte3_e32 v52, v44                               ; 7e68292c
	v_cvt_f32_ubyte2_e32 v53, v44                               ; 7e6a272c
	v_cvt_f32_ubyte0_e32 v44, v44                               ; 7e58232c
	v_cvt_f32_ubyte3_e32 v62, v61                               ; 7e7c293d
	v_and_or_b32 v33, s11, v33, v51                             ; d2010021 04ce420b
	v_mul_f32_e32 v19, v19, v62                                 ; 0a267d13
	v_cvt_f32_ubyte2_e32 v62, v61                               ; 7e7c273d
	v_cvt_f32_ubyte2_e32 v58, v33                               ; 7e742721
	v_cvt_f32_ubyte1_e32 v59, v33                               ; 7e762521
	v_lshrrev_b32_e32 v57, 4, v57                               ; 20727284
	v_cvt_f32_ubyte3_e32 v56, v33                               ; 7e702921
	v_cvt_f32_ubyte0_e32 v33, v33                               ; 7e422321
	v_mac_f32_e32 v19, v18, v62                                 ; 2c267d12
	v_cvt_f32_ubyte1_e32 v62, v61                               ; 7e7c253d
	v_cvt_f32_ubyte0_e32 v61, v61                               ; 7e7a233d
	v_and_b32_e32 v57, s11, v57                                 ; 2672720b
	v_mul_f32_e32 v32, v32, v56                                 ; 0a407120
	v_mac_f32_e32 v19, v17, v62                                 ; 2c267d11
	v_cvt_f32_ubyte3_e32 v62, v57                               ; 7e7c2939
	v_mac_f32_e32 v32, v15, v58                                 ; 2c40750f
	v_mac_f32_e32 v19, v16, v61                                 ; 2c267b10
	v_mul_f32_e32 v23, v23, v62                                 ; 0a2e7d17
	v_cvt_f32_ubyte2_e32 v62, v57                               ; 7e7c2739
	v_mac_f32_e32 v32, v14, v52                                 ; 2c40690e
	v_mac_f32_e32 v23, v22, v62                                 ; 2c2e7d16
	v_cvt_f32_ubyte1_e32 v62, v57                               ; 7e7c2539
	v_cvt_f32_ubyte0_e32 v57, v57                               ; 7e722339
	v_mac_f32_e32 v32, v13, v53                                 ; 2c406b0d
	v_mac_f32_e32 v23, v21, v62                                 ; 2c2e7d15
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v62, s11, v60                                 ; 267c780b
	v_lshrrev_b32_e32 v60, 4, v60                               ; 20787884
	v_mad_f32 v12, -v55, v32, v12                               ; d1c1000c 24324137
	v_mac_f32_e32 v23, v20, v57                                 ; 2c2e7314
	v_cvt_f32_ubyte2_e32 v14, v62                               ; 7e1c273e
	v_cvt_f32_ubyte1_e32 v15, v62                               ; 7e1e253e
	v_cvt_f32_ubyte3_e32 v13, v62                               ; 7e1a293e
	v_cvt_f32_ubyte0_e32 v62, v62                               ; 7e7c233e
	v_and_b32_e32 v60, s11, v60                                 ; 2678780b
	v_mul_f32_e32 v27, v27, v13                                 ; 0a361b1b
	v_cvt_f32_ubyte2_e32 v17, v60                               ; 7e22273c
	v_cvt_f32_ubyte3_e32 v16, v60                               ; 7e20293c
	v_cvt_f32_ubyte1_e32 v18, v60                               ; 7e24253c
	v_cvt_f32_ubyte0_e32 v60, v60                               ; 7e78233c
	v_mac_f32_e32 v27, v26, v14                                 ; 2c361d1a
	v_mul_f32_e32 v31, v31, v16                                 ; 0a3e211f
	v_mac_f32_e32 v27, v25, v15                                 ; 2c361f19
	v_mac_f32_e32 v31, v30, v17                                 ; 2c3e231e
	v_mac_f32_e32 v27, v24, v62                                 ; 2c367d18
	v_mac_f32_e32 v31, v29, v18                                 ; 2c3e251d
	v_mac_f32_e32 v31, v28, v60                                 ; 2c3e791c
	v_mul_f32_e32 v31, v31, v59                                 ; 0a3e771f
	v_mac_f32_e32 v31, v27, v33                                 ; 2c3e431b
	v_mac_f32_e32 v31, v23, v54                                 ; 2c3e6d17
	v_mac_f32_e32 v31, v19, v44                                 ; 2c3e5913
	v_mac_f32_e32 v12, v42, v31                                 ; 2c183f2a
BB5:
	s_mov_b64 s[0:1], exec                                      ; be80017e
	v_cmpx_le_u32_e32 vcc, s3, v0                               ; 7db60003
BB6:
	s_andn2_b64 s[0:1], s[0:1], exec                            ; 89807e00
	s_cbranch_scc1 BB10                                         ; bf85fcd0
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
	s_mov_b64 exec, s[10:11]                                    ; befe010a
	v_readlane_b32 s4, v63, 63                                  ; d2890004 00017f3f
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
	v_readlane_b32 s5, v63, 63                                  ; d2890005 00017f3f
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
	v_readlane_b32 s6, v63, 63                                  ; d2890006 00017f3f
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
	v_readlane_b32 s9, v63, 63                                  ; d2890009 00017f3f
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
	s_branch BB203                                              ; bf8205ac
BB66:
	s_cmp_lt_u32 s16, s4                                        ; bf0a0410
	s_cbranch_scc0 BB203                                        ; bf8405aa
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
	v_lshl_add_u32 v1, v1, 1, v3                                ; d1fd0001 040d0301
	v_mov_b32_e32 v3, 0                                         ; 7e060280
	v_lshlrev_b32_e32 v5, 4, v2                                 ; 240a0484
	v_lshlrev_b32_e32 v1, 2, v1                                 ; 24020282
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
	v_lshl_add_u32 v13, v0, 8, v1                               ; d1fd000d 04051100
	v_add_u32_e32 v14, s5, v13                                  ; 681c1a05
	v_add_u32_e32 v13, 0x80, v13                                ; 681a1aff 00000080
	v_lshrrev_b32_e32 v14, 2, v14                               ; 201c1c82
	v_add_u32_e32 v13, s5, v13                                  ; 681a1a05
	v_lshlrev_b32_e32 v14, 4, v14                               ; 241c1c84
	v_lshrrev_b32_e32 v13, 2, v13                               ; 201a1a82
	v_lshlrev_b32_e32 v13, 4, v13                               ; 241a1a84
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_load_dwordx4 v[16:19], v14, s[12:15], 0 offen        ; e05c1000 8003100e
	buffer_load_dwordx4 v[20:23], v14, s[12:15], 0 offen offset:128 ; e05c1080 8003140e
	buffer_load_dwordx4 v[24:27], v13, s[12:15], 0 offen        ; e05c1000 8003180d
	buffer_load_dwordx4 v[28:31], v13, s[12:15], 0 offen offset:128 ; e05c1080 80031c0d
	s_cmp_lg_i32 s4, 0                                          ; bf018004
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_add_f32_e32 v15, v16, v17                                 ; 021e2310
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_add_f32_e32 v32, v20, v21                                 ; 02402b14
	v_add_f32_e32 v15, v15, v18                                 ; 021e250f
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_add_f32_e32 v33, v24, v25                                 ; 02423318
	v_add_f32_e32 v32, v32, v22                                 ; 02402d20
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_add_f32_e32 v34, v28, v29                                 ; 02443b1c
	v_add_f32_e32 v15, v15, v19                                 ; 021e270f
	v_add_f32_e32 v33, v33, v26                                 ; 02423521
	v_add_f32_e32 v32, v32, v23                                 ; 02402f20
	v_add_f32_e32 v34, v34, v30                                 ; 02443d22
	v_add_f32_e32 v33, v33, v27                                 ; 02423721
	v_add_f32_e32 v34, v34, v31                                 ; 02443f22
	s_cbranch_scc0 BB100                                        ; bf84033b
BB77:
	s_load_dwordx4 s[12:15], s[0:1], 0x0                        ; c00a0300 00000000
	s_mul_i32 s0, s16, s3                                       ; 92000310
	v_lshl_add_u32 v35, v2, 1, 8                                ; d1fd0023 02210302
	v_add_u32_e32 v39, 64, v4                                   ; 684e08c0
	s_add_u32 s0, s19, s0                                       ; 80000013
	v_add_u32_e32 v13, s0, v0                                   ; 681a0000
	v_lshlrev_b32_e32 v14, 4, v13                               ; 241c1a84
	v_lshl_add_u32 v13, v13, 7, v14                             ; d1fd000d 04390f0d
	v_add3_u32 v36, v35, 4, v13                                 ; d1ff0024 04350923
	v_add_u32_e32 v37, 16, v13                                  ; 684a1a90
	v_add_u32_e32 v38, v37, v4                                  ; 684c0925
	v_add_u32_e32 v37, v37, v39                                 ; 684a4f25
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_load_dwordx3 v[40:42], v13, s[12:15], 0 offen        ; e0581000 8003280d
	buffer_load_ushort v36, v36, s[12:15], 0 offen              ; e0481000 80032424
	buffer_load_dword v38, v38, s[12:15], 0 offen               ; e0501000 80032626
	buffer_load_dword v37, v37, s[12:15], 0 offen               ; e0501000 80032525
	s_bfm_b32 s1, 16, 16                                        ; 91019090
	s_mov_b32 s5, 0xf0f0f0f                                     ; be8500ff 0f0f0f0f
	s_cmp_lt_u32 1, s4                                          ; bf0a0481
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_lshrrev_b32_sdwa v42, v5, v42 dst_sel:WORD_1 dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:DWORD ; 205454f9 06060505
	v_lshrrev_b32_e32 v41, v5, v41                              ; 20525305
	v_cvt_f32_f16_sdwa v47, v40 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e5e16f9 00050628
	v_cvt_f32_f16_e32 v40, v40                                  ; 7e501728
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_lshl_or_b32 v36, v36, 12, v36                             ; d2000024 04911924
	v_bfi_b32 v42, s1, v42, v41                                 ; d1ca002a 04a65401
	v_and_b32_e32 v43, 0xc0c0c0c0, v42                          ; 265654ff c0c0c0c0
	v_and_b32_e32 v42, 0x3f3f3f3f, v42                          ; 265454ff 3f3f3f3f
	v_lshrrev_b32_e32 v43, 2, v43                               ; 20565682
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v51, s5, v38                                  ; 26664c05
	v_cvt_f32_ubyte3_e32 v44, v42                               ; 7e58292a
	v_cvt_f32_ubyte2_e32 v45, v42                               ; 7e5a272a
	v_cvt_f32_ubyte1_e32 v46, v42                               ; 7e5c252a
	v_cvt_f32_ubyte0_e32 v42, v42                               ; 7e54232a
	v_and_or_b32 v36, s5, v36, v43                              ; d2010024 04ae4805
	v_cvt_f32_ubyte3_e32 v52, v51                               ; 7e682933
	v_cvt_f32_ubyte2_e32 v53, v51                               ; 7e6a2733
	v_cvt_f32_ubyte1_e32 v54, v51                               ; 7e6c2533
	v_cvt_f32_ubyte0_e32 v51, v51                               ; 7e662333
	v_cvt_f32_ubyte3_e32 v48, v36                               ; 7e602924
	v_cvt_f32_ubyte2_e32 v49, v36                               ; 7e622724
	v_cvt_f32_ubyte1_e32 v50, v36                               ; 7e642524
	v_cvt_f32_ubyte0_e32 v36, v36                               ; 7e482324
	v_mul_f32_e32 v52, v19, v52                                 ; 0a686913
	v_lshrrev_b32_e32 v38, 4, v38                               ; 204c4c84
	v_mul_f32_e32 v48, v34, v48                                 ; 0a606122
	v_mac_f32_e32 v52, v18, v53                                 ; 2c686b12
	v_and_b32_e32 v38, s5, v38                                  ; 264c4c05
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v58, s5, v37                                  ; 26744a05
	v_mac_f32_e32 v48, v33, v49                                 ; 2c606321
	v_mac_f32_e32 v52, v17, v54                                 ; 2c686d11
	v_cvt_f32_ubyte3_e32 v55, v38                               ; 7e6e2926
	v_cvt_f32_ubyte2_e32 v56, v38                               ; 7e702726
	v_cvt_f32_ubyte1_e32 v57, v38                               ; 7e722526
	v_cvt_f32_ubyte0_e32 v38, v38                               ; 7e4c2326
	v_cvt_f32_ubyte2_e32 v60, v58                               ; 7e78273a
	v_cvt_f32_ubyte3_e32 v59, v58                               ; 7e76293a
	v_mac_f32_e32 v48, v32, v44                                 ; 2c605920
	v_cvt_f32_ubyte1_e32 v61, v58                               ; 7e7a253a
	v_mac_f32_e32 v52, v16, v51                                 ; 2c686710
	v_mul_f32_e32 v55, v23, v55                                 ; 0a6e6f17
	v_cvt_f32_ubyte0_e32 v58, v58                               ; 7e74233a
	v_lshrrev_b32_e32 v37, 4, v37                               ; 204a4a84
	v_mul_f32_e32 v59, v27, v59                                 ; 0a76771b
	v_mac_f32_e32 v48, v15, v45                                 ; 2c605b0f
	v_mac_f32_e32 v55, v22, v56                                 ; 2c6e7116
	v_and_b32_e32 v37, s5, v37                                  ; 264a4a05
	v_mac_f32_e32 v59, v26, v60                                 ; 2c76791a
	v_mad_f32 v3, -v47, v48, v3                                 ; d1c10003 240e612f
	v_mac_f32_e32 v55, v21, v57                                 ; 2c6e7315
	v_cvt_f32_ubyte1_e32 v14, v37                               ; 7e1c2525
	v_cvt_f32_ubyte2_e32 v13, v37                               ; 7e1a2725
	v_cvt_f32_ubyte3_e32 v62, v37                               ; 7e7c2925
	v_cvt_f32_ubyte0_e32 v37, v37                               ; 7e4a2325
	v_mac_f32_e32 v59, v25, v61                                 ; 2c767b19
	v_mac_f32_e32 v55, v20, v38                                 ; 2c6e4d14
	v_mul_f32_e32 v62, v31, v62                                 ; 0a7c7d1f
	v_mac_f32_e32 v59, v24, v58                                 ; 2c767518
	v_mac_f32_e32 v62, v30, v13                                 ; 2c7c1b1e
	v_mac_f32_e32 v62, v29, v14                                 ; 2c7c1d1d
	v_mac_f32_e32 v62, v28, v37                                 ; 2c7c4b1c
	v_mul_f32_e32 v62, v62, v50                                 ; 0a7c653e
	v_mac_f32_e32 v62, v59, v36                                 ; 2c7c493b
	v_mac_f32_e32 v62, v55, v46                                 ; 2c7c5d37
	v_mac_f32_e32 v62, v52, v42                                 ; 2c7c5534
	v_mac_f32_e32 v3, v40, v62                                  ; 2c067d28
	s_cbranch_scc0 BB100                                        ; bf8402cf
BB78:
	s_add_u32 s0, s16, 1                                        ; 80008110
	s_mul_i32 s0, s0, s3                                        ; 92000300
	s_add_u32 s0, s19, s0                                       ; 80000013
	v_add_u32_e32 v13, s0, v0                                   ; 681a0000
	v_lshlrev_b32_e32 v14, 4, v13                               ; 241c1a84
	v_lshl_add_u32 v13, v13, 7, v14                             ; d1fd000d 04390f0d
	v_add3_u32 v36, v35, 4, v13                                 ; d1ff0024 04350923
	v_add_u32_e32 v37, 16, v13                                  ; 684a1a90
	v_add_u32_e32 v38, v37, v4                                  ; 684c0925
	v_add_u32_e32 v37, v37, v39                                 ; 684a4f25
	buffer_load_dwordx3 v[40:42], v13, s[12:15], 0 offen        ; e0581000 8003280d
	buffer_load_ushort v36, v36, s[12:15], 0 offen              ; e0481000 80032424
	buffer_load_dword v38, v38, s[12:15], 0 offen               ; e0501000 80032626
	buffer_load_dword v37, v37, s[12:15], 0 offen               ; e0501000 80032525
	s_bfm_b32 s1, 16, 16                                        ; 91019090
	s_mov_b32 s5, 0xf0f0f0f                                     ; be8500ff 0f0f0f0f
	s_cmp_lt_u32 2, s4                                          ; bf0a0482
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_lshrrev_b32_e32 v41, v5, v41                              ; 20525305
	v_lshrrev_b32_sdwa v42, v5, v42 dst_sel:WORD_1 dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:DWORD ; 205454f9 06060505
	v_cvt_f32_f16_sdwa v47, v40 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e5e16f9 00050628
	v_cvt_f32_f16_e32 v40, v40                                  ; 7e501728
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_lshl_or_b32 v36, v36, 12, v36                             ; d2000024 04911924
	v_bfi_b32 v42, s1, v42, v41                                 ; d1ca002a 04a65401
	v_and_b32_e32 v43, 0xc0c0c0c0, v42                          ; 265654ff c0c0c0c0
	v_and_b32_e32 v42, 0x3f3f3f3f, v42                          ; 265454ff 3f3f3f3f
	v_lshrrev_b32_e32 v43, 2, v43                               ; 20565682
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v51, s5, v38                                  ; 26664c05
	v_cvt_f32_ubyte3_e32 v44, v42                               ; 7e58292a
	v_cvt_f32_ubyte2_e32 v45, v42                               ; 7e5a272a
	v_cvt_f32_ubyte1_e32 v46, v42                               ; 7e5c252a
	v_cvt_f32_ubyte0_e32 v42, v42                               ; 7e54232a
	v_and_or_b32 v36, s5, v36, v43                              ; d2010024 04ae4805
	v_cvt_f32_ubyte3_e32 v52, v51                               ; 7e682933
	v_cvt_f32_ubyte2_e32 v53, v51                               ; 7e6a2733
	v_cvt_f32_ubyte1_e32 v54, v51                               ; 7e6c2533
	v_cvt_f32_ubyte0_e32 v51, v51                               ; 7e662333
	v_cvt_f32_ubyte2_e32 v49, v36                               ; 7e622724
	v_cvt_f32_ubyte1_e32 v50, v36                               ; 7e642524
	v_cvt_f32_ubyte3_e32 v48, v36                               ; 7e602924
	v_cvt_f32_ubyte0_e32 v36, v36                               ; 7e482324
	v_mul_f32_e32 v52, v19, v52                                 ; 0a686913
	v_lshrrev_b32_e32 v38, 4, v38                               ; 204c4c84
	v_mul_f32_e32 v48, v34, v48                                 ; 0a606122
	v_mac_f32_e32 v52, v18, v53                                 ; 2c686b12
	v_and_b32_e32 v38, s5, v38                                  ; 264c4c05
	v_mac_f32_e32 v48, v33, v49                                 ; 2c606321
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v58, s5, v37                                  ; 26744a05
	v_mac_f32_e32 v52, v17, v54                                 ; 2c686d11
	v_cvt_f32_ubyte1_e32 v57, v38                               ; 7e722526
	v_cvt_f32_ubyte2_e32 v56, v38                               ; 7e702726
	v_cvt_f32_ubyte3_e32 v55, v38                               ; 7e6e2926
	v_cvt_f32_ubyte0_e32 v38, v38                               ; 7e4c2326
	v_mac_f32_e32 v48, v32, v44                                 ; 2c605920
	v_cvt_f32_ubyte2_e32 v60, v58                               ; 7e78273a
	v_cvt_f32_ubyte3_e32 v59, v58                               ; 7e76293a
	v_cvt_f32_ubyte1_e32 v61, v58                               ; 7e7a253a
	v_mac_f32_e32 v52, v16, v51                                 ; 2c686710
	v_cvt_f32_ubyte0_e32 v58, v58                               ; 7e74233a
	v_mul_f32_e32 v55, v23, v55                                 ; 0a6e6f17
	v_lshrrev_b32_e32 v37, 4, v37                               ; 204a4a84
	v_mac_f32_e32 v48, v15, v45                                 ; 2c605b0f
	v_mul_f32_e32 v59, v27, v59                                 ; 0a76771b
	v_mac_f32_e32 v55, v22, v56                                 ; 2c6e7116
	v_and_b32_e32 v37, s5, v37                                  ; 264a4a05
	v_mad_f32 v6, -v47, v48, v6                                 ; d1c10006 241a612f
	v_mac_f32_e32 v59, v26, v60                                 ; 2c76791a
	v_mac_f32_e32 v55, v21, v57                                 ; 2c6e7315
	v_cvt_f32_ubyte1_e32 v14, v37                               ; 7e1c2525
	v_cvt_f32_ubyte2_e32 v13, v37                               ; 7e1a2725
	v_cvt_f32_ubyte3_e32 v62, v37                               ; 7e7c2925
	v_cvt_f32_ubyte0_e32 v37, v37                               ; 7e4a2325
	v_mac_f32_e32 v59, v25, v61                                 ; 2c767b19
	v_mac_f32_e32 v55, v20, v38                                 ; 2c6e4d14
	v_mul_f32_e32 v62, v31, v62                                 ; 0a7c7d1f
	v_mac_f32_e32 v59, v24, v58                                 ; 2c767518
	v_mac_f32_e32 v62, v30, v13                                 ; 2c7c1b1e
	v_mac_f32_e32 v62, v29, v14                                 ; 2c7c1d1d
	v_mac_f32_e32 v62, v28, v37                                 ; 2c7c4b1c
	v_mul_f32_e32 v62, v62, v50                                 ; 0a7c653e
	v_mac_f32_e32 v62, v59, v36                                 ; 2c7c493b
	v_mac_f32_e32 v62, v55, v46                                 ; 2c7c5d37
	v_mac_f32_e32 v62, v52, v42                                 ; 2c7c5534
	v_mac_f32_e32 v6, v40, v62                                  ; 2c0c7d28
	s_cbranch_scc0 BB100                                        ; bf840268
BB79:
	s_add_u32 s0, s16, 2                                        ; 80008210
	s_mul_i32 s0, s0, s3                                        ; 92000300
	s_add_u32 s0, s19, s0                                       ; 80000013
	v_add_u32_e32 v13, s0, v0                                   ; 681a0000
	v_lshlrev_b32_e32 v14, 4, v13                               ; 241c1a84
	v_lshl_add_u32 v13, v13, 7, v14                             ; d1fd000d 04390f0d
	v_add3_u32 v36, v35, 4, v13                                 ; d1ff0024 04350923
	v_add_u32_e32 v37, 16, v13                                  ; 684a1a90
	v_add_u32_e32 v38, v37, v4                                  ; 684c0925
	v_add_u32_e32 v37, v37, v39                                 ; 684a4f25
	buffer_load_dwordx3 v[40:42], v13, s[12:15], 0 offen        ; e0581000 8003280d
	buffer_load_ushort v36, v36, s[12:15], 0 offen              ; e0481000 80032424
	buffer_load_dword v38, v38, s[12:15], 0 offen               ; e0501000 80032626
	buffer_load_dword v37, v37, s[12:15], 0 offen               ; e0501000 80032525
	s_bfm_b32 s1, 16, 16                                        ; 91019090
	s_mov_b32 s5, 0xf0f0f0f                                     ; be8500ff 0f0f0f0f
	s_cmp_lt_u32 3, s4                                          ; bf0a0483
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_lshrrev_b32_e32 v41, v5, v41                              ; 20525305
	v_lshrrev_b32_sdwa v42, v5, v42 dst_sel:WORD_1 dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:DWORD ; 205454f9 06060505
	v_cvt_f32_f16_sdwa v47, v40 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e5e16f9 00050628
	v_cvt_f32_f16_e32 v40, v40                                  ; 7e501728
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_lshl_or_b32 v36, v36, 12, v36                             ; d2000024 04911924
	v_bfi_b32 v42, s1, v42, v41                                 ; d1ca002a 04a65401
	v_and_b32_e32 v43, 0xc0c0c0c0, v42                          ; 265654ff c0c0c0c0
	v_and_b32_e32 v42, 0x3f3f3f3f, v42                          ; 265454ff 3f3f3f3f
	v_lshrrev_b32_e32 v43, 2, v43                               ; 20565682
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v51, s5, v38                                  ; 26664c05
	v_cvt_f32_ubyte3_e32 v44, v42                               ; 7e58292a
	v_cvt_f32_ubyte2_e32 v45, v42                               ; 7e5a272a
	v_cvt_f32_ubyte1_e32 v46, v42                               ; 7e5c252a
	v_cvt_f32_ubyte0_e32 v42, v42                               ; 7e54232a
	v_and_or_b32 v36, s5, v36, v43                              ; d2010024 04ae4805
	v_cvt_f32_ubyte3_e32 v52, v51                               ; 7e682933
	v_cvt_f32_ubyte2_e32 v53, v51                               ; 7e6a2733
	v_cvt_f32_ubyte1_e32 v54, v51                               ; 7e6c2533
	v_cvt_f32_ubyte0_e32 v51, v51                               ; 7e662333
	v_cvt_f32_ubyte2_e32 v49, v36                               ; 7e622724
	v_cvt_f32_ubyte1_e32 v50, v36                               ; 7e642524
	v_cvt_f32_ubyte3_e32 v48, v36                               ; 7e602924
	v_cvt_f32_ubyte0_e32 v36, v36                               ; 7e482324
	v_mul_f32_e32 v52, v19, v52                                 ; 0a686913
	v_lshrrev_b32_e32 v38, 4, v38                               ; 204c4c84
	v_mul_f32_e32 v48, v34, v48                                 ; 0a606122
	v_mac_f32_e32 v52, v18, v53                                 ; 2c686b12
	v_and_b32_e32 v38, s5, v38                                  ; 264c4c05
	v_mac_f32_e32 v48, v33, v49                                 ; 2c606321
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v58, s5, v37                                  ; 26744a05
	v_mac_f32_e32 v52, v17, v54                                 ; 2c686d11
	v_cvt_f32_ubyte1_e32 v57, v38                               ; 7e722526
	v_cvt_f32_ubyte2_e32 v56, v38                               ; 7e702726
	v_cvt_f32_ubyte3_e32 v55, v38                               ; 7e6e2926
	v_cvt_f32_ubyte0_e32 v38, v38                               ; 7e4c2326
	v_mac_f32_e32 v48, v32, v44                                 ; 2c605920
	v_cvt_f32_ubyte2_e32 v60, v58                               ; 7e78273a
	v_cvt_f32_ubyte3_e32 v59, v58                               ; 7e76293a
	v_cvt_f32_ubyte1_e32 v61, v58                               ; 7e7a253a
	v_mac_f32_e32 v52, v16, v51                                 ; 2c686710
	v_cvt_f32_ubyte0_e32 v58, v58                               ; 7e74233a
	v_mul_f32_e32 v55, v23, v55                                 ; 0a6e6f17
	v_lshrrev_b32_e32 v37, 4, v37                               ; 204a4a84
	v_mac_f32_e32 v48, v15, v45                                 ; 2c605b0f
	v_mul_f32_e32 v59, v27, v59                                 ; 0a76771b
	v_mac_f32_e32 v55, v22, v56                                 ; 2c6e7116
	v_and_b32_e32 v37, s5, v37                                  ; 264a4a05
	v_mad_f32 v7, -v47, v48, v7                                 ; d1c10007 241e612f
	v_mac_f32_e32 v59, v26, v60                                 ; 2c76791a
	v_mac_f32_e32 v55, v21, v57                                 ; 2c6e7315
	v_cvt_f32_ubyte1_e32 v14, v37                               ; 7e1c2525
	v_cvt_f32_ubyte2_e32 v13, v37                               ; 7e1a2725
	v_cvt_f32_ubyte3_e32 v62, v37                               ; 7e7c2925
	v_cvt_f32_ubyte0_e32 v37, v37                               ; 7e4a2325
	v_mac_f32_e32 v59, v25, v61                                 ; 2c767b19
	v_mac_f32_e32 v55, v20, v38                                 ; 2c6e4d14
	v_mul_f32_e32 v62, v31, v62                                 ; 0a7c7d1f
	v_mac_f32_e32 v59, v24, v58                                 ; 2c767518
	v_mac_f32_e32 v62, v30, v13                                 ; 2c7c1b1e
	v_mac_f32_e32 v62, v29, v14                                 ; 2c7c1d1d
	v_mac_f32_e32 v62, v28, v37                                 ; 2c7c4b1c
	v_mul_f32_e32 v62, v62, v50                                 ; 0a7c653e
	v_mac_f32_e32 v62, v59, v36                                 ; 2c7c493b
	v_mac_f32_e32 v62, v55, v46                                 ; 2c7c5d37
	v_mac_f32_e32 v62, v52, v42                                 ; 2c7c5534
	v_mac_f32_e32 v7, v40, v62                                  ; 2c0e7d28
	s_cbranch_scc0 BB100                                        ; bf840201
BB80:
	s_add_u32 s0, s16, 3                                        ; 80008310
	s_mul_i32 s0, s0, s3                                        ; 92000300
	s_add_u32 s0, s19, s0                                       ; 80000013
	v_add_u32_e32 v13, s0, v0                                   ; 681a0000
	v_lshlrev_b32_e32 v14, 4, v13                               ; 241c1a84
	v_lshl_add_u32 v13, v13, 7, v14                             ; d1fd000d 04390f0d
	v_add3_u32 v36, v35, 4, v13                                 ; d1ff0024 04350923
	v_add_u32_e32 v37, 16, v13                                  ; 684a1a90
	v_add_u32_e32 v38, v37, v4                                  ; 684c0925
	v_add_u32_e32 v37, v37, v39                                 ; 684a4f25
	buffer_load_dwordx3 v[40:42], v13, s[12:15], 0 offen        ; e0581000 8003280d
	buffer_load_ushort v36, v36, s[12:15], 0 offen              ; e0481000 80032424
	buffer_load_dword v38, v38, s[12:15], 0 offen               ; e0501000 80032626
	buffer_load_dword v37, v37, s[12:15], 0 offen               ; e0501000 80032525
	s_bfm_b32 s1, 16, 16                                        ; 91019090
	s_mov_b32 s5, 0xf0f0f0f                                     ; be8500ff 0f0f0f0f
	s_cmp_lt_u32 4, s4                                          ; bf0a0484
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_lshrrev_b32_e32 v41, v5, v41                              ; 20525305
	v_lshrrev_b32_sdwa v42, v5, v42 dst_sel:WORD_1 dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:DWORD ; 205454f9 06060505
	v_cvt_f32_f16_sdwa v47, v40 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e5e16f9 00050628
	v_cvt_f32_f16_e32 v40, v40                                  ; 7e501728
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_lshl_or_b32 v36, v36, 12, v36                             ; d2000024 04911924
	v_bfi_b32 v42, s1, v42, v41                                 ; d1ca002a 04a65401
	v_and_b32_e32 v43, 0xc0c0c0c0, v42                          ; 265654ff c0c0c0c0
	v_and_b32_e32 v42, 0x3f3f3f3f, v42                          ; 265454ff 3f3f3f3f
	v_lshrrev_b32_e32 v43, 2, v43                               ; 20565682
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v51, s5, v38                                  ; 26664c05
	v_cvt_f32_ubyte3_e32 v44, v42                               ; 7e58292a
	v_cvt_f32_ubyte2_e32 v45, v42                               ; 7e5a272a
	v_cvt_f32_ubyte1_e32 v46, v42                               ; 7e5c252a
	v_cvt_f32_ubyte0_e32 v42, v42                               ; 7e54232a
	v_and_or_b32 v36, s5, v36, v43                              ; d2010024 04ae4805
	v_cvt_f32_ubyte3_e32 v52, v51                               ; 7e682933
	v_cvt_f32_ubyte2_e32 v53, v51                               ; 7e6a2733
	v_cvt_f32_ubyte1_e32 v54, v51                               ; 7e6c2533
	v_cvt_f32_ubyte0_e32 v51, v51                               ; 7e662333
	v_cvt_f32_ubyte2_e32 v49, v36                               ; 7e622724
	v_cvt_f32_ubyte1_e32 v50, v36                               ; 7e642524
	v_cvt_f32_ubyte3_e32 v48, v36                               ; 7e602924
	v_cvt_f32_ubyte0_e32 v36, v36                               ; 7e482324
	v_mul_f32_e32 v52, v19, v52                                 ; 0a686913
	v_lshrrev_b32_e32 v38, 4, v38                               ; 204c4c84
	v_mul_f32_e32 v48, v34, v48                                 ; 0a606122
	v_mac_f32_e32 v52, v18, v53                                 ; 2c686b12
	v_and_b32_e32 v38, s5, v38                                  ; 264c4c05
	v_mac_f32_e32 v48, v33, v49                                 ; 2c606321
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v58, s5, v37                                  ; 26744a05
	v_mac_f32_e32 v52, v17, v54                                 ; 2c686d11
	v_cvt_f32_ubyte1_e32 v57, v38                               ; 7e722526
	v_cvt_f32_ubyte2_e32 v56, v38                               ; 7e702726
	v_cvt_f32_ubyte3_e32 v55, v38                               ; 7e6e2926
	v_cvt_f32_ubyte0_e32 v38, v38                               ; 7e4c2326
	v_mac_f32_e32 v48, v32, v44                                 ; 2c605920
	v_cvt_f32_ubyte2_e32 v60, v58                               ; 7e78273a
	v_cvt_f32_ubyte3_e32 v59, v58                               ; 7e76293a
	v_cvt_f32_ubyte1_e32 v61, v58                               ; 7e7a253a
	v_mac_f32_e32 v52, v16, v51                                 ; 2c686710
	v_cvt_f32_ubyte0_e32 v58, v58                               ; 7e74233a
	v_mul_f32_e32 v55, v23, v55                                 ; 0a6e6f17
	v_lshrrev_b32_e32 v37, 4, v37                               ; 204a4a84
	v_mac_f32_e32 v48, v15, v45                                 ; 2c605b0f
	v_mul_f32_e32 v59, v27, v59                                 ; 0a76771b
	v_mac_f32_e32 v55, v22, v56                                 ; 2c6e7116
	v_and_b32_e32 v37, s5, v37                                  ; 264a4a05
	v_mad_f32 v8, -v47, v48, v8                                 ; d1c10008 2422612f
	v_mac_f32_e32 v59, v26, v60                                 ; 2c76791a
	v_mac_f32_e32 v55, v21, v57                                 ; 2c6e7315
	v_cvt_f32_ubyte1_e32 v14, v37                               ; 7e1c2525
	v_cvt_f32_ubyte2_e32 v13, v37                               ; 7e1a2725
	v_cvt_f32_ubyte3_e32 v62, v37                               ; 7e7c2925
	v_cvt_f32_ubyte0_e32 v37, v37                               ; 7e4a2325
	v_mac_f32_e32 v59, v25, v61                                 ; 2c767b19
	v_mac_f32_e32 v55, v20, v38                                 ; 2c6e4d14
	v_mul_f32_e32 v62, v31, v62                                 ; 0a7c7d1f
	v_mac_f32_e32 v59, v24, v58                                 ; 2c767518
	v_mac_f32_e32 v62, v30, v13                                 ; 2c7c1b1e
	v_mac_f32_e32 v62, v29, v14                                 ; 2c7c1d1d
	v_mac_f32_e32 v62, v28, v37                                 ; 2c7c4b1c
	v_mul_f32_e32 v62, v62, v50                                 ; 0a7c653e
	v_mac_f32_e32 v62, v59, v36                                 ; 2c7c493b
	v_mac_f32_e32 v62, v55, v46                                 ; 2c7c5d37
	v_mac_f32_e32 v62, v52, v42                                 ; 2c7c5534
	v_mac_f32_e32 v8, v40, v62                                  ; 2c107d28
	s_cbranch_scc0 BB100                                        ; bf84019a
BB81:
	s_add_u32 s0, s16, 4                                        ; 80008410
	s_mul_i32 s0, s0, s3                                        ; 92000300
	s_add_u32 s0, s19, s0                                       ; 80000013
	v_add_u32_e32 v13, s0, v0                                   ; 681a0000
	v_lshlrev_b32_e32 v14, 4, v13                               ; 241c1a84
	v_lshl_add_u32 v13, v13, 7, v14                             ; d1fd000d 04390f0d
	v_add3_u32 v36, v35, 4, v13                                 ; d1ff0024 04350923
	v_add_u32_e32 v37, 16, v13                                  ; 684a1a90
	v_add_u32_e32 v38, v37, v4                                  ; 684c0925
	v_add_u32_e32 v37, v37, v39                                 ; 684a4f25
	buffer_load_dwordx3 v[40:42], v13, s[12:15], 0 offen        ; e0581000 8003280d
	buffer_load_ushort v36, v36, s[12:15], 0 offen              ; e0481000 80032424
	buffer_load_dword v38, v38, s[12:15], 0 offen               ; e0501000 80032626
	buffer_load_dword v37, v37, s[12:15], 0 offen               ; e0501000 80032525
	s_bfm_b32 s1, 16, 16                                        ; 91019090
	s_mov_b32 s5, 0xf0f0f0f                                     ; be8500ff 0f0f0f0f
	s_cmp_lt_u32 5, s4                                          ; bf0a0485
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_lshrrev_b32_e32 v41, v5, v41                              ; 20525305
	v_lshrrev_b32_sdwa v42, v5, v42 dst_sel:WORD_1 dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:DWORD ; 205454f9 06060505
	v_cvt_f32_f16_sdwa v47, v40 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e5e16f9 00050628
	v_cvt_f32_f16_e32 v40, v40                                  ; 7e501728
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_lshl_or_b32 v36, v36, 12, v36                             ; d2000024 04911924
	v_bfi_b32 v42, s1, v42, v41                                 ; d1ca002a 04a65401
	v_and_b32_e32 v43, 0xc0c0c0c0, v42                          ; 265654ff c0c0c0c0
	v_and_b32_e32 v42, 0x3f3f3f3f, v42                          ; 265454ff 3f3f3f3f
	v_lshrrev_b32_e32 v43, 2, v43                               ; 20565682
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v51, s5, v38                                  ; 26664c05
	v_cvt_f32_ubyte3_e32 v44, v42                               ; 7e58292a
	v_cvt_f32_ubyte2_e32 v45, v42                               ; 7e5a272a
	v_cvt_f32_ubyte1_e32 v46, v42                               ; 7e5c252a
	v_cvt_f32_ubyte0_e32 v42, v42                               ; 7e54232a
	v_and_or_b32 v36, s5, v36, v43                              ; d2010024 04ae4805
	v_cvt_f32_ubyte3_e32 v52, v51                               ; 7e682933
	v_cvt_f32_ubyte2_e32 v53, v51                               ; 7e6a2733
	v_cvt_f32_ubyte1_e32 v54, v51                               ; 7e6c2533
	v_cvt_f32_ubyte0_e32 v51, v51                               ; 7e662333
	v_cvt_f32_ubyte2_e32 v49, v36                               ; 7e622724
	v_cvt_f32_ubyte1_e32 v50, v36                               ; 7e642524
	v_cvt_f32_ubyte3_e32 v48, v36                               ; 7e602924
	v_cvt_f32_ubyte0_e32 v36, v36                               ; 7e482324
	v_mul_f32_e32 v52, v19, v52                                 ; 0a686913
	v_lshrrev_b32_e32 v38, 4, v38                               ; 204c4c84
	v_mul_f32_e32 v48, v34, v48                                 ; 0a606122
	v_mac_f32_e32 v52, v18, v53                                 ; 2c686b12
	v_and_b32_e32 v38, s5, v38                                  ; 264c4c05
	v_mac_f32_e32 v48, v33, v49                                 ; 2c606321
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v58, s5, v37                                  ; 26744a05
	v_mac_f32_e32 v52, v17, v54                                 ; 2c686d11
	v_cvt_f32_ubyte1_e32 v57, v38                               ; 7e722526
	v_cvt_f32_ubyte2_e32 v56, v38                               ; 7e702726
	v_cvt_f32_ubyte3_e32 v55, v38                               ; 7e6e2926
	v_cvt_f32_ubyte0_e32 v38, v38                               ; 7e4c2326
	v_mac_f32_e32 v48, v32, v44                                 ; 2c605920
	v_cvt_f32_ubyte2_e32 v60, v58                               ; 7e78273a
	v_cvt_f32_ubyte3_e32 v59, v58                               ; 7e76293a
	v_cvt_f32_ubyte1_e32 v61, v58                               ; 7e7a253a
	v_mac_f32_e32 v52, v16, v51                                 ; 2c686710
	v_cvt_f32_ubyte0_e32 v58, v58                               ; 7e74233a
	v_mul_f32_e32 v55, v23, v55                                 ; 0a6e6f17
	v_lshrrev_b32_e32 v37, 4, v37                               ; 204a4a84
	v_mac_f32_e32 v48, v15, v45                                 ; 2c605b0f
	v_mul_f32_e32 v59, v27, v59                                 ; 0a76771b
	v_mac_f32_e32 v55, v22, v56                                 ; 2c6e7116
	v_and_b32_e32 v37, s5, v37                                  ; 264a4a05
	v_mad_f32 v9, -v47, v48, v9                                 ; d1c10009 2426612f
	v_mac_f32_e32 v59, v26, v60                                 ; 2c76791a
	v_mac_f32_e32 v55, v21, v57                                 ; 2c6e7315
	v_cvt_f32_ubyte1_e32 v14, v37                               ; 7e1c2525
	v_cvt_f32_ubyte2_e32 v13, v37                               ; 7e1a2725
	v_cvt_f32_ubyte3_e32 v62, v37                               ; 7e7c2925
	v_cvt_f32_ubyte0_e32 v37, v37                               ; 7e4a2325
	v_mac_f32_e32 v59, v25, v61                                 ; 2c767b19
	v_mac_f32_e32 v55, v20, v38                                 ; 2c6e4d14
	v_mul_f32_e32 v62, v31, v62                                 ; 0a7c7d1f
	v_mac_f32_e32 v59, v24, v58                                 ; 2c767518
	v_mac_f32_e32 v62, v30, v13                                 ; 2c7c1b1e
	v_mac_f32_e32 v62, v29, v14                                 ; 2c7c1d1d
	v_mac_f32_e32 v62, v28, v37                                 ; 2c7c4b1c
	v_mul_f32_e32 v62, v62, v50                                 ; 0a7c653e
	v_mac_f32_e32 v62, v59, v36                                 ; 2c7c493b
	v_mac_f32_e32 v62, v55, v46                                 ; 2c7c5d37
	v_mac_f32_e32 v62, v52, v42                                 ; 2c7c5534
	v_mac_f32_e32 v9, v40, v62                                  ; 2c127d28
	s_cbranch_scc0 BB100                                        ; bf840133
BB82:
	s_add_u32 s0, s16, 5                                        ; 80008510
	s_mul_i32 s0, s0, s3                                        ; 92000300
	s_add_u32 s0, s19, s0                                       ; 80000013
	v_add_u32_e32 v13, s0, v0                                   ; 681a0000
	v_lshlrev_b32_e32 v14, 4, v13                               ; 241c1a84
	v_lshl_add_u32 v13, v13, 7, v14                             ; d1fd000d 04390f0d
	v_add3_u32 v36, v35, 4, v13                                 ; d1ff0024 04350923
	v_add_u32_e32 v37, 16, v13                                  ; 684a1a90
	v_add_u32_e32 v38, v37, v4                                  ; 684c0925
	v_add_u32_e32 v37, v37, v39                                 ; 684a4f25
	buffer_load_dwordx3 v[40:42], v13, s[12:15], 0 offen        ; e0581000 8003280d
	buffer_load_ushort v36, v36, s[12:15], 0 offen              ; e0481000 80032424
	buffer_load_dword v38, v38, s[12:15], 0 offen               ; e0501000 80032626
	buffer_load_dword v37, v37, s[12:15], 0 offen               ; e0501000 80032525
	s_bfm_b32 s1, 16, 16                                        ; 91019090
	s_mov_b32 s5, 0xf0f0f0f                                     ; be8500ff 0f0f0f0f
	s_cmp_lt_u32 6, s4                                          ; bf0a0486
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_lshrrev_b32_e32 v41, v5, v41                              ; 20525305
	v_lshrrev_b32_sdwa v42, v5, v42 dst_sel:WORD_1 dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:DWORD ; 205454f9 06060505
	v_cvt_f32_f16_sdwa v47, v40 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e5e16f9 00050628
	v_cvt_f32_f16_e32 v40, v40                                  ; 7e501728
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_lshl_or_b32 v36, v36, 12, v36                             ; d2000024 04911924
	v_bfi_b32 v42, s1, v42, v41                                 ; d1ca002a 04a65401
	v_and_b32_e32 v43, 0xc0c0c0c0, v42                          ; 265654ff c0c0c0c0
	v_and_b32_e32 v42, 0x3f3f3f3f, v42                          ; 265454ff 3f3f3f3f
	v_lshrrev_b32_e32 v43, 2, v43                               ; 20565682
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v51, s5, v38                                  ; 26664c05
	v_cvt_f32_ubyte3_e32 v44, v42                               ; 7e58292a
	v_cvt_f32_ubyte2_e32 v45, v42                               ; 7e5a272a
	v_cvt_f32_ubyte1_e32 v46, v42                               ; 7e5c252a
	v_cvt_f32_ubyte0_e32 v42, v42                               ; 7e54232a
	v_and_or_b32 v36, s5, v36, v43                              ; d2010024 04ae4805
	v_cvt_f32_ubyte3_e32 v52, v51                               ; 7e682933
	v_cvt_f32_ubyte2_e32 v53, v51                               ; 7e6a2733
	v_cvt_f32_ubyte1_e32 v54, v51                               ; 7e6c2533
	v_cvt_f32_ubyte0_e32 v51, v51                               ; 7e662333
	v_cvt_f32_ubyte2_e32 v49, v36                               ; 7e622724
	v_cvt_f32_ubyte1_e32 v50, v36                               ; 7e642524
	v_cvt_f32_ubyte3_e32 v48, v36                               ; 7e602924
	v_cvt_f32_ubyte0_e32 v36, v36                               ; 7e482324
	v_mul_f32_e32 v52, v19, v52                                 ; 0a686913
	v_lshrrev_b32_e32 v38, 4, v38                               ; 204c4c84
	v_mul_f32_e32 v48, v34, v48                                 ; 0a606122
	v_mac_f32_e32 v52, v18, v53                                 ; 2c686b12
	v_and_b32_e32 v38, s5, v38                                  ; 264c4c05
	v_mac_f32_e32 v48, v33, v49                                 ; 2c606321
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v58, s5, v37                                  ; 26744a05
	v_mac_f32_e32 v52, v17, v54                                 ; 2c686d11
	v_cvt_f32_ubyte1_e32 v57, v38                               ; 7e722526
	v_cvt_f32_ubyte2_e32 v56, v38                               ; 7e702726
	v_cvt_f32_ubyte3_e32 v55, v38                               ; 7e6e2926
	v_cvt_f32_ubyte0_e32 v38, v38                               ; 7e4c2326
	v_mac_f32_e32 v48, v32, v44                                 ; 2c605920
	v_cvt_f32_ubyte2_e32 v60, v58                               ; 7e78273a
	v_cvt_f32_ubyte3_e32 v59, v58                               ; 7e76293a
	v_cvt_f32_ubyte1_e32 v61, v58                               ; 7e7a253a
	v_mac_f32_e32 v52, v16, v51                                 ; 2c686710
	v_cvt_f32_ubyte0_e32 v58, v58                               ; 7e74233a
	v_mul_f32_e32 v55, v23, v55                                 ; 0a6e6f17
	v_lshrrev_b32_e32 v37, 4, v37                               ; 204a4a84
	v_mac_f32_e32 v48, v15, v45                                 ; 2c605b0f
	v_mul_f32_e32 v59, v27, v59                                 ; 0a76771b
	v_mac_f32_e32 v55, v22, v56                                 ; 2c6e7116
	v_and_b32_e32 v37, s5, v37                                  ; 264a4a05
	v_mad_f32 v10, -v47, v48, v10                               ; d1c1000a 242a612f
	v_mac_f32_e32 v59, v26, v60                                 ; 2c76791a
	v_mac_f32_e32 v55, v21, v57                                 ; 2c6e7315
	v_cvt_f32_ubyte1_e32 v14, v37                               ; 7e1c2525
	v_cvt_f32_ubyte2_e32 v13, v37                               ; 7e1a2725
	v_cvt_f32_ubyte3_e32 v62, v37                               ; 7e7c2925
	v_cvt_f32_ubyte0_e32 v37, v37                               ; 7e4a2325
	v_mac_f32_e32 v59, v25, v61                                 ; 2c767b19
	v_mac_f32_e32 v55, v20, v38                                 ; 2c6e4d14
	v_mul_f32_e32 v62, v31, v62                                 ; 0a7c7d1f
	v_mac_f32_e32 v59, v24, v58                                 ; 2c767518
	v_mac_f32_e32 v62, v30, v13                                 ; 2c7c1b1e
	v_mac_f32_e32 v62, v29, v14                                 ; 2c7c1d1d
	v_mac_f32_e32 v62, v28, v37                                 ; 2c7c4b1c
	v_mul_f32_e32 v62, v62, v50                                 ; 0a7c653e
	v_mac_f32_e32 v62, v59, v36                                 ; 2c7c493b
	v_mac_f32_e32 v62, v55, v46                                 ; 2c7c5d37
	v_mac_f32_e32 v62, v52, v42                                 ; 2c7c5534
	v_mac_f32_e32 v10, v40, v62                                 ; 2c147d28
	s_cbranch_scc0 BB100                                        ; bf8400cc
BB83:
	s_add_u32 s0, s16, 6                                        ; 80008610
	s_mul_i32 s0, s0, s3                                        ; 92000300
	s_add_u32 s0, s19, s0                                       ; 80000013
	v_add_u32_e32 v13, s0, v0                                   ; 681a0000
	v_lshlrev_b32_e32 v14, 4, v13                               ; 241c1a84
	v_lshl_add_u32 v13, v13, 7, v14                             ; d1fd000d 04390f0d
	v_add3_u32 v36, v35, 4, v13                                 ; d1ff0024 04350923
	v_add_u32_e32 v37, 16, v13                                  ; 684a1a90
	v_add_u32_e32 v38, v37, v4                                  ; 684c0925
	v_add_u32_e32 v37, v37, v39                                 ; 684a4f25
	buffer_load_dwordx3 v[40:42], v13, s[12:15], 0 offen        ; e0581000 8003280d
	buffer_load_ushort v36, v36, s[12:15], 0 offen              ; e0481000 80032424
	buffer_load_dword v38, v38, s[12:15], 0 offen               ; e0501000 80032626
	buffer_load_dword v37, v37, s[12:15], 0 offen               ; e0501000 80032525
	s_bfm_b32 s1, 16, 16                                        ; 91019090
	s_mov_b32 s5, 0xf0f0f0f                                     ; be8500ff 0f0f0f0f
	s_cmp_lt_u32 7, s4                                          ; bf0a0487
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_lshrrev_b32_e32 v41, v5, v41                              ; 20525305
	v_lshrrev_b32_sdwa v42, v5, v42 dst_sel:WORD_1 dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:DWORD ; 205454f9 06060505
	v_cvt_f32_f16_sdwa v47, v40 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e5e16f9 00050628
	v_cvt_f32_f16_e32 v40, v40                                  ; 7e501728
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_lshl_or_b32 v36, v36, 12, v36                             ; d2000024 04911924
	v_bfi_b32 v42, s1, v42, v41                                 ; d1ca002a 04a65401
	v_and_b32_e32 v43, 0xc0c0c0c0, v42                          ; 265654ff c0c0c0c0
	v_and_b32_e32 v42, 0x3f3f3f3f, v42                          ; 265454ff 3f3f3f3f
	v_lshrrev_b32_e32 v43, 2, v43                               ; 20565682
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v51, s5, v38                                  ; 26664c05
	v_cvt_f32_ubyte3_e32 v44, v42                               ; 7e58292a
	v_cvt_f32_ubyte2_e32 v45, v42                               ; 7e5a272a
	v_cvt_f32_ubyte1_e32 v46, v42                               ; 7e5c252a
	v_cvt_f32_ubyte0_e32 v42, v42                               ; 7e54232a
	v_and_or_b32 v36, s5, v36, v43                              ; d2010024 04ae4805
	v_cvt_f32_ubyte3_e32 v52, v51                               ; 7e682933
	v_cvt_f32_ubyte2_e32 v53, v51                               ; 7e6a2733
	v_cvt_f32_ubyte1_e32 v54, v51                               ; 7e6c2533
	v_cvt_f32_ubyte0_e32 v51, v51                               ; 7e662333
	v_cvt_f32_ubyte2_e32 v49, v36                               ; 7e622724
	v_cvt_f32_ubyte1_e32 v50, v36                               ; 7e642524
	v_cvt_f32_ubyte3_e32 v48, v36                               ; 7e602924
	v_cvt_f32_ubyte0_e32 v36, v36                               ; 7e482324
	v_mul_f32_e32 v52, v19, v52                                 ; 0a686913
	v_lshrrev_b32_e32 v38, 4, v38                               ; 204c4c84
	v_mul_f32_e32 v48, v34, v48                                 ; 0a606122
	v_mac_f32_e32 v52, v18, v53                                 ; 2c686b12
	v_and_b32_e32 v38, s5, v38                                  ; 264c4c05
	v_mac_f32_e32 v48, v33, v49                                 ; 2c606321
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v58, s5, v37                                  ; 26744a05
	v_mac_f32_e32 v52, v17, v54                                 ; 2c686d11
	v_cvt_f32_ubyte1_e32 v57, v38                               ; 7e722526
	v_cvt_f32_ubyte2_e32 v56, v38                               ; 7e702726
	v_cvt_f32_ubyte3_e32 v55, v38                               ; 7e6e2926
	v_cvt_f32_ubyte0_e32 v38, v38                               ; 7e4c2326
	v_mac_f32_e32 v48, v32, v44                                 ; 2c605920
	v_cvt_f32_ubyte2_e32 v60, v58                               ; 7e78273a
	v_cvt_f32_ubyte3_e32 v59, v58                               ; 7e76293a
	v_cvt_f32_ubyte1_e32 v61, v58                               ; 7e7a253a
	v_mac_f32_e32 v52, v16, v51                                 ; 2c686710
	v_cvt_f32_ubyte0_e32 v58, v58                               ; 7e74233a
	v_mul_f32_e32 v55, v23, v55                                 ; 0a6e6f17
	v_lshrrev_b32_e32 v37, 4, v37                               ; 204a4a84
	v_mac_f32_e32 v48, v15, v45                                 ; 2c605b0f
	v_mul_f32_e32 v59, v27, v59                                 ; 0a76771b
	v_mac_f32_e32 v55, v22, v56                                 ; 2c6e7116
	v_and_b32_e32 v37, s5, v37                                  ; 264a4a05
	v_mad_f32 v11, -v47, v48, v11                               ; d1c1000b 242e612f
	v_mac_f32_e32 v59, v26, v60                                 ; 2c76791a
	v_mac_f32_e32 v55, v21, v57                                 ; 2c6e7315
	v_cvt_f32_ubyte1_e32 v14, v37                               ; 7e1c2525
	v_cvt_f32_ubyte2_e32 v13, v37                               ; 7e1a2725
	v_cvt_f32_ubyte3_e32 v62, v37                               ; 7e7c2925
	v_cvt_f32_ubyte0_e32 v37, v37                               ; 7e4a2325
	v_mac_f32_e32 v59, v25, v61                                 ; 2c767b19
	v_mac_f32_e32 v55, v20, v38                                 ; 2c6e4d14
	v_mul_f32_e32 v62, v31, v62                                 ; 0a7c7d1f
	v_mac_f32_e32 v59, v24, v58                                 ; 2c767518
	v_mac_f32_e32 v62, v30, v13                                 ; 2c7c1b1e
	v_mac_f32_e32 v62, v29, v14                                 ; 2c7c1d1d
	v_mac_f32_e32 v62, v28, v37                                 ; 2c7c4b1c
	v_mul_f32_e32 v62, v62, v50                                 ; 0a7c653e
	v_mac_f32_e32 v62, v59, v36                                 ; 2c7c493b
	v_mac_f32_e32 v62, v55, v46                                 ; 2c7c5d37
	v_mac_f32_e32 v62, v52, v42                                 ; 2c7c5534
	v_mac_f32_e32 v11, v40, v62                                 ; 2c167d28
	s_cbranch_scc0 BB100                                        ; bf840065
BB84:
	s_add_u32 s0, s16, 7                                        ; 80008710
	s_mul_i32 s0, s0, s3                                        ; 92000300
	s_add_u32 s0, s19, s0                                       ; 80000013
	v_add_u32_e32 v13, s0, v0                                   ; 681a0000
	v_lshlrev_b32_e32 v14, 4, v13                               ; 241c1a84
	v_lshl_add_u32 v13, v13, 7, v14                             ; d1fd000d 04390f0d
	v_add3_u32 v35, v35, 4, v13                                 ; d1ff0023 04350923
	v_add_u32_e32 v36, 16, v13                                  ; 68481a90
	v_add_u32_e32 v37, v36, v4                                  ; 684a0924
	v_add_u32_e32 v36, v36, v39                                 ; 68484f24
	buffer_load_dwordx3 v[38:40], v13, s[12:15], 0 offen        ; e0581000 8003260d
	buffer_load_ushort v35, v35, s[12:15], 0 offen              ; e0481000 80032323
	buffer_load_dword v37, v37, s[12:15], 0 offen               ; e0501000 80032525
	buffer_load_dword v36, v36, s[12:15], 0 offen               ; e0501000 80032424
	s_bfm_b32 s1, 16, 16                                        ; 91019090
	s_mov_b32 s5, 0xf0f0f0f                                     ; be8500ff 0f0f0f0f
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_lshrrev_b32_e32 v39, v5, v39                              ; 204e4f05
	v_lshrrev_b32_sdwa v40, v5, v40 dst_sel:WORD_1 dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:DWORD ; 205050f9 06060505
	v_cvt_f32_f16_sdwa v45, v38 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e5a16f9 00050626
	v_cvt_f32_f16_e32 v38, v38                                  ; 7e4c1726
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_lshl_or_b32 v35, v35, 12, v35                             ; d2000023 048d1923
	v_bfi_b32 v40, s1, v40, v39                                 ; d1ca0028 049e5001
	v_and_b32_e32 v41, 0xc0c0c0c0, v40                          ; 265250ff c0c0c0c0
	v_and_b32_e32 v40, 0x3f3f3f3f, v40                          ; 265050ff 3f3f3f3f
	v_lshrrev_b32_e32 v41, 2, v41                               ; 20525282
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v49, s5, v37                                  ; 26624a05
	v_cvt_f32_ubyte3_e32 v42, v40                               ; 7e542928
	v_cvt_f32_ubyte2_e32 v43, v40                               ; 7e562728
	v_cvt_f32_ubyte1_e32 v44, v40                               ; 7e582528
	v_cvt_f32_ubyte0_e32 v40, v40                               ; 7e502328
	v_and_or_b32 v35, s5, v35, v41                              ; d2010023 04a64605
	v_cvt_f32_ubyte3_e32 v50, v49                               ; 7e642931
	v_cvt_f32_ubyte2_e32 v51, v49                               ; 7e662731
	v_cvt_f32_ubyte1_e32 v52, v49                               ; 7e682531
	v_cvt_f32_ubyte0_e32 v49, v49                               ; 7e622331
	v_cvt_f32_ubyte2_e32 v47, v35                               ; 7e5e2723
	v_cvt_f32_ubyte1_e32 v48, v35                               ; 7e602523
	v_cvt_f32_ubyte3_e32 v46, v35                               ; 7e5c2923
	v_cvt_f32_ubyte0_e32 v35, v35                               ; 7e462323
	v_mul_f32_e32 v19, v19, v50                                 ; 0a266513
	v_lshrrev_b32_e32 v37, 4, v37                               ; 204a4a84
	v_mul_f32_e32 v34, v34, v46                                 ; 0a445d22
	v_mac_f32_e32 v19, v18, v51                                 ; 2c266712
	v_and_b32_e32 v37, s5, v37                                  ; 264a4a05
	v_mac_f32_e32 v34, v33, v47                                 ; 2c445f21
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v56, s5, v36                                  ; 26704805
	v_mac_f32_e32 v19, v17, v52                                 ; 2c266911
	v_cvt_f32_ubyte1_e32 v55, v37                               ; 7e6e2525
	v_cvt_f32_ubyte2_e32 v54, v37                               ; 7e6c2725
	v_cvt_f32_ubyte3_e32 v53, v37                               ; 7e6a2925
	v_cvt_f32_ubyte0_e32 v37, v37                               ; 7e4a2325
	v_mac_f32_e32 v34, v32, v42                                 ; 2c445520
	v_cvt_f32_ubyte2_e32 v58, v56                               ; 7e742738
	v_cvt_f32_ubyte3_e32 v57, v56                               ; 7e722938
	v_cvt_f32_ubyte1_e32 v59, v56                               ; 7e762538
	v_mac_f32_e32 v19, v16, v49                                 ; 2c266310
	v_cvt_f32_ubyte0_e32 v56, v56                               ; 7e702338
	v_mul_f32_e32 v23, v23, v53                                 ; 0a2e6b17
	v_lshrrev_b32_e32 v36, 4, v36                               ; 20484884
	v_mac_f32_e32 v34, v15, v43                                 ; 2c44570f
	v_mul_f32_e32 v27, v27, v57                                 ; 0a36731b
	v_mac_f32_e32 v23, v22, v54                                 ; 2c2e6d16
	v_and_b32_e32 v36, s5, v36                                  ; 26484805
	v_mad_f32 v12, -v45, v34, v12                               ; d1c1000c 2432452d
	v_mac_f32_e32 v27, v26, v58                                 ; 2c36751a
	v_mac_f32_e32 v23, v21, v55                                 ; 2c2e6f15
	v_cvt_f32_ubyte1_e32 v62, v36                               ; 7e7c2524
	v_cvt_f32_ubyte2_e32 v61, v36                               ; 7e7a2724
	v_cvt_f32_ubyte3_e32 v60, v36                               ; 7e782924
	v_cvt_f32_ubyte0_e32 v36, v36                               ; 7e482324
	v_mac_f32_e32 v27, v25, v59                                 ; 2c367719
	v_mac_f32_e32 v23, v20, v37                                 ; 2c2e4b14
	v_mul_f32_e32 v31, v31, v60                                 ; 0a3e791f
	v_mac_f32_e32 v27, v24, v56                                 ; 2c367118
	v_mac_f32_e32 v31, v30, v61                                 ; 2c3e7b1e
	v_mac_f32_e32 v31, v29, v62                                 ; 2c3e7d1d
	v_mac_f32_e32 v31, v28, v36                                 ; 2c3e491c
	v_mul_f32_e32 v31, v31, v48                                 ; 0a3e611f
	v_mac_f32_e32 v31, v27, v35                                 ; 2c3e471b
	v_mac_f32_e32 v31, v23, v44                                 ; 2c3e5917
	v_mac_f32_e32 v31, v19, v40                                 ; 2c3e5113
	v_mac_f32_e32 v12, v38, v31                                 ; 2c183f26
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
	s_cbranch_scc0 BB121                                        ; bf8400a0
BB104:
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
	s_cbranch_scc0 BB119                                        ; bf840085
BB105:
	s_or_saveexec_b64 s[10:11], -1                              ; be8a21c1
	s_cmp_lt_u32 4, s4                                          ; bf0a0484
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
	s_cbranch_scc0 BB117                                        ; bf84006a
BB106:
	s_or_saveexec_b64 s[12:13], -1                              ; be8c21c1
	s_cmp_lt_u32 5, s4                                          ; bf0a0485
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
	v_readlane_b32 s10, v63, 63                                 ; d289000a 00017f3f
	s_cbranch_scc0 BB115                                        ; bf84004f
BB107:
	s_or_saveexec_b64 s[12:13], -1                              ; be8c21c1
	s_cmp_lt_u32 6, s4                                          ; bf0a0486
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
	v_readlane_b32 s11, v63, 63                                 ; d289000b 00017f3f
	s_cbranch_scc0 BB113                                        ; bf840034
BB108:
	s_or_saveexec_b64 s[14:15], -1                              ; be8e21c1
	s_cmp_lt_u32 7, s4                                          ; bf0a0487
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
	v_readlane_b32 s12, v63, 63                                 ; d289000c 00017f3f
	s_cbranch_scc0 BB111                                        ; bf840019
BB109:
	s_or_saveexec_b64 s[14:15], -1                              ; be8e21c1
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
	v_readlane_b32 s13, v63, 63                                 ; d289000d 00017f3f
	v_mov_b32_e32 v12, s13                                      ; 7e18020d
BB111:
	v_mov_b32_e32 v11, s12                                      ; 7e16020c
BB113:
	v_mov_b32_e32 v10, s11                                      ; 7e14020b
BB115:
	v_mov_b32_e32 v9, s10                                       ; 7e12020a
BB117:
	v_mov_b32_e32 v8, s9                                        ; 7e100209
BB119:
	v_mov_b32_e32 v7, s6                                        ; 7e0e0206
BB121:
	v_mov_b32_e32 v6, s5                                        ; 7e0c0205
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
	v_add_f32_e32 v6, s5, v6                                    ; 020c0c05
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
	v_add_f32_e32 v6, s5, v6                                    ; 020c0c05
	s_branch BB139                                              ; bf820001
BB138:
	s_mov_b32 s0, src_scc                                       ; be8000fd
BB139:
	s_add_u32 s5, s7, 4                                         ; 80058407
	buffer_store_dword v6, off, s[8:11], s5                     ; e0700000 05020680
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
	v_add_f32_e32 v7, s5, v7                                    ; 020e0e05
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
	v_add_f32_e32 v7, s5, v7                                    ; 020e0e05
	s_branch BB146                                              ; bf820001
BB145:
	s_mov_b32 s0, src_scc                                       ; be8000fd
BB146:
	s_add_u32 s5, s7, 8                                         ; 80058807
	buffer_store_dword v7, off, s[8:11], s5                     ; e0700000 05020780
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
	v_add_f32_e32 v8, s5, v8                                    ; 02101005
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
	v_add_f32_e32 v8, s5, v8                                    ; 02101005
	s_branch BB153                                              ; bf820001
BB152:
	s_mov_b32 s0, src_scc                                       ; be8000fd
BB153:
	s_add_u32 s5, s7, 12                                        ; 80058c07
	buffer_store_dword v8, off, s[8:11], s5                     ; e0700000 05020880
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
	v_add_f32_e32 v9, s5, v9                                    ; 02121205
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
	v_add_f32_e32 v9, s5, v9                                    ; 02121205
	s_branch BB160                                              ; bf820001
BB159:
	s_mov_b32 s0, src_scc                                       ; be8000fd
BB160:
	s_add_u32 s5, s7, 16                                        ; 80059007
	buffer_store_dword v9, off, s[8:11], s5                     ; e0700000 05020980
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
	v_add_f32_e32 v10, s5, v10                                  ; 02141405
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
	v_add_f32_e32 v10, s5, v10                                  ; 02141405
	s_branch BB167                                              ; bf820001
BB166:
	s_mov_b32 s0, src_scc                                       ; be8000fd
BB167:
	s_add_u32 s5, s7, 20                                        ; 80059407
	buffer_store_dword v10, off, s[8:11], s5                    ; e0700000 05020a80
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
	v_add_f32_e32 v11, s5, v11                                  ; 02161605
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
	v_add_f32_e32 v11, s5, v11                                  ; 02161605
	s_branch BB174                                              ; bf820001
BB173:
	s_mov_b32 s0, src_scc                                       ; be8000fd
BB174:
	s_add_u32 s5, s7, 24                                        ; 80059807
	buffer_store_dword v11, off, s[8:11], s5                    ; e0700000 05020b80
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
	v_add_f32_e32 v12, s1, v12                                  ; 02181801
BB178:
	s_cmp_lg_i32 s0, 0                                          ; bf018000
	s_cbranch_scc0 BB181                                        ; bf840008
BB179:
	s_load_dwordx4 s[0:3], s[2:3], 0x40                         ; c00a0001 00000040
	s_add_u32 s4, s7, 28                                        ; 80049c07
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s4, s[0:3], s4                          ; c0200100 00000004
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v12, s4, v12                                  ; 02181804
BB181:
	s_add_u32 s7, s7, 28                                        ; 80079c07
	buffer_store_dword v12, off, s[8:11], s7                    ; e0700000 07020c80
BB203:
	s_endpgm                                                    ; bf810000
