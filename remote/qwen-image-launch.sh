#!/bin/sh
set -eu

# Start the appliance in web router mode with the image generation lane armed,
# on the loopback alone.
#
# An image section reaches the device rather than the network: its MCP child
# hands a job to image-service.py, which takes the Vulkan workload lease and
# spawns the pinned image runtime. The grant that authorizes one generation is
# signed by the same approval broker a search grant comes from, so this wrapper
# is qwen-web-launch.sh with the image authority resolved first: it reads the
# preset's image markers, rejoins them to the ledger, proves the deadline stack
# is ordered, exports the image service's own settings, and hands the launch on.
# qwen-webui-control.sh forwards every QWEN_IMAGE_* value inside the tmux
# command string, and qwen-webui-session.sh starts the service as a guarded
# child and records its pid on the session status line.
#
# The listener is 127.0.0.1 and a caller asking for any other one is refused
# rather than silently rewritten, for the reason qwen-web-launch.sh states: an
# operator who typed 0.0.0.0 wants an exposure this launch declines to provide.
#
# One checked-in row of remote/image-profiles.tsv reads `validator-gated`, so
# the preset a generator writes against the shipped ledger under
# QWEN_WEB_AUTHORIZER_READY=1 names that image profile and this launch arms the
# path. A preset naming none refuses and says so, and promoting a further row
# is a measurement on the appliance.

if [ "$#" -gt 1 ]; then
    printf 'usage: %s [paced-60|low-serialized|low-async]\n' "$0" >&2
    printf 'web preset file comes from QWEN_WEB_PRESETS, default $HOME/qwen-webui-state/web-presets.ini\n' >&2
    printf 'the preset must name an image profile, which requires a validator-gated row in remote/image-profiles.tsv\n' >&2
    printf 'QWEN_IMAGE_PROFILES_JSON names the validated profile parameters the image service runs a job under\n' >&2
    printf 'the listener is 127.0.0.1; QWEN_BIND_HOST set to any other value refuses the launch\n' >&2
    exit 2
fi

profile=${1:-low-async}
script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
web_launcher=$script_directory/qwen-web-launch.sh
image_service_program=${QWEN_IMAGE_SERVICE_PROGRAM:-$script_directory/image-service.py}
state_directory=${QWEN_WEBUI_STATE_DIRECTORY:-"${HOME:?}/qwen-webui-state"}
web_presets=${QWEN_WEB_PRESETS:-$state_directory/web-presets.ini}

requested_bind_host=${QWEN_BIND_HOST:-127.0.0.1}
if [ "$requested_bind_host" != 127.0.0.1 ]; then
    printf 'image router mode serves the loopback alone, and QWEN_BIND_HOST requests %s\n' \
        "$requested_bind_host" >&2
    printf 'an image section spawns a device runtime through its MCP server; unset QWEN_BIND_HOST or set it to 127.0.0.1\n' >&2
    exit 2
fi

if [ ! -r "$web_presets" ]; then
    printf 'web presets are unreadable: %s\n' "$web_presets" >&2
    printf 'generate them with remote/build-web-presets.sh\n' >&2
    exit 2
fi

# The generator records the image profile it emitted, the ledger it read, and
# that ledger's digest, so the launch reads one authority out of the file it
# launches rather than re-deriving it from an environment that may have moved.
preset_image_profile=$(sed -n 's/^# qwen_image_profile=//p' "$web_presets")
preset_image_profiles=$(sed -n 's/^# qwen_image_profiles_path=//p' "$web_presets")
preset_image_profiles_sha256=$(sed -n \
    's/^# qwen_image_profiles_sha256=//p' "$web_presets")
if [ -z "$preset_image_profile" ]; then
    printf 'the preset carries no image markers: %s\n' "$web_presets" >&2
    printf 'regenerate it with a remote/build-web-presets.sh that reads remote/image-profiles.tsv\n' >&2
    exit 2
fi
if [ "$preset_image_profile" = '-' ]; then
    printf 'every image profile in %s withholds an executing policy, so the preset arms no generation\n' \
        "${preset_image_profiles:-remote/image-profiles.tsv}" >&2
    printf 'every checked-in row reads refused; a validator-gated row is a measurement on the appliance and the only thing this launch runs\n' >&2
    printf 'launch the ordinary web router with remote/qwen-web-launch.sh\n' >&2
    exit 2
fi

case $preset_image_profiles in
    /*) ;;
    *)
        printf 'the preset omits an absolute image profile ledger path: %s\n' \
            "$web_presets" >&2
        exit 2
        ;;
esac
if [ "${#preset_image_profiles_sha256}" -ne 64 ]; then
    printf 'image preset ledger SHA-256 must hold 64 lowercase hexadecimal characters\n' >&2
    exit 2
fi
case $preset_image_profiles_sha256 in
    *[!0-9a-f]*)
        printf 'image preset ledger SHA-256 must hold 64 lowercase hexadecimal characters\n' >&2
        exit 2
        ;;
esac
if ! image_profiles_identity=$(sha256sum -- "$preset_image_profiles"); then
    printf 'image profile ledger identity cannot be measured: %s\n' \
        "$preset_image_profiles" >&2
    exit 2
fi
image_profiles_actual_sha256=${image_profiles_identity%% *}
if [ "$image_profiles_actual_sha256" != "$preset_image_profiles_sha256" ]; then
    printf 'image profile ledger identity changed: expected %s, measured %s\n' \
        "$preset_image_profiles_sha256" "$image_profiles_actual_sha256" >&2
    printf 'regenerate the preset tree with remote/build-web-presets.sh\n' >&2
    exit 2
fi

# A preset persists across an edit to the ledger, so the row it names is read
# again here: a row moved to `refused` or removed outright refuses the launch
# rather than serving a persisted MCP configuration that still names it.
QWEN_IMAGE_PROFILES=$preset_image_profiles
export QWEN_IMAGE_PROFILES
if ! image_profile_row=$("$script_directory/image-registry.sh" profile \
    "$preset_image_profile" 2>/dev/null); then
    printf 'the preset names image profile %s, which %s holds no row for\n' \
        "$preset_image_profile" "$preset_image_profiles" >&2
    exit 2
fi
image_profile_field() {
    printf '%s\n' "$image_profile_row" | sed -n "s/^$1=//p"
}
image_execution_policy=$(image_profile_field execution_policy)
if [ "$image_execution_policy" != validator-gated ]; then
    printf 'image profile %s carries execution_policy %s, and only validator-gated reaches a runtime\n' \
        "$preset_image_profile" "${image_execution_policy:-<absent>}" >&2
    exit 2
fi

authorizer_ready=${QWEN_WEB_AUTHORIZER_READY:-0}
if [ "$authorizer_ready" != 1 ]; then
    printf 'an image section requires QWEN_WEB_AUTHORIZER_READY=1, which asserts that the argument-authorization validator runs\n' >&2
    exit 2
fi

# The approval broker is the only issuer of the grant an image call carries, so
# a section armed for generation without one serves a tool every call is
# refused. qwen-web-launch.sh applies every rule the signing key must meet;
# this wrapper requires the file to be named, because the image MCP child reads
# it under its own name and a launch that named none would reach the model as a
# per-call refusal.
signing_key_file=${QWEN_WEB_TOKEN_KEY_FILE:-}
if [ -z "$signing_key_file" ]; then
    printf 'the image grant signing key is unset\n' >&2
    printf 'QWEN_WEB_TOKEN_KEY_FILE names a regular file at mode 0600, owned by this user, holding the HMAC key\n' >&2
    exit 2
fi
QWEN_IMAGE_TOKEN_KEY_FILE=${QWEN_IMAGE_TOKEN_KEY_FILE:-$signing_key_file}
if [ "$QWEN_IMAGE_TOKEN_KEY_FILE" != "$signing_key_file" ]; then
    printf 'QWEN_IMAGE_TOKEN_KEY_FILE names %s where the broker signs with %s\n' \
        "$QWEN_IMAGE_TOKEN_KEY_FILE" "$signing_key_file" >&2
    printf 'one key signs both grant contexts, which the context string separates\n' >&2
    exit 2
fi

# The service runs a job under validated profile parameters rather than under
# the ledger row, because the row names no runtime binary and no argv template.
# The launch validates the file against the row it claims to serve, so a
# parameter set naming another geometry, another ceiling, or another policy
# refuses here rather than at the first approved generation.
image_profiles_json=${QWEN_IMAGE_PROFILES_JSON:-}
if [ ! -r "$image_profiles_json" ]; then
    printf 'QWEN_IMAGE_PROFILES_JSON names no readable file: %s\n' \
        "${image_profiles_json:-<unset>}" >&2
    printf 'the file holds validated profile parameters keyed by profile_id, which image-service.py runs a job under\n' >&2
    exit 2
fi
if ! image_parameters=$(python3 -c '
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    profiles = json.load(handle)
profile = profiles.get(sys.argv[2])
if not isinstance(profile, dict):
    raise SystemExit("the parameter file holds no object for " + sys.argv[2])
for name in ("width", "height", "steps", "max_steps", "max_dimension",
             "timeout_s", "execution_policy", "runtime_path"):
    if name not in profile:
        raise SystemExit("the parameters omit " + name)
    print("%s=%s" % (name, profile[name]))
' "$image_profiles_json" "$preset_image_profile"); then
    printf 'the image parameter file fails its own shape: %s\n' \
        "$image_profiles_json" >&2
    exit 2
fi
image_parameter_field() {
    printf '%s\n' "$image_parameters" | sed -n "s/^$1=//p"
}
for compared_field in width height steps max_steps max_dimension timeout_s \
    execution_policy; do
    ledger_value=$(image_profile_field "$compared_field")
    parameter_value=$(image_parameter_field "$compared_field")
    if [ "$ledger_value" != "$parameter_value" ]; then
        printf 'image profile %s carries %s %s in %s and %s in %s\n' \
            "$preset_image_profile" "$compared_field" "$ledger_value" \
            "$preset_image_profiles" "$parameter_value" "$image_profiles_json" >&2
        exit 2
    fi
done
image_runtime_path=$(image_parameter_field runtime_path)
if [ ! -x "$image_runtime_path" ]; then
    printf 'the image runtime is absent or not executable: %s\n' \
        "$image_runtime_path" >&2
    exit 2
fi

# The deadline stack is verified from the value each layer is configured with,
# because a number typed here would assert an ordering the system does not
# have. Four layers configure one: the profile row and image-service.py's own
# ceiling bound the runtime, image-service.py bounds the whole job, the
# emitted MCP configuration bounds the tool call, and webui/index.html bounds
# the page's wait. The router proxy configures none in this tree -- the patched
# router proxies with llama-server's own read timeout, 3600 s -- so the launch
# reads that default rather than claiming a 600 s bound nothing sets, and
# QWEN_IMAGE_ROUTER_PROXY_TIMEOUT_S states another where a deployment sets one.
# What the ordering buys is that the innermost deadline fires first: a stalled
# generation is ended by the process that owns it, and the proxy outlasts the
# tool call it is carrying.
runtime_hard_timeout=$(sed -n \
    's/^RUNTIME_HARD_TIMEOUT_SECONDS = \([0-9]\{1,\}\)$/\1/p' \
    "$image_service_program")
service_job_deadline=$(sed -n \
    's/^SERVICE_JOB_DEADLINE_SECONDS = \([0-9]\{1,\}\)$/\1/p' \
    "$image_service_program")
image_profile_timeout=$(image_profile_field timeout_s)
runtime_timeout=$image_profile_timeout
if [ "$runtime_hard_timeout" -lt "$runtime_timeout" ]; then
    runtime_timeout=$runtime_hard_timeout
fi

static_path=${QWEN_STATIC_PATH:-"$script_directory/../webui"}
browser_timeout_ms=$(sed -n \
    's/^const IMAGE_GENERATION_TIMEOUT_MS = \([0-9]\{1,\}\);$/\1/p' \
    "$static_path/index.html")
router_proxy_timeout=${QWEN_IMAGE_ROUTER_PROXY_TIMEOUT_S:-3600}

# The tool deadline is read from the configuration llama-server hands the
# child, rather than from the generator's own marker, because that file is what
# the running child applies. The same read proves the section names the five
# settings the child needs.
image_mcp_configuration=$(sed -n \
    's/^[[:space:]]*LLAMA_ARG_MCP_SERVERS_CONFIG[[:space:]]*=[[:space:]]*//p' \
    "$web_presets" | sed -n '1p')
if [ ! -r "${image_mcp_configuration:-}" ]; then
    printf 'the preset names no readable MCP configuration: %s\n' \
        "${image_mcp_configuration:-<absent>}" >&2
    exit 2
fi
if ! image_mcp_timeout_ms=$(python3 -c '
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    configuration = json.load(handle)
image = configuration.get("mcpServers", {}).get("image")
if not isinstance(image, dict):
    raise SystemExit("the configuration names no image server")
for name in ("QWEN_IMAGE_LANGUAGE_PROFILE", "QWEN_IMAGE_PROFILE",
             "QWEN_IMAGE_TOKEN_KEY_FILE", "QWEN_IMAGE_STATE_DIR",
             "QWEN_IMAGE_SERVICE_SOCKET", "QWEN_IMAGE_MCP_TIMEOUT_S"):
    if not image.get("env", {}).get(name):
        raise SystemExit("the image server names no " + name)
if image["env"]["QWEN_IMAGE_PROFILE"] != sys.argv[2]:
    raise SystemExit("the image server names another profile")
# The router bounds the call at timeout_ms and the child bounds its own socket
# read at QWEN_IMAGE_MCP_TIMEOUT_S. Two numbers for one deadline let the router
# wait past the point the child gave up, so the launch requires them to agree.
router_limit = int(image["timeout_ms"])
child_limit = float(image["env"]["QWEN_IMAGE_MCP_TIMEOUT_S"])
if abs(router_limit / 1000.0 - child_limit) > 0.001:
    raise SystemExit(
        "the image server bounds its call at %d ms and its own read at %g s"
        % (router_limit, child_limit)
    )
print(router_limit)
' "$image_mcp_configuration" "$preset_image_profile"); then
    printf 'the image MCP configuration is unusable: %s\n' \
        "$image_mcp_configuration" >&2
    exit 2
fi
image_mcp_timeout=$((image_mcp_timeout_ms / 1000))
browser_timeout=$((browser_timeout_ms / 1000))

for measured_deadline in "$runtime_timeout" "$service_job_deadline" \
    "$image_mcp_timeout" "$router_proxy_timeout" "$browser_timeout"; do
    case $measured_deadline in
        '' | 0 | *[!0-9]*)
            printf 'a deadline in the stack is unreadable: runtime=%s service=%s mcp=%s proxy=%s browser=%s\n' \
                "$runtime_timeout" "$service_job_deadline" \
                "$image_mcp_timeout" "$router_proxy_timeout" \
                "$browser_timeout" >&2
            exit 2
            ;;
    esac
done

deadline_breach=''
if [ "$runtime_timeout" -ge "$service_job_deadline" ]; then
    deadline_breach='runtime>=service'
elif [ "$service_job_deadline" -ge "$image_mcp_timeout" ]; then
    deadline_breach='service>=mcp'
elif [ "$image_mcp_timeout" -ge "$browser_timeout" ]; then
    deadline_breach='mcp>=browser'
elif [ "$image_mcp_timeout" -ge "$router_proxy_timeout" ]; then
    deadline_breach='mcp>=proxy'
fi
if [ -n "$deadline_breach" ]; then
    printf 'the image deadline stack is out of order at %s: runtime=%s service=%s mcp=%s proxy=%s browser=%s\n' \
        "$deadline_breach" "$runtime_timeout" "$service_job_deadline" \
        "$image_mcp_timeout" "$router_proxy_timeout" "$browser_timeout" >&2
    printf 'a stalled generation is ended by the process that owns it, so each deadline sits inside the one above it\n' >&2
    exit 2
fi
printf 'image_launch timeouts runtime=%s service=%s mcp=%s proxy=%s browser=%s proxy_source=%s\n' \
    "$runtime_timeout" "$service_job_deadline" "$image_mcp_timeout" \
    "$router_proxy_timeout" "$browser_timeout" \
    "${QWEN_IMAGE_ROUTER_PROXY_TIMEOUT_S:+configured}${QWEN_IMAGE_ROUTER_PROXY_TIMEOUT_S:-llama-server-default}"

QWEN_IMAGE_SERVICE=1
QWEN_IMAGE_SERVICE_PROGRAM=$image_service_program
QWEN_IMAGE_PROFILES_JSON=$image_profiles_json
QWEN_IMAGE_PROFILE=$preset_image_profile
export QWEN_IMAGE_SERVICE QWEN_IMAGE_SERVICE_PROGRAM QWEN_IMAGE_PROFILES_JSON
export QWEN_IMAGE_PROFILE QWEN_IMAGE_TOKEN_KEY_FILE
printf 'image_launch profile=%s ledger=%s runtime=%s parameters=%s\n' \
    "$preset_image_profile" "$preset_image_profiles" "$image_runtime_path" \
    "$image_profiles_json"

exec "$web_launcher" "$profile"
