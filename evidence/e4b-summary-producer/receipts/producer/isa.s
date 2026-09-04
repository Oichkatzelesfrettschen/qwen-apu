BB0:
	v_lshl_add_u32 v0, s6, 6, v0                                ; d1fd0000 04010c06
	s_lshl_b32 s3, s3, 4                                        ; 8e038403
	s_mul_i32 s4, s3, s4                                        ; 92040403
	v_cmpx_gt_u32_e32 vcc, s4, v0                               ; 7db80004
	s_cbranch_execz BB6                                         ; bf880050
BB1:
	s_mov_b32 s0, s3                                            ; be800003
	s_movk_i32 s3, 0x8000                                       ; b0038000
	s_load_dwordx8 s[8:15], s[2:3], 0x0                         ; c00e0201 00000000
	v_cvt_f32_u32_e32 v1, s0                                    ; 7e020c00
	v_rcp_f32_e32 v1, v1                                        ; 7e024501
	v_mul_f32_e32 v1, 0x4f7ffffe, v1                            ; 0a0202ff 4f7ffffe
	v_cvt_u32_f32_e32 v1, v1                                    ; 7e020f01
	v_readfirstlane_b32 s1, v1                                  ; 7e020501
	s_mul_i32 s2, s0, s1                                        ; 92020100
	s_sub_i32 s2, 0, s2                                         ; 81820280
	s_mul_hi_u32 s2, s1, s2                                     ; 96020201
	s_add_u32 s1, s1, s2                                        ; 80010201
	v_mul_hi_u32 v2, v0, s1                                     ; d2860002 00000300
	v_mul_lo_u32 v3, v2, s0                                     ; d2850003 00000102
	v_sub_u32_e32 v3, v0, v3                                    ; 6a060700
	v_subrev_u32_e32 v4, s0, v3                                 ; 6c080600
	v_cmp_le_u32_e32 vcc, s0, v3                                ; 7d960600
	v_addc_co_u32_e64 v2, s[2:3], 0, v2, vcc                    ; d11c0202 01aa0480
	v_cndmask_b32_e32 v3, v3, v4, vcc                           ; 00060903
	v_cmp_le_u32_e32 vcc, s0, v3                                ; 7d960600
	s_movk_i32 s3, 0x80                                         ; b0030080
	v_addc_co_u32_e32 v2, vcc, 0, v2, vcc                       ; 38040480
	v_mul_lo_u32 v5, v2, s0                                     ; d2850005 00000102
	v_mul_lo_u32 v2, v2, s5                                     ; d2850002 00000b02
	v_sub_u32_e32 v0, v0, v5                                    ; 6a000b00
	v_and_b32_e32 v6, -16, v0                                   ; 260c00d0
	v_sub_u32_e32 v7, v0, v6                                    ; 6a0e0d00
	v_lshrrev_b32_e32 v0, 4, v0                                 ; 20000084
	v_and_b32_e32 v8, 7, v7                                     ; 26100e87
	v_lshrrev_b32_e32 v9, 3, v7                                 ; 20120e83
	v_lshlrev_b32_e32 v8, 2, v8                                 ; 24101082
	v_lshl_add_u32 v9, v9, 6, v8                                ; d1fd0009 04210d09
	v_lshl_add_u32 v0, v0, 8, v9                                ; d1fd0000 04251100
	v_add_u32_e32 v10, v2, v0                                   ; 68140102
	v_add3_u32 v0, v2, s3, v0                                   ; d1ff0000 04000702
	v_lshrrev_b32_e32 v10, 2, v10                               ; 20141482
	v_lshrrev_b32_e32 v0, 2, v0                                 ; 20000082
	v_lshlrev_b32_e32 v10, 4, v10                               ; 24141484
	v_lshlrev_b32_e32 v0, 4, v0                                 ; 24000084
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_load_dwordx4 v[12:15], v10, s[8:11], 0 offen         ; e05c1000 80020c0a
	buffer_load_dwordx4 v[8:11], v10, s[8:11], 0 offen offset:128 ; e05c1080 8002080a
	buffer_load_dwordx4 v[16:19], v0, s[8:11], 0 offen          ; e05c1000 80021000
	buffer_load_dwordx4 v[20:23], v0, s[8:11], 0 offen offset:128 ; e05c1080 80021400
	v_lshrrev_b32_e32 v2, 4, v2                                 ; 20040484
	v_add3_u32 v7, v7, v2, v6                                   ; d1ff0007 041a0507
	v_lshlrev_b32_e32 v7, 4, v7                                 ; 240e0e84
	s_waitcnt vmcnt(3)                                          ; bf8c3f73
	v_add_f32_e32 v12, v12, v13                                 ; 02181b0c
	s_waitcnt vmcnt(2)                                          ; bf8c3f72
	v_add_f32_e32 v8, v8, v9                                    ; 02101308
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_add_f32_e32 v16, v16, v17                                 ; 02202310
	v_add_f32_e32 v12, v12, v14                                 ; 02181d0c
	v_add_f32_e32 v8, v8, v10                                   ; 02101508
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_add_f32_e32 v20, v20, v21                                 ; 02282b14
	v_add_f32_e32 v16, v16, v18                                 ; 02202510
	v_add_f32_e32 v0, v12, v15                                  ; 02001f0c
	v_add_f32_e32 v1, v8, v11                                   ; 02021708
	v_add_f32_e32 v20, v20, v22                                 ; 02282d14
	v_add_f32_e32 v2, v16, v19                                  ; 02042710
	v_add_f32_e32 v3, v20, v23                                  ; 02062f14
	buffer_store_dwordx4 v[0:3], v7, s[12:15], 0 offen          ; e07c1000 80030007
BB6:
	s_endpgm                                                    ; bf810000
