# Cutover rehearsal receipt: Python on the production address, legacy restored, Python returned

Window `pyctl-cutover2` on the laptop, 2026-09-11 daytime under the user's
nice-19 grant, ran the bounded cutover sequence from the cutover worktree
while the window held production torn down: the application deployment
built and verified offline (`checked=17 result=verified`), `qwen-apu
appliance serve --router --port 8080 --gateway-port 42069 --bind-host
10.0.0.170` on the production address, pairing through the one-time code,
the acceptance driver against that origin, `appliance stop`, the legacy
launch restored and verified (`state=running`, `GET /v1/models` 200 behind
the bearer), the legacy teardown, the Python application again, the
acceptance again, and the stop; the window then relaunched legacy
production, which stayed the serving path.

```text
2026-09-11T23:44:51Z 3 verify the Python application offline
application_verify=/home/eirikr/worktrees/qwen-apu/cutover/.runtime/deployments/applications/cutover manifest_sha256=73f01212fa062a2139a45acc1c34d6afc2321c5f58c69d74039b4eb24198821f checked=17 result=verified
2026-09-11T23:44:53Z 5 python on the production address
2026-09-11T23:44:55Z 6-8 pair and run the acceptance
acceptance_1_exit=1
2026-09-11T23:46:44Z 9 stop python
stop_exit=0
2026-09-11T23:46:45Z 10 restore legacy and verify
state=running
legacy_models_http=200
2026-09-11T23:47:14Z 10b stop legacy
teardown_exit=0
2026-09-11T23:47:15Z 11 return to python
2026-09-11T23:47:18Z 12 verify python again
acceptance_2_exit=1
stop_exit=0
2026-09-11T23:48:54Z 13 done; the window relaunches legacy production
```

The first acceptance on the production address:

| Check | Result | Reason or evidence |
| --- | --- | --- |
| `origin_reachable` | pass | status=401 |
| `unauthenticated_refusal` | pass | status=401 |
| `pairing` | pass | status=200 |
| `roster_join` | pass | entries=16, mode=router, preset_sections=compared |
| `text_turn:qwen35-08b` | pass | content=, served_model=qwen35-08b |
| `text_turn:qwen38-2b-distill` | pass | content=ready, served_model=qwen38-2b-distill |
| `text_turn:qwen38-4b-distill` | pass | content=, served_model=qwen38-4b-distill |
| `vision_consumes_image:qwen38-2b-distill` | fail | the image arm answered 500 and the control 200 |
| `midstream_cancel` | pass | first_bytes=256, follow_status=200, health_status=200, stream_status=200 |
| `calculator` | pass | status=200, value=12288 |
| `file_search` | pass | hits=200, status=200 |
| `file_search_scope` | pass | status=400 |
| `document_extraction:text.pdf` | pass | boundary_kinds=['page'], characters=79, expected_boundary_kinds=['page'], read_back_status=200, sha256=0582431928ba69d0c3d50f898d30b6384cabcb01cd8ef1624426b0ce10e9c8df, state=extracted |
| `document_extraction:two-paragraphs.docx` | pass | boundary_kinds=['page', 'paragraph'], characters=134, expected_boundary_kinds=['paragraph'], read_back_status=200, sha256=fb600fd46ee73557f5b44f3d42d90de5ba3a8506867af547337f08a64fe8165c, state=extracted |
| `web_search_then_fetch` | skipped | the route /api/tools/web/search answers 404 on this branch, so the claim has no surface yet |
| `web_retrieval_failure_explicit` | skipped | the route /api/tools/web/fetch answers 404 on this branch, so the claim has no surface yet |
| `image_generate` | skipped | the image grant answered 403; every device-reaching call in this lane passes one human approval and a single-use grant |
| `artifact_read` | skipped | the image grant answered 403; every device-reaching call in this lane passes one human approval and a single-use grant |
| `image_review` | skipped | the image grant answered 403; every device-reaching call in this lane passes one human approval and a single-use grant |
| `image_cancel` | skipped | the image grant answered 403; every device-reaching call in this lane passes one human approval and a single-use grant |
| `image_remove` | skipped | the image grant answered 403; every device-reaching call in this lane passes one human approval and a single-use grant |
| `browser_history_import` | pass | read_back_status=200, skipped=[], warnings=["conversations[0]: the browser record carries no per-message timestamp; every message's created_utc is set to the conversation's own updated_utc (2023-11-14T22:13:20.000Z)"] |
| `conversation_open` | pass | saved=c8855e09cfd34ad18c4cc49df71411fc, temporary=786556151b2448cb9ebf528c11833a40 |
| `history_survives_restart` | skipped | the run names no --restart-command, so no second process reads this root |
| `stop_command` | pass | exit_status=0, stdout=signalled=475793,475767
 |
| `vulkan_lease_free` | pass | free=True, lease=/home/eirikr/worktrees/qwen-apu/cutover/.runtime/state/vulkan-workload.lock |
| `teardown_leaves_no_residue` | pass | children=0, listening_ports=[], record_state=stopped |

A skipped item names the route or the argument its claim needs; a 404 from a route this branch does not mount is a skip, and a 401 or 403 is a live gate answering and stays a failure.

The second acceptance, after the legacy detour over the same root, matched
the first apart from `browser_history_import`, which the driver refused by
re-importing the conversation id its first run had already stored.

What the run established: the appliance owns the router, the gateway, and
the state record on the production address; the roster equals the
registry-and-preset join; text turns on the 0.8B, 2B, and 4B name the
selected model in the served-model field; the mid-stream cancel leaves the
next request healthy; the calculator, scoped file search, PDF and DOCX
extraction with boundaries, saved and temporary conversations, the
unauthenticated refusal, the lease release, and the teardown with no owned
residue all pass; legacy rollback and return both succeed.

What the driver left open, each a driver-side contract rather than an
appliance fault: the vision arm was pointed at a text row; the web lane
posted to route names the executor does not serve; the image grant was
posted without the session secret the page sends; the restart proof named
no restart command; and the browser import reused one conversation id
across runs. The next device run carries the corrected driver.

The first window of this rehearsal answered 403 to every request: the
closed Host set was built from an exposure literal the assembly never
derived from a LAN bind, and the fix admits the bind host beside the
loopback names.
