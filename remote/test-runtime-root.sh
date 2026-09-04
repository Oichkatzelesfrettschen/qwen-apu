#!/bin/sh
# runtime-root.sh over a scratch root: init lays out the layout and the
# marker, status enumerates every component present or absent, doctor
# reports seeded legacy and foreign paths without touching them, uninstall
# keeps state and models, purge and purge-legacy refuse without their opt-in
# and act on exactly the enumerated paths with it, and a directory carrying
# no marker is never removed.
set -eu
script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
tool=$script_directory/runtime-root.sh
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT HUP INT TERM
failures=0
report() {
    if [ "$2" = ok ]; then printf 'ok %s\n' "$1"; else printf 'FAIL %s: %s\n' "$1" "$2"; failures=$((failures + 1)); fi
}
export QWEN_HOME=$work/root

# ---- init ----
"$tool" init >/dev/null
[ -f "$QWEN_HOME/.qwen-runtime-root" ] && grep -q '^runtime_schema_version=1$' "$QWEN_HOME/.qwen-runtime-root" \
    && report init_writes_marker ok || report init_writes_marker missing
missing=''
for d in bin opt models deployments state cache tmp results; do [ -d "$QWEN_HOME/$d" ] || missing="$missing $d"; done
[ -z "$missing" ] && report init_lays_out_layout ok || report init_lays_out_layout "$missing"

# ---- status: every component, absent components read absent ----
status_out=$("$tool" status)
[ -f "$QWEN_HOME/manifest.tsv" ] && report status_writes_manifest ok || report status_writes_manifest missing
header=$(head -n 1 "$QWEN_HOME/manifest.tsv")
[ "$header" = "$(printf 'component\tkind\tpath\tsource\trevision\tsource_sha256\tinstalled_sha256\tmutable\trebuild_command')" ] \
    && report manifest_header ok || report manifest_header "$header"
for component in runtime-root searxng-source searxng-venv ryzenadj image-runtime llama-source llama-server shaderc models deployments state cache tmp results sudo-policy; do
    grep -q "^$component	" "$QWEN_HOME/manifest.tsv" || report "manifest_row_$component" missing
done
searxng_installed=$(awk -F'\t' '$1 == "searxng-venv" { print $7 }' "$QWEN_HOME/manifest.tsv")
[ "$searxng_installed" = absent ] && report absent_component_reads_absent ok || report absent_component_reads_absent "$searxng_installed"
rebuild=$(awk -F'\t' '$1 == "searxng-venv" { print $9 }' "$QWEN_HOME/manifest.tsv")
[ "$rebuild" = 'make install-searxng' ] && report rebuild_command_named ok || report rebuild_command_named "$rebuild"
case $status_out in *runtime_manifest_sha256=*) report status_prints_manifest_digest ok ;; *) report status_prints_manifest_digest missing ;; esac

# ---- doctor over seeded legacy and foreign paths ----
fake_home=$work/home; fake_system=$work/system
mkdir -p "$fake_home/qwen-webui-state" "$fake_home/models" "$fake_system/usr/local/searxng" "$fake_system/etc/searxng" "$fake_system/tmp"
: >"$fake_system/tmp/sxng_cache_x.db"
: >"$fake_home/qwen-web-token.key"
mkdir -p "$QWEN_HOME/stray-directory"
doctor_out=$(QWEN_DOCTOR_HOME=$fake_home QWEN_DOCTOR_SYSTEM_PREFIX=$fake_system \
    QWEN_DOCTOR_ACCOUNT_LOOKUP='[ "$1" = searxng ]' "$tool" doctor)
printf '%s\n' "$doctor_out" | grep -q "^legacy-known	$fake_home/qwen-webui-state	" && report doctor_reports_legacy_user_path ok || report doctor_reports_legacy_user_path missing
printf '%s\n' "$doctor_out" | grep -q "^legacy-known	$fake_system/usr/local/searxng	" && report doctor_reports_legacy_system_path ok || report doctor_reports_legacy_system_path missing
printf '%s\n' "$doctor_out" | grep -q "^legacy-known	account:searxng	" && report doctor_reports_legacy_account ok || report doctor_reports_legacy_account missing
printf '%s\n' "$doctor_out" | grep -q "^legacy-known	$fake_system/tmp/sxng_cache_x.db	" && report doctor_reports_cache ok || report doctor_reports_cache missing
printf '%s\n' "$doctor_out" | grep -q "^foreign	$QWEN_HOME/stray-directory	" && report doctor_reports_foreign ok || report doctor_reports_foreign missing
printf '%s\n' "$doctor_out" | grep -q "^declared	$QWEN_HOME/models	present" && report doctor_reports_declared ok || report doctor_reports_declared missing
printf '%s\n' "$doctor_out" | grep -q '^legacy_paths_present=yes legacy_paths=7 foreign_owned_paths=1$' \
    && report doctor_summary_counts ok || report doctor_summary_counts "$(printf '%s\n' "$doctor_out" | tail -n 1)"
[ -d "$fake_home/qwen-webui-state" ] && [ -d "$fake_system/usr/local/searxng" ] && [ -d "$QWEN_HOME/stray-directory" ] \
    && report doctor_touches_nothing ok || report doctor_touches_nothing removed

# ---- purge-legacy refuses without the opt-in, and without a replacement instance ----
if QWEN_DOCTOR_HOME=$fake_home QWEN_DOCTOR_SYSTEM_PREFIX=$fake_system "$tool" purge-legacy >/dev/null 2>&1; then
    report purge_legacy_needs_opt_in accepted
else
    report purge_legacy_needs_opt_in ok
fi
if QWEN_PURGE_LEGACY_CONFIRM=yes QWEN_DOCTOR_HOME=$fake_home QWEN_DOCTOR_SYSTEM_PREFIX=$fake_system "$tool" purge-legacy >/dev/null 2>&1; then
    report purge_legacy_needs_replacement accepted
else
    report purge_legacy_needs_replacement ok
fi
[ -d "$fake_home/qwen-webui-state" ] && report refused_purge_touches_nothing ok || report refused_purge_touches_nothing removed

# ---- purge-legacy removes exactly the enumerated paths ----
mkdir -p "$QWEN_HOME/opt/searxng/venv/bin"; printf '#!/bin/sh\n' >"$QWEN_HOME/opt/searxng/venv/bin/python"; chmod +x "$QWEN_HOME/opt/searxng/venv/bin/python"
mkdir -p "$fake_home/unrelated"; : >"$fake_system/tmp/other.db"
QWEN_PURGE_LEGACY_CONFIRM=yes QWEN_DOCTOR_HOME=$fake_home QWEN_DOCTOR_SYSTEM_PREFIX=$fake_system \
    QWEN_DOCTOR_ACCOUNT_LOOKUP='false' "$tool" purge-legacy >"$work/purge.log"
[ ! -e "$fake_home/qwen-webui-state" ] && [ ! -e "$fake_home/models" ] && [ ! -e "$fake_home/qwen-web-token.key" ] \
    && [ ! -e "$fake_system/usr/local/searxng" ] && [ ! -e "$fake_system/etc/searxng" ] && [ ! -e "$fake_system/tmp/sxng_cache_x.db" ] \
    && report purge_legacy_removes_enumerated ok || report purge_legacy_removes_enumerated "$(cat "$work/purge.log")"
[ -d "$fake_home/unrelated" ] && [ -e "$fake_system/tmp/other.db" ] && [ -d "$QWEN_HOME/stray-directory" ] \
    && report purge_legacy_leaves_the_rest ok || report purge_legacy_leaves_the_rest removed

# ---- uninstall keeps state and models, refuses a running session, refuses without a marker ----
: >"$QWEN_HOME/state/keep.txt"; : >"$QWEN_HOME/models/keep.gguf"; : >"$QWEN_HOME/cache/drop"
printf 'state=running server_pid=1\n' >"$QWEN_HOME/state/session.status"
if "$tool" uninstall >/dev/null 2>&1; then report uninstall_refuses_running_session accepted; else report uninstall_refuses_running_session ok; fi
rm -f "$QWEN_HOME/state/session.status"
"$tool" uninstall >/dev/null
[ -f "$QWEN_HOME/state/keep.txt" ] && [ -f "$QWEN_HOME/models/keep.gguf" ] && [ ! -e "$QWEN_HOME/cache" ] && [ ! -e "$QWEN_HOME/stray-directory" ] \
    && report uninstall_keeps_state_and_models ok || report uninstall_keeps_state_and_models "$(ls -A "$QWEN_HOME")"
[ -f "$QWEN_HOME/.qwen-runtime-root" ] && report uninstall_keeps_marker ok || report uninstall_keeps_marker missing
unmarked=$work/unmarked; mkdir -p "$unmarked/models"; : >"$unmarked/models/precious"
if QWEN_HOME=$unmarked "$tool" uninstall >/dev/null 2>&1; then report unmarked_root_refused accepted; else report unmarked_root_refused ok; fi
[ -f "$unmarked/models/precious" ] && report unmarked_root_untouched ok || report unmarked_root_untouched removed

# ---- purge requires the confirm to equal the root ----
if QWEN_RUNTIME_ROOT_CONFIRM=/wrong "$tool" purge >/dev/null 2>&1; then report purge_needs_exact_confirm accepted; else report purge_needs_exact_confirm ok; fi
QWEN_RUNTIME_ROOT_CONFIRM=$QWEN_HOME "$tool" purge >/dev/null
[ ! -e "$QWEN_HOME/models" ] && [ ! -e "$QWEN_HOME/state" ] && report purge_removes_whole ok || report purge_removes_whole "$(ls -A "$QWEN_HOME")"

if [ "$failures" -ne 0 ]; then printf '%s failure(s)\n' "$failures"; exit 1; fi
printf 'test-runtime-root: all checks passed\n'
