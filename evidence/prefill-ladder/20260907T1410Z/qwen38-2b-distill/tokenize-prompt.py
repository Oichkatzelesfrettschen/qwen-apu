"""Report how many tokens the served route makes of one prompt file."""
import json
import sys
import urllib.request

origin, prompt_path = sys.argv[1:3]
with open(prompt_path, encoding="utf-8") as handle:
    text = handle.read()
request = urllib.request.Request(
    f"{origin}/tokenize", data=json.dumps({"content": text}).encode(),
    headers={"Content-Type": "application/json"})
with urllib.request.urlopen(request, timeout=600) as response:
    payload = json.loads(response.read().decode())
tokens = payload.get("tokens")
if not isinstance(tokens, list):
    sys.stderr.write("tokenize_reply_without_tokens\n")
    raise SystemExit(1)
print(len(tokens))
