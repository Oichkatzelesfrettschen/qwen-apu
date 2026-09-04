# shellcheck shell=sh
# shellcheck disable=SC2154  # every function reads caller-set launch variables by name
# shellcheck disable=SC2034  # every function writes results the caller reads by name
# Shared image-lane launch rules.
#
# Two launchers arm the same lane. remote/qwen-image-launch.sh serves the
# web-only preset, whose one language section and optional review-only section
# are the whole file, and remote/qwen-launch.sh serves the merged roster preset,
# where the language section is one of sixteen and the reviewer is the registry
# row the roster already carries. What both do is identical: read the preset's
# image markers, rejoin them to remote/image-profiles.tsv, validate the
# parameter file the service runs a job under, prove the deadline stack ordered
# from the value each layer is configured with, charge the image runtime against
# the Vulkan budget, and export the settings qwen-webui-session.sh starts the
# service from. A second copy of those rules would let the two launchers
# disagree about what an armed lane is, so they live here.
#
# Every key is resolved inside the named section rather than at the file's first
# occurrence, because the merged preset opens on a registry row and a first-match
# read would arm the lane from a section that carries no grant.
#
# The caller sets these before calling anything here:
#   script_directory     the remote/ directory the launcher runs from
#   state_directory      QWEN_WEBUI_STATE_DIRECTORY

# The generator records the image profile it emitted, the ledger it read, and
# that ledger's digest, so the launch reads one authority out of the file it
# launches rather than re-deriving it from an environment that may have moved.
# `-` and an absent marker both read as a withheld lane: the second is a preset
# generated before this lane, and a launch over one arms nothing rather than
# refusing a file the rest of the appliance still serves.
read_image_preset_markers() {
    image_preset=$1
    preset_image_profile=$(sed -n 's/^# qwen_image_profile=//p' "$image_preset")
    preset_image_profiles=$(sed -n 's/^# qwen_image_profiles_path=//p' \
        "$image_preset")
    preset_image_profiles_sha256=$(sed -n \
        's/^# qwen_image_profiles_sha256=//p' "$image_preset")
    preset_review_model=$(sed -n 's/^# qwen_image_review_model=//p' \
        "$image_preset")
    preset_review_section=$(sed -n 's/^# qwen_image_review_section=//p' \
        "$image_preset")
    image_lane_armed=0
    case $preset_image_profile in
        '' | '-') return 0 ;;
    esac
    image_lane_armed=1
}

# A preset persists across an edit to the ledger, so the row it names is read
# again here: a row moved to `refused` or removed outright refuses the launch
# rather than serving a persisted MCP configuration that still names it. The
# digest binds every row rather than only that one field.
require_image_ledger_row() {
    case $preset_image_profiles in
        /*) ;;
        *)
            printf 'the preset omits an absolute image profile ledger path: %s\n' \
                "$image_preset" >&2
            return 1
            ;;
    esac
    if [ "${#preset_image_profiles_sha256}" -ne 64 ]; then
        printf 'image preset ledger SHA-256 must hold 64 lowercase hexadecimal characters\n' >&2
        return 1
    fi
    case $preset_image_profiles_sha256 in
        *[!0-9a-f]*)
            printf 'image preset ledger SHA-256 must hold 64 lowercase hexadecimal characters\n' >&2
            return 1
            ;;
    esac
    if ! image_profiles_identity=$(sha256sum -- "$preset_image_profiles"); then
        printf 'image profile ledger identity cannot be measured: %s\n' \
            "$preset_image_profiles" >&2
        return 1
    fi
    image_profiles_actual_sha256=${image_profiles_identity%% *}
    if [ "$image_profiles_actual_sha256" != "$preset_image_profiles_sha256" ]; then
        printf 'image profile ledger identity changed: expected %s, measured %s\n' \
            "$preset_image_profiles_sha256" "$image_profiles_actual_sha256" >&2
        printf 'regenerate the preset tree\n' >&2
        return 1
    fi
    QWEN_IMAGE_PROFILES=$preset_image_profiles
    export QWEN_IMAGE_PROFILES
    if ! image_profile_row=$("$script_directory/image-registry.sh" profile \
        "$preset_image_profile" 2>/dev/null); then
        printf 'the preset names image profile %s, which %s holds no row for\n' \
            "$preset_image_profile" "$preset_image_profiles" >&2
        return 1
    fi
    image_execution_policy=$(image_profile_field execution_policy)
    if [ "$image_execution_policy" != validator-gated ]; then
        printf 'image profile %s carries execution_policy %s, and only validator-gated reaches a runtime\n' \
            "$preset_image_profile" "${image_execution_policy:-<absent>}" >&2
        return 1
    fi
    # The reviewer is a property of the image row, so the preset's own marker is
    # rejoined the way the image profile is: a row whose review_model changed
    # since generation refuses rather than serving a persisted claim the ledger
    # no longer makes.
    ledger_review_model=$(image_profile_field review_model)
    if [ "$preset_review_model" != "$ledger_review_model" ]; then
        printf 'image profile %s pairs review_model %s where the preset carries %s\n' \
            "$preset_image_profile" "${ledger_review_model:-<absent>}" \
            "${preset_review_model:-<absent>}" >&2
        printf 'regenerate the preset tree\n' >&2
        return 1
    fi
}

image_profile_field() {
    printf '%s\n' "$image_profile_row" | sed -n "s/^$1=//p"
}

# The approval broker is the only issuer of the grant an image call carries, so
# a section armed for generation without one serves a tool every call is
# refused. The launchers apply every rule the signing key must meet; this
# requires the file to be named, because the image MCP child reads it under its
# own name and a launch that named none would reach the model as a per-call
# refusal.
require_image_signing_key() {
    signing_key_file=${QWEN_WEB_TOKEN_KEY_FILE:-}
    if [ -z "$signing_key_file" ]; then
        printf 'the image grant signing key is unset\n' >&2
        printf 'QWEN_WEB_TOKEN_KEY_FILE names a regular file at mode 0600, owned by this user, holding the HMAC key\n' >&2
        return 1
    fi
    QWEN_IMAGE_TOKEN_KEY_FILE=${QWEN_IMAGE_TOKEN_KEY_FILE:-$signing_key_file}
    if [ "$QWEN_IMAGE_TOKEN_KEY_FILE" != "$signing_key_file" ]; then
        printf 'QWEN_IMAGE_TOKEN_KEY_FILE names %s where the broker signs with %s\n' \
            "$QWEN_IMAGE_TOKEN_KEY_FILE" "$signing_key_file" >&2
        printf 'one key signs both grant contexts, which the context string separates\n' >&2
        return 1
    fi
}

# The service runs a job under validated profile parameters rather than under
# the ledger row, because the row names no runtime binary and no argv template.
# The launch validates the file against the row it claims to serve, so a
# parameter set naming another geometry, another ceiling, or another policy
# refuses here rather than at the first approved generation.
require_image_parameters() {
    image_profiles_json=${QWEN_IMAGE_PROFILES_JSON:-}
    if [ ! -r "$image_profiles_json" ]; then
        printf 'QWEN_IMAGE_PROFILES_JSON names no readable file: %s\n' \
            "${image_profiles_json:-<unset>}" >&2
        printf 'the file holds validated profile parameters keyed by profile_id, which image-service.py runs a job under\n' >&2
        return 1
    fi
    if ! image_parameters=$(python3 -c '
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    profiles = json.load(handle)
profile = profiles.get(sys.argv[2])
if not isinstance(profile, dict):
    raise SystemExit("the parameter file holds no object for " + sys.argv[2])
for name in ("model_id", "placement", "width", "height", "steps", "sampler",
             "cfg", "max_steps", "max_dimension", "timeout_s",
             "execution_policy", "runtime_path"):
    if name not in profile:
        raise SystemExit("the parameters omit " + name)
    print("%s=%s" % (name, profile[name]))
' "$image_profiles_json" "$preset_image_profile"); then
        printf 'the image parameter file fails its own shape: %s\n' \
            "$image_profiles_json" >&2
        return 1
    fi
    for compared_field in model_id placement width height steps sampler cfg \
        max_steps max_dimension timeout_s execution_policy; do
        ledger_value=$(image_profile_field "$compared_field")
        parameter_value=$(image_parameter_field "$compared_field")
        if [ "$ledger_value" != "$parameter_value" ]; then
            printf 'image profile %s carries %s %s in %s and %s in %s\n' \
                "$preset_image_profile" "$compared_field" "$ledger_value" \
                "$preset_image_profiles" "$parameter_value" \
                "$image_profiles_json" >&2
            return 1
        fi
    done
    image_runtime_path=$(image_parameter_field runtime_path)
    if [ ! -x "$image_runtime_path" ]; then
        printf 'the image runtime is absent or not executable: %s\n' \
            "$image_runtime_path" >&2
        return 1
    fi
}

image_parameter_field() {
    printf '%s\n' "$image_parameters" | sed -n "s/^$1=//p"
}

# The MCP configuration a section names is what llama-server hands its child, so
# the key is read inside that section: the merged preset opens on a registry row
# and a first-match read would arm the lane from a section carrying no grant.
image_section_mcp_configuration() {
    awk -v wanted="$2" '
        /^[[:space:]]*\[/ {
            section = $0
            sub(/^[[:space:]]*\[/, "", section)
            sub(/\][[:space:]]*$/, "", section)
            next
        }
        section != wanted { next }
        {
            separator = index($0, "=")
            if (separator == 0) next
            key = substr($0, 1, separator - 1)
            value = substr($0, separator + 1)
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", key)
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
            if (key == "LLAMA_ARG_MCP_SERVERS_CONFIG") print value
        }
    ' "$1"
}

# The deadline stack is verified from the value each layer is configured with,
# because a number typed here would assert an ordering the system does not have.
# Four layers configure one: the profile row and image-service.py's own ceiling
# bound the runtime, image-service.py bounds the whole job, the emitted MCP
# configuration bounds the tool call, and webui/index.html bounds the page's
# wait. The router proxy configures none in this tree -- the patched router
# proxies with llama-server's own read timeout, 3600 s -- so the launch reads
# that default rather than claiming a bound nothing sets, and
# QWEN_IMAGE_ROUTER_PROXY_TIMEOUT_S states another where a deployment sets one.
# What the ordering buys is that the innermost deadline fires first: a stalled
# generation is ended by the process that owns it, and the proxy outlasts the
# tool call it is carrying.
verify_image_deadline_stack() {
    image_deadline_preset=$1
    image_language_section=$2
    image_mcp_configuration=$(image_section_mcp_configuration \
        "$image_deadline_preset" "$image_language_section")
    if [ ! -r "${image_mcp_configuration:-}" ]; then
        printf 'section %s names no readable MCP configuration: %s\n' \
            "$image_language_section" \
            "${image_mcp_configuration:-<absent>}" >&2
        return 1
    fi
    # remote/read-image-mcp-server.py is the one parser this launch and
    # qwen-capacity-policy.sh read that file with, and it already requires the
    # seven names the child reads and the agreement between the router's
    # timeout_ms and the child's own socket deadline.
    if ! image_server_report=$("$script_directory/read-image-mcp-server.py" \
        "$image_mcp_configuration"); then
        printf 'the image MCP configuration is unusable: %s\n' \
            "$image_mcp_configuration" >&2
        return 1
    fi
    if [ "$(image_server_field image_server)" != present ]; then
        printf 'section %s names an MCP configuration carrying no image server: %s\n' \
            "$image_language_section" "$image_mcp_configuration" >&2
        return 1
    fi
    for image_server_pair in \
        "QWEN_IMAGE_PROFILE=$preset_image_profile" \
        "QWEN_IMAGE_LANGUAGE_PROFILE=$image_language_section" \
        "QWEN_IMAGE_PROFILES_JSON=$image_profiles_json" \
        "QWEN_IMAGE_TOKEN_KEY_FILE=$QWEN_IMAGE_TOKEN_KEY_FILE" \
        "QWEN_IMAGE_STATE_DIR=$state_directory/images" \
        "QWEN_IMAGE_SERVICE_SOCKET=$state_directory/images/image-service.sock"; do
        image_server_name=${image_server_pair%%=*}
        image_server_expected=${image_server_pair#*=}
        image_server_measured=$(image_server_field "$image_server_name")
        if [ "$image_server_measured" != "$image_server_expected" ]; then
            printf 'the image server names %s %s where this launch serves %s\n' \
                "$image_server_name" "$image_server_measured" \
                "$image_server_expected" >&2
            return 1
        fi
    done
    image_mcp_timeout_ms=$(image_server_field image_timeout_ms)

    runtime_hard_timeout=$(sed -n \
        's/^RUNTIME_HARD_TIMEOUT_SECONDS = \([0-9]\{1,\}\)$/\1/p' \
        "$image_service_program")
    service_job_deadline=$(sed -n \
        's/^SERVICE_JOB_DEADLINE_SECONDS = \([0-9]\{1,\}\)$/\1/p' \
        "$image_service_program")
    image_profile_timeout=$(image_profile_field timeout_s)
    runtime_timeout=$image_profile_timeout
    if [ "${runtime_hard_timeout:-0}" -lt "$runtime_timeout" ]; then
        runtime_timeout=$runtime_hard_timeout
    fi
    static_path=${QWEN_STATIC_PATH:-"$script_directory/../webui"}
    browser_timeout_ms=$(sed -n \
        's/^const IMAGE_GENERATION_TIMEOUT_MS = \([0-9]\{1,\}\);$/\1/p' \
        "$static_path/index.html")
    router_proxy_timeout=${QWEN_IMAGE_ROUTER_PROXY_TIMEOUT_S:-3600}
    runtime_timeout_ms=$((runtime_timeout * 1000))
    service_job_deadline_ms=$((service_job_deadline * 1000))
    router_proxy_timeout_ms=$((router_proxy_timeout * 1000))
    for measured_deadline in "$runtime_timeout_ms" "$service_job_deadline_ms" \
        "$image_mcp_timeout_ms" "$router_proxy_timeout_ms" \
        "$browser_timeout_ms"; do
        case $measured_deadline in
            '' | 0 | *[!0-9]*)
                printf 'a deadline in the stack is unreadable: runtime=%s service=%s mcp=%s proxy=%s browser=%s\n' \
                    "$runtime_timeout_ms" "$service_job_deadline_ms" \
                    "$image_mcp_timeout_ms" "$router_proxy_timeout_ms" \
                    "$browser_timeout_ms" >&2
                return 1
                ;;
        esac
    done
    deadline_breach=''
    if [ "$runtime_timeout_ms" -ge "$service_job_deadline_ms" ]; then
        deadline_breach='runtime>=service'
    elif [ "$service_job_deadline_ms" -ge "$image_mcp_timeout_ms" ]; then
        deadline_breach='service>=mcp'
    elif [ "$image_mcp_timeout_ms" -ge "$browser_timeout_ms" ]; then
        deadline_breach='mcp>=browser'
    elif [ "$image_mcp_timeout_ms" -ge "$router_proxy_timeout_ms" ]; then
        deadline_breach='mcp>=proxy'
    fi
    if [ -n "$deadline_breach" ]; then
        printf 'the image deadline stack is out of order at %s: runtime=%s service=%s mcp=%s proxy=%s browser=%s\n' \
            "$deadline_breach" "$runtime_timeout_ms" \
            "$service_job_deadline_ms" "$image_mcp_timeout_ms" \
            "$router_proxy_timeout_ms" "$browser_timeout_ms" >&2
        printf 'a stalled generation is ended by the process that owns it, so each deadline sits inside the one above it\n' >&2
        return 1
    fi
    printf 'image_launch timeouts runtime_ms=%s service_ms=%s mcp_ms=%s proxy_ms=%s browser_ms=%s proxy_source=%s\n' \
        "$runtime_timeout_ms" "$service_job_deadline_ms" \
        "$image_mcp_timeout_ms" "$router_proxy_timeout_ms" \
        "$browser_timeout_ms" \
        "${QWEN_IMAGE_ROUTER_PROXY_TIMEOUT_S:+configured}${QWEN_IMAGE_ROUTER_PROXY_TIMEOUT_S:-llama-server-default}"
}

image_server_field() {
    printf '%s\n' "$image_server_report" | sed -n "s/^$1=//p"
}

# The runtime's resident cost is a measured figure from the standalone campaign
# rather than a derived one, and it is charged whole because a generation runs
# while the language child stays loaded.
read_image_runtime_resident_mib() {
    image_runtime_resident_mib=${QWEN_IMAGE_RUNTIME_RESIDENT_MIB:-480}
    case $image_runtime_resident_mib in
        '' | *[!0-9]*)
            printf 'QWEN_IMAGE_RUNTIME_RESIDENT_MIB must be a non-negative integer of MiB: %s\n' \
                "$image_runtime_resident_mib" >&2
            return 1
            ;;
    esac
}

# model-memory-preflight.sh reports and admits every launch by design -- a
# prediction that a model will not fit was wrong once and read as a hardware
# limit -- so a caller reads its `vulkan_budget_headroom` line and makes any
# refusal its own. The probe stays the single authority for what the device has.
run_image_memory_preflight() {
    memory_preflight_program=${QWEN_MEMORY_PREFLIGHT_PROGRAM:-$script_directory/model-memory-preflight.sh}
    if ! image_budget_report=$("$memory_preflight_program" "$1" "$2"); then
        printf 'the memory preflight failed to measure the device\n' >&2
        printf '%s\n' "$image_budget_report" >&2
        return 1
    fi
    printf '%s\n' "$image_budget_report"
}

# qwen-webui-session.sh starts the service as a guarded child from these four
# values and records its pid and its artifact listener on the state=running
# line; qwen-webui-control.sh forwards each inside the tmux command string.
export_image_service_environment() {
    QWEN_IMAGE_SERVICE=1
    QWEN_IMAGE_SERVICE_PROGRAM=$image_service_program
    QWEN_IMAGE_PROFILES_JSON=$image_profiles_json
    QWEN_IMAGE_PROFILE=$preset_image_profile
    export QWEN_IMAGE_SERVICE QWEN_IMAGE_SERVICE_PROGRAM
    export QWEN_IMAGE_PROFILES_JSON QWEN_IMAGE_PROFILE QWEN_IMAGE_TOKEN_KEY_FILE
    printf 'image_launch profile=%s ledger=%s runtime=%s parameters=%s\n' \
        "$preset_image_profile" "$preset_image_profiles" \
        "$image_runtime_path" "$image_profiles_json"
}
