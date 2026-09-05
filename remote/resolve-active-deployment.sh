#!/bin/sh
set -eu

# One resolution of the active deployment for a whole launch. The launch chain
# reads a server, a checkpoint ledger, and a preset from the activated
# bundle, and an activation between two reads of `deployment-current` would
# pair members of two generations. This script takes the activation lock
# shared, follows `deployment-current` to one bundle, requires that bundle to
# sit immediately below the deployment root under a plain name, verifies it
# once, and prints canonical member paths. The caller retains the directory
# in QWEN_ACTIVE_DEPLOYMENT_DIRECTORY and reads every member from it, so a
# later activation replaces the pointer while the launch keeps the bundle it
# resolved. An explicit QWEN_ACTIVE_DEPLOYMENT_DIRECTORY is verified rather
# than trusted: it must be a bundle below the root and passes the same
# verification, so a caller that already resolved once hands the same bundle
# down the chain.
#
# usage: resolve-active-deployment.sh [DEPLOYMENT_ROOT]
# Prints `active_deployment_directory=`, `active_deployment_name=`,
# `active_deployment_server=`, `active_deployment_ledger=`,
# `active_deployment_manifest=`, `active_deployment_router_presets=`, and
# `active_deployment_web_presets=`; an absent preset reads `-`. Exit 3 states
# that the root holds no deployment-current at all, so a caller can keep the
# promote-chain defaults; any other failure is a corrupt or refused bundle.
# Absence is one of the states the lock protects, so a root that admits no
# lock leaf answers with the helper's own refusal rather than with 3: what a
# root holds is unknown until the activation lock says it holds still.

if [ "$#" -gt 1 ]; then
    printf 'usage: %s [DEPLOYMENT_ROOT]\n' "$0" >&2
    exit 2
fi

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
# shellcheck source=remote/qwen-home.sh
. "$script_directory/qwen-home.sh"
# An explicit deployment root is the caller's own claim and is verified as
# one; the derived root belongs to QWEN_HOME, so the marker binding decides
# whether this checkout reads it. A root laid out beside another checkout
# would otherwise serve that checkout's bundles under this tree's scripts.
if [ "$#" -eq 0 ] && [ -z "${QWEN_DEPLOYMENT_ROOT:-}" ]; then
    qwen_home_require_binding || exit 2
fi
deployment_root=${1:-${QWEN_DEPLOYMENT_ROOT:-"$qwen_home_deployments"}}
current_link=$deployment_root/deployment-current

if [ ! -d "$deployment_root" ]; then
    printf 'no deployment root: %s\n' "$deployment_root" >&2
    exit 3
fi
canonical_root=$(readlink -f -- "$deployment_root")

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
flock -s 7

if [ -n "${QWEN_ACTIVE_DEPLOYMENT_DIRECTORY:-}" ]; then
    candidate_directory=$QWEN_ACTIVE_DEPLOYMENT_DIRECTORY
    if [ -L "$candidate_directory" ] || [ ! -d "$candidate_directory" ]; then
        printf 'QWEN_ACTIVE_DEPLOYMENT_DIRECTORY is not a plain directory: %s\n' \
            "$candidate_directory" >&2
        exit 1
    fi
    canonical_directory=$(readlink -f -- "$candidate_directory")
else
    # Absence is decided under the lock, so an activation that publishes
    # deployment-state and its role aliases between the read and the lock
    # cannot leave the launch reporting an empty root it no longer has.
    if [ ! -e "$current_link" ] && [ ! -L "$current_link" ]; then
        printf 'no deployment-current under %s\n' "$deployment_root" >&2
        exit 3
    fi
    if [ ! -L "$current_link" ]; then
        printf 'deployment-current is not a symlink: %s\n' "$current_link" >&2
        exit 1
    fi
    if [ ! -d "$current_link/" ]; then
        printf 'deployment-current does not resolve to a directory: %s\n' \
            "$current_link" >&2
        exit 1
    fi
    canonical_directory=$(readlink -f -- "$current_link")
fi

bundle_name=${canonical_directory##*/}
if [ "${canonical_directory%/*}" != "$canonical_root" ]; then
    printf 'active deployment resolves outside the deployment root: %s\n' \
        "$canonical_directory" >&2
    exit 1
fi
# The resolved basename meets the bundle namespace here as well, so a launch
# refuses a directory carrying one of the root's own names before it hands
# the name to verification.
name_helper=$script_directory/deployment-bundle-name.sh
if [ ! -r "$name_helper" ]; then
    printf 'deployment bundle name helper is unreadable: %s\n' "$name_helper" >&2
    exit 1
fi
# shellcheck source=deployment-bundle-name.sh
. "$name_helper"
if ! deployment_bundle_name_is_valid "$bundle_name"; then
    printf 'active deployment name must match [A-Za-z0-9][A-Za-z0-9._-]* and avoid the root names: %s\n' \
        "$bundle_name" >&2
    exit 1
fi
"$script_directory/verify-deployment-bundle.sh" "$deployment_root" \
    "$bundle_name" >/dev/null

router_presets=-
web_presets=-
if [ -f "$canonical_directory/router-presets.ini" ]; then
    router_presets=$canonical_directory/router-presets.ini
fi
if [ -f "$canonical_directory/web-presets.ini" ]; then
    web_presets=$canonical_directory/web-presets.ini
fi
printf 'active_deployment_directory=%s\n' "$canonical_directory"
printf 'active_deployment_name=%s\n' "$bundle_name"
printf 'active_deployment_server=%s\n' "$canonical_directory/llama-server"
printf 'active_deployment_ledger=%s\n' "$canonical_directory/ctx-checkpoints.tsv"
printf 'active_deployment_manifest=%s\n' "$canonical_directory/bundle-manifest.tsv"
printf 'active_deployment_router_presets=%s\n' "$router_presets"
printf 'active_deployment_web_presets=%s\n' "$web_presets"
