# UI tool qualification and stopped image-quality protocol

## Result

The deployed page completed the tested mixed Wikipedia-to-image sequence. The
Wikipedia retrieval ended with the application-authored incomplete-source
result, the following image tool call completed, and the verified image card
remained authoritative while a fabricated model-written URL stayed labeled
unverified. A separate `web-open` turn searched and fetched
`docs.python.org` and produced the requested source-grounded answer. These two
retrieval outcomes remain separate: the successful source does not reclassify
the failed required retrieval.

The image-quality protocol stopped before generating its first image. The
Firefox driver ran with the system Python instead of the existing private
browser environment, and import of `marionette_driver` failed before Firefox
or a disposable profile started. The protocol retained that failure and marked
the cube and exact-text rows `not_run`; the stopping rule forbids a retry or a
later arm after a protocol failure. The result changes no image profile,
executable, bundle, model, or serving policy.

## Runtime identity

| Surface | Retained identity |
| --- | --- |
| Runtime source manifest commit | `09b937b1fabe671e0795e887c13d285abf0ee9da` |
| Runtime source manifest SHA-256 | `cae4b6220983880e188595eae842f30fc47cadbaf55e8e23b175a1bcebcd9293` |
| Served page SHA-256 | `4539f12f10cd2627383c3bd3ece520273061c7954ae40205668de0d5a8c6a891` |
| Deployment bundle | `lease-q4k-6b262d93-r1` |
| Serving executable SHA-256 | `510c0420346ffa4f5104d3f2b28117262a0d30b2907dc21c833d38442c3e49af` |
| Deployment receipt SHA-256 | `82374f61c9dc7cbf142215e8584c3047082c431d29a3c95346c54579276f1651` |
| Image profile | `image-sdxs-512-a` |
| Registered reviewer | `lfm25-vl-16b` |
| Private quality protocol SHA-256 | `138cb71e3ca3e16493556834b0a3fcf726a4802678e6bdf47ad48078ca47b2d6` |
| Submitted fox command SHA-256 | `9206a4580f59fff46db362beae5678c7650cdea72efbab31593eb20cafc0b216` |

The private acquisition binds the runtime records by the digests in
`source-derivative.tsv`. `web-retrieval-outcomes.tsv` retains the bounded
request, search, fetch, application-outcome, and cleanup fields for both
retrievals. `web-source-success-qualification.json` retains the successful
qualification object. Browser logs, session status, service addresses,
credentials, authorization-bearing URLs, result handles, and generated image
bytes remain under the declared runtime root. The stopped quality protocol
produced no image bytes.

## Product qualification outcomes

| Observation | Outcome | Scope |
| --- | --- | --- |
| Mixed-turn image tool execution | `completed` | One image call after the failed Wikipedia retrieval |
| Canonical artifact controls | `verified` | Open and Download resolved verified blob URLs; Remove and Review remained application-owned card actions |
| Fabricated model URL | `contained` | The prose URL remained under the unverified warning and never replaced the card identity |
| Successful required retrieval | `completed` | One `web-open` search and fetch against `docs.python.org` produced grounded content containing the requested title; the response also included unrequested explanatory text |
| Failed required retrieval | `incomplete_source` | One Wikipedia search/fetch sequence ended without a source-grounded answer |
| Browser cleanup for completed turns | `completed` | Each retained terminal reports browser completion and disposable-profile removal |
| Post-quality service health | `accepted` | Authenticated router, broker, and artifact health returned HTTP 200 |
| Post-quality access refusal | `accepted` | Unauthenticated router, broker, and artifact probes returned HTTP 401, 403, and 401 |
| Post-quality process identity | `preserved` | Seven recorded service PIDs and start identities remained live |
| Post-quality appliance surfaces | `preserved` | Bundle links, executable digest, page digest, KSM, DPM policy, and the observed QEMU PID/start identity matched the retained values |

The preservation claim covers only the enumerated observations. Filesystem,
network, kernel, VM guest, and application state outside those observations
remain unmeasured.

## Image-quality rows

The protocol registered 512 by 512 output, four steps, the sole admitted image
profile, and the registered reviewer for every row before execution.

| Row | Exact registered prompt |
| --- | --- |
| Fox side profile | `A single red fox standing on plain white snow, full body, strict left-facing side profile, one head, two ears, four anatomically plausible legs, one tail, no other animals or objects.` |
| Red cube left of blue sphere | `A single red cube strictly to the left of a single blue sphere on a plain white background, both fully visible, no other objects, no text.` |
| Exact-text sign | `A single plain rectangular sign centered on a plain white background. The sign contains exactly the uppercase text RAVEN2 READY, with no other letters, words, numbers, symbols, or objects.` |

| Row | Seed | Predefined constraint | Generation | Artifact digest | Generation latency | Reviewer schema | Reviewer judgment | Direct inspection | Agreement |
| --- | ---: | --- | --- | --- | --- | --- | --- | --- | --- |
| Fox side profile | `314159` | One complete red fox; strict left-facing side profile; plausible head, ears, four legs, and tail; no extra subject | `failed_before_start` | `not_produced` | `not_measured` | `not_run` | `not_run` | `not_run` | `not_assessable` |
| Red cube left of blue sphere | `271828` | Exactly one red cube strictly left of one blue sphere; both complete; no extra object or text | `not_run` | `not_produced` | `not_measured` | `not_run` | `not_run` | `not_run` | `not_assessable` |
| Exact-text sign | `161803` | One sign containing exactly `RAVEN2 READY`; uppercase and legible; no extra text or object | `not_run` | `not_produced` | `not_measured` | `not_run` | `not_run` | `not_run` | `not_assessable` |

The first row's private terminal SHA-256 is
`bca71a86cac229c44d094e4cc5b24311d581d43c4072ebc9a00e3bc2d19ce0fb`.
The terminal reports `ModuleNotFoundError`, browser `not_applicable`, profile
`not_created`, and cleanup `completed`. The retained failure supplies no visual
quality or reviewer-correctness observation.

## Sanitized derivative

`remote/sanitize-capture.py` transformed the bounded private source summary
into `source-derivative.tsv`, `web-retrieval-outcomes.tsv`, and
`web-source-success-qualification.json`. The sources contain bounded identities
and outcomes rather than raw browser records; the sanitizer replaced private
host and home fields. The transformation record binds every input, output, and
sanitizer byte sequence.

## Boundaries

- Installed weights, served models, experimental draft pairings, vision
  profiles, `web-open`, and image profiles remain distinct registry objects.
- `image-sdxs-512-a` remains the single admitted image-generation profile.
- Generated-image prose can be unreliable. Open, Download, Review, and Remove
  remain application-owned controls over the verified artifact.
- The executable and serving bundle were neither rebuilt nor renamed.
- The run installed no model and enabled no refused profile.
- Application-authored image-only completion remains outside this change.
- Q8 remains held. Arm `09-P` retained 748 sampler rows whose integer-floor
  mean was `1,038,085 ns`, above the registered `1,000,000 ns` limit. Isolated
  scheduling stalls also occur in accepted arms, so the record identifies no
  deterministic broker defect. Q8 calibration and candidate timing remain
  withheld until a registered input changes.
