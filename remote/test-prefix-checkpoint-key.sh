#!/bin/sh
set -eu

# The key derivation of the schema-bound prefix checkpoint, tested on the
# workstation without a model, a device, or a running server.
#
# The subject is the header patches/llama-server-prefix-checkpoint.patch adds.
# The test extracts that one file out of the patch into a temporary directory,
# compiles remote/test-fixtures/prefix-checkpoint-key-probe.cpp against it, and
# reads the digests back. Extracting rather than reading a checked-out llama.cpp
# tree keeps the subject the patch itself, so a header edited in a source tree
# and not carried into the patch fails here rather than passing.
#
# Three claims are checked. The SHA-256 implementation reproduces the standard
# vectors and agrees with Python's hashlib over a token array. The key framing
# reproduces what the header documents, computed independently in Python. Each
# of the seven key fields changes the key on its own, and repeating a derivation
# with every field held reproduces the previous key.

if [ "$#" -gt 1 ]; then
    printf 'usage: %s [PATCH_FILE]\n' "$0" >&2
    exit 2
fi

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
repository_directory=$(CDPATH='' cd -- "$script_directory/.." && pwd)
patch_file=${1:-"$repository_directory/patches/llama-server-prefix-checkpoint.patch"}
probe_source=$script_directory/test-fixtures/prefix-checkpoint-key-probe.cpp
header_path=tools/server/server-prefix-checkpoint.h

if [ ! -r "$patch_file" ]; then
    printf 'candidate patch is unreadable: %s\n' "$patch_file" >&2
    exit 1
fi
patch_file=$(CDPATH='' cd -- "$(dirname -- "$patch_file")" && pwd)/$(basename -- "$patch_file")
if [ ! -r "$probe_source" ]; then
    printf 'probe source is unreadable: %s\n' "$probe_source" >&2
    exit 1
fi
for required_tool in git c++ python3; do
    if ! command -v "$required_tool" >/dev/null 2>&1; then
        printf 'required tool is absent: %s\n' "$required_tool" >&2
        exit 1
    fi
done

work_directory=$(mktemp -d)
cleanup() { rm -rf "$work_directory"; }
trap cleanup EXIT INT TERM

( cd "$work_directory" && git apply --include="$header_path" "$patch_file" )

if [ ! -r "$work_directory/$header_path" ]; then
    printf 'the patch carries no %s\n' "$header_path" >&2
    exit 1
fi

c++ -std=c++17 -Wall -Wextra -Werror \
    -I "$work_directory/tools/server" \
    -o "$work_directory/probe" "$probe_source"
printf 'probe=compiled header=%s\n' "$header_path"

probe=$work_directory/probe

check_equal() {
    check_name=$1
    expected_value=$2
    actual_value=$3

    if [ "$expected_value" != "$actual_value" ]; then
        printf '%s: expected %s, measured %s\n' \
            "$check_name" "$expected_value" "$actual_value" >&2
        exit 1
    fi
    printf '%s=ok\n' "$check_name"
}

check_differs() {
    check_name=$1
    first_value=$2
    second_value=$3

    if [ "$first_value" = "$second_value" ]; then
        printf '%s: the key held at %s across a changed field\n' \
            "$check_name" "$first_value" >&2
        exit 1
    fi
    printf '%s=ok\n' "$check_name"
}

# The two standard SHA-256 vectors, which fix the padding and the length
# encoding rather than only the compression function.
check_equal sha256_empty \
    e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855 \
    "$("$probe" sha256 '')"
check_equal sha256_abc \
    ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad \
    "$("$probe" sha256 abc)"

# A token array digests as its little-endian 32-bit elements, so hashlib over
# the same packing is the independent authority.
token_list=1,2,3,151643,-1
expected_token_digest=$(python3 -c '
import hashlib, struct, sys
tokens = [int(value) for value in sys.argv[1].split(",")]
print(hashlib.sha256(struct.pack("<%di" % len(tokens), *tokens)).hexdigest())
' "$token_list")
check_equal token_digest "$expected_token_digest" "$("$probe" tokens "$token_list")"

check_equal token_digest_empty \
    e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855 \
    "$("$probe" tokens '')"

# The key framing, reproduced from the header's documented shape: a version
# line, six length-prefixed named fields, and the prefix token count.
base_model='/models/qwen35-2b.gguf|qwen35 2B Q4_K_M|2000000000'
base_template=0000000000000000000000000000000000000000000000000000000000000001
base_runtime='16384,128,32,1,1,1,2,8192'
base_build='f280b26983ad0fdb705a0d9ebf0503e76f2899b0-1'
base_system=0000000000000000000000000000000000000000000000000000000000000002
base_prefix=0000000000000000000000000000000000000000000000000000000000000003
base_count=507

derive_key() {
    "$probe" key "$1" "$2" "$3" "$4" "$5" "$6" "$7"
}

base_key=$(derive_key "$base_model" "$base_template" "$base_runtime" \
    "$base_build" "$base_system" "$base_prefix" "$base_count")

expected_key=$(python3 -c '
import hashlib, sys
names = ["model", "template", "runtime", "build", "system", "prefix"]
digest = hashlib.sha256()
digest.update(b"qwen-prefix-checkpoint-v1\n")
for name, value in zip(names, sys.argv[1:7]):
    raw = value.encode()
    digest.update(("%s:%d:" % (name, len(raw))).encode())
    digest.update(raw)
    digest.update(b"\n")
digest.update(("n_prefix_tokens:%s\n" % sys.argv[7]).encode())
print(digest.hexdigest())
' "$base_model" "$base_template" "$base_runtime" "$base_build" \
    "$base_system" "$base_prefix" "$base_count")
check_equal key_framing "$expected_key" "$base_key"

repeat_key=$(derive_key "$base_model" "$base_template" "$base_runtime" \
    "$base_build" "$base_system" "$base_prefix" "$base_count")
check_equal key_repeats "$base_key" "$repeat_key"

check_differs key_model_field "$base_key" \
    "$(derive_key "${base_model}x" "$base_template" "$base_runtime" \
        "$base_build" "$base_system" "$base_prefix" "$base_count")"
check_differs key_template_field "$base_key" \
    "$(derive_key "$base_model" "${base_template}x" "$base_runtime" \
        "$base_build" "$base_system" "$base_prefix" "$base_count")"
check_differs key_runtime_field "$base_key" \
    "$(derive_key "$base_model" "$base_template" '16384,2048,512,1,1,1,2,8192' \
        "$base_build" "$base_system" "$base_prefix" "$base_count")"
check_differs key_build_field "$base_key" \
    "$(derive_key "$base_model" "$base_template" "$base_runtime" \
        "${base_build}x" "$base_system" "$base_prefix" "$base_count")"
check_differs key_system_field "$base_key" \
    "$(derive_key "$base_model" "$base_template" "$base_runtime" \
        "$base_build" "${base_system}x" "$base_prefix" "$base_count")"
check_differs key_prefix_field "$base_key" \
    "$(derive_key "$base_model" "$base_template" "$base_runtime" \
        "$base_build" "$base_system" "${base_prefix}x" "$base_count")"
check_differs key_count_field "$base_key" \
    "$(derive_key "$base_model" "$base_template" "$base_runtime" \
        "$base_build" "$base_system" "$base_prefix" 508)"

# Length prefixes are what keep a byte moved across a field boundary from
# leaving the key alone, so the shifted pair is checked rather than assumed.
check_differs key_field_boundary \
    "$(derive_key ab "$base_template" "$base_runtime" \
        "$base_build" "$base_system" "$base_prefix" "$base_count")" \
    "$(derive_key a "b$base_template" "$base_runtime" \
        "$base_build" "$base_system" "$base_prefix" "$base_count")"

printf 'prefix_checkpoint_key=accepted\n'
