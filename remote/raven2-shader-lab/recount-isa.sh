#!/bin/sh
set -eu

# Recount a retained ISA listing under the expanded instruction schema, so a
# receipt written before lab.sh counted a mnemonic is reinterpreted from the raw
# record rather than re-measured. The measurement head and the analysis head are
# separate here: `isa.s` is what the run produced and every count below is
# derived from it, so a reader added later reaches every arm ever retained
# including the ones whose driver is no longer installed.
#
# Two counts the receipt schema has no field for are reported because the arm's
# mechanism is a claim about operand encoding rather than about opcode choice.
# A GFX9 SDWA 24-bit multiply selects a byte on each source independently, so
# `mul24_dual_byte_select` counts the products that fold a byte select into both
# operands and `mul24_dword_by_byte_select` counts those that read one source as
# a whole DWORD. A masked byte that ACO can prove already occupies the low lane
# needs no select on that side, so the split states how much of the expansion
# the encoding actually absorbed.
#
# usage: recount-isa.sh ISA_FILE [ISA_FILE ...]

if [ "$#" -lt 1 ]; then
    printf 'usage: %s ISA_FILE [ISA_FILE ...]\n' "$0" >&2
    exit 2
fi

for isa_file in "$@"; do
    if [ ! -r "$isa_file" ]; then
        printf 'ISA listing is unreadable: %s\n' "$isa_file" >&2
        exit 1
    fi
done

# The mnemonics the expanded schema counts, in the order lab.sh writes them,
# with the encoding suffixes GFX9 spells them under folded into one name.
counted_mnemonics='v_mul_lo_u32 v_mul_u32_u24 v_mul_i32_i24 v_mad_u32_u24
v_mad_i32_i24 v_add3_u32 v_add_u32 v_mov_b32 v_perm_b32 v_bfe_u32
v_cvt_f32_f16 v_cvt_f32_ubyte0 v_mad_mix_f32 v_fma_f32 v_mac_f32 v_pk_fma_f16'

printf 'isa_path\tisa_sha256'
for counted_mnemonic in $counted_mnemonics; do
    printf '\t%s' "$counted_mnemonic"
done
printf '\tsdwa_operand_uses\tmul24_dual_byte_select\tmul24_dword_by_byte_select\n'

for isa_file in "$@"; do
    printf '%s\t%s' "$isa_file" "$(sha256sum "$isa_file" | cut -d ' ' -f 1)"
    for counted_mnemonic in $counted_mnemonics; do
        # The mnemonic is matched at the head of an instruction line with its
        # encoding suffix, so v_add_u32 counts v_add_u32_e32 and never
        # v_add3_u32, which a substring match would fold into it.
        printf '\t%s' "$(awk -v name="$counted_mnemonic" '
            { mnemonic = $1
              sub(/_(e32|e64|sdwa|dpp|sdwa_e32)$/, "", mnemonic)
              if (mnemonic == name) count++ }
            END { print count + 0 }' "$isa_file")"
    done
    printf '\t%s' "$(grep -c '_sdwa' "$isa_file" || true)"
    # A 24-bit multiply under SDWA states one select per source; the pair
    # decides whether the byte extraction was absorbed on both sides or one.
    printf '\t%s' "$(awk '
        $1 ~ /^v_(mul|mad)_(u32_u24|i32_i24)(_sdwa)?$/ &&
        /src0_sel:BYTE_/ && /src1_sel:BYTE_/ { count++ }
        END { print count + 0 }' "$isa_file")"
    printf '\t%s\n' "$(awk '
        $1 ~ /^v_(mul|mad)_(u32_u24|i32_i24)(_sdwa)?$/ &&
        (/src0_sel:DWORD/ || /src1_sel:DWORD/) { count++ }
        END { print count + 0 }' "$isa_file")"
done
