BB0:
	s_load_dword s0, s[14:15], 0x0                              ; c0020007 00000000
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_mul_i32 s0, s0, s18                                       ; 92001200
	s_add_u32 s16, s16, s0                                      ; 80100010
	s_lshl_b32 s16, s16, 3                                      ; 8e108310
	s_add_u32 s1, s16, 8                                        ; 80018810
	s_cmp_ge_u32 s4, s1                                         ; bf090104
	s_cbranch_scc0 BB66                                         ; bf840549
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
	v_mov_b32_e32 v9, 0                                         ; 7e120280
	v_mov_b32_e32 v10, 0                                        ; 7e140280
	v_mov_b32_e32 v11, 0                                        ; 7e160280
	v_mov_b32_e32 v12, 0                                        ; 7e180280
	v_lshl_add_u32 v1, v1, 1, v3                                ; d1fd0001 040d0301
	v_mov_b32_e32 v3, 0                                         ; 7e060280
	v_lshlrev_b32_e32 v1, 2, v1                                 ; 24020282
	v_lshl_add_u32 v4, v2, 5, v1                                ; d1fd0004 04050b02
	v_lshl_add_u32 v1, v2, 6, v1                                ; d1fd0001 04050d02
	v_lshlrev_b32_e32 v2, 4, v2                                 ; 24040484
	v_sub_u32_e32 v5, 16, v2                                    ; 6a0a0490
	s_branch BB5                                                ; bf82031e
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
	v_add_u32_e32 v35, 64, v4                                   ; 684608c0
	s_add_u32 s1, s18, s1                                       ; 80010112
	s_add_u32 s4, s16, 1                                        ; 80048110
	v_add_u32_e32 v15, s1, v0                                   ; 681e0001
	s_mul_i32 s4, s4, s3                                        ; 92040304
	v_lshlrev_b32_e32 v32, 4, v15                               ; 24401e84
	s_add_u32 s4, s18, s4                                       ; 80040412
	s_add_u32 s5, s16, 2                                        ; 80058210
	v_lshl_add_u32 v15, v15, 7, v32                             ; d1fd000f 04810f0f
	v_add_u32_e32 v36, s4, v0                                   ; 68480004
	s_mul_i32 s5, s5, s3                                        ; 92050305
	v_add_u32_e32 v33, 16, v15                                  ; 68421e90
	v_lshlrev_b32_e32 v37, 4, v36                               ; 244a4884
	s_add_u32 s5, s18, s5                                       ; 80050512
	s_add_u32 s9, s16, 3                                        ; 80098310
	v_add_u32_e32 v34, v33, v4                                  ; 68440921
	v_add_u32_e32 v33, v33, v35                                 ; 68424721
	v_lshl_add_u32 v36, v36, 7, v37                             ; d1fd0024 04950f24
	v_add_u32_e32 v40, s5, v0                                   ; 68500005
	s_mul_i32 s9, s9, s3                                        ; 92090309
	v_add_u32_e32 v38, 16, v36                                  ; 684c4890
	v_lshlrev_b32_e32 v41, 4, v40                               ; 24525084
	s_add_u32 s9, s18, s9                                       ; 80090912
	v_add_u32_e32 v39, v38, v4                                  ; 684e0926
	v_add_u32_e32 v38, v38, v35                                 ; 684c4726
	v_lshl_add_u32 v40, v40, 7, v41                             ; d1fd0028 04a50f28
	v_add_u32_e32 v44, s9, v0                                   ; 68580009
	v_add_u32_e32 v42, 16, v40                                  ; 68545090
	v_lshlrev_b32_e32 v45, 4, v44                               ; 245a5884
	v_add_u32_e32 v43, v42, v4                                  ; 6856092a
	v_mov_b32_e32 v60, v12                                      ; 7e78030c
	v_add_u32_e32 v42, v42, v35                                 ; 6854472a
	v_lshl_add_u32 v44, v44, 7, v45                             ; d1fd002c 04b50f2c
	v_add_u32_e32 v46, 16, v44                                  ; 685c5890
	v_add_u32_e32 v47, v46, v4                                  ; 685e092e
	v_add_u32_e32 v46, v46, v35                                 ; 685c472e
	buffer_load_dwordx4 v[48:51], v15, s[24:27], 0 offen        ; e05c1000 8006300f
	buffer_load_dword v34, v34, s[24:27], 0 offen               ; e0501000 80062222
	buffer_load_dword v33, v33, s[24:27], 0 offen               ; e0501000 80062121
	buffer_load_dwordx4 v[52:55], v36, s[24:27], 0 offen        ; e05c1000 80063424
	buffer_load_dword v39, v39, s[24:27], 0 offen               ; e0501000 80062727
	buffer_load_dword v38, v38, s[24:27], 0 offen               ; e0501000 80062626
	buffer_load_dwordx4 v[56:59], v40, s[24:27], 0 offen        ; e05c1000 80063828
	buffer_load_dword v43, v43, s[24:27], 0 offen               ; e0501000 80062b2b
	buffer_load_dword v42, v42, s[24:27], 0 offen               ; e0501000 80062a2a
	buffer_load_dwordx4 v[12:15], v44, s[24:27], 0 offen        ; e05c1000 80060c2c
	buffer_load_dword v47, v47, s[24:27], 0 offen               ; e0501000 80062f2f
	buffer_load_dword v46, v46, s[24:27], 0 offen               ; e0501000 80062e2e
	s_bfm_b32 s10, 16, 16                                       ; 910a9090
	s_mov_b32 s11, 0xf0f0f0f                                    ; be8b00ff 0f0f0f0f
	s_mov_b32 s12, 0xc0c0c0c0                                   ; be8c00ff c0c0c0c0
	s_mov_b32 s13, 0x3f3f3f3f                                   ; be8d00ff 3f3f3f3f
	s_add_u32 s14, s16, 4                                       ; 800e8410
	s_mul_i32 s14, s14, s3                                      ; 920e030e
	s_add_u32 s14, s18, s14                                     ; 800e0e12
	s_waitcnt vmcnt(15)                                         ; bf8c3f7f
	v_add_f32_e32 v61, v16, v17                                 ; 027a2310
	s_waitcnt vmcnt(14)                                         ; bf8c3f7e
	v_add_f32_e32 v62, v20, v21                                 ; 027c2b14
	v_add_f32_e32 v61, v61, v18                                 ; 027a253d
	s_waitcnt vmcnt(13)                                         ; bf8c3f7d
	v_add_f32_e32 v32, v24, v25                                 ; 02403318
	v_add_f32_e32 v62, v62, v22                                 ; 027c2d3e
	s_waitcnt vmcnt(12)                                         ; bf8c3f7c
	v_add_f32_e32 v36, v28, v29                                 ; 02483b1c
	v_add_f32_e32 v61, v61, v19                                 ; 027a273d
	v_add_f32_e32 v32, v32, v26                                 ; 02403520
	v_add_f32_e32 v62, v62, v23                                 ; 027c2f3e
	v_add_f32_e32 v36, v36, v30                                 ; 02483d24
	v_add_f32_e32 v32, v32, v27                                 ; 02403720
	v_add_f32_e32 v36, v36, v31                                 ; 02483f24
	s_waitcnt vmcnt(11)                                         ; bf8c3f7b
	v_lshlrev_b32_e32 v50, v5, v50                              ; 24646505
	v_bfe_u32 v49, v49, v2, 16                                  ; d1c80031 02420531
	v_bfe_u32 v51, v51, v2, 16                                  ; d1c80033 02420533
	s_waitcnt vmcnt(10)                                         ; bf8c3f7a
	v_and_b32_e32 v40, s11, v34                                 ; 2650440b
	v_lshrrev_b32_e32 v34, 4, v34                               ; 20444484
	v_and_or_b32 v50, s10, v50, v49                             ; d2010032 04c6640a
	v_lshl_or_b32 v51, v51, 12, v51                             ; d2000033 04cd1933
	v_cvt_f32_ubyte2_e32 v44, v40                               ; 7e582728
	v_cvt_f32_ubyte3_e32 v41, v40                               ; 7e522928
	v_cvt_f32_ubyte1_e32 v45, v40                               ; 7e5a2528
	v_cvt_f32_ubyte0_e32 v40, v40                               ; 7e502328
	v_and_b32_e32 v34, s11, v34                                 ; 2644440b
	v_and_b32_e32 v37, s12, v50                                 ; 264a640c
	v_mul_f32_e32 v41, v19, v41                                 ; 0a525313
	v_cvt_f32_ubyte3_e32 v49, v34                               ; 7e622922
	v_lshrrev_b32_e32 v37, 2, v37                               ; 204a4a82
	v_mac_f32_e32 v41, v18, v44                                 ; 2c525912
	s_waitcnt vmcnt(9)                                          ; bf8c3f79
	v_and_b32_e32 v44, s11, v33                                 ; 2658420b
	v_mul_f32_e32 v49, v23, v49                                 ; 0a626317
	v_and_or_b32 v51, s11, v51, v37                             ; d2010033 0496660b
	v_cvt_f32_ubyte2_e32 v37, v34                               ; 7e4a2722
	v_mac_f32_e32 v41, v17, v45                                 ; 2c525b11
	v_cvt_f32_ubyte3_e32 v45, v44                               ; 7e5a292c
	v_lshrrev_b32_e32 v33, 4, v33                               ; 20424284
	v_mac_f32_e32 v49, v22, v37                                 ; 2c624b16
	v_cvt_f32_ubyte1_e32 v37, v44                               ; 7e4a252c
	v_mac_f32_e32 v41, v16, v40                                 ; 2c525110
	v_cvt_f32_ubyte1_e32 v40, v34                               ; 7e502522
	v_cvt_f32_ubyte0_e32 v34, v34                               ; 7e442322
	v_mul_f32_e32 v45, v27, v45                                 ; 0a5a5b1b
	v_and_b32_e32 v33, s11, v33                                 ; 2642420b
	v_mac_f32_e32 v49, v21, v40                                 ; 2c625115
	v_cvt_f32_ubyte3_e32 v40, v33                               ; 7e502921
	v_mac_f32_e32 v49, v20, v34                                 ; 2c624514
	v_cvt_f32_ubyte2_e32 v34, v44                               ; 7e44272c
	v_cvt_f32_ubyte0_e32 v44, v44                               ; 7e58232c
	v_mul_f32_e32 v40, v31, v40                                 ; 0a50511f
	v_and_b32_e32 v50, s13, v50                                 ; 2664640d
	v_mac_f32_e32 v45, v26, v34                                 ; 2c5a451a
	v_cvt_f32_ubyte1_e32 v34, v33                               ; 7e442521
	v_mac_f32_e32 v45, v25, v37                                 ; 2c5a4b19
	v_cvt_f32_ubyte3_e32 v37, v51                               ; 7e4a2933
	v_mac_f32_e32 v45, v24, v44                                 ; 2c5a5918
	v_cvt_f32_ubyte2_e32 v44, v33                               ; 7e582721
	v_cvt_f32_ubyte0_e32 v33, v33                               ; 7e422321
	v_mul_f32_e32 v37, v36, v37                                 ; 0a4a4b24
	v_mac_f32_e32 v40, v30, v44                                 ; 2c50591e
	v_cvt_f32_ubyte2_e32 v44, v51                               ; 7e582733
	v_mac_f32_e32 v40, v29, v34                                 ; 2c50451d
	v_cvt_f32_ubyte2_e32 v34, v50                               ; 7e442732
	v_mac_f32_e32 v37, v32, v44                                 ; 2c4a5920
	v_cvt_f32_ubyte1_e32 v44, v51                               ; 7e582533
	v_cvt_f32_ubyte0_e32 v51, v51                               ; 7e662333
	v_mac_f32_e32 v40, v28, v33                                 ; 2c50431c
	v_cvt_f32_ubyte3_e32 v33, v50                               ; 7e422932
	v_mul_f32_e32 v40, v40, v44                                 ; 0a505928
	v_mac_f32_e32 v37, v62, v33                                 ; 2c4a433e
	v_mac_f32_e32 v40, v45, v51                                 ; 2c50672d
	v_cvt_f32_ubyte1_e32 v45, v50                               ; 7e5a2532
	v_cvt_f32_ubyte0_e32 v50, v50                               ; 7e642332
	v_cvt_f32_f16_sdwa v51, v48 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e6616f9 00050630
	v_mac_f32_e32 v37, v61, v34                                 ; 2c4a453d
	v_mac_f32_e32 v40, v49, v45                                 ; 2c505b31
	v_add_u32_e32 v49, s14, v0                                  ; 6862000e
	v_mad_f32 v3, -v51, v37, v3                                 ; d1c10003 240e4b33
	v_mov_b32_e32 v37, v48                                      ; 7e4a0330
	v_mac_f32_e32 v40, v41, v50                                 ; 2c506529
	v_lshlrev_b32_e32 v50, 4, v49                               ; 24646284
	v_lshl_add_u32 v49, v49, 7, v50                             ; d1fd0031 04c90f31
	v_add_u32_e32 v33, 16, v49                                  ; 68426290
	v_add_u32_e32 v34, v33, v4                                  ; 68440921
	v_add_u32_e32 v33, v33, v35                                 ; 68424721
	buffer_load_dwordx4 v[48:51], v49, s[24:27], 0 offen        ; e05c1000 80063031
	buffer_load_dword v34, v34, s[24:27], 0 offen               ; e0501000 80062222
	buffer_load_dword v33, v33, s[24:27], 0 offen               ; e0501000 80062121
	s_add_u32 s15, s16, 5                                       ; 800f8510
	s_waitcnt vmcnt(11)                                         ; bf8c3f7b
	v_bfe_u32 v55, v55, v2, 16                                  ; d1c80037 02420537
	v_bfe_u32 v53, v53, v2, 16                                  ; d1c80035 02420535
	v_lshlrev_b32_e32 v54, v5, v54                              ; 246c6d05
	v_cvt_f32_f16_e32 v37, v37                                  ; 7e4a1725
	s_waitcnt vmcnt(10)                                         ; bf8c3f7a
	v_and_b32_e32 v41, s11, v39                                 ; 26524e0b
	s_mul_i32 s15, s15, s3                                      ; 920f030f
	v_lshl_or_b32 v55, v55, 12, v55                             ; d2000037 04dd1937
	v_and_or_b32 v54, s10, v54, v53                             ; d2010036 04d66c0a
	v_mac_f32_e32 v3, v37, v40                                  ; 2c065125
	v_cvt_f32_ubyte2_e32 v45, v41                               ; 7e5a2729
	v_cvt_f32_ubyte3_e32 v44, v41                               ; 7e582929
	v_lshrrev_b32_e32 v39, 4, v39                               ; 204e4e84
	v_cvt_f32_ubyte1_e32 v53, v41                               ; 7e6a2529
	v_cvt_f32_ubyte0_e32 v41, v41                               ; 7e522329
	s_add_u32 s15, s18, s15                                     ; 800f0f12
	v_and_b32_e32 v40, s12, v54                                 ; 26506c0c
	v_mul_f32_e32 v44, v19, v44                                 ; 0a585913
	v_and_b32_e32 v39, s11, v39                                 ; 264e4e0b
	v_lshrrev_b32_e32 v40, 2, v40                               ; 20505082
	v_mac_f32_e32 v44, v18, v45                                 ; 2c585b12
	s_waitcnt vmcnt(9)                                          ; bf8c3f79
	v_and_b32_e32 v45, s11, v38                                 ; 265a4c0b
	v_cvt_f32_ubyte3_e32 v37, v39                               ; 7e4a2927
	v_and_or_b32 v55, s11, v55, v40                             ; d2010037 04a26e0b
	v_cvt_f32_ubyte2_e32 v40, v39                               ; 7e502727
	v_mac_f32_e32 v44, v17, v53                                 ; 2c586b11
	v_cvt_f32_ubyte3_e32 v53, v45                               ; 7e6a292d
	v_mul_f32_e32 v37, v23, v37                                 ; 0a4a4b17
	v_lshrrev_b32_e32 v38, 4, v38                               ; 204c4c84
	v_mac_f32_e32 v44, v16, v41                                 ; 2c585310
	v_cvt_f32_ubyte1_e32 v41, v39                               ; 7e522527
	v_cvt_f32_ubyte0_e32 v39, v39                               ; 7e4e2327
	v_mul_f32_e32 v53, v27, v53                                 ; 0a6a6b1b
	v_mac_f32_e32 v37, v22, v40                                 ; 2c4a5116
	v_cvt_f32_ubyte1_e32 v40, v45                               ; 7e50252d
	v_and_b32_e32 v38, s11, v38                                 ; 264c4c0b
	v_mac_f32_e32 v37, v21, v41                                 ; 2c4a5315
	v_cvt_f32_ubyte3_e32 v41, v38                               ; 7e522926
	v_mac_f32_e32 v37, v20, v39                                 ; 2c4a4f14
	v_cvt_f32_ubyte2_e32 v39, v45                               ; 7e4e272d
	v_cvt_f32_ubyte0_e32 v45, v45                               ; 7e5a232d
	v_mul_f32_e32 v41, v31, v41                                 ; 0a52531f
	v_and_b32_e32 v54, s13, v54                                 ; 266c6c0d
	v_mac_f32_e32 v53, v26, v39                                 ; 2c6a4f1a
	v_cvt_f32_ubyte1_e32 v39, v38                               ; 7e4e2526
	v_mac_f32_e32 v53, v25, v40                                 ; 2c6a5119
	v_cvt_f32_ubyte3_e32 v40, v55                               ; 7e502937
	v_mac_f32_e32 v53, v24, v45                                 ; 2c6a5b18
	v_cvt_f32_ubyte2_e32 v45, v38                               ; 7e5a2726
	v_cvt_f32_ubyte0_e32 v38, v38                               ; 7e4c2326
	v_mul_f32_e32 v40, v36, v40                                 ; 0a505124
	v_mac_f32_e32 v41, v30, v45                                 ; 2c525b1e
	v_cvt_f32_ubyte2_e32 v45, v55                               ; 7e5a2737
	v_mac_f32_e32 v41, v29, v39                                 ; 2c524f1d
	v_cvt_f32_ubyte2_e32 v39, v54                               ; 7e4e2736
	v_mac_f32_e32 v40, v32, v45                                 ; 2c505b20
	v_cvt_f32_ubyte1_e32 v45, v55                               ; 7e5a2537
	v_cvt_f32_ubyte0_e32 v55, v55                               ; 7e6e2337
	v_mac_f32_e32 v41, v28, v38                                 ; 2c524d1c
	v_cvt_f32_ubyte3_e32 v38, v54                               ; 7e4c2936
	v_mul_f32_e32 v41, v41, v45                                 ; 0a525b29
	v_mac_f32_e32 v40, v62, v38                                 ; 2c504d3e
	v_mac_f32_e32 v41, v53, v55                                 ; 2c526f35
	v_cvt_f32_ubyte1_e32 v53, v54                               ; 7e6a2536
	v_cvt_f32_ubyte0_e32 v54, v54                               ; 7e6c2336
	v_mac_f32_e32 v40, v61, v39                                 ; 2c504f3d
	v_mac_f32_e32 v41, v37, v53                                 ; 2c526b25
	v_mac_f32_e32 v41, v44, v54                                 ; 2c526d2c
	v_add_u32_e32 v54, s15, v0                                  ; 686c000f
	v_mov_b32_e32 v44, v36                                      ; 7e580324
	v_lshlrev_b32_e32 v55, 4, v54                               ; 246e6c84
	v_lshl_add_u32 v54, v54, 7, v55                             ; d1fd0036 04dd0f36
	buffer_load_dwordx4 v[36:39], v54, s[24:27], 0 offen        ; e05c1000 80062436
	v_cvt_f32_f16_sdwa v45, v52 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e5a16f9 00050634
	v_cvt_f32_f16_e32 v52, v52                                  ; 7e681734
	s_waitcnt vmcnt(9)                                          ; bf8c3f79
	v_bfe_u32 v59, v59, v2, 16                                  ; d1c8003b 0242053b
	v_bfe_u32 v57, v57, v2, 16                                  ; d1c80039 02420539
	v_lshlrev_b32_e32 v58, v5, v58                              ; 24747505
	s_waitcnt vmcnt(8)                                          ; bf8c3f78
	v_and_b32_e32 v53, s11, v43                                 ; 266a560b
	v_mad_f32 v6, -v45, v40, v6                                 ; d1c10006 241a512d
	v_lshl_or_b32 v59, v59, 12, v59                             ; d200003b 04ed193b
	v_and_or_b32 v58, s10, v58, v57                             ; d201003a 04e6740a
	v_lshrrev_b32_e32 v43, 4, v43                               ; 20565684
	v_cvt_f32_ubyte3_e32 v55, v53                               ; 7e6e2935
	v_cvt_f32_ubyte1_e32 v40, v53                               ; 7e502535
	v_add_u32_e32 v54, 16, v54                                  ; 686c6c90
	v_cvt_f32_ubyte2_e32 v57, v53                               ; 7e722735
	v_add_u32_e32 v45, v54, v4                                  ; 685a0936
	v_add_u32_e32 v54, v54, v35                                 ; 686c4736
	buffer_load_dword v45, v45, s[24:27], 0 offen               ; e0501000 80062d2d
	buffer_load_dword v54, v54, s[24:27], 0 offen               ; e0501000 80063636
	v_cvt_f32_ubyte0_e32 v53, v53                               ; 7e6a2335
	v_mac_f32_e32 v6, v52, v41                                  ; 2c0c5334
	v_and_b32_e32 v52, s12, v58                                 ; 2668740c
	v_and_b32_e32 v43, s11, v43                                 ; 2656560b
	v_mul_f32_e32 v55, v19, v55                                 ; 0a6e6f13
	v_lshrrev_b32_e32 v52, 2, v52                               ; 20686882
	v_cvt_f32_ubyte3_e32 v41, v43                               ; 7e52292b
	v_mac_f32_e32 v55, v18, v57                                 ; 2c6e7312
	s_waitcnt vmcnt(9)                                          ; bf8c3f79
	v_and_b32_e32 v57, s11, v42                                 ; 2672540b
	v_and_or_b32 v59, s11, v59, v52                             ; d201003b 04d2760b
	v_cvt_f32_ubyte2_e32 v52, v43                               ; 7e68272b
	v_mul_f32_e32 v41, v23, v41                                 ; 0a525317
	v_mac_f32_e32 v55, v17, v40                                 ; 2c6e5111
	v_cvt_f32_ubyte3_e32 v40, v57                               ; 7e502939
	v_lshrrev_b32_e32 v42, 4, v42                               ; 20545484
	v_mac_f32_e32 v41, v22, v52                                 ; 2c526916
	v_cvt_f32_ubyte1_e32 v52, v57                               ; 7e682539
	v_mac_f32_e32 v55, v16, v53                                 ; 2c6e6b10
	v_cvt_f32_ubyte1_e32 v53, v43                               ; 7e6a252b
	v_cvt_f32_ubyte0_e32 v43, v43                               ; 7e56232b
	v_mul_f32_e32 v40, v27, v40                                 ; 0a50511b
	v_and_b32_e32 v42, s11, v42                                 ; 2654540b
	v_mac_f32_e32 v41, v21, v53                                 ; 2c526b15
	v_cvt_f32_ubyte3_e32 v53, v42                               ; 7e6a292a
	v_mac_f32_e32 v41, v20, v43                                 ; 2c525714
	v_cvt_f32_ubyte2_e32 v43, v57                               ; 7e562739
	v_cvt_f32_ubyte0_e32 v57, v57                               ; 7e722339
	v_mul_f32_e32 v53, v31, v53                                 ; 0a6a6b1f
	v_and_b32_e32 v58, s13, v58                                 ; 2674740d
	v_mac_f32_e32 v40, v26, v43                                 ; 2c50571a
	v_cvt_f32_ubyte1_e32 v43, v42                               ; 7e56252a
	v_mac_f32_e32 v40, v25, v52                                 ; 2c506919
	v_cvt_f32_ubyte3_e32 v52, v59                               ; 7e68293b
	v_mac_f32_e32 v40, v24, v57                                 ; 2c507318
	v_cvt_f32_ubyte2_e32 v57, v42                               ; 7e72272a
	v_cvt_f32_ubyte0_e32 v42, v42                               ; 7e54232a
	v_mul_f32_e32 v52, v44, v52                                 ; 0a68692c
	v_mac_f32_e32 v53, v30, v57                                 ; 2c6a731e
	v_cvt_f32_ubyte2_e32 v57, v59                               ; 7e72273b
	v_mac_f32_e32 v53, v29, v43                                 ; 2c6a571d
	v_cvt_f32_ubyte2_e32 v43, v58                               ; 7e56273a
	v_mac_f32_e32 v52, v32, v57                                 ; 2c687320
	v_cvt_f32_ubyte1_e32 v57, v59                               ; 7e72253b
	v_cvt_f32_ubyte0_e32 v59, v59                               ; 7e76233b
	v_mac_f32_e32 v53, v28, v42                                 ; 2c6a551c
	v_cvt_f32_ubyte3_e32 v42, v58                               ; 7e54293a
	s_waitcnt vmcnt(8)                                          ; bf8c3f78
	v_bfe_u32 v15, v15, v2, 16                                  ; d1c8000f 0242050f
	v_bfe_u32 v13, v13, v2, 16                                  ; d1c8000d 0242050d
	v_lshlrev_b32_e32 v14, v5, v14                              ; 241c1d05
	v_mul_f32_e32 v53, v53, v57                                 ; 0a6a7335
	v_mac_f32_e32 v52, v62, v42                                 ; 2c68553e
	v_lshl_or_b32 v15, v15, 12, v15                             ; d200000f 043d190f
	v_and_or_b32 v14, s10, v14, v13                             ; d201000e 04361c0a
	s_waitcnt vmcnt(7)                                          ; bf8c3f77
	v_and_b32_e32 v42, s11, v47                                 ; 26545e0b
	v_mac_f32_e32 v53, v40, v59                                 ; 2c6a7728
	v_cvt_f32_ubyte1_e32 v59, v58                               ; 7e76253a
	v_cvt_f32_ubyte0_e32 v58, v58                               ; 7e74233a
	v_cvt_f32_f16_sdwa v40, v56 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e5016f9 00050638
	v_cvt_f32_f16_e32 v56, v56                                  ; 7e701738
	v_mac_f32_e32 v52, v61, v43                                 ; 2c68573d
	s_add_u32 s19, s16, 6                                       ; 80138610
	v_mac_f32_e32 v53, v41, v59                                 ; 2c6a7729
	v_mad_f32 v7, -v40, v52, v7                                 ; d1c10007 241e6928
	s_mul_i32 s19, s19, s3                                      ; 92130313
	v_mac_f32_e32 v53, v55, v58                                 ; 2c6a7537
	s_add_u32 s19, s18, s19                                     ; 80131312
	v_mac_f32_e32 v7, v56, v53                                  ; 2c0e6b38
	v_add_u32_e32 v52, s19, v0                                  ; 68680013
	v_lshlrev_b32_e32 v53, 4, v52                               ; 246a6884
	v_lshl_add_u32 v52, v52, 7, v53                             ; d1fd0034 04d50f34
	buffer_load_dwordx4 v[56:59], v52, s[24:27], 0 offen        ; e05c1000 80063834
	v_and_b32_e32 v41, s12, v14                                 ; 26521c0c
	v_cvt_f32_ubyte3_e32 v43, v42                               ; 7e56292a
	v_add_u32_e32 v52, 16, v52                                  ; 68686890
	v_cvt_f32_ubyte2_e32 v55, v42                               ; 7e6e272a
	v_lshrrev_b32_e32 v41, 2, v41                               ; 20525282
	v_and_or_b32 v15, s11, v15, v41                             ; d201000f 04a61e0b
	v_add_u32_e32 v41, v52, v4                                  ; 68520934
	v_add_u32_e32 v52, v52, v35                                 ; 68684734
	buffer_load_dword v41, v41, s[24:27], 0 offen               ; e0501000 80062929
	buffer_load_dword v52, v52, s[24:27], 0 offen               ; e0501000 80063434
	v_cvt_f32_ubyte1_e32 v13, v42                               ; 7e1a252a
	v_cvt_f32_ubyte0_e32 v42, v42                               ; 7e54232a
	v_lshrrev_b32_e32 v47, 4, v47                               ; 205e5e84
	v_mul_f32_e32 v43, v19, v43                                 ; 0a565713
	v_and_b32_e32 v47, s11, v47                                 ; 265e5e0b
	v_mac_f32_e32 v43, v18, v55                                 ; 2c566f12
	s_waitcnt vmcnt(9)                                          ; bf8c3f79
	v_and_b32_e32 v55, s11, v46                                 ; 266e5c0b
	v_cvt_f32_ubyte1_e32 v53, v47                               ; 7e6a252f
	v_cvt_f32_ubyte3_e32 v40, v47                               ; 7e50292f
	v_mac_f32_e32 v43, v17, v13                                 ; 2c561b11
	v_cvt_f32_ubyte3_e32 v13, v55                               ; 7e1a2937
	v_mul_f32_e32 v40, v23, v40                                 ; 0a505117
	v_lshrrev_b32_e32 v46, 4, v46                               ; 205c5c84
	v_mac_f32_e32 v43, v16, v42                                 ; 2c565510
	v_cvt_f32_ubyte2_e32 v42, v47                               ; 7e54272f
	v_cvt_f32_ubyte0_e32 v47, v47                               ; 7e5e232f
	v_mul_f32_e32 v13, v27, v13                                 ; 0a1a1b1b
	v_and_b32_e32 v46, s11, v46                                 ; 265c5c0b
	v_mac_f32_e32 v40, v22, v42                                 ; 2c505516
	v_cvt_f32_ubyte2_e32 v42, v55                               ; 7e542737
	v_mac_f32_e32 v40, v21, v53                                 ; 2c506b15
	v_cvt_f32_ubyte3_e32 v53, v46                               ; 7e6a292e
	v_mac_f32_e32 v13, v26, v42                                 ; 2c1a551a
	v_cvt_f32_ubyte1_e32 v42, v46                               ; 7e54252e
	v_mac_f32_e32 v40, v20, v47                                 ; 2c505f14
	v_cvt_f32_ubyte1_e32 v47, v55                               ; 7e5e2537
	v_cvt_f32_ubyte0_e32 v55, v55                               ; 7e6e2337
	v_mul_f32_e32 v53, v31, v53                                 ; 0a6a6b1f
	v_and_b32_e32 v14, s13, v14                                 ; 261c1c0d
	v_mac_f32_e32 v13, v25, v47                                 ; 2c1a5f19
	v_cvt_f32_ubyte2_e32 v47, v15                               ; 7e5e270f
	v_mac_f32_e32 v13, v24, v55                                 ; 2c1a6f18
	v_cvt_f32_ubyte2_e32 v55, v46                               ; 7e6e272e
	v_cvt_f32_ubyte0_e32 v46, v46                               ; 7e5c232e
	v_mac_f32_e32 v53, v30, v55                                 ; 2c6a6f1e
	v_cvt_f32_ubyte3_e32 v55, v14                               ; 7e6e290e
	v_mac_f32_e32 v53, v29, v42                                 ; 2c6a551d
	v_cvt_f32_ubyte2_e32 v42, v14                               ; 7e54270e
	v_mac_f32_e32 v53, v28, v46                                 ; 2c6a5d1c
	v_cvt_f32_ubyte3_e32 v46, v15                               ; 7e5c290f
	v_mul_f32_e32 v46, v44, v46                                 ; 0a5c5d2c
	s_waitcnt vmcnt(8)                                          ; bf8c3f78
	v_bfe_u32 v51, v51, v2, 16                                  ; d1c80033 02420533
	v_bfe_u32 v49, v49, v2, 16                                  ; d1c80031 02420531
	v_mac_f32_e32 v46, v32, v47                                 ; 2c5c5f20
	v_cvt_f32_ubyte1_e32 v47, v15                               ; 7e5e250f
	v_cvt_f32_ubyte0_e32 v15, v15                               ; 7e1e230f
	v_lshlrev_b32_e32 v50, v5, v50                              ; 24646505
	v_mac_f32_e32 v46, v62, v55                                 ; 2c5c6f3e
	v_cvt_f32_ubyte1_e32 v55, v14                               ; 7e6e250e
	v_cvt_f32_ubyte0_e32 v14, v14                               ; 7e1c230e
	v_lshl_or_b32 v51, v51, 12, v51                             ; d2000033 04cd1933
	v_mul_f32_e32 v53, v53, v47                                 ; 0a6a5f35
	v_and_or_b32 v50, s10, v50, v49                             ; d2010032 04c6640a
	v_mac_f32_e32 v46, v61, v42                                 ; 2c5c553d
	s_add_u32 s20, s16, 7                                       ; 80148710
	v_mac_f32_e32 v53, v13, v15                                 ; 2c6a1f0d
	v_cvt_f32_f16_sdwa v13, v12 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e1a16f9 0005060c
	v_cvt_f32_f16_e32 v12, v12                                  ; 7e18170c
	s_waitcnt vmcnt(7)                                          ; bf8c3f77
	v_and_b32_e32 v15, s11, v34                                 ; 261e440b
	s_mul_i32 s20, s20, s3                                      ; 92140314
	v_mac_f32_e32 v53, v40, v55                                 ; 2c6a6f28
	v_mad_f32 v8, -v13, v46, v8                                 ; d1c10008 24225d0d
	v_mov_b32_e32 v46, v15                                      ; 7e5c030f
	v_cvt_f32_ubyte3_e32 v40, v15                               ; 7e50290f
	s_add_u32 s20, s18, s20                                     ; 80141412
	v_mac_f32_e32 v53, v43, v14                                 ; 2c6a1d2b
	v_and_b32_e32 v14, s12, v50                                 ; 261c640c
	v_add_u32_e32 v42, s20, v0                                  ; 68540014
	v_mac_f32_e32 v8, v12, v53                                  ; 2c106b0c
	v_lshrrev_b32_e32 v14, 2, v14                               ; 201c1c82
	v_lshlrev_b32_e32 v43, 4, v42                               ; 24565484
	v_and_or_b32 v51, s11, v51, v14                             ; d2010033 043a660b
	v_lshl_add_u32 v42, v42, 7, v43                             ; d1fd002a 04ad0f2a
	buffer_load_dwordx4 v[12:15], v42, s[24:27], 0 offen        ; e05c1000 80060c2a
	v_add_u32_e32 v42, 16, v42                                  ; 68545490
	v_add_u32_e32 v55, v42, v4                                  ; 686e092a
	v_add_u32_e32 v42, v42, v35                                 ; 6854472a
	buffer_load_dword v55, v55, s[24:27], 0 offen               ; e0501000 80063737
	buffer_load_dword v42, v42, s[24:27], 0 offen               ; e0501000 80062a2a
	v_cvt_f32_ubyte1_e32 v49, v46                               ; 7e62252e
	v_cvt_f32_ubyte2_e32 v47, v46                               ; 7e5e272e
	v_cvt_f32_ubyte0_e32 v46, v46                               ; 7e5c232e
	v_mul_f32_e32 v40, v19, v40                                 ; 0a505113
	v_lshrrev_b32_e32 v34, 4, v34                               ; 20444484
	v_mac_f32_e32 v40, v18, v47                                 ; 2c505f12
	v_and_b32_e32 v34, s11, v34                                 ; 2644440b
	v_mac_f32_e32 v40, v17, v49                                 ; 2c506311
	v_cvt_f32_ubyte1_e32 v43, v34                               ; 7e562522
	v_cvt_f32_ubyte3_e32 v53, v34                               ; 7e6a2922
	v_cvt_f32_ubyte2_e32 v35, v34                               ; 7e462722
	v_cvt_f32_ubyte0_e32 v34, v34                               ; 7e442322
	v_mac_f32_e32 v40, v16, v46                                 ; 2c505d10
	s_waitcnt vmcnt(9)                                          ; bf8c3f79
	v_and_b32_e32 v46, s11, v33                                 ; 265c420b
	v_mul_f32_e32 v53, v23, v53                                 ; 0a6a6b17
	v_lshrrev_b32_e32 v33, 4, v33                               ; 20424284
	v_cvt_f32_ubyte3_e32 v47, v46                               ; 7e5e292e
	v_cvt_f32_ubyte2_e32 v49, v46                               ; 7e62272e
	v_mac_f32_e32 v53, v22, v35                                 ; 2c6a4716
	v_and_b32_e32 v33, s11, v33                                 ; 2642420b
	v_mul_f32_e32 v47, v27, v47                                 ; 0a5e5f1b
	v_mac_f32_e32 v53, v21, v43                                 ; 2c6a5715
	v_cvt_f32_ubyte2_e32 v43, v33                               ; 7e562721
	v_cvt_f32_ubyte3_e32 v35, v33                               ; 7e462921
	v_mac_f32_e32 v47, v26, v49                                 ; 2c5e631a
	v_cvt_f32_ubyte3_e32 v49, v51                               ; 7e622933
	v_mac_f32_e32 v53, v20, v34                                 ; 2c6a4514
	v_cvt_f32_ubyte1_e32 v34, v46                               ; 7e44252e
	v_cvt_f32_ubyte0_e32 v46, v46                               ; 7e5c232e
	v_mul_f32_e32 v35, v31, v35                                 ; 0a46471f
	v_and_b32_e32 v50, s13, v50                                 ; 2664640d
	v_mul_f32_e32 v49, v44, v49                                 ; 0a62632c
	v_mac_f32_e32 v47, v25, v34                                 ; 2c5e4519
	v_mac_f32_e32 v35, v30, v43                                 ; 2c46571e
	v_cvt_f32_ubyte3_e32 v34, v50                               ; 7e442932
	v_cvt_f32_ubyte2_e32 v43, v50                               ; 7e562732
	v_mac_f32_e32 v47, v24, v46                                 ; 2c5e5d18
	v_cvt_f32_ubyte1_e32 v46, v33                               ; 7e5c2521
	v_cvt_f32_ubyte0_e32 v33, v33                               ; 7e422321
	v_mac_f32_e32 v35, v29, v46                                 ; 2c465d1d
	v_cvt_f32_ubyte1_e32 v46, v51                               ; 7e5c2533
	v_mac_f32_e32 v35, v28, v33                                 ; 2c46431c
	v_cvt_f32_ubyte2_e32 v33, v51                               ; 7e422733
	v_cvt_f32_ubyte0_e32 v51, v51                               ; 7e662333
	s_waitcnt vmcnt(8)                                          ; bf8c3f78
	v_bfe_u32 v39, v39, v2, 16                                  ; d1c80027 02420527
	v_bfe_u32 v37, v37, v2, 16                                  ; d1c80025 02420525
	v_mul_f32_e32 v35, v35, v46                                 ; 0a465d23
	v_mac_f32_e32 v49, v32, v33                                 ; 2c624320
	v_lshlrev_b32_e32 v38, v5, v38                              ; 244c4d05
	v_lshl_or_b32 v39, v39, 12, v39                             ; d2000027 049d1927
	v_mac_f32_e32 v35, v47, v51                                 ; 2c46672f
	v_cvt_f32_ubyte1_e32 v47, v50                               ; 7e5e2532
	v_cvt_f32_ubyte0_e32 v50, v50                               ; 7e642332
	v_mac_f32_e32 v49, v62, v34                                 ; 2c62453e
	v_and_or_b32 v38, s10, v38, v37                             ; d2010026 04964c0a
	v_mac_f32_e32 v35, v53, v47                                 ; 2c465f35
	s_waitcnt vmcnt(7)                                          ; bf8c3f77
	v_and_b32_e32 v53, s11, v45                                 ; 266a5a0b
	v_mac_f32_e32 v49, v61, v43                                 ; 2c62573d
	v_and_b32_e32 v51, s12, v38                                 ; 26664c0c
	v_mac_f32_e32 v35, v40, v50                                 ; 2c466528
	v_cvt_f32_f16_sdwa v50, v48 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e6416f9 00050630
	v_cvt_f32_f16_e32 v48, v48                                  ; 7e601730
	v_cvt_f32_ubyte3_e32 v33, v53                               ; 7e422935
	v_cvt_f32_ubyte2_e32 v34, v53                               ; 7e442735
	v_lshrrev_b32_e32 v45, 4, v45                               ; 205a5a84
	v_lshrrev_b32_e32 v51, 2, v51                               ; 20666682
	v_mad_f32 v9, -v50, v49, v9                                 ; d1c10009 24266332
	v_mul_f32_e32 v33, v19, v33                                 ; 0a424313
	v_and_b32_e32 v45, s11, v45                                 ; 265a5a0b
	v_and_or_b32 v39, s11, v39, v51                             ; d2010027 04ce4e0b
	v_mac_f32_e32 v9, v48, v35                                  ; 2c124730
	v_cvt_f32_ubyte1_e32 v35, v53                               ; 7e462535
	v_cvt_f32_ubyte0_e32 v53, v53                               ; 7e6a2335
	v_mac_f32_e32 v33, v18, v34                                 ; 2c424512
	v_cvt_f32_ubyte2_e32 v40, v45                               ; 7e50272d
	v_cvt_f32_ubyte3_e32 v37, v45                               ; 7e4a292d
	v_cvt_f32_ubyte1_e32 v43, v45                               ; 7e56252d
	v_cvt_f32_ubyte0_e32 v45, v45                               ; 7e5a232d
	v_mac_f32_e32 v33, v17, v35                                 ; 2c424711
	v_mul_f32_e32 v37, v23, v37                                 ; 0a4a4b17
	v_mac_f32_e32 v33, v16, v53                                 ; 2c426b10
	v_mac_f32_e32 v37, v22, v40                                 ; 2c4a5116
	v_mac_f32_e32 v37, v21, v43                                 ; 2c4a5715
	v_mac_f32_e32 v37, v20, v45                                 ; 2c4a5b14
	s_waitcnt vmcnt(6)                                          ; bf8c3f76
	v_and_b32_e32 v45, s11, v54                                 ; 265a6c0b
	v_lshrrev_b32_e32 v54, 4, v54                               ; 206c6c84
	v_cvt_f32_ubyte1_e32 v48, v45                               ; 7e60252d
	v_cvt_f32_ubyte2_e32 v47, v45                               ; 7e5e272d
	v_cvt_f32_ubyte3_e32 v46, v45                               ; 7e5c292d
	v_cvt_f32_ubyte0_e32 v45, v45                               ; 7e5a232d
	v_and_b32_e32 v54, s11, v54                                 ; 266c6c0b
	v_cvt_f32_ubyte3_e32 v53, v39                               ; 7e6a2927
	v_mul_f32_e32 v46, v27, v46                                 ; 0a5c5d1b
	v_and_b32_e32 v38, s13, v38                                 ; 264c4c0d
	v_cvt_f32_ubyte2_e32 v50, v54                               ; 7e642736
	v_cvt_f32_ubyte3_e32 v49, v54                               ; 7e622936
	v_cvt_f32_ubyte1_e32 v51, v54                               ; 7e662536
	v_cvt_f32_ubyte0_e32 v54, v54                               ; 7e6c2336
	v_mul_f32_e32 v53, v44, v53                                 ; 0a6a6b2c
	v_mac_f32_e32 v46, v26, v47                                 ; 2c5c5f1a
	v_cvt_f32_ubyte2_e32 v35, v38                               ; 7e462726
	v_cvt_f32_ubyte3_e32 v34, v38                               ; 7e442926
	v_mul_f32_e32 v49, v31, v49                                 ; 0a62631f
	v_cvt_f32_ubyte1_e32 v40, v39                               ; 7e502527
	v_mac_f32_e32 v46, v25, v48                                 ; 2c5c6119
	v_cvt_f32_ubyte1_e32 v43, v38                               ; 7e562526
	v_cvt_f32_ubyte0_e32 v38, v38                               ; 7e4c2326
	v_mac_f32_e32 v49, v30, v50                                 ; 2c62651e
	v_mac_f32_e32 v46, v24, v45                                 ; 2c5c5b18
	v_cvt_f32_f16_sdwa v45, v36 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e5a16f9 00050624
	v_cvt_f32_f16_e32 v36, v36                                  ; 7e481724
	v_mac_f32_e32 v49, v29, v51                                 ; 2c62671d
	s_waitcnt vmcnt(5)                                          ; bf8c3f75
	v_bfe_u32 v59, v59, v2, 16                                  ; d1c8003b 0242053b
	v_bfe_u32 v57, v57, v2, 16                                  ; d1c80039 02420539
	v_lshlrev_b32_e32 v58, v5, v58                              ; 24747505
	v_mac_f32_e32 v49, v28, v54                                 ; 2c626d1c
	v_cvt_f32_ubyte2_e32 v54, v39                               ; 7e6c2727
	v_cvt_f32_ubyte0_e32 v39, v39                               ; 7e4e2327
	v_lshl_or_b32 v59, v59, 12, v59                             ; d200003b 04ed193b
	v_and_or_b32 v58, s10, v58, v57                             ; d201003a 04e6740a
	v_mul_f32_e32 v49, v49, v40                                 ; 0a625131
	s_waitcnt vmcnt(4)                                          ; bf8c3f74
	v_and_b32_e32 v47, s11, v41                                 ; 265e520b
	v_mac_f32_e32 v53, v32, v54                                 ; 2c6a6d20
	v_mac_f32_e32 v49, v46, v39                                 ; 2c624f2e
	v_and_b32_e32 v46, s12, v58                                 ; 265c740c
	v_cvt_f32_ubyte1_e32 v50, v47                               ; 7e64252f
	v_cvt_f32_ubyte3_e32 v48, v47                               ; 7e60292f
	v_mac_f32_e32 v53, v62, v34                                 ; 2c6a453e
	v_mac_f32_e32 v49, v37, v43                                 ; 2c625725
	v_lshrrev_b32_e32 v46, 2, v46                               ; 205c5c82
	v_lshrrev_b32_e32 v41, 4, v41                               ; 20525284
	v_mul_f32_e32 v48, v19, v48                                 ; 0a606113
	v_mac_f32_e32 v53, v61, v35                                 ; 2c6a473d
	v_mac_f32_e32 v49, v33, v38                                 ; 2c624d21
	v_and_or_b32 v59, s11, v59, v46                             ; d201003b 04ba760b
	v_and_b32_e32 v41, s11, v41                                 ; 2652520b
	v_mad_f32 v10, -v45, v53, v10                               ; d1c1000a 242a6b2d
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_and_b32_e32 v57, s11, v52                                 ; 2672680b
	v_cvt_f32_ubyte2_e32 v53, v41                               ; 7e6a2729
	v_cvt_f32_ubyte3_e32 v51, v41                               ; 7e662929
	v_cvt_f32_ubyte1_e32 v54, v41                               ; 7e6c2529
	v_cvt_f32_ubyte0_e32 v41, v41                               ; 7e522329
	v_mac_f32_e32 v10, v36, v49                                 ; 2c146324
	v_cvt_f32_ubyte2_e32 v49, v47                               ; 7e62272f
	v_cvt_f32_ubyte0_e32 v47, v47                               ; 7e5e232f
	v_cvt_f32_ubyte2_e32 v34, v57                               ; 7e442739
	v_cvt_f32_ubyte3_e32 v33, v57                               ; 7e422939
	v_mul_f32_e32 v51, v23, v51                                 ; 0a666717
	v_cvt_f32_ubyte1_e32 v35, v57                               ; 7e462539
	v_cvt_f32_ubyte0_e32 v57, v57                               ; 7e722339
	v_mac_f32_e32 v48, v18, v49                                 ; 2c606312
	v_lshrrev_b32_e32 v52, 4, v52                               ; 20686884
	v_mul_f32_e32 v33, v27, v33                                 ; 0a42431b
	v_mac_f32_e32 v51, v22, v53                                 ; 2c666b16
	v_mac_f32_e32 v48, v17, v50                                 ; 2c606511
	v_and_b32_e32 v52, s11, v52                                 ; 2668680b
	v_mac_f32_e32 v33, v26, v34                                 ; 2c42451a
	v_cvt_f32_ubyte3_e32 v39, v59                               ; 7e4e293b
	v_mac_f32_e32 v51, v21, v54                                 ; 2c666d15
	v_mac_f32_e32 v48, v16, v47                                 ; 2c605f10
	v_cvt_f32_ubyte1_e32 v38, v52                               ; 7e4c2534
	v_cvt_f32_ubyte2_e32 v40, v59                               ; 7e50273b
	v_cvt_f32_ubyte3_e32 v36, v52                               ; 7e482934
	v_cvt_f32_ubyte2_e32 v37, v52                               ; 7e4a2734
	v_cvt_f32_ubyte0_e32 v52, v52                               ; 7e682334
	v_mac_f32_e32 v33, v25, v35                                 ; 2c424719
	v_mul_f32_e32 v39, v44, v39                                 ; 0a4e4f2c
	v_and_b32_e32 v58, s13, v58                                 ; 2674740d
	v_mac_f32_e32 v51, v20, v41                                 ; 2c665314
	v_mul_f32_e32 v36, v31, v36                                 ; 0a48491f
	v_cvt_f32_ubyte1_e32 v45, v59                               ; 7e5a253b
	v_cvt_f32_ubyte0_e32 v59, v59                               ; 7e76233b
	v_mac_f32_e32 v33, v24, v57                                 ; 2c427318
	v_mac_f32_e32 v39, v32, v40                                 ; 2c4e5120
	v_cvt_f32_ubyte3_e32 v41, v58                               ; 7e52293a
	v_cvt_f32_ubyte2_e32 v43, v58                               ; 7e56273a
	v_cvt_f32_ubyte1_e32 v46, v58                               ; 7e5c253a
	v_cvt_f32_ubyte0_e32 v58, v58                               ; 7e74233a
	v_mac_f32_e32 v36, v30, v37                                 ; 2c484b1e
	v_cvt_f32_f16_sdwa v47, v56 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e5e16f9 00050638
	v_cvt_f32_f16_e32 v56, v56                                  ; 7e701738
	v_mac_f32_e32 v39, v62, v41                                 ; 2c4e533e
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_bfe_u32 v15, v15, v2, 16                                  ; d1c8000f 0242050f
	v_bfe_u32 v13, v13, v2, 16                                  ; d1c8000d 0242050d
	v_lshlrev_b32_e32 v14, v5, v14                              ; 241c1d05
	v_mac_f32_e32 v36, v29, v38                                 ; 2c484d1d
	v_mac_f32_e32 v39, v61, v43                                 ; 2c4e573d
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v49, s11, v55                                 ; 26626e0b
	v_lshl_or_b32 v15, v15, 12, v15                             ; d200000f 043d190f
	v_and_or_b32 v14, s10, v14, v13                             ; d201000e 04361c0a
	v_mac_f32_e32 v36, v28, v52                                 ; 2c48691c
	v_mad_f32 v11, -v47, v39, v11                               ; d1c1000b 242e4f2f
	v_cvt_f32_ubyte3_e32 v50, v49                               ; 7e642931
	v_cvt_f32_ubyte1_e32 v52, v49                               ; 7e682531
	v_mul_f32_e32 v36, v36, v45                                 ; 0a485b24
	v_lshrrev_b32_e32 v55, 4, v55                               ; 206e6e84
	v_mul_f32_e32 v19, v19, v50                                 ; 0a266513
	v_mac_f32_e32 v36, v33, v59                                 ; 2c487721
	v_and_b32_e32 v55, s11, v55                                 ; 266e6e0b
	v_mac_f32_e32 v36, v51, v46                                 ; 2c485d33
	v_cvt_f32_ubyte2_e32 v51, v49                               ; 7e662731
	v_cvt_f32_ubyte0_e32 v49, v49                               ; 7e622331
	v_cvt_f32_ubyte2_e32 v54, v55                               ; 7e6c2737
	v_cvt_f32_ubyte3_e32 v53, v55                               ; 7e6a2937
	v_mac_f32_e32 v36, v48, v58                                 ; 2c487530
	v_and_b32_e32 v48, s12, v14                                 ; 26601c0c
	v_mac_f32_e32 v19, v18, v51                                 ; 2c266712
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v57, s11, v42                                 ; 2672540b
	v_mul_f32_e32 v23, v23, v53                                 ; 0a2e6b17
	v_mac_f32_e32 v11, v56, v36                                 ; 2c164938
	v_cvt_f32_ubyte1_e32 v56, v55                               ; 7e702537
	v_cvt_f32_ubyte0_e32 v55, v55                               ; 7e6e2337
	v_lshrrev_b32_e32 v48, 2, v48                               ; 20606082
	v_mac_f32_e32 v19, v17, v52                                 ; 2c266911
	v_cvt_f32_ubyte2_e32 v59, v57                               ; 7e762739
	v_cvt_f32_ubyte1_e32 v13, v57                               ; 7e1a2539
	v_cvt_f32_ubyte3_e32 v58, v57                               ; 7e742939
	v_mac_f32_e32 v23, v22, v54                                 ; 2c2e6d16
	v_cvt_f32_ubyte0_e32 v57, v57                               ; 7e722339
	v_lshrrev_b32_e32 v42, 4, v42                               ; 20545484
	v_and_or_b32 v15, s11, v15, v48                             ; d201000f 04c21e0b
	v_mac_f32_e32 v19, v16, v49                                 ; 2c266310
	v_mul_f32_e32 v27, v27, v58                                 ; 0a36751b
	v_mac_f32_e32 v23, v21, v56                                 ; 2c2e7115
	v_and_b32_e32 v42, s11, v42                                 ; 2654540b
	v_cvt_f32_ubyte2_e32 v21, v15                               ; 7e2a270f
	v_mac_f32_e32 v27, v26, v59                                 ; 2c36771a
	v_mac_f32_e32 v23, v20, v55                                 ; 2c2e6f14
	v_cvt_f32_ubyte3_e32 v20, v15                               ; 7e28290f
	v_and_b32_e32 v14, s13, v14                                 ; 261c1c0d
	v_cvt_f32_ubyte1_e32 v18, v42                               ; 7e24252a
	v_cvt_f32_ubyte2_e32 v17, v42                               ; 7e22272a
	v_cvt_f32_ubyte3_e32 v16, v42                               ; 7e20292a
	v_cvt_f32_ubyte0_e32 v42, v42                               ; 7e54232a
	v_mac_f32_e32 v27, v25, v13                                 ; 2c361b19
	v_mul_f32_e32 v44, v44, v20                                 ; 0a58292c
	v_cvt_f32_ubyte1_e32 v25, v15                               ; 7e32250f
	v_cvt_f32_ubyte3_e32 v22, v14                               ; 7e2c290e
	v_cvt_f32_ubyte0_e32 v15, v15                               ; 7e1e230f
	v_mul_f32_e32 v31, v31, v16                                 ; 0a3e211f
	v_cvt_f32_ubyte1_e32 v26, v14                               ; 7e34250e
	v_mac_f32_e32 v27, v24, v57                                 ; 2c367318
	v_cvt_f32_ubyte2_e32 v24, v14                               ; 7e30270e
	v_cvt_f32_ubyte0_e32 v14, v14                               ; 7e1c230e
	v_mac_f32_e32 v44, v32, v21                                 ; 2c582b20
	v_mac_f32_e32 v31, v30, v17                                 ; 2c3e231e
	v_add_u32_e32 v0, 4, v0                                     ; 68000084
	v_mac_f32_e32 v44, v62, v22                                 ; 2c582d3e
	v_mac_f32_e32 v31, v29, v18                                 ; 2c3e251d
	v_mac_f32_e32 v44, v61, v24                                 ; 2c58313d
	v_mac_f32_e32 v31, v28, v42                                 ; 2c3e551c
	v_mul_f32_e32 v31, v31, v25                                 ; 0a3e331f
	v_mac_f32_e32 v31, v27, v15                                 ; 2c3e1f1b
	v_cvt_f32_f16_sdwa v27, v12 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e3616f9 0005060c
	v_cvt_f32_f16_e32 v12, v12                                  ; 7e18170c
	v_mac_f32_e32 v31, v23, v26                                 ; 2c3e3517
	v_mad_f32 v27, -v27, v44, v60                               ; d1c1001b 24f2591b
	v_mac_f32_e32 v31, v19, v14                                 ; 2c3e1d13
	v_mad_f32 v12, v12, v31, v27                                ; d1c1000c 046e3f0c
BB5:
	s_mov_b64 s[0:1], exec                                      ; be80017e
	v_cmpx_le_u32_e32 vcc, s3, v0                               ; 7db60003
BB6:
	s_andn2_b64 s[0:1], s[0:1], exec                            ; 89807e00
	s_cbranch_scc1 BB10                                         ; bf85fcde
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
	s_branch BB203                                              ; bf820593
BB66:
	s_cmp_lt_u32 s16, s4                                        ; bf0a0410
	s_cbranch_scc0 BB203                                        ; bf840591
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
	s_mul_i32 s19, s19, s5                                      ; 92130513
	v_mov_b32_e32 v7, 0                                         ; 7e0e0280
	v_mov_b32_e32 v8, 0                                         ; 7e100280
	v_sub_u32_e32 v1, v2, v1                                    ; 6a020302
	v_bfe_u32 v3, v2, 2, 1                                      ; d1c80003 02050502
	v_lshrrev_b32_e32 v2, 3, v2                                 ; 20040483
	v_mov_b32_e32 v9, 0                                         ; 7e120280
	v_mov_b32_e32 v10, 0                                        ; 7e140280
	v_mov_b32_e32 v11, 0                                        ; 7e160280
	v_mov_b32_e32 v12, 0                                        ; 7e180280
	v_lshl_add_u32 v1, v1, 1, v3                                ; d1fd0001 040d0301
	v_mov_b32_e32 v3, 0                                         ; 7e060280
	v_lshlrev_b32_e32 v1, 2, v1                                 ; 24020282
	v_lshl_add_u32 v4, v2, 5, v1                                ; d1fd0004 04050b02
	v_lshl_add_u32 v1, v2, 6, v1                                ; d1fd0001 04050d02
	v_lshlrev_b32_e32 v2, 4, v2                                 ; 24040484
	v_sub_u32_e32 v5, 16, v2                                    ; 6a0a0490
BB71:
	s_mov_b64 s[0:1], exec                                      ; be80017e
	v_cmpx_le_u32_e32 vcc, s3, v0                               ; 7db60003
BB72:
	s_andn2_b64 s[0:1], s[0:1], exec                            ; 89807e00
	s_cbranch_scc0 BB101                                        ; bf84034e
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
	s_cbranch_scc0 BB100                                        ; bf840321
BB77:
	s_load_dwordx4 s[12:15], s[0:1], 0x0                        ; c00a0300 00000000
	s_mul_i32 s0, s16, s3                                       ; 92000310
	v_add_u32_e32 v37, 64, v4                                   ; 684a08c0
	s_add_u32 s0, s19, s0                                       ; 80000013
	v_add_u32_e32 v13, s0, v0                                   ; 681a0000
	v_lshlrev_b32_e32 v14, 4, v13                               ; 241c1a84
	v_lshl_add_u32 v13, v13, 7, v14                             ; d1fd000d 04390f0d
	v_add_u32_e32 v35, 16, v13                                  ; 68461a90
	v_add_u32_e32 v36, v35, v4                                  ; 68480923
	v_add_u32_e32 v35, v35, v37                                 ; 68464b23
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_load_dwordx4 v[40:43], v13, s[12:15], 0 offen        ; e05c1000 8003280d
	buffer_load_dword v36, v36, s[12:15], 0 offen               ; e0501000 80032424
	buffer_load_dword v35, v35, s[12:15], 0 offen               ; e0501000 80032323
	s_bfm_b32 s1, 16, 16                                        ; 91019090
	s_mov_b32 s5, 0xf0f0f0f                                     ; be8500ff 0f0f0f0f
	s_cmp_lt_u32 1, s4                                          ; bf0a0481
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_bfe_u32 v43, v43, v2, 16                                  ; d1c8002b 0242052b
	v_bfe_u32 v41, v41, v2, 16                                  ; d1c80029 02420529
	v_lshlrev_b32_e32 v42, v5, v42                              ; 24545505
	v_lshl_or_b32 v43, v43, 12, v43                             ; d200002b 04ad192b
	v_and_or_b32 v42, s1, v42, v41                              ; d201002a 04a65401
	v_and_b32_e32 v38, 0xc0c0c0c0, v42                          ; 264c54ff c0c0c0c0
	v_and_b32_e32 v42, 0x3f3f3f3f, v42                          ; 265454ff 3f3f3f3f
	v_cvt_f32_f16_sdwa v48, v40 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e6016f9 00050628
	v_lshrrev_b32_e32 v38, 2, v38                               ; 204c4c82
	v_cvt_f32_ubyte1_e32 v47, v42                               ; 7e5e252a
	v_cvt_f32_f16_e32 v40, v40                                  ; 7e501728
	v_cvt_f32_ubyte3_e32 v44, v42                               ; 7e58292a
	v_cvt_f32_ubyte2_e32 v45, v42                               ; 7e5a272a
	v_cvt_f32_ubyte0_e32 v42, v42                               ; 7e54232a
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v49, s5, v36                                  ; 26624805
	v_and_or_b32 v43, s5, v43, v38                              ; d201002b 049a5605
	v_cvt_f32_ubyte1_e32 v52, v49                               ; 7e682531
	v_cvt_f32_ubyte3_e32 v50, v49                               ; 7e642931
	v_cvt_f32_ubyte2_e32 v51, v49                               ; 7e662731
	v_cvt_f32_ubyte0_e32 v49, v49                               ; 7e622331
	v_cvt_f32_ubyte1_e32 v46, v43                               ; 7e5c252b
	v_cvt_f32_ubyte3_e32 v39, v43                               ; 7e4e292b
	v_cvt_f32_ubyte2_e32 v41, v43                               ; 7e52272b
	v_cvt_f32_ubyte0_e32 v43, v43                               ; 7e56232b
	v_lshrrev_b32_e32 v36, 4, v36                               ; 20484884
	v_mul_f32_e32 v50, v19, v50                                 ; 0a646513
	v_mul_f32_e32 v39, v34, v39                                 ; 0a4e4f22
	v_and_b32_e32 v36, s5, v36                                  ; 26484805
	v_mac_f32_e32 v50, v18, v51                                 ; 2c646712
	v_mac_f32_e32 v39, v33, v41                                 ; 2c4e5321
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v56, s5, v35                                  ; 26704605
	v_cvt_f32_ubyte3_e32 v53, v36                               ; 7e6a2924
	v_cvt_f32_ubyte2_e32 v54, v36                               ; 7e6c2724
	v_cvt_f32_ubyte1_e32 v55, v36                               ; 7e6e2524
	v_cvt_f32_ubyte0_e32 v36, v36                               ; 7e482324
	v_mac_f32_e32 v50, v17, v52                                 ; 2c646911
	v_mac_f32_e32 v39, v32, v44                                 ; 2c4e5920
	v_cvt_f32_ubyte2_e32 v58, v56                               ; 7e742738
	v_cvt_f32_ubyte3_e32 v57, v56                               ; 7e722938
	v_mul_f32_e32 v53, v23, v53                                 ; 0a6a6b17
	v_cvt_f32_ubyte1_e32 v59, v56                               ; 7e762538
	v_cvt_f32_ubyte0_e32 v56, v56                               ; 7e702338
	v_mac_f32_e32 v50, v16, v49                                 ; 2c646310
	v_lshrrev_b32_e32 v35, 4, v35                               ; 20464684
	v_mac_f32_e32 v39, v15, v45                                 ; 2c4e5b0f
	v_mul_f32_e32 v57, v27, v57                                 ; 0a72731b
	v_mac_f32_e32 v53, v22, v54                                 ; 2c6a6d16
	v_and_b32_e32 v35, s5, v35                                  ; 26464605
	v_mad_f32 v3, -v48, v39, v3                                 ; d1c10003 240e4f30
	v_mac_f32_e32 v57, v26, v58                                 ; 2c72751a
	v_mac_f32_e32 v53, v21, v55                                 ; 2c6a6f15
	v_cvt_f32_ubyte1_e32 v62, v35                               ; 7e7c2523
	v_cvt_f32_ubyte2_e32 v61, v35                               ; 7e7a2723
	v_cvt_f32_ubyte3_e32 v60, v35                               ; 7e782923
	v_cvt_f32_ubyte0_e32 v35, v35                               ; 7e462323
	v_mac_f32_e32 v57, v25, v59                                 ; 2c727719
	v_mac_f32_e32 v53, v20, v36                                 ; 2c6a4914
	v_mul_f32_e32 v60, v31, v60                                 ; 0a78791f
	v_mac_f32_e32 v57, v24, v56                                 ; 2c727118
	v_mac_f32_e32 v60, v30, v61                                 ; 2c787b1e
	v_mac_f32_e32 v60, v29, v62                                 ; 2c787d1d
	v_mac_f32_e32 v60, v28, v35                                 ; 2c78471c
	v_mul_f32_e32 v60, v60, v46                                 ; 0a785d3c
	v_mac_f32_e32 v60, v57, v43                                 ; 2c785739
	v_mac_f32_e32 v60, v53, v47                                 ; 2c785f35
	v_mac_f32_e32 v60, v50, v42                                 ; 2c785532
	v_mac_f32_e32 v3, v40, v60                                  ; 2c067928
	s_cbranch_scc0 BB100                                        ; bf8402ba
BB78:
	s_add_u32 s0, s16, 1                                        ; 80008110
	s_mul_i32 s0, s0, s3                                        ; 92000300
	s_add_u32 s0, s19, s0                                       ; 80000013
	v_add_u32_e32 v13, s0, v0                                   ; 681a0000
	v_lshlrev_b32_e32 v14, 4, v13                               ; 241c1a84
	v_lshl_add_u32 v13, v13, 7, v14                             ; d1fd000d 04390f0d
	v_add_u32_e32 v35, 16, v13                                  ; 68461a90
	v_add_u32_e32 v36, v35, v4                                  ; 68480923
	v_add_u32_e32 v35, v35, v37                                 ; 68464b23
	buffer_load_dwordx4 v[40:43], v13, s[12:15], 0 offen        ; e05c1000 8003280d
	buffer_load_dword v36, v36, s[12:15], 0 offen               ; e0501000 80032424
	buffer_load_dword v35, v35, s[12:15], 0 offen               ; e0501000 80032323
	s_bfm_b32 s1, 16, 16                                        ; 91019090
	s_mov_b32 s5, 0xf0f0f0f                                     ; be8500ff 0f0f0f0f
	s_cmp_lt_u32 2, s4                                          ; bf0a0482
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_bfe_u32 v41, v41, v2, 16                                  ; d1c80029 02420529
	v_lshlrev_b32_e32 v42, v5, v42                              ; 24545505
	v_bfe_u32 v43, v43, v2, 16                                  ; d1c8002b 0242052b
	v_and_or_b32 v42, s1, v42, v41                              ; d201002a 04a65401
	v_lshl_or_b32 v43, v43, 12, v43                             ; d200002b 04ad192b
	v_and_b32_e32 v38, 0xc0c0c0c0, v42                          ; 264c54ff c0c0c0c0
	v_and_b32_e32 v42, 0x3f3f3f3f, v42                          ; 265454ff 3f3f3f3f
	v_cvt_f32_f16_sdwa v48, v40 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e6016f9 00050628
	v_lshrrev_b32_e32 v38, 2, v38                               ; 204c4c82
	v_cvt_f32_ubyte1_e32 v47, v42                               ; 7e5e252a
	v_cvt_f32_f16_e32 v40, v40                                  ; 7e501728
	v_cvt_f32_ubyte3_e32 v44, v42                               ; 7e58292a
	v_cvt_f32_ubyte2_e32 v45, v42                               ; 7e5a272a
	v_cvt_f32_ubyte0_e32 v42, v42                               ; 7e54232a
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v49, s5, v36                                  ; 26624805
	v_and_or_b32 v43, s5, v43, v38                              ; d201002b 049a5605
	v_cvt_f32_ubyte3_e32 v50, v49                               ; 7e642931
	v_cvt_f32_ubyte1_e32 v52, v49                               ; 7e682531
	v_cvt_f32_ubyte2_e32 v51, v49                               ; 7e662731
	v_cvt_f32_ubyte0_e32 v49, v49                               ; 7e622331
	v_cvt_f32_ubyte1_e32 v46, v43                               ; 7e5c252b
	v_cvt_f32_ubyte3_e32 v39, v43                               ; 7e4e292b
	v_cvt_f32_ubyte2_e32 v41, v43                               ; 7e52272b
	v_cvt_f32_ubyte0_e32 v43, v43                               ; 7e56232b
	v_lshrrev_b32_e32 v36, 4, v36                               ; 20484884
	v_mul_f32_e32 v50, v19, v50                                 ; 0a646513
	v_mul_f32_e32 v39, v34, v39                                 ; 0a4e4f22
	v_and_b32_e32 v36, s5, v36                                  ; 26484805
	v_mac_f32_e32 v50, v18, v51                                 ; 2c646712
	v_mac_f32_e32 v39, v33, v41                                 ; 2c4e5321
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v56, s5, v35                                  ; 26704605
	v_cvt_f32_ubyte3_e32 v53, v36                               ; 7e6a2924
	v_cvt_f32_ubyte2_e32 v54, v36                               ; 7e6c2724
	v_cvt_f32_ubyte1_e32 v55, v36                               ; 7e6e2524
	v_cvt_f32_ubyte0_e32 v36, v36                               ; 7e482324
	v_mac_f32_e32 v50, v17, v52                                 ; 2c646911
	v_mac_f32_e32 v39, v32, v44                                 ; 2c4e5920
	v_cvt_f32_ubyte2_e32 v58, v56                               ; 7e742738
	v_cvt_f32_ubyte3_e32 v57, v56                               ; 7e722938
	v_mul_f32_e32 v53, v23, v53                                 ; 0a6a6b17
	v_cvt_f32_ubyte1_e32 v59, v56                               ; 7e762538
	v_cvt_f32_ubyte0_e32 v56, v56                               ; 7e702338
	v_mac_f32_e32 v50, v16, v49                                 ; 2c646310
	v_lshrrev_b32_e32 v35, 4, v35                               ; 20464684
	v_mac_f32_e32 v39, v15, v45                                 ; 2c4e5b0f
	v_mul_f32_e32 v57, v27, v57                                 ; 0a72731b
	v_mac_f32_e32 v53, v22, v54                                 ; 2c6a6d16
	v_and_b32_e32 v35, s5, v35                                  ; 26464605
	v_mad_f32 v6, -v48, v39, v6                                 ; d1c10006 241a4f30
	v_mac_f32_e32 v57, v26, v58                                 ; 2c72751a
	v_mac_f32_e32 v53, v21, v55                                 ; 2c6a6f15
	v_cvt_f32_ubyte1_e32 v62, v35                               ; 7e7c2523
	v_cvt_f32_ubyte2_e32 v61, v35                               ; 7e7a2723
	v_cvt_f32_ubyte3_e32 v60, v35                               ; 7e782923
	v_cvt_f32_ubyte0_e32 v35, v35                               ; 7e462323
	v_mac_f32_e32 v57, v25, v59                                 ; 2c727719
	v_mac_f32_e32 v53, v20, v36                                 ; 2c6a4914
	v_mul_f32_e32 v60, v31, v60                                 ; 0a78791f
	v_mac_f32_e32 v57, v24, v56                                 ; 2c727118
	v_mac_f32_e32 v60, v30, v61                                 ; 2c787b1e
	v_mac_f32_e32 v60, v29, v62                                 ; 2c787d1d
	v_mac_f32_e32 v60, v28, v35                                 ; 2c78471c
	v_mul_f32_e32 v60, v60, v46                                 ; 0a785d3c
	v_mac_f32_e32 v60, v57, v43                                 ; 2c785739
	v_mac_f32_e32 v60, v53, v47                                 ; 2c785f35
	v_mac_f32_e32 v60, v50, v42                                 ; 2c785532
	v_mac_f32_e32 v6, v40, v60                                  ; 2c0c7928
	s_cbranch_scc0 BB100                                        ; bf840256
BB79:
	s_add_u32 s0, s16, 2                                        ; 80008210
	s_mul_i32 s0, s0, s3                                        ; 92000300
	s_add_u32 s0, s19, s0                                       ; 80000013
	v_add_u32_e32 v13, s0, v0                                   ; 681a0000
	v_lshlrev_b32_e32 v14, 4, v13                               ; 241c1a84
	v_lshl_add_u32 v13, v13, 7, v14                             ; d1fd000d 04390f0d
	v_add_u32_e32 v35, 16, v13                                  ; 68461a90
	v_add_u32_e32 v36, v35, v4                                  ; 68480923
	v_add_u32_e32 v35, v35, v37                                 ; 68464b23
	buffer_load_dwordx4 v[40:43], v13, s[12:15], 0 offen        ; e05c1000 8003280d
	buffer_load_dword v36, v36, s[12:15], 0 offen               ; e0501000 80032424
	buffer_load_dword v35, v35, s[12:15], 0 offen               ; e0501000 80032323
	s_bfm_b32 s1, 16, 16                                        ; 91019090
	s_mov_b32 s5, 0xf0f0f0f                                     ; be8500ff 0f0f0f0f
	s_cmp_lt_u32 3, s4                                          ; bf0a0483
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_bfe_u32 v41, v41, v2, 16                                  ; d1c80029 02420529
	v_lshlrev_b32_e32 v42, v5, v42                              ; 24545505
	v_bfe_u32 v43, v43, v2, 16                                  ; d1c8002b 0242052b
	v_and_or_b32 v42, s1, v42, v41                              ; d201002a 04a65401
	v_lshl_or_b32 v43, v43, 12, v43                             ; d200002b 04ad192b
	v_and_b32_e32 v38, 0xc0c0c0c0, v42                          ; 264c54ff c0c0c0c0
	v_and_b32_e32 v42, 0x3f3f3f3f, v42                          ; 265454ff 3f3f3f3f
	v_cvt_f32_f16_sdwa v48, v40 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e6016f9 00050628
	v_lshrrev_b32_e32 v38, 2, v38                               ; 204c4c82
	v_cvt_f32_ubyte1_e32 v47, v42                               ; 7e5e252a
	v_cvt_f32_f16_e32 v40, v40                                  ; 7e501728
	v_cvt_f32_ubyte3_e32 v44, v42                               ; 7e58292a
	v_cvt_f32_ubyte2_e32 v45, v42                               ; 7e5a272a
	v_cvt_f32_ubyte0_e32 v42, v42                               ; 7e54232a
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v49, s5, v36                                  ; 26624805
	v_and_or_b32 v43, s5, v43, v38                              ; d201002b 049a5605
	v_cvt_f32_ubyte3_e32 v50, v49                               ; 7e642931
	v_cvt_f32_ubyte1_e32 v52, v49                               ; 7e682531
	v_cvt_f32_ubyte2_e32 v51, v49                               ; 7e662731
	v_cvt_f32_ubyte0_e32 v49, v49                               ; 7e622331
	v_cvt_f32_ubyte1_e32 v46, v43                               ; 7e5c252b
	v_cvt_f32_ubyte3_e32 v39, v43                               ; 7e4e292b
	v_cvt_f32_ubyte2_e32 v41, v43                               ; 7e52272b
	v_cvt_f32_ubyte0_e32 v43, v43                               ; 7e56232b
	v_lshrrev_b32_e32 v36, 4, v36                               ; 20484884
	v_mul_f32_e32 v50, v19, v50                                 ; 0a646513
	v_mul_f32_e32 v39, v34, v39                                 ; 0a4e4f22
	v_and_b32_e32 v36, s5, v36                                  ; 26484805
	v_mac_f32_e32 v50, v18, v51                                 ; 2c646712
	v_mac_f32_e32 v39, v33, v41                                 ; 2c4e5321
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v56, s5, v35                                  ; 26704605
	v_cvt_f32_ubyte3_e32 v53, v36                               ; 7e6a2924
	v_cvt_f32_ubyte2_e32 v54, v36                               ; 7e6c2724
	v_cvt_f32_ubyte1_e32 v55, v36                               ; 7e6e2524
	v_cvt_f32_ubyte0_e32 v36, v36                               ; 7e482324
	v_mac_f32_e32 v50, v17, v52                                 ; 2c646911
	v_mac_f32_e32 v39, v32, v44                                 ; 2c4e5920
	v_cvt_f32_ubyte2_e32 v58, v56                               ; 7e742738
	v_cvt_f32_ubyte3_e32 v57, v56                               ; 7e722938
	v_mul_f32_e32 v53, v23, v53                                 ; 0a6a6b17
	v_cvt_f32_ubyte1_e32 v59, v56                               ; 7e762538
	v_cvt_f32_ubyte0_e32 v56, v56                               ; 7e702338
	v_mac_f32_e32 v50, v16, v49                                 ; 2c646310
	v_lshrrev_b32_e32 v35, 4, v35                               ; 20464684
	v_mac_f32_e32 v39, v15, v45                                 ; 2c4e5b0f
	v_mul_f32_e32 v57, v27, v57                                 ; 0a72731b
	v_mac_f32_e32 v53, v22, v54                                 ; 2c6a6d16
	v_and_b32_e32 v35, s5, v35                                  ; 26464605
	v_mad_f32 v7, -v48, v39, v7                                 ; d1c10007 241e4f30
	v_mac_f32_e32 v57, v26, v58                                 ; 2c72751a
	v_mac_f32_e32 v53, v21, v55                                 ; 2c6a6f15
	v_cvt_f32_ubyte1_e32 v62, v35                               ; 7e7c2523
	v_cvt_f32_ubyte2_e32 v61, v35                               ; 7e7a2723
	v_cvt_f32_ubyte3_e32 v60, v35                               ; 7e782923
	v_cvt_f32_ubyte0_e32 v35, v35                               ; 7e462323
	v_mac_f32_e32 v57, v25, v59                                 ; 2c727719
	v_mac_f32_e32 v53, v20, v36                                 ; 2c6a4914
	v_mul_f32_e32 v60, v31, v60                                 ; 0a78791f
	v_mac_f32_e32 v57, v24, v56                                 ; 2c727118
	v_mac_f32_e32 v60, v30, v61                                 ; 2c787b1e
	v_mac_f32_e32 v60, v29, v62                                 ; 2c787d1d
	v_mac_f32_e32 v60, v28, v35                                 ; 2c78471c
	v_mul_f32_e32 v60, v60, v46                                 ; 0a785d3c
	v_mac_f32_e32 v60, v57, v43                                 ; 2c785739
	v_mac_f32_e32 v60, v53, v47                                 ; 2c785f35
	v_mac_f32_e32 v60, v50, v42                                 ; 2c785532
	v_mac_f32_e32 v7, v40, v60                                  ; 2c0e7928
	s_cbranch_scc0 BB100                                        ; bf8401f2
BB80:
	s_add_u32 s0, s16, 3                                        ; 80008310
	s_mul_i32 s0, s0, s3                                        ; 92000300
	s_add_u32 s0, s19, s0                                       ; 80000013
	v_add_u32_e32 v13, s0, v0                                   ; 681a0000
	v_lshlrev_b32_e32 v14, 4, v13                               ; 241c1a84
	v_lshl_add_u32 v13, v13, 7, v14                             ; d1fd000d 04390f0d
	v_add_u32_e32 v35, 16, v13                                  ; 68461a90
	v_add_u32_e32 v36, v35, v4                                  ; 68480923
	v_add_u32_e32 v35, v35, v37                                 ; 68464b23
	buffer_load_dwordx4 v[40:43], v13, s[12:15], 0 offen        ; e05c1000 8003280d
	buffer_load_dword v36, v36, s[12:15], 0 offen               ; e0501000 80032424
	buffer_load_dword v35, v35, s[12:15], 0 offen               ; e0501000 80032323
	s_bfm_b32 s1, 16, 16                                        ; 91019090
	s_mov_b32 s5, 0xf0f0f0f                                     ; be8500ff 0f0f0f0f
	s_cmp_lt_u32 4, s4                                          ; bf0a0484
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_bfe_u32 v41, v41, v2, 16                                  ; d1c80029 02420529
	v_lshlrev_b32_e32 v42, v5, v42                              ; 24545505
	v_bfe_u32 v43, v43, v2, 16                                  ; d1c8002b 0242052b
	v_and_or_b32 v42, s1, v42, v41                              ; d201002a 04a65401
	v_lshl_or_b32 v43, v43, 12, v43                             ; d200002b 04ad192b
	v_and_b32_e32 v38, 0xc0c0c0c0, v42                          ; 264c54ff c0c0c0c0
	v_and_b32_e32 v42, 0x3f3f3f3f, v42                          ; 265454ff 3f3f3f3f
	v_cvt_f32_f16_sdwa v48, v40 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e6016f9 00050628
	v_lshrrev_b32_e32 v38, 2, v38                               ; 204c4c82
	v_cvt_f32_ubyte1_e32 v47, v42                               ; 7e5e252a
	v_cvt_f32_f16_e32 v40, v40                                  ; 7e501728
	v_cvt_f32_ubyte3_e32 v44, v42                               ; 7e58292a
	v_cvt_f32_ubyte2_e32 v45, v42                               ; 7e5a272a
	v_cvt_f32_ubyte0_e32 v42, v42                               ; 7e54232a
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v49, s5, v36                                  ; 26624805
	v_and_or_b32 v43, s5, v43, v38                              ; d201002b 049a5605
	v_cvt_f32_ubyte3_e32 v50, v49                               ; 7e642931
	v_cvt_f32_ubyte1_e32 v52, v49                               ; 7e682531
	v_cvt_f32_ubyte2_e32 v51, v49                               ; 7e662731
	v_cvt_f32_ubyte0_e32 v49, v49                               ; 7e622331
	v_cvt_f32_ubyte1_e32 v46, v43                               ; 7e5c252b
	v_cvt_f32_ubyte3_e32 v39, v43                               ; 7e4e292b
	v_cvt_f32_ubyte2_e32 v41, v43                               ; 7e52272b
	v_cvt_f32_ubyte0_e32 v43, v43                               ; 7e56232b
	v_lshrrev_b32_e32 v36, 4, v36                               ; 20484884
	v_mul_f32_e32 v50, v19, v50                                 ; 0a646513
	v_mul_f32_e32 v39, v34, v39                                 ; 0a4e4f22
	v_and_b32_e32 v36, s5, v36                                  ; 26484805
	v_mac_f32_e32 v50, v18, v51                                 ; 2c646712
	v_mac_f32_e32 v39, v33, v41                                 ; 2c4e5321
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v56, s5, v35                                  ; 26704605
	v_cvt_f32_ubyte3_e32 v53, v36                               ; 7e6a2924
	v_cvt_f32_ubyte2_e32 v54, v36                               ; 7e6c2724
	v_cvt_f32_ubyte1_e32 v55, v36                               ; 7e6e2524
	v_cvt_f32_ubyte0_e32 v36, v36                               ; 7e482324
	v_mac_f32_e32 v50, v17, v52                                 ; 2c646911
	v_mac_f32_e32 v39, v32, v44                                 ; 2c4e5920
	v_cvt_f32_ubyte2_e32 v58, v56                               ; 7e742738
	v_cvt_f32_ubyte3_e32 v57, v56                               ; 7e722938
	v_mul_f32_e32 v53, v23, v53                                 ; 0a6a6b17
	v_cvt_f32_ubyte1_e32 v59, v56                               ; 7e762538
	v_cvt_f32_ubyte0_e32 v56, v56                               ; 7e702338
	v_mac_f32_e32 v50, v16, v49                                 ; 2c646310
	v_lshrrev_b32_e32 v35, 4, v35                               ; 20464684
	v_mac_f32_e32 v39, v15, v45                                 ; 2c4e5b0f
	v_mul_f32_e32 v57, v27, v57                                 ; 0a72731b
	v_mac_f32_e32 v53, v22, v54                                 ; 2c6a6d16
	v_and_b32_e32 v35, s5, v35                                  ; 26464605
	v_mad_f32 v8, -v48, v39, v8                                 ; d1c10008 24224f30
	v_mac_f32_e32 v57, v26, v58                                 ; 2c72751a
	v_mac_f32_e32 v53, v21, v55                                 ; 2c6a6f15
	v_cvt_f32_ubyte1_e32 v62, v35                               ; 7e7c2523
	v_cvt_f32_ubyte2_e32 v61, v35                               ; 7e7a2723
	v_cvt_f32_ubyte3_e32 v60, v35                               ; 7e782923
	v_cvt_f32_ubyte0_e32 v35, v35                               ; 7e462323
	v_mac_f32_e32 v57, v25, v59                                 ; 2c727719
	v_mac_f32_e32 v53, v20, v36                                 ; 2c6a4914
	v_mul_f32_e32 v60, v31, v60                                 ; 0a78791f
	v_mac_f32_e32 v57, v24, v56                                 ; 2c727118
	v_mac_f32_e32 v60, v30, v61                                 ; 2c787b1e
	v_mac_f32_e32 v60, v29, v62                                 ; 2c787d1d
	v_mac_f32_e32 v60, v28, v35                                 ; 2c78471c
	v_mul_f32_e32 v60, v60, v46                                 ; 0a785d3c
	v_mac_f32_e32 v60, v57, v43                                 ; 2c785739
	v_mac_f32_e32 v60, v53, v47                                 ; 2c785f35
	v_mac_f32_e32 v60, v50, v42                                 ; 2c785532
	v_mac_f32_e32 v8, v40, v60                                  ; 2c107928
	s_cbranch_scc0 BB100                                        ; bf84018e
BB81:
	s_add_u32 s0, s16, 4                                        ; 80008410
	s_mul_i32 s0, s0, s3                                        ; 92000300
	s_add_u32 s0, s19, s0                                       ; 80000013
	v_add_u32_e32 v13, s0, v0                                   ; 681a0000
	v_lshlrev_b32_e32 v14, 4, v13                               ; 241c1a84
	v_lshl_add_u32 v13, v13, 7, v14                             ; d1fd000d 04390f0d
	v_add_u32_e32 v35, 16, v13                                  ; 68461a90
	v_add_u32_e32 v36, v35, v4                                  ; 68480923
	v_add_u32_e32 v35, v35, v37                                 ; 68464b23
	buffer_load_dwordx4 v[40:43], v13, s[12:15], 0 offen        ; e05c1000 8003280d
	buffer_load_dword v36, v36, s[12:15], 0 offen               ; e0501000 80032424
	buffer_load_dword v35, v35, s[12:15], 0 offen               ; e0501000 80032323
	s_bfm_b32 s1, 16, 16                                        ; 91019090
	s_mov_b32 s5, 0xf0f0f0f                                     ; be8500ff 0f0f0f0f
	s_cmp_lt_u32 5, s4                                          ; bf0a0485
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_bfe_u32 v41, v41, v2, 16                                  ; d1c80029 02420529
	v_lshlrev_b32_e32 v42, v5, v42                              ; 24545505
	v_bfe_u32 v43, v43, v2, 16                                  ; d1c8002b 0242052b
	v_and_or_b32 v42, s1, v42, v41                              ; d201002a 04a65401
	v_lshl_or_b32 v43, v43, 12, v43                             ; d200002b 04ad192b
	v_and_b32_e32 v38, 0xc0c0c0c0, v42                          ; 264c54ff c0c0c0c0
	v_and_b32_e32 v42, 0x3f3f3f3f, v42                          ; 265454ff 3f3f3f3f
	v_cvt_f32_f16_sdwa v48, v40 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e6016f9 00050628
	v_lshrrev_b32_e32 v38, 2, v38                               ; 204c4c82
	v_cvt_f32_ubyte1_e32 v47, v42                               ; 7e5e252a
	v_cvt_f32_f16_e32 v40, v40                                  ; 7e501728
	v_cvt_f32_ubyte3_e32 v44, v42                               ; 7e58292a
	v_cvt_f32_ubyte2_e32 v45, v42                               ; 7e5a272a
	v_cvt_f32_ubyte0_e32 v42, v42                               ; 7e54232a
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v49, s5, v36                                  ; 26624805
	v_and_or_b32 v43, s5, v43, v38                              ; d201002b 049a5605
	v_cvt_f32_ubyte3_e32 v50, v49                               ; 7e642931
	v_cvt_f32_ubyte1_e32 v52, v49                               ; 7e682531
	v_cvt_f32_ubyte2_e32 v51, v49                               ; 7e662731
	v_cvt_f32_ubyte0_e32 v49, v49                               ; 7e622331
	v_cvt_f32_ubyte1_e32 v46, v43                               ; 7e5c252b
	v_cvt_f32_ubyte3_e32 v39, v43                               ; 7e4e292b
	v_cvt_f32_ubyte2_e32 v41, v43                               ; 7e52272b
	v_cvt_f32_ubyte0_e32 v43, v43                               ; 7e56232b
	v_lshrrev_b32_e32 v36, 4, v36                               ; 20484884
	v_mul_f32_e32 v50, v19, v50                                 ; 0a646513
	v_mul_f32_e32 v39, v34, v39                                 ; 0a4e4f22
	v_and_b32_e32 v36, s5, v36                                  ; 26484805
	v_mac_f32_e32 v50, v18, v51                                 ; 2c646712
	v_mac_f32_e32 v39, v33, v41                                 ; 2c4e5321
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v56, s5, v35                                  ; 26704605
	v_cvt_f32_ubyte3_e32 v53, v36                               ; 7e6a2924
	v_cvt_f32_ubyte2_e32 v54, v36                               ; 7e6c2724
	v_cvt_f32_ubyte1_e32 v55, v36                               ; 7e6e2524
	v_cvt_f32_ubyte0_e32 v36, v36                               ; 7e482324
	v_mac_f32_e32 v50, v17, v52                                 ; 2c646911
	v_mac_f32_e32 v39, v32, v44                                 ; 2c4e5920
	v_cvt_f32_ubyte2_e32 v58, v56                               ; 7e742738
	v_cvt_f32_ubyte3_e32 v57, v56                               ; 7e722938
	v_mul_f32_e32 v53, v23, v53                                 ; 0a6a6b17
	v_cvt_f32_ubyte1_e32 v59, v56                               ; 7e762538
	v_cvt_f32_ubyte0_e32 v56, v56                               ; 7e702338
	v_mac_f32_e32 v50, v16, v49                                 ; 2c646310
	v_lshrrev_b32_e32 v35, 4, v35                               ; 20464684
	v_mac_f32_e32 v39, v15, v45                                 ; 2c4e5b0f
	v_mul_f32_e32 v57, v27, v57                                 ; 0a72731b
	v_mac_f32_e32 v53, v22, v54                                 ; 2c6a6d16
	v_and_b32_e32 v35, s5, v35                                  ; 26464605
	v_mad_f32 v9, -v48, v39, v9                                 ; d1c10009 24264f30
	v_mac_f32_e32 v57, v26, v58                                 ; 2c72751a
	v_mac_f32_e32 v53, v21, v55                                 ; 2c6a6f15
	v_cvt_f32_ubyte1_e32 v62, v35                               ; 7e7c2523
	v_cvt_f32_ubyte2_e32 v61, v35                               ; 7e7a2723
	v_cvt_f32_ubyte3_e32 v60, v35                               ; 7e782923
	v_cvt_f32_ubyte0_e32 v35, v35                               ; 7e462323
	v_mac_f32_e32 v57, v25, v59                                 ; 2c727719
	v_mac_f32_e32 v53, v20, v36                                 ; 2c6a4914
	v_mul_f32_e32 v60, v31, v60                                 ; 0a78791f
	v_mac_f32_e32 v57, v24, v56                                 ; 2c727118
	v_mac_f32_e32 v60, v30, v61                                 ; 2c787b1e
	v_mac_f32_e32 v60, v29, v62                                 ; 2c787d1d
	v_mac_f32_e32 v60, v28, v35                                 ; 2c78471c
	v_mul_f32_e32 v60, v60, v46                                 ; 0a785d3c
	v_mac_f32_e32 v60, v57, v43                                 ; 2c785739
	v_mac_f32_e32 v60, v53, v47                                 ; 2c785f35
	v_mac_f32_e32 v60, v50, v42                                 ; 2c785532
	v_mac_f32_e32 v9, v40, v60                                  ; 2c127928
	s_cbranch_scc0 BB100                                        ; bf84012a
BB82:
	s_add_u32 s0, s16, 5                                        ; 80008510
	s_mul_i32 s0, s0, s3                                        ; 92000300
	s_add_u32 s0, s19, s0                                       ; 80000013
	v_add_u32_e32 v13, s0, v0                                   ; 681a0000
	v_lshlrev_b32_e32 v14, 4, v13                               ; 241c1a84
	v_lshl_add_u32 v13, v13, 7, v14                             ; d1fd000d 04390f0d
	v_add_u32_e32 v35, 16, v13                                  ; 68461a90
	v_add_u32_e32 v36, v35, v4                                  ; 68480923
	v_add_u32_e32 v35, v35, v37                                 ; 68464b23
	buffer_load_dwordx4 v[40:43], v13, s[12:15], 0 offen        ; e05c1000 8003280d
	buffer_load_dword v36, v36, s[12:15], 0 offen               ; e0501000 80032424
	buffer_load_dword v35, v35, s[12:15], 0 offen               ; e0501000 80032323
	s_bfm_b32 s1, 16, 16                                        ; 91019090
	s_mov_b32 s5, 0xf0f0f0f                                     ; be8500ff 0f0f0f0f
	s_cmp_lt_u32 6, s4                                          ; bf0a0486
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_bfe_u32 v41, v41, v2, 16                                  ; d1c80029 02420529
	v_lshlrev_b32_e32 v42, v5, v42                              ; 24545505
	v_bfe_u32 v43, v43, v2, 16                                  ; d1c8002b 0242052b
	v_and_or_b32 v42, s1, v42, v41                              ; d201002a 04a65401
	v_lshl_or_b32 v43, v43, 12, v43                             ; d200002b 04ad192b
	v_and_b32_e32 v38, 0xc0c0c0c0, v42                          ; 264c54ff c0c0c0c0
	v_and_b32_e32 v42, 0x3f3f3f3f, v42                          ; 265454ff 3f3f3f3f
	v_cvt_f32_f16_sdwa v48, v40 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e6016f9 00050628
	v_lshrrev_b32_e32 v38, 2, v38                               ; 204c4c82
	v_cvt_f32_ubyte1_e32 v47, v42                               ; 7e5e252a
	v_cvt_f32_f16_e32 v40, v40                                  ; 7e501728
	v_cvt_f32_ubyte3_e32 v44, v42                               ; 7e58292a
	v_cvt_f32_ubyte2_e32 v45, v42                               ; 7e5a272a
	v_cvt_f32_ubyte0_e32 v42, v42                               ; 7e54232a
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v49, s5, v36                                  ; 26624805
	v_and_or_b32 v43, s5, v43, v38                              ; d201002b 049a5605
	v_cvt_f32_ubyte3_e32 v50, v49                               ; 7e642931
	v_cvt_f32_ubyte1_e32 v52, v49                               ; 7e682531
	v_cvt_f32_ubyte2_e32 v51, v49                               ; 7e662731
	v_cvt_f32_ubyte0_e32 v49, v49                               ; 7e622331
	v_cvt_f32_ubyte1_e32 v46, v43                               ; 7e5c252b
	v_cvt_f32_ubyte3_e32 v39, v43                               ; 7e4e292b
	v_cvt_f32_ubyte2_e32 v41, v43                               ; 7e52272b
	v_cvt_f32_ubyte0_e32 v43, v43                               ; 7e56232b
	v_lshrrev_b32_e32 v36, 4, v36                               ; 20484884
	v_mul_f32_e32 v50, v19, v50                                 ; 0a646513
	v_mul_f32_e32 v39, v34, v39                                 ; 0a4e4f22
	v_and_b32_e32 v36, s5, v36                                  ; 26484805
	v_mac_f32_e32 v50, v18, v51                                 ; 2c646712
	v_mac_f32_e32 v39, v33, v41                                 ; 2c4e5321
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v56, s5, v35                                  ; 26704605
	v_cvt_f32_ubyte3_e32 v53, v36                               ; 7e6a2924
	v_cvt_f32_ubyte2_e32 v54, v36                               ; 7e6c2724
	v_cvt_f32_ubyte1_e32 v55, v36                               ; 7e6e2524
	v_cvt_f32_ubyte0_e32 v36, v36                               ; 7e482324
	v_mac_f32_e32 v50, v17, v52                                 ; 2c646911
	v_mac_f32_e32 v39, v32, v44                                 ; 2c4e5920
	v_cvt_f32_ubyte2_e32 v58, v56                               ; 7e742738
	v_cvt_f32_ubyte3_e32 v57, v56                               ; 7e722938
	v_mul_f32_e32 v53, v23, v53                                 ; 0a6a6b17
	v_cvt_f32_ubyte1_e32 v59, v56                               ; 7e762538
	v_cvt_f32_ubyte0_e32 v56, v56                               ; 7e702338
	v_mac_f32_e32 v50, v16, v49                                 ; 2c646310
	v_lshrrev_b32_e32 v35, 4, v35                               ; 20464684
	v_mac_f32_e32 v39, v15, v45                                 ; 2c4e5b0f
	v_mul_f32_e32 v57, v27, v57                                 ; 0a72731b
	v_mac_f32_e32 v53, v22, v54                                 ; 2c6a6d16
	v_and_b32_e32 v35, s5, v35                                  ; 26464605
	v_mad_f32 v10, -v48, v39, v10                               ; d1c1000a 242a4f30
	v_mac_f32_e32 v57, v26, v58                                 ; 2c72751a
	v_mac_f32_e32 v53, v21, v55                                 ; 2c6a6f15
	v_cvt_f32_ubyte1_e32 v62, v35                               ; 7e7c2523
	v_cvt_f32_ubyte2_e32 v61, v35                               ; 7e7a2723
	v_cvt_f32_ubyte3_e32 v60, v35                               ; 7e782923
	v_cvt_f32_ubyte0_e32 v35, v35                               ; 7e462323
	v_mac_f32_e32 v57, v25, v59                                 ; 2c727719
	v_mac_f32_e32 v53, v20, v36                                 ; 2c6a4914
	v_mul_f32_e32 v60, v31, v60                                 ; 0a78791f
	v_mac_f32_e32 v57, v24, v56                                 ; 2c727118
	v_mac_f32_e32 v60, v30, v61                                 ; 2c787b1e
	v_mac_f32_e32 v60, v29, v62                                 ; 2c787d1d
	v_mac_f32_e32 v60, v28, v35                                 ; 2c78471c
	v_mul_f32_e32 v60, v60, v46                                 ; 0a785d3c
	v_mac_f32_e32 v60, v57, v43                                 ; 2c785739
	v_mac_f32_e32 v60, v53, v47                                 ; 2c785f35
	v_mac_f32_e32 v60, v50, v42                                 ; 2c785532
	v_mac_f32_e32 v10, v40, v60                                 ; 2c147928
	s_cbranch_scc0 BB100                                        ; bf8400c6
BB83:
	s_add_u32 s0, s16, 6                                        ; 80008610
	s_mul_i32 s0, s0, s3                                        ; 92000300
	s_add_u32 s0, s19, s0                                       ; 80000013
	v_add_u32_e32 v13, s0, v0                                   ; 681a0000
	v_lshlrev_b32_e32 v14, 4, v13                               ; 241c1a84
	v_lshl_add_u32 v13, v13, 7, v14                             ; d1fd000d 04390f0d
	v_add_u32_e32 v35, 16, v13                                  ; 68461a90
	v_add_u32_e32 v36, v35, v4                                  ; 68480923
	v_add_u32_e32 v35, v35, v37                                 ; 68464b23
	buffer_load_dwordx4 v[40:43], v13, s[12:15], 0 offen        ; e05c1000 8003280d
	buffer_load_dword v36, v36, s[12:15], 0 offen               ; e0501000 80032424
	buffer_load_dword v35, v35, s[12:15], 0 offen               ; e0501000 80032323
	s_bfm_b32 s1, 16, 16                                        ; 91019090
	s_mov_b32 s5, 0xf0f0f0f                                     ; be8500ff 0f0f0f0f
	s_cmp_lt_u32 7, s4                                          ; bf0a0487
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_bfe_u32 v41, v41, v2, 16                                  ; d1c80029 02420529
	v_lshlrev_b32_e32 v42, v5, v42                              ; 24545505
	v_bfe_u32 v43, v43, v2, 16                                  ; d1c8002b 0242052b
	v_and_or_b32 v42, s1, v42, v41                              ; d201002a 04a65401
	v_lshl_or_b32 v43, v43, 12, v43                             ; d200002b 04ad192b
	v_and_b32_e32 v38, 0xc0c0c0c0, v42                          ; 264c54ff c0c0c0c0
	v_and_b32_e32 v42, 0x3f3f3f3f, v42                          ; 265454ff 3f3f3f3f
	v_cvt_f32_f16_sdwa v48, v40 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e6016f9 00050628
	v_lshrrev_b32_e32 v38, 2, v38                               ; 204c4c82
	v_cvt_f32_ubyte1_e32 v47, v42                               ; 7e5e252a
	v_cvt_f32_f16_e32 v40, v40                                  ; 7e501728
	v_cvt_f32_ubyte3_e32 v44, v42                               ; 7e58292a
	v_cvt_f32_ubyte2_e32 v45, v42                               ; 7e5a272a
	v_cvt_f32_ubyte0_e32 v42, v42                               ; 7e54232a
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v49, s5, v36                                  ; 26624805
	v_and_or_b32 v43, s5, v43, v38                              ; d201002b 049a5605
	v_cvt_f32_ubyte3_e32 v50, v49                               ; 7e642931
	v_cvt_f32_ubyte1_e32 v52, v49                               ; 7e682531
	v_cvt_f32_ubyte2_e32 v51, v49                               ; 7e662731
	v_cvt_f32_ubyte0_e32 v49, v49                               ; 7e622331
	v_cvt_f32_ubyte1_e32 v46, v43                               ; 7e5c252b
	v_cvt_f32_ubyte3_e32 v39, v43                               ; 7e4e292b
	v_cvt_f32_ubyte2_e32 v41, v43                               ; 7e52272b
	v_cvt_f32_ubyte0_e32 v43, v43                               ; 7e56232b
	v_lshrrev_b32_e32 v36, 4, v36                               ; 20484884
	v_mul_f32_e32 v50, v19, v50                                 ; 0a646513
	v_mul_f32_e32 v39, v34, v39                                 ; 0a4e4f22
	v_and_b32_e32 v36, s5, v36                                  ; 26484805
	v_mac_f32_e32 v50, v18, v51                                 ; 2c646712
	v_mac_f32_e32 v39, v33, v41                                 ; 2c4e5321
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v56, s5, v35                                  ; 26704605
	v_cvt_f32_ubyte3_e32 v53, v36                               ; 7e6a2924
	v_cvt_f32_ubyte2_e32 v54, v36                               ; 7e6c2724
	v_cvt_f32_ubyte1_e32 v55, v36                               ; 7e6e2524
	v_cvt_f32_ubyte0_e32 v36, v36                               ; 7e482324
	v_mac_f32_e32 v50, v17, v52                                 ; 2c646911
	v_mac_f32_e32 v39, v32, v44                                 ; 2c4e5920
	v_cvt_f32_ubyte2_e32 v58, v56                               ; 7e742738
	v_cvt_f32_ubyte3_e32 v57, v56                               ; 7e722938
	v_mul_f32_e32 v53, v23, v53                                 ; 0a6a6b17
	v_cvt_f32_ubyte1_e32 v59, v56                               ; 7e762538
	v_cvt_f32_ubyte0_e32 v56, v56                               ; 7e702338
	v_mac_f32_e32 v50, v16, v49                                 ; 2c646310
	v_lshrrev_b32_e32 v35, 4, v35                               ; 20464684
	v_mac_f32_e32 v39, v15, v45                                 ; 2c4e5b0f
	v_mul_f32_e32 v57, v27, v57                                 ; 0a72731b
	v_mac_f32_e32 v53, v22, v54                                 ; 2c6a6d16
	v_and_b32_e32 v35, s5, v35                                  ; 26464605
	v_mad_f32 v11, -v48, v39, v11                               ; d1c1000b 242e4f30
	v_mac_f32_e32 v57, v26, v58                                 ; 2c72751a
	v_mac_f32_e32 v53, v21, v55                                 ; 2c6a6f15
	v_cvt_f32_ubyte1_e32 v62, v35                               ; 7e7c2523
	v_cvt_f32_ubyte2_e32 v61, v35                               ; 7e7a2723
	v_cvt_f32_ubyte3_e32 v60, v35                               ; 7e782923
	v_cvt_f32_ubyte0_e32 v35, v35                               ; 7e462323
	v_mac_f32_e32 v57, v25, v59                                 ; 2c727719
	v_mac_f32_e32 v53, v20, v36                                 ; 2c6a4914
	v_mul_f32_e32 v60, v31, v60                                 ; 0a78791f
	v_mac_f32_e32 v57, v24, v56                                 ; 2c727118
	v_mac_f32_e32 v60, v30, v61                                 ; 2c787b1e
	v_mac_f32_e32 v60, v29, v62                                 ; 2c787d1d
	v_mac_f32_e32 v60, v28, v35                                 ; 2c78471c
	v_mul_f32_e32 v60, v60, v46                                 ; 0a785d3c
	v_mac_f32_e32 v60, v57, v43                                 ; 2c785739
	v_mac_f32_e32 v60, v53, v47                                 ; 2c785f35
	v_mac_f32_e32 v60, v50, v42                                 ; 2c785532
	v_mac_f32_e32 v11, v40, v60                                 ; 2c167928
	s_cbranch_scc0 BB100                                        ; bf840062
BB84:
	s_add_u32 s0, s16, 7                                        ; 80008710
	s_mul_i32 s0, s0, s3                                        ; 92000300
	s_add_u32 s0, s19, s0                                       ; 80000013
	v_add_u32_e32 v13, s0, v0                                   ; 681a0000
	v_lshlrev_b32_e32 v14, 4, v13                               ; 241c1a84
	v_lshl_add_u32 v13, v13, 7, v14                             ; d1fd000d 04390f0d
	v_add_u32_e32 v35, 16, v13                                  ; 68461a90
	v_add_u32_e32 v36, v35, v4                                  ; 68480923
	v_add_u32_e32 v35, v35, v37                                 ; 68464b23
	buffer_load_dwordx4 v[40:43], v13, s[12:15], 0 offen        ; e05c1000 8003280d
	buffer_load_dword v36, v36, s[12:15], 0 offen               ; e0501000 80032424
	buffer_load_dword v35, v35, s[12:15], 0 offen               ; e0501000 80032323
	s_bfm_b32 s1, 16, 16                                        ; 91019090
	s_mov_b32 s5, 0xf0f0f0f                                     ; be8500ff 0f0f0f0f
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_lshlrev_b32_e32 v42, v5, v42                              ; 24545505
	v_bfe_u32 v43, v43, v2, 16                                  ; d1c8002b 0242052b
	v_bfe_u32 v41, v41, v2, 16                                  ; d1c80029 02420529
	v_lshl_or_b32 v43, v43, 12, v43                             ; d200002b 04ad192b
	v_and_or_b32 v42, s1, v42, v41                              ; d201002a 04a65401
	v_and_b32_e32 v37, 0xc0c0c0c0, v42                          ; 264a54ff c0c0c0c0
	v_and_b32_e32 v42, 0x3f3f3f3f, v42                          ; 265454ff 3f3f3f3f
	v_cvt_f32_f16_sdwa v47, v40 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e5e16f9 00050628
	v_lshrrev_b32_e32 v37, 2, v37                               ; 204a4a82
	v_cvt_f32_ubyte1_e32 v46, v42                               ; 7e5c252a
	v_cvt_f32_f16_e32 v40, v40                                  ; 7e501728
	v_cvt_f32_ubyte3_e32 v41, v42                               ; 7e52292a
	v_cvt_f32_ubyte2_e32 v44, v42                               ; 7e58272a
	v_cvt_f32_ubyte0_e32 v42, v42                               ; 7e54232a
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v48, s5, v36                                  ; 26604805
	v_and_or_b32 v43, s5, v43, v37                              ; d201002b 04965605
	v_cvt_f32_ubyte1_e32 v51, v48                               ; 7e662530
	v_cvt_f32_ubyte3_e32 v49, v48                               ; 7e622930
	v_cvt_f32_ubyte2_e32 v50, v48                               ; 7e642730
	v_cvt_f32_ubyte0_e32 v48, v48                               ; 7e602330
	v_cvt_f32_ubyte3_e32 v38, v43                               ; 7e4c292b
	v_cvt_f32_ubyte2_e32 v39, v43                               ; 7e4e272b
	v_cvt_f32_ubyte1_e32 v45, v43                               ; 7e5a252b
	v_cvt_f32_ubyte0_e32 v43, v43                               ; 7e56232b
	v_lshrrev_b32_e32 v36, 4, v36                               ; 20484884
	v_mul_f32_e32 v19, v19, v49                                 ; 0a266313
	v_mul_f32_e32 v34, v34, v38                                 ; 0a444d22
	v_and_b32_e32 v36, s5, v36                                  ; 26484805
	v_mac_f32_e32 v19, v18, v50                                 ; 2c266512
	v_mac_f32_e32 v34, v33, v39                                 ; 2c444f21
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v55, s5, v35                                  ; 266e4605
	v_cvt_f32_ubyte3_e32 v52, v36                               ; 7e682924
	v_cvt_f32_ubyte2_e32 v53, v36                               ; 7e6a2724
	v_cvt_f32_ubyte1_e32 v54, v36                               ; 7e6c2524
	v_cvt_f32_ubyte0_e32 v36, v36                               ; 7e482324
	v_mac_f32_e32 v19, v17, v51                                 ; 2c266711
	v_mac_f32_e32 v34, v32, v41                                 ; 2c445320
	v_cvt_f32_ubyte2_e32 v57, v55                               ; 7e722737
	v_cvt_f32_ubyte3_e32 v56, v55                               ; 7e702937
	v_mul_f32_e32 v23, v23, v52                                 ; 0a2e6917
	v_cvt_f32_ubyte1_e32 v58, v55                               ; 7e742537
	v_cvt_f32_ubyte0_e32 v55, v55                               ; 7e6e2337
	v_mac_f32_e32 v19, v16, v48                                 ; 2c266110
	v_lshrrev_b32_e32 v35, 4, v35                               ; 20464684
	v_mac_f32_e32 v34, v15, v44                                 ; 2c44590f
	v_mul_f32_e32 v27, v27, v56                                 ; 0a36711b
	v_mac_f32_e32 v23, v22, v53                                 ; 2c2e6b16
	v_and_b32_e32 v35, s5, v35                                  ; 26464605
	v_mad_f32 v12, -v47, v34, v12                               ; d1c1000c 2432452f
	v_mac_f32_e32 v27, v26, v57                                 ; 2c36731a
	v_mac_f32_e32 v23, v21, v54                                 ; 2c2e6d15
	v_cvt_f32_ubyte1_e32 v61, v35                               ; 7e7a2523
	v_cvt_f32_ubyte2_e32 v60, v35                               ; 7e782723
	v_cvt_f32_ubyte3_e32 v59, v35                               ; 7e762923
	v_cvt_f32_ubyte0_e32 v35, v35                               ; 7e462323
	v_mac_f32_e32 v27, v25, v58                                 ; 2c367519
	v_mac_f32_e32 v23, v20, v36                                 ; 2c2e4914
	v_mul_f32_e32 v31, v31, v59                                 ; 0a3e771f
	v_mac_f32_e32 v27, v24, v55                                 ; 2c366f18
	v_mac_f32_e32 v31, v30, v60                                 ; 2c3e791e
	v_mac_f32_e32 v31, v29, v61                                 ; 2c3e7b1d
	v_mac_f32_e32 v31, v28, v35                                 ; 2c3e471c
	v_mul_f32_e32 v31, v31, v45                                 ; 0a3e5b1f
	v_mac_f32_e32 v31, v27, v43                                 ; 2c3e571b
	v_mac_f32_e32 v31, v23, v46                                 ; 2c3e5d17
	v_mac_f32_e32 v31, v19, v42                                 ; 2c3e5513
	v_mac_f32_e32 v12, v40, v31                                 ; 2c183f28
BB100:
	v_add_u32_e32 v0, 4, v0                                     ; 68000084
	s_branch BB71                                               ; bf82fcae
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
