# Vision review control: real, withheld, swapped, real

`remote/run-vision-review-control.sh` ran the four arms registered in
`evidence/image-appliance/vision-review-control-design.md` on the appliance
through the served model id `qwen-apu` beside an `image-service.py` artifact
listener. The retained files do not bind that served id to an immutable model
or record the process launch and teardown sequence, so the standalone
`lfm25-vl-16b` attribution remains the operator's unverified run annotation.
`chain-note.md` separates the recovered inputs from the run-level fields that
were not retained. Artifact A is the fox
(`17e452e6...`), artifact B the apple (`7c6b7565...`), prompt hash
`c59aebad...`. The operator annotation names two declared constraints:
`prompt_subject=one fox in a snowy field` and
`background_plain=the background is plain and uncluttered`. Every
arm sent `--no-prompt-cache`, temperature 0, 400 reply tokens, no `tools`
key. `arms/` retains `summary.tsv`, `audit.log`, and the raw reply, stdout,
stderr, and parsed verdict of each arm.

| arm | image sent | prompt_subject | background_plain | regenerate | prompt_delta | wall s |
| --- | --- | --- | --- | --- | --- | ---: |
| 01-real | A | passed: "A fox is standing in the snow." | passed | no | - | 35.49 |
| 02-withheld | none | failed: "The image does not contain a fox." | passed | no | "Add a fox in a snowy field." | 20.02 |
| 03-swapped | B | passed: "A red apple with a bite taken out of it is shown on a plain white background." | passed | no | - | 37.27 |
| 04-real-closing | A | passed: "A fox is standing in the snow." | passed | no | - | 36.07 |

## Reading against the registered falsifiers

The opening and closing real arms carry identical verdicts and observations.
That endpoint agreement does not measure a real request at sequence positions
2 or 3, so a position, predecessor, or warm-state effect remains possible. The
four rows therefore describe the registered order alone; they do not isolate
the intermediate differences as image effects.

Falsifier 1 is not met on the subject constraint: with no pixels the model
fails `prompt_subject` and names the absence. It is met on the background
constraint, which the withheld arm passes with the same sentence the real arm
writes. That equality is consistent with an answer derived from the constraint
text, but the fixed-text sequence does not identify the answer's source.

Falsifier 2 is met in its second form. The swapped arm's
observation describes B -- a bitten red apple on white -- so the pixels reach
the model, and the same verdict marks `prompt_subject` passed for "one fox in
a snowy field". The row establishes an inconsistency between the observation
and the flag. Every arm holds the constraint text fixed, while the same flag is
false in the withheld arm and true in both image-bearing arms, so these data do
not identify the cause of the flag or show that the flag follows the constraint
text. One sequence from one served model id cannot authorize automatic
regeneration.

## Consequence for the page

The CLI control uses `remote/image-review.py`, whose request carries a response
schema and disables prompt caching. The page builds a different schema-free
request, so this run establishes no page-driven reviewer behavior. In the page
implementation, a correction is admitted only when all three conditions hold:
a constraint fails, `regenerate` is true, and `prompt_delta` is non-empty. The
approval dialog remains the authority for an admitted proposal. A page-driven
arm or an aligned request is required before extending this CLI observation to
the page.

The withheld row took 20.02 seconds and the three image-bearing rows took
35.49 to 37.27 seconds in this sequence. The retained run lacks counterbalanced
positions and a process timeline, so the 15-to-17-second difference remains an
observed wall-time association rather than an isolated image-prefill cost.
