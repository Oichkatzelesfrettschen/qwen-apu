---
name: qwen-image-turn-language-model
description: the served image turn is admitted on the laptop with qwen38-4b-distill as the language model; the 2B answers image requests in prose, and admission runs from ~/qwen-laptop-setup/remote with QWEN_ADMISSION_MODEL_ID=qwen38-4b-distill
metadata:
  type: project
---

On 2026-08-29 `remote/admit-image-router.sh` accepted 41 of 41 checks on the
laptop with `QWEN_ADMISSION_MODEL_ID=qwen38-4b-distill` and an explicit browser
prompt ("Call the image_generate_image tool now to generate this image: ...").
The 2B distill answered the same request in prose within its 512-token
budget (registry grade 2/10 on tool selection); the 4B proposed on the explicit
prompt every run and on a plain "Draw ..." prompt in one run of two.

**Why:** the served tool is listed as `image_generate_image` with the profile's
bounds in its schema, and the model must choose it inside those bounds; the
harness defaults to the 2B, which does not.

**How to apply:** run image admission with the 4B as the language model and an
explicit tool-naming prompt; treat a prose reply from the 2B as model behavior,
not a harness defect. Evidence: `evidence/image-appliance/served-turn-admission/`.
See [[qwen-laptop-repo-copy-and-test-paths]].

On 2026-08-29 13:53 UTC the paired preset (4B language section beside the
lfm25-vl-16b review-only section, QWEN_ADMISSION_REVIEW_MODEL=lfm25-vl-16b)
passed the whole admission including the page's Review arm; the router lists
the roster sorted, so the page defaults to the first row whose GET /tools
answers 200 (PR #71) and the driver selects the language model by --model.
