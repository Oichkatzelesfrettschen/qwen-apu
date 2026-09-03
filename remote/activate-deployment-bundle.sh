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
# Activations serialize on `.activate.lock` under the root, because the
# transition reads the displaced current, allocates a generation number, and
# publishes in three steps: two writers that both read the same current
# publish the same previous, so the rollback pointer loses the intermediate
# activation, and the generation each removes is the one it read rather than
# the one the other published, so orphan generation directories accumulate.
# The lock is a descriptor this process holds exclusively until it exits, so
# ownership is a kernel fact rather than an inherited environment string, and
# resolve-active-deployment.sh takes the same lock shared while it reads.
#
# Every name the transition reads back from the root is held to its own
# namespace: a role link targets exactly `../BUNDLE_NAME`, a generation link
# targets exactly `deployment-state.N`, and only such a validated basename is
# ever removed. A root whose links name anything else is refused whole.
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

if [ ! -d "$deployment_root" ]; then
    printf 'deployment root is not a directory: %s\n' "$deployment_root" >&2
    exit 1
fi
# The lock leaf is opened through open-verified-lock-descriptor.py, which
# refuses a symlink, a directory, a foreign owner, and a loose mode, opens
# without truncation, and carries descriptor 7 across one exec. The
# inheritance marker selects the verify branch and authorizes nothing by
# itself: the helper re-verifies that descriptor 7 is that leaf.
lock_path=$deployment_root/.activate.lock
lock_helper=$script_directory/open-verified-lock-descriptor.py
case ${QWEN_ACTIVATION_LOCK_DESCRIPTOR_INHERITED:-0} in
    0)
        QWEN_ACTIVATION_LOCK_DESCRIPTOR_INHERITED=1
        export QWEN_ACTIVATION_LOCK_DESCRIPTOR_INHERITED
        exec "$lock_helper" open --normalize-legacy-mode "$lock_path" 7 "$0" "$@"
        ;;
    1)
        "$lock_helper" verify "$lock_path" 7
        ;;
    *)
        printf 'invalid activation-lock inheritance marker: %s\n' \
            "$QWEN_ACTIVATION_LOCK_DESCRIPTOR_INHERITED" >&2
        exit 2
        ;;
esac
flock -x 7

verify_bundle() {
    "$script_directory/verify-deployment-bundle.sh" "$deployment_root" "$1" \
        >/dev/null
}

name_helper=$script_directory/deployment-bundle-name.sh
if [ ! -r "$name_helper" ]; then
    printf 'deployment bundle name helper is unreadable: %s\n' "$name_helper" >&2
    exit 1
fi
# shellcheck source=deployment-bundle-name.sh
. "$name_helper"

# The bundle name a role resolves to, through either the generation directory
# or a legacy plain link a prior activator version left at the root. A role
# link inside a generation targets exactly `../NAME`; a legacy plain link
# targets exactly `NAME`. Any other target refuses the transition, because a
# link pointing outside the root would otherwise name the bundle a rollback
# activates or the generation a publish removes.
resolve_role() {
    role=$1
    if [ -L "$state_link" ] && [ -L "$state_link/$role" ]; then
        role_target=$(readlink "$state_link/$role")
        case $role_target in
            ../*) role_name=${role_target#../} ;;
            *) role_name='' ;;
        esac
        if ! deployment_bundle_name_is_valid "$role_name"; then
            printf 'role link %s targets %s; exactly ../BUNDLE_NAME is admitted\n' \
                "$state_link/$role" "$role_target" >&2
            return 1
        fi
        printf '%s\n' "$role_name"
        return 0
    fi
    if [ -L "$deployment_root/deployment-$role" ]; then
        role_target=$(readlink "$deployment_root/deployment-$role")
        case $role_target in
            deployment-state/current | deployment-state/previous)
                return 0
                ;;
        esac
        if ! deployment_bundle_name_is_valid "$role_target"; then
            printf 'legacy role link %s targets %s; exactly BUNDLE_NAME is admitted\n' \
                "$deployment_root/deployment-$role" "$role_target" >&2
            return 1
        fi
        printf '%s\n' "$role_target"
    fi
    return 0
}

# The generation name the state link targets, held to `deployment-state.N`.
resolve_state_generation() {
    if [ ! -L "$state_link" ]; then
        return 0
    fi
    state_target=$(readlink "$state_link")
    if ! printf '%s\n' "$state_target" | grep -qxE 'deployment-state\.[0-9]+'; then
        printf 'state link %s targets %s; exactly deployment-state.N is admitted\n' \
            "$state_link" "$state_target" >&2
        return 1
    fi
    printf '%s\n' "$state_target"
}

# One rename of the deployment-state link publishes the whole current/previous
# pair; the displaced generation directory is removed after the publish, and
# only a validated generation basename that is a plain directory is removed.
publish_state() {
    publish_current=$1
    publish_previous=$2
    displaced_state=$(resolve_state_generation)
    generation=1
    while [ -e "$deployment_root/deployment-state.$generation" ] || \
        [ -L "$deployment_root/deployment-state.$generation" ]; do
        generation=$((generation + 1))
    done
    generation_directory=$deployment_root/deployment-state.$generation
    mkdir "$generation_directory"
    ln -s "../$publish_current" "$generation_directory/current"
    if [ -n "$publish_previous" ]; then
        ln -s "../$publish_previous" "$generation_directory/previous"
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
    if [ -n "$displaced_state" ] && \
        [ -d "$deployment_root/$displaced_state" ] && \
        [ ! -L "$deployment_root/$displaced_state" ]; then
        rm -rf -- "${deployment_root:?}/$displaced_state"
    fi
}

# The root's own links are read before any bundle is verified, so a corrupt
# state or role link refuses the transition ahead of the publish.
resolve_state_generation >/dev/null
current_target=$(resolve_role current)

if [ "$selector" = rollback ]; then
    rollback_target=$(resolve_role previous)
    if [ -z "$rollback_target" ]; then
        printf 'no deployment-previous to roll back to: %s\n' "$previous_link" >&2
        exit 1
    fi
    if ! verify_bundle "$rollback_target"; then
        printf 'rollback target failed verification and stays inactive\n' >&2
        exit 1
    fi
    publish_state "$rollback_target" "$current_target"
    printf 'deployment_current=%s deployment_previous=%s transition=rollback\n' \
        "$rollback_target" "$current_target"
    exit 0
fi

if ! deployment_bundle_name_is_valid "$selector"; then
    printf 'bundle name must match [A-Za-z0-9][A-Za-z0-9._-]* and avoid the root names: %s\n' \
        "$selector" >&2
    exit 2
fi
if ! verify_bundle "$selector"; then
    printf 'bundle failed verification and stays inactive: %s\n' "$selector" >&2
    exit 1
fi
if [ "$current_target" = "$selector" ]; then
    printf 'bundle is already deployment-current: %s\n' "$selector"
    exit 0
fi
publish_state "$selector" "$current_target"
printf 'deployment_current=%s deployment_previous=%s transition=activate\n' \
    "$selector" "${current_target:--}"
