#!/bin/sh
set -eu

# Tests remote/build-web-presets.sh against temporary copies of models.tsv and
# web-profiles.tsv, so a case that must fail (an over-ceiling context, an
# unvalidated depth, a missing MCP config) never depends on editing the
# checked-in ledgers.

if [ "$#" -ne 0 ]; then
    printf 'usage: %s\n' "$0" >&2
    exit 2
fi

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
builder=$script_directory/build-web-presets.sh
failures=0

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT INT TERM

report() {
    printf '%s=%s\n' "$1" "$2"
    [ "$2" = ok ] || failures=$((failures + 1))
}

# Four fabricated model rows, one per tier-and-depth combination the
# refusal rules below distinguish: a production row with a numeric validated
# depth, a candidate row with a numeric validated depth, a candidate row
# whose depth reads `-`, and an archive row.
model_registry=$work/models.tsv
cat >"$model_registry" <<'EOF'
# id	role	model_file	fetch_script	context_default	context_ceiling	context_target	cache_type_k	cache_type_v	flash_attention	projector	projector_fetch_script	decode_tok_s	prefill_tok_s	quality	tier	batch	ubatch	validated_filled_depth	validation_evidence	raw_tool_selection	guarded_tool_execution
fixture-production	fixture-role	Fixture-GGUF/production.gguf	download-fixture.sh	8192	16384	32768	q8_0	q4_0	on	none	-	1.00	1.00	untested	production	128	32	8192	evidence/fixture.md	9/10	refused
fixture-candidate-validated	fixture-role	Fixture-GGUF/candidate-validated.gguf	download-fixture.sh	8192	16384	32768	q8_0	q4_0	on	none	-	1.00	1.00	untested	candidate	128	32	8192	evidence/fixture.md	9/10	refused
fixture-candidate-unknown	fixture-role	Fixture-GGUF/candidate-unknown.gguf	download-fixture.sh	8192	16384	32768	q8_0	q4_0	on	none	-	1.00	1.00	untested	candidate	128	32	-	-	9/10	refused
fixture-archive	fixture-role	Fixture-GGUF/archive.gguf	download-fixture.sh	8192	16384	32768	q8_0	q4_0	on	none	-	1.00	1.00	untested	archive	128	32	-	-	9/10	refused
EOF

web_profiles_ok=$work/web-profiles-ok.tsv
cat >"$web_profiles_ok" <<'EOF'
# profile_id	model_id	web_mode	context	validated_filled_depth	max_results	max_fetches	max_chars_per_fetch	multi_source	vision_allowed	tool_selection	execution_policy
web-fixture-ok	fixture-production	validator-gated	8192	8192	5	2	12000	yes	no	9/10	validator-gated
EOF

web_profiles_over_ceiling=$work/web-profiles-over-ceiling.tsv
cat >"$web_profiles_over_ceiling" <<'EOF'
web-fixture-over-ceiling	fixture-production	validator-gated	32768	8192	5	2	12000	yes	no	9/10	validator-gated
EOF

# Candidate tier, numeric validated_filled_depth of 8192, context 16384: the
# exceeded-numeric-depth case.
web_profiles_over_depth=$work/web-profiles-over-depth.tsv
cat >"$web_profiles_over_depth" <<'EOF'
web-fixture-over-depth	fixture-candidate-validated	validator-gated	16384	8192	5	2	12000	yes	no	9/10	validator-gated
EOF

# Candidate tier, validated_filled_depth `-`: the unknown-depth case.
web_profiles_unknown_depth=$work/web-profiles-unknown-depth.tsv
cat >"$web_profiles_unknown_depth" <<'EOF'
web-fixture-unknown-depth	fixture-candidate-unknown	validator-gated	8192	-	5	2	12000	yes	no	9/10	validator-gated
EOF

# Production tier at an unvalidated depth: the override admits this one as
# experimental, since production names the model_id's own tier and the
# override withholds the emitted section's claim to it rather than
# refusing the model_id.
web_profiles_production_unvalidated=$work/web-profiles-production-unvalidated.tsv
cat >"$web_profiles_production_unvalidated" <<'EOF'
web-fixture-production-unvalidated	fixture-production	validator-gated	16384	8192	5	2	12000	yes	no	9/10	validator-gated
EOF

web_profiles_archive=$work/web-profiles-archive.tsv
cat >"$web_profiles_archive" <<'EOF'
web-fixture-archive	fixture-archive	validator-gated	8192	-	5	2	12000	yes	no	9/10	validator-gated
EOF

mcp_server_program=$work/web-mcp-server.py
: >"$mcp_server_program"
search_key_file=$work/private/exa-api.key
token_key_file=$work/private/web-mcp-token.key
mkdir -p "$work/private"
printf 'fixture-search-secret-value\n' >"$search_key_file"
printf 'fixture-token-secret-value\n' >"$token_key_file"
web_state_directory=$work/private/web-mcp-state

# Every build arm supplies the same MCP inputs; an arm that measures their
# absence unsets one explicitly.
mcp_environment() {
    printf 'QWEN_WEB_MCP_SERVER=%s\n' "$mcp_server_program"
    printf 'QWEN_WEB_SEARCH_KEY_FILE=%s\n' "$search_key_file"
    printf 'QWEN_WEB_TOKEN_KEY_FILE=%s\n' "$token_key_file"
    printf 'QWEN_WEB_STATE_DIR=%s\n' "$web_state_directory"
}

# Every fixture row below states execution_policy validator-gated, so the build
# helper supplies the authorizer marker and each arm measures the rule it names
# rather than the execution gate. The gate has its own arms at the end.
build() {
    build_web_profiles=$1
    build_output=$2
    shift 2
    QWEN_MODEL_REGISTRY=$model_registry \
    QWEN_WEB_PROFILES=$build_web_profiles \
    QWEN_WEB_AUTHORIZER_READY=1 \
        "$@" "$builder" "$build_output"
}

# A profile within the ceiling and within the validated depth is accepted,
# carries every required key, and carries no experimental tag or override
# marker.
presets_ok=$work/presets-ok.ini
if build "$web_profiles_ok" "$presets_ok" \
    env QWEN_WEB_MCP_SERVER="$mcp_server_program" QWEN_WEB_SEARCH_KEY_FILE="$search_key_file" QWEN_WEB_TOKEN_KEY_FILE="$token_key_file" QWEN_WEB_STATE_DIR="$web_state_directory" \
    >"$work/ok.log" 2>"$work/ok.err"; then
    report accepted_within_bounds ok
else
    report accepted_within_bounds failed
    cat "$work/ok.err" >&2
fi

required_keys='LLAMA_ARG_MODEL LLAMA_ARG_ALIAS LLAMA_ARG_CTX_SIZE LLAMA_ARG_BATCH LLAMA_ARG_UBATCH LLAMA_ARG_CACHE_TYPE_K LLAMA_ARG_CACHE_TYPE_V LLAMA_ARG_FLASH_ATTN LLAMA_ARG_MCP_SERVERS_CONFIG LLAMA_ARG_TAGS'
geometry_ok=ok
for key in $required_keys; do
    if ! awk -v key="$key" '
        /^\[/ { in_section = 1 }
        in_section && $0 ~ "^" key " *=" { found = 1 }
        END { exit found ? 0 : 1 }
    ' "$presets_ok"; then
        geometry_ok=missing_$key
    fi
done
report section_carries_required_keys "$geometry_ok"

# LLAMA_ARG_MCP_SERVERS_CONFIG never appears before the first section header,
# which would place it outside every [profile_id] block.
preamble_clean=ok
if [ -f "$presets_ok" ] &&
    awk '
        /^\[/ { exit }
        /^LLAMA_ARG_MCP_SERVERS_CONFIG/ { found = 1 }
        END { exit found ? 0 : 1 }
    ' "$presets_ok"; then
    preamble_clean=mcp_key_before_first_section
fi
report no_mcp_key_outside_section "$preamble_clean"

# A fully validated profile carries no unvalidated-depth-override marker and
# no experimental tag.
no_marker=ok
if grep -q 'unvalidated-depth-override' "$presets_ok"; then
    no_marker=marker_present
fi
report validated_profile_carries_no_marker "$no_marker"

no_experimental_tag=ok
if grep -q 'experimental' "$presets_ok"; then
    no_experimental_tag=tag_present
fi
report validated_profile_carries_no_experimental_tag "$no_experimental_tag"

# A profile whose context exceeds the registry context_ceiling is refused.
presets_over_ceiling=$work/presets-over-ceiling.ini
if build "$web_profiles_over_ceiling" "$presets_over_ceiling" \
    env QWEN_WEB_MCP_SERVER="$mcp_server_program" QWEN_WEB_SEARCH_KEY_FILE="$search_key_file" QWEN_WEB_TOKEN_KEY_FILE="$token_key_file" QWEN_WEB_STATE_DIR="$web_state_directory" \
    >"$work/over-ceiling.log" 2>"$work/over-ceiling.err"; then
    report over_ceiling_refused failed
else
    report over_ceiling_refused ok
fi

# A profile whose context exceeds a numeric validated_filled_depth is refused
# by default.
presets_over_depth=$work/presets-over-depth.ini
if build "$web_profiles_over_depth" "$presets_over_depth" \
    env QWEN_WEB_MCP_SERVER="$mcp_server_program" QWEN_WEB_SEARCH_KEY_FILE="$search_key_file" QWEN_WEB_TOKEN_KEY_FILE="$token_key_file" QWEN_WEB_STATE_DIR="$web_state_directory" \
    >"$work/over-depth.log" 2>"$work/over-depth.err"; then
    report numeric_over_depth_refused_without_override failed
else
    report numeric_over_depth_refused_without_override ok
fi

# The same profile is admitted, tagged experimental, and warned with the
# numeric gap under the override, and the file carries the override marker.
presets_over_depth_allowed=$work/presets-over-depth-allowed.ini
if build "$web_profiles_over_depth" "$presets_over_depth_allowed" \
    env QWEN_WEB_MCP_SERVER="$mcp_server_program" QWEN_WEB_SEARCH_KEY_FILE="$search_key_file" QWEN_WEB_TOKEN_KEY_FILE="$token_key_file" QWEN_WEB_STATE_DIR="$web_state_directory" QWEN_WEB_ALLOW_UNVALIDATED_DEPTH=1 \
    >"$work/over-depth-allowed.log" 2>"$work/over-depth-allowed.err"; then
    outcome=ok
    grep -q 'validated_filled_depth_gap=8192' "$work/over-depth-allowed.err" ||
        outcome=missing_gap_warning
    grep -q ',experimental' "$presets_over_depth_allowed" ||
        outcome=missing_experimental_tag
    grep -q 'unvalidated-depth-override' "$presets_over_depth_allowed" ||
        outcome=missing_override_marker
    report numeric_over_depth_admitted_with_override "$outcome"
else
    report numeric_over_depth_admitted_with_override failed
    cat "$work/over-depth-allowed.err" >&2
fi

# A profile whose validated_filled_depth reads `-` is refused by default: the
# unmeasured case fails the same way the measured-too-shallow case does.
presets_unknown_depth=$work/presets-unknown-depth.ini
if build "$web_profiles_unknown_depth" "$presets_unknown_depth" \
    env QWEN_WEB_MCP_SERVER="$mcp_server_program" QWEN_WEB_SEARCH_KEY_FILE="$search_key_file" QWEN_WEB_TOKEN_KEY_FILE="$token_key_file" QWEN_WEB_STATE_DIR="$web_state_directory" \
    >"$work/unknown-depth.log" 2>"$work/unknown-depth.err"; then
    report unknown_depth_refused_without_override failed
else
    report unknown_depth_refused_without_override ok
fi

# The same profile is admitted, tagged experimental, and warned with the
# unknown state under the override, and the file carries the override
# marker.
presets_unknown_depth_allowed=$work/presets-unknown-depth-allowed.ini
if build "$web_profiles_unknown_depth" "$presets_unknown_depth_allowed" \
    env QWEN_WEB_MCP_SERVER="$mcp_server_program" QWEN_WEB_SEARCH_KEY_FILE="$search_key_file" QWEN_WEB_TOKEN_KEY_FILE="$token_key_file" QWEN_WEB_STATE_DIR="$web_state_directory" QWEN_WEB_ALLOW_UNVALIDATED_DEPTH=1 \
    >"$work/unknown-depth-allowed.log" 2>"$work/unknown-depth-allowed.err"; then
    outcome=ok
    grep -q 'validated_filled_depth=unknown' "$work/unknown-depth-allowed.err" ||
        outcome=missing_unknown_warning
    grep -q ',experimental' "$presets_unknown_depth_allowed" ||
        outcome=missing_experimental_tag
    grep -q 'unvalidated-depth-override' "$presets_unknown_depth_allowed" ||
        outcome=missing_override_marker
    report unknown_depth_admitted_with_override "$outcome"
else
    report unknown_depth_admitted_with_override failed
    cat "$work/unknown-depth-allowed.err" >&2
fi

# A production-tier profile at an unvalidated depth is admitted under the
# override: a production-tiered model_id is exactly the one an experimental
# web profile should be able to run. What the override withholds is the
# emitted section's own claim to that tier.
presets_production_unvalidated=$work/presets-production-unvalidated.ini
if build "$web_profiles_production_unvalidated" "$presets_production_unvalidated" \
    env QWEN_WEB_MCP_SERVER="$mcp_server_program" QWEN_WEB_SEARCH_KEY_FILE="$search_key_file" QWEN_WEB_TOKEN_KEY_FILE="$token_key_file" QWEN_WEB_STATE_DIR="$web_state_directory" QWEN_WEB_ALLOW_UNVALIDATED_DEPTH=1 \
    >"$work/production-unvalidated.log" 2>"$work/production-unvalidated.err"; then
    outcome=ok
    grep -q ',experimental' "$presets_production_unvalidated" ||
        outcome=missing_experimental_tag
    grep -q 'unvalidated-depth-override' "$presets_production_unvalidated" ||
        outcome=missing_override_marker
    report production_model_admitted_as_experimental_under_override "$outcome"
else
    report production_model_admitted_as_experimental_under_override failed
    cat "$work/production-unvalidated.err" >&2
fi

# The emitted section never carries a default tag: the override withholds
# the emitted profile's own claim to a tier it did not earn.
no_default_tag=ok
if grep -q 'default' "$presets_production_unvalidated"; then
    no_default_tag=default_tag_present
fi
report no_default_tag_under_override "$no_default_tag"

# A profile naming an archive-tiered model is refused.
presets_archive=$work/presets-archive.ini
if build "$web_profiles_archive" "$presets_archive" \
    env QWEN_WEB_MCP_SERVER="$mcp_server_program" QWEN_WEB_SEARCH_KEY_FILE="$search_key_file" QWEN_WEB_TOKEN_KEY_FILE="$token_key_file" QWEN_WEB_STATE_DIR="$web_state_directory" \
    >"$work/archive.log" 2>"$work/archive.err"; then
    report archive_tier_refused failed
else
    report archive_tier_refused ok
fi

# An absent MCP server program or key file path refuses the run: no default is
# safe to assume for a tool-bearing section.
presets_no_mcp=$work/presets-no-mcp.ini
if QWEN_MODEL_REGISTRY=$model_registry QWEN_WEB_PROFILES=$web_profiles_ok \
    QWEN_WEB_AUTHORIZER_READY=1 \
    env -u QWEN_WEB_MCP_SERVER QWEN_WEB_SEARCH_KEY_FILE="$search_key_file" \
    "$builder" "$presets_no_mcp" \
    >"$work/no-mcp.log" 2>"$work/no-mcp.err"; then
    report missing_mcp_server_refused failed
else
    report missing_mcp_server_refused ok
fi

presets_no_key=$work/presets-no-key.ini
if QWEN_MODEL_REGISTRY=$model_registry QWEN_WEB_PROFILES=$web_profiles_ok \
    QWEN_WEB_AUTHORIZER_READY=1 \
    env -u QWEN_WEB_SEARCH_KEY_FILE QWEN_WEB_MCP_SERVER="$mcp_server_program" \
    "$builder" "$presets_no_key" \
    >"$work/no-key.log" 2>"$work/no-key.err"; then
    report missing_search_key_file_refused failed
else
    report missing_search_key_file_refused ok
fi

# The generated file reaches llama-server through qwen-capacity-policy.sh, whose
# validate_router_preset_tuples is the authority on a complete section tuple.
# Running the generator's own output through that validator is what makes a
# misspelled key a test failure here rather than a launch failure on the
# appliance; a key-name check inside this script would only restate the
# generator's printf list.
policy=$script_directory/qwen-capacity-policy.sh
fake_server=$script_directory/test-fixtures/fake-llama-server.sh
fake_icd=$work/radeon_icd.x86_64.json
: >"$fake_icd"
policy_model_root=$work/model-root
mkdir -p "$policy_model_root/Fixture-GGUF"
for fixture_weights in production candidate-validated candidate-unknown archive; do
    : >"$policy_model_root/Fixture-GGUF/$fixture_weights.gguf"
done
policy_quarantine=$work/quarantine.tsv
printf '# reason_id\tscope\tsubject\tconsumers\tdepth\tbatch\tubatch\tcache_type_k\tcache_type_v\tflash_attention\n' \
    >"$policy_quarantine"
policy_output=$work/policy.out

run_policy_over_presets() {
    QWEN_MODEL_REGISTRY=$model_registry \
    QWEN_MODEL_ROOT=$policy_model_root \
    QWEN_QUARANTINE_REGISTRY=$policy_quarantine \
    QWEN_RADV_ICD=$fake_icd \
    QWEN_POLICY_TEST_OUTPUT=$policy_output \
    QWEN_ROUTER=1 QWEN_ROUTER_PRESETS=$1 QWEN_ROUTER_MAX=1 \
        "$policy" "$fake_server" \
        "$policy_model_root/Fixture-GGUF/production.gguf" 8192 18080
}

presets_policy=$work/presets-policy.ini
if QWEN_MODEL_ROOT=$policy_model_root build "$web_profiles_ok" "$presets_policy" \
    env QWEN_WEB_MCP_SERVER="$mcp_server_program" QWEN_WEB_SEARCH_KEY_FILE="$search_key_file" QWEN_WEB_TOKEN_KEY_FILE="$token_key_file" QWEN_WEB_STATE_DIR="$web_state_directory" \
    >"$work/policy-build.log" 2>"$work/policy-build.err"; then
    if run_policy_over_presets "$presets_policy" \
        >"$work/policy.log" 2>"$work/policy.err"; then
        report generated_preset_passes_capacity_policy ok
    else
        report generated_preset_passes_capacity_policy failed
        cat "$work/policy.err" >&2
    fi
else
    report generated_preset_passes_capacity_policy build_failed
    cat "$work/policy-build.err" >&2
fi

# A misspelled or absent tuple key fails that same validation. Each key is
# removed in turn, so the arm proves the validator reads every one rather than
# reading the file's first line.
for required_key in LLAMA_ARG_MODEL LLAMA_ARG_CTX_SIZE LLAMA_ARG_BATCH \
    LLAMA_ARG_UBATCH LLAMA_ARG_CACHE_TYPE_K LLAMA_ARG_CACHE_TYPE_V \
    LLAMA_ARG_FLASH_ATTN; do
    broken_presets=$work/presets-without-$required_key.ini
    sed "/^$required_key =/d" "$presets_policy" >"$broken_presets"
    if run_policy_over_presets "$broken_presets" \
        >"$work/broken.log" 2>"$work/broken.err"; then
        report "policy_rejects_missing_$required_key" accepted
    else
        report "policy_rejects_missing_$required_key" ok
    fi
done

# A key spelled in the CLI style the deployed router format leaves unread is a
# missing key, which is the defect this generator carried.
cli_style_presets=$work/presets-cli-style.ini
sed 's/^LLAMA_ARG_UBATCH =/ubatch-size =/' "$presets_policy" >"$cli_style_presets"
if run_policy_over_presets "$cli_style_presets" \
    >"$work/cli-style.log" 2>"$work/cli-style.err"; then
    report policy_rejects_cli_style_key accepted
else
    report policy_rejects_cli_style_key ok
fi

# execution_policy decides emission. A refused row emits nothing under every
# setting, which is the boundary no override crosses.
web_profiles_refused=$work/web-profiles-refused.tsv
printf 'web-fixture-refused\tfixture-production\tvalidator-gated\t8192\t8192\t5\t2\t12000\tyes\tno\t9/10\trefused\n' \
    >"$web_profiles_refused"
presets_refused=$work/presets-refused.ini
if build "$web_profiles_refused" "$presets_refused" \
    env QWEN_WEB_MCP_SERVER="$mcp_server_program" QWEN_WEB_SEARCH_KEY_FILE="$search_key_file" QWEN_WEB_TOKEN_KEY_FILE="$token_key_file" QWEN_WEB_STATE_DIR="$web_state_directory" \
    >"$work/refused.log" 2>"$work/refused.err"; then
    report refused_policy_emits_nothing emitted_a_section
else
    outcome=ok
    grep -q 'web_preset_skipped profile=web-fixture-refused execution_policy=refused' \
        "$work/refused.err" || outcome=missing_skip_line
    [ -f "$presets_refused" ] && grep -q '^\[web-fixture-refused\]' "$presets_refused" &&
        outcome=section_present
    report refused_policy_emits_nothing "$outcome"
fi

# The authorizer marker admits no refused row, so the same ledger emits nothing
# with the marker set.
presets_refused_marked=$work/presets-refused-marked.ini
if QWEN_MODEL_REGISTRY=$model_registry QWEN_WEB_PROFILES=$web_profiles_refused \
    QWEN_WEB_AUTHORIZER_READY=1 QWEN_WEB_ALLOW_UNVALIDATED_DEPTH=1 \
    env QWEN_WEB_MCP_SERVER="$mcp_server_program" QWEN_WEB_SEARCH_KEY_FILE="$search_key_file" QWEN_WEB_TOKEN_KEY_FILE="$token_key_file" QWEN_WEB_STATE_DIR="$web_state_directory" \
    "$builder" "$presets_refused_marked" \
    >"$work/refused-marked.log" 2>"$work/refused-marked.err"; then
    report refused_policy_survives_every_override emitted_a_section
else
    report refused_policy_survives_every_override ok
fi

# A validator-gated row emits only where the authorizer marker asserts the
# argument-authorization path runs.
web_profiles_gated=$work/web-profiles-gated.tsv
printf 'web-fixture-gated\tfixture-production\tvalidator-gated\t8192\t8192\t5\t2\t12000\tyes\tno\t9/10\tvalidator-gated\n' \
    >"$web_profiles_gated"
presets_gated_absent=$work/presets-gated-absent.ini
if QWEN_MODEL_REGISTRY=$model_registry QWEN_WEB_PROFILES=$web_profiles_gated \
    env -u QWEN_WEB_AUTHORIZER_READY QWEN_WEB_MCP_SERVER="$mcp_server_program" QWEN_WEB_SEARCH_KEY_FILE="$search_key_file" QWEN_WEB_TOKEN_KEY_FILE="$token_key_file" QWEN_WEB_STATE_DIR="$web_state_directory" \
    "$builder" "$presets_gated_absent" \
    >"$work/gated-absent.log" 2>"$work/gated-absent.err"; then
    report validator_gated_withheld_without_authorizer emitted_a_section
else
    outcome=ok
    grep -q 'execution_policy=validator-gated authorizer=absent' \
        "$work/gated-absent.err" || outcome=missing_skip_line
    report validator_gated_withheld_without_authorizer "$outcome"
fi

presets_gated=$work/presets-gated.ini
if build "$web_profiles_gated" "$presets_gated" \
    env QWEN_WEB_MCP_SERVER="$mcp_server_program" QWEN_WEB_SEARCH_KEY_FILE="$search_key_file" QWEN_WEB_TOKEN_KEY_FILE="$token_key_file" QWEN_WEB_STATE_DIR="$web_state_directory" \
    >"$work/gated.log" 2>"$work/gated.err"; then
    outcome=ok
    grep -q '^LLAMA_ARG_MCP_SERVERS_CONFIG = ' "$presets_gated" ||
        outcome=missing_mcp_key
    grep -q '^LLAMA_ARG_TAGS = web-research,validator-gated$' "$presets_gated" ||
        outcome=wrong_tags
    report validator_gated_emits_with_authorizer "$outcome"
else
    report validator_gated_emits_with_authorizer failed
    cat "$work/gated.err" >&2
fi

# A ui-mediated row emits a section the server runs no MCP client from, so the
# retrieval stays in the web UI.
web_profiles_ui=$work/web-profiles-ui.tsv
printf 'web-fixture-ui\tfixture-production\tui-mediated\t8192\t8192\t5\t2\t12000\tyes\tno\t9/10\tui-mediated\n' \
    >"$web_profiles_ui"
presets_ui=$work/presets-ui.ini
if build "$web_profiles_ui" "$presets_ui" \
    env QWEN_WEB_MCP_SERVER="$mcp_server_program" QWEN_WEB_SEARCH_KEY_FILE="$search_key_file" QWEN_WEB_TOKEN_KEY_FILE="$token_key_file" QWEN_WEB_STATE_DIR="$web_state_directory" \
    >"$work/ui.log" 2>"$work/ui.err"; then
    outcome=ok
    grep -q '^LLAMA_ARG_MCP_SERVERS_CONFIG' "$presets_ui" && outcome=mcp_key_present
    grep -q '^LLAMA_ARG_TAGS = web-research,ui-mediated$' "$presets_ui" ||
        outcome=wrong_tags
    report ui_mediated_emits_without_mcp_config "$outcome"
else
    report ui_mediated_emits_without_mcp_config failed
    cat "$work/ui.err" >&2
fi

# A ui-mediated row emits without the authorizer marker: the marker gates the
# server's own tool execution, which a ui-mediated section never performs.
presets_ui_unmarked=$work/presets-ui-unmarked.ini
if QWEN_MODEL_REGISTRY=$model_registry QWEN_WEB_PROFILES=$web_profiles_ui \
    env -u QWEN_WEB_AUTHORIZER_READY QWEN_WEB_MCP_SERVER="$mcp_server_program" QWEN_WEB_SEARCH_KEY_FILE="$search_key_file" QWEN_WEB_TOKEN_KEY_FILE="$token_key_file" QWEN_WEB_STATE_DIR="$web_state_directory" \
    "$builder" "$presets_ui_unmarked" \
    >"$work/ui-unmarked.log" 2>"$work/ui-unmarked.err"; then
    report ui_mediated_emits_without_authorizer ok
else
    report ui_mediated_emits_without_authorizer failed
    cat "$work/ui-unmarked.err" >&2
fi

# An execution_policy outside the vocabulary stops the run: the ledger states a
# policy the generator has no rule for.
web_profiles_unknown_policy=$work/web-profiles-unknown-policy.tsv
printf 'web-fixture-unknown-policy\tfixture-production\tvalidator-gated\t8192\t8192\t5\t2\t12000\tyes\tno\t9/10\tunguarded\n' \
    >"$web_profiles_unknown_policy"
presets_unknown_policy=$work/presets-unknown-policy.ini
if build "$web_profiles_unknown_policy" "$presets_unknown_policy" \
    env QWEN_WEB_MCP_SERVER="$mcp_server_program" QWEN_WEB_SEARCH_KEY_FILE="$search_key_file" QWEN_WEB_TOKEN_KEY_FILE="$token_key_file" QWEN_WEB_STATE_DIR="$web_state_directory" \
    >"$work/unknown-policy.log" 2>"$work/unknown-policy.err"; then
    report unknown_execution_policy_refused emitted_a_section
else
    outcome=ok
    grep -q 'outside the vocabulary' "$work/unknown-policy.err" ||
        outcome=missing_vocabulary_message
    report unknown_execution_policy_refused "$outcome"
fi

# Every numeric field is validated before it is compared, so a malformed value
# stops the run naming the field and the profile. The ledger row below is well
# formed except in the one field each arm rewrites.
emit_numeric_fixture() {
    # profile_id model_id web_mode context depth results fetches chars ...
    printf 'web-fixture-numeric\tfixture-production\tvalidator-gated\t%s\t%s\t%s\t%s\t%s\tyes\tno\t9/10\tvalidator-gated\n' \
        "$1" "$2" "$3" "$4" "$5"
}

check_numeric_field_refused() {
    numeric_case_name=$1
    shift
    numeric_profiles=$work/web-profiles-numeric-$numeric_case_name.tsv
    emit_numeric_fixture "$@" >"$numeric_profiles"
    numeric_presets=$work/presets-numeric-$numeric_case_name.ini
    if build "$numeric_profiles" "$numeric_presets" \
        env QWEN_WEB_MCP_SERVER="$mcp_server_program" QWEN_WEB_SEARCH_KEY_FILE="$search_key_file" QWEN_WEB_TOKEN_KEY_FILE="$token_key_file" QWEN_WEB_STATE_DIR="$web_state_directory" \
        >"$work/numeric-$numeric_case_name.log" \
        2>"$work/numeric-$numeric_case_name.err"; then
        report "numeric_${numeric_case_name}_refused" emitted_a_section
        return
    fi
    if grep -q 'web-fixture-numeric' "$work/numeric-$numeric_case_name.err"; then
        report "numeric_${numeric_case_name}_refused" ok
    else
        report "numeric_${numeric_case_name}_refused" message_omits_profile
    fi
}

check_numeric_field_refused context_text abc 8192 5 2 12000
check_numeric_field_refused context_leading_zero 08192 8192 5 2 12000
check_numeric_field_refused context_empty '' 8192 5 2 12000
check_numeric_field_refused context_sentinel - 8192 5 2 12000
check_numeric_field_refused ledger_depth_text 8192 later 5 2 12000
check_numeric_field_refused ledger_depth_leading_zero 8192 08192 5 2 12000
check_numeric_field_refused max_results_text 8192 8192 many 2 12000
check_numeric_field_refused max_results_zero 8192 8192 0 2 12000
check_numeric_field_refused max_fetches_leading_zero 8192 8192 5 02 12000
check_numeric_field_refused max_chars_negative 8192 8192 5 2 -12000

# The sentinel stands where the registry defines the unmeasured state, so a
# ledger validated_filled_depth of `-` matching its registry row is admitted by
# the numeric rule. The depth override carries it past the unmeasured-depth
# refusal, which is a separate rule with its own arms above.
numeric_sentinel_profiles=$work/web-profiles-numeric-sentinel.tsv
printf 'web-fixture-sentinel\tfixture-candidate-unknown\tvalidator-gated\t8192\t-\t5\t2\t12000\tyes\tno\t9/10\tvalidator-gated\n' \
    >"$numeric_sentinel_profiles"
numeric_sentinel_presets=$work/presets-numeric-sentinel.ini
if build "$numeric_sentinel_profiles" "$numeric_sentinel_presets" \
    env QWEN_WEB_MCP_SERVER="$mcp_server_program" QWEN_WEB_SEARCH_KEY_FILE="$search_key_file" QWEN_WEB_TOKEN_KEY_FILE="$token_key_file" QWEN_WEB_STATE_DIR="$web_state_directory" QWEN_WEB_ALLOW_UNVALIDATED_DEPTH=1 \
    >"$work/numeric-sentinel.log" 2>"$work/numeric-sentinel.err"; then
    report ledger_depth_sentinel_admitted ok
else
    report ledger_depth_sentinel_admitted refused
    cat "$work/numeric-sentinel.err" >&2
fi

# remote/models.tsv is the authority for validated_filled_depth,
# vision_allowed, and tool_selection, so a ledger copy that diverges stops the
# run naming the profile, the field, and both values.
check_divergent_field_refused() {
    divergent_case_name=$1
    divergent_row=$2
    divergent_needle=$3
    divergent_profiles=$work/web-profiles-divergent-$divergent_case_name.tsv
    printf '%s\n' "$divergent_row" >"$divergent_profiles"
    divergent_presets=$work/presets-divergent-$divergent_case_name.ini
    if build "$divergent_profiles" "$divergent_presets" \
        env QWEN_WEB_MCP_SERVER="$mcp_server_program" QWEN_WEB_SEARCH_KEY_FILE="$search_key_file" QWEN_WEB_TOKEN_KEY_FILE="$token_key_file" QWEN_WEB_STATE_DIR="$web_state_directory" \
        >"$work/divergent-$divergent_case_name.log" \
        2>"$work/divergent-$divergent_case_name.err"; then
        report "divergent_${divergent_case_name}_refused" emitted_a_section
        return
    fi
    divergent_outcome=ok
    grep -q "$divergent_needle" "$work/divergent-$divergent_case_name.err" ||
        divergent_outcome=message_omits_values
    grep -q 'web-fixture-divergent' "$work/divergent-$divergent_case_name.err" ||
        divergent_outcome=message_omits_profile
    report "divergent_${divergent_case_name}_refused" "$divergent_outcome"
}

# fixture-production reads validated_filled_depth 8192, projector none, and
# raw_tool_selection 9/10; each row below diverges in one of the three.
check_divergent_field_refused validated_filled_depth \
    "$(printf 'web-fixture-divergent\tfixture-production\tvalidator-gated\t8192\t16384\t5\t2\t12000\tyes\tno\t9/10\tvalidator-gated')" \
    'validated_filled_depth 16384 where model fixture-production carries 8192'
check_divergent_field_refused vision_allowed \
    "$(printf 'web-fixture-divergent\tfixture-production\tvalidator-gated\t8192\t8192\t5\t2\t12000\tyes\tyes\t9/10\tvalidator-gated')" \
    'vision_allowed yes where model fixture-production carries no'
check_divergent_field_refused tool_selection \
    "$(printf 'web-fixture-divergent\tfixture-production\tvalidator-gated\t8192\t8192\t5\t2\t12000\tyes\tno\t2/10\tvalidator-gated')" \
    'tool_selection 2/10 where model fixture-production carries 9/10'

# A registry-side numeric field is validated on the same rule, so a malformed
# batch stops the run rather than reaching the emitted geometry.
malformed_registry=$work/models-malformed-batch.tsv
sed 's/^\(fixture-production\t.*untested\tproduction\t\)128\t/\10128\t/' \
    "$model_registry" >"$malformed_registry"
malformed_registry_presets=$work/presets-malformed-batch.ini
if QWEN_MODEL_REGISTRY=$malformed_registry \
    QWEN_WEB_PROFILES=$web_profiles_ok QWEN_WEB_AUTHORIZER_READY=1 \
    env QWEN_WEB_MCP_SERVER="$mcp_server_program" QWEN_WEB_SEARCH_KEY_FILE="$search_key_file" QWEN_WEB_TOKEN_KEY_FILE="$token_key_file" QWEN_WEB_STATE_DIR="$web_state_directory" \
    "$builder" "$malformed_registry_presets" \
    >"$work/malformed-batch.log" 2>"$work/malformed-batch.err"; then
    report registry_batch_leading_zero_refused emitted_a_section
else
    outcome=ok
    grep -q 'batch' "$work/malformed-batch.err" || outcome=message_omits_field
    report registry_batch_leading_zero_refused "$outcome"
fi

# One MCP configuration per emitting profile, carrying the profile's own
# budgets. The gated fixture emits one section, so its configuration is the
# subject.
mcp_configs=$work/web-mcp-configs
gated_mcp_config=$mcp_configs/web-fixture-gated.json

mcp_outcome=ok
[ -f "$gated_mcp_config" ] || mcp_outcome=config_absent
if [ "$mcp_outcome" = ok ]; then
    grep -q '"QWEN_WEB_PROFILE": "web-fixture-gated"' "$gated_mcp_config" ||
        mcp_outcome=missing_profile
    grep -q '"QWEN_WEB_MAX_RESULTS": "5"' "$gated_mcp_config" ||
        mcp_outcome=missing_max_results
    grep -q '"QWEN_WEB_MAX_FETCHES": "2"' "$gated_mcp_config" ||
        mcp_outcome=missing_max_fetches
    grep -q '"QWEN_WEB_MAX_CHARS_PER_FETCH": "12000"' "$gated_mcp_config" ||
        mcp_outcome=missing_max_chars
    grep -q '"QWEN_WEB_SEARCH_AUTH": "required"' "$gated_mcp_config" ||
        mcp_outcome=missing_search_auth
    grep -q '"QWEN_WEB_STATE_DIR"' "$gated_mcp_config" ||
        mcp_outcome=missing_state_dir
    grep -q '"QWEN_WEB_SEARCH_KEY_FILE"' "$gated_mcp_config" ||
        mcp_outcome=missing_key_file_path
fi
report mcp_config_carries_profile_budgets "$mcp_outcome"

# The section points at the generated file rather than at a path the caller
# supplied.
if grep -q "^LLAMA_ARG_MCP_SERVERS_CONFIG = $gated_mcp_config\$" "$presets_gated"; then
    report mcp_config_path_reaches_section ok
else
    report mcp_config_path_reaches_section wrong_path
fi

# The configuration parses as JSON, so the server reads what the generator
# meant rather than a file whose commas decide it.
if python3 -c 'import json,sys; json.load(open(sys.argv[1]))' \
    "$gated_mcp_config" >/dev/null 2>&1; then
    report mcp_config_parses_as_json ok
else
    report mcp_config_parses_as_json malformed
fi

# A generated configuration carries key-file paths and never key contents. The
# check reads every env value: a *_KEY_FILE value must be an absolute path that
# names no file the run can read as a secret, and every other env key must come
# from the declared set. Its limit is that it recognises a secret by the shape
# of the value and by the fixture contents it knows, so a credential that
# happens to look like an absolute path, or one smuggled into a path component,
# passes; what it does catch is a key file's contents inlined where its path
# belongs, which is the substitution that turns a persisted preset tree into a
# credential store.
secret_leak_outcome=ok
for generated_config in "$mcp_configs"/*.json; do
    [ -f "$generated_config" ] || continue
    if grep -q 'fixture-search-secret-value\|fixture-token-secret-value' \
        "$generated_config"; then
        secret_leak_outcome=key_contents_present
        break
    fi
    unexpected_key=$(python3 - "$generated_config" <<'PYTHON'
import json
import sys

admitted = {
    "QWEN_WEB_PROFILE",
    "QWEN_WEB_PROVIDER",
    "QWEN_WEB_MAX_RESULTS",
    "QWEN_WEB_MAX_FETCHES",
    "QWEN_WEB_MAX_CHARS_PER_FETCH",
    "QWEN_WEB_SEARCH_AUTH",
    "QWEN_WEB_SEARCH_KEY_FILE",
    "QWEN_WEB_TOKEN_KEY_FILE",
    "QWEN_WEB_STATE_DIR",
}
document = json.load(open(sys.argv[1]))
environment = document["mcpServers"]["web"]["env"]
for name, value in environment.items():
    if name not in admitted:
        print("undeclared env key: %s" % name)
    if name.endswith("_KEY_FILE") and not value.startswith("/"):
        print("key file value is no absolute path: %s" % name)
PYTHON
    ) || unexpected_key='config unreadable'
    if [ -n "$unexpected_key" ]; then
        secret_leak_outcome=$unexpected_key
        break
    fi
done
report mcp_config_carries_paths_only "$secret_leak_outcome"

# A ui-mediated profile performs its retrieval in the UI, so its section names
# no configuration while the file still records the profile's budgets for the
# UI to read.
if grep -q '^LLAMA_ARG_MCP_SERVERS_CONFIG' "$presets_ui"; then
    report ui_mediated_section_names_no_mcp_config key_present
else
    report ui_mediated_section_names_no_mcp_config ok
fi

# A path holding a double quote would change the parsed JSON value, so the run
# refuses it.
presets_quoted_path=$work/presets-quoted-path.ini
if QWEN_MODEL_REGISTRY=$model_registry QWEN_WEB_PROFILES=$web_profiles_gated \
    QWEN_WEB_AUTHORIZER_READY=1 \
    env QWEN_WEB_MCP_SERVER="$mcp_server_program" \
    QWEN_WEB_SEARCH_KEY_FILE='/private/exa".key' \
    "$builder" "$presets_quoted_path" \
    >"$work/quoted-path.log" 2>"$work/quoted-path.err"; then
    report json_unsafe_key_path_refused accepted
else
    report json_unsafe_key_path_refused ok
fi

if [ "$failures" -ne 0 ]; then
    printf 'test-web-presets: %d check(s) failed\n' "$failures" >&2
    exit 1
fi
printf 'test-web-presets: all checks passed\n'
