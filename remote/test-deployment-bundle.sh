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
verifier=$script_directory/verify-deployment-bundle.sh
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

# The Q4_K formulation binds to the same resolved row. A registry releasing one
# for the 2B requires that section to carry the key and requires every other
# section to carry none, so a preset generated against another registry is
# refused at assembly and at activation rather than serving a formulation the
# row never released.
q4k_registry=$work_directory/q4k-models.tsv
awk -F'\t' 'BEGIN { OFS = "\t" }
    { for (field = NF + 1; field <= 23; field++) { $field = "-" }
      if ($1 == "qwen-2b") { $23 = "e4-scale/4" }
      print }' "$QWEN_MODEL_REGISTRY" >"$q4k_registry"
printf '[qwen-2b]\nLLAMA_ARG_MODEL = %s/qwen-2b.gguf\nLLAMA_ARG_CTX_CHECKPOINTS = 2\nLLAMA_ARG_VK_Q4K_VARIANT = e4-scale/4\n' \
    "$model_root" >"$bound_preset"
if ! "$preset_check" "$bound_preset" "$positive_ledger" "$q4k_registry" \
    >/dev/null 2>"$work_directory/q4k-match.stderr"; then
    printf 'a section carrying its own row formulation was refused\n' >&2
    cat "$work_directory/q4k-match.stderr" >&2
    exit 1
fi
printf '[qwen-2b]\nLLAMA_ARG_MODEL = %s/qwen-2b.gguf\nLLAMA_ARG_CTX_CHECKPOINTS = 2\nLLAMA_ARG_VK_Q4K_VARIANT = e4/4\n' \
    "$model_root" >"$bound_preset"
if "$preset_check" "$bound_preset" "$positive_ledger" "$q4k_registry" \
    >/dev/null 2>"$work_directory/q4k-drift.stderr"; then
    printf 'a section naming another formulation escaped the preset check\n' >&2
    exit 1
fi
if ! grep -q 'carries Q4_K formulation e4/4 where the registry releases e4-scale/4' \
    "$work_directory/q4k-drift.stderr"; then
    printf 'the formulation drift refusal lost its reason\n' >&2
    exit 1
fi
printf '[qwen-2b]\nLLAMA_ARG_MODEL = %s/qwen-2b.gguf\nLLAMA_ARG_CTX_CHECKPOINTS = 2\n' \
    "$model_root" >"$bound_preset"
if "$preset_check" "$bound_preset" "$positive_ledger" "$q4k_registry" \
    >/dev/null 2>"$work_directory/q4k-absent.stderr"; then
    printf 'a section omitting a released formulation escaped the preset check\n' >&2
    exit 1
fi
if ! grep -q 'carries 0 LLAMA_ARG_VK_Q4K_VARIANT keys' \
    "$work_directory/q4k-absent.stderr"; then
    printf 'the absent-formulation refusal lost its reason\n' >&2
    exit 1
fi
printf '[qwen-08b]\nLLAMA_ARG_MODEL = %s/qwen-08b.gguf\nLLAMA_ARG_CTX_CHECKPOINTS = 0\nLLAMA_ARG_VK_Q4K_VARIANT = e4-scale/4\n' \
    "$model_root" >"$bound_preset"
if "$preset_check" "$bound_preset" "$positive_ledger" "$q4k_registry" \
    >/dev/null 2>"$work_directory/q4k-unreleased.stderr"; then
    printf 'a section keyed against an unreleased row escaped the preset check\n' >&2
    exit 1
fi
if ! grep -q 'releases no Q4_K formulation for qwen-08b' \
    "$work_directory/q4k-unreleased.stderr"; then
    printf 'the unreleased-formulation refusal lost its reason\n' >&2
    exit 1
fi
report preset_bound_to_row_formulation accepted

# The formulation authority travels with the bundle, so a release that promotes
# a row leaves every already-assembled bundle verifiable. The registry column
# alone would refuse in both directions at once -- an old keyless preset against
# a registry that now releases a formulation, and a new keyed preset against the
# registry it was generated before -- which leaves no order in which a release
# and its rollback both verify. A `-` policy is the pre-member bundle: its
# generator wrote no section key because it wrote no policy either.
printf '[qwen-2b]\nLLAMA_ARG_MODEL = %s/qwen-2b.gguf\nLLAMA_ARG_CTX_CHECKPOINTS = 2\n' \
    "$model_root" >"$bound_preset"
if ! QWEN_BUNDLE_Q4K_POLICY=- "$preset_check" "$bound_preset" \
    "$positive_ledger" "$q4k_registry" \
    >/dev/null 2>"$work_directory/q4k-policy-keyless.stderr"; then
    printf 'a bundle predating the policy member was refused against a registry that released a formulation\n' >&2
    cat "$work_directory/q4k-policy-keyless.stderr" >&2
    exit 1
fi
# A bundled policy answers where the registry disagrees, in both directions.
q4k_policy=$work_directory/q4k-policy.tsv
printf 'qwen-2b\te4-scale/4\nqwen-08b\t-\n' >"$q4k_policy"
printf '[qwen-2b]\nLLAMA_ARG_MODEL = %s/qwen-2b.gguf\nLLAMA_ARG_CTX_CHECKPOINTS = 2\nLLAMA_ARG_VK_Q4K_VARIANT = e4-scale/4\n' \
    "$model_root" >"$bound_preset"
if ! "$preset_check" "$bound_preset" "$positive_ledger" "$QWEN_MODEL_REGISTRY" \
    "$q4k_policy" >/dev/null 2>"$work_directory/q4k-policy-ahead.stderr"; then
    printf 'a keyed section was refused against its own bundled policy\n' >&2
    cat "$work_directory/q4k-policy-ahead.stderr" >&2
    exit 1
fi
# A policy that disagrees with the preset beside it refuses, so the member
# states the release rather than decorating it.
printf 'qwen-2b\t-\nqwen-08b\t-\n' >"$q4k_policy"
if "$preset_check" "$bound_preset" "$positive_ledger" "$q4k_registry" \
    "$q4k_policy" >/dev/null 2>"$work_directory/q4k-policy-conflict.stderr"; then
    printf 'a section keyed against its own unreleasing policy escaped the preset check\n' >&2
    exit 1
fi
if ! grep -q 'the bundled Q4_K policy releases no Q4_K formulation for qwen-2b' \
    "$work_directory/q4k-policy-conflict.stderr"; then
    printf 'the bundled-policy conflict refusal lost its reason\n' >&2
    cat "$work_directory/q4k-policy-conflict.stderr" >&2
    exit 1
fi
# A model the policy never names is refused rather than read as unreleased, so
# a policy written against a narrower registry cannot silently admit a section.
printf 'qwen-08b\t-\n' >"$q4k_policy"
if "$preset_check" "$bound_preset" "$positive_ledger" "$q4k_registry" \
    "$q4k_policy" >/dev/null 2>"$work_directory/q4k-policy-gap.stderr"; then
    printf 'a section outside the bundled policy escaped the preset check\n' >&2
    exit 1
fi
if ! grep -q 'which the bundled Q4_K policy never names' \
    "$work_directory/q4k-policy-gap.stderr"; then
    printf 'the policy-gap refusal lost its reason\n' >&2
    cat "$work_directory/q4k-policy-gap.stderr" >&2
    exit 1
fi
report formulation_policy_travels_with_the_bundle accepted

# The assembled bundle states its own policy, and a bundle that predates the
# member keeps verifying after the registry moves under it. The second half is
# the regression: without the member the activator refuses the rollback target
# the release depends on.
if ! QWEN_BUNDLE_ROUTER_PRESETS=$positive_preset \
    "$builder" bundle-policy-baseline "$natural_server" "$natural_manifest" \
    "$positive_ledger" "$deployment_root" \
    >/dev/null 2>"$work_directory/policy-baseline.stderr"; then
    printf 'the policy baseline bundle failed to assemble\n' >&2
    cat "$work_directory/policy-baseline.stderr" >&2
    exit 1
fi
if [ ! -r "$deployment_root/bundle-policy-baseline/q4k-policy.tsv" ]; then
    printf 'the assembled bundle carries no Q4_K policy member\n' >&2
    exit 1
fi
if ! awk -F'\t' '$1 == "q4k-policy.tsv" && $2 ~ /^[0-9a-f]{64}$/ { found = 1 }
    END { exit !found }' \
    "$deployment_root/bundle-policy-baseline/bundle-manifest.tsv"; then
    printf 'the bundle manifest carries no digest row for q4k-policy.tsv\n' >&2
    exit 1
fi
released_registry=$work_directory/released-models.tsv
awk -F'\t' 'BEGIN { OFS = "\t" }
    { for (field = NF + 1; field <= 23; field++) { $field = "-" }
      if ($1 == "qwen-2b") { $23 = "e4-scale-licm/4" }
      print }' "$QWEN_MODEL_REGISTRY" >"$released_registry"
if ! QWEN_MODEL_REGISTRY=$released_registry "$verifier" "$deployment_root" \
    bundle-policy-baseline >/dev/null 2>"$work_directory/released-verify.stderr"; then
    printf 'a bundle assembled before a release was refused after the registry released a formulation\n' >&2
    cat "$work_directory/released-verify.stderr" >&2
    exit 1
fi
if ! QWEN_BUNDLE_ROUTER_PRESETS=$positive_preset \
    "$builder" bundle-legacy-policy "$natural_server" "$natural_manifest" \
    "$positive_ledger" "$deployment_root" \
    >/dev/null 2>"$work_directory/legacy-assemble.stderr"; then
    printf 'the legacy policy bundle failed to assemble\n' >&2
    cat "$work_directory/legacy-assemble.stderr" >&2
    exit 1
fi
legacy_bundle=$deployment_root/bundle-legacy-policy
legacy_manifest=$legacy_bundle/bundle-manifest.tsv
legacy_policy_digest=$(awk -F'\t' '$1 == "q4k-policy.tsv" { print $2; exit }' \
    "$legacy_manifest")
printf 'qwen-2b\te4/8\n' >"$legacy_bundle/q4k-policy.tsv"
if QWEN_MODEL_REGISTRY=$released_registry "$verifier" "$deployment_root" \
    bundle-legacy-policy >/dev/null 2>"$work_directory/legacy-digest.stderr"; then
    printf 'a policy member diverging from its recorded digest escaped verification\n' >&2
    exit 1
fi
if ! grep -q 'bundle member diverged: q4k-policy.tsv' \
    "$work_directory/legacy-digest.stderr"; then
    printf 'the diverged-policy refusal lost its reason\n' >&2
    exit 1
fi
# The pre-member bundle: no policy file, and a manifest row reading `-`. It is
# the one every laptop already holds, and it verifies after the registry moves.
cp "$deployment_root/bundle-policy-baseline/q4k-policy.tsv" \
    "$legacy_bundle/q4k-policy.tsv"
if [ "$(sha256sum "$legacy_bundle/q4k-policy.tsv" | cut -d ' ' -f 1)" != \
    "$legacy_policy_digest" ]; then
    printf 'two bundles assembled from one registry recorded different policies\n' >&2
    exit 1
fi
rm -f "$legacy_bundle/q4k-policy.tsv"
awk -F'\t' 'BEGIN { OFS = "\t" } $1 == "q4k-policy.tsv" { $2 = "-" } { print }' \
    "$legacy_manifest" >"$legacy_manifest.next"
mv "$legacy_manifest.next" "$legacy_manifest"
if ! QWEN_MODEL_REGISTRY=$released_registry "$verifier" "$deployment_root" \
    bundle-legacy-policy >/dev/null 2>"$work_directory/legacy-verify.stderr"; then
    printf 'a bundle recording no policy member was refused after the registry released a formulation\n' >&2
    cat "$work_directory/legacy-verify.stderr" >&2
    exit 1
fi
cp "$deployment_root/bundle-policy-baseline/q4k-policy.tsv" \
    "$legacy_bundle/q4k-policy.tsv"
if QWEN_MODEL_REGISTRY=$released_registry "$verifier" "$deployment_root" \
    bundle-legacy-policy >/dev/null 2>"$work_directory/legacy-present.stderr"; then
    printf 'a bundle carrying a policy its manifest records as absent escaped verification\n' >&2
    exit 1
fi
if ! grep -q 'q4k-policy.tsv that its manifest records as absent' \
    "$work_directory/legacy-present.stderr"; then
    printf 'the recorded-absent policy refusal lost its reason\n' >&2
    exit 1
fi
rm -rf "$legacy_bundle"
report bundle_states_its_own_formulation_policy accepted


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
: >"$outside_directory/private-leaf"
chmod 0600 "$outside_directory/private-leaf"
ln "$outside_directory/private-leaf" "$lock_path"
if "$activator" bundle-third "$deployment_root" >/dev/null 2>"$work_directory/lock-hardlink.stderr" || \
    "$resolver" "$deployment_root" >/dev/null 2>&1; then
    printf 'a hard-linked private leaf at the lock path was accepted\n' >&2
    exit 1
fi
if ! grep -q 'hard links' "$work_directory/lock-hardlink.stderr"; then
    printf 'the hard-link refusal lost its reason\n' >&2
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
if ! grep -q 'grants write access to another user' "$work_directory/lock-mode.stderr"; then
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

# Assembly, verification, activation, and resolution read one bundle
# namespace. A complete bundle carrying a dot-prefixed name -- the shape a
# directory planted as .staging or .activate.lock would take -- is refused by
# every reader rather than assembled under one rule and served under another.
dot_root=$work_directory/dot-name-root
mkdir -p "$dot_root"
QWEN_BUNDLE_ROUTER_PRESETS=$zero_preset \
    "$builder" hidden "$forced_server" "$forced_manifest" "$zero_ledger" \
    "$dot_root" >/dev/null
mv "$dot_root/hidden" "$dot_root/.hidden"
awk -F'\t' -v OFS='\t' '$1 == "bundle_name" { $2 = ".hidden" } { print }' \
    "$dot_root/.hidden/bundle-manifest.tsv" \
    >"$dot_root/.hidden/bundle-manifest.tsv.new"
mv "$dot_root/.hidden/bundle-manifest.tsv.new" \
    "$dot_root/.hidden/bundle-manifest.tsv"
if "$script_directory/verify-deployment-bundle.sh" "$dot_root" .hidden \
    >/dev/null 2>"$work_directory/dot-verify.stderr"; then
    printf 'a dot-prefixed bundle name passed verification\n' >&2
    exit 1
fi
if ! grep -q 'avoid the root names' "$work_directory/dot-verify.stderr"; then
    printf 'the dot-prefixed verification refusal lost its reason\n' >&2
    exit 1
fi
if "$activator" .hidden "$dot_root" \
    >/dev/null 2>"$work_directory/dot-activate.stderr"; then
    printf 'a dot-prefixed bundle name activated\n' >&2
    exit 1
fi
if ! grep -q 'avoid the root names' "$work_directory/dot-activate.stderr"; then
    printf 'the dot-prefixed activation refusal lost its reason\n' >&2
    exit 1
fi
if QWEN_ACTIVE_DEPLOYMENT_DIRECTORY=$dot_root/.hidden "$resolver" "$dot_root" \
    >/dev/null 2>"$work_directory/dot-resolve.stderr"; then
    printf 'a dot-prefixed bundle name resolved for a launch\n' >&2
    exit 1
fi
if ! grep -q 'avoid the root names' "$work_directory/dot-resolve.stderr"; then
    printf 'the dot-prefixed resolution refusal lost its reason\n' >&2
    exit 1
fi
report bundle_namespace_shared accepted

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
# bundle with consistent digests is refused at activation. The refusal names
# the instrumentation rather than the eligibility spelling, because an
# instrumentation row refuses the bundle however that row reads.
diagnostic_manifest=$work_directory/manifest-diagnostic.tsv
{
    printf 'instrumentation\tpipeline-census-v3\nbuild_role\tdiagnostic\nserving_eligible\tno\n'
    cat "$forced_manifest"
} >"$diagnostic_manifest"
if "$builder" bundle-diagnostic "$forced_server" "$diagnostic_manifest" \
    "$zero_ledger" "$deployment_root" \
    >/dev/null 2>"$work_directory/diagnostic.stderr"; then
    printf 'a diagnostic build assembled into a bundle\n' >&2
    exit 1
fi
if ! grep -q 'names instrumentation pipeline-census-v3; a bundle carries serving builds alone' \
    "$work_directory/diagnostic.stderr"; then
    printf 'the diagnostic refusal lost its declaration\n' >&2
    exit 1
fi
# A manifest carrying serving_eligible twice, yes ahead of no, is refused on
# cardinality rather than read by its first row.
duplicate_manifest=$work_directory/manifest-duplicate-eligibility.tsv
{
    printf 'serving_eligible\tyes\n'
    cat "$diagnostic_manifest"
} >"$duplicate_manifest"
if "$builder" bundle-duplicate "$forced_server" "$duplicate_manifest" \
    "$zero_ledger" "$deployment_root" \
    >/dev/null 2>"$work_directory/duplicate-eligibility.stderr"; then
    printf 'a manifest with two serving_eligible rows assembled\n' >&2
    exit 1
fi
if ! grep -q 'serving_eligible rows' "$work_directory/duplicate-eligibility.stderr"; then
    printf 'the duplicate eligibility refusal lost its reason\n' >&2
    exit 1
fi
# A manifest reaches a bundle directory by routes the builder never ran, so
# each eligibility refusal is exercised again against an assembled bundle:
# the manifest is copied in and its digest recomputed into bundle-manifest.tsv,
# which leaves every other claim consistent and the eligibility grammar the
# one thing the verification meets.
plant_manifest() {
    plant_bundle=$1
    plant_source=$2
    cp "$plant_source" "$deployment_root/$plant_bundle/artifact-manifest.tsv"
    planted_digest=$(sha256sum \
        "$deployment_root/$plant_bundle/artifact-manifest.tsv" | cut -d ' ' -f 1)
    awk -F'\t' -v OFS='\t' -v digest="$planted_digest" '
        $1 == "artifact-manifest.tsv" { $2 = digest }
        { print }' "$deployment_root/$plant_bundle/bundle-manifest.tsv" \
        >"$deployment_root/$plant_bundle/bundle-manifest.tsv.new"
    mv "$deployment_root/$plant_bundle/bundle-manifest.tsv.new" \
        "$deployment_root/$plant_bundle/bundle-manifest.tsv"
}
"$activator" bundle-natural "$deployment_root" >/dev/null
plant_manifest bundle-third "$diagnostic_manifest"
if "$activator" bundle-third "$deployment_root" \
    >/dev/null 2>"$work_directory/diagnostic-activate.stderr"; then
    printf 'a diagnostic manifest activated\n' >&2
    exit 1
fi
if ! grep -q 'names instrumentation pipeline-census-v3; a bundle carries serving builds alone' \
    "$work_directory/diagnostic-activate.stderr"; then
    printf 'the diagnostic activation refusal lost its reason\n' >&2
    exit 1
fi
report diagnostic_build_refused accepted


# A merged router preset names one MCP configuration per web section. The
# configuration is session state -- its contents name the state directory, the
# broker signing key, and the per-profile budgets -- so the bundle records the
# path and the digest rather than copying the file, and verification compares
# that record against the preset alone. Reading the named files at resolution
# would refuse every bundle on a machine that never armed the web lane, which
# turns a web-lane concern into an outage across the whole roster.
merged_configuration=$work_directory/web-open.json
printf '{"mcpServers":{"web":{"command":"python3"}}}\n' >"$merged_configuration"
merged_preset=$work_directory/router-presets-merged.ini
{
    printf '# qwen_web_sections=web-open\n'
    printf '[qwen-2b]\nLLAMA_ARG_MODEL = %s/qwen-2b.gguf\nLLAMA_ARG_CTX_CHECKPOINTS = 0\n\n' \
        "$model_root"
    printf '[web-open]\nLLAMA_ARG_MODEL = %s/qwen-2b.gguf\nLLAMA_ARG_CTX_CHECKPOINTS = 0\n' \
        "$model_root"
    printf 'LLAMA_ARG_MCP_SERVERS_CONFIG = %s\n' "$merged_configuration"
} >"$merged_preset"
if ! QWEN_BUNDLE_ROUTER_PRESETS=$merged_preset "$builder" bundle-merged \
    "$forced_server" "$forced_manifest" "$zero_ledger" "$deployment_root" \
    >"$work_directory/merged-bundle.log" 2>"$work_directory/merged-bundle.err"; then
    printf 'a merged preset failed bundle assembly\n' >&2
    cat "$work_directory/merged-bundle.err" >&2
    exit 1
fi
merged_recorded=$(awk -F'\t' '$1 == "web-open" { print $2 "\t" $3 }' \
    "$deployment_root/bundle-merged/web-mcp-manifest.tsv")
if [ "$merged_recorded" != "$merged_configuration	$(sha256sum -- \
    "$merged_configuration" | cut -d ' ' -f 1)" ]; then
    printf 'the bundle recorded no MCP configuration identity for web-open\n' >&2
    exit 1
fi
if [ -e "$deployment_root/bundle-merged/web-open.json" ]; then
    printf 'the bundle copied a session-state configuration into its own tree\n' >&2
    exit 1
fi
# The record binds the preset, so a configuration path that moved between
# assembly and activation is a preset the bundle no longer describes.
awk -F'\t' -v OFS='\t' '
    $1 == "web-open" { $2 = "/nonexistent/web-open.json" }
    { print }' "$deployment_root/bundle-merged/web-mcp-manifest.tsv" \
    >"$work_directory/mcp-drift.tsv"
cp "$work_directory/mcp-drift.tsv" \
    "$deployment_root/bundle-merged/web-mcp-manifest.tsv"
drift_digest=$(sha256sum "$deployment_root/bundle-merged/web-mcp-manifest.tsv" |
    cut -d ' ' -f 1)
awk -F'\t' -v OFS='\t' -v digest="$drift_digest" '
    $1 == "web-mcp-manifest.tsv" { $2 = digest }
    { print }' "$deployment_root/bundle-merged/bundle-manifest.tsv" \
    >"$work_directory/merged-manifest.tsv"
cp "$work_directory/merged-manifest.tsv" \
    "$deployment_root/bundle-merged/bundle-manifest.tsv"
if "$activator" bundle-merged "$deployment_root" \
    >/dev/null 2>"$work_directory/merged-drift.stderr"; then
    printf 'a web MCP record diverging from its preset activated\n' >&2
    exit 1
fi
if ! grep -q 'records configurations the bundled router preset does not name' \
    "$work_directory/merged-drift.stderr"; then
    printf 'the MCP record refusal lost its reason\n' >&2
    exit 1
fi
report bundle_records_web_mcp_configurations accepted


# A bundle whose router preset names no web section carries no MCP record, and
# every bundle assembled before the merged preset is that shape: their presets
# carry no `# qwen_web_sections=` marker at all. Requiring the record of every
# bundle refused the whole roster on the appliance active deployment and left
# it serving through recovery mode, so a marker-free bundle verifies with zero
# web-mcp rows and a marker-carrying one requires exactly one.
marker_free_preset=$work_directory/router-presets-marker-free.ini
printf '[qwen-2b]\nLLAMA_ARG_MODEL = %s/qwen-2b.gguf\nLLAMA_ARG_CTX_CHECKPOINTS = 0\n' \
    "$model_root" >"$marker_free_preset"
if ! QWEN_BUNDLE_ROUTER_PRESETS=$marker_free_preset "$builder" bundle-marker-free \
    "$forced_server" "$forced_manifest" "$zero_ledger" "$deployment_root" \
    >"$work_directory/marker-free.log" 2>"$work_directory/marker-free.err"; then
    printf 'a preset carrying no web section marker failed bundle assembly\n' >&2
    cat "$work_directory/marker-free.err" >&2
    exit 1
fi
if [ -e "$deployment_root/bundle-marker-free/web-mcp-manifest.tsv" ]; then
    printf 'a marker-free bundle carries a web MCP record\n' >&2
    exit 1
fi
if ! "$activator" bundle-marker-free "$deployment_root" >/dev/null; then
    printf 'a marker-free bundle failed activation\n' >&2
    exit 1
fi
# A bundle assembled before this lane carries no web-mcp-manifest.tsv row at
# all, which is the exact shape natural-boundary-13d05a0-r2 refused under.
grep -v '^web-mcp-manifest\.tsv	' \
    "$deployment_root/bundle-marker-free/bundle-manifest.tsv" \
    >"$work_directory/legacy-manifest.tsv"
cp "$work_directory/legacy-manifest.tsv" \
    "$deployment_root/bundle-marker-free/bundle-manifest.tsv"
if ! "$verifier" "$deployment_root" bundle-marker-free \
    >/dev/null 2>"$work_directory/legacy.stderr"; then
    printf 'a bundle predating the web MCP record failed verification\n' >&2
    cat "$work_directory/legacy.stderr" >&2
    exit 1
fi
# The marker is what requires the record, so a marker-carrying bundle whose
# manifest lost the row refuses rather than serving a preset the bundle no
# longer describes.
awk -F'\t' -v OFS='\t' '
    $1 == "web-mcp-manifest.tsv" { $2 = "-" }
    { print }' "$deployment_root/bundle-merged/bundle-manifest.tsv" \
    >"$work_directory/merged-without-record.tsv"
cp "$work_directory/merged-without-record.tsv" \
    "$deployment_root/bundle-merged/bundle-manifest.tsv"
if "$verifier" "$deployment_root" bundle-merged \
    >/dev/null 2>"$work_directory/merged-without-record.stderr"; then
    printf 'a marker-carrying bundle verified without its MCP record\n' >&2
    exit 1
fi
if ! grep -q 'names web section web-open and its manifest records no web-mcp-manifest.tsv' \
    "$work_directory/merged-without-record.stderr"; then
    printf 'the missing-record refusal lost its reason\n' >&2
    cat "$work_directory/merged-without-record.stderr" >&2
    exit 1
fi
# A record on a preset that names no web section claims a grant the marker
# withholds, so assembly refuses it too.
smuggled_preset=$work_directory/router-presets-smuggled.ini
{
    printf '[qwen-2b]\nLLAMA_ARG_MODEL = %s/qwen-2b.gguf\n' "$model_root"
    printf 'LLAMA_ARG_CTX_CHECKPOINTS = 0\n'
    printf 'LLAMA_ARG_MCP_SERVERS_CONFIG = %s\n' "$merged_configuration"
} >"$smuggled_preset"
if QWEN_BUNDLE_ROUTER_PRESETS=$smuggled_preset "$builder" bundle-smuggled \
    "$forced_server" "$forced_manifest" "$zero_ledger" "$deployment_root" \
    >/dev/null 2>"$work_directory/smuggled.stderr"; then
    printf 'a preset carrying an MCP key under no web section marker assembled\n' >&2
    exit 1
fi
if ! grep -q 'head marker names no web section' "$work_directory/smuggled.stderr"; then
    printf 'the unmarked MCP key refusal lost its reason\n' >&2
    cat "$work_directory/smuggled.stderr" >&2
    exit 1
fi
report web_mcp_record_follows_the_marker accepted

# The image server rides inside the same per-section configuration, so the
# record gains a column rather than a file and the preset own
# `# qwen_image_profile=` marker decides what it reads. Verification compares
# the two without opening a configuration, for the reason it compares the
# digest against the preset rather than the state directory.
imaged_configuration=$work_directory/web-open-image.json
cat >"$imaged_configuration" <<'IMAGE_CONFIGURATION'
{
  "mcpServers": {
    "web": {"command": "python3"},
    "image": {
      "command": "python3",
      "timeout_ms": 360000,
      "args": ["server.py"],
      "env": {
        "QWEN_IMAGE_LANGUAGE_PROFILE": "web-open",
        "QWEN_IMAGE_PROFILE": "image-sdxs-512-a",
        "QWEN_IMAGE_TOKEN_KEY_FILE": "/nonexistent/token.key",
        "QWEN_IMAGE_STATE_DIR": "/nonexistent/images",
        "QWEN_IMAGE_SERVICE_SOCKET": "/nonexistent/images/image.sock",
        "QWEN_IMAGE_PROFILES_JSON": "/nonexistent/image-parameters.json",
        "QWEN_IMAGE_MCP_TIMEOUT_S": "360"
      }
    }
  }
}
IMAGE_CONFIGURATION
imaged_preset=$work_directory/router-presets-imaged.ini
{
    printf '# qwen_web_sections=web-open\n'
    printf '# qwen_image_profile=image-sdxs-512-a\n'
    printf '[qwen-2b]\nLLAMA_ARG_MODEL = %s/qwen-2b.gguf\nLLAMA_ARG_CTX_CHECKPOINTS = 0\n\n' \
        "$model_root"
    printf '[web-open]\nLLAMA_ARG_MODEL = %s/qwen-2b.gguf\nLLAMA_ARG_CTX_CHECKPOINTS = 0\n' \
        "$model_root"
    printf 'LLAMA_ARG_MCP_SERVERS_CONFIG = %s\n' "$imaged_configuration"
} >"$imaged_preset"
if ! QWEN_BUNDLE_ROUTER_PRESETS=$imaged_preset "$builder" bundle-imaged \
    "$forced_server" "$forced_manifest" "$zero_ledger" "$deployment_root" \
    >"$work_directory/imaged-bundle.log" 2>"$work_directory/imaged-bundle.err"; then
    printf 'a preset carrying the image marker failed bundle assembly\n' >&2
    cat "$work_directory/imaged-bundle.err" >&2
    exit 1
fi
imaged_recorded=$(awk -F'\t' '$1 == "web-open" { print $4 }' \
    "$deployment_root/bundle-imaged/web-mcp-manifest.tsv")
if [ "$imaged_recorded" != image ]; then
    printf 'the bundle recorded image_server %s for a section arming a generation\n' \
        "${imaged_recorded:--}" >&2
    exit 1
fi
if ! "$activator" bundle-imaged "$deployment_root" >/dev/null; then
    printf 'a bundle carrying the image marker failed activation\n' >&2
    exit 1
fi
# The marker and the column are one claim, so a preset whose marker was
# withheld after assembly refuses rather than serving a configuration that
# still arms the runtime.
sed 's/^# qwen_image_profile=image-sdxs-512-a$/# qwen_image_profile=-/' \
    "$deployment_root/bundle-imaged/router-presets.ini" \
    >"$work_directory/imaged-unmarked.ini"
cp "$work_directory/imaged-unmarked.ini" \
    "$deployment_root/bundle-imaged/router-presets.ini"
unmarked_digest=$(sha256sum "$deployment_root/bundle-imaged/router-presets.ini" |
    cut -d ' ' -f 1)
awk -F'\t' -v OFS='\t' -v digest="$unmarked_digest" '
    $1 == "router-presets.ini" { $2 = digest }
    { print }' "$deployment_root/bundle-imaged/bundle-manifest.tsv" \
    >"$work_directory/imaged-manifest.tsv"
cp "$work_directory/imaged-manifest.tsv" \
    "$deployment_root/bundle-imaged/bundle-manifest.tsv"
if "$verifier" "$deployment_root" bundle-imaged \
    >/dev/null 2>"$work_directory/imaged-unmarked.stderr"; then
    printf 'a bundle recording an image server verified under a withheld marker\n' >&2
    exit 1
fi
if ! grep -q 'records image_server image for web-open where the preset marker reads -' \
    "$work_directory/imaged-unmarked.stderr"; then
    printf 'the withheld-marker refusal lost its reason\n' >&2
    cat "$work_directory/imaged-unmarked.stderr" >&2
    exit 1
fi
# A marker naming an image profile over a preset holding no web section claims
# a grant no section carries, so assembly refuses it.
image_only_preset=$work_directory/router-presets-image-only.ini
{
    printf '# qwen_image_profile=image-sdxs-512-a\n'
    printf '[qwen-2b]\nLLAMA_ARG_MODEL = %s/qwen-2b.gguf\nLLAMA_ARG_CTX_CHECKPOINTS = 0\n' \
        "$model_root"
} >"$image_only_preset"
if QWEN_BUNDLE_ROUTER_PRESETS=$image_only_preset "$builder" bundle-image-only \
    "$forced_server" "$forced_manifest" "$zero_ledger" "$deployment_root" \
    >/dev/null 2>"$work_directory/image-only.stderr"; then
    printf 'a preset arming an image lane over no web section assembled\n' >&2
    exit 1
fi
if ! grep -q 'names image profile image-sdxs-512-a and its head marker names no web section' \
    "$work_directory/image-only.stderr"; then
    printf 'the sectionless image lane refusal lost its reason\n' >&2
    cat "$work_directory/image-only.stderr" >&2
    exit 1
fi
report bundle_records_the_image_server accepted

# The grant binds the generation to the section that proposed it, so a
# configuration whose QWEN_IMAGE_LANGUAGE_PROFILE names one section reached
# through a preset naming another is a stale or copied binding: assembly
# refuses it even though QWEN_IMAGE_PROFILE alone still matches the preset
# marker, because qwen-capacity-policy.sh rejoins the language profile to the
# containing section at launch and would refuse the same bundle after it
# verified and activated.
mismatched_preset=$work_directory/router-presets-language-mismatch.ini
{
    printf '# qwen_web_sections=web-other\n'
    printf '# qwen_image_profile=image-sdxs-512-a\n'
    printf '[qwen-2b]\nLLAMA_ARG_MODEL = %s/qwen-2b.gguf\nLLAMA_ARG_CTX_CHECKPOINTS = 0\n\n' \
        "$model_root"
    printf '[web-other]\nLLAMA_ARG_MODEL = %s/qwen-2b.gguf\nLLAMA_ARG_CTX_CHECKPOINTS = 0\n' \
        "$model_root"
    printf 'LLAMA_ARG_MCP_SERVERS_CONFIG = %s\n' "$imaged_configuration"
} >"$mismatched_preset"
if QWEN_BUNDLE_ROUTER_PRESETS=$mismatched_preset "$builder" \
    bundle-language-mismatch "$forced_server" "$forced_manifest" \
    "$zero_ledger" "$deployment_root" \
    >/dev/null 2>"$work_directory/language-mismatch.stderr"; then
    printf 'a section reaching an image server bound to another section assembled\n' >&2
    exit 1
fi
if ! grep -q 'carries an image server bound to language profile web-open' \
    "$work_directory/language-mismatch.stderr"; then
    printf 'the language-profile mismatch refusal lost its reason\n' >&2
    cat "$work_directory/language-mismatch.stderr" >&2
    exit 1
fi
report bundle_rejects_a_stale_image_language_profile accepted

# A present serving_eligible row carrying an empty value declares nothing and
# is read as its own spelling rather than as the absent legacy declaration,
# at assembly and against an assembled bundle.
empty_eligibility_manifest=$work_directory/manifest-empty-eligibility.tsv
{
    printf 'serving_eligible\t\n'
    cat "$forced_manifest"
} >"$empty_eligibility_manifest"
if "$builder" bundle-empty-eligibility "$forced_server" \
    "$empty_eligibility_manifest" "$zero_ledger" "$deployment_root" \
    >/dev/null 2>"$work_directory/empty-eligibility.stderr"; then
    printf 'an empty serving_eligible value assembled into a bundle\n' >&2
    exit 1
fi
if ! grep -q 'declares serving_eligible <empty>; a bundle carries serving builds alone' \
    "$work_directory/empty-eligibility.stderr"; then
    printf 'the empty eligibility refusal lost its observed value\n' >&2
    exit 1
fi
plant_manifest bundle-third "$empty_eligibility_manifest"
if "$activator" bundle-third "$deployment_root" \
    >/dev/null 2>"$work_directory/empty-eligibility-activate.stderr"; then
    printf 'an empty serving_eligible value activated\n' >&2
    exit 1
fi
if ! grep -q 'declares serving_eligible <empty>; a bundle carries serving builds alone' \
    "$work_directory/empty-eligibility-activate.stderr"; then
    printf 'the empty eligibility activation refusal lost its observed value\n' >&2
    exit 1
fi
report empty_eligibility_refused accepted

# Deleting the eligibility row from a diagnostic manifest leaves the
# instrumentation it was built with, and that row alone refuses the bundle at
# assembly and at verification.
instrumentation_only_manifest=$work_directory/manifest-instrumentation-only.tsv
{
    printf 'instrumentation\tpipeline-census-v3\nbuild_role\tdiagnostic\n'
    cat "$forced_manifest"
} >"$instrumentation_only_manifest"
if "$builder" bundle-instrumentation "$forced_server" \
    "$instrumentation_only_manifest" "$zero_ledger" "$deployment_root" \
    >/dev/null 2>"$work_directory/instrumentation-only.stderr"; then
    printf 'an instrumentation row with no eligibility row assembled\n' >&2
    exit 1
fi
if ! grep -q 'names instrumentation pipeline-census-v3; a bundle carries serving builds alone' \
    "$work_directory/instrumentation-only.stderr"; then
    printf 'the instrumentation-only refusal lost its instrumentation\n' >&2
    exit 1
fi
plant_manifest bundle-third "$instrumentation_only_manifest"
if "$verifier" "$deployment_root" bundle-third \
    >/dev/null 2>"$work_directory/instrumentation-only-verify.stderr"; then
    printf 'an instrumentation row with no eligibility row verified\n' >&2
    exit 1
fi
if ! grep -q 'names instrumentation pipeline-census-v3; a bundle carries serving builds alone' \
    "$work_directory/instrumentation-only-verify.stderr"; then
    printf 'the instrumentation-only verification refusal lost its instrumentation\n' >&2
    exit 1
fi
report instrumentation_without_eligibility_refused accepted

# An instrumented build that also declares itself servable is refused on the
# instrumentation, so the eligibility spelling never admits the diagnostic.
instrumented_servable_manifest=$work_directory/manifest-instrumented-servable.tsv
{
    printf 'instrumentation\tpipeline-census-v3\nserving_eligible\tyes\n'
    cat "$forced_manifest"
} >"$instrumented_servable_manifest"
if "$builder" bundle-instrumented-servable "$forced_server" \
    "$instrumented_servable_manifest" "$zero_ledger" "$deployment_root" \
    >/dev/null 2>"$work_directory/instrumented-servable.stderr"; then
    printf 'an instrumented manifest declaring serving_eligible yes assembled\n' >&2
    exit 1
fi
if ! grep -q 'names instrumentation pipeline-census-v3; a bundle carries serving builds alone' \
    "$work_directory/instrumented-servable.stderr"; then
    printf 'the instrumented servable refusal lost its instrumentation\n' >&2
    exit 1
fi
report instrumented_servable_refused accepted

printf 'deployment_bundle=accepted checks=%s\n' "$checks"
