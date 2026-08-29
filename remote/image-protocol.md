# Image job protocol, version 1

One image job crosses four boundaries -- the Web UI, the image MCP wrapper,
`remote/image-service.py`, and the pinned runtime -- and each boundary reads the
same line. This file freezes what that line says at `protocol_version=1`, and
`remote/image_protocol.py` is the checker every lane tests against, so a rule
stated here is enforced in one place rather than restated in each caller.

The Python standard library carries no JSON Schema validator, so the schema is
code rather than a `.schema.json`: a declarative schema in this tree would need
a dependency to enforce it, and an unenforced schema drifts from the callers it
describes. `image_protocol.validate_request` and
`image_protocol.validate_response` raise `ProtocolError` naming the field and
the breach; `decode_line` and `encode_line` carry the framing.
`remote/test-image-protocol.py` drives every refusal below.

## Framing

A message is one UTF-8 JSON object on one line, terminated by `\n`. The line is
bounded at 65536 bytes excluding the terminator, measured on the encoded bytes
before the line is parsed, so an oversized line costs a length check rather than
a parse and a peer streaming an unbounded line does not choose the reader's
memory. `encode_line` writes compact separators, sorted keys, and ASCII escapes,
so the bytes the sender bounded are the bytes the peer measures.

The schema is closed at version 1. An unknown key is refused rather than
ignored, because a field a newer peer adds would otherwise be dropped silently
into a run that acts on fewer fields than the sender believes it sent. A
`protocol_version` other than 1 is refused by the same checker, so a version
change is a visible edit here rather than a tolerated difference on the wire.

## Request

| field | type | applies to | rule |
| --- | --- | --- | --- |
| `protocol_version` | integer | every action | exactly 1 |
| `request_id` | string | every action | 1 to 64 characters of `[A-Za-z0-9._-]` |
| `action` | string | every action | `image_generate`, `cancel`, or `status` |
| `profile_id` | string | `image_generate` | identifier shape; a row in `remote/image-profiles.tsv` |
| `prompt` | string | `image_generate` | at most 8192 characters |
| `negative_prompt` | string | `image_generate` | at most 8192 characters, empty string where none applies |
| `seed` | integer | `image_generate` | required, 0 to 4294967295 |
| `aspect` | string | `image_generate` | `square`, `portrait`, or `landscape`, agreeing with width and height |
| `width` | integer | `image_generate` | 64 to 2048, a multiple of 64 |
| `height` | integer | `image_generate` | 64 to 2048, a multiple of 64 |
| `steps` | integer | `image_generate` | 1 to 100 |
| `authorization` | string | `image_generate` | the grant token, opaque to the service, 1 to 4096 characters |

The seed is required rather than defaulted. Where the model omits one, the
trusted UI generates and displays it before approval, so the value the grant was
signed over is the value that reaches the runtime and randomness is fixed before
authorization rather than chosen after it.

`aspect` and the dimensions state one shape twice, so the checker requires them
to agree rather than choosing which one the runtime obeys: `square` where width
equals height, `landscape` where width exceeds it, `portrait` otherwise.

A `cancel` or a `status` message carries `protocol_version`, `request_id`, and
`action` alone, and the checker refuses any generation field on one. A control
message names a job; describing one would let a cancel arrive carrying a
geometry the grant never authorized.

`authorization` is opaque here. The service verifies the grant against the
`qwen-image-generate-v1` context, which binds the language profile, the image
profile, the prompt hash, the negative-prompt hash, the seed, the aspect, the
maximum dimensions, the maximum step count, the conversation generation, an
expiry, and a single-use nonce. This protocol carries the token and states
nothing about its contents.

The bounds in the table are the protocol frame. `remote/image-profiles.tsv` is
the serving authority, and a request inside these bounds still meets its own
profile's `max_dimension`, `max_steps`, and `timeout_s` before anything runs. A
request naming no filesystem path is what makes those two checks sufficient:
the service chooses every path it writes.

## Response

| field | type | rule |
| --- | --- | --- |
| `protocol_version` | integer | exactly 1 |
| `request_id` | string | the request it answers |
| `status` | string | `accepted`, `completed`, `refused`, `cancelled`, or `failed` |
| `sha256` | string | 64 lowercase hex digits, present on `completed` alone |
| `provenance_url` | string | `/artifacts/<sha256>.json`, present on `completed` alone |
| `error` | string | 1 to 1024 characters, present on `refused` and `failed` |

`completed` carries the digest and the provenance URL and no error.
`provenance_url` is derived from `sha256` rather than chosen by the sender, and
the checker requires the two to agree, so an artifact is reachable only by its
own identity and a caller supplies no path at any layer. `refused` and `failed`
carry a non-empty error and name no artifact. `accepted` and `cancelled` report
progress and carry neither.

`refused` and `failed` differ in what they say about the machine. `refused` is a
request the service declined -- a grant outside the profile's bounds, a spent
nonce, a profile whose `execution_policy` reads `refused` -- and nothing reached
the device. `failed` is a run that started and did not produce a valid PNG,
which is what a telemetry record and, where the device is implicated, a row in
`remote/image-quarantine.tsv` are opened against.

## Timeouts

The deadlines stack so that a stalled run is ended by the process that owns it
rather than abandoned by the layer above: the runtime's hard bound is 300 s and
the profile row carries it, the image service allows 330 s, the image MCP tool
allows 360 s, the router proxy allows 600 s, and the browser allows 660 s. Each
of those is an initial bound the first campaign measures against rather than a
promise.

## What tests this

`remote/test-image-protocol.py` exercises every accepted shape and every refusal
named above, including the line exactly at the 65536-byte bound and the line one
byte past it. The service and MCP lanes import `remote/image_protocol.py` and
test against this file, so a change to the contract is one edit here, one edit
in the module, and a failing suite everywhere the old reading survived.
