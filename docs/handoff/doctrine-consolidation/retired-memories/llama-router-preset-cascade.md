---
name: llama-router-preset-cascade
description: llama-server router CLI arguments overwrite the same key in every model preset, so per-model values must stay off the router argv
metadata:
  type: reference
---

`tools/server/server-models.cpp` ends its preset assembly with
`preset.merge(base_preset)` under the comment "overlay router's own CLI args on
top of every model preset", and `common_preset::merge` in `common/preset.cpp`
assigns rather than fills gaps. A router CLI argument therefore replaces the
same key in every `[section]` of the `--models-preset` INI.

The consequence is inverted from what the INI suggests: a per-model
`LLAMA_ARG_CTX_SIZE` is inert wherever the router argv also passes `--ctx-size`.
Per-model depth, cache triple, and submission geometry only take effect when the
router argv omits those flags entirely, which means every section must then
carry them, since an absent key falls through to the llama.cpp defaults of
`ctx 4096`, `batch 2048`, `ubatch 512`.

`unset_reserved_args` strips only the SSL, API-key, and `models-*` keys from the
base preset, so everything else cascades. Preset key names are the `set_env()`
names in `common/arg.cpp`: `LLAMA_ARG_BATCH` and `LLAMA_ARG_UBATCH`, not
`LLAMA_ARG_BATCH_SIZE`. An unrecognised key fails the whole router at startup
rather than being ignored.

See [[qwen-appliance-host]].
