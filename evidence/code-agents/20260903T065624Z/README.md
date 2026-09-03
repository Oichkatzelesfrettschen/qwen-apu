# The 4B distill on three coding tasks, over the Anthropic Messages route

## What this measures

`remote/measure-code-agent-tasks.py` sends one non-streamed
`POST /v1/messages` turn per task with a standard-library client, so the
measurement covers the route a coding agent uses while the agent harness itself
stays out of the arm. Each turn carries the task prompt, the fixture's context
files where it has any, `max_tokens` 2048, `temperature` 0, and
`chat_template_kwargs.enable_thinking: false`, which
`server_chat_convert_anthropic_to_oai` passes through to the template. The reply
is graded by execution: the client extracts the single fenced block the prompt
demands, writes it as the task's target file in a throwaway workspace holding
the fixture's own tests, and runs `python3 -m unittest discover` there.

The three tasks are `remote/test-fixtures/code-agent-tasks/`:

- `task-01-write` writes `duration.py` from a specification, with the tests
  covering combined units, whitespace, eight malformed inputs, and a repeated
  unit.
- `task-02-fix` repairs a `rolling_mean` that averages `size - 1` samples and
  returns one window fewer than `rolling_max`. The shipped workspace fails its
  own tests with three failures and one error, so the arm measures a repair
  rather than a rewrite of something already correct.
- `task-03-refactor` collapses three copies of one scaling loop in `report.py`
  behind a single helper. The graded property is behavior preservation, since
  the tests pin every returned string and both `main` return codes; the record
  carries `baseline_target_lines` beside `reply_lines` so a reply that deleted
  the duplication is visible, and a reply that changed nothing would also pass.

Each fixture ships a hand-written reference answer under `reference/`, and
`measure-code-agent-tasks.py --self-check` grades those answers through the same
extraction and execution path. All three pass, which is what proves the tests
reachable independent of any model.

## Result

| Task | Outcome | Tests | Wall s | Prompt tokens | Completion tokens |
| --- | --- | --- | ---: | ---: | ---: |
| task-01-write | not run | not run | - | - | - |
| task-02-fix | not run | not run | - | - | - |
| task-03-refactor | not run | not run | - | - | - |

The three arms are `not run`. The appliance answered no `GET /health` for the
whole session: `curl` returned exit 7 on every attempt against port 8080, and
`tmux ls` on the laptop reported no server running on its socket, so the router
was down rather than loading. This lane starts and stops the appliance through
its own launch and teardown scripts alone, so the measurement waits for a launch
rather than making one, and the wait ended with the session.

The paths the arms would have exercised are proven independently.
`measure-code-agent-tasks.py --self-check` grades all three reference answers
through the same extraction and execution path and passes, the shipped
`task-02-fix` workspace fails its own tests before repair, and both
`remote/test-code-agent-endpoint.sh` and the measurement client complete against
a local Anthropic-shaped fixture endpoint. What the appliance would add is the
model's own reply, and that is the part no substitute supplies.

## Reading the numbers

Wall time is a wall-clock observation of one turn on a shared machine, not a
rate. CLAUDE.md measures 4% of uncontrolled spread on a repeated depth-0 rate at
rest and 30.6% under desktop load, and states that a difference below about 20%
quoted from single arms reports queue position. These are three single arms of
three different prompts, so the times order nothing and support no comparison
between tasks or against another checkpoint.

The token counts carry no such caveat. `input_tokens`, `output_tokens`, and
`cache_read_input_tokens` come from the `usage` object
`server_task_result_cmpl_final::to_json_anthropic` builds from the server's own
counters, and `count_tokens_input_tokens` comes from
`POST /v1/messages/count_tokens` tokenizing the same prompt through
`tokenize_mixed`. They are exact.

`tests_passed` is the outcome that answers the question the arm was built for,
and it is binary per task.

## Sanitization

Following CLAUDE.md, the Git copy writes the appliance's private hostname as
`qwen-laptop`, replaces the home prefix with `$HOME`, and writes MAC addresses
as `<mac>`. The bearer the client authenticates with lives at
`$HOME/qwen-webui-state/api.key` on the laptop, reaches the workstation as a
0600 file outside this repository, and appears in no record here: the retained
JSON carries prompts, replies, timings, and counts alone.

## What remains unmeasured

The hosted fallback is unmeasured. No OpenRouter key exists in this repository
or on either machine, and none was obtained, so the free-tier lane in
`docs/code-agents.md` rests on OpenRouter's published limits alone with no
latency, no token count, and no task outcome behind it.

Claude Code itself is unmeasured against the appliance. The configuration in
`tools/code-agents/claude-code.env.example` is verified against Anthropic's
documented environment variables and gateway protocol, and no session has run
through it here; a multi-turn agent loop on a 3 tok/s backend spends its time
differently than one scripted turn per task, and nothing in this directory
bounds that.

OpenCode's resident memory on the workstation is unmeasured for the same
reason: measuring it means running a session, and no session has run. The
installed executable is 134 MiB at version 1.2.27.

Three tasks are three tasks. They probe writing from a specification, repairing
a stated defect, and preserving behavior across a refactor, at prompt sizes
under a thousand tokens; they say nothing about a repository-scale context, a
multi-file edit, or a task where the model chooses what to read.
