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
# The router and web presets belong to the same unit, because each section
# carries LLAMA_ARG_CTX_CHECKPOINTS from the ledger it was generated against:
# a rollback that moved the ledger and left the state directory's preset in
# place would put a count of 2 in front of a build declaring forced-tail-v1.
# QWEN_BUNDLE_ROUTER_PRESETS and QWEN_BUNDLE_WEB_PRESETS name preset files
# generated against CTX_LEDGER; each named file is verified against the ledger,
# copied in as router-presets.ini or web-presets.ini, and digested into the
# bundle manifest, and an unnamed one is recorded as `-`.
#
# usage: build-deployment-bundle.sh BUNDLE_NAME SERVER_PATH MANIFEST_PATH \
#            CTX_LEDGER [DEPLOYMENT_ROOT]
# DEPLOYMENT_ROOT defaults to ~/qwen-deployments.

if [ "$#" -lt 4 ] || [ "$#" -gt 5 ]; then
    printf 'usage: %s BUNDLE_NAME SERVER_PATH MANIFEST_PATH CTX_LEDGER [DEPLOYMENT_ROOT]\n' \
        "$0" >&2
    exit 2
fi

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
bundle_name=$1
server_path=$2
manifest_path=$3
ctx_ledger_path=$4
deployment_root=${5:-"${HOME:?}/qwen-deployments"}

# A bundle name starts with an alphanumeric, so it can never spell a
# dot-prefixed root entry, and the root's own names are reserved.
case $bundle_name in
    '' | [!A-Za-z0-9]* | *[!A-Za-z0-9._-]* | deployment-current | \
        deployment-previous | deployment-state | deployment-state.* | . | ..)
        printf 'bundle name must match [A-Za-z0-9][A-Za-z0-9._-]* and avoid the root names: %s\n' \
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
# the manifest must own exactly one declaration and exactly one executable row
# whose byte count and digest match this server, the same row shape
# qwen-build-exec-guard.sh requires: a digest appearing in a comment or in
# another object's row binds nothing.
checkpoint_semantics=$(awk -F'\t' '$1 == "checkpoint_semantics" { count++; value = $2 }
    END { if (count != 1) exit 1; print value }' "$manifest_path") || {
    printf 'bundle manifest must carry exactly one checkpoint_semantics row: %s\n' \
        "$manifest_path" >&2
    exit 1
}
named_rows=$(awk -F'\t' '
    $1 == "executable" && $2 == "llama-server" && NF == 4 { count++ }
    END { print count + 0 }' "$manifest_path")
if [ "$named_rows" -ne 1 ]; then
    printf 'artifact manifest holds %s executable llama-server rows; exactly one is required: %s\n' \
        "$named_rows" "$manifest_path" >&2
    exit 1
fi
# A diagnostic build names its instrumentation and declares itself unfit to
# serve; the bundle is the unit an activation makes the appliance's server,
# so the declaration is honored here rather than trusted to an operator.
serving_eligible=$(awk -F'\t' '$1 == "serving_eligible" { print $2; exit }' \
    "$manifest_path")
if [ -n "$serving_eligible" ] && [ "$serving_eligible" != yes ]; then
    printf 'artifact manifest declares serving_eligible %s (instrumentation %s); a bundle carries serving builds alone: %s\n' \
        "$serving_eligible" \
        "$(awk -F'\t' '$1 == "instrumentation" { print $2; exit }' "$manifest_path")" \
        "$manifest_path" >&2
    exit 1
fi

executable_rows=$(awk -F'\t' -v bytes="$server_bytes" -v digest="$server_sha256" '
    $1 == "executable" && $2 == "llama-server" && NF == 4 &&
        $3 == bytes && $4 == digest { count++ }
    END { print count + 0 }' "$manifest_path")
if [ "$executable_rows" -ne 1 ]; then
    printf 'artifact manifest executable llama-server row does not match %s bytes %s: %s\n' \
        "$server_bytes" "$server_sha256" "$manifest_path" >&2
    exit 1
fi

# The ledger is read through the registry validator rather than a local awk,
# so a malformed count, a duplicate id, a model outside the registry, or a
# positive count with no evidence refuses assembly instead of contributing
# zero to the maximum.
validated_ledger_rows=$(QWEN_CTX_CHECKPOINT_LEDGER=$ctx_ledger_path \
    "$script_directory/model-registry.sh" ctx-checkpoints) || {
    printf 'context checkpoint ledger failed registry validation: %s\n' \
        "$ctx_ledger_path" >&2
    exit 1
}
maximum_ledger_count=$(printf '%s\n' "$validated_ledger_rows" | awk -F'\t' '
    { if ($2 + 0 > maximum) maximum = $2 + 0 }
    END { print maximum + 0 }')

# A positive checkpoint count is admissible only against natural-boundary-v1,
# so a bundle pairing them wrongly is refused at assembly, where the operator
# chose the inputs, rather than at the activation an incident is running on.
if [ "$maximum_ledger_count" -gt 0 ] && \
    [ "$checkpoint_semantics" != natural-boundary-v1 ]; then
    printf 'ledger carries a positive checkpoint count and the server declares %s; a positive count requires natural-boundary-v1\n' \
        "$checkpoint_semantics" >&2
    exit 1
fi

router_presets_path=${QWEN_BUNDLE_ROUTER_PRESETS:-}
web_presets_path=${QWEN_BUNDLE_WEB_PRESETS:-}
for preset_input in "$router_presets_path" "$web_presets_path"; do
    [ -n "$preset_input" ] || continue
    if [ ! -r "$preset_input" ] || [ ! -f "$preset_input" ]; then
        printf 'bundle preset input is not a readable file: %s\n' \
            "$preset_input" >&2
        exit 1
    fi
    if ! "$script_directory/verify-bundle-preset-ledger.sh" \
        "$preset_input" "$ctx_ledger_path" >/dev/null; then
        printf 'bundle preset disagrees with the bundle ledger: %s\n' \
            "$preset_input" >&2
        exit 1
    fi
done

bundle_directory=$deployment_root/$bundle_name
if [ -e "$bundle_directory" ]; then
    printf 'bundle already exists: %s\n' "$bundle_directory" >&2
    exit 1
fi
# Staging is a private random directory under .staging, so no bundle name
# can collide with a staging path and nothing existing is ever removed; the
# staged tree is verified as a bundle before the rename publishes it.
mkdir -p "$deployment_root/.staging"
staging_root=$(mktemp -d "$deployment_root/.staging/bundle.XXXXXX")
staging_directory=$staging_root/$bundle_name
trap 'rm -rf "$staging_root"' EXIT HUP INT TERM
mkdir "$staging_directory"
cp "$server_path" "$staging_directory/llama-server"
chmod 755 "$staging_directory/llama-server"
cp "$manifest_path" "$staging_directory/artifact-manifest.tsv"
cp "$ctx_ledger_path" "$staging_directory/ctx-checkpoints.tsv"
router_presets_sha256=-
if [ -n "$router_presets_path" ]; then
    cp "$router_presets_path" "$staging_directory/router-presets.ini"
    chmod 600 "$staging_directory/router-presets.ini"
    router_presets_sha256=$(sha256sum "$staging_directory/router-presets.ini" |
        cut -d ' ' -f 1)
fi
web_presets_sha256=-
if [ -n "$web_presets_path" ]; then
    cp "$web_presets_path" "$staging_directory/web-presets.ini"
    chmod 600 "$staging_directory/web-presets.ini"
    web_presets_sha256=$(sha256sum "$staging_directory/web-presets.ini" |
        cut -d ' ' -f 1)
fi

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
    printf 'router-presets.ini\t%s\n' "$router_presets_sha256"
    printf 'web-presets.ini\t%s\n' "$web_presets_sha256"
} >"$staging_directory/bundle-manifest.tsv"

# The staged bundle passes the same verification an activation applies,
# under its own name below the staging root, before anything carries the
# final name; a partially written or refused staging tree is removed by the
# trap and an interrupted assembly leaves nothing an activation could select.
if ! "$script_directory/verify-deployment-bundle.sh" "$staging_root" "$bundle_name" \
    >/dev/null; then
    printf 'staged bundle failed verification and was not published: %s\n' \
        "$bundle_name" >&2
    exit 1
fi
if [ -e "$bundle_directory" ] || [ -L "$bundle_directory" ]; then
    printf 'bundle already exists: %s\n' "$bundle_directory" >&2
    exit 1
fi
mv -T "$staging_directory" "$bundle_directory"
printf 'deployment_bundle=%s semantics=%s maximum_count=%s server_sha256=%s router_presets=%s web_presets=%s\n' \
    "$bundle_directory" "$checkpoint_semantics" "$maximum_ledger_count" \
    "$server_sha256" "$router_presets_sha256" "$web_presets_sha256"
