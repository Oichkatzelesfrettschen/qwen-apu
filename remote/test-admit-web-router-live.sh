#!/bin/sh
set -eu

# remote/admit-web-router-live.sh owns the appliance: a real router, a real
# broker, and a real local SearXNG instance all start under it. This test
# exercises only what runs ahead of any of those -- the reused-OUTPUT_DIR
# refusal, and restore_ordinary's gating on whether an ordinary router was
# found running and on QWEN_ADMISSION_RESTORE -- reached through a broken
# model registry that fails the preset-generation step before a router, a
# broker, or a search instance would ever start. Neither arm launches a
# process, touches tmux, or reaches the network.

if [ "$#" -ne 0 ]; then
    printf 'usage: %s\n' "$0" >&2
    exit 2
fi

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT HUP INT TERM
failures=0

report() {
    printf '%s=%s\n' "$1" "$2"
    [ "$2" = ok ] || failures=$((failures + 1))
}

# This host's own llama-server, if any, must stay out of the gating arms
# below: a real one running here would make ordinary_running read 1 for a
# reason this test did not construct, and the harness would then attempt a
# real teardown and relaunch this test does not own.
if pgrep -x llama-server >/dev/null 2>&1; then
    printf 'test-admit-web-router-live: a real llama-server is running on this host; refusing to run\n' >&2
    exit 2
fi

state_directory=$work/state
mkdir -p "$state_directory"
# ordinary_server's identity is read with sha256sum whether or not a router
# was found running, so a workstation holding no llama.cpp build directory
# needs a real, executable file named for it regardless of which arm runs:
# an unreadable-as-executable QWEN_LLAMA_SERVER falls through to the
# hardcoded build directory fallback, which this workstation also lacks.
dummy_llama_server=$work/fake-llama-server
: >"$dummy_llama_server"
chmod +x "$dummy_llama_server"

# 1. A reused OUTPUT_DIR is refused before the run touches anything else.
reused_output=$work/reused-output
mkdir -p "$reused_output"
: >"$reused_output/stray-file"
if QWEN_WEBUI_STATE_DIRECTORY=$state_directory \
    "$script_directory/admit-web-router-live.sh" "$reused_output" web-compact \
    >"$work/reused.log" 2>"$work/reused.err"; then
    report reused_output_directory_refused accepted
elif grep -q 'output directory must be empty' "$work/reused.err"; then
    report reused_output_directory_refused ok
else
    report reused_output_directory_refused missing_message
    cat "$work/reused.err" >&2
fi

# An absent directory and an empty one both pass the same check and proceed to
# whatever this run's next input fails on, which the broken registry below
# supplies deliberately rather than the emptiness refusal misfiring on them.
absent_output=$work/absent-output
if QWEN_WEBUI_STATE_DIRECTORY=$state_directory \
    QWEN_LLAMA_SERVER=$dummy_llama_server \
    QWEN_MODEL_REGISTRY=$work/missing-registry.tsv \
    "$script_directory/admit-web-router-live.sh" "$absent_output" web-compact \
    >"$work/absent.log" 2>"$work/absent.err"; then
    report absent_output_directory_admitted accepted
elif grep -q 'output directory must be empty' "$work/absent.err"; then
    report absent_output_directory_admitted wrongly_refused
else
    report absent_output_directory_admitted ok
fi

# 2. restore_ordinary's relaunch is gated on whether an ordinary router was
# running at admission start. The broken registry fails preset generation,
# which calls restore_ordinary explicitly on that path -- well before a
# router, a broker, or a search instance would start -- and ordinary_running
# reads 0 because no llama-server ran on this host to begin with.
gated_output=$work/gated-output
if QWEN_WEBUI_STATE_DIRECTORY=$state_directory \
    QWEN_LLAMA_SERVER=$dummy_llama_server \
    QWEN_MODEL_REGISTRY=$work/missing-registry.tsv \
    QWEN_ADMISSION_RESTORE=1 \
    "$script_directory/admit-web-router-live.sh" "$gated_output" web-compact \
    >"$work/gated.log" 2>"$work/gated.err"; then
    report restore_gated_on_ordinary_running accepted
else
    outcome=ok
    grep -qF "$(printf 'ordinary_restore\tpass\tno ordinary router was running at admission start')" \
        "$gated_output/summary.tsv" || outcome=missing_row
    # No relaunch attempted means no relaunch log written for it.
    [ -e "$gated_output/ordinary-restore.log" ] && outcome=relaunch_attempted
    report restore_gated_on_ordinary_running "$outcome"
fi

# QWEN_ADMISSION_RESTORE=0 still tears down whatever test router this run
# started -- none, here, since the failure precedes any launch -- and skips
# only the relaunch, which the recorded row states explicitly.
skipped_output=$work/skipped-output
if QWEN_WEBUI_STATE_DIRECTORY=$state_directory \
    QWEN_LLAMA_SERVER=$dummy_llama_server \
    QWEN_MODEL_REGISTRY=$work/missing-registry.tsv \
    QWEN_ADMISSION_RESTORE=0 \
    "$script_directory/admit-web-router-live.sh" "$skipped_output" web-compact \
    >"$work/skipped.log" 2>"$work/skipped.err"; then
    report restore_skipped_on_admission_restore_0 accepted
else
    outcome=ok
    grep -qF "$(printf 'ordinary_restore\tskipped\tQWEN_ADMISSION_RESTORE=0')" \
        "$skipped_output/summary.tsv" || outcome=missing_row
    report restore_skipped_on_admission_restore_0 "$outcome"
fi

if [ "$failures" -ne 0 ]; then
    printf 'test-admit-web-router-live: %d check(s) failed\n' "$failures" >&2
    exit 1
fi
printf 'test-admit-web-router-live: all checks passed\n'
