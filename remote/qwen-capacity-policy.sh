#!/bin/sh
set -eu

if [ "$#" -lt 3 ] || [ "$#" -gt 6 ]; then
    printf 'usage: %s LLAMA_SERVER MODEL_PATH CONTEXT_SIZE [PORT [STATIC_PATH [API_KEY_FILE]]]\n' "$0" >&2
    exit 2
fi

llama_server=$1
model_path=$2
context_size=$3
server_port=${4:-8080}
static_path=${5:-}
api_key_file=${6:-}
router_enabled=${QWEN_ROUTER:-0}
case $router_enabled in
    0 | 1) ;;
    *)
        printf 'QWEN_ROUTER must be 0 or 1: %s\n' "$router_enabled" >&2
        exit 2
        ;;
esac

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
bind_host=${QWEN_BIND_HOST:-127.0.0.1}
cors_origins=${QWEN_CORS_ORIGINS:-localhost}

# A router preset section normally names a registry id. A web preset section
# names a profile_id instead, because several profiles serve one checkpoint at
# depths the profile chooses, so $6 switches the resolution: the section's
# LLAMA_ARG_MODEL path resolves the registry row through the model_file column,
# which is unique across the registry, and LLAMA_ARG_CTX_SIZE is bounded by that
# row's context_ceiling rather than pinned to its context_default, and bounded
# again by that row's validated_filled_depth unless $7 carries the preset's
# unvalidated-depth marker. Every other tuple key, tier rule, and quarantine
# rule stays identical.
#
# A draft-pair section names a pair_id, so $8 carries the validated rows of
# remote/draft-pairs.tsv and the section resolves through them to the target
# registry row. The six tuple keys are then compared against that row and the
# nine draft keys against the pair row, and a section outside the ledger
# carrying any draft key is refused, because a draft the ledger never admitted
# loads a second checkpoint no resident-set arithmetic counted.
validate_router_preset_tuples() {
    printf '%s\n' "$4" | awk -F'\t' -v model_root="$3" \
        -v include_quarantine="$5" -v web_profile_sections="${6:-0}" \
        -v web_depth_override="${7:-0}" -v draft_pair_ledger="${8:-}" \
        -v ctx_checkpoint_ledger="${9:-}" -v web_section_list="${10:-}" '
        # The merged preset holds registry sections and web sections in one
        # file, so the web rules are selected per section rather than per file.
        # $6 states that every section is a web profile, which is what
        # build-web-presets.sh emits; $10 names the sections
        # build-router-presets.sh folded into the roster preset, and every
        # other section of that file takes the registry rules.
        function is_web_section(name) {
            return web_profile_sections == 1 || (name in web_sections)
        }
        function reset_tuple(   draft_key_index) {
            for (draft_key_index = 1; draft_key_index <= draft_key_count;
                 draft_key_index++) {
                draft_count[draft_keys[draft_key_index]] = 0
                draft_value[draft_keys[draft_key_index]] = ""
            }
            model_count = 0
            context_count = 0
            cache_k_count = 0
            cache_v_count = 0
            flash_count = 0
            batch_count = 0
            ubatch_count = 0
            checkpoint_count = 0
            tags_count = 0
            mcp_count = 0
            model_value = ""
            context_value = ""
            cache_k_value = ""
            cache_v_value = ""
            flash_value = ""
            batch_value = ""
            ubatch_value = ""
            checkpoint_value = ""
            tags_value = ""
        }
        function reject_key(key, count) {
            printf "router preset section %s requires exactly one %s, found %d\n", \
                section, key, count > "/dev/stderr"
            rejected = 1
        }
        function reject_value(key, value) {
            printf "router preset section %s carries invalid %s: %s\n", \
                section, key, value > "/dev/stderr"
            rejected = 1
        }
        function reject_registry_value(key, value, expected) {
            printf "router preset section %s carries %s %s, registry admits %s\n", \
                section, key, value, expected > "/dev/stderr"
            rejected = 1
        }
        function check_draft_key(key, expected) {
            if (draft_count[key] != 1) {
                reject_key(key, draft_count[key])
                return
            }
            if (draft_value[key] != expected) {
                printf "router preset section %s carries %s %s, the draft pair ledger admits %s\n", \
                    section, key, draft_value[key], expected > "/dev/stderr"
                rejected = 1
            }
        }
        function finish_section() {
            if (section == "" || section == "*") {
                return
            }
            model_sections++
            if (model_count != 1) reject_key("LLAMA_ARG_MODEL", model_count)
            if (context_count != 1) reject_key("LLAMA_ARG_CTX_SIZE", context_count)
            if (cache_k_count != 1) reject_key("LLAMA_ARG_CACHE_TYPE_K", cache_k_count)
            if (cache_v_count != 1) reject_key("LLAMA_ARG_CACHE_TYPE_V", cache_v_count)
            if (flash_count != 1) reject_key("LLAMA_ARG_FLASH_ATTN", flash_count)
            if (batch_count != 1) reject_key("LLAMA_ARG_BATCH", batch_count)
            if (ubatch_count != 1) reject_key("LLAMA_ARG_UBATCH", ubatch_count)
            # The checkpoint count is the seventh per-section key. The pinned
            # build defaults n_ctx_checkpoints to 32, so an absent key serves
            # thirty-two host copies of the recurrent state where the ledger
            # admits at most two, which is why the key is required rather than
            # defaulted.
            if (checkpoint_count != 1) reject_key("LLAMA_ARG_CTX_CHECKPOINTS", checkpoint_count)
            if (checkpoint_count == 1 && checkpoint_value !~ /^(0|[1-9][0-9]*)$/) {
                reject_value("LLAMA_ARG_CTX_CHECKPOINTS", checkpoint_value)
            }
            if (context_count == 1 && (context_value !~ /^[0-9]+$/ || context_value + 0 < 1)) {
                reject_value("LLAMA_ARG_CTX_SIZE", context_value)
            }
            if (batch_count == 1 && (batch_value !~ /^[0-9]+$/ || batch_value + 0 < 1)) {
                reject_value("LLAMA_ARG_BATCH", batch_value)
            }
            if (ubatch_count == 1 && (ubatch_value !~ /^[0-9]+$/ || ubatch_value + 0 < 1)) {
                reject_value("LLAMA_ARG_UBATCH", ubatch_value)
            }
            if (batch_count == 1 && ubatch_count == 1 &&
                batch_value ~ /^[0-9]+$/ && ubatch_value ~ /^[0-9]+$/ &&
                ubatch_value + 0 > batch_value + 0) {
                reject_value("LLAMA_ARG_UBATCH", ubatch_value)
            }
            if (cache_k_count == 1 && cache_k_value !~ /^(f32|f16|bf16|q8_0|q5_1|q5_0|q4_1|q4_0|iq4_nl)$/) {
                reject_value("LLAMA_ARG_CACHE_TYPE_K", cache_k_value)
            }
            if (cache_v_count == 1 && cache_v_value !~ /^(f32|f16|bf16|q8_0|q5_1|q5_0|q4_1|q4_0|iq4_nl)$/) {
                reject_value("LLAMA_ARG_CACHE_TYPE_V", cache_v_value)
            }
            if (flash_count == 1 && flash_value !~ /^(on|off|auto)$/) {
                reject_value("LLAMA_ARG_FLASH_ATTN", flash_value)
            }
            # A draft-pair section names a pair_id rather than a registry id, so
            # the ledger resolves it to the target row whose tuple the six keys
            # above are then compared against. The draft keys are compared
            # against the pair row in the same pass, and an ordinary section
            # carrying any of them is refused, because a section that gained a
            # draft outside the ledger loads a second checkpoint the resident-set
            # arithmetic never counted.
            section_is_web = is_web_section(section)
            # An MCP configuration is the execution grant. A section outside
            # the list the head marker names carrying one would reach the
            # network under rules the launch validated as tool-free, and a
            # named web section holding none serves a toggle that returns
            # nothing. The rule runs over the merged file alone: a whole-file
            # web preset also carries the configuration-free ui-mediated and
            # review-only shapes, whose grants the execution-policy rejoin and
            # the tag rules already decide.
            if (web_profile_sections == 1) {
                # every section is a web profile and the shapes differ
            } else if (section in web_sections) {
                if (mcp_count != 1) {
                    reject_key("LLAMA_ARG_MCP_SERVERS_CONFIG", mcp_count)
                }
            } else if (mcp_count != 0) {
                printf "router preset section %s carries LLAMA_ARG_MCP_SERVERS_CONFIG outside the web section list\n", \
                    section > "/dev/stderr"
                rejected = 1
            }
            is_draft_pair = (!section_is_web && (section in pair_target))
            if (!is_draft_pair) {
                for (draft_key_index = 1; draft_key_index <= draft_key_count;
                     draft_key_index++) {
                    draft_key = draft_keys[draft_key_index]
                    if (draft_count[draft_key] != 0) {
                        printf "router preset section %s carries %s without a draft pair row\n", \
                            section, draft_key > "/dev/stderr"
                        rejected = 1
                    }
                }
            }
            registry_key = section
            if (is_draft_pair) {
                registry_key = pair_target[section]
                check_draft_key("LLAMA_ARG_SPEC_TYPE", "draft-simple")
                check_draft_key("LLAMA_ARG_SPEC_DRAFT_MODEL",
                    model_root "/" registry_model[pair_draft[section]])
                check_draft_key("LLAMA_ARG_SPEC_DRAFT_N_MAX",
                    pair_n_max[section])
                check_draft_key("LLAMA_ARG_SPEC_DRAFT_P_MIN",
                    pair_p_min[section])
                check_draft_key("LLAMA_ARG_SPEC_DRAFT_CACHE_TYPE_K",
                    pair_cache_k[section])
                check_draft_key("LLAMA_ARG_SPEC_DRAFT_CACHE_TYPE_V",
                    pair_cache_v[section])
                # Placement is stated rather than inherited:
                # common_base_params_to_speculative overwrites result.devices,
                # result.n_gpu_layers, and result.tensor_buft_overrides with the
                # own draft values, so the Vulkan0 placement on the router argv
                # reaches the target and leaves the draft on automatic placement
                # unless the section names it.
                check_draft_key("LLAMA_ARG_N_GPU_LAYERS_DRAFT", "all")
                check_draft_key("spec-draft-device", "Vulkan0")
                check_draft_key("spec-draft-override-tensor", ".*=Vulkan0")
            }
            if (section_is_web) {
                model_root_prefix = model_root "/"
                if (model_count == 1 &&
                    substr(model_value, 1, length(model_root_prefix)) == model_root_prefix) {
                    registry_key = registry_id_by_model_file[substr(model_value,
                        length(model_root_prefix) + 1)]
                } else {
                    registry_key = ""
                }
                if (registry_key == "") {
                    printf "web preset section %s carries a LLAMA_ARG_MODEL outside the registry: %s\n", \
                        section, model_value > "/dev/stderr"
                    rejected = 1
                    return
                }
                # Resolution by weights file requires the registry to name each
                # file once. Two rows sharing one model_file would resolve to
                # whichever row was read last, which picks a tier and a tuple
                # by file order, so the ambiguity is refused instead.
                section_model_file = substr(model_value, length(model_root_prefix) + 1)
                if (registry_rows_by_model_file[section_model_file] != 1) {
                    printf "web preset section %s resolves to %d registry rows through model file %s\n", \
                        section, registry_rows_by_model_file[section_model_file], \
                        section_model_file > "/dev/stderr"
                    rejected = 1
                    return
                }
            }
            if (registry_count[registry_key] != 1) {
                printf "router preset section %s resolves to %d registry rows\n", \
                    section, registry_count[registry_key] > "/dev/stderr"
                rejected = 1
                return
            }
            if (registry_tier[registry_key] != "production" &&
                registry_tier[registry_key] != "candidate" &&
                registry_tier[registry_key] != "quarantine") {
                printf "router preset section %s has non-servable registry tier %s\n", \
                    section, registry_tier[registry_key] > "/dev/stderr"
                rejected = 1
            }
            if (registry_tier[registry_key] == "quarantine" &&
                (include_quarantine != 1 || !quarantined_models[registry_key])) {
                printf "router preset section %s lacks an admitted model quarantine override\n", \
                    section > "/dev/stderr"
                rejected = 1
            }
            expected_model = model_root "/" registry_model[registry_key]
            if (model_count == 1 && model_value != expected_model) {
                reject_registry_value("LLAMA_ARG_MODEL", model_value,
                    expected_model)
            }
            if (context_count == 1) {
                if (section_is_web) {
                    if (context_value + 0 > registry_ceiling[registry_key] + 0) {
                        reject_registry_value("LLAMA_ARG_CTX_SIZE", context_value,
                            "at most " registry_ceiling[registry_key])
                    }
                    # A preset persists across a registry edit, so the depth the
                    # generator validated is rechecked against the registry this
                    # launch reads. build-web-presets.sh admits a context above
                    # validated_filled_depth, or against an unmeasured `-`, only
                    # under QWEN_WEB_ALLOW_UNVALIDATED_DEPTH, whose marker forces
                    # the listener to loopback; a registry that later lowers that
                    # field, or sets it to `-`, leaves an unmarked section serving
                    # a depth no run has filled and decoded and reaching the LAN
                    # through a launch outside the web wrapper. `-` is refused by
                    # its literal spelling, since it reads as 0 in a numeric
                    # comparison and would name a nonsense expectation.
                    if (web_depth_override != 1) {
                        if (registry_filled_depth[registry_key] == "-") {
                            printf "web preset section %s serves context %s where the registry records no filled depth for %s\n", \
                                section, context_value, registry_key > "/dev/stderr"
                            rejected = 1
                        } else if (context_value + 0 > \
                            registry_filled_depth[registry_key] + 0) {
                            reject_registry_value("LLAMA_ARG_CTX_SIZE",
                                context_value,
                                "at most validated_filled_depth " \
                                    registry_filled_depth[registry_key])
                        }
                    }
                } else if (context_value != registry_context[registry_key]) {
                    reject_registry_value("LLAMA_ARG_CTX_SIZE", context_value,
                        registry_context[registry_key])
                }
            }
            if (cache_k_count == 1 && cache_k_value != registry_cache_k[registry_key]) {
                reject_registry_value("LLAMA_ARG_CACHE_TYPE_K", cache_k_value,
                    registry_cache_k[registry_key])
            }
            if (cache_v_count == 1 && cache_v_value != registry_cache_v[registry_key]) {
                reject_registry_value("LLAMA_ARG_CACHE_TYPE_V", cache_v_value,
                    registry_cache_v[registry_key])
            }
            if (flash_count == 1 && flash_value != registry_flash[registry_key]) {
                reject_registry_value("LLAMA_ARG_FLASH_ATTN", flash_value,
                    registry_flash[registry_key])
            }
            if (batch_count == 1 && batch_value != registry_batch[registry_key]) {
                reject_registry_value("LLAMA_ARG_BATCH", batch_value,
                    registry_batch[registry_key])
            }
            if (ubatch_count == 1 && ubatch_value != registry_ubatch[registry_key]) {
                reject_registry_value("LLAMA_ARG_UBATCH", ubatch_value,
                    registry_ubatch[registry_key])
            }
            # The count is compared against the ledger row of the registry key
            # the section resolved to, which for a draft-pair section is its
            # target row and for a web section its model row; a row outside
            # the ledger admits 0.
            expected_checkpoints = (registry_key in ledger_checkpoints) ? \
                ledger_checkpoints[registry_key] : "0"
            if (checkpoint_count == 1 && checkpoint_value ~ /^(0|[1-9][0-9]*)$/ &&
                checkpoint_value != expected_checkpoints) {
                printf "router preset section %s carries LLAMA_ARG_CTX_CHECKPOINTS %s, the context checkpoint ledger admits %s\n", \
                    section, checkpoint_value, expected_checkpoints > "/dev/stderr"
                rejected = 1
            }
            if (include_quarantine != 1 && quarantined_models[registry_key]) {
                printf "router preset section %s is excluded by model quarantine\n", \
                    section > "/dev/stderr"
                rejected = 1
            }
            profile_key = registry_key SUBSEP context_value SUBSEP batch_value SUBSEP \
                ubatch_value SUBSEP cache_k_value SUBSEP cache_v_value SUBSEP \
                flash_value
            quarantined_section = quarantined_models[registry_key] ||
                quarantined_profiles[profile_key] ||
                registry_tier[registry_key] == "quarantine"
            if (include_quarantine == 1 && quarantined_section) {
                if (tags_count != 1) {
                    reject_key("LLAMA_ARG_TAGS", tags_count)
                } else {
                    quarantine_tag = 0
                    default_tag = 0
                    conflicting_tier_tag = 0
                    tag_count = split(tags_value, tags, ",")
                    for (tag_index = 1; tag_index <= tag_count; tag_index++) {
                        if (tags[tag_index] == "quarantine") quarantine_tag = 1
                        if (tags[tag_index] == "default") default_tag = 1
                        if (tags[tag_index] == "production" ||
                            tags[tag_index] == "candidate" ||
                            tags[tag_index] == "archive" ||
                            tags[tag_index] == "rejected") {
                            conflicting_tier_tag = 1
                        }
                    }
                    if (!quarantine_tag || default_tag || conflicting_tier_tag) {
                        printf "router preset section %s carries unsafe quarantine tags: %s\n", \
                            section, tags_value > "/dev/stderr"
                        rejected = 1
                    }
                }
            }
            if (include_quarantine != 1 &&
                quarantined_profiles[profile_key]) {
                printf "router preset section %s is excluded by profile quarantine\n", \
                    section > "/dev/stderr"
                rejected = 1
            }
        }
        BEGIN {
            # Six draft keys carry a set_env in the pinned common/arg.cpp and
            # reach the INI as LLAMA_ARG_ names; draft layers breaks the SPEC
            # pattern as LLAMA_ARG_N_GPU_LAYERS_DRAFT. The device and tensor
            # override options carry no env at all, and get_map_key_opt in
            # common/preset.cpp indexes every option by its dash-stripped
            # argument names beside its env names, so those two reach the INI as
            # spec-draft-device and spec-draft-override-tensor.
            draft_key_count = split("LLAMA_ARG_SPEC_TYPE " \
                "LLAMA_ARG_SPEC_DRAFT_MODEL LLAMA_ARG_SPEC_DRAFT_N_MAX " \
                "LLAMA_ARG_SPEC_DRAFT_P_MIN LLAMA_ARG_SPEC_DRAFT_CACHE_TYPE_K " \
                "LLAMA_ARG_SPEC_DRAFT_CACHE_TYPE_V LLAMA_ARG_N_GPU_LAYERS_DRAFT " \
                "spec-draft-device spec-draft-override-tensor",
                draft_keys, " ")
            for (draft_key_index = 1; draft_key_index <= draft_key_count;
                 draft_key_index++) {
                is_draft_key[draft_keys[draft_key_index]] = 1
            }
            # The ledger arrives as validated rows rather than as a path, so a
            # preset persisting across a ledger edit is rejoined to the rows this
            # launch itself read and validated.
            ledger_row_count = split(draft_pair_ledger, ledger_rows, "\n")
            for (ledger_row_index = 1; ledger_row_index <= ledger_row_count;
                 ledger_row_index++) {
                if (ledger_rows[ledger_row_index] == "") continue
                split(ledger_rows[ledger_row_index], pair_fields, "\t")
                if (pair_fields[4] != "production" &&
                    pair_fields[4] != "candidate") continue
                pair_target[pair_fields[1]] = pair_fields[2]
                pair_draft[pair_fields[1]]  = pair_fields[3]
                pair_n_max[pair_fields[1]]  = pair_fields[5]
                pair_p_min[pair_fields[1]]  = pair_fields[6]
                pair_cache_k[pair_fields[1]] = pair_fields[9]
                pair_cache_v[pair_fields[1]] = pair_fields[10]
            }
            checkpoint_row_count = split(ctx_checkpoint_ledger, checkpoint_rows, "\n")
            for (checkpoint_row_index = 1; checkpoint_row_index <= checkpoint_row_count;
                 checkpoint_row_index++) {
                if (checkpoint_rows[checkpoint_row_index] == "") continue
                split(checkpoint_rows[checkpoint_row_index], checkpoint_fields, "\t")
                ledger_checkpoints[checkpoint_fields[1]] = checkpoint_fields[2]
            }
            web_section_count = split(web_section_list, web_section_names, ",")
            for (web_section_index = 1; web_section_index <= web_section_count;
                 web_section_index++) {
                if (web_section_names[web_section_index] == "") continue
                web_sections[web_section_names[web_section_index]] = 1
            }
            reset_tuple()
        }
        FILENAME == "-" {
            if ($0 == "") next
            if ($2 == "model") {
                quarantined_models[$3] = 1
            } else if ($2 == "profile") {
                profile_key = $3 SUBSEP $5 SUBSEP $6 SUBSEP $7 SUBSEP \
                    $8 SUBSEP $9 SUBSEP $10
                quarantined_profiles[profile_key] = 1
            }
            next
        }
        FILENAME == ARGV[2] {
            if ($0 ~ /^[[:space:]]*($|#)/) next
            registry_count[$1]++
            registry_model[$1] = $3
            registry_context[$1] = $5
            registry_ceiling[$1] = $6
            registry_id_by_model_file[$3] = $1
            registry_rows_by_model_file[$3]++
            registry_cache_k[$1] = $8
            registry_cache_v[$1] = $9
            registry_flash[$1] = $10
            registry_tier[$1] = $16
            registry_batch[$1] = $17
            registry_ubatch[$1] = $18
            registry_filled_depth[$1] = $19
            next
        }
        /^[[:space:]]*($|[#;])/ { next }
        /^[[:space:]]*\[/ {
            finish_section()
            section = $0
            if (section !~ /^[[:space:]]*\[[^]]+\][[:space:]]*$/) {
                printf "router preset carries malformed section header: %s\n", \
                    section > "/dev/stderr"
                rejected = 1
                section = ""
                reset_tuple()
                next
            }
            sub(/^[[:space:]]*\[/, "", section)
            sub(/\][[:space:]]*$/, "", section)
            if (section != "*" && seen_sections[section]++) {
                printf "router preset repeats section: %s\n", section > "/dev/stderr"
                rejected = 1
            }
            reset_tuple()
            next
        }
        {
            if (section == "" || section == "*") next
            separator = index($0, "=")
            if (separator == 0) next
            key = substr($0, 1, separator - 1)
            value = substr($0, separator + 1)
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", key)
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
            if (key == "LLAMA_ARG_MODEL") {
                model_count++
                model_value = value
            } else if (key == "LLAMA_ARG_CTX_SIZE") {
                context_count++
                context_value = value
            } else if (key == "LLAMA_ARG_CACHE_TYPE_K") {
                cache_k_count++
                cache_k_value = value
            } else if (key == "LLAMA_ARG_CACHE_TYPE_V") {
                cache_v_count++
                cache_v_value = value
            } else if (key == "LLAMA_ARG_FLASH_ATTN") {
                flash_count++
                flash_value = value
            } else if (key == "LLAMA_ARG_BATCH") {
                batch_count++
                batch_value = value
            } else if (key == "LLAMA_ARG_UBATCH") {
                ubatch_count++
                ubatch_value = value
            } else if (key == "LLAMA_ARG_CTX_CHECKPOINTS") {
                checkpoint_count++
                checkpoint_value = value
            } else if (key == "LLAMA_ARG_TAGS") {
                tags_count++
                tags_value = value
            } else if (key == "LLAMA_ARG_MCP_SERVERS_CONFIG") {
                mcp_count++
            } else if (is_draft_key[key]) {
                draft_count[key]++
                draft_value[key] = value
            }
        }
        END {
            finish_section()
            if (model_sections == 0) {
                print "router preset carries no model section" > "/dev/stderr"
                rejected = 1
            }
            exit rejected
        }
    ' - "$1" "$2"
}

case $bind_host in
    127.0.0.1 | localhost | 0.0.0.0) ;;
    *[!0-9.]* | '')
        printf 'bind host must be 127.0.0.1, localhost, 0.0.0.0, or an IPv4 address: %s\n' \
            "$bind_host" >&2
        exit 2
        ;;
esac

# The API key is optional at every bind address on the ordinary serving path. A
# key authenticates callers on a shared network; it grants no capability the
# model itself withholds, so a trusted network serves without one and reaches
# the page directly.
if [ -n "$api_key_file" ] && [ -z "$static_path" ]; then
    printf 'an API key file requires a static path\n' >&2
    exit 2
fi

# The web and image lanes are the exception, and the guard stands here as well
# as in the launcher because two paths construct this argv and a preset
# persists across the launch that generated it. A section reaching the network
# through its MCP server or the device through its image runtime serves an
# exposed listener only behind the bearer, so the policy refuses to build the
# tuple rather than warning about it.
#
# QWEN_WEB_LAN_OPEN=1 is the operator's decision that this exposure serves
# without that bearer, and it inverts the guard rather than lifting it: the
# open lane refuses a key file and the bearer lane refuses its absence, so the
# argv this policy builds carries the credential state the launch announced.
# remote/web-lan-exposure.sh admits the opt-in beside QWEN_WEB_LAN=1 alone, so
# the value reaching here is the one that passed that admission.
if [ "${QWEN_WEB_LAN:-0}" = 1 ]; then
    if [ "${QWEN_WEB_LAN_OPEN:-0}" = 1 ] && [ -n "$api_key_file" ]; then
        printf 'the open LAN exposure serves without a bearer, and an API key file reaches this launch: %s\n' \
            "$api_key_file" >&2
        printf 'QWEN_WEB_LAN_OPEN=1 exports QWEN_REQUIRE_API_KEY=0; a launch reaching here with a key binds %s authenticated where the launch announced an open listener\n' \
            "$bind_host" >&2
        exit 2
    fi
    if [ "${QWEN_WEB_LAN_OPEN:-0}" = 0 ] && [ -z "$api_key_file" ]; then
        printf 'the LAN exposure serves an authenticated listener, and no API key file reaches this launch\n' >&2
        printf 'the web and image launchers export QWEN_REQUIRE_API_KEY=1; a launch reaching here without one binds %s unauthenticated\n' \
            "$bind_host" >&2
        exit 2
    fi
fi

if [ ! -x "$llama_server" ]; then
    printf 'llama-server is not executable: %s\n' "$llama_server" >&2
    exit 2
fi

if [ ! -f "$model_path" ]; then
    printf 'model is not a regular file: %s\n' "$model_path" >&2
    exit 2
fi

# A served measurement launches a descriptor path so pathname replacement
# cannot change the bytes llama-server opens. The measurement runner derives
# the object tuple from its sealed runtime-input record, and the controller
# carries the tuple through tmux. The capacity policy re-stats the descriptor
# before the registry ID becomes policy authority. Resolving the proc link back
# to a pathname would lose the descriptor guarantee after a rename or unlink.
approved_model_id=${QWEN_APPROVED_MODEL_ID:-}
approved_model_file=${QWEN_APPROVED_MODEL_FILE:-}
approved_model_device=${QWEN_APPROVED_MODEL_DEVICE:-}
approved_model_inode=${QWEN_APPROVED_MODEL_INODE:-}
approved_model_bytes=${QWEN_APPROVED_MODEL_BYTES:-}
approved_identity_field_count=0
for approved_identity_value in "$approved_model_id" "$approved_model_file" \
    "$approved_model_device" "$approved_model_inode" "$approved_model_bytes"; do
    if [ -n "$approved_identity_value" ]; then
        approved_identity_field_count=$((approved_identity_field_count + 1))
    fi
done
registry_selector_kind=path
registry_selector=$model_path
approved_registry_descriptor=''
approved_registry_id=''
approved_registry_model_file=''
approved_registry_context_ceiling=''
approved_registry_cache_type_k=''
approved_registry_cache_type_v=''
approved_registry_flash_attention=''
approved_registry_batch=''
approved_registry_ubatch=''
approved_registry_validated_depth=''
if [ "$approved_identity_field_count" -ne 0 ]; then
    if [ "$approved_identity_field_count" -ne 5 ]; then
        printf 'approved model identity requires ID, file, device, inode, and bytes\n' >&2
        exit 2
    fi
    if [ "$router_enabled" = 1 ]; then
        printf 'approved single-model identity is refused in router mode\n' >&2
        exit 2
    fi
    if ! python3 - "$model_path" "$approved_model_id" \
        "$approved_model_device" "$approved_model_inode" \
        "$approved_model_bytes" <<'PY'
import os
import re
import stat
import sys

model_path, model_id, device_text, inode_text, bytes_text = sys.argv[1:]
if not re.fullmatch(r"/proc/[1-9][0-9]*/fd/[0-9]+", model_path):
    raise SystemExit("approved model identity requires a canonical proc descriptor path")
if not re.fullmatch(r"[a-z0-9][a-z0-9._-]*", model_id):
    raise SystemExit("approved model ID is malformed")
expected_values = []
for name, value, minimum in (
    ("device", device_text, 0),
    ("inode", inode_text, 1),
    ("bytes", bytes_text, 0),
):
    if not value.isascii() or not value.isdecimal():
        raise SystemExit(f"approved model {name} is malformed")
    parsed_value = int(value)
    if parsed_value < minimum or str(parsed_value) != value:
        raise SystemExit(f"approved model {name} is malformed")
    expected_values.append(parsed_value)
try:
    descriptor_status = os.stat(model_path)
except OSError as error:
    raise SystemExit(f"approved model descriptor cannot be stated: {error}") from None
if not stat.S_ISREG(descriptor_status.st_mode):
    raise SystemExit("approved model descriptor is not a regular file")
observed_values = (
    descriptor_status.st_dev,
    descriptor_status.st_ino,
    descriptor_status.st_size,
)
if observed_values != tuple(expected_values):
    raise SystemExit(
        "approved model descriptor identity differs: "
        f"expected={tuple(expected_values)} observed={observed_values}"
    )
PY
    then
        exit 2
    fi
    approved_registry_source=${QWEN_MODEL_REGISTRY:-$script_directory/models.tsv}
    if ! exec 5<"$approved_registry_source"; then
        printf 'approved model registry cannot be opened: %s\n' \
            "$approved_registry_source" >&2
        exit 2
    fi
    approved_registry_descriptor=/proc/$$/fd/5
    if ! approved_registry_row=$(python3 - "$approved_registry_descriptor" \
        "$approved_model_id" "$approved_model_file" <<'PY'
import os
import stat
import sys

registry_path, expected_id, expected_file = sys.argv[1:]


def fail(message):
    raise SystemExit(f"approved model registry row is invalid: {message}")


def canonical_positive(value, name):
    if not value.isascii() or not value.isdecimal() or value.startswith("0"):
        fail(f"{name} must be a canonical positive integer")
    parsed = int(value)
    if parsed <= 0:
        fail(f"{name} must be a canonical positive integer")
    return parsed


try:
    with open(registry_path, "rb", buffering=0) as registry_handle:
        before = os.fstat(registry_handle.fileno())
        registry_bytes = registry_handle.read()
        after = os.fstat(registry_handle.fileno())
except OSError as error:
    fail(f"registry cannot be read: {error}")
if not stat.S_ISREG(before.st_mode):
    fail("registry is not a regular file")
identity_fields = ("st_dev", "st_ino", "st_size", "st_mtime_ns")
if tuple(getattr(before, field) for field in identity_fields) != tuple(
    getattr(after, field) for field in identity_fields
):
    fail("registry identity changed while reading")
try:
    registry_text = registry_bytes.decode("utf-8")
except UnicodeDecodeError:
    fail("registry is not UTF-8")

matching_rows = []
for line_number, line in enumerate(registry_text.splitlines(), start=1):
    if not line.strip() or line.startswith("#"):
        continue
    fields = line.split("\t")
    if fields[0] != expected_id:
        continue
    if len(fields) != 22:
        fail(f"line {line_number} holds {len(fields)} fields instead of 22")
    matching_rows.append((line_number, fields))
if len(matching_rows) != 1:
    fail(f"ID {expected_id} resolves to {len(matching_rows)} rows")

line_number, fields = matching_rows[0]
if fields[2] != expected_file:
    fail(
        f"ID {expected_id} names file {fields[2]}, publisher names {expected_file}"
    )
context_ceiling = canonical_positive(fields[5], "context_ceiling")
batch = canonical_positive(fields[16], "batch")
ubatch = canonical_positive(fields[17], "ubatch")
if ubatch > batch:
    fail(f"ubatch {ubatch} exceeds batch {batch}")
cache_types = {"f32", "f16", "bf16", "q8_0", "q5_1", "q5_0", "q4_1", "q4_0", "iq4_nl"}
if fields[7] not in cache_types:
    fail(f"cache_type_k is invalid: {fields[7]}")
if fields[8] not in cache_types:
    fail(f"cache_type_v is invalid: {fields[8]}")
if fields[9] not in {"on", "off", "auto"}:
    fail(f"flash_attention is invalid: {fields[9]}")
validated_depth = fields[18]
if validated_depth != "-":
    canonical_positive(validated_depth, "validated_filled_depth")
print(
    fields[0],
    fields[2],
    context_ceiling,
    fields[7],
    fields[8],
    fields[9],
    batch,
    ubatch,
    validated_depth,
    sep="\t",
)
PY
    ); then
        exit 2
    fi
    IFS="$(printf '\t')" read -r approved_registry_id \
        approved_registry_model_file approved_registry_context_ceiling \
        approved_registry_cache_type_k approved_registry_cache_type_v \
        approved_registry_flash_attention approved_registry_batch \
        approved_registry_ubatch approved_registry_validated_depth <<EOF
$approved_registry_row
EOF
    registry_selector_kind=id
    registry_selector=$approved_model_id
else
    ordinary_model_root=${QWEN_MODEL_ROOT:-"${HOME:?}/models"}
    if ! python3 - "$model_path" "$ordinary_model_root" <<'PY'
import os
import re
import sys
from pathlib import Path

model_path, model_root = sys.argv[1:]
collapsed_path = re.sub(r"/+", "/", model_path)
normalized_path = os.path.normpath(collapsed_path)
descriptor_aliases = (
    r"/proc/(?:self|thread-self|[1-9][0-9]*)/fd/[0-9]+",
    r"/proc/(?:self|[1-9][0-9]*)/task/(?:self|[1-9][0-9]*)/fd/[0-9]+",
    r"/dev/fd/[0-9]+",
    r"/dev/stdin",
)
if any(re.fullmatch(pattern, normalized_path) for pattern in descriptor_aliases):
    raise SystemExit("descriptor-backed model path requires approved model identity")
if not os.path.isabs(model_path) or normalized_path != model_path:
    raise SystemExit("ordinary model path must be canonical and absolute")
try:
    resolved_root = Path(model_root).resolve(strict=True)
    resolved_model = Path(model_path).resolve(strict=True)
except OSError as error:
    raise SystemExit(f"ordinary model path cannot be resolved: {error}") from None
if str(resolved_model) != model_path:
    raise SystemExit("ordinary model path must not contain symbolic links")
try:
    resolved_model.relative_to(resolved_root)
except ValueError:
    raise SystemExit(
        f"ordinary model path escapes QWEN_MODEL_ROOT: {model_path}"
    ) from None
PY
    then
        exit 2
    fi
fi

registry_model_field() {
    if [ "$registry_selector_kind" = id ]; then
        case $1 in
            id) printf '%s\n' "$approved_registry_id" ;;
            model_file) printf '%s\n' "$approved_registry_model_file" ;;
            context_ceiling) printf '%s\n' "$approved_registry_context_ceiling" ;;
            cache_type_k) printf '%s\n' "$approved_registry_cache_type_k" ;;
            cache_type_v) printf '%s\n' "$approved_registry_cache_type_v" ;;
            flash_attention) printf '%s\n' "$approved_registry_flash_attention" ;;
            batch) printf '%s\n' "$approved_registry_batch" ;;
            ubatch) printf '%s\n' "$approved_registry_ubatch" ;;
            validated_filled_depth) printf '%s\n' "$approved_registry_validated_depth" ;;
            *) return 2 ;;
        esac
        return 0
    fi
    "$script_directory/model-registry.sh" path "$registry_selector" "$1"
}

registry_checkpoint_count() {
    if [ "$registry_selector_kind" = id ]; then
        QWEN_MODEL_REGISTRY=$approved_registry_descriptor \
            "$script_directory/model-registry.sh" ctx-checkpoint "$1"
        return
    fi
    "$script_directory/model-registry.sh" ctx-checkpoint "$1"
}

case $context_size in
    '' | *[!0-9]*)
        printf 'context size must be a positive integer\n' >&2
        exit 2
        ;;
esac

if [ "$context_size" -eq 0 ]; then
    printf 'context size must be a positive integer\n' >&2
    exit 2
fi

# Router children take their complete tuple from the preset file. The model path
# supplied to this process is only the largest installed preflight subject, so
# applying that one row's context ceiling to the router-wide listener rejects a
# valid preset whose sections each carry their own admitted depth.
if [ "$router_enabled" != 1 ]; then
# The admitted depth is a property of the checkpoint rather than of the
# appliance: KV cost scales with full-attention layer count and key-value head
# width, so the 9B pays more per token of context than the 2B at the same
# depth. remote/models.tsv carries one ceiling per row and this gate reads it.
# A checkpoint outside the registry keeps the depth that the 24K allocation of
# 2,974 MiB was measured against.
registry_ceiling=$(registry_model_field context_ceiling 2>/dev/null) || \
    registry_ceiling=''
case $registry_ceiling in
    '' | *[!0-9]*) registry_ceiling=24576 ;;
esac

# Cache representation, Flash Attention, and context depth form one admission
# tuple. A registry ceiling belongs only to the tuple stored in that row. An
# experiment that changes any member supplies its own positive conservative
# ceiling explicitly; silently reusing the registered ceiling would present an
# unvalidated allocation as admitted policy.
registry_cache_type_k=$(registry_model_field cache_type_k 2>/dev/null) || \
    registry_cache_type_k=''
registry_cache_type_v=$(registry_model_field cache_type_v 2>/dev/null) || \
    registry_cache_type_v=''
registry_flash_attention=$(registry_model_field flash_attention 2>/dev/null) || \
    registry_flash_attention=''
[ -n "$registry_cache_type_k" ] || registry_cache_type_k=q8_0
[ -n "$registry_cache_type_v" ] || registry_cache_type_v=q4_0
[ -n "$registry_flash_attention" ] || registry_flash_attention=on

cache_type_k=${QWEN_CACHE_TYPE_K:-$registry_cache_type_k}
cache_type_v=${QWEN_CACHE_TYPE_V:-$registry_cache_type_v}
flash_attention=${QWEN_FLASH_ATTN:-$registry_flash_attention}
for cache_type in "$cache_type_k" "$cache_type_v"; do
    if ! "$script_directory/model-registry.sh" validate-cache-type "$cache_type"; then
        printf 'cache type is outside the set llama-server accepts: %s\n' \
            "$cache_type" >&2
        exit 2
    fi
done
case $flash_attention in
    on | off | auto) ;;
    *)
        printf 'flash attention must be on, off, or auto: %s\n' \
            "$flash_attention" >&2
        exit 2
        ;;
esac

maximum_context_size=$registry_ceiling
if [ "$cache_type_k" != "$registry_cache_type_k" ] ||
   [ "$cache_type_v" != "$registry_cache_type_v" ] ||
   [ "$flash_attention" != "$registry_flash_attention" ]; then
    override_ceiling=${QWEN_CACHE_OVERRIDE_CONTEXT_CEILING:-}
    case $override_ceiling in
        '' | *[!0-9]* | 0)
            printf 'cache-policy overrides require a positive QWEN_CACHE_OVERRIDE_CONTEXT_CEILING\n' >&2
            exit 2
            ;;
    esac
    if [ "$override_ceiling" -gt "$registry_ceiling" ]; then
        printf 'cache override ceiling must not exceed the registered ceiling: %s > %s\n' \
            "$override_ceiling" "$registry_ceiling" >&2
        exit 2
    fi
    maximum_context_size=$override_ceiling
fi
if [ "$context_size" -gt "$maximum_context_size" ]; then
    printf 'context size exceeds the admitted ceiling for this cache policy: %s > %s\n' \
        "$context_size" "$maximum_context_size" >&2
    exit 2
fi

# Submission geometry comes from the row rather than from a constant, because
# the ceiling and the geometry are one claim. At 16384 the same checkpoint,
# cache triple, Flash Attention state, and device wedged the amdgpu compute ring
# at 2048/512 and completed twice at 128/32, so a depth is admitted under a
# geometry and reading the ceiling without it reads half the measurement.
registry_batch=$(registry_model_field batch 2>/dev/null) || registry_batch=''
registry_ubatch=$(registry_model_field ubatch 2>/dev/null) || registry_ubatch=''
case $registry_batch in '' | *[!0-9]*) registry_batch=128 ;; esac
case $registry_ubatch in '' | *[!0-9]*) registry_ubatch=32 ;; esac
batch_size=${QWEN_BATCH_SIZE:-$registry_batch}
ubatch_size=${QWEN_UBATCH_SIZE:-$registry_ubatch}
for submission_value in "$batch_size" "$ubatch_size"; do
    case $submission_value in
        '' | *[!0-9]* | 0)
            printf 'batch and ubatch must be positive integers: %s\n' \
                "$submission_value" >&2
            exit 2
            ;;
    esac
done
if [ "$ubatch_size" -gt "$batch_size" ]; then
    printf 'ubatch exceeds batch: %s > %s\n' "$ubatch_size" "$batch_size" >&2
    exit 2
fi

# A quarantined profile names a tuple that produced a device failure. The launch
# refuses to construct it rather than warning about it, because the failure it
# reproduces resets the compute ring on a live desktop.
registry_id=$(registry_model_field id 2>/dev/null) || registry_id=''
if [ -n "$registry_id" ]; then
    quarantine_profiles=$("$script_directory/model-registry.sh" \
        quarantine-profiles standalone)
    quarantine_hit=$(awk -F'\t' -v id="$registry_id" \
        -v depth="$context_size" -v batch="$batch_size" \
        -v ubatch="$ubatch_size" -v cache_k="$cache_type_k" \
        -v cache_v="$cache_type_v" -v flash="$flash_attention" '
        $1 == id && $2 == depth && $3 == batch && $4 == ubatch &&
        $5 == cache_k && $6 == cache_v && $7 == flash { print $1; exit }
    ' <<EOF
$quarantine_profiles
EOF
    )
    if [ -n "$quarantine_hit" ]; then
        printf 'this tuple is quarantined: %s at depth %s, batch %s, ubatch %s, K %s, V %s, flash attention %s\n' \
            "$registry_id" "$context_size" "$batch_size" "$ubatch_size" \
            "$cache_type_k" "$cache_type_v" "$flash_attention" >&2
        printf 'the reason record is evidence/quarantine/%s-d%s-b%s-ub%s.md\n' \
            "$registry_id" "$context_size" "$batch_size" "$ubatch_size" >&2
        exit 2
    fi
fi

# The allocation and the validated depth are separate claims and the status line
# carries both, so a served depth above anything measured to fill and decode is
# a visible gap rather than an implied guarantee.
registry_validated_depth=$(registry_model_field validated_filled_depth \
    2>/dev/null) || registry_validated_depth=''
[ -n "$registry_validated_depth" ] || registry_validated_depth=-
if [ "$registry_validated_depth" = - ]; then
    printf 'depth_validation admitted=%s validated=none geometry=%s/%s\n' \
        "$context_size" "$batch_size" "$ubatch_size" >&2
elif [ "$context_size" -gt "$registry_validated_depth" ]; then
    printf 'depth_validation admitted=%s validated=%s geometry=%s/%s allocation_beyond_validation=yes\n' \
        "$context_size" "$registry_validated_depth" "$batch_size" \
        "$ubatch_size" >&2
else
    printf 'depth_validation admitted=%s validated=%s geometry=%s/%s\n' \
        "$context_size" "$registry_validated_depth" "$batch_size" \
        "$ubatch_size" >&2
fi
fi

case $server_port in
    '' | *[!0-9]*)
        printf 'port must be an integer from 1024 through 65535\n' >&2
        exit 2
        ;;
esac

if [ "$server_port" -lt 1024 ] || [ "$server_port" -gt 65535 ]; then
    printf 'port must be an integer from 1024 through 65535\n' >&2
    exit 2
fi

if [ -n "$static_path" ] && [ ! -f "$static_path/index.html" ]; then
    printf 'static path must contain index.html: %s\n' "$static_path" >&2
    exit 2
fi

if [ -n "$api_key_file" ] && [ ! -s "$api_key_file" ]; then
    printf 'API key file must be a non-empty regular file: %s\n' "$api_key_file" >&2
    exit 2
fi

if env | awk -F= '$1 ~ /^LLAMA_ARG_/ { found = 1 } END { exit !found }'; then
    printf 'LLAMA_ARG_* environment overrides are forbidden by the fixed policy\n' >&2
    exit 2
fi

# Router mode serves every admitted checkpoint behind one listener and lets the
# picker choose per chat. llama-server builds a base preset from this argv,
# strips the SSL, API key, and models-* keys from it, and cascades the rest onto
# each child it spawns, so every guard below reaches the child unchanged and the
# preset file supplies only what differs per checkpoint.
#
# models-max is 1 rather than the upstream default of 4. The 4B alone peaks at
# 2029 MiB of a 2048 MiB VRAM carve-out with 2700 MiB more in GTT, so a second
# resident model competes for a pool already saturated by one. Switching models
# unloads the previous one, which costs a reload and buys a device that fits.
router_presets=${QWEN_ROUTER_PRESETS:-"${HOME:?}/qwen-webui-state/router-presets.ini"}
router_registry=${QWEN_MODEL_REGISTRY:-"$script_directory/models.tsv"}
router_quarantine_registry=${QWEN_QUARANTINE_REGISTRY:-$script_directory/quarantine.tsv}
router_draft_pair_registry=${QWEN_DRAFT_PAIRS:-$script_directory/draft-pairs.tsv}
# model-registry.sh resolves the checkpoint ledger from the same variable and
# the same default, so the path this launch hashes is the path whose rows the
# tuple validator compared each section against.
router_ctx_checkpoint_ledger=${QWEN_CTX_CHECKPOINT_LEDGER:-$script_directory/ctx-checkpoints.tsv}
router_model_root=${QWEN_MODEL_ROOT:-"${HOME:?}/models"}
router_web_profiles_environment=${QWEN_WEB_PROFILES:-}
router_web_profiles=$script_directory/web-profiles.tsv
router_web_profiles_guard_path=-
router_web_profiles_guard_sha256=-
router_draft_pair_guard_path=-
router_draft_pair_guard_sha256=-
web_presets_from_preset=0
web_sections_from_preset=
# The image lane reads as withheld until a preset marker names it, which is what
# a preset generated before the lane and a preset that armed nothing both say.
router_image_profile=
router_image_profiles=
router_image_profiles_sha256=
router_web_mode=0
router_max=${QWEN_ROUTER_MAX:-1}
router_preset_expected_sha256=${QWEN_ROUTER_PRESET_SHA256:-}
verify_router_preset_identity() {
    if [ -z "$router_preset_expected_sha256" ]; then
        return 0
    fi
    if [ "${#router_preset_expected_sha256}" -ne 64 ]; then
        printf 'router preset SHA-256 must hold 64 lowercase hexadecimal characters\n' >&2
        return 1
    fi
    case $router_preset_expected_sha256 in
        *[!0-9a-f]*)
            printf 'router preset SHA-256 must hold 64 lowercase hexadecimal characters\n' >&2
            return 1
            ;;
    esac
    if ! router_preset_identity=$(sha256sum "$router_presets"); then
        printf 'router preset identity cannot be measured: %s\n' \
            "$router_presets" >&2
        return 1
    fi
    router_preset_actual_sha256=${router_preset_identity%% *}
    if [ "$router_preset_actual_sha256" != "$router_preset_expected_sha256" ]; then
        printf 'router preset identity changed: expected %s, measured %s\n' \
            "$router_preset_expected_sha256" "$router_preset_actual_sha256" >&2
        return 1
    fi
}
measure_router_authority_identity() {
    authority_name=$1
    authority_path=$2
    if ! authority_identity=$(sha256sum "$authority_path"); then
        printf '%s identity cannot be measured: %s\n' \
            "$authority_name" "$authority_path" >&2
        return 1
    fi
    printf '%s\n' "${authority_identity%% *}"
}
# execution_policy is the security boundary the web ledger states, and a preset
# persists across an edit to it. build-web-presets.sh emits a section only for a
# validator-gated or ui-mediated row and writes that word into LLAMA_ARG_TAGS, so
# a row moved to refused, or removed from the ledger, leaves a persisted section
# launching an MCP configuration the ledger no longer authorizes. The launch
# rejoins each section to the current ledger by its profile_id, which is the
# section name build-web-presets.sh writes, and requires the row to exist, to
# carry an emitting policy, and to carry the same policy the section's tags
# claim: a row moved from validator-gated to ui-mediated leaves a persisted
# LLAMA_ARG_MCP_SERVERS_CONFIG in a section the ledger now says reaches no
# network.
#
# validate_current_router_authorities runs this immediately before the exec, so
# the ledger's last read is one link earlier than the preset and the two
# registries, whose digests qwen-router-exec-guard.sh remeasures after the
# Vulkan wrapper configures the environment.
validate_web_preset_execution_policies() {
    awk -F'\t' -v ledger="$1" -v authorizer_ready="$3" \
        -v web_all_sections="${4:-0}" -v web_section_list="${5:-}" '
        # The merged preset holds registry sections beside the web one, and the
        # web ledger holds a row for neither a registry id nor a pair id. The
        # rejoin therefore runs over the sections the head marker names, and a
        # section outside that list is validated by the tuple rules alone.
        function is_web_section(name) {
            return web_all_sections == 1 || (name in web_sections)
        }
        function policy_from_tags(tags,   tag_count, tags_parts, tag_index) {
            tag_count = split(tags, tags_parts, ",")
            for (tag_index = 1; tag_index <= tag_count; tag_index++) {
                if (tags_parts[tag_index] == "validator-gated" ||
                    tags_parts[tag_index] == "ui-mediated" ||
                    tags_parts[tag_index] == "refused") {
                    return tags_parts[tag_index]
                }
            }
            return ""
        }
        function finish_section(   ledger_policy, section_policy) {
            if (section == "" || section == "*") return
            if (!is_web_section(section)) return
            # A review-only section names a vision checkpoint rather than a web
            # profile, so the web ledger holds no row for it and the rejoin that
            # guards an execution grant has nothing to rejoin. What makes it
            # safe is that it holds no grant at all: the tuple validator has
            # already bound it to one registry row at that row own geometry,
            # and an MCP configuration reaching it would arm a tool the page
            # never offers a reviewer, so its absence is required here.
            if (tags_value ~ /(^|,)review-only(,|$)/) {
                if (seen_mcp_configuration) {
                    printf "web preset section %s is review-only and carries LLAMA_ARG_MCP_SERVERS_CONFIG\n", \
                        section > "/dev/stderr"
                    rejected = 1
                }
                return
            }
            if (!(section in ledger_execution_policy)) {
                printf "web preset section %s names a profile the ledger %s no longer carries\n", \
                    section, ledger > "/dev/stderr"
                rejected = 1
                return
            }
            ledger_policy = ledger_execution_policy[section]
            if (ledger_policy != "validator-gated" && ledger_policy != "ui-mediated") {
                printf "web preset section %s carries ledger execution_policy %s, which emits no section\n", \
                    section, ledger_policy > "/dev/stderr"
                rejected = 1
                return
            }
            if (ledger_policy == "validator-gated" && authorizer_ready != 1) {
                printf "web preset section %s requires QWEN_WEB_AUTHORIZER_READY=1\n", \
                    section > "/dev/stderr"
                rejected = 1
            }
            section_policy = policy_from_tags(tags_value)
            if (section_policy != ledger_policy) {
                printf "web preset section %s claims execution_policy %s where the ledger carries %s\n", \
                    section, section_policy, ledger_policy > "/dev/stderr"
                rejected = 1
            }
        }
        BEGIN {
            web_section_count = split(web_section_list, web_section_names, ",")
            for (web_section_index = 1; web_section_index <= web_section_count;
                 web_section_index++) {
                if (web_section_names[web_section_index] == "") continue
                web_sections[web_section_names[web_section_index]] = 1
            }
        }
        FILENAME == ledger {
            if ($0 ~ /^[[:space:]]*($|#)/) next
            ledger_execution_policy[$1] = $12
            next
        }
        /^[[:space:]]*($|[#;])/ { next }
        /^[[:space:]]*\[/ {
            finish_section()
            section = $0
            sub(/^[[:space:]]*\[/, "", section)
            sub(/\][[:space:]]*$/, "", section)
            tags_value = ""
            seen_mcp_configuration = 0
            next
        }
        {
            if (section == "" || section == "*") next
            separator = index($0, "=")
            if (separator == 0) next
            key = substr($0, 1, separator - 1)
            value = substr($0, separator + 1)
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", key)
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
            if (key == "LLAMA_ARG_TAGS") tags_value = value
            if (key == "LLAMA_ARG_MCP_SERVERS_CONFIG") seen_mcp_configuration = 1
        }
        END {
            finish_section()
            exit rejected
        }
    ' "$1" "$2"
}

# The image lane is the second execution grant a merged preset can carry, and
# the section's own MCP configuration rather than the marker is what the child
# spawns. The rejoin therefore runs in both directions: a preset naming an image
# profile requires every web section's configuration to carry an image server
# bound to that profile and to that section as its language profile, and a
# preset naming none requires every configuration to carry no image server at
# all. remote/read-image-mcp-server.py is the one parser both this policy and
# the image launch library read that file with.
#
# A marker-free preset is one generated before this lane, so it reads as a
# withheld lane and its sections are held to the same absence.
router_section_mcp_configurations() {
    awk '
        /^[[:space:]]*($|[#;])/ { next }
        /^[[:space:]]*\[/ {
            section = $0
            sub(/^[[:space:]]*\[/, "", section)
            sub(/\][[:space:]]*$/, "", section)
            next
        }
        {
            if (section == "") next
            separator = index($0, "=")
            if (separator == 0) next
            key = substr($0, 1, separator - 1)
            value = substr($0, separator + 1)
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", key)
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
            if (key == "LLAMA_ARG_MCP_SERVERS_CONFIG") {
                printf "%s\t%s\n", section, value
            }
        }
    ' "$1"
}

validate_image_preset_lane() {
    image_lane_rejected=0
    image_lane_configurations=$(router_section_mcp_configurations \
        "$router_presets")
    while IFS='	' read -r image_lane_section image_lane_configuration; do
        [ -n "$image_lane_section" ] || continue
        if ! image_lane_report=$("$script_directory/read-image-mcp-server.py" \
            "$image_lane_configuration"); then
            printf 'router preset section %s names an MCP configuration this policy cannot read: %s\n' \
                "$image_lane_section" "$image_lane_configuration" >&2
            image_lane_rejected=1
            continue
        fi
        image_lane_state=$(printf '%s\n' "$image_lane_report" |
            sed -n 's/^image_server=//p')
        if [ -z "$router_image_profile" ]; then
            if [ "$image_lane_state" = present ]; then
                printf 'router preset section %s carries an image server where the preset names no image profile\n' \
                    "$image_lane_section" >&2
                printf 'regenerate the preset tree with remote/build-router-presets.sh\n' >&2
                image_lane_rejected=1
            fi
            continue
        fi
        if [ "$image_lane_state" != present ]; then
            printf 'router preset names image profile %s and section %s carries no image server\n' \
                "$router_image_profile" "$image_lane_section" >&2
            image_lane_rejected=1
            continue
        fi
        image_lane_profile=$(printf '%s\n' "$image_lane_report" |
            sed -n 's/^QWEN_IMAGE_PROFILE=//p')
        image_lane_language=$(printf '%s\n' "$image_lane_report" |
            sed -n 's/^QWEN_IMAGE_LANGUAGE_PROFILE=//p')
        if [ "$image_lane_profile" != "$router_image_profile" ]; then
            printf 'router preset section %s arms image profile %s where the preset names %s\n' \
                "$image_lane_section" "$image_lane_profile" \
                "$router_image_profile" >&2
            image_lane_rejected=1
        fi
        if [ "$image_lane_language" != "$image_lane_section" ]; then
            printf 'router preset section %s carries an image server bound to language profile %s\n' \
                "$image_lane_section" "$image_lane_language" >&2
            printf 'the grant binds the language profile and the image profile together, so the section signs for itself\n' >&2
            image_lane_rejected=1
        fi
    done <<IMAGE_LANE_CONFIGURATIONS
$image_lane_configurations
IMAGE_LANE_CONFIGURATIONS
    [ "$image_lane_rejected" = 0 ] || return 1
    [ -n "$router_image_profile" ] || return 0
    # A preset persists across an edit to the image ledger, so the row it names
    # is read again here: a row moved to `refused` or removed outright refuses
    # the launch rather than serving a persisted configuration that still names
    # it. The digest binds every row rather than only that one field.
    if ! image_lane_identity=$(sha256sum -- "$router_image_profiles"); then
        printf 'image profile ledger identity cannot be measured: %s\n' \
            "$router_image_profiles" >&2
        return 1
    fi
    image_lane_actual_sha256=${image_lane_identity%% *}
    if [ "$image_lane_actual_sha256" != "$router_image_profiles_sha256" ]; then
        printf 'image profile ledger identity changed: expected %s, measured %s\n' \
            "$router_image_profiles_sha256" "$image_lane_actual_sha256" >&2
        return 1
    fi
    if ! image_lane_row=$(QWEN_IMAGE_PROFILES=$router_image_profiles \
        "$script_directory/image-registry.sh" profile \
        "$router_image_profile" 2>/dev/null); then
        printf 'the preset names image profile %s, which %s holds no row for\n' \
            "$router_image_profile" "$router_image_profiles" >&2
        return 1
    fi
    image_lane_policy=$(printf '%s\n' "$image_lane_row" |
        sed -n 's/^execution_policy=//p')
    if [ "$image_lane_policy" != validator-gated ]; then
        printf 'image profile %s carries execution_policy %s, and only validator-gated reaches a runtime\n' \
            "$router_image_profile" "${image_lane_policy:-<absent>}" >&2
        return 1
    fi
}

verify_web_profiles_identity() {
    if [ "$router_web_mode" != 1 ]; then
        return 0
    fi
    if ! web_profiles_identity=$(sha256sum -- "$router_web_profiles"); then
        printf 'web profile ledger identity cannot be measured: %s\n' \
            "$router_web_profiles" >&2
        return 1
    fi
    web_profiles_actual_sha256=${web_profiles_identity%% *}
    if [ "$web_profiles_actual_sha256" != "$router_web_profiles_guard_sha256" ]; then
        printf 'web profile ledger identity changed: expected %s, measured %s\n' \
            "$router_web_profiles_guard_sha256" \
            "$web_profiles_actual_sha256" >&2
        return 1
    fi
}

validate_current_router_authorities() {
    if ! router_quarantine_rows=$(
        "$script_directory/model-registry.sh" quarantine-rows router-child
    ); then
        printf 'router quarantine authority is unavailable\n' >&2
        return 1
    fi
    # The draft-pair ledger is a third authority the router preset persists
    # across, so it is read and validated whole at every router launch and its
    # rows are what a pair section is rejoined to. A web preset names profiles
    # rather than pair ids and build-web-presets.sh emits no draft key, so that
    # path resolves against an empty ledger and joins nothing.
    router_draft_pair_rows=''
    if [ "$web_presets_from_preset" != 1 ]; then
        # The merged preset carries the pair sections beside the web one, so
        # the ledger they are rejoined to is read for that shape too.
        if ! router_draft_pair_rows=$(
            "$script_directory/model-registry.sh" draft-pairs
        ); then
            printf 'router draft pair authority is unavailable\n' >&2
            return 1
        fi
    fi
    # The context checkpoint ledger is read whole at every router launch, for
    # web presets as much as router presets, since every section carries the
    # count and a persisted preset is rejoined to the rows this launch read.
    if ! router_ctx_checkpoint_rows=$(
        "$script_directory/model-registry.sh" ctx-checkpoints
    ); then
        printf 'router context checkpoint authority is unavailable\n' >&2
        return 1
    fi
    if ! validate_router_preset_tuples "$router_registry" "$router_presets" \
        "$router_model_root" "$router_quarantine_rows" \
        "$quarantine_override_from_preset" "$web_presets_from_preset" \
        "$web_depth_override_from_preset" "$router_draft_pair_rows" \
        "$router_ctx_checkpoint_rows" "$web_sections_from_preset"; then
        printf 'router presets do not carry complete admitted tuples: %s\n' \
            "$router_presets" >&2
        return 1
    fi
    if [ "$router_web_mode" = 1 ]; then
        verify_web_profiles_identity || return 1
        if [ ! -r "$router_web_profiles" ]; then
            printf 'web profile ledger is unreadable: %s\n' \
                "$router_web_profiles" >&2
            return 1
        fi
        if ! validate_web_preset_execution_policies "$router_web_profiles" \
            "$router_presets" "$router_web_authorizer_ready" \
            "$web_presets_from_preset" "$web_sections_from_preset"; then
            printf 'web preset sections lost their ledger execution grant: %s\n' \
                "$router_presets" >&2
            printf 'regenerate the preset tree with remote/build-web-presets.sh\n' >&2
            return 1
        fi
    fi
    if ! validate_image_preset_lane; then
        printf 'the router preset image lane fails its own markers: %s\n' \
            "$router_presets" >&2
        return 1
    fi
}
if [ "$router_enabled" = 1 ]; then
    if [ ! -r "$router_presets" ]; then
        printf 'router presets are unreadable: %s\n' "$router_presets" >&2
        printf 'generate them with remote/build-router-presets.sh\n' >&2
        exit 2
    fi
    verify_router_preset_identity || exit 2
    if [ ! -r "$router_registry" ]; then
        printf 'router model registry is unreadable: %s\n' "$router_registry" >&2
        exit 2
    fi
    if [ ! -r "$router_quarantine_registry" ]; then
        printf 'router quarantine authority is unavailable: %s\n' \
            "$router_quarantine_registry" >&2
        exit 2
    fi
    case $router_max in
        '' | *[!0-9]*)
            printf 'router model limit must be a non-negative integer: %s\n' \
                "$router_max" >&2
            exit 2
            ;;
    esac
    # build-web-presets.sh names its sections for profile ids and chooses a
    # depth inside context_ceiling, so its head marker selects the section
    # resolution the tuple validator applies. The marker is the file's own
    # provenance, which is what makes the resolution survive a preset that
    # persists across a later launch.
    web_presets_from_preset=$(sed -n 's/^# qwen_web_presets=\([01]\)$/\1/p' \
        "$router_presets")
    case $web_presets_from_preset in
        '') web_presets_from_preset=0 ;;
        0 | 1) ;;
        *)
            printf 'router presets carry ambiguous web provenance: %s\n' \
                "$router_presets" >&2
            exit 2
            ;;
    esac
    # build-router-presets.sh names the sections it folded into the roster
    # preset, so the launch validates exactly those under the web rules and
    # every other section under the registry rules. `-` states that the file
    # holds registry sections alone, which is what a generation without the
    # authorizer marker writes.
    web_sections_from_preset=$(sed -n 's/^# qwen_web_sections=//p' \
        "$router_presets")
    case $web_sections_from_preset in
        '' | '-') web_sections_from_preset='' ;;
        *[!A-Za-z0-9_,-]* | ,* | *, | *,,*)
            printf 'router presets carry a malformed web section list: %s\n' \
                "$web_sections_from_preset" >&2
            exit 2
            ;;
    esac
    if [ "$web_presets_from_preset" = 1 ] &&
        [ -n "$web_sections_from_preset" ]; then
        printf 'router presets claim both a whole-file web provenance and a web section list: %s\n' \
            "$router_presets" >&2
        exit 2
    fi
    # Either provenance puts a section under the web rules, so the ledger
    # identity markers are required and validated for both shapes.
    router_web_mode=0
    if [ "$web_presets_from_preset" = 1 ] ||
        [ -n "$web_sections_from_preset" ]; then
        router_web_mode=1
    fi
    # Both generators write `# qwen_image_profile=` and spell a withheld lane
    # `-`, so an absent marker is a preset generated before the lane and reads
    # the same way. A named profile requires the ledger path and digest beside
    # it, since the rejoin that keeps a revoked row from serving reads that
    # exact file.
    router_image_profile=$(sed -n 's/^# qwen_image_profile=//p' \
        "$router_presets")
    case $router_image_profile in
        '' | '-') router_image_profile='' ;;
        [A-Za-z0-9]*)
            # image-registry.sh's own identifier() admits a period after the
            # first character, and a ledger-valid id such as sdxs.512-arm-a
            # carries one, so this vocabulary matches identifier() exactly
            # rather than rejecting a marker the ledger already accepted.
            case $router_image_profile in
                *[!A-Za-z0-9._-]*)
                    printf 'router presets carry a malformed image profile marker: %s\n' \
                        "$router_image_profile" >&2
                    exit 2
                    ;;
            esac
            ;;
        *)
            printf 'router presets carry a malformed image profile marker: %s\n' \
                "$router_image_profile" >&2
            exit 2
            ;;
    esac
    router_image_profiles=$(sed -n 's/^# qwen_image_profiles_path=//p' \
        "$router_presets")
    router_image_profiles_sha256=$(sed -n \
        's/^# qwen_image_profiles_sha256=//p' "$router_presets")
    if [ -n "$router_image_profile" ]; then
        case $router_image_profiles in
            /*) ;;
            *)
                printf 'router presets name image profile %s and omit an absolute image ledger path: %s\n' \
                    "$router_image_profile" "$router_presets" >&2
                exit 2
                ;;
        esac
        if [ "${#router_image_profiles_sha256}" -ne 64 ]; then
            printf 'image preset ledger SHA-256 must hold 64 lowercase hexadecimal characters\n' >&2
            exit 2
        fi
        case $router_image_profiles_sha256 in
            *[!0-9a-f]*)
                printf 'image preset ledger SHA-256 must hold 64 lowercase hexadecimal characters\n' >&2
                exit 2
                ;;
        esac
        # An image server reaches the device from a section the web ledger
        # emitted, so a lane armed over a file naming no web section would sign
        # a grant for a profile the launch never resolves.
        if [ "$router_web_mode" != 1 ]; then
            printf 'router presets name image profile %s and carry no web section\n' \
                "$router_image_profile" >&2
            exit 2
        fi
    fi
    web_profiles_path_from_preset=$(sed -n \
        's/^# qwen_web_profiles_path=//p' "$router_presets")
    web_profiles_sha256_from_preset=$(sed -n \
        's/^# qwen_web_profiles_sha256=//p' "$router_presets")
    if [ "$router_web_mode" = 1 ]; then
        case $web_profiles_path_from_preset in
            /*) ;;
            *)
                printf 'web presets omit an absolute web profile ledger path: %s\n' \
                    "$router_presets" >&2
                exit 2
                ;;
        esac
        if [ "${#web_profiles_sha256_from_preset}" -ne 64 ]; then
            printf 'web preset ledger SHA-256 must hold 64 lowercase hexadecimal characters\n' >&2
            exit 2
        fi
        case $web_profiles_sha256_from_preset in
            *[!0-9a-f]*)
                printf 'web preset ledger SHA-256 must hold 64 lowercase hexadecimal characters\n' >&2
                exit 2
                ;;
        esac
        if [ -n "$router_web_profiles_environment" ] &&
            [ "$router_web_profiles_environment" != "$web_profiles_path_from_preset" ]; then
            printf 'QWEN_WEB_PROFILES names %s where the preset binds %s\n' \
                "$router_web_profiles_environment" \
                "$web_profiles_path_from_preset" >&2
            exit 2
        fi
        router_web_profiles=$web_profiles_path_from_preset
        router_web_profiles_guard_path=$web_profiles_path_from_preset
        router_web_profiles_guard_sha256=$web_profiles_sha256_from_preset
        router_web_authorizer_ready=${QWEN_WEB_AUTHORIZER_READY:-0}
        case $router_web_authorizer_ready in
            0 | 1) ;;
            *)
                printf 'QWEN_WEB_AUTHORIZER_READY must be 0 or 1: %s\n' \
                    "$router_web_authorizer_ready" >&2
                exit 2
                ;;
        esac
    elif [ -n "$(printf '%s%s' "$web_profiles_path_from_preset" \
        "$web_profiles_sha256_from_preset" | tr -d '\n-')" ]; then
        # A generation that armed no web lane writes `-` for both, so the
        # markers state their own emptiness rather than being absent. A
        # non-empty value under no web provenance is a preset whose ledger
        # identity claims a grant no section carries.
        printf 'non-web router presets carry web profile ledger identity markers: %s\n' \
            "$router_presets" >&2
        exit 2
    fi
    # build-web-presets.sh writes this marker when
    # QWEN_WEB_ALLOW_UNVALIDATED_DEPTH admitted a profile whose context exceeds
    # its row's validated_filled_depth or whose depth reads `-`. The preset file
    # carries the marker, so the restriction follows the file across every later
    # launch the way the quarantine provenance does.
    web_depth_override_from_preset=0
    if grep -qx '# qwen-web-presets: unvalidated-depth-override' \
        "$router_presets"; then
        web_depth_override_from_preset=1
    fi
    quarantine_override_from_preset=$(sed -n \
        's/^# qwen_router_include_quarantine=\([01]\)$/\1/p' \
        "$router_presets")
    if [ "$web_presets_from_preset" = 0 ] &&
        grep -qx '# Generated by remote/build-router-presets.sh from the model registry.' \
        "$router_presets" && [ -z "$quarantine_override_from_preset" ]; then
        printf 'generated router presets omit quarantine provenance; regenerate %s\n' \
            "$router_presets" >&2
        exit 2
    fi
    case $quarantine_override_from_preset in
        '' | 0 | 1) ;;
        *)
            printf 'router presets carry ambiguous quarantine provenance: %s\n' \
                "$router_presets" >&2
            exit 2
            ;;
    esac
    if [ -n "$router_preset_expected_sha256" ]; then
        router_preset_guard_sha256=$router_preset_expected_sha256
    else
        router_preset_guard_sha256=$(measure_router_authority_identity \
            'router preset' "$router_presets") || exit 2
    fi
    router_registry_guard_sha256=$(measure_router_authority_identity \
        'router model registry' "$router_registry") || exit 2
    router_quarantine_guard_sha256=$(measure_router_authority_identity \
        'router quarantine registry' "$router_quarantine_registry") || exit 2
    if [ "$web_presets_from_preset" != 1 ]; then
        router_draft_pair_guard_path=$router_draft_pair_registry
        router_draft_pair_guard_sha256=$(measure_router_authority_identity \
            'router draft-pair ledger' "$router_draft_pair_registry") || exit 2
    fi
    validate_current_router_authorities || exit 2
    # The digest follows the validation that read the rows, so the guard's
    # remeasurement binds the admitted counts to the ledger content this launch
    # compared each section against. Both preset shapes carry the count, so this
    # authority is measured for every router launch rather than skipped the way
    # the draft-pair and web ledgers are.
    router_ctx_checkpoint_guard_sha256=$(measure_router_authority_identity \
        'router context checkpoint ledger' \
        "$router_ctx_checkpoint_ledger") || exit 2
    quarantine_override_from_environment=${QWEN_ROUTER_INCLUDE_QUARANTINE:-0}
    case $quarantine_override_from_environment in
        0 | 1) ;;
        *)
            printf 'QWEN_ROUTER_INCLUDE_QUARANTINE must be 0 or 1: %s\n' \
                "$quarantine_override_from_environment" >&2
            exit 2
            ;;
    esac
    # A quarantined checkpoint reaches the picker only through the research
    # override, and it stays on the loopback while it does. The appliance binds
    # 0.0.0.0 so the laptop serves the LAN, and a warning alone would leave a
    # model with a recorded device failure or no validated safe tuple reachable
    # from every host on that network. The bind host is forced rather than
    # refused, so the override runs the experiment it exists for and the
    # exposure it would create does not follow it.
    if [ "$quarantine_override_from_environment" = 1 ] ||
       [ "$quarantine_override_from_preset" = 1 ]; then
        # Forcing the loopback under an exposure the operator asked for would
        # bind one address while the launcher printed another, so the two
        # settings refuse together rather than one silently winning.
        if [ "${QWEN_WEB_LAN:-0}" = 1 ]; then
            printf 'the quarantine override and the LAN exposure name different listeners; a checkpoint with a recorded device failure serves the loopback\n' >&2
            exit 2
        fi
        if [ "$bind_host" != 127.0.0.1 ]; then
            printf 'quarantine override forces the listener to loopback: %s -> 127.0.0.1\n' \
                "$bind_host" >&2
            bind_host=127.0.0.1
        fi
    fi
    # A section admitted past its validated_filled_depth serves a depth no run
    # has filled and decoded, so the same restriction applies for the same
    # reason: the appliance binds 0.0.0.0 and a depth that wedged the compute
    # ring reaches every host on the network from there. The bind host is forced
    # rather than refused, so the experiment the override exists for still runs.
    if [ "$web_depth_override_from_preset" = 1 ]; then
        # The exposure and this override refuse together for the reason the
        # quarantine pair does: the operator validates the depth rather than
        # serving an unvalidated one on an address the launch announced.
        if [ "${QWEN_WEB_LAN:-0}" = 1 ]; then
            printf 'the unvalidated-depth override and the LAN exposure name different listeners; validate the depth or serve it on the loopback\n' >&2
            exit 2
        fi
        if [ "$bind_host" != 127.0.0.1 ]; then
            printf 'web preset unvalidated-depth override forces the listener to loopback: %s -> 127.0.0.1\n' \
                "$bind_host" >&2
            bind_host=127.0.0.1
        fi
    fi
    set -- "$llama_server" \
        --models-preset "$router_presets" \
        --models-max "$router_max" \
        --host "$bind_host" \
        --port "$server_port" \
        --cors-origins "$cors_origins"
else
    set -- "$llama_server" \
        --model "$model_path" \
        --host "$bind_host" \
        --port "$server_port" \
        --alias qwen-apu \
        --cors-origins "$cors_origins"
fi

if [ -n "$static_path" ]; then
    set -- "$@" --path "$static_path" --ui
else
    set -- "$@" --no-ui
fi

if [ -n "$api_key_file" ]; then
    set -- "$@" --api-key-file "$api_key_file"
fi

# The projector turns images into embeddings the language model consumes; a
# text GGUF alone never gains vision. It must come from the same checkpoint as
# the language weights, which download-qwen35-4b-mmproj.sh pins to the same
# repository revision. Offloading it to Vulkan costs about 672 MiB of a heap
# with over 12 GiB free, and the alternative is running a vision encoder on two
# CPU cores.
if [ -n "${QWEN_MMPROJ:-}" ] && [ "$router_enabled" != 1 ]; then
    if [ ! -f "$QWEN_MMPROJ" ]; then
        printf 'projector is not a regular file: %s\n' "$QWEN_MMPROJ" >&2
        exit 2
    fi
    set -- "$@" --mmproj "$QWEN_MMPROJ"
    if [ "${QWEN_MMPROJ_OFFLOAD:-1}" = 0 ]; then
        set -- "$@" --no-mmproj-offload
    fi
    if [ -n "${QWEN_IMAGE_MAX_TOKENS:-}" ]; then
        set -- "$@" --image-max-tokens "$QWEN_IMAGE_MAX_TOKENS"
    fi
fi

# Speculation is a policy argument rather than an ambient override, so the four
# variables below are the whole surface and LLAMA_ARG_* stays refused above.
# draft-mtp needs no second checkpoint: common_speculative_init_result takes the
# `else if (spec_mtp)` branch and builds the draft context against the target
# model, and llama_model::create_memory filters the MTP KV cache to
# `il >= hparams.n_layer()`, so the draft cache holds the one appended NextN
# block. The 4B distill carries that block at 37,767,168 bytes, which the
# ordinary load reports as an unused tensor and skips.
spec_type=${QWEN_SPEC_TYPE:-}
# `off` is the explicit disable a harness exports to shut out an ambient
# speculation setting, and it selects the same argv the absent variable does.
if [ "$spec_type" = off ]; then
    spec_type=''
fi
if [ -n "$spec_type" ]; then
    case $spec_type in
        draft-mtp | ngram-simple | ngram-map-k | ngram-map-k4v | ngram-mod | ngram-cache) ;;
        *)
            printf 'speculation type must be draft-mtp or an ngram type: %s\n' \
                "$spec_type" >&2
            exit 2
            ;;
    esac
    set -- "$@" --spec-type "$spec_type"

    spec_draft_n_max=${QWEN_SPEC_DRAFT_N_MAX:-}
    if [ -n "$spec_draft_n_max" ]; then
        case $spec_draft_n_max in
            '' | *[!0-9]*)
                printf 'draft length must be a non-negative integer: %s\n' \
                    "$spec_draft_n_max" >&2
                exit 2
                ;;
        esac
        # A draft of N tokens makes the target emit N+1 output positions in one
        # pass, and common_speculative_get_output_limits clamps that count to
        # the batch size. Sixteen keeps the product inside the 128-token batch
        # this policy sets.
        if [ "$spec_draft_n_max" -gt 16 ]; then
            printf 'draft length exceeds operational maximum: %s > 16\n' \
                "$spec_draft_n_max" >&2
            exit 2
        fi
        # Zero aborts the pinned server on the first prompt:
        # common_speculative_get_output_limits sizes the target context for
        # `1 + n_draft` outputs while the speculative decode path still asks for
        # two, and llama-context.cpp:2227 asserts
        # `n_outputs_max <= cparams.n_outputs_max`. common/arg.cpp accepts any
        # value at or above zero, so the gate is here.
        if [ "$spec_draft_n_max" -eq 0 ]; then
            printf 'draft length of zero aborts the pinned server; omit QWEN_SPEC_TYPE to disable speculation\n' >&2
            exit 2
        fi
        set -- "$@" --spec-draft-n-max "$spec_draft_n_max"
    fi

    # p_min gates drafting rather than acceptance: common/speculative.cpp reads
    # llama_get_embeddings_nextn and breaks out of the draft loop when the
    # head's confidence falls below it, so a floor of 1 leaves the MTP block
    # loaded and the draft context built while no draft reaches the target.
    spec_draft_p_min=${QWEN_SPEC_DRAFT_P_MIN:-}
    if [ "$spec_draft_p_min" = 0 ]; then
        spec_draft_p_min=''
    fi
    if [ -n "$spec_draft_p_min" ]; then
        case $spec_draft_p_min in
            *[!0-9.]* | '' | *.*.*)
                printf 'draft probability floor must be a decimal fraction: %s\n' \
                    "$spec_draft_p_min" >&2
                exit 2
                ;;
        esac
        set -- "$@" --spec-draft-p-min "$spec_draft_p_min"
    fi

    if [ "${QWEN_SPEC_BACKEND_SAMPLING:-0}" = 1 ]; then
        set -- "$@" --spec-draft-backend-sampling
    fi
fi

# Backend sampling moves the supported sampler chain onto the device. This
# vocabulary is 248,320 entries wide, so the transfer it removes is the largest
# per-token host copy the server makes. It is experimental in the pinned build,
# which is why it is a variable rather than the default.
if [ "${QWEN_BACKEND_SAMPLING:-0}" = 1 ]; then
    set -- "$@" --backend-sampling
fi

# Context checkpoints are the one saved-state mechanism a hybrid recurrent
# model has: server-context.cpp cannot roll the Gated DeltaNet state back, so
# a second turn sharing a long prefix re-prefills from the newest checkpoint
# below the divergence point or from zero. The count is per registry row:
# remote/ctx-checkpoints.tsv carries it, because
# evidence/ctx-checkpoint-sweep/ measures the same second-turn reduction on
# every class while the 0.8B alone emits a different first-turn token once
# checkpoints are armed, and a row outside the ledger serves at 0.
# QWEN_CTX_CHECKPOINTS replaces the row's count for a sweep that measures what
# the copies buy, an explicit 0 included. A checkpoint copies the recurrent
# state into host memory, so the count stays on the desktop reserve's side of
# the arithmetic. QWEN_CHECKPOINT_MIN_STEP names --checkpoint-min-step and
# leaves the pinned build's 8192-token default in place when unset. Both are
# non-negative integers, since common/arg.cpp reads them as such. In router
# mode the count belongs to each section's LLAMA_ARG_CTX_CHECKPOINTS, which
# the tuple validator above compared against the ledger, and this variable
# stays off the router argv with the six tuple flags.
registry_ctx_checkpoints=0
if [ "$router_enabled" != 1 ]; then
    registry_model_id=$(registry_model_field id 2>/dev/null) || \
        registry_model_id=''
    if [ -n "$registry_model_id" ]; then
        if ! registry_ctx_checkpoints=$(registry_checkpoint_count \
            "$registry_model_id"); then
            printf 'context checkpoint authority is unavailable\n' >&2
            exit 2
        fi
    fi
fi
ctx_checkpoints=${QWEN_CTX_CHECKPOINTS:-$registry_ctx_checkpoints}
case $ctx_checkpoints in
    '' | *[!0-9]*)
        printf 'context checkpoint count must be a non-negative integer: %s\n' \
            "$ctx_checkpoints" >&2
        exit 2
        ;;
esac
# Router mode takes its count from each section, so this variable would reach
# neither the argv nor the preset and the launch would serve the ledger's count
# under a name that says otherwise. An arm measuring what the copies buy runs
# the checkpoint it measures on the single-model path, where the count reaches
# the server.
if [ "$router_enabled" = 1 ] && [ -n "${QWEN_CTX_CHECKPOINTS:-}" ]; then
    printf 'QWEN_CTX_CHECKPOINTS is refused in router mode: %s\n' \
        "$QWEN_CTX_CHECKPOINTS" >&2
    printf 'launch the checkpoint the arm measures on the single-model path\n' >&2
    exit 2
fi
checkpoint_min_step=${QWEN_CHECKPOINT_MIN_STEP:-}
if [ -n "$checkpoint_min_step" ]; then
    case $checkpoint_min_step in
        *[!0-9]*)
            printf 'checkpoint minimum step must be a non-negative integer: %s\n' \
                "$checkpoint_min_step" >&2
            exit 2
            ;;
    esac
    # The spacing reaches the router's own argv, and common_preset::merge
    # overwrites, so one value would place every child's checkpoints while each
    # section still matched the ledger. The ledger states a count per row and no
    # authority states a spacing, and evidence/ctx-checkpoint-sweep/ measured
    # its counts at the pinned build's 8192-token default, so the override
    # belongs to the single-model path where it changes the one row it launches.
    if [ "$router_enabled" = 1 ]; then
        printf 'QWEN_CHECKPOINT_MIN_STEP is refused in router mode: %s\n' \
            "$checkpoint_min_step" >&2
        printf 'launch the checkpoint the arm measures on the single-model path\n' >&2
        exit 2
    fi
fi

# A positive count is meaningful only against a build whose prompt fill loop
# places checkpoints at natural n_batch boundaries. The pinned build breaks the
# prompt `4 + n_ubatch` and `4` tokens from the end whenever checkpoints are
# armed, and evidence/ctx-checkpoint-sweep/ measures that forced partition
# moving the 0.8B's first-turn token at index 25. The ledger and the binary are
# separate release artifacts, so a ledger edit alone could otherwise pair a
# positive count with the unrepaired implementation. build-llama-preset.sh
# records what it compiled as `checkpoint_semantics` in the build's artifact
# manifest, this policy reads that declaration from the manifest beside the
# selected executable, and an absent declaration refuses rather than defaults.
checkpoint_semantics=unknown
checkpoint_manifest_sha256=-
llama_server_directory=$(dirname -- "$(readlink -f -- "$llama_server")")
for checkpoint_manifest in "$llama_server_directory/artifact-manifest.tsv" \
    "$llama_server_directory/../artifact-manifest.tsv"; do
    [ -r "$checkpoint_manifest" ] || continue
    # A manifest states the declaration once, so a second row leaves the value
    # undefined rather than disputed. Reading the first row would admit a
    # manifest whose natural-boundary-v1 sits above a forced-tail-v1, which
    # qwen-build-exec-guard.sh refuses at the exec boundary; counting here keeps
    # the refusal beside the argv it would have produced.
    checkpoint_semantics=$(awk -F'\t' '
        $1 == "checkpoint_semantics" { count++; value = $2 }
        END { print (count == 1 && value != "") ? value : "unknown" }
    ' "$checkpoint_manifest")
    checkpoint_manifest_sha256=$(sha256sum -- "$checkpoint_manifest" | cut -d ' ' -f 1)
    break
done

# Router mode carries the count per section, so the preset rather than this
# argv states whether any child arms one.
checkpoint_count_armed=0
if [ "$router_enabled" = 1 ]; then
    if [ -r "$router_presets" ] && awk '
        /^[[:space:]]*LLAMA_ARG_CTX_CHECKPOINTS[[:space:]]*=/ {
            value = $0
            sub(/^[^=]*=[[:space:]]*/, "", value)
            sub(/[[:space:]]+$/, "", value)
            if (value + 0 > 0) { found = 1 }
        }
        END { exit found ? 0 : 1 }
    ' "$router_presets"; then
        checkpoint_count_armed=1
    fi
elif [ "$ctx_checkpoints" -gt 0 ]; then
    checkpoint_count_armed=1
fi

checkpoint_guard_requirement=-
if [ "$checkpoint_count_armed" = 1 ]; then
    checkpoint_guard_requirement=natural-boundary-v1
fi

# The refusal is stated here so an unserviceable combination fails while the
# reason is still readable beside the argv it would have produced.
# qwen-build-exec-guard.sh states it again at the exec boundary, where it also
# measures the manifest and the executable, so a symlink repointed or a manifest
# rewritten after this point is caught there rather than served.
if [ "$checkpoint_guard_requirement" != - ] &&
    [ "$checkpoint_semantics" != "$checkpoint_guard_requirement" ]; then
    printf 'the selected llama-server declares checkpoint_semantics=%s: %s\n' \
        "$checkpoint_semantics" "$llama_server" >&2
    printf 'a positive context checkpoint count requires %s\n' \
        "$checkpoint_guard_requirement" >&2
    exit 2
fi
printf 'checkpoint_binding semantics=%s requirement=%s manifest_sha256=%s\n' \
    "$checkpoint_semantics" "$checkpoint_guard_requirement" \
    "$checkpoint_manifest_sha256"

set -- "$@" \
    --log-verbosity 4 \
    --device Vulkan0 \
    --split-mode none \
    --n-gpu-layers all \
    --override-tensor '.*=Vulkan0' \
    --fit off \
    --parallel 1 \
    --threads 1 \
    --threads-batch 1 \
    --cache-ram 0 \
    --no-context-shift \
    --offline
if [ -n "$checkpoint_min_step" ]; then
    set -- "$@" --checkpoint-min-step "$checkpoint_min_step"
fi

# The six per-checkpoint flags stay off the router's own argv, because
# server-models.cpp ends its preset assembly with `preset.merge(base_preset)`
# and common_preset::merge overwrites, so a router CLI argument replaces the
# same key in every model preset. Setting --ctx-size here served the vision row
# at 24576 where its section named 16384. Router mode therefore leaves depth,
# cache triple, and submission geometry to the preset file, which
# build-router-presets.sh writes from the registry row for every section, and
# the single-model path sets them from the row it launches.
#
# Every section carrying all six is what makes the omission safe: an absent key
# falls through to the llama.cpp defaults, and those are batch 2048 and ubatch
# 512, which is the quarantined geometry. The checkpoint count joins them for
# the same reason, with a default of 32 where the ledger admits at most two.
if [ "$router_enabled" != 1 ]; then
    set -- "$@" \
        --ctx-checkpoints "$ctx_checkpoints" \
        --ctx-size "$context_size" \
        --batch-size "$batch_size" \
        --ubatch-size "$ubatch_size" \
        --flash-attn "$flash_attention" \
        --cache-type-k "$cache_type_k" \
        --cache-type-v "$cache_type_v"
fi

# The appliance admits one active qwen-owned Vulkan workload, and
# ~/qwen-webui-state/vulkan-workload.lock is the kernel lock that carries it.
# remote/image-service.py takes it across one generation and llama-server holds
# it from the first busy slot to the last idle one, so a resident idle server
# competes with nothing while active prompt processing and decode exclude a
# generation. radv-low-priority-env.sh scrubs the GGML_VK_*, display, AMD,
# RADV, and VK layer names alone, so this variable crosses the exec boundary
# untouched. In router mode server-models.cpp snapshots environ into base_env
# at server_models_routes construction and spawns every child with that copy, so
# the child executing the graphs opens the lock; the router parent leaves
# server_context uninitialised and opens nothing.
workload_lease_state_directory=${QWEN_WEBUI_STATE_DIRECTORY:-"${HOME:?}/qwen-webui-state"}
mkdir -p -- "$workload_lease_state_directory"
chmod 700 -- "$workload_lease_state_directory"
workload_lease_path=$workload_lease_state_directory/vulkan-workload.lock
if [ -n "${QWEN_VULKAN_EXTERNAL_LEASE_PROOF:-}" ]; then
    external_lease_verifier=$script_directory/verify-external-vulkan-lease.py
    if [ ! -x "$external_lease_verifier" ]; then
        printf 'external Vulkan lease verifier is absent: %s\n' \
            "$external_lease_verifier" >&2
        exit 2
    fi
    if ! "$external_lease_verifier" "$QWEN_VULKAN_EXTERNAL_LEASE_PROOF" \
        "$workload_lease_path"; then
        exit 2
    fi
    unset QWEN_VULKAN_WORKLOAD_LOCK
    printf 'vulkan_workload_lease mode=external path=%s proof=%s\n' \
        "$workload_lease_path" "$QWEN_VULKAN_EXTERNAL_LEASE_PROOF"
else
    export QWEN_VULKAN_WORKLOAD_LOCK=$workload_lease_path
    printf 'vulkan_workload_lease mode=request path=%s\n' \
        "$QWEN_VULKAN_WORKLOAD_LOCK"
fi

# The launcher hashes its immutable-per-session snapshot before preflight. The
# exec boundary revalidates every mutable authority and measures the preset
# again, so a replacement of the model registry, the quarantine registry, the
# draft-pair ledger, the web profile ledger, or the context checkpoint ledger
# invalidates the assembled server command before llama-server starts.
if [ "$router_enabled" = 1 ]; then
    verify_router_preset_identity || exit 2
    validate_current_router_authorities || exit 2
    # The digest the guard carries is measured once, and the validation that
    # admits the counts runs twice, so the ledger is remeasured here and
    # required to equal that digest. Without the comparison a file holding the
    # admitted rows at each validation and revoked rows at the single
    # measurement would hand the guard a digest naming content no validation
    # read, and the guard would then accept the revoked file it matches.
    router_ctx_checkpoint_final_sha256=$(measure_router_authority_identity \
        'router context checkpoint ledger' \
        "$router_ctx_checkpoint_ledger") || exit 2
    if [ "$router_ctx_checkpoint_final_sha256" != \
        "$router_ctx_checkpoint_guard_sha256" ]; then
        printf 'context checkpoint ledger identity changed during validation: expected %s, measured %s\n' \
            "$router_ctx_checkpoint_guard_sha256" \
            "$router_ctx_checkpoint_final_sha256" >&2
        exit 2
    fi
    exec "$script_directory/radv-low-priority-env.sh" \
        "$script_directory/qwen-build-exec-guard.sh" \
        "$llama_server" "$checkpoint_manifest_sha256" \
        "$checkpoint_guard_requirement" \
        "$script_directory/qwen-router-exec-guard.sh" \
        "$router_presets" "$router_preset_guard_sha256" \
        "$router_registry" "$router_registry_guard_sha256" \
        "$router_quarantine_registry" "$router_quarantine_guard_sha256" \
        "$router_draft_pair_guard_path" "$router_draft_pair_guard_sha256" \
        "$router_web_profiles_guard_path" \
        "$router_web_profiles_guard_sha256" \
        "$router_ctx_checkpoint_ledger" \
        "$router_ctx_checkpoint_guard_sha256" \
        "$@"
fi

if [ -n "$approved_registry_descriptor" ]; then
    exec 5<&-
fi
exec "$script_directory/radv-low-priority-env.sh" \
    "$script_directory/qwen-build-exec-guard.sh" \
    "$llama_server" "$checkpoint_manifest_sha256" \
    "$checkpoint_guard_requirement" \
    "$@"
