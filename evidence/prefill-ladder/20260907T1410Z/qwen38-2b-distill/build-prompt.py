"""Build a prompt of exactly the requested token count against the served route.

The filler word is repeated and the count adjusted by the difference `/tokenize`
reports, which converges in one step wherever the tokenizer maps the filler onto
a fixed number of tokens and is bounded by an attempt count otherwise: a
tokenizer that merges across the space boundary oscillates rather than settling,
and an exhausted budget is `prompt_length_unconverged` rather than a prompt of
some other length.
"""
import json
import sys
import urllib.request

origin, filler, target, attempts, destination = sys.argv[1:6]
target, attempts = int(target), int(attempts)


def tokenize(text):
    body = json.dumps({"content": text}).encode()
    request = urllib.request.Request(
        f"{origin}/tokenize", data=body,
        headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(request, timeout=600) as response:
        payload = json.loads(response.read().decode())
    tokens = payload.get("tokens")
    if not isinstance(tokens, list):
        sys.stderr.write("tokenize_reply_without_tokens\n")
        raise SystemExit(1)
    return len(tokens)


words = target
seen = set()
for attempt in range(1, attempts + 1):
    if words < 1:
        words = 1
    text = " ".join([filler] * words)
    count = tokenize(text)
    if count == target:
        with open(destination, "w", encoding="utf-8") as handle:
            handle.write(text)
        print(f"tokenize_n={count}")
        print(f"words={words}")
        print(f"attempts={attempt}")
        raise SystemExit(0)
    if words in seen:
        break
    seen.add(words)
    words += target - count
sys.stderr.write("prompt_length_unconverged\n")
raise SystemExit(1)
