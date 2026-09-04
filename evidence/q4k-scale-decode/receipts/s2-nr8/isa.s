BB0:
	s_load_dword s0, s[14:15], 0x0                              ; c0020007 00000000
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_mul_i32 s0, s0, s18                                       ; 92001200
	s_add_u32 s16, s16, s0                                      ; 80100010
	s_lshl_b32 s16, s16, 3                                      ; 8e108310
	s_add_u32 s1, s16, 8                                        ; 80018810
	s_cmp_ge_u32 s4, s1                                         ; bf090104
	s_cbranch_scc0 BB66                                         ; bf840559
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
	s_branch BB5                                                ; bf820330
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
	v_add_u32_e32 v48, 16, v45                                  ; 68605a90
	v_add3_u32 v47, v30, 4, v45                                 ; d1ff002f 04b5091e
	v_add_u32_e32 v49, v48, v4                                  ; 68620930
	v_add_u32_e32 v48, v48, v34                                 ; 68604530
	buffer_load_dwordx3 v[50:52], v28, s[24:27], 0 offen        ; e0581000 8006321c
	buffer_load_ushort v31, v31, s[24:27], 0 offen              ; e0481000 80061f1f
	buffer_load_dword v33, v33, s[24:27], 0 offen               ; e0501000 80062121
	buffer_load_dword v32, v32, s[24:27], 0 offen               ; e0501000 80062020
	buffer_load_dwordx3 v[53:55], v35, s[24:27], 0 offen        ; e0581000 80063523
	buffer_load_ushort v37, v37, s[24:27], 0 offen              ; e0481000 80062525
	buffer_load_dword v39, v39, s[24:27], 0 offen               ; e0501000 80062727
	buffer_load_dword v38, v38, s[24:27], 0 offen               ; e0501000 80062626
	buffer_load_dwordx3 v[56:58], v40, s[24:27], 0 offen        ; e0581000 80063828
	buffer_load_ushort v42, v42, s[24:27], 0 offen              ; e0481000 80062a2a
	buffer_load_dword v44, v44, s[24:27], 0 offen               ; e0501000 80062c2c
	buffer_load_dword v43, v43, s[24:27], 0 offen               ; e0501000 80062b2b
	buffer_load_dwordx3 v[59:61], v45, s[24:27], 0 offen        ; e0581000 80063b2d
	buffer_load_ushort v47, v47, s[24:27], 0 offen              ; e0481000 80062f2f
	buffer_load_dword v49, v49, s[24:27], 0 offen               ; e0501000 80063131
	buffer_load_dword v48, v48, s[24:27], 0 offen               ; e0501000 80063030
	s_bitreplicate_b64_b32 vcc, 0xf0f0f0f                       ; beea37ff 0f0f0f0f
	s_mov_b32 s10, 0xf0f0f0f                                    ; be8a00ff 0f0f0f0f
	s_mov_b32 s11, 0xc0c0c0c0                                   ; be8b00ff c0c0c0c0
	s_mov_b32 s12, 0x3f3f3f3f                                   ; be8c00ff 3f3f3f3f
	s_add_u32 s13, s16, 4                                       ; 800d8410
	s_mul_i32 s13, s13, s3                                      ; 920d030d
	s_add_u32 s13, s18, s13                                     ; 800d0d12
	s_waitcnt vmcnt(19)                                         ; bf8c7f73
	v_add_f32_e32 v62, v16, v17                                 ; 027c2310
	s_waitcnt vmcnt(18)                                         ; bf8c7f72
	v_add_f32_e32 v28, v20, v21                                 ; 02382b14
	v_add_f32_e32 v62, v62, v18                                 ; 027c253e
	s_waitcnt vmcnt(17)                                         ; bf8c7f71
	v_add_f32_e32 v29, v24, v25                                 ; 023a3318
	v_add_f32_e32 v28, v28, v22                                 ; 02382d1c
	s_waitcnt vmcnt(16)                                         ; bf8c7f70
	v_add_f32_e32 v35, v12, v13                                 ; 02461b0c
	v_add_f32_e32 v62, v62, v19                                 ; 027c273e
	v_add_f32_e32 v29, v29, v26                                 ; 023a351d
	v_add_f32_e32 v28, v28, v23                                 ; 02382f1c
	v_add_f32_e32 v35, v35, v14                                 ; 02461d23
	v_add_f32_e32 v29, v29, v27                                 ; 023a371d
	v_add_f32_e32 v35, v35, v15                                 ; 02461f23
	s_waitcnt vmcnt(15)                                         ; bf8c3f7f
	v_cndmask_b32_sdwa v36, v51, v51, vcc dst_sel:WORD_0 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 004866f9 06051433
	v_cndmask_b32_sdwa v36, v52, v52, vcc dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 004868f9 06051534
	s_waitcnt vmcnt(14)                                         ; bf8c3f7e
	v_lshl_or_b32 v31, v31, 12, v31                             ; d200001f 047d191f
	s_waitcnt vmcnt(13)                                         ; bf8c3f7d
	v_and_b32_e32 v41, s10, v33                                 ; 2652420a
	v_lshrrev_b32_e32 v33, 4, v33                               ; 20424284
	v_and_b32_e32 v40, s11, v36                                 ; 2650480b
	v_and_b32_e32 v36, s12, v36                                 ; 2648480c
	v_cvt_f32_ubyte3_e32 v45, v41                               ; 7e5a2929
	v_cvt_f32_ubyte1_e32 v51, v41                               ; 7e662529
	v_cvt_f32_ubyte2_e32 v46, v41                               ; 7e5c2729
	v_cvt_f32_ubyte0_e32 v41, v41                               ; 7e522329
	v_and_b32_e32 v33, s10, v33                                 ; 2642420a
	v_lshrrev_b32_e32 v40, 2, v40                               ; 20505082
	v_mul_f32_e32 v45, v19, v45                                 ; 0a5a5b13
	v_cvt_f32_ubyte3_e32 v52, v33                               ; 7e682921
	v_and_or_b32 v31, s10, v31, v40                             ; d201001f 04a23e0a
	v_cvt_f32_ubyte2_e32 v40, v33                               ; 7e502721
	v_mac_f32_e32 v45, v18, v46                                 ; 2c5a5d12
	s_waitcnt vmcnt(12)                                         ; bf8c3f7c
	v_and_b32_e32 v46, s10, v32                                 ; 265c400a
	v_mul_f32_e32 v52, v23, v52                                 ; 0a686917
	v_mac_f32_e32 v45, v17, v51                                 ; 2c5a6711
	v_cvt_f32_ubyte3_e32 v51, v46                               ; 7e66292e
	v_lshrrev_b32_e32 v32, 4, v32                               ; 20404084
	v_mac_f32_e32 v52, v22, v40                                 ; 2c685116
	v_cvt_f32_ubyte1_e32 v40, v46                               ; 7e50252e
	v_mac_f32_e32 v45, v16, v41                                 ; 2c5a5310
	v_cvt_f32_ubyte1_e32 v41, v33                               ; 7e522521
	v_cvt_f32_ubyte0_e32 v33, v33                               ; 7e422321
	v_mul_f32_e32 v51, v27, v51                                 ; 0a66671b
	v_and_b32_e32 v32, s10, v32                                 ; 2640400a
	v_mac_f32_e32 v52, v21, v41                                 ; 2c685315
	v_cvt_f32_ubyte3_e32 v41, v32                               ; 7e522920
	v_mac_f32_e32 v52, v20, v33                                 ; 2c684314
	v_cvt_f32_ubyte2_e32 v33, v46                               ; 7e42272e
	v_cvt_f32_ubyte0_e32 v46, v46                               ; 7e5c232e
	v_mul_f32_e32 v41, v15, v41                                 ; 0a52530f
	v_mac_f32_e32 v51, v26, v33                                 ; 2c66431a
	v_cvt_f32_ubyte1_e32 v33, v32                               ; 7e422520
	v_mac_f32_e32 v51, v25, v40                                 ; 2c665119
	v_cvt_f32_ubyte3_e32 v40, v31                               ; 7e50291f
	v_mac_f32_e32 v51, v24, v46                                 ; 2c665d18
	v_cvt_f32_ubyte2_e32 v46, v32                               ; 7e5c2720
	v_cvt_f32_ubyte0_e32 v32, v32                               ; 7e402320
	v_mul_f32_e32 v40, v35, v40                                 ; 0a505123
	v_mac_f32_e32 v41, v14, v46                                 ; 2c525d0e
	v_cvt_f32_ubyte2_e32 v46, v31                               ; 7e5c271f
	v_mac_f32_e32 v41, v13, v33                                 ; 2c52430d
	v_cvt_f32_ubyte2_e32 v33, v36                               ; 7e422724
	v_mac_f32_e32 v40, v29, v46                                 ; 2c505d1d
	v_cvt_f32_ubyte1_e32 v46, v31                               ; 7e5c251f
	v_cvt_f32_ubyte0_e32 v31, v31                               ; 7e3e231f
	v_mac_f32_e32 v41, v12, v32                                 ; 2c52410c
	v_cvt_f32_ubyte3_e32 v32, v36                               ; 7e402924
	v_mul_f32_e32 v41, v41, v46                                 ; 0a525d29
	v_mac_f32_e32 v40, v28, v32                                 ; 2c50411c
	v_mac_f32_e32 v41, v51, v31                                 ; 2c523f33
	v_cvt_f32_ubyte1_e32 v51, v36                               ; 7e662524
	v_cvt_f32_ubyte0_e32 v36, v36                               ; 7e482324
	v_mac_f32_e32 v40, v62, v33                                 ; 2c50433e
	v_cvt_f32_f16_sdwa v33, v50 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e4216f9 00050632
	v_mac_f32_e32 v41, v52, v51                                 ; 2c526734
	v_add_u32_e32 v52, s13, v0                                  ; 6868000d
	v_mad_f32 v3, -v33, v40, v3                                 ; d1c10003 240e5121
	v_mac_f32_e32 v41, v45, v36                                 ; 2c52492d
	v_lshlrev_b32_e32 v31, 4, v52                               ; 243e6884
	v_lshl_add_u32 v52, v52, 7, v31                             ; d1fd0034 047d0f34
	v_add3_u32 v32, v30, 4, v52                                 ; d1ff0020 04d1091e
	v_add_u32_e32 v36, 16, v52                                  ; 68486890
	v_mov_b32_e32 v45, v32                                      ; 7e5a0320
	v_add_u32_e32 v40, v36, v4                                  ; 68500924
	v_add_u32_e32 v36, v36, v34                                 ; 68484524
	buffer_load_dwordx3 v[31:33], v52, s[24:27], 0 offen        ; e0581000 80061f34
	buffer_load_ushort v45, v45, s[24:27], 0 offen              ; e0481000 80062d2d
	buffer_load_dword v40, v40, s[24:27], 0 offen               ; e0501000 80062828
	buffer_load_dword v36, v36, s[24:27], 0 offen               ; e0501000 80062424
	v_cvt_f32_f16_e32 v50, v50                                  ; 7e641732
	s_add_u32 s14, s16, 5                                       ; 800e8510
	s_waitcnt vmcnt(15)                                         ; bf8c3f7f
	v_cndmask_b32_sdwa v46, v54, v54, vcc dst_sel:WORD_0 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 005c6cf9 06051436
	v_cndmask_b32_sdwa v46, v55, v55, vcc dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 005c6ef9 06051537
	s_waitcnt vmcnt(14)                                         ; bf8c3f7e
	v_lshl_or_b32 v37, v37, 12, v37                             ; d2000025 04951925
	s_waitcnt vmcnt(13)                                         ; bf8c3f7d
	v_and_b32_e32 v51, s10, v39                                 ; 26664e0a
	v_mac_f32_e32 v3, v50, v41                                  ; 2c065332
	s_mul_i32 s14, s14, s3                                      ; 920e030e
	v_and_b32_e32 v50, s11, v46                                 ; 26645c0b
	v_and_b32_e32 v46, s12, v46                                 ; 265c5c0c
	v_lshrrev_b32_e32 v39, 4, v39                               ; 204e4e84
	v_cvt_f32_ubyte1_e32 v55, v51                               ; 7e6e2533
	v_cvt_f32_ubyte2_e32 v54, v51                               ; 7e6c2733
	v_cvt_f32_ubyte3_e32 v52, v51                               ; 7e682933
	v_cvt_f32_ubyte0_e32 v51, v51                               ; 7e662333
	s_add_u32 s14, s18, s14                                     ; 800e0e12
	v_lshrrev_b32_e32 v50, 2, v50                               ; 20646482
	v_and_b32_e32 v39, s10, v39                                 ; 264e4e0a
	v_mul_f32_e32 v52, v19, v52                                 ; 0a686913
	v_and_or_b32 v37, s10, v37, v50                             ; d2010025 04ca4a0a
	v_cvt_f32_ubyte2_e32 v50, v39                               ; 7e642727
	v_cvt_f32_ubyte3_e32 v41, v39                               ; 7e522927
	v_mac_f32_e32 v52, v18, v54                                 ; 2c686d12
	s_waitcnt vmcnt(12)                                         ; bf8c3f7c
	v_and_b32_e32 v54, s10, v38                                 ; 266c4c0a
	v_mul_f32_e32 v41, v23, v41                                 ; 0a525317
	v_mac_f32_e32 v52, v17, v55                                 ; 2c686f11
	v_lshrrev_b32_e32 v38, 4, v38                               ; 204c4c84
	v_cvt_f32_ubyte3_e32 v55, v54                               ; 7e6e2936
	v_mac_f32_e32 v41, v22, v50                                 ; 2c526516
	v_cvt_f32_ubyte1_e32 v50, v54                               ; 7e642536
	v_mac_f32_e32 v52, v16, v51                                 ; 2c686710
	v_cvt_f32_ubyte1_e32 v51, v39                               ; 7e662527
	v_cvt_f32_ubyte0_e32 v39, v39                               ; 7e4e2327
	v_and_b32_e32 v38, s10, v38                                 ; 264c4c0a
	v_mul_f32_e32 v55, v27, v55                                 ; 0a6e6f1b
	v_mac_f32_e32 v41, v21, v51                                 ; 2c526715
	v_cvt_f32_ubyte3_e32 v51, v38                               ; 7e662926
	v_mac_f32_e32 v41, v20, v39                                 ; 2c524f14
	v_cvt_f32_ubyte2_e32 v39, v54                               ; 7e4e2736
	v_cvt_f32_ubyte0_e32 v54, v54                               ; 7e6c2336
	v_mul_f32_e32 v51, v15, v51                                 ; 0a66670f
	v_mac_f32_e32 v55, v26, v39                                 ; 2c6e4f1a
	v_cvt_f32_ubyte1_e32 v39, v38                               ; 7e4e2526
	v_mac_f32_e32 v55, v25, v50                                 ; 2c6e6519
	v_cvt_f32_ubyte3_e32 v50, v37                               ; 7e642925
	v_mac_f32_e32 v55, v24, v54                                 ; 2c6e6d18
	v_cvt_f32_ubyte2_e32 v54, v38                               ; 7e6c2726
	v_cvt_f32_ubyte0_e32 v38, v38                               ; 7e4c2326
	v_mul_f32_e32 v50, v35, v50                                 ; 0a646523
	v_mac_f32_e32 v51, v14, v54                                 ; 2c666d0e
	v_cvt_f32_ubyte2_e32 v54, v37                               ; 7e6c2725
	v_mac_f32_e32 v51, v13, v39                                 ; 2c664f0d
	v_cvt_f32_ubyte2_e32 v39, v46                               ; 7e4e272e
	v_mac_f32_e32 v50, v29, v54                                 ; 2c646d1d
	v_cvt_f32_ubyte1_e32 v54, v37                               ; 7e6c2525
	v_cvt_f32_ubyte0_e32 v37, v37                               ; 7e4a2325
	v_mac_f32_e32 v51, v12, v38                                 ; 2c664d0c
	v_cvt_f32_ubyte3_e32 v38, v46                               ; 7e4c292e
	s_waitcnt vmcnt(10)                                         ; bf8c3f7a
	v_lshl_or_b32 v42, v42, 12, v42                             ; d200002a 04a9192a
	v_mul_f32_e32 v51, v51, v54                                 ; 0a666d33
	v_mac_f32_e32 v50, v28, v38                                 ; 2c644d1c
	v_cndmask_b32_sdwa v38, v57, v57, vcc dst_sel:WORD_0 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 004c72f9 06051439
	v_cndmask_b32_sdwa v38, v58, v58, vcc dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 004c74f9 0605153a
	v_mac_f32_e32 v51, v55, v37                                 ; 2c664b37
	v_cvt_f32_ubyte1_e32 v55, v46                               ; 7e6e252e
	v_cvt_f32_ubyte0_e32 v46, v46                               ; 7e5c232e
	v_cvt_f32_f16_sdwa v37, v53 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e4a16f9 00050635
	v_cvt_f32_f16_e32 v53, v53                                  ; 7e6a1735
	v_mac_f32_e32 v50, v62, v39                                 ; 2c644f3e
	v_mac_f32_e32 v51, v41, v55                                 ; 2c666f29
	v_mad_f32 v5, -v37, v50, v5                                 ; d1c10005 24166525
	v_mac_f32_e32 v51, v52, v46                                 ; 2c665d34
	v_add_u32_e32 v46, s14, v0                                  ; 685c000e
	v_mac_f32_e32 v5, v53, v51                                  ; 2c0a6735
	v_lshlrev_b32_e32 v50, 4, v46                               ; 24645c84
	v_lshl_add_u32 v46, v46, 7, v50                             ; d1fd002e 04c90f2e
	v_add3_u32 v55, v30, 4, v46                                 ; d1ff0037 04b9091e
	buffer_load_dwordx3 v[51:53], v46, s[24:27], 0 offen        ; e0581000 8006332e
	buffer_load_ushort v55, v55, s[24:27], 0 offen              ; e0481000 80063737
	v_add_u32_e32 v46, 16, v46                                  ; 685c5c90
	s_waitcnt vmcnt(11)                                         ; bf8c3f7b
	v_and_b32_e32 v41, s10, v44                                 ; 2652580a
	v_add_u32_e32 v37, v46, v4                                  ; 684a092e
	v_add_u32_e32 v46, v46, v34                                 ; 685c452e
	buffer_load_dword v37, v37, s[24:27], 0 offen               ; e0501000 80062525
	buffer_load_dword v46, v46, s[24:27], 0 offen               ; e0501000 80062e2e
	v_and_b32_e32 v39, s11, v38                                 ; 264e4c0b
	v_lshrrev_b32_e32 v44, 4, v44                               ; 20585884
	v_cvt_f32_ubyte1_e32 v58, v41                               ; 7e742529
	v_cvt_f32_ubyte3_e32 v54, v41                               ; 7e6c2929
	v_cvt_f32_ubyte2_e32 v57, v41                               ; 7e722729
	v_cvt_f32_ubyte0_e32 v41, v41                               ; 7e522329
	v_lshrrev_b32_e32 v39, 2, v39                               ; 204e4e82
	v_and_b32_e32 v44, s10, v44                                 ; 2658580a
	v_mul_f32_e32 v54, v19, v54                                 ; 0a6c6d13
	v_and_or_b32 v42, s10, v42, v39                             ; d201002a 049e540a
	v_cvt_f32_ubyte1_e32 v50, v44                               ; 7e64252c
	v_cvt_f32_ubyte3_e32 v39, v44                               ; 7e4e292c
	v_mac_f32_e32 v54, v18, v57                                 ; 2c6c7312
	s_waitcnt vmcnt(12)                                         ; bf8c3f7c
	v_and_b32_e32 v57, s10, v43                                 ; 2672560a
	v_mul_f32_e32 v39, v23, v39                                 ; 0a4e4f17
	v_mac_f32_e32 v54, v17, v58                                 ; 2c6c7511
	v_cvt_f32_ubyte3_e32 v58, v57                               ; 7e742939
	v_lshrrev_b32_e32 v43, 4, v43                               ; 20565684
	v_mac_f32_e32 v54, v16, v41                                 ; 2c6c5310
	v_cvt_f32_ubyte2_e32 v41, v44                               ; 7e52272c
	v_cvt_f32_ubyte0_e32 v44, v44                               ; 7e58232c
	v_mul_f32_e32 v58, v27, v58                                 ; 0a74751b
	v_and_b32_e32 v43, s10, v43                                 ; 2656560a
	v_mac_f32_e32 v39, v22, v41                                 ; 2c4e5316
	v_cvt_f32_ubyte2_e32 v41, v57                               ; 7e522739
	v_mac_f32_e32 v39, v21, v50                                 ; 2c4e6515
	v_cvt_f32_ubyte3_e32 v50, v43                               ; 7e64292b
	v_mac_f32_e32 v58, v26, v41                                 ; 2c74531a
	v_cvt_f32_ubyte1_e32 v41, v43                               ; 7e52252b
	v_mac_f32_e32 v39, v20, v44                                 ; 2c4e5914
	v_cvt_f32_ubyte1_e32 v44, v57                               ; 7e582539
	v_cvt_f32_ubyte0_e32 v57, v57                               ; 7e722339
	v_mul_f32_e32 v50, v15, v50                                 ; 0a64650f
	v_and_b32_e32 v38, s12, v38                                 ; 264c4c0c
	v_mac_f32_e32 v58, v25, v44                                 ; 2c745919
	v_cvt_f32_ubyte2_e32 v44, v42                               ; 7e58272a
	v_mac_f32_e32 v58, v24, v57                                 ; 2c747318
	v_cvt_f32_ubyte2_e32 v57, v43                               ; 7e72272b
	v_cvt_f32_ubyte0_e32 v43, v43                               ; 7e56232b
	v_mac_f32_e32 v50, v14, v57                                 ; 2c64730e
	v_cvt_f32_ubyte3_e32 v57, v38                               ; 7e722926
	v_mac_f32_e32 v50, v13, v41                                 ; 2c64530d
	v_cvt_f32_ubyte2_e32 v41, v38                               ; 7e522726
	v_mac_f32_e32 v50, v12, v43                                 ; 2c64570c
	v_cvt_f32_ubyte3_e32 v43, v42                               ; 7e56292a
	v_mul_f32_e32 v43, v35, v43                                 ; 0a565723
	s_waitcnt vmcnt(11)                                         ; bf8c3f7b
	v_cndmask_b32_sdwa v60, v60, v60, vcc dst_sel:WORD_0 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 007878f9 0605143c
	v_cndmask_b32_sdwa v60, v61, v61, vcc dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 00787af9 0605153d
	v_mac_f32_e32 v43, v29, v44                                 ; 2c56591d
	v_cvt_f32_ubyte1_e32 v44, v42                               ; 7e58252a
	v_cvt_f32_ubyte0_e32 v42, v42                               ; 7e54232a
	s_waitcnt vmcnt(10)                                         ; bf8c3f7a
	v_lshl_or_b32 v47, v47, 12, v47                             ; d200002f 04bd192f
	v_and_b32_e32 v61, s11, v60                                 ; 267a780b
	v_mac_f32_e32 v43, v28, v57                                 ; 2c56731c
	v_cvt_f32_ubyte1_e32 v57, v38                               ; 7e722526
	v_cvt_f32_ubyte0_e32 v38, v38                               ; 7e4c2326
	v_mul_f32_e32 v50, v50, v44                                 ; 0a645932
	s_add_u32 s15, s16, 6                                       ; 800f8610
	v_lshrrev_b32_e32 v61, 2, v61                               ; 207a7a82
	v_mac_f32_e32 v43, v62, v41                                 ; 2c56533e
	v_mac_f32_e32 v50, v58, v42                                 ; 2c64553a
	v_cvt_f32_f16_sdwa v58, v56 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e7416f9 00050638
	v_cvt_f32_f16_e32 v56, v56                                  ; 7e701738
	s_mul_i32 s15, s15, s3                                      ; 920f030f
	v_mac_f32_e32 v50, v39, v57                                 ; 2c647327
	v_mad_f32 v6, -v58, v43, v6                                 ; d1c10006 241a573a
	s_add_u32 s15, s18, s15                                     ; 800f0f12
	v_mac_f32_e32 v50, v54, v38                                 ; 2c644d36
	v_add_u32_e32 v39, s15, v0                                  ; 684e000f
	v_lshlrev_b32_e32 v41, 4, v39                               ; 24524e84
	v_lshl_add_u32 v39, v39, 7, v41                             ; d1fd0027 04a50f27
	v_add3_u32 v54, v30, 4, v39                                 ; d1ff0036 049d091e
	buffer_load_dwordx3 v[42:44], v39, s[24:27], 0 offen        ; e0581000 80062a27
	buffer_load_ushort v54, v54, s[24:27], 0 offen              ; e0481000 80063636
	s_waitcnt vmcnt(11)                                         ; bf8c3f7b
	v_and_b32_e32 v38, s10, v49                                 ; 264c620a
	v_add_u32_e32 v39, 16, v39                                  ; 684e4e90
	v_add_u32_e32 v58, v39, v4                                  ; 68740927
	v_add_u32_e32 v39, v39, v34                                 ; 684e4527
	buffer_load_dword v58, v58, s[24:27], 0 offen               ; e0501000 80063a3a
	buffer_load_dword v39, v39, s[24:27], 0 offen               ; e0501000 80062727
	v_and_or_b32 v47, s10, v47, v61                             ; d201002f 04f65e0a
	v_mac_f32_e32 v6, v56, v50                                  ; 2c0c6538
	v_lshrrev_b32_e32 v49, 4, v49                               ; 20626284
	v_cvt_f32_ubyte1_e32 v57, v38                               ; 7e722526
	v_cvt_f32_ubyte2_e32 v56, v38                               ; 7e702726
	v_cvt_f32_ubyte3_e32 v50, v38                               ; 7e642926
	v_cvt_f32_ubyte0_e32 v38, v38                               ; 7e4c2326
	v_and_b32_e32 v49, s10, v49                                 ; 2662620a
	v_mul_f32_e32 v50, v19, v50                                 ; 0a646513
	v_cvt_f32_ubyte1_e32 v41, v49                               ; 7e522531
	v_cvt_f32_ubyte3_e32 v61, v49                               ; 7e7a2931
	v_mac_f32_e32 v50, v18, v56                                 ; 2c647112
	v_mul_f32_e32 v61, v23, v61                                 ; 0a7a7b17
	v_mac_f32_e32 v50, v17, v57                                 ; 2c647311
	v_mac_f32_e32 v50, v16, v38                                 ; 2c644d10
	v_cvt_f32_ubyte2_e32 v38, v49                               ; 7e4c2731
	v_cvt_f32_ubyte0_e32 v49, v49                               ; 7e622331
	v_mac_f32_e32 v61, v22, v38                                 ; 2c7a4d16
	v_mac_f32_e32 v61, v21, v41                                 ; 2c7a5315
	v_mac_f32_e32 v61, v20, v49                                 ; 2c7a6314
	s_waitcnt vmcnt(12)                                         ; bf8c3f7c
	v_and_b32_e32 v49, s10, v48                                 ; 2662600a
	v_lshrrev_b32_e32 v48, 4, v48                               ; 20606084
	v_cvt_f32_ubyte1_e32 v38, v49                               ; 7e4c2531
	v_cvt_f32_ubyte3_e32 v56, v49                               ; 7e702931
	v_cvt_f32_ubyte2_e32 v57, v49                               ; 7e722731
	v_cvt_f32_ubyte0_e32 v49, v49                               ; 7e622331
	v_and_b32_e32 v48, s10, v48                                 ; 2660600a
	v_mul_f32_e32 v56, v27, v56                                 ; 0a70711b
	v_cvt_f32_ubyte3_e32 v41, v48                               ; 7e522930
	v_and_b32_e32 v60, s12, v60                                 ; 2678780c
	v_mac_f32_e32 v56, v26, v57                                 ; 2c70731a
	v_cvt_f32_ubyte1_e32 v57, v48                               ; 7e722530
	v_mul_f32_e32 v41, v15, v41                                 ; 0a52530f
	v_mac_f32_e32 v56, v25, v38                                 ; 2c704d19
	v_cvt_f32_ubyte3_e32 v38, v47                               ; 7e4c292f
	v_mac_f32_e32 v56, v24, v49                                 ; 2c706318
	v_cvt_f32_ubyte2_e32 v49, v48                               ; 7e622730
	v_cvt_f32_ubyte0_e32 v48, v48                               ; 7e602330
	v_mul_f32_e32 v38, v35, v38                                 ; 0a4c4d23
	v_mac_f32_e32 v41, v14, v49                                 ; 2c52630e
	v_cvt_f32_ubyte3_e32 v49, v60                               ; 7e62293c
	v_mac_f32_e32 v41, v13, v57                                 ; 2c52730d
	v_cvt_f32_ubyte2_e32 v57, v60                               ; 7e72273c
	v_mac_f32_e32 v41, v12, v48                                 ; 2c52610c
	v_cvt_f32_ubyte2_e32 v48, v47                               ; 7e60272f
	v_mac_f32_e32 v38, v29, v48                                 ; 2c4c611d
	v_cvt_f32_ubyte1_e32 v48, v47                               ; 7e60252f
	v_cvt_f32_ubyte0_e32 v47, v47                               ; 7e5e232f
	s_waitcnt vmcnt(10)                                         ; bf8c3f7a
	v_lshl_or_b32 v45, v45, 12, v45                             ; d200002d 04b5192d
	v_mac_f32_e32 v38, v28, v49                                 ; 2c4c631c
	v_cvt_f32_ubyte1_e32 v49, v60                               ; 7e62253c
	v_cvt_f32_ubyte0_e32 v60, v60                               ; 7e78233c
	v_mul_f32_e32 v41, v41, v48                                 ; 0a526129
	v_mac_f32_e32 v38, v62, v57                                 ; 2c4c733e
	s_add_u32 s19, s16, 7                                       ; 80138710
	v_mac_f32_e32 v41, v56, v47                                 ; 2c525f38
	v_cndmask_b32_sdwa v56, v32, v32, vcc dst_sel:WORD_0 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 007040f9 06051420
	v_cndmask_b32_sdwa v56, v33, v33, vcc dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 007042f9 06051521
	s_mul_i32 s19, s19, s3                                      ; 92130313
	v_mac_f32_e32 v41, v61, v49                                 ; 2c52633d
	s_add_u32 s19, s18, s19                                     ; 80131312
	v_and_b32_e32 v57, s11, v56                                 ; 2672700b
	v_mac_f32_e32 v41, v50, v60                                 ; 2c527932
	v_add_u32_e32 v60, s19, v0                                  ; 68780013
	v_lshlrev_b32_e32 v61, 4, v60                               ; 247a7884
	v_lshl_add_u32 v60, v60, 7, v61                             ; d1fd003c 04f50f3c
	v_add3_u32 v30, v30, 4, v60                                 ; d1ff001e 04f1091e
	buffer_load_dwordx3 v[47:49], v60, s[24:27], 0 offen        ; e0581000 80062f3c
	buffer_load_ushort v30, v30, s[24:27], 0 offen              ; e0481000 80061e1e
	v_cvt_f32_f16_sdwa v50, v59 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e6416f9 0005063b
	v_cvt_f32_f16_e32 v59, v59                                  ; 7e76173b
	v_lshrrev_b32_e32 v57, 2, v57                               ; 20727282
	v_add_u32_e32 v60, 16, v60                                  ; 68787890
	v_mad_f32 v7, -v50, v38, v7                                 ; d1c10007 241e4d32
	v_add_u32_e32 v32, v60, v4                                  ; 6840093c
	v_add_u32_e32 v60, v60, v34                                 ; 6878453c
	buffer_load_dword v32, v32, s[24:27], 0 offen               ; e0501000 80062020
	buffer_load_dword v60, v60, s[24:27], 0 offen               ; e0501000 80063c3c
	v_and_or_b32 v45, s10, v45, v57                             ; d201002d 04e65a0a
	v_mac_f32_e32 v7, v59, v41                                  ; 2c0e533b
	s_waitcnt vmcnt(13)                                         ; bf8c3f7d
	v_and_b32_e32 v59, s10, v40                                 ; 2676500a
	v_lshrrev_b32_e32 v40, 4, v40                               ; 20505084
	v_cvt_f32_ubyte1_e32 v61, v59                               ; 7e7a253b
	v_cvt_f32_ubyte3_e32 v50, v59                               ; 7e64293b
	v_cvt_f32_ubyte2_e32 v57, v59                               ; 7e72273b
	v_cvt_f32_ubyte0_e32 v59, v59                               ; 7e76233b
	v_and_b32_e32 v40, s10, v40                                 ; 2650500a
	v_mul_f32_e32 v50, v19, v50                                 ; 0a646513
	v_cvt_f32_ubyte1_e32 v38, v40                               ; 7e4c2528
	v_cvt_f32_ubyte2_e32 v34, v40                               ; 7e442728
	v_cvt_f32_ubyte3_e32 v33, v40                               ; 7e422928
	v_cvt_f32_ubyte0_e32 v40, v40                               ; 7e502328
	v_mac_f32_e32 v50, v18, v57                                 ; 2c647312
	v_mul_f32_e32 v33, v23, v33                                 ; 0a424317
	v_mac_f32_e32 v50, v17, v61                                 ; 2c647b11
	v_mac_f32_e32 v33, v22, v34                                 ; 2c424516
	v_mac_f32_e32 v50, v16, v59                                 ; 2c647710
	v_mac_f32_e32 v33, v21, v38                                 ; 2c424d15
	v_mac_f32_e32 v33, v20, v40                                 ; 2c425114
	s_waitcnt vmcnt(12)                                         ; bf8c3f7c
	v_and_b32_e32 v40, s10, v36                                 ; 2650480a
	v_lshrrev_b32_e32 v36, 4, v36                               ; 20484884
	v_cvt_f32_ubyte1_e32 v59, v40                               ; 7e762528
	v_cvt_f32_ubyte2_e32 v57, v40                               ; 7e722728
	v_cvt_f32_ubyte3_e32 v41, v40                               ; 7e522928
	v_cvt_f32_ubyte0_e32 v40, v40                               ; 7e502328
	v_and_b32_e32 v36, s10, v36                                 ; 2648480a
	v_mul_f32_e32 v41, v27, v41                                 ; 0a52531b
	v_cvt_f32_ubyte3_e32 v61, v36                               ; 7e7a2924
	v_and_b32_e32 v56, s12, v56                                 ; 2670700c
	v_cvt_f32_ubyte1_e32 v38, v36                               ; 7e4c2524
	v_cvt_f32_ubyte2_e32 v34, v36                               ; 7e442724
	v_cvt_f32_ubyte0_e32 v36, v36                               ; 7e482324
	v_mac_f32_e32 v41, v26, v57                                 ; 2c52731a
	v_cvt_f32_ubyte2_e32 v57, v45                               ; 7e72272d
	v_mul_f32_e32 v61, v15, v61                                 ; 0a7a7b0f
	v_mac_f32_e32 v41, v25, v59                                 ; 2c527719
	v_cvt_f32_ubyte3_e32 v59, v56                               ; 7e762938
	v_mac_f32_e32 v61, v14, v34                                 ; 2c7a450e
	v_cvt_f32_ubyte2_e32 v34, v56                               ; 7e442738
	v_mac_f32_e32 v41, v24, v40                                 ; 2c525118
	v_cvt_f32_ubyte3_e32 v40, v45                               ; 7e50292d
	v_mac_f32_e32 v61, v13, v38                                 ; 2c7a4d0d
	v_cvt_f32_ubyte1_e32 v38, v56                               ; 7e4c2538
	v_cvt_f32_ubyte0_e32 v56, v56                               ; 7e702338
	v_mul_f32_e32 v40, v35, v40                                 ; 0a505123
	v_mac_f32_e32 v61, v12, v36                                 ; 2c7a490c
	v_cvt_f32_ubyte1_e32 v36, v45                               ; 7e48252d
	v_cvt_f32_ubyte0_e32 v45, v45                               ; 7e5a232d
	s_waitcnt vmcnt(10)                                         ; bf8c3f7a
	v_lshl_or_b32 v55, v55, 12, v55                             ; d2000037 04dd1937
	v_mac_f32_e32 v40, v29, v57                                 ; 2c50731d
	v_mul_f32_e32 v61, v61, v36                                 ; 0a7a493d
	v_mac_f32_e32 v40, v28, v59                                 ; 2c50771c
	v_mac_f32_e32 v61, v41, v45                                 ; 2c7a5b29
	v_cvt_f32_f16_sdwa v41, v31 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e5216f9 0005061f
	v_cvt_f32_f16_e32 v31, v31                                  ; 7e3e171f
	v_cndmask_b32_sdwa v45, v52, v52, vcc dst_sel:WORD_0 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 005a68f9 06051434
	v_cndmask_b32_sdwa v45, v53, v53, vcc dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 005a6af9 06051535
	s_waitcnt vmcnt(9)                                          ; bf8c3f79
	v_and_b32_e32 v52, s10, v37                                 ; 26684a0a
	v_mac_f32_e32 v40, v62, v34                                 ; 2c50453e
	v_mac_f32_e32 v61, v33, v38                                 ; 2c7a4d21
	v_cvt_f32_ubyte3_e32 v53, v52                               ; 7e6a2934
	v_cvt_f32_ubyte1_e32 v57, v52                               ; 7e722534
	v_lshrrev_b32_e32 v37, 4, v37                               ; 204a4a84
	v_mad_f32 v8, -v41, v40, v8                                 ; d1c10008 24225129
	v_mac_f32_e32 v61, v50, v56                                 ; 2c7a7132
	v_and_b32_e32 v50, s11, v45                                 ; 26645a0b
	v_cvt_f32_ubyte2_e32 v56, v52                               ; 7e702734
	v_cvt_f32_ubyte0_e32 v52, v52                               ; 7e682334
	v_mul_f32_e32 v53, v19, v53                                 ; 0a6a6b13
	v_and_b32_e32 v37, s10, v37                                 ; 264a4a0a
	v_mac_f32_e32 v8, v31, v61                                  ; 2c107b1f
	v_lshrrev_b32_e32 v50, 2, v50                               ; 20646482
	s_waitcnt vmcnt(8)                                          ; bf8c3f78
	v_and_b32_e32 v33, s10, v46                                 ; 26425c0a
	v_mac_f32_e32 v53, v18, v56                                 ; 2c6a7112
	v_cvt_f32_ubyte3_e32 v59, v37                               ; 7e762925
	v_cvt_f32_ubyte1_e32 v31, v37                               ; 7e3e2525
	v_cvt_f32_ubyte2_e32 v61, v37                               ; 7e7a2725
	v_cvt_f32_ubyte0_e32 v37, v37                               ; 7e4a2325
	v_and_or_b32 v55, s10, v55, v50                             ; d2010037 04ca6e0a
	v_cvt_f32_ubyte3_e32 v34, v33                               ; 7e442921
	v_cvt_f32_ubyte2_e32 v36, v33                               ; 7e482721
	v_mac_f32_e32 v53, v17, v57                                 ; 2c6a7311
	v_mul_f32_e32 v59, v23, v59                                 ; 0a767717
	v_lshrrev_b32_e32 v46, 4, v46                               ; 205c5c84
	v_mul_f32_e32 v34, v27, v34                                 ; 0a44451b
	v_mac_f32_e32 v53, v16, v52                                 ; 2c6a6910
	v_mac_f32_e32 v59, v22, v61                                 ; 2c767b16
	v_and_b32_e32 v46, s10, v46                                 ; 265c5c0a
	v_mac_f32_e32 v34, v26, v36                                 ; 2c44491a
	v_mac_f32_e32 v59, v21, v31                                 ; 2c763f15
	v_cvt_f32_ubyte3_e32 v38, v46                               ; 7e4c292e
	v_cvt_f32_ubyte2_e32 v40, v46                               ; 7e50272e
	v_cvt_f32_ubyte1_e32 v41, v46                               ; 7e52252e
	v_cvt_f32_ubyte0_e32 v46, v46                               ; 7e5c232e
	v_cvt_f32_ubyte2_e32 v50, v55                               ; 7e642737
	v_mac_f32_e32 v59, v20, v37                                 ; 2c764b14
	v_cvt_f32_ubyte1_e32 v37, v33                               ; 7e4a2521
	v_cvt_f32_ubyte0_e32 v33, v33                               ; 7e422321
	v_mul_f32_e32 v38, v15, v38                                 ; 0a4c4d0f
	v_and_b32_e32 v45, s12, v45                                 ; 265a5a0c
	v_cvt_f32_ubyte1_e32 v57, v55                               ; 7e722537
	v_mac_f32_e32 v34, v25, v37                                 ; 2c444b19
	v_mac_f32_e32 v38, v14, v40                                 ; 2c4c510e
	v_cvt_f32_ubyte1_e32 v61, v45                               ; 7e7a252d
	v_cvt_f32_ubyte3_e32 v52, v45                               ; 7e68292d
	v_cvt_f32_ubyte2_e32 v56, v45                               ; 7e70272d
	v_cvt_f32_ubyte0_e32 v45, v45                               ; 7e5a232d
	v_mac_f32_e32 v34, v24, v33                                 ; 2c444318
	v_mac_f32_e32 v38, v13, v41                                 ; 2c4c530d
	v_cvt_f32_f16_sdwa v31, v51 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e3e16f9 00050633
	v_cvt_f32_f16_e32 v51, v51                                  ; 7e661733
	s_waitcnt vmcnt(7)                                          ; bf8c3f77
	v_cndmask_b32_sdwa v33, v43, v43, vcc dst_sel:WORD_0 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 004256f9 0605142b
	v_mac_f32_e32 v38, v12, v46                                 ; 2c4c5d0c
	v_cvt_f32_ubyte3_e32 v46, v55                               ; 7e5c2937
	v_cvt_f32_ubyte0_e32 v55, v55                               ; 7e6e2337
	v_cndmask_b32_sdwa v33, v44, v44, vcc dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 004258f9 0605152c
	s_waitcnt vmcnt(6)                                          ; bf8c3f76
	v_lshl_or_b32 v54, v54, 12, v54                             ; d2000036 04d91936
	v_mul_f32_e32 v38, v38, v57                                 ; 0a4c7326
	v_mul_f32_e32 v46, v35, v46                                 ; 0a5c5d23
	s_waitcnt vmcnt(5)                                          ; bf8c3f75
	v_and_b32_e32 v36, s10, v58                                 ; 2648740a
	v_mac_f32_e32 v38, v34, v55                                 ; 2c4c6f22
	v_and_b32_e32 v34, s11, v33                                 ; 2644420b
	v_mac_f32_e32 v46, v29, v50                                 ; 2c5c651d
	v_cvt_f32_ubyte1_e32 v40, v36                               ; 7e502524
	v_cvt_f32_ubyte3_e32 v37, v36                               ; 7e4a2924
	v_mac_f32_e32 v38, v59, v61                                 ; 2c4c7b3b
	v_lshrrev_b32_e32 v34, 2, v34                               ; 20444482
	v_lshrrev_b32_e32 v58, 4, v58                               ; 20747484
	v_mac_f32_e32 v46, v28, v52                                 ; 2c5c691c
	v_mul_f32_e32 v37, v19, v37                                 ; 0a4a4b13
	v_mac_f32_e32 v38, v53, v45                                 ; 2c4c5b35
	v_and_or_b32 v54, s10, v54, v34                             ; d2010036 048a6c0a
	v_and_b32_e32 v58, s10, v58                                 ; 2674740a
	v_mac_f32_e32 v46, v62, v56                                 ; 2c5c713e
	v_cvt_f32_ubyte2_e32 v43, v58                               ; 7e56273a
	v_cvt_f32_ubyte3_e32 v41, v58                               ; 7e52293a
	v_cvt_f32_ubyte1_e32 v44, v58                               ; 7e58253a
	v_cvt_f32_ubyte0_e32 v58, v58                               ; 7e74233a
	s_waitcnt vmcnt(4)                                          ; bf8c3f74
	v_and_b32_e32 v45, s10, v39                                 ; 265a4e0a
	v_mad_f32 v9, -v31, v46, v9                                 ; d1c10009 24265d1f
	v_mul_f32_e32 v41, v23, v41                                 ; 0a525317
	v_cvt_f32_ubyte3_e32 v46, v45                               ; 7e5c292d
	v_cvt_f32_ubyte2_e32 v50, v45                               ; 7e64272d
	v_mac_f32_e32 v9, v51, v38                                  ; 2c124d33
	v_cvt_f32_ubyte2_e32 v38, v36                               ; 7e4c2724
	v_cvt_f32_ubyte0_e32 v36, v36                               ; 7e482324
	v_cvt_f32_ubyte1_e32 v51, v45                               ; 7e66252d
	v_cvt_f32_ubyte0_e32 v45, v45                               ; 7e5a232d
	v_mac_f32_e32 v41, v22, v43                                 ; 2c525716
	v_mul_f32_e32 v46, v27, v46                                 ; 0a5c5d1b
	v_lshrrev_b32_e32 v39, 4, v39                               ; 204e4e84
	v_mac_f32_e32 v37, v18, v38                                 ; 2c4a4d12
	v_mac_f32_e32 v41, v21, v44                                 ; 2c525915
	v_mac_f32_e32 v46, v26, v50                                 ; 2c5c651a
	v_and_b32_e32 v39, s10, v39                                 ; 264e4e0a
	v_cvt_f32_ubyte3_e32 v56, v54                               ; 7e702936
	v_mac_f32_e32 v37, v17, v40                                 ; 2c4a5111
	v_mac_f32_e32 v41, v20, v58                                 ; 2c527514
	v_mac_f32_e32 v46, v25, v51                                 ; 2c5c6719
	v_cvt_f32_ubyte2_e32 v57, v54                               ; 7e722736
	v_cvt_f32_ubyte3_e32 v52, v39                               ; 7e682927
	v_cvt_f32_ubyte2_e32 v53, v39                               ; 7e6a2727
	v_cvt_f32_ubyte1_e32 v55, v39                               ; 7e6e2527
	v_cvt_f32_ubyte0_e32 v39, v39                               ; 7e4e2327
	v_mul_f32_e32 v56, v35, v56                                 ; 0a707123
	v_and_b32_e32 v33, s12, v33                                 ; 2642420c
	v_mac_f32_e32 v37, v16, v36                                 ; 2c4a4910
	v_mac_f32_e32 v46, v24, v45                                 ; 2c5c5b18
	v_mul_f32_e32 v52, v15, v52                                 ; 0a68690f
	v_cvt_f32_ubyte1_e32 v61, v54                               ; 7e7a2536
	v_cvt_f32_ubyte0_e32 v54, v54                               ; 7e6c2336
	v_mac_f32_e32 v56, v29, v57                                 ; 2c70731d
	v_cvt_f32_ubyte1_e32 v31, v33                               ; 7e3e2521
	v_cvt_f32_ubyte3_e32 v58, v33                               ; 7e742921
	v_cvt_f32_ubyte2_e32 v59, v33                               ; 7e762721
	v_cvt_f32_ubyte0_e32 v33, v33                               ; 7e422321
	v_mac_f32_e32 v52, v14, v53                                 ; 2c686b0e
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_cndmask_b32_sdwa v34, v48, v48, vcc dst_sel:WORD_0 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 004460f9 06051430
	v_mac_f32_e32 v56, v28, v58                                 ; 2c70751c
	v_cndmask_b32_sdwa v34, v49, v49, vcc dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 004462f9 06051531
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_lshl_or_b32 v30, v30, 12, v30                             ; d200001e 0479191e
	v_mac_f32_e32 v52, v13, v55                                 ; 2c686f0d
	v_mac_f32_e32 v56, v62, v59                                 ; 2c70773e
	v_and_b32_e32 v36, s11, v34                                 ; 2648440b
	v_mac_f32_e32 v52, v12, v39                                 ; 2c684f0c
	v_lshrrev_b32_e32 v36, 2, v36                               ; 20484882
	v_mul_f32_e32 v52, v52, v61                                 ; 0a687b34
	v_and_or_b32 v30, s10, v30, v36                             ; d201001e 04923c0a
	v_mac_f32_e32 v52, v46, v54                                 ; 2c686d2e
	v_mac_f32_e32 v52, v41, v31                                 ; 2c683f29
	v_mac_f32_e32 v52, v37, v33                                 ; 2c684325
	v_cvt_f32_f16_sdwa v33, v42 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e4216f9 0005062a
	v_cvt_f32_f16_e32 v42, v42                                  ; 7e54172a
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v37, s10, v32                                 ; 264a400a
	v_lshrrev_b32_e32 v32, 4, v32                               ; 20404084
	v_mad_f32 v10, -v33, v56, v10                               ; d1c1000a 242a7121
	v_cvt_f32_ubyte1_e32 v40, v37                               ; 7e502525
	v_cvt_f32_ubyte3_e32 v38, v37                               ; 7e4c2925
	v_cvt_f32_ubyte2_e32 v39, v37                               ; 7e4e2725
	v_cvt_f32_ubyte0_e32 v37, v37                               ; 7e4a2325
	v_and_b32_e32 v32, s10, v32                                 ; 2640400a
	v_mac_f32_e32 v10, v42, v52                                 ; 2c14692a
	v_mul_f32_e32 v19, v19, v38                                 ; 0a264d13
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v44, s10, v60                                 ; 2658780a
	v_cvt_f32_ubyte1_e32 v43, v32                               ; 7e562520
	v_cvt_f32_ubyte3_e32 v41, v32                               ; 7e522920
	v_cvt_f32_ubyte2_e32 v42, v32                               ; 7e542720
	v_cvt_f32_ubyte0_e32 v32, v32                               ; 7e402320
	v_mac_f32_e32 v19, v18, v39                                 ; 2c264f12
	v_cvt_f32_ubyte2_e32 v46, v44                               ; 7e5c272c
	v_cvt_f32_ubyte1_e32 v48, v44                               ; 7e60252c
	v_cvt_f32_ubyte3_e32 v45, v44                               ; 7e5a292c
	v_cvt_f32_ubyte0_e32 v44, v44                               ; 7e58232c
	v_mul_f32_e32 v23, v23, v41                                 ; 0a2e5317
	v_lshrrev_b32_e32 v60, 4, v60                               ; 20787884
	v_mac_f32_e32 v19, v17, v40                                 ; 2c265111
	v_mul_f32_e32 v27, v27, v45                                 ; 0a365b1b
	v_mac_f32_e32 v23, v22, v42                                 ; 2c2e5516
	v_and_b32_e32 v60, s10, v60                                 ; 2678780a
	v_mac_f32_e32 v19, v16, v37                                 ; 2c264b10
	v_mac_f32_e32 v27, v26, v46                                 ; 2c365d1a
	v_cvt_f32_ubyte3_e32 v52, v30                               ; 7e68291e
	v_mac_f32_e32 v23, v21, v43                                 ; 2c2e5715
	v_cvt_f32_ubyte3_e32 v49, v60                               ; 7e62293c
	v_cvt_f32_ubyte1_e32 v51, v60                               ; 7e66253c
	v_cvt_f32_ubyte2_e32 v53, v30                               ; 7e6a271e
	v_cvt_f32_ubyte2_e32 v50, v60                               ; 7e64273c
	v_cvt_f32_ubyte0_e32 v60, v60                               ; 7e78233c
	v_mac_f32_e32 v27, v25, v48                                 ; 2c366119
	v_and_b32_e32 v34, s12, v34                                 ; 2644440c
	v_mul_f32_e32 v35, v35, v52                                 ; 0a466923
	v_mac_f32_e32 v23, v20, v32                                 ; 2c2e4114
	v_mul_f32_e32 v15, v15, v49                                 ; 0a1e630f
	v_cvt_f32_ubyte1_e32 v56, v30                               ; 7e70251e
	v_cvt_f32_ubyte0_e32 v30, v30                               ; 7e3c231e
	v_mac_f32_e32 v27, v24, v44                                 ; 2c365918
	v_cvt_f32_ubyte1_e32 v57, v34                               ; 7e722522
	v_cvt_f32_ubyte3_e32 v54, v34                               ; 7e6c2922
	v_cvt_f32_ubyte2_e32 v55, v34                               ; 7e6e2722
	v_mac_f32_e32 v35, v29, v53                                 ; 2c466b1d
	v_cvt_f32_ubyte0_e32 v34, v34                               ; 7e442322
	v_mac_f32_e32 v15, v14, v50                                 ; 2c1e650e
	v_cvt_f32_f16_sdwa v58, v47 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e7416f9 0005062f
	v_cvt_f32_f16_e32 v47, v47                                  ; 7e5e172f
	v_add_u32_e32 v0, 4, v0                                     ; 68000084
	v_mac_f32_e32 v35, v28, v54                                 ; 2c466d1c
	v_mac_f32_e32 v15, v13, v51                                 ; 2c1e670d
	v_mac_f32_e32 v35, v62, v55                                 ; 2c466f3e
	v_mac_f32_e32 v15, v12, v60                                 ; 2c1e790c
	v_mad_f32 v11, -v58, v35, v11                               ; d1c1000b 242e473a
	v_mul_f32_e32 v15, v15, v56                                 ; 0a1e710f
	v_mac_f32_e32 v15, v27, v30                                 ; 2c1e3d1b
	v_mac_f32_e32 v15, v23, v57                                 ; 2c1e7317
	v_mac_f32_e32 v15, v19, v34                                 ; 2c1e4513
	v_mac_f32_e32 v11, v47, v15                                 ; 2c161f2f
BB5:
	s_mov_b64 s[0:1], exec                                      ; be80017e
	v_cmpx_le_u32_e32 vcc, s3, v0                               ; 7db60003
BB6:
	s_andn2_b64 s[0:1], s[0:1], exec                            ; 89807e00
	s_cbranch_scc1 BB10                                         ; bf85fcd2
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
	s_branch BB203                                              ; bf82059d
BB66:
	s_cmp_lt_u32 s16, s4                                        ; bf0a0410
	s_cbranch_scc0 BB203                                        ; bf84059b
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
	s_cbranch_scc0 BB101                                        ; bf84035a
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
	s_cbranch_scc0 BB100                                        ; bf84032d
BB77:
	s_load_dwordx4 s[12:15], s[0:1], 0x0                        ; c00a0300 00000000
	s_mul_i32 s0, s16, s3                                       ; 92000310
	v_lshl_add_u32 v34, v2, 1, 8                                ; d1fd0022 02210302
	v_add_u32_e32 v38, 64, v4                                   ; 684c08c0
	s_add_u32 s0, s19, s0                                       ; 80000013
	v_add_u32_e32 v32, s0, v0                                   ; 68400000
	v_lshlrev_b32_e32 v33, 4, v32                               ; 24424084
	v_lshl_add_u32 v32, v32, 7, v33                             ; d1fd0020 04850f20
	v_add3_u32 v35, v34, 4, v32                                 ; d1ff0023 04810922
	v_add_u32_e32 v36, 16, v32                                  ; 68484090
	v_add_u32_e32 v37, v36, v4                                  ; 684a0924
	v_add_u32_e32 v36, v36, v38                                 ; 68484d24
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_load_dwordx3 v[39:41], v32, s[12:15], 0 offen        ; e0581000 80032720
	buffer_load_ushort v35, v35, s[12:15], 0 offen              ; e0481000 80032323
	buffer_load_dword v37, v37, s[12:15], 0 offen               ; e0501000 80032525
	buffer_load_dword v36, v36, s[12:15], 0 offen               ; e0501000 80032424
	s_bitreplicate_b64_b32 vcc, 0xf0f0f0f                       ; beea37ff 0f0f0f0f
	s_mov_b32 s1, 0xf0f0f0f                                     ; be8100ff 0f0f0f0f
	s_cmp_lt_u32 1, s4                                          ; bf0a0481
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_cndmask_b32_sdwa v42, v40, v40, vcc dst_sel:WORD_0 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 005450f9 06051428
	v_cndmask_b32_sdwa v42, v41, v41, vcc dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 005452f9 06051529
	v_cvt_f32_f16_sdwa v47, v39 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e5e16f9 00050627
	v_cvt_f32_f16_e32 v39, v39                                  ; 7e4e1727
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_lshl_or_b32 v35, v35, 12, v35                             ; d2000023 048d1923
	v_and_b32_e32 v43, 0xc0c0c0c0, v42                          ; 265654ff c0c0c0c0
	v_and_b32_e32 v42, 0x3f3f3f3f, v42                          ; 265454ff 3f3f3f3f
	v_lshrrev_b32_e32 v43, 2, v43                               ; 20565682
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v51, s1, v37                                  ; 26664a01
	v_cvt_f32_ubyte3_e32 v44, v42                               ; 7e58292a
	v_cvt_f32_ubyte2_e32 v45, v42                               ; 7e5a272a
	v_cvt_f32_ubyte1_e32 v46, v42                               ; 7e5c252a
	v_cvt_f32_ubyte0_e32 v42, v42                               ; 7e54232a
	v_and_or_b32 v35, s1, v35, v43                              ; d2010023 04ae4601
	v_cvt_f32_ubyte3_e32 v52, v51                               ; 7e682933
	v_cvt_f32_ubyte2_e32 v53, v51                               ; 7e6a2733
	v_cvt_f32_ubyte1_e32 v54, v51                               ; 7e6c2533
	v_cvt_f32_ubyte0_e32 v51, v51                               ; 7e662333
	v_cvt_f32_ubyte3_e32 v48, v35                               ; 7e602923
	v_cvt_f32_ubyte2_e32 v49, v35                               ; 7e622723
	v_cvt_f32_ubyte1_e32 v50, v35                               ; 7e642523
	v_cvt_f32_ubyte0_e32 v35, v35                               ; 7e462323
	v_mul_f32_e32 v52, v19, v52                                 ; 0a686913
	v_lshrrev_b32_e32 v37, 4, v37                               ; 204a4a84
	v_mul_f32_e32 v48, v31, v48                                 ; 0a60611f
	v_mac_f32_e32 v52, v18, v53                                 ; 2c686b12
	v_and_b32_e32 v37, s1, v37                                  ; 264a4a01
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v58, s1, v36                                  ; 26744801
	v_mac_f32_e32 v48, v30, v49                                 ; 2c60631e
	v_mac_f32_e32 v52, v17, v54                                 ; 2c686d11
	v_cvt_f32_ubyte2_e32 v56, v37                               ; 7e702725
	v_cvt_f32_ubyte1_e32 v57, v37                               ; 7e722525
	v_cvt_f32_ubyte3_e32 v55, v37                               ; 7e6e2925
	v_cvt_f32_ubyte0_e32 v37, v37                               ; 7e4a2325
	v_cvt_f32_ubyte3_e32 v59, v58                               ; 7e76293a
	v_cvt_f32_ubyte2_e32 v60, v58                               ; 7e78273a
	v_mac_f32_e32 v48, v29, v44                                 ; 2c60591d
	v_mac_f32_e32 v52, v16, v51                                 ; 2c686710
	v_cvt_f32_ubyte1_e32 v61, v58                               ; 7e7a253a
	v_cvt_f32_ubyte0_e32 v58, v58                               ; 7e74233a
	v_mul_f32_e32 v55, v23, v55                                 ; 0a6e6f17
	v_lshrrev_b32_e32 v36, 4, v36                               ; 20484884
	v_mul_f32_e32 v59, v27, v59                                 ; 0a76771b
	v_mac_f32_e32 v48, v28, v45                                 ; 2c605b1c
	v_mac_f32_e32 v55, v22, v56                                 ; 2c6e7116
	v_and_b32_e32 v36, s1, v36                                  ; 26484801
	v_mac_f32_e32 v59, v26, v60                                 ; 2c76791a
	v_mad_f32 v3, -v47, v48, v3                                 ; d1c10003 240e612f
	v_mac_f32_e32 v55, v21, v57                                 ; 2c6e7315
	v_cvt_f32_ubyte1_e32 v33, v36                               ; 7e422524
	v_cvt_f32_ubyte3_e32 v62, v36                               ; 7e7c2924
	v_cvt_f32_ubyte2_e32 v32, v36                               ; 7e402724
	v_cvt_f32_ubyte0_e32 v36, v36                               ; 7e482324
	v_mac_f32_e32 v59, v25, v61                                 ; 2c767b19
	v_mac_f32_e32 v55, v20, v37                                 ; 2c6e4b14
	v_mul_f32_e32 v62, v15, v62                                 ; 0a7c7d0f
	v_mac_f32_e32 v59, v24, v58                                 ; 2c767518
	v_mac_f32_e32 v62, v14, v32                                 ; 2c7c410e
	v_mac_f32_e32 v62, v13, v33                                 ; 2c7c430d
	v_mac_f32_e32 v62, v12, v36                                 ; 2c7c490c
	v_mul_f32_e32 v62, v62, v50                                 ; 0a7c653e
	v_mac_f32_e32 v62, v59, v35                                 ; 2c7c473b
	v_mac_f32_e32 v62, v55, v46                                 ; 2c7c5d37
	v_mac_f32_e32 v62, v52, v42                                 ; 2c7c5534
	v_mac_f32_e32 v3, v39, v62                                  ; 2c067d27
	s_cbranch_scc0 BB100                                        ; bf8402c1
BB78:
	s_add_u32 s0, s16, 1                                        ; 80008110
	s_mul_i32 s0, s0, s3                                        ; 92000300
	s_add_u32 s0, s19, s0                                       ; 80000013
	v_add_u32_e32 v32, s0, v0                                   ; 68400000
	v_lshlrev_b32_e32 v33, 4, v32                               ; 24424084
	v_lshl_add_u32 v32, v32, 7, v33                             ; d1fd0020 04850f20
	v_add3_u32 v35, v34, 4, v32                                 ; d1ff0023 04810922
	v_add_u32_e32 v36, 16, v32                                  ; 68484090
	v_add_u32_e32 v37, v36, v4                                  ; 684a0924
	v_add_u32_e32 v36, v36, v38                                 ; 68484d24
	buffer_load_dwordx3 v[39:41], v32, s[12:15], 0 offen        ; e0581000 80032720
	buffer_load_ushort v35, v35, s[12:15], 0 offen              ; e0481000 80032323
	buffer_load_dword v37, v37, s[12:15], 0 offen               ; e0501000 80032525
	buffer_load_dword v36, v36, s[12:15], 0 offen               ; e0501000 80032424
	s_mov_b32 s1, 0xf0f0f0f                                     ; be8100ff 0f0f0f0f
	s_cmp_lt_u32 2, s4                                          ; bf0a0482
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_cndmask_b32_sdwa v42, v40, v40, vcc dst_sel:WORD_0 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 005450f9 06051428
	v_cndmask_b32_sdwa v42, v41, v41, vcc dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 005452f9 06051529
	v_cvt_f32_f16_sdwa v47, v39 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e5e16f9 00050627
	v_cvt_f32_f16_e32 v39, v39                                  ; 7e4e1727
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_lshl_or_b32 v35, v35, 12, v35                             ; d2000023 048d1923
	v_and_b32_e32 v43, 0xc0c0c0c0, v42                          ; 265654ff c0c0c0c0
	v_and_b32_e32 v42, 0x3f3f3f3f, v42                          ; 265454ff 3f3f3f3f
	v_lshrrev_b32_e32 v43, 2, v43                               ; 20565682
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v51, s1, v37                                  ; 26664a01
	v_cvt_f32_ubyte3_e32 v44, v42                               ; 7e58292a
	v_cvt_f32_ubyte2_e32 v45, v42                               ; 7e5a272a
	v_cvt_f32_ubyte1_e32 v46, v42                               ; 7e5c252a
	v_cvt_f32_ubyte0_e32 v42, v42                               ; 7e54232a
	v_and_or_b32 v35, s1, v35, v43                              ; d2010023 04ae4601
	v_cvt_f32_ubyte3_e32 v52, v51                               ; 7e682933
	v_cvt_f32_ubyte2_e32 v53, v51                               ; 7e6a2733
	v_cvt_f32_ubyte1_e32 v54, v51                               ; 7e6c2533
	v_cvt_f32_ubyte0_e32 v51, v51                               ; 7e662333
	v_cvt_f32_ubyte1_e32 v50, v35                               ; 7e642523
	v_cvt_f32_ubyte3_e32 v48, v35                               ; 7e602923
	v_cvt_f32_ubyte2_e32 v49, v35                               ; 7e622723
	v_cvt_f32_ubyte0_e32 v35, v35                               ; 7e462323
	v_mul_f32_e32 v52, v19, v52                                 ; 0a686913
	v_lshrrev_b32_e32 v37, 4, v37                               ; 204a4a84
	v_mul_f32_e32 v48, v31, v48                                 ; 0a60611f
	v_mac_f32_e32 v52, v18, v53                                 ; 2c686b12
	v_and_b32_e32 v37, s1, v37                                  ; 264a4a01
	v_mac_f32_e32 v48, v30, v49                                 ; 2c60631e
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v58, s1, v36                                  ; 26744801
	v_mac_f32_e32 v52, v17, v54                                 ; 2c686d11
	v_cvt_f32_ubyte1_e32 v57, v37                               ; 7e722525
	v_cvt_f32_ubyte3_e32 v55, v37                               ; 7e6e2925
	v_cvt_f32_ubyte2_e32 v56, v37                               ; 7e702725
	v_cvt_f32_ubyte0_e32 v37, v37                               ; 7e4a2325
	v_mac_f32_e32 v48, v29, v44                                 ; 2c60591d
	v_cvt_f32_ubyte2_e32 v60, v58                               ; 7e78273a
	v_cvt_f32_ubyte3_e32 v59, v58                               ; 7e76293a
	v_mac_f32_e32 v52, v16, v51                                 ; 2c686710
	v_cvt_f32_ubyte1_e32 v61, v58                               ; 7e7a253a
	v_mul_f32_e32 v55, v23, v55                                 ; 0a6e6f17
	v_cvt_f32_ubyte0_e32 v58, v58                               ; 7e74233a
	v_lshrrev_b32_e32 v36, 4, v36                               ; 20484884
	v_mac_f32_e32 v48, v28, v45                                 ; 2c605b1c
	v_mul_f32_e32 v59, v27, v59                                 ; 0a76771b
	v_mac_f32_e32 v55, v22, v56                                 ; 2c6e7116
	v_and_b32_e32 v36, s1, v36                                  ; 26484801
	v_mad_f32 v5, -v47, v48, v5                                 ; d1c10005 2416612f
	v_mac_f32_e32 v59, v26, v60                                 ; 2c76791a
	v_mac_f32_e32 v55, v21, v57                                 ; 2c6e7315
	v_cvt_f32_ubyte3_e32 v62, v36                               ; 7e7c2924
	v_cvt_f32_ubyte2_e32 v32, v36                               ; 7e402724
	v_cvt_f32_ubyte1_e32 v33, v36                               ; 7e422524
	v_cvt_f32_ubyte0_e32 v36, v36                               ; 7e482324
	v_mac_f32_e32 v59, v25, v61                                 ; 2c767b19
	v_mac_f32_e32 v55, v20, v37                                 ; 2c6e4b14
	v_mul_f32_e32 v62, v15, v62                                 ; 0a7c7d0f
	v_mac_f32_e32 v59, v24, v58                                 ; 2c767518
	v_mac_f32_e32 v62, v14, v32                                 ; 2c7c410e
	v_mac_f32_e32 v62, v13, v33                                 ; 2c7c430d
	v_mac_f32_e32 v62, v12, v36                                 ; 2c7c490c
	v_mul_f32_e32 v62, v62, v50                                 ; 0a7c653e
	v_mac_f32_e32 v62, v59, v35                                 ; 2c7c473b
	v_mac_f32_e32 v62, v55, v46                                 ; 2c7c5d37
	v_mac_f32_e32 v62, v52, v42                                 ; 2c7c5534
	v_mac_f32_e32 v5, v39, v62                                  ; 2c0a7d27
	s_cbranch_scc0 BB100                                        ; bf84025c
BB79:
	s_add_u32 s0, s16, 2                                        ; 80008210
	s_mul_i32 s0, s0, s3                                        ; 92000300
	s_add_u32 s0, s19, s0                                       ; 80000013
	v_add_u32_e32 v32, s0, v0                                   ; 68400000
	v_lshlrev_b32_e32 v33, 4, v32                               ; 24424084
	v_lshl_add_u32 v32, v32, 7, v33                             ; d1fd0020 04850f20
	v_add3_u32 v35, v34, 4, v32                                 ; d1ff0023 04810922
	v_add_u32_e32 v36, 16, v32                                  ; 68484090
	v_add_u32_e32 v37, v36, v4                                  ; 684a0924
	v_add_u32_e32 v36, v36, v38                                 ; 68484d24
	buffer_load_dwordx3 v[39:41], v32, s[12:15], 0 offen        ; e0581000 80032720
	buffer_load_ushort v35, v35, s[12:15], 0 offen              ; e0481000 80032323
	buffer_load_dword v37, v37, s[12:15], 0 offen               ; e0501000 80032525
	buffer_load_dword v36, v36, s[12:15], 0 offen               ; e0501000 80032424
	s_mov_b32 s1, 0xf0f0f0f                                     ; be8100ff 0f0f0f0f
	s_cmp_lt_u32 3, s4                                          ; bf0a0483
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_cndmask_b32_sdwa v42, v40, v40, vcc dst_sel:WORD_0 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 005450f9 06051428
	v_cndmask_b32_sdwa v42, v41, v41, vcc dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 005452f9 06051529
	v_cvt_f32_f16_sdwa v47, v39 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e5e16f9 00050627
	v_cvt_f32_f16_e32 v39, v39                                  ; 7e4e1727
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_lshl_or_b32 v35, v35, 12, v35                             ; d2000023 048d1923
	v_and_b32_e32 v43, 0xc0c0c0c0, v42                          ; 265654ff c0c0c0c0
	v_and_b32_e32 v42, 0x3f3f3f3f, v42                          ; 265454ff 3f3f3f3f
	v_lshrrev_b32_e32 v43, 2, v43                               ; 20565682
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v51, s1, v37                                  ; 26664a01
	v_cvt_f32_ubyte3_e32 v44, v42                               ; 7e58292a
	v_cvt_f32_ubyte2_e32 v45, v42                               ; 7e5a272a
	v_cvt_f32_ubyte1_e32 v46, v42                               ; 7e5c252a
	v_cvt_f32_ubyte0_e32 v42, v42                               ; 7e54232a
	v_and_or_b32 v35, s1, v35, v43                              ; d2010023 04ae4601
	v_cvt_f32_ubyte3_e32 v52, v51                               ; 7e682933
	v_cvt_f32_ubyte2_e32 v53, v51                               ; 7e6a2733
	v_cvt_f32_ubyte1_e32 v54, v51                               ; 7e6c2533
	v_cvt_f32_ubyte0_e32 v51, v51                               ; 7e662333
	v_cvt_f32_ubyte1_e32 v50, v35                               ; 7e642523
	v_cvt_f32_ubyte3_e32 v48, v35                               ; 7e602923
	v_cvt_f32_ubyte2_e32 v49, v35                               ; 7e622723
	v_cvt_f32_ubyte0_e32 v35, v35                               ; 7e462323
	v_mul_f32_e32 v52, v19, v52                                 ; 0a686913
	v_lshrrev_b32_e32 v37, 4, v37                               ; 204a4a84
	v_mul_f32_e32 v48, v31, v48                                 ; 0a60611f
	v_mac_f32_e32 v52, v18, v53                                 ; 2c686b12
	v_and_b32_e32 v37, s1, v37                                  ; 264a4a01
	v_mac_f32_e32 v48, v30, v49                                 ; 2c60631e
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v58, s1, v36                                  ; 26744801
	v_mac_f32_e32 v52, v17, v54                                 ; 2c686d11
	v_cvt_f32_ubyte1_e32 v57, v37                               ; 7e722525
	v_cvt_f32_ubyte3_e32 v55, v37                               ; 7e6e2925
	v_cvt_f32_ubyte2_e32 v56, v37                               ; 7e702725
	v_cvt_f32_ubyte0_e32 v37, v37                               ; 7e4a2325
	v_mac_f32_e32 v48, v29, v44                                 ; 2c60591d
	v_cvt_f32_ubyte2_e32 v60, v58                               ; 7e78273a
	v_cvt_f32_ubyte3_e32 v59, v58                               ; 7e76293a
	v_mac_f32_e32 v52, v16, v51                                 ; 2c686710
	v_cvt_f32_ubyte1_e32 v61, v58                               ; 7e7a253a
	v_mul_f32_e32 v55, v23, v55                                 ; 0a6e6f17
	v_cvt_f32_ubyte0_e32 v58, v58                               ; 7e74233a
	v_lshrrev_b32_e32 v36, 4, v36                               ; 20484884
	v_mac_f32_e32 v48, v28, v45                                 ; 2c605b1c
	v_mul_f32_e32 v59, v27, v59                                 ; 0a76771b
	v_mac_f32_e32 v55, v22, v56                                 ; 2c6e7116
	v_and_b32_e32 v36, s1, v36                                  ; 26484801
	v_mad_f32 v6, -v47, v48, v6                                 ; d1c10006 241a612f
	v_mac_f32_e32 v59, v26, v60                                 ; 2c76791a
	v_mac_f32_e32 v55, v21, v57                                 ; 2c6e7315
	v_cvt_f32_ubyte3_e32 v62, v36                               ; 7e7c2924
	v_cvt_f32_ubyte2_e32 v32, v36                               ; 7e402724
	v_cvt_f32_ubyte1_e32 v33, v36                               ; 7e422524
	v_cvt_f32_ubyte0_e32 v36, v36                               ; 7e482324
	v_mac_f32_e32 v59, v25, v61                                 ; 2c767b19
	v_mac_f32_e32 v55, v20, v37                                 ; 2c6e4b14
	v_mul_f32_e32 v62, v15, v62                                 ; 0a7c7d0f
	v_mac_f32_e32 v59, v24, v58                                 ; 2c767518
	v_mac_f32_e32 v62, v14, v32                                 ; 2c7c410e
	v_mac_f32_e32 v62, v13, v33                                 ; 2c7c430d
	v_mac_f32_e32 v62, v12, v36                                 ; 2c7c490c
	v_mul_f32_e32 v62, v62, v50                                 ; 0a7c653e
	v_mac_f32_e32 v62, v59, v35                                 ; 2c7c473b
	v_mac_f32_e32 v62, v55, v46                                 ; 2c7c5d37
	v_mac_f32_e32 v62, v52, v42                                 ; 2c7c5534
	v_mac_f32_e32 v6, v39, v62                                  ; 2c0c7d27
	s_cbranch_scc0 BB100                                        ; bf8401f7
BB80:
	s_add_u32 s0, s16, 3                                        ; 80008310
	s_mul_i32 s0, s0, s3                                        ; 92000300
	s_add_u32 s0, s19, s0                                       ; 80000013
	v_add_u32_e32 v32, s0, v0                                   ; 68400000
	v_lshlrev_b32_e32 v33, 4, v32                               ; 24424084
	v_lshl_add_u32 v32, v32, 7, v33                             ; d1fd0020 04850f20
	v_add3_u32 v35, v34, 4, v32                                 ; d1ff0023 04810922
	v_add_u32_e32 v36, 16, v32                                  ; 68484090
	v_add_u32_e32 v37, v36, v4                                  ; 684a0924
	v_add_u32_e32 v36, v36, v38                                 ; 68484d24
	buffer_load_dwordx3 v[39:41], v32, s[12:15], 0 offen        ; e0581000 80032720
	buffer_load_ushort v35, v35, s[12:15], 0 offen              ; e0481000 80032323
	buffer_load_dword v37, v37, s[12:15], 0 offen               ; e0501000 80032525
	buffer_load_dword v36, v36, s[12:15], 0 offen               ; e0501000 80032424
	s_mov_b32 s1, 0xf0f0f0f                                     ; be8100ff 0f0f0f0f
	s_cmp_lt_u32 4, s4                                          ; bf0a0484
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_cndmask_b32_sdwa v42, v40, v40, vcc dst_sel:WORD_0 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 005450f9 06051428
	v_cndmask_b32_sdwa v42, v41, v41, vcc dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 005452f9 06051529
	v_cvt_f32_f16_sdwa v47, v39 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e5e16f9 00050627
	v_cvt_f32_f16_e32 v39, v39                                  ; 7e4e1727
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_lshl_or_b32 v35, v35, 12, v35                             ; d2000023 048d1923
	v_and_b32_e32 v43, 0xc0c0c0c0, v42                          ; 265654ff c0c0c0c0
	v_and_b32_e32 v42, 0x3f3f3f3f, v42                          ; 265454ff 3f3f3f3f
	v_lshrrev_b32_e32 v43, 2, v43                               ; 20565682
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v51, s1, v37                                  ; 26664a01
	v_cvt_f32_ubyte3_e32 v44, v42                               ; 7e58292a
	v_cvt_f32_ubyte2_e32 v45, v42                               ; 7e5a272a
	v_cvt_f32_ubyte1_e32 v46, v42                               ; 7e5c252a
	v_cvt_f32_ubyte0_e32 v42, v42                               ; 7e54232a
	v_and_or_b32 v35, s1, v35, v43                              ; d2010023 04ae4601
	v_cvt_f32_ubyte3_e32 v52, v51                               ; 7e682933
	v_cvt_f32_ubyte2_e32 v53, v51                               ; 7e6a2733
	v_cvt_f32_ubyte1_e32 v54, v51                               ; 7e6c2533
	v_cvt_f32_ubyte0_e32 v51, v51                               ; 7e662333
	v_cvt_f32_ubyte1_e32 v50, v35                               ; 7e642523
	v_cvt_f32_ubyte3_e32 v48, v35                               ; 7e602923
	v_cvt_f32_ubyte2_e32 v49, v35                               ; 7e622723
	v_cvt_f32_ubyte0_e32 v35, v35                               ; 7e462323
	v_mul_f32_e32 v52, v19, v52                                 ; 0a686913
	v_lshrrev_b32_e32 v37, 4, v37                               ; 204a4a84
	v_mul_f32_e32 v48, v31, v48                                 ; 0a60611f
	v_mac_f32_e32 v52, v18, v53                                 ; 2c686b12
	v_and_b32_e32 v37, s1, v37                                  ; 264a4a01
	v_mac_f32_e32 v48, v30, v49                                 ; 2c60631e
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v58, s1, v36                                  ; 26744801
	v_mac_f32_e32 v52, v17, v54                                 ; 2c686d11
	v_cvt_f32_ubyte1_e32 v57, v37                               ; 7e722525
	v_cvt_f32_ubyte3_e32 v55, v37                               ; 7e6e2925
	v_cvt_f32_ubyte2_e32 v56, v37                               ; 7e702725
	v_cvt_f32_ubyte0_e32 v37, v37                               ; 7e4a2325
	v_mac_f32_e32 v48, v29, v44                                 ; 2c60591d
	v_cvt_f32_ubyte2_e32 v60, v58                               ; 7e78273a
	v_cvt_f32_ubyte3_e32 v59, v58                               ; 7e76293a
	v_mac_f32_e32 v52, v16, v51                                 ; 2c686710
	v_cvt_f32_ubyte1_e32 v61, v58                               ; 7e7a253a
	v_mul_f32_e32 v55, v23, v55                                 ; 0a6e6f17
	v_cvt_f32_ubyte0_e32 v58, v58                               ; 7e74233a
	v_lshrrev_b32_e32 v36, 4, v36                               ; 20484884
	v_mac_f32_e32 v48, v28, v45                                 ; 2c605b1c
	v_mul_f32_e32 v59, v27, v59                                 ; 0a76771b
	v_mac_f32_e32 v55, v22, v56                                 ; 2c6e7116
	v_and_b32_e32 v36, s1, v36                                  ; 26484801
	v_mad_f32 v7, -v47, v48, v7                                 ; d1c10007 241e612f
	v_mac_f32_e32 v59, v26, v60                                 ; 2c76791a
	v_mac_f32_e32 v55, v21, v57                                 ; 2c6e7315
	v_cvt_f32_ubyte3_e32 v62, v36                               ; 7e7c2924
	v_cvt_f32_ubyte2_e32 v32, v36                               ; 7e402724
	v_cvt_f32_ubyte1_e32 v33, v36                               ; 7e422524
	v_cvt_f32_ubyte0_e32 v36, v36                               ; 7e482324
	v_mac_f32_e32 v59, v25, v61                                 ; 2c767b19
	v_mac_f32_e32 v55, v20, v37                                 ; 2c6e4b14
	v_mul_f32_e32 v62, v15, v62                                 ; 0a7c7d0f
	v_mac_f32_e32 v59, v24, v58                                 ; 2c767518
	v_mac_f32_e32 v62, v14, v32                                 ; 2c7c410e
	v_mac_f32_e32 v62, v13, v33                                 ; 2c7c430d
	v_mac_f32_e32 v62, v12, v36                                 ; 2c7c490c
	v_mul_f32_e32 v62, v62, v50                                 ; 0a7c653e
	v_mac_f32_e32 v62, v59, v35                                 ; 2c7c473b
	v_mac_f32_e32 v62, v55, v46                                 ; 2c7c5d37
	v_mac_f32_e32 v62, v52, v42                                 ; 2c7c5534
	v_mac_f32_e32 v7, v39, v62                                  ; 2c0e7d27
	s_cbranch_scc0 BB100                                        ; bf840192
BB81:
	s_add_u32 s0, s16, 4                                        ; 80008410
	s_mul_i32 s0, s0, s3                                        ; 92000300
	s_add_u32 s0, s19, s0                                       ; 80000013
	v_add_u32_e32 v32, s0, v0                                   ; 68400000
	v_lshlrev_b32_e32 v33, 4, v32                               ; 24424084
	v_lshl_add_u32 v32, v32, 7, v33                             ; d1fd0020 04850f20
	v_add3_u32 v35, v34, 4, v32                                 ; d1ff0023 04810922
	v_add_u32_e32 v36, 16, v32                                  ; 68484090
	v_add_u32_e32 v37, v36, v4                                  ; 684a0924
	v_add_u32_e32 v36, v36, v38                                 ; 68484d24
	buffer_load_dwordx3 v[39:41], v32, s[12:15], 0 offen        ; e0581000 80032720
	buffer_load_ushort v35, v35, s[12:15], 0 offen              ; e0481000 80032323
	buffer_load_dword v37, v37, s[12:15], 0 offen               ; e0501000 80032525
	buffer_load_dword v36, v36, s[12:15], 0 offen               ; e0501000 80032424
	s_mov_b32 s1, 0xf0f0f0f                                     ; be8100ff 0f0f0f0f
	s_cmp_lt_u32 5, s4                                          ; bf0a0485
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_cndmask_b32_sdwa v42, v40, v40, vcc dst_sel:WORD_0 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 005450f9 06051428
	v_cndmask_b32_sdwa v42, v41, v41, vcc dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 005452f9 06051529
	v_cvt_f32_f16_sdwa v47, v39 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e5e16f9 00050627
	v_cvt_f32_f16_e32 v39, v39                                  ; 7e4e1727
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_lshl_or_b32 v35, v35, 12, v35                             ; d2000023 048d1923
	v_and_b32_e32 v43, 0xc0c0c0c0, v42                          ; 265654ff c0c0c0c0
	v_and_b32_e32 v42, 0x3f3f3f3f, v42                          ; 265454ff 3f3f3f3f
	v_lshrrev_b32_e32 v43, 2, v43                               ; 20565682
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v51, s1, v37                                  ; 26664a01
	v_cvt_f32_ubyte3_e32 v44, v42                               ; 7e58292a
	v_cvt_f32_ubyte2_e32 v45, v42                               ; 7e5a272a
	v_cvt_f32_ubyte1_e32 v46, v42                               ; 7e5c252a
	v_cvt_f32_ubyte0_e32 v42, v42                               ; 7e54232a
	v_and_or_b32 v35, s1, v35, v43                              ; d2010023 04ae4601
	v_cvt_f32_ubyte3_e32 v52, v51                               ; 7e682933
	v_cvt_f32_ubyte2_e32 v53, v51                               ; 7e6a2733
	v_cvt_f32_ubyte1_e32 v54, v51                               ; 7e6c2533
	v_cvt_f32_ubyte0_e32 v51, v51                               ; 7e662333
	v_cvt_f32_ubyte1_e32 v50, v35                               ; 7e642523
	v_cvt_f32_ubyte3_e32 v48, v35                               ; 7e602923
	v_cvt_f32_ubyte2_e32 v49, v35                               ; 7e622723
	v_cvt_f32_ubyte0_e32 v35, v35                               ; 7e462323
	v_mul_f32_e32 v52, v19, v52                                 ; 0a686913
	v_lshrrev_b32_e32 v37, 4, v37                               ; 204a4a84
	v_mul_f32_e32 v48, v31, v48                                 ; 0a60611f
	v_mac_f32_e32 v52, v18, v53                                 ; 2c686b12
	v_and_b32_e32 v37, s1, v37                                  ; 264a4a01
	v_mac_f32_e32 v48, v30, v49                                 ; 2c60631e
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v58, s1, v36                                  ; 26744801
	v_mac_f32_e32 v52, v17, v54                                 ; 2c686d11
	v_cvt_f32_ubyte1_e32 v57, v37                               ; 7e722525
	v_cvt_f32_ubyte3_e32 v55, v37                               ; 7e6e2925
	v_cvt_f32_ubyte2_e32 v56, v37                               ; 7e702725
	v_cvt_f32_ubyte0_e32 v37, v37                               ; 7e4a2325
	v_mac_f32_e32 v48, v29, v44                                 ; 2c60591d
	v_cvt_f32_ubyte2_e32 v60, v58                               ; 7e78273a
	v_cvt_f32_ubyte3_e32 v59, v58                               ; 7e76293a
	v_mac_f32_e32 v52, v16, v51                                 ; 2c686710
	v_cvt_f32_ubyte1_e32 v61, v58                               ; 7e7a253a
	v_mul_f32_e32 v55, v23, v55                                 ; 0a6e6f17
	v_cvt_f32_ubyte0_e32 v58, v58                               ; 7e74233a
	v_lshrrev_b32_e32 v36, 4, v36                               ; 20484884
	v_mac_f32_e32 v48, v28, v45                                 ; 2c605b1c
	v_mul_f32_e32 v59, v27, v59                                 ; 0a76771b
	v_mac_f32_e32 v55, v22, v56                                 ; 2c6e7116
	v_and_b32_e32 v36, s1, v36                                  ; 26484801
	v_mad_f32 v8, -v47, v48, v8                                 ; d1c10008 2422612f
	v_mac_f32_e32 v59, v26, v60                                 ; 2c76791a
	v_mac_f32_e32 v55, v21, v57                                 ; 2c6e7315
	v_cvt_f32_ubyte3_e32 v62, v36                               ; 7e7c2924
	v_cvt_f32_ubyte2_e32 v32, v36                               ; 7e402724
	v_cvt_f32_ubyte1_e32 v33, v36                               ; 7e422524
	v_cvt_f32_ubyte0_e32 v36, v36                               ; 7e482324
	v_mac_f32_e32 v59, v25, v61                                 ; 2c767b19
	v_mac_f32_e32 v55, v20, v37                                 ; 2c6e4b14
	v_mul_f32_e32 v62, v15, v62                                 ; 0a7c7d0f
	v_mac_f32_e32 v59, v24, v58                                 ; 2c767518
	v_mac_f32_e32 v62, v14, v32                                 ; 2c7c410e
	v_mac_f32_e32 v62, v13, v33                                 ; 2c7c430d
	v_mac_f32_e32 v62, v12, v36                                 ; 2c7c490c
	v_mul_f32_e32 v62, v62, v50                                 ; 0a7c653e
	v_mac_f32_e32 v62, v59, v35                                 ; 2c7c473b
	v_mac_f32_e32 v62, v55, v46                                 ; 2c7c5d37
	v_mac_f32_e32 v62, v52, v42                                 ; 2c7c5534
	v_mac_f32_e32 v8, v39, v62                                  ; 2c107d27
	s_cbranch_scc0 BB100                                        ; bf84012d
BB82:
	s_add_u32 s0, s16, 5                                        ; 80008510
	s_mul_i32 s0, s0, s3                                        ; 92000300
	s_add_u32 s0, s19, s0                                       ; 80000013
	v_add_u32_e32 v32, s0, v0                                   ; 68400000
	v_lshlrev_b32_e32 v33, 4, v32                               ; 24424084
	v_lshl_add_u32 v32, v32, 7, v33                             ; d1fd0020 04850f20
	v_add3_u32 v35, v34, 4, v32                                 ; d1ff0023 04810922
	v_add_u32_e32 v36, 16, v32                                  ; 68484090
	v_add_u32_e32 v37, v36, v4                                  ; 684a0924
	v_add_u32_e32 v36, v36, v38                                 ; 68484d24
	buffer_load_dwordx3 v[39:41], v32, s[12:15], 0 offen        ; e0581000 80032720
	buffer_load_ushort v35, v35, s[12:15], 0 offen              ; e0481000 80032323
	buffer_load_dword v37, v37, s[12:15], 0 offen               ; e0501000 80032525
	buffer_load_dword v36, v36, s[12:15], 0 offen               ; e0501000 80032424
	s_mov_b32 s1, 0xf0f0f0f                                     ; be8100ff 0f0f0f0f
	s_cmp_lt_u32 6, s4                                          ; bf0a0486
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_cndmask_b32_sdwa v42, v40, v40, vcc dst_sel:WORD_0 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 005450f9 06051428
	v_cndmask_b32_sdwa v42, v41, v41, vcc dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 005452f9 06051529
	v_cvt_f32_f16_sdwa v47, v39 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e5e16f9 00050627
	v_cvt_f32_f16_e32 v39, v39                                  ; 7e4e1727
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_lshl_or_b32 v35, v35, 12, v35                             ; d2000023 048d1923
	v_and_b32_e32 v43, 0xc0c0c0c0, v42                          ; 265654ff c0c0c0c0
	v_and_b32_e32 v42, 0x3f3f3f3f, v42                          ; 265454ff 3f3f3f3f
	v_lshrrev_b32_e32 v43, 2, v43                               ; 20565682
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v51, s1, v37                                  ; 26664a01
	v_cvt_f32_ubyte3_e32 v44, v42                               ; 7e58292a
	v_cvt_f32_ubyte2_e32 v45, v42                               ; 7e5a272a
	v_cvt_f32_ubyte1_e32 v46, v42                               ; 7e5c252a
	v_cvt_f32_ubyte0_e32 v42, v42                               ; 7e54232a
	v_and_or_b32 v35, s1, v35, v43                              ; d2010023 04ae4601
	v_cvt_f32_ubyte3_e32 v52, v51                               ; 7e682933
	v_cvt_f32_ubyte2_e32 v53, v51                               ; 7e6a2733
	v_cvt_f32_ubyte1_e32 v54, v51                               ; 7e6c2533
	v_cvt_f32_ubyte0_e32 v51, v51                               ; 7e662333
	v_cvt_f32_ubyte1_e32 v50, v35                               ; 7e642523
	v_cvt_f32_ubyte3_e32 v48, v35                               ; 7e602923
	v_cvt_f32_ubyte2_e32 v49, v35                               ; 7e622723
	v_cvt_f32_ubyte0_e32 v35, v35                               ; 7e462323
	v_mul_f32_e32 v52, v19, v52                                 ; 0a686913
	v_lshrrev_b32_e32 v37, 4, v37                               ; 204a4a84
	v_mul_f32_e32 v48, v31, v48                                 ; 0a60611f
	v_mac_f32_e32 v52, v18, v53                                 ; 2c686b12
	v_and_b32_e32 v37, s1, v37                                  ; 264a4a01
	v_mac_f32_e32 v48, v30, v49                                 ; 2c60631e
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v58, s1, v36                                  ; 26744801
	v_mac_f32_e32 v52, v17, v54                                 ; 2c686d11
	v_cvt_f32_ubyte1_e32 v57, v37                               ; 7e722525
	v_cvt_f32_ubyte3_e32 v55, v37                               ; 7e6e2925
	v_cvt_f32_ubyte2_e32 v56, v37                               ; 7e702725
	v_cvt_f32_ubyte0_e32 v37, v37                               ; 7e4a2325
	v_mac_f32_e32 v48, v29, v44                                 ; 2c60591d
	v_cvt_f32_ubyte2_e32 v60, v58                               ; 7e78273a
	v_cvt_f32_ubyte3_e32 v59, v58                               ; 7e76293a
	v_mac_f32_e32 v52, v16, v51                                 ; 2c686710
	v_cvt_f32_ubyte1_e32 v61, v58                               ; 7e7a253a
	v_mul_f32_e32 v55, v23, v55                                 ; 0a6e6f17
	v_cvt_f32_ubyte0_e32 v58, v58                               ; 7e74233a
	v_lshrrev_b32_e32 v36, 4, v36                               ; 20484884
	v_mac_f32_e32 v48, v28, v45                                 ; 2c605b1c
	v_mul_f32_e32 v59, v27, v59                                 ; 0a76771b
	v_mac_f32_e32 v55, v22, v56                                 ; 2c6e7116
	v_and_b32_e32 v36, s1, v36                                  ; 26484801
	v_mad_f32 v9, -v47, v48, v9                                 ; d1c10009 2426612f
	v_mac_f32_e32 v59, v26, v60                                 ; 2c76791a
	v_mac_f32_e32 v55, v21, v57                                 ; 2c6e7315
	v_cvt_f32_ubyte3_e32 v62, v36                               ; 7e7c2924
	v_cvt_f32_ubyte2_e32 v32, v36                               ; 7e402724
	v_cvt_f32_ubyte1_e32 v33, v36                               ; 7e422524
	v_cvt_f32_ubyte0_e32 v36, v36                               ; 7e482324
	v_mac_f32_e32 v59, v25, v61                                 ; 2c767b19
	v_mac_f32_e32 v55, v20, v37                                 ; 2c6e4b14
	v_mul_f32_e32 v62, v15, v62                                 ; 0a7c7d0f
	v_mac_f32_e32 v59, v24, v58                                 ; 2c767518
	v_mac_f32_e32 v62, v14, v32                                 ; 2c7c410e
	v_mac_f32_e32 v62, v13, v33                                 ; 2c7c430d
	v_mac_f32_e32 v62, v12, v36                                 ; 2c7c490c
	v_mul_f32_e32 v62, v62, v50                                 ; 0a7c653e
	v_mac_f32_e32 v62, v59, v35                                 ; 2c7c473b
	v_mac_f32_e32 v62, v55, v46                                 ; 2c7c5d37
	v_mac_f32_e32 v62, v52, v42                                 ; 2c7c5534
	v_mac_f32_e32 v9, v39, v62                                  ; 2c127d27
	s_cbranch_scc0 BB100                                        ; bf8400c8
BB83:
	s_add_u32 s0, s16, 6                                        ; 80008610
	s_mul_i32 s0, s0, s3                                        ; 92000300
	s_add_u32 s0, s19, s0                                       ; 80000013
	v_add_u32_e32 v32, s0, v0                                   ; 68400000
	v_lshlrev_b32_e32 v33, 4, v32                               ; 24424084
	v_lshl_add_u32 v32, v32, 7, v33                             ; d1fd0020 04850f20
	v_add3_u32 v35, v34, 4, v32                                 ; d1ff0023 04810922
	v_add_u32_e32 v36, 16, v32                                  ; 68484090
	v_add_u32_e32 v37, v36, v4                                  ; 684a0924
	v_add_u32_e32 v36, v36, v38                                 ; 68484d24
	buffer_load_dwordx3 v[39:41], v32, s[12:15], 0 offen        ; e0581000 80032720
	buffer_load_ushort v35, v35, s[12:15], 0 offen              ; e0481000 80032323
	buffer_load_dword v37, v37, s[12:15], 0 offen               ; e0501000 80032525
	buffer_load_dword v36, v36, s[12:15], 0 offen               ; e0501000 80032424
	s_mov_b32 s1, 0xf0f0f0f                                     ; be8100ff 0f0f0f0f
	s_cmp_lt_u32 7, s4                                          ; bf0a0487
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_cndmask_b32_sdwa v42, v40, v40, vcc dst_sel:WORD_0 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 005450f9 06051428
	v_cndmask_b32_sdwa v42, v41, v41, vcc dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 005452f9 06051529
	v_cvt_f32_f16_sdwa v47, v39 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e5e16f9 00050627
	v_cvt_f32_f16_e32 v39, v39                                  ; 7e4e1727
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_lshl_or_b32 v35, v35, 12, v35                             ; d2000023 048d1923
	v_and_b32_e32 v43, 0xc0c0c0c0, v42                          ; 265654ff c0c0c0c0
	v_and_b32_e32 v42, 0x3f3f3f3f, v42                          ; 265454ff 3f3f3f3f
	v_lshrrev_b32_e32 v43, 2, v43                               ; 20565682
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v51, s1, v37                                  ; 26664a01
	v_cvt_f32_ubyte3_e32 v44, v42                               ; 7e58292a
	v_cvt_f32_ubyte2_e32 v45, v42                               ; 7e5a272a
	v_cvt_f32_ubyte1_e32 v46, v42                               ; 7e5c252a
	v_cvt_f32_ubyte0_e32 v42, v42                               ; 7e54232a
	v_and_or_b32 v35, s1, v35, v43                              ; d2010023 04ae4601
	v_cvt_f32_ubyte3_e32 v52, v51                               ; 7e682933
	v_cvt_f32_ubyte2_e32 v53, v51                               ; 7e6a2733
	v_cvt_f32_ubyte1_e32 v54, v51                               ; 7e6c2533
	v_cvt_f32_ubyte0_e32 v51, v51                               ; 7e662333
	v_cvt_f32_ubyte1_e32 v50, v35                               ; 7e642523
	v_cvt_f32_ubyte3_e32 v48, v35                               ; 7e602923
	v_cvt_f32_ubyte2_e32 v49, v35                               ; 7e622723
	v_cvt_f32_ubyte0_e32 v35, v35                               ; 7e462323
	v_mul_f32_e32 v52, v19, v52                                 ; 0a686913
	v_lshrrev_b32_e32 v37, 4, v37                               ; 204a4a84
	v_mul_f32_e32 v48, v31, v48                                 ; 0a60611f
	v_mac_f32_e32 v52, v18, v53                                 ; 2c686b12
	v_and_b32_e32 v37, s1, v37                                  ; 264a4a01
	v_mac_f32_e32 v48, v30, v49                                 ; 2c60631e
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v58, s1, v36                                  ; 26744801
	v_mac_f32_e32 v52, v17, v54                                 ; 2c686d11
	v_cvt_f32_ubyte1_e32 v57, v37                               ; 7e722525
	v_cvt_f32_ubyte3_e32 v55, v37                               ; 7e6e2925
	v_cvt_f32_ubyte2_e32 v56, v37                               ; 7e702725
	v_cvt_f32_ubyte0_e32 v37, v37                               ; 7e4a2325
	v_mac_f32_e32 v48, v29, v44                                 ; 2c60591d
	v_cvt_f32_ubyte2_e32 v60, v58                               ; 7e78273a
	v_cvt_f32_ubyte3_e32 v59, v58                               ; 7e76293a
	v_mac_f32_e32 v52, v16, v51                                 ; 2c686710
	v_cvt_f32_ubyte1_e32 v61, v58                               ; 7e7a253a
	v_mul_f32_e32 v55, v23, v55                                 ; 0a6e6f17
	v_cvt_f32_ubyte0_e32 v58, v58                               ; 7e74233a
	v_lshrrev_b32_e32 v36, 4, v36                               ; 20484884
	v_mac_f32_e32 v48, v28, v45                                 ; 2c605b1c
	v_mul_f32_e32 v59, v27, v59                                 ; 0a76771b
	v_mac_f32_e32 v55, v22, v56                                 ; 2c6e7116
	v_and_b32_e32 v36, s1, v36                                  ; 26484801
	v_mad_f32 v10, -v47, v48, v10                               ; d1c1000a 242a612f
	v_mac_f32_e32 v59, v26, v60                                 ; 2c76791a
	v_mac_f32_e32 v55, v21, v57                                 ; 2c6e7315
	v_cvt_f32_ubyte3_e32 v62, v36                               ; 7e7c2924
	v_cvt_f32_ubyte2_e32 v32, v36                               ; 7e402724
	v_cvt_f32_ubyte1_e32 v33, v36                               ; 7e422524
	v_cvt_f32_ubyte0_e32 v36, v36                               ; 7e482324
	v_mac_f32_e32 v59, v25, v61                                 ; 2c767b19
	v_mac_f32_e32 v55, v20, v37                                 ; 2c6e4b14
	v_mul_f32_e32 v62, v15, v62                                 ; 0a7c7d0f
	v_mac_f32_e32 v59, v24, v58                                 ; 2c767518
	v_mac_f32_e32 v62, v14, v32                                 ; 2c7c410e
	v_mac_f32_e32 v62, v13, v33                                 ; 2c7c430d
	v_mac_f32_e32 v62, v12, v36                                 ; 2c7c490c
	v_mul_f32_e32 v62, v62, v50                                 ; 0a7c653e
	v_mac_f32_e32 v62, v59, v35                                 ; 2c7c473b
	v_mac_f32_e32 v62, v55, v46                                 ; 2c7c5d37
	v_mac_f32_e32 v62, v52, v42                                 ; 2c7c5534
	v_mac_f32_e32 v10, v39, v62                                 ; 2c147d27
	s_cbranch_scc0 BB100                                        ; bf840063
BB84:
	s_add_u32 s0, s16, 7                                        ; 80008710
	s_mul_i32 s0, s0, s3                                        ; 92000300
	s_add_u32 s0, s19, s0                                       ; 80000013
	v_add_u32_e32 v32, s0, v0                                   ; 68400000
	v_lshlrev_b32_e32 v33, 4, v32                               ; 24424084
	v_lshl_add_u32 v32, v32, 7, v33                             ; d1fd0020 04850f20
	v_add3_u32 v34, v34, 4, v32                                 ; d1ff0022 04810922
	v_add_u32_e32 v35, 16, v32                                  ; 68464090
	v_add_u32_e32 v36, v35, v4                                  ; 68480923
	v_add_u32_e32 v35, v35, v38                                 ; 68464d23
	buffer_load_dwordx3 v[37:39], v32, s[12:15], 0 offen        ; e0581000 80032520
	buffer_load_ushort v34, v34, s[12:15], 0 offen              ; e0481000 80032222
	buffer_load_dword v36, v36, s[12:15], 0 offen               ; e0501000 80032424
	buffer_load_dword v35, v35, s[12:15], 0 offen               ; e0501000 80032323
	s_mov_b32 s1, 0xf0f0f0f                                     ; be8100ff 0f0f0f0f
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_cvt_f32_f16_sdwa v45, v37 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e5a16f9 00050625
	v_cvt_f32_f16_e32 v37, v37                                  ; 7e4a1725
	v_cndmask_b32_sdwa v40, v38, v38, vcc dst_sel:WORD_0 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 00504cf9 06051426
	v_cndmask_b32_sdwa v40, v39, v39, vcc dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 00504ef9 06051527
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_lshl_or_b32 v34, v34, 12, v34                             ; d2000022 04891922
	v_and_b32_e32 v41, 0xc0c0c0c0, v40                          ; 265250ff c0c0c0c0
	v_and_b32_e32 v40, 0x3f3f3f3f, v40                          ; 265050ff 3f3f3f3f
	v_lshrrev_b32_e32 v41, 2, v41                               ; 20525282
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v49, s1, v36                                  ; 26624801
	v_cvt_f32_ubyte3_e32 v42, v40                               ; 7e542928
	v_cvt_f32_ubyte2_e32 v43, v40                               ; 7e562728
	v_cvt_f32_ubyte1_e32 v44, v40                               ; 7e582528
	v_cvt_f32_ubyte0_e32 v40, v40                               ; 7e502328
	v_and_or_b32 v34, s1, v34, v41                              ; d2010022 04a64401
	v_cvt_f32_ubyte3_e32 v50, v49                               ; 7e642931
	v_cvt_f32_ubyte2_e32 v51, v49                               ; 7e662731
	v_cvt_f32_ubyte1_e32 v52, v49                               ; 7e682531
	v_cvt_f32_ubyte0_e32 v49, v49                               ; 7e622331
	v_cvt_f32_ubyte1_e32 v48, v34                               ; 7e602522
	v_cvt_f32_ubyte3_e32 v46, v34                               ; 7e5c2922
	v_cvt_f32_ubyte2_e32 v47, v34                               ; 7e5e2722
	v_cvt_f32_ubyte0_e32 v34, v34                               ; 7e442322
	v_mul_f32_e32 v19, v19, v50                                 ; 0a266513
	v_lshrrev_b32_e32 v36, 4, v36                               ; 20484884
	v_mul_f32_e32 v31, v31, v46                                 ; 0a3e5d1f
	v_mac_f32_e32 v19, v18, v51                                 ; 2c266712
	v_and_b32_e32 v36, s1, v36                                  ; 26484801
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v56, s1, v35                                  ; 26704601
	v_mac_f32_e32 v31, v30, v47                                 ; 2c3e5f1e
	v_mac_f32_e32 v19, v17, v52                                 ; 2c266911
	v_cvt_f32_ubyte1_e32 v55, v36                               ; 7e6e2524
	v_cvt_f32_ubyte3_e32 v53, v36                               ; 7e6a2924
	v_cvt_f32_ubyte2_e32 v54, v36                               ; 7e6c2724
	v_cvt_f32_ubyte0_e32 v36, v36                               ; 7e482324
	v_cvt_f32_ubyte3_e32 v57, v56                               ; 7e722938
	v_cvt_f32_ubyte2_e32 v58, v56                               ; 7e742738
	v_mac_f32_e32 v31, v29, v42                                 ; 2c3e551d
	v_mac_f32_e32 v19, v16, v49                                 ; 2c266310
	v_cvt_f32_ubyte1_e32 v59, v56                               ; 7e762538
	v_mul_f32_e32 v23, v23, v53                                 ; 0a2e6b17
	v_cvt_f32_ubyte0_e32 v56, v56                               ; 7e702338
	v_lshrrev_b32_e32 v35, 4, v35                               ; 20464684
	v_mul_f32_e32 v27, v27, v57                                 ; 0a36731b
	v_mac_f32_e32 v31, v28, v43                                 ; 2c3e571c
	v_mac_f32_e32 v23, v22, v54                                 ; 2c2e6d16
	v_and_b32_e32 v35, s1, v35                                  ; 26464601
	v_mac_f32_e32 v27, v26, v58                                 ; 2c36751a
	v_mad_f32 v11, -v45, v31, v11                               ; d1c1000b 242e3f2d
	v_mac_f32_e32 v23, v21, v55                                 ; 2c2e6f15
	v_cvt_f32_ubyte3_e32 v60, v35                               ; 7e782923
	v_cvt_f32_ubyte2_e32 v61, v35                               ; 7e7a2723
	v_cvt_f32_ubyte1_e32 v62, v35                               ; 7e7c2523
	v_cvt_f32_ubyte0_e32 v35, v35                               ; 7e462323
	v_mac_f32_e32 v27, v25, v59                                 ; 2c367719
	v_mac_f32_e32 v23, v20, v36                                 ; 2c2e4914
	v_mul_f32_e32 v15, v15, v60                                 ; 0a1e790f
	v_mac_f32_e32 v27, v24, v56                                 ; 2c367118
	v_mac_f32_e32 v15, v14, v61                                 ; 2c1e7b0e
	v_mac_f32_e32 v15, v13, v62                                 ; 2c1e7d0d
	v_mac_f32_e32 v15, v12, v35                                 ; 2c1e470c
	v_mul_f32_e32 v15, v15, v48                                 ; 0a1e610f
	v_mac_f32_e32 v15, v27, v34                                 ; 2c1e451b
	v_mac_f32_e32 v15, v23, v44                                 ; 2c1e5917
	v_mac_f32_e32 v15, v19, v40                                 ; 2c1e5113
	v_mac_f32_e32 v11, v37, v15                                 ; 2c161f25
BB100:
	v_add_u32_e32 v0, 4, v0                                     ; 68000084
	s_branch BB71                                               ; bf82fca2
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
