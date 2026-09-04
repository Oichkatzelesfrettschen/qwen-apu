#!/usr/bin/env python3
"""A SearXNG stand-in that answers the two routes the launch chain reads.

`GET /healthz` is what remote/qwen-webui-session.sh polls before it starts the
capacity server, and `GET /search?format=json` is the route `SearXNGProvider`
in remote/web-mcp/server.py sends its category query to. The answer carries the
`results`, `engines`, `score`, and `unresponsive_engines` fields that provider
maps, so a guard test drives the whole chain on a host holding no SearXNG
install and reaching no network.

`--results` states how many records each category answers with, which is what
lets a test place a category below a profile's `minimum_results`. `--fail-health`
answers `/healthz` with 503 while the process keeps running, the shape of an
instance that binds its port and never becomes usable. `--delay-ready` answers
503 until the given number of seconds have elapsed since the process started,
then 200, the shape of an instance still loading its engine set: a test reads
the session's status file inside that window to prove the pid and start time
land there before health succeeds. `--stall-health` sleeps inside the
`/healthz` handler before answering 200, the shape of a connection that is
accepted and then stalls rather than one that answers immediately: a readiness
loop that counts attempts instead of elapsed wall-clock time multiplies its
budget by whatever each stalled request costs it.
"""

import argparse
import http.server
import json
import os
import signal
import sys
import time
import urllib.parse

ENGINES_BY_CATEGORY = {
    "qwen-open": ["bing", "google", "wikipedia"],
    "qwen-broad": ["bing", "google", "wikipedia", "mdn", "github", "stackoverflow"],
}


def parse_counts(specification):
    counts = {}
    for entry in specification.split(","):
        entry = entry.strip()
        if not entry:
            continue
        name, _, value = entry.partition("=")
        counts[name.strip()] = int(value)
    return counts


def build_arguments():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, required=True)
    parser.add_argument(
        "--results",
        default="qwen-open=3,qwen-broad=6",
        help="records each category answers with, as CATEGORY=COUNT pairs",
    )
    parser.add_argument("--log", default="", help="one line per request")
    parser.add_argument("--fail-health", action="store_true")
    parser.add_argument(
        "--delay-ready",
        type=float,
        default=0.0,
        help="seconds after start before /healthz answers 200 rather than 503",
    )
    parser.add_argument(
        "--ignore-term",
        action="store_true",
        help="retain SIGTERM, so a teardown meets a survivor and reports residue",
    )
    parser.add_argument(
        "--stall-health",
        type=float,
        default=0.0,
        help="seconds the /healthz handler sleeps before answering 200",
    )
    return parser.parse_args()


def main():
    arguments = build_arguments()
    counts = parse_counts(arguments.results)
    started_monotonic = time.monotonic()

    def note(line):
        if not arguments.log:
            return
        with open(arguments.log, "a", encoding="utf-8") as handle:
            handle.write(line + "\n")

    # The launch chain suppresses bytecode in every python child it starts,
    # because an import writes it into the runtime tree the manifest names. The
    # value this child inherited is recorded so a test reads what the session
    # actually exported rather than what the session's source says.
    note(
        "environment pythondontwritebytecode=%s"
        % (os.environ.get("PYTHONDONTWRITEBYTECODE", "") or "unset")
    )

    class Handler(http.server.BaseHTTPRequestHandler):
        protocol_version = "HTTP/1.1"

        def log_message(self, *unused):
            pass

        def answer(self, status, body, content_type):
            payload = body.encode("utf-8")
            self.send_response(status)
            self.send_header("Content-Type", content_type)
            self.send_header("Content-Length", str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)

        def do_GET(self):
            parsed = urllib.parse.urlparse(self.path)
            fields = urllib.parse.parse_qs(parsed.query)
            if parsed.path == "/healthz":
                note("healthz")
                if arguments.stall_health:
                    # ThreadingHTTPServer gives each request its own thread,
                    # so this blocks only the caller waiting on it rather than
                    # the whole listener.
                    time.sleep(arguments.stall_health)
                if arguments.fail_health:
                    self.answer(503, "unavailable", "text/plain")
                elif (
                    arguments.delay_ready
                    and time.monotonic() - started_monotonic < arguments.delay_ready
                ):
                    self.answer(503, "unavailable", "text/plain")
                else:
                    self.answer(200, "OK", "text/plain")
                return
            if parsed.path != "/search":
                self.answer(404, "not found", "text/plain")
                return
            category = (fields.get("categories") or [""])[0]
            query = (fields.get("q") or [""])[0]
            note("search category=%s q=%s" % (category, query))
            engines = ENGINES_BY_CATEGORY.get(category, ["bing"])
            records = []
            for index in range(counts.get(category, 0)):
                records.append(
                    {
                        "url": "https://example.org/%s/%d" % (category, index),
                        "title": "%s result %d" % (category, index),
                        "content": "FIXTURE-SEARXNG-%s-%d" % (category, index),
                        "engines": engines[: 1 + index % len(engines)],
                        "score": 1.0 / (index + 1),
                        "publishedDate": "",
                    }
                )
            self.answer(
                200,
                json.dumps(
                    {
                        "query": query,
                        "number_of_results": len(records),
                        "results": records,
                        "unresponsive_engines": [],
                    }
                ),
                "application/json",
            )

    service = http.server.ThreadingHTTPServer((arguments.host, arguments.port), Handler)

    def leave(unused_number, unused_frame):
        raise KeyboardInterrupt

    if arguments.ignore_term:
        signal.signal(signal.SIGTERM, signal.SIG_IGN)
    else:
        signal.signal(signal.SIGTERM, leave)
    sys.stdout.write("listening %s %s\n" % (arguments.host, arguments.port))
    sys.stdout.flush()
    try:
        service.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        service.server_close()


if __name__ == "__main__":
    main()
