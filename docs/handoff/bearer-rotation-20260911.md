# Bearer rotation receipt

The production Web UI bearer, `state/api.key` under the laptop's runtime
root, was rotated on 2026-09-11 after a shell trace exposed it. Running a
scratch comparison script under `sh -x` echoed every expanded command line
into the agent's tool output, and one line carried the `Authorization`
header built from the key file. The output reached the agent session alone;
no file, commit, log, or peer received it.

`qwen-webui-session.sh` generates the key when the file is absent
(`openssl rand -hex 32`, mode 0600) and hands the path to `llama-server`,
the approval broker, and the artifact listener at startup, so the rotation
ran as teardown, removal of the one file, and relaunch through
`qwen-lan-launch.sh lan-authenticated low-async`.

| Field | Value |
| --- | --- |
| trace source | `sh -x` over a scratch comparison script |
| exposure scope | one agent session's tool output |
| old key SHA-256 | `8df972230a76f3892ee92967079920e08e667adefdaea91594805b1c7addf9a7` |
| new key SHA-256 | `c77314a8780d2bcc399c445393eca06fdd187c4aaa9c7ae90d45021052713e92` |
| router `GET /v1/models`, old key | 401 |
| router `GET /v1/models`, new key | 200 |
| artifact listener, old key | 401 |
| artifact listener, new key | 404 for an absent name, past the bearer gate |
| broker `POST /grant`, old key | 403 naming the bearer refusal |
| broker `POST /grant`, new key | 403 naming the session secret, past the bearer gate |
| production after relaunch | `state=running`, new broker pid |

The regression lives in `qwen_apu.ci.ratchet`: a subprocess argv in the
package never carries a shell trace flag, and `os.environ` never reaches a
print, log, or serializer whole, so a command echo or an environment dump
cannot carry a secret into output the way the trace did.
