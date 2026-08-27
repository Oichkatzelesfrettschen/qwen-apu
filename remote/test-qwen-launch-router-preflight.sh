#!/bin/sh
set -eu

# Router preflight consumes a safety-filtered registry query. A command
# substitution hidden in a loop can lose its exit status, so this fixture makes
# the query return a unique failure and proves the launcher stops at that gate.

if [ "$#" -ne 0 ]; then
    printf 'usage: %s\n' "$0" >&2
    exit 2
fi

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
temporary_directory=$(mktemp -d)
trap 'rm -rf "$temporary_directory"' EXIT INT TERM
fixture_remote=$temporary_directory/remote
fixture_bin=$temporary_directory/bin
mkdir -p "$fixture_remote" "$fixture_bin"
cp "$script_directory/qwen-launch.sh" "$fixture_remote/qwen-launch.sh"

cat >"$fixture_remote/model-registry.sh" <<'REGISTRY'
#!/bin/sh
if [ "$#" -eq 1 ] && [ "$1" = servable-files ]; then
    printf 'fixture servable enumeration failed\n' >&2
    exit 7
fi
exit 8
REGISTRY

cat >"$fixture_bin/pgrep" <<'PGREP'
#!/bin/sh
exit 1
PGREP

chmod +x "$fixture_remote"/*.sh "$fixture_bin"/*
set +e
HOME=$temporary_directory QWEN_ROUTER=1 PATH="$fixture_bin:$PATH" \
    "$fixture_remote/qwen-launch.sh" \
    >"$temporary_directory/launch.stdout" \
    2>"$temporary_directory/launch.stderr"
launch_status=$?
set -e

if [ "$launch_status" -ne 7 ]; then
    printf 'launcher replaced servable-enumeration status 7 with %s\n' \
        "$launch_status" >&2
    exit 1
fi
grep -F 'fixture servable enumeration failed' \
    "$temporary_directory/launch.stderr" >/dev/null
printf 'qwen_launch_router_preflight=accepted\n'
