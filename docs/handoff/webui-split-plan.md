# WebUI split plan (Phase 8)

`webui/index.html` is 5100 lines: one `<style>` block at lines 38-153, body
markup at 155-309 with 49 element ids, and one inline `<script>` at 310-5098
holding 161 top-level functions. The page writes text through `textContent`
throughout, so a model-authored URL renders as inert text; the only anchors
whose `href` the script sets are the artifact Open and Download links, which
`loadArtifactBlobUrl` fills after `verifiedDigest` proves the bytes against
the named SHA-256. The split keeps that boundary in `artifacts.js`.

| Target | Source lines | Owns |
| --- | --- | --- |
| `static/app.css` | 38-153 | every rule, verbatim |
| `static/index.html` | 155-309 | the markup, minus the demo-tool checkbox at 168, plus one stylesheet link and one module script |
| `js/api.js` | 343-412, 475-485, 1111-1185, 1309-1317, 1543-1605, 1774-1833 | storage helpers, `authHeaders`, the LAN bounds, grant requests, SHA-256 |
| `js/models.js` | 487-764, 2598-2765 | roster, picker, context, `boot` |
| `js/chat.js` | 2914-3130, 3570-4131 | the turn loop, streaming, proposed-tool dispatch |
| `js/conversations.js` | 4132-5045 | the IndexedDB, localStorage, memory store chain and the side panel |
| `js/attachments.js` | 2769-2913 | attach, chips, image data URLs |
| `js/tools.js` | 793-980, 1327-1527, 1606-1739, 3131-3229 | web tool listing, result handles, approval dialog, execution |
| `js/artifacts.js` | 981-2596, 3229-3568 | image generation, grants, artifact cards, review |
| `js/status.js` | 395-406, 470-474, 5047-5097 | entry point, tabs, key entry, a new `/api/health` probe |

Every network call is relative to the router origin today, with the broker
and artifact calls going to sibling origins read from the `qwen-web-broker`
and `qwen-image-artifacts` meta tags and gated by `trustedListenerOrigin`.
Under one origin every call retargets to `/api/*`: `./v1/models` and
`./props` to `/api/models`, `./tokenize` to a models sub-route, `./tools` to
`/api/tools`, `${broker}/session|grant|grant-image` to `/api/tools/session`,
`/api/tools/grant`, `/api/tools/grant-image`, `${artifacts}/artifacts/<sha>`
to `/api/artifacts/<sha>.png`, and `./v1/chat/completions` to `/api/chat`.
The multi-origin block at 1094-1285 and the two origin meta tags leave the
page; the two LAN bound meta tags stay. The demo tool goes whole: line 168,
`DEMO_TOOL` at 766, and the push at 2973.

The split removes the CSP problem: the page then references two files and a
`script-src 'self'` policy needs no hash and no `'unsafe-inline'`.

The ten `remote/test-fallback-webui-*.mjs` tests extract the inline script by
regex and evaluate it in a `vm` context with a fake DOM, so every one breaks
at the split. They move to importing `static/js/*.js` as real modules with
the fake globals installed first. `broker-origin.mjs` and the artifact-origin
assertions in `image-review.mjs` describe the sibling origins and are retired
with them; `sha256.mjs` reads `api.js` and needs a new end anchor since
`aspectRatio` moves to `artifacts.js`; the rest keep their assertions against
the module that received their functions.

One refactor risk: `apiKey` and `keyRequired` are reassigned `let` bindings
shared across the page; as module exports they become one small state object
with setters.
