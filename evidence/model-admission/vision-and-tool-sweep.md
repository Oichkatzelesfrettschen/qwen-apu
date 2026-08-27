# The vision and tool categories across the roster

`evidence/model-admission/roster-quality-sweep.md` grades 55 text rows and
leaves two claims the registry makes untested. Three rows carry
`projector: required` and no graded evidence that the projector path answers
about an image; every row is offered to a picker whose user may attach a tool
schema, and no row has been measured on whether it selects one. This sweep
grades both through the same router listener the appliance already serves.

## Terms

```text
endpoint:      http://127.0.0.1:8080, router mode, --models-max 1
thinking:      off, through chat_template_kwargs.enable_thinking
token budget:  1024
sampling:      temperature 0, top_k 1, seed 1
geometry:      batch 128, ubatch 32, q8_0/q4_0, Flash Attention on, from the
               preset file rather than the router argv
priority:      nice 19
suite:         remote/quality-suite.tsv, categories `vision` and `tool`
fixtures:      remote/quality-images/, drawn by remote/generate-quality-images.py
tool sets:     remote/quality-tools.json
```

## Nothing is executed on the tool path

The appliance runs without `--tools`, so the server holds no tool server and
runs no command. A tool row puts a schema in the request body's `tools` field
and grades the `tool_calls` object the model emits. Tool selection is therefore
measured with the read-only boundary intact rather than relaxed for the
measurement, and `remote/test-qwen-capacity-policy.sh` and
`remote/test-model-tiers.sh` continue to refuse a tool grant on both argv paths
and in the preset file.

## The ground truth is drawn rather than found

`remote/generate-quality-images.py` declares what each fixture holds and then
draws it: `bars.png` is four bars whose tallest is JUN at 150 because the
generator's `heights` table says so. A photograph or a downloaded chart would
put the answer in a reader's judgement, which is what the graded suite exists to
remove.

The fixtures are committed and the generator's `--check` compares **pixels**
rather than file bytes. Deflate is not reproducible across hosts: zlib 1.3 on
the appliance re-encodes 7 of the 8 fixtures to different bytes than the
workstation wrote, with identical pixels. Inflate is fully specified where
deflate leaves the match search to the implementation, so decoding both sides
and comparing pixels tests the claim a fixture makes and a digest comparison
tests the encoder.

## The control the vision rows need

A vision row is only a vision measurement if the image is what answers it. Some
of these questions have priors -- a chart's tallest bar is guessable, a serial
number is not -- so the same ten rows run against the same checkpoint with the
image withheld and everything else identical. `--omit-images` is that arm.

## Registered before any arm ran

| # | prediction | falsifier |
| --- | --- | --- |
| 1 | The vision rows are not answerable from the prompt alone | the image-withheld control scores 4 or more of 10 |
| 2 | LFM2.5-VL-1.6B leads both Qwen vision rows on the vision category | either Qwen vision row scores at or above LFM's vision total |
| 3 | Every servable row emits a syntactically valid tool call on tool-01, the single-tool row with one obvious argument | any arm emits no call or unparseable arguments on tool-01 |
| 4 | Tool selection separates the roster more than the text suite did, whose 4B rows tied at 47 | the two 4B rows land within 1 row of each other on the tool category |
| 5 | The prompt-injection row is harder than the plain row it is built from | tool-08 passes on at least as many arms as tool-01 |

## The promotion gate these rows are being measured against

`lfm25-vl-16b` is the strongest unpromoted candidate: it decodes 15.87 tok/s
against the 2B distill's 9.19 and grades 43 of 55 against 40, while its 6 of 10
format column is the weakest of any servable row above the 0.8B. It is a
candidate rather than production because text grading says nothing about the
projector its registry row requires.

It moves to `production` when, in this sweep:

1. it leads both Qwen vision rows on the vision category by 2 rows or more,
2. its image-withheld control confirms those rows read the image,
3. its tool category is within 2 rows of the best servable row, and
4. no arm records a device fault, reset, or loss.

Any of those unmet leaves it `candidate` with the specific gap named, because a
faster checkpoint that answers about images and mis-selects tools is a different
artifact from one that does neither.

`qwen35-2b` is measured on the same rows. Its case is narrower: it is within 1
row of the 2B distill on text and 2.6% on decode, so vision is the only
dimension on which it could earn a place the roster does not already hold.

## Results

Not yet run.
