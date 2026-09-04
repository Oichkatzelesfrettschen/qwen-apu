import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as handle:
    payload = json.load(handle)
top_count = int(sys.argv[2])
tokens = payload.get("tokens")
probabilities = payload.get("completion_probabilities")


def top_list(entry, token_id):
    top = entry.get("top_logprobs")
    if not isinstance(top, list) or len(top) < top_count:
        sys.stderr.write(f"top_logprobs holds {len(top) if isinstance(top, list) else 'no'} entries"
                         f" where {top_count} were requested\n")
        raise SystemExit(1)
    if top[0].get("id") != token_id:
        sys.stderr.write(f"top_logprobs opens on id {top[0].get('id')} where the selected token is {token_id}\n")
        raise SystemExit(1)
    return ";".join(f"{int(item['id'])}:{float(item['logprob']):.9g}" for item in top[:top_count])

if not isinstance(tokens, list) or not tokens:
    sys.stderr.write("response carries no token array\n")
    raise SystemExit(1)
# The server returns fewer probability entries than tokens whenever a token
# ends inside a multi-byte UTF-8 sequence: `process_token` in
# tools/server/server-context.cpp at f280b269 calls `slot.add_token` only
# when `validate_utf8` finds the generated text complete, so the withheld
# token gets no entry and the next complete token's entry carries both
# pieces in its `bytes`. A reply writing `÷` three times therefore carries
# three fewer entries, and the count follows content. The entries are
# merged onto the token array by id in order; a token without an entry
# prints `-`, is compared by id alone, and is admitted only when the entry
# that follows it holds a byte at or above 0x80, which is the sequence the
# server withheld it for. Every entry must be consumed, since an entry the
# token array cannot place names a reply this reader does not understand.
if not isinstance(probabilities, list) or not probabilities:
    sys.stderr.write("response carries no probability entries\n")
    raise SystemExit(1)
entry_index = 0
withheld = []
lines = []
for position, token_id in enumerate(tokens):
    if not isinstance(token_id, int):
        sys.stderr.write("token array holds a non-integer entry\n")
        raise SystemExit(1)
    if entry_index < len(probabilities) and probabilities[entry_index].get("id") == token_id:
        entry = probabilities[entry_index]
        lines.append(f"{token_id}\t{float(entry['logprob']):.9g}\t{top_list(entry, token_id)}")
        entry_index += 1
    else:
        following = probabilities[entry_index] if entry_index < len(probabilities) else {}
        following_bytes = following.get("bytes")
        if not isinstance(following_bytes, list) or not any(isinstance(b, int) and b >= 0x80 for b in following_bytes):
            sys.stderr.write(f"token {token_id} at position {position} has no probability entry and the"
                             f" entry that follows carries no multi-byte sequence to explain it\n")
            raise SystemExit(1)
        lines.append(f"{token_id}\t-\t-")
        withheld.append(position)
if entry_index != len(probabilities):
    sys.stderr.write(f"probability entries do not align with the token array:"
                     f" consumed={entry_index} of {len(probabilities)} withheld_tokens={len(withheld)}\n")
    raise SystemExit(1)
if withheld:
    sys.stderr.write(f"withheld_utf8_positions={','.join(str(p) for p in withheld)}\n")
print("\n".join(lines))
