#!/bin/sh
set -eu

# Prove the sparse gate's content identity over a fixture gate of four tiny
# cells rather than over the repository gate, whose own cells cost minutes and
# whose read sets are the thing under test. The fixture carries one cell with a
# derivable read set, one whose script enumerates the tree, one reaching its
# dependency by Python module name in its own directory, and one reaching a
# module, a literal script name, and an extensionless helper across a sibling
# directory the way image-mcp/server.py reaches image_protocol.py and
# image-mcp/test-image-mcp.py reaches web-mcp/authorize-broker.py, so the same
# run observes a reuse, an always-run cell, a same-directory import, and a
# cross-directory reference the filename reader alone would miss.
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
mkdir -p "$fixture_root/remote/helpers"

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

cat >"$fixture_root/remote/gamma_helper.py" <<'FIXTURE'
MARGIN = 1
FIXTURE

cat >"$fixture_root/remote/gamma-test.py" <<'FIXTURE'
import os

import gamma_helper

# A cell reaching its dependency by Python module name rather than by filename,
# which is how every test in this tree reaches a sibling module in its own
# directory.
with open(os.environ["QWEN_GATE_FIXTURE_MARKER"], "a") as marker_stream:
    marker_stream.write("gamma\n")
assert gamma_helper.MARGIN >= 0
FIXTURE

# delta-test.py reaches three members of remote/helpers/ the way this tree's
# multi-directory servers reach a sibling directory: a bare import resolved
# through sys.path.insert, a script named as a string literal and spawned, and
# an extensionless script that is itself read for what it names.
cat >"$fixture_root/remote/helpers/cross_helper.py" <<'FIXTURE'
MARGIN = 1
FIXTURE

cat >"$fixture_root/remote/helpers/cross-helper.sh" <<'FIXTURE'
#!/bin/sh
set -eu
exit 0
FIXTURE

cat >"$fixture_root/remote/helpers/cross-helper" <<'FIXTURE'
#!/bin/sh
set -eu
# reads remote/helpers/cross-helper-data.tsv
cat remote/helpers/cross-helper-data.tsv >/dev/null
FIXTURE
chmod 0755 "$fixture_root/remote/helpers/cross-helper"

cat >"$fixture_root/remote/helpers/cross-helper-data.tsv" <<'FIXTURE'
name	value
cross	1
FIXTURE

cat >"$fixture_root/remote/delta-test.py" <<'FIXTURE'
import os
import subprocess
import sys

DELTA_DIRECTORY = os.path.dirname(os.path.abspath(__file__))
HELPERS_DIRECTORY = os.path.join(DELTA_DIRECTORY, "helpers")
sys.path.insert(0, HELPERS_DIRECTORY)

import cross_helper  # noqa: E402

# A script named as a string literal in another directory, the way
# image-mcp/test-image-mcp.py names remote/web-mcp/authorize-broker.py.
CROSS_SCRIPT_PATH = os.path.join(HELPERS_DIRECTORY, "cross-helper.sh")

with open(os.environ["QWEN_GATE_FIXTURE_MARKER"], "a") as marker_stream:
    marker_stream.write("delta\n")
assert cross_helper.MARGIN >= 0
subprocess.run(["sh", CROSS_SCRIPT_PATH], check=True)
# The extensionless sibling is named here as a bare os.path.join(...) leaf
# alone, with no comment spelling its path, so the read set must resolve it
# by directory rather than by matching a literal string elsewhere in the file.
subprocess.run(
    ["sh", os.path.join(HELPERS_DIRECTORY, "cross-helper")], check=True
)
FIXTURE

# A browser stand-in whose version report is a field of the tool digest, which
# is what binds a cell record to the executable that produced it.
fixture_chromium=$work_directory/chromium
cat >"$fixture_chromium" <<'FIXTURE'
#!/bin/sh
printf 'Chromium 140.0.0.0 fixture\n'
FIXTURE
chmod 0755 "$fixture_chromium"

# A `sh` stand-in that passes every real invocation through to the system
# shell and fakes only its own version report, so PATH alone decides which
# interpreter the fixture gate's own `sh remote/NAME.sh` cells and the driver
# invocation itself resolve to. Its shebang names /bin/sh absolutely, so the
# kernel resolves it independently of PATH and a prepended fixture directory
# cannot recurse into itself.
fixture_sh_directory=$work_directory/bin
mkdir -p "$fixture_sh_directory"
fixture_sh=$fixture_sh_directory/sh
cat >"$fixture_sh" <<'FIXTURE'
#!/bin/sh
if [ "$1" = "--version" ]; then
    printf 'fixture sh 9.9.9\n'
    exit 0
fi
exec /bin/sh "$@"
FIXTURE
chmod 0755 "$fixture_sh"

# The fixture driver lives beside its own copy of gate-cell-key.sh, the way
# repository-quality-gates.sh lives beside the real one, so the driver and
# reader identity the key now carries resolves the same way in the test as in
# the gate.
cp "$script_directory/gate-cell-key.sh" "$fixture_root/remote/gate-cell-key.sh"
cp "$script_directory/qwen-home.sh" "$fixture_root/remote/qwen-home.sh"
cat >"$fixture_root/remote/gate.sh" <<'FIXTURE'
#!/bin/sh
set -eu
gate_script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
gate_fixture_root=$(CDPATH='' cd -- "$gate_script_directory/.." && pwd)
cd "$gate_fixture_root"
GATE_CELL_ROOT=$gate_fixture_root
export GATE_CELL_ROOT
GATE_CELL_DRIVER_PATH=$gate_script_directory/$(basename -- "$0")
export GATE_CELL_DRIVER_PATH
. "$gate_script_directory/gate-cell-key.sh"
gate_cell_init
trap gate_cell_cleanup EXIT
gate_cell alpha derive remote/alpha-test.sh 'sh remote/alpha-test.sh'
gate_cell beta derive remote/beta-test.sh 'sh remote/beta-test.sh'
gate_cell gamma derive remote/gamma-test.py 'python3 remote/gamma-test.py'
gate_cell delta derive remote/delta-test.py 'python3 remote/delta-test.py'
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
        QWEN_GATE_TIMING=${3:-1} \
        QWEN_GATE_FIXTURE_MARKER="$marker_file" \
        QWEN_GATE_CACHE_DIR="$cache_directory" \
        QWEN_CHROMIUM="$fixture_chromium" \
        sh "$fixture_root/remote/gate.sh" >"$run_output" 2>"$run_output.err"
}

marker_holds() {
    grep -qx "$1" "$marker_file"
}

summary_field() {
    sed -n 's/^gate=accepted .*'"$1"'=\([^ ]*\).*$/\1/p' "$run_output"
}

# A fresh cache runs everything: alpha, gamma, and delta are bounded, beta is
# unbounded.
run_fixture_gate
if ! marker_holds alpha || ! marker_holds beta || ! marker_holds gamma ||
    ! marker_holds delta; then
    report_failure fresh-cache every_cell_executes
fi
if [ "$(summary_field cells_run)" != 4 ] ||
    [ "$(summary_field cells_reused)" != 0 ]; then
    report_failure fresh-cache counts_report_four_runs
fi
if ! grep -qE '^cell=run key=[0-9a-f]{64} name=beta read_set=unbounded$' \
    "$run_output"; then
    report_failure fresh-cache beta_reports_unbounded
fi
first_root=$(summary_field root)

# Nothing changed: the three derivable cells are reused and the unbounded one
# runs.
run_fixture_gate
if marker_holds alpha; then
    report_failure unchanged alpha_skips_execution
fi
if ! marker_holds beta; then
    report_failure unchanged beta_executes
fi
if marker_holds gamma || marker_holds delta; then
    report_failure unchanged gamma_and_delta_skip_execution
fi
if ! grep -qE '^cell=reused key=[0-9a-f]{64} name=alpha$' "$run_output"; then
    report_failure unchanged alpha_reports_reused
fi
if [ "$(summary_field cells_run)" != 1 ] ||
    [ "$(summary_field cells_reused)" != 3 ]; then
    report_failure unchanged counts_report_three_reuses
fi
if [ "$(summary_field root)" != "$first_root" ]; then
    report_failure unchanged root_is_stable_across_runs
fi
# Where the run spent its time is read from the same boundaries the decisions
# are made at, so a timing line accompanies every cell and names which decision
# it belongs to. A reused cell states the execution it avoided, which the
# record it reused measured when that cell last ran; a run before the field
# existed reads `-` rather than zero, since an unrecorded cost is not a saving
# of nothing.
if [ "$(grep -c '^cell=timing ' "$run_output")" -ne 4 ]; then
    report_failure unchanged every_cell_reports_timing
fi
if ! grep -qE '^cell=timing key=[0-9a-f]{64} name=alpha decision=reused key_ns=[0-9]+ avoided_ns=[0-9]+$' \
    "$run_output"; then
    report_failure unchanged reused_cell_states_the_execution_it_avoided
fi
if ! grep -qE '^cell=timing key=[0-9a-f]{64} name=beta decision=run key_ns=[0-9]+ run_ns=[0-9]+$' \
    "$run_output"; then
    report_failure unchanged running_cell_states_both_phases
fi
if ! grep -qE '^gate_timing key_ns=[0-9]+ run_ns=[0-9]+ avoided_ns=[0-9]+ clock=CLOCK_REALTIME boundaries_per_cell=3$' \
    "$run_output"; then
    report_failure unchanged summary_states_the_three_totals
fi
# The totals are sums of the per-cell lines rather than a second measurement, so
# a reader recomputing them from the log reaches the same numbers.
timing_recomputed=$(awk '
    /^cell=timing / {
        for (i = 1; i <= NF; i++) {
            split($i, field, "=")
            if (field[1] == "key_ns" && field[2] ~ /^[0-9]+$/) key += field[2]
            if (field[1] == "run_ns" && field[2] ~ /^[0-9]+$/) run += field[2]
            if (field[1] == "avoided_ns" && field[2] ~ /^[0-9]+$/) avoided += field[2]
        }
    }
    END { printf "%d %d %d\n", key + 0, run + 0, avoided + 0 }' "$run_output")
timing_reported=$(awk '
    /^gate_timing / {
        for (i = 1; i <= NF; i++) {
            split($i, field, "=")
            if (field[1] == "key_ns") key = field[2]
            if (field[1] == "run_ns") run = field[2]
            if (field[1] == "avoided_ns") avoided = field[2]
        }
    }
    END { printf "%d %d %d\n", key + 0, run + 0, avoided + 0 }' "$run_output")
if [ "$timing_recomputed" != "$timing_reported" ]; then
    report_failure unchanged totals_recompute_from_the_cell_lines
fi
# The timing is an addition to the decision lines rather than a change to them,
# so a reader that matched a cell line before this field existed still matches.
if ! grep -qE '^cell=reused key=[0-9a-f]{64} name=alpha$' "$run_output"; then
    report_failure unchanged decision_line_shape_is_unchanged
fi
# QWEN_GATE_TIMING=0 removes the clock reads entirely, for a run that wants no
# measurement of itself at all.
run_fixture_gate 0 1 0
if grep -q '^cell=timing ' "$run_output" || grep -q '^gate_timing ' "$run_output"; then
    report_failure timing-off timing_lines_absent
fi
if [ "$(summary_field root)" != "$first_root" ]; then
    report_failure timing-off root_is_unmoved_by_timing
fi

# QWEN_GATE_SPARSE=0 runs every cell against the same warm cache.
run_fixture_gate 0 0
if ! marker_holds alpha; then
    report_failure sparse-off alpha_executes
fi
if [ "$(summary_field cells_run)" != 4 ]; then
    report_failure sparse-off counts_report_four_runs
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

# A cell reaching its dependency by Python module name in its own directory
# carries that module in its read set, so an edit to the module reruns the
# cell.
run_fixture_gate
printf 'MARGIN = 2\n' >"$fixture_root/remote/gamma_helper.py"
run_fixture_gate
if ! marker_holds gamma; then
    report_failure python-import gamma_reruns_on_the_imported_module
fi
run_fixture_gate
if marker_holds gamma; then
    report_failure python-import gamma_reuses_the_new_key
fi

# A cell reaching a bare import across a sibling directory through
# sys.path.insert carries that module in its read set too.
run_fixture_gate
printf 'MARGIN = 2\n' >"$fixture_root/remote/helpers/cross_helper.py"
run_fixture_gate
if ! marker_holds delta; then
    report_failure cross-directory-import delta_reruns_on_the_imported_module
fi
run_fixture_gate
if marker_holds delta; then
    report_failure cross-directory-import delta_reuses_the_new_key
fi

# A cell reaching a script named as a string literal across a sibling
# directory carries that script in its read set, the way
# image-mcp/test-image-mcp.py reaches remote/web-mcp/authorize-broker.py.
run_fixture_gate
printf '#\n' >>"$fixture_root/remote/helpers/cross-helper.sh"
run_fixture_gate
if ! marker_holds delta; then
    report_failure cross-directory-literal delta_reruns_on_the_named_script
fi
run_fixture_gate
if marker_holds delta; then
    report_failure cross-directory-literal delta_reuses_the_new_key
fi

# An extensionless executable script is read as text for what it names, so a
# change to the file it names reruns the cell that reaches it, though neither
# the extensionless script's own name nor the file it names carries a
# recognized extension the literal-filename reader could have matched without
# reading the script's content.
run_fixture_gate
printf '# cross\n' >>"$fixture_root/remote/helpers/cross-helper-data.tsv"
run_fixture_gate
if ! marker_holds delta; then
    report_failure extensionless-executable delta_reruns_on_the_named_data
fi
run_fixture_gate
if marker_holds delta; then
    report_failure extensionless-executable delta_reuses_the_new_key
fi

# The extensionless helper itself is named only as the bare last argument of
# os.path.join(HELPERS_DIRECTORY, "cross-helper") in delta-test.py, with no
# comment anywhere spelling its repository path, so an edit to its own bytes
# or mode bits reruns delta only if the reader resolved that bare reference by
# directory rather than by matching a literal string.
run_fixture_gate
printf '# cross-helper edit\n' >>"$fixture_root/remote/helpers/cross-helper"
run_fixture_gate
if ! marker_holds delta; then
    report_failure bare-name-helper delta_reruns_on_the_helper_edit
fi
run_fixture_gate
if marker_holds delta; then
    report_failure bare-name-helper delta_reuses_the_new_key
fi

# A mode change to the same bare-named helper moves the key too, holding it
# executable throughout so the reference keeps resolving: clearing the
# execute bit instead would fail the bare-name resolver's own `-x` test and
# move the whole cell to unbounded rather than moving its key, which is a
# different case from the mode-bit section below that exercises exactly that
# transition on a filename-matched member.
chmod 0700 "$fixture_root/remote/helpers/cross-helper"
run_fixture_gate
if ! marker_holds delta; then
    report_failure bare-name-helper delta_reruns_on_the_helper_mode_change
fi
run_fixture_gate
if marker_holds delta; then
    report_failure bare-name-helper delta_reuses_the_new_mode_key
fi
# Restoring 0755 alone would collide with the record the reuse check above
# already cached for this content at that mode, so a further edit keeps the
# transition unambiguous.
printf '# cross-helper mode-restore\n' >>"$fixture_root/remote/helpers/cross-helper"
chmod 0755 "$fixture_root/remote/helpers/cross-helper"
run_fixture_gate
if ! marker_holds delta; then
    report_failure bare-name-helper delta_reruns_after_restoring_the_mode
fi

# A cleared or set execute bit moves the key, because the gate runs several
# cells by invoking their script directly and a mode change alone decides
# whether that invocation reaches the interpreter. 0644 and 0755 are already
# cached for the file's current content from the script-edit section above, so
# the content is freshened once here before cycling through modes -- otherwise
# a later revisit to either mode would collide with that old record and reuse
# rather than exercise the mode read.
printf '# mode-set\n' >>"$fixture_root/remote/alpha-test.sh"
chmod 0755 "$fixture_root/remote/alpha-test.sh"
run_fixture_gate
if ! marker_holds alpha; then
    report_failure file-mode alpha_reruns_on_the_execute_bit
fi
run_fixture_gate
if marker_holds alpha; then
    report_failure file-mode alpha_reuses_the_new_key
fi

# Clearing the execute bit back off moves the key too, with the file's content
# held fixed against the 0755 record above so the mode change is the only
# variable that moves it.
chmod 0644 "$fixture_root/remote/alpha-test.sh"
run_fixture_gate
if ! marker_holds alpha; then
    report_failure file-mode alpha_reruns_on_the_cleared_execute_bit
fi
run_fixture_gate
if marker_holds alpha; then
    report_failure file-mode alpha_reuses_the_new_key
fi

# A mode change that leaves the file executable in both states still moves the
# key, because the manifest carries the full permission bits rather than a
# coarse exec/plain class. 0700 has never been cached for any content in this
# run, so the transition from 0644 above is unambiguous without a further
# content edit.
chmod 0700 "$fixture_root/remote/alpha-test.sh"
run_fixture_gate
if ! marker_holds alpha; then
    report_failure file-mode alpha_reruns_on_narrowed_permission_bits
fi
run_fixture_gate
if marker_holds alpha; then
    report_failure file-mode alpha_reuses_the_new_key
fi

# Restore 0755 for the sections that follow, with a further content edit so
# the restored mode does not collide with the 0755 record cached above.
printf '# mode-restore\n' >>"$fixture_root/remote/alpha-test.sh"
chmod 0755 "$fixture_root/remote/alpha-test.sh"
run_fixture_gate
if ! marker_holds alpha; then
    report_failure file-mode alpha_reruns_after_restoring_execute_permissions
fi

# The tool digest names every executable a cell's verdict depends on, so a
# replacement browser reruns the cells an accepted record covers.
for required_tool_name in shellcheck ruff python3 cc c++ bash sh node mypy \
    git curl flock ps sha256sum chromium; do
    if ! QWEN_CHROMIUM="$fixture_chromium" sh -c \
        ". \"$script_directory/gate-cell-key.sh\"; gate_cell_tool_versions" |
        grep -q "^$required_tool_name	"; then
        report_failure tool-digest "names_$required_tool_name"
    fi
done
printf '#!/bin/sh\nprintf "Chromium 141.0.0.0 fixture\\n"\n' >"$fixture_chromium"
chmod 0755 "$fixture_chromium"
run_fixture_gate
if ! marker_holds alpha; then
    report_failure tool-digest alpha_reruns_on_the_browser_version
fi

# `sh` is the interpreter every `sh remote/NAME.sh` cell command names and the
# one the gate's own driver runs under, so its identity moves every bounded
# cell's key the way bash's, python3's, and the browser's already do.
run_fixture_gate
if ! PATH="$fixture_sh_directory:$PATH" run_fixture_gate; then
    report_failure tool-digest fixture_sh_still_runs_the_gate
fi
if ! marker_holds alpha; then
    report_failure tool-digest alpha_reruns_on_the_sh_version
fi
if ! PATH="$fixture_sh_directory:$PATH" run_fixture_gate; then
    report_failure tool-digest fixture_sh_still_runs_the_gate
fi
if marker_holds alpha; then
    report_failure tool-digest alpha_reuses_the_new_sh_key
fi

# The driver and this reader are bound into every key, so an edit to either one
# reruns every bounded cell even though no cell names either file in its own
# spec.
run_fixture_gate
printf '# driver edit\n' >>"$fixture_root/remote/gate.sh"
run_fixture_gate
if ! marker_holds alpha || ! marker_holds gamma || ! marker_holds delta; then
    report_failure driver-identity every_bounded_cell_reruns_on_a_driver_edit
fi
run_fixture_gate
if marker_holds alpha || marker_holds gamma || marker_holds delta; then
    report_failure driver-identity bounded_cells_reuse_the_new_driver_key
fi

printf '# reader edit\n' >>"$fixture_root/remote/gate-cell-key.sh"
run_fixture_gate
if ! marker_holds alpha || ! marker_holds gamma || ! marker_holds delta; then
    report_failure reader-identity every_bounded_cell_reruns_on_a_reader_edit
fi
run_fixture_gate
if marker_holds alpha || marker_holds gamma || marker_holds delta; then
    report_failure reader-identity bounded_cells_reuse_the_new_reader_key
fi

# A GATE_CELL_DRIVER_PATH naming a file the tree lacks refuses at init rather
# than silently keying every cell on `absent` and still reusing from run to
# run, which is what would let a typo in the driver's own path defeat the
# binding above.
cat >"$fixture_root/remote/bad-driver-gate.sh" <<'FIXTURE'
#!/bin/sh
set -eu
gate_script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
gate_fixture_root=$(CDPATH='' cd -- "$gate_script_directory/.." && pwd)
cd "$gate_fixture_root"
GATE_CELL_ROOT=$gate_fixture_root
export GATE_CELL_ROOT
GATE_CELL_DRIVER_PATH=$gate_script_directory/does-not-exist.sh
export GATE_CELL_DRIVER_PATH
. "$gate_script_directory/gate-cell-key.sh"
gate_cell_init
FIXTURE
if sh "$fixture_root/remote/bad-driver-gate.sh" \
    >"$work_directory/bad-driver.out" 2>"$work_directory/bad-driver.err"; then
    report_failure driver-identity bad_driver_path_is_refused
fi
if ! grep -q 'gate_cell_driver_path names no file' "$work_directory/bad-driver.err"; then
    report_failure driver-identity bad_driver_path_reports_why
fi

# The persisted record states its own read-set class explicitly rather than
# leaving it to be inferred from whether the cell always runs.
alpha_key=$(sed -n 's/^cell=reused key=\([0-9a-f]*\) name=alpha$/\1/p' \
    "$run_output")
if [ -z "$alpha_key" ]; then
    run_fixture_gate
    alpha_key=$(sed -n 's/^cell=run key=\([0-9a-f]*\) name=alpha.*$/\1/p' \
        "$run_output")
fi
if ! grep -qx 'read_set=bounded' "$cache_directory/cells/$alpha_key"; then
    report_failure read-set-record alpha_record_states_bounded
fi
beta_key=$(sed -n 's/^cell=run key=\([0-9a-f]*\) name=beta.*$/\1/p' \
    "$run_output")
if [ -z "$beta_key" ]; then
    report_failure read-set-record beta_key_is_reported
elif ! grep -qx 'read_set=unbounded' "$cache_directory/cells/$beta_key"; then
    report_failure read-set-record beta_record_states_unbounded
fi

# A bare os.path.join(...) leaf that names neither an existing executable
# file nor an existing directory in any directory the reference resolves
# against marks the read set unbounded, since the reader found a spawn target
# it cannot bound rather than a prose word that happens to share a directory's
# spelling.
missing_helper_root=$work_directory/missing-helper-tree
mkdir -p "$missing_helper_root/remote/helpers"
cat >"$missing_helper_root/remote/zeta-test.py" <<'FIXTURE'
import os

ZETA_DIRECTORY = os.path.dirname(os.path.abspath(__file__))
HELPERS_DIRECTORY = os.path.join(ZETA_DIRECTORY, "helpers")
SPAWN_TARGET = os.path.join(HELPERS_DIRECTORY, "does-not-exist-helper")
FIXTURE
zeta_status=0
GATE_CELL_ROOT="$missing_helper_root" sh -c \
    ". \"$script_directory/gate-cell-key.sh\"; gate_cell_read_set remote/zeta-test.py" \
    >"$work_directory/zeta.out" 2>"$work_directory/zeta.err" || zeta_status=$?
if [ "$zeta_status" -ne 3 ]; then
    report_failure bare-name-unresolved zeta_read_set_is_unbounded
fi

# A helper reached through a directory a script composes purely from two of
# its own DIRECTORY constants -- LEAF_DIRECTORY built by joining
# ETA_DIRECTORY with the bare name `only-helpers`, holding no .py module of
# its own -- still resolves, since gate_cell_named_directories takes the one
# further hop through a bare token that itself names a directory rather than
# relying on that directory happening to hold a Python module the way
# remote/helpers does in the delta fixture above.
directory_composition_root=$work_directory/directory-composition-tree
mkdir -p "$directory_composition_root/remote/only-helpers"
cat >"$directory_composition_root/remote/only-helpers/leaf-helper" <<'FIXTURE'
#!/bin/sh
set -eu
exit 0
FIXTURE
chmod 0755 "$directory_composition_root/remote/only-helpers/leaf-helper"
cat >"$directory_composition_root/remote/eta-test.py" <<'FIXTURE'
import os

ETA_DIRECTORY = os.path.dirname(os.path.abspath(__file__))
LEAF_DIRECTORY = os.path.join(ETA_DIRECTORY, "only-helpers")
LEAF_TARGET = os.path.join(LEAF_DIRECTORY, "leaf-helper")
FIXTURE
eta_status=0
GATE_CELL_ROOT="$directory_composition_root" sh -c \
    ". \"$script_directory/gate-cell-key.sh\"; gate_cell_read_set remote/eta-test.py" \
    >"$work_directory/eta.out" 2>"$work_directory/eta.err" || eta_status=$?
if [ "$eta_status" -ne 0 ]; then
    report_failure directory-composition eta_read_set_is_bounded
fi
if ! grep -qx 'remote/only-helpers/leaf-helper' "$work_directory/eta.out"; then
    report_failure directory-composition eta_read_set_carries_the_leaf
fi

# gate_cell_bare_names_are_unresolved binds a bare name to the one directory
# gate_cell_directory_variable_map traces its own call's first argument to,
# not to any candidate directory that happens to hold a same-named
# executable. The decoy sits directly under remote/, which
# gate_cell_module_search_directories always reports and gate_cell_named_directories
# would therefore always search under the old, unscoped design this replaces --
# proving the binding is real rather than incidentally correct because the
# decoy's directory was never a candidate at all. THETA_DIRECTORY also
# exercises the third assignment pattern, NAME = os.path.dirname(OTHER_DIRECTORY),
# the way remote/image-mcp/server.py derives REMOTE_DIRECTORY from its own
# SERVER_DIRECTORY.
decoy_root=$work_directory/decoy-directory-tree
mkdir -p "$decoy_root/remote/nested" "$decoy_root/remote/actual-helpers"
cat >"$decoy_root/remote/nested/theta-test.py" <<'FIXTURE'
import os

NESTED_DIRECTORY = os.path.dirname(os.path.abspath(__file__))
THETA_DIRECTORY = os.path.dirname(NESTED_DIRECTORY)
HELPER_DIRECTORY = os.path.join(THETA_DIRECTORY, "actual-helpers")
TARGET = os.path.join(HELPER_DIRECTORY, "shared-name-helper")
FIXTURE
cat >"$decoy_root/remote/shared-name-helper" <<'FIXTURE'
#!/bin/sh
set -eu
exit 0
FIXTURE
chmod 0755 "$decoy_root/remote/shared-name-helper"
theta_status=0
GATE_CELL_ROOT="$decoy_root" sh -c \
    ". \"$script_directory/gate-cell-key.sh\"; gate_cell_read_set remote/nested/theta-test.py" \
    >"$work_directory/theta.out" 2>"$work_directory/theta.err" || theta_status=$?
if [ "$theta_status" -ne 3 ]; then
    report_failure decoy-directory-binding theta_stays_unbounded_before_the_real_target_exists
fi
cat >"$decoy_root/remote/actual-helpers/shared-name-helper" <<'FIXTURE'
#!/bin/sh
set -eu
exit 0
FIXTURE
chmod 0755 "$decoy_root/remote/actual-helpers/shared-name-helper"
theta_status=0
GATE_CELL_ROOT="$decoy_root" sh -c \
    ". \"$script_directory/gate-cell-key.sh\"; gate_cell_read_set remote/nested/theta-test.py" \
    >"$work_directory/theta.out" 2>"$work_directory/theta.err" || theta_status=$?
if [ "$theta_status" -ne 0 ]; then
    report_failure decoy-directory-binding theta_resolves_once_the_real_target_exists
fi
if ! grep -qx 'remote/actual-helpers/shared-name-helper' "$work_directory/theta.out"; then
    report_failure decoy-directory-binding theta_read_set_carries_the_real_target
fi

if [ "$failures" -ne 0 ]; then
    printf 'gate_cell_test=rejected failures=%s\n' "$failures" >&2
    exit 1
fi

printf 'gate_cell_test=accepted\n'
