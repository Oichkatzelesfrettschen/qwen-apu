#!/bin/sh
set -eu

# Activation makes one verified bundle the deployment the launch chain reads,
# in one symlink rename, and keeps the displaced deployment reachable as
# deployment-previous, so promotion and rollback are the same atomic
# transition run in opposite directions. `rollback` swaps current and
# previous without naming a bundle.
#
# usage: activate-deployment-bundle.sh BUNDLE_NAME [DEPLOYMENT_ROOT]
#        activate-deployment-bundle.sh rollback [DEPLOYMENT_ROOT]

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
    printf 'usage: %s BUNDLE_NAME|rollback [DEPLOYMENT_ROOT]\n' "$0" >&2
    exit 2
fi

selector=$1
deployment_root=${2:-"${HOME:?}/qwen-deployments"}
current_link=$deployment_root/deployment-current
previous_link=$deployment_root/deployment-previous

verify_bundle() {
    bundle_directory=$1
    bundle_manifest=$bundle_directory/bundle-manifest.tsv
    if [ ! -r "$bundle_manifest" ]; then
        printf 'bundle manifest is unreadable: %s\n' "$bundle_manifest" >&2
        return 1
    fi
    for bundle_member in llama-server artifact-manifest.tsv ctx-checkpoints.tsv; do
        expected_sha256=$(awk -F'\t' -v key="$bundle_member" \
            '$1 == key { print $2; exit }' "$bundle_manifest")
        if [ -z "$expected_sha256" ]; then
            printf 'bundle manifest names no digest for %s: %s\n' \
                "$bundle_member" "$bundle_manifest" >&2
            return 1
        fi
        if [ ! -r "$bundle_directory/$bundle_member" ]; then
            printf 'bundle member is unreadable: %s\n' \
                "$bundle_directory/$bundle_member" >&2
            return 1
        fi
        actual_sha256=$(sha256sum "$bundle_directory/$bundle_member" |
            cut -d ' ' -f 1)
        if [ "$actual_sha256" != "$expected_sha256" ]; then
            printf 'bundle member diverged: %s expected=%s found=%s\n' \
                "$bundle_member" "$expected_sha256" "$actual_sha256" >&2
            return 1
        fi
    done
    if [ ! -x "$bundle_directory/llama-server" ]; then
        printf 'bundle server is not executable: %s\n' \
            "$bundle_directory/llama-server" >&2
        return 1
    fi
    # The semantics rule is re-proven from the bundle's own bytes at every
    # activation, because a manifest edited after assembly would otherwise
    # activate a pairing the assembly refused.
    bundle_semantics=$(awk -F'\t' '$1 == "checkpoint_semantics" { print $2; exit }' \
        "$bundle_manifest")
    bundle_maximum_count=$(awk -F'\t' '/^#/ || NF == 0 { next }
        $1 == "model_id" { next }
        { if ($2 + 0 > maximum) maximum = $2 + 0 }
        END { print maximum + 0 }' "$bundle_directory/ctx-checkpoints.tsv")
    if [ "$bundle_maximum_count" -gt 0 ] && \
        [ "$bundle_semantics" != natural-boundary-v1 ]; then
        printf 'bundle pairs a positive checkpoint count with %s; a positive count requires natural-boundary-v1\n' \
            "$bundle_semantics" >&2
        return 1
    fi
    return 0
}

swap_links() {
    new_target=$1
    displaced_target=$2
    # ln -sfn onto a temporary name plus mv is the atomic transition: readers
    # resolve either the old deployment or the new one, never a missing link.
    if [ -n "$displaced_target" ]; then
        ln -sfn "$displaced_target" "$deployment_root/.deployment-previous.new"
        mv -T "$deployment_root/.deployment-previous.new" "$previous_link"
    fi
    ln -sfn "$new_target" "$deployment_root/.deployment-current.new"
    mv -T "$deployment_root/.deployment-current.new" "$current_link"
}

if [ "$selector" = rollback ]; then
    if [ ! -L "$previous_link" ]; then
        printf 'no deployment-previous to roll back to: %s\n' "$previous_link" >&2
        exit 1
    fi
    rollback_target=$(readlink "$previous_link")
    current_target=''
    if [ -L "$current_link" ]; then
        current_target=$(readlink "$current_link")
    fi
    if ! verify_bundle "$deployment_root/$rollback_target"; then
        printf 'rollback target failed verification and stays inactive\n' >&2
        exit 1
    fi
    swap_links "$rollback_target" "$current_target"
    printf 'deployment_current=%s deployment_previous=%s transition=rollback\n' \
        "$rollback_target" "$current_target"
    exit 0
fi

case $selector in
    *[!A-Za-z0-9._-]* | '' | deployment-current | deployment-previous)
        printf 'bundle name must be nonempty [A-Za-z0-9._-] and not a link name: %s\n' \
            "$selector" >&2
        exit 2
        ;;
esac
if ! verify_bundle "$deployment_root/$selector"; then
    printf 'bundle failed verification and stays inactive: %s\n' "$selector" >&2
    exit 1
fi
displaced=''
if [ -L "$current_link" ]; then
    displaced=$(readlink "$current_link")
fi
if [ "$displaced" = "$selector" ]; then
    printf 'bundle is already deployment-current: %s\n' "$selector"
    exit 0
fi
swap_links "$selector" "$displaced"
printf 'deployment_current=%s deployment_previous=%s transition=activate\n' \
    "$selector" "${displaced:--}"
