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
# shellcheck source=remote/qwen-home.sh
. "$script_directory/qwen-home.sh"
bundle_name=$1
server_path=$2
manifest_path=$3
ctx_ledger_path=$4
deployment_root=${5:-"$qwen_home_deployments"}

name_helper=$script_directory/deployment-bundle-name.sh
if [ ! -r "$name_helper" ]; then
    printf 'deployment bundle name helper is unreadable: %s\n' "$name_helper" >&2
    exit 1
fi
# shellcheck source=deployment-bundle-name.sh
. "$name_helper"
if ! deployment_bundle_name_is_valid "$bundle_name"; then
    printf 'bundle name must match [A-Za-z0-9][A-Za-z0-9._-]* and avoid the root names: %s\n' \
        "$bundle_name" >&2
    exit 2
fi
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
# so the declaration is honored here rather than trusted to an operator. The
# eligibility grammar admits two shapes and refuses the rest. A manifest
# carrying zero serving_eligible rows is the legacy shape, admitted only where
# it also names no instrumentation. A manifest carrying exactly one row is
# admitted where that row's value is exactly `yes`, so an empty value -- a
# present declaration stating nothing -- is refused by its own reading rather
# than by falling through the legacy branch. A second row of either kind is
# refused on cardinality ahead of both, since a first-row reading of a
# manifest that declares twice reports one of two answers. An instrumentation
# row refuses the bundle at whatever eligibility spelling accompanies it, and
# that refusal precedes the eligibility reading so a diagnostic manifest names
# the instrumentation that identifies it however its eligibility row is
# spelled or deleted.
declaration_rows=$(awk -F'\t' '
    $1 == "serving_eligible" { eligible++ }
    $1 == "instrumentation" { instrumentation++ }
    END { print eligible + 0, instrumentation + 0 }' "$manifest_path")
serving_rows=${declaration_rows%% *}
instrumentation_rows=${declaration_rows##* }
if [ "$serving_rows" -gt 1 ] || [ "$instrumentation_rows" -gt 1 ]; then
    printf 'artifact manifest holds %s serving_eligible rows and %s instrumentation rows, at most one of each: %s\n' \
        "$serving_rows" "$instrumentation_rows" "$manifest_path" >&2
    exit 1
fi
if [ "$instrumentation_rows" -eq 1 ]; then
    declared_instrumentation=$(awk -F'\t' \
        '$1 == "instrumentation" { print $2; exit }' "$manifest_path")
    printf 'artifact manifest names instrumentation %s; a bundle carries serving builds alone: %s\n' \
        "${declared_instrumentation:-<empty>}" "$manifest_path" >&2
    exit 1
fi
if [ "$serving_rows" -eq 1 ]; then
    serving_eligible=$(awk -F'\t' '$1 == "serving_eligible" { print $2; exit }' \
        "$manifest_path")
    if [ "$serving_eligible" != yes ]; then
        printf 'artifact manifest declares serving_eligible %s; a bundle carries serving builds alone: %s\n' \
            "${serving_eligible:-<empty>}" "$manifest_path" >&2
        exit 1
    fi
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
# staged tree is verified as a bundle before the rename publishes it. The
# .staging parent is a plain directory this process creates or reuses at mode
# 700: a symlink there would carry the copied server, the ledger, and the
# preset into whatever directory the link named, and the trap that removes
# the staging root would remove that directory's contents with them. The
# bundle.XXXXXX leaf is fresh, since mktemp creates it and refuses a name
# that already exists.
staging_parent=$deployment_root/.staging
if [ -L "$staging_parent" ]; then
    printf 'bundle staging parent is a symlink: %s\n' "$staging_parent" >&2
    exit 1
fi
if [ -e "$staging_parent" ]; then
    if [ ! -d "$staging_parent" ]; then
        printf 'bundle staging parent is not a directory: %s\n' \
            "$staging_parent" >&2
        exit 1
    fi
else
    mkdir -m 700 "$staging_parent"
fi
staging_root=$(mktemp -d "$staging_parent/bundle.XXXXXX")
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

# A merged router preset names one MCP configuration per web section, and that
# configuration is session state rather than release state: its contents name
# QWEN_WEB_STATE_DIR, the broker signing key, and the per-profile budgets, and
# rewriting those paths to bundle-relative ones would change the preset bytes
# the digest binds. The bundle records the path and the digest of each
# configuration and leaves the file where the generator wrote it.
#
# The preset own `# qwen_web_sections=` marker decides whether a record exists
# at all, so a bundle assembled from a registry preset carries none and a
# bundle assembled from a merged one carries exactly the sections the marker
# names. verify-deployment-bundle.sh applies the same rule, which is what lets
# a deployment that predates this lane keep resolving: requiring the record of
# every bundle refused the whole roster on natural-boundary-13d05a0-r2, whose
# preset carries no marker, and left the appliance serving through recovery
# mode alone.
#
# One row shape serves every reader: `profile_id`, `configuration_path`,
# `sha256`, `image_server`, tab-separated, with `image_server` over `image` and
# `-`. The header line the record carries states it in the file itself.
# verify-deployment-bundle.sh and qwen-launch.sh both parse four fields and read
# a three-field row -- one written before the image lane -- as an absent
# `image_server`, which is the withheld lane an unmarked preset also names. A
# reader taking three fields measures the digest against `<sha256><TAB>image`,
# which is what a fourth column added without its readers cost the appliance on
# natural-boundary-13d05a0-r4-image: the bundle verified and every launch
# refused.
web_mcp_manifest_sha256=-
if [ -n "$router_presets_path" ]; then
    preset_web_sections=$(sed -n 's/^# qwen_web_sections=//p' \
        "$staging_directory/router-presets.ini")
    case $preset_web_sections in
        '-') preset_web_sections='' ;;
    esac
    web_mcp_rows=$(awk '
        /^[[:space:]]*\[/ {
            section = $0
            sub(/^[[:space:]]*\[/, "", section)
            sub(/\][[:space:]]*$/, "", section)
            next
        }
        /^[[:space:]]*LLAMA_ARG_MCP_SERVERS_CONFIG[[:space:]]*=/ {
            value = $0
            sub(/^[^=]*=[[:space:]]*/, "", value)
            sub(/[[:space:]]+$/, "", value)
            printf "%s\t%s\n", section, value
        }
    ' "$staging_directory/router-presets.ini")
    if [ -z "$preset_web_sections" ] && [ -n "$web_mcp_rows" ]; then
        printf 'bundle router preset names MCP configurations and its head marker names no web section: %s\n' \
            "$router_presets_path" >&2
        exit 1
    fi
    if [ -n "$preset_web_sections" ] && [ -z "$web_mcp_rows" ]; then
        printf 'bundle router preset names web section %s and no section carries LLAMA_ARG_MCP_SERVERS_CONFIG: %s\n' \
            "$preset_web_sections" "$router_presets_path" >&2
        exit 1
    fi
    # The image server lives inside the same per-section configuration, so the
    # record gains a column rather than a file: `image` where that section arms
    # a generation and `-` where it carries the search server alone. The preset
    # own `# qwen_image_profile=` marker decides which the row has to read, and
    # verify-deployment-bundle.sh compares the two without opening a file a
    # machine that never armed the lane holds none of.
    preset_image_profile=$(sed -n 's/^# qwen_image_profile=//p' \
        "$staging_directory/router-presets.ini")
    case $preset_image_profile in
        '-') preset_image_profile='' ;;
    esac
    if [ -n "$preset_image_profile" ]; then
        expected_image_column=image
        if [ -z "$preset_web_sections" ]; then
            printf 'bundle router preset names image profile %s and its head marker names no web section: %s\n' \
                "$preset_image_profile" "$router_presets_path" >&2
            exit 1
        fi
    else
        expected_image_column=-
    fi
    if [ -n "$preset_web_sections" ]; then
        {
            printf '# profile_id\tconfiguration_path\tsha256\timage_server\n'
            printf '%s\n' "$web_mcp_rows" |
                while IFS='	' read -r web_section web_configuration; do
                    if [ ! -r "$web_configuration" ]; then
                        printf 'bundle preset section %s names an unreadable MCP configuration: %s\n' \
                            "$web_section" "$web_configuration" >&2
                        exit 1
                    fi
                    if ! image_server_report=$(
                        "$script_directory/read-image-mcp-server.py" \
                            "$web_configuration"
                    ); then
                        printf 'bundle preset section %s names an MCP configuration this record cannot read: %s\n' \
                            "$web_section" "$web_configuration" >&2
                        exit 1
                    fi
                    image_server_column=-
                    if [ "$(printf '%s\n' "$image_server_report" |
                        sed -n 's/^image_server=//p')" = present ]; then
                        image_server_column=image
                        recorded_image_profile=$(printf '%s\n' \
                            "$image_server_report" |
                            sed -n 's/^QWEN_IMAGE_PROFILE=//p')
                        if [ "$recorded_image_profile" != "$preset_image_profile" ]; then
                            printf 'bundle preset section %s arms image profile %s where its preset names %s\n' \
                                "$web_section" "$recorded_image_profile" \
                                "${preset_image_profile:--}" >&2
                            exit 1
                        fi
                        # The grant binds the generation to the section that
                        # proposed it, so a configuration copied or left stale
                        # from another section's build is a language-profile
                        # binding the bundle must not carry forward silently:
                        # qwen-capacity-policy.sh rejoins
                        # QWEN_IMAGE_LANGUAGE_PROFILE to the section at launch
                        # and refuses the mismatch there, so the bundle would
                        # verify and activate a manifest no launch can serve.
                        recorded_language_profile=$(printf '%s\n' \
                            "$image_server_report" |
                            sed -n 's/^QWEN_IMAGE_LANGUAGE_PROFILE=//p')
                        if [ "$recorded_language_profile" != "$web_section" ]; then
                            printf 'bundle preset section %s carries an image server bound to language profile %s\n' \
                                "$web_section" "$recorded_language_profile" >&2
                            exit 1
                        fi
                    fi
                    if [ "$image_server_column" != "$expected_image_column" ]; then
                        printf 'bundle preset section %s reads image_server %s where its preset marker reads %s\n' \
                            "$web_section" "$image_server_column" \
                            "$expected_image_column" >&2
                        exit 1
                    fi
                    printf '%s\t%s\t%s\t%s\n' "$web_section" \
                        "$web_configuration" \
                        "$(sha256sum -- "$web_configuration" | cut -d ' ' -f 1)" \
                        "$image_server_column"
                done
        } >"$staging_directory/web-mcp-manifest.tsv" || exit 1
        chmod 600 "$staging_directory/web-mcp-manifest.tsv"
        web_mcp_manifest_sha256=$(sha256sum \
            "$staging_directory/web-mcp-manifest.tsv" | cut -d ' ' -f 1)
    fi
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
    printf 'web-mcp-manifest.tsv\t%s\n' "$web_mcp_manifest_sha256"
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
printf 'deployment_bundle=%s semantics=%s maximum_count=%s server_sha256=%s router_presets=%s web_presets=%s web_mcp_manifest=%s\n' \
    "$bundle_directory" "$checkpoint_semantics" "$maximum_ledger_count" \
    "$server_sha256" "$router_presets_sha256" "$web_presets_sha256" \
    "$web_mcp_manifest_sha256"
