# One functional image turn through the live LAN page

`remote/web-mcp/drive-fallback-page.py --lane image --review` drove one turn
against the appliance already serving under `lan-authenticated` -- the router
on port 42069, the broker on 42070, the artifact listener on 42071, the
`web-open` section armed with the image server, and
`# qwen_image_review_section=lfm25-vl-16b` in the preset's head marker. The run
started nothing and tore nothing down. This is a functional check of the served
page against a live deployment rather than an admission: the admission for this
lane is `evidence/image-appliance/served-turn-admission/` and the paired review
is `evidence/image-appliance/paired-review-admission/`.

## Generation passed end to end

The prompt was `Draw a fox in a snowy field.` and the language profile was
`web-open`, which resolves to `qwen38-4b-distill`. The model proposed one
`image_generate_image` call inside every bound the tool listing states:

    {"prompt":"A beautiful fox standing in a snowy field, snow-covered
    landscape, winter scene, soft lighting","seed":123456,"width":512,
    "height":512,"steps":1,"profile_id":"image-sdxs-512-a"}

The approval dialog named the prompt, an empty negative prompt, seed 123456,
512x512, 1 step, and profile `image-sdxs-512-a`, and the page posted one
`POST /grant-image` to the broker and one `POST /tools` carrying the grant
inside `params`. The tool message came back naming
`sha256 e6778995b6421a52a96e6416ae62b541e72cf7d11f18bc3dd81222d8398e4d82` with
provenance route
`/artifacts/768a20d172c6540e9ceba7b260dcf35d68d96c65b3a7b28e4d82fc5672b7d4da.json`,
and the artifact card rendered with that digest, seed, geometry, and profile.

`GET /artifacts/<sha>.png` with the Web UI bearer returns bytes hashing to the
digest the reply named, and the same route with no bearer answers 401. Every
request the page made stayed on the three origins the launch owns:
`10.0.0.170:42069`, `:42070`, and `:42071`.

`provenance.json` carries the run: `runtime_seconds` 15.252, `total_seconds`
15.273, `png_bytes` 608726, `nice` 19, `ioclass` idle, `steps` 1, sampler
euler, `timeout_s_applied` 300 against a requested 300, `exit_status` 0, and
`vram_used_bytes` 2067456000 against a 2048 MiB carve-out. The service's own
log records `generate_image completed in 11.68s` with 3.95 s of that in latent
decode. `started_at` is 2026-09-06T09:14:34Z and `recorded_at` 09:14:49Z inside
a page turn that ran 09:11:20Z to 09:16:41Z.

The PNG itself is not retained here. The provenance record names the profile,
the seed, the runtime SHA-256, and the PNG SHA-256, which reproduces the file
from its own runtime -- the convention `ARTIFACTS.md` states and
`evidence/image-appliance/paired-review-admission/` already follows.

## The review reached the reviewer and its verdict failed the schema

The page found a vision modality on `GET /props?model=lfm25-vl-16b`, offered
Review on the card, fetched the artifact a second time over the credentialed
route, and posted one `/v1/chat/completions` to that reviewer. The verdict came
back carrying `hard_constraints` alone, and the page refused it:

    The review did not complete: the verdict carries the keys hard_constraints.

`remote/image-review.py`'s schema requires `hard_constraints`,
`composition_change_required`, `prompt_delta`, and `regenerate` together, and a
reply missing a key is refused by the rule rather than read partially. The
refusal is the mechanism working; what it reports is that `lfm25-vl-16b`
emitted a partial object on this turn. The reply itself is not retained in the
driver's report, so whether the three absent keys were dropped, truncated at
the 400-token reply budget, or displaced by a reasoning span is unresolved
here. `remote/image-review.py --image-mode real` against this digest with the
raw reply retained is the probe that separates them.

The review ran roughly 09:14:52Z to 09:16:41Z, about 109 s from the artifact
fetch to the refused verdict. That is the whole review leg including the
reviewer's load: `--models-max 1` means the router unloaded the 4B and loaded
the vision child between the generation and the review, so the figure is not
comparable to the 19.44 s
`evidence/image-appliance/paired-review-admission/` measured for a review with
its reviewer already resident.

## Files

`browser-turn.json` is the driver's own report -- the dialog fields, the
transcript, the artifact card, and every request the page's `fetch` made. The
grant inside the one `POST /tools` body is replaced by `<redacted-grant>`, the
filter `remote/admit-image-router.sh` applies to its own retained reports; the
report carries no bearer and no session secret. The review request's logged
body is truncated by the driver at 4000 characters and holds a prefix of the
artifact's own base64 bytes, which is a copy of a content-addressed file rather
than a credential. `provenance.json` is the artifact's provenance record read
over the listener. `timing.txt` carries the turn's start and end.
