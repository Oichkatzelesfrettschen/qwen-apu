#!/bin/sh
set -eu

# Read one field of one row of remote/models.tsv. A checkpoint is identified
# either by its registry id or by the path it is served from, so the launch
# path resolves a row from QWEN_MODEL_PATH without the caller naming an id.

validate_cache_type() {
    case $1 in
        f32 | f16 | bf16 | q8_0 | q5_1 | q5_0 | q4_1 | q4_0 | iq4_nl)
            return 0
            ;;
        *) return 1 ;;
    esac
}

# The tier vocabulary is closed because each value carries a different claim and
# a typo would otherwise create a sixth tier that no reader handles. production
# is a serving tuple measured safe and useful; candidate leaves quality or
# performance unqualified with no device failure under its admitted tuple;
# quarantine names a device failure or the absence of any validated safe tuple;
# archive is a valid artifact displaced or too slow to serve; rejected lost
# admission on measurement without being dangerous.
validate_tier() {
    case $1 in
        production | candidate | quarantine | archive | rejected) return 0 ;;
        *) return 1 ;;
    esac
}

# The Q4_K mat-vec formulation vocabulary is closed for the same reason the tier
# vocabulary is: the key selects a compiled pipeline at load, and a value the
# build does not carry ends the load rather than falling back. `-` is the
# production module every build executes unkeyed; `production/4` names that same
# module through the multiplexer, so a variant-select build serves the control
# arm under a key rather than under an absent one.
validate_q4k_variant() {
    case $1 in
        - | production/4) return 0 ;;
        e4/2 | e4/4 | e4/8) return 0 ;;
        e4-scale/2 | e4-scale/4 | e4-scale/8) return 0 ;;
        e4-scale-licm/2 | e4-scale-licm/4 | e4-scale-licm/8) return 0 ;;
        *) return 1 ;;
    esac
}

if [ "$#" -eq 2 ] && [ "$1" = validate-q4k-variant ]; then
    validate_q4k_variant "$2"
    exit $?
fi

if [ "$#" -eq 2 ] && [ "$1" = validate-cache-type ]; then
    validate_cache_type "$2"
    exit $?
fi

if [ "$#" -eq 2 ] && [ "$1" = validate-tier ]; then
    validate_tier "$2"
    exit $?
fi

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
quarantine_registry=${QWEN_QUARANTINE_REGISTRY:-$script_directory/quarantine.tsv}

# A ledger row names its evidence by a repository-relative path, and the path
# shape is validated wherever the ledger is read because it is a property of the
# row. Whether the file it names exists is a property of the tree, and the
# appliance runs from a copy carrying remote/ and patches/ alone, so
# remote/check-ledger-evidence.sh asserts existence and
# remote/repository-quality-gates.sh runs it in a checkout that holds the
# evidence. A launch that read the tree would refuse to serve over a directory
# the sync never sent.

# The quarantine queries read a second file rather than the tier field alone,
# because a quarantine has two scopes and the model registry has one row per
# checkpoint. A scope `model` row removes a checkpoint entirely; a scope
# `profile` row removes one tuple of a checkpoint that otherwise serves. An
# optional runtime mode returns rows that apply to that path, including `any`.
if [ "$#" -ge 1 ] && [ "$#" -le 2 ]; then
    quarantine_query=$1
    quarantine_runtime_mode=${2:-}
    case $quarantine_query in
        quarantine-subjects | quarantine-profiles | quarantine-rows) ;;
        *) quarantine_query='' ;;
    esac
    if [ -n "$quarantine_query" ]; then
        case $quarantine_runtime_mode in
            '' | router-child | standalone) ;;
            *)
                printf 'quarantine runtime mode must be router-child or standalone: %s\n' \
                    "$quarantine_runtime_mode" >&2
                exit 2
                ;;
        esac
        if [ ! -r "$quarantine_registry" ]; then
            printf 'quarantine registry is unreadable: %s\n' \
                "$quarantine_registry" >&2
            exit 1
        fi
        awk -F'\t' -v mode="$quarantine_runtime_mode" \
            -v query="$quarantine_query" '
            function validate_quarantine_row(row_number, field_index) {
                row_invalid = 0
                if (NF != 14) {
                    printf "quarantine row %d holds %d fields, expected 14\n", \
                        row_number, NF > "/dev/stderr"
                    invalid = 1
                    return 1
                }
                if ($1 == "" || $3 == "") {
                    printf "quarantine row %d requires non-empty id and subject\n", \
                        row_number > "/dev/stderr"
                    invalid = row_invalid = 1
                }
                if ($2 != "model" && $2 != "profile") {
                    printf "quarantine row %d carries invalid scope %s\n", \
                        row_number, $2 > "/dev/stderr"
                    invalid = row_invalid = 1
                }
                if ($14 != "any" && $14 != "router-child" &&
                    $14 != "standalone") {
                    printf "quarantine row %d carries invalid runtime mode %s\n", \
                        row_number, $14 > "/dev/stderr"
                    invalid = row_invalid = 1
                }
                if ($2 == "model") {
                    for (field_index = 5; field_index <= 10; field_index++) {
                        if ($field_index != "-") {
                            printf "model quarantine row %d carries tuple field %d: %s\n", \
                                row_number, field_index, $field_index > "/dev/stderr"
                            invalid = row_invalid = 1
                        }
                    }
                }
                if ($2 == "profile") {
                    if ($5 !~ /^[1-9][0-9]*$/ ||
                        $6 !~ /^[1-9][0-9]*$/ ||
                        $7 !~ /^[1-9][0-9]*$/) {
                        printf "profile quarantine row %d carries invalid depth or geometry\n", \
                            row_number > "/dev/stderr"
                        invalid = row_invalid = 1
                    } else if ($7 + 0 > $6 + 0) {
                        printf "profile quarantine row %d carries ubatch above batch\n", \
                            row_number > "/dev/stderr"
                        invalid = row_invalid = 1
                    }
                    if ($8 !~ /^(f32|f16|bf16|q8_0|q5_1|q5_0|q4_1|q4_0|iq4_nl)$/ ||
                        $9 !~ /^(f32|f16|bf16|q8_0|q5_1|q5_0|q4_1|q4_0|iq4_nl)$/) {
                        printf "profile quarantine row %d carries invalid cache type\n", \
                            row_number > "/dev/stderr"
                        invalid = row_invalid = 1
                    }
                    if ($10 !~ /^(on|off|auto)$/) {
                        printf "profile quarantine row %d carries invalid flash attention\n", \
                            row_number > "/dev/stderr"
                        invalid = row_invalid = 1
                    }
                }
                return row_invalid
            }
            $0 ~ /^#/ || $0 ~ /^[[:space:]]*$/ { next }
            { row_invalid = validate_quarantine_row(NR) }
            row_invalid { next }
            mode != "" && $14 != "any" && $14 != mode { next }
            query == "quarantine-subjects" && $2 == "model" {
                query_rows[++query_row_count] = $3
                next
            }
            query == "quarantine-profiles" && $2 == "profile" {
                query_rows[++query_row_count] = sprintf("%s\t%s\t%s\t%s\t%s\t%s\t%s", \
                    $3, $5, $6, $7, $8, $9, $10)
                next
            }
            query == "quarantine-rows" { query_rows[++query_row_count] = $0 }
            END {
                if (invalid) { exit 1 }
                for (query_row_index = 1;
                     query_row_index <= query_row_count;
                     query_row_index++) {
                    print query_rows[query_row_index]
                }
            }
        ' "$quarantine_registry"
        exit 0
    fi
fi

emit_servable_rows() {
    servable_output_field=$1
    servable_registry=${QWEN_MODEL_REGISTRY:-$script_directory/models.tsv}
    if [ ! -r "$servable_registry" ]; then
        printf 'model registry is unreadable: %s\n' "$servable_registry" >&2
        return 1
    fi
    if [ ! -r "$quarantine_registry" ]; then
        printf 'quarantine registry is unreadable: %s\n' \
            "$quarantine_registry" >&2
        return 1
    fi
    # Read the quarantine authority first, then admit only registry rows whose
    # router-child tuple survives both exclusion scopes. The field selector is
    # fixed by the caller; it is not user-provided AWK source.
    awk -F'\t' -v output_field="$servable_output_field" '
        function validate_quarantine_row(row_number, field_index) {
            row_invalid = 0
            if (NF != 14) {
                printf "quarantine row %d holds %d fields, expected 14\n", \
                    row_number, NF > "/dev/stderr"
                invalid = 1
                return 1
            }
            if ($1 == "" || $3 == "") {
                printf "quarantine row %d requires non-empty id and subject\n", \
                    row_number > "/dev/stderr"
                invalid = row_invalid = 1
            }
            if ($2 != "model" && $2 != "profile") {
                printf "quarantine row %d carries invalid scope %s\n", \
                    row_number, $2 > "/dev/stderr"
                invalid = row_invalid = 1
            }
            if ($14 != "any" && $14 != "router-child" &&
                $14 != "standalone") {
                printf "quarantine row %d carries invalid runtime mode %s\n", \
                    row_number, $14 > "/dev/stderr"
                invalid = row_invalid = 1
            }
            if ($2 == "model") {
                for (field_index = 5; field_index <= 10; field_index++) {
                    if ($field_index != "-") {
                        printf "model quarantine row %d carries tuple field %d: %s\n", \
                            row_number, field_index, $field_index > "/dev/stderr"
                        invalid = row_invalid = 1
                    }
                }
            }
            if ($2 == "profile") {
                if ($5 !~ /^[1-9][0-9]*$/ ||
                    $6 !~ /^[1-9][0-9]*$/ ||
                    $7 !~ /^[1-9][0-9]*$/) {
                    printf "profile quarantine row %d carries invalid depth or geometry\n", \
                        row_number > "/dev/stderr"
                    invalid = row_invalid = 1
                } else if ($7 + 0 > $6 + 0) {
                    printf "profile quarantine row %d carries ubatch above batch\n", \
                        row_number > "/dev/stderr"
                    invalid = row_invalid = 1
                }
                if ($8 !~ /^(f32|f16|bf16|q8_0|q5_1|q5_0|q4_1|q4_0|iq4_nl)$/ ||
                    $9 !~ /^(f32|f16|bf16|q8_0|q5_1|q5_0|q4_1|q4_0|iq4_nl)$/) {
                    printf "profile quarantine row %d carries invalid cache type\n", \
                        row_number > "/dev/stderr"
                    invalid = row_invalid = 1
                }
                if ($10 !~ /^(on|off|auto)$/) {
                    printf "profile quarantine row %d carries invalid flash attention\n", \
                        row_number > "/dev/stderr"
                    invalid = row_invalid = 1
                }
            }
            return row_invalid
        }
        FILENAME == ARGV[1] {
            if ($0 ~ /^#/ || $0 ~ /^[[:space:]]*$/) { next }
            row_invalid = validate_quarantine_row(FNR)
            if (row_invalid) { next }
            if ($14 == "standalone") { next }
            if ($2 == "model") {
                quarantined_models[$3] = 1
            } else if ($2 == "profile") {
                profile_key = $3 SUBSEP $5 SUBSEP $6 SUBSEP $7 SUBSEP \
                    $8 SUBSEP $9 SUBSEP $10
                quarantined_profiles[profile_key] = 1
            }
            next
        }
        $0 ~ /^#/ || $0 ~ /^[[:space:]]*$/ { next }
        invalid { next }
        NF != 23 {
            printf "model row %d holds %d fields, expected 23\n", FNR, NF \
                > "/dev/stderr"
            invalid = 1
            next
        }
        # The Q4_K formulation vocabulary is closed, so a typo names a pipeline
        # the variant-select build refuses at load rather than a row that serves
        # the production module. The whole registry is validated before any row
        # is emitted, the discipline every closed field here takes.
        $23 !~ /^(-|production\/4|e4\/[248]|e4-scale\/[248]|e4-scale-licm\/[248])$/ {
            printf "model row %d carries invalid q4k_variant: %s\n", FNR, $23 \
                > "/dev/stderr"
            invalid = 1
            next
        }
        $16 == "production" || $16 == "candidate" {
            profile_key = $1 SUBSEP $5 SUBSEP $17 SUBSEP $18 SUBSEP \
                $8 SUBSEP $9 SUBSEP $10
            if (!quarantined_models[$1] && !quarantined_profiles[profile_key]) {
                print $output_field
            }
        }
        END { exit invalid ? 1 : 0 }
    ' "$quarantine_registry" "$servable_registry"
}

# The rows the router can load on demand. Router mode serves any of them behind
# one listener, so a caller sizing the machine reads this list rather than the
# one checkpoint it happened to name.
if [ "$#" -eq 1 ] && [ "$1" = servable-files ]; then
    emit_servable_rows 3
    exit 0
fi

# The ids of those same rows. The router routes on an id and answers 400 for one
# it does not hold, so a caller grading every served checkpoint enumerates ids
# here rather than reading the live endpoint, which would also list a
# quarantined row exposed by QWEN_ROUTER_INCLUDE_QUARANTINE.
if [ "$#" -eq 1 ] && [ "$1" = servable-ids ]; then
    emit_servable_rows 1
    exit 0
fi

# The tuple ledger carries every measured (context, batch, ubatch, cache,
# Flash Attention) arm rather than the single validated_filled_depth field
# models.tsv holds per row, because the served checkpoint fills and decodes
# 16384 tokens at batch 128 and wedges the ring at the harness-default 2048,
# and one scalar per model cannot carry both arms. Both subcommands validate
# the whole ledger before reading it, the same discipline emit_servable_rows
# applies to the quarantine authority, because a caller reading one row must
# not trust a ledger a sibling row has made unsafe to read.
validate_tuple_ledger() {
    tuple_ledger_registry=${QWEN_VALIDATED_TUPLES:-$script_directory/validated-tuples.tsv}
    tuple_model_registry=${QWEN_MODEL_REGISTRY:-$script_directory/models.tsv}
    if [ ! -r "$tuple_ledger_registry" ]; then
        printf 'validated tuple ledger is unreadable: %s\n' \
            "$tuple_ledger_registry" >&2
        return 1
    fi
    if [ ! -r "$tuple_model_registry" ]; then
        printf 'model registry is unreadable: %s\n' "$tuple_model_registry" >&2
        return 1
    fi
    tuple_ledger_rows=$(awk -F'\t' '
        FILENAME == ARGV[1] {
            if ($0 ~ /^#/ || $0 ~ /^[[:space:]]*$/) { next }
            if (NF >= 1) { known_model_ids[$1] = 1 }
            next
        }
        $0 ~ /^#/ || $0 ~ /^[[:space:]]*$/ { next }
        {
            rows++
            if (NF != 21) {
                printf "tuple row %d holds %d fields, expected 21\n", FNR, NF \
                    > "/dev/stderr"
                bad++
                next
            }
            if ($1 == "") {
                printf "tuple row %d carries an empty tuple_id\n", FNR \
                    > "/dev/stderr"
                bad++
                next
            }
            if ($1 in known_model_ids) {
                printf "%s: pair_id collides with model registry id\n", $1 \
                    > "/dev/stderr"
                bad++
            }
            if (seen_id[$1]++) {
                printf "duplicate tuple_id %s at row %d\n", $1, FNR \
                    > "/dev/stderr"
                bad++
            }
            if (!($2 in known_model_ids)) {
                printf "%s: model_id %s is absent from the model registry\n", \
                    $1, $2 > "/dev/stderr"
                bad++
            }
            if ($3 != "standalone" && $3 != "router-child") {
                printf "%s: runtime_mode %s is not standalone or router-child\n", \
                    $1, $3 > "/dev/stderr"
                bad++
            }
            split("context batch ubatch", geometry_names, " ")
            for (i = 4; i <= 6; i++) {
                if ($i !~ /^[1-9][0-9]*$/) {
                    printf "%s: %s is not a canonical positive integer: %s\n", \
                        $1, geometry_names[i - 3], $i > "/dev/stderr"
                    bad++
                }
            }
            if ($5 ~ /^[1-9][0-9]*$/ && $6 ~ /^[1-9][0-9]*$/ &&
                $6 + 0 > $5 + 0) {
                printf "%s: ubatch %s exceeds batch %s\n", $1, $6, $5 \
                    > "/dev/stderr"
                bad++
            }
            if ($7 !~ /^(f32|f16|bf16|q8_0|q5_1|q5_0|q4_1|q4_0|iq4_nl)$/) {
                printf "%s: cache_k %s is outside the runtime vocabulary\n", \
                    $1, $7 > "/dev/stderr"
                bad++
            }
            if ($8 !~ /^(f32|f16|bf16|q8_0|q5_1|q5_0|q4_1|q4_0|iq4_nl)$/) {
                printf "%s: cache_v %s is outside the runtime vocabulary\n", \
                    $1, $8 > "/dev/stderr"
                bad++
            }
            if ($9 != "on" && $9 != "off" && $9 != "auto") {
                printf "%s: flash_attention %s is not on, off, or auto\n", \
                    $1, $9 > "/dev/stderr"
                bad++
            }
            if ($10 !~ /^[1-9][0-9]*$/) {
                printf "%s: threads %s is not a canonical positive integer\n", \
                    $1, $10 > "/dev/stderr"
                bad++
            }
            if ($11 !~ /^[1-9][0-9]*$/) {
                printf "%s: parallel %s is not a canonical positive integer\n", \
                    $1, $11 > "/dev/stderr"
                bad++
            }
            if ($12 != "none" && $12 != "loaded") {
                printf "%s: projector_state %s is not none or loaded\n", \
                    $1, $12 > "/dev/stderr"
                bad++
            }
            if ($13 != "vulkan" && $13 != "cpu" && $13 != "hip") {
                printf "%s: backend %s is not vulkan, cpu, or hip\n", \
                    $1, $13 > "/dev/stderr"
                bad++
            }
            if ($14 != "validated" && $14 != "failed" && $14 != "unverified") {
                printf "%s: status %s is not validated, failed, or unverified\n", \
                    $1, $14 > "/dev/stderr"
                bad++
            }
            if ($14 == "validated") {
                if ($15 == "-") {
                    printf "%s: validated status carries no evidence path\n", \
                        $1 > "/dev/stderr"
                    bad++
                }
            }
            if ($21 != "-" && $21 !~ /^[0-9]{4}-[0-9]{2}-[0-9]{2}$/) {
                printf "%s: measured_at %s is not an ISO date or -\n", \
                    $1, $21 > "/dev/stderr"
                bad++
            }
            print $0
        }
        END {
            if (!rows) { print "tuple ledger holds no rows" > "/dev/stderr"; bad++ }
            exit bad ? 1 : 0
        }
    ' "$tuple_model_registry" "$tuple_ledger_registry") || return 1

    # Ledger text never becomes shell source. Validate each retained evidence
    # path as one shell word after AWK has established the 21-field row shape,
    # then test the quoted path with the shell's pathname primitive. The shell
    # pathname test keeps quotes, semicolons, and command substitutions in a
    # ledger outside executable input.
    tuple_tab=$(printf '\t')
    tuple_evidence_failures=0
    while IFS="$tuple_tab" read -r tuple_id _model_id _runtime_mode \
        _context _batch _ubatch _cache_k _cache_v _flash_attention \
        _threads _parallel _projector_state _backend tuple_status \
        tuple_evidence _llama_commit _runner_sha256 _kernel _mesa _amdgpu \
        _measured_at; do
        [ "$tuple_status" = validated ] || continue
        case $tuple_evidence in
            '' | - | .. | /* | ../* | */../* | */..)
                printf '%s: validation evidence is not a repository-relative path: %s\n' \
                    "$tuple_id" "$tuple_evidence" >&2
                tuple_evidence_failures=$((tuple_evidence_failures + 1))
                continue
                ;;
        esac
    done <<EOF
$tuple_ledger_rows
EOF
    [ "$tuple_evidence_failures" -eq 0 ] || return 1
    printf '%s\n' "$tuple_ledger_rows"
}

# All validated and failed arms measured for one model, in ledger order. A
# caller choosing a serving geometry reads every row rather than the single
# field models.tsv carries, because two geometries at the same depth can
# disagree.
if [ "$#" -eq 2 ] && [ "$1" = tuples ]; then
    tuples_model_id=$2
    validated_tuples_rows=$(validate_tuple_ledger) || exit 1
    printf '%s\n' "$validated_tuples_rows" | awk -F'\t' -v model_id="$tuples_model_id" \
        '$2 == model_id { print; matched = 1 } END { exit matched ? 0 : 1 }'
    exit $?
fi

# One tuple row by its id, either the whole row as key=value lines or a single
# named field, the same interface the id and path selectors give the model
# registry.
if [ "$#" -eq 2 ] && [ "$1" = tuple ]; then
    tuple_selector=$2
    validated_tuples_rows=$(validate_tuple_ledger) || exit 1
    printf '%s\n' "$validated_tuples_rows" | awk -F'\t' -v selector="$tuple_selector" '
        $1 == selector {
            split("tuple_id model_id runtime_mode context batch ubatch cache_k " \
                  "cache_v flash_attention threads parallel projector_state " \
                  "backend status evidence llama_commit runner_sha256 kernel " \
                  "mesa amdgpu measured_at", names, " ")
            for (i = 1; i <= 21; i++) { printf "%s=%s\n", names[i], $i }
            matched = 1
            next
        }
        END { exit matched ? 0 : 3 }
    '
    exit $?
fi

if [ "$#" -eq 3 ] && [ "$1" = tuple ]; then
    tuple_selector=$2
    tuple_field=$3
    validated_tuples_rows=$(validate_tuple_ledger) || exit 1
    printf '%s\n' "$validated_tuples_rows" | awk -F'\t' \
        -v selector="$tuple_selector" -v field="$tuple_field" '
        $1 == selector {
            split("tuple_id model_id runtime_mode context batch ubatch cache_k " \
                  "cache_v flash_attention threads parallel projector_state " \
                  "backend status evidence llama_commit runner_sha256 kernel " \
                  "mesa amdgpu measured_at", names, " ")
            for (i = 1; i <= 21; i++) {
                if (names[i] == field) { printf "%s\n", $i; found = 1 }
            }
            matched = 1
            next
        }
        END { exit matched && found ? 0 : 3 }
    '
    exit $?
fi

# The draft pairings that put a small model in front of a larger target.
# models.tsv carries one row per checkpoint and cannot state that two of them
# run inside one server, so remote/draft-pairs.tsv carries the pairing and this
# reader validates the whole ledger before answering any query, the discipline
# validate_tuple_ledger already applies to the tuple ledger: a caller reading
# one pairing must not trust a ledger a sibling row has made unsafe to read.
validate_draft_pair_ledger() {
    draft_pair_registry=${QWEN_DRAFT_PAIRS:-$script_directory/draft-pairs.tsv}
    draft_pair_model_registry=${QWEN_MODEL_REGISTRY:-$script_directory/models.tsv}
    if [ ! -r "$draft_pair_registry" ]; then
        printf 'draft pair ledger is unreadable: %s\n' \
            "$draft_pair_registry" >&2
        return 1
    fi
    if [ ! -r "$draft_pair_model_registry" ]; then
        printf 'model registry is unreadable: %s\n' \
            "$draft_pair_model_registry" >&2
        return 1
    fi
    # The quarantine authority answers through this script's own query, so a
    # malformed or unreadable registry stops the pairing read the way it stops
    # preset generation rather than admitting a pairing over an unread file.
    # The query names no runtime mode, so it returns every model-scope subject
    # of both scopes: a pairing serves through the router and is measured
    # standalone, and one ledger answering both paths retires a checkpoint
    # excluded on either.
    draft_pair_quarantine_subjects=$("$script_directory/model-registry.sh" \
        quarantine-subjects) || return 1
    draft_pair_rows=$(printf '%s\n' "$draft_pair_quarantine_subjects" |
        awk -F'\t' '
        FILENAME == "-" {
            if ($0 == "") next
            quarantined_models[$1] = 1
            next
        }
        FILENAME == ARGV[2] {
            if ($0 ~ /^#/ || $0 ~ /^[[:space:]]*$/) { next }
            if (NF >= 5) {
                known_model_ids[$1] = 1
                model_context_default[$1] = $5
            }
            next
        }
        $0 ~ /^#/ || $0 ~ /^[[:space:]]*$/ { next }
        {
            if (NF != 12) {
                printf "draft pair row %d holds %d fields, expected 12\n", \
                    FNR, NF > "/dev/stderr"
                bad++
                next
            }
            if ($1 == "") {
                printf "draft pair row %d carries an empty pair_id\n", FNR \
                    > "/dev/stderr"
                bad++
                next
            }
            if (seen_id[$1]++) {
                printf "duplicate pair_id %s at row %d\n", $1, FNR \
                    > "/dev/stderr"
                bad++
            }
            if (!($2 in known_model_ids)) {
                printf "%s: target_model_id %s is absent from the model registry\n", \
                    $1, $2 > "/dev/stderr"
                bad++
            }
            if (!($3 in known_model_ids)) {
                printf "%s: draft_model_id %s is absent from the model registry\n", \
                    $1, $3 > "/dev/stderr"
                bad++
            }
            # A checkpoint drafting itself loads one artifact twice for a draft
            # that agrees with the target by construction, which spends the
            # device on a copy rather than on a cheaper proposer.
            if ($2 == $3) {
                printf "%s: target and draft name the same checkpoint %s\n", \
                    $1, $2 > "/dev/stderr"
                bad++
            }
            if (quarantined_models[$2]) {
                printf "%s: target %s is excluded by model quarantine\n", \
                    $1, $2 > "/dev/stderr"
                bad++
            }
            if (quarantined_models[$3]) {
                printf "%s: draft %s is excluded by model quarantine\n", \
                    $1, $3 > "/dev/stderr"
                bad++
            }
            if ($4 != "production" && $4 != "candidate" &&
                $4 != "quarantine" && $4 != "archive" && $4 != "rejected") {
                printf "%s: tier %s is outside the vocabulary\n", $1, $4 \
                    > "/dev/stderr"
                bad++
            }
            if ($5 !~ /^[1-9][0-9]*$/) {
                printf "%s: spec_draft_n_max %s is not a canonical positive integer\n", \
                    $1, $5 > "/dev/stderr"
                bad++
            } else if ($5 + 0 > 16) {
                # A draft of N makes the target emit N+1 output positions in one
                # pass and common_speculative_get_output_limits clamps that count
                # to the batch size, so sixteen keeps the product inside the
                # 128-token batch qwen-capacity-policy.sh launches with.
                printf "%s: spec_draft_n_max %s exceeds the operational maximum of 16\n", \
                    $1, $5 > "/dev/stderr"
                bad++
            }
            # p_min gates drafting rather than acceptance, and common/arg.cpp
            # reads it with std::stof, so the ledger spells one decimal fraction
            # inside the closed unit interval.
            if ($6 !~ /^(0|1)(\.[0-9]+)?$/ || $6 + 0 > 1) {
                printf "%s: spec_draft_p_min %s is not a decimal fraction in [0,1]\n", \
                    $1, $6 > "/dev/stderr"
                bad++
            }
            # The draft context is derived rather than set: common/speculative.cpp
            # assigns cparams.n_ctx = llama_n_ctx(ctx_tgt) before the draft model
            # loads, so the column states the target row own admitted depth and a
            # different number would describe an allocation no launch makes.
            if ($7 !~ /^(0|1)(\.[0-9]+)?$/ || $7 + 0 > 1) {
                printf "%s: acceptance_floor %s is not a decimal fraction in [0,1]\n", \
                    $1, $7 > "/dev/stderr"
                bad++
            }
            if ($8 !~ /^[1-9][0-9]*$/) {
                printf "%s: draft_context %s is not a canonical positive integer\n", \
                    $1, $8 > "/dev/stderr"
                bad++
            } else if (($2 in model_context_default) &&
                $8 != model_context_default[$2]) {
                printf "%s: draft_context %s differs from target context_default %s\n", \
                    $1, $8, model_context_default[$2] > "/dev/stderr"
                bad++
            }
            if ($9 !~ /^(f32|f16|bf16|q8_0|q5_1|q5_0|q4_1|q4_0|iq4_nl)$/) {
                printf "%s: draft_cache_type_k %s is outside the runtime vocabulary\n", \
                    $1, $9 > "/dev/stderr"
                bad++
            }
            if ($10 !~ /^(f32|f16|bf16|q8_0|q5_1|q5_0|q4_1|q4_0|iq4_nl)$/) {
                printf "%s: draft_cache_type_v %s is outside the runtime vocabulary\n", \
                    $1, $10 > "/dev/stderr"
                bad++
            }
            if ($11 == "") {
                printf "%s: validated_evidence is empty; write - for an unmeasured pairing\n", \
                    $1 > "/dev/stderr"
                bad++
            } else if ($4 == "production" && $11 == "-") {
                printf "%s: production pairing requires retained validated_evidence\n", \
                    $1 > "/dev/stderr"
                bad++
            }
            # The note is the display name build-router-presets.sh writes into
            # LLAMA_ARG_ALIAS beside the pair_id, and common/arg.cpp splits that
            # value on commas into a set of routing names, so a comma here
            # silently becomes a third alias.
            if ($12 == "" || $12 ~ /,/ || $12 ~ /^[[:space:]]/ ||
                $12 ~ /[[:space:]]$/) {
                printf "%s: notes is the alias display name and holds no comma or edge whitespace: %s\n", \
                    $1, $12 > "/dev/stderr"
                bad++
            }
            print $0
        }
        END { exit bad ? 1 : 0 }
    ' - "$draft_pair_model_registry" "$draft_pair_registry") || return 1

    # Ledger text never becomes shell source. AWK has established the 12-field
    # row shape, so each retained evidence path is read as one shell word and
    # tested with the shell pathname primitive, which keeps quotes, semicolons,
    # and command substitutions outside executable input.
    draft_pair_tab=$(printf '\t')
    draft_pair_evidence_failures=0
    while IFS="$draft_pair_tab" read -r draft_pair_id _target_model_id \
        _draft_model_id _pair_tier _spec_draft_n_max _spec_draft_p_min \
        _acceptance_floor _draft_context _draft_cache_type_k _draft_cache_type_v \
        draft_pair_evidence _notes; do
        # A ledger admitting no pairing is a valid state, so the empty line the
        # here-document carries for it reaches this loop and is skipped.
        [ -n "$draft_pair_id" ] || continue
        [ "$draft_pair_evidence" = - ] && continue
        case $draft_pair_evidence in
            '' | .. | /* | ../* | */../* | */..)
                printf '%s: validated evidence is not a repository-relative path: %s\n' \
                    "$draft_pair_id" "$draft_pair_evidence" >&2
                draft_pair_evidence_failures=$((draft_pair_evidence_failures + 1))
                continue
                ;;
        esac
    done <<EOF
$draft_pair_rows
EOF
    [ "$draft_pair_evidence_failures" -eq 0 ] || return 1
    printf '%s\n' "$draft_pair_rows"
}

# Every pairing in ledger order. build-router-presets.sh reads this list to
# decide which sections to emit and qwen-capacity-policy.sh reads it again at
# launch, so a preset persisting across a ledger edit is rejoined to the rows
# the launch itself validated.
if [ "$#" -eq 1 ] && [ "$1" = draft-pairs ]; then
    validate_draft_pair_ledger || exit 1
    exit 0
fi

# One pairing by its id, either the whole row as key=value lines or a single
# named field, the interface the model and tuple selectors already give.
if [ "$#" -eq 2 ] && [ "$1" = draft-pair ]; then
    draft_pair_selector=$2
    draft_pair_ledger_rows=$(validate_draft_pair_ledger) || exit 1
    printf '%s\n' "$draft_pair_ledger_rows" | awk -F'\t' \
        -v selector="$draft_pair_selector" '
        $1 == selector {
            split("pair_id target_model_id draft_model_id tier " \
                  "spec_draft_n_max spec_draft_p_min acceptance_floor " \
                  "draft_context draft_cache_type_k draft_cache_type_v validated_evidence " \
                  "notes", names, " ")
            for (i = 1; i <= 12; i++) { printf "%s=%s\n", names[i], $i }
            matched = 1
            next
        }
        END { exit matched ? 0 : 3 }
    '
    exit $?
fi

if [ "$#" -eq 3 ] && [ "$1" = draft-pair ]; then
    draft_pair_selector=$2
    draft_pair_field=$3
    draft_pair_ledger_rows=$(validate_draft_pair_ledger) || exit 1
    printf '%s\n' "$draft_pair_ledger_rows" | awk -F'\t' \
        -v selector="$draft_pair_selector" -v field="$draft_pair_field" '
        $1 == selector {
            split("pair_id target_model_id draft_model_id tier " \
                  "spec_draft_n_max spec_draft_p_min acceptance_floor " \
                  "draft_context draft_cache_type_k draft_cache_type_v validated_evidence " \
                  "notes", names, " ")
            for (i = 1; i <= 12; i++) {
                if (names[i] == field) { printf "%s\n", $i; found = 1 }
            }
            matched = 1
            next
        }
        END { exit matched && found ? 0 : 3 }
    '
    exit $?
fi

# The context checkpoint count is per registry row, because the classes
# disagree on first-turn token fidelity under checkpointing (the 0.8B differs
# at zero-based index 25, the 2B and 4B do not), so remote/ctx-checkpoints.tsv
# carries one count per model_id and this reader validates the whole ledger
# before answering any query, the discipline the tuple and draft-pair ledgers
# already take. A model_id outside the ledger serves at 0.
validate_ctx_checkpoint_ledger() {
    ctx_checkpoint_ledger=${QWEN_CTX_CHECKPOINT_LEDGER:-$script_directory/ctx-checkpoints.tsv}
    ctx_checkpoint_model_registry=${QWEN_MODEL_REGISTRY:-$script_directory/models.tsv}
    if [ ! -r "$ctx_checkpoint_ledger" ]; then
        printf 'context checkpoint ledger is unreadable: %s\n' \
            "$ctx_checkpoint_ledger" >&2
        return 1
    fi
    if [ ! -r "$ctx_checkpoint_model_registry" ]; then
        printf 'model registry is unreadable: %s\n' \
            "$ctx_checkpoint_model_registry" >&2
        return 1
    fi
    ctx_checkpoint_rows=$(awk -F'\t' '
        FILENAME == ARGV[1] {
            if ($0 ~ /^#/ || $0 ~ /^[[:space:]]*$/) { next }
            if (NF >= 1) { known_model_ids[$1] = 1 }
            next
        }
        $0 ~ /^#/ || $0 ~ /^[[:space:]]*$/ { next }
        {
            if (NF != 3) {
                printf "context checkpoint row %d holds %d fields, expected 3\n", \
                    FNR, NF > "/dev/stderr"
                bad++
                next
            }
            if ($1 == "") {
                printf "context checkpoint row %d carries an empty model_id\n", \
                    FNR > "/dev/stderr"
                bad++
            }
            if (seen_id[$1]++) {
                printf "duplicate model_id %s at context checkpoint row %d\n", \
                    $1, FNR > "/dev/stderr"
                bad++
            }
            if (!($1 in known_model_ids)) {
                printf "%s: model_id is absent from the model registry\n", \
                    $1 > "/dev/stderr"
                bad++
            }
            # common/arg.cpp reads --ctx-checkpoints as an int and the policy
            # builds exact string tuple keys, so the count is one canonical
            # non-negative decimal integer without leading zeroes.
            if ($2 !~ /^(0|[1-9][0-9]*)$/) {
                printf "%s: ctx_checkpoints %s is not a canonical non-negative integer\n", \
                    $1, $2 > "/dev/stderr"
                bad++
            }
            if ($3 == "") {
                printf "%s: evidence is empty; write - for an unmeasured zero\n", \
                    $1 > "/dev/stderr"
                bad++
            } else if ($3 == "-" && $2 != "0") {
                printf "%s: a count above 0 requires retained evidence\n", \
                    $1 > "/dev/stderr"
                bad++
            }
            print $0
        }
        END { exit bad ? 1 : 0 }
    ' "$ctx_checkpoint_model_registry" "$ctx_checkpoint_ledger") || return 1

    # AWK has established the three-field shape, so each evidence path is read
    # as one shell word and tested with the pathname primitive, which keeps
    # ledger text outside executable input.
    ctx_checkpoint_tab=$(printf '\t')
    ctx_checkpoint_evidence_failures=0
    while IFS="$ctx_checkpoint_tab" read -r ctx_checkpoint_model_id \
        _ctx_checkpoint_count ctx_checkpoint_evidence; do
        [ -n "$ctx_checkpoint_model_id" ] || continue
        [ "$ctx_checkpoint_evidence" = - ] && continue
        case $ctx_checkpoint_evidence in
            '' | .. | /* | ../* | */../* | */..)
                printf '%s: evidence is not a repository-relative path: %s\n' \
                    "$ctx_checkpoint_model_id" "$ctx_checkpoint_evidence" >&2
                ctx_checkpoint_evidence_failures=$((ctx_checkpoint_evidence_failures + 1))
                continue
                ;;
        esac
    done <<EOF
$ctx_checkpoint_rows
EOF
    [ "$ctx_checkpoint_evidence_failures" -eq 0 ] || return 1
    printf '%s\n' "$ctx_checkpoint_rows"
}

# Every ledger row in order, validated whole. build-router-presets.sh and
# build-web-presets.sh read it before emitting a section, and
# qwen-capacity-policy.sh reads it again at launch to rejoin a persisted preset
# to the counts this launch validated.
if [ "$#" -eq 1 ] && [ "$1" = ctx-checkpoints ]; then
    validate_ctx_checkpoint_ledger || exit 1
    exit 0
fi

# One model's count after validating the whole ledger; a model outside the
# ledger answers 0, the process-wide fallback.
if [ "$#" -eq 2 ] && [ "$1" = ctx-checkpoint ]; then
    ctx_checkpoint_selector=$2
    ctx_checkpoint_ledger_rows=$(validate_ctx_checkpoint_ledger) || exit 1
    printf '%s\n' "$ctx_checkpoint_ledger_rows" | awk -F'\t' \
        -v selector="$ctx_checkpoint_selector" '
        $1 == selector { count = $2; matched = 1 }
        END { print matched ? count : 0 }
    '
    exit 0
fi

if [ "$#" -ne 2 ] && [ "$#" -ne 3 ]; then
    printf 'usage: %s id|path SELECTOR [FIELD]\n' "$0" >&2
    printf '       %s validate-cache-type TYPE\n' "$0" >&2
    printf '       %s validate-q4k-variant KEY\n' "$0" >&2
    printf '       %s validate-tier TIER\n' "$0" >&2
    printf '       %s quarantine-subjects|quarantine-profiles|quarantine-rows [RUNTIME_MODE]\n' "$0" >&2
    printf '       %s servable-files | servable-ids\n' "$0" >&2
    printf '       %s tuples MODEL_ID\n' "$0" >&2
    printf '       %s tuple TUPLE_ID [FIELD]\n' "$0" >&2
    printf '       %s draft-pairs\n' "$0" >&2
    printf '       %s draft-pair PAIR_ID [FIELD]\n' "$0" >&2
    printf '       %s ctx-checkpoints\n' "$0" >&2
    printf '       %s ctx-checkpoint MODEL_ID\n' "$0" >&2
    printf 'fields: id role model_file fetch_script context_default context_ceiling\n' >&2
    printf '        context_target cache_type_k cache_type_v flash_attention\n' >&2
    printf '        projector projector_fetch_script decode_tok_s prefill_tok_s\n' >&2
    printf '        quality tier batch\n' >&2
    printf '        ubatch validated_filled_depth validation_evidence\n' >&2
    printf '        raw_tool_selection guarded_tool_execution q4k_variant\n' >&2
    printf 'omit FIELD to print the whole row as key=value lines\n' >&2
    exit 2
fi

selector_kind=$1
selector=$2
field=${3:-}
registry=${QWEN_MODEL_REGISTRY:-$script_directory/models.tsv}

case $selector_kind in
    id | path) ;;
    *)
        printf 'selector kind must be id, path, validate-cache-type, validate-q4k-variant, validate-tier, or a quarantine query: %s\n' \
            "$selector_kind" >&2
        exit 2
        ;;
esac

if [ ! -r "$registry" ]; then
    printf 'model registry is unreadable: %s\n' "$registry" >&2
    exit 1
fi

awk -F'\t' -v kind="$selector_kind" -v selector="$selector" -v field="$field" '
    /^#/ { next }
    NF < 23 { next }
    {
        matched = 0
        if (kind == "id" && $1 == selector) {
            matched = 1
        }
        # A path matches when it ends in the registry file suffix, so the row
        # holds a repository-relative name and the caller holds an absolute one.
        if (kind == "path" && length($3) <= length(selector) &&
            substr(selector, length(selector) - length($3) + 1) == $3) {
            matched = 1
        }
        if (!matched) { next }
        matched_any = 1
        split("id role model_file fetch_script context_default context_ceiling " \
              "context_target cache_type_k cache_type_v flash_attention projector " \
              "projector_fetch_script decode_tok_s prefill_tok_s quality tier batch ubatch " \
              "validated_filled_depth validation_evidence raw_tool_selection " \
              "guarded_tool_execution q4k_variant", names, " ")
        if (field == "") {
            for (i = 1; i <= 23; i++) { printf "%s=%s\n", names[i], $i }
        } else {
            for (i = 1; i <= 23; i++) {
                if (names[i] == field) { printf "%s\n", $i; found = 1 }
            }
            if (!found) { exit 3 }
        }
        exit 0
    }
    END {
        if (!matched_any) {
            printf "no registry row matches %s %s\n", kind, selector > "/dev/stderr"
            exit 1
        }
    }
' "$registry"
