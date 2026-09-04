BB0:
	s_load_dword s0, s[14:15], 0x0                              ; c0020007 00000000
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_mul_i32 s0, s0, s18                                       ; 92001200
	s_add_u32 s16, s16, s0                                      ; 80100010
	s_lshl_b32 s16, s16, 2                                      ; 8e108210
	s_add_u32 s1, s16, 4                                        ; 80018410
	s_cmp_ge_u32 s4, s1                                         ; bf090104
	s_cbranch_scc0 BB42                                         ; bf8402fe
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
	v_mov_b32_e32 v7, 0                                         ; 7e0e0280
	s_mul_i32 s18, s18, s5                                      ; 92120512
	v_mov_b32_e32 v8, 0                                         ; 7e100280
	v_mov_b32_e32 v9, 0                                         ; 7e120280
	v_sub_u32_e32 v1, v2, v1                                    ; 6a020302
	v_bfe_u32 v3, v2, 2, 1                                      ; d1c80003 02050502
	v_lshrrev_b32_e32 v2, 3, v2                                 ; 20040483
	v_lshl_add_u32 v1, v1, 1, v3                                ; d1fd0001 040d0301
	v_mov_b32_e32 v3, 0                                         ; 7e060280
	v_lshlrev_b32_e32 v5, 4, v2                                 ; 240a0484
	v_lshlrev_b32_e32 v1, 2, v1                                 ; 24020282
	v_sub_u32_e32 v6, 16, v5                                    ; 6a0c0a90
	v_lshl_add_u32 v4, v2, 5, v1                                ; d1fd0004 04050b02
	v_lshl_add_u32 v1, v2, 6, v1                                ; d1fd0001 04050d02
	s_branch BB5                                                ; bf8201b3
BB10:
	s_mov_b64 exec, s[0:1]                                      ; befe0100
	s_mov_b32 s0, s2                                            ; be800002
	s_movk_i32 s1, 0x8000                                       ; b0018000
	s_load_dwordx8 s[24:31], s[0:1], 0x0                        ; c00e0600 00000000
	s_mul_i32 s0, s6, s17                                       ; 92001106
	v_lshl_add_u32 v10, v0, 8, v1                               ; d1fd000a 04051100
	v_add_u32_e32 v11, s0, v10                                  ; 68161400
	v_add_u32_e32 v10, 0x80, v10                                ; 681414ff 00000080
	v_lshrrev_b32_e32 v11, 2, v11                               ; 20161682
	v_add_u32_e32 v10, s0, v10                                  ; 68141400
	v_lshlrev_b32_e32 v11, 4, v11                               ; 24161684
	v_lshrrev_b32_e32 v10, 2, v10                               ; 20141482
	v_lshlrev_b32_e32 v10, 4, v10                               ; 24141484
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_load_dwordx4 v[12:15], v11, s[28:31], 0 offen        ; e05c1000 80070c0b
	buffer_load_dwordx4 v[16:19], v11, s[28:31], 0 offen offset:128 ; e05c1080 8007100b
	buffer_load_dwordx4 v[20:23], v10, s[28:31], 0 offen        ; e05c1000 8007140a
	buffer_load_dwordx4 v[24:27], v10, s[28:31], 0 offen offset:128 ; e05c1080 8007180a
	s_mul_i32 s1, s16, s3                                       ; 92010310
	v_lshl_add_u32 v30, v2, 1, 8                                ; d1fd001e 02210302
	v_add_u32_e32 v34, 64, v4                                   ; 684408c0
	s_add_u32 s1, s18, s1                                       ; 80010112
	s_add_u32 s4, s16, 1                                        ; 80048110
	v_add_u32_e32 v28, s1, v0                                   ; 68380001
	s_mul_i32 s4, s4, s3                                        ; 92040304
	v_lshlrev_b32_e32 v29, 4, v28                               ; 243a3884
	s_add_u32 s4, s18, s4                                       ; 80040412
	s_add_u32 s5, s16, 2                                        ; 80058210
	v_lshl_add_u32 v28, v28, 7, v29                             ; d1fd001c 04750f1c
	v_add_u32_e32 v35, s4, v0                                   ; 68460004
	s_mul_i32 s5, s5, s3                                        ; 92050305
	v_add_u32_e32 v32, 16, v28                                  ; 68403890
	v_add3_u32 v31, v30, 4, v28                                 ; d1ff001f 0471091e
	v_lshlrev_b32_e32 v36, 4, v35                               ; 24484684
	s_add_u32 s5, s18, s5                                       ; 80050512
	v_add_u32_e32 v33, v32, v4                                  ; 68420920
	v_add_u32_e32 v32, v32, v34                                 ; 68404520
	s_add_u32 s9, s16, 3                                        ; 80098310
	v_lshl_add_u32 v35, v35, 7, v36                             ; d1fd0023 04910f23
	v_add_u32_e32 v40, s5, v0                                   ; 68500005
	s_mul_i32 s9, s9, s3                                        ; 92090309
	v_add3_u32 v37, v30, 4, v35                                 ; d1ff0025 048d091e
	v_add_u32_e32 v38, 16, v35                                  ; 684c4690
	v_lshlrev_b32_e32 v41, 4, v40                               ; 24525084
	s_add_u32 s9, s18, s9                                       ; 80090912
	v_add_u32_e32 v39, v38, v4                                  ; 684e0926
	v_add_u32_e32 v38, v38, v34                                 ; 684c4526
	v_lshl_add_u32 v40, v40, 7, v41                             ; d1fd0028 04a50f28
	v_add_u32_e32 v45, s9, v0                                   ; 685a0009
	v_add_u32_e32 v43, 16, v40                                  ; 68565090
	v_add3_u32 v42, v30, 4, v40                                 ; d1ff002a 04a1091e
	v_lshlrev_b32_e32 v46, 4, v45                               ; 245c5a84
	v_add_u32_e32 v44, v43, v4                                  ; 6858092b
	v_add_u32_e32 v43, v43, v34                                 ; 6856452b
	v_lshl_add_u32 v45, v45, 7, v46                             ; d1fd002d 04b90f2d
	v_add_u32_e32 v47, 16, v45                                  ; 685e5a90
	v_add3_u32 v30, v30, 4, v45                                 ; d1ff001e 04b5091e
	v_add_u32_e32 v48, v47, v4                                  ; 6860092f
	v_add_u32_e32 v47, v47, v34                                 ; 685e452f
	buffer_load_dwordx3 v[49:51], v28, s[24:27], 0 offen        ; e0581000 8006311c
	buffer_load_ushort v31, v31, s[24:27], 0 offen              ; e0481000 80061f1f
	buffer_load_dword v33, v33, s[24:27], 0 offen               ; e0501000 80062121
	buffer_load_dword v32, v32, s[24:27], 0 offen               ; e0501000 80062020
	buffer_load_dwordx3 v[52:54], v35, s[24:27], 0 offen        ; e0581000 80063423
	buffer_load_ushort v37, v37, s[24:27], 0 offen              ; e0481000 80062525
	buffer_load_dword v39, v39, s[24:27], 0 offen               ; e0501000 80062727
	buffer_load_dword v38, v38, s[24:27], 0 offen               ; e0501000 80062626
	buffer_load_dwordx3 v[55:57], v40, s[24:27], 0 offen        ; e0581000 80063728
	buffer_load_ushort v42, v42, s[24:27], 0 offen              ; e0481000 80062a2a
	buffer_load_dword v44, v44, s[24:27], 0 offen               ; e0501000 80062c2c
	buffer_load_dword v43, v43, s[24:27], 0 offen               ; e0501000 80062b2b
	buffer_load_dwordx3 v[58:60], v45, s[24:27], 0 offen        ; e0581000 80063a2d
	buffer_load_ushort v30, v30, s[24:27], 0 offen              ; e0481000 80061e1e
	buffer_load_dword v48, v48, s[24:27], 0 offen               ; e0501000 80063030
	buffer_load_dword v47, v47, s[24:27], 0 offen               ; e0501000 80062f2f
	s_bfm_b32 s10, 16, 16                                       ; 910a9090
	s_mov_b32 s11, 0xf0f0f0f                                    ; be8b00ff 0f0f0f0f
	s_mov_b32 s12, 0xc0c0c0c0                                   ; be8c00ff c0c0c0c0
	s_mov_b32 s13, 0x3f3f3f3f                                   ; be8d00ff 3f3f3f3f
	v_add_u32_e32 v0, 4, v0                                     ; 68000084
	s_waitcnt vmcnt(19)                                         ; bf8c7f73
	v_add_f32_e32 v61, v12, v13                                 ; 027a1b0c
	s_waitcnt vmcnt(18)                                         ; bf8c7f72
	v_add_f32_e32 v62, v16, v17                                 ; 027c2310
	s_waitcnt vmcnt(17)                                         ; bf8c7f71
	v_add_f32_e32 v10, v20, v21                                 ; 02142b14
	v_add_f32_e32 v61, v61, v14                                 ; 027a1d3d
	s_waitcnt vmcnt(16)                                         ; bf8c7f70
	v_add_f32_e32 v11, v24, v25                                 ; 02163318
	v_add_f32_e32 v62, v62, v18                                 ; 027c253e
	v_add_f32_e32 v10, v10, v22                                 ; 02142d0a
	v_add_f32_e32 v61, v61, v15                                 ; 027a1f3d
	v_add_f32_e32 v11, v11, v26                                 ; 0216350b
	v_add_f32_e32 v62, v62, v19                                 ; 027c273e
	v_add_f32_e32 v10, v10, v23                                 ; 02142f0a
	v_add_f32_e32 v11, v11, v27                                 ; 0216370b
	s_waitcnt vmcnt(15)                                         ; bf8c3f7f
	v_lshlrev_b32_e32 v51, v6, v51                              ; 24666706
	v_cvt_f32_f16_sdwa v36, v49 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e4816f9 00050631
	v_bfe_u32 v50, v50, v5, 16                                  ; d1c80032 02420b32
	v_cvt_f32_f16_e32 v49, v49                                  ; 7e621731
	s_waitcnt vmcnt(14)                                         ; bf8c3f7e
	v_lshl_or_b32 v31, v31, 12, v31                             ; d200001f 047d191f
	s_waitcnt vmcnt(13)                                         ; bf8c3f7d
	v_and_b32_e32 v40, s11, v33                                 ; 2650420b
	v_and_or_b32 v51, s10, v51, v50                             ; d2010033 04ca660a
	v_cvt_f32_ubyte3_e32 v41, v40                               ; 7e522928
	v_cvt_f32_ubyte2_e32 v45, v40                               ; 7e5a2728
	v_cvt_f32_ubyte1_e32 v46, v40                               ; 7e5c2528
	v_cvt_f32_ubyte0_e32 v40, v40                               ; 7e502328
	v_lshrrev_b32_e32 v33, 4, v33                               ; 20424284
	v_and_b32_e32 v28, s12, v51                                 ; 2638660c
	v_and_b32_e32 v51, s13, v51                                 ; 2666660d
	v_mul_f32_e32 v41, v15, v41                                 ; 0a52530f
	v_and_b32_e32 v33, s11, v33                                 ; 2642420b
	v_lshrrev_b32_e32 v28, 2, v28                               ; 20383882
	v_cvt_f32_ubyte3_e32 v29, v51                               ; 7e3a2933
	v_cvt_f32_ubyte1_e32 v35, v51                               ; 7e462533
	v_cvt_f32_ubyte2_e32 v34, v51                               ; 7e442733
	v_cvt_f32_ubyte0_e32 v51, v51                               ; 7e662333
	v_mac_f32_e32 v41, v14, v45                                 ; 2c525b0e
	v_cvt_f32_ubyte3_e32 v50, v33                               ; 7e642921
	s_waitcnt vmcnt(12)                                         ; bf8c3f7c
	v_and_b32_e32 v45, s11, v32                                 ; 265a400b
	v_and_or_b32 v31, s11, v31, v28                             ; d201001f 04723e0b
	v_cvt_f32_ubyte2_e32 v28, v33                               ; 7e382721
	v_mac_f32_e32 v41, v13, v46                                 ; 2c525d0d
	v_mul_f32_e32 v50, v19, v50                                 ; 0a646513
	v_cvt_f32_ubyte3_e32 v46, v45                               ; 7e5c292d
	v_lshrrev_b32_e32 v32, 4, v32                               ; 20404084
	v_mac_f32_e32 v41, v12, v40                                 ; 2c52510c
	v_cvt_f32_ubyte1_e32 v40, v33                               ; 7e502521
	v_cvt_f32_ubyte0_e32 v33, v33                               ; 7e422321
	v_mac_f32_e32 v50, v18, v28                                 ; 2c643912
	v_cvt_f32_ubyte2_e32 v28, v45                               ; 7e38272d
	v_mul_f32_e32 v46, v23, v46                                 ; 0a5c5d17
	v_and_b32_e32 v32, s11, v32                                 ; 2640400b
	v_mac_f32_e32 v50, v17, v40                                 ; 2c645111
	v_mac_f32_e32 v46, v22, v28                                 ; 2c5c3916
	v_cvt_f32_ubyte1_e32 v28, v32                               ; 7e382520
	v_cvt_f32_ubyte3_e32 v40, v32                               ; 7e502920
	v_mac_f32_e32 v50, v16, v33                                 ; 2c644310
	v_cvt_f32_ubyte1_e32 v33, v45                               ; 7e42252d
	v_cvt_f32_ubyte0_e32 v45, v45                               ; 7e5a232d
	v_mul_f32_e32 v40, v27, v40                                 ; 0a50511b
	v_mac_f32_e32 v46, v21, v33                                 ; 2c5c4315
	v_cvt_f32_ubyte2_e32 v33, v31                               ; 7e42271f
	v_mac_f32_e32 v46, v20, v45                                 ; 2c5c5b14
	v_cvt_f32_ubyte2_e32 v45, v32                               ; 7e5a2720
	v_cvt_f32_ubyte0_e32 v32, v32                               ; 7e402320
	v_mac_f32_e32 v40, v26, v45                                 ; 2c505b1a
	s_waitcnt vmcnt(11)                                         ; bf8c3f7b
	v_bfe_u32 v53, v53, v5, 16                                  ; d1c80035 02420b35
	v_lshlrev_b32_e32 v54, v6, v54                              ; 246c6d06
	v_mac_f32_e32 v40, v25, v28                                 ; 2c503919
	v_and_or_b32 v54, s10, v54, v53                             ; d2010036 04d66c0a
	v_mac_f32_e32 v40, v24, v32                                 ; 2c504118
	v_cvt_f32_ubyte3_e32 v32, v31                               ; 7e40291f
	v_mul_f32_e32 v32, v11, v32                                 ; 0a40410b
	v_mac_f32_e32 v32, v10, v33                                 ; 2c40430a
	v_mac_f32_e32 v32, v62, v29                                 ; 2c403b3e
	v_mac_f32_e32 v32, v61, v34                                 ; 2c40453d
	v_cvt_f32_ubyte1_e32 v34, v31                               ; 7e44251f
	v_cvt_f32_ubyte0_e32 v31, v31                               ; 7e3e231f
	v_cvt_f32_f16_sdwa v45, v52 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e5a16f9 00050634
	v_mad_f32 v3, -v36, v32, v3                                 ; d1c10003 240e4124
	v_cvt_f32_f16_e32 v52, v52                                  ; 7e681734
	s_waitcnt vmcnt(10)                                         ; bf8c3f7a
	v_lshl_or_b32 v37, v37, 12, v37                             ; d2000025 04951925
	v_mul_f32_e32 v40, v40, v34                                 ; 0a504528
	v_mac_f32_e32 v40, v46, v31                                 ; 2c503f2e
	v_mac_f32_e32 v40, v50, v35                                 ; 2c504732
	v_and_b32_e32 v35, s12, v54                                 ; 26466c0c
	v_and_b32_e32 v54, s13, v54                                 ; 266c6c0d
	v_mac_f32_e32 v40, v41, v51                                 ; 2c506729
	v_lshrrev_b32_e32 v35, 2, v35                               ; 20464682
	v_cvt_f32_ubyte1_e32 v41, v54                               ; 7e522536
	v_cvt_f32_ubyte3_e32 v36, v54                               ; 7e482936
	s_waitcnt vmcnt(9)                                          ; bf8c3f79
	v_and_b32_e32 v51, s11, v39                                 ; 26664e0b
	v_mac_f32_e32 v3, v49, v40                                  ; 2c065131
	v_cvt_f32_ubyte2_e32 v40, v54                               ; 7e502736
	v_cvt_f32_ubyte0_e32 v54, v54                               ; 7e6c2336
	v_and_or_b32 v37, s11, v37, v35                             ; d2010025 048e4a0b
	v_cvt_f32_ubyte2_e32 v28, v51                               ; 7e382733
	v_cvt_f32_ubyte3_e32 v53, v51                               ; 7e6a2933
	v_cvt_f32_ubyte1_e32 v29, v51                               ; 7e3a2533
	v_cvt_f32_ubyte0_e32 v51, v51                               ; 7e662333
	v_cvt_f32_ubyte1_e32 v50, v37                               ; 7e642525
	v_cvt_f32_ubyte2_e32 v49, v37                               ; 7e622725
	v_cvt_f32_ubyte3_e32 v46, v37                               ; 7e5c2925
	v_cvt_f32_ubyte0_e32 v37, v37                               ; 7e4a2325
	v_lshrrev_b32_e32 v39, 4, v39                               ; 204e4e84
	v_mul_f32_e32 v53, v15, v53                                 ; 0a6a6b0f
	v_mul_f32_e32 v46, v11, v46                                 ; 0a5c5d0b
	v_and_b32_e32 v39, s11, v39                                 ; 264e4e0b
	v_mac_f32_e32 v53, v14, v28                                 ; 2c6a390e
	s_waitcnt vmcnt(8)                                          ; bf8c3f78
	v_and_b32_e32 v34, s11, v38                                 ; 26444c0b
	v_mac_f32_e32 v46, v10, v49                                 ; 2c5c630a
	v_cvt_f32_ubyte2_e32 v32, v39                               ; 7e402727
	v_cvt_f32_ubyte3_e32 v31, v39                               ; 7e3e2927
	v_cvt_f32_ubyte1_e32 v33, v39                               ; 7e422527
	v_cvt_f32_ubyte0_e32 v39, v39                               ; 7e4e2327
	v_mac_f32_e32 v53, v13, v29                                 ; 2c6a3b0d
	v_cvt_f32_ubyte3_e32 v35, v34                               ; 7e462922
	v_mac_f32_e32 v46, v62, v36                                 ; 2c5c493e
	v_cvt_f32_ubyte2_e32 v36, v34                               ; 7e482722
	v_mul_f32_e32 v31, v19, v31                                 ; 0a3e3f13
	v_mac_f32_e32 v53, v12, v51                                 ; 2c6a670c
	v_lshrrev_b32_e32 v38, 4, v38                               ; 204c4c84
	v_mul_f32_e32 v35, v23, v35                                 ; 0a464717
	v_mac_f32_e32 v46, v61, v40                                 ; 2c5c513d
	v_mac_f32_e32 v31, v18, v32                                 ; 2c3e4112
	v_and_b32_e32 v38, s11, v38                                 ; 264c4c0b
	v_mac_f32_e32 v35, v22, v36                                 ; 2c464916
	v_mad_f32 v7, -v45, v46, v7                                 ; d1c10007 241e5d2d
	v_mac_f32_e32 v31, v17, v33                                 ; 2c3e4311
	v_cvt_f32_ubyte2_e32 v45, v38                               ; 7e5a2726
	v_cvt_f32_ubyte1_e32 v46, v38                               ; 7e5c2526
	v_cvt_f32_ubyte3_e32 v40, v38                               ; 7e502926
	v_cvt_f32_ubyte0_e32 v38, v38                               ; 7e4c2326
	v_mac_f32_e32 v31, v16, v39                                 ; 2c3e4f10
	v_cvt_f32_ubyte1_e32 v39, v34                               ; 7e4e2522
	v_cvt_f32_ubyte0_e32 v34, v34                               ; 7e442322
	s_waitcnt vmcnt(7)                                          ; bf8c3f77
	v_bfe_u32 v56, v56, v5, 16                                  ; d1c80038 02420b38
	v_mul_f32_e32 v40, v27, v40                                 ; 0a50511b
	v_lshlrev_b32_e32 v57, v6, v57                              ; 24727306
	v_mac_f32_e32 v35, v21, v39                                 ; 2c464f15
	v_mac_f32_e32 v40, v26, v45                                 ; 2c505b1a
	v_and_or_b32 v57, s10, v57, v56                             ; d2010039 04e2720a
	v_mac_f32_e32 v35, v20, v34                                 ; 2c464514
	v_mac_f32_e32 v40, v25, v46                                 ; 2c505d19
	v_and_b32_e32 v49, s12, v57                                 ; 2662720c
	v_and_b32_e32 v57, s13, v57                                 ; 2672720d
	s_waitcnt vmcnt(6)                                          ; bf8c3f76
	v_lshl_or_b32 v42, v42, 12, v42                             ; d200002a 04a9192a
	v_mac_f32_e32 v40, v24, v38                                 ; 2c504d18
	v_lshrrev_b32_e32 v49, 2, v49                               ; 20626282
	v_cvt_f32_ubyte2_e32 v51, v57                               ; 7e662739
	v_mul_f32_e32 v40, v40, v50                                 ; 0a506528
	v_cvt_f32_ubyte3_e32 v50, v57                               ; 7e642939
	v_and_or_b32 v42, s11, v42, v49                             ; d201002a 04c6540b
	v_mac_f32_e32 v40, v35, v37                                 ; 2c504b23
	s_waitcnt vmcnt(5)                                          ; bf8c3f75
	v_and_b32_e32 v28, s11, v44                                 ; 2638580b
	v_cvt_f32_ubyte2_e32 v56, v42                               ; 7e70272a
	v_mac_f32_e32 v40, v31, v41                                 ; 2c50531f
	v_cvt_f32_ubyte2_e32 v31, v28                               ; 7e3e271c
	v_cvt_f32_ubyte3_e32 v29, v28                               ; 7e3a291c
	v_cvt_f32_ubyte1_e32 v32, v28                               ; 7e40251c
	v_mac_f32_e32 v40, v53, v54                                 ; 2c506d35
	v_cvt_f32_f16_sdwa v53, v55 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e6a16f9 00050637
	v_cvt_f32_f16_e32 v55, v55                                  ; 7e6e1737
	v_cvt_f32_ubyte3_e32 v54, v42                               ; 7e6c292a
	v_cvt_f32_ubyte0_e32 v28, v28                               ; 7e38231c
	v_mul_f32_e32 v29, v15, v29                                 ; 0a3a3b0f
	v_lshrrev_b32_e32 v44, 4, v44                               ; 20585884
	v_mac_f32_e32 v7, v52, v40                                  ; 2c0e5134
	v_cvt_f32_ubyte1_e32 v52, v57                               ; 7e682539
	v_cvt_f32_ubyte0_e32 v57, v57                               ; 7e722339
	v_mul_f32_e32 v54, v11, v54                                 ; 0a6c6d0b
	v_mac_f32_e32 v29, v14, v31                                 ; 2c3a3f0e
	v_and_b32_e32 v44, s11, v44                                 ; 2658580b
	s_waitcnt vmcnt(4)                                          ; bf8c3f74
	v_and_b32_e32 v36, s11, v43                                 ; 2648560b
	v_mac_f32_e32 v54, v10, v56                                 ; 2c6c710a
	v_mac_f32_e32 v29, v13, v32                                 ; 2c3a410d
	v_cvt_f32_ubyte1_e32 v35, v44                               ; 7e46252c
	v_cvt_f32_ubyte3_e32 v33, v44                               ; 7e42292c
	v_cvt_f32_ubyte2_e32 v34, v44                               ; 7e44272c
	v_cvt_f32_ubyte0_e32 v44, v44                               ; 7e58232c
	v_cvt_f32_ubyte3_e32 v37, v36                               ; 7e4a2924
	v_cvt_f32_ubyte2_e32 v38, v36                               ; 7e4c2724
	v_cvt_f32_ubyte1_e32 v39, v36                               ; 7e4e2524
	v_mac_f32_e32 v54, v62, v50                                 ; 2c6c653e
	v_mac_f32_e32 v29, v12, v28                                 ; 2c3a390c
	v_cvt_f32_ubyte0_e32 v36, v36                               ; 7e482324
	v_mul_f32_e32 v33, v19, v33                                 ; 0a424313
	v_lshrrev_b32_e32 v43, 4, v43                               ; 20565684
	v_mul_f32_e32 v37, v23, v37                                 ; 0a4a4b17
	v_mac_f32_e32 v54, v61, v51                                 ; 2c6c673d
	v_mac_f32_e32 v33, v18, v34                                 ; 2c424512
	v_and_b32_e32 v43, s11, v43                                 ; 2656560b
	v_cvt_f32_ubyte1_e32 v45, v42                               ; 7e5a252a
	v_mac_f32_e32 v37, v22, v38                                 ; 2c4a4d16
	v_cvt_f32_ubyte0_e32 v42, v42                               ; 7e54232a
	v_mac_f32_e32 v33, v17, v35                                 ; 2c424711
	v_cvt_f32_ubyte3_e32 v40, v43                               ; 7e50292b
	v_cvt_f32_ubyte2_e32 v41, v43                               ; 7e52272b
	v_mac_f32_e32 v37, v21, v39                                 ; 2c4a4f15
	v_mad_f32 v8, -v53, v54, v8                                 ; d1c10008 24226d35
	v_mac_f32_e32 v33, v16, v44                                 ; 2c425910
	v_cvt_f32_ubyte1_e32 v44, v43                               ; 7e58252b
	v_cvt_f32_ubyte0_e32 v43, v43                               ; 7e56232b
	v_mul_f32_e32 v40, v27, v40                                 ; 0a50511b
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_bfe_u32 v59, v59, v5, 16                                  ; d1c8003b 02420b3b
	v_lshlrev_b32_e32 v60, v6, v60                              ; 24787906
	v_mac_f32_e32 v37, v20, v36                                 ; 2c4a4914
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_lshl_or_b32 v30, v30, 12, v30                             ; d200001e 0479191e
	v_mac_f32_e32 v40, v26, v41                                 ; 2c50531a
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v49, s11, v48                                 ; 2662600b
	v_and_or_b32 v60, s10, v60, v59                             ; d201003c 04ee780a
	v_mac_f32_e32 v40, v25, v44                                 ; 2c505919
	v_cvt_f32_ubyte3_e32 v50, v49                               ; 7e642931
	v_cvt_f32_ubyte2_e32 v51, v49                               ; 7e662731
	v_and_b32_e32 v46, s12, v60                                 ; 265c780c
	v_mac_f32_e32 v40, v24, v43                                 ; 2c505718
	v_lshrrev_b32_e32 v48, 4, v48                               ; 20606084
	v_mul_f32_e32 v15, v15, v50                                 ; 0a1e650f
	v_lshrrev_b32_e32 v46, 2, v46                               ; 205c5c82
	v_mul_f32_e32 v40, v40, v45                                 ; 0a505b28
	v_and_b32_e32 v48, s11, v48                                 ; 2660600b
	v_mac_f32_e32 v15, v14, v51                                 ; 2c1e670e
	v_and_or_b32 v30, s11, v30, v46                             ; d201001e 04ba3c0b
	v_mac_f32_e32 v40, v37, v42                                 ; 2c505525
	v_cvt_f32_ubyte2_e32 v54, v48                               ; 7e6c2730
	v_cvt_f32_ubyte3_e32 v53, v48                               ; 7e6a2930
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v56, s11, v47                                 ; 26705e0b
	v_mac_f32_e32 v40, v33, v52                                 ; 2c506921
	v_cvt_f32_ubyte1_e32 v52, v49                               ; 7e682531
	v_cvt_f32_ubyte0_e32 v49, v49                               ; 7e622331
	v_mul_f32_e32 v19, v19, v53                                 ; 0a266b13
	v_cvt_f32_ubyte2_e32 v59, v56                               ; 7e762738
	v_mac_f32_e32 v40, v29, v57                                 ; 2c50731d
	v_cvt_f32_ubyte3_e32 v57, v56                               ; 7e722938
	v_mac_f32_e32 v15, v13, v52                                 ; 2c1e690d
	v_mac_f32_e32 v19, v18, v54                                 ; 2c266d12
	v_lshrrev_b32_e32 v47, 4, v47                               ; 205e5e84
	v_mac_f32_e32 v8, v55, v40                                  ; 2c105137
	v_cvt_f32_ubyte1_e32 v55, v48                               ; 7e6e2530
	v_cvt_f32_ubyte0_e32 v48, v48                               ; 7e602330
	v_mul_f32_e32 v23, v23, v57                                 ; 0a2e7317
	v_mac_f32_e32 v15, v12, v49                                 ; 2c1e630c
	v_cvt_f32_ubyte1_e32 v12, v56                               ; 7e182538
	v_cvt_f32_ubyte0_e32 v56, v56                               ; 7e702338
	v_and_b32_e32 v47, s11, v47                                 ; 265e5e0b
	v_mac_f32_e32 v19, v17, v55                                 ; 2c266f11
	v_mac_f32_e32 v23, v22, v59                                 ; 2c2e7716
	v_cvt_f32_ubyte3_e32 v17, v30                               ; 7e22291e
	v_cvt_f32_ubyte2_e32 v18, v30                               ; 7e24271e
	v_cvt_f32_ubyte2_e32 v14, v47                               ; 7e1c272f
	v_cvt_f32_ubyte3_e32 v13, v47                               ; 7e1a292f
	v_mac_f32_e32 v19, v16, v48                                 ; 2c266110
	v_cvt_f32_ubyte1_e32 v16, v47                               ; 7e20252f
	v_cvt_f32_ubyte0_e32 v47, v47                               ; 7e5e232f
	v_and_b32_e32 v60, s13, v60                                 ; 2678780d
	v_mac_f32_e32 v23, v21, v12                                 ; 2c2e1915
	v_mul_f32_e32 v11, v11, v17                                 ; 0a16230b
	v_cvt_f32_ubyte1_e32 v22, v30                               ; 7e2c251e
	v_mul_f32_e32 v27, v27, v13                                 ; 0a361b1b
	v_cvt_f32_ubyte0_e32 v30, v30                               ; 7e3c231e
	v_cvt_f32_ubyte2_e32 v21, v60                               ; 7e2a273c
	v_mac_f32_e32 v23, v20, v56                                 ; 2c2e7114
	v_cvt_f32_ubyte3_e32 v20, v60                               ; 7e28293c
	v_mac_f32_e32 v11, v10, v18                                 ; 2c16250a
	v_mac_f32_e32 v27, v26, v14                                 ; 2c361d1a
	v_mac_f32_e32 v11, v62, v20                                 ; 2c16293e
	v_mac_f32_e32 v27, v25, v16                                 ; 2c362119
	v_mac_f32_e32 v11, v61, v21                                 ; 2c162b3d
	v_mac_f32_e32 v27, v24, v47                                 ; 2c365f18
	v_cvt_f32_f16_sdwa v24, v58 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e3016f9 0005063a
	v_cvt_f32_f16_e32 v58, v58                                  ; 7e74173a
	v_mul_f32_e32 v27, v27, v22                                 ; 0a362d1b
	v_mad_f32 v9, -v24, v11, v9                                 ; d1c10009 24261718
	v_mac_f32_e32 v27, v23, v30                                 ; 2c363d17
	v_cvt_f32_ubyte1_e32 v23, v60                               ; 7e2e253c
	v_cvt_f32_ubyte0_e32 v60, v60                               ; 7e78233c
	v_mac_f32_e32 v27, v19, v23                                 ; 2c362f13
	v_mac_f32_e32 v27, v15, v60                                 ; 2c36790f
	v_mac_f32_e32 v9, v58, v27                                  ; 2c12373a
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
	s_branch BB119                                              ; bf820325
BB42:
	s_cmp_lt_u32 s16, s4                                        ; bf0a0410
	s_cbranch_scc0 BB119                                        ; bf840323
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
	v_mov_b32_e32 v7, 0                                         ; 7e0e0280
	s_mul_i32 s19, s19, s5                                      ; 92130513
	v_mov_b32_e32 v8, 0                                         ; 7e100280
	v_mov_b32_e32 v9, 0                                         ; 7e120280
	v_sub_u32_e32 v1, v2, v1                                    ; 6a020302
	v_bfe_u32 v3, v2, 2, 1                                      ; d1c80003 02050502
	v_lshrrev_b32_e32 v2, 3, v2                                 ; 20040483
	v_lshl_add_u32 v1, v1, 1, v3                                ; d1fd0001 040d0301
	v_mov_b32_e32 v3, 0                                         ; 7e060280
	v_lshlrev_b32_e32 v5, 4, v2                                 ; 240a0484
	v_lshlrev_b32_e32 v1, 2, v1                                 ; 24020282
	v_sub_u32_e32 v6, 16, v5                                    ; 6a0c0a90
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
	v_lshl_add_u32 v10, v0, 8, v1                               ; d1fd000a 04051100
	v_add_u32_e32 v11, s5, v10                                  ; 68161405
	v_add_u32_e32 v10, 0x80, v10                                ; 681414ff 00000080
	v_lshrrev_b32_e32 v11, 2, v11                               ; 20161682
	v_add_u32_e32 v10, s5, v10                                  ; 68141405
	v_lshlrev_b32_e32 v11, 4, v11                               ; 24161684
	v_lshrrev_b32_e32 v10, 2, v10                               ; 20141482
	v_lshlrev_b32_e32 v10, 4, v10                               ; 24141484
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_load_dwordx4 v[12:15], v11, s[12:15], 0 offen        ; e05c1000 80030c0b
	buffer_load_dwordx4 v[16:19], v11, s[12:15], 0 offen offset:128 ; e05c1080 8003100b
	buffer_load_dwordx4 v[20:23], v10, s[12:15], 0 offen        ; e05c1000 8003140a
	buffer_load_dwordx4 v[24:27], v10, s[12:15], 0 offen offset:128 ; e05c1080 8003180a
	s_cmp_lg_i32 s4, 0                                          ; bf018004
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_add_f32_e32 v28, v12, v13                                 ; 02381b0c
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_add_f32_e32 v29, v16, v17                                 ; 023a2310
	v_add_f32_e32 v28, v28, v14                                 ; 02381d1c
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_add_f32_e32 v30, v20, v21                                 ; 023c2b14
	v_add_f32_e32 v29, v29, v18                                 ; 023a251d
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_add_f32_e32 v31, v24, v25                                 ; 023e3318
	v_add_f32_e32 v28, v28, v15                                 ; 02381f1c
	v_add_f32_e32 v30, v30, v22                                 ; 023c2d1e
	v_add_f32_e32 v29, v29, v19                                 ; 023a271d
	v_add_f32_e32 v31, v31, v26                                 ; 023e351f
	v_add_f32_e32 v30, v30, v23                                 ; 023c2f1e
	v_add_f32_e32 v31, v31, v27                                 ; 023e371f
	s_cbranch_scc0 BB64                                         ; bf84019f
BB53:
	s_load_dwordx4 s[12:15], s[0:1], 0x0                        ; c00a0300 00000000
	s_mul_i32 s0, s16, s3                                       ; 92000310
	v_lshl_add_u32 v32, v2, 1, 8                                ; d1fd0020 02210302
	v_add_u32_e32 v36, 64, v4                                   ; 684808c0
	s_add_u32 s0, s19, s0                                       ; 80000013
	v_add_u32_e32 v10, s0, v0                                   ; 68140000
	v_lshlrev_b32_e32 v11, 4, v10                               ; 24161484
	v_lshl_add_u32 v10, v10, 7, v11                             ; d1fd000a 042d0f0a
	v_add3_u32 v33, v32, 4, v10                                 ; d1ff0021 04290920
	v_add_u32_e32 v34, 16, v10                                  ; 68441490
	v_add_u32_e32 v35, v34, v4                                  ; 68460922
	v_add_u32_e32 v34, v34, v36                                 ; 68444922
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_load_dwordx3 v[37:39], v10, s[12:15], 0 offen        ; e0581000 8003250a
	buffer_load_ushort v33, v33, s[12:15], 0 offen              ; e0481000 80032121
	buffer_load_dword v35, v35, s[12:15], 0 offen               ; e0501000 80032323
	buffer_load_dword v34, v34, s[12:15], 0 offen               ; e0501000 80032222
	s_bfm_b32 s1, 16, 16                                        ; 91019090
	s_mov_b32 s5, 0xf0f0f0f                                     ; be8500ff 0f0f0f0f
	s_cmp_lt_u32 1, s4                                          ; bf0a0481
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_lshlrev_b32_e32 v39, v6, v39                              ; 244e4f06
	v_bfe_u32 v38, v38, v5, 16                                  ; d1c80026 02420b26
	v_cvt_f32_f16_sdwa v44, v37 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e5816f9 00050625
	v_cvt_f32_f16_e32 v37, v37                                  ; 7e4a1725
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_lshl_or_b32 v33, v33, 12, v33                             ; d2000021 04851921
	v_and_or_b32 v39, s1, v39, v38                              ; d2010027 049a4e01
	v_and_b32_e32 v40, 0xc0c0c0c0, v39                          ; 26504eff c0c0c0c0
	v_and_b32_e32 v39, 0x3f3f3f3f, v39                          ; 264e4eff 3f3f3f3f
	v_lshrrev_b32_e32 v40, 2, v40                               ; 20505082
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v48, s5, v35                                  ; 26604605
	v_cvt_f32_ubyte3_e32 v41, v39                               ; 7e522927
	v_cvt_f32_ubyte2_e32 v42, v39                               ; 7e542727
	v_cvt_f32_ubyte1_e32 v43, v39                               ; 7e562527
	v_cvt_f32_ubyte0_e32 v39, v39                               ; 7e4e2327
	v_and_or_b32 v33, s5, v33, v40                              ; d2010021 04a24205
	v_cvt_f32_ubyte3_e32 v49, v48                               ; 7e622930
	v_cvt_f32_ubyte2_e32 v50, v48                               ; 7e642730
	v_cvt_f32_ubyte1_e32 v51, v48                               ; 7e662530
	v_cvt_f32_ubyte0_e32 v48, v48                               ; 7e602330
	v_cvt_f32_ubyte3_e32 v45, v33                               ; 7e5a2921
	v_cvt_f32_ubyte2_e32 v46, v33                               ; 7e5c2721
	v_cvt_f32_ubyte1_e32 v47, v33                               ; 7e5e2521
	v_cvt_f32_ubyte0_e32 v33, v33                               ; 7e422321
	v_mul_f32_e32 v49, v15, v49                                 ; 0a62630f
	v_lshrrev_b32_e32 v35, 4, v35                               ; 20464684
	v_mul_f32_e32 v45, v31, v45                                 ; 0a5a5b1f
	v_mac_f32_e32 v49, v14, v50                                 ; 2c62650e
	v_and_b32_e32 v35, s5, v35                                  ; 26464605
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v55, s5, v34                                  ; 266e4405
	v_mac_f32_e32 v45, v30, v46                                 ; 2c5a5d1e
	v_mac_f32_e32 v49, v13, v51                                 ; 2c62670d
	v_cvt_f32_ubyte3_e32 v52, v35                               ; 7e682923
	v_cvt_f32_ubyte2_e32 v53, v35                               ; 7e6a2723
	v_cvt_f32_ubyte1_e32 v54, v35                               ; 7e6c2523
	v_cvt_f32_ubyte0_e32 v35, v35                               ; 7e462323
	v_cvt_f32_ubyte2_e32 v57, v55                               ; 7e722737
	v_cvt_f32_ubyte3_e32 v56, v55                               ; 7e702937
	v_mac_f32_e32 v45, v29, v41                                 ; 2c5a531d
	v_cvt_f32_ubyte1_e32 v58, v55                               ; 7e742537
	v_mac_f32_e32 v49, v12, v48                                 ; 2c62610c
	v_mul_f32_e32 v52, v19, v52                                 ; 0a686913
	v_cvt_f32_ubyte0_e32 v55, v55                               ; 7e6e2337
	v_lshrrev_b32_e32 v34, 4, v34                               ; 20444484
	v_mul_f32_e32 v56, v23, v56                                 ; 0a707117
	v_mac_f32_e32 v45, v28, v42                                 ; 2c5a551c
	v_mac_f32_e32 v52, v18, v53                                 ; 2c686b12
	v_and_b32_e32 v34, s5, v34                                  ; 26444405
	v_mac_f32_e32 v56, v22, v57                                 ; 2c707316
	v_mad_f32 v3, -v44, v45, v3                                 ; d1c10003 240e5b2c
	v_mac_f32_e32 v52, v17, v54                                 ; 2c686d11
	v_cvt_f32_ubyte1_e32 v61, v34                               ; 7e7a2522
	v_cvt_f32_ubyte2_e32 v60, v34                               ; 7e782722
	v_cvt_f32_ubyte3_e32 v59, v34                               ; 7e762922
	v_cvt_f32_ubyte0_e32 v34, v34                               ; 7e442322
	v_mac_f32_e32 v56, v21, v58                                 ; 2c707515
	v_mac_f32_e32 v52, v16, v35                                 ; 2c684710
	v_mul_f32_e32 v59, v27, v59                                 ; 0a76771b
	v_mac_f32_e32 v56, v20, v55                                 ; 2c706f14
	v_mac_f32_e32 v59, v26, v60                                 ; 2c76791a
	v_mac_f32_e32 v59, v25, v61                                 ; 2c767b19
	v_mac_f32_e32 v59, v24, v34                                 ; 2c764518
	v_mul_f32_e32 v59, v59, v47                                 ; 0a765f3b
	v_mac_f32_e32 v59, v56, v33                                 ; 2c764338
	v_mac_f32_e32 v59, v52, v43                                 ; 2c765734
	v_mac_f32_e32 v59, v49, v39                                 ; 2c764f31
	v_mac_f32_e32 v3, v37, v59                                  ; 2c067725
	s_cbranch_scc0 BB64                                         ; bf840133
BB54:
	s_add_u32 s0, s16, 1                                        ; 80008110
	s_mul_i32 s0, s0, s3                                        ; 92000300
	s_add_u32 s0, s19, s0                                       ; 80000013
	v_add_u32_e32 v10, s0, v0                                   ; 68140000
	v_lshlrev_b32_e32 v11, 4, v10                               ; 24161484
	v_lshl_add_u32 v10, v10, 7, v11                             ; d1fd000a 042d0f0a
	v_add3_u32 v33, v32, 4, v10                                 ; d1ff0021 04290920
	v_add_u32_e32 v34, 16, v10                                  ; 68441490
	v_add_u32_e32 v35, v34, v4                                  ; 68460922
	v_add_u32_e32 v34, v34, v36                                 ; 68444922
	buffer_load_dwordx3 v[37:39], v10, s[12:15], 0 offen        ; e0581000 8003250a
	buffer_load_ushort v33, v33, s[12:15], 0 offen              ; e0481000 80032121
	buffer_load_dword v35, v35, s[12:15], 0 offen               ; e0501000 80032323
	buffer_load_dword v34, v34, s[12:15], 0 offen               ; e0501000 80032222
	s_bfm_b32 s1, 16, 16                                        ; 91019090
	s_mov_b32 s5, 0xf0f0f0f                                     ; be8500ff 0f0f0f0f
	s_cmp_lt_u32 2, s4                                          ; bf0a0482
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_bfe_u32 v38, v38, v5, 16                                  ; d1c80026 02420b26
	v_lshlrev_b32_e32 v39, v6, v39                              ; 244e4f06
	v_cvt_f32_f16_sdwa v44, v37 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e5816f9 00050625
	v_cvt_f32_f16_e32 v37, v37                                  ; 7e4a1725
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_lshl_or_b32 v33, v33, 12, v33                             ; d2000021 04851921
	v_and_or_b32 v39, s1, v39, v38                              ; d2010027 049a4e01
	v_and_b32_e32 v40, 0xc0c0c0c0, v39                          ; 26504eff c0c0c0c0
	v_and_b32_e32 v39, 0x3f3f3f3f, v39                          ; 264e4eff 3f3f3f3f
	v_lshrrev_b32_e32 v40, 2, v40                               ; 20505082
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v48, s5, v35                                  ; 26604605
	v_cvt_f32_ubyte3_e32 v41, v39                               ; 7e522927
	v_cvt_f32_ubyte2_e32 v42, v39                               ; 7e542727
	v_cvt_f32_ubyte1_e32 v43, v39                               ; 7e562527
	v_cvt_f32_ubyte0_e32 v39, v39                               ; 7e4e2327
	v_and_or_b32 v33, s5, v33, v40                              ; d2010021 04a24205
	v_cvt_f32_ubyte3_e32 v49, v48                               ; 7e622930
	v_cvt_f32_ubyte2_e32 v50, v48                               ; 7e642730
	v_cvt_f32_ubyte1_e32 v51, v48                               ; 7e662530
	v_cvt_f32_ubyte0_e32 v48, v48                               ; 7e602330
	v_cvt_f32_ubyte2_e32 v46, v33                               ; 7e5c2721
	v_cvt_f32_ubyte1_e32 v47, v33                               ; 7e5e2521
	v_cvt_f32_ubyte3_e32 v45, v33                               ; 7e5a2921
	v_cvt_f32_ubyte0_e32 v33, v33                               ; 7e422321
	v_mul_f32_e32 v49, v15, v49                                 ; 0a62630f
	v_lshrrev_b32_e32 v35, 4, v35                               ; 20464684
	v_mul_f32_e32 v45, v31, v45                                 ; 0a5a5b1f
	v_mac_f32_e32 v49, v14, v50                                 ; 2c62650e
	v_and_b32_e32 v35, s5, v35                                  ; 26464605
	v_mac_f32_e32 v45, v30, v46                                 ; 2c5a5d1e
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v55, s5, v34                                  ; 266e4405
	v_mac_f32_e32 v49, v13, v51                                 ; 2c62670d
	v_cvt_f32_ubyte1_e32 v54, v35                               ; 7e6c2523
	v_cvt_f32_ubyte2_e32 v53, v35                               ; 7e6a2723
	v_cvt_f32_ubyte3_e32 v52, v35                               ; 7e682923
	v_cvt_f32_ubyte0_e32 v35, v35                               ; 7e462323
	v_mac_f32_e32 v45, v29, v41                                 ; 2c5a531d
	v_cvt_f32_ubyte2_e32 v57, v55                               ; 7e722737
	v_cvt_f32_ubyte3_e32 v56, v55                               ; 7e702937
	v_cvt_f32_ubyte1_e32 v58, v55                               ; 7e742537
	v_mac_f32_e32 v49, v12, v48                                 ; 2c62610c
	v_cvt_f32_ubyte0_e32 v55, v55                               ; 7e6e2337
	v_mul_f32_e32 v52, v19, v52                                 ; 0a686913
	v_lshrrev_b32_e32 v34, 4, v34                               ; 20444484
	v_mac_f32_e32 v45, v28, v42                                 ; 2c5a551c
	v_mul_f32_e32 v56, v23, v56                                 ; 0a707117
	v_mac_f32_e32 v52, v18, v53                                 ; 2c686b12
	v_and_b32_e32 v34, s5, v34                                  ; 26444405
	v_mad_f32 v7, -v44, v45, v7                                 ; d1c10007 241e5b2c
	v_mac_f32_e32 v56, v22, v57                                 ; 2c707316
	v_mac_f32_e32 v52, v17, v54                                 ; 2c686d11
	v_cvt_f32_ubyte1_e32 v61, v34                               ; 7e7a2522
	v_cvt_f32_ubyte2_e32 v60, v34                               ; 7e782722
	v_cvt_f32_ubyte3_e32 v59, v34                               ; 7e762922
	v_cvt_f32_ubyte0_e32 v34, v34                               ; 7e442322
	v_mac_f32_e32 v56, v21, v58                                 ; 2c707515
	v_mac_f32_e32 v52, v16, v35                                 ; 2c684710
	v_mul_f32_e32 v59, v27, v59                                 ; 0a76771b
	v_mac_f32_e32 v56, v20, v55                                 ; 2c706f14
	v_mac_f32_e32 v59, v26, v60                                 ; 2c76791a
	v_mac_f32_e32 v59, v25, v61                                 ; 2c767b19
	v_mac_f32_e32 v59, v24, v34                                 ; 2c764518
	v_mul_f32_e32 v59, v59, v47                                 ; 0a765f3b
	v_mac_f32_e32 v59, v56, v33                                 ; 2c764338
	v_mac_f32_e32 v59, v52, v43                                 ; 2c765734
	v_mac_f32_e32 v59, v49, v39                                 ; 2c764f31
	v_mac_f32_e32 v7, v37, v59                                  ; 2c0e7725
	s_cbranch_scc0 BB64                                         ; bf8400cc
BB55:
	s_add_u32 s0, s16, 2                                        ; 80008210
	s_mul_i32 s0, s0, s3                                        ; 92000300
	s_add_u32 s0, s19, s0                                       ; 80000013
	v_add_u32_e32 v10, s0, v0                                   ; 68140000
	v_lshlrev_b32_e32 v11, 4, v10                               ; 24161484
	v_lshl_add_u32 v10, v10, 7, v11                             ; d1fd000a 042d0f0a
	v_add3_u32 v33, v32, 4, v10                                 ; d1ff0021 04290920
	v_add_u32_e32 v34, 16, v10                                  ; 68441490
	v_add_u32_e32 v35, v34, v4                                  ; 68460922
	v_add_u32_e32 v34, v34, v36                                 ; 68444922
	buffer_load_dwordx3 v[37:39], v10, s[12:15], 0 offen        ; e0581000 8003250a
	buffer_load_ushort v33, v33, s[12:15], 0 offen              ; e0481000 80032121
	buffer_load_dword v35, v35, s[12:15], 0 offen               ; e0501000 80032323
	buffer_load_dword v34, v34, s[12:15], 0 offen               ; e0501000 80032222
	s_bfm_b32 s1, 16, 16                                        ; 91019090
	s_mov_b32 s5, 0xf0f0f0f                                     ; be8500ff 0f0f0f0f
	s_cmp_lt_u32 3, s4                                          ; bf0a0483
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_bfe_u32 v38, v38, v5, 16                                  ; d1c80026 02420b26
	v_lshlrev_b32_e32 v39, v6, v39                              ; 244e4f06
	v_cvt_f32_f16_sdwa v44, v37 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e5816f9 00050625
	v_cvt_f32_f16_e32 v37, v37                                  ; 7e4a1725
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_lshl_or_b32 v33, v33, 12, v33                             ; d2000021 04851921
	v_and_or_b32 v39, s1, v39, v38                              ; d2010027 049a4e01
	v_and_b32_e32 v40, 0xc0c0c0c0, v39                          ; 26504eff c0c0c0c0
	v_and_b32_e32 v39, 0x3f3f3f3f, v39                          ; 264e4eff 3f3f3f3f
	v_lshrrev_b32_e32 v40, 2, v40                               ; 20505082
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v48, s5, v35                                  ; 26604605
	v_cvt_f32_ubyte3_e32 v41, v39                               ; 7e522927
	v_cvt_f32_ubyte2_e32 v42, v39                               ; 7e542727
	v_cvt_f32_ubyte1_e32 v43, v39                               ; 7e562527
	v_cvt_f32_ubyte0_e32 v39, v39                               ; 7e4e2327
	v_and_or_b32 v33, s5, v33, v40                              ; d2010021 04a24205
	v_cvt_f32_ubyte3_e32 v49, v48                               ; 7e622930
	v_cvt_f32_ubyte2_e32 v50, v48                               ; 7e642730
	v_cvt_f32_ubyte1_e32 v51, v48                               ; 7e662530
	v_cvt_f32_ubyte0_e32 v48, v48                               ; 7e602330
	v_cvt_f32_ubyte2_e32 v46, v33                               ; 7e5c2721
	v_cvt_f32_ubyte1_e32 v47, v33                               ; 7e5e2521
	v_cvt_f32_ubyte3_e32 v45, v33                               ; 7e5a2921
	v_cvt_f32_ubyte0_e32 v33, v33                               ; 7e422321
	v_mul_f32_e32 v49, v15, v49                                 ; 0a62630f
	v_lshrrev_b32_e32 v35, 4, v35                               ; 20464684
	v_mul_f32_e32 v45, v31, v45                                 ; 0a5a5b1f
	v_mac_f32_e32 v49, v14, v50                                 ; 2c62650e
	v_and_b32_e32 v35, s5, v35                                  ; 26464605
	v_mac_f32_e32 v45, v30, v46                                 ; 2c5a5d1e
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v55, s5, v34                                  ; 266e4405
	v_mac_f32_e32 v49, v13, v51                                 ; 2c62670d
	v_cvt_f32_ubyte1_e32 v54, v35                               ; 7e6c2523
	v_cvt_f32_ubyte2_e32 v53, v35                               ; 7e6a2723
	v_cvt_f32_ubyte3_e32 v52, v35                               ; 7e682923
	v_cvt_f32_ubyte0_e32 v35, v35                               ; 7e462323
	v_mac_f32_e32 v45, v29, v41                                 ; 2c5a531d
	v_cvt_f32_ubyte2_e32 v57, v55                               ; 7e722737
	v_cvt_f32_ubyte3_e32 v56, v55                               ; 7e702937
	v_cvt_f32_ubyte1_e32 v58, v55                               ; 7e742537
	v_mac_f32_e32 v49, v12, v48                                 ; 2c62610c
	v_cvt_f32_ubyte0_e32 v55, v55                               ; 7e6e2337
	v_mul_f32_e32 v52, v19, v52                                 ; 0a686913
	v_lshrrev_b32_e32 v34, 4, v34                               ; 20444484
	v_mac_f32_e32 v45, v28, v42                                 ; 2c5a551c
	v_mul_f32_e32 v56, v23, v56                                 ; 0a707117
	v_mac_f32_e32 v52, v18, v53                                 ; 2c686b12
	v_and_b32_e32 v34, s5, v34                                  ; 26444405
	v_mad_f32 v8, -v44, v45, v8                                 ; d1c10008 24225b2c
	v_mac_f32_e32 v56, v22, v57                                 ; 2c707316
	v_mac_f32_e32 v52, v17, v54                                 ; 2c686d11
	v_cvt_f32_ubyte1_e32 v61, v34                               ; 7e7a2522
	v_cvt_f32_ubyte2_e32 v60, v34                               ; 7e782722
	v_cvt_f32_ubyte3_e32 v59, v34                               ; 7e762922
	v_cvt_f32_ubyte0_e32 v34, v34                               ; 7e442322
	v_mac_f32_e32 v56, v21, v58                                 ; 2c707515
	v_mac_f32_e32 v52, v16, v35                                 ; 2c684710
	v_mul_f32_e32 v59, v27, v59                                 ; 0a76771b
	v_mac_f32_e32 v56, v20, v55                                 ; 2c706f14
	v_mac_f32_e32 v59, v26, v60                                 ; 2c76791a
	v_mac_f32_e32 v59, v25, v61                                 ; 2c767b19
	v_mac_f32_e32 v59, v24, v34                                 ; 2c764518
	v_mul_f32_e32 v59, v59, v47                                 ; 0a765f3b
	v_mac_f32_e32 v59, v56, v33                                 ; 2c764338
	v_mac_f32_e32 v59, v52, v43                                 ; 2c765734
	v_mac_f32_e32 v59, v49, v39                                 ; 2c764f31
	v_mac_f32_e32 v8, v37, v59                                  ; 2c107725
	s_cbranch_scc0 BB64                                         ; bf840065
BB56:
	s_add_u32 s0, s16, 3                                        ; 80008310
	s_mul_i32 s0, s0, s3                                        ; 92000300
	s_add_u32 s0, s19, s0                                       ; 80000013
	v_add_u32_e32 v10, s0, v0                                   ; 68140000
	v_lshlrev_b32_e32 v11, 4, v10                               ; 24161484
	v_lshl_add_u32 v10, v10, 7, v11                             ; d1fd000a 042d0f0a
	v_add3_u32 v32, v32, 4, v10                                 ; d1ff0020 04290920
	v_add_u32_e32 v33, 16, v10                                  ; 68421490
	v_add_u32_e32 v34, v33, v4                                  ; 68440921
	v_add_u32_e32 v33, v33, v36                                 ; 68424921
	buffer_load_dwordx3 v[35:37], v10, s[12:15], 0 offen        ; e0581000 8003230a
	buffer_load_ushort v32, v32, s[12:15], 0 offen              ; e0481000 80032020
	buffer_load_dword v34, v34, s[12:15], 0 offen               ; e0501000 80032222
	buffer_load_dword v33, v33, s[12:15], 0 offen               ; e0501000 80032121
	s_bfm_b32 s1, 16, 16                                        ; 91019090
	s_mov_b32 s5, 0xf0f0f0f                                     ; be8500ff 0f0f0f0f
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_bfe_u32 v36, v36, v5, 16                                  ; d1c80024 02420b24
	v_lshlrev_b32_e32 v37, v6, v37                              ; 244a4b06
	v_cvt_f32_f16_sdwa v42, v35 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e5416f9 00050623
	v_cvt_f32_f16_e32 v35, v35                                  ; 7e461723
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_lshl_or_b32 v32, v32, 12, v32                             ; d2000020 04811920
	v_and_or_b32 v37, s1, v37, v36                              ; d2010025 04924a01
	v_and_b32_e32 v38, 0xc0c0c0c0, v37                          ; 264c4aff c0c0c0c0
	v_and_b32_e32 v37, 0x3f3f3f3f, v37                          ; 264a4aff 3f3f3f3f
	v_lshrrev_b32_e32 v38, 2, v38                               ; 204c4c82
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v46, s5, v34                                  ; 265c4405
	v_cvt_f32_ubyte3_e32 v39, v37                               ; 7e4e2925
	v_cvt_f32_ubyte2_e32 v40, v37                               ; 7e502725
	v_cvt_f32_ubyte1_e32 v41, v37                               ; 7e522525
	v_cvt_f32_ubyte0_e32 v37, v37                               ; 7e4a2325
	v_and_or_b32 v32, s5, v32, v38                              ; d2010020 049a4005
	v_cvt_f32_ubyte3_e32 v47, v46                               ; 7e5e292e
	v_cvt_f32_ubyte2_e32 v48, v46                               ; 7e60272e
	v_cvt_f32_ubyte1_e32 v49, v46                               ; 7e62252e
	v_cvt_f32_ubyte0_e32 v46, v46                               ; 7e5c232e
	v_cvt_f32_ubyte2_e32 v44, v32                               ; 7e582720
	v_cvt_f32_ubyte1_e32 v45, v32                               ; 7e5a2520
	v_cvt_f32_ubyte3_e32 v43, v32                               ; 7e562920
	v_cvt_f32_ubyte0_e32 v32, v32                               ; 7e402320
	v_mul_f32_e32 v15, v15, v47                                 ; 0a1e5f0f
	v_lshrrev_b32_e32 v34, 4, v34                               ; 20444484
	v_mul_f32_e32 v31, v31, v43                                 ; 0a3e571f
	v_mac_f32_e32 v15, v14, v48                                 ; 2c1e610e
	v_and_b32_e32 v34, s5, v34                                  ; 26444405
	v_mac_f32_e32 v31, v30, v44                                 ; 2c3e591e
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v53, s5, v33                                  ; 266a4205
	v_mac_f32_e32 v15, v13, v49                                 ; 2c1e630d
	v_cvt_f32_ubyte1_e32 v52, v34                               ; 7e682522
	v_cvt_f32_ubyte2_e32 v51, v34                               ; 7e662722
	v_cvt_f32_ubyte3_e32 v50, v34                               ; 7e642922
	v_cvt_f32_ubyte0_e32 v34, v34                               ; 7e442322
	v_mac_f32_e32 v31, v29, v39                                 ; 2c3e4f1d
	v_cvt_f32_ubyte2_e32 v55, v53                               ; 7e6e2735
	v_cvt_f32_ubyte3_e32 v54, v53                               ; 7e6c2935
	v_cvt_f32_ubyte1_e32 v56, v53                               ; 7e702535
	v_mac_f32_e32 v15, v12, v46                                 ; 2c1e5d0c
	v_cvt_f32_ubyte0_e32 v53, v53                               ; 7e6a2335
	v_mul_f32_e32 v19, v19, v50                                 ; 0a266513
	v_lshrrev_b32_e32 v33, 4, v33                               ; 20424284
	v_mac_f32_e32 v31, v28, v40                                 ; 2c3e511c
	v_mul_f32_e32 v23, v23, v54                                 ; 0a2e6d17
	v_mac_f32_e32 v19, v18, v51                                 ; 2c266712
	v_and_b32_e32 v33, s5, v33                                  ; 26424205
	v_mad_f32 v9, -v42, v31, v9                                 ; d1c10009 24263f2a
	v_mac_f32_e32 v23, v22, v55                                 ; 2c2e6f16
	v_mac_f32_e32 v19, v17, v52                                 ; 2c266911
	v_cvt_f32_ubyte1_e32 v59, v33                               ; 7e762521
	v_cvt_f32_ubyte2_e32 v58, v33                               ; 7e742721
	v_cvt_f32_ubyte3_e32 v57, v33                               ; 7e722921
	v_cvt_f32_ubyte0_e32 v33, v33                               ; 7e422321
	v_mac_f32_e32 v23, v21, v56                                 ; 2c2e7115
	v_mac_f32_e32 v19, v16, v34                                 ; 2c264510
	v_mul_f32_e32 v27, v27, v57                                 ; 0a36731b
	v_mac_f32_e32 v23, v20, v53                                 ; 2c2e6b14
	v_mac_f32_e32 v27, v26, v58                                 ; 2c36751a
	v_mac_f32_e32 v27, v25, v59                                 ; 2c367719
	v_mac_f32_e32 v27, v24, v33                                 ; 2c364318
	v_mul_f32_e32 v27, v27, v45                                 ; 0a365b1b
	v_mac_f32_e32 v27, v23, v32                                 ; 2c364117
	v_mac_f32_e32 v27, v19, v41                                 ; 2c365313
	v_mac_f32_e32 v27, v15, v37                                 ; 2c364b0f
	v_mac_f32_e32 v9, v35, v27                                  ; 2c123723
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
	v_readlane_b32 s5, v63, 63                                  ; d2890005 00017f3f
	s_cbranch_scc0 BB73                                         ; bf840034
BB68:
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
	s_cbranch_scc0 BB71                                         ; bf840019
BB69:
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
BB71:
	v_mov_b32_e32 v8, s6                                        ; 7e100206
BB73:
	v_mov_b32_e32 v7, s5                                        ; 7e0e0205
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
	v_add_f32_e32 v7, s5, v7                                    ; 020e0e05
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
	v_add_f32_e32 v7, s5, v7                                    ; 020e0e05
	s_branch BB91                                               ; bf820001
BB90:
	s_mov_b32 s0, src_scc                                       ; be8000fd
BB91:
	s_add_u32 s5, s7, 4                                         ; 80058407
	buffer_store_dword v7, off, s[8:11], s5                     ; e0700000 05020780
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
	v_add_f32_e32 v8, s5, v8                                    ; 02101005
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
	v_add_f32_e32 v8, s5, v8                                    ; 02101005
	s_branch BB98                                               ; bf820001
BB97:
	s_mov_b32 s0, src_scc                                       ; be8000fd
BB98:
	s_add_u32 s5, s7, 8                                         ; 80058807
	buffer_store_dword v8, off, s[8:11], s5                     ; e0700000 05020880
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
	v_add_f32_e32 v9, s1, v9                                    ; 02121201
BB102:
	s_cmp_lg_i32 s0, 0                                          ; bf018000
	s_cbranch_scc0 BB105                                        ; bf840008
BB103:
	s_load_dwordx4 s[0:3], s[2:3], 0x40                         ; c00a0001 00000040
	s_add_u32 s4, s7, 12                                        ; 80048c07
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s4, s[0:3], s4                          ; c0200100 00000004
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v9, s4, v9                                    ; 02121204
BB105:
	s_add_u32 s7, s7, 12                                        ; 80078c07
	buffer_store_dword v9, off, s[8:11], s7                     ; e0700000 07020980
BB119:
	s_endpgm                                                    ; bf810000
