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

# Two selected graphics clocks are one execution state where they lie within a
# band of each other. The appliance calibrations of 20260902T1302Z and its
# predecessor both fell from a flat 1100 MHz over the first nine slots to a
# sustained regime hovering across 775, 787, 800, 812, 825, 837, and 857 MHz,
# so an exact comparison read every collect pair of one regime as a governor
# step while the campaign held one thermal state throughout. The band is a
# relative difference over the larger of the two modes, which is symmetric in
# its arguments and keeps 1100 against 800 at 0.2727 outside a 0.06 band while
# the widest sustained pair, 762 against 787, sits at 0.0318 inside it.
#
# census_within_band A B BAND -- exits 0 where the two lie inside the band.
census_within_band() {
    awk -v first="$1" -v second="$2" -v band="$3" 'BEGIN {
        if (first + 0 <= 0 || second + 0 <= 0) exit 1
        larger = (first + 0 > second + 0) ? first + 0 : second + 0
        difference = first - second
        if (difference < 0) difference = -difference
        exit (difference / larger <= band + 0) ? 0 : 1 }'
}

# One step of the regime precondition. The campaign opens on warmup arms with
# the sampler on and reads their clock state until two consecutive arms agree
# inside the band and each holds a modal share inside [MIN_SHARE, MAX_SHARE].
# That window rather than a floor is what separates the two regimes this device
# runs in. 20260902T1417Z measures the boost regime pinning 1100 MHz at a modal
# share of 0.5518 to 0.6803 and the sustained regime hovering across seven
# values at 0.1206 to 0.1615, so a share above the ceiling reports a pinned
# clock and two boost warmups would otherwise agree at 1100 on the second arm,
# settling the precondition on the regime it exists to leave. The floor stays as
# a sanity bound under a window whose samples name no mode at all.
#
# Prints `reached MEAN` where this arm closes such a pair and `pending MODE
# SHARE` otherwise, with the unusable arm resetting the pair to `pending - -`
# rather than pairing across it: an arm whose sampler wrote no clock state, an
# arm spread thinner than the floor, and an arm pinned above the ceiling each
# report a window the precondition declines to build a regime on.
#
# census_regime_step PREVIOUS_MODE PREVIOUS_SHARE MODE SHARE BAND MIN_SHARE \
#     MAX_SHARE
census_regime_step() {
    awk -v previous_mode="$1" -v previous_share="$2" -v mode="$3" -v share="$4" \
        -v band="$5" -v min_share="$6" -v max_share="$7" 'BEGIN {
        usable = (mode != "-" && share != "-" && mode + 0 > 0 \
            && share + 0 >= min_share + 0 && share + 0 <= max_share + 0)
        if (!usable) { print "pending - -"; exit }
        settled = (previous_mode != "-" && previous_share != "-" \
            && previous_mode + 0 > 0 && previous_share + 0 >= min_share + 0 \
            && previous_share + 0 <= max_share + 0)
        if (settled) {
            larger = (mode + 0 > previous_mode + 0) ? mode + 0 : previous_mode + 0
            difference = mode - previous_mode
            if (difference < 0) difference = -difference
            if (difference / larger <= band + 0) {
                printf "reached %.1f\n", (mode + previous_mode) / 2
                exit
            }
        }
        printf "pending %s %s\n", mode, share }'
}

# The warmup arms occupy slots 0a through 0p, one letter per arm in execution
# order, so the named arms of either campaign keep the integer slots 1 through
# N that every brick, receipt, pair, and quadruple is stated in. The label
# sorts ahead of 01- in the arms directory, carries no leading dash, and
# compares as a string against a ledger's own slot column. Sixteen letters cover
# the precondition's own cap, which is set by the nine arms boost held for in
# both retained calibrations.
#
# census_warmup_slot INDEX -- 1 prints 0a
census_warmup_slot() {
    printf '0%s\n' "$(printf 'abcdefghijklmnop' | cut -c "$1")"
}

# One arm's distance from the regime the precondition recorded, signed toward
# the arm and scaled by the larger of the two so its magnitude compares against
# the same band the pair comparison uses. An unknown mode or an unreached
# regime prints the unknown value, since a distance from nothing is not zero.
#
# census_regime_delta MODE REGIME
census_regime_delta() {
    awk -v mode="$1" -v regime="$2" 'BEGIN {
        if (mode == "-" || regime == "-" || mode + 0 <= 0 || regime + 0 <= 0) {
            print "-"; exit }
        larger = (mode + 0 > regime + 0) ? mode + 0 : regime + 0
        printf "%+.4f\n", (mode - regime) / larger }'
}

# The graphics clock is a control rather than an observed regime wherever
# QWEN_CENSUS_ENGINE_CLOCK_POLICY names one. `power_dpm_force_performance_level`
# takes `high` for the highest power state, `profile_peak` for peak clocks with
# gating disabled, and `manual` for the level indices written to pp_dpm_sclk and
# pp_dpm_mclk, and the appliance default `auto` is what produced the fall the
# regime precondition was built to wait out: nine arms at 1100 MHz, then 750 to
# 857, then 658 after a CPU build.
#
# The delivered clock rather than the DPM state is what decides decode, which
# the appliance measured against both forcing levels. Under `high` and
# `profile_peak` the starred graphics step and hwmon freq1_input both read 1100
# MHz throughout and decode fell to 6.3 to 7.0 tok/s against `auto`'s 6.8 to
# 8.2, because both levels left the starred pp_dpm_mclk fabric state at 400 MHz
# where the governor selected 933 to 1067. `manual` with the highest graphics
# level selected decoded 9.58, 8.91, and 9.23 tok/s against interleaved `auto`
# arms at 8.22 and 7.94, so `manual` is the campaign policy. The fabric
# selection is written and read back rather than required: the starred
# pp_dpm_mclk level stayed at 933 MHz whether 1067 or 933 was written, and
# every arm ran there, so 933 is the floor the invariant holds the fabric to
# and the write is recorded as an observation.
#
# The functions below split the transition where its risk sits. The snapshot is
# taken and the trap armed before anything is written, each write is proven by
# reading the attribute back, and the restore runs from a signal handler, so it
# exits nothing, changes no status, and prints the level it observed rather than
# the one it asked for: a `sudo -n` timestamp that expired mid-campaign is
# exactly what `dpm_restore=` exists to make visible.
census_engine_clock_restored=0

# The highest graphics clock a DPM table lists, and the index of the level
# carrying it. Each line reads `INDEX: VALUEMhz` with a trailing ` *` on the
# selected one.
#
# census_engine_clock_highest_mhz PP_DPM_TABLE
census_engine_clock_highest_mhz() {
    awk 'match($0, /[0-9]+[Mm][Hh]z/) {
            value = substr($0, RSTART, RLENGTH) + 0
            if (value > highest) highest = value }
        END { if (highest > 0) print highest; else exit 1 }' "$1"
}

# census_engine_clock_highest_level PP_DPM_TABLE
census_engine_clock_highest_level() {
    awk 'match($0, /[0-9]+[Mm][Hh]z/) {
            value = substr($0, RSTART, RLENGTH) + 0
            index_field = $1
            sub(/:$/, "", index_field)
            if (index_field ~ /^[0-9]+$/ && value > highest) {
                highest = value; level = index_field } }
        END { if (highest > 0) print level; else exit 1 }' "$1"
}

# The megahertz one level of a DPM table carries. A level the table never lists
# is refused here rather than written to the device and read back as another.
#
# census_engine_clock_level_mhz PP_DPM_TABLE LEVEL
census_engine_clock_level_mhz() {
    awk -v want="$2" 'match($0, /[0-9]+[Mm][Hh]z/) {
            value = substr($0, RSTART, RLENGTH) + 0
            index_field = $1
            sub(/:$/, "", index_field)
            if (index_field == want) { found++; mhz = value } }
        END { if (found == 1) print mhz; else exit 1 }' "$1"
}

# The level a DPM table marks selected, as `INDEX MHZ`. Two starred lines
# describe no single selection, so the count is required to be one.
#
# census_engine_clock_selected PP_DPM_TABLE
census_engine_clock_selected() {
    awk '/\*/ && match($0, /[0-9]+[Mm][Hh]z/) {
            starred++
            value = substr($0, RSTART, RLENGTH) + 0
            index_field = $1
            sub(/:$/, "", index_field) }
        END { if (starred == 1) print index_field, value; else exit 1 }' "$1"
}

# A forced policy writes kernel attributes the serving user does not own, so
# the campaign requires a cached credential rather than prompting inside a run
# that has already begun and naming a password prompt no arm can answer.
census_engine_clock_require_sudo() {
    if ! sudo -n true 2>/dev/null; then
        printf 'a forced engine clock policy writes power_dpm_force_performance_level through sudo -n; run sudo -v and start the campaign again\n' >&2
        exit 2
    fi
}

# The state the device holds now, as `LEVEL SCLK_INDEX MCLK_INDEX`, printed so
# the caller can arm its restore trap over values it read. A snapshot taken
# under `manual` carries the two selections that level means, since restoring
# the level alone would leave the device on this campaign's own indices.
#
# census_engine_clock_snapshot DRM_DEVICE
census_engine_clock_snapshot() {
    census_clock_node=$1/power_dpm_force_performance_level
    if [ ! -r "$census_clock_node" ]; then
        printf 'the forced engine clock policy names an unreadable level attribute: %s\n' \
            "$census_clock_node" >&2
        exit 2
    fi
    census_clock_level=$(tr -d ' \t' <"$census_clock_node" | head -n 1)
    if [ -z "$census_clock_level" ]; then
        printf 'the level attribute names no current policy: %s\n' "$census_clock_node" >&2
        exit 2
    fi
    census_clock_sclk_index=$(census_engine_clock_selected "$1/pp_dpm_sclk" \
        2>/dev/null | cut -d ' ' -f 1) || census_clock_sclk_index=-
    census_clock_mclk_index=$(census_engine_clock_selected "$1/pp_dpm_mclk" \
        2>/dev/null | cut -d ' ' -f 1) || census_clock_mclk_index=-
    printf '%s %s %s\n' "$census_clock_level" "${census_clock_sclk_index:--}" \
        "${census_clock_mclk_index:--}"
}

# One privileged write and its proof. tee is the writer because the redirection
# belongs to the privileged process rather than to this shell, and its copy to
# stdout is discarded so the campaign's own lines stay the only ones a reader
# parses.
#
# census_engine_clock_write VALUE NODE
census_engine_clock_write() {
    if ! printf '%s\n' "$1" | sudo -n tee "$2" >/dev/null 2>&1; then
        printf 'writing %s to %s through sudo -n failed\n' "$1" "$2" >&2
        exit 2
    fi
}

# The level write, proven by reading the attribute back.
#
# census_engine_clock_write_level POLICY DRM_DEVICE
census_engine_clock_write_level() {
    census_clock_node=$2/power_dpm_force_performance_level
    census_engine_clock_write "$1" "$census_clock_node"
    census_clock_observed=$(tr -d ' \t' <"$census_clock_node" | head -n 1)
    if [ "$census_clock_observed" != "$1" ]; then
        printf 'the level attribute reads %s where the campaign wrote %s: %s\n' \
            "${census_clock_observed:--}" "$1" "$census_clock_node" >&2
        exit 2
    fi
}

# One DPM level selection, printed back as `INDEX MHZ` from the table's own
# starred line. REQUIRE 1 refuses a selection the device declined; REQUIRE 0
# records what it did instead, which is what the fabric table earns: the write
# is accepted and the starred level stays where the firmware put it.
#
# census_engine_clock_select LEAF DRM_DEVICE LEVEL REQUIRE
census_engine_clock_select() {
    census_clock_table=$2/$1
    census_engine_clock_write "$3" "$census_clock_table"
    # The firmware moves the starred level after the write returns: on the
    # appliance a readback in the same instant still starred the idle step
    # where one taken a second later starred the written one, so the readback
    # polls for up to ten seconds before the selection is judged.
    census_clock_attempt=0
    while :; do
        census_clock_readback=$(census_engine_clock_selected "$census_clock_table") || {
            printf '%s marks other than one selected level after the write: %s\n' \
                "$1" "$census_clock_table" >&2
            exit 2
        }
        if [ "$4" != 1 ] || [ "${census_clock_readback%% *}" = "$3" ] || \
           [ "$census_clock_attempt" -ge 100 ]; then
            break
        fi
        census_clock_attempt=$((census_clock_attempt + 1))
        sleep 0.1
    done
    if [ "$4" = 1 ] && [ "${census_clock_readback%% *}" != "$3" ]; then
        printf '%s selected level %s where the campaign wrote %s: %s\n' \
            "$1" "${census_clock_readback%% *}" "$3" "$census_clock_table" >&2
        exit 2
    fi
    printf '%s\n' "$census_clock_readback"
}

# What the device delivers under the policy just written. A policy that names a
# graphics step and leaves the device on another describes something other than
# the pinned clock the arms are about to be read against.
#
# census_engine_clock_confirm DRM_DEVICE REQUIRED_MHZ
census_engine_clock_confirm() {
    census_clock_table=$1/pp_dpm_sclk
    census_clock_selected=$(census_engine_clock_selected "$census_clock_table") || {
        printf 'pp_dpm_sclk marks other than one selected step under the forced policy: %s\n' \
            "$census_clock_table" >&2
        exit 2
    }
    if [ "${census_clock_selected#* }" != "$2" ]; then
        printf 'the forced policy selected %s MHz where the campaign requires %s MHz: %s\n' \
            "${census_clock_selected#* }" "$2" "$census_clock_table" >&2
        exit 2
    fi
}

# The restore, which runs from EXIT and from every terminating signal handler.
# It acts once, survives a failed write, and reports the level it read back. A
# snapshot taken under `manual` restores its two selections after the level, in
# that order, since the level is what makes them mean anything.
#
# census_engine_clock_restore DRM_DEVICE SNAPSHOT
census_engine_clock_restore() {
    [ "$census_engine_clock_restored" -eq 0 ] || return 0
    census_engine_clock_restored=1
    census_clock_node=$1/power_dpm_force_performance_level
    census_clock_level=${2%% *}
    census_clock_rest=${2#* }
    census_clock_sclk_index=${census_clock_rest%% *}
    census_clock_mclk_index=${census_clock_rest##* }
    printf '%s\n' "$census_clock_level" | sudo -n tee "$census_clock_node" \
        >/dev/null 2>&1 || true
    if [ "$census_clock_level" = manual ]; then
        for census_clock_pair in "pp_dpm_sclk $census_clock_sclk_index" \
            "pp_dpm_mclk $census_clock_mclk_index"; do
            census_clock_leaf=${census_clock_pair%% *}
            census_clock_index=${census_clock_pair#* }
            [ "$census_clock_index" != - ] || continue
            printf '%s\n' "$census_clock_index" \
                | sudo -n tee "$1/$census_clock_leaf" >/dev/null 2>&1 || true
        done
    fi
    census_clock_observed=$(tr -d ' \t' <"$census_clock_node" 2>/dev/null | head -n 1) || true
    if [ -z "${census_clock_observed:-}" ]; then
        printf 'dpm_restore=unreadable level=- requested=%s node=%s\n' \
            "$census_clock_level" "$census_clock_node"
        return 0
    fi
    if [ "$census_clock_observed" = "$census_clock_level" ]; then
        printf 'dpm_restore=restored level=%s requested=%s sclk_level=%s mclk_level=%s node=%s\n' \
            "$census_clock_observed" "$census_clock_level" \
            "$census_clock_sclk_index" "$census_clock_mclk_index" "$census_clock_node"
    else
        printf 'dpm_restore=mismatch level=%s requested=%s sclk_level=%s mclk_level=%s node=%s\n' \
            "$census_clock_observed" "$census_clock_level" \
            "$census_clock_sclk_index" "$census_clock_mclk_index" "$census_clock_node"
    fi
    return 0
}

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
