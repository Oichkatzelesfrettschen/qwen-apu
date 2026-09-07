BB0:
	s_load_dword s0, s[14:15], 0x0                              ; c0020007 00000000
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_mul_i32 s0, s0, s18                                       ; 92001200
	s_add_u32 s16, s16, s0                                      ; 80100010
	s_lshl_b32 s16, s16, 1                                      ; 8e108110
	s_add_u32 s1, s16, 2                                        ; 80018210
	s_cmp_ge_u32 s4, s1                                         ; bf090104
	s_cbranch_scc0 BB56                                         ; bf840410
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
	s_mul_i32 s18, s18, s5                                      ; 92120512
	v_add_u32_e32 v1, s0, v0                                    ; 68020000
	s_mov_b32 s0, 0                                             ; be800080
	v_cmp_gt_u32_e32 vcc, s3, v1                                ; 7d980203
	v_mov_b32_e32 v1, 0                                         ; 7e020280
	v_cndmask_b32_e64 v2, 0, 1, vcc                             ; d1000002 01a90280
	v_add_u32_e32 v2, s1, v2                                    ; 68040401
	v_and_b32_e32 v3, -4, v2                                    ; 260604c4
	s_branch BB5                                                ; bf8201b5
BB10:
	s_mov_b64 exec, s[4:5]                                      ; befe0104
	s_mov_b32 s4, s2                                            ; be840002
	s_movk_i32 s5, 0x8000                                       ; b0058000
	s_load_dwordx8 s[24:31], s[4:5], 0x0                        ; c00e0602 00000000
	s_lshl_b32 s1, s0, 9                                        ; 8e018900
	s_mul_i32 s4, s6, s17                                       ; 92041106
	v_add_u32_e32 v5, s1, v0                                    ; 680a0001
	v_and_b32_e32 v6, 31, v5                                    ; 260c0a9f
	v_sub_u32_e32 v7, v5, v6                                    ; 6a0e0d05
	v_add3_u32 v7, v6, s4, v7                                   ; d1ff0007 041c0906
	v_lshrrev_b32_e32 v7, 2, v7                                 ; 200e0e82
	v_lshlrev_b32_e32 v7, 4, v7                                 ; 240e0e84
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_load_dwordx4 v[8:11], v7, s[28:31], 0 offen          ; e05c1000 80070807
	buffer_load_dwordx4 v[12:15], v7, s[28:31], 0 offen offset:16 ; e05c1010 80070c07
	s_mul_i32 s5, s16, s3                                       ; 92050310
	s_add_u32 s9, s5, s3                                        ; 80090305
	v_add_u32_e32 v16, s5, v5                                   ; 68200a05
	v_add_u32_e32 v5, s9, v5                                    ; 680a0a09
	v_lshrrev_b32_e32 v16, 5, v16                               ; 20202085
	v_lshrrev_b32_e32 v5, 5, v5                                 ; 200a0a85
	v_add_u32_e32 v16, s18, v16                                 ; 68202012
	v_add_u32_e32 v5, s18, v5                                   ; 680a0a12
	v_lshlrev_b32_e32 v17, 1, v16                               ; 24222081
	v_lshlrev_b32_e32 v20, 1, v5                                ; 24280a81
	v_lshl_add_u32 v16, v16, 5, v17                             ; d1fd0010 04450b10
	v_lshl_add_u32 v5, v5, 5, v20                               ; d1fd0005 04510b05
	v_add_u32_e32 v18, 2, v16                                   ; 68242082
	v_add_u32_e32 v21, 2, v5                                    ; 682a0a82
	v_add_u32_e32 v19, v18, v6                                  ; 68260d12
	v_and_b32_e32 v18, -4, v18                                  ; 262424c4
	v_add_u32_e32 v22, v21, v6                                  ; 682c0d15
	v_and_b32_e32 v21, -4, v21                                  ; 262a2ac4
	v_add_u32_e32 v18, v18, v6                                  ; 68240d12
	v_add_u32_e32 v21, v21, v6                                  ; 682a0d15
	buffer_load_dwordx3 v[23:25], v18, s[24:27], 0 offen        ; e0581000 80061712
	buffer_load_short_d16 v26, v16, s[24:27], 0 offen           ; e0901000 80061a10
	buffer_load_dwordx3 v[27:29], v21, s[24:27], 0 offen        ; e0581000 80061b15
	buffer_load_short_d16 v30, v5, s[24:27], 0 offen            ; e0901000 80061e05
	s_add_u32 s10, s1, 0x200                                    ; 800aff01 00000200
	v_mov_b32_e32 v38, v4                                       ; 7e4c0304
	v_add_u32_e32 v31, s10, v0                                  ; 683e000a
	v_and_b32_e32 v32, 31, v31                                  ; 26403e9f
	v_sub_u32_e32 v33, v31, v32                                 ; 6a42411f
	v_add3_u32 v33, v32, s4, v33                                ; d1ff0021 04840920
	v_lshrrev_b32_e32 v33, 2, v33                               ; 20424282
	v_lshlrev_b32_e32 v33, 4, v33                               ; 24424284
	buffer_load_dwordx4 v[34:37], v33, s[28:31], 0 offen        ; e05c1000 80072221
	buffer_load_dwordx4 v[4:7], v33, s[28:31], 0 offen offset:16 ; e05c1010 80070421
	v_add_u32_e32 v16, s5, v31                                  ; 68203e05
	v_lshrrev_b32_e32 v16, 5, v16                               ; 20202085
	v_add_u32_e32 v16, s18, v16                                 ; 68202012
	s_waitcnt vmcnt(5)                                          ; bf8c3f75
	v_alignbyte_b32 v25, v25, v24, v19                          ; d1cf0019 044e3119
	v_alignbyte_b32 v23, v24, v23, v19                          ; d1cf0017 044e2f18
	v_cvt_f32_i32_sdwa v20, sext(v25) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e280af9 000b0619
	v_cvt_f32_i32_sdwa v21, sext(v25) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e2a0af9 000a0619
	v_cvt_f32_i32_sdwa v24, sext(v25) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e300af9 00090619
	v_cvt_f32_i32_sdwa v25, sext(v25) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e320af9 00080619
	v_cvt_f32_i32_sdwa v18, sext(v23) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e240af9 000a0617
	v_cvt_f32_i32_sdwa v19, sext(v23) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e260af9 00090617
	v_cvt_f32_i32_sdwa v17, sext(v23) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e220af9 000b0617
	v_cvt_f32_i32_sdwa v23, sext(v23) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e2e0af9 00080617
	v_mul_f32_e32 v20, v15, v20                                 ; 0a28290f
	v_mac_f32_e32 v20, v14, v21                                 ; 2c282b0e
	v_mac_f32_e32 v20, v13, v24                                 ; 2c28310d
	v_mac_f32_e32 v20, v12, v25                                 ; 2c28330c
	v_lshlrev_b32_e32 v25, 1, v16                               ; 24322081
	v_mac_f32_e32 v20, v10, v18                                 ; 2c28250a
	v_mov_b32_e32 v18, v23                                      ; 7e240317
	v_lshl_add_u32 v16, v16, 5, v25                             ; d1fd0010 04650b10
	v_mac_f32_e32 v20, v11, v17                                 ; 2c28230b
	v_add_u32_e32 v33, 2, v16                                   ; 68422082
	v_add_u32_e32 v17, v33, v32                                 ; 68224121
	v_and_b32_e32 v33, -4, v33                                  ; 264242c4
	v_add_u32_e32 v33, v33, v32                                 ; 68424121
	buffer_load_dwordx3 v[23:25], v33, s[24:27], 0 offen        ; e0581000 80061721
	buffer_load_short_d16 v21, v16, s[24:27], 0 offen           ; e0901000 80061510
	v_add_u32_e32 v31, s9, v31                                  ; 683e3e09
	v_mac_f32_e32 v20, v9, v19                                  ; 2c282709
	s_waitcnt vmcnt(6)                                          ; bf8c3f76
	v_cvt_f32_f16_e32 v19, v26                                  ; 7e26171a
	s_waitcnt vmcnt(5)                                          ; bf8c3f75
	v_alignbyte_b32 v27, v28, v27, v22                          ; d1cf001b 045a371c
	v_alignbyte_b32 v29, v29, v28, v22                          ; d1cf001d 045a391d
	v_lshrrev_b32_e32 v31, 5, v31                               ; 203e3e85
	v_mac_f32_e32 v20, v8, v18                                  ; 2c282508
	v_cvt_f32_i32_sdwa v26, sext(v27) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e340af9 0009061b
	v_cvt_f32_i32_sdwa v22, sext(v27) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e2c0af9 000a061b
	v_cvt_f32_i32_sdwa v28, sext(v29) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e380af9 000b061d
	v_add_u32_e32 v31, s18, v31                                 ; 683e3e12
	v_mac_f32_e32 v1, v20, v19                                  ; 2c022714
	v_mul_f32_e32 v15, v15, v28                                 ; 0a1e390f
	v_lshlrev_b32_e32 v33, 1, v31                               ; 24423e81
	v_lshl_add_u32 v31, v31, 5, v33                             ; d1fd001f 04850b1f
	v_add_u32_e32 v16, 2, v31                                   ; 68203e82
	v_add_u32_e32 v18, v16, v32                                 ; 68244110
	v_and_b32_e32 v16, -4, v16                                  ; 262020c4
	v_add_u32_e32 v16, v16, v32                                 ; 68204110
	v_cvt_f32_i32_sdwa v32, sext(v29) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e400af9 000a061d
	v_mac_f32_e32 v15, v14, v32                                 ; 2c1e410e
	v_mov_b32_e32 v33, v15                                      ; 7e42030f
	buffer_load_dwordx3 v[14:16], v16, s[24:27], 0 offen        ; e0581000 80060e10
	buffer_load_short_d16 v19, v31, s[24:27], 0 offen           ; e0901000 8006131f
	v_cvt_f32_i32_sdwa v20, sext(v27) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e280af9 000b061b
	v_cvt_f32_i32_sdwa v27, sext(v27) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e360af9 0008061b
	v_cvt_f32_i32_sdwa v28, sext(v29) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e380af9 0009061d
	v_cvt_f32_i32_sdwa v29, sext(v29) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e3a0af9 0008061d
	s_add_u32 s11, 0x400, s1                                    ; 800b01ff 00000400
	v_mac_f32_e32 v33, v13, v28                                 ; 2c42390d
	v_mac_f32_e32 v33, v12, v29                                 ; 2c423b0c
	v_add_u32_e32 v29, s11, v0                                  ; 683a000b
	v_mac_f32_e32 v33, v10, v22                                 ; 2c422d0a
	v_and_b32_e32 v31, 31, v29                                  ; 263e3a9f
	v_mac_f32_e32 v33, v11, v20                                 ; 2c42290b
	v_sub_u32_e32 v32, v29, v31                                 ; 6a403f1d
	v_mac_f32_e32 v33, v9, v26                                  ; 2c423509
	v_add3_u32 v32, v31, s4, v32                                ; d1ff0020 0480091f
	v_lshrrev_b32_e32 v32, 2, v32                               ; 20404082
	v_lshlrev_b32_e32 v32, 4, v32                               ; 24404084
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_pack_b32_f16 v9, v19, v21                                 ; d2a00009 00022b13
	buffer_load_dwordx4 v[10:13], v32, s[28:31], 0 offen        ; e05c1000 80070a20
	buffer_load_dwordx4 v[19:22], v32, s[28:31], 0 offen offset:16 ; e05c1010 80071320
	v_add_u32_e32 v26, s5, v29                                  ; 68343a05
	v_mac_f32_e32 v33, v8, v27                                  ; 2c423708
	v_cvt_f32_f16_e32 v27, v30                                  ; 7e36171e
	v_alignbyte_b32 v25, v25, v24, v17                          ; d1cf0019 04463119
	v_alignbyte_b32 v23, v24, v23, v17                          ; d1cf0017 04462f18
	v_lshrrev_b32_e32 v26, 5, v26                               ; 20343485
	v_mac_f32_e32 v38, v33, v27                                 ; 2c4c3721
	v_cvt_f32_i32_sdwa v17, sext(v25) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e220af9 00090619
	v_cvt_f32_i32_sdwa v8, sext(v25) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e100af9 000a0619
	v_cvt_f32_i32_sdwa v33, sext(v25) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e420af9 000b0619
	v_cvt_f32_i32_sdwa v25, sext(v25) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e320af9 00080619
	v_cvt_f32_i32_sdwa v28, sext(v23) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e380af9 000b0617
	v_cvt_f32_i32_sdwa v32, sext(v23) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e400af9 00090617
	v_cvt_f32_i32_sdwa v30, sext(v23) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e3c0af9 000a0617
	v_cvt_f32_i32_sdwa v23, sext(v23) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e2e0af9 00080617
	v_add_u32_e32 v26, s18, v26                                 ; 68343412
	v_mul_f32_e32 v33, v7, v33                                  ; 0a424307
	v_lshlrev_b32_e32 v24, 1, v26                               ; 24303481
	v_mac_f32_e32 v33, v6, v8                                   ; 2c421106
	v_mov_b32_e32 v8, v23                                       ; 7e100317
	v_lshl_add_u32 v26, v26, 5, v24                             ; d1fd001a 04610b1a
	v_mac_f32_e32 v33, v5, v17                                  ; 2c422305
	v_mac_f32_e32 v33, v4, v25                                  ; 2c423304
	v_add_u32_e32 v25, 2, v26                                   ; 68323482
	v_add_u32_e32 v27, v25, v31                                 ; 68363f19
	v_and_b32_e32 v25, -4, v25                                  ; 263232c4
	v_add_u32_e32 v25, v25, v31                                 ; 68323f19
	buffer_load_dwordx3 v[23:25], v25, s[24:27], 0 offen        ; e0581000 80061719
	buffer_load_short_d16 v17, v26, s[24:27], 0 offen           ; e0901000 8006111a
	v_add_u32_e32 v29, s9, v29                                  ; 683a3a09
	v_mac_f32_e32 v33, v36, v30                                 ; 2c423d24
	v_alignbyte_b32 v14, v15, v14, v18                          ; d1cf000e 044a1d0f
	v_alignbyte_b32 v16, v16, v15, v18                          ; d1cf0010 044a1f10
	v_lshrrev_b32_e32 v29, 5, v29                               ; 203a3a85
	v_mac_f32_e32 v33, v37, v28                                 ; 2c423925
	v_cvt_f32_i32_sdwa v15, sext(v16) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e1e0af9 000b0610
	v_add_u32_e32 v29, s18, v29                                 ; 683a3a12
	v_mac_f32_e32 v33, v35, v32                                 ; 2c424123
	v_cvt_f32_i32_sdwa v32, sext(v14) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e400af9 000b060e
	v_mul_f32_e32 v7, v7, v15                                   ; 0a0e1f07
	v_cvt_f32_i32_sdwa v18, sext(v16) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e240af9 000a0610
	v_lshlrev_b32_e32 v26, 1, v29                               ; 24343a81
	v_mac_f32_e32 v7, v6, v18                                   ; 2c0e2506
	v_mov_b32_e32 v6, v27                                       ; 7e0c031b
	v_lshl_add_u32 v29, v29, 5, v26                             ; d1fd001d 04690b1d
	v_add_u32_e32 v28, 2, v29                                   ; 68383a82
	v_add_u32_e32 v30, v28, v31                                 ; 683c3f1c
	v_and_b32_e32 v28, -4, v28                                  ; 263838c4
	v_add_u32_e32 v28, v28, v31                                 ; 68383f1c
	buffer_load_dwordx3 v[26:28], v28, s[24:27], 0 offen        ; e0581000 80061a1c
	buffer_load_short_d16 v15, v29, s[24:27], 0 offen           ; e0901000 80060f1d
	v_cvt_f32_f16_sdwa v31, v9 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e3e16f9 00050609
	v_mac_f32_e32 v33, v34, v8                                  ; 2c421122
	v_cvt_f32_i32_sdwa v8, sext(v14) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e100af9 0009060e
	v_cvt_f32_i32_sdwa v18, sext(v16) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e240af9 00090610
	v_cvt_f32_i32_sdwa v16, sext(v16) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e200af9 00080610
	s_addk_i32 s1, 0x600                                        ; b7010600
	v_mac_f32_e32 v1, v33, v31                                  ; 2c023f21
	v_cvt_f32_i32_sdwa v33, sext(v14) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e420af9 000a060e
	v_mac_f32_e32 v7, v5, v18                                   ; 2c0e2505
	v_cvt_f32_i32_sdwa v14, sext(v14) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e1c0af9 0008060e
	v_add_u32_e32 v29, s1, v0                                   ; 683a0001
	v_mac_f32_e32 v7, v4, v16                                   ; 2c0e2104
	v_mov_b32_e32 v4, v34                                       ; 7e080322
	v_mov_b32_e32 v16, v6                                       ; 7e200306
	v_and_b32_e32 v31, 31, v29                                  ; 263e3a9f
	v_mac_f32_e32 v7, v36, v33                                  ; 2c0e4324
	v_mac_f32_e32 v7, v37, v32                                  ; 2c0e4125
	v_sub_u32_e32 v32, v29, v31                                 ; 6a403f1d
	v_mac_f32_e32 v7, v35, v8                                   ; 2c0e1123
	v_add3_u32 v32, v31, s4, v32                                ; d1ff0020 0480091f
	v_mov_b32_e32 v18, v7                                       ; 7e240307
	v_lshrrev_b32_e32 v32, 2, v32                               ; 20404082
	v_lshlrev_b32_e32 v32, 4, v32                               ; 24404084
	buffer_load_dwordx4 v[33:36], v32, s[28:31], 0 offen        ; e05c1000 80072120
	buffer_load_dwordx4 v[5:8], v32, s[28:31], 0 offen offset:16 ; e05c1010 80070520
	v_add_u32_e32 v32, s5, v29                                  ; 68403a05
	v_cvt_f32_f16_e32 v37, v9                                   ; 7e4a1709
	v_mac_f32_e32 v18, v4, v14                                  ; 2c241d04
	v_lshrrev_b32_e32 v32, 5, v32                               ; 20404085
	v_mad_f32 v4, v18, v37, v38                                 ; d1c10004 049a4b12
	v_add_u32_e32 v32, s18, v32                                 ; 68404012
	s_waitcnt vmcnt(5)                                          ; bf8c3f75
	v_alignbyte_b32 v23, v24, v23, v16                          ; d1cf0017 04422f18
	v_alignbyte_b32 v25, v25, v24, v16                          ; d1cf0019 04423119
	v_cvt_f32_i32_sdwa v14, sext(v23) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e1c0af9 00090617
	v_cvt_f32_i32_sdwa v9, sext(v23) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e120af9 000a0617
	v_cvt_f32_i32_sdwa v38, sext(v23) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e4c0af9 000b0617
	v_cvt_f32_i32_sdwa v23, sext(v23) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e2e0af9 00080617
	v_cvt_f32_i32_sdwa v24, sext(v25) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e300af9 00090619
	v_cvt_f32_i32_sdwa v16, sext(v25) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e200af9 000b0619
	v_cvt_f32_i32_sdwa v18, sext(v25) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e240af9 000a0619
	v_cvt_f32_i32_sdwa v25, sext(v25) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e320af9 00080619
	v_mul_f32_e32 v16, v22, v16                                 ; 0a202116
	v_mac_f32_e32 v16, v21, v18                                 ; 2c202515
	v_mac_f32_e32 v16, v20, v24                                 ; 2c203114
	v_mac_f32_e32 v16, v19, v25                                 ; 2c203313
	v_lshlrev_b32_e32 v25, 1, v32                               ; 24324081
	v_mac_f32_e32 v16, v12, v9                                  ; 2c20130c
	v_mov_b32_e32 v9, v23                                       ; 7e120317
	v_lshl_add_u32 v32, v32, 5, v25                             ; d1fd0020 04650b20
	v_mac_f32_e32 v16, v13, v38                                 ; 2c204d0d
	v_add_u32_e32 v37, 2, v32                                   ; 684a4082
	v_add_u32_e32 v38, v37, v31                                 ; 684c3f25
	v_and_b32_e32 v37, -4, v37                                  ; 264a4ac4
	v_add_u32_e32 v37, v37, v31                                 ; 684a3f25
	buffer_load_dwordx3 v[23:25], v37, s[24:27], 0 offen        ; e0581000 80061725
	buffer_load_short_d16 v18, v32, s[24:27], 0 offen           ; e0901000 80061220
	v_add_u32_e32 v29, s9, v29                                  ; 683a3a09
	v_mac_f32_e32 v16, v11, v14                                 ; 2c201d0b
	s_waitcnt vmcnt(6)                                          ; bf8c3f76
	v_cvt_f32_f16_e32 v14, v17                                  ; 7e1c1711
	s_waitcnt vmcnt(5)                                          ; bf8c3f75
	v_alignbyte_b32 v26, v27, v26, v30                          ; d1cf001a 047a351b
	v_alignbyte_b32 v28, v28, v27, v30                          ; d1cf001c 047a371c
	v_lshrrev_b32_e32 v29, 5, v29                               ; 203a3a85
	v_mac_f32_e32 v16, v10, v9                                  ; 2c20130a
	v_cvt_f32_i32_sdwa v17, sext(v26) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e220af9 000a061a
	v_cvt_f32_i32_sdwa v27, sext(v26) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e360af9 0009061a
	v_cvt_f32_i32_sdwa v30, sext(v28) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e3c0af9 000b061c
	v_add_u32_e32 v29, s18, v29                                 ; 683a3a12
	v_mul_f32_e32 v22, v22, v30                                 ; 0a2c3d16
	v_lshlrev_b32_e32 v32, 1, v29                               ; 24403a81
	v_lshl_add_u32 v29, v29, 5, v32                             ; d1fd001d 04810b1d
	v_add_u32_e32 v37, 2, v29                                   ; 684a3a82
	v_add_u32_e32 v9, v37, v31                                  ; 68123f25
	v_and_b32_e32 v37, -4, v37                                  ; 264a4ac4
	v_add_u32_e32 v37, v37, v31                                 ; 684a3f25
	v_cvt_f32_i32_sdwa v31, sext(v28) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e3e0af9 000a061c
	v_mac_f32_e32 v22, v21, v31                                 ; 2c2c3f15
	buffer_load_dwordx3 v[30:32], v37, s[24:27], 0 offen        ; e0581000 80061e25
	buffer_load_short_d16 v37, v29, s[24:27], 0 offen           ; e0901000 8006251d
	v_mac_f32_e32 v1, v16, v14                                  ; 2c021d10
	v_cvt_f32_i32_sdwa v16, sext(v26) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e200af9 000b061a
	v_cvt_f32_i32_sdwa v26, sext(v26) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e340af9 0008061a
	v_cvt_f32_i32_sdwa v14, sext(v28) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e1c0af9 0009061c
	v_cvt_f32_i32_sdwa v28, sext(v28) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e380af9 0008061c
	s_add_u32 s0, 4, s0                                         ; 80000084
	s_waitcnt vmcnt(6)                                          ; bf8c3f76
	v_cvt_f32_f16_e32 v15, v15                                  ; 7e1e170f
	v_mac_f32_e32 v22, v20, v14                                 ; 2c2c1d14
	v_mac_f32_e32 v22, v19, v28                                 ; 2c2c3913
	v_mac_f32_e32 v22, v12, v17                                 ; 2c2c230c
	v_mac_f32_e32 v22, v13, v16                                 ; 2c2c210d
	v_mac_f32_e32 v22, v11, v27                                 ; 2c2c370b
	v_mac_f32_e32 v22, v10, v26                                 ; 2c2c350a
	v_mac_f32_e32 v4, v22, v15                                  ; 2c081f16
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_alignbyte_b32 v23, v24, v23, v38                          ; d1cf0017 049a2f18
	v_alignbyte_b32 v25, v25, v24, v38                          ; d1cf0019 049a3119
	v_cvt_f32_i32_sdwa v19, sext(v23) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e260af9 00090617
	v_cvt_f32_i32_sdwa v16, sext(v23) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e200af9 000b0617
	v_cvt_f32_i32_sdwa v17, sext(v23) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e220af9 000a0617
	v_cvt_f32_i32_sdwa v23, sext(v23) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e2e0af9 00080617
	v_cvt_f32_i32_sdwa v22, sext(v25) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e2c0af9 00090619
	v_cvt_f32_i32_sdwa v20, sext(v25) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e280af9 000b0619
	v_cvt_f32_i32_sdwa v21, sext(v25) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e2a0af9 000a0619
	v_cvt_f32_i32_sdwa v25, sext(v25) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e320af9 00080619
	v_mul_f32_e32 v20, v8, v20                                  ; 0a282908
	v_mac_f32_e32 v20, v7, v21                                  ; 2c282b07
	v_mac_f32_e32 v20, v6, v22                                  ; 2c282d06
	v_mac_f32_e32 v20, v5, v25                                  ; 2c283305
	v_mac_f32_e32 v20, v35, v17                                 ; 2c282323
	v_mac_f32_e32 v20, v36, v16                                 ; 2c282124
	v_mac_f32_e32 v20, v34, v19                                 ; 2c282722
	v_mac_f32_e32 v20, v33, v23                                 ; 2c282f21
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_cvt_f32_f16_e32 v23, v18                                  ; 7e2e1712
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_alignbyte_b32 v32, v32, v31, v9                           ; d1cf0020 04263f20
	v_mac_f32_e32 v1, v20, v23                                  ; 2c022f14
	v_alignbyte_b32 v30, v31, v30, v9                           ; d1cf001e 04263d1f
	v_cvt_f32_i32_sdwa v29, sext(v32) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e3a0af9 00090620
	v_cvt_f32_i32_sdwa v27, sext(v32) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e360af9 000b0620
	v_cvt_f32_i32_sdwa v28, sext(v32) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e380af9 000a0620
	v_cvt_f32_i32_sdwa v32, sext(v32) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e400af9 00080620
	v_cvt_f32_i32_sdwa v24, sext(v30) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e300af9 000b061e
	v_cvt_f32_i32_sdwa v25, sext(v30) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e320af9 000a061e
	v_cvt_f32_i32_sdwa v26, sext(v30) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e340af9 0009061e
	v_cvt_f32_i32_sdwa v30, sext(v30) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e3c0af9 0008061e
	v_mul_f32_e32 v8, v8, v27                                   ; 0a103708
	v_mac_f32_e32 v8, v7, v28                                   ; 2c103907
	v_mac_f32_e32 v8, v6, v29                                   ; 2c103b06
	v_mac_f32_e32 v8, v5, v32                                   ; 2c104105
	v_mac_f32_e32 v8, v35, v25                                  ; 2c103323
	v_mac_f32_e32 v8, v36, v24                                  ; 2c103124
	v_mac_f32_e32 v8, v34, v26                                  ; 2c103522
	v_mac_f32_e32 v8, v33, v30                                  ; 2c103d21
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_cvt_f32_f16_e32 v30, v37                                  ; 7e3c1725
	v_mac_f32_e32 v4, v8, v30                                   ; 2c083d08
BB5:
	s_mov_b64 s[4:5], exec                                      ; be84017e
	v_cmpx_ge_u32_e32 vcc, s0, v3                               ; 7dbc0600
BB6:
	v_mov_b32_e32 v3, s0                                        ; 7e060200
	s_andn2_b64 s[4:5], s[4:5], exec                            ; 89847e04
	s_cbranch_scc1 BB10                                         ; bf85fe46
BB11:
	s_mov_b64 exec, -1                                          ; befe01c1
	v_and_b32_e32 v5, -2, v2                                    ; 260a04c2
	s_branch BB12                                               ; bf8200e3
	s_nop 0                                                     ; bf800000
	(then repeated 2 times)
BB17:
	s_mov_b64 exec, s[0:1]                                      ; befe0100
	s_mov_b32 s0, s2                                            ; be800002
	s_movk_i32 s1, 0x8000                                       ; b0018000
	s_load_dwordx8 s[24:31], s[0:1], 0x0                        ; c00e0600 00000000
	s_mul_i32 s0, s6, s17                                       ; 92001106
	v_lshl_add_u32 v6, v3, 9, v0                                ; d1fd0006 04011303
	v_and_b32_e32 v7, 31, v6                                    ; 260e0c9f
	v_sub_u32_e32 v8, v6, v7                                    ; 6a100f06
	v_add3_u32 v8, v7, s0, v8                                   ; d1ff0008 04200107
	v_lshrrev_b32_e32 v8, 2, v8                                 ; 20101082
	v_lshlrev_b32_e32 v8, 4, v8                                 ; 24101084
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_load_dwordx4 v[12:15], v8, s[28:31], 0 offen         ; e05c1000 80070c08
	buffer_load_dwordx4 v[8:11], v8, s[28:31], 0 offen offset:16 ; e05c1010 80070808
	s_mul_i32 s1, s16, s3                                       ; 92010310
	s_add_u32 s4, s1, s3                                        ; 80040301
	v_add_u32_e32 v16, s1, v6                                   ; 68200c01
	v_add_u32_e32 v6, s4, v6                                    ; 680c0c04
	v_lshrrev_b32_e32 v16, 5, v16                               ; 20202085
	v_lshrrev_b32_e32 v6, 5, v6                                 ; 200c0c85
	v_add_u32_e32 v16, s18, v16                                 ; 68202012
	v_add_u32_e32 v6, s18, v6                                   ; 680c0c12
	v_lshlrev_b32_e32 v17, 1, v16                               ; 24222081
	v_lshlrev_b32_e32 v20, 1, v6                                ; 24280c81
	v_lshl_add_u32 v16, v16, 5, v17                             ; d1fd0010 04450b10
	v_lshl_add_u32 v6, v6, 5, v20                               ; d1fd0006 04510b06
	v_add_u32_e32 v18, 2, v16                                   ; 68242082
	v_add_u32_e32 v21, 2, v6                                    ; 682a0c82
	v_add_u32_e32 v19, v18, v7                                  ; 68260f12
	v_and_b32_e32 v18, -4, v18                                  ; 262424c4
	v_add_u32_e32 v22, v21, v7                                  ; 682c0f15
	v_and_b32_e32 v21, -4, v21                                  ; 262a2ac4
	v_add_u32_e32 v18, v18, v7                                  ; 68240f12
	v_add_u32_e32 v21, v21, v7                                  ; 682a0f15
	buffer_load_dwordx3 v[23:25], v18, s[24:27], 0 offen        ; e0581000 80061712
	buffer_load_short_d16 v26, v16, s[24:27], 0 offen           ; e0901000 80061a10
	buffer_load_dwordx3 v[27:29], v21, s[24:27], 0 offen        ; e0581000 80061b15
	buffer_load_short_d16 v30, v6, s[24:27], 0 offen            ; e0901000 80061e06
	s_movk_i32 s5, 0x200                                        ; b0050200
	v_mov_b32_e32 v6, v19                                       ; 7e0c0313
	v_lshl_add_u32 v31, v3, 9, s5                               ; d1fd001f 00151303
	v_add_u32_e32 v31, v31, v0                                  ; 683e011f
	v_and_b32_e32 v32, 31, v31                                  ; 26403e9f
	v_sub_u32_e32 v33, v31, v32                                 ; 6a42411f
	v_add3_u32 v33, v32, s0, v33                                ; d1ff0021 04840120
	v_lshrrev_b32_e32 v33, 2, v33                               ; 20424282
	v_lshlrev_b32_e32 v33, 4, v33                               ; 24424284
	buffer_load_dwordx4 v[34:37], v33, s[28:31], 0 offen        ; e05c1000 80072221
	buffer_load_dwordx4 v[16:19], v33, s[28:31], 0 offen offset:16 ; e05c1010 80071021
	s_waitcnt vmcnt(5)                                          ; bf8c3f75
	v_alignbyte_b32 v23, v24, v23, v6                           ; d1cf0017 041a2f18
	v_alignbyte_b32 v25, v25, v24, v6                           ; d1cf0019 041a3119
	v_cvt_f32_i32_sdwa v20, sext(v23) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e280af9 000a0617
	v_cvt_f32_i32_sdwa v7, sext(v23) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e0e0af9 000b0617
	v_cvt_f32_i32_sdwa v21, sext(v23) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e2a0af9 00090617
	v_cvt_f32_i32_sdwa v23, sext(v23) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e2e0af9 00080617
	v_cvt_f32_i32_sdwa v33, sext(v25) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e420af9 000a0619
	v_cvt_f32_i32_sdwa v38, sext(v25) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e4c0af9 00090619
	v_cvt_f32_i32_sdwa v24, sext(v25) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e300af9 000b0619
	v_cvt_f32_i32_sdwa v25, sext(v25) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e320af9 00080619
	v_mul_f32_e32 v24, v11, v24                                 ; 0a30310b
	v_mac_f32_e32 v24, v10, v33                                 ; 2c30430a
	v_mac_f32_e32 v24, v9, v38                                  ; 2c304d09
	v_add_u32_e32 v38, s1, v31                                  ; 684c3e01
	v_mac_f32_e32 v24, v8, v25                                  ; 2c303308
	v_lshrrev_b32_e32 v38, 5, v38                               ; 204c4c85
	v_mac_f32_e32 v24, v14, v20                                 ; 2c30290e
	v_add_u32_e32 v38, s18, v38                                 ; 684c4c12
	v_mac_f32_e32 v24, v15, v7                                  ; 2c300f0f
	v_lshlrev_b32_e32 v6, 1, v38                                ; 240c4c81
	v_mac_f32_e32 v24, v13, v21                                 ; 2c302b0d
	v_mov_b32_e32 v21, v5                                       ; 7e2a0305
	v_lshl_add_u32 v38, v38, 5, v6                              ; d1fd0026 04190b26
	v_add_u32_e32 v7, 2, v38                                    ; 680e4c82
	v_add_u32_e32 v20, v7, v32                                  ; 68284107
	v_and_b32_e32 v7, -4, v7                                    ; 260e0ec4
	v_add_u32_e32 v7, v7, v32                                   ; 680e4107
	buffer_load_dwordx3 v[5:7], v7, s[24:27], 0 offen           ; e0581000 80060507
	buffer_load_short_d16 v25, v38, s[24:27], 0 offen           ; e0901000 80061926
	v_add_u32_e32 v31, s4, v31                                  ; 683e3e04
	v_mac_f32_e32 v24, v12, v23                                 ; 2c302f0c
	s_waitcnt vmcnt(6)                                          ; bf8c3f76
	v_cvt_f32_f16_e32 v23, v26                                  ; 7e2e171a
	s_waitcnt vmcnt(5)                                          ; bf8c3f75
	v_alignbyte_b32 v27, v28, v27, v22                          ; d1cf001b 045a371c
	v_alignbyte_b32 v29, v29, v28, v22                          ; d1cf001d 045a391d
	v_lshrrev_b32_e32 v31, 5, v31                               ; 203e3e85
	v_mac_f32_e32 v1, v24, v23                                  ; 2c022f18
	v_cvt_f32_i32_sdwa v24, sext(v27) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e300af9 000b061b
	v_cvt_f32_i32_sdwa v28, sext(v27) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e380af9 0009061b
	v_cvt_f32_i32_sdwa v26, sext(v27) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e340af9 000a061b
	v_cvt_f32_i32_sdwa v27, sext(v27) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e360af9 0008061b
	v_cvt_f32_i32_sdwa v23, sext(v29) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e2e0af9 0009061d
	v_cvt_f32_i32_sdwa v22, sext(v29) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e2c0af9 000a061d
	v_add_u32_e32 v31, s18, v31                                 ; 683e3e12
	v_lshlrev_b32_e32 v33, 1, v31                               ; 24423e81
	v_lshl_add_u32 v31, v31, 5, v33                             ; d1fd001f 04850b1f
	v_cvt_f32_i32_sdwa v33, sext(v29) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e420af9 000b061d
	v_add_u32_e32 v38, 2, v31                                   ; 684c3e82
	v_mul_f32_e32 v11, v11, v33                                 ; 0a16430b
	v_add_u32_e32 v33, v38, v32                                 ; 68424126
	v_and_b32_e32 v38, -4, v38                                  ; 264c4cc4
	v_mac_f32_e32 v11, v10, v22                                 ; 2c162d0a
	v_mov_b32_e32 v22, v8                                       ; 7e2c0308
	v_add_u32_e32 v38, v38, v32                                 ; 684c4126
	v_mac_f32_e32 v11, v9, v23                                  ; 2c162f09
	buffer_load_dwordx3 v[8:10], v38, s[24:27], 0 offen         ; e0581000 80060826
	buffer_load_short_d16 v23, v31, s[24:27], 0 offen           ; e0901000 8006171f
	v_cvt_f32_i32_sdwa v29, sext(v29) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e3a0af9 0008061d
	v_add_u32_e32 v3, 2, v3                                     ; 68060682
	v_mac_f32_e32 v11, v22, v29                                 ; 2c163b16
	v_mac_f32_e32 v11, v14, v26                                 ; 2c16350e
	v_mac_f32_e32 v11, v15, v24                                 ; 2c16310f
	s_waitcnt vmcnt(6)                                          ; bf8c3f76
	v_cvt_f32_f16_e32 v24, v30                                  ; 7e30171e
	v_mac_f32_e32 v11, v13, v28                                 ; 2c16390d
	v_mac_f32_e32 v11, v12, v27                                 ; 2c16370c
	v_mac_f32_e32 v4, v11, v24                                  ; 2c08310b
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_alignbyte_b32 v7, v7, v6, v20                             ; d1cf0007 04520d07
	v_alignbyte_b32 v5, v6, v5, v20                             ; d1cf0005 04520b06
	v_cvt_f32_i32_sdwa v31, sext(v7) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e3e0af9 00090607
	v_cvt_f32_i32_sdwa v30, sext(v7) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e3c0af9 000a0607
	v_cvt_f32_i32_sdwa v29, sext(v7) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e3a0af9 000b0607
	v_cvt_f32_i32_sdwa v7, sext(v7) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e0e0af9 00080607
	v_cvt_f32_i32_sdwa v28, sext(v5) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e380af9 00090605
	v_cvt_f32_i32_sdwa v27, sext(v5) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e360af9 000a0605
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_cvt_f32_f16_e32 v32, v25                                  ; 7e401719
	v_cvt_f32_i32_sdwa v26, sext(v5) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e340af9 000b0605
	v_cvt_f32_i32_sdwa v5, sext(v5) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e0a0af9 00080605
	v_mul_f32_e32 v29, v19, v29                                 ; 0a3a3b13
	v_mac_f32_e32 v29, v18, v30                                 ; 2c3a3d12
	v_mac_f32_e32 v29, v17, v31                                 ; 2c3a3f11
	v_mac_f32_e32 v29, v16, v7                                  ; 2c3a0f10
	v_mac_f32_e32 v29, v36, v27                                 ; 2c3a3724
	v_mac_f32_e32 v29, v37, v26                                 ; 2c3a3525
	v_mac_f32_e32 v29, v35, v28                                 ; 2c3a3923
	v_mac_f32_e32 v29, v34, v5                                  ; 2c3a0b22
	v_mac_f32_e32 v1, v29, v32                                  ; 2c02411d
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_alignbyte_b32 v10, v10, v9, v33                           ; d1cf000a 0486130a
	v_alignbyte_b32 v8, v9, v8, v33                             ; d1cf0008 04861109
	v_cvt_f32_i32_sdwa v9, sext(v10) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e120af9 0009060a
	v_cvt_f32_i32_sdwa v6, sext(v10) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e0c0af9 000b060a
	v_cvt_f32_i32_sdwa v7, sext(v10) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e0e0af9 000a060a
	v_cvt_f32_i32_sdwa v10, sext(v10) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e140af9 0008060a
	v_cvt_f32_i32_sdwa v33, sext(v8) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e420af9 000b0608
	v_cvt_f32_i32_sdwa v38, sext(v8) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e4c0af9 000a0608
	v_cvt_f32_i32_sdwa v5, sext(v8) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e0a0af9 00090608
	v_cvt_f32_i32_sdwa v8, sext(v8) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e100af9 00080608
	v_mul_f32_e32 v19, v19, v6                                  ; 0a260d13
	v_mac_f32_e32 v19, v18, v7                                  ; 2c260f12
	v_mac_f32_e32 v19, v17, v9                                  ; 2c261311
	v_mac_f32_e32 v19, v16, v10                                 ; 2c261510
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_cvt_f32_f16_e32 v10, v23                                  ; 7e141717
	v_mac_f32_e32 v19, v36, v38                                 ; 2c264d24
	v_mac_f32_e32 v19, v37, v33                                 ; 2c264325
	v_mac_f32_e32 v19, v35, v5                                  ; 2c260b23
	v_mov_b32_e32 v5, v21                                       ; 7e0a0315
	v_mac_f32_e32 v19, v34, v8                                  ; 2c261122
	v_mac_f32_e32 v4, v19, v10                                  ; 2c081513
BB12:
	s_mov_b64 s[0:1], exec                                      ; be80017e
	v_cmpx_ge_u32_e32 vcc, v3, v5                               ; 7dbc0b03
BB13:
	s_andn2_b64 s[0:1], s[0:1], exec                            ; 89807e00
	s_cbranch_scc1 BB17                                         ; bf85ff1c
BB18:
	s_mov_b64 exec, -1                                          ; befe01c1
	s_branch BB19                                               ; bf820072
BB24:
	s_mov_b64 exec, s[0:1]                                      ; befe0100
	s_mov_b32 s0, s2                                            ; be800002
	s_movk_i32 s1, 0x8000                                       ; b0018000
	s_load_dwordx8 s[24:31], s[0:1], 0x0                        ; c00e0600 00000000
	s_mul_i32 s0, s6, s17                                       ; 92001106
	v_lshl_add_u32 v5, v3, 9, v0                                ; d1fd0005 04011303
	v_and_b32_e32 v6, 31, v5                                    ; 260c0a9f
	v_sub_u32_e32 v7, v5, v6                                    ; 6a0e0d05
	v_add3_u32 v7, v6, s0, v7                                   ; d1ff0007 041c0106
	v_lshrrev_b32_e32 v7, 2, v7                                 ; 200e0e82
	v_lshlrev_b32_e32 v7, 4, v7                                 ; 240e0e84
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_load_dwordx4 v[8:11], v7, s[28:31], 0 offen          ; e05c1000 80070807
	buffer_load_dwordx4 v[12:15], v7, s[28:31], 0 offen offset:16 ; e05c1010 80070c07
	s_mul_i32 s1, s16, s3                                       ; 92010310
	v_add_u32_e32 v16, s1, v5                                   ; 68200a01
	s_add_u32 s1, s1, s3                                        ; 80010301
	v_lshrrev_b32_e32 v16, 5, v16                               ; 20202085
	v_add_u32_e32 v5, s1, v5                                    ; 680a0a01
	v_add_u32_e32 v16, s18, v16                                 ; 68202012
	v_lshrrev_b32_e32 v5, 5, v5                                 ; 200a0a85
	v_lshlrev_b32_e32 v17, 1, v16                               ; 24222081
	v_add_u32_e32 v5, s18, v5                                   ; 680a0a12
	v_lshl_add_u32 v16, v16, 5, v17                             ; d1fd0010 04450b10
	v_lshlrev_b32_e32 v20, 1, v5                                ; 24280a81
	v_add_u32_e32 v18, 2, v16                                   ; 68242082
	v_lshl_add_u32 v5, v5, 5, v20                               ; d1fd0005 04510b05
	v_add_u32_e32 v19, v18, v6                                  ; 68260d12
	v_and_b32_e32 v18, -4, v18                                  ; 262424c4
	v_add_u32_e32 v21, 2, v5                                    ; 682a0a82
	v_add_u32_e32 v18, v18, v6                                  ; 68240d12
	v_add_u32_e32 v22, v21, v6                                  ; 682c0d15
	v_and_b32_e32 v21, -4, v21                                  ; 262a2ac4
	v_add_u32_e32 v21, v21, v6                                  ; 682a0d15
	buffer_load_dwordx3 v[23:25], v18, s[24:27], 0 offen        ; e0581000 80061712
	buffer_load_short_d16 v26, v16, s[24:27], 0 offen           ; e0901000 80061a10
	buffer_load_dwordx3 v[27:29], v21, s[24:27], 0 offen        ; e0581000 80061b15
	buffer_load_short_d16 v30, v5, s[24:27], 0 offen            ; e0901000 80061e05
	v_add_u32_e32 v3, 1, v3                                     ; 68060681
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_alignbyte_b32 v23, v24, v23, v19                          ; d1cf0017 044e2f18
	v_alignbyte_b32 v25, v25, v24, v19                          ; d1cf0019 044e3119
	v_cvt_f32_i32_sdwa v31, sext(v23) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e3e0af9 000b0617
	v_cvt_f32_i32_sdwa v33, sext(v23) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e420af9 00090617
	v_cvt_f32_i32_sdwa v32, sext(v23) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e400af9 000a0617
	v_cvt_f32_i32_sdwa v23, sext(v23) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e2e0af9 00080617
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_cvt_f32_f16_e32 v37, v26                                  ; 7e4a171a
	v_cvt_f32_i32_sdwa v34, sext(v25) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e440af9 000b0619
	v_cvt_f32_i32_sdwa v35, sext(v25) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e460af9 000a0619
	v_cvt_f32_i32_sdwa v36, sext(v25) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e480af9 00090619
	v_cvt_f32_i32_sdwa v25, sext(v25) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e320af9 00080619
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_alignbyte_b32 v27, v28, v27, v22                          ; d1cf001b 045a371c
	v_alignbyte_b32 v29, v29, v28, v22                          ; d1cf001d 045a391d
	v_mul_f32_e32 v34, v15, v34                                 ; 0a44450f
	v_cvt_f32_i32_sdwa v38, sext(v27) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e4c0af9 000b061b
	v_cvt_f32_i32_sdwa v5, sext(v27) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e0a0af9 000a061b
	v_cvt_f32_i32_sdwa v6, sext(v27) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e0c0af9 0009061b
	v_cvt_f32_i32_sdwa v27, sext(v27) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e360af9 0008061b
	v_cvt_f32_i32_sdwa v7, sext(v29) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e0e0af9 000b061d
	v_cvt_f32_i32_sdwa v16, sext(v29) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e200af9 000a061d
	v_cvt_f32_i32_sdwa v17, sext(v29) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e220af9 0009061d
	v_mac_f32_e32 v34, v14, v35                                 ; 2c44470e
	v_cvt_f32_i32_sdwa v29, sext(v29) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e3a0af9 0008061d
	v_mul_f32_e32 v15, v15, v7                                  ; 0a1e0f0f
	v_mac_f32_e32 v34, v13, v36                                 ; 2c44490d
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_cvt_f32_f16_e32 v18, v30                                  ; 7e24171e
	v_mac_f32_e32 v15, v14, v16                                 ; 2c1e210e
	v_mac_f32_e32 v34, v12, v25                                 ; 2c44330c
	v_mac_f32_e32 v15, v13, v17                                 ; 2c1e230d
	v_mac_f32_e32 v34, v10, v32                                 ; 2c44410a
	v_mac_f32_e32 v15, v12, v29                                 ; 2c1e3b0c
	v_mac_f32_e32 v34, v11, v31                                 ; 2c443f0b
	v_mac_f32_e32 v15, v10, v5                                  ; 2c1e0b0a
	v_mac_f32_e32 v34, v9, v33                                  ; 2c444309
	v_mac_f32_e32 v15, v11, v38                                 ; 2c1e4d0b
	v_mac_f32_e32 v34, v8, v23                                  ; 2c442f08
	v_mac_f32_e32 v15, v9, v6                                   ; 2c1e0d09
	v_mac_f32_e32 v1, v34, v37                                  ; 2c024b22
	v_mac_f32_e32 v15, v8, v27                                  ; 2c1e3708
	v_mac_f32_e32 v4, v15, v18                                  ; 2c08250f
BB19:
	s_mov_b64 s[0:1], exec                                      ; be80017e
	v_cmpx_ge_u32_e32 vcc, v3, v2                               ; 7dbc0503
BB20:
	s_andn2_b64 s[0:1], s[0:1], exec                            ; 89807e00
	s_cbranch_scc1 BB24                                         ; bf85ff8a
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
	s_mov_b64 exec, 1                                           ; befe0181
	v_readlane_b32 s1, v39, 63                                  ; d2890001 00017f27
	s_mov_b64 s[4:5], exec                                      ; be84017e
BB26:
	v_mov_b32_e32 v0, s0                                        ; 7e000200
	v_mov_b32_e32 v1, s1                                        ; 7e020201
	v_mov_b32_e32 v2, 0                                         ; 7e040280
	ds_write_b64 v2, v[0:1]                                     ; d89a0000 00000002
BB31:
	s_mov_b64 exec, s[4:5]                                      ; befe0104
	s_cbranch_execz BB164                                       ; bf8804aa
BB32:
	s_and_b32 s19, s19, 63                                      ; 8613bf13
	s_cmp_lg_u32 src_scc, 0                                     ; bf0780fd
	s_cbranch_scc0 BB34                                         ; bf84000a
BB33:
	v_mov_b32_e32 v0, 0                                         ; 7e000280
	ds_read_b32 v0, v0                                          ; d86c0000 00000000
	s_mov_b32 s0, src_scc                                       ; be8000fd
	s_cmp_lt_u32 1, s19                                         ; bf0a1381
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_readfirstlane_b32 s1, v0                                  ; 7e020500
	s_cselect_b32 s1, 0x7fc00000, s1                            ; 850101ff 7fc00000
	s_branch BB35                                               ; bf820002
BB34:
	s_mov_b32 s0, src_scc                                       ; be8000fd
	s_mov_b32 s1, 0                                             ; be810080
BB35:
	s_bitcmp1_b32 s8, 0                                         ; bf0d8008
	s_cbranch_scc0 BB37                                         ; bf84000f
BB36:
	s_mov_b32 s4, s2                                            ; be840002
	s_movk_i32 s5, 0x8000                                       ; b0058000
	s_load_dwordx4 s[12:15], s[4:5], 0x30                       ; c00a0302 00000030
	s_mul_i32 s3, s7, s17                                       ; 92031107
	s_mov_b32 s4, src_scc                                       ; be8400fd
	s_add_u32 s3, s3, s16                                       ; 80031003
	s_lshl_b32 s3, s3, 2                                        ; 8e038203
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s3, s[12:15], s3                        ; c02000c6 00000003
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_mov_b32_e32 v0, s3                                        ; 7e000203
	v_add_f32_e32 v0, s1, v0                                    ; 02000001
	s_branch BB38                                               ; bf820002
BB37:
	s_mov_b32 s4, src_scc                                       ; be8400fd
	v_mov_b32_e32 v0, s1                                        ; 7e000201
BB38:
	s_bitcmp1_b32 s8, 1                                         ; bf0d8108
	s_cbranch_scc0 BB40                                         ; bf84000e
BB39:
	s_mov_b32 s8, s2                                            ; be880002
	s_movk_i32 s9, 0x8000                                       ; b0098000
	s_load_dwordx4 s[8:11], s[8:9], 0x40                        ; c00a0204 00000040
	s_mul_i32 s1, s7, s17                                       ; 92011107
	s_mov_b32 s3, src_scc                                       ; be8300fd
	s_add_u32 s1, s1, s16                                       ; 80011001
	s_lshl_b32 s1, s1, 2                                        ; 8e018201
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s1, s[8:11], s1                         ; c0200044 00000001
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v0, s1, v0                                    ; 02000001
	s_branch BB41                                               ; bf820001
BB40:
	s_mov_b32 s3, src_scc                                       ; be8300fd
BB41:
	s_mov_b32 s1, s3                                            ; be810003
	s_movk_i32 s3, 0x8000                                       ; b0038000
	s_load_dwordx4 s[8:11], s[2:3], 0x20                        ; c00a0201 00000020
	s_mul_i32 s7, s7, s17                                       ; 92071107
	s_add_u32 s7, s7, s16                                       ; 80071007
	s_lshl_b32 s7, s7, 2                                        ; 8e078207
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_store_dword v0, off, s[8:11], s7                     ; e0700000 07020080
	s_cmp_lg_i32 s0, 0                                          ; bf018000
	s_cbranch_scc0 BB43                                         ; bf840009
BB42:
	v_mov_b32_e32 v0, 0                                         ; 7e000280
	ds_read_b32 v0, v0 offset:4                                 ; d86c0004 00000000
	s_cmp_lt_u32 1, s19                                         ; bf0a1381
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_readfirstlane_b32 s0, v0                                  ; 7e000500
	s_cselect_b32 s0, 0x7fc00000, s0                            ; 850000ff 7fc00000
	s_branch BB44                                               ; bf820001
BB43:
	s_mov_b32 s0, 0                                             ; be800080
BB44:
	s_cmp_lg_i32 s4, 0                                          ; bf018004
	s_cbranch_scc0 BB46                                         ; bf84000a
BB45:
	s_load_dwordx4 s[12:15], s[2:3], 0x30                       ; c00a0301 00000030
	s_add_u32 s4, s7, 4                                         ; 80048407
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s4, s[12:15], s4                        ; c0200106 00000004
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_mov_b32_e32 v0, s4                                        ; 7e000204
	v_add_f32_e32 v0, s0, v0                                    ; 02000000
	s_branch BB47                                               ; bf820001
BB46:
	v_mov_b32_e32 v0, s0                                        ; 7e000200
BB47:
	s_cmp_lg_i32 s1, 0                                          ; bf018001
	s_cbranch_scc0 BB50                                         ; bf840008
BB48:
	s_load_dwordx4 s[0:3], s[2:3], 0x40                         ; c00a0001 00000040
	s_add_u32 s4, s7, 4                                         ; 80048407
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s4, s[0:3], s4                          ; c0200100 00000004
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v0, s4, v0                                    ; 02000004
BB50:
	s_add_u32 s7, s7, 4                                         ; 80078407
	buffer_store_dword v0, off, s[8:11], s7                     ; e0700000 07020080
	s_branch BB164                                              ; bf820446
BB56:
	s_cmp_lt_u32 s16, s4                                        ; bf0a0410
	s_cbranch_scc0 BB164                                        ; bf840444
BB57:
	s_sub_i32 s4, s4, s16                                       ; 81841004
	s_add_u32 s17, s17, s9                                      ; 80110911
	s_cmp_lg_i32 s17, 0                                         ; bf018011
	s_cbranch_scc0 BB59                                         ; bf840043
BB58:
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
	s_branch BB60                                               ; bf820001
BB59:
	s_mov_b32 s20, 0                                            ; be940080
BB60:
	s_lshr_b32 s5, s5, 5                                        ; 8f058505
	v_lshlrev_b32_e32 v0, 3, v0                                 ; 24000083
	s_and_b32 s0, s3, 0xfffffe00                                ; 8600ff03 fffffe00
	s_lshr_b32 s1, s3, 9                                        ; 8f018903
	v_mov_b32_e32 v4, 0                                         ; 7e080280
	s_mul_i32 s20, s20, s5                                      ; 92140514
	v_add_u32_e32 v1, s0, v0                                    ; 68020000
	s_mov_b32 s0, 0                                             ; be800080
	v_cmp_gt_u32_e32 vcc, s3, v1                                ; 7d980203
	v_mov_b32_e32 v1, 0                                         ; 7e020280
	v_cndmask_b32_e64 v2, 0, 1, vcc                             ; d1000002 01a90280
	v_add_u32_e32 v2, s1, v2                                    ; 68040401
	v_and_b32_e32 v3, -4, v2                                    ; 260604c4
BB61:
	s_mov_b64 s[10:11], exec                                    ; be8a017e
	v_cmpx_ge_u32_e32 vcc, s0, v3                               ; 7dbc0600
BB62:
	v_mov_b32_e32 v3, s0                                        ; 7e060200
	s_andn2_b64 s[10:11], s[10:11], exec                        ; 898a7e0a
	s_cbranch_scc0 BB91                                         ; bf8401d5
BB66:
	s_mov_b64 exec, s[10:11]                                    ; befe010a
	s_mov_b32 s10, s2                                           ; be8a0002
	s_movk_i32 s11, 0x8000                                      ; b00b8000
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_load_dwordx4 s[12:15], s[10:11], 0x10                     ; c00a0305 00000010
	s_lshl_b32 s1, s0, 9                                        ; 8e018900
	s_mul_i32 s5, s6, s17                                       ; 92051106
	s_mul_i32 s9, s16, s3                                       ; 92090310
	s_cmp_lg_i32 s4, 0                                          ; bf018004
	v_add_u32_e32 v5, s1, v0                                    ; 680a0001
	v_and_b32_e32 v6, 31, v5                                    ; 260c0a9f
	v_sub_u32_e32 v7, v5, v6                                    ; 6a0e0d05
	v_add3_u32 v7, v6, s5, v7                                   ; d1ff0007 041c0b06
	s_cbranch_scc0 BB71                                         ; bf84006a
BB67:
	s_load_dwordx4 s[24:27], s[10:11], 0x0                      ; c00a0605 00000000
	v_lshrrev_b32_e32 v7, 2, v7                                 ; 200e0e82
	v_lshlrev_b32_e32 v7, 4, v7                                 ; 240e0e84
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_load_dwordx4 v[8:11], v7, s[12:15], 0 offen          ; e05c1000 80030807
	buffer_load_dwordx4 v[12:15], v7, s[12:15], 0 offen offset:16 ; e05c1010 80030c07
	v_add_u32_e32 v7, s9, v5                                    ; 680e0a09
	v_lshrrev_b32_e32 v7, 5, v7                                 ; 200e0e85
	v_add_u32_e32 v7, s20, v7                                   ; 680e0e14
	v_lshlrev_b32_e32 v16, 1, v7                                ; 24200e81
	v_lshl_add_u32 v7, v7, 5, v16                               ; d1fd0007 04410b07
	v_add_u32_e32 v17, 2, v7                                    ; 68220e82
	v_add_u32_e32 v18, v17, v6                                  ; 68240d11
	v_and_b32_e32 v17, -4, v17                                  ; 262222c4
	v_add_u32_e32 v17, v17, v6                                  ; 68220d11
	buffer_load_dwordx3 v[19:21], v17, s[24:27], 0 offen        ; e0581000 80061311
	buffer_load_short_d16 v22, v7, s[24:27], 0 offen            ; e0901000 80061607
	s_mov_b32 s18, src_scc                                      ; be9200fd
	s_add_u32 s21, s9, s3                                       ; 80150309
	s_cmp_lt_u32 1, s4                                          ; bf0a0481
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_alignbyte_b32 v19, v20, v19, v18                          ; d1cf0013 044a2714
	v_alignbyte_b32 v21, v21, v20, v18                          ; d1cf0015 044a2915
	v_cvt_f32_i32_sdwa v23, sext(v19) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e2e0af9 000b0613
	v_cvt_f32_i32_sdwa v24, sext(v19) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e300af9 000a0613
	v_cvt_f32_i32_sdwa v25, sext(v19) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e320af9 00090613
	v_cvt_f32_i32_sdwa v19, sext(v19) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e260af9 00080613
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_cvt_f32_f16_e32 v29, v22                                  ; 7e3a1716
	v_cvt_f32_i32_sdwa v26, sext(v21) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e340af9 000b0615
	v_cvt_f32_i32_sdwa v27, sext(v21) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e360af9 000a0615
	v_cvt_f32_i32_sdwa v28, sext(v21) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e380af9 00090615
	v_cvt_f32_i32_sdwa v21, sext(v21) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e2a0af9 00080615
	v_mul_f32_e32 v26, v15, v26                                 ; 0a34350f
	v_mac_f32_e32 v26, v14, v27                                 ; 2c34370e
	v_mac_f32_e32 v26, v13, v28                                 ; 2c34390d
	v_mac_f32_e32 v26, v12, v21                                 ; 2c342b0c
	v_mac_f32_e32 v26, v10, v24                                 ; 2c34310a
	v_mac_f32_e32 v26, v11, v23                                 ; 2c342f0b
	v_mac_f32_e32 v26, v9, v25                                  ; 2c343309
	v_mac_f32_e32 v26, v8, v19                                  ; 2c342708
	v_mac_f32_e32 v1, v26, v29                                  ; 2c023b1a
	s_cbranch_scc0 BB72                                         ; bf840030
BB68:
	v_add_u32_e32 v5, s21, v5                                   ; 680a0a15
	v_lshrrev_b32_e32 v5, 5, v5                                 ; 200a0a85
	v_add_u32_e32 v5, s20, v5                                   ; 680a0a14
	v_lshlrev_b32_e32 v7, 1, v5                                 ; 240e0a81
	v_lshl_add_u32 v5, v5, 5, v7                                ; d1fd0005 041d0b05
	v_add_u32_e32 v16, 2, v5                                    ; 68200a82
	v_add_u32_e32 v17, v16, v6                                  ; 68220d10
	v_and_b32_e32 v16, -4, v16                                  ; 262020c4
	v_add_u32_e32 v16, v16, v6                                  ; 68200d10
	buffer_load_dwordx3 v[18:20], v16, s[24:27], 0 offen        ; e0581000 80061210
	buffer_load_short_d16 v21, v5, s[24:27], 0 offen            ; e0901000 80061505
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_alignbyte_b32 v18, v19, v18, v17                          ; d1cf0012 04462513
	v_alignbyte_b32 v20, v20, v19, v17                          ; d1cf0014 04462714
	v_cvt_f32_i32_sdwa v22, sext(v18) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e2c0af9 000b0612
	v_cvt_f32_i32_sdwa v23, sext(v18) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e2e0af9 000a0612
	v_cvt_f32_i32_sdwa v24, sext(v18) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e300af9 00090612
	v_cvt_f32_i32_sdwa v18, sext(v18) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e240af9 00080612
	v_cvt_f32_i32_sdwa v25, sext(v20) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e320af9 000b0614
	v_cvt_f32_i32_sdwa v26, sext(v20) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e340af9 000a0614
	v_cvt_f32_i32_sdwa v27, sext(v20) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e360af9 00090614
	v_cvt_f32_i32_sdwa v20, sext(v20) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e280af9 00080614
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_cvt_f32_f16_e32 v28, v21                                  ; 7e381715
	v_mul_f32_e32 v15, v15, v25                                 ; 0a1e330f
	v_mac_f32_e32 v15, v14, v26                                 ; 2c1e350e
	v_mac_f32_e32 v15, v13, v27                                 ; 2c1e370d
	v_mac_f32_e32 v15, v12, v20                                 ; 2c1e290c
	v_mac_f32_e32 v15, v10, v23                                 ; 2c1e2f0a
	v_mac_f32_e32 v15, v11, v22                                 ; 2c1e2d0b
	v_mac_f32_e32 v15, v9, v24                                  ; 2c1e3109
	v_mac_f32_e32 v15, v8, v18                                  ; 2c1e2508
	v_mac_f32_e32 v4, v15, v28                                  ; 2c08390f
	s_branch BB72                                               ; bf820001
BB71:
	s_mov_b32 s18, src_scc                                      ; be9200fd
BB72:
	s_add_u32 s21, s1, 0x200                                    ; 8015ff01 00000200
	s_cmp_lg_i32 s18, 0                                         ; bf018012
	v_add_u32_e32 v5, s21, v0                                   ; 680a0015
	v_and_b32_e32 v6, 31, v5                                    ; 260c0a9f
	v_sub_u32_e32 v7, v5, v6                                    ; 6a0e0d05
	v_add3_u32 v7, v6, s5, v7                                   ; d1ff0007 041c0b06
	s_cbranch_scc0 BB77                                         ; bf84006a
BB73:
	s_load_dwordx4 s[24:27], s[10:11], 0x0                      ; c00a0605 00000000
	v_lshrrev_b32_e32 v7, 2, v7                                 ; 200e0e82
	v_lshlrev_b32_e32 v7, 4, v7                                 ; 240e0e84
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_load_dwordx4 v[8:11], v7, s[12:15], 0 offen          ; e05c1000 80030807
	buffer_load_dwordx4 v[12:15], v7, s[12:15], 0 offen offset:16 ; e05c1010 80030c07
	v_add_u32_e32 v7, s9, v5                                    ; 680e0a09
	v_lshrrev_b32_e32 v7, 5, v7                                 ; 200e0e85
	v_add_u32_e32 v7, s20, v7                                   ; 680e0e14
	v_lshlrev_b32_e32 v16, 1, v7                                ; 24200e81
	v_lshl_add_u32 v7, v7, 5, v16                               ; d1fd0007 04410b07
	v_add_u32_e32 v17, 2, v7                                    ; 68220e82
	v_add_u32_e32 v18, v17, v6                                  ; 68240d11
	v_and_b32_e32 v17, -4, v17                                  ; 262222c4
	v_add_u32_e32 v17, v17, v6                                  ; 68220d11
	buffer_load_dwordx3 v[19:21], v17, s[24:27], 0 offen        ; e0581000 80061311
	buffer_load_short_d16 v22, v7, s[24:27], 0 offen            ; e0901000 80061607
	s_mov_b32 s18, src_scc                                      ; be9200fd
	s_add_u32 s21, s9, s3                                       ; 80150309
	s_cmp_lt_u32 1, s4                                          ; bf0a0481
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_alignbyte_b32 v19, v20, v19, v18                          ; d1cf0013 044a2714
	v_alignbyte_b32 v21, v21, v20, v18                          ; d1cf0015 044a2915
	v_cvt_f32_i32_sdwa v23, sext(v19) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e2e0af9 000b0613
	v_cvt_f32_i32_sdwa v24, sext(v19) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e300af9 000a0613
	v_cvt_f32_i32_sdwa v25, sext(v19) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e320af9 00090613
	v_cvt_f32_i32_sdwa v19, sext(v19) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e260af9 00080613
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_cvt_f32_f16_e32 v29, v22                                  ; 7e3a1716
	v_cvt_f32_i32_sdwa v26, sext(v21) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e340af9 000b0615
	v_cvt_f32_i32_sdwa v27, sext(v21) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e360af9 000a0615
	v_cvt_f32_i32_sdwa v28, sext(v21) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e380af9 00090615
	v_cvt_f32_i32_sdwa v21, sext(v21) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e2a0af9 00080615
	v_mul_f32_e32 v26, v15, v26                                 ; 0a34350f
	v_mac_f32_e32 v26, v14, v27                                 ; 2c34370e
	v_mac_f32_e32 v26, v13, v28                                 ; 2c34390d
	v_mac_f32_e32 v26, v12, v21                                 ; 2c342b0c
	v_mac_f32_e32 v26, v10, v24                                 ; 2c34310a
	v_mac_f32_e32 v26, v11, v23                                 ; 2c342f0b
	v_mac_f32_e32 v26, v9, v25                                  ; 2c343309
	v_mac_f32_e32 v26, v8, v19                                  ; 2c342708
	v_mac_f32_e32 v1, v26, v29                                  ; 2c023b1a
	s_cbranch_scc0 BB78                                         ; bf840030
BB74:
	v_add_u32_e32 v5, s21, v5                                   ; 680a0a15
	v_lshrrev_b32_e32 v5, 5, v5                                 ; 200a0a85
	v_add_u32_e32 v5, s20, v5                                   ; 680a0a14
	v_lshlrev_b32_e32 v7, 1, v5                                 ; 240e0a81
	v_lshl_add_u32 v5, v5, 5, v7                                ; d1fd0005 041d0b05
	v_add_u32_e32 v16, 2, v5                                    ; 68200a82
	v_add_u32_e32 v17, v16, v6                                  ; 68220d10
	v_and_b32_e32 v16, -4, v16                                  ; 262020c4
	v_add_u32_e32 v16, v16, v6                                  ; 68200d10
	buffer_load_dwordx3 v[18:20], v16, s[24:27], 0 offen        ; e0581000 80061210
	buffer_load_short_d16 v21, v5, s[24:27], 0 offen            ; e0901000 80061505
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_alignbyte_b32 v18, v19, v18, v17                          ; d1cf0012 04462513
	v_alignbyte_b32 v20, v20, v19, v17                          ; d1cf0014 04462714
	v_cvt_f32_i32_sdwa v22, sext(v18) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e2c0af9 000b0612
	v_cvt_f32_i32_sdwa v23, sext(v18) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e2e0af9 000a0612
	v_cvt_f32_i32_sdwa v24, sext(v18) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e300af9 00090612
	v_cvt_f32_i32_sdwa v18, sext(v18) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e240af9 00080612
	v_cvt_f32_i32_sdwa v25, sext(v20) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e320af9 000b0614
	v_cvt_f32_i32_sdwa v26, sext(v20) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e340af9 000a0614
	v_cvt_f32_i32_sdwa v27, sext(v20) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e360af9 00090614
	v_cvt_f32_i32_sdwa v20, sext(v20) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e280af9 00080614
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_cvt_f32_f16_e32 v28, v21                                  ; 7e381715
	v_mul_f32_e32 v15, v15, v25                                 ; 0a1e330f
	v_mac_f32_e32 v15, v14, v26                                 ; 2c1e350e
	v_mac_f32_e32 v15, v13, v27                                 ; 2c1e370d
	v_mac_f32_e32 v15, v12, v20                                 ; 2c1e290c
	v_mac_f32_e32 v15, v10, v23                                 ; 2c1e2f0a
	v_mac_f32_e32 v15, v11, v22                                 ; 2c1e2d0b
	v_mac_f32_e32 v15, v9, v24                                  ; 2c1e3109
	v_mac_f32_e32 v15, v8, v18                                  ; 2c1e2508
	v_mac_f32_e32 v4, v15, v28                                  ; 2c08390f
	s_branch BB78                                               ; bf820001
BB77:
	s_mov_b32 s18, src_scc                                      ; be9200fd
BB78:
	s_add_u32 s21, 0x400, s1                                    ; 801501ff 00000400
	s_cmp_lg_i32 s18, 0                                         ; bf018012
	v_add_u32_e32 v5, s21, v0                                   ; 680a0015
	v_and_b32_e32 v6, 31, v5                                    ; 260c0a9f
	v_sub_u32_e32 v7, v5, v6                                    ; 6a0e0d05
	v_add3_u32 v7, v6, s5, v7                                   ; d1ff0007 041c0b06
	s_cbranch_scc0 BB83                                         ; bf84006a
BB79:
	s_load_dwordx4 s[24:27], s[10:11], 0x0                      ; c00a0605 00000000
	v_lshrrev_b32_e32 v7, 2, v7                                 ; 200e0e82
	v_lshlrev_b32_e32 v7, 4, v7                                 ; 240e0e84
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_load_dwordx4 v[8:11], v7, s[12:15], 0 offen          ; e05c1000 80030807
	buffer_load_dwordx4 v[12:15], v7, s[12:15], 0 offen offset:16 ; e05c1010 80030c07
	v_add_u32_e32 v7, s9, v5                                    ; 680e0a09
	v_lshrrev_b32_e32 v7, 5, v7                                 ; 200e0e85
	v_add_u32_e32 v7, s20, v7                                   ; 680e0e14
	v_lshlrev_b32_e32 v16, 1, v7                                ; 24200e81
	v_lshl_add_u32 v7, v7, 5, v16                               ; d1fd0007 04410b07
	v_add_u32_e32 v17, 2, v7                                    ; 68220e82
	v_add_u32_e32 v18, v17, v6                                  ; 68240d11
	v_and_b32_e32 v17, -4, v17                                  ; 262222c4
	v_add_u32_e32 v17, v17, v6                                  ; 68220d11
	buffer_load_dwordx3 v[19:21], v17, s[24:27], 0 offen        ; e0581000 80061311
	buffer_load_short_d16 v22, v7, s[24:27], 0 offen            ; e0901000 80061607
	s_mov_b32 s18, src_scc                                      ; be9200fd
	s_add_u32 s21, s9, s3                                       ; 80150309
	s_cmp_lt_u32 1, s4                                          ; bf0a0481
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_alignbyte_b32 v19, v20, v19, v18                          ; d1cf0013 044a2714
	v_alignbyte_b32 v21, v21, v20, v18                          ; d1cf0015 044a2915
	v_cvt_f32_i32_sdwa v23, sext(v19) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e2e0af9 000b0613
	v_cvt_f32_i32_sdwa v24, sext(v19) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e300af9 000a0613
	v_cvt_f32_i32_sdwa v25, sext(v19) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e320af9 00090613
	v_cvt_f32_i32_sdwa v19, sext(v19) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e260af9 00080613
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_cvt_f32_f16_e32 v29, v22                                  ; 7e3a1716
	v_cvt_f32_i32_sdwa v26, sext(v21) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e340af9 000b0615
	v_cvt_f32_i32_sdwa v27, sext(v21) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e360af9 000a0615
	v_cvt_f32_i32_sdwa v28, sext(v21) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e380af9 00090615
	v_cvt_f32_i32_sdwa v21, sext(v21) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e2a0af9 00080615
	v_mul_f32_e32 v26, v15, v26                                 ; 0a34350f
	v_mac_f32_e32 v26, v14, v27                                 ; 2c34370e
	v_mac_f32_e32 v26, v13, v28                                 ; 2c34390d
	v_mac_f32_e32 v26, v12, v21                                 ; 2c342b0c
	v_mac_f32_e32 v26, v10, v24                                 ; 2c34310a
	v_mac_f32_e32 v26, v11, v23                                 ; 2c342f0b
	v_mac_f32_e32 v26, v9, v25                                  ; 2c343309
	v_mac_f32_e32 v26, v8, v19                                  ; 2c342708
	v_mac_f32_e32 v1, v26, v29                                  ; 2c023b1a
	s_cbranch_scc0 BB84                                         ; bf840030
BB80:
	v_add_u32_e32 v5, s21, v5                                   ; 680a0a15
	v_lshrrev_b32_e32 v5, 5, v5                                 ; 200a0a85
	v_add_u32_e32 v5, s20, v5                                   ; 680a0a14
	v_lshlrev_b32_e32 v7, 1, v5                                 ; 240e0a81
	v_lshl_add_u32 v5, v5, 5, v7                                ; d1fd0005 041d0b05
	v_add_u32_e32 v16, 2, v5                                    ; 68200a82
	v_add_u32_e32 v17, v16, v6                                  ; 68220d10
	v_and_b32_e32 v16, -4, v16                                  ; 262020c4
	v_add_u32_e32 v16, v16, v6                                  ; 68200d10
	buffer_load_dwordx3 v[18:20], v16, s[24:27], 0 offen        ; e0581000 80061210
	buffer_load_short_d16 v21, v5, s[24:27], 0 offen            ; e0901000 80061505
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_alignbyte_b32 v18, v19, v18, v17                          ; d1cf0012 04462513
	v_alignbyte_b32 v20, v20, v19, v17                          ; d1cf0014 04462714
	v_cvt_f32_i32_sdwa v22, sext(v18) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e2c0af9 000b0612
	v_cvt_f32_i32_sdwa v23, sext(v18) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e2e0af9 000a0612
	v_cvt_f32_i32_sdwa v24, sext(v18) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e300af9 00090612
	v_cvt_f32_i32_sdwa v18, sext(v18) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e240af9 00080612
	v_cvt_f32_i32_sdwa v25, sext(v20) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e320af9 000b0614
	v_cvt_f32_i32_sdwa v26, sext(v20) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e340af9 000a0614
	v_cvt_f32_i32_sdwa v27, sext(v20) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e360af9 00090614
	v_cvt_f32_i32_sdwa v20, sext(v20) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e280af9 00080614
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_cvt_f32_f16_e32 v28, v21                                  ; 7e381715
	v_mul_f32_e32 v15, v15, v25                                 ; 0a1e330f
	v_mac_f32_e32 v15, v14, v26                                 ; 2c1e350e
	v_mac_f32_e32 v15, v13, v27                                 ; 2c1e370d
	v_mac_f32_e32 v15, v12, v20                                 ; 2c1e290c
	v_mac_f32_e32 v15, v10, v23                                 ; 2c1e2f0a
	v_mac_f32_e32 v15, v11, v22                                 ; 2c1e2d0b
	v_mac_f32_e32 v15, v9, v24                                  ; 2c1e3109
	v_mac_f32_e32 v15, v8, v18                                  ; 2c1e2508
	v_mac_f32_e32 v4, v15, v28                                  ; 2c08390f
	s_branch BB84                                               ; bf820001
BB83:
	s_mov_b32 s18, src_scc                                      ; be9200fd
BB84:
	s_addk_i32 s1, 0x600                                        ; b7010600
	s_cmp_lg_i32 s18, 0                                         ; bf018012
	v_add_u32_e32 v5, s1, v0                                    ; 680a0001
	v_and_b32_e32 v6, 31, v5                                    ; 260c0a9f
	v_sub_u32_e32 v7, v5, v6                                    ; 6a0e0d05
	v_add3_u32 v7, v6, s5, v7                                   ; d1ff0007 041c0b06
	s_cbranch_scc0 BB90                                         ; bf840068
BB85:
	s_load_dwordx4 s[24:27], s[10:11], 0x0                      ; c00a0605 00000000
	v_lshrrev_b32_e32 v7, 2, v7                                 ; 200e0e82
	v_lshlrev_b32_e32 v7, 4, v7                                 ; 240e0e84
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_load_dwordx4 v[8:11], v7, s[12:15], 0 offen          ; e05c1000 80030807
	buffer_load_dwordx4 v[12:15], v7, s[12:15], 0 offen offset:16 ; e05c1010 80030c07
	v_add_u32_e32 v7, s9, v5                                    ; 680e0a09
	v_lshrrev_b32_e32 v7, 5, v7                                 ; 200e0e85
	v_add_u32_e32 v7, s20, v7                                   ; 680e0e14
	v_lshlrev_b32_e32 v16, 1, v7                                ; 24200e81
	v_lshl_add_u32 v7, v7, 5, v16                               ; d1fd0007 04410b07
	v_add_u32_e32 v17, 2, v7                                    ; 68220e82
	v_add_u32_e32 v18, v17, v6                                  ; 68240d11
	v_and_b32_e32 v17, -4, v17                                  ; 262222c4
	v_add_u32_e32 v17, v17, v6                                  ; 68220d11
	buffer_load_dwordx3 v[19:21], v17, s[24:27], 0 offen        ; e0581000 80061311
	buffer_load_short_d16 v22, v7, s[24:27], 0 offen            ; e0901000 80061607
	s_add_u32 s9, s9, s3                                        ; 80090309
	s_cmp_lt_u32 1, s4                                          ; bf0a0481
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_alignbyte_b32 v19, v20, v19, v18                          ; d1cf0013 044a2714
	v_alignbyte_b32 v21, v21, v20, v18                          ; d1cf0015 044a2915
	v_cvt_f32_i32_sdwa v23, sext(v19) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e2e0af9 000b0613
	v_cvt_f32_i32_sdwa v24, sext(v19) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e300af9 000a0613
	v_cvt_f32_i32_sdwa v25, sext(v19) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e320af9 00090613
	v_cvt_f32_i32_sdwa v19, sext(v19) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e260af9 00080613
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_cvt_f32_f16_e32 v29, v22                                  ; 7e3a1716
	v_cvt_f32_i32_sdwa v26, sext(v21) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e340af9 000b0615
	v_cvt_f32_i32_sdwa v27, sext(v21) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e360af9 000a0615
	v_cvt_f32_i32_sdwa v28, sext(v21) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e380af9 00090615
	v_cvt_f32_i32_sdwa v21, sext(v21) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e2a0af9 00080615
	v_mul_f32_e32 v26, v15, v26                                 ; 0a34350f
	v_mac_f32_e32 v26, v14, v27                                 ; 2c34370e
	v_mac_f32_e32 v26, v13, v28                                 ; 2c34390d
	v_mac_f32_e32 v26, v12, v21                                 ; 2c342b0c
	v_mac_f32_e32 v26, v10, v24                                 ; 2c34310a
	v_mac_f32_e32 v26, v11, v23                                 ; 2c342f0b
	v_mac_f32_e32 v26, v9, v25                                  ; 2c343309
	v_mac_f32_e32 v26, v8, v19                                  ; 2c342708
	v_mac_f32_e32 v1, v26, v29                                  ; 2c023b1a
	s_cbranch_scc0 BB90                                         ; bf84002e
BB86:
	v_add_u32_e32 v5, s9, v5                                    ; 680a0a09
	v_lshrrev_b32_e32 v5, 5, v5                                 ; 200a0a85
	v_add_u32_e32 v5, s20, v5                                   ; 680a0a14
	v_lshlrev_b32_e32 v7, 1, v5                                 ; 240e0a81
	v_lshl_add_u32 v5, v5, 5, v7                                ; d1fd0005 041d0b05
	v_add_u32_e32 v16, 2, v5                                    ; 68200a82
	v_add_u32_e32 v17, v16, v6                                  ; 68220d10
	v_and_b32_e32 v16, -4, v16                                  ; 262020c4
	v_add_u32_e32 v16, v16, v6                                  ; 68200d10
	buffer_load_dwordx3 v[18:20], v16, s[24:27], 0 offen        ; e0581000 80061210
	buffer_load_short_d16 v21, v5, s[24:27], 0 offen            ; e0901000 80061505
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_alignbyte_b32 v18, v19, v18, v17                          ; d1cf0012 04462513
	v_alignbyte_b32 v20, v20, v19, v17                          ; d1cf0014 04462714
	v_cvt_f32_i32_sdwa v22, sext(v18) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e2c0af9 000b0612
	v_cvt_f32_i32_sdwa v23, sext(v18) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e2e0af9 000a0612
	v_cvt_f32_i32_sdwa v24, sext(v18) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e300af9 00090612
	v_cvt_f32_i32_sdwa v18, sext(v18) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e240af9 00080612
	v_cvt_f32_i32_sdwa v25, sext(v20) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e320af9 000b0614
	v_cvt_f32_i32_sdwa v26, sext(v20) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e340af9 000a0614
	v_cvt_f32_i32_sdwa v27, sext(v20) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e360af9 00090614
	v_cvt_f32_i32_sdwa v20, sext(v20) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e280af9 00080614
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_cvt_f32_f16_e32 v28, v21                                  ; 7e381715
	v_mul_f32_e32 v15, v15, v25                                 ; 0a1e330f
	v_mac_f32_e32 v15, v14, v26                                 ; 2c1e350e
	v_mac_f32_e32 v15, v13, v27                                 ; 2c1e370d
	v_mac_f32_e32 v15, v12, v20                                 ; 2c1e290c
	v_mac_f32_e32 v15, v10, v23                                 ; 2c1e2f0a
	v_mac_f32_e32 v15, v11, v22                                 ; 2c1e2d0b
	v_mac_f32_e32 v15, v9, v24                                  ; 2c1e3109
	v_mac_f32_e32 v15, v8, v18                                  ; 2c1e2508
	v_mac_f32_e32 v4, v15, v28                                  ; 2c08390f
BB90:
	s_add_u32 s0, 4, s0                                         ; 80000084
	s_branch BB61                                               ; bf82fe26
BB91:
	s_mov_b64 exec, -1                                          ; befe01c1
	v_and_b32_e32 v5, -2, v2                                    ; 260a04c2
	s_nop 0                                                     ; bf800000
	(then repeated 1 times)
BB92:
	s_mov_b64 s[0:1], exec                                      ; be80017e
	v_cmpx_ge_u32_e32 vcc, v3, v5                               ; 7dbc0b03
BB93:
	s_andn2_b64 s[0:1], s[0:1], exec                            ; 89807e00
	s_cbranch_scc0 BB110                                        ; bf8400ef
BB97:
	s_mov_b64 exec, s[0:1]                                      ; befe0100
	s_mov_b32 s0, s2                                            ; be800002
	s_movk_i32 s1, 0x8000                                       ; b0018000
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_load_dwordx4 s[12:15], s[0:1], 0x10                       ; c00a0300 00000010
	s_mul_i32 s5, s6, s17                                       ; 92051106
	s_mul_i32 s9, s16, s3                                       ; 92090310
	s_cmp_lg_i32 s4, 0                                          ; bf018004
	v_lshl_add_u32 v6, v3, 9, v0                                ; d1fd0006 04011303
	v_and_b32_e32 v7, 31, v6                                    ; 260e0c9f
	v_sub_u32_e32 v8, v6, v7                                    ; 6a100f06
	v_add3_u32 v8, v7, s5, v8                                   ; d1ff0008 04200b07
	s_cbranch_scc0 BB102                                        ; bf84006a
BB98:
	s_load_dwordx4 s[24:27], s[0:1], 0x0                        ; c00a0600 00000000
	v_lshrrev_b32_e32 v8, 2, v8                                 ; 20101082
	v_lshlrev_b32_e32 v8, 4, v8                                 ; 24101084
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_load_dwordx4 v[12:15], v8, s[12:15], 0 offen         ; e05c1000 80030c08
	buffer_load_dwordx4 v[8:11], v8, s[12:15], 0 offen offset:16 ; e05c1010 80030808
	v_add_u32_e32 v16, s9, v6                                   ; 68200c09
	v_lshrrev_b32_e32 v16, 5, v16                               ; 20202085
	v_add_u32_e32 v16, s20, v16                                 ; 68202014
	v_lshlrev_b32_e32 v17, 1, v16                               ; 24222081
	v_lshl_add_u32 v16, v16, 5, v17                             ; d1fd0010 04450b10
	v_add_u32_e32 v18, 2, v16                                   ; 68242082
	v_add_u32_e32 v19, v18, v7                                  ; 68260f12
	v_and_b32_e32 v18, -4, v18                                  ; 262424c4
	v_add_u32_e32 v18, v18, v7                                  ; 68240f12
	buffer_load_dwordx3 v[20:22], v18, s[24:27], 0 offen        ; e0581000 80061412
	buffer_load_short_d16 v23, v16, s[24:27], 0 offen           ; e0901000 80061710
	s_mov_b32 s10, src_scc                                      ; be8a00fd
	s_add_u32 s11, s9, s3                                       ; 800b0309
	s_cmp_lt_u32 1, s4                                          ; bf0a0481
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_alignbyte_b32 v20, v21, v20, v19                          ; d1cf0014 044e2915
	v_alignbyte_b32 v22, v22, v21, v19                          ; d1cf0016 044e2b16
	v_cvt_f32_i32_sdwa v24, sext(v20) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e300af9 000b0614
	v_cvt_f32_i32_sdwa v25, sext(v20) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e320af9 000a0614
	v_cvt_f32_i32_sdwa v26, sext(v20) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e340af9 00090614
	v_cvt_f32_i32_sdwa v20, sext(v20) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e280af9 00080614
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_cvt_f32_f16_e32 v30, v23                                  ; 7e3c1717
	v_cvt_f32_i32_sdwa v27, sext(v22) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e360af9 000b0616
	v_cvt_f32_i32_sdwa v28, sext(v22) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e380af9 000a0616
	v_cvt_f32_i32_sdwa v29, sext(v22) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e3a0af9 00090616
	v_cvt_f32_i32_sdwa v22, sext(v22) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e2c0af9 00080616
	v_mul_f32_e32 v27, v11, v27                                 ; 0a36370b
	v_mac_f32_e32 v27, v10, v28                                 ; 2c36390a
	v_mac_f32_e32 v27, v9, v29                                  ; 2c363b09
	v_mac_f32_e32 v27, v8, v22                                  ; 2c362d08
	v_mac_f32_e32 v27, v14, v25                                 ; 2c36330e
	v_mac_f32_e32 v27, v15, v24                                 ; 2c36310f
	v_mac_f32_e32 v27, v13, v26                                 ; 2c36350d
	v_mac_f32_e32 v27, v12, v20                                 ; 2c36290c
	v_mac_f32_e32 v1, v27, v30                                  ; 2c023d1b
	s_cbranch_scc0 BB103                                        ; bf840030
BB99:
	v_add_u32_e32 v6, s11, v6                                   ; 680c0c0b
	v_lshrrev_b32_e32 v6, 5, v6                                 ; 200c0c85
	v_add_u32_e32 v6, s20, v6                                   ; 680c0c14
	v_lshlrev_b32_e32 v16, 1, v6                                ; 24200c81
	v_lshl_add_u32 v6, v6, 5, v16                               ; d1fd0006 04410b06
	v_add_u32_e32 v17, 2, v6                                    ; 68220c82
	v_add_u32_e32 v18, v17, v7                                  ; 68240f11
	v_and_b32_e32 v17, -4, v17                                  ; 262222c4
	v_add_u32_e32 v17, v17, v7                                  ; 68220f11
	buffer_load_dwordx3 v[19:21], v17, s[24:27], 0 offen        ; e0581000 80061311
	buffer_load_short_d16 v22, v6, s[24:27], 0 offen            ; e0901000 80061606
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_alignbyte_b32 v19, v20, v19, v18                          ; d1cf0013 044a2714
	v_alignbyte_b32 v21, v21, v20, v18                          ; d1cf0015 044a2915
	v_cvt_f32_i32_sdwa v23, sext(v19) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e2e0af9 000b0613
	v_cvt_f32_i32_sdwa v24, sext(v19) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e300af9 000a0613
	v_cvt_f32_i32_sdwa v25, sext(v19) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e320af9 00090613
	v_cvt_f32_i32_sdwa v19, sext(v19) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e260af9 00080613
	v_cvt_f32_i32_sdwa v26, sext(v21) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e340af9 000b0615
	v_cvt_f32_i32_sdwa v27, sext(v21) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e360af9 000a0615
	v_cvt_f32_i32_sdwa v28, sext(v21) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e380af9 00090615
	v_cvt_f32_i32_sdwa v21, sext(v21) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e2a0af9 00080615
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_cvt_f32_f16_e32 v29, v22                                  ; 7e3a1716
	v_mul_f32_e32 v11, v11, v26                                 ; 0a16350b
	v_mac_f32_e32 v11, v10, v27                                 ; 2c16370a
	v_mac_f32_e32 v11, v9, v28                                  ; 2c163909
	v_mac_f32_e32 v11, v8, v21                                  ; 2c162b08
	v_mac_f32_e32 v11, v14, v24                                 ; 2c16310e
	v_mac_f32_e32 v11, v15, v23                                 ; 2c162f0f
	v_mac_f32_e32 v11, v13, v25                                 ; 2c16330d
	v_mac_f32_e32 v11, v12, v19                                 ; 2c16270c
	v_mac_f32_e32 v4, v11, v29                                  ; 2c083b0b
	s_branch BB103                                              ; bf820001
BB102:
	s_mov_b32 s10, src_scc                                      ; be8a00fd
BB103:
	s_movk_i32 s11, 0x200                                       ; b00b0200
	s_cmp_lg_i32 s10, 0                                         ; bf01800a
	v_lshl_add_u32 v6, v3, 9, s11                               ; d1fd0006 002d1303
	v_add_u32_e32 v6, v6, v0                                    ; 680c0106
	v_and_b32_e32 v7, 31, v6                                    ; 260e0c9f
	v_sub_u32_e32 v8, v6, v7                                    ; 6a100f06
	v_add3_u32 v8, v7, s5, v8                                   ; d1ff0008 04200b07
	s_cbranch_scc0 BB109                                        ; bf840068
BB104:
	s_load_dwordx4 s[24:27], s[0:1], 0x0                        ; c00a0600 00000000
	v_lshrrev_b32_e32 v8, 2, v8                                 ; 20101082
	v_lshlrev_b32_e32 v8, 4, v8                                 ; 24101084
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_load_dwordx4 v[12:15], v8, s[12:15], 0 offen         ; e05c1000 80030c08
	buffer_load_dwordx4 v[8:11], v8, s[12:15], 0 offen offset:16 ; e05c1010 80030808
	v_add_u32_e32 v16, s9, v6                                   ; 68200c09
	v_lshrrev_b32_e32 v16, 5, v16                               ; 20202085
	v_add_u32_e32 v16, s20, v16                                 ; 68202014
	v_lshlrev_b32_e32 v17, 1, v16                               ; 24222081
	v_lshl_add_u32 v16, v16, 5, v17                             ; d1fd0010 04450b10
	v_add_u32_e32 v18, 2, v16                                   ; 68242082
	v_add_u32_e32 v19, v18, v7                                  ; 68260f12
	v_and_b32_e32 v18, -4, v18                                  ; 262424c4
	v_add_u32_e32 v18, v18, v7                                  ; 68240f12
	buffer_load_dwordx3 v[20:22], v18, s[24:27], 0 offen        ; e0581000 80061412
	buffer_load_short_d16 v23, v16, s[24:27], 0 offen           ; e0901000 80061710
	s_add_u32 s9, s9, s3                                        ; 80090309
	s_cmp_lt_u32 1, s4                                          ; bf0a0481
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_alignbyte_b32 v20, v21, v20, v19                          ; d1cf0014 044e2915
	v_alignbyte_b32 v22, v22, v21, v19                          ; d1cf0016 044e2b16
	v_cvt_f32_i32_sdwa v24, sext(v20) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e300af9 000b0614
	v_cvt_f32_i32_sdwa v25, sext(v20) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e320af9 000a0614
	v_cvt_f32_i32_sdwa v26, sext(v20) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e340af9 00090614
	v_cvt_f32_i32_sdwa v20, sext(v20) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e280af9 00080614
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_cvt_f32_f16_e32 v30, v23                                  ; 7e3c1717
	v_cvt_f32_i32_sdwa v27, sext(v22) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e360af9 000b0616
	v_cvt_f32_i32_sdwa v28, sext(v22) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e380af9 000a0616
	v_cvt_f32_i32_sdwa v29, sext(v22) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e3a0af9 00090616
	v_cvt_f32_i32_sdwa v22, sext(v22) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e2c0af9 00080616
	v_mul_f32_e32 v27, v11, v27                                 ; 0a36370b
	v_mac_f32_e32 v27, v10, v28                                 ; 2c36390a
	v_mac_f32_e32 v27, v9, v29                                  ; 2c363b09
	v_mac_f32_e32 v27, v8, v22                                  ; 2c362d08
	v_mac_f32_e32 v27, v14, v25                                 ; 2c36330e
	v_mac_f32_e32 v27, v15, v24                                 ; 2c36310f
	v_mac_f32_e32 v27, v13, v26                                 ; 2c36350d
	v_mac_f32_e32 v27, v12, v20                                 ; 2c36290c
	v_mac_f32_e32 v1, v27, v30                                  ; 2c023d1b
	s_cbranch_scc0 BB109                                        ; bf84002e
BB105:
	v_add_u32_e32 v6, s9, v6                                    ; 680c0c09
	v_lshrrev_b32_e32 v6, 5, v6                                 ; 200c0c85
	v_add_u32_e32 v6, s20, v6                                   ; 680c0c14
	v_lshlrev_b32_e32 v16, 1, v6                                ; 24200c81
	v_lshl_add_u32 v6, v6, 5, v16                               ; d1fd0006 04410b06
	v_add_u32_e32 v17, 2, v6                                    ; 68220c82
	v_add_u32_e32 v18, v17, v7                                  ; 68240f11
	v_and_b32_e32 v17, -4, v17                                  ; 262222c4
	v_add_u32_e32 v17, v17, v7                                  ; 68220f11
	buffer_load_dwordx3 v[19:21], v17, s[24:27], 0 offen        ; e0581000 80061311
	buffer_load_short_d16 v22, v6, s[24:27], 0 offen            ; e0901000 80061606
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_alignbyte_b32 v19, v20, v19, v18                          ; d1cf0013 044a2714
	v_alignbyte_b32 v21, v21, v20, v18                          ; d1cf0015 044a2915
	v_cvt_f32_i32_sdwa v23, sext(v19) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e2e0af9 000b0613
	v_cvt_f32_i32_sdwa v24, sext(v19) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e300af9 000a0613
	v_cvt_f32_i32_sdwa v25, sext(v19) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e320af9 00090613
	v_cvt_f32_i32_sdwa v19, sext(v19) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e260af9 00080613
	v_cvt_f32_i32_sdwa v26, sext(v21) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e340af9 000b0615
	v_cvt_f32_i32_sdwa v27, sext(v21) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e360af9 000a0615
	v_cvt_f32_i32_sdwa v28, sext(v21) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e380af9 00090615
	v_cvt_f32_i32_sdwa v21, sext(v21) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e2a0af9 00080615
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_cvt_f32_f16_e32 v29, v22                                  ; 7e3a1716
	v_mul_f32_e32 v11, v11, v26                                 ; 0a16350b
	v_mac_f32_e32 v11, v10, v27                                 ; 2c16370a
	v_mac_f32_e32 v11, v9, v28                                  ; 2c163909
	v_mac_f32_e32 v11, v8, v21                                  ; 2c162b08
	v_mac_f32_e32 v11, v14, v24                                 ; 2c16310e
	v_mac_f32_e32 v11, v15, v23                                 ; 2c162f0f
	v_mac_f32_e32 v11, v13, v25                                 ; 2c16330d
	v_mac_f32_e32 v11, v12, v19                                 ; 2c16270c
	v_mac_f32_e32 v4, v11, v29                                  ; 2c083b0b
BB109:
	v_add_u32_e32 v3, 2, v3                                     ; 68060682
	s_branch BB92                                               ; bf82ff0d
BB110:
	s_mov_b64 exec, -1                                          ; befe01c1
BB111:
	s_mov_b64 s[0:1], exec                                      ; be80017e
	v_cmpx_ge_u32_e32 vcc, v3, v2                               ; 7dbc0503
BB112:
	s_andn2_b64 s[0:1], s[0:1], exec                            ; 89807e00
	s_cbranch_scc0 BB123                                        ; bf84007a
BB116:
	s_mov_b64 exec, s[0:1]                                      ; befe0100
	s_mov_b32 s0, s2                                            ; be800002
	s_movk_i32 s1, 0x8000                                       ; b0018000
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_load_dwordx4 s[12:15], s[0:1], 0x10                       ; c00a0300 00000010
	s_mul_i32 s5, s6, s17                                       ; 92051106
	s_mul_i32 s9, s16, s3                                       ; 92090310
	s_cmp_lg_i32 s4, 0                                          ; bf018004
	v_lshl_add_u32 v5, v3, 9, v0                                ; d1fd0005 04011303
	v_and_b32_e32 v6, 31, v5                                    ; 260c0a9f
	v_sub_u32_e32 v7, v5, v6                                    ; 6a0e0d05
	v_add3_u32 v7, v6, s5, v7                                   ; d1ff0007 041c0b06
	s_cbranch_scc0 BB122                                        ; bf840068
BB117:
	s_load_dwordx4 s[24:27], s[0:1], 0x0                        ; c00a0600 00000000
	v_lshrrev_b32_e32 v7, 2, v7                                 ; 200e0e82
	v_lshlrev_b32_e32 v7, 4, v7                                 ; 240e0e84
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_load_dwordx4 v[8:11], v7, s[12:15], 0 offen          ; e05c1000 80030807
	buffer_load_dwordx4 v[12:15], v7, s[12:15], 0 offen offset:16 ; e05c1010 80030c07
	v_add_u32_e32 v7, s9, v5                                    ; 680e0a09
	v_lshrrev_b32_e32 v7, 5, v7                                 ; 200e0e85
	v_add_u32_e32 v7, s20, v7                                   ; 680e0e14
	v_lshlrev_b32_e32 v16, 1, v7                                ; 24200e81
	v_lshl_add_u32 v7, v7, 5, v16                               ; d1fd0007 04410b07
	v_add_u32_e32 v17, 2, v7                                    ; 68220e82
	v_add_u32_e32 v18, v17, v6                                  ; 68240d11
	v_and_b32_e32 v17, -4, v17                                  ; 262222c4
	v_add_u32_e32 v17, v17, v6                                  ; 68220d11
	buffer_load_dwordx3 v[19:21], v17, s[24:27], 0 offen        ; e0581000 80061311
	buffer_load_short_d16 v22, v7, s[24:27], 0 offen            ; e0901000 80061607
	s_add_u32 s9, s9, s3                                        ; 80090309
	s_cmp_lt_u32 1, s4                                          ; bf0a0481
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_alignbyte_b32 v19, v20, v19, v18                          ; d1cf0013 044a2714
	v_alignbyte_b32 v21, v21, v20, v18                          ; d1cf0015 044a2915
	v_cvt_f32_i32_sdwa v23, sext(v19) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e2e0af9 000b0613
	v_cvt_f32_i32_sdwa v24, sext(v19) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e300af9 000a0613
	v_cvt_f32_i32_sdwa v25, sext(v19) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e320af9 00090613
	v_cvt_f32_i32_sdwa v19, sext(v19) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e260af9 00080613
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_cvt_f32_f16_e32 v29, v22                                  ; 7e3a1716
	v_cvt_f32_i32_sdwa v26, sext(v21) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e340af9 000b0615
	v_cvt_f32_i32_sdwa v27, sext(v21) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e360af9 000a0615
	v_cvt_f32_i32_sdwa v28, sext(v21) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e380af9 00090615
	v_cvt_f32_i32_sdwa v21, sext(v21) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e2a0af9 00080615
	v_mul_f32_e32 v26, v15, v26                                 ; 0a34350f
	v_mac_f32_e32 v26, v14, v27                                 ; 2c34370e
	v_mac_f32_e32 v26, v13, v28                                 ; 2c34390d
	v_mac_f32_e32 v26, v12, v21                                 ; 2c342b0c
	v_mac_f32_e32 v26, v10, v24                                 ; 2c34310a
	v_mac_f32_e32 v26, v11, v23                                 ; 2c342f0b
	v_mac_f32_e32 v26, v9, v25                                  ; 2c343309
	v_mac_f32_e32 v26, v8, v19                                  ; 2c342708
	v_mac_f32_e32 v1, v26, v29                                  ; 2c023b1a
	s_cbranch_scc0 BB122                                        ; bf84002e
BB118:
	v_add_u32_e32 v5, s9, v5                                    ; 680a0a09
	v_lshrrev_b32_e32 v5, 5, v5                                 ; 200a0a85
	v_add_u32_e32 v5, s20, v5                                   ; 680a0a14
	v_lshlrev_b32_e32 v7, 1, v5                                 ; 240e0a81
	v_lshl_add_u32 v5, v5, 5, v7                                ; d1fd0005 041d0b05
	v_add_u32_e32 v16, 2, v5                                    ; 68200a82
	v_add_u32_e32 v17, v16, v6                                  ; 68220d10
	v_and_b32_e32 v16, -4, v16                                  ; 262020c4
	v_add_u32_e32 v16, v16, v6                                  ; 68200d10
	buffer_load_dwordx3 v[18:20], v16, s[24:27], 0 offen        ; e0581000 80061210
	buffer_load_short_d16 v21, v5, s[24:27], 0 offen            ; e0901000 80061505
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_alignbyte_b32 v18, v19, v18, v17                          ; d1cf0012 04462513
	v_alignbyte_b32 v20, v20, v19, v17                          ; d1cf0014 04462714
	v_cvt_f32_i32_sdwa v22, sext(v18) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e2c0af9 000b0612
	v_cvt_f32_i32_sdwa v23, sext(v18) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e2e0af9 000a0612
	v_cvt_f32_i32_sdwa v24, sext(v18) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e300af9 00090612
	v_cvt_f32_i32_sdwa v18, sext(v18) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e240af9 00080612
	v_cvt_f32_i32_sdwa v25, sext(v20) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e320af9 000b0614
	v_cvt_f32_i32_sdwa v26, sext(v20) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e340af9 000a0614
	v_cvt_f32_i32_sdwa v27, sext(v20) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e360af9 00090614
	v_cvt_f32_i32_sdwa v20, sext(v20) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e280af9 00080614
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_cvt_f32_f16_e32 v28, v21                                  ; 7e381715
	v_mul_f32_e32 v15, v15, v25                                 ; 0a1e330f
	v_mac_f32_e32 v15, v14, v26                                 ; 2c1e350e
	v_mac_f32_e32 v15, v13, v27                                 ; 2c1e370d
	v_mac_f32_e32 v15, v12, v20                                 ; 2c1e290c
	v_mac_f32_e32 v15, v10, v23                                 ; 2c1e2f0a
	v_mac_f32_e32 v15, v11, v22                                 ; 2c1e2d0b
	v_mac_f32_e32 v15, v9, v24                                  ; 2c1e3109
	v_mac_f32_e32 v15, v8, v18                                  ; 2c1e2508
	v_mac_f32_e32 v4, v15, v28                                  ; 2c08390f
BB122:
	v_add_u32_e32 v3, 1, v3                                     ; 68060681
	s_branch BB111                                              ; bf82ff82
BB123:
	s_mov_b64 exec, -1                                          ; befe01c1
	s_cmp_lg_i32 s4, 0                                          ; bf018004
	s_cselect_b64 s[0:1], -1, 0                                 ; 858080c1
	s_cbranch_scc0 BB129                                        ; bf840034
BB124:
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
	s_cbranch_scc0 BB127                                        ; bf840019
BB125:
	s_or_saveexec_b64 s[10:11], -1                              ; be8a21c1
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
	v_mov_b32_e32 v4, s5                                        ; 7e080205
BB127:
	v_mov_b32_e32 v1, s3                                        ; 7e020203
BB129:
	s_mov_b64 s[10:11], 1                                       ; be8a0181
	s_and_b64 exec, s[0:1], s[10:11]                            ; 86fe0a00
	s_cbranch_execz BB138                                       ; bf880008
BB130:
	v_mov_b32_e32 v0, 0                                         ; 7e000280
	ds_write_b32 v0, v1                                         ; d81a0000 00000100
	s_cmp_lt_u32 1, s4                                          ; bf0a0481
	s_cbranch_scc0 BB138                                        ; bf840003
BB131:
	v_mov_b32_e32 v0, 0                                         ; 7e000280
	ds_write_b32 v0, v4 offset:4                                ; d81a0004 00000400
BB138:
	s_mov_b64 exec, s[10:11]                                    ; befe010a
	s_cbranch_execz BB164                                       ; bf880058
BB139:
	s_min_u32 s4, 2, s4                                         ; 83840482
	s_mov_b32 s0, 0                                             ; be800080
BB140:
	s_cmp_ge_u32 s0, s4                                         ; bf090400
	s_cbranch_scc1 BB164                                        ; bf850054
BB142:
	s_cmp_lt_i32 s0, 1                                          ; bf048100
	s_cselect_b64 vcc, -1, 0                                    ; 85ea80c1
	s_and_b32 s1, s19, 63                                       ; 8601bf13
	v_cndmask_b32_e32 v0, 0, v4, vcc                            ; 00000880
	v_cndmask_b32_e64 v2, v1, 0, vcc                            ; d1000002 01a90101
	s_cbranch_scc0 BB148                                        ; bf840016
BB143:
	s_lshl_b32 s3, s0, 2                                        ; 8e038200
	v_mov_b32_e32 v0, s3                                        ; 7e000203
	ds_read_b32 v0, v0                                          ; d86c0000 00000000
	s_mov_b32 s3, 1                                             ; be830081
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_cndmask_b32_e32 v4, v0, v4, vcc                           ; 00080900
	v_cndmask_b32_e32 v1, v1, v0, vcc                           ; 00020101
	s_nop 0                                                     ; bf800000
	(then repeated 5 times)
BB144:
	s_cmp_ge_u32 s3, s1                                         ; bf090103
	s_cbranch_scc1 BB149                                        ; bf850008
BB146:
	v_mov_b32_e32 v0, 0x7fc00000                                ; 7e0002ff 7fc00000
	s_add_u32 s3, s3, 1                                         ; 80038103
	v_cndmask_b32_e32 v4, v0, v4, vcc                           ; 00080900
	v_cndmask_b32_e32 v1, v1, v0, vcc                           ; 00020101
	s_branch BB144                                              ; bf82fff8
BB148:
	v_mov_b32_e32 v1, v2                                        ; 7e020302
	v_mov_b32_e32 v4, v0                                        ; 7e080300
BB149:
	s_bitcmp1_b32 s8, 0                                         ; bf0d8008
	s_cbranch_scc0 BB152                                        ; bf840011
BB150:
	s_mov_b32 s10, s2                                           ; be8a0002
	s_movk_i32 s11, 0x8000                                      ; b00b8000
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_load_dwordx4 s[12:15], s[10:11], 0x30                     ; c00a0305 00000030
	s_mul_i32 s1, s7, s17                                       ; 92011107
	s_add_u32 s1, s1, s16                                       ; 80011001
	s_add_u32 s1, s1, s0                                        ; 80010001
	s_lshl_b32 s1, s1, 2                                        ; 8e018201
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s1, s[12:15], s1                        ; c0200046 00000001
	v_cndmask_b32_e32 v0, v4, v1, vcc                           ; 00000304
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v0, s1, v0                                    ; 02000001
	v_cndmask_b32_e32 v4, v0, v4, vcc                           ; 00080900
	v_cndmask_b32_e32 v1, v1, v0, vcc                           ; 00020101
BB152:
	s_bitcmp1_b32 s8, 1                                         ; bf0d8108
	s_cbranch_scc0 BB155                                        ; bf840011
BB153:
	s_mov_b32 s10, s2                                           ; be8a0002
	s_movk_i32 s11, 0x8000                                      ; b00b8000
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_load_dwordx4 s[12:15], s[10:11], 0x40                     ; c00a0305 00000040
	s_mul_i32 s1, s7, s17                                       ; 92011107
	s_add_u32 s1, s1, s16                                       ; 80011001
	s_add_u32 s1, s1, s0                                        ; 80010001
	s_lshl_b32 s1, s1, 2                                        ; 8e018201
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s1, s[12:15], s1                        ; c0200046 00000001
	v_cndmask_b32_e32 v0, v4, v1, vcc                           ; 00000304
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v0, s1, v0                                    ; 02000001
	v_cndmask_b32_e32 v4, v0, v4, vcc                           ; 00080900
	v_cndmask_b32_e32 v1, v1, v0, vcc                           ; 00020101
BB155:
	s_mov_b32 s10, s2                                           ; be8a0002
	s_movk_i32 s11, 0x8000                                      ; b00b8000
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_load_dwordx4 s[12:15], s[10:11], 0x20                     ; c00a0305 00000020
	s_mul_i32 s1, s7, s17                                       ; 92011107
	v_cndmask_b32_e32 v0, v4, v1, vcc                           ; 00000304
	s_add_u32 s1, s1, s16                                       ; 80011001
	s_add_u32 s1, s1, s0                                        ; 80010001
	s_lshl_b32 s1, s1, 2                                        ; 8e018201
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_store_dword v0, off, s[12:15], s1                    ; e0700000 01030080
	s_add_u32 s0, s0, 1                                         ; 80008100
	s_branch BB140                                              ; bf82ffaa
BB164:
	s_endpgm                                                    ; bf810000
