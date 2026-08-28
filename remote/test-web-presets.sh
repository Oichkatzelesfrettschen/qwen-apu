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
web-fixture-ok	fixture-production	validator-gated	8192	8192	5	2	12000	yes	no	9/10	refused
EOF

web_profiles_over_ceiling=$work/web-profiles-over-ceiling.tsv
cat >"$web_profiles_over_ceiling" <<'EOF'
web-fixture-over-ceiling	fixture-production	validator-gated	32768	8192	5	2	12000	yes	no	9/10	refused
EOF

# Candidate tier, numeric validated_filled_depth of 8192, context 16384: the
# exceeded-numeric-depth case.
web_profiles_over_depth=$work/web-profiles-over-depth.tsv
cat >"$web_profiles_over_depth" <<'EOF'
web-fixture-over-depth	fixture-candidate-validated	validator-gated	16384	8192	5	2	12000	yes	no	9/10	refused
EOF

# Candidate tier, validated_filled_depth `-`: the unknown-depth case.
web_profiles_unknown_depth=$work/web-profiles-unknown-depth.tsv
cat >"$web_profiles_unknown_depth" <<'EOF'
web-fixture-unknown-depth	fixture-candidate-unknown	validator-gated	8192	-	5	2	12000	yes	no	9/10	refused
EOF

# Production tier at an unvalidated depth: the override admits this one as
# experimental, since production names the model_id's own tier and the
# override withholds the emitted section's claim to it rather than
# refusing the model_id.
web_profiles_production_unvalidated=$work/web-profiles-production-unvalidated.tsv
cat >"$web_profiles_production_unvalidated" <<'EOF'
web-fixture-production-unvalidated	fixture-production	validator-gated	16384	8192	5	2	12000	yes	no	9/10	refused
EOF

web_profiles_archive=$work/web-profiles-archive.tsv
cat >"$web_profiles_archive" <<'EOF'
web-fixture-archive	fixture-archive	validator-gated	8192	-	5	2	12000	yes	no	9/10	refused
EOF

mcp_config=$work/mcp.json
: >"$mcp_config"

build() {
    build_web_profiles=$1
    build_output=$2
    shift 2
    QWEN_MODEL_REGISTRY=$model_registry \
    QWEN_WEB_PROFILES=$build_web_profiles \
        "$@" "$builder" "$build_output"
}

# A profile within the ceiling and within the validated depth is accepted,
# carries every required key, and carries no experimental tag or override
# marker.
presets_ok=$work/presets-ok.ini
if build "$web_profiles_ok" "$presets_ok" \
    env QWEN_WEB_MCP_CONFIG="$mcp_config" \
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
    env QWEN_WEB_MCP_CONFIG="$mcp_config" \
    >"$work/over-ceiling.log" 2>"$work/over-ceiling.err"; then
    report over_ceiling_refused failed
else
    report over_ceiling_refused ok
fi

# A profile whose context exceeds a numeric validated_filled_depth is refused
# by default.
presets_over_depth=$work/presets-over-depth.ini
if build "$web_profiles_over_depth" "$presets_over_depth" \
    env QWEN_WEB_MCP_CONFIG="$mcp_config" \
    >"$work/over-depth.log" 2>"$work/over-depth.err"; then
    report numeric_over_depth_refused_without_override failed
else
    report numeric_over_depth_refused_without_override ok
fi

# The same profile is admitted, tagged experimental, and warned with the
# numeric gap under the override, and the file carries the override marker.
presets_over_depth_allowed=$work/presets-over-depth-allowed.ini
if build "$web_profiles_over_depth" "$presets_over_depth_allowed" \
    env QWEN_WEB_MCP_CONFIG="$mcp_config" QWEN_WEB_ALLOW_UNVALIDATED_DEPTH=1 \
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
    env QWEN_WEB_MCP_CONFIG="$mcp_config" \
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
    env QWEN_WEB_MCP_CONFIG="$mcp_config" QWEN_WEB_ALLOW_UNVALIDATED_DEPTH=1 \
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
    env QWEN_WEB_MCP_CONFIG="$mcp_config" QWEN_WEB_ALLOW_UNVALIDATED_DEPTH=1 \
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
    env QWEN_WEB_MCP_CONFIG="$mcp_config" \
    >"$work/archive.log" 2>"$work/archive.err"; then
    report archive_tier_refused failed
else
    report archive_tier_refused ok
fi

# A missing QWEN_WEB_MCP_CONFIG refuses the run.
presets_no_mcp=$work/presets-no-mcp.ini
if QWEN_MODEL_REGISTRY=$model_registry QWEN_WEB_PROFILES=$web_profiles_ok \
    env -u QWEN_WEB_MCP_CONFIG "$builder" "$presets_no_mcp" \
    >"$work/no-mcp.log" 2>"$work/no-mcp.err"; then
    report missing_mcp_config_refused failed
else
    report missing_mcp_config_refused ok
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
    env QWEN_WEB_MCP_CONFIG="$mcp_config" \
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

if [ "$failures" -ne 0 ]; then
    printf 'test-web-presets: %d check(s) failed\n' "$failures" >&2
    exit 1
fi
printf 'test-web-presets: all checks passed\n'
