#!/bin/sh
set -eu

# Install SearXNG under the runtime root as the serving user and prove it.
#
# toolchains/searxng/source.tsv pins the upstream commit and the digest of the
# requirements file that commit carries, and toolchains/searxng/requirements.lock
# is the full frozen environment that commit resolves to. The source lands in
# opt/searxng/src under QWEN_HOME, the interpreter in opt/searxng/venv beside
# it, and both belong to the user running this script: no service account,
# no /etc, no /usr/local, and no sudo take part, because remote/searxng-launch.sh
# renders the settings into the launch's own state directory and runs the
# module from the source tree under the user's own TMPDIR.
#
# The installed environment is proven against the lock rather than trusted:
# after the install, `pip freeze` sorted must equal the lock byte for byte, so
# the venv identity remote/runtime-root.sh records is the digest of a listing
# this script already required to match.
#
# `verify` starts the instance through remote/searxng-launch.sh in a scratch
# state directory, requires GET /healthz and one JSON search to answer on the
# loopback, and stops it, so an install is admitted by the same path the
# appliance launches it through.
#
# usage: install-searxng.sh [install|verify|identity]
#   QWEN_SEARXNG_ROOT      the instance root, default opt/searxng under QWEN_HOME
#   QWEN_SEARXNG_TOOLCHAIN the pin directory, default toolchains/searxng
#   QWEN_SEARXNG_PORT      the loopback port `verify` uses, default 8888

usage() {
    sed -n '25,29p' "$0" >&2
    exit 2
}

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
# shellcheck source=remote/qwen-home.sh
. "$script_directory/qwen-home.sh"

[ "$#" -le 1 ] || usage
action=${1:-install}
case $action in
    install | verify | identity) ;;
    *) usage ;;
esac

instance_root=${QWEN_SEARXNG_ROOT:-"$qwen_home_searxng_root"}
source_directory=$instance_root/src
venv_directory=$instance_root/venv
instance_python=$venv_directory/bin/python
toolchain_directory=${QWEN_SEARXNG_TOOLCHAIN:-"$qwen_tree_root/toolchains/searxng"}
source_pins=$toolchain_directory/source.tsv
requirements_lock=$toolchain_directory/requirements.lock
pin_branch=qwen-search-pin

read_pin() {
    awk -F'\t' -v key="$1" 'NR > 1 && $1 == key { print $2; exit }' "$source_pins"
}

for required in "$source_pins" "$requirements_lock"; do
    [ -r "$required" ] || { printf 'pin file unreadable: %s\n' "$required" >&2; exit 2; }
done
upstream_url=$(read_pin upstream_url)
pinned_commit=$(read_pin pinned_commit)
requirements_sha256=$(read_pin requirements_sha256)
python_minimum=$(read_pin python_minimum)
for pin in "upstream_url=$upstream_url" "pinned_commit=$pinned_commit" \
    "requirements_sha256=$requirements_sha256" "python_minimum=$python_minimum"; do
    [ -n "${pin#*=}" ] || { printf 'pin absent from %s: %s\n' "$source_pins" "${pin%%=*}" >&2; exit 2; }
done
case $pinned_commit in
    *[!0-9a-f]* | '') printf 'pinned_commit is not a SHA-1: %s\n' "$pinned_commit" >&2; exit 2 ;;
esac

# The lock digest is the venv identity: the sorted freeze of an installed
# environment equal to the lock hashes to this same value.
lock_sha256=$(sha256sum "$requirements_lock" | cut -d ' ' -f 1)

venv_freeze() {
    "$instance_python" -m pip freeze --disable-pip-version-check 2>/dev/null | LC_ALL=C sort
}

print_identity() {
    identity_commit=absent
    identity_venv=absent
    if [ -d "$source_directory/.git" ]; then
        identity_commit=$(git -C "$source_directory" rev-parse HEAD 2>/dev/null || printf 'unreadable')
    fi
    if [ -x "$instance_python" ]; then
        identity_venv=$(venv_freeze | sha256sum | cut -d ' ' -f 1)
    fi
    printf 'searxng_root=%s\nsearxng_source_commit=%s\nsearxng_pinned_commit=%s\nsearxng_venv_sha256=%s\nsearxng_lock_sha256=%s\n' \
        "$instance_root" "$identity_commit" "$pinned_commit" "$identity_venv" "$lock_sha256"
}

if [ "$action" = identity ]; then
    print_identity
    exit 0
fi

if [ "$action" = install ]; then
    for tool in git python3 sha256sum; do
        command -v "$tool" >/dev/null 2>&1 || { printf '%s is required\n' "$tool" >&2; exit 2; }
    done
    python_version=$(python3 -c 'import sys; print("%d.%d" % sys.version_info[:2])')
    if [ "$(printf '%s\n%s\n' "$python_minimum" "$python_version" | sort -V | head -n 1)" != "$python_minimum" ]; then
        printf 'python3 %s is below the pinned minimum %s\n' "$python_version" "$python_minimum" >&2
        exit 2
    fi
    mkdir -p "$instance_root"

    printf 'source: %s at %s\n' "$upstream_url" "$pinned_commit"
    if [ -d "$source_directory/.git" ]; then
        git -C "$source_directory" fetch -q origin
    else
        git clone -q "$upstream_url" "$source_directory"
    fi
    git -C "$source_directory" checkout -q -B "$pin_branch" "$pinned_commit"
    clone_status=$(git -C "$source_directory" status --porcelain)
    if [ -n "$clone_status" ]; then
        printf 'pinned clone is not clean:\n%s\n' "$clone_status" >&2
        exit 1
    fi
    clone_head=$(git -C "$source_directory" rev-parse HEAD)
    if [ "$clone_head" != "$pinned_commit" ]; then
        printf 'HEAD %s does not match pin %s\n' "$clone_head" "$pinned_commit" >&2
        exit 1
    fi
    observed_requirements_sha256=$(sha256sum "$source_directory/requirements.txt" | cut -d ' ' -f 1)
    if [ "$observed_requirements_sha256" != "$requirements_sha256" ]; then
        printf 'requirements.txt at %s hashes to %s where the pin states %s\n' \
            "$pinned_commit" "$observed_requirements_sha256" "$requirements_sha256" >&2
        exit 1
    fi

    printf 'venv: %s\n' "$venv_directory"
    [ -x "$instance_python" ] || python3 -m venv "$venv_directory"
    mkdir -p "$qwen_home_cache/pip"
    # The lock is the whole environment, so dependency resolution is off and
    # every installed distribution is one the lock names at its pinned version.
    PIP_CACHE_DIR=$qwen_home_cache/pip "$instance_python" -m pip install -q \
        --disable-pip-version-check --no-deps -r "$requirements_lock"
    observed_freeze=$(venv_freeze)
    expected_freeze=$(LC_ALL=C sort "$requirements_lock")
    if [ "$observed_freeze" != "$expected_freeze" ]; then
        printf 'installed environment differs from %s:\n' "$requirements_lock" >&2
        printf '%s\n' "$observed_freeze" >"$instance_root/.freeze.observed"
        printf '%s\n' "$expected_freeze" | diff - "$instance_root/.freeze.observed" >&2 || true
        rm -f "$instance_root/.freeze.observed"
        exit 1
    fi
    print_identity
    printf 'install complete: run %s verify\n' "$0"
    exit 0
fi

# verify: the instance through the launch path the appliance uses.
QWEN_SEARXNG_ROOT=$instance_root "$script_directory/searxng-launch.sh" check >/dev/null
verify_port=${QWEN_SEARXNG_PORT:-8888}
verify_state=$(mktemp -d "${TMPDIR:-/tmp}/searxng-verify.XXXXXX")
verify_cleanup() {
    QWEN_SEARXNG_ROOT=$instance_root "$script_directory/searxng-launch.sh" stop "$verify_state" >/dev/null 2>&1 || true
    rm -rf "$verify_state"
}
trap verify_cleanup EXIT HUP INT TERM
QWEN_SEARXNG_ROOT=$instance_root QWEN_SEARXNG_PORT=$verify_port \
    "$script_directory/searxng-launch.sh" start "$verify_state"
search_response=$(mktemp "$verify_state/search.XXXXXX")
search_status=$(curl -s -o "$search_response" -w '%{http_code}' \
    "http://127.0.0.1:$verify_port/search?q=test&format=json")
if [ "$search_status" != 200 ]; then
    printf 'GET /search?format=json returned %s\n' "$search_status" >&2
    exit 1
fi
if ! python3 -c 'import json, sys; json.load(open(sys.argv[1]))' "$search_response" >/dev/null 2>&1; then
    printf 'GET /search?format=json did not return parseable JSON\n' >&2
    exit 1
fi
QWEN_SEARXNG_ROOT=$instance_root "$script_directory/searxng-launch.sh" stop "$verify_state"
print_identity
printf 'searxng_verify=passed port=%s\n' "$verify_port"
