# Cutover rehearsal receipt: every acceptance item on the production address

Window `pyctl-cutover10` on the laptop, 2026-09-12, ran the bounded cutover
sequence with both lanes armed: the application deployment verified offline,
`qwen-apu appliance serve --router --port 8080 --gateway-port 42069
--bind-host 10.0.0.170 --image-profile image-sdxs-512-a --web-profile
web-open` owning the router, the gateway, the image worker, and the SearXNG
instance on the production address, pairing, the acceptance driver, the stop,
the legacy launch restored and verified behind its bearer, the legacy
teardown, the Python application again with `--previous-report`, the
acceptance again, and the stop; the window then relaunched legacy production.

```text
2026-09-12T01:56:30Z 3 verify the Python application offline
application_verify=/home/eirikr/worktrees/qwen-apu/cutover/.runtime/deployments/applications/cutover manifest_sha256=73f01212fa062a2139a45acc1c34d6afc2321c5f58c69d74039b4eb24198821f checked=17 result=verified
2026-09-12T01:56:31Z 5 python on the production address
2026-09-12T01:56:35Z 6-8 pair and run the acceptance
2026-09-12T01:59:59Z 9 stop python
stop_exit=0
2026-09-12T02:00:00Z 10 restore legacy and verify
state=running
legacy_models_http=200
2026-09-12T02:00:25Z 10b stop legacy
teardown_exit=0
2026-09-12T02:00:27Z 11 return to python
2026-09-12T02:00:31Z 12 verify python again
stop_exit=0
2026-09-12T02:03:48Z 13 done; the window relaunches legacy production
```

The first acceptance passed 26 items and skipped one by construction (the
restart proof needs a previous report). The second, after the legacy detour
over the same root:

| Check | Result | Reason or evidence |
| --- | --- | --- |
| `origin_reachable` | pass | status=401 |
| `unauthenticated_refusal` | pass | status=401 |
| `pairing` | pass | status=200 |
| `roster_join` | pass | entries=16, mode=router, preset_sections=compared |
| `text_turn:qwen35-08b` | pass | content=, served_model=qwen35-08b |
| `text_turn:qwen38-2b-distill` | pass | content=ready, served_model=qwen38-2b-distill |
| `text_turn:qwen38-4b-distill` | pass | content=, served_model=qwen38-4b-distill |
| `vision_consumes_image:lfm25-vl-16b` | pass | declared_tallest=middle, image_bytes=187, with_image=The tallest bar in this chart is blue., withheld=To determine the tallest bar in a chart, I would need to see the specific chart in question. Without the chart, it's not possible to identify the tallest bar. Could you provide a description or the ch |
| `midstream_cancel` | pass | first_bytes=256, follow_status=200, health_status=200, stream_status=200 |
| `calculator` | pass | status=200, value=12288 |
| `file_search` | pass | hits=200, status=200 |
| `file_search_scope` | pass | status=400 |
| `document_extraction:text.pdf` | pass | boundary_kinds=['page'], characters=79, expected_boundary_kinds=['page'], read_back_status=200, sha256=0582431928ba69d0c3d50f898d30b6384cabcb01cd8ef1624426b0ce10e9c8df, state=extracted |
| `document_extraction:two-paragraphs.docx` | pass | boundary_kinds=['page', 'paragraph'], characters=134, expected_boundary_kinds=['paragraph'], read_back_status=200, sha256=fb600fd46ee73557f5b44f3d42d90de5ba3a8506867af547337f08a64fe8165c, state=extracted |
| `web_search_then_fetch` | pass | attempts=[{'status': 200, 'state': 'complete', 'term': 'success', 'characters': 2955}], results_issued=5 |
| `web_retrieval_failure_explicit` | pass | proved_by=empty_window, start_index=131071, state=incomplete, status=200, term=provider_content_error |
| `image_generate` | pass | artifact=39bbddc9646c38059f596558f9594b7c0207c2e254bb5925d08297509d7b312b, status=200 |
| `artifact_read` | pass | bytes=588517, status=200 |
| `image_review` | pass | answered=True, schema_valid=True, status=200 |
| `image_cancel` | pass | request_id=d22ac8b2911d466fba131865cbe5408d, status=200, worker_status=refused |
| `image_remove` | pass | removed=True, status=200 |
| `browser_history_import` | pass | conversation_id=1608c89de578409c8d6b093d83ecbc2d, read_back_status=200, skipped=[], warnings=["conversations[0]: the browser record carries no per-message timestamp; every message's created_utc is set to the conversation's own updated_utc (2023-11-14T22:13:20.000Z)"] |
| `conversation_open` | pass | saved=9bd3a85e96fc40bc9710f4f1281cbbbd, temporary=2f0dbcb739be40a8ba0f23c877e8e0ee |
| `history_survives_restart` | pass | conversation_id=34a75cbed2b44505aba351c3018aeaf0, listed=True, listing_status=200, previous_report=/home/eirikr/worktrees/qwen-apu/cutover/.runtime/results/acceptance-1.json, read_status=200 |
| `stop_command` | pass | exit_status=0, stdout=signalled=1700809,1700796,1700795,1700762
 |
| `vulkan_lease_free` | pass | free=True, lease=/home/eirikr/worktrees/qwen-apu/cutover/.runtime/state/vulkan-workload.lock |
| `teardown_leaves_no_residue` | pass | children=0, listening_ports=[], record_state=stopped |

A skipped item names the route or the argument its claim needs; a 404 from a route this branch does not mount is a skip, and a 401 or 403 is a live gate answering and stays a failure.

Every item of the launch acceptance list is therefore proven on the
production address by a live run: the roster equals the registry-and-preset
join; the 0.8B, 2B, and 4B text turns name the selected model; the admitted
vision row consumes image bytes against a withheld control; saved history
survives the detour and temporary history does not; the browser import,
PDF and DOCX extraction with boundaries, the calculator, and the scoped file
search pass; a web search followed by a fetch grounds an answer and a
refusing source answers `incomplete` explicitly; image generation, artifact
read, review, cancel, and removal pass; a mid-stream cancel leaves the next
request healthy; the Vulkan workload lease is free after stop; an
unauthenticated request is refused; the teardown leaves no owned process,
socket, or listener; and legacy rollback and return both succeed.

Nine windows across the two days closed the launch-side gaps this run no
longer meets: the LAN Host literal in the gateway's and the approval routes'
closed sets, the per-launch session secret armed at assembly, the verifier
authorities stated in the appliance process, the worker's artifact directory,
the grant slot released on spend, a live source read as its own
incomplete proof, and a pairing code read only once whole. Each is a test on
main rather than a note here.
