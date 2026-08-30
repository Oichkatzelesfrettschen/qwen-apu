#!/bin/sh
set -eu

if [ "$#" -ne 0 ]; then
    printf 'usage: %s\n' "$0" >&2
    exit 2
fi

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
temporary_directory=$(mktemp -d)
trap 'rm -rf "$temporary_directory"' EXIT HUP INT TERM
fake_bin=$temporary_directory/bin
destination_directory=$temporary_directory/model
curl_marker=$temporary_directory/curl-invoked
mkdir -p "$fake_bin" "$destination_directory"

for command_name in renice taskset ionice; do
    printf '#!/bin/sh\nexit 0\n' >"$fake_bin/$command_name"
    chmod +x "$fake_bin/$command_name"
done

cat >"$fake_bin/wc" <<'EOF'
#!/bin/sh
printf '5214561328\n'
EOF
cat >"$fake_bin/sha256sum" <<'EOF'
#!/bin/sh
printf '3f067a1b943cf162f2b8f8588f6cf5824bd5b4c7d1d88d87164b9ca123616549  %s\n' "$1"
EOF
cat >"$fake_bin/curl" <<'EOF'
#!/bin/sh
: >"${QWEN_TEST_CURL_MARKER:?}"
exit 99
EOF
chmod +x "$fake_bin/wc" "$fake_bin/sha256sum" "$fake_bin/curl"

partial_path=$destination_directory/sd_turbo.safetensors.part
printf 'fixture bytes\n' >"$partial_path"

if PATH=$fake_bin:$PATH QWEN_TEST_CURL_MARKER=$curl_marker \
    "$script_directory/download-sd-turbo.sh" "$destination_directory" \
    >"$temporary_directory/stdout" 2>"$temporary_directory/stderr"
then
    test_status=accepted
else
    test_status=refused
fi

[ -f "$destination_directory/sd_turbo.safetensors" ] || test_status=refused
[ ! -e "$partial_path" ] || test_status=refused
[ ! -e "$curl_marker" ] || test_status=refused
grep -q '^artifact_status=verified_complete_partial ' "$temporary_directory/stdout" ||
    test_status=refused

printf 'complete_partial_promoted_before_curl=%s\n' "$test_status"
[ "$test_status" = accepted ]
printf 'test-download-sd-turbo=accepted\n'
