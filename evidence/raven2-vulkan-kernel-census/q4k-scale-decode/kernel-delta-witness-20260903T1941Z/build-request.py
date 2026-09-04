import json
import sys

prompt_path, predict, seed, top_count = sys.argv[1], int(sys.argv[2]), int(sys.argv[3]), int(sys.argv[4])
with open(prompt_path, "r", encoding="utf-8") as handle:
    prompt_text = handle.read()
json.dump(
    {
        "prompt": prompt_text,
        "n_predict": predict,
        "temperature": 0,
        "top_k": 1,
        "seed": seed,
        "ignore_eos": True,
        "cache_prompt": False,
        "return_tokens": True,
        "n_probs": top_count,
        "stream": False,
    },
    sys.stdout,
)
