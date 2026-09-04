#!/bin/sh
set -eu

# Benchmark every servable checkpoint through the graded suite twice: once
# through the API with the web lane off, the way remote/run-quality-roster.sh
# already does, and once through the served fallback page with the per-turn
# Web toggle on, where a web-enabled router section reaches the checkpoint.
# The page is the executor a web search runs through, so the web-on arm drives
# it with remote/run-conversational-web-arm.py rather than adding a `tools`
# body to a direct API call: that script sends one text prompt per row through
# remote/web-mcp/drive-fallback-page.py, auto-approves the single dialog a
# proposed search opens the way remote/admit-web-router-live.sh does, and
# grades the settled reply with the same grade() the API arm uses.
#
# remote/web-profiles.tsv joins a profile to one checkpoint and states whether
# its execution_policy authorizes a section (validator-gated); the served
# roster (GET /v1/models) is the other half of the join, since the router only
# emits an authorized section under QWEN_WEB_AUTHORIZER_READY=1.
# remote/resolve-web-profile.py answers that join before any device time is
# spent, so a checkpoint the ledger does not authorize, or authorizes but the
# live listener does not serve, records web_on=unavailable with its reason
# rather than being skipped silently.
#
# Both arms grade the suite's rows in the row file's own order: a row's grade
# is conditioned on the request sequence a warm KV cache or prefix reuse
# carries forward (CLAUDE.md's evidence discipline), so an order difference
# between the two arms would confound the web-on delta with a sequence effect.
# The web-on arm excludes rows whose attachment is `image` or `tools`, because
# the page's turn driver sends one text prompt through the chat box and offers
# no path to attach an image or declare a tool set; run-conversational-web-arm.py
# records those rows as skipped rather than driving them through an unrelated
# transport.
#
# usage: run-conversational-suite.sh OUTPUT_DIRECTORY [MODEL_ID...]
# environment:
#   QWEN_CONVERSATIONAL_CATEGORIES               comma-separated subset, default all
#   QWEN_CONVERSATIONAL_MAX_TOKENS               web-off token budget, default 1024
#   QWEN_CONVERSATIONAL_THINKING                 on|off, default off
#   QWEN_CONVERSATIONAL_LONG_CONTEXT_CHARACTERS  default 24000
#   QWEN_CONVERSATIONAL_MODELS                   override the registry's servable ids
#   QWEN_CONVERSATIONAL_SUITE                    default remote/quality-suite.tsv
#   QWEN_WEB_PROFILES                            default remote/web-profiles.tsv
#   QWEN_SERVER_PORT                             router port, default 8080
#   QWEN_WEB_BROKER_PORT                         broker port, default 8571
#   QWEN_WEB_API_KEY_FILE                        bearer file the page sets; required
#                                                 for any model whose web-on arm runs
#   QWEN_CONVERSATIONAL_PAGE_DRIVER              default remote/web-mcp/drive-fallback-page.py
#   QWEN_CONVERSATIONAL_LOAD_TIMEOUT             default 180
#   QWEN_CONVERSATIONAL_DIALOG_TIMEOUT           default 300
#   QWEN_CONVERSATIONAL_TURN_TIMEOUT             default 300
#   QWEN_CONVERSATIONAL_CHROMIUM                 default chromium

if [ "$#" -lt 1 ]; then
    printf 'usage: %s OUTPUT_DIRECTORY [MODEL_ID...]\n' "$0" >&2
    exit 2
fi

output_directory=$1
shift

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
endpoint=http://127.0.0.1:${QWEN_SERVER_PORT:-8080}
broker_origin=http://127.0.0.1:${QWEN_WEB_BROKER_PORT:-8571}
suite_runner=$script_directory/run-quality-suite.py
web_arm_runner=$script_directory/run-conversational-web-arm.py
summarizer=$script_directory/summarize-conversational-suite.py
resolver=$script_directory/resolve-web-profile.py
registry_script=$script_directory/model-registry.sh
categories=${QWEN_CONVERSATIONAL_CATEGORIES:-}
max_tokens=${QWEN_CONVERSATIONAL_MAX_TOKENS:-1024}
thinking=${QWEN_CONVERSATIONAL_THINKING:-off}
long_context_characters=${QWEN_CONVERSATIONAL_LONG_CONTEXT_CHARACTERS:-24000}
suite_path=${QWEN_CONVERSATIONAL_SUITE:-$script_directory/quality-suite.tsv}
web_profiles=${QWEN_WEB_PROFILES:-$script_directory/web-profiles.tsv}
page_driver=${QWEN_CONVERSATIONAL_PAGE_DRIVER:-$script_directory/web-mcp/drive-fallback-page.py}
api_key_file=${QWEN_WEB_API_KEY_FILE:-}
load_timeout=${QWEN_CONVERSATIONAL_LOAD_TIMEOUT:-180}
dialog_timeout=${QWEN_CONVERSATIONAL_DIALOG_TIMEOUT:-300}
turn_timeout=${QWEN_CONVERSATIONAL_TURN_TIMEOUT:-300}
chromium=${QWEN_CONVERSATIONAL_CHROMIUM:-chromium}

for required in "$suite_runner" "$web_arm_runner" "$summarizer" "$resolver"; do
    if [ ! -x "$required" ]; then
        printf 'run-conversational-suite: required script is absent or not executable: %s\n' \
            "$required" >&2
        exit 1
    fi
done
if [ ! -r "$suite_path" ]; then
    printf 'run-conversational-suite: suite is unreadable: %s\n' "$suite_path" >&2
    exit 1
fi
if [ ! -r "$web_profiles" ]; then
    printf 'run-conversational-suite: web-profiles ledger is unreadable: %s\n' "$web_profiles" >&2
    exit 1
fi

case $max_tokens in
    '' | *[!0-9]* | 0)
        printf 'token budget must be a positive integer: %s\n' "$max_tokens" >&2
        exit 2
        ;;
esac
case $thinking in
    on | off) ;;
    *)
        printf 'thinking must be on or off: %s\n' "$thinking" >&2
        exit 2
        ;;
esac

if [ "$#" -ge 1 ]; then
    model_ids=$*
else
    model_ids=$("$registry_script" servable-ids)
fi
if [ -z "$model_ids" ]; then
    printf 'run-conversational-suite: no model ids selected\n' >&2
    exit 1
fi

served_listing=$(curl -s --max-time 30 "$endpoint/v1/models") || {
    printf 'run-conversational-suite: the endpoint is unreachable: %s\n' "$endpoint" >&2
    exit 1
}
served_ids=$(printf '%s' "$served_listing" | python3 -c '
import json
import sys

document = json.load(sys.stdin)
print(",".join(entry.get("id", "") for entry in document.get("data", [])))
')

for model_id in $model_ids; do
    if ! printf '%s\n' "$served_ids" | tr ',' '\n' | grep -qx "$model_id"; then
        printf 'run-conversational-suite: the listener does not hold registry row %s\n' \
            "$model_id" >&2
        printf 'regenerate the preset file and relaunch before grading\n' >&2
        exit 1
    fi
done

mkdir -p "$output_directory"
manifest=$output_directory/manifest.tsv
printf 'model_id\tweb_off_json\tweb_on_status\tweb_on_reason\tweb_on_json\n' >"$manifest"

failed_arms=0
for model_id in $model_ids; do
    printf 'arm=%s leg=web-off thinking=%s max_tokens=%s\n' "$model_id" "$thinking" "$max_tokens"
    off_json=$output_directory/$model_id.web-off.json
    off_log=$output_directory/$model_id.web-off.log

    set -- "$endpoint" "$off_json" --model "$model_id" --suite "$suite_path" \
        --thinking "$thinking" --max-tokens "$max_tokens" \
        --long-context-characters "$long_context_characters"
    if [ -n "$categories" ]; then
        set -- "$@" --categories "$categories"
    fi
    if "$suite_runner" "$@" >"$off_log" 2>&1; then
        off_status=completed
    else
        off_status=failed
        failed_arms=$((failed_arms + 1))
    fi
    tail -6 "$off_log"
    printf 'arm=%s leg=web-off status=%s\n' "$model_id" "$off_status"

    resolution=$("$resolver" "$model_id" --ledger "$web_profiles" --served-ids "$served_ids")
    status=$(printf '%s' "$resolution" | cut -f1)
    second=$(printf '%s' "$resolution" | cut -f2)
    third=$(printf '%s' "$resolution" | cut -f3)

    on_json=-
    reason=-
    if [ "$status" = available ]; then
        profile_id=$second
        printf 'arm=%s leg=web-on profile=%s max_fetches=%s\n' "$model_id" "$profile_id" "$third"
        if [ -z "$api_key_file" ]; then
            printf 'run-conversational-suite: %s reaches web section %s but ' \
                "$model_id" "$profile_id" >&2
            printf 'QWEN_WEB_API_KEY_FILE names no bearer file\n' >&2
            exit 1
        fi
        on_json=$output_directory/$model_id.web-on.json
        on_log=$output_directory/$model_id.web-on.log
        set -- "$endpoint" "$profile_id" "$on_json" --suite "$suite_path" \
            --long-context-characters "$long_context_characters" \
            --page-driver "$page_driver" --broker-origin "$broker_origin" \
            --api-key-file "$api_key_file" \
            --load-timeout "$load_timeout" --dialog-timeout "$dialog_timeout" \
            --turn-timeout "$turn_timeout" --chromium "$chromium"
        if [ -n "$categories" ]; then
            set -- "$@" --categories "$categories"
        fi
        if "$web_arm_runner" "$@" >"$on_log" 2>&1; then
            on_status=completed
        else
            on_status=failed
            failed_arms=$((failed_arms + 1))
        fi
        tail -6 "$on_log"
        printf 'arm=%s leg=web-on status=%s\n' "$model_id" "$on_status"
    else
        reason=$second
        printf 'arm=%s leg=web-on status=unavailable reason=%s detail=%s\n' \
            "$model_id" "$reason" "$third"
    fi

    printf '%s\t%s\t%s\t%s\t%s\n' "$model_id" "$off_json" "$status" "$reason" "$on_json" \
        >>"$manifest"
    printf '\n'
done

"$summarizer" "$manifest" "$output_directory"

printf '\n'
cat "$output_directory/conversational-summary.tsv"
printf 'conversational_suite=%s arms=%s failed=%s output=%s\n' \
    "$([ "$failed_arms" -eq 0 ] && printf completed || printf failed)" \
    "$(printf '%s\n' "$model_ids" | wc -w | tr -d ' ')" \
    "$failed_arms" "$output_directory"
[ "$failed_arms" -eq 0 ]
