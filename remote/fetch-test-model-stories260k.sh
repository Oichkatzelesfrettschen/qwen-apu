#!/bin/sh
set -eu
script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
# shellcheck source=remote/qwen-home.sh
. "$script_directory/qwen-home.sh"

# The 260K-parameter TinyStories checkpoint llama.cpp's own server tests load,
# fetched once into the runtime root's cache for the router lifecycle test
# (remote/test-router-cancelled-load.sh). It is a test fixture rather than a
# served model, so it lives under cache/test-models and never enters
# remote/models.tsv. The revision, byte count, and SHA-256 are pinned the way
# every download script pins them, and an existing file is verified in place
# rather than fetched again.
#
# usage: fetch-test-model-stories260k.sh [DESTINATION_FILE]

if [ "$#" -gt 1 ]; then
    printf 'usage: %s [DESTINATION_FILE]\n' "$0" >&2
    exit 2
fi

destination_file=${1:-"$qwen_home_cache/test-models/stories260K.gguf"}
source_repository=ggml-org/models-moved
source_revision=499bc8821c6b12b4e53c5bffcb21ec206f212d81
source_path=tinyllamas/stories260K.gguf
expected_bytes=1185376
expected_sha256=270cba1bd5109f42d03350f60406024560464db173c0e387d91f0426d3bd256d

verify_artifact() {
    actual_bytes=$(wc -c <"$1")
    if [ "$actual_bytes" != "$expected_bytes" ]; then
        printf 'artifact byte count mismatch: expected %s, found %s at %s\n' \
            "$expected_bytes" "$actual_bytes" "$1" >&2
        return 1
    fi
    actual_sha256=$(sha256sum "$1" | awk '{ print $1 }')
    if [ "$actual_sha256" != "$expected_sha256" ]; then
        printf 'artifact SHA-256 mismatch: expected %s, found %s at %s\n' \
            "$expected_sha256" "$actual_sha256" "$1" >&2
        return 1
    fi
}

umask 077
mkdir -p "$(dirname -- "$destination_file")"
if [ -f "$destination_file" ]; then
    verify_artifact "$destination_file"
    printf 'artifact_status=already_verified path=%s bytes=%s sha256=%s\n' \
        "$destination_file" "$expected_bytes" "$expected_sha256"
    exit 0
fi

partial_file=$destination_file.part
curl -fsSL --retry 3 -o "$partial_file" \
    "https://huggingface.co/$source_repository/resolve/$source_revision/$source_path"
verify_artifact "$partial_file"
mv -- "$partial_file" "$destination_file"
printf 'artifact_status=fetched path=%s bytes=%s sha256=%s revision=%s\n' \
    "$destination_file" "$expected_bytes" "$expected_sha256" "$source_revision"
