#!/bin/sh
set -eu

# A deployment bundle binds the release artifacts one activation swaps
# together: the llama-server binary, the artifact manifest that declares its
# checkpoint semantics, and the context checkpoint ledger the capacity policy
# reads. The binary and the ledger are separate release surfaces, so a
# rollback that moved only the binary would pair the frozen forced-tail build
# with a positive-count ledger and refuse every launch; the bundle makes the
# pair one unit and activate-deployment-bundle.sh swaps it atomically.
#
# usage: build-deployment-bundle.sh BUNDLE_NAME SERVER_PATH MANIFEST_PATH \
#            CTX_LEDGER [DEPLOYMENT_ROOT]
# DEPLOYMENT_ROOT defaults to ~/qwen-deployments.

if [ "$#" -lt 4 ] || [ "$#" -gt 5 ]; then
    printf 'usage: %s BUNDLE_NAME SERVER_PATH MANIFEST_PATH CTX_LEDGER [DEPLOYMENT_ROOT]\n' \
        "$0" >&2
    exit 2
fi

bundle_name=$1
server_path=$2
manifest_path=$3
ctx_ledger_path=$4
deployment_root=${5:-"${HOME:?}/qwen-deployments"}

case $bundle_name in
    *[!A-Za-z0-9._-]* | '')
        printf 'bundle name must be nonempty [A-Za-z0-9._-]: %s\n' \
            "$bundle_name" >&2
        exit 2
        ;;
esac
for required in "$server_path" "$manifest_path" "$ctx_ledger_path"; do
    if [ ! -r "$required" ]; then
        printf 'bundle input is unreadable: %s\n' "$required" >&2
        exit 1
    fi
done
if [ ! -x "$server_path" ]; then
    printf 'bundle server is not executable: %s\n' "$server_path" >&2
    exit 1
fi

server_sha256=$(sha256sum "$server_path" | cut -d ' ' -f 1)
server_bytes=$(wc -c <"$server_path" | tr -d ' ')

# The semantics are read from the manifest that travels into the bundle, and
# the manifest must own exactly one declaration and exactly one row matching
# this server's digest, the same discipline the exec guard applies: a
# manifest describing some other binary must fail assembly rather than
# activation.
checkpoint_semantics=$(awk -F'\t' '$1 == "checkpoint_semantics" { count++; value = $2 }
    END { if (count != 1) exit 1; print value }' "$manifest_path") || {
    printf 'bundle manifest must carry exactly one checkpoint_semantics row: %s\n' \
        "$manifest_path" >&2
    exit 1
}
manifest_digest_rows=$(grep -c "$server_sha256" "$manifest_path" || :)
if [ "$manifest_digest_rows" -ne 1 ]; then
    printf 'bundle manifest carries %s rows for server digest %s; exactly one is required: %s\n' \
        "$manifest_digest_rows" "$server_sha256" "$manifest_path" >&2
    exit 1
fi

# A positive checkpoint count is admissible only against natural-boundary-v1,
# so a bundle pairing them wrongly is refused at assembly, where the operator
# chose the inputs, rather than at the activation an incident is running on.
maximum_ledger_count=$(awk -F'\t' '/^#/ || NF == 0 { next }
    $1 == "model_id" { next }
    { if ($2 + 0 > maximum) maximum = $2 + 0 }
    END { print maximum + 0 }' "$ctx_ledger_path")
if [ "$maximum_ledger_count" -gt 0 ] && \
    [ "$checkpoint_semantics" != natural-boundary-v1 ]; then
    printf 'ledger carries a positive checkpoint count and the server declares %s; a positive count requires natural-boundary-v1\n' \
        "$checkpoint_semantics" >&2
    exit 1
fi

bundle_directory=$deployment_root/$bundle_name
if [ -e "$bundle_directory" ]; then
    printf 'bundle already exists: %s\n' "$bundle_directory" >&2
    exit 1
fi
staging_directory=$deployment_root/.$bundle_name.staging
rm -rf "$staging_directory"
mkdir -p "$staging_directory"
cp "$server_path" "$staging_directory/llama-server"
chmod 755 "$staging_directory/llama-server"
cp "$manifest_path" "$staging_directory/artifact-manifest.tsv"
cp "$ctx_ledger_path" "$staging_directory/ctx-checkpoints.tsv"

{
    printf 'bundle_name\t%s\n' "$bundle_name"
    printf 'created_utc\t%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'checkpoint_semantics\t%s\n' "$checkpoint_semantics"
    printf 'maximum_ledger_count\t%s\n' "$maximum_ledger_count"
    printf 'server_bytes\t%s\n' "$server_bytes"
    printf 'llama-server\t%s\n' "$server_sha256"
    printf 'artifact-manifest.tsv\t%s\n' \
        "$(sha256sum "$staging_directory/artifact-manifest.tsv" | cut -d ' ' -f 1)"
    printf 'ctx-checkpoints.tsv\t%s\n' \
        "$(sha256sum "$staging_directory/ctx-checkpoints.tsv" | cut -d ' ' -f 1)"
} >"$staging_directory/bundle-manifest.tsv"

# The rename is what makes a bundle exist: a partially written staging
# directory never carries the final name, so an interrupted assembly leaves
# nothing an activation could select.
mv "$staging_directory" "$bundle_directory"
printf 'deployment_bundle=%s semantics=%s maximum_count=%s server_sha256=%s\n' \
    "$bundle_directory" "$checkpoint_semantics" "$maximum_ledger_count" \
    "$server_sha256"
