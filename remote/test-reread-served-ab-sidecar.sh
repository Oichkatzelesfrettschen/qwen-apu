#!/bin/sh
set -eu

# Drive reread-served-ab-sidecar.sh over a scratch served A/B campaign built
# from scratch under mktemp -d, since the retained target-closure evidence
# under evidence/q4k-scale-decode/ carries ledgers and summaries but no raw
# arms/*/clock-sidecar.tsv or request-window.tsv, the campaign's own state
# lives on the appliance rather than in the tree.
#
# The fixture's C K K C quadruple copies the tok_s, sclk_mode_mhz, and
# mclk_mode_mhz values evidence/q4k-scale-decode/target-closure-20260905/
# run1/arms.tsv already carries for its nine-arm ledger, so the summarizer's
# served-ab verdict over this fixture is the same "unresolved" call the real
# campaign reached; only slot 1's sidecar and status move.
#
# Slot 1 carries a clock-sidecar.tsv with one marker-to-marker gap widened
# past validate-clock-sidecar.py's 1.5x bound while every other marker gap
# stays at the declared cadence, so the record's median in-window marker gap
# (dpm_marker_cadence's own reading) sits under the bound while its widest
# single gap sits over it. The record's declared pp_dpm_period_ns of
# 200000000 against the campaign's 20 ms sampling period fixes that bound at
# 300 ms, so a single 60 ms hold-off cannot carry a 200 ms marker interval
# past it; the fixture instead uses one 110 ms hold-off to cross the bound
# with margin while keeping the same shape the task names -- one scheduler
# hold-off a widest-gap reading refuses and the median reading admits. Every
# other column the tool copies verbatim, so the original run's own
# clock-sidecar-verdict.txt reads sidecar_exit=accepted status=0 on every arm
# including slot 1: the sampler exited cleanly there, and what refused the
# arm was validate-clock-sidecar.py's own marker-cadence reading, not the
# sampler process.
#
# usage: test-reread-served-ab-sidecar.sh
# Exits 0 and prints test_reread_served_ab_sidecar=accepted on success.

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
tool=$script_directory/reread-served-ab-sidecar.sh

if [ ! -x "$tool" ]; then
    printf 'tool is not executable: %s\n' "$tool" >&2
    exit 1
fi

work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT

campaign_directory=$work/campaign
mkdir -p "$campaign_directory/arms"

# -- usage: a wrong argument count exits 2 and says so on stderr --------
usage_failures=0
set +e
"$tool" >/dev/null 2>"$work/usage-0.err"
status=$?
set -e
if [ "$status" -ne 2 ]; then
    printf 'usage: no arguments exited %s, expected 2\n' "$status" >&2
    usage_failures=1
fi
if ! grep -q 'usage:' "$work/usage-0.err"; then
    printf 'usage: no-argument stderr names no usage line\n' >&2
    usage_failures=1
fi
set +e
"$tool" "$campaign_directory" >/dev/null 2>"$work/usage-1.err"
status=$?
set -e
if [ "$status" -ne 2 ]; then
    printf 'usage: one argument exited %s, expected 2\n' "$status" >&2
    usage_failures=1
fi
set +e
"$tool" "$campaign_directory" "$work/out-a" "$work/out-b" >/dev/null 2>"$work/usage-3.err"
status=$?
set -e
if [ "$status" -ne 2 ]; then
    printf 'usage: three arguments exited %s, expected 2\n' "$status" >&2
    usage_failures=1
fi
if [ "$usage_failures" -ne 0 ]; then
    exit 1
fi

# -- build the fixture campaign -------------------------------------------

cat >"$campaign_directory/inputs.tsv" <<'EOF'
sidecar_period_ms	20
sidecar_tolerance	0.25
sidecar_cost_ns	1000000
sidecar_max_gap_ns	250000000
sidecar_max_lost_fraction	0.03
sidecar_nice	19
sidecar_cpu	0,1
sidecar_allowed_unavailable	-
engine_clock_required_sclk_mhz	-
engine_clock_required_mclk_mhz	-
clock_below_mclk_floor_fraction	-
served_ab_bound	0.05
sclk_band	0.06
EOF

cat >"$campaign_directory/arms.tsv" <<'EOF'
slot	arm	server_sha256	predicted_n	predicted_ms	tok_s	census_rows	sidecar	ownership	status	sclk_mode_mhz	sclk_share	mclk_mode_mhz	regime_delta	clock_invariant	below_required_fraction
0a	W	70aa78bc0eed708ce8d06b690467affce3bb222014714af4dbd92e00fa5ff010	64	6537.038	9.637	-	on	-	completed	1100	1.0000	933	-	held	0.0000
1	C	70aa78bc0eed708ce8d06b690467affce3bb222014714af4dbd92e00fa5ff010	64	6522.848	9.658	-	refused	-	failed	1100	1.0000	933	-	held	0.0000
2	K	83684f3c5992c1e62f26d15247393cf4b1aa380c5f2a4e1ca1b05071db0e49b4	64	6261.172	10.062	-	on	-	completed	1100	1.0000	933	-	held	0.0000
3	K	83684f3c5992c1e62f26d15247393cf4b1aa380c5f2a4e1ca1b05071db0e49b4	64	6194.849	10.170	-	on	-	completed	1100	1.0000	933	-	held	0.0000
4	C	70aa78bc0eed708ce8d06b690467affce3bb222014714af4dbd92e00fa5ff010	64	6547.955	9.621	-	on	-	completed	1100	1.0000	933	-	held	0.0000
5	C	70aa78bc0eed708ce8d06b690467affce3bb222014714af4dbd92e00fa5ff010	64	6534.680	9.641	-	on	-	completed	1100	1.0000	933	-	held	0.0000
6	K	83684f3c5992c1e62f26d15247393cf4b1aa380c5f2a4e1ca1b05071db0e49b4	64	6242.209	10.093	-	on	-	completed	1100	1.0000	933	-	held	0.0000
7	K	83684f3c5992c1e62f26d15247393cf4b1aa380c5f2a4e1ca1b05071db0e49b4	64	6172.429	10.207	-	on	-	completed	1100	1.0000	933	-	held	0.0000
8	C	70aa78bc0eed708ce8d06b690467affce3bb222014714af4dbd92e00fa5ff010	64	6574.985	9.582	-	on	-	completed	1100	1.0000	933	-	held	0.0000
EOF

cat >"$work/gen-arm.py" <<'PY'
import sys

COLUMNS = (
    "monotonic_ns",
    "pp_dpm_sclk_selected_mhz",
    "pp_dpm_mclk_surface_mhz",
    "pp_dpm_fclk_surface_mhz",
    "gpu_busy_percent",
    "temp1_millidegrees",
    "sample_cost_ns",
)

PERIOD_NS = 20_000_000
STRIDE = 10
SAMPLES = 500
START_NS = 1_000_000_000
COST_NS = 30_000


def main():
    directory = sys.argv[1]
    holdoff_index = None if sys.argv[2] == "-" else int(sys.argv[2])
    holdoff_ns = int(sys.argv[3])

    instants = []
    for index in range(SAMPLES):
        instant = START_NS + index * PERIOD_NS
        if holdoff_index is not None and index >= holdoff_index:
            instant += holdoff_ns
        instants.append(instant)

    lines = [
        f"# clock=CLOCK_MONOTONIC period_ns={PERIOD_NS} drm_device=/fake hwmon=/fake/hwmon0",
        f"# sample_rates: gpu_busy_percent_period_ns={PERIOD_NS}"
        f" pp_dpm_period_ns={PERIOD_NS * STRIDE}",
        "# sampler_pid=4242 nice=19 cpu_affinity=0,1",
        "\t".join(COLUMNS),
    ]
    for index, instant in enumerate(instants):
        if index % STRIDE == 0:
            lines.append(f"# dpm_read={instant}")
        lines.append(f"{instant}\t1100\t933\t1067\t61.0\t61000\t{COST_NS}")
    first = instants[0]
    last = instants[-1]
    achieved = (last - first) // (SAMPLES - 1)
    lines.append(
        f"# samples={SAMPLES} achieved_period_ns={achieved}"
        f" mean_sample_cost_ns={COST_NS} max_sample_cost_ns={COST_NS}"
        f" samples_with_unavailable_sensor=0"
        f" first_sample_ns={first} last_sample_ns={last}"
    )

    with open(f"{directory}/clock-sidecar.tsv", "w") as handle:
        handle.write("\n".join(lines) + "\n")

    window_begin = first + 100_000_000
    window_end = last - 100_000_000
    with open(f"{directory}/request-window.tsv", "w") as handle:
        handle.write(f"begin_ns\t{window_begin}\nend_ns\t{window_end}\n")

    with open(f"{directory}/clock-sidecar-verdict.txt", "w") as handle:
        handle.write("sidecar_exit=accepted status=0\n")


if __name__ == "__main__":
    main()
PY

for slot_name in 0a-W 01-C 02-K 03-K 04-C 05-C 06-K 07-K 08-C; do
    mkdir -p "$campaign_directory/arms/$slot_name"
    if [ "$slot_name" = "01-C" ]; then
        # One marker interval carries an extra 110 ms hold-off starting at
        # row 55, inside the ten-row stride between the markers at rows 50
        # and 60: that one gap reads 310 ms against the 300 ms bound
        # (1.5x the declared 200 ms cadence) while every other marker gap
        # in the record, and therefore the median, stays at 200 ms.
        python3 "$work/gen-arm.py" "$campaign_directory/arms/$slot_name" 55 110000000
    else
        python3 "$work/gen-arm.py" "$campaign_directory/arms/$slot_name" - 0
    fi
done

# -- the tool runs clean over the fixture campaign ------------------------

output_ok=$work/output-ok
set +e
"$tool" "$campaign_directory" "$output_ok" >"$work/run-ok.out" 2>"$work/run-ok.err"
status=$?
set -e
if [ "$status" -ne 0 ]; then
    printf 'reread-served-ab-sidecar.sh exited %s over a clean fixture\n' "$status" >&2
    cat "$work/run-ok.err" >&2
    exit 1
fi

reread_provenance=$output_ok/reread.tsv
if [ ! -r "$reread_provenance" ]; then
    printf 'reread.tsv is missing: %s\n' "$reread_provenance" >&2
    exit 1
fi
if ! grep -q '^arm_moved	1-C	refused/failed	on/completed$' "$reread_provenance"; then
    printf 'reread.tsv carries no arm_moved row for 1-C refused/failed -> on/completed\n' >&2
    cat "$reread_provenance" >&2
    exit 1
fi

reread_ledger=$output_ok/arms.tsv
if [ ! -r "$reread_ledger" ]; then
    printf 're-read arms.tsv is missing: %s\n' "$reread_ledger" >&2
    exit 1
fi

expected_row=$(awk -F'\t' -v OFS='\t' \
    'NR == 1 { for (i = 1; i <= NF; i++) column[$i] = i; next }
     $(column["slot"]) == "1" && $(column["arm"]) == "C" {
         $(column["sidecar"]) = "on"; $(column["status"]) = "completed"; print }' \
    "$campaign_directory/arms.tsv")
actual_row=$(awk -F'\t' '$1 == "1" && $2 == "C"' "$reread_ledger")
if [ "$actual_row" != "$expected_row" ]; then
    printf 're-read arms.tsv row for slot 1 does not read on/completed with every other column unchanged\n' >&2
    printf 'expected: %s\n' "$expected_row" >&2
    printf 'actual:   %s\n' "$actual_row" >&2
    exit 1
fi

summary=$output_ok/summary.tsv
if [ ! -r "$summary" ]; then
    printf 'summary.tsv is missing: %s\n' "$summary" >&2
    exit 1
fi
served_ab_verdict=$(awk -F'\t' \
    'NR == 1 { for (i = 1; i <= NF; i++) column[$i] = i; next }
     $(column["control"]) == "served-ab" { print $(column["verdict"]) }' \
    "$summary")
if [ -z "$served_ab_verdict" ]; then
    printf 'summary.tsv carries no served-ab row\n' >&2
    cat "$summary" >&2
    exit 1
fi
if [ "$served_ab_verdict" = "incomplete" ]; then
    printf 'summary.tsv reads served-ab verdict=incomplete\n' >&2
    exit 1
fi

# -- the tool refuses a re-read into an output directory that already exists

set +e
"$tool" "$campaign_directory" "$output_ok" >/dev/null 2>"$work/exists.err"
status=$?
set -e
if [ "$status" -eq 0 ]; then
    printf 'reread-served-ab-sidecar.sh accepted an existing output directory: %s\n' "$output_ok" >&2
    exit 1
fi
if ! grep -qF -- "$output_ok" "$work/exists.err"; then
    printf 'the existing-output refusal names no path: %s\n' "$output_ok" >&2
    cat "$work/exists.err" >&2
    exit 1
fi

# -- the tool refuses an arm that retained no request-window.tsv ---------

campaign_missing=$work/campaign-missing
cp -r "$campaign_directory" "$campaign_missing"
rm -f "$campaign_missing/arms/01-C/request-window.tsv"
output_missing=$work/output-missing
set +e
"$tool" "$campaign_missing" "$output_missing" >/dev/null 2>"$work/missing.err"
status=$?
set -e
if [ "$status" -eq 0 ]; then
    printf 'reread-served-ab-sidecar.sh accepted an arm missing request-window.tsv\n' >&2
    exit 1
fi
if ! grep -q '1-C' "$work/missing.err" || ! grep -q 'request window' "$work/missing.err"; then
    printf 'the missing-window refusal does not name the arm: %s\n' "1-C" >&2
    cat "$work/missing.err" >&2
    exit 1
fi

printf 'test_reread_served_ab_sidecar=accepted\n'
