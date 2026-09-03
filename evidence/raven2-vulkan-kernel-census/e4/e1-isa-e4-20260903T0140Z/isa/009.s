Compute Shader
BB0:
	s_load_dword s0, s[14:15], 0x0                              ; c0020007 00000000
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_mul_i32 s0, s0, s18                                       ; 92001200
	s_add_u32 s16, s16, s0                                      ; 80100010
	s_lshl_b32 s16, s16, 2                                      ; 8e108210
	s_add_u32 s1, s16, 4                                        ; 80018410
	s_cmp_ge_u32 s4, s1                                         ; bf090104
	s_cbranch_scc0 BB66                                         ; bf84048d
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
	s_branch BB5                                                ; bf82025b
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
	s_add_u32 s1, 1, s17                                        ; 80011181
	v_add_u32_e32 v14, 0x80, v12                                ; 681c18ff 00000080
	v_lshrrev_b32_e32 v13, 2, v13                               ; 201a1a82
	s_mul_i32 s1, s6, s1                                        ; 92010106
	v_add_u32_e32 v15, s0, v14                                  ; 681e1c00
	v_lshlrev_b32_e32 v13, 4, v13                               ; 241a1a84
	v_add_u32_e32 v12, s1, v12                                  ; 68181801
	v_add_u32_e32 v14, s1, v14                                  ; 681c1c01
	v_lshrrev_b32_e32 v15, 2, v15                               ; 201e1e82
	v_lshrrev_b32_e32 v12, 2, v12                               ; 20181882
	v_lshrrev_b32_e32 v14, 2, v14                               ; 201c1c82
	v_lshlrev_b32_e32 v15, 4, v15                               ; 241e1e84
	v_lshlrev_b32_e32 v12, 4, v12                               ; 24181884
	v_lshlrev_b32_e32 v14, 4, v14                               ; 241c1c84
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_load_dwordx4 v[16:19], v13, s[28:31], 0 offen        ; e05c1000 8007100d
	buffer_load_dwordx4 v[20:23], v13, s[28:31], 0 offen offset:128 ; e05c1080 8007140d
	buffer_load_dwordx4 v[24:27], v15, s[28:31], 0 offen        ; e05c1000 8007180f
	buffer_load_dwordx4 v[28:31], v15, s[28:31], 0 offen offset:128 ; e05c1080 80071c0f
	buffer_load_dwordx4 v[32:35], v12, s[28:31], 0 offen        ; e05c1000 8007200c
	buffer_load_dwordx4 v[36:39], v12, s[28:31], 0 offen offset:128 ; e05c1080 8007240c
	buffer_load_dwordx4 v[40:43], v14, s[28:31], 0 offen        ; e05c1000 8007280e
	buffer_load_dwordx4 v[12:15], v14, s[28:31], 0 offen offset:128 ; e05c1080 80070c0e
	s_mul_i32 s4, s16, s3                                       ; 92040310
	v_lshlrev_b32_e32 v47, 1, v2                                ; 245e0481
	s_add_u32 s4, s18, s4                                       ; 80040412
	v_add_u32_e32 v55, 64, v4                                   ; 686e08c0
	v_add_u32_e32 v53, 8, v47                                   ; 686a5e88
	v_and_b32_e32 v49, -4, v47                                  ; 26625ec4
	v_add_u32_e32 v44, s4, v0                                   ; 68580004
	v_lshlrev_b32_e32 v45, 4, v44                               ; 245a5884
	v_lshl_add_u32 v44, v44, 7, v45                             ; d1fd002c 04b50f2c
	v_add_u32_e32 v48, 4, v44                                   ; 68605884
	v_add_u32_e32 v52, v48, v47                                 ; 68685f30
	v_add_u32_e32 v50, v49, v48                                 ; 68646131
	v_add_u32_e32 v48, v48, v53                                 ; 68606b30
	buffer_load_dword v46, v44, s[24:27], 0 offen               ; e0501000 80062e2c
	buffer_load_dwordx2 v[50:51], v50, s[24:27], 0 offen        ; e0541000 80063232
	buffer_load_ushort v48, v48, s[24:27], 0 offen              ; e0481000 80063030
	v_add_u32_e32 v44, 16, v44                                  ; 68585890
	v_add_u32_e32 v54, v44, v4                                  ; 686c092c
	v_add_u32_e32 v44, v44, v55                                 ; 68586f2c
	s_add_u32 s5, s16, 1                                        ; 80058110
	s_mul_i32 s5, s5, s3                                        ; 92050305
	s_add_u32 s5, s18, s5                                       ; 80050512
	v_add_u32_e32 v56, s5, v0                                   ; 68700005
	v_lshlrev_b32_e32 v57, 4, v56                               ; 24727084
	v_lshl_add_u32 v56, v56, 7, v57                             ; d1fd0038 04e50f38
	v_add_u32_e32 v58, 4, v56                                   ; 68747084
	v_add_u32_e32 v61, 16, v56                                  ; 687a7090
	v_add_u32_e32 v59, v49, v58                                 ; 68767531
	v_add_u32_e32 v60, v58, v47                                 ; 68785f3a
	v_add_u32_e32 v58, v58, v53                                 ; 68746b3a
	v_add_u32_e32 v62, v61, v4                                  ; 687c093d
	v_add_u32_e32 v61, v61, v55                                 ; 687a6f3d
	buffer_load_dword v54, v54, s[24:27], 0 offen               ; e0501000 80063636
	buffer_load_dword v44, v44, s[24:27], 0 offen               ; e0501000 80062c2c
	buffer_load_dword v56, v56, s[24:27], 0 offen               ; e0501000 80063838
	buffer_load_dwordx2 v[64:65], v59, s[24:27], 0 offen        ; e0541000 8006403b
	buffer_load_ushort v58, v58, s[24:27], 0 offen              ; e0481000 80063a3a
	buffer_load_dword v62, v62, s[24:27], 0 offen               ; e0501000 80063e3e
	buffer_load_dword v61, v61, s[24:27], 0 offen               ; e0501000 80063d3d
	s_add_u32 s9, s16, 2                                        ; 80098210
	s_mul_i32 s9, s9, s3                                        ; 92090309
	s_add_u32 s9, s18, s9                                       ; 80090912
	v_add_u32_e32 v63, s9, v0                                   ; 687e0009
	v_lshlrev_b32_e32 v66, 4, v63                               ; 24847e84
	v_lshl_add_u32 v63, v63, 7, v66                             ; d1fd003f 05090f3f
	v_add_u32_e32 v70, 16, v63                                  ; 688c7e90
	v_add_u32_e32 v67, 4, v63                                   ; 68867e84
	v_add_u32_e32 v71, v70, v4                                  ; 688e0946
	v_add_u32_e32 v70, v70, v55                                 ; 688c6f46
	v_add_u32_e32 v69, v67, v47                                 ; 688a5f43
	v_add_u32_e32 v68, v49, v67                                 ; 68888731
	v_add_u32_e32 v67, v67, v53                                 ; 68866b43
	buffer_load_dword v63, v63, s[24:27], 0 offen               ; e0501000 80063f3f
	buffer_load_dwordx2 v[72:73], v68, s[24:27], 0 offen        ; e0541000 80064844
	buffer_load_ushort v67, v67, s[24:27], 0 offen              ; e0481000 80064343
	buffer_load_dword v71, v71, s[24:27], 0 offen               ; e0501000 80064747
	buffer_load_dword v70, v70, s[24:27], 0 offen               ; e0501000 80064646
	s_add_u32 s10, s16, 3                                       ; 800a8310
	s_mul_i32 s10, s10, s3                                      ; 920a030a
	s_add_u32 s10, s18, s10                                     ; 800a0a12
	v_add_u32_e32 v74, s10, v0                                  ; 6894000a
	v_lshlrev_b32_e32 v75, 4, v74                               ; 24969484
	v_lshl_add_u32 v74, v74, 7, v75                             ; d1fd004a 052d0f4a
	v_add_u32_e32 v77, 16, v74                                  ; 689a9490
	v_add_u32_e32 v76, 4, v74                                   ; 68989484
	v_add_u32_e32 v78, v77, v4                                  ; 689c094d
	v_add_u32_e32 v77, v77, v55                                 ; 689a6f4d
	v_add_u32_e32 v47, v76, v47                                 ; 685e5f4c
	v_add_u32_e32 v49, v49, v76                                 ; 68629931
	v_add_u32_e32 v76, v76, v53                                 ; 68986b4c
	buffer_load_dword v74, v74, s[24:27], 0 offen               ; e0501000 80064a4a
	buffer_load_dwordx2 v[80:81], v49, s[24:27], 0 offen        ; e0541000 80065031
	buffer_load_ushort v76, v76, s[24:27], 0 offen              ; e0481000 80064c4c
	buffer_load_dword v78, v78, s[24:27], 0 offen               ; e0501000 80064e4e
	buffer_load_dword v77, v77, s[24:27], 0 offen               ; e0501000 80064d4d
	s_mov_b32 s11, 0xf0f0f0f                                    ; be8b00ff 0f0f0f0f
	s_mov_b32 s12, 0xc0c0c0c0                                   ; be8c00ff c0c0c0c0
	s_mov_b32 s13, 0x3f3f3f3f                                   ; be8d00ff 3f3f3f3f
	v_add_u32_e32 v0, 4, v0                                     ; 68000084
	s_waitcnt vmcnt(27)                                         ; bf8c7f7b
	v_add_f32_e32 v79, v16, v17                                 ; 029e2310
	s_waitcnt vmcnt(26)                                         ; bf8c7f7a
	v_add_f32_e32 v82, v20, v21                                 ; 02a42b14
	s_waitcnt vmcnt(25)                                         ; bf8c7f79
	v_add_f32_e32 v83, v24, v25                                 ; 02a63318
	s_waitcnt vmcnt(24)                                         ; bf8c7f78
	v_add_f32_e32 v84, v28, v29                                 ; 02a83b1c
	s_waitcnt vmcnt(23)                                         ; bf8c7f77
	v_add_f32_e32 v85, v32, v33                                 ; 02aa4320
	s_waitcnt vmcnt(22)                                         ; bf8c7f76
	v_add_f32_e32 v86, v36, v37                                 ; 02ac4b24
	v_add_f32_e32 v79, v79, v18                                 ; 029e254f
	v_add_f32_e32 v82, v82, v22                                 ; 02a42d52
	s_waitcnt vmcnt(21)                                         ; bf8c7f75
	v_add_f32_e32 v87, v40, v41                                 ; 02ae5328
	v_add_f32_e32 v83, v83, v26                                 ; 02a63553
	v_add_f32_e32 v84, v84, v30                                 ; 02a83d54
	v_add_f32_e32 v85, v85, v34                                 ; 02aa4555
	s_waitcnt vmcnt(20)                                         ; bf8c7f74
	v_add_f32_e32 v88, v12, v13                                 ; 02b01b0c
	v_add_f32_e32 v86, v86, v38                                 ; 02ac4d56
	v_add_f32_e32 v79, v79, v19                                 ; 029e274f
	v_add_f32_e32 v82, v82, v23                                 ; 02a42f52
	s_waitcnt vmcnt(19)                                         ; bf8c7f73
	v_cvt_f32_f16_sdwa v89, v46 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7eb216f9 0005062e
	v_add_f32_e32 v87, v87, v42                                 ; 02ae5557
	v_cvt_f32_f16_e32 v46, v46                                  ; 7e5c172e
	v_add_f32_e32 v83, v83, v27                                 ; 02a63753
	s_waitcnt vmcnt(18)                                         ; bf8c7f72
	v_alignbyte_b32 v50, v51, v50, v52                          ; d1cf0032 04d26533
	v_add_f32_e32 v84, v84, v31                                 ; 02a83f54
	v_alignbyte_b32 v51, v51, v51, v52                          ; d1cf0033 04d26733
	v_add_f32_e32 v85, v85, v35                                 ; 02aa4755
	v_add_f32_e32 v88, v88, v14                                 ; 02b01d58
	v_add_f32_e32 v86, v86, v39                                 ; 02ac4f56
	v_add_f32_e32 v87, v87, v43                                 ; 02ae5757
	s_waitcnt vmcnt(17)                                         ; bf8c7f71
	v_lshl_or_b32 v48, v48, 12, v48                             ; d2000030 04c11930
	v_mov_b32_sdwa v50, v51 dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_0 ; 7e6402f9 00041533
	v_add_f32_e32 v88, v88, v15                                 ; 02b01f58
	v_and_b32_e32 v90, s12, v50                                 ; 26b4640c
	v_and_b32_e32 v50, s13, v50                                 ; 2664640d
	v_lshrrev_b32_e32 v90, 2, v90                               ; 20b4b482
	v_cvt_f32_ubyte2_e32 v92, v50                               ; 7eb82732
	v_cvt_f32_ubyte1_e32 v93, v50                               ; 7eba2532
	v_cvt_f32_ubyte3_e32 v91, v50                               ; 7eb62932
	v_cvt_f32_ubyte0_e32 v50, v50                               ; 7e642332
	v_and_or_b32 v48, s11, v48, v90                             ; d2010030 056a600b
	s_waitcnt vmcnt(16)                                         ; bf8c7f70
	v_and_b32_e32 v98, s11, v54                                 ; 26c46c0b
	v_cvt_f32_ubyte2_e32 v96, v48                               ; 7ec02730
	v_cvt_f32_ubyte3_e32 v94, v48                               ; 7ebc2930
	v_cvt_f32_ubyte1_e32 v97, v48                               ; 7ec22530
	v_cvt_f32_ubyte0_e32 v48, v48                               ; 7e602330
	v_cvt_f32_ubyte2_e32 v101, v98                              ; 7eca2762
	v_cvt_f32_ubyte3_e32 v99, v98                               ; 7ec62962
	v_mul_f32_e32 v95, v84, v94                                 ; 0abebd54
	v_mul_f32_e32 v94, v88, v94                                 ; 0abcbd58
	v_cvt_f32_ubyte1_e32 v102, v98                              ; 7ecc2562
	v_cvt_f32_ubyte0_e32 v98, v98                               ; 7ec42362
	v_mul_f32_e32 v100, v19, v99                                ; 0ac8c713
	v_lshrrev_b32_e32 v54, 4, v54                               ; 206c6c84
	v_mac_f32_e32 v95, v83, v96                                 ; 2cbec153
	v_mac_f32_e32 v94, v87, v96                                 ; 2cbcc157
	v_mac_f32_e32 v100, v18, v101                               ; 2cc8cb12
	v_and_b32_e32 v54, s11, v54                                 ; 266c6c0b
	v_mac_f32_e32 v95, v82, v91                                 ; 2cbeb752
	v_mac_f32_e32 v94, v86, v91                                 ; 2cbcb756
	v_mac_f32_e32 v100, v17, v102                               ; 2cc8cd11
	v_mul_f32_e32 v99, v35, v99                                 ; 0ac6c723
	v_cvt_f32_ubyte2_e32 v105, v54                              ; 7ed22736
	v_cvt_f32_ubyte1_e32 v106, v54                              ; 7ed42536
	v_cvt_f32_ubyte3_e32 v103, v54                              ; 7ece2936
	v_cvt_f32_ubyte0_e32 v54, v54                               ; 7e6c2336
	v_mac_f32_e32 v95, v79, v92                                 ; 2cbeb94f
	v_mac_f32_e32 v94, v85, v92                                 ; 2cbcb955
	v_mac_f32_e32 v100, v16, v98                                ; 2cc8c510
	v_mac_f32_e32 v99, v34, v101                                ; 2cc6cb22
	v_mul_f32_e32 v104, v23, v103                               ; 0ad0cf17
	v_mul_f32_e32 v103, v39, v103                               ; 0acecf27
	s_waitcnt vmcnt(15)                                         ; bf8c3f7f
	v_and_b32_e32 v107, s11, v44                                ; 26d6580b
	v_mad_f32 v3, -v89, v95, v3                                 ; d1c10003 240ebf59
	v_mad_f32 v8, -v89, v94, v8                                 ; d1c10008 2422bd59
	v_mac_f32_e32 v99, v33, v102                                ; 2cc6cd21
	v_mac_f32_e32 v104, v22, v105                               ; 2cd0d316
	v_mac_f32_e32 v103, v38, v105                               ; 2cced326
	v_cvt_f32_ubyte2_e32 v110, v107                             ; 7edc276b
	v_cvt_f32_ubyte1_e32 v111, v107                             ; 7ede256b
	v_cvt_f32_ubyte3_e32 v108, v107                             ; 7ed8296b
	v_cvt_f32_ubyte0_e32 v107, v107                             ; 7ed6236b
	v_lshrrev_b32_e32 v44, 4, v44                               ; 20585884
	v_mac_f32_e32 v99, v32, v98                                 ; 2cc6c520
	v_mac_f32_e32 v104, v21, v106                               ; 2cd0d515
	v_mac_f32_e32 v103, v37, v106                               ; 2cced525
	v_mul_f32_e32 v109, v27, v108                               ; 0adad91b
	v_and_b32_e32 v44, s11, v44                                 ; 2658580b
	v_mac_f32_e32 v104, v20, v54                                ; 2cd06d14
	v_mac_f32_e32 v103, v36, v54                                ; 2cce6d24
	v_mac_f32_e32 v109, v26, v110                               ; 2cdadd1a
	v_cvt_f32_ubyte2_e32 v114, v44                              ; 7ee4272c
	v_cvt_f32_ubyte1_e32 v115, v44                              ; 7ee6252c
	v_cvt_f32_ubyte3_e32 v112, v44                              ; 7ee0292c
	v_cvt_f32_ubyte0_e32 v44, v44                               ; 7e58232c
	v_mul_f32_e32 v108, v43, v108                               ; 0ad8d92b
	v_mac_f32_e32 v109, v25, v111                               ; 2cdadf19
	v_mul_f32_e32 v113, v31, v112                               ; 0ae2e11f
	v_mul_f32_e32 v112, v15, v112                               ; 0ae0e10f
	v_mac_f32_e32 v108, v42, v110                               ; 2cd8dd2a
	v_mac_f32_e32 v109, v24, v107                               ; 2cdad718
	v_mac_f32_e32 v113, v30, v114                               ; 2ce2e51e
	v_mac_f32_e32 v112, v14, v114                               ; 2ce0e50e
	v_mac_f32_e32 v108, v41, v111                               ; 2cd8df29
	v_mac_f32_e32 v113, v29, v115                               ; 2ce2e71d
	s_waitcnt vmcnt(14)                                         ; bf8c3f7e
	v_cvt_f32_f16_sdwa v116, v56 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7ee816f9 00050638
	v_mac_f32_e32 v112, v13, v115                               ; 2ce0e70d
	v_mac_f32_e32 v108, v40, v107                               ; 2cd8d728
	v_cvt_f32_f16_e32 v56, v56                                  ; 7e701738
	s_waitcnt vmcnt(13)                                         ; bf8c3f7d
	v_alignbyte_b32 v64, v65, v64, v60                          ; d1cf0040 04f28141
	v_mac_f32_e32 v113, v28, v44                                ; 2ce2591c
	v_alignbyte_b32 v65, v65, v65, v60                          ; d1cf0041 04f28341
	v_mac_f32_e32 v112, v12, v44                                ; 2ce0590c
	v_mul_f32_e32 v113, v113, v97                               ; 0ae2c371
	v_mov_b32_sdwa v64, v65 dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_0 ; 7e8002f9 00041541
	v_mul_f32_e32 v112, v112, v97                               ; 0ae0c370
	v_mac_f32_e32 v113, v109, v48                               ; 2ce2616d
	s_waitcnt vmcnt(12)                                         ; bf8c3f7c
	v_lshl_or_b32 v58, v58, 12, v58                             ; d200003a 04e9193a
	v_and_b32_e32 v117, s12, v64                                ; 26ea800c
	v_and_b32_e32 v64, s13, v64                                 ; 2680800d
	v_mac_f32_e32 v112, v108, v48                               ; 2ce0616c
	v_mac_f32_e32 v113, v104, v93                               ; 2ce2bb68
	v_lshrrev_b32_e32 v117, 2, v117                             ; 20eaea82
	v_cvt_f32_ubyte2_e32 v119, v64                              ; 7eee2740
	v_cvt_f32_ubyte3_e32 v118, v64                              ; 7eec2940
	v_cvt_f32_ubyte1_e32 v120, v64                              ; 7ef02540
	v_cvt_f32_ubyte0_e32 v64, v64                               ; 7e802340
	v_mac_f32_e32 v112, v103, v93                               ; 2ce0bb67
	v_mac_f32_e32 v113, v100, v50                               ; 2ce26564
	v_and_or_b32 v58, s11, v58, v117                            ; d201003a 05d6740b
	v_mac_f32_e32 v112, v99, v50                                ; 2ce06563
	v_mac_f32_e32 v3, v46, v113                                 ; 2c06e32e
	v_cvt_f32_ubyte1_e32 v124, v58                              ; 7ef8253a
	v_cvt_f32_ubyte3_e32 v121, v58                              ; 7ef2293a
	v_cvt_f32_ubyte2_e32 v123, v58                              ; 7ef6273a
	v_cvt_f32_ubyte0_e32 v58, v58                               ; 7e74233a
	v_mac_f32_e32 v8, v46, v112                                 ; 2c10e12e
	s_waitcnt vmcnt(11)                                         ; bf8c3f7b
	v_and_b32_e32 v125, s11, v62                                ; 26fa7c0b
	v_mul_f32_e32 v122, v84, v121                               ; 0af4f354
	v_mul_f32_e32 v121, v88, v121                               ; 0af2f358
	v_cvt_f32_ubyte3_e32 v126, v125                             ; 7efc297d
	v_cvt_f32_ubyte1_e32 v46, v125                              ; 7e5c257d
	v_cvt_f32_ubyte2_e32 v45, v125                              ; 7e5a277d
	v_cvt_f32_ubyte0_e32 v125, v125                             ; 7efa237d
	v_mac_f32_e32 v122, v83, v123                               ; 2cf4f753
	v_lshrrev_b32_e32 v62, 4, v62                               ; 207c7c84
	v_mac_f32_e32 v121, v87, v123                               ; 2cf2f757
	v_mul_f32_e32 v44, v19, v126                                ; 0a58fd13
	v_mac_f32_e32 v122, v82, v118                               ; 2cf4ed52
	v_and_b32_e32 v62, s11, v62                                 ; 267c7c0b
	v_mac_f32_e32 v121, v86, v118                               ; 2cf2ed56
	v_mac_f32_e32 v44, v18, v45                                 ; 2c585b12
	v_mac_f32_e32 v122, v79, v119                               ; 2cf4ef4f
	v_cvt_f32_ubyte2_e32 v50, v62                               ; 7e64273e
	v_mul_f32_e32 v126, v35, v126                               ; 0afcfd23
	v_cvt_f32_ubyte1_e32 v51, v62                               ; 7e66253e
	v_cvt_f32_ubyte3_e32 v48, v62                               ; 7e60293e
	v_cvt_f32_ubyte0_e32 v62, v62                               ; 7e7c233e
	v_mac_f32_e32 v121, v85, v119                               ; 2cf2ef55
	v_mac_f32_e32 v44, v17, v46                                 ; 2c585d11
	v_mad_f32 v5, -v116, v122, v5                               ; d1c10005 2416f574
	v_mac_f32_e32 v126, v34, v45                                ; 2cfc5b22
	s_waitcnt vmcnt(10)                                         ; bf8c3f7a
	v_and_b32_e32 v52, s11, v61                                 ; 26687a0b
	v_mul_f32_e32 v49, v23, v48                                 ; 0a626117
	v_mul_f32_e32 v48, v39, v48                                 ; 0a606127
	v_mad_f32 v9, -v116, v121, v9                               ; d1c10009 2426f374
	v_mac_f32_e32 v44, v16, v125                                ; 2c58fb10
	v_mac_f32_e32 v126, v33, v46                                ; 2cfc5d21
	v_cvt_f32_ubyte1_e32 v57, v52                               ; 7e722534
	v_cvt_f32_ubyte3_e32 v53, v52                               ; 7e6a2934
	v_cvt_f32_ubyte2_e32 v55, v52                               ; 7e6e2734
	v_mac_f32_e32 v49, v22, v50                                 ; 2c626516
	v_cvt_f32_ubyte0_e32 v52, v52                               ; 7e682334
	v_mac_f32_e32 v48, v38, v50                                 ; 2c606526
	v_lshrrev_b32_e32 v61, 4, v61                               ; 207a7a84
	v_mac_f32_e32 v126, v32, v125                               ; 2cfcfb20
	v_mul_f32_e32 v54, v27, v53                                 ; 0a6c6b1b
	v_mac_f32_e32 v49, v21, v51                                 ; 2c626715
	v_mac_f32_e32 v48, v37, v51                                 ; 2c606725
	v_and_b32_e32 v61, s11, v61                                 ; 267a7a0b
	v_mac_f32_e32 v54, v26, v55                                 ; 2c6c6f1a
	v_mac_f32_e32 v49, v20, v62                                 ; 2c627d14
	v_cvt_f32_ubyte3_e32 v59, v61                               ; 7e76293d
	v_cvt_f32_ubyte1_e32 v66, v61                               ; 7e84253d
	v_cvt_f32_ubyte2_e32 v65, v61                               ; 7e82273d
	v_cvt_f32_ubyte0_e32 v61, v61                               ; 7e7a233d
	v_mac_f32_e32 v48, v36, v62                                 ; 2c607d24
	v_mac_f32_e32 v54, v25, v57                                 ; 2c6c7319
	v_mul_f32_e32 v53, v43, v53                                 ; 0a6a6b2b
	v_mul_f32_e32 v60, v31, v59                                 ; 0a78771f
	v_mul_f32_e32 v59, v15, v59                                 ; 0a76770f
	v_mac_f32_e32 v54, v24, v52                                 ; 2c6c6918
	v_mac_f32_e32 v53, v42, v55                                 ; 2c6a6f2a
	v_mac_f32_e32 v60, v30, v65                                 ; 2c78831e
	v_mac_f32_e32 v59, v14, v65                                 ; 2c76830e
	v_mac_f32_e32 v53, v41, v57                                 ; 2c6a7329
	v_mac_f32_e32 v60, v29, v66                                 ; 2c78851d
	v_mac_f32_e32 v59, v13, v66                                 ; 2c76850d
	s_waitcnt vmcnt(8)                                          ; bf8c3f78
	v_alignbyte_b32 v72, v73, v72, v69                          ; d1cf0048 05169149
	v_mac_f32_e32 v53, v40, v52                                 ; 2c6a6928
	v_alignbyte_b32 v73, v73, v73, v69                          ; d1cf0049 05169349
	v_mac_f32_e32 v60, v28, v61                                 ; 2c787b1c
	v_mac_f32_e32 v59, v12, v61                                 ; 2c767b0c
	s_waitcnt vmcnt(7)                                          ; bf8c3f77
	v_lshl_or_b32 v67, v67, 12, v67                             ; d2000043 050d1943
	v_mov_b32_sdwa v72, v73 dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_0 ; 7e9002f9 00041549
	s_waitcnt vmcnt(6)                                          ; bf8c3f76
	v_and_b32_e32 v69, s11, v71                                 ; 268a8e0b
	v_mul_f32_e32 v60, v60, v124                                ; 0a78f93c
	v_mul_f32_e32 v59, v59, v124                                ; 0a76f93b
	v_and_b32_e32 v68, s12, v72                                 ; 2688900c
	v_cvt_f32_ubyte2_e32 v89, v69                               ; 7eb22745
	v_cvt_f32_ubyte3_e32 v73, v69                               ; 7e922945
	v_mac_f32_e32 v60, v54, v58                                 ; 2c787536
	v_cvt_f32_ubyte1_e32 v90, v69                               ; 7eb42545
	v_mac_f32_e32 v59, v53, v58                                 ; 2c767535
	v_cvt_f32_ubyte0_e32 v69, v69                               ; 7e8a2345
	v_lshrrev_b32_e32 v68, 2, v68                               ; 20888882
	v_lshrrev_b32_e32 v71, 4, v71                               ; 208e8e84
	v_mul_f32_e32 v75, v19, v73                                 ; 0a969313
	v_mac_f32_e32 v60, v49, v120                                ; 2c78f131
	v_mac_f32_e32 v59, v48, v120                                ; 2c76f130
	v_and_or_b32 v67, s11, v67, v68                             ; d2010043 0512860b
	v_and_b32_e32 v71, s11, v71                                 ; 268e8e0b
	v_mac_f32_e32 v75, v18, v89                                 ; 2c96b312
	v_mac_f32_e32 v60, v44, v64                                 ; 2c78812c
	v_mac_f32_e32 v59, v126, v64                                ; 2c76817e
	s_waitcnt vmcnt(5)                                          ; bf8c3f75
	v_and_b32_e32 v95, s11, v70                                 ; 26be8c0b
	v_cvt_f32_ubyte1_e32 v94, v71                               ; 7ebc2547
	v_cvt_f32_ubyte3_e32 v91, v71                               ; 7eb62947
	v_cvt_f32_ubyte2_e32 v93, v71                               ; 7eba2747
	v_cvt_f32_ubyte0_e32 v71, v71                               ; 7e8e2347
	v_mac_f32_e32 v75, v17, v90                                 ; 2c96b511
	v_mac_f32_e32 v5, v56, v60                                  ; 2c0a7938
	v_mac_f32_e32 v9, v56, v59                                  ; 2c127738
	v_cvt_f32_ubyte2_e32 v98, v95                               ; 7ec4275f
	v_cvt_f32_ubyte1_e32 v99, v95                               ; 7ec6255f
	v_cvt_f32_ubyte3_e32 v96, v95                               ; 7ec0295f
	v_mul_f32_e32 v92, v23, v91                                 ; 0ab8b717
	v_cvt_f32_ubyte0_e32 v95, v95                               ; 7ebe235f
	v_lshrrev_b32_e32 v70, 4, v70                               ; 208c8c84
	v_mac_f32_e32 v75, v16, v69                                 ; 2c968b10
	v_mul_f32_e32 v97, v27, v96                                 ; 0ac2c11b
	v_mac_f32_e32 v92, v22, v93                                 ; 2cb8bb16
	v_and_b32_e32 v70, s11, v70                                 ; 268c8c0b
	v_cvt_f32_ubyte3_e32 v104, v67                              ; 7ed02943
	v_mac_f32_e32 v97, v26, v98                                 ; 2cc2c51a
	v_cvt_f32_ubyte2_e32 v106, v67                              ; 7ed42743
	v_mac_f32_e32 v92, v21, v94                                 ; 2cb8bd15
	v_cvt_f32_ubyte2_e32 v102, v70                              ; 7ecc2746
	v_cvt_f32_ubyte3_e32 v100, v70                              ; 7ec82946
	v_cvt_f32_ubyte1_e32 v103, v70                              ; 7ece2546
	v_cvt_f32_ubyte0_e32 v70, v70                               ; 7e8c2346
	v_mul_f32_e32 v105, v84, v104                               ; 0ad2d154
	v_and_b32_e32 v72, s13, v72                                 ; 2690900d
	v_mac_f32_e32 v97, v25, v99                                 ; 2cc2c719
	v_mac_f32_e32 v92, v20, v71                                 ; 2cb88f14
	v_mul_f32_e32 v101, v31, v100                               ; 0acac91f
	v_cvt_f32_ubyte1_e32 v109, v67                              ; 7eda2543
	v_cvt_f32_ubyte0_e32 v67, v67                               ; 7e862343
	v_mac_f32_e32 v105, v83, v106                               ; 2cd2d553
	v_cvt_f32_ubyte2_e32 v108, v72                              ; 7ed82748
	v_cvt_f32_ubyte1_e32 v110, v72                              ; 7edc2548
	v_cvt_f32_ubyte3_e32 v107, v72                              ; 7ed62948
	v_mac_f32_e32 v97, v24, v95                                 ; 2cc2bf18
	v_cvt_f32_ubyte0_e32 v72, v72                               ; 7e902348
	v_mac_f32_e32 v101, v30, v102                               ; 2ccacd1e
	v_cvt_f32_f16_sdwa v111, v63 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7ede16f9 0005063f
	v_cvt_f32_f16_e32 v63, v63                                  ; 7e7e173f
	v_mul_f32_e32 v73, v35, v73                                 ; 0a929323
	v_mac_f32_e32 v105, v82, v107                               ; 2cd2d752
	v_mul_f32_e32 v91, v39, v91                                 ; 0ab6b727
	v_mac_f32_e32 v101, v29, v103                               ; 2ccacf1d
	v_mac_f32_e32 v73, v34, v89                                 ; 2c92b322
	v_mul_f32_e32 v96, v43, v96                                 ; 0ac0c12b
	v_mac_f32_e32 v105, v79, v108                               ; 2cd2d94f
	v_mac_f32_e32 v91, v38, v93                                 ; 2cb6bb26
	v_mac_f32_e32 v101, v28, v70                                ; 2cca8d1c
	v_mac_f32_e32 v73, v33, v90                                 ; 2c92b521
	v_mul_f32_e32 v100, v15, v100                               ; 0ac8c90f
	v_mac_f32_e32 v96, v42, v98                                 ; 2cc0c52a
	v_mad_f32 v6, -v111, v105, v6                               ; d1c10006 241ad36f
	v_mac_f32_e32 v91, v37, v94                                 ; 2cb6bd25
	v_mul_f32_e32 v101, v101, v109                              ; 0acadb65
	v_mul_f32_e32 v104, v88, v104                               ; 0ad0d158
	v_mac_f32_e32 v73, v32, v69                                 ; 2c928b20
	v_mac_f32_e32 v100, v14, v102                               ; 2cc8cd0e
	v_mac_f32_e32 v96, v41, v99                                 ; 2cc0c729
	v_mac_f32_e32 v91, v36, v71                                 ; 2cb68f24
	v_mac_f32_e32 v101, v97, v67                                ; 2cca8761
	v_mac_f32_e32 v104, v87, v106                               ; 2cd0d557
	v_mac_f32_e32 v100, v13, v103                               ; 2cc8cf0d
	v_mac_f32_e32 v96, v40, v95                                 ; 2cc0bf28
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_alignbyte_b32 v80, v81, v80, v47                          ; d1cf0050 04bea151
	v_mac_f32_e32 v101, v92, v110                               ; 2ccadd5c
	v_alignbyte_b32 v81, v81, v81, v47                          ; d1cf0051 04bea351
	v_mac_f32_e32 v104, v86, v107                               ; 2cd0d756
	v_mac_f32_e32 v100, v12, v70                                ; 2cc88d0c
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_lshl_or_b32 v76, v76, 12, v76                             ; d200004c 0531194c
	v_mac_f32_e32 v101, v75, v72                                ; 2cca914b
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v113, s11, v78                                ; 26e29c0b
	v_mov_b32_sdwa v80, v81 dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_0 ; 7ea002f9 00041551
	v_mac_f32_e32 v104, v85, v108                               ; 2cd0d955
	v_mul_f32_e32 v100, v100, v109                              ; 0ac8db64
	v_mac_f32_e32 v6, v63, v101                                 ; 2c0ccb3f
	v_cvt_f32_ubyte3_e32 v114, v113                             ; 7ee42971
	v_cvt_f32_ubyte2_e32 v115, v113                             ; 7ee62771
	v_cvt_f32_ubyte1_e32 v116, v113                             ; 7ee82571
	v_and_b32_e32 v112, s12, v80                                ; 26e0a00c
	v_cvt_f32_ubyte0_e32 v113, v113                             ; 7ee22371
	v_mad_f32 v10, -v111, v104, v10                             ; d1c1000a 242ad16f
	v_mac_f32_e32 v100, v96, v67                                ; 2cc88760
	v_lshrrev_b32_e32 v78, 4, v78                               ; 209c9c84
	v_mul_f32_e32 v19, v19, v114                                ; 0a26e513
	v_lshrrev_b32_e32 v112, 2, v112                             ; 20e0e082
	v_mac_f32_e32 v100, v91, v110                               ; 2cc8dd5b
	v_and_b32_e32 v78, s11, v78                                 ; 269c9c0b
	v_mac_f32_e32 v19, v18, v115                                ; 2c26e712
	v_and_or_b32 v76, s11, v76, v112                            ; d201004c 05c2980b
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v120, s11, v77                                ; 26f09a0b
	v_mac_f32_e32 v100, v73, v72                                ; 2cc89149
	v_cvt_f32_ubyte2_e32 v118, v78                              ; 7eec274e
	v_cvt_f32_ubyte1_e32 v119, v78                              ; 7eee254e
	v_cvt_f32_ubyte3_e32 v117, v78                              ; 7eea294e
	v_cvt_f32_ubyte0_e32 v78, v78                               ; 7e9c234e
	v_mac_f32_e32 v19, v17, v116                                ; 2c26e911
	v_cvt_f32_ubyte1_e32 v123, v120                             ; 7ef62578
	v_cvt_f32_ubyte3_e32 v121, v120                             ; 7ef22978
	v_cvt_f32_ubyte2_e32 v122, v120                             ; 7ef42778
	v_mac_f32_e32 v10, v63, v100                                ; 2c14c93f
	v_cvt_f32_ubyte0_e32 v120, v120                             ; 7ef02378
	v_lshrrev_b32_e32 v77, 4, v77                               ; 209a9a84
	v_mul_f32_e32 v23, v23, v117                                ; 0a2eeb17
	v_mac_f32_e32 v19, v16, v113                                ; 2c26e310
	v_mul_f32_e32 v27, v27, v121                                ; 0a36f31b
	v_and_b32_e32 v77, s11, v77                                 ; 269a9a0b
	v_mac_f32_e32 v23, v22, v118                                ; 2c2eed16
	v_cvt_f32_ubyte3_e32 v16, v76                               ; 7e20294c
	v_mac_f32_e32 v27, v26, v122                                ; 2c36f51a
	v_cvt_f32_ubyte3_e32 v124, v77                              ; 7ef8294d
	v_cvt_f32_ubyte1_e32 v126, v77                              ; 7efc254d
	v_cvt_f32_ubyte2_e32 v17, v76                               ; 7e22274c
	v_cvt_f32_ubyte2_e32 v125, v77                              ; 7efa274d
	v_cvt_f32_ubyte0_e32 v77, v77                               ; 7e9a234d
	v_mac_f32_e32 v23, v21, v119                                ; 2c2eef15
	v_mul_f32_e32 v84, v84, v16                                 ; 0aa82154
	v_and_b32_e32 v80, s13, v80                                 ; 26a0a00d
	v_mac_f32_e32 v27, v25, v123                                ; 2c36f719
	v_mul_f32_e32 v31, v31, v124                                ; 0a3ef91f
	v_cvt_f32_ubyte1_e32 v21, v76                               ; 7e2a254c
	v_mac_f32_e32 v23, v20, v78                                 ; 2c2e9d14
	v_cvt_f32_ubyte0_e32 v76, v76                               ; 7e98234c
	v_mac_f32_e32 v84, v83, v17                                 ; 2ca82353
	v_cvt_f32_ubyte1_e32 v22, v80                               ; 7e2c2550
	v_cvt_f32_ubyte3_e32 v18, v80                               ; 7e242950
	v_cvt_f32_ubyte2_e32 v20, v80                               ; 7e282750
	v_mac_f32_e32 v27, v24, v120                                ; 2c36f118
	v_cvt_f32_ubyte0_e32 v80, v80                               ; 7ea02350
	v_mac_f32_e32 v31, v30, v125                                ; 2c3efb1e
	v_mac_f32_e32 v84, v82, v18                                 ; 2ca82552
	v_mul_f32_e32 v35, v35, v114                                ; 0a46e523
	v_mac_f32_e32 v31, v29, v126                                ; 2c3efd1d
	v_mul_f32_e32 v39, v39, v117                                ; 0a4eeb27
	v_mac_f32_e32 v84, v79, v20                                 ; 2ca8294f
	v_mac_f32_e32 v35, v34, v115                                ; 2c46e722
	v_mac_f32_e32 v31, v28, v77                                 ; 2c3e9b1c
	v_mac_f32_e32 v39, v38, v118                                ; 2c4eed26
	v_mul_f32_e32 v43, v43, v121                                ; 0a56f32b
	v_mac_f32_e32 v35, v33, v116                                ; 2c46e921
	v_mul_f32_e32 v31, v31, v21                                 ; 0a3e2b1f
	v_mac_f32_e32 v39, v37, v119                                ; 2c4eef25
	v_mul_f32_e32 v15, v15, v124                                ; 0a1ef90f
	v_mac_f32_e32 v43, v42, v122                                ; 2c56f52a
	v_mac_f32_e32 v35, v32, v113                                ; 2c46e320
	v_mac_f32_e32 v31, v27, v76                                 ; 2c3e991b
	v_mac_f32_e32 v39, v36, v78                                 ; 2c4e9d24
	v_mul_f32_e32 v88, v88, v16                                 ; 0ab02158
	v_mac_f32_e32 v15, v14, v125                                ; 2c1efb0e
	v_mac_f32_e32 v43, v41, v123                                ; 2c56f729
	v_mac_f32_e32 v31, v23, v22                                 ; 2c3e2d17
	v_cvt_f32_f16_sdwa v23, v74 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e2e16f9 0005064a
	v_cvt_f32_f16_e32 v74, v74                                  ; 7e94174a
	v_mac_f32_e32 v88, v87, v17                                 ; 2cb02357
	v_mac_f32_e32 v15, v13, v126                                ; 2c1efd0d
	v_mac_f32_e32 v43, v40, v120                                ; 2c56f128
	v_mac_f32_e32 v31, v19, v80                                 ; 2c3ea113
	v_mad_f32 v7, -v23, v84, v7                                 ; d1c10007 241ea917
	v_mac_f32_e32 v88, v86, v18                                 ; 2cb02556
	v_mac_f32_e32 v15, v12, v77                                 ; 2c1e9b0c
	v_mac_f32_e32 v7, v74, v31                                  ; 2c0e3f4a
	v_mac_f32_e32 v88, v85, v20                                 ; 2cb02955
	v_mul_f32_e32 v15, v15, v21                                 ; 0a1e2b0f
	v_mad_f32 v11, -v23, v88, v11                               ; d1c1000b 242eb117
	v_mac_f32_e32 v15, v43, v76                                 ; 2c1e992b
	v_mac_f32_e32 v15, v39, v22                                 ; 2c1e2d27
	v_mac_f32_e32 v15, v35, v80                                 ; 2c1ea123
	v_mac_f32_e32 v11, v74, v15                                 ; 2c161f4a
BB5:
	s_mov_b64 s[0:1], exec                                      ; be80017e
	v_cmpx_le_u32_e32 vcc, s3, v0                               ; 7db60003
BB6:
	s_andn2_b64 s[0:1], s[0:1], exec                            ; 89807e00
	s_cbranch_scc1 BB10                                         ; bf85fda7
BB11:
	s_mov_b64 exec, -1                                          ; befe01c1
	s_or_saveexec_b64 s[4:5], -1                                ; be8421c1
	v_cndmask_b32_e64 v127, 0, v3, s[4:5]                       ; d100007f 00120680
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v127, v127, v127 quad_perm:[1,0,3,2] row_mask:0xf bank_mask:0xf ; 02fefefa ff00b17f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v127, v127, v127 quad_perm:[2,3,0,1] row_mask:0xf bank_mask:0xf ; 02fefefa ff004e7f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v127, v127, v127 row_half_mirror row_mask:0xf bank_mask:0xf ; 02fefefa ff01417f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v127, v127, v127 row_mirror row_mask:0xf bank_mask:0xf ; 02fefefa ff01407f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v127, v127, v127 row_bcast:15 row_mask:0xa bank_mask:0xf ; 02fefefa af01427f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v127, v127, v127 row_bcast:31 row_mask:0xc bank_mask:0xf ; 02fefefa cf01437f
	s_mov_b64 exec, s[4:5]                                      ; befe0104
	v_readlane_b32 s0, v127, 63                                 ; d2890000 00017f7f
	s_or_saveexec_b64 s[4:5], -1                                ; be8421c1
	v_cndmask_b32_e64 v127, 0, v5, s[4:5]                       ; d100007f 00120a80
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v127, v127, v127 quad_perm:[1,0,3,2] row_mask:0xf bank_mask:0xf ; 02fefefa ff00b17f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v127, v127, v127 quad_perm:[2,3,0,1] row_mask:0xf bank_mask:0xf ; 02fefefa ff004e7f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v127, v127, v127 row_half_mirror row_mask:0xf bank_mask:0xf ; 02fefefa ff01417f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v127, v127, v127 row_mirror row_mask:0xf bank_mask:0xf ; 02fefefa ff01407f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v127, v127, v127 row_bcast:15 row_mask:0xa bank_mask:0xf ; 02fefefa af01427f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v127, v127, v127 row_bcast:31 row_mask:0xc bank_mask:0xf ; 02fefefa cf01437f
	s_mov_b64 exec, s[4:5]                                      ; befe0104
	v_readlane_b32 s1, v127, 63                                 ; d2890001 00017f7f
	s_or_saveexec_b64 s[4:5], -1                                ; be8421c1
	v_cndmask_b32_e64 v127, 0, v6, s[4:5]                       ; d100007f 00120c80
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v127, v127, v127 quad_perm:[1,0,3,2] row_mask:0xf bank_mask:0xf ; 02fefefa ff00b17f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v127, v127, v127 quad_perm:[2,3,0,1] row_mask:0xf bank_mask:0xf ; 02fefefa ff004e7f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v127, v127, v127 row_half_mirror row_mask:0xf bank_mask:0xf ; 02fefefa ff01417f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v127, v127, v127 row_mirror row_mask:0xf bank_mask:0xf ; 02fefefa ff01407f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v127, v127, v127 row_bcast:15 row_mask:0xa bank_mask:0xf ; 02fefefa af01427f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v127, v127, v127 row_bcast:31 row_mask:0xc bank_mask:0xf ; 02fefefa cf01437f
	s_mov_b64 exec, s[4:5]                                      ; befe0104
	v_readlane_b32 s3, v127, 63                                 ; d2890003 00017f7f
	s_or_saveexec_b64 s[10:11], -1                              ; be8a21c1
	v_cndmask_b32_e64 v127, 0, v7, s[10:11]                     ; d100007f 002a0e80
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v127, v127, v127 quad_perm:[1,0,3,2] row_mask:0xf bank_mask:0xf ; 02fefefa ff00b17f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v127, v127, v127 quad_perm:[2,3,0,1] row_mask:0xf bank_mask:0xf ; 02fefefa ff004e7f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v127, v127, v127 row_half_mirror row_mask:0xf bank_mask:0xf ; 02fefefa ff01417f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v127, v127, v127 row_mirror row_mask:0xf bank_mask:0xf ; 02fefefa ff01407f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v127, v127, v127 row_bcast:15 row_mask:0xa bank_mask:0xf ; 02fefefa af01427f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v127, v127, v127 row_bcast:31 row_mask:0xc bank_mask:0xf ; 02fefefa cf01437f
	s_mov_b64 exec, s[10:11]                                    ; befe010a
	v_readlane_b32 s4, v127, 63                                 ; d2890004 00017f7f
	s_or_saveexec_b64 s[10:11], -1                              ; be8a21c1
	v_cndmask_b32_e64 v127, 0, v8, s[10:11]                     ; d100007f 002a1080
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v127, v127, v127 quad_perm:[1,0,3,2] row_mask:0xf bank_mask:0xf ; 02fefefa ff00b17f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v127, v127, v127 quad_perm:[2,3,0,1] row_mask:0xf bank_mask:0xf ; 02fefefa ff004e7f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v127, v127, v127 row_half_mirror row_mask:0xf bank_mask:0xf ; 02fefefa ff01417f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v127, v127, v127 row_mirror row_mask:0xf bank_mask:0xf ; 02fefefa ff01407f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v127, v127, v127 row_bcast:15 row_mask:0xa bank_mask:0xf ; 02fefefa af01427f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v127, v127, v127 row_bcast:31 row_mask:0xc bank_mask:0xf ; 02fefefa cf01437f
	s_mov_b64 exec, s[10:11]                                    ; befe010a
	v_readlane_b32 s5, v127, 63                                 ; d2890005 00017f7f
	s_or_saveexec_b64 s[10:11], -1                              ; be8a21c1
	v_cndmask_b32_e64 v127, 0, v9, s[10:11]                     ; d100007f 002a1280
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v127, v127, v127 quad_perm:[1,0,3,2] row_mask:0xf bank_mask:0xf ; 02fefefa ff00b17f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v127, v127, v127 quad_perm:[2,3,0,1] row_mask:0xf bank_mask:0xf ; 02fefefa ff004e7f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v127, v127, v127 row_half_mirror row_mask:0xf bank_mask:0xf ; 02fefefa ff01417f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v127, v127, v127 row_mirror row_mask:0xf bank_mask:0xf ; 02fefefa ff01407f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v127, v127, v127 row_bcast:15 row_mask:0xa bank_mask:0xf ; 02fefefa af01427f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v127, v127, v127 row_bcast:31 row_mask:0xc bank_mask:0xf ; 02fefefa cf01437f
	s_mov_b64 exec, s[10:11]                                    ; befe010a
	v_readlane_b32 s6, v127, 63                                 ; d2890006 00017f7f
	s_or_saveexec_b64 s[10:11], -1                              ; be8a21c1
	v_cndmask_b32_e64 v127, 0, v10, s[10:11]                    ; d100007f 002a1480
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v127, v127, v127 quad_perm:[1,0,3,2] row_mask:0xf bank_mask:0xf ; 02fefefa ff00b17f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v127, v127, v127 quad_perm:[2,3,0,1] row_mask:0xf bank_mask:0xf ; 02fefefa ff004e7f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v127, v127, v127 row_half_mirror row_mask:0xf bank_mask:0xf ; 02fefefa ff01417f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v127, v127, v127 row_mirror row_mask:0xf bank_mask:0xf ; 02fefefa ff01407f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v127, v127, v127 row_bcast:15 row_mask:0xa bank_mask:0xf ; 02fefefa af01427f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v127, v127, v127 row_bcast:31 row_mask:0xc bank_mask:0xf ; 02fefefa cf01437f
	s_mov_b64 exec, s[10:11]                                    ; befe010a
	v_readlane_b32 s9, v127, 63                                 ; d2890009 00017f7f
	s_or_saveexec_b64 s[12:13], -1                              ; be8c21c1
	v_cndmask_b32_e64 v127, 0, v11, s[12:13]                    ; d100007f 00321680
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v127, v127, v127 quad_perm:[1,0,3,2] row_mask:0xf bank_mask:0xf ; 02fefefa ff00b17f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v127, v127, v127 quad_perm:[2,3,0,1] row_mask:0xf bank_mask:0xf ; 02fefefa ff004e7f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v127, v127, v127 row_half_mirror row_mask:0xf bank_mask:0xf ; 02fefefa ff01417f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v127, v127, v127 row_mirror row_mask:0xf bank_mask:0xf ; 02fefefa ff01407f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v127, v127, v127 row_bcast:15 row_mask:0xa bank_mask:0xf ; 02fefefa af01427f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v127, v127, v127 row_bcast:31 row_mask:0xc bank_mask:0xf ; 02fefefa cf01437f
	s_mov_b64 exec, 1                                           ; befe0181
	v_readlane_b32 s10, v127, 63                                ; d289000a 00017f7f
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
	s_mul_i32 s11, s7, s17                                      ; 920b1107
	s_add_u32 s11, s11, s16                                     ; 800b100b
	s_lshl_b32 s11, s11, 2                                      ; 8e0b820b
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_store_dword v0, off, s[12:15], s11                   ; e0700000 0b030080
	s_cmp_lg_i32 s18, 0                                         ; bf018012
	s_cbranch_scc0 BB20                                         ; bf84000b
BB19:
	s_load_dwordx4 s[20:23], s[2:3], 0x30                       ; c00a0501 00000030
	s_mov_b32 s18, src_scc                                      ; be9200fd
	s_add_u32 s19, s11, 4                                       ; 8013840b
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s19, s[20:23], s19                      ; c02004ca 00000013
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_mov_b32_e32 v0, s19                                       ; 7e000213
	v_add_f32_e32 v0, s1, v0                                    ; 02000001
	s_branch BB21                                               ; bf820002
BB20:
	s_mov_b32 s18, src_scc                                      ; be9200fd
	v_mov_b32_e32 v0, s1                                        ; 7e000201
BB21:
	s_cmp_lg_i32 s8, 0                                          ; bf018008
	s_cbranch_scc0 BB23                                         ; bf84000a
BB22:
	s_load_dwordx4 s[20:23], s[2:3], 0x40                       ; c00a0501 00000040
	s_mov_b32 s1, src_scc                                       ; be8100fd
	s_add_u32 s8, s11, 4                                        ; 8008840b
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s8, s[20:23], s8                        ; c020020a 00000008
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v0, s8, v0                                    ; 02000008
	s_branch BB24                                               ; bf820001
BB23:
	s_mov_b32 s1, src_scc                                       ; be8100fd
BB24:
	s_add_u32 s8, s11, 4                                        ; 8008840b
	buffer_store_dword v0, off, s[12:15], s8                    ; e0700000 08030080
	s_cmp_lg_i32 s18, 0                                         ; bf018012
	s_cbranch_scc0 BB26                                         ; bf84000b
BB25:
	s_load_dwordx4 s[20:23], s[2:3], 0x30                       ; c00a0501 00000030
	s_mov_b32 s8, src_scc                                       ; be8800fd
	s_add_u32 s18, s11, 8                                       ; 8012880b
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s18, s[20:23], s18                      ; c020048a 00000012
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_mov_b32_e32 v0, s18                                       ; 7e000212
	v_add_f32_e32 v0, s0, v0                                    ; 02000000
	s_branch BB27                                               ; bf820002
BB26:
	s_mov_b32 s8, src_scc                                       ; be8800fd
	v_mov_b32_e32 v0, s0                                        ; 7e000200
BB27:
	s_cmp_lg_i32 s1, 0                                          ; bf018001
	s_cbranch_scc0 BB29                                         ; bf84000a
BB28:
	s_load_dwordx4 s[20:23], s[2:3], 0x40                       ; c00a0501 00000040
	s_mov_b32 s0, src_scc                                       ; be8000fd
	s_add_u32 s1, s11, 8                                        ; 8001880b
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s1, s[20:23], s1                        ; c020004a 00000001
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v0, s1, v0                                    ; 02000001
	s_branch BB30                                               ; bf820001
BB29:
	s_mov_b32 s0, src_scc                                       ; be8000fd
BB30:
	s_add_u32 s1, s11, 8                                        ; 8001880b
	buffer_store_dword v0, off, s[12:15], s1                    ; e0700000 01030080
	s_cmp_lg_i32 s8, 0                                          ; bf018008
	s_cbranch_scc0 BB32                                         ; bf84000b
BB31:
	s_load_dwordx4 s[20:23], s[2:3], 0x30                       ; c00a0501 00000030
	s_mov_b32 s1, src_scc                                       ; be8100fd
	s_add_u32 s8, s11, 12                                       ; 80088c0b
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s8, s[20:23], s8                        ; c020020a 00000008
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
	s_load_dwordx4 s[20:23], s[2:3], 0x40                       ; c00a0501 00000040
	s_mov_b32 s0, src_scc                                       ; be8000fd
	s_add_u32 s4, s11, 12                                       ; 80048c0b
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s4, s[20:23], s4                        ; c020010a 00000004
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v0, s4, v0                                    ; 02000004
	s_branch BB36                                               ; bf820001
BB35:
	s_mov_b32 s0, src_scc                                       ; be8000fd
BB36:
	s_add_u32 s11, s11, 12                                      ; 800b8c0b
	buffer_store_dword v0, off, s[12:15], s11                   ; e0700000 0b030080
	s_cmp_lg_i32 s1, 0                                          ; bf018001
	s_cbranch_scc0 BB38                                         ; bf84000e
BB37:
	s_load_dwordx4 s[20:23], s[2:3], 0x30                       ; c00a0501 00000030
	s_mov_b32 s1, src_scc                                       ; be8100fd
	s_add_u32 s4, 1, s17                                        ; 80041181
	s_mul_i32 s4, s7, s4                                        ; 92040407
	s_add_u32 s4, s4, s16                                       ; 80041004
	s_lshl_b32 s4, s4, 2                                        ; 8e048204
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s4, s[20:23], s4                        ; c020010a 00000004
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_mov_b32_e32 v0, s4                                        ; 7e000204
	v_add_f32_e32 v0, s5, v0                                    ; 02000005
	s_branch BB39                                               ; bf820002
BB38:
	s_mov_b32 s1, src_scc                                       ; be8100fd
	v_mov_b32_e32 v0, s5                                        ; 7e000205
BB39:
	s_cmp_lg_i32 s0, 0                                          ; bf018000
	s_cbranch_scc0 BB41                                         ; bf84000d
BB40:
	s_load_dwordx4 s[20:23], s[2:3], 0x40                       ; c00a0501 00000040
	s_mov_b32 s0, src_scc                                       ; be8000fd
	s_add_u32 s4, 1, s17                                        ; 80041181
	s_mul_i32 s4, s7, s4                                        ; 92040407
	s_add_u32 s4, s4, s16                                       ; 80041004
	s_lshl_b32 s4, s4, 2                                        ; 8e048204
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s4, s[20:23], s4                        ; c020010a 00000004
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v0, s4, v0                                    ; 02000004
	s_branch BB42                                               ; bf820001
BB41:
	s_mov_b32 s0, src_scc                                       ; be8000fd
BB42:
	s_add_u32 s17, 1, s17                                       ; 80111181
	s_mul_i32 s7, s7, s17                                       ; 92071107
	s_add_u32 s7, s7, s16                                       ; 80071007
	s_lshl_b32 s7, s7, 2                                        ; 8e078207
	buffer_store_dword v0, off, s[12:15], s7                    ; e0700000 07030080
	s_cmp_lg_i32 s1, 0                                          ; bf018001
	s_cbranch_scc0 BB44                                         ; bf84000b
BB43:
	s_load_dwordx4 s[16:19], s[2:3], 0x30                       ; c00a0401 00000030
	s_mov_b32 s1, src_scc                                       ; be8100fd
	s_add_u32 s4, s7, 4                                         ; 80048407
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
	s_add_u32 s4, s7, 4                                         ; 80048407
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s4, s[16:19], s4                        ; c0200108 00000004
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v0, s4, v0                                    ; 02000004
	s_branch BB48                                               ; bf820001
BB47:
	s_mov_b32 s0, src_scc                                       ; be8000fd
BB48:
	s_add_u32 s4, s7, 4                                         ; 80048407
	buffer_store_dword v0, off, s[12:15], s4                    ; e0700000 04030080
	s_cmp_lg_i32 s1, 0                                          ; bf018001
	s_cbranch_scc0 BB50                                         ; bf84000b
BB49:
	s_load_dwordx4 s[16:19], s[2:3], 0x30                       ; c00a0401 00000030
	s_mov_b32 s1, src_scc                                       ; be8100fd
	s_add_u32 s4, s7, 8                                         ; 80048807
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
	s_add_u32 s4, s7, 8                                         ; 80048807
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s4, s[16:19], s4                        ; c0200108 00000004
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v0, s4, v0                                    ; 02000004
	s_branch BB54                                               ; bf820001
BB53:
	s_mov_b32 s0, src_scc                                       ; be8000fd
BB54:
	s_add_u32 s4, s7, 8                                         ; 80048807
	buffer_store_dword v0, off, s[12:15], s4                    ; e0700000 04030080
	s_cmp_lg_i32 s1, 0                                          ; bf018001
	s_cbranch_scc0 BB56                                         ; bf84000a
BB55:
	s_load_dwordx4 s[16:19], s[2:3], 0x30                       ; c00a0401 00000030
	s_add_u32 s1, s7, 12                                        ; 80018c07
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
	s_add_u32 s4, s7, 12                                        ; 80048c07
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s4, s[0:3], s4                          ; c0200100 00000004
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v0, s4, v0                                    ; 02000004
BB60:
	s_add_u32 s7, s7, 12                                        ; 80078c07
	buffer_store_dword v0, off, s[12:15], s7                    ; e0700000 07030080
	s_branch BB185                                              ; bf8204bd
BB66:
	s_cmp_lt_u32 s16, s4                                        ; bf0a0410
	s_cbranch_scc0 BB185                                        ; bf8404bb
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
	s_cbranch_scc0 BB89                                         ; bf84026d
BB76:
	s_mov_b64 exec, s[0:1]                                      ; befe0100
	s_mov_b32 s0, s2                                            ; be800002
	s_movk_i32 s1, 0x8000                                       ; b0018000
	s_load_dwordx4 s[12:15], s[0:1], 0x10                       ; c00a0300 00000010
	s_mul_i32 s5, s6, s17                                       ; 92051106
	v_lshl_add_u32 v12, v0, 8, v1                               ; d1fd000c 04051100
	v_add_u32_e32 v13, s5, v12                                  ; 681a1805
	s_add_u32 s9, 1, s17                                        ; 80091181
	v_add_u32_e32 v14, 0x80, v12                                ; 681c18ff 00000080
	v_lshrrev_b32_e32 v13, 2, v13                               ; 201a1a82
	s_mul_i32 s9, s6, s9                                        ; 92090906
	v_add_u32_e32 v15, s5, v14                                  ; 681e1c05
	v_lshlrev_b32_e32 v13, 4, v13                               ; 241a1a84
	v_add_u32_e32 v12, s9, v12                                  ; 68181809
	v_add_u32_e32 v14, s9, v14                                  ; 681c1c09
	v_lshrrev_b32_e32 v15, 2, v15                               ; 201e1e82
	v_lshrrev_b32_e32 v12, 2, v12                               ; 20181882
	v_lshrrev_b32_e32 v14, 2, v14                               ; 201c1c82
	v_lshlrev_b32_e32 v15, 4, v15                               ; 241e1e84
	v_lshlrev_b32_e32 v12, 4, v12                               ; 24181884
	v_lshlrev_b32_e32 v14, 4, v14                               ; 241c1c84
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_load_dwordx4 v[16:19], v13, s[12:15], 0 offen        ; e05c1000 8003100d
	buffer_load_dwordx4 v[20:23], v13, s[12:15], 0 offen offset:128 ; e05c1080 8003140d
	buffer_load_dwordx4 v[24:27], v15, s[12:15], 0 offen        ; e05c1000 8003180f
	buffer_load_dwordx4 v[28:31], v15, s[12:15], 0 offen offset:128 ; e05c1080 80031c0f
	buffer_load_dwordx4 v[32:35], v12, s[12:15], 0 offen        ; e05c1000 8003200c
	buffer_load_dwordx4 v[36:39], v12, s[12:15], 0 offen offset:128 ; e05c1080 8003240c
	buffer_load_dwordx4 v[40:43], v14, s[12:15], 0 offen        ; e05c1000 8003280e
	buffer_load_dwordx4 v[12:15], v14, s[12:15], 0 offen offset:128 ; e05c1080 80030c0e
	s_cmp_lg_i32 s4, 0                                          ; bf018004
	s_waitcnt vmcnt(7)                                          ; bf8c3f77
	v_add_f32_e32 v44, v16, v17                                 ; 02582310
	s_waitcnt vmcnt(6)                                          ; bf8c3f76
	v_add_f32_e32 v45, v20, v21                                 ; 025a2b14
	s_waitcnt vmcnt(5)                                          ; bf8c3f75
	v_add_f32_e32 v46, v24, v25                                 ; 025c3318
	v_add_f32_e32 v44, v44, v18                                 ; 0258252c
	v_add_f32_e32 v45, v45, v22                                 ; 025a2d2d
	s_waitcnt vmcnt(4)                                          ; bf8c3f74
	v_add_f32_e32 v47, v28, v29                                 ; 025e3b1c
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_add_f32_e32 v48, v32, v33                                 ; 02604320
	v_add_f32_e32 v46, v46, v26                                 ; 025c352e
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_add_f32_e32 v49, v36, v37                                 ; 02624b24
	v_add_f32_e32 v44, v44, v19                                 ; 0258272c
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_add_f32_e32 v50, v40, v41                                 ; 02645328
	v_add_f32_e32 v45, v45, v23                                 ; 025a2f2d
	v_add_f32_e32 v47, v47, v30                                 ; 025e3d2f
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_add_f32_e32 v51, v12, v13                                 ; 02661b0c
	v_add_f32_e32 v48, v48, v34                                 ; 02604530
	v_add_f32_e32 v46, v46, v27                                 ; 025c372e
	v_add_f32_e32 v49, v49, v38                                 ; 02624d31
	v_add_f32_e32 v50, v50, v42                                 ; 02645532
	v_add_f32_e32 v47, v47, v31                                 ; 025e3f2f
	v_add_f32_e32 v51, v51, v14                                 ; 02661d33
	v_add_f32_e32 v48, v48, v35                                 ; 02604730
	v_add_f32_e32 v49, v49, v39                                 ; 02624f31
	v_add_f32_e32 v50, v50, v43                                 ; 02645732
	v_add_f32_e32 v51, v51, v15                                 ; 02661f33
	s_cbranch_scc0 BB88                                         ; bf840220
BB77:
	s_load_dwordx4 s[12:15], s[0:1], 0x0                        ; c00a0300 00000000
	s_mul_i32 s0, s16, s3                                       ; 92000310
	v_lshlrev_b32_e32 v55, 1, v2                                ; 246e0481
	s_add_u32 s0, s19, s0                                       ; 80000013
	v_add_u32_e32 v63, 64, v4                                   ; 687e08c0
	v_and_b32_e32 v57, -4, v55                                  ; 26726ec4
	v_add_u32_e32 v61, 8, v55                                   ; 687a6e88
	v_add_u32_e32 v52, s0, v0                                   ; 68680000
	v_lshlrev_b32_e32 v53, 4, v52                               ; 246a6884
	v_lshl_add_u32 v52, v52, 7, v53                             ; d1fd0034 04d50f34
	v_add_u32_e32 v56, 4, v52                                   ; 68706884
	v_add_u32_e32 v58, v57, v56                                 ; 68747139
	v_add_u32_e32 v60, v56, v55                                 ; 68786f38
	v_add_u32_e32 v56, v56, v61                                 ; 68707b38
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_load_dword v54, v52, s[12:15], 0 offen               ; e0501000 80033634
	buffer_load_dwordx2 v[58:59], v58, s[12:15], 0 offen        ; e0541000 80033a3a
	buffer_load_ushort v56, v56, s[12:15], 0 offen              ; e0481000 80033838
	v_add_u32_e32 v52, 16, v52                                  ; 68686890
	v_add_u32_e32 v62, v52, v4                                  ; 687c0934
	v_add_u32_e32 v52, v52, v63                                 ; 68687f34
	buffer_load_dword v62, v62, s[12:15], 0 offen               ; e0501000 80033e3e
	buffer_load_dword v52, v52, s[12:15], 0 offen               ; e0501000 80033434
	s_mov_b32 s1, 0xf0f0f0f                                     ; be8100ff 0f0f0f0f
	s_cmp_lt_u32 1, s4                                          ; bf0a0481
	s_waitcnt vmcnt(4)                                          ; bf8c3f74
	v_cvt_f32_f16_sdwa v64, v54 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e8016f9 00050636
	v_cvt_f32_f16_e32 v54, v54                                  ; 7e6c1736
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_alignbyte_b32 v58, v59, v58, v60                          ; d1cf003a 04f2753b
	v_alignbyte_b32 v59, v59, v59, v60                          ; d1cf003b 04f2773b
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_lshl_or_b32 v56, v56, 12, v56                             ; d2000038 04e11938
	v_mov_b32_sdwa v58, v59 dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_0 ; 7e7402f9 0004153b
	v_and_b32_e32 v65, 0xc0c0c0c0, v58                          ; 268274ff c0c0c0c0
	v_and_b32_e32 v58, 0x3f3f3f3f, v58                          ; 267474ff 3f3f3f3f
	v_lshrrev_b32_e32 v65, 2, v65                               ; 20828282
	v_cvt_f32_ubyte1_e32 v68, v58                               ; 7e88253a
	v_cvt_f32_ubyte3_e32 v66, v58                               ; 7e84293a
	v_cvt_f32_ubyte2_e32 v67, v58                               ; 7e86273a
	v_cvt_f32_ubyte0_e32 v58, v58                               ; 7e74233a
	v_and_or_b32 v56, s1, v56, v65                              ; d2010038 05067001
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v73, s1, v62                                  ; 26927c01
	v_cvt_f32_ubyte1_e32 v72, v56                               ; 7e902538
	v_cvt_f32_ubyte2_e32 v71, v56                               ; 7e8e2738
	v_cvt_f32_ubyte3_e32 v69, v56                               ; 7e8a2938
	v_cvt_f32_ubyte0_e32 v56, v56                               ; 7e702338
	v_cvt_f32_ubyte2_e32 v76, v73                               ; 7e982749
	v_cvt_f32_ubyte3_e32 v74, v73                               ; 7e942949
	v_cvt_f32_ubyte1_e32 v77, v73                               ; 7e9a2549
	v_mul_f32_e32 v70, v47, v69                                 ; 0a8c8b2f
	v_mul_f32_e32 v69, v51, v69                                 ; 0a8a8b33
	v_cvt_f32_ubyte0_e32 v73, v73                               ; 7e922349
	v_mul_f32_e32 v75, v19, v74                                 ; 0a969513
	v_lshrrev_b32_e32 v62, 4, v62                               ; 207c7c84
	v_mac_f32_e32 v70, v46, v71                                 ; 2c8c8f2e
	v_mac_f32_e32 v69, v50, v71                                 ; 2c8a8f32
	v_mac_f32_e32 v75, v18, v76                                 ; 2c969912
	v_and_b32_e32 v62, s1, v62                                  ; 267c7c01
	v_mac_f32_e32 v70, v45, v66                                 ; 2c8c852d
	v_mac_f32_e32 v69, v49, v66                                 ; 2c8a8531
	v_mac_f32_e32 v75, v17, v77                                 ; 2c969b11
	v_cvt_f32_ubyte1_e32 v81, v62                               ; 7ea2253e
	v_cvt_f32_ubyte2_e32 v80, v62                               ; 7ea0273e
	v_mul_f32_e32 v74, v35, v74                                 ; 0a949523
	v_cvt_f32_ubyte3_e32 v78, v62                               ; 7e9c293e
	v_cvt_f32_ubyte0_e32 v62, v62                               ; 7e7c233e
	v_mac_f32_e32 v70, v44, v67                                 ; 2c8c872c
	v_mac_f32_e32 v69, v48, v67                                 ; 2c8a8730
	v_mac_f32_e32 v75, v16, v73                                 ; 2c969310
	v_mac_f32_e32 v74, v34, v76                                 ; 2c949922
	v_mul_f32_e32 v79, v23, v78                                 ; 0a9e9d17
	v_mul_f32_e32 v78, v39, v78                                 ; 0a9c9d27
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v82, s1, v52                                  ; 26a46801
	v_mad_f32 v3, -v64, v70, v3                                 ; d1c10003 240e8d40
	v_mad_f32 v8, -v64, v69, v8                                 ; d1c10008 24228b40
	v_mac_f32_e32 v74, v33, v77                                 ; 2c949b21
	v_mac_f32_e32 v79, v22, v80                                 ; 2c9ea116
	v_mac_f32_e32 v78, v38, v80                                 ; 2c9ca126
	v_cvt_f32_ubyte2_e32 v85, v82                               ; 7eaa2752
	v_cvt_f32_ubyte3_e32 v83, v82                               ; 7ea62952
	v_cvt_f32_ubyte1_e32 v86, v82                               ; 7eac2552
	v_cvt_f32_ubyte0_e32 v82, v82                               ; 7ea42352
	v_lshrrev_b32_e32 v52, 4, v52                               ; 20686884
	v_mac_f32_e32 v74, v32, v73                                 ; 2c949320
	v_mac_f32_e32 v79, v21, v81                                 ; 2c9ea315
	v_mac_f32_e32 v78, v37, v81                                 ; 2c9ca325
	v_mul_f32_e32 v84, v27, v83                                 ; 0aa8a71b
	v_and_b32_e32 v52, s1, v52                                  ; 26686801
	v_mac_f32_e32 v79, v20, v62                                 ; 2c9e7d14
	v_mac_f32_e32 v78, v36, v62                                 ; 2c9c7d24
	v_mac_f32_e32 v84, v26, v85                                 ; 2ca8ab1a
	v_cvt_f32_ubyte2_e32 v89, v52                               ; 7eb22734
	v_cvt_f32_ubyte3_e32 v87, v52                               ; 7eae2934
	v_cvt_f32_ubyte1_e32 v90, v52                               ; 7eb42534
	v_cvt_f32_ubyte0_e32 v52, v52                               ; 7e682334
	v_mul_f32_e32 v83, v43, v83                                 ; 0aa6a72b
	v_mac_f32_e32 v84, v25, v86                                 ; 2ca8ad19
	v_mul_f32_e32 v88, v31, v87                                 ; 0ab0af1f
	v_mul_f32_e32 v87, v15, v87                                 ; 0aaeaf0f
	v_mac_f32_e32 v83, v42, v85                                 ; 2ca6ab2a
	v_mac_f32_e32 v84, v24, v82                                 ; 2ca8a518
	v_mac_f32_e32 v88, v30, v89                                 ; 2cb0b31e
	v_mac_f32_e32 v87, v14, v89                                 ; 2caeb30e
	v_mac_f32_e32 v83, v41, v86                                 ; 2ca6ad29
	v_mac_f32_e32 v88, v29, v90                                 ; 2cb0b51d
	v_mac_f32_e32 v87, v13, v90                                 ; 2caeb50d
	v_mac_f32_e32 v83, v40, v82                                 ; 2ca6a528
	v_mac_f32_e32 v88, v28, v52                                 ; 2cb0691c
	v_mac_f32_e32 v87, v12, v52                                 ; 2cae690c
	v_mul_f32_e32 v88, v88, v72                                 ; 0ab09158
	v_mul_f32_e32 v87, v87, v72                                 ; 0aae9157
	v_mac_f32_e32 v88, v84, v56                                 ; 2cb07154
	v_mac_f32_e32 v87, v83, v56                                 ; 2cae7153
	v_mac_f32_e32 v88, v79, v68                                 ; 2cb0894f
	v_mac_f32_e32 v87, v78, v68                                 ; 2cae894e
	v_mac_f32_e32 v88, v75, v58                                 ; 2cb0754b
	v_mac_f32_e32 v87, v74, v58                                 ; 2cae754a
	v_mac_f32_e32 v3, v54, v88                                  ; 2c06b136
	v_mac_f32_e32 v8, v54, v87                                  ; 2c10af36
	s_cbranch_scc0 BB88                                         ; bf840193
BB78:
	s_add_u32 s0, s16, 1                                        ; 80008110
	s_mul_i32 s0, s0, s3                                        ; 92000300
	s_add_u32 s0, s19, s0                                       ; 80000013
	v_add_u32_e32 v52, s0, v0                                   ; 68680000
	v_lshlrev_b32_e32 v53, 4, v52                               ; 246a6884
	v_lshl_add_u32 v52, v52, 7, v53                             ; d1fd0034 04d50f34
	v_add_u32_e32 v54, 4, v52                                   ; 686c6884
	v_add_u32_e32 v59, 16, v52                                  ; 68766890
	v_add_u32_e32 v56, v57, v54                                 ; 68706d39
	v_add_u32_e32 v58, v54, v55                                 ; 68746f36
	v_add_u32_e32 v54, v54, v61                                 ; 686c7b36
	v_add_u32_e32 v60, v59, v4                                  ; 6878093b
	v_add_u32_e32 v59, v59, v63                                 ; 68767f3b
	buffer_load_dword v52, v52, s[12:15], 0 offen               ; e0501000 80033434
	buffer_load_dwordx2 v[64:65], v56, s[12:15], 0 offen        ; e0541000 80034038
	buffer_load_ushort v54, v54, s[12:15], 0 offen              ; e0481000 80033636
	buffer_load_dword v60, v60, s[12:15], 0 offen               ; e0501000 80033c3c
	buffer_load_dword v59, v59, s[12:15], 0 offen               ; e0501000 80033b3b
	s_mov_b32 s1, 0xf0f0f0f                                     ; be8100ff 0f0f0f0f
	s_cmp_lt_u32 2, s4                                          ; bf0a0482
	s_waitcnt vmcnt(4)                                          ; bf8c3f74
	v_cvt_f32_f16_sdwa v62, v52 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e7c16f9 00050634
	v_cvt_f32_f16_e32 v52, v52                                  ; 7e681734
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_alignbyte_b32 v64, v65, v64, v58                          ; d1cf0040 04ea8141
	v_alignbyte_b32 v65, v65, v65, v58                          ; d1cf0041 04ea8341
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_lshl_or_b32 v54, v54, 12, v54                             ; d2000036 04d91936
	v_mov_b32_sdwa v64, v65 dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_0 ; 7e8002f9 00041541
	v_and_b32_e32 v65, 0xc0c0c0c0, v64                          ; 268280ff c0c0c0c0
	v_and_b32_e32 v64, 0x3f3f3f3f, v64                          ; 268080ff 3f3f3f3f
	v_lshrrev_b32_e32 v65, 2, v65                               ; 20828282
	v_cvt_f32_ubyte3_e32 v66, v64                               ; 7e842940
	v_cvt_f32_ubyte2_e32 v67, v64                               ; 7e862740
	v_cvt_f32_ubyte1_e32 v68, v64                               ; 7e882540
	v_cvt_f32_ubyte0_e32 v64, v64                               ; 7e802340
	v_and_or_b32 v54, s1, v54, v65                              ; d2010036 05066c01
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v73, s1, v60                                  ; 26927801
	v_cvt_f32_ubyte1_e32 v72, v54                               ; 7e902536
	v_cvt_f32_ubyte3_e32 v69, v54                               ; 7e8a2936
	v_cvt_f32_ubyte2_e32 v71, v54                               ; 7e8e2736
	v_cvt_f32_ubyte0_e32 v54, v54                               ; 7e6c2336
	v_cvt_f32_ubyte2_e32 v76, v73                               ; 7e982749
	v_cvt_f32_ubyte3_e32 v74, v73                               ; 7e942949
	v_mul_f32_e32 v70, v47, v69                                 ; 0a8c8b2f
	v_cvt_f32_ubyte1_e32 v77, v73                               ; 7e9a2549
	v_mul_f32_e32 v69, v51, v69                                 ; 0a8a8b33
	v_cvt_f32_ubyte0_e32 v73, v73                               ; 7e922349
	v_lshrrev_b32_e32 v60, 4, v60                               ; 20787884
	v_mul_f32_e32 v75, v19, v74                                 ; 0a969513
	v_mac_f32_e32 v70, v46, v71                                 ; 2c8c8f2e
	v_mac_f32_e32 v69, v50, v71                                 ; 2c8a8f32
	v_and_b32_e32 v60, s1, v60                                  ; 26787801
	v_mac_f32_e32 v75, v18, v76                                 ; 2c969912
	v_mac_f32_e32 v70, v45, v66                                 ; 2c8c852d
	v_mac_f32_e32 v69, v49, v66                                 ; 2c8a8531
	v_cvt_f32_ubyte2_e32 v80, v60                               ; 7ea0273c
	v_cvt_f32_ubyte1_e32 v81, v60                               ; 7ea2253c
	v_cvt_f32_ubyte3_e32 v78, v60                               ; 7e9c293c
	v_cvt_f32_ubyte0_e32 v60, v60                               ; 7e78233c
	v_mul_f32_e32 v74, v35, v74                                 ; 0a949523
	v_mac_f32_e32 v75, v17, v77                                 ; 2c969b11
	v_mac_f32_e32 v70, v44, v67                                 ; 2c8c872c
	v_mac_f32_e32 v69, v48, v67                                 ; 2c8a8730
	v_mul_f32_e32 v79, v23, v78                                 ; 0a9e9d17
	v_mul_f32_e32 v78, v39, v78                                 ; 0a9c9d27
	v_mac_f32_e32 v74, v34, v76                                 ; 2c949922
	v_mac_f32_e32 v75, v16, v73                                 ; 2c969310
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v82, s1, v59                                  ; 26a47601
	v_mad_f32 v5, -v62, v70, v5                                 ; d1c10005 24168d3e
	v_mad_f32 v9, -v62, v69, v9                                 ; d1c10009 24268b3e
	v_mac_f32_e32 v79, v22, v80                                 ; 2c9ea116
	v_mac_f32_e32 v78, v38, v80                                 ; 2c9ca126
	v_mac_f32_e32 v74, v33, v77                                 ; 2c949b21
	v_cvt_f32_ubyte1_e32 v86, v82                               ; 7eac2552
	v_cvt_f32_ubyte2_e32 v85, v82                               ; 7eaa2752
	v_cvt_f32_ubyte3_e32 v83, v82                               ; 7ea62952
	v_cvt_f32_ubyte0_e32 v82, v82                               ; 7ea42352
	v_lshrrev_b32_e32 v59, 4, v59                               ; 20767684
	v_mac_f32_e32 v79, v21, v81                                 ; 2c9ea315
	v_mac_f32_e32 v78, v37, v81                                 ; 2c9ca325
	v_mac_f32_e32 v74, v32, v73                                 ; 2c949320
	v_mul_f32_e32 v84, v27, v83                                 ; 0aa8a71b
	v_and_b32_e32 v59, s1, v59                                  ; 26767601
	v_mac_f32_e32 v79, v20, v60                                 ; 2c9e7914
	v_mac_f32_e32 v78, v36, v60                                 ; 2c9c7924
	v_mac_f32_e32 v84, v26, v85                                 ; 2ca8ab1a
	v_cvt_f32_ubyte3_e32 v87, v59                               ; 7eae293b
	v_cvt_f32_ubyte1_e32 v90, v59                               ; 7eb4253b
	v_cvt_f32_ubyte2_e32 v89, v59                               ; 7eb2273b
	v_cvt_f32_ubyte0_e32 v59, v59                               ; 7e76233b
	v_mul_f32_e32 v83, v43, v83                                 ; 0aa6a72b
	v_mac_f32_e32 v84, v25, v86                                 ; 2ca8ad19
	v_mul_f32_e32 v88, v31, v87                                 ; 0ab0af1f
	v_mul_f32_e32 v87, v15, v87                                 ; 0aaeaf0f
	v_mac_f32_e32 v83, v42, v85                                 ; 2ca6ab2a
	v_mac_f32_e32 v84, v24, v82                                 ; 2ca8a518
	v_mac_f32_e32 v88, v30, v89                                 ; 2cb0b31e
	v_mac_f32_e32 v87, v14, v89                                 ; 2caeb30e
	v_mac_f32_e32 v83, v41, v86                                 ; 2ca6ad29
	v_mac_f32_e32 v88, v29, v90                                 ; 2cb0b51d
	v_mac_f32_e32 v87, v13, v90                                 ; 2caeb50d
	v_mac_f32_e32 v83, v40, v82                                 ; 2ca6a528
	v_mac_f32_e32 v88, v28, v59                                 ; 2cb0771c
	v_mac_f32_e32 v87, v12, v59                                 ; 2cae770c
	v_mul_f32_e32 v88, v88, v72                                 ; 0ab09158
	v_mul_f32_e32 v87, v87, v72                                 ; 0aae9157
	v_mac_f32_e32 v88, v84, v54                                 ; 2cb06d54
	v_mac_f32_e32 v87, v83, v54                                 ; 2cae6d53
	v_mac_f32_e32 v88, v79, v68                                 ; 2cb0894f
	v_mac_f32_e32 v87, v78, v68                                 ; 2cae894e
	v_mac_f32_e32 v88, v75, v64                                 ; 2cb0814b
	v_mac_f32_e32 v87, v74, v64                                 ; 2cae814a
	v_mac_f32_e32 v5, v52, v88                                  ; 2c0ab134
	v_mac_f32_e32 v9, v52, v87                                  ; 2c12af34
	s_cbranch_scc0 BB88                                         ; bf84010c
BB79:
	s_add_u32 s0, s16, 2                                        ; 80008210
	s_mul_i32 s0, s0, s3                                        ; 92000300
	s_add_u32 s0, s19, s0                                       ; 80000013
	v_add_u32_e32 v52, s0, v0                                   ; 68680000
	v_lshlrev_b32_e32 v53, 4, v52                               ; 246a6884
	v_lshl_add_u32 v52, v52, 7, v53                             ; d1fd0034 04d50f34
	v_add_u32_e32 v54, 4, v52                                   ; 686c6884
	v_add_u32_e32 v59, 16, v52                                  ; 68766890
	v_add_u32_e32 v56, v57, v54                                 ; 68706d39
	v_add_u32_e32 v58, v54, v55                                 ; 68746f36
	v_add_u32_e32 v54, v54, v61                                 ; 686c7b36
	v_add_u32_e32 v60, v59, v4                                  ; 6878093b
	v_add_u32_e32 v59, v59, v63                                 ; 68767f3b
	buffer_load_dword v52, v52, s[12:15], 0 offen               ; e0501000 80033434
	buffer_load_dwordx2 v[64:65], v56, s[12:15], 0 offen        ; e0541000 80034038
	buffer_load_ushort v54, v54, s[12:15], 0 offen              ; e0481000 80033636
	buffer_load_dword v60, v60, s[12:15], 0 offen               ; e0501000 80033c3c
	buffer_load_dword v59, v59, s[12:15], 0 offen               ; e0501000 80033b3b
	s_mov_b32 s1, 0xf0f0f0f                                     ; be8100ff 0f0f0f0f
	s_cmp_lt_u32 3, s4                                          ; bf0a0483
	s_waitcnt vmcnt(4)                                          ; bf8c3f74
	v_cvt_f32_f16_sdwa v62, v52 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e7c16f9 00050634
	v_cvt_f32_f16_e32 v52, v52                                  ; 7e681734
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_alignbyte_b32 v64, v65, v64, v58                          ; d1cf0040 04ea8141
	v_alignbyte_b32 v65, v65, v65, v58                          ; d1cf0041 04ea8341
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_lshl_or_b32 v54, v54, 12, v54                             ; d2000036 04d91936
	v_mov_b32_sdwa v64, v65 dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_0 ; 7e8002f9 00041541
	v_and_b32_e32 v65, 0xc0c0c0c0, v64                          ; 268280ff c0c0c0c0
	v_and_b32_e32 v64, 0x3f3f3f3f, v64                          ; 268080ff 3f3f3f3f
	v_lshrrev_b32_e32 v65, 2, v65                               ; 20828282
	v_cvt_f32_ubyte3_e32 v66, v64                               ; 7e842940
	v_cvt_f32_ubyte2_e32 v67, v64                               ; 7e862740
	v_cvt_f32_ubyte1_e32 v68, v64                               ; 7e882540
	v_cvt_f32_ubyte0_e32 v64, v64                               ; 7e802340
	v_and_or_b32 v54, s1, v54, v65                              ; d2010036 05066c01
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v73, s1, v60                                  ; 26927801
	v_cvt_f32_ubyte1_e32 v72, v54                               ; 7e902536
	v_cvt_f32_ubyte3_e32 v69, v54                               ; 7e8a2936
	v_cvt_f32_ubyte2_e32 v71, v54                               ; 7e8e2736
	v_cvt_f32_ubyte0_e32 v54, v54                               ; 7e6c2336
	v_cvt_f32_ubyte2_e32 v76, v73                               ; 7e982749
	v_cvt_f32_ubyte3_e32 v74, v73                               ; 7e942949
	v_mul_f32_e32 v70, v47, v69                                 ; 0a8c8b2f
	v_cvt_f32_ubyte1_e32 v77, v73                               ; 7e9a2549
	v_mul_f32_e32 v69, v51, v69                                 ; 0a8a8b33
	v_cvt_f32_ubyte0_e32 v73, v73                               ; 7e922349
	v_lshrrev_b32_e32 v60, 4, v60                               ; 20787884
	v_mul_f32_e32 v75, v19, v74                                 ; 0a969513
	v_mac_f32_e32 v70, v46, v71                                 ; 2c8c8f2e
	v_mac_f32_e32 v69, v50, v71                                 ; 2c8a8f32
	v_and_b32_e32 v60, s1, v60                                  ; 26787801
	v_mac_f32_e32 v75, v18, v76                                 ; 2c969912
	v_mac_f32_e32 v70, v45, v66                                 ; 2c8c852d
	v_mac_f32_e32 v69, v49, v66                                 ; 2c8a8531
	v_cvt_f32_ubyte2_e32 v80, v60                               ; 7ea0273c
	v_cvt_f32_ubyte1_e32 v81, v60                               ; 7ea2253c
	v_cvt_f32_ubyte3_e32 v78, v60                               ; 7e9c293c
	v_cvt_f32_ubyte0_e32 v60, v60                               ; 7e78233c
	v_mul_f32_e32 v74, v35, v74                                 ; 0a949523
	v_mac_f32_e32 v75, v17, v77                                 ; 2c969b11
	v_mac_f32_e32 v70, v44, v67                                 ; 2c8c872c
	v_mac_f32_e32 v69, v48, v67                                 ; 2c8a8730
	v_mul_f32_e32 v79, v23, v78                                 ; 0a9e9d17
	v_mul_f32_e32 v78, v39, v78                                 ; 0a9c9d27
	v_mac_f32_e32 v74, v34, v76                                 ; 2c949922
	v_mac_f32_e32 v75, v16, v73                                 ; 2c969310
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v82, s1, v59                                  ; 26a47601
	v_mad_f32 v6, -v62, v70, v6                                 ; d1c10006 241a8d3e
	v_mad_f32 v10, -v62, v69, v10                               ; d1c1000a 242a8b3e
	v_mac_f32_e32 v79, v22, v80                                 ; 2c9ea116
	v_mac_f32_e32 v78, v38, v80                                 ; 2c9ca126
	v_mac_f32_e32 v74, v33, v77                                 ; 2c949b21
	v_cvt_f32_ubyte1_e32 v86, v82                               ; 7eac2552
	v_cvt_f32_ubyte2_e32 v85, v82                               ; 7eaa2752
	v_cvt_f32_ubyte3_e32 v83, v82                               ; 7ea62952
	v_cvt_f32_ubyte0_e32 v82, v82                               ; 7ea42352
	v_lshrrev_b32_e32 v59, 4, v59                               ; 20767684
	v_mac_f32_e32 v79, v21, v81                                 ; 2c9ea315
	v_mac_f32_e32 v78, v37, v81                                 ; 2c9ca325
	v_mac_f32_e32 v74, v32, v73                                 ; 2c949320
	v_mul_f32_e32 v84, v27, v83                                 ; 0aa8a71b
	v_and_b32_e32 v59, s1, v59                                  ; 26767601
	v_mac_f32_e32 v79, v20, v60                                 ; 2c9e7914
	v_mac_f32_e32 v78, v36, v60                                 ; 2c9c7924
	v_mac_f32_e32 v84, v26, v85                                 ; 2ca8ab1a
	v_cvt_f32_ubyte3_e32 v87, v59                               ; 7eae293b
	v_cvt_f32_ubyte1_e32 v90, v59                               ; 7eb4253b
	v_cvt_f32_ubyte2_e32 v89, v59                               ; 7eb2273b
	v_cvt_f32_ubyte0_e32 v59, v59                               ; 7e76233b
	v_mul_f32_e32 v83, v43, v83                                 ; 0aa6a72b
	v_mac_f32_e32 v84, v25, v86                                 ; 2ca8ad19
	v_mul_f32_e32 v88, v31, v87                                 ; 0ab0af1f
	v_mul_f32_e32 v87, v15, v87                                 ; 0aaeaf0f
	v_mac_f32_e32 v83, v42, v85                                 ; 2ca6ab2a
	v_mac_f32_e32 v84, v24, v82                                 ; 2ca8a518
	v_mac_f32_e32 v88, v30, v89                                 ; 2cb0b31e
	v_mac_f32_e32 v87, v14, v89                                 ; 2caeb30e
	v_mac_f32_e32 v83, v41, v86                                 ; 2ca6ad29
	v_mac_f32_e32 v88, v29, v90                                 ; 2cb0b51d
	v_mac_f32_e32 v87, v13, v90                                 ; 2caeb50d
	v_mac_f32_e32 v83, v40, v82                                 ; 2ca6a528
	v_mac_f32_e32 v88, v28, v59                                 ; 2cb0771c
	v_mac_f32_e32 v87, v12, v59                                 ; 2cae770c
	v_mul_f32_e32 v88, v88, v72                                 ; 0ab09158
	v_mul_f32_e32 v87, v87, v72                                 ; 0aae9157
	v_mac_f32_e32 v88, v84, v54                                 ; 2cb06d54
	v_mac_f32_e32 v87, v83, v54                                 ; 2cae6d53
	v_mac_f32_e32 v88, v79, v68                                 ; 2cb0894f
	v_mac_f32_e32 v87, v78, v68                                 ; 2cae894e
	v_mac_f32_e32 v88, v75, v64                                 ; 2cb0814b
	v_mac_f32_e32 v87, v74, v64                                 ; 2cae814a
	v_mac_f32_e32 v6, v52, v88                                  ; 2c0cb134
	v_mac_f32_e32 v10, v52, v87                                 ; 2c14af34
	s_cbranch_scc0 BB88                                         ; bf840085
BB80:
	s_add_u32 s0, s16, 3                                        ; 80008310
	s_mul_i32 s0, s0, s3                                        ; 92000300
	s_add_u32 s0, s19, s0                                       ; 80000013
	v_add_u32_e32 v52, s0, v0                                   ; 68680000
	v_lshlrev_b32_e32 v53, 4, v52                               ; 246a6884
	v_lshl_add_u32 v52, v52, 7, v53                             ; d1fd0034 04d50f34
	v_add_u32_e32 v54, 4, v52                                   ; 686c6884
	v_add_u32_e32 v56, 16, v52                                  ; 68706890
	v_add_u32_e32 v57, v57, v54                                 ; 68726d39
	v_add_u32_e32 v55, v54, v55                                 ; 686e6f36
	v_add_u32_e32 v54, v54, v61                                 ; 686c7b36
	v_add_u32_e32 v58, v56, v4                                  ; 68740938
	v_add_u32_e32 v56, v56, v63                                 ; 68707f38
	buffer_load_dword v52, v52, s[12:15], 0 offen               ; e0501000 80033434
	buffer_load_dwordx2 v[60:61], v57, s[12:15], 0 offen        ; e0541000 80033c39
	buffer_load_ushort v54, v54, s[12:15], 0 offen              ; e0481000 80033636
	buffer_load_dword v58, v58, s[12:15], 0 offen               ; e0501000 80033a3a
	buffer_load_dword v56, v56, s[12:15], 0 offen               ; e0501000 80033838
	s_mov_b32 s1, 0xf0f0f0f                                     ; be8100ff 0f0f0f0f
	s_waitcnt vmcnt(4)                                          ; bf8c3f74
	v_cvt_f32_f16_sdwa v59, v52 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:WORD_1 ; 7e7616f9 00050634
	v_cvt_f32_f16_e32 v52, v52                                  ; 7e681734
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_alignbyte_b32 v60, v61, v60, v55                          ; d1cf003c 04de793d
	v_alignbyte_b32 v61, v61, v61, v55                          ; d1cf003d 04de7b3d
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_lshl_or_b32 v54, v54, 12, v54                             ; d2000036 04d91936
	v_mov_b32_sdwa v60, v61 dst_sel:WORD_1 dst_unused:UNUSED_PRESERVE src0_sel:WORD_0 ; 7e7802f9 0004153d
	v_and_b32_e32 v61, 0xc0c0c0c0, v60                          ; 267a78ff c0c0c0c0
	v_and_b32_e32 v60, 0x3f3f3f3f, v60                          ; 267878ff 3f3f3f3f
	v_lshrrev_b32_e32 v61, 2, v61                               ; 207a7a82
	v_cvt_f32_ubyte3_e32 v62, v60                               ; 7e7c293c
	v_cvt_f32_ubyte2_e32 v63, v60                               ; 7e7e273c
	v_cvt_f32_ubyte1_e32 v64, v60                               ; 7e80253c
	v_cvt_f32_ubyte0_e32 v60, v60                               ; 7e78233c
	v_and_or_b32 v54, s1, v54, v61                              ; d2010036 04f66c01
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_and_b32_e32 v68, s1, v58                                  ; 26887401
	v_cvt_f32_ubyte3_e32 v65, v54                               ; 7e822936
	v_cvt_f32_ubyte2_e32 v66, v54                               ; 7e842736
	v_cvt_f32_ubyte1_e32 v67, v54                               ; 7e862536
	v_cvt_f32_ubyte0_e32 v54, v54                               ; 7e6c2336
	v_cvt_f32_ubyte3_e32 v69, v68                               ; 7e8a2944
	v_cvt_f32_ubyte2_e32 v70, v68                               ; 7e8c2744
	v_mul_f32_e32 v47, v47, v65                                 ; 0a5e832f
	v_mul_f32_e32 v51, v51, v65                                 ; 0a668333
	v_cvt_f32_ubyte1_e32 v71, v68                               ; 7e8e2544
	v_cvt_f32_ubyte0_e32 v68, v68                               ; 7e882344
	v_mul_f32_e32 v19, v19, v69                                 ; 0a268b13
	v_lshrrev_b32_e32 v58, 4, v58                               ; 20747484
	v_mac_f32_e32 v47, v46, v66                                 ; 2c5e852e
	v_mac_f32_e32 v51, v50, v66                                 ; 2c668532
	v_mac_f32_e32 v19, v18, v70                                 ; 2c268d12
	v_and_b32_e32 v58, s1, v58                                  ; 26747401
	v_mac_f32_e32 v47, v45, v62                                 ; 2c5e7d2d
	v_mac_f32_e32 v51, v49, v62                                 ; 2c667d31
	v_mac_f32_e32 v19, v17, v71                                 ; 2c268f11
	v_cvt_f32_ubyte1_e32 v74, v58                               ; 7e94253a
	v_mul_f32_e32 v35, v35, v69                                 ; 0a468b23
	v_cvt_f32_ubyte2_e32 v73, v58                               ; 7e92273a
	v_cvt_f32_ubyte3_e32 v72, v58                               ; 7e90293a
	v_cvt_f32_ubyte0_e32 v58, v58                               ; 7e74233a
	v_mac_f32_e32 v47, v44, v63                                 ; 2c5e7f2c
	v_mac_f32_e32 v51, v48, v63                                 ; 2c667f30
	v_mac_f32_e32 v19, v16, v68                                 ; 2c268910
	v_mac_f32_e32 v35, v34, v70                                 ; 2c468d22
	v_mul_f32_e32 v23, v23, v72                                 ; 0a2e9117
	v_mul_f32_e32 v39, v39, v72                                 ; 0a4e9127
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_and_b32_e32 v75, s1, v56                                  ; 26967001
	v_mad_f32 v7, -v59, v47, v7                                 ; d1c10007 241e5f3b
	v_mad_f32 v11, -v59, v51, v11                               ; d1c1000b 242e673b
	v_mac_f32_e32 v35, v33, v71                                 ; 2c468f21
	v_mac_f32_e32 v23, v22, v73                                 ; 2c2e9316
	v_mac_f32_e32 v39, v38, v73                                 ; 2c4e9326
	v_cvt_f32_ubyte1_e32 v78, v75                               ; 7e9c254b
	v_cvt_f32_ubyte2_e32 v77, v75                               ; 7e9a274b
	v_cvt_f32_ubyte3_e32 v76, v75                               ; 7e98294b
	v_cvt_f32_ubyte0_e32 v75, v75                               ; 7e96234b
	v_lshrrev_b32_e32 v56, 4, v56                               ; 20707084
	v_mac_f32_e32 v35, v32, v68                                 ; 2c468920
	v_mac_f32_e32 v23, v21, v74                                 ; 2c2e9515
	v_mac_f32_e32 v39, v37, v74                                 ; 2c4e9525
	v_mul_f32_e32 v27, v27, v76                                 ; 0a36991b
	v_and_b32_e32 v56, s1, v56                                  ; 26707001
	v_mac_f32_e32 v23, v20, v58                                 ; 2c2e7514
	v_mac_f32_e32 v39, v36, v58                                 ; 2c4e7524
	v_mac_f32_e32 v27, v26, v77                                 ; 2c369b1a
	v_cvt_f32_ubyte1_e32 v81, v56                               ; 7ea22538
	v_cvt_f32_ubyte2_e32 v80, v56                               ; 7ea02738
	v_cvt_f32_ubyte3_e32 v79, v56                               ; 7e9e2938
	v_cvt_f32_ubyte0_e32 v56, v56                               ; 7e702338
	v_mul_f32_e32 v43, v43, v76                                 ; 0a56992b
	v_mac_f32_e32 v27, v25, v78                                 ; 2c369d19
	v_mul_f32_e32 v15, v15, v79                                 ; 0a1e9f0f
	v_mul_f32_e32 v31, v31, v79                                 ; 0a3e9f1f
	v_mac_f32_e32 v43, v42, v77                                 ; 2c569b2a
	v_mac_f32_e32 v27, v24, v75                                 ; 2c369718
	v_mac_f32_e32 v15, v14, v80                                 ; 2c1ea10e
	v_mac_f32_e32 v31, v30, v80                                 ; 2c3ea11e
	v_mac_f32_e32 v43, v41, v78                                 ; 2c569d29
	v_mac_f32_e32 v15, v13, v81                                 ; 2c1ea30d
	v_mac_f32_e32 v31, v29, v81                                 ; 2c3ea31d
	v_mac_f32_e32 v43, v40, v75                                 ; 2c569728
	v_mac_f32_e32 v15, v12, v56                                 ; 2c1e710c
	v_mac_f32_e32 v31, v28, v56                                 ; 2c3e711c
	v_mul_f32_e32 v15, v15, v67                                 ; 0a1e870f
	v_mul_f32_e32 v31, v31, v67                                 ; 0a3e871f
	v_mac_f32_e32 v15, v43, v54                                 ; 2c1e6d2b
	v_mac_f32_e32 v31, v27, v54                                 ; 2c3e6d1b
	v_mac_f32_e32 v15, v39, v64                                 ; 2c1e8127
	v_mac_f32_e32 v31, v23, v64                                 ; 2c3e8117
	v_mac_f32_e32 v15, v35, v60                                 ; 2c1e7923
	v_mac_f32_e32 v31, v19, v60                                 ; 2c3e7913
	v_mac_f32_e32 v11, v52, v15                                 ; 2c161f34
	v_mac_f32_e32 v7, v52, v31                                  ; 2c0e3f34
BB88:
	v_add_u32_e32 v0, 4, v0                                     ; 68000084
	s_branch BB71                                               ; bf82fd8f
BB89:
	s_mov_b64 exec, -1                                          ; befe01c1
	s_cmp_lg_i32 s4, 0                                          ; bf018004
	s_cselect_b64 s[0:1], -1, 0                                 ; 858080c1
	s_cbranch_scc0 BB110                                        ; bf8400d7
BB90:
	s_or_saveexec_b64 s[10:11], -1                              ; be8a21c1
	s_cmp_lt_u32 1, s4                                          ; bf0a0481
	v_cndmask_b32_e64 v127, 0, v3, s[10:11]                     ; d100007f 002a0680
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v127, v127, v127 quad_perm:[1,0,3,2] row_mask:0xf bank_mask:0xf ; 02fefefa ff00b17f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v127, v127, v127 quad_perm:[2,3,0,1] row_mask:0xf bank_mask:0xf ; 02fefefa ff004e7f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v127, v127, v127 row_half_mirror row_mask:0xf bank_mask:0xf ; 02fefefa ff01417f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v127, v127, v127 row_mirror row_mask:0xf bank_mask:0xf ; 02fefefa ff01407f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v127, v127, v127 row_bcast:15 row_mask:0xa bank_mask:0xf ; 02fefefa af01427f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v127, v127, v127 row_bcast:31 row_mask:0xc bank_mask:0xf ; 02fefefa cf01437f
	s_mov_b64 exec, s[10:11]                                    ; befe010a
	v_readlane_b32 s3, v127, 63                                 ; d2890003 00017f7f
	s_cbranch_scc0 BB98                                         ; bf840051
BB91:
	s_mov_b32 s5, src_scc                                       ; be8500fd
	s_or_saveexec_b64 s[10:11], -1                              ; be8a21c1
	s_cmp_lt_u32 2, s4                                          ; bf0a0482
	v_cndmask_b32_e64 v127, 0, v5, s[10:11]                     ; d100007f 002a0a80
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v127, v127, v127 quad_perm:[1,0,3,2] row_mask:0xf bank_mask:0xf ; 02fefefa ff00b17f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v127, v127, v127 quad_perm:[2,3,0,1] row_mask:0xf bank_mask:0xf ; 02fefefa ff004e7f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v127, v127, v127 row_half_mirror row_mask:0xf bank_mask:0xf ; 02fefefa ff01417f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v127, v127, v127 row_mirror row_mask:0xf bank_mask:0xf ; 02fefefa ff01407f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v127, v127, v127 row_bcast:15 row_mask:0xa bank_mask:0xf ; 02fefefa af01427f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v127, v127, v127 row_bcast:31 row_mask:0xc bank_mask:0xf ; 02fefefa cf01437f
	s_mov_b64 exec, s[10:11]                                    ; befe010a
	v_readlane_b32 s6, v127, 63                                 ; d2890006 00017f7f
	s_cbranch_scc0 BB97                                         ; bf840034
BB92:
	s_or_saveexec_b64 s[10:11], -1                              ; be8a21c1
	s_cmp_lt_u32 3, s4                                          ; bf0a0483
	v_cndmask_b32_e64 v127, 0, v6, s[10:11]                     ; d100007f 002a0c80
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v127, v127, v127 quad_perm:[1,0,3,2] row_mask:0xf bank_mask:0xf ; 02fefefa ff00b17f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v127, v127, v127 quad_perm:[2,3,0,1] row_mask:0xf bank_mask:0xf ; 02fefefa ff004e7f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v127, v127, v127 row_half_mirror row_mask:0xf bank_mask:0xf ; 02fefefa ff01417f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v127, v127, v127 row_mirror row_mask:0xf bank_mask:0xf ; 02fefefa ff01407f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v127, v127, v127 row_bcast:15 row_mask:0xa bank_mask:0xf ; 02fefefa af01427f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v127, v127, v127 row_bcast:31 row_mask:0xc bank_mask:0xf ; 02fefefa cf01437f
	s_mov_b64 exec, s[10:11]                                    ; befe010a
	v_readlane_b32 s9, v127, 63                                 ; d2890009 00017f7f
	s_cbranch_scc0 BB95                                         ; bf840019
BB93:
	s_or_saveexec_b64 s[12:13], -1                              ; be8c21c1
	v_cndmask_b32_e64 v127, 0, v7, s[12:13]                     ; d100007f 00320e80
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v127, v127, v127 quad_perm:[1,0,3,2] row_mask:0xf bank_mask:0xf ; 02fefefa ff00b17f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v127, v127, v127 quad_perm:[2,3,0,1] row_mask:0xf bank_mask:0xf ; 02fefefa ff004e7f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v127, v127, v127 row_half_mirror row_mask:0xf bank_mask:0xf ; 02fefefa ff01417f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v127, v127, v127 row_mirror row_mask:0xf bank_mask:0xf ; 02fefefa ff01407f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v127, v127, v127 row_bcast:15 row_mask:0xa bank_mask:0xf ; 02fefefa af01427f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v127, v127, v127 row_bcast:31 row_mask:0xc bank_mask:0xf ; 02fefefa cf01437f
	s_mov_b64 exec, s[12:13]                                    ; befe010c
	v_readlane_b32 s10, v127, 63                                ; d289000a 00017f7f
	v_mov_b32_e32 v7, s10                                       ; 7e0e020a
BB95:
	v_mov_b32_e32 v6, s9                                        ; 7e0c0209
BB97:
	v_mov_b32_e32 v5, s6                                        ; 7e0a0206
	s_branch BB99                                               ; bf820001
BB98:
	s_mov_b32 s5, src_scc                                       ; be8500fd
BB99:
	s_or_saveexec_b64 s[10:11], -1                              ; be8a21c1
	s_cmp_lg_i32 s5, 0                                          ; bf018005
	v_cndmask_b32_e64 v127, 0, v8, s[10:11]                     ; d100007f 002a1080
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v127, v127, v127 quad_perm:[1,0,3,2] row_mask:0xf bank_mask:0xf ; 02fefefa ff00b17f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v127, v127, v127 quad_perm:[2,3,0,1] row_mask:0xf bank_mask:0xf ; 02fefefa ff004e7f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v127, v127, v127 row_half_mirror row_mask:0xf bank_mask:0xf ; 02fefefa ff01417f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v127, v127, v127 row_mirror row_mask:0xf bank_mask:0xf ; 02fefefa ff01407f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v127, v127, v127 row_bcast:15 row_mask:0xa bank_mask:0xf ; 02fefefa af01427f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v127, v127, v127 row_bcast:31 row_mask:0xc bank_mask:0xf ; 02fefefa cf01437f
	s_mov_b64 exec, s[10:11]                                    ; befe010a
	v_readlane_b32 s6, v127, 63                                 ; d2890006 00017f7f
	s_cbranch_scc0 BB108                                        ; bf84004f
BB100:
	s_or_saveexec_b64 s[10:11], -1                              ; be8a21c1
	s_cmp_lt_u32 2, s4                                          ; bf0a0482
	v_cndmask_b32_e64 v127, 0, v9, s[10:11]                     ; d100007f 002a1280
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v127, v127, v127 quad_perm:[1,0,3,2] row_mask:0xf bank_mask:0xf ; 02fefefa ff00b17f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v127, v127, v127 quad_perm:[2,3,0,1] row_mask:0xf bank_mask:0xf ; 02fefefa ff004e7f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v127, v127, v127 row_half_mirror row_mask:0xf bank_mask:0xf ; 02fefefa ff01417f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v127, v127, v127 row_mirror row_mask:0xf bank_mask:0xf ; 02fefefa ff01407f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v127, v127, v127 row_bcast:15 row_mask:0xa bank_mask:0xf ; 02fefefa af01427f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v127, v127, v127 row_bcast:31 row_mask:0xc bank_mask:0xf ; 02fefefa cf01437f
	s_mov_b64 exec, s[10:11]                                    ; befe010a
	v_readlane_b32 s5, v127, 63                                 ; d2890005 00017f7f
	s_cbranch_scc0 BB106                                        ; bf840034
BB101:
	s_or_saveexec_b64 s[10:11], -1                              ; be8a21c1
	s_cmp_lt_u32 3, s4                                          ; bf0a0483
	v_cndmask_b32_e64 v127, 0, v10, s[10:11]                    ; d100007f 002a1480
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v127, v127, v127 quad_perm:[1,0,3,2] row_mask:0xf bank_mask:0xf ; 02fefefa ff00b17f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v127, v127, v127 quad_perm:[2,3,0,1] row_mask:0xf bank_mask:0xf ; 02fefefa ff004e7f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v127, v127, v127 row_half_mirror row_mask:0xf bank_mask:0xf ; 02fefefa ff01417f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v127, v127, v127 row_mirror row_mask:0xf bank_mask:0xf ; 02fefefa ff01407f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v127, v127, v127 row_bcast:15 row_mask:0xa bank_mask:0xf ; 02fefefa af01427f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v127, v127, v127 row_bcast:31 row_mask:0xc bank_mask:0xf ; 02fefefa cf01437f
	s_mov_b64 exec, s[10:11]                                    ; befe010a
	v_readlane_b32 s9, v127, 63                                 ; d2890009 00017f7f
	s_cbranch_scc0 BB104                                        ; bf840019
BB102:
	s_or_saveexec_b64 s[12:13], -1                              ; be8c21c1
	v_cndmask_b32_e64 v127, 0, v11, s[12:13]                    ; d100007f 00321680
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v127, v127, v127 quad_perm:[1,0,3,2] row_mask:0xf bank_mask:0xf ; 02fefefa ff00b17f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v127, v127, v127 quad_perm:[2,3,0,1] row_mask:0xf bank_mask:0xf ; 02fefefa ff004e7f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v127, v127, v127 row_half_mirror row_mask:0xf bank_mask:0xf ; 02fefefa ff01417f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v127, v127, v127 row_mirror row_mask:0xf bank_mask:0xf ; 02fefefa ff01407f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v127, v127, v127 row_bcast:15 row_mask:0xa bank_mask:0xf ; 02fefefa af01427f
	s_nop 1                                                     ; bf800001
	v_add_f32_dpp v127, v127, v127 row_bcast:31 row_mask:0xc bank_mask:0xf ; 02fefefa cf01437f
	s_mov_b64 exec, s[12:13]                                    ; befe010c
	v_readlane_b32 s10, v127, 63                                ; d289000a 00017f7f
	v_mov_b32_e32 v11, s10                                      ; 7e16020a
BB104:
	v_mov_b32_e32 v10, s9                                       ; 7e140209
BB106:
	v_mov_b32_e32 v9, s5                                        ; 7e120205
BB108:
	v_mov_b32_e32 v3, s3                                        ; 7e060203
	v_mov_b32_e32 v8, s6                                        ; 7e100206
BB110:
	s_mov_b64 s[10:11], 1                                       ; be8a0181
	s_and_b64 exec, s[0:1], s[10:11]                            ; 86fe0a00
	s_cbranch_execz BB185                                       ; bf88010b
BB111:
	s_bitcmp1_b32 s8, 0                                         ; bf0d8008
	s_cbranch_scc0 BB113                                        ; bf84000e
BB112:
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
	s_branch BB114                                              ; bf820001
BB113:
	s_mov_b32 s1, src_scc                                       ; be8100fd
BB114:
	s_bitcmp1_b32 s8, 1                                         ; bf0d8108
	s_cbranch_scc0 BB116                                        ; bf84000e
BB115:
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
	s_branch BB117                                              ; bf820001
BB116:
	s_mov_b32 s3, src_scc                                       ; be8300fd
BB117:
	s_mov_b32 s0, s3                                            ; be800003
	s_movk_i32 s3, 0x8000                                       ; b0038000
	s_load_dwordx4 s[8:11], s[2:3], 0x20                        ; c00a0201 00000020
	s_mul_i32 s5, s7, s17                                       ; 92051107
	s_add_u32 s5, s5, s16                                       ; 80051005
	s_lshl_b32 s5, s5, 2                                        ; 8e058205
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_store_dword v3, off, s[8:11], s5                     ; e0700000 05020380
	s_cmp_lt_u32 1, s4                                          ; bf0a0481
	s_cbranch_scc0 BB143                                        ; bf84005e
BB118:
	s_mov_b32 s31, src_scc                                      ; be9f00fd
	s_cmp_lg_i32 s1, 0                                          ; bf018001
	s_mov_b32 s1, s31                                           ; be81001f
	s_cbranch_scc0 BB120                                        ; bf84000a
BB119:
	s_load_dwordx4 s[12:15], s[2:3], 0x30                       ; c00a0301 00000030
	s_mov_b32 s6, src_scc                                       ; be8600fd
	s_add_u32 s18, s5, 4                                        ; 80128405
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s18, s[12:15], s18                      ; c0200486 00000012
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v5, s18, v5                                   ; 020a0a12
	s_branch BB121                                              ; bf820001
BB120:
	s_mov_b32 s6, src_scc                                       ; be8600fd
BB121:
	s_cmp_lg_i32 s0, 0                                          ; bf018000
	s_cbranch_scc0 BB123                                        ; bf84000a
BB122:
	s_load_dwordx4 s[12:15], s[2:3], 0x40                       ; c00a0301 00000040
	s_mov_b32 s0, src_scc                                       ; be8000fd
	s_add_u32 s18, s5, 4                                        ; 80128405
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s18, s[12:15], s18                      ; c0200486 00000012
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v5, s18, v5                                   ; 020a0a12
	s_branch BB124                                              ; bf820001
BB123:
	s_mov_b32 s0, src_scc                                       ; be8000fd
BB124:
	s_add_u32 s12, s5, 4                                        ; 800c8405
	buffer_store_dword v5, off, s[8:11], s12                    ; e0700000 0c020580
	s_cmp_lt_u32 2, s4                                          ; bf0a0482
	s_cbranch_scc0 BB144                                        ; bf84003f
BB125:
	s_cmp_lg_i32 s6, 0                                          ; bf018006
	s_cbranch_scc0 BB127                                        ; bf84000a
BB126:
	s_load_dwordx4 s[12:15], s[2:3], 0x30                       ; c00a0301 00000030
	s_mov_b32 s6, src_scc                                       ; be8600fd
	s_add_u32 s18, s5, 8                                        ; 80128805
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s18, s[12:15], s18                      ; c0200486 00000012
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v6, s18, v6                                   ; 020c0c12
	s_branch BB128                                              ; bf820001
BB127:
	s_mov_b32 s6, src_scc                                       ; be8600fd
BB128:
	s_cmp_lg_i32 s0, 0                                          ; bf018000
	s_cbranch_scc0 BB130                                        ; bf84000a
BB129:
	s_load_dwordx4 s[12:15], s[2:3], 0x40                       ; c00a0301 00000040
	s_mov_b32 s0, src_scc                                       ; be8000fd
	s_add_u32 s18, s5, 8                                        ; 80128805
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s18, s[12:15], s18                      ; c0200486 00000012
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v6, s18, v6                                   ; 020c0c12
	s_branch BB131                                              ; bf820001
BB130:
	s_mov_b32 s0, src_scc                                       ; be8000fd
BB131:
	s_add_u32 s12, s5, 8                                        ; 800c8805
	buffer_store_dword v6, off, s[8:11], s12                    ; e0700000 0c020680
	s_cmp_lt_u32 3, s4                                          ; bf0a0483
	s_cbranch_scc0 BB144                                        ; bf840020
BB132:
	s_cmp_lg_i32 s6, 0                                          ; bf018006
	s_cbranch_scc0 BB134                                        ; bf84000a
BB133:
	s_load_dwordx4 s[12:15], s[2:3], 0x30                       ; c00a0301 00000030
	s_mov_b32 s6, src_scc                                       ; be8600fd
	s_add_u32 s18, s5, 12                                       ; 80128c05
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s18, s[12:15], s18                      ; c0200486 00000012
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v7, s18, v7                                   ; 020e0e12
	s_branch BB135                                              ; bf820001
BB134:
	s_mov_b32 s6, src_scc                                       ; be8600fd
BB135:
	s_cmp_lg_i32 s0, 0                                          ; bf018000
	s_cbranch_scc0 BB137                                        ; bf84000a
BB136:
	s_load_dwordx4 s[12:15], s[2:3], 0x40                       ; c00a0301 00000040
	s_mov_b32 s0, src_scc                                       ; be8000fd
	s_add_u32 s18, s5, 12                                       ; 80128c05
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s18, s[12:15], s18                      ; c0200486 00000012
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v7, s18, v7                                   ; 020e0e12
	s_branch BB138                                              ; bf820001
BB137:
	s_mov_b32 s0, src_scc                                       ; be8000fd
BB138:
	s_add_u32 s5, s5, 12                                        ; 80058c05
	buffer_store_dword v7, off, s[8:11], s5                     ; e0700000 05020780
	s_branch BB144                                              ; bf820002
BB143:
	s_mov_b32 s6, s1                                            ; be860001
	s_mov_b32 s1, src_scc                                       ; be8100fd
BB144:
	s_cmp_lg_i32 s6, 0                                          ; bf018006
	s_cbranch_scc0 BB146                                        ; bf84000d
BB145:
	s_load_dwordx4 s[12:15], s[2:3], 0x30                       ; c00a0301 00000030
	s_mov_b32 s5, src_scc                                       ; be8500fd
	s_add_u32 s6, 1, s17                                        ; 80061181
	s_mul_i32 s6, s7, s6                                        ; 92060607
	s_add_u32 s6, s6, s16                                       ; 80061006
	s_lshl_b32 s6, s6, 2                                        ; 8e068206
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s6, s[12:15], s6                        ; c0200186 00000006
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v8, s6, v8                                    ; 02101006
	s_branch BB147                                              ; bf820001
BB146:
	s_mov_b32 s5, src_scc                                       ; be8500fd
BB147:
	s_cmp_lg_i32 s0, 0                                          ; bf018000
	s_cbranch_scc0 BB149                                        ; bf84000d
BB148:
	s_load_dwordx4 s[12:15], s[2:3], 0x40                       ; c00a0301 00000040
	s_mov_b32 s0, src_scc                                       ; be8000fd
	s_add_u32 s6, 1, s17                                        ; 80061181
	s_mul_i32 s6, s7, s6                                        ; 92060607
	s_add_u32 s6, s6, s16                                       ; 80061006
	s_lshl_b32 s6, s6, 2                                        ; 8e068206
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s6, s[12:15], s6                        ; c0200186 00000006
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v8, s6, v8                                    ; 02101006
	s_branch BB150                                              ; bf820001
BB149:
	s_mov_b32 s0, src_scc                                       ; be8000fd
BB150:
	s_add_u32 s17, 1, s17                                       ; 80111181
	s_mul_i32 s7, s7, s17                                       ; 92071107
	s_add_u32 s7, s7, s16                                       ; 80071007
	s_lshl_b32 s7, s7, 2                                        ; 8e078207
	buffer_store_dword v8, off, s[8:11], s7                     ; e0700000 07020880
	s_cmp_lg_i32 s1, 0                                          ; bf018001
	s_cbranch_scc0 BB185                                        ; bf840055
BB151:
	s_cmp_lg_i32 s5, 0                                          ; bf018005
	s_cbranch_scc0 BB153                                        ; bf84000a
BB152:
	s_load_dwordx4 s[12:15], s[2:3], 0x30                       ; c00a0301 00000030
	s_mov_b32 s1, src_scc                                       ; be8100fd
	s_add_u32 s5, s7, 4                                         ; 80058407
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s5, s[12:15], s5                        ; c0200146 00000005
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v9, s5, v9                                    ; 02121205
	s_branch BB154                                              ; bf820001
BB153:
	s_mov_b32 s1, src_scc                                       ; be8100fd
BB154:
	s_cmp_lg_i32 s0, 0                                          ; bf018000
	s_cbranch_scc0 BB156                                        ; bf84000a
BB155:
	s_load_dwordx4 s[12:15], s[2:3], 0x40                       ; c00a0301 00000040
	s_mov_b32 s0, src_scc                                       ; be8000fd
	s_add_u32 s5, s7, 4                                         ; 80058407
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s5, s[12:15], s5                        ; c0200146 00000005
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v9, s5, v9                                    ; 02121205
	s_branch BB157                                              ; bf820001
BB156:
	s_mov_b32 s0, src_scc                                       ; be8000fd
BB157:
	s_add_u32 s5, s7, 4                                         ; 80058407
	buffer_store_dword v9, off, s[8:11], s5                     ; e0700000 05020980
	s_cmp_lt_u32 2, s4                                          ; bf0a0482
	s_cbranch_scc0 BB185                                        ; bf840036
BB158:
	s_cmp_lg_i32 s1, 0                                          ; bf018001
	s_cbranch_scc0 BB160                                        ; bf84000a
BB159:
	s_load_dwordx4 s[12:15], s[2:3], 0x30                       ; c00a0301 00000030
	s_mov_b32 s1, src_scc                                       ; be8100fd
	s_add_u32 s5, s7, 8                                         ; 80058807
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s5, s[12:15], s5                        ; c0200146 00000005
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v10, s5, v10                                  ; 02141405
	s_branch BB161                                              ; bf820001
BB160:
	s_mov_b32 s1, src_scc                                       ; be8100fd
BB161:
	s_cmp_lg_i32 s0, 0                                          ; bf018000
	s_cbranch_scc0 BB163                                        ; bf84000a
BB162:
	s_load_dwordx4 s[12:15], s[2:3], 0x40                       ; c00a0301 00000040
	s_mov_b32 s0, src_scc                                       ; be8000fd
	s_add_u32 s5, s7, 8                                         ; 80058807
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s5, s[12:15], s5                        ; c0200146 00000005
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v10, s5, v10                                  ; 02141405
	s_branch BB164                                              ; bf820001
BB163:
	s_mov_b32 s0, src_scc                                       ; be8000fd
BB164:
	s_add_u32 s5, s7, 8                                         ; 80058807
	buffer_store_dword v10, off, s[8:11], s5                    ; e0700000 05020a80
	s_cmp_lt_u32 3, s4                                          ; bf0a0483
	s_cbranch_scc0 BB185                                        ; bf840017
BB165:
	s_cmp_lg_i32 s1, 0                                          ; bf018001
	s_cbranch_scc0 BB168                                        ; bf840008
BB166:
	s_load_dwordx4 s[12:15], s[2:3], 0x30                       ; c00a0301 00000030
	s_add_u32 s1, s7, 12                                        ; 80018c07
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s1, s[12:15], s1                        ; c0200046 00000001
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v11, s1, v11                                  ; 02161601
BB168:
	s_cmp_lg_i32 s0, 0                                          ; bf018000
	s_cbranch_scc0 BB171                                        ; bf840008
BB169:
	s_load_dwordx4 s[0:3], s[2:3], 0x40                         ; c00a0001 00000040
	s_add_u32 s4, s7, 12                                        ; 80048c07
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	s_buffer_load_dword s4, s[0:3], s4                          ; c0200100 00000004
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v11, s4, v11                                  ; 02161604
BB171:
	s_add_u32 s7, s7, 12                                        ; 80078c07
	buffer_store_dword v11, off, s[8:11], s7                    ; e0700000 07020b80
BB185:
	s_endpgm                                                    ; bf810000
