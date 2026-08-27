#!/bin/sh
set -eu

# The repository Web UI is the fallback when the separately built llama-ui is
# absent. Router mode exposes only preset ids, so the fallback must derive its
# request model from /v1/models and never send the single-model qwen-apu alias.

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
fallback_ui=$script_directory/../webui/index.html

grep -F '<select class="model-picker" id="model-picker"' "$fallback_ui" >/dev/null
grep -F "fetch('./v1/models'" "$fallback_ui" >/dev/null
grep -F 'model: requestModel' "$fallback_ui" >/dev/null
grep -F 'model: selectedModel, content: text, add_special: false' \
    "$fallback_ui" >/dev/null
grep -F "if (!selectedModel) throw new Error('no routable model is selected')" \
    "$fallback_ui" >/dev/null
grep -F "modelIds.includes(storedModel) ? storedModel : modelIds[0]" \
    "$fallback_ui" >/dev/null
grep -F "readBrowserStorage('localStorage', 'qwen-apu-model-id')" \
    "$fallback_ui" >/dev/null
grep -F "writeBrowserStorage('localStorage', 'qwen-apu-model-id', requestModel)" \
    "$fallback_ui" >/dev/null
grep -F 'const generation = ++bootGeneration' "$fallback_ui" >/dev/null
grep -F 'if (generation !== bootGeneration) return' "$fallback_ui" >/dev/null

if grep -E '(localStorage|sessionStorage)\.(getItem|setItem|removeItem)' \
    "$fallback_ui" >/dev/null; then
    printf 'fallback Web UI bypasses storage-denial handling\n' >&2
    exit 1
fi

if grep -E "model: ['\"]qwen-apu['\"]" "$fallback_ui" >/dev/null; then
    printf 'fallback Web UI still sends the single-model compatibility alias\n' >&2
    exit 1
fi

printf 'fallback_webui_model_selection=accepted\n'
