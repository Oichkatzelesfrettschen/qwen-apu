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
    printf 'environment: QWEN_FETCH_CONNECTIONS (default 4, 1 for one stream)\n' >&2
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
fetch_connections=${QWEN_FETCH_CONNECTIONS:-4}

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

# The publisher's CDN throttles per connection rather than per object, and the
# rate differs by repository: measured from the appliance in one minute, one
# stream reached 22.6 MB/s from one repository and 3.3 MB/s from another, while
# four streams against that slower repository reached 12.6 MB/s and eight
# reached 16.0. Concurrency therefore recovers a throttled object and costs
# about a fifth on an unthrottled one, which is why the default is four rather
# than eight or one.
#
# Ranges are what make this safe: each part states the bytes it must contain,
# every part is checked against that length before assembly, and the assembled
# file is checked against the length the server declared. A part short by one
# byte would otherwise concatenate into a plausible file with no error.
fetch_single_stream() {
    # --continue-at - resumes a partial transfer, so an interrupted sweep does
    # not refetch a gigabyte it already holds.
    curl --location --fail --silent --show-error --continue-at - \
        --output "$partial_path" "$source_url"
}

fetch_parallel_ranges() {
    parallel_total=$1
    parallel_directory=$partial_path.parts
    rm -rf "$parallel_directory"
    mkdir -p "$parallel_directory"
    parallel_chunk=$(( (parallel_total + fetch_connections - 1) / fetch_connections ))
    parallel_index=0
    while [ "$parallel_index" -lt "$fetch_connections" ]; do
        parallel_first=$(( parallel_index * parallel_chunk ))
        [ "$parallel_first" -ge "$parallel_total" ] && break
        parallel_last=$(( parallel_first + parallel_chunk - 1 ))
        [ "$parallel_last" -ge "$parallel_total" ] && parallel_last=$(( parallel_total - 1 ))
        curl --location --fail --silent --show-error \
            --range "$parallel_first-$parallel_last" \
            --output "$parallel_directory/$(printf '%04d' "$parallel_index")" \
            "$source_url" &
        parallel_index=$(( parallel_index + 1 ))
    done
    wait || return 1

    # Assemble in index order and require every part to hold exactly the bytes
    # its range named.
    : >"$partial_path"
    parallel_index=0
    while [ "$parallel_index" -lt "$fetch_connections" ]; do
        parallel_first=$(( parallel_index * parallel_chunk ))
        [ "$parallel_first" -ge "$parallel_total" ] && break
        parallel_last=$(( parallel_first + parallel_chunk - 1 ))
        [ "$parallel_last" -ge "$parallel_total" ] && parallel_last=$(( parallel_total - 1 ))
        parallel_part=$parallel_directory/$(printf '%04d' "$parallel_index")
        parallel_expected=$(( parallel_last - parallel_first + 1 ))
        if [ ! -f "$parallel_part" ]; then
            printf 'range part %s is absent\n' "$parallel_index" >&2
            return 1
        fi
        parallel_actual=$(wc -c <"$parallel_part")
        if [ "$parallel_actual" != "$parallel_expected" ]; then
            printf 'range part %s holds %s bytes for a %s-byte range\n' \
                "$parallel_index" "$parallel_actual" "$parallel_expected" >&2
            return 1
        fi
        cat "$parallel_part" >>"$partial_path"
        parallel_index=$(( parallel_index + 1 ))
    done
    rm -rf "$parallel_directory"

    parallel_assembled=$(wc -c <"$partial_path")
    if [ "$parallel_assembled" != "$parallel_total" ]; then
        printf 'assembled %s bytes against the declared %s\n' \
            "$parallel_assembled" "$parallel_total" >&2
        return 1
    fi
    return 0
}

# A server that declares neither a length nor range support leaves nothing to
# split, so the single stream is the fallback rather than an error.
declared_bytes=''
accepts_ranges=no
if [ "$fetch_connections" -gt 1 ]; then
    header_dump=$(curl --location --fail --silent --show-error --head \
        "$source_url" 2>/dev/null || true)
    declared_bytes=$(printf '%s\n' "$header_dump" |
        awk 'tolower($1) == "content-length:" { value = $2 }
             END { gsub(/\r/, "", value); print value }')
    printf '%s\n' "$header_dump" |
        grep -qi '^accept-ranges:[[:space:]]*bytes' && accepts_ranges=yes
fi

fetch_mode=single
case $declared_bytes in
    ''|*[!0-9]*) ;;
    *)
        if [ "$accepts_ranges" = yes ] && [ "$declared_bytes" -gt 0 ]; then
            fetch_mode=parallel
        fi
        ;;
esac

rm -f "$partial_path"
if [ "$fetch_mode" = parallel ]; then
    if ! fetch_parallel_ranges "$declared_bytes"; then
        printf 'parallel range fetch failed, falling back to one stream: %s\n' \
            "$source_url" >&2
        rm -rf "$partial_path.parts"
        rm -f "$partial_path"
        fetch_mode=single
    fi
fi
if [ "$fetch_mode" = single ] && ! fetch_single_stream; then
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
printf 'artifact_status=fetched path=%s bytes=%s observed_sha256=%s mode=%s repository=%s revision=%s\n' \
    "$artifact_path" "$observed_bytes" "$observed_sha256" "$fetch_mode" \
    "$source_repository" "$source_revision"
