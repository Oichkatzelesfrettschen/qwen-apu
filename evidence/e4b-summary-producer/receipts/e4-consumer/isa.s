BB0:
	s_load_dword s0, s[14:15], 0x0                              ; c0020007 00000000
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_mul_i32 s0, s0, s18                                       ; 92001200
	s_add_u32 s16, s16, s0                                      ; 80100010
	s_lshl_b32 s16, s16, 2                                      ; 8e108210
	s_add_u32 s1, s16, 4                                        ; 80018410
	s_cmp_ge_u32 s4, s1                                         ; bf090104
	s_cbranch_scc0 BB42                                         ; bf840312
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
	v_sub_u32_e32 v1, v2, v1                                    ; 6a020302
	v_bfe_u32 v3, v2, 2, 1                                      ; d1c80003 02050502
	v_lshrrev_b32_e32 v2, 3, v2                                 ; 20040483
	v_lshl_add_u32 v1, v1, 1, v3                                ; d1fd0001 040d0301
	v_mov_b32_e32 v3, 0                                         ; 7e060280
	v_lshlrev_b32_e32 v1, 2, v1                                 ; 24020282
	v_lshl_add_u32 v4, v2, 5, v1                                ; d1fd0004 04050b02
	v_lshl_add_u32 v1, v2, 6, v1                                ; d1fd0001 04050d02
	s_branch BB5                                                ; bf8201c9
BB10:
	s_mov_b64 exec, s[0:1]                                      ; befe0100
	s_mov_b32 s0, s2                                            ; be800002
	s_movk_i32 s1, 0x8000                                       ; b0018000
	s_load_dwordx8 s[24:31], s[0:1], 0x0                        ; c00e0600 00000000
	s_mul_i32 s0, s6, s17                                       ; 92001106
	v_lshl_add_u32 v8, v0, 8, v1                                ; d1fd0008 04051100
	v_add_u32_e32 v9, s0, v8                                    ; 68121000
	v_add_u32_e32 v8, 0x80, v8                                  ; 681010ff 00000080
	v_lshrrev_b32_e32 v9, 2, v9                                 ; 20121282
	v_add_u32_e32 v8, s0, v8                                    ; 68101000
	v_lshlrev_b32_e32 v9, 4, v9                                 ; 24121284
	v_lshrrev_b32_e32 v8, 2, v8                                 ; 20101082
	v_lshlrev_b32_e32 v8, 4, v8                                 ; 24101084
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_load_dwordx4 v[12:15], v9, s[28:31], 0 offen         ; e05c1000 80070c09
	buffer_load_dwordx4 v[16:19], v9, s[28:31], 0 offen offset:128 ; e05c1080 80071009
	buffer_load_dwordx4 v[20:23], v8, s[28:31], 0 offen         ; e05c1000 80071408
	buffer_load_dwordx4 v[8:11], v8, s[28:31], 0 offen offset:128 ; e05c1080 80070808
	s_mul_i32 s1, s16, s3                                       ; 92010310
	v_lshlrev_b32_e32 v26, 1, v2                                ; 24340481
	v_add_u32_e32 v34, 64, v4                                   ; 684408c0
	s_add_u32 s1, s18, s1                                       ; 80010112
	s_add_u32 s4, s16, 1                                        ; 80048110
	v_and_b32_e32 v28, -4, v26                                  ; 263834c4
	v_add_u32_e32 v31, 8, v26                                   ; 683e3488
	v_add_u32_e32 v24, s1, v0                                   ; 68300001
	s_mul_i32 s4, s4, s3                                        ; 92040304
	v_lshlrev_b32_e32 v25, 4, v24                               ; 24323084
	s_add_u32 s4, s18, s4                                       ; 80040412
	v_lshl_add_u32 v24, v24, 7, v25                             ; d1fd0018 04650f18
	v_add_u32_e32 v35, s4, v0                                   ; 68460004
	v_add_u32_e32 v27, 4, v24                                   ; 68363084
	v_add_u32_e32 v32, 16, v24                                  ; 68403090
	v_lshlrev_b32_e32 v36, 4, v35                               ; 24484684
	s_add_u32 s5, s16, 2                                        ; 80058210
	v_add_u32_e32 v30, v27, v26                                 ; 683c351b
	v_add_u32_e32 v29, v28, v27                                 ; 683a371c
	v_add_u32_e32 v27, v27, v31                                 ; 68363f1b
	v_add_u32_e32 v33, v32, v4                                  ; 68420920
	v_add_u32_e32 v32, v32, v34                                 ; 68404520
	v_lshl_add_u32 v35, v35, 7, v36                             ; d1fd0023 04910f23
	s_mul_i32 s5, s5, s3                                        ; 92050305
	v_add_u32_e32 v37, 4, v35                                   ; 684a4684
	v_add_u32_e32 v40, 16, v35                                  ; 68504690
	s_add_u32 s5, s18, s5                                       ; 80050512
	v_add_u32_e32 v38, v28, v37                                 ; 684c4b1c
	v_add_u32_e32 v39, v37, v26                                 ; 684e3525
	v_add_u32_e32 v37, v37, v31                                 ; 684a3f25
	s_add_u32 s9, s16, 3                                        ; 80098310
	v_add_u32_e32 v41, v40, v4                                  ; 68520928
	v_add_u32_e32 v40, v40, v34                                 ; 68504528
	v_add_u32_e32 v42, s5, v0                                   ; 68540005
	s_mul_i32 s9, s9, s3                                        ; 92090309
	v_lshlrev_b32_e32 v43, 4, v42                               ; 24565484
	s_add_u32 s9, s18, s9                                       ; 80090912
	v_lshl_add_u32 v42, v42, 7, v43                             ; d1fd002a 04ad0f2a
	v_add_u32_e32 v49, s9, v0                                   ; 68620009
	v_add_u32_e32 v44, 4, v42                                   ; 68585484
	v_add_u32_e32 v47, 16, v42                                  ; 685e5490
	v_lshlrev_b32_e32 v50, 4, v49                               ; 24646284
	v_add_u32_e32 v46, v44, v26                                 ; 685c352c
	v_add_u32_e32 v45, v28, v44                                 ; 685a591c
	v_add_u32_e32 v44, v44, v31                                 ; 68583f2c
	v_add_u32_e32 v48, v47, v4                                  ; 6860092f
	v_add_u32_e32 v47, v47, v34                                 ; 685e452f
	v_lshl_add_u32 v49, v49, 7, v50                             ; d1fd0031 04c90f31
	v_add_u32_e32 v51, 4, v49                                   ; 68666284
	v_add_u32_e32 v52, 16, v49                                  ; 68686290
	v_add_u32_e32 v26, v51, v26                                 ; 68343533
	v_add_u32_e32 v28, v28, v51                                 ; 6838671c
	v_add_u32_e32 v51, v51, v31                                 ; 68663f33
	v_add_u32_e32 v53, v52, v4                                  ; 686a0934
	v_add_u32_e32 v52, v52, v34                                 ; 68684534
	buffer_load_dword v24, v24, s[24:27], 0 offen               ; e0501000 80061818
	buffer_load_dwordx2 v[54:55], v29, s[24:27], 0 offen        ; e0541000 8006361d
	buffer_load_ushort v27, v27, s[24:27], 0 offen              ; e0481000 80061b1b
	buffer_load_dword v33, v33, s[24:27], 0 offen               ; e0501000 80062121
	buffer_load_dword v32, v32, s[24:27], 0 offen               ; e0501000 80062020
	buffer_load_dword v35, v35, s[24:27], 0 offen               ; e0501000 80062323
	buffer_load_dwordx2 v[56:57], v38, s[24:27], 0 offen        ; e0541000 80063826
	buffer_load_ushort v37, v37, s[24:27], 0 offen              ; e0481000 80062525
	buffer_load_dword v41, v41, s[24:27], 0 offen               ; e0501000 80062929
	buffer_load_dword v40, v40, s[24:27], 0 offen               ; e0501000 80062828
	buffer_load_dword v42, v42, s[24:27], 0 offen               ; e0501000 80062a2a
	buffer_load_dwordx2 v[58:59], v45, s[24:27], 0 offen        ; e0541000 80063a2d
	buffer_load_ushort v44, v44, s[24:27], 0 offen              ; e0481000 80062c2c
	buffer_load_dword v48, v48, s[24:27], 0 offen               ; e0501000 80063030
	buffer_load_dword v47, v47, s[24:27], 0 offen               ; e0501000 80062f2f
	buffer_load_dword v49, v49, s[24:27], 0 offen               ; e0501000 80063131
	buffer_load_dwordx2 v[28:29], v28, s[24:27], 0 offen        ; e0541000 80061c1c
	buffer_load_ushort v51, v51, s[24:27], 0 offen              ; e0481000 80063333
	buffer_load_dword v53, v53, s[24:27], 0 offen               ; e0501000 80063535
	buffer_load_dword v52, v52, s[24:27], 0 offen               ; e0501000 80063434
	s_mov_b32 s10, 0xf0f0f0f                                    ; be8a00ff 0f0f0f0f
	s_mov_b32 s11, 0xc0c0c0c0                                   ; be8b00ff c0c0c0c0
	s_mov_b32 s12, 0x3f3f3f3f                                   ; be8c00ff 3f3f3f3f
	v_add_u32_e32 v0, 4, v0                                     ; 68000084
	s_waitcnt vmcnt(23)                                         ; bf8c7f77
	v_add_f32_e32 v60, v12, v13                                 ; 02781b0c
	s_waitcnt vmcnt(22)                                         ; bf8c7f76
	v_add_f32_e32 v61, v16, v17                                 ; 027a2310
	s_waitcnt vmcnt(21)                                         ; bf8c7f75
	v_add_f32_e32 v62, v20, v21                                 ; 027c2b14
	s_waitcnt vmcnt(20)                                         ; bf8c7f74
	v_add_f32_e32 v25, v8, v9                                   ; 02321308
	v_add_f32_e32 v60, v60, v14                                 ; 02781d3c
	v_add_f32_e32 v61, v61, v18                                 ; 027a253d
	v_add_f32_e32 v62, v62, v22                                 ; 027c2d3e
	v_add_f32_e32 v25, v25, v10                                 ; 02321519
	v_add_f32_e32 v60, v60, v15                                 ; 02781f3c
	v_add_f32_e32 v61, v61, v19                                 ; 027a273d
	v_add_f32_e32 v62, v62, v23                                 ; 027c2f3e
	v_add_f32_e32 v25, v25, v11                                 ; 02321719
	s_waitcnt vmcnt(19)                                         ; bf8c7f73
	v_cvt_f32_f16_sdwa v31, v24 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e3e16f9 00050618
	v_cvt_f32_f16_e32 v24, v24                                  ; 7e301718
	s_waitcnt vmcnt(18)                                         ; bf8c7f72
	v_alignbyte_b32 v54, v55, v54, v30                          ; d1cf0036 047a6d37
	v_alignbyte_b32 v55, v55, v55, v30                          ; d1cf0037 047a6f37
	s_waitcnt vmcnt(17)                                         ; bf8c7f71
	v_lshl_or_b32 v27, v27, 12, v27                             ; d200001b 046d191b
	s_waitcnt vmcnt(16)                                         ; bf8c7f70
	v_and_b32_e32 v43, s10, v33                                 ; 2656420a
	v_mov_b32_sdwa v54, v55 dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_0 ; 7e6c02f9 00041537
	v_lshrrev_b32_e32 v33, 4, v33                               ; 20424284
	v_cvt_f32_ubyte2_e32 v50, v43                               ; 7e64272b
	v_cvt_f32_ubyte1_e32 v55, v43                               ; 7e6e252b
	v_cvt_f32_ubyte3_e32 v45, v43                               ; 7e5a292b
	v_cvt_f32_ubyte0_e32 v43, v43                               ; 7e56232b
	v_and_b32_e32 v34, s11, v54                                 ; 26446c0b
	v_and_b32_e32 v54, s12, v54                                 ; 266c6c0c
	v_and_b32_e32 v33, s10, v33                                 ; 2642420a
	v_mul_f32_e32 v45, v15, v45                                 ; 0a5a5b0f
	v_lshrrev_b32_e32 v34, 2, v34                               ; 20444482
	v_cvt_f32_ubyte3_e32 v36, v54                               ; 7e482936
	v_cvt_f32_ubyte2_e32 v38, v54                               ; 7e4c2736
	v_cvt_f32_ubyte3_e32 v30, v33                               ; 7e3c2921
	v_mac_f32_e32 v45, v14, v50                                 ; 2c5a650e
	s_waitcnt vmcnt(15)                                         ; bf8c3f7f
	v_and_b32_e32 v50, s10, v32                                 ; 2664400a
	v_and_or_b32 v27, s10, v27, v34                             ; d201001b 048a360a
	v_cvt_f32_ubyte2_e32 v34, v33                               ; 7e442721
	v_mul_f32_e32 v30, v19, v30                                 ; 0a3c3d13
	v_mac_f32_e32 v45, v13, v55                                 ; 2c5a6f0d
	v_cvt_f32_ubyte3_e32 v55, v50                               ; 7e6e2932
	v_lshrrev_b32_e32 v32, 4, v32                               ; 20404084
	v_mac_f32_e32 v30, v18, v34                                 ; 2c3c4512
	v_cvt_f32_ubyte1_e32 v34, v50                               ; 7e442532
	v_mac_f32_e32 v45, v12, v43                                 ; 2c5a570c
	v_cvt_f32_ubyte1_e32 v43, v33                               ; 7e562521
	v_cvt_f32_ubyte0_e32 v33, v33                               ; 7e422321
	v_mul_f32_e32 v55, v23, v55                                 ; 0a6e6f17
	v_and_b32_e32 v32, s10, v32                                 ; 2640400a
	v_mac_f32_e32 v30, v17, v43                                 ; 2c3c5711
	v_cvt_f32_ubyte3_e32 v43, v32                               ; 7e562920
	v_mac_f32_e32 v30, v16, v33                                 ; 2c3c4310
	v_cvt_f32_ubyte2_e32 v33, v50                               ; 7e422732
	v_cvt_f32_ubyte0_e32 v50, v50                               ; 7e642332
	v_mul_f32_e32 v43, v11, v43                                 ; 0a56570b
	v_mac_f32_e32 v55, v22, v33                                 ; 2c6e4316
	v_cvt_f32_ubyte1_e32 v33, v32                               ; 7e422520
	v_mac_f32_e32 v55, v21, v34                                 ; 2c6e4515
	v_cvt_f32_ubyte3_e32 v34, v27                               ; 7e44291b
	v_mac_f32_e32 v55, v20, v50                                 ; 2c6e6514
	v_cvt_f32_ubyte2_e32 v50, v32                               ; 7e642720
	v_cvt_f32_ubyte0_e32 v32, v32                               ; 7e402320
	v_mul_f32_e32 v34, v25, v34                                 ; 0a444519
	v_mac_f32_e32 v43, v10, v50                                 ; 2c56650a
	v_cvt_f32_ubyte2_e32 v50, v27                               ; 7e64271b
	v_mac_f32_e32 v43, v9, v33                                  ; 2c564309
	v_cvt_f32_ubyte1_e32 v33, v54                               ; 7e422536
	v_cvt_f32_ubyte0_e32 v54, v54                               ; 7e6c2336
	v_mac_f32_e32 v34, v62, v50                                 ; 2c44653e
	v_mac_f32_e32 v43, v8, v32                                  ; 2c564108
	v_cvt_f32_ubyte1_e32 v32, v27                               ; 7e40251b
	v_cvt_f32_ubyte0_e32 v27, v27                               ; 7e36231b
	s_waitcnt vmcnt(13)                                         ; bf8c3f7d
	v_alignbyte_b32 v56, v57, v56, v39                          ; d1cf0038 049e7139
	v_alignbyte_b32 v57, v57, v57, v39                          ; d1cf0039 049e7339
	v_mac_f32_e32 v34, v61, v36                                 ; 2c44493d
	v_mul_f32_e32 v43, v43, v32                                 ; 0a56412b
	v_mov_b32_sdwa v56, v57 dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_0 ; 7e7002f9 00041539
	v_mac_f32_e32 v34, v60, v38                                 ; 2c444d3c
	s_waitcnt vmcnt(12)                                         ; bf8c3f7c
	v_lshl_or_b32 v37, v37, 12, v37                             ; d2000025 04951925
	v_mac_f32_e32 v43, v55, v27                                 ; 2c563737
	v_and_b32_e32 v36, s11, v56                                 ; 2648700b
	v_and_b32_e32 v56, s12, v56                                 ; 2670700c
	v_mad_f32 v3, -v31, v34, v3                                 ; d1c10003 240e451f
	v_cvt_f32_f16_sdwa v34, v35 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e4416f9 00050623
	v_cvt_f32_f16_e32 v35, v35                                  ; 7e461723
	v_mac_f32_e32 v43, v30, v33                                 ; 2c56431e
	v_lshrrev_b32_e32 v36, 2, v36                               ; 20484882
	v_cvt_f32_ubyte2_e32 v39, v56                               ; 7e4e2738
	v_cvt_f32_ubyte3_e32 v38, v56                               ; 7e4c2938
	v_mac_f32_e32 v43, v45, v54                                 ; 2c566d2d
	v_and_or_b32 v37, s10, v37, v36                             ; d2010025 04924a0a
	s_waitcnt vmcnt(11)                                         ; bf8c3f7b
	v_and_b32_e32 v55, s10, v41                                 ; 266e520a
	v_mac_f32_e32 v3, v24, v43                                  ; 2c065718
	v_cvt_f32_ubyte1_e32 v43, v56                               ; 7e562538
	v_cvt_f32_ubyte0_e32 v56, v56                               ; 7e702338
	v_cvt_f32_ubyte2_e32 v50, v37                               ; 7e642725
	v_cvt_f32_ubyte3_e32 v45, v37                               ; 7e5a2925
	v_cvt_f32_ubyte1_e32 v54, v37                               ; 7e6c2525
	v_cvt_f32_ubyte0_e32 v37, v37                               ; 7e4a2325
	v_cvt_f32_ubyte2_e32 v24, v55                               ; 7e302737
	v_cvt_f32_ubyte3_e32 v57, v55                               ; 7e722937
	v_cvt_f32_ubyte1_e32 v27, v55                               ; 7e362537
	v_cvt_f32_ubyte0_e32 v55, v55                               ; 7e6e2337
	v_lshrrev_b32_e32 v41, 4, v41                               ; 20525284
	v_mul_f32_e32 v45, v25, v45                                 ; 0a5a5b19
	v_mul_f32_e32 v57, v15, v57                                 ; 0a72730f
	v_and_b32_e32 v41, s10, v41                                 ; 2652520a
	v_mac_f32_e32 v45, v62, v50                                 ; 2c5a653e
	v_mac_f32_e32 v57, v14, v24                                 ; 2c72310e
	s_waitcnt vmcnt(10)                                         ; bf8c3f7a
	v_and_b32_e32 v33, s10, v40                                 ; 2642500a
	v_cvt_f32_ubyte1_e32 v32, v41                               ; 7e402529
	v_cvt_f32_ubyte3_e32 v30, v41                               ; 7e3c2929
	v_cvt_f32_ubyte2_e32 v31, v41                               ; 7e3e2729
	v_cvt_f32_ubyte0_e32 v41, v41                               ; 7e522329
	v_mac_f32_e32 v45, v61, v38                                 ; 2c5a4d3d
	v_mac_f32_e32 v57, v13, v27                                 ; 2c72370d
	v_cvt_f32_ubyte2_e32 v36, v33                               ; 7e482721
	v_cvt_f32_ubyte1_e32 v38, v33                               ; 7e4c2521
	v_mul_f32_e32 v30, v19, v30                                 ; 0a3c3d13
	v_lshrrev_b32_e32 v40, 4, v40                               ; 20505084
	v_mac_f32_e32 v45, v60, v39                                 ; 2c5a4f3c
	v_mac_f32_e32 v57, v12, v55                                 ; 2c726f0c
	v_mac_f32_e32 v30, v18, v31                                 ; 2c3c3f12
	v_and_b32_e32 v40, s10, v40                                 ; 2650500a
	v_mad_f32 v5, -v34, v45, v5                                 ; d1c10005 24165b22
	v_cvt_f32_ubyte3_e32 v34, v33                               ; 7e442921
	v_cvt_f32_ubyte0_e32 v33, v33                               ; 7e422321
	v_mac_f32_e32 v30, v17, v32                                 ; 2c3c4111
	v_cvt_f32_ubyte1_e32 v45, v40                               ; 7e5a2528
	v_cvt_f32_ubyte3_e32 v39, v40                               ; 7e4e2928
	v_mul_f32_e32 v34, v23, v34                                 ; 0a444517
	v_mac_f32_e32 v30, v16, v41                                 ; 2c3c5310
	v_cvt_f32_ubyte2_e32 v41, v40                               ; 7e522728
	v_cvt_f32_ubyte0_e32 v40, v40                               ; 7e502328
	v_mul_f32_e32 v39, v11, v39                                 ; 0a4e4f0b
	s_waitcnt vmcnt(9)                                          ; bf8c3f79
	v_cvt_f32_f16_sdwa v50, v42 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e6416f9 0005062a
	v_mac_f32_e32 v34, v22, v36                                 ; 2c444916
	v_cvt_f32_f16_e32 v42, v42                                  ; 7e54172a
	s_waitcnt vmcnt(8)                                          ; bf8c3f78
	v_alignbyte_b32 v58, v59, v58, v46                          ; d1cf003a 04ba753b
	v_alignbyte_b32 v59, v59, v59, v46                          ; d1cf003b 04ba773b
	v_mac_f32_e32 v39, v10, v41                                 ; 2c4e530a
	v_mac_f32_e32 v34, v21, v38                                 ; 2c444d15
	s_waitcnt vmcnt(7)                                          ; bf8c3f77
	v_lshl_or_b32 v44, v44, 12, v44                             ; d200002c 04b1192c
	v_mov_b32_sdwa v58, v59 dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_0 ; 7e7402f9 0004153b
	v_mac_f32_e32 v39, v9, v45                                  ; 2c4e5b09
	v_mac_f32_e32 v34, v20, v33                                 ; 2c444314
	v_mac_f32_e32 v39, v8, v40                                  ; 2c4e5108
	v_mul_f32_e32 v39, v39, v54                                 ; 0a4e6d27
	v_and_b32_e32 v54, s11, v58                                 ; 266c740b
	v_and_b32_e32 v58, s12, v58                                 ; 2674740c
	v_mac_f32_e32 v39, v34, v37                                 ; 2c4e4b22
	v_lshrrev_b32_e32 v54, 2, v54                               ; 206c6c82
	v_mac_f32_e32 v39, v30, v43                                 ; 2c4e571e
	v_and_or_b32 v44, s10, v44, v54                             ; d201002c 04da580a
	v_mac_f32_e32 v39, v57, v56                                 ; 2c4e7139
	s_waitcnt vmcnt(6)                                          ; bf8c3f76
	v_and_b32_e32 v56, s10, v48                                 ; 2670600a
	v_lshrrev_b32_e32 v48, 4, v48                               ; 20606084
	v_cvt_f32_ubyte3_e32 v55, v44                               ; 7e6e292c
	v_mac_f32_e32 v5, v35, v39                                  ; 2c0a4f23
	v_cvt_f32_ubyte1_e32 v24, v56                               ; 7e302538
	v_cvt_f32_ubyte3_e32 v57, v56                               ; 7e722938
	v_cvt_f32_ubyte2_e32 v59, v56                               ; 7e762738
	v_cvt_f32_ubyte0_e32 v56, v56                               ; 7e702338
	v_and_b32_e32 v48, s10, v48                                 ; 2660600a
	s_waitcnt vmcnt(5)                                          ; bf8c3f75
	v_and_b32_e32 v32, s10, v47                                 ; 26405e0a
	v_mul_f32_e32 v57, v15, v57                                 ; 0a72730f
	v_cvt_f32_ubyte2_e32 v30, v48                               ; 7e3c2730
	v_cvt_f32_ubyte3_e32 v27, v48                               ; 7e362930
	v_cvt_f32_ubyte1_e32 v31, v48                               ; 7e3e2530
	v_cvt_f32_ubyte0_e32 v48, v48                               ; 7e602330
	v_cvt_f32_ubyte1_e32 v35, v32                               ; 7e462520
	v_cvt_f32_ubyte2_e32 v34, v32                               ; 7e442720
	v_cvt_f32_ubyte3_e32 v33, v32                               ; 7e422920
	v_mac_f32_e32 v57, v14, v59                                 ; 2c72770e
	v_cvt_f32_ubyte0_e32 v32, v32                               ; 7e402320
	v_mul_f32_e32 v27, v19, v27                                 ; 0a363713
	v_lshrrev_b32_e32 v47, 4, v47                               ; 205e5e84
	v_mul_f32_e32 v33, v23, v33                                 ; 0a424317
	v_mac_f32_e32 v57, v13, v24                                 ; 2c72310d
	v_mac_f32_e32 v27, v18, v30                                 ; 2c363d12
	v_and_b32_e32 v47, s10, v47                                 ; 265e5e0a
	v_mac_f32_e32 v33, v22, v34                                 ; 2c424516
	v_mul_f32_e32 v55, v25, v55                                 ; 0a6e6f19
	v_mac_f32_e32 v57, v12, v56                                 ; 2c72710c
	v_cvt_f32_ubyte2_e32 v39, v44                               ; 7e4e272c
	v_mac_f32_e32 v27, v17, v31                                 ; 2c363f11
	v_cvt_f32_ubyte2_e32 v37, v47                               ; 7e4a272f
	v_cvt_f32_ubyte3_e32 v36, v47                               ; 7e48292f
	v_cvt_f32_ubyte1_e32 v38, v47                               ; 7e4c252f
	v_cvt_f32_ubyte0_e32 v47, v47                               ; 7e5e232f
	v_mac_f32_e32 v33, v21, v35                                 ; 2c424715
	v_cvt_f32_ubyte3_e32 v40, v58                               ; 7e50293a
	v_cvt_f32_ubyte2_e32 v41, v58                               ; 7e52273a
	v_mac_f32_e32 v55, v62, v39                                 ; 2c6e4f3e
	v_mac_f32_e32 v27, v16, v48                                 ; 2c366110
	v_cvt_f32_ubyte1_e32 v43, v44                               ; 7e56252c
	v_mul_f32_e32 v36, v11, v36                                 ; 0a48490b
	v_cvt_f32_ubyte0_e32 v44, v44                               ; 7e58232c
	v_mac_f32_e32 v33, v20, v32                                 ; 2c424114
	v_mac_f32_e32 v55, v61, v40                                 ; 2c6e513d
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_alignbyte_b32 v28, v29, v28, v26                          ; d1cf001c 046a391d
	v_mac_f32_e32 v36, v10, v37                                 ; 2c484b0a
	v_alignbyte_b32 v29, v29, v29, v26                          ; d1cf001d 046a3b1d
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_lshl_or_b32 v51, v51, 12, v51                             ; d2000033 04cd1933
	v_mac_f32_e32 v55, v60, v41                                 ; 2c6e533c
	v_mac_f32_e32 v36, v9, v38                                  ; 2c484d09
	v_mov_b32_sdwa v28, v29 dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_0 ; 7e3802f9 0004151d
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v46, s10, v53                                 ; 265c6a0a
	v_mad_f32 v6, -v50, v55, v6                                 ; d1c10006 241a6f32
	v_mac_f32_e32 v36, v8, v47                                  ; 2c485f08
	v_and_b32_e32 v45, s11, v28                                 ; 265a380b
	v_cvt_f32_ubyte1_e32 v50, v46                               ; 7e64252e
	v_cvt_f32_ubyte3_e32 v47, v46                               ; 7e5e292e
	v_cvt_f32_ubyte2_e32 v48, v46                               ; 7e60272e
	v_mul_f32_e32 v36, v36, v43                                 ; 0a485724
	v_cvt_f32_ubyte0_e32 v46, v46                               ; 7e5c232e
	v_lshrrev_b32_e32 v45, 2, v45                               ; 205a5a82
	v_lshrrev_b32_e32 v53, 4, v53                               ; 206a6a84
	v_mul_f32_e32 v15, v15, v47                                 ; 0a1e5f0f
	v_mac_f32_e32 v36, v33, v44                                 ; 2c485921
	v_cvt_f32_ubyte1_e32 v44, v58                               ; 7e58253a
	v_cvt_f32_ubyte0_e32 v58, v58                               ; 7e74233a
	v_and_or_b32 v51, s10, v51, v45                             ; d2010033 04b6660a
	v_and_b32_e32 v53, s10, v53                                 ; 266a6a0a
	v_mac_f32_e32 v15, v14, v48                                 ; 2c1e610e
	v_mac_f32_e32 v36, v27, v44                                 ; 2c48591b
	v_cvt_f32_ubyte2_e32 v55, v53                               ; 7e6e2735
	v_cvt_f32_ubyte3_e32 v54, v53                               ; 7e6c2935
	v_cvt_f32_ubyte1_e32 v56, v53                               ; 7e702535
	v_cvt_f32_ubyte0_e32 v53, v53                               ; 7e6a2335
	v_mac_f32_e32 v15, v13, v50                                 ; 2c1e650d
	v_mac_f32_e32 v36, v57, v58                                 ; 2c487539
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v57, s10, v52                                 ; 2672680a
	v_mul_f32_e32 v19, v19, v54                                 ; 0a266d13
	v_mac_f32_e32 v15, v12, v46                                 ; 2c1e5d0c
	v_lshrrev_b32_e32 v52, 4, v52                               ; 20686884
	v_mac_f32_e32 v6, v42, v36                                  ; 2c0c492a
	v_cvt_f32_ubyte1_e32 v12, v57                               ; 7e182539
	v_cvt_f32_ubyte2_e32 v59, v57                               ; 7e762739
	v_cvt_f32_ubyte3_e32 v58, v57                               ; 7e742939
	v_cvt_f32_ubyte0_e32 v57, v57                               ; 7e722339
	v_mac_f32_e32 v19, v18, v55                                 ; 2c266f12
	v_and_b32_e32 v52, s10, v52                                 ; 2668680a
	v_mul_f32_e32 v23, v23, v58                                 ; 0a2e7517
	v_mac_f32_e32 v19, v17, v56                                 ; 2c267111
	v_cvt_f32_ubyte3_e32 v17, v51                               ; 7e222933
	v_cvt_f32_ubyte2_e32 v14, v52                               ; 7e1c2734
	v_cvt_f32_ubyte2_e32 v18, v51                               ; 7e242733
	v_cvt_f32_ubyte3_e32 v13, v52                               ; 7e1a2934
	v_mac_f32_e32 v23, v22, v59                                 ; 2c2e7716
	v_mac_f32_e32 v19, v16, v53                                 ; 2c266b10
	v_cvt_f32_ubyte1_e32 v16, v52                               ; 7e202534
	v_cvt_f32_ubyte0_e32 v52, v52                               ; 7e682334
	v_and_b32_e32 v28, s12, v28                                 ; 2638380c
	v_mul_f32_e32 v25, v25, v17                                 ; 0a322319
	v_mul_f32_e32 v11, v11, v13                                 ; 0a161b0b
	v_cvt_f32_ubyte1_e32 v22, v51                               ; 7e2c2533
	v_mac_f32_e32 v23, v21, v12                                 ; 2c2e1915
	v_cvt_f32_ubyte0_e32 v51, v51                               ; 7e662333
	v_cvt_f32_ubyte2_e32 v21, v28                               ; 7e2a271c
	v_mac_f32_e32 v25, v62, v18                                 ; 2c32253e
	v_mac_f32_e32 v11, v10, v14                                 ; 2c161d0a
	v_mac_f32_e32 v23, v20, v57                                 ; 2c2e7314
	v_cvt_f32_ubyte3_e32 v20, v28                               ; 7e28291c
	v_cvt_f32_f16_sdwa v24, v49 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e3016f9 00050631
	v_cvt_f32_f16_e32 v49, v49                                  ; 7e621731
	v_mac_f32_e32 v11, v9, v16                                  ; 2c162109
	v_mac_f32_e32 v25, v61, v20                                 ; 2c32293d
	v_mac_f32_e32 v11, v8, v52                                  ; 2c166908
	v_mac_f32_e32 v25, v60, v21                                 ; 2c322b3c
	v_mul_f32_e32 v11, v11, v22                                 ; 0a162d0b
	v_mad_f32 v7, -v24, v25, v7                                 ; d1c10007 241e3318
	v_mac_f32_e32 v11, v23, v51                                 ; 2c166717
	v_cvt_f32_ubyte1_e32 v23, v28                               ; 7e2e251c
	v_cvt_f32_ubyte0_e32 v28, v28                               ; 7e38231c
	v_mac_f32_e32 v11, v19, v23                                 ; 2c162f13
	v_mac_f32_e32 v11, v15, v28                                 ; 2c16390f
	v_mac_f32_e32 v7, v49, v11                                  ; 2c0e1731
BB5:
	s_mov_b64 s[0:1], exec                                      ; be80017e
	v_cmpx_le_u32_e32 vcc, s3, v0                               ; 7db60003
BB6:
	s_andn2_b64 s[0:1], s[0:1], exec                            ; 89807e00
	s_cbranch_scc1 BB10                                         ; bf85fe33
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
	s_branch BB119                                              ; bf820338
BB42:
	s_cmp_lt_u32 s16, s4                                        ; bf0a0410
	s_cbranch_scc0 BB119                                        ; bf840336
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
	v_mov_b32_e32 v5, 0                                         ; 7e0a0280
	v_mov_b32_e32 v6, 0                                         ; 7e0c0280
	v_mov_b32_e32 v7, 0                                         ; 7e0e0280
	s_mul_i32 s19, s19, s5                                      ; 92130513
	v_sub_u32_e32 v1, v2, v1                                    ; 6a020302
	v_bfe_u32 v3, v2, 2, 1                                      ; d1c80003 02050502
	v_lshrrev_b32_e32 v2, 3, v2                                 ; 20040483
	v_lshl_add_u32 v1, v1, 1, v3                                ; d1fd0001 040d0301
	v_mov_b32_e32 v3, 0                                         ; 7e060280
	v_lshlrev_b32_e32 v1, 2, v1                                 ; 24020282
	v_lshl_add_u32 v4, v2, 5, v1                                ; d1fd0004 04050b02
	v_lshl_add_u32 v1, v2, 6, v1                                ; d1fd0001 04050d02
BB47:
	s_mov_b64 s[0:1], exec                                      ; be80017e
	v_cmpx_le_u32_e32 vcc, s3, v0                               ; 7db60003
BB48:
	s_andn2_b64 s[0:1], s[0:1], exec                            ; 89807e00
	s_cbranch_scc0 BB65                                         ; bf8401e1
BB52:
	s_mov_b64 exec, s[0:1]                                      ; befe0100
	s_mov_b32 s0, s2                                            ; be800002
	s_movk_i32 s1, 0x8000                                       ; b0018000
	s_load_dwordx4 s[12:15], s[0:1], 0x10                       ; c00a0300 00000010
	s_mul_i32 s5, s6, s17                                       ; 92051106
	v_lshl_add_u32 v8, v0, 8, v1                                ; d1fd0008 04051100
	v_add_u32_e32 v9, s5, v8                                    ; 68121005
	v_add_u32_e32 v8, 0x80, v8                                  ; 681010ff 00000080
	v_lshrrev_b32_e32 v9, 2, v9                                 ; 20121282
	v_add_u32_e32 v8, s5, v8                                    ; 68101005
	v_lshlrev_b32_e32 v9, 4, v9                                 ; 24121284
	v_lshrrev_b32_e32 v8, 2, v8                                 ; 20101082
	v_lshlrev_b32_e32 v8, 4, v8                                 ; 24101084
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_load_dwordx4 v[12:15], v9, s[12:15], 0 offen         ; e05c1000 80030c09
	buffer_load_dwordx4 v[16:19], v9, s[12:15], 0 offen offset:128 ; e05c1080 80031009
	buffer_load_dwordx4 v[20:23], v8, s[12:15], 0 offen         ; e05c1000 80031408
	buffer_load_dwordx4 v[8:11], v8, s[12:15], 0 offen offset:128 ; e05c1080 80030808
	s_cmp_lg_i32 s4, 0                                          ; bf018004
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_add_f32_e32 v24, v12, v13                                 ; 02301b0c
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_add_f32_e32 v25, v16, v17                                 ; 02322310
	v_add_f32_e32 v24, v24, v14                                 ; 02301d18
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_add_f32_e32 v26, v20, v21                                 ; 02342b14
	v_add_f32_e32 v25, v25, v18                                 ; 02322519
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_add_f32_e32 v27, v8, v9                                   ; 02361308
	v_add_f32_e32 v24, v24, v15                                 ; 02301f18
	v_add_f32_e32 v26, v26, v22                                 ; 02342d1a
	v_add_f32_e32 v25, v25, v19                                 ; 02322719
	v_add_f32_e32 v27, v27, v10                                 ; 0236151b
	v_add_f32_e32 v26, v26, v23                                 ; 02342f1a
	v_add_f32_e32 v27, v27, v11                                 ; 0236171b
	s_cbranch_scc0 BB64                                         ; bf8401b4
BB53:
	s_load_dwordx4 s[12:15], s[0:1], 0x0                        ; c00a0300 00000000
	s_mul_i32 s0, s16, s3                                       ; 92000310
	v_lshlrev_b32_e32 v30, 1, v2                                ; 243c0481
	v_add_u32_e32 v38, 64, v4                                   ; 684c08c0
	s_add_u32 s0, s19, s0                                       ; 80000013
	v_and_b32_e32 v32, -4, v30                                  ; 26403cc4
	v_add_u32_e32 v35, 8, v30                                   ; 68463c88
	v_add_u32_e32 v28, s0, v0                                   ; 68380000
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
	buffer_load_dword v28, v28, s[12:15], 0 offen               ; e0501000 80031c1c
	buffer_load_dwordx2 v[40:41], v33, s[12:15], 0 offen        ; e0541000 80032821
	buffer_load_ushort v31, v31, s[12:15], 0 offen              ; e0481000 80031f1f
	buffer_load_dword v37, v37, s[12:15], 0 offen               ; e0501000 80032525
	buffer_load_dword v36, v36, s[12:15], 0 offen               ; e0501000 80032424
	s_mov_b32 s1, 0xf0f0f0f                                     ; be8100ff 0f0f0f0f
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
	v_and_b32_e32 v48, s1, v37                                  ; 26604a01
	v_cvt_f32_ubyte3_e32 v42, v40                               ; 7e542928
	v_cvt_f32_ubyte2_e32 v43, v40                               ; 7e562728
	v_cvt_f32_ubyte1_e32 v44, v40                               ; 7e582528
	v_cvt_f32_ubyte0_e32 v40, v40                               ; 7e502328
	v_and_or_b32 v31, s1, v31, v41                              ; d201001f 04a63e01
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
	v_and_b32_e32 v37, s1, v37                                  ; 264a4a01
	v_mac_f32_e32 v49, v14, v50                                 ; 2c62650e
	v_mac_f32_e32 v45, v26, v46                                 ; 2c5a5d1a
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v55, s1, v36                                  ; 266e4801
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
	v_and_b32_e32 v36, s1, v36                                  ; 26484801
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
	s_cbranch_scc0 BB64                                         ; bf840142
BB54:
	s_add_u32 s0, s16, 1                                        ; 80008110
	s_mul_i32 s0, s0, s3                                        ; 92000300
	s_add_u32 s0, s19, s0                                       ; 80000013
	v_add_u32_e32 v28, s0, v0                                   ; 68380000
	v_lshlrev_b32_e32 v29, 4, v28                               ; 243a3884
	v_lshl_add_u32 v28, v28, 7, v29                             ; d1fd001c 04750f1c
	v_add_u32_e32 v31, 4, v28                                   ; 683e3884
	v_add_u32_e32 v36, 16, v28                                  ; 68483890
	v_add_u32_e32 v33, v32, v31                                 ; 68423f20
	v_add_u32_e32 v34, v31, v30                                 ; 68443d1f
	v_add_u32_e32 v31, v31, v35                                 ; 683e471f
	v_add_u32_e32 v37, v36, v4                                  ; 684a0924
	v_add_u32_e32 v36, v36, v38                                 ; 68484d24
	buffer_load_dword v28, v28, s[12:15], 0 offen               ; e0501000 80031c1c
	buffer_load_dwordx2 v[40:41], v33, s[12:15], 0 offen        ; e0541000 80032821
	buffer_load_ushort v31, v31, s[12:15], 0 offen              ; e0481000 80031f1f
	buffer_load_dword v37, v37, s[12:15], 0 offen               ; e0501000 80032525
	buffer_load_dword v36, v36, s[12:15], 0 offen               ; e0501000 80032424
	s_mov_b32 s1, 0xf0f0f0f                                     ; be8100ff 0f0f0f0f
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
	v_and_b32_e32 v48, s1, v37                                  ; 26604a01
	v_cvt_f32_ubyte3_e32 v42, v40                               ; 7e542928
	v_cvt_f32_ubyte2_e32 v43, v40                               ; 7e562728
	v_cvt_f32_ubyte1_e32 v44, v40                               ; 7e582528
	v_cvt_f32_ubyte0_e32 v40, v40                               ; 7e502328
	v_and_or_b32 v31, s1, v31, v41                              ; d201001f 04a63e01
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
	v_and_b32_e32 v37, s1, v37                                  ; 264a4a01
	v_mac_f32_e32 v45, v26, v46                                 ; 2c5a5d1a
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v55, s1, v36                                  ; 266e4801
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
	v_and_b32_e32 v36, s1, v36                                  ; 26484801
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
	s_cbranch_scc0 BB64                                         ; bf8400d6
BB55:
	s_add_u32 s0, s16, 2                                        ; 80008210
	s_mul_i32 s0, s0, s3                                        ; 92000300
	s_add_u32 s0, s19, s0                                       ; 80000013
	v_add_u32_e32 v28, s0, v0                                   ; 68380000
	v_lshlrev_b32_e32 v29, 4, v28                               ; 243a3884
	v_lshl_add_u32 v28, v28, 7, v29                             ; d1fd001c 04750f1c
	v_add_u32_e32 v31, 4, v28                                   ; 683e3884
	v_add_u32_e32 v36, 16, v28                                  ; 68483890
	v_add_u32_e32 v33, v32, v31                                 ; 68423f20
	v_add_u32_e32 v34, v31, v30                                 ; 68443d1f
	v_add_u32_e32 v31, v31, v35                                 ; 683e471f
	v_add_u32_e32 v37, v36, v4                                  ; 684a0924
	v_add_u32_e32 v36, v36, v38                                 ; 68484d24
	buffer_load_dword v28, v28, s[12:15], 0 offen               ; e0501000 80031c1c
	buffer_load_dwordx2 v[40:41], v33, s[12:15], 0 offen        ; e0541000 80032821
	buffer_load_ushort v31, v31, s[12:15], 0 offen              ; e0481000 80031f1f
	buffer_load_dword v37, v37, s[12:15], 0 offen               ; e0501000 80032525
	buffer_load_dword v36, v36, s[12:15], 0 offen               ; e0501000 80032424
	s_mov_b32 s1, 0xf0f0f0f                                     ; be8100ff 0f0f0f0f
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
	v_and_b32_e32 v48, s1, v37                                  ; 26604a01
	v_cvt_f32_ubyte3_e32 v42, v40                               ; 7e542928
	v_cvt_f32_ubyte2_e32 v43, v40                               ; 7e562728
	v_cvt_f32_ubyte1_e32 v44, v40                               ; 7e582528
	v_cvt_f32_ubyte0_e32 v40, v40                               ; 7e502328
	v_and_or_b32 v31, s1, v31, v41                              ; d201001f 04a63e01
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
	v_and_b32_e32 v37, s1, v37                                  ; 264a4a01
	v_mac_f32_e32 v45, v26, v46                                 ; 2c5a5d1a
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v55, s1, v36                                  ; 266e4801
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
	v_and_b32_e32 v36, s1, v36                                  ; 26484801
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
	s_cbranch_scc0 BB64                                         ; bf84006a
BB56:
	s_add_u32 s0, s16, 3                                        ; 80008310
	s_mul_i32 s0, s0, s3                                        ; 92000300
	s_add_u32 s0, s19, s0                                       ; 80000013
	v_add_u32_e32 v28, s0, v0                                   ; 68380000
	v_lshlrev_b32_e32 v29, 4, v28                               ; 243a3884
	v_lshl_add_u32 v28, v28, 7, v29                             ; d1fd001c 04750f1c
	v_add_u32_e32 v31, 4, v28                                   ; 683e3884
	v_add_u32_e32 v33, 16, v28                                  ; 68423890
	v_add_u32_e32 v32, v32, v31                                 ; 68403f20
	v_add_u32_e32 v30, v31, v30                                 ; 683c3d1f
	v_add_u32_e32 v31, v31, v35                                 ; 683e471f
	v_add_u32_e32 v34, v33, v4                                  ; 68440921
	v_add_u32_e32 v33, v33, v38                                 ; 68424d21
	buffer_load_dword v28, v28, s[12:15], 0 offen               ; e0501000 80031c1c
	buffer_load_dwordx2 v[36:37], v32, s[12:15], 0 offen        ; e0541000 80032420
	buffer_load_ushort v31, v31, s[12:15], 0 offen              ; e0481000 80031f1f
	buffer_load_dword v34, v34, s[12:15], 0 offen               ; e0501000 80032222
	buffer_load_dword v33, v33, s[12:15], 0 offen               ; e0501000 80032121
	s_mov_b32 s1, 0xf0f0f0f                                     ; be8100ff 0f0f0f0f
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
	v_and_b32_e32 v44, s1, v34                                  ; 26584401
	v_cvt_f32_ubyte3_e32 v38, v36                               ; 7e4c2924
	v_cvt_f32_ubyte2_e32 v39, v36                               ; 7e4e2724
	v_cvt_f32_ubyte1_e32 v40, v36                               ; 7e502524
	v_cvt_f32_ubyte0_e32 v36, v36                               ; 7e482324
	v_and_or_b32 v31, s1, v31, v37                              ; d201001f 04963e01
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
	v_and_b32_e32 v34, s1, v34                                  ; 26444401
	v_mac_f32_e32 v27, v26, v42                                 ; 2c36551a
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v51, s1, v33                                  ; 26664201
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
	v_and_b32_e32 v33, s1, v33                                  ; 26424201
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
BB64:
	v_add_u32_e32 v0, 4, v0                                     ; 68000084
	s_branch BB47                                               ; bf82fe1b
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
	s_cbranch_scc0 BB73                                         ; bf840034
BB68:
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
	s_cbranch_scc0 BB71                                         ; bf840019
BB69:
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
BB71:
	v_mov_b32_e32 v6, s6                                        ; 7e0c0206
BB73:
	v_mov_b32_e32 v5, s5                                        ; 7e0a0205
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
	v_add_f32_e32 v5, s5, v5                                    ; 020a0a05
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
	v_add_f32_e32 v5, s5, v5                                    ; 020a0a05
	s_branch BB91                                               ; bf820001
BB90:
	s_mov_b32 s0, src_scc                                       ; be8000fd
BB91:
	s_add_u32 s5, s7, 4                                         ; 80058407
	buffer_store_dword v5, off, s[8:11], s5                     ; e0700000 05020580
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
	v_add_f32_e32 v6, s5, v6                                    ; 020c0c05
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
	v_add_f32_e32 v6, s5, v6                                    ; 020c0c05
	s_branch BB98                                               ; bf820001
BB97:
	s_mov_b32 s0, src_scc                                       ; be8000fd
BB98:
	s_add_u32 s5, s7, 8                                         ; 80058807
	buffer_store_dword v6, off, s[8:11], s5                     ; e0700000 05020680
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
	v_add_f32_e32 v7, s1, v7                                    ; 020e0e01
BB102:
	s_cmp_lg_i32 s0, 0                                          ; bf018000
	s_cbranch_scc0 BB105                                        ; bf840008
BB103:
	s_load_dwordx4 s[0:3], s[2:3], 0x40                         ; c00a0001 00000040
	s_add_u32 s4, s7, 12                                        ; 80048c07
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s4, s[0:3], s4                          ; c0200100 00000004
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v7, s4, v7                                    ; 020e0e04
BB105:
	s_add_u32 s7, s7, 12                                        ; 80078c07
	buffer_store_dword v7, off, s[8:11], s7                     ; e0700000 07020780
BB119:
	s_endpgm                                                    ; bf810000
