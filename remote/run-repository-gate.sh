#!/bin/sh
set -eu

# The one invocation every gate run uses.
#
# `repository-quality-gates.sh` reaches fixtures that read `/proc/PID/stat`,
# claim loopback ports, and resolve the runtime root per fixture, so the
# environment it starts in decides whether a rejection names the tree or the
# harness. Three properties of that environment are what this wrapper exists
# to establish, and each has a failure this tree has already measured.
#
# `--unshare-pid` puts the run in its own PID namespace, so a fixture that
# enumerates processes reads its own children rather than another session's
# `llama-server` on a shared workstation, and `--die-with-parent` is what
# makes that namespace end with this wrapper: bwrap's forked child is the
# namespace's init while bwrap itself stays outside it, so an interrupted run
# otherwise leaves the driver and every lease holder it started running
# against a result directory the run is done with. `--proc /proc` is required
# beside them: `--dev-bind / /` carries the host's procfs in, `$!` is then a namespace
# PID that resolves to nothing there, and `searxng-launch.sh`'s
# `process_start_time` reads an absent `/proc/PID/stat` and reports `the
# instance left before its identity could be read`. The pairing isolates
# process identity alone -- the network namespace, the filesystem, and the
# user namespace stay the host's, so two runs still contend for a loopback
# port and a bind mount still reaches every file the caller can reach.
#
# `QWEN_HOME` leaves the entry point unset. `qwen-home.sh` derives the root
# from the tree that holds `remote/`, so each fixture resolves the root of
# the tree it is testing, and an inherited value makes a launch refuse a
# fixture's own temporary root as foreign. A fixture that sets its own
# isolated root is doing what the resolver is for; what this wrapper removes
# is the caller's.
#
# The gate cache is separate from the runtime root, so `QWEN_GATE_CACHE_DIR`
# shares accepted cells across worktrees without pointing any fixture at
# another tree's `.runtime`. The port lease is not shared: every run takes a
# fresh directory, since a lease holder outlives an interrupted run by its
# own sleep and a directory cleared under a live holder releases a port the
# holder still answers for.
#
# usage: run-repository-gate.sh [-r RESULT_ROOT] [-c CACHE_DIR] [WORKTREE]
#   WORKTREE      tree to gate, default the tree holding this script
#   -r            directory the run's result is written under, default
#                 QWEN_GATE_RESULT_ROOT or a `qwen-gate` directory under
#                 TMPDIR. It sits outside the worktree so the terminal
#                 result survives `git worktree remove`.
#   -c            gate cell cache, default QWEN_GATE_CACHE_DIR or a
#                 `qwen-gate-cache` directory under TMPDIR shared by every
#                 run this wrapper starts.

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)

result_root=${QWEN_GATE_RESULT_ROOT:-${TMPDIR:-/tmp}/qwen-gate}
cache_directory=${QWEN_GATE_CACHE_DIR:-${TMPDIR:-/tmp}/qwen-gate-cache}

while getopts r:c: option; do
    case $option in
        r) result_root=$OPTARG ;;
        c) cache_directory=$OPTARG ;;
        *)
            printf 'usage: %s [-r RESULT_ROOT] [-c CACHE_DIR] [WORKTREE]\n' "$0" >&2
            exit 2
            ;;
    esac
done
shift $((OPTIND - 1))

if [ "$#" -gt 1 ]; then
    printf 'usage: %s [-r RESULT_ROOT] [-c CACHE_DIR] [WORKTREE]\n' "$0" >&2
    exit 2
fi

worktree=${1:-$(CDPATH='' cd -- "$script_directory/.." && pwd)}
if [ ! -d "$worktree" ]; then
    printf '%s: worktree is absent: %s\n' "$0" "$worktree" >&2
    exit 2
fi
worktree=$(CDPATH='' cd -- "$worktree" && pwd)

# `test-runtime-root` refuses inside the production checkout, because the
# marker binds that root to the tree the appliance serves from. A linked
# worktree carries `.git` as a file and a fixture tree carries none, which is
# the same discriminator `runtime-root.sh` applies.
if [ -d "$worktree/.git" ]; then
    printf '%s: %s is a production checkout; gate from a linked worktree, which AGENTS.md names the home of\n' \
        "$0" "$worktree" >&2
    exit 2
fi

gate_driver=$worktree/remote/repository-quality-gates.sh
if [ ! -x "$gate_driver" ]; then
    printf '%s: gate driver is absent or unexecutable: %s\n' "$0" "$gate_driver" >&2
    exit 2
fi

for required_command in bwrap git flock; do
    if ! command -v "$required_command" >/dev/null 2>&1; then
        printf '%s: required command is absent: %s\n' "$0" "$required_command" >&2
        exit 2
    fi
done

head_commit=$(git -C "$worktree" rev-parse HEAD)
# Two runs of one head inside one second are ordinary -- a fast rejection and
# its rerun -- so the directory carries a unique suffix beside the readable
# stamp rather than refusing the second run.
mkdir -p "$result_root"
result_directory=$(mktemp -d "$result_root/$(date -u '+%Y%m%dT%H%M%SZ')-$(printf '%s' "$head_commit" | cut -c1-8).XXXXXX")
run_identity=${result_directory##*/}

# One lease directory per run. Two runs that name one directory serialize
# against each other; two that name different ones coordinate over nothing,
# so a workstation gating two repositories at once passes one directory to
# both rather than relying on this default.
lease_directory=$result_directory/port-leases
mkdir -p "$lease_directory"

gate_log=$result_directory/gate.log
result_file=$result_directory/result.tsv
mkdir -p "$cache_directory"

# The terminal result is written from the wrapper rather than parsed out of
# the log, so a run killed part way leaves `status=interrupted` behind rather
# than an absent file a reader would have to interpret.
gate_status=interrupted
gate_exit=143
gate_pid=

# `gate_cell_summary` ends an accepted run with its own counts and the root
# digest over every cell key, so the result copies that line rather than
# recounting it: the driver emits `cell=run`, `cell=reused`, `cell=timing`,
# and `cell=rejected`, and a wrapper keeping a second tally of those tokens
# states a number the driver never agreed to. A rejected run reaches no
# summary, so its counts come from the rejected lines alone.
read_summary_field() {
    awk -v key="$1" '
        /^gate=/ {
            for (field = 1; field <= NF; field++) {
                split($field, pair, "=")
                if (pair[1] == key) { print pair[2]; exit }
            }
        }
    ' "$gate_log"
}

write_result() {
    summary_run=-
    summary_reused=-
    summary_root=-
    rejected_cells=0
    if [ -f "$gate_log" ]; then
        rejected_cells=$(grep -c '^cell=rejected' "$gate_log" || true)
        summary_run=$(read_summary_field cells_run)
        summary_reused=$(read_summary_field cells_reused)
        summary_root=$(read_summary_field root)
    fi
    {
        printf 'field\tvalue\n'
        printf 'status\t%s\n' "$gate_status"
        printf 'exit\t%s\n' "$gate_exit"
        printf 'worktree\t%s\n' "$worktree"
        printf 'head\t%s\n' "$head_commit"
        printf 'run\t%s\n' "$run_identity"
        printf 'log\t%s\n' "$gate_log"
        printf 'cache\t%s\n' "$cache_directory"
        printf 'cells_run\t%s\n' "${summary_run:--}"
        printf 'cells_reused\t%s\n' "${summary_reused:--}"
        printf 'cells_rejected\t%s\n' "$rejected_cells"
        printf 'cell_root\t%s\n' "${summary_root:--}"
    } >"$result_file"
}

# The wrapper owns the run's children: `--unshare-pid` makes the bwrap
# process the namespace's init, so signalling it ends every descendant
# together, and a lease holder that outlives its own fixture leaves with it
# rather than sleeping out its hour against a directory this run is done
# with.
release_run() {
    if [ -n "$gate_pid" ] && kill -0 "$gate_pid" 2>/dev/null; then
        kill -TERM "$gate_pid" 2>/dev/null || true
        termination_wait=0
        while [ "$termination_wait" -lt 10 ]; do
            kill -0 "$gate_pid" 2>/dev/null || break
            sleep 1
            termination_wait=$((termination_wait + 1))
        done
        kill -KILL "$gate_pid" 2>/dev/null || true
    fi
    write_result
}

trap 'release_run; exit 143' HUP INT TERM

printf 'gate_run=%s worktree=%s head=%s\n' "$run_identity" "$worktree" "$head_commit"
printf 'gate_result_directory=%s\n' "$result_directory"

set +e
env -u QWEN_HOME \
    QWEN_GATE_CACHE_DIR="$cache_directory" \
    QWEN_TEST_PORT_LEASE_DIR="$lease_directory" \
    bwrap --unshare-pid --die-with-parent --dev-bind / / --proc /proc --chdir "$worktree" \
    "$gate_driver" >"$gate_log" 2>&1 &
gate_pid=$!
wait "$gate_pid"
gate_exit=$?
set -e
gate_pid=

if [ "$gate_exit" -eq 0 ] && grep -q '^repository_quality_gates=accepted$' "$gate_log"; then
    gate_status=accepted
else
    gate_status=rejected
fi

write_result

if [ "$gate_status" = rejected ]; then
    printf 'gate=rejected exit=%s\n' "$gate_exit" >&2
    grep '^cell=rejected' "$gate_log" >&2 || true
    printf 'a rejected cell is run standalone at main before it is read as caused by this branch; a failure at both heads names the invocation\n' >&2
    printf 'gate_result=%s\n' "$result_file"
    exit 1
fi

printf 'gate=accepted cells_run=%s cells_reused=%s cell_root=%s\n' \
    "$(read_summary_field cells_run)" "$(read_summary_field cells_reused)" \
    "$(read_summary_field root)"
printf 'gate_result=%s\n' "$result_file"
