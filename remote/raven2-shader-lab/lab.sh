#!/bin/sh
set -eu

# One compute pipeline, every compiler layer it passes through, retained as
# files under one output directory. E1 in
# evidence/raven2-vulkan-kernel-census/decode-decomposition.md needs the
# instruction inventory of the pinned mat-vec kernels in place of the
# 77-operation estimate that document derives from GLSL, and E2, E2b, E3, and
# E4 each read the same five outputs over a different shader, so the ladder is
# one script rather than one script per experiment.
#
# The layers are GLSL -> SPIR-V -> NIR -> ACO -> ISA. spirv-dis reads the
# module as the caller supplies it, and the other three come out of one
# vkCreateComputePipelines call: mesa-25.3.2
# src/amd/vulkan/radv_pipeline_compute.c prints the final NIR handed to ACO
# with nir_print_shader when RADV_DEBUG carries the nir bit, ACO's
# aco_print_program writes its own IR under the ir bit, and
# src/amd/vulkan/radv_shader.c:3282 writes the "disasm:" block under the asm
# bit. RADV_DEBUG=shaders is the union of all three plus every stage
# (src/amd/vulkan/radv_debug.h:79), so the nir member below states what
# shaders already implies and costs a reader nothing to verify.
#
# The whole per-pipeline sequence runs inside instance->shader_dump_mtx, which
# is what keeps one pipeline's four dumps contiguous in the stream; this lab
# creates exactly one pipeline per run and refuses a log carrying more than one
# block of any kind, so the extraction never pairs one shader's NIR with
# another's ISA.

usage() {
    printf 'usage: %s SPV OUT_DIR [--spec ID:UINT]... [--subgroup N]\n' "$0" >&2
    printf '%s\n' "           [--bindings N] [--push-constants BYTES] [--device-index N]" >&2
    printf '%s\n' "           [--per-superblock N] [--spirv-only]" >&2
}

if [ "$#" -lt 2 ]; then
    usage
    exit 2
fi

spirv_path=$1
output_directory=$2
shift 2

per_superblock_divisor=-
spirv_only=0
harness_arguments=''
while [ "$#" -gt 0 ]; do
    case $1 in
    --per-superblock)
        if [ "$#" -lt 2 ]; then
            usage
            exit 2
        fi
        per_superblock_divisor=$2
        shift 2
        ;;
    --spirv-only)
        spirv_only=1
        shift
        ;;
    --spec | --subgroup | --bindings | --push-constants | --device-index)
        if [ "$#" -lt 2 ]; then
            usage
            exit 2
        fi
        harness_arguments="$harness_arguments $1 $2"
        shift 2
        ;;
    *)
        printf 'unknown option: %s\n' "$1" >&2
        usage
        exit 2
        ;;
    esac
done

if [ "$per_superblock_divisor" != - ]; then
    case $per_superblock_divisor in
    '' | *[!0-9]*)
        printf '%s\n' "--per-superblock takes a positive decimal integer: $per_superblock_divisor" >&2
        exit 2
        ;;
    esac
    if [ "$per_superblock_divisor" -le 0 ]; then
        printf '%s\n' "--per-superblock takes a positive decimal integer: $per_superblock_divisor" >&2
        exit 2
    fi
fi

if [ ! -r "$spirv_path" ] || [ -d "$spirv_path" ]; then
    printf 'SPIR-V module is not a readable file: %s\n' "$spirv_path" >&2
    exit 1
fi
if [ -e "$output_directory" ]; then
    printf 'output directory already exists, refusing to overwrite: %s\n' "$output_directory" >&2
    exit 1
fi
for required_tool in spirv-dis sha256sum awk cc; do
    if ! command -v "$required_tool" >/dev/null 2>&1; then
        printf '%s is required\n' "$required_tool" >&2
        exit 1
    fi
done

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
mkdir -p -- "$output_directory"

spirv_disassembly=$output_directory/spirv.dis
nir_text=$output_directory/final.nir
isa_text=$output_directory/isa.s
stats_table=$output_directory/stats.tsv
receipt_table=$output_directory/receipt.tsv
debug_log=$output_directory/radv-debug.log
harness_log=$output_directory/harness.txt
raw_stats=$output_directory/shaderstats.txt

spirv-dis "$spirv_path" >"$spirv_disassembly"
spirv_sha256=$(sha256sum <"$spirv_path" | cut -d' ' -f1)
spirv_bytes=$(wc -c <"$spirv_path" | tr -d ' ')

nir_sha256=-
isa_sha256=-
run_mode=spirv-only
replay_directory=${QWEN_SHADER_LAB_REPLAY_DIR:-}
: >"$harness_log"

if [ "$spirv_only" -eq 0 ]; then
    if [ -n "$replay_directory" ]; then
        # A recorded pair of streams stands in for the device, which is what
        # lets the extraction, the statistic reader, and the receipt writer be
        # exercised on a host carrying no RADV part. The stage the recording
        # replaces is the pipeline creation and nothing after it.
        run_mode=replay
        for replayed_file in radv-debug.log harness.txt; do
            if [ ! -r "$replay_directory/$replayed_file" ]; then
                printf 'replay directory is missing %s: %s\n' "$replayed_file" "$replay_directory" >&2
                exit 1
            fi
        done
        cat -- "$replay_directory/radv-debug.log" >"$debug_log"
        cat -- "$replay_directory/harness.txt" >"$harness_log"
    else
        run_mode=device
        harness_executable=$output_directory/shader-lab
        cc -O2 -Wall -Wextra "$script_directory/shader-lab.c" -lvulkan -o "$harness_executable"

        # An ambient RADV_DEBUG, RADV_PERFTEST, or Vulkan layer name changes
        # which passes run and what the driver prints, and a receipt compared
        # against another host's receipt reads that difference as a source
        # difference. remote/radv-low-priority-env.sh is the scrub that removes
        # it, under the low-async serving profile; it unsets RADV_DEBUG among
        # the rest, so `env` reintroduces the one setting this harness needs
        # after the scrub and ahead of pipeline creation.
        set +e
        # shellcheck disable=SC2086
        env QWEN_VULKAN_PROFILE=low-async "$script_directory/../radv-low-priority-env.sh" \
            env RADV_DEBUG=shaders,shaderstats,nir \
            "$harness_executable" "$spirv_path" $harness_arguments \
            >"$harness_log" 2>"$debug_log"
        harness_status=$?
        set -e
        if [ "$harness_status" -ne 0 ]; then
            printf 'pipeline creation failed with status %s; see %s and %s\n' \
                "$harness_status" "$harness_log" "$debug_log" >&2
            exit 1
        fi
        # The receipt carries the driver-facing names that survived the scrub,
        # so a reader compares two receipts on what the driver was told rather
        # than trusting that neither host had an ambient setting. The same
        # wrapper and profile answer, so the list is the run's own.
        surviving_names=$(env QWEN_VULKAN_PROFILE=low-async \
            "$script_directory/../radv-low-priority-env.sh" \
            env RADV_DEBUG=shaders,shaderstats,nir sh -c \
            'env | sed -n "s/^\(RADV_[A-Za-z0-9_]*\|VK_[A-Za-z0-9_]*\|MESA_[A-Za-z0-9_]*\|GGML_VK_[A-Za-z0-9_]*\)=.*/\1/p" | sort | tr "\n" "," | sed "s/,$//"')
        printf 'environment_names=%s\n' "${surviving_names:--}" >>"$harness_log"
    fi

    # The disassembly block opens on a stage-name line immediately followed
    # by a literal "disasm:" line and closes where the shaderstats block for
    # the same pipeline opens, or at end of stream where shaderstats is
    # absent. Anchoring the close on the stats marker rather than on the next
    # disasm header is what keeps the following pipeline's NIR and ACO dumps
    # out of the ISA under the shaders union.
    awk -v nir_file="$nir_text" -v isa_file="$isa_text" -v stats_file="$raw_stats" '
        { line[NR] = $0 }
        END {
            total = NR
            nir_blocks = 0
            isa_blocks = 0
            stats_blocks = 0
            for (i = 1; i <= total; i++) {
                if (line[i] ~ /^shader: MESA_SHADER_/) {
                    nir_blocks++
                    for (j = i; j <= total; j++) {
                        if (j > i && (line[j] ~ /^After (Instruction Selection|Spilling|RA|lowering)/ ||
                                      (j < total && line[j + 1] == "disasm:"))) {
                            break
                        }
                        if (nir_blocks == 1) print line[j] > nir_file
                    }
                    i = j - 1
                    continue
                }
                if (line[i] == "disasm:" && i > 1 && line[i - 1] != "") {
                    isa_blocks++
                    last = total
                    for (j = i + 1; j <= total; j++) {
                        if (line[j] == "*** SHADER STATS ***") { last = j - 1; break }
                    }
                    while (last > i && (line[last] == "" || line[last] ~ /:$/)) last--
                    if (isa_blocks == 1) {
                        for (j = i + 1; j <= last; j++) print line[j] > isa_file
                    }
                    i = last
                    continue
                }
                if (line[i] == "*** SHADER STATS ***") {
                    stats_blocks++
                    for (j = i + 1; j <= total && line[j] !~ /^\*{20}$/; j++) {
                        if (stats_blocks == 1) print line[j] > stats_file
                    }
                    i = j
                    continue
                }
            }
            printf "nir_blocks=%d isa_blocks=%d stats_blocks=%d\n", nir_blocks, isa_blocks, stats_blocks
        }
    ' "$debug_log" >"$output_directory/block-counts.txt"

    # One pipeline is created, so more than one block of any kind means the
    # extraction is reading a stream this lab did not produce. A missing
    # statistics block leaves every stat field reading "-" instead:
    # radv_pipeline_capture_shader_stats in radv_pipeline.c:55 turns capture on
    # for RADV_DEBUG_DUMP_SHADER_STATS, so the block is expected, and a driver
    # that withheld it still leaves the disassembly and the NIR that E1 and
    # E1.5 are collected for.
    block_counts=$(cat "$output_directory/block-counts.txt")
    case $block_counts in
    'nir_blocks=1 isa_blocks=1 stats_blocks=1' | 'nir_blocks=1 isa_blocks=1 stats_blocks=0') : ;;
    *)
        printf 'this lab creates one pipeline and the log carries %s; extraction is refused\n' \
            "$block_counts" >&2
        exit 1
        ;;
    esac

    nir_sha256=$(sha256sum <"$nir_text" | cut -d' ' -f1)
    isa_sha256=$(sha256sum <"$isa_text" | cut -d' ' -f1)
fi

# The statistic names VK_KHR_pipeline_executable_properties reports come from
# a header Mesa generates at build time rather than from the source this tree
# reads, so a field is selected by lowercased substring and the retained
# shaderstats block carries the names verbatim beside it. "spilled" is tested
# ahead of the bare register substrings so a spill count never lands in the
# allocation field.
{
    printf 'field\tvalue\tstat_name\n'
    if [ -r "$raw_stats" ]; then
        awk -F': *' '
            NF >= 2 {
                name = $1
                value = $2
                lowered = tolower(name)
                match(value, /-?[0-9]+/)
                number = RSTART ? substr(value, RSTART, RLENGTH) : value
                if (lowered ~ /spilled/ && lowered ~ /vgpr/) { emit("spilled_vgprs", number, name); next }
                if (lowered ~ /spilled/ && lowered ~ /sgpr/) { emit("spilled_sgprs", number, name); next }
                if (lowered ~ /vgpr/) { emit("vgprs", number, name); next }
                if (lowered ~ /sgpr/) { emit("sgprs", number, name); next }
                if (lowered ~ /lds/) { emit("lds", number, name); next }
                if (lowered ~ /scratch/) { emit("scratch", number, name); next }
                if (lowered ~ /code *size/) { emit("code_size", number, name); next }
                if (lowered ~ /wave/) { emit("waves_per_simd", number, name); next }
            }
            function emit(field, value, name) {
                if (field in seen) return
                seen[field] = 1
                printf "%s\t%s\t%s\n", field, value, name
            }
        ' "$raw_stats"
    fi
} >"$stats_table"

read_stat() {
    awk -F'\t' -v want="$1" '$1 == want { print $2; found = 1 } END { if (!found) print "-" }' "$stats_table"
}

# Instruction classes and the named gfx902 mechanisms
# decode-decomposition.md's own table turns on. A mnemonic is the line's first
# token after the trailing "; encoding" comment is removed; SDWA and DPP are
# counted by the operand modifiers the disassembler prints rather than by a
# mnemonic, since both ride on an ordinary VOP1 or VOP2 opcode. SMEM is a
# named subset of SALU rather than a sibling of it, so an s_load counts in
# both columns.
#
# v_alignbyte_b32, v_bfi_b32, and v_add_u32 join the list because the Q4_K
# scale decode's halfword selection is read from them: the two-byte-aligned
# scale pair reaches ACO as nir_op_alignbyte_amd from
# nir_lower_mem_access_bit_sizes, a bitfield-select formulation reaches it as
# v_bfi_b32, and the shift operand each alignbyte takes costs its own address
# add. evidence/q4k-scale-decode/ reads all three.
count_instruction_classes() {
    awk '
        {
            sub(/;.*$/, "")
            gsub(/^[ \t]+|[ \t]+$/, "")
            if ($0 == "" || $0 ~ /^[^ \t]+:$/) next
            mnemonic = $1
            total++
            if (mnemonic ~ /^v_/) valu++
            if (mnemonic ~ /^s_/ && mnemonic !~ /^s_waitcnt/ && mnemonic != "s_barrier" && mnemonic != "s_endpgm") salu++
            if (mnemonic ~ /^(buffer_|global_|flat_)/) vmem++
            if (mnemonic ~ /^(s_load|s_buffer_load)/) smem++
            if (mnemonic ~ /^ds_/) lds++
            if (mnemonic ~ /^s_waitcnt/) waitcnt++
            if (mnemonic == "s_barrier") barrier++
            if (mnemonic ~ /^v_cvt_f32_ubyte/) cvt_ubyte++
            if (mnemonic ~ /^v_bfe_/) bfe++
            if (mnemonic ~ /^v_lshrrev_b32/) lshrrev++
            if (mnemonic ~ /^v_lshlrev_b32/) lshlrev++
            if (mnemonic ~ /^v_and_b32/) and_b32++
            if (mnemonic ~ /^v_perm_b32/) perm_b32++
            if (mnemonic ~ /^v_alignbyte_b32/) alignbyte_b32++
            if (mnemonic ~ /^v_bfi_b32/) bfi_b32++
            if (mnemonic ~ /^v_add_u32/) add_u32++
            if (mnemonic ~ /^v_mul_lo_u32/) mul_lo_u32++
            if (mnemonic ~ /^v_mad_u32_u24/) mad_u32_u24++
            if (mnemonic ~ /^v_mad_i32_i24/) mad_i32_i24++
            if (mnemonic ~ /^v_mul_u32_u24/) mul_u32_u24++
            if (mnemonic ~ /^v_fma_f32/) fma_f32++
            if (mnemonic ~ /^v_mac_f32/) mac_f32++
            if (mnemonic ~ /^v_mad_mix_f32/) mad_mix_f32++
            if (mnemonic ~ /^v_pk_fma_f16/) pk_fma_f16++
            if (mnemonic ~ /^v_cvt_f32_f16/) cvt_f32_f16++
            if ($0 ~ /src[0-9]_sel:|dst_sel:/) sdwa++
            if ($0 ~ /row_shr|row_bcast|quad_perm|row_ror/) dpp++
        }
        END {
            printf "instruction_lines\t%d\n", total
            printf "valu\t%d\n", valu
            printf "salu\t%d\n", salu
            printf "vmem\t%d\n", vmem
            printf "smem\t%d\n", smem
            printf "lds_instructions\t%d\n", lds
            printf "waitcnt\t%d\n", waitcnt
            printf "barrier\t%d\n", barrier
            printf "v_cvt_f32_ubyte\t%d\n", cvt_ubyte
            printf "v_bfe\t%d\n", bfe
            printf "v_lshrrev_b32\t%d\n", lshrrev
            printf "v_lshlrev_b32\t%d\n", lshlrev
            printf "v_and_b32\t%d\n", and_b32
            printf "v_perm_b32\t%d\n", perm_b32
            printf "v_alignbyte_b32\t%d\n", alignbyte_b32
            printf "v_bfi_b32\t%d\n", bfi_b32
            printf "v_add_u32\t%d\n", add_u32
            printf "sdwa_operand_uses\t%d\n", sdwa
            printf "dpp_uses\t%d\n", dpp
            printf "v_mul_lo_u32\t%d\n", mul_lo_u32
            printf "v_mad_u32_u24\t%d\n", mad_u32_u24
            printf "v_mad_i32_i24\t%d\n", mad_i32_i24
            printf "v_mul_u32_u24\t%d\n", mul_u32_u24
            printf "v_fma_f32\t%d\n", fma_f32
            printf "v_mac_f32\t%d\n", mac_f32
            printf "v_mad_mix_f32\t%d\n", mad_mix_f32
            printf "v_pk_fma_f16\t%d\n", pk_fma_f16
            printf "v_cvt_f32_f16\t%d\n", cvt_f32_f16
        }
    ' "$1"
}

read_harness() {
    awk -F'=' -v want="$1" '$1 == want { sub(/^[^=]*=/, ""); print; found = 1 } END { if (!found) print "-" }' \
        "$harness_log"
}

counts_file=$output_directory/.instruction-counts.tsv
if [ "$spirv_only" -eq 0 ]; then
    count_instruction_classes "$isa_text" >"$counts_file"
else
    : >"$counts_file"
fi

{
    printf 'field\tvalue\tper_superblock\n'
    printf 'run_mode\t%s\t-\n' "$run_mode"
    printf 'spirv_path\t%s\t-\n' "$spirv_path"
    printf 'spirv_sha256\t%s\t-\n' "$spirv_sha256"
    printf 'spirv_bytes\t%s\t-\n' "$spirv_bytes"
    printf 'nir_sha256\t%s\t-\n' "$nir_sha256"
    printf 'isa_sha256\t%s\t-\n' "$isa_sha256"
    for harness_field in device_name driver_name driver_info device_api_version spirv_capabilities \
        features_enabled robust_buffer_access spec_constants bindings push_constant_bytes \
        subgroup_size_requested subgroup_size_min subgroup_size_max \
        environment_names; do
        printf '%s\t%s\t-\n' "$harness_field" "$(read_harness "$harness_field")"
    done
    # The divisor is an operator claim rather than a fact the ISA carries: the
    # inner loop's trip count arrives in push constants at run time
    # (p.ncols and num_blocks_per_row in mul_mat_vec_q4_k.comp), so the file
    # records who asked for the normalization beside the number it produces.
    printf 'per_superblock_divisor\t%s\t-\n' "$per_superblock_divisor"
    for stat_field in vgprs sgprs spilled_vgprs spilled_sgprs lds scratch code_size waves_per_simd; do
        printf '%s\t%s\t-\n' "$stat_field" "$(read_stat "$stat_field")"
    done
    awk -F'\t' -v divisor="$per_superblock_divisor" '
        {
            if (divisor == "-") normalized = "-"
            else normalized = sprintf("%.4f", $2 / divisor)
            printf "%s\t%s\t%s\n", $1, $2, normalized
        }
    ' "$counts_file"
} >"$receipt_table"

rm -f -- "$counts_file"

printf 'shader_lab=complete spirv=%s nir=%s isa=%s receipt=%s\n' \
    "$spirv_disassembly" "$nir_text" "$isa_text" "$receipt_table"
