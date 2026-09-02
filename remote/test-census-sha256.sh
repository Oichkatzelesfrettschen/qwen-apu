#!/bin/sh
# Compiles the census SHA-256 implementation out of the patch and compares its
# digest against sha256sum. The census publishes a module identity as a hex
# digest, and a reader cross-checks that identity by hashing a dumped .spv, so
# the two implementations agree or the identity means nothing. The function
# text comes from patches/llama-vulkan-pipeline-census.patch between the
# census-sha256-begin and census-sha256-end markers, which is the artifact the
# build applies rather than a copy that could drift from it.
#
# The vectors cover the three FIPS 180-4 cases the runtime self-test asserts, a
# 1 MiB random input, and the five lengths around the padding boundary at 55,
# 56, 63, 64, and 65 bytes, where a message either fits its final block with
# room for the length field or forces another block.
set -eu

usage() {
    printf 'usage: %s\n' "$(basename "$0")" >&2
    printf 'Compiles the census SHA-256 function from the patch and checks it\n' >&2
    printf 'against sha256sum over nine inputs. Takes no arguments.\n' >&2
    exit 2
}

if [ "$#" -ne 0 ]; then
    usage
fi

script_directory=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repository_root=$(CDPATH= cd -- "$script_directory/.." && pwd)
patch_path="$repository_root/patches/llama-vulkan-pipeline-census.patch"

if [ ! -f "$patch_path" ]; then
    printf 'census patch is absent: %s\n' "$patch_path" >&2
    exit 1
fi

temporary_directory=$(mktemp -d "${TMPDIR:-/tmp}/census-sha256.XXXXXX")
cleanup() {
    rm -r "$temporary_directory"
}
trap cleanup EXIT

extracted_source="$temporary_directory/census-sha256.inc"

# The markers bound the added function, so every line between them is an
# addition and carries the leading '+'. A line without it means a hunk header
# landed inside the range and the extracted text is incomplete.
awk '
    /^\+\/\/ census-sha256-begin$/ { inside = 1; next }
    /^\+\/\/ census-sha256-end$/   { if (inside) { inside = 0; closed = 1 } ; next }
    inside {
        if (substr($0, 1, 1) != "+") {
            printf "extraction crossed a non-addition line: %s\n", $0 > "/dev/stderr"
            exit 1
        }
        print substr($0, 2)
        lines++
    }
    END {
        if (!closed) {
            print "census-sha256 markers are absent or unbalanced in the patch" > "/dev/stderr"
            exit 1
        }
        if (lines < 40) {
            printf "extracted %d lines, which is shorter than the function\n", lines > "/dev/stderr"
            exit 1
        }
    }
' "$patch_path" > "$extracted_source"

printf 'extraction=accepted lines=%s\n' "$(wc -l < "$extracted_source" | tr -d ' ')"

harness_source="$temporary_directory/census-sha256-main.cpp"
{
    printf '#include <string>\n'
    printf '#include <vector>\n'
    printf '#include <cstdio>\n'
    printf '#include <cstdint>\n'
    printf '#include <cstddef>\n'
    cat "$extracted_source"
    cat <<'HARNESS'

int main(int argc, char ** argv) {
    if (argc != 2) {
        fprintf(stderr, "usage: census-sha256 FILE\n");
        return 2;
    }
    FILE * input = fopen(argv[1], "rb");
    if (input == nullptr) {
        fprintf(stderr, "unreadable: %s\n", argv[1]);
        return 1;
    }
    std::vector<unsigned char> bytes;
    unsigned char chunk[65536];
    size_t got = 0;
    while ((got = fread(chunk, 1, sizeof(chunk), input)) > 0) {
        bytes.insert(bytes.end(), chunk, chunk + got);
    }
    fclose(input);
    printf("%s\n", ggml_vk_census_sha256_hex(bytes.empty() ? (const void *) "" : (const void *) bytes.data(),
                                             bytes.size()).c_str());
    return 0;
}
HARNESS
} > "$harness_source"

"${CXX:-c++}" -std=c++17 -O1 -o "$temporary_directory/census-sha256" "$harness_source"
printf 'compile=accepted\n'

compare_vector() {
    check_name=$1
    vector_path=$2
    expected=$3
    observed=$("$temporary_directory/census-sha256" "$vector_path")
    if [ "$observed" != "$expected" ]; then
        printf '%s=refused observed=%s expected=%s\n' "$check_name" "$observed" "$expected" >&2
        exit 1
    fi
    printf '%s=accepted\n' "$check_name"
}

compare_against_sha256sum() {
    check_name=$1
    vector_path=$2
    reference=$(sha256sum "$vector_path" | cut -d' ' -f1)
    compare_vector "$check_name" "$vector_path" "$reference"
}

# The three vectors the runtime self-test asserts, checked here against their
# published digests rather than against sha256sum, so a wrong reference tool
# cannot make both sides agree.
printf '' > "$temporary_directory/empty"
compare_vector known-empty "$temporary_directory/empty" \
    e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855

printf 'abc' > "$temporary_directory/abc"
compare_vector known-abc "$temporary_directory/abc" \
    ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad

printf 'abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq' \
    > "$temporary_directory/two-block"
compare_vector known-two-block "$temporary_directory/two-block" \
    248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1

# A megabyte of random bytes exercises the block loop past any single-block
# path, and sha256sum is the reference.
head -c 1048576 /dev/urandom > "$temporary_directory/random-1mib"
compare_against_sha256sum random-1mib "$temporary_directory/random-1mib"

# The padding boundary: 55 bytes leaves exactly room for the 0x80 byte and the
# 8-byte length in one block, 56 forces a second block, and 63, 64, and 65
# straddle the block size itself.
for boundary_length in 55 56 63 64 65; do
    boundary_path="$temporary_directory/boundary-$boundary_length"
    head -c "$boundary_length" /dev/urandom > "$boundary_path"
    compare_against_sha256sum "boundary-$boundary_length" "$boundary_path"
done

printf 'census_sha256=accepted\n'
