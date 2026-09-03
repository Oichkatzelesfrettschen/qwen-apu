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
# The registry carries the id in column 1 and the model_file in column 3, the
# columns model-registry.sh and the preset check read; the second row is a
# checkpoint the positive ledger leaves at 0.
printf 'qwen-2b\tfast-text\tqwen-2b.gguf\nqwen-08b\tfast\tqwen-08b.gguf\n' \
    >"$QWEN_MODEL_REGISTRY"
model_root=$work_directory/models

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
    printf '# fixture preset\n[qwen-2b]\nLLAMA_ARG_MODEL = %s/qwen-2b.gguf\nLLAMA_ARG_CTX_CHECKPOINTS = %s\n[qwen-2b+draft]\nLLAMA_ARG_MODEL = %s/qwen-2b.gguf\nLLAMA_ARG_CTX_CHECKPOINTS = %s\n' \
        "$model_root" "$1" "$model_root" "$1" >"$2"
}
positive_preset=$work_directory/router-presets-positive.ini
write_preset 2 "$positive_preset"
zero_preset=$work_directory/router-presets-zero.ini
write_preset 0 "$zero_preset"
web_preset=$work_directory/web-presets.ini
printf '[web-profile]\nLLAMA_ARG_MODEL = %s/qwen-2b.gguf\nLLAMA_ARG_CTX_CHECKPOINTS = 2\n' \
    "$model_root" >"$web_preset"

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
for consumer in qwen-webui-control.sh qwen-launch.sh qwen-web-launch.sh; do
    if ! grep -q 'resolve-active-deployment.sh' "$script_directory/$consumer"; then
        printf '%s no longer resolves the active deployment\n' "$consumer" >&2
        exit 1
    fi
done
if ! grep -q 'active_deployment_directory/llama-server' \
    "$script_directory/qwen-webui-control.sh" || \
    ! grep -q 'active_deployment_directory/ctx-checkpoints.tsv' \
    "$script_directory/qwen-webui-control.sh"; then
    printf 'the control script no longer reads the resolved bundle\n' >&2
    exit 1
fi
if ! grep -q 'QWEN_VALIDATED_TUPLES QWEN_CTX_CHECKPOINT_LEDGER' \
    "$script_directory/qwen-webui-control.sh" || \
    ! grep -q 'QWEN_ACTIVE_DEPLOYMENT_DIRECTORY \\' \
    "$script_directory/qwen-webui-control.sh"; then
    printf 'the bundle ledger or directory no longer crosses the tmux boundary\n' >&2
    exit 1
fi
if ! grep -q 'the activated deployment failed resolution; the control start stops' \
    "$script_directory/qwen-webui-control.sh"; then
    printf 'the control script fell back silently on a broken deployment\n' >&2
    exit 1
fi
report control_consults_deployment accepted

# The launchers read the bundled presets from the resolved bundle directory
# ahead of the state directory's files.
if ! grep -q 'active_deployment_directory/router-presets.ini' \
    "$script_directory/qwen-launch.sh"; then
    printf 'qwen-launch.sh no longer reads the bundled router preset\n' >&2
    exit 1
fi
if ! grep -q 'active_deployment_directory/web-presets.ini' \
    "$script_directory/qwen-web-launch.sh"; then
    printf 'qwen-web-launch.sh no longer reads the bundled web preset\n' >&2
    exit 1
fi
report launchers_read_bundled_presets accepted

# A section is bound to its own model's count rather than to any count the
# ledger states somewhere: the 0.8B row is absent from the positive ledger,
# so a section naming its file at 2 is refused even though the ledger states
# 2 for the 2B; a section naming no model, a path outside the registry, and
# a draft-pair section carrying the draft's file at the target's count are
# each refused.
preset_check=$script_directory/verify-bundle-preset-ledger.sh
bound_preset=$work_directory/router-presets-bound.ini
printf '[qwen-08b]\nLLAMA_ARG_MODEL = %s/qwen-08b.gguf\nLLAMA_ARG_CTX_CHECKPOINTS = 2\n' \
    "$model_root" >"$bound_preset"
if "$preset_check" "$bound_preset" "$positive_ledger" \
    >/dev/null 2>"$work_directory/bound.stderr"; then
    printf 'a section carrying another model'"'"'s count escaped the preset check\n' >&2
    exit 1
fi
if ! grep -q 'states 0 for qwen-08b' "$work_directory/bound.stderr"; then
    printf 'the section binding refusal lost the model it resolved\n' >&2
    exit 1
fi
printf '[qwen-08b]\nLLAMA_ARG_MODEL = %s/qwen-08b.gguf\nLLAMA_ARG_CTX_CHECKPOINTS = 0\n' \
    "$model_root" >"$bound_preset"
if ! "$preset_check" "$bound_preset" "$positive_ledger" >/dev/null; then
    printf 'a section carrying its own model'"'"'s zero count was refused\n' >&2
    exit 1
fi
printf '[nameless]\nLLAMA_ARG_CTX_CHECKPOINTS = 2\n' >"$bound_preset"
if "$preset_check" "$bound_preset" "$positive_ledger" >/dev/null 2>&1; then
    printf 'a section naming no model escaped the preset check\n' >&2
    exit 1
fi
printf '[foreign]\nLLAMA_ARG_MODEL = %s/other.gguf\nLLAMA_ARG_CTX_CHECKPOINTS = 0\n' \
    "$model_root" >"$bound_preset"
if "$preset_check" "$bound_preset" "$positive_ledger" \
    >/dev/null 2>"$work_directory/foreign.stderr"; then
    printf 'a section naming a file outside the registry escaped the preset check\n' >&2
    exit 1
fi
if ! grep -q 'resolves to 0 registry rows' "$work_directory/foreign.stderr"; then
    printf 'the foreign-file refusal lost its reason\n' >&2
    exit 1
fi
report section_bound_to_own_model accepted

# The natural bundle is restored from the consistent tamper above, so the
# checks below activate it again.
write_manifest natural-boundary-v1 "$consistent_tamper/llama-server" \
    "$consistent_tamper/artifact-manifest.tsv"
restored_manifest_digest=$(sha256sum "$consistent_tamper/artifact-manifest.tsv" |
    cut -d ' ' -f 1)
awk -F'\t' -v OFS='\t' -v digest="$restored_manifest_digest" -v semantics=natural-boundary-v1 '
    $1 == "artifact-manifest.tsv" { $2 = digest }
    $1 == "checkpoint_semantics" { $2 = semantics }
    { print }' "$consistent_tamper/bundle-manifest.tsv" \
    >"$consistent_tamper/bundle-manifest.tsv.new"
mv "$consistent_tamper/bundle-manifest.tsv.new" \
    "$consistent_tamper/bundle-manifest.tsv"

# The activation lock is a held descriptor rather than an inherited marker: a
# writer exporting the former QWEN_ACTIVATION_LOCK_HELD marker still waits
# behind a holder of the lock file.
"$activator" bundle-natural "$deployment_root" >/dev/null
lock_release=$work_directory/lock-release
sh -c 'exec 7>"$1/.activate.lock"; flock -x 7; : >"$2.held"; while [ ! -e "$2" ]; do sleep 0.1; done' \
    sh "$deployment_root" "$lock_release" &
lock_holder=$!
while [ ! -e "$lock_release.held" ]; do sleep 0.1; done
QWEN_ACTIVATION_LOCK_HELD=$deployment_root \
    "$activator" bundle-third "$deployment_root" >/dev/null 2>&1 &
marked_writer=$!
sleep 1
if [ "$(resolved_bundle current)" != bundle-natural ]; then
    printf 'a writer exporting the former lock marker bypassed the held lock\n' >&2
    exit 1
fi
: >"$lock_release"
wait "$lock_holder" "$marked_writer"
if [ "$(resolved_bundle current)" != bundle-third ]; then
    printf 'the waiting writer did not activate after the lock was released\n' >&2
    exit 1
fi
report lock_descriptor_not_bypassed accepted

# Every name read back from the root is held to its namespace. An outside
# sentinel beside the root proves that a corrupt state link naming a path
# through `..` removes nothing, and each corrupt role link refuses the
# transition rather than naming a bundle outside the root.
outside_directory=$work_directory/outside
mkdir -p "$outside_directory"
printf 'sentinel\n' >"$outside_directory/sentinel"
sentinel_digest=$(sha256sum "$outside_directory/sentinel" | cut -d ' ' -f 1)
"$activator" bundle-natural "$deployment_root" >/dev/null
generation_name=$(readlink "$deployment_root/deployment-state")
ln -sfn "$generation_name/../../outside" "$deployment_root/deployment-state"
if "$activator" bundle-third "$deployment_root" \
    >/dev/null 2>"$work_directory/state-escape.stderr"; then
    printf 'a state link escaping the root did not refuse the transition\n' >&2
    exit 1
fi
if ! grep -q 'exactly deployment-state.N is admitted' \
    "$work_directory/state-escape.stderr"; then
    printf 'the state link refusal lost its reason\n' >&2
    exit 1
fi
if [ ! -d "$outside_directory" ] || \
    [ "$(sha256sum "$outside_directory/sentinel" | cut -d ' ' -f 1)" != "$sentinel_digest" ]; then
    printf 'a corrupt state link reached the outside sentinel\n' >&2
    exit 1
fi
ln -sfn "$generation_name" "$deployment_root/deployment-state"
for escape_target in ../../outside "$outside_directory" ../bundle-natural/extra \
    ../deployment-state.1 ../.; do
    ln -sfn "$escape_target" "$deployment_root/$generation_name/previous"
    if "$activator" rollback "$deployment_root" \
        >/dev/null 2>"$work_directory/role-escape.stderr"; then
        printf 'a role link targeting %s carried a rollback\n' "$escape_target" >&2
        exit 1
    fi
    if ! grep -q 'exactly ../BUNDLE_NAME is admitted' \
        "$work_directory/role-escape.stderr"; then
        printf 'the role link refusal for %s lost its reason\n' "$escape_target" >&2
        exit 1
    fi
done
ln -sfn ../bundle-third "$deployment_root/$generation_name/previous"
if [ "$(sha256sum "$outside_directory/sentinel" | cut -d ' ' -f 1)" != "$sentinel_digest" ] || \
    [ ! -d "$deployment_root/bundle-natural" ]; then
    printf 'a corrupt role link reached the sentinel or the bundle\n' >&2
    exit 1
fi
report link_escape_refused accepted

# A symlinked bundle directory and a symlinked member are refused, so a link
# planted at the root cannot carry an activation to bytes outside it.
ln -s "$outside_directory" "$deployment_root/bundle-link"
if "$activator" bundle-link "$deployment_root" \
    >/dev/null 2>"$work_directory/bundle-link.stderr"; then
    printf 'a symlinked bundle directory activated\n' >&2
    exit 1
fi
if ! grep -q 'bundle directory is a symlink' "$work_directory/bundle-link.stderr"; then
    printf 'the symlinked bundle refusal lost its reason\n' >&2
    exit 1
fi
rm "$deployment_root/bundle-link"
cp "$deployment_root/bundle-third/ctx-checkpoints.tsv" "$outside_directory/ledger.tsv"
mv "$deployment_root/bundle-third/ctx-checkpoints.tsv" "$work_directory/ledger-third.tsv"
ln -s "$outside_directory/ledger.tsv" "$deployment_root/bundle-third/ctx-checkpoints.tsv"
if "$activator" bundle-third "$deployment_root" \
    >/dev/null 2>"$work_directory/member-link.stderr"; then
    printf 'a bundle carrying a symlinked member activated\n' >&2
    exit 1
fi
if ! grep -q 'bundle member is a symlink' "$work_directory/member-link.stderr"; then
    printf 'the symlinked member refusal lost its reason\n' >&2
    exit 1
fi
rm "$deployment_root/bundle-third/ctx-checkpoints.tsv"
mv "$work_directory/ledger-third.tsv" "$deployment_root/bundle-third/ctx-checkpoints.tsv"
report symlinked_bundle_refused accepted

# The launch-side resolver names one canonical bundle and its members, keeps
# naming the bundle a caller already retained after another activation moves
# the pointer, refuses a retained directory outside the root, and reports an
# empty root as exit 3 so the promote-chain defaults apply.
resolver=$script_directory/resolve-active-deployment.sh
"$activator" bundle-natural "$deployment_root" >/dev/null
resolution=$("$resolver" "$deployment_root")
resolved_directory=$(printf '%s\n' "$resolution" | sed -n 's/^active_deployment_directory=//p')
if [ "$resolved_directory" != "$(readlink -f "$deployment_root")/bundle-natural" ] || \
    ! printf '%s\n' "$resolution" | grep -qx "active_deployment_router_presets=$resolved_directory/router-presets.ini" || \
    ! printf '%s\n' "$resolution" | grep -qx "active_deployment_server=$resolved_directory/llama-server"; then
    printf 'the resolver named something other than the activated bundle: %s\n' \
        "$resolution" >&2
    exit 1
fi
"$activator" bundle-third "$deployment_root" >/dev/null
retained=$(QWEN_ACTIVE_DEPLOYMENT_DIRECTORY=$resolved_directory "$resolver" "$deployment_root" |
    sed -n 's/^active_deployment_ledger=//p')
if [ "$retained" != "$resolved_directory/ctx-checkpoints.tsv" ]; then
    printf 'a retained bundle directory was replaced by the new deployment-current\n' >&2
    exit 1
fi
if [ "$("$resolver" "$deployment_root" | sed -n 's/^active_deployment_name=//p')" != bundle-third ]; then
    printf 'a fresh resolution did not follow the new deployment-current\n' >&2
    exit 1
fi
if QWEN_ACTIVE_DEPLOYMENT_DIRECTORY=$outside_directory "$resolver" "$deployment_root" \
    >/dev/null 2>"$work_directory/resolver-outside.stderr"; then
    printf 'a retained directory outside the root passed resolution\n' >&2
    exit 1
fi
if ! grep -q 'outside the deployment root' "$work_directory/resolver-outside.stderr"; then
    printf 'the outside-root resolver refusal lost its reason\n' >&2
    exit 1
fi
empty_root=$work_directory/empty-root
mkdir -p "$empty_root"
"$resolver" "$empty_root" >/dev/null 2>&1 && resolver_status=0 || resolver_status=$?
if [ "$resolver_status" -ne 3 ]; then
    printf 'an empty root resolved with status %s rather than 3\n' "$resolver_status" >&2
    exit 1
fi
report resolver_one_bundle accepted

# Absence is decided under the activation lock. The leaf is created private
# here so the helper's legacy-mode branch returns at once and the resolver
# reaches `flock -s 7`, where a held exclusive lock stops it: a resolver that
# answered 3 from a pre-lock read would report an empty root while an
# activation was midway through publishing one.
locked_root=$work_directory/locked-root
mkdir -p "$locked_root"
locked_lock_path=$locked_root/.activate.lock
: >"$locked_lock_path"
chmod 600 "$locked_lock_path"
flock -x "$locked_lock_path" sleep 5 &
lock_holder_pid=$!
lock_wait=0
while [ "$lock_wait" -lt 50 ] && \
    flock -x -n "$locked_lock_path" true 2>/dev/null; do
    lock_wait=$((lock_wait + 1))
    sleep 0.1
done
timeout 2 "$resolver" "$locked_root" >/dev/null 2>&1 && locked_status=0 || \
    locked_status=$?
kill "$lock_holder_pid" 2>/dev/null || :
wait "$lock_holder_pid" 2>/dev/null || :
if [ "$locked_status" -eq 3 ]; then
    printf 'the resolver reported an empty root while the activation lock was held\n' >&2
    exit 1
fi
if [ "$locked_status" -ne 124 ]; then
    printf 'the resolver left the held activation lock with status %s rather than blocking\n' \
        "$locked_status" >&2
    exit 1
fi
report absence_decided_under_lock accepted

# The lock leaf is opened without following links or truncating: a symlinked
# .activate.lock aimed at the outside sentinel refuses both the activator and
# the resolver and leaves the sentinel's bytes as they were; a directory and
# a loose mode refuse; an inherited-descriptor marker without descriptor 7,
# or with an unrelated descriptor 7, refuses on the helper's own check.
lock_path=$deployment_root/.activate.lock
rm -f "$lock_path"
ln -s "$outside_directory/sentinel" "$lock_path"
if "$activator" bundle-third "$deployment_root" >/dev/null 2>"$work_directory/lock-symlink.stderr"; then
    printf 'a symlinked activation lock carried an activation\n' >&2
    exit 1
fi
if ! grep -q 'verified_lock_descriptor=rejected' "$work_directory/lock-symlink.stderr"; then
    printf 'the symlinked lock refusal did not come from the descriptor helper\n' >&2
    exit 1
fi
if "$resolver" "$deployment_root" >/dev/null 2>"$work_directory/lock-symlink-resolve.stderr"; then
    printf 'a symlinked activation lock carried a resolution\n' >&2
    exit 1
fi
if [ "$(sha256sum "$outside_directory/sentinel" | cut -d ' ' -f 1)" != "$sentinel_digest" ]; then
    printf 'opening the lock through a symlink truncated the sentinel\n' >&2
    exit 1
fi
rm -f "$lock_path"
mkdir "$lock_path"
if "$activator" bundle-third "$deployment_root" >/dev/null 2>&1 || \
    "$resolver" "$deployment_root" >/dev/null 2>&1; then
    printf 'a directory at the lock path was accepted\n' >&2
    exit 1
fi
rmdir "$lock_path"
: >"$lock_path"
chmod 0666 "$lock_path"
if "$activator" bundle-third "$deployment_root" >/dev/null 2>"$work_directory/lock-mode.stderr" || \
    "$resolver" "$deployment_root" >/dev/null 2>&1; then
    printf 'a lock leaf with a loose mode was accepted\n' >&2
    exit 1
fi
if ! grep -q 'not the admitted legacy mode' "$work_directory/lock-mode.stderr"; then
    printf 'the loose-mode refusal lost its reason\n' >&2
    exit 1
fi
rm -f "$lock_path"
if QWEN_ACTIVATION_LOCK_DESCRIPTOR_INHERITED=1 "$activator" bundle-third "$deployment_root" \
    >/dev/null 2>"$work_directory/lock-marker.stderr"; then
    printf 'an inherited-descriptor marker without descriptor 7 was accepted\n' >&2
    exit 1
fi
if ! grep -q 'verified_lock_descriptor=rejected' "$work_directory/lock-marker.stderr"; then
    printf 'the missing-descriptor refusal did not come from the descriptor helper\n' >&2
    exit 1
fi
if QWEN_ACTIVATION_LOCK_DESCRIPTOR_INHERITED=1 "$resolver" "$deployment_root" \
    7<"$outside_directory/sentinel" >/dev/null 2>"$work_directory/lock-foreign.stderr"; then
    printf 'an inherited marker over an unrelated descriptor 7 was accepted\n' >&2
    exit 1
fi
if ! grep -q 'verified_lock_descriptor=rejected' "$work_directory/lock-foreign.stderr"; then
    printf 'the unrelated-descriptor refusal did not come from the descriptor helper\n' >&2
    exit 1
fi
"$activator" bundle-third "$deployment_root" >/dev/null
if [ "$(stat -c %a "$lock_path")" != 600 ]; then
    printf 'the lock leaf was created at mode %s rather than 600\n' "$(stat -c %a "$lock_path")" >&2
    exit 1
fi
report lock_leaf_verified accepted

# A manifest with a second, conflicting executable llama-server row is
# refused at assembly and at activation, the cardinality the exec guard
# applies, even though one row matches the server.
conflicting_manifest=$work_directory/manifest-conflicting.tsv
{
    cat "$forced_manifest"
    printf 'executable\tllama-server\t1\t%s\n' \
        "0000000000000000000000000000000000000000000000000000000000000000"
} >"$conflicting_manifest"
if QWEN_BUNDLE_ROUTER_PRESETS=$zero_preset \
    "$builder" bundle-conflicting "$forced_server" "$conflicting_manifest" \
    "$zero_ledger" "$deployment_root" >/dev/null 2>"$work_directory/conflicting.stderr"; then
    printf 'a manifest with two executable rows assembled\n' >&2
    exit 1
fi
if ! grep -q 'holds 2 executable llama-server rows' "$work_directory/conflicting.stderr"; then
    printf 'the conflicting-row refusal lost its count\n' >&2
    exit 1
fi
"$activator" bundle-natural "$deployment_root" >/dev/null
cp "$conflicting_manifest" "$deployment_root/bundle-third/artifact-manifest.tsv"
conflicting_digest=$(sha256sum "$deployment_root/bundle-third/artifact-manifest.tsv" |
    cut -d ' ' -f 1)
awk -F'\t' -v OFS='\t' -v digest="$conflicting_digest" '
    $1 == "artifact-manifest.tsv" { $2 = digest }
    { print }' "$deployment_root/bundle-third/bundle-manifest.tsv" \
    >"$deployment_root/bundle-third/bundle-manifest.tsv.new"
mv "$deployment_root/bundle-third/bundle-manifest.tsv.new" \
    "$deployment_root/bundle-third/bundle-manifest.tsv"
if "$activator" bundle-third "$deployment_root" \
    >/dev/null 2>"$work_directory/conflicting-activate.stderr"; then
    printf 'a manifest with two executable rows activated\n' >&2
    exit 1
fi
if ! grep -q 'holds 2 executable llama-server rows' "$work_directory/conflicting-activate.stderr"; then
    printf 'the conflicting-row activation refusal lost its count\n' >&2
    exit 1
fi
cp "$forced_manifest" "$deployment_root/bundle-third/artifact-manifest.tsv"
restored_third_digest=$(sha256sum "$deployment_root/bundle-third/artifact-manifest.tsv" |
    cut -d ' ' -f 1)
awk -F'\t' -v OFS='\t' -v digest="$restored_third_digest" '
    $1 == "artifact-manifest.tsv" { $2 = digest }
    { print }' "$deployment_root/bundle-third/bundle-manifest.tsv" \
    >"$deployment_root/bundle-third/bundle-manifest.tsv.new"
mv "$deployment_root/bundle-third/bundle-manifest.tsv.new" \
    "$deployment_root/bundle-third/bundle-manifest.tsv"
report executable_row_cardinality accepted

# A bundle name starts with an alphanumeric and avoids the root's own names;
# staging is a private random directory, so an existing dot-prefixed entry at
# the root survives an assembly under the name it would once have collided
# with, and a staged bundle that fails verification publishes nothing.
for reserved_name in .foo deployment-current deployment-state.1 .activate.lock -x; do
    if QWEN_BUNDLE_ROUTER_PRESETS=$zero_preset \
        "$builder" "$reserved_name" "$forced_server" "$forced_manifest" \
        "$zero_ledger" "$deployment_root" >/dev/null 2>&1; then
        printf 'the reserved bundle name %s was accepted\n' "$reserved_name" >&2
        exit 1
    fi
done
mkdir "$deployment_root/.foo.staging"
printf 'kept\n' >"$deployment_root/.foo.staging/marker"
QWEN_BUNDLE_ROUTER_PRESETS=$zero_preset \
    "$builder" foo "$forced_server" "$forced_manifest" "$zero_ledger" "$deployment_root" >/dev/null
if [ ! -f "$deployment_root/.foo.staging/marker" ] || [ ! -d "$deployment_root/foo" ]; then
    printf 'assembling foo removed the unrelated .foo.staging entry or published nothing\n' >&2
    exit 1
fi
if [ -n "$(ls -A "$deployment_root/.staging" 2>/dev/null)" ]; then
    printf 'a completed assembly left its staging directory behind\n' >&2
    exit 1
fi
report bundle_name_and_staging accepted

# The staging parent is a plain directory the assembly creates or reuses. A
# symlink planted at .staging is refused whole, so the copied server, ledger,
# and preset stay out of the directory it names and the trap that removes the
# staging root removes nothing there; a leaf that is not a directory refuses
# on the same rule.
staging_link_root=$work_directory/staging-link-root
mkdir -p "$staging_link_root"
staging_link_target=$work_directory/staging-link-target
mkdir -p "$staging_link_target"
printf 'kept\n' >"$staging_link_target/marker"
ln -s "$staging_link_target" "$staging_link_root/.staging"
if QWEN_BUNDLE_ROUTER_PRESETS=$zero_preset \
    "$builder" bundle-staged "$forced_server" "$forced_manifest" \
    "$zero_ledger" "$staging_link_root" \
    >/dev/null 2>"$work_directory/staging-link.stderr"; then
    printf 'a symlinked staging parent carried an assembly\n' >&2
    exit 1
fi
if ! grep -q 'staging parent is a symlink' "$work_directory/staging-link.stderr"; then
    printf 'the symlinked staging refusal lost its reason\n' >&2
    exit 1
fi
if [ "$(ls -A "$staging_link_target")" != marker ] || \
    [ ! -f "$staging_link_target/marker" ] || \
    [ -e "$staging_link_root/bundle-staged" ]; then
    printf 'a symlinked staging parent reached the directory it named\n' >&2
    exit 1
fi
rm "$staging_link_root/.staging"
printf 'leaf\n' >"$staging_link_root/.staging"
if QWEN_BUNDLE_ROUTER_PRESETS=$zero_preset \
    "$builder" bundle-staged "$forced_server" "$forced_manifest" \
    "$zero_ledger" "$staging_link_root" \
    >/dev/null 2>"$work_directory/staging-leaf.stderr"; then
    printf 'a regular file at the staging parent carried an assembly\n' >&2
    exit 1
fi
if ! grep -q 'staging parent is not a directory' "$work_directory/staging-leaf.stderr"; then
    printf 'the non-directory staging refusal lost its reason\n' >&2
    exit 1
fi
report staging_parent_plain_directory accepted

# A section path two registry rows match under the registry's raw suffix
# rule is refused as ambiguous rather than bound to the first row.
ambiguous_registry=$work_directory/models-ambiguous.tsv
printf 'foo\tfast\tfoo.gguf\nxfoo\tfast\txfoo.gguf\n' >"$ambiguous_registry"
ambiguous_ledger=$work_directory/ledger-ambiguous.tsv
printf 'foo\t0\t-\nxfoo\t0\t-\n' >"$ambiguous_ledger"
printf '[xfoo]\nLLAMA_ARG_MODEL = %s/xfoo.gguf\nLLAMA_ARG_CTX_CHECKPOINTS = 0\n' \
    "$model_root" >"$bound_preset"
if "$preset_check" "$bound_preset" "$ambiguous_ledger" "$ambiguous_registry" \
    >/dev/null 2>"$work_directory/ambiguous.stderr"; then
    printf 'a path two registry rows match was bound to one of them\n' >&2
    exit 1
fi
if ! grep -q 'resolves to 2 registry rows' "$work_directory/ambiguous.stderr"; then
    printf 'the ambiguity refusal lost its count\n' >&2
    exit 1
fi
printf '[foo]\nLLAMA_ARG_MODEL = %s/foo.gguf\nLLAMA_ARG_CTX_CHECKPOINTS = 0\n' \
    "$model_root" >"$bound_preset"
if ! "$preset_check" "$bound_preset" "$ambiguous_ledger" "$ambiguous_registry" >/dev/null; then
    printf 'a path one registry row matches was refused\n' >&2
    exit 1
fi
report suffix_ambiguity_refused accepted

# A diagnostic build declares serving_eligible no in its artifact manifest
# and is refused at assembly; the same manifest planted into an assembled
# bundle with consistent digests is refused at activation.
diagnostic_manifest=$work_directory/manifest-diagnostic.tsv
{
    printf 'instrumentation\tpipeline-census-v1\nbuild_role\tdiagnostic\nserving_eligible\tno\n'
    cat "$forced_manifest"
} >"$diagnostic_manifest"
if "$builder" bundle-diagnostic "$forced_server" "$diagnostic_manifest" \
    "$zero_ledger" "$deployment_root" \
    >/dev/null 2>"$work_directory/diagnostic.stderr"; then
    printf 'a diagnostic build assembled into a bundle\n' >&2
    exit 1
fi
if ! grep -q 'serving_eligible no (instrumentation pipeline-census-v1)' \
    "$work_directory/diagnostic.stderr"; then
    printf 'the diagnostic refusal lost its declaration\n' >&2
    exit 1
fi
"$activator" bundle-natural "$deployment_root" >/dev/null
cp "$diagnostic_manifest" "$deployment_root/bundle-third/artifact-manifest.tsv"
diagnostic_digest=$(sha256sum "$deployment_root/bundle-third/artifact-manifest.tsv" |
    cut -d ' ' -f 1)
awk -F'\t' -v OFS='\t' -v digest="$diagnostic_digest" '
    $1 == "artifact-manifest.tsv" { $2 = digest }
    { print }' "$deployment_root/bundle-third/bundle-manifest.tsv" \
    >"$deployment_root/bundle-third/bundle-manifest.tsv.new"
mv "$deployment_root/bundle-third/bundle-manifest.tsv.new" \
    "$deployment_root/bundle-third/bundle-manifest.tsv"
if "$activator" bundle-third "$deployment_root" \
    >/dev/null 2>"$work_directory/diagnostic-activate.stderr"; then
    printf 'a diagnostic manifest activated\n' >&2
    exit 1
fi
if ! grep -q 'a diagnostic build stays inactive' \
    "$work_directory/diagnostic-activate.stderr"; then
    printf 'the diagnostic activation refusal lost its reason\n' >&2
    exit 1
fi
report diagnostic_build_refused accepted

printf 'deployment_bundle=accepted checks=%s\n' "$checks"
