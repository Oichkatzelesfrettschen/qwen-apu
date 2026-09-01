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

# Preset fixtures carry the section key the launch policy reads, generated
# against one ledger each; the mismatched one names a count its ledger never
# stated.
write_preset() {
    printf '# fixture preset\n[qwen-2b]\nLLAMA_ARG_MODEL = qwen-2b.gguf\nLLAMA_ARG_CTX_CHECKPOINTS = %s\n[qwen-2b+draft]\nLLAMA_ARG_CTX_CHECKPOINTS = %s\n' \
        "$1" "$1" >"$2"
}
positive_preset=$work_directory/router-presets-positive.ini
write_preset 2 "$positive_preset"
zero_preset=$work_directory/router-presets-zero.ini
write_preset 0 "$zero_preset"
web_preset=$work_directory/web-presets.ini
printf '[web-profile]\nLLAMA_ARG_CTX_CHECKPOINTS = 2\n' >"$web_preset"

if QWEN_BUNDLE_ROUTER_PRESETS=$positive_preset \
    QWEN_BUNDLE_WEB_PRESETS=$web_preset \
    "$builder" bundle-natural "$natural_server" "$natural_manifest" \
    "$positive_ledger" "$deployment_root" >/dev/null; then
    report natural_bundle_assembled accepted
else
    printf 'the natural-boundary bundle failed to assemble\n' >&2
    exit 1
fi
for bundle_member in llama-server artifact-manifest.tsv ctx-checkpoints.tsv \
    bundle-manifest.tsv router-presets.ini web-presets.ini; do
    if [ ! -r "$deployment_root/bundle-natural/$bundle_member" ]; then
        printf 'assembled bundle lacks %s\n' "$bundle_member" >&2
        exit 1
    fi
done
for preset_row in router-presets.ini web-presets.ini; do
    if ! awk -F'\t' -v key="$preset_row" '$1 == key && $2 ~ /^[0-9a-f]{64}$/ { found = 1 }
        END { exit !found }' "$deployment_root/bundle-natural/bundle-manifest.tsv"; then
        printf 'the bundle manifest carries no digest row for %s\n' "$preset_row" >&2
        exit 1
    fi
done
report bundle_members_present accepted

# A preset generated against another ledger is refused at assembly: the zero
# preset names count 0 for a row the positive ledger states at 2.
if QWEN_BUNDLE_ROUTER_PRESETS=$zero_preset \
    "$builder" bundle-preset-mismatch "$natural_server" "$natural_manifest" \
    "$positive_ledger" "$deployment_root" \
    >/dev/null 2>"$work_directory/preset-mismatch.stderr"; then
    printf 'a preset disagreeing with the ledger escaped assembly\n' >&2
    exit 1
fi
if ! grep -q 'disagrees with the bundle ledger' \
    "$work_directory/preset-mismatch.stderr"; then
    printf 'the preset mismatch refusal lost its reason\n' >&2
    exit 1
fi
report preset_ledger_mismatch_refused accepted

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

# The emergency shape assembles: forced-tail server with the all-zero ledger
# and the preset generated against it.
if QWEN_BUNDLE_ROUTER_PRESETS=$zero_preset \
    "$builder" bundle-emergency "$forced_server" "$forced_manifest" \
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

# The activated bundle's preset resolves through the current alias, so the
# launch chain reads the preset generated against the ledger it serves.
if [ "$(readlink -f "$deployment_root/deployment-current/router-presets.ini")" != \
    "$deployment_root/bundle-natural/router-presets.ini" ]; then
    printf 'deployment-current does not resolve the activated preset\n' >&2
    exit 1
fi
report current_resolves_preset accepted

# A preset edited inside the bundle after assembly is refused at activation
# on its digest, and a preset rewritten with a consistent digest is refused on
# the ledger agreement recomputed from the sections.
"$activator" bundle-emergency "$deployment_root" >/dev/null
printf '# edited after assembly\n' >>"$deployment_root/bundle-natural/router-presets.ini"
if "$activator" bundle-natural "$deployment_root" \
    >/dev/null 2>"$work_directory/preset-digest.stderr"; then
    printf 'an edited bundle preset escaped activation\n' >&2
    exit 1
fi
if ! grep -q 'bundle member diverged: router-presets.ini' \
    "$work_directory/preset-digest.stderr"; then
    printf 'the preset digest refusal lost the member it names\n' >&2
    exit 1
fi
write_preset 0 "$deployment_root/bundle-natural/router-presets.ini"
rewritten_digest=$(sha256sum "$deployment_root/bundle-natural/router-presets.ini" |
    cut -d ' ' -f 1)
awk -F'\t' -v OFS='\t' -v digest="$rewritten_digest" '
    $1 == "router-presets.ini" { $2 = digest }
    { print }' "$deployment_root/bundle-natural/bundle-manifest.tsv" \
    >"$deployment_root/bundle-natural/bundle-manifest.tsv.new"
mv "$deployment_root/bundle-natural/bundle-manifest.tsv.new" \
    "$deployment_root/bundle-natural/bundle-manifest.tsv"
if "$activator" bundle-natural "$deployment_root" \
    >/dev/null 2>"$work_directory/preset-ledger.stderr"; then
    printf 'a consistently rewritten preset disagreeing with the ledger escaped activation\n' >&2
    exit 1
fi
if ! grep -q 'disagrees with the bundled ledger' \
    "$work_directory/preset-ledger.stderr"; then
    printf 'the preset ledger refusal lost its reason\n' >&2
    exit 1
fi
write_preset 2 "$deployment_root/bundle-natural/router-presets.ini"
restored_digest=$(sha256sum "$deployment_root/bundle-natural/router-presets.ini" |
    cut -d ' ' -f 1)
awk -F'\t' -v OFS='\t' -v digest="$restored_digest" '
    $1 == "router-presets.ini" { $2 = digest }
    { print }' "$deployment_root/bundle-natural/bundle-manifest.tsv" \
    >"$deployment_root/bundle-natural/bundle-manifest.tsv.new"
mv "$deployment_root/bundle-natural/bundle-manifest.tsv.new" \
    "$deployment_root/bundle-natural/bundle-manifest.tsv"
if [ "$(resolved_bundle current)" != bundle-emergency ]; then
    printf 'a refused preset activation moved deployment-current\n' >&2
    exit 1
fi
"$activator" bundle-natural "$deployment_root" >/dev/null
report bundle_preset_tamper_refused accepted

# A bundle directory renamed onto another name is refused, because the
# bundle_name it was assembled under is bound to the directory it activates
# from.
QWEN_BUNDLE_ROUTER_PRESETS=$zero_preset \
    "$builder" bundle-third "$forced_server" "$forced_manifest" \
    "$zero_ledger" "$deployment_root" >/dev/null
mv "$deployment_root/bundle-third" "$deployment_root/bundle-renamed"
if "$activator" bundle-renamed "$deployment_root" \
    >/dev/null 2>"$work_directory/renamed.stderr"; then
    printf 'a renamed bundle activated under a foreign bundle_name\n' >&2
    exit 1
fi
if ! grep -q 'carries bundle_name bundle-third' "$work_directory/renamed.stderr"; then
    printf 'the renamed-bundle refusal lost the name it found\n' >&2
    exit 1
fi
mv "$deployment_root/bundle-renamed" "$deployment_root/bundle-third"
report renamed_bundle_refused accepted

# Concurrent activations serialize: after three racing writers away from the
# natural bundle, exactly one generation directory remains and the rollback
# pointer names the bundle the last writer displaced rather than the one all
# three read before any published.
race_trials=6
race_trial=0
while [ "$race_trial" -lt "$race_trials" ]; do
    race_trial=$((race_trial + 1))
    "$activator" bundle-natural "$deployment_root" >/dev/null
    "$activator" bundle-emergency "$deployment_root" >/dev/null 2>&1 &
    race_first=$!
    "$activator" bundle-third "$deployment_root" >/dev/null 2>&1 &
    race_second=$!
    "$activator" bundle-emergency "$deployment_root" >/dev/null 2>&1 &
    race_third=$!
    wait "$race_first" "$race_second" "$race_third"
    race_generations=$(find "$deployment_root" -maxdepth 1 \
        -name 'deployment-state.*' -type d | wc -l | tr -d ' ')
    if [ "$race_generations" -ne 1 ]; then
        printf 'racing activations retained %s generation directories in trial %s\n' \
            "$race_generations" "$race_trial" >&2
        exit 1
    fi
    if [ "$(resolved_bundle previous)" = bundle-natural ]; then
        printf 'racing activations lost an intermediate activation from the rollback pointer in trial %s\n' \
            "$race_trial" >&2
        exit 1
    fi
done
"$activator" bundle-emergency "$deployment_root" >/dev/null
"$activator" bundle-natural "$deployment_root" >/dev/null
if [ "$(resolved_bundle current)" != bundle-natural ] || \
    [ "$(resolved_bundle previous)" != bundle-emergency ]; then
    printf 'the pair did not settle after the race trials\n' >&2
    exit 1
fi
report concurrent_activation_serialized accepted

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

# The launchers read the bundled presets through deployment-current ahead of
# the state directory's files.
if ! grep -q 'deployment-current/router-presets.ini' \
    "$script_directory/qwen-launch.sh"; then
    printf 'qwen-launch.sh no longer reads the bundled router preset\n' >&2
    exit 1
fi
if ! grep -q 'deployment-current/web-presets.ini' \
    "$script_directory/qwen-web-launch.sh"; then
    printf 'qwen-web-launch.sh no longer reads the bundled web preset\n' >&2
    exit 1
fi
report launchers_read_bundled_presets accepted

printf 'deployment_bundle=accepted checks=%s\n' "$checks"
