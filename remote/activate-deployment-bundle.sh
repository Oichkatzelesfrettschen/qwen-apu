#!/bin/sh
set -eu

# Activation makes one verified bundle the deployment the launch chain reads
# and keeps the displaced deployment reachable as deployment-previous, so
# promotion and rollback are the same transition run in opposite directions.
# The current/previous pair lives inside a generation directory published by
# one symlink rename of `deployment-state`, so the pair changes together: an
# interruption leaves the reader on the old complete generation or the new
# complete generation, never on a current that lost its rollback pointer.
# The root names `deployment-current` and `deployment-previous` are stable
# aliases into `deployment-state/` that later activations leave untouched.
#
# usage: activate-deployment-bundle.sh BUNDLE_NAME [DEPLOYMENT_ROOT]
#        activate-deployment-bundle.sh rollback [DEPLOYMENT_ROOT]

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
    printf 'usage: %s BUNDLE_NAME|rollback [DEPLOYMENT_ROOT]\n' "$0" >&2
    exit 2
fi

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
selector=$1
deployment_root=${2:-"${HOME:?}/qwen-deployments"}
state_link=$deployment_root/deployment-state
previous_link=$deployment_root/deployment-previous

# Verification reads nothing outside the bundle directory except the model
# registry, and every claim the bundle manifest states is recomputed from the
# members' own bytes: an internal manifest edited to match a tampered member
# still fails on the semantics, ledger, and executable-row recomputation.
verify_bundle() {
    bundle_directory=$1
    bundle_manifest=$bundle_directory/bundle-manifest.tsv
    if [ ! -r "$bundle_manifest" ]; then
        printf 'bundle manifest is unreadable: %s\n' "$bundle_manifest" >&2
        return 1
    fi
    for manifest_key in bundle_name checkpoint_semantics maximum_ledger_count \
        server_bytes llama-server artifact-manifest.tsv ctx-checkpoints.tsv; do
        manifest_key_rows=$(awk -F'\t' -v key="$manifest_key" \
            '$1 == key { count++ } END { print count + 0 }' "$bundle_manifest")
        if [ "$manifest_key_rows" -ne 1 ]; then
            printf 'bundle manifest carries %s rows for %s; exactly one is required: %s\n' \
                "$manifest_key_rows" "$manifest_key" "$bundle_manifest" >&2
            return 1
        fi
    done
    for bundle_member in llama-server artifact-manifest.tsv ctx-checkpoints.tsv; do
        expected_sha256=$(awk -F'\t' -v key="$bundle_member" \
            '$1 == key { print $2; exit }' "$bundle_manifest")
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
    # The semantics are recomputed from the artifact manifest and the server's
    # own bytes, and the bundle manifest must agree with what was recomputed.
    measured_bytes=$(wc -c <"$bundle_directory/llama-server" | tr -d ' ')
    measured_sha256=$(sha256sum "$bundle_directory/llama-server" |
        cut -d ' ' -f 1)
    declared_bytes=$(awk -F'\t' '$1 == "server_bytes" { print $2; exit }' \
        "$bundle_manifest")
    if [ "$measured_bytes" != "$declared_bytes" ]; then
        printf 'bundle server measures %s bytes against the declared %s\n' \
            "$measured_bytes" "$declared_bytes" >&2
        return 1
    fi
    executable_rows=$(awk -F'\t' -v bytes="$measured_bytes" \
        -v digest="$measured_sha256" '
        $1 == "executable" && $2 == "llama-server" && NF == 4 &&
            $3 == bytes && $4 == digest { count++ }
        END { print count + 0 }' "$bundle_directory/artifact-manifest.tsv")
    if [ "$executable_rows" -ne 1 ]; then
        printf 'artifact manifest holds %s executable llama-server rows matching the bundled server; exactly one is required\n' \
            "$executable_rows" >&2
        return 1
    fi
    recomputed_semantics=$(awk -F'\t' \
        '$1 == "checkpoint_semantics" { count++; value = $2 }
        END { if (count != 1) exit 1; print value }' \
        "$bundle_directory/artifact-manifest.tsv") || {
        printf 'artifact manifest must carry exactly one checkpoint_semantics row\n' >&2
        return 1
    }
    declared_semantics=$(awk -F'\t' \
        '$1 == "checkpoint_semantics" { print $2; exit }' "$bundle_manifest")
    if [ "$recomputed_semantics" != "$declared_semantics" ]; then
        printf 'artifact manifest declares checkpoint_semantics %s against the bundle manifest declaration %s\n' \
            "$recomputed_semantics" "$declared_semantics" >&2
        return 1
    fi
    # The ledger is revalidated through the registry validator, and the
    # maximum count is recomputed from the validated rows.
    validated_ledger_rows=$(QWEN_CTX_CHECKPOINT_LEDGER=$bundle_directory/ctx-checkpoints.tsv \
        "$script_directory/model-registry.sh" ctx-checkpoints) || {
        printf 'bundle ledger failed registry validation: %s\n' \
            "$bundle_directory/ctx-checkpoints.tsv" >&2
        return 1
    }
    recomputed_maximum=$(printf '%s\n' "$validated_ledger_rows" | awk -F'\t' '
        { if ($2 + 0 > maximum) maximum = $2 + 0 }
        END { print maximum + 0 }')
    declared_maximum=$(awk -F'\t' \
        '$1 == "maximum_ledger_count" { print $2; exit }' "$bundle_manifest")
    if [ "$recomputed_maximum" != "$declared_maximum" ]; then
        printf 'bundle ledger maximum count %s disagrees with the declared %s\n' \
            "$recomputed_maximum" "$declared_maximum" >&2
        return 1
    fi
    if [ "$recomputed_maximum" -gt 0 ] && \
        [ "$recomputed_semantics" != natural-boundary-v1 ]; then
        printf 'bundle pairs a positive checkpoint count with %s; a positive count requires natural-boundary-v1\n' \
            "$recomputed_semantics" >&2
        return 1
    fi
    return 0
}

# The bundle a role name resolves to, through either the generation directory
# or a legacy plain link a prior activator version left at the root.
resolve_role() {
    role=$1
    if [ -L "$state_link" ] && [ -L "$state_link/$role" ]; then
        role_target=$(readlink "$state_link/$role")
        printf '%s\n' "${role_target#../}"
        return 0
    fi
    if [ -L "$deployment_root/deployment-$role" ]; then
        role_target=$(readlink "$deployment_root/deployment-$role")
        case $role_target in
            deployment-state/*) ;;
            *) printf '%s\n' "$role_target" ;;
        esac
    fi
    return 0
}

# One rename of the deployment-state link publishes the whole current/previous
# pair; the displaced generation directory is removed after the publish.
publish_state() {
    publish_current=$1
    publish_previous=$2
    generation=1
    while [ -e "$deployment_root/deployment-state.$generation" ]; do
        generation=$((generation + 1))
    done
    generation_directory=$deployment_root/deployment-state.$generation
    mkdir "$generation_directory"
    ln -s "../$publish_current" "$generation_directory/current"
    if [ -n "$publish_previous" ]; then
        ln -s "../$publish_previous" "$generation_directory/previous"
    fi
    displaced_state=''
    if [ -L "$state_link" ]; then
        displaced_state=$(readlink "$state_link")
    fi
    ln -sfn "deployment-state.$generation" "$deployment_root/.deployment-state.new"
    mv -T "$deployment_root/.deployment-state.new" "$state_link"
    # The root aliases point into the generation indirection once and stay
    # put; repointing happens only when a legacy plain link is migrated.
    for role in current previous; do
        role_link=$deployment_root/deployment-$role
        if [ "$(readlink "$role_link" 2>/dev/null || :)" != \
            "deployment-state/$role" ]; then
            ln -sfn "deployment-state/$role" "$deployment_root/.deployment-$role.new"
            mv -T "$deployment_root/.deployment-$role.new" "$role_link"
        fi
    done
    case $displaced_state in
        deployment-state.[0-9]*)
            rm -rf -- "${deployment_root:?}/$displaced_state"
            ;;
    esac
}

if [ "$selector" = rollback ]; then
    rollback_target=$(resolve_role previous)
    if [ -z "$rollback_target" ]; then
        printf 'no deployment-previous to roll back to: %s\n' "$previous_link" >&2
        exit 1
    fi
    current_target=$(resolve_role current)
    if ! verify_bundle "$deployment_root/$rollback_target"; then
        printf 'rollback target failed verification and stays inactive\n' >&2
        exit 1
    fi
    publish_state "$rollback_target" "$current_target"
    printf 'deployment_current=%s deployment_previous=%s transition=rollback\n' \
        "$rollback_target" "$current_target"
    exit 0
fi

case $selector in
    *[!A-Za-z0-9._-]* | '' | deployment-current | deployment-previous | \
        deployment-state | deployment-state.*)
        printf 'bundle name must be nonempty [A-Za-z0-9._-] and not a link name: %s\n' \
            "$selector" >&2
        exit 2
        ;;
esac
if ! verify_bundle "$deployment_root/$selector"; then
    printf 'bundle failed verification and stays inactive: %s\n' "$selector" >&2
    exit 1
fi
displaced=$(resolve_role current)
if [ "$displaced" = "$selector" ]; then
    printf 'bundle is already deployment-current: %s\n' "$selector"
    exit 0
fi
publish_state "$selector" "$displaced"
printf 'deployment_current=%s deployment_previous=%s transition=activate\n' \
    "$selector" "${displaced:--}"
