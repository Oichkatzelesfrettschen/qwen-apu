#!/bin/sh
set -eu

# The recount reader against a fixture listing whose every count is stated in
# the fixture itself, so the schema and the two byte-select classes are checked
# without a driver and without a device.

if [ "$#" -gt 0 ]; then
    printf 'usage: %s\n' "$0" >&2
    exit 2
fi

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
recounter=$script_directory/recount-isa.sh

temporary_directory=$(mktemp -d)
trap 'rm -rf -- "$temporary_directory"' EXIT HUP INT TERM

fixture=$temporary_directory/isa.s
cat >"$fixture" <<'FIXTURE'
Compute Shader:
	v_mul_u32_u24_sdwa v19, v10, v12 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:DWORD src1_sel:BYTE_0 ; 102618f9
	v_mul_u32_u24_sdwa v22, v16, v12 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_2 src1_sel:BYTE_2 ; 102c18f9
	v_mul_u32_u24_sdwa v23, v17, v13 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_1 src1_sel:BYTE_3 ; 102c18fa
	v_mul_i32_i24_sdwa v24, v18, v14 dst_sel:DWORD dst_unused:UNUSED_PAD src0_sel:BYTE_0 src1_sel:BYTE_1 ; 102c18fb
	v_add3_u32 v25, v19, v22, v23                                                                        ; d1ff0019
	v_add3_u32 v26, v24, v25, v23                                                                        ; d1ff001a
	v_add_u32_e32 v27, v25, v26                                                                          ; 68361b19
	v_mov_b32_e32 v28, 0                                                                                 ; 7e380280
	v_cvt_f32_f16_e32 v29, v28                                                                           ; 7e3a5f1c
	v_mad_mix_f32 v30, v29, v29, v30 op_sel_hi:[1,1,0]                                                   ; d3a0001e
	v_mul_lo_u32 v31, v30, v29                                                                           ; d2850x1f
	s_endpgm
FIXTURE

output=$temporary_directory/recount.tsv
"$recounter" "$fixture" >"$output"

header=$(head -n 1 "$output")
read_count() {
    awk -F'\t' -v name="$1" -v header="$header" '
        BEGIN { n = split(header, columns, "\t"); for (i = 1; i <= n; i++) if (columns[i] == name) want = i }
        NR == 2 { print $want }' "$output"
}

check() {
    check_name=$1
    check_expected=$2
    check_observed=$(read_count "$check_name")
    if [ "$check_observed" != "$check_expected" ]; then
        printf '%s read %s where the fixture states %s\n' \
            "$check_name" "${check_observed:--}" "$check_expected" >&2
        exit 1
    fi
}

# Three unsigned and one signed 24-bit multiply, so the two multiply columns
# separate rather than sharing a substring match.
check v_mul_u32_u24 3
check v_mul_i32_i24 1
check v_mul_lo_u32 1
check v_mad_u32_u24 0
# v_add3_u32 and v_add_u32 are distinct instructions whose names share a prefix,
# which is the confusion a substring counter makes.
check v_add3_u32 2
check v_add_u32 1
check v_mov_b32 1
check v_cvt_f32_f16 1
check v_mad_mix_f32 1
check v_pk_fma_f16 0
# Four SDWA instructions, three of them selecting a byte on both sources and one
# reading a whole DWORD on src0.
check sdwa_operand_uses 4
check mul24_dual_byte_select 3
check mul24_dword_by_byte_select 1

observed_digest=$(awk -F'\t' 'NR == 2 { print $2 }' "$output")
if [ "$observed_digest" != "$(sha256sum "$fixture" | cut -d ' ' -f 1)" ]; then
    printf 'the recount records a digest other than the listing it read\n' >&2
    exit 1
fi
printf 'fixture_counts=accepted\n'

# Two listings in one call keep one header and two rows, since a census over a
# lane is what the reader exists for.
"$recounter" "$fixture" "$fixture" >"$temporary_directory/pair.tsv"
[ "$(awk 'END { print NR }' "$temporary_directory/pair.tsv")" = 3 ]
printf 'multiple_listings=accepted\n'

unreadable_status=0
"$recounter" "$temporary_directory/absent.s" >/dev/null \
    2>"$temporary_directory/absent.log" || unreadable_status=$?
[ "$unreadable_status" -eq 1 ]
grep -q 'ISA listing is unreadable' "$temporary_directory/absent.log"
printf 'unreadable_listing=accepted\n'

usage_status=0
"$recounter" >/dev/null 2>&1 || usage_status=$?
[ "$usage_status" -eq 2 ]
printf 'usage=accepted\n'

printf 'recount_isa=accepted\n'
