# Vision review control: real, withheld, swapped, real

`remote/run-vision-review-control.sh` ran the four arms registered in
`evidence/image-appliance/vision-review-control-design.md` on the appliance
against `lfm25-vl-16b` served standalone (model id `qwen-apu`) beside a
standalone `image-service.py` artifact listener. Artifact A is the fox
(`17e452e6...`), artifact B the apple (`7c6b7565...`), prompt hash
`c59aebad...`, two declared constraints: `prompt_subject=one fox in a snowy
field` and `background_plain=the background is plain and uncluttered`. Every
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

Falsifier 3 is not met: the opening and closing real arms carry identical
verdicts and observations, so arms 2 and 3 are read as image effects.

Falsifier 1 is not met on the subject constraint: with no pixels the model
fails `prompt_subject` and names the absence. It is met on the background
constraint, which the withheld arm passes with the same sentence the real arm
writes; a constraint phrased as a property every plain render has is answered
from the constraint text.

Falsifier 2 is met in its second form and is the finding. The swapped arm's
observation describes B -- a bitten red apple on white -- so the pixels reach
the model, and the same verdict marks `prompt_subject` passed for "one fox in
a snowy field". The observation and the `passed` flag are produced by
different processes: the observation is grounded in the image and the flag
follows the constraint text. A verdict's `passed` therefore states what the
model reads in the constraint, not whether the observation satisfies it, and
one review at 1.6B cannot be the authority for an automatic regeneration.

## Consequence for the page

The reviewer stays advisory. `webui/index.html` already admits a correction
only on a failed constraint, the `regenerate` flag, or a non-empty
`prompt_delta`, and every one of those is a proposal behind the same approval
dialog, so no automatic path exists to close. What this run adds is that a
passing verdict is not evidence of conformance: the card shows the
observation text beside each flag so the human reads the sentence rather than
the boolean. A grader that compares the observation against the constraint
is a second model call over text and belongs to the review lane's next arm,
with `qwen35-2b` as the in-sweep control the design names.

Withheld review at 20.02 s against 35 to 37 s with an image measures the
image part of the prompt at about 15 s of prefill, matching the 14.77 s the
paired-review admission recorded.
