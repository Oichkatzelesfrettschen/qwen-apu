#!/bin/sh
set -eu

# Preserve the pre-session telemetry.log bytes before the session launcher
# replaces that shared regular file with the newest-record symlink. The content
# digest gives repeated migrations one stable destination and lets an existing
# destination prove equivalence before the shared pathname is removed.

if [ "$#" -ne 2 ]; then
    printf 'usage: %s SHARED_TELEMETRY_PATH TELEMETRY_DIRECTORY\n' "$0" >&2
    exit 2
fi

shared_telemetry_path=$1
telemetry_directory=$2

if [ -L "$shared_telemetry_path" ]; then
    printf 'legacy_telemetry=symlink path=%s\n' "$shared_telemetry_path"
    exit 0
fi
if [ ! -e "$shared_telemetry_path" ]; then
    printf 'legacy_telemetry=absent path=%s\n' "$shared_telemetry_path"
    exit 0
fi
if [ ! -f "$shared_telemetry_path" ]; then
    printf 'legacy telemetry path is not a regular file: %s\n' \
        "$shared_telemetry_path" >&2
    exit 1
fi
if [ ! -d "$telemetry_directory" ] || [ -L "$telemetry_directory" ]; then
    printf 'telemetry directory is absent, linked, or not a directory: %s\n' \
        "$telemetry_directory" >&2
    exit 1
fi

legacy_sha256=$(sha256sum "$shared_telemetry_path")
legacy_sha256=${legacy_sha256%% *}
legacy_record=$telemetry_directory/legacy-shared-$legacy_sha256.log

if [ -L "$legacy_record" ]; then
    printf 'legacy telemetry destination is linked: %s\n' "$legacy_record" >&2
    exit 1
fi
if [ -e "$legacy_record" ]; then
    if [ ! -f "$legacy_record" ] || \
       ! cmp -s "$shared_telemetry_path" "$legacy_record"; then
        printf 'legacy telemetry destination differs from shared bytes: %s\n' \
            "$legacy_record" >&2
        exit 1
    fi
    rm -- "$shared_telemetry_path"
    printf 'legacy_telemetry=already_preserved path=%s sha256=%s\n' \
        "$legacy_record" "$legacy_sha256"
    exit 0
fi

mv -- "$shared_telemetry_path" "$legacy_record"
printf 'legacy_telemetry=preserved path=%s sha256=%s\n' \
    "$legacy_record" "$legacy_sha256"
