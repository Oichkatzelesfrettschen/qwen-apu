#!/bin/sh
set -eu

# The E5 module-and-driver proof: one device arm that decides whether the
# measured executable consumes the OpSDotKHR module the pinned producer compiled
# and executes it through the isolated driver, before any activation-quantizer
# comparison spends a window.
#
# Two claims are separated because they fail for different reasons and stop the
# ladder at different rungs. Module identity is a claim about the SPIR-V the
# device compiled: llama-vulkan-pipeline-census.patch hashes the embedded module
# at pipeline creation as census_spirv_source_sha256, and
# evidence/raven2-vulkan-kernel-census/e5/E5-S0/shader-pack/shader-pack.tsv
# states the digest the pinned glslc wrote for the same source and defines, so
# equality proves the served binary carries the packed-dot module rather than the
# distribution toolchain's fallback. ACO lowering is a claim about what the
# driver made of that module: recount-isa.sh over the RADV disassembly names 224
# v_mul_i32_i24 products in every E5-S arm and separates merge request 2115's 140
# v_add3_u32 from the generic expansion's 98, and every retained E5-S receipt was
# measured on a drm-shimmed workstation node, so the appliance's own answer is
# the open question this arm closes.
#
# The census runner is the wrong instrument here. Its attribution mode requires
# QWEN_CENSUS_CALIBRATION_RECEIPT naming an accepted calibration that bound the
# same two server digests, and an E5 binary is a new pair, so the receipt would
# have to be produced by a thirteen-arm calibration run first. This arm needs one
# server process and one completion, which dump-radv-shader-isa.sh already owns:
# it launches through radv-low-priority-env.sh under low-async, reintroduces
# RADV_DEBUG past the scrub, drives one eight-token completion at temperature 0,
# and splits the disassembly per shader. GGML_VK_FORCE_INTEGER_DOT reaches it
# directly and QWEN_PIPELINE_CENSUS crosses the profile scrub on its own name, so
# both arm the run through this script's exported environment and neither
# collector changes.
#
# A refuted identity ends the rung as a completed negative with exit 3 and a
# terminal-state.tsv naming the field that moved. It never falls through to a
# served comparison, because a rate measured against a module the device did not
# execute attributes the difference to the wrong cause.
#
# usage: run-e5-module-proof.sh OUTPUT_DIR SERVER MODEL_PATH RADV_PREFIX
#   OUTPUT_DIR   an absent directory the arm writes its whole record into
#   SERVER       the E5 binary remote/build-llama-e5.sh produced
#   MODEL_PATH   the Q4_K checkpoint whose trunk the q8_1 mat-vec serves
#   RADV_PREFIX  the isolated RADV prefix remote/build-isolated-radv.sh created

usage() {
    printf 'usage: %s OUTPUT_DIR SERVER MODEL_PATH RADV_PREFIX\n' "$0" >&2
    exit 2
}

if [ "$#" -ne 4 ]; then
    usage
fi

output_directory=$1
server_executable=$2
model_path=$3
radv_prefix=$4

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
repository_root=$(CDPATH='' cd -- "$script_directory/.." && pwd)
# Both collectors are resolved beside this script; the overrides are the seam
# remote/test-run-e5-module-proof.sh drives every verdict through with no device.
isa_collector=${QWEN_E5_ISA_COLLECTOR:-$script_directory/dump-radv-shader-isa.sh}
isa_recounter=${QWEN_E5_ISA_RECOUNTER:-$script_directory/raven2-shader-lab/recount-isa.sh}
shader_pack_directory=${QWEN_E5_SHADER_PACK:-$repository_root/evidence/raven2-vulkan-kernel-census/e5/E5-S0/shader-pack}
instruction_census=${QWEN_E5_INSTRUCTION_CENSUS:-$repository_root/evidence/raven2-vulkan-kernel-census/e5/instruction-census.tsv}

e5_module_name=mul_mat_vec_q4_k_q8_1_f32_subgroup_no_shmem
e5_pipeline_prefix=mul_mat_vec_q4_k_q8_1

# A missing input is a setup error rather than a scientific negative, so it
# exits 2 and writes no terminal state: filing it as completed-negative would
# retire the rung on a mistake.
for required_program in awk sed sha256sum python3; do
    if ! command -v "$required_program" >/dev/null 2>&1; then
        printf 'the proof requires %s\n' "$required_program" >&2
        exit 2
    fi
done
for required_input in "$isa_collector" "$isa_recounter"; do
    if [ ! -x "$required_input" ]; then
        printf 'collector is not executable: %s\n' "$required_input" >&2
        exit 2
    fi
done
if [ ! -x "$server_executable" ] || [ -d "$server_executable" ]; then
    printf 'server is not an executable file: %s\n' "$server_executable" >&2
    exit 2
fi
if [ ! -r "$model_path" ] || [ -d "$model_path" ]; then
    printf 'model path is not a readable file: %s\n' "$model_path" >&2
    exit 2
fi
if [ -e "$output_directory" ]; then
    printf 'output directory already exists, refusing to overwrite: %s\n' \
        "$output_directory" >&2
    exit 2
fi
# The census patch refuses a relative GGML_VK_PIPELINE_CENSUS by throwing out of
# Vulkan initialization, so a relative output directory takes the server down
# before /health rather than producing a record. It is refused here, where the
# argument is still readable.
case $output_directory in
    /*) ;;
    *)
        printf 'the output directory is an absolute path, since the census refuses a relative one: %s\n' \
            "$output_directory" >&2
        exit 2
        ;;
esac

pack_ledger=$shader_pack_directory/shader-pack.tsv
pack_inputs=$shader_pack_directory/pack-inputs.tsv
dot_proof=$shader_pack_directory/dot-instruction-proof.tsv
for required_input in "$pack_ledger" "$pack_inputs" "$dot_proof" "$instruction_census"; do
    if [ ! -r "$required_input" ]; then
        printf 'the pinned record is unreadable: %s\n' "$required_input" >&2
        exit 2
    fi
done

read_key_value() {
    awk -F'\t' -v key="$1" '$1 == key { print $2; found = 1 }
        END { exit found ? 0 : 1 }' "$2"
}

# The expected module comes out of the pack ledger rather than out of this
# script, so a pack regenerated under a later pin moves the expectation with it.
expected_module_sha256=$(awk -F'\t' -v name="$e5_module_name" \
    '$1 == name { print $8; found = 1 } END { exit found ? 0 : 1 }' "$pack_ledger") || {
    printf 'the shader pack ledger names no %s module\n' "$e5_module_name" >&2
    exit 2
}
expected_module_bytes=$(awk -F'\t' -v name="$e5_module_name" \
    '$1 == name { print $7 }' "$pack_ledger")
pack_glslc_version=$(read_key_value glslc_version "$pack_inputs" || printf -)
pack_declaration_sha256=$(read_key_value declaration_sha256 "$pack_inputs" || printf -)
pack_spirv_dis=$(read_key_value spirv_dis "$dot_proof" || printf -)
pack_opsdot_packed=$(read_key_value opsdot_packed_4x8 "$dot_proof" || printf -)

# The two ACO expectations are read from the retained receipts for the same
# reason: merge request 2115's lowering is what E5-S1 measured and the generic
# expansion is what E5-S0 measured, and both counts belong to those records.
census_field() {
    awk -F'\t' -v want="$1" -v field="$2" '
        NR == 1 { for (i = 1; i <= NF; i++) column[$i] = i; next }
        index($1, want) { print $(column[field]); found = 1; exit }
        END { exit found ? 0 : 1 }' "$instruction_census"
}
expected_mul24=$(census_field /E5-S1/ v_mul_i32_i24) || {
    printf 'the instruction census names no E5-S1 row\n' >&2
    exit 2
}
expected_add3_mr2115=$(census_field /E5-S1/ v_add3_u32)
expected_add3_generic=$(census_field /E5-S0/ v_add3_u32) || {
    printf 'the instruction census names no E5-S0 row\n' >&2
    exit 2
}

# The isolated driver is named by its own build receipt and reached through the
# ICD that receipt's environment fragment exports. The ICD's library_path is
# required to sit inside the named prefix, because a devenv json pointing at the
# system driver would serve the system driver under this prefix's name.
radv_receipt=$radv_prefix/radv-build.tsv
radv_fragment=$radv_prefix/radv-experiment-env.sh
for required_input in "$radv_receipt" "$radv_fragment"; do
    if [ ! -r "$required_input" ]; then
        printf 'the isolated RADV prefix carries no %s\n' "$required_input" >&2
        exit 2
    fi
done
radv_schema=$(read_key_value schema "$radv_receipt" || printf -)
if [ "$radv_schema" != isolated-radv-v1 ]; then
    printf 'the RADV build receipt declares schema %s rather than isolated-radv-v1\n' \
        "$radv_schema" >&2
    exit 2
fi
radv_revision=$(read_key_value revision "$radv_receipt")
radv_lowering_merge=$(read_key_value lowering_merge "$radv_receipt" || printf -)
radv_icd=$(sed -n 's/^QWEN_RADV_ICD=//p' "$radv_fragment" | head -n 1)
if [ -z "$radv_icd" ] || [ ! -r "$radv_icd" ]; then
    printf 'the environment fragment names no readable ICD: %s\n' "${radv_icd:--}" >&2
    exit 2
fi
radv_library=$(sed -n 's/.*"library_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' \
    "$radv_icd" | head -n 1)
if [ ! -r "$radv_library" ]; then
    printf 'the ICD names no readable driver library: %s\n' "${radv_library:--}" >&2
    exit 2
fi
case $radv_library in
    "$radv_prefix"/*) ;;
    *)
        printf 'the ICD library %s lies outside the prefix %s, so it is not the isolated driver\n' \
            "$radv_library" "$radv_prefix" >&2
        exit 2
        ;;
esac

mkdir -p -- "$output_directory"
census_path=$output_directory/pipeline-census.tsv
inputs_record=$output_directory/inputs.tsv
terminal_state=$output_directory/terminal-state.tsv

runtime_tree_state=not_run:check_absent
runtime_tree_checker=$script_directory/check-runtime-tree.sh
if [ -x "$runtime_tree_checker" ]; then
    runtime_tree_state=recomputed
    "$runtime_tree_checker" "$repository_root" >"$output_directory/runtime-tree.log" 2>&1 ||
        runtime_tree_state=refused
fi

{
    printf 'key\tvalue\n'
    printf 'schema\te5-module-proof-v1\n'
    printf 'server\t%s\n' "$server_executable"
    printf 'server_sha256\t%s\n' "$(sha256sum "$server_executable" | cut -d ' ' -f 1)"
    printf 'server_bytes\t%s\n' "$(wc -c <"$server_executable" | tr -d ' ')"
    printf 'model\t%s\n' "$model_path"
    printf 'model_sha256\t%s\n' "$(sha256sum "$model_path" | cut -d ' ' -f 1)"
    printf 'model_bytes\t%s\n' "$(wc -c <"$model_path" | tr -d ' ')"
    printf 'force_integer_dot\t1\n'
    printf 'radv_prefix\t%s\n' "$radv_prefix"
    printf 'radv_revision\t%s\n' "$radv_revision"
    printf 'radv_lowering_merge\t%s\n' "$radv_lowering_merge"
    printf 'radv_icd\t%s\n' "$radv_icd"
    printf 'radv_icd_sha256\t%s\n' "$(sha256sum "$radv_icd" | cut -d ' ' -f 1)"
    printf 'radv_library\t%s\n' "$radv_library"
    printf 'radv_library_sha256\t%s\n' "$(sha256sum "$radv_library" | cut -d ' ' -f 1)"
    printf 'shader_pack\t%s\n' "$shader_pack_directory"
    printf 'pack_module_name\t%s\n' "$e5_module_name"
    printf 'pack_module_sha256\t%s\n' "$expected_module_sha256"
    printf 'pack_module_bytes\t%s\n' "$expected_module_bytes"
    printf 'pack_glslc_version\t%s\n' "$pack_glslc_version"
    printf 'pack_declaration_sha256\t%s\n' "$pack_declaration_sha256"
    printf 'pack_spirv_dis\t%s\n' "$pack_spirv_dis"
    printf 'pack_opsdot_packed_4x8\t%s\n' "$pack_opsdot_packed"
    printf 'expected_v_mul_i32_i24\t%s\n' "$expected_mul24"
    printf 'expected_v_add3_u32_mr2115\t%s\n' "$expected_add3_mr2115"
    printf 'expected_v_add3_u32_generic\t%s\n' "$expected_add3_generic"
    printf 'runtime_tree\t%s\n' "$runtime_tree_state"
    printf 'runtime_tree_head\t%s\n' \
        "$(git -C "$repository_root" rev-parse HEAD 2>/dev/null || printf -)"
} >"$inputs_record"

# The verdict is written once, from one place, so a refusal and an acceptance
# carry the same fields and a reader never has to guess which arm produced which
# shape.
emit_terminal_state() {
    {
        printf 'key\tvalue\n'
        printf 'schema\te5-module-proof-terminal-v1\n'
        printf 'state\t%s\n' "$1"
        printf 'field\t%s\n' "$2"
        printf 'expected\t%s\n' "$3"
        printf 'observed\t%s\n' "$4"
    } >"$terminal_state"
}

refute() {
    emit_terminal_state completed-negative "$1" "$2" "$3"
    printf 'e5_module_proof module_identity=refuted aco_lowering=%s field=%s expected=%s observed=%s inputs=%s\n' \
        "${4:-not_read}" "$1" "$2" "$3" "$inputs_record"
    exit 3
}

# One launch supplies both claims. QWEN_PIPELINE_CENSUS crosses the low-async
# scrub inside radv-low-priority-env.sh and reaches the server as
# GGML_VK_PIPELINE_CENSUS; GGML_VK_FORCE_INTEGER_DOT is read by the collector
# itself and forwarded past the same scrub; QWEN_RADV_ICD selects the isolated
# driver for the loader.
# The fragment build-isolated-radv.sh wrote carries three names and this arm
# takes two of them. LD_LIBRARY_PATH covers the LLVM the -Dllvm=enabled driver
# links beside itself, which the disassembler needs and the appliance's system
# prefix does not carry. QWEN_AMDGPU_DRM_SHIM stays out: the shim environment
# turns it into an LD_PRELOAD that fakes a RAVEN2 node, which is how the
# workstation receipts were taken, and a proof run against a faked device would
# read proven while measuring nothing about this silicon. The fragment is
# therefore read by name rather than sourced.
# shellcheck disable=SC2016  # the fragment's own literal text is the pattern
radv_library_path=$(sed -n 's/^LD_LIBRARY_PATH=\([^$]*\)\${LD_LIBRARY_PATH.*/\1/p' \
    "$radv_fragment" | head -n 1)
collection_status=0
LD_LIBRARY_PATH=${radv_library_path}${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH} \
QWEN_RADV_ICD=$radv_icd \
QWEN_PIPELINE_CENSUS=$census_path \
GGML_VK_FORCE_INTEGER_DOT=1 \
    "$isa_collector" "$output_directory/isa-dump" "$server_executable" "$model_path" \
    >"$output_directory/collector.log" 2>&1 || collection_status=$?
if [ "$collection_status" -ne 0 ]; then
    printf 'the ISA and census collection failed with status %s\n' "$collection_status" >&2
    tail -n 40 "$output_directory/collector.log" >&2
    exit 1
fi

if [ ! -r "$census_path" ]; then
    printf 'the run wrote no pipeline census at %s\n' "$census_path" >&2
    exit 1
fi

# census_pipeline rows carry the census-local id, the pipeline name, the entry
# point, then the embedded module's digest and byte count, then the digest and
# byte count of the bytes handed to vkCreateShaderModule after the FP16
# float-control rewrite. The pack states the compiler's own output, so the
# comparison is against the source digest and the executed digest is recorded
# beside it.
#
# ggml_vk_load_shaders creates several pipelines under this prefix -- the
# accumulator and subgroup variants of one family -- and the pack declares the
# one module their shared source and defines compile to. The proof therefore
# accepts where any created pipeline of the family carries the pack's digest and
# byte count and refutes only where none does, since reading the first row alone
# would refute the rung on the creation order of a variant the pack never
# declared, and this stop rule closes the candidate.
family_rows=$output_directory/family-pipelines.tsv
awk -F'\t' -v prefix="$e5_pipeline_prefix" '
    BEGIN { print "pipeline_name\tmodule_sha256\tmodule_bytes\texecuted_sha256" }
    $1 == "census_pipeline" && index($3, prefix) == 1 {
        print $3 "\t" $5 "\t" $6 "\t" $7 }' "$census_path" >"$family_rows"
family_count=$(awk 'NR > 1' "$family_rows" | wc -l | tr -d ' ')
if [ "$family_count" -eq 0 ]; then
    refute pipeline_created "$e5_pipeline_prefix" absent
fi

matched_row=$(awk -F'\t' -v want="$expected_module_sha256" -v bytes="$expected_module_bytes" '
    NR > 1 && $2 == want && $3 == bytes { print; exit }' "$family_rows")
if [ -z "$matched_row" ]; then
    observed_module_sha256=$(awk -F'\t' 'NR == 2 { print $2 }' "$family_rows")
    refute module_sha256 "$expected_module_sha256" "${observed_module_sha256:--}"
fi
observed_pipeline_name=$(printf '%s' "$matched_row" | cut -f 1)
observed_module_sha256=$(printf '%s' "$matched_row" | cut -f 2)
observed_module_bytes=$(printf '%s' "$matched_row" | cut -f 3)
observed_executed_sha256=$(printf '%s' "$matched_row" | cut -f 4)

# The disassembly carries one block per compiled shader under RADV's own stage
# name, so the q8_1 mat-vec is selected by what it is rather than by what it is
# called: the 224 24-bit signed products the expansion produces are the handle.
# Uniqueness of that handle is recorded rather than assumed, since the family's
# own second reduction variant expands the same products.
recount_record=$output_directory/isa-recount.tsv
set -- "$output_directory"/isa-dump/isa/*.s
if [ ! -r "$1" ]; then
    printf 'the collection retained no ISA listing under %s\n' \
        "$output_directory/isa-dump/isa" >&2
    exit 1
fi
"$isa_recounter" "$@" >"$recount_record"

aco_row=$(awk -F'\t' -v mul24="$expected_mul24" '
    NR == 1 { for (i = 1; i <= NF; i++) column[$i] = i; next }
    $(column["v_mul_i32_i24"]) == mul24 {
        print $(column["isa_path"]) "\t" $(column["isa_sha256"]) "\t" \
            $(column["v_add3_u32"]) "\t" $(column["v_mul_lo_u32"]);
        exit
    }' "$recount_record")
# RADV names every compute shader "Compute Shader" in its own dump, so
# summarize-radv-isa.py derives isa-index.tsv from content alone and this
# selection is by expansion shape rather than by pipeline name. The family
# creates a second q8_1 module for DMMV_WG_SIZE_LARGE whose reduction differs
# while its 224 products do not, so the match is not proven unique and the row
# a first match returns follows compile order. The candidate count and the
# reductions those candidates agree on are therefore recorded: a single
# candidate reads its own lowering, several agreeing candidates read that one
# lowering, and several disagreeing candidates read `ambiguous`, since the
# reduction the arm executed is undetermined by a listing that carries no name.
aco_candidate_rows=$(awk -F'\t' -v mul24="$expected_mul24" '
    NR == 1 { for (i = 1; i <= NF; i++) column[$i] = i; next }
    $(column["v_mul_i32_i24"]) == mul24 { rows++ }
    END { print rows + 0 }' "$recount_record")
aco_candidate_add3=$(awk -F'\t' -v mul24="$expected_mul24" '
    NR == 1 { for (i = 1; i <= NF; i++) column[$i] = i; next }
    $(column["v_mul_i32_i24"]) == mul24 { seen[$(column["v_add3_u32"])] = 1 }
    END { for (value in seen) distinct++; print distinct + 0 }' "$recount_record")
if [ -z "$aco_row" ]; then
    observed_mul24=$(awk -F'\t' '
        NR == 1 { for (i = 1; i <= NF; i++) column[$i] = i; next }
        { if ($(column["v_mul_i32_i24"]) + 0 > peak) peak = $(column["v_mul_i32_i24"]) + 0 }
        END { print peak + 0 }' "$recount_record")
    refute aco_dot_expansion "$expected_mul24" "$observed_mul24"
fi
aco_isa_path=$(printf '%s' "$aco_row" | cut -f 1)
aco_isa_sha256=$(printf '%s' "$aco_row" | cut -f 2)
aco_add3=$(printf '%s' "$aco_row" | cut -f 3)
# The ladder's falsifier 1 names v_mul_lo_u32 in the inner loop as its own
# clause, so the quarter-rate multiply is selected on nothing and reported as
# itself rather than folded into the row that finds the expansion.
aco_mul_lo=$(printf '%s' "$aco_row" | cut -f 4)

case $aco_add3 in
    "$expected_add3_mr2115") aco_lowering=mr2115 ;;
    "$expected_add3_generic") aco_lowering=generic ;;
    *) aco_lowering=other ;;
esac
if [ "$aco_candidate_add3" -gt 1 ]; then
    aco_lowering=ambiguous
fi

{
    printf 'key\tvalue\n'
    printf 'schema\te5-module-proof-verdict-v1\n'
    printf 'module_identity\tproven\n'
    printf 'pipeline_name\t%s\n' "$observed_pipeline_name"
    printf 'module_sha256\t%s\n' "$observed_module_sha256"
    printf 'module_bytes\t%s\n' "$observed_module_bytes"
    printf 'executed_sha256\t%s\n' "$observed_executed_sha256"
    printf 'aco_lowering\t%s\n' "$aco_lowering"
    printf 'aco_isa_path\t%s\n' "$aco_isa_path"
    printf 'aco_isa_sha256\t%s\n' "$aco_isa_sha256"
    printf 'aco_v_add3_u32\t%s\n' "$aco_add3"
    printf 'aco_v_mul_i32_i24\t%s\n' "$expected_mul24"
    printf 'aco_v_mul_lo_u32\t%s\n' "$aco_mul_lo"
    printf 'family_pipeline_count\t%s\n' "$family_count"
    printf 'aco_candidate_rows\t%s\n' "$aco_candidate_rows"
    printf 'aco_candidate_reductions\t%s\n' "$aco_candidate_add3"
} >"$output_directory/verdict.tsv"

# The module is proven and the lowering is recorded rather than gated: merge
# request 2115's sequence is what E5-S1 predicts, the generic expansion is what a
# driver without the merge produces, and any third answer is the appliance's own
# ACO differing from every workstation receipt. Each of the three is a result
# that the next rung reads, so none of them refutes module identity.
emit_terminal_state accepted aco_lowering \
    "$expected_add3_mr2115" "$aco_add3"
printf 'e5_module_proof module_identity=proven aco_lowering=%s v_mul_lo_u32=%s module_sha256=%s executed_sha256=%s isa_sha256=%s inputs=%s\n' \
    "$aco_lowering" "$aco_mul_lo" "$observed_module_sha256" "$observed_executed_sha256" \
    "$aco_isa_sha256" "$inputs_record"
