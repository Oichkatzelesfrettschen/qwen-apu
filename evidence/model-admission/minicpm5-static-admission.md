# Static admission: the MiniCPM5-1B stock and Fable5 V2 Q8_0 artifacts

`remote/admit-candidate-static.py` reads both candidates' headers over an HTTP
range request against a pinned revision, without fetching either artifact's
weights.

```sh
python3 remote/admit-candidate-static.py openbmb/MiniCPM5-1B-GGUF \
    3d55fac80935ae6456986ad2384b5cbcc4d6c948 --file MiniCPM5-1B-Q8_0.gguf
python3 remote/admit-candidate-static.py \
    GnLOLot/MiniCPM5-1B-Claude-Opus-Fable5-V2-Thinking-GGUF \
    1c5821260e77c42e0b350f0248fabcf3c90ecade \
    --file MiniCPM5-1B-Claude-Opus-Fable5-V2-Thinking-Q8_0.gguf
```

## Identity

| field | stock MiniCPM5-1B | Fable5 V2 |
| --- | --- | --- |
| repository | openbmb/MiniCPM5-1B-GGUF | GnLOLot/MiniCPM5-1B-Claude-Opus-Fable5-V2-Thinking-GGUF |
| revision | 3d55fac80935ae6456986ad2384b5cbcc4d6c948 | 1c5821260e77c42e0b350f0248fabcf3c90ecade |
| artifact | MiniCPM5-1B-Q8_0.gguf | MiniCPM5-1B-Claude-Opus-Fable5-V2-Thinking-Q8_0.gguf |
| artifact_bytes | 1153529216 | 1153529184 |
| artifact_sha256 (LFS oid) | 0dc7638539067268774c275a14a6ec9c7e01f7eeb2cff606c8590361fa527e4c | fc3ee1eddd305c155f63b6bd7bb189daa4d5f226ca325ab219bd7acd3b00ec77 |
| architecture | llama | llama |
| block_count | 24 | 24 |
| embedding_length | 1536 | 1536 |
| feed_forward_length | 4608 | 4608 |
| attention.head_count | 16 | 16 |
| attention.head_count_kv | 2 | 2 |
| context_length | 131072 | 131072 |
| nextn_layers | 0 | 0 |
| vocabulary_size | 130560 | 130560 |
| tokenizer_pre | llama-bpe | minicpm5 |
| tokens_sha256 | d8048736f4df501a44afea3a64b22d7e0a5e9d6d8d24c270f8ed38feba4b26c4 | d8048736f4df501a44afea3a64b22d7e0a5e9d6d8d24c270f8ed38feba4b26c4 |
| chat_template_sha256 | 7451a05cf1e28a79d97d7c0bc951028c0b1915119bf9046acd06a0e3d931f47c | 7451a05cf1e28a79d97d7c0bc951028c0b1915119bf9046acd06a0e3d931f47c |
| chat_template_bytes | 9062 | 9062 |
| loaded_tensor_bytes | 1148393472 | 1148393472 |
| skipped_mtp_bytes | 0 | 0 |

The architecture fingerprint, tensor byte count, vocabulary, and token-array
digest match exactly, so the Fable5 fine-tune changes weights inside an
unchanged MiniCPM5-1B structure. The tokenizer's `tokenizer.ggml.pre` metadata
key differs: the stock repository records `llama-bpe`, while the fine-tune
records `minicpm5`. The shared token-array digest proves vocabulary-table
identity. Static admission does not prove identical token IDs for prompt text;
that stronger behavioral claim requires a pinned prompt corpus through both
tokenizer configurations.

## Chat template

Both artifacts carry the same template byte for byte (`chat_template_sha256`
7451a05c...47c, 9062 bytes), read with `--print-chat-template`. The GnLOLot
model card states this directly: the Fable5 V2 fine-tune "keeps MiniCPM5's
native chat template embedded in the GGUF files."

`chat_template_kwargs.enable_thinking` gates the generation prompt in both
files:

```jinja
{%- if add_generation_prompt %}
    {{- '<|im_start|>assistant\n' }}
    {%- if enable_thinking is defined %}
        {%- if enable_thinking is false %}
            {{- '<think>\n\n</think>\n\n' }}
        {%- elif enable_thinking is true %}
            {{- '<think>\n' }}
        {%- endif %}
    {%- endif %}
{%- endif %}
```

`enable_thinking is false` closes the thinking block before the assistant
turn opens, so the appliance's thinking-off request reaches a template branch
that honors it. `admit`'s regex scan reports `enable_thinking=True` and
`thinking_block=True` for both rows, consistent with the source.

## Tool-call template shape and the unclassified runtime boundary

The template's `tools` branch is present in both files (`tools=True` in the
static scan), and it does define a `tool_calls` key in its Jinja source
(`tool_calls=True`), but the regex match on the literal string `tool_calls`
does not classify llama.cpp runtime compatibility. The branch emits an XML-like
`<function name="...">...</function>` block inside the assistant message's
rendered content.

```jinja
{%- if message.tool_calls %}
    ...
    {{- '<function name="' ~ tool_call.name ~ '">' }}
    {%- if tool_call.arguments %}
        {%- for param_name, param_value in args_dict.items() %}
            {{- '<param name="' ~ param_name ~ '">' }}
            ...
            {{- '</param>' }}
        {%- endfor %}
    {%- endif %}
    {{- '</function>' }}
{%- endif %}
```

The system-prompt injection instructs the model to answer with the same XML
shape. A server-side parser and grammar decide whether llama.cpp converts that
text into the OpenAI-compatible `tool_calls` response field. The retained
static scan does not load `llama-server`, select a parser, sample a call, or
inspect the response object, so runtime compatibility remains `unclassified`
for both artifacts. A classification requires an exact server build, parser
selection, grammar, request, raw response, and expected structured result.

## What this stage does not measure

A ranged read reports what the file declares. It does not load the model, run
a completion, or prove the described tool-call XML round-trips through the
`llama.cpp` grammar sampler; those are load-admission and quality-suite
questions this stage never reaches.
