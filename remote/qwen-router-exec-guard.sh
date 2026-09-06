#!/bin/sh
set -eu

# Verify the identities that the capacity policy validated after the Vulkan
# environment is configured and immediately before llama-server replaces this
# process. The server never reads these authorities; their identities bind the
# assembled argv to the exact preset, model registry, quarantine registry,
# draft-pair registry, web profile ledger, and context checkpoint ledger whose
# identities admitted the server command. A ledger that does not apply to one
# preset carries `-` for both its path and digest.
#
# The context checkpoint ledger is required rather than optional, because every
# router and web preset section carries LLAMA_ARG_CTX_CHECKPOINTS and the launch
# rejoins that key to the ledger's rows. A replacement between validation and
# exec would otherwise admit a count the ledger no longer states, and the pinned
# build defaults n_ctx_checkpoints to 32 where the ledger admits at most two.

if [ "$#" -lt 14 ]; then
    printf 'usage: %s PRESET PRESET_SHA MODEL_REGISTRY MODEL_SHA QUARANTINE_REGISTRY QUARANTINE_SHA DRAFT_PAIRS DRAFT_PAIRS_SHA WEB_PROFILES WEB_PROFILES_SHA CTX_CHECKPOINT_LEDGER CTX_CHECKPOINT_LEDGER_SHA REQUIRED_Q4K_KEYS COMMAND [ARG ...]\n' \
        "$0" >&2
    exit 2
fi

preset_path=$1
shift
preset_sha256=$1
shift
model_registry_path=$1
shift
model_registry_sha256=$1
shift
quarantine_registry_path=$1
shift
quarantine_registry_sha256=$1
shift
draft_pairs_path=$1
shift
draft_pairs_sha256=$1
shift
web_profiles_path=$1
shift
web_profiles_sha256=$1
shift
ctx_checkpoint_ledger_path=$1
shift
ctx_checkpoint_ledger_sha256=$1
shift
required_q4k_keys=$1
shift

verify_identity() {
    identity_name=$1
    identity_path=$2
    expected_sha256=$3
    if [ "${#expected_sha256}" -ne 64 ]; then
        printf '%s SHA-256 must hold 64 lowercase hexadecimal characters\n' \
            "$identity_name" >&2
        return 1
    fi
    case $expected_sha256 in
        *[!0-9a-f]*)
            printf '%s SHA-256 must hold 64 lowercase hexadecimal characters\n' \
                "$identity_name" >&2
            return 1
            ;;
    esac
    if ! measured_identity=$(sha256sum -- "$identity_path"); then
        printf '%s identity cannot be measured: %s\n' \
            "$identity_name" "$identity_path" >&2
        return 1
    fi
    measured_sha256=${measured_identity%% *}
    if [ "$measured_sha256" != "$expected_sha256" ]; then
        printf '%s identity changed: expected %s, measured %s\n' \
            "$identity_name" "$expected_sha256" "$measured_sha256" >&2
        return 1
    fi
}

verify_identity 'router preset' "$preset_path" "$preset_sha256"
verify_identity 'router model registry' \
    "$model_registry_path" "$model_registry_sha256"
verify_identity 'router quarantine registry' \
    "$quarantine_registry_path" "$quarantine_registry_sha256"
if [ "$draft_pairs_path" = - ] || [ "$draft_pairs_sha256" = - ]; then
    if [ "$draft_pairs_path" != - ] || [ "$draft_pairs_sha256" != - ]; then
        printf 'router draft-pair ledger path and SHA-256 must both be `-` or both be present\n' >&2
        exit 1
    fi
else
    verify_identity 'router draft-pair ledger' \
        "$draft_pairs_path" "$draft_pairs_sha256"
fi
if [ "$web_profiles_path" = - ] || [ "$web_profiles_sha256" = - ]; then
    if [ "$web_profiles_path" != - ] || [ "$web_profiles_sha256" != - ]; then
        printf 'router web profile ledger path and SHA-256 must both be `-` or both be present\n' >&2
        exit 1
    fi
else
    verify_identity 'router web profile ledger' \
        "$web_profiles_path" "$web_profiles_sha256"
fi
verify_identity 'router context checkpoint ledger' \
    "$ctx_checkpoint_ledger_path" "$ctx_checkpoint_ledger_sha256"

# The Q4_K formulation requirement is what qwen-build-exec-guard.sh held the
# manifest to, and it is derived rather than declared: the policy reads the keys
# off the preset sections. This guard re-derives them from the preset whose
# digest it has just verified and requires the same set, so a derivation that
# missed a section would leave that section serving a formulation no build
# authority admitted. The two readings are one decision made twice over the same
# bytes.
measured_q4k_keys=$(awk '
    /^[[:space:]]*LLAMA_ARG_VK_Q4K_VARIANT[[:space:]]*=/ {
        value = $0
        sub(/^[^=]*=[[:space:]]*/, "", value)
        sub(/[[:space:]]+$/, "", value)
        if (value != "" && !seen[value]++) {
            keys = keys (keys == "" ? "" : ",") value
        }
    }
    END { print (keys == "") ? "-" : keys }
' "$preset_path")
if [ "$measured_q4k_keys" != "$required_q4k_keys" ]; then
    printf 'router preset names Q4_K formulations %s where the policy bound %s\n' \
        "$measured_q4k_keys" "$required_q4k_keys" >&2
    exit 1
fi

exec "$@"
