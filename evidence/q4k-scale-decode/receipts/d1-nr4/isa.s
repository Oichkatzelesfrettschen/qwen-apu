BB0:
	s_load_dword s0, s[14:15], 0x0                              ; c0020007 00000000
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_mul_i32 s0, s0, s18                                       ; 92001200
	s_add_u32 s16, s16, s0                                      ; 80100010
	s_lshl_b32 s16, s16, 2                                      ; 8e108210
	s_add_u32 s1, s16, 4                                        ; 80018410
	s_cmp_ge_u32 s4, s1                                         ; bf090104
	s_cbranch_scc0 BB48                                         ; bf84031d
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
	s_cbranch_execz BB15                                        ; bf8801d6
BB5:
	s_mov_b32 s0, s2                                            ; be800002
	s_movk_i32 s1, 0x8000                                       ; b0018000
	s_load_dwordx8 s[24:31], s[0:1], 0x0                        ; c00e0600 00000000
	s_mul_i32 s6, s6, s17                                       ; 92061106
	s_mul_i32 s0, s16, s3                                       ; 92000310
	v_lshlrev_b32_e32 v2, 1, v2                                 ; 24040481
	v_add_u32_e32 v5, 64, v4                                    ; 680a08c0
	s_mov_b64 s[10:11], exec                                    ; be8a017e
	v_mov_b32_e32 v6, 0                                         ; 7e0c0280
	v_mov_b32_e32 v7, 0                                         ; 7e0e0280
	s_add_u32 s0, s18, s0                                       ; 80000012
	s_add_u32 s1, s16, 1                                        ; 80018110
	v_mov_b32_e32 v8, 0                                         ; 7e100280
	v_add_u32_e32 v3, 8, v2                                     ; 68060488
	v_mov_b32_e32 v9, 0                                         ; 7e120280
	s_mul_i32 s1, s1, s3                                        ; 92010301
	s_add_u32 s1, s18, s1                                       ; 80010112
	s_add_u32 s4, s16, 2                                        ; 80048210
	s_mul_i32 s4, s4, s3                                        ; 92040304
	s_add_u32 s4, s18, s4                                       ; 80040412
	s_add_u32 s5, s16, 3                                        ; 80058310
	s_mul_i32 s5, s5, s3                                        ; 92050305
	s_add_u32 s18, s18, s5                                      ; 80120512
	s_nop 0                                                     ; bf800000
	(then repeated 4 times)
BB6:
	v_lshl_add_u32 v10, v0, 8, v1                               ; d1fd000a 04051100
	v_add_u32_e32 v11, s6, v10                                  ; 68161406
	v_add_u32_e32 v10, 0x80, v10                                ; 681414ff 00000080
	v_lshrrev_b32_e32 v11, 2, v11                               ; 20161682
	v_add_u32_e32 v10, s6, v10                                  ; 68141406
	v_lshlrev_b32_e32 v11, 4, v11                               ; 24161684
	v_lshrrev_b32_e32 v10, 2, v10                               ; 20141482
	v_lshlrev_b32_e32 v10, 4, v10                               ; 24141484
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_load_dwordx4 v[12:15], v11, s[28:31], 0 offen        ; e05c1000 80070c0b
	buffer_load_dwordx4 v[16:19], v11, s[28:31], 0 offen offset:128 ; e05c1080 8007100b
	buffer_load_dwordx4 v[20:23], v10, s[28:31], 0 offen        ; e05c1000 8007140a
	buffer_load_dwordx4 v[24:27], v10, s[28:31], 0 offen offset:128 ; e05c1080 8007180a
	v_add_u32_e32 v28, s0, v0                                   ; 68380000
	v_and_b32_e32 v31, -4, v2                                   ; 263e04c4
	v_add_u32_e32 v36, s1, v0                                   ; 68480001
	v_lshlrev_b32_e32 v29, 4, v28                               ; 243a3884
	v_lshlrev_b32_e32 v37, 4, v36                               ; 244a4884
	v_lshl_add_u32 v28, v28, 7, v29                             ; d1fd001c 04750f1c
	v_lshl_add_u32 v36, v36, 7, v37                             ; d1fd0024 04950f24
	v_add_u32_e32 v43, s4, v0                                   ; 68560004
	v_add_u32_e32 v34, 16, v28                                  ; 68443890
	v_add_u32_e32 v30, 4, v28                                   ; 683c3884
	v_add_u32_e32 v41, 16, v36                                  ; 68524890
	v_add_u32_e32 v38, 4, v36                                   ; 684c4884
	v_lshlrev_b32_e32 v44, 4, v43                               ; 24585684
	v_add_u32_e32 v35, v34, v4                                  ; 68460922
	v_add_u32_e32 v34, v34, v5                                  ; 68440b22
	v_add_u32_e32 v32, v31, v30                                 ; 68403d1f
	v_add_u32_e32 v33, v30, v2                                  ; 6842051e
	v_add_u32_e32 v30, v30, v3                                  ; 683c071e
	v_add_u32_e32 v42, v41, v4                                  ; 68540929
	v_add_u32_e32 v41, v41, v5                                  ; 68520b29
	v_add_u32_e32 v39, v31, v38                                 ; 684e4d1f
	v_add_u32_e32 v40, v38, v2                                  ; 68500526
	v_add_u32_e32 v38, v38, v3                                  ; 684c0726
	v_lshl_add_u32 v43, v43, 7, v44                             ; d1fd002b 04b10f2b
	v_add_u32_e32 v50, s18, v0                                  ; 68640012
	v_add_u32_e32 v45, 4, v43                                   ; 685a5684
	v_add_u32_e32 v48, 16, v43                                  ; 68605690
	v_lshlrev_b32_e32 v51, 4, v50                               ; 24666484
	v_add_u32_e32 v47, v45, v2                                  ; 685e052d
	v_add_u32_e32 v46, v31, v45                                 ; 685c5b1f
	v_add_u32_e32 v45, v45, v3                                  ; 685a072d
	v_add_u32_e32 v49, v48, v4                                  ; 68620930
	v_add_u32_e32 v48, v48, v5                                  ; 68600b30
	v_lshl_add_u32 v50, v50, 7, v51                             ; d1fd0032 04cd0f32
	v_add_u32_e32 v54, 16, v50                                  ; 686c6490
	v_add_u32_e32 v52, 4, v50                                   ; 68686484
	v_add_u32_e32 v55, v54, v4                                  ; 686e0936
	v_add_u32_e32 v54, v54, v5                                  ; 686c0b36
	v_add_u32_e32 v31, v31, v52                                 ; 683e691f
	v_add_u32_e32 v53, v52, v2                                  ; 686a0534
	v_add_u32_e32 v52, v52, v3                                  ; 68680734
	buffer_load_dword v28, v28, s[24:27], 0 offen               ; e0501000 80061c1c
	buffer_load_dwordx2 v[10:11], v32, s[24:27], 0 offen        ; e0541000 80060a20
	buffer_load_ushort v30, v30, s[24:27], 0 offen              ; e0481000 80061e1e
	buffer_load_dword v35, v35, s[24:27], 0 offen               ; e0501000 80062323
	buffer_load_dword v34, v34, s[24:27], 0 offen               ; e0501000 80062222
	buffer_load_dword v36, v36, s[24:27], 0 offen               ; e0501000 80062424
	buffer_load_dwordx2 v[56:57], v39, s[24:27], 0 offen        ; e0541000 80063827
	buffer_load_ushort v38, v38, s[24:27], 0 offen              ; e0481000 80062626
	buffer_load_dword v42, v42, s[24:27], 0 offen               ; e0501000 80062a2a
	buffer_load_dword v41, v41, s[24:27], 0 offen               ; e0501000 80062929
	buffer_load_dword v43, v43, s[24:27], 0 offen               ; e0501000 80062b2b
	buffer_load_dwordx2 v[58:59], v46, s[24:27], 0 offen        ; e0541000 80063a2e
	buffer_load_ushort v45, v45, s[24:27], 0 offen              ; e0481000 80062d2d
	buffer_load_dword v49, v49, s[24:27], 0 offen               ; e0501000 80063131
	buffer_load_dword v48, v48, s[24:27], 0 offen               ; e0501000 80063030
	buffer_load_dword v50, v50, s[24:27], 0 offen               ; e0501000 80063232
	buffer_load_dwordx2 v[60:61], v31, s[24:27], 0 offen        ; e0541000 80063c1f
	buffer_load_ushort v52, v52, s[24:27], 0 offen              ; e0481000 80063434
	buffer_load_dword v55, v55, s[24:27], 0 offen               ; e0501000 80063737
	buffer_load_dword v54, v54, s[24:27], 0 offen               ; e0501000 80063636
	s_mov_b32 s5, 0xf0f0f0f                                     ; be8500ff 0f0f0f0f
	s_mov_b32 s9, 0xc0c0c0c0                                    ; be8900ff c0c0c0c0
	s_mov_b32 s12, 0x3f3f3f3f                                   ; be8c00ff 3f3f3f3f
	v_add_u32_e32 v0, 4, v0                                     ; 68000084
	v_cmp_le_u32_e32 vcc, s3, v0                                ; 7d960003
	s_waitcnt vmcnt(23)                                         ; bf8c7f77
	v_add_f32_e32 v62, v12, v13                                 ; 027c1b0c
	s_waitcnt vmcnt(22)                                         ; bf8c7f76
	v_add_f32_e32 v29, v16, v17                                 ; 023a2310
	s_waitcnt vmcnt(21)                                         ; bf8c7f75
	v_add_f32_e32 v31, v20, v21                                 ; 023e2b14
	v_add_f32_e32 v62, v62, v14                                 ; 027c1d3e
	s_waitcnt vmcnt(20)                                         ; bf8c7f74
	v_add_f32_e32 v32, v24, v25                                 ; 02403318
	v_add_f32_e32 v29, v29, v18                                 ; 023a251d
	v_add_f32_e32 v31, v31, v22                                 ; 023e2d1f
	v_add_f32_e32 v62, v62, v15                                 ; 027c1f3e
	v_add_f32_e32 v32, v32, v26                                 ; 02403520
	v_add_f32_e32 v29, v29, v19                                 ; 023a271d
	v_add_f32_e32 v31, v31, v23                                 ; 023e2f1f
	v_add_f32_e32 v32, v32, v27                                 ; 02403720
	s_waitcnt vmcnt(19)                                         ; bf8c7f73
	v_cvt_f32_f16_sdwa v37, v28 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e4a16f9 0005061c
	v_cvt_f32_f16_e32 v28, v28                                  ; 7e38171c
	s_waitcnt vmcnt(18)                                         ; bf8c7f72
	v_alignbyte_b32 v10, v11, v10, v33                          ; d1cf000a 0486150b
	v_alignbyte_b32 v11, v11, v11, v33                          ; d1cf000b 0486170b
	s_waitcnt vmcnt(17)                                         ; bf8c7f71
	v_lshl_or_b32 v30, v30, 12, v30                             ; d200001e 0479191e
	s_waitcnt vmcnt(16)                                         ; bf8c7f70
	v_and_b32_e32 v44, s5, v35                                  ; 26584605
	v_lshrrev_b32_e32 v35, 4, v35                               ; 20464684
	v_mov_b32_sdwa v10, v11 dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_0 ; 7e1402f9 0004150b
	v_cvt_f32_ubyte2_e32 v51, v44                               ; 7e66272c
	v_cvt_f32_ubyte3_e32 v46, v44                               ; 7e5c292c
	v_cvt_f32_ubyte1_e32 v11, v44                               ; 7e16252c
	v_cvt_f32_ubyte0_e32 v44, v44                               ; 7e58232c
	v_and_b32_e32 v35, s5, v35                                  ; 26464605
	v_and_b32_e32 v39, s9, v10                                  ; 264e1409
	v_and_b32_e32 v10, s12, v10                                 ; 2614140c
	v_mul_f32_e32 v46, v15, v46                                 ; 0a5c5d0f
	v_cvt_f32_ubyte3_e32 v33, v35                               ; 7e422923
	v_lshrrev_b32_e32 v39, 2, v39                               ; 204e4e82
	v_mac_f32_e32 v46, v14, v51                                 ; 2c5c670e
	s_waitcnt vmcnt(15)                                         ; bf8c3f7f
	v_and_b32_e32 v51, s5, v34                                  ; 26664405
	v_mul_f32_e32 v33, v19, v33                                 ; 0a424313
	v_and_or_b32 v30, s5, v30, v39                              ; d201001e 049e3c05
	v_cvt_f32_ubyte2_e32 v39, v35                               ; 7e4e2723
	v_mac_f32_e32 v46, v13, v11                                 ; 2c5c170d
	v_cvt_f32_ubyte3_e32 v11, v51                               ; 7e162933
	v_lshrrev_b32_e32 v34, 4, v34                               ; 20444484
	v_mac_f32_e32 v33, v18, v39                                 ; 2c424f12
	v_cvt_f32_ubyte1_e32 v39, v51                               ; 7e4e2533
	v_mac_f32_e32 v46, v12, v44                                 ; 2c5c590c
	v_cvt_f32_ubyte1_e32 v44, v35                               ; 7e582523
	v_cvt_f32_ubyte0_e32 v35, v35                               ; 7e462323
	v_mul_f32_e32 v11, v23, v11                                 ; 0a161717
	v_and_b32_e32 v34, s5, v34                                  ; 26444405
	v_mac_f32_e32 v33, v17, v44                                 ; 2c425911
	v_cvt_f32_ubyte3_e32 v44, v34                               ; 7e582922
	v_mac_f32_e32 v33, v16, v35                                 ; 2c424710
	v_cvt_f32_ubyte2_e32 v35, v51                               ; 7e462733
	v_cvt_f32_ubyte0_e32 v51, v51                               ; 7e662333
	v_mul_f32_e32 v44, v27, v44                                 ; 0a58591b
	v_mac_f32_e32 v11, v22, v35                                 ; 2c164716
	v_cvt_f32_ubyte1_e32 v35, v34                               ; 7e462522
	v_mac_f32_e32 v11, v21, v39                                 ; 2c164f15
	v_cvt_f32_ubyte3_e32 v39, v30                               ; 7e4e291e
	v_mac_f32_e32 v11, v20, v51                                 ; 2c166714
	v_cvt_f32_ubyte2_e32 v51, v34                               ; 7e662722
	v_cvt_f32_ubyte0_e32 v34, v34                               ; 7e442322
	v_mul_f32_e32 v39, v32, v39                                 ; 0a4e4f20
	v_mac_f32_e32 v44, v26, v51                                 ; 2c58671a
	v_cvt_f32_ubyte2_e32 v51, v30                               ; 7e66271e
	v_mac_f32_e32 v44, v25, v35                                 ; 2c584719
	v_cvt_f32_ubyte2_e32 v35, v10                               ; 7e46270a
	v_mac_f32_e32 v39, v31, v51                                 ; 2c4e671f
	v_cvt_f32_ubyte1_e32 v51, v30                               ; 7e66251e
	v_cvt_f32_ubyte0_e32 v30, v30                               ; 7e3c231e
	v_mac_f32_e32 v44, v24, v34                                 ; 2c584518
	v_cvt_f32_ubyte3_e32 v34, v10                               ; 7e44290a
	s_waitcnt vmcnt(13)                                         ; bf8c3f7d
	v_alignbyte_b32 v56, v57, v56, v40                          ; d1cf0038 04a27139
	v_alignbyte_b32 v57, v57, v57, v40                          ; d1cf0039 04a27339
	v_mul_f32_e32 v44, v44, v51                                 ; 0a58672c
	v_mac_f32_e32 v39, v29, v34                                 ; 2c4e451d
	v_mov_b32_sdwa v56, v57 dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_0 ; 7e7002f9 00041539
	v_mac_f32_e32 v44, v11, v30                                 ; 2c583d0b
	v_cvt_f32_ubyte1_e32 v11, v10                               ; 7e16250a
	v_cvt_f32_ubyte0_e32 v10, v10                               ; 7e14230a
	v_mac_f32_e32 v39, v62, v35                                 ; 2c4e473e
	v_and_b32_e32 v30, s9, v56                                  ; 263c7009
	v_and_b32_e32 v56, s12, v56                                 ; 2670700c
	s_waitcnt vmcnt(12)                                         ; bf8c3f7c
	v_lshl_or_b32 v38, v38, 12, v38                             ; d2000026 04991926
	v_mac_f32_e32 v44, v33, v11                                 ; 2c581721
	v_mad_f32 v6, -v37, v39, v6                                 ; d1c10006 241a4f25
	v_lshrrev_b32_e32 v30, 2, v30                               ; 203c3c82
	v_cvt_f32_ubyte3_e32 v33, v56                               ; 7e422938
	v_cvt_f32_ubyte2_e32 v34, v56                               ; 7e442738
	v_cvt_f32_ubyte1_e32 v35, v56                               ; 7e462538
	v_cvt_f32_ubyte0_e32 v56, v56                               ; 7e702338
	v_mac_f32_e32 v44, v46, v10                                 ; 2c58152e
	v_and_or_b32 v38, s5, v38, v30                              ; d2010026 047a4c05
	v_mac_f32_e32 v6, v28, v44                                  ; 2c0c591c
	v_cvt_f32_f16_sdwa v28, v36 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e3816f9 00050624
	v_cvt_f32_f16_e32 v36, v36                                  ; 7e481724
	s_waitcnt vmcnt(11)                                         ; bf8c3f7b
	v_and_b32_e32 v44, s5, v42                                  ; 26585405
	v_cvt_f32_ubyte1_e32 v40, v38                               ; 7e502526
	v_cvt_f32_ubyte2_e32 v39, v38                               ; 7e4e2726
	v_cvt_f32_ubyte3_e32 v37, v38                               ; 7e4a2926
	v_cvt_f32_ubyte0_e32 v38, v38                               ; 7e4c2326
	v_cvt_f32_ubyte1_e32 v57, v44                               ; 7e72252c
	v_cvt_f32_ubyte3_e32 v46, v44                               ; 7e5c292c
	v_cvt_f32_ubyte2_e32 v51, v44                               ; 7e66272c
	v_cvt_f32_ubyte0_e32 v44, v44                               ; 7e58232c
	v_lshrrev_b32_e32 v42, 4, v42                               ; 20545484
	v_mul_f32_e32 v37, v32, v37                                 ; 0a4a4b20
	v_mul_f32_e32 v46, v15, v46                                 ; 0a5c5d0f
	v_and_b32_e32 v42, s5, v42                                  ; 26545405
	v_mac_f32_e32 v37, v31, v39                                 ; 2c4a4f1f
	s_waitcnt vmcnt(10)                                         ; bf8c3f7a
	v_and_b32_e32 v30, s5, v41                                  ; 263c5205
	v_mac_f32_e32 v46, v14, v51                                 ; 2c5c670e
	v_cvt_f32_ubyte3_e32 v10, v42                               ; 7e14292a
	v_cvt_f32_ubyte2_e32 v11, v42                               ; 7e16272a
	v_mac_f32_e32 v37, v29, v33                                 ; 2c4a431d
	v_cvt_f32_ubyte3_e32 v33, v30                               ; 7e42291e
	v_mac_f32_e32 v46, v13, v57                                 ; 2c5c730d
	v_mul_f32_e32 v10, v19, v10                                 ; 0a141513
	v_mac_f32_e32 v37, v62, v34                                 ; 2c4a453e
	v_cvt_f32_ubyte2_e32 v34, v30                               ; 7e44271e
	v_mul_f32_e32 v33, v23, v33                                 ; 0a424317
	v_lshrrev_b32_e32 v41, 4, v41                               ; 20525284
	v_mac_f32_e32 v46, v12, v44                                 ; 2c5c590c
	v_mac_f32_e32 v10, v18, v11                                 ; 2c141712
	v_mad_f32 v7, -v28, v37, v7                                 ; d1c10007 241e4b1c
	v_cvt_f32_ubyte1_e32 v28, v42                               ; 7e38252a
	v_cvt_f32_ubyte0_e32 v42, v42                               ; 7e54232a
	v_cvt_f32_ubyte1_e32 v37, v30                               ; 7e4a251e
	v_cvt_f32_ubyte0_e32 v30, v30                               ; 7e3c231e
	v_mac_f32_e32 v33, v22, v34                                 ; 2c424516
	v_and_b32_e32 v41, s5, v41                                  ; 26525205
	v_mac_f32_e32 v10, v17, v28                                 ; 2c143911
	v_mac_f32_e32 v33, v21, v37                                 ; 2c424b15
	v_cvt_f32_ubyte3_e32 v39, v41                               ; 7e4e2929
	v_cvt_f32_ubyte1_e32 v44, v41                               ; 7e582529
	v_mac_f32_e32 v10, v16, v42                                 ; 2c145510
	v_cvt_f32_ubyte2_e32 v42, v41                               ; 7e542729
	v_cvt_f32_ubyte0_e32 v41, v41                               ; 7e522329
	v_mac_f32_e32 v33, v20, v30                                 ; 2c423d14
	v_mul_f32_e32 v39, v27, v39                                 ; 0a4e4f1b
	s_waitcnt vmcnt(8)                                          ; bf8c3f78
	v_alignbyte_b32 v58, v59, v58, v47                          ; d1cf003a 04be753b
	v_alignbyte_b32 v59, v59, v59, v47                          ; d1cf003b 04be773b
	v_mac_f32_e32 v39, v26, v42                                 ; 2c4e551a
	v_mov_b32_sdwa v58, v59 dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_0 ; 7e7402f9 0004153b
	s_waitcnt vmcnt(7)                                          ; bf8c3f77
	v_lshl_or_b32 v45, v45, 12, v45                             ; d200002d 04b5192d
	v_mac_f32_e32 v39, v25, v44                                 ; 2c4e5919
	v_and_b32_e32 v47, s9, v58                                  ; 265e7409
	v_and_b32_e32 v58, s12, v58                                 ; 2674740c
	s_waitcnt vmcnt(6)                                          ; bf8c3f76
	v_and_b32_e32 v59, s5, v49                                  ; 26766205
	v_mac_f32_e32 v39, v24, v41                                 ; 2c4e5318
	v_lshrrev_b32_e32 v47, 2, v47                               ; 205e5e82
	v_cvt_f32_ubyte3_e32 v51, v58                               ; 7e66293a
	v_cvt_f32_ubyte2_e32 v11, v59                               ; 7e16273b
	v_cvt_f32_ubyte1_e32 v28, v59                               ; 7e38253b
	v_mul_f32_e32 v39, v39, v40                                 ; 0a4e5127
	v_and_or_b32 v45, s5, v45, v47                              ; d201002d 04be5a05
	v_lshrrev_b32_e32 v49, 4, v49                               ; 20626284
	v_mac_f32_e32 v39, v33, v38                                 ; 2c4e4d21
	v_cvt_f32_ubyte3_e32 v57, v45                               ; 7e72292d
	v_and_b32_e32 v49, s5, v49                                  ; 26626205
	v_mac_f32_e32 v39, v10, v35                                 ; 2c4e470a
	v_cvt_f32_ubyte3_e32 v10, v59                               ; 7e14293b
	v_cvt_f32_ubyte0_e32 v59, v59                               ; 7e76233b
	v_cvt_f32_ubyte1_e32 v34, v49                               ; 7e442531
	v_cvt_f32_ubyte2_e32 v33, v49                               ; 7e422731
	v_cvt_f32_ubyte3_e32 v30, v49                               ; 7e3c2931
	v_mac_f32_e32 v39, v46, v56                                 ; 2c4e712e
	v_cvt_f32_f16_sdwa v46, v43 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e5c16f9 0005062b
	v_cvt_f32_f16_e32 v43, v43                                  ; 7e56172b
	v_cvt_f32_ubyte2_e32 v56, v58                               ; 7e70273a
	v_cvt_f32_ubyte0_e32 v49, v49                               ; 7e622331
	v_mul_f32_e32 v10, v15, v10                                 ; 0a14150f
	s_waitcnt vmcnt(5)                                          ; bf8c3f75
	v_and_b32_e32 v35, s5, v48                                  ; 26466005
	v_mul_f32_e32 v30, v19, v30                                 ; 0a3c3d13
	v_mac_f32_e32 v7, v36, v39                                  ; 2c0e4f24
	v_mac_f32_e32 v10, v14, v11                                 ; 2c14170e
	v_cvt_f32_ubyte2_e32 v37, v35                               ; 7e4a2723
	v_cvt_f32_ubyte3_e32 v36, v35                               ; 7e482923
	v_cvt_f32_ubyte1_e32 v38, v35                               ; 7e4c2523
	v_lshrrev_b32_e32 v48, 4, v48                               ; 20606084
	v_cvt_f32_ubyte0_e32 v35, v35                               ; 7e462323
	v_mac_f32_e32 v30, v18, v33                                 ; 2c3c4312
	v_mac_f32_e32 v10, v13, v28                                 ; 2c14390d
	v_mul_f32_e32 v36, v23, v36                                 ; 0a484917
	v_and_b32_e32 v48, s5, v48                                  ; 26606005
	v_mac_f32_e32 v30, v17, v34                                 ; 2c3c4511
	v_mac_f32_e32 v10, v12, v59                                 ; 2c14770c
	v_mul_f32_e32 v57, v32, v57                                 ; 0a727320
	v_cvt_f32_ubyte2_e32 v42, v45                               ; 7e54272d
	v_mac_f32_e32 v36, v22, v37                                 ; 2c484b16
	v_cvt_f32_ubyte3_e32 v39, v48                               ; 7e4e2930
	v_cvt_f32_ubyte2_e32 v40, v48                               ; 7e502730
	v_cvt_f32_ubyte1_e32 v41, v48                               ; 7e522530
	v_cvt_f32_ubyte0_e32 v48, v48                               ; 7e602330
	v_mac_f32_e32 v30, v16, v49                                 ; 2c3c6310
	v_cvt_f32_ubyte1_e32 v44, v45                               ; 7e58252d
	v_mac_f32_e32 v57, v31, v42                                 ; 2c72551f
	v_mac_f32_e32 v36, v21, v38                                 ; 2c484d15
	v_cvt_f32_ubyte0_e32 v45, v45                               ; 7e5a232d
	v_mul_f32_e32 v39, v27, v39                                 ; 0a4e4f1b
	v_mac_f32_e32 v57, v29, v51                                 ; 2c72671d
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_alignbyte_b32 v60, v61, v60, v53                          ; d1cf003c 04d6793d
	v_mac_f32_e32 v36, v20, v35                                 ; 2c484714
	v_alignbyte_b32 v61, v61, v61, v53                          ; d1cf003d 04d67b3d
	v_mac_f32_e32 v39, v26, v40                                 ; 2c4e511a
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_lshl_or_b32 v52, v52, 12, v52                             ; d2000034 04d11934
	v_mac_f32_e32 v57, v62, v56                                 ; 2c72713e
	v_mov_b32_sdwa v60, v61 dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_0 ; 7e7802f9 0004153d
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v47, s5, v55                                  ; 265e6e05
	v_mac_f32_e32 v39, v25, v41                                 ; 2c4e5319
	v_mad_f32 v8, -v46, v57, v8                                 ; d1c10008 2422732e
	v_and_b32_e32 v46, s9, v60                                  ; 265c7809
	v_cvt_f32_ubyte2_e32 v49, v47                               ; 7e62272f
	v_cvt_f32_ubyte1_e32 v51, v47                               ; 7e66252f
	v_mac_f32_e32 v39, v24, v48                                 ; 2c4e6118
	v_cvt_f32_ubyte3_e32 v48, v47                               ; 7e60292f
	v_lshrrev_b32_e32 v46, 2, v46                               ; 205c5c82
	v_cvt_f32_ubyte0_e32 v47, v47                               ; 7e5e232f
	v_lshrrev_b32_e32 v55, 4, v55                               ; 206e6e84
	v_mul_f32_e32 v39, v39, v44                                 ; 0a4e5927
	v_mul_f32_e32 v15, v15, v48                                 ; 0a1e610f
	v_and_or_b32 v52, s5, v52, v46                              ; d2010034 04ba6805
	v_and_b32_e32 v55, s5, v55                                  ; 266e6e05
	v_mac_f32_e32 v39, v36, v45                                 ; 2c4e5b24
	v_cvt_f32_ubyte1_e32 v45, v58                               ; 7e5a253a
	v_cvt_f32_ubyte0_e32 v58, v58                               ; 7e74233a
	v_mac_f32_e32 v15, v14, v49                                 ; 2c1e630e
	v_cvt_f32_ubyte3_e32 v53, v55                               ; 7e6a2937
	v_cvt_f32_ubyte1_e32 v57, v55                               ; 7e722537
	v_cvt_f32_ubyte2_e32 v56, v55                               ; 7e702737
	v_cvt_f32_ubyte0_e32 v55, v55                               ; 7e6e2337
	v_mac_f32_e32 v39, v30, v45                                 ; 2c4e5b1e
	v_mac_f32_e32 v15, v13, v51                                 ; 2c1e670d
	v_mul_f32_e32 v19, v19, v53                                 ; 0a266b13
	v_mac_f32_e32 v39, v10, v58                                 ; 2c4e750a
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v58, s5, v54                                  ; 26746c05
	v_lshrrev_b32_e32 v54, 4, v54                               ; 206c6c84
	v_mac_f32_e32 v15, v12, v47                                 ; 2c1e5f0c
	v_mac_f32_e32 v19, v18, v56                                 ; 2c267112
	v_mac_f32_e32 v8, v43, v39                                  ; 2c104f2b
	v_cvt_f32_ubyte3_e32 v59, v58                               ; 7e76293a
	v_cvt_f32_ubyte2_e32 v61, v58                               ; 7e7a273a
	v_cvt_f32_ubyte1_e32 v10, v58                               ; 7e14253a
	v_cvt_f32_ubyte0_e32 v58, v58                               ; 7e74233a
	v_and_b32_e32 v54, s5, v54                                  ; 266c6c05
	v_mac_f32_e32 v19, v17, v57                                 ; 2c267311
	v_mul_f32_e32 v23, v23, v59                                 ; 0a2e7717
	v_cvt_f32_ubyte3_e32 v14, v52                               ; 7e1c2934
	v_cvt_f32_ubyte1_e32 v13, v54                               ; 7e1a2536
	v_cvt_f32_ubyte2_e32 v12, v54                               ; 7e182736
	v_cvt_f32_ubyte3_e32 v11, v54                               ; 7e162936
	v_cvt_f32_ubyte0_e32 v54, v54                               ; 7e6c2336
	v_mac_f32_e32 v19, v16, v55                                 ; 2c266f10
	v_cvt_f32_ubyte2_e32 v16, v52                               ; 7e202734
	v_and_b32_e32 v60, s12, v60                                 ; 2678780c
	v_mac_f32_e32 v23, v22, v61                                 ; 2c2e7b16
	v_mul_f32_e32 v32, v32, v14                                 ; 0a401d20
	v_mul_f32_e32 v27, v27, v11                                 ; 0a36171b
	v_cvt_f32_ubyte3_e32 v17, v60                               ; 7e22293c
	v_cvt_f32_ubyte2_e32 v18, v60                               ; 7e24273c
	v_mac_f32_e32 v23, v21, v10                                 ; 2c2e1515
	v_cvt_f32_ubyte1_e32 v21, v60                               ; 7e2a253c
	v_mac_f32_e32 v32, v31, v16                                 ; 2c40211f
	v_cvt_f32_ubyte0_e32 v60, v60                               ; 7e78233c
	v_mac_f32_e32 v27, v26, v12                                 ; 2c36191a
	v_cvt_f32_f16_sdwa v22, v50 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e2c16f9 00050632
	v_mac_f32_e32 v23, v20, v58                                 ; 2c2e7514
	v_cvt_f32_ubyte1_e32 v20, v52                               ; 7e282534
	v_cvt_f32_ubyte0_e32 v52, v52                               ; 7e682334
	v_cvt_f32_f16_e32 v50, v50                                  ; 7e641732
	v_mac_f32_e32 v32, v29, v17                                 ; 2c40231d
	v_mac_f32_e32 v27, v25, v13                                 ; 2c361b19
	v_mac_f32_e32 v32, v62, v18                                 ; 2c40253e
	v_mac_f32_e32 v27, v24, v54                                 ; 2c366d18
	v_mad_f32 v9, -v22, v32, v9                                 ; d1c10009 24264116
	v_mul_f32_e32 v27, v27, v20                                 ; 0a36291b
	v_mac_f32_e32 v27, v23, v52                                 ; 2c366917
	v_mac_f32_e32 v27, v19, v21                                 ; 2c362b13
	v_mac_f32_e32 v27, v15, v60                                 ; 2c36790f
	v_mac_f32_e32 v9, v50, v27                                  ; 2c123732
	s_and_saveexec_b64 s[12:13], vcc                            ; be8c206a
BB11:
	s_andn2_wrexec_b64 s[12:13], s[12:13]                       ; be8c360c
	s_cbranch_scc1 BB6                                          ; bf85fe48
BB12:
	s_mov_b64 exec, s[10:11]                                    ; befe010a
BB15:
	s_andn2_b64 exec, -1, exec                                  ; 89fe7ec1
	v_mov_b32_e32 v6, 0                                         ; 7e0c0280
	v_mov_b32_e32 v7, 0                                         ; 7e0e0280
	v_mov_b32_e32 v8, 0                                         ; 7e100280
	v_mov_b32_e32 v9, 0                                         ; 7e120280
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
	s_mov_b64 exec, 1                                           ; befe0181
	v_readlane_b32 s4, v63, 63                                  ; d2890004 00017f3f
BB18:
	s_bitcmp1_b32 s8, 0                                         ; bf0d8008
	s_cbranch_scc0 BB20                                         ; bf84000f
BB19:
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
	s_branch BB21                                               ; bf820002
BB20:
	s_mov_b32 s6, src_scc                                       ; be8600fd
	v_mov_b32_e32 v0, s0                                        ; 7e000200
BB21:
	s_bitcmp1_b32 s8, 1                                         ; bf0d8108
	s_cbranch_scc0 BB23                                         ; bf84000e
BB22:
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
	s_branch BB24                                               ; bf820001
BB23:
	s_mov_b32 s5, src_scc                                       ; be8500fd
BB24:
	s_mov_b32 s0, s3                                            ; be800003
	s_movk_i32 s3, 0x8000                                       ; b0038000
	s_load_dwordx4 s[8:11], s[2:3], 0x20                        ; c00a0201 00000020
	s_mul_i32 s7, s7, s17                                       ; 92071107
	s_add_u32 s7, s7, s16                                       ; 80071007
	s_lshl_b32 s7, s7, 2                                        ; 8e078207
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_store_dword v0, off, s[8:11], s7                     ; e0700000 07020080
	s_cmp_lg_i32 s6, 0                                          ; bf018006
	s_cbranch_scc0 BB26                                         ; bf84000b
BB25:
	s_load_dwordx4 s[12:15], s[2:3], 0x30                       ; c00a0301 00000030
	s_mov_b32 s6, src_scc                                       ; be8600fd
	s_add_u32 s16, s7, 4                                        ; 80108407
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s16, s[12:15], s16                      ; c0200406 00000010
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_mov_b32_e32 v0, s16                                       ; 7e000210
	v_add_f32_e32 v0, s1, v0                                    ; 02000001
	s_branch BB27                                               ; bf820002
BB26:
	s_mov_b32 s6, src_scc                                       ; be8600fd
	v_mov_b32_e32 v0, s1                                        ; 7e000201
BB27:
	s_cmp_lg_i32 s5, 0                                          ; bf018005
	s_cbranch_scc0 BB29                                         ; bf84000a
BB28:
	s_load_dwordx4 s[12:15], s[2:3], 0x40                       ; c00a0301 00000040
	s_mov_b32 s1, src_scc                                       ; be8100fd
	s_add_u32 s5, s7, 4                                         ; 80058407
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s5, s[12:15], s5                        ; c0200146 00000005
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v0, s5, v0                                    ; 02000005
	s_branch BB30                                               ; bf820001
BB29:
	s_mov_b32 s1, src_scc                                       ; be8100fd
BB30:
	s_add_u32 s5, s7, 4                                         ; 80058407
	buffer_store_dword v0, off, s[8:11], s5                     ; e0700000 05020080
	s_cmp_lg_i32 s6, 0                                          ; bf018006
	s_cbranch_scc0 BB32                                         ; bf84000b
BB31:
	s_load_dwordx4 s[12:15], s[2:3], 0x30                       ; c00a0301 00000030
	s_mov_b32 s5, src_scc                                       ; be8500fd
	s_add_u32 s6, s7, 8                                         ; 80068807
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s6, s[12:15], s6                        ; c0200186 00000006
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_mov_b32_e32 v0, s6                                        ; 7e000206
	v_add_f32_e32 v0, s0, v0                                    ; 02000000
	s_branch BB33                                               ; bf820002
BB32:
	s_mov_b32 s5, src_scc                                       ; be8500fd
	v_mov_b32_e32 v0, s0                                        ; 7e000200
BB33:
	s_cmp_lg_i32 s1, 0                                          ; bf018001
	s_cbranch_scc0 BB35                                         ; bf84000a
BB34:
	s_load_dwordx4 s[12:15], s[2:3], 0x40                       ; c00a0301 00000040
	s_mov_b32 s0, src_scc                                       ; be8000fd
	s_add_u32 s1, s7, 8                                         ; 80018807
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s1, s[12:15], s1                        ; c0200046 00000001
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v0, s1, v0                                    ; 02000001
	s_branch BB36                                               ; bf820001
BB35:
	s_mov_b32 s0, src_scc                                       ; be8000fd
BB36:
	s_add_u32 s1, s7, 8                                         ; 80018807
	buffer_store_dword v0, off, s[8:11], s1                     ; e0700000 01020080
	s_cmp_lg_i32 s5, 0                                          ; bf018005
	s_cbranch_scc0 BB38                                         ; bf84000a
BB37:
	s_load_dwordx4 s[12:15], s[2:3], 0x30                       ; c00a0301 00000030
	s_add_u32 s1, s7, 12                                        ; 80018c07
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s1, s[12:15], s1                        ; c0200046 00000001
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_mov_b32_e32 v0, s1                                        ; 7e000201
	v_add_f32_e32 v0, s4, v0                                    ; 02000004
	s_branch BB39                                               ; bf820001
BB38:
	v_mov_b32_e32 v0, s4                                        ; 7e000204
BB39:
	s_cmp_lg_i32 s0, 0                                          ; bf018000
	s_cbranch_scc0 BB42                                         ; bf840008
BB40:
	s_load_dwordx4 s[0:3], s[2:3], 0x40                         ; c00a0001 00000040
	s_add_u32 s4, s7, 12                                        ; 80048c07
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s4, s[0:3], s4                          ; c0200100 00000004
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v0, s4, v0                                    ; 02000004
BB42:
	s_add_u32 s7, s7, 12                                        ; 80078c07
	buffer_store_dword v0, off, s[8:11], s7                     ; e0700000 07020080
	s_branch BB131                                              ; bf820346
BB48:
	s_cmp_lt_u32 s16, s4                                        ; bf0a0410
	s_cbranch_scc0 BB131                                        ; bf840344
BB49:
	s_sub_i32 s4, s4, s16                                       ; 81841004
	s_add_u32 s17, s17, s9                                      ; 80110911
	s_cmp_lg_i32 s17, 0                                         ; bf018011
	s_cbranch_scc0 BB51                                         ; bf840043
BB50:
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
	s_branch BB52                                               ; bf820001
BB51:
	s_mov_b32 s19, 0                                            ; be930080
BB52:
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
	s_cbranch_execz BB75                                        ; bf8801f0
BB53:
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
	s_branch BB54                                               ; bf820003
	s_nop 0                                                     ; bf800000
BB71:
	s_mov_b64 exec, s[20:21]                                    ; befe0114
	s_cmp_lg_i32 s9, 0                                          ; bf018009
BB54:
	v_lshl_add_u32 v8, v0, 8, v1                                ; d1fd0008 04051100
	v_add_u32_e32 v9, s6, v8                                    ; 68121006
	v_add_u32_e32 v8, 0x80, v8                                  ; 681010ff 00000080
	v_lshrrev_b32_e32 v9, 2, v9                                 ; 20121282
	v_add_u32_e32 v8, s6, v8                                    ; 68101006
	v_lshlrev_b32_e32 v9, 4, v9                                 ; 24121284
	v_lshrrev_b32_e32 v8, 2, v8                                 ; 20101082
	v_lshlrev_b32_e32 v8, 4, v8                                 ; 24101084
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_load_dwordx4 v[12:15], v9, s[12:15], 0 offen         ; e05c1000 80030c09
	buffer_load_dwordx4 v[16:19], v9, s[12:15], 0 offen offset:128 ; e05c1080 80031009
	buffer_load_dwordx4 v[20:23], v8, s[12:15], 0 offen         ; e05c1000 80031408
	buffer_load_dwordx4 v[8:11], v8, s[12:15], 0 offen offset:128 ; e05c1080 80030808
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_add_f32_e32 v24, v12, v13                                 ; 02301b0c
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_add_f32_e32 v25, v16, v17                                 ; 02322310
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_add_f32_e32 v26, v20, v21                                 ; 02342b14
	v_add_f32_e32 v24, v24, v14                                 ; 02301d18
	v_add_f32_e32 v25, v25, v18                                 ; 02322519
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_add_f32_e32 v27, v8, v9                                   ; 02361308
	v_add_f32_e32 v26, v26, v22                                 ; 02342d1a
	v_add_f32_e32 v24, v24, v15                                 ; 02301f18
	v_add_f32_e32 v25, v25, v19                                 ; 02322719
	v_add_f32_e32 v27, v27, v10                                 ; 0236151b
	v_add_f32_e32 v26, v26, v23                                 ; 02342f1a
	v_add_f32_e32 v27, v27, v11                                 ; 0236171b
	s_cbranch_scc0 BB65                                         ; bf8401b6
BB55:
	s_load_dwordx4 s[20:23], s[0:1], 0x0                        ; c00a0500 00000000
	s_mul_i32 s5, s16, s3                                       ; 92050310
	s_mov_b32 s9, src_scc                                       ; be8900fd
	v_lshlrev_b32_e32 v30, 1, v2                                ; 243c0481
	v_add_u32_e32 v38, 64, v4                                   ; 684c08c0
	s_add_u32 s5, s19, s5                                       ; 80050513
	v_and_b32_e32 v32, -4, v30                                  ; 26403cc4
	v_add_u32_e32 v35, 8, v30                                   ; 68463c88
	v_add_u32_e32 v28, s5, v0                                   ; 68380005
	v_lshlrev_b32_e32 v29, 4, v28                               ; 243a3884
	v_lshl_add_u32 v28, v28, 7, v29                             ; d1fd001c 04750f1c
	v_add_u32_e32 v31, 4, v28                                   ; 683e3884
	v_add_u32_e32 v36, 16, v28                                  ; 68483890
	v_add_u32_e32 v33, v32, v31                                 ; 68423f20
	v_add_u32_e32 v34, v31, v30                                 ; 68443d1f
	v_add_u32_e32 v31, v31, v35                                 ; 683e471f
	v_add_u32_e32 v37, v36, v4                                  ; 684a0924
	v_add_u32_e32 v36, v36, v38                                 ; 68484d24
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_load_dword v28, v28, s[20:23], 0 offen               ; e0501000 80051c1c
	buffer_load_dwordx2 v[40:41], v33, s[20:23], 0 offen        ; e0541000 80052821
	buffer_load_ushort v31, v31, s[20:23], 0 offen              ; e0481000 80051f1f
	buffer_load_dword v37, v37, s[20:23], 0 offen               ; e0501000 80052525
	buffer_load_dword v36, v36, s[20:23], 0 offen               ; e0501000 80052424
	s_mov_b32 s18, 0xf0f0f0f                                    ; be9200ff 0f0f0f0f
	s_cmp_lt_u32 1, s4                                          ; bf0a0481
	s_waitcnt vmcnt(4)                                          ; bf8c3f74
	v_cvt_f32_f16_sdwa v39, v28 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e4e16f9 0005061c
	v_cvt_f32_f16_e32 v28, v28                                  ; 7e38171c
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_alignbyte_b32 v40, v41, v40, v34                          ; d1cf0028 048a5129
	v_alignbyte_b32 v41, v41, v41, v34                          ; d1cf0029 048a5329
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_lshl_or_b32 v31, v31, 12, v31                             ; d200001f 047d191f
	v_mov_b32_sdwa v40, v41 dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_0 ; 7e5002f9 00041529
	v_and_b32_e32 v41, 0xc0c0c0c0, v40                          ; 265250ff c0c0c0c0
	v_and_b32_e32 v40, 0x3f3f3f3f, v40                          ; 265050ff 3f3f3f3f
	v_lshrrev_b32_e32 v41, 2, v41                               ; 20525282
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v48, s18, v37                                 ; 26604a12
	v_cvt_f32_ubyte3_e32 v42, v40                               ; 7e542928
	v_cvt_f32_ubyte2_e32 v43, v40                               ; 7e562728
	v_cvt_f32_ubyte1_e32 v44, v40                               ; 7e582528
	v_cvt_f32_ubyte0_e32 v40, v40                               ; 7e502328
	v_and_or_b32 v31, s18, v31, v41                             ; d201001f 04a63e12
	v_cvt_f32_ubyte2_e32 v50, v48                               ; 7e642730
	v_cvt_f32_ubyte3_e32 v49, v48                               ; 7e622930
	v_cvt_f32_ubyte1_e32 v51, v48                               ; 7e662530
	v_cvt_f32_ubyte0_e32 v48, v48                               ; 7e602330
	v_cvt_f32_ubyte1_e32 v47, v31                               ; 7e5e251f
	v_cvt_f32_ubyte2_e32 v46, v31                               ; 7e5c271f
	v_cvt_f32_ubyte3_e32 v45, v31                               ; 7e5a291f
	v_cvt_f32_ubyte0_e32 v31, v31                               ; 7e3e231f
	v_lshrrev_b32_e32 v37, 4, v37                               ; 204a4a84
	v_mul_f32_e32 v49, v15, v49                                 ; 0a62630f
	v_mul_f32_e32 v45, v27, v45                                 ; 0a5a5b1b
	v_and_b32_e32 v37, s18, v37                                 ; 264a4a12
	v_mac_f32_e32 v49, v14, v50                                 ; 2c62650e
	v_mac_f32_e32 v45, v26, v46                                 ; 2c5a5d1a
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v55, s18, v36                                 ; 266e4812
	v_cvt_f32_ubyte2_e32 v53, v37                               ; 7e6a2725
	v_cvt_f32_ubyte3_e32 v52, v37                               ; 7e682925
	v_cvt_f32_ubyte1_e32 v54, v37                               ; 7e6c2525
	v_cvt_f32_ubyte0_e32 v37, v37                               ; 7e4a2325
	v_mac_f32_e32 v49, v13, v51                                 ; 2c62670d
	v_mac_f32_e32 v45, v25, v42                                 ; 2c5a5519
	v_cvt_f32_ubyte3_e32 v56, v55                               ; 7e702937
	v_cvt_f32_ubyte2_e32 v57, v55                               ; 7e722737
	v_cvt_f32_ubyte1_e32 v58, v55                               ; 7e742537
	v_mul_f32_e32 v52, v19, v52                                 ; 0a686913
	v_cvt_f32_ubyte0_e32 v55, v55                               ; 7e6e2337
	v_mac_f32_e32 v49, v12, v48                                 ; 2c62610c
	v_lshrrev_b32_e32 v36, 4, v36                               ; 20484884
	v_mac_f32_e32 v45, v24, v43                                 ; 2c5a5718
	v_mul_f32_e32 v56, v23, v56                                 ; 0a707117
	v_mac_f32_e32 v52, v18, v53                                 ; 2c686b12
	v_and_b32_e32 v36, s18, v36                                 ; 26484812
	v_mad_f32 v3, -v39, v45, v3                                 ; d1c10003 240e5b27
	v_mac_f32_e32 v56, v22, v57                                 ; 2c707316
	v_mac_f32_e32 v52, v17, v54                                 ; 2c686d11
	v_cvt_f32_ubyte1_e32 v61, v36                               ; 7e7a2524
	v_cvt_f32_ubyte2_e32 v60, v36                               ; 7e782724
	v_cvt_f32_ubyte3_e32 v59, v36                               ; 7e762924
	v_cvt_f32_ubyte0_e32 v36, v36                               ; 7e482324
	v_mac_f32_e32 v56, v21, v58                                 ; 2c707515
	v_mac_f32_e32 v52, v16, v37                                 ; 2c684b10
	v_mul_f32_e32 v59, v11, v59                                 ; 0a76770b
	v_mac_f32_e32 v56, v20, v55                                 ; 2c706f14
	v_mac_f32_e32 v59, v10, v60                                 ; 2c76790a
	v_mac_f32_e32 v59, v9, v61                                  ; 2c767b09
	v_mac_f32_e32 v59, v8, v36                                  ; 2c764908
	v_mul_f32_e32 v59, v59, v47                                 ; 0a765f3b
	v_mac_f32_e32 v59, v56, v31                                 ; 2c763f38
	v_mac_f32_e32 v59, v52, v44                                 ; 2c765934
	v_mac_f32_e32 v59, v49, v40                                 ; 2c765131
	v_mac_f32_e32 v3, v28, v59                                  ; 2c06771c
	s_cbranch_scc0 BB66                                         ; bf840144
BB56:
	s_add_u32 s5, s16, 1                                        ; 80058110
	s_mul_i32 s5, s5, s3                                        ; 92050305
	s_add_u32 s5, s19, s5                                       ; 80050513
	v_add_u32_e32 v28, s5, v0                                   ; 68380005
	v_lshlrev_b32_e32 v29, 4, v28                               ; 243a3884
	v_lshl_add_u32 v28, v28, 7, v29                             ; d1fd001c 04750f1c
	v_add_u32_e32 v31, 4, v28                                   ; 683e3884
	v_add_u32_e32 v36, 16, v28                                  ; 68483890
	v_add_u32_e32 v33, v32, v31                                 ; 68423f20
	v_add_u32_e32 v34, v31, v30                                 ; 68443d1f
	v_add_u32_e32 v31, v31, v35                                 ; 683e471f
	v_add_u32_e32 v37, v36, v4                                  ; 684a0924
	v_add_u32_e32 v36, v36, v38                                 ; 68484d24
	buffer_load_dword v28, v28, s[20:23], 0 offen               ; e0501000 80051c1c
	buffer_load_dwordx2 v[40:41], v33, s[20:23], 0 offen        ; e0541000 80052821
	buffer_load_ushort v31, v31, s[20:23], 0 offen              ; e0481000 80051f1f
	buffer_load_dword v37, v37, s[20:23], 0 offen               ; e0501000 80052525
	buffer_load_dword v36, v36, s[20:23], 0 offen               ; e0501000 80052424
	s_mov_b32 s18, 0xf0f0f0f                                    ; be9200ff 0f0f0f0f
	s_cmp_lt_u32 2, s4                                          ; bf0a0482
	s_waitcnt vmcnt(4)                                          ; bf8c3f74
	v_cvt_f32_f16_sdwa v39, v28 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e4e16f9 0005061c
	v_cvt_f32_f16_e32 v28, v28                                  ; 7e38171c
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_alignbyte_b32 v40, v41, v40, v34                          ; d1cf0028 048a5129
	v_alignbyte_b32 v41, v41, v41, v34                          ; d1cf0029 048a5329
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_lshl_or_b32 v31, v31, 12, v31                             ; d200001f 047d191f
	v_mov_b32_sdwa v40, v41 dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_0 ; 7e5002f9 00041529
	v_and_b32_e32 v41, 0xc0c0c0c0, v40                          ; 265250ff c0c0c0c0
	v_and_b32_e32 v40, 0x3f3f3f3f, v40                          ; 265050ff 3f3f3f3f
	v_lshrrev_b32_e32 v41, 2, v41                               ; 20525282
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v48, s18, v37                                 ; 26604a12
	v_cvt_f32_ubyte3_e32 v42, v40                               ; 7e542928
	v_cvt_f32_ubyte2_e32 v43, v40                               ; 7e562728
	v_cvt_f32_ubyte1_e32 v44, v40                               ; 7e582528
	v_cvt_f32_ubyte0_e32 v40, v40                               ; 7e502328
	v_and_or_b32 v31, s18, v31, v41                             ; d201001f 04a63e12
	v_cvt_f32_ubyte3_e32 v49, v48                               ; 7e622930
	v_cvt_f32_ubyte2_e32 v50, v48                               ; 7e642730
	v_cvt_f32_ubyte1_e32 v51, v48                               ; 7e662530
	v_cvt_f32_ubyte0_e32 v48, v48                               ; 7e602330
	v_cvt_f32_ubyte1_e32 v47, v31                               ; 7e5e251f
	v_cvt_f32_ubyte3_e32 v45, v31                               ; 7e5a291f
	v_cvt_f32_ubyte2_e32 v46, v31                               ; 7e5c271f
	v_cvt_f32_ubyte0_e32 v31, v31                               ; 7e3e231f
	v_mul_f32_e32 v49, v15, v49                                 ; 0a62630f
	v_lshrrev_b32_e32 v37, 4, v37                               ; 204a4a84
	v_mul_f32_e32 v45, v27, v45                                 ; 0a5a5b1b
	v_mac_f32_e32 v49, v14, v50                                 ; 2c62650e
	v_and_b32_e32 v37, s18, v37                                 ; 264a4a12
	v_mac_f32_e32 v45, v26, v46                                 ; 2c5a5d1a
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v55, s18, v36                                 ; 266e4812
	v_mac_f32_e32 v49, v13, v51                                 ; 2c62670d
	v_cvt_f32_ubyte3_e32 v52, v37                               ; 7e682925
	v_cvt_f32_ubyte2_e32 v53, v37                               ; 7e6a2725
	v_cvt_f32_ubyte1_e32 v54, v37                               ; 7e6c2525
	v_cvt_f32_ubyte0_e32 v37, v37                               ; 7e4a2325
	v_mac_f32_e32 v45, v25, v42                                 ; 2c5a5519
	v_cvt_f32_ubyte2_e32 v57, v55                               ; 7e722737
	v_cvt_f32_ubyte3_e32 v56, v55                               ; 7e702937
	v_cvt_f32_ubyte1_e32 v58, v55                               ; 7e742537
	v_mac_f32_e32 v49, v12, v48                                 ; 2c62610c
	v_mul_f32_e32 v52, v19, v52                                 ; 0a686913
	v_cvt_f32_ubyte0_e32 v55, v55                               ; 7e6e2337
	v_lshrrev_b32_e32 v36, 4, v36                               ; 20484884
	v_mac_f32_e32 v45, v24, v43                                 ; 2c5a5718
	v_mul_f32_e32 v56, v23, v56                                 ; 0a707117
	v_mac_f32_e32 v52, v18, v53                                 ; 2c686b12
	v_and_b32_e32 v36, s18, v36                                 ; 26484812
	v_mad_f32 v5, -v39, v45, v5                                 ; d1c10005 24165b27
	v_mac_f32_e32 v56, v22, v57                                 ; 2c707316
	v_mac_f32_e32 v52, v17, v54                                 ; 2c686d11
	v_cvt_f32_ubyte1_e32 v61, v36                               ; 7e7a2524
	v_cvt_f32_ubyte2_e32 v60, v36                               ; 7e782724
	v_cvt_f32_ubyte3_e32 v59, v36                               ; 7e762924
	v_cvt_f32_ubyte0_e32 v36, v36                               ; 7e482324
	v_mac_f32_e32 v56, v21, v58                                 ; 2c707515
	v_mac_f32_e32 v52, v16, v37                                 ; 2c684b10
	v_mul_f32_e32 v59, v11, v59                                 ; 0a76770b
	v_mac_f32_e32 v56, v20, v55                                 ; 2c706f14
	v_mac_f32_e32 v59, v10, v60                                 ; 2c76790a
	v_mac_f32_e32 v59, v9, v61                                  ; 2c767b09
	v_mac_f32_e32 v59, v8, v36                                  ; 2c764908
	v_mul_f32_e32 v59, v59, v47                                 ; 0a765f3b
	v_mac_f32_e32 v59, v56, v31                                 ; 2c763f38
	v_mac_f32_e32 v59, v52, v44                                 ; 2c765934
	v_mac_f32_e32 v59, v49, v40                                 ; 2c765131
	v_mac_f32_e32 v5, v28, v59                                  ; 2c0a771c
	s_cbranch_scc0 BB66                                         ; bf8400d8
BB57:
	s_add_u32 s5, s16, 2                                        ; 80058210
	s_mul_i32 s5, s5, s3                                        ; 92050305
	s_add_u32 s5, s19, s5                                       ; 80050513
	v_add_u32_e32 v28, s5, v0                                   ; 68380005
	v_lshlrev_b32_e32 v29, 4, v28                               ; 243a3884
	v_lshl_add_u32 v28, v28, 7, v29                             ; d1fd001c 04750f1c
	v_add_u32_e32 v31, 4, v28                                   ; 683e3884
	v_add_u32_e32 v36, 16, v28                                  ; 68483890
	v_add_u32_e32 v33, v32, v31                                 ; 68423f20
	v_add_u32_e32 v34, v31, v30                                 ; 68443d1f
	v_add_u32_e32 v31, v31, v35                                 ; 683e471f
	v_add_u32_e32 v37, v36, v4                                  ; 684a0924
	v_add_u32_e32 v36, v36, v38                                 ; 68484d24
	buffer_load_dword v28, v28, s[20:23], 0 offen               ; e0501000 80051c1c
	buffer_load_dwordx2 v[40:41], v33, s[20:23], 0 offen        ; e0541000 80052821
	buffer_load_ushort v31, v31, s[20:23], 0 offen              ; e0481000 80051f1f
	buffer_load_dword v37, v37, s[20:23], 0 offen               ; e0501000 80052525
	buffer_load_dword v36, v36, s[20:23], 0 offen               ; e0501000 80052424
	s_mov_b32 s18, 0xf0f0f0f                                    ; be9200ff 0f0f0f0f
	s_cmp_lt_u32 3, s4                                          ; bf0a0483
	s_waitcnt vmcnt(4)                                          ; bf8c3f74
	v_cvt_f32_f16_sdwa v39, v28 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e4e16f9 0005061c
	v_cvt_f32_f16_e32 v28, v28                                  ; 7e38171c
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_alignbyte_b32 v40, v41, v40, v34                          ; d1cf0028 048a5129
	v_alignbyte_b32 v41, v41, v41, v34                          ; d1cf0029 048a5329
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_lshl_or_b32 v31, v31, 12, v31                             ; d200001f 047d191f
	v_mov_b32_sdwa v40, v41 dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_0 ; 7e5002f9 00041529
	v_and_b32_e32 v41, 0xc0c0c0c0, v40                          ; 265250ff c0c0c0c0
	v_and_b32_e32 v40, 0x3f3f3f3f, v40                          ; 265050ff 3f3f3f3f
	v_lshrrev_b32_e32 v41, 2, v41                               ; 20525282
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v48, s18, v37                                 ; 26604a12
	v_cvt_f32_ubyte3_e32 v42, v40                               ; 7e542928
	v_cvt_f32_ubyte2_e32 v43, v40                               ; 7e562728
	v_cvt_f32_ubyte1_e32 v44, v40                               ; 7e582528
	v_cvt_f32_ubyte0_e32 v40, v40                               ; 7e502328
	v_and_or_b32 v31, s18, v31, v41                             ; d201001f 04a63e12
	v_cvt_f32_ubyte3_e32 v49, v48                               ; 7e622930
	v_cvt_f32_ubyte2_e32 v50, v48                               ; 7e642730
	v_cvt_f32_ubyte1_e32 v51, v48                               ; 7e662530
	v_cvt_f32_ubyte0_e32 v48, v48                               ; 7e602330
	v_cvt_f32_ubyte1_e32 v47, v31                               ; 7e5e251f
	v_cvt_f32_ubyte3_e32 v45, v31                               ; 7e5a291f
	v_cvt_f32_ubyte2_e32 v46, v31                               ; 7e5c271f
	v_cvt_f32_ubyte0_e32 v31, v31                               ; 7e3e231f
	v_mul_f32_e32 v49, v15, v49                                 ; 0a62630f
	v_lshrrev_b32_e32 v37, 4, v37                               ; 204a4a84
	v_mul_f32_e32 v45, v27, v45                                 ; 0a5a5b1b
	v_mac_f32_e32 v49, v14, v50                                 ; 2c62650e
	v_and_b32_e32 v37, s18, v37                                 ; 264a4a12
	v_mac_f32_e32 v45, v26, v46                                 ; 2c5a5d1a
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v55, s18, v36                                 ; 266e4812
	v_mac_f32_e32 v49, v13, v51                                 ; 2c62670d
	v_cvt_f32_ubyte3_e32 v52, v37                               ; 7e682925
	v_cvt_f32_ubyte2_e32 v53, v37                               ; 7e6a2725
	v_cvt_f32_ubyte1_e32 v54, v37                               ; 7e6c2525
	v_cvt_f32_ubyte0_e32 v37, v37                               ; 7e4a2325
	v_mac_f32_e32 v45, v25, v42                                 ; 2c5a5519
	v_cvt_f32_ubyte2_e32 v57, v55                               ; 7e722737
	v_cvt_f32_ubyte3_e32 v56, v55                               ; 7e702937
	v_cvt_f32_ubyte1_e32 v58, v55                               ; 7e742537
	v_mac_f32_e32 v49, v12, v48                                 ; 2c62610c
	v_mul_f32_e32 v52, v19, v52                                 ; 0a686913
	v_cvt_f32_ubyte0_e32 v55, v55                               ; 7e6e2337
	v_lshrrev_b32_e32 v36, 4, v36                               ; 20484884
	v_mac_f32_e32 v45, v24, v43                                 ; 2c5a5718
	v_mul_f32_e32 v56, v23, v56                                 ; 0a707117
	v_mac_f32_e32 v52, v18, v53                                 ; 2c686b12
	v_and_b32_e32 v36, s18, v36                                 ; 26484812
	v_mad_f32 v6, -v39, v45, v6                                 ; d1c10006 241a5b27
	v_mac_f32_e32 v56, v22, v57                                 ; 2c707316
	v_mac_f32_e32 v52, v17, v54                                 ; 2c686d11
	v_cvt_f32_ubyte1_e32 v61, v36                               ; 7e7a2524
	v_cvt_f32_ubyte2_e32 v60, v36                               ; 7e782724
	v_cvt_f32_ubyte3_e32 v59, v36                               ; 7e762924
	v_cvt_f32_ubyte0_e32 v36, v36                               ; 7e482324
	v_mac_f32_e32 v56, v21, v58                                 ; 2c707515
	v_mac_f32_e32 v52, v16, v37                                 ; 2c684b10
	v_mul_f32_e32 v59, v11, v59                                 ; 0a76770b
	v_mac_f32_e32 v56, v20, v55                                 ; 2c706f14
	v_mac_f32_e32 v59, v10, v60                                 ; 2c76790a
	v_mac_f32_e32 v59, v9, v61                                  ; 2c767b09
	v_mac_f32_e32 v59, v8, v36                                  ; 2c764908
	v_mul_f32_e32 v59, v59, v47                                 ; 0a765f3b
	v_mac_f32_e32 v59, v56, v31                                 ; 2c763f38
	v_mac_f32_e32 v59, v52, v44                                 ; 2c765934
	v_mac_f32_e32 v59, v49, v40                                 ; 2c765131
	v_mac_f32_e32 v6, v28, v59                                  ; 2c0c771c
	s_cbranch_scc0 BB66                                         ; bf84006c
BB58:
	s_add_u32 s5, s16, 3                                        ; 80058310
	s_mul_i32 s5, s5, s3                                        ; 92050305
	s_add_u32 s5, s19, s5                                       ; 80050513
	v_add_u32_e32 v28, s5, v0                                   ; 68380005
	v_lshlrev_b32_e32 v29, 4, v28                               ; 243a3884
	v_lshl_add_u32 v28, v28, 7, v29                             ; d1fd001c 04750f1c
	v_add_u32_e32 v31, 4, v28                                   ; 683e3884
	v_add_u32_e32 v33, 16, v28                                  ; 68423890
	v_add_u32_e32 v32, v32, v31                                 ; 68403f20
	v_add_u32_e32 v30, v31, v30                                 ; 683c3d1f
	v_add_u32_e32 v31, v31, v35                                 ; 683e471f
	v_add_u32_e32 v34, v33, v4                                  ; 68440921
	v_add_u32_e32 v33, v33, v38                                 ; 68424d21
	buffer_load_dword v28, v28, s[20:23], 0 offen               ; e0501000 80051c1c
	buffer_load_dwordx2 v[36:37], v32, s[20:23], 0 offen        ; e0541000 80052420
	buffer_load_ushort v31, v31, s[20:23], 0 offen              ; e0481000 80051f1f
	buffer_load_dword v34, v34, s[20:23], 0 offen               ; e0501000 80052222
	buffer_load_dword v33, v33, s[20:23], 0 offen               ; e0501000 80052121
	s_mov_b32 s18, 0xf0f0f0f                                    ; be9200ff 0f0f0f0f
	s_waitcnt vmcnt(4)                                          ; bf8c3f74
	v_cvt_f32_f16_sdwa v35, v28 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e4616f9 0005061c
	v_cvt_f32_f16_e32 v28, v28                                  ; 7e38171c
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_alignbyte_b32 v36, v37, v36, v30                          ; d1cf0024 047a4925
	v_alignbyte_b32 v37, v37, v37, v30                          ; d1cf0025 047a4b25
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_lshl_or_b32 v31, v31, 12, v31                             ; d200001f 047d191f
	v_mov_b32_sdwa v36, v37 dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_0 ; 7e4802f9 00041525
	v_and_b32_e32 v37, 0xc0c0c0c0, v36                          ; 264a48ff c0c0c0c0
	v_and_b32_e32 v36, 0x3f3f3f3f, v36                          ; 264848ff 3f3f3f3f
	v_lshrrev_b32_e32 v37, 2, v37                               ; 204a4a82
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v44, s18, v34                                 ; 26584412
	v_cvt_f32_ubyte3_e32 v38, v36                               ; 7e4c2924
	v_cvt_f32_ubyte2_e32 v39, v36                               ; 7e4e2724
	v_cvt_f32_ubyte1_e32 v40, v36                               ; 7e502524
	v_cvt_f32_ubyte0_e32 v36, v36                               ; 7e482324
	v_and_or_b32 v31, s18, v31, v37                             ; d201001f 04963e12
	v_cvt_f32_ubyte3_e32 v45, v44                               ; 7e5a292c
	v_cvt_f32_ubyte2_e32 v46, v44                               ; 7e5c272c
	v_cvt_f32_ubyte1_e32 v47, v44                               ; 7e5e252c
	v_cvt_f32_ubyte0_e32 v44, v44                               ; 7e58232c
	v_cvt_f32_ubyte3_e32 v41, v31                               ; 7e52291f
	v_cvt_f32_ubyte2_e32 v42, v31                               ; 7e54271f
	v_cvt_f32_ubyte1_e32 v43, v31                               ; 7e56251f
	v_cvt_f32_ubyte0_e32 v31, v31                               ; 7e3e231f
	v_mul_f32_e32 v15, v15, v45                                 ; 0a1e5b0f
	v_lshrrev_b32_e32 v34, 4, v34                               ; 20444484
	v_mul_f32_e32 v27, v27, v41                                 ; 0a36531b
	v_mac_f32_e32 v15, v14, v46                                 ; 2c1e5d0e
	v_and_b32_e32 v34, s18, v34                                 ; 26444412
	v_mac_f32_e32 v27, v26, v42                                 ; 2c36551a
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v51, s18, v33                                 ; 26664212
	v_mac_f32_e32 v15, v13, v47                                 ; 2c1e5f0d
	v_cvt_f32_ubyte3_e32 v48, v34                               ; 7e602922
	v_cvt_f32_ubyte2_e32 v49, v34                               ; 7e622722
	v_cvt_f32_ubyte1_e32 v50, v34                               ; 7e642522
	v_cvt_f32_ubyte0_e32 v34, v34                               ; 7e442322
	v_mac_f32_e32 v27, v25, v38                                 ; 2c364d19
	v_cvt_f32_ubyte2_e32 v53, v51                               ; 7e6a2733
	v_cvt_f32_ubyte3_e32 v52, v51                               ; 7e682933
	v_cvt_f32_ubyte1_e32 v54, v51                               ; 7e6c2533
	v_mac_f32_e32 v15, v12, v44                                 ; 2c1e590c
	v_mul_f32_e32 v19, v19, v48                                 ; 0a266113
	v_cvt_f32_ubyte0_e32 v51, v51                               ; 7e662333
	v_lshrrev_b32_e32 v33, 4, v33                               ; 20424284
	v_mac_f32_e32 v27, v24, v39                                 ; 2c364f18
	v_mul_f32_e32 v23, v23, v52                                 ; 0a2e6917
	v_mac_f32_e32 v19, v18, v49                                 ; 2c266312
	v_and_b32_e32 v33, s18, v33                                 ; 26424212
	v_mad_f32 v7, -v35, v27, v7                                 ; d1c10007 241e3723
	v_mac_f32_e32 v23, v22, v53                                 ; 2c2e6b16
	v_mac_f32_e32 v19, v17, v50                                 ; 2c266511
	v_cvt_f32_ubyte2_e32 v56, v33                               ; 7e702721
	v_cvt_f32_ubyte1_e32 v57, v33                               ; 7e722521
	v_cvt_f32_ubyte3_e32 v55, v33                               ; 7e6e2921
	v_cvt_f32_ubyte0_e32 v33, v33                               ; 7e422321
	v_mac_f32_e32 v23, v21, v54                                 ; 2c2e6d15
	v_mac_f32_e32 v19, v16, v34                                 ; 2c264510
	v_mul_f32_e32 v11, v11, v55                                 ; 0a166f0b
	v_mac_f32_e32 v23, v20, v51                                 ; 2c2e6714
	v_mac_f32_e32 v11, v10, v56                                 ; 2c16710a
	v_mac_f32_e32 v11, v9, v57                                  ; 2c167309
	v_mac_f32_e32 v11, v8, v33                                  ; 2c164308
	v_mul_f32_e32 v11, v11, v43                                 ; 0a16570b
	v_mac_f32_e32 v11, v23, v31                                 ; 2c163f17
	v_mac_f32_e32 v11, v19, v40                                 ; 2c165113
	v_mac_f32_e32 v11, v15, v36                                 ; 2c16490f
	v_mac_f32_e32 v7, v28, v11                                  ; 2c0e171c
	s_branch BB66                                               ; bf820001
BB65:
	s_mov_b32 s9, src_scc                                       ; be8900fd
BB66:
	v_add_u32_e32 v0, 4, v0                                     ; 68000084
	s_mov_b64 s[20:21], exec                                    ; be94017e
	v_cmpx_le_u32_e32 vcc, s3, v0                               ; 7db60003
BB67:
	s_andn2_b64 s[20:21], s[20:21], exec                        ; 89947e14
	s_cbranch_scc1 BB71                                         ; bf85fe1e
BB72:
	s_mov_b64 exec, s[10:11]                                    ; befe010a
BB75:
	s_andn2_b64 exec, -1, exec                                  ; 89fe7ec1
	v_mov_b32_e32 v3, 0                                         ; 7e060280
	v_mov_b32_e32 v5, 0                                         ; 7e0a0280
	v_mov_b32_e32 v6, 0                                         ; 7e0c0280
	v_mov_b32_e32 v7, 0                                         ; 7e0e0280
BB77:
	s_mov_b64 exec, -1                                          ; befe01c1
	s_cmp_lg_i32 s4, 0                                          ; bf018004
	s_cselect_b64 s[0:1], -1, 0                                 ; 858080c1
	s_cbranch_scc0 BB89                                         ; bf84006a
BB78:
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
	s_cbranch_scc0 BB87                                         ; bf84004f
BB79:
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
	s_cbranch_scc0 BB85                                         ; bf840034
BB80:
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
	s_cbranch_scc0 BB83                                         ; bf840019
BB81:
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
BB83:
	v_mov_b32_e32 v6, s6                                        ; 7e0c0206
BB85:
	v_mov_b32_e32 v5, s5                                        ; 7e0a0205
BB87:
	v_mov_b32_e32 v3, s3                                        ; 7e060203
BB89:
	s_mov_b64 s[10:11], 1                                       ; be8a0181
	s_and_b64 exec, s[0:1], s[10:11]                            ; 86fe0a00
	s_cbranch_execz BB131                                       ; bf880083
BB90:
	s_bitcmp1_b32 s8, 0                                         ; bf0d8008
	s_cbranch_scc0 BB92                                         ; bf84000e
BB91:
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
	s_branch BB93                                               ; bf820001
BB92:
	s_mov_b32 s1, src_scc                                       ; be8100fd
BB93:
	s_bitcmp1_b32 s8, 1                                         ; bf0d8108
	s_cbranch_scc0 BB95                                         ; bf84000e
BB94:
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
	s_branch BB96                                               ; bf820001
BB95:
	s_mov_b32 s3, src_scc                                       ; be8300fd
BB96:
	s_mov_b32 s0, s3                                            ; be800003
	s_movk_i32 s3, 0x8000                                       ; b0038000
	s_load_dwordx4 s[8:11], s[2:3], 0x20                        ; c00a0201 00000020
	s_mul_i32 s7, s7, s17                                       ; 92071107
	s_add_u32 s7, s7, s16                                       ; 80071007
	s_lshl_b32 s7, s7, 2                                        ; 8e078207
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_store_dword v3, off, s[8:11], s7                     ; e0700000 07020380
	s_cmp_lt_u32 1, s4                                          ; bf0a0481
	s_cbranch_scc0 BB131                                        ; bf840055
BB97:
	s_cmp_lg_i32 s1, 0                                          ; bf018001
	s_cbranch_scc0 BB99                                         ; bf84000a
BB98:
	s_load_dwordx4 s[12:15], s[2:3], 0x30                       ; c00a0301 00000030
	s_mov_b32 s1, src_scc                                       ; be8100fd
	s_add_u32 s5, s7, 4                                         ; 80058407
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s5, s[12:15], s5                        ; c0200146 00000005
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v5, s5, v5                                    ; 020a0a05
	s_branch BB100                                              ; bf820001
BB99:
	s_mov_b32 s1, src_scc                                       ; be8100fd
BB100:
	s_cmp_lg_i32 s0, 0                                          ; bf018000
	s_cbranch_scc0 BB102                                        ; bf84000a
BB101:
	s_load_dwordx4 s[12:15], s[2:3], 0x40                       ; c00a0301 00000040
	s_mov_b32 s0, src_scc                                       ; be8000fd
	s_add_u32 s5, s7, 4                                         ; 80058407
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s5, s[12:15], s5                        ; c0200146 00000005
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v5, s5, v5                                    ; 020a0a05
	s_branch BB103                                              ; bf820001
BB102:
	s_mov_b32 s0, src_scc                                       ; be8000fd
BB103:
	s_add_u32 s5, s7, 4                                         ; 80058407
	buffer_store_dword v5, off, s[8:11], s5                     ; e0700000 05020580
	s_cmp_lt_u32 2, s4                                          ; bf0a0482
	s_cbranch_scc0 BB131                                        ; bf840036
BB104:
	s_cmp_lg_i32 s1, 0                                          ; bf018001
	s_cbranch_scc0 BB106                                        ; bf84000a
BB105:
	s_load_dwordx4 s[12:15], s[2:3], 0x30                       ; c00a0301 00000030
	s_mov_b32 s1, src_scc                                       ; be8100fd
	s_add_u32 s5, s7, 8                                         ; 80058807
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s5, s[12:15], s5                        ; c0200146 00000005
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v6, s5, v6                                    ; 020c0c05
	s_branch BB107                                              ; bf820001
BB106:
	s_mov_b32 s1, src_scc                                       ; be8100fd
BB107:
	s_cmp_lg_i32 s0, 0                                          ; bf018000
	s_cbranch_scc0 BB109                                        ; bf84000a
BB108:
	s_load_dwordx4 s[12:15], s[2:3], 0x40                       ; c00a0301 00000040
	s_mov_b32 s0, src_scc                                       ; be8000fd
	s_add_u32 s5, s7, 8                                         ; 80058807
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s5, s[12:15], s5                        ; c0200146 00000005
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v6, s5, v6                                    ; 020c0c05
	s_branch BB110                                              ; bf820001
BB109:
	s_mov_b32 s0, src_scc                                       ; be8000fd
BB110:
	s_add_u32 s5, s7, 8                                         ; 80058807
	buffer_store_dword v6, off, s[8:11], s5                     ; e0700000 05020680
	s_cmp_lt_u32 3, s4                                          ; bf0a0483
	s_cbranch_scc0 BB131                                        ; bf840017
BB111:
	s_cmp_lg_i32 s1, 0                                          ; bf018001
	s_cbranch_scc0 BB114                                        ; bf840008
BB112:
	s_load_dwordx4 s[12:15], s[2:3], 0x30                       ; c00a0301 00000030
	s_add_u32 s1, s7, 12                                        ; 80018c07
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s1, s[12:15], s1                        ; c0200046 00000001
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v7, s1, v7                                    ; 020e0e01
BB114:
	s_cmp_lg_i32 s0, 0                                          ; bf018000
	s_cbranch_scc0 BB117                                        ; bf840008
BB115:
	s_load_dwordx4 s[0:3], s[2:3], 0x40                         ; c00a0001 00000040
	s_add_u32 s4, s7, 12                                        ; 80048c07
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s4, s[0:3], s4                          ; c0200100 00000004
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v7, s4, v7                                    ; 020e0e04
BB117:
	s_add_u32 s7, s7, 12                                        ; 80078c07
	buffer_store_dword v7, off, s[8:11], s7                     ; e0700000 07020780
BB131:
	s_endpgm                                                    ; bf810000
