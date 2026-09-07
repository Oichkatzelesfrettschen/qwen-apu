"""Post one streamed completion and report its first-token latency and timings.

Time to first token is the wall time from the instant the request leaves this
process to the first streamed chunk carrying non-empty content, measured on
CLOCK_MONOTONIC. It holds the HTTP round trip and the first sampling pass beside
the prefill, which is what a client observes; `timings.prompt_ms` beside it is
the server's own instrument over the same fill.

Every timing the ledger states is required. A reply whose `timings` object omits
one, or states it as something other than a finite number, ends this reader with
`missing_timings` rather than a zero, since a rate of nothing pairs as a
measurement.

A finite value is not by itself a measurement: `prompt_n` and `predicted_n` are
counts, so a non-integer value is `timings_noninteger`, and every count and rate
is required positive, so a zero or negative one is `timings_nonpositive` --
`prompt_per_second: 0` and a negative `prompt_ms` are what this rejects. A
decode spanning more than one token is required to have taken measurable time,
so `predicted_ms` is nonpositive there too. `predicted_n` is further required to
equal the `n_predict` this request asked for, as `predicted_n_mismatch`, since a
server that decoded a different count answered a different request than the one
the ladder posted.
"""
import json
import math
import sys
import time
import urllib.request

origin, prompt_path, predict, deadline_s, destination = sys.argv[1:6]
with open(prompt_path, encoding="utf-8") as handle:
    prompt_text = handle.read()
body = json.dumps({
    "prompt": prompt_text,
    "n_predict": int(predict),
    "temperature": 0,
    "top_k": 1,
    "seed": 1,
    "ignore_eos": True,
    "cache_prompt": False,
    "stream": True,
}).encode()
request = urllib.request.Request(
    f"{origin}/completion", data=body,
    headers={"Content-Type": "application/json"})

first_token_ns = None
final = None
started_ns = time.monotonic_ns()
with urllib.request.urlopen(request, timeout=float(deadline_s)) as response:
    for raw in response:
        line = raw.decode("utf-8", "replace").strip()
        if not line.startswith("data:"):
            continue
        payload = line[len("data:"):].strip()
        if payload == "[DONE]":
            continue
        chunk = json.loads(payload)
        if first_token_ns is None and chunk.get("content"):
            first_token_ns = time.monotonic_ns()
        if chunk.get("stop"):
            final = chunk
completed_ns = time.monotonic_ns()
if first_token_ns is None:
    sys.stderr.write("no_content_delta\n")
    raise SystemExit(1)
if final is None:
    sys.stderr.write("no_final_chunk\n")
    raise SystemExit(1)
timings = final.get("timings")
if not isinstance(timings, dict):
    sys.stderr.write("missing_timings\n")
    raise SystemExit(1)
required = ("prompt_n", "prompt_ms", "prompt_per_second",
            "predicted_n", "predicted_ms", "predicted_per_second")
count_fields = ("prompt_n", "predicted_n")
positive_fields = ("prompt_n", "prompt_ms", "prompt_per_second",
                   "predicted_n", "predicted_per_second")
values = {}
for name in required:
    value = timings.get(name)
    if not isinstance(value, (int, float)) or isinstance(value, bool):
        sys.stderr.write(f"missing_timings field={name}\n")
        raise SystemExit(1)
    value = float(value)
    if not math.isfinite(value):
        sys.stderr.write(f"missing_timings field={name}\n")
        raise SystemExit(1)
    if name in positive_fields and value <= 0:
        sys.stderr.write(f"timings_nonpositive field={name} value={value:.6g}\n")
        raise SystemExit(1)
    if name in count_fields and not value.is_integer():
        sys.stderr.write(f"timings_noninteger field={name} value={value:.6g}\n")
        raise SystemExit(1)
    values[name] = value
if values["predicted_n"] > 1 and values["predicted_ms"] <= 0:
    sys.stderr.write(
        f"timings_nonpositive field=predicted_ms value={values['predicted_ms']:.6g}\n")
    raise SystemExit(1)
requested_predict = int(predict)
if int(values["predicted_n"]) != requested_predict:
    sys.stderr.write(
        f"predicted_n_mismatch requested={requested_predict}"
        f" reported={int(values['predicted_n'])}\n")
    raise SystemExit(1)
with open(destination, "w", encoding="utf-8") as handle:
    json.dump(final, handle)
print(f"ttft_ms={(first_token_ns - started_ns) / 1e6:.3f}")
print(f"wall_ms={(completed_ns - started_ns) / 1e6:.3f}")
print(f"window_begin_ns={started_ns}")
print(f"window_end_ns={completed_ns}")
for name in required:
    print(f"{name}={values[name]:.6g}")
