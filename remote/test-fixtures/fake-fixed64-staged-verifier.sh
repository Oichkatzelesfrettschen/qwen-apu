#!/bin/sh
set -eu

# Delegate ordinary summary generation and refuse only the semantic check of
# the staged manifest. The campaign test uses the refusal to prove that neither
# the temporary nor final manifest pathname survives a prepublication failure.

real_summarizer=${QWEN_TEST_FIXED64_REAL_SUMMARIZER:?}
if [ "${1:-}" = --verify-sealed ]; then
    printf 'fake staged semantic verifier failure\n' >&2
    exit 48
fi
exec "$real_summarizer" "$@"
