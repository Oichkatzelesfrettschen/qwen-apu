#!/bin/sh
set -eu

# A parallel range fetch assembles a file from parts, so its failure mode is a
# plausible file rather than an error: a part short by one byte concatenates
# into something that loads and answers wrongly. These checks run the fetcher
# against a local server that honours ranges and compare the assembled digest
# with the origin's, across several connection counts including one that does
# not divide the length evenly.

if [ "$#" -ne 0 ]; then
    printf 'usage: %s\n' "$0" >&2
    exit 2
fi

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
temporary_directory=$(mktemp -d)
server_pid=''
cleanup() {
    [ -n "$server_pid" ] && kill "$server_pid" 2>/dev/null
    rm -rf "$temporary_directory"
}
trap cleanup EXIT HUP INT TERM
failures=0

report() {
    printf '%s=%s\n' "$1" "$2"
    [ "$2" = accepted ] || failures=$((failures + 1))
}

document_root=$temporary_directory/www
mkdir -p "$document_root" "$temporary_directory/dest"
# A length that no connection count divides evenly, so the final part is short
# by construction and the assembly is exercised at its boundary.
python3 -c '
import sys
with open(sys.argv[1], "wb") as handle:
    handle.write(bytes((index * 7 + 13) % 256 for index in range(1000003)))
' "$document_root/model.gguf"

server_script=$temporary_directory/range-server.py
cat >"$server_script" <<'PYTHON'
import http.server
import os
import sys

root, port_file = sys.argv[1], sys.argv[2]


class RangeHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *arguments, **keywords):
        super().__init__(*arguments, directory=root, **keywords)

    def send_head(self):
        requested = self.headers.get("Range")
        path = self.translate_path(self.path)
        if not requested or not os.path.isfile(path):
            self._limit = None
            return super().send_head()
        size = os.path.getsize(path)
        first, _, last = requested.partition("=")[2].partition("-")
        first = int(first)
        last = int(last) if last else size - 1
        handle = open(path, "rb")
        handle.seek(first)
        self._limit = last - first + 1
        self.send_response(206)
        self.send_header("Content-Type", "application/octet-stream")
        self.send_header("Content-Length", str(self._limit))
        self.send_header("Content-Range", f"bytes {first}-{last}/{size}")
        self.send_header("Accept-Ranges", "bytes")
        self.end_headers()
        return handle

    def copyfile(self, source, outputfile):
        limit = getattr(self, "_limit", None)
        if limit is None:
            return super().copyfile(source, outputfile)
        outputfile.write(source.read(limit))

    def end_headers(self):
        if not self.headers.get("Range"):
            self.send_header("Accept-Ranges", "bytes")
        super().end_headers()

    def log_message(self, *arguments):
        pass


server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), RangeHandler)
with open(port_file, "w") as handle:
    handle.write(str(server.server_address[1]))
server.serve_forever()
PYTHON

port_file=$temporary_directory/port
python3 "$server_script" "$document_root" "$port_file" &
server_pid=$!
attempt=0
while [ "$attempt" -lt 100 ]; do
    [ -s "$port_file" ] && break
    attempt=$((attempt + 1))
    sleep 0.1
done
if [ ! -s "$port_file" ]; then
    printf 'the range server did not start\n' >&2
    exit 1
fi
port=$(cat "$port_file")

# The fetcher builds its URL from the publisher's host, so the test substitutes
# the local one and changes nothing else.
fetcher=$temporary_directory/fetch-candidate-artifact.sh
sed "s|^source_url=https://huggingface.co/.*|source_url=http://127.0.0.1:$port/\$artifact_name|" \
    "$script_directory/fetch-candidate-artifact.sh" >"$fetcher"
chmod +x "$fetcher"

origin_digest=$(sha256sum "$document_root/model.gguf" | awk '{ print $1 }')

for connections in 1 2 4 7; do
    rm -rf "$temporary_directory/dest"
    mkdir -p "$temporary_directory/dest"
    line=$(QWEN_FETCH_CONNECTIONS=$connections "$fetcher" owner/repo revision \
        model.gguf "$temporary_directory/dest" 2>&1) || {
            report "connections_$connections" rejected
            printf '%s\n' "$line" >&2
            continue
        }
    assembled=$(sha256sum "$temporary_directory/dest/model.gguf" | awk '{ print $1 }')
    mode=$(printf '%s' "$line" | sed -n 's/.*mode=\([a-z]*\).*/\1/p')
    expected_mode=parallel
    [ "$connections" = 1 ] && expected_mode=single
    if [ "$assembled" = "$origin_digest" ] && [ "$mode" = "$expected_mode" ]; then
        report "connections_$connections" accepted
    else
        report "connections_$connections" rejected
        printf 'digest %s against origin %s, mode %s expected %s\n' \
            "$assembled" "$origin_digest" "$mode" "$expected_mode" >&2
    fi
done

# A retained artifact is re-observed rather than refetched, and a file that has
# changed under a recorded digest is refused rather than served.
line=$(QWEN_FETCH_CONNECTIONS=4 "$fetcher" owner/repo revision model.gguf \
    "$temporary_directory/dest" 2>&1)
case $line in
    *artifact_status=retained*) report retained_artifact_reobserved accepted ;;
    *) report retained_artifact_reobserved rejected ;;
esac

printf 'tampered\n' >>"$temporary_directory/dest/model.gguf"
if QWEN_FETCH_CONNECTIONS=4 "$fetcher" owner/repo revision model.gguf \
        "$temporary_directory/dest" >/dev/null 2>&1; then
    report tampered_artifact_refused rejected
else
    report tampered_artifact_refused accepted
fi

if [ "$failures" -eq 0 ]; then
    printf 'fetch_candidate_artifact=accepted\n'
    exit 0
fi
printf 'fetch_candidate_artifact=rejected failures=%s\n' "$failures" >&2
exit 1
