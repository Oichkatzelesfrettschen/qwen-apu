#!/bin/sh
set -eu

# Load every static-admitted candidate once and require it to produce a token.
#
# Static admission reads what a file declares. It cannot show that the artifact
# parses completely, that its tensor types have kernels in this build, that the
# graph constructs, that the device holds it, or that a token comes out. A
# runtime class establishes a shared throughput expectation and nothing about a
# particular artifact, so every row runs rather than one representative per
# class.
#
# remote/test-strict-vulkan-placement.sh is the admission itself: it requires
# CPU tensor placement and CPU graph placement to be rejected, brings a strict
# Vulkan server up, drives a two-token completion, and requires the model, KV,
# and compute buffers to name Vulkan0 with no CPU fallback reached. A control
# arm runs the same check against a checkpoint this tree already serves, after
# each new runtime class and after any failure, so a later refusal is read
# against a device that was working rather than against an unknown one.
#
# The load is text-only. A projector is a separate artifact that encodes images
# into one checkpoint's embedding space, so admitting it is a separate arm, and
# a row that loads and decodes without one is admitted for text rather than
# refused for vision. Those rows stay in the ledger as throughput and quality
# subjects; `projector` in the summary states whether the vision path was
# exercised, and `not-run` is what every row reads until that arm exists.
#
# The device is exclusive for the duration. The appliance listener holds the
# GPU, so it comes down before this runs and back up after.

renice -n 19 -p $$ >/dev/null 2>&1 || true
ionice -c 3 -p $$ >/dev/null 2>&1 || true

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
    printf 'usage: %s STATIC_ADMISSION_TSV [OUTPUT_DIRECTORY]\n' "$0" >&2
    printf 'environment: QWEN_LLAMA_SERVER QWEN_CANDIDATE_ROOT QWEN_CONTROL_MODEL\n' >&2
    printf '             QWEN_ADMISSION_STAGES QWEN_ADMISSION_ROWS\n' >&2
    printf '             QWEN_PLACEMENT_CHECK QWEN_CANDIDATE_FETCH\n' >&2
    exit 2
fi

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
record=$1
output_directory=${2:-"${HOME:?}/qwen-webui-state/one-token-admission"}
llama_server=${QWEN_LLAMA_SERVER:-"${HOME:?}/src/llama.cpp-qwen-apu/build-qwen-vulkan/bin/llama-server"}
candidate_root=${QWEN_CANDIDATE_ROOT:-"${HOME:?}/models/candidates"}
control_model=${QWEN_CONTROL_MODEL:-"${HOME:?}/models/Qwen3.8-2B-Distill-GGUF/Qwen3.8-2B-Q4_K_M.gguf"}
placement=${QWEN_PLACEMENT_CHECK:-$script_directory/test-strict-vulkan-placement.sh}
fetch=${QWEN_CANDIDATE_FETCH:-$script_directory/fetch-candidate-artifact.sh}
# `fetch` alone downloads without touching the device, which is what lets the
# transfers run while the appliance is still serving.
stages=${QWEN_ADMISSION_STAGES:-fetch,load}
selected_rows=${QWEN_ADMISSION_ROWS:-}

for required in "$record" "$placement" "$fetch"; do
    [ -r "$required" ] || { printf 'unreadable: %s\n' "$required" >&2; exit 2; }
done
case $stages in
    *load*)
        [ -x "$llama_server" ] || {
            printf 'llama-server is not executable: %s\n' "$llama_server" >&2
            exit 2
        }
        [ -f "$control_model" ] || {
            printf 'control model is absent: %s\n' "$control_model" >&2
            exit 2
        }
        ;;
esac

mkdir -p "$output_directory"
summary=$output_directory/admission-summary.tsv
if [ ! -s "$summary" ]; then
    printf 'candidate_id\tarchitecture\tartifact\tobserved_sha256\tfetch\tload\tprojector\tcontrol\tdetail\n' \
        >"$summary"
fi

run_control() {
    control_reason=$1
    control_log=$output_directory/control-$control_reason.log
    if "$placement" --llama-server "$llama_server" --model "$control_model" \
            >"$control_log" 2>&1; then
        printf 'control=accepted reason=%s\n' "$control_reason"
        control_state=accepted
    else
        printf 'control=rejected reason=%s log=%s\n' "$control_reason" "$control_log" >&2
        control_state=rejected
    fi
}

selected() {
    [ -z "$selected_rows" ] && return 0
    for wanted in $(printf '%s\n' "$selected_rows" | tr ',' ' '); do
        [ "$wanted" = "$1" ] && return 0
    done
    return 1
}

seen_classes=''
control_state=not-run
tab=$(printf '\t')

# The record's first column is the header and `admission` names whether the
# static read parsed, so a row that failed there has nothing to load.
while IFS="$tab" read -r candidate_id repository revision admission architecture \
        _block_count _nextn _vocabulary _pre _template_sha _template_bytes \
        _tokens_sha artifact _artifact_bytes _loaded _skipped _shards \
        _gguf_count _rule _window _thinking _think_block _tools _tool_calls \
        fingerprint; do
    [ "$candidate_id" = "candidate_id" ] && continue
    [ "$admission" = "parsed" ] || continue
    selected "$candidate_id" || continue

    candidate_directory=$candidate_root/$candidate_id
    artifact_path=$candidate_directory/$artifact
    fetch_state=skipped
    load_state=not-run
    projector_state=not-run
    detail='-'
    observed_sha256='-'

    case $stages in
        *fetch*)
            if fetch_line=$("$fetch" "$repository" "$revision" "$artifact" \
                    "$candidate_directory" 2>&1); then
                fetch_state=$(printf '%s' "$fetch_line" |
                    sed -n 's/.*artifact_status=\([a-z]*\).*/\1/p')
                observed_sha256=$(printf '%s' "$fetch_line" |
                    sed -n 's/.*observed_sha256=\([0-9a-f]*\).*/\1/p')
            else
                fetch_state=failed
                detail=$(printf '%s' "$fetch_line" | tr '\n' ' ' | cut -c1-160)
            fi
            ;;
    esac

    case $stages in
        *load*)
            if [ "$fetch_state" = failed ]; then
                load_state=not-run
            else
                # A class is a shared throughput expectation, so the control
                # runs when one is met for the first time: a refusal then reads
                # against a device that had just answered.
                class=$(printf '%s' "$fingerprint" | cut -d/ -f1-4)
                case " $seen_classes " in
                    *" $class "*) ;;
                    *)
                        seen_classes="$seen_classes $class"
                        run_control "class-$(printf '%s' "$class" | tr '/' '-')"
                        ;;
                esac
                load_log=$output_directory/$candidate_id.load.log
                if "$placement" --llama-server "$llama_server" \
                        --model "$artifact_path" >"$load_log" 2>&1; then
                    load_state=accepted
                else
                    load_state=rejected
                    detail=$(tail -3 "$load_log" | tr '\n' ' ' | cut -c1-160)
                    run_control "after-$candidate_id"
                fi
            fi
            ;;
    esac

    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$candidate_id" "$architecture" "$artifact" "$observed_sha256" \
        "$fetch_state" "$load_state" "$projector_state" "$control_state" \
        "$detail" >>"$summary"
    printf 'row=%s fetch=%s load=%s control=%s\n' \
        "$candidate_id" "$fetch_state" "$load_state" "$control_state"
done <"$record"

printf 'one_token_admission=complete summary=%s\n' "$summary"
