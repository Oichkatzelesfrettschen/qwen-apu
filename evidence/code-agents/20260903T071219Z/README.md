# The 4B distill on three coding tasks, over the Anthropic Messages route

## What this measures

`remote/measure-code-agent-tasks.py` sends one non-streamed
`POST /v1/messages` turn per task with a standard-library client, so the
measurement covers the route a coding agent uses while the agent harness stays
out of the arm. Each turn carries the task prompt, the fixture's context files
where it has any, `max_tokens` 2048, `temperature` 0, and
`chat_template_kwargs.enable_thinking: false`, which
`server_chat_convert_anthropic_to_oai` passes through to the template. The reply
is graded by execution: the client extracts the single fenced block the prompt
demands, writes it as the task's target file in a throwaway workspace holding
the fixture's own tests, and runs `python3 -m unittest discover` there. The
extracted source is retained beside each record as `<task>.produced.py`, because
a passing test states that the file behaves and states nothing about what the
model wrote.

The three tasks are `remote/test-fixtures/code-agent-tasks/`:

- `task-01-write` writes `duration.py` from a specification, with the tests
  covering combined units, whitespace, eight malformed inputs, and a repeated
  unit.
- `task-02-fix` repairs a `rolling_mean` that averages `size - 1` samples and
  returns one window fewer than `rolling_max`. The shipped workspace fails its
  own tests with three failures and one error, so the arm measures a repair
  rather than a rewrite of something already correct.
- `task-03-refactor` collapses three copies of one scaling loop in `report.py`
  behind a single helper. The tests pin every returned string and both `main`
  return codes, so they grade behavior preservation; whether the duplication
  went away is read from the retained source.

Each fixture ships a hand-written reference answer under `reference/`, and
`measure-code-agent-tasks.py --self-check` grades those answers through the same
extraction and execution path. All three pass, which is what proves the tests
reachable independent of any model.

## Result

Model `qwen38-4b-distill`, Qwen3.8-4B Distill Q4_K_M, served by the router on
the appliance. This sweep is the retained one; the pair column reports the same
arm from `../20260903T070320Z/` minutes earlier under identical flags.

| Task | Outcome | Tests | Wall s | Wall s, first sweep | Prompt tokens | Completion tokens |
| --- | --- | --- | ---: | ---: | ---: | ---: |
| task-01-write | extracted | pass | 150.161 | 149.885 | 280 | 397 |
| task-02-fix | extracted | pass | 113.537 | 110.315 | 726 | 211 |
| task-03-refactor | extracted | pass | 231.029 | 228.811 | 1016 | 501 |

Every arm ended on `stop_reason=end_turn` inside the 2048-token budget, emitted
exactly one fenced block, and passed its fixture's tests. Prompt and completion
token counts are identical across the two sweeps on all three tasks, and
`cache_read_input_tokens` is 0 throughout, so each turn tokenized and decoded
the whole prompt afresh.

`reasoning_emitted` is false on every arm, and the reply carried no `thinking`
content block. The template keyword therefore reaches the model through
`/v1/messages` and suppresses the reasoning span, which is the mechanism
`docs/code-agents.md` names and the reason a scripted client controls a cost
that Claude Code, which sends Anthropic's `thinking` block instead, leaves at
the template default.

The produced sources answer what the tests cannot. `task-02-fix` returned the
module with `range(len(values) - size + 1)` and a full-width window, which is
the stated defect repaired and nothing else touched. `task-03-refactor` returned
a `_format(value, units, divisor)` helper with the three public functions
delegating to it, so the duplication went away rather than the file coming back
unchanged; `produced_matches_baseline` is false on all three arms, which is the
check that would have caught the opposite.

## Reading the numbers

Wall time is a wall-clock observation of one turn, not a rate. CLAUDE.md
measures 4% of uncontrolled spread on a repeated depth-0 rate at rest and 30.6%
under desktop load, and states that a difference below about 20% quoted from
single arms reports queue position. The three prompts differ in size and the
three replies in length, so the times order the tasks by nothing and support no
comparison against another checkpoint.

The repeat pair bounds this machine's spread on these arms rather than
explaining it. The two sweeps agree to 0.18%, 2.9%, and 0.97%, all inside the 4%
this tree measures at rest, and the laptop carried a load average of 0.92 over
two cores with no other tenant during the run. Two sweeps minutes apart share a
machine state, so the agreement bounds short-interval repeatability and says
nothing about the 30.6% CLAUDE.md measures between sweeps under load.

The token counts carry no such caveat. `input_tokens`, `output_tokens`, and
`cache_read_input_tokens` come from the `usage` object
`server_task_result_cmpl_final::to_json_anthropic` builds from the server's own
counters, and `count_tokens_input_tokens` comes from
`POST /v1/messages/count_tokens` tokenizing the same prompt through
`tokenize_mixed`. They are exact, and their agreement across the two sweeps at
temperature 0 is what greedy decoding on this backend already predicts.

The two prompt figures count different things and the summary carries both.
`handle_count_tokens` returns the whole tokenization, while `to_json_anthropic`
sets `input_tokens` to `n_prompt_tokens - n_prompt_tokens_cache` and reports the
reused prefix separately, so `count_tokens_input_tokens` equals
`input_tokens + cache_read_input_tokens`. The count route tokenizes the message
content and the messages route charges the rendered chat template, which is the
two-token gap on every row.

`tests_passed` is the outcome the arms were built for, and it is binary per
task: three of three.

## Sanitization

Following CLAUDE.md, the Git copy writes the appliance's private hostname as
`qwen-laptop`, replaces the home prefix with `$HOME`, and writes MAC addresses
as `<mac>`. The records here name neither: the client stores prompts, replies,
timings, and counts, and the request origin stays out of the retained JSON. The
bearer the client authenticates with lives at `$HOME/qwen-webui-state/api.key`
on the laptop, reaches the workstation as a 0600 file outside this repository,
and appears in no record.

## What remains unmeasured

The hosted fallback is unmeasured. No OpenRouter key exists in this repository
or on either machine, and none was obtained, so the free-tier lane in
`docs/code-agents.md` rests on OpenRouter's published limits alone with no
latency, no token count, and no task outcome behind it.

Claude Code itself is unmeasured against the appliance. The configuration in
`tools/code-agents/claude-code.env.example` is verified against Anthropic's
documented environment variables and gateway protocol, and no session has run
through it here. A multi-turn agent loop spends its time differently than one
scripted turn per task: it re-sends a growing transcript, and these arms
measured a cold cache every time, so the prefix reuse that decides an agent
loop's cost on this hardware is untouched by them.

OpenCode's resident memory on the workstation is unmeasured for the same
reason: measuring it means running a session, and no session has run. The
installed executable is 134 MiB at version 1.2.27.

The other served rows are unmeasured on these tasks. Only `qwen38-4b-distill`
ran, so nothing here compares the 2B fast lane or the 0.8B against it, and the
registry's `raw_tool_selection` grades remain the only ordering between them.

Three tasks are three tasks. They probe writing from a specification, repairing
a stated defect, and preserving behavior across a refactor, at prompt sizes
around a thousand tokens; they say nothing about a repository-scale context, a
multi-file edit, or a task where the model chooses what to read.
