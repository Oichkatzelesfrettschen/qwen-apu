#!/bin/sh
set -eu

# Stand-in for rocminfo, used by remote/test-rocm10-ladder.sh so the
# enumerate rung runs without a real ROCm install. QWEN_ROCM10_FAKE_LOG, when
# set, receives one line naming the invocation and the HSA_ENABLE_SDMA and
# ROCM_PATH it ran under. QWEN_ROCM10_FAKE_FAIL_STAGE=enumerate makes it
# refuse, for the stop-at-first-failure test.

if [ -n "${QWEN_ROCM10_FAKE_LOG:-}" ]; then
    {
        printf 'run:rocminfo\n'
        printf 'HSA_ENABLE_SDMA=%s ROCM_PATH=%s\n' \
            "${HSA_ENABLE_SDMA:-unset}" "${ROCM_PATH:-unset}"
    } >> "$QWEN_ROCM10_FAKE_LOG"
fi

if [ "${QWEN_ROCM10_FAKE_FAIL_STAGE:-}" = enumerate ]; then
    printf 'fake rocminfo: refusing (QWEN_ROCM10_FAKE_FAIL_STAGE)\n' >&2
    exit 1
fi

printf '*** Agent 2 ***\n'
printf '  Name: gfx902\n'
printf '  Marketing Name: gfx902:xnack+\n'
exit 0
