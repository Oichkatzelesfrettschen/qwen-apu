#!/bin/sh
# stage-webui-page.sh writes the served page from the launch's own bounds and
# reads back exactly what it wrote; every other shape refuses.
set -eu
script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
stager=$script_directory/stage-webui-page.sh
source_page=$script_directory/../webui
temporary_directory=$(mktemp -d)
trap 'rm -rf "$temporary_directory"' EXIT HUP INT TERM

report() { printf 'ok %s\n' "$1"; }
refuses() {
    # refuses NAME EXPECTED_STDERR_FRAGMENT COMMAND...
    refusal_name=$1; refusal_fragment=$2; shift 2
    if "$@" >"$temporary_directory/refusal.out" 2>"$temporary_directory/refusal.err"; then
        printf '%s: accepted where a refusal was expected\n' "$refusal_name" >&2
        exit 1
    fi
    grep -F "$refusal_fragment" "$temporary_directory/refusal.err" >/dev/null || {
        printf '%s: refusal did not name %s:\n' "$refusal_name" "$refusal_fragment" >&2
        cat "$temporary_directory/refusal.err" >&2
        exit 1
    }
    report "$refusal_name"
}

# ---- the exact generated page ---------------------------------------------
line=$(QWEN_LAN_MAX_PROMPT_TOKENS=1000 QWEN_LAN_MAX_OUTPUT_TOKENS=200 \
    "$stager" stage "$source_page" "$temporary_directory/served")
case $line in
    "staged_page=$temporary_directory/served page_sha256="*' prompt_bound=1000 output_bound=200') ;;
    *) printf 'stage line unexpected: %s\n' "$line" >&2; exit 1 ;;
esac
printed_sha=${line#*page_sha256=}; printed_sha=${printed_sha%% *}
[ "$printed_sha" = "$(sha256sum "$temporary_directory/served/index.html" | cut -d ' ' -f 1)" ]
report stage_prints_the_served_digest
grep -Fx '<meta name="qwen-lan-max-prompt-tokens" content="1000">' \
    "$temporary_directory/served/index.html" >/dev/null
grep -Fx '<meta name="qwen-lan-max-output-tokens" content="200">' \
    "$temporary_directory/served/index.html" >/dev/null
report both_tags_written_once
# The tags sit after the broker tag, ahead of the script that reads them.
broker_line=$(grep -n '^<meta name="qwen-web-broker"' "$temporary_directory/served/index.html" | cut -d: -f1)
prompt_line=$(grep -n '^<meta name="qwen-lan-max-prompt-tokens"' "$temporary_directory/served/index.html" | cut -d: -f1)
[ "$prompt_line" -eq $((broker_line + 1)) ]
report tags_follow_the_broker_tag
[ -f "$temporary_directory/served/roster.json" ]
report sibling_files_copied
# Everything else in the page is byte-identical to the source.
diff <(grep -v '^<meta name="qwen-lan-max-' "$temporary_directory/served/index.html") \
    "$source_page/index.html" >/dev/null 2>&1 || {
    sed '/^<meta name="qwen-lan-max-/d' "$temporary_directory/served/index.html" \
        >"$temporary_directory/stripped.html"
    cmp "$temporary_directory/stripped.html" "$source_page/index.html"
}
report page_otherwise_identical
[ "$("$stager" read "$temporary_directory/served/index.html")" = 'prompt_bound=1000 output_bound=200' ]
report read_returns_what_stage_wrote
ls -a "$temporary_directory" | grep -q '^\.webui-staging\.' && {
    printf 'staging directory left behind\n' >&2; exit 1; }
report staging_directory_renamed_away

# ---- no bounds: an identical copy, no tags -------------------------------------
line=$("$stager" stage "$source_page" "$temporary_directory/plain")
case $line in *' prompt_bound=- output_bound=-') ;; *) printf 'plain line: %s\n' "$line" >&2; exit 1 ;; esac
cmp "$temporary_directory/plain/index.html" "$source_page/index.html"
[ "$("$stager" read "$temporary_directory/plain/index.html")" = 'prompt_bound=- output_bound=-' ]
report unbounded_launch_serves_the_source_page

# ---- restaging replaces the previous copy ---------------------------------------
QWEN_LAN_MAX_PROMPT_TOKENS=1000 QWEN_LAN_MAX_OUTPUT_TOKENS=200 \
    "$stager" stage "$source_page" "$temporary_directory/plain" >/dev/null
[ "$("$stager" read "$temporary_directory/plain/index.html")" = 'prompt_bound=1000 output_bound=200' ]
report restage_replaces_the_directory

# ---- refusals ----------------------------------------------------------------------
refuses source_with_tags_refused 'the launch alone writes them' \
    env QWEN_LAN_MAX_PROMPT_TOKENS=1000 QWEN_LAN_MAX_OUTPUT_TOKENS=200 \
    "$stager" stage "$temporary_directory/served" "$temporary_directory/again"
refuses one_bound_refused 'set together or not at all' \
    env QWEN_LAN_MAX_PROMPT_TOKENS=1000 "$stager" stage "$source_page" "$temporary_directory/again"
refuses zero_bound_refused 'must be a positive integer' \
    env QWEN_LAN_MAX_PROMPT_TOKENS=0 QWEN_LAN_MAX_OUTPUT_TOKENS=200 \
    "$stager" stage "$source_page" "$temporary_directory/again"
refuses missing_source_refused 'carries no index.html' \
    "$stager" stage "$temporary_directory/absent" "$temporary_directory/again"

# A page missing the broker anchor can be copied unbounded and refuses a bound.
mkdir -p "$temporary_directory/anchorless"
printf '<html><head><title>x</title></head><body></body></html>\n' \
    >"$temporary_directory/anchorless/index.html"
"$stager" stage "$temporary_directory/anchorless" "$temporary_directory/anchorless-out" >/dev/null
report anchorless_page_copies_unbounded
refuses anchorless_page_refuses_a_bound 'qwen-web-broker meta lines' \
    env QWEN_LAN_MAX_PROMPT_TOKENS=1000 QWEN_LAN_MAX_OUTPUT_TOKENS=200 \
    "$stager" stage "$temporary_directory/anchorless" "$temporary_directory/anchorless-out"

# read: forged shapes a hand could write.
forged=$temporary_directory/forged.html
sed '/^<meta name="qwen-lan-max-prompt-tokens"/p' \
    "$temporary_directory/served/index.html" >"$forged"
refuses duplicate_tag_refused 'more than once' "$stager" read "$forged"
sed 's/content="1000"/content="1000"><meta name="qwen-lan-max-prompt-tokens" content="9000"/' \
    "$temporary_directory/served/index.html" >"$forged"
refuses inline_second_tag_refused 'a form this launch never writes' "$stager" read "$forged"
sed '/qwen-lan-max-output-tokens/d' "$temporary_directory/served/index.html" >"$forged"
refuses one_tag_without_the_other_refused 'without the other' "$stager" read "$forged"
sed 's/content="1000"/content="-5"/' "$temporary_directory/served/index.html" >"$forged"
refuses negative_value_refused 'not a positive integer' "$stager" read "$forged"
sed 's/content="1000"/content="0100"/' "$temporary_directory/served/index.html" >"$forged"
refuses leading_zero_refused 'not a positive integer' "$stager" read "$forged"
sed 's/^<meta name="qwen-lan-max-prompt-tokens" content="1000">$/<meta content="1000" name="qwen-lan-max-prompt-tokens">/' \
    "$temporary_directory/served/index.html" >"$forged"
refuses reordered_attributes_refused 'a form this launch never writes' "$stager" read "$forged"
refuses missing_page_refused 'page is not a file' "$stager" read "$temporary_directory/absent.html"
refuses unknown_command_refused 'usage:' "$stager" frobnicate "$forged"
printf 'test-stage-webui-page: all checks passed\n'
