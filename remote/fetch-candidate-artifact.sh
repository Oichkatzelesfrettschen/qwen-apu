#!/bin/sh
set -eu

# Fetch one candidate artifact by repository, revision, and file name.
#
# This differs from every download-*.sh in one way that decides how its output
# may be used. A pinned fetch script carries a byte count and a SHA-256 written
# into the repository before the file is fetched, so it verifies. A candidate
# has neither: the digest recorded here is what this download observed, and an
# observation cannot detect the substitution a pin exists to detect. Promotion
# to remote/models.tsv therefore means writing a pinned fetch script that
# carries the observed digest as its expectation, which is a separate act.
#
# A retained file is re-observed rather than re-fetched, and a recorded digest
# from an earlier run is compared against it, so a candidate directory that has
# already been admitted stays stable across sweeps.

renice -n 19 -p $$ >/dev/null 2>&1 || true
ionice -c 3 -p $$ >/dev/null 2>&1 || true

if [ "$#" -ne 4 ]; then
    printf 'usage: %s REPOSITORY REVISION ARTIFACT_NAME DESTINATION_DIRECTORY\n' "$0" >&2
    printf 'writes DESTINATION_DIRECTORY/ARTIFACT_NAME and its observed digest\n' >&2
    exit 2
fi

source_repository=$1
source_revision=$2
artifact_name=$3
destination_directory=$4
artifact_path=$destination_directory/$artifact_name
partial_path=$artifact_path.part
digest_path=$artifact_path.observed-sha256
source_url=https://huggingface.co/$source_repository/resolve/$source_revision/$artifact_name

umask 077
mkdir -p "$destination_directory"

observe() {
    printf '%s %s\n' "$(sha256sum "$1" | awk '{ print $1 }')" "$(wc -c <"$1")"
}

if [ -f "$artifact_path" ]; then
    observed=$(observe "$artifact_path")
    observed_sha256=${observed% *}
    observed_bytes=${observed#* }
    if [ -f "$digest_path" ]; then
        recorded=$(cat "$digest_path")
        recorded_sha256=${recorded% *}
        if [ "$recorded_sha256" != "$observed_sha256" ]; then
            printf 'retained artifact no longer matches its recorded digest: %s\n' \
                "$artifact_path" >&2
            printf 'recorded %s observed %s\n' "$recorded_sha256" "$observed_sha256" >&2
            exit 1
        fi
    else
        printf '%s %s\n' "$observed_sha256" "$observed_bytes" >"$digest_path"
    fi
    printf 'artifact_status=retained path=%s bytes=%s observed_sha256=%s repository=%s revision=%s\n' \
        "$artifact_path" "$observed_bytes" "$observed_sha256" \
        "$source_repository" "$source_revision"
    exit 0
fi

# --continue-at - resumes a partial transfer, so an interrupted sweep does not
# refetch a gigabyte it already holds.
if ! curl --location --fail --silent --show-error --continue-at - \
        --output "$partial_path" "$source_url"; then
    printf 'fetch failed: %s\n' "$source_url" >&2
    exit 1
fi

observed=$(observe "$partial_path")
observed_sha256=${observed% *}
observed_bytes=${observed#* }
if [ "$observed_bytes" -le 0 ]; then
    printf 'fetch produced an empty artifact: %s\n' "$source_url" >&2
    rm -f "$partial_path"
    exit 1
fi

mv "$partial_path" "$artifact_path"
printf '%s %s\n' "$observed_sha256" "$observed_bytes" >"$digest_path"
printf 'artifact_status=fetched path=%s bytes=%s observed_sha256=%s repository=%s revision=%s\n' \
    "$artifact_path" "$observed_bytes" "$observed_sha256" \
    "$source_repository" "$source_revision"
