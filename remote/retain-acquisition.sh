#!/bin/sh
set -eu

# Copy an acquisition into the tree under the repository's sanitization rules
# and record the transformation as a checkable claim.
#
# `evidence/SHA256SUMS` fixes the identity of every retained surface, and the
# git copy of a measurement replaces the private hostname with `qwen-laptop`,
# the serving user's home prefix with `$HOME`, and a MAC address with `<mac>`.
# A retained file therefore differs from the acquisition it came from, and a
# reader with only the retained copy can neither reproduce that difference nor
# tell a sanitized substitution from an edit. This script writes both digests
# and the substitution count per file into `transformation.tsv` beside the
# copy, so the retained bytes state what produced them.
#
# The source is read and never written. A sanitized copy is a derivative
# rather than a replacement: the acquisition stays where it is, under whatever
# retention decision governs it, and this script authorizes no deletion.
#
# A file whose content is not text passes through byte-for-byte and records
# `binary` as its substitution count, since a substitution over a compiled
# module would corrupt the artifact the digest beside it identifies.
#
# usage: retain-acquisition.sh SOURCE_DIRECTORY DESTINATION_DIRECTORY
#   QWEN_SANITIZE_HOST     private hostname replaced by `qwen-laptop`,
#                          default the appliance name this tree records
#   QWEN_SANITIZE_HOME     home prefix replaced by the literal `$HOME`,
#                          default the invoking user's own. The appliance and
#                          the workstation run under one account name, so an
#                          acquisition copied between them carries one prefix;
#                          a differing source names it here.
#
# The destination must be absent, because a partial overwrite would leave a
# transformation record describing files a later run replaced.

if [ "$#" -ne 2 ]; then
    printf 'usage: %s SOURCE_DIRECTORY DESTINATION_DIRECTORY\n' "$0" >&2
    exit 2
fi

source_directory=$1
destination_directory=$2

if [ ! -d "$source_directory" ]; then
    printf '%s: source directory is absent: %s\n' "$0" "$source_directory" >&2
    exit 2
fi
if [ -e "$destination_directory" ]; then
    printf '%s: destination already exists: %s\n' "$0" "$destination_directory" >&2
    exit 2
fi

sanitize_host=${QWEN_SANITIZE_HOST:-hp14-dk1xxx}
sanitize_home=${QWEN_SANITIZE_HOME:-${HOME:?the home prefix to sanitize is unset}}

source_directory=$(CDPATH='' cd -- "$source_directory" && pwd)
mkdir -p "$destination_directory"
destination_directory=$(CDPATH='' cd -- "$destination_directory" && pwd)

transformation_record=$destination_directory/transformation.tsv
{
    printf 'relative_path\tsource_sha256\tretained_sha256\tsubstitutions\n'
} >"$transformation_record"

# The walk takes regular files alone. A FIFO, socket, or device node is
# inventoried by the acquisition's own manifest and opening one here would
# block on a writer that left with the campaign.
find "$source_directory" -type f -printf '%P\n' | LC_ALL=C sort |
while IFS= read -r relative_path; do
    source_file=$source_directory/$relative_path
    destination_file=$destination_directory/$relative_path
    mkdir -p "$(dirname -- "$destination_file")"
    source_digest=$(sha256sum -- "$source_file" | cut -d' ' -f1)

    if LC_ALL=C grep -qI . "$source_file" 2>/dev/null || [ ! -s "$source_file" ]; then
        SANITIZE_HOST=$sanitize_host SANITIZE_HOME=$sanitize_home \
            python3 - "$source_file" "$destination_file" <<'SANITIZE'
import os, re, sys

source_path, destination_path = sys.argv[1], sys.argv[2]
text = open(source_path, encoding='utf-8', errors='surrogateescape').read()
substitutions = 0
for pattern, replacement in (
    (re.escape(os.environ['SANITIZE_HOST']), 'qwen-laptop'),
    (re.escape(os.environ['SANITIZE_HOME']), '$HOME'),
    (r'(?<![0-9A-Fa-f:])(?:[0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}(?![0-9A-Fa-f:])', '<mac>'),
):
    text, count = re.subn(pattern, replacement, text)
    substitutions += count
with open(destination_path, 'w', encoding='utf-8', errors='surrogateescape') as handle:
    handle.write(text)
print(substitutions)
SANITIZE
    else
        cp -- "$source_file" "$destination_file"
        printf 'binary\n'
    fi >"$destination_directory/.substitutions"
    substitutions=$(cat "$destination_directory/.substitutions")
    rm -f "$destination_directory/.substitutions"

    retained_digest=$(sha256sum -- "$destination_file" | cut -d' ' -f1)
    printf '%s\t%s\t%s\t%s\n' \
        "$relative_path" "$source_digest" "$retained_digest" "$substitutions" \
        >>"$transformation_record"
done

retained_files=$(( $(wc -l <"$transformation_record") - 1 ))
changed_files=$(awk -F'\t' 'NR > 1 && $4 != "binary" && $4 > 0 { count++ } END { print count + 0 }' \
    "$transformation_record")
unchanged_files=$(awk -F'\t' 'NR > 1 && $2 == $3 { count++ } END { print count + 0 }' \
    "$transformation_record")
printf 'retained_files=%s substituted_files=%s identical_files=%s record=%s\n' \
    "$retained_files" "$changed_files" "$unchanged_files" "$transformation_record"
