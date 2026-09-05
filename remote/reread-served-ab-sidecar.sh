#!/bin/sh
set -eu
# Re-reads a retained served A/B campaign under the current clock-sidecar
# validator. The measurement head and the analysis head are recorded apart,
# so a validator rule that changes after a run reinterprets the raw records
# the run retained rather than requiring the device again. Every arm's
# clock-sidecar.tsv is validated once more with the arguments the campaign's
# own inputs.tsv bound -- period, tolerance, cost bound, row-gap bound, lost
# fraction, allowed unavailable sensors, required clocks, nice, and CPU set
# -- over the request window each arm retained, and the new verdict decides
# the arm's `sidecar` and `status` columns exactly where the original verdict
# decided them: an arm the original run failed for `clock_sidecar` with the
# clock invariant held completes where the re-read accepts, and an arm the
# original run completed fails where the re-read refuses. Every other column
# is copied, since the rate, the clock state, and the regime were measured
# once. summarize-census-controls.py then runs over the re-read ledger with
# the bounds the campaign recorded, and the output directory carries the
# re-read verdicts, the re-read ledger, the summary, and a provenance file
# naming both validator digests and the arms whose status moved.
#
# usage: reread-served-ab-sidecar.sh CAMPAIGN_DIRECTORY OUTPUT_DIRECTORY
if [ "$#" -ne 2 ]; then
    printf 'usage: %s CAMPAIGN_DIRECTORY OUTPUT_DIRECTORY\n' "$0" >&2
    exit 2
fi
script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
campaign_directory=$1
output_directory=$2
validator=$script_directory/validate-clock-sidecar.py
summarizer=$script_directory/summarize-census-controls.py
for required in "$campaign_directory/arms.tsv" "$campaign_directory/inputs.tsv" \
    "$validator" "$summarizer"; do
    if [ ! -r "$required" ]; then
        printf 'required file is unreadable: %s\n' "$required" >&2
        exit 1
    fi
done
if [ -e "$output_directory" ]; then
    printf 'output directory exists; a re-read is written fresh: %s\n' "$output_directory" >&2
    exit 1
fi
inputs=$campaign_directory/inputs.tsv
input_value() {
    awk -F'\t' -v key="$1" '$1 == key { value = $2; count++ }
        END { if (count != 1) exit 1; print value }' "$inputs" || {
        printf 'inputs.tsv states %s other than exactly once\n' "$1" >&2
        exit 1
    }
}
input_optional() {
    awk -F'\t' -v key="$1" '$1 == key { value = $2; count++ }
        END { if (count == 1 && value != "-") print value }' "$inputs"
}
sidecar_period_ms=$(input_value sidecar_period_ms)
sidecar_tolerance=$(input_value sidecar_tolerance)
sidecar_cost_ns=$(input_value sidecar_cost_ns)
sidecar_max_gap_ns=$(input_value sidecar_max_gap_ns)
sidecar_max_lost_fraction=$(input_value sidecar_max_lost_fraction)
sidecar_nice=$(input_value sidecar_nice)
sidecar_cpu=$(input_value sidecar_cpu)
sidecar_allowed_unavailable=$(input_optional sidecar_allowed_unavailable)
required_sclk=$(input_optional engine_clock_required_sclk_mhz)
required_mclk=$(input_optional engine_clock_required_mclk_mhz)
mclk_floor_fraction=$(input_optional clock_below_mclk_floor_fraction)
served_ab_bound=$(input_value served_ab_bound)
sclk_band=$(input_value sclk_band)
original_validator_sha256=$(input_optional validate_clock_sidecar_sha256)
[ -n "$original_validator_sha256" ] || original_validator_sha256=-

mkdir -p "$output_directory/arms"
ledger=$output_directory/arms.tsv
provenance=$output_directory/reread.tsv
head -n 1 "$campaign_directory/arms.tsv" >"$ledger"
{
    printf 'campaign_directory\t%s\n' "$campaign_directory"
    printf 'validator_sha256\t%s\n' "$(sha256sum "$validator" | cut -d ' ' -f 1)"
    printf 'original_validator_sha256\t%s\n' "$original_validator_sha256"
    printf 'summarizer_sha256\t%s\n' "$(sha256sum "$summarizer" | cut -d ' ' -f 1)"
} >"$provenance"
moved=''
awk -F'\t' 'NR == 1 { for (i = 1; i <= NF; i++) column[$i] = i; next }
    { printf "%s\t%s\t%s\t%s\t%s\n", $(column["slot"]), $(column["arm"]),
        $(column["sidecar"]), $(column["status"]), $(column["clock_invariant"]) }' \
    "$campaign_directory/arms.tsv" | while IFS="$(printf '\t')" read -r slot arm sidecar status invariant; do
    # run-served-binary-ab.sh names an arm directory by a two-digit slot
    # where the ledger's slot column carries the bare number, and the warmup
    # slot 0a stays as written.
    case $slot in
        [0-9]) slot_name=0$slot ;;
        *) slot_name=$slot ;;
    esac
    arm_directory=$campaign_directory/arms/$slot_name-$arm
    record=$arm_directory/clock-sidecar.tsv
    window=$arm_directory/request-window.tsv
    reread_directory=$output_directory/arms/$slot_name-$arm
    mkdir -p "$reread_directory"
    new_sidecar=$sidecar
    new_status=$status
    if [ "$sidecar" = on ] || [ "$sidecar" = refused ]; then
        if [ ! -r "$record" ] || [ ! -r "$window" ]; then
            printf 'arm %s-%s retained no sidecar record or request window\n' "$slot" "$arm" >&2
            exit 1
        fi
        window_begin=$(awk -F'\t' '$1 == "begin_ns" { print $2 }' "$window")
        window_end=$(awk -F'\t' '$1 == "end_ns" { print $2 }' "$window")
        # The sampler's own exit status is read from the original verdict's
        # first line, since the record carries no exit status of its own.
        sidecar_status=$(awk '/^sidecar_exit=/ { for (i = 1; i <= NF; i++)
            if (index($i, "status=") == 1) print substr($i, 8); exit }' \
            "$arm_directory/clock-sidecar-verdict.txt" 2>/dev/null || true)
        [ -n "$sidecar_status" ] || sidecar_status=0
        set +e
        python3 "$validator" "$record" \
            --sidecar-status "$sidecar_status" --period-ms "$sidecar_period_ms" \
            --period-tolerance "$sidecar_tolerance" --cost-bound-ns "$sidecar_cost_ns" \
            --max-gap-ns "$sidecar_max_gap_ns" \
            --max-lost-fraction "$sidecar_max_lost_fraction" \
            --window-begin-ns "$window_begin" --window-end-ns "$window_end" \
            ${sidecar_allowed_unavailable:+--allow-unavailable "$sidecar_allowed_unavailable"} \
            ${required_sclk:+--required-sclk-mhz "$required_sclk"} \
            ${required_mclk:+--required-mclk-mhz "$required_mclk"} \
            ${mclk_floor_fraction:+--max-below-mclk-floor-fraction "$mclk_floor_fraction"} \
            --expected-nice "$sidecar_nice" --expected-cpu-affinity "$sidecar_cpu" \
            >"$reread_directory/clock-sidecar-verdict.txt" 2>&1
        verdict=$?
        set -e
        if [ "$verdict" -eq 0 ]; then
            new_sidecar=on
            # The original run failed the arm on its sidecar alone where the
            # rate was measured and the clock held; a warmup's sidecar
            # verdict never decides its status.
            if [ "$status" = failed ] && [ "$sidecar" = refused ] && [ "$invariant" = held ]; then
                new_status=completed
            fi
        else
            new_sidecar=refused
            if [ "$status" = completed ] && [ "$arm" != W ]; then
                new_status=failed
            fi
        fi
    fi
    awk -F'\t' -v OFS='\t' -v slot="$slot" -v arm="$arm" \
        -v sidecar="$new_sidecar" -v status="$new_status" \
        'NR == 1 { for (i = 1; i <= NF; i++) column[$i] = i; next }
        $(column["slot"]) == slot && $(column["arm"]) == arm {
            $(column["sidecar"]) = sidecar; $(column["status"]) = status; print }' \
        "$campaign_directory/arms.tsv" >>"$ledger"
    if [ "$new_status" != "$status" ] || [ "$new_sidecar" != "$sidecar" ]; then
        printf 'arm_moved\t%s-%s\t%s/%s\t%s/%s\n' "$slot" "$arm" "$sidecar" "$status" \
            "$new_sidecar" "$new_status" >>"$provenance"
    fi
done
python3 "$summarizer" "$ledger" \
    --sidecar-bound 0.0065 --compile-bound 0.0065 --collect-bound 0.02 \
    --served-ab-bound "$served_ab_bound" --sclk-band "$sclk_band" \
    >"$output_directory/summary.tsv"
awk -F'\t' 'NR == 1 { for (i = 1; i <= NF; i++) column[$i] = i; next }
    $(column["control"]) == "served-ab" {
        printf "served_ab_reread=%s mean_delta=%s ci_low=%s ci_high=%s deltas=%s\n",
            $(column["verdict"]), $(column["mean_delta"]), $(column["ci_low"]),
            $(column["ci_high"]), $(column["deltas"]) }' "$output_directory/summary.tsv"
awk -F'\t' '$1 == "arm_moved" { printf "arm_moved=%s %s -> %s\n", $2, $3, $4 }' "$provenance"
