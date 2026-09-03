#!/bin/sh
set -eu

# receipt-diff.sh attributes a layer difference to a source change, so what a
# test on a host with no RADV part checks is which receipt pairs it refuses to
# attribute anything from. The receipts below are written here rather than
# produced by lab.sh: each case changes one field against a base pair whose
# every other field agrees.

if [ "$#" -ne 0 ]; then
    printf 'usage: %s\n' "$0" >&2
    exit 2
fi

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
differ=$script_directory/receipt-diff.sh
temporary_directory=$(mktemp -d)
cleanup() {
    cleanup_status=$?
    rm -rf -- "$temporary_directory"
    exit "$cleanup_status"
}
trap cleanup EXIT HUP INT TERM

failures=0
report() {
    if [ "$1" = 0 ]; then
        printf 'ok %s\n' "$2"
    else
        printf 'FAIL %s\n' "$2"
        failures=$((failures + 1))
    fi
}

# usage: write_receipt DIRECTORY SPIRV NIR ISA SUBGROUP BINDINGS
write_receipt() {
    receipt_directory=$1
    mkdir -p "$receipt_directory"
    {
        printf 'field\tvalue\tper_superblock\n'
        printf 'run_mode\treplay\t-\n'
        printf 'spirv_path\t%s/fixture.spv\t-\n' "$receipt_directory"
        printf 'spirv_sha256\t%s\t-\n' "$2"
        printf 'spirv_bytes\t6852\t-\n'
        printf 'nir_sha256\t%s\t-\n' "$3"
        printf 'isa_sha256\t%s\t-\n' "$4"
        printf 'device_name\tAMD Radeon Graphics (RADV RAVEN2)\t-\n'
        printf 'driver_name\tradv\t-\n'
        printf 'driver_info\tMesa 25.3.2\t-\n'
        printf 'device_api_version\t1.4.321\t-\n'
        printf 'spirv_capabilities\tShader\t-\n'
        printf 'features_enabled\tsubgroupSizeControl,computeFullSubgroups\t-\n'
        printf 'robust_buffer_access\toff\t-\n'
        printf 'spec_constants\t0:64,1:4,2:1\t-\n'
        printf 'bindings\t%s\t-\n' "$6"
        printf 'push_constant_bytes\t64\t-\n'
        printf 'subgroup_size_requested\t%s\t-\n' "$5"
        printf 'subgroup_size_min\t64\t-\n'
        printf 'subgroup_size_max\t64\t-\n'
        printf 'per_superblock_divisor\t-\t-\n'
        printf 'vgprs\t48\t-\n'
        printf 'sgprs\t32\t-\n'
        printf 'code_size\t4096\t-\n'
        printf 'instruction_lines\t900\t-\n'
    } >"$receipt_directory/receipt.tsv"
}

control=$temporary_directory/control
write_receipt "$control" aaaa bbbb cccc 64 5

# The comparison the tool exists for: three digests differ and the execution
# contract holds, so the ISA verdict follows from the source change.
candidate=$temporary_directory/candidate
write_receipt "$candidate" dddd eeee ffff 64 5
verdict_status=0
"$differ" "$control" "$candidate" >"$temporary_directory/verdict.txt" 2>&1 ||
    verdict_status=$?
if [ "$verdict_status" -eq 0 ] &&
    grep -qx "$(printf 'verdict\tisa_changed')" "$temporary_directory/verdict.txt"; then
    report 0 matching_contract_reaches_a_verdict
else
    report 1 matching_contract_reaches_a_verdict
    cat "$temporary_directory/verdict.txt" >&2
fi

# A shader's own declaration decides nothing: the sideplane variant adds one
# binding and the comparison is still about the instructions it emitted.
declaration_candidate=$temporary_directory/declaration
write_receipt "$declaration_candidate" dddd eeee ffff 64 6
declaration_status=0
"$differ" "$control" "$declaration_candidate" \
    >"$temporary_directory/declaration.txt" 2>&1 || declaration_status=$?
if [ "$declaration_status" -eq 0 ] &&
    grep -qx "$(printf 'verdict\tisa_changed')" "$temporary_directory/declaration.txt" &&
    grep -qx "$(printf 'bindings\t5\t6\tchanged')" "$temporary_directory/declaration.txt"; then
    report 0 declaration_difference_is_reported_and_compared
else
    report 1 declaration_difference_is_reported_and_compared
    cat "$temporary_directory/declaration.txt" >&2
fi

# A subgroup size the harness asked for differently makes the emitted
# instructions a statement about the request rather than about the source.
subgroup_candidate=$temporary_directory/subgroup
write_receipt "$subgroup_candidate" dddd eeee ffff 32 5
subgroup_status=0
"$differ" "$control" "$subgroup_candidate" \
    >"$temporary_directory/subgroup.txt" 2>&1 || subgroup_status=$?
if [ "$subgroup_status" -eq 1 ] &&
    grep -q 'execution contract differs.*subgroup_size_requested control=64 candidate=32' \
        "$temporary_directory/subgroup.txt" &&
    ! grep -q 'isa_changed' "$temporary_directory/subgroup.txt"; then
    report 0 refuses_differing_subgroup_size
else
    report 1 refuses_differing_subgroup_size
    cat "$temporary_directory/subgroup.txt" >&2
fi

# --spirv-only receipts write no NIR and no ISA digest, and read_field prints
# `-` for both, which compares equal and would otherwise report that NIR
# canonicalized a difference no NIR was ever captured for.
spirv_only_control=$temporary_directory/spirv-only-control
spirv_only_candidate=$temporary_directory/spirv-only-candidate
write_receipt "$spirv_only_control" aaaa - - 64 5
write_receipt "$spirv_only_candidate" dddd - - 64 5
spirv_only_status=0
"$differ" "$spirv_only_control" "$spirv_only_candidate" \
    >"$temporary_directory/spirv-only.txt" 2>&1 || spirv_only_status=$?
if [ "$spirv_only_status" -eq 1 ] &&
    grep -q 'receipt carries no nir_sha256' "$temporary_directory/spirv-only.txt" &&
    grep -q 'receipt carries no isa_sha256' "$temporary_directory/spirv-only.txt" &&
    ! grep -q 'nir_canonicalized' "$temporary_directory/spirv-only.txt"; then
    report 0 refuses_receipts_without_nir_or_isa
else
    report 1 refuses_receipts_without_nir_or_isa
    cat "$temporary_directory/spirv-only.txt" >&2
fi

if [ "$failures" -ne 0 ]; then
    printf 'receipt_diff_tests=failed failures=%s\n' "$failures" >&2
    exit 1
fi
printf 'receipt_diff_tests=passed\n'
