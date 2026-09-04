BB0:
	s_load_dword s0, s[14:15], 0x0                              ; c0020007 00000000
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_mul_i32 s0, s0, s18                                       ; 92001200
	s_add_u32 s16, s16, s0                                      ; 80100010
	s_lshl_b32 s16, s16, 3                                      ; 8e108310
	s_add_u32 s1, s16, 8                                        ; 80018810
	s_cmp_ge_u32 s4, s1                                         ; bf090104
	s_cbranch_scc0 BB72                                         ; bf840546
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
	s_cbranch_execz BB14                                        ; bf88031e
BB5:
	s_mov_b32 s0, s2                                            ; be800002
	s_movk_i32 s1, 0x8000                                       ; b0018000
	s_load_dwordx8 s[24:31], s[0:1], 0x0                        ; c00e0600 00000000
	s_mul_i32 s6, s6, s17                                       ; 92061106
	s_mul_i32 s0, s16, s3                                       ; 92000310
	s_add_u32 s0, s18, s0                                       ; 80000012
	s_add_u32 s1, s16, 1                                        ; 80018110
	s_mul_i32 s1, s1, s3                                        ; 92010301
	s_add_u32 s1, s18, s1                                       ; 80010112
	s_add_u32 s4, s16, 2                                        ; 80048210
	s_mul_i32 s4, s4, s3                                        ; 92040304
	s_add_u32 s4, s18, s4                                       ; 80040412
	s_add_u32 s5, s16, 3                                        ; 80058310
	v_lshlrev_b32_e32 v2, 4, v2                                 ; 24040484
	v_add_u32_e32 v3, 64, v4                                    ; 680608c0
	s_bitreplicate_b64_b32 vcc, 0xf0f0f0f                       ; beea37ff 0f0f0f0f
	s_mul_i32 s5, s5, s3                                        ; 92050305
	v_mov_b32_e32 v5, 0                                         ; 7e0a0280
	v_mov_b32_e32 v6, 0                                         ; 7e0c0280
	v_mov_b32_e32 v7, 0                                         ; 7e0e0280
	s_add_u32 s5, s18, s5                                       ; 80050512
	s_add_u32 s9, s16, 4                                        ; 80098410
	v_mov_b32_e32 v8, 0                                         ; 7e100280
	v_mov_b32_e32 v9, 0                                         ; 7e120280
	v_mov_b32_e32 v10, 0                                        ; 7e140280
	v_mov_b32_e32 v11, 0                                        ; 7e160280
	s_mul_i32 s9, s9, s3                                        ; 92090309
	v_mov_b32_e32 v12, 0                                        ; 7e180280
	s_add_u32 s9, s18, s9                                       ; 80090912
	s_add_u32 s10, s16, 5                                       ; 800a8510
	s_mul_i32 s10, s10, s3                                      ; 920a030a
	s_add_u32 s10, s18, s10                                     ; 800a0a12
	s_add_u32 s11, s16, 6                                       ; 800b8610
	s_mul_i32 s11, s11, s3                                      ; 920b030b
	s_add_u32 s11, s18, s11                                     ; 800b0b12
	s_add_u32 s12, s16, 7                                       ; 800c8710
	s_mul_i32 s12, s12, s3                                      ; 920c030c
	s_add_u32 s18, s18, s12                                     ; 80120c12
	s_mov_b64 s[12:13], exec                                    ; be8c017e
BB6:
	v_lshl_add_u32 v13, v0, 8, v1                               ; d1fd000d 04051100
	v_add_u32_e32 v14, s6, v13                                  ; 681c1a06
	v_add_u32_e32 v13, 0x80, v13                                ; 681a1aff 00000080
	v_lshrrev_b32_e32 v14, 2, v14                               ; 201c1c82
	v_add_u32_e32 v13, s6, v13                                  ; 681a1a06
	v_lshlrev_b32_e32 v14, 4, v14                               ; 241c1c84
	v_lshrrev_b32_e32 v13, 2, v13                               ; 201a1a82
	v_lshlrev_b32_e32 v13, 4, v13                               ; 241a1a84
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_load_dwordx4 v[16:19], v14, s[28:31], 0 offen        ; e05c1000 8007100e
	buffer_load_dwordx4 v[20:23], v14, s[28:31], 0 offen offset:128 ; e05c1080 8007140e
	buffer_load_dwordx4 v[24:27], v13, s[28:31], 0 offen        ; e05c1000 8007180d
	buffer_load_dwordx4 v[28:31], v13, s[28:31], 0 offen offset:128 ; e05c1080 80071c0d
	v_add_u32_e32 v15, s0, v0                                   ; 681e0000
	v_add_u32_e32 v35, s1, v0                                   ; 68460001
	v_add_u32_e32 v39, s4, v0                                   ; 684e0004
	v_lshlrev_b32_e32 v32, 4, v15                               ; 24401e84
	v_lshlrev_b32_e32 v36, 4, v35                               ; 24484684
	v_add_u32_e32 v43, s5, v0                                   ; 68560005
	v_lshlrev_b32_e32 v40, 4, v39                               ; 24504e84
	v_lshl_add_u32 v15, v15, 7, v32                             ; d1fd000f 04810f0f
	v_lshl_add_u32 v35, v35, 7, v36                             ; d1fd0023 04910f23
	v_lshlrev_b32_e32 v44, 4, v43                               ; 24585684
	v_lshl_add_u32 v39, v39, 7, v40                             ; d1fd0027 04a10f27
	v_add_u32_e32 v33, 16, v15                                  ; 68421e90
	v_add_u32_e32 v37, 16, v35                                  ; 684a4690
	v_lshl_add_u32 v43, v43, 7, v44                             ; d1fd002b 04b10f2b
	v_add_u32_e32 v41, 16, v39                                  ; 68524e90
	v_add_u32_e32 v34, v33, v4                                  ; 68440921
	v_add_u32_e32 v33, v33, v3                                  ; 68420721
	v_add_u32_e32 v38, v37, v4                                  ; 684c0925
	v_add_u32_e32 v37, v37, v3                                  ; 684a0725
	v_add_u32_e32 v45, 16, v43                                  ; 685a5690
	v_add_u32_e32 v42, v41, v4                                  ; 68540929
	v_add_u32_e32 v41, v41, v3                                  ; 68520729
	v_mov_b32_e32 v47, v12                                      ; 7e5e030c
	v_add_u32_e32 v46, v45, v4                                  ; 685c092d
	v_add_u32_e32 v45, v45, v3                                  ; 685a072d
	buffer_load_dwordx4 v[48:51], v15, s[24:27], 0 offen        ; e05c1000 8006300f
	buffer_load_dword v34, v34, s[24:27], 0 offen               ; e0501000 80062222
	buffer_load_dword v33, v33, s[24:27], 0 offen               ; e0501000 80062121
	buffer_load_dwordx4 v[52:55], v35, s[24:27], 0 offen        ; e05c1000 80063423
	buffer_load_dword v38, v38, s[24:27], 0 offen               ; e0501000 80062626
	buffer_load_dword v37, v37, s[24:27], 0 offen               ; e0501000 80062525
	buffer_load_dwordx4 v[56:59], v39, s[24:27], 0 offen        ; e05c1000 80063827
	buffer_load_dword v42, v42, s[24:27], 0 offen               ; e0501000 80062a2a
	buffer_load_dword v41, v41, s[24:27], 0 offen               ; e0501000 80062929
	buffer_load_dwordx4 v[12:15], v43, s[24:27], 0 offen        ; e05c1000 80060c2b
	buffer_load_dword v46, v46, s[24:27], 0 offen               ; e0501000 80062e2e
	buffer_load_dword v45, v45, s[24:27], 0 offen               ; e0501000 80062d2d
	s_mov_b32 s14, 0xf0f0f0f                                    ; be8e00ff 0f0f0f0f
	s_mov_b32 s15, 0xc0c0c0c0                                   ; be8f00ff c0c0c0c0
	s_mov_b32 s19, 0x3f3f3f3f                                   ; be9300ff 3f3f3f3f
	v_add_u32_e32 v60, s9, v0                                   ; 68780009
	s_waitcnt vmcnt(15)                                         ; bf8c3f7f
	v_add_f32_e32 v61, v16, v17                                 ; 027a2310
	s_waitcnt vmcnt(14)                                         ; bf8c3f7e
	v_add_f32_e32 v62, v20, v21                                 ; 027c2b14
	s_waitcnt vmcnt(13)                                         ; bf8c3f7d
	v_add_f32_e32 v32, v24, v25                                 ; 02403318
	v_add_f32_e32 v61, v61, v18                                 ; 027a253d
	v_add_f32_e32 v62, v62, v22                                 ; 027c2d3e
	s_waitcnt vmcnt(12)                                         ; bf8c3f7c
	v_add_f32_e32 v35, v28, v29                                 ; 02463b1c
	v_add_f32_e32 v32, v32, v26                                 ; 02403520
	v_add_f32_e32 v61, v61, v19                                 ; 027a273d
	v_add_f32_e32 v62, v62, v23                                 ; 027c2f3e
	v_add_f32_e32 v35, v35, v30                                 ; 02463d23
	v_add_f32_e32 v32, v32, v27                                 ; 02403720
	v_add_f32_e32 v35, v35, v31                                 ; 02463f23
	s_waitcnt vmcnt(11)                                         ; bf8c3f7b
	v_bfe_u32 v51, v51, v2, 16                                  ; d1c80033 02420533
	v_cndmask_b32_sdwa v36, v49, v49, vcc dst_sel:WORD_0 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 004862f9 06051431
	v_cndmask_b32_sdwa v36, v50, v50, vcc dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 004864f9 06051532
	s_waitcnt vmcnt(10)                                         ; bf8c3f7a
	v_and_b32_e32 v40, s14, v34                                 ; 2650440e
	v_lshrrev_b32_e32 v34, 4, v34                               ; 20444484
	v_lshl_or_b32 v51, v51, 12, v51                             ; d2000033 04cd1933
	v_and_b32_e32 v39, s15, v36                                 ; 264e480f
	v_cvt_f32_ubyte2_e32 v44, v40                               ; 7e582728
	v_cvt_f32_ubyte1_e32 v49, v40                               ; 7e622528
	v_cvt_f32_ubyte3_e32 v43, v40                               ; 7e562928
	v_cvt_f32_ubyte0_e32 v40, v40                               ; 7e502328
	v_and_b32_e32 v34, s14, v34                                 ; 2644440e
	v_lshrrev_b32_e32 v39, 2, v39                               ; 204e4e82
	v_mul_f32_e32 v43, v19, v43                                 ; 0a565713
	v_cvt_f32_ubyte3_e32 v50, v34                               ; 7e642922
	v_and_or_b32 v51, s14, v51, v39                             ; d2010033 049e660e
	v_cvt_f32_ubyte2_e32 v39, v34                               ; 7e4e2722
	v_mac_f32_e32 v43, v18, v44                                 ; 2c565912
	s_waitcnt vmcnt(9)                                          ; bf8c3f79
	v_and_b32_e32 v44, s14, v33                                 ; 2658420e
	v_mul_f32_e32 v50, v23, v50                                 ; 0a646517
	v_mac_f32_e32 v43, v17, v49                                 ; 2c566311
	v_cvt_f32_ubyte3_e32 v49, v44                               ; 7e62292c
	v_lshrrev_b32_e32 v33, 4, v33                               ; 20424284
	v_mac_f32_e32 v50, v22, v39                                 ; 2c644f16
	v_cvt_f32_ubyte1_e32 v39, v44                               ; 7e4e252c
	v_mac_f32_e32 v43, v16, v40                                 ; 2c565110
	v_cvt_f32_ubyte1_e32 v40, v34                               ; 7e502522
	v_cvt_f32_ubyte0_e32 v34, v34                               ; 7e442322
	v_mul_f32_e32 v49, v27, v49                                 ; 0a62631b
	v_and_b32_e32 v33, s14, v33                                 ; 2642420e
	v_mac_f32_e32 v50, v21, v40                                 ; 2c645115
	v_cvt_f32_ubyte3_e32 v40, v33                               ; 7e502921
	v_mac_f32_e32 v50, v20, v34                                 ; 2c644514
	v_cvt_f32_ubyte2_e32 v34, v44                               ; 7e44272c
	v_cvt_f32_ubyte0_e32 v44, v44                               ; 7e58232c
	v_mul_f32_e32 v40, v31, v40                                 ; 0a50511f
	v_and_b32_e32 v36, s19, v36                                 ; 26484813
	v_mac_f32_e32 v49, v26, v34                                 ; 2c62451a
	v_cvt_f32_ubyte1_e32 v34, v33                               ; 7e442521
	v_mac_f32_e32 v49, v25, v39                                 ; 2c624f19
	v_cvt_f32_ubyte3_e32 v39, v51                               ; 7e4e2933
	v_mac_f32_e32 v49, v24, v44                                 ; 2c625918
	v_cvt_f32_ubyte2_e32 v44, v33                               ; 7e582721
	v_cvt_f32_ubyte0_e32 v33, v33                               ; 7e422321
	v_mul_f32_e32 v39, v35, v39                                 ; 0a4e4f23
	v_mac_f32_e32 v40, v30, v44                                 ; 2c50591e
	v_cvt_f32_ubyte2_e32 v44, v51                               ; 7e582733
	v_mac_f32_e32 v40, v29, v34                                 ; 2c50451d
	v_cvt_f32_ubyte2_e32 v34, v36                               ; 7e442724
	v_mac_f32_e32 v39, v32, v44                                 ; 2c4e5920
	v_cvt_f32_ubyte1_e32 v44, v51                               ; 7e582533
	v_cvt_f32_ubyte0_e32 v51, v51                               ; 7e662333
	v_mac_f32_e32 v40, v28, v33                                 ; 2c50431c
	v_cvt_f32_ubyte3_e32 v33, v36                               ; 7e422924
	v_mul_f32_e32 v40, v40, v44                                 ; 0a505928
	v_mac_f32_e32 v39, v62, v33                                 ; 2c4e433e
	v_mac_f32_e32 v40, v49, v51                                 ; 2c506731
	v_cvt_f32_ubyte1_e32 v49, v36                               ; 7e622524
	v_cvt_f32_ubyte0_e32 v36, v36                               ; 7e482324
	v_mac_f32_e32 v39, v61, v34                                 ; 2c4e453d
	v_mov_b32_e32 v34, v48                                      ; 7e440330
	v_mac_f32_e32 v40, v50, v49                                 ; 2c506332
	v_lshlrev_b32_e32 v50, 4, v60                               ; 24647884
	v_mac_f32_e32 v40, v43, v36                                 ; 2c50492b
	v_lshl_add_u32 v60, v60, 7, v50                             ; d1fd003c 04c90f3c
	v_add_u32_e32 v51, 16, v60                                  ; 68667890
	v_add_u32_e32 v33, v51, v4                                  ; 68420933
	v_add_u32_e32 v51, v51, v3                                  ; 68660733
	v_mov_b32_e32 v36, v51                                      ; 7e480333
	buffer_load_dwordx4 v[48:51], v60, s[24:27], 0 offen        ; e05c1000 8006303c
	buffer_load_dword v33, v33, s[24:27], 0 offen               ; e0501000 80062121
	buffer_load_dword v36, v36, s[24:27], 0 offen               ; e0501000 80062424
	v_add_u32_e32 v44, s10, v0                                  ; 6858000a
	v_cvt_f32_f16_sdwa v43, v34 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e5616f9 00050622
	s_waitcnt vmcnt(11)                                         ; bf8c3f7b
	v_bfe_u32 v55, v55, v2, 16                                  ; d1c80037 02420537
	v_cvt_f32_f16_e32 v34, v34                                  ; 7e441722
	v_cndmask_b32_sdwa v53, v53, v53, vcc dst_sel:WORD_0 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 006a6af9 06051435
	v_cndmask_b32_sdwa v53, v54, v54, vcc dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 006a6cf9 06051536
	s_waitcnt vmcnt(10)                                         ; bf8c3f7a
	v_and_b32_e32 v60, s14, v38                                 ; 26784c0e
	v_mad_f32 v5, -v43, v39, v5                                 ; d1c10005 24164f2b
	v_lshl_or_b32 v55, v55, 12, v55                             ; d2000037 04dd1937
	v_lshrrev_b32_e32 v38, 4, v38                               ; 204c4c84
	v_and_b32_e32 v54, s15, v53                                 ; 266c6a0f
	v_cvt_f32_ubyte2_e32 v39, v60                               ; 7e4e273c
	v_mac_f32_e32 v5, v34, v40                                  ; 2c0a5122
	v_cvt_f32_ubyte1_e32 v40, v60                               ; 7e50253c
	v_cvt_f32_ubyte3_e32 v34, v60                               ; 7e44293c
	v_cvt_f32_ubyte0_e32 v60, v60                               ; 7e78233c
	v_and_b32_e32 v38, s14, v38                                 ; 264c4c0e
	v_lshrrev_b32_e32 v54, 2, v54                               ; 206c6c82
	v_mul_f32_e32 v34, v19, v34                                 ; 0a444513
	v_cvt_f32_ubyte3_e32 v43, v38                               ; 7e562926
	v_and_or_b32 v55, s14, v55, v54                             ; d2010037 04da6e0e
	v_cvt_f32_ubyte2_e32 v54, v38                               ; 7e6c2726
	v_mac_f32_e32 v34, v18, v39                                 ; 2c444f12
	v_mul_f32_e32 v43, v23, v43                                 ; 0a565717
	v_mac_f32_e32 v34, v17, v40                                 ; 2c445111
	v_mac_f32_e32 v43, v22, v54                                 ; 2c566d16
	v_mac_f32_e32 v34, v16, v60                                 ; 2c447910
	v_cvt_f32_ubyte1_e32 v60, v38                               ; 7e782526
	v_cvt_f32_ubyte0_e32 v38, v38                               ; 7e4c2326
	v_mac_f32_e32 v43, v21, v60                                 ; 2c567915
	v_mac_f32_e32 v43, v20, v38                                 ; 2c564d14
	s_waitcnt vmcnt(9)                                          ; bf8c3f79
	v_and_b32_e32 v38, s14, v37                                 ; 264c4a0e
	v_lshrrev_b32_e32 v37, 4, v37                               ; 204a4a84
	v_cvt_f32_ubyte2_e32 v40, v38                               ; 7e502726
	v_cvt_f32_ubyte1_e32 v54, v38                               ; 7e6c2526
	v_cvt_f32_ubyte3_e32 v39, v38                               ; 7e4e2926
	v_cvt_f32_ubyte0_e32 v38, v38                               ; 7e4c2326
	v_and_b32_e32 v37, s14, v37                                 ; 264a4a0e
	v_mul_f32_e32 v39, v27, v39                                 ; 0a4e4f1b
	v_cvt_f32_ubyte3_e32 v60, v37                               ; 7e782925
	v_and_b32_e32 v53, s19, v53                                 ; 266a6a13
	v_mac_f32_e32 v39, v26, v40                                 ; 2c4e511a
	v_cvt_f32_ubyte1_e32 v40, v37                               ; 7e502525
	v_mul_f32_e32 v60, v31, v60                                 ; 0a78791f
	v_mac_f32_e32 v39, v25, v54                                 ; 2c4e6d19
	v_cvt_f32_ubyte3_e32 v54, v55                               ; 7e6c2937
	v_mac_f32_e32 v39, v24, v38                                 ; 2c4e4d18
	v_cvt_f32_ubyte2_e32 v38, v37                               ; 7e4c2725
	v_cvt_f32_ubyte0_e32 v37, v37                               ; 7e4a2325
	v_mul_f32_e32 v54, v35, v54                                 ; 0a6c6d23
	v_mac_f32_e32 v60, v30, v38                                 ; 2c784d1e
	v_cvt_f32_ubyte3_e32 v38, v53                               ; 7e4c2935
	v_mac_f32_e32 v60, v29, v40                                 ; 2c78511d
	v_cvt_f32_ubyte2_e32 v40, v53                               ; 7e502735
	v_mac_f32_e32 v60, v28, v37                                 ; 2c784b1c
	v_cvt_f32_ubyte2_e32 v37, v55                               ; 7e4a2737
	v_mac_f32_e32 v54, v32, v37                                 ; 2c6c4b20
	v_cvt_f32_ubyte1_e32 v37, v55                               ; 7e4a2537
	v_cvt_f32_ubyte0_e32 v55, v55                               ; 7e6e2337
	v_mac_f32_e32 v54, v62, v38                                 ; 2c6c4d3e
	v_cvt_f32_ubyte1_e32 v38, v53                               ; 7e4c2535
	v_cvt_f32_ubyte0_e32 v53, v53                               ; 7e6a2335
	v_mul_f32_e32 v60, v60, v37                                 ; 0a784b3c
	v_mac_f32_e32 v54, v61, v40                                 ; 2c6c513d
	v_mac_f32_e32 v60, v39, v55                                 ; 2c786f27
	v_lshlrev_b32_e32 v39, 4, v44                               ; 244e5884
	v_mac_f32_e32 v60, v43, v38                                 ; 2c784d2b
	v_lshl_add_u32 v44, v44, 7, v39                             ; d1fd002c 049d0f2c
	v_mac_f32_e32 v60, v34, v53                                 ; 2c786b22
	v_add_u32_e32 v40, 16, v44                                  ; 68505890
	v_add_u32_e32 v43, v40, v4                                  ; 68560928
	v_add_u32_e32 v40, v40, v3                                  ; 68500728
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_mov_b32_e32 v34, v36                                      ; 7e440324
	buffer_load_dwordx4 v[36:39], v44, s[24:27], 0 offen        ; e05c1000 8006242c
	buffer_load_dword v43, v43, s[24:27], 0 offen               ; e0501000 80062b2b
	buffer_load_dword v40, v40, s[24:27], 0 offen               ; e0501000 80062828
	v_cvt_f32_f16_sdwa v44, v52 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e5816f9 00050634
	v_cvt_f32_f16_e32 v52, v52                                  ; 7e681734
	v_bfe_u32 v59, v59, v2, 16                                  ; d1c8003b 0242053b
	v_cndmask_b32_sdwa v53, v57, v57, vcc dst_sel:WORD_0 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 006a72f9 06051439
	v_cndmask_b32_sdwa v53, v58, v58, vcc dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 006a74f9 0605153a
	v_and_b32_e32 v55, s14, v42                                 ; 266e540e
	v_mad_f32 v6, -v44, v54, v6                                 ; d1c10006 241a6d2c
	v_lshl_or_b32 v59, v59, 12, v59                             ; d200003b 04ed193b
	v_lshrrev_b32_e32 v42, 4, v42                               ; 20545484
	v_and_b32_e32 v54, s15, v53                                 ; 266c6a0f
	v_cvt_f32_ubyte2_e32 v58, v55                               ; 7e742737
	v_cvt_f32_ubyte3_e32 v57, v55                               ; 7e722937
	v_mac_f32_e32 v6, v52, v60                                  ; 2c0c7934
	v_add_u32_e32 v52, s11, v0                                  ; 6868000b
	v_cvt_f32_ubyte1_e32 v60, v55                               ; 7e782537
	v_cvt_f32_ubyte0_e32 v55, v55                               ; 7e6e2337
	v_and_b32_e32 v42, s14, v42                                 ; 2654540e
	v_lshrrev_b32_e32 v54, 2, v54                               ; 206c6c82
	v_mul_f32_e32 v57, v19, v57                                 ; 0a727313
	v_cvt_f32_ubyte3_e32 v44, v42                               ; 7e58292a
	v_and_or_b32 v59, s14, v59, v54                             ; d201003b 04da760e
	v_cvt_f32_ubyte2_e32 v54, v42                               ; 7e6c272a
	v_mac_f32_e32 v57, v18, v58                                 ; 2c727512
	v_and_b32_e32 v58, s14, v41                                 ; 2674520e
	v_mul_f32_e32 v44, v23, v44                                 ; 0a585917
	v_mac_f32_e32 v57, v17, v60                                 ; 2c727911
	v_cvt_f32_ubyte3_e32 v60, v58                               ; 7e78293a
	v_lshrrev_b32_e32 v41, 4, v41                               ; 20525284
	v_mac_f32_e32 v44, v22, v54                                 ; 2c586d16
	v_cvt_f32_ubyte1_e32 v54, v58                               ; 7e6c253a
	v_mac_f32_e32 v57, v16, v55                                 ; 2c726f10
	v_cvt_f32_ubyte1_e32 v55, v42                               ; 7e6e252a
	v_cvt_f32_ubyte0_e32 v42, v42                               ; 7e54232a
	v_mul_f32_e32 v60, v27, v60                                 ; 0a78791b
	v_and_b32_e32 v41, s14, v41                                 ; 2652520e
	v_mac_f32_e32 v44, v21, v55                                 ; 2c586f15
	v_cvt_f32_ubyte3_e32 v55, v41                               ; 7e6e2929
	v_mac_f32_e32 v44, v20, v42                                 ; 2c585514
	v_cvt_f32_ubyte2_e32 v42, v58                               ; 7e54273a
	v_cvt_f32_ubyte0_e32 v58, v58                               ; 7e74233a
	v_mul_f32_e32 v55, v31, v55                                 ; 0a6e6f1f
	v_and_b32_e32 v53, s19, v53                                 ; 266a6a13
	v_mac_f32_e32 v60, v26, v42                                 ; 2c78551a
	v_cvt_f32_ubyte1_e32 v42, v41                               ; 7e542529
	v_mac_f32_e32 v60, v25, v54                                 ; 2c786d19
	v_cvt_f32_ubyte3_e32 v54, v59                               ; 7e6c293b
	v_mac_f32_e32 v60, v24, v58                                 ; 2c787518
	v_cvt_f32_ubyte2_e32 v58, v41                               ; 7e742729
	v_cvt_f32_ubyte0_e32 v41, v41                               ; 7e522329
	v_mul_f32_e32 v54, v35, v54                                 ; 0a6c6d23
	v_mac_f32_e32 v55, v30, v58                                 ; 2c6e751e
	v_cvt_f32_ubyte2_e32 v58, v59                               ; 7e74273b
	v_mac_f32_e32 v55, v29, v42                                 ; 2c6e551d
	v_cvt_f32_ubyte2_e32 v42, v53                               ; 7e542735
	v_mac_f32_e32 v54, v32, v58                                 ; 2c6c7520
	v_cvt_f32_ubyte1_e32 v58, v59                               ; 7e74253b
	v_cvt_f32_ubyte0_e32 v59, v59                               ; 7e76233b
	v_mac_f32_e32 v55, v28, v41                                 ; 2c6e531c
	v_cvt_f32_ubyte3_e32 v41, v53                               ; 7e522935
	v_bfe_u32 v15, v15, v2, 16                                  ; d1c8000f 0242050f
	v_cndmask_b32_sdwa v13, v13, v13, vcc dst_sel:WORD_0 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 001a1af9 0605140d
	v_cndmask_b32_sdwa v13, v14, v14, vcc dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 001a1cf9 0605150e
	v_mul_f32_e32 v55, v55, v58                                 ; 0a6e7537
	v_mac_f32_e32 v54, v62, v41                                 ; 2c6c533e
	v_lshl_or_b32 v15, v15, 12, v15                             ; d200000f 043d190f
	v_and_b32_e32 v14, s15, v13                                 ; 261c1a0f
	v_and_b32_e32 v41, s14, v46                                 ; 26525c0e
	v_mac_f32_e32 v55, v60, v59                                 ; 2c6e773c
	v_cvt_f32_ubyte1_e32 v59, v53                               ; 7e762535
	v_cvt_f32_ubyte0_e32 v53, v53                               ; 7e6a2335
	v_cvt_f32_f16_sdwa v60, v56 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e7816f9 00050638
	v_cvt_f32_f16_e32 v56, v56                                  ; 7e701738
	v_mac_f32_e32 v54, v61, v42                                 ; 2c6c553d
	v_mac_f32_e32 v55, v44, v59                                 ; 2c6e772c
	v_lshlrev_b32_e32 v44, 4, v52                               ; 24586884
	v_mad_f32 v7, -v60, v54, v7                                 ; d1c10007 241e6d3c
	v_mac_f32_e32 v55, v57, v53                                 ; 2c6e6b39
	v_lshl_add_u32 v52, v52, 7, v44                             ; d1fd0034 04b10f34
	v_mac_f32_e32 v7, v56, v55                                  ; 2c0e6f38
	buffer_load_dwordx4 v[56:59], v52, s[24:27], 0 offen        ; e05c1000 80063834
	v_lshrrev_b32_e32 v14, 2, v14                               ; 201c1c82
	v_add_u32_e32 v52, 16, v52                                  ; 68686890
	v_cvt_f32_ubyte3_e32 v42, v41                               ; 7e542929
	v_add_u32_e32 v60, v52, v4                                  ; 68780934
	v_add_u32_e32 v52, v52, v3                                  ; 68680734
	buffer_load_dword v60, v60, s[24:27], 0 offen               ; e0501000 80063c3c
	buffer_load_dword v52, v52, s[24:27], 0 offen               ; e0501000 80063434
	v_cvt_f32_ubyte2_e32 v53, v41                               ; 7e6a2729
	v_cvt_f32_ubyte1_e32 v54, v41                               ; 7e6c2529
	v_cvt_f32_ubyte0_e32 v41, v41                               ; 7e522329
	v_lshrrev_b32_e32 v46, 4, v46                               ; 205c5c84
	v_and_or_b32 v15, s14, v15, v14                             ; d201000f 043a1e0e
	v_mul_f32_e32 v42, v19, v42                                 ; 0a545513
	v_and_b32_e32 v44, s14, v45                                 ; 26585a0e
	v_and_b32_e32 v46, s14, v46                                 ; 265c5c0e
	v_mac_f32_e32 v42, v18, v53                                 ; 2c546b12
	v_cvt_f32_ubyte2_e32 v53, v44                               ; 7e6a272c
	v_cvt_f32_ubyte2_e32 v14, v46                               ; 7e1c272e
	v_cvt_f32_ubyte3_e32 v55, v46                               ; 7e6e292e
	v_mac_f32_e32 v42, v17, v54                                 ; 2c546d11
	v_cvt_f32_ubyte1_e32 v54, v44                               ; 7e6c252c
	v_lshrrev_b32_e32 v45, 4, v45                               ; 205a5a84
	v_mul_f32_e32 v55, v23, v55                                 ; 0a6e6f17
	v_mac_f32_e32 v42, v16, v41                                 ; 2c545310
	v_cvt_f32_ubyte1_e32 v41, v46                               ; 7e52252e
	v_cvt_f32_ubyte0_e32 v46, v46                               ; 7e5c232e
	v_and_b32_e32 v45, s14, v45                                 ; 265a5a0e
	v_mac_f32_e32 v55, v22, v14                                 ; 2c6e1d16
	v_cvt_f32_ubyte3_e32 v14, v45                               ; 7e1c292d
	v_mac_f32_e32 v55, v21, v41                                 ; 2c6e5315
	v_cvt_f32_ubyte2_e32 v41, v45                               ; 7e52272d
	v_mul_f32_e32 v14, v31, v14                                 ; 0a1c1d1f
	v_mac_f32_e32 v55, v20, v46                                 ; 2c6e5d14
	v_cvt_f32_ubyte3_e32 v46, v44                               ; 7e5c292c
	v_cvt_f32_ubyte0_e32 v44, v44                               ; 7e58232c
	v_and_b32_e32 v13, s19, v13                                 ; 261a1a13
	v_mac_f32_e32 v14, v30, v41                                 ; 2c1c531e
	v_mul_f32_e32 v46, v27, v46                                 ; 0a5c5d1b
	v_cvt_f32_ubyte2_e32 v41, v13                               ; 7e52270d
	v_mac_f32_e32 v46, v26, v53                                 ; 2c5c6b1a
	v_cvt_f32_ubyte2_e32 v53, v15                               ; 7e6a270f
	v_mac_f32_e32 v46, v25, v54                                 ; 2c5c6d19
	v_cvt_f32_ubyte3_e32 v54, v13                               ; 7e6c290d
	v_mac_f32_e32 v46, v24, v44                                 ; 2c5c5918
	v_cvt_f32_ubyte1_e32 v44, v45                               ; 7e58252d
	v_cvt_f32_ubyte0_e32 v45, v45                               ; 7e5a232d
	v_mac_f32_e32 v14, v29, v44                                 ; 2c1c591d
	v_cvt_f32_ubyte1_e32 v44, v15                               ; 7e58250f
	v_mac_f32_e32 v14, v28, v45                                 ; 2c1c5b1c
	v_cvt_f32_ubyte3_e32 v45, v15                               ; 7e5a290f
	v_cvt_f32_ubyte0_e32 v15, v15                               ; 7e1e230f
	v_mul_f32_e32 v14, v14, v44                                 ; 0a1c590e
	v_bfe_u32 v51, v51, v2, 16                                  ; d1c80033 02420533
	v_mul_f32_e32 v45, v35, v45                                 ; 0a5a5b23
	v_mac_f32_e32 v14, v46, v15                                 ; 2c1c1f2e
	v_cvt_f32_ubyte1_e32 v46, v13                               ; 7e5c250d
	v_cvt_f32_ubyte0_e32 v13, v13                               ; 7e1a230d
	v_lshl_or_b32 v51, v51, 12, v51                             ; d2000033 04cd1933
	v_mac_f32_e32 v45, v32, v53                                 ; 2c5a6b20
	v_cvt_f32_f16_sdwa v53, v12 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e6a16f9 0005060c
	v_cvt_f32_f16_e32 v12, v12                                  ; 7e18170c
	v_mac_f32_e32 v14, v55, v46                                 ; 2c1c5d37
	v_mac_f32_e32 v45, v62, v54                                 ; 2c5a6d3e
	v_cndmask_b32_sdwa v54, v49, v49, vcc dst_sel:WORD_0 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 006c62f9 06051431
	v_cndmask_b32_sdwa v54, v50, v50, vcc dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 006c64f9 06051532
	v_mac_f32_e32 v14, v42, v13                                 ; 2c1c1b2a
	v_mac_f32_e32 v45, v61, v41                                 ; 2c5a533d
	v_mov_b32_e32 v41, v47                                      ; 7e52032f
	v_mad_f32 v8, -v53, v45, v8                                 ; d1c10008 24225b35
	v_mac_f32_e32 v8, v12, v14                                  ; 2c101d0c
	v_add_u32_e32 v14, s18, v0                                  ; 681c0012
	v_lshlrev_b32_e32 v15, 4, v14                               ; 241e1c84
	v_lshl_add_u32 v14, v14, 7, v15                             ; d1fd000e 043d0f0e
	buffer_load_dwordx4 v[44:47], v14, s[24:27], 0 offen        ; e05c1000 80062c0e
	v_and_b32_e32 v12, s14, v33                                 ; 2618420e
	v_and_b32_e32 v55, s15, v54                                 ; 266e6c0f
	v_lshrrev_b32_e32 v33, 4, v33                               ; 20424284
	v_add_u32_e32 v14, 16, v14                                  ; 681c1c90
	v_cvt_f32_ubyte2_e32 v42, v12                               ; 7e54270c
	v_add_u32_e32 v53, v14, v4                                  ; 686a090e
	v_add_u32_e32 v14, v14, v3                                  ; 681c070e
	buffer_load_dword v53, v53, s[24:27], 0 offen               ; e0501000 80063535
	buffer_load_dword v14, v14, s[24:27], 0 offen               ; e0501000 80060e0e
	v_cvt_f32_ubyte1_e32 v49, v12                               ; 7e62250c
	v_cvt_f32_ubyte3_e32 v13, v12                               ; 7e1a290c
	v_cvt_f32_ubyte0_e32 v12, v12                               ; 7e18230c
	v_lshrrev_b32_e32 v55, 2, v55                               ; 206e6e82
	v_and_b32_e32 v33, s14, v33                                 ; 2642420e
	v_and_b32_e32 v15, s14, v34                                 ; 261e440e
	v_mul_f32_e32 v13, v19, v13                                 ; 0a1a1b13
	v_and_or_b32 v51, s14, v51, v55                             ; d2010033 04de660e
	v_cvt_f32_ubyte2_e32 v55, v33                               ; 7e6e2721
	v_cvt_f32_ubyte3_e32 v50, v33                               ; 7e642921
	v_mac_f32_e32 v13, v18, v42                                 ; 2c1a5512
	v_cvt_f32_ubyte2_e32 v42, v15                               ; 7e54270f
	v_mul_f32_e32 v50, v23, v50                                 ; 0a646517
	v_mac_f32_e32 v13, v17, v49                                 ; 2c1a6311
	v_cvt_f32_ubyte1_e32 v49, v15                               ; 7e62250f
	v_lshrrev_b32_e32 v34, 4, v34                               ; 20444484
	v_mac_f32_e32 v50, v22, v55                                 ; 2c646f16
	v_mac_f32_e32 v13, v16, v12                                 ; 2c1a1910
	v_cvt_f32_ubyte1_e32 v12, v33                               ; 7e182521
	v_cvt_f32_ubyte0_e32 v33, v33                               ; 7e422321
	v_and_b32_e32 v34, s14, v34                                 ; 2644440e
	v_mac_f32_e32 v50, v21, v12                                 ; 2c641915
	v_cvt_f32_ubyte3_e32 v55, v34                               ; 7e6e2922
	v_cvt_f32_ubyte2_e32 v12, v34                               ; 7e182722
	v_mac_f32_e32 v50, v20, v33                                 ; 2c644314
	v_cvt_f32_ubyte3_e32 v33, v15                               ; 7e42290f
	v_cvt_f32_ubyte0_e32 v15, v15                               ; 7e1e230f
	v_mul_f32_e32 v55, v31, v55                                 ; 0a6e6f1f
	v_and_b32_e32 v54, s19, v54                                 ; 266c6c13
	v_mul_f32_e32 v33, v27, v33                                 ; 0a42431b
	v_mac_f32_e32 v55, v30, v12                                 ; 2c6e191e
	v_cvt_f32_ubyte2_e32 v12, v54                               ; 7e182736
	v_mac_f32_e32 v33, v26, v42                                 ; 2c42551a
	v_cvt_f32_ubyte2_e32 v42, v51                               ; 7e542733
	v_mac_f32_e32 v33, v25, v49                                 ; 2c426319
	v_cvt_f32_ubyte3_e32 v49, v54                               ; 7e622936
	v_mac_f32_e32 v33, v24, v15                                 ; 2c421f18
	v_cvt_f32_ubyte1_e32 v15, v34                               ; 7e1e2522
	v_cvt_f32_ubyte0_e32 v34, v34                               ; 7e442322
	v_mac_f32_e32 v55, v29, v15                                 ; 2c6e1f1d
	v_cvt_f32_ubyte1_e32 v15, v51                               ; 7e1e2533
	v_mac_f32_e32 v55, v28, v34                                 ; 2c6e451c
	v_cvt_f32_ubyte3_e32 v34, v51                               ; 7e442933
	v_cvt_f32_ubyte0_e32 v51, v51                               ; 7e662333
	s_waitcnt vmcnt(8)                                          ; bf8c3f78
	v_bfe_u32 v39, v39, v2, 16                                  ; d1c80027 02420527
	v_mul_f32_e32 v55, v55, v15                                 ; 0a6e1f37
	v_mul_f32_e32 v34, v35, v34                                 ; 0a444523
	v_lshl_or_b32 v39, v39, 12, v39                             ; d2000027 049d1927
	v_mac_f32_e32 v55, v33, v51                                 ; 2c6e6721
	v_cvt_f32_ubyte1_e32 v33, v54                               ; 7e422536
	v_cvt_f32_ubyte0_e32 v54, v54                               ; 7e6c2336
	v_mac_f32_e32 v34, v32, v42                                 ; 2c445520
	v_cvt_f32_f16_sdwa v42, v48 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e5416f9 00050630
	v_cvt_f32_f16_e32 v48, v48                                  ; 7e601730
	v_mac_f32_e32 v55, v50, v33                                 ; 2c6e4332
	s_waitcnt vmcnt(7)                                          ; bf8c3f77
	v_and_b32_e32 v50, s14, v43                                 ; 2664560e
	v_mac_f32_e32 v34, v62, v49                                 ; 2c44633e
	v_mac_f32_e32 v55, v13, v54                                 ; 2c6e6d0d
	v_cvt_f32_ubyte3_e32 v51, v50                               ; 7e662932
	v_cvt_f32_ubyte2_e32 v54, v50                               ; 7e6c2732
	v_mac_f32_e32 v34, v61, v12                                 ; 2c44193d
	v_lshrrev_b32_e32 v43, 4, v43                               ; 20565684
	v_mul_f32_e32 v51, v19, v51                                 ; 0a666713
	v_mad_f32 v9, -v42, v34, v9                                 ; d1c10009 2426452a
	v_and_b32_e32 v43, s14, v43                                 ; 2656560e
	v_mac_f32_e32 v51, v18, v54                                 ; 2c666d12
	v_mac_f32_e32 v9, v48, v55                                  ; 2c126f30
	v_cndmask_b32_sdwa v48, v37, v37, vcc dst_sel:WORD_0 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 00604af9 06051425
	v_cndmask_b32_sdwa v48, v38, v38, vcc dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 00604cf9 06051526
	v_cvt_f32_ubyte1_e32 v55, v50                               ; 7e6e2532
	v_cvt_f32_ubyte0_e32 v50, v50                               ; 7e642332
	v_cvt_f32_ubyte3_e32 v12, v43                               ; 7e18292b
	v_cvt_f32_ubyte1_e32 v15, v43                               ; 7e1e252b
	v_cvt_f32_ubyte2_e32 v13, v43                               ; 7e1a272b
	v_cvt_f32_ubyte0_e32 v43, v43                               ; 7e56232b
	s_waitcnt vmcnt(6)                                          ; bf8c3f76
	v_and_b32_e32 v33, s14, v40                                 ; 2642500e
	v_and_b32_e32 v49, s15, v48                                 ; 2662600f
	v_mac_f32_e32 v51, v17, v55                                 ; 2c666f11
	v_mul_f32_e32 v12, v23, v12                                 ; 0a181917
	v_cvt_f32_ubyte2_e32 v37, v33                               ; 7e4a2721
	v_cvt_f32_ubyte3_e32 v34, v33                               ; 7e442921
	v_cvt_f32_ubyte1_e32 v38, v33                               ; 7e4c2521
	v_cvt_f32_ubyte0_e32 v33, v33                               ; 7e422321
	v_lshrrev_b32_e32 v40, 4, v40                               ; 20505084
	v_lshrrev_b32_e32 v49, 2, v49                               ; 20626282
	v_mac_f32_e32 v51, v16, v50                                 ; 2c666510
	v_mac_f32_e32 v12, v22, v13                                 ; 2c181b16
	v_mul_f32_e32 v34, v27, v34                                 ; 0a44451b
	v_and_b32_e32 v40, s14, v40                                 ; 2650500e
	v_and_or_b32 v39, s14, v39, v49                             ; d2010027 04c64e0e
	v_mac_f32_e32 v12, v21, v15                                 ; 2c181f15
	v_mac_f32_e32 v34, v26, v37                                 ; 2c444b1a
	v_cvt_f32_ubyte3_e32 v42, v40                               ; 7e542928
	v_cvt_f32_ubyte1_e32 v49, v40                               ; 7e622528
	v_cvt_f32_ubyte2_e32 v54, v39                               ; 7e6c2727
	v_cvt_f32_ubyte3_e32 v50, v39                               ; 7e642927
	v_mac_f32_e32 v12, v20, v43                                 ; 2c185714
	v_cvt_f32_ubyte2_e32 v43, v40                               ; 7e562728
	v_cvt_f32_ubyte0_e32 v40, v40                               ; 7e502328
	v_and_b32_e32 v48, s19, v48                                 ; 26606013
	v_mac_f32_e32 v34, v25, v38                                 ; 2c444d19
	v_mul_f32_e32 v42, v31, v42                                 ; 0a54551f
	v_mul_f32_e32 v50, v35, v50                                 ; 0a646523
	v_cvt_f32_ubyte1_e32 v15, v39                               ; 7e1e2527
	v_cvt_f32_ubyte0_e32 v39, v39                               ; 7e4e2327
	v_cvt_f32_ubyte2_e32 v13, v48                               ; 7e1a2730
	v_cvt_f32_ubyte3_e32 v55, v48                               ; 7e6e2930
	v_mac_f32_e32 v34, v24, v33                                 ; 2c444318
	v_cvt_f32_ubyte1_e32 v33, v48                               ; 7e422530
	v_cvt_f32_ubyte0_e32 v48, v48                               ; 7e602330
	v_mac_f32_e32 v42, v30, v43                                 ; 2c54571e
	v_mac_f32_e32 v50, v32, v54                                 ; 2c646d20
	s_waitcnt vmcnt(5)                                          ; bf8c3f75
	v_bfe_u32 v59, v59, v2, 16                                  ; d1c8003b 0242053b
	v_mac_f32_e32 v42, v29, v49                                 ; 2c54631d
	v_mac_f32_e32 v50, v62, v55                                 ; 2c646f3e
	v_lshl_or_b32 v59, v59, 12, v59                             ; d200003b 04ed193b
	v_mac_f32_e32 v42, v28, v40                                 ; 2c54511c
	v_mac_f32_e32 v50, v61, v13                                 ; 2c641b3d
	s_waitcnt vmcnt(4)                                          ; bf8c3f74
	v_and_b32_e32 v38, s14, v60                                 ; 264c780e
	v_mul_f32_e32 v42, v42, v15                                 ; 0a541f2a
	v_cvt_f32_ubyte2_e32 v40, v38                               ; 7e502726
	v_mac_f32_e32 v42, v34, v39                                 ; 2c544f22
	v_cvt_f32_f16_sdwa v34, v36 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e4416f9 00050624
	v_cvt_f32_f16_e32 v36, v36                                  ; 7e481724
	v_cvt_f32_ubyte3_e32 v39, v38                               ; 7e4e2926
	v_mac_f32_e32 v42, v12, v33                                 ; 2c54430c
	v_mad_f32 v10, -v34, v50, v10                               ; d1c1000a 242a6522
	v_lshrrev_b32_e32 v60, 4, v60                               ; 20787884
	v_mul_f32_e32 v39, v19, v39                                 ; 0a4e4f13
	v_mac_f32_e32 v42, v51, v48                                 ; 2c546133
	v_and_b32_e32 v60, s14, v60                                 ; 2678780e
	v_mac_f32_e32 v39, v18, v40                                 ; 2c4e5112
	v_mac_f32_e32 v10, v36, v42                                 ; 2c145524
	v_cndmask_b32_sdwa v36, v57, v57, vcc dst_sel:WORD_0 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 004872f9 06051439
	v_cndmask_b32_sdwa v36, v58, v58, vcc dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 004874f9 0605153a
	v_cvt_f32_ubyte1_e32 v42, v38                               ; 7e542526
	v_cvt_f32_ubyte0_e32 v38, v38                               ; 7e4c2326
	v_cvt_f32_ubyte3_e32 v43, v60                               ; 7e56293c
	v_cvt_f32_ubyte1_e32 v49, v60                               ; 7e62253c
	v_cvt_f32_ubyte2_e32 v48, v60                               ; 7e60273c
	v_cvt_f32_ubyte0_e32 v60, v60                               ; 7e78233c
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_and_b32_e32 v50, s14, v52                                 ; 2664680e
	v_and_b32_e32 v37, s15, v36                                 ; 264a480f
	v_mac_f32_e32 v39, v17, v42                                 ; 2c4e5511
	v_mul_f32_e32 v43, v23, v43                                 ; 0a565717
	v_cvt_f32_ubyte2_e32 v54, v50                               ; 7e6c2732
	v_cvt_f32_ubyte1_e32 v55, v50                               ; 7e6e2532
	v_cvt_f32_ubyte3_e32 v51, v50                               ; 7e662932
	v_cvt_f32_ubyte0_e32 v50, v50                               ; 7e642332
	v_lshrrev_b32_e32 v37, 2, v37                               ; 204a4a82
	v_lshrrev_b32_e32 v52, 4, v52                               ; 20686884
	v_mac_f32_e32 v39, v16, v38                                 ; 2c4e4d10
	v_mac_f32_e32 v43, v22, v48                                 ; 2c566116
	v_mul_f32_e32 v51, v27, v51                                 ; 0a66671b
	v_and_or_b32 v59, s14, v59, v37                             ; d201003b 0496760e
	v_and_b32_e32 v52, s14, v52                                 ; 2668680e
	v_mac_f32_e32 v43, v21, v49                                 ; 2c566315
	v_mac_f32_e32 v51, v26, v54                                 ; 2c666d1a
	v_cvt_f32_ubyte2_e32 v13, v59                               ; 7e1a273b
	v_cvt_f32_ubyte3_e32 v12, v59                               ; 7e18293b
	v_cvt_f32_ubyte3_e32 v57, v52                               ; 7e722934
	v_cvt_f32_ubyte2_e32 v58, v52                               ; 7e742734
	v_mac_f32_e32 v43, v20, v60                                 ; 2c567914
	v_cvt_f32_ubyte1_e32 v60, v52                               ; 7e782534
	v_cvt_f32_ubyte0_e32 v52, v52                               ; 7e682334
	v_and_b32_e32 v36, s19, v36                                 ; 26484813
	v_mac_f32_e32 v51, v25, v55                                 ; 2c666f19
	v_mul_f32_e32 v12, v35, v12                                 ; 0a181923
	v_mul_f32_e32 v57, v31, v57                                 ; 0a72731f
	v_cvt_f32_ubyte1_e32 v34, v59                               ; 7e44253b
	v_cvt_f32_ubyte0_e32 v59, v59                               ; 7e76233b
	v_cvt_f32_ubyte1_e32 v37, v36                               ; 7e4a2524
	v_cvt_f32_ubyte2_e32 v33, v36                               ; 7e422724
	v_cvt_f32_ubyte3_e32 v15, v36                               ; 7e1e2924
	v_mac_f32_e32 v51, v24, v50                                 ; 2c666518
	v_cvt_f32_ubyte0_e32 v36, v36                               ; 7e482324
	v_mac_f32_e32 v12, v32, v13                                 ; 2c181b20
	v_mac_f32_e32 v57, v30, v58                                 ; 2c72751e
	v_cvt_f32_f16_sdwa v38, v56 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e4c16f9 00050638
	v_cvt_f32_f16_e32 v56, v56                                  ; 7e701738
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_bfe_u32 v47, v47, v2, 16                                  ; d1c8002f 0242052f
	v_mac_f32_e32 v12, v62, v15                                 ; 2c181f3e
	v_mac_f32_e32 v57, v29, v60                                 ; 2c72791d
	v_lshl_or_b32 v47, v47, 12, v47                             ; d200002f 04bd192f
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v42, s14, v53                                 ; 26546a0e
	v_mac_f32_e32 v12, v61, v33                                 ; 2c18433d
	v_mac_f32_e32 v57, v28, v52                                 ; 2c72691c
	v_mad_f32 v11, -v38, v12, v11                               ; d1c1000b 242e1926
	v_mul_f32_e32 v57, v57, v34                                 ; 0a724539
	v_mac_f32_e32 v57, v51, v59                                 ; 2c727733
	v_mac_f32_e32 v57, v43, v37                                 ; 2c724b2b
	v_cvt_f32_ubyte3_e32 v43, v42                               ; 7e56292a
	v_lshrrev_b32_e32 v53, 4, v53                               ; 206a6a84
	v_mac_f32_e32 v57, v39, v36                                 ; 2c724927
	v_cndmask_b32_sdwa v39, v45, v45, vcc dst_sel:WORD_0 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 004e5af9 0605142d
	v_cndmask_b32_sdwa v39, v46, v46, vcc dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 004e5cf9 0605152e
	v_cvt_f32_ubyte2_e32 v45, v42                               ; 7e5a272a
	v_cvt_f32_ubyte1_e32 v46, v42                               ; 7e5c252a
	v_cvt_f32_ubyte0_e32 v42, v42                               ; 7e54232a
	v_mul_f32_e32 v19, v19, v43                                 ; 0a265713
	v_and_b32_e32 v53, s14, v53                                 ; 266a6a0e
	v_mac_f32_e32 v11, v56, v57                                 ; 2c167338
	v_and_b32_e32 v40, s15, v39                                 ; 26504e0f
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v51, s14, v14                                 ; 26661c0e
	v_mac_f32_e32 v19, v18, v45                                 ; 2c265b12
	v_cvt_f32_ubyte3_e32 v48, v53                               ; 7e602935
	v_cvt_f32_ubyte2_e32 v49, v53                               ; 7e622735
	v_cvt_f32_ubyte1_e32 v50, v53                               ; 7e642535
	v_cvt_f32_ubyte0_e32 v53, v53                               ; 7e6a2335
	v_lshrrev_b32_e32 v40, 2, v40                               ; 20505082
	v_cvt_f32_ubyte3_e32 v52, v51                               ; 7e682933
	v_mac_f32_e32 v19, v17, v46                                 ; 2c265d11
	v_cvt_f32_ubyte1_e32 v54, v51                               ; 7e6c2533
	v_mul_f32_e32 v23, v23, v48                                 ; 0a2e6117
	v_lshrrev_b32_e32 v14, 4, v14                               ; 201c1c84
	v_and_or_b32 v47, s14, v47, v40                             ; d201002f 04a25e0e
	v_mul_f32_e32 v27, v27, v52                                 ; 0a36691b
	v_mac_f32_e32 v19, v16, v42                                 ; 2c265510
	v_mac_f32_e32 v23, v22, v49                                 ; 2c2e6316
	v_and_b32_e32 v14, s14, v14                                 ; 261c1c0e
	v_mac_f32_e32 v23, v21, v50                                 ; 2c2e6515
	v_cvt_f32_ubyte3_e32 v58, v47                               ; 7e74292f
	v_cvt_f32_ubyte1_e32 v57, v14                               ; 7e72250e
	v_cvt_f32_ubyte3_e32 v55, v14                               ; 7e6e290e
	v_cvt_f32_ubyte2_e32 v56, v14                               ; 7e70270e
	v_cvt_f32_ubyte0_e32 v14, v14                               ; 7e1c230e
	v_mac_f32_e32 v23, v20, v53                                 ; 2c2e6b14
	v_cvt_f32_ubyte2_e32 v53, v51                               ; 7e6a2733
	v_cvt_f32_ubyte0_e32 v51, v51                               ; 7e662333
	v_cvt_f32_ubyte2_e32 v59, v47                               ; 7e76272f
	v_mul_f32_e32 v35, v35, v58                                 ; 0a467523
	v_and_b32_e32 v39, s19, v39                                 ; 264e4e13
	v_mul_f32_e32 v31, v31, v55                                 ; 0a3e6f1f
	v_mac_f32_e32 v27, v26, v53                                 ; 2c366b1a
	v_mac_f32_e32 v35, v32, v59                                 ; 2c467720
	v_cvt_f32_ubyte3_e32 v60, v39                               ; 7e782927
	v_mac_f32_e32 v31, v30, v56                                 ; 2c3e711e
	v_mac_f32_e32 v27, v25, v54                                 ; 2c366d19
	v_mac_f32_e32 v35, v62, v60                                 ; 2c46793e
	v_cvt_f32_ubyte2_e32 v62, v39                               ; 7e7c2727
	v_mac_f32_e32 v31, v29, v57                                 ; 2c3e731d
	v_mac_f32_e32 v27, v24, v51                                 ; 2c366718
	v_add_u32_e32 v0, 4, v0                                     ; 68000084
	v_mac_f32_e32 v35, v61, v62                                 ; 2c467d3d
	v_cvt_f32_ubyte1_e32 v61, v47                               ; 7e7a252f
	v_cvt_f32_ubyte0_e32 v47, v47                               ; 7e5e232f
	v_cvt_f32_ubyte1_e32 v62, v39                               ; 7e7c2527
	v_cvt_f32_ubyte0_e32 v39, v39                               ; 7e4e2327
	v_mac_f32_e32 v31, v28, v14                                 ; 2c3e1d1c
	v_cmp_le_u32_e64 s[14:15], s3, v0                           ; d0cb000e 00020003
	v_mul_f32_e32 v31, v31, v61                                 ; 0a3e7b1f
	v_mac_f32_e32 v31, v27, v47                                 ; 2c3e5f1b
	v_mac_f32_e32 v31, v23, v62                                 ; 2c3e7d17
	v_cvt_f32_f16_sdwa v62, v44 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e7c16f9 0005062c
	v_cvt_f32_f16_e32 v44, v44                                  ; 7e58172c
	v_mac_f32_e32 v31, v19, v39                                 ; 2c3e4f13
	v_mad_f32 v12, -v62, v35, v41                               ; d1c1000c 24a6473e
	v_mac_f32_e32 v12, v44, v31                                 ; 2c183f2c
	s_and_saveexec_b64 s[14:15], s[14:15]                       ; be8e200e
BB11:
	s_andn2_wrexec_b64 s[14:15], s[14:15]                       ; be8e360e
	s_cbranch_scc1 BB6                                          ; bf85fd0c
BB12:
	s_mov_b64 exec, s[12:13]                                    ; befe010c
BB14:
	s_andn2_b64 exec, -1, exec                                  ; 89fe7ec1
	s_cbranch_execz BB17                                        ; bf880008
BB15:
	v_mov_b32_e32 v5, 0                                         ; 7e0a0280
	v_mov_b32_e32 v6, 0                                         ; 7e0c0280
	v_mov_b32_e32 v7, 0                                         ; 7e0e0280
	v_mov_b32_e32 v8, 0                                         ; 7e100280
	v_mov_b32_e32 v9, 0                                         ; 7e120280
	v_mov_b32_e32 v10, 0                                        ; 7e140280
	v_mov_b32_e32 v11, 0                                        ; 7e160280
	v_mov_b32_e32 v12, 0                                        ; 7e180280
BB17:
	s_mov_b64 exec, -1                                          ; befe01c1
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
BB18:
	s_bitcmp1_b32 s8, 0                                         ; bf0d8008
	s_cbranch_scc0 BB20                                         ; bf84000f
BB19:
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
	s_branch BB21                                               ; bf820002
BB20:
	s_mov_b32 s18, src_scc                                      ; be9200fd
	v_mov_b32_e32 v0, s0                                        ; 7e000200
BB21:
	s_bitcmp1_b32 s8, 1                                         ; bf0d8108
	s_cbranch_scc0 BB23                                         ; bf84000e
BB22:
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
	s_branch BB24                                               ; bf820001
BB23:
	s_mov_b32 s8, src_scc                                       ; be8800fd
BB24:
	s_mov_b32 s0, s3                                            ; be800003
	s_movk_i32 s3, 0x8000                                       ; b0038000
	s_load_dwordx4 s[12:15], s[2:3], 0x20                       ; c00a0301 00000020
	s_mul_i32 s7, s7, s17                                       ; 92071107
	s_add_u32 s7, s7, s16                                       ; 80071007
	s_lshl_b32 s7, s7, 2                                        ; 8e078207
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_store_dword v0, off, s[12:15], s7                    ; e0700000 07030080
	s_cmp_lg_i32 s18, 0                                         ; bf018012
	s_cbranch_scc0 BB26                                         ; bf84000b
BB25:
	s_load_dwordx4 s[16:19], s[2:3], 0x30                       ; c00a0401 00000030
	s_mov_b32 s11, src_scc                                      ; be8b00fd
	s_add_u32 s20, s7, 4                                        ; 80148407
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s20, s[16:19], s20                      ; c0200508 00000014
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_mov_b32_e32 v0, s20                                       ; 7e000214
	v_add_f32_e32 v0, s1, v0                                    ; 02000001
	s_branch BB27                                               ; bf820002
BB26:
	s_mov_b32 s11, src_scc                                      ; be8b00fd
	v_mov_b32_e32 v0, s1                                        ; 7e000201
BB27:
	s_cmp_lg_i32 s8, 0                                          ; bf018008
	s_cbranch_scc0 BB29                                         ; bf84000a
BB28:
	s_load_dwordx4 s[16:19], s[2:3], 0x40                       ; c00a0401 00000040
	s_mov_b32 s1, src_scc                                       ; be8100fd
	s_add_u32 s8, s7, 4                                         ; 80088407
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s8, s[16:19], s8                        ; c0200208 00000008
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v0, s8, v0                                    ; 02000008
	s_branch BB30                                               ; bf820001
BB29:
	s_mov_b32 s1, src_scc                                       ; be8100fd
BB30:
	s_add_u32 s8, s7, 4                                         ; 80088407
	buffer_store_dword v0, off, s[12:15], s8                    ; e0700000 08030080
	s_cmp_lg_i32 s11, 0                                         ; bf01800b
	s_cbranch_scc0 BB32                                         ; bf84000b
BB31:
	s_load_dwordx4 s[16:19], s[2:3], 0x30                       ; c00a0401 00000030
	s_mov_b32 s8, src_scc                                       ; be8800fd
	s_add_u32 s11, s7, 8                                        ; 800b8807
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s11, s[16:19], s11                      ; c02002c8 0000000b
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_mov_b32_e32 v0, s11                                       ; 7e00020b
	v_add_f32_e32 v0, s0, v0                                    ; 02000000
	s_branch BB33                                               ; bf820002
BB32:
	s_mov_b32 s8, src_scc                                       ; be8800fd
	v_mov_b32_e32 v0, s0                                        ; 7e000200
BB33:
	s_cmp_lg_i32 s1, 0                                          ; bf018001
	s_cbranch_scc0 BB35                                         ; bf84000a
BB34:
	s_load_dwordx4 s[16:19], s[2:3], 0x40                       ; c00a0401 00000040
	s_mov_b32 s0, src_scc                                       ; be8000fd
	s_add_u32 s1, s7, 8                                         ; 80018807
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s1, s[16:19], s1                        ; c0200048 00000001
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v0, s1, v0                                    ; 02000001
	s_branch BB36                                               ; bf820001
BB35:
	s_mov_b32 s0, src_scc                                       ; be8000fd
BB36:
	s_add_u32 s1, s7, 8                                         ; 80018807
	buffer_store_dword v0, off, s[12:15], s1                    ; e0700000 01030080
	s_cmp_lg_i32 s8, 0                                          ; bf018008
	s_cbranch_scc0 BB38                                         ; bf84000b
BB37:
	s_load_dwordx4 s[16:19], s[2:3], 0x30                       ; c00a0401 00000030
	s_mov_b32 s1, src_scc                                       ; be8100fd
	s_add_u32 s8, s7, 12                                        ; 80088c07
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s8, s[16:19], s8                        ; c0200208 00000008
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_mov_b32_e32 v0, s8                                        ; 7e000208
	v_add_f32_e32 v0, s4, v0                                    ; 02000004
	s_branch BB39                                               ; bf820002
BB38:
	s_mov_b32 s1, src_scc                                       ; be8100fd
	v_mov_b32_e32 v0, s4                                        ; 7e000204
BB39:
	s_cmp_lg_i32 s0, 0                                          ; bf018000
	s_cbranch_scc0 BB41                                         ; bf84000a
BB40:
	s_load_dwordx4 s[16:19], s[2:3], 0x40                       ; c00a0401 00000040
	s_mov_b32 s0, src_scc                                       ; be8000fd
	s_add_u32 s4, s7, 12                                        ; 80048c07
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s4, s[16:19], s4                        ; c0200108 00000004
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v0, s4, v0                                    ; 02000004
	s_branch BB42                                               ; bf820001
BB41:
	s_mov_b32 s0, src_scc                                       ; be8000fd
BB42:
	s_add_u32 s4, s7, 12                                        ; 80048c07
	buffer_store_dword v0, off, s[12:15], s4                    ; e0700000 04030080
	s_cmp_lg_i32 s1, 0                                          ; bf018001
	s_cbranch_scc0 BB44                                         ; bf84000b
BB43:
	s_load_dwordx4 s[16:19], s[2:3], 0x30                       ; c00a0401 00000030
	s_mov_b32 s1, src_scc                                       ; be8100fd
	s_add_u32 s4, s7, 16                                        ; 80049007
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s4, s[16:19], s4                        ; c0200108 00000004
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_mov_b32_e32 v0, s4                                        ; 7e000204
	v_add_f32_e32 v0, s5, v0                                    ; 02000005
	s_branch BB45                                               ; bf820002
BB44:
	s_mov_b32 s1, src_scc                                       ; be8100fd
	v_mov_b32_e32 v0, s5                                        ; 7e000205
BB45:
	s_cmp_lg_i32 s0, 0                                          ; bf018000
	s_cbranch_scc0 BB47                                         ; bf84000a
BB46:
	s_load_dwordx4 s[16:19], s[2:3], 0x40                       ; c00a0401 00000040
	s_mov_b32 s0, src_scc                                       ; be8000fd
	s_add_u32 s4, s7, 16                                        ; 80049007
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s4, s[16:19], s4                        ; c0200108 00000004
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v0, s4, v0                                    ; 02000004
	s_branch BB48                                               ; bf820001
BB47:
	s_mov_b32 s0, src_scc                                       ; be8000fd
BB48:
	s_add_u32 s4, s7, 16                                        ; 80049007
	buffer_store_dword v0, off, s[12:15], s4                    ; e0700000 04030080
	s_cmp_lg_i32 s1, 0                                          ; bf018001
	s_cbranch_scc0 BB50                                         ; bf84000b
BB49:
	s_load_dwordx4 s[16:19], s[2:3], 0x30                       ; c00a0401 00000030
	s_mov_b32 s1, src_scc                                       ; be8100fd
	s_add_u32 s4, s7, 20                                        ; 80049407
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s4, s[16:19], s4                        ; c0200108 00000004
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_mov_b32_e32 v0, s4                                        ; 7e000204
	v_add_f32_e32 v0, s6, v0                                    ; 02000006
	s_branch BB51                                               ; bf820002
BB50:
	s_mov_b32 s1, src_scc                                       ; be8100fd
	v_mov_b32_e32 v0, s6                                        ; 7e000206
BB51:
	s_cmp_lg_i32 s0, 0                                          ; bf018000
	s_cbranch_scc0 BB53                                         ; bf84000a
BB52:
	s_load_dwordx4 s[16:19], s[2:3], 0x40                       ; c00a0401 00000040
	s_mov_b32 s0, src_scc                                       ; be8000fd
	s_add_u32 s4, s7, 20                                        ; 80049407
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s4, s[16:19], s4                        ; c0200108 00000004
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v0, s4, v0                                    ; 02000004
	s_branch BB54                                               ; bf820001
BB53:
	s_mov_b32 s0, src_scc                                       ; be8000fd
BB54:
	s_add_u32 s4, s7, 20                                        ; 80049407
	buffer_store_dword v0, off, s[12:15], s4                    ; e0700000 04030080
	s_cmp_lg_i32 s1, 0                                          ; bf018001
	s_cbranch_scc0 BB56                                         ; bf84000b
BB55:
	s_load_dwordx4 s[16:19], s[2:3], 0x30                       ; c00a0401 00000030
	s_mov_b32 s1, src_scc                                       ; be8100fd
	s_add_u32 s4, s7, 24                                        ; 80049807
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s4, s[16:19], s4                        ; c0200108 00000004
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_mov_b32_e32 v0, s4                                        ; 7e000204
	v_add_f32_e32 v0, s9, v0                                    ; 02000009
	s_branch BB57                                               ; bf820002
BB56:
	s_mov_b32 s1, src_scc                                       ; be8100fd
	v_mov_b32_e32 v0, s9                                        ; 7e000209
BB57:
	s_cmp_lg_i32 s0, 0                                          ; bf018000
	s_cbranch_scc0 BB59                                         ; bf84000a
BB58:
	s_load_dwordx4 s[16:19], s[2:3], 0x40                       ; c00a0401 00000040
	s_mov_b32 s0, src_scc                                       ; be8000fd
	s_add_u32 s4, s7, 24                                        ; 80049807
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s4, s[16:19], s4                        ; c0200108 00000004
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v0, s4, v0                                    ; 02000004
	s_branch BB60                                               ; bf820001
BB59:
	s_mov_b32 s0, src_scc                                       ; be8000fd
BB60:
	s_add_u32 s4, s7, 24                                        ; 80049807
	buffer_store_dword v0, off, s[12:15], s4                    ; e0700000 04030080
	s_cmp_lg_i32 s1, 0                                          ; bf018001
	s_cbranch_scc0 BB62                                         ; bf84000a
BB61:
	s_load_dwordx4 s[16:19], s[2:3], 0x30                       ; c00a0401 00000030
	s_add_u32 s1, s7, 28                                        ; 80019c07
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s1, s[16:19], s1                        ; c0200048 00000001
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_mov_b32_e32 v0, s1                                        ; 7e000201
	v_add_f32_e32 v0, s10, v0                                   ; 0200000a
	s_branch BB63                                               ; bf820001
BB62:
	v_mov_b32_e32 v0, s10                                       ; 7e00020a
BB63:
	s_cmp_lg_i32 s0, 0                                          ; bf018000
	s_cbranch_scc0 BB66                                         ; bf840008
BB64:
	s_load_dwordx4 s[0:3], s[2:3], 0x40                         ; c00a0001 00000040
	s_add_u32 s4, s7, 28                                        ; 80049c07
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s4, s[0:3], s4                          ; c0200100 00000004
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v0, s4, v0                                    ; 02000004
BB66:
	s_add_u32 s7, s7, 28                                        ; 80079c07
	buffer_store_dword v0, off, s[12:15], s7                    ; e0700000 07030080
	s_branch BB215                                              ; bf820596
BB72:
	s_cmp_lt_u32 s16, s4                                        ; bf0a0410
	s_cbranch_scc0 BB215                                        ; bf840594
BB73:
	s_sub_i32 s4, s4, s16                                       ; 81841004
	s_add_u32 s17, s17, s9                                      ; 80110911
	s_cmp_lg_i32 s17, 0                                         ; bf018011
	s_cbranch_scc0 BB75                                         ; bf840043
BB74:
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
	s_branch BB76                                               ; bf820001
BB75:
	s_mov_b32 s19, 0                                            ; be930080
BB76:
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
	s_cbranch_execz BB110                                       ; bf880353
BB77:
	s_mov_b32 s0, s2                                            ; be800002
	s_movk_i32 s1, 0x8000                                       ; b0018000
	s_load_dwordx4 s[12:15], s[0:1], 0x10                       ; c00a0300 00000010
	s_mul_i32 s6, s6, s17                                       ; 92061106
	v_lshlrev_b32_e32 v2, 4, v2                                 ; 24040484
	s_cmp_lg_i32 s4, 0                                          ; bf018004
	s_mov_b64 s[10:11], exec                                    ; be8a017e
	v_mov_b32_e32 v3, 0                                         ; 7e060280
	v_mov_b32_e32 v5, 0                                         ; 7e0a0280
	v_mov_b32_e32 v6, 0                                         ; 7e0c0280
	v_mov_b32_e32 v7, 0                                         ; 7e0e0280
	v_mov_b32_e32 v8, 0                                         ; 7e100280
	v_mov_b32_e32 v9, 0                                         ; 7e120280
	v_mov_b32_e32 v10, 0                                        ; 7e140280
	v_mov_b32_e32 v11, 0                                        ; 7e160280
	s_branch BB78                                               ; bf820002
BB107:
	s_mov_b64 exec, s[20:21]                                    ; befe0114
	s_cmp_lg_i32 s9, 0                                          ; bf018009
BB78:
	v_lshl_add_u32 v12, v0, 8, v1                               ; d1fd000c 04051100
	v_add_u32_e32 v13, s6, v12                                  ; 681a1806
	v_add_u32_e32 v12, 0x80, v12                                ; 681818ff 00000080
	v_lshrrev_b32_e32 v13, 2, v13                               ; 201a1a82
	v_add_u32_e32 v12, s6, v12                                  ; 68181806
	v_lshlrev_b32_e32 v13, 4, v13                               ; 241a1a84
	v_lshrrev_b32_e32 v12, 2, v12                               ; 20181882
	v_lshlrev_b32_e32 v12, 4, v12                               ; 24181884
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_load_dwordx4 v[16:19], v13, s[12:15], 0 offen        ; e05c1000 8003100d
	buffer_load_dwordx4 v[20:23], v13, s[12:15], 0 offen offset:128 ; e05c1080 8003140d
	buffer_load_dwordx4 v[24:27], v12, s[12:15], 0 offen        ; e05c1000 8003180c
	buffer_load_dwordx4 v[12:15], v12, s[12:15], 0 offen offset:128 ; e05c1080 80030c0c
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_add_f32_e32 v28, v16, v17                                 ; 02382310
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_add_f32_e32 v29, v20, v21                                 ; 023a2b14
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_add_f32_e32 v30, v24, v25                                 ; 023c3318
	v_add_f32_e32 v28, v28, v18                                 ; 0238251c
	v_add_f32_e32 v29, v29, v22                                 ; 023a2d1d
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_add_f32_e32 v31, v12, v13                                 ; 023e1b0c
	v_add_f32_e32 v30, v30, v26                                 ; 023c351e
	v_add_f32_e32 v28, v28, v19                                 ; 0238271c
	v_add_f32_e32 v29, v29, v23                                 ; 023a2f1d
	v_add_f32_e32 v31, v31, v14                                 ; 023e1d1f
	v_add_f32_e32 v30, v30, v27                                 ; 023c371e
	v_add_f32_e32 v31, v31, v15                                 ; 023e1f1f
	s_cbranch_scc0 BB101                                        ; bf840315
BB79:
	s_load_dwordx4 s[20:23], s[0:1], 0x0                        ; c00a0500 00000000
	s_mul_i32 s5, s16, s3                                       ; 92050310
	s_mov_b32 s9, src_scc                                       ; be8900fd
	v_add_u32_e32 v36, 64, v4                                   ; 684808c0
	s_add_u32 s5, s19, s5                                       ; 80050513
	v_add_u32_e32 v32, s5, v0                                   ; 68400005
	v_lshlrev_b32_e32 v33, 4, v32                               ; 24424084
	v_lshl_add_u32 v32, v32, 7, v33                             ; d1fd0020 04850f20
	v_add_u32_e32 v34, 16, v32                                  ; 68444090
	v_add_u32_e32 v35, v34, v4                                  ; 68460922
	v_add_u32_e32 v34, v34, v36                                 ; 68444922
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_load_dwordx4 v[40:43], v32, s[20:23], 0 offen        ; e05c1000 80052820
	buffer_load_dword v35, v35, s[20:23], 0 offen               ; e0501000 80052323
	buffer_load_dword v34, v34, s[20:23], 0 offen               ; e0501000 80052222
	s_bitreplicate_b64_b32 vcc, 0xf0f0f0f                       ; beea37ff 0f0f0f0f
	s_mov_b32 s18, 0xf0f0f0f                                    ; be9200ff 0f0f0f0f
	s_cmp_lt_u32 1, s4                                          ; bf0a0481
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_bfe_u32 v43, v43, v2, 16                                  ; d1c8002b 0242052b
	v_cndmask_b32_sdwa v37, v41, v41, vcc dst_sel:WORD_0 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 004a52f9 06051429
	v_cndmask_b32_sdwa v37, v42, v42, vcc dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 004a54f9 0605152a
	v_lshl_or_b32 v43, v43, 12, v43                             ; d200002b 04ad192b
	v_and_b32_e32 v38, 0xc0c0c0c0, v37                          ; 264c4aff c0c0c0c0
	v_and_b32_e32 v37, 0x3f3f3f3f, v37                          ; 264a4aff 3f3f3f3f
	v_cvt_f32_f16_sdwa v47, v40 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e5e16f9 00050628
	v_lshrrev_b32_e32 v38, 2, v38                               ; 204c4c82
	v_cvt_f32_f16_e32 v40, v40                                  ; 7e501728
	v_cvt_f32_ubyte1_e32 v46, v37                               ; 7e5c2525
	v_cvt_f32_ubyte3_e32 v42, v37                               ; 7e542925
	v_cvt_f32_ubyte2_e32 v44, v37                               ; 7e582725
	v_cvt_f32_ubyte0_e32 v37, v37                               ; 7e4a2325
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v48, s18, v35                                 ; 26604612
	v_and_or_b32 v43, s18, v43, v38                             ; d201002b 049a5612
	v_cvt_f32_ubyte1_e32 v51, v48                               ; 7e662530
	v_cvt_f32_ubyte3_e32 v49, v48                               ; 7e622930
	v_cvt_f32_ubyte2_e32 v50, v48                               ; 7e642730
	v_cvt_f32_ubyte0_e32 v48, v48                               ; 7e602330
	v_cvt_f32_ubyte1_e32 v45, v43                               ; 7e5a252b
	v_cvt_f32_ubyte3_e32 v39, v43                               ; 7e4e292b
	v_cvt_f32_ubyte2_e32 v41, v43                               ; 7e52272b
	v_cvt_f32_ubyte0_e32 v43, v43                               ; 7e56232b
	v_lshrrev_b32_e32 v35, 4, v35                               ; 20464684
	v_mul_f32_e32 v49, v19, v49                                 ; 0a626313
	v_mul_f32_e32 v39, v31, v39                                 ; 0a4e4f1f
	v_and_b32_e32 v35, s18, v35                                 ; 26464612
	v_mac_f32_e32 v49, v18, v50                                 ; 2c626512
	v_mac_f32_e32 v39, v30, v41                                 ; 2c4e531e
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v55, s18, v34                                 ; 266e4412
	v_cvt_f32_ubyte1_e32 v54, v35                               ; 7e6c2523
	v_cvt_f32_ubyte3_e32 v52, v35                               ; 7e682923
	v_cvt_f32_ubyte2_e32 v53, v35                               ; 7e6a2723
	v_cvt_f32_ubyte0_e32 v35, v35                               ; 7e462323
	v_mac_f32_e32 v49, v17, v51                                 ; 2c626711
	v_mac_f32_e32 v39, v29, v42                                 ; 2c4e551d
	v_cvt_f32_ubyte2_e32 v57, v55                               ; 7e722737
	v_cvt_f32_ubyte3_e32 v56, v55                               ; 7e702937
	v_cvt_f32_ubyte1_e32 v58, v55                               ; 7e742537
	v_mul_f32_e32 v52, v23, v52                                 ; 0a686917
	v_cvt_f32_ubyte0_e32 v55, v55                               ; 7e6e2337
	v_mac_f32_e32 v49, v16, v48                                 ; 2c626110
	v_lshrrev_b32_e32 v34, 4, v34                               ; 20444484
	v_mac_f32_e32 v39, v28, v44                                 ; 2c4e591c
	v_mul_f32_e32 v56, v27, v56                                 ; 0a70711b
	v_mac_f32_e32 v52, v22, v53                                 ; 2c686b16
	v_and_b32_e32 v34, s18, v34                                 ; 26444412
	v_mad_f32 v3, -v47, v39, v3                                 ; d1c10003 240e4f2f
	v_mac_f32_e32 v56, v26, v57                                 ; 2c70731a
	v_mac_f32_e32 v52, v21, v54                                 ; 2c686d15
	v_cvt_f32_ubyte2_e32 v60, v34                               ; 7e782722
	v_cvt_f32_ubyte1_e32 v61, v34                               ; 7e7a2522
	v_cvt_f32_ubyte3_e32 v59, v34                               ; 7e762922
	v_cvt_f32_ubyte0_e32 v34, v34                               ; 7e442322
	v_mac_f32_e32 v56, v25, v58                                 ; 2c707519
	v_mac_f32_e32 v52, v20, v35                                 ; 2c684714
	v_mul_f32_e32 v59, v15, v59                                 ; 0a76770f
	v_mac_f32_e32 v56, v24, v55                                 ; 2c706f18
	v_mac_f32_e32 v59, v14, v60                                 ; 2c76790e
	v_mac_f32_e32 v59, v13, v61                                 ; 2c767b0d
	v_mac_f32_e32 v59, v12, v34                                 ; 2c76450c
	v_mul_f32_e32 v59, v59, v45                                 ; 0a765b3b
	v_mac_f32_e32 v59, v56, v43                                 ; 2c765738
	v_mac_f32_e32 v59, v52, v46                                 ; 2c765d34
	v_mac_f32_e32 v59, v49, v37                                 ; 2c764b31
	v_mac_f32_e32 v3, v40, v59                                  ; 2c067728
	s_cbranch_scc0 BB102                                        ; bf8402ae
BB80:
	s_add_u32 s5, s16, 1                                        ; 80058110
	s_mul_i32 s5, s5, s3                                        ; 92050305
	s_add_u32 s5, s19, s5                                       ; 80050513
	v_add_u32_e32 v32, s5, v0                                   ; 68400005
	v_lshlrev_b32_e32 v33, 4, v32                               ; 24424084
	v_lshl_add_u32 v32, v32, 7, v33                             ; d1fd0020 04850f20
	v_add_u32_e32 v34, 16, v32                                  ; 68444090
	v_add_u32_e32 v35, v34, v4                                  ; 68460922
	v_add_u32_e32 v34, v34, v36                                 ; 68444922
	buffer_load_dwordx4 v[40:43], v32, s[20:23], 0 offen        ; e05c1000 80052820
	buffer_load_dword v35, v35, s[20:23], 0 offen               ; e0501000 80052323
	buffer_load_dword v34, v34, s[20:23], 0 offen               ; e0501000 80052222
	s_mov_b32 s18, 0xf0f0f0f                                    ; be9200ff 0f0f0f0f
	s_cmp_lt_u32 2, s4                                          ; bf0a0482
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_bfe_u32 v43, v43, v2, 16                                  ; d1c8002b 0242052b
	v_cndmask_b32_sdwa v37, v41, v41, vcc dst_sel:WORD_0 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 004a52f9 06051429
	v_cndmask_b32_sdwa v37, v42, v42, vcc dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 004a54f9 0605152a
	v_lshl_or_b32 v43, v43, 12, v43                             ; d200002b 04ad192b
	v_and_b32_e32 v38, 0xc0c0c0c0, v37                          ; 264c4aff c0c0c0c0
	v_and_b32_e32 v37, 0x3f3f3f3f, v37                          ; 264a4aff 3f3f3f3f
	v_cvt_f32_f16_sdwa v47, v40 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e5e16f9 00050628
	v_lshrrev_b32_e32 v38, 2, v38                               ; 204c4c82
	v_cvt_f32_ubyte1_e32 v46, v37                               ; 7e5c2525
	v_cvt_f32_f16_e32 v40, v40                                  ; 7e501728
	v_cvt_f32_ubyte3_e32 v42, v37                               ; 7e542925
	v_cvt_f32_ubyte2_e32 v44, v37                               ; 7e582725
	v_cvt_f32_ubyte0_e32 v37, v37                               ; 7e4a2325
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v48, s18, v35                                 ; 26604612
	v_and_or_b32 v43, s18, v43, v38                             ; d201002b 049a5612
	v_cvt_f32_ubyte3_e32 v49, v48                               ; 7e622930
	v_cvt_f32_ubyte1_e32 v51, v48                               ; 7e662530
	v_cvt_f32_ubyte2_e32 v50, v48                               ; 7e642730
	v_cvt_f32_ubyte0_e32 v48, v48                               ; 7e602330
	v_cvt_f32_ubyte3_e32 v39, v43                               ; 7e4e292b
	v_cvt_f32_ubyte2_e32 v41, v43                               ; 7e52272b
	v_cvt_f32_ubyte1_e32 v45, v43                               ; 7e5a252b
	v_cvt_f32_ubyte0_e32 v43, v43                               ; 7e56232b
	v_lshrrev_b32_e32 v35, 4, v35                               ; 20464684
	v_mul_f32_e32 v49, v19, v49                                 ; 0a626313
	v_mul_f32_e32 v39, v31, v39                                 ; 0a4e4f1f
	v_and_b32_e32 v35, s18, v35                                 ; 26464612
	v_mac_f32_e32 v49, v18, v50                                 ; 2c626512
	v_mac_f32_e32 v39, v30, v41                                 ; 2c4e531e
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v55, s18, v34                                 ; 266e4412
	v_cvt_f32_ubyte3_e32 v52, v35                               ; 7e682923
	v_cvt_f32_ubyte2_e32 v53, v35                               ; 7e6a2723
	v_cvt_f32_ubyte1_e32 v54, v35                               ; 7e6c2523
	v_cvt_f32_ubyte0_e32 v35, v35                               ; 7e462323
	v_mac_f32_e32 v49, v17, v51                                 ; 2c626711
	v_mac_f32_e32 v39, v29, v42                                 ; 2c4e551d
	v_cvt_f32_ubyte2_e32 v57, v55                               ; 7e722737
	v_cvt_f32_ubyte3_e32 v56, v55                               ; 7e702937
	v_mul_f32_e32 v52, v23, v52                                 ; 0a686917
	v_cvt_f32_ubyte1_e32 v58, v55                               ; 7e742537
	v_cvt_f32_ubyte0_e32 v55, v55                               ; 7e6e2337
	v_mac_f32_e32 v49, v16, v48                                 ; 2c626110
	v_lshrrev_b32_e32 v34, 4, v34                               ; 20444484
	v_mac_f32_e32 v39, v28, v44                                 ; 2c4e591c
	v_mul_f32_e32 v56, v27, v56                                 ; 0a70711b
	v_mac_f32_e32 v52, v22, v53                                 ; 2c686b16
	v_and_b32_e32 v34, s18, v34                                 ; 26444412
	v_mad_f32 v5, -v47, v39, v5                                 ; d1c10005 24164f2f
	v_mac_f32_e32 v56, v26, v57                                 ; 2c70731a
	v_mac_f32_e32 v52, v21, v54                                 ; 2c686d15
	v_cvt_f32_ubyte1_e32 v61, v34                               ; 7e7a2522
	v_cvt_f32_ubyte2_e32 v60, v34                               ; 7e782722
	v_cvt_f32_ubyte3_e32 v59, v34                               ; 7e762922
	v_cvt_f32_ubyte0_e32 v34, v34                               ; 7e442322
	v_mac_f32_e32 v56, v25, v58                                 ; 2c707519
	v_mac_f32_e32 v52, v20, v35                                 ; 2c684714
	v_mul_f32_e32 v59, v15, v59                                 ; 0a76770f
	v_mac_f32_e32 v56, v24, v55                                 ; 2c706f18
	v_mac_f32_e32 v59, v14, v60                                 ; 2c76790e
	v_mac_f32_e32 v59, v13, v61                                 ; 2c767b0d
	v_mac_f32_e32 v59, v12, v34                                 ; 2c76450c
	v_mul_f32_e32 v59, v59, v45                                 ; 0a765b3b
	v_mac_f32_e32 v59, v56, v43                                 ; 2c765738
	v_mac_f32_e32 v59, v52, v46                                 ; 2c765d34
	v_mac_f32_e32 v59, v49, v37                                 ; 2c764b31
	v_mac_f32_e32 v5, v40, v59                                  ; 2c0a7728
	s_cbranch_scc0 BB102                                        ; bf84024c
BB81:
	s_add_u32 s5, s16, 2                                        ; 80058210
	s_mul_i32 s5, s5, s3                                        ; 92050305
	s_add_u32 s5, s19, s5                                       ; 80050513
	v_add_u32_e32 v32, s5, v0                                   ; 68400005
	v_lshlrev_b32_e32 v33, 4, v32                               ; 24424084
	v_lshl_add_u32 v32, v32, 7, v33                             ; d1fd0020 04850f20
	v_add_u32_e32 v34, 16, v32                                  ; 68444090
	v_add_u32_e32 v35, v34, v4                                  ; 68460922
	v_add_u32_e32 v34, v34, v36                                 ; 68444922
	buffer_load_dwordx4 v[40:43], v32, s[20:23], 0 offen        ; e05c1000 80052820
	buffer_load_dword v35, v35, s[20:23], 0 offen               ; e0501000 80052323
	buffer_load_dword v34, v34, s[20:23], 0 offen               ; e0501000 80052222
	s_mov_b32 s18, 0xf0f0f0f                                    ; be9200ff 0f0f0f0f
	s_cmp_lt_u32 3, s4                                          ; bf0a0483
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_bfe_u32 v43, v43, v2, 16                                  ; d1c8002b 0242052b
	v_cndmask_b32_sdwa v37, v41, v41, vcc dst_sel:WORD_0 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 004a52f9 06051429
	v_cndmask_b32_sdwa v37, v42, v42, vcc dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 004a54f9 0605152a
	v_lshl_or_b32 v43, v43, 12, v43                             ; d200002b 04ad192b
	v_and_b32_e32 v38, 0xc0c0c0c0, v37                          ; 264c4aff c0c0c0c0
	v_and_b32_e32 v37, 0x3f3f3f3f, v37                          ; 264a4aff 3f3f3f3f
	v_cvt_f32_f16_sdwa v47, v40 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e5e16f9 00050628
	v_lshrrev_b32_e32 v38, 2, v38                               ; 204c4c82
	v_cvt_f32_ubyte1_e32 v46, v37                               ; 7e5c2525
	v_cvt_f32_f16_e32 v40, v40                                  ; 7e501728
	v_cvt_f32_ubyte3_e32 v42, v37                               ; 7e542925
	v_cvt_f32_ubyte2_e32 v44, v37                               ; 7e582725
	v_cvt_f32_ubyte0_e32 v37, v37                               ; 7e4a2325
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v48, s18, v35                                 ; 26604612
	v_and_or_b32 v43, s18, v43, v38                             ; d201002b 049a5612
	v_cvt_f32_ubyte3_e32 v49, v48                               ; 7e622930
	v_cvt_f32_ubyte1_e32 v51, v48                               ; 7e662530
	v_cvt_f32_ubyte2_e32 v50, v48                               ; 7e642730
	v_cvt_f32_ubyte0_e32 v48, v48                               ; 7e602330
	v_cvt_f32_ubyte3_e32 v39, v43                               ; 7e4e292b
	v_cvt_f32_ubyte2_e32 v41, v43                               ; 7e52272b
	v_cvt_f32_ubyte1_e32 v45, v43                               ; 7e5a252b
	v_cvt_f32_ubyte0_e32 v43, v43                               ; 7e56232b
	v_lshrrev_b32_e32 v35, 4, v35                               ; 20464684
	v_mul_f32_e32 v49, v19, v49                                 ; 0a626313
	v_mul_f32_e32 v39, v31, v39                                 ; 0a4e4f1f
	v_and_b32_e32 v35, s18, v35                                 ; 26464612
	v_mac_f32_e32 v49, v18, v50                                 ; 2c626512
	v_mac_f32_e32 v39, v30, v41                                 ; 2c4e531e
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v55, s18, v34                                 ; 266e4412
	v_cvt_f32_ubyte3_e32 v52, v35                               ; 7e682923
	v_cvt_f32_ubyte2_e32 v53, v35                               ; 7e6a2723
	v_cvt_f32_ubyte1_e32 v54, v35                               ; 7e6c2523
	v_cvt_f32_ubyte0_e32 v35, v35                               ; 7e462323
	v_mac_f32_e32 v49, v17, v51                                 ; 2c626711
	v_mac_f32_e32 v39, v29, v42                                 ; 2c4e551d
	v_cvt_f32_ubyte2_e32 v57, v55                               ; 7e722737
	v_cvt_f32_ubyte3_e32 v56, v55                               ; 7e702937
	v_mul_f32_e32 v52, v23, v52                                 ; 0a686917
	v_cvt_f32_ubyte1_e32 v58, v55                               ; 7e742537
	v_cvt_f32_ubyte0_e32 v55, v55                               ; 7e6e2337
	v_mac_f32_e32 v49, v16, v48                                 ; 2c626110
	v_lshrrev_b32_e32 v34, 4, v34                               ; 20444484
	v_mac_f32_e32 v39, v28, v44                                 ; 2c4e591c
	v_mul_f32_e32 v56, v27, v56                                 ; 0a70711b
	v_mac_f32_e32 v52, v22, v53                                 ; 2c686b16
	v_and_b32_e32 v34, s18, v34                                 ; 26444412
	v_mad_f32 v6, -v47, v39, v6                                 ; d1c10006 241a4f2f
	v_mac_f32_e32 v56, v26, v57                                 ; 2c70731a
	v_mac_f32_e32 v52, v21, v54                                 ; 2c686d15
	v_cvt_f32_ubyte1_e32 v61, v34                               ; 7e7a2522
	v_cvt_f32_ubyte2_e32 v60, v34                               ; 7e782722
	v_cvt_f32_ubyte3_e32 v59, v34                               ; 7e762922
	v_cvt_f32_ubyte0_e32 v34, v34                               ; 7e442322
	v_mac_f32_e32 v56, v25, v58                                 ; 2c707519
	v_mac_f32_e32 v52, v20, v35                                 ; 2c684714
	v_mul_f32_e32 v59, v15, v59                                 ; 0a76770f
	v_mac_f32_e32 v56, v24, v55                                 ; 2c706f18
	v_mac_f32_e32 v59, v14, v60                                 ; 2c76790e
	v_mac_f32_e32 v59, v13, v61                                 ; 2c767b0d
	v_mac_f32_e32 v59, v12, v34                                 ; 2c76450c
	v_mul_f32_e32 v59, v59, v45                                 ; 0a765b3b
	v_mac_f32_e32 v59, v56, v43                                 ; 2c765738
	v_mac_f32_e32 v59, v52, v46                                 ; 2c765d34
	v_mac_f32_e32 v59, v49, v37                                 ; 2c764b31
	v_mac_f32_e32 v6, v40, v59                                  ; 2c0c7728
	s_cbranch_scc0 BB102                                        ; bf8401ea
BB82:
	s_add_u32 s5, s16, 3                                        ; 80058310
	s_mul_i32 s5, s5, s3                                        ; 92050305
	s_add_u32 s5, s19, s5                                       ; 80050513
	v_add_u32_e32 v32, s5, v0                                   ; 68400005
	v_lshlrev_b32_e32 v33, 4, v32                               ; 24424084
	v_lshl_add_u32 v32, v32, 7, v33                             ; d1fd0020 04850f20
	v_add_u32_e32 v34, 16, v32                                  ; 68444090
	v_add_u32_e32 v35, v34, v4                                  ; 68460922
	v_add_u32_e32 v34, v34, v36                                 ; 68444922
	buffer_load_dwordx4 v[40:43], v32, s[20:23], 0 offen        ; e05c1000 80052820
	buffer_load_dword v35, v35, s[20:23], 0 offen               ; e0501000 80052323
	buffer_load_dword v34, v34, s[20:23], 0 offen               ; e0501000 80052222
	s_mov_b32 s18, 0xf0f0f0f                                    ; be9200ff 0f0f0f0f
	s_cmp_lt_u32 4, s4                                          ; bf0a0484
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_bfe_u32 v43, v43, v2, 16                                  ; d1c8002b 0242052b
	v_cndmask_b32_sdwa v37, v41, v41, vcc dst_sel:WORD_0 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 004a52f9 06051429
	v_cndmask_b32_sdwa v37, v42, v42, vcc dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 004a54f9 0605152a
	v_lshl_or_b32 v43, v43, 12, v43                             ; d200002b 04ad192b
	v_and_b32_e32 v38, 0xc0c0c0c0, v37                          ; 264c4aff c0c0c0c0
	v_and_b32_e32 v37, 0x3f3f3f3f, v37                          ; 264a4aff 3f3f3f3f
	v_cvt_f32_f16_sdwa v47, v40 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e5e16f9 00050628
	v_lshrrev_b32_e32 v38, 2, v38                               ; 204c4c82
	v_cvt_f32_ubyte1_e32 v46, v37                               ; 7e5c2525
	v_cvt_f32_f16_e32 v40, v40                                  ; 7e501728
	v_cvt_f32_ubyte3_e32 v42, v37                               ; 7e542925
	v_cvt_f32_ubyte2_e32 v44, v37                               ; 7e582725
	v_cvt_f32_ubyte0_e32 v37, v37                               ; 7e4a2325
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v48, s18, v35                                 ; 26604612
	v_and_or_b32 v43, s18, v43, v38                             ; d201002b 049a5612
	v_cvt_f32_ubyte3_e32 v49, v48                               ; 7e622930
	v_cvt_f32_ubyte1_e32 v51, v48                               ; 7e662530
	v_cvt_f32_ubyte2_e32 v50, v48                               ; 7e642730
	v_cvt_f32_ubyte0_e32 v48, v48                               ; 7e602330
	v_cvt_f32_ubyte3_e32 v39, v43                               ; 7e4e292b
	v_cvt_f32_ubyte2_e32 v41, v43                               ; 7e52272b
	v_cvt_f32_ubyte1_e32 v45, v43                               ; 7e5a252b
	v_cvt_f32_ubyte0_e32 v43, v43                               ; 7e56232b
	v_lshrrev_b32_e32 v35, 4, v35                               ; 20464684
	v_mul_f32_e32 v49, v19, v49                                 ; 0a626313
	v_mul_f32_e32 v39, v31, v39                                 ; 0a4e4f1f
	v_and_b32_e32 v35, s18, v35                                 ; 26464612
	v_mac_f32_e32 v49, v18, v50                                 ; 2c626512
	v_mac_f32_e32 v39, v30, v41                                 ; 2c4e531e
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v55, s18, v34                                 ; 266e4412
	v_cvt_f32_ubyte3_e32 v52, v35                               ; 7e682923
	v_cvt_f32_ubyte2_e32 v53, v35                               ; 7e6a2723
	v_cvt_f32_ubyte1_e32 v54, v35                               ; 7e6c2523
	v_cvt_f32_ubyte0_e32 v35, v35                               ; 7e462323
	v_mac_f32_e32 v49, v17, v51                                 ; 2c626711
	v_mac_f32_e32 v39, v29, v42                                 ; 2c4e551d
	v_cvt_f32_ubyte2_e32 v57, v55                               ; 7e722737
	v_cvt_f32_ubyte3_e32 v56, v55                               ; 7e702937
	v_mul_f32_e32 v52, v23, v52                                 ; 0a686917
	v_cvt_f32_ubyte1_e32 v58, v55                               ; 7e742537
	v_cvt_f32_ubyte0_e32 v55, v55                               ; 7e6e2337
	v_mac_f32_e32 v49, v16, v48                                 ; 2c626110
	v_lshrrev_b32_e32 v34, 4, v34                               ; 20444484
	v_mac_f32_e32 v39, v28, v44                                 ; 2c4e591c
	v_mul_f32_e32 v56, v27, v56                                 ; 0a70711b
	v_mac_f32_e32 v52, v22, v53                                 ; 2c686b16
	v_and_b32_e32 v34, s18, v34                                 ; 26444412
	v_mad_f32 v7, -v47, v39, v7                                 ; d1c10007 241e4f2f
	v_mac_f32_e32 v56, v26, v57                                 ; 2c70731a
	v_mac_f32_e32 v52, v21, v54                                 ; 2c686d15
	v_cvt_f32_ubyte1_e32 v61, v34                               ; 7e7a2522
	v_cvt_f32_ubyte2_e32 v60, v34                               ; 7e782722
	v_cvt_f32_ubyte3_e32 v59, v34                               ; 7e762922
	v_cvt_f32_ubyte0_e32 v34, v34                               ; 7e442322
	v_mac_f32_e32 v56, v25, v58                                 ; 2c707519
	v_mac_f32_e32 v52, v20, v35                                 ; 2c684714
	v_mul_f32_e32 v59, v15, v59                                 ; 0a76770f
	v_mac_f32_e32 v56, v24, v55                                 ; 2c706f18
	v_mac_f32_e32 v59, v14, v60                                 ; 2c76790e
	v_mac_f32_e32 v59, v13, v61                                 ; 2c767b0d
	v_mac_f32_e32 v59, v12, v34                                 ; 2c76450c
	v_mul_f32_e32 v59, v59, v45                                 ; 0a765b3b
	v_mac_f32_e32 v59, v56, v43                                 ; 2c765738
	v_mac_f32_e32 v59, v52, v46                                 ; 2c765d34
	v_mac_f32_e32 v59, v49, v37                                 ; 2c764b31
	v_mac_f32_e32 v7, v40, v59                                  ; 2c0e7728
	s_cbranch_scc0 BB102                                        ; bf840188
BB83:
	s_add_u32 s5, s16, 4                                        ; 80058410
	s_mul_i32 s5, s5, s3                                        ; 92050305
	s_add_u32 s5, s19, s5                                       ; 80050513
	v_add_u32_e32 v32, s5, v0                                   ; 68400005
	v_lshlrev_b32_e32 v33, 4, v32                               ; 24424084
	v_lshl_add_u32 v32, v32, 7, v33                             ; d1fd0020 04850f20
	v_add_u32_e32 v34, 16, v32                                  ; 68444090
	v_add_u32_e32 v35, v34, v4                                  ; 68460922
	v_add_u32_e32 v34, v34, v36                                 ; 68444922
	buffer_load_dwordx4 v[40:43], v32, s[20:23], 0 offen        ; e05c1000 80052820
	buffer_load_dword v35, v35, s[20:23], 0 offen               ; e0501000 80052323
	buffer_load_dword v34, v34, s[20:23], 0 offen               ; e0501000 80052222
	s_mov_b32 s18, 0xf0f0f0f                                    ; be9200ff 0f0f0f0f
	s_cmp_lt_u32 5, s4                                          ; bf0a0485
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_bfe_u32 v43, v43, v2, 16                                  ; d1c8002b 0242052b
	v_cndmask_b32_sdwa v37, v41, v41, vcc dst_sel:WORD_0 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 004a52f9 06051429
	v_cndmask_b32_sdwa v37, v42, v42, vcc dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 004a54f9 0605152a
	v_lshl_or_b32 v43, v43, 12, v43                             ; d200002b 04ad192b
	v_and_b32_e32 v38, 0xc0c0c0c0, v37                          ; 264c4aff c0c0c0c0
	v_and_b32_e32 v37, 0x3f3f3f3f, v37                          ; 264a4aff 3f3f3f3f
	v_cvt_f32_f16_sdwa v47, v40 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e5e16f9 00050628
	v_lshrrev_b32_e32 v38, 2, v38                               ; 204c4c82
	v_cvt_f32_ubyte1_e32 v46, v37                               ; 7e5c2525
	v_cvt_f32_f16_e32 v40, v40                                  ; 7e501728
	v_cvt_f32_ubyte3_e32 v42, v37                               ; 7e542925
	v_cvt_f32_ubyte2_e32 v44, v37                               ; 7e582725
	v_cvt_f32_ubyte0_e32 v37, v37                               ; 7e4a2325
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v48, s18, v35                                 ; 26604612
	v_and_or_b32 v43, s18, v43, v38                             ; d201002b 049a5612
	v_cvt_f32_ubyte3_e32 v49, v48                               ; 7e622930
	v_cvt_f32_ubyte1_e32 v51, v48                               ; 7e662530
	v_cvt_f32_ubyte2_e32 v50, v48                               ; 7e642730
	v_cvt_f32_ubyte0_e32 v48, v48                               ; 7e602330
	v_cvt_f32_ubyte3_e32 v39, v43                               ; 7e4e292b
	v_cvt_f32_ubyte2_e32 v41, v43                               ; 7e52272b
	v_cvt_f32_ubyte1_e32 v45, v43                               ; 7e5a252b
	v_cvt_f32_ubyte0_e32 v43, v43                               ; 7e56232b
	v_lshrrev_b32_e32 v35, 4, v35                               ; 20464684
	v_mul_f32_e32 v49, v19, v49                                 ; 0a626313
	v_mul_f32_e32 v39, v31, v39                                 ; 0a4e4f1f
	v_and_b32_e32 v35, s18, v35                                 ; 26464612
	v_mac_f32_e32 v49, v18, v50                                 ; 2c626512
	v_mac_f32_e32 v39, v30, v41                                 ; 2c4e531e
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v55, s18, v34                                 ; 266e4412
	v_cvt_f32_ubyte3_e32 v52, v35                               ; 7e682923
	v_cvt_f32_ubyte2_e32 v53, v35                               ; 7e6a2723
	v_cvt_f32_ubyte1_e32 v54, v35                               ; 7e6c2523
	v_cvt_f32_ubyte0_e32 v35, v35                               ; 7e462323
	v_mac_f32_e32 v49, v17, v51                                 ; 2c626711
	v_mac_f32_e32 v39, v29, v42                                 ; 2c4e551d
	v_cvt_f32_ubyte2_e32 v57, v55                               ; 7e722737
	v_cvt_f32_ubyte3_e32 v56, v55                               ; 7e702937
	v_mul_f32_e32 v52, v23, v52                                 ; 0a686917
	v_cvt_f32_ubyte1_e32 v58, v55                               ; 7e742537
	v_cvt_f32_ubyte0_e32 v55, v55                               ; 7e6e2337
	v_mac_f32_e32 v49, v16, v48                                 ; 2c626110
	v_lshrrev_b32_e32 v34, 4, v34                               ; 20444484
	v_mac_f32_e32 v39, v28, v44                                 ; 2c4e591c
	v_mul_f32_e32 v56, v27, v56                                 ; 0a70711b
	v_mac_f32_e32 v52, v22, v53                                 ; 2c686b16
	v_and_b32_e32 v34, s18, v34                                 ; 26444412
	v_mad_f32 v8, -v47, v39, v8                                 ; d1c10008 24224f2f
	v_mac_f32_e32 v56, v26, v57                                 ; 2c70731a
	v_mac_f32_e32 v52, v21, v54                                 ; 2c686d15
	v_cvt_f32_ubyte1_e32 v61, v34                               ; 7e7a2522
	v_cvt_f32_ubyte2_e32 v60, v34                               ; 7e782722
	v_cvt_f32_ubyte3_e32 v59, v34                               ; 7e762922
	v_cvt_f32_ubyte0_e32 v34, v34                               ; 7e442322
	v_mac_f32_e32 v56, v25, v58                                 ; 2c707519
	v_mac_f32_e32 v52, v20, v35                                 ; 2c684714
	v_mul_f32_e32 v59, v15, v59                                 ; 0a76770f
	v_mac_f32_e32 v56, v24, v55                                 ; 2c706f18
	v_mac_f32_e32 v59, v14, v60                                 ; 2c76790e
	v_mac_f32_e32 v59, v13, v61                                 ; 2c767b0d
	v_mac_f32_e32 v59, v12, v34                                 ; 2c76450c
	v_mul_f32_e32 v59, v59, v45                                 ; 0a765b3b
	v_mac_f32_e32 v59, v56, v43                                 ; 2c765738
	v_mac_f32_e32 v59, v52, v46                                 ; 2c765d34
	v_mac_f32_e32 v59, v49, v37                                 ; 2c764b31
	v_mac_f32_e32 v8, v40, v59                                  ; 2c107728
	s_cbranch_scc0 BB102                                        ; bf840126
BB84:
	s_add_u32 s5, s16, 5                                        ; 80058510
	s_mul_i32 s5, s5, s3                                        ; 92050305
	s_add_u32 s5, s19, s5                                       ; 80050513
	v_add_u32_e32 v32, s5, v0                                   ; 68400005
	v_lshlrev_b32_e32 v33, 4, v32                               ; 24424084
	v_lshl_add_u32 v32, v32, 7, v33                             ; d1fd0020 04850f20
	v_add_u32_e32 v34, 16, v32                                  ; 68444090
	v_add_u32_e32 v35, v34, v4                                  ; 68460922
	v_add_u32_e32 v34, v34, v36                                 ; 68444922
	buffer_load_dwordx4 v[40:43], v32, s[20:23], 0 offen        ; e05c1000 80052820
	buffer_load_dword v35, v35, s[20:23], 0 offen               ; e0501000 80052323
	buffer_load_dword v34, v34, s[20:23], 0 offen               ; e0501000 80052222
	s_mov_b32 s18, 0xf0f0f0f                                    ; be9200ff 0f0f0f0f
	s_cmp_lt_u32 6, s4                                          ; bf0a0486
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_bfe_u32 v43, v43, v2, 16                                  ; d1c8002b 0242052b
	v_cndmask_b32_sdwa v37, v41, v41, vcc dst_sel:WORD_0 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 004a52f9 06051429
	v_cndmask_b32_sdwa v37, v42, v42, vcc dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 004a54f9 0605152a
	v_lshl_or_b32 v43, v43, 12, v43                             ; d200002b 04ad192b
	v_and_b32_e32 v38, 0xc0c0c0c0, v37                          ; 264c4aff c0c0c0c0
	v_and_b32_e32 v37, 0x3f3f3f3f, v37                          ; 264a4aff 3f3f3f3f
	v_cvt_f32_f16_sdwa v47, v40 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e5e16f9 00050628
	v_lshrrev_b32_e32 v38, 2, v38                               ; 204c4c82
	v_cvt_f32_ubyte1_e32 v46, v37                               ; 7e5c2525
	v_cvt_f32_f16_e32 v40, v40                                  ; 7e501728
	v_cvt_f32_ubyte3_e32 v42, v37                               ; 7e542925
	v_cvt_f32_ubyte2_e32 v44, v37                               ; 7e582725
	v_cvt_f32_ubyte0_e32 v37, v37                               ; 7e4a2325
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v48, s18, v35                                 ; 26604612
	v_and_or_b32 v43, s18, v43, v38                             ; d201002b 049a5612
	v_cvt_f32_ubyte3_e32 v49, v48                               ; 7e622930
	v_cvt_f32_ubyte1_e32 v51, v48                               ; 7e662530
	v_cvt_f32_ubyte2_e32 v50, v48                               ; 7e642730
	v_cvt_f32_ubyte0_e32 v48, v48                               ; 7e602330
	v_cvt_f32_ubyte3_e32 v39, v43                               ; 7e4e292b
	v_cvt_f32_ubyte2_e32 v41, v43                               ; 7e52272b
	v_cvt_f32_ubyte1_e32 v45, v43                               ; 7e5a252b
	v_cvt_f32_ubyte0_e32 v43, v43                               ; 7e56232b
	v_lshrrev_b32_e32 v35, 4, v35                               ; 20464684
	v_mul_f32_e32 v49, v19, v49                                 ; 0a626313
	v_mul_f32_e32 v39, v31, v39                                 ; 0a4e4f1f
	v_and_b32_e32 v35, s18, v35                                 ; 26464612
	v_mac_f32_e32 v49, v18, v50                                 ; 2c626512
	v_mac_f32_e32 v39, v30, v41                                 ; 2c4e531e
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v55, s18, v34                                 ; 266e4412
	v_cvt_f32_ubyte3_e32 v52, v35                               ; 7e682923
	v_cvt_f32_ubyte2_e32 v53, v35                               ; 7e6a2723
	v_cvt_f32_ubyte1_e32 v54, v35                               ; 7e6c2523
	v_cvt_f32_ubyte0_e32 v35, v35                               ; 7e462323
	v_mac_f32_e32 v49, v17, v51                                 ; 2c626711
	v_mac_f32_e32 v39, v29, v42                                 ; 2c4e551d
	v_cvt_f32_ubyte2_e32 v57, v55                               ; 7e722737
	v_cvt_f32_ubyte3_e32 v56, v55                               ; 7e702937
	v_mul_f32_e32 v52, v23, v52                                 ; 0a686917
	v_cvt_f32_ubyte1_e32 v58, v55                               ; 7e742537
	v_cvt_f32_ubyte0_e32 v55, v55                               ; 7e6e2337
	v_mac_f32_e32 v49, v16, v48                                 ; 2c626110
	v_lshrrev_b32_e32 v34, 4, v34                               ; 20444484
	v_mac_f32_e32 v39, v28, v44                                 ; 2c4e591c
	v_mul_f32_e32 v56, v27, v56                                 ; 0a70711b
	v_mac_f32_e32 v52, v22, v53                                 ; 2c686b16
	v_and_b32_e32 v34, s18, v34                                 ; 26444412
	v_mad_f32 v9, -v47, v39, v9                                 ; d1c10009 24264f2f
	v_mac_f32_e32 v56, v26, v57                                 ; 2c70731a
	v_mac_f32_e32 v52, v21, v54                                 ; 2c686d15
	v_cvt_f32_ubyte1_e32 v61, v34                               ; 7e7a2522
	v_cvt_f32_ubyte2_e32 v60, v34                               ; 7e782722
	v_cvt_f32_ubyte3_e32 v59, v34                               ; 7e762922
	v_cvt_f32_ubyte0_e32 v34, v34                               ; 7e442322
	v_mac_f32_e32 v56, v25, v58                                 ; 2c707519
	v_mac_f32_e32 v52, v20, v35                                 ; 2c684714
	v_mul_f32_e32 v59, v15, v59                                 ; 0a76770f
	v_mac_f32_e32 v56, v24, v55                                 ; 2c706f18
	v_mac_f32_e32 v59, v14, v60                                 ; 2c76790e
	v_mac_f32_e32 v59, v13, v61                                 ; 2c767b0d
	v_mac_f32_e32 v59, v12, v34                                 ; 2c76450c
	v_mul_f32_e32 v59, v59, v45                                 ; 0a765b3b
	v_mac_f32_e32 v59, v56, v43                                 ; 2c765738
	v_mac_f32_e32 v59, v52, v46                                 ; 2c765d34
	v_mac_f32_e32 v59, v49, v37                                 ; 2c764b31
	v_mac_f32_e32 v9, v40, v59                                  ; 2c127728
	s_cbranch_scc0 BB102                                        ; bf8400c4
BB85:
	s_add_u32 s5, s16, 6                                        ; 80058610
	s_mul_i32 s5, s5, s3                                        ; 92050305
	s_add_u32 s5, s19, s5                                       ; 80050513
	v_add_u32_e32 v32, s5, v0                                   ; 68400005
	v_lshlrev_b32_e32 v33, 4, v32                               ; 24424084
	v_lshl_add_u32 v32, v32, 7, v33                             ; d1fd0020 04850f20
	v_add_u32_e32 v34, 16, v32                                  ; 68444090
	v_add_u32_e32 v35, v34, v4                                  ; 68460922
	v_add_u32_e32 v34, v34, v36                                 ; 68444922
	buffer_load_dwordx4 v[40:43], v32, s[20:23], 0 offen        ; e05c1000 80052820
	buffer_load_dword v35, v35, s[20:23], 0 offen               ; e0501000 80052323
	buffer_load_dword v34, v34, s[20:23], 0 offen               ; e0501000 80052222
	s_mov_b32 s18, 0xf0f0f0f                                    ; be9200ff 0f0f0f0f
	s_cmp_lt_u32 7, s4                                          ; bf0a0487
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_bfe_u32 v43, v43, v2, 16                                  ; d1c8002b 0242052b
	v_cndmask_b32_sdwa v37, v41, v41, vcc dst_sel:WORD_0 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 004a52f9 06051429
	v_cndmask_b32_sdwa v37, v42, v42, vcc dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 004a54f9 0605152a
	v_lshl_or_b32 v43, v43, 12, v43                             ; d200002b 04ad192b
	v_and_b32_e32 v38, 0xc0c0c0c0, v37                          ; 264c4aff c0c0c0c0
	v_and_b32_e32 v37, 0x3f3f3f3f, v37                          ; 264a4aff 3f3f3f3f
	v_cvt_f32_f16_sdwa v47, v40 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e5e16f9 00050628
	v_lshrrev_b32_e32 v38, 2, v38                               ; 204c4c82
	v_cvt_f32_ubyte1_e32 v46, v37                               ; 7e5c2525
	v_cvt_f32_f16_e32 v40, v40                                  ; 7e501728
	v_cvt_f32_ubyte3_e32 v42, v37                               ; 7e542925
	v_cvt_f32_ubyte2_e32 v44, v37                               ; 7e582725
	v_cvt_f32_ubyte0_e32 v37, v37                               ; 7e4a2325
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v48, s18, v35                                 ; 26604612
	v_and_or_b32 v43, s18, v43, v38                             ; d201002b 049a5612
	v_cvt_f32_ubyte3_e32 v49, v48                               ; 7e622930
	v_cvt_f32_ubyte1_e32 v51, v48                               ; 7e662530
	v_cvt_f32_ubyte2_e32 v50, v48                               ; 7e642730
	v_cvt_f32_ubyte0_e32 v48, v48                               ; 7e602330
	v_cvt_f32_ubyte3_e32 v39, v43                               ; 7e4e292b
	v_cvt_f32_ubyte2_e32 v41, v43                               ; 7e52272b
	v_cvt_f32_ubyte1_e32 v45, v43                               ; 7e5a252b
	v_cvt_f32_ubyte0_e32 v43, v43                               ; 7e56232b
	v_lshrrev_b32_e32 v35, 4, v35                               ; 20464684
	v_mul_f32_e32 v49, v19, v49                                 ; 0a626313
	v_mul_f32_e32 v39, v31, v39                                 ; 0a4e4f1f
	v_and_b32_e32 v35, s18, v35                                 ; 26464612
	v_mac_f32_e32 v49, v18, v50                                 ; 2c626512
	v_mac_f32_e32 v39, v30, v41                                 ; 2c4e531e
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v55, s18, v34                                 ; 266e4412
	v_cvt_f32_ubyte3_e32 v52, v35                               ; 7e682923
	v_cvt_f32_ubyte2_e32 v53, v35                               ; 7e6a2723
	v_cvt_f32_ubyte1_e32 v54, v35                               ; 7e6c2523
	v_cvt_f32_ubyte0_e32 v35, v35                               ; 7e462323
	v_mac_f32_e32 v49, v17, v51                                 ; 2c626711
	v_mac_f32_e32 v39, v29, v42                                 ; 2c4e551d
	v_cvt_f32_ubyte2_e32 v57, v55                               ; 7e722737
	v_cvt_f32_ubyte3_e32 v56, v55                               ; 7e702937
	v_mul_f32_e32 v52, v23, v52                                 ; 0a686917
	v_cvt_f32_ubyte1_e32 v58, v55                               ; 7e742537
	v_cvt_f32_ubyte0_e32 v55, v55                               ; 7e6e2337
	v_mac_f32_e32 v49, v16, v48                                 ; 2c626110
	v_lshrrev_b32_e32 v34, 4, v34                               ; 20444484
	v_mac_f32_e32 v39, v28, v44                                 ; 2c4e591c
	v_mul_f32_e32 v56, v27, v56                                 ; 0a70711b
	v_mac_f32_e32 v52, v22, v53                                 ; 2c686b16
	v_and_b32_e32 v34, s18, v34                                 ; 26444412
	v_mad_f32 v10, -v47, v39, v10                               ; d1c1000a 242a4f2f
	v_mac_f32_e32 v56, v26, v57                                 ; 2c70731a
	v_mac_f32_e32 v52, v21, v54                                 ; 2c686d15
	v_cvt_f32_ubyte1_e32 v61, v34                               ; 7e7a2522
	v_cvt_f32_ubyte2_e32 v60, v34                               ; 7e782722
	v_cvt_f32_ubyte3_e32 v59, v34                               ; 7e762922
	v_cvt_f32_ubyte0_e32 v34, v34                               ; 7e442322
	v_mac_f32_e32 v56, v25, v58                                 ; 2c707519
	v_mac_f32_e32 v52, v20, v35                                 ; 2c684714
	v_mul_f32_e32 v59, v15, v59                                 ; 0a76770f
	v_mac_f32_e32 v56, v24, v55                                 ; 2c706f18
	v_mac_f32_e32 v59, v14, v60                                 ; 2c76790e
	v_mac_f32_e32 v59, v13, v61                                 ; 2c767b0d
	v_mac_f32_e32 v59, v12, v34                                 ; 2c76450c
	v_mul_f32_e32 v59, v59, v45                                 ; 0a765b3b
	v_mac_f32_e32 v59, v56, v43                                 ; 2c765738
	v_mac_f32_e32 v59, v52, v46                                 ; 2c765d34
	v_mac_f32_e32 v59, v49, v37                                 ; 2c764b31
	v_mac_f32_e32 v10, v40, v59                                 ; 2c147728
	s_cbranch_scc0 BB102                                        ; bf840062
BB86:
	s_add_u32 s5, s16, 7                                        ; 80058710
	s_mul_i32 s5, s5, s3                                        ; 92050305
	s_add_u32 s5, s19, s5                                       ; 80050513
	v_add_u32_e32 v32, s5, v0                                   ; 68400005
	v_lshlrev_b32_e32 v33, 4, v32                               ; 24424084
	v_lshl_add_u32 v32, v32, 7, v33                             ; d1fd0020 04850f20
	v_add_u32_e32 v34, 16, v32                                  ; 68444090
	v_add_u32_e32 v35, v34, v4                                  ; 68460922
	v_add_u32_e32 v34, v34, v36                                 ; 68444922
	buffer_load_dwordx4 v[36:39], v32, s[20:23], 0 offen        ; e05c1000 80052420
	buffer_load_dword v35, v35, s[20:23], 0 offen               ; e0501000 80052323
	buffer_load_dword v34, v34, s[20:23], 0 offen               ; e0501000 80052222
	s_mov_b32 s18, 0xf0f0f0f                                    ; be9200ff 0f0f0f0f
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_bfe_u32 v39, v39, v2, 16                                  ; d1c80027 02420527
	v_cndmask_b32_sdwa v37, v37, v37, vcc dst_sel:WORD_0 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 004a4af9 06051425
	v_cndmask_b32_sdwa v37, v38, v38, vcc dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_1 src1_sel:DWORD ; 004a4cf9 06051526
	v_lshl_or_b32 v39, v39, 12, v39                             ; d2000027 049d1927
	v_and_b32_e32 v38, 0xc0c0c0c0, v37                          ; 264c4aff c0c0c0c0
	v_and_b32_e32 v37, 0x3f3f3f3f, v37                          ; 264a4aff 3f3f3f3f
	v_cvt_f32_f16_sdwa v46, v36 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e5c16f9 00050624
	v_lshrrev_b32_e32 v38, 2, v38                               ; 204c4c82
	v_cvt_f32_f16_e32 v36, v36                                  ; 7e481724
	v_cvt_f32_ubyte3_e32 v42, v37                               ; 7e542925
	v_cvt_f32_ubyte2_e32 v43, v37                               ; 7e562725
	v_cvt_f32_ubyte1_e32 v45, v37                               ; 7e5a2525
	v_cvt_f32_ubyte0_e32 v37, v37                               ; 7e4a2325
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v47, s18, v35                                 ; 265e4612
	v_and_or_b32 v39, s18, v39, v38                             ; d2010027 049a4e12
	v_cvt_f32_ubyte1_e32 v50, v47                               ; 7e64252f
	v_cvt_f32_ubyte3_e32 v48, v47                               ; 7e60292f
	v_cvt_f32_ubyte2_e32 v49, v47                               ; 7e62272f
	v_cvt_f32_ubyte0_e32 v47, v47                               ; 7e5e232f
	v_cvt_f32_ubyte3_e32 v40, v39                               ; 7e502927
	v_cvt_f32_ubyte2_e32 v41, v39                               ; 7e522727
	v_cvt_f32_ubyte1_e32 v44, v39                               ; 7e582527
	v_cvt_f32_ubyte0_e32 v39, v39                               ; 7e4e2327
	v_lshrrev_b32_e32 v35, 4, v35                               ; 20464684
	v_mul_f32_e32 v19, v19, v48                                 ; 0a266113
	v_mul_f32_e32 v31, v31, v40                                 ; 0a3e511f
	v_and_b32_e32 v35, s18, v35                                 ; 26464612
	v_mac_f32_e32 v19, v18, v49                                 ; 2c266312
	v_mac_f32_e32 v31, v30, v41                                 ; 2c3e531e
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v54, s18, v34                                 ; 266c4412
	v_cvt_f32_ubyte3_e32 v51, v35                               ; 7e662923
	v_cvt_f32_ubyte2_e32 v52, v35                               ; 7e682723
	v_cvt_f32_ubyte1_e32 v53, v35                               ; 7e6a2523
	v_cvt_f32_ubyte0_e32 v35, v35                               ; 7e462323
	v_mac_f32_e32 v19, v17, v50                                 ; 2c266511
	v_mac_f32_e32 v31, v29, v42                                 ; 2c3e551d
	v_cvt_f32_ubyte2_e32 v56, v54                               ; 7e702736
	v_cvt_f32_ubyte3_e32 v55, v54                               ; 7e6e2936
	v_mul_f32_e32 v23, v23, v51                                 ; 0a2e6717
	v_cvt_f32_ubyte1_e32 v57, v54                               ; 7e722536
	v_cvt_f32_ubyte0_e32 v54, v54                               ; 7e6c2336
	v_mac_f32_e32 v19, v16, v47                                 ; 2c265f10
	v_lshrrev_b32_e32 v34, 4, v34                               ; 20444484
	v_mac_f32_e32 v31, v28, v43                                 ; 2c3e571c
	v_mul_f32_e32 v27, v27, v55                                 ; 0a366f1b
	v_mac_f32_e32 v23, v22, v52                                 ; 2c2e6916
	v_and_b32_e32 v34, s18, v34                                 ; 26444412
	v_mad_f32 v11, -v46, v31, v11                               ; d1c1000b 242e3f2e
	v_mac_f32_e32 v27, v26, v56                                 ; 2c36711a
	v_mac_f32_e32 v23, v21, v53                                 ; 2c2e6b15
	v_cvt_f32_ubyte1_e32 v60, v34                               ; 7e782522
	v_cvt_f32_ubyte2_e32 v59, v34                               ; 7e762722
	v_cvt_f32_ubyte3_e32 v58, v34                               ; 7e742922
	v_cvt_f32_ubyte0_e32 v34, v34                               ; 7e442322
	v_mac_f32_e32 v27, v25, v57                                 ; 2c367319
	v_mac_f32_e32 v23, v20, v35                                 ; 2c2e4714
	v_mul_f32_e32 v15, v15, v58                                 ; 0a1e750f
	v_mac_f32_e32 v27, v24, v54                                 ; 2c366d18
	v_mac_f32_e32 v15, v14, v59                                 ; 2c1e770e
	v_mac_f32_e32 v15, v13, v60                                 ; 2c1e790d
	v_mac_f32_e32 v15, v12, v34                                 ; 2c1e450c
	v_mul_f32_e32 v15, v15, v44                                 ; 0a1e590f
	v_mac_f32_e32 v15, v27, v39                                 ; 2c1e4f1b
	v_mac_f32_e32 v15, v23, v45                                 ; 2c1e5b17
	v_mac_f32_e32 v15, v19, v37                                 ; 2c1e4b13
	v_mac_f32_e32 v11, v36, v15                                 ; 2c161f24
	s_branch BB102                                              ; bf820001
BB101:
	s_mov_b32 s9, src_scc                                       ; be8900fd
BB102:
	v_add_u32_e32 v0, 4, v0                                     ; 68000084
	s_mov_b64 s[20:21], exec                                    ; be94017e
	v_cmpx_le_u32_e32 vcc, s3, v0                               ; 7db60003
BB103:
	s_andn2_b64 s[20:21], s[20:21], exec                        ; 89947e14
	s_cbranch_scc1 BB107                                        ; bf85fcbf
BB108:
	s_mov_b64 exec, s[10:11]                                    ; befe010a
BB110:
	s_andn2_b64 exec, -1, exec                                  ; 89fe7ec1
	s_cbranch_execz BB113                                       ; bf880008
BB111:
	v_mov_b32_e32 v3, 0                                         ; 7e060280
	v_mov_b32_e32 v5, 0                                         ; 7e0a0280
	v_mov_b32_e32 v6, 0                                         ; 7e0c0280
	v_mov_b32_e32 v7, 0                                         ; 7e0e0280
	v_mov_b32_e32 v8, 0                                         ; 7e100280
	v_mov_b32_e32 v9, 0                                         ; 7e120280
	v_mov_b32_e32 v10, 0                                        ; 7e140280
	v_mov_b32_e32 v11, 0                                        ; 7e160280
BB113:
	s_mov_b64 exec, -1                                          ; befe01c1
	s_cmp_lg_i32 s4, 0                                          ; bf018004
	s_cselect_b64 s[0:1], -1, 0                                 ; 858080c1
	s_cbranch_scc0 BB137                                        ; bf8400d6
BB114:
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
	s_cbranch_scc0 BB135                                        ; bf8400bb
BB115:
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
	s_cbranch_scc0 BB133                                        ; bf8400a0
BB116:
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
	s_cbranch_scc0 BB131                                        ; bf840085
BB117:
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
	s_cbranch_scc0 BB129                                        ; bf84006a
BB118:
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
	s_cbranch_scc0 BB127                                        ; bf84004f
BB119:
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
	s_cbranch_scc0 BB125                                        ; bf840034
BB120:
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
	s_cbranch_scc0 BB123                                        ; bf840019
BB121:
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
BB123:
	v_mov_b32_e32 v10, s12                                      ; 7e14020c
BB125:
	v_mov_b32_e32 v9, s11                                       ; 7e12020b
BB127:
	v_mov_b32_e32 v8, s10                                       ; 7e10020a
BB129:
	v_mov_b32_e32 v7, s9                                        ; 7e0e0209
BB131:
	v_mov_b32_e32 v6, s6                                        ; 7e0c0206
BB133:
	v_mov_b32_e32 v5, s5                                        ; 7e0a0205
BB135:
	v_mov_b32_e32 v3, s3                                        ; 7e060203
BB137:
	s_mov_b64 s[10:11], 1                                       ; be8a0181
	s_and_b64 exec, s[0:1], s[10:11]                            ; 86fe0a00
	s_cbranch_execz BB215                                       ; bf8800ff
BB138:
	s_bitcmp1_b32 s8, 0                                         ; bf0d8008
	s_cbranch_scc0 BB140                                        ; bf84000e
BB139:
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
	s_branch BB141                                              ; bf820001
BB140:
	s_mov_b32 s1, src_scc                                       ; be8100fd
BB141:
	s_bitcmp1_b32 s8, 1                                         ; bf0d8108
	s_cbranch_scc0 BB143                                        ; bf84000e
BB142:
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
	s_branch BB144                                              ; bf820001
BB143:
	s_mov_b32 s3, src_scc                                       ; be8300fd
BB144:
	s_mov_b32 s0, s3                                            ; be800003
	s_movk_i32 s3, 0x8000                                       ; b0038000
	s_load_dwordx4 s[8:11], s[2:3], 0x20                        ; c00a0201 00000020
	s_mul_i32 s7, s7, s17                                       ; 92071107
	s_add_u32 s7, s7, s16                                       ; 80071007
	s_lshl_b32 s7, s7, 2                                        ; 8e078207
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_store_dword v3, off, s[8:11], s7                     ; e0700000 07020380
	s_cmp_lt_u32 1, s4                                          ; bf0a0481
	s_cbranch_scc0 BB215                                        ; bf8400d1
BB145:
	s_cmp_lg_i32 s1, 0                                          ; bf018001
	s_cbranch_scc0 BB147                                        ; bf84000a
BB146:
	s_load_dwordx4 s[12:15], s[2:3], 0x30                       ; c00a0301 00000030
	s_mov_b32 s1, src_scc                                       ; be8100fd
	s_add_u32 s5, s7, 4                                         ; 80058407
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s5, s[12:15], s5                        ; c0200146 00000005
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v5, s5, v5                                    ; 020a0a05
	s_branch BB148                                              ; bf820001
BB147:
	s_mov_b32 s1, src_scc                                       ; be8100fd
BB148:
	s_cmp_lg_i32 s0, 0                                          ; bf018000
	s_cbranch_scc0 BB150                                        ; bf84000a
BB149:
	s_load_dwordx4 s[12:15], s[2:3], 0x40                       ; c00a0301 00000040
	s_mov_b32 s0, src_scc                                       ; be8000fd
	s_add_u32 s5, s7, 4                                         ; 80058407
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s5, s[12:15], s5                        ; c0200146 00000005
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v5, s5, v5                                    ; 020a0a05
	s_branch BB151                                              ; bf820001
BB150:
	s_mov_b32 s0, src_scc                                       ; be8000fd
BB151:
	s_add_u32 s5, s7, 4                                         ; 80058407
	buffer_store_dword v5, off, s[8:11], s5                     ; e0700000 05020580
	s_cmp_lt_u32 2, s4                                          ; bf0a0482
	s_cbranch_scc0 BB215                                        ; bf8400b2
BB152:
	s_cmp_lg_i32 s1, 0                                          ; bf018001
	s_cbranch_scc0 BB154                                        ; bf84000a
BB153:
	s_load_dwordx4 s[12:15], s[2:3], 0x30                       ; c00a0301 00000030
	s_mov_b32 s1, src_scc                                       ; be8100fd
	s_add_u32 s5, s7, 8                                         ; 80058807
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s5, s[12:15], s5                        ; c0200146 00000005
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v6, s5, v6                                    ; 020c0c05
	s_branch BB155                                              ; bf820001
BB154:
	s_mov_b32 s1, src_scc                                       ; be8100fd
BB155:
	s_cmp_lg_i32 s0, 0                                          ; bf018000
	s_cbranch_scc0 BB157                                        ; bf84000a
BB156:
	s_load_dwordx4 s[12:15], s[2:3], 0x40                       ; c00a0301 00000040
	s_mov_b32 s0, src_scc                                       ; be8000fd
	s_add_u32 s5, s7, 8                                         ; 80058807
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s5, s[12:15], s5                        ; c0200146 00000005
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v6, s5, v6                                    ; 020c0c05
	s_branch BB158                                              ; bf820001
BB157:
	s_mov_b32 s0, src_scc                                       ; be8000fd
BB158:
	s_add_u32 s5, s7, 8                                         ; 80058807
	buffer_store_dword v6, off, s[8:11], s5                     ; e0700000 05020680
	s_cmp_lt_u32 3, s4                                          ; bf0a0483
	s_cbranch_scc0 BB215                                        ; bf840093
BB159:
	s_cmp_lg_i32 s1, 0                                          ; bf018001
	s_cbranch_scc0 BB161                                        ; bf84000a
BB160:
	s_load_dwordx4 s[12:15], s[2:3], 0x30                       ; c00a0301 00000030
	s_mov_b32 s1, src_scc                                       ; be8100fd
	s_add_u32 s5, s7, 12                                        ; 80058c07
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s5, s[12:15], s5                        ; c0200146 00000005
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v7, s5, v7                                    ; 020e0e05
	s_branch BB162                                              ; bf820001
BB161:
	s_mov_b32 s1, src_scc                                       ; be8100fd
BB162:
	s_cmp_lg_i32 s0, 0                                          ; bf018000
	s_cbranch_scc0 BB164                                        ; bf84000a
BB163:
	s_load_dwordx4 s[12:15], s[2:3], 0x40                       ; c00a0301 00000040
	s_mov_b32 s0, src_scc                                       ; be8000fd
	s_add_u32 s5, s7, 12                                        ; 80058c07
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s5, s[12:15], s5                        ; c0200146 00000005
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v7, s5, v7                                    ; 020e0e05
	s_branch BB165                                              ; bf820001
BB164:
	s_mov_b32 s0, src_scc                                       ; be8000fd
BB165:
	s_add_u32 s5, s7, 12                                        ; 80058c07
	buffer_store_dword v7, off, s[8:11], s5                     ; e0700000 05020780
	s_cmp_lt_u32 4, s4                                          ; bf0a0484
	s_cbranch_scc0 BB215                                        ; bf840074
BB166:
	s_cmp_lg_i32 s1, 0                                          ; bf018001
	s_cbranch_scc0 BB168                                        ; bf84000a
BB167:
	s_load_dwordx4 s[12:15], s[2:3], 0x30                       ; c00a0301 00000030
	s_mov_b32 s1, src_scc                                       ; be8100fd
	s_add_u32 s5, s7, 16                                        ; 80059007
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s5, s[12:15], s5                        ; c0200146 00000005
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v8, s5, v8                                    ; 02101005
	s_branch BB169                                              ; bf820001
BB168:
	s_mov_b32 s1, src_scc                                       ; be8100fd
BB169:
	s_cmp_lg_i32 s0, 0                                          ; bf018000
	s_cbranch_scc0 BB171                                        ; bf84000a
BB170:
	s_load_dwordx4 s[12:15], s[2:3], 0x40                       ; c00a0301 00000040
	s_mov_b32 s0, src_scc                                       ; be8000fd
	s_add_u32 s5, s7, 16                                        ; 80059007
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s5, s[12:15], s5                        ; c0200146 00000005
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v8, s5, v8                                    ; 02101005
	s_branch BB172                                              ; bf820001
BB171:
	s_mov_b32 s0, src_scc                                       ; be8000fd
BB172:
	s_add_u32 s5, s7, 16                                        ; 80059007
	buffer_store_dword v8, off, s[8:11], s5                     ; e0700000 05020880
	s_cmp_lt_u32 5, s4                                          ; bf0a0485
	s_cbranch_scc0 BB215                                        ; bf840055
BB173:
	s_cmp_lg_i32 s1, 0                                          ; bf018001
	s_cbranch_scc0 BB175                                        ; bf84000a
BB174:
	s_load_dwordx4 s[12:15], s[2:3], 0x30                       ; c00a0301 00000030
	s_mov_b32 s1, src_scc                                       ; be8100fd
	s_add_u32 s5, s7, 20                                        ; 80059407
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s5, s[12:15], s5                        ; c0200146 00000005
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v9, s5, v9                                    ; 02121205
	s_branch BB176                                              ; bf820001
BB175:
	s_mov_b32 s1, src_scc                                       ; be8100fd
BB176:
	s_cmp_lg_i32 s0, 0                                          ; bf018000
	s_cbranch_scc0 BB178                                        ; bf84000a
BB177:
	s_load_dwordx4 s[12:15], s[2:3], 0x40                       ; c00a0301 00000040
	s_mov_b32 s0, src_scc                                       ; be8000fd
	s_add_u32 s5, s7, 20                                        ; 80059407
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s5, s[12:15], s5                        ; c0200146 00000005
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v9, s5, v9                                    ; 02121205
	s_branch BB179                                              ; bf820001
BB178:
	s_mov_b32 s0, src_scc                                       ; be8000fd
BB179:
	s_add_u32 s5, s7, 20                                        ; 80059407
	buffer_store_dword v9, off, s[8:11], s5                     ; e0700000 05020980
	s_cmp_lt_u32 6, s4                                          ; bf0a0486
	s_cbranch_scc0 BB215                                        ; bf840036
BB180:
	s_cmp_lg_i32 s1, 0                                          ; bf018001
	s_cbranch_scc0 BB182                                        ; bf84000a
BB181:
	s_load_dwordx4 s[12:15], s[2:3], 0x30                       ; c00a0301 00000030
	s_mov_b32 s1, src_scc                                       ; be8100fd
	s_add_u32 s5, s7, 24                                        ; 80059807
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s5, s[12:15], s5                        ; c0200146 00000005
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v10, s5, v10                                  ; 02141405
	s_branch BB183                                              ; bf820001
BB182:
	s_mov_b32 s1, src_scc                                       ; be8100fd
BB183:
	s_cmp_lg_i32 s0, 0                                          ; bf018000
	s_cbranch_scc0 BB185                                        ; bf84000a
BB184:
	s_load_dwordx4 s[12:15], s[2:3], 0x40                       ; c00a0301 00000040
	s_mov_b32 s0, src_scc                                       ; be8000fd
	s_add_u32 s5, s7, 24                                        ; 80059807
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s5, s[12:15], s5                        ; c0200146 00000005
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v10, s5, v10                                  ; 02141405
	s_branch BB186                                              ; bf820001
BB185:
	s_mov_b32 s0, src_scc                                       ; be8000fd
BB186:
	s_add_u32 s5, s7, 24                                        ; 80059807
	buffer_store_dword v10, off, s[8:11], s5                    ; e0700000 05020a80
	s_cmp_lt_u32 7, s4                                          ; bf0a0487
	s_cbranch_scc0 BB215                                        ; bf840017
BB187:
	s_cmp_lg_i32 s1, 0                                          ; bf018001
	s_cbranch_scc0 BB190                                        ; bf840008
BB188:
	s_load_dwordx4 s[12:15], s[2:3], 0x30                       ; c00a0301 00000030
	s_add_u32 s1, s7, 28                                        ; 80019c07
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s1, s[12:15], s1                        ; c0200046 00000001
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v11, s1, v11                                  ; 02161601
BB190:
	s_cmp_lg_i32 s0, 0                                          ; bf018000
	s_cbranch_scc0 BB193                                        ; bf840008
BB191:
	s_load_dwordx4 s[0:3], s[2:3], 0x40                         ; c00a0001 00000040
	s_add_u32 s4, s7, 28                                        ; 80049c07
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s4, s[0:3], s4                          ; c0200100 00000004
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v11, s4, v11                                  ; 02161604
BB193:
	s_add_u32 s7, s7, 28                                        ; 80079c07
	buffer_store_dword v11, off, s[8:11], s7                    ; e0700000 07020b80
BB215:
	s_endpgm                                                    ; bf810000
