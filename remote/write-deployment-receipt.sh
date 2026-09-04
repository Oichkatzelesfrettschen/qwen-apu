#!/bin/sh
set -eu

# One receipt binds a served deployment's identity to the commit it derives
# from, so a later question -- which main commit is this LAN peer talking to --
# reads one file instead of six live probes. The receipt names the active
# bundle's own members, the synced runtime tree beside it, the model and
# checkpoint ledgers the registry reads, the candidate patch identity a served
# reply's prefix-checkpoint behavior depends on, and the LAN exposure boundary
# the running session recorded, each beside the file it was read from so a
# claim here is checkable against the tree that produced it. evidence/
# deployment-epochs/README.md registers the schema and the epoch-tagging rule
# this receipt exists to support.
#
# Every claim is read rather than asserted: resolve-active-deployment.sh
# verifies the bundle before this script reads a byte of it, and
# check-runtime-tree.sh recomputes the runtime tree's own digests before this
# script reads its manifest. A resolution or a verification failure refuses
# the receipt rather than writing a row naming a file this run never
# confirmed.
#
# usage: write-deployment-receipt.sh ROOT OUTPUT_TSV
#   ROOT is the deployment root resolve-active-deployment.sh reads
#   (QWEN_DEPLOYMENT_ROOT's own default is ~/qwen-deployments, this script
#   takes ROOT as an explicit argument instead since a receipt names the root
#   it was written against).
#
#   QWEN_RECEIPT_RUNTIME_TREE_ROOT   the synced runtime tree to read
#                                     runtime-tree-manifest.tsv from; default
#                                     is this script's own parent directory,
#                                     which is the runtime tree itself when
#                                     this script runs from a synced copy
#   QWEN_RECEIPT_MODEL_REGISTRY      remote/models.tsv to digest; default is
#                                     the copy beside this script
#   QWEN_RECEIPT_STATE_DIRECTORY     the webui session state directory to read
#                                     session.status from; default
#                                     $HOME/qwen-webui-state
#
# The output carries one field per row -- name, value, source path -- and a
# closing receipt_sha256 row over every row above it, so the receipt proves
# its own bytes the way a bundle member proves its own digest.

if [ "$#" -ne 2 ]; then
    printf 'usage: %s ROOT OUTPUT_TSV\n' "$0" >&2
    exit 2
fi

deployment_root=$1
output_tsv=$2

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
# shellcheck source=remote/qwen-home.sh
. "$script_directory/qwen-home.sh"
runtime_tree_root=${QWEN_RECEIPT_RUNTIME_TREE_ROOT:-$(CDPATH='' cd -- "$script_directory/.." && pwd)}
model_registry=${QWEN_RECEIPT_MODEL_REGISTRY:-"$script_directory/models.tsv"}
state_directory=${QWEN_RECEIPT_STATE_DIRECTORY:-"$qwen_home_state"}

for required_tool in sha256sum awk sed; do
    if ! command -v "$required_tool" >/dev/null 2>&1; then
        printf '%s is required\n' "$required_tool" >&2
        exit 2
    fi
done

output_directory=$(dirname -- "$output_tsv")
if [ ! -d "$output_directory" ]; then
    printf 'output directory does not exist: %s\n' "$output_directory" >&2
    exit 1
fi

# The runtime tree is verified before any of its bytes are read, the same
# refusal check-runtime-tree.sh applies to a launch: an unsynced source clone
# or a divergent copy names no identity this receipt can stand behind.
if [ ! -x "$script_directory/check-runtime-tree.sh" ]; then
    printf 'check-runtime-tree.sh is required beside %s\n' "$script_directory" >&2
    exit 1
fi
runtime_tree_report=$("$script_directory/check-runtime-tree.sh" "$runtime_tree_root") || {
    printf 'runtime tree at %s failed verification; sync it before writing a receipt\n' \
        "$runtime_tree_root" >&2
    exit 1
}
case $runtime_tree_report in
    runtime_tree=verified*) ;;
    *)
        printf 'runtime tree at %s reads %s; a receipt requires a verified synced copy\n' \
            "$runtime_tree_root" "$runtime_tree_report" >&2
        exit 1
        ;;
esac
runtime_tree_manifest=$runtime_tree_root/runtime-tree-manifest.tsv
if [ ! -r "$runtime_tree_manifest" ]; then
    printf 'runtime tree reports verified and carries no manifest: %s\n' \
        "$runtime_tree_manifest" >&2
    exit 1
fi

read_manifest_row() {
    awk -F'\t' -v key="$1" '$1 == key { print $2; exit }' "$2"
}

main_commit=$(read_manifest_row git_head "$runtime_tree_manifest")
runtime_tree_digest=$(read_manifest_row remote_payload_tree_sha256 "$runtime_tree_manifest")
patch_tree_digest=$(read_manifest_row patches_payload_tree_sha256 "$runtime_tree_manifest")
if [ -z "$main_commit" ] || [ -z "$runtime_tree_digest" ] || [ -z "$patch_tree_digest" ]; then
    printf 'runtime tree manifest carries no git_head or payload digest rows: %s\n' \
        "$runtime_tree_manifest" >&2
    exit 1
fi
# sync-runtime-tree.sh appends -dirty to git_head where the workstation
# working tree differed from HEAD at sync time, so that value names no commit
# a git tag can point at. evidence/deployment-epochs/README.md's tag rule
# requires main_commit to be taggable, so a dirty sync refuses the receipt
# here rather than writing a field the tag rule cannot act on.
case $main_commit in
    *-dirty)
        printf 'runtime tree was synced from a dirty working tree: %s\n' "$main_commit" >&2
        printf 'commit or stash the workstation changes and re-sync before writing a receipt\n' >&2
        exit 1
        ;;
esac

# resolve-active-deployment.sh takes the activation lock shared and verifies
# the bundle whole, so every path it prints already passed
# verify-deployment-bundle.sh's own member-digest and preset-ledger checks.
if [ ! -x "$script_directory/resolve-active-deployment.sh" ]; then
    printf 'resolve-active-deployment.sh is required beside %s\n' "$script_directory" >&2
    exit 1
fi
resolved=$("$script_directory/resolve-active-deployment.sh" "$deployment_root") || {
    resolve_status=$?
    printf 'no verified active deployment under %s\n' "$deployment_root" >&2
    exit "$resolve_status"
}
active_directory=$(printf '%s\n' "$resolved" | sed -n 's/^active_deployment_directory=//p')
active_manifest=$(printf '%s\n' "$resolved" | sed -n 's/^active_deployment_manifest=//p')
if [ -z "$active_directory" ] || [ -z "$active_manifest" ]; then
    printf 'resolve-active-deployment.sh printed no directory or bundle manifest for %s\n' \
        "$deployment_root" >&2
    exit 1
fi
bundle_manifest=$active_directory/bundle-manifest.tsv
if [ ! -r "$bundle_manifest" ]; then
    printf 'bundle manifest is unreadable: %s\n' "$bundle_manifest" >&2
    exit 1
fi

server_digest=$(read_manifest_row 'llama-server' "$bundle_manifest")
bundle_digest=$(sha256sum "$bundle_manifest" | cut -d ' ' -f 1)
router_preset_digest=$(read_manifest_row 'router-presets.ini' "$bundle_manifest")
web_preset_digest=$(read_manifest_row 'web-presets.ini' "$bundle_manifest")
checkpoint_ledger_digest=$(read_manifest_row 'ctx-checkpoints.tsv' "$bundle_manifest")
if [ -z "$server_digest" ] || [ -z "$checkpoint_ledger_digest" ]; then
    printf 'bundle manifest carries no llama-server or ctx-checkpoints.tsv row: %s\n' \
        "$bundle_manifest" >&2
    exit 1
fi
router_preset_digest=${router_preset_digest:--}
web_preset_digest=${web_preset_digest:--}
router_preset_source=$active_directory/router-presets.ini
[ "$router_preset_digest" != - ] || router_preset_source=-
web_preset_source=$active_directory/web-presets.ini
[ "$web_preset_digest" != - ] || web_preset_source=-

if [ -r "$model_registry" ]; then
    model_ledger_digest=$(sha256sum "$model_registry" | cut -d ' ' -f 1)
else
    printf 'model registry is unreadable: %s\n' "$model_registry" >&2
    exit 1
fi

# resolve-active-deployment.sh prints active_deployment_manifest as
# bundle-manifest.tsv, the bundle's own binding manifest; the candidate series
# row this field needs lives in the artifact manifest build-llama-preset.sh
# writes, which the bundle carries as artifact-manifest.tsv beside it.
artifact_manifest=$active_directory/artifact-manifest.tsv
if [ ! -r "$artifact_manifest" ]; then
    printf 'artifact manifest is unreadable: %s\n' "$artifact_manifest" >&2
    exit 1
fi
# The candidate series row is the identity a served reply's prefix-checkpoint
# behavior depends on: patches/llama-server-prefix-checkpoint.patch reaches no
# production build, so an ordinary bundle reads `-` here and the field states
# that absence as a fact about this deployment rather than as a missing row.
candidate_series=$(read_manifest_row candidate_series "$artifact_manifest")
candidate_series_sha256=$(read_manifest_row candidate_series_sha256 "$artifact_manifest")
candidate_series=${candidate_series:--}
candidate_series_sha256=${candidate_series_sha256:--}
tool_prefix_identity=$candidate_series:$candidate_series_sha256

# The boundary line is the one the running session recorded when it armed the
# LAN exposure, read verbatim rather than re-derived, so the receipt states
# what the session actually decided rather than what its inputs would imply.
# A stopped or absent session carries no such line, and the receipt records
# that absence rather than refusing: a receipt is written after teardown too,
# to bind the identity of a bundle a peer is no longer serving.
session_status=$state_directory/session.status
open_lan_policy_identity=no-running-session
open_lan_policy_source=-
if [ -r "$session_status" ]; then
    boundary_line=$(grep '^state=running' "$session_status" | tail -n 1 || true)
    if [ -n "$boundary_line" ]; then
        open_lan_policy_identity=$(printf '%s\n' "$boundary_line" |
            sed -n 's/.*\( lan_exposure=.*\)$/\1/p')
        open_lan_policy_identity=${open_lan_policy_identity# }
        if [ -z "$open_lan_policy_identity" ]; then
            open_lan_policy_identity=no-lan-fields
        fi
        open_lan_policy_source=$session_status
    fi
fi

staging_output=$(mktemp)
trap 'rm -f "$staging_output"' EXIT HUP INT TERM
{
    printf '# field\tvalue\tsource_path\n'
    printf 'main_commit\t%s\t%s\n' "$main_commit" "$runtime_tree_manifest"
    printf 'runtime_tree_digest\t%s\t%s\n' "$runtime_tree_digest" "$runtime_tree_manifest"
    printf 'patch_tree_digest\t%s\t%s\n' "$patch_tree_digest" "$runtime_tree_manifest"
    printf 'server_digest\t%s\t%s\n' "$server_digest" "$bundle_manifest"
    printf 'bundle_digest\t%s\t%s\n' "$bundle_digest" "$bundle_manifest"
    printf 'router_preset_digest\t%s\t%s\n' "$router_preset_digest" "$router_preset_source"
    printf 'web_preset_digest\t%s\t%s\n' "$web_preset_digest" "$web_preset_source"
    printf 'model_ledger_digest\t%s\t%s\n' "$model_ledger_digest" "$model_registry"
    printf 'checkpoint_ledger_digest\t%s\t%s\n' "$checkpoint_ledger_digest" \
        "$active_directory/ctx-checkpoints.tsv"
    printf 'tool_prefix_identity\t%s\t%s\n' "$tool_prefix_identity" "$artifact_manifest"
    printf 'open_lan_policy_identity\t%s\t%s\n' "$open_lan_policy_identity" \
        "$open_lan_policy_source"
} >"$staging_output"
receipt_sha256=$(sha256sum "$staging_output" | cut -d ' ' -f 1)

output_staging=$output_tsv.staging.$$
cp "$staging_output" "$output_staging"
printf 'receipt_sha256\t%s\t%s\n' "$receipt_sha256" "$output_tsv" >>"$output_staging"
mv "$output_staging" "$output_tsv"

printf 'deployment_receipt=%s bundle=%s main_commit=%s receipt_sha256=%s\n' \
    "$output_tsv" "$active_directory" "$main_commit" "$receipt_sha256"
