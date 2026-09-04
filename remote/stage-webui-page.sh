#!/bin/sh
# The served copy of the fallback page, generated from the launch's own bounds.
#
# webui/index.html reads `qwen-lan-max-prompt-tokens` and
# `qwen-lan-max-output-tokens` meta tags to count a prompt before sending and to
# narrow its own max_tokens, and qwen-capacity-policy.sh reads
# QWEN_LAN_MAX_PROMPT_TOKENS and QWEN_LAN_MAX_OUTPUT_TOKENS to clamp --ctx-size
# and set --n-predict. The checked-in page carries neither tag, because the
# bound is a property of a launch rather than of the file, so this script
# writes the copy the server serves: the source directory copied whole into a
# staging directory beside the target and renamed into place, with the two tags
# inserted after the `qwen-web-broker` meta where the launch names bounds and
# absent where it names none. The tags describe; the server enforces. A page
# whose tags a browser strips or edits gains nothing, since --ctx-size and
# --n-predict are what refuse the request.
#
# `read` prints the tags a page carries, in the form the policy compares against
# its own bounds, and refuses a page carrying one tag without the other, a
# duplicate tag, or a value that is not a positive integer. `stage` refuses a
# source page that already carries either tag: the value must come from the
# launch and from nowhere else, so a tag in the source is a claim the launch
# never made.
#
# usage: stage-webui-page.sh stage SOURCE_DIRECTORY OUTPUT_DIRECTORY
#        stage-webui-page.sh read INDEX_HTML
#   QWEN_LAN_MAX_PROMPT_TOKENS   the prompt bound to write, with the next
#   QWEN_LAN_MAX_OUTPUT_TOKENS   the output bound to write; both or neither
#
# stage prints `staged_page=DIR page_sha256=HEX prompt_bound=N|- output_bound=N|-`.
# read prints `prompt_bound=N|- output_bound=N|-`.
set -eu

usage() {
    sed -n '22,30p' "$0" >&2
    exit 2
}

# read_bound NAME INDEX_HTML -> the one value the named tag carries, or `-`.
read_bound() {
    bound_name=$1
    bound_page=$2
    bound_values=$(sed -n \
        's/^[[:space:]]*<meta name="'"$bound_name"'" content="\([^"]*\)">[[:space:]]*$/\1/p' \
        "$bound_page")
    bound_count=$(printf '%s' "$bound_values" | grep -c . || true)
    # A tag on a line with other markup, or with any other attribute layout,
    # is one this script never wrote and the page would read anyway.
    bound_mentions=$(grep -c "name=\"$bound_name\"" "$bound_page" || true)
    case $bound_count in
        0)
            if [ "$bound_mentions" -ne 0 ]; then
                printf '%s carries a %s tag in a form this launch never writes\n' \
                    "$bound_page" "$bound_name" >&2
                exit 2
            fi
            printf -- '-\n'
            ;;
        1)
            if [ "$bound_mentions" -ne 1 ]; then
                printf '%s carries %s more than once\n' "$bound_page" "$bound_name" >&2
                exit 2
            fi
            case $bound_values in
                *[!0-9]* | 0 | 0*)
                    printf '%s carries %s=%s, which is not a positive integer\n' \
                        "$bound_page" "$bound_name" "$bound_values" >&2
                    exit 2
                    ;;
            esac
            printf '%s\n' "$bound_values"
            ;;
        *)
            printf '%s carries %s more than once\n' "$bound_page" "$bound_name" >&2
            exit 2
            ;;
    esac
}

read_page() {
    page=$1
    [ -f "$page" ] || { printf 'page is not a file: %s\n' "$page" >&2; exit 2; }
    page_prompt=$(read_bound qwen-lan-max-prompt-tokens "$page")
    page_output=$(read_bound qwen-lan-max-output-tokens "$page")
    if { [ "$page_prompt" = - ] && [ "$page_output" != - ]; } ||
        { [ "$page_prompt" != - ] && [ "$page_output" = - ]; }; then
        printf '%s carries one LAN bound tag without the other: prompt=%s output=%s\n' \
            "$page" "$page_prompt" "$page_output" >&2
        exit 2
    fi
    printf 'prompt_bound=%s output_bound=%s\n' "$page_prompt" "$page_output"
}

[ $# -ge 1 ] || usage
command=$1
shift
case $command in
    read)
        [ $# -eq 1 ] || usage
        read_page "$1"
        exit 0
        ;;
    stage) [ $# -eq 2 ] || usage ;;
    *) usage ;;
esac

source_directory=$1
output_directory=$2
prompt_bound=${QWEN_LAN_MAX_PROMPT_TOKENS:-}
output_bound=${QWEN_LAN_MAX_OUTPUT_TOKENS:-}

[ -f "$source_directory/index.html" ] || {
    printf 'source directory carries no index.html: %s\n' "$source_directory" >&2
    exit 2
}
for bound_pair in "QWEN_LAN_MAX_PROMPT_TOKENS=$prompt_bound" \
    "QWEN_LAN_MAX_OUTPUT_TOKENS=$output_bound"; do
    case ${bound_pair#*=} in
        '') ;;
        *[!0-9]* | 0 | 0*)
            printf '%s must be a positive integer: %s\n' \
                "${bound_pair%%=*}" "${bound_pair#*=}" >&2
            exit 2
            ;;
    esac
done
if { [ -n "$prompt_bound" ] && [ -z "$output_bound" ]; } ||
    { [ -z "$prompt_bound" ] && [ -n "$output_bound" ]; }; then
    printf 'QWEN_LAN_MAX_PROMPT_TOKENS and QWEN_LAN_MAX_OUTPUT_TOKENS are set together or not at all\n' >&2
    exit 2
fi

# The source is the checked-in page and carries no bound; a bound found there
# is a claim the launch never made.
source_bounds=$(read_page "$source_directory/index.html")
if [ "$source_bounds" != 'prompt_bound=- output_bound=-' ]; then
    printf 'source page already carries LAN bound tags (%s); the launch alone writes them: %s\n' \
        "$source_bounds" "$source_directory/index.html" >&2
    exit 2
fi
anchor_count=$(grep -c '^<meta name="qwen-web-broker" content="[^"]*">$' \
    "$source_directory/index.html" || true)
if [ -n "$prompt_bound" ] && [ "$anchor_count" -ne 1 ]; then
    printf 'source page carries %s qwen-web-broker meta lines where the bound tags are inserted after exactly one\n' \
        "$anchor_count" >&2
    exit 2
fi

output_parent=$(dirname "$output_directory")
mkdir -p "$output_parent"
staging_directory=$(mktemp -d "$output_parent/.webui-staging.XXXXXX")
trap 'rm -rf "$staging_directory"' EXIT HUP INT TERM
# cp -R over the directory's contents keeps roster.json and every other file
# the page fetches beside itself; the page is then rewritten in place.
cp -R "$source_directory/." "$staging_directory/"
if [ -n "$prompt_bound" ]; then
    awk -v prompt="$prompt_bound" -v output="$output_bound" '
        { print }
        /^<meta name="qwen-web-broker" content="[^"]*">$/ {
            print "<meta name=\"qwen-lan-max-prompt-tokens\" content=\"" prompt "\">"
            print "<meta name=\"qwen-lan-max-output-tokens\" content=\"" output "\">"
        }' "$source_directory/index.html" >"$staging_directory/index.html"
fi
# The staged page is read back through the same reader the policy uses, so
# what this script prints is what the policy will find.
staged_bounds=$(read_page "$staging_directory/index.html")
expected_bounds="prompt_bound=${prompt_bound:--} output_bound=${output_bound:--}"
if [ "$staged_bounds" != "$expected_bounds" ]; then
    printf 'staged page reads %s where the launch wrote %s\n' \
        "$staged_bounds" "$expected_bounds" >&2
    exit 1
fi
rm -rf "$output_directory"
mv "$staging_directory" "$output_directory"
trap - EXIT HUP INT TERM
printf 'staged_page=%s page_sha256=%s %s\n' "$output_directory" \
    "$(sha256sum "$output_directory/index.html" | cut -d ' ' -f 1)" "$expected_bounds"
