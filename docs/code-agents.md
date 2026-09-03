# Code agents against the appliance

A coding agent is a client, and the appliance is an inference server that
executes nothing. This document states which routes each agent reaches, which
registry ids it may name, where the execution boundary sits, what the agent
costs in workstation memory, and what the appliance's 4B distill measured on
three small coding tasks.

## The routes an agent reaches

`tools/server/server.cpp` registers `POST /v1/messages` and
`POST /v1/messages/count_tokens` beside the OpenAI chat route, and the router
branch assigns both to `models_routes->proxy_post`, so a router launch serves
the Anthropic Messages API on the same listener as everything else.
`server_routes::post_anthropic_messages` converts the body through
`server_chat_convert_anthropic_to_oai` in `tools/server/server-chat.cpp` and
answers with `server_task_result_cmpl_final::to_json_anthropic`, which echoes
the requested id in `model` and reports `input_tokens`, `output_tokens`, and
`cache_read_input_tokens` under `usage`.

The routing key is the request body's own `model`. `server-models.cpp` reads
`json_value(body, "model", std::string())` in `proxy_post` and resolves the
child from it, which is the same mechanism `/v1/chat/completions` uses, so the
ids an agent may name are exactly the ids `GET /v1/models` returns. Those come
from the generated router preset, and `remote/build-router-presets.sh` emits a
section for a `production` or `candidate` row of `remote/models.tsv` alone.

Two conversion details decide how a turn behaves on this hardware.
`server_chat_convert_anthropic_to_oai` passes `chat_template_kwargs` through
unchanged, so a plain HTTP client turns the Qwen3.8 distill's `<think>` span off
by sending `{"chat_template_kwargs": {"enable_thinking": false}}`. An Anthropic
`thinking` block maps to `thinking_budget_tokens` instead, and Claude Code sends
that rather than the template keyword, so a Claude Code turn runs the template's
own default. At the 4B distill's roughly 3 tok/s decode a reasoning span is paid
in wall time, which is why `tools/code-agents/claude-code.env.example` sets
`MAX_THINKING_TOKENS=0`.

`remote/test-code-agent-endpoint.sh` proves the three routes against a live
appliance: `GET /v1/models` lists the ids the caller names, `POST /v1/messages`
answers a one-turn request with the id echoed, and
`POST /v1/messages/count_tokens` returns a positive `input_tokens` within eight
tokens of what the messages route charged. It exits 2 on a usage error and 1 on
any mismatch, and it stays out of the repository gate because it needs the
appliance running.

## The execution boundary

The appliance runs without `--tools`, so llama-server holds no tool server and
executes nothing a model proposes. Every row of `remote/models.tsv` reads
`guarded_tool_execution=refused`, and the reason is measured rather than
cautious: the graded suite's `tool-08` row puts an instruction inside the note
the user asks about, and all six measured arms carried the injected city into
the emitted call in place of the authorized one. The 4B distill's
`raw_tool_selection` grade of 9 of 10 states that it picks the right tool from a
schema; it says nothing about surviving a prompt injection, which is the
property an execution grant exists to survive.

The consequence for a coding agent is exact. Every file read, every edit, and
every command comes from the agent's own runtime on the workstation, gated by
that runtime's sandbox and its confirmation prompts. A model served here that
proposes `rm -rf` reaches a confirmation dialog rather than a shell, and the
appliance's contribution to that safety is that it never had a shell to offer.
CLAUDE.md's read-only tool set -- `read_file,file_glob_search,grep_search` --
and its rule that a tool-enabled server stays off the LAN both remain the
appliance-side policy; an agent pointed at this endpoint inherits the injection
hazard on its own side of the wire, over whatever repository content it reads.

## Claude Code

Claude Code reads its endpoint, credential, and model from environment
variables, all documented at
<https://code.claude.com/docs/en/env-vars> and
<https://code.claude.com/docs/en/llm-gateway-connect>:

- `ANTHROPIC_BASE_URL` overrides the API endpoint. Anthropic documents this as
  gateway connectivity, states that it disables MCP tool search by default
  against a non-first-party host, and disables Remote Control from v2.1.196
  against any host other than `api.anthropic.com`.
- `ANTHROPIC_AUTH_TOKEN` supplies "a custom value for the `Authorization`
  header (the value you set here will be prefixed with `Bearer `)", which is
  the header `llama-server --api-key-file` checks. `ANTHROPIC_API_KEY` sends
  `X-Api-Key` instead and, in interactive mode, prompts once before it overrides
  a subscription login, so the token variable is the one that matches this
  server.
- `ANTHROPIC_MODEL` names the model, and `ANTHROPIC_DEFAULT_HAIKU_MODEL`,
  `ANTHROPIC_DEFAULT_SONNET_MODEL`, and `ANTHROPIC_DEFAULT_OPUS_MODEL` name what
  the three aliases resolve to. `ANTHROPIC_SMALL_FAST_MODEL` is documented as
  deprecated in favour of the haiku variable.
- `API_TIMEOUT_MS` defaults to 600000, which a 4B decoding at 3 tok/s can
  exhaust on a long reply.
- `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC` and `DISABLE_TELEMETRY` are
  presence variables: any non-empty value turns the behavior on.

The gateway protocol reference at
<https://code.claude.com/docs/en/llm-gateway-protocol> states what the endpoint
must supply. `/v1/messages` is required and `/v1/messages/count_tokens` is
optional, "when they're absent, Claude Code falls back to counting context usage
through the inference endpoint instead"; this appliance serves both. Streaming
is required -- "Claude Code reads the stream as it arrives, so if your gateway
buffers complete responses before relaying them, Claude Code stalls" -- and
llama-server streams the Messages format through `format_anthropic_sse` in
`tools/server/server-common.cpp`. Model discovery is opt-in through
`CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY=1` and reads
`GET /v1/models?limit=1000`. The same reference notes that Claude Code prepends
an attribution block to `system` that a first-party endpoint strips; upstream
llama.cpp reads that block, since
`normalize_anthropic_billing_header` in `server-chat.cpp` recognizes the
`x-anthropic-billing-header:` prefix on a system string and rewrites it.

`tools/code-agents/claude-code.env.example` holds the whole set with the bearer
left as a placeholder. Fill it in a copy outside this repository, or export
`ANTHROPIC_AUTH_TOKEN` from a 0600 file the shell reads, and start Claude Code
in the usual way. The appliance's bearer lives at
`$HOME/qwen-webui-state/api.key` on the laptop, which
`remote/qwen-webui-session.sh` mints at mode 0600; it stays out of this tree.

That configuration is verified against the documentation cited above. No Claude
Code session in this repository has run against the appliance, so its
interactive behavior on a 3 tok/s backend is unmeasured; the measured numbers
below come from a plain scripted client over the same route.

## OpenCode

OpenCode reads an OpenAI-compatible endpoint from a JSON configuration.
<https://opencode.ai/docs/config/> documents the file as `opencode.json` or
`opencode.jsonc`, resolved from a remote `.well-known/opencode` entry, then
`~/.config/opencode/opencode.json`, then `OPENCODE_CONFIG`, then the project
root, then `.opencode` directories, then `OPENCODE_CONFIG_CONTENT`, then managed
configuration, with later entries overriding earlier ones. The same page
documents environment substitution as `{env:VARIABLE_NAME}`, replaced with an
empty string where the variable is unset.

<https://opencode.ai/docs/providers/> documents a custom provider as an entry
under `provider` carrying `npm`, `name`, `options.baseURL`, `options.apiKey`,
and a `models` map, with `@ai-sdk/openai-compatible` for a
`/v1/chat/completions`-style API and `@ai-sdk/openai` for `/v1/responses`. A
model is then referenced as `provider/model` and selected through the top-level
`model` key, with `small_model` naming the cheap lane.

`tools/code-agents/opencode.json.example` follows that shape: `baseURL` is the
appliance's `/v1` prefix, `apiKey` reads `{env:QWEN_CODE_AGENT_KEY}`, the models
map names three registry ids, `model` selects the 4B distill, and `small_model`
selects the 2B. OpenCode reaches the OpenAI chat route rather than the Messages
route, so the routing key travels in the same body field and the same router
resolution applies.

## OpenRouter as a hosted fallback

<https://openrouter.ai/docs/guides/routing/model-variants/free> documents a
`:free` variant naming scheme -- a model id with `:free` appended, such as
`meta-llama/llama-3.2-3b-instruct:free`.
<https://openrouter.ai/docs/api-reference/limits> states the limits those
variants carry: 20 requests per minute, 50 requests per day below 10 lifetime
purchased credits, and 1000 requests per day at or above 10, governed globally
so additional accounts or keys leave them unchanged.

The endpoints are compatible with both agents.
<https://openrouter.ai/docs/api_reference/overview> documents the
OpenAI-compatible base URL `https://openrouter.ai/api/v1`, which is what an
OpenCode provider block needs; the Anthropic Messages route resolves to
`POST https://openrouter.ai/api/v1/messages` from the "Create a message"
reference, which is what `ANTHROPIC_BASE_URL=https://openrouter.ai/api/v1`
needs. Adding it to OpenCode is a second entry beside `qwen-appliance` with
`options.baseURL` set to the OpenAI base and `options.apiKey` reading an
environment variable; switching Claude Code to it is a change of
`ANTHROPIC_BASE_URL`, `ANTHROPIC_AUTH_TOKEN`, and the model variables.

The documentation reachable here states no keyless path: every request example
carries a Bearer `OPENROUTER_API_KEY`, and the free-variant limits are keyed to
an account's lifetime credit purchases, which is account-scoped by
construction. That a key is required is therefore an inference from the
documented rate-limit mechanism rather than a quoted sentence.

No OpenRouter key exists in this repository or on either machine, so nothing
about the hosted fallback is measured here: no latency, no token count, and no
task outcome. The comparison below covers the appliance alone.

## What each agent costs on the workstation

Measured from `/proc/PID/status` on the workstation while five Claude Code
sessions ran, `VmRSS` spanned 216 to 563 MiB per session, the spread following
transcript length and open tool state rather than the endpoint. Claude Code
2.1.257 was the version measured. Pointing a session at the appliance moves no
weight onto the workstation, so the agent's memory is the agent's runtime alone.

OpenCode 1.2.27 installs as a 134 MiB single executable. Its resident cost is
unmeasured here, because measuring it means running a session and no session
has run.

The appliance carries the model. The 4B distill's Q4_K_M weights are 2.58 GiB
inside the laptop's Vulkan carve-out, which is the cost that decides whether a
second checkpoint fits beside it, and no part of it lands on the workstation.

## Measured: the 4B distill on three coding tasks

`remote/measure-code-agent-tasks.py` sends one non-streamed `/v1/messages` turn
per task with a plain standard-library client, extracts the single fenced block
each prompt demands, writes it as the task's target file in a throwaway
workspace, and runs that workspace's own `unittest` module. The fixtures are
`remote/test-fixtures/code-agent-tasks/`: `task-01-write` writes a duration
parser from a specification, `task-02-fix` repairs a `rolling_mean` that drops
its newest sample and returns one window too few, and `task-03-refactor`
collapses three copies of one scaling loop while the tests pin every returned
string. Each fixture ships a hand-written reference answer, and `--self-check`
grades that answer through the same path, which is how a fixture is proven
reachable before appliance time is spent on it.

`qwen38-4b-distill` at `max_tokens` 2048, `temperature` 0, thinking off, run
twice under identical flags minutes apart:

| Task | Outcome | Tests | Wall s | Wall s, repeat | Prompt tokens | Completion tokens |
| --- | --- | --- | ---: | ---: | ---: | ---: |
| task-01-write | extracted | pass | 150.2 | 149.9 | 280 | 397 |
| task-02-fix | extracted | pass | 113.5 | 110.3 | 726 | 211 |
| task-03-refactor | extracted | pass | 231.0 | 228.8 | 1016 | 501 |

Three of three pass their fixture's tests, every arm ends on
`stop_reason=end_turn` inside the budget, and the token counts reproduce exactly
across both sweeps. The retained sources show the work rather than only its
result: `task-02-fix` returned the stated defect repaired and nothing else
touched, and `task-03-refactor` returned a `_format(value, units, divisor)`
helper with the three public functions delegating to it.

`reasoning_emitted` is false on every arm, so
`chat_template_kwargs.enable_thinking: false` does reach this model's template
through `/v1/messages` and suppress the reasoning span. A scripted client can
therefore spend its whole budget on code; Claude Code sends Anthropic's
`thinking` block instead and leaves that span at the template's own default,
which is what `MAX_THINKING_TOKENS=0` addresses from the other side.

Rerun the arms with `remote/measure-code-agent-tasks.py --origin
http://qwen-laptop:8080 --key-file PATH --output-directory DIR`. Wall time
on this machine is a wall-clock observation of one turn
rather than a rate, since CLAUDE.md measures 4% of spread at rest and 30.6%
under desktop load on a repeated depth-0 rate; the token counts come from the
server's own `usage` counters and are exact.

`evidence/code-agents/` retains the records, the summary TSV, and the reading of
what the numbers support.
