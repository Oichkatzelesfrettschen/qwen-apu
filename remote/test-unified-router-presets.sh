#!/bin/sh
set -eu

# One router serves the whole roster, so the roster preset holds the registry
# sections and the validator-gated web sections in one file. These checks run
# against the checked-in registry and a fabricated model root, because the
# section arithmetic is the claim: thirteen servable registry rows and two
# draft pairs make fifteen tool-free sections, and web-open is the one ledger
# row carrying an execution grant, so the armed generation writes sixteen.
#
# The refusals are what keep the merge safe. An ordinary section carrying
# LLAMA_ARG_MCP_SERVERS_CONFIG would reach the network under rules the launch
# validated as tool-free; a web section whose ledger row has moved to refused
# would serve a persisted grant the ledger revoked. The capacity policy states
# both, which is why they are measured through the real policy rather than by
# grepping the generated file.

if [ "$#" -ne 0 ]; then
    printf 'usage: %s\n' "$0" >&2
    exit 2
fi

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
repository_root=$(CDPATH='' cd -- "$script_directory/.." && pwd)
builder=$script_directory/build-router-presets.sh
policy=$script_directory/qwen-capacity-policy.sh
fake_server=$script_directory/test-fixtures/fake-llama-server.sh
bundle_ledger_check=$script_directory/verify-bundle-preset-ledger.sh
failures=0

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT INT TERM

report() {
    printf '%s=%s\n' "$1" "$2"
    [ "$2" = ok ] || failures=$((failures + 1))
}

# A fabricated model root carrying an empty file at every registry path, and a
# projector beside every vision row. The generator tests for a regular file
# rather than reading it, so an empty file exercises the whole emission without
# a weight on disk.
model_root=$work/models
awk -F'\t' '!/^#/ && NF { print $3 }' "$script_directory/models.tsv" |
    while IFS= read -r model_file; do
        mkdir -p "$model_root/$(dirname -- "$model_file")"
        : >"$model_root/$model_file"
    done
awk -F'\t' '!/^#/ && NF && $11 == "required" { print $3 }' \
    "$script_directory/models.tsv" |
    while IFS= read -r model_file; do
        : >"$model_root/$(dirname -- "$model_file")/mmproj-F16.gguf"
    done

# An empty checkpoint ledger admits 0 for every row, which keeps the
# checkpoint-semantics gate off the fake server and leaves these checks
# measuring the preset shape rather than the build declaration.
ctx_ledger=$work/ctx-checkpoints.tsv
printf '# this fixture admits no checkpoint count\n' >"$ctx_ledger"

# The checked-in quarantine registry is the exclusion authority these counts
# rest on: two registry rows carry a model-scope record, so thirteen of the
# fifteen servable rows reach the file.
quarantine_registry=$script_directory/quarantine.tsv
fake_icd=$work/radeon_icd.x86_64.json
: >"$fake_icd"
mcp_server_program=$script_directory/web-mcp/server.py
# The generated preset binds the path and the digest of the ledger it read, so
# the revocation arms below edit a copy the preset names rather than the
# checked-in file.
web_profiles=$work/web-profiles.tsv
cp -- "$script_directory/web-profiles.tsv" "$web_profiles"
token_key_file=$work/token.key
printf 'fixture\n' >"$token_key_file"
chmod 600 "$token_key_file"

# The checked-in remote/image-profiles.tsv carries one validator-gated row, so a
# generation that arms the web lane alone names an all-refused ledger the way
# remote/test-web-presets.sh does; the image arms below name the gated one and
# supply the five image MCP inputs it requires.
image_profiles_refused=$work/image-profiles-refused.tsv
cat >"$image_profiles_refused" <<'EOF'
# profile_id	model_id	placement	width	height	steps	sampler	cfg	max_steps	max_dimension	timeout_s	execution_policy	validated_evidence	review_model
image-fixture-refused	sdxs-512	A	512	512	1	euler	1.0	4	512	300	refused	-	-
EOF
# remote/image-registry.sh validates the four image authorities whole, so the
# fixture ledger names the checked-in bundle and differs from it in
# execution_policy and review_model alone.
image_profiles_gated=$work/image-profiles-gated.tsv
printf 'image-fixture-a\tsdxs-512\tA\t512\t512\t1\teuler\t1.0\t4\t512\t300\tvalidator-gated\tevidence/image-appliance/design.md\t-\n' \
    >"$image_profiles_gated"
image_profiles_reviewed=$work/image-profiles-reviewed.tsv
printf 'image-fixture-a\tsdxs-512\tA\t512\t512\t1\teuler\t1.0\t4\t512\t300\tvalidator-gated\tevidence/image-appliance/design.md\tlfm25-vl-16b\n' \
    >"$image_profiles_reviewed"
image_mcp_server_program=$work/image-mcp-server.py
: >"$image_mcp_server_program"
image_profiles_json=$work/image-parameters.json
printf '{}\n' >"$image_profiles_json"

build_presets() {
    build_output=$1
    shift
    QWEN_MODEL_ROOT=$model_root \
    QWEN_QUARANTINE_REGISTRY=$quarantine_registry \
    QWEN_QUARANTINE_REASONS=$repository_root/evidence/quarantine \
    QWEN_CTX_CHECKPOINT_LEDGER=$ctx_ledger \
    QWEN_IMAGE_PROFILES=$image_profiles_refused \
        env "$@" "$builder" "$build_output"
}

section_count() {
    grep -c '^\[' "$1"
}

# Without the authorizer marker the generator emits the registry sections alone
# and names the ledger it withheld, because an execution grant is a security
# boundary and no default admits one.
tool_free=$work/tool-free.ini
if build_presets "$tool_free" QWEN_WEB_AUTHORIZER_READY=0 \
    >"$work/tool-free.log" 2>"$work/tool-free.err"; then
    if [ "$(section_count "$tool_free")" -eq 15 ] &&
        grep -qx '# qwen_web_sections=-' "$tool_free" &&
        ! grep -q 'LLAMA_ARG_MCP_SERVERS_CONFIG' "$tool_free" &&
        grep -q 'web_sections=withheld reason=authorizer_absent' \
            "$work/tool-free.log"; then
        report tool_free_generation ok
    else
        report tool_free_generation failed
        printf 'sections=%s\n' "$(section_count "$tool_free")" >&2
        cat "$work/tool-free.log" >&2
    fi
else
    report tool_free_generation build_failed
    cat "$work/tool-free.err" >&2
fi

# The armed generation adds one section per validator-gated ledger row.
# web-open is the one checked-in row carrying that policy, so the file grows by
# exactly one section and that section carries the six tuple keys, the
# checkpoint count, and its own configuration.
merged=$work/merged.ini
if build_presets "$merged" QWEN_WEB_AUTHORIZER_READY=1 \
    "QWEN_WEB_MCP_SERVER=$mcp_server_program" \
    "QWEN_WEB_TOKEN_KEY_FILE=$token_key_file" \
    "QWEN_WEB_STATE_DIR=$work/web-mcp" "QWEN_WEB_PROFILES=$web_profiles" \
    >"$work/merged.log" 2>"$work/merged.err"; then
    merged_section_keys=$(awk '
        /^\[web-open\]/ { inside = 1; next }
        /^\[/ { inside = 0 }
        inside && /=/ {
            key = $0
            sub(/[[:space:]]*=.*$/, "", key)
            print key
        }
    ' "$merged" | LC_ALL=C sort | tr '\n' ' ')
    merged_expected='LLAMA_ARG_ALIAS LLAMA_ARG_BATCH LLAMA_ARG_CACHE_TYPE_K LLAMA_ARG_CACHE_TYPE_V LLAMA_ARG_CTX_CHECKPOINTS LLAMA_ARG_CTX_SIZE LLAMA_ARG_FLASH_ATTN LLAMA_ARG_MCP_SERVERS_CONFIG LLAMA_ARG_MODEL LLAMA_ARG_TAGS LLAMA_ARG_UBATCH '
    merged_config=$(sed -n 's/^LLAMA_ARG_MCP_SERVERS_CONFIG = //p' "$merged")
    if [ "$(section_count "$merged")" -eq 16 ] &&
        grep -qx '# qwen_web_sections=web-open' "$merged" &&
        [ "$merged_section_keys" = "$merged_expected" ] &&
        [ "$(grep -c 'LLAMA_ARG_MCP_SERVERS_CONFIG' "$merged")" -eq 1 ] &&
        [ -f "$merged_config" ] &&
        grep -q '"QWEN_WEB_PROFILE": "web-open"' "$merged_config"; then
        report merged_generation ok
    else
        report merged_generation failed
        printf 'sections=%s keys=%s\n' "$(section_count "$merged")" \
            "$merged_section_keys" >&2
        cat "$work/merged.log" >&2
    fi
else
    report merged_generation build_failed
    cat "$work/merged.err" >&2
fi

# The merged file names the ledger it was generated from, so a launch rejoins
# every named section to that exact file.
if grep -qx "# qwen_web_profiles_path=$web_profiles" "$merged" &&
    grep -qx "# qwen_web_profiles_sha256=$(sha256sum -- "$web_profiles" |
        cut -d' ' -f1)" "$merged" &&
    grep -qx '# qwen_web_provider=searxng' "$merged"; then
    report merged_ledger_identity ok
else
    report merged_ledger_identity failed
    sed -n '1,8p' "$merged" >&2
fi

# An all-refused image ledger arms no generation under any setting, so the
# merged file carries the web server alone and its markers say so.
if ! grep -rq '"image"' "$work"/web-mcp-configs-* 2>/dev/null &&
    grep -qx '# qwen_image_profile=-' "$merged" &&
    grep -qx '# qwen_image_profiles_path=-' "$merged" &&
    grep -qx '# qwen_image_review_section=-' "$merged"; then
    report image_server_withheld_under_refused_ledger ok
else
    report image_server_withheld_under_refused_ledger failed
    sed -n '1,12p' "$merged" >&2
fi

# A validator-gated image row adds one `image` server to the web section's own
# configuration, bound to that section as the language profile. The
# `mcpServers` object then holds two members, so the file has to parse.
imaged=$work/imaged.ini
if build_presets "$imaged" QWEN_WEB_AUTHORIZER_READY=1 \
    "QWEN_WEB_MCP_SERVER=$mcp_server_program" \
    "QWEN_WEB_TOKEN_KEY_FILE=$token_key_file" \
    "QWEN_WEB_STATE_DIR=$work/web-mcp" "QWEN_WEB_PROFILES=$web_profiles" \
    "QWEN_IMAGE_PROFILES=$image_profiles_gated" \
    "QWEN_IMAGE_MCP_SERVER=$image_mcp_server_program" \
    "QWEN_IMAGE_TOKEN_KEY_FILE=$token_key_file" \
    "QWEN_IMAGE_STATE_DIR=$work/image-state" \
    "QWEN_IMAGE_SERVICE_SOCKET=$work/image-state/image-service.sock" \
    "QWEN_IMAGE_PROFILES_JSON=$image_profiles_json" \
    >"$work/imaged.log" 2>"$work/imaged.err"; then
    imaged_config=$(sed -n 's/^LLAMA_ARG_MCP_SERVERS_CONFIG = //p' "$imaged")
    outcome=ok
    [ "$(section_count "$imaged")" -eq 16 ] || outcome=wrong_section_count
    grep -qx '# qwen_image_profile=image-fixture-a' "$imaged" ||
        outcome=profile_marker_absent
    grep -qx "# qwen_image_profiles_path=$image_profiles_gated" "$imaged" ||
        outcome=ledger_marker_absent
    grep -qx '# qwen_image_review_section=-' "$imaged" ||
        outcome=review_marker_set
    python3 -c '
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    servers = json.load(handle)["mcpServers"]
image = servers["image"]["env"]
assert set(servers) == {"web", "image"}, sorted(servers)
assert image["QWEN_IMAGE_PROFILE"] == "image-fixture-a", image
assert image["QWEN_IMAGE_LANGUAGE_PROFILE"] == "web-open", image
' "$imaged_config" >/dev/null 2>>"$work/imaged.err" || outcome=configuration_wrong
    report image_server_emitted_into_the_web_section "$outcome"
else
    report image_server_emitted_into_the_web_section build_failed
    cat "$work/imaged.err" >&2
fi

# resolve_image_profile runs ahead of the web loop and used to leave
# image_profile_id armed whether or not any web row went on to emit, so a
# ledger whose sole validator-gated web row is refused (or has its weights
# absent) would have landed a preset naming an image profile over an empty
# `# qwen_web_sections=-` list -- exactly the combination
# qwen-capacity-policy.sh refuses at launch. The generator refuses it here
# instead of replacing the last known-good preset.
web_profiles_refused_row=$work/web-profiles-refused-row.tsv
awk -F'\t' -v OFS='\t' '$1 == "web-open" { $12 = "refused" } { print }' \
    "$web_profiles" >"$web_profiles_refused_row"
if build_presets "$work/image-without-web.ini" QWEN_WEB_AUTHORIZER_READY=1 \
    "QWEN_WEB_MCP_SERVER=$mcp_server_program" \
    "QWEN_WEB_TOKEN_KEY_FILE=$token_key_file" \
    "QWEN_WEB_STATE_DIR=$work/web-mcp" \
    "QWEN_WEB_PROFILES=$web_profiles_refused_row" \
    "QWEN_IMAGE_PROFILES=$image_profiles_gated" \
    "QWEN_IMAGE_MCP_SERVER=$image_mcp_server_program" \
    "QWEN_IMAGE_TOKEN_KEY_FILE=$token_key_file" \
    "QWEN_IMAGE_STATE_DIR=$work/image-state" \
    "QWEN_IMAGE_SERVICE_SOCKET=$work/image-state/image-service.sock" \
    "QWEN_IMAGE_PROFILES_JSON=$image_profiles_json" \
    >"$work/image-without-web.log" 2>"$work/image-without-web.err"; then
    report image_marker_refused_over_empty_web_section_list admitted
elif grep -q 'is armed and no web section emitted' \
    "$work/image-without-web.err"; then
    report image_marker_refused_over_empty_web_section_list ok
else
    report image_marker_refused_over_empty_web_section_list wrong_reason
    cat "$work/image-without-web.err" >&2
fi

# The reviewer is a roster section rather than a section of its own, and the
# marker is written only where remote/validated-tuples.tsv carries a validated
# router-child tuple with the projector loaded. The checked-in ledger carries
# none for lfm25-vl-16b at that geometry, so the generation lane still arms and
# the review claim is withheld beside the probe that would measure it.
reviewed=$work/reviewed.ini
if build_presets "$reviewed" QWEN_WEB_AUTHORIZER_READY=1 \
    "QWEN_WEB_MCP_SERVER=$mcp_server_program" \
    "QWEN_WEB_TOKEN_KEY_FILE=$token_key_file" \
    "QWEN_WEB_STATE_DIR=$work/web-mcp" "QWEN_WEB_PROFILES=$web_profiles" \
    "QWEN_IMAGE_PROFILES=$image_profiles_reviewed" \
    "QWEN_IMAGE_MCP_SERVER=$image_mcp_server_program" \
    "QWEN_IMAGE_TOKEN_KEY_FILE=$token_key_file" \
    "QWEN_IMAGE_STATE_DIR=$work/image-state" \
    "QWEN_IMAGE_SERVICE_SOCKET=$work/image-state/image-service.sock" \
    "QWEN_IMAGE_PROFILES_JSON=$image_profiles_json" \
    >"$work/reviewed.log" 2>"$work/reviewed.err"; then
    outcome=ok
    grep -qx '# qwen_image_review_model=lfm25-vl-16b' "$reviewed" ||
        outcome=review_model_marker_absent
    [ "$(section_count "$reviewed")" -eq 16 ] || outcome=review_section_emitted
    if grep -qx '# qwen_image_review_section=lfm25-vl-16b' "$reviewed"; then
        # A tree whose validated-tuple ledger has since gained that arm reads
        # the marker set, and the roster is what serves it either way.
        grep -q '^\[lfm25-vl-16b\]$' "$reviewed" || outcome=reviewer_absent
    else
        grep -qx '# qwen_image_review_section=-' "$reviewed" ||
            outcome=review_marker_malformed
        grep -q 'remote/probe-depth-projector.sh lfm25-vl-16b' \
            "$work/reviewed.err" || outcome=probe_command_unreported
    fi
    report image_review_section_names_a_roster_row "$outcome"
else
    report image_review_section_names_a_roster_row build_failed
    cat "$work/reviewed.err" >&2
fi

run_policy() {
    policy_preset=$1
    policy_ledger=${2:-$web_profiles}
    QWEN_MODEL_ROOT=$model_root \
    QWEN_QUARANTINE_REGISTRY=$quarantine_registry \
    QWEN_CTX_CHECKPOINT_LEDGER=$ctx_ledger \
    QWEN_WEB_PROFILES=$policy_ledger \
    QWEN_WEB_AUTHORIZER_READY=1 \
    QWEN_RADV_ICD=$fake_icd \
    QWEN_POLICY_TEST_OUTPUT=$work/policy.out \
    QWEN_ROUTER=1 QWEN_ROUTER_PRESETS=$policy_preset QWEN_ROUTER_MAX=1 \
        "$policy" "$fake_server" \
        "$model_root/Qwen3.8-2B-Distill-GGUF/Qwen3.8-2B-Q4_K_M.gguf" 8192 18080
}

# The policy is the authority on a complete admitted tuple, and the merged file
# puts two section shapes in front of it: the registry rules for fifteen
# sections and the web rules for web-open.
if run_policy "$merged" >"$work/policy.log" 2>"$work/policy.err"; then
    report merged_preset_admitted ok
else
    report merged_preset_admitted failed
    cat "$work/policy.err" >&2
fi

# The merged preset is the first shape in which both the draft-pair ledger and
# the web profile ledger reach qwen-router-exec-guard.sh as real paths: a
# whole-file web preset left the draft-pair path `-` and a registry preset left
# the web path `-`. The policy run above execs the whole chain, so the argv the
# fake server recorded is what proves the guard admitted the pair rather than
# refusing one of them.
# The fake server records one argument per line, so the preset and the model
# limit are read as their own rows. QWEN_ROUTER_MAX stays 1: the merged file
# holds sixteen sections and the 4B alone peaks at 2029 MiB of a 2048 MiB
# carve-out, so a second resident child competes for a pool one model
# saturates.
if [ -r "$work/policy.out" ] &&
    grep -qxF -- 'argument=--models-preset' "$work/policy.out" &&
    grep -qxF -- "argument=$merged" "$work/policy.out" &&
    grep -qxF -- 'argument=--models-max' "$work/policy.out" &&
    grep -qxF -- 'argument=1' "$work/policy.out"; then
    report merged_preset_reaches_the_server ok
else
    report merged_preset_reaches_the_server failed
    [ -r "$work/policy.out" ] && cat "$work/policy.out" >&2
fi

# The guard is called directly with both ledgers present, because the shape is
# new and the refusal it exists for is a ledger replaced between validation and
# exec.
exec_guard=$script_directory/qwen-router-exec-guard.sh
guard_digest() {
    sha256sum -- "$1" | cut -d ' ' -f 1
}
if "$exec_guard" "$merged" "$(guard_digest "$merged")" \
    "$script_directory/models.tsv" "$(guard_digest "$script_directory/models.tsv")" \
    "$quarantine_registry" "$(guard_digest "$quarantine_registry")" \
    "$script_directory/draft-pairs.tsv" \
    "$(guard_digest "$script_directory/draft-pairs.tsv")" \
    "$web_profiles" "$(guard_digest "$web_profiles")" \
    "$ctx_ledger" "$(guard_digest "$ctx_ledger")" \
    - \
    true >"$work/guard.log" 2>"$work/guard.err"; then
    report exec_guard_admits_both_ledgers ok
else
    report exec_guard_admits_both_ledgers failed
    cat "$work/guard.err" >&2
fi
if "$exec_guard" "$merged" "$(guard_digest "$merged")" \
    "$script_directory/models.tsv" "$(guard_digest "$script_directory/models.tsv")" \
    "$quarantine_registry" "$(guard_digest "$quarantine_registry")" \
    "$script_directory/draft-pairs.tsv" \
    "$(guard_digest "$script_directory/draft-pairs.tsv")" \
    "$web_profiles" "$(guard_digest "$script_directory/models.tsv")" \
    "$ctx_ledger" "$(guard_digest "$ctx_ledger")" \
    - \
    true >"$work/guard-swap.log" 2>"$work/guard-swap.err"; then
    report exec_guard_web_ledger_swap_refused admitted
elif grep -q 'router web profile ledger identity changed' \
    "$work/guard-swap.err"; then
    report exec_guard_web_ledger_swap_refused ok
else
    report exec_guard_web_ledger_swap_refused wrong_reason
    cat "$work/guard-swap.err" >&2
fi

# The tool-free file is the same authority with an empty section list.
if run_policy "$tool_free" >"$work/policy-free.log" \
    2>"$work/policy-free.err"; then
    report tool_free_preset_admitted ok
else
    report tool_free_preset_admitted failed
    cat "$work/policy-free.err" >&2
fi

# An MCP configuration in a section the marker never named is the grant the
# merge exists to keep off the roster, so the policy refuses the file rather
# than serving fifteen tool-free rows and one that quietly is not.
smuggled=$work/smuggled.ini
awk -v configuration="$(sed -n 's/^LLAMA_ARG_MCP_SERVERS_CONFIG = //p' "$merged")" '
    { print }
    /^\[qwen38-2b-distill\]$/ {
        printf "LLAMA_ARG_MCP_SERVERS_CONFIG = %s\n", configuration
    }
' "$merged" >"$smuggled"
if run_policy "$smuggled" >"$work/smuggled.log" 2>"$work/smuggled.err"; then
    report ordinary_section_mcp_key_refused admitted
    cat "$work/smuggled.log" >&2
else
    if grep -q 'LLAMA_ARG_MCP_SERVERS_CONFIG outside the web section list' \
        "$work/smuggled.err"; then
        report ordinary_section_mcp_key_refused ok
    else
        report ordinary_section_mcp_key_refused wrong_reason
        cat "$work/smuggled.err" >&2
    fi
fi

# The image marker and the section's own configuration are one claim, so the
# policy reads both. The armed file passes with the image ledger the marker
# names, and a configuration whose image server survives a marker the generator
# withheld is the grant this rejoin exists to catch.
run_image_policy() {
    QWEN_MODEL_ROOT=$model_root \
    QWEN_QUARANTINE_REGISTRY=$quarantine_registry \
    QWEN_CTX_CHECKPOINT_LEDGER=$ctx_ledger \
    QWEN_WEB_PROFILES=$web_profiles \
    QWEN_WEB_AUTHORIZER_READY=1 \
    QWEN_RADV_ICD=$fake_icd \
    QWEN_POLICY_TEST_OUTPUT=$work/image-policy.out \
    QWEN_ROUTER=1 QWEN_ROUTER_PRESETS=$1 QWEN_ROUTER_MAX=1 \
        "$policy" "$fake_server" \
        "$model_root/Qwen3.8-2B-Distill-GGUF/Qwen3.8-2B-Q4_K_M.gguf" 8192 18080
}
if run_image_policy "$imaged" >"$work/image-policy.log" \
    2>"$work/image-policy.err"; then
    report imaged_preset_admitted ok
else
    report imaged_preset_admitted failed
    cat "$work/image-policy.err" >&2
fi

# The generation lane is the marker plus the configuration, so a preset whose
# marker was withheld refuses the section that still carries an image server.
unmarked=$work/unmarked.ini
sed 's|^# qwen_image_profile=image-fixture-a$|# qwen_image_profile=-|' \
    "$imaged" >"$unmarked"
if run_image_policy "$unmarked" >"$work/unmarked.log" 2>"$work/unmarked.err"; then
    report unmarked_image_server_refused admitted
elif grep -q 'carries an image server where the preset names no image profile' \
    "$work/unmarked.err"; then
    report unmarked_image_server_refused ok
else
    report unmarked_image_server_refused wrong_reason
    cat "$work/unmarked.err" >&2
fi

# A marker naming another profile than the one the child would arm is the same
# divergence read from the other side.
foreign=$work/foreign-image.ini
sed 's|^# qwen_image_profile=image-fixture-a$|# qwen_image_profile=image-fixture-b|' \
    "$imaged" >"$foreign"
if run_image_policy "$foreign" >"$work/foreign.log" 2>"$work/foreign.err"; then
    report foreign_image_profile_refused admitted
elif grep -q 'arms image profile image-fixture-a where the preset names image-fixture-b' \
    "$work/foreign.err"; then
    report foreign_image_profile_refused ok
else
    report foreign_image_profile_refused wrong_reason
    cat "$work/foreign.err" >&2
fi

# An image row moved to refused after generation revokes the lane, and the
# ledger digest the preset binds is what reads the edit first.
sed 's/\tvalidator-gated\t/\trefused\t/' "$image_profiles_gated" \
    >"$work/image-revoked.tsv"
mv -- "$work/image-revoked.tsv" "$image_profiles_gated"
if run_image_policy "$imaged" >"$work/image-revoked.log" \
    2>"$work/image-revoked.err"; then
    report revoked_image_ledger_refused admitted
elif grep -q 'image profile ledger identity changed' "$work/image-revoked.err"; then
    report revoked_image_ledger_refused ok
else
    report revoked_image_ledger_refused wrong_reason
    cat "$work/image-revoked.err" >&2
fi
rebound_image=$work/rebound-image.ini
sed "s|^# qwen_image_profiles_sha256=.*|# qwen_image_profiles_sha256=$(sha256sum -- "$image_profiles_gated" | cut -d' ' -f1)|" \
    "$imaged" >"$rebound_image"
if run_image_policy "$rebound_image" >"$work/image-rebound.log" \
    2>"$work/image-rebound.err"; then
    report revoked_image_row_refused admitted
elif grep -q 'carries execution_policy refused, and only validator-gated reaches a runtime' \
    "$work/image-rebound.err"; then
    report revoked_image_row_refused ok
else
    report revoked_image_row_refused wrong_reason
    cat "$work/image-rebound.err" >&2
fi

# A web section whose ledger row loses its execution grant is a persisted
# configuration the ledger no longer authorizes. The preset binds the ledger
# path and digest, so an edit refuses there first; the arm reads that refusal
# and then rewrites the recorded digest, which is what puts the rejoin by
# profile_id in front of the launch.
sed 's/^\(web-open\t.*\t\)validator-gated\(\tsearxng\)/\1refused\2/' \
    "$web_profiles" >"$work/revoked-ledger.tsv"
mv -- "$work/revoked-ledger.tsv" "$web_profiles"
if grep -q '^web-open.*	refused	searxng' "$web_profiles"; then
    if run_policy "$merged" >"$work/revoked.log" 2>"$work/revoked.err"; then
        report revoked_ledger_identity_refused admitted
    else
        if grep -q 'web profile ledger identity changed' "$work/revoked.err"; then
            report revoked_ledger_identity_refused ok
        else
            report revoked_ledger_identity_refused wrong_reason
            cat "$work/revoked.err" >&2
        fi
    fi
    rebound=$work/rebound.ini
    rebound_digest=$(sha256sum -- "$web_profiles" | cut -d' ' -f1)
    sed "s|^# qwen_web_profiles_sha256=.*|# qwen_web_profiles_sha256=$rebound_digest|" \
        "$merged" >"$rebound"
    if run_policy "$rebound" >"$work/rebound.log" 2>"$work/rebound.err"; then
        report revoked_web_section_refused admitted
    else
        if grep -q 'web preset section web-open carries ledger execution_policy refused' \
            "$work/rebound.err"; then
            report revoked_web_section_refused ok
        else
            report revoked_web_section_refused wrong_reason
            cat "$work/rebound.err" >&2
        fi
    fi
else
    report revoked_ledger_identity_refused ledger_edit_failed
    report revoked_web_section_refused ledger_edit_failed
fi

# A web profile the ledger no longer holds is the same revocation by removal,
# and every registry section of the merged file still passes beside it.
removed=$work/removed.ini
grep -v '^web-open	' "$web_profiles" >"$work/removed-ledger.tsv"
mv -- "$work/removed-ledger.tsv" "$web_profiles"
removed_digest=$(sha256sum -- "$web_profiles" | cut -d' ' -f1)
sed "s|^# qwen_web_profiles_sha256=.*|# qwen_web_profiles_sha256=$removed_digest|" \
    "$merged" >"$removed"
if run_policy "$removed" >"$work/removed.log" 2>"$work/removed.err"; then
    report removed_web_section_refused admitted
else
    if grep -q 'web preset section web-open names a profile the ledger' \
        "$work/removed.err"; then
        report removed_web_section_refused ok
    else
        report removed_web_section_refused wrong_reason
        cat "$work/removed.err" >&2
    fi
fi

# The deployment bundle binds every section to the checkpoint count of the
# model its LLAMA_ARG_MODEL resolves to, and a web section names its
# checkpoint file the way a registry section does.
if "$bundle_ledger_check" "$merged" "$ctx_ledger" \
    "$script_directory/models.tsv" >"$work/bundle.log" 2>"$work/bundle.err"; then
    if grep -q 'preset_ledger_agreement=accepted sections=16' "$work/bundle.log"; then
        report bundle_binds_web_sections ok
    else
        report bundle_binds_web_sections wrong_count
        cat "$work/bundle.log" >&2
    fi
else
    report bundle_binds_web_sections failed
    cat "$work/bundle.err" >&2
fi

# A count the bundled ledger never stated for that model refuses at assembly
# rather than serving, for a web section as much as a registry one.
drifted=$work/drifted.ini
sed '/^\[web-open\]/,/^$/s/^LLAMA_ARG_CTX_CHECKPOINTS = 0$/LLAMA_ARG_CTX_CHECKPOINTS = 2/' \
    "$merged" >"$drifted"
if "$bundle_ledger_check" "$drifted" "$ctx_ledger" \
    "$script_directory/models.tsv" >"$work/drift.log" 2>"$work/drift.err"; then
    report bundle_web_count_drift_refused admitted
else
    if grep -q 'preset section \[web-open\] carries checkpoint count 2' \
        "$work/drift.err"; then
        report bundle_web_count_drift_refused ok
    else
        report bundle_web_count_drift_refused wrong_reason
        cat "$work/drift.err" >&2
    fi
fi

# The Q4_K formulation release travels row to section to policy to guard, and
# each of the four rules is measured against the merged file the roster serves.
# The shipped registry releases none, so the generated preset carries no key and
# a smuggled one names a formulation the row never released.
q4k_smuggled=$work/q4k-smuggled.ini
awk '
    { print }
    /^\[qwen38-2b-distill\]$/ { print "LLAMA_ARG_VK_Q4K_VARIANT = e4-scale/4" }
' "$merged" >"$q4k_smuggled"
if run_policy "$q4k_smuggled" >"$work/q4k-smuggled.log" \
    2>"$work/q4k-smuggled.err"; then
    report q4k_unreleased_section_key_refused admitted
elif grep -q 'releases no Q4_K formulation' "$work/q4k-smuggled.err"; then
    report q4k_unreleased_section_key_refused ok
else
    report q4k_unreleased_section_key_refused wrong_reason
    cat "$work/q4k-smuggled.err" >&2
fi

# A registry releasing a formulation for one row is the release commit this
# plumbing exists for. The policy then requires the section key to equal the
# row and the build manifest to admit it, so the same preset is run against a
# build that declares the key and one that declares none.
q4k_registry=$work/q4k-models.tsv
awk -F'\t' 'BEGIN { OFS = "\t" }
    /^#/ || NF == 0 { print; next }
    $1 == "qwen38-2b-distill" { $23 = "e4-scale/4" }
    { print }' "$script_directory/models.tsv" >"$q4k_registry"
q4k_preset=$work/q4k-merged.ini
if build_presets "$q4k_preset" "QWEN_MODEL_REGISTRY=$q4k_registry" \
    QWEN_WEB_AUTHORIZER_READY=0 \
    >"$work/q4k-build.log" 2>"$work/q4k-build.err"; then
    report q4k_release_preset_generated ok
else
    report q4k_release_preset_generated failed
    cat "$work/q4k-build.err" >&2
fi

# A build declaring the key admits the section; a build declaring `-` carries no
# reader, so the same preset would serve the production module under a row
# claiming a formulation and the policy refuses ahead of the argv.
q4k_build_root=$work/q4k-build
make_q4k_build() {
    q4k_build_directory=$1
    q4k_build_declaration=$2
    mkdir -p "$q4k_build_directory"
    cp "$fake_server" "$q4k_build_directory/llama-server"
    chmod +x "$q4k_build_directory/llama-server"
    {
        printf 'executable\tllama-server\t%s\t%s\n' \
            "$(stat -c %s -- "$q4k_build_directory/llama-server")" \
            "$(sha256sum -- "$q4k_build_directory/llama-server" | cut -d ' ' -f 1)"
        printf 'checkpoint_semantics\tnatural-boundary-v1\n'
        printf 'q4k_variants\t%s\n' "$q4k_build_declaration"
    } >"$q4k_build_directory/artifact-manifest.tsv"
}
make_q4k_build "$q4k_build_root/admits" \
    e4/4,e4-scale/4,e4-scale-licm/4
make_q4k_build "$q4k_build_root/silent" -
run_q4k_policy() {
    QWEN_MODEL_REGISTRY=$q4k_registry \
    QWEN_MODEL_ROOT=$model_root \
    QWEN_QUARANTINE_REGISTRY=$quarantine_registry \
    QWEN_CTX_CHECKPOINT_LEDGER=$ctx_ledger \
    QWEN_RADV_ICD=$fake_icd \
    QWEN_POLICY_TEST_OUTPUT=$work/q4k-policy.out \
    QWEN_ROUTER=1 QWEN_ROUTER_PRESETS=$2 QWEN_ROUTER_MAX=1 \
        "$policy" "$1/llama-server" \
        "$model_root/Qwen3.8-2B-Distill-GGUF/Qwen3.8-2B-Q4_K_M.gguf" 8192 18080
}
if run_q4k_policy "$q4k_build_root/admits" "$q4k_preset" \
    >"$work/q4k-admits.log" 2>"$work/q4k-admits.err"; then
    report q4k_declared_build_admits_release ok
else
    report q4k_declared_build_admits_release failed
    cat "$work/q4k-admits.err" >&2
fi
if run_q4k_policy "$q4k_build_root/silent" "$q4k_preset" \
    >"$work/q4k-silent.log" 2>"$work/q4k-silent.err"; then
    report q4k_undeclared_build_refused admitted
elif grep -q 'does not admit Q4_K formulation' "$work/q4k-silent.err"; then
    report q4k_undeclared_build_refused ok
else
    report q4k_undeclared_build_refused wrong_reason
    cat "$work/q4k-silent.err" >&2
fi

# A preset persists across a registry edit, so a section naming a formulation
# other than the one its row releases is refused against the same build.
q4k_drifted=$work/q4k-drifted.ini
sed 's|^LLAMA_ARG_VK_Q4K_VARIANT = e4-scale/4$|LLAMA_ARG_VK_Q4K_VARIANT = e4/4|' \
    "$q4k_preset" >"$q4k_drifted"
if run_q4k_policy "$q4k_build_root/admits" "$q4k_drifted" \
    >"$work/q4k-drift.log" 2>"$work/q4k-drift.err"; then
    report q4k_section_row_drift_refused admitted
elif grep -q 'carries LLAMA_ARG_VK_Q4K_VARIANT e4/4, registry admits e4-scale/4' \
    "$work/q4k-drift.err"; then
    report q4k_section_row_drift_refused ok
else
    report q4k_section_row_drift_refused wrong_reason
    cat "$work/q4k-drift.err" >&2
fi

# A deployment bundle carries the formulation policy its preset was generated
# against, so the launch reads that policy rather than whichever registry the
# checkout holds. Without it the release and its rollback refuse in opposite
# directions: the keyed preset against the registry it predates, and the
# keyless preset against the registry that has since released a formulation.
run_q4k_policy_bound() {
    QWEN_MODEL_REGISTRY=$3 \
    QWEN_MODEL_ROOT=$model_root \
    QWEN_QUARANTINE_REGISTRY=$quarantine_registry \
    QWEN_CTX_CHECKPOINT_LEDGER=$ctx_ledger \
    QWEN_RADV_ICD=$fake_icd \
    QWEN_POLICY_TEST_OUTPUT=$work/q4k-bound-policy.out \
    QWEN_BUNDLE_Q4K_POLICY=$4 \
    QWEN_ROUTER=1 QWEN_ROUTER_PRESETS=$2 QWEN_ROUTER_MAX=1 \
        "$policy" "$1/llama-server" \
        "$model_root/Qwen3.8-2B-Distill-GGUF/Qwen3.8-2B-Q4_K_M.gguf" 8192 18080
}
q4k_bundle_policy=$work/q4k-policy.tsv
awk -F'\t' 'BEGIN { OFS = "\t" }
    /^[[:space:]]*($|#)/ { next }
    $1 == "" { next }
    { print $1, ($23 == "") ? "-" : $23 }' "$q4k_registry" >"$q4k_bundle_policy"
if run_q4k_policy_bound "$q4k_build_root/admits" "$q4k_preset" \
    "$script_directory/models.tsv" "$q4k_bundle_policy" \
    >"$work/q4k-bound.log" 2>"$work/q4k-bound.err"; then
    report q4k_bundle_policy_outranks_registry ok
else
    report q4k_bundle_policy_outranks_registry failed
    cat "$work/q4k-bound.err" >&2
fi
# `-` is a bundle declaring that no row released a formulation: the launch that
# reads it releases nothing, and the registry that has since released one moves
# nothing about it.
#
# The keyless preset is generated against a registry copy whose formulation
# column is cleared on every row rather than against the shipped one, since a
# release lands by writing that column: reading the shipped registry here would
# make this arm measure a keyed preset the moment a row is promoted, which is
# exactly the state the arm exists to hold against.
q4k_unreleased_registry=$work/q4k-unreleased-models.tsv
awk -F'\t' 'BEGIN { OFS = "\t" }
    /^#/ || NF == 0 { print; next }
    { $23 = "-"; print }' "$script_directory/models.tsv" \
    >"$q4k_unreleased_registry"
q4k_keyless_preset=$work/q4k-keyless.ini
if build_presets "$q4k_keyless_preset" \
    "QWEN_MODEL_REGISTRY=$q4k_unreleased_registry" \
    QWEN_WEB_AUTHORIZER_READY=0 \
    >"$work/q4k-keyless-build.log" 2>"$work/q4k-keyless-build.err"; then
    :
else
    report q4k_keyless_preset_generated failed
    cat "$work/q4k-keyless-build.err" >&2
fi
if grep -q 'LLAMA_ARG_VK_Q4K_VARIANT' "$q4k_keyless_preset"; then
    printf 'the cleared registry still produced a section key; the keyless arm measures nothing\n' >&2
    exit 1
fi
if run_q4k_policy_bound "$q4k_build_root/silent" "$q4k_keyless_preset" \
    "$q4k_registry" - \
    >"$work/q4k-legacy.log" 2>"$work/q4k-legacy.err"; then
    report q4k_unreleasing_policy_admits_keyless_preset ok
else
    report q4k_unreleasing_policy_admits_keyless_preset failed
    cat "$work/q4k-legacy.err" >&2
fi
# A bundled policy that releases nothing refuses a keyed section, so a policy
# and the preset beside it state one release rather than two.
if run_q4k_policy_bound "$q4k_build_root/admits" "$q4k_preset" \
    "$q4k_registry" - \
    >"$work/q4k-conflict.log" 2>"$work/q4k-conflict.err"; then
    report q4k_unreleasing_policy_refuses_keyed_section admitted
elif grep -q 'the bundled Q4_K policy releases no Q4_K formulation for that row' \
    "$work/q4k-conflict.err"; then
    report q4k_unreleasing_policy_refuses_keyed_section ok
else
    report q4k_unreleasing_policy_refuses_keyed_section wrong_reason
    cat "$work/q4k-conflict.err" >&2
fi
# `legacy` is the bundle assembled before the policy member existed. It records
# no release state at all, which is a different claim from a policy stating that
# nothing was released, so it admits the keyless preset every such bundle on the
# appliance carries -- the rollback the release depends on -- and refuses a keyed
# section by naming the two ways to recover the selection rather than reading the
# absence as proof that the section was never released.
if run_q4k_policy_bound "$q4k_build_root/silent" "$q4k_keyless_preset" \
    "$q4k_registry" legacy \
    >"$work/q4k-unrecorded.log" 2>"$work/q4k-unrecorded.err"; then
    report q4k_unrecorded_policy_admits_keyless_preset ok
else
    report q4k_unrecorded_policy_admits_keyless_preset failed
    cat "$work/q4k-unrecorded.err" >&2
fi
if run_q4k_policy_bound "$q4k_build_root/admits" "$q4k_preset" \
    "$q4k_registry" legacy \
    >"$work/q4k-unrecorded-keyed.log" 2>"$work/q4k-unrecorded-keyed.err"; then
    report q4k_unrecorded_policy_refuses_keyed_section admitted
elif grep -q 'the bundle records no Q4_K formulation policy; re-assemble the bundle' \
    "$work/q4k-unrecorded-keyed.err"; then
    report q4k_unrecorded_policy_refuses_keyed_section ok
else
    report q4k_unrecorded_policy_refuses_keyed_section wrong_reason
    cat "$work/q4k-unrecorded-keyed.err" >&2
fi
# `registry` states the reading an empty value already takes, so a launcher that
# selected a preset the bundle never generated names it rather than leaving the
# variable for a later link to fill from the active bundle.
if run_q4k_policy_bound "$q4k_build_root/admits" "$q4k_preset" \
    "$q4k_registry" registry \
    >"$work/q4k-registry-word.log" 2>"$work/q4k-registry-word.err"; then
    report q4k_registry_word_reads_the_column ok
else
    report q4k_registry_word_reads_the_column failed
    cat "$work/q4k-registry-word.err" >&2
fi
# A section the policy never names is refused rather than read as unreleased.
q4k_gap_policy=$work/q4k-policy-gap.tsv
grep -v '^qwen38-2b-distill	' "$q4k_bundle_policy" >"$q4k_gap_policy"
if run_q4k_policy_bound "$q4k_build_root/admits" "$q4k_preset" \
    "$q4k_registry" "$q4k_gap_policy" \
    >"$work/q4k-gap.log" 2>"$work/q4k-gap.err"; then
    report q4k_policy_gap_refused admitted
elif grep -q 'which the bundled Q4_K policy never names' "$work/q4k-gap.err"; then
    report q4k_policy_gap_refused ok
else
    report q4k_policy_gap_refused wrong_reason
    cat "$work/q4k-gap.err" >&2
fi

# The router guard re-derives the key set from the preset it has just verified,
# so a requirement that missed a section is refused at the exec boundary rather
# than serving a formulation no build authority admitted.
if "$exec_guard" "$q4k_preset" "$(guard_digest "$q4k_preset")" \
    "$q4k_registry" "$(guard_digest "$q4k_registry")" \
    "$quarantine_registry" "$(guard_digest "$quarantine_registry")" \
    "$script_directory/draft-pairs.tsv" \
    "$(guard_digest "$script_directory/draft-pairs.tsv")" \
    - - \
    "$ctx_ledger" "$(guard_digest "$ctx_ledger")" \
    - \
    true >"$work/q4k-guard.log" 2>"$work/q4k-guard.err"; then
    report q4k_guard_underderived_requirement_refused admitted
elif grep -q 'names Q4_K formulations e4-scale/4 where the policy bound -' \
    "$work/q4k-guard.err"; then
    report q4k_guard_underderived_requirement_refused ok
else
    report q4k_guard_underderived_requirement_refused wrong_reason
    cat "$work/q4k-guard.err" >&2
fi

if [ "$failures" -eq 0 ]; then
    printf 'test-unified-router-presets: all checks passed\n'
else
    printf 'test-unified-router-presets: %s check(s) failed\n' "$failures" >&2
    exit 1
fi
