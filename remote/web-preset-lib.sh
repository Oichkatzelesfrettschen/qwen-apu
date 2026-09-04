# shellcheck shell=sh
# shellcheck disable=SC2154  # every function reads caller-set row variables by name
# Shared web-profile validation and MCP configuration emission.
#
# Two generators read remote/web-profiles.tsv and turn one row into one router
# preset section: remote/build-web-presets.sh emits the web-only preset that
# remote/qwen-web-launch.sh serves, and remote/build-router-presets.sh folds the
# validator-gated rows into the ordinary roster preset so one router serves both.
# A second copy of these rules would let the two files diverge on what a ledger
# row means, so both source this file and the rules have one home.
#
# This file is sourced rather than executed. Every function reads the caller's
# variables by name and ends the run with `exit 1` on a refusal, which is the
# behavior a generator wants: a ledger the rules refuse leaves the previously
# generated preset tree standing.
#
# The caller sets these before calling anything here:
#   web_provider              the one backend the file serves
#   profile_id, model_id      the row being read, for the refusal text
#   mcp_server_program        remote/web-mcp/server.py
#   web_state_directory       QWEN_WEB_STATE_DIR
#   token_key_file            the broker signing key path, or empty
#   search_key_file           the Exa key file path under provider exa
#   fake_fixtures             the recorded response file under provider fake
#   searxng_language, searxng_safesearch, searxng_allow_remote
#   mcp_timeout_ms            the per-call deadline llama-server applies
#   image_profile_id and the image_* names, where an image row emits

# A JSON string value carries the path verbatim, so a quote or a backslash in it
# would change the parsed value and a control character would place a byte in
# the string that RFC 8259 section 7 admits only as an escape. Refusing the
# character keeps the emitted file parseable and a faithful record of the path
# the operator named.
require_json_safe_path() {
    json_path_name=$1
    json_path_value=$2
    case $json_path_value in
        *'"'* | *'\'*)
            printf '%s holds a double quote or backslash, which JSON escaping would reinterpret: %s\n' \
                "$json_path_name" "$json_path_value" >&2
            exit 1
            ;;
        *[[:cntrl:]]*)
            printf '%s holds a control character, which JSON admits only as an escape: %s\n' \
                "$json_path_name" "$json_path_value" >&2
            exit 1
            ;;
    esac
}

# A profile's search policy is the ledger's own claim about which backend
# serves it and what that backend is asked for, so it is validated for every
# row whatever the row's execution_policy, the way the depth and tier rules
# are. `provider` must equal the generator's own QWEN_WEB_PROVIDER: the head
# marker records one provider for the file and qwen-web-launch.sh reads it, so
# a row naming another backend would emit a section the launch serves under a
# provider the ledger never claimed. A category is a name in the instance's
# settings.yml rather than an engine list, and minimum_results is the count of
# validated results below which the fallback category runs, so it cannot exceed
# the row's own max_results. server.py validates the same four values again in
# SearXNGProvider.__init__ before the first request.
require_search_policy() {
    search_policy_profile=$1
    search_policy_provider=$2
    search_policy_primary=$3
    search_policy_fallback=$4
    search_policy_minimum=$5
    search_policy_max_results=$6
    search_policy_url=$7
    if [ "$search_policy_provider" != "$web_provider" ]; then
        printf 'profile %s names provider %s where the run serves %s\n' \
            "$search_policy_profile" "${search_policy_provider:-<absent>}" \
            "$web_provider" >&2
        exit 1
    fi
    if [ "$search_policy_provider" != searxng ]; then
        for search_policy_field in "$search_policy_primary" \
            "$search_policy_fallback" "$search_policy_minimum" \
            "$search_policy_url"; do
            if [ "$search_policy_field" != '-' ]; then
                printf 'profile %s carries a search policy under provider %s, which reads none\n' \
                    "$search_policy_profile" "$search_policy_provider" >&2
                exit 1
            fi
        done
        return 0
    fi
    require_category "$search_policy_profile" primary_category \
        "$search_policy_primary" required
    require_category "$search_policy_profile" fallback_category \
        "$search_policy_fallback" optional
    require_canonical_integer minimum_results "$search_policy_minimum" \
        sentinel-refused "$search_policy_profile"
    if [ "$search_policy_minimum" -gt "$search_policy_max_results" ]; then
        printf 'profile %s names minimum_results %s above its max_results %s\n' \
            "$search_policy_profile" "$search_policy_minimum" \
            "$search_policy_max_results" >&2
        exit 1
    fi
    case $search_policy_url in
        http://127.0.0.1:* | http://127.0.0.1 | http://localhost:* | \
        http://localhost | https://127.0.0.1:* | https://127.0.0.1 | \
        https://localhost:* | https://localhost) ;;
        *)
            printf 'profile %s names searxng_url %s, and the instance is reached over loopback\n' \
                "$search_policy_profile" "${search_policy_url:-<absent>}" >&2
            exit 1
            ;;
    esac
    require_json_safe_path searxng_url "$search_policy_url"
}

require_category() {
    category_value=$3
    case $3 in
        '-')
            if [ "$4" = required ]; then
                printf 'profile %s names no %s, which every searxng row carries\n' \
                    "$1" "$2" >&2
                exit 1
            fi
            ;;
        '' | *[!a-z0-9._-]* | [!a-z0-9]*)
            printf 'profile %s carries %s %s, which holds a character outside a category name\n' \
                "$1" "$2" "${3:-<absent>}" >&2
            exit 1
            ;;
    esac
    if [ "$category_value" != '-' ] && [ "${#category_value}" -gt 64 ]; then
        printf 'profile %s carries %s longer than 64 characters: %s\n' \
            "$1" "$2" "$category_value" >&2
        exit 1
    fi
}

# The MCP inputs describe a configuration file, so a ledger whose every row is
# refused or ui-mediated writes none and needs none. The requirement runs at the
# first row that writes one, which keeps an offline or manual ledger generating
# without a server program and a provider key it never reaches, and keeps the
# refusal on the row that would have been misconfigured by omission.
#
# The provider decides which input backs the emitted section: `exa` reaches
# the network and requires QWEN_WEB_SEARCH_KEY_FILE, a readable key file the
# generator's own input keeps its name for since every caller of this script
# already spells it that way; `fake` reaches no network and requires
# QWEN_WEB_FAKE_FIXTURES instead, a readable regular file of recorded
# responses; `searxng` reaches an unauthenticated instance and requires
# an instance URL and a category policy from the profile row, so it holds no
# secret at all and reads no key file.
# server.py's settings_from_environment reads QWEN_WEB_EXA_KEY_FILE rather than
# QWEN_WEB_SEARCH_KEY_FILE, so the emitted section renames that one value at
# the JSON boundary while the shell variable that carries it into this script
# keeps its established name; every SearXNG name crosses unchanged.
require_mcp_inputs() {
    if [ -z "$mcp_server_program" ]; then
        printf 'profile %s emits an MCP configuration and QWEN_WEB_MCP_SERVER names no server program\n' \
            "$profile_id" >&2
        exit 1
    fi
    require_json_safe_path QWEN_WEB_MCP_SERVER "$mcp_server_program"
    require_json_safe_path QWEN_WEB_STATE_DIR "$web_state_directory"
    if [ -n "$token_key_file" ]; then
        require_json_safe_path QWEN_WEB_TOKEN_KEY_FILE "$token_key_file"
    fi
    case $web_provider in
        fake)
            if [ -z "$fake_fixtures" ]; then
                printf 'profile %s emits an MCP configuration under provider fake and QWEN_WEB_FAKE_FIXTURES names no fixture file\n' \
                    "$profile_id" >&2
                exit 1
            fi
            if [ ! -f "$fake_fixtures" ] || [ ! -r "$fake_fixtures" ]; then
                printf 'QWEN_WEB_FAKE_FIXTURES names an unreadable regular file: %s\n' \
                    "$fake_fixtures" >&2
                exit 1
            fi
            require_json_safe_path QWEN_WEB_FAKE_FIXTURES "$fake_fixtures"
            ;;
        searxng)
            # The instance URL and the category policy come from the row that
            # `require_search_policy` has already validated, so this branch
            # reads the optional tuning the environment supplies beside it.
            require_json_safe_path QWEN_WEB_SEARXNG_LANGUAGE "$searxng_language"
            require_json_safe_path QWEN_WEB_SEARXNG_SAFESEARCH "$searxng_safesearch"
            require_json_safe_path QWEN_WEB_SEARXNG_ALLOW_REMOTE \
                "$searxng_allow_remote"
            ;;
        *)
            if [ -z "$search_key_file" ]; then
                printf 'profile %s emits an MCP configuration and QWEN_WEB_SEARCH_KEY_FILE names no provider key file\n' \
                    "$profile_id" >&2
                exit 1
            fi
            require_json_safe_path QWEN_WEB_SEARCH_KEY_FILE "$search_key_file"
            ;;
    esac
}

registry_field() {
    registry_field_row=$1
    registry_field_name=$2
    printf '%s\n' "$registry_field_row" | sed -n "s/^$registry_field_name=//p"
}

# A canonical positive decimal integer carries no leading zero and no sign.
# require_canonical_integer names the field and the profile on failure, so a
# malformed ledger or registry value stops the run where it is read rather than
# reaching a comparison that would coerce it.
require_canonical_integer() {
    require_field_name=$1
    require_field_value=$2
    require_sentinel=$3
    require_profile=$4
    if [ "$require_sentinel" = sentinel-admitted ] &&
        [ "$require_field_value" = '-' ]; then
        return 0
    fi
    case $require_field_value in
        '' | *[!0-9]*)
            printf 'profile %s carries non-numeric %s: %s\n' \
                "$require_profile" "$require_field_name" \
                "$require_field_value" >&2
            exit 1
            ;;
        0*)
            printf 'profile %s carries %s outside canonical positive decimal form: %s\n' \
                "$require_profile" "$require_field_name" \
                "$require_field_value" >&2
            exit 1
            ;;
    esac
}

# The profile_id becomes a path component, an INI section name, and the served
# alias. The vocabulary admits what all three read the same way, which also
# leaves `/`, `.`, `[`, `]`, and every control character outside it.
require_canonical_profile_id() {
    case $1 in
        '' | [!A-Za-z0-9]* | *[!A-Za-z0-9_-]*)
            printf 'profile_id %s lies outside the admitted vocabulary\n' "$1" >&2
            printf 'a profile_id starts with a letter or digit and holds letters, digits, underscores, and hyphens\n' >&2
            exit 1
            ;;
    esac
}

# One id per ledger. The seen list is a space-delimited string because the
# generator runs under POSIX sh, which holds no associative array.
seen_profile_ids=' '
require_unique_profile_id() {
    case $seen_profile_ids in
        *" $1 "*)
            printf 'ledger repeats profile_id %s\n' "$1" >&2
            printf 'two rows of one id write two sections of one name and one MCP configuration the second row owns\n' >&2
            exit 1
            ;;
    esac
    seen_profile_ids="$seen_profile_ids$1 "
}

# The ledger repeats three registry fields so a profile row reads whole, and the
# registry stays their authority. A divergence names the profile, the field, and
# both values, because either side may be the stale one and the reader decides.
require_ledger_matches_registry() {
    compare_field_name=$1
    compare_ledger_value=$2
    compare_registry_value=$3
    if [ "$compare_ledger_value" != "$compare_registry_value" ]; then
        printf 'profile %s carries %s %s where model %s carries %s\n' \
            "$profile_id" "$compare_field_name" "$compare_ledger_value" \
            "$model_id" "$compare_registry_value" >&2
        printf 'remote/models.tsv is the authority for this field; correct remote/web-profiles.tsv\n' >&2
        exit 1
    fi
}

# multi_source and max_fetches state one retrieval budget twice, so the ledger
# holds them as a biconditional: a second source exists exactly where a second
# fetch does. The emitted MCP configuration carries max_fetches alone, so a
# `no` row above one fetch would grant multi-source retrieval the ledger denies
# and a `yes` row at one fetch would claim a combination one fetch cannot make.
# The check runs for every row, whatever its execution_policy, because the
# ledger is one claimed policy document and a refused row states a budget a
# reader trusts.
require_multi_source_matches_fetches() {
    multi_source_value=$1
    multi_source_fetches=$2
    case $multi_source_value in
        yes | no) ;;
        *)
            printf 'profile %s carries multi_source %s, which is outside the vocabulary\n' \
                "$profile_id" "$multi_source_value" >&2
            printf 'admitted values are yes and no\n' >&2
            exit 1
            ;;
    esac
    if [ "$multi_source_fetches" -gt 1 ] && [ "$multi_source_value" != yes ]; then
        printf 'profile %s carries multi_source %s with max_fetches %s\n' \
            "$profile_id" "$multi_source_value" "$multi_source_fetches" >&2
        printf 'the emitted configuration grants every fetch, so a budget above one fetch reads multi_source yes\n' >&2
        exit 1
    fi
    if [ "$multi_source_fetches" -le 1 ] && [ "$multi_source_value" != no ]; then
        printf 'profile %s carries multi_source %s with max_fetches %s\n' \
            "$profile_id" "$multi_source_value" "$multi_source_fetches" >&2
        printf 'one fetch reaches one source, so a single-fetch budget reads multi_source no\n' >&2
        exit 1
    fi
}

# Write one profile's MCP server configuration. The caller decides which servers
# the object carries through emit_web_server and emit_image_server, and names the
# file as the first argument; the budgets and the search policy come from the row
# the caller is reading. A generated configuration carries key-file paths and
# never key contents, so a preset tree that persists in the state directory stays
# free of credential material and the child reads the key itself.
emit_web_mcp_configuration() {
    mcp_configuration_path=$1
    if [ "$emit_mcp_configuration" = 1 ]; then
        {
            printf '{\n'
            printf '  "mcpServers": {\n'
        } >"$mcp_configuration_path"
    fi
    if [ "$emit_web_server" = 1 ]; then
        {
            printf '    "web": {\n'
            printf '      "command": "python3",\n'
            printf '      "timeout_ms": %s,\n' "$mcp_timeout_ms"
            printf '      "args": [\n'
            printf '        "%s",\n' "$mcp_server_program"
            printf '        "--provider",\n'
            printf '        "%s"\n' "$web_provider"
            printf '      ],\n'
            printf '      "env": {\n'
            # The child imports its modules from the runtime tree, and an
            # import writes bytecode beside them: the appliance read
            # remote/web-mcp/__pycache__ as a stray at the next
            # check-runtime-tree.sh, since no sync ships or removes a file the
            # manifest never named. The setting travels in the configuration
            # rather than only in the session's environment, so the child
            # carries it whatever llama-server inherited.
            printf '        "PYTHONDONTWRITEBYTECODE": "1",\n'
            printf '        "QWEN_WEB_PROFILE": "%s",\n' "$profile_id"
            printf '        "QWEN_WEB_PROVIDER": "%s",\n' "$web_provider"
            printf '        "QWEN_WEB_MAX_RESULTS": "%s",\n' "$max_results"
            printf '        "QWEN_WEB_MAX_FETCHES_PER_SEARCH": "%s",\n' "$max_fetches"
            printf '        "QWEN_WEB_MAX_CHARS_PER_FETCH": "%s",\n' \
                "$max_chars_per_fetch"
            printf '        "QWEN_WEB_SEARCH_AUTH": "required",\n'
            case $web_provider in
                fake)
                    printf '        "QWEN_WEB_FAKE_FIXTURES": "%s",\n' \
                        "$fake_fixtures"
                    ;;
                searxng)
                    # The instance and the category policy come from the
                    # profile row, so the model supplies none of them and an
                    # operator changes them by editing the ledger. The three
                    # tuning names are emitted where the operator set them, so
                    # an unset one leaves server.py reading its own default
                    # rather than an empty string the child would interpret.
                    printf '        "QWEN_WEB_SEARXNG_URL": "%s",\n' \
                        "$row_searxng_url"
                    printf '        "QWEN_WEB_SEARXNG_PRIMARY_CATEGORY": "%s",\n' \
                        "$primary_category"
                    printf '        "QWEN_WEB_SEARXNG_FALLBACK_CATEGORY": "%s",\n' \
                        "$fallback_category"
                    printf '        "QWEN_WEB_SEARXNG_MINIMUM_RESULTS": "%s",\n' \
                        "$minimum_results"
                    if [ -n "$searxng_language" ]; then
                        printf '        "QWEN_WEB_SEARXNG_LANGUAGE": "%s",\n' \
                            "$searxng_language"
                    fi
                    if [ -n "$searxng_safesearch" ]; then
                        printf '        "QWEN_WEB_SEARXNG_SAFESEARCH": "%s",\n' \
                            "$searxng_safesearch"
                    fi
                    if [ -n "$searxng_allow_remote" ]; then
                        printf '        "QWEN_WEB_SEARXNG_ALLOW_REMOTE": "%s",\n' \
                            "$searxng_allow_remote"
                    fi
                    ;;
                *)
                    printf '        "QWEN_WEB_EXA_KEY_FILE": "%s",\n' \
                        "$search_key_file"
                    ;;
            esac
            if [ -n "$token_key_file" ]; then
                printf '        "QWEN_WEB_TOKEN_KEY_FILE": "%s",\n' "$token_key_file"
            fi
            printf '        "QWEN_WEB_STATE_DIR": "%s"\n' "$web_state_directory"
            printf '      }\n'
            printf '    }%s\n' "$web_server_separator"
        } >>"$mcp_configuration_path"
    fi
    # The image server names the language profile beside the image profile,
    # because the grant binds both: one approval authorizes one image profile
    # for the conversation running under one language profile, and
    # image_grant.enforce_image_authorization compares each against the section
    # that executed the call. The key file, the state directory, and the socket
    # travel as paths; the child reads each itself, so the preset carries no
    # signing key and no device state.
    if [ "$emit_image_server" = 1 ]; then
        {
            printf '    "image": {\n'
            printf '      "command": "python3",\n'
            printf '      "timeout_ms": %s,\n' "$image_mcp_timeout_ms"
            printf '      "args": [\n'
            printf '        "%s"\n' "$image_mcp_server"
            printf '      ],\n'
            printf '      "env": {\n'
            # image-mcp/server.py imports remote/image_protocol.py, which wrote
            # remote/__pycache__ into the runtime tree for the same reason.
            printf '        "PYTHONDONTWRITEBYTECODE": "1",\n'
            printf '        "QWEN_IMAGE_LANGUAGE_PROFILE": "%s",\n' "$profile_id"
            printf '        "QWEN_IMAGE_PROFILE": "%s",\n' "$image_profile_id"
            printf '        "QWEN_IMAGE_TOKEN_KEY_FILE": "%s",\n' \
                "$image_token_key_file"
            printf '        "QWEN_IMAGE_STATE_DIR": "%s",\n' \
                "$image_state_directory"
            printf '        "QWEN_IMAGE_SERVICE_SOCKET": "%s",\n' \
                "$image_service_socket"
            printf '        "QWEN_IMAGE_PROFILES_JSON": "%s",\n' \
                "$image_profiles_json"
            # llama-server reads timeout_ms as the per-call limit and the child
            # reads QWEN_IMAGE_MCP_TIMEOUT_S as its own socket deadline, so the
            # two are written from one value: an operator raising the router's
            # limit alone would leave the child cutting at its 360 second
            # default while the launch verified the larger number.
            printf '        "QWEN_IMAGE_MCP_TIMEOUT_S": "%s"\n' \
                "$((image_mcp_timeout_ms / 1000))"
            printf '      }\n'
            printf '    }\n'
        } >>"$mcp_configuration_path"
    fi
    if [ "$emit_mcp_configuration" = 1 ]; then
        {
            printf '  }\n'
            printf '}\n'
        } >>"$mcp_configuration_path"
    fi
}
