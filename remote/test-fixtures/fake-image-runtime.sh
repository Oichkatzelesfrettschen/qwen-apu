#!/bin/sh
set -eu

# The stand-in for sd-cli that lets remote/run-image-standalone.sh run its
# cold/warm arms, telemetry capture, and refusal paths without the device.
# It answers three request shapes sd-cli itself answers: a device listing, an
# ordinary generation, and a generation whose named backend device does not
# resolve, which evidence/image-appliance/stable-diffusion-cpp-pin.md traces
# to a nonzero exit through StableDiffusionGGML::ensure_backend_pair,
# new_sd_ctx, and examples/cli/main.cpp's "new_sd_ctx_t failed" path.

if [ "${1:-}" = --list-devices ]; then
    printf 'Vulkan0\t%s\n' "${QWEN_FAKE_IMAGE_DEVICE_DESCRIPTION:-AMD Radeon Graphics (RADV RAVEN2) (RADV RAVEN2)}"
    exit 0
fi

output_path=''
model_path=''
backend_argument=''
previous_argument=''
for argument in "$@"; do
    case $previous_argument in
        -o | --output) output_path=$argument ;;
        -m | --model) model_path=$argument ;;
        --backend) backend_argument=$argument ;;
    esac
    previous_argument=$argument
done

# A backend value naming the refusal-control marker
# (remote/run-image-standalone.sh's run_refusal_control) refuses on its own,
# the way an unresolvable device name refuses against the real binary, so a
# caller need not also set QWEN_FAKE_IMAGE_DEVICE_REFUSAL for the harness's
# own control arm to exercise the refusal path.
# QWEN_FAKE_IMAGE_IGNORE_REFUSAL_MARKER=1 disables that auto-detection, which
# is what a test needs to reach the harness's own safety check for a runtime
# that accepts an unresolvable device name instead of refusing it.
if [ "${QWEN_FAKE_IMAGE_IGNORE_REFUSAL_MARKER:-0}" != 1 ]; then
    case $backend_argument in
        *_refusal_control_*) QWEN_FAKE_IMAGE_DEVICE_REFUSAL=1 ;;
    esac
fi

if [ -n "${QWEN_FAKE_IMAGE_ARGV_OUTPUT:-}" ]; then
    {
        printf 'argument_count=%s\n' "$#"
        for argument in "$@"; do
            printf 'argument=%s\n' "$argument"
        done
        printf 'model_path=%s\n' "$model_path"
        printf 'output_path=%s\n' "$output_path"
    } >"$QWEN_FAKE_IMAGE_ARGV_OUTPUT"
fi

# A backend name absent from --list-devices refuses the run: the pinned audit
# traces this to SDBackendManager::init_cached_backend's LOG_ERROR and a
# nonzero sd-cli exit rather than a silent CPU placement.
if [ "${QWEN_FAKE_IMAGE_DEVICE_REFUSAL:-0}" = 1 ]; then
    printf "[ERROR] ggml_extend_backend.cpp:920 - backend '%s' was not found\n" \
        "${QWEN_FAKE_IMAGE_REFUSED_DEVICE:-vulkan9}" >&2
    printf '[INFO ] main.cpp:911  - new_sd_ctx_t failed\n' >&2
    exit 1
fi

# Phase durations are small and overridable so a test arm completes in well
# under a second while still producing two distinct wall-clock samples for
# the harness's phase-boundary parser to read.
text_encoder_seconds=${QWEN_FAKE_IMAGE_TE_SECONDS:-0.02}
diffusion_seconds=${QWEN_FAKE_IMAGE_DIFFUSION_SECONDS:-0.04}
vae_seconds=${QWEN_FAKE_IMAGE_VAE_SECONDS:-0.02}

printf '[INFO ] stable-diffusion.cpp:710  - loading model from '"'"'%s'"'"'\n' "$model_path"
printf '[INFO ] stable-diffusion.cpp:4371 - sampling using %s method\n' "${QWEN_FAKE_IMAGE_SAMPLER:-euler_a}"
sleep "$text_encoder_seconds"
printf '[INFO ] stable-diffusion.cpp:5287 - get_learned_condition completed, taking %ss\n' \
    "$text_encoder_seconds"
sleep "$diffusion_seconds"
printf '[INFO ] stable-diffusion.cpp:5702 - sampling completed, taking %ss\n' "$diffusion_seconds"
sleep "$vae_seconds"
printf '[INFO ] stable-diffusion.cpp:5382 - decode_first_stage completed, taking %ss\n' "$vae_seconds"

if [ "${QWEN_FAKE_IMAGE_SKIP_PNG:-0}" != 1 ] && [ -n "$output_path" ]; then
    # A minimal single-pixel PNG, built without a dependency on a PNG library
    # being installed for the test to exercise the harness's own hashing and
    # validation path.
    python3 -c "
import sys, zlib, struct

def chunk(tag, data):
    body = tag + data
    return struct.pack('>I', len(data)) + body + struct.pack('>I', zlib.crc32(body) & 0xffffffff)

signature = b'\x89PNG\r\n\x1a\n'
ihdr = chunk(b'IHDR', struct.pack('>IIBBBBB', 1, 1, 8, 2, 0, 0, 0))
idat = chunk(b'IDAT', zlib.compress(b'\x00\x00\x00\x00'))
iend = chunk(b'IEND', b'')
with open(sys.argv[1], 'wb') as handle:
    handle.write(signature + ihdr + idat + iend)
" "$output_path"
fi

total_seconds=$(awk -v a="$text_encoder_seconds" -v b="$diffusion_seconds" -v c="$vae_seconds" \
    'BEGIN { printf "%.2f", a + b + c }')
printf '[INFO ] stable-diffusion.cpp:5852 - generate_image completed in %ss\n' "$total_seconds"

exit "${QWEN_FAKE_IMAGE_EXIT_STATUS:-0}"
