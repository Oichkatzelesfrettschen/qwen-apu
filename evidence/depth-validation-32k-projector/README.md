# Projector-loaded depth campaign on the retained rollback server

`evidence/depth-validation-32k/` fills and decodes 8192, 16384, and 32768 on
five checkpoints through `llama-bench -d`, which takes no `--mmproj` and
allocates no projector buffers. Every arm it records reads
`projector_state=none`, so the two vision rows that require a projector in
serving, `qwen35-2b` and `lfm25-vl-16b`, kept `validated_filled_depth` at `-`
and `context_ceiling` at 8192 however many text-only arms accumulated there,
and `qwen35-4b-base` carried no depth arm at all.
`remote/probe-depth-projector.sh` measures the tuple those rows need: one
llama-server instance, standalone, at the row's own cache triple and
submission geometry, with the row's own projector attached through
`--mmproj`, filled by one chat completion carrying a fixture image plus text
padding and answered by one recovery question afterward.

## Falsifier registered before the arms ran

A vision row cannot claim a numeric `validated_filled_depth` from an arm that
did not load its projector. The prediction under test was that the served
128/32 geometry fills and decodes to 32768 with the projector resident and
that the projector still writes usable image tokens into the language model's
embedding space after the deep fill; a wedge, a reset, a fault, a fill outside
the acceptance window, or a control answer missing "JUN" at any depth would
have stopped the chain at the deepest arm that passed and left the row's
ceiling there. `probe-depth-projector.sh` enforces this: `device_corrupt` is
set on the first failed arm, and the loop over depths stops rather than
measuring a corrupted device at a greater depth.

## Terms

```text
runner:      remote/probe-depth-projector.sh
tuple:       q8_0 K, q4_0 V, Flash Attention on, batch 128, ubatch 32
threads:     1, threads-batch 1 (the served tuple's own submission thread
             count, distinct from the threads 2 the llama-bench text-only
             arms in evidence/depth-validation-32k/ recorded)
kernel:      7.0.0-29-generic
device:      RADV RAVEN2, whole device, standalone llama-server per arm
control:     bars.png, "Which bar is tallest in this chart? Reply with its
             label alone.", declared answer JUN
window:      DEPTH - 2% <= prompt_n <= DEPTH - decode_tokens (32)
health:      status ok, control_status ok, ring resets 0, GPU faults 0
```

Each arm's `prompt_n` is the server's own `timings.prompt_n` after the fill
request: the image contributes a token lump `/tokenize` cannot see, since that
route tokenizes text alone and the projector writes image tokens inside the
chat pipeline, so the harness measures the template-plus-image overhead with
one probe request and closes the remainder with text padding measured through
`/tokenize`.

## Results

`prompt_n`, `prefill_s`, and `decode tok/s` are `timings.prompt_n`,
`prompt_ms / 1000`, and `predicted_per_second` from the fill request's own
`/v1/chat/completions` response. These are standalone-server fills with one
image in the prompt at `--parallel 1`, not `llama-bench` rates: no repetition
count, no isolated prefill/decode phase split, and the image token cost is
inside `prompt_n` rather than reported separately.

| checkpoint | depth | prompt_n | prefill s | decode tok/s | control | resets | faults | health |
| --- | ---: | ---: | ---: | ---: | --- | ---: | ---: | --- |
| Qwen3.5-2B Q4_K_M | 8192 | 8041 | 219.165 | 6.386 | ok | 0 | 0 | healthy |
| | 16384 | 16231 | 568.193 | 6.391 | ok | 0 | 0 | healthy |
| | 32768 | 32632 | 1454.187 | 3.902 | ok | 0 | 0 | healthy |
| LFM2.5-VL-1.6B Q4_K_M | 8192 | 8042 | 199.712 | 10.158 | ok | 0 | 0 | healthy |
| | 16384 | 16248 | 504.125 | 8.353 | ok | 0 | 0 | healthy |
| | 32768 | 32616 | 1410.909 | 6.857 | ok | 0 | 0 | healthy |
| Qwen3.5-4B base Q4_K_M | 8192 | 8041 | 693.049 | 2.698 | ok | 0 | 0 | healthy |
| | 16384 | 16231 | 1241.084 | 2.318 | ok | 0 | 0 | healthy |
| | 32768 | 32632 | 3375.497 | 1.816 | ok | 0 | 0 | healthy |

## Historical executable boundary

All three `projector-identity.tsv` rows name `llama-server` SHA-256
`3d5b158160b08cf897bb05b47186a13f67e8a17def31012f2f8282f12e95cb08`.
`ARTIFACTS.md` identifies that executable as the retained four-patch rollback
server. The promoted five-patch server has SHA-256
`4117a9c4d58e530c3c5ef6934596ae6d257ca61ef80c5f0f8a5ee71d1d63ca79`.
The nine measurements therefore establish behavior for the rollback
executable alone. They do not validate filled depth, projector behavior, or a
serving ceiling for the promoted executable.

`remote/models.tsv` and `remote/web-profiles.tsv` consequently retain their
pre-campaign ceilings and carry `validated_filled_depth=-` for these three
projector-required models. The historical rows remain in
`remote/validated-tuples.tsv` with their evidence paths; their `validated`
status means that the recorded arm completed against the rollback executable,
not that the promoted executable inherits the result. An authentic rerun must
name the promoted server digest in `projector-identity.tsv` and retain the
summary, requests, clocks, kernel delta, and server log for every admitted
depth before the serving registries can promote these claims.

Every arm's `prompt_n` sits inside its acceptance window and every control
answers JUN. Every `.dmesg-method.txt` reads `follow`, so each `.dmesg.txt`
window is captured live rather than by an offset subtraction. Eight of the
nine windows are empty; the ninth, `qwen35-4b-base` at 32768, carries two
userif link-flap pairs and two `dm_irq_work_func` workqueue-latency warnings,
none of which the reset or fault patterns match, so the arm's own summary row
reads `ring_resets=0 gpu_faults=0` and the ledger's `classify_hazard` names it
`none`. The chain never halted, so no depth was left unmeasured behind a
failed arm.

## What the rows establish

For the retained rollback executable, a context of 32768 tokens allocated,
filled, and decoded with the projector resident on all three checkpoints at
the recorded cache triple and submission geometry. Each standalone session
also answered its recovery question afterward. The evidence does not transfer
that result across the executable-identity change to the promoted server.

Every historical arm's evidence path resolves to a directory under this one,
so `remote/model-registry.sh tuples MODEL_ID` returns nine rows across the
three model ids, each `status=validated` beside its subdirectory. The model
registry carries no numeric projector-loaded depth for those models until the
promoted executable satisfies the rerun intake condition above.

## Retained artifacts

Each of `qwen35-2b/`, `lfm25-vl-16b/`, and `qwen35-4b-base/` carries
`projector-summary.tsv` (the table above, source), `validated-tuples-rows.tsv`
(the rows appended to `remote/validated-tuples.tsv`), `projector-identity.tsv`
(one provenance row per invocation naming the llama-server, runner, sampler,
and control-image digests, the kernel release, and the argv), and
`wedge-metadata.tsv` (the model and projector SHA-256 and byte counts, cache
triple, submission geometry, decode length, fill margin, and control claim the
ledger binds every resumed row to). Each arm additionally carries its
`.server.log`, `.requests.txt` (the four dependent requests: probe, padding
tokenize, fill, control), `.clocks.tsv` (GPU clock and memory samples), and
`.dmesg.txt`/`.dmesg-method.txt` (the kernel delta and whether it was captured
by following the ring buffer or by an offset subtraction). Every path under
`$HOME` in these files is written literally as `$HOME`, matching this
repository's Git-copy sanitization rule.

## The router-child arm a review-only section requires

`remote/build-web-presets.sh` emits a review-only vision section for the
`review_model` an image row names, and it joins that model against
`remote/validated-tuples.tsv` on `runtime_mode=router-child` with
`projector_state=loaded` at the model's own registry tuple. Every row above is
`standalone`, because `remote/probe-depth-projector.sh` launched one
llama-server per arm with the tuple on its own argv. A standalone row leaves
that section ungenerated, so `image-sdxs-512-a` names `lfm25-vl-16b` as its
reviewer while the preset the appliance would serve carries one section rather
than two. `remote/check-validated-tuples.sh` reports that gap by name and
prints the arm that closes it.

`--runtime-mode router-child` measures the same geometry through the serving
path the section uses. The harness generates a one-section preset with
`remote/build-router-presets.sh` over a one-row copy of the registry whose
`context_default` is the arm's depth, stages the weights and the resolved
projector as symlinks so `select-projector.sh` answers with the same file the
standalone arm attaches, and launches `llama-server --models-preset ...
--models-max 1`. Depth, cache triple, submission geometry, checkpoint count,
and the projector stay off that argv, because `common_preset::merge` overwrites
each section key with the router argv's value of the same name; the section
carries all of them and the harness reads the generated file back before the
server starts. Each request names the section in the body's `model` key, since
`router_validate_model` resolves the child from it and `models_autoload`
defaults to true, so the first request of an arm loads the child inside the
arm's own request budget. The fill, the acceptance window, and the `bars.png`
control are the standalone arm's unchanged.

The unblocking run is the one depth the review section needs, which is
`lfm25-vl-16b`'s `context_default` of 8192:

```sh
QWEN_WEDGE_DEPTHS=8192 remote/probe-depth-projector.sh --runtime-mode router-child lfm25-vl-16b OUTPUT_DIRECTORY
```

On the appliance the runner is `~/qwen-laptop-setup/remote/probe-depth-projector.sh`
and `OUTPUT_DIRECTORY` is an absent path the run creates, for example
`~/qwen-webui-state/depth-validation-32k-projector-router/lfm25-vl-16b`. The
appliance serves nothing else while it runs: the harness refuses to start
beside another `llama-server` or `llama-bench`, and it refuses an occupied
`127.0.0.1:18087`. `QWEN_WEDGE_DEPTHS="8192 16384 32768"` runs the full ladder,
which measures more than the section needs and stops at the first failed arm.

A healthy arm appends one line to `validated-tuples-rows.tsv` in the output
directory, and that line is copied into `remote/validated-tuples.tsv` by hand
once the directory is retained under `evidence/depth-validation-32k-projector/`,
because a `validated` row requires its evidence path to exist in the tree. The
line reads `runtime_mode=router-child` and `projector_state=loaded` with the
tuple, backend, and evidence fields of the standalone line beside it; its
`tuple_id` carries a `-router` suffix, since the ledger keys on that column and
the two rows state one geometry measured through two serving paths. The output
directory retains `<arm>.router-preset.ini`, the generated section the arm
served under, beside the standalone artifacts.

The executable-identity condition above holds for this arm too: the run's
`projector-identity.tsv` must name the promoted server digest before
`remote/models.tsv` or `remote/web-profiles.tsv` promote any claim from it.
