#!/bin/sh
set -eu

# Prove the gate wrapper establishes the environment it exists to establish.
#
# The wrapper's whole value is the invocation, so each arm reads what the
# driver actually received rather than what the wrapper's own text claims. A
# stub driver stands in for `repository-quality-gates.sh` and reports its PID
# namespace, its procfs view, the variables reaching it, and its working
# directory; the arms then read that report. The stub also lets a rejection
# and an interruption run in seconds, which the real driver's thirty minutes
# would put out of reach of a gate cell.
#
# usage: test-run-repository-gate.sh

if [ "$#" -ne 0 ]; then
    printf 'usage: %s\n' "$0" >&2
    exit 2
fi

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
wrapper=$script_directory/run-repository-gate.sh

work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT

failures=0
report() {
    if [ "$2" = ok ]; then
        printf 'ok %s\n' "$1"
    else
        printf 'FAIL %s: %s\n' "$1" "$2"
        failures=$((failures + 1))
    fi
}

# A fixture worktree carries `.git` as neither a directory nor a file, which
# is what separates it from the production checkout the wrapper refuses.
fixture_tree=$work/tree
mkdir -p "$fixture_tree/remote"
git -C "$fixture_tree" init -q
git -C "$fixture_tree" config user.email fixture@example.invalid
git -C "$fixture_tree" config user.name fixture
: >"$fixture_tree/marker"
git -C "$fixture_tree" add marker
git -C "$fixture_tree" commit -q -m 'fixture'
fixture_head=$(git -C "$fixture_tree" rev-parse HEAD)

# The wrapper refuses a tree carrying `.git` as a directory, so the fixture
# runs from a linked worktree the way an ordinary cluster does.
linked_tree=$work/linked
git -C "$fixture_tree" worktree add -q --detach "$linked_tree" HEAD
mkdir -p "$linked_tree/remote"

write_driver() {
    cat >"$linked_tree/remote/repository-quality-gates.sh" <<STUB
#!/bin/sh
set -eu
{
    printf 'stub_pid=%s\n' "\$\$"
    printf 'stub_pid1_comm=%s\n' "\$(cat /proc/1/comm 2>/dev/null || printf unreadable)"
    printf 'stub_self_stat_readable=%s\n' "\$([ -r /proc/\$\$/stat ] && printf yes || printf no)"
    printf 'stub_qwen_home=%s\n' "\${QWEN_HOME-unset}"
    printf 'stub_cache=%s\n' "\${QWEN_GATE_CACHE_DIR-unset}"
    printf 'stub_leases=%s\n' "\${QWEN_TEST_PORT_LEASE_DIR-unset}"
    printf 'stub_cwd=%s\n' "\$(pwd)"
} >"$work/driver-report.txt"
printf 'cell=run key=aaa name=one read_set=universal\n'
printf 'cell=timing key=aaa name=one decision=run key_ns=1 run_ns=2\n'
printf 'cell=reused key=bbb name=two\n'
$1
STUB
    chmod 755 "$linked_tree/remote/repository-quality-gates.sh"
}

result_root=$work/results
cache_directory=$work/cache

# ---- an accepted run reports accepted and retains one terminal result ----
write_driver "printf 'gate=accepted cells_run=1 cells_reused=1 root=deadbeef\\n'; printf 'repository_quality_gates=accepted\\n'"
accepted_log=$work/accepted.log
if QWEN_HOME=$work/inherited-root sh "$wrapper" \
    -r "$result_root" -c "$cache_directory" "$linked_tree" \
    >"$accepted_log" 2>&1; then
    grep -q '^gate=accepted cells_run=1 cells_reused=1 cell_root=deadbeef$' "$accepted_log" \
        && report accepted_run_reports_its_cell_counts ok \
        || report accepted_run_reports_its_cell_counts "$(cat "$accepted_log")"
else
    report accepted_run_reports_its_cell_counts "$(cat "$accepted_log")"
fi

result_file=$(sed -n 's/^gate_result=//p' "$accepted_log")
if [ -f "${result_file:-/nonexistent}" ]; then
    report terminal_result_is_written ok
else
    report terminal_result_is_written "no result file at ${result_file:-none}"
fi

result_field() {
    awk -F'\t' -v key="$1" '$1 == key { print $2; exit }' "$result_file"
}

[ "$(result_field status)" = accepted ] \
    && report result_states_the_accepted_status ok \
    || report result_states_the_accepted_status "$(result_field status)"
[ "$(result_field head)" = "$fixture_head" ] \
    && report result_binds_the_gated_head ok \
    || report result_binds_the_gated_head "$(result_field head)"
[ "$(result_field cells_run)" = 1 ] && [ "$(result_field cells_reused)" = 1 ] \
    && [ "$(result_field cell_root)" = deadbeef ] \
    && report result_copies_the_driver_summary ok \
    || report result_copies_the_driver_summary \
        "run=$(result_field cells_run) reused=$(result_field cells_reused) root=$(result_field cell_root)"

# ---- the result directory outlives the worktree it gated ----
case $result_file in
    "$linked_tree"/*)
        report result_directory_is_outside_the_worktree "$result_file" ;;
    *)
        report result_directory_is_outside_the_worktree ok ;;
esac

# ---- the driver runs with the environment the wrapper establishes ----
driver_field() {
    awk -F= -v key="$1" '$1 == key { sub(/^[^=]*=/, ""); print; exit }' \
        "$work/driver-report.txt"
}

[ "$(driver_field stub_qwen_home)" = unset ] \
    && report driver_inherits_no_qwen_home ok \
    || report driver_inherits_no_qwen_home "$(driver_field stub_qwen_home)"
[ "$(driver_field stub_cache)" = "$cache_directory" ] \
    && report driver_reads_the_shared_cell_cache ok \
    || report driver_reads_the_shared_cell_cache "$(driver_field stub_cache)"
[ "$(driver_field stub_cwd)" = "$linked_tree" ] \
    && report driver_runs_in_the_named_worktree ok \
    || report driver_runs_in_the_named_worktree "$(driver_field stub_cwd)"

# The lease directory belongs to the run rather than to a shared location, so
# an interrupted run's holder cannot outlive its own directory into the next.
case $(driver_field stub_leases) in
    "$result_root"/*) report lease_directory_belongs_to_the_run ok ;;
    *) report lease_directory_belongs_to_the_run "$(driver_field stub_leases)" ;;
esac

# ---- the driver is init of its own PID namespace with a matching procfs ----
# `--unshare-pid` makes the wrapper's child PID 1 there, and `--proc /proc`
# is what makes that namespace's own procfs readable; a run carrying the host
# procfs reads another process at /proc/1 and fails this pair together.
[ "$(driver_field stub_self_stat_readable)" = yes ] \
    && report driver_reads_its_own_proc_entry ok \
    || report driver_reads_its_own_proc_entry "$(driver_field stub_self_stat_readable)"
case $(driver_field stub_pid1_comm) in
    systemd | init) report driver_runs_in_its_own_pid_namespace "host init at /proc/1: $(driver_field stub_pid1_comm)" ;;
    unreadable) report driver_runs_in_its_own_pid_namespace 'procfs carries no /proc/1' ;;
    *) report driver_runs_in_its_own_pid_namespace ok ;;
esac

# ---- a rejected driver reports rejected and still writes a result ----
write_driver "printf 'cell=rejected key=ccc name=three\\n'; exit 1"
rejected_log=$work/rejected.log
if QWEN_HOME=$work/inherited-root sh "$wrapper" \
    -r "$result_root" -c "$cache_directory" "$linked_tree" \
    >"$rejected_log" 2>&1; then
    report rejected_run_exits_nonzero 'the wrapper accepted a failing driver'
else
    grep -q '^gate=rejected' "$rejected_log" \
        && report rejected_run_exits_nonzero ok \
        || report rejected_run_exits_nonzero "$(cat "$rejected_log")"
fi
rejected_result=$(sed -n 's/^gate_result=//p' "$rejected_log")
if [ -f "${rejected_result:-/nonexistent}" ] &&
    awk -F'\t' '$1 == "status" && $2 == "rejected" { found = 1 } END { exit !found }' \
        "$rejected_result"; then
    report rejected_run_retains_its_result ok
else
    report rejected_run_retains_its_result "no rejected result at ${rejected_result:-none}"
fi

# A driver exiting zero without its terminal line is a truncated run rather
# than an accepted one, so the wrapper reads the line rather than the status.
write_driver "printf 'cell=accepted key=ddd name=four\\n'"
truncated_log=$work/truncated.log
if QWEN_HOME=$work/inherited-root sh "$wrapper" \
    -r "$result_root" -c "$cache_directory" "$linked_tree" \
    >"$truncated_log" 2>&1; then
    report truncated_run_is_rejected 'a driver without its terminal line was accepted'
else
    grep -q '^gate=rejected' "$truncated_log" \
        && report truncated_run_is_rejected ok \
        || report truncated_run_is_rejected "$(cat "$truncated_log")"
fi

# ---- an interrupted run leaves an interrupted result and no children ----
write_driver "sleep 300 & printf '%s\\n' \"\$!\" >\"$work/stub-child.pid\"; wait"
interrupted_log=$work/interrupted.log
QWEN_HOME=$work/inherited-root sh "$wrapper" \
    -r "$result_root" -c "$cache_directory" "$linked_tree" \
    >"$interrupted_log" 2>&1 &
wrapper_pid=$!
waited=0
while [ "$waited" -lt 30 ]; do
    grep -q '^gate_result_directory=' "$interrupted_log" 2>/dev/null && break
    sleep 1
    waited=$((waited + 1))
done
kill -TERM "$wrapper_pid" 2>/dev/null || true
wait "$wrapper_pid" 2>/dev/null || true
interrupted_directory=$(sed -n 's/^gate_result_directory=//p' "$interrupted_log")
if [ -f "${interrupted_directory:-/nonexistent}/result.tsv" ] &&
    awk -F'\t' '$1 == "status" && $2 == "interrupted" { found = 1 } END { exit !found }' \
        "$interrupted_directory/result.tsv"; then
    report interrupted_run_retains_an_interrupted_result ok
else
    report interrupted_run_retains_an_interrupted_result \
        "no interrupted result under ${interrupted_directory:-none}"
fi

# `--die-with-parent` ends the namespace with this wrapper, so the stub's own
# child leaves with it rather than outliving the run against a directory it is
# done with. The arm reads the recorded PID rather than every `sleep` on the
# machine, since a concurrent run of this test would otherwise fail on the
# other run's child.
sleep 2
stub_child=$(cat "$work/stub-child.pid" 2>/dev/null || true)
if [ -z "$stub_child" ]; then
    report interrupted_run_releases_its_children 'the stub recorded no child'
elif kill -0 "$stub_child" 2>/dev/null; then
    report interrupted_run_releases_its_children "stub child $stub_child survived the interruption"
else
    report interrupted_run_releases_its_children ok
fi

# ---- the production checkout is refused ----
cp "$linked_tree/remote/repository-quality-gates.sh" \
    "$fixture_tree/remote/repository-quality-gates.sh"
production_log=$work/production.log
if sh "$wrapper" -r "$result_root" -c "$cache_directory" "$fixture_tree" \
    >"$production_log" 2>&1; then
    report production_checkout_is_refused 'the wrapper gated a production checkout'
else
    grep -q 'gate from a linked worktree' "$production_log" \
        && report production_checkout_is_refused ok \
        || report production_checkout_is_refused "$(cat "$production_log")"
fi

# ---- an absent driver is refused before any namespace is entered ----
absent_tree=$work/absent
mkdir -p "$absent_tree/remote"
absent_log=$work/absent.log
if sh "$wrapper" -r "$result_root" -c "$cache_directory" "$absent_tree" \
    >"$absent_log" 2>&1; then
    report absent_driver_is_refused 'the wrapper ran without a gate driver'
else
    grep -q 'gate driver is absent' "$absent_log" \
        && report absent_driver_is_refused ok \
        || report absent_driver_is_refused "$(cat "$absent_log")"
fi

if [ "$failures" -ne 0 ]; then
    printf 'run_repository_gate=failed failures=%s\n' "$failures" >&2
    exit 1
fi
printf 'run_repository_gate=passed\n'
