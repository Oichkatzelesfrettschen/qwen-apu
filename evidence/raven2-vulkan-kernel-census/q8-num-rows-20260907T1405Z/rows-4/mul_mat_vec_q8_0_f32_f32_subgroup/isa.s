BB0:
	s_load_dword s0, s[14:15], 0x0                              ; c0020007 00000000
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_mul_i32 s0, s0, s18                                       ; 92001200
	s_add_u32 s16, s16, s0                                      ; 80100010
	s_lshl_b32 s16, s16, 2                                      ; 8e108210
	s_add_u32 s1, s16, 4                                        ; 80018410
	s_cmp_ge_u32 s4, s1                                         ; bf090104
	s_cbranch_scc0 BB55                                         ; bf840701
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
	s_mul_i32 s20, s13, s18                                     ; 9214120d
	s_cselect_b32 s14, s14, s4                                  ; 850e040e
	s_cmp_ge_u32 s14, s11                                       ; bf090b0e
	s_mov_b32 s15, src_scc                                      ; be8f00fd
	s_add_u32 s0, s0, src_scc                                   ; 8000fd00
	s_sub_i32 s11, s14, s11                                     ; 818b0b0e
	s_cmp_lg_i32 s15, 0                                         ; bf01800f
	v_cvt_f32_u32_e32 v3, s12                                   ; 7e060c0c
	s_cselect_b32 s11, s11, s14                                 ; 850b0e0b
	s_sub_i32 s20, 0, s20                                       ; 81941480
	v_rcp_f32_e32 v3, v3                                        ; 7e064503
	s_mul_hi_u32 s20, s18, s20                                  ; 96141412
	s_add_u32 s18, s18, s20                                     ; 80121412
	v_mul_f32_e32 v3, 0x4f7ffffe, v3                            ; 0a0606ff 4f7ffffe
	s_mul_hi_u32 s18, s0, s18                                   ; 96121200
	v_cvt_u32_f32_e32 v3, v3                                    ; 7e060f03
	s_mul_i32 s21, s18, s13                                     ; 92150d12
	v_readfirstlane_b32 s24, v3                                 ; 7e300503
	s_sub_i32 s0, s0, s21                                       ; 81801500
	s_mul_i32 s25, s12, s24                                     ; 9219180c
	s_cmp_ge_u32 s0, s13                                        ; bf090d00
	s_add_u32 s18, s18, src_scc                                 ; 8012fd12
	s_sub_i32 s23, s0, s13                                      ; 81970d00
	s_cmp_ge_u32 s0, s13                                        ; bf090d00
	s_cselect_b32 s23, s23, s0                                  ; 85170017
	s_cmp_ge_u32 s23, s13                                       ; bf090d17
	s_add_u32 s18, s18, src_scc                                 ; 8012fd12
	s_sub_i32 s25, 0, s25                                       ; 81991980
	s_mul_i32 s18, s18, s10                                     ; 92120a12
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
	s_add_u32 s18, s18, s24                                     ; 80121812
	s_branch BB4                                                ; bf820001
BB3:
	s_mov_b32 s18, 0                                            ; be920080
BB4:
	s_lshr_b32 s5, s5, 5                                        ; 8f058505
	v_lshlrev_b32_e32 v0, 3, v0                                 ; 24000083
	s_and_b32 s0, s3, 0xfffffe00                                ; 8600ff03 fffffe00
	s_lshr_b32 s1, s3, 9                                        ; 8f018903
	v_mov_b32_e32 v4, 0                                         ; 7e080280
	v_mov_b32_e32 v5, 0                                         ; 7e0a0280
	v_mov_b32_e32 v6, 0                                         ; 7e0c0280
	s_mul_i32 s18, s18, s5                                      ; 92120512
	v_add_u32_e32 v1, s0, v0                                    ; 68020000
	s_mov_b32 s0, 0                                             ; be800080
	v_cmp_gt_u32_e32 vcc, s3, v1                                ; 7d980203
	v_mov_b32_e32 v1, 0                                         ; 7e020280
	v_cndmask_b32_e64 v2, 0, 1, vcc                             ; d1000002 01a90280
	v_add_u32_e32 v2, s1, v2                                    ; 68040401
	v_and_b32_e32 v3, -4, v2                                    ; 260604c4
	s_branch BB5                                                ; bf82032d
BB10:
	s_mov_b64 exec, s[4:5]                                      ; befe0104
	s_mov_b32 s4, s2                                            ; be840002
	s_movk_i32 s5, 0x8000                                       ; b0058000
	s_load_dwordx8 s[24:31], s[4:5], 0x0                        ; c00e0602 00000000
	s_lshl_b32 s1, s0, 9                                        ; 8e018900
	s_mul_i32 s4, s6, s17                                       ; 92041106
	v_add_u32_e32 v7, s1, v0                                    ; 680e0001
	v_and_b32_e32 v8, 31, v7                                    ; 26100e9f
	v_sub_u32_e32 v9, v7, v8                                    ; 6a121107
	v_add3_u32 v9, v8, s4, v9                                   ; d1ff0009 04240908
	v_lshrrev_b32_e32 v9, 2, v9                                 ; 20121282
	v_lshlrev_b32_e32 v9, 4, v9                                 ; 24121284
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_load_dwordx4 v[12:15], v9, s[28:31], 0 offen         ; e05c1000 80070c09
	buffer_load_dwordx4 v[16:19], v9, s[28:31], 0 offen offset:16 ; e05c1010 80071009
	s_mul_i32 s5, s16, s3                                       ; 92050310
	s_add_u32 s9, s5, s3                                        ; 80090305
	v_add_u32_e32 v10, s5, v7                                   ; 68140e05
	v_add_u32_e32 v22, s9, v7                                   ; 682c0e09
	v_lshrrev_b32_e32 v10, 5, v10                               ; 20141485
	s_add_u32 s10, s9, s3                                       ; 800a0309
	v_lshrrev_b32_e32 v22, 5, v22                               ; 202c2c85
	v_add_u32_e32 v10, s18, v10                                 ; 68141412
	v_add_u32_e32 v26, s10, v7                                  ; 68340e0a
	v_add_u32_e32 v22, s18, v22                                 ; 682c2c12
	v_lshlrev_b32_e32 v11, 1, v10                               ; 24161481
	v_lshrrev_b32_e32 v26, 5, v26                               ; 20343485
	v_lshlrev_b32_e32 v23, 1, v22                               ; 242e2c81
	v_lshl_add_u32 v10, v10, 5, v11                             ; d1fd000a 042d0b0a
	v_add_u32_e32 v26, s18, v26                                 ; 68343412
	v_lshl_add_u32 v22, v22, 5, v23                             ; d1fd0016 045d0b16
	v_add_u32_e32 v20, 2, v10                                   ; 68281482
	v_lshlrev_b32_e32 v27, 1, v26                               ; 24363481
	v_add_u32_e32 v24, 2, v22                                   ; 68302c82
	v_add_u32_e32 v21, v20, v8                                  ; 682a1114
	v_and_b32_e32 v20, -4, v20                                  ; 262828c4
	v_lshl_add_u32 v26, v26, 5, v27                             ; d1fd001a 046d0b1a
	v_add_u32_e32 v25, v24, v8                                  ; 68321118
	v_and_b32_e32 v24, -4, v24                                  ; 263030c4
	v_add_u32_e32 v20, v20, v8                                  ; 68281114
	v_add_u32_e32 v28, 2, v26                                   ; 68383482
	v_add_u32_e32 v24, v24, v8                                  ; 68301118
	v_add_u32_e32 v29, v28, v8                                  ; 683a111c
	v_and_b32_e32 v28, -4, v28                                  ; 263838c4
	v_add_u32_e32 v28, v28, v8                                  ; 6838111c
	buffer_load_dwordx3 v[30:32], v20, s[24:27], 0 offen        ; e0581000 80061e14
	buffer_load_short_d16 v33, v10, s[24:27], 0 offen           ; e0901000 8006210a
	buffer_load_dwordx3 v[34:36], v24, s[24:27], 0 offen        ; e0581000 80062218
	buffer_load_short_d16 v37, v22, s[24:27], 0 offen           ; e0901000 80062516
	buffer_load_dwordx3 v[9:11], v28, s[24:27], 0 offen         ; e0581000 8006091c
	buffer_load_short_d16 v20, v26, s[24:27], 0 offen           ; e0901000 8006141a
	s_add_u32 s11, s10, s3                                      ; 800b030a
	v_add_u32_e32 v7, s11, v7                                   ; 680e0e0b
	v_lshrrev_b32_e32 v7, 5, v7                                 ; 200e0e85
	v_add_u32_e32 v7, s18, v7                                   ; 680e0e12
	v_lshlrev_b32_e32 v22, 1, v7                                ; 242c0e81
	v_lshl_add_u32 v7, v7, 5, v22                               ; d1fd0007 04590b07
	v_add_u32_e32 v23, 2, v7                                    ; 682e0e82
	v_add_u32_e32 v24, v23, v8                                  ; 68301117
	v_and_b32_e32 v23, -4, v23                                  ; 262e2ec4
	v_add_u32_e32 v23, v23, v8                                  ; 682e1117
	s_waitcnt vmcnt(5)                                          ; bf8c3f75
	v_alignbyte_b32 v30, v31, v30, v21                          ; d1cf001e 04563d1f
	v_alignbyte_b32 v32, v32, v31, v21                          ; d1cf0020 04563f20
	v_cvt_f32_i32_sdwa v31, sext(v32) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e3e0af9 000b0620
	v_cvt_f32_i32_sdwa v38, sext(v32) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e4c0af9 000a0620
	v_mul_f32_e32 v31, v19, v31                                 ; 0a3e3f13
	v_mac_f32_e32 v31, v18, v38                                 ; 2c3e4d12
	v_cvt_f32_i32_sdwa v38, sext(v32) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e4c0af9 00090620
	v_mac_f32_e32 v31, v17, v38                                 ; 2c3e4d11
	buffer_load_dwordx3 v[21:23], v23, s[24:27], 0 offen        ; e0581000 80061517
	buffer_load_short_d16 v38, v7, s[24:27], 0 offen            ; e0901000 80062607
	v_cvt_f32_i32_sdwa v27, sext(v30) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e360af9 000a061e
	v_cvt_f32_i32_sdwa v26, sext(v30) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e340af9 000b061e
	v_cvt_f32_i32_sdwa v28, sext(v30) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e380af9 0009061e
	v_cvt_f32_i32_sdwa v30, sext(v30) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e3c0af9 0008061e
	v_cvt_f32_i32_sdwa v32, sext(v32) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e400af9 00080620
	s_add_u32 s12, s1, 0x200                                    ; 800cff01 00000200
	s_waitcnt vmcnt(5)                                          ; bf8c3f75
	v_alignbyte_b32 v34, v35, v34, v25                          ; d1cf0022 04664523
	v_alignbyte_b32 v36, v36, v35, v25                          ; d1cf0024 04664724
	v_mac_f32_e32 v31, v16, v32                                 ; 2c3e4110
	v_cvt_f32_i32_sdwa v32, sext(v34) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e400af9 000a0622
	v_mac_f32_e32 v31, v14, v27                                 ; 2c3e370e
	v_cvt_f32_i32_sdwa v35, sext(v36) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e460af9 000b0624
	v_cvt_f32_i32_sdwa v7, sext(v36) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e0e0af9 000a0624
	v_mac_f32_e32 v31, v15, v26                                 ; 2c3e350f
	v_add_u32_e32 v26, s12, v0                                  ; 6834000c
	v_mul_f32_e32 v35, v19, v35                                 ; 0a464713
	v_cvt_f32_i32_sdwa v8, sext(v36) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e100af9 00090624
	v_mac_f32_e32 v31, v13, v28                                 ; 2c3e390d
	v_cvt_f32_i32_sdwa v36, sext(v36) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e480af9 00080624
	v_and_b32_e32 v27, 31, v26                                  ; 2636349f
	v_mac_f32_e32 v35, v18, v7                                  ; 2c460f12
	v_mov_b32_e32 v25, v5                                       ; 7e320305
	v_mac_f32_e32 v31, v12, v30                                 ; 2c3e3d0c
	v_cvt_f32_f16_e32 v30, v33                                  ; 7e3c1721
	v_sub_u32_e32 v28, v26, v27                                 ; 6a38371a
	v_mac_f32_e32 v35, v17, v8                                  ; 2c461111
	v_mac_f32_e32 v1, v31, v30                                  ; 2c023d1f
	v_mov_b32_e32 v30, v6                                       ; 7e3c0306
	v_add3_u32 v28, v27, s4, v28                                ; d1ff001c 0470091b
	v_lshrrev_b32_e32 v28, 2, v28                               ; 20383882
	v_lshlrev_b32_e32 v28, 4, v28                               ; 24383884
	buffer_load_dwordx4 v[5:8], v28, s[28:31], 0 offen          ; e05c1000 8007051c
	v_cvt_f32_i32_sdwa v31, sext(v34) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e3e0af9 000b0622
	v_cvt_f32_i32_sdwa v33, sext(v34) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e420af9 00090622
	v_cvt_f32_i32_sdwa v34, sext(v34) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e440af9 00080622
	v_mac_f32_e32 v35, v16, v36                                 ; 2c464910
	s_waitcnt vmcnt(4)                                          ; bf8c3f74
	v_alignbyte_b32 v9, v10, v9, v29                            ; d1cf0009 0476130a
	v_alignbyte_b32 v11, v11, v10, v29                          ; d1cf000b 0476150b
	v_mac_f32_e32 v35, v14, v32                                 ; 2c46410e
	v_cvt_f32_i32_sdwa v32, sext(v9) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e400af9 000b0609
	v_cvt_f32_i32_sdwa v36, sext(v11) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e480af9 000a060b
	v_mov_b32_e32 v10, v30                                      ; 7e14031e
	v_mac_f32_e32 v35, v15, v31                                 ; 2c463f0f
	v_cvt_f32_f16_e32 v31, v37                                  ; 7e3e1725
	v_mac_f32_e32 v35, v13, v33                                 ; 2c46430d
	v_mac_f32_e32 v35, v12, v34                                 ; 2c46450c
	v_mac_f32_e32 v4, v35, v31                                  ; 2c083f23
	buffer_load_dwordx4 v[28:31], v28, s[28:31], 0 offen offset:16 ; e05c1010 80071c1c
	v_cvt_f32_i32_sdwa v34, sext(v9) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e440af9 00090609
	v_cvt_f32_i32_sdwa v33, sext(v9) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e420af9 000a0609
	v_cvt_f32_i32_sdwa v9, sext(v9) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e120af9 00080609
	v_cvt_f32_i32_sdwa v35, sext(v11) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e460af9 000b060b
	v_cvt_f32_i32_sdwa v37, sext(v11) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e4a0af9 0009060b
	v_cvt_f32_i32_sdwa v11, sext(v11) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e160af9 0008060b
	v_mul_f32_e32 v35, v19, v35                                 ; 0a464713
	v_mac_f32_e32 v35, v18, v36                                 ; 2c464912
	v_mac_f32_e32 v35, v17, v37                                 ; 2c464b11
	v_mac_f32_e32 v35, v16, v11                                 ; 2c461710
	v_add_u32_e32 v11, s5, v26                                  ; 68163405
	v_mac_f32_e32 v35, v14, v33                                 ; 2c46430e
	v_lshrrev_b32_e32 v11, 5, v11                               ; 20161685
	v_mac_f32_e32 v35, v15, v32                                 ; 2c46410f
	v_add_u32_e32 v11, s18, v11                                 ; 68161612
	v_mac_f32_e32 v35, v13, v34                                 ; 2c46450d
	v_lshlrev_b32_e32 v32, 1, v11                               ; 24401681
	v_mac_f32_e32 v35, v12, v9                                  ; 2c46130c
	v_lshl_add_u32 v11, v11, 5, v32                             ; d1fd000b 04810b0b
	v_add_u32_e32 v33, 2, v11                                   ; 68421682
	v_add_u32_e32 v34, v33, v27                                 ; 68443721
	v_and_b32_e32 v33, -4, v33                                  ; 264242c4
	v_mov_b32_e32 v9, v34                                       ; 7e120322
	v_add_u32_e32 v33, v33, v27                                 ; 68423721
	buffer_load_dwordx3 v[32:34], v33, s[24:27], 0 offen        ; e0581000 80062021
	buffer_load_short_d16 v11, v11, s[24:27], 0 offen           ; e0901000 80060b0b
	s_waitcnt vmcnt(6)                                          ; bf8c3f76
	v_cvt_f32_f16_e32 v20, v20                                  ; 7e281714
	s_waitcnt vmcnt(5)                                          ; bf8c3f75
	v_alignbyte_b32 v23, v23, v22, v24                          ; d1cf0017 04622d17
	v_alignbyte_b32 v21, v22, v21, v24                          ; d1cf0015 04622b16
	v_mac_f32_e32 v25, v35, v20                                 ; 2c322923
	v_add_u32_e32 v20, s9, v26                                  ; 68283409
	v_cvt_f32_i32_sdwa v36, sext(v23) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e480af9 000b0617
	v_cvt_f32_i32_sdwa v37, sext(v23) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e4a0af9 000a0617
	v_cvt_f32_i32_sdwa v22, sext(v21) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e2c0af9 000b0615
	v_cvt_f32_i32_sdwa v24, sext(v21) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e300af9 000a0615
	v_cvt_f32_i32_sdwa v35, sext(v21) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e460af9 00090615
	v_cvt_f32_i32_sdwa v21, sext(v21) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e2a0af9 00080615
	v_lshrrev_b32_e32 v20, 5, v20                               ; 20282885
	v_mul_f32_e32 v19, v19, v36                                 ; 0a264913
	v_add_u32_e32 v20, s18, v20                                 ; 68282812
	v_mac_f32_e32 v19, v18, v37                                 ; 2c264b12
	v_cvt_f32_i32_sdwa v18, sext(v23) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e240af9 00090617
	v_cvt_f32_i32_sdwa v23, sext(v23) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e2e0af9 00080617
	v_mac_f32_e32 v19, v17, v18                                 ; 2c262511
	v_mac_f32_e32 v19, v16, v23                                 ; 2c262f10
	v_lshlrev_b32_e32 v23, 1, v20                               ; 242e2881
	v_lshl_add_u32 v20, v20, 5, v23                             ; d1fd0014 045d0b14
	v_add_u32_e32 v36, 2, v20                                   ; 68482882
	v_add_u32_e32 v37, v36, v27                                 ; 684a3724
	v_and_b32_e32 v36, -4, v36                                  ; 264848c4
	v_mac_f32_e32 v19, v14, v24                                 ; 2c26310e
	v_add_u32_e32 v36, v36, v27                                 ; 68483724
	v_mac_f32_e32 v19, v15, v22                                 ; 2c262d0f
	v_add_u32_e32 v22, s10, v26                                 ; 682c340a
	v_mac_f32_e32 v19, v13, v35                                 ; 2c26470d
	v_lshrrev_b32_e32 v22, 5, v22                               ; 202c2c85
	v_add_u32_e32 v22, s18, v22                                 ; 682c2c12
	v_lshlrev_b32_e32 v23, 1, v22                               ; 242e2c81
	v_lshl_add_u32 v22, v22, 5, v23                             ; d1fd0016 045d0b16
	v_add_u32_e32 v24, 2, v22                                   ; 68302c82
	v_add_u32_e32 v35, v24, v27                                 ; 68463718
	v_and_b32_e32 v24, -4, v24                                  ; 263030c4
	v_add_u32_e32 v24, v24, v27                                 ; 68303718
	buffer_load_dwordx3 v[16:18], v36, s[24:27], 0 offen        ; e0581000 80061024
	buffer_load_short_d16 v20, v20, s[24:27], 0 offen           ; e0901000 80061414
	buffer_load_dwordx3 v[13:15], v24, s[24:27], 0 offen        ; e0581000 80060d18
	buffer_load_short_d16 v22, v22, s[24:27], 0 offen           ; e0901000 80061616
	v_add_u32_e32 v26, s11, v26                                 ; 6834340b
	v_mac_f32_e32 v19, v12, v21                                 ; 2c262b0c
	s_waitcnt vmcnt(8)                                          ; bf8c3f78
	v_cvt_f32_f16_e32 v38, v38                                  ; 7e4c1726
	v_lshrrev_b32_e32 v26, 5, v26                               ; 20343485
	v_mac_f32_e32 v10, v19, v38                                 ; 2c144d13
	v_add_u32_e32 v26, s18, v26                                 ; 68343412
	v_lshlrev_b32_e32 v23, 1, v26                               ; 242e3481
	v_lshl_add_u32 v26, v26, 5, v23                             ; d1fd001a 045d0b1a
	v_add_u32_e32 v24, 2, v26                                   ; 68303482
	v_add_u32_e32 v36, v24, v27                                 ; 68483718
	v_and_b32_e32 v24, -4, v24                                  ; 263030c4
	v_add_u32_e32 v24, v24, v27                                 ; 68303718
	s_waitcnt vmcnt(5)                                          ; bf8c3f75
	v_alignbyte_b32 v34, v34, v33, v9                           ; d1cf0022 04264322
	v_cvt_f32_i32_sdwa v19, sext(v34) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e260af9 000b0622
	v_cvt_f32_i32_sdwa v23, sext(v34) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e2e0af9 00090622
	v_cvt_f32_i32_sdwa v21, sext(v34) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e2a0af9 000a0622
	v_mul_f32_e32 v19, v31, v19                                 ; 0a26271f
	v_mac_f32_e32 v19, v30, v21                                 ; 2c262b1e
	v_mac_f32_e32 v19, v29, v23                                 ; 2c262f1d
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_mov_b32_sdwa v11, v22 dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_0 ; 7e1602f9 00041516
	buffer_load_dwordx3 v[21:23], v24, s[24:27], 0 offen        ; e0581000 80061518
	buffer_load_short_d16 v24, v26, s[24:27], 0 offen           ; e0901000 8006181a
	v_alignbyte_b32 v32, v33, v32, v9                           ; d1cf0020 04264121
	v_cvt_f32_i32_sdwa v34, sext(v34) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e440af9 00080622
	s_add_u32 s13, 0x400, s1                                    ; 800d01ff 00000400
	v_cvt_f32_i32_sdwa v38, sext(v32) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e4c0af9 000b0620
	v_cvt_f32_i32_sdwa v9, sext(v32) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e120af9 000a0620
	v_cvt_f32_i32_sdwa v12, sext(v32) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e180af9 00090620
	v_cvt_f32_i32_sdwa v32, sext(v32) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e400af9 00080620
	v_mac_f32_e32 v19, v28, v34                                 ; 2c26451c
	v_cvt_f32_f16_e32 v33, v11                                  ; 7e42170b
	v_add_u32_e32 v26, s13, v0                                  ; 6834000d
	v_alignbyte_b32 v16, v17, v16, v37                          ; d1cf0010 04962111
	v_alignbyte_b32 v18, v18, v17, v37                          ; d1cf0012 04962312
	v_mac_f32_e32 v19, v7, v9                                   ; 2c261307
	v_and_b32_e32 v27, 31, v26                                  ; 2636349f
	v_cvt_f32_i32_sdwa v37, sext(v16) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e4a0af9 000a0610
	v_cvt_f32_i32_sdwa v34, sext(v16) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e440af9 000b0610
	v_cvt_f32_i32_sdwa v9, sext(v18) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e120af9 000b0612
	v_mac_f32_e32 v19, v8, v38                                  ; 2c264d08
	v_cvt_f32_i32_sdwa v38, sext(v16) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e4c0af9 00090610
	v_cvt_f32_i32_sdwa v16, sext(v16) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e200af9 00080610
	v_cvt_f32_i32_sdwa v17, sext(v18) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e220af9 00090612
	v_mul_f32_e32 v9, v31, v9                                   ; 0a12131f
	v_mac_f32_e32 v19, v6, v12                                  ; 2c261906
	v_cvt_f32_i32_sdwa v12, sext(v18) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e180af9 000a0612
	v_cvt_f32_i32_sdwa v18, sext(v18) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e240af9 00080612
	v_mac_f32_e32 v19, v5, v32                                  ; 2c264105
	v_sub_u32_e32 v32, v26, v27                                 ; 6a40371a
	v_mac_f32_e32 v9, v30, v12                                  ; 2c12191e
	v_mov_b32_e32 v12, v16                                      ; 7e180310
	v_mac_f32_e32 v1, v19, v33                                  ; 2c024313
	v_add3_u32 v32, v27, s4, v32                                ; d1ff0020 0480091b
	v_mac_f32_e32 v9, v29, v17                                  ; 2c12231d
	v_lshrrev_b32_e32 v32, 2, v32                               ; 20404082
	v_mac_f32_e32 v9, v28, v18                                  ; 2c12251c
	v_lshlrev_b32_e32 v32, 4, v32                               ; 24404084
	buffer_load_dwordx4 v[16:19], v32, s[28:31], 0 offen        ; e05c1000 80071020
	v_cvt_f32_f16_e32 v20, v20                                  ; 7e281714
	v_alignbyte_b32 v13, v14, v13, v35                          ; d1cf000d 048e1b0e
	v_alignbyte_b32 v15, v15, v14, v35                          ; d1cf000f 048e1d0f
	v_mac_f32_e32 v9, v7, v37                                   ; 2c124b07
	v_cvt_f32_i32_sdwa v35, sext(v13) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e460af9 0009060d
	v_cvt_f32_i32_sdwa v33, sext(v13) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e420af9 000b060d
	v_cvt_f32_i32_sdwa v37, sext(v15) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e4a0af9 000b060f
	v_mac_f32_e32 v9, v8, v34                                   ; 2c124508
	v_cvt_f32_i32_sdwa v34, sext(v13) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e440af9 000a060d
	v_cvt_f32_i32_sdwa v13, sext(v13) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e1a0af9 0008060d
	v_mul_f32_e32 v37, v31, v37                                 ; 0a4a4b1f
	v_mac_f32_e32 v9, v6, v38                                   ; 2c124d06
	v_cvt_f32_i32_sdwa v38, sext(v15) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e4c0af9 000a060f
	v_mac_f32_e32 v9, v5, v12                                   ; 2c121905
	v_mac_f32_e32 v37, v30, v38                                 ; 2c4a4d1e
	v_cvt_f32_i32_sdwa v38, sext(v15) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e4c0af9 0009060f
	v_mac_f32_e32 v4, v9, v20                                   ; 2c082909
	v_mov_b32_e32 v20, v15                                      ; 7e28030f
	v_mov_b32_e32 v9, v13                                       ; 7e12030d
	buffer_load_dwordx4 v[12:15], v32, s[28:31], 0 offen offset:16 ; e05c1010 80070c20
	v_add_u32_e32 v32, s5, v26                                  ; 68403405
	v_mac_f32_e32 v37, v29, v38                                 ; 2c4a4d1d
	v_cvt_f32_i32_sdwa v20, sext(v20) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e280af9 00080614
	v_lshrrev_b32_e32 v32, 5, v32                               ; 20404085
	v_mac_f32_e32 v37, v28, v20                                 ; 2c4a291c
	v_add_u32_e32 v32, s18, v32                                 ; 68404012
	v_mac_f32_e32 v37, v7, v34                                  ; 2c4a4507
	v_mac_f32_e32 v37, v8, v33                                  ; 2c4a4308
	v_lshlrev_b32_e32 v33, 1, v32                               ; 24424081
	v_mac_f32_e32 v37, v6, v35                                  ; 2c4a4706
	v_lshl_add_u32 v32, v32, 5, v33                             ; d1fd0020 04850b20
	v_mac_f32_e32 v37, v5, v9                                   ; 2c4a1305
	v_add_u32_e32 v34, 2, v32                                   ; 68444082
	v_mov_b32_e32 v9, v32                                       ; 7e120320
	v_add_u32_e32 v35, v34, v27                                 ; 68463722
	v_and_b32_e32 v34, -4, v34                                  ; 264444c4
	v_add_u32_e32 v34, v34, v27                                 ; 68443722
	buffer_load_dwordx3 v[32:34], v34, s[24:27], 0 offen        ; e0581000 80062022
	buffer_load_short_d16 v20, v9, s[24:27], 0 offen            ; e0901000 80061409
	v_cvt_f32_f16_sdwa v38, v11 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e4c16f9 0005060b
	s_waitcnt vmcnt(5)                                          ; bf8c3f75
	v_alignbyte_b32 v21, v22, v21, v36                          ; d1cf0015 04922b16
	v_alignbyte_b32 v23, v23, v22, v36                          ; d1cf0017 04922d17
	v_mac_f32_e32 v25, v37, v38                                 ; 2c324d25
	v_cvt_f32_i32_sdwa v22, sext(v21) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e2c0af9 000b0615
	v_cvt_f32_i32_sdwa v36, sext(v21) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e480af9 000a0615
	v_cvt_f32_i32_sdwa v37, sext(v21) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e4a0af9 00090615
	v_cvt_f32_i32_sdwa v21, sext(v21) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e2a0af9 00080615
	v_cvt_f32_i32_sdwa v38, sext(v23) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e4c0af9 000b0617
	v_mul_f32_e32 v31, v31, v38                                 ; 0a3e4d1f
	v_cvt_f32_i32_sdwa v38, sext(v23) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e4c0af9 000a0617
	v_mac_f32_e32 v31, v30, v38                                 ; 2c3e4d1e
	v_cvt_f32_i32_sdwa v38, sext(v23) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e4c0af9 00090617
	v_cvt_f32_i32_sdwa v23, sext(v23) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e2e0af9 00080617
	v_mac_f32_e32 v31, v29, v38                                 ; 2c3e4d1d
	v_add_u32_e32 v38, s9, v26                                  ; 684c3409
	v_mac_f32_e32 v31, v28, v23                                 ; 2c3e2f1c
	v_lshrrev_b32_e32 v38, 5, v38                               ; 204c4c85
	v_add_u32_e32 v38, s18, v38                                 ; 684c4c12
	v_lshlrev_b32_e32 v9, 1, v38                                ; 24124c81
	v_lshl_add_u32 v38, v38, 5, v9                              ; d1fd0026 04250b26
	v_add_u32_e32 v11, 2, v38                                   ; 68164c82
	v_add_u32_e32 v23, v11, v27                                 ; 682e370b
	v_and_b32_e32 v11, -4, v11                                  ; 261616c4
	v_add_u32_e32 v11, v11, v27                                 ; 6816370b
	v_mac_f32_e32 v31, v7, v36                                  ; 2c3e4907
	v_add_u32_e32 v36, s10, v26                                 ; 6848340a
	v_mac_f32_e32 v31, v8, v22                                  ; 2c3e2d08
	v_lshrrev_b32_e32 v36, 5, v36                               ; 20484885
	v_mac_f32_e32 v31, v6, v37                                  ; 2c3e4b06
	v_add_u32_e32 v36, s18, v36                                 ; 68484812
	v_lshlrev_b32_e32 v37, 1, v36                               ; 244a4881
	v_lshl_add_u32 v36, v36, 5, v37                             ; d1fd0024 04950b24
	v_add_u32_e32 v6, 2, v36                                    ; 680c4882
	v_add_u32_e32 v7, v6, v27                                   ; 680e3706
	v_and_b32_e32 v6, -4, v6                                    ; 260c0cc4
	v_mov_b32_e32 v9, v7                                        ; 7e120307
	v_add_u32_e32 v6, v6, v27                                   ; 680c3706
	buffer_load_dwordx3 v[28:30], v11, s[24:27], 0 offen        ; e0581000 80061c0b
	buffer_load_short_d16 v38, v38, s[24:27], 0 offen           ; e0901000 80062626
	buffer_load_dwordx3 v[6:8], v6, s[24:27], 0 offen           ; e0581000 80060606
	buffer_load_short_d16 v11, v36, s[24:27], 0 offen           ; e0901000 80060b24
	v_add_u32_e32 v26, s11, v26                                 ; 6834340b
	v_mac_f32_e32 v31, v5, v21                                  ; 2c3e2b05
	s_waitcnt vmcnt(8)                                          ; bf8c3f78
	v_cvt_f32_f16_e32 v37, v24                                  ; 7e4a1718
	v_lshrrev_b32_e32 v26, 5, v26                               ; 20343485
	v_mac_f32_e32 v10, v31, v37                                 ; 2c144b1f
	v_add_u32_e32 v26, s18, v26                                 ; 68343412
	v_lshlrev_b32_e32 v21, 1, v26                               ; 242a3481
	v_lshl_add_u32 v26, v26, 5, v21                             ; d1fd001a 04550b1a
	v_add_u32_e32 v22, 2, v26                                   ; 682c3482
	v_add_u32_e32 v36, v22, v27                                 ; 68483716
	v_and_b32_e32 v22, -4, v22                                  ; 262c2cc4
	v_add_u32_e32 v22, v22, v27                                 ; 682c3716
	s_waitcnt vmcnt(5)                                          ; bf8c3f75
	v_alignbyte_b32 v32, v33, v32, v35                          ; d1cf0020 048e4121
	v_alignbyte_b32 v34, v34, v33, v35                          ; d1cf0022 048e4322
	v_cvt_f32_i32_sdwa v21, sext(v32) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e2a0af9 000a0620
	v_cvt_f32_i32_sdwa v24, sext(v32) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e300af9 00090620
	v_cvt_f32_i32_sdwa v5, sext(v32) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e0a0af9 000b0620
	v_cvt_f32_i32_sdwa v32, sext(v32) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e400af9 00080620
	v_cvt_f32_i32_sdwa v27, sext(v34) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e360af9 000b0622
	v_cvt_f32_i32_sdwa v33, sext(v34) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e420af9 00090622
	v_cvt_f32_i32_sdwa v31, sext(v34) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e3e0af9 000a0622
	v_mov_b32_e32 v35, v32                                      ; 7e460320
	v_mul_f32_e32 v27, v15, v27                                 ; 0a36370f
	v_mac_f32_e32 v27, v14, v31                                 ; 2c363f0e
	v_mac_f32_e32 v27, v13, v33                                 ; 2c36430d
	buffer_load_dwordx3 v[31:33], v22, s[24:27], 0 offen        ; e0581000 80061f16
	buffer_load_short_d16 v37, v26, s[24:27], 0 offen           ; e0901000 8006251a
	v_cvt_f32_i32_sdwa v34, sext(v34) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e440af9 00080622
	s_addk_i32 s1, 0x600                                        ; b7010600
	v_mac_f32_e32 v27, v12, v34                                 ; 2c36450c
	v_mac_f32_e32 v27, v18, v21                                 ; 2c362b12
	v_mac_f32_e32 v27, v19, v5                                  ; 2c360b13
	v_add_u32_e32 v5, s1, v0                                    ; 680a0001
	v_mac_f32_e32 v27, v17, v24                                 ; 2c363111
	s_waitcnt vmcnt(6)                                          ; bf8c3f76
	v_cvt_f32_f16_e32 v24, v20                                  ; 7e301714
	v_and_b32_e32 v21, 31, v5                                   ; 262a0a9f
	v_mac_f32_e32 v27, v16, v35                                 ; 2c364710
	v_sub_u32_e32 v22, v5, v21                                  ; 6a2c2b05
	v_mac_f32_e32 v1, v27, v24                                  ; 2c02311b
	v_add3_u32 v22, v21, s4, v22                                ; d1ff0016 04580915
	v_lshrrev_b32_e32 v22, 2, v22                               ; 202c2c82
	v_lshlrev_b32_e32 v22, 4, v22                               ; 242c2c84
	v_mov_b32_e32 v24, v21                                      ; 7e300315
	s_waitcnt vmcnt(5)                                          ; bf8c3f75
	v_alignbyte_b32 v28, v29, v28, v23                          ; d1cf001c 045e391d
	v_alignbyte_b32 v30, v30, v29, v23                          ; d1cf001e 045e3b1e
	v_cvt_f32_i32_sdwa v27, sext(v28) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e360af9 000a061c
	v_cvt_f32_i32_sdwa v34, sext(v30) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e440af9 000b061e
	v_cvt_f32_i32_sdwa v35, sext(v30) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e460af9 000a061e
	v_cvt_f32_i32_sdwa v20, sext(v30) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e280af9 0009061e
	v_cvt_f32_i32_sdwa v30, sext(v30) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e3c0af9 0008061e
	v_mul_f32_e32 v34, v15, v34                                 ; 0a44450f
	v_mac_f32_e32 v34, v14, v35                                 ; 2c44470e
	v_mac_f32_e32 v34, v13, v20                                 ; 2c44290d
	v_mac_f32_e32 v34, v12, v30                                 ; 2c443d0c
	v_mac_f32_e32 v34, v18, v27                                 ; 2c443712
	v_mov_b32_e32 v27, v22                                      ; 7e360316
	buffer_load_dwordx4 v[20:23], v22, s[28:31], 0 offen        ; e05c1000 80071416
	v_cvt_f32_i32_sdwa v26, sext(v28) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e340af9 000b061c
	v_cvt_f32_i32_sdwa v29, sext(v28) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e3a0af9 0009061c
	v_cvt_f32_i32_sdwa v28, sext(v28) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e380af9 0008061c
	s_waitcnt vmcnt(4)                                          ; bf8c3f74
	v_alignbyte_b32 v6, v7, v6, v9                              ; d1cf0006 04260d07
	v_alignbyte_b32 v8, v8, v7, v9                              ; d1cf0008 04260f08
	v_mac_f32_e32 v34, v19, v26                                 ; 2c443513
	v_cvt_f32_i32_sdwa v30, sext(v6) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e3c0af9 000a0606
	v_mov_b32_e32 v7, v25                                       ; 7e0e0319
	v_mac_f32_e32 v34, v17, v29                                 ; 2c443b11
	v_mac_f32_e32 v34, v16, v28                                 ; 2c443910
	v_cvt_f32_f16_e32 v28, v38                                  ; 7e381726
	v_mac_f32_e32 v4, v34, v28                                  ; 2c083922
	buffer_load_dwordx4 v[25:28], v27, s[28:31], 0 offen offset:16 ; e05c1010 8007191b
	v_cvt_f32_i32_sdwa v29, sext(v6) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e3a0af9 000b0606
	v_cvt_f32_i32_sdwa v34, sext(v6) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e440af9 00090606
	v_cvt_f32_i32_sdwa v6, sext(v6) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e0c0af9 00080606
	v_cvt_f32_i32_sdwa v38, sext(v8) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e4c0af9 000a0608
	v_cvt_f32_i32_sdwa v35, sext(v8) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e460af9 000b0608
	v_mul_f32_e32 v35, v15, v35                                 ; 0a46470f
	v_mac_f32_e32 v35, v14, v38                                 ; 2c464d0e
	v_cvt_f32_i32_sdwa v38, sext(v8) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e4c0af9 00090608
	v_cvt_f32_i32_sdwa v8, sext(v8) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e100af9 00080608
	v_mac_f32_e32 v35, v13, v38                                 ; 2c464d0d
	v_mov_b32_e32 v38, v5                                       ; 7e4c0305
	v_mac_f32_e32 v35, v12, v8                                  ; 2c46110c
	v_add_u32_e32 v8, s5, v5                                    ; 68100a05
	v_mac_f32_e32 v35, v18, v30                                 ; 2c463d12
	v_lshrrev_b32_e32 v8, 5, v8                                 ; 20101085
	v_mac_f32_e32 v35, v19, v29                                 ; 2c463b13
	v_add_u32_e32 v8, s18, v8                                   ; 68101012
	v_mac_f32_e32 v35, v17, v34                                 ; 2c464511
	v_mov_b32_e32 v34, v4                                       ; 7e440304
	v_lshlrev_b32_e32 v9, 1, v8                                 ; 24121081
	v_mac_f32_e32 v35, v16, v6                                  ; 2c460d10
	v_lshl_add_u32 v8, v8, 5, v9                                ; d1fd0008 04250b08
	v_add_u32_e32 v29, 2, v8                                    ; 683a1082
	v_add_u32_e32 v30, v29, v24                                 ; 683c311d
	v_and_b32_e32 v29, -4, v29                                  ; 263a3ac4
	v_add_u32_e32 v29, v29, v24                                 ; 683a311d
	buffer_load_dwordx3 v[4:6], v29, s[24:27], 0 offen          ; e0581000 8006041d
	buffer_load_short_d16_hi v37, v8, s[24:27], 0 offen         ; e0941000 80062508
	s_waitcnt vmcnt(6)                                          ; bf8c3f76
	v_cvt_f32_f16_e32 v8, v11                                   ; 7e10170b
	s_waitcnt vmcnt(5)                                          ; bf8c3f75
	v_alignbyte_b32 v31, v32, v31, v36                          ; d1cf001f 04923f20
	v_alignbyte_b32 v33, v33, v32, v36                          ; d1cf0021 04924121
	v_mac_f32_e32 v7, v35, v8                                   ; 2c0e1123
	v_add_u32_e32 v8, s9, v38                                   ; 68104c09
	v_cvt_f32_i32_sdwa v29, sext(v31) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e3a0af9 0009061f
	v_cvt_f32_i32_sdwa v11, sext(v31) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e160af9 000a061f
	v_cvt_f32_i32_sdwa v9, sext(v31) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e120af9 000b061f
	v_cvt_f32_i32_sdwa v31, sext(v31) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e3e0af9 0008061f
	v_cvt_f32_i32_sdwa v35, sext(v33) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e460af9 000a0621
	v_cvt_f32_i32_sdwa v32, sext(v33) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e400af9 000b0621
	v_cvt_f32_i32_sdwa v36, sext(v33) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e480af9 00090621
	v_cvt_f32_i32_sdwa v33, sext(v33) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e420af9 00080621
	v_lshrrev_b32_e32 v8, 5, v8                                 ; 20101085
	v_mul_f32_e32 v15, v15, v32                                 ; 0a1e410f
	v_mov_b32_e32 v32, v11                                      ; 7e40030b
	v_add_u32_e32 v8, s18, v8                                   ; 68101012
	v_mac_f32_e32 v15, v14, v35                                 ; 2c1e470e
	v_mac_f32_e32 v15, v13, v36                                 ; 2c1e490d
	v_mac_f32_e32 v15, v12, v33                                 ; 2c1e430c
	v_lshlrev_b32_e32 v12, 1, v8                                ; 24181081
	v_lshl_add_u32 v8, v8, 5, v12                               ; d1fd0008 04310b08
	v_add_u32_e32 v13, 2, v8                                    ; 681a1082
	v_add_u32_e32 v14, v13, v24                                 ; 681c310d
	v_and_b32_e32 v13, -4, v13                                  ; 261a1ac4
	v_add_u32_e32 v13, v13, v24                                 ; 681a310d
	buffer_load_dwordx3 v[11:13], v13, s[24:27], 0 offen        ; e0581000 80060b0d
	buffer_load_short_d16 v33, v8, s[24:27], 0 offen            ; e0901000 80062108
	v_add_u32_e32 v35, s10, v38                                 ; 68464c0a
	v_mac_f32_e32 v15, v18, v32                                 ; 2c1e4112
	v_lshrrev_b32_e32 v35, 5, v35                               ; 20464685
	v_mac_f32_e32 v15, v19, v9                                  ; 2c1e1313
	v_add_u32_e32 v35, s18, v35                                 ; 68464612
	v_mac_f32_e32 v15, v17, v29                                 ; 2c1e3b11
	v_lshlrev_b32_e32 v36, 1, v35                               ; 24484681
	v_lshl_add_u32 v35, v35, 5, v36                             ; d1fd0023 04910b23
	v_add_u32_e32 v8, 2, v35                                    ; 68104682
	v_add_u32_e32 v9, v8, v24                                   ; 68123108
	v_and_b32_e32 v8, -4, v8                                    ; 261010c4
	v_add_u32_e32 v8, v8, v24                                   ; 68103108
	buffer_load_dwordx3 v[17:19], v8, s[24:27], 0 offen         ; e0581000 80061108
	buffer_load_short_d16 v29, v35, s[24:27], 0 offen           ; e0901000 80061d23
	v_add_u32_e32 v38, s11, v38                                 ; 684c4c0b
	v_mac_f32_e32 v15, v16, v31                                 ; 2c1e3f10
	v_lshrrev_b32_e32 v38, 5, v38                               ; 204c4c85
	v_add_u32_e32 v38, s18, v38                                 ; 684c4c12
	v_lshlrev_b32_e32 v31, 1, v38                               ; 243e4c81
	v_lshl_add_u32 v38, v38, 5, v31                             ; d1fd0026 047d0b26
	v_add_u32_e32 v32, 2, v38                                   ; 68404c82
	v_add_u32_e32 v35, v32, v24                                 ; 68463120
	v_and_b32_e32 v32, -4, v32                                  ; 264040c4
	v_add_u32_e32 v32, v32, v24                                 ; 68403120
	s_waitcnt vmcnt(5)                                          ; bf8c3f75
	v_alignbyte_b32 v4, v5, v4, v30                             ; d1cf0004 047a0905
	v_alignbyte_b32 v6, v6, v5, v30                             ; d1cf0006 047a0b06
	s_waitcnt vmcnt(4)                                          ; bf8c3f74
	v_cvt_f32_f16_e32 v36, v37                                  ; 7e481725
	v_cvt_f32_i32_sdwa v30, sext(v6) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e3c0af9 00090606
	v_cvt_f32_i32_sdwa v24, sext(v6) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e300af9 000a0606
	v_cvt_f32_i32_sdwa v16, sext(v6) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e200af9 000b0606
	v_mac_f32_e32 v10, v15, v36                                 ; 2c14490f
	v_mul_f32_e32 v16, v28, v16                                 ; 0a20211c
	v_mac_f32_e32 v16, v27, v24                                 ; 2c20311b
	v_mac_f32_e32 v16, v26, v30                                 ; 2c203d1a
	buffer_load_dwordx3 v[30:32], v32, s[24:27], 0 offen        ; e0581000 80061e20
	buffer_load_short_d16 v36, v38, s[24:27], 0 offen           ; e0901000 80062426
	v_cvt_f32_i32_sdwa v5, sext(v4) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e0a0af9 000b0604
	v_cvt_f32_i32_sdwa v15, sext(v4) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e1e0af9 00090604
	v_cvt_f32_i32_sdwa v8, sext(v4) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e100af9 000a0604
	v_cvt_f32_i32_sdwa v4, sext(v4) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e080af9 00080604
	v_cvt_f32_i32_sdwa v6, sext(v6) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e0c0af9 00080606
	s_add_u32 s0, 4, s0                                         ; 80000084
	v_cvt_f32_f16_sdwa v37, v37 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e4a16f9 00050625
	v_mac_f32_e32 v16, v25, v6                                  ; 2c200d19
	v_mac_f32_e32 v16, v22, v8                                  ; 2c201116
	v_mac_f32_e32 v16, v23, v5                                  ; 2c200b17
	v_mac_f32_e32 v16, v21, v15                                 ; 2c201f15
	v_mac_f32_e32 v16, v20, v4                                  ; 2c200914
	v_mac_f32_e32 v1, v16, v37                                  ; 2c024b10
	s_waitcnt vmcnt(5)                                          ; bf8c3f75
	v_alignbyte_b32 v11, v12, v11, v14                          ; d1cf000b 043a170c
	v_alignbyte_b32 v13, v13, v12, v14                          ; d1cf000d 043a190d
	v_cvt_f32_i32_sdwa v4, sext(v11) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e080af9 000a060b
	v_cvt_f32_i32_sdwa v38, sext(v11) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e4c0af9 000b060b
	v_cvt_f32_i32_sdwa v5, sext(v11) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e0a0af9 0009060b
	v_cvt_f32_i32_sdwa v11, sext(v11) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e160af9 0008060b
	v_cvt_f32_i32_sdwa v8, sext(v13) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e100af9 000a060d
	v_cvt_f32_i32_sdwa v12, sext(v13) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e180af9 0009060d
	v_cvt_f32_i32_sdwa v6, sext(v13) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e0c0af9 000b060d
	v_cvt_f32_i32_sdwa v13, sext(v13) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e1a0af9 0008060d
	v_mul_f32_e32 v6, v28, v6                                   ; 0a0c0d1c
	v_mac_f32_e32 v6, v27, v8                                   ; 2c0c111b
	v_mac_f32_e32 v6, v26, v12                                  ; 2c0c191a
	v_mac_f32_e32 v6, v25, v13                                  ; 2c0c1b19
	s_waitcnt vmcnt(4)                                          ; bf8c3f74
	v_cvt_f32_f16_e32 v13, v33                                  ; 7e1a1721
	v_mac_f32_e32 v6, v22, v4                                   ; 2c0c0916
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_alignbyte_b32 v17, v18, v17, v9                           ; d1cf0011 04262312
	v_alignbyte_b32 v19, v19, v18, v9                           ; d1cf0013 04262513
	v_mac_f32_e32 v6, v23, v38                                  ; 2c0c4d17
	v_cvt_f32_i32_sdwa v14, sext(v17) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e1c0af9 000b0611
	v_cvt_f32_i32_sdwa v15, sext(v17) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e1e0af9 000a0611
	v_cvt_f32_i32_sdwa v16, sext(v17) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e200af9 00090611
	v_cvt_f32_i32_sdwa v17, sext(v17) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e220af9 00080611
	v_cvt_f32_i32_sdwa v24, sext(v19) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e300af9 000a0613
	v_cvt_f32_i32_sdwa v18, sext(v19) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e240af9 000b0613
	v_cvt_f32_i32_sdwa v33, sext(v19) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e420af9 00090613
	v_cvt_f32_i32_sdwa v19, sext(v19) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e260af9 00080613
	v_mac_f32_e32 v6, v21, v5                                   ; 2c0c0b15
	v_mul_f32_e32 v18, v28, v18                                 ; 0a24251c
	v_mac_f32_e32 v6, v20, v11                                  ; 2c0c1714
	v_mac_f32_e32 v18, v27, v24                                 ; 2c24311b
	v_mad_f32 v4, v6, v13, v34                                  ; d1c10004 048a1b06
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_cvt_f32_f16_e32 v34, v29                                  ; 7e44171d
	v_mac_f32_e32 v18, v26, v33                                 ; 2c24431a
	v_mac_f32_e32 v18, v25, v19                                 ; 2c242719
	v_mac_f32_e32 v18, v22, v15                                 ; 2c241f16
	v_mac_f32_e32 v18, v23, v14                                 ; 2c241d17
	v_mac_f32_e32 v18, v21, v16                                 ; 2c242115
	v_mac_f32_e32 v18, v20, v17                                 ; 2c242314
	v_mad_f32 v5, v18, v34, v7                                  ; d1c10005 041e4512
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_alignbyte_b32 v30, v31, v30, v35                          ; d1cf001e 048e3d1f
	v_alignbyte_b32 v32, v32, v31, v35                          ; d1cf0020 048e3f20
	v_cvt_f32_i32_sdwa v37, sext(v30) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e4a0af9 000a061e
	v_cvt_f32_i32_sdwa v38, sext(v30) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e4c0af9 0009061e
	v_cvt_f32_i32_sdwa v35, sext(v30) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e460af9 000b061e
	v_cvt_f32_i32_sdwa v30, sext(v30) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e3c0af9 0008061e
	v_cvt_f32_i32_sdwa v7, sext(v32) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e0e0af9 000a0620
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_cvt_f32_f16_e32 v9, v36                                   ; 7e121724
	v_cvt_f32_i32_sdwa v6, sext(v32) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e0c0af9 000b0620
	v_cvt_f32_i32_sdwa v8, sext(v32) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e100af9 00090620
	v_cvt_f32_i32_sdwa v32, sext(v32) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e400af9 00080620
	v_mul_f32_e32 v28, v28, v6                                  ; 0a380d1c
	v_mac_f32_e32 v28, v27, v7                                  ; 2c380f1b
	v_mac_f32_e32 v28, v26, v8                                  ; 2c38111a
	v_mac_f32_e32 v28, v25, v32                                 ; 2c384119
	v_mac_f32_e32 v28, v22, v37                                 ; 2c384b16
	v_mac_f32_e32 v28, v23, v35                                 ; 2c384717
	v_mac_f32_e32 v28, v21, v38                                 ; 2c384d15
	v_mac_f32_e32 v28, v20, v30                                 ; 2c383d14
	v_mad_f32 v6, v28, v9, v10                                  ; d1c10006 042a131c
BB5:
	s_mov_b64 s[4:5], exec                                      ; be84017e
	v_cmpx_ge_u32_e32 vcc, s0, v3                               ; 7dbc0600
BB6:
	v_mov_b32_e32 v3, s0                                        ; 7e060200
	s_andn2_b64 s[4:5], s[4:5], exec                            ; 89847e04
	s_cbranch_scc1 BB10                                         ; bf85fcce
BB11:
	s_mov_b64 exec, -1                                          ; befe01c1
	v_and_b32_e32 v7, -2, v2                                    ; 260e04c2
	s_branch BB12                                               ; bf82019d
BB17:
	s_mov_b64 exec, s[0:1]                                      ; befe0100
	s_mov_b32 s0, s2                                            ; be800002
	s_movk_i32 s1, 0x8000                                       ; b0018000
	s_load_dwordx8 s[24:31], s[0:1], 0x0                        ; c00e0600 00000000
	s_mul_i32 s0, s6, s17                                       ; 92001106
	v_lshl_add_u32 v8, v3, 9, v0                                ; d1fd0008 04011303
	v_and_b32_e32 v9, 31, v8                                    ; 2612109f
	v_sub_u32_e32 v10, v8, v9                                   ; 6a141308
	v_add3_u32 v10, v9, s0, v10                                 ; d1ff000a 04280109
	v_lshrrev_b32_e32 v10, 2, v10                               ; 20141482
	v_lshlrev_b32_e32 v10, 4, v10                               ; 24141484
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_load_dwordx4 v[12:15], v10, s[28:31], 0 offen        ; e05c1000 80070c0a
	buffer_load_dwordx4 v[16:19], v10, s[28:31], 0 offen offset:16 ; e05c1010 8007100a
	s_mul_i32 s1, s16, s3                                       ; 92010310
	s_add_u32 s4, s1, s3                                        ; 80040301
	v_add_u32_e32 v11, s1, v8                                   ; 68161001
	v_add_u32_e32 v23, s4, v8                                   ; 682e1004
	v_lshrrev_b32_e32 v11, 5, v11                               ; 20161685
	v_lshrrev_b32_e32 v23, 5, v23                               ; 202e2e85
	s_add_u32 s5, s4, s3                                        ; 80050304
	v_add_u32_e32 v11, s18, v11                                 ; 68161612
	v_add_u32_e32 v23, s18, v23                                 ; 682e2e12
	v_add_u32_e32 v27, s5, v8                                   ; 68361005
	v_lshlrev_b32_e32 v20, 1, v11                               ; 24281681
	v_lshlrev_b32_e32 v24, 1, v23                               ; 24302e81
	v_lshrrev_b32_e32 v27, 5, v27                               ; 20363685
	v_lshl_add_u32 v11, v11, 5, v20                             ; d1fd000b 04510b0b
	v_lshl_add_u32 v23, v23, 5, v24                             ; d1fd0017 04610b17
	v_add_u32_e32 v27, s18, v27                                 ; 68363612
	v_add_u32_e32 v21, 2, v11                                   ; 682a1682
	v_add_u32_e32 v25, 2, v23                                   ; 68322e82
	v_lshlrev_b32_e32 v28, 1, v27                               ; 24383681
	v_add_u32_e32 v22, v21, v9                                  ; 682c1315
	v_and_b32_e32 v21, -4, v21                                  ; 262a2ac4
	v_add_u32_e32 v26, v25, v9                                  ; 68341319
	v_and_b32_e32 v25, -4, v25                                  ; 263232c4
	v_lshl_add_u32 v27, v27, 5, v28                             ; d1fd001b 04710b1b
	v_add_u32_e32 v21, v21, v9                                  ; 682a1315
	v_add_u32_e32 v25, v25, v9                                  ; 68321319
	v_add_u32_e32 v29, 2, v27                                   ; 683a3682
	v_add_u32_e32 v30, v29, v9                                  ; 683c131d
	v_and_b32_e32 v29, -4, v29                                  ; 263a3ac4
	v_add_u32_e32 v29, v29, v9                                  ; 683a131d
	buffer_load_dwordx3 v[31:33], v21, s[24:27], 0 offen        ; e0581000 80061f15
	buffer_load_short_d16 v34, v11, s[24:27], 0 offen           ; e0901000 8006220b
	buffer_load_dwordx3 v[35:37], v25, s[24:27], 0 offen        ; e0581000 80062319
	buffer_load_short_d16 v38, v23, s[24:27], 0 offen           ; e0901000 80062617
	buffer_load_dwordx3 v[23:25], v29, s[24:27], 0 offen        ; e0581000 8006171d
	buffer_load_short_d16 v27, v27, s[24:27], 0 offen           ; e0901000 80061b1b
	s_add_u32 s9, s5, s3                                        ; 80090305
	v_add_u32_e32 v8, s9, v8                                    ; 68101009
	v_lshrrev_b32_e32 v8, 5, v8                                 ; 20101085
	v_add_u32_e32 v8, s18, v8                                   ; 68101012
	v_lshlrev_b32_e32 v28, 1, v8                                ; 24381081
	v_lshl_add_u32 v8, v8, 5, v28                               ; d1fd0008 04710b08
	v_add_u32_e32 v29, 2, v8                                    ; 683a1082
	v_add_u32_e32 v28, v29, v9                                  ; 6838131d
	v_and_b32_e32 v29, -4, v29                                  ; 263a3ac4
	v_add_u32_e32 v29, v29, v9                                  ; 683a131d
	s_waitcnt vmcnt(5)                                          ; bf8c3f75
	v_alignbyte_b32 v31, v32, v31, v22                          ; d1cf001f 045a3f20
	v_alignbyte_b32 v33, v33, v32, v22                          ; d1cf0021 045a4121
	v_cvt_f32_i32_sdwa v22, sext(v33) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e2c0af9 00090621
	v_cvt_f32_i32_sdwa v21, sext(v33) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e2a0af9 000a0621
	v_cvt_f32_i32_sdwa v20, sext(v33) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e280af9 000b0621
	v_cvt_f32_i32_sdwa v33, sext(v33) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e420af9 00080621
	v_mul_f32_e32 v20, v19, v20                                 ; 0a282913
	v_mac_f32_e32 v20, v18, v21                                 ; 2c282b12
	v_mac_f32_e32 v20, v17, v22                                 ; 2c282d11
	v_mac_f32_e32 v20, v16, v33                                 ; 2c284310
	v_mov_b32_e32 v9, v20                                       ; 7e120314
	buffer_load_dwordx3 v[20:22], v29, s[24:27], 0 offen        ; e0581000 8006141d
	buffer_load_short_d16 v29, v8, s[24:27], 0 offen            ; e0901000 80061d08
	v_cvt_f32_i32_sdwa v11, sext(v31) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e160af9 0009061f
	v_cvt_f32_i32_sdwa v32, sext(v31) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e400af9 000b061f
	v_cvt_f32_i32_sdwa v10, sext(v31) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e140af9 000a061f
	v_cvt_f32_i32_sdwa v31, sext(v31) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e3e0af9 0008061f
	s_movk_i32 s10, 0x200                                       ; b00a0200
	s_waitcnt vmcnt(6)                                          ; bf8c3f76
	v_cvt_f32_f16_e32 v34, v34                                  ; 7e441722
	s_waitcnt vmcnt(5)                                          ; bf8c3f75
	v_alignbyte_b32 v35, v36, v35, v26                          ; d1cf0023 046a4724
	v_alignbyte_b32 v37, v37, v36, v26                          ; d1cf0025 046a4925
	v_mac_f32_e32 v9, v14, v10                                  ; 2c12150e
	v_cvt_f32_i32_sdwa v8, sext(v35) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e100af9 000a0623
	v_cvt_f32_i32_sdwa v36, sext(v35) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e480af9 000b0623
	v_cvt_f32_i32_sdwa v10, sext(v37) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e140af9 000b0625
	v_mac_f32_e32 v9, v15, v32                                  ; 2c12410f
	v_mul_f32_e32 v10, v19, v10                                 ; 0a141513
	v_cvt_f32_i32_sdwa v26, sext(v37) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e340af9 00090625
	v_mac_f32_e32 v9, v13, v11                                  ; 2c12170d
	v_cvt_f32_i32_sdwa v11, sext(v37) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e160af9 000a0625
	v_cvt_f32_i32_sdwa v37, sext(v37) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e4a0af9 00080625
	v_mac_f32_e32 v9, v12, v31                                  ; 2c123f0c
	v_lshl_add_u32 v31, v3, 9, s10                              ; d1fd001f 00291303
	v_mac_f32_e32 v10, v18, v11                                 ; 2c141712
	v_mac_f32_e32 v1, v9, v34                                   ; 2c024509
	v_cvt_f32_i32_sdwa v9, sext(v35) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e120af9 00090623
	v_cvt_f32_i32_sdwa v35, sext(v35) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e460af9 00080623
	v_add_u32_e32 v31, v31, v0                                  ; 683e011f
	v_mac_f32_e32 v10, v17, v26                                 ; 2c143511
	v_and_b32_e32 v32, 31, v31                                  ; 26403e9f
	v_mac_f32_e32 v10, v16, v37                                 ; 2c144b10
	v_sub_u32_e32 v33, v31, v32                                 ; 6a42411f
	v_mac_f32_e32 v10, v14, v8                                  ; 2c14110e
	v_mov_b32_e32 v8, v35                                       ; 7e100323
	v_add3_u32 v33, v32, s0, v33                                ; d1ff0021 04840120
	v_mac_f32_e32 v10, v15, v36                                 ; 2c14490f
	v_lshrrev_b32_e32 v33, 2, v33                               ; 20424282
	v_lshlrev_b32_e32 v33, 4, v33                               ; 24424284
	buffer_load_dwordx4 v[34:37], v33, s[28:31], 0 offen        ; e05c1000 80072221
	s_waitcnt vmcnt(4)                                          ; bf8c3f74
	v_alignbyte_b32 v23, v24, v23, v30                          ; d1cf0017 047a2f18
	v_alignbyte_b32 v25, v25, v24, v30                          ; d1cf0019 047a3119
	v_mac_f32_e32 v10, v13, v9                                  ; 2c14130d
	v_cvt_f32_f16_e32 v9, v38                                   ; 7e121726
	v_cvt_f32_i32_sdwa v24, sext(v23) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e300af9 00090617
	v_cvt_f32_i32_sdwa v11, sext(v23) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e160af9 000a0617
	v_cvt_f32_i32_sdwa v30, sext(v25) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e3c0af9 000a0619
	v_cvt_f32_i32_sdwa v38, sext(v25) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e4c0af9 00090619
	v_cvt_f32_i32_sdwa v26, sext(v25) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e340af9 000b0619
	v_cvt_f32_i32_sdwa v25, sext(v25) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e320af9 00080619
	v_mac_f32_e32 v10, v12, v8                                  ; 2c14110c
	v_mul_f32_e32 v26, v19, v26                                 ; 0a343513
	v_mac_f32_e32 v4, v10, v9                                   ; 2c08130a
	v_cvt_f32_i32_sdwa v10, sext(v23) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e140af9 000b0617
	v_mac_f32_e32 v26, v18, v30                                 ; 2c343d12
	v_mac_f32_e32 v26, v17, v38                                 ; 2c344d11
	v_mov_b32_e32 v38, v10                                      ; 7e4c030a
	v_mac_f32_e32 v26, v16, v25                                 ; 2c343310
	v_mov_b32_e32 v25, v11                                      ; 7e32030b
	buffer_load_dwordx4 v[8:11], v33, s[28:31], 0 offen offset:16 ; e05c1010 80070821
	v_cvt_f32_i32_sdwa v23, sext(v23) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e2e0af9 00080617
	v_add_u32_e32 v30, s1, v31                                  ; 683c3e01
	v_mac_f32_e32 v26, v14, v25                                 ; 2c34330e
	v_lshrrev_b32_e32 v30, 5, v30                               ; 203c3c85
	v_mac_f32_e32 v26, v15, v38                                 ; 2c344d0f
	v_add_u32_e32 v30, s18, v30                                 ; 683c3c12
	v_mac_f32_e32 v26, v13, v24                                 ; 2c34310d
	s_waitcnt vmcnt(4)                                          ; bf8c3f74
	v_cvt_f32_f16_e32 v24, v27                                  ; 7e30171b
	v_lshlrev_b32_e32 v33, 1, v30                               ; 24423c81
	v_mac_f32_e32 v26, v12, v23                                 ; 2c342f0c
	v_lshl_add_u32 v30, v30, 5, v33                             ; d1fd001e 04850b1e
	v_mac_f32_e32 v5, v26, v24                                  ; 2c0a311a
	v_mov_b32_e32 v24, v17                                      ; 7e300311
	v_add_u32_e32 v38, 2, v30                                   ; 684c3c82
	v_add_u32_e32 v23, v38, v32                                 ; 682e4126
	v_and_b32_e32 v38, -4, v38                                  ; 264c4cc4
	v_add_u32_e32 v38, v38, v32                                 ; 684c4126
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_alignbyte_b32 v22, v22, v21, v28                          ; d1cf0016 04722b16
	v_alignbyte_b32 v20, v21, v20, v28                          ; d1cf0014 04722915
	v_mov_b32_e32 v21, v16                                      ; 7e2a0310
	v_cvt_f32_i32_sdwa v33, sext(v22) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e420af9 000a0616
	v_cvt_f32_i32_sdwa v28, sext(v22) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e380af9 000b0616
	v_mul_f32_e32 v19, v19, v28                                 ; 0a263913
	v_mac_f32_e32 v19, v18, v33                                 ; 2c264312
	buffer_load_dwordx3 v[16:18], v38, s[24:27], 0 offen        ; e0581000 80061026
	buffer_load_short_d16 v28, v30, s[24:27], 0 offen           ; e0901000 80061c1e
	v_cvt_f32_i32_sdwa v30, sext(v22) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e3c0af9 00090616
	v_cvt_f32_i32_sdwa v22, sext(v22) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e2c0af9 00080616
	v_cvt_f32_i32_sdwa v26, sext(v20) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e340af9 000a0614
	v_cvt_f32_i32_sdwa v27, sext(v20) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e360af9 00090614
	v_cvt_f32_i32_sdwa v25, sext(v20) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e320af9 000b0614
	v_cvt_f32_i32_sdwa v20, sext(v20) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e280af9 00080614
	v_add_u32_e32 v33, s4, v31                                  ; 68423e04
	v_mac_f32_e32 v19, v24, v30                                 ; 2c263d18
	v_lshrrev_b32_e32 v33, 5, v33                               ; 20424285
	v_mac_f32_e32 v19, v21, v22                                 ; 2c262d15
	v_add_u32_e32 v33, s18, v33                                 ; 68424212
	v_mac_f32_e32 v19, v14, v26                                 ; 2c26350e
	v_lshlrev_b32_e32 v38, 1, v33                               ; 244c4281
	v_mac_f32_e32 v19, v15, v25                                 ; 2c26330f
	v_add_u32_e32 v15, s5, v31                                  ; 681e3e05
	v_lshl_add_u32 v33, v33, 5, v38                             ; d1fd0021 04990b21
	v_mac_f32_e32 v19, v13, v27                                 ; 2c26370d
	v_lshrrev_b32_e32 v15, 5, v15                               ; 201e1e85
	v_mov_b32_e32 v13, v20                                      ; 7e1a0314
	v_add_u32_e32 v38, 2, v33                                   ; 684c4282
	v_add_u32_e32 v15, s18, v15                                 ; 681e1e12
	v_add_u32_e32 v14, v38, v32                                 ; 681c4126
	v_and_b32_e32 v38, -4, v38                                  ; 264c4cc4
	v_lshlrev_b32_e32 v21, 1, v15                               ; 242a1e81
	v_add_u32_e32 v38, v38, v32                                 ; 684c4126
	v_lshl_add_u32 v15, v15, 5, v21                             ; d1fd000f 04550b0f
	v_add_u32_e32 v22, 2, v15                                   ; 682c1e82
	v_add_u32_e32 v24, v22, v32                                 ; 68304116
	v_and_b32_e32 v22, -4, v22                                  ; 262c2cc4
	v_add_u32_e32 v22, v22, v32                                 ; 682c4116
	buffer_load_dwordx3 v[25:27], v38, s[24:27], 0 offen        ; e0581000 80061926
	buffer_load_short_d16 v30, v33, s[24:27], 0 offen           ; e0901000 80061e21
	buffer_load_dwordx3 v[20:22], v22, s[24:27], 0 offen        ; e0581000 80061416
	buffer_load_short_d16 v15, v15, s[24:27], 0 offen           ; e0901000 80060f0f
	v_add_u32_e32 v31, s9, v31                                  ; 683e3e09
	v_mac_f32_e32 v19, v12, v13                                 ; 2c261b0c
	s_waitcnt vmcnt(8)                                          ; bf8c3f78
	v_cvt_f32_f16_e32 v12, v29                                  ; 7e18171d
	v_lshrrev_b32_e32 v31, 5, v31                               ; 203e3e85
	v_mac_f32_e32 v6, v19, v12                                  ; 2c0c1913
	v_add_u32_e32 v31, s18, v31                                 ; 683e3e12
	v_lshlrev_b32_e32 v33, 1, v31                               ; 24423e81
	v_lshl_add_u32 v31, v31, 5, v33                             ; d1fd001f 04850b1f
	v_add_u32_e32 v38, 2, v31                                   ; 684c3e82
	v_add_u32_e32 v12, v38, v32                                 ; 68184126
	v_and_b32_e32 v38, -4, v38                                  ; 264c4cc4
	v_add_u32_e32 v38, v38, v32                                 ; 684c4126
	s_waitcnt vmcnt(5)                                          ; bf8c3f75
	v_alignbyte_b32 v18, v18, v17, v23                          ; d1cf0012 045e2312
	v_alignbyte_b32 v16, v17, v16, v23                          ; d1cf0010 045e2111
	v_cvt_f32_i32_sdwa v23, sext(v18) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e2e0af9 000b0612
	v_cvt_f32_i32_sdwa v29, sext(v18) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e3a0af9 000a0612
	v_cvt_f32_i32_sdwa v33, sext(v18) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e420af9 00090612
	v_cvt_f32_i32_sdwa v18, sext(v18) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e240af9 00080612
	v_mul_f32_e32 v23, v11, v23                                 ; 0a2e2f0b
	v_mac_f32_e32 v23, v10, v29                                 ; 2c2e3b0a
	v_mac_f32_e32 v23, v9, v33                                  ; 2c2e4309
	v_mac_f32_e32 v23, v8, v18                                  ; 2c2e2508
	v_mov_b32_e32 v18, v31                                      ; 7e24031f
	buffer_load_dwordx3 v[31:33], v38, s[24:27], 0 offen        ; e0581000 80061f26
	buffer_load_short_d16 v29, v18, s[24:27], 0 offen           ; e0901000 80061d12
	v_cvt_f32_i32_sdwa v17, sext(v16) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e220af9 000a0610
	v_cvt_f32_i32_sdwa v19, sext(v16) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e260af9 00090610
	v_cvt_f32_i32_sdwa v13, sext(v16) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e1a0af9 000b0610
	v_cvt_f32_i32_sdwa v16, sext(v16) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e200af9 00080610
	v_add_u32_e32 v3, 2, v3                                     ; 68060682
	s_waitcnt vmcnt(6)                                          ; bf8c3f76
	v_cvt_f32_f16_e32 v38, v28                                  ; 7e4c171c
	v_mac_f32_e32 v23, v36, v17                                 ; 2c2e2324
	v_mac_f32_e32 v23, v37, v13                                 ; 2c2e1b25
	v_mac_f32_e32 v23, v35, v19                                 ; 2c2e2723
	v_mac_f32_e32 v23, v34, v16                                 ; 2c2e2122
	v_mac_f32_e32 v1, v23, v38                                  ; 2c024d17
	s_waitcnt vmcnt(5)                                          ; bf8c3f75
	v_alignbyte_b32 v25, v26, v25, v14                          ; d1cf0019 043a331a
	v_alignbyte_b32 v27, v27, v26, v14                          ; d1cf001b 043a351b
	v_cvt_f32_i32_sdwa v38, sext(v25) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e4c0af9 000b0619
	v_cvt_f32_i32_sdwa v14, sext(v25) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e1c0af9 00090619
	v_cvt_f32_i32_sdwa v13, sext(v25) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e1a0af9 000a0619
	v_cvt_f32_i32_sdwa v25, sext(v25) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e320af9 00080619
	s_waitcnt vmcnt(4)                                          ; bf8c3f74
	v_cvt_f32_f16_e32 v19, v30                                  ; 7e26171e
	v_cvt_f32_i32_sdwa v18, sext(v27) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e240af9 0009061b
	v_cvt_f32_i32_sdwa v17, sext(v27) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e220af9 000a061b
	v_cvt_f32_i32_sdwa v16, sext(v27) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e200af9 000b061b
	v_cvt_f32_i32_sdwa v27, sext(v27) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e360af9 0008061b
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_alignbyte_b32 v20, v21, v20, v24                          ; d1cf0014 04622915
	v_alignbyte_b32 v22, v22, v21, v24                          ; d1cf0016 04622b16
	v_mul_f32_e32 v16, v11, v16                                 ; 0a20210b
	v_cvt_f32_i32_sdwa v21, sext(v20) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e2a0af9 000b0614
	v_cvt_f32_i32_sdwa v23, sext(v20) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e2e0af9 000a0614
	v_cvt_f32_i32_sdwa v24, sext(v20) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e300af9 00090614
	v_cvt_f32_i32_sdwa v20, sext(v20) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e280af9 00080614
	v_cvt_f32_i32_sdwa v26, sext(v22) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e340af9 000a0616
	v_mac_f32_e32 v16, v10, v17                                 ; 2c20230a
	v_mac_f32_e32 v16, v9, v18                                  ; 2c202509
	v_mac_f32_e32 v16, v8, v27                                  ; 2c203708
	v_cvt_f32_i32_sdwa v27, sext(v22) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e360af9 00090616
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_cvt_f32_f16_e32 v28, v15                                  ; 7e38170f
	v_mac_f32_e32 v16, v36, v13                                 ; 2c201b24
	v_mac_f32_e32 v16, v37, v38                                 ; 2c204d25
	v_mac_f32_e32 v16, v35, v14                                 ; 2c201d23
	v_mac_f32_e32 v16, v34, v25                                 ; 2c203322
	v_cvt_f32_i32_sdwa v25, sext(v22) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e320af9 000b0616
	v_cvt_f32_i32_sdwa v22, sext(v22) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e2c0af9 00080616
	v_mac_f32_e32 v4, v16, v19                                  ; 2c082710
	v_mul_f32_e32 v25, v11, v25                                 ; 0a32330b
	v_mac_f32_e32 v25, v10, v26                                 ; 2c32350a
	v_mac_f32_e32 v25, v9, v27                                  ; 2c323709
	v_mac_f32_e32 v25, v8, v22                                  ; 2c322d08
	v_mac_f32_e32 v25, v36, v23                                 ; 2c322f24
	v_mac_f32_e32 v25, v37, v21                                 ; 2c322b25
	v_mac_f32_e32 v25, v35, v24                                 ; 2c323123
	v_mac_f32_e32 v25, v34, v20                                 ; 2c322922
	v_mac_f32_e32 v5, v25, v28                                  ; 2c0a3919
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_alignbyte_b32 v33, v33, v32, v12                          ; d1cf0021 04324121
	v_alignbyte_b32 v31, v32, v31, v12                          ; d1cf001f 04323f20
	v_cvt_f32_i32_sdwa v14, sext(v33) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e1c0af9 00090621
	v_cvt_f32_i32_sdwa v12, sext(v33) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e180af9 000b0621
	v_cvt_f32_i32_sdwa v13, sext(v33) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e1a0af9 000a0621
	v_cvt_f32_i32_sdwa v33, sext(v33) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e420af9 00080621
	v_cvt_f32_i32_sdwa v38, sext(v31) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e4c0af9 0009061f
	v_cvt_f32_i32_sdwa v30, sext(v31) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e3c0af9 000b061f
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_cvt_f32_f16_e32 v15, v29                                  ; 7e1e171d
	v_cvt_f32_i32_sdwa v32, sext(v31) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e400af9 000a061f
	v_cvt_f32_i32_sdwa v31, sext(v31) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e3e0af9 0008061f
	v_mul_f32_e32 v11, v11, v12                                 ; 0a16190b
	v_mac_f32_e32 v11, v10, v13                                 ; 2c161b0a
	v_mac_f32_e32 v11, v9, v14                                  ; 2c161d09
	v_mac_f32_e32 v11, v8, v33                                  ; 2c164308
	v_mac_f32_e32 v11, v36, v32                                 ; 2c164124
	v_mac_f32_e32 v11, v37, v30                                 ; 2c163d25
	v_mac_f32_e32 v11, v35, v38                                 ; 2c164d23
	v_mac_f32_e32 v11, v34, v31                                 ; 2c163f22
	v_mac_f32_e32 v6, v11, v15                                  ; 2c0c1f0b
BB12:
	s_mov_b64 s[0:1], exec                                      ; be80017e
	v_cmpx_ge_u32_e32 vcc, v3, v7                               ; 7dbc0f03
BB13:
	s_andn2_b64 s[0:1], s[0:1], exec                            ; 89807e00
	s_cbranch_scc1 BB17                                         ; bf85fe5f
BB18:
	s_mov_b64 exec, -1                                          ; befe01c1
	s_branch BB19                                               ; bf8200ce
BB24:
	s_mov_b64 exec, s[0:1]                                      ; befe0100
	s_mov_b32 s0, s2                                            ; be800002
	s_movk_i32 s1, 0x8000                                       ; b0018000
	s_load_dwordx8 s[24:31], s[0:1], 0x0                        ; c00e0600 00000000
	s_mul_i32 s0, s6, s17                                       ; 92001106
	v_lshl_add_u32 v7, v3, 9, v0                                ; d1fd0007 04011303
	v_and_b32_e32 v8, 31, v7                                    ; 26100e9f
	v_sub_u32_e32 v9, v7, v8                                    ; 6a121107
	v_add3_u32 v9, v8, s0, v9                                   ; d1ff0009 04240108
	v_lshrrev_b32_e32 v9, 2, v9                                 ; 20121282
	v_lshlrev_b32_e32 v9, 4, v9                                 ; 24121284
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_load_dwordx4 v[12:15], v9, s[28:31], 0 offen         ; e05c1000 80070c09
	buffer_load_dwordx4 v[16:19], v9, s[28:31], 0 offen offset:16 ; e05c1010 80071009
	s_mul_i32 s1, s16, s3                                       ; 92010310
	v_add_u32_e32 v10, s1, v7                                   ; 68140e01
	s_add_u32 s1, s1, s3                                        ; 80010301
	v_lshrrev_b32_e32 v10, 5, v10                               ; 20141485
	v_add_u32_e32 v22, s1, v7                                   ; 682c0e01
	v_add_u32_e32 v10, s18, v10                                 ; 68141412
	s_add_u32 s1, s1, s3                                        ; 80010301
	v_lshrrev_b32_e32 v22, 5, v22                               ; 202c2c85
	v_lshlrev_b32_e32 v11, 1, v10                               ; 24161481
	v_add_u32_e32 v26, s1, v7                                   ; 68340e01
	v_add_u32_e32 v22, s18, v22                                 ; 682c2c12
	v_lshl_add_u32 v10, v10, 5, v11                             ; d1fd000a 042d0b0a
	v_lshrrev_b32_e32 v26, 5, v26                               ; 20343485
	v_lshlrev_b32_e32 v23, 1, v22                               ; 242e2c81
	v_add_u32_e32 v20, 2, v10                                   ; 68281482
	v_add_u32_e32 v26, s18, v26                                 ; 68343412
	v_lshl_add_u32 v22, v22, 5, v23                             ; d1fd0016 045d0b16
	v_add_u32_e32 v21, v20, v8                                  ; 682a1114
	v_and_b32_e32 v20, -4, v20                                  ; 262828c4
	v_lshlrev_b32_e32 v27, 1, v26                               ; 24363481
	v_add_u32_e32 v24, 2, v22                                   ; 68302c82
	v_add_u32_e32 v20, v20, v8                                  ; 68281114
	v_lshl_add_u32 v26, v26, 5, v27                             ; d1fd001a 046d0b1a
	v_add_u32_e32 v25, v24, v8                                  ; 68321118
	v_and_b32_e32 v24, -4, v24                                  ; 263030c4
	v_add_u32_e32 v28, 2, v26                                   ; 68383482
	v_add_u32_e32 v24, v24, v8                                  ; 68301118
	v_add_u32_e32 v29, v28, v8                                  ; 683a111c
	v_and_b32_e32 v28, -4, v28                                  ; 263838c4
	v_add_u32_e32 v28, v28, v8                                  ; 6838111c
	buffer_load_dwordx3 v[30:32], v20, s[24:27], 0 offen        ; e0581000 80061e14
	buffer_load_short_d16 v33, v10, s[24:27], 0 offen           ; e0901000 8006210a
	buffer_load_dwordx3 v[34:36], v24, s[24:27], 0 offen        ; e0581000 80062218
	buffer_load_short_d16 v37, v22, s[24:27], 0 offen           ; e0901000 80062516
	buffer_load_dwordx3 v[9:11], v28, s[24:27], 0 offen         ; e0581000 8006091c
	buffer_load_short_d16 v20, v26, s[24:27], 0 offen           ; e0901000 8006141a
	s_add_u32 s1, s1, s3                                        ; 80010301
	v_add_u32_e32 v7, s1, v7                                    ; 680e0e01
	v_lshrrev_b32_e32 v7, 5, v7                                 ; 200e0e85
	v_add_u32_e32 v7, s18, v7                                   ; 680e0e12
	v_lshlrev_b32_e32 v22, 1, v7                                ; 242c0e81
	v_lshl_add_u32 v7, v7, 5, v22                               ; d1fd0007 04590b07
	v_add_u32_e32 v23, 2, v7                                    ; 682e0e82
	v_add_u32_e32 v24, v23, v8                                  ; 68301117
	v_and_b32_e32 v23, -4, v23                                  ; 262e2ec4
	v_add_u32_e32 v23, v23, v8                                  ; 682e1117
	s_waitcnt vmcnt(5)                                          ; bf8c3f75
	v_alignbyte_b32 v30, v31, v30, v21                          ; d1cf001e 04563d1f
	v_alignbyte_b32 v32, v32, v31, v21                          ; d1cf0020 04563f20
	v_cvt_f32_i32_sdwa v38, sext(v32) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e4c0af9 000a0620
	v_cvt_f32_i32_sdwa v31, sext(v32) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e3e0af9 000b0620
	v_mul_f32_e32 v31, v19, v31                                 ; 0a3e3f13
	v_mac_f32_e32 v31, v18, v38                                 ; 2c3e4d12
	v_cvt_f32_i32_sdwa v38, sext(v32) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e4c0af9 00090620
	v_mac_f32_e32 v31, v17, v38                                 ; 2c3e4d11
	buffer_load_dwordx3 v[21:23], v23, s[24:27], 0 offen        ; e0581000 80061517
	buffer_load_short_d16 v38, v7, s[24:27], 0 offen            ; e0901000 80062607
	v_cvt_f32_i32_sdwa v28, sext(v30) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e380af9 0009061e
	v_cvt_f32_i32_sdwa v27, sext(v30) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e360af9 000a061e
	v_cvt_f32_i32_sdwa v26, sext(v30) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e340af9 000b061e
	v_cvt_f32_i32_sdwa v30, sext(v30) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e3c0af9 0008061e
	v_cvt_f32_i32_sdwa v32, sext(v32) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e400af9 00080620
	v_add_u32_e32 v3, 1, v3                                     ; 68060681
	s_waitcnt vmcnt(5)                                          ; bf8c3f75
	v_alignbyte_b32 v34, v35, v34, v25                          ; d1cf0022 04664523
	v_alignbyte_b32 v36, v36, v35, v25                          ; d1cf0024 04664724
	v_mac_f32_e32 v31, v16, v32                                 ; 2c3e4110
	v_cvt_f32_i32_sdwa v32, sext(v36) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e400af9 000a0624
	v_mac_f32_e32 v31, v14, v27                                 ; 2c3e370e
	v_cvt_f32_i32_sdwa v27, sext(v34) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e360af9 000b0622
	v_mac_f32_e32 v31, v15, v26                                 ; 2c3e350f
	v_cvt_f32_f16_e32 v26, v33                                  ; 7e341721
	v_cvt_f32_i32_sdwa v33, sext(v36) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e420af9 00090624
	v_mac_f32_e32 v31, v13, v28                                 ; 2c3e390d
	v_cvt_f32_i32_sdwa v28, sext(v34) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e380af9 000a0622
	v_mac_f32_e32 v31, v12, v30                                 ; 2c3e3d0c
	v_cvt_f32_i32_sdwa v30, sext(v34) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e3c0af9 00090622
	v_cvt_f32_i32_sdwa v34, sext(v34) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e440af9 00080622
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_alignbyte_b32 v9, v10, v9, v29                            ; d1cf0009 0476130a
	v_mac_f32_e32 v1, v31, v26                                  ; 2c02351f
	v_cvt_f32_i32_sdwa v31, sext(v36) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e3e0af9 000b0624
	v_cvt_f32_i32_sdwa v36, sext(v36) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e480af9 00080624
	v_alignbyte_b32 v11, v11, v10, v29                          ; d1cf000b 0476150b
	v_cvt_f32_i32_sdwa v35, sext(v9) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e460af9 000b0609
	v_mul_f32_e32 v31, v19, v31                                 ; 0a3e3f13
	v_cvt_f32_i32_sdwa v7, sext(v11) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e0e0af9 000b060b
	v_cvt_f32_i32_sdwa v8, sext(v11) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e100af9 000a060b
	v_cvt_f32_i32_sdwa v10, sext(v11) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e140af9 0009060b
	v_mac_f32_e32 v31, v18, v32                                 ; 2c3e4112
	v_mul_f32_e32 v7, v19, v7                                   ; 0a0e0f13
	v_cvt_f32_i32_sdwa v11, sext(v11) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e160af9 0008060b
	v_mac_f32_e32 v31, v17, v33                                 ; 2c3e4311
	v_mac_f32_e32 v7, v18, v8                                   ; 2c0e1112
	v_mac_f32_e32 v31, v16, v36                                 ; 2c3e4910
	v_cvt_f32_i32_sdwa v36, sext(v9) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e480af9 000a0609
	v_mac_f32_e32 v7, v17, v10                                  ; 2c0e1511
	v_mac_f32_e32 v31, v14, v28                                 ; 2c3e390e
	v_mac_f32_e32 v7, v16, v11                                  ; 2c0e1710
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_cvt_f32_f16_e32 v11, v20                                  ; 7e161714
	v_mac_f32_e32 v31, v15, v27                                 ; 2c3e370f
	v_mac_f32_e32 v7, v14, v36                                  ; 2c0e490e
	v_mac_f32_e32 v31, v13, v30                                 ; 2c3e3d0d
	v_mac_f32_e32 v7, v15, v35                                  ; 2c0e470f
	v_mac_f32_e32 v31, v12, v34                                 ; 2c3e450c
	v_cvt_f32_f16_e32 v34, v37                                  ; 7e441725
	v_cvt_f32_i32_sdwa v37, sext(v9) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e4a0af9 00090609
	v_cvt_f32_i32_sdwa v9, sext(v9) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e120af9 00080609
	v_mac_f32_e32 v4, v31, v34                                  ; 2c08451f
	v_mac_f32_e32 v7, v13, v37                                  ; 2c0e4b0d
	v_mac_f32_e32 v7, v12, v9                                   ; 2c0e130c
	v_mac_f32_e32 v5, v7, v11                                   ; 2c0a1707
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_alignbyte_b32 v23, v23, v22, v24                          ; d1cf0017 04622d17
	v_alignbyte_b32 v21, v22, v21, v24                          ; d1cf0015 04622b16
	v_cvt_f32_i32_sdwa v27, sext(v23) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e360af9 00090617
	v_cvt_f32_i32_sdwa v25, sext(v23) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e320af9 000b0617
	v_cvt_f32_i32_sdwa v26, sext(v23) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e340af9 000a0617
	v_cvt_f32_i32_sdwa v23, sext(v23) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e2e0af9 00080617
	v_cvt_f32_i32_sdwa v22, sext(v21) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e2c0af9 000a0615
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_cvt_f32_f16_e32 v28, v38                                  ; 7e381726
	v_cvt_f32_i32_sdwa v24, sext(v21) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e300af9 00090615
	v_cvt_f32_i32_sdwa v20, sext(v21) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e280af9 000b0615
	v_cvt_f32_i32_sdwa v21, sext(v21) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e2a0af9 00080615
	v_mul_f32_e32 v19, v19, v25                                 ; 0a263313
	v_mac_f32_e32 v19, v18, v26                                 ; 2c263512
	v_mac_f32_e32 v19, v17, v27                                 ; 2c263711
	v_mac_f32_e32 v19, v16, v23                                 ; 2c262f10
	v_mac_f32_e32 v19, v14, v22                                 ; 2c262d0e
	v_mac_f32_e32 v19, v15, v20                                 ; 2c26290f
	v_mac_f32_e32 v19, v13, v24                                 ; 2c26310d
	v_mac_f32_e32 v19, v12, v21                                 ; 2c262b0c
	v_mac_f32_e32 v6, v19, v28                                  ; 2c0c3913
BB19:
	s_mov_b64 s[0:1], exec                                      ; be80017e
	v_cmpx_ge_u32_e32 vcc, v3, v2                               ; 7dbc0503
BB20:
	s_andn2_b64 s[0:1], s[0:1], exec                            ; 89807e00
	s_cbranch_scc1 BB24                                         ; bf85ff2e
BB25:
	s_mov_b64 exec, -1                                          ; befe01c1
	s_or_saveexec_b64 s[4:5], -1                                ; be8421c1
	v_cndmask_b32_e64 v39, 0, v1, s[4:5]                        ; d1000027 00120280
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v39, v39, v39 quad_perm:[1,0,3,2] row_mask:0xf bank_mask:0xf ; 024e4efa ff00b127
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v39, v39, v39 quad_perm:[2,3,0,1] row_mask:0xf bank_mask:0xf ; 024e4efa ff004e27
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v39, v39, v39 row_half_mirror row_mask:0xf bank_mask:0xf ; 024e4efa ff014127
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v39, v39, v39 row_mirror row_mask:0xf bank_mask:0xf ; 024e4efa ff014027
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v39, v39, v39 row_bcast:15 row_mask:0xa bank_mask:0xf ; 024e4efa af014227
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v39, v39, v39 row_bcast:31 row_mask:0xc bank_mask:0xf ; 024e4efa cf014327
	s_mov_b64 exec, s[4:5]                                      ; befe0104
	v_readlane_b32 s0, v39, 63                                  ; d2890000 00017f27
	s_or_saveexec_b64 s[4:5], -1                                ; be8421c1
	v_cndmask_b32_e64 v39, 0, v4, s[4:5]                        ; d1000027 00120880
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v39, v39, v39 quad_perm:[1,0,3,2] row_mask:0xf bank_mask:0xf ; 024e4efa ff00b127
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v39, v39, v39 quad_perm:[2,3,0,1] row_mask:0xf bank_mask:0xf ; 024e4efa ff004e27
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v39, v39, v39 row_half_mirror row_mask:0xf bank_mask:0xf ; 024e4efa ff014127
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v39, v39, v39 row_mirror row_mask:0xf bank_mask:0xf ; 024e4efa ff014027
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v39, v39, v39 row_bcast:15 row_mask:0xa bank_mask:0xf ; 024e4efa af014227
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v39, v39, v39 row_bcast:31 row_mask:0xc bank_mask:0xf ; 024e4efa cf014327
	s_mov_b64 exec, s[4:5]                                      ; befe0104
	v_readlane_b32 s1, v39, 63                                  ; d2890001 00017f27
	s_or_saveexec_b64 s[4:5], -1                                ; be8421c1
	v_cndmask_b32_e64 v39, 0, v5, s[4:5]                        ; d1000027 00120a80
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v39, v39, v39 quad_perm:[1,0,3,2] row_mask:0xf bank_mask:0xf ; 024e4efa ff00b127
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v39, v39, v39 quad_perm:[2,3,0,1] row_mask:0xf bank_mask:0xf ; 024e4efa ff004e27
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v39, v39, v39 row_half_mirror row_mask:0xf bank_mask:0xf ; 024e4efa ff014127
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v39, v39, v39 row_mirror row_mask:0xf bank_mask:0xf ; 024e4efa ff014027
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v39, v39, v39 row_bcast:15 row_mask:0xa bank_mask:0xf ; 024e4efa af014227
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v39, v39, v39 row_bcast:31 row_mask:0xc bank_mask:0xf ; 024e4efa cf014327
	s_mov_b64 exec, s[4:5]                                      ; befe0104
	v_readlane_b32 s3, v39, 63                                  ; d2890003 00017f27
	s_or_saveexec_b64 s[10:11], -1                              ; be8a21c1
	v_cndmask_b32_e64 v39, 0, v6, s[10:11]                      ; d1000027 002a0c80
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v39, v39, v39 quad_perm:[1,0,3,2] row_mask:0xf bank_mask:0xf ; 024e4efa ff00b127
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v39, v39, v39 quad_perm:[2,3,0,1] row_mask:0xf bank_mask:0xf ; 024e4efa ff004e27
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v39, v39, v39 row_half_mirror row_mask:0xf bank_mask:0xf ; 024e4efa ff014127
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v39, v39, v39 row_mirror row_mask:0xf bank_mask:0xf ; 024e4efa ff014027
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v39, v39, v39 row_bcast:15 row_mask:0xa bank_mask:0xf ; 024e4efa af014227
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v39, v39, v39 row_bcast:31 row_mask:0xc bank_mask:0xf ; 024e4efa cf014327
	s_mov_b64 exec, 1                                           ; befe0181
	v_readlane_b32 s4, v39, 63                                  ; d2890004 00017f27
	s_mov_b64 s[10:11], exec                                    ; be8a017e
BB26:
	v_mov_b32_e32 v0, s0                                        ; 7e000200
	v_mov_b32_e32 v1, s1                                        ; 7e020201
	v_mov_b32_e32 v2, s3                                        ; 7e040203
	v_mov_b32_e32 v3, s4                                        ; 7e060204
	v_mov_b32_e32 v4, 0                                         ; 7e080280
	ds_write_b128 v4, v[0:3]                                    ; d9be0000 00000004
BB31:
	s_mov_b64 exec, s[10:11]                                    ; befe010a
	s_cbranch_execz BB217                                       ; bf8807f6
BB32:
	s_mov_b32 s5, s3                                            ; be850003
	s_movk_i32 s3, 0x8000                                       ; b0038000
	s_load_dwordx4 s[12:15], s[2:3], 0x20                       ; c00a0301 00000020
	s_mul_i32 s7, s7, s17                                       ; 92071107
	v_mov_b32_e32 v0, s0                                        ; 7e000200
	s_mov_b32 s0, 0                                             ; be800080
	v_mov_b32_e32 v1, s1                                        ; 7e020201
	v_mov_b32_e32 v3, s4                                        ; 7e060204
	v_mov_b32_e32 v2, s5                                        ; 7e040205
	s_add_u32 s7, s7, s16                                       ; 80071007
	s_and_b32 s19, s19, 63                                      ; 8613bf13
	s_bitcmp1_b32 s8, 1                                         ; bf0d8108
	s_mov_b32 s6, src_scc                                       ; be8600fd
	s_cmp_lg_i32 s19, 0                                         ; bf018013
	s_mov_b32 s9, src_scc                                       ; be8900fd
	s_bitcmp1_b32 s8, 0                                         ; bf0d8008
BB33:
	s_mov_b32 s4, src_scc                                       ; be8400fd
	s_cmp_lt_i32 s0, 2                                          ; bf048200
	s_cselect_b64 vcc, -1, 0                                    ; 85ea80c1
	s_cmp_lt_i32 s0, 3                                          ; bf048300
	s_cselect_b64 s[10:11], -1, 0                               ; 858a80c1
	s_or_b64 s[16:17], vcc, s[10:11]                            ; 87900a6a
	s_andn2_b64 s[20:21], s[10:11], vcc                         ; 89946a0a
	s_cmp_lt_i32 s0, 1                                          ; bf048100
	v_cndmask_b32_e64 v4, 0, v3, s[16:17]                       ; d1000004 00420680
	v_cndmask_b32_e64 v5, v2, 0, s[20:21]                       ; d1000005 00510102
	s_cselect_b64 s[22:23], -1, 0                               ; 859680c1
	s_andn2_b64 s[24:25], vcc, s[22:23]                         ; 8998166a
	s_and_b64 s[26:27], vcc, s[22:23]                           ; 869a166a
	s_cmp_lg_i32 s9, 0                                          ; bf018009
	v_cndmask_b32_e64 v6, v1, 0, s[24:25]                       ; d1000006 00610101
	v_cndmask_b32_e64 v7, v0, 0, s[26:27]                       ; d1000007 00690100
	s_cbranch_scc0 BB39                                         ; bf840021
BB34:
	s_mov_b32 s1, src_scc                                       ; be8100fd
	s_lshl_b32 s5, s0, 2                                        ; 8e058200
	v_mov_b32_e32 v8, s5                                        ; 7e100205
	ds_read_b32 v8, v8                                          ; d86c0000 08000008
	s_mov_b32 s5, 1                                             ; be850081
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_cndmask_b32_e64 v6, v8, v6, s[22:23]                      ; d1000006 005a0d08
	v_cndmask_b32_e64 v7, v7, v8, s[22:23]                      ; d1000007 005a1107
	v_cndmask_b32_e64 v4, v8, v4, s[10:11]                      ; d1000004 002a0908
	v_cndmask_b32_e64 v5, v5, v8, s[10:11]                      ; d1000005 002a1105
	v_cndmask_b32_e32 v1, v1, v6, vcc                           ; 00020d01
	v_cndmask_b32_e32 v0, v0, v7, vcc                           ; 00000f00
	v_cndmask_b32_e32 v3, v4, v3, vcc                           ; 00060704
	v_cndmask_b32_e32 v2, v5, v2, vcc                           ; 00040505
BB35:
	s_cmp_ge_u32 s5, s19                                        ; bf091305
	s_cbranch_scc1 BB40                                         ; bf850011
BB37:
	v_mov_b32_e32 v4, 0x7fc00000                                ; 7e0802ff 7fc00000
	s_add_u32 s5, s5, 1                                         ; 80058105
	v_cndmask_b32_e64 v3, v4, v3, s[16:17]                      ; d1000003 00420704
	v_cndmask_b32_e64 v2, v2, v4, s[20:21]                      ; d1000002 00520902
	v_cndmask_b32_e64 v1, v1, v4, s[24:25]                      ; d1000001 00620901
	v_cndmask_b32_e64 v0, v0, v4, s[26:27]                      ; d1000000 006a0900
	s_branch BB35                                               ; bf82fff2
BB39:
	s_mov_b32 s1, src_scc                                       ; be8100fd
	v_mov_b32_e32 v0, v7                                        ; 7e000307
	v_mov_b32_e32 v1, v6                                        ; 7e020306
	v_mov_b32_e32 v2, v5                                        ; 7e040305
	v_mov_b32_e32 v3, v4                                        ; 7e060304
BB40:
	s_cmp_lg_i32 s4, 0                                          ; bf018004
	s_cbranch_scc0 BB42                                         ; bf840018
BB41:
	s_load_dwordx4 s[28:31], s[2:3], 0x30                       ; c00a0701 00000030
	s_mov_b32 s4, src_scc                                       ; be8400fd
	s_add_u32 s5, s7, s0                                        ; 80050007
	s_lshl_b32 s5, s5, 2                                        ; 8e058205
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s5, s[28:31], s5                        ; c020014e 00000005
	v_cndmask_b32_e64 v4, v1, v0, s[22:23]                      ; d1000004 005a0101
	v_cndmask_b32_e64 v5, v3, v2, s[10:11]                      ; d1000005 002a0503
	v_cndmask_b32_e32 v5, v5, v4, vcc                           ; 000a0905
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v5, s5, v5                                    ; 020a0a05
	v_cndmask_b32_e64 v3, v5, v3, s[16:17]                      ; d1000003 00420705
	v_cndmask_b32_e64 v2, v2, v5, s[20:21]                      ; d1000002 00520b02
	v_cndmask_b32_e64 v1, v1, v5, s[24:25]                      ; d1000001 00620b01
	v_cndmask_b32_e64 v0, v0, v5, s[26:27]                      ; d1000000 006a0b00
	s_branch BB43                                               ; bf820001
BB42:
	s_mov_b32 s4, src_scc                                       ; be8400fd
BB43:
	s_cmp_lg_i32 s6, 0                                          ; bf018006
	s_cbranch_scc0 BB45                                         ; bf840018
BB44:
	s_load_dwordx4 s[28:31], s[2:3], 0x40                       ; c00a0701 00000040
	s_mov_b32 s5, src_scc                                       ; be8500fd
	s_add_u32 s6, s7, s0                                        ; 80060007
	s_lshl_b32 s6, s6, 2                                        ; 8e068206
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s6, s[28:31], s6                        ; c020018e 00000006
	v_cndmask_b32_e64 v4, v1, v0, s[22:23]                      ; d1000004 005a0101
	v_cndmask_b32_e64 v5, v3, v2, s[10:11]                      ; d1000005 002a0503
	v_cndmask_b32_e32 v5, v5, v4, vcc                           ; 000a0905
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v5, s6, v5                                    ; 020a0a06
	v_cndmask_b32_e64 v3, v5, v3, s[16:17]                      ; d1000003 00420705
	v_cndmask_b32_e64 v2, v2, v5, s[20:21]                      ; d1000002 00520b02
	v_cndmask_b32_e64 v1, v1, v5, s[24:25]                      ; d1000001 00620b01
	v_cndmask_b32_e64 v0, v0, v5, s[26:27]                      ; d1000000 006a0b00
	s_branch BB46                                               ; bf820001
BB45:
	s_mov_b32 s5, src_scc                                       ; be8500fd
BB46:
	s_add_u32 s6, s7, s0                                        ; 80060007
	v_cndmask_b32_e64 v4, v1, v0, s[22:23]                      ; d1000004 005a0101
	v_cndmask_b32_e64 v5, v3, v2, s[10:11]                      ; d1000005 002a0503
	s_lshl_b32 s6, s6, 2                                        ; 8e068206
	v_cndmask_b32_e32 v5, v5, v4, vcc                           ; 000a0905
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_store_dword v5, off, s[12:15], s6                    ; e0700000 06030580
	s_add_u32 s0, s0, 1                                         ; 80008100
	s_cmp_ge_u32 s0, 4                                          ; bf098400
	s_cbranch_scc1 BB217                                        ; bf850767
BB48:
	s_mov_b32 s6, s5                                            ; be860005
	s_mov_b32 s9, s1                                            ; be890001
	s_cmp_lg_i32 s4, 0                                          ; bf018004
	s_branch BB33                                               ; bf82ff7e
BB55:
	s_cmp_lt_u32 s16, s4                                        ; bf0a0410
	s_cbranch_scc0 BB217                                        ; bf840761
BB56:
	s_sub_i32 s4, s4, s16                                       ; 81841004
	s_add_u32 s17, s17, s9                                      ; 80110911
	s_cmp_lg_i32 s17, 0                                         ; bf018011
	s_cbranch_scc0 BB58                                         ; bf840043
BB57:
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
	v_readfirstlane_b32 s20, v2                                 ; 7e280502
	s_add_u32 s0, s0, src_scc                                   ; 8000fd00
	s_sub_i32 s15, s9, s11                                      ; 818f0b09
	s_cmp_ge_u32 s9, s11                                        ; bf090b09
	s_mul_i32 s21, s13, s20                                     ; 9215140d
	s_cselect_b32 s15, s15, s9                                  ; 850f090f
	s_cmp_ge_u32 s15, s11                                       ; bf090b0f
	s_mov_b32 s18, src_scc                                      ; be9200fd
	s_add_u32 s0, s0, src_scc                                   ; 8000fd00
	s_sub_i32 s11, s15, s11                                     ; 818b0b0f
	s_cmp_lg_i32 s18, 0                                         ; bf018012
	v_cvt_f32_u32_e32 v3, s12                                   ; 7e060c0c
	s_cselect_b32 s11, s11, s15                                 ; 850b0f0b
	s_sub_i32 s21, 0, s21                                       ; 81951580
	v_rcp_f32_e32 v3, v3                                        ; 7e064503
	s_mul_hi_u32 s21, s20, s21                                  ; 96151514
	s_add_u32 s20, s20, s21                                     ; 80141514
	v_mul_f32_e32 v3, 0x4f7ffffe, v3                            ; 0a0606ff 4f7ffffe
	s_mul_hi_u32 s20, s0, s20                                   ; 96141400
	v_cvt_u32_f32_e32 v3, v3                                    ; 7e060f03
	s_mul_i32 s22, s20, s13                                     ; 92160d14
	v_readfirstlane_b32 s25, v3                                 ; 7e320503
	s_sub_i32 s0, s0, s22                                       ; 81801600
	s_mul_i32 s26, s12, s25                                     ; 921a190c
	s_cmp_ge_u32 s0, s13                                        ; bf090d00
	s_add_u32 s20, s20, src_scc                                 ; 8014fd14
	s_sub_i32 s24, s0, s13                                      ; 81980d00
	s_cmp_ge_u32 s0, s13                                        ; bf090d00
	s_cselect_b32 s24, s24, s0                                  ; 85180018
	s_cmp_ge_u32 s24, s13                                       ; bf090d18
	s_add_u32 s20, s20, src_scc                                 ; 8014fd14
	s_sub_i32 s26, 0, s26                                       ; 819a1a80
	s_mul_i32 s20, s20, s10                                     ; 92140a14
	s_mul_hi_u32 s26, s25, s26                                  ; 961a1a19
	s_add_u32 s25, s25, s26                                     ; 80191a19
	s_mul_hi_u32 s25, s11, s25                                  ; 9619190b
	s_mul_i32 s27, s25, s12                                     ; 921b0c19
	s_sub_i32 s11, s11, s27                                     ; 818b1b0b
	s_cmp_ge_u32 s11, s12                                       ; bf090c0b
	s_add_u32 s25, s25, src_scc                                 ; 8019fd19
	s_sub_i32 s29, s11, s12                                     ; 819d0c0b
	s_cmp_ge_u32 s11, s12                                       ; bf090c0b
	s_cselect_b32 s29, s29, s11                                 ; 851d0b1d
	s_cmp_ge_u32 s29, s12                                       ; bf090c1d
	s_add_u32 s25, s25, src_scc                                 ; 8019fd19
	s_add_u32 s20, s20, s25                                     ; 80141914
	s_branch BB59                                               ; bf820001
BB58:
	s_mov_b32 s20, 0                                            ; be940080
BB59:
	s_lshr_b32 s5, s5, 5                                        ; 8f058505
	v_lshlrev_b32_e32 v0, 3, v0                                 ; 24000083
	s_and_b32 s0, s3, 0xfffffe00                                ; 8600ff03 fffffe00
	s_lshr_b32 s1, s3, 9                                        ; 8f018903
	v_mov_b32_e32 v4, 0                                         ; 7e080280
	v_mov_b32_e32 v5, 0                                         ; 7e0a0280
	v_mov_b32_e32 v6, 0                                         ; 7e0c0280
	s_mul_i32 s20, s20, s5                                      ; 92140514
	v_add_u32_e32 v1, s0, v0                                    ; 68020000
	s_mov_b32 s0, 0                                             ; be800080
	v_cmp_gt_u32_e32 vcc, s3, v1                                ; 7d980203
	v_mov_b32_e32 v1, 0                                         ; 7e020280
	v_cndmask_b32_e64 v2, 0, 1, vcc                             ; d1000002 01a90280
	v_add_u32_e32 v2, s1, v2                                    ; 68040401
	v_and_b32_e32 v3, -4, v2                                    ; 260604c4
BB60:
	s_mov_b64 s[10:11], exec                                    ; be8a017e
	v_cmpx_ge_u32_e32 vcc, s0, v3                               ; 7dbc0600
BB61:
	v_mov_b32_e32 v3, s0                                        ; 7e060200
	s_andn2_b64 s[10:11], s[10:11], exec                        ; 898a7e0a
	s_cbranch_scc0 BB114                                        ; bf84035d
BB65:
	s_mov_b64 exec, s[10:11]                                    ; befe010a
	s_mov_b32 s10, s2                                           ; be8a0002
	s_movk_i32 s11, 0x8000                                      ; b00b8000
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_load_dwordx4 s[12:15], s[10:11], 0x10                     ; c00a0305 00000010
	s_lshl_b32 s1, s0, 9                                        ; 8e018900
	s_mul_i32 s5, s6, s17                                       ; 92051106
	s_mul_i32 s9, s16, s3                                       ; 92090310
	s_cmp_lg_i32 s4, 0                                          ; bf018004
	v_add_u32_e32 v7, s1, v0                                    ; 680e0001
	v_and_b32_e32 v8, 31, v7                                    ; 26100e9f
	v_sub_u32_e32 v9, v7, v8                                    ; 6a121107
	v_add3_u32 v9, v8, s5, v9                                   ; d1ff0009 04240b08
	s_cbranch_scc0 BB76                                         ; bf8400cc
BB66:
	s_load_dwordx4 s[24:27], s[10:11], 0x0                      ; c00a0605 00000000
	v_lshrrev_b32_e32 v9, 2, v9                                 ; 20121282
	v_lshlrev_b32_e32 v9, 4, v9                                 ; 24121284
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_load_dwordx4 v[12:15], v9, s[12:15], 0 offen         ; e05c1000 80030c09
	buffer_load_dwordx4 v[16:19], v9, s[12:15], 0 offen offset:16 ; e05c1010 80031009
	v_add_u32_e32 v9, s9, v7                                    ; 68120e09
	v_lshrrev_b32_e32 v9, 5, v9                                 ; 20121285
	v_add_u32_e32 v9, s20, v9                                   ; 68121214
	v_lshlrev_b32_e32 v10, 1, v9                                ; 24141281
	v_lshl_add_u32 v9, v9, 5, v10                               ; d1fd0009 04290b09
	v_add_u32_e32 v11, 2, v9                                    ; 68161282
	v_add_u32_e32 v20, v11, v8                                  ; 6828110b
	v_and_b32_e32 v11, -4, v11                                  ; 261616c4
	v_add_u32_e32 v11, v11, v8                                  ; 6816110b
	buffer_load_dwordx3 v[21:23], v11, s[24:27], 0 offen        ; e0581000 8006150b
	buffer_load_short_d16 v24, v9, s[24:27], 0 offen            ; e0901000 80061809
	s_mov_b32 s18, src_scc                                      ; be9200fd
	s_add_u32 s21, s9, s3                                       ; 80150309
	s_cmp_lt_u32 1, s4                                          ; bf0a0481
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_alignbyte_b32 v21, v22, v21, v20                          ; d1cf0015 04522b16
	v_alignbyte_b32 v23, v23, v22, v20                          ; d1cf0017 04522d17
	v_cvt_f32_i32_sdwa v25, sext(v21) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e320af9 000b0615
	v_cvt_f32_i32_sdwa v26, sext(v21) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e340af9 000a0615
	v_cvt_f32_i32_sdwa v27, sext(v21) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e360af9 00090615
	v_cvt_f32_i32_sdwa v21, sext(v21) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e2a0af9 00080615
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_cvt_f32_f16_e32 v31, v24                                  ; 7e3e1718
	v_cvt_f32_i32_sdwa v28, sext(v23) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e380af9 000b0617
	v_cvt_f32_i32_sdwa v29, sext(v23) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e3a0af9 000a0617
	v_cvt_f32_i32_sdwa v30, sext(v23) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e3c0af9 00090617
	v_cvt_f32_i32_sdwa v23, sext(v23) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e2e0af9 00080617
	v_mul_f32_e32 v28, v19, v28                                 ; 0a383913
	v_mac_f32_e32 v28, v18, v29                                 ; 2c383b12
	v_mac_f32_e32 v28, v17, v30                                 ; 2c383d11
	v_mac_f32_e32 v28, v16, v23                                 ; 2c382f10
	v_mac_f32_e32 v28, v14, v26                                 ; 2c38350e
	v_mac_f32_e32 v28, v15, v25                                 ; 2c38330f
	v_mac_f32_e32 v28, v13, v27                                 ; 2c38370d
	v_mac_f32_e32 v28, v12, v21                                 ; 2c382b0c
	v_mac_f32_e32 v1, v28, v31                                  ; 2c023f1c
	s_cbranch_scc0 BB77                                         ; bf840092
BB67:
	v_add_u32_e32 v9, s21, v7                                   ; 68120e15
	v_lshrrev_b32_e32 v9, 5, v9                                 ; 20121285
	v_add_u32_e32 v9, s20, v9                                   ; 68121214
	v_lshlrev_b32_e32 v10, 1, v9                                ; 24141281
	v_lshl_add_u32 v9, v9, 5, v10                               ; d1fd0009 04290b09
	v_add_u32_e32 v11, 2, v9                                    ; 68161282
	v_add_u32_e32 v20, v11, v8                                  ; 6828110b
	v_and_b32_e32 v11, -4, v11                                  ; 261616c4
	v_add_u32_e32 v11, v11, v8                                  ; 6816110b
	buffer_load_dwordx3 v[21:23], v11, s[24:27], 0 offen        ; e0581000 8006150b
	buffer_load_short_d16 v24, v9, s[24:27], 0 offen            ; e0901000 80061809
	s_add_u32 s21, s21, s3                                      ; 80150315
	s_cmp_lt_u32 2, s4                                          ; bf0a0482
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_alignbyte_b32 v21, v22, v21, v20                          ; d1cf0015 04522b16
	v_alignbyte_b32 v23, v23, v22, v20                          ; d1cf0017 04522d17
	v_cvt_f32_i32_sdwa v26, sext(v21) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e340af9 000a0615
	v_cvt_f32_i32_sdwa v27, sext(v21) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e360af9 00090615
	v_cvt_f32_i32_sdwa v25, sext(v21) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e320af9 000b0615
	v_cvt_f32_i32_sdwa v21, sext(v21) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e2a0af9 00080615
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_cvt_f32_f16_e32 v31, v24                                  ; 7e3e1718
	v_cvt_f32_i32_sdwa v28, sext(v23) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e380af9 000b0617
	v_cvt_f32_i32_sdwa v29, sext(v23) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e3a0af9 000a0617
	v_cvt_f32_i32_sdwa v30, sext(v23) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e3c0af9 00090617
	v_cvt_f32_i32_sdwa v23, sext(v23) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e2e0af9 00080617
	v_mul_f32_e32 v28, v19, v28                                 ; 0a383913
	v_mac_f32_e32 v28, v18, v29                                 ; 2c383b12
	v_mac_f32_e32 v28, v17, v30                                 ; 2c383d11
	v_mac_f32_e32 v28, v16, v23                                 ; 2c382f10
	v_mac_f32_e32 v28, v14, v26                                 ; 2c38350e
	v_mac_f32_e32 v28, v15, v25                                 ; 2c38330f
	v_mac_f32_e32 v28, v13, v27                                 ; 2c38370d
	v_mac_f32_e32 v28, v12, v21                                 ; 2c382b0c
	v_mac_f32_e32 v4, v28, v31                                  ; 2c083f1c
	s_cbranch_scc0 BB77                                         ; bf840061
BB68:
	v_add_u32_e32 v9, s21, v7                                   ; 68120e15
	v_lshrrev_b32_e32 v9, 5, v9                                 ; 20121285
	v_add_u32_e32 v9, s20, v9                                   ; 68121214
	v_lshlrev_b32_e32 v10, 1, v9                                ; 24141281
	v_lshl_add_u32 v9, v9, 5, v10                               ; d1fd0009 04290b09
	v_add_u32_e32 v11, 2, v9                                    ; 68161282
	v_add_u32_e32 v20, v11, v8                                  ; 6828110b
	v_and_b32_e32 v11, -4, v11                                  ; 261616c4
	v_add_u32_e32 v11, v11, v8                                  ; 6816110b
	buffer_load_dwordx3 v[21:23], v11, s[24:27], 0 offen        ; e0581000 8006150b
	buffer_load_short_d16 v24, v9, s[24:27], 0 offen            ; e0901000 80061809
	s_add_u32 s21, s21, s3                                      ; 80150315
	s_cmp_lt_u32 3, s4                                          ; bf0a0483
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_alignbyte_b32 v21, v22, v21, v20                          ; d1cf0015 04522b16
	v_alignbyte_b32 v23, v23, v22, v20                          ; d1cf0017 04522d17
	v_cvt_f32_i32_sdwa v26, sext(v21) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e340af9 000a0615
	v_cvt_f32_i32_sdwa v27, sext(v21) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e360af9 00090615
	v_cvt_f32_i32_sdwa v25, sext(v21) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e320af9 000b0615
	v_cvt_f32_i32_sdwa v21, sext(v21) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e2a0af9 00080615
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_cvt_f32_f16_e32 v31, v24                                  ; 7e3e1718
	v_cvt_f32_i32_sdwa v28, sext(v23) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e380af9 000b0617
	v_cvt_f32_i32_sdwa v29, sext(v23) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e3a0af9 000a0617
	v_cvt_f32_i32_sdwa v30, sext(v23) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e3c0af9 00090617
	v_cvt_f32_i32_sdwa v23, sext(v23) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e2e0af9 00080617
	v_mul_f32_e32 v28, v19, v28                                 ; 0a383913
	v_mac_f32_e32 v28, v18, v29                                 ; 2c383b12
	v_mac_f32_e32 v28, v17, v30                                 ; 2c383d11
	v_mac_f32_e32 v28, v16, v23                                 ; 2c382f10
	v_mac_f32_e32 v28, v14, v26                                 ; 2c38350e
	v_mac_f32_e32 v28, v15, v25                                 ; 2c38330f
	v_mac_f32_e32 v28, v13, v27                                 ; 2c38370d
	v_mac_f32_e32 v28, v12, v21                                 ; 2c382b0c
	v_mac_f32_e32 v5, v28, v31                                  ; 2c0a3f1c
	s_cbranch_scc0 BB77                                         ; bf840030
BB69:
	v_add_u32_e32 v7, s21, v7                                   ; 680e0e15
	v_lshrrev_b32_e32 v7, 5, v7                                 ; 200e0e85
	v_add_u32_e32 v7, s20, v7                                   ; 680e0e14
	v_lshlrev_b32_e32 v9, 1, v7                                 ; 24120e81
	v_lshl_add_u32 v7, v7, 5, v9                                ; d1fd0007 04250b07
	v_add_u32_e32 v10, 2, v7                                    ; 68140e82
	v_add_u32_e32 v11, v10, v8                                  ; 6816110a
	v_and_b32_e32 v10, -4, v10                                  ; 261414c4
	v_add_u32_e32 v10, v10, v8                                  ; 6814110a
	buffer_load_dwordx3 v[20:22], v10, s[24:27], 0 offen        ; e0581000 8006140a
	buffer_load_short_d16 v23, v7, s[24:27], 0 offen            ; e0901000 80061707
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_alignbyte_b32 v20, v21, v20, v11                          ; d1cf0014 042e2915
	v_alignbyte_b32 v22, v22, v21, v11                          ; d1cf0016 042e2b16
	v_cvt_f32_i32_sdwa v24, sext(v20) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e300af9 000b0614
	v_cvt_f32_i32_sdwa v25, sext(v20) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e320af9 000a0614
	v_cvt_f32_i32_sdwa v26, sext(v20) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e340af9 00090614
	v_cvt_f32_i32_sdwa v20, sext(v20) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e280af9 00080614
	v_cvt_f32_i32_sdwa v27, sext(v22) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e360af9 000b0616
	v_cvt_f32_i32_sdwa v28, sext(v22) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e380af9 000a0616
	v_cvt_f32_i32_sdwa v29, sext(v22) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e3a0af9 00090616
	v_cvt_f32_i32_sdwa v22, sext(v22) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e2c0af9 00080616
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_cvt_f32_f16_e32 v30, v23                                  ; 7e3c1717
	v_mul_f32_e32 v19, v19, v27                                 ; 0a263713
	v_mac_f32_e32 v19, v18, v28                                 ; 2c263912
	v_mac_f32_e32 v19, v17, v29                                 ; 2c263b11
	v_mac_f32_e32 v19, v16, v22                                 ; 2c262d10
	v_mac_f32_e32 v19, v14, v25                                 ; 2c26330e
	v_mac_f32_e32 v19, v15, v24                                 ; 2c26310f
	v_mac_f32_e32 v19, v13, v26                                 ; 2c26350d
	v_mac_f32_e32 v19, v12, v20                                 ; 2c26290c
	v_mac_f32_e32 v6, v19, v30                                  ; 2c0c3d13
	s_branch BB77                                               ; bf820001
BB76:
	s_mov_b32 s18, src_scc                                      ; be9200fd
BB77:
	s_add_u32 s21, s1, 0x200                                    ; 8015ff01 00000200
	s_cmp_lg_i32 s18, 0                                         ; bf018012
	v_add_u32_e32 v7, s21, v0                                   ; 680e0015
	v_and_b32_e32 v8, 31, v7                                    ; 26100e9f
	v_sub_u32_e32 v9, v7, v8                                    ; 6a121107
	v_add3_u32 v9, v8, s5, v9                                   ; d1ff0009 04240b08
	s_cbranch_scc0 BB88                                         ; bf8400cc
BB78:
	s_load_dwordx4 s[24:27], s[10:11], 0x0                      ; c00a0605 00000000
	v_lshrrev_b32_e32 v9, 2, v9                                 ; 20121282
	v_lshlrev_b32_e32 v9, 4, v9                                 ; 24121284
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_load_dwordx4 v[12:15], v9, s[12:15], 0 offen         ; e05c1000 80030c09
	buffer_load_dwordx4 v[16:19], v9, s[12:15], 0 offen offset:16 ; e05c1010 80031009
	v_add_u32_e32 v9, s9, v7                                    ; 68120e09
	v_lshrrev_b32_e32 v9, 5, v9                                 ; 20121285
	v_add_u32_e32 v9, s20, v9                                   ; 68121214
	v_lshlrev_b32_e32 v10, 1, v9                                ; 24141281
	v_lshl_add_u32 v9, v9, 5, v10                               ; d1fd0009 04290b09
	v_add_u32_e32 v11, 2, v9                                    ; 68161282
	v_add_u32_e32 v20, v11, v8                                  ; 6828110b
	v_and_b32_e32 v11, -4, v11                                  ; 261616c4
	v_add_u32_e32 v11, v11, v8                                  ; 6816110b
	buffer_load_dwordx3 v[21:23], v11, s[24:27], 0 offen        ; e0581000 8006150b
	buffer_load_short_d16 v24, v9, s[24:27], 0 offen            ; e0901000 80061809
	s_mov_b32 s18, src_scc                                      ; be9200fd
	s_add_u32 s21, s9, s3                                       ; 80150309
	s_cmp_lt_u32 1, s4                                          ; bf0a0481
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_alignbyte_b32 v21, v22, v21, v20                          ; d1cf0015 04522b16
	v_alignbyte_b32 v23, v23, v22, v20                          ; d1cf0017 04522d17
	v_cvt_f32_i32_sdwa v25, sext(v21) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e320af9 000b0615
	v_cvt_f32_i32_sdwa v26, sext(v21) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e340af9 000a0615
	v_cvt_f32_i32_sdwa v27, sext(v21) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e360af9 00090615
	v_cvt_f32_i32_sdwa v21, sext(v21) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e2a0af9 00080615
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_cvt_f32_f16_e32 v31, v24                                  ; 7e3e1718
	v_cvt_f32_i32_sdwa v28, sext(v23) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e380af9 000b0617
	v_cvt_f32_i32_sdwa v29, sext(v23) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e3a0af9 000a0617
	v_cvt_f32_i32_sdwa v30, sext(v23) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e3c0af9 00090617
	v_cvt_f32_i32_sdwa v23, sext(v23) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e2e0af9 00080617
	v_mul_f32_e32 v28, v19, v28                                 ; 0a383913
	v_mac_f32_e32 v28, v18, v29                                 ; 2c383b12
	v_mac_f32_e32 v28, v17, v30                                 ; 2c383d11
	v_mac_f32_e32 v28, v16, v23                                 ; 2c382f10
	v_mac_f32_e32 v28, v14, v26                                 ; 2c38350e
	v_mac_f32_e32 v28, v15, v25                                 ; 2c38330f
	v_mac_f32_e32 v28, v13, v27                                 ; 2c38370d
	v_mac_f32_e32 v28, v12, v21                                 ; 2c382b0c
	v_mac_f32_e32 v1, v28, v31                                  ; 2c023f1c
	s_cbranch_scc0 BB89                                         ; bf840092
BB79:
	v_add_u32_e32 v9, s21, v7                                   ; 68120e15
	v_lshrrev_b32_e32 v9, 5, v9                                 ; 20121285
	v_add_u32_e32 v9, s20, v9                                   ; 68121214
	v_lshlrev_b32_e32 v10, 1, v9                                ; 24141281
	v_lshl_add_u32 v9, v9, 5, v10                               ; d1fd0009 04290b09
	v_add_u32_e32 v11, 2, v9                                    ; 68161282
	v_add_u32_e32 v20, v11, v8                                  ; 6828110b
	v_and_b32_e32 v11, -4, v11                                  ; 261616c4
	v_add_u32_e32 v11, v11, v8                                  ; 6816110b
	buffer_load_dwordx3 v[21:23], v11, s[24:27], 0 offen        ; e0581000 8006150b
	buffer_load_short_d16 v24, v9, s[24:27], 0 offen            ; e0901000 80061809
	s_add_u32 s21, s21, s3                                      ; 80150315
	s_cmp_lt_u32 2, s4                                          ; bf0a0482
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_alignbyte_b32 v21, v22, v21, v20                          ; d1cf0015 04522b16
	v_alignbyte_b32 v23, v23, v22, v20                          ; d1cf0017 04522d17
	v_cvt_f32_i32_sdwa v26, sext(v21) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e340af9 000a0615
	v_cvt_f32_i32_sdwa v27, sext(v21) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e360af9 00090615
	v_cvt_f32_i32_sdwa v25, sext(v21) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e320af9 000b0615
	v_cvt_f32_i32_sdwa v21, sext(v21) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e2a0af9 00080615
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_cvt_f32_f16_e32 v31, v24                                  ; 7e3e1718
	v_cvt_f32_i32_sdwa v28, sext(v23) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e380af9 000b0617
	v_cvt_f32_i32_sdwa v29, sext(v23) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e3a0af9 000a0617
	v_cvt_f32_i32_sdwa v30, sext(v23) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e3c0af9 00090617
	v_cvt_f32_i32_sdwa v23, sext(v23) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e2e0af9 00080617
	v_mul_f32_e32 v28, v19, v28                                 ; 0a383913
	v_mac_f32_e32 v28, v18, v29                                 ; 2c383b12
	v_mac_f32_e32 v28, v17, v30                                 ; 2c383d11
	v_mac_f32_e32 v28, v16, v23                                 ; 2c382f10
	v_mac_f32_e32 v28, v14, v26                                 ; 2c38350e
	v_mac_f32_e32 v28, v15, v25                                 ; 2c38330f
	v_mac_f32_e32 v28, v13, v27                                 ; 2c38370d
	v_mac_f32_e32 v28, v12, v21                                 ; 2c382b0c
	v_mac_f32_e32 v4, v28, v31                                  ; 2c083f1c
	s_cbranch_scc0 BB89                                         ; bf840061
BB80:
	v_add_u32_e32 v9, s21, v7                                   ; 68120e15
	v_lshrrev_b32_e32 v9, 5, v9                                 ; 20121285
	v_add_u32_e32 v9, s20, v9                                   ; 68121214
	v_lshlrev_b32_e32 v10, 1, v9                                ; 24141281
	v_lshl_add_u32 v9, v9, 5, v10                               ; d1fd0009 04290b09
	v_add_u32_e32 v11, 2, v9                                    ; 68161282
	v_add_u32_e32 v20, v11, v8                                  ; 6828110b
	v_and_b32_e32 v11, -4, v11                                  ; 261616c4
	v_add_u32_e32 v11, v11, v8                                  ; 6816110b
	buffer_load_dwordx3 v[21:23], v11, s[24:27], 0 offen        ; e0581000 8006150b
	buffer_load_short_d16 v24, v9, s[24:27], 0 offen            ; e0901000 80061809
	s_add_u32 s21, s21, s3                                      ; 80150315
	s_cmp_lt_u32 3, s4                                          ; bf0a0483
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_alignbyte_b32 v21, v22, v21, v20                          ; d1cf0015 04522b16
	v_alignbyte_b32 v23, v23, v22, v20                          ; d1cf0017 04522d17
	v_cvt_f32_i32_sdwa v26, sext(v21) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e340af9 000a0615
	v_cvt_f32_i32_sdwa v27, sext(v21) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e360af9 00090615
	v_cvt_f32_i32_sdwa v25, sext(v21) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e320af9 000b0615
	v_cvt_f32_i32_sdwa v21, sext(v21) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e2a0af9 00080615
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_cvt_f32_f16_e32 v31, v24                                  ; 7e3e1718
	v_cvt_f32_i32_sdwa v28, sext(v23) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e380af9 000b0617
	v_cvt_f32_i32_sdwa v29, sext(v23) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e3a0af9 000a0617
	v_cvt_f32_i32_sdwa v30, sext(v23) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e3c0af9 00090617
	v_cvt_f32_i32_sdwa v23, sext(v23) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e2e0af9 00080617
	v_mul_f32_e32 v28, v19, v28                                 ; 0a383913
	v_mac_f32_e32 v28, v18, v29                                 ; 2c383b12
	v_mac_f32_e32 v28, v17, v30                                 ; 2c383d11
	v_mac_f32_e32 v28, v16, v23                                 ; 2c382f10
	v_mac_f32_e32 v28, v14, v26                                 ; 2c38350e
	v_mac_f32_e32 v28, v15, v25                                 ; 2c38330f
	v_mac_f32_e32 v28, v13, v27                                 ; 2c38370d
	v_mac_f32_e32 v28, v12, v21                                 ; 2c382b0c
	v_mac_f32_e32 v5, v28, v31                                  ; 2c0a3f1c
	s_cbranch_scc0 BB89                                         ; bf840030
BB81:
	v_add_u32_e32 v7, s21, v7                                   ; 680e0e15
	v_lshrrev_b32_e32 v7, 5, v7                                 ; 200e0e85
	v_add_u32_e32 v7, s20, v7                                   ; 680e0e14
	v_lshlrev_b32_e32 v9, 1, v7                                 ; 24120e81
	v_lshl_add_u32 v7, v7, 5, v9                                ; d1fd0007 04250b07
	v_add_u32_e32 v10, 2, v7                                    ; 68140e82
	v_add_u32_e32 v11, v10, v8                                  ; 6816110a
	v_and_b32_e32 v10, -4, v10                                  ; 261414c4
	v_add_u32_e32 v10, v10, v8                                  ; 6814110a
	buffer_load_dwordx3 v[20:22], v10, s[24:27], 0 offen        ; e0581000 8006140a
	buffer_load_short_d16 v23, v7, s[24:27], 0 offen            ; e0901000 80061707
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_alignbyte_b32 v20, v21, v20, v11                          ; d1cf0014 042e2915
	v_alignbyte_b32 v22, v22, v21, v11                          ; d1cf0016 042e2b16
	v_cvt_f32_i32_sdwa v24, sext(v20) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e300af9 000b0614
	v_cvt_f32_i32_sdwa v25, sext(v20) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e320af9 000a0614
	v_cvt_f32_i32_sdwa v26, sext(v20) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e340af9 00090614
	v_cvt_f32_i32_sdwa v20, sext(v20) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e280af9 00080614
	v_cvt_f32_i32_sdwa v27, sext(v22) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e360af9 000b0616
	v_cvt_f32_i32_sdwa v28, sext(v22) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e380af9 000a0616
	v_cvt_f32_i32_sdwa v29, sext(v22) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e3a0af9 00090616
	v_cvt_f32_i32_sdwa v22, sext(v22) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e2c0af9 00080616
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_cvt_f32_f16_e32 v30, v23                                  ; 7e3c1717
	v_mul_f32_e32 v19, v19, v27                                 ; 0a263713
	v_mac_f32_e32 v19, v18, v28                                 ; 2c263912
	v_mac_f32_e32 v19, v17, v29                                 ; 2c263b11
	v_mac_f32_e32 v19, v16, v22                                 ; 2c262d10
	v_mac_f32_e32 v19, v14, v25                                 ; 2c26330e
	v_mac_f32_e32 v19, v15, v24                                 ; 2c26310f
	v_mac_f32_e32 v19, v13, v26                                 ; 2c26350d
	v_mac_f32_e32 v19, v12, v20                                 ; 2c26290c
	v_mac_f32_e32 v6, v19, v30                                  ; 2c0c3d13
	s_branch BB89                                               ; bf820001
BB88:
	s_mov_b32 s18, src_scc                                      ; be9200fd
BB89:
	s_add_u32 s21, 0x400, s1                                    ; 801501ff 00000400
	s_cmp_lg_i32 s18, 0                                         ; bf018012
	v_add_u32_e32 v7, s21, v0                                   ; 680e0015
	v_and_b32_e32 v8, 31, v7                                    ; 26100e9f
	v_sub_u32_e32 v9, v7, v8                                    ; 6a121107
	v_add3_u32 v9, v8, s5, v9                                   ; d1ff0009 04240b08
	s_cbranch_scc0 BB100                                        ; bf8400cc
BB90:
	s_load_dwordx4 s[24:27], s[10:11], 0x0                      ; c00a0605 00000000
	v_lshrrev_b32_e32 v9, 2, v9                                 ; 20121282
	v_lshlrev_b32_e32 v9, 4, v9                                 ; 24121284
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_load_dwordx4 v[12:15], v9, s[12:15], 0 offen         ; e05c1000 80030c09
	buffer_load_dwordx4 v[16:19], v9, s[12:15], 0 offen offset:16 ; e05c1010 80031009
	v_add_u32_e32 v9, s9, v7                                    ; 68120e09
	v_lshrrev_b32_e32 v9, 5, v9                                 ; 20121285
	v_add_u32_e32 v9, s20, v9                                   ; 68121214
	v_lshlrev_b32_e32 v10, 1, v9                                ; 24141281
	v_lshl_add_u32 v9, v9, 5, v10                               ; d1fd0009 04290b09
	v_add_u32_e32 v11, 2, v9                                    ; 68161282
	v_add_u32_e32 v20, v11, v8                                  ; 6828110b
	v_and_b32_e32 v11, -4, v11                                  ; 261616c4
	v_add_u32_e32 v11, v11, v8                                  ; 6816110b
	buffer_load_dwordx3 v[21:23], v11, s[24:27], 0 offen        ; e0581000 8006150b
	buffer_load_short_d16 v24, v9, s[24:27], 0 offen            ; e0901000 80061809
	s_mov_b32 s18, src_scc                                      ; be9200fd
	s_add_u32 s21, s9, s3                                       ; 80150309
	s_cmp_lt_u32 1, s4                                          ; bf0a0481
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_alignbyte_b32 v21, v22, v21, v20                          ; d1cf0015 04522b16
	v_alignbyte_b32 v23, v23, v22, v20                          ; d1cf0017 04522d17
	v_cvt_f32_i32_sdwa v25, sext(v21) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e320af9 000b0615
	v_cvt_f32_i32_sdwa v26, sext(v21) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e340af9 000a0615
	v_cvt_f32_i32_sdwa v27, sext(v21) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e360af9 00090615
	v_cvt_f32_i32_sdwa v21, sext(v21) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e2a0af9 00080615
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_cvt_f32_f16_e32 v31, v24                                  ; 7e3e1718
	v_cvt_f32_i32_sdwa v28, sext(v23) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e380af9 000b0617
	v_cvt_f32_i32_sdwa v29, sext(v23) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e3a0af9 000a0617
	v_cvt_f32_i32_sdwa v30, sext(v23) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e3c0af9 00090617
	v_cvt_f32_i32_sdwa v23, sext(v23) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e2e0af9 00080617
	v_mul_f32_e32 v28, v19, v28                                 ; 0a383913
	v_mac_f32_e32 v28, v18, v29                                 ; 2c383b12
	v_mac_f32_e32 v28, v17, v30                                 ; 2c383d11
	v_mac_f32_e32 v28, v16, v23                                 ; 2c382f10
	v_mac_f32_e32 v28, v14, v26                                 ; 2c38350e
	v_mac_f32_e32 v28, v15, v25                                 ; 2c38330f
	v_mac_f32_e32 v28, v13, v27                                 ; 2c38370d
	v_mac_f32_e32 v28, v12, v21                                 ; 2c382b0c
	v_mac_f32_e32 v1, v28, v31                                  ; 2c023f1c
	s_cbranch_scc0 BB101                                        ; bf840092
BB91:
	v_add_u32_e32 v9, s21, v7                                   ; 68120e15
	v_lshrrev_b32_e32 v9, 5, v9                                 ; 20121285
	v_add_u32_e32 v9, s20, v9                                   ; 68121214
	v_lshlrev_b32_e32 v10, 1, v9                                ; 24141281
	v_lshl_add_u32 v9, v9, 5, v10                               ; d1fd0009 04290b09
	v_add_u32_e32 v11, 2, v9                                    ; 68161282
	v_add_u32_e32 v20, v11, v8                                  ; 6828110b
	v_and_b32_e32 v11, -4, v11                                  ; 261616c4
	v_add_u32_e32 v11, v11, v8                                  ; 6816110b
	buffer_load_dwordx3 v[21:23], v11, s[24:27], 0 offen        ; e0581000 8006150b
	buffer_load_short_d16 v24, v9, s[24:27], 0 offen            ; e0901000 80061809
	s_add_u32 s21, s21, s3                                      ; 80150315
	s_cmp_lt_u32 2, s4                                          ; bf0a0482
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_alignbyte_b32 v21, v22, v21, v20                          ; d1cf0015 04522b16
	v_alignbyte_b32 v23, v23, v22, v20                          ; d1cf0017 04522d17
	v_cvt_f32_i32_sdwa v26, sext(v21) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e340af9 000a0615
	v_cvt_f32_i32_sdwa v27, sext(v21) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e360af9 00090615
	v_cvt_f32_i32_sdwa v25, sext(v21) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e320af9 000b0615
	v_cvt_f32_i32_sdwa v21, sext(v21) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e2a0af9 00080615
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_cvt_f32_f16_e32 v31, v24                                  ; 7e3e1718
	v_cvt_f32_i32_sdwa v28, sext(v23) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e380af9 000b0617
	v_cvt_f32_i32_sdwa v29, sext(v23) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e3a0af9 000a0617
	v_cvt_f32_i32_sdwa v30, sext(v23) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e3c0af9 00090617
	v_cvt_f32_i32_sdwa v23, sext(v23) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e2e0af9 00080617
	v_mul_f32_e32 v28, v19, v28                                 ; 0a383913
	v_mac_f32_e32 v28, v18, v29                                 ; 2c383b12
	v_mac_f32_e32 v28, v17, v30                                 ; 2c383d11
	v_mac_f32_e32 v28, v16, v23                                 ; 2c382f10
	v_mac_f32_e32 v28, v14, v26                                 ; 2c38350e
	v_mac_f32_e32 v28, v15, v25                                 ; 2c38330f
	v_mac_f32_e32 v28, v13, v27                                 ; 2c38370d
	v_mac_f32_e32 v28, v12, v21                                 ; 2c382b0c
	v_mac_f32_e32 v4, v28, v31                                  ; 2c083f1c
	s_cbranch_scc0 BB101                                        ; bf840061
BB92:
	v_add_u32_e32 v9, s21, v7                                   ; 68120e15
	v_lshrrev_b32_e32 v9, 5, v9                                 ; 20121285
	v_add_u32_e32 v9, s20, v9                                   ; 68121214
	v_lshlrev_b32_e32 v10, 1, v9                                ; 24141281
	v_lshl_add_u32 v9, v9, 5, v10                               ; d1fd0009 04290b09
	v_add_u32_e32 v11, 2, v9                                    ; 68161282
	v_add_u32_e32 v20, v11, v8                                  ; 6828110b
	v_and_b32_e32 v11, -4, v11                                  ; 261616c4
	v_add_u32_e32 v11, v11, v8                                  ; 6816110b
	buffer_load_dwordx3 v[21:23], v11, s[24:27], 0 offen        ; e0581000 8006150b
	buffer_load_short_d16 v24, v9, s[24:27], 0 offen            ; e0901000 80061809
	s_add_u32 s21, s21, s3                                      ; 80150315
	s_cmp_lt_u32 3, s4                                          ; bf0a0483
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_alignbyte_b32 v21, v22, v21, v20                          ; d1cf0015 04522b16
	v_alignbyte_b32 v23, v23, v22, v20                          ; d1cf0017 04522d17
	v_cvt_f32_i32_sdwa v26, sext(v21) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e340af9 000a0615
	v_cvt_f32_i32_sdwa v27, sext(v21) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e360af9 00090615
	v_cvt_f32_i32_sdwa v25, sext(v21) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e320af9 000b0615
	v_cvt_f32_i32_sdwa v21, sext(v21) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e2a0af9 00080615
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_cvt_f32_f16_e32 v31, v24                                  ; 7e3e1718
	v_cvt_f32_i32_sdwa v28, sext(v23) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e380af9 000b0617
	v_cvt_f32_i32_sdwa v29, sext(v23) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e3a0af9 000a0617
	v_cvt_f32_i32_sdwa v30, sext(v23) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e3c0af9 00090617
	v_cvt_f32_i32_sdwa v23, sext(v23) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e2e0af9 00080617
	v_mul_f32_e32 v28, v19, v28                                 ; 0a383913
	v_mac_f32_e32 v28, v18, v29                                 ; 2c383b12
	v_mac_f32_e32 v28, v17, v30                                 ; 2c383d11
	v_mac_f32_e32 v28, v16, v23                                 ; 2c382f10
	v_mac_f32_e32 v28, v14, v26                                 ; 2c38350e
	v_mac_f32_e32 v28, v15, v25                                 ; 2c38330f
	v_mac_f32_e32 v28, v13, v27                                 ; 2c38370d
	v_mac_f32_e32 v28, v12, v21                                 ; 2c382b0c
	v_mac_f32_e32 v5, v28, v31                                  ; 2c0a3f1c
	s_cbranch_scc0 BB101                                        ; bf840030
BB93:
	v_add_u32_e32 v7, s21, v7                                   ; 680e0e15
	v_lshrrev_b32_e32 v7, 5, v7                                 ; 200e0e85
	v_add_u32_e32 v7, s20, v7                                   ; 680e0e14
	v_lshlrev_b32_e32 v9, 1, v7                                 ; 24120e81
	v_lshl_add_u32 v7, v7, 5, v9                                ; d1fd0007 04250b07
	v_add_u32_e32 v10, 2, v7                                    ; 68140e82
	v_add_u32_e32 v11, v10, v8                                  ; 6816110a
	v_and_b32_e32 v10, -4, v10                                  ; 261414c4
	v_add_u32_e32 v10, v10, v8                                  ; 6814110a
	buffer_load_dwordx3 v[20:22], v10, s[24:27], 0 offen        ; e0581000 8006140a
	buffer_load_short_d16 v23, v7, s[24:27], 0 offen            ; e0901000 80061707
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_alignbyte_b32 v20, v21, v20, v11                          ; d1cf0014 042e2915
	v_alignbyte_b32 v22, v22, v21, v11                          ; d1cf0016 042e2b16
	v_cvt_f32_i32_sdwa v24, sext(v20) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e300af9 000b0614
	v_cvt_f32_i32_sdwa v25, sext(v20) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e320af9 000a0614
	v_cvt_f32_i32_sdwa v26, sext(v20) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e340af9 00090614
	v_cvt_f32_i32_sdwa v20, sext(v20) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e280af9 00080614
	v_cvt_f32_i32_sdwa v27, sext(v22) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e360af9 000b0616
	v_cvt_f32_i32_sdwa v28, sext(v22) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e380af9 000a0616
	v_cvt_f32_i32_sdwa v29, sext(v22) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e3a0af9 00090616
	v_cvt_f32_i32_sdwa v22, sext(v22) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e2c0af9 00080616
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_cvt_f32_f16_e32 v30, v23                                  ; 7e3c1717
	v_mul_f32_e32 v19, v19, v27                                 ; 0a263713
	v_mac_f32_e32 v19, v18, v28                                 ; 2c263912
	v_mac_f32_e32 v19, v17, v29                                 ; 2c263b11
	v_mac_f32_e32 v19, v16, v22                                 ; 2c262d10
	v_mac_f32_e32 v19, v14, v25                                 ; 2c26330e
	v_mac_f32_e32 v19, v15, v24                                 ; 2c26310f
	v_mac_f32_e32 v19, v13, v26                                 ; 2c26350d
	v_mac_f32_e32 v19, v12, v20                                 ; 2c26290c
	v_mac_f32_e32 v6, v19, v30                                  ; 2c0c3d13
	s_branch BB101                                              ; bf820001
BB100:
	s_mov_b32 s18, src_scc                                      ; be9200fd
BB101:
	s_addk_i32 s1, 0x600                                        ; b7010600
	s_cmp_lg_i32 s18, 0                                         ; bf018012
	v_add_u32_e32 v7, s1, v0                                    ; 680e0001
	v_and_b32_e32 v8, 31, v7                                    ; 26100e9f
	v_sub_u32_e32 v9, v7, v8                                    ; 6a121107
	v_add3_u32 v9, v8, s5, v9                                   ; d1ff0009 04240b08
	s_cbranch_scc0 BB113                                        ; bf8400ca
BB102:
	s_load_dwordx4 s[24:27], s[10:11], 0x0                      ; c00a0605 00000000
	v_lshrrev_b32_e32 v9, 2, v9                                 ; 20121282
	v_lshlrev_b32_e32 v9, 4, v9                                 ; 24121284
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_load_dwordx4 v[12:15], v9, s[12:15], 0 offen         ; e05c1000 80030c09
	buffer_load_dwordx4 v[16:19], v9, s[12:15], 0 offen offset:16 ; e05c1010 80031009
	v_add_u32_e32 v9, s9, v7                                    ; 68120e09
	v_lshrrev_b32_e32 v9, 5, v9                                 ; 20121285
	v_add_u32_e32 v9, s20, v9                                   ; 68121214
	v_lshlrev_b32_e32 v10, 1, v9                                ; 24141281
	v_lshl_add_u32 v9, v9, 5, v10                               ; d1fd0009 04290b09
	v_add_u32_e32 v11, 2, v9                                    ; 68161282
	v_add_u32_e32 v20, v11, v8                                  ; 6828110b
	v_and_b32_e32 v11, -4, v11                                  ; 261616c4
	v_add_u32_e32 v11, v11, v8                                  ; 6816110b
	buffer_load_dwordx3 v[21:23], v11, s[24:27], 0 offen        ; e0581000 8006150b
	buffer_load_short_d16 v24, v9, s[24:27], 0 offen            ; e0901000 80061809
	s_add_u32 s9, s9, s3                                        ; 80090309
	s_cmp_lt_u32 1, s4                                          ; bf0a0481
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_alignbyte_b32 v21, v22, v21, v20                          ; d1cf0015 04522b16
	v_alignbyte_b32 v23, v23, v22, v20                          ; d1cf0017 04522d17
	v_cvt_f32_i32_sdwa v25, sext(v21) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e320af9 000b0615
	v_cvt_f32_i32_sdwa v26, sext(v21) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e340af9 000a0615
	v_cvt_f32_i32_sdwa v27, sext(v21) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e360af9 00090615
	v_cvt_f32_i32_sdwa v21, sext(v21) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e2a0af9 00080615
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_cvt_f32_f16_e32 v31, v24                                  ; 7e3e1718
	v_cvt_f32_i32_sdwa v28, sext(v23) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e380af9 000b0617
	v_cvt_f32_i32_sdwa v29, sext(v23) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e3a0af9 000a0617
	v_cvt_f32_i32_sdwa v30, sext(v23) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e3c0af9 00090617
	v_cvt_f32_i32_sdwa v23, sext(v23) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e2e0af9 00080617
	v_mul_f32_e32 v28, v19, v28                                 ; 0a383913
	v_mac_f32_e32 v28, v18, v29                                 ; 2c383b12
	v_mac_f32_e32 v28, v17, v30                                 ; 2c383d11
	v_mac_f32_e32 v28, v16, v23                                 ; 2c382f10
	v_mac_f32_e32 v28, v14, v26                                 ; 2c38350e
	v_mac_f32_e32 v28, v15, v25                                 ; 2c38330f
	v_mac_f32_e32 v28, v13, v27                                 ; 2c38370d
	v_mac_f32_e32 v28, v12, v21                                 ; 2c382b0c
	v_mac_f32_e32 v1, v28, v31                                  ; 2c023f1c
	s_cbranch_scc0 BB113                                        ; bf840090
BB103:
	v_add_u32_e32 v9, s9, v7                                    ; 68120e09
	v_lshrrev_b32_e32 v9, 5, v9                                 ; 20121285
	v_add_u32_e32 v9, s20, v9                                   ; 68121214
	v_lshlrev_b32_e32 v10, 1, v9                                ; 24141281
	v_lshl_add_u32 v9, v9, 5, v10                               ; d1fd0009 04290b09
	v_add_u32_e32 v11, 2, v9                                    ; 68161282
	v_add_u32_e32 v20, v11, v8                                  ; 6828110b
	v_and_b32_e32 v11, -4, v11                                  ; 261616c4
	v_add_u32_e32 v11, v11, v8                                  ; 6816110b
	buffer_load_dwordx3 v[21:23], v11, s[24:27], 0 offen        ; e0581000 8006150b
	buffer_load_short_d16 v24, v9, s[24:27], 0 offen            ; e0901000 80061809
	s_add_u32 s9, s9, s3                                        ; 80090309
	s_cmp_lt_u32 2, s4                                          ; bf0a0482
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_alignbyte_b32 v21, v22, v21, v20                          ; d1cf0015 04522b16
	v_alignbyte_b32 v23, v23, v22, v20                          ; d1cf0017 04522d17
	v_cvt_f32_i32_sdwa v26, sext(v21) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e340af9 000a0615
	v_cvt_f32_i32_sdwa v27, sext(v21) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e360af9 00090615
	v_cvt_f32_i32_sdwa v25, sext(v21) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e320af9 000b0615
	v_cvt_f32_i32_sdwa v21, sext(v21) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e2a0af9 00080615
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_cvt_f32_f16_e32 v31, v24                                  ; 7e3e1718
	v_cvt_f32_i32_sdwa v28, sext(v23) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e380af9 000b0617
	v_cvt_f32_i32_sdwa v29, sext(v23) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e3a0af9 000a0617
	v_cvt_f32_i32_sdwa v30, sext(v23) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e3c0af9 00090617
	v_cvt_f32_i32_sdwa v23, sext(v23) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e2e0af9 00080617
	v_mul_f32_e32 v28, v19, v28                                 ; 0a383913
	v_mac_f32_e32 v28, v18, v29                                 ; 2c383b12
	v_mac_f32_e32 v28, v17, v30                                 ; 2c383d11
	v_mac_f32_e32 v28, v16, v23                                 ; 2c382f10
	v_mac_f32_e32 v28, v14, v26                                 ; 2c38350e
	v_mac_f32_e32 v28, v15, v25                                 ; 2c38330f
	v_mac_f32_e32 v28, v13, v27                                 ; 2c38370d
	v_mac_f32_e32 v28, v12, v21                                 ; 2c382b0c
	v_mac_f32_e32 v4, v28, v31                                  ; 2c083f1c
	s_cbranch_scc0 BB113                                        ; bf84005f
BB104:
	v_add_u32_e32 v9, s9, v7                                    ; 68120e09
	v_lshrrev_b32_e32 v9, 5, v9                                 ; 20121285
	v_add_u32_e32 v9, s20, v9                                   ; 68121214
	v_lshlrev_b32_e32 v10, 1, v9                                ; 24141281
	v_lshl_add_u32 v9, v9, 5, v10                               ; d1fd0009 04290b09
	v_add_u32_e32 v11, 2, v9                                    ; 68161282
	v_add_u32_e32 v20, v11, v8                                  ; 6828110b
	v_and_b32_e32 v11, -4, v11                                  ; 261616c4
	v_add_u32_e32 v11, v11, v8                                  ; 6816110b
	buffer_load_dwordx3 v[21:23], v11, s[24:27], 0 offen        ; e0581000 8006150b
	buffer_load_short_d16 v24, v9, s[24:27], 0 offen            ; e0901000 80061809
	s_add_u32 s9, s9, s3                                        ; 80090309
	s_cmp_lt_u32 3, s4                                          ; bf0a0483
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_alignbyte_b32 v21, v22, v21, v20                          ; d1cf0015 04522b16
	v_alignbyte_b32 v23, v23, v22, v20                          ; d1cf0017 04522d17
	v_cvt_f32_i32_sdwa v26, sext(v21) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e340af9 000a0615
	v_cvt_f32_i32_sdwa v27, sext(v21) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e360af9 00090615
	v_cvt_f32_i32_sdwa v25, sext(v21) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e320af9 000b0615
	v_cvt_f32_i32_sdwa v21, sext(v21) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e2a0af9 00080615
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_cvt_f32_f16_e32 v31, v24                                  ; 7e3e1718
	v_cvt_f32_i32_sdwa v28, sext(v23) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e380af9 000b0617
	v_cvt_f32_i32_sdwa v29, sext(v23) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e3a0af9 000a0617
	v_cvt_f32_i32_sdwa v30, sext(v23) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e3c0af9 00090617
	v_cvt_f32_i32_sdwa v23, sext(v23) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e2e0af9 00080617
	v_mul_f32_e32 v28, v19, v28                                 ; 0a383913
	v_mac_f32_e32 v28, v18, v29                                 ; 2c383b12
	v_mac_f32_e32 v28, v17, v30                                 ; 2c383d11
	v_mac_f32_e32 v28, v16, v23                                 ; 2c382f10
	v_mac_f32_e32 v28, v14, v26                                 ; 2c38350e
	v_mac_f32_e32 v28, v15, v25                                 ; 2c38330f
	v_mac_f32_e32 v28, v13, v27                                 ; 2c38370d
	v_mac_f32_e32 v28, v12, v21                                 ; 2c382b0c
	v_mac_f32_e32 v5, v28, v31                                  ; 2c0a3f1c
	s_cbranch_scc0 BB113                                        ; bf84002e
BB105:
	v_add_u32_e32 v7, s9, v7                                    ; 680e0e09
	v_lshrrev_b32_e32 v7, 5, v7                                 ; 200e0e85
	v_add_u32_e32 v7, s20, v7                                   ; 680e0e14
	v_lshlrev_b32_e32 v9, 1, v7                                 ; 24120e81
	v_lshl_add_u32 v7, v7, 5, v9                                ; d1fd0007 04250b07
	v_add_u32_e32 v10, 2, v7                                    ; 68140e82
	v_add_u32_e32 v11, v10, v8                                  ; 6816110a
	v_and_b32_e32 v10, -4, v10                                  ; 261414c4
	v_add_u32_e32 v10, v10, v8                                  ; 6814110a
	buffer_load_dwordx3 v[20:22], v10, s[24:27], 0 offen        ; e0581000 8006140a
	buffer_load_short_d16 v23, v7, s[24:27], 0 offen            ; e0901000 80061707
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_alignbyte_b32 v20, v21, v20, v11                          ; d1cf0014 042e2915
	v_alignbyte_b32 v22, v22, v21, v11                          ; d1cf0016 042e2b16
	v_cvt_f32_i32_sdwa v24, sext(v20) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e300af9 000b0614
	v_cvt_f32_i32_sdwa v25, sext(v20) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e320af9 000a0614
	v_cvt_f32_i32_sdwa v26, sext(v20) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e340af9 00090614
	v_cvt_f32_i32_sdwa v20, sext(v20) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e280af9 00080614
	v_cvt_f32_i32_sdwa v27, sext(v22) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e360af9 000b0616
	v_cvt_f32_i32_sdwa v28, sext(v22) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e380af9 000a0616
	v_cvt_f32_i32_sdwa v29, sext(v22) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e3a0af9 00090616
	v_cvt_f32_i32_sdwa v22, sext(v22) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e2c0af9 00080616
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_cvt_f32_f16_e32 v30, v23                                  ; 7e3c1717
	v_mul_f32_e32 v19, v19, v27                                 ; 0a263713
	v_mac_f32_e32 v19, v18, v28                                 ; 2c263912
	v_mac_f32_e32 v19, v17, v29                                 ; 2c263b11
	v_mac_f32_e32 v19, v16, v22                                 ; 2c262d10
	v_mac_f32_e32 v19, v14, v25                                 ; 2c26330e
	v_mac_f32_e32 v19, v15, v24                                 ; 2c26310f
	v_mac_f32_e32 v19, v13, v26                                 ; 2c26350d
	v_mac_f32_e32 v19, v12, v20                                 ; 2c26290c
	v_mac_f32_e32 v6, v19, v30                                  ; 2c0c3d13
BB113:
	s_add_u32 s0, 4, s0                                         ; 80000084
	s_branch BB60                                               ; bf82fc9e
BB114:
	s_mov_b64 exec, -1                                          ; befe01c1
	v_and_b32_e32 v7, -2, v2                                    ; 260e04c2
BB115:
	s_mov_b64 s[0:1], exec                                      ; be80017e
	v_cmpx_ge_u32_e32 vcc, v3, v7                               ; 7dbc0f03
BB116:
	s_andn2_b64 s[0:1], s[0:1], exec                            ; 89807e00
	s_cbranch_scc0 BB145                                        ; bf8401b3
BB120:
	s_mov_b64 exec, s[0:1]                                      ; befe0100
	s_mov_b32 s0, s2                                            ; be800002
	s_movk_i32 s1, 0x8000                                       ; b0018000
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_load_dwordx4 s[12:15], s[0:1], 0x10                       ; c00a0300 00000010
	s_mul_i32 s5, s6, s17                                       ; 92051106
	s_mul_i32 s9, s16, s3                                       ; 92090310
	s_cmp_lg_i32 s4, 0                                          ; bf018004
	v_lshl_add_u32 v8, v3, 9, v0                                ; d1fd0008 04011303
	v_and_b32_e32 v9, 31, v8                                    ; 2612109f
	v_sub_u32_e32 v10, v8, v9                                   ; 6a141308
	v_add3_u32 v10, v9, s5, v10                                 ; d1ff000a 04280b09
	s_cbranch_scc0 BB131                                        ; bf8400cc
BB121:
	s_load_dwordx4 s[24:27], s[0:1], 0x0                        ; c00a0600 00000000
	v_lshrrev_b32_e32 v10, 2, v10                               ; 20141482
	v_lshlrev_b32_e32 v10, 4, v10                               ; 24141484
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_load_dwordx4 v[12:15], v10, s[12:15], 0 offen        ; e05c1000 80030c0a
	buffer_load_dwordx4 v[16:19], v10, s[12:15], 0 offen offset:16 ; e05c1010 8003100a
	v_add_u32_e32 v10, s9, v8                                   ; 68141009
	v_lshrrev_b32_e32 v10, 5, v10                               ; 20141485
	v_add_u32_e32 v10, s20, v10                                 ; 68141414
	v_lshlrev_b32_e32 v11, 1, v10                               ; 24161481
	v_lshl_add_u32 v10, v10, 5, v11                             ; d1fd000a 042d0b0a
	v_add_u32_e32 v20, 2, v10                                   ; 68281482
	v_add_u32_e32 v21, v20, v9                                  ; 682a1314
	v_and_b32_e32 v20, -4, v20                                  ; 262828c4
	v_add_u32_e32 v20, v20, v9                                  ; 68281314
	buffer_load_dwordx3 v[22:24], v20, s[24:27], 0 offen        ; e0581000 80061614
	buffer_load_short_d16 v25, v10, s[24:27], 0 offen           ; e0901000 8006190a
	s_mov_b32 s10, src_scc                                      ; be8a00fd
	s_add_u32 s11, s9, s3                                       ; 800b0309
	s_cmp_lt_u32 1, s4                                          ; bf0a0481
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_alignbyte_b32 v22, v23, v22, v21                          ; d1cf0016 04562d17
	v_alignbyte_b32 v24, v24, v23, v21                          ; d1cf0018 04562f18
	v_cvt_f32_i32_sdwa v26, sext(v22) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e340af9 000b0616
	v_cvt_f32_i32_sdwa v27, sext(v22) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e360af9 000a0616
	v_cvt_f32_i32_sdwa v28, sext(v22) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e380af9 00090616
	v_cvt_f32_i32_sdwa v22, sext(v22) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e2c0af9 00080616
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_cvt_f32_f16_e32 v32, v25                                  ; 7e401719
	v_cvt_f32_i32_sdwa v29, sext(v24) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e3a0af9 000b0618
	v_cvt_f32_i32_sdwa v30, sext(v24) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e3c0af9 000a0618
	v_cvt_f32_i32_sdwa v31, sext(v24) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e3e0af9 00090618
	v_cvt_f32_i32_sdwa v24, sext(v24) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e300af9 00080618
	v_mul_f32_e32 v29, v19, v29                                 ; 0a3a3b13
	v_mac_f32_e32 v29, v18, v30                                 ; 2c3a3d12
	v_mac_f32_e32 v29, v17, v31                                 ; 2c3a3f11
	v_mac_f32_e32 v29, v16, v24                                 ; 2c3a3110
	v_mac_f32_e32 v29, v14, v27                                 ; 2c3a370e
	v_mac_f32_e32 v29, v15, v26                                 ; 2c3a350f
	v_mac_f32_e32 v29, v13, v28                                 ; 2c3a390d
	v_mac_f32_e32 v29, v12, v22                                 ; 2c3a2d0c
	v_mac_f32_e32 v1, v29, v32                                  ; 2c02411d
	s_cbranch_scc0 BB132                                        ; bf840092
BB122:
	v_add_u32_e32 v10, s11, v8                                  ; 6814100b
	v_lshrrev_b32_e32 v10, 5, v10                               ; 20141485
	v_add_u32_e32 v10, s20, v10                                 ; 68141414
	v_lshlrev_b32_e32 v11, 1, v10                               ; 24161481
	v_lshl_add_u32 v10, v10, 5, v11                             ; d1fd000a 042d0b0a
	v_add_u32_e32 v20, 2, v10                                   ; 68281482
	v_add_u32_e32 v21, v20, v9                                  ; 682a1314
	v_and_b32_e32 v20, -4, v20                                  ; 262828c4
	v_add_u32_e32 v20, v20, v9                                  ; 68281314
	buffer_load_dwordx3 v[22:24], v20, s[24:27], 0 offen        ; e0581000 80061614
	buffer_load_short_d16 v25, v10, s[24:27], 0 offen           ; e0901000 8006190a
	s_add_u32 s11, s11, s3                                      ; 800b030b
	s_cmp_lt_u32 2, s4                                          ; bf0a0482
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_alignbyte_b32 v22, v23, v22, v21                          ; d1cf0016 04562d17
	v_alignbyte_b32 v24, v24, v23, v21                          ; d1cf0018 04562f18
	v_cvt_f32_i32_sdwa v27, sext(v22) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e360af9 000a0616
	v_cvt_f32_i32_sdwa v28, sext(v22) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e380af9 00090616
	v_cvt_f32_i32_sdwa v26, sext(v22) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e340af9 000b0616
	v_cvt_f32_i32_sdwa v22, sext(v22) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e2c0af9 00080616
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_cvt_f32_f16_e32 v32, v25                                  ; 7e401719
	v_cvt_f32_i32_sdwa v29, sext(v24) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e3a0af9 000b0618
	v_cvt_f32_i32_sdwa v30, sext(v24) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e3c0af9 000a0618
	v_cvt_f32_i32_sdwa v31, sext(v24) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e3e0af9 00090618
	v_cvt_f32_i32_sdwa v24, sext(v24) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e300af9 00080618
	v_mul_f32_e32 v29, v19, v29                                 ; 0a3a3b13
	v_mac_f32_e32 v29, v18, v30                                 ; 2c3a3d12
	v_mac_f32_e32 v29, v17, v31                                 ; 2c3a3f11
	v_mac_f32_e32 v29, v16, v24                                 ; 2c3a3110
	v_mac_f32_e32 v29, v14, v27                                 ; 2c3a370e
	v_mac_f32_e32 v29, v15, v26                                 ; 2c3a350f
	v_mac_f32_e32 v29, v13, v28                                 ; 2c3a390d
	v_mac_f32_e32 v29, v12, v22                                 ; 2c3a2d0c
	v_mac_f32_e32 v4, v29, v32                                  ; 2c08411d
	s_cbranch_scc0 BB132                                        ; bf840061
BB123:
	v_add_u32_e32 v10, s11, v8                                  ; 6814100b
	v_lshrrev_b32_e32 v10, 5, v10                               ; 20141485
	v_add_u32_e32 v10, s20, v10                                 ; 68141414
	v_lshlrev_b32_e32 v11, 1, v10                               ; 24161481
	v_lshl_add_u32 v10, v10, 5, v11                             ; d1fd000a 042d0b0a
	v_add_u32_e32 v20, 2, v10                                   ; 68281482
	v_add_u32_e32 v21, v20, v9                                  ; 682a1314
	v_and_b32_e32 v20, -4, v20                                  ; 262828c4
	v_add_u32_e32 v20, v20, v9                                  ; 68281314
	buffer_load_dwordx3 v[22:24], v20, s[24:27], 0 offen        ; e0581000 80061614
	buffer_load_short_d16 v25, v10, s[24:27], 0 offen           ; e0901000 8006190a
	s_add_u32 s11, s11, s3                                      ; 800b030b
	s_cmp_lt_u32 3, s4                                          ; bf0a0483
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_alignbyte_b32 v22, v23, v22, v21                          ; d1cf0016 04562d17
	v_alignbyte_b32 v24, v24, v23, v21                          ; d1cf0018 04562f18
	v_cvt_f32_i32_sdwa v27, sext(v22) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e360af9 000a0616
	v_cvt_f32_i32_sdwa v28, sext(v22) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e380af9 00090616
	v_cvt_f32_i32_sdwa v26, sext(v22) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e340af9 000b0616
	v_cvt_f32_i32_sdwa v22, sext(v22) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e2c0af9 00080616
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_cvt_f32_f16_e32 v32, v25                                  ; 7e401719
	v_cvt_f32_i32_sdwa v29, sext(v24) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e3a0af9 000b0618
	v_cvt_f32_i32_sdwa v30, sext(v24) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e3c0af9 000a0618
	v_cvt_f32_i32_sdwa v31, sext(v24) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e3e0af9 00090618
	v_cvt_f32_i32_sdwa v24, sext(v24) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e300af9 00080618
	v_mul_f32_e32 v29, v19, v29                                 ; 0a3a3b13
	v_mac_f32_e32 v29, v18, v30                                 ; 2c3a3d12
	v_mac_f32_e32 v29, v17, v31                                 ; 2c3a3f11
	v_mac_f32_e32 v29, v16, v24                                 ; 2c3a3110
	v_mac_f32_e32 v29, v14, v27                                 ; 2c3a370e
	v_mac_f32_e32 v29, v15, v26                                 ; 2c3a350f
	v_mac_f32_e32 v29, v13, v28                                 ; 2c3a390d
	v_mac_f32_e32 v29, v12, v22                                 ; 2c3a2d0c
	v_mac_f32_e32 v5, v29, v32                                  ; 2c0a411d
	s_cbranch_scc0 BB132                                        ; bf840030
BB124:
	v_add_u32_e32 v8, s11, v8                                   ; 6810100b
	v_lshrrev_b32_e32 v8, 5, v8                                 ; 20101085
	v_add_u32_e32 v8, s20, v8                                   ; 68101014
	v_lshlrev_b32_e32 v10, 1, v8                                ; 24141081
	v_lshl_add_u32 v8, v8, 5, v10                               ; d1fd0008 04290b08
	v_add_u32_e32 v11, 2, v8                                    ; 68161082
	v_add_u32_e32 v20, v11, v9                                  ; 6828130b
	v_and_b32_e32 v11, -4, v11                                  ; 261616c4
	v_add_u32_e32 v11, v11, v9                                  ; 6816130b
	buffer_load_dwordx3 v[21:23], v11, s[24:27], 0 offen        ; e0581000 8006150b
	buffer_load_short_d16 v24, v8, s[24:27], 0 offen            ; e0901000 80061808
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_alignbyte_b32 v21, v22, v21, v20                          ; d1cf0015 04522b16
	v_alignbyte_b32 v23, v23, v22, v20                          ; d1cf0017 04522d17
	v_cvt_f32_i32_sdwa v25, sext(v21) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e320af9 000b0615
	v_cvt_f32_i32_sdwa v26, sext(v21) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e340af9 000a0615
	v_cvt_f32_i32_sdwa v27, sext(v21) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e360af9 00090615
	v_cvt_f32_i32_sdwa v21, sext(v21) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e2a0af9 00080615
	v_cvt_f32_i32_sdwa v28, sext(v23) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e380af9 000b0617
	v_cvt_f32_i32_sdwa v29, sext(v23) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e3a0af9 000a0617
	v_cvt_f32_i32_sdwa v30, sext(v23) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e3c0af9 00090617
	v_cvt_f32_i32_sdwa v23, sext(v23) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e2e0af9 00080617
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_cvt_f32_f16_e32 v31, v24                                  ; 7e3e1718
	v_mul_f32_e32 v19, v19, v28                                 ; 0a263913
	v_mac_f32_e32 v19, v18, v29                                 ; 2c263b12
	v_mac_f32_e32 v19, v17, v30                                 ; 2c263d11
	v_mac_f32_e32 v19, v16, v23                                 ; 2c262f10
	v_mac_f32_e32 v19, v14, v26                                 ; 2c26350e
	v_mac_f32_e32 v19, v15, v25                                 ; 2c26330f
	v_mac_f32_e32 v19, v13, v27                                 ; 2c26370d
	v_mac_f32_e32 v19, v12, v21                                 ; 2c262b0c
	v_mac_f32_e32 v6, v19, v31                                  ; 2c0c3f13
	s_branch BB132                                              ; bf820001
BB131:
	s_mov_b32 s10, src_scc                                      ; be8a00fd
BB132:
	s_movk_i32 s11, 0x200                                       ; b00b0200
	s_cmp_lg_i32 s10, 0                                         ; bf01800a
	v_lshl_add_u32 v8, v3, 9, s11                               ; d1fd0008 002d1303
	v_add_u32_e32 v8, v8, v0                                    ; 68100108
	v_and_b32_e32 v9, 31, v8                                    ; 2612109f
	v_sub_u32_e32 v10, v8, v9                                   ; 6a141308
	v_add3_u32 v10, v9, s5, v10                                 ; d1ff000a 04280b09
	s_cbranch_scc0 BB144                                        ; bf8400ca
BB133:
	s_load_dwordx4 s[24:27], s[0:1], 0x0                        ; c00a0600 00000000
	v_lshrrev_b32_e32 v10, 2, v10                               ; 20141482
	v_lshlrev_b32_e32 v10, 4, v10                               ; 24141484
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_load_dwordx4 v[12:15], v10, s[12:15], 0 offen        ; e05c1000 80030c0a
	buffer_load_dwordx4 v[16:19], v10, s[12:15], 0 offen offset:16 ; e05c1010 8003100a
	v_add_u32_e32 v10, s9, v8                                   ; 68141009
	v_lshrrev_b32_e32 v10, 5, v10                               ; 20141485
	v_add_u32_e32 v10, s20, v10                                 ; 68141414
	v_lshlrev_b32_e32 v11, 1, v10                               ; 24161481
	v_lshl_add_u32 v10, v10, 5, v11                             ; d1fd000a 042d0b0a
	v_add_u32_e32 v20, 2, v10                                   ; 68281482
	v_add_u32_e32 v21, v20, v9                                  ; 682a1314
	v_and_b32_e32 v20, -4, v20                                  ; 262828c4
	v_add_u32_e32 v20, v20, v9                                  ; 68281314
	buffer_load_dwordx3 v[22:24], v20, s[24:27], 0 offen        ; e0581000 80061614
	buffer_load_short_d16 v25, v10, s[24:27], 0 offen           ; e0901000 8006190a
	s_add_u32 s9, s9, s3                                        ; 80090309
	s_cmp_lt_u32 1, s4                                          ; bf0a0481
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_alignbyte_b32 v22, v23, v22, v21                          ; d1cf0016 04562d17
	v_alignbyte_b32 v24, v24, v23, v21                          ; d1cf0018 04562f18
	v_cvt_f32_i32_sdwa v26, sext(v22) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e340af9 000b0616
	v_cvt_f32_i32_sdwa v27, sext(v22) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e360af9 000a0616
	v_cvt_f32_i32_sdwa v28, sext(v22) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e380af9 00090616
	v_cvt_f32_i32_sdwa v22, sext(v22) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e2c0af9 00080616
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_cvt_f32_f16_e32 v32, v25                                  ; 7e401719
	v_cvt_f32_i32_sdwa v29, sext(v24) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e3a0af9 000b0618
	v_cvt_f32_i32_sdwa v30, sext(v24) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e3c0af9 000a0618
	v_cvt_f32_i32_sdwa v31, sext(v24) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e3e0af9 00090618
	v_cvt_f32_i32_sdwa v24, sext(v24) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e300af9 00080618
	v_mul_f32_e32 v29, v19, v29                                 ; 0a3a3b13
	v_mac_f32_e32 v29, v18, v30                                 ; 2c3a3d12
	v_mac_f32_e32 v29, v17, v31                                 ; 2c3a3f11
	v_mac_f32_e32 v29, v16, v24                                 ; 2c3a3110
	v_mac_f32_e32 v29, v14, v27                                 ; 2c3a370e
	v_mac_f32_e32 v29, v15, v26                                 ; 2c3a350f
	v_mac_f32_e32 v29, v13, v28                                 ; 2c3a390d
	v_mac_f32_e32 v29, v12, v22                                 ; 2c3a2d0c
	v_mac_f32_e32 v1, v29, v32                                  ; 2c02411d
	s_cbranch_scc0 BB144                                        ; bf840090
BB134:
	v_add_u32_e32 v10, s9, v8                                   ; 68141009
	v_lshrrev_b32_e32 v10, 5, v10                               ; 20141485
	v_add_u32_e32 v10, s20, v10                                 ; 68141414
	v_lshlrev_b32_e32 v11, 1, v10                               ; 24161481
	v_lshl_add_u32 v10, v10, 5, v11                             ; d1fd000a 042d0b0a
	v_add_u32_e32 v20, 2, v10                                   ; 68281482
	v_add_u32_e32 v21, v20, v9                                  ; 682a1314
	v_and_b32_e32 v20, -4, v20                                  ; 262828c4
	v_add_u32_e32 v20, v20, v9                                  ; 68281314
	buffer_load_dwordx3 v[22:24], v20, s[24:27], 0 offen        ; e0581000 80061614
	buffer_load_short_d16 v25, v10, s[24:27], 0 offen           ; e0901000 8006190a
	s_add_u32 s9, s9, s3                                        ; 80090309
	s_cmp_lt_u32 2, s4                                          ; bf0a0482
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_alignbyte_b32 v22, v23, v22, v21                          ; d1cf0016 04562d17
	v_alignbyte_b32 v24, v24, v23, v21                          ; d1cf0018 04562f18
	v_cvt_f32_i32_sdwa v27, sext(v22) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e360af9 000a0616
	v_cvt_f32_i32_sdwa v28, sext(v22) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e380af9 00090616
	v_cvt_f32_i32_sdwa v26, sext(v22) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e340af9 000b0616
	v_cvt_f32_i32_sdwa v22, sext(v22) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e2c0af9 00080616
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_cvt_f32_f16_e32 v32, v25                                  ; 7e401719
	v_cvt_f32_i32_sdwa v29, sext(v24) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e3a0af9 000b0618
	v_cvt_f32_i32_sdwa v30, sext(v24) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e3c0af9 000a0618
	v_cvt_f32_i32_sdwa v31, sext(v24) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e3e0af9 00090618
	v_cvt_f32_i32_sdwa v24, sext(v24) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e300af9 00080618
	v_mul_f32_e32 v29, v19, v29                                 ; 0a3a3b13
	v_mac_f32_e32 v29, v18, v30                                 ; 2c3a3d12
	v_mac_f32_e32 v29, v17, v31                                 ; 2c3a3f11
	v_mac_f32_e32 v29, v16, v24                                 ; 2c3a3110
	v_mac_f32_e32 v29, v14, v27                                 ; 2c3a370e
	v_mac_f32_e32 v29, v15, v26                                 ; 2c3a350f
	v_mac_f32_e32 v29, v13, v28                                 ; 2c3a390d
	v_mac_f32_e32 v29, v12, v22                                 ; 2c3a2d0c
	v_mac_f32_e32 v4, v29, v32                                  ; 2c08411d
	s_cbranch_scc0 BB144                                        ; bf84005f
BB135:
	v_add_u32_e32 v10, s9, v8                                   ; 68141009
	v_lshrrev_b32_e32 v10, 5, v10                               ; 20141485
	v_add_u32_e32 v10, s20, v10                                 ; 68141414
	v_lshlrev_b32_e32 v11, 1, v10                               ; 24161481
	v_lshl_add_u32 v10, v10, 5, v11                             ; d1fd000a 042d0b0a
	v_add_u32_e32 v20, 2, v10                                   ; 68281482
	v_add_u32_e32 v21, v20, v9                                  ; 682a1314
	v_and_b32_e32 v20, -4, v20                                  ; 262828c4
	v_add_u32_e32 v20, v20, v9                                  ; 68281314
	buffer_load_dwordx3 v[22:24], v20, s[24:27], 0 offen        ; e0581000 80061614
	buffer_load_short_d16 v25, v10, s[24:27], 0 offen           ; e0901000 8006190a
	s_add_u32 s9, s9, s3                                        ; 80090309
	s_cmp_lt_u32 3, s4                                          ; bf0a0483
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_alignbyte_b32 v22, v23, v22, v21                          ; d1cf0016 04562d17
	v_alignbyte_b32 v24, v24, v23, v21                          ; d1cf0018 04562f18
	v_cvt_f32_i32_sdwa v27, sext(v22) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e360af9 000a0616
	v_cvt_f32_i32_sdwa v28, sext(v22) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e380af9 00090616
	v_cvt_f32_i32_sdwa v26, sext(v22) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e340af9 000b0616
	v_cvt_f32_i32_sdwa v22, sext(v22) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e2c0af9 00080616
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_cvt_f32_f16_e32 v32, v25                                  ; 7e401719
	v_cvt_f32_i32_sdwa v29, sext(v24) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e3a0af9 000b0618
	v_cvt_f32_i32_sdwa v30, sext(v24) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e3c0af9 000a0618
	v_cvt_f32_i32_sdwa v31, sext(v24) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e3e0af9 00090618
	v_cvt_f32_i32_sdwa v24, sext(v24) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e300af9 00080618
	v_mul_f32_e32 v29, v19, v29                                 ; 0a3a3b13
	v_mac_f32_e32 v29, v18, v30                                 ; 2c3a3d12
	v_mac_f32_e32 v29, v17, v31                                 ; 2c3a3f11
	v_mac_f32_e32 v29, v16, v24                                 ; 2c3a3110
	v_mac_f32_e32 v29, v14, v27                                 ; 2c3a370e
	v_mac_f32_e32 v29, v15, v26                                 ; 2c3a350f
	v_mac_f32_e32 v29, v13, v28                                 ; 2c3a390d
	v_mac_f32_e32 v29, v12, v22                                 ; 2c3a2d0c
	v_mac_f32_e32 v5, v29, v32                                  ; 2c0a411d
	s_cbranch_scc0 BB144                                        ; bf84002e
BB136:
	v_add_u32_e32 v8, s9, v8                                    ; 68101009
	v_lshrrev_b32_e32 v8, 5, v8                                 ; 20101085
	v_add_u32_e32 v8, s20, v8                                   ; 68101014
	v_lshlrev_b32_e32 v10, 1, v8                                ; 24141081
	v_lshl_add_u32 v8, v8, 5, v10                               ; d1fd0008 04290b08
	v_add_u32_e32 v11, 2, v8                                    ; 68161082
	v_add_u32_e32 v20, v11, v9                                  ; 6828130b
	v_and_b32_e32 v11, -4, v11                                  ; 261616c4
	v_add_u32_e32 v11, v11, v9                                  ; 6816130b
	buffer_load_dwordx3 v[21:23], v11, s[24:27], 0 offen        ; e0581000 8006150b
	buffer_load_short_d16 v24, v8, s[24:27], 0 offen            ; e0901000 80061808
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_alignbyte_b32 v21, v22, v21, v20                          ; d1cf0015 04522b16
	v_alignbyte_b32 v23, v23, v22, v20                          ; d1cf0017 04522d17
	v_cvt_f32_i32_sdwa v25, sext(v21) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e320af9 000b0615
	v_cvt_f32_i32_sdwa v26, sext(v21) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e340af9 000a0615
	v_cvt_f32_i32_sdwa v27, sext(v21) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e360af9 00090615
	v_cvt_f32_i32_sdwa v21, sext(v21) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e2a0af9 00080615
	v_cvt_f32_i32_sdwa v28, sext(v23) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e380af9 000b0617
	v_cvt_f32_i32_sdwa v29, sext(v23) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e3a0af9 000a0617
	v_cvt_f32_i32_sdwa v30, sext(v23) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e3c0af9 00090617
	v_cvt_f32_i32_sdwa v23, sext(v23) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e2e0af9 00080617
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_cvt_f32_f16_e32 v31, v24                                  ; 7e3e1718
	v_mul_f32_e32 v19, v19, v28                                 ; 0a263913
	v_mac_f32_e32 v19, v18, v29                                 ; 2c263b12
	v_mac_f32_e32 v19, v17, v30                                 ; 2c263d11
	v_mac_f32_e32 v19, v16, v23                                 ; 2c262f10
	v_mac_f32_e32 v19, v14, v26                                 ; 2c26350e
	v_mac_f32_e32 v19, v15, v25                                 ; 2c26330f
	v_mac_f32_e32 v19, v13, v27                                 ; 2c26370d
	v_mac_f32_e32 v19, v12, v21                                 ; 2c262b0c
	v_mac_f32_e32 v6, v19, v31                                  ; 2c0c3f13
BB144:
	v_add_u32_e32 v3, 2, v3                                     ; 68060682
	s_branch BB115                                              ; bf82fe49
BB145:
	s_mov_b64 exec, -1                                          ; befe01c1
BB146:
	s_mov_b64 s[0:1], exec                                      ; be80017e
	v_cmpx_ge_u32_e32 vcc, v3, v2                               ; 7dbc0503
BB147:
	s_andn2_b64 s[0:1], s[0:1], exec                            ; 89807e00
	s_cbranch_scc0 BB164                                        ; bf8400dc
BB151:
	s_mov_b64 exec, s[0:1]                                      ; befe0100
	s_mov_b32 s0, s2                                            ; be800002
	s_movk_i32 s1, 0x8000                                       ; b0018000
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_load_dwordx4 s[12:15], s[0:1], 0x10                       ; c00a0300 00000010
	s_mul_i32 s5, s6, s17                                       ; 92051106
	s_mul_i32 s9, s16, s3                                       ; 92090310
	s_cmp_lg_i32 s4, 0                                          ; bf018004
	v_lshl_add_u32 v7, v3, 9, v0                                ; d1fd0007 04011303
	v_and_b32_e32 v8, 31, v7                                    ; 26100e9f
	v_sub_u32_e32 v9, v7, v8                                    ; 6a121107
	v_add3_u32 v9, v8, s5, v9                                   ; d1ff0009 04240b08
	s_cbranch_scc0 BB163                                        ; bf8400ca
BB152:
	s_load_dwordx4 s[24:27], s[0:1], 0x0                        ; c00a0600 00000000
	v_lshrrev_b32_e32 v9, 2, v9                                 ; 20121282
	v_lshlrev_b32_e32 v9, 4, v9                                 ; 24121284
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_load_dwordx4 v[12:15], v9, s[12:15], 0 offen         ; e05c1000 80030c09
	buffer_load_dwordx4 v[16:19], v9, s[12:15], 0 offen offset:16 ; e05c1010 80031009
	v_add_u32_e32 v9, s9, v7                                    ; 68120e09
	v_lshrrev_b32_e32 v9, 5, v9                                 ; 20121285
	v_add_u32_e32 v9, s20, v9                                   ; 68121214
	v_lshlrev_b32_e32 v10, 1, v9                                ; 24141281
	v_lshl_add_u32 v9, v9, 5, v10                               ; d1fd0009 04290b09
	v_add_u32_e32 v11, 2, v9                                    ; 68161282
	v_add_u32_e32 v20, v11, v8                                  ; 6828110b
	v_and_b32_e32 v11, -4, v11                                  ; 261616c4
	v_add_u32_e32 v11, v11, v8                                  ; 6816110b
	buffer_load_dwordx3 v[21:23], v11, s[24:27], 0 offen        ; e0581000 8006150b
	buffer_load_short_d16 v24, v9, s[24:27], 0 offen            ; e0901000 80061809
	s_add_u32 s9, s9, s3                                        ; 80090309
	s_cmp_lt_u32 1, s4                                          ; bf0a0481
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_alignbyte_b32 v21, v22, v21, v20                          ; d1cf0015 04522b16
	v_alignbyte_b32 v23, v23, v22, v20                          ; d1cf0017 04522d17
	v_cvt_f32_i32_sdwa v25, sext(v21) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e320af9 000b0615
	v_cvt_f32_i32_sdwa v26, sext(v21) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e340af9 000a0615
	v_cvt_f32_i32_sdwa v27, sext(v21) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e360af9 00090615
	v_cvt_f32_i32_sdwa v21, sext(v21) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e2a0af9 00080615
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_cvt_f32_f16_e32 v31, v24                                  ; 7e3e1718
	v_cvt_f32_i32_sdwa v28, sext(v23) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e380af9 000b0617
	v_cvt_f32_i32_sdwa v29, sext(v23) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e3a0af9 000a0617
	v_cvt_f32_i32_sdwa v30, sext(v23) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e3c0af9 00090617
	v_cvt_f32_i32_sdwa v23, sext(v23) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e2e0af9 00080617
	v_mul_f32_e32 v28, v19, v28                                 ; 0a383913
	v_mac_f32_e32 v28, v18, v29                                 ; 2c383b12
	v_mac_f32_e32 v28, v17, v30                                 ; 2c383d11
	v_mac_f32_e32 v28, v16, v23                                 ; 2c382f10
	v_mac_f32_e32 v28, v14, v26                                 ; 2c38350e
	v_mac_f32_e32 v28, v15, v25                                 ; 2c38330f
	v_mac_f32_e32 v28, v13, v27                                 ; 2c38370d
	v_mac_f32_e32 v28, v12, v21                                 ; 2c382b0c
	v_mac_f32_e32 v1, v28, v31                                  ; 2c023f1c
	s_cbranch_scc0 BB163                                        ; bf840090
BB153:
	v_add_u32_e32 v9, s9, v7                                    ; 68120e09
	v_lshrrev_b32_e32 v9, 5, v9                                 ; 20121285
	v_add_u32_e32 v9, s20, v9                                   ; 68121214
	v_lshlrev_b32_e32 v10, 1, v9                                ; 24141281
	v_lshl_add_u32 v9, v9, 5, v10                               ; d1fd0009 04290b09
	v_add_u32_e32 v11, 2, v9                                    ; 68161282
	v_add_u32_e32 v20, v11, v8                                  ; 6828110b
	v_and_b32_e32 v11, -4, v11                                  ; 261616c4
	v_add_u32_e32 v11, v11, v8                                  ; 6816110b
	buffer_load_dwordx3 v[21:23], v11, s[24:27], 0 offen        ; e0581000 8006150b
	buffer_load_short_d16 v24, v9, s[24:27], 0 offen            ; e0901000 80061809
	s_add_u32 s9, s9, s3                                        ; 80090309
	s_cmp_lt_u32 2, s4                                          ; bf0a0482
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_alignbyte_b32 v21, v22, v21, v20                          ; d1cf0015 04522b16
	v_alignbyte_b32 v23, v23, v22, v20                          ; d1cf0017 04522d17
	v_cvt_f32_i32_sdwa v26, sext(v21) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e340af9 000a0615
	v_cvt_f32_i32_sdwa v27, sext(v21) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e360af9 00090615
	v_cvt_f32_i32_sdwa v25, sext(v21) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e320af9 000b0615
	v_cvt_f32_i32_sdwa v21, sext(v21) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e2a0af9 00080615
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_cvt_f32_f16_e32 v31, v24                                  ; 7e3e1718
	v_cvt_f32_i32_sdwa v28, sext(v23) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e380af9 000b0617
	v_cvt_f32_i32_sdwa v29, sext(v23) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e3a0af9 000a0617
	v_cvt_f32_i32_sdwa v30, sext(v23) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e3c0af9 00090617
	v_cvt_f32_i32_sdwa v23, sext(v23) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e2e0af9 00080617
	v_mul_f32_e32 v28, v19, v28                                 ; 0a383913
	v_mac_f32_e32 v28, v18, v29                                 ; 2c383b12
	v_mac_f32_e32 v28, v17, v30                                 ; 2c383d11
	v_mac_f32_e32 v28, v16, v23                                 ; 2c382f10
	v_mac_f32_e32 v28, v14, v26                                 ; 2c38350e
	v_mac_f32_e32 v28, v15, v25                                 ; 2c38330f
	v_mac_f32_e32 v28, v13, v27                                 ; 2c38370d
	v_mac_f32_e32 v28, v12, v21                                 ; 2c382b0c
	v_mac_f32_e32 v4, v28, v31                                  ; 2c083f1c
	s_cbranch_scc0 BB163                                        ; bf84005f
BB154:
	v_add_u32_e32 v9, s9, v7                                    ; 68120e09
	v_lshrrev_b32_e32 v9, 5, v9                                 ; 20121285
	v_add_u32_e32 v9, s20, v9                                   ; 68121214
	v_lshlrev_b32_e32 v10, 1, v9                                ; 24141281
	v_lshl_add_u32 v9, v9, 5, v10                               ; d1fd0009 04290b09
	v_add_u32_e32 v11, 2, v9                                    ; 68161282
	v_add_u32_e32 v20, v11, v8                                  ; 6828110b
	v_and_b32_e32 v11, -4, v11                                  ; 261616c4
	v_add_u32_e32 v11, v11, v8                                  ; 6816110b
	buffer_load_dwordx3 v[21:23], v11, s[24:27], 0 offen        ; e0581000 8006150b
	buffer_load_short_d16 v24, v9, s[24:27], 0 offen            ; e0901000 80061809
	s_add_u32 s9, s9, s3                                        ; 80090309
	s_cmp_lt_u32 3, s4                                          ; bf0a0483
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_alignbyte_b32 v21, v22, v21, v20                          ; d1cf0015 04522b16
	v_alignbyte_b32 v23, v23, v22, v20                          ; d1cf0017 04522d17
	v_cvt_f32_i32_sdwa v26, sext(v21) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e340af9 000a0615
	v_cvt_f32_i32_sdwa v27, sext(v21) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e360af9 00090615
	v_cvt_f32_i32_sdwa v25, sext(v21) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e320af9 000b0615
	v_cvt_f32_i32_sdwa v21, sext(v21) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e2a0af9 00080615
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_cvt_f32_f16_e32 v31, v24                                  ; 7e3e1718
	v_cvt_f32_i32_sdwa v28, sext(v23) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e380af9 000b0617
	v_cvt_f32_i32_sdwa v29, sext(v23) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e3a0af9 000a0617
	v_cvt_f32_i32_sdwa v30, sext(v23) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e3c0af9 00090617
	v_cvt_f32_i32_sdwa v23, sext(v23) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e2e0af9 00080617
	v_mul_f32_e32 v28, v19, v28                                 ; 0a383913
	v_mac_f32_e32 v28, v18, v29                                 ; 2c383b12
	v_mac_f32_e32 v28, v17, v30                                 ; 2c383d11
	v_mac_f32_e32 v28, v16, v23                                 ; 2c382f10
	v_mac_f32_e32 v28, v14, v26                                 ; 2c38350e
	v_mac_f32_e32 v28, v15, v25                                 ; 2c38330f
	v_mac_f32_e32 v28, v13, v27                                 ; 2c38370d
	v_mac_f32_e32 v28, v12, v21                                 ; 2c382b0c
	v_mac_f32_e32 v5, v28, v31                                  ; 2c0a3f1c
	s_cbranch_scc0 BB163                                        ; bf84002e
BB155:
	v_add_u32_e32 v7, s9, v7                                    ; 680e0e09
	v_lshrrev_b32_e32 v7, 5, v7                                 ; 200e0e85
	v_add_u32_e32 v7, s20, v7                                   ; 680e0e14
	v_lshlrev_b32_e32 v9, 1, v7                                 ; 24120e81
	v_lshl_add_u32 v7, v7, 5, v9                                ; d1fd0007 04250b07
	v_add_u32_e32 v10, 2, v7                                    ; 68140e82
	v_add_u32_e32 v11, v10, v8                                  ; 6816110a
	v_and_b32_e32 v10, -4, v10                                  ; 261414c4
	v_add_u32_e32 v10, v10, v8                                  ; 6814110a
	buffer_load_dwordx3 v[20:22], v10, s[24:27], 0 offen        ; e0581000 8006140a
	buffer_load_short_d16 v23, v7, s[24:27], 0 offen            ; e0901000 80061707
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_alignbyte_b32 v20, v21, v20, v11                          ; d1cf0014 042e2915
	v_alignbyte_b32 v22, v22, v21, v11                          ; d1cf0016 042e2b16
	v_cvt_f32_i32_sdwa v24, sext(v20) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e300af9 000b0614
	v_cvt_f32_i32_sdwa v25, sext(v20) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e320af9 000a0614
	v_cvt_f32_i32_sdwa v26, sext(v20) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e340af9 00090614
	v_cvt_f32_i32_sdwa v20, sext(v20) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e280af9 00080614
	v_cvt_f32_i32_sdwa v27, sext(v22) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e360af9 000b0616
	v_cvt_f32_i32_sdwa v28, sext(v22) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e380af9 000a0616
	v_cvt_f32_i32_sdwa v29, sext(v22) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e3a0af9 00090616
	v_cvt_f32_i32_sdwa v22, sext(v22) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e2c0af9 00080616
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_cvt_f32_f16_e32 v30, v23                                  ; 7e3c1717
	v_mul_f32_e32 v19, v19, v27                                 ; 0a263713
	v_mac_f32_e32 v19, v18, v28                                 ; 2c263912
	v_mac_f32_e32 v19, v17, v29                                 ; 2c263b11
	v_mac_f32_e32 v19, v16, v22                                 ; 2c262d10
	v_mac_f32_e32 v19, v14, v25                                 ; 2c26330e
	v_mac_f32_e32 v19, v15, v24                                 ; 2c26310f
	v_mac_f32_e32 v19, v13, v26                                 ; 2c26350d
	v_mac_f32_e32 v19, v12, v20                                 ; 2c26290c
	v_mac_f32_e32 v6, v19, v30                                  ; 2c0c3d13
BB163:
	v_add_u32_e32 v3, 1, v3                                     ; 68060681
	s_branch BB146                                              ; bf82ff20
BB164:
	s_mov_b64 exec, -1                                          ; befe01c1
	s_cmp_lg_i32 s4, 0                                          ; bf018004
	s_cselect_b64 s[0:1], -1, 0                                 ; 858080c1
	s_cbranch_scc0 BB176                                        ; bf84006a
BB165:
	s_or_saveexec_b64 s[10:11], -1                              ; be8a21c1
	s_cmp_lt_u32 1, s4                                          ; bf0a0481
	v_cndmask_b32_e64 v39, 0, v1, s[10:11]                      ; d1000027 002a0280
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v39, v39, v39 quad_perm:[1,0,3,2] row_mask:0xf bank_mask:0xf ; 024e4efa ff00b127
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v39, v39, v39 quad_perm:[2,3,0,1] row_mask:0xf bank_mask:0xf ; 024e4efa ff004e27
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v39, v39, v39 row_half_mirror row_mask:0xf bank_mask:0xf ; 024e4efa ff014127
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v39, v39, v39 row_mirror row_mask:0xf bank_mask:0xf ; 024e4efa ff014027
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v39, v39, v39 row_bcast:15 row_mask:0xa bank_mask:0xf ; 024e4efa af014227
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v39, v39, v39 row_bcast:31 row_mask:0xc bank_mask:0xf ; 024e4efa cf014327
	s_mov_b64 exec, s[10:11]                                    ; befe010a
	v_readlane_b32 s3, v39, 63                                  ; d2890003 00017f27
	s_cbranch_scc0 BB174                                        ; bf84004f
BB166:
	s_or_saveexec_b64 s[10:11], -1                              ; be8a21c1
	s_cmp_lt_u32 2, s4                                          ; bf0a0482
	v_cndmask_b32_e64 v39, 0, v4, s[10:11]                      ; d1000027 002a0880
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v39, v39, v39 quad_perm:[1,0,3,2] row_mask:0xf bank_mask:0xf ; 024e4efa ff00b127
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v39, v39, v39 quad_perm:[2,3,0,1] row_mask:0xf bank_mask:0xf ; 024e4efa ff004e27
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v39, v39, v39 row_half_mirror row_mask:0xf bank_mask:0xf ; 024e4efa ff014127
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v39, v39, v39 row_mirror row_mask:0xf bank_mask:0xf ; 024e4efa ff014027
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v39, v39, v39 row_bcast:15 row_mask:0xa bank_mask:0xf ; 024e4efa af014227
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v39, v39, v39 row_bcast:31 row_mask:0xc bank_mask:0xf ; 024e4efa cf014327
	s_mov_b64 exec, s[10:11]                                    ; befe010a
	v_readlane_b32 s5, v39, 63                                  ; d2890005 00017f27
	s_cbranch_scc0 BB172                                        ; bf840034
BB167:
	s_or_saveexec_b64 s[10:11], -1                              ; be8a21c1
	s_cmp_lt_u32 3, s4                                          ; bf0a0483
	v_cndmask_b32_e64 v39, 0, v5, s[10:11]                      ; d1000027 002a0a80
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v39, v39, v39 quad_perm:[1,0,3,2] row_mask:0xf bank_mask:0xf ; 024e4efa ff00b127
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v39, v39, v39 quad_perm:[2,3,0,1] row_mask:0xf bank_mask:0xf ; 024e4efa ff004e27
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v39, v39, v39 row_half_mirror row_mask:0xf bank_mask:0xf ; 024e4efa ff014127
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v39, v39, v39 row_mirror row_mask:0xf bank_mask:0xf ; 024e4efa ff014027
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v39, v39, v39 row_bcast:15 row_mask:0xa bank_mask:0xf ; 024e4efa af014227
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v39, v39, v39 row_bcast:31 row_mask:0xc bank_mask:0xf ; 024e4efa cf014327
	s_mov_b64 exec, s[10:11]                                    ; befe010a
	v_readlane_b32 s6, v39, 63                                  ; d2890006 00017f27
	s_cbranch_scc0 BB170                                        ; bf840019
BB168:
	s_or_saveexec_b64 s[10:11], -1                              ; be8a21c1
	v_cndmask_b32_e64 v39, 0, v6, s[10:11]                      ; d1000027 002a0c80
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v39, v39, v39 quad_perm:[1,0,3,2] row_mask:0xf bank_mask:0xf ; 024e4efa ff00b127
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v39, v39, v39 quad_perm:[2,3,0,1] row_mask:0xf bank_mask:0xf ; 024e4efa ff004e27
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v39, v39, v39 row_half_mirror row_mask:0xf bank_mask:0xf ; 024e4efa ff014127
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v39, v39, v39 row_mirror row_mask:0xf bank_mask:0xf ; 024e4efa ff014027
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v39, v39, v39 row_bcast:15 row_mask:0xa bank_mask:0xf ; 024e4efa af014227
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v39, v39, v39 row_bcast:31 row_mask:0xc bank_mask:0xf ; 024e4efa cf014327
	s_mov_b64 exec, s[10:11]                                    ; befe010a
	v_readlane_b32 s9, v39, 63                                  ; d2890009 00017f27
	v_mov_b32_e32 v6, s9                                        ; 7e0c0209
BB170:
	v_mov_b32_e32 v5, s6                                        ; 7e0a0206
BB172:
	v_mov_b32_e32 v4, s5                                        ; 7e080205
BB174:
	v_mov_b32_e32 v1, s3                                        ; 7e020203
BB176:
	s_mov_b64 s[10:11], 1                                       ; be8a0181
	s_and_b64 exec, s[0:1], s[10:11]                            ; 86fe0a00
	s_cbranch_execz BB191                                       ; bf880012
BB177:
	v_mov_b32_e32 v0, 0                                         ; 7e000280
	ds_write_b32 v0, v1                                         ; d81a0000 00000100
	s_cmp_lt_u32 1, s4                                          ; bf0a0481
	s_cbranch_scc0 BB191                                        ; bf84000d
BB178:
	v_mov_b32_e32 v0, 0                                         ; 7e000280
	ds_write_b32 v0, v4 offset:4                                ; d81a0004 00000400
	s_cmp_lt_u32 2, s4                                          ; bf0a0482
	s_cbranch_scc0 BB191                                        ; bf840008
BB179:
	v_mov_b32_e32 v0, 0                                         ; 7e000280
	ds_write_b32 v0, v5 offset:8                                ; d81a0008 00000500
	s_cmp_lt_u32 3, s4                                          ; bf0a0483
	s_cbranch_scc0 BB191                                        ; bf840003
BB180:
	v_mov_b32_e32 v0, 0                                         ; 7e000280
	ds_write_b32 v0, v6 offset:12                               ; d81a000c 00000600
BB191:
	s_mov_b64 exec, s[10:11]                                    ; befe010a
	s_cbranch_execz BB217                                       ; bf880087
BB192:
	s_min_u32 s4, 4, s4                                         ; 83840484
	s_mov_b32 s0, 0                                             ; be800080
BB193:
	s_cmp_ge_u32 s0, s4                                         ; bf090400
	s_cbranch_scc1 BB217                                        ; bf850083
BB195:
	s_cmp_lt_i32 s0, 2                                          ; bf048200
	s_cselect_b64 vcc, -1, 0                                    ; 85ea80c1
	s_cmp_lt_i32 s0, 3                                          ; bf048300
	s_cselect_b64 s[10:11], -1, 0                               ; 858a80c1
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_or_b64 s[12:13], vcc, s[10:11]                            ; 878c0a6a
	s_andn2_b64 s[14:15], s[10:11], vcc                         ; 898e6a0a
	s_cmp_lt_i32 s0, 1                                          ; bf048100
	v_cndmask_b32_e64 v0, 0, v6, s[12:13]                       ; d1000000 00320c80
	v_cndmask_b32_e64 v2, v5, 0, s[14:15]                       ; d1000002 00390105
	s_cselect_b64 s[20:21], -1, 0                               ; 859480c1
	s_andn2_b64 s[22:23], vcc, s[20:21]                         ; 8996146a
	s_and_b64 s[24:25], vcc, s[20:21]                           ; 8698146a
	s_and_b32 s1, s19, 63                                       ; 8601bf13
	v_cndmask_b32_e64 v3, v4, 0, s[22:23]                       ; d1000003 00590104
	v_cndmask_b32_e64 v7, v1, 0, s[24:25]                       ; d1000007 00610101
	s_cbranch_scc0 BB201                                        ; bf840020
BB196:
	s_lshl_b32 s3, s0, 2                                        ; 8e038200
	v_mov_b32_e32 v8, s3                                        ; 7e100203
	ds_read_b32 v8, v8                                          ; d86c0000 08000008
	s_mov_b32 s3, 1                                             ; be830081
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_cndmask_b32_e64 v3, v8, v3, s[20:21]                      ; d1000003 00520708
	v_cndmask_b32_e64 v7, v7, v8, s[20:21]                      ; d1000007 00521107
	v_cndmask_b32_e64 v0, v8, v0, s[10:11]                      ; d1000000 002a0108
	v_cndmask_b32_e64 v2, v2, v8, s[10:11]                      ; d1000002 002a1102
	v_cndmask_b32_e32 v4, v4, v3, vcc                           ; 00080704
	v_cndmask_b32_e32 v1, v1, v7, vcc                           ; 00020f01
	v_cndmask_b32_e32 v6, v0, v6, vcc                           ; 000c0d00
	v_cndmask_b32_e32 v5, v2, v5, vcc                           ; 000a0b02
BB197:
	s_cmp_ge_u32 s3, s1                                         ; bf090103
	s_cbranch_scc1 BB202                                        ; bf850010
BB199:
	v_mov_b32_e32 v0, 0x7fc00000                                ; 7e0002ff 7fc00000
	s_add_u32 s3, s3, 1                                         ; 80038103
	v_cndmask_b32_e64 v6, v0, v6, s[12:13]                      ; d1000006 00320d00
	v_cndmask_b32_e64 v5, v5, v0, s[14:15]                      ; d1000005 003a0105
	v_cndmask_b32_e64 v4, v4, v0, s[22:23]                      ; d1000004 005a0104
	v_cndmask_b32_e64 v1, v1, v0, s[24:25]                      ; d1000001 00620101
	s_branch BB197                                              ; bf82fff2
BB201:
	v_mov_b32_e32 v1, v7                                        ; 7e020307
	v_mov_b32_e32 v4, v3                                        ; 7e080303
	v_mov_b32_e32 v5, v2                                        ; 7e0a0302
	v_mov_b32_e32 v6, v0                                        ; 7e0c0300
BB202:
	s_bitcmp1_b32 s8, 0                                         ; bf0d8008
	s_cbranch_scc0 BB205                                        ; bf84001a
BB203:
	s_mov_b32 s26, s2                                           ; be9a0002
	s_movk_i32 s27, 0x8000                                      ; b01b8000
	s_load_dwordx4 s[28:31], s[26:27], 0x30                     ; c00a070d 00000030
	s_mul_i32 s1, s7, s17                                       ; 92011107
	s_add_u32 s1, s1, s16                                       ; 80011001
	s_add_u32 s1, s1, s0                                        ; 80010001
	s_lshl_b32 s1, s1, 2                                        ; 8e018201
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s1, s[28:31], s1                        ; c020004e 00000001
	v_cndmask_b32_e64 v0, v4, v1, s[20:21]                      ; d1000000 00520304
	v_cndmask_b32_e64 v2, v6, v5, s[10:11]                      ; d1000002 002a0b06
	v_cndmask_b32_e32 v2, v2, v0, vcc                           ; 00040102
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v2, s1, v2                                    ; 02040401
	v_cndmask_b32_e64 v6, v2, v6, s[12:13]                      ; d1000006 00320d02
	v_cndmask_b32_e64 v5, v5, v2, s[14:15]                      ; d1000005 003a0505
	v_cndmask_b32_e64 v4, v4, v2, s[22:23]                      ; d1000004 005a0504
	v_cndmask_b32_e64 v1, v1, v2, s[24:25]                      ; d1000001 00620501
BB205:
	s_bitcmp1_b32 s8, 1                                         ; bf0d8108
	s_cbranch_scc0 BB208                                        ; bf84001a
BB206:
	s_mov_b32 s26, s2                                           ; be9a0002
	s_movk_i32 s27, 0x8000                                      ; b01b8000
	s_load_dwordx4 s[28:31], s[26:27], 0x40                     ; c00a070d 00000040
	s_mul_i32 s1, s7, s17                                       ; 92011107
	s_add_u32 s1, s1, s16                                       ; 80011001
	s_add_u32 s1, s1, s0                                        ; 80010001
	s_lshl_b32 s1, s1, 2                                        ; 8e018201
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s1, s[28:31], s1                        ; c020004e 00000001
	v_cndmask_b32_e64 v0, v4, v1, s[20:21]                      ; d1000000 00520304
	v_cndmask_b32_e64 v2, v6, v5, s[10:11]                      ; d1000002 002a0b06
	v_cndmask_b32_e32 v2, v2, v0, vcc                           ; 00040102
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v2, s1, v2                                    ; 02040401
	v_cndmask_b32_e64 v6, v2, v6, s[12:13]                      ; d1000006 00320d02
	v_cndmask_b32_e64 v5, v5, v2, s[14:15]                      ; d1000005 003a0505
	v_cndmask_b32_e64 v4, v4, v2, s[22:23]                      ; d1000004 005a0504
	v_cndmask_b32_e64 v1, v1, v2, s[24:25]                      ; d1000001 00620501
BB208:
	s_mov_b32 s12, s2                                           ; be8c0002
	s_movk_i32 s13, 0x8000                                      ; b00d8000
	s_load_dwordx4 s[12:15], s[12:13], 0x20                     ; c00a0306 00000020
	s_mul_i32 s1, s7, s17                                       ; 92011107
	v_cndmask_b32_e64 v2, v6, v5, s[10:11]                      ; d1000002 002a0b06
	v_cndmask_b32_e64 v0, v4, v1, s[20:21]                      ; d1000000 00520304
	s_add_u32 s1, s1, s16                                       ; 80011001
	v_cndmask_b32_e32 v2, v2, v0, vcc                           ; 00040102
	s_add_u32 s1, s1, s0                                        ; 80010001
	s_lshl_b32 s1, s1, 2                                        ; 8e018201
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_store_dword v2, off, s[12:15], s1                    ; e0700000 01030280
	s_add_u32 s0, s0, 1                                         ; 80008100
	s_branch BB193                                              ; bf82ff7b
BB217:
	s_endpgm                                                    ; bf810000
