#!/bin/sh
set -eu

# Print one environment value the generated MCP configuration hands a wrapped
# server.
#
# A preset section names its configuration through LLAMA_ARG_MCP_SERVERS_CONFIG
# and carries none of the policy itself, so a reader that greps the INI for
# QWEN_WEB_SEARXNG_URL finds nothing while the child is configured correctly.
# The path resolves through the section, the JSON is parsed rather than
# grepped, and an absent key prints nothing and exits 1, so a caller
# distinguishes an unset key from an empty value.
#
# usage: read-mcp-server-env.sh PRESET SECTION SERVER KEY

if [ "$#" -ne 4 ]; then
    printf 'usage: %s PRESET SECTION SERVER KEY\n' "$0" >&2
    exit 2
fi

preset=$1
section=$2
server=$3
key=$4

if [ ! -r "$preset" ]; then
    printf 'the preset is unreadable: %s\n' "$preset" >&2
    exit 2
fi

configuration=$(awk -v wanted="$section" '
    /^[[:space:]]*\[/ {
        current = $0
        sub(/^[[:space:]]*\[/, "", current)
        sub(/\][[:space:]]*$/, "", current)
        next
    }
    current != wanted { next }
    {
        separator = index($0, "=")
        if (separator == 0) next
        name = substr($0, 1, separator - 1)
        value = substr($0, separator + 1)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", name)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
        if (name == "LLAMA_ARG_MCP_SERVERS_CONFIG") configuration = value
    }
    END {
        if (configuration == "") exit 1
        print configuration
    }
' "$preset") || {
    printf 'section %s names no MCP configuration in %s\n' "$section" "$preset" >&2
    exit 1
}

if [ ! -r "$configuration" ]; then
    printf 'the MCP configuration is unreadable: %s\n' "$configuration" >&2
    exit 1
fi

python3 - "$configuration" "$server" "$key" <<'PY'
import json
import sys

path, server, key = sys.argv[1], sys.argv[2], sys.argv[3]
with open(path, "r", encoding="utf-8") as handle:
    document = json.load(handle)
environment = document.get("mcpServers", {}).get(server, {}).get("env", {})
if key not in environment:
    sys.stderr.write("server %s carries no %s\n" % (server, key))
    raise SystemExit(1)
sys.stdout.write(str(environment[key]) + "\n")
PY
