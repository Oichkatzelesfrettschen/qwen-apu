BB0:
	s_load_dword s0, s[14:15], 0x0                              ; c0020007 00000000
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_mul_i32 s0, s0, s18                                       ; 92001200
	s_add_u32 s16, s16, s0                                      ; 80100010
	s_add_u32 s1, s16, 1                                        ; 80018110
	s_cmp_ge_u32 s4, s1                                         ; bf090104
	s_cbranch_scc0 BB24                                         ; bf840137
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
	v_mov_b32_e32 v3, 0                                         ; 7e060280
	v_lshlrev_b32_e32 v1, 2, v1                                 ; 24020282
	v_lshl_add_u32 v4, v2, 5, v1                                ; d1fd0004 04050b02
	v_lshl_add_u32 v1, v2, 6, v1                                ; d1fd0001 04050d02
	s_branch BB5                                                ; bf820097
BB10:
	s_mov_b64 exec, s[0:1]                                      ; befe0100
	s_mov_b32 s0, s2                                            ; be800002
	s_movk_i32 s1, 0x8000                                       ; b0018000
	s_load_dwordx8 s[24:31], s[0:1], 0x0                        ; c00e0600 00000000
	s_mul_i32 s0, s6, s17                                       ; 92001106
	v_lshl_add_u32 v5, v0, 8, v1                                ; d1fd0005 04051100
	v_add_u32_e32 v6, s0, v5                                    ; 680c0a00
	v_add_u32_e32 v5, 0x80, v5                                  ; 680a0aff 00000080
	v_lshrrev_b32_e32 v6, 2, v6                                 ; 200c0c82
	v_add_u32_e32 v5, s0, v5                                    ; 680a0a00
	v_lshlrev_b32_e32 v6, 4, v6                                 ; 240c0c84
	v_lshrrev_b32_e32 v5, 2, v5                                 ; 200a0a82
	v_lshlrev_b32_e32 v5, 4, v5                                 ; 240a0a84
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_load_dwordx4 v[8:11], v6, s[28:31], 0 offen          ; e05c1000 80070806
	buffer_load_dwordx4 v[12:15], v6, s[28:31], 0 offen offset:128 ; e05c1080 80070c06
	buffer_load_dwordx4 v[16:19], v5, s[28:31], 0 offen         ; e05c1000 80071005
	buffer_load_dwordx4 v[20:23], v5, s[28:31], 0 offen offset:128 ; e05c1080 80071405
	s_mul_i32 s1, s16, s3                                       ; 92010310
	v_lshlrev_b32_e32 v25, 1, v2                                ; 24320481
	s_add_u32 s1, s18, s1                                       ; 80010112
	v_and_b32_e32 v27, -4, v25                                  ; 263632c4
	v_add_u32_e32 v7, s1, v0                                    ; 680e0001
	v_lshlrev_b32_e32 v24, 4, v7                                ; 24300e84
	v_lshl_add_u32 v7, v7, 7, v24                               ; d1fd0007 04610f07
	v_add_u32_e32 v26, 4, v7                                    ; 68340e84
	v_add_u32_e32 v29, 16, v7                                   ; 683a0e90
	v_add_u32_e32 v28, v26, v25                                 ; 6838331a
	v_add_u32_e32 v27, v27, v26                                 ; 6836351b
	v_add3_u32 v26, v26, 8, v25                                 ; d1ff001a 0465111a
	v_add_u32_e32 v30, v29, v4                                  ; 683c091d
	v_add3_u32 v29, v29, 64, v4                                 ; d1ff001d 0411811d
	buffer_load_dword v7, v7, s[24:27], 0 offen                 ; e0501000 80060707
	buffer_load_dwordx2 v[24:25], v27, s[24:27], 0 offen        ; e0541000 8006181b
	buffer_load_ushort v26, v26, s[24:27], 0 offen              ; e0481000 80061a1a
	buffer_load_dword v30, v30, s[24:27], 0 offen               ; e0501000 80061e1e
	buffer_load_dword v29, v29, s[24:27], 0 offen               ; e0501000 80061d1d
	s_mov_b32 s4, 0xf0f0f0f                                     ; be8400ff 0f0f0f0f
	v_add_u32_e32 v0, 4, v0                                     ; 68000084
	s_waitcnt vmcnt(8)                                          ; bf8c3f78
	v_add_f32_e32 v31, v8, v9                                   ; 023e1308
	s_waitcnt vmcnt(7)                                          ; bf8c3f77
	v_add_f32_e32 v32, v12, v13                                 ; 02401b0c
	v_add_f32_e32 v31, v31, v10                                 ; 023e151f
	s_waitcnt vmcnt(6)                                          ; bf8c3f76
	v_add_f32_e32 v33, v16, v17                                 ; 02422310
	v_add_f32_e32 v32, v32, v14                                 ; 02401d20
	s_waitcnt vmcnt(5)                                          ; bf8c3f75
	v_add_f32_e32 v34, v20, v21                                 ; 02442b14
	v_add_f32_e32 v31, v31, v11                                 ; 023e171f
	v_add_f32_e32 v33, v33, v18                                 ; 02422521
	v_add_f32_e32 v32, v32, v15                                 ; 02401f20
	v_add_f32_e32 v34, v34, v22                                 ; 02442d22
	v_add_f32_e32 v33, v33, v19                                 ; 02422721
	v_add_f32_e32 v34, v34, v23                                 ; 02442f22
	s_waitcnt vmcnt(4)                                          ; bf8c3f74
	v_cvt_f32_f16_sdwa v5, v7 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e0a16f9 00050607
	v_cvt_f32_f16_e32 v7, v7                                    ; 7e0e1707
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_alignbyte_b32 v24, v25, v24, v28                          ; d1cf0018 04723119
	v_alignbyte_b32 v25, v25, v25, v28                          ; d1cf0019 04723319
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_lshl_or_b32 v26, v26, 12, v26                             ; d200001a 0469191a
	v_mov_b32_sdwa v24, v25 dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_0 ; 7e3002f9 00041519
	v_and_b32_e32 v6, 0xc0c0c0c0, v24                           ; 260c30ff c0c0c0c0
	v_and_b32_e32 v24, 0x3f3f3f3f, v24                          ; 263030ff 3f3f3f3f
	v_lshrrev_b32_e32 v6, 2, v6                                 ; 200c0c82
	v_cvt_f32_ubyte3_e32 v25, v24                               ; 7e322918
	v_cvt_f32_ubyte1_e32 v28, v24                               ; 7e382518
	v_cvt_f32_ubyte2_e32 v27, v24                               ; 7e362718
	v_cvt_f32_ubyte0_e32 v24, v24                               ; 7e302318
	v_and_or_b32 v26, s4, v26, v6                               ; d201001a 041a3404
	v_cvt_f32_ubyte3_e32 v6, v26                                ; 7e0c291a
	v_mul_f32_e32 v34, v34, v6                                  ; 0a440d22
	v_cvt_f32_ubyte2_e32 v6, v26                                ; 7e0c271a
	v_mac_f32_e32 v34, v33, v6                                  ; 2c440d21
	v_mac_f32_e32 v34, v32, v25                                 ; 2c443320
	v_cvt_f32_ubyte1_e32 v25, v26                               ; 7e32251a
	v_cvt_f32_ubyte0_e32 v26, v26                               ; 7e34231a
	v_mac_f32_e32 v34, v31, v27                                 ; 2c44371f
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v27, s4, v30                                  ; 26363c04
	v_lshrrev_b32_e32 v30, 4, v30                               ; 203c3c84
	v_mad_f32 v3, -v5, v34, v3                                  ; d1c10003 240e4505
	v_cvt_f32_ubyte3_e32 v31, v27                               ; 7e3e291b
	v_cvt_f32_ubyte2_e32 v32, v27                               ; 7e40271b
	v_cvt_f32_ubyte1_e32 v33, v27                               ; 7e42251b
	v_cvt_f32_ubyte0_e32 v27, v27                               ; 7e36231b
	v_and_b32_e32 v30, s4, v30                                  ; 263c3c04
	v_mul_f32_e32 v11, v11, v31                                 ; 0a163f0b
	v_cvt_f32_ubyte3_e32 v34, v30                               ; 7e44291e
	v_mac_f32_e32 v11, v10, v32                                 ; 2c16410a
	v_mul_f32_e32 v15, v15, v34                                 ; 0a1e450f
	v_cvt_f32_ubyte2_e32 v34, v30                               ; 7e44271e
	v_mac_f32_e32 v11, v9, v33                                  ; 2c164309
	v_mac_f32_e32 v15, v14, v34                                 ; 2c1e450e
	v_cvt_f32_ubyte1_e32 v34, v30                               ; 7e44251e
	v_cvt_f32_ubyte0_e32 v30, v30                               ; 7e3c231e
	v_mac_f32_e32 v11, v8, v27                                  ; 2c163708
	v_mac_f32_e32 v15, v13, v34                                 ; 2c1e450d
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v34, s4, v29                                  ; 26443a04
	v_lshrrev_b32_e32 v29, 4, v29                               ; 203a3a84
	v_mac_f32_e32 v15, v12, v30                                 ; 2c1e3d0c
	v_cvt_f32_ubyte2_e32 v6, v34                                ; 7e0c2722
	v_cvt_f32_ubyte1_e32 v8, v34                                ; 7e102522
	v_cvt_f32_ubyte3_e32 v5, v34                                ; 7e0a2922
	v_cvt_f32_ubyte0_e32 v34, v34                               ; 7e442322
	v_and_b32_e32 v29, s4, v29                                  ; 263a3a04
	v_mul_f32_e32 v19, v19, v5                                  ; 0a260b13
	v_cvt_f32_ubyte2_e32 v10, v29                               ; 7e14271d
	v_cvt_f32_ubyte1_e32 v12, v29                               ; 7e18251d
	v_cvt_f32_ubyte3_e32 v9, v29                                ; 7e12291d
	v_cvt_f32_ubyte0_e32 v29, v29                               ; 7e3a231d
	v_mac_f32_e32 v19, v18, v6                                  ; 2c260d12
	v_mul_f32_e32 v23, v23, v9                                  ; 0a2e1317
	v_mac_f32_e32 v19, v17, v8                                  ; 2c261111
	v_mac_f32_e32 v23, v22, v10                                 ; 2c2e1516
	v_mac_f32_e32 v19, v16, v34                                 ; 2c264510
	v_mac_f32_e32 v23, v21, v12                                 ; 2c2e1915
	v_mac_f32_e32 v23, v20, v29                                 ; 2c2e3b14
	v_mul_f32_e32 v23, v23, v25                                 ; 0a2e3317
	v_mac_f32_e32 v23, v19, v26                                 ; 2c2e3513
	v_mac_f32_e32 v23, v15, v28                                 ; 2c2e390f
	v_mac_f32_e32 v23, v11, v24                                 ; 2c2e310b
	v_mac_f32_e32 v3, v7, v23                                   ; 2c062f07
BB5:
	s_mov_b64 s[0:1], exec                                      ; be80017e
	v_cmpx_le_u32_e32 vcc, s3, v0                               ; 7db60003
BB6:
	s_andn2_b64 s[0:1], s[0:1], exec                            ; 89807e00
	s_cbranch_scc1 BB10                                         ; bf85ff65
BB11:
	s_mov_b64 exec, -1                                          ; befe01c1
	s_or_saveexec_b64 s[4:5], -1                                ; be8421c1
	v_cndmask_b32_e64 v35, 0, v3, s[4:5]                        ; d1000023 00120680
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v35, v35, v35 quad_perm:[1,0,3,2] row_mask:0xf bank_mask:0xf ; 024646fa ff00b123
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v35, v35, v35 quad_perm:[2,3,0,1] row_mask:0xf bank_mask:0xf ; 024646fa ff004e23
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v35, v35, v35 row_half_mirror row_mask:0xf bank_mask:0xf ; 024646fa ff014123
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v35, v35, v35 row_mirror row_mask:0xf bank_mask:0xf ; 024646fa ff014023
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v35, v35, v35 row_bcast:15 row_mask:0xa bank_mask:0xf ; 024646fa af014223
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v35, v35, v35 row_bcast:31 row_mask:0xc bank_mask:0xf ; 024646fa cf014323
	s_mov_b64 exec, 1                                           ; befe0181
	v_readlane_b32 s0, v35, 63                                  ; d2890000 00017f23
BB12:
	s_bitcmp1_b32 s8, 0                                         ; bf0d8008
	s_cbranch_scc0 BB14                                         ; bf84000e
BB13:
	s_mov_b32 s4, s2                                            ; be840002
	s_movk_i32 s5, 0x8000                                       ; b0058000
	s_load_dwordx4 s[12:15], s[4:5], 0x30                       ; c00a0302 00000030
	s_mul_i32 s1, s7, s17                                       ; 92011107
	s_add_u32 s1, s1, s16                                       ; 80011001
	s_lshl_b32 s1, s1, 2                                        ; 8e018201
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s1, s[12:15], s1                        ; c0200046 00000001
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_mov_b32_e32 v0, s1                                        ; 7e000201
	v_add_f32_e32 v0, s0, v0                                    ; 02000000
	s_branch BB15                                               ; bf820001
BB14:
	v_mov_b32_e32 v0, s0                                        ; 7e000200
BB15:
	s_bitcmp1_b32 s8, 1                                         ; bf0d8108
	s_cbranch_scc0 BB18                                         ; bf84000c
BB16:
	s_mov_b32 s0, s2                                            ; be800002
	s_movk_i32 s1, 0x8000                                       ; b0018000
	s_load_dwordx4 s[8:11], s[0:1], 0x40                        ; c00a0200 00000040
	s_mul_i32 s0, s7, s17                                       ; 92001107
	s_add_u32 s0, s0, s16                                       ; 80001000
	s_lshl_b32 s0, s0, 2                                        ; 8e008200
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s0, s[8:11], s0                         ; c0200004 00000000
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v0, s0, v0                                    ; 02000000
BB18:
	s_movk_i32 s3, 0x8000                                       ; b0038000
	s_load_dwordx4 s[0:3], s[2:3], 0x20                         ; c00a0001 00000020
	s_mul_i32 s7, s7, s17                                       ; 92071107
	s_add_u32 s7, s7, s16                                       ; 80071007
	s_lshl_b32 s7, s7, 2                                        ; 8e078207
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_store_dword v0, off, s[0:3], s7                      ; e0700000 07000080
	s_branch BB56                                               ; bf820142
BB24:
	s_cmp_lt_u32 s16, s4                                        ; bf0a0410
	s_cbranch_scc0 BB56                                         ; bf840140
BB25:
	s_sub_i32 s4, s4, s16                                       ; 81841004
	s_add_u32 s17, s17, s9                                      ; 80110911
	s_cmp_lg_i32 s17, 0                                         ; bf018011
	s_cbranch_scc0 BB27                                         ; bf840043
BB26:
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
	s_branch BB28                                               ; bf820001
BB27:
	s_mov_b32 s19, 0                                            ; be930080
BB28:
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
	v_mov_b32_e32 v3, 0                                         ; 7e060280
	v_lshlrev_b32_e32 v1, 2, v1                                 ; 24020282
	v_lshl_add_u32 v4, v2, 5, v1                                ; d1fd0004 04050b02
	v_lshl_add_u32 v1, v2, 6, v1                                ; d1fd0001 04050d02
BB29:
	s_mov_b64 s[0:1], exec                                      ; be80017e
	v_cmpx_le_u32_e32 vcc, s3, v0                               ; 7db60003
BB30:
	s_andn2_b64 s[0:1], s[0:1], exec                            ; 89807e00
	s_cbranch_scc0 BB38                                         ; bf84009d
BB34:
	s_mov_b64 exec, s[0:1]                                      ; befe0100
	s_mov_b32 s0, s2                                            ; be800002
	s_movk_i32 s1, 0x8000                                       ; b0018000
	s_load_dwordx4 s[12:15], s[0:1], 0x10                       ; c00a0300 00000010
	s_mul_i32 s5, s6, s17                                       ; 92051106
	v_lshl_add_u32 v5, v0, 8, v1                                ; d1fd0005 04051100
	v_add_u32_e32 v6, s5, v5                                    ; 680c0a05
	v_add_u32_e32 v5, 0x80, v5                                  ; 680a0aff 00000080
	v_lshrrev_b32_e32 v6, 2, v6                                 ; 200c0c82
	v_add_u32_e32 v5, s5, v5                                    ; 680a0a05
	v_lshlrev_b32_e32 v6, 4, v6                                 ; 240c0c84
	v_lshrrev_b32_e32 v5, 2, v5                                 ; 200a0a82
	v_lshlrev_b32_e32 v5, 4, v5                                 ; 240a0a84
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_load_dwordx4 v[8:11], v6, s[12:15], 0 offen          ; e05c1000 80030806
	buffer_load_dwordx4 v[12:15], v6, s[12:15], 0 offen offset:128 ; e05c1080 80030c06
	buffer_load_dwordx4 v[16:19], v5, s[12:15], 0 offen         ; e05c1000 80031005
	buffer_load_dwordx4 v[20:23], v5, s[12:15], 0 offen offset:128 ; e05c1080 80031405
	s_cmp_lg_i32 s4, 0                                          ; bf018004
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_add_f32_e32 v7, v8, v9                                    ; 020e1308
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_add_f32_e32 v24, v12, v13                                 ; 02301b0c
	v_add_f32_e32 v7, v7, v10                                   ; 020e1507
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_add_f32_e32 v25, v16, v17                                 ; 02322310
	v_add_f32_e32 v24, v24, v14                                 ; 02301d18
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_add_f32_e32 v26, v20, v21                                 ; 02342b14
	v_add_f32_e32 v7, v7, v11                                   ; 020e1707
	v_add_f32_e32 v25, v25, v18                                 ; 02322519
	v_add_f32_e32 v24, v24, v15                                 ; 02301f18
	v_add_f32_e32 v26, v26, v22                                 ; 02342d1a
	v_add_f32_e32 v25, v25, v19                                 ; 02322719
	v_add_f32_e32 v26, v26, v23                                 ; 02342f1a
	s_cbranch_scc0 BB37                                         ; bf840070
BB35:
	s_load_dwordx4 s[12:15], s[0:1], 0x0                        ; c00a0300 00000000
	s_mul_i32 s0, s16, s3                                       ; 92000310
	v_lshlrev_b32_e32 v27, 1, v2                                ; 24360481
	s_add_u32 s0, s19, s0                                       ; 80000013
	v_and_b32_e32 v29, -4, v27                                  ; 263a36c4
	v_add_u32_e32 v5, s0, v0                                    ; 680a0000
	v_lshlrev_b32_e32 v6, 4, v5                                 ; 240c0a84
	v_lshl_add_u32 v5, v5, 7, v6                                ; d1fd0005 04190f05
	v_add_u32_e32 v28, 4, v5                                    ; 68380a84
	v_add_u32_e32 v31, 16, v5                                   ; 683e0a90
	v_add_u32_e32 v29, v29, v28                                 ; 683a391d
	v_add_u32_e32 v30, v28, v27                                 ; 683c371c
	v_add3_u32 v28, v28, 8, v27                                 ; d1ff001c 046d111c
	v_add_u32_e32 v32, v31, v4                                  ; 6840091f
	v_add3_u32 v31, v31, 64, v4                                 ; d1ff001f 0411811f
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_load_dword v5, v5, s[12:15], 0 offen                 ; e0501000 80030505
	buffer_load_dwordx2 v[33:34], v29, s[12:15], 0 offen        ; e0541000 8003211d
	buffer_load_ushort v28, v28, s[12:15], 0 offen              ; e0481000 80031c1c
	buffer_load_dword v32, v32, s[12:15], 0 offen               ; e0501000 80032020
	buffer_load_dword v31, v31, s[12:15], 0 offen               ; e0501000 80031f1f
	s_mov_b32 s1, 0xf0f0f0f                                     ; be8100ff 0f0f0f0f
	s_waitcnt vmcnt(4)                                          ; bf8c3f74
	v_cvt_f32_f16_sdwa v6, v5 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e0c16f9 00050605
	v_cvt_f32_f16_e32 v5, v5                                    ; 7e0a1705
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_alignbyte_b32 v33, v34, v33, v30                          ; d1cf0021 047a4322
	v_alignbyte_b32 v34, v34, v34, v30                          ; d1cf0022 047a4522
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_lshl_or_b32 v28, v28, 12, v28                             ; d200001c 0471191c
	v_mov_b32_sdwa v33, v34 dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_0 ; 7e4202f9 00041522
	v_and_b32_e32 v27, 0xc0c0c0c0, v33                          ; 263642ff c0c0c0c0
	v_and_b32_e32 v33, 0x3f3f3f3f, v33                          ; 264242ff 3f3f3f3f
	v_lshrrev_b32_e32 v27, 2, v27                               ; 20363682
	v_cvt_f32_ubyte3_e32 v29, v33                               ; 7e3a2921
	v_cvt_f32_ubyte2_e32 v30, v33                               ; 7e3c2721
	v_cvt_f32_ubyte1_e32 v34, v33                               ; 7e442521
	v_cvt_f32_ubyte0_e32 v33, v33                               ; 7e422321
	v_and_or_b32 v28, s1, v28, v27                              ; d201001c 046e3801
	v_cvt_f32_ubyte3_e32 v27, v28                               ; 7e36291c
	v_mul_f32_e32 v26, v26, v27                                 ; 0a34371a
	v_cvt_f32_ubyte2_e32 v27, v28                               ; 7e36271c
	v_mac_f32_e32 v26, v25, v27                                 ; 2c343719
	v_mac_f32_e32 v26, v24, v29                                 ; 2c343b18
	v_cvt_f32_ubyte1_e32 v29, v28                               ; 7e3a251c
	v_cvt_f32_ubyte0_e32 v28, v28                               ; 7e38231c
	v_mac_f32_e32 v26, v7, v30                                  ; 2c343d07
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v30, s1, v32                                  ; 263c4001
	v_lshrrev_b32_e32 v32, 4, v32                               ; 20404084
	v_mad_f32 v3, -v6, v26, v3                                  ; d1c10003 240e3506
	v_cvt_f32_ubyte3_e32 v6, v30                                ; 7e0c291e
	v_cvt_f32_ubyte2_e32 v7, v30                                ; 7e0e271e
	v_and_b32_e32 v32, s1, v32                                  ; 26404001
	v_mul_f32_e32 v11, v11, v6                                  ; 0a160d0b
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v27, s1, v31                                  ; 26363e01
	v_cvt_f32_ubyte3_e32 v24, v32                               ; 7e302920
	v_cvt_f32_ubyte1_e32 v26, v32                               ; 7e342520
	v_cvt_f32_ubyte2_e32 v25, v32                               ; 7e322720
	v_cvt_f32_ubyte0_e32 v32, v32                               ; 7e402320
	v_mac_f32_e32 v11, v10, v7                                  ; 2c160f0a
	v_cvt_f32_ubyte1_e32 v10, v30                               ; 7e14251e
	v_cvt_f32_ubyte0_e32 v30, v30                               ; 7e3c231e
	v_mul_f32_e32 v15, v15, v24                                 ; 0a1e310f
	v_cvt_f32_ubyte1_e32 v6, v27                                ; 7e0c251b
	v_lshrrev_b32_e32 v31, 4, v31                               ; 203e3e84
	v_mac_f32_e32 v11, v9, v10                                  ; 2c161509
	v_mac_f32_e32 v15, v14, v25                                 ; 2c1e330e
	v_and_b32_e32 v31, s1, v31                                  ; 263e3e01
	v_mac_f32_e32 v11, v8, v30                                  ; 2c163d08
	v_cvt_f32_ubyte3_e32 v30, v27                               ; 7e3c291b
	v_mac_f32_e32 v15, v13, v26                                 ; 2c1e350d
	v_cvt_f32_ubyte2_e32 v8, v31                                ; 7e10271f
	v_cvt_f32_ubyte3_e32 v7, v31                                ; 7e0e291f
	v_cvt_f32_ubyte1_e32 v9, v31                                ; 7e12251f
	v_cvt_f32_ubyte0_e32 v31, v31                               ; 7e3e231f
	v_mul_f32_e32 v19, v19, v30                                 ; 0a263d13
	v_mac_f32_e32 v15, v12, v32                                 ; 2c1e410c
	v_cvt_f32_ubyte2_e32 v32, v27                               ; 7e40271b
	v_cvt_f32_ubyte0_e32 v27, v27                               ; 7e36231b
	v_mul_f32_e32 v23, v23, v7                                  ; 0a2e0f17
	v_mac_f32_e32 v19, v18, v32                                 ; 2c264112
	v_mac_f32_e32 v23, v22, v8                                  ; 2c2e1116
	v_mac_f32_e32 v19, v17, v6                                  ; 2c260d11
	v_mac_f32_e32 v23, v21, v9                                  ; 2c2e1315
	v_mac_f32_e32 v19, v16, v27                                 ; 2c263710
	v_mac_f32_e32 v23, v20, v31                                 ; 2c2e3f14
	v_mul_f32_e32 v23, v23, v29                                 ; 0a2e3b17
	v_mac_f32_e32 v23, v19, v28                                 ; 2c2e3913
	v_mac_f32_e32 v23, v15, v34                                 ; 2c2e450f
	v_mac_f32_e32 v23, v11, v33                                 ; 2c2e430b
	v_mac_f32_e32 v3, v5, v23                                   ; 2c062f05
BB37:
	v_add_u32_e32 v0, 4, v0                                     ; 68000084
	s_branch BB29                                               ; bf82ff5f
BB38:
	s_mov_b64 exec, -1                                          ; befe01c1
	s_cmp_lg_i32 s4, 0                                          ; bf018004
	s_cselect_b64 s[0:1], -1, 0                                 ; 858080c1
	s_cbranch_scc0 BB41                                         ; bf840019
BB39:
	s_or_saveexec_b64 s[4:5], -1                                ; be8421c1
	v_cndmask_b32_e64 v35, 0, v3, s[4:5]                        ; d1000023 00120680
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v35, v35, v35 quad_perm:[1,0,3,2] row_mask:0xf bank_mask:0xf ; 024646fa ff00b123
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v35, v35, v35 quad_perm:[2,3,0,1] row_mask:0xf bank_mask:0xf ; 024646fa ff004e23
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v35, v35, v35 row_half_mirror row_mask:0xf bank_mask:0xf ; 024646fa ff014123
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v35, v35, v35 row_mirror row_mask:0xf bank_mask:0xf ; 024646fa ff014023
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v35, v35, v35 row_bcast:15 row_mask:0xa bank_mask:0xf ; 024646fa af014223
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v35, v35, v35 row_bcast:31 row_mask:0xc bank_mask:0xf ; 024646fa cf014323
	s_mov_b64 exec, s[4:5]                                      ; befe0104
	v_readlane_b32 s3, v35, 63                                  ; d2890003 00017f23
	v_mov_b32_e32 v3, s3                                        ; 7e060203
BB41:
	s_mov_b64 s[4:5], 1                                         ; be840181
	s_and_b64 exec, s[0:1], s[4:5]                              ; 86fe0400
	s_cbranch_execz BB56                                        ; bf880025
BB42:
	s_bitcmp1_b32 s8, 0                                         ; bf0d8008
	s_cbranch_scc0 BB45                                         ; bf84000c
BB43:
	s_mov_b32 s0, s2                                            ; be800002
	s_movk_i32 s1, 0x8000                                       ; b0018000
	s_load_dwordx4 s[12:15], s[0:1], 0x30                       ; c00a0300 00000030
	s_mul_i32 s0, s7, s17                                       ; 92001107
	s_add_u32 s0, s0, s16                                       ; 80001000
	s_lshl_b32 s0, s0, 2                                        ; 8e008200
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s0, s[12:15], s0                        ; c0200006 00000000
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v3, s0, v3                                    ; 02060600
BB45:
	s_bitcmp1_b32 s8, 1                                         ; bf0d8108
	s_cbranch_scc0 BB48                                         ; bf84000c
BB46:
	s_mov_b32 s0, s2                                            ; be800002
	s_movk_i32 s1, 0x8000                                       ; b0018000
	s_load_dwordx4 s[8:11], s[0:1], 0x40                        ; c00a0200 00000040
	s_mul_i32 s0, s7, s17                                       ; 92001107
	s_add_u32 s0, s0, s16                                       ; 80001000
	s_lshl_b32 s0, s0, 2                                        ; 8e008200
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s0, s[8:11], s0                         ; c0200004 00000000
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v3, s0, v3                                    ; 02060600
BB48:
	s_movk_i32 s3, 0x8000                                       ; b0038000
	s_load_dwordx4 s[0:3], s[2:3], 0x20                         ; c00a0001 00000020
	s_mul_i32 s7, s7, s17                                       ; 92071107
	s_add_u32 s7, s7, s16                                       ; 80071007
	s_lshl_b32 s7, s7, 2                                        ; 8e078207
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_store_dword v3, off, s[0:3], s7                      ; e0700000 07000380
BB56:
	s_endpgm                                                    ; bf810000
