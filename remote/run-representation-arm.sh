#!/bin/sh
set -eu

# Measure one value representation against another on the same weights, in the
# order control, subject, subject, control. A representation changes the bytes
# streamed per token and nothing else about the model, so the question is a
# ratio; this tree has measured the same checkpoint under identical flags
# spanning 30.6% between sweeps, and an absolute band built across sweeps
# measured the sweep. The ABBA order puts both rungs inside one sweep and pairs
# each subject arm with a control arm minutes away, so a monotonic drift in
# machine state cancels in the paired mean instead of ordering the result.
#
# The control is named first because it is the rung already measured. Both files
# hold the same weights at the same architecture, so a difference in prefill or
# decode is a difference in what the value format costs to stream and unpack.

if [ "$#" -lt 3 ] || [ "$#" -gt 4 ]; then
    printf 'usage: %s LABEL CONTROL_MODEL SUBJECT_MODEL [OUTPUT_DIRECTORY]\n' "$0" >&2
    printf 'environment: QWEN_LLAMA_BENCH QWEN_CLOCK_SAMPLER QWEN_ARM_REPEATS\n' >&2
    printf '             QWEN_BENCH_PROMPT QWEN_BENCH_GENERATE QWEN_COOLDOWN_SECONDS\n' >&2
    exit 2
fi

label=$1
control_model=$2
subject_model=$3
output_directory=${4:-"${HOME:?}/qwen-representation-arm"}/$label
script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
bench=${QWEN_LLAMA_BENCH:-"${HOME:?}/src/llama.cpp-qwen-apu/build-qwen-vulkan/bin/llama-bench"}
cli=${QWEN_LLAMA_CLI:-"${HOME:?}/src/llama.cpp-qwen-apu/build-qwen-vulkan/bin/llama-cli"}
clock_sampler=${QWEN_CLOCK_SAMPLER:-$script_directory/sample-gpu-clocks.sh}
arm_repeats=${QWEN_ARM_REPEATS:-3}
prompt_tokens=${QWEN_BENCH_PROMPT:-512}
generate_tokens=${QWEN_BENCH_GENERATE:-64}
cooldown_seconds=${QWEN_COOLDOWN_SECONDS:-90}

for required_file in "$bench" "$cli"; do
    if [ ! -x "$required_file" ]; then
        printf 'required executable is absent: %s\n' "$required_file" >&2
        exit 1
    fi
done
for required_model in "$control_model" "$subject_model"; do
    if [ ! -f "$required_model" ]; then
        printf 'model does not exist: %s\n' "$required_model" >&2
        exit 2
    fi
done

# llama-bench and the server both take the whole device, so a second holder
# makes every rate below a measurement of contention.
if pgrep -x llama-server >/dev/null 2>&1 || pgrep -x llama-bench >/dev/null 2>&1; then
    printf 'another llama process holds the device\n' >&2
    exit 2
fi

mkdir -p "$output_directory"
summary=$output_directory/representation-summary.tsv
printf 'position\trole\tmodel\tstreamed_bytes\tprefill_tok_s\tdecode_tok_s\twall_seconds\tmclk_mhz_modal\tsclk_mhz_max\ttemp_c_max\n' \
    >"$summary"

sampler_pid=''
stop_sampler() {
    [ -n "$sampler_pid" ] || return 0
    kill "$sampler_pid" 2>/dev/null || true
    wait "$sampler_pid" 2>/dev/null || true
    sampler_pid=''
}
trap 'stop_sampler' EXIT INT TERM

# The census reports what an ordinary load streams per token, which excludes the
# multi-token-prediction block the loader skips. File size counts that block, so
# a ratio built from file sizes overstates what the device moves.
streamed_bytes_of() {
    GGUF_PY_PATH=${GGUF_PY_PATH:-"${HOME:?}/src/llama.cpp-qwen-apu/gguf-py"} \
        "$script_directory/gguf-tensor-census.py" "$1" 2>/dev/null |
        awk -F'\t' '$1 == "streamed_bytes_per_token" { print $2; exit }'
}

# One token with every tensor forced onto the device, so an arm that silently
# placed weights on the CPU backend is named here rather than read as a slow
# representation.
check_strict_placement() {
    placement_model=$1
    placement_log=$2
    nice -n 19 "$cli" --model "$placement_model" --device Vulkan0 \
        --n-gpu-layers all --override-tensor '.*=Vulkan0' --no-warmup \
        --ctx-size 256 --n-predict 1 --temp 0 --prompt 'ok' \
        --no-conversation >"$placement_log" 2>&1 || return 1
    if grep -q 'CPU buffer size' "$placement_log"; then
        return 2
    fi
    return 0
}

run_arm() {
    arm_position=$1
    arm_role=$2
    arm_model=$3
    arm_stem=$output_directory/$(printf '%02d' "$arm_position")-$arm_role
    arm_clocks=$arm_stem-clocks.tsv
    arm_log=$arm_stem-bench.txt

    "$clock_sampler" "$arm_clocks" 100000 >/dev/null 2>&1 &
    sampler_pid=$!

    arm_started=$(date +%s)
    nice -n 19 "$bench" --model "$arm_model" -ngl 99 -t 2 \
        -r "$arm_repeats" -p "$prompt_tokens" -n "$generate_tokens" \
        -b 128 -ub 32 -fa 1 -ctk q8_0 -ctv q4_0 -o csv \
        >"$arm_log" 2>&1 || {
            printf 'bench arm failed: position %s role %s\n' \
                "$arm_position" "$arm_role" >&2
            cat "$arm_log" >&2
            stop_sampler
            return 1
        }
    arm_wall=$(( $(date +%s) - arm_started ))
    stop_sampler

    # llama-bench csv names its columns, so the rate is read by header rather
    # than by column position, which moves between builds.
    arm_rates=$(python3 - "$arm_log" <<'PYTHON'
import csv
import sys

prefill = decode = "-"
with open(sys.argv[1], newline="") as handle:
    for row in csv.DictReader(line for line in handle if "," in line):
        name = (row.get("n_prompt") or "0", row.get("n_gen") or "0")
        rate = row.get("avg_ts") or row.get("t/s") or ""
        if name[0] != "0" and name[1] == "0":
            prefill = f"{float(rate):.2f}"
        elif name[1] != "0":
            decode = f"{float(rate):.2f}"
print(f"{prefill}\t{decode}")
PYTHON
)

    arm_clock_summary=$(awk -F'\t' 'NR > 1 {
            mclk[$3]++; if ($4 + 0 > sclk) { sclk = $4 + 0 }
            if ($5 + 0 > temp) { temp = $5 + 0 }
        }
        END {
            modal = "-"; best = 0
            for (value in mclk) { if (mclk[value] > best) { best = mclk[value]; modal = value } }
            printf "%s\t%s\t%s", modal, (sclk ? sclk : "-"), (temp ? temp : "-")
        }' "$arm_clocks" 2>/dev/null || printf -- '-\t-\t-')

    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$arm_position" "$arm_role" "$(basename "$arm_model")" \
        "$(streamed_bytes_of "$arm_model")" "$arm_rates" "$arm_wall" \
        "$arm_clock_summary" >>"$summary"
    printf 'position=%s role=%s prefill=%s decode=%s wall=%ss\n' \
        "$arm_position" "$arm_role" \
        "$(printf '%s' "$arm_rates" | cut -f1)" \
        "$(printf '%s' "$arm_rates" | cut -f2)" "$arm_wall"
}

for placement_role in control subject; do
    case $placement_role in
        control) placement_target=$control_model ;;
        subject) placement_target=$subject_model ;;
    esac
    set +e
    check_strict_placement "$placement_target" \
        "$output_directory/placement-$placement_role.txt"
    placement_status=$?
    set -e
    case $placement_status in
        0) printf 'placement=%s strict_vulkan=passed\n' "$placement_role" ;;
        2) printf 'placement=%s strict_vulkan=cpu-fallback\n' "$placement_role" >&2
           grep -F 'buffer size' "$output_directory/placement-$placement_role.txt" >&2
           exit 1 ;;
        *) printf 'placement=%s strict_vulkan=failed\n' "$placement_role" >&2
           tail -20 "$output_directory/placement-$placement_role.txt" >&2
           exit 1 ;;
    esac
done

position=1
for arm_role in control subject subject control; do
    case $arm_role in
        control) arm_model=$control_model ;;
        subject) arm_model=$subject_model ;;
    esac
    run_arm "$position" "$arm_role" "$arm_model"
    position=$((position + 1))
    [ "$position" -le 4 ] && sleep "$cooldown_seconds"
done

printf '\n'
cat "$summary"

# The paired mean is what the ABBA order was run for: two subject arms against
# two control arms measured minutes apart in the same session.
python3 - "$summary" <<'PYTHON'
import sys

rows = []
with open(sys.argv[1]) as handle:
    header = handle.readline().rstrip("\n").split("\t")
    for line in handle:
        rows.append(dict(zip(header, line.rstrip("\n").split("\t"))))

def mean(role, column):
    values = [float(r[column]) for r in rows
              if r["role"] == role and r[column] not in ("-", "")]
    return sum(values) / len(values) if values else None

print()
for column in ("prefill_tok_s", "decode_tok_s"):
    control, subject = mean("control", column), mean("subject", column)
    if control and subject:
        print(f"{column}\tcontrol={control:.2f}\tsubject={subject:.2f}"
              f"\tratio={subject / control:.3f}")

streamed = {r["role"]: int(r["streamed_bytes"]) for r in rows
            if r["streamed_bytes"] not in ("-", "")}
if len(streamed) == 2:
    print(f"streamed_bytes\tcontrol={streamed['control']}"
          f"\tsubject={streamed['subject']}"
          f"\tratio={streamed['subject'] / streamed['control']:.3f}")
    for role in ("control", "subject"):
        decode = mean(role, "decode_tok_s")
        if decode:
            print(f"achieved_gib_tok_s\t{role}="
                  f"{decode * streamed[role] / 1073741824:.2f}")
PYTHON

printf 'representation_arm=completed label=%s output=%s\n' "$label" "$output_directory"
