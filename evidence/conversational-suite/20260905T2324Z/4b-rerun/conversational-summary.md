# Conversational suite: web-off against web-on

Both arms grade the suite's rows in the row file's own order; the web-on arm runs only where a served web section reaches the model, and its `paired_delta_mean` is computed over the row ids both arms actually graded, named by `paired_count`.

| model_id | web_off_rows | web_off_correct_on_completed | web_off_mean_wall | web_off_p90_wall | web_on_status | web_on_reason | web_on_rows | web_on_correct_on_completed | web_on_mean_wall | web_on_p90_wall | tool_proposal_rate | approvals | results_produced | paired_count | paired_delta_mean |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| qwen38-4b-distill | 94 | 0.747 | 33.71 | 38.52 | failed | - | 65 | 0.746 | 185.58 | 189.59 | 0.015 | 1 | 0 | 65 | -0.046 |

## Category breakdown

| model_id | arm | category | passed/attempted |
|---|---|---|---|
| qwen38-4b-distill | web-off | arithmetic | 9/10 |
| qwen38-4b-distill | web-off | code | 8/10 |
| qwen38-4b-distill | web-off | format | 9/10 |
| qwen38-4b-distill | web-off | long_context | 5/5 |
| qwen38-4b-distill | web-off | photo | 0/9 |
| qwen38-4b-distill | web-off | screen | 5/5 |
| qwen38-4b-distill | web-off | termination | 5/5 |
| qwen38-4b-distill | web-off | tool | 9/10 |
| qwen38-4b-distill | web-off | vision | 0/10 |
| qwen38-4b-distill | web-off | web_current | 0/10 |
| qwen38-4b-distill | web-off | word_problem | 6/10 |
| qwen38-4b-distill | web-on | arithmetic | 9/10 |
| qwen38-4b-distill | web-on | code | 9/10 |
| qwen38-4b-distill | web-on | format | 9/10 |
| qwen38-4b-distill | web-on | long_context | 0/5 |
| qwen38-4b-distill | web-on | screen | 5/5 |
| qwen38-4b-distill | web-on | termination | 5/5 |
| qwen38-4b-distill | web-on | web_current | 2/10 |
| qwen38-4b-distill | web-on | word_problem | 5/10 |
