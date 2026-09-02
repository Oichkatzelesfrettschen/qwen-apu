# shellcheck shell=sh
# Shared preflight for the served campaigns that bind two llama-server
# binaries against one scoreboard denominator. run-raven2-vulkan-kernel-census.sh
# binds P against I; run-served-binary-ab.sh binds the control against the
# candidate. Both decide the same six questions -- where the manifest sits,
# whether it describes the executable, what one manifest key says, what base
# build a server descends from, whether a command substitution printed a whole
# binding, and whether the scoreboard receipt states this run's own denominator
# -- so the answers live here and a rule tightened for one campaign reaches the
# other.
#
# This file is sourced rather than executed: it defines functions and runs
# nothing. Every function is pure in the sense that matters here -- it reads its
# arguments and the files they name, and writes to stdout, stderr, or the path
# it is given. A refusal exits 2 from the shell that sourced it, which is what
# the callers want at preflight; census_bind_server runs inside a command
# substitution at both call sites, so its exit ends the subshell alone and
# census_require_binding_fields is what turns that into the caller's refusal.

# The manifest sits beside a bundled server or one directory above a build
# tree's bin/. Prints the path of the first that is readable.
census_manifest_beside() {
    census_manifest_candidate=$(dirname -- "$1")/artifact-manifest.tsv
    if [ ! -r "$census_manifest_candidate" ]; then
        census_manifest_candidate=$(dirname -- "$1")/../artifact-manifest.tsv
    fi
    if [ ! -r "$census_manifest_candidate" ]; then
        printf 'the %s server carries no artifact manifest beside it or above its bin/: %s\n' \
            "$2" "$1" >&2
        exit 2
    fi
    printf '%s\n' "$census_manifest_candidate"
}

# Prints sha256, bytes, manifest sha256, checkpoint_semantics, and
# checkpoint_patch_series_sha256 for one server, refusing a manifest that does
# not describe it or that names checkpoint semantics the checkpoint count
# cannot run under. The executable is bound to the manifest by byte count and
# digest, the rule the bundle verifier and the exec guard apply, so a manifest
# carrying one matching row beside a conflicting one is ambiguous here as it is
# there.
#
# census_bind_server ROLE SERVER MANIFEST CTX_CHECKPOINTS
census_bind_server() {
    census_bound_role=$1
    census_bound_server=$2
    census_bound_manifest=$3
    census_bound_checkpoints=$4
    if [ ! -x "$census_bound_server" ]; then
        printf 'the %s server must be an executable: %s\n' \
            "$census_bound_role" "${census_bound_server:--}" >&2
        exit 2
    fi
    census_bound_sha256=$(sha256sum "$census_bound_server" | cut -d ' ' -f 1)
    census_bound_bytes=$(wc -c <"$census_bound_server" | tr -d ' ')
    if ! awk -F'\t' -v bytes="$census_bound_bytes" -v digest="$census_bound_sha256" '
        $1 == "executable" && $2 == "llama-server" { named++
            if (NF == 4 && $3 == bytes && $4 == digest) found++ }
        END { exit (named == 1 && found == 1) ? 0 : 1 }' "$census_bound_manifest"; then
        printf 'the %s server is not the one executable llama-server row its manifest carries: %s\n' \
            "$census_bound_role" "$census_bound_server" >&2
        exit 2
    fi
    census_bound_semantics=$(awk -F'\t' '$1 == "checkpoint_semantics" { count++; value = $2 }
        END { if (count != 1) exit 1; print value }' "$census_bound_manifest") || {
        printf 'the %s manifest holds other than one checkpoint_semantics row\n' \
            "$census_bound_role" >&2
        exit 2
    }
    if [ "$census_bound_checkpoints" -gt 0 ] && \
        [ "$census_bound_semantics" != natural-boundary-v1 ]; then
        printf 'the %s server declares checkpoint semantics %s and the registry row runs %s checkpoints; natural-boundary-v1 is required\n' \
            "$census_bound_role" "$census_bound_semantics" "$census_bound_checkpoints" >&2
        exit 2
    fi
    census_bound_series=$(awk -F'\t' '$1 == "checkpoint_patch_series_sha256" { count++; value = $2 }
        END { if (count != 1) exit 1; print value }' "$census_bound_manifest") || {
        printf 'the %s manifest holds other than one checkpoint_patch_series_sha256 row\n' \
            "$census_bound_role" >&2
        exit 2
    }
    printf '%s\t%s\t%s\t%s\t%s\n' "$census_bound_sha256" "$census_bound_bytes" \
        "$(sha256sum "$census_bound_manifest" | cut -d ' ' -f 1)" \
        "$census_bound_semantics" "$census_bound_series"
}

# The binding runs in a command substitution, so its status is captured
# explicitly at the call site and every field is required nonempty before the
# caller reads it: a refusal inside a here-document substitution ends only the
# subshell and leaves read filling every field empty, which is how a mismatched
# instrumented manifest once entered the arm loop.
census_require_binding_fields() {
    if ! printf '%s\n' "$2" | awk -F'\t' 'NF != 5 { exit 1 }
        { for (i = 1; i <= NF; i++) if ($i == "") exit 1 }'; then
        printf 'the %s binding printed other than five nonempty fields\n' "$1" >&2
        exit 2
    fi
}

# Prints the one value of a manifest key; other than one row is a refusal the
# caller carries out explicitly, since this runs in a substitution.
#
# census_manifest_value MANIFEST KEY ROLE
census_manifest_value() {
    awk -F'\t' -v key="$2" '$1 == key { count++; value = $2 }
        END { if (count != 1) exit 1; print value }' "$1" || {
        printf 'the %s manifest holds other than one %s row\n' "$3" "$2" >&2
        return 2
    }
}

# Writes the base-build identity of one manifest and server to OUTPUT: the
# llama.cpp commit, the production patch series digest, the checkpoint patch
# and source digests, the compiler flags, and the CMake flags with STRIP_FLAG
# removed, closed by the compiler identity read from the executable's own
# .comment section, since the manifest records flags rather than the toolchain.
# Two servers that differ by one compile-time flag or one candidate patch write
# the same file; two built from different sources or toolchains do not.
# STRIP_FLAG empty removes nothing, which is the comparison two serving-shaped
# builds want.
#
# census_base_build_identity MANIFEST SERVER ROLE OUTPUT STRIP_FLAG
census_base_build_identity() {
    census_identity_manifest=$1
    census_identity_server=$2
    census_identity_role=$3
    census_identity_output=$4
    census_identity_strip=$5
    census_identity_commit=$(census_manifest_value "$census_identity_manifest" \
        commit "$census_identity_role") || exit 2
    census_identity_series=$(census_manifest_value "$census_identity_manifest" \
        checkpoint_patch_series_sha256 "$census_identity_role") || exit 2
    census_identity_patch=$(census_manifest_value "$census_identity_manifest" \
        checkpoint_patch_sha256 "$census_identity_role") || exit 2
    census_identity_source=$(census_manifest_value "$census_identity_manifest" \
        checkpoint_source_sha256 "$census_identity_role") || exit 2
    census_identity_compiler_flags=$(census_manifest_value "$census_identity_manifest" \
        compiler_flags "$census_identity_role") || exit 2
    census_identity_cmake=$(census_manifest_value "$census_identity_manifest" \
        cmake_flags "$census_identity_role") || exit 2
    if [ -n "$census_identity_strip" ]; then
        census_identity_cmake=$(printf '%s\n' "$census_identity_cmake" | tr ' ' '\n' \
            | grep -vx -- "$census_identity_strip" | tr '\n' ' ' | sed 's/ *$//') || true
    fi
    census_identity_compiler=$(readelf -p .comment "$census_identity_server" 2>/dev/null \
        | sed -n 's/^ *\[ *[0-9]*\] *//p' | sort | tr '\n' ';')
    # Two empty compiler strings compare equal and prove nothing, so an
    # executable whose .comment section names no compiler refuses.
    if [ -z "$census_identity_compiler" ]; then
        printf 'the %s server carries no compiler identity in its .comment section: %s\n' \
            "$census_identity_role" "$census_identity_server" >&2
        exit 2
    fi
    {
        printf 'commit\t%s\n' "$census_identity_commit"
        printf 'checkpoint_patch_series_sha256\t%s\n' "$census_identity_series"
        printf 'checkpoint_patch_sha256\t%s\n' "$census_identity_patch"
        printf 'checkpoint_source_sha256\t%s\n' "$census_identity_source"
        printf 'compiler_flags\t%s\n' "$census_identity_compiler_flags"
        printf 'cmake_flags_common\t%s\n' "$census_identity_cmake"
        printf 'compiler_identity\t%s\n' "$census_identity_compiler"
    } >"$census_identity_output"
}

# The production receipt binding: the identity-check.tsv of the fixed-64
# scoreboard sweep whose denominator the control server stands for. Its one
# server row carries that digest and byte count as both expected and observed,
# accepted; the models-resolved.tsv beside it resolves this model to the tuple
# the registry and ledger resolve it to now; and the campaign-inputs.tsv there
# states every setting the arms rerun under, each exactly once. A key that
# repeats, whatever its second value, is a conflicting record rather than a
# stronger statement, so the count per key is required to be one rather than
# its presence alone. Prints the two digests, tab separated, in that order.
#
# TUPLE is one tab-delimited record of ten fields, in this order: context,
# batch, ubatch, cache_k, cache_v, flash_attention, ctx_checkpoints,
# checkpoint_min_step, model_bytes, model_sha256. It travels as one argument
# because it is one claim: the denominator the receipt and this run must share.
#
# census_verify_scoreboard_receipt RECEIPT SERVER_SHA256 SERVER_BYTES \
#     REQUIRE_GENERATE MODEL_ID TUPLE
census_verify_scoreboard_receipt() {
    census_receipt=$1
    census_receipt_digest=$2
    census_receipt_bytes=$3
    census_receipt_require_generate=$4
    census_receipt_model=$5
    census_receipt_tuple=$6
    if [ ! -r "$census_receipt" ]; then
        printf 'the production receipt must name the readable identity-check.tsv of the scoreboard sweep: %s\n' \
            "${census_receipt:--}" >&2
        exit 2
    fi
    if ! awk -F'\t' -v bytes="$census_receipt_bytes" -v digest="$census_receipt_digest" '
        NR == 1 && $0 != "subject\tpath\texpected_bytes\tobserved_bytes\texpected_sha256\tobserved_sha256\tstate" { exit 1 }
        $1 == "server" { rows++; if ($3 == bytes && $4 == bytes && $5 == digest && $6 == digest && $7 == "accepted") matched++ }
        END { exit (rows == 1 && matched == 1) ? 0 : 1 }' "$census_receipt"; then
        printf 'the scoreboard receipt does not carry one accepted server row with the digest %s and %s bytes: %s\n' \
            "$census_receipt_digest" "$census_receipt_bytes" "$census_receipt" >&2
        exit 2
    fi
    census_receipt_directory=$(dirname -- "$census_receipt")
    census_scoreboard_models=$census_receipt_directory/models-resolved.tsv
    census_scoreboard_inputs=$census_receipt_directory/campaign-inputs.tsv
    for census_scoreboard_file in "$census_scoreboard_models" "$census_scoreboard_inputs"; do
        if [ ! -r "$census_scoreboard_file" ]; then
            printf 'the scoreboard receipt directory carries no readable %s\n' \
                "$(basename -- "$census_scoreboard_file")" >&2
            exit 2
        fi
    done
    IFS="$(printf '\t')" read -r census_tuple_context census_tuple_batch census_tuple_ubatch \
        census_tuple_cache_k census_tuple_cache_v census_tuple_flash \
        census_tuple_checkpoints census_tuple_min_step census_tuple_bytes \
        census_tuple_digest census_tuple_excess <<CENSUS_TUPLE
$census_receipt_tuple
CENSUS_TUPLE
    if [ -z "$census_tuple_digest" ] || [ -n "$census_tuple_excess" ]; then
        printf 'the scoreboard tuple must carry ten nonempty tab-separated fields\n' >&2
        exit 2
    fi
    if ! awk -F'\t' -v id="$census_receipt_model" -v context="$census_tuple_context" \
        -v batch="$census_tuple_batch" -v ubatch="$census_tuple_ubatch" \
        -v cache_k="$census_tuple_cache_k" -v cache_v="$census_tuple_cache_v" \
        -v flash="$census_tuple_flash" -v checkpoints="$census_tuple_checkpoints" \
        -v min_step="$census_tuple_min_step" -v bytes="$census_tuple_bytes" \
        -v digest="$census_tuple_digest" '
        NR == 1 { for (i = 1; i <= NF; i++) column[$i] = i; next }
        $(column["model_id"]) == id { rows++
            if ($(column["context"]) == context && $(column["batch"]) == batch \
                && $(column["ubatch"]) == ubatch && $(column["cache_k"]) == cache_k \
                && $(column["cache_v"]) == cache_v && $(column["flash_attention"]) == flash \
                && $(column["ctx_checkpoints"]) == checkpoints \
                && $(column["checkpoint_min_step"]) == min_step \
                && $(column["model_bytes"]) == bytes && $(column["model_sha256"]) == digest \
                && $(column["publisher_sha256"]) == digest) matched++ }
        END { exit (rows == 1 && matched == 1) ? 0 : 1 }' "$census_scoreboard_models"; then
        printf 'the scoreboard resolved %s to a tuple other than the one the registry and ledger resolve now: %s\n' \
            "$census_receipt_model" "$census_scoreboard_models" >&2
        exit 2
    fi
    if ! awk -F'\t' -v require_generate="$census_receipt_require_generate" '
        BEGIN {
            expected["vulkan_profile"] = "low-async"
            expected["sampling"] = "temperature=0 top_k=1 seed=1 ignore_eos=true thinking=false"
            expected["server_nice"] = "19"
            expected["inference_cpu"] = "0"
            expected["speculation"] = "off"
            expected["router"] = "0"
            expected["server_io_class"] = "idle"
            expected["backend_sampling"] = "0"
            expected["latency_mode"] = "observe"
            expected["web_broker"] = "0"
            expected["image_service"] = "0"
            if (require_generate == "1") expected["generate_tokens"] = "64"
        }
        ($1 in expected) { count[$1]++; if ($2 != expected[$1]) mismatched++ }
        END {
            for (key in expected) if (count[key] != 1) exit 1
            exit mismatched ? 1 : 0
        }' "$census_scoreboard_inputs"; then
        printf 'the scoreboard campaign inputs state a profile, token count, sampling, priority, placement, speculation, router, I/O class, backend sampling, latency mode, broker, or image service setting other than the one every arm here runs under, or state one of them more than once: %s\n' \
            "$census_scoreboard_inputs" >&2
        exit 2
    fi
    printf '%s\t%s\n' \
        "$(sha256sum "$census_scoreboard_models" | cut -d ' ' -f 1)" \
        "$(sha256sum "$census_scoreboard_inputs" | cut -d ' ' -f 1)"
}
