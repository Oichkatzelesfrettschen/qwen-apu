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
# The listener is 127.0.0.1 by default and a caller asking for any other one is
# refused rather than silently rewritten, for the reason qwen-web-launch.sh
# states: an operator who typed 0.0.0.0 wants an exposure this launch declines
# to provide. QWEN_WEB_LAN=1 with QWEN_WEB_LAN_ADDRESS is that exposure granted
# deliberately, and remote/web-lan-exposure.sh holds its conditions.
#
# One checked-in row of remote/image-profiles.tsv reads `validator-gated`, so
# the preset a generator writes against the shipped ledger under
# QWEN_WEB_AUTHORIZER_READY=1 names that image profile and this launch arms the
# path. A preset naming none refuses and says so, and promoting a further row
# is a measurement on the appliance.
#
# The ledger row's `review_model` decides whether a second section serves. A
# named reviewer makes the preset two sections -- the language profile and one
# review-only vision section carrying that row's validated tuple and its
# projector -- and the page's Review button then appears, because it appears
# where `GET /props?model=` reports a vision modality for some roster row. Two
# resident checkpoints share one Vulkan carve-out that the 4B alone fills to
# 2029 of 2048 MiB, so the pair is measured before it is served: this wrapper
# sums every model and projector the preset names, adds the image runtime's own
# resident cost, hands the total to model-memory-preflight.sh, and refuses on
# the `vulkan_budget_headroom=short` line the probe reports. The preflight
# stays the single authority for what the device has, and the launch is a
# reader of it. A `-` review_model leaves one section, and the review runs
# through remote/image-review.py against a separate launch.

if [ "$#" -gt 1 ]; then
    printf 'usage: %s [paced-60|low-serialized|low-async]\n' "$0" >&2
    printf 'web preset file comes from QWEN_WEB_PRESETS, default $HOME/qwen-webui-state/web-presets.ini\n' >&2
    printf 'the preset must name an image profile, which requires a validator-gated row in remote/image-profiles.tsv\n' >&2
    printf 'QWEN_IMAGE_PROFILES_JSON names the validated profile parameters the image service runs a job under\n' >&2
    printf 'QWEN_IMAGE_RUNTIME_RESIDENT_MIB is the image runtime cost charged against the Vulkan budget, default 480\n' >&2
    printf 'the listener is 127.0.0.1; QWEN_BIND_HOST set to any other value refuses the launch\n' >&2
    printf 'QWEN_WEB_LAN=1 with QWEN_WEB_LAN_ADDRESS naming a routable IPv4 literal serves the network instead, with the Web UI bearer required on every route\n' >&2
    exit 2
fi

profile=${1:-low-async}
script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
web_launcher=$script_directory/qwen-web-launch.sh
image_service_program=${QWEN_IMAGE_SERVICE_PROGRAM:-$script_directory/image-service.py}
state_directory=${QWEN_WEBUI_STATE_DIRECTORY:-"${HOME:?}/qwen-webui-state"}
web_presets=${QWEN_WEB_PRESETS:-$state_directory/web-presets.ini}
# The marker rejoin, the parameter comparison, the deadline stack, and the
# device charge live in one file, because qwen-launch.sh arms the same lane from
# the merged roster preset.
# shellcheck source=remote/image-launch-lib.sh
. "$script_directory/image-launch-lib.sh"

# QWEN_WEB_LAN=1 is the operator's explicit decision to serve this lane on the
# network. This wrapper checks the shape of the request and reports it; the six
# conditions in remote/web-lan-exposure.sh are applied once, by the web
# launcher this script execs into, so one authority admits both lanes.
web_lan_exposure=${QWEN_WEB_LAN:-0}
case $web_lan_exposure in
    0 | 1) ;;
    *)
        printf 'QWEN_WEB_LAN must be 0 or 1: %s\n' "$web_lan_exposure" >&2
        exit 2
        ;;
esac
if [ "$web_lan_exposure" = 1 ]; then
    if [ -z "${QWEN_WEB_LAN_ADDRESS:-}" ]; then
        printf 'QWEN_WEB_LAN=1 requires QWEN_WEB_LAN_ADDRESS naming a routable IPv4 literal\n' >&2
        exit 2
    fi
    printf 'image_launch exposure=lan address=%s bearer=required\n' \
        "$QWEN_WEB_LAN_ADDRESS"
else
    requested_bind_host=${QWEN_BIND_HOST:-127.0.0.1}
    if [ "$requested_bind_host" != 127.0.0.1 ]; then
        printf 'image router mode serves the loopback alone, and QWEN_BIND_HOST requests %s\n' \
            "$requested_bind_host" >&2
        printf 'an image section spawns a device runtime through its MCP server; unset QWEN_BIND_HOST or set it to 127.0.0.1, or set QWEN_WEB_LAN=1 to serve the network deliberately\n' >&2
        exit 2
    fi
    printf 'image_launch exposure=loopback\n'
fi

if [ ! -r "$web_presets" ]; then
    printf 'web presets are unreadable: %s\n' "$web_presets" >&2
    printf 'generate them with remote/build-web-presets.sh\n' >&2
    exit 2
fi

# The generator records the image profile it emitted, the ledger it read, and
# that ledger's digest, so the launch reads one authority out of the file it
# launches rather than re-deriving it from an environment that may have moved.
# remote/image-launch-lib.sh holds those rules, because qwen-launch.sh arms the
# same lane from the merged roster preset and a second copy would let the two
# launchers disagree about what an armed lane is.
read_image_preset_markers "$web_presets"
if [ -z "$preset_image_profile" ]; then
    printf 'the preset carries no image markers: %s\n' "$web_presets" >&2
    printf 'regenerate it with a remote/build-web-presets.sh that reads remote/image-profiles.tsv\n' >&2
    exit 2
fi
if [ "$image_lane_armed" != 1 ]; then
    printf 'every image profile in %s withholds an executing policy, so the preset arms no generation\n' \
        "${preset_image_profiles:-remote/image-profiles.tsv}" >&2
    printf 'every checked-in row reads refused; a validator-gated row is a measurement on the appliance and the only thing this launch runs\n' >&2
    printf 'launch the ordinary web router with remote/qwen-web-launch.sh\n' >&2
    exit 2
fi
require_image_ledger_row || exit 2

if [ -z "$preset_review_model" ] || [ -z "$preset_review_section" ]; then
    printf 'the preset carries no review markers: %s\n' "$web_presets" >&2
    printf 'regenerate it with a remote/build-web-presets.sh that reads review_model\n' >&2
    exit 2
fi
if [ "$preset_review_model" = '-' ]; then
    if [ "$preset_review_section" != '-' ]; then
        printf 'the preset names review section %s against review_model -\n' \
            "$preset_review_section" >&2
        exit 2
    fi
    review_section=
    expected_section_count=1
else
    if [ "$preset_review_section" != "$preset_review_model" ]; then
        printf 'the preset names review section %s for review_model %s\n' \
            "$preset_review_section" "$preset_review_model" >&2
        exit 2
    fi
    review_section=$preset_review_section
    expected_section_count=2
fi

# The section shape is read out of the file the launch hands on, because a
# preset persists across the generation that wrote it. A third section would
# leave the broker signing for one profile while two others served, and a
# review section stripped of its projector would answer an image request from
# nothing while the roster still advertises a vision modality.
preset_section_count=$(grep -c '^\[[^]]*\]$' "$web_presets" || true)
if [ "$preset_section_count" -ne "$expected_section_count" ]; then
    printf 'image router mode serves %s section(s) and %s carries %s\n' \
        "$expected_section_count" "$web_presets" "$preset_section_count" >&2
    printf 'one language section serves the turn, and a review_model adds one review-only vision section\n' >&2
    exit 2
fi
if [ -n "$review_section" ]; then
    if ! review_section_shape=$(awk -v wanted="$review_section" '
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
            if (key == "LLAMA_ARG_MMPROJ") projector = value
            if (key == "LLAMA_ARG_MCP_SERVERS_CONFIG") configuration = value
            if (key == "LLAMA_ARG_TAGS") tags = value
        }
        END {
            if (projector == "") {
                print "the review section names no LLAMA_ARG_MMPROJ" > "/dev/stderr"
                exit 1
            }
            if (configuration != "") {
                print "the review section names an MCP configuration: " configuration > "/dev/stderr"
                exit 1
            }
            if (tags !~ /(^|,)review-only(,|$)/) {
                print "the review section carries tags " tags > "/dev/stderr"
                exit 1
            }
            print projector
        }
    ' "$web_presets"); then
        printf 'the review section %s is unusable in %s\n' \
            "$review_section" "$web_presets" >&2
        printf 'a reviewer reads an image through its own projector and holds no execution grant\n' >&2
        exit 2
    fi
    printf 'image_launch review_section=%s projector=%s\n' \
        "$review_section" "$review_section_shape"
fi

authorizer_ready=${QWEN_WEB_AUTHORIZER_READY:-0}
if [ "$authorizer_ready" != 1 ]; then
    printf 'an image section requires QWEN_WEB_AUTHORIZER_READY=1, which asserts that the argument-authorization validator runs\n' >&2
    exit 2
fi

require_image_signing_key || exit 2
require_image_parameters || exit 2

# The language profile is this file's first section, which is the one section
# the broker signs for; the review section follows it and carries no
# configuration of its own.
image_language_section=${QWEN_WEB_PROFILE:-$(sed -n 's/^\[\([^]]*\)\]$/\1/p' \
    "$web_presets" | sed -n '1p')}
verify_image_deadline_stack "$web_presets" "$image_language_section" || exit 2

# Two resident checkpoints and a running image runtime draw on one Vulkan
# carve-out, so the requirement is summed from what the preset names and the
# probe answers whether the device holds it. This file serves one language
# section and at most one reviewer, and qwen-web-launch.sh raises QWEN_ROUTER_MAX
# to two where the reviewer exists, so every artifact it names can be resident at
# once and the sum charges them all.
read_image_runtime_resident_mib || exit 2
# The named paths reach the loop through a file rather than through command
# substitution, which field-splits a path holding a space, and the loop reads
# from a redirection so its running total survives it.
resident_artifact_list=$(mktemp)
trap 'rm -f -- "$resident_artifact_list"' EXIT HUP INT TERM
awk '
    {
        separator = index($0, "=")
        if (separator == 0) next
        key = substr($0, 1, separator - 1)
        value = substr($0, separator + 1)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", key)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
        if (key == "LLAMA_ARG_MODEL" || key == "LLAMA_ARG_MMPROJ") print value
    }
' "$web_presets" >"$resident_artifact_list"
if [ ! -s "$resident_artifact_list" ]; then
    printf 'the preset names no weights to size the device against: %s\n' \
        "$web_presets" >&2
    exit 2
fi
resident_artifact_bytes=0
while IFS= read -r resident_artifact; do
    [ -n "$resident_artifact" ] || continue
    if [ ! -f "$resident_artifact" ]; then
        printf 'the preset names an artifact this machine holds no file for: %s\n' \
            "$resident_artifact" >&2
        exit 2
    fi
    resident_artifact_bytes=$((resident_artifact_bytes + $(wc -c <"$resident_artifact")))
done <"$resident_artifact_list"
rm -f -- "$resident_artifact_list"
trap - EXIT HUP INT TERM
mebibyte=1048576
resident_artifact_mib=$(((resident_artifact_bytes + mebibyte - 1) / mebibyte))
required_vulkan_mib=$((resident_artifact_mib + image_runtime_resident_mib))
preflight_subject=$(sed -n \
    's/^[[:space:]]*LLAMA_ARG_MODEL[[:space:]]*=[[:space:]]*//p' \
    "$web_presets" | sed -n '1p')
run_image_memory_preflight "$preflight_subject" "$required_vulkan_mib" || exit 2
printf 'image_launch budget artifacts_mib=%s runtime_mib=%s required_mib=%s sections=%s\n' \
    "$resident_artifact_mib" "$image_runtime_resident_mib" \
    "$required_vulkan_mib" "$preset_section_count"
# The refusal belongs to the pairing rather than to the lane. A one-section
# launch is the shape evidence/image-appliance/served-turn-admission/ ran and
# passed without this arithmetic, and model-memory-preflight.sh reports rather
# than refuses because a prediction of this kind was wrong once and read as a
# hardware limit; the number is printed on both paths and decides only the
# launch that adds a second resident checkpoint the appliance has never held.
if [ -n "$review_section" ] &&
    printf '%s\n' "$image_budget_report" |
    grep -q '^vulkan_budget_headroom=short'; then
    printf 'the Vulkan budget holds less than the %s MiB this preset needs, plus the margin the probe adds\n' \
        "$required_vulkan_mib" >&2
    printf '%s\n' "$image_budget_report" | grep '^vulkan_budget_headroom=' >&2
    printf 'pair the image row with a smaller review_model, or set review_model to - and review through remote/image-review.py\n' >&2
    exit 2
fi
# The session runs its own preflight against the same denominator, so the two
# reports read one requirement rather than this launch measuring the pair and
# the session measuring a fixed default.
QWEN_REQUIRED_VULKAN_MIB=$required_vulkan_mib
export QWEN_REQUIRED_VULKAN_MIB
if [ -n "$review_section" ]; then
    QWEN_WEB_REVIEW_SECTION=$review_section
    export QWEN_WEB_REVIEW_SECTION
fi

export_image_service_environment

exec "$web_launcher" "$profile"
