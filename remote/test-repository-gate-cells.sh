#!/bin/sh
set -eu

# Prove the sparse gate's content identity over a fixture gate of two tiny
# cells rather than over the repository gate, whose own cells cost minutes and
# whose read sets are the thing under test. The fixture carries one cell with a
# derivable read set and one whose script enumerates the tree, so the same run
# observes a reuse and an always-run cell.
#
# Ground truth is a marker file each cell command appends to. The printed
# `cell=reused` line reports what the gate decided; the marker reports what
# actually executed, and only the pair separates a correct skip from a cell that
# runs and misreports.

if [ "$#" -ne 0 ]; then
    printf 'usage: %s\n' "$0" >&2
    exit 2
fi

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)

if [ ! -f "$script_directory/gate-cell-key.sh" ]; then
    printf 'gate cell reader is absent: %s\n' \
        "$script_directory/gate-cell-key.sh" >&2
    exit 2
fi

work_directory=$(mktemp -d)
cleanup() {
    rm -rf "$work_directory"
}
trap cleanup EXIT

fixture_root=$work_directory/tree
cache_directory=$work_directory/cache
marker_file=$work_directory/marker
mkdir -p "$fixture_root/remote"

cat >"$fixture_root/remote/alpha-data.tsv" <<'FIXTURE'
name	value
alpha	1
FIXTURE

cat >"$fixture_root/remote/alpha-test.sh" <<'FIXTURE'
#!/bin/sh
set -eu
# A cell whose whole read set is derivable: it names remote/alpha-data.tsv
# literally and composes no path from a variable.
printf 'alpha\n' >>"$QWEN_GATE_FIXTURE_MARKER"
cut -f1 remote/alpha-data.tsv >/dev/null
if [ "${QWEN_GATE_FIXTURE_ALPHA_FAIL:-0}" = 1 ]; then
    printf 'alpha refused\n' >&2
    exit 1
fi
FIXTURE

cat >"$fixture_root/remote/beta-test.sh" <<'FIXTURE'
#!/bin/sh
set -eu
# A cell whose read set the static reader cannot bound: it enumerates the
# tracked tree instead of naming its inputs.
printf 'beta\n' >>"$QWEN_GATE_FIXTURE_MARKER"
git ls-files >/dev/null 2>&1 || true
FIXTURE

cat >"$fixture_root/gate.sh" <<FIXTURE
#!/bin/sh
set -eu
cd "$fixture_root"
GATE_CELL_ROOT="$fixture_root"
export GATE_CELL_ROOT
. "$script_directory/gate-cell-key.sh"
gate_cell_init
trap gate_cell_cleanup EXIT
gate_cell alpha derive remote/alpha-test.sh 'sh remote/alpha-test.sh'
gate_cell beta derive remote/beta-test.sh 'sh remote/beta-test.sh'
gate_cell_summary
FIXTURE

failures=0

report_failure() {
    printf 'gate_cell_test=rejected case=%s reason=%s\n' "$1" "$2" >&2
    failures=$((failures + 1))
}

# Run the fixture gate and leave its stdout in $run_output and its marker lines
# in $marker_file. The first argument of 1 makes the alpha command exit
# non-zero; the second is the sparse setting the run carries.
run_output=$work_directory/output
run_fixture_gate() {
    : >"$marker_file"
    QWEN_GATE_FIXTURE_ALPHA_FAIL=${1:-0} \
        QWEN_GATE_SPARSE=${2:-1} \
        QWEN_GATE_FIXTURE_MARKER="$marker_file" \
        QWEN_GATE_CACHE_DIR="$cache_directory" \
        sh "$fixture_root/gate.sh" >"$run_output" 2>"$run_output.err"
}

marker_holds() {
    grep -qx "$1" "$marker_file"
}

summary_field() {
    sed -n 's/^gate=accepted .*'"$1"'=\([^ ]*\).*$/\1/p' "$run_output"
}

# A fresh cache runs everything.
run_fixture_gate
if ! marker_holds alpha || ! marker_holds beta; then
    report_failure fresh-cache both_cells_execute
fi
if [ "$(summary_field cells_run)" != 2 ] ||
    [ "$(summary_field cells_reused)" != 0 ]; then
    report_failure fresh-cache counts_report_two_runs
fi
if ! grep -qE '^cell=run key=[0-9a-f]{64} name=beta read_set=unbounded$' \
    "$run_output"; then
    report_failure fresh-cache beta_reports_unbounded
fi
first_root=$(summary_field root)

# Nothing changed: the derivable cell is reused and the unbounded one runs.
run_fixture_gate
if marker_holds alpha; then
    report_failure unchanged alpha_skips_execution
fi
if ! marker_holds beta; then
    report_failure unchanged beta_executes
fi
if ! grep -qE '^cell=reused key=[0-9a-f]{64} name=alpha$' "$run_output"; then
    report_failure unchanged alpha_reports_reused
fi
if [ "$(summary_field cells_run)" != 1 ] ||
    [ "$(summary_field cells_reused)" != 1 ]; then
    report_failure unchanged counts_report_one_reuse
fi
if [ "$(summary_field root)" != "$first_root" ]; then
    report_failure unchanged root_is_stable_across_runs
fi

# QWEN_GATE_SPARSE=0 runs every cell against the same warm cache.
run_fixture_gate 0 0
if ! marker_holds alpha; then
    report_failure sparse-off alpha_executes
fi
if [ "$(summary_field cells_run)" != 2 ]; then
    report_failure sparse-off counts_report_two_runs
fi
if [ "$(summary_field root)" != "$first_root" ]; then
    report_failure sparse-off root_is_stable_across_runs
fi

# One byte appended to the cell's own script reruns it.
printf '#\n' >>"$fixture_root/remote/alpha-test.sh"
run_fixture_gate
if ! marker_holds alpha; then
    report_failure script-edit alpha_reruns
fi
if [ "$(summary_field root)" = "$first_root" ]; then
    report_failure script-edit root_moves_with_the_script
fi
run_fixture_gate
if marker_holds alpha; then
    report_failure script-edit alpha_reuses_the_new_key
fi

# One byte appended to a file the cell reads reruns it, though the cell's own
# script is unchanged.
printf 'beta\t2\n' >>"$fixture_root/remote/alpha-data.tsv"
run_fixture_gate
if ! marker_holds alpha; then
    report_failure data-edit alpha_reruns
fi
run_fixture_gate
if marker_holds alpha; then
    report_failure data-edit alpha_reuses_the_new_key
fi

# A refused cell writes no record, so the next run measures it again. The read
# set moves first, since a cell holding an accepted record is skipped before its
# command could refuse.
printf 'gamma\t3\n' >>"$fixture_root/remote/alpha-data.tsv"
if run_fixture_gate 1; then
    report_failure refusal gate_fails_with_the_cell
fi
if ! grep -qE '^cell=rejected key=[0-9a-f]{64} name=alpha$' "$run_output.err"; then
    report_failure refusal rejection_is_reported
fi
run_fixture_gate
if ! marker_holds alpha; then
    report_failure refusal alpha_reruns_after_refusal
fi

# The unbounded cell ran in every one of those invocations.
if grep -qE '^cell=reused key=[0-9a-f]{64} name=beta$' "$run_output"; then
    report_failure unbounded beta_never_reuses
fi

if [ "$failures" -ne 0 ]; then
    printf 'gate_cell_test=rejected failures=%s\n' "$failures" >&2
    exit 1
fi

printf 'gate_cell_test=accepted\n'
