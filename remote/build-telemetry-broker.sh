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

source_path=$script_directory/telemetry-broker.c
mkdir -p "$(dirname -- "$output_path")"
"$compiler" -O2 -Wall -Wextra -std=c11 \
    "$source_path" \
    -o "$output_path"
# The digest of the source this executable was compiled from, written beside
# it as `<output>.source-sha256`. An executable states its own identity and
# says nothing about the source it descends from, so a campaign preflight
# reading this file rebuilds an executable that predates an edit rather than
# sampling with it: the 20260902T2011Z calibration ran an eighth-column
# invariant against a seven-column binary because the preflight built only
# where the executable was absent.
source_sha256=$(sha256sum "$source_path" | awk '{ print $1 }')
printf '%s\n' "$source_sha256" >"$output_path.source-sha256"
printf 'telemetry_broker=%s sha256=%s source_sha256=%s source_record=%s\n' \
    "$output_path" "$(sha256sum "$output_path" | awk '{ print $1 }')" \
    "$source_sha256" "$output_path.source-sha256"
