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

build_presets() {
    build_output=$1
    shift
    QWEN_MODEL_ROOT=$model_root \
    QWEN_QUARANTINE_REGISTRY=$quarantine_registry \
    QWEN_QUARANTINE_REASONS=$repository_root/evidence/quarantine \
    QWEN_CTX_CHECKPOINT_LEDGER=$ctx_ledger \
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

# The image lane stays on qwen-image-launch.sh, so no emitted configuration
# names an image server whatever the checked-in image ledger carries.
if ! grep -rq '"image"' "$work"/web-mcp-configs-* 2>/dev/null; then
    report image_server_withheld ok
else
    report image_server_withheld failed
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

if [ "$failures" -eq 0 ]; then
    printf 'test-unified-router-presets: all checks passed\n'
else
    printf 'test-unified-router-presets: %s check(s) failed\n' "$failures" >&2
    exit 1
fi
