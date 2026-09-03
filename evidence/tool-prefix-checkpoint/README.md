# The schema-bound prefix checkpoint

A served web turn carries a stable head: the chat template's preamble, the
system prompt, and the tool schemas `webui/index.html` composes from
`GET /tools?model=<id>&autoload=true`. The retained notes measure three schemas
adding 507 tokens and about 26.5 seconds of prefill on this device. This
directory registers what llama-server at the pinned commit already reuses of
that head, where it recomputes it, what the Gated DeltaNet recurrent state
forces, the key a retained prefix state is bound by, the candidate patch that
retains one, and the arms that would measure it.

Every line reference below reads the source at
`f280b26983ad0fdb705a0d9ebf0503e76f2899b0` with the eight production members of
`remote/llama-patch-series.tsv` applied, which
`remote/prepare-llama-vulkan-source.sh BASE SCRATCH` reproduces and
`remote/verify-llama-patch-series.sh` pins at
`tools/server/server-context.cpp` SHA-256
`3744317beb622feff234e5b7a615c50665579f34ce49921e324bcd418fb3a58a`. No arm ran
on the appliance; the whole of the analysis is source, and the measurement
design at the end is unrun.

## The appliance runs on one slot with the prompt cache off

`remote/qwen-capacity-policy.sh` passes `--parallel 1` and `--cache-ram 0`.
`server-context.cpp:1269` constructs `prompt_cache` only where
`cache_ram_mib != 0`, so on the appliance the pointer stays null,
`get_available_slot` reaches `update_cache = update_cache && prompt_cache` at
1544 and saves and loads nothing, and `server-context.cpp:1338` turns
`cache_idle_slots` off for the same reason. Everything
`server_prompt_cache::alloc` and `::load` do in `server-task.cpp:1711` and
`:1793` -- the `f_keep < 0.25f` skip at 1813 included -- is inert here.

One slot and no prompt cache leave exactly one carrier of state between
requests: `slot.prompt`, holding the token array and
`std::list<common_prompt_checkpoint> checkpoints`.

## The hybrid memory decides which branch update_slots takes

Qwen3.5 is hybrid. `llama-model.cpp:2444` filters its layers into an attention
half and a recurrent half, and the retained appliance logs report
`print_info: n_swa = 0`
(`evidence/depth-validation-32k-projector/qwen35-2b/d32768-b128-ub32-proj.server.log:96`),
so `llama_memory_hybrid` rather than `llama_memory_hybrid_iswa` is constructed
and `server-context.cpp:1151` leaves `n_swa` at 0.

`llama_memory_hybrid::seq_pos_min` at `src/llama-memory-hybrid.cpp:172` returns
the **maximum** of its two halves, and
`llama_memory_recurrent::seq_pos_min` at
`src/llama-memory-recurrent.cpp:367` scans cells of which a sequence owns one,
whose `pos` is the latest position written. A hybrid sequence therefore reports
`seq_pos_min == last position`, where a pure attention cache reports 0. That one
value decides the branch at `server-context.cpp:3233`: `pos_min >= pos_min_thold`
is true for every rollback on this architecture, so a diverging request always
enters the checkpoint search, and the search result rather than cache residency
decides how many tokens survive.

`llm_arch_supports_rs_rollback` at `src/llama-arch.cpp:1032` lists
`LLM_ARCH_QWEN35`, so `common_context_can_seq_rm` (`common/common.cpp:1583`)
would report `COMMON_CONTEXT_SEQ_RM_TYPE_RS` under a positive `n_rs_seq`. That
budget comes from `common_params_speculative::need_n_rs_seq`
(`common/common.h:386`), which returns `draft.n_max` only for the MTP, EAGLE3,
DFLASH, and DSPARK draft types, so an ordinary appliance launch runs at
`n_rs_seq = 0` and `llama_memory_recurrent::seq_rm` refuses every partial
rollback at `src/llama-memory-recurrent.cpp:187`. The recurrent state is a
single vector at one position; it is restored or recomputed, and there is no
third answer.

## The three cases

Write `P` for the shared head (template preamble, system prompt, tool schemas),
`U1` and `U2` for two user messages, and `X` for a request sharing no head.

### (a) Same slot, the request extends what the slot holds

`n_past = slot.prompt.tokens.get_common_prefix(input_tokens)` at
`server-context.cpp:3103` reaches the whole of the slot's array. `pos_next`
equals the slot's own end, `pos_min_thold` equals it too, and `pos_min` is one
below it, so `pos_min >= pos_min_thold` at 3233 is false and the checkpoint
block is skipped entirely. `keep_first(n_past)` at 3298 truncates nothing,
`slot.mem.seq_rm(slot.id, p0, -1)` at 3328 removes nothing, and the fill loop
at 3408 processes the new tokens alone. `[TAG_PROMPT_LOGITS]` at 3287 gives back
one token so the batch is non-empty. Everything before the new turn is reused,
both halves of the memory, with no checkpoint involved.

### (b) A new conversation on the same slot, same head, different user message

`get_common_prefix` returns `|P|`. `has_new_tokens` is true, so
`pos_min_thold = pos_next = |P|` (3181), and `pos_min` is the slot's last
position, so the search at 3235 runs.

The head is where a checkpoint already sits, and the message spans are what put
it there. The fill loop breaks at a user message start (3434), and
`common_chat_msg_spans::last_user_message_pos` (`common/chat.h:182`) makes the
break unconditional at the last one, so the batch after `P` begins at
`n_tokens_start == |P|`; `is_last_user_message` is true at 3460 and
`do_checkpoint` survives 3496, so `create_checkpoint` at 3504 records
`n_tokens = |P|`, `pos_min = pos_max = |P| - 1` (2245). The predicate at 3245
accepts it: `pos_max <= pos_next` and `pos_min < pos_min_thold`, the second by
exactly one. `load_tgt` at 3253 restores it, `n_past` returns to `|P|` at 3259,
and the request prefills `U2` alone.

The spans are a property of the request rather than of the server.
`server-context.cpp:4392` reads `message_delimiters` out of the request body and
defaults it to an empty array, `server-common.cpp:1350` writes it there from
`chat_params.message_delimiters` on the OAI-compatible chat path alone, and
`common/chat.cpp:1188` fills that field in
`common_chat_params_init_qwen3_coder`, the specialized template the dispatcher
at `common/chat.cpp:3590` selects for a source carrying `<tool_call>`,
`<function=`, and `<parameter=` and whose comment names Qwen3.5. That handler
declares `<|im_start|>user` and `<|im_start|>system` delimiters, so a request
whose template takes that branch carries both spans. The served checkpoints'
own template text is unread here, and the server log names the branch it
selected, so an arm reads that line rather than assuming this one.
A raw `/completion` request carries no
delimiters, `is_user_start` is false everywhere, `last_user_message_pos` is -1,
no batch boundary lands at the head, and neither the existing checkpoint nor the
pin below is created. A template falling through to the differential autoparser
at `common/chat.cpp:3716` gets user and assistant delimiters and no system one,
which leaves the break intact and the system span empty.

The restore carries the recurrent half alone. `create_checkpoint` saves with
`LLAMA_STATE_SEQ_FLAGS_PARTIAL_ONLY` at 2247, which `include/llama.h:903`
defines as partial states such as SWA or recurrent caches, and the attention
cells for `[0, |P|)` are reused because they are still resident: `seq_rm` at
3328 removes from `pos_next` upward and never below it.

So the head is already reused across conversations at the pinned commit. The
condition is narrow: the checkpoint list must still hold a checkpoint at or
below the divergence point.

### (b') A new conversation after an unrelated request

`X` reaches `get_common_prefix == 0`, so `pos_next` is 0, the erase loop at 3274
removes every checkpoint with `pos_max > 0` -- the head's included -- and 3328
clears the memory. The next request sharing `P` finds an empty checkpoint list
and a slot holding `X`, takes `do_reset` at 3249, and reprefills `P` from token
0. One intervening request is enough to lose the head.

`--ctx-checkpoints 2` bounds the list the same way from the other side:
`create_checkpoint` erases the front while `checkpoints.size() >= 2` (2228), so
a conversation that creates two checkpoints deeper than the head evicts it.

### (c) Same tool schemas, a different system prompt

Divergence lands inside `P`. `pos_next` is the divergence point, the head's
checkpoint has `pos_max = |P| - 1 > pos_next` and is rejected by the first
clause at 3242, no earlier checkpoint exists, and `do_reset` at 3263 sets
`n_past = 0`. The request recomputes every token, the shared preamble ahead of
the divergence included, even though the attention cells for those positions are
resident.

That is the recurrent state speaking. An attention KV cache can be truncated at
any position; a Gated DeltaNet state at position `k` carries no record of
position `j < k`, so reuse below a divergence point requires a snapshot taken at
or below it and nothing else will do. Case (c) is the clean falsifier of that
model: any partial reuse there means the memory does not work the way this
document says it does.

## What the tool schemas cost is not separately visible

The server receives a rendered token array and a delimiter list; the tool
schemas enter that array through the Jinja template and reach no field of their
own. Where the template renders them inside the system block, the system span
digest carries them; where it renders them elsewhere, the prefix token digest
carries them. Both digests are fields of the key, so the key is correct either
way and only the attribution of which field moves changes. A caller that needs
the tool set digested apart from the system prompt supplies its own field.

The consequence for measurement is that arm C changes the system prompt with the
tool set held fixed by construction, which
`GET /tools?model=<id>&autoload=true` gives for free, and the arm therefore
measures a system-prompt change rather than a joint one.

## The key

`tools/server/server-prefix-checkpoint.h`, added by
`patches/llama-server-prefix-checkpoint.patch`, derives one SHA-256 over
length-prefixed named fields:

| field | source | what a change means |
| --- | --- | --- |
| `model` | `params_base.model.path`, `llama_model_desc`, `llama_model_n_params` | another checkpoint |
| `template` | digest of the default and `tool_use` sources from `common_chat_templates_source` | another rendering of the same messages |
| `runtime` | `n_ctx`, `n_batch`, `n_ubatch`, both cache types, flash attention, checkpoint count, checkpoint min step | another layout for the state bytes |
| `build` | `llama_commit()` and `llama_build_number()` | another private encoding of the state blob |
| `system` | digest of the tokens of the system span | another system prompt or another tool set |
| `prefix` | digest of the whole retained prefix token array | any change ahead of the last user message |
| `n_prefix_tokens` | length of that array | a truncation is a different key |

The key labels the pin; `server_prefix_checkpoint::covers` guards it by
comparing the pinned token array against the request element by element, so a
digest collision moves no state. Within one server process the model, template,
runtime, and build fields are constants, so they are recorded rather than
enforced there; they are what a persisted pin would need.

That division is why two further inputs are refused rather than keyed. A
per-request lora scale map and a speculative draft context each decide the
retained bytes while leaving the prefix tokens identical, and `covers` admits a
restore on the tokens alone, so a key field naming either would label the pin
without guarding it. The pin is process-scoped and `slot.lora` is per request:
`construct_lora_list` at `server-context.cpp:1601` copies
`params_base.lora_adapters` and rescales by index, `launch_slot_with_task` at
1620 clears `slot.prompt` for a changed adapter set and leaves this pin
standing, and the next request reproducing the tokens would restore a state
computed under the previous scales. A draft context carries state the pin does
not hold at all: `create_checkpoint` at 2247 saves `ctx_tgt`, `ctx_dft`, and the
speculative boundary stash together and the restore at 3253 loads all three,
while the pin holds `ctx_tgt` alone.

The server therefore disarms the pin at startup where `ctx_dft` is non-null or
`params_base.lora_adapters` is non-empty, states each condition on its own
`SRV_WRN` line so a launch meeting both reports both, and restates the lora half
per request through one predicate over `slot.lora` that the fill partition, the
capture, and the restore all read, so the three sites cannot diverge. `ctx_dft`
is the exact predicate for the speculative half:
`common_speculative_impl_draft_eagle3` at `common/speculative.cpp:424` overrides
`get_state` and `set_state` at 870 and 887 and is the only implementation that
does, and `common_speculative_init` at 2461 admits every draft-loading
implementation only where `params.draft.ctx_dft` is non-null. An n-gram
speculator leaves `ctx_dft` null, returns no state from
`common_speculative_get_state` at 2745, and has its drafts verified against the
target, so it stays armed. `--spec-type draft-simple` and `draft-mtp` both set
`ctx_dft`, so a `remote/draft-pairs.tsv` section and the pin are mutually
exclusive inside one server process; in router mode `server-models.cpp` spawns
every child from the `base_env` snapshot, so `QWEN_PREFIX_CHECKPOINT` reaches
all of them and the draft-pair child alone disarms. An empty `slot.lora` leaves
`alora_invocation_start` at -1, since `lora_all_alora` at
`server-common.cpp:133` reports false over an empty list, so the same predicate
carries the alora caching rule the restore previously stated for itself.

`remote/test-prefix-checkpoint-key.sh` compiles the header out of the patch and
checks the SHA-256 against the two standard vectors, the token digest against
`hashlib` over the same little-endian packing, the key framing against an
independent Python derivation, per-field sensitivity for all seven fields, and
that a byte moved across a field boundary changes the key.

## The candidate patch

`patches/llama-server-prefix-checkpoint.patch` is registered `candidate` in
`remote/llama-patch-series.tsv` and reaches no production build. It retains one
whole sequence state, saved with `LLAMA_STATE_SEQ_FLAGS_NONE`, at the boundary
the fill loop already stops at, and restores it for any request whose tokens
start with the pinned array.

The full-state save is the point. A partial checkpoint carries the recurrent
half and reads the attention cells out of a slot that case (b') has already
cleared, so pinning one against the erase loop would restore a recurrent state
at `|P|` over attention cells holding `X` -- an answer rather than a failure,
the shape of the foreign-projector hazard this repository already guards. The
restore therefore runs after `slot.prompt_clear()`, which empties the sequence
before the blob is written, and a failed write leaves an empty sequence rather
than a mixed one.

The capture proves its own invariant rather than inheriting one. A blob is the
prefix's state only where the memory holds exactly the tokens the pinned array
will carry, so the capture requires
`llama_memory_seq_pos_max(llama_get_memory(ctx_tgt), slot.id)` to equal
`n_tokens_start - 1`, at a site where `create_checkpoint` settles for a
`pos_min` and `pos_max` that are consistent with each other and with nothing
else. A capture whose recurrent state sat one batch ahead of its own token array
would restore an answer rather than fail.

`QWEN_PREFIX_CHECKPOINT` arms it, and an unset, empty, or `0` value leaves every
hook inert, as does a launch carrying a draft context or a loaded lora adapter,
for the reasons the key section states. The mechanism is independent of
`--ctx-checkpoints`: the fill loop's break at the last user message is what puts
a batch boundary at the pin's own boundary, and the patch admits that break
where the admission predicate holds while leaving the `do_checkpoint` spacing
rule at 3438 untouched. The break reads that same predicate rather than the
armed flag, so a refused configuration leaves the stock fill partition instead
of adding a third execution shape that captures nothing.

Arming the pin changes the fill partition where the checkpoint count is 0, since
a batch then ends at a user start that would otherwise have run on. An armed run
and an unarmed run are two execution shapes, so the control for a measurement is
an armed run whose prefix the pin does not hold, not an unarmed run. The
natural-boundary result establishes what a changed fill partition can move:
`evidence/ctx-checkpoint-sweep/` measured the 0.8B emitting a different token at
zero-based index 25 under the forced partition the eighth production patch
removes.

## The constraint a candidate build carries

`remote/build-llama-preset.sh` writes `checkpoint_semantics=natural-boundary-v1`
only where the compiled `tools/server/server-context.cpp` hashes to
`3744317b...`, and `remote/qwen-capacity-policy.sh` refuses a positive
`--ctx-checkpoints` against any other declaration, restated at the exec boundary
by `remote/qwen-build-exec-guard.sh`. This patch rewrites that file, so a build
carrying it declares `unknown` and admits `--ctx-checkpoints 0` alone.
`patches/llama-server-vulkan-workload-lease.patch` rewrites the same file and
carries the same constraint, so this is the standing shape of a
server-context.cpp candidate rather than a new problem.

Two consequences for the arms. The pin arm runs at count 0, which the mechanism
was built to allow. The production-build baseline arm runs the promoted
`natural-boundary-v1` server at the ledger's count of 2 through the ordinary
launch chain, so the two arms differ in build and in count together; a
count-0 arm on the candidate build with the pin disarmed separates them. The
candidate build reaches the device through an explicit `QWEN_LLAMA_SERVER`,
which is the recovery mode the bundle layer leaves alone.

## The measurement design

Three request arms against one server, each a `POST /v1/chat/completions` at
temperature 0 with a short reply budget, read from `timings.prompt_n` (tokens
decoded), `timings.cache_n` (tokens reused), and `timings.prompt_ms`.

| arm | build and count | request | reused tokens |
| --- | --- | --- | --- |
| A | either | conversation 1: head `P`, user `U1`, from a cold slot | 0 |
| B-production | promoted `natural-boundary-v1`, count 2 | conversation 2: head `P`, user `U2`, sent next | `\|P\|` |
| B-candidate | candidate, count 0, pin armed | the same pair | `\|P\|` |
| B'-production | promoted, count 2 | A, then `X` with its own head, then head `P`, user `U3` | 0 |
| B'-candidate | candidate, count 0, pin armed | the same triple | `\|P\|` |
| D-control | candidate, count 0, pin armed and pin disarmed | arm A alone, run both ways | 0 both ways |
| C | either | conversation 4: same tool schemas, a different system prompt, user `U4` | 0 |

The two B rows measure two mechanisms rather than one arm on two builds.
B-production is served by the context checkpoint the fill loop already places at
the last user message, which case (b) needs no patch for. B-candidate runs at
count 0, where `do_checkpoint` is false and no such checkpoint exists, so it is
served by the pin alone. A passing B-candidate confirms the pin and says nothing
about case (b), and the pair separating would say the count rather than the pin
carried B.

Predictions, stated before any run:

- A: `cache_n = 0`, `prompt_n = |P| + |U1|`. This is the denominator every other
  arm is read against, and the head is the retained 507 tokens at about 26.5 s.
- B-production: `cache_n = |P|`, `prompt_n` at `|U2|` scale rather than `|P|`
  scale, from the checkpoint mechanism.
- B-candidate: the same numbers from the pin.
- B'-production: `cache_n = 0` and a second full head prefill, because the
  intervening `X` erases the checkpoint and clears the slot.
- B'-candidate: `cache_n = |P|`. This is the arm the patch exists for, and the
  B' pair is the reported result.
- D-control: `cache_n = 0` both ways, and the two runs are read for emitted token
  identity rather than for reuse. Arming the pin ends a batch at the last user
  message that would otherwise have run on, so the two runs are two execution
  shapes and the comparison states whether that partition change moves the
  answer, the way `evidence/ctx-checkpoint-natural-boundary/` states it for the
  checkpoint count. It runs on the candidate build alone, so the build is held
  and the arming is the one changed dimension.
- C: `cache_n = 0` and `prompt_n = |P'| + |U4|` on every build. Partial reuse in
  C refutes the recurrent-state account above and the pin's `covers` predicate
  together.

`remote/measure-served-decode.sh` and the request-window discipline of the
census campaign supply the timing method; a rate is read inside one sweep,
because this machine spans 30.6% between sweeps under desktop load
(`evidence/decode-bound-analysis.md`) and about 4% at rest
(`evidence/measurement-state-and-memory-clock.md`). The head prefill difference
the arms resolve is of order 26 s against a sub-second suffix, far outside that
spread, so the ratio between B' arms is the reported quantity and the absolute
seconds are reported beside it.

Class order is the 2B first, the 0.8B second, and the 4B third, which is the
order `CLAUDE.md` sets for a general runtime experiment and the class policy
this repository already applies to prompt-cache checkpoints. The result becomes
a Raven2-wide default only where the three classes agree; a win on one class
alone becomes that class's profile setting.

## Falsifiers

- Arm C shows any reuse. The recurrent-state account is wrong and the whole
  design rests on a false premise.
- Arm B on the production build at count 2 shows `cache_n = 0`. Case (b) does not
  hold, and the reason is either an `n_swa` other than the retained 0, a chat
  template whose spans place no user start at `|P|`, or a checkpoint evicted by
  a path this analysis missed.
- A served turn carries no user-start span at `|P|`. The pin shares the existing
  checkpoint's dependence on `message_delimiters`, so a request routed through a
  template the dispatcher does not specialize, or a request sent to `/completion`
  rather than `/v1/chat/completions`, captures nothing and reuses nothing. The
  server log states which specialized template it selected, and the arm reads it
  rather than assuming Qwen3.5 took the `qwen3_coder` branch.
- Arm B' with the pin armed shows `cache_n = |P|` and an answer that differs from
  the same request served cold. The restore is writing state that does not
  describe the prefix, and the patch is unsafe rather than slow.
- The D-control pair differs in emitted tokens. Arming the pin then moves the
  answer through the fill partition alone, and the mechanism costs correctness
  before it buys anything, which is what the eighth production patch removed for
  the checkpoint count.
- The captured state exceeds what the carve-out tolerates. The blob size is
  unmeasured; the capture line reports it in MiB at every capture, and a size
  that competes with the model's own residency ends the design rather than
  tuning it.
- A server log carries `captured prefix checkpoint` or `restored prefix
  checkpoint` while it also carries `prefix checkpoint refuses a draft context`
  or `prefix checkpoint refuses N loaded lora adapter(s)`. The disarm is not
  exact, and a restore then advanced `n_past` to the pinned prefix over state
  the pin never held. The two refusals are logged from the same requested arm
  rather than from a running total, so a process meeting both prints both lines
  and each predicate is read on its own.
- A launch that loaded no adapter and no draft model logs either refusal line.
  The predicates are wider than the source says, and the arms measure the
  unpinned path while reading as though they measured the pin. Every arm above
  reads the arming and refusal lines before it reads a timing.
- An arm against a `remote/draft-pairs.tsv` section reports `cache_n = |P|` with
  `QWEN_PREFIX_CHECKPOINT` set. The pin is disarmed in that child, so the reuse
  came from the context checkpoint the count already places and the arm
  attributes it to the wrong mechanism.

## What did not run

- No arm ran on the appliance. The laptop is owned by another session for the
  duration of this work, and every claim above about llama-server's behavior is
  read from the source rather than from a served request.
- The state blob size for a 507-token prefix is unmeasured on this architecture.
  `llama_state_seq_get_size_ext` under `LLAMA_STATE_SEQ_FLAGS_NONE` returns the
  attention cells for the prefix plus the whole recurrent state of every
  recurrent layer, and the second term is independent of the prefix length.
- The candidate build was compiled and linked in the workstation container and
  loaded no model. `llama-server` links, `libllama-server-impl.so` carries the
  key derivation and both log lines, and nothing executed.
- Both refusals are read from the source rather than from a log. No launch
  carrying a draft context or a loaded adapter has run against this build, so
  the `SRV_WRN` lines the falsifiers above read are unobserved and the exactness
  of `ctx_dft` and `params_base.lora_adapters` as predicates rests on the
  reading of `common_speculative_init` and `construct_lora_list`.
