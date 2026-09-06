#!/bin/sh
# install-searxng.sh against a fake upstream: a local bare repository stands
# in for github, the pin directory names its commit and the digest of its
# requirements.txt, and the lock is empty, so the install clones the pin,
# proves the requirements digest, builds a venv whose freeze equals the lock,
# and prints an identity, all as the invoking user under a scratch root. A
# wrong pin commit, a wrong requirements digest, and a lock the environment
# fails to equal each refuse; `verify` runs the instance through
# searxng-launch.sh under QWEN_SEARXNG_LAUNCH_COMMAND naming a stand-in
# listener.
set -eu
script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
installer=$script_directory/install-searxng.sh
work=$(mktemp -d)
port_lease_holder_pid=''
release_port_lease() {
    if [ -n "$port_lease_holder_pid" ]; then
        "$script_directory/test-port-lease.sh" release \
            "$port_lease_holder_pid" || true
        port_lease_holder_pid=''
    fi
}
trap 'release_port_lease; rm -rf "$work"' EXIT HUP INT TERM
failures=0
report() {
    if [ "$2" = ok ]; then printf 'ok %s\n' "$1"; else printf 'FAIL %s: %s\n' "$1" "$2"; failures=$((failures + 1)); fi
}
if ! python3 -c 'import venv, ensurepip' >/dev/null 2>&1; then
    printf 'python3 venv with ensurepip is unavailable: not_run\n'
    exit 0
fi
export QWEN_HOME=$work/root
export QWEN_SEARXNG_TOOLCHAIN=$work/toolchain
mkdir -p "$QWEN_SEARXNG_TOOLCHAIN"

# ---- a fake upstream ----
upstream=$work/upstream
mkdir -p "$upstream/searx"
printf 'certifi==0\n' >"$upstream/requirements.txt"
printf 'print("stand-in")\n' >"$upstream/searx/webapp.py"
git -C "$upstream" init -q
git -C "$upstream" -c user.name=t -c user.email=t@t add -A
git -C "$upstream" -c user.name=t -c user.email=t@t commit -q -m 'pin'
pinned=$(git -C "$upstream" rev-parse HEAD)
requirements_sha256=$(sha256sum "$upstream/requirements.txt" | cut -d ' ' -f 1)
write_pins() {
    printf 'key\tvalue\nupstream_url\t%s\npinned_commit\t%s\nrequirements_sha256\t%s\npython_minimum\t3.8\n' \
        "$upstream" "$1" "$2" >"$QWEN_SEARXNG_TOOLCHAIN/source.tsv"
}
write_pins "$pinned" "$requirements_sha256"
: >"$QWEN_SEARXNG_TOOLCHAIN/requirements.lock"

# ---- install ----
if "$installer" install >"$work/install.log" 2>&1; then
    grep -q "^searxng_source_commit=$pinned$" "$work/install.log" && report install_reports_pinned_commit ok \
        || report install_reports_pinned_commit "$(cat "$work/install.log")"
    [ -x "$QWEN_HOME/opt/searxng/venv/bin/python" ] && report install_builds_venv_under_root ok || report install_builds_venv_under_root missing
    [ "$(git -C "$QWEN_HOME/opt/searxng/src" rev-parse HEAD)" = "$pinned" ] && report install_checks_out_pin ok || report install_checks_out_pin wrong
    lock_sha256=$(sha256sum "$QWEN_SEARXNG_TOOLCHAIN/requirements.lock" | cut -d ' ' -f 1)
    grep -q "^searxng_lock_sha256=$lock_sha256$" "$work/install.log" && report install_reports_lock_digest ok || report install_reports_lock_digest missing
else
    report install_succeeds "$(tail -n 5 "$work/install.log")"
fi

# ---- the identity command reads what install left ----
identity=$("$installer" identity)
printf '%s\n' "$identity" | grep -q "^searxng_source_commit=$pinned$" && report identity_reads_commit ok || report identity_reads_commit "$identity"
venv_identity=$(printf '%s\n' "$identity" | sed -n 's/^searxng_venv_sha256=//p')
expected_venv_identity=$("$QWEN_HOME/opt/searxng/venv/bin/python" -m pip freeze --disable-pip-version-check 2>/dev/null | LC_ALL=C sort | sha256sum | cut -d ' ' -f 1)
[ "$venv_identity" = "$expected_venv_identity" ] && report identity_is_freeze_digest ok || report identity_is_freeze_digest "$venv_identity"

# ---- a lock the environment cannot equal refuses ----
printf 'not-a-real-distribution==0\n' >"$QWEN_SEARXNG_TOOLCHAIN/requirements.lock"
if "$installer" install >"$work/lock.log" 2>&1; then report unmet_lock_refused accepted; else report unmet_lock_refused ok; fi
: >"$QWEN_SEARXNG_TOOLCHAIN/requirements.lock"

# ---- a wrong requirements digest refuses ----
write_pins "$pinned" 0000000000000000000000000000000000000000000000000000000000000000
if "$installer" install >"$work/digest.log" 2>&1; then report wrong_requirements_digest_refused accepted; else
    grep -q 'where the pin states' "$work/digest.log" && report wrong_requirements_digest_refused ok || report wrong_requirements_digest_refused "$(cat "$work/digest.log")"
fi

# ---- a commit the upstream lacks refuses ----
write_pins 0123456789012345678901234567890123456789 "$requirements_sha256"
if "$installer" install >"$work/commit.log" 2>&1; then report absent_commit_refused accepted; else report absent_commit_refused ok; fi
write_pins "$pinned" "$requirements_sha256"

# ---- verify through the launch path with a stand-in listener ----
# The stand-in listener binds this port itself, so a lease over the number
# rather than a socket is what reserves it: a holder process keeps an exclusive
# flock on the port's lease file until this script exits.
port_lease_ports_file=$work/leased-ports
port_lease_holder_pid=$("$script_directory/test-port-lease.sh" claim 1 \
    "$port_lease_ports_file")
port=$(sed -n 1p "$port_lease_ports_file")
mkdir -p "$work/site"; printf '{}' >"$work/site/healthz"; printf '{"results": []}' >"$work/site/search"
if QWEN_SEARXNG_PORT=$port \
    QWEN_SEARXNG_LAUNCH_COMMAND="python3 -m http.server $port --bind 127.0.0.1 --directory $work/site" \
    "$installer" verify >"$work/verify.log" 2>&1; then
    grep -q "^searxng_verify=passed port=$port$" "$work/verify.log" && report verify_passes_through_launch_path ok \
        || report verify_passes_through_launch_path "$(cat "$work/verify.log")"
else
    report verify_passes_through_launch_path "$(tail -n 5 "$work/verify.log")"
fi

# ---- an absent instance refuses verify with the component block ----
if QWEN_SEARXNG_ROOT=$work/nowhere "$installer" verify >"$work/absent.log" 2>&1; then report absent_instance_refuses_verify accepted; else
    grep -q 'component=searxng' "$work/absent.log" && grep -q "repair='make install-searxng'" "$work/absent.log" \
        && report absent_instance_refuses_verify ok || report absent_instance_refuses_verify "$(cat "$work/absent.log")"
fi

if [ "$failures" -ne 0 ]; then printf '%s failure(s)\n' "$failures"; exit 1; fi
printf 'test-install-searxng: all checks passed\n'
