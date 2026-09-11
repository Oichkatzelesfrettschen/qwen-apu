# Shadow deployment receipt: the Python stack beside production

Window `pyctl-shadow2` on the laptop, 2026-09-11, ran the current `main`
(Phases 1 to 5 merged) from a git worktree with its own runtime root while
production stood torn down: bootstrap, native bundle staged from the deployed
server and production tool builds, the three core checkpoints hard linked,
deployment built and activated, `qwen-apu serve --model qwen38-2b-distill
--port 18099 --daemon`, and `qwen-apu gateway --port 18090 --upstream-port
18099` at nice 19. Production relaunched afterwards with
`qwen-lan-launch.sh lan-authenticated low-async` and the same three prompts
ran against its router at temperature 0 with 48 tokens.

| Check | Result |
| --- | --- |
| unauthenticated `POST /api/chat` | 401 |
| pairing with the printed code | 200, HttpOnly cookie |
| `GET /api/models` | 13 models |
| prompt 1 content and reasoning, Python against production | equal (`control plane ok`) |
| prompt 2 | equal (empty content; the reasoning consumed the 48-token budget on both) |
| prompt 3 | equal (`Oslo`) |
| mid-stream abort after 2 s | server health ok, next request answered |
| `qwen-apu stop` | exit 0, server pid gone, no listener, lease free |
| decode rate, Python arm | 9.46 to 9.51 tok/s |
| decode rate, production router, same checkpoint | 1.70 to 2.68 tok/s |

The two decode rates come from different sessions and machine states, so
they stand as two observations rather than a comparison; the production
figure sits well below the checkpoint's registry rate and is worth its own
in-sweep read.

Two earlier windows the same day failed on the command side and were
restored: the first shadow command named a flag the merged `main` lacks and
left the supervised server running, so the window's relaunch refused a
device already serving; the script now releases the server and the gateway
from an exit trap on every path. Every window since relaunched or was
relaunched by hand, and the laptop worktrees were removed after each.
