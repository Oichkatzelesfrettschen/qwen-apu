# Conversational suite: web-off against web-on

Both arms grade the suite's rows in the row file's own order; the web-on arm runs only where a served web section reaches the model, and its `paired_delta_mean` is computed over the row ids both arms actually graded, named by `paired_count`.

| model_id | web_off_rows | web_off_correct_on_completed | web_off_mean_wall | web_off_p90_wall | web_on_status | web_on_reason | web_on_rows | web_on_correct_on_completed | web_on_mean_wall | web_on_p90_wall | tool_proposal_rate | approvals | results_produced | paired_count | paired_delta_mean |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| qwen38-4b-distill | 94 | 0.747 | 38.84 | 45.59 | failed | record_absent | - | - | - | - | - | - | - | 0 | - |
| qwen38-2b-distill | 94 | 0.548 | 23.57 | 46.73 | unavailable | execution_policy_refused | - | - | - | - | - | - | - | 0 | - |
| qwen35-4b-base | 94 | 0.830 | 40.37 | 67.04 | unavailable | execution_policy_refused | - | - | - | - | - | - | - | 0 | - |
| qwen35-08b | 94 | 0.533 | 5.72 | 7.74 | unavailable | execution_policy_refused | - | - | - | - | - | - | - | 0 | - |
| qwen35-2b | 94 | 0.681 | 14.77 | 34.88 | unavailable | execution_policy_refused | - | - | - | - | - | - | - | 0 | - |
| lfm25-vl-16b | 94 | 0.734 | 14.97 | 74.53 | unavailable | execution_policy_refused | - | - | - | - | - | - | - | 0 | - |
| qwen35-08b-f16 | 94 | 0.533 | 6.63 | 9.17 | unavailable | no_web_profile | - | - | - | - | - | - | - | 0 | - |
| qwen38-2b-uncensored | 94 | 0.554 | 23.20 | 36.46 | unavailable | no_web_profile | - | - | - | - | - | - | - | 0 | - |
| qwen35-2b-hauhau | 94 | 0.573 | 14.39 | 16.86 | unavailable | no_web_profile | - | - | - | - | - | - | - | 0 | - |
| qwen35-2b-unredacted | 94 | 0.595 | 14.04 | 15.24 | unavailable | no_web_profile | - | - | - | - | - | - | - | 0 | - |
| qwen35-2b-heretic | 94 | 0.649 | 27.13 | 47.11 | unavailable | no_web_profile | - | - | - | - | - | - | - | 0 | - |
| qwen35-08b-unsloth-unc | 94 | 0.587 | 6.56 | 12.21 | unavailable | no_web_profile | - | - | - | - | - | - | - | 0 | - |
| qwenseer-2b | 94 | 0.662 | 16.77 | 64.89 | unavailable | no_web_profile | - | - | - | - | - | - | - | 0 | - |

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
| qwen38-2b-distill | web-off | arithmetic | 8/10 |
| qwen38-2b-distill | web-off | code | 7/10 |
| qwen38-2b-distill | web-off | format | 8/10 |
| qwen38-2b-distill | web-off | long_context | 4/5 |
| qwen38-2b-distill | web-off | photo | 0/9 |
| qwen38-2b-distill | web-off | screen | 2/5 |
| qwen38-2b-distill | web-off | termination | 5/5 |
| qwen38-2b-distill | web-off | tool | 2/10 |
| qwen38-2b-distill | web-off | vision | 0/10 |
| qwen38-2b-distill | web-off | web_current | 0/10 |
| qwen38-2b-distill | web-off | word_problem | 4/10 |
| qwen35-4b-base | web-off | arithmetic | 9/10 |
| qwen35-4b-base | web-off | code | 9/10 |
| qwen35-4b-base | web-off | format | 9/10 |
| qwen35-4b-base | web-off | long_context | 5/5 |
| qwen35-4b-base | web-off | photo | 9/9 |
| qwen35-4b-base | web-off | screen | 5/5 |
| qwen35-4b-base | web-off | termination | 5/5 |
| qwen35-4b-base | web-off | tool | 10/10 |
| qwen35-4b-base | web-off | vision | 10/10 |
| qwen35-4b-base | web-off | web_current | 1/10 |
| qwen35-4b-base | web-off | word_problem | 6/10 |
| qwen35-08b | web-off | arithmetic | 4/10 |
| qwen35-08b | web-off | code | 5/10 |
| qwen35-08b | web-off | format | 6/10 |
| qwen35-08b | web-off | long_context | 5/5 |
| qwen35-08b | web-off | photo | 0/9 |
| qwen35-08b | web-off | screen | 5/5 |
| qwen35-08b | web-off | termination | 5/5 |
| qwen35-08b | web-off | tool | 9/10 |
| qwen35-08b | web-off | vision | 0/10 |
| qwen35-08b | web-off | web_current | 0/10 |
| qwen35-08b | web-off | word_problem | 1/10 |
| qwen35-2b | web-off | arithmetic | 5/10 |
| qwen35-2b | web-off | code | 9/10 |
| qwen35-2b | web-off | format | 7/10 |
| qwen35-2b | web-off | long_context | 5/5 |
| qwen35-2b | web-off | photo | 9/9 |
| qwen35-2b | web-off | screen | 3/5 |
| qwen35-2b | web-off | termination | 5/5 |
| qwen35-2b | web-off | tool | 8/10 |
| qwen35-2b | web-off | vision | 10/10 |
| qwen35-2b | web-off | web_current | 0/10 |
| qwen35-2b | web-off | word_problem | 3/10 |
| lfm25-vl-16b | web-off | arithmetic | 9/10 |
| lfm25-vl-16b | web-off | code | 7/10 |
| lfm25-vl-16b | web-off | format | 6/10 |
| lfm25-vl-16b | web-off | long_context | 4/5 |
| lfm25-vl-16b | web-off | photo | 9/9 |
| lfm25-vl-16b | web-off | screen | 4/5 |
| lfm25-vl-16b | web-off | termination | 5/5 |
| lfm25-vl-16b | web-off | tool | 8/10 |
| lfm25-vl-16b | web-off | vision | 9/10 |
| lfm25-vl-16b | web-off | web_current | 0/10 |
| lfm25-vl-16b | web-off | word_problem | 8/10 |
| qwen35-08b-f16 | web-off | arithmetic | 3/10 |
| qwen35-08b-f16 | web-off | code | 7/10 |
| qwen35-08b-f16 | web-off | format | 6/10 |
| qwen35-08b-f16 | web-off | long_context | 5/5 |
| qwen35-08b-f16 | web-off | photo | 0/9 |
| qwen35-08b-f16 | web-off | screen | 4/5 |
| qwen35-08b-f16 | web-off | termination | 5/5 |
| qwen35-08b-f16 | web-off | tool | 9/10 |
| qwen35-08b-f16 | web-off | vision | 0/10 |
| qwen35-08b-f16 | web-off | web_current | 0/10 |
| qwen35-08b-f16 | web-off | word_problem | 1/10 |
| qwen38-2b-uncensored | web-off | arithmetic | 7/10 |
| qwen38-2b-uncensored | web-off | code | 6/10 |
| qwen38-2b-uncensored | web-off | format | 9/10 |
| qwen38-2b-uncensored | web-off | long_context | 4/5 |
| qwen38-2b-uncensored | web-off | photo | 0/9 |
| qwen38-2b-uncensored | web-off | screen | 3/5 |
| qwen38-2b-uncensored | web-off | termination | 5/5 |
| qwen38-2b-uncensored | web-off | tool | 2/10 |
| qwen38-2b-uncensored | web-off | vision | 0/10 |
| qwen38-2b-uncensored | web-off | web_current | 0/10 |
| qwen38-2b-uncensored | web-off | word_problem | 5/10 |
| qwen35-2b-hauhau | web-off | arithmetic | 5/10 |
| qwen35-2b-hauhau | web-off | code | 6/10 |
| qwen35-2b-hauhau | web-off | format | 8/10 |
| qwen35-2b-hauhau | web-off | long_context | 4/5 |
| qwen35-2b-hauhau | web-off | photo | 0/9 |
| qwen35-2b-hauhau | web-off | screen | 2/5 |
| qwen35-2b-hauhau | web-off | termination | 5/5 |
| qwen35-2b-hauhau | web-off | tool | 9/10 |
| qwen35-2b-hauhau | web-off | vision | 0/10 |
| qwen35-2b-hauhau | web-off | web_current | 0/10 |
| qwen35-2b-hauhau | web-off | word_problem | 4/10 |
| qwen35-2b-unredacted | web-off | arithmetic | 5/10 |
| qwen35-2b-unredacted | web-off | code | 7/10 |
| qwen35-2b-unredacted | web-off | format | 8/10 |
| qwen35-2b-unredacted | web-off | long_context | 4/5 |
| qwen35-2b-unredacted | web-off | photo | 0/9 |
| qwen35-2b-unredacted | web-off | screen | 4/5 |
| qwen35-2b-unredacted | web-off | termination | 5/5 |
| qwen35-2b-unredacted | web-off | tool | 9/10 |
| qwen35-2b-unredacted | web-off | vision | 0/10 |
| qwen35-2b-unredacted | web-off | web_current | 0/10 |
| qwen35-2b-unredacted | web-off | word_problem | 3/10 |
| qwen35-2b-heretic | web-off | arithmetic | 10/10 |
| qwen35-2b-heretic | web-off | code | 7/10 |
| qwen35-2b-heretic | web-off | format | 3/10 |
| qwen35-2b-heretic | web-off | long_context | 4/5 |
| qwen35-2b-heretic | web-off | photo | 0/9 |
| qwen35-2b-heretic | web-off | screen | 5/5 |
| qwen35-2b-heretic | web-off | termination | 5/5 |
| qwen35-2b-heretic | web-off | tool | 5/10 |
| qwen35-2b-heretic | web-off | vision | 0/10 |
| qwen35-2b-heretic | web-off | web_current | 0/10 |
| qwen35-2b-heretic | web-off | word_problem | 9/10 |
| qwen35-08b-unsloth-unc | web-off | arithmetic | 7/10 |
| qwen35-08b-unsloth-unc | web-off | code | 5/10 |
| qwen35-08b-unsloth-unc | web-off | format | 6/10 |
| qwen35-08b-unsloth-unc | web-off | long_context | 5/5 |
| qwen35-08b-unsloth-unc | web-off | photo | 0/9 |
| qwen35-08b-unsloth-unc | web-off | screen | 2/5 |
| qwen35-08b-unsloth-unc | web-off | termination | 5/5 |
| qwen35-08b-unsloth-unc | web-off | tool | 9/10 |
| qwen35-08b-unsloth-unc | web-off | vision | 0/10 |
| qwen35-08b-unsloth-unc | web-off | web_current | 0/10 |
| qwen35-08b-unsloth-unc | web-off | word_problem | 5/10 |
| qwenseer-2b | web-off | arithmetic | 6/10 |
| qwenseer-2b | web-off | code | 8/10 |
| qwenseer-2b | web-off | format | 7/10 |
| qwenseer-2b | web-off | long_context | 5/5 |
| qwenseer-2b | web-off | photo | 0/9 |
| qwenseer-2b | web-off | screen | 3/5 |
| qwenseer-2b | web-off | termination | 5/5 |
| qwenseer-2b | web-off | tool | 9/10 |
| qwenseer-2b | web-off | vision | 0/10 |
| qwenseer-2b | web-off | web_current | 0/10 |
| qwenseer-2b | web-off | word_problem | 6/10 |
