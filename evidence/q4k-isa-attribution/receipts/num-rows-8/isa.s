BB0:
	s_load_dword s0, s[14:15], 0x0                              ; c0020007 00000000
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_mul_i32 s0, s0, s18                                       ; 92001200
	s_add_u32 s16, s16, s0                                      ; 80100010
	s_lshl_b32 s16, s16, 3                                      ; 8e108310
	s_add_u32 s1, s16, 8                                        ; 80018810
	s_cmp_ge_u32 s4, s1                                         ; bf090104
	s_cbranch_scc0 BB66                                         ; bf840587
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
	v_lshl_add_u32 v1, v1, 1, v3                                ; d1fd0001 040d0301
	v_mov_b32_e32 v3, 0                                         ; 7e060280
	v_lshlrev_b32_e32 v1, 2, v1                                 ; 24020282
	v_lshl_add_u32 v4, v2, 5, v1                                ; d1fd0004 04050b02
	v_lshl_add_u32 v1, v2, 6, v1                                ; d1fd0001 04050d02
	s_branch BB5                                                ; bf82035e
	s_nop 0                                                     ; bf800000
	(then repeated 5 times)
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
	v_lshlrev_b32_e32 v30, 1, v2                                ; 243c0481
	v_add_u32_e32 v38, 64, v4                                   ; 684c08c0
	s_add_u32 s1, s18, s1                                       ; 80010112
	s_add_u32 s4, s16, 1                                        ; 80048110
	v_and_b32_e32 v32, -4, v30                                  ; 26403cc4
	v_add_u32_e32 v35, 8, v30                                   ; 68463c88
	v_add_u32_e32 v28, s1, v0                                   ; 68380001
	s_mul_i32 s4, s4, s3                                        ; 92040304
	v_lshlrev_b32_e32 v29, 4, v28                               ; 243a3884
	s_add_u32 s4, s18, s4                                       ; 80040412
	v_lshl_add_u32 v28, v28, 7, v29                             ; d1fd001c 04750f1c
	v_add_u32_e32 v39, s4, v0                                   ; 684e0004
	v_add_u32_e32 v31, 4, v28                                   ; 683e3884
	v_add_u32_e32 v36, 16, v28                                  ; 68483890
	v_lshlrev_b32_e32 v40, 4, v39                               ; 24504e84
	s_add_u32 s5, s16, 2                                        ; 80058210
	v_add_u32_e32 v34, v31, v30                                 ; 68443d1f
	v_add_u32_e32 v33, v32, v31                                 ; 68423f20
	v_add_u32_e32 v31, v31, v35                                 ; 683e471f
	v_add_u32_e32 v37, v36, v4                                  ; 684a0924
	v_add_u32_e32 v36, v36, v38                                 ; 68484d24
	v_lshl_add_u32 v39, v39, 7, v40                             ; d1fd0027 04a10f27
	s_mul_i32 s5, s5, s3                                        ; 92050305
	v_add_u32_e32 v41, 4, v39                                   ; 68524e84
	v_add_u32_e32 v44, 16, v39                                  ; 68584e90
	s_add_u32 s5, s18, s5                                       ; 80050512
	v_add_u32_e32 v42, v32, v41                                 ; 68545320
	v_add_u32_e32 v43, v41, v30                                 ; 68563d29
	v_add_u32_e32 v41, v41, v35                                 ; 68524729
	s_add_u32 s9, s16, 3                                        ; 80098310
	v_add_u32_e32 v45, v44, v4                                  ; 685a092c
	v_add_u32_e32 v44, v44, v38                                 ; 68584d2c
	v_add_u32_e32 v46, s5, v0                                   ; 685c0005
	s_mul_i32 s9, s9, s3                                        ; 92090309
	v_lshlrev_b32_e32 v47, 4, v46                               ; 245e5c84
	s_add_u32 s9, s18, s9                                       ; 80090912
	v_lshl_add_u32 v46, v46, 7, v47                             ; d1fd002e 04bd0f2e
	v_add_u32_e32 v53, s9, v0                                   ; 686a0009
	v_add_u32_e32 v48, 4, v46                                   ; 68605c84
	v_add_u32_e32 v51, 16, v46                                  ; 68665c90
	v_lshlrev_b32_e32 v54, 4, v53                               ; 246c6a84
	v_add_u32_e32 v50, v48, v30                                 ; 68643d30
	v_add_u32_e32 v49, v32, v48                                 ; 68626120
	v_add_u32_e32 v48, v48, v35                                 ; 68604730
	v_add_u32_e32 v52, v51, v4                                  ; 68680933
	v_add_u32_e32 v51, v51, v38                                 ; 68664d33
	v_lshl_add_u32 v53, v53, 7, v54                             ; d1fd0035 04d90f35
	buffer_load_dword v28, v28, s[24:27], 0 offen               ; e0501000 80061c1c
	buffer_load_dwordx2 v[54:55], v33, s[24:27], 0 offen        ; e0541000 80063621
	buffer_load_ushort v31, v31, s[24:27], 0 offen              ; e0481000 80061f1f
	buffer_load_dword v37, v37, s[24:27], 0 offen               ; e0501000 80062525
	buffer_load_dword v36, v36, s[24:27], 0 offen               ; e0501000 80062424
	buffer_load_dword v39, v39, s[24:27], 0 offen               ; e0501000 80062727
	buffer_load_dwordx2 v[56:57], v42, s[24:27], 0 offen        ; e0541000 8006382a
	buffer_load_ushort v41, v41, s[24:27], 0 offen              ; e0481000 80062929
	buffer_load_dword v45, v45, s[24:27], 0 offen               ; e0501000 80062d2d
	buffer_load_dword v44, v44, s[24:27], 0 offen               ; e0501000 80062c2c
	buffer_load_dword v46, v46, s[24:27], 0 offen               ; e0501000 80062e2e
	buffer_load_dwordx2 v[58:59], v49, s[24:27], 0 offen        ; e0541000 80063a31
	buffer_load_ushort v48, v48, s[24:27], 0 offen              ; e0481000 80063030
	buffer_load_dword v52, v52, s[24:27], 0 offen               ; e0501000 80063434
	buffer_load_dword v51, v51, s[24:27], 0 offen               ; e0501000 80063333
	buffer_load_dword v60, v53, s[24:27], 0 offen               ; e0501000 80063c35
	s_mov_b32 s10, 0xf0f0f0f                                    ; be8a00ff 0f0f0f0f
	s_mov_b32 s11, 0xc0c0c0c0                                   ; be8b00ff c0c0c0c0
	s_mov_b32 s12, 0x3f3f3f3f                                   ; be8c00ff 3f3f3f3f
	s_waitcnt vmcnt(19)                                         ; bf8c7f73
	v_add_f32_e32 v61, v16, v17                                 ; 027a2310
	s_waitcnt vmcnt(18)                                         ; bf8c7f72
	v_add_f32_e32 v62, v20, v21                                 ; 027c2b14
	s_waitcnt vmcnt(17)                                         ; bf8c7f71
	v_add_f32_e32 v29, v24, v25                                 ; 023a3318
	v_add_f32_e32 v61, v61, v18                                 ; 027a253d
	s_waitcnt vmcnt(16)                                         ; bf8c7f70
	v_add_f32_e32 v33, v12, v13                                 ; 02421b0c
	v_add_f32_e32 v62, v62, v22                                 ; 027c2d3e
	v_add_f32_e32 v29, v29, v26                                 ; 023a351d
	v_add_f32_e32 v61, v61, v19                                 ; 027a273d
	v_add_f32_e32 v33, v33, v14                                 ; 02421d21
	v_add_f32_e32 v62, v62, v23                                 ; 027c2f3e
	v_add_f32_e32 v29, v29, v27                                 ; 023a371d
	v_add_f32_e32 v33, v33, v15                                 ; 02421f21
	s_waitcnt vmcnt(14)                                         ; bf8c3f7e
	v_alignbyte_b32 v54, v55, v54, v34                          ; d1cf0036 048a6d37
	v_alignbyte_b32 v55, v55, v55, v34                          ; d1cf0037 048a6f37
	s_waitcnt vmcnt(13)                                         ; bf8c3f7d
	v_lshl_or_b32 v31, v31, 12, v31                             ; d200001f 047d191f
	s_waitcnt vmcnt(12)                                         ; bf8c3f7c
	v_and_b32_e32 v40, s10, v37                                 ; 26504a0a
	v_lshrrev_b32_e32 v37, 4, v37                               ; 204a4a84
	v_mov_b32_sdwa v54, v55 dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_0 ; 7e6c02f9 00041537
	v_cvt_f32_ubyte2_e32 v47, v40                               ; 7e5e2728
	v_cvt_f32_ubyte3_e32 v42, v40                               ; 7e542928
	v_cvt_f32_ubyte1_e32 v49, v40                               ; 7e622528
	v_cvt_f32_ubyte0_e32 v40, v40                               ; 7e502328
	v_and_b32_e32 v37, s10, v37                                 ; 264a4a0a
	v_and_b32_e32 v34, s11, v54                                 ; 26446c0b
	v_and_b32_e32 v54, s12, v54                                 ; 266c6c0c
	v_mul_f32_e32 v42, v19, v42                                 ; 0a545513
	v_cvt_f32_ubyte3_e32 v55, v37                               ; 7e6e2925
	v_lshrrev_b32_e32 v34, 2, v34                               ; 20444482
	v_mac_f32_e32 v42, v18, v47                                 ; 2c545f12
	s_waitcnt vmcnt(11)                                         ; bf8c3f7b
	v_and_b32_e32 v47, s10, v36                                 ; 265e480a
	v_mul_f32_e32 v55, v23, v55                                 ; 0a6e6f17
	v_and_or_b32 v31, s10, v31, v34                             ; d201001f 048a3e0a
	v_cvt_f32_ubyte2_e32 v34, v37                               ; 7e442725
	v_mac_f32_e32 v42, v17, v49                                 ; 2c546311
	v_cvt_f32_ubyte3_e32 v49, v47                               ; 7e62292f
	v_lshrrev_b32_e32 v36, 4, v36                               ; 20484884
	v_mac_f32_e32 v55, v22, v34                                 ; 2c6e4516
	v_cvt_f32_ubyte2_e32 v34, v47                               ; 7e44272f
	v_mac_f32_e32 v42, v16, v40                                 ; 2c545110
	v_cvt_f32_ubyte1_e32 v40, v37                               ; 7e502525
	v_cvt_f32_ubyte0_e32 v37, v37                               ; 7e4a2325
	v_mul_f32_e32 v49, v27, v49                                 ; 0a62631b
	v_and_b32_e32 v36, s10, v36                                 ; 2648480a
	v_mac_f32_e32 v55, v21, v40                                 ; 2c6e5115
	v_mac_f32_e32 v49, v26, v34                                 ; 2c62451a
	v_cvt_f32_ubyte1_e32 v34, v36                               ; 7e442524
	v_cvt_f32_ubyte3_e32 v40, v36                               ; 7e502924
	v_mac_f32_e32 v55, v20, v37                                 ; 2c6e4b14
	v_cvt_f32_ubyte1_e32 v37, v47                               ; 7e4a252f
	v_cvt_f32_ubyte0_e32 v47, v47                               ; 7e5e232f
	v_mul_f32_e32 v40, v15, v40                                 ; 0a50510f
	v_mac_f32_e32 v49, v25, v37                                 ; 2c624b19
	v_cvt_f32_ubyte2_e32 v37, v31                               ; 7e4a271f
	v_mac_f32_e32 v49, v24, v47                                 ; 2c625f18
	v_cvt_f32_ubyte2_e32 v47, v36                               ; 7e5e2724
	v_cvt_f32_ubyte0_e32 v36, v36                               ; 7e482324
	v_mac_f32_e32 v40, v14, v47                                 ; 2c505f0e
	v_cvt_f32_ubyte3_e32 v47, v54                               ; 7e5e2936
	v_mac_f32_e32 v40, v13, v34                                 ; 2c50450d
	v_cvt_f32_ubyte2_e32 v34, v54                               ; 7e442736
	v_mac_f32_e32 v40, v12, v36                                 ; 2c50490c
	v_cvt_f32_ubyte3_e32 v36, v31                               ; 7e48291f
	v_mul_f32_e32 v36, v33, v36                                 ; 0a484921
	v_mac_f32_e32 v36, v29, v37                                 ; 2c484b1d
	v_cvt_f32_ubyte1_e32 v37, v31                               ; 7e4a251f
	v_cvt_f32_ubyte0_e32 v31, v31                               ; 7e3e231f
	v_mac_f32_e32 v36, v62, v47                                 ; 2c485f3e
	v_cvt_f32_ubyte1_e32 v47, v54                               ; 7e5e2536
	v_cvt_f32_ubyte0_e32 v54, v54                               ; 7e6c2336
	v_mul_f32_e32 v40, v40, v37                                 ; 0a504b28
	v_cvt_f32_f16_sdwa v37, v28 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e4a16f9 0005061c
	v_mac_f32_e32 v36, v61, v34                                 ; 2c48453d
	s_add_u32 s13, s16, 4                                       ; 800d8410
	v_mac_f32_e32 v40, v49, v31                                 ; 2c503f31
	v_add_u32_e32 v49, 4, v53                                   ; 68626a84
	v_add_u32_e32 v53, 16, v53                                  ; 686a6a90
	v_mad_f32 v3, -v37, v36, v3                                 ; d1c10003 240e4925
	s_mul_i32 s13, s13, s3                                      ; 920d030d
	v_cvt_f32_f16_e32 v28, v28                                  ; 7e38171c
	v_mac_f32_e32 v40, v55, v47                                 ; 2c505f37
	v_add_u32_e32 v55, v32, v49                                 ; 686e6320
	v_add_u32_e32 v31, v49, v30                                 ; 683e3d31
	v_add_u32_e32 v49, v49, v35                                 ; 68624731
	s_waitcnt vmcnt(9)                                          ; bf8c3f79
	v_alignbyte_b32 v56, v57, v56, v43                          ; d1cf0038 04ae7139
	v_alignbyte_b32 v57, v57, v57, v43                          ; d1cf0039 04ae7339
	v_add_u32_e32 v34, v53, v4                                  ; 68440935
	v_add_u32_e32 v53, v53, v38                                 ; 686a4d35
	s_add_u32 s13, s18, s13                                     ; 800d0d12
	v_mac_f32_e32 v40, v42, v54                                 ; 2c506d2a
	s_waitcnt vmcnt(8)                                          ; bf8c3f78
	v_lshl_or_b32 v41, v41, 12, v41                             ; d2000029 04a51929
	v_mov_b32_sdwa v56, v57 dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_0 ; 7e7002f9 00041539
	s_waitcnt vmcnt(7)                                          ; bf8c3f77
	v_and_b32_e32 v57, s10, v45                                 ; 26725a0a
	v_add_u32_e32 v42, s13, v0                                  ; 6854000d
	v_mac_f32_e32 v3, v28, v40                                  ; 2c06511c
	v_and_b32_e32 v54, s11, v56                                 ; 266c700b
	v_and_b32_e32 v56, s12, v56                                 ; 2670700c
	v_cvt_f32_ubyte3_e32 v28, v57                               ; 7e382939
	v_lshrrev_b32_e32 v45, 4, v45                               ; 205a5a84
	v_cvt_f32_ubyte2_e32 v36, v57                               ; 7e482739
	v_cvt_f32_ubyte1_e32 v37, v57                               ; 7e4a2539
	v_cvt_f32_ubyte0_e32 v57, v57                               ; 7e722339
	v_lshlrev_b32_e32 v47, 4, v42                               ; 245e5484
	v_lshrrev_b32_e32 v54, 2, v54                               ; 206c6c82
	v_mul_f32_e32 v28, v19, v28                                 ; 0a383913
	v_and_b32_e32 v45, s10, v45                                 ; 265a5a0a
	v_lshl_add_u32 v42, v42, 7, v47                             ; d1fd002a 04bd0f2a
	v_and_or_b32 v41, s10, v41, v54                             ; d2010029 04da520a
	s_waitcnt vmcnt(6)                                          ; bf8c3f76
	v_and_b32_e32 v54, s10, v44                                 ; 266c580a
	v_mac_f32_e32 v28, v18, v36                                 ; 2c384912
	v_cvt_f32_ubyte2_e32 v43, v45                               ; 7e56272d
	v_cvt_f32_ubyte3_e32 v40, v45                               ; 7e50292d
	v_cvt_f32_ubyte1_e32 v47, v45                               ; 7e5e252d
	v_cvt_f32_ubyte0_e32 v45, v45                               ; 7e5a232d
	v_cvt_f32_ubyte2_e32 v36, v54                               ; 7e482736
	v_mac_f32_e32 v28, v17, v37                                 ; 2c384b11
	v_cvt_f32_ubyte1_e32 v37, v54                               ; 7e4a2536
	v_mul_f32_e32 v40, v23, v40                                 ; 0a505117
	v_lshrrev_b32_e32 v44, 4, v44                               ; 20585884
	v_mac_f32_e32 v28, v16, v57                                 ; 2c387310
	v_cvt_f32_ubyte3_e32 v57, v54                               ; 7e722936
	v_cvt_f32_ubyte0_e32 v54, v54                               ; 7e6c2336
	v_mac_f32_e32 v40, v22, v43                                 ; 2c505716
	v_and_b32_e32 v44, s10, v44                                 ; 2658580a
	v_mul_f32_e32 v57, v27, v57                                 ; 0a72731b
	v_mac_f32_e32 v40, v21, v47                                 ; 2c505f15
	v_cvt_f32_ubyte1_e32 v47, v44                               ; 7e5e252c
	v_cvt_f32_ubyte3_e32 v43, v44                               ; 7e56292c
	v_mac_f32_e32 v57, v26, v36                                 ; 2c72491a
	v_cvt_f32_ubyte2_e32 v36, v41                               ; 7e482729
	v_mac_f32_e32 v40, v20, v45                                 ; 2c505b14
	v_cvt_f32_ubyte2_e32 v45, v44                               ; 7e5a272c
	v_cvt_f32_ubyte0_e32 v44, v44                               ; 7e58232c
	v_mul_f32_e32 v43, v15, v43                                 ; 0a56570f
	v_mac_f32_e32 v57, v25, v37                                 ; 2c724b19
	v_cvt_f32_ubyte3_e32 v37, v56                               ; 7e4a2938
	v_mac_f32_e32 v43, v14, v45                                 ; 2c565b0e
	v_cvt_f32_ubyte1_e32 v45, v41                               ; 7e5a2529
	v_mac_f32_e32 v57, v24, v54                                 ; 2c726d18
	v_cvt_f32_ubyte3_e32 v54, v41                               ; 7e6c2929
	v_cvt_f32_ubyte0_e32 v41, v41                               ; 7e522329
	v_mac_f32_e32 v43, v13, v47                                 ; 2c565f0d
	v_cvt_f32_ubyte1_e32 v47, v56                               ; 7e5e2538
	v_mul_f32_e32 v54, v33, v54                                 ; 0a6c6d21
	v_mac_f32_e32 v43, v12, v44                                 ; 2c56590c
	v_cvt_f32_ubyte2_e32 v44, v56                               ; 7e582738
	v_cvt_f32_ubyte0_e32 v56, v56                               ; 7e702338
	v_mac_f32_e32 v54, v29, v36                                 ; 2c6c491d
	v_mul_f32_e32 v43, v43, v45                                 ; 0a565b2b
	v_mac_f32_e32 v54, v62, v37                                 ; 2c6c4b3e
	v_mac_f32_e32 v43, v57, v41                                 ; 2c565339
	v_add_u32_e32 v57, 4, v42                                   ; 68725484
	v_mac_f32_e32 v54, v61, v44                                 ; 2c6c593d
	v_mac_f32_e32 v43, v40, v47                                 ; 2c565f28
	v_add_u32_e32 v40, 16, v42                                  ; 68505490
	v_add_u32_e32 v36, v32, v57                                 ; 68487320
	v_add_u32_e32 v37, v57, v30                                 ; 684a3d39
	v_add_u32_e32 v57, v57, v35                                 ; 68724739
	v_mac_f32_e32 v43, v28, v56                                 ; 2c56711c
	v_add_u32_e32 v41, v40, v4                                  ; 68520928
	v_add_u32_e32 v40, v40, v38                                 ; 68504d28
	buffer_load_dwordx2 v[44:45], v55, s[24:27], 0 offen        ; e0541000 80062c37
	buffer_load_ushort v49, v49, s[24:27], 0 offen              ; e0481000 80063131
	buffer_load_dword v34, v34, s[24:27], 0 offen               ; e0501000 80062222
	buffer_load_dword v53, v53, s[24:27], 0 offen               ; e0501000 80063535
	buffer_load_dword v42, v42, s[24:27], 0 offen               ; e0501000 80062a2a
	buffer_load_dwordx2 v[55:56], v36, s[24:27], 0 offen        ; e0541000 80063724
	buffer_load_ushort v57, v57, s[24:27], 0 offen              ; e0481000 80063939
	buffer_load_dword v41, v41, s[24:27], 0 offen               ; e0501000 80062929
	buffer_load_dword v40, v40, s[24:27], 0 offen               ; e0501000 80062828
	v_cvt_f32_f16_sdwa v28, v39 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e3816f9 00050627
	v_cvt_f32_f16_e32 v39, v39                                  ; 7e4e1727
	s_waitcnt vmcnt(14)                                         ; bf8c3f7e
	v_cvt_f32_f16_sdwa v36, v46 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e4816f9 0005062e
	v_cvt_f32_f16_e32 v46, v46                                  ; 7e5c172e
	s_waitcnt vmcnt(13)                                         ; bf8c3f7d
	v_alignbyte_b32 v58, v59, v58, v50                          ; d1cf003a 04ca753b
	v_alignbyte_b32 v59, v59, v59, v50                          ; d1cf003b 04ca773b
	s_waitcnt vmcnt(12)                                         ; bf8c3f7c
	v_lshl_or_b32 v48, v48, 12, v48                             ; d2000030 04c11930
	v_mad_f32 v5, -v28, v54, v5                                 ; d1c10005 24166d1c
	v_mov_b32_sdwa v58, v59 dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_0 ; 7e7402f9 0004153b
	v_mac_f32_e32 v5, v39, v43                                  ; 2c0a5727
	s_waitcnt vmcnt(11)                                         ; bf8c3f7b
	v_and_b32_e32 v43, s10, v52                                 ; 2656680a
	v_lshrrev_b32_e32 v52, 4, v52                               ; 20686884
	v_and_b32_e32 v39, s11, v58                                 ; 264e740b
	v_cvt_f32_ubyte2_e32 v50, v43                               ; 7e64272b
	v_cvt_f32_ubyte3_e32 v47, v43                               ; 7e5e292b
	v_cvt_f32_ubyte1_e32 v54, v43                               ; 7e6c252b
	v_cvt_f32_ubyte0_e32 v43, v43                               ; 7e56232b
	v_and_b32_e32 v52, s10, v52                                 ; 2668680a
	v_lshrrev_b32_e32 v39, 2, v39                               ; 204e4e82
	v_mul_f32_e32 v47, v19, v47                                 ; 0a5e5f13
	v_cvt_f32_ubyte3_e32 v59, v52                               ; 7e762934
	v_cvt_f32_ubyte2_e32 v28, v52                               ; 7e382734
	v_and_or_b32 v48, s10, v48, v39                             ; d2010030 049e600a
	v_cvt_f32_ubyte1_e32 v39, v52                               ; 7e4e2534
	v_cvt_f32_ubyte0_e32 v52, v52                               ; 7e682334
	v_mac_f32_e32 v47, v18, v50                                 ; 2c5e6512
	v_mul_f32_e32 v59, v23, v59                                 ; 0a767717
	v_mac_f32_e32 v47, v17, v54                                 ; 2c5e6d11
	v_mac_f32_e32 v59, v22, v28                                 ; 2c763916
	v_mac_f32_e32 v47, v16, v43                                 ; 2c5e5710
	s_waitcnt vmcnt(10)                                         ; bf8c3f7a
	v_and_b32_e32 v43, s10, v51                                 ; 2656660a
	v_lshrrev_b32_e32 v51, 4, v51                               ; 20666684
	v_mac_f32_e32 v59, v21, v39                                 ; 2c764f15
	v_cvt_f32_ubyte3_e32 v50, v43                               ; 7e64292b
	v_cvt_f32_ubyte1_e32 v54, v43                               ; 7e6c252b
	v_and_b32_e32 v51, s10, v51                                 ; 2666660a
	v_mac_f32_e32 v59, v20, v52                                 ; 2c766914
	v_cvt_f32_ubyte2_e32 v52, v43                               ; 7e68272b
	v_cvt_f32_ubyte0_e32 v43, v43                               ; 7e56232b
	v_mul_f32_e32 v50, v27, v50                                 ; 0a64651b
	v_cvt_f32_ubyte3_e32 v28, v51                               ; 7e382933
	v_cvt_f32_ubyte2_e32 v39, v51                               ; 7e4e2733
	v_and_b32_e32 v58, s12, v58                                 ; 2674740c
	v_mac_f32_e32 v50, v26, v52                                 ; 2c64691a
	v_cvt_f32_ubyte2_e32 v52, v48                               ; 7e682730
	v_mul_f32_e32 v28, v15, v28                                 ; 0a38390f
	v_mac_f32_e32 v50, v25, v54                                 ; 2c646d19
	v_cvt_f32_ubyte3_e32 v54, v58                               ; 7e6c293a
	v_mac_f32_e32 v28, v14, v39                                 ; 2c384f0e
	v_cvt_f32_ubyte2_e32 v39, v58                               ; 7e4e273a
	s_add_u32 s14, s16, 5                                       ; 800e8510
	v_mac_f32_e32 v50, v24, v43                                 ; 2c645718
	v_cvt_f32_ubyte1_e32 v43, v51                               ; 7e562533
	v_cvt_f32_ubyte0_e32 v51, v51                               ; 7e662333
	s_mul_i32 s14, s14, s3                                      ; 920e030e
	v_mac_f32_e32 v28, v13, v43                                 ; 2c38570d
	v_cvt_f32_ubyte1_e32 v43, v48                               ; 7e562530
	s_add_u32 s14, s18, s14                                     ; 800e0e12
	v_mac_f32_e32 v28, v12, v51                                 ; 2c38670c
	v_cvt_f32_ubyte3_e32 v51, v48                               ; 7e662930
	v_cvt_f32_ubyte0_e32 v48, v48                               ; 7e602330
	v_mul_f32_e32 v28, v28, v43                                 ; 0a38571c
	v_mul_f32_e32 v51, v33, v51                                 ; 0a666721
	v_mac_f32_e32 v28, v50, v48                                 ; 2c386132
	v_mac_f32_e32 v51, v29, v52                                 ; 2c66691d
	v_add_u32_e32 v52, s14, v0                                  ; 6868000e
	v_mac_f32_e32 v51, v62, v54                                 ; 2c666d3e
	v_lshlrev_b32_e32 v54, 4, v52                               ; 246c6884
	v_mac_f32_e32 v51, v61, v39                                 ; 2c664f3d
	v_cvt_f32_ubyte1_e32 v39, v58                               ; 7e4e253a
	v_cvt_f32_ubyte0_e32 v58, v58                               ; 7e74233a
	v_lshl_add_u32 v52, v52, 7, v54                             ; d1fd0034 04d90f34
	v_mac_f32_e32 v28, v59, v39                                 ; 2c384f3b
	v_add_u32_e32 v43, 4, v52                                   ; 68566884
	v_mac_f32_e32 v28, v47, v58                                 ; 2c38752f
	v_add_u32_e32 v48, v32, v43                                 ; 68605720
	v_add_u32_e32 v50, v43, v30                                 ; 68643d2b
	v_add_u32_e32 v43, v43, v35                                 ; 6856472b
	buffer_load_dword v54, v52, s[24:27], 0 offen               ; e0501000 80063634
	buffer_load_dwordx2 v[58:59], v48, s[24:27], 0 offen        ; e0541000 80063a30
	buffer_load_ushort v43, v43, s[24:27], 0 offen              ; e0481000 80062b2b
	v_add_u32_e32 v52, 16, v52                                  ; 68686890
	v_add_u32_e32 v39, v52, v4                                  ; 684e0934
	v_add_u32_e32 v52, v52, v38                                 ; 68684d34
	buffer_load_dword v39, v39, s[24:27], 0 offen               ; e0501000 80062727
	buffer_load_dword v52, v52, s[24:27], 0 offen               ; e0501000 80063434
	v_mad_f32 v6, -v36, v51, v6                                 ; d1c10006 241a6724
	s_add_u32 s15, s16, 6                                       ; 800f8610
	s_waitcnt vmcnt(13)                                         ; bf8c3f7d
	v_alignbyte_b32 v44, v45, v44, v31                          ; d1cf002c 047e592d
	v_alignbyte_b32 v45, v45, v45, v31                          ; d1cf002d 047e5b2d
	s_waitcnt vmcnt(12)                                         ; bf8c3f7c
	v_lshl_or_b32 v49, v49, 12, v49                             ; d2000031 04c51931
	s_waitcnt vmcnt(11)                                         ; bf8c3f7b
	v_and_b32_e32 v48, s10, v34                                 ; 2660440a
	v_mac_f32_e32 v6, v46, v28                                  ; 2c0c392e
	v_cvt_f32_f16_sdwa v46, v60 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e5c16f9 0005063c
	v_cvt_f32_f16_e32 v60, v60                                  ; 7e78173c
	s_mul_i32 s15, s15, s3                                      ; 920f030f
	v_mov_b32_sdwa v44, v45 dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_0 ; 7e5802f9 0004152d
	v_cvt_f32_ubyte3_e32 v51, v48                               ; 7e662930
	v_cvt_f32_ubyte2_e32 v28, v48                               ; 7e382730
	v_cvt_f32_ubyte1_e32 v31, v48                               ; 7e3e2530
	v_cvt_f32_ubyte0_e32 v48, v48                               ; 7e602330
	v_lshrrev_b32_e32 v34, 4, v34                               ; 20444484
	v_and_b32_e32 v47, s11, v44                                 ; 265e580b
	v_mul_f32_e32 v51, v19, v51                                 ; 0a666713
	v_and_b32_e32 v34, s10, v34                                 ; 2644440a
	v_lshrrev_b32_e32 v47, 2, v47                               ; 205e5e82
	v_mac_f32_e32 v51, v18, v28                                 ; 2c663912
	v_cvt_f32_ubyte3_e32 v36, v34                               ; 7e482922
	v_cvt_f32_ubyte2_e32 v45, v34                               ; 7e5a2722
	v_and_or_b32 v49, s10, v49, v47                             ; d2010031 04be620a
	v_cvt_f32_ubyte1_e32 v47, v34                               ; 7e5e2522
	v_cvt_f32_ubyte0_e32 v34, v34                               ; 7e442322
	v_mac_f32_e32 v51, v17, v31                                 ; 2c663f11
	v_mul_f32_e32 v36, v23, v36                                 ; 0a484917
	v_mac_f32_e32 v51, v16, v48                                 ; 2c666110
	s_waitcnt vmcnt(10)                                         ; bf8c3f7a
	v_and_b32_e32 v48, s10, v53                                 ; 26606a0a
	v_lshrrev_b32_e32 v53, 4, v53                               ; 206a6a84
	v_mac_f32_e32 v36, v22, v45                                 ; 2c485b16
	v_cvt_f32_ubyte3_e32 v28, v48                               ; 7e382930
	v_cvt_f32_ubyte2_e32 v31, v48                               ; 7e3e2730
	v_and_b32_e32 v53, s10, v53                                 ; 266a6a0a
	v_mac_f32_e32 v36, v21, v47                                 ; 2c485f15
	v_mul_f32_e32 v28, v27, v28                                 ; 0a38391b
	v_cvt_f32_ubyte3_e32 v45, v53                               ; 7e5a2935
	v_cvt_f32_ubyte2_e32 v47, v53                               ; 7e5e2735
	v_mac_f32_e32 v36, v20, v34                                 ; 2c484514
	v_cvt_f32_ubyte1_e32 v34, v48                               ; 7e442530
	v_cvt_f32_ubyte0_e32 v48, v48                               ; 7e602330
	v_mac_f32_e32 v28, v26, v31                                 ; 2c383f1a
	v_cvt_f32_ubyte2_e32 v31, v49                               ; 7e3e2731
	v_mul_f32_e32 v45, v15, v45                                 ; 0a5a5b0f
	v_and_b32_e32 v44, s12, v44                                 ; 2658580c
	v_mac_f32_e32 v28, v25, v34                                 ; 2c384519
	v_mac_f32_e32 v45, v14, v47                                 ; 2c5a5f0e
	v_cvt_f32_ubyte2_e32 v47, v44                               ; 7e5e272c
	v_cvt_f32_ubyte3_e32 v34, v44                               ; 7e44292c
	s_add_u32 s15, s18, s15                                     ; 800f0f12
	v_mac_f32_e32 v28, v24, v48                                 ; 2c386118
	v_cvt_f32_ubyte1_e32 v48, v53                               ; 7e602535
	v_cvt_f32_ubyte0_e32 v53, v53                               ; 7e6a2335
	v_mac_f32_e32 v45, v13, v48                                 ; 2c5a610d
	v_cvt_f32_ubyte1_e32 v48, v49                               ; 7e602531
	v_mac_f32_e32 v45, v12, v53                                 ; 2c5a6b0c
	v_cvt_f32_ubyte3_e32 v53, v49                               ; 7e6a2931
	v_cvt_f32_ubyte0_e32 v49, v49                               ; 7e622331
	v_mul_f32_e32 v45, v45, v48                                 ; 0a5a612d
	v_mul_f32_e32 v53, v33, v53                                 ; 0a6a6b21
	v_mac_f32_e32 v45, v28, v49                                 ; 2c5a631c
	v_mac_f32_e32 v53, v29, v31                                 ; 2c6a3f1d
	v_add_u32_e32 v31, s15, v0                                  ; 683e000f
	v_mac_f32_e32 v53, v62, v34                                 ; 2c6a453e
	v_lshlrev_b32_e32 v34, 4, v31                               ; 24443e84
	v_mac_f32_e32 v53, v61, v47                                 ; 2c6a5f3d
	v_cvt_f32_ubyte1_e32 v47, v44                               ; 7e5e252c
	v_cvt_f32_ubyte0_e32 v44, v44                               ; 7e58232c
	v_lshl_add_u32 v31, v31, 7, v34                             ; d1fd001f 04890f1f
	v_mac_f32_e32 v45, v36, v47                                 ; 2c5a5f24
	v_mov_b32_e32 v36, v33                                      ; 7e480321
	v_add_u32_e32 v48, 4, v31                                   ; 68603e84
	v_mac_f32_e32 v45, v51, v44                                 ; 2c5a5933
	v_add_u32_e32 v49, v32, v48                                 ; 68626120
	v_add_u32_e32 v51, v48, v30                                 ; 68663d30
	v_add_u32_e32 v48, v48, v35                                 ; 68604730
	buffer_load_dword v28, v31, s[24:27], 0 offen               ; e0501000 80061c1f
	buffer_load_dwordx2 v[33:34], v49, s[24:27], 0 offen        ; e0541000 80062131
	buffer_load_ushort v48, v48, s[24:27], 0 offen              ; e0481000 80063030
	v_add_u32_e32 v31, 16, v31                                  ; 683e3e90
	v_add_u32_e32 v44, v31, v4                                  ; 6858091f
	v_add_u32_e32 v31, v31, v38                                 ; 683e4d1f
	buffer_load_dword v44, v44, s[24:27], 0 offen               ; e0501000 80062c2c
	buffer_load_dword v31, v31, s[24:27], 0 offen               ; e0501000 80061f1f
	v_mad_f32 v7, -v46, v53, v7                                 ; d1c10007 241e6b2e
	s_add_u32 s19, s16, 7                                       ; 80138710
	s_waitcnt vmcnt(13)                                         ; bf8c3f7d
	v_alignbyte_b32 v55, v56, v55, v37                          ; d1cf0037 04966f38
	v_alignbyte_b32 v56, v56, v56, v37                          ; d1cf0038 04967138
	s_waitcnt vmcnt(12)                                         ; bf8c3f7c
	v_lshl_or_b32 v57, v57, 12, v57                             ; d2000039 04e51939
	s_waitcnt vmcnt(11)                                         ; bf8c3f7b
	v_and_b32_e32 v47, s10, v41                                 ; 265e520a
	v_mac_f32_e32 v7, v60, v45                                  ; 2c0e5b3c
	v_cvt_f32_f16_sdwa v45, v42 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e5a16f9 0005062a
	v_cvt_f32_f16_e32 v42, v42                                  ; 7e54172a
	s_mul_i32 s19, s19, s3                                      ; 92130313
	v_mov_b32_sdwa v55, v56 dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_0 ; 7e6e02f9 00041538
	v_cvt_f32_ubyte3_e32 v49, v47                               ; 7e62292f
	v_cvt_f32_ubyte2_e32 v53, v47                               ; 7e6a272f
	v_lshrrev_b32_e32 v41, 4, v41                               ; 20525284
	v_cvt_f32_ubyte1_e32 v56, v47                               ; 7e70252f
	v_cvt_f32_ubyte0_e32 v47, v47                               ; 7e5e232f
	v_and_b32_e32 v46, s11, v55                                 ; 265c6e0b
	v_mul_f32_e32 v49, v19, v49                                 ; 0a626313
	v_and_b32_e32 v41, s10, v41                                 ; 2652520a
	v_lshrrev_b32_e32 v46, 2, v46                               ; 205c5c82
	v_mac_f32_e32 v49, v18, v53                                 ; 2c626b12
	v_cvt_f32_ubyte3_e32 v60, v41                               ; 7e782929
	v_cvt_f32_ubyte2_e32 v37, v41                               ; 7e4a2729
	v_and_or_b32 v57, s10, v57, v46                             ; d2010039 04ba720a
	v_cvt_f32_ubyte1_e32 v46, v41                               ; 7e5c2529
	v_cvt_f32_ubyte0_e32 v41, v41                               ; 7e522329
	v_mac_f32_e32 v49, v17, v56                                 ; 2c627111
	v_mul_f32_e32 v60, v23, v60                                 ; 0a787917
	v_mac_f32_e32 v49, v16, v47                                 ; 2c625f10
	s_waitcnt vmcnt(10)                                         ; bf8c3f7a
	v_and_b32_e32 v47, s10, v40                                 ; 265e500a
	v_lshrrev_b32_e32 v40, 4, v40                               ; 20505084
	v_mac_f32_e32 v60, v22, v37                                 ; 2c784b16
	v_cvt_f32_ubyte1_e32 v37, v47                               ; 7e4a252f
	v_cvt_f32_ubyte2_e32 v56, v47                               ; 7e70272f
	v_cvt_f32_ubyte3_e32 v53, v47                               ; 7e6a292f
	v_cvt_f32_ubyte0_e32 v47, v47                               ; 7e5e232f
	v_and_b32_e32 v40, s10, v40                                 ; 2650500a
	v_mac_f32_e32 v60, v21, v46                                 ; 2c785d15
	v_mul_f32_e32 v53, v27, v53                                 ; 0a6a6b1b
	v_cvt_f32_ubyte2_e32 v46, v40                               ; 7e5c2728
	v_mac_f32_e32 v60, v20, v41                                 ; 2c785314
	v_cvt_f32_ubyte3_e32 v41, v40                               ; 7e522928
	v_and_b32_e32 v55, s12, v55                                 ; 266e6e0c
	v_mac_f32_e32 v53, v26, v56                                 ; 2c6a711a
	v_cvt_f32_ubyte3_e32 v56, v57                               ; 7e702939
	v_mul_f32_e32 v41, v15, v41                                 ; 0a52530f
	v_mac_f32_e32 v53, v25, v37                                 ; 2c6a4b19
	v_cvt_f32_ubyte2_e32 v37, v57                               ; 7e4a2739
	v_mul_f32_e32 v56, v36, v56                                 ; 0a707124
	s_add_u32 s19, s18, s19                                     ; 80131312
	v_mac_f32_e32 v41, v14, v46                                 ; 2c525d0e
	v_cvt_f32_ubyte2_e32 v46, v55                               ; 7e5c2737
	v_mac_f32_e32 v53, v24, v47                                 ; 2c6a5f18
	v_cvt_f32_ubyte1_e32 v47, v40                               ; 7e5e2528
	v_cvt_f32_ubyte0_e32 v40, v40                               ; 7e502328
	v_mac_f32_e32 v56, v29, v37                                 ; 2c704b1d
	v_add_u32_e32 v37, s19, v0                                  ; 684a0013
	v_mac_f32_e32 v41, v13, v47                                 ; 2c525f0d
	v_cvt_f32_ubyte1_e32 v47, v57                               ; 7e5e2539
	v_cvt_f32_ubyte0_e32 v57, v57                               ; 7e722339
	v_mac_f32_e32 v41, v12, v40                                 ; 2c52510c
	v_cvt_f32_ubyte3_e32 v40, v55                               ; 7e502937
	v_mul_f32_e32 v41, v41, v47                                 ; 0a525f29
	v_mac_f32_e32 v56, v62, v40                                 ; 2c70513e
	v_lshlrev_b32_e32 v40, 4, v37                               ; 24504a84
	v_mac_f32_e32 v41, v53, v57                                 ; 2c527335
	v_mac_f32_e32 v56, v61, v46                                 ; 2c705d3d
	v_cvt_f32_ubyte1_e32 v46, v55                               ; 7e5c2537
	v_lshl_add_u32 v37, v37, 7, v40                             ; d1fd0025 04a10f25
	v_mac_f32_e32 v41, v60, v46                                 ; 2c525d3c
	v_add_u32_e32 v53, 16, v37                                  ; 686a4a90
	v_add_u32_e32 v47, 4, v37                                   ; 685e4a84
	v_add_u32_e32 v57, v53, v4                                  ; 68720935
	v_add_u32_e32 v53, v53, v38                                 ; 686a4d35
	v_add_u32_e32 v32, v32, v47                                 ; 68405f20
	v_add_u32_e32 v30, v47, v30                                 ; 683c3d2f
	v_add_u32_e32 v47, v47, v35                                 ; 685e472f
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_mov_b32_e32 v60, v31                                      ; 7e78031f
	buffer_load_dword v37, v37, s[24:27], 0 offen               ; e0501000 80062525
	buffer_load_dwordx2 v[31:32], v32, s[24:27], 0 offen        ; e0541000 80061f20
	buffer_load_ushort v47, v47, s[24:27], 0 offen              ; e0481000 80062f2f
	buffer_load_dword v57, v57, s[24:27], 0 offen               ; e0501000 80063939
	buffer_load_dword v53, v53, s[24:27], 0 offen               ; e0501000 80063535
	v_cvt_f32_ubyte0_e32 v55, v55                               ; 7e6e2337
	v_mad_f32 v8, -v45, v56, v8                                 ; d1c10008 2422712d
	v_cvt_f32_f16_sdwa v35, v54 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e4616f9 00050636
	v_cvt_f32_f16_e32 v54, v54                                  ; 7e6c1736
	v_add_u32_e32 v0, 4, v0                                     ; 68000084
	v_alignbyte_b32 v58, v59, v58, v50                          ; d1cf003a 04ca753b
	v_alignbyte_b32 v59, v59, v59, v50                          ; d1cf003b 04ca773b
	v_lshl_or_b32 v43, v43, 12, v43                             ; d200002b 04ad192b
	v_mac_f32_e32 v41, v49, v55                                 ; 2c526f31
	v_mov_b32_sdwa v58, v59 dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_0 ; 7e7402f9 0004153b
	v_mac_f32_e32 v8, v42, v41                                  ; 2c10532a
	v_and_b32_e32 v41, s10, v39                                 ; 26524e0a
	v_lshrrev_b32_e32 v39, 4, v39                               ; 204e4e84
	v_and_b32_e32 v38, s11, v58                                 ; 264c740b
	v_cvt_f32_ubyte3_e32 v42, v41                               ; 7e542929
	v_cvt_f32_ubyte2_e32 v45, v41                               ; 7e5a2729
	v_cvt_f32_ubyte1_e32 v46, v41                               ; 7e5c2529
	v_cvt_f32_ubyte0_e32 v41, v41                               ; 7e522329
	v_and_b32_e32 v39, s10, v39                                 ; 264e4e0a
	v_lshrrev_b32_e32 v38, 2, v38                               ; 204c4c82
	v_mul_f32_e32 v42, v19, v42                                 ; 0a545513
	v_and_b32_e32 v56, s10, v52                                 ; 2670680a
	v_cvt_f32_ubyte2_e32 v50, v39                               ; 7e642727
	v_cvt_f32_ubyte3_e32 v49, v39                               ; 7e622927
	v_cvt_f32_ubyte1_e32 v55, v39                               ; 7e6e2527
	v_cvt_f32_ubyte0_e32 v39, v39                               ; 7e4e2327
	v_and_or_b32 v43, s10, v43, v38                             ; d201002b 049a560a
	v_mac_f32_e32 v42, v18, v45                                 ; 2c545b12
	v_cvt_f32_ubyte2_e32 v38, v56                               ; 7e4c2738
	v_cvt_f32_ubyte3_e32 v59, v56                               ; 7e762938
	v_mul_f32_e32 v49, v23, v49                                 ; 0a626317
	v_cvt_f32_ubyte3_e32 v40, v43                               ; 7e50292b
	v_lshrrev_b32_e32 v52, 4, v52                               ; 20686884
	v_mac_f32_e32 v42, v17, v46                                 ; 2c545d11
	v_mul_f32_e32 v59, v27, v59                                 ; 0a76771b
	v_mac_f32_e32 v49, v22, v50                                 ; 2c626516
	v_and_b32_e32 v52, s10, v52                                 ; 2668680a
	v_mac_f32_e32 v42, v16, v41                                 ; 2c545310
	v_mac_f32_e32 v59, v26, v38                                 ; 2c764d1a
	v_mac_f32_e32 v49, v21, v55                                 ; 2c626f15
	v_cvt_f32_ubyte2_e32 v45, v52                               ; 7e5a2734
	v_cvt_f32_ubyte1_e32 v46, v52                               ; 7e5c2534
	v_mul_f32_e32 v40, v36, v40                                 ; 0a505124
	v_cvt_f32_ubyte3_e32 v41, v52                               ; 7e522934
	v_cvt_f32_ubyte0_e32 v52, v52                               ; 7e682334
	v_cvt_f32_ubyte2_e32 v50, v43                               ; 7e64272b
	v_and_b32_e32 v58, s12, v58                                 ; 2674740c
	v_mac_f32_e32 v49, v20, v39                                 ; 2c624f14
	v_cvt_f32_ubyte1_e32 v39, v56                               ; 7e4e2538
	v_cvt_f32_ubyte0_e32 v56, v56                               ; 7e702338
	v_mul_f32_e32 v41, v15, v41                                 ; 0a52530f
	v_mac_f32_e32 v40, v29, v50                                 ; 2c50651d
	v_cvt_f32_ubyte2_e32 v55, v58                               ; 7e6e273a
	v_mac_f32_e32 v59, v25, v39                                 ; 2c764f19
	v_mac_f32_e32 v41, v14, v45                                 ; 2c525b0e
	v_mac_f32_e32 v59, v24, v56                                 ; 2c767118
	v_cvt_f32_ubyte1_e32 v56, v43                               ; 7e70252b
	v_cvt_f32_ubyte0_e32 v43, v43                               ; 7e56232b
	v_mac_f32_e32 v41, v13, v46                                 ; 2c525d0d
	v_alignbyte_b32 v33, v34, v33, v51                          ; d1cf0021 04ce4322
	v_alignbyte_b32 v34, v34, v34, v51                          ; d1cf0022 04ce4522
	v_mac_f32_e32 v41, v12, v52                                 ; 2c52690c
	v_cvt_f32_ubyte3_e32 v52, v58                               ; 7e68293a
	v_mov_b32_sdwa v33, v34 dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_0 ; 7e4202f9 00041522
	v_mul_f32_e32 v41, v41, v56                                 ; 0a527129
	v_mac_f32_e32 v40, v62, v52                                 ; 2c50693e
	v_and_b32_e32 v38, s11, v33                                 ; 264c420b
	v_and_b32_e32 v33, s12, v33                                 ; 2642420c
	v_mac_f32_e32 v41, v59, v43                                 ; 2c52573b
	v_cvt_f32_ubyte1_e32 v59, v58                               ; 7e76253a
	v_cvt_f32_ubyte0_e32 v58, v58                               ; 7e74233a
	v_mac_f32_e32 v40, v61, v55                                 ; 2c506f3d
	v_lshrrev_b32_e32 v38, 2, v38                               ; 204c4c82
	v_lshl_or_b32 v48, v48, 12, v48                             ; d2000030 04c11930
	v_cvt_f32_ubyte3_e32 v39, v33                               ; 7e4e2921
	v_mac_f32_e32 v41, v49, v59                                 ; 2c527731
	v_mad_f32 v9, -v35, v40, v9                                 ; d1c10009 24265123
	v_cvt_f32_f16_sdwa v35, v28 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e4616f9 0005061c
	v_cvt_f32_f16_e32 v28, v28                                  ; 7e38171c
	v_cvt_f32_ubyte2_e32 v40, v33                               ; 7e502721
	v_and_or_b32 v48, s10, v48, v38                             ; d2010030 049a600a
	v_mac_f32_e32 v41, v42, v58                                 ; 2c52752a
	v_and_b32_e32 v46, s10, v44                                 ; 265c580a
	v_cvt_f32_ubyte2_e32 v43, v48                               ; 7e562730
	v_cvt_f32_ubyte1_e32 v45, v48                               ; 7e5a2530
	v_cvt_f32_ubyte3_e32 v42, v48                               ; 7e542930
	v_cvt_f32_ubyte0_e32 v48, v48                               ; 7e602330
	v_mac_f32_e32 v9, v54, v41                                  ; 2c125336
	v_cvt_f32_ubyte1_e32 v41, v33                               ; 7e522521
	v_cvt_f32_ubyte0_e32 v33, v33                               ; 7e422321
	v_cvt_f32_ubyte1_e32 v51, v46                               ; 7e66252e
	v_cvt_f32_ubyte3_e32 v49, v46                               ; 7e62292e
	v_cvt_f32_ubyte2_e32 v50, v46                               ; 7e64272e
	v_cvt_f32_ubyte0_e32 v46, v46                               ; 7e5c232e
	v_mul_f32_e32 v42, v36, v42                                 ; 0a545524
	v_lshrrev_b32_e32 v44, 4, v44                               ; 20585884
	v_mul_f32_e32 v49, v19, v49                                 ; 0a626313
	v_mac_f32_e32 v42, v29, v43                                 ; 2c54571d
	v_and_b32_e32 v44, s10, v44                                 ; 2658580a
	v_and_b32_e32 v56, s10, v60                                 ; 2670780a
	v_mac_f32_e32 v49, v18, v50                                 ; 2c626512
	v_mac_f32_e32 v42, v62, v39                                 ; 2c544f3e
	v_cvt_f32_ubyte2_e32 v54, v44                               ; 7e6c272c
	v_cvt_f32_ubyte3_e32 v52, v44                               ; 7e68292c
	v_cvt_f32_ubyte1_e32 v55, v44                               ; 7e6e252c
	v_cvt_f32_ubyte0_e32 v44, v44                               ; 7e58232c
	v_cvt_f32_ubyte2_e32 v59, v56                               ; 7e762738
	v_cvt_f32_ubyte3_e32 v58, v56                               ; 7e742938
	v_mac_f32_e32 v49, v17, v51                                 ; 2c626711
	v_cvt_f32_ubyte1_e32 v34, v56                               ; 7e442538
	v_mac_f32_e32 v42, v61, v40                                 ; 2c54513d
	v_mul_f32_e32 v52, v23, v52                                 ; 0a686917
	v_cvt_f32_ubyte0_e32 v56, v56                               ; 7e702338
	v_lshrrev_b32_e32 v60, 4, v60                               ; 20787884
	v_mul_f32_e32 v58, v27, v58                                 ; 0a74751b
	v_mac_f32_e32 v49, v16, v46                                 ; 2c625d10
	v_mad_f32 v10, -v35, v42, v10                               ; d1c1000a 242a5523
	v_mac_f32_e32 v52, v22, v54                                 ; 2c686d16
	v_and_b32_e32 v60, s10, v60                                 ; 2678780a
	v_mac_f32_e32 v58, v26, v59                                 ; 2c74771a
	v_mac_f32_e32 v52, v21, v55                                 ; 2c686f15
	v_cvt_f32_ubyte3_e32 v35, v60                               ; 7e46293c
	v_cvt_f32_ubyte2_e32 v38, v60                               ; 7e4c273c
	v_cvt_f32_ubyte1_e32 v39, v60                               ; 7e4e253c
	v_cvt_f32_ubyte0_e32 v60, v60                               ; 7e78233c
	v_mac_f32_e32 v58, v25, v34                                 ; 2c744519
	s_waitcnt vmcnt(4)                                          ; bf8c3f74
	v_cvt_f32_f16_sdwa v40, v37 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e5016f9 00050625
	v_mac_f32_e32 v52, v20, v44                                 ; 2c685914
	v_mul_f32_e32 v35, v15, v35                                 ; 0a46470f
	v_cvt_f32_f16_e32 v37, v37                                  ; 7e4a1725
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_alignbyte_b32 v31, v32, v31, v30                          ; d1cf001f 047a3f20
	v_alignbyte_b32 v32, v32, v32, v30                          ; d1cf0020 047a4120
	v_mac_f32_e32 v58, v24, v56                                 ; 2c747118
	v_mac_f32_e32 v35, v14, v38                                 ; 2c464d0e
	v_mov_b32_sdwa v31, v32 dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_0 ; 7e3e02f9 00041520
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_lshl_or_b32 v47, v47, 12, v47                             ; d200002f 04bd192f
	v_mac_f32_e32 v35, v13, v39                                 ; 2c464f0d
	v_mac_f32_e32 v35, v12, v60                                 ; 2c46790c
	v_mul_f32_e32 v35, v35, v45                                 ; 0a465b23
	v_mac_f32_e32 v35, v58, v48                                 ; 2c46613a
	v_mac_f32_e32 v35, v52, v41                                 ; 2c465334
	v_and_b32_e32 v41, s11, v31                                 ; 26523e0b
	v_and_b32_e32 v31, s12, v31                                 ; 263e3e0c
	v_mac_f32_e32 v35, v49, v33                                 ; 2c464331
	v_lshrrev_b32_e32 v41, 2, v41                               ; 20525282
	v_cvt_f32_ubyte1_e32 v44, v31                               ; 7e58251f
	v_cvt_f32_ubyte3_e32 v42, v31                               ; 7e54291f
	v_cvt_f32_ubyte2_e32 v43, v31                               ; 7e56271f
	v_cvt_f32_ubyte0_e32 v31, v31                               ; 7e3e231f
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v49, s10, v57                                 ; 2662720a
	v_mac_f32_e32 v10, v28, v35                                 ; 2c14471c
	v_and_or_b32 v47, s10, v47, v41                             ; d201002f 04a65e0a
	v_cvt_f32_ubyte3_e32 v50, v49                               ; 7e642931
	v_cvt_f32_ubyte1_e32 v52, v49                               ; 7e682531
	v_cvt_f32_ubyte2_e32 v51, v49                               ; 7e662731
	v_cvt_f32_ubyte0_e32 v49, v49                               ; 7e622331
	v_cvt_f32_ubyte3_e32 v45, v47                               ; 7e5a292f
	v_cvt_f32_ubyte1_e32 v48, v47                               ; 7e60252f
	v_cvt_f32_ubyte2_e32 v46, v47                               ; 7e5c272f
	v_cvt_f32_ubyte0_e32 v47, v47                               ; 7e5e232f
	v_lshrrev_b32_e32 v57, 4, v57                               ; 20727284
	v_mul_f32_e32 v19, v19, v50                                 ; 0a266513
	v_mul_f32_e32 v36, v36, v45                                 ; 0a485b24
	v_and_b32_e32 v57, s10, v57                                 ; 2672720a
	v_mac_f32_e32 v19, v18, v51                                 ; 2c266712
	v_mac_f32_e32 v36, v29, v46                                 ; 2c485d1d
	v_cvt_f32_ubyte1_e32 v56, v57                               ; 7e702539
	v_cvt_f32_ubyte3_e32 v54, v57                               ; 7e6c2939
	v_cvt_f32_ubyte2_e32 v55, v57                               ; 7e6e2739
	v_cvt_f32_ubyte0_e32 v57, v57                               ; 7e722339
	v_mac_f32_e32 v19, v17, v52                                 ; 2c266911
	v_mac_f32_e32 v36, v62, v42                                 ; 2c48553e
	v_mul_f32_e32 v23, v23, v54                                 ; 0a2e6d17
	v_mac_f32_e32 v19, v16, v49                                 ; 2c266310
	v_mac_f32_e32 v36, v61, v43                                 ; 2c48573d
	v_mac_f32_e32 v23, v22, v55                                 ; 2c2e6f16
	v_mad_f32 v11, -v40, v36, v11                               ; d1c1000b 242e4928
	v_mac_f32_e32 v23, v21, v56                                 ; 2c2e7115
	v_mac_f32_e32 v23, v20, v57                                 ; 2c2e7314
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v57, s10, v53                                 ; 26726a0a
	v_lshrrev_b32_e32 v53, 4, v53                               ; 206a6a84
	v_cvt_f32_ubyte2_e32 v59, v57                               ; 7e762739
	v_cvt_f32_ubyte1_e32 v60, v57                               ; 7e782539
	v_cvt_f32_ubyte3_e32 v58, v57                               ; 7e742939
	v_cvt_f32_ubyte0_e32 v57, v57                               ; 7e722339
	v_and_b32_e32 v53, s10, v53                                 ; 266a6a0a
	v_mul_f32_e32 v27, v27, v58                                 ; 0a36751b
	v_cvt_f32_ubyte2_e32 v62, v53                               ; 7e7c2735
	v_cvt_f32_ubyte3_e32 v61, v53                               ; 7e7a2935
	v_mac_f32_e32 v27, v26, v59                                 ; 2c36771a
	v_mul_f32_e32 v15, v15, v61                                 ; 0a1e7b0f
	v_mac_f32_e32 v27, v25, v60                                 ; 2c367919
	v_mac_f32_e32 v15, v14, v62                                 ; 2c1e7d0e
	v_cvt_f32_ubyte1_e32 v62, v53                               ; 7e7c2535
	v_cvt_f32_ubyte0_e32 v53, v53                               ; 7e6a2335
	v_mac_f32_e32 v27, v24, v57                                 ; 2c367318
	v_mac_f32_e32 v15, v13, v62                                 ; 2c1e7d0d
	v_mac_f32_e32 v15, v12, v53                                 ; 2c1e6b0c
	v_mul_f32_e32 v15, v15, v48                                 ; 0a1e610f
	v_mac_f32_e32 v15, v27, v47                                 ; 2c1e5f1b
	v_mac_f32_e32 v15, v23, v44                                 ; 2c1e5917
	v_mac_f32_e32 v15, v19, v31                                 ; 2c1e3f13
	v_mac_f32_e32 v11, v37, v15                                 ; 2c161f25
BB5:
	s_mov_b64 s[0:1], exec                                      ; be80017e
	v_cmpx_le_u32_e32 vcc, s3, v0                               ; 7db60003
BB6:
	s_andn2_b64 s[0:1], s[0:1], exec                            ; 89807e00
	s_cbranch_scc1 BB10                                         ; bf85fca4
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
	s_branch BB203                                              ; bf8205d4
BB66:
	s_cmp_lt_u32 s16, s4                                        ; bf0a0410
	s_cbranch_scc0 BB203                                        ; bf8405d2
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
	v_mov_b32_e32 v7, 0                                         ; 7e0e0280
	s_mul_i32 s19, s19, s5                                      ; 92130513
	v_mov_b32_e32 v8, 0                                         ; 7e100280
	v_mov_b32_e32 v9, 0                                         ; 7e120280
	v_sub_u32_e32 v1, v2, v1                                    ; 6a020302
	v_bfe_u32 v3, v2, 2, 1                                      ; d1c80003 02050502
	v_lshrrev_b32_e32 v2, 3, v2                                 ; 20040483
	v_mov_b32_e32 v10, 0                                        ; 7e140280
	v_mov_b32_e32 v11, 0                                        ; 7e160280
	v_lshl_add_u32 v1, v1, 1, v3                                ; d1fd0001 040d0301
	v_mov_b32_e32 v3, 0                                         ; 7e060280
	v_lshlrev_b32_e32 v1, 2, v1                                 ; 24020282
	v_lshl_add_u32 v4, v2, 5, v1                                ; d1fd0004 04050b02
	v_lshl_add_u32 v1, v2, 6, v1                                ; d1fd0001 04050d02
BB71:
	s_mov_b64 s[0:1], exec                                      ; be80017e
	v_cmpx_le_u32_e32 vcc, s3, v0                               ; 7db60003
BB72:
	s_andn2_b64 s[0:1], s[0:1], exec                            ; 89807e00
	s_cbranch_scc0 BB101                                        ; bf840391
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
	s_cbranch_scc0 BB100                                        ; bf840364
BB77:
	s_load_dwordx4 s[12:15], s[0:1], 0x0                        ; c00a0300 00000000
	s_mul_i32 s0, s16, s3                                       ; 92000310
	v_lshlrev_b32_e32 v34, 1, v2                                ; 24440481
	v_add_u32_e32 v42, 64, v4                                   ; 685408c0
	s_add_u32 s0, s19, s0                                       ; 80000013
	v_and_b32_e32 v36, -4, v34                                  ; 264844c4
	v_add_u32_e32 v39, 8, v34                                   ; 684e4488
	v_add_u32_e32 v32, s0, v0                                   ; 68400000
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
	buffer_load_dword v32, v32, s[12:15], 0 offen               ; e0501000 80032020
	buffer_load_dwordx2 v[44:45], v37, s[12:15], 0 offen        ; e0541000 80032c25
	buffer_load_ushort v35, v35, s[12:15], 0 offen              ; e0481000 80032323
	buffer_load_dword v41, v41, s[12:15], 0 offen               ; e0501000 80032929
	buffer_load_dword v40, v40, s[12:15], 0 offen               ; e0501000 80032828
	s_mov_b32 s1, 0xf0f0f0f                                     ; be8100ff 0f0f0f0f
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
	v_and_b32_e32 v52, s1, v41                                  ; 26685201
	v_cvt_f32_ubyte3_e32 v46, v44                               ; 7e5c292c
	v_cvt_f32_ubyte2_e32 v47, v44                               ; 7e5e272c
	v_cvt_f32_ubyte1_e32 v48, v44                               ; 7e60252c
	v_cvt_f32_ubyte0_e32 v44, v44                               ; 7e58232c
	v_and_or_b32 v35, s1, v35, v45                              ; d2010023 04b64601
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
	v_and_b32_e32 v41, s1, v41                                  ; 26525201
	v_mac_f32_e32 v53, v18, v54                                 ; 2c6a6d12
	v_mac_f32_e32 v49, v30, v50                                 ; 2c62651e
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v59, s1, v40                                  ; 26765001
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
	v_and_b32_e32 v40, s1, v40                                  ; 26505001
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
	s_cbranch_scc0 BB100                                        ; bf8402f2
BB78:
	s_add_u32 s0, s16, 1                                        ; 80008110
	s_mul_i32 s0, s0, s3                                        ; 92000300
	s_add_u32 s0, s19, s0                                       ; 80000013
	v_add_u32_e32 v32, s0, v0                                   ; 68400000
	v_lshlrev_b32_e32 v33, 4, v32                               ; 24424084
	v_lshl_add_u32 v32, v32, 7, v33                             ; d1fd0020 04850f20
	v_add_u32_e32 v35, 4, v32                                   ; 68464084
	v_add_u32_e32 v40, 16, v32                                  ; 68504090
	v_add_u32_e32 v37, v36, v35                                 ; 684a4724
	v_add_u32_e32 v38, v35, v34                                 ; 684c4523
	v_add_u32_e32 v35, v35, v39                                 ; 68464f23
	v_add_u32_e32 v41, v40, v4                                  ; 68520928
	v_add_u32_e32 v40, v40, v42                                 ; 68505528
	buffer_load_dword v32, v32, s[12:15], 0 offen               ; e0501000 80032020
	buffer_load_dwordx2 v[44:45], v37, s[12:15], 0 offen        ; e0541000 80032c25
	buffer_load_ushort v35, v35, s[12:15], 0 offen              ; e0481000 80032323
	buffer_load_dword v41, v41, s[12:15], 0 offen               ; e0501000 80032929
	buffer_load_dword v40, v40, s[12:15], 0 offen               ; e0501000 80032828
	s_mov_b32 s1, 0xf0f0f0f                                     ; be8100ff 0f0f0f0f
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
	v_and_b32_e32 v52, s1, v41                                  ; 26685201
	v_cvt_f32_ubyte3_e32 v46, v44                               ; 7e5c292c
	v_cvt_f32_ubyte2_e32 v47, v44                               ; 7e5e272c
	v_cvt_f32_ubyte1_e32 v48, v44                               ; 7e60252c
	v_cvt_f32_ubyte0_e32 v44, v44                               ; 7e58232c
	v_and_or_b32 v35, s1, v35, v45                              ; d2010023 04b64601
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
	v_and_b32_e32 v41, s1, v41                                  ; 26525201
	v_mac_f32_e32 v49, v30, v50                                 ; 2c62651e
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v59, s1, v40                                  ; 26765001
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
	v_and_b32_e32 v40, s1, v40                                  ; 26505001
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
	s_cbranch_scc0 BB100                                        ; bf840286
BB79:
	s_add_u32 s0, s16, 2                                        ; 80008210
	s_mul_i32 s0, s0, s3                                        ; 92000300
	s_add_u32 s0, s19, s0                                       ; 80000013
	v_add_u32_e32 v32, s0, v0                                   ; 68400000
	v_lshlrev_b32_e32 v33, 4, v32                               ; 24424084
	v_lshl_add_u32 v32, v32, 7, v33                             ; d1fd0020 04850f20
	v_add_u32_e32 v35, 4, v32                                   ; 68464084
	v_add_u32_e32 v40, 16, v32                                  ; 68504090
	v_add_u32_e32 v37, v36, v35                                 ; 684a4724
	v_add_u32_e32 v38, v35, v34                                 ; 684c4523
	v_add_u32_e32 v35, v35, v39                                 ; 68464f23
	v_add_u32_e32 v41, v40, v4                                  ; 68520928
	v_add_u32_e32 v40, v40, v42                                 ; 68505528
	buffer_load_dword v32, v32, s[12:15], 0 offen               ; e0501000 80032020
	buffer_load_dwordx2 v[44:45], v37, s[12:15], 0 offen        ; e0541000 80032c25
	buffer_load_ushort v35, v35, s[12:15], 0 offen              ; e0481000 80032323
	buffer_load_dword v41, v41, s[12:15], 0 offen               ; e0501000 80032929
	buffer_load_dword v40, v40, s[12:15], 0 offen               ; e0501000 80032828
	s_mov_b32 s1, 0xf0f0f0f                                     ; be8100ff 0f0f0f0f
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
	v_and_b32_e32 v52, s1, v41                                  ; 26685201
	v_cvt_f32_ubyte3_e32 v46, v44                               ; 7e5c292c
	v_cvt_f32_ubyte2_e32 v47, v44                               ; 7e5e272c
	v_cvt_f32_ubyte1_e32 v48, v44                               ; 7e60252c
	v_cvt_f32_ubyte0_e32 v44, v44                               ; 7e58232c
	v_and_or_b32 v35, s1, v35, v45                              ; d2010023 04b64601
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
	v_and_b32_e32 v41, s1, v41                                  ; 26525201
	v_mac_f32_e32 v49, v30, v50                                 ; 2c62651e
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v59, s1, v40                                  ; 26765001
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
	v_and_b32_e32 v40, s1, v40                                  ; 26505001
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
	s_cbranch_scc0 BB100                                        ; bf84021a
BB80:
	s_add_u32 s0, s16, 3                                        ; 80008310
	s_mul_i32 s0, s0, s3                                        ; 92000300
	s_add_u32 s0, s19, s0                                       ; 80000013
	v_add_u32_e32 v32, s0, v0                                   ; 68400000
	v_lshlrev_b32_e32 v33, 4, v32                               ; 24424084
	v_lshl_add_u32 v32, v32, 7, v33                             ; d1fd0020 04850f20
	v_add_u32_e32 v35, 4, v32                                   ; 68464084
	v_add_u32_e32 v40, 16, v32                                  ; 68504090
	v_add_u32_e32 v37, v36, v35                                 ; 684a4724
	v_add_u32_e32 v38, v35, v34                                 ; 684c4523
	v_add_u32_e32 v35, v35, v39                                 ; 68464f23
	v_add_u32_e32 v41, v40, v4                                  ; 68520928
	v_add_u32_e32 v40, v40, v42                                 ; 68505528
	buffer_load_dword v32, v32, s[12:15], 0 offen               ; e0501000 80032020
	buffer_load_dwordx2 v[44:45], v37, s[12:15], 0 offen        ; e0541000 80032c25
	buffer_load_ushort v35, v35, s[12:15], 0 offen              ; e0481000 80032323
	buffer_load_dword v41, v41, s[12:15], 0 offen               ; e0501000 80032929
	buffer_load_dword v40, v40, s[12:15], 0 offen               ; e0501000 80032828
	s_mov_b32 s1, 0xf0f0f0f                                     ; be8100ff 0f0f0f0f
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
	v_and_b32_e32 v52, s1, v41                                  ; 26685201
	v_cvt_f32_ubyte3_e32 v46, v44                               ; 7e5c292c
	v_cvt_f32_ubyte2_e32 v47, v44                               ; 7e5e272c
	v_cvt_f32_ubyte1_e32 v48, v44                               ; 7e60252c
	v_cvt_f32_ubyte0_e32 v44, v44                               ; 7e58232c
	v_and_or_b32 v35, s1, v35, v45                              ; d2010023 04b64601
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
	v_and_b32_e32 v41, s1, v41                                  ; 26525201
	v_mac_f32_e32 v49, v30, v50                                 ; 2c62651e
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v59, s1, v40                                  ; 26765001
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
	v_and_b32_e32 v40, s1, v40                                  ; 26505001
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
	s_cbranch_scc0 BB100                                        ; bf8401ae
BB81:
	s_add_u32 s0, s16, 4                                        ; 80008410
	s_mul_i32 s0, s0, s3                                        ; 92000300
	s_add_u32 s0, s19, s0                                       ; 80000013
	v_add_u32_e32 v32, s0, v0                                   ; 68400000
	v_lshlrev_b32_e32 v33, 4, v32                               ; 24424084
	v_lshl_add_u32 v32, v32, 7, v33                             ; d1fd0020 04850f20
	v_add_u32_e32 v35, 4, v32                                   ; 68464084
	v_add_u32_e32 v40, 16, v32                                  ; 68504090
	v_add_u32_e32 v37, v36, v35                                 ; 684a4724
	v_add_u32_e32 v38, v35, v34                                 ; 684c4523
	v_add_u32_e32 v35, v35, v39                                 ; 68464f23
	v_add_u32_e32 v41, v40, v4                                  ; 68520928
	v_add_u32_e32 v40, v40, v42                                 ; 68505528
	buffer_load_dword v32, v32, s[12:15], 0 offen               ; e0501000 80032020
	buffer_load_dwordx2 v[44:45], v37, s[12:15], 0 offen        ; e0541000 80032c25
	buffer_load_ushort v35, v35, s[12:15], 0 offen              ; e0481000 80032323
	buffer_load_dword v41, v41, s[12:15], 0 offen               ; e0501000 80032929
	buffer_load_dword v40, v40, s[12:15], 0 offen               ; e0501000 80032828
	s_mov_b32 s1, 0xf0f0f0f                                     ; be8100ff 0f0f0f0f
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
	v_and_b32_e32 v52, s1, v41                                  ; 26685201
	v_cvt_f32_ubyte3_e32 v46, v44                               ; 7e5c292c
	v_cvt_f32_ubyte2_e32 v47, v44                               ; 7e5e272c
	v_cvt_f32_ubyte1_e32 v48, v44                               ; 7e60252c
	v_cvt_f32_ubyte0_e32 v44, v44                               ; 7e58232c
	v_and_or_b32 v35, s1, v35, v45                              ; d2010023 04b64601
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
	v_and_b32_e32 v41, s1, v41                                  ; 26525201
	v_mac_f32_e32 v49, v30, v50                                 ; 2c62651e
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v59, s1, v40                                  ; 26765001
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
	v_and_b32_e32 v40, s1, v40                                  ; 26505001
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
	s_cbranch_scc0 BB100                                        ; bf840142
BB82:
	s_add_u32 s0, s16, 5                                        ; 80008510
	s_mul_i32 s0, s0, s3                                        ; 92000300
	s_add_u32 s0, s19, s0                                       ; 80000013
	v_add_u32_e32 v32, s0, v0                                   ; 68400000
	v_lshlrev_b32_e32 v33, 4, v32                               ; 24424084
	v_lshl_add_u32 v32, v32, 7, v33                             ; d1fd0020 04850f20
	v_add_u32_e32 v35, 4, v32                                   ; 68464084
	v_add_u32_e32 v40, 16, v32                                  ; 68504090
	v_add_u32_e32 v37, v36, v35                                 ; 684a4724
	v_add_u32_e32 v38, v35, v34                                 ; 684c4523
	v_add_u32_e32 v35, v35, v39                                 ; 68464f23
	v_add_u32_e32 v41, v40, v4                                  ; 68520928
	v_add_u32_e32 v40, v40, v42                                 ; 68505528
	buffer_load_dword v32, v32, s[12:15], 0 offen               ; e0501000 80032020
	buffer_load_dwordx2 v[44:45], v37, s[12:15], 0 offen        ; e0541000 80032c25
	buffer_load_ushort v35, v35, s[12:15], 0 offen              ; e0481000 80032323
	buffer_load_dword v41, v41, s[12:15], 0 offen               ; e0501000 80032929
	buffer_load_dword v40, v40, s[12:15], 0 offen               ; e0501000 80032828
	s_mov_b32 s1, 0xf0f0f0f                                     ; be8100ff 0f0f0f0f
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
	v_and_b32_e32 v52, s1, v41                                  ; 26685201
	v_cvt_f32_ubyte3_e32 v46, v44                               ; 7e5c292c
	v_cvt_f32_ubyte2_e32 v47, v44                               ; 7e5e272c
	v_cvt_f32_ubyte1_e32 v48, v44                               ; 7e60252c
	v_cvt_f32_ubyte0_e32 v44, v44                               ; 7e58232c
	v_and_or_b32 v35, s1, v35, v45                              ; d2010023 04b64601
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
	v_and_b32_e32 v41, s1, v41                                  ; 26525201
	v_mac_f32_e32 v49, v30, v50                                 ; 2c62651e
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v59, s1, v40                                  ; 26765001
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
	v_and_b32_e32 v40, s1, v40                                  ; 26505001
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
	s_cbranch_scc0 BB100                                        ; bf8400d6
BB83:
	s_add_u32 s0, s16, 6                                        ; 80008610
	s_mul_i32 s0, s0, s3                                        ; 92000300
	s_add_u32 s0, s19, s0                                       ; 80000013
	v_add_u32_e32 v32, s0, v0                                   ; 68400000
	v_lshlrev_b32_e32 v33, 4, v32                               ; 24424084
	v_lshl_add_u32 v32, v32, 7, v33                             ; d1fd0020 04850f20
	v_add_u32_e32 v35, 4, v32                                   ; 68464084
	v_add_u32_e32 v40, 16, v32                                  ; 68504090
	v_add_u32_e32 v37, v36, v35                                 ; 684a4724
	v_add_u32_e32 v38, v35, v34                                 ; 684c4523
	v_add_u32_e32 v35, v35, v39                                 ; 68464f23
	v_add_u32_e32 v41, v40, v4                                  ; 68520928
	v_add_u32_e32 v40, v40, v42                                 ; 68505528
	buffer_load_dword v32, v32, s[12:15], 0 offen               ; e0501000 80032020
	buffer_load_dwordx2 v[44:45], v37, s[12:15], 0 offen        ; e0541000 80032c25
	buffer_load_ushort v35, v35, s[12:15], 0 offen              ; e0481000 80032323
	buffer_load_dword v41, v41, s[12:15], 0 offen               ; e0501000 80032929
	buffer_load_dword v40, v40, s[12:15], 0 offen               ; e0501000 80032828
	s_mov_b32 s1, 0xf0f0f0f                                     ; be8100ff 0f0f0f0f
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
	v_and_b32_e32 v52, s1, v41                                  ; 26685201
	v_cvt_f32_ubyte3_e32 v46, v44                               ; 7e5c292c
	v_cvt_f32_ubyte2_e32 v47, v44                               ; 7e5e272c
	v_cvt_f32_ubyte1_e32 v48, v44                               ; 7e60252c
	v_cvt_f32_ubyte0_e32 v44, v44                               ; 7e58232c
	v_and_or_b32 v35, s1, v35, v45                              ; d2010023 04b64601
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
	v_and_b32_e32 v41, s1, v41                                  ; 26525201
	v_mac_f32_e32 v49, v30, v50                                 ; 2c62651e
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v59, s1, v40                                  ; 26765001
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
	v_and_b32_e32 v40, s1, v40                                  ; 26505001
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
	s_cbranch_scc0 BB100                                        ; bf84006a
BB84:
	s_add_u32 s0, s16, 7                                        ; 80008710
	s_mul_i32 s0, s0, s3                                        ; 92000300
	s_add_u32 s0, s19, s0                                       ; 80000013
	v_add_u32_e32 v32, s0, v0                                   ; 68400000
	v_lshlrev_b32_e32 v33, 4, v32                               ; 24424084
	v_lshl_add_u32 v32, v32, 7, v33                             ; d1fd0020 04850f20
	v_add_u32_e32 v35, 4, v32                                   ; 68464084
	v_add_u32_e32 v37, 16, v32                                  ; 684a4090
	v_add_u32_e32 v36, v36, v35                                 ; 68484724
	v_add_u32_e32 v34, v35, v34                                 ; 68444523
	v_add_u32_e32 v35, v35, v39                                 ; 68464f23
	v_add_u32_e32 v38, v37, v4                                  ; 684c0925
	v_add_u32_e32 v37, v37, v42                                 ; 684a5525
	buffer_load_dword v32, v32, s[12:15], 0 offen               ; e0501000 80032020
	buffer_load_dwordx2 v[40:41], v36, s[12:15], 0 offen        ; e0541000 80032824
	buffer_load_ushort v35, v35, s[12:15], 0 offen              ; e0481000 80032323
	buffer_load_dword v38, v38, s[12:15], 0 offen               ; e0501000 80032626
	buffer_load_dword v37, v37, s[12:15], 0 offen               ; e0501000 80032525
	s_mov_b32 s1, 0xf0f0f0f                                     ; be8100ff 0f0f0f0f
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
	v_and_b32_e32 v48, s1, v38                                  ; 26604c01
	v_cvt_f32_ubyte3_e32 v42, v40                               ; 7e542928
	v_cvt_f32_ubyte2_e32 v43, v40                               ; 7e562728
	v_cvt_f32_ubyte1_e32 v44, v40                               ; 7e582528
	v_cvt_f32_ubyte0_e32 v40, v40                               ; 7e502328
	v_and_or_b32 v35, s1, v35, v41                              ; d2010023 04a64601
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
	v_and_b32_e32 v38, s1, v38                                  ; 264c4c01
	v_mac_f32_e32 v31, v30, v46                                 ; 2c3e5d1e
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v55, s1, v37                                  ; 266e4a01
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
	v_and_b32_e32 v37, s1, v37                                  ; 264a4a01
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
BB100:
	v_add_u32_e32 v0, 4, v0                                     ; 68000084
	s_branch BB71                                               ; bf82fc6b
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
