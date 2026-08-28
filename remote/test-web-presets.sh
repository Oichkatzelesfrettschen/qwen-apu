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
fixture-production	fixture-role	Fixture-GGUF/fixture.gguf	download-fixture.sh	8192	16384	32768	q8_0	q4_0	on	none	-	1.00	1.00	untested	production	128	32	8192	evidence/fixture.md	9/10	refused
fixture-candidate-validated	fixture-role	Fixture-GGUF/fixture.gguf	download-fixture.sh	8192	16384	32768	q8_0	q4_0	on	none	-	1.00	1.00	untested	candidate	128	32	8192	evidence/fixture.md	9/10	refused
fixture-candidate-unknown	fixture-role	Fixture-GGUF/fixture.gguf	download-fixture.sh	8192	16384	32768	q8_0	q4_0	on	none	-	1.00	1.00	untested	candidate	128	32	-	-	9/10	refused
fixture-archive	fixture-role	Fixture-GGUF/fixture.gguf	download-fixture.sh	8192	16384	32768	q8_0	q4_0	on	none	-	1.00	1.00	untested	archive	128	32	-	-	9/10	refused
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

# Production tier at an unvalidated depth: the override never admits this
# one, regardless of QWEN_WEB_ALLOW_UNVALIDATED_DEPTH.
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

required_keys='model ctx-size batch-size ubatch-size cache-type-k cache-type-v flash-attn mcp-servers-config tags'
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

# mcp-servers-config never appears before the first section header, which
# would place it outside every [profile_id] block.
preamble_clean=ok
if [ -f "$presets_ok" ] &&
    awk '
        /^\[/ { exit }
        /^mcp-servers-config/ { found = 1 }
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

# A production-tier profile at an unvalidated depth refuses even under the
# override, because production claims a measured-safe tuple.
presets_production_unvalidated=$work/presets-production-unvalidated.ini
if build "$web_profiles_production_unvalidated" "$presets_production_unvalidated" \
    env QWEN_WEB_MCP_CONFIG="$mcp_config" QWEN_WEB_ALLOW_UNVALIDATED_DEPTH=1 \
    >"$work/production-unvalidated.log" 2>"$work/production-unvalidated.err"; then
    report production_tier_refuses_override failed
else
    report production_tier_refuses_override ok
fi

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

if [ "$failures" -ne 0 ]; then
    printf 'test-web-presets: %d check(s) failed\n' "$failures" >&2
    exit 1
fi
printf 'test-web-presets: all checks passed\n'
