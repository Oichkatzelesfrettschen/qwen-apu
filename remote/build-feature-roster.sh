#!/bin/sh
set -eu

# Emit webui/roster.json from the registry and the feature claim ledger, so the
# page decorates a model id with a tier and a support matrix it never holds a
# second copy of. remote/repository-quality-gates.sh regenerates into a
# scratch path and diffs the result against the committed file, so an edit to
# remote/models.tsv, remote/quarantine.tsv, or remote/feature-claims.tsv that
# leaves the page stale fails the gate rather than serving a claim the ledgers
# retired.
#
# The ordering is the repository class policy rather than the registry file
# order. Tier ranks first, since the page badges production, candidate, and
# quarantine and a reader asks what is served before asking how fast it is.
# Inside a tier the three runtime classes rank 2B, 0.8B, then 4B: the 2B class
# is the appliance primary performance target, the 0.8B class its secondary
# fast target, and the 4B class the quality-heavy fallback. A row outside those
# three classes ranks after them and sorts by id, because the policy states an
# order over three named classes and states nothing about a fourth.
#
# Every claim is validated before any row is emitted, the discipline
# remote/model-registry.sh applies to the quarantine, tuple, draft pair, and
# context checkpoint authorities: a reader taking one row must not trust a
# ledger a sibling row has made unsafe to read. Row shape is validated here and
# the existence of each evidence path belongs to
# remote/check-ledger-evidence.sh, which runs where the tree is.

if [ "$#" -gt 1 ]; then
    printf 'usage: %s [OUTPUT_JSON]\n' "$0" >&2
    printf '       default output is webui/roster.json\n' >&2
    exit 2
fi

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
repository_root=$(CDPATH='' cd -- "$script_directory/.." && pwd)

output_json=${1:-$repository_root/webui/roster.json}
feature_claims=${QWEN_FEATURE_CLAIMS:-$script_directory/feature-claims.tsv}
model_registry=${QWEN_MODEL_REGISTRY:-$script_directory/models.tsv}
draft_pair_ledger=${QWEN_DRAFT_PAIRS:-$script_directory/draft-pairs.tsv}
web_profile_ledger=${QWEN_WEB_PROFILES:-$script_directory/web-profiles.tsv}
image_profile_ledger=${QWEN_IMAGE_PROFILES:-$script_directory/image-profiles.tsv}

for required_ledger in "$feature_claims" "$model_registry" "$draft_pair_ledger" \
    "$web_profile_ledger" "$image_profile_ledger"; do
    if [ ! -r "$required_ledger" ]; then
        printf 'feature roster input is unreadable: %s\n' "$required_ledger" >&2
        exit 1
    fi
done

# The quarantine authority answers through the registry reader rather than
# through a second parse of the file, so a malformed registry stops the roster
# the way it stops preset generation. The query names no runtime mode and
# returns model-scope subjects alone: a profile-scope row removes one tuple of
# a checkpoint that otherwise serves, and reading it as a checkpoint exclusion
# would retire the served 4B over a geometry the launch never builds.
quarantine_subjects=$("$script_directory/model-registry.sh" quarantine-subjects)

roster_json=$(printf '%s\n' "$quarantine_subjects" | awk -F'\t' \
    -v models_file="$model_registry" \
    -v pairs_file="$draft_pair_ledger" \
    -v web_file="$web_profile_ledger" \
    -v image_file="$image_profile_ledger" \
    -v claims_file="$feature_claims" '
    function fail(message) {
        printf "%s\n", message > "/dev/stderr"
        bad++
    }
    # Validation guarantees every emitted field is free of the quotation mark,
    # the backslash, and the control characters, so a string reaches JSON as
    # itself and the emitter carries no escape table that a ledger edit could
    # outrun.
    function quoted(text) {
        return "\"" text "\""
    }
    function printable(text) {
        return text !~ /["\\]/ && text !~ /[\001-\037\177]/
    }
    function class_rank(model_id) {
        if (model_id in two_b_class) { return 1 }
        if (model_id in compact_class) { return 2 }
        if (model_id in four_b_class) { return 3 }
        return 4
    }
    function tier_rank(tier) {
        if (tier == "production") { return 1 }
        if (tier == "candidate") { return 2 }
        if (tier == "quarantine") { return 3 }
        return 0
    }
    BEGIN {
        split("text-chat vision tool-selection guarded-tool-execution " \
              "long-context context-checkpoints quarantine", model_features, " ")
        model_feature_count = 7
        for (i = 1; i <= model_feature_count; i++) {
            feature_scope[model_features[i]] = "model"
        }
        feature_scope["draft-pair-speculation"] = "draft-pair"
        feature_scope["web-search"] = "web-profile"
        feature_scope["image-generation"] = "image-profile"
        feature_scope["image-review"] = "image-profile"
        split("draft-pair-speculation web-search image-generation image-review", \
              other_features, " ")
        other_feature_count = 4

        split("production candidate experimental unstable unsupported", \
              statuses, " ")
        for (i = 1; i <= 5; i++) { known_status[statuses[i]] = 1 }

        # The class membership the CLAUDE.md three-runtime-class section names.
        # A checkpoint joins a class by the architecture and parameter scale its
        # publisher states, and the ordering is a repository policy over three
        # classes rather than a property any ledger column carries.
        split("qwen38-2b-distill qwen35-2b qwen38-2b-uncensored qwen35-2b-hauhau " \
              "qwen35-2b-unredacted qwen35-2b-heretic qwenseer-2b", members, " ")
        for (i in members) { two_b_class[members[i]] = 1 }
        split("qwen35-08b qwen35-08b-f16 qwen35-08b-unsloth-unc", members, " ")
        for (i in members) { compact_class[members[i]] = 1 }
        split("qwen38-4b-distill qwen35-4b-base", members, " ")
        for (i in members) { four_b_class[members[i]] = 1 }
    }

    FILENAME == "-" {
        if ($0 == "") { next }
        quarantined_model[$1] = 1
        next
    }

    FILENAME == models_file {
        if ($0 ~ /^#/ || $0 ~ /^[[:space:]]*$/) { next }
        if (NF != 22) {
            fail(sprintf("model row %d holds %d fields, expected 22", FNR, NF))
            next
        }
        model_tier[$1] = $16
        model_role[$1] = $2
        if (tier_rank($16) == 0) { next }
        rostered_model[++rostered_count] = $1
        next
    }

    FILENAME == pairs_file {
        if ($0 ~ /^#/ || $0 ~ /^[[:space:]]*$/) { next }
        if (NF != 12) {
            fail(sprintf("draft pair row %d holds %d fields, expected 12", FNR, NF))
            next
        }
        pair_id[++pair_count] = $1
        known_pair[$1] = 1
        pair_target[$1] = $2
        pair_draft[$1] = $3
        pair_tier[$1] = $4
        next
    }

    FILENAME == web_file {
        if ($0 ~ /^#/ || $0 ~ /^[[:space:]]*$/) { next }
        if (NF != 17) {
            fail(sprintf("web profile row %d holds %d fields, expected 17", FNR, NF))
            next
        }
        web_id[++web_count] = $1
        known_web[$1] = 1
        web_model[$1] = $2
        # Field 12 is execution_policy and field 3 is web_mode, which names the
        # intended path rather than what is authorized now, so the emitted
        # status reads the twelfth column alone.
        web_policy[$1] = $12
        next
    }

    FILENAME == image_file {
        if ($0 ~ /^#/ || $0 ~ /^[[:space:]]*$/) { next }
        if (NF != 14) {
            fail(sprintf("image profile row %d holds %d fields, expected 14", FNR, NF))
            next
        }
        image_id[++image_count] = $1
        known_image[$1] = 1
        image_policy[$1] = $12
        image_review[$1] = $14
        next
    }

    FILENAME == claims_file {
        if ($0 ~ /^#/ || $0 ~ /^[[:space:]]*$/) { next }
        if (NF != 5) {
            fail(sprintf("feature claim row %d holds %d fields, expected 5", FNR, NF))
            next
        }
        claim_subject = $1
        claim_feature = $2
        claim_status = $3
        claim_evidence = $4
        claim_note = $5
        if (claim_subject == "" || claim_feature == "" || claim_status == "" ||
            claim_evidence == "" || claim_note == "") {
            fail(sprintf("feature claim row %d carries an empty field", FNR))
            next
        }
        if (!printable(claim_subject) || !printable(claim_feature) ||
            !printable(claim_status) || !printable(claim_evidence) ||
            !printable(claim_note)) {
            fail(sprintf("%s/%s: a field carries a quotation mark, a backslash, or a control character", \
                claim_subject, claim_feature))
            next
        }
        if (!(claim_feature in feature_scope)) {
            fail(sprintf("%s: feature %s is outside the vocabulary", \
                claim_subject, claim_feature))
            next
        }
        if (!(claim_status in known_status)) {
            fail(sprintf("%s/%s: status %s is outside the vocabulary", \
                claim_subject, claim_feature, claim_status))
        }
        claim_key = claim_subject SUBSEP claim_feature
        if (claim_key in claim_status_of) {
            fail(sprintf("%s/%s: duplicate claim at row %d", \
                claim_subject, claim_feature, FNR))
        }
        scope = feature_scope[claim_feature]
        if (scope == "model" && !(claim_subject in model_tier)) {
            fail(sprintf("%s/%s: subject is absent from the model registry", \
                claim_subject, claim_feature))
        }
        if (scope == "draft-pair" && !(claim_subject in known_pair)) {
            fail(sprintf("%s/%s: subject is absent from the draft pair ledger", \
                claim_subject, claim_feature))
        }
        if (scope == "web-profile" && !(claim_subject in known_web)) {
            fail(sprintf("%s/%s: subject is absent from the web profile ledger", \
                claim_subject, claim_feature))
        }
        if (scope == "image-profile" && !(claim_subject in known_image)) {
            fail(sprintf("%s/%s: subject is absent from the image profile ledger", \
                claim_subject, claim_feature))
        }
        # production, candidate, and unstable each assert a run, so each names
        # the record of it. experimental and unsupported admit `-`, because a
        # mechanism nobody measured retains nothing.
        if (claim_evidence != "-") {
            if (claim_evidence !~ /^evidence\// || claim_evidence ~ /(^|\/)\.\.(\/|$)/) {
                fail(sprintf("%s/%s: evidence is not a repository-relative path under evidence/: %s", \
                    claim_subject, claim_feature, claim_evidence))
            }
        } else if (claim_status == "production" || claim_status == "candidate" ||
                   claim_status == "unstable") {
            fail(sprintf("%s/%s: status %s requires retained evidence", \
                claim_subject, claim_feature, claim_status))
        }
        # A quarantined checkpoint carries a recorded device failure or holds no
        # validated safe tuple, and build-router-presets.sh keeps it out of the
        # picker, so a production claim over it would badge a row the launch
        # path refuses to construct.
        if (scope == "model" && claim_status == "production" &&
            (model_tier[claim_subject] == "quarantine" ||
             (claim_subject in quarantined_model))) {
            fail(sprintf("%s/%s: production claim over a quarantined checkpoint", \
                claim_subject, claim_feature))
        }
        claim_status_of[claim_key] = claim_status
        claim_evidence_of[claim_key] = claim_evidence
        claim_note_of[claim_key] = claim_note
        next
    }

    function emit_claim(subject, feature, indent,    key, status, evidence, note) {
        key = subject SUBSEP feature
        status = (key in claim_status_of) ? claim_status_of[key] : "unclaimed"
        evidence = (key in claim_evidence_of) ? claim_evidence_of[key] : "-"
        note = (key in claim_note_of) ? claim_note_of[key] : "-"
        printf "%s{ \"feature\": %s, \"status\": %s, \"evidence\": %s, \"note\": %s }", \
            indent, quoted(feature), quoted(status), quoted(evidence), quoted(note)
    }

    END {
        if (bad) { exit 1 }

        # Insertion sort over tier rank, then class rank, then id. The roster
        # holds at most the registry row count, so the quadratic cost is a few
        # hundred comparisons and the ordering stays readable beside the policy
        # it implements.
        for (i = 2; i <= rostered_count; i++) {
            candidate = rostered_model[i]
            j = i - 1
            while (j >= 1) {
                held = rostered_model[j]
                if (tier_rank(model_tier[held]) < tier_rank(model_tier[candidate])) { break }
                if (tier_rank(model_tier[held]) == tier_rank(model_tier[candidate])) {
                    if (class_rank(held) < class_rank(candidate)) { break }
                    if (class_rank(held) == class_rank(candidate) && held < candidate) { break }
                }
                rostered_model[j + 1] = held
                j--
            }
            rostered_model[j + 1] = candidate
        }

        print "{"
        print "  \"schema\": \"qwen-feature-roster/1\","
        print "  \"features\": ["
        for (i = 1; i <= model_feature_count; i++) {
            printf "    { \"feature\": %s, \"scope\": \"model\" },\n", \
                quoted(model_features[i])
        }
        for (i = 1; i <= other_feature_count; i++) {
            printf "    { \"feature\": %s, \"scope\": %s }%s\n", \
                quoted(other_features[i]), quoted(feature_scope[other_features[i]]), \
                (i == other_feature_count ? "" : ",")
        }
        print "  ],"

        print "  \"models\": ["
        for (i = 1; i <= rostered_count; i++) {
            model_id = rostered_model[i]
            tier = model_tier[model_id]
            # The tags the picker badges. tier comes from the registry, vision
            # from a vision claim a run established, and experimental from any
            # claim whose measurement is still ahead of it.
            tag_count = 0
            tags[++tag_count] = tier
            vision_key = model_id SUBSEP "vision"
            if ((vision_key in claim_status_of) &&
                (claim_status_of[vision_key] == "production" ||
                 claim_status_of[vision_key] == "candidate")) {
                tags[++tag_count] = "vision"
            }
            for (f = 1; f <= model_feature_count; f++) {
                probe_key = model_id SUBSEP model_features[f]
                if ((probe_key in claim_status_of) &&
                    claim_status_of[probe_key] == "experimental") {
                    tags[++tag_count] = "experimental"
                    break
                }
            }
            print "    {"
            printf "      \"id\": %s,\n", quoted(model_id)
            printf "      \"role\": %s,\n", quoted(model_role[model_id])
            printf "      \"tier\": %s,\n", quoted(tier)
            printf "      \"class_rank\": %d,\n", class_rank(model_id)
            printf "      \"tags\": ["
            for (t = 1; t <= tag_count; t++) {
                printf "%s%s", quoted(tags[t]), (t == tag_count ? "" : ", ")
            }
            print "],"
            print "      \"features\": ["
            for (f = 1; f <= model_feature_count; f++) {
                emit_claim(model_id, model_features[f], "        ")
                print (f == model_feature_count ? "" : ",")
            }
            print "      ]"
            printf "    }%s\n", (i == rostered_count ? "" : ",")
        }
        print "  ],"

        print "  \"draft_pairs\": ["
        for (i = 1; i <= pair_count; i++) {
            print "    {"
            printf "      \"id\": %s,\n", quoted(pair_id[i])
            printf "      \"target_model_id\": %s,\n", quoted(pair_target[pair_id[i]])
            printf "      \"draft_model_id\": %s,\n", quoted(pair_draft[pair_id[i]])
            printf "      \"tier\": %s,\n", quoted(pair_tier[pair_id[i]])
            print "      \"features\": ["
            emit_claim(pair_id[i], "draft-pair-speculation", "        ")
            print ""
            print "      ]"
            printf "    }%s\n", (i == pair_count ? "" : ",")
        }
        print "  ],"

        print "  \"web_profiles\": ["
        for (i = 1; i <= web_count; i++) {
            print "    {"
            printf "      \"id\": %s,\n", quoted(web_id[i])
            printf "      \"model_id\": %s,\n", quoted(web_model[web_id[i]])
            printf "      \"execution_policy\": %s,\n", quoted(web_policy[web_id[i]])
            print "      \"features\": ["
            emit_claim(web_id[i], "web-search", "        ")
            print ""
            print "      ]"
            printf "    }%s\n", (i == web_count ? "" : ",")
        }
        print "  ],"

        print "  \"image_profiles\": ["
        for (i = 1; i <= image_count; i++) {
            print "    {"
            printf "      \"id\": %s,\n", quoted(image_id[i])
            printf "      \"execution_policy\": %s,\n", quoted(image_policy[image_id[i]])
            printf "      \"review_model\": %s,\n", quoted(image_review[image_id[i]])
            print "      \"features\": ["
            emit_claim(image_id[i], "image-generation", "        ")
            print ","
            emit_claim(image_id[i], "image-review", "        ")
            print ""
            print "      ]"
            printf "    }%s\n", (i == image_count ? "" : ",")
        }
        print "  ]"
        print "}"
    }
' - "$model_registry" "$draft_pair_ledger" "$web_profile_ledger" \
    "$image_profile_ledger" "$feature_claims") || exit 1

# The roster is written whole or not at all, so a reader served from the same
# directory never reads half a document: the content lands in a sibling
# temporary file and one rename publishes it.
output_directory=$(dirname -- "$output_json")
if [ ! -d "$output_directory" ]; then
    printf 'feature roster output directory is absent: %s\n' "$output_directory" >&2
    exit 1
fi
staged_output=$(mktemp "$output_directory/.roster.json.XXXXXX")
printf '%s\n' "$roster_json" >"$staged_output"
mv -- "$staged_output" "$output_json"

printf 'feature_roster=written output=%s claims=%s\n' "$output_json" \
    "$(awk -F'\t' '/^[[:space:]]*($|#)/ { next } { rows++ } END { print rows + 0 }' \
        "$feature_claims")"
