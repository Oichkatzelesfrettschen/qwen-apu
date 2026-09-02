#!/bin/sh
set -eu

# Compile the telemetry broker into the appliance's build directory beside the
# other C probes. build/ sits next to remote/ under the runtime tree root, so a
# copy synced to ~/qwen-laptop-setup/remote writes ~/qwen-laptop-setup/build.

if [ "$#" -gt 1 ]; then
    printf 'usage: %s [OUTPUT_PATH]\n' "$0" >&2
    exit 2
fi

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
output_path=${1:-"$script_directory/../build/telemetry-broker"}
compiler=${CC:-cc}

if ! command -v "$compiler" >/dev/null 2>&1; then
    printf 'C compiler is unavailable: %s\n' "$compiler" >&2
    exit 1
fi

mkdir -p "$(dirname -- "$output_path")"
"$compiler" -O2 -Wall -Wextra -std=c11 \
    "$script_directory/telemetry-broker.c" \
    -o "$output_path"
printf 'telemetry_broker=%s sha256=%s\n' "$output_path" \
    "$(sha256sum "$output_path" | awk '{ print $1 }')"
