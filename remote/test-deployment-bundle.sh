#!/bin/sh
set -eu

# The deployment bundle over fixtures: assembly binds server, manifest, and
# ledger with digests, reads the ledger through the registry validator, and
# refuses the pairing the capacity policy would refuse at launch; activation
# recomputes every bundle-manifest claim from the members' own bytes and
# publishes the current/previous pair in one rename of deployment-state, so
# rollback is the same transition run backward and an interruption never
# leaves a current without its rollback pointer.

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

# The registry validator requires ledger model ids to exist in the model
# registry, so the fixture carries its own one-row registry.
QWEN_MODEL_REGISTRY=$work_directory/models.tsv
export QWEN_MODEL_REGISTRY
printf 'model_id\tmodel_file\nqwen-2b\tqwen-2b.gguf\n' >"$QWEN_MODEL_REGISTRY"

resolved_bundle() {
    basename "$(readlink -f "$deployment_root/deployment-$1")"
}

# Fixture inputs: a natural-boundary server, a forced-tail server, a
# positive-count ledger, and a zero-count ledger. Each artifact manifest
# carries the exec guard's executable row shape for its own server.
write_manifest() {
    manifest_semantics=$1
    manifest_server=$2
    manifest_output=$3
    {
        printf 'checkpoint_semantics\t%s\n' "$manifest_semantics"
        printf 'executable\tllama-server\t%s\t%s\n' \
            "$(wc -c <"$manifest_server" | tr -d ' ')" \
            "$(sha256sum "$manifest_server" | cut -d ' ' -f 1)"
    } >"$manifest_output"
}
natural_server=$work_directory/server-natural
printf '#!/bin/sh\nexit 0\n' >"$natural_server"
chmod 755 "$natural_server"
forced_server=$work_directory/server-forced
printf '#!/bin/sh\nexit 1\n' >"$forced_server"
chmod 755 "$forced_server"
natural_manifest=$work_directory/manifest-natural.tsv
write_manifest natural-boundary-v1 "$natural_server" "$natural_manifest"
forced_manifest=$work_directory/manifest-forced.tsv
write_manifest forced-tail-v1 "$forced_server" "$forced_manifest"
positive_ledger=$work_directory/ledger-positive.tsv
printf 'qwen-2b\t2\tevidence/run\n' >"$positive_ledger"
zero_ledger=$work_directory/ledger-zero.tsv
printf 'qwen-2b\t0\t-\n' >"$zero_ledger"

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

# A malformed ledger row contributes an error rather than a zero maximum: a
# spelled-out count fails the registry validator at assembly.
malformed_ledger=$work_directory/ledger-malformed.tsv
printf 'qwen-2b\ttwo\tevidence/run\n' >"$malformed_ledger"
if "$builder" bundle-malformed "$forced_server" "$forced_manifest" \
    "$malformed_ledger" "$deployment_root" \
    >/dev/null 2>"$work_directory/malformed.stderr"; then
    printf 'a malformed ledger count escaped assembly\n' >&2
    exit 1
fi
if ! grep -q 'failed registry validation' "$work_directory/malformed.stderr"; then
    printf 'the malformed ledger refusal lost its reason\n' >&2
    exit 1
fi
report malformed_ledger_refused accepted

# The emergency shape assembles: forced-tail server with the all-zero ledger.
if "$builder" bundle-emergency "$forced_server" "$forced_manifest" \
    "$zero_ledger" "$deployment_root" >/dev/null; then
    report emergency_bundle_assembled accepted
else
    printf 'the emergency forced-tail bundle failed to assemble\n' >&2
    exit 1
fi

# A manifest describing another binary fails assembly on the executable row.
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
if [ "$(resolved_bundle current)" != bundle-natural ]; then
    printf 'deployment-current does not resolve to the activated bundle\n' >&2
    exit 1
fi
if [ ! -L "$deployment_root/deployment-state" ]; then
    printf 'activation published no deployment-state generation link\n' >&2
    exit 1
fi
report current_links_activated accepted

"$activator" bundle-emergency "$deployment_root" >/dev/null
if [ "$(resolved_bundle current)" != bundle-emergency ] || \
    [ "$(resolved_bundle previous)" != bundle-natural ]; then
    printf 'the second activation did not displace the first into previous\n' >&2
    exit 1
fi
report second_activation_displaces accepted

# The pair changes through one generation link, so exactly one generation
# directory remains after a completed activation.
generation_count=$(find "$deployment_root" -maxdepth 1 \
    -name 'deployment-state.*' -type d | wc -l | tr -d ' ')
if [ "$generation_count" -ne 1 ]; then
    printf 'activation retained %s generation directories, expected one\n' \
        "$generation_count" >&2
    exit 1
fi
report single_generation_retained accepted

"$activator" rollback "$deployment_root" >/dev/null
if [ "$(resolved_bundle current)" != bundle-natural ] || \
    [ "$(resolved_bundle previous)" != bundle-emergency ]; then
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
if [ "$(resolved_bundle current)" != bundle-natural ]; then
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

# A writer who edits a member and updates the internal digests to match still
# fails, because the semantics rule is recomputed from the artifact manifest
# rather than trusted from the bundle manifest: rewriting the natural bundle's
# artifact manifest to forced-tail-v1 with a consistent internal digest is
# refused against its positive-count ledger.
consistent_tamper=$deployment_root/bundle-natural
write_manifest forced-tail-v1 "$consistent_tamper/llama-server" \
    "$consistent_tamper/artifact-manifest.tsv"
tampered_digest=$(sha256sum "$consistent_tamper/artifact-manifest.tsv" |
    cut -d ' ' -f 1)
awk -F'\t' -v OFS='\t' -v digest="$tampered_digest" -v semantics=forced-tail-v1 '
    $1 == "artifact-manifest.tsv" { $2 = digest }
    $1 == "checkpoint_semantics" { $2 = semantics }
    { print }' "$consistent_tamper/bundle-manifest.tsv" \
    >"$consistent_tamper/bundle-manifest.tsv.new"
mv "$consistent_tamper/bundle-manifest.tsv.new" \
    "$consistent_tamper/bundle-manifest.tsv"
if "$activator" bundle-natural "$deployment_root" \
    >/dev/null 2>"$work_directory/consistent.stderr"; then
    printf 'an internally consistent semantics rewrite escaped activation\n' >&2
    exit 1
fi
if ! grep -q 'requires natural-boundary-v1' "$work_directory/consistent.stderr"; then
    printf 'the consistent-tamper refusal lost its reason\n' >&2
    exit 1
fi
report consistent_tamper_refused accepted

# The launch chain reads the activated bundle: the control script prefers
# deployment-current, refuses a present-but-broken deployment before tmux,
# and carries the bundle ledger across the tmux boundary.
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
if ! grep -q 'deployment-current exists but its llama-server is not executable' \
    "$script_directory/qwen-webui-control.sh"; then
    printf 'the control script fell back silently on a broken deployment\n' >&2
    exit 1
fi
report control_consults_deployment accepted

printf 'deployment_bundle=accepted checks=%s\n' "$checks"
