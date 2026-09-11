# Application deployment identity at the Phase 8 merge

Main at `2a5fe478` carries Phases 1 to 9 of the Python control plane. The
page and the package are application deployment members beside the native
server, so the identity of an application deployment is the set below rather
than the executable's digest alone; the same `llama-server` serves a
different application when any row changes. The wheel row is empty because
the tree links its source through `bootstrap.py` and builds no wheel yet;
the Phase 10 deployment builder produces one and fills the row.

| Member | Identity |
| --- | --- |
| source commit | `2a5fe47867739f9d2e46451e73381bd4185e8c37` |
| qwen-apu wheel | none built; source linked from the checkout |
| dependency lock `wheelhouse/requirements.lock` | `d3eb57b49847b3f21a737fd1d7560560c83522d216a583276842b5728566bb0b` |
| static tree (sorted file digests, digested) | `3e23a61facdaf48f2d718c17cd102b29e26d65ab9a6cb979632d5a00ab074181` |
| `static/index.html` | `ccc85e863ca401814c640cb25b0f96a48bd143352d40091a9ce5cea6f87c47dc` |
| `static/js/api.js` | `2b67b8cd884b899d621bc657127b2e18aeb0a1440cff7a208d3e58083f27133e` |
| `static/js/artifacts.js` | `f8dfb6f3a81b272acd9e7d3585ea74bdb2a8375f82f76add9d99dabc49422623` |
| `static/js/attachments.js` | `1673da430e9c747d724f242c1d021be4847cc67ad35abeb2fb4f795024e3f63b` |
| `static/js/chat.js` | `97548c5913344f0d39dea16d2bdaec0aca264a474a432f8c37b3a965157d5960` |
| `static/js/conversations.js` | `0b0808990104c2d059c093cc55ed0487826b3784b515a1ab81a65c6b11c4a071` |
| `static/js/models.js` | `c3fcf81aeabfdc87ff44af20241f5aef210fee1cc087ec3d336895491d797215` |
| `static/js/status.js` | `7a5eab8eef9bb6520cab51292a244406a2947c275bc170d402a4feaaf923a4ca` |
| `static/js/temporary.js` | `d67b763d9dc86f204ec9cf175395746a8f63e0cfd05b67aef0722e185abe0d31` |
| `static/js/tools.js` | `33c6e5a4551f7f4756c71bfe2f7e15f165fb25a03c8719a4e76c34d8b0453507` |
| conversation database schema version | 1 |
| native deployment (laptop, active) | `lease-q4k-6b262d93-r1`, server `510c0420346ffa4f5104d3f2b28117262a0d30b2907dc21c833d38442c3e49af` |
| `remote/models.tsv` | `f6574f070ffcc450fecff763bcbc6a7926f54923cb8cdebd1e04d93b13922a6a` |
| `remote/web-profiles.tsv` | `82808651466fff3cc2aea662762e7e338bcdfbaf87d05e636398156fb8ebb605` |
| `remote/feature-claims.tsv` | `ca044f89ceae7501bbe0d89b45faa48b031cfcbadc614fb3f68c120bca102329` |
| `remote/validated-tuples.tsv` | `92a68508781ba9426c3a4ba0e54faf634ec5ce797c320dc34af47851a65fab10` |
| `remote/draft-pairs.tsv` | `bf326a0f822d51dcf08aa877f39882661880651cf8a50ae02e5a099799de4986` |
| `remote/quarantine.tsv` | `32f5c3aa0fe474b568201b14552b995efe14c54eea35610b447ef1ebfd8ca810` |
| `remote/model-artifacts.tsv` | `b02df5588436f0a4030a1c020277e7f8aabde2c471e67d7313a3d93dbb0bd94c` |
