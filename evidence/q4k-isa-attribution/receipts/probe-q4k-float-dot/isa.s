BB0:
	s_mov_b32 s0, s3                                            ; be800003
	s_movk_i32 s3, 0x8000                                       ; b0038000
	s_load_dwordx8 s[8:15], s[2:3], 0x0                         ; c00e0201 00000000
	v_lshl_add_u32 v1, s0, 6, v0                                ; d1fd0001 04010c00
	v_lshlrev_b32_e32 v1, 2, v1                                 ; 24020282
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	buffer_load_dword v2, v1, s[8:11], 0 offen                  ; e0501000 80020201
	buffer_load_dword v1, v1, s[12:15], 0 offen                 ; e0501000 80030101
	v_lshlrev_b32_e32 v0, 2, v0                                 ; 24000082
	s_mov_b64 s[4:5], 1                                         ; be840181
	s_waitcnt vmcnt(1)                                          ; bf8c3f71
	v_lshrrev_b32_e32 v3, 4, v2                                 ; 20060484
	v_and_b32_e32 v5, 15, v2                                    ; 260a048f
	v_and_b32_e32 v2, 0xf0f0f0f, v2                             ; 260404ff 0f0f0f0f
	v_and_b32_e32 v4, 15, v3                                    ; 2608068f
	v_and_b32_e32 v3, 0xf0f0f0f, v3                             ; 260606ff 0f0f0f0f
	v_cvt_f32_u32_e32 v5, v5                                    ; 7e0a0d05
	s_waitcnt vmcnt(0)                                          ; bf8c3f70
	v_cvt_f32_i32_sdwa v10, sext(v1) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 ; 7e140af9 00080601
	v_bfe_u32 v6, v2, 8, 4                                      ; d1c80006 02111102
	v_bfe_u32 v8, v2, 16, 4                                     ; d1c80008 02112102
	v_cvt_f32_ubyte3_e32 v2, v2                                 ; 7e042902
	v_cvt_f32_i32_sdwa v11, sext(v1) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 ; 7e160af9 00090601
	v_cvt_f32_u32_e32 v4, v4                                    ; 7e080d04
	v_bfe_u32 v7, v3, 8, 4                                      ; d1c80007 02111103
	v_bfe_u32 v9, v3, 16, 4                                     ; d1c80009 02112103
	v_cvt_f32_ubyte3_e32 v3, v3                                 ; 7e062903
	v_cvt_f32_i32_sdwa v12, sext(v1) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 ; 7e180af9 000a0601
	v_cvt_f32_u32_e32 v6, v6                                    ; 7e0c0d06
	v_cvt_f32_u32_e32 v8, v8                                    ; 7e100d08
	v_cvt_f32_i32_sdwa v1, sext(v1) dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_3 ; 7e020af9 000b0601
	v_add_f32_e32 v4, v4, v5                                    ; 02080b04
	v_cvt_f32_u32_e32 v7, v7                                    ; 7e0e0d07
	v_cvt_f32_u32_e32 v9, v9                                    ; 7e120d09
	v_mul_f32_e32 v10, v10, v4                                  ; 0a14090a
	v_mac_f32_e32 v10, v6, v11                                  ; 2c141706
	v_mac_f32_e32 v10, v7, v11                                  ; 2c141707
	v_mac_f32_e32 v10, v8, v12                                  ; 2c141908
	v_mac_f32_e32 v10, v9, v12                                  ; 2c141909
	v_mac_f32_e32 v10, v2, v1                                   ; 2c140302
	v_mac_f32_e32 v10, v3, v1                                   ; 2c140303
	ds_write_b32 v0, v10                                        ; d81a0000 00000a00
	s_mov_b64 exec, s[4:5]                                      ; befe0104
	s_cbranch_execz BB6                                         ; bf8800a0
BB1:
	v_mov_b32_e32 v0, 0                                         ; 7e000280
	ds_read_b64 v[2:3], v0                                      ; d8ec0000 02000000
	ds_read_b64 v[4:5], v0 offset:8                             ; d8ec0008 04000000
	ds_read_b64 v[6:7], v0 offset:16                            ; d8ec0010 06000000
	ds_read_b64 v[8:9], v0 offset:24                            ; d8ec0018 08000000
	ds_read_b64 v[10:11], v0 offset:32                          ; d8ec0020 0a000000
	ds_read_b64 v[12:13], v0 offset:40                          ; d8ec0028 0c000000
	ds_read_b64 v[14:15], v0 offset:48                          ; d8ec0030 0e000000
	ds_read_b64 v[16:17], v0 offset:56                          ; d8ec0038 10000000
	ds_read_b64 v[18:19], v0 offset:64                          ; d8ec0040 12000000
	ds_read_b64 v[20:21], v0 offset:72                          ; d8ec0048 14000000
	ds_read_b64 v[22:23], v0 offset:80                          ; d8ec0050 16000000
	ds_read_b64 v[24:25], v0 offset:88                          ; d8ec0058 18000000
	ds_read_b64 v[26:27], v0 offset:96                          ; d8ec0060 1a000000
	ds_read_b64 v[28:29], v0 offset:104                         ; d8ec0068 1c000000
	ds_read_b64 v[30:31], v0 offset:112                         ; d8ec0070 1e000000
	ds_read_b64 v[32:33], v0 offset:120                         ; d8ec0078 20000000
	ds_read_b64 v[34:35], v0 offset:128                         ; d8ec0080 22000000
	s_waitcnt lgkmcnt(14)                                       ; bf8cce7f
	v_add_f32_e32 v2, v2, v3                                    ; 02040702
	v_add_f32_e32 v4, v4, v2                                    ; 02080504
	v_add_f32_e32 v5, v5, v4                                    ; 020a0905
	v_add_f32_e32 v6, v6, v5                                    ; 020c0b06
	v_add_f32_e32 v7, v7, v6                                    ; 020e0d07
	s_waitcnt lgkmcnt(13)                                       ; bf8ccd7f
	v_add_f32_e32 v8, v8, v7                                    ; 02100f08
	v_add_f32_e32 v9, v9, v8                                    ; 02121109
	s_waitcnt lgkmcnt(12)                                       ; bf8ccc7f
	v_add_f32_e32 v10, v10, v9                                  ; 0214130a
	v_add_f32_e32 v11, v11, v10                                 ; 0216150b
	s_waitcnt lgkmcnt(11)                                       ; bf8ccb7f
	v_add_f32_e32 v12, v12, v11                                 ; 0218170c
	v_add_f32_e32 v13, v13, v12                                 ; 021a190d
	s_waitcnt lgkmcnt(10)                                       ; bf8cca7f
	v_add_f32_e32 v14, v14, v13                                 ; 021c1b0e
	v_add_f32_e32 v15, v15, v14                                 ; 021e1d0f
	s_waitcnt lgkmcnt(9)                                        ; bf8cc97f
	v_add_f32_e32 v16, v16, v15                                 ; 02201f10
	v_add_f32_e32 v17, v17, v16                                 ; 02222111
	s_waitcnt lgkmcnt(8)                                        ; bf8cc87f
	v_add_f32_e32 v18, v18, v17                                 ; 02242312
	ds_read_b64 v[2:3], v0 offset:136                           ; d8ec0088 02000000
	ds_read_b64 v[4:5], v0 offset:144                           ; d8ec0090 04000000
	ds_read_b64 v[6:7], v0 offset:152                           ; d8ec0098 06000000
	ds_read_b64 v[8:9], v0 offset:160                           ; d8ec00a0 08000000
	ds_read_b64 v[10:11], v0 offset:168                         ; d8ec00a8 0a000000
	ds_read_b64 v[12:13], v0 offset:176                         ; d8ec00b0 0c000000
	ds_read_b64 v[14:15], v0 offset:184                         ; d8ec00b8 0e000000
	ds_read_b64 v[16:17], v0 offset:192                         ; d8ec00c0 10000000
	v_add_f32_e32 v19, v19, v18                                 ; 02262513
	s_waitcnt lgkmcnt(14)                                       ; bf8cce7f
	v_add_f32_e32 v20, v20, v19                                 ; 02282714
	v_add_f32_e32 v21, v21, v20                                 ; 022a2915
	v_add_f32_e32 v22, v22, v21                                 ; 022c2b16
	v_add_f32_e32 v23, v23, v22                                 ; 022e2d17
	s_waitcnt lgkmcnt(13)                                       ; bf8ccd7f
	v_add_f32_e32 v24, v24, v23                                 ; 02302f18
	v_add_f32_e32 v25, v25, v24                                 ; 02323119
	s_waitcnt lgkmcnt(12)                                       ; bf8ccc7f
	v_add_f32_e32 v26, v26, v25                                 ; 0234331a
	v_add_f32_e32 v27, v27, v26                                 ; 0236351b
	s_waitcnt lgkmcnt(11)                                       ; bf8ccb7f
	v_add_f32_e32 v28, v28, v27                                 ; 0238371c
	v_add_f32_e32 v29, v29, v28                                 ; 023a391d
	s_waitcnt lgkmcnt(10)                                       ; bf8cca7f
	v_add_f32_e32 v30, v30, v29                                 ; 023c3b1e
	ds_read_b64 v[18:19], v0 offset:200                         ; d8ec00c8 12000000
	ds_read_b64 v[20:21], v0 offset:208                         ; d8ec00d0 14000000
	ds_read_b64 v[22:23], v0 offset:216                         ; d8ec00d8 16000000
	ds_read_b64 v[24:25], v0 offset:224                         ; d8ec00e0 18000000
	ds_read_b64 v[26:27], v0 offset:232                         ; d8ec00e8 1a000000
	ds_read_b64 v[28:29], v0 offset:240                         ; d8ec00f0 1c000000
	ds_read_b64 v[0:1], v0 offset:248                           ; d8ec00f8 00000000
	s_load_dwordx4 s[4:7], s[2:3], 0x20                         ; c00a0101 00000020
	v_add_f32_e32 v31, v31, v30                                 ; 023e3d1f
	s_waitcnt lgkmcnt(14)                                       ; bf8cce7f
	v_add_f32_e32 v32, v32, v31                                 ; 02403f20
	v_add_f32_e32 v33, v33, v32                                 ; 02424121
	v_add_f32_e32 v34, v34, v33                                 ; 02444322
	v_add_f32_e32 v35, v35, v34                                 ; 02464523
	v_add_f32_e32 v2, v2, v35                                   ; 02044702
	v_add_f32_e32 v3, v3, v2                                    ; 02060503
	s_waitcnt lgkmcnt(13)                                       ; bf8ccd7f
	v_add_f32_e32 v4, v4, v3                                    ; 02080704
	v_add_f32_e32 v5, v5, v4                                    ; 020a0905
	s_waitcnt lgkmcnt(12)                                       ; bf8ccc7f
	v_add_f32_e32 v6, v6, v5                                    ; 020c0b06
	v_add_f32_e32 v7, v7, v6                                    ; 020e0d07
	s_waitcnt lgkmcnt(11)                                       ; bf8ccb7f
	v_add_f32_e32 v8, v8, v7                                    ; 02100f08
	v_add_f32_e32 v9, v9, v8                                    ; 02121109
	s_waitcnt lgkmcnt(10)                                       ; bf8cca7f
	v_add_f32_e32 v10, v10, v9                                  ; 0214130a
	v_add_f32_e32 v11, v11, v10                                 ; 0216150b
	s_waitcnt lgkmcnt(9)                                        ; bf8cc97f
	v_add_f32_e32 v12, v12, v11                                 ; 0218170c
	v_add_f32_e32 v13, v13, v12                                 ; 021a190d
	s_waitcnt lgkmcnt(8)                                        ; bf8cc87f
	v_add_f32_e32 v14, v14, v13                                 ; 021c1b0e
	v_add_f32_e32 v15, v15, v14                                 ; 021e1d0f
	s_waitcnt lgkmcnt(7)                                        ; bf8cc77f
	v_add_f32_e32 v16, v16, v15                                 ; 02201f10
	s_lshl_b32 s0, s0, 2                                        ; 8e008200
	v_add_f32_e32 v17, v17, v16                                 ; 02222111
	s_waitcnt lgkmcnt(6)                                        ; bf8cc67f
	v_add_f32_e32 v18, v18, v17                                 ; 02242312
	v_add_f32_e32 v19, v19, v18                                 ; 02262513
	s_waitcnt lgkmcnt(5)                                        ; bf8cc57f
	v_add_f32_e32 v20, v20, v19                                 ; 02282714
	v_add_f32_e32 v21, v21, v20                                 ; 022a2915
	s_waitcnt lgkmcnt(4)                                        ; bf8cc47f
	v_add_f32_e32 v22, v22, v21                                 ; 022c2b16
	v_add_f32_e32 v23, v23, v22                                 ; 022e2d17
	s_waitcnt lgkmcnt(3)                                        ; bf8cc37f
	v_add_f32_e32 v24, v24, v23                                 ; 02302f18
	v_add_f32_e32 v25, v25, v24                                 ; 02323119
	s_waitcnt lgkmcnt(2)                                        ; bf8cc27f
	v_add_f32_e32 v26, v26, v25                                 ; 0234331a
	v_add_f32_e32 v27, v27, v26                                 ; 0236351b
	s_waitcnt lgkmcnt(1)                                        ; bf8cc17f
	v_add_f32_e32 v28, v28, v27                                 ; 0238371c
	v_add_f32_e32 v29, v29, v28                                 ; 023a391d
	s_waitcnt lgkmcnt(0)                                        ; bf8cc07f
	v_add_f32_e32 v0, v0, v29                                   ; 02003b00
	v_add_f32_e32 v1, v1, v0                                    ; 02020101
	buffer_store_dword v1, off, s[4:7], s0                      ; e0700000 00010180
BB6:
	s_endpgm                                                    ; bf810000
