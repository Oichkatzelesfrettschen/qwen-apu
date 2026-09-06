#!/bin/sh
# verify-models.sh over a fixture registry, pin ledger, and models tree: a
# matching file verifies, a truncated file reports bytes-differ, a same-sized
# file of other bytes reports digest-differs, an absent file reports absent, a
# row whose fetch rule pins nothing reports unpinned, a pin the registry names
# nowhere reports orphan-pin, and a mismatch alone ends the run non-zero.
set -eu
script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
tool=$script_directory/verify-models.sh
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT HUP INT TERM
failures=0
report() {
    if [ "$2" = ok ]; then printf 'ok %s\n' "$1"; else printf 'FAIL %s: %s\n' "$1" "$2"; failures=$((failures + 1)); fi
}
registry=$work/models.tsv
ledger=$work/model-artifacts.tsv
models=$work/models
mkdir -p "$models/good" "$models/short" "$models/other" "$models/unpinned"
printf 'good-bytes\n' >"$models/good/good.gguf"
printf 'x\n' >"$models/short/short.gguf"
printf 'other-bytes\n' >"$models/other/other.gguf"
good_bytes=$(wc -c <"$models/good/good.gguf" | tr -d ' ')
good_sha256=$(sha256sum "$models/good/good.gguf" | cut -d ' ' -f 1)
short_bytes=$(wc -c <"$models/short/short.gguf" | tr -d ' ')
other_bytes=$(wc -c <"$models/other/other.gguf" | tr -d ' ')

# A fetch script states its pin as two top-level assignments and this fixture
# states nothing else, since the verification reads the source rather than
# running it.
fetch_directory=$work/fetch
mkdir -p "$fetch_directory"
fixture_script() {
    printf '#!/bin/sh\nexpected_bytes=%s\nexpected_sha256=%s\n' "$2" "$3" >"$fetch_directory/$1"
}
fixture_script test-fixture-good.sh "$good_bytes" "$good_sha256"
fixture_script test-fixture-short.sh "$((short_bytes + 5))" "$good_sha256"
fixture_script test-fixture-other.sh "$other_bytes" "$good_sha256"
fixture_script test-fixture-absent.sh "$good_bytes" "$good_sha256"
printf '#!/bin/sh\n' >"$fetch_directory/test-fixture-unpinned.sh"

# The registry columns the verification reads are id, model_file, fetch_script,
# and projector, so the fixture states those and pads the rest.
: >"$registry"
printf '# fixture registry\n' >>"$registry"
add_row() {
    printf '%s\trole\t%s\t%s\t4096\t4096\t4096\tf16\tf16\ton\tnone\t-\t-\t-\t-\tproduction\t128\t32\t-\t-\t-\trefused\n' \
        "$1" "$2" "$3" >>"$registry"
}
add_row good good/good.gguf test-fixture-good.sh
add_row short short/short.gguf test-fixture-short.sh
add_row other other/other.gguf test-fixture-other.sh
add_row gone gone/gone.gguf test-fixture-absent.sh
add_row loose unpinned/loose.gguf test-fixture-unpinned.sh
# A row whose id the pin ledger also carries and which requires a projector:
# the model file takes the ledger pin and the projector takes its own script's,
# so the projector is never measured against the model's bytes.
printf 'vision\trole\tvision/vision.gguf\ttest-fixture-unpinned.sh\t4096\t4096\t4096\tf16\tf16\ton\trequired\ttest-fixture-projector.sh\t-\t-\t-\tproduction\t128\t32\t-\t-\t-\trefused\n' >>"$registry"
mkdir -p "$models/vision"
printf 'vision-model-bytes\n' >"$models/vision/vision.gguf"
printf 'projector-bytes\n' >"$models/vision/projector.gguf"
vision_bytes=$(wc -c <"$models/vision/vision.gguf" | tr -d ' ')
vision_sha256=$(sha256sum "$models/vision/vision.gguf" | cut -d ' ' -f 1)
projector_bytes=$(wc -c <"$models/vision/projector.gguf" | tr -d ' ')
projector_sha256=$(sha256sum "$models/vision/projector.gguf" | cut -d ' ' -f 1)
{
    printf '#!/bin/sh\n'
    printf 'destination_directory=${1:-"$qwen_home_models/vision"}\n'
    printf 'artifact_name=projector.gguf\n'
    printf 'expected_bytes=%s\n' "$projector_bytes"
    printf 'expected_sha256=%s\n' "$projector_sha256"
} >"$fetch_directory/test-fixture-projector.sh"

printf '# fixture pin ledger\nstranger\tstranger/stranger.gguf\t1\t%s\trepo\trev\nvision\tvision/vision.gguf\t%s\t%s\trepo\trev\n' \
    "$good_sha256" "$vision_bytes" "$vision_sha256" >"$ledger"

run() {
    QWEN_MODEL_REGISTRY=$registry QWEN_MODEL_ARTIFACTS=$ledger QWEN_MODEL_ROOT=$models QWEN_MODEL_FETCH_DIR=$fetch_directory "$tool" "$@"
}

if run >"$work/report.tsv" 2>&1; then
    report mismatch_exits_nonzero accepted
else
    report mismatch_exits_nonzero ok
fi
head -n 1 "$work/report.tsv" | grep -q '^model_id	kind	path	status	expected	observed	fetch_script$' \
    && report report_header ok || report report_header "$(head -n 1 "$work/report.tsv")"
grep -q "^good	model	good/good.gguf	verified	$good_bytes	$good_sha256	" "$work/report.tsv" \
    && report verified_row ok || report verified_row missing
grep -q "^short	model	short/short.gguf	bytes-differ	$((short_bytes + 5))	$short_bytes	" "$work/report.tsv" \
    && report bytes_differ_row ok || report bytes_differ_row missing
grep -q '^other	model	other/other.gguf	digest-differs	' "$work/report.tsv" \
    && report digest_differs_row ok || report digest_differs_row missing
grep -q '^gone	model	gone/gone.gguf	absent	' "$work/report.tsv" \
    && report absent_row ok || report absent_row missing
grep -q '^loose	model	unpinned/loose.gguf	unpinned	-	-	' "$work/report.tsv" \
    && report unpinned_row ok || report unpinned_row missing
grep -q "^vision	model	vision/vision.gguf	verified	$vision_bytes	$vision_sha256	" "$work/report.tsv" \
    && report ledger_pin_reads_the_model ok || report ledger_pin_reads_the_model missing
grep -q "^vision	projector	vision/projector.gguf	verified	$projector_bytes	$projector_sha256	" "$work/report.tsv" \
    && report projector_takes_its_own_pin ok || report projector_takes_its_own_pin "$(grep '	projector	' "$work/report.tsv")"
grep -q '^stranger	ledger	-	orphan-pin	' "$work/report.tsv" \
    && report orphan_pin_row ok || report orphan_pin_row missing
grep -q '^verify_models=failed verified=3 absent=1 unpinned=1 mismatched=2 orphan_pins=1 ' "$work/report.tsv" \
    && report summary_line ok || report summary_line "$(tail -n 1 "$work/report.tsv")"

# A selection reads the named rows alone, and a run over verified rows passes.
if run good >"$work/selected.tsv" 2>&1; then
    report selection_passes ok
else
    report selection_passes "$(cat "$work/selected.tsv")"
fi
[ "$(grep -c '	model	' "$work/selected.tsv")" -eq 1 ] \
    && report selection_reads_one_row ok || report selection_reads_one_row "$(grep -c '	model	' "$work/selected.tsv")"

# Nothing is fetched: the absent row's directory stays absent.
[ ! -e "$models/gone" ] && report fetches_nothing ok || report fetches_nothing created

if [ "$failures" -ne 0 ]; then printf '%s failure(s)\n' "$failures"; exit 1; fi
printf 'test-verify-models: all checks passed\n'
