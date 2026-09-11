# Shadow deployment receipt: the split page and the document routes

Window `pyctl-shadow3e` on the laptop, 2026-09-11 daytime under the user's
nice-19 grant, ran the Phase 8 branch (Phases 1 to 7 merged beneath it)
from a git worktree with its own runtime root while production stood torn
down: bootstrap, deployment built from the production server and its
artifact and checkpoint ledgers, the 2B hard linked at the resolved path,
a UTF-8 hex signing key under `state/web-token.key`, `qwen-apu serve
--model qwen38-2b-distill --port 18099 --daemon`, a wait on the server's
`/health`, and `qwen-apu gateway --port 18090 --upstream-port 18099
--file-root <tree>/docs` at nice 19. Production relaunched afterwards with
`qwen-lan-launch.sh lan-authenticated low-async` and reported
`state=running`.

| Check | Result |
| --- | --- |
| `GET /` | 200, one `type="module"` tag, `js/chat.js` and `app.css` 200 |
| Content-Security-Policy | `default-src 'none'; script-src 'self'; style-src 'self'; ...` with no hash source |
| unauthenticated `POST /api/chat` | 401 |
| pairing with the printed code | 200 |
| `GET /api/models` | 13 models |
| `POST /api/models/tokenize` | four tokens for a four-word text |
| prompt 1 | `control plane ok`, reasoning present |
| prompt 2 | empty content; the reasoning consumed the 48-token budget as in the first pass |
| prompt 3 | `Oslo` |
| `POST /api/documents` (text/plain, 89 bytes) | 201, `sha256` record, one chunk |
| `GET /api/documents/<sha256>` | 200 |
| `POST /api/documents/<sha256>/search` `capital` | 200, one hit at `line:3` |
| `POST /api/conversations` saved and temporary | 201 and 201, both listed |
| `GET /api/conversations/export` | the saved conversation alone |
| mid-stream abort after 2 s | `/api/health` 200, next request answered `Oslo` |
| `qwen-apu stop` | `state=stopped`, exit 0, no listener on 18090 or 18099 |
| decode rate, this window | 3.29 to 3.55 tok/s |

The three prompt answers equal the first pass's answers against the same
checkpoint, so the split page's routes carry the same request the router
served. The decode rate sits at a third of the first pass's 9.46 to 9.51 on
the same binary, policy argv, and checkpoint; the machine had run the
production router at 60 to 70 percent GPU busy and 79 degrees C into the
minute before the window, and the figure stands as one observation for an
in-sweep read beside the production router's own 1.70 to 2.68.

Four windows the same day ended on the command side and every one
relaunched production: the checkpoint linked under `models/production/`
where the root resolves `models/<publisher>/`; the signing key absent; the
signing key random bytes where the reader requires UTF-8 text; and the
prompts sent before the server had loaded the model, which the wait on
`/health` closes. Each defect names a precondition the gateway or the serve
path reports rather than assumes, and the worktree was removed after the
pass.
