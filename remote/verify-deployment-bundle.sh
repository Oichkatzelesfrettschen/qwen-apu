#!/bin/sh
set -eu

# One verification of a deployment bundle, shared by activation and by the
# launch-side resolver. Every claim the bundle manifest states is recomputed
# from the members' own bytes, so an internal manifest edited to match a
# tampered member still fails on the semantics, ledger, executable-row, and
# preset recomputation. The bundle is also held inside the deployment root
# lexically and canonically: its name is one path component, the directory
# and each member are plain files rather than symlinks, and the canonical
# directory sits immediately below the canonical root, so a link planted at
# the root cannot carry an activation or a launch outside it.
#
# usage: verify-deployment-bundle.sh DEPLOYMENT_ROOT BUNDLE_NAME
# Prints `deployment_bundle_verified=NAME directory=CANONICAL_PATH`.

if [ "$#" -ne 2 ]; then
    printf 'usage: %s DEPLOYMENT_ROOT BUNDLE_NAME\n' "$0" >&2
    exit 2
fi

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
deployment_root=$1
bundle_name=$2

case $bundle_name in
    *[!A-Za-z0-9._-]* | '' | deployment-current | deployment-previous | \
        deployment-state | deployment-state.* | . | ..)
        printf 'bundle name must be nonempty [A-Za-z0-9._-] and not a link name: %s\n' \
            "$bundle_name" >&2
        exit 1
        ;;
esac
if [ ! -d "$deployment_root" ]; then
    printf 'deployment root is not a directory: %s\n' "$deployment_root" >&2
    exit 1
fi
canonical_root=$(readlink -f -- "$deployment_root")
bundle_directory=$deployment_root/$bundle_name
if [ -L "$bundle_directory" ]; then
    printf 'bundle directory is a symlink and stays inactive: %s\n' \
        "$bundle_directory" >&2
    exit 1
fi
if [ ! -d "$bundle_directory" ]; then
    printf 'bundle directory is absent: %s\n' "$bundle_directory" >&2
    exit 1
fi
canonical_directory=$(readlink -f -- "$bundle_directory")
if [ "$canonical_directory" != "$canonical_root/$bundle_name" ]; then
    printf 'bundle directory resolves outside the deployment root: %s resolves to %s\n' \
        "$bundle_directory" "$canonical_directory" >&2
    exit 1
fi

bundle_manifest=$bundle_directory/bundle-manifest.tsv
for bundle_member in bundle-manifest.tsv llama-server artifact-manifest.tsv \
    ctx-checkpoints.tsv router-presets.ini web-presets.ini; do
    if [ -L "$bundle_directory/$bundle_member" ]; then
        printf 'bundle member is a symlink: %s\n' \
            "$bundle_directory/$bundle_member" >&2
        exit 1
    fi
done
if [ ! -r "$bundle_manifest" ] || [ ! -f "$bundle_manifest" ]; then
    printf 'bundle manifest is unreadable: %s\n' "$bundle_manifest" >&2
    exit 1
fi
for manifest_key in bundle_name checkpoint_semantics maximum_ledger_count \
    server_bytes llama-server artifact-manifest.tsv ctx-checkpoints.tsv \
    router-presets.ini web-presets.ini; do
    manifest_key_rows=$(awk -F'\t' -v key="$manifest_key" \
        '$1 == key { count++ } END { print count + 0 }' "$bundle_manifest")
    if [ "$manifest_key_rows" -ne 1 ]; then
        printf 'bundle manifest carries %s rows for %s; exactly one is required: %s\n' \
            "$manifest_key_rows" "$manifest_key" "$bundle_manifest" >&2
        exit 1
    fi
done
# The name a bundle was assembled under is the name it activates under: a
# directory renamed onto another bundle's name would otherwise publish one
# bundle's bytes under a role record naming another.
declared_name=$(awk -F'\t' '$1 == "bundle_name" { print $2; exit }' \
    "$bundle_manifest")
if [ "$declared_name" != "$bundle_name" ]; then
    printf 'bundle directory %s carries bundle_name %s\n' \
        "$bundle_name" "$declared_name" >&2
    exit 1
fi
for bundle_member in llama-server artifact-manifest.tsv ctx-checkpoints.tsv; do
    expected_sha256=$(awk -F'\t' -v key="$bundle_member" \
        '$1 == key { print $2; exit }' "$bundle_manifest")
    if [ ! -r "$bundle_directory/$bundle_member" ] || \
        [ ! -f "$bundle_directory/$bundle_member" ]; then
        printf 'bundle member is unreadable: %s\n' \
            "$bundle_directory/$bundle_member" >&2
        exit 1
    fi
    actual_sha256=$(sha256sum "$bundle_directory/$bundle_member" |
        cut -d ' ' -f 1)
    if [ "$actual_sha256" != "$expected_sha256" ]; then
        printf 'bundle member diverged: %s expected=%s found=%s\n' \
            "$bundle_member" "$expected_sha256" "$actual_sha256" >&2
        exit 1
    fi
done
if [ ! -x "$bundle_directory/llama-server" ]; then
    printf 'bundle server is not executable: %s\n' \
        "$bundle_directory/llama-server" >&2
    exit 1
fi
# The semantics are recomputed from the artifact manifest and the server's
# own bytes, and the bundle manifest must agree with what was recomputed.
measured_bytes=$(wc -c <"$bundle_directory/llama-server" | tr -d ' ')
measured_sha256=$(sha256sum "$bundle_directory/llama-server" | cut -d ' ' -f 1)
declared_bytes=$(awk -F'\t' '$1 == "server_bytes" { print $2; exit }' \
    "$bundle_manifest")
if [ "$measured_bytes" != "$declared_bytes" ]; then
    printf 'bundle server measures %s bytes against the declared %s\n' \
        "$measured_bytes" "$declared_bytes" >&2
    exit 1
fi
# The exec guard requires exactly one executable llama-server row and then
# checks that row, so the bundle requires the same two facts: one named row,
# and that row matching the bundled server's bytes and digest. A manifest
# with a second conflicting row would pass a match count alone and refuse at
# the exec boundary.
named_rows=$(awk -F'\t' '
    $1 == "executable" && $2 == "llama-server" && NF == 4 { count++ }
    END { print count + 0 }' "$bundle_directory/artifact-manifest.tsv")
if [ "$named_rows" -ne 1 ]; then
    printf 'artifact manifest holds %s executable llama-server rows; exactly one is required\n' \
        "$named_rows" >&2
    exit 1
fi
executable_rows=$(awk -F'\t' -v bytes="$measured_bytes" \
    -v digest="$measured_sha256" '
    $1 == "executable" && $2 == "llama-server" && NF == 4 &&
        $3 == bytes && $4 == digest { count++ }
    END { print count + 0 }' "$bundle_directory/artifact-manifest.tsv")
if [ "$executable_rows" -ne 1 ]; then
    printf 'artifact manifest executable llama-server row does not match the bundled server\n' >&2
    exit 1
fi
declaration_rows=$(awk -F'\t' '
    $1 == "serving_eligible" { eligible++ }
    $1 == "instrumentation" { instrumentation++ }
    END { print eligible + 0, instrumentation + 0 }' "$bundle_directory/artifact-manifest.tsv")
serving_rows=${declaration_rows%% *}
instrumentation_rows=${declaration_rows##* }
if [ "$serving_rows" -gt 1 ] || [ "$instrumentation_rows" -gt 1 ]; then
    printf 'artifact manifest holds %s serving_eligible rows and %s instrumentation rows, at most one of each: %s\n' \
        "$serving_rows" "$instrumentation_rows" "$bundle_directory/artifact-manifest.tsv" >&2
    exit 1
fi
serving_eligible=$(awk -F'\t' '$1 == "serving_eligible" { print $2; exit }' \
    "$bundle_directory/artifact-manifest.tsv")
if [ -n "$serving_eligible" ] && [ "$serving_eligible" != yes ]; then
    printf 'bundle artifact manifest declares serving_eligible %s; a diagnostic build stays inactive\n' \
        "$serving_eligible" >&2
    exit 1
fi
recomputed_semantics=$(awk -F'\t' \
    '$1 == "checkpoint_semantics" { count++; value = $2 }
    END { if (count != 1) exit 1; print value }' \
    "$bundle_directory/artifact-manifest.tsv") || {
    printf 'artifact manifest must carry exactly one checkpoint_semantics row\n' >&2
    exit 1
}
declared_semantics=$(awk -F'\t' \
    '$1 == "checkpoint_semantics" { print $2; exit }' "$bundle_manifest")
if [ "$recomputed_semantics" != "$declared_semantics" ]; then
    printf 'artifact manifest declares checkpoint_semantics %s against the bundle manifest declaration %s\n' \
        "$recomputed_semantics" "$declared_semantics" >&2
    exit 1
fi
# The ledger is revalidated through the registry validator, and the maximum
# count is recomputed from the validated rows.
validated_ledger_rows=$(QWEN_CTX_CHECKPOINT_LEDGER=$bundle_directory/ctx-checkpoints.tsv \
    "$script_directory/model-registry.sh" ctx-checkpoints) || {
    printf 'bundle ledger failed registry validation: %s\n' \
        "$bundle_directory/ctx-checkpoints.tsv" >&2
    exit 1
}
recomputed_maximum=$(printf '%s\n' "$validated_ledger_rows" | awk -F'\t' '
    { if ($2 + 0 > maximum) maximum = $2 + 0 }
    END { print maximum + 0 }')
declared_maximum=$(awk -F'\t' \
    '$1 == "maximum_ledger_count" { print $2; exit }' "$bundle_manifest")
if [ "$recomputed_maximum" != "$declared_maximum" ]; then
    printf 'bundle ledger maximum count %s disagrees with the declared %s\n' \
        "$recomputed_maximum" "$declared_maximum" >&2
    exit 1
fi
if [ "$recomputed_maximum" -gt 0 ] && \
    [ "$recomputed_semantics" != natural-boundary-v1 ]; then
    printf 'bundle pairs a positive checkpoint count with %s; a positive count requires natural-boundary-v1\n' \
        "$recomputed_semantics" >&2
    exit 1
fi
# A preset member is present exactly where the manifest digests one, and its
# sections are re-read against the bundled ledger and the registry rather
# than trusted from the digest alone.
for preset_member in router-presets.ini web-presets.ini; do
    expected_sha256=$(awk -F'\t' -v key="$preset_member" \
        '$1 == key { print $2; exit }' "$bundle_manifest")
    if [ "$expected_sha256" = - ]; then
        if [ -e "$bundle_directory/$preset_member" ]; then
            printf 'bundle carries %s that its manifest records as absent\n' \
                "$preset_member" >&2
            exit 1
        fi
        continue
    fi
    if [ ! -r "$bundle_directory/$preset_member" ] || \
        [ ! -f "$bundle_directory/$preset_member" ]; then
        printf 'bundle member is unreadable: %s\n' \
            "$bundle_directory/$preset_member" >&2
        exit 1
    fi
    actual_sha256=$(sha256sum "$bundle_directory/$preset_member" |
        cut -d ' ' -f 1)
    if [ "$actual_sha256" != "$expected_sha256" ]; then
        printf 'bundle member diverged: %s expected=%s found=%s\n' \
            "$preset_member" "$expected_sha256" "$actual_sha256" >&2
        exit 1
    fi
    if ! "$script_directory/verify-bundle-preset-ledger.sh" \
        "$bundle_directory/$preset_member" \
        "$bundle_directory/ctx-checkpoints.tsv" >/dev/null; then
        printf 'bundle preset %s disagrees with the bundled ledger\n' \
            "$preset_member" >&2
        exit 1
    fi
done
printf 'deployment_bundle_verified=%s directory=%s\n' \
    "$bundle_name" "$canonical_directory"
