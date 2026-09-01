#!/bin/sh
set -eu

# The deployment bundle over fixtures: assembly binds server, manifest, and
# ledger with digests and refuses the pairing the capacity policy would
# refuse at launch; activation re-verifies every member and the semantics
# rule from the bundle's own bytes, swaps deployment-current in one rename,
# and rollback is the same transition run backward.

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
work_directory=$(mktemp -d)
trap 'rm -rf "$work_directory"' EXIT HUP INT TERM

builder=$script_directory/build-deployment-bundle.sh
activator=$script_directory/activate-deployment-bundle.sh
deployment_root=$work_directory/deployments
mkdir -p "$deployment_root"
checks=0
report() {
    checks=$((checks + 1))
    printf 'check_%02d %s=%s\n' "$checks" "$1" "$2"
}

# Fixture inputs: a natural-boundary server, a forced-tail server, a
# positive-count ledger, and a zero-count ledger.
natural_server=$work_directory/server-natural
printf '#!/bin/sh\nexit 0\n' >"$natural_server"
chmod 755 "$natural_server"
forced_server=$work_directory/server-forced
printf '#!/bin/sh\nexit 1\n' >"$forced_server"
chmod 755 "$forced_server"
natural_manifest=$work_directory/manifest-natural.tsv
{
    printf 'checkpoint_semantics\tnatural-boundary-v1\n'
    printf 'bin/llama-server\t%s\n' \
        "$(sha256sum "$natural_server" | cut -d ' ' -f 1)"
} >"$natural_manifest"
forced_manifest=$work_directory/manifest-forced.tsv
{
    printf 'checkpoint_semantics\tforced-tail-v1\n'
    printf 'bin/llama-server\t%s\n' \
        "$(sha256sum "$forced_server" | cut -d ' ' -f 1)"
} >"$forced_manifest"
positive_ledger=$work_directory/ledger-positive.tsv
printf 'model_id\tctx_checkpoints\tevidence\nqwen-2b\t2\tevidence/run\n' \
    >"$positive_ledger"
zero_ledger=$work_directory/ledger-zero.tsv
printf 'model_id\tctx_checkpoints\tevidence\nqwen-2b\t0\t-\n' >"$zero_ledger"

if "$builder" bundle-natural "$natural_server" "$natural_manifest" \
    "$positive_ledger" "$deployment_root" >/dev/null; then
    report natural_bundle_assembled accepted
else
    printf 'the natural-boundary bundle failed to assemble\n' >&2
    exit 1
fi
for bundle_member in llama-server artifact-manifest.tsv ctx-checkpoints.tsv \
    bundle-manifest.tsv; do
    if [ ! -r "$deployment_root/bundle-natural/$bundle_member" ]; then
        printf 'assembled bundle lacks %s\n' "$bundle_member" >&2
        exit 1
    fi
done
report bundle_members_present accepted

if "$builder" bundle-natural "$natural_server" "$natural_manifest" \
    "$positive_ledger" "$deployment_root" >/dev/null 2>&1; then
    printf 'a duplicate bundle name escaped refusal\n' >&2
    exit 1
fi
report duplicate_name_refused accepted

# The pairing a launch would refuse is refused at assembly: a positive count
# against forced-tail semantics.
if "$builder" bundle-bad-pair "$forced_server" "$forced_manifest" \
    "$positive_ledger" "$deployment_root" \
    >/dev/null 2>"$work_directory/pair.stderr"; then
    printf 'a positive count paired with forced-tail escaped assembly\n' >&2
    exit 1
fi
if ! grep -q 'requires natural-boundary-v1' "$work_directory/pair.stderr"; then
    printf 'the pairing refusal lost its reason\n' >&2
    exit 1
fi
report forced_positive_pair_refused accepted

# The emergency shape assembles: forced-tail server with the all-zero ledger.
if "$builder" bundle-emergency "$forced_server" "$forced_manifest" \
    "$zero_ledger" "$deployment_root" >/dev/null; then
    report emergency_bundle_assembled accepted
else
    printf 'the emergency forced-tail bundle failed to assemble\n' >&2
    exit 1
fi

# A manifest describing another binary fails assembly.
if "$builder" bundle-foreign "$natural_server" "$forced_manifest" \
    "$zero_ledger" "$deployment_root" >/dev/null 2>&1; then
    printf 'a manifest for another binary escaped assembly\n' >&2
    exit 1
fi
report foreign_manifest_refused accepted

if "$activator" bundle-natural "$deployment_root" | \
    grep -q 'transition=activate'; then
    report first_activation accepted
else
    printf 'first activation failed\n' >&2
    exit 1
fi
if [ "$(readlink "$deployment_root/deployment-current")" != bundle-natural ]; then
    printf 'deployment-current does not name the activated bundle\n' >&2
    exit 1
fi
report current_links_activated accepted

"$activator" bundle-emergency "$deployment_root" >/dev/null
if [ "$(readlink "$deployment_root/deployment-current")" != bundle-emergency ] || \
    [ "$(readlink "$deployment_root/deployment-previous")" != bundle-natural ]; then
    printf 'the second activation did not displace the first into previous\n' >&2
    exit 1
fi
report second_activation_displaces accepted

"$activator" rollback "$deployment_root" >/dev/null
if [ "$(readlink "$deployment_root/deployment-current")" != bundle-natural ] || \
    [ "$(readlink "$deployment_root/deployment-previous")" != bundle-emergency ]; then
    printf 'rollback did not swap current and previous\n' >&2
    exit 1
fi
report rollback_swaps accepted

# A diverged member stays inactive, and the links stay where they were.
printf 'tampered\n' >>"$deployment_root/bundle-emergency/llama-server"
if "$activator" bundle-emergency "$deployment_root" \
    >/dev/null 2>"$work_directory/diverged.stderr"; then
    printf 'a diverged bundle member escaped refusal\n' >&2
    exit 1
fi
if ! grep -q 'bundle member diverged: llama-server' \
    "$work_directory/diverged.stderr"; then
    printf 'the divergence refusal lost the member it names\n' >&2
    exit 1
fi
if [ "$(readlink "$deployment_root/deployment-current")" != bundle-natural ]; then
    printf 'a refused activation moved deployment-current\n' >&2
    exit 1
fi
report diverged_member_refused accepted

# A rollback target is verified the way an activation is.
if "$activator" rollback "$deployment_root" >/dev/null 2>&1; then
    printf 'rollback activated a diverged bundle\n' >&2
    exit 1
fi
report diverged_rollback_refused accepted

# The launch chain reads the activated bundle: the control script prefers
# deployment-current and carries its ledger across the tmux boundary.
if ! grep -q 'deployment_current/llama-server' \
    "$script_directory/qwen-webui-control.sh" || \
    ! grep -q 'deployment_current/ctx-checkpoints.tsv' \
    "$script_directory/qwen-webui-control.sh"; then
    printf 'the control script no longer consults deployment-current\n' >&2
    exit 1
fi
if ! grep -q 'QWEN_VALIDATED_TUPLES QWEN_CTX_CHECKPOINT_LEDGER' \
    "$script_directory/qwen-webui-control.sh"; then
    printf 'the bundle ledger no longer crosses the tmux boundary\n' >&2
    exit 1
fi
report control_consults_deployment accepted

printf 'deployment_bundle=accepted checks=%s\n' "$checks"
