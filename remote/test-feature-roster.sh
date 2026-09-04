#!/bin/sh
set -eu

# remote/build-feature-roster.sh turns four ledgers and one claim file into the
# document the page decorates its picker from, so a claim the ledgers contradict
# has to fail the generator rather than reach webui/roster.json. This test
# drives the generator over fixture ledgers for each contradiction it refuses
# and for the ordering it emits, then requires the shipped ledgers to reproduce
# the committed roster byte for byte.

if [ "$#" -ne 0 ]; then
    printf 'usage: %s\n' "$0" >&2
    exit 2
fi

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
repository_root=$(CDPATH='' cd -- "$script_directory/.." && pwd)
generator=$script_directory/build-feature-roster.sh

work_directory=$(mktemp -d)
trap 'rm -rf -- "$work_directory"' EXIT INT TERM HUP

tab=$(printf '\t')

# A row is written field by field, so a fixture states the columns it exercises
# and the reader sees which position carries the tier, the execution policy, or
# the review model.
write_row() {
    row_file=$1
    shift
    row_text=''
    for row_field in "$@"; do
        if [ -z "$row_text" ]; then
            row_text=$row_field
        else
            row_text=$row_text$tab$row_field
        fi
    done
    printf '%s\n' "$row_text" >>"$row_file"
}

model_row() {
    # id role model_file fetch_script, the depth triple, the cache triple,
    # projector pair, rates, quality, tier, geometry, filled depth, evidence,
    # and the two tool claims: 22 fields.
    write_row "$fixture_models" "$1" role "$1.gguf" "download-$1.sh" \
        8192 8192 32768 q8_0 q4_0 on none - - - untested "$2" 128 32 - - \
        unmeasured refused
}

build_fixture_ledgers() {
    fixture_models=$work_directory/models.tsv
    fixture_quarantine=$work_directory/quarantine.tsv
    fixture_pairs=$work_directory/draft-pairs.tsv
    fixture_web=$work_directory/web-profiles.tsv
    fixture_image=$work_directory/image-profiles.tsv
    fixture_claims=$work_directory/feature-claims.tsv
    fixture_output=$work_directory/roster.json
    rm -f "$fixture_models" "$fixture_quarantine" "$fixture_pairs" \
        "$fixture_web" "$fixture_image" "$fixture_claims" "$fixture_output"

    printf '# fixture model registry\n' >"$fixture_models"
    model_row qwen38-4b-distill production
    model_row qwen38-2b-distill production
    model_row qwen35-08b production
    model_row zz-other production
    model_row qwen35-2b candidate
    model_row nanbeige42-3b quarantine
    model_row qwen38-9b-distill archive

    printf '# fixture quarantine registry\n' >"$fixture_quarantine"
    write_row "$fixture_quarantine" nanbeige42-3b model nanbeige42-3b \
        no-validated-safe-tuple - - - - - - evidence/a.md evidence/b.md \
        evidence/c.md any

    printf '# fixture draft pair ledger\n' >"$fixture_pairs"
    write_row "$fixture_pairs" pair-a qwen38-2b-distill qwen35-08b candidate \
        2 0.00 0.896 8192 q8_0 q4_0 - 'pair a'

    # web_mode sits at field 3 and execution_policy at field 12, and the two
    # disagree here on purpose: web_mode names the intended path and
    # execution_policy names what is authorized now, so the emitted status has
    # to read the twelfth column.
    printf '# fixture web profile ledger\n' >"$fixture_web"
    write_row "$fixture_web" web-a qwen38-4b-distill ui-mediated 8192 - 5 2 \
        12000 yes no 9/10 validator-gated searxng qwen-open - 1 \
        http://127.0.0.1:8888

    printf '# fixture image profile ledger\n' >"$fixture_image"
    write_row "$fixture_image" image-a sdxs-512 A 512 512 1 euler 1.0 4 512 300 \
        refused - -

    printf '# fixture feature claims\n' >"$fixture_claims"
}

run_generator() {
    QWEN_FEATURE_CLAIMS=$fixture_claims \
    QWEN_MODEL_REGISTRY=$fixture_models \
    QWEN_QUARANTINE_REGISTRY=$fixture_quarantine \
    QWEN_DRAFT_PAIRS=$fixture_pairs \
    QWEN_WEB_PROFILES=$fixture_web \
    QWEN_IMAGE_PROFILES=$fixture_image \
        "$generator" "$fixture_output" >"$work_directory/stdout" \
            2>"$work_directory/stderr"
}

# Each rejection case seeds one claim the ledgers contradict and requires the
# generator to exit non-zero, name the subject, and leave no output behind.
expect_rejection() {
    rejection_name=$1
    rejection_pattern=$2
    if run_generator; then
        printf '%s: the generator accepted a claim it must refuse\n' \
            "$rejection_name" >&2
        exit 1
    fi
    if ! grep -q -- "$rejection_pattern" "$work_directory/stderr"; then
        printf '%s: the refusal names no %s\n' "$rejection_name" \
            "$rejection_pattern" >&2
        cat "$work_directory/stderr" >&2
        exit 1
    fi
    if [ -e "$fixture_output" ]; then
        printf '%s: a refused run wrote an output document\n' "$rejection_name" >&2
        exit 1
    fi
}

build_fixture_ledgers
write_row "$fixture_claims" qwen38-4b-distill text-chat approved evidence/a.md note
expect_rejection 'status outside the vocabulary' 'status approved is outside'

build_fixture_ledgers
write_row "$fixture_claims" qwen38-4b-distill text-chat candidate - note
expect_rejection 'candidate without evidence' 'requires retained evidence'

build_fixture_ledgers
write_row "$fixture_claims" qwen38-4b-distill text-chat unstable - note
expect_rejection 'unstable without evidence' 'requires retained evidence'

build_fixture_ledgers
write_row "$fixture_claims" absent-checkpoint text-chat experimental - note
expect_rejection 'unknown model id' 'absent from the model registry'

build_fixture_ledgers
write_row "$fixture_claims" nanbeige42-3b text-chat production evidence/a.md note
expect_rejection 'production under quarantine' \
    'production claim over a quarantined checkpoint'

build_fixture_ledgers
write_row "$fixture_claims" pair-a draft-pair-speculation production evidence/a.md note
write_row "$fixture_claims" pair-a web-search experimental - note
expect_rejection 'subject outside its feature namespace' \
    'absent from the web profile ledger'

build_fixture_ledgers
write_row "$fixture_claims" qwen38-4b-distill text-chat experimental - first
write_row "$fixture_claims" qwen38-4b-distill text-chat unsupported - second
expect_rejection 'duplicate claim' 'duplicate claim at row'

build_fixture_ledgers
write_row "$fixture_claims" qwen38-4b-distill text-chat production /etc/passwd note  # appliance-path: named
expect_rejection 'evidence outside the tree' \
    'not a repository-relative path under evidence/'

build_fixture_ledgers
write_row "$fixture_claims" qwen38-4b-distill text-chat production \
    evidence/../../etc/passwd note  # appliance-path: named
expect_rejection 'evidence traversing out of the tree' \
    'not a repository-relative path under evidence/'

build_fixture_ledgers
write_row "$fixture_claims" qwen38-4b-distill text-chat experimental - \
    'a note with a " in it'
expect_rejection 'note carrying a quotation mark' 'quotation mark'

build_fixture_ledgers
write_row "$fixture_claims" qwen38-4b-distill text-chat experimental -
expect_rejection 'short row' 'holds 4 fields, expected 5'

build_fixture_ledgers
write_row "$fixture_claims" qwen38-4b-distill flying experimental - note
expect_rejection 'feature outside the vocabulary' 'feature flying is outside'

# A registry the reader cannot parse stops the roster the way it stops preset
# generation, rather than emitting a document over the rows it did read.
build_fixture_ledgers
write_row "$fixture_quarantine" broken-row model broken-row reason
if run_generator; then
    printf 'the generator emitted a roster over a malformed quarantine registry\n' >&2
    exit 1
fi

# The ordering is tier rank, then the class policy, then id: the 2B class leads
# every tier, the 0.8B class follows, the 4B class follows that, and a row
# outside the three classes sorts after them. An archive row reaches no picker,
# so it reaches no roster.
build_fixture_ledgers
write_row "$fixture_claims" qwen38-2b-distill text-chat production evidence/a.md \
    'the primary performance target'
write_row "$fixture_claims" qwen35-2b vision candidate evidence/b.md \
    'the projector loads'
write_row "$fixture_claims" qwen35-2b long-context experimental - \
    'remote/probe-depth-projector.sh measures it'
write_row "$fixture_claims" nanbeige42-3b quarantine unstable evidence/c.md \
    'model scope'
write_row "$fixture_claims" pair-a draft-pair-speculation experimental - \
    'remote/measure-draft-pair.sh measures it'
write_row "$fixture_claims" web-a web-search unsupported - 'execution_policy refused'
write_row "$fixture_claims" image-a image-generation unsupported - \
    'execution_policy refused'
if ! run_generator; then
    cat "$work_directory/stderr" >&2
    printf 'the generator refused a consistent fixture\n' >&2
    exit 1
fi

emitted_order=$(python3 -c '
import json
import sys

roster = json.load(open(sys.argv[1]))
print(" ".join(model["id"] for model in roster["models"]))
' "$fixture_output")
expected_order='qwen38-2b-distill qwen35-08b qwen38-4b-distill zz-other qwen35-2b nanbeige42-3b'
if [ "$emitted_order" != "$expected_order" ]; then
    printf 'roster order is %s, expected %s\n' "$emitted_order" "$expected_order" >&2
    exit 1
fi

# The tags the picker badges come from the tier and from the claims: a row with
# a vision claim a run established carries vision, and a row carrying any
# experimental claim carries experimental.
python3 -c '
import json
import sys

roster = json.load(open(sys.argv[1]))
by_id = {model["id"]: model for model in roster["models"]}

assert by_id["qwen38-2b-distill"]["tags"] == ["production"], \
    by_id["qwen38-2b-distill"]["tags"]
assert by_id["qwen35-2b"]["tags"] == ["candidate", "vision", "experimental"], \
    by_id["qwen35-2b"]["tags"]
assert by_id["nanbeige42-3b"]["tags"] == ["quarantine"], by_id["nanbeige42-3b"]["tags"]
assert by_id["qwen38-2b-distill"]["class_rank"] == 1
assert by_id["qwen35-08b"]["class_rank"] == 2
assert by_id["qwen38-4b-distill"]["class_rank"] == 3
assert by_id["zz-other"]["class_rank"] == 4

# A model-scope feature the ledger claims nothing for reads unclaimed rather
# than reading as a denial, so the matrix renders a hole where no run has spoken.
claims = {claim["feature"]: claim for claim in by_id["qwen38-2b-distill"]["features"]}
assert claims["text-chat"]["status"] == "production"
assert claims["vision"]["status"] == "unclaimed"
assert claims["vision"]["evidence"] == "-"
assert claims["vision"]["note"] == "-"

# Every model-scope feature appears in every model row, so the page reads a
# rectangular matrix rather than joining ragged rows.
feature_names = [entry["feature"] for entry in roster["features"]
                 if entry["scope"] == "model"]
for model in roster["models"]:
    assert [claim["feature"] for claim in model["features"]] == feature_names, model["id"]

assert [pair["id"] for pair in roster["draft_pairs"]] == ["pair-a"]
assert roster["draft_pairs"][0]["target_model_id"] == "qwen38-2b-distill"
assert roster["web_profiles"][0]["execution_policy"] == "validator-gated"
assert roster["image_profiles"][0]["execution_policy"] == "refused"
assert roster["image_profiles"][0]["review_model"] == "-"
assert roster["image_profiles"][0]["features"][0]["feature"] == "image-generation"
assert roster["image_profiles"][0]["features"][1]["feature"] == "image-review"
' "$fixture_output"

# The committed document is what the page fetches, so the shipped ledgers must
# reproduce it exactly. remote/repository-quality-gates.sh runs the same
# comparison; this test states it beside the generator it belongs to.
regenerated=$work_directory/committed-roster.json
"$generator" "$regenerated" >/dev/null
if ! diff -u "$repository_root/webui/roster.json" "$regenerated"; then
    printf 'webui/roster.json drifted from the ledgers; run remote/build-feature-roster.sh\n' >&2
    exit 1
fi

printf 'feature_roster=accepted\n'
