#!/bin/sh
set -eu

# The stand-in for llama-server that lets the temporal-amortization harness and
# its break-even summarizer run without the device.
#
# It answers the four routes that harness uses -- /health, /completion,
# /metrics, and an argv record -- and it derives its speculation counters from
# one acceptance rather than from three independent numbers, so the accounting
# identity the summarizer enforces holds by construction. Each skew variable
# then breaks exactly one term: the two metrics skews move the cumulative
# counters away from what the response reports, which is what an unordered
# /metrics read produces, and the timings and control variables break a count
# the response itself carries.
#
# Every round emits one target token beside the drafts it accepts and the first
# token comes from the prompt logits, so with acceptance `a` and draft length
# `n` the step count solves `steps = (predicted_n - 1) / (1 + a * n)`, the
# accepted count is `predicted_n - 1 - steps`, and the drafted count is
# `n * steps`.

if [ "${1:-}" = --version ]; then
    printf 'version: 0 (fake-mtp)\nbuild: 0000000 with fake\n'
    exit 0
fi

if [ -z "${QWEN_FAKE_MTP_STATE_DIRECTORY:-}" ]; then
    printf 'QWEN_FAKE_MTP_STATE_DIRECTORY is required\n' >&2
    exit 2
fi

fake_spec_type=none
fake_draft_n_max=0
fake_previous=
for fake_argument in "$@"; do
    case $fake_previous in
        --spec-type) fake_spec_type=$fake_argument ;;
        --spec-draft-n-max) fake_draft_n_max=$fake_argument ;;
    esac
    fake_previous=$fake_argument
done

mkdir -p "$QWEN_FAKE_MTP_STATE_DIRECTORY"
{
    printf 'spec_type=%s\n' "$fake_spec_type"
    printf 'draft_n_max=%s\n' "$fake_draft_n_max"
    printf 'profile=%s\n' "${QWEN_VULKAN_PROFILE:-unset}"
    printf 'strict=%s\n' "${LLAMA_NO_CPU_FALLBACK:-unset}"
    printf 'lease=%s\n' "${QWEN_VULKAN_WORKLOAD_LOCK-unset}"
    printf 'argument_count=%s\n' "$#"
    for fake_argument in "$@"; do
        printf 'argument=%s\n' "$fake_argument"
    done
} >"$QWEN_FAKE_MTP_STATE_DIRECTORY/argv-$$.txt"

[ -n "${QWEN_FAKE_MTP_PORT:-}" ] || exit 0

# A per-depth override lets one invocation of the harness, which sweeps every
# draft length in turn, give each depth its own rate and acceptance.
fake_rate=${QWEN_FAKE_MTP_DECODE_TOK_S:-3.10}
fake_acceptance=0
if [ "$fake_spec_type" != none ]; then
    fake_rate=${QWEN_FAKE_MTP_SPEC_TOK_S:-3.50}
    fake_acceptance=${QWEN_FAKE_MTP_ACCEPTANCE:-0.850}
    eval "fake_rate=\${QWEN_FAKE_MTP_SPEC_TOK_S_N$fake_draft_n_max:-\$fake_rate}"
    eval "fake_acceptance=\${QWEN_FAKE_MTP_ACCEPTANCE_N$fake_draft_n_max:-\$fake_acceptance}"
fi

QWEN_FAKE_MTP_RESOLVED_PORT=$QWEN_FAKE_MTP_PORT \
QWEN_FAKE_MTP_RESOLVED_RATE=$fake_rate \
QWEN_FAKE_MTP_RESOLVED_ACCEPTANCE=$fake_acceptance \
QWEN_FAKE_MTP_RESOLVED_DRAFT_N_MAX=$fake_draft_n_max \
QWEN_FAKE_MTP_RESOLVED_SPEC_TYPE=$fake_spec_type \
QWEN_FAKE_MTP_RESOLVED_TOKENS=${QWEN_FAKE_MTP_TOKENS:-10 11 12 13 14 15 16 17} \
QWEN_FAKE_MTP_RESOLVED_TOKENS_SPEC=${QWEN_FAKE_MTP_TOKENS_SPEC:-} \
QWEN_FAKE_MTP_RESOLVED_METRICS_SKEW=${QWEN_FAKE_MTP_METRICS_SKEW:-0} \
QWEN_FAKE_MTP_RESOLVED_STEP_SKEW=${QWEN_FAKE_MTP_STEP_SKEW:-0} \
QWEN_FAKE_MTP_RESOLVED_CONTROL_MOVE=${QWEN_FAKE_MTP_CONTROL_METRICS_MOVE:-0} \
QWEN_FAKE_MTP_RESOLVED_OMIT_METRICS=${QWEN_FAKE_MTP_OMIT_METRICS:-0} \
QWEN_FAKE_MTP_RESOLVED_OMIT_TIMINGS_DRAFT=${QWEN_FAKE_MTP_OMIT_TIMINGS_DRAFT:-0} \
    exec python3 - <<'PY'
import json
import os
from http.server import BaseHTTPRequestHandler, HTTPServer

port = int(os.environ["QWEN_FAKE_MTP_RESOLVED_PORT"])
rate = float(os.environ["QWEN_FAKE_MTP_RESOLVED_RATE"])
acceptance = float(os.environ["QWEN_FAKE_MTP_RESOLVED_ACCEPTANCE"])
draft_n_max = int(os.environ["QWEN_FAKE_MTP_RESOLVED_DRAFT_N_MAX"])
speculating = os.environ["QWEN_FAKE_MTP_RESOLVED_SPEC_TYPE"] != "none"
control_tokens = [
    int(value) for value in os.environ["QWEN_FAKE_MTP_RESOLVED_TOKENS"].split()
]
spec_tokens_text = os.environ["QWEN_FAKE_MTP_RESOLVED_TOKENS_SPEC"]
spec_tokens = (
    [int(value) for value in spec_tokens_text.split()]
    if spec_tokens_text
    else control_tokens
)
metrics_skew = int(os.environ["QWEN_FAKE_MTP_RESOLVED_METRICS_SKEW"])
step_skew = int(os.environ["QWEN_FAKE_MTP_RESOLVED_STEP_SKEW"])
control_move = os.environ["QWEN_FAKE_MTP_RESOLVED_CONTROL_MOVE"] == "1"
omit_metrics = os.environ["QWEN_FAKE_MTP_RESOLVED_OMIT_METRICS"] == "1"
omit_timings_draft = os.environ["QWEN_FAKE_MTP_RESOLVED_OMIT_TIMINGS_DRAFT"] == "1"


def speculation_counts(predicted):
    """Drafted, accepted, and verification steps consistent with one acceptance.

    The step count is rounded to an integer and the accepted count is derived
    from it rather than rounded separately, so the summarizer's
    `steps == predicted_n - accepted - 1` identity holds exactly.
    """
    decoded = predicted - 1
    if not speculating or draft_n_max <= 0 or decoded <= 0:
        return 0, 0, 0
    steps = max(1, round(decoded / (1.0 + acceptance * draft_n_max)))
    steps = min(steps, decoded)
    accepted = decoded - steps
    drafted = draft_n_max * steps
    if accepted > drafted:
        accepted = drafted
        steps = decoded - accepted
        drafted = draft_n_max * steps
    return drafted, accepted, steps


class ReusableHTTPServer(HTTPServer):
    allow_reuse_address = True


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *arguments):
        pass

    def respond(self, payload):
        body = json.dumps(payload).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if self.path.startswith("/health"):
            self.respond({"status": "ok"})
            return
        if self.path.startswith("/metrics"):
            if omit_metrics:
                self.send_error(404)
                return
            body = (
                "# TYPE spec_decode_num_draft_tokens_total counter\n"
                f"spec_decode_num_draft_tokens_total {self.server.drafted:.1f}\n"
                "# TYPE spec_decode_num_accepted_tokens_total counter\n"
                f"spec_decode_num_accepted_tokens_total {self.server.accepted:.1f}\n"
                "# TYPE spec_decode_num_drafts_total counter\n"
                f"spec_decode_num_drafts_total {self.server.steps:.1f}\n"
            ).encode()
            self.send_response(200)
            self.send_header("Content-Type", "text/plain")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return
        self.send_error(404)

    def do_POST(self):
        if not self.path.startswith("/completion"):
            self.send_error(404)
            return
        length = int(self.headers.get("Content-Length") or 0)
        body = json.loads(self.rfile.read(length).decode() or "{}")
        source = spec_tokens if speculating else control_tokens
        predicted = int(body.get("n_predict") or len(source))
        emitted = [source[index % len(source)] for index in range(predicted)]
        drafted, accepted, steps = speculation_counts(predicted)
        timings = {
            "prompt_n": len(str(body.get("prompt", "")).split()),
            "prompt_ms": 1000.0,
            "prompt_per_second": 20.0,
            "predicted_n": predicted,
            "predicted_ms": max(predicted - 1, 0) * 1000.0 / rate,
            "predicted_per_second": rate,
        }
        if drafted > 0 and not omit_timings_draft:
            timings["draft_n"] = drafted
            timings["draft_n_accepted"] = accepted
        # A skew models the /metrics counters disagreeing with the response,
        # which only a speculating server can do; a control moves nothing.
        self.server.drafted += drafted + (metrics_skew if speculating else 0)
        self.server.accepted += accepted
        self.server.steps += steps + (step_skew if speculating else 0)
        if control_move and not speculating:
            self.server.drafted += 1
            self.server.accepted += 1
            self.server.steps += 1
        self.respond({"content": "", "tokens": emitted, "timings": timings})


server = ReusableHTTPServer(("127.0.0.1", port), Handler)
server.drafted = 0
server.accepted = 0
server.steps = 0
server.serve_forever()
PY
