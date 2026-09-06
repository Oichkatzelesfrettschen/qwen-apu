#!/bin/sh
set -eu

# q8-mat-vec-receipt.sh is the argument surface of a two-arm comparison whose
# only difference is specialization constant 1, so this test reads the argv it
# hands lab.sh rather than any receipt lab.sh would write. A fake lab.sh records
# its own arguments, which makes the check run on a host with no Vulkan device
# and no SPIR-V toolchain: the question is which constants the script forwards,
# and that is decided before any driver is reached.

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
work_directory=$(mktemp -d)
trap 'rm -rf "$work_directory"' EXIT HUP INT TERM

checks=0
report() {
    checks=$((checks + 1))
    printf 'check_%02d %s=%s\n' "$checks" "$1" "$2"
    [ "$2" = accepted ] || exit 1
}

# The harness holds the script under test beside a lab.sh that records and a
# depth.py that answers, so the run reaches the argument construction and stops
# there.
harness=$work_directory/harness
mkdir -p "$harness"
cp "$script_directory/raven2-shader-lab/q8-mat-vec-receipt.sh" "$harness/"
cat >"$harness/lab.sh" <<'EOF'
#!/bin/sh
set -eu
printf '%s\n' "$*" >>"$LAB_ARGUMENT_RECORD"
variant_out=$2
mkdir -p "$variant_out"
printf 'fake receipt\n' >"$variant_out/receipt.tsv"
EOF
chmod +x "$harness/lab.sh"
cat >"$harness/depth.py" <<'EOF'
import sys
open(sys.argv[2], "w").write("fake depth\n")
EOF
receipt=$harness/q8-mat-vec-receipt.sh

spv_directory=$work_directory/spv
mkdir -p "$spv_directory"
for variant in mul_mat_vec_q8_0_f32_f32 mul_mat_vec_q8_0_f32_f32_subgroup; do
    printf 'not really spirv\n' >"$spv_directory/$variant.spv"
done

run_receipt() {
    run_out=$1
    shift
    LAB_ARGUMENT_RECORD=$work_directory/lab-arguments \
        "$receipt" "$spv_directory" "$run_out" "$@"
}

# The served arm is the default, so a caller naming no row count measures the
# geometry ggml-vulkan.cpp builds.
: >"$work_directory/lab-arguments"
outcome=accepted
run_receipt "$work_directory/default" --allow-device --subgroup-only \
    >/dev/null 2>&1 || outcome=refused
if [ "$outcome" = accepted ]; then
    grep -q -- '--spec 1:2' "$work_directory/lab-arguments" ||
        outcome=served_rows_absent
    grep -q -- '--spec 0:64' "$work_directory/lab-arguments" ||
        outcome=block_size_absent
    grep -q -- '--spec 2:1' "$work_directory/lab-arguments" ||
        outcome=columns_absent
fi
report default_forwards_the_served_row_count "$outcome"

# The candidate arm is the one the kernel-delta design registers, and it reaches
# lab.sh as the same argument at another value.
: >"$work_directory/lab-arguments"
outcome=accepted
run_receipt "$work_directory/candidate" --allow-device --subgroup-only \
    --num-rows 4 >/dev/null 2>&1 || outcome=refused
if [ "$outcome" = accepted ]; then
    grep -q -- '--spec 1:4' "$work_directory/lab-arguments" ||
        outcome=candidate_rows_absent
    grep -q -- '--spec 1:2' "$work_directory/lab-arguments" &&
        outcome=served_rows_also_forwarded
fi
report candidate_forwards_its_own_row_count "$outcome"

# Specialization constant 1 reaches the compiler at pipeline creation, so a
# spirv-only run at another row count would write the served receipt under a
# candidate's name. It is refused rather than retained.
outcome=refused
if run_receipt "$work_directory/spirv-candidate" --num-rows 4 \
    >/dev/null 2>"$work_directory/spirv-candidate.err"; then
    outcome=admitted
elif grep -q 'reaches the compiler at pipeline creation alone' \
    "$work_directory/spirv-candidate.err"; then
    outcome=accepted
else
    outcome=wrong_reason
    cat "$work_directory/spirv-candidate.err" >&2
fi
report spirv_only_candidate_refused "$outcome"

# The served count under --spirv-only stays admitted, since that layer closes
# module identity and states no row count of its own.
outcome=accepted
run_receipt "$work_directory/spirv-default" --num-rows 2 \
    >/dev/null 2>&1 || outcome=refused
report spirv_only_served_count_admitted "$outcome"

# A row count that is not a positive decimal integer is an argument error rather
# than a value forwarded into a specialization.
for bad_value in 0 -1 2.5 four '' 04; do
    outcome=refused
    if run_receipt "$work_directory/bad-$$-$checks" --allow-device \
        --num-rows "$bad_value" >/dev/null 2>&1; then
        outcome=admitted
    else
        status=$?
        if [ "$status" -eq 2 ]; then
            outcome=accepted
        else
            outcome=wrong_status
        fi
    fi
    [ "$outcome" = accepted ] || {
        printf 'the row count %s produced %s\n' "$bad_value" "$outcome" >&2
        break
    }
done
report malformed_row_count_refused "$outcome"

# The retained directory states its own arm, because one SPIR-V module serves
# every row count and the order two runs were taken in is not a record.
outcome=accepted
[ -r "$work_directory/candidate/specialization.tsv" ] ||
    outcome=record_absent
if [ "$outcome" = accepted ]; then
    # A pattern opening on the `-` that marks a row outside the constant space
    # reads as a grep option, so every comparison passes it after --.
    grep -qx -- '1	NUM_ROWS	4' \
        "$work_directory/candidate/specialization.tsv" ||
        outcome=candidate_row_count_unstated
    grep -qx -- '-	specialization_applied	yes' \
        "$work_directory/candidate/specialization.tsv" ||
        outcome=device_layer_unstated
    grep -qx -- '1	NUM_ROWS	2' \
        "$work_directory/default/specialization.tsv" ||
        outcome=control_row_count_unstated
    grep -qx -- '-	specialization_applied	no' \
        "$work_directory/spirv-default/specialization.tsv" ||
        outcome=spirv_layer_unstated
fi
report retained_directory_states_its_arm "$outcome"

printf 'test-q8-mat-vec-receipt: all checks passed\n'
