#!/bin/sh
set -eu

# Two regressions close the observability gap a shared telemetry.log left: a
# later session preserves an earlier session's record byte for byte, and the
# convenience symlink advances while the recorded session-unique path still
# resolves and still verifies against its retained digest. The record is
# session-unique and sealed read-only rather than immutable, since its owner
# restores the write bit at will.

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
work_directory=$(mktemp -d)
trap 'chmod -R u+w "$work_directory" 2>/dev/null || true; rm -rf "$work_directory"' \
    EXIT HUP INT TERM

state_directory=$work_directory/state
mkdir -p "$state_directory/telemetry"
legacy_preserver=$script_directory/preserve-legacy-telemetry.sh

# The first upgraded launch must retain the regular shared record that predates
# session-unique telemetry. The helper moves the bytes to their digest-derived
# record before the launcher creates the convenience symlink.
legacy_shared=$state_directory/telemetry.log
printf 'legacy terminating sample\n' >"$legacy_shared"
legacy_digest=$(sha256sum "$legacy_shared" | cut -d ' ' -f 1)
legacy_record=$state_directory/telemetry/legacy-shared-$legacy_digest.log
"$legacy_preserver" "$legacy_shared" "$state_directory/telemetry" >/dev/null
if [ -e "$legacy_shared" ] || [ -L "$legacy_shared" ]; then
    printf 'legacy shared telemetry path survived migration\n' >&2
    exit 1
fi
if [ "$(sha256sum "$legacy_record" | cut -d ' ' -f 1)" != "$legacy_digest" ]; then
    printf 'legacy telemetry migration changed the retained bytes\n' >&2
    exit 1
fi

# A retry with identical content converges on the same retained record. A
# conflicting occupant at the digest-derived destination refuses the migration.
printf 'legacy terminating sample\n' >"$legacy_shared"
"$legacy_preserver" "$legacy_shared" "$state_directory/telemetry" >/dev/null
if [ -e "$legacy_shared" ] || [ -L "$legacy_shared" ]; then
    printf 'repeated legacy migration left the shared file behind\n' >&2
    exit 1
fi
printf 'conflicting bytes\n' >"$legacy_record"
printf 'legacy terminating sample\n' >"$legacy_shared"
if "$legacy_preserver" "$legacy_shared" "$state_directory/telemetry" \
    >/dev/null 2>"$work_directory/legacy-conflict.stderr"; then
    printf 'legacy migration overwrote a conflicting retained record\n' >&2
    exit 1
fi
if ! grep -q 'destination differs from shared bytes' \
    "$work_directory/legacy-conflict.stderr"; then
    printf 'legacy migration conflict lost its reason\n' >&2
    exit 1
fi
rm "$legacy_shared" "$legacy_record"

write_session_record() {
    record_path=$1
    mem_available_kib=$2
    aborts=$3
    {
        printf 'monitor_start_utc=2026-08-31T21:04:12Z server_pid=18422 sample_seconds=1 profile=low-serialized latency_watchdog_pid=1 kernel_hazard_watchdog_pid=2 guard_affinity=0 guard_nice=19\n'
        printf 'threshold_mem_available_kib=4194304 threshold_swapin_bytes_per_sample=67108864 report_temperature_millicelsius=90000\n'
        printf 'threshold_maximum_gpu_busy_percent=99 enforcement=terminate_on_sample_above_threshold\n'
        printf 'sample_utc=2026-08-31T21:04:13Z affinity=0-1 nice=19 rss_kib=1000 peak_rss_kib=1000 mem_available_kib=8388608 swapin_bytes=0 max_temp_millicelsius=70000 gpu_busy_percent=10 gtt_used_bytes=100 vram_used_bytes=200 sclk=1100 mclk=933\n'
        printf 'sample_utc=2026-08-31T21:04:14Z affinity=0-1 nice=19 rss_kib=2000 peak_rss_kib=2500 mem_available_kib=%s swapin_bytes=4096 max_temp_millicelsius=88000 gpu_busy_percent=20 gtt_used_bytes=900 vram_used_bytes=800 sclk=1100 mclk=933\n' \
            "$mem_available_kib"
        if [ "$aborts" = yes ]; then
            printf 'abort_utc=2026-08-31T21:04:15Z reason=memory_reserve_breached\n'
            printf 'termination_utc=2026-08-31T21:04:15Z action=SIGTERM\n'
        else
            printf 'monitor_stop_utc=2026-08-31T21:04:15Z reason=server_exited\n'
        fi
    } >"$record_path"
}

# Session A aborts on the reserve. Its terminating sample is the quantity a
# later evidence document quotes, so it is what must survive.
session_a=$state_directory/telemetry/20260831T210412Z-model-a-pid18422.log
write_session_record "$session_a" 4194303 yes
ln -sfn "telemetry/20260831T210412Z-model-a-pid18422.log" \
    "$state_directory/telemetry.log"
session_a_digest=$(sha256sum "$session_a" | cut -d ' ' -f 1)

QWEN_TELEMETRY_MODEL_ID=model-a "$script_directory/summarize-telemetry-session.sh" \
    "$session_a" >/dev/null
summary_a=${session_a%.log}.summary

summary_field() {
    awk -F= -v key="$1" '$1 == key { print $2 }' "$2"
}

if [ "$(summary_field terminating_mem_available_kib "$summary_a")" != 4194303 ]; then
    printf 'summary lost the terminating sample\n' >&2
    exit 1
fi
if [ "$(summary_field termination_reason "$summary_a")" != memory_reserve_breached ]; then
    printf 'summary lost the termination reason\n' >&2
    exit 1
fi
if [ "$(summary_field observed_minimum_mem_available_kib "$summary_a")" != 4194303 ]; then
    printf 'summary miscomputed the observed minimum\n' >&2
    exit 1
fi
if [ "$(summary_field threshold_mem_available_kib "$summary_a")" != 4194304 ]; then
    printf 'summary lost the threshold, or confused it with the observation\n' >&2
    exit 1
fi
if [ "$(summary_field peak_server_rss_kib "$summary_a")" != 2500 ]; then
    printf 'summary miscomputed peak RSS\n' >&2
    exit 1
fi
if [ "$(summary_field cumulative_swapin_bytes "$summary_a")" != 4096 ]; then
    printf 'summary miscomputed cumulative swap-in\n' >&2
    exit 1
fi
if [ "$(summary_field telemetry_log_sha256 "$summary_a")" != "$session_a_digest" ]; then
    printf 'summary recorded a digest the record does not carry\n' >&2
    exit 1
fi

# Session B starts afterward and writes its own record.
session_b=$state_directory/telemetry/20260831T221500Z-model-b-pid19001.log
write_session_record "$session_b" 6291456 no
ln -sfn "telemetry/20260831T221500Z-model-b-pid19001.log" \
    "$state_directory/telemetry.log"

if [ "$(sha256sum "$session_a" | cut -d ' ' -f 1)" != "$session_a_digest" ]; then
    printf 'a later session rewrote an earlier record\n' >&2
    exit 1
fi
if [ ! -r "$session_a" ]; then
    printf 'the earlier record stopped resolving after a later session\n' >&2
    exit 1
fi

resolved=$(readlink -f "$state_directory/telemetry.log")
if [ "$resolved" != "$(readlink -f "$session_b")" ]; then
    printf 'the convenience symlink did not advance to the newest session\n' >&2
    exit 1
fi
if [ "$(summary_field terminating_mem_available_kib "$summary_a")" != 4194303 ]; then
    printf 'the retained summary changed when a later session started\n' >&2
    exit 1
fi

# A record with no abort states its absence rather than inheriting one.
QWEN_TELEMETRY_MODEL_ID=model-b "$script_directory/summarize-telemetry-session.sh" \
    "$session_b" >/dev/null
if [ "$(summary_field termination_reason "${session_b%.log}.summary")" != server_exited ]; then
    printf 'a completed session reported the wrong termination reason\n' >&2
    exit 1
fi
if [ "$(summary_field terminating_mem_available_kib "${session_b%.log}.summary")" != - ]; then
    printf 'a completed session invented a terminating sample\n' >&2
    exit 1
fi

# A loading record beside the session record yields loading-phase peaks, and a
# session without one reads `-` in every derived field rather than zero, which
# is what separates a pre-coverage record from an empty loading phase.
if [ "$(summary_field loading_sample_count "$summary_a")" != - ]; then
    printf 'a session without a loading record invented loading samples\n' >&2
    exit 1
fi
loading_b=${session_b%.log}-loading.log
{
    printf 'loading_start_utc=2026-08-31T22:14:55Z server_pid=19001 model=model-b.gguf\n'
    printf 'loading_sample_utc=2026-08-31T22:14:56Z rss_kib=500 peak_rss_kib=500 mem_available_kib=9437184 vram_used_bytes=100 gtt_used_bytes=50\n'
    printf 'loading_sample_utc=2026-08-31T22:14:57Z rss_kib=3500 peak_rss_kib=3500 mem_available_kib=5242880 vram_used_bytes=1900 gtt_used_bytes=70\n'
    printf 'loading_end_utc=2026-08-31T22:14:58Z ready=1 attempts=20\n'
} >"$loading_b"
QWEN_TELEMETRY_MODEL_ID=model-b "$script_directory/summarize-telemetry-session.sh" \
    "$session_b" >/dev/null
summary_b=${session_b%.log}.summary
if [ "$(summary_field loading_sample_count "$summary_b")" != 2 ]; then
    printf 'summary miscounted loading samples\n' >&2
    exit 1
fi
if [ "$(summary_field loading_peak_server_rss_kib "$summary_b")" != 3500 ]; then
    printf 'summary miscomputed the loading-phase RSS peak\n' >&2
    exit 1
fi
if [ "$(summary_field loading_observed_minimum_mem_available_kib "$summary_b")" != 5242880 ]; then
    printf 'summary miscomputed the loading-phase MemAvailable minimum\n' >&2
    exit 1
fi
if [ "$(summary_field loading_peak_vram_used_bytes "$summary_b")" != 1900 ]; then
    printf 'summary miscomputed the loading-phase VRAM peak\n' >&2
    exit 1
fi
if [ "$(summary_field loading_ready "$summary_b")" != 1 ]; then
    printf 'summary lost the loading-phase readiness outcome\n' >&2
    exit 1
fi

# The session script samples the loading phase inside its readiness loop and
# reports finalization with the session name as its own joinable field, through
# a guarded append that a read-only state directory cannot turn into an abort.
if ! grep -q 'record_loading_sample$' "$script_directory/qwen-webui-session.sh"; then
    printf 'the session script no longer samples the loading phase\n' >&2
    exit 1
fi
if ! grep -q 'session=%s telemetry_record=%s' \
    "$script_directory/qwen-webui-session.sh"; then
    printf 'the finalization line no longer names its session\n' >&2
    exit 1
fi
if ! grep -q 'telemetry-finalization.log" || :' \
    "$script_directory/qwen-webui-session.sh"; then
    printf 'the finalization append is unguarded under set -e\n' >&2
    exit 1
fi

# The session script names one record per launch and points the symlink at it.
if ! grep -q 'telemetry_directory=\$state_directory/telemetry' \
    "$script_directory/qwen-webui-session.sh"; then
    printf 'the session script no longer owns a telemetry directory\n' >&2
    exit 1
fi
if ! grep -q 'ln -sfn "telemetry/\$telemetry_session_name.log"' \
    "$script_directory/qwen-webui-session.sh"; then
    printf 'the session script no longer advances the convenience symlink\n' >&2
    exit 1
fi

printf 'telemetry_session_records=accepted session_unique_record=yes sealed=read_only symlink_advances=yes\n'
