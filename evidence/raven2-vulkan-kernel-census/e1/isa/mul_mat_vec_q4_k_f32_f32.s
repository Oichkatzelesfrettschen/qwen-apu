Compute Shader
BB0:
	s_load_dword s0, s[14:15], 0x0                              ; c0020007 00000000
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_mul_i32 s0, s0, s18                                       ; 92001200
	s_add_u32 s16, s16, s0                                      ; 80100010
	s_lshl_b32 s16, s16, 2                                      ; 8e108210
	s_add_u32 s1, s16, 4                                        ; 80018410
	s_cmp_ge_u32 s4, s1                                         ; bf090104
	s_cbranch_scc0 BB42                                         ; bf840335
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
	s_branch BB5                                                ; bf8201ec
BB10:
	s_mov_b64 exec, s[0:1]                                      ; befe0100
	s_mov_b32 s0, s2                                            ; be800002
	s_movk_i32 s1, 0x8000                                       ; b0018000
	s_load_dwordx8 s[24:31], s[0:1], 0x0                        ; c00e0600 00000000
	s_mul_i32 s0, s16, s3                                       ; 92000310
	v_lshlrev_b32_e32 v10, 1, v2                                ; 24140481
	v_add_u32_e32 v18, 64, v4                                   ; 682408c0
	s_add_u32 s0, s18, s0                                       ; 80000012
	v_and_b32_e32 v12, -4, v10                                  ; 261814c4
	v_add_u32_e32 v15, 8, v10                                   ; 681e1488
	v_add_u32_e32 v8, s0, v0                                    ; 68100000
	v_lshlrev_b32_e32 v9, 4, v8                                 ; 24121084
	v_lshl_add_u32 v8, v8, 7, v9                                ; d1fd0008 04250f08
	v_add_u32_e32 v16, 16, v8                                   ; 68201090
	v_add_u32_e32 v11, 4, v8                                    ; 68161084
	v_add_u32_e32 v17, v16, v4                                  ; 68220910
	v_add_u32_e32 v16, v16, v18                                 ; 68202510
	v_add_u32_e32 v13, v12, v11                                 ; 681a170c
	v_add_u32_e32 v14, v11, v10                                 ; 681c150b
	v_add_u32_e32 v11, v11, v15                                 ; 68161f0b
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_load_dword v8, v8, s[24:27], 0 offen                 ; e0501000 80060808
	buffer_load_dwordx2 v[20:21], v13, s[24:27], 0 offen        ; e0541000 8006140d
	buffer_load_ushort v11, v11, s[24:27], 0 offen              ; e0481000 80060b0b
	buffer_load_dword v17, v17, s[24:27], 0 offen               ; e0501000 80061111
	buffer_load_dword v16, v16, s[24:27], 0 offen               ; e0501000 80061010
	v_lshl_add_u32 v19, v0, 8, v1                               ; d1fd0013 04051100
	s_mul_i32 s1, s6, s17                                       ; 92011106
	v_add_u32_e32 v22, s1, v19                                  ; 682c2601
	v_add_u32_e32 v19, 0x80, v19                                ; 682626ff 00000080
	v_lshrrev_b32_e32 v22, 2, v22                               ; 202c2c82
	v_add_u32_e32 v19, s1, v19                                  ; 68262601
	v_lshlrev_b32_e32 v22, 4, v22                               ; 242c2c84
	v_lshrrev_b32_e32 v19, 2, v19                               ; 20262682
	v_lshlrev_b32_e32 v19, 4, v19                               ; 24262684
	buffer_load_dwordx4 v[24:27], v22, s[28:31], 0 offen        ; e05c1000 80071816
	buffer_load_dwordx4 v[28:31], v22, s[28:31], 0 offen offset:128 ; e05c1080 80071c16
	buffer_load_dwordx4 v[32:35], v19, s[28:31], 0 offen        ; e05c1000 80072013
	buffer_load_dwordx4 v[36:39], v19, s[28:31], 0 offen offset:128 ; e05c1080 80072413
	s_add_u32 s4, s16, 1                                        ; 80048110
	s_mul_i32 s4, s4, s3                                        ; 92040304
	s_add_u32 s4, s18, s4                                       ; 80040412
	s_add_u32 s5, s16, 2                                        ; 80058210
	v_add_u32_e32 v23, s4, v0                                   ; 682e0004
	s_mul_i32 s5, s5, s3                                        ; 92050305
	v_lshlrev_b32_e32 v40, 4, v23                               ; 24502e84
	s_add_u32 s5, s18, s5                                       ; 80050512
	v_lshl_add_u32 v23, v23, 7, v40                             ; d1fd0017 04a10f17
	v_add_u32_e32 v46, s5, v0                                   ; 685c0005
	v_add_u32_e32 v44, 16, v23                                  ; 68582e90
	v_add_u32_e32 v41, 4, v23                                   ; 68522e84
	s_add_u32 s9, s16, 3                                        ; 80098310
	v_lshlrev_b32_e32 v47, 4, v46                               ; 245e5c84
	v_add_u32_e32 v45, v44, v4                                  ; 685a092c
	v_add_u32_e32 v44, v44, v18                                 ; 6858252c
	v_add_u32_e32 v43, v41, v10                                 ; 68561529
	v_add_u32_e32 v42, v12, v41                                 ; 6854530c
	v_add_u32_e32 v41, v41, v15                                 ; 68521f29
	s_mul_i32 s9, s9, s3                                        ; 92090309
	v_lshl_add_u32 v46, v46, 7, v47                             ; d1fd002e 04bd0f2e
	s_add_u32 s9, s18, s9                                       ; 80090912
	v_add_u32_e32 v51, 16, v46                                  ; 68665c90
	v_add_u32_e32 v48, 4, v46                                   ; 68605c84
	v_add_u32_e32 v53, s9, v0                                   ; 686a0009
	v_add_u32_e32 v52, v51, v4                                  ; 68680933
	v_add_u32_e32 v51, v51, v18                                 ; 68662533
	v_add_u32_e32 v50, v48, v10                                 ; 68641530
	v_add_u32_e32 v49, v12, v48                                 ; 6862610c
	v_add_u32_e32 v48, v48, v15                                 ; 68601f30
	v_lshlrev_b32_e32 v54, 4, v53                               ; 246c6a84
	v_lshl_add_u32 v53, v53, 7, v54                             ; d1fd0035 04d90f35
	v_add_u32_e32 v55, 4, v53                                   ; 686e6a84
	v_add_u32_e32 v56, 16, v53                                  ; 68706a90
	v_add_u32_e32 v10, v55, v10                                 ; 68141537
	v_add_u32_e32 v12, v12, v55                                 ; 68186f0c
	v_add_u32_e32 v55, v55, v15                                 ; 686e1f37
	v_add_u32_e32 v57, v56, v4                                  ; 68720938
	v_add_u32_e32 v56, v56, v18                                 ; 68702538
	buffer_load_dword v23, v23, s[24:27], 0 offen               ; e0501000 80061717
	buffer_load_dwordx2 v[18:19], v42, s[24:27], 0 offen        ; e0541000 8006122a
	buffer_load_ushort v41, v41, s[24:27], 0 offen              ; e0481000 80062929
	buffer_load_dword v45, v45, s[24:27], 0 offen               ; e0501000 80062d2d
	buffer_load_dword v44, v44, s[24:27], 0 offen               ; e0501000 80062c2c
	buffer_load_dword v46, v46, s[24:27], 0 offen               ; e0501000 80062e2e
	buffer_load_dwordx2 v[58:59], v49, s[24:27], 0 offen        ; e0541000 80063a31
	buffer_load_ushort v48, v48, s[24:27], 0 offen              ; e0481000 80063030
	buffer_load_dword v52, v52, s[24:27], 0 offen               ; e0501000 80063434
	buffer_load_dword v51, v51, s[24:27], 0 offen               ; e0501000 80063333
	buffer_load_dword v53, v53, s[24:27], 0 offen               ; e0501000 80063535
	buffer_load_dwordx2 v[12:13], v12, s[24:27], 0 offen        ; e0541000 80060c0c
	buffer_load_ushort v55, v55, s[24:27], 0 offen              ; e0481000 80063737
	buffer_load_dword v57, v57, s[24:27], 0 offen               ; e0501000 80063939
	buffer_load_dword v56, v56, s[24:27], 0 offen               ; e0501000 80063838
	s_mov_b32 s10, 0xf0f0f0f                                    ; be8a00ff 0f0f0f0f
	s_mov_b32 s11, 0xc0c0c0c0                                   ; be8b00ff c0c0c0c0
	s_mov_b32 s12, 0x3f3f3f3f                                   ; be8c00ff 3f3f3f3f
	v_add_u32_e32 v0, 4, v0                                     ; 68000084
	s_waitcnt vmcnt(23)                                         ; bf8c7f77
	v_cvt_f32_f16_sdwa v60, v8 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e7816f9 00050608
	v_cvt_f32_f16_e32 v8, v8                                    ; 7e101708
	s_waitcnt vmcnt(22)                                         ; bf8c7f76
	v_alignbyte_b32 v20, v21, v20, v14                          ; d1cf0014 043a2915
	v_alignbyte_b32 v21, v21, v21, v14                          ; d1cf0015 043a2b15
	s_waitcnt vmcnt(21)                                         ; bf8c7f75
	v_lshl_or_b32 v11, v11, 12, v11                             ; d200000b 042d190b
	s_waitcnt vmcnt(20)                                         ; bf8c7f74
	v_and_b32_e32 v40, s10, v17                                 ; 2650220a
	v_mov_b32_sdwa v20, v21 dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_0 ; 7e2802f9 00041515
	v_cvt_f32_ubyte3_e32 v42, v40                               ; 7e542928
	v_cvt_f32_ubyte2_e32 v47, v40                               ; 7e5e2728
	v_cvt_f32_ubyte1_e32 v49, v40                               ; 7e622528
	v_cvt_f32_ubyte0_e32 v40, v40                               ; 7e502328
	v_lshrrev_b32_e32 v17, 4, v17                               ; 20222284
	v_and_b32_e32 v61, s11, v20                                 ; 267a280b
	v_and_b32_e32 v20, s12, v20                                 ; 2628280c
	v_and_b32_e32 v17, s10, v17                                 ; 2622220a
	v_lshrrev_b32_e32 v61, 2, v61                               ; 207a7a82
	v_cvt_f32_ubyte3_e32 v62, v20                               ; 7e7c2914
	v_cvt_f32_ubyte2_e32 v9, v20                                ; 7e122714
	v_cvt_f32_ubyte1_e32 v14, v20                               ; 7e1c2514
	v_cvt_f32_ubyte0_e32 v20, v20                               ; 7e282314
	s_waitcnt vmcnt(18)                                         ; bf8c7f72
	v_mul_f32_e32 v42, v27, v42                                 ; 0a54551b
	v_cvt_f32_ubyte3_e32 v54, v17                               ; 7e6c2911
	v_and_or_b32 v11, s10, v11, v61                             ; d201000b 04f6160a
	v_cvt_f32_ubyte2_e32 v61, v17                               ; 7e7a2711
	v_mac_f32_e32 v42, v26, v47                                 ; 2c545f1a
	v_and_b32_e32 v47, s10, v16                                 ; 265e200a
	s_waitcnt vmcnt(17)                                         ; bf8c7f71
	v_mul_f32_e32 v54, v31, v54                                 ; 0a6c6d1f
	v_cvt_f32_ubyte1_e32 v22, v11                               ; 7e2c250b
	v_cvt_f32_ubyte3_e32 v15, v11                               ; 7e1e290b
	v_cvt_f32_ubyte2_e32 v21, v11                               ; 7e2a270b
	v_cvt_f32_ubyte0_e32 v11, v11                               ; 7e16230b
	v_mac_f32_e32 v42, v25, v49                                 ; 2c546319
	v_cvt_f32_ubyte3_e32 v49, v47                               ; 7e62292f
	v_mac_f32_e32 v54, v30, v61                                 ; 2c6c7b1e
	v_cvt_f32_ubyte2_e32 v61, v47                               ; 7e7a272f
	v_lshrrev_b32_e32 v16, 4, v16                               ; 20202084
	v_mac_f32_e32 v42, v24, v40                                 ; 2c545118
	v_cvt_f32_ubyte1_e32 v40, v17                               ; 7e502511
	v_cvt_f32_ubyte0_e32 v17, v17                               ; 7e222311
	s_waitcnt vmcnt(16)                                         ; bf8c7f70
	v_mul_f32_e32 v49, v35, v49                                 ; 0a626323
	v_and_b32_e32 v16, s10, v16                                 ; 2620200a
	v_mac_f32_e32 v54, v29, v40                                 ; 2c6c511d
	v_mac_f32_e32 v49, v34, v61                                 ; 2c627b22
	v_cvt_f32_ubyte1_e32 v61, v16                               ; 7e7a2510
	v_cvt_f32_ubyte3_e32 v40, v16                               ; 7e502910
	v_mac_f32_e32 v54, v28, v17                                 ; 2c6c231c
	v_cvt_f32_ubyte1_e32 v17, v47                               ; 7e22252f
	v_cvt_f32_ubyte0_e32 v47, v47                               ; 7e5e232f
	s_waitcnt vmcnt(15)                                         ; bf8c3f7f
	v_mul_f32_e32 v40, v39, v40                                 ; 0a505127
	v_mac_f32_e32 v49, v33, v17                                 ; 2c622321
	v_mac_f32_e32 v49, v32, v47                                 ; 2c625f20
	v_cvt_f32_ubyte2_e32 v47, v16                               ; 7e5e2710
	v_cvt_f32_ubyte0_e32 v16, v16                               ; 7e202310
	v_mac_f32_e32 v40, v38, v47                                 ; 2c505f26
	v_mac_f32_e32 v40, v37, v61                                 ; 2c507b25
	v_mac_f32_e32 v40, v36, v16                                 ; 2c502124
	v_mul_f32_e32 v16, v39, v15                                 ; 0a201f27
	v_mul_f32_e32 v40, v40, v22                                 ; 0a502d28
	v_mac_f32_e32 v16, v35, v21                                 ; 2c202b23
	v_mac_f32_e32 v40, v49, v11                                 ; 2c501731
	v_mac_f32_e32 v16, v31, v62                                 ; 2c207d1f
	v_mac_f32_e32 v40, v54, v14                                 ; 2c501d36
	v_mac_f32_e32 v16, v27, v9                                  ; 2c20131b
	v_mac_f32_e32 v40, v42, v20                                 ; 2c50292a
	s_waitcnt vmcnt(14)                                         ; bf8c3f7e
	v_cvt_f32_f16_sdwa v17, v23 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e2216f9 00050617
	v_cvt_f32_f16_e32 v23, v23                                  ; 7e2e1717
	v_mac_f32_e32 v16, v38, v15                                 ; 2c201f26
	s_waitcnt vmcnt(13)                                         ; bf8c3f7d
	v_alignbyte_b32 v18, v19, v18, v43                          ; d1cf0012 04ae2513
	v_alignbyte_b32 v19, v19, v19, v43                          ; d1cf0013 04ae2713
	v_mac_f32_e32 v16, v34, v21                                 ; 2c202b22
	v_mov_b32_sdwa v18, v19 dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_0 ; 7e2402f9 00041513
	v_mac_f32_e32 v16, v30, v62                                 ; 2c207d1e
	v_and_b32_e32 v19, s11, v18                                 ; 2626240b
	v_and_b32_e32 v18, s12, v18                                 ; 2624240c
	v_mac_f32_e32 v16, v26, v9                                  ; 2c20131a
	v_lshrrev_b32_e32 v19, 2, v19                               ; 20262682
	s_waitcnt vmcnt(12)                                         ; bf8c3f7c
	v_lshl_or_b32 v41, v41, 12, v41                             ; d2000029 04a51929
	v_cvt_f32_ubyte1_e32 v22, v18                               ; 7e2c2512
	v_cvt_f32_ubyte3_e32 v20, v18                               ; 7e282912
	v_mac_f32_e32 v16, v37, v15                                 ; 2c201f25
	v_and_or_b32 v41, s10, v41, v19                             ; d2010029 044e520a
	v_mac_f32_e32 v16, v33, v21                                 ; 2c202b21
	v_cvt_f32_ubyte2_e32 v43, v41                               ; 7e562729
	v_mac_f32_e32 v16, v29, v62                                 ; 2c207d1d
	v_mac_f32_e32 v16, v25, v9                                  ; 2c201319
	v_mac_f32_e32 v16, v36, v15                                 ; 2c201f24
	v_mac_f32_e32 v16, v32, v21                                 ; 2c202b20
	v_cvt_f32_ubyte2_e32 v21, v18                               ; 7e2a2712
	v_cvt_f32_ubyte0_e32 v18, v18                               ; 7e242312
	v_mac_f32_e32 v16, v28, v62                                 ; 2c207d1c
	v_mac_f32_e32 v16, v24, v9                                  ; 2c201318
	v_mad_f32 v3, -v60, v16, v3                                 ; d1c10003 240e213c
	v_mac_f32_e32 v3, v8, v40                                   ; 2c065108
	v_cvt_f32_ubyte3_e32 v40, v41                               ; 7e502929
	v_mul_f32_e32 v42, v39, v40                                 ; 0a545127
	v_cvt_f32_ubyte1_e32 v47, v41                               ; 7e5e2529
	v_mac_f32_e32 v42, v35, v43                                 ; 2c545723
	v_cvt_f32_ubyte0_e32 v41, v41                               ; 7e522329
	v_mac_f32_e32 v42, v31, v20                                 ; 2c54291f
	s_waitcnt vmcnt(11)                                         ; bf8c3f7b
	v_and_b32_e32 v49, s10, v45                                 ; 26625a0a
	v_mac_f32_e32 v42, v27, v21                                 ; 2c542b1b
	v_cvt_f32_ubyte2_e32 v60, v49                               ; 7e782731
	v_cvt_f32_ubyte3_e32 v54, v49                               ; 7e6c2931
	v_mac_f32_e32 v42, v38, v40                                 ; 2c545126
	v_cvt_f32_ubyte1_e32 v61, v49                               ; 7e7a2531
	v_mul_f32_e32 v54, v27, v54                                 ; 0a6c6d1b
	v_cvt_f32_ubyte0_e32 v49, v49                               ; 7e622331
	v_mac_f32_e32 v42, v34, v43                                 ; 2c545722
	v_mac_f32_e32 v54, v26, v60                                 ; 2c6c791a
	v_lshrrev_b32_e32 v45, 4, v45                               ; 205a5a84
	v_mac_f32_e32 v42, v30, v20                                 ; 2c54291e
	v_mac_f32_e32 v54, v25, v61                                 ; 2c6c7b19
	v_and_b32_e32 v45, s10, v45                                 ; 265a5a0a
	v_mac_f32_e32 v42, v26, v21                                 ; 2c542b1a
	v_mac_f32_e32 v54, v24, v49                                 ; 2c6c6318
	v_cvt_f32_ubyte3_e32 v62, v45                               ; 7e7c292d
	v_cvt_f32_ubyte1_e32 v9, v45                                ; 7e12252d
	v_cvt_f32_ubyte2_e32 v8, v45                                ; 7e10272d
	v_mac_f32_e32 v42, v37, v40                                 ; 2c545125
	v_cvt_f32_ubyte0_e32 v45, v45                               ; 7e5a232d
	v_mul_f32_e32 v62, v31, v62                                 ; 0a7c7d1f
	s_waitcnt vmcnt(10)                                         ; bf8c3f7a
	v_and_b32_e32 v11, s10, v44                                 ; 2616580a
	v_mac_f32_e32 v42, v33, v43                                 ; 2c545721
	v_mac_f32_e32 v62, v30, v8                                  ; 2c7c111e
	v_cvt_f32_ubyte1_e32 v16, v11                               ; 7e20250b
	v_cvt_f32_ubyte3_e32 v14, v11                               ; 7e1c290b
	v_cvt_f32_ubyte2_e32 v15, v11                               ; 7e1e270b
	v_mac_f32_e32 v42, v29, v20                                 ; 2c54291d
	v_cvt_f32_ubyte0_e32 v11, v11                               ; 7e16230b
	v_mac_f32_e32 v62, v29, v9                                  ; 2c7c131d
	v_lshrrev_b32_e32 v44, 4, v44                               ; 20585884
	v_mul_f32_e32 v14, v35, v14                                 ; 0a1c1d23
	v_mac_f32_e32 v42, v25, v21                                 ; 2c542b19
	v_mac_f32_e32 v62, v28, v45                                 ; 2c7c5b1c
	v_and_b32_e32 v44, s10, v44                                 ; 2658580a
	v_mac_f32_e32 v14, v34, v15                                 ; 2c1c1f22
	v_mac_f32_e32 v42, v36, v40                                 ; 2c545124
	v_cvt_f32_ubyte2_e32 v19, v44                               ; 7e26272c
	v_mac_f32_e32 v14, v33, v16                                 ; 2c1c2121
	v_mac_f32_e32 v42, v32, v43                                 ; 2c545720
	v_mac_f32_e32 v14, v32, v11                                 ; 2c1c1720
	v_mac_f32_e32 v42, v28, v20                                 ; 2c54291c
	v_cvt_f32_ubyte1_e32 v20, v44                               ; 7e28252c
	s_waitcnt vmcnt(8)                                          ; bf8c3f78
	v_alignbyte_b32 v58, v59, v58, v50                          ; d1cf003a 04ca753b
	v_alignbyte_b32 v59, v59, v59, v50                          ; d1cf003b 04ca773b
	v_mac_f32_e32 v42, v24, v21                                 ; 2c542b18
	s_waitcnt vmcnt(7)                                          ; bf8c3f77
	v_lshl_or_b32 v48, v48, 12, v48                             ; d2000030 04c11930
	v_mov_b32_sdwa v58, v59 dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_0 ; 7e7402f9 0004153b
	v_mad_f32 v5, -v17, v42, v5                                 ; d1c10005 24165511
	v_cvt_f32_ubyte3_e32 v17, v44                               ; 7e22292c
	v_cvt_f32_ubyte0_e32 v44, v44                               ; 7e58232c
	v_and_b32_e32 v21, s11, v58                                 ; 262a740b
	v_mul_f32_e32 v17, v39, v17                                 ; 0a222327
	v_lshrrev_b32_e32 v21, 2, v21                               ; 202a2a82
	v_mac_f32_e32 v17, v38, v19                                 ; 2c222726
	v_and_or_b32 v48, s10, v48, v21                             ; d2010030 0456600a
	v_mac_f32_e32 v17, v37, v20                                 ; 2c222925
	v_mac_f32_e32 v17, v36, v44                                 ; 2c225924
	v_mul_f32_e32 v17, v17, v47                                 ; 0a225f11
	v_mac_f32_e32 v17, v14, v41                                 ; 2c22530e
	v_mac_f32_e32 v17, v62, v22                                 ; 2c222d3e
	s_waitcnt vmcnt(6)                                          ; bf8c3f76
	v_and_b32_e32 v22, s10, v52                                 ; 262c680a
	v_lshrrev_b32_e32 v52, 4, v52                               ; 20686884
	v_mac_f32_e32 v17, v54, v18                                 ; 2c222536
	v_cvt_f32_ubyte2_e32 v40, v22                               ; 7e502716
	v_cvt_f32_ubyte1_e32 v41, v22                               ; 7e522516
	v_and_b32_e32 v52, s10, v52                                 ; 2668680a
	v_mac_f32_e32 v5, v23, v17                                  ; 2c0a2317
	v_cvt_f32_ubyte3_e32 v23, v22                               ; 7e2e2916
	v_cvt_f32_ubyte0_e32 v22, v22                               ; 7e2c2316
	s_waitcnt vmcnt(5)                                          ; bf8c3f75
	v_and_b32_e32 v45, s10, v51                                 ; 265a660a
	v_cvt_f32_ubyte2_e32 v43, v52                               ; 7e562734
	v_cvt_f32_ubyte1_e32 v44, v52                               ; 7e582534
	v_cvt_f32_ubyte3_e32 v42, v52                               ; 7e542934
	v_cvt_f32_ubyte0_e32 v52, v52                               ; 7e682334
	v_mul_f32_e32 v23, v27, v23                                 ; 0a2e2f1b
	v_cvt_f32_ubyte1_e32 v50, v45                               ; 7e64252d
	v_cvt_f32_ubyte2_e32 v49, v45                               ; 7e62272d
	v_cvt_f32_ubyte3_e32 v47, v45                               ; 7e5e292d
	v_cvt_f32_ubyte0_e32 v45, v45                               ; 7e5a232d
	v_mul_f32_e32 v42, v31, v42                                 ; 0a54551f
	v_lshrrev_b32_e32 v51, 4, v51                               ; 20666684
	v_mac_f32_e32 v23, v26, v40                                 ; 2c2e511a
	v_mul_f32_e32 v47, v35, v47                                 ; 0a5e5f23
	v_mac_f32_e32 v42, v30, v43                                 ; 2c54571e
	v_and_b32_e32 v51, s10, v51                                 ; 2666660a
	v_mac_f32_e32 v23, v25, v41                                 ; 2c2e5319
	v_mac_f32_e32 v47, v34, v49                                 ; 2c5e6322
	v_cvt_f32_ubyte3_e32 v60, v48                               ; 7e782930
	v_mac_f32_e32 v42, v29, v44                                 ; 2c54591d
	v_cvt_f32_ubyte2_e32 v54, v51                               ; 7e6c2733
	v_cvt_f32_ubyte1_e32 v59, v51                               ; 7e762533
	v_mac_f32_e32 v23, v24, v22                                 ; 2c2e2d18
	v_cvt_f32_ubyte2_e32 v62, v48                               ; 7e7c2730
	v_mac_f32_e32 v47, v33, v50                                 ; 2c5e6521
	v_mul_f32_e32 v61, v39, v60                                 ; 0a7a7927
	v_and_b32_e32 v58, s12, v58                                 ; 2674740c
	v_mac_f32_e32 v42, v28, v52                                 ; 2c54691c
	v_cvt_f32_ubyte3_e32 v52, v51                               ; 7e682933
	v_cvt_f32_ubyte0_e32 v51, v51                               ; 7e662333
	v_mac_f32_e32 v47, v32, v45                                 ; 2c5e5b20
	v_mac_f32_e32 v61, v35, v62                                 ; 2c7a7d23
	v_cvt_f32_ubyte3_e32 v8, v58                                ; 7e10293a
	v_cvt_f32_ubyte2_e32 v9, v58                                ; 7e12273a
	v_mul_f32_e32 v52, v39, v52                                 ; 0a686927
	v_mac_f32_e32 v61, v31, v8                                  ; 2c7a111f
	v_mac_f32_e32 v52, v38, v54                                 ; 2c686d26
	v_cvt_f32_ubyte1_e32 v11, v48                               ; 7e162530
	v_mac_f32_e32 v61, v27, v9                                  ; 2c7a131b
	v_mac_f32_e32 v52, v37, v59                                 ; 2c687725
	v_cvt_f32_ubyte0_e32 v48, v48                               ; 7e602330
	v_mac_f32_e32 v61, v38, v60                                 ; 2c7a7926
	v_mac_f32_e32 v52, v36, v51                                 ; 2c686724
	v_cvt_f32_ubyte1_e32 v14, v58                               ; 7e1c253a
	v_cvt_f32_ubyte0_e32 v58, v58                               ; 7e74233a
	v_mac_f32_e32 v61, v34, v62                                 ; 2c7a7d22
	v_mul_f32_e32 v52, v52, v11                                 ; 0a681734
	v_cvt_f32_f16_sdwa v15, v46 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e1e16f9 0005062e
	v_mac_f32_e32 v61, v30, v8                                  ; 2c7a111e
	v_cvt_f32_f16_e32 v46, v46                                  ; 7e5c172e
	v_mac_f32_e32 v52, v47, v48                                 ; 2c68612f
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_alignbyte_b32 v12, v13, v12, v10                          ; d1cf000c 042a190d
	v_alignbyte_b32 v13, v13, v13, v10                          ; d1cf000d 042a1b0d
	v_mac_f32_e32 v61, v26, v9                                  ; 2c7a131a
	v_mac_f32_e32 v52, v42, v14                                 ; 2c681d2a
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_lshl_or_b32 v55, v55, 12, v55                             ; d2000037 04dd1937
	v_mov_b32_sdwa v12, v13 dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_0 ; 7e1802f9 0004150d
	v_mac_f32_e32 v61, v37, v60                                 ; 2c7a7925
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v17, s10, v57                                 ; 2622720a
	v_mac_f32_e32 v52, v23, v58                                 ; 2c687517
	v_and_b32_e32 v16, s11, v12                                 ; 2620180b
	v_mac_f32_e32 v61, v33, v62                                 ; 2c7a7d21
	v_cvt_f32_ubyte3_e32 v18, v17                               ; 7e242911
	v_cvt_f32_ubyte2_e32 v19, v17                               ; 7e262711
	v_cvt_f32_ubyte1_e32 v20, v17                               ; 7e282511
	v_lshrrev_b32_e32 v16, 2, v16                               ; 20202082
	v_mac_f32_e32 v61, v29, v8                                  ; 2c7a111d
	v_cvt_f32_ubyte0_e32 v17, v17                               ; 7e222311
	v_mul_f32_e32 v18, v27, v18                                 ; 0a24251b
	v_lshrrev_b32_e32 v57, 4, v57                               ; 20727284
	v_and_or_b32 v55, s10, v55, v16                             ; d2010037 04426e0a
	v_mac_f32_e32 v61, v25, v9                                  ; 2c7a1319
	v_mac_f32_e32 v18, v26, v19                                 ; 2c24271a
	v_and_b32_e32 v57, s10, v57                                 ; 2672720a
	v_mac_f32_e32 v61, v36, v60                                 ; 2c7a7924
	v_mac_f32_e32 v18, v25, v20                                 ; 2c242919
	v_cvt_f32_ubyte1_e32 v23, v57                               ; 7e2e2539
	v_cvt_f32_ubyte3_e32 v21, v57                               ; 7e2a2939
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v40, s10, v56                                 ; 2650700a
	v_cvt_f32_ubyte2_e32 v22, v57                               ; 7e2c2739
	v_cvt_f32_ubyte0_e32 v57, v57                               ; 7e722339
	v_mac_f32_e32 v61, v32, v62                                 ; 2c7a7d20
	v_mac_f32_e32 v18, v24, v17                                 ; 2c242318
	v_mul_f32_e32 v21, v31, v21                                 ; 0a2a2b1f
	v_cvt_f32_ubyte2_e32 v42, v40                               ; 7e542728
	v_cvt_f32_ubyte3_e32 v41, v40                               ; 7e522928
	v_cvt_f32_ubyte1_e32 v43, v40                               ; 7e562528
	v_cvt_f32_ubyte0_e32 v40, v40                               ; 7e502328
	v_mac_f32_e32 v61, v28, v8                                  ; 2c7a111c
	v_lshrrev_b32_e32 v56, 4, v56                               ; 20707084
	v_mac_f32_e32 v21, v30, v22                                 ; 2c2a2d1e
	v_mul_f32_e32 v41, v35, v41                                 ; 0a525323
	v_mac_f32_e32 v61, v24, v9                                  ; 2c7a1318
	v_and_b32_e32 v56, s10, v56                                 ; 2670700a
	v_mac_f32_e32 v21, v29, v23                                 ; 2c2a2f1d
	v_mac_f32_e32 v41, v34, v42                                 ; 2c525522
	v_cvt_f32_ubyte3_e32 v47, v55                               ; 7e5e2937
	v_mad_f32 v6, -v15, v61, v6                                 ; d1c10006 241a7b0f
	v_cvt_f32_ubyte2_e32 v45, v56                               ; 7e5a2738
	v_cvt_f32_ubyte3_e32 v44, v56                               ; 7e582938
	v_cvt_f32_ubyte2_e32 v48, v55                               ; 7e602737
	v_mac_f32_e32 v21, v28, v57                                 ; 2c2a731c
	v_mac_f32_e32 v41, v33, v43                                 ; 2c525721
	v_and_b32_e32 v12, s12, v12                                 ; 2618180c
	v_mac_f32_e32 v6, v46, v52                                  ; 2c0c692e
	v_cvt_f32_ubyte1_e32 v46, v56                               ; 7e5c2538
	v_cvt_f32_ubyte0_e32 v56, v56                               ; 7e702338
	v_mul_f32_e32 v44, v39, v44                                 ; 0a585927
	v_mul_f32_e32 v39, v39, v47                                 ; 0a4e5f27
	v_mac_f32_e32 v41, v32, v40                                 ; 2c525120
	v_cvt_f32_ubyte2_e32 v50, v12                               ; 7e64270c
	v_cvt_f32_ubyte3_e32 v49, v12                               ; 7e62290c
	v_mac_f32_e32 v44, v38, v45                                 ; 2c585b26
	v_mac_f32_e32 v39, v35, v48                                 ; 2c4e6123
	v_mac_f32_e32 v44, v37, v46                                 ; 2c585d25
	v_mac_f32_e32 v39, v31, v49                                 ; 2c4e631f
	v_cvt_f32_ubyte1_e32 v51, v55                               ; 7e662537
	v_mac_f32_e32 v44, v36, v56                                 ; 2c587124
	v_cvt_f32_ubyte0_e32 v55, v55                               ; 7e6e2337
	v_mac_f32_e32 v39, v27, v50                                 ; 2c4e651b
	v_mul_f32_e32 v44, v44, v51                                 ; 0a58672c
	v_cvt_f32_ubyte1_e32 v52, v12                               ; 7e68250c
	v_cvt_f32_ubyte0_e32 v12, v12                               ; 7e18230c
	v_mac_f32_e32 v39, v38, v47                                 ; 2c4e5f26
	v_mac_f32_e32 v44, v41, v55                                 ; 2c586f29
	v_cvt_f32_f16_sdwa v54, v53 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e6c16f9 00050635
	v_mac_f32_e32 v39, v34, v48                                 ; 2c4e6122
	v_cvt_f32_f16_e32 v53, v53                                  ; 7e6a1735
	v_mac_f32_e32 v44, v21, v52                                 ; 2c586915
	v_mac_f32_e32 v39, v30, v49                                 ; 2c4e631e
	v_mac_f32_e32 v44, v18, v12                                 ; 2c581912
	v_mac_f32_e32 v39, v26, v50                                 ; 2c4e651a
	v_mac_f32_e32 v39, v37, v47                                 ; 2c4e5f25
	v_mac_f32_e32 v39, v33, v48                                 ; 2c4e6121
	v_mac_f32_e32 v39, v29, v49                                 ; 2c4e631d
	v_mac_f32_e32 v39, v25, v50                                 ; 2c4e6519
	v_mac_f32_e32 v39, v36, v47                                 ; 2c4e5f24
	v_mac_f32_e32 v39, v32, v48                                 ; 2c4e6120
	v_mac_f32_e32 v39, v28, v49                                 ; 2c4e631c
	v_mac_f32_e32 v39, v24, v50                                 ; 2c4e6518
	v_mad_f32 v7, -v54, v39, v7                                 ; d1c10007 241e4f36
	v_mac_f32_e32 v7, v53, v44                                  ; 2c0e5935
BB5:
	s_mov_b64 s[0:1], exec                                      ; be80017e
	v_cmpx_le_u32_e32 vcc, s3, v0                               ; 7db60003
BB6:
	s_andn2_b64 s[0:1], s[0:1], exec                            ; 89807e00
	s_cbranch_scc1 BB10                                         ; bf85fe10
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
	s_branch BB119                                              ; bf82035c
BB42:
	s_cmp_lt_u32 s16, s4                                        ; bf0a0410
	s_cbranch_scc0 BB119                                        ; bf84035a
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
	s_nop 0                                                     ; bf800000
	(then repeated 2 times)
BB47:
	s_mov_b64 s[0:1], exec                                      ; be80017e
	v_cmpx_le_u32_e32 vcc, s3, v0                               ; 7db60003
BB48:
	s_andn2_b64 s[0:1], s[0:1], exec                            ; 89807e00
	s_cbranch_scc0 BB65                                         ; bf840202
BB52:
	s_mov_b64 exec, s[0:1]                                      ; befe0100
	s_cmp_lg_i32 s4, 0                                          ; bf018004
	v_lshl_add_u32 v8, v0, 8, v1                                ; d1fd0008 04051100
	s_cbranch_scc0 BB64                                         ; bf8401fb
BB53:
	s_mov_b32 s0, s2                                            ; be800002
	s_movk_i32 s1, 0x8000                                       ; b0018000
	s_load_dwordx8 s[24:31], s[0:1], 0x0                        ; c00e0600 00000000
	s_mul_i32 s0, s16, s3                                       ; 92000310
	v_lshlrev_b32_e32 v11, 1, v2                                ; 24160481
	v_add_u32_e32 v19, 64, v4                                   ; 682608c0
	s_add_u32 s0, s19, s0                                       ; 80000013
	v_and_b32_e32 v13, -4, v11                                  ; 261a16c4
	v_add_u32_e32 v16, 8, v11                                   ; 68201688
	v_add_u32_e32 v9, s0, v0                                    ; 68120000
	v_lshlrev_b32_e32 v10, 4, v9                                ; 24141284
	v_lshl_add_u32 v9, v9, 7, v10                               ; d1fd0009 04290f09
	v_add_u32_e32 v12, 4, v9                                    ; 68181284
	v_add_u32_e32 v17, 16, v9                                   ; 68221290
	v_add_u32_e32 v14, v13, v12                                 ; 681c190d
	v_add_u32_e32 v15, v12, v11                                 ; 681e170c
	v_add_u32_e32 v12, v12, v16                                 ; 6818210c
	v_add_u32_e32 v18, v17, v4                                  ; 68240911
	v_add_u32_e32 v17, v17, v19                                 ; 68222711
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_load_dword v9, v9, s[24:27], 0 offen                 ; e0501000 80060909
	buffer_load_dwordx2 v[20:21], v14, s[24:27], 0 offen        ; e0541000 8006140e
	buffer_load_ushort v12, v12, s[24:27], 0 offen              ; e0481000 80060c0c
	buffer_load_dword v18, v18, s[24:27], 0 offen               ; e0501000 80061212
	buffer_load_dword v17, v17, s[24:27], 0 offen               ; e0501000 80061111
	s_mul_i32 s1, s6, s17                                       ; 92011106
	v_add_u32_e32 v22, s1, v8                                   ; 682c1001
	v_add_u32_e32 v8, 0x80, v8                                  ; 681010ff 00000080
	v_lshrrev_b32_e32 v22, 2, v22                               ; 202c2c82
	v_add_u32_e32 v8, s1, v8                                    ; 68101001
	v_lshlrev_b32_e32 v22, 4, v22                               ; 242c2c84
	v_lshrrev_b32_e32 v8, 2, v8                                 ; 20101082
	v_lshlrev_b32_e32 v8, 4, v8                                 ; 24101084
	buffer_load_dwordx4 v[24:27], v22, s[28:31], 0 offen        ; e05c1000 80071816
	buffer_load_dwordx4 v[28:31], v22, s[28:31], 0 offen offset:128 ; e05c1080 80071c16
	buffer_load_dwordx4 v[32:35], v8, s[28:31], 0 offen         ; e05c1000 80072008
	buffer_load_dwordx4 v[36:39], v8, s[28:31], 0 offen offset:128 ; e05c1080 80072408
	s_mov_b32 s5, 0xf0f0f0f                                     ; be8500ff 0f0f0f0f
	s_cmp_lt_u32 1, s4                                          ; bf0a0481
	s_waitcnt vmcnt(8)                                          ; bf8c3f78
	v_cvt_f32_f16_sdwa v23, v9 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e2e16f9 00050609
	v_cvt_f32_f16_e32 v9, v9                                    ; 7e121709
	s_waitcnt vmcnt(7)                                          ; bf8c3f77
	v_alignbyte_b32 v20, v21, v20, v15                          ; d1cf0014 043e2915
	v_alignbyte_b32 v21, v21, v21, v15                          ; d1cf0015 043e2b15
	s_waitcnt vmcnt(6)                                          ; bf8c3f76
	v_lshl_or_b32 v12, v12, 12, v12                             ; d200000c 0431190c
	s_waitcnt vmcnt(5)                                          ; bf8c3f75
	v_and_b32_e32 v47, s5, v18                                  ; 265e2405
	v_mov_b32_sdwa v20, v21 dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_0 ; 7e2802f9 00041515
	v_cvt_f32_ubyte2_e32 v49, v47                               ; 7e62272f
	v_cvt_f32_ubyte3_e32 v48, v47                               ; 7e60292f
	v_cvt_f32_ubyte1_e32 v50, v47                               ; 7e64252f
	v_cvt_f32_ubyte0_e32 v47, v47                               ; 7e5e232f
	v_lshrrev_b32_e32 v18, 4, v18                               ; 20242484
	v_and_b32_e32 v40, 0xc0c0c0c0, v20                          ; 265028ff c0c0c0c0
	v_and_b32_e32 v20, 0x3f3f3f3f, v20                          ; 262828ff 3f3f3f3f
	v_and_b32_e32 v18, s5, v18                                  ; 26242405
	s_waitcnt vmcnt(4)                                          ; bf8c3f74
	v_and_b32_e32 v54, s5, v17                                  ; 266c2205
	v_lshrrev_b32_e32 v40, 2, v40                               ; 20505082
	v_cvt_f32_ubyte3_e32 v41, v20                               ; 7e522914
	v_cvt_f32_ubyte2_e32 v42, v20                               ; 7e542714
	v_cvt_f32_ubyte1_e32 v43, v20                               ; 7e562514
	v_cvt_f32_ubyte0_e32 v20, v20                               ; 7e282314
	v_cvt_f32_ubyte1_e32 v53, v18                               ; 7e6a2512
	v_cvt_f32_ubyte2_e32 v52, v18                               ; 7e682712
	v_cvt_f32_ubyte3_e32 v51, v18                               ; 7e662912
	v_cvt_f32_ubyte0_e32 v18, v18                               ; 7e242312
	v_cvt_f32_ubyte3_e32 v55, v54                               ; 7e6e2936
	v_cvt_f32_ubyte2_e32 v56, v54                               ; 7e702736
	v_cvt_f32_ubyte1_e32 v57, v54                               ; 7e722536
	v_and_or_b32 v12, s5, v12, v40                              ; d201000c 04a21805
	v_cvt_f32_ubyte0_e32 v54, v54                               ; 7e6c2336
	v_lshrrev_b32_e32 v17, 4, v17                               ; 20222284
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_mul_f32_e32 v48, v27, v48                                 ; 0a60611b
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_mul_f32_e32 v51, v31, v51                                 ; 0a66671f
	v_cvt_f32_ubyte2_e32 v45, v12                               ; 7e5a270c
	v_cvt_f32_ubyte1_e32 v46, v12                               ; 7e5c250c
	v_cvt_f32_ubyte3_e32 v44, v12                               ; 7e58290c
	v_cvt_f32_ubyte0_e32 v12, v12                               ; 7e18230c
	v_and_b32_e32 v17, s5, v17                                  ; 26222205
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_mul_f32_e32 v55, v35, v55                                 ; 0a6e6f23
	v_mac_f32_e32 v48, v26, v49                                 ; 2c60631a
	v_mac_f32_e32 v51, v30, v52                                 ; 2c66691e
	v_cvt_f32_ubyte3_e32 v58, v17                               ; 7e742911
	v_cvt_f32_ubyte2_e32 v59, v17                               ; 7e762711
	v_cvt_f32_ubyte1_e32 v60, v17                               ; 7e782511
	v_cvt_f32_ubyte0_e32 v17, v17                               ; 7e222311
	v_mac_f32_e32 v55, v34, v56                                 ; 2c6e7122
	v_mac_f32_e32 v48, v25, v50                                 ; 2c606519
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_mul_f32_e32 v61, v39, v44                                 ; 0a7a5927
	v_mac_f32_e32 v51, v29, v53                                 ; 2c666b1d
	v_mul_f32_e32 v58, v39, v58                                 ; 0a747527
	v_mac_f32_e32 v55, v33, v57                                 ; 2c6e7321
	v_mac_f32_e32 v48, v24, v47                                 ; 2c605f18
	v_mac_f32_e32 v61, v35, v45                                 ; 2c7a5b23
	v_mac_f32_e32 v51, v28, v18                                 ; 2c66251c
	v_mac_f32_e32 v58, v38, v59                                 ; 2c747726
	v_mac_f32_e32 v55, v32, v54                                 ; 2c6e6d20
	v_mac_f32_e32 v61, v31, v41                                 ; 2c7a531f
	v_mac_f32_e32 v58, v37, v60                                 ; 2c747925
	v_mac_f32_e32 v61, v27, v42                                 ; 2c7a551b
	v_mac_f32_e32 v58, v36, v17                                 ; 2c742324
	v_mac_f32_e32 v61, v38, v44                                 ; 2c7a5926
	v_mul_f32_e32 v58, v58, v46                                 ; 0a745d3a
	v_mac_f32_e32 v61, v34, v45                                 ; 2c7a5b22
	v_mac_f32_e32 v58, v55, v12                                 ; 2c741937
	v_mac_f32_e32 v61, v30, v41                                 ; 2c7a531e
	v_mac_f32_e32 v58, v51, v43                                 ; 2c745733
	v_mac_f32_e32 v61, v26, v42                                 ; 2c7a551a
	v_mac_f32_e32 v58, v48, v20                                 ; 2c742930
	v_mac_f32_e32 v61, v37, v44                                 ; 2c7a5925
	v_mac_f32_e32 v61, v33, v45                                 ; 2c7a5b21
	v_mac_f32_e32 v61, v29, v41                                 ; 2c7a531d
	v_mac_f32_e32 v61, v25, v42                                 ; 2c7a5519
	v_mac_f32_e32 v61, v36, v44                                 ; 2c7a5924
	v_mac_f32_e32 v61, v32, v45                                 ; 2c7a5b20
	v_mac_f32_e32 v61, v28, v41                                 ; 2c7a531c
	v_mac_f32_e32 v61, v24, v42                                 ; 2c7a5518
	v_mad_f32 v3, -v23, v61, v3                                 ; d1c10003 240e7b17
	v_mac_f32_e32 v3, v9, v58                                   ; 2c067509
	s_cbranch_scc0 BB64                                         ; bf840166
BB54:
	s_add_u32 s0, s16, 1                                        ; 80008110
	s_mul_i32 s0, s0, s3                                        ; 92000300
	s_add_u32 s0, s19, s0                                       ; 80000013
	v_add_u32_e32 v8, s0, v0                                    ; 68100000
	v_lshlrev_b32_e32 v9, 4, v8                                 ; 24121084
	v_lshl_add_u32 v8, v8, 7, v9                                ; d1fd0008 04250f08
	v_add_u32_e32 v10, 4, v8                                    ; 68141084
	v_add_u32_e32 v15, 16, v8                                   ; 681e1090
	v_add_u32_e32 v12, v13, v10                                 ; 6818150d
	v_add_u32_e32 v14, v10, v11                                 ; 681c170a
	v_add_u32_e32 v10, v10, v16                                 ; 6814210a
	v_add_u32_e32 v17, v15, v4                                  ; 6822090f
	v_add_u32_e32 v15, v15, v19                                 ; 681e270f
	buffer_load_dword v8, v8, s[24:27], 0 offen                 ; e0501000 80060808
	buffer_load_dwordx2 v[20:21], v12, s[24:27], 0 offen        ; e0541000 8006140c
	buffer_load_ushort v10, v10, s[24:27], 0 offen              ; e0481000 80060a0a
	buffer_load_dword v17, v17, s[24:27], 0 offen               ; e0501000 80061111
	buffer_load_dword v15, v15, s[24:27], 0 offen               ; e0501000 80060f0f
	s_mov_b32 s1, 0xf0f0f0f                                     ; be8100ff 0f0f0f0f
	s_cmp_lt_u32 2, s4                                          ; bf0a0482
	s_waitcnt vmcnt(4)                                          ; bf8c3f74
	v_cvt_f32_f16_sdwa v18, v8 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e2416f9 00050608
	v_cvt_f32_f16_e32 v8, v8                                    ; 7e101708
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_alignbyte_b32 v20, v21, v20, v14                          ; d1cf0014 043a2915
	v_alignbyte_b32 v21, v21, v21, v14                          ; d1cf0015 043a2b15
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_lshl_or_b32 v10, v10, 12, v10                             ; d200000a 0429190a
	v_mov_b32_sdwa v20, v21 dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_0 ; 7e2802f9 00041515
	v_and_b32_e32 v21, 0xc0c0c0c0, v20                          ; 262a28ff c0c0c0c0
	v_and_b32_e32 v20, 0x3f3f3f3f, v20                          ; 262828ff 3f3f3f3f
	v_lshrrev_b32_e32 v21, 2, v21                               ; 202a2a82
	v_cvt_f32_ubyte3_e32 v22, v20                               ; 7e2c2914
	v_cvt_f32_ubyte2_e32 v23, v20                               ; 7e2e2714
	v_cvt_f32_ubyte1_e32 v40, v20                               ; 7e502514
	v_cvt_f32_ubyte0_e32 v20, v20                               ; 7e282314
	v_and_or_b32 v10, s1, v10, v21                              ; d201000a 04561401
	v_cvt_f32_ubyte3_e32 v41, v10                               ; 7e52290a
	v_cvt_f32_ubyte2_e32 v43, v10                               ; 7e56270a
	v_mul_f32_e32 v42, v39, v41                                 ; 0a545327
	v_cvt_f32_ubyte1_e32 v44, v10                               ; 7e58250a
	v_cvt_f32_ubyte0_e32 v10, v10                               ; 7e14230a
	v_mac_f32_e32 v42, v35, v43                                 ; 2c545723
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v45, s1, v17                                  ; 265a2201
	v_mac_f32_e32 v42, v31, v22                                 ; 2c542d1f
	v_cvt_f32_ubyte3_e32 v46, v45                               ; 7e5c292d
	v_cvt_f32_ubyte2_e32 v47, v45                               ; 7e5e272d
	v_mac_f32_e32 v42, v27, v23                                 ; 2c542f1b
	v_mul_f32_e32 v46, v27, v46                                 ; 0a5c5d1b
	v_cvt_f32_ubyte1_e32 v48, v45                               ; 7e60252d
	v_mac_f32_e32 v42, v38, v41                                 ; 2c545326
	v_mac_f32_e32 v46, v26, v47                                 ; 2c5c5f1a
	v_cvt_f32_ubyte0_e32 v45, v45                               ; 7e5a232d
	v_lshrrev_b32_e32 v17, 4, v17                               ; 20222284
	v_mac_f32_e32 v42, v34, v43                                 ; 2c545722
	v_mac_f32_e32 v46, v25, v48                                 ; 2c5c6119
	v_and_b32_e32 v17, s1, v17                                  ; 26222201
	v_mac_f32_e32 v42, v30, v22                                 ; 2c542d1e
	v_mac_f32_e32 v46, v24, v45                                 ; 2c5c5b18
	v_cvt_f32_ubyte3_e32 v49, v17                               ; 7e622911
	v_cvt_f32_ubyte2_e32 v50, v17                               ; 7e642711
	v_cvt_f32_ubyte1_e32 v51, v17                               ; 7e662511
	v_mac_f32_e32 v42, v26, v23                                 ; 2c542f1a
	v_cvt_f32_ubyte0_e32 v17, v17                               ; 7e222311
	v_mul_f32_e32 v49, v31, v49                                 ; 0a62631f
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v52, s1, v15                                  ; 26681e01
	v_mac_f32_e32 v42, v37, v41                                 ; 2c545325
	v_mac_f32_e32 v49, v30, v50                                 ; 2c62651e
	v_cvt_f32_ubyte2_e32 v54, v52                               ; 7e6c2734
	v_cvt_f32_ubyte1_e32 v55, v52                               ; 7e6e2534
	v_cvt_f32_ubyte3_e32 v53, v52                               ; 7e6a2934
	v_mac_f32_e32 v42, v33, v43                                 ; 2c545721
	v_mac_f32_e32 v49, v29, v51                                 ; 2c62671d
	v_cvt_f32_ubyte0_e32 v52, v52                               ; 7e682334
	v_lshrrev_b32_e32 v15, 4, v15                               ; 201e1e84
	v_mul_f32_e32 v53, v35, v53                                 ; 0a6a6b23
	v_mac_f32_e32 v42, v29, v22                                 ; 2c542d1d
	v_mac_f32_e32 v49, v28, v17                                 ; 2c62231c
	v_and_b32_e32 v15, s1, v15                                  ; 261e1e01
	v_mac_f32_e32 v53, v34, v54                                 ; 2c6a6d22
	v_mac_f32_e32 v42, v25, v23                                 ; 2c542f19
	v_cvt_f32_ubyte3_e32 v56, v15                               ; 7e70290f
	v_cvt_f32_ubyte2_e32 v57, v15                               ; 7e72270f
	v_cvt_f32_ubyte1_e32 v58, v15                               ; 7e74250f
	v_cvt_f32_ubyte0_e32 v15, v15                               ; 7e1e230f
	v_mac_f32_e32 v53, v33, v55                                 ; 2c6a6f21
	v_mac_f32_e32 v42, v36, v41                                 ; 2c545324
	v_mul_f32_e32 v56, v39, v56                                 ; 0a707127
	v_mac_f32_e32 v53, v32, v52                                 ; 2c6a6920
	v_mac_f32_e32 v42, v32, v43                                 ; 2c545720
	v_mac_f32_e32 v56, v38, v57                                 ; 2c707326
	v_mac_f32_e32 v42, v28, v22                                 ; 2c542d1c
	v_mac_f32_e32 v56, v37, v58                                 ; 2c707525
	v_mac_f32_e32 v42, v24, v23                                 ; 2c542f18
	v_mac_f32_e32 v56, v36, v15                                 ; 2c701f24
	v_mad_f32 v5, -v18, v42, v5                                 ; d1c10005 24165512
	v_mul_f32_e32 v56, v56, v44                                 ; 0a705938
	v_mac_f32_e32 v56, v53, v10                                 ; 2c701535
	v_mac_f32_e32 v56, v49, v40                                 ; 2c705131
	v_mac_f32_e32 v56, v46, v20                                 ; 2c70292e
	v_mac_f32_e32 v5, v8, v56                                   ; 2c0a7108
	s_cbranch_scc0 BB64                                         ; bf8400ee
BB55:
	s_add_u32 s0, s16, 2                                        ; 80008210
	s_mul_i32 s0, s0, s3                                        ; 92000300
	s_add_u32 s0, s19, s0                                       ; 80000013
	v_add_u32_e32 v8, s0, v0                                    ; 68100000
	v_lshlrev_b32_e32 v9, 4, v8                                 ; 24121084
	v_lshl_add_u32 v8, v8, 7, v9                                ; d1fd0008 04250f08
	v_add_u32_e32 v10, 4, v8                                    ; 68141084
	v_add_u32_e32 v15, 16, v8                                   ; 681e1090
	v_add_u32_e32 v12, v13, v10                                 ; 6818150d
	v_add_u32_e32 v14, v10, v11                                 ; 681c170a
	v_add_u32_e32 v10, v10, v16                                 ; 6814210a
	v_add_u32_e32 v17, v15, v4                                  ; 6822090f
	v_add_u32_e32 v15, v15, v19                                 ; 681e270f
	buffer_load_dword v8, v8, s[24:27], 0 offen                 ; e0501000 80060808
	buffer_load_dwordx2 v[20:21], v12, s[24:27], 0 offen        ; e0541000 8006140c
	buffer_load_ushort v10, v10, s[24:27], 0 offen              ; e0481000 80060a0a
	buffer_load_dword v17, v17, s[24:27], 0 offen               ; e0501000 80061111
	buffer_load_dword v15, v15, s[24:27], 0 offen               ; e0501000 80060f0f
	s_mov_b32 s1, 0xf0f0f0f                                     ; be8100ff 0f0f0f0f
	s_cmp_lt_u32 3, s4                                          ; bf0a0483
	s_waitcnt vmcnt(4)                                          ; bf8c3f74
	v_cvt_f32_f16_sdwa v18, v8 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e2416f9 00050608
	v_cvt_f32_f16_e32 v8, v8                                    ; 7e101708
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_alignbyte_b32 v20, v21, v20, v14                          ; d1cf0014 043a2915
	v_alignbyte_b32 v21, v21, v21, v14                          ; d1cf0015 043a2b15
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_lshl_or_b32 v10, v10, 12, v10                             ; d200000a 0429190a
	v_mov_b32_sdwa v20, v21 dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_0 ; 7e2802f9 00041515
	v_and_b32_e32 v21, 0xc0c0c0c0, v20                          ; 262a28ff c0c0c0c0
	v_and_b32_e32 v20, 0x3f3f3f3f, v20                          ; 262828ff 3f3f3f3f
	v_lshrrev_b32_e32 v21, 2, v21                               ; 202a2a82
	v_cvt_f32_ubyte3_e32 v22, v20                               ; 7e2c2914
	v_cvt_f32_ubyte2_e32 v23, v20                               ; 7e2e2714
	v_cvt_f32_ubyte1_e32 v40, v20                               ; 7e502514
	v_cvt_f32_ubyte0_e32 v20, v20                               ; 7e282314
	v_and_or_b32 v10, s1, v10, v21                              ; d201000a 04561401
	v_cvt_f32_ubyte3_e32 v41, v10                               ; 7e52290a
	v_cvt_f32_ubyte2_e32 v43, v10                               ; 7e56270a
	v_mul_f32_e32 v42, v39, v41                                 ; 0a545327
	v_cvt_f32_ubyte1_e32 v44, v10                               ; 7e58250a
	v_cvt_f32_ubyte0_e32 v10, v10                               ; 7e14230a
	v_mac_f32_e32 v42, v35, v43                                 ; 2c545723
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v45, s1, v17                                  ; 265a2201
	v_mac_f32_e32 v42, v31, v22                                 ; 2c542d1f
	v_cvt_f32_ubyte3_e32 v46, v45                               ; 7e5c292d
	v_cvt_f32_ubyte2_e32 v47, v45                               ; 7e5e272d
	v_mac_f32_e32 v42, v27, v23                                 ; 2c542f1b
	v_mul_f32_e32 v46, v27, v46                                 ; 0a5c5d1b
	v_cvt_f32_ubyte1_e32 v48, v45                               ; 7e60252d
	v_mac_f32_e32 v42, v38, v41                                 ; 2c545326
	v_mac_f32_e32 v46, v26, v47                                 ; 2c5c5f1a
	v_cvt_f32_ubyte0_e32 v45, v45                               ; 7e5a232d
	v_lshrrev_b32_e32 v17, 4, v17                               ; 20222284
	v_mac_f32_e32 v42, v34, v43                                 ; 2c545722
	v_mac_f32_e32 v46, v25, v48                                 ; 2c5c6119
	v_and_b32_e32 v17, s1, v17                                  ; 26222201
	v_mac_f32_e32 v42, v30, v22                                 ; 2c542d1e
	v_mac_f32_e32 v46, v24, v45                                 ; 2c5c5b18
	v_cvt_f32_ubyte3_e32 v49, v17                               ; 7e622911
	v_cvt_f32_ubyte2_e32 v50, v17                               ; 7e642711
	v_cvt_f32_ubyte1_e32 v51, v17                               ; 7e662511
	v_mac_f32_e32 v42, v26, v23                                 ; 2c542f1a
	v_cvt_f32_ubyte0_e32 v17, v17                               ; 7e222311
	v_mul_f32_e32 v49, v31, v49                                 ; 0a62631f
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v52, s1, v15                                  ; 26681e01
	v_mac_f32_e32 v42, v37, v41                                 ; 2c545325
	v_mac_f32_e32 v49, v30, v50                                 ; 2c62651e
	v_cvt_f32_ubyte2_e32 v54, v52                               ; 7e6c2734
	v_cvt_f32_ubyte1_e32 v55, v52                               ; 7e6e2534
	v_cvt_f32_ubyte3_e32 v53, v52                               ; 7e6a2934
	v_mac_f32_e32 v42, v33, v43                                 ; 2c545721
	v_mac_f32_e32 v49, v29, v51                                 ; 2c62671d
	v_cvt_f32_ubyte0_e32 v52, v52                               ; 7e682334
	v_lshrrev_b32_e32 v15, 4, v15                               ; 201e1e84
	v_mul_f32_e32 v53, v35, v53                                 ; 0a6a6b23
	v_mac_f32_e32 v42, v29, v22                                 ; 2c542d1d
	v_mac_f32_e32 v49, v28, v17                                 ; 2c62231c
	v_and_b32_e32 v15, s1, v15                                  ; 261e1e01
	v_mac_f32_e32 v53, v34, v54                                 ; 2c6a6d22
	v_mac_f32_e32 v42, v25, v23                                 ; 2c542f19
	v_cvt_f32_ubyte3_e32 v56, v15                               ; 7e70290f
	v_cvt_f32_ubyte2_e32 v57, v15                               ; 7e72270f
	v_cvt_f32_ubyte1_e32 v58, v15                               ; 7e74250f
	v_cvt_f32_ubyte0_e32 v15, v15                               ; 7e1e230f
	v_mac_f32_e32 v53, v33, v55                                 ; 2c6a6f21
	v_mac_f32_e32 v42, v36, v41                                 ; 2c545324
	v_mul_f32_e32 v56, v39, v56                                 ; 0a707127
	v_mac_f32_e32 v53, v32, v52                                 ; 2c6a6920
	v_mac_f32_e32 v42, v32, v43                                 ; 2c545720
	v_mac_f32_e32 v56, v38, v57                                 ; 2c707326
	v_mac_f32_e32 v42, v28, v22                                 ; 2c542d1c
	v_mac_f32_e32 v56, v37, v58                                 ; 2c707525
	v_mac_f32_e32 v42, v24, v23                                 ; 2c542f18
	v_mac_f32_e32 v56, v36, v15                                 ; 2c701f24
	v_mad_f32 v6, -v18, v42, v6                                 ; d1c10006 241a5512
	v_mul_f32_e32 v56, v56, v44                                 ; 0a705938
	v_mac_f32_e32 v56, v53, v10                                 ; 2c701535
	v_mac_f32_e32 v56, v49, v40                                 ; 2c705131
	v_mac_f32_e32 v56, v46, v20                                 ; 2c70292e
	v_mac_f32_e32 v6, v8, v56                                   ; 2c0c7108
	s_cbranch_scc0 BB64                                         ; bf840076
BB56:
	s_add_u32 s0, s16, 3                                        ; 80008310
	s_mul_i32 s0, s0, s3                                        ; 92000300
	s_add_u32 s0, s19, s0                                       ; 80000013
	v_add_u32_e32 v8, s0, v0                                    ; 68100000
	v_lshlrev_b32_e32 v9, 4, v8                                 ; 24121084
	v_lshl_add_u32 v8, v8, 7, v9                                ; d1fd0008 04250f08
	v_add_u32_e32 v10, 4, v8                                    ; 68141084
	v_add_u32_e32 v12, 16, v8                                   ; 68181090
	v_add_u32_e32 v13, v13, v10                                 ; 681a150d
	v_add_u32_e32 v11, v10, v11                                 ; 6816170a
	v_add_u32_e32 v10, v10, v16                                 ; 6814210a
	v_add_u32_e32 v14, v12, v4                                  ; 681c090c
	v_add_u32_e32 v12, v12, v19                                 ; 6818270c
	buffer_load_dword v8, v8, s[24:27], 0 offen                 ; e0501000 80060808
	buffer_load_dwordx2 v[16:17], v13, s[24:27], 0 offen        ; e0541000 8006100d
	buffer_load_ushort v10, v10, s[24:27], 0 offen              ; e0481000 80060a0a
	buffer_load_dword v14, v14, s[24:27], 0 offen               ; e0501000 80060e0e
	buffer_load_dword v12, v12, s[24:27], 0 offen               ; e0501000 80060c0c
	s_mov_b32 s1, 0xf0f0f0f                                     ; be8100ff 0f0f0f0f
	s_waitcnt vmcnt(4)                                          ; bf8c3f74
	v_cvt_f32_f16_sdwa v15, v8 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e1e16f9 00050608
	v_cvt_f32_f16_e32 v8, v8                                    ; 7e101708
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_alignbyte_b32 v16, v17, v16, v11                          ; d1cf0010 042e2111
	v_alignbyte_b32 v17, v17, v17, v11                          ; d1cf0011 042e2311
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_lshl_or_b32 v10, v10, 12, v10                             ; d200000a 0429190a
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v40, s1, v14                                  ; 26501c01
	v_mov_b32_sdwa v16, v17 dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_0 ; 7e2002f9 00041511
	v_cvt_f32_ubyte2_e32 v42, v40                               ; 7e542728
	v_cvt_f32_ubyte3_e32 v41, v40                               ; 7e522928
	v_cvt_f32_ubyte1_e32 v43, v40                               ; 7e562528
	v_and_b32_e32 v17, 0xc0c0c0c0, v16                          ; 262220ff c0c0c0c0
	v_and_b32_e32 v16, 0x3f3f3f3f, v16                          ; 262020ff 3f3f3f3f
	v_cvt_f32_ubyte0_e32 v40, v40                               ; 7e502328
	v_mul_f32_e32 v41, v27, v41                                 ; 0a52531b
	v_lshrrev_b32_e32 v17, 2, v17                               ; 20222282
	v_lshrrev_b32_e32 v14, 4, v14                               ; 201c1c84
	v_cvt_f32_ubyte3_e32 v18, v16                               ; 7e242910
	v_cvt_f32_ubyte2_e32 v19, v16                               ; 7e262710
	v_cvt_f32_ubyte1_e32 v20, v16                               ; 7e282510
	v_cvt_f32_ubyte0_e32 v16, v16                               ; 7e202310
	v_mac_f32_e32 v41, v26, v42                                 ; 2c52551a
	v_and_or_b32 v10, s1, v10, v17                              ; d201000a 04461401
	v_and_b32_e32 v14, s1, v14                                  ; 261c1c01
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v47, s1, v12                                  ; 265e1801
	v_mac_f32_e32 v41, v25, v43                                 ; 2c525719
	v_cvt_f32_ubyte3_e32 v21, v10                               ; 7e2a290a
	v_cvt_f32_ubyte2_e32 v22, v10                               ; 7e2c270a
	v_cvt_f32_ubyte1_e32 v23, v10                               ; 7e2e250a
	v_cvt_f32_ubyte0_e32 v10, v10                               ; 7e14230a
	v_cvt_f32_ubyte2_e32 v45, v14                               ; 7e5a270e
	v_cvt_f32_ubyte1_e32 v46, v14                               ; 7e5c250e
	v_cvt_f32_ubyte3_e32 v44, v14                               ; 7e58290e
	v_cvt_f32_ubyte0_e32 v14, v14                               ; 7e1c230e
	v_cvt_f32_ubyte3_e32 v48, v47                               ; 7e60292f
	v_cvt_f32_ubyte2_e32 v49, v47                               ; 7e62272f
	v_mac_f32_e32 v41, v24, v40                                 ; 2c525118
	v_cvt_f32_ubyte1_e32 v50, v47                               ; 7e64252f
	v_cvt_f32_ubyte0_e32 v47, v47                               ; 7e5e232f
	v_lshrrev_b32_e32 v12, 4, v12                               ; 20181884
	v_mul_f32_e32 v44, v31, v44                                 ; 0a58591f
	v_mul_f32_e32 v48, v35, v48                                 ; 0a606123
	v_and_b32_e32 v12, s1, v12                                  ; 26181801
	v_mac_f32_e32 v44, v30, v45                                 ; 2c585b1e
	v_mac_f32_e32 v48, v34, v49                                 ; 2c606322
	v_cvt_f32_ubyte1_e32 v53, v12                               ; 7e6a250c
	v_cvt_f32_ubyte2_e32 v52, v12                               ; 7e68270c
	v_cvt_f32_ubyte3_e32 v51, v12                               ; 7e66290c
	v_cvt_f32_ubyte0_e32 v12, v12                               ; 7e18230c
	v_mac_f32_e32 v44, v29, v46                                 ; 2c585d1d
	v_mac_f32_e32 v48, v33, v50                                 ; 2c606521
	v_mul_f32_e32 v51, v39, v51                                 ; 0a666727
	v_mul_f32_e32 v39, v39, v21                                 ; 0a4e2b27
	v_mac_f32_e32 v44, v28, v14                                 ; 2c581d1c
	v_mac_f32_e32 v48, v32, v47                                 ; 2c605f20
	v_mac_f32_e32 v51, v38, v52                                 ; 2c666926
	v_mac_f32_e32 v39, v35, v22                                 ; 2c4e2d23
	v_mac_f32_e32 v51, v37, v53                                 ; 2c666b25
	v_mac_f32_e32 v39, v31, v18                                 ; 2c4e251f
	v_mac_f32_e32 v51, v36, v12                                 ; 2c661924
	v_mac_f32_e32 v39, v27, v19                                 ; 2c4e271b
	v_mul_f32_e32 v51, v51, v23                                 ; 0a662f33
	v_mac_f32_e32 v39, v38, v21                                 ; 2c4e2b26
	v_mac_f32_e32 v51, v48, v10                                 ; 2c661530
	v_mac_f32_e32 v39, v34, v22                                 ; 2c4e2d22
	v_mac_f32_e32 v51, v44, v20                                 ; 2c66292c
	v_mac_f32_e32 v39, v30, v18                                 ; 2c4e251e
	v_mac_f32_e32 v51, v41, v16                                 ; 2c662129
	v_mac_f32_e32 v39, v26, v19                                 ; 2c4e271a
	v_mac_f32_e32 v39, v37, v21                                 ; 2c4e2b25
	v_mac_f32_e32 v39, v33, v22                                 ; 2c4e2d21
	v_mac_f32_e32 v39, v29, v18                                 ; 2c4e251d
	v_mac_f32_e32 v39, v25, v19                                 ; 2c4e2719
	v_mac_f32_e32 v39, v36, v21                                 ; 2c4e2b24
	v_mac_f32_e32 v39, v32, v22                                 ; 2c4e2d20
	v_mac_f32_e32 v39, v28, v18                                 ; 2c4e251c
	v_mac_f32_e32 v39, v24, v19                                 ; 2c4e2718
	v_mad_f32 v7, -v15, v39, v7                                 ; d1c10007 241e4f0f
	v_mac_f32_e32 v7, v8, v51                                   ; 2c0e6708
BB64:
	v_add_u32_e32 v0, 4, v0                                     ; 68000084
	s_branch BB47                                               ; bf82fdfa
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
