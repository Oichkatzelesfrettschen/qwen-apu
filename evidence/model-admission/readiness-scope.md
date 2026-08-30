# Model readiness scope

Three read-only passes over the tree and the appliance, joined here: the
served registry (`remote/models.tsv`), the candidate ledger
(`evidence/model-admission/candidate-ledger.tsv`), and the artifacts under
`$HOME/models` on the appliance. The tables beside this file carry one row per
model with the evidence file behind each cell.

## Served registry (15 rows)

| category | rows | what remains |
| --- | --- | --- |
| ready-production | `qwen38-4b-distill`, `qwen38-2b-distill` | nothing; 32768 validated, graded 47/55 and 40/55 |
| ready-candidate | `qwen35-08b`, `qwen35-08b-f16` | 32768 validated, graded 33/55 and 32/55; a tier move is a quality decision |
| needs-depth-validation | `qwen35-4b-base` | no depth arm exists for the base 4B; the vision profile serves it, so this is the largest open gap on a served row |
| depth validated text-only | `qwen35-2b`, `lfm25-vl-16b` | `validated_filled_depth` reads `-` and stays so: the ledger's validated rows at 8192, 16384, and 32768 carry `projector_state=none` (llama-bench), the registry row requires a projector, and `check-validated-tuples.sh` keys a required-projector row on `loaded`, so a numeric claim fails the gate until a projector-loaded arm fills and decodes through the served path |
| quarantined | `nanbeige42-3b`, `ministral3-3b` | each has a reason record and a re-entry gate under `evidence/quarantine/` |
| archive or rejected | `qwen38-9b-distill`, the three 4B i1 rungs, the two 27B rungs | measured and displaced; nothing to configure |

## Candidate ledger (29 rows)

| category | rows |
| --- | --- |
| promoted | `qwen38-2b-distill-gguf`, `qwen35-08b-bartowski` |
| needs-quality-grade | `qwen3-zero-coder-08b` and the text-trunk scope of `qwen2vl-2b-platinum`; both carry artifact-specific throughput and a same-sweep 55-row protocol |
| needs-throughput | the seven 2B fine-tune/reconstruction rows (`qwen38-2b-uncensored`, `qwen35-2b-hauhau`, `qwen35-2b-unsloth`, `qwen35-2b-unredacted`, `qwen35-2b-unredacted-i1`, `qwen35-2b-heretic`, `qwenseer-2b`), `qwen35-08b-unsloth-unc`, `qwen35-08b-opus-reason`, and `qwen3-zero-coder-v2-08b` |
| needs-one-token-load | `qwen35-9b-defiant-fable`, `minicpm5-1b-fable5-v2`, `minicpm5-1b-stock` |
| archive policy | `qwen38-9b-distill`: the registry and ledger both read `served`; the archive tier is the policy basis, while 5/5-screen and 47/55 remain incomparable quality scales |
| artifact-absent | six rows, safetensors-only or empty repositories, including both Damien420 rows |
| rejected or provenance | five rows |

The repaired ledger reads `static-admitted` for `qwen35-9b-defiant-fable` and
`served` for `qwen38-9b-distill`, matching the cited static and registry
evidence. Both MiniCPM5-1B artifacts now have exact ledger, readiness, and
static-admission rows. `remote/check-model-admission-consistency.py` validates
those joins and refuses lifecycle transitions that outrun artifact evidence.

## Appliance artifacts

23 GGUF files at the top level of `$HOME/models`, 63.4 GB, every one matching
the byte count its pinned `download-*.sh` states. The appliance table carries
17 paths under `candidates/`: 14 ledger staging directories at mode 0700 and
three symlinks to served directories. Eight symlink rows span `production/`,
`candidates/`, and `quarantine/`. The checker derives the 17-row count from
`readiness-appliance-artifacts.tsv` instead of freezing it as verifier input.
Installed and unregistered:
`Qwen3.5-0.8B-bf16.gguf` and `Qwen3.8-2B-BF16.gguf` (F16 derivation
sources, which is their documented role), and the `stories15M` fixture.
`Qwen3.8-2B-F16.gguf` is a measured, rejected representation: its 4.96 tok/s
decode falls below the registered 9 tok/s floor. Pinned
but absent: `qwen38-4b-i1-iq3s` (expected 2,191,729,152 bytes, never
fetched).

## Order of work that follows from this

1. Ledger verification, no device time: run
   `remote/check-model-admission-consistency.py` before admitting a readiness
   or lifecycle edit.
2. Throughput measurement, device time: run artifact-specific, same-sweep arms
   for the ten loaded-and-unmeasured rows. Keep the IQ4_XS and IQ3_S
   reconstruction rungs separate.
3. Quality grading, device time: grade only `qwen3-zero-coder-08b` and the
   text-trunk scope of `qwen2vl-2b-platinum` now. Measure
   `qwen35-08b-opus-reason` and `qwen3-zero-coder-v2-08b` first. A future Opus
   comparison runs both candidate and control in native-thinking mode inside
   one 55-row sweep.
4. MiniCPM5: fetch and strict-load both admitted artifacts, compare tokenizer
   behavior on an exact prompt corpus, run the server parser/grammar tool-call
   arm, measure throughput, then run the paired quality suite.
5. Projector-loaded depth arms for `qwen35-4b-base`, `qwen35-2b`, and
   `lfm25-vl-16b`, since the vision profiles serve all three.
