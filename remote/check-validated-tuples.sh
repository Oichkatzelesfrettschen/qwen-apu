#!/bin/sh
set -eu

# Every models.tsv row that claims a numeric validated_filled_depth must own a
# validated row in remote/validated-tuples.tsv naming the same model, depth,
# geometry, cache policy, and projector state. models.tsv holds one
# validated_filled_depth tuple per row and the ledger holds every measured arm,
# so the cross-ledger check derives the complete tuple models.tsv already
# claims and requires the ledger to carry the same tuple.
#
# remote/image-profiles.tsv adds a second claim over the same ledger. A row that
# names a review_model makes build-web-presets.sh emit a review-only vision
# section, which it emits only against a `validated` row carrying
# `runtime_mode=router-child` and `projector_state=loaded` at that model's own
# registry tuple. A standalone row of the same geometry leaves that section
# ungenerated, so the reviewer claim is checked here rather than at the launch
# that discovers it: a `validator-gated` image row is an emitting grant and its
# missing reviewer tuple fails the gate, while any other policy emits nothing
# under every setting and reports a warning naming the arm that would close it.

if [ "$#" -ne 0 ]; then
    printf 'usage: %s\n' "$0" >&2
    exit 2
fi

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
model_registry=${QWEN_MODEL_REGISTRY:-$script_directory/models.tsv}
tuple_ledger=${QWEN_VALIDATED_TUPLES:-$script_directory/validated-tuples.tsv}
image_profiles=${QWEN_IMAGE_PROFILES:-$script_directory/image-profiles.tsv}

if [ ! -r "$model_registry" ]; then
    printf 'model registry is unreadable: %s\n' "$model_registry" >&2
    exit 1
fi
if [ ! -r "$tuple_ledger" ]; then
    printf 'validated tuple ledger is unreadable: %s\n' "$tuple_ledger" >&2
    exit 1
fi
if [ ! -r "$image_profiles" ]; then
    printf 'image profile ledger is unreadable: %s\n' "$image_profiles" >&2
    exit 1
fi

awk -F'\t' -v tuple_ledger_path="$tuple_ledger" '
    FILENAME == ARGV[1] {
        if ($0 ~ /^#/ || $0 ~ /^[[:space:]]*$/) { next }
        tuple_rows++
        if (NF != 21) {
            printf "validated tuple row %d holds %d fields, expected 21\n", \
                FNR, NF > "/dev/stderr"
            malformed++
            next
        }
        if ($1 == "" || $2 == "") {
            printf "validated tuple row %d requires tuple_id and model_id\n", \
                FNR > "/dev/stderr"
            malformed++
        }
        for (field_index = 4; field_index <= 6; field_index++) {
            if ($field_index !~ /^[1-9][0-9]*$/) {
                printf "%s: tuple geometry field %d is not a canonical positive integer: %s\n", \
                    $1, field_index, $field_index > "/dev/stderr"
                malformed++
            }
        }
        if ($7 !~ /^(f32|f16|bf16|q8_0|q5_1|q5_0|q4_1|q4_0|iq4_nl)$/ ||
            $8 !~ /^(f32|f16|bf16|q8_0|q5_1|q5_0|q4_1|q4_0|iq4_nl)$/) {
            printf "%s: tuple carries an invalid cache type\n", $1 > "/dev/stderr"
            malformed++
        }
        if ($9 !~ /^(on|off|auto)$/ || $10 !~ /^[1-9][0-9]*$/ ||
            $11 !~ /^[1-9][0-9]*$/ || $12 !~ /^(none|loaded)$/ ||
            $13 !~ /^(vulkan|cpu|hip)$/ ||
            $14 !~ /^(validated|failed|unverified)$/) {
            printf "%s: tuple carries an invalid policy or status field\n", \
                $1 > "/dev/stderr"
            malformed++
        }
        if ($6 ~ /^[1-9][0-9]*$/ && $5 ~ /^[1-9][0-9]*$/ &&
            $6 + 0 > $5 + 0) {
            printf "%s: tuple ubatch %s exceeds batch %s\n", \
                $1, $6, $5 > "/dev/stderr"
            malformed++
        }
        if ($14 == "validated" && $15 == "-") {
            printf "%s: validated tuple carries no evidence path\n", \
                $1 > "/dev/stderr"
            malformed++
        }
        if ($14 != "validated") { next }
        # model_id, context, batch, ubatch, cache_k, cache_v, flash_attention,
        # projector_state
        key = $2 SUBSEP $4 SUBSEP $5 SUBSEP $6 SUBSEP $7 SUBSEP $8 SUBSEP \
            $9 SUBSEP $12
        validated_tuples[key] = 1
        # The reviewer claim reads one serving path rather than any measured
        # arm, so a router-child row with the projector loaded on the Vulkan
        # backend is indexed under its own key.
        if ($3 == "router-child" && $12 == "loaded" && $13 == "vulkan") {
            router_child_tuples[$2 SUBSEP $4 SUBSEP $5 SUBSEP $6 SUBSEP $7 \
                SUBSEP $8 SUBSEP $9] = 1
        }
        next
    }
    FILENAME == ARGV[2] && ($0 ~ /^#/ || $0 ~ /^[[:space:]]*$/) { next }
    FILENAME == ARGV[2] {
        model_rows++
        if (NF != 22) {
            printf "model row %d holds %d fields, expected 22\n", \
                FNR, NF > "/dev/stderr"
            malformed++
            next
        }
        # The whole serving tuple of every row, because the reviewer claim in
        # remote/image-profiles.tsv names a model_id and reads its geometry from
        # here the way build-web-presets.sh reads it.
        registry_context[$1] = $5
        registry_cache_k[$1] = $8
        registry_cache_v[$1] = $9
        registry_flash[$1] = $10
        registry_projector[$1] = $11
        registry_batch[$1] = $17
        registry_ubatch[$1] = $18
        # id, context_default..., batch, ubatch, validated_filled_depth,
        # validation_evidence, cache_type_k, cache_type_v, flash_attention.
        if ($19 == "-") { next }
        if ($19 !~ /^[1-9][0-9]*$/) {
            printf "%s: validated_filled_depth is malformed: %s\n", \
                $1, $19 > "/dev/stderr"
            malformed++
            next
        }
        expected_projector_state = ($11 == "required" ? "loaded" : "none")
        checked++
        key = $1 SUBSEP $19 SUBSEP $17 SUBSEP $18 SUBSEP $8 SUBSEP $9 SUBSEP \
            $10 SUBSEP expected_projector_state
        if (!(key in validated_tuples)) {
            printf "%s: models.tsv claims validated_filled_depth %s at batch %s, ubatch %s, cache %s/%s, flash attention %s, projector state %s, and no validated row in %s matches\n", \
                $1, $19, $17, $18, $8, $9, $10, \
                expected_projector_state, tuple_ledger_path > "/dev/stderr"
            gaps++
        }
        next
    }
    $0 ~ /^#/ || $0 ~ /^[[:space:]]*$/ { next }
    {
        image_rows++
        if (NF != 14) {
            printf "image profile row %d holds %d fields, expected 14\n", \
                FNR, NF > "/dev/stderr"
            malformed++
            next
        }
        if ($14 == "-" || $14 == "") { next }
        reviewers++
        # An emitting grant is the one that reaches a served section, so its
        # missing reviewer tuple fails the gate and every other policy reports
        # the same absence as a warning.
        emitting = ($12 == "validator-gated")
        if (!($14 in registry_context)) {
            printf "%s: image profile names review_model %s, which the model registry holds no row for\n", \
                $1, $14 > "/dev/stderr"
            if (emitting) { gaps++ } else { warnings++ }
            next
        }
        if (registry_projector[$14] != "required") {
            printf "%s: image profile names review_model %s, whose registry row reads projector %s, and a reviewer reads an image through its own projector\n", \
                $1, $14, registry_projector[$14] > "/dev/stderr"
            if (emitting) { gaps++ } else { warnings++ }
            next
        }
        reviewer_key = $14 SUBSEP registry_context[$14] SUBSEP \
            registry_batch[$14] SUBSEP registry_ubatch[$14] SUBSEP \
            registry_cache_k[$14] SUBSEP registry_cache_v[$14] SUBSEP \
            registry_flash[$14]
        if (reviewer_key in router_child_tuples) { next }
        printf "%s: image profile names review_model %s, and no validated router-child row with the projector loaded in %s matches its registry tuple at depth %s, batch %s, ubatch %s, cache %s/%s, flash attention %s\n", \
            $1, $14, tuple_ledger_path, registry_context[$14], \
            registry_batch[$14], registry_ubatch[$14], registry_cache_k[$14], \
            registry_cache_v[$14], registry_flash[$14] > "/dev/stderr"
        printf "QWEN_WEDGE_DEPTHS=%s remote/probe-depth-projector.sh --runtime-mode router-child %s OUTPUT_DIRECTORY\n", \
            registry_context[$14], $14 > "/dev/stderr"
        if (emitting) { gaps++ } else { warnings++ }
    }
    END {
        if (!tuple_rows || !model_rows || !image_rows) {
            printf "check_validated_tuples=rejected empty_ledger=1 tuple_rows=%d model_rows=%d image_rows=%d\n", \
                tuple_rows, model_rows, image_rows > "/dev/stderr"
            exit 1
        }
        if (gaps + malformed > 0) {
            printf "check_validated_tuples=rejected gaps=%d malformed=%d checked=%d reviewers=%d\n", \
                gaps, malformed, checked, reviewers > "/dev/stderr"
            exit 1
        }
        if (warnings > 0) {
            printf "check_validated_tuples_warning=reviewer_tuple_absent warnings=%d\n", \
                warnings
        }
        printf "check_validated_tuples=accepted checked=%d reviewers=%d\n", \
            checked, reviewers
    }
' "$tuple_ledger" "$model_registry" "$image_profiles"
